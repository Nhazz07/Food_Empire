--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local ShipmentService = require("./ShipmentService")
local BlackMarketService = require("./BlackMarketService")
local CombatLockService = require("./CombatLockService")
local NightMafiaRaidService = require("./NightMafiaRaidService")

type MafiaAgent = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	IsBoss: boolean,
	LastAttackAt: number,
	PatrolIndex: number,
	ShakedownTarget: Player?,
	ShakedownDeadline: number,
}

local MafiaService = {}

local MAX_ENFORCERS = 4
local DECISION_INTERVAL = 2.0
local RESPAWN_DELAY = 20
local SHAKEDOWN_INTERVAL = 52
local SHAKEDOWN_WINDOW = 22

local SPAWN_POINTS: { Vector3 } = {
	Vector3.new(490, 4, 490),
	Vector3.new(-490, 4, 490),
	Vector3.new(490, 4, -490),
	Vector3.new(-490, 4, -490),
	Vector3.new(0, 4, 204), -- Boss spawn on Central Ring
}

local PATROL_POINTS: { Vector3 } = {
	Vector3.new(66, 4, 66),
	Vector3.new(-66, 4, -66),
	Vector3.new(-66, 4, 66),
	Vector3.new(66, 4, -66),
	Vector3.new(0, 4, -340),
	Vector3.new(0, 4, 340),
	Vector3.new(340, 4, 0),
	Vector3.new(-340, 4, 0),
}

local isRunning = false
local mafiaFolder: Folder? = nil
local activeAgents: { MafiaAgent } = {}
local aiThread: thread? = nil

local function sendToast(player: Player, msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg)
	end
end

local function isInsideAnySafeBase(pos: Vector3): boolean
	for _, base in ipairs(CollectionService:GetTagged("PlayerBase")) do
		if base:IsA("Model") and base:IsDescendantOf(Workspace) then
			local piv = base:GetPivot().Position
			if math.abs(pos.X - piv.X) <= 110 and math.abs(pos.Z - piv.Z) <= 110 then
				return true
			end
		end
	end
	return false
end

local function getFrontGatePos(player: Player): Vector3?
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return nil
	end
	local base = BaseService.GetBaseModel(slot)
	local def = if base then base:FindFirstChild("Defenses") else nil
	local gate = if def then def:FindFirstChild("GrandFrontGate", true) else nil
	if gate and gate:IsA("Model") then
		local cf = gate:GetBoundingBox()
		return Vector3.new(cf.Position.X, 4, cf.Position.Z)
	end
	return nil
end

