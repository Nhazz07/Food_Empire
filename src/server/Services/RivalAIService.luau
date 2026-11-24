--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RivalFactionConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RivalFactionConfig")
)
local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local SectorService = require("./SectorService")
local ShipmentService = require("./ShipmentService")
local BlackMarketService = require("./BlackMarketService")
local PlayerDataService = require("./PlayerDataService")

local RivalAIService = {}

local OPENING_GRACE_SECONDS = 8
local DECISION_INTERVAL = 1.4
local RESPAWN_DELAY = 14
local RIVAL_MELEE_RANGE = 11.5
local RIVAL_MELEE_COOLDOWN = 1.15

type RivalAgent = {
	UnitKey: string,
	Faction: RivalFactionConfig.RivalFactionSpec,
	IsBossEscort: boolean,
	EscortSlot: number, -- 1 or 2 if Boss Bodyguard escort
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	TaskLabel: TextLabel,
	PatrolIndex: number,
	LastAttackAt: number,
	StrafeSign: number,
	AlertUntil: number,
	AlertTargetPos: Vector3?,
}

local isRunning = false
local aiFolder: Folder? = nil
local activeAgents: { RivalAgent } = {}
local aiThread: thread? = nil
local lastBossAnnounceAt = 0

local function getHighestPlayerProgression(): (number, number, number)
	local maxLevel = 1
	local maxRep = 0
	local maxSectors = 0
	for _, p in ipairs(Players:GetPlayers()) do
		local prof = PlayerDataService.GetProfile(p)
		if prof.Level > maxLevel then
			maxLevel = prof.Level
		end
		if prof.Reputation > maxRep then
			maxRep = prof.Reputation
		end
		local owned = SectorService.GetOwnedSectors("Player_" .. tostring(p.UserId))
		if #owned > maxSectors then
			maxSectors = #owned
		end
	end
	return maxLevel, maxRep, maxSectors
end

local function isFactionUnlocked(spec: RivalFactionConfig.RivalFactionSpec, maxLevel: number, maxRep: number, maxSectors: number): boolean
	if spec.Difficulty == "Easy" or spec.Difficulty == "Medium" then
		return true
	end
	return maxLevel >= spec.UnlockMinLevel
		or maxRep >= spec.UnlockMinRep
		or (spec.UnlockMinSectors > 0 and maxSectors >= spec.UnlockMinSectors)
end

