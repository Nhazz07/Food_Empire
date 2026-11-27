--!strict

-- NightMafiaRaidService (Stage 3 — Random Nighttime Mafia Raids)
-- Server-authoritative random nighttime raid engine integrated with DayNightService,
-- BaseService, PlayerDataService, WarehouseService, MafiaVisualBuilder, BlackMarketService,
-- and CombatLockService.
--
-- Guarantees:
--  1. Raids occur ONLY at night on random eligible nights (NEVER every night).
--  2. Configurable probability, real-time cooldown, and minimum peaceful nights between raids.
--  3. Strictly prevents multiple simultaneous raids on the same restaurant.
--  4. Supports Normal Mafia, Ninja Mafia, Strong Mafia, and Elite Mafia squads.
--  5. A successful raid deducts 20% of Money OR 20% of Reputation (NEVER both) plus
--     configurable stored warehouse ingredients — never negative, never touching Robux items.
--  6. Clean hooks (OnRaidWarning / OnRaidStarted / OnRaidEnded) ready for Stage 4 & Stage 6/7.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local RestaurantSecurityConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RestaurantSecurityConfig")
)
local RestaurantExpansionConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RestaurantExpansionConfig")
)
local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)

local DayNightService = require("./DayNightService")
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local WarehouseService = require("./WarehouseService")
local BlackMarketService = require("./BlackMarketService")
local CombatLockService = require("./CombatLockService")

export type RaidGroupId = RestaurantSecurityConfig.RaidGroupId
export type RaidPenaltyResource = RestaurantSecurityConfig.RaidPenaltyResource
export type RaidOutcome = "Defeated" | "Succeeded" | "RetreatedDawn" | "Cancelled"

export type RaidResultSummary = {
	RaidId: string,
	OwnerUserId: number,
	BaseSlot: BaseService.BaseSlot,
	GroupId: RaidGroupId,
	GroupName: string,
	Outcome: RaidOutcome,
	PenaltyResource: RaidPenaltyResource?,
	CoinsLost: number,
	ReputationLost: number,
	StolenIngredients: { [string]: number },
	TotalIngredientsStolen: number,
	RewardGold: number,
	RewardExp: number,
	RewardRep: number,
}

export type RaidWarningPayload = {
	RaidId: string,
	Owner: Player,
	BaseSlot: BaseService.BaseSlot,
	RestaurantName: string,
	GroupId: RaidGroupId,
	GroupName: string,
	LeadSeconds: number,
	EndsAt: number,
}

export type RaidSnapshot = {
	IsActive: boolean,
	Phase: "Idle" | "Warning" | "Active",
	RaidId: string?,
	BaseSlot: string?,
	RestaurantName: string?,
	GroupId: RaidGroupId?,
	GroupName: string?,
	AliveCount: number,
	TotalCount: number,
	BreachProgress: number,
	TimeRemaining: number,
	CooldownRemaining: number,
	NightCycleId: number,
}

type RaiderUnit = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Template: RestaurantSecurityConfig.RaidUnitTemplate,
	ObjectivePos: Vector3,
	PassedGate: boolean,
	LastAttackAt: number,
	LastPos: Vector3,
	StuckTime: number,
	PathWaypoints: { Vector3 }?,
	PathIndex: number,
	LastPathAt: number,
}

type ActiveRaid = {
	RaidId: string,
	Owner: Player,
	BaseSlot: BaseService.BaseSlot,
	BaseModel: Model,
	GroupSpec: RestaurantSecurityConfig.RaidGroupSpec,
	NightCycleId: number,
	StartedAt: number,
	DeadlineAt: number,
	GatePos: Vector3,
	RestaurantTargetPos: Vector3,
	WarehouseTargetPos: Vector3,
	BaseCenterPos: Vector3,
	StealProgress: number,
	Units: { RaiderUnit },
	Resolved: boolean,
	IgnoreDaylight: boolean,
}

export type StartRaidOptions = {
	IgnoreCooldown: boolean?,
	IgnoreDaylight: boolean?,
	SkipWarning: boolean?,
	WarningLeadOverride: number?,
}

local NightMafiaRaidService = {}

local AI_TICK = 0.45
local ENGAGE_RADIUS_RANGED = 54
local ENGAGE_RADIUS_MELEE = 40
local OBJECTIVE_PRESSURE_RADIUS = 46

local isRunning = false
local raidFolder: Folder? = nil
local aiThread: thread? = nil
local nightConn: RBXScriptConnection? = nil
local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local unsubBaseReleased: (() -> ())? = nil
local testBridge: BindableFunction? = nil

local nightCycleId = 0
local raidSerial = 0

local playerJoinedAt: { [Player]: number } = {}
local lastEvaluatedNightCycle: { [BaseService.BaseSlot]: number } = {}
local lastRaidEndedAt: { [BaseService.BaseSlot]: number } = {}
local lastRaidNightCycle: { [BaseService.BaseSlot]: number } = {}
local activeRaidsBySlot: { [BaseService.BaseSlot]: ActiveRaid } = {}
local pendingRaidBySlot: { [BaseService.BaseSlot]: thread } = {}
local warningStateBySlot: { [BaseService.BaseSlot]: RaidWarningPayload } = {}
local lastAlertPhaseKeyByPlayer: { [Player]: string } = {}
local resolvedRaidIds: { [string]: boolean } = {}
local lastResultBySlot: { [BaseService.BaseSlot]: RaidResultSummary } = {}
local raidAlertRemote: RemoteEvent? = nil

local warningListeners: { (payload: RaidWarningPayload) -> () } = {}
local startedListeners: { (payload: RaidWarningPayload) -> () } = {}
local endedListeners: { (summary: RaidResultSummary) -> () } = {}

local function getCfg(): RestaurantSecurityConfig.NightRaidsConfig
	return RestaurantSecurityConfig.NightRaids
end

local function ensureAlertRemote(): RemoteEvent?
	if raidAlertRemote and raidAlertRemote.Parent then
		return raidAlertRemote
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		local f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
		remotes = f
	end
	if not remotes then
		return nil
	end
	local existing = remotes:FindFirstChild("NightRaidAlert")
	if existing and existing:IsA("RemoteEvent") then
		raidAlertRemote = existing
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = "NightRaidAlert"
	created.Parent = remotes
	raidAlertRemote = created
	return created
end

local function getAffectedRestaurantName(player: Player, slot: BaseService.BaseSlot): string
	local profile = PlayerDataService.GetProfile(player)
	local hqLevel = math.max(1, profile.RestaurantLevel or 1)
	local tierSpec = RestaurantExpansionConfig.GetTierSpec(hqLevel)
	local bistroName = if tierSpec then tierSpec.DisplayName else "Restaurant HQ"
	return string.format("%s Restaurant (%s)", slot, bistroName)
end

-- Owner-team alert remote with deduplication by raidId:phase (notifies ALL co-op partners in the targeted base!)
local function fireOwnerRaidAlert(player: Player, payload: { [string]: any }): ()
	if not player.Parent then
		return
	end
	local ev = ensureAlertRemote()
	if not ev then
		return
	end
	local raidId = tostring(payload.RaidId or "")
	local phase = tostring(payload.Phase or "")
	local key = raidId .. ":" .. phase
	if raidId ~= "" and lastAlertPhaseKeyByPlayer[player] == key then
		return
	end
	lastAlertPhaseKeyByPlayer[player] = key
	ev:FireClient(player, payload)
end

local function fireBaseRaidAlert(slot: BaseService.BaseSlot, payload: { [string]: any }): ()
	for _, member in ipairs(BaseService.GetBasePlayers(slot)) do
		fireOwnerRaidAlert(member, payload)
	end
end

local function sendToast(player: Player, msg: string): ()
	if not player.Parent then
		return
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg)
	end
end

local function sendBaseToast(slot: BaseService.BaseSlot, msg: string): ()
	for _, member in ipairs(BaseService.GetBasePlayers(slot)) do
		sendToast(member, msg)
	end
end

local function formatStolenIngredients(stolen: { [string]: number }): string
	local parts: { string } = {}
	for ing, qty in pairs(stolen) do
		if qty > 0 then
			local display = WarehouseConfig.IngredientDisplayNames[ing] or ing
			table.insert(parts, string.format("%dx %s", qty, display))
		end
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