local function buildMafiaModel(index: number, spawnPos: Vector3, isBoss: boolean): MafiaAgent
	local scale = if isBoss then 1.18 else 1.02
	local modelName = if isBoss then "MafiaCapoBoss" else ("MafiaEnforcer_" .. tostring(index))
	local rig = MafiaVisualBuilder.BuildRivalRig(modelName, "CrimsonDonEmpire", not isBoss, scale, CFrame.new(spawnPos), false)
	local model = rig.Model
	local root = rig.Root
	local head = rig.Head
	local tieCol = if isBoss then Color3.fromRGB(186, 148, 68) else Color3.fromRGB(154, 30, 38)

	-- Restrained Dark-Noir Nameplate + HP Bar (Zero Emojis)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(if isBoss then 196 else 168, 42)
	bb.StudsOffset = Vector3.new(0, 3.1 * scale, 0)
	bb.MaxDistance = 155
	bb.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 21)
	label.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
	label.BackgroundTransparency = 0.08
	label.Font = Enum.Font.GothamBlack
	label.Text = if isBoss then "MAFIA CAPO BOSS" else "FOOD MAFIA ENFORCER"
	label.TextSize = if isBoss then 11 else 10
	label.TextColor3 = if isBoss then Color3.fromRGB(238, 194, 114) else Color3.fromRGB(228, 128, 130)
	label.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = label
	local st = Instance.new("UIStroke")
	st.Color = tieCol
	st.Thickness = 1.2
	st.Parent = label

	local maxHp = if isBoss then 320 else 200

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBarBg"
	hpBg.Position = UDim2.new(0.04, 0, 0, 24)
	hpBg.Size = UDim2.new(0.92, 0, 0, 13)
	hpBg.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
	hpBg.Parent = bb
	local hpc = Instance.new("UICorner")
	hpc.CornerRadius = UDim.new(0, 3)
	hpc.Parent = hpBg

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(154, 30, 38)
	hpFill.Parent = hpBg
	local hpfc = Instance.new("UICorner")
	hpfc.CornerRadius = UDim.new(0, 3)
	hpfc.Parent = hpFill

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.GothamBold
	hpText.Text = string.format("%d / %d HP", maxHp, maxHp)
	hpText.TextSize = 9
	hpText.TextColor3 = Color3.fromRGB(238, 236, 232)
	hpText.ZIndex = 3
	hpText.Parent = hpBg

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = maxHp
	hum.Health = maxHp
	hum.WalkSpeed = if isBoss then 15.5 else 18.0
	hum.HipHeight = 2.25 * scale
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	hum.Died:Connect(function()
		MafiaVisualBuilder.PlayDeathSequence(model, isBoss, function(impactPos: Vector3)
			BlackMarketService.BroadcastSFX("BodyDrop", impactPos)
		end)
	end)

	hum.HealthChanged:Connect(function(hp: number)
		local cur = math.max(0, math.ceil(hp))
		local maxH = math.max(1, math.ceil(hum.MaxHealth))
		hpFill.Size = UDim2.fromScale(math.clamp(hp / maxH, 0, 1), 1)
		hpText.Text = string.format("❤️ %d / %d HP", cur, maxH)
	end)

	model.PrimaryPart = root
	model:SetAttribute("Faction", "Mafia")
	model:SetAttribute("IsMafiaBoss", isBoss)
	CollectionService:AddTag(model, "MafiaUnit")
	model.Parent = mafiaFolder or Workspace

	return {
		Model = model,
		Humanoid = hum,
		Root = root,
		IsBoss = isBoss,
		LastAttackAt = 0,
		PatrolIndex = ((index - 1) % #PATROL_POINTS) + 1,
		ShakedownTarget = nil,
		ShakedownDeadline = 0,
	}
end

local function ensureSyndicate(): ()
	local hasBoss = false
	local enforcerCount = 0
	for i = #activeAgents, 1, -1 do
		local a = activeAgents[i]
		if not a.Model.Parent or a.Humanoid.Health <= 0 then
			if a.Model.Parent and a.Model:GetAttribute("IsDying") ~= true then
				MafiaVisualBuilder.PlayDeathSequence(a.Model, a.IsBoss, function(impactPos: Vector3)
					BlackMarketService.BroadcastSFX("BodyDrop", impactPos)
				end)
			end
			table.remove(activeAgents, i)
		else
			if a.IsBoss then hasBoss = true else enforcerCount += 1 end
		end
	end

	while enforcerCount < MAX_ENFORCERS do
		enforcerCount += 1
		local sp = SPAWN_POINTS[((enforcerCount - 1) % 4) + 1]
		table.insert(activeAgents, buildMafiaModel(enforcerCount, sp, false))
	end
	if not hasBoss then
		table.insert(activeAgents, buildMafiaModel(5, SPAWN_POINTS[5], true))
	end
end

local function navigateTo(agent: MafiaAgent, dest: Vector3): ()
	if (agent.Root.Position - dest).Magnitude <= 9 then
		return
	end
	local path = PathfindingService:CreatePath({ AgentRadius = 2.6, AgentHeight = 7, AgentCanJump = true })
	local ok = pcall(function()
		path:ComputeAsync(agent.Root.Position, dest)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		local wps = path:GetWaypoints()
		local step = wps[math.min(5, #wps)]
		if step then
			if step.Action == Enum.PathWaypointAction.Jump then
				agent.Humanoid.Jump = true
			end
			agent.Humanoid:MoveTo(step.Position)
			return
		end
	end
	agent.Humanoid:MoveTo(dest)
end

local function tryMafiaAmbush(agent: MafiaAgent): boolean
	local now = os.clock()
	local myPos = agent.Root.Position
	local bestHum: Humanoid? = nil
	local bestPos: Vector3? = nil
	local isNight = game:GetService("ReplicatedStorage"):GetAttribute("IsNight") == true
	-- Night Mode: Mafia hunt fighters from farther away, but sneaky Delivery Runners are harder to spot in the dark!
	local bestDist = if isNight then 80 else 62
	local runnerVision = if isNight then 26 else 42

	-- Central Market Peace Truce: Food Mafia in/near Central Market NEVER randomly attack unless the player stole a shipment!
	local function isInCentralMarket(pos: Vector3): boolean
		return math.abs(pos.X) <= 195 and math.abs(pos.Z) <= 195
	end
	local inCentralSpinZone = isInCentralMarket(myPos)
	local function hasPlayerStolenShipment(p: Player): boolean
		local untilAttr = p:GetAttribute("StolenShipmentUntil")
		if typeof(untilAttr) == "number" and untilAttr > os.clock() then
			return true
		end
		return p:GetAttribute("CarryingCrate") ~= nil
	end

	if not inCentralSpinZone then
		for _, runner in ipairs(CollectionService:GetTagged("PlayerDeliveryRunner")) do
			if runner:IsA("Model") then
				local rRoot = runner:FindFirstChild("HumanoidRootPart")
				local rHum = runner:FindFirstChildOfClass("Humanoid")
				if rRoot and rRoot:IsA("BasePart") and rHum and rHum.Health > 0 and not isInsideAnySafeBase(rRoot.Position) then
					local d = (rRoot.Position - myPos).Magnitude
					if d < runnerVision then
						bestDist = d; bestHum = rHum; bestPos = rRoot.Position
					end
				end
			end
		end
	end

	for _, tagName in ipairs({ "PlayerBodyguardUnit", "PlayerRaiderUnit", "HiredDefenseCompanion" }) do
		for _, raider in ipairs(CollectionService:GetTagged(tagName)) do
			if raider:IsA("Model") then
				local allowAggro = true
				if inCentralSpinZone then
					local ownerId = raider:GetAttribute("OwnerUserId")
					local ownerPlayer = if typeof(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
					allowAggro = (ownerPlayer ~= nil and hasPlayerStolenShipment(ownerPlayer))
				end
				if allowAggro then
					local rRoot = raider:FindFirstChild("HumanoidRootPart")
					local rHum = raider:FindFirstChildOfClass("Humanoid")
					if rRoot and rRoot:IsA("BasePart") and rHum and rHum.Health > 0 and not isInsideAnySafeBase(rRoot.Position) then
						local d = (rRoot.Position - myPos).Magnitude
						if d < bestDist then
							bestDist = d; bestHum = rHum; bestPos = rRoot.Position
						end
					end
				end
			end
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local pRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
		local pHum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		if pRoot and pRoot:IsA("BasePart") and pHum and pHum.Health > 0 and not isInsideAnySafeBase(pRoot.Position) then
			local targetInCentral = inCentralSpinZone or isInCentralMarket(pRoot.Position)
			local allowPlayerAggro = if targetInCentral then hasPlayerStolenShipment(player) else true
			if allowPlayerAggro then
				local d = (pRoot.Position - myPos).Magnitude
				if d < bestDist then
					bestDist = d; bestHum = pHum; bestPos = pRoot.Position
				end
			end
		end
	end

	if bestHum and bestPos then
		local victimModel = bestHum.Parent
		local victimPlayer = if victimModel and victimModel:IsA("Model") then Players:GetPlayerFromCharacter(victimModel) else nil
		if bestDist <= 12 and (now - agent.LastAttackAt) >= 1.15 then
			agent.LastAttackAt = now
			MafiaVisualBuilder.TriggerAttackAnim(agent.Model)
			if victimPlayer then
				CombatLockService.MarkUnderAttack(victimPlayer, myPos, if agent.IsBoss then "Food Mafia Capo" else "Food Mafia Enforcer")
			end
			bestHum:TakeDamage(if agent.IsBoss then 26 else 18)
			BlackMarketService.BroadcastSFX("MeleeHit", bestPos)
		elseif bestDist > 12 and bestDist <= 60 and (now - agent.LastAttackAt) >= (if agent.IsBoss then 1.05 else 1.5) then
			agent.LastAttackAt = now
			MafiaVisualBuilder.TriggerAttackAnim(agent.Model)
			if victimPlayer then
				CombatLockService.MarkUnderAttack(victimPlayer, myPos, if agent.IsBoss then "Food Mafia Capo" else "Food Mafia Enforcer")
			end
			local fromPos = agent.Root.Position + Vector3.new(0, 1.4, 0)
			local tracerCol = if agent.IsBoss then Color3.fromRGB(255, 206, 54) else Color3.fromRGB(255, 62, 86)
			BlackMarketService.SpawnBulletTracer(fromPos, bestPos, tracerCol)
			BlackMarketService.BroadcastSFX(if agent.IsBoss then "SMGShot" else "EnemyShot", fromPos)
			if math.random() < 0.76 then
				bestHum:TakeDamage(if agent.IsBoss then 18 else 14)
				BlackMarketService.BroadcastSFX("MeleeHit", bestPos)
			end
		end
		agent.Humanoid:MoveTo(bestPos)
		return true
	end
	return false
end

function MafiaService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local existing = Workspace:FindFirstChild("FoodMafiaSyndicate")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		mafiaFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "FoodMafiaSyndicate"
		f.Parent = Workspace
		mafiaFolder = f
	end

	ensureSyndicate()
	print("[Food Empire] MafiaService started (4 Food Mafia Enforcers + Capo Boss + Shakedowns & Shipment Heists active)!")

	aiThread = task.spawn(function()
		task.wait(16)
		local respawnTimer = 0
		local shakedownTimer = 25
		while isRunning do
			task.wait(DECISION_INTERVAL)
			if not isRunning then break end

			respawnTimer += DECISION_INTERVAL
			if respawnTimer >= RESPAWN_DELAY then
				respawnTimer = 0
				ensureSyndicate()
			end

			-- Trigger periodic Protection Racket Shakedown at a player's Restaurant Front Gate!
			shakedownTimer += DECISION_INTERVAL
			if shakedownTimer >= SHAKEDOWN_INTERVAL then
				shakedownTimer = 0
				local eligiblePlayers: { Player } = {}
				for _, p in ipairs(Players:GetPlayers()) do
					if BaseService.GetPlayerBaseSlot(p)
						and not NightMafiaRaidService.IsRaidActive(p)
						and PlayerDataService.GetProfile(p).Coins >= 60
					then
						table.insert(eligiblePlayers, p)
					end
				end
				if #eligiblePlayers > 0 then
					local victim = eligiblePlayers[math.random(1, #eligiblePlayers)]
					for _, agent in ipairs(activeAgents) do
						if not agent.IsBoss and not agent.ShakedownTarget and agent.Humanoid.Health > 0 then
							agent.ShakedownTarget = victim
							agent.ShakedownDeadline = os.clock() + SHAKEDOWN_WINDOW
							sendToast(victim, "🕶️ FOOD MAFIA heading to your front gate for Protection Tax! Fight them off!")
							break
						end
					end
				end
			end

			local now = os.clock()
			for _, agent in ipairs(activeAgents) do
				if agent.Model.Parent and agent.Humanoid.Health > 0 then
					-- Handle active Protection Racket Shakedown
					if agent.ShakedownTarget then
						local victim = agent.ShakedownTarget
						local gatePos = if victim.Parent then getFrontGatePos(victim) else nil
						if not victim.Parent or not gatePos then
							agent.ShakedownTarget = nil
						elseif now >= agent.ShakedownDeadline then
							local slot = BaseService.GetPlayerBaseSlot(victim)
							local defTier = if slot then BaseService.GetDefenseTier(slot) else 1
							local prof = PlayerDataService.GetProfile(victim)
							local rawTax = math.clamp(math.floor(prof.Coins * 0.12), 20, 110)
							local finalTax = if defTier >= 2 then math.floor(rawTax * 0.45) else rawTax
							if defTier >= 2 then
								agent.Humanoid:TakeDamage(75)
							end
							if finalTax > 0 and PlayerDataService.SpendCoins(victim, finalTax) then
								sendToast(victim, string.format("🕶️ Food Mafia shook down -%d Gold! Upgrade Defenses / fight back!", finalTax))
							end
							agent.ShakedownTarget = nil
						else
							if not tryMafiaAmbush(agent) then
								navigateTo(agent, gatePos)
							end
						end
					else
						-- Standard Mafia Ambush + Central Shipment Heist + Boulevard Patrol
						if not tryMafiaAmbush(agent) then
							ShipmentService.TryRivalInterceptAtPosition(agent.Root.Position)
							local shipPos = ShipmentService.GetBestActiveShipmentPosition(nil)
							local dest = if not agent.IsBoss and shipPos and (shipPos - Vector3.new(0, 4, 0)).Magnitude > 12
								then shipPos
								else PATROL_POINTS[agent.PatrolIndex]
							if (agent.Root.Position - dest).Magnitude <= 14 then
								agent.PatrolIndex = (agent.PatrolIndex % #PATROL_POINTS) + 1
							end
							navigateTo(agent, dest)
						end
					end
				end
			end
		end
	end)
end

function MafiaService.Stop(): ()
	isRunning = false
	if aiThread then
		task.cancel(aiThread)
		aiThread = nil
	end
	if mafiaFolder then
		mafiaFolder:ClearAllChildren()
	end
	table.clear(activeAgents)
end

return MafiaService
