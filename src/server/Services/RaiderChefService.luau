--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)
local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local SectorService = require("./SectorService")
local MonetizationService = require("./MonetizationService")
local ShipmentService = require("./ShipmentService")
local TurfService = require("./TurfService")

type RaiderAgent = {
	Owner: Player,
	Index: number,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	LastAttackAt: number,
}

local RaiderChefService = {}

RaiderChefService.MAX_RAIDERS = 2
RaiderChefService.COSTS = { [1] = 2250, [2] = 4250 }

local WALK_SPEED = 18
local RESPAWN_DELAY = 15
local DUEL_RANGE = 11
local DUEL_DAMAGE = 28
local DUEL_COOLDOWN = 1.1

local isRunning = false
local raiderFolder: Folder? = nil
local agentsByPlayer: { [Player]: { RaiderAgent } } = {}
local aiThread: thread? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local unsubBase: (() -> ())? = nil

function RaiderChefService.GetRaiderCount(player: Player): number
	local fromCoins = PlayerDataService.GetProfile(player).RaiderCount or 0
	if MonetizationService.HasPass(player, "RaiderChefSquad") then
		return RaiderChefService.MAX_RAIDERS
	end
	return math.clamp(fromCoins, 0, RaiderChefService.MAX_RAIDERS)
end

function RaiderChefService.GetNextCost(player: Player): number?
	local count = RaiderChefService.GetRaiderCount(player)
	if count >= RaiderChefService.MAX_RAIDERS then
		return nil
	end
	return RaiderChefService.COSTS[count + 1]
end

local function getZoneForSector(sectorId: string): BasePart?
	for _, zone in ipairs(CollectionService:GetTagged("CaptureZone")) do
		if zone:IsA("BasePart") and zone:IsDescendantOf(Workspace) and zone:GetAttribute("SectorId") == sectorId then
			return zone
		end
	end
	return nil
end

local function getGateSpawnPosition(player: Player, index: number): Vector3
	local slot = BaseService.GetPlayerBaseSlot(player)
	if slot then
		local baseModel = BaseService.GetBaseModel(slot)
		if baseModel then
			local spawnPart = baseModel:FindFirstChild("BaseSpawn")
			if spawnPart and spawnPart:IsA("BasePart") then
				-- Spawn just outside the castle gate / courtyard path
				local offset = Vector3.new(if index == 1 then -8 else 8, 5, 0)
				return spawnPart.Position + offset
			end
		end
	end
	return Vector3.new(0, 5, 40)
end

local function buildRaiderChefModel(owner: Player, index: number, spawnPos: Vector3): RaiderAgent
	local slot = BaseService.GetPlayerBaseSlot(owner)
	local teamCol = if slot and SectorConfig.FactionColors[slot]
		then SectorConfig.FactionColors[slot]
		else Color3.fromRGB(58, 152, 232)

	local modelName = string.format("RaiderChef_%d_%d", owner.UserId, index)
	local rig = MafiaVisualBuilder.BuildChefRig(modelName, teamCol, 1.0, CFrame.new(spawnPos), true)
	local model = rig.Model
	local root = rig.Root
	local head = rig.Head

	-- Nameplate + Live Health Bar (Zero Emojis)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(168, 40)
	bb.StudsOffset = Vector3.new(0, 3.1, 0)
	bb.MaxDistance = 130
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = "RAIDER CHEF #" .. tostring(index)
	lbl.TextSize = 10
	lbl.TextColor3 = Color3.fromRGB(238, 236, 232)
	lbl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = lbl
	local st = Instance.new("UIStroke")
	st.Color = teamCol
	st.Thickness = 1.2
	st.Parent = lbl

	local hpBg = Instance.new("Frame")
	hpBg.Position = UDim2.new(0.05, 0, 0, 24)
	hpBg.Size = UDim2.new(0.90, 0, 0, 10)
	hpBg.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
	hpBg.Parent = bb
	local hpc = Instance.new("UICorner")
	hpc.CornerRadius = UDim.new(0, 3)
	hpc.Parent = hpBg

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(78, 146, 98)
	hpFill.Parent = hpBg
	local hpfc = Instance.new("UICorner")
	hpfc.CornerRadius = UDim.new(0, 3)
	hpfc.Parent = hpFill

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 120
	hum.Health = 120
	hum.WalkSpeed = WALK_SPEED
	hum.HipHeight = 2.25
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	hum.HealthChanged:Connect(function(hp: number)
		hpFill.Size = UDim2.fromScale(math.clamp(hp / math.max(1, hum.MaxHealth), 0, 1), 1)
	end)

	model.PrimaryPart = root
	model:SetAttribute("Faction", BaseService.GetPlayerFactionId(owner))
	if slot then
		model:SetAttribute("BaseSlot", slot)
	end
	model:SetAttribute("OwnerUserId", owner.UserId)
	CollectionService:AddTag(model, "PlayerRaiderUnit")
	CollectionService:AddTag(model, "AnimatedRaiderLimbs")

	model.Parent = raiderFolder or Workspace

	return {
		Owner = owner,
		Index = index,
		Model = model,
		Humanoid = hum,
		Root = root,
		LastAttackAt = 0,
	}