local function syncBaseRaidAttributes(baseModel: Model?, raid: ActiveRaid?, aliveCount: number): ()
	if not baseModel or not baseModel.Parent then
		return
	end
	if raid and not raid.Resolved then
		baseModel:SetAttribute("NightRaidActive", true)
		baseModel:SetAttribute("NightRaidId", raid.RaidId)
		baseModel:SetAttribute("NightRaidGroupId", raid.GroupSpec.Id)
		baseModel:SetAttribute("NightRaidGroupName", raid.GroupSpec.DisplayName)
		baseModel:SetAttribute("NightRaidAlive", aliveCount)
		baseModel:SetAttribute("NightRaidTotal", #raid.Units)
		baseModel:SetAttribute("NightRaidProgress", math.floor(math.clamp(raid.StealProgress, 0, 100)))
	else
		baseModel:SetAttribute("NightRaidActive", false)
		baseModel:SetAttribute("NightRaidId", nil)
		baseModel:SetAttribute("NightRaidGroupId", nil)
		baseModel:SetAttribute("NightRaidGroupName", nil)
		baseModel:SetAttribute("NightRaidAlive", 0)
		baseModel:SetAttribute("NightRaidTotal", 0)
		baseModel:SetAttribute("NightRaidProgress", 0)
	end
end

local function clearPendingRollForSlot(slot: BaseService.BaseSlot, cancelReason: string?): ()
	local th = pendingRaidBySlot[slot]
	if th then
		pendingRaidBySlot[slot] = nil
		if coroutine.running() ~= th then
			pcall(task.cancel, th)
		end
	end
	local prevWarn = warningStateBySlot[slot]
	warningStateBySlot[slot] = nil
	if prevWarn and cancelReason ~= nil then
		fireBaseRaidAlert(slot, {
			Phase = "Cancelled",
			RaidId = prevWarn.RaidId,
			GroupId = prevWarn.GroupId,
			GroupName = prevWarn.GroupName,
			BaseSlot = prevWarn.BaseSlot,
			RestaurantName = prevWarn.RestaurantName,
			Reason = cancelReason,
		})
	end
end

local function computeBaseWaypoints(baseModel: Model, slot: BaseService.BaseSlot, owner: Player): (Vector3, Vector3, Vector3, Vector3, CFrame)
	local bp = baseModel:FindFirstChild("BasePivot")
	local baseCF = if bp and bp:IsA("BasePart") then bp.CFrame else baseModel:GetPivot()
	local baseCenter = Vector3.new(baseCF.Position.X, 4, baseCF.Position.Z)

	-- Gate waypoint just inside GrandFrontGate (BasePivot local Z = +112 is the gate line!)
	local gatePos = (baseCF * CFrame.new(0, 0, 96)).Position
	local def = baseModel:FindFirstChild("Defenses")
	local gateModel = if def then def:FindFirstChild("GrandFrontGate", true) else nil
	if gateModel and gateModel:IsA("Model") then
		local gateCF = gateModel:GetBoundingBox()
		local toCenter = Vector3.new(baseCenter.X - gateCF.Position.X, 0, baseCenter.Z - gateCF.Position.Z)
		if toCenter.Magnitude > 1 then
			gatePos = Vector3.new(gateCF.Position.X, 4, gateCF.Position.Z) + toCenter.Unit * 14
		else
			gatePos = Vector3.new(gateCF.Position.X, 4, gateCF.Position.Z)
		end
	else
		gatePos = Vector3.new(gatePos.X, 4, gatePos.Z)
	end

	-- Restaurant attack zone: in front of RestaurantHQ / Front Wood Pavilion entrance
	local restPos = (baseCF * CFrame.new(0, 0, 34)).Position
	restPos = Vector3.new(restPos.X, 4, restPos.Z)
	local hq = baseModel:FindFirstChild("RestaurantHQ")
	if hq and hq:IsA("Model") then
		local hqCF, hqSize = hq:GetBoundingBox()
		local dirToGate = Vector3.new(gatePos.X - hqCF.Position.X, 0, gatePos.Z - hqCF.Position.Z)
		if dirToGate.Magnitude > 1 then
			local frontOffset = math.clamp(hqSize.Z * 0.45 + 10, 16, 42)
			local candidate = Vector3.new(hqCF.Position.X, 4, hqCF.Position.Z) + dirToGate.Unit * frontOffset
			restPos = candidate
		end
	end

	-- Warehouse attack zone: pick an unlocked WarehousePlot (preferring one that holds stock!)
	local whPos = (baseCF * CFrame.new(-36, 0, -112)).Position
	whPos = Vector3.new(whPos.X, 4, whPos.Z)
	local bestStock = -1
	local inv = WarehouseService.GetInventorySnapshot(owner)
	for _, plot in ipairs(CollectionService:GetTagged("WarehousePlot")) do
		if plot:GetAttribute("BaseSlot") == slot then
			local catAttr = plot:GetAttribute("Category")
			local pad = plot:FindFirstChild("PlotPivot")
			if typeof(catAttr) == "string" and pad and pad:IsA("BasePart") then
				local cat = catAttr :: WarehouseConfig.WarehouseCategory
				local lv = inv.Levels[cat] or 0
				if lv >= 1 then
					local catTotal = inv.CategoryTotals[cat] or 0
					if catTotal > bestStock then
						bestStock = catTotal
						-- Stand just in front of the CargoDoor apron (+22 studs along base +Z toward plaza)
						local toPlaza = Vector3.new(baseCenter.X - pad.Position.X, 0, baseCenter.Z - pad.Position.Z)
						local frontDir = if toPlaza.Magnitude > 1 then toPlaza.Unit else Vector3.new(0, 0, 1)
						whPos = Vector3.new(pad.Position.X, 4, pad.Position.Z) + frontDir * 22
					end
				end
			end
		end
	end

	return baseCenter, gatePos, restPos, whPos, baseCF
end

local function buildRaiderRig(
	modelName: string,
	tpl: RestaurantSecurityConfig.RaidUnitTemplate,
	spawnCF: CFrame
): MafiaVisualBuilder.RigHandle
	if tpl.VisualKind == "NinjaMafia" then
		return MafiaVisualBuilder.BuildSyndicateSpecialistRig(modelName, "NinjaMafia", tpl.Scale, spawnCF, false)
	elseif tpl.VisualKind == "ApexAssassin" then
		return MafiaVisualBuilder.BuildSyndicateSpecialistRig(modelName, "ApexAssassin", tpl.Scale, spawnCF, false)
	elseif tpl.VisualKind == "ApexWarlord" then
		return MafiaVisualBuilder.BuildSyndicateSpecialistRig(modelName, "ApexWarlord", tpl.Scale, spawnCF, false)
	elseif tpl.VisualKind == "CrimsonDonBoss" then
		return MafiaVisualBuilder.BuildRivalRig(modelName, "CrimsonDonEmpire", false, tpl.Scale, spawnCF, false)
	elseif tpl.VisualKind == "ObsidianKnifeOrder" then
		return MafiaVisualBuilder.BuildRivalRig(modelName, "ObsidianKnifeOrder", true, tpl.Scale, spawnCF, false)
	elseif tpl.VisualKind == "IronCleaverSyndicate" then
		return MafiaVisualBuilder.BuildRivalRig(modelName, "IronCleaverSyndicate", true, tpl.Scale, spawnCF, false)
	else
		return MafiaVisualBuilder.BuildRivalRig(modelName, "HarborHookCartel", true, tpl.Scale, spawnCF, false)
	end
end

local function spawnRaiderUnit(
	raidId: string,
	owner: Player,
	groupSpec: RestaurantSecurityConfig.RaidGroupSpec,
	tpl: RestaurantSecurityConfig.RaidUnitTemplate,
	unitIndex: number,
	spawnCF: CFrame,
	objectivePos: Vector3
): RaiderUnit
	local modelName = string.format("NightRaid_%s_%d", groupSpec.Id, unitIndex)
	local rig = buildRaiderRig(modelName, tpl, spawnCF)
	local model = rig.Model
	local root = rig.Root
	local head = rig.Head

	-- Crisp dark-noir overhead nameplate + live HP bar
	local bb = Instance.new("BillboardGui")
	bb.Name = "RaidUnitPlate"
	bb.Size = UDim2.fromOffset(if tpl.IsBoss then 210 else 178, 44)
	bb.StudsOffset = Vector3.new(0, 3.15 * tpl.Scale, 0)
	bb.MaxDistance = 175
	bb.AlwaysOnTop = false
	bb.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 21)
	label.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
	label.BackgroundTransparency = 0.08
	label.Font = Enum.Font.GothamBlack
	label.Text = tpl.RoleName
	label.TextSize = if tpl.IsBoss then 11 else 10
	label.TextColor3 = if tpl.IsBoss then Color3.fromRGB(255, 214, 118) else groupSpec.AccentColor
	label.Parent = bb

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = label

	local st = Instance.new("UIStroke")
	st.Color = groupSpec.AccentColor
	st.Thickness = 1.25
	st.Parent = label

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBarBg"
	hpBg.Position = UDim2.new(0.04, 0, 0, 24)
	hpBg.Size = UDim2.new(0.92, 0, 0, 14)
	hpBg.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
	hpBg.Parent = bb

	local hpc = Instance.new("UICorner")
	hpc.CornerRadius = UDim.new(0, 3)
	hpc.Parent = hpBg

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = groupSpec.AccentColor
	hpFill.Parent = hpBg

	local hpfc = Instance.new("UICorner")
	hpfc.CornerRadius = UDim.new(0, 3)
	hpfc.Parent = hpFill

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.GothamBold
	hpText.Text = string.format("%d / %d HP", tpl.MaxHealth, tpl.MaxHealth)
	hpText.TextSize = 9
	hpText.TextColor3 = Color3.fromRGB(240, 238, 234)
	hpText.ZIndex = 3
	hpText.Parent = hpBg

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = tpl.MaxHealth
	hum.Health = tpl.MaxHealth
	hum.WalkSpeed = tpl.WalkSpeed
	hum.HipHeight = 2.25 * tpl.Scale
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	hum.HealthChanged:Connect(function(hp: number)
		local cur = math.max(0, math.ceil(hp))
		local maxH = math.max(1, math.ceil(hum.MaxHealth))
		hpFill.Size = UDim2.fromScale(math.clamp(hp / maxH, 0, 1), 1)
		hpText.Text = string.format("%d / %d HP", cur, maxH)
	end)

	hum.Died:Connect(function()
		CollectionService:RemoveTag(model, "NightRaidMafiaUnit")
		CollectionService:RemoveTag(model, "MafiaUnit")
		MafiaVisualBuilder.PlayDeathSequence(model, tpl.IsBoss, function(impactPos: Vector3)
			BlackMarketService.BroadcastSFX("BodyDrop", impactPos)
		end)
	end)

	model.PrimaryPart = root
	model:SetAttribute("RaidId", raidId)
	model:SetAttribute("RaidGroup", groupSpec.Id)
	model:SetAttribute("RaidGroupName", groupSpec.DisplayName)
	model:SetAttribute("RaidOwnerUserId", owner.UserId)
	local ownerSlot = BaseService.GetPlayerBaseSlot(owner)
	if ownerSlot then
		model:SetAttribute("RaidBaseSlot", ownerSlot)
	end
	model:SetAttribute("RaidObjective", tpl.Objective)
	model:SetAttribute("RaidRole", tpl.RoleName)
	model:SetAttribute("MafiaTitle", tpl.RoleName)
	model:SetAttribute("IsMafiaBoss", tpl.IsBoss)
	model:SetAttribute("BountyGold", tpl.BountyGold)
	model:SetAttribute("BountyExp", tpl.BountyExp)
	model:SetAttribute("BountyRep", tpl.BountyRep)
	-- Note: We tag both NightRaidMafiaUnit AND MafiaUnit so all existing weapons,
	-- Golden Spatula, Bodyguards, Mercenaries, Minimap, Limb Animator, and CombatLock
	-- engage seamlessly without duplicating any combat code!
	CollectionService:AddTag(model, "NightRaidMafiaUnit")
	CollectionService:AddTag(model, "MafiaUnit")
	model.Parent = raidFolder or Workspace

	return {
		Model = model,
		Humanoid = hum,
		Root = root,
		Template = tpl,
		ObjectivePos = objectivePos,
		PassedGate = false,
		LastAttackAt = 0,
		LastPos = root.Position,
		StuckTime = 0,
		PathWaypoints = nil,
		PathIndex = 1,
		LastPathAt = 0,
	}
