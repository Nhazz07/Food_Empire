--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)
local BodyguardConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("BodyguardConfig")
)
local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local DeliveryRunnerService = require("./DeliveryRunnerService")
local BlackMarketService = require("./BlackMarketService")
local MonetizationService = require("./MonetizationService")

type ComputedStats = {
	MaxHP: number,
	Damage: number,
	Range: number,
	WalkSpeed: number,
	Cooldown: number,
	IsRanged: boolean,
	HealAura: number,
	HasStun: boolean,
	ArmorColor: Color3?,
	HelmetColor: Color3?,
	OutfitColor: Color3?,
	WeaponColor: Color3?,
	HasRiotPlate: boolean,
}

type BodyguardAgent = {
	Owner: Player,
	SlotIndex: number,
	ClassSpec: BodyguardConfig.BodyguardClassSpec,
	Stats: ComputedStats,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	StatusLabel: TextLabel,
	LastAttackAt: number,
	LastHealAt: number,
}

local BodyguardService = {}

BodyguardService.MAX_BODYGUARDS = BodyguardConfig.MAX_ACTIVE_GUARDS
BodyguardService.COSTS = { [1] = 280, [2] = 620, [3] = 780, [4] = 1180 }
BodyguardService.STANCE_ORDER = { "Follow", "GuardBistro", "PatrolBase", "Aggressive" }
BodyguardService.STANCE_LABELS = {
	Follow = "FOLLOW ME",
	GuardBistro = "GUARD CENTRAL PARK BISTRO",
	PatrolBase = "DEFEND RESTAURANT HQ",
	Aggressive = "FREE-FIRE AGGRESSIVE",
}

local PROTECT_RADIUS = 52
local RESPAWN_DELAY = 12

function BodyguardService.GetSquadStance(player: Player): string
	local prof = PlayerDataService.GetProfile(player)
	local st = prof.GuardStance
	if typeof(st) == "string" and BodyguardService.STANCE_LABELS[st] then
		return st
	end
	return "Follow"
end

function BodyguardService.SetSquadStance(player: Player, stance: string): (boolean, string)
	if not BodyguardService.STANCE_LABELS[stance] then
		return false, "Unknown Tactical Order!"
	end
	PlayerDataService.SetGuardStance(player, stance)
	local label = BodyguardService.STANCE_LABELS[stance]
	return true, string.format("Squad Tactical Order: %s", label)
end

