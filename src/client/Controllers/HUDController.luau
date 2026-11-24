--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)
local TurfConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("TurfConfig")
)

export type OpenMenuCallback = (tabName: "Kitchen" | "Warehouses" | "Upgrades" | "Shop" | "BlackMarket") -> ()
export type QuickServeCallback = () -> ()
export type ReturnHomeCallback = () -> ()
export type ToggleScooterCallback = () -> ()
export type AcceptExpressCallback = () -> ()

local HUDController = {}

local FONT_TITLE = Enum.Font.GothamBlack
local FONT_BODY = Enum.Font.GothamBold

local SECTOR_TAGS: { [string]: string } = {
	FishingPort = "PORT",
	VegetableFarm = "FARM",
	Ranch = "RNCH",
	FruitOrchard = "ORCH",
}

local C_OBS = Color3.fromRGB(15, 17, 21)
local C_CHAR = Color3.fromRGB(22, 24, 30)
local C_BORDER = Color3.fromRGB(48, 52, 62)
local C_BONE = Color3.fromRGB(234, 231, 224)
local C_ASH = Color3.fromRGB(156, 160, 170)
local C_OXBLOOD = Color3.fromRGB(134, 28, 36)
local C_BRASS = Color3.fromRGB(168, 138, 76)
local C_ROBUX = Color3.fromRGB(36, 94, 62)

local screenGui: ScreenGui? = nil
local coinsLabel: TextLabel? = nil
local repLabel: TextLabel? = nil
local levelLabel: TextLabel? = nil
local baseBadge: TextLabel? = nil
local basePillFrame: Frame? = nil
local emperorBanner: TextLabel? = nil
local objectiveLabel: TextLabel? = nil
local vipOrderLabel: TextLabel? = nil
local expressOrderLabel: TextLabel? = nil
local expressAcceptBtn: TextButton? = nil
local sellBadgeBtn: TextButton? = nil
local sellTextLabel: TextLabel? = nil
local bikeTextLabel: TextLabel? = nil
local toastLabel: TextLabel? = nil
local receiptTicket: Frame? = nil
local receiptHeaderLbl: TextLabel? = nil
local receiptBodyLbl: TextLabel? = nil
local turfSummaryLabel: TextLabel? = nil
local turfAlertLabel: TextLabel? = nil
local activeBlockBanner: Frame? = nil
local activeBlockTitle: TextLabel? = nil
local activeBlockOwnerPill: TextLabel? = nil
local activeBlockFill: Frame? = nil
local activeBlockSub: TextLabel? = nil
local latestTurfState: { [string]: any }? = nil
local turfProximityConn: RBXScriptConnection? = nil
local sectorDots: { [string]: Frame } = {}
local sectorStatusLabels: { [string]: TextLabel } = {}
local toastToken = 0
local lastReceiptOrderNo = 0
local receiptHideToken = 0