end

local function pickPenaltyResource(groupSpec: RestaurantSecurityConfig.RaidGroupSpec): RaidPenaltyResource
	local mode = getCfg().OutcomeMode
	if mode == "Money" then
		return "Money"
	elseif mode == "Reputation" then
		return "Reputation"
	end
	return groupSpec.PenaltyResource
end

local function destroyRemainingRaidUnits(raid: ActiveRaid): ()
	for _, u in ipairs(raid.Units) do
		if u.Model and u.Model.Parent then
			if u.Humanoid.Health > 0 then
				u.Model:Destroy()
			else
				task.delay(4, function()
					if u.Model and u.Model.Parent then
						u.Model:Destroy()
					end
				end)
			end
		end
	end
end

local function finalizeRaid(raid: ActiveRaid, summary: RaidResultSummary, setCooldown: boolean): ()
	local slot = raid.BaseSlot
	if activeRaidsBySlot[slot] == raid then
		activeRaidsBySlot[slot] = nil
	end
	warningStateBySlot[slot] = nil
	syncBaseRaidAttributes(raid.BaseModel, nil, 0)

	if setCooldown and BaseService.GetBasePlayerCount(slot) > 0 then
		lastRaidEndedAt[slot] = os.clock()
		lastRaidNightCycle[slot] = raid.NightCycleId
	end

	destroyRemainingRaidUnits(raid)
	lastResultBySlot[slot] = summary

	local stolenText = if summary.TotalIngredientsStolen > 0
		then formatStolenIngredients(summary.StolenIngredients)
		else ""
	local cfg = getCfg()
	local lead = BaseService.GetBaseLeadPlayer(slot) or raid.Owner

	fireBaseRaidAlert(slot, {
		Phase = "Ended",
		RaidId = raid.RaidId,
		GroupId = raid.GroupSpec.Id,
		GroupName = raid.GroupSpec.DisplayName,
		BaseSlot = slot,
		RestaurantName = getAffectedRestaurantName(lead, slot),
		Outcome = summary.Outcome,
		PenaltyResource = summary.PenaltyResource,
		CoinsLost = summary.CoinsLost,
		ReputationLost = summary.ReputationLost,
		StolenIngredients = summary.StolenIngredients,
		TotalIngredientsStolen = summary.TotalIngredientsStolen,
		StolenText = stolenText,
		RewardGold = summary.RewardGold,
		RewardExp = summary.RewardExp,
		RewardRep = summary.RewardRep,
		DisplayDuration = cfg.OutcomeBannerDurationSeconds,
	})

	for _, cb in ipairs(endedListeners) do
		task.spawn(cb, summary)
	end
end

local function resolveRaidDefeated(raid: ActiveRaid): ()
	if raid.Resolved or resolvedRaidIds[raid.RaidId] then
		return
	end
	raid.Resolved = true
	resolvedRaidIds[raid.RaidId] = true

	local g = raid.GroupSpec
	local slot = raid.BaseSlot
	local members = BaseService.GetBasePlayers(slot)
	local lead = members[1] or raid.Owner
	local rGold, rExp, rRep = 0, 0, 0
	if #members > 0 then
		rGold = g.DefenseRewardGold
		rExp = g.DefenseRewardExp
		rRep = g.DefenseRewardRep
		for _, member in ipairs(members) do
			PlayerDataService.AddRewards(member, rGold, rExp, rRep)
			sendToast(
				member,
				string.format(
					"RESTAURANT PROTECTED! Your team defeated the %s Night Raid! (+%dG, +%d Rep)",
					g.DisplayName,
					rGold,
					rRep
				)
			)
		end
	end

	print(
		string.format(
			"[NightMafiaRaidService] Raid %s (%s) on %s Base DEFEATED! Rewarded +%dG +%dRep.",
			raid.RaidId,
			g.DisplayName,
			slot,
			rGold,
			rRep
		)
	)

	finalizeRaid(raid, {
		RaidId = raid.RaidId,
		OwnerUserId = lead.UserId,
		BaseSlot = slot,
		GroupId = g.Id,
		GroupName = g.DisplayName,
		Outcome = "Defeated",
		PenaltyResource = nil,
		CoinsLost = 0,
		ReputationLost = 0,
		StolenIngredients = {},
		TotalIngredientsStolen = 0,
		RewardGold = rGold,
		RewardExp = rExp,
		RewardRep = rRep,
	}, true)
