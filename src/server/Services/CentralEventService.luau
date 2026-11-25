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
local MARKET_BUNDLE_COST = 200

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
local monumentPromptConn: RBXScriptConnection? = nil
local tributeCooldownByPlayer: { [Player]: number } = {}
local lastAutoTributeAt = 0
local boardEventLabel: TextLabel? = nil
local emperorHeaderLabel: TextLabel? = nil
local boardRankLabels: { TextLabel } = {}

local function getRankTitleForRep(rep: number): string
	if rep >= 2000 then return "GODFATHER"
	elseif rep >= 900 then return "UNDERBOSS"
	elseif rep >= 400 then return "CAPOREGIME"
	elseif rep >= 150 then return "SOLDIER"
	elseif rep >= 50 then return "ASSOCIATE"
	else return "RUNNER" end
end

function CentralEventService.TryClaimEmperorTribute(player: Player): (boolean, string)
	local now = os.clock()
	local cdUntil = tributeCooldownByPlayer[player] or 0
	if cdUntil > now then
		local rem = math.max(1, math.ceil(cdUntil - now))
		return false, string.format("Emperor Monument Tribute recharging (%ds)!", rem)
	end
	tributeCooldownByPlayer[player] = now + 25

	local topPlayer: Player? = nil
	local topRep = -1
	for _, p in ipairs(Players:GetPlayers()) do
		local r = PlayerDataService.GetProfile(p).Reputation
		if r > topRep then
			topRep = r
			topPlayer = p
		end
	end

	local isEmperor = (topPlayer == player)
	local gold = if isEmperor then 150 else 65
	local rep = if isEmperor then 25 else 15
	PlayerDataService.AddRewards(player, gold, 40, rep)

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	local msg = if isEmperor
		then string.format("FOOD EMPEROR TRIBUTE CLAIMED! +%d Gold & +%d Rep from the Central Plaza Monument!", gold, rep)
		else string.format("SYNDICATE MONUMENT STIPEND CLAIMED! +%d Gold & +%d Rep (Surpass %d Rep to reign as #1 Food Emperor)!", gold, rep, math.max(0, topRep))
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg)
	end
	return true, msg