local function broadcastToast(msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local toastEv = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if toastEv and toastEv:IsA("RemoteEvent") then
		toastEv:FireAllClients(msg)
	end
end

local function buildRivalUnitModel(
	unitKey: string,
	faction: RivalFactionConfig.RivalFactionSpec,
	isEscort: boolean,
	escortSlot: number,
	spawnPos: Vector3
): RivalAgent
	local s = if isEscort then 1.08 else faction.Scale
	local maxHP = if isEscort then faction.EscortHP else faction.MaxHP
	local isBossLeader = (faction.Difficulty == "Boss" and not isEscort)
	local titleText = if isEscort
		then "DON'S ENFORCER"
		else faction.ShortTag

	local rig = MafiaVisualBuilder.BuildRivalRig(unitKey, faction.Id, isEscort, s, CFrame.new(spawnPos), false)
	local model = rig.Model
	local root = rig.Root
	local head = rig.Head

	-- Restrained Dark Mafia Nameplate + Subtle Status + Clean Blood-Red HP Bar (Zero Emojis / Zero Neon)
	local bb = Instance.new("BillboardGui")
	bb.Name = "RivalTag"
	bb.Size = UDim2.fromOffset(if isBossLeader then 214 else 188, 56)
	bb.StudsOffset = Vector3.new(0, 3.05 * s, 0)
	bb.MaxDistance = if isBossLeader then 220 else 155
	bb.AlwaysOnTop = false
	bb.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 21)
	label.BackgroundColor3 = Color3.fromRGB(16, 17, 21)
	label.BackgroundTransparency = 0.08
	label.Font = Enum.Font.GothamBlack
	label.Text = titleText
	label.TextSize = if isBossLeader then 11 else 10
	label.TextColor3 = if isBossLeader then Color3.fromRGB(224, 198, 134) else Color3.fromRGB(228, 226, 220)
	label.Parent = bb
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 4)
	local st = Instance.new("UIStroke")
	st.Color = if isBossLeader then Color3.fromRGB(142, 32, 38) else Color3.fromRGB(58, 62, 70)
	st.Thickness = 1.2
	st.Parent = label

	local taskLbl = Instance.new("TextLabel")
	taskLbl.Name = "TaskText"
	taskLbl.Position = UDim2.new(0.02, 0, 0, 23)
	taskLbl.Size = UDim2.new(0.96, 0, 0, 15)
	taskLbl.BackgroundColor3 = Color3.fromRGB(14, 15, 18)
	taskLbl.BackgroundTransparency = 0.20
	taskLbl.Font = Enum.Font.GothamMedium
	taskLbl.Text = if isEscort then "Escorting The Crimson Don" else faction.CareTasks[1]
	taskLbl.TextSize = 9
	taskLbl.TextColor3 = Color3.fromRGB(168, 170, 178)
	taskLbl.Parent = bb
	Instance.new("UICorner", taskLbl).CornerRadius = UDim.new(0, 3)

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBarBg"
	hpBg.Position = UDim2.new(0.02, 0, 0, 40)
	hpBg.Size = UDim2.new(0.96, 0, 0, 13)
	hpBg.BackgroundColor3 = Color3.fromRGB(14, 15, 18)
	hpBg.Parent = bb
	Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 3)
	local hst = Instance.new("UIStroke")
	hst.Color = Color3.fromRGB(52, 54, 62)
	hst.Thickness = 1
	hst.Parent = hpBg

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = if isBossLeader then Color3.fromRGB(154, 28, 36) else Color3.fromRGB(132, 32, 38)
	hpFill.Parent = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.GothamBold
	hpText.Text = string.format("%d / %d HP", maxHP, maxHP)
	hpText.TextSize = 9
	hpText.TextColor3 = Color3.fromRGB(238, 236, 232)
	hpText.ZIndex = 3
	hpText.Parent = hpBg

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = maxHP
	humanoid.Health = maxHP
	humanoid.WalkSpeed = if isEscort then faction.WalkSpeed + 0.5 else faction.WalkSpeed
	humanoid.HipHeight = 2.42 * s
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	humanoid.Died:Connect(function()
		if faction.Id ~= "CrimsonDonEmpire" and root.Parent then
			local deathPos = root.Position
			local bestP: Player? = nil
			local bestD = 160
			for _, p in ipairs(Players:GetPlayers()) do
				local ch = p.Character
				local hrp = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
				if hrp and hrp:IsA("BasePart") then
					local d = (hrp.Position - deathPos).Magnitude
					if d < bestD then
						bestD = d
						bestP = p
					end
				elseif not bestP then
					bestP = p
				end
			end
			if bestP then
				local cur = tonumber(bestP:GetAttribute("VaultKeycards")) or 0
				bestP:SetAttribute("VaultKeycards", cur + 1)
				local remotes = ReplicatedStorage:FindFirstChild("Remotes")
				local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
				if ev and ev:IsA("RemoteEvent") then
					ev:FireClient(bestP, string.format("TERRITORY KEYCARD DROPPED (%d Owned)! Crack a Corner Supply Vault [E] for +440G & Rare Stock!", cur + 1))
				end
			end
		end
		MafiaVisualBuilder.PlayDeathSequence(model, isBossLeader, function(impactPos: Vector3)
			BlackMarketService.BroadcastSFX("BodyDrop", impactPos)
		end)
	end)

	local agent: RivalAgent = {
		UnitKey = unitKey,
		Faction = faction,
		IsBossEscort = isEscort,
		EscortSlot = escortSlot,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		TaskLabel = taskLbl,
		PatrolIndex = math.random(1, math.max(1, #faction.PatrolPoints)),
		LastAttackAt = 0,
		StrafeSign = if math.random() < 0.5 then -1 else 1,
		AlertUntil = 0,
		AlertTargetPos = nil,
	}

	local prevHp = maxHP
	humanoid.HealthChanged:Connect(function(hp: number)
		local cur = math.max(0, math.ceil(hp))
		local maxH = math.max(1, math.ceil(humanoid.MaxHealth))
		local frac = math.clamp(hp / maxH, 0, 1)
		hpFill.Size = UDim2.fromScale(frac, 1)
		hpText.Text = string.format("%d / %d HP", cur, maxH)
		-- Squad Alert! If damaged (and not hit by a Suppressed weapon), alert nearby faction allies & Boss Bodyguards within 95 studs!
		local supAt = model:GetAttribute("SuppressedHitAt")
		local isSuppressedHit = typeof(supAt) == "number" and (os.clock() - supAt) < 0.6
		if hp < prevHp and root.Parent and not isSuppressedHit then
			local hitOrigin = root.Position
			for _, ally in ipairs(activeAgents) do
				if ally.Faction.Id == faction.Id and ally.Root.Parent and (ally.Root.Position - hitOrigin).Magnitude <= 95 then
					ally.AlertUntil = os.clock() + 10
					ally.AlertTargetPos = hitOrigin
				end
			end
		end
		prevHp = hp
	end)

	local bountyGold = if isEscort then math.floor(faction.BountyGold * 0.45) else faction.BountyGold
	local bountyExp = if isEscort then math.floor(faction.BountyExp * 0.45) else faction.BountyExp
	local bountyRep = if isEscort then math.floor(faction.BountyRep * 0.45) else faction.BountyRep

	model.PrimaryPart = root
	model:SetAttribute("Faction", "Rival")
	model:SetAttribute("RivalFactionId", faction.Id)
	model:SetAttribute("RivalDifficulty", faction.Difficulty)
	model:SetAttribute("RivalTitle", titleText)
	model:SetAttribute("TerritoryId", faction.TerritoryId)
	model:SetAttribute("BountyGold", bountyGold)
	model:SetAttribute("BountyExp", bountyExp)
	model:SetAttribute("BountyRep", bountyRep)
	model:SetAttribute("IsRivalBoss", isBossLeader)
	CollectionService:AddTag(model, "RivalAIUnit")

	model.Parent = aiFolder or Workspace
	return agent
end

local function isInsideAnySafeBase(pos: Vector3): boolean
	for _, base in ipairs(CollectionService:GetTagged("PlayerBase")) do
		if base:IsA("Model") and base:IsDescendantOf(Workspace) then
			local piv = base:GetPivot().Position
			if math.abs(pos.X - piv.X) <= 116 and math.abs(pos.Z - piv.Z) <= 116 then
				return true
			end
		end
	end
	return false
end

local function findFactionBossLeader(factionId: string): RivalAgent?
	for _, ag in ipairs(activeAgents) do
		if ag.Faction.Id == factionId and not ag.IsBossEscort and ag.Model.Parent and ag.Humanoid.Health > 0 then
			return ag
		end
	end
	return nil
end

local function isNearCentralSpinEvent(pos: Vector3): boolean
	return math.abs(pos.X) <= 195 and math.abs(pos.Z) <= 195
end

local function hasPlayerStolenShipment(player: Player): boolean
	local untilAttr = player:GetAttribute("StolenShipmentUntil")
	if typeof(untilAttr) == "number" and untilAttr > os.clock() then
		return true
	end
	if player:GetAttribute("CarryingCrate") ~= nil then
		return true
	end
	return false
end

local function tryRivalCombat(agent: RivalAgent): boolean
	local now = os.clock()
	local myPos = agent.Root.Position
	local faction = agent.Faction
	local isCentralParkRival = (faction.Id == "CrimsonDonEmpire") or isNearCentralSpinEvent(myPos)
	local nearestHum: Humanoid? = nil
	local nearestPos: Vector3? = nil
	local nearestModel: Model? = nil
	local alertBonus = if agent.AlertUntil > now then 22 else 0
	local bestDist = faction.AttackRange + alertBonus

	-- 1. Spot & intercept Player Delivery Runners (only outside Central Park, or if owner stole a shipment!)
	local runnerVision = if ReplicatedStorage:GetAttribute("IsNight") == true then 28 else 44
	if not isCentralParkRival then
		for _, runner in ipairs(CollectionService:GetTagged("PlayerDeliveryRunner")) do
			if runner:IsA("Model") then
				local rRoot = runner:FindFirstChild("HumanoidRootPart")
				local rHum = runner:FindFirstChildOfClass("Humanoid")
				if rRoot and rRoot:IsA("BasePart") and rHum and rHum.Health > 0 and not isInsideAnySafeBase(rRoot.Position) then
					local d = (rRoot.Position - myPos).Magnitude
					if d < math.min(runnerVision, bestDist) then
						bestDist = d; nearestHum = rHum; nearestPos = rRoot.Position; nearestModel = runner
					end
				end
			end
		end
	end

	-- 2. Fight nearby Player Bodyguards & Raider Chefs (Central Park rivals ONLY fight if owner stole a shipment!)
	for _, tagName in ipairs({ "PlayerBodyguardUnit", "PlayerRaiderUnit" }) do
		for _, unit in ipairs(CollectionService:GetTagged(tagName)) do
			if unit:IsA("Model") then
				local allowUnitAggro = true
				if isCentralParkRival then
					local ownerId = unit:GetAttribute("OwnerUserId")
					local ownerPlayer = if typeof(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
					allowUnitAggro = (ownerPlayer ~= nil and hasPlayerStolenShipment(ownerPlayer))
				end
				if allowUnitAggro then
					local rRoot = unit:FindFirstChild("HumanoidRootPart")
					local rHum = unit:FindFirstChildOfClass("Humanoid")
					if rRoot and rRoot:IsA("BasePart") and rHum and rHum.Health > 0 and not isInsideAnySafeBase(rRoot.Position) then
						local d = (rRoot.Position - myPos).Magnitude
						if d < bestDist then
							bestDist = d; nearestHum = rHum; nearestPos = rRoot.Position; nearestModel = unit
						end
					end
				end
			end
		end
	end

	-- 3. Engage Players:
	--    * Central Park Rivals (near the Lucky Spin Event) ONLY shoot/fight if the player stole a Fish/Meat/Veg/Fruit shipment!
	--    * Corner Territory Rivals (Fruit, Meat, Fish, Vegetable territories) ALWAYS shoot/fight any player who enters or stays near their territory!
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local pRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
		local pHum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		if pRoot and pRoot:IsA("BasePart") and pHum and pHum.Health > 0 and not isInsideAnySafeBase(pRoot.Position) then
			local inCentral = isCentralParkRival or isNearCentralSpinEvent(pRoot.Position)
			local canAggro = if inCentral then hasPlayerStolenShipment(player) else true
			if canAggro then
				local smokeUntil = player:GetAttribute("InSmokeUntil")
				local maxSight = if typeof(smokeUntil) == "number" and smokeUntil > now then 16 else bestDist
				local d = (pRoot.Position - myPos).Magnitude
				if d < maxSight then
					bestDist = d; nearestHum = pHum; nearestPos = pRoot.Position; nearestModel = char
				end
			end
		end
	end

	if nearestHum and nearestPos then
		local stunUntil = agent.Model:GetAttribute("StunnedUntil")
		if typeof(stunUntil) == "number" and stunUntil > now then
			agent.TaskLabel.Text = "FLASHBANGED / STUNNED!"
			return
		end
		local isBossLeader = (faction.Difficulty == "Boss" and not agent.IsBossEscort)
		agent.TaskLabel.Text = if agent.IsBossEscort
			then "Defending The Crimson Don"
			else "Engaging (" .. faction.Difficulty .. ")"

		local hasGun = faction.HasGun or agent.IsBossEscort
		if hasGun and bestDist <= faction.AttackRange and bestDist > RIVAL_MELEE_RANGE then
			if (now - agent.LastAttackAt) >= faction.FireCooldown then
				agent.LastAttackAt = now
				MafiaVisualBuilder.TriggerAttackAnim(agent.Model)
				local fromPos = agent.Root.Position + Vector3.new(0, 1.4, 0)
				local gunDmg = if agent.IsBossEscort then math.floor(faction.GunDamage * 0.78) else faction.GunDamage
				local shots = if isBossLeader then 2 else 1
				for shotIdx = 1, shots do
					local targetP = nearestPos + Vector3.new((math.random() - 0.5) * 1.4, (math.random() - 0.5) * 1.0, (math.random() - 0.5) * 1.4)
					BlackMarketService.SpawnBulletTracer(fromPos, targetP, faction.TracerColor)
					if shotIdx == 1 then
						local sfx = if faction.GunKind == "SMG" or faction.GunKind == "Carbine" then "SMGShot" elseif isBossLeader then "ShotgunBlast" else "EnemyShot"
						BlackMarketService.BroadcastSFX(sfx, fromPos)
					end
					if math.random() < faction.Accuracy then
						if nearestModel then
							local dir = nearestPos - myPos
							if dir.Magnitude > 0.05 then
								nearestModel:SetAttribute("LastHitDir", dir.Unit)
							end
						end
						nearestHum:TakeDamage(gunDmg)
						BlackMarketService.BroadcastSFX("MeleeHit", nearestPos)
					end
				end
			end

			-- Improved Tactical Combat Behavior: Hard/Elite/Boss factions strafe laterally at ideal combat range!
			if faction.StrafesInCombat and bestDist < faction.AttackRange * 0.72 and bestDist > 22 then
				if math.random() < 0.25 then
					agent.StrafeSign = -agent.StrafeSign
				end
				local toTarget = (nearestPos - myPos)
				local rightVec = Vector3.new(-toTarget.Z, 0, toTarget.X)
				if rightVec.Magnitude > 0.1 then
					local strafeDest = myPos + rightVec.Unit * (14 * agent.StrafeSign)
					agent.Humanoid:MoveTo(strafeDest)
				end
			else
				agent.Humanoid:MoveTo(nearestPos)
			end
			return true
		elseif bestDist <= RIVAL_MELEE_RANGE then
			if (now - agent.LastAttackAt) >= RIVAL_MELEE_COOLDOWN then
				agent.LastAttackAt = now
				MafiaVisualBuilder.TriggerAttackAnim(agent.Model)
				local mDmg = if agent.IsBossEscort then math.floor(faction.MeleeDamage * 0.8) else faction.MeleeDamage
				if nearestModel then
					local dir = nearestPos - myPos
					if dir.Magnitude > 0.05 then
						nearestModel:SetAttribute("LastHitDir", dir.Unit)
					end
				end
				nearestHum:TakeDamage(mDmg)
				BlackMarketService.BroadcastSFX("MeleeHit", nearestPos)
			end
		end

		agent.Humanoid:MoveTo(nearestPos)
		return true
	end

	-- If alerted by an ally being attacked nearby, converge to assist!
	if agent.AlertUntil > now and agent.AlertTargetPos then
		agent.TaskLabel.Text = "Reinforcing Faction"
		agent.Humanoid:MoveTo(agent.AlertTargetPos)
		return true
	end

	return false
end

local function navigateAgentTo(agent: RivalAgent, destination: Vector3): ()
	if agent.Humanoid.Health <= 0 or not agent.Model.Parent then
		return
	end
	if (agent.Root.Position - destination).Magnitude <= 8 then
		return
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2.5,
		AgentHeight = 6,
		AgentCanJump = true,
	})
	local ok = pcall(function()
		path:ComputeAsync(agent.Root.Position, destination)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		local stepTarget = waypoints[math.min(4, #waypoints)]
		if stepTarget then
			if stepTarget.Action == Enum.PathWaypointAction.Jump then
				agent.Humanoid.Jump = true
			end
			agent.Humanoid:MoveTo(stepTarget.Position)
			return
		end
	end
	agent.Humanoid:MoveTo(destination)
end

local function hasAliveUnit(unitKey: string): boolean
	for _, ag in ipairs(activeAgents) do
		if ag.UnitKey == unitKey and ag.Model.Parent and ag.Humanoid.Health > 0 then
			return true
		end
	end
	return false
end

local function ensureFactionAgents(): ()
	for i = #activeAgents, 1, -1 do
		local agent = activeAgents[i]
		if not agent.Model.Parent or agent.Humanoid.Health <= 0 then
			if agent.Model.Parent and agent.Model:GetAttribute("IsDying") ~= true then
				MafiaVisualBuilder.PlayDeathSequence(agent.Model, agent.Faction.Difficulty == "Boss" and not agent.IsBossEscort, function(impactPos: Vector3)
					BlackMarketService.BroadcastSFX("BodyDrop", impactPos)
				end)
			end
			table.remove(activeAgents, i)
		end
	end

	local maxLevel, maxRep, maxSectors = getHighestPlayerProgression()

	for _, factionId in ipairs(RivalFactionConfig.FACTION_ORDER) do
		local spec = RivalFactionConfig.FACTIONS[factionId]
		if spec and isFactionUnlocked(spec, maxLevel, maxRep, maxSectors) then
			for unitIdx = 1, spec.MaxUnits do
				local key = string.format("%s_Unit_%d", spec.Id, unitIdx)
				if not hasAliveUnit(key) then
					local pt = spec.PatrolPoints[((unitIdx - 1) % #spec.PatrolPoints) + 1] or Vector3.new(0, 4, 80)
					local spawnPos = pt + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
					local agent = buildRivalUnitModel(key, spec, false, 0, spawnPos)
					table.insert(activeAgents, agent)

					if spec.Difficulty == "Boss" and (os.clock() - lastBossAnnounceAt) > 60 then
						lastBossAnnounceAt = os.clock()
						broadcastToast("BOSS ALERT: The Crimson Don and his Enforcers have entered Central Plaza (+480G Bounty)")
					end
				end
			end

			-- Spawn 2 dedicated Armored Bodyguards protecting the Boss Faction Leader!
			if spec.HasBossEscorts then
				local boss = findFactionBossLeader(spec.Id)
				if boss then
					for slot = 1, 2 do
						local eKey = string.format("%s_Escort_%d", spec.Id, slot)
						if not hasAliveUnit(eKey) then
							local side = if slot == 1 then -7 else 7
							local spawnPos = boss.Root.Position + Vector3.new(side, 0, 6)
							local escort = buildRivalUnitModel(eKey, spec, true, slot, spawnPos)
							table.insert(activeAgents, escort)
						end
					end
				end
			end
		end
	end
end

function RivalAIService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local existingFolder = Workspace:FindFirstChild("RivalAIUnits")
	if existingFolder and existingFolder:IsA("Folder") then
		existingFolder:ClearAllChildren()
		aiFolder = existingFolder
	else
		local folder = Instance.new("Folder")
		folder.Name = "RivalAIUnits"
		folder.Parent = Workspace
		aiFolder = folder
	end

	ensureFactionAgents()
	print("[Food Empire] RivalAIService started (5 Progressive Rival Factions: Easy, Medium, Hard, Elite & Boss + Boss Bodyguards active)!")

	aiThread = task.spawn(function()
		task.wait(OPENING_GRACE_SECONDS)
		local respawnTimer = 0
		while isRunning do
			task.wait(DECISION_INTERVAL)
			if not isRunning then
				break
			end

			respawnTimer += DECISION_INTERVAL
			if respawnTimer >= RESPAWN_DELAY then
				respawnTimer = 0
				ensureFactionAgents()
			end

			for _, agent in ipairs(activeAgents) do
				if agent.Model.Parent and agent.Humanoid.Health > 0 then
					if not tryRivalCombat(agent) then
						if agent.IsBossEscort then
							local boss = findFactionBossLeader(agent.Faction.Id)
							if boss then
								local side = if agent.EscortSlot == 1 then -7.5 else 7.5
								local escortDest = (boss.Root.CFrame * CFrame.new(side, 0, 5.5)).Position
								agent.TaskLabel.Text = "Escorting The Crimson Don"
								if (escortDest - agent.Root.Position).Magnitude > 6 then
									agent.Humanoid:MoveTo(escortDest)
								end
							end
						else
							-- Interception & Faction Territory Caretaking / Patrols
							if agent.Faction.Difficulty == "Elite" or agent.Faction.Difficulty == "Boss" then
								ShipmentService.TryRivalInterceptAtPosition(agent.Root.Position)
							end
							local pts = agent.Faction.PatrolPoints
							local targetPt = pts[agent.PatrolIndex] or pts[1]
							if (agent.Root.Position - targetPt).Magnitude <= 14 then
								agent.PatrolIndex = (agent.PatrolIndex % #pts) + 1
								targetPt = pts[agent.PatrolIndex]
								agent.TaskLabel.Text = agent.Faction.CareTasks[((agent.PatrolIndex - 1) % #agent.Faction.CareTasks) + 1]
							end
							navigateAgentTo(agent, Vector3.new(targetPt.X, agent.Root.Position.Y, targetPt.Z))
						end
					end
				end
			end
		end
	end)
end

function RivalAIService.Stop(): ()
	isRunning = false
	if aiThread then
		task.cancel(aiThread)
		aiThread = nil
	end
	table.clear(activeAgents)
end

return RivalAIService
