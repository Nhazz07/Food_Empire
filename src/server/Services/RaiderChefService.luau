--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local SectorService = require("./SectorService")
local MonetizationService = require("./MonetizationService")
local ShipmentService = require("./ShipmentService")

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
RaiderChefService.COSTS = { [1] = 450, [2] = 850 }

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
	local darkTrim = Color3.new(teamCol.R * 0.72, teamCol.G * 0.72, teamCol.B * 0.72)

	local model = Instance.new("Model")
	model.Name = string.format("RaiderChef_%d_%d", owner.UserId, index)

	local function makePart(name: string, size: Vector3, color: Color3, mat: Enum.Material, shape: Enum.PartType?, collide: boolean): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = mat
		if shape then
			p.Shape = shape
		end
		p.CanCollide = collide
		p.CanTouch = collide
		p.Massless = not collide
		p.CastShadow = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local function weldTo(parentPart: BasePart, childPart: BasePart, relCF: CFrame): ()
		childPart.CFrame = parentPart.CFrame * relCF
		local w = Instance.new("WeldConstraint")
		w.Part0 = parentPart
		w.Part1 = childPart
		w.Parent = childPart
	end

	local function makeJoint(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
		part1.CFrame = part0.CFrame * c0 * c1:Inverse()
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = part0
		m.Part1 = part1
		m.C0 = c0
		m.C1 = c1
		m.Parent = part0
		return m
	end

	local skinCol = Color3.fromRGB(246, 212, 178)
	local pantsCol = Color3.fromRGB(44, 52, 68)
	local bootCol = Color3.fromRGB(26, 28, 36)

	-- 1. Team-Colored Executive Raider Coat + White Apron
	local root = makePart("HumanoidRootPart", Vector3.new(2.4, 2.75, 1.35), teamCol, Enum.Material.SmoothPlastic, nil, true)
	root.CFrame = CFrame.new(spawnPos)

	local apron = makePart("Apron", Vector3.new(2.5, 1.45, 1.45), Color3.fromRGB(250, 250, 254), Enum.Material.SmoothPlastic, nil, false)
	weldTo(root, apron, CFrame.new(0, -0.68, 0))

	-- 2. Head + Determined Eyes + Pleated Team Chef Toque Hat
	local head = makePart("Head", Vector3.new(1.95, 1.95, 1.95), skinCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
	weldTo(root, head, CFrame.new(0, 2.3, 0))

	for _, ex in ipairs({ -0.34, 0.34 }) do
		local eye = makePart("Eye", Vector3.new(0.24, 0.26, 0.14), Color3.fromRGB(24, 24, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
		weldTo(head, eye, CFrame.new(ex, 0.12, -0.9))
	end

	local hatBand = makePart("HatBand", Vector3.new(0.72, 2.05, 2.05), darkTrim, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, false)
	weldTo(head, hatBand, CFrame.new(0, 1.0, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local hatPuff = makePart("ChefHat", Vector3.new(2.4, 1.55, 2.35), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
	hatPuff.CastShadow = false
	weldTo(head, hatPuff, CFrame.new(0, 1.85, 0))

	-- 3. Articulated Arms + Glowing Golden Spatula!
	local leftArm = makePart("LeftArm", Vector3.new(0.9, 2.4, 0.9), teamCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("LeftArmJoint", root, leftArm, CFrame.new(-1.7, 1.0, 0), CFrame.new(0, 1.0, 0))
	local leftHand = makePart("LeftHand", Vector3.new(0.78, 0.7, 0.78), skinCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
	weldTo(leftArm, leftHand, CFrame.new(0, -1.32, 0))

	local rightArm = makePart("RightArm", Vector3.new(0.9, 2.4, 0.9), teamCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("RightArmJoint", root, rightArm, CFrame.new(1.7, 1.0, 0), CFrame.new(0, 1.0, 0))
	local rightHand = makePart("RightHand", Vector3.new(0.78, 0.7, 0.78), skinCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
	weldTo(rightArm, rightHand, CFrame.new(0, -1.32, 0))

	local spatHandle = makePart("SpatulaHandle", Vector3.new(0.28, 0.28, 1.55), Color3.fromRGB(132, 86, 54), Enum.Material.Wood, nil, false)
	weldTo(rightHand, spatHandle, CFrame.new(0, -0.05, -0.95))
	local spatBlade = makePart("SpatulaBlade", Vector3.new(0.95, 0.2, 1.35), Color3.fromRGB(255, 212, 54), Enum.Material.Neon, nil, false)
	spatBlade.CastShadow = false
	weldTo(spatHandle, spatBlade, CFrame.new(0, 0, -1.35))

	-- 4. Articulated Legs + Chef Boots
	local leftLeg = makePart("LeftLeg", Vector3.new(1.0, 2.45, 1.0), pantsCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("LeftLegJoint", root, leftLeg, CFrame.new(-0.6, -1.38, 0), CFrame.new(0, 1.22, 0))
	local leftBoot = makePart("LeftBoot", Vector3.new(1.08, 0.6, 1.4), bootCol, Enum.Material.SmoothPlastic, nil, false)
	weldTo(leftLeg, leftBoot, CFrame.new(0, -1.18, -0.16))

	local rightLeg = makePart("RightLeg", Vector3.new(1.0, 2.45, 1.0), pantsCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("RightLegJoint", root, rightLeg, CFrame.new(0.6, -1.38, 0), CFrame.new(0, 1.22, 0))
	local rightBoot = makePart("RightBoot", Vector3.new(1.08, 0.6, 1.4), bootCol, Enum.Material.SmoothPlastic, nil, false)
	weldTo(rightLeg, rightBoot, CFrame.new(0, -1.18, -0.16))

	-- 5. Nameplate + Live Health Bar
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(165, 44)
	bb.StudsOffset = Vector3.new(0, 3.7, 0)
	bb.MaxDistance = 130
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 24)
	lbl.BackgroundColor3 = teamCol
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = "⚔️ RAIDER CHEF #" .. tostring(index)
	lbl.TextSize = 13
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 7)
	c.Parent = lbl
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(16, 20, 30)
	st.Thickness = 1.5
	st.Parent = lbl

	local hpBg = Instance.new("Frame")
	hpBg.Position = UDim2.new(0.08, 0, 0, 29)
	hpBg.Size = UDim2.new(0.84, 0, 0, 9)
	hpBg.BackgroundColor3 = Color3.fromRGB(24, 26, 36)
	hpBg.Parent = bb
	local hpc = Instance.new("UICorner")
	hpc.CornerRadius = UDim.new(0, 5)
	hpc.Parent = hpBg

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(72, 224, 108)
	hpFill.Parent = hpBg
	local hpfc = Instance.new("UICorner")
	hpfc.CornerRadius = UDim.new(0, 5)
	hpfc.Parent = hpFill

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 120
	hum.Health = 120
	hum.WalkSpeed = WALK_SPEED
	hum.HipHeight = 2.6
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	hum.HealthChanged:Connect(function(hp: number)
		hpFill.Size = UDim2.fromScale(math.clamp(hp / math.max(1, hum.MaxHealth), 0, 1), 1)
	end)

	model.PrimaryPart = root
	model:SetAttribute("Faction", "Player_" .. tostring(owner.UserId))
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
	local myFaction = "Player_" .. tostring(owner.UserId)
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

	-- 1. Defend Owner if a Rival Chef or Mafia is attacking near the Owner (within 50 studs)!
	local now = os.clock()
	local ownerChar = agent.Owner.Character
	local ownerRoot = if ownerChar then ownerChar:FindFirstChild("HumanoidRootPart") else nil
	for _, tagName in ipairs({ "MafiaUnit", "RivalAIUnit" }) do
		for _, rival in ipairs(CollectionService:GetTagged(tagName)) do
			if rival:IsA("Model") then
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
					elseif dMe <= 36 or (nearOwner and dMe <= 90) then
						agent.Humanoid:MoveTo(rRoot.Position)
						return
					end
				end
			end
		end
	end

	-- 2. Collect arrived Central Plaza Shipments & patrol the Expanded Center!
	ShipmentService.TryRaiderClaimAtPosition(agent.Owner, agent.Root.Position)
	local shipTarget = ShipmentService.GetBestActiveShipmentPosition(nil)
	local targetPos = shipTarget or Vector3.new(if agent.Index == 1 then 48 else -48, 4, 48)

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