local function makeCorner(parent: Instance, radius: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeBorderStroke(parent: Instance, color: Color3, thickness: number): ()
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
end

local function makeTextOutline(parent: GuiObject, thickness: number?): ()
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = Color3.fromRGB(16, 20, 30)
	s.Thickness = thickness or 1.6
	s.Transparency = 0.12
	s.Parent = parent
end

local function addGlossGradient(parent: Instance, topColor: Color3, bottomColor: Color3): ()
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(topColor, bottomColor)
	g.Parent = parent
end

local function createStatPill(
	parent: Instance,
	name: string,
	layoutOrder: number,
	accentColor: Color3,
	tagText: string,
	initialText: string
): (Frame, TextLabel)
	local pill = Instance.new("Frame")
	pill.Name = name
	pill.LayoutOrder = layoutOrder
	pill.Size = UDim2.fromOffset(152, 34)
	pill.BackgroundColor3 = C_OBS
	pill.BackgroundTransparency = 0.05
	pill.Parent = parent
	makeCorner(pill, 5)
	makeBorderStroke(pill, C_BORDER, 1)

	local strip = Instance.new("Frame")
	strip.Name = "AccentStrip"
	strip.Size = UDim2.new(0, 3, 1, -8)
	strip.Position = UDim2.new(0, 0, 0, 4)
	strip.BackgroundColor3 = accentColor
	strip.BorderSizePixel = 0
	strip.Parent = pill

	local badge = Instance.new("TextLabel")
	badge.Name = "TagBadge"
	badge.Position = UDim2.new(0, 8, 0.5, -10)
	badge.Size = UDim2.fromOffset(32, 20)
	badge.BackgroundColor3 = C_CHAR
	badge.Font = FONT_TITLE
	badge.Text = tagText
	badge.TextSize = 9
	badge.TextColor3 = accentColor
	badge.Parent = pill
	makeCorner(badge, 3)

	local val = Instance.new("TextLabel")
	val.Name = "ValueText"
	val.Position = UDim2.new(0, 46, 0, 0)
	val.Size = UDim2.new(1, -52, 1, 0)
	val.BackgroundTransparency = 1
	val.Font = FONT_TITLE
	val.Text = initialText
	val.TextSize = 12
	val.TextXAlignment = Enum.TextXAlignment.Left
	val.TextColor3 = C_BONE
	val.Parent = pill

	return pill, val
end

local function createDockButton(
	parent: Instance,
	name: string,
	labelText: string,
	keyHint: string?,
	bg: Color3,
	accent: Color3,
	layoutOrder: number,
	isRobuxStyle: boolean,
	onClick: () -> ()
): (TextButton, TextLabel)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.LayoutOrder = layoutOrder
	btn.Size = UDim2.fromOffset(106, 36)
	btn.BackgroundColor3 = bg
	btn.BackgroundTransparency = 0.04
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = parent
	makeCorner(btn, 5)
	makeBorderStroke(btn, if isRobuxStyle then C_BRASS else C_BORDER, 1)

	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(1, -14, 0, 2)
	accentBar.Position = UDim2.new(0, 7, 1, -2)
	accentBar.BackgroundColor3 = accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = btn

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Label"
	lbl.Position = UDim2.new(0, 8, 0, 0)
	lbl.Size = UDim2.new(1, if keyHint then -30 else -16, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = FONT_TITLE
	lbl.Text = string.upper(labelText)
	lbl.TextSize = 11
	lbl.TextXAlignment = if keyHint then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	lbl.TextColor3 = C_BONE
	lbl.Parent = btn

	if keyHint and keyHint ~= "" then
		local keyCap = Instance.new("TextLabel")
		keyCap.Name = "KeyCap"
		keyCap.AnchorPoint = Vector2.new(1, 0.5)
		keyCap.Position = UDim2.new(1, -6, 0.5, 0)
		keyCap.Size = UDim2.fromOffset(18, 18)
		keyCap.BackgroundColor3 = Color3.fromRGB(11, 12, 16)
		keyCap.Font = FONT_TITLE
		keyCap.Text = keyHint
		keyCap.TextSize = 10
		keyCap.TextColor3 = C_ASH
		keyCap.Parent = btn
		makeCorner(keyCap, 3)
		makeBorderStroke(keyCap, C_BORDER, 1)
	end

	local baseBg = bg
	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = baseBg:Lerp(Color3.new(1, 1, 1), 0.08)
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = baseBg
	end)
	btn.MouseButton1Click:Connect(onClick)
	return btn, lbl
end

function HUDController.Init(
	onOpenMenu: OpenMenuCallback,
	onQuickServe: QuickServeCallback,
	onReturnHome: ReturnHomeCallback?,
	onToggleScooter: ToggleScooterCallback?,
	onAcceptExpress: AcceptExpressCallback?,
	onSquadAttack: (() -> ())?,
	onSquadRecall: (() -> ())?,
	onThrowFlashbang: (() -> ())?,
	onDeployC4: (() -> ())?,
	onTriggerShadowDash: (() -> ())?
): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("FoodEmpireHUD")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "FoodEmpireHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	screenGui = gui

	-- Top Stats Bar (Gold Coins, Reputation Crown, Star Level, Castle Base)
	local topBar = Instance.new("Frame")
	topBar.Name = "TopStatsBar"
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.new(0.5, 0, 0, 8)
	topBar.Size = UDim2.fromOffset(650, 44)
	topBar.BackgroundTransparency = 1
	topBar.Parent = gui

	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topLayout.Padding = UDim.new(0, 8)
	topLayout.Parent = topBar

	local _, cLbl = createStatPill(topBar, "Coins", 1, C_BRASS, "GOLD", "90 Gold")
	coinsLabel = cLbl

	local _, rLbl = createStatPill(topBar, "Reputation", 2, C_OXBLOOD, "REP", "0 Rep")
	repLabel = rLbl

	local _, lLbl = createStatPill(topBar, "Level", 3, Color3.fromRGB(118, 134, 158), "LVL", "Lv.1 • 0 XP")
	levelLabel = lLbl

	local bFrame, bLbl = createStatPill(topBar, "BaseSlot", 4, Color3.fromRGB(142, 146, 156), "BASE", "Base: --")
	basePillFrame = bFrame
	baseBadge = bLbl

	-- Food Emperor Title Banner
	local emp = Instance.new("TextLabel")
	emp.Name = "FoodEmperorBanner"
	emp.AnchorPoint = Vector2.new(0.5, 0)
	emp.Position = UDim2.new(0.5, 0, 0, 48)
	emp.Size = UDim2.fromOffset(330, 22)
	emp.BackgroundColor3 = C_OBS
	emp.BackgroundTransparency = 0.08
	emp.Font = FONT_BODY
	emp.Text = "FOOD EMPEROR: --"
	emp.TextSize = 11
	emp.TextColor3 = C_BRASS
	emp.Parent = gui
	makeCorner(emp, 4)
	makeBorderStroke(emp, C_BORDER, 1)
	emperorBanner = emp

	-- Active Central District Event Pill
	local evBanner = Instance.new("TextLabel")
	evBanner.Name = "ActiveEventBanner"
	evBanner.AnchorPoint = Vector2.new(0.5, 0)
	evBanner.Position = UDim2.new(0.5, 0, 0, 74)
	evBanner.Size = UDim2.fromOffset(360, 22)
	evBanner.BackgroundColor3 = Color3.fromRGB(36, 18, 22)
	evBanner.BackgroundTransparency = 0.08
	evBanner.Font = FONT_BODY
	evBanner.TextSize = 11
	evBanner.TextColor3 = C_BONE
	evBanner.Parent = gui
	makeCorner(evBanner, 4)
	makeBorderStroke(evBanner, C_OXBLOOD, 1)

	local function refreshEventText()
		local title = ReplicatedStorage:GetAttribute("ActiveEventTitle")
		evBanner.Text = string.upper(if typeof(title) == "string" then title else "CENTRAL DISTRICT MARKET OPEN")
	end
	refreshEventText()
	ReplicatedStorage:GetAttributeChangedSignal("ActiveEventTitle"):Connect(refreshEventText)

	-- Territory Shipments Strip (Top-Left)
	local terrPanel = Instance.new("Frame")
	terrPanel.Name = "TerritoryStrip"
	terrPanel.Position = UDim2.new(0, 14, 0, 62)
	terrPanel.Size = UDim2.fromOffset(214, 130)
	terrPanel.BackgroundColor3 = C_OBS
	terrPanel.BackgroundTransparency = 0.08
	terrPanel.Parent = gui
	makeCorner(terrPanel, 6)
	makeBorderStroke(terrPanel, C_BORDER, 1)

	local terrHeader = Instance.new("TextLabel")
	terrHeader.Position = UDim2.new(0, 10, 0, 4)
	terrHeader.Size = UDim2.new(1, -20, 0, 20)
	terrHeader.BackgroundTransparency = 1
	terrHeader.Font = FONT_TITLE
	terrHeader.Text = "CORNER SHIPMENTS"
	terrHeader.TextSize = 11
	terrHeader.TextXAlignment = Enum.TextXAlignment.Left
	terrHeader.TextColor3 = C_BRASS
	terrHeader.Parent = terrPanel

	local listHolder = Instance.new("Frame")
	listHolder.Position = UDim2.new(0, 10, 0, 26)
	listHolder.Size = UDim2.new(1, -20, 1, -30)
	listHolder.BackgroundTransparency = 1
	listHolder.Parent = terrPanel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 3)
	listLayout.Parent = listHolder

	local sectorOrder = { "FishingPort", "VegetableFarm", "FruitOrchard", "Ranch" }
	for _, sectorId in ipairs(sectorOrder) do
		local entry = SectorConfig.Sectors[sectorId]
		if entry then
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 22)
			row.BackgroundTransparency = 1
			row.Parent = listHolder

			local dot = Instance.new("Frame")
			dot.Size = UDim2.fromOffset(8, 8)
			dot.Position = UDim2.new(0, 2, 0.5, -4)
			dot.BackgroundColor3 = SectorConfig.FactionColors.Neutral
			dot.Parent = row
			makeCorner(dot, 4)
			sectorDots[sectorId] = dot

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 16, 0, 0)
			nameLbl.Size = UDim2.new(1, -16, 1, 0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = FONT_BODY
			nameLbl.Text = entry.DisplayName
			nameLbl.TextSize = 11
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextColor3 = C_BONE
			nameLbl.Parent = row
			sectorStatusLabels[sectorId] = nameLbl
		end
	end

	-- Next Objective Panel
	local goalPanel = Instance.new("Frame")
	goalPanel.Name = "ObjectivePanel"
	goalPanel.Position = UDim2.new(0, 14, 0, 198)
	goalPanel.Size = UDim2.fromOffset(214, 72)
	goalPanel.BackgroundColor3 = C_OBS
	goalPanel.BackgroundTransparency = 0.08
	goalPanel.Parent = gui
	makeCorner(goalPanel, 6)
	makeBorderStroke(goalPanel, C_BORDER, 1)

	local goalHeader = Instance.new("TextLabel")
	goalHeader.Position = UDim2.new(0, 10, 0, 4)
	goalHeader.Size = UDim2.new(1, -20, 0, 18)
	goalHeader.BackgroundTransparency = 1
	goalHeader.Font = FONT_TITLE
	goalHeader.Text = "OBJECTIVE"
	goalHeader.TextSize = 10
	goalHeader.TextXAlignment = Enum.TextXAlignment.Left
	goalHeader.TextColor3 = C_BRASS
	goalHeader.Parent = goalPanel

	local goalTxt = Instance.new("TextLabel")
	goalTxt.Position = UDim2.new(0, 10, 0, 22)
	goalTxt.Size = UDim2.new(1, -20, 1, -26)
	goalTxt.BackgroundTransparency = 1
	goalTxt.Font = Enum.Font.Gotham
	goalTxt.TextWrapped = true
	goalTxt.TextXAlignment = Enum.TextXAlignment.Left
	goalTxt.TextYAlignment = Enum.TextYAlignment.Top
	goalTxt.TextSize = 11
	goalTxt.TextColor3 = C_BONE
	goalTxt.Text = "Capture Fishing Port (SE) to supply your starter Warehouse."
	goalTxt.Parent = goalPanel
	objectiveLabel = goalTxt

	-- Timed VIP Food Critic Order Card
	local vipPanel = Instance.new("Frame")
	vipPanel.Name = "VIPOrderPanel"
	vipPanel.Position = UDim2.new(0, 14, 0, 276)
	vipPanel.Size = UDim2.fromOffset(214, 68)
	vipPanel.BackgroundColor3 = C_OBS
	vipPanel.BackgroundTransparency = 0.08
	vipPanel.Parent = gui
	makeCorner(vipPanel, 6)
	makeBorderStroke(vipPanel, C_BORDER, 1)

	local vipHeader = Instance.new("TextLabel")
	vipHeader.Position = UDim2.new(0, 10, 0, 4)
	vipHeader.Size = UDim2.new(1, -20, 0, 18)
	vipHeader.BackgroundTransparency = 1
	vipHeader.Font = FONT_TITLE
	vipHeader.Text = "VIP CRITIC ORDER"
	vipHeader.TextSize = 10
	vipHeader.TextXAlignment = Enum.TextXAlignment.Left
	vipHeader.TextColor3 = C_BRASS
	vipHeader.Parent = vipPanel

	local vipTxt = Instance.new("TextLabel")
	vipTxt.Position = UDim2.new(0, 10, 0, 22)
	vipTxt.Size = UDim2.new(1, -20, 1, -26)
	vipTxt.BackgroundTransparency = 1
	vipTxt.Font = Enum.Font.Gotham
	vipTxt.TextWrapped = true
	vipTxt.TextXAlignment = Enum.TextXAlignment.Left
	vipTxt.TextYAlignment = Enum.TextYAlignment.Top
	vipTxt.TextSize = 11
	vipTxt.TextColor3 = C_BONE
	vipTxt.Text = "Waiting for VIP Critic..."
	vipTxt.Parent = vipPanel
	vipOrderLabel = vipTxt

	-- Express Delivery Mission Card
	local expPanel = Instance.new("Frame")
	expPanel.Name = "ExpressDeliveryPanel"
	expPanel.Position = UDim2.new(0, 14, 0, 350)
	expPanel.Size = UDim2.fromOffset(214, 92)
	expPanel.BackgroundColor3 = C_OBS
	expPanel.BackgroundTransparency = 0.08
	expPanel.Parent = gui
	makeCorner(expPanel, 6)
	makeBorderStroke(expPanel, C_BORDER, 1)

	local expHeader = Instance.new("TextLabel")
	expHeader.Position = UDim2.new(0, 10, 0, 4)
	expHeader.Size = UDim2.new(1, -20, 0, 18)
	expHeader.BackgroundTransparency = 1
	expHeader.Font = FONT_TITLE
	expHeader.Text = "EXPRESS DELIVERY"
	expHeader.TextSize = 10
	expHeader.TextXAlignment = Enum.TextXAlignment.Left
	expHeader.TextColor3 = C_BRASS
	expHeader.Parent = expPanel

	local expTxt = Instance.new("TextLabel")
	expTxt.Position = UDim2.new(0, 10, 0, 22)
	expTxt.Size = UDim2.new(1, -20, 0, 38)
	expTxt.BackgroundTransparency = 1
	expTxt.Font = Enum.Font.Gotham
	expTxt.TextWrapped = true
	expTxt.TextXAlignment = Enum.TextXAlignment.Left
	expTxt.TextYAlignment = Enum.TextYAlignment.Top
	expTxt.TextSize = 10
	expTxt.TextColor3 = C_BONE
	expTxt.Text = "Express dispatch pending..."
	expTxt.Parent = expPanel
	expressOrderLabel = expTxt

	local expBtn = Instance.new("TextButton")
	expBtn.Name = "AcceptExpressBtn"
	expBtn.Position = UDim2.new(0, 10, 1, -28)
	expBtn.Size = UDim2.new(1, -20, 0, 22)
	expBtn.BackgroundColor3 = Color3.fromRGB(48, 86, 62)
	expBtn.Font = FONT_TITLE
	expBtn.Text = "ACCEPT EXPRESS"
	expBtn.TextSize = 10
	expBtn.TextColor3 = C_BONE
	expBtn.Parent = expPanel
	makeCorner(expBtn, 4)
	makeBorderStroke(expBtn, C_BORDER, 1)
	expBtn.MouseButton1Click:Connect(function()
		if onAcceptExpress then onAcceptExpress() end
	end)
	expressAcceptBtn = expBtn

	-- Clean Bottom Action Dock (Seated neatly ABOVE the new 1-5 Numbered Thumbnail Hotbar!)
	local dock = Instance.new("Frame")
	dock.Name = "BottomDock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Position = UDim2.new(0.5, 0, 1, -104)
	dock.Size = UDim2.fromOffset(920, 40)
	dock.BackgroundTransparency = 1
	dock.Parent = gui

	local dockLayout = Instance.new("UIListLayout")
	dockLayout.FillDirection = Enum.FillDirection.Horizontal
	dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dockLayout.Padding = UDim.new(0, 6)
	dockLayout.Parent = dock

	createDockButton(dock, "KitchenBtn", "Kitchen", "C", C_OBS, C_BRASS, 1, false, function() onOpenMenu("Kitchen") end)
	createDockButton(dock, "WarehouseBtn", "Storage", "B", C_OBS, Color3.fromRGB(88, 106, 128), 2, false, function() onOpenMenu("Warehouses") end)
	createDockButton(dock, "UpgradeBtn", "Empire", "U", C_OBS, Color3.fromRGB(118, 104, 134), 3, false, function() onOpenMenu("Upgrades") end)
	local bmBtn = createDockButton(dock, "BlackMarketBtn", "Black Market", "M", Color3.fromRGB(32, 16, 20), C_OXBLOOD, 4, false, function() onOpenMenu("BlackMarket") end)
	bmBtn.Size = UDim2.fromOffset(128, 36)
	createDockButton(dock, "RobuxShopBtn", "R$ Store", "P", Color3.fromRGB(18, 28, 22), C_BRASS, 5, true, function() onOpenMenu("Shop") end)
	local sBtn, sLbl = createDockButton(dock, "SellBtn", "Sell (0)", nil, C_OBS, Color3.fromRGB(68, 114, 82), 6, false, onQuickServe)
	sellBadgeBtn = sBtn
	sellTextLabel = sLbl

	if onToggleScooter then
		local _, bikeLbl = createDockButton(dock, "ScooterBtn", "Bike", "V", C_OBS, Color3.fromRGB(86, 112, 122), 7, false, onToggleScooter)
		bikeTextLabel = bikeLbl
	end
	if onReturnHome then
		createDockButton(dock, "BaseBtn", "Base", "H", C_OBS, Color3.fromRGB(108, 112, 122), 8, false, onReturnHome)
	end

	-- Subtle Controls Hint Strip (Cleanly positioned above Bottom Dock)
	local hintStrip = Instance.new("TextLabel")
	hintStrip.Name = "ControlsHint"
	hintStrip.AnchorPoint = Vector2.new(0.5, 1)
	hintStrip.Position = UDim2.new(0.5, 0, 1, -146)
	hintStrip.Size = UDim2.fromOffset(540, 16)
	hintStrip.BackgroundTransparency = 1
	hintStrip.Font = Enum.Font.Gotham
	hintStrip.Text = "[1-5] Equip   |   [RMB] Aim / Scope   |   [Ctrl] Crouch   |   [Shift] Sprint   |   [M] Black Market"
	hintStrip.TextSize = 10
	hintStrip.TextColor3 = Color3.fromRGB(178, 180, 188)
	hintStrip.Parent = gui
	makeTextOutline(hintStrip, 1.0)

	-- Toast Feedback Banner
	local toast = Instance.new("TextLabel")
	toast.Name = "ToastBanner"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -200)
	toast.Size = UDim2.fromOffset(470, 32)
	toast.BackgroundColor3 = C_OBS
	toast.BackgroundTransparency = 0.05
	toast.Font = FONT_BODY
	toast.Text = ""
	toast.TextSize = 12
	toast.TextColor3 = C_BONE
	toast.Visible = false
	toast.Parent = gui
	makeCorner(toast, 5)
	makeBorderStroke(toast, C_BRASS, 1)
	toastLabel = toast

	-- Thermal-Paper Printed Restaurant Receipt Pop-Up (Above bottom-right Minimap)
	local ticket = Instance.new("Frame")
	ticket.Name = "ReceiptTicket"
	ticket.AnchorPoint = Vector2.new(1, 1)
	ticket.Position = UDim2.new(1, -14, 1, -184)
	ticket.Size = UDim2.fromOffset(212, 134)
	ticket.BackgroundColor3 = Color3.fromRGB(242, 238, 226)
	ticket.Visible = false
	ticket.Parent = gui
	makeCorner(ticket, 5)
	makeBorderStroke(ticket, C_BORDER, 1.2)
	receiptTicket = ticket

	local rHead = Instance.new("TextLabel")
	rHead.Name = "Header"
	rHead.Size = UDim2.new(1, 0, 0, 22)
	rHead.BackgroundColor3 = C_OBS
	rHead.Font = FONT_TITLE
	rHead.Text = "RECEIPT #1"
	rHead.TextSize = 11
	rHead.TextColor3 = C_BRASS
	rHead.Parent = ticket
	makeCorner(rHead, 4)
	receiptHeaderLbl = rHead

	local rBody = Instance.new("TextLabel")
	rBody.Name = "Body"
	rBody.Position = UDim2.new(0, 8, 0, 26)
	rBody.Size = UDim2.new(1, -16, 1, -32)
	rBody.BackgroundTransparency = 1
	rBody.Font = Enum.Font.Code
	rBody.TextWrapped = true
	rBody.TextXAlignment = Enum.TextXAlignment.Left
	rBody.TextYAlignment = Enum.TextYAlignment.Top
	rBody.TextSize = 11
	rBody.TextColor3 = Color3.fromRGB(28, 30, 36)
	rBody.Text = ""
	rBody.Parent = ticket
	receiptBodyLbl = rBody

	-- Top-Right Urban Turf Control Card (Clean 6px spacing below Armor Bar!)
	local turfCard = Instance.new("Frame")
	turfCard.Name = "UrbanTurfCard"
	turfCard.AnchorPoint = Vector2.new(1, 0)
	turfCard.Position = UDim2.new(1, -14, 0, 116)
	turfCard.Size = UDim2.fromOffset(216, 54)
	turfCard.BackgroundColor3 = C_OBS
	turfCard.BackgroundTransparency = 0.06
	turfCard.Parent = gui
	makeCorner(turfCard, 6)
	makeBorderStroke(turfCard, C_BORDER, 1)

	local tHead = Instance.new("TextLabel")
	tHead.Position = UDim2.new(0, 8, 0, 3)
	tHead.Size = UDim2.new(1, -16, 0, 15)
	tHead.BackgroundTransparency = 1
	tHead.Font = FONT_TITLE
	tHead.Text = "URBAN TURF CONTROL"
	tHead.TextSize = 10
	tHead.TextXAlignment = Enum.TextXAlignment.Left
	tHead.TextColor3 = C_BRASS
	tHead.Parent = turfCard

	local tSum = Instance.new("TextLabel")
	tSum.Position = UDim2.new(0, 8, 0, 19)
	tSum.Size = UDim2.new(1, -16, 0, 15)
	tSum.BackgroundTransparency = 1
	tSum.Font = FONT_BODY
	tSum.Text = "Blocks: 0 / 16  |  +0G / 20s"
	tSum.TextSize = 10
	tSum.TextXAlignment = Enum.TextXAlignment.Left
	tSum.TextColor3 = C_BONE
	tSum.Parent = turfCard
	turfSummaryLabel = tSum

	local tAlert = Instance.new("TextLabel")
	tAlert.Position = UDim2.new(0, 8, 0, 35)
	tAlert.Size = UDim2.new(1, -16, 0, 15)
	tAlert.BackgroundTransparency = 1
	tAlert.Font = Enum.Font.Gotham
	tAlert.Text = "Click minimap blocks to raid Mafia"
	tAlert.TextSize = 10
	tAlert.TextXAlignment = Enum.TextXAlignment.Left
	tAlert.TextColor3 = C_ASH
	tAlert.TextTruncate = Enum.TextTruncate.AtEnd
	tAlert.Parent = turfCard
	turfAlertLabel = tAlert

	-- Contextual Block Capture Banner
	local bBanner = Instance.new("Frame")
	bBanner.Name = "ActiveBlockCaptureBanner"
	bBanner.AnchorPoint = Vector2.new(0.5, 0)
	bBanner.Position = UDim2.new(0.5, 0, 0, 102)
	bBanner.Size = UDim2.fromOffset(356, 52)
	bBanner.BackgroundColor3 = C_OBS
	bBanner.BackgroundTransparency = 0.06
	bBanner.Visible = false
	bBanner.Parent = gui
	makeCorner(bBanner, 6)
	makeBorderStroke(bBanner, C_BORDER, 1.2)
	activeBlockBanner = bBanner

	local bTitle = Instance.new("TextLabel")
	bTitle.Position = UDim2.new(0, 10, 0, 4)
	bTitle.Size = UDim2.new(0.58, -10, 0, 22)
	bTitle.BackgroundTransparency = 1
	bTitle.Font = FONT_TITLE
	bTitle.TextXAlignment = Enum.TextXAlignment.Left
	bTitle.Text = "LITTLE ITALY ROW"
	bTitle.TextSize = 13
	bTitle.TextColor3 = Color3.fromRGB(255, 232, 134)
	bTitle.Parent = bBanner
	makeTextOutline(bTitle, 1.2)
	activeBlockTitle = bTitle

	local bOwner = Instance.new("TextLabel")
	bOwner.AnchorPoint = Vector2.new(1, 0)
	bOwner.Position = UDim2.new(1, -10, 0, 5)
	bOwner.Size = UDim2.new(0.40, 0, 0, 20)
	bOwner.BackgroundColor3 = Color3.fromRGB(238, 112, 24)
	bOwner.Font = FONT_TITLE
	bOwner.Text = "IRON CLAW"
	bOwner.TextSize = 11
	bOwner.TextColor3 = Color3.new(1, 1, 1)
	bOwner.Parent = bBanner
	makeCorner(bOwner, 6)
	makeTextOutline(bOwner, 1.0)
	activeBlockOwnerPill = bOwner

	local bBarBg = Instance.new("Frame")
	bBarBg.Position = UDim2.new(0, 10, 0, 30)
	bBarBg.Size = UDim2.new(1, -20, 0, 19)
	bBarBg.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
	bBarBg.Parent = bBanner
	makeCorner(bBarBg, 7)

	local bFill = Instance.new("Frame")
	bFill.Size = UDim2.fromScale(0, 1)
	bFill.BackgroundColor3 = Color3.fromRGB(58, 214, 118)
	bFill.Parent = bBarBg
	makeCorner(bFill, 7)
	activeBlockFill = bFill

	local bSub = Instance.new("TextLabel")
	bSub.Size = UDim2.fromScale(1, 1)
	bSub.BackgroundTransparency = 1
	bSub.Font = FONT_TITLE
	bSub.Text = "MAFIA CONTROLLED"
	bSub.TextSize = 11
	bSub.TextColor3 = Color3.new(1, 1, 1)
	bSub.ZIndex = 3
	bSub.Parent = bBarBg
	makeTextOutline(bSub, 1.0)
	activeBlockSub = bSub

	if turfProximityConn then
		turfProximityConn:Disconnect()
	end
	local checkAcc = 0
	turfProximityConn = RunService.Heartbeat:Connect(function(dt: number)
		checkAcc += dt
		if checkAcc < 0.2 then
			return
		end
		checkAcc = 0
		if not activeBlockBanner then
			return
		end
		local char = Players.LocalPlayer.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		local turf = latestTurfState
		if not root or not root:IsA("BasePart") or typeof(turf) ~= "table" or typeof(turf.Blocks) ~= "table" then
			activeBlockBanner.Visible = false
			return
		end

		local pos = root.Position
		local foundBlock: { [string]: any }? = nil
		for _, blockId in ipairs(TurfConfig.BlockOrder) do
			local b = turf.Blocks[blockId]
			if typeof(b) == "table" and typeof(b.PlazaX) == "number" and typeof(b.PlazaZ) == "number" then
				local r = (tonumber(b.CaptureRadius) or 29) + 12
				local dx = pos.X - b.PlazaX
				local dz = pos.Z - b.PlazaZ
				if (dx * dx + dz * dz) <= (r * r) then
					foundBlock = b
					break
				end
			end
		end

		if not foundBlock then
			activeBlockBanner.Visible = false
			return
		end

		activeBlockBanner.Visible = true
		local ownerCol = Color3.fromRGB(
			tonumber(foundBlock.ColorR) or 160,
			tonumber(foundBlock.ColorG) or 160,
			tonumber(foundBlock.ColorB) or 160
		)
		local capCol = Color3.fromRGB(
			tonumber(foundBlock.CapColorR) or 68,
			tonumber(foundBlock.CapColorG) or 214,
			tonumber(foundBlock.CapColorB) or 118
		)
		if activeBlockTitle then
			activeBlockTitle.Text = string.upper(tostring(foundBlock.DisplayName or "BLOCK"))
		end
		if activeBlockOwnerPill then
			if foundBlock.Status == "Contested" then
				activeBlockOwnerPill.Text = "CONTESTED"
				activeBlockOwnerPill.BackgroundColor3 = TurfConfig.ContestedColor
			else
				activeBlockOwnerPill.Text = string.upper(tostring(foundBlock.OwnerName or "MAFIA"))
				activeBlockOwnerPill.BackgroundColor3 = ownerCol
			end
		end
		if activeBlockFill then
			activeBlockFill.Size = UDim2.fromScale(math.clamp(tonumber(foundBlock.Progress) or 0, 0, 1), 1)
			activeBlockFill.BackgroundColor3 = capCol
		end
		if activeBlockSub then
			local defs = tonumber(foundBlock.DefendersAlive) or 0
			local prog = tonumber(foundBlock.Progress) or 0
			if foundBlock.Status == "Contested" then
				activeBlockSub.Text = "CONTESTED  |  Eliminate or push out rival units"
			elseif prog > 0.01 then
				activeBlockSub.Text = string.format("%s CAPTURING... %d%%", string.upper(tostring(foundBlock.CapturingName or "CAPTURING")), math.floor(prog * 100))
			elseif TurfConfig.IsMafiaFaction(tostring(foundBlock.Owner or "")) then
				activeBlockSub.Text = if defs > 0
					then string.format("%d Mafia Defender(s)  |  Clear and hold plaza", defs)
					else "Defenders cleared  |  Hold plaza to claim"
			else
				activeBlockSub.Text = string.format("Controlled (+%dG/20s)  |  %d Guard(s) on patrol", tonumber(foundBlock.IncomeGold) or 18, defs)
			end
		end
	end)

	-- Tactical Squad & Black Market Tier 2 Gadget Command Strip
	local cmdStrip = Instance.new("Frame")
	cmdStrip.Name = "SquadTacticalCommandBar"
	cmdStrip.AnchorPoint = Vector2.new(0.5, 1)
	cmdStrip.Position = UDim2.new(0.5, 0, 1, -166)
	cmdStrip.Size = UDim2.fromOffset(664, 28)
	cmdStrip.BackgroundTransparency = 1
	cmdStrip.Parent = gui

	local cmdLayout = Instance.new("UIListLayout")
	cmdLayout.FillDirection = Enum.FillDirection.Horizontal
	cmdLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cmdLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	cmdLayout.Padding = UDim.new(0, 6)
	cmdLayout.Parent = cmdStrip

	local function makeCmdBtn(name: string, text: string, width: number, bg: Color3, border: Color3, cb: (() -> ())?): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.Size = UDim2.fromOffset(width, 26)
		b.BackgroundColor3 = bg
		b.AutoButtonColor = false
		b.Font = FONT_TITLE
		b.Text = text
		b.TextSize = 10
		b.TextColor3 = C_BONE
		b.Parent = cmdStrip
		makeCorner(b, 4)
		makeBorderStroke(b, border, 1.2)
		b.MouseEnter:Connect(function()
			b.BackgroundColor3 = bg:Lerp(Color3.new(1, 1, 1), 0.12)
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundColor3 = bg
		end)
		b.MouseButton1Click:Connect(function()
			if cb then cb() end
		end)
		return b
	end

	local attackBtn = makeCmdBtn("SquadAttackBtn", "ATTACK ALL  [Y]", 130, Color3.fromRGB(122, 26, 34), Color3.fromRGB(184, 52, 62), onSquadAttack)
	local recallBtn = makeCmdBtn("SquadRecallBtn", "CALL BACK  [Z]", 122, Color3.fromRGB(36, 46, 62), Color3.fromRGB(108, 124, 148), onSquadRecall)
	local flashBtn = makeCmdBtn("GadgetFlashBtn", "FLASH (2) [6]", 114, Color3.fromRGB(54, 52, 40), C_BRASS, onThrowFlashbang)
	local c4Btn = makeCmdBtn("GadgetC4Btn", "C4 (1) [7]", 96, Color3.fromRGB(64, 30, 32), Color3.fromRGB(178, 56, 62), onDeployC4)
	local dashBtn = makeCmdBtn("GadgetDashBtn", "SHADOW DASH [8]", 122, Color3.fromRGB(30, 34, 44), Color3.fromRGB(98, 114, 142), onTriggerShadowDash)
	-- Hide squad command & locked gadget buttons until the player actually hires Bodyguards/Mafia or owns the gadget!
	attackBtn.Visible = false
	recallBtn.Visible = false
	flashBtn.Visible = false
	c4Btn.Visible = false
	dashBtn.Visible = false
	gui:SetAttribute("HasGadgetStrip", true)
	flashBtn:SetAttribute("IsGadgetBtn", "Flash")
	c4Btn:SetAttribute("IsGadgetBtn", "C4")
	dashBtn:SetAttribute("IsGadgetBtn", "Dash")

	return gui