end

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

	-- Right Monument: 3D Obsidian & Brass FOOD EMPEROR SYNDICATE MONUMENT & Live Leaderboard
	local oldMon = plaza:FindFirstChild("FoodEmperorMonument")
	if oldMon then oldMon:Destroy() end
	local monument = Instance.new("Model")
	monument.Name = "FoodEmperorMonument"
	monument.Parent = plaza

	local monPos = Vector3.new(26, 1.35, -40)
	local monCF = CFrame.new(monPos) * CFrame.Angles(0, math.rad(-18), 0)
	local function mPart(name: string, sz: Vector3, rel: CFrame, col: Color3, mat: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = monCF * rel
		p.Color = col
		p.Material = mat
		p.Anchored = true
		p.CanCollide = true
		p.Parent = monument
		return p
	end

	local obsidian = Color3.fromRGB(18, 20, 26)
	local brass = Color3.fromRGB(184, 146, 78)
	local darkMarble = Color3.fromRGB(26, 28, 36)

	local pedestal = mPart("MonumentPedestal", Vector3.new(19.0, 2.2, 6.2), CFrame.new(0, 1.1, 0), darkMarble, Enum.Material.Marble)
	mPart("BrassPlinth", Vector3.new(17.6, 0.5, 4.8), CFrame.new(0, 2.45, 0), brass, Enum.Material.Metal)
	mPart("PillarLeft", Vector3.new(1.5, 12.2, 1.6), CFrame.new(-8.2, 8.5, 0), obsidian, Enum.Material.Marble)
	mPart("PillarRight", Vector3.new(1.5, 12.2, 1.6), CFrame.new(8.2, 8.5, 0), obsidian, Enum.Material.Marble)
	mPart("CorniceTop", Vector3.new(19.4, 1.1, 2.4), CFrame.new(0, 14.9, 0), brass, Enum.Material.Metal)
	mPart("EmperorCrestBase", Vector3.new(6.8, 1.4, 1.4), CFrame.new(0, 16.0, 0), obsidian, Enum.Material.Metal)
	mPart("EmperorCrownSpireC", Vector3.new(1.1, 2.2, 0.8), CFrame.new(0, 17.5, 0), brass, Enum.Material.Metal)
	mPart("EmperorCrownSpireL", Vector3.new(0.9, 1.6, 0.8), CFrame.new(-1.8, 17.2, 0) * CFrame.Angles(0, 0, math.rad(14)), brass, Enum.Material.Metal)
	mPart("EmperorCrownSpireR", Vector3.new(0.9, 1.6, 0.8), CFrame.new(1.8, 17.2, 0) * CFrame.Angles(0, 0, math.rad(-14)), brass, Enum.Material.Metal)

	local lbBg = buildBoardFrame("EmperorLeaderboard", monPos, -18, "FOOD EMPEROR MONUMENT", Color3.fromRGB(168, 132, 64))
	local crownHdr = Instance.new("TextLabel")
	crownHdr.Position = UDim2.new(0.05, 0, 0.19, 0)
	crownHdr.Size = UDim2.new(0.90, 0, 0.12, 0)
	crownHdr.BackgroundTransparency = 1
	crownHdr.Font = Enum.Font.GothamBlack
	crownHdr.TextXAlignment = Enum.TextXAlignment.Center
	crownHdr.TextSize = 20
	crownHdr.TextColor3 = Color3.fromRGB(244, 212, 124)
	crownHdr.Text = "REIGNING EMPEROR: ---"
	crownHdr.Parent = lbBg
	emperorHeaderLabel = crownHdr

	for i = 1, 4 do
		local row = Instance.new("TextLabel")
		row.Position = UDim2.new(0.05, 0, 0.32 + (i - 1) * 0.16, 0)
		row.Size = UDim2.new(0.90, 0, 0.15, 0)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextSize = 22
		row.TextColor3 = if i == 1 then Color3.fromRGB(255, 224, 96) else Color3.fromRGB(224, 222, 216)
		row.Text = string.format("#%d  ---", i)
		row.Parent = lbBg
		table.insert(boardRankLabels, row)
	end

	local tribPrompt = Instance.new("ProximityPrompt")
	tribPrompt.Name = "ClaimEmperorTributePrompt"
	tribPrompt.KeyboardKeyCode = Enum.KeyCode.E
	tribPrompt.HoldDuration = 0.25
	tribPrompt.MaxActivationDistance = 18
	tribPrompt.RequiresLineOfSight = false
	tribPrompt.ActionText = "Claim Food Emperor Tribute (+150G & +25 Rep)"
	tribPrompt.ObjectText = "Food Emperor Syndicate Monument"
	tribPrompt.Parent = pedestal

	if monumentPromptConn then
		monumentPromptConn:Disconnect()
	end
	monumentPromptConn = tribPrompt.Triggered:Connect(function(player: Player)
		CentralEventService.TryClaimEmperorTribute(player)
	end)
	monument.PrimaryPart = pedestal
end

local function refreshPlazaLeaderboard(): ()
	if #boardRankLabels == 0 then
		return
	end
	local entries: { { Player: Player, Name: string, Rep: number, Level: number, Coins: number } } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local prof = PlayerDataService.GetProfile(p)
		table.insert(entries, {
			Player = p,
			Name = p.DisplayName,
			Rep = prof.Reputation,
			Level = prof.Level,
			Coins = prof.Coins,
		})
	end
	table.sort(entries, function(a, b)
		if a.Rep ~= b.Rep then
			return a.Rep > b.Rep
		end
		return a.Coins > b.Coins
	end)

	local top = entries[1]
	if emperorHeaderLabel then
		if top then
			emperorHeaderLabel.Text = string.format("REIGNING EMPEROR: %s [%s]", string.upper(top.Name), getRankTitleForRep(top.Rep))
		else
			emperorHeaderLabel.Text = "REIGNING EMPEROR: ---"
		end
	end

	for i, lbl in ipairs(boardRankLabels) do
		local e = entries[i]
		if e then
			lbl.Text = string.format("#%d  %s [%s] — %d Rep | %dG", i, e.Name, getRankTitleForRep(e.Rep), e.Rep, e.Coins)
		else
			lbl.Text = string.format("#%d  ---", i)
		end
	end

	local now = os.clock()
	if top and (now - lastAutoTributeAt) >= 45 then
		lastAutoTributeAt = now
		PlayerDataService.AddRewards(top.Player, 75, 20, 12)
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
