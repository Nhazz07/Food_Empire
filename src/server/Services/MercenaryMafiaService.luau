--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local PlayerDataService = require("./PlayerDataService")
local BlackMarketService = require("./BlackMarketService")
local MonetizationService = require("./MonetizationService")
local MafiaRestaurantService = require("./MafiaRestaurantService")

export type MercenaryType = "Samurai" | "Ninja"

type MercenaryAgent = {
	Owner: Player,
	MercType: MercenaryType,
	Index: number,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	StatusLabel: TextLabel,
	Damage: number,
	Cooldown: number,
	LastAttackAt: number,
}

type MercenaryContract = {
	MercType: MercenaryType,
	ExpiresAt: number,
	Mode: "Attack" | "Recall",
	ExplicitAttackOrder: boolean,
	TargetRestaurantId: string?, -- nil = Escort / Hunt Nearby; string = Assault & Conquer that Mafia Restaurant!
	Agents: { MercenaryAgent },
}

local MercenaryMafiaService = {}

MercenaryMafiaService.GOLD_COST = 20000
MercenaryMafiaService.CONTRACT_SECONDS = 300 -- Exact 5-minute mercenary mafia contract!

local contracts: { [Player]: MercenaryContract } = {}
local mercFolder: Folder? = nil
local isRunning = false
local aiThread: thread? = nil
local onChangedCb: ((player: Player) -> ())? = nil

function MercenaryMafiaService.SetChangedCallback(cb: (player: Player) -> ()): ()
	onChangedCb = cb
end

local function sendToast(player: Player, msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg)
	end
end

local function clearContract(player: Player): ()
	local c = contracts[player]
	if not c then return end
	for _, ag in ipairs(c.Agents) do
		if ag.Model.Parent then ag.Model:Destroy() end
	end
	contracts[player] = nil
end

local function spawnMercenaryUnit(owner: Player, mercType: MercenaryType, idx: number, spawnPos: Vector3): MercenaryAgent
	local isSamurai = (mercType == "Samurai")
	local rigKind: "SamuraiMafia" | "NinjaMafia" = if isSamurai then "SamuraiMafia" else "NinjaMafia"
	-- Slightly stronger than Rival Samurai (1050 HP / 85 DMG) & Rival Ninja (920 HP / 78 DMG) so your hired squad dominates duels!
	local maxHP = if isSamurai then 1550 else 1350
	local dmg = if isSamurai then 134 else 124
	local cd = if isSamurai then 0.48 else 0.38
	local spd = if isSamurai then 25 else 29
	local title = if isSamurai then string.format("HIRED SAMURAI MAFIA #%d", idx) else string.format("HIRED NINJA MAFIA #%d", idx)

	local rig = MafiaVisualBuilder.BuildSyndicateSpecialistRig(
		string.format("Mercenary_%s_%d_%d", mercType, owner.UserId, idx),
		rigKind,
		if isSamurai then 1.08 else 1.02,
		CFrame.new(spawnPos),
		false
	)
	local model = rig.Model
	local root = rig.Root
	local head = rig.Head

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(196, 38)
	bb.StudsOffset = Vector3.new(0, 3.1, 0)
	bb.MaxDistance = 160
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 19)
	lbl.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = title
	lbl.TextSize = 10
	lbl.TextColor3 = if isSamurai then Color3.fromRGB(234, 184, 114) else Color3.fromRGB(198, 212, 232)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)
	local st = Instance.new("UIStroke")
	st.Color = if isSamurai then Color3.fromRGB(154, 34, 42) else Color3.fromRGB(72, 82, 102)
	st.Thickness = 1.2
	st.Parent = lbl

	local hpBg = Instance.new("Frame")
	hpBg.Position = UDim2.new(0.03, 0, 0, 22)
	hpBg.Size = UDim2.new(0.94, 0, 0, 12)
	hpBg.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
	hpBg.Parent = bb
	Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 3)

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(82, 146, 102)
	hpFill.Parent = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = maxHP
	hum.Health = maxHP
	hum.WalkSpeed = spd
	hum.HipHeight = 2.42 * (if isSamurai then 1.08 else 1.02)
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	hum.HealthChanged:Connect(function(hp: number)
		hpFill.Size = UDim2.fromScale(math.clamp(hp / math.max(1, hum.MaxHealth), 0, 1), 1)
	end)

	hum.Died:Connect(function()
		MafiaVisualBuilder.PlayDeathSequence(model, false, function(impactPos: Vector3)
			BlackMarketService.BroadcastSFX("BodyDrop", impactPos)
		end)
	end)

	model.PrimaryPart = root
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("MercenaryType", mercType)
	CollectionService:AddTag(model, "MercenaryMafiaUnit")
	CollectionService:AddTag(model, "AnimatedRaiderLimbs")
	model.Parent = mercFolder or Workspace

	return {
		Owner = owner,
		MercType = mercType,
		Index = idx,
		Model = model,
		Humanoid = hum,
		Root = root,
		StatusLabel = lbl,
		Damage = dmg,
		Cooldown = cd,
		LastAttackAt = 0,
	}
