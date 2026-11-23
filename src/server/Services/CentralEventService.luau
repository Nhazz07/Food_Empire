--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local WarehouseService = require("./WarehouseService")
local PlayerDataService = require("./PlayerDataService")

export type RushEventSpec = {
	Id: string,
	Title: string,
	CoinsMult: number,
	RepMult: number,
}

local CentralEventService = {}

local EVENT_DURATION = 75
local MARKET_BUNDLE_COST = 40

local EVENTS: { RushEventSpec } = {
	{ Id = "GoldenFeast", Title = "GOLDEN FEAST: 2x Coins on All Food!", CoinsMult = 2.0, RepMult = 1.0 },
	{ Id = "EmperorGala", Title = "EMPEROR GALA: 2x Reputation on All Food!", CoinsMult = 1.0, RepMult = 2.0 },
	{ Id = "MarketBoom",  Title = "MARKET BOOM: 1.5x Coins & 1.5x Rep!", CoinsMult = 1.5, RepMult = 1.5 },
}

local currentEvent: RushEventSpec = EVENTS[1]
local isRunning = false
local eventThread: thread? = nil
local leaderboardThread: thread? = nil
local traderConn: RBXScriptConnection? = nil
local boardEventLabel: TextLabel? = nil
local boardRankLabels: { TextLabel } = {}

local function spawnCentralPlazaBoards(): ()
	local map = Workspace:FindFirstChild("FoodEmpireMap")
	local central = if map then map:FindFirstChild("CentralDistrict") else nil
	local plaza = if central then central:FindFirstChild("CentralPlaza") else nil
	if not plaza then
		return
	end

	local oldBoards = plaza:FindFirstChild("PlazaInfoBoards")
	if oldBoards then oldBoards:Destroy() end
	table.clear(boardRankLabels)

	local boards = Instance.new("Folder")
	boards.Name = "PlazaInfoBoards"
	boards.Parent = plaza

	local function buildBoardFrame(name: string, pos: Vector3, rotDeg: number, titleText: string, accent: Color3): Frame
		local postL = Instance.new("Part")
		postL.Size = Vector3.new(1.0, 12, 1.0)
		postL.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotDeg), 0) * CFrame.new(-7.5, 6, 0)
		postL.Color = Color3.fromRGB(132, 86, 54)
		postL.Material = Enum.Material.WoodPlanks
		postL.Anchored = true
		postL.CanCollide = true
		postL.Parent = boards

		local postR = postL:Clone()
		postR.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotDeg), 0) * CFrame.new(7.5, 6, 0)
		postR.Parent = boards

		local panel = Instance.new("Part")
		panel.Name = name
		panel.Size = Vector3.new(16, 10, 1.0)
		panel.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotDeg), 0) * CFrame.new(0, 8.2, 0)
		panel.Color = Color3.fromRGB(28, 34, 50)
		panel.Material = Enum.Material.SmoothPlastic
		panel.Anchored = true
		panel.CanCollide = true
		panel.Parent = boards

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = panel

		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(22, 28, 44)
		bg.BorderSizePixel = 0
		bg.Parent = gui

		local hdr = Instance.new("TextLabel")
		hdr.Size = UDim2.new(1, 0, 0, 56)
		hdr.BackgroundColor3 = accent
		hdr.Font = Enum.Font.FredokaOne
		hdr.Text = titleText
		hdr.TextScaled = true
		hdr.TextColor3 = Color3.new(1, 1, 1)
		hdr.Parent = bg

		return bg
	end

	-- Left Board: Active Central Plaza Rush Event
	local evBg = buildBoardFrame("EventBoard", Vector3.new(-26, 1.35, -42), 18, "CENTRAL EVENT", Color3.fromRGB(196, 48, 66))
	local evLbl = Instance.new("TextLabel")
	evLbl.Position = UDim2.new(0.05, 0, 0.26, 0)
	evLbl.Size = UDim2.new(0.9, 0, 0.68, 0)
	evLbl.BackgroundTransparency = 1
	evLbl.Font = Enum.Font.FredokaOne
	evLbl.TextWrapped = true
	evLbl.Text = currentEvent.Title
	evLbl.TextSize = 34
	evLbl.TextColor3 = Color3.fromRGB(255, 226, 106)
	evLbl.Parent = evBg
	boardEventLabel = evLbl

	-- Right Board: Live Top 4 Food Emperor Leaderboard
	local lbBg = buildBoardFrame("EmperorLeaderboard", Vector3.new(26, 1.35, -42), -18, "FOOD EMPERORS", Color3.fromRGB(218, 152, 28))
	for i = 1, 4 do
		local row = Instance.new("TextLabel")
		row.Position = UDim2.new(0.06, 0, 0.22 + (i - 1) * 0.19, 0)
		row.Size = UDim2.new(0.88, 0, 0.17, 0)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextSize = 26
		row.TextColor3 = if i == 1 then Color3.fromRGB(255, 224, 96) else Color3.new(1, 1, 1)
		row.Text = string.format("#%d  ---", i)
		row.Parent = lbBg
		table.insert(boardRankLabels, row)
	end
