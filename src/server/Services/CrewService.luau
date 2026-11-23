--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local RecipeConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RecipeConfig")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local MonetizationService = require("./MonetizationService")

export type AutoServeCallback = (player: Player) -> ()

local CrewService = {}

local CREW_SPEED_BONUS_PER_MEMBER = 0.15
local AUTO_SERVE_INTERVAL = 6

local crewModels: { [Player]: { Model } } = {}
local autoServeHandler: AutoServeCallback? = nil
local isRunning = false
local loopThread: thread? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local unsubscribeProfile: (() -> ())? = nil
local unsubscribeBase: (() -> ())? = nil

-- Keep hired Crew Chefs INSIDE the Restaurant Kitchen cooking behind the range!
local CREW_OFFSETS: { Vector3 } = {
	Vector3.new(-25, 1.5, -15),
	Vector3.new(-19, 1.5, -11),
	Vector3.new(-12, 1.5, -15),
	Vector3.new(-6, 1.5, -11),
}

function CrewService.SetAutoServeHandler(handler: AutoServeCallback): ()
	autoServeHandler = handler
end

function CrewService.GetCrewCount(player: Player): number
	return PlayerDataService.GetProfile(player).CrewCount
end

function CrewService.GetNextHireCost(player: Player): number
	local count = CrewService.GetCrewCount(player)
	return RecipeConfig.CrewHireBaseCost + count * RecipeConfig.CrewHireCostStep
end

function CrewService.GetMaxCrew(player: Player): number
	local level = PlayerDataService.GetProfile(player).RestaurantLevel
	local tier = RecipeConfig.RestaurantTiers[level] or RecipeConfig.RestaurantTiers[1]
	return tier.MaxCrew + MonetizationService.GetBonusCrewSlots(player)
end

function CrewService.GetCookSpeedMultiplier(player: Player): number
	local count = CrewService.GetCrewCount(player)
	return 1 + count * CREW_SPEED_BONUS_PER_MEMBER
end

local function clearCrewVisuals(player: Player): ()
	local list = crewModels[player]
	if not list then
		return
	end
	for _, m in ipairs(list) do
		if m.Parent then
			m:Destroy()
		end
	end
	crewModels[player] = nil
end