end

local function resolveRaidSucceeded(raid: ActiveRaid): ()
	if raid.Resolved or resolvedRaidIds[raid.RaidId] then
		return
	end
	raid.Resolved = true
	resolvedRaidIds[raid.RaidId] = true

	local cfg = getCfg()
	local g = raid.GroupSpec
	local slot = raid.BaseSlot
	local members = BaseService.GetBasePlayers(slot)
	local lead = members[1] or raid.Owner
	local penaltyResource = pickPenaltyResource(g)
	local coinsLost = 0
	local repLost = 0
	local stolenMap: { [string]: number } = {}
	local totalStolen = 0

	if #members > 0 then
		local pct = math.clamp(cfg.PenaltyPercent, 0, 0.5)

		-- Steal stored warehouse ingredients ONCE from the shared base warehouse!
		if cfg.EnableWarehouseTheft and g.MaxIngredientsToSteal > 0 then
			stolenMap, totalStolen = WarehouseService.StealRandomStoredIngredients(
				lead,
				g.MaxIngredientsToSteal,
				cfg.WarehouseTheftPercent,
				cfg.WarehouseTheftOnlyUnlocked
			)
		end

		local theftText = if totalStolen > 0
			then (" | Stole: " .. formatStolenIngredients(stolenMap))
			else " | Warehouse empty (0 supplies stolen)"

		for _, member in ipairs(members) do
			local profile = PlayerDataService.GetProfile(member)
			local mCoinsLost = 0
			local mRepLost = 0
			-- Strictly deduct 20% of Money OR 20% of Reputation — NEVER both!
			if penaltyResource == "Money" then
				local rawLoss = math.floor(math.max(0, profile.Coins) * pct)
				mCoinsLost = PlayerDataService.DeductCoinsClamped(member, rawLoss)
				coinsLost = math.max(coinsLost, mCoinsLost)
			else
				local rawLoss = math.floor(math.max(0, profile.Reputation) * pct)
				mRepLost = PlayerDataService.DeductReputation(member, rawLoss)
				repLost = math.max(repLost, mRepLost)
			end

			local penaltyText = if penaltyResource == "Money"
				then string.format("-%d Gold (20%%)", mCoinsLost)
				else string.format("-%d Reputation (20%%)", mRepLost)
			sendToast(
				member,
				string.format("NIGHT RAID FAILED! %s robbed your base: %s%s", g.DisplayName, penaltyText, theftText)
			)
		end
	end

	print(
		string.format(
			"[NightMafiaRaidService] Raid %s (%s) on %s Base SUCCEEDED: resource=%s coinsLost=%d repLost=%d ingredientsStolen=%d",
			raid.RaidId,
			g.DisplayName,
			slot,
			penaltyResource,
			coinsLost,
			repLost,
			totalStolen
		)
	)

	finalizeRaid(raid, {
		RaidId = raid.RaidId,
		OwnerUserId = lead.UserId,
		BaseSlot = slot,
		GroupId = g.Id,
		GroupName = g.DisplayName,
		Outcome = "Succeeded",
		PenaltyResource = penaltyResource,
		CoinsLost = coinsLost,
		ReputationLost = repLost,
		StolenIngredients = stolenMap,
		TotalIngredientsStolen = totalStolen,
		RewardGold = 0,
		RewardExp = 0,
		RewardRep = 0,
	}, true)
end

local function resolveRaidRetreated(raid: ActiveRaid, outcome: "RetreatedDawn" | "Cancelled", reasonText: string?): ()
	if raid.Resolved or resolvedRaidIds[raid.RaidId] then
		return
	end
	raid.Resolved = true
	resolvedRaidIds[raid.RaidId] = true

	local g = raid.GroupSpec
	local slot = raid.BaseSlot
	local lead = BaseService.GetBaseLeadPlayer(slot) or raid.Owner
	if outcome == "RetreatedDawn" then
		sendBaseToast(
			slot,
			string.format("SUNRISE! The %s squad retreated before completing their heist!", g.DisplayName)
		)
	end

	print(
		string.format(
			"[NightMafiaRaidService] Raid %s (%s) on %s Base ended (%s: %s).",
			raid.RaidId,
			g.DisplayName,
			slot,
			outcome,
			reasonText or "cleanup"
		)
	)

	finalizeRaid(raid, {
		RaidId = raid.RaidId,
		OwnerUserId = lead.UserId,
		BaseSlot = slot,
		GroupId = g.Id,
		GroupName = g.DisplayName,
		Outcome = outcome,
		PenaltyResource = nil,
		CoinsLost = 0,
		ReputationLost = 0,
		StolenIngredients = {},
		TotalIngredientsStolen = 0,
		RewardGold = 0,
		RewardExp = 0,
		RewardRep = 0,
	}, outcome == "RetreatedDawn")
end

local function findNearestDefender(
	raid: ActiveRaid,
	raiderPos: Vector3,
	searchRadius: number
): (Humanoid?, Vector3?, Player?)
	local bestHum: Humanoid? = nil
	local bestPos: Vector3? = nil
	local bestPlayer: Player? = nil
	local bestDist = searchRadius

	-- 1. Defending Players inside/near the raided base
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if hum and hum.Health > 0 and root and root:IsA("BasePart") then
			local distFromBase = (root.Position - raid.BaseCenterPos).Magnitude
			if distFromBase <= 185 then
				local d = (root.Position - raiderPos).Magnitude
				if d < bestDist then
					bestDist = d
					bestHum = hum
					bestPos = root.Position
					bestPlayer = plr
				end
			end
		end
	end

	-- 2. Friendly Base Defenders (Personal Bodyguards & Hired Mercenaries / Companions)
	for _, tagName in ipairs({ "PlayerBodyguardUnit", "MercenaryMafiaUnit", "HiredDefenseCompanion" }) do
		for _, unit in ipairs(CollectionService:GetTagged(tagName)) do
			if unit:IsA("Model") and unit.Parent then
				local hum = unit:FindFirstChildOfClass("Humanoid")
				local root = unit:FindFirstChild("HumanoidRootPart")
				if hum and hum.Health > 0 and root and root:IsA("BasePart") then
					local d = (root.Position - raiderPos).Magnitude
					if d < bestDist then
						bestDist = d
						bestHum = hum
						bestPos = root.Position
						bestPlayer = nil
					end
				end
			end
		end
	end

	return bestHum, bestPos, bestPlayer
end