end

function MercenaryMafiaService.ActivateContract(player: Player, mercType: MercenaryType): ()
	clearContract(player)
	local char = player.Character
	local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local origin = if hrp and hrp:IsA("BasePart") then hrp.Position else Vector3.new(0, 5, 24)

	local agents: { MercenaryAgent } = {}
	local offsets = {
		Vector3.new(-7, 0, -6),
		Vector3.new(7, 0, -6),
		Vector3.new(0, 0, -10),
	}
	for i = 1, 3 do
		table.insert(agents, spawnMercenaryUnit(player, mercType, i, origin + offsets[i]))
	end

	contracts[player] = {
		MercType = mercType,
		ExpiresAt = os.clock() + MercenaryMafiaService.CONTRACT_SECONDS,
		Mode = "Attack",
		ExplicitAttackOrder = false,
		TargetRestaurantId = nil,
		Agents = agents,
	}
	if onChangedCb then onChangedCb(player) end
end

function MercenaryMafiaService.TryHireWithGold(player: Player, mercTypeRaw: string): (boolean, string)
	local mercType: MercenaryType = if string.lower(mercTypeRaw) == "ninja" then "Ninja" else "Samurai"
	if not PlayerDataService.SpendCoins(player, MercenaryMafiaService.GOLD_COST) then
		return false, string.format("Need %d Gold (or 199 R$ in Shop) to hire the 5-minute %s Mafia Strike Squad!", MercenaryMafiaService.GOLD_COST, mercType)
	end
	MercenaryMafiaService.ActivateContract(player, mercType)
	local name = if mercType == "Samurai" then "Kurogane Samurai Mafia" else "Kage Ninja Assassin Mafia"
	return true, string.format("HIRED %s FOR 5 MINUTES! Click ATTACK on HUD to unleash them against Rival Samurai/Ninja Mafia or Restaurants!", name)
end

function MercenaryMafiaService.CommandAttack(player: Player): (boolean, string)
	local c = contracts[player]
	if not c or os.clock() >= c.ExpiresAt then
		return false, "No active Samurai/Ninja Mafia contract."
	end
	c.Mode = "Attack"
	c.ExplicitAttackOrder = true
	if onChangedCb then onChangedCb(player) end
	return true, string.format("%s MAFIA ENGAGING ALL NEARBY RIVALS & RIVAL SAMURAI!", string.upper(c.MercType))
end

function MercenaryMafiaService.CommandRecall(player: Player): (boolean, string)
	local c = contracts[player]
	if not c or os.clock() >= c.ExpiresAt then
		return false, "No active Samurai/Ninja Mafia contract."
	end
	c.Mode = "Recall"
	c.ExplicitAttackOrder = false
	c.TargetRestaurantId = nil
	local ch = player.Character
	local hrp = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
	if hrp and hrp:IsA("BasePart") then
		for idx, ag in ipairs(c.Agents) do
			if ag.Model.Parent and ag.Humanoid.Health > 0 then
				local dest = hrp.Position + Vector3.new((idx - 2) * 6, 1, 7)
				if (dest - ag.Root.Position).Magnitude > 48 then
					ag.Model:PivotTo(CFrame.new(dest))
				else
					ag.Humanoid:MoveTo(dest)
				end
			end
		end
	end
	if onChangedCb then onChangedCb(player) end
	return true, string.format("%s MAFIA RECALLED TO YOUR SIDE!", string.upper(c.MercType))
end

function MercenaryMafiaService.OrderAssault(player: Player, targetArg: string?): (boolean, string)
	local c = contracts[player]
	if not c or os.clock() >= c.ExpiresAt then
		return false, "Hire the Samurai Mafia or Ninja Mafia (20,000G or 199 R$) first!"
	end

	if not targetArg or targetArg == "" or targetArg == "Follow" then
		return MercenaryMafiaService.CommandRecall(player)
	end

	local pos = MafiaRestaurantService.GetRestaurantPosition(targetArg)
	if not pos then
		return false, "Unknown Mafia Restaurant target!"
	end

	c.Mode = "Attack"
	c.TargetRestaurantId = targetArg
	-- Rapidly deploy the 3 mercenary specialists right onto the target restaurant perimeter!
	local offsets = { Vector3.new(-9, 3.8, 22), Vector3.new(9, 3.8, 22), Vector3.new(0, 3.8, 26) }
	for i, ag in ipairs(c.Agents) do
		if ag.Model.Parent and ag.Humanoid.Health > 0 then
			ag.Model:PivotTo(CFrame.new(pos + (offsets[i] or offsets[1])))
		end
	end
	if onChangedCb then onChangedCb(player) end
	local spec = MafiaRestaurantService.SPECS[targetArg]
	return true, string.format("%s MAFIA ASSAULTING %s! They will clear the garrison and capture it for you!", string.upper(c.MercType), if spec then spec.DisplayName else targetArg)
