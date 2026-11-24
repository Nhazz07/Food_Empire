--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local MonetizationService = require("./MonetizationService")

export type DeliveryStatus = "Available" | "Active" | "Cooldown"

type DropPoint = {
	Name: string,
	Pos: Vector3,
}

type ExpressOrder = {
	CustomerName: string,
	DishName: string,
	DropName: string,
	DropPos: Vector3,
	BaseGold: number,
	BaseRep: number,
	Duration: number,
	ExpiresAt: number,
	Status: DeliveryStatus,
	DropModel: Model?,
	PromptConn: RBXScriptConnection?,
}

local ExpressDeliveryService = {}

local DROP_POINTS: { DropPoint } = {
	{ Name = "Plaza Fountain",       Pos = Vector3.new(0, 2.2, 26) },
	{ Name = "Royal Hall Steps",     Pos = Vector3.new(0, 2.2, -96) },
	{ Name = "Little Italy Row",     Pos = Vector3.new(-158, 2.2, -266) },
	{ Name = "Jade Tea Arcade",      Pos = Vector3.new(158, 2.2, -266) },
	{ Name = "Sunset Cafe Strip",    Pos = Vector3.new(-158, 2.2, 266) },
	{ Name = "Harborview Bistro",    Pos = Vector3.new(158, 2.2, 266) },
	{ Name = "Black Market Row",       Pos = Vector3.new(-288, 2.2, 216) },
	{ Name = "Spice Bazaar Square",    Pos = Vector3.new(282, 2.2, -142) },
	{ Name = "Shogun Market Terrace",  Pos = Vector3.new(-610, 2.2, -792) },
	{ Name = "Viper Exchange Square",  Pos = Vector3.new(838, 2.2, -792) },
	{ Name = "Blossom Boulevard",      Pos = Vector3.new(-792, 2.2, 610) },
	{ Name = "Pierhead Bistro Row",    Pos = Vector3.new(610, 2.2, 792) },
}

local EXPRESS_MEALS: { { Name: string, Gold: number, Rep: number, Time: number } } = {
	{ Name = "Hot Grilled Island Fish", Gold = 110, Rep = 16, Time = 50 },
	{ Name = "Express Fresh Sushi",     Gold = 135, Rep = 20, Time = 48 },
	{ Name = "Sizzling Steak Box",      Gold = 155, Rep = 24, Time = 46 },
	{ Name = "King Crab Bento",         Gold = 170, Rep = 28, Time = 45 },
	{ Name = "Classic Double Burger",   Gold = 120, Rep = 18, Time = 50 },
	{ Name = "Tropical Smoothie Pack",  Gold = 115, Rep = 16, Time = 52 },
}

local CALLER_NAMES = { "Maya", "Lucas", "Aria", "Ethan", "Sofia", "Liam", "Hana", "Owen", "Ella", "Jay" }

local ordersByPlayer: { [Player]: ExpressOrder } = {}
local comboByPlayer: { [Player]: number } = {}
local onUpdatedCallback: ((player: Player, msg: string?) -> ())? = nil
local isRunning = false
local tickThread: thread? = nil
local dropFolder: Folder? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local unsubBase: (() -> ())? = nil

function ExpressDeliveryService.SetUpdatedCallback(cb: (player: Player, msg: string?) -> ()): ()
	onUpdatedCallback = cb
end

local function clearDropVisual(order: ExpressOrder?): ()
	if not order then
		return
	end
	if order.PromptConn then
		order.PromptConn:Disconnect()
		order.PromptConn = nil
	end
	if order.DropModel and order.DropModel.Parent then
		order.DropModel:Destroy()
	end
	order.DropModel = nil
end