local function moveUnitSmart(u: RaiderUnit, dest: Vector3, now: number, dt: number): ()
	local pos = u.Root.Position
	local moved = (pos - u.LastPos).Magnitude
	u.LastPos = pos

	if moved < 0.75 then
		u.StuckTime += dt
	else
		u.StuckTime = 0
	end

	-- If stuck for >2.6s, compute a Roblox Pathfinding detour or step slightly sideways
	if u.StuckTime >= 2.6 and (now - u.LastPathAt) >= 3.2 then
		u.LastPathAt = now
		u.StuckTime = 0
		local path = PathfindingService:CreatePath({
			AgentRadius = 2.2,
			AgentHeight = 5.5,
			AgentCanJump = true,
			WaypointSpacing = 10,
		})
		local ok = pcall(function()
			path:ComputeAsync(pos, dest)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			local pts: { Vector3 } = {}
			for idx, wp in ipairs(path:GetWaypoints()) do
				if idx > 1 then
					table.insert(pts, wp.Position)
				end
			end
			if #pts > 0 then
				u.PathWaypoints = pts
				u.PathIndex = 1
			end
		else
			-- Gentle lateral nudge to clear a corner post/doorway jamb
			local toDest = Vector3.new(dest.X - pos.X, 0, dest.Z - pos.Z)
			if toDest.Magnitude > 1 then
				local side = Vector3.new(-toDest.Z, 0, toDest.X).Unit
				u.Humanoid:MoveTo(pos + side * 6 + toDest.Unit * 4)
				return
			end
		end
	end

	if u.PathWaypoints and u.PathIndex <= #u.PathWaypoints then
		local wp = u.PathWaypoints[u.PathIndex]
		if (Vector3.new(wp.X - pos.X, 0, wp.Z - pos.Z)).Magnitude <= 5.5 then
			u.PathIndex += 1
			if u.PathIndex > #u.PathWaypoints then
				u.PathWaypoints = nil
			else
				wp = u.PathWaypoints[u.PathIndex]
			end
		end
		if u.PathWaypoints then
			u.Humanoid:MoveTo(wp)
			return
		end
	end

	u.Humanoid:MoveTo(dest)
end

local function stepActiveRaid(raid: ActiveRaid, now: number, dt: number): ()
	if raid.Resolved then
		return
	end

	if BaseService.GetBasePlayerCount(raid.BaseSlot) == 0 or not raid.BaseModel.Parent then
		resolveRaidRetreated(raid, "Cancelled", "base_empty")
		return
	end
	if not raid.Owner.Parent then
		local lead = BaseService.GetBaseLeadPlayer(raid.BaseSlot)
		if lead then
			raid.Owner = lead
		end
	end

	if not raid.IgnoreDaylight and not DayNightService.IsNight() then
		resolveRaidRetreated(raid, "RetreatedDawn", "sunrise")
		return
	end

	if now >= raid.DeadlineAt then
		resolveRaidRetreated(raid, "RetreatedDawn", "timeout")
		return
	end

	local aliveCount = 0
	local onObjectiveCount = 0

	for _, u in ipairs(raid.Units) do
		if u.Model.Parent and u.Humanoid.Health > 0 and u.Root.Parent then
			aliveCount += 1
			local pos = u.Root.Position
			local tpl = u.Template

			if not u.PassedGate then
				if (Vector3.new(pos.X - raid.GatePos.X, 0, pos.Z - raid.GatePos.Z)).Magnitude <= 14 then
					u.PassedGate = true
					u.PathWaypoints = nil
				end
			end

			local aggroDist = if tpl.CombatStyle == "Melee" then ENGAGE_RADIUS_MELEE else ENGAGE_RADIUS_RANGED
			local targetHum, targetPos, targetPlayer = findNearestDefender(raid, pos, aggroDist)

			-- Combat engagement against nearby players & defenders
			if targetHum and targetPos then
				local distToTarget = (targetPos - pos).Magnitude
				if distToTarget <= tpl.AttackRange and (now - u.LastAttackAt) >= tpl.AttackCooldown then
					u.LastAttackAt = now
					MafiaVisualBuilder.TriggerAttackAnim(u.Model)
					if targetPlayer then
						CombatLockService.MarkUnderAttack(targetPlayer, pos, tpl.RoleName)
					end
					if tpl.CombatStyle == "Melee" then
						targetHum:TakeDamage(tpl.Damage)
						BlackMarketService.BroadcastSFX("MeleeHit", targetPos)
					else
						local fromPos = pos + Vector3.new(0, 1.4, 0)
						local tracerCol = if tpl.IsBoss
							then Color3.fromRGB(255, 206, 62)
							else raid.GroupSpec.AccentColor
						BlackMarketService.SpawnBulletTracer(fromPos, targetPos, tracerCol)
						BlackMarketService.BroadcastSFX(if tpl.IsBoss then "SMGShot" else "EnemyShot", fromPos)
						if math.random() < 0.78 then
							targetHum:TakeDamage(tpl.Damage)
							BlackMarketService.BroadcastSFX("MeleeHit", targetPos)
						end
					end
				end

				-- Ninja Mafia rush straight at defenders; ranged raiders advance toward objective if far, or engage close threats
				if tpl.CombatStyle == "Melee" or distToTarget <= 24 then
					moveUnitSmart(u, targetPos, now, dt)
				else
					local navDest = if u.PassedGate then u.ObjectivePos else raid.GatePos
					moveUnitSmart(u, navDest, now, dt)
				end
			else
				local navDest = if u.PassedGate then u.ObjectivePos else raid.GatePos
				moveUnitSmart(u, navDest, now, dt)
			end

			-- Check if this living raider is actively pressuring the Restaurant or Warehouse zone
			local distRest = (Vector3.new(pos.X - raid.RestaurantTargetPos.X, 0, pos.Z - raid.RestaurantTargetPos.Z)).Magnitude
			local distWh = (Vector3.new(pos.X - raid.WarehouseTargetPos.X, 0, pos.Z - raid.WarehouseTargetPos.Z)).Magnitude
			if u.PassedGate and (distRest <= OBJECTIVE_PRESSURE_RADIUS or distWh <= OBJECTIVE_PRESSURE_RADIUS) then
				onObjectiveCount += 1
			end
		end
	end

	if aliveCount <= 0 then
		resolveRaidDefeated(raid)
		return
	end

	-- Advance steal/breach meter while living raiders occupy the restaurant / warehouse zones
	if onObjectiveCount > 0 then
		local cfg = getCfg()
		local baseDuration = math.max(10, cfg.BreachDurationSeconds)
		local pressureMult = 0.65 + 0.35 * math.min(onObjectiveCount, 3)
		local progressDelta = (100 / baseDuration) * raid.GroupSpec.BreachRateMultiplier * pressureMult * dt
		raid.StealProgress = math.min(100, raid.StealProgress + progressDelta)
	end

	syncBaseRaidAttributes(raid.BaseModel, raid, aliveCount)

	if raid.StealProgress >= 100 then
		resolveRaidSucceeded(raid)
	end
end

local function selectWeightedGroupForPlayer(player: Player): RestaurantSecurityConfig.RaidGroupSpec
	local cfg = getCfg()
	local profile = PlayerDataService.GetProfile(player)
	local hqLevel = math.max(1, profile.RestaurantLevel or 1)

	local eligible: { RestaurantSecurityConfig.RaidGroupSpec } = {}
	local totalWeight = 0
	for _, groupId in ipairs(cfg.GroupOrder) do
		local spec = cfg.Groups[groupId]
		if spec and hqLevel >= spec.MinRestaurantLevel then
			table.insert(eligible, spec)
			totalWeight += math.max(1, spec.SelectionWeight)
		end
	end

	if #eligible == 0 then
		return cfg.Groups.NormalMafia
	end

	local roll = math.random() * totalWeight
	local acc = 0
	for _, spec in ipairs(eligible) do
		acc += math.max(1, spec.SelectionWeight)
		if roll <= acc then
			return spec
		end
	end
	return eligible[#eligible]
end

function NightMafiaRaidService.IsRaidActive(player: Player): boolean
	local slot = BaseService.GetPlayerBaseSlot(player)
	local raid = if slot then activeRaidsBySlot[slot] else nil
	return raid ~= nil and not raid.Resolved
end

function NightMafiaRaidService.GetActiveRaidUnitsForPlayer(player: Player): { Model }
	local out: { Model } = {}
	local slot = BaseService.GetPlayerBaseSlot(player)
	local raid = if slot then activeRaidsBySlot[slot] else nil
	if not raid or raid.Resolved then
		return out
	end
	for _, u in ipairs(raid.Units) do
		if u.Model.Parent and u.Humanoid.Health > 0 then
			table.insert(out, u.Model)
		end
	end
	return out
end

function NightMafiaRaidService.GetSnapshot(player: Player): RaidSnapshot
	local cfg = getCfg()
	local now = os.clock()
	local curSlot = BaseService.GetPlayerBaseSlot(player)
	local lastEnd = if curSlot then lastRaidEndedAt[curSlot] else nil
	local cdRem = if lastEnd then math.max(0, math.ceil(cfg.RaidCooldownSeconds - (now - lastEnd))) else 0

	local raid = if curSlot then activeRaidsBySlot[curSlot] else nil
	if raid and not raid.Resolved then
		local alive = 0
		for _, u in ipairs(raid.Units) do
			if u.Model.Parent and u.Humanoid.Health > 0 then
				alive += 1
			end
		end
		return {
			IsActive = true,
			Phase = "Active",
			RaidId = raid.RaidId,
			BaseSlot = raid.BaseSlot,
			RestaurantName = getAffectedRestaurantName(player, raid.BaseSlot),
			GroupId = raid.GroupSpec.Id,
			GroupName = raid.GroupSpec.DisplayName,
			AliveCount = alive,
			TotalCount = #raid.Units,
			BreachProgress = math.floor(math.clamp(raid.StealProgress, 0, 100)),
			TimeRemaining = math.max(0, math.ceil(raid.DeadlineAt - now)),
			CooldownRemaining = 0,
			NightCycleId = nightCycleId,
		}
	end

	local warnState = if curSlot then warningStateBySlot[curSlot] else nil
	if warnState then
		return {
			IsActive = false,
			Phase = "Warning",
			RaidId = warnState.RaidId,
			BaseSlot = warnState.BaseSlot,
			RestaurantName = warnState.RestaurantName,
			GroupId = warnState.GroupId,
			GroupName = warnState.GroupName,
			AliveCount = 0,
			TotalCount = 0,
			BreachProgress = 0,
			TimeRemaining = math.max(0, math.ceil(warnState.EndsAt - now)),
			CooldownRemaining = 0,
			NightCycleId = nightCycleId,
		}
	end

	return {
		IsActive = false,
		Phase = "Idle",
		RaidId = nil,
		BaseSlot = curSlot,
		RestaurantName = if curSlot then getAffectedRestaurantName(player, curSlot) else nil,
		GroupId = nil,
		GroupName = nil,
		AliveCount = 0,
		TotalCount = 0,
		BreachProgress = 0,
		TimeRemaining = 0,
		CooldownRemaining = cdRem,
		NightCycleId = nightCycleId,
	}
end

function NightMafiaRaidService.EvaluateNightEligibility(player: Player, ignoreGrace: boolean?): (boolean, string)
	local cfg = getCfg()
	if not cfg.Enabled then
		return false, "Night raids disabled in config"
	end
	if not player.Parent then
		return false, "Player offline"
	end
	if not DayNightService.IsNight() then
		return false, "Not nighttime"
	end
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot or not BaseService.GetBaseModel(slot) then
		return false, "No claimed restaurant base"
	end
	if activeRaidsBySlot[slot] ~= nil or warningStateBySlot[slot] ~= nil then
		return false, "Raid already active or pending on this restaurant"
	end
	local now = os.clock()
	if not ignoreGrace then
		local earliestJoin = playerJoinedAt[player] or now
		for _, m in ipairs(BaseService.GetBasePlayers(slot)) do
			local j = playerJoinedAt[m]
			if j and j < earliestJoin then
				earliestJoin = j
			end
		end
		if (now - earliestJoin) < cfg.NewPlayerGraceSeconds then
			return false, string.format("New player grace (%ds left)", math.ceil(cfg.NewPlayerGraceSeconds - (now - earliestJoin)))
		end
	end
	local lastEnd = lastRaidEndedAt[slot]
	if lastEnd and (now - lastEnd) < cfg.RaidCooldownSeconds then
		return false, string.format("Raid cooldown (%ds left)", math.ceil(cfg.RaidCooldownSeconds - (now - lastEnd)))
	end
	local lastNight = lastRaidNightCycle[slot]
	if lastNight and nightCycleId > 0 and (nightCycleId - lastNight) <= cfg.MinNightsBetweenRaids then
		return false, "Protected peaceful night between raids"
	end
	return true, "Eligible"
end

function NightMafiaRaidService.StartRaidForPlayer(
	player: Player,
	requestedGroupId: RaidGroupId?,
	options: StartRaidOptions?
): (boolean, string)
	local cfg = getCfg()
	local opts: StartRaidOptions = options or {}

	if not player.Parent then
		return false, "Player is no longer in server"
	end
	if not opts.IgnoreDaylight and not DayNightService.IsNight() then
		return false, "Night Mafia Raids can only occur at night"
	end

	local slot = BaseService.GetPlayerBaseSlot(player)
	local baseModel = if slot then BaseService.GetBaseModel(slot) else nil
	if not slot or not baseModel then
		return false, "Player does not own a restaurant base yet"
	end

	if activeRaidsBySlot[slot] ~= nil or warningStateBySlot[slot] ~= nil then
		return false, "A raid or raid warning is already active against this restaurant"
	end
	if not opts.IgnoreCooldown then
		local okElig, reason = NightMafiaRaidService.EvaluateNightEligibility(player, true)
		if not okElig then
			return false, reason
		end
	end

	local groupSpec: RestaurantSecurityConfig.RaidGroupSpec? = nil
	if requestedGroupId and cfg.Groups[requestedGroupId] then
		groupSpec = cfg.Groups[requestedGroupId]
	else
		groupSpec = selectWeightedGroupForPlayer(player)
	end
	if not groupSpec then
		return false, "Invalid raid group"
	end

	clearPendingRollForSlot(slot, nil)
	raidSerial += 1
	local raidId = string.format("NR_%s_%d", slot, raidSerial)
	local restaurantName = getAffectedRestaurantName(player, slot)
	local leadSec = if opts.SkipWarning
		then 0
		elseif typeof(opts.WarningLeadOverride) == "number" then math.max(0, opts.WarningLeadOverride)
		else math.max(0, cfg.WarningLeadSeconds)

	local warningPayload: RaidWarningPayload = {
		RaidId = raidId,
		Owner = player,
		BaseSlot = slot,
		RestaurantName = restaurantName,
		GroupId = groupSpec.Id,
		GroupName = groupSpec.DisplayName,
		LeadSeconds = leadSec,
		EndsAt = os.clock() + leadSec,
	}

	local function spawnSquadNow(): (boolean, string)
		local leadPlr = BaseService.GetBaseLeadPlayer(slot)
		if not leadPlr or not baseModel.Parent then
			warningStateBySlot[slot] = nil
			return false, "Base unavailable or empty"
		end
		if not opts.IgnoreDaylight and not DayNightService.IsNight() then
			warningStateBySlot[slot] = nil
			fireBaseRaidAlert(slot, {
				Phase = "Cancelled",
				RaidId = raidId,
				GroupId = groupSpec.Id,
				GroupName = groupSpec.DisplayName,
				BaseSlot = slot,
				RestaurantName = restaurantName,
				Reason = "sunrise",
			})
			return false, "Daybreak cancelled raid"
		end
		if activeRaidsBySlot[slot] ~= nil then
			warningStateBySlot[slot] = nil
			return false, "A raid is already active against this restaurant"
		end

		local baseCenter, gatePos, restPos, whPos, baseCF = computeBaseWaypoints(baseModel, slot, leadPlr)
		local units: { RaiderUnit } = {}
		local squadCount = #groupSpec.Squad

		for idx, tpl in ipairs(groupSpec.Squad) do
			local spreadX = (idx - (squadCount + 1) * 0.5) * 6.5
			local spawnWorld = (baseCF * CFrame.new(spreadX, 0, 124 + (idx % 2) * 3.5)).Position
			local groundedPos = Vector3.new(spawnWorld.X, 4.2, spawnWorld.Z)
			local lookTarget = Vector3.new(gatePos.X, 4.2, gatePos.Z)
			local spawnCF = if (lookTarget - groundedPos).Magnitude > 1
				then CFrame.lookAt(groundedPos, lookTarget)
				else CFrame.new(groundedPos)
			local objPos = if tpl.Objective == "Warehouse" then whPos else restPos
			local unit = spawnRaiderUnit(raidId, leadPlr, groupSpec, tpl, idx, spawnCF, objPos)
			table.insert(units, unit)
		end

		local now = os.clock()
		local raid: ActiveRaid = {
			RaidId = raidId,
			Owner = leadPlr,
			BaseSlot = slot,
			BaseModel = baseModel,
			GroupSpec = groupSpec,
			NightCycleId = math.max(1, nightCycleId),
			StartedAt = now,
			DeadlineAt = now + math.max(25, cfg.MaxRaidDurationSeconds),
			GatePos = gatePos,
			RestaurantTargetPos = restPos,
			WarehouseTargetPos = whPos,
			BaseCenterPos = baseCenter,
			StealProgress = 0,
			Units = units,
			Resolved = false,
			IgnoreDaylight = opts.IgnoreDaylight == true,
		}

		warningStateBySlot[slot] = nil
		activeRaidsBySlot[slot] = raid
		syncBaseRaidAttributes(baseModel, raid, #units)

		-- Dismiss pre-attack warning banner & stop alarm for all co-op partners!
		fireBaseRaidAlert(slot, {
			Phase = "Started",
			RaidId = raidId,
			GroupId = groupSpec.Id,
			GroupName = groupSpec.DisplayName,
			BaseSlot = slot,
			RestaurantName = restaurantName,
			AliveCount = #units,
			TotalCount = #units,
		})

		sendBaseToast(
			slot,
			string.format(
				"RAID UNDERWAY! %s (%d raiders) are storming %s! Defend your vault & warehouses together!",
				string.upper(groupSpec.DisplayName),
				#units,
				restaurantName
			)
		)

		print(
			string.format(
				"[NightMafiaRaidService] Started %s (%s, %d units) on %s Co-op Base!",
				raidId,
				groupSpec.DisplayName,
				#units,
				slot
			)
		)

		for _, cb in ipairs(startedListeners) do
			task.spawn(cb, warningPayload)
		end
		return true, string.format("Started %s raid (%d units)", groupSpec.DisplayName, #units)
	end

	-- Stage 4: Pre-attack warning & alarm period for ALL co-op partners in the targeted base!
	if warningPayload.LeadSeconds > 0 then
		warningStateBySlot[slot] = warningPayload
		local alarmCfg = RestaurantSecurityConfig.RaidAlarm
		fireBaseRaidAlert(slot, {
			Phase = "Warning",
			RaidId = raidId,
			GroupId = groupSpec.Id,
			GroupName = groupSpec.DisplayName,
			GroupTag = groupSpec.ShortTag,
			AccentColor = groupSpec.AccentColor,
			BaseSlot = slot,
			RestaurantName = restaurantName,
			LeadSeconds = warningPayload.LeadSeconds,
			TitleText = alarmCfg.TitleText,
			SubtitleText = alarmCfg.SubtitleText,
			DetailText = alarmCfg.DetailText,
		})
		print(
			string.format(
				"[NightMafiaRaidService] Raid Warning %s (%s -> %s) active for %.1fs before attack!",
				raidId,
				groupSpec.DisplayName,
				restaurantName,
				warningPayload.LeadSeconds
			)
		)
		for _, cb in ipairs(warningListeners) do
			task.spawn(cb, warningPayload)
		end
		pendingRaidBySlot[slot] = task.delay(warningPayload.LeadSeconds, function()
			pendingRaidBySlot[slot] = nil
			spawnSquadNow()
		end)
		return true, string.format("Warning active (%ds) for %s raid", warningPayload.LeadSeconds, groupSpec.DisplayName)
	end

	for _, cb in ipairs(warningListeners) do
		task.spawn(cb, warningPayload)
	end
	return spawnSquadNow()
end

function NightMafiaRaidService.TryRollNightRaidForPlayer(player: Player, ignoreGrace: boolean?): (boolean, string)
	local okElig, reason = NightMafiaRaidService.EvaluateNightEligibility(player, ignoreGrace)
	if not okElig then
		return false, reason
	end

	local cfg = getCfg()
	local profile = PlayerDataService.GetProfile(player)
	local hqLevel = math.max(1, profile.RestaurantLevel or 1)
	local chance = math.min(cfg.MaxRaidChance, cfg.BaseRaidChance + math.max(0, hqLevel - 1) * cfg.ChancePerRestaurantLevel)
	local roll = math.random()

	if roll > chance then
		return false, string.format("Peaceful night (rolled %.2f > %.2f)", roll, chance)
	end

	return NightMafiaRaidService.StartRaidForPlayer(player, nil, nil)
end

function NightMafiaRaidService.CancelRaidForPlayer(player: Player, reason: string?): boolean
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return false
	end
	local hadWarn = warningStateBySlot[slot] ~= nil
	clearPendingRollForSlot(slot, reason or "manual_cancel")
	local raid = activeRaidsBySlot[slot]
	if not raid or raid.Resolved then
		return hadWarn
	end
	resolveRaidRetreated(raid, "Cancelled", reason or "manual_cancel")
	return true
end

function NightMafiaRaidService.OnRaidWarning(cb: (payload: RaidWarningPayload) -> ()): () -> ()
	table.insert(warningListeners, cb)
	return function()
		local idx = table.find(warningListeners, cb)
		if idx then
			table.remove(warningListeners, idx)
		end
	end
end

function NightMafiaRaidService.OnRaidStarted(cb: (payload: RaidWarningPayload) -> ()): () -> ()
	table.insert(startedListeners, cb)
	return function()
		local idx = table.find(startedListeners, cb)
		if idx then
			table.remove(startedListeners, idx)
		end
	end
end

function NightMafiaRaidService.OnRaidEnded(cb: (summary: RaidResultSummary) -> ()): () -> ()
	table.insert(endedListeners, cb)
	return function()
		local idx = table.find(endedListeners, cb)
		if idx then
			table.remove(endedListeners, idx)
		end
	end
end

local function scheduleNightEvaluationForSlot(slot: BaseService.BaseSlot, cycleId: number): ()
	if lastEvaluatedNightCycle[slot] == cycleId then
		return
	end
	local lead = BaseService.GetBaseLeadPlayer(slot)
	if not lead then
		return
	end
	lastEvaluatedNightCycle[slot] = cycleId

	local okElig, _ = NightMafiaRaidService.EvaluateNightEligibility(lead, false)
	if not okElig then
		return
	end

	local cfg = getCfg()
	local profile = PlayerDataService.GetProfile(lead)
	local hqLevel = math.max(1, profile.RestaurantLevel or 1)
	local chance = math.min(cfg.MaxRaidChance, cfg.BaseRaidChance + math.max(0, hqLevel - 1) * cfg.ChancePerRestaurantLevel)
	local roll = math.random()

	if roll > chance then
		print(
			string.format(
				"[NightMafiaRaidService] Night #%d for %s Base: peaceful night (roll %.2f > %.2f).",
				cycleId,
				slot,
				roll,
				chance
			)
		)
		return
	end

	local minD = math.max(1, cfg.MinNightDelaySeconds)
	local maxD = math.max(minD, cfg.MaxNightDelaySeconds)
	local delaySec = minD + math.random() * (maxD - minD)

	print(
		string.format(
			"[NightMafiaRaidService] Night #%d for %s Base: raid rolled! Arriving in %.1fs.",
			cycleId,
			slot,
			delaySec
		)
	)

	clearPendingRollForSlot(slot)
	pendingRaidBySlot[slot] = task.delay(delaySec, function()
		pendingRaidBySlot[slot] = nil
		local activeLead = BaseService.GetBaseLeadPlayer(slot)
		if not isRunning or not activeLead or not DayNightService.IsNight() then
			return
		end
		if nightCycleId ~= cycleId then
			return
		end
		NightMafiaRaidService.StartRaidForPlayer(activeLead, nil, nil)
	end)
end

local function handleNightStateChanged(): ()
	local isNight = DayNightService.IsNight()
	if isNight then
		nightCycleId += 1
		local thisCycle = nightCycleId
		for _, slot in ipairs(BaseService.GetSlotOrder()) do
			scheduleNightEvaluationForSlot(slot, thisCycle)
		end
	else
		-- Sunrise: cancel pending night rolls/warnings and make any active raids retreat cleanly
		for _, slot in ipairs(BaseService.GetSlotOrder()) do
			clearPendingRollForSlot(slot, "sunrise")
		end
		local activeList: { ActiveRaid } = {}
		for _, raid in pairs(activeRaidsBySlot) do
			table.insert(activeList, raid)
		end
		for _, raid in ipairs(activeList) do
			if not raid.Resolved and not raid.IgnoreDaylight then
				resolveRaidRetreated(raid, "RetreatedDawn", "sunrise")
			end
		end
	end
end

-- Studio-only test bridge so automated Play-mode verification communicates directly
-- with the live running server VM (never created in production servers).
local function setupStudioTestBridge(): ()
	if not RunService:IsStudio() then
		return
	end
	local existing = ServerStorage:FindFirstChild("NightRaidTestBridge")
	if existing then
		existing:Destroy()
	end
	local bf = Instance.new("BindableFunction")
	bf.Name = "NightRaidTestBridge"
	bf.OnInvoke = function(action: string, arg1: any, arg2: any, arg3: any): any
		local plr = if typeof(arg1) == "Instance" and arg1:IsA("Player")
			then arg1
			else Players:GetPlayers()[1]
		local slot = if plr then BaseService.GetPlayerBaseSlot(plr) else nil

		if action == "GetState" then
			local prof = if plr then PlayerDataService.GetProfile(plr) else nil
			return {
				IsNight = DayNightService.IsNight(),
				NightCycleId = nightCycleId,
				Snapshot = if plr then NightMafiaRaidService.GetSnapshot(plr) else nil,
				LastResult = if slot then lastResultBySlot[slot] else nil,
				Coins = if prof then prof.Coins else 0,
				Reputation = if prof then prof.Reputation else 0,
				HasDualStove = if prof then prof.HasDualStove else false,
				HasVIPBooths = if prof then prof.HasVIPBooths else false,
				OwnsMotorbike = if prof then prof.OwnsMotorbike else false,
				RestaurantLevel = if prof then prof.RestaurantLevel else 1,
				Warehouse = if plr then WarehouseService.GetInventorySnapshot(plr) else nil,
			}
		elseif action == "SetNight" then
			local wantNight = (arg1 == true)
			if DayNightService.IsNight() ~= wantNight then
				DayNightService.SkipPhase(nil)
			end
			return DayNightService.IsNight()
		elseif action == "ResetCooldown" and plr then
			if slot then
				lastRaidEndedAt[slot] = nil
				lastRaidNightCycle[slot] = nil
				lastEvaluatedNightCycle[slot] = nil
			end
			playerJoinedAt[plr] = os.clock() - 999
			return true
		elseif action == "EvaluateEligibility" and plr then
			local ok, why = NightMafiaRaidService.EvaluateNightEligibility(plr, arg2 == true)
			return { Ok = ok, Reason = why }
		elseif action == "StartRaid" and plr then
			local ok, msg = NightMafiaRaidService.StartRaidForPlayer(plr, arg2, arg3)
			return { Ok = ok, Message = msg, Snapshot = NightMafiaRaidService.GetSnapshot(plr) }
		elseif action == "ForceCompleteBreach" and plr and slot then
			local raid = activeRaidsBySlot[slot]
			if not raid or raid.Resolved then
				return { Ok = false, Message = "No active raid" }
			end
			raid.StealProgress = 100
			resolveRaidSucceeded(raid)
			-- Attempt a second resolution immediately to guarantee single-resolution lock!
			resolveRaidSucceeded(raid)
			resolveRaidDefeated(raid)
			return {
				Ok = true,
				Result = lastResultBySlot[slot],
				Coins = PlayerDataService.GetProfile(plr).Coins,
				Reputation = PlayerDataService.GetProfile(plr).Reputation,
				Warehouse = WarehouseService.GetInventorySnapshot(plr),
			}
		elseif action == "ClearWarehouseStock" and plr then
			WarehouseService.ClearAllStockForTest(plr)
			return { Warehouse = WarehouseService.GetInventorySnapshot(plr) }
		elseif action == "SeedPermanentUpgradesForTest" and plr then
			local prof = PlayerDataService.GetProfile(plr)
			prof.HasDualStove = true
			prof.HasVIPBooths = true
			prof.OwnsMotorbike = true
			return { HasDualStove = prof.HasDualStove, HasVIPBooths = prof.HasVIPBooths, OwnsMotorbike = prof.OwnsMotorbike }
		elseif action == "KillAllRaiders" and plr and slot then
			local raid = activeRaidsBySlot[slot]
			if not raid or raid.Resolved then
				return { Ok = false, Message = "No active raid" }
			end
			for _, u in ipairs(raid.Units) do
				if u.Humanoid and u.Humanoid.Health > 0 then
					u.Humanoid.Health = 0
				end
			end
			task.wait(0.6)
			return { Ok = true, Snapshot = NightMafiaRaidService.GetSnapshot(plr), Coins = PlayerDataService.GetProfile(plr).Coins, Reputation = PlayerDataService.GetProfile(plr).Reputation }
		elseif action == "SeedTestResources" and plr then
			local prof = PlayerDataService.GetProfile(plr)
			prof.Coins = if typeof(arg2) == "number" then arg2 else 1000
			prof.Reputation = if typeof(arg3) == "number" then arg3 else 200
			WarehouseService.AddIngredient(plr, "fish", 10)
			WarehouseService.AddIngredient(plr, "shrimp", 8)
			return { Coins = prof.Coins, Reputation = prof.Reputation, Warehouse = WarehouseService.GetInventorySnapshot(plr) }
		elseif action == "CancelRaid" and plr then
			return NightMafiaRaidService.CancelRaidForPlayer(plr, "test_cancel")
		end
		return nil
	end
	bf.Parent = ServerStorage
	testBridge = bf
end

function NightMafiaRaidService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	ensureAlertRemote()

	local existing = Workspace:FindFirstChild("NightMafiaRaids")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		raidFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "NightMafiaRaids"
		f.Parent = Workspace
		raidFolder = f
	end

	local now = os.clock()
	for _, plr in ipairs(Players:GetPlayers()) do
		playerJoinedAt[plr] = now
	end

	playerAddedConn = Players.PlayerAdded:Connect(function(plr)
		playerJoinedAt[plr] = os.clock()
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(plr)
		playerJoinedAt[plr] = nil
		lastAlertPhaseKeyByPlayer[plr] = nil
	end)

	unsubBaseReleased = BaseService.OnBaseReleased(function(slot, _, remainingCount)
		if remainingCount == 0 then
			clearPendingRollForSlot(slot, nil)
			local raid = activeRaidsBySlot[slot]
			if raid and not raid.Resolved then
				resolveRaidRetreated(raid, "Cancelled", "base_empty")
			end
			lastEvaluatedNightCycle[slot] = nil
			lastRaidEndedAt[slot] = nil
			lastRaidNightCycle[slot] = nil
		else
			local raid = activeRaidsBySlot[slot]
			if raid and not raid.Owner.Parent then
				local lead = BaseService.GetBaseLeadPlayer(slot)
				if lead then
					raid.Owner = lead
				end
			end
		end
	end)

	nightConn = ReplicatedStorage:GetAttributeChangedSignal("IsNight"):Connect(handleNightStateChanged)
	if DayNightService.IsNight() then
		handleNightStateChanged()
	end

	setupStudioTestBridge()

	aiThread = task.spawn(function()
		local last = os.clock()
		while isRunning do
			task.wait(AI_TICK)
			if not isRunning then
				break
			end
			local t = os.clock()
			local dt = math.clamp(t - last, 0.05, 1.5)
			last = t

			-- Catch bases claimed mid-night so each occupied base is evaluated ONCE per night
			if DayNightService.IsNight() and nightCycleId > 0 then
				for _, slot in ipairs(BaseService.GetSlotOrder()) do
					if lastEvaluatedNightCycle[slot] ~= nightCycleId and BaseService.GetBasePlayerCount(slot) > 0 then
						scheduleNightEvaluationForSlot(slot, nightCycleId)
					end
				end
			end

			local snapshotList: { ActiveRaid } = {}
			for _, raid in pairs(activeRaidsBySlot) do
				table.insert(snapshotList, raid)
			end
			for _, raid in ipairs(snapshotList) do
				stepActiveRaid(raid, t, dt)
			end
		end
	end)

	print("[Food Empire] NightMafiaRaidService started (Co-op Per-Base Nighttime Mafia Raids: Normal, Ninja, Strong & Elite Mafia active)!")
end

function NightMafiaRaidService.Stop(): ()
	isRunning = false
	if aiThread then
		task.cancel(aiThread)
		aiThread = nil
	end
	if nightConn then
		nightConn:Disconnect()
		nightConn = nil
	end
	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	if unsubBaseReleased then
		unsubBaseReleased()
		unsubBaseReleased = nil
	end
	if testBridge then
		testBridge:Destroy()
		testBridge = nil
	end
	for slot in pairs(pendingRaidBySlot) do
		clearPendingRollForSlot(slot)
	end
	local activeList: { ActiveRaid } = {}
	for _, raid in pairs(activeRaidsBySlot) do
		table.insert(activeList, raid)
	end
	for _, raid in ipairs(activeList) do
		resolveRaidRetreated(raid, "Cancelled", "service_stop")
	end
	if raidFolder then
		raidFolder:ClearAllChildren()
	end
end

return NightMafiaRaidService