end

function MercenaryMafiaService.GetSnapshot(player: Player): { [string]: any }
	local c = contracts[player]
	local now = os.clock()
	if not c or now >= c.ExpiresAt then
		return {
			Active = false,
			MercType = nil,
			Mode = "Recall",
			TimeRemaining = 0,
			TargetRestaurantId = nil,
			GoldCost = MercenaryMafiaService.GOLD_COST,
		}
	end
	return {
		Active = true,
		MercType = c.MercType,
		Mode = c.Mode,
		TimeRemaining = math.max(0, math.ceil(c.ExpiresAt - now)),
		TargetRestaurantId = c.TargetRestaurantId,
		GoldCost = MercenaryMafiaService.GOLD_COST,
	}
end

local function hasPlayerStolenShipment(player: Player): boolean
	local untilAttr = player:GetAttribute("StolenShipmentUntil")
	if typeof(untilAttr) == "number" and untilAttr > os.clock() then
		return true
	end
	return player:GetAttribute("CarryingCrate") ~= nil
end

local function findBestEnemyForMerc(owner: Player, c: MercenaryContract, anchor: Vector3): (Humanoid?, BasePart?, Model?)
	-- Priority 1: If assigned to a Mafia Restaurant, relentlessly hunt its defending Apex Mafia / Revenge squad!
	if c.TargetRestaurantId then
		local hostiles = MafiaRestaurantService.GetActiveHostiles(c.TargetRestaurantId)
		local bestH: Humanoid? = nil
		local bestR: BasePart? = nil
		local bestM: Model? = nil
		local bestD = math.huge
		for _, m in ipairs(hostiles) do
			local r = m:FindFirstChild("HumanoidRootPart")
			local h = m:FindFirstChildOfClass("Humanoid")
			if r and r:IsA("BasePart") and h and h.Health > 0 then
				local d = (r.Position - anchor).Magnitude
				if d < bestD then
					bestD = d; bestH = h; bestR = r; bestM = m
				end
			end
		end
		if bestH then
			return bestH, bestR, bestM
		end
	end

	-- Priority 2: Hunt nearby Turf Ninja/Samurai Mafia, ApexMafia, PenthouseBoss, RivalAI, enemy TurfGuards, and (when ordered/provoked/stolen) Central Park Rival Samurai!
	local bestH: Humanoid? = nil
	local bestR: BasePart? = nil
	local bestM: Model? = nil
	local bestD = if c.Mode == "Attack" then 145 else 36
	local ownerStole = hasPlayerStolenShipment(owner)
	for _, tagName in ipairs({ "MafiaUnit", "ApexMafiaUnit", "PenthouseBossUnit", "RivalSamuraiUnit", "RivalAIUnit", "TurfGuardUnit" }) do
		for _, u in ipairs(CollectionService:GetTagged(tagName)) do
			if u:IsA("Model") then
				if tagName == "TurfGuardUnit" and u:GetAttribute("OwnerUserId") == owner.UserId then
					continue
				end
				if tagName == "RivalSamuraiUnit" then
					local isProvoked = u:GetAttribute("Provoked") == true
					if not c.ExplicitAttackOrder and not ownerStole and not isProvoked then
						continue
					end
				end
				local r = u:FindFirstChild("HumanoidRootPart")
				local h = u:FindFirstChildOfClass("Humanoid")
				if r and r:IsA("BasePart") and h and h.Health > 0 then
					if tagName == "RivalAIUnit" then
						local inCentralSpinZone = (math.abs(r.Position.X) <= 175 and math.abs(r.Position.Z) <= 175)
							or (u:GetAttribute("RivalFactionId") == "CrimsonDonEmpire")
						if inCentralSpinZone and not ownerStole and not c.ExplicitAttackOrder then
							continue
						end
					end
					local d = (r.Position - anchor).Magnitude
					if d < bestD then
						bestD = d; bestH = h; bestR = r; bestM = u
					end
				end
			end
		end
	end
	return bestH, bestR, bestM
end