local function createNewOffer(player: Player): ()
	clearDropVisual(ordersByPlayer[player])
	local meal = EXPRESS_MEALS[math.random(1, #EXPRESS_MEALS)]
	local dp = DROP_POINTS[math.random(1, #DROP_POINTS)]
	local caller = CALLER_NAMES[math.random(1, #CALLER_NAMES)]

	ordersByPlayer[player] = {
		CustomerName = caller,
		DishName = meal.Name,
		DropName = dp.Name,
		DropPos = dp.Pos,
		BaseGold = meal.Gold,
		BaseRep = meal.Rep,
		Duration = meal.Time,
		ExpiresAt = 0,
		Status = "Available",
		DropModel = nil,
		PromptConn = nil,
	}

	if onUpdatedCallback then
		onUpdatedCallback(player, nil)
	end
end

local function completeDelivery(player: Player): ()
	local order = ordersByPlayer[player]
	if not order or order.Status ~= "Active" then
		return
	end

	local remaining = math.max(0, order.ExpiresAt - os.clock())
	local nextCombo = math.min(5, (comboByPlayer[player] or 0) + 1)
	comboByPlayer[player] = nextCombo

	local speedTip = math.floor(remaining * 2.2)
	local comboBonus = (nextCombo - 1) * 30
	local passMult = MonetizationService.GetPayoutMultiplier(player)
	local repMult = MonetizationService.GetRepMultiplier(player)

	local totalGold = math.floor((order.BaseGold + speedTip + comboBonus) * passMult)
	local totalRep = math.floor((order.BaseRep + nextCombo * 3) * repMult)
	local totalExp = 35 + nextCombo * 8

	clearDropVisual(order)
	order.Status = "Cooldown"
	order.ExpiresAt = os.clock() + 9

	PlayerDataService.AddRewards(player, totalGold, totalExp, totalRep)

	local msg = string.format(
		"🛵 DELIVERED to %s! +%d Gold (Tip +%dG • Combo x%d) & +%d Rep!",
		order.CustomerName,
		totalGold,
		speedTip,
		nextCombo,
		totalRep
	)
	print("[ExpressDeliveryService]", player.Name, msg)
	if onUpdatedCallback then
		onUpdatedCallback(player, msg)
	end
end

local function spawnDropOffBeacon(player: Player, order: ExpressOrder): ()
	clearDropVisual(order)

	local m = Instance.new("Model")
	m.Name = "ExpressDeliveryDrop_" .. tostring(player.UserId)
	local pos = order.DropPos

	-- Glowing Neon Ground Ring + Tall Golden Delivery Sky-Beam!
	local ring = Instance.new("Part")
	ring.Name = "DropRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 14.0, 14.0)
	ring.CFrame = CFrame.new(pos.X, 1.5, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(48, 224, 118)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.25
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = m

	local beam = Instance.new("Part")
	beam.Name = "DeliveryBeacon"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(95, 3.2, 3.2)
	beam.CFrame = CFrame.new(pos.X, 48, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	beam.Color = Color3.fromRGB(255, 212, 54)
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.45
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Parent = m

	-- Authentic Roblox R15 Neighborhood Citizen Customer NPC!
	local rig = MafiaVisualBuilder.BuildCustomerRig("ExpressCustomer", math.random(1, 8), 1.02, CFrame.new(pos.X, 4.1, pos.Z))
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	rig.Model.Parent = m
	local body = rig.Root
	local head = rig.Head

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(224, 40)
	bb.StudsOffset = Vector3.new(0, 3.1, 0)
	bb.MaxDistance = 300
	bb.Parent = head
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = string.format("%s'S EXPRESS ORDER  [E]", string.upper(order.CustomerName))
	lbl.TextSize = 11
	lbl.TextColor3 = Color3.fromRGB(238, 206, 114)
	lbl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 5)
	c.Parent = lbl

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DeliverExpressMealPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.ActionText = "Deliver " .. order.DishName
	prompt.ObjectText = order.CustomerName .. " (" .. order.DropName .. ")"
	prompt.Parent = body

	order.PromptConn = prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer == player then
			completeDelivery(player)
		end
	end)

	m.PrimaryPart = body
	m.Parent = dropFolder or Workspace
	order.DropModel = m
end

function ExpressDeliveryService.AcceptDelivery(player: Player): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Restaurant Plaza first!"
	end

	local order = ordersByPlayer[player]
	if not order or order.Status == "Cooldown" then
		return false, "Next Express Delivery call arriving in a few seconds!"
	end
	if order.Status == "Active" then
		return false, string.format("Deliver %s to %s (%ds left)!", order.DishName, order.DropName, math.max(0, math.ceil(order.ExpiresAt - os.clock())))
	end

	order.Status = "Active"
	order.ExpiresAt = os.clock() + order.Duration
	spawnDropOffBeacon(player, order)

	if onUpdatedCallback then
		onUpdatedCallback(player, nil)
	end

	return true, string.format("🛵 Rush %s to %s (%ds)! Follow the Golden Arrow & Beam!", order.DishName, order.DropName, order.Duration)
end

function ExpressDeliveryService.GetSnapshot(player: Player): { [string]: any }?
	local order = ordersByPlayer[player]
	if not order then
		return nil
	end
	local now = os.clock()
	return {
		CustomerName = order.CustomerName,
		DishName = order.DishName,
		DropName = order.DropName,
		DropX = order.DropPos.X,
		DropZ = order.DropPos.Z,
		BaseGold = order.BaseGold,
		BaseRep = order.BaseRep,
		Duration = order.Duration,
		Remaining = if order.Status ~= "Available" then math.max(0, math.ceil(order.ExpiresAt - now)) else order.Duration,
		Status = order.Status,
		Combo = comboByPlayer[player] or 0,
	}
end

function ExpressDeliveryService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local existing = Workspace:FindFirstChild("ExpressDeliveryDrops")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		dropFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "ExpressDeliveryDrops"
		f.Parent = Workspace
		dropFolder = f
	end

	unsubBase = BaseService.OnBaseAssigned(function(player)
		if not ordersByPlayer[player] then
			createNewOffer(player)
		end
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		clearDropVisual(ordersByPlayer[player])
		ordersByPlayer[player] = nil
		comboByPlayer[player] = nil
	end)

	for _, p in ipairs(Players:GetPlayers()) do
		if BaseService.GetPlayerBaseSlot(p) then
			createNewOffer(p)
		end
	end

	tickThread = task.spawn(function()
		while isRunning do
			task.wait(1.0)
			if not isRunning then
				break
			end
			local now = os.clock()
			for _, p in ipairs(Players:GetPlayers()) do
				local ord = ordersByPlayer[p]
				if ord then
					if ord.Status == "Active" and now >= ord.ExpiresAt then
						clearDropVisual(ord)
						comboByPlayer[p] = 0
						ord.Status = "Cooldown"
						ord.ExpiresAt = now + 7
						if onUpdatedCallback then
							onUpdatedCallback(p, "⏰ Express Delivery timed out! Combo reset — new order incoming!")
						end
					elseif ord.Status == "Cooldown" and now >= ord.ExpiresAt then
						createNewOffer(p)
					elseif ord.Status == "Active" and onUpdatedCallback then
						onUpdatedCallback(p, nil)
					end
				end
			end
		end
	end)

	print("[Food Empire] ExpressDeliveryService started (Live Central District Motorbike Rush Missions active)!")
end

function ExpressDeliveryService.Stop(): ()
	isRunning = false
	if tickThread then
		task.cancel(tickThread)
		tickThread = nil
	end
	if unsubBase then
		unsubBase()
		unsubBase = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for _, ord in pairs(ordersByPlayer) do
		clearDropVisual(ord)
	end
	table.clear(ordersByPlayer)
	table.clear(comboByPlayer)
end

return ExpressDeliveryService