end

local function refreshPlazaLeaderboard(): ()
	if #boardRankLabels == 0 then
		return
	end
	local entries: { { Name: string, Rep: number, Level: number } } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local prof = PlayerDataService.GetProfile(p)
		table.insert(entries, { Name = p.DisplayName, Rep = prof.Reputation, Level = prof.Level })
	end
	table.sort(entries, function(a, b)
		return a.Rep > b.Rep
	end)
	for i, lbl in ipairs(boardRankLabels) do
		local e = entries[i]
		if e then
			lbl.Text = string.format("#%d  %s — %d Rep (Lv.%d)", i, e.Name, e.Rep, e.Level)
		else
			lbl.Text = string.format("#%d  ---", i)
		end
	end
end

function CentralEventService.GetCurrentEvent(): RushEventSpec
	return currentEvent
end

local function spawnCentralMarketTrader(): ()
	local map = Workspace:FindFirstChild("FoodEmpireMap")
	local central = if map then map:FindFirstChild("CentralDistrict") else nil
	local plaza = if central then central:FindFirstChild("CentralPlaza") else nil
	if not plaza then
		return
	end

	local old = plaza:FindFirstChild("CentralMarketTrader")
	if old then old:Destroy() end

	-- Positioned right in front of the Grand FOOD EMPIRE Royal Hall overlooking the Fountain
	local pos = Vector3.new(0, 4.2, -42)
	local rig = MafiaVisualBuilder.BuildMarketBrokerRig("CentralMarketTrader", CFrame.new(pos) * CFrame.Angles(0, math.pi, 0))
	local npc = rig.Model
	local body = rig.Root
	local head = rig.Head

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(186, 34)
	bb.StudsOffset = Vector3.new(0, 3.0, 0)
	bb.MaxDistance = 120
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = "MARKET SYNDICATE BROKER"
	lbl.TextSize = 10
	lbl.TextColor3 = Color3.fromRGB(214, 186, 118)
	lbl.Parent = bb

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 5)
	c.Parent = lbl
	local bst = Instance.new("UIStroke")
	bst.Color = Color3.fromRGB(68, 72, 82)
	bst.Thickness = 1.2
	bst.Parent = lbl

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuySupplyPackPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.ActionText = string.format("Buy Mixed Supply Pack (%d Coins)", MARKET_BUNDLE_COST)
	prompt.ObjectText = "Central District Market"
	prompt.Parent = body

	traderConn = prompt.Triggered:Connect(function(player)
		if not PlayerDataService.SpendCoins(player, MARKET_BUNDLE_COST) then
			return
		end
		for _, cat in ipairs(WarehouseConfig.Categories) do
			local spec = WarehouseConfig.Specs[cat]
			for _, ing in ipairs(spec.Ingredients) do
				if ing ~= "golden_tuna" and ing ~= "king_crab" then
					WarehouseService.AddIngredient(player, ing, 2)
				end
			end
		end
		print(string.format("[CentralEventService] %s bought a Mixed Supply Pack (+2 of all 12 ingredients)!", player.Name))
	end)

	npc.PrimaryPart = body
	npc.Parent = plaza
end

local function publishEvent(ev: RushEventSpec): ()
	currentEvent = ev
	ReplicatedStorage:SetAttribute("ActiveEventTitle", ev.Title)
	ReplicatedStorage:SetAttribute("ActiveEventCoinsMult", ev.CoinsMult)
	ReplicatedStorage:SetAttribute("ActiveEventRepMult", ev.RepMult)
	if boardEventLabel then
		boardEventLabel.Text = ev.Title
	end
	print("[CentralEventService] Active Central District Event:", ev.Title)
end

function CentralEventService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	spawnCentralMarketTrader()
	spawnCentralPlazaBoards()
	local idx = 1
	publishEvent(EVENTS[idx])
	refreshPlazaLeaderboard()

	leaderboardThread = task.spawn(function()
		while isRunning do
			task.wait(4)
			if not isRunning then
				break
			end
			refreshPlazaLeaderboard()
		end
	end)

	eventThread = task.spawn(function()
		while isRunning do
			task.wait(EVENT_DURATION)
			if not isRunning then
				break
			end
			idx = (idx % #EVENTS) + 1
			publishEvent(EVENTS[idx])
		end
	end)

	print("[Food Empire] CentralEventService started (Central Market Trader & Plaza Rush Events active)!")
end

function CentralEventService.Stop(): ()
	isRunning = false
	if eventThread then
		task.cancel(eventThread)
		eventThread = nil
	end
	if leaderboardThread then
		task.cancel(leaderboardThread)
		leaderboardThread = nil
	end
	if traderConn then
		traderConn:Disconnect()
		traderConn = nil
	end
end

return CentralEventService