end

function HUDController.ShowToast(message: string, isError: boolean?): ()
	if not toastLabel then
		return
	end
	toastToken += 1
	local myToken = toastToken
	toastLabel.Text = message
	toastLabel.TextColor3 = if isError then Color3.fromRGB(224, 118, 124) else C_BONE
	toastLabel.Visible = true
	task.delay(3.2, function()
		if toastToken == myToken and toastLabel then
			toastLabel.Visible = false
		end
	end)
end

function HUDController.Update(state: { [string]: any }): ()
	local profile = state.Profile
	if profile then
		if coinsLabel then
			coinsLabel.Text = string.format("%d Gold", profile.Coins or 0)
		end
		if repLabel then
			repLabel.Text = string.format("%d Rep", profile.Reputation or 0)
		end
		if levelLabel then
			levelLabel.Text = string.format("Lv.%d  |  %d XP", profile.Level or 1, profile.EXP or 0)
		end
	end

	local slot = state.BaseSlot
	if baseBadge and typeof(slot) == "string" then
		baseBadge.Text = slot .. " Base"
		local col = SectorConfig.FactionColors[slot]
		if col and basePillFrame then
			local strip = basePillFrame:FindFirstChild("AccentStrip")
			if strip and strip:IsA("Frame") then
				strip.BackgroundColor3 = col
			end
		end
	end

	local emperor = state.FoodEmperor
	local starInfo = state.StarRating
	local syn = state.Syndicate
	if emperorBanner and typeof(emperor) == "table" then
		local stars = if typeof(starInfo) == "table" and typeof(starInfo.Stars) == "number" then starInfo.Stars else 1
		local rankTitle = if typeof(syn) == "table" and typeof(syn.RankTitle) == "string" then syn.RankTitle else "STREET RUNNER"
		local pv = state.PrestigeVault
		local pLv = if typeof(pv) == "table" and typeof(pv.PrestigeLevel) == "number" then pv.PrestigeLevel else 0
		local fam = state.SyndicateFamily
		local famTag = if typeof(fam) == "table" and fam.InFamily and typeof(fam.FamilyName) == "string" then ("  |  " .. fam.FamilyName) else ""
		local pTag = if pLv > 0 then string.format(" [GODFATHER P%d]", pLv) else ""
		emperorBanner.Text = string.format(
			"RANK: %s%s  |  %d-STAR BISTRO  |  EMPEROR: %s%s",
			rankTitle,
			pTag,
			stars,
			string.upper(emperor.Name or "--"),
			famTag
		)
	end

	local kitchen = state.Kitchen
	local waiting = state.WaitingCustomer
	if sellBadgeBtn and sellTextLabel and kitchen then
		local ready = kitchen.ReadyTotal or 0
		if ready > 0 then
			sellTextLabel.Text = string.format("SELL (%d)", ready)
			sellBadgeBtn.BackgroundColor3 = Color3.fromRGB(36, 72, 48)
		elseif typeof(waiting) == "table" and waiting.IsBeingCooked then
			sellTextLabel.Text = "COOKING"
			sellBadgeBtn.BackgroundColor3 = Color3.fromRGB(72, 54, 28)
		elseif typeof(waiting) == "table" and waiting.CustomerName then
			sellTextLabel.Text = "SERVE"
			sellBadgeBtn.BackgroundColor3 = Color3.fromRGB(36, 72, 48)
		else
			sellTextLabel.Text = "SELL (0)"
			sellBadgeBtn.BackgroundColor3 = C_OBS
		end
	end

	-- Pop up Printed Restaurant Receipt Ticket whenever a new order is rung up!
	local latest = state.LatestReceipt
	if typeof(latest) == "table" and typeof(latest.OrderNo) == "number" and latest.OrderNo > lastReceiptOrderNo then
		lastReceiptOrderNo = latest.OrderNo
		if receiptTicket and receiptHeaderLbl and receiptBodyLbl then
			receiptHeaderLbl.Text = string.format("RECEIPT #%d  |  PAID", latest.OrderNo)
			receiptBodyLbl.Text = string.format(
				"FOOD EMPIRE DINER\n---------------------\nGuest: %s\nItem:  %s\nChef:  %s\n---------------------\nTOTAL: +%dG | +%d Rep",
				tostring(latest.CustomerName or "Guest"),
				tostring(latest.DishName or "Meal"),
				tostring(latest.ChefName or "Chef"),
				tonumber(latest.GoldEarned) or 0,
				tonumber(latest.RepEarned) or 0
			)
			receiptTicket.Visible = true
			receiptHideToken += 1
			local myReceiptToken = receiptHideToken
			task.delay(5.0, function()
				if receiptHideToken == myReceiptToken and receiptTicket then
					receiptTicket.Visible = false
				end
			end)
		end
	end

	if bikeTextLabel then
		local ownsBike = state.OwnsMotorbike == true
		bikeTextLabel.Text = if ownsBike then "BIKE" else "BIKE [LOCK]"
	end

	local shipments = state.Shipments
	local readyShipmentCount = 0
	if typeof(shipments) == "table" then
		for sectorId, dot in pairs(sectorDots) do
			local sh = shipments[sectorId]
			local lbl = sectorStatusLabels[sectorId]
			local tag = SECTOR_TAGS[sectorId] or "SEC"
			if typeof(sh) == "table" then
				local shortName = if sectorId == "FishingPort" then "Fish Port"
					elseif sectorId == "VegetableFarm" then "Veg Farm"
					elseif sectorId == "FruitOrchard" then "Orchard"
					else "Ranch"
				if sh.Phase == "EnRoute" then
					dot.BackgroundColor3 = C_BRASS
					if lbl then
						lbl.Text = string.format("[%s] %s: EN ROUTE", tag, shortName)
						lbl.TextColor3 = C_BRASS
					end
				elseif sh.Phase == "Arrived" then
					readyShipmentCount += 1
					dot.BackgroundColor3 = Color3.fromRGB(78, 134, 96)
					if lbl then
						lbl.Text = string.format("[%s] %s: AT CENTER", tag, shortName)
						lbl.TextColor3 = Color3.fromRGB(168, 212, 180)
					end
				else
					dot.BackgroundColor3 = SectorConfig.FactionColors.Neutral
					if lbl then
						lbl.Text = string.format("[%s] %s: %ds", tag, shortName, tonumber(sh.SecondsUntilNext) or 0)
						lbl.TextColor3 = C_ASH
					end
				end
			end
		end
	end

	if objectiveLabel then
		local totalStock = 0
		local unlockedWh = 0
		if state.Warehouse then
			if state.Warehouse.CategoryTotals then
				for _, v in pairs(state.Warehouse.CategoryTotals) do
					totalStock += v
				end
			end
			if state.Warehouse.Levels then
				for _, lv in pairs(state.Warehouse.Levels) do
					if lv >= 1 then
						unlockedWh += 1
					end
				end
			end
		end
		local readyDishes = if kitchen then (kitchen.ReadyTotal or 0) else 0
		local rep = if profile then (profile.Reputation or 0) else 0
		local restLv = if profile then (profile.RestaurantLevel or 1) else 1
		local crewCount = if profile then (profile.CrewCount or 0) else 0
		local waiterCount = tonumber(state.WaiterCount) or 0
		local courierCount = tonumber(state.CourierCount) or 0
		local branch = state.CentralParkBranch
		local underShakedown = typeof(branch) == "table" and branch.UnderShakedown == true

		if underShakedown then
			objectiveLabel.Text = "ALERT: Central Park Bistro under Shakedown! Open Empire [U] -> DEFEND (+260G)!"
		elseif not state.BaseSlot then
			objectiveLabel.Text = "STEP 1: Select and claim your Restaurant Plaza Base."
		elseif readyDishes > 0 and waiterCount == 0 then
			objectiveLabel.Text = "STEP 2: Press [SERVE] (or hire a Waiter in Empire [U]) to sell cooked dishes!"
		elseif rep < 15 and crewCount == 0 then
			if totalStock < 2 then
				objectiveLabel.Text = "STEP 1: Claim a Corner Shipment at Central Plaza [E] or spin the Lucky Wheel."
			else
				objectiveLabel.Text = "STEP 2: Open Kitchen [C] to cook your 1st dish, then press [SERVE]!"
			end
		elseif courierCount == 0 or crewCount == 0 or waiterCount == 0 then
			objectiveLabel.Text = string.format(
				"STEP 3: Open Empire [U] to hire Couriers (%d/2), Chefs (%d), & Waiters (%d/3).",
				courierCount,
				crewCount,
				waiterCount
			)
		elseif typeof(branch) == "table" and not branch.Owned then
			objectiveLabel.Text = "STEP 4: Buy the Central Park Bistro (750G in Empire [U]) & call your staff!"
		elseif unlockedWh < 4 then
			objectiveLabel.Text = string.format("STEP 5: Open Storage [B] and unlock all 4 Warehouses (%d/4).", unlockedWh)
		elseif restLv < 2 then
			objectiveLabel.Text = "STEP 6: Upgrade Restaurant HQ [U], escort Smuggler Convoys & complete Contracts!"
		else
			objectiveLabel.Text = "Complete Syndicate Contracts [U], seize Gang War Drops & reign as Food Emperor!"
		end
	end

	if vipOrderLabel then
		local vip = state.VIPOrder
		if typeof(vip) == "table" and vip.DisplayName then
			vipOrderLabel.Text = string.format(
				"Serve %s\n+%dG  |  +%d Rep  (%ds)",
				vip.DisplayName,
				vip.BonusCoins or 0,
				vip.BonusRep or 0,
				vip.Remaining or 0
			)
		else
			vipOrderLabel.Text = "Next VIP Critic order pending..."
		end
	end

	if expressOrderLabel and expressAcceptBtn then
		local exp = state.ExpressDelivery
		if typeof(exp) == "table" then
			local comboStr = if (exp.Combo or 0) > 0 then string.format(" [x%d]", exp.Combo) else ""
			if exp.Status == "Active" then
				expressOrderLabel.Text = string.format(
					"%s -> %s\n%ds left  |  +%dG + Tip%s",
					tostring(exp.DishName or "Meal"),
					tostring(exp.DropName or "Center"),
					tonumber(exp.Remaining) or 0,
					tonumber(exp.BaseGold) or 100,
					comboStr
				)
				expressAcceptBtn.Text = string.format("EN ROUTE (%ds)", tonumber(exp.Remaining) or 0)
				expressAcceptBtn.BackgroundColor3 = Color3.fromRGB(116, 78, 32)
			elseif exp.Status == "Available" then
				expressOrderLabel.Text = string.format(
					"%s: %s at %s\n+%dG + Speed Tip (%ds)%s",
					tostring(exp.CustomerName or "Guest"),
					tostring(exp.DishName or "Meal"),
					tostring(exp.DropName or "Center"),
					tonumber(exp.BaseGold) or 100,
					tonumber(exp.Duration) or 45,
					comboStr
				)
				expressAcceptBtn.Text = "ACCEPT EXPRESS"
				expressAcceptBtn.BackgroundColor3 = Color3.fromRGB(48, 86, 62)
			else
				expressOrderLabel.Text = string.format("Next express dispatch in %ds%s", tonumber(exp.Remaining) or 5, comboStr)
				expressAcceptBtn.Text = "STANDBY"
				expressAcceptBtn.BackgroundColor3 = C_CHAR
			end
		end
	end

	local turf = state.Turf
	if typeof(turf) == "table" then
		latestTurfState = turf
		local owned = tonumber(turf.OwnedCount) or 0
		local total = tonumber(turf.TotalBlocks) or 28
		local inc = tonumber(turf.IncomePerCycle) or 0
		local mono = tonumber(turf.Monopolies) or 0
		if turfSummaryLabel then
			local monoTag = if mono > 0 then string.format("  |  %d MONO", mono) else ""
			turfSummaryLabel.Text = string.format("Blocks: %d/%d  |  +%dG/20s%s", owned, total, inc, monoTag)
		end
		if turfAlertLabel and typeof(turf.Blocks) == "table" then
			local myFaction = "Player_" .. tostring(Players.LocalPlayer.UserId)
			local underAttackName: string? = nil
			for _, b in pairs(turf.Blocks) do
				if typeof(b) == "table" and b.Owner == myFaction and b.UnderAttack == true then
					underAttackName = tostring(b.DisplayName or "Your Block")
					break
				end
			end
			if underAttackName then
				turfAlertLabel.Text = "RAID ACTIVE: " .. string.upper(underAttackName)
				turfAlertLabel.TextColor3 = Color3.fromRGB(218, 96, 102)
			elseif owned == 0 then
				turfAlertLabel.Text = "Engage Mafia across 28 urban blocks"
				turfAlertLabel.TextColor3 = C_ASH
			else
				turfAlertLabel.Text = "Hold all 7 in a quadrant for +50%"
				turfAlertLabel.TextColor3 = Color3.fromRGB(154, 198, 166)
			end
		end
	end

	-- Update Squad Command buttons (only shown when Bodyguards or Hired Samurai/Ninja Mafia are active!)
	-- and Tier 2 Tactical Gadget Pills (only shown when owned / ammo > 0!)
	if screenGui then
		local strip = screenGui:FindFirstChild("SquadTacticalCommandBar")
		if strip and strip:IsA("Frame") then
			local hasGuards = (tonumber(state.BodyguardCount) or 0) > 0
			local merc = state.MercenaryMafia
			local hasMerc = typeof(merc) == "table" and merc.Active == true
			local showSquadCmds = hasGuards or hasMerc

			local atkBtn = strip:FindFirstChild("SquadAttackBtn")
			if atkBtn and atkBtn:IsA("TextButton") then
				atkBtn.Visible = showSquadCmds
			end
			local recBtn = strip:FindFirstChild("SquadRecallBtn")
			if recBtn and recBtn:IsA("TextButton") then
				recBtn.Visible = showSquadCmds
			end

			local bm = state.BlackMarket
			local flashCount = if typeof(bm) == "table" then (tonumber(bm.Flashbangs) or 0) else 0
			local c4Count = if typeof(bm) == "table" then (tonumber(bm.C4Charges) or 0) else 0
			local hasDash = typeof(bm) == "table" and bm.HasShadowDash == true

			local fBtn = strip:FindFirstChild("GadgetFlashBtn")
			if fBtn and fBtn:IsA("TextButton") then
				fBtn.Visible = flashCount > 0
				fBtn.Text = string.format("FLASH (%d) [6]", flashCount)
			end
			local cBtn = strip:FindFirstChild("GadgetC4Btn")
			if cBtn and cBtn:IsA("TextButton") then
				cBtn.Visible = c4Count > 0
				cBtn.Text = string.format("C4 (%d) [7]", c4Count)
			end
			local dBtn = strip:FindFirstChild("GadgetDashBtn")
			if dBtn and dBtn:IsA("TextButton") then
				dBtn.Visible = hasDash
				dBtn.Text = "SHADOW DASH [8]"
			end

			strip.Visible = showSquadCmds or flashCount > 0 or c4Count > 0 or hasDash
		end
	end
end

return HUDController