end

local function clearPlayerRaiders(player: Player): ()
	local list = agentsByPlayer[player]
	if not list then
		return
	end
	for _, agent in ipairs(list) do
		if agent.Model.Parent then
			agent.Model:Destroy()
		end
	end
	agentsByPlayer[player] = nil
end

function RaiderChefService.SyncRaidersForPlayer(player: Player): ()
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return
	end

	local targetCount = RaiderChefService.GetRaiderCount(player)
	local list = agentsByPlayer[player]
	if not list then
		list = {}
		agentsByPlayer[player] = list
	end

	-- Remove destroyed entries first
	for i = #list, 1, -1 do
		if not list[i].Model.Parent or list[i].Humanoid.Health <= 0 then
			table.remove(list, i)
		end
	end

	while #list < targetCount do
		local nextIndex = #list + 1
		local spawnPos = getGateSpawnPosition(player, nextIndex)
		local agent = buildRaiderChefModel(player, nextIndex, spawnPos)
		agent.Humanoid.Died:Connect(function()
			task.delay(2.5, function()
				if agent.Model.Parent then
					agent.Model:Destroy()
				end
			end)
			task.delay(RESPAWN_DELAY, function()
				if isRunning and player.Parent then
					RaiderChefService.SyncRaidersForPlayer(player)
				end
			end)
		end)
		table.insert(list, agent)
	end
end

function RaiderChefService.TryHireRaider(player: Player): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Castle Base first!"
	end

	local current = RaiderChefService.GetRaiderCount(player)
	local cost = RaiderChefService.GetNextCost(player)
	if not cost then
		return false, "Max Raider Chefs deployed (2/2)!"
	end

	if not PlayerDataService.SpendCoins(player, cost) then
		return false, string.format("Need %d Gold to deploy Raider Chef #%d!", cost, current + 1)
	end

	PlayerDataService.SetRaiderCount(player, current + 1)
	RaiderChefService.SyncRaidersForPlayer(player)
	print(string.format("[RaiderChefService] %s deployed Raider Chef #%d!", player.Name, current + 1))
	return true, string.format("Raider Chef #%d deployed! Marching to capture territories!", current + 1)
end

local function pickTargetSectorForRaider(owner: Player, currentPos: Vector3, index: number): string?
	local myFaction = BaseService.GetPlayerFactionId(owner)
	local bestId: string? = nil
	local bestScore = -math.huge

	for sectorId, sector in pairs(SectorService.GetAllSectors()) do
		local zone = getZoneForSector(sectorId)
		if zone then
			local dist = (zone.Position - currentPos).Magnitude
			local priority = 0
			if sector.Owner == "Rival" then
				-- Love liberating Rival territories!
				priority = 620
			elseif sector.Owner == "Neutral" then
				-- Prefer Fishing Port early when only Fish Warehouse unlocked, or nearest neutral
				priority = if sectorId == "FishingPort" then 590 else 540
			elseif sector.Owner ~= myFaction then
				priority = 560
			else
				-- Patrol owned territories if all 4 are already yours!
				priority = if sector.Status == "Contested" then 650 else 120
			end
			-- Split Raider #1 and Raider #2 cleanly across different territories
			local splitBias = if (index == 2 and (sectorId == "VegetableFarm" or sectorId == "Ranch")) then 45 else 0
			local score = priority + splitBias - dist * 0.42
			if score > bestScore then
				bestScore = score
				bestId = sectorId
			end
		end
	end
	return bestId
end