function BodyguardService.CycleSquadStance(player: Player): (boolean, string)
	local cur = BodyguardService.GetSquadStance(player)
	local nextStance = "Follow"
	for idx, st in ipairs(BodyguardService.STANCE_ORDER) do
		if st == cur then
			nextStance = BodyguardService.STANCE_ORDER[(idx % #BodyguardService.STANCE_ORDER) + 1]
			break
		end
	end
	return BodyguardService.SetSquadStance(player, nextStance)
end

local isRunning = false
local guardFolder: Folder? = nil
local guardsByPlayer: { [Player]: { BodyguardAgent } } = {}
local slotRespawnUntil: { [Player]: { [number]: number } } = {}
local playerUnderAttackUntil: { [Player]: number } = {}
local playerRecallUntil: { [Player]: number } = {}
local playerAttackOrderUntil: { [Player]: number } = {}

function BodyguardService.CommandAttack(player: Player): (boolean, string)
	playerRecallUntil[player] = nil
	playerAttackOrderUntil[player] = os.clock() + 45
	PlayerDataService.SetGuardStance(player, "Aggressive")
	return true, "PERSONAL BODYGUARDS ORDERED TO ATTACK!"
end

function BodyguardService.CommandRecall(player: Player): (boolean, string)
	playerAttackOrderUntil[player] = nil
	playerRecallUntil[player] = os.clock() + 14
	PlayerDataService.SetGuardStance(player, "Follow")
	local list = guardsByPlayer[player]
	local ch = player.Character
	local hrp = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
	if list and hrp and hrp:IsA("BasePart") then
		for _, g in ipairs(list) do
			if g.Model.Parent and g.Humanoid.Health > 0 then
				local dest = hrp.Position + Vector3.new((g.SlotIndex - 2.5) * 4.5, 1, 6.5)
				if (dest - g.Root.Position).Magnitude > 48 then
					g.Model:PivotTo(CFrame.new(dest))
				else
					g.Humanoid:MoveTo(dest)
				end
			end
		end
	end
	return true, "PERSONAL BODYGUARDS RECALLED TO YOUR SIDE!"
end
local charConns: { [Player]: RBXScriptConnection } = {}
local hpConns: { [Player]: RBXScriptConnection } = {}
local aiThread: thread? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local unsubBase: (() -> ())? = nil

function BodyguardService.GetGuardCount(player: Player): number
	local prof = PlayerDataService.GetProfile(player)
	return math.clamp(#prof.ActiveBodyguards, 0, BodyguardConfig.MAX_ACTIVE_GUARDS)
end

function BodyguardService.GetNextCost(player: Player): number?
	local count = BodyguardService.GetGuardCount(player)
	if count >= BodyguardConfig.MAX_ACTIVE_GUARDS then
		return nil
	end
	return BodyguardService.COSTS[count + 1] or 620
end

local function computeGuardStats(player: Player, slotIndex: number, classSpec: BodyguardConfig.BodyguardClassSpec): ComputedStats
	local prof = PlayerDataService.GetProfile(player)
	local loadout = prof.GuardLoadouts[tostring(slotIndex)] or {}

	local maxHP = classSpec.MaxHP
	local dmg = classSpec.Damage
	local rng = classSpec.AttackRange
	local spd = classSpec.WalkSpeed
	local cdMult = 1.0
	local healAura = if classSpec.Id == "TacticalGuard" then 10 else 0
	local hasStun = false
	local armorCol: Color3? = nil
	local helmCol: Color3? = nil
	local outfitCol: Color3? = nil
	local weaponCol: Color3? = nil
	local hasRiotPlate = (classSpec.Id == "HeavyGuard")

	for _, gearId in pairs(loadout) do
		local gSpec = BodyguardConfig.GEAR[gearId]
		if gSpec and prof.OwnedGuardGear[gearId] and BodyguardConfig.IsGearCompatible(classSpec.Id, gearId) then
			maxHP += gSpec.BonusHP
			dmg += gSpec.BonusDamage
			rng += gSpec.BonusRange
			spd += gSpec.BonusSpeed
			cdMult *= gSpec.CooldownMult
			healAura += gSpec.HealAuraBonus
			if gSpec.StunEffect then
				hasStun = true
			end
			if gSpec.Slot == "Armor" then
				armorCol = gSpec.VisualColor
			elseif gSpec.Slot == "Helmet" then
				helmCol = gSpec.VisualColor
			elseif gSpec.Slot == "Outfit" then
				outfitCol = gSpec.VisualColor
			elseif gSpec.Slot == "Weapon" then
				weaponCol = gSpec.VisualColor
			elseif gearId == "GuardRiotPlate" then
				hasRiotPlate = true
			end
		end
	end

	local isRanged = (classSpec.CombatStyle ~= "Melee") or (rng >= 30)
	return {
		MaxHP = math.max(100, math.floor(maxHP)),
		Damage = math.max(10, math.floor(dmg)),
		Range = math.max(12, rng),
		WalkSpeed = math.max(14, spd),
		Cooldown = math.max(0.32, classSpec.AttackCooldown * cdMult),
		IsRanged = isRanged,
		HealAura = healAura,
		HasStun = hasStun,
		ArmorColor = armorCol,
		HelmetColor = helmCol,
		OutfitColor = outfitCol,
		WeaponColor = weaponCol,
		HasRiotPlate = hasRiotPlate,
	}
end

local function spawnGuardHitBurst(pos: Vector3, col: Color3?): ()
	local bp = Instance.new("Part")
	bp.Size = Vector3.new(1, 1, 1)
	bp.CFrame = CFrame.new(pos)
	bp.Transparency = 1
	bp.Anchored = true
	bp.CanCollide = false
	bp.Parent = Workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(col or Color3.fromRGB(255, 224, 78))
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.2, 0.36)
	pe.Speed = NumberRange.new(10, 16)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = bp
	pe:Emit(10)
	task.delay(0.45, function()
		if bp.Parent then bp:Destroy() end
	end)
end

local function getOwnerAnchorPos(owner: Player, slotIndex: number): Vector3
	local offsets = {
		Vector3.new(-6.5, 0, 5.5),
		Vector3.new(6.5, 0, 5.5),
		Vector3.new(-9.5, 0, 9.5),
		Vector3.new(9.5, 0, 9.5),
	}
	local off = offsets[slotIndex] or offsets[1]
	local stance = BodyguardService.GetSquadStance(owner)
	if stance == "GuardBistro" then
		return Vector3.new(48 + off.X, 3.8, 86 + off.Z)
	elseif stance == "PatrolBase" then
		local slot = BaseService.GetPlayerBaseSlot(owner)
		if slot then
			local base = BaseService.GetBaseModel(slot)
			local hq = if base then base:FindFirstChild("RestaurantHQ") else nil
			if hq and hq:IsA("Model") and hq.PrimaryPart then
				local defensePosts = {
					Vector3.new(-10.5, 3.6, 31.0),
					Vector3.new(10.5, 3.6, 31.0),
					Vector3.new(-26.0, 3.6, 25.0),
					Vector3.new(26.0, 3.6, 25.0),
				}
				local postOff = defensePosts[slotIndex] or defensePosts[1]
				return (hq.PrimaryPart.CFrame * CFrame.new(postOff)).Position
			end
			local sp = if base then base:FindFirstChild("BaseSpawn") else nil
			if sp and sp:IsA("BasePart") then
				return sp.Position + Vector3.new(off.X * 1.5, 3.8, off.Z * 1.5)
			end
		end
	end
	local char = owner.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return (root.CFrame * CFrame.new(off)).Position
	end
	local slot = BaseService.GetPlayerBaseSlot(owner)
	if slot then
		local base = BaseService.GetBaseModel(slot)
		local sp = if base then base:FindFirstChild("BaseSpawn") else nil
		if sp and sp:IsA("BasePart") then
			return sp.Position + Vector3.new(off.X, 4, off.Z)
		end
	end
	return Vector3.new(off.X, 5, 20 + off.Z)
end

local function buildBodyguardModel(owner: Player, slotIndex: number, classSpec: BodyguardConfig.BodyguardClassSpec, spawnPos: Vector3): BodyguardAgent
	local stats = computeGuardStats(owner, slotIndex, classSpec)
	local s = classSpec.Scale

	local modelName = string.format("Bodyguard_%d_%s_%d", owner.UserId, classSpec.Id, slotIndex)
	local rig = MafiaVisualBuilder.BuildBodyguardRig(modelName, classSpec.Id, s, CFrame.new(spawnPos), {
		OutfitColor = stats.OutfitColor,
		ArmorColor = stats.ArmorColor,
		HelmetColor = stats.HelmetColor,
		WeaponColor = stats.WeaponColor,
		HasRiotPlate = stats.HasRiotPlate,
		IsRanged = stats.IsRanged,
	}, false)

	local model = rig.Model
	local root = rig.Root
	local head = rig.Head

	-- Restrained Professional Mafia Security Nameplate + Clean Muted HP Bar (Zero Emojis / Zero Neon)
	local bb = Instance.new("BillboardGui")
	bb.Name = "GuardTag"
	bb.Size = UDim2.fromOffset(186, 40)
	bb.StudsOffset = Vector3.new(0, 3.0 * s, 0)
	bb.MaxDistance = 150
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	lbl.BackgroundTransparency = 0.10
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = string.format("%s  #%d", string.upper(classSpec.DisplayName), slotIndex)
	lbl.TextSize = 10
	lbl.TextColor3 = Color3.fromRGB(224, 222, 216)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(72, 76, 86)
	st.Thickness = 1.2
	st.Parent = lbl

	local hpBg = Instance.new("Frame")
	hpBg.Position = UDim2.new(0.03, 0, 0, 23)
	hpBg.Size = UDim2.new(0.94, 0, 0, 13)
	hpBg.BackgroundColor3 = Color3.fromRGB(14, 15, 19)
	hpBg.Parent = bb
	Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 3)
	local hst = Instance.new("UIStroke")
	hst.Color = Color3.fromRGB(54, 58, 66)
	hst.Thickness = 1
	hst.Parent = hpBg

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(78, 128, 96)
	hpFill.Parent = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

	local hpTxt = Instance.new("TextLabel")
	hpTxt.Size = UDim2.fromScale(1, 1)
	hpTxt.BackgroundTransparency = 1
	hpTxt.Font = Enum.Font.GothamBold
	hpTxt.Text = string.format("%d / %d HP", stats.MaxHP, stats.MaxHP)
	hpTxt.TextSize = 9
	hpTxt.TextColor3 = Color3.fromRGB(238, 236, 232)
	hpTxt.ZIndex = 3
	hpTxt.Parent = hpBg

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = stats.MaxHP
	hum.Health = stats.MaxHP
	hum.WalkSpeed = stats.WalkSpeed
	hum.HipHeight = 2.42 * s
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	-- HeavyGuard Passive: Riot Fortress reduces incoming damage by 25%!
	local prevHp = stats.MaxHP
	local adjustingHp = false
	hum.HealthChanged:Connect(function(hp: number)
		if adjustingHp then return end
		if classSpec.Id == "HeavyGuard" and hp < prevHp and hp > 0 then
			local dmgTaken = prevHp - hp
			local refunded = math.floor(dmgTaken * 0.25)
			if refunded > 0 then
				adjustingHp = true
				hum.Health = math.min(hum.MaxHealth, hp + refunded)
				hp = hum.Health
				adjustingHp = false
			end
		end
		prevHp = hp
		local cur = math.max(0, math.ceil(hp))
		local maxH = math.max(1, math.ceil(hum.MaxHealth))
		hpFill.Size = UDim2.fromScale(math.clamp(hp / maxH, 0, 1), 1)
		hpTxt.Text = string.format("%d / %d HP", cur, maxH)
	end)

	model.PrimaryPart = root
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("GuardClassId", classSpec.Id)
	model:SetAttribute("Faction", BaseService.GetPlayerFactionId(owner))
	local ownerSlot = BaseService.GetPlayerBaseSlot(owner)
	if ownerSlot then
		model:SetAttribute("BaseSlot", ownerSlot)
	end
	CollectionService:AddTag(model, "PlayerBodyguardUnit")
	CollectionService:AddTag(model, "AnimatedRaiderLimbs")
	model.Parent = guardFolder or Workspace

	return {
		Owner = owner,
		SlotIndex = slotIndex,
		ClassSpec = classSpec,
		Stats = stats,
		Model = model,
		Humanoid = hum,
		Root = root,
		StatusLabel = lbl,
		LastAttackAt = 0,
		LastHealAt = 0,
	}
end

local function clearPlayerGuards(player: Player): ()
	local list = guardsByPlayer[player]
	if list then
		for _, g in ipairs(list) do
			if g.Model.Parent then g.Model:Destroy() end
		end
		guardsByPlayer[player] = nil
	end
	slotRespawnUntil[player] = nil
end

function BodyguardService.RebuildGuardsForPlayer(player: Player): ()
	clearPlayerGuards(player)
	BodyguardService.SyncGuardsForPlayer(player)
end

function BodyguardService.SyncGuardsForPlayer(player: Player): ()
	if not BaseService.GetPlayerBaseSlot(player) then
		return
	end
	local prof = PlayerDataService.GetProfile(player)
	local activeClasses = prof.ActiveBodyguards
	local list = guardsByPlayer[player]
	if not list then
		list = {}
		guardsByPlayer[player] = list
	end

	for i = #list, 1, -1 do
		if not list[i].Model.Parent or list[i].Humanoid.Health <= 0 then
			table.remove(list, i)
		end
	end

	for slotIdx = 1, math.min(#activeClasses, BodyguardConfig.MAX_ACTIVE_GUARDS) do
		local classId = activeClasses[slotIdx] :: BodyguardConfig.GuardClassId
		local spec = BodyguardConfig.CLASSES[classId] or BodyguardConfig.CLASSES.BasicGuard
		-- Security check: never spawn a Robux-only guard unless the player owns its Game Pass or unlocked it legitimately with Gold!
		if spec.RobuxItemId and not MonetizationService.HasPass(player, spec.RobuxItemId) and prof.UnlockedGuardClasses[spec.Id] ~= true then
			continue
		end
		local existsForSlot = false
		for _, ag in ipairs(list) do
			if ag.SlotIndex == slotIdx then
				existsForSlot = true
				break
			end
		end
		if not existsForSlot then
			local cdMap = slotRespawnUntil[player]
			if cdMap and (cdMap[slotIdx] or 0) > os.clock() then
				continue
			end
			local sp = getOwnerAnchorPos(player, slotIdx)
			local agent = buildBodyguardModel(player, slotIdx, spec, sp)
			agent.Humanoid.Died:Connect(function()
				local map = slotRespawnUntil[player]
				if not map then
					map = {}
					slotRespawnUntil[player] = map
				end
				map[slotIdx] = os.clock() + RESPAWN_DELAY
				MafiaVisualBuilder.PlayDeathSequence(agent.Model, spec.Id == "BossBodyguard", function(impactPos: Vector3)
					BlackMarketService.BroadcastSFX("BodyDrop", impactPos)
				end)
				task.delay(RESPAWN_DELAY + 0.15, function()
					if isRunning and player.Parent then
						BodyguardService.SyncGuardsForPlayer(player)
					end
				end)
			end)
			table.insert(list, agent)
		end
	end
end

-- Recruit any Bodyguard Class (supports Gold unlock, optional Robux Pass unlock, and restaurant defense deployment!)
function BodyguardService.TryRecruitClass(player: Player, classId: string, targetSlot: number?, useRobux: boolean?, autoDefendHQ: boolean?): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Restaurant Plaza first!"
	end
	local spec = BodyguardConfig.CLASSES[classId :: BodyguardConfig.GuardClassId]
	if not spec then
		return false, "Unknown Bodyguard class!"
	end

	local prof = PlayerDataService.GetProfile(player)
	local hasPass = spec.RobuxItemId ~= nil and MonetizationService.HasPass(player, spec.RobuxItemId)

	-- Explicit Robux Purchase Request OR Robux-exclusive (Cost <= 0) pass check
	if spec.RobuxItemId and not hasPass and (useRobux == true or spec.Cost <= 0) then
		return MonetizationService.TryPromptPurchase(player, spec.RobuxItemId)
	end

	local alreadyUnlocked = hasPass or (prof.UnlockedGuardClasses[spec.Id] == true)

	-- Dual-Currency Robux Option for Gold-based Bodyguards (unlocks immediately via Robux without Gold or level gate!)
	if useRobux == true and not alreadyUnlocked and typeof(spec.RobuxPrice) == "number" and spec.RobuxPrice > 0 then
		return MonetizationService.TryPromptDualPurchase(
			player,
			"Guard_" .. spec.Id,
			spec.RobuxPrice,
			spec.DisplayName,
			function()
				prof.UnlockedGuardClasses[spec.Id] = true
				return BodyguardService.TryRecruitClass(player, classId, targetSlot, false, autoDefendHQ)
			end
		)
	end

	if not alreadyUnlocked and prof.Level < spec.RequiredLevel then
		return false, string.format("Requires Player Lv.%d to recruit %s!", spec.RequiredLevel, spec.DisplayName)
	end

	-- Unlock class once with Gold (or Robux pass); once unlocked, assign/swap freely across your 4 squad slots!
	local paidDealDiscount = false
	local dealDiscPct = 0
	local effectiveCost = spec.Cost
	local savedGold = 0
	if not alreadyUnlocked then
		if BodyguardConfig.GetClassMarketTier(spec.Id) == "BlackMarket" then
			effectiveCost, paidDealDiscount, dealDiscPct = BlackMarketService.GetEffectivePrice("GuardClass", spec.Id, spec.Cost)
			savedGold = math.max(0, spec.Cost - effectiveCost)
		end
		if effectiveCost <= 0 or not PlayerDataService.SpendCoins(player, effectiveCost) then
			return false, string.format("Need %d Gold to recruit %s!", effectiveCost, spec.DisplayName)
		end
	end

	if autoDefendHQ == true then
		PlayerDataService.SetGuardStance(player, "PatrolBase")
	end

	local finalSlotIdx: number
	if typeof(targetSlot) == "number" and targetSlot >= 1 and targetSlot <= BodyguardConfig.MAX_ACTIVE_GUARDS then
		finalSlotIdx = math.floor(targetSlot)
		if finalSlotIdx > #prof.ActiveBodyguards then
			PlayerDataService.AddBodyguardClass(player, spec.Id)
			finalSlotIdx = #prof.ActiveBodyguards
		else
			PlayerDataService.ReplaceBodyguardSlot(player, finalSlotIdx, spec.Id)
		end
	else
		PlayerDataService.AddBodyguardClass(player, spec.Id)
		finalSlotIdx = #prof.ActiveBodyguards
	end

	-- Prune any previously equipped gear in that slot that is incompatible with the new class
	local slotKey = tostring(finalSlotIdx)
	local ld = prof.GuardLoadouts[slotKey]
	if ld then
		for gearSlot, eqGearId in pairs(ld) do
			if not BodyguardConfig.IsGearCompatible(spec.Id, eqGearId) then
				PlayerDataService.SetGuardGearSlot(player, slotKey, gearSlot, nil)
			end
		end
	end

	BodyguardService.RebuildGuardsForPlayer(player)

	-- In-world 3D Syndicate Brass Crest Ring + Rising Gold Embers & Full-Screen Bodyguard Welcome Cinematic!
	local anchorPos = getOwnerAnchorPos(player, finalSlotIdx)
	local crest = Instance.new("Part")
	crest.Name = "BodyguardArrivalCrest"
	crest.Shape = Enum.PartType.Cylinder
	crest.Size = Vector3.new(0.24, 3.2, 3.2)
	crest.CFrame = CFrame.new(anchorPos.X, math.max(1.5, anchorPos.Y - 2.4), anchorPos.Z) * CFrame.Angles(0, 0, math.rad(90))
	crest.Color = Color3.fromRGB(196, 158, 82)
	crest.Material = Enum.Material.Metal
	crest.Transparency = 0.22
	crest.Anchored = true
	crest.CanCollide = false
	crest.Parent = Workspace
	TweenService:Create(crest, TweenInfo.new(0.65, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.16, 15.0, 15.0),
		Transparency = 0.90,
	}):Play()
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(Color3.fromRGB(252, 220, 128), Color3.fromRGB(172, 142, 76))
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
	embers.Lifetime = NumberRange.new(0.8, 1.4)
	embers.Speed = NumberRange.new(7, 15)
	embers.SpreadAngle = Vector2.new(95, 95)
	embers.Parent = crest
	embers:Emit(26)
	task.delay(1.8, function()
		if crest.Parent then crest:Destroy() end
	end)

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local welcomeEv = if remotes then remotes:FindFirstChild("PlayUnitWelcome") else nil
	if welcomeEv and welcomeEv:IsA("RemoteEvent") then
		welcomeEv:FireClient(player, {
			Kind = "Bodyguard",
			Badge = if alreadyUnlocked
				then string.format("SQUAD SLOT #%d REDEPLOYED", finalSlotIdx)
				else string.format("NEW BODYGUARD RECRUITED  |  SLOT #%d", finalSlotIdx),
			Title = spec.DisplayName,
			Subtitle = string.format("%s — Sworn to guard your Empire! Press [Y] to Attack or [Z] to Recall.", spec.Role),
			PreviewId = spec.Id,
		})
	end

	local verb = if alreadyUnlocked then "Assigned" else "Recruited"
	if paidDealDiscount then
		return true, string.format("DON VINNIE'S DROP (-%d%%)! Recruited %s to Slot #%d for %dG (saved %dG)!", dealDiscPct, spec.DisplayName, finalSlotIdx, effectiveCost, savedGold)
	end
	return true, string.format("%s %s (%s) to Guard Slot #%d", verb, spec.DisplayName, spec.Role, finalSlotIdx)
end

-- Legacy quick-hire compatibility (called from Empire Upgrades tab)
function BodyguardService.TryHireBodyguard(player: Player): (boolean, string)
	local count = BodyguardService.GetGuardCount(player)
	if count >= BodyguardConfig.MAX_ACTIVE_GUARDS then
		return false, "Squad full (4/4)! Open Black Market -> Bodyguards to upgrade classes!"
	end
	local prof = PlayerDataService.GetProfile(player)
	local defaultOrder: { BodyguardConfig.GuardClassId } = { "BasicGuard", "HeavyGuard", "AssaultGuard", "TacticalGuard" }
	local pick = defaultOrder[count + 1] or "BasicGuard"
	local spec = BodyguardConfig.CLASSES[pick]
	if prof.Level < spec.RequiredLevel then
		pick = "BasicGuard"
	end
	return BodyguardService.TryRecruitClass(player, pick, nil)
end

-- Buy a piece of Bodyguard Equipment (Server-Validated, Dual-Currency Gold OR Robux!)
function BodyguardService.TryBuyGear(player: Player, gearId: string, useRobux: boolean?): (boolean, string)
	local gSpec = BodyguardConfig.GEAR[gearId]
	if not gSpec then
		return false, "Unknown Bodyguard equipment!"
	end
	if gSpec.RobuxItemId then
		return MonetizationService.TryPromptPurchase(player, gSpec.RobuxItemId)
	end

	local prof = PlayerDataService.GetProfile(player)
	if prof.OwnedGuardGear[gearId] then
		return false, gSpec.DisplayName .. " is already owned! Equip it onto a compatible Bodyguard."
	end

	local function grantGearAndAutoEquip(): (boolean, string)
		PlayerDataService.UnlockGuardGear(player, gearId)
		-- Auto-equip onto the first compatible active bodyguard if that slot is currently empty!
		for idx, classId in ipairs(prof.ActiveBodyguards) do
			if BodyguardConfig.IsGearCompatible(classId :: BodyguardConfig.GuardClassId, gearId) then
				local sk = tostring(idx)
				local ld = prof.GuardLoadouts[sk]
				if not ld or not ld[gSpec.Slot] then
					PlayerDataService.SetGuardGearSlot(player, sk, gSpec.Slot, gearId)
					BodyguardService.RebuildGuardsForPlayer(player)
					return true, string.format("Unlocked & equipped %s on Guard #%d", gSpec.DisplayName, idx)
				end
			end
		end
		return true, string.format("Unlocked %s — equip onto a compatible Bodyguard", gSpec.DisplayName)
	end

	if useRobux == true and typeof(gSpec.RobuxPrice) == "number" and gSpec.RobuxPrice > 0 then
		return MonetizationService.TryPromptDualPurchase(
			player,
			"GuardGear_" .. gearId,
			gSpec.RobuxPrice,
			gSpec.DisplayName,
			grantGearAndAutoEquip
		)
	end

	if prof.Level < gSpec.RequiredLevel then
		return false, string.format("Requires Player Lv.%d for %s!", gSpec.RequiredLevel, gSpec.DisplayName)
	end
	local effectivePrice = gSpec.Price
	local isDeal = false
	local discPct = 0
	if BodyguardConfig.GetGearMarketTier(gearId) == "BlackMarket" then
		effectivePrice, isDeal, discPct = BlackMarketService.GetEffectivePrice("GuardGear", gearId, gSpec.Price)
	end
	if not PlayerDataService.SpendCoins(player, effectivePrice) then
		return false, string.format("Need %d Gold to buy %s!", effectivePrice, gSpec.DisplayName)
	end

	local ok, msg = grantGearAndAutoEquip()
	if ok and isDeal then
		return true, string.format("DON VINNIE'S DROP (-%d%%)! %s for %dG (saved %dG)!", discPct, msg, effectivePrice, math.max(0, gSpec.Price - effectivePrice))
	end
	return ok, msg
end

-- Equip Owned Gear onto a Specific Bodyguard Slot (Strict Server Compatibility Check!)
function BodyguardService.TryEquipGear(player: Player, slotIndex: number, gearId: string): (boolean, string)
	local gSpec = BodyguardConfig.GEAR[gearId]
	if not gSpec then
		return false, "Unknown equipment item!"
	end
	local prof = PlayerDataService.GetProfile(player)
	local ownsViaPass = gSpec.RobuxItemId ~= nil and MonetizationService.HasPass(player, gSpec.RobuxItemId)
	if not prof.OwnedGuardGear[gearId] and not ownsViaPass then
		return false, "Buy " .. gSpec.DisplayName .. " first!"
	end
	if ownsViaPass and not prof.OwnedGuardGear[gearId] then
		PlayerDataService.UnlockGuardGear(player, gearId)
	end

	local idx = math.floor(slotIndex)
	local classId = prof.ActiveBodyguards[idx]
	if not classId then
		return false, "Recruit a Bodyguard into Slot #" .. tostring(idx) .. " first!"
	end

	if not BodyguardConfig.IsGearCompatible(classId :: BodyguardConfig.GuardClassId, gearId) then
		local cSpec = BodyguardConfig.CLASSES[classId :: BodyguardConfig.GuardClassId]
		return false, string.format("%s cannot equip %s (incompatible class)!", if cSpec then cSpec.DisplayName else classId, gSpec.DisplayName)
	end

	PlayerDataService.SetGuardGearSlot(player, tostring(idx), gSpec.Slot, gearId)
	BodyguardService.RebuildGuardsForPlayer(player)
	return true, string.format("Equipped %s onto Guard #%d", gSpec.DisplayName, idx)
end

function BodyguardService.GetBodyguardPayload(player: Player): { [string]: any }
	local prof = PlayerDataService.GetProfile(player)
	return {
		MaxSlots = BodyguardConfig.MAX_ACTIVE_GUARDS,
		ActiveSquad = prof.ActiveBodyguards,
		UnlockedClasses = prof.UnlockedGuardClasses,
		OwnedGear = prof.OwnedGuardGear,
		Loadouts = prof.GuardLoadouts,
		Stance = BodyguardService.GetSquadStance(player),
		StanceLabel = BodyguardService.STANCE_LABELS[BodyguardService.GetSquadStance(player)] or "FOLLOW ME",
	}
end

local function hookPlayerDamageDefense(player: Player): ()
	local function attachChar(char: Model)
		if hpConns[player] then hpConns[player]:Disconnect(); hpConns[player] = nil end
		local hum = char:WaitForChild("Humanoid", 10)
		if hum and hum:IsA("Humanoid") then
			local lastHp = hum.Health
			hpConns[player] = hum.HealthChanged:Connect(function(newHp: number)
				if newHp < lastHp then
					playerUnderAttackUntil[player] = os.clock() + 10
				end
				lastHp = newHp
			end)
		end
	end

	if charConns[player] then charConns[player]:Disconnect() end
	charConns[player] = player.CharacterAdded:Connect(attachChar)
	if player.Character then
		task.spawn(attachChar, player.Character)
	end
end

local function hasPlayerStolenShipment(player: Player): boolean
	local untilAttr = player:GetAttribute("StolenShipmentUntil")
	if typeof(untilAttr) == "number" and untilAttr > os.clock() then
		return true
	end
	return player:GetAttribute("CarryingCrate") ~= nil
end

local function findBestHostileForGuard(owner: Player, anchor: Vector3, radius: number, prioritizeBoss: boolean, hasAttackOrder: boolean): (Humanoid?, BasePart?, Model?)
	local bestHum: Humanoid? = nil
	local bestRoot: BasePart? = nil
	local bestModel: Model? = nil
	local bestScore = -math.huge
	local ownerStoleShipment = hasPlayerStolenShipment(owner)

	for _, tagName in ipairs({ "MafiaUnit", "RivalAIUnit", "ApexMafiaUnit", "RivalSamuraiUnit", "PenthouseBossUnit" }) do
		for _, unit in ipairs(CollectionService:GetTagged(tagName)) do
			if unit:IsA("Model") then
				local r = unit:FindFirstChild("HumanoidRootPart")
				local h = unit:FindFirstChildOfClass("Humanoid")
				if r and r:IsA("BasePart") and h and h.Health > 0 then
					local isEventRaider = (unit.Name == "BistroExtortionEnforcer") or (string.find(unit.Name, "GangWarEnforcer") ~= nil) or (tagName == "PenthouseBossUnit") or (unit:GetAttribute("UnderRevenge") == true)
					local isCentralParkSamurai = (tagName == "RivalSamuraiUnit") or (tagName == "ApexMafiaUnit")
					local isProvoked = unit:GetAttribute("Provoked") == true
					local inCentralSpinZone = (not isEventRaider) and (isCentralParkSamurai
						or (math.abs(r.Position.X) <= 195 and math.abs(r.Position.Z) <= 195)
						or (unit:GetAttribute("RivalFactionId") == "CrimsonDonEmpire"))
					-- Respect Central Market Peace Truce (Rivals, Mafia Restaurants & Samurai/Ninja) unless owner stole a shipment, they are provoked, or owner pressed ATTACK ALL [Y]!
					local allowEngage = (not inCentralSpinZone) or ownerStoleShipment or isProvoked or (isCentralParkSamurai and hasAttackOrder)
					if allowEngage then
						local d = (r.Position - anchor).Magnitude
						if d <= radius then
							local isBoss = unit:GetAttribute("IsMafiaBoss") == true or unit:GetAttribute("IsRivalBoss") == true
							local diff = unit:GetAttribute("RivalDifficulty")
							local priorityBonus = 0
							if prioritizeBoss then
								if isBoss then priorityBonus = 120
								elseif diff == "Elite" then priorityBonus = 70
								elseif diff == "Hard" then priorityBonus = 35 end
							end
							local score = priorityBonus - d
							if score > bestScore then
								bestScore = score; bestHum = h; bestRoot = r; bestModel = unit
							end
						end
					end
				end
			end
		end
	end
	return bestHum, bestRoot, bestModel
end

local function hasBossAuraNearby(owner: Player, guardPos: Vector3): boolean
	local list = guardsByPlayer[owner]
	if not list then return false end
	for _, g in ipairs(list) do
		if g.ClassSpec.Id == "BossBodyguard" and g.Model.Parent and g.Humanoid.Health > 0 then
			if (g.Root.Position - guardPos).Magnitude <= 50 then
				return true
			end
		end
	end
	return false
end

local function stepGuard(agent: BodyguardAgent): ()
	if not agent.Model.Parent or agent.Humanoid.Health <= 0 then
		return
	end
	local owner = agent.Owner
	local char = owner.Character
	local ownerRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local ownerHum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not ownerRoot or not ownerRoot:IsA("BasePart") then
		return
	end

	local now = os.clock()
	local ownerPos = ownerRoot.Position
	local guardPos = agent.Root.Position
	local stats = agent.Stats
	local stance = BodyguardService.GetSquadStance(owner)
	local anchorPos = getOwnerAnchorPos(owner, agent.SlotIndex)
	local ridingSedan = (char ~= nil and char:GetAttribute("RidingMafiaSedan") == true) and (stance == "Follow" or stance == "Aggressive")

	-- Field Medic Aura (TacticalGuard or Squad Trauma Med-Kit): heals owner's Base HP & self every 5s!
	if stats.HealAura > 0 and (now - agent.LastHealAt) >= 5.0 then
		agent.LastHealAt = now
		if ownerHum and ownerHum.Health > 0 and ownerHum.Health < 100 then
			ownerHum.Health = math.min(100, ownerHum.Health + stats.HealAura)
		end
		if agent.Humanoid.Health < agent.Humanoid.MaxHealth then
			agent.Humanoid.Health = math.min(agent.Humanoid.MaxHealth, agent.Humanoid.Health + stats.HealAura)
		end
	end

	-- Armored Black Mafia Sedan Passenger Mode: Bodyguards physically sit inside the vehicle cabin and provide drive-by fire!
	if ridingSedan then
		local passengerSeats = {
			CFrame.new(1.55, -0.35, -0.25),
			CFrame.new(-1.55, -0.35, 2.25),
			CFrame.new(1.55, -0.35, 2.25),
			CFrame.new(0, -0.35, 2.45),
		}
		local seatCF = passengerSeats[agent.SlotIndex] or passengerSeats[1]
		agent.Model:PivotTo(ownerRoot.CFrame * seatCF)
		agent.StatusLabel.Text = string.format("%s  |  IN SEDAN", string.upper(agent.ClassSpec.DisplayName))
		agent.StatusLabel.TextColor3 = Color3.fromRGB(224, 186, 114)
		if stats.IsRanged and (now - agent.LastAttackAt) >= stats.Cooldown then
			local hasOrder = (playerAttackOrderUntil[owner] or 0) > now
			local tHum, tRoot, tModel = findBestHostileForGuard(owner, ownerPos, stats.Range, agent.ClassSpec.CombatStyle == "Sniper", hasOrder)
			if tHum and tRoot and tModel then
				agent.LastAttackAt = now
				local finalDmg = math.floor(stats.Damage * (if hasBossAuraNearby(owner, agent.Root.Position) then 1.20 else 1.0))
				tHum:TakeDamage(finalDmg)
				local fromPos = agent.Root.Position + Vector3.new(0, 1.4, 0)
				local tracerCol = if agent.ClassSpec.Id == "BossBodyguard" then Color3.fromRGB(255, 206, 56) else Color3.fromRGB(92, 228, 255)
				BlackMarketService.SpawnBulletTracer(fromPos, tRoot.Position, tracerCol)
				BlackMarketService.BroadcastSFX("SMGShot", fromPos)
				BlackMarketService.BroadcastSFX(if tHum.Health <= 0 then "EnemyDeathScream" else "EnemyHitScream", tRoot.Position)
			end
		end
		return
	end

	-- Regroup smoothly if owner sped away or stance redeployed to Bistro / Base!
	if (anchorPos - guardPos).Magnitude > 125 then
		agent.Model:PivotTo(CFrame.new(anchorPos))
		return
	end

	-- Intelligent Target Selection (Respects Recall Hold & Expanded Attack Order!)
	local isRecalling = (playerRecallUntil[owner] or 0) > now
	local hasAttackOrder = (playerAttackOrderUntil[owner] or 0) > now
	local baseAlert = if hasAttackOrder then 135 elseif stance == "Aggressive" then 88 elseif (playerUnderAttackUntil[owner] or 0) > now then 74 else PROTECT_RADIUS
	local alertRadius = math.max(stats.Range + (if stance == "Aggressive" or hasAttackOrder then 28 else 0), baseAlert)
	local targetHum: Humanoid? = nil
	local targetRoot: BasePart? = nil
	local targetModel: Model? = nil
	if not isRecalling then
		targetHum, targetRoot, targetModel = findBestHostileForGuard(owner, anchorPos, alertRadius, agent.ClassSpec.CombatStyle == "Sniper", hasAttackOrder)
	end

	if not targetHum and (stance == "Follow" or stance == "Aggressive") then
		local runnerPos = DeliveryRunnerService.GetActiveRunnerPosition(owner)
		if runnerPos and (runnerPos - ownerPos).Magnitude < 120 then
			targetHum, targetRoot, targetModel = findBestHostileForGuard(owner, runnerPos, 46, false, hasAttackOrder)
		end
	end

	if targetHum and targetRoot and targetModel then
		agent.StatusLabel.Text = string.format("%s  |  ENGAGING", string.upper(agent.ClassSpec.DisplayName))
		agent.StatusLabel.TextColor3 = Color3.fromRGB(224, 186, 114)
		local dist = (targetRoot.Position - guardPos).Magnitude
		local auraMult = if hasBossAuraNearby(owner, guardPos) then 1.20 else 1.0
		local finalDmg = math.floor(stats.Damage * auraMult)

		if dist <= stats.Range then
			if (now - agent.LastAttackAt) >= stats.Cooldown then
				agent.LastAttackAt = now
				MafiaVisualBuilder.TriggerAttackAnim(agent.Model)
				local hitDir = targetRoot.Position - guardPos
				if hitDir.Magnitude > 0.05 then
					targetModel:SetAttribute("LastHitDir", hitDir.Unit)
				end
				targetHum:TakeDamage(finalDmg)

				-- Tactical Stun Breacher slow effect
				if stats.HasStun and targetHum.WalkSpeed > 8 then
					local origSpd = targetHum.WalkSpeed
					targetHum.WalkSpeed = math.max(7, origSpd * 0.55)
					task.delay(1.5, function()
						if targetHum.Parent and targetHum.Health > 0 then
							targetHum.WalkSpeed = origSpd
						end
					end)
				end

				if stats.IsRanged then
					local fromPos = agent.Root.Position + Vector3.new(0, 1.4, 0)
					local tracerCol = if agent.ClassSpec.Id == "BossBodyguard" then Color3.fromRGB(255, 206, 56) else Color3.fromRGB(92, 228, 255)
					BlackMarketService.SpawnBulletTracer(fromPos, targetRoot.Position, tracerCol)
					local sfx = if agent.ClassSpec.CombatStyle == "Sniper"
						then "SniperShot"
						elseif agent.ClassSpec.CombatStyle == "Shotgun" then "ShotgunBlast"
						elseif agent.ClassSpec.CombatStyle == "Rifle" then "RifleShot"
						else "PistolShot"
					BlackMarketService.BroadcastSFX(sfx, fromPos)
				else
					spawnGuardHitBurst(targetRoot.Position, agent.ClassSpec.AccentColor)
					BlackMarketService.BroadcastSFX("MeleeHit", targetRoot.Position)
				end
				BlackMarketService.BroadcastSFX(if targetHum.Health <= 0 then "EnemyDeathScream" else "EnemyHitScream", targetRoot.Position)

				if targetHum.Health <= 0 then
					local isMafia = CollectionService:HasTag(targetModel, "MafiaUnit")
					local isMafiaBoss = targetModel:GetAttribute("IsMafiaBoss") == true
					local bGold = targetModel:GetAttribute("BountyGold")
					local bExp = targetModel:GetAttribute("BountyExp")
					local bRep = targetModel:GetAttribute("BountyRep")
					local rewardGold = if typeof(bGold) == "number" then bGold elseif isMafiaBoss then 220 elseif isMafia then 90 else 45
					local rewardExp = if typeof(bExp) == "number" then bExp else 28
					local rewardRep = if typeof(bRep) == "number" then bRep elseif isMafiaBoss then 45 elseif isMafia then 20 else 12
					PlayerDataService.AddRewards(owner, rewardGold, rewardExp, rewardRep)
				end
			end

			-- Ranged/Sniper guards hold tactical standoff range instead of charging into melee!
			if agent.ClassSpec.CombatStyle == "Sniper" and dist < 55 then
				local retreatPos = getOwnerAnchorPos(owner, agent.SlotIndex)
				agent.Humanoid:MoveTo(retreatPos)
			elseif stats.IsRanged and dist < math.min(28, stats.Range * 0.45) then
				agent.Humanoid:MoveTo(guardPos)
			else
				agent.Humanoid:MoveTo(targetRoot.Position)
			end
		else
			agent.Humanoid:MoveTo(targetRoot.Position)
		end
		return
	end

	-- Calm Escort / Stationed Guard Mode
	local stanceBadge = if stance == "GuardBistro" then "  |  BISTRO"
		elseif stance == "PatrolBase" then "  |  PATROL"
		elseif stance == "Aggressive" then "  |  AGGRO"
		else ""
	agent.StatusLabel.Text = string.format("%s  #%d%s", string.upper(agent.ClassSpec.DisplayName), agent.SlotIndex, stanceBadge)
	agent.StatusLabel.TextColor3 = Color3.fromRGB(224, 222, 216)
	local escortPos = anchorPos
	if (escortPos - guardPos).Magnitude > 5.5 then
		agent.Humanoid:MoveTo(escortPos)
	end
end

function BodyguardService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local existing = Workspace:FindFirstChild("PlayerBodyguards")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		guardFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "PlayerBodyguards"
		f.Parent = Workspace
		guardFolder = f
	end

	unsubBase = BaseService.OnBaseAssigned(function(player)
		BodyguardService.SyncGuardsForPlayer(player)
	end)

	Players.PlayerAdded:Connect(hookPlayerDamageDefense)
	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayerDamageDefense(p)
		BodyguardService.SyncGuardsForPlayer(p)
	end

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		clearPlayerGuards(player)
		playerUnderAttackUntil[player] = nil
		if charConns[player] then charConns[player]:Disconnect(); charConns[player] = nil end
		if hpConns[player] then hpConns[player]:Disconnect(); hpConns[player] = nil end
	end)

	aiThread = task.spawn(function()
		while isRunning do
			task.wait(0.42)
			if not isRunning then
				break
			end
			for _, player in ipairs(Players:GetPlayers()) do
				if BodyguardService.GetGuardCount(player) > 0 then
					BodyguardService.SyncGuardsForPlayer(player)
				end
				local list = guardsByPlayer[player]
				if list then
					for _, g in ipairs(list) do
						stepGuard(g)
					end
				end
			end
		end
	end)

	print("[Food Empire] BodyguardService started (7 Recruitable Classes + Compatible Gear & Smart Combat AI active)!")
end

function BodyguardService.Stop(): ()
	isRunning = false
	if aiThread then task.cancel(aiThread); aiThread = nil end
	if unsubBase then unsubBase(); unsubBase = nil end
	if playerRemovingConn then playerRemovingConn:Disconnect(); playerRemovingConn = nil end
	for p in pairs(guardsByPlayer) do
		clearPlayerGuards(p)
	end
end

return BodyguardService