local function spawnCrewChef(parent: Instance, index: number, worldCF: CFrame, accentColor: Color3): Model
	local npc = Instance.new("Model")
	npc.Name = "CrewChef_" .. tostring(index)
	local cf = worldCF * CFrame.new(0, 3.6, 0)

	local function cPart(name: string, sz: Vector3, rel: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = cf * rel
		p.Color = col
		p.Material = mat
		if shape then p.Shape = shape end
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Parent = npc
		return p
	end

	local body = cPart("Torso", Vector3.new(2.3, 2.7, 1.35), CFrame.new(), Color3.fromRGB(250, 250, 252), Enum.Material.SmoothPlastic, nil)
	cPart("Apron", Vector3.new(2.4, 1.45, 1.45), CFrame.new(0, -0.68, 0), accentColor, Enum.Material.SmoothPlastic, nil)
	local head = cPart("Head", Vector3.new(1.9, 1.9, 1.9), CFrame.new(0, 2.25, 0), Color3.fromRGB(246, 212, 178), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	cPart("EyeL", Vector3.new(0.22, 0.24, 0.12), CFrame.new(-0.32, 2.34, -0.9), Color3.fromRGB(24, 24, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	cPart("EyeR", Vector3.new(0.22, 0.24, 0.12), CFrame.new(0.32, 2.34, -0.9), Color3.fromRGB(24, 24, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	cPart("HatBand", Vector3.new(0.7, 1.95, 1.95), CFrame.new(0, 3.25, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(245, 245, 250), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	cPart("HatPuff", Vector3.new(2.35, 1.5, 2.3), CFrame.new(0, 4.05, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	cPart("LeftArm", Vector3.new(0.85, 2.35, 0.85), CFrame.new(-1.6, 0.05, 0), Color3.fromRGB(250, 250, 252), Enum.Material.SmoothPlastic, nil)
	cPart("RightArm", Vector3.new(0.85, 2.35, 0.85), CFrame.new(1.6, 0.2, -0.45) * CFrame.Angles(math.rad(35), 0, 0), Color3.fromRGB(250, 250, 252), Enum.Material.SmoothPlastic, nil)
	cPart("Spoon", Vector3.new(0.24, 2.2, 0.24), CFrame.new(1.6, 0.65, -1.55) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(168, 114, 62), Enum.Material.Wood, nil)
	cPart("LeftLeg", Vector3.new(0.95, 2.4, 0.95), CFrame.new(-0.58, -2.45, 0), Color3.fromRGB(46, 52, 66), Enum.Material.SmoothPlastic, nil)
	cPart("RightLeg", Vector3.new(0.95, 2.4, 0.95), CFrame.new(0.58, -2.45, 0), Color3.fromRGB(46, 52, 66), Enum.Material.SmoothPlastic, nil)
	cPart("LeftShoe", Vector3.new(1.05, 0.55, 1.35), CFrame.new(-0.58, -3.48, -0.15), Color3.fromRGB(26, 28, 34), Enum.Material.SmoothPlastic, nil)
	cPart("RightShoe", Vector3.new(1.05, 0.55, 1.35), CFrame.new(0.58, -3.48, -0.15), Color3.fromRGB(26, 28, 34), Enum.Material.SmoothPlastic, nil)

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(116, 26)
	bb.StudsOffset = Vector3.new(0, 3.3, 0)
	bb.MaxDistance = 75
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = accentColor
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = "Chef #" .. tostring(index)
	lbl.TextSize = 13
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Parent = bb

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = lbl

	npc.PrimaryPart = body
	CollectionService:AddTag(npc, "AnimatedKitchenChef")
	npc.Parent = parent
	return npc
end

function CrewService.SyncCrewVisuals(player: Player): ()
	clearCrewVisuals(player)

	local count = CrewService.GetCrewCount(player)
	if count <= 0 then
		return
	end

	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return
	end

	local baseModel = BaseService.GetBaseModel(slot)
	if not baseModel then
		return
	end

	local hq = baseModel:FindFirstChild("RestaurantHQ")
	if not hq or not hq:IsA("Model") or not hq.PrimaryPart then
		return
	end

	local accentAttr = baseModel:GetAttribute("AccentColor")
	local accentColor = if typeof(accentAttr) == "Color3" then accentAttr else Color3.fromRGB(74, 188, 86)

	local spawned: { Model } = {}
	for i = 1, math.min(count, #CREW_OFFSETS) do
		local worldCF = hq.PrimaryPart.CFrame * CFrame.new(CREW_OFFSETS[i])
		table.insert(spawned, spawnCrewChef(hq, i, worldCF, accentColor))
	end
	crewModels[player] = spawned
end

function CrewService.TryHireCrew(player: Player): (boolean, string)
	local current = CrewService.GetCrewCount(player)
	local maxCrew = CrewService.GetMaxCrew(player)
	if current >= maxCrew then
		return false, string.format("Max Crew (%d) — Upgrade Restaurant HQ!", maxCrew)
	end

	local cost = CrewService.GetNextHireCost(player)
	if not PlayerDataService.SpendCoins(player, cost) then
		return false, string.format("Need %d Coins", cost)
	end

	PlayerDataService.SetCrewCount(player, current + 1)
	CrewService.SyncCrewVisuals(player)
	print(string.format("[CrewService] %s hired Crew Chef #%d!", player.Name, current + 1))
	return true, "Hired Crew Chef!"
end

function CrewService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	unsubscribeBase = BaseService.OnBaseAssigned(function(player)
		CrewService.SyncCrewVisuals(player)
	end)

	unsubscribeProfile = PlayerDataService.OnProfileChanged(function(player)
		local existing = crewModels[player]
		local targetCount = CrewService.GetCrewCount(player)
		if (existing and #existing or 0) ~= targetCount then
			CrewService.SyncCrewVisuals(player)
		end
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		clearCrewVisuals(player)
	end)

	loopThread = task.spawn(function()
		while isRunning do
			task.wait(AUTO_SERVE_INTERVAL)
			if not isRunning then
				break
			end
			if autoServeHandler then
				for _, player in ipairs(Players:GetPlayers()) do
					if CrewService.GetCrewCount(player) > 0 then
						autoServeHandler(player)
					end
				end
			end
		end
	end)

	print("[Food Empire] CrewService started (hireable Restaurant Crew Chefs + auto-serve active)!")
end

function CrewService.Stop(): ()
	isRunning = false
	if loopThread then
		task.cancel(loopThread)
		loopThread = nil
	end
	if unsubscribeBase then
		unsubscribeBase()
		unsubscribeBase = nil
	end
	if unsubscribeProfile then
		unsubscribeProfile()
		unsubscribeProfile = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for player in pairs(crewModels) do
		clearCrewVisuals(player)
	end
end

return CrewService