function MercenaryMafiaService.Start(): ()
	if isRunning then return end
	isRunning = true

	local existing = Workspace:FindFirstChild("MercenaryMafiaUnits")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		mercFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "MercenaryMafiaUnits"
		f.Parent = Workspace
		mercFolder = f
	end

	MonetizationService.SetMercenaryGrantHandler(function(player: Player, mercTypeStr: string)
		local mType: MercenaryType = if mercTypeStr == "Ninja" then "Ninja" else "Samurai"
		MercenaryMafiaService.ActivateContract(player, mType)
	end)

	Players.PlayerRemoving:Connect(function(p: Player)
		clearContract(p)
	end)

	aiThread = task.spawn(function()
		while isRunning do
			task.wait(0.35)
			if not isRunning then break end
			local now = os.clock()
			for player, c in pairs(contracts) do
				if not player.Parent or now >= c.ExpiresAt then
					clearContract(player)
					if player.Parent then
						sendToast(player, "Your 5-minute Samurai/Ninja Mafia contract has ended!")
						if onChangedCb then onChangedCb(player) end
					end
					continue
				end

				local targetPos: Vector3
				if c.TargetRestaurantId then
					targetPos = MafiaRestaurantService.GetRestaurantPosition(c.TargetRestaurantId) or Vector3.new(0, 4, 0)
				else
					local ch = player.Character
					local hrp = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
					targetPos = if hrp and hrp:IsA("BasePart") then hrp.Position else Vector3.new(0, 4, 0)
				end

				for idx, ag in ipairs(c.Agents) do
					if not ag.Model.Parent or ag.Humanoid.Health <= 0 then
						-- Mercenary specialists reinforce during their active 10m contract
						c.Agents[idx] = spawnMercenaryUnit(player, c.MercType, idx, targetPos + Vector3.new((idx - 2) * 8, 3.8, 12))
						continue
					end

					local myPos = ag.Root.Position
					local tHum: Humanoid? = nil
					local tRoot: BasePart? = nil
					local tModel: Model? = nil
					if c.Mode == "Attack" then
						tHum, tRoot, tModel = findBestEnemyForMerc(player, c, targetPos)
					end
					if tHum and tRoot and tModel then
						ag.StatusLabel.Text = string.format("%s MAFIA  |  STRIKING", string.upper(ag.MercType))
						local d = (tRoot.Position - myPos).Magnitude
						if d > 130 then
							ag.Model:PivotTo(CFrame.new(tRoot.Position + Vector3.new(6, 1, 6)))
						elseif d > 10 then
							ag.Humanoid:MoveTo(tRoot.Position)
						end
						if d <= 15 and (now - ag.LastAttackAt) >= ag.Cooldown then
							ag.LastAttackAt = now
							local dmg = ag.Damage
							if ag.MercType == "Ninja" and math.random() < 0.38 then
								dmg = math.floor(dmg * 1.6)
							end
							tHum:TakeDamage(dmg)
							local clashPoint = (myPos + tRoot.Position) * 0.5 + Vector3.new(0, 1.5, 0)
							local defStyle = tostring(tModel:GetAttribute("BladeStyle") or "Samurai")
							BlackMarketService.SpawnBladeClashVFX(clashPoint, ag.MercType, defStyle)
							local slashCol = if ag.MercType == "Samurai" then Color3.fromRGB(204, 48, 56) else Color3.fromRGB(168, 184, 214)
							BlackMarketService.SpawnBulletTracer(myPos + Vector3.new(0, 1.4, 0), tRoot.Position, slashCol)
							BlackMarketService.BroadcastSFX("MeleeHit", clashPoint)
							BlackMarketService.BroadcastSFX(if tHum.Health <= 0 then "EnemyDeathScream" else "EnemyHitScream", tRoot.Position)
							if tHum.Health <= 0 then
								local rid = tModel:GetAttribute("MafiaRestaurantId")
								if typeof(rid) == "string" then
									MafiaRestaurantService.RecordUnitKiller(rid, player)
								end
								PlayerDataService.AddRewards(player, 110, 50, 26)
							end
						end
					else
						local remMin = math.floor((c.ExpiresAt - now) / 60)
						local remSec = math.floor((c.ExpiresAt - now) % 60)
						local modeTag = if c.Mode == "Recall" then "RECALLED" else string.format("%02d:%02d", remMin, remSec)
						ag.StatusLabel.Text = string.format("%s MAFIA  |  %s", string.upper(ag.MercType), modeTag)
						local formPos = targetPos + Vector3.new((idx - 2) * 6.5, 0, 8)
						if (formPos - myPos).Magnitude > 110 then
							ag.Model:PivotTo(CFrame.new(formPos + Vector3.new(0, 2, 0)))
						elseif (formPos - myPos).Magnitude > 6 then
							ag.Humanoid:MoveTo(formPos)
						end
					end
				end
			end
		end
	end)

	print("[Food Empire] MercenaryMafiaService started (5-Minute Samurai Mafia & Ninja Assassin Mafia Contracts active)!")
end

function MercenaryMafiaService.Stop(): ()
	isRunning = false
	if aiThread then task.cancel(aiThread); aiThread = nil end
	for p in pairs(contracts) do
		clearContract(p)
	end
end

return MercenaryMafiaService