local function stepRaiderAgent(agent: RaiderAgent): ()
	if not agent.Model.Parent or agent.Humanoid.Health <= 0 then
		return
	end

	-- 1. Defend Owner & engage Mafia / Rival Chefs / Enemy Turf Guards!
	local now = os.clock()
	local myFaction = BaseService.GetPlayerFactionId(agent.Owner)
	local ownerChar = agent.Owner.Character
	local ownerRoot = if ownerChar then ownerChar:FindFirstChild("HumanoidRootPart") else nil
	for _, tagName in ipairs({ "MafiaUnit", "RivalAIUnit", "TurfGuardUnit" }) do
		for _, rival in ipairs(CollectionService:GetTagged(tagName)) do
			if rival:IsA("Model") and rival:GetAttribute("Faction") ~= myFaction then
				local rRoot = rival:FindFirstChild("HumanoidRootPart")
				local rHum = rival:FindFirstChildOfClass("Humanoid")
				if rRoot and rRoot:IsA("BasePart") and rHum and rHum.Health > 0 then
					local dMe = (rRoot.Position - agent.Root.Position).Magnitude
					local nearOwner = ownerRoot and ownerRoot:IsA("BasePart") and ((rRoot.Position - ownerRoot.Position).Magnitude <= 46)
					if dMe <= DUEL_RANGE then
						if (now - agent.LastAttackAt) >= DUEL_COOLDOWN then
							agent.LastAttackAt = now
							rHum:TakeDamage(DUEL_DAMAGE)
						end
						agent.Humanoid:MoveTo(rRoot.Position)
						return
					elseif dMe <= 40 or (nearOwner and dMe <= 90) then
						agent.Humanoid:MoveTo(rRoot.Position)
						return
					end
				end
			end
		end
	end

	-- 2. Raider #1 captures & defends Urban Mafia Territory Blocks; Raider #2 claims Shipments or captures blocks!
	ShipmentService.TryRaiderClaimAtPosition(agent.Owner, agent.Root.Position)
	local _, turfTarget = TurfService.GetBestCaptureTargetForPlayer(agent.Owner, agent.Root.Position)
	local shipTarget = ShipmentService.GetBestActiveShipmentPosition(nil)
	local targetPos: Vector3
	if agent.Index == 1 and turfTarget then
		targetPos = turfTarget
	elseif shipTarget and (shipTarget - Vector3.new(0, 4, 0)).Magnitude > 10 then
		targetPos = shipTarget
	elseif turfTarget then
		targetPos = turfTarget
	else
		targetPos = Vector3.new(if agent.Index == 1 then 48 else -48, 4, 48)
	end

	if (targetPos - agent.Root.Position).Magnitude <= 10 then
		return
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2.5,
		AgentHeight = 6,
		AgentCanJump = true,
	})
	local ok = pcall(function()
		path:ComputeAsync(agent.Root.Position, targetPos)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		local stepTarget = waypoints[math.min(5, #waypoints)]
		if stepTarget then
			if stepTarget.Action == Enum.PathWaypointAction.Jump then
				agent.Humanoid.Jump = true
			end
			agent.Humanoid:MoveTo(stepTarget.Position)
			return
		end
	end
	agent.Humanoid:MoveTo(targetPos)
end

function RaiderChefService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local folder = Workspace:FindFirstChild("EmpireRaiderChefs")
	if folder and folder:IsA("Folder") then
		raiderFolder = folder
	else
		local created = Instance.new("Folder")
		created.Name = "EmpireRaiderChefs"
		created.Parent = Workspace
		raiderFolder = created
	end

	unsubBase = BaseService.OnBaseAssigned(function(player)
		RaiderChefService.SyncRaidersForPlayer(player)
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		clearPlayerRaiders(player)
	end)

	aiThread = task.spawn(function()
		while isRunning do
			task.wait(2.0)
			if not isRunning then
				break
			end
			for _, player in ipairs(Players:GetPlayers()) do
				if RaiderChefService.GetRaiderCount(player) > 0 then
					RaiderChefService.SyncRaidersForPlayer(player)
				end
				local list = agentsByPlayer[player]
				if list then
					for _, agent in ipairs(list) do
						stepRaiderAgent(agent)
					end
				end
			end
		end
	end)

	print("[Food Empire] RaiderChefService started (Empire Raider Chefs march out to capture Neutral & Rival territories)!")
end

function RaiderChefService.Stop(): ()
	isRunning = false
	if aiThread then
		task.cancel(aiThread)
		aiThread = nil
	end
	if unsubBase then
		unsubBase()
		unsubBase = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for p in pairs(agentsByPlayer) do
		clearPlayerRaiders(p)
	end
end

return RaiderChefService
