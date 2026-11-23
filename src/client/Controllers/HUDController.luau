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

local SECTOR_ICONS: { [string]: string } = {
	FishingPort = "🐟",
	VegetableFarm = "🥕",
	Ranch = "🥩",
	FruitOrchard = "🥭",
}

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
	bg: Color3,
	iconBg: Color3,
	iconGlyph: string,
	initialText: string
): (Frame, TextLabel)
	local pill = Instance.new("Frame")
	pill.Name = name
	pill.LayoutOrder = layoutOrder
	pill.Size = UDim2.fromOffset(152, 40)
	pill.BackgroundColor3 = bg
	pill.Parent = parent
	makeCorner(pill, 12)
	makeBorderStroke(pill, Color3.fromRGB(18, 24, 36), 2)
	addGlossGradient(pill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 212, 224))

	local iconCircle = Instance.new("TextLabel")
	iconCircle.Name = "IconBadge"
	iconCircle.Position = UDim2.new(0, 5, 0.5, -15)
	iconCircle.Size = UDim2.fromOffset(30, 30)
	iconCircle.BackgroundColor3 = iconBg
	iconCircle.Font = FONT_TITLE
	iconCircle.Text = iconGlyph
	iconCircle.TextSize = 17
	iconCircle.TextColor3 = Color3.new(1, 1, 1)
	iconCircle.Parent = pill
	makeCorner(iconCircle, 15)
	makeBorderStroke(iconCircle, Color3.fromRGB(255, 246, 210), 1.5)

	local val = Instance.new("TextLabel")
	val.Name = "ValueText"
	val.Position = UDim2.new(0, 40, 0, 0)
	val.Size = UDim2.new(1, -46, 1, 0)
	val.BackgroundTransparency = 1
	val.Font = FONT_TITLE
	val.Text = initialText
	val.TextSize = 14
	val.TextXAlignment = Enum.TextXAlignment.Left
	val.TextColor3 = Color3.new(1, 1, 1)
	val.Parent = pill
	makeTextOutline(val, 1.5)

	return pill, val
end

local function createDockButton(
	parent: Instance,
	name: string,
	iconGlyph: string,
	labelText: string,
	keyHint: string?,
	bg: Color3,
	iconBg: Color3,
	layoutOrder: number,
	isRobuxStyle: boolean,
	onClick: () -> ()
): (TextButton, TextLabel)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.LayoutOrder = layoutOrder
	btn.Size = UDim2.fromOffset(124, 46)
	btn.BackgroundColor3 = bg
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.Parent = parent
	makeCorner(btn, 12)
	makeBorderStroke(btn, if isRobuxStyle then Color3.fromRGB(255, 224, 92) else Color3.fromRGB(18, 24, 36), if isRobuxStyle then 2.4 else 2)
	addGlossGradient(btn, Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 212, 225))

	-- Crisp Left Icon Badge (or classic R$ Robux Emblem!)
	local badge = Instance.new("TextLabel")
	badge.Name = "Icon"
	badge.Position = UDim2.new(0, 6, 0.5, -16)
	badge.Size = UDim2.fromOffset(32, 32)
	badge.BackgroundColor3 = iconBg
	badge.Font = FONT_TITLE
	badge.Text = iconGlyph
	badge.TextSize = if isRobuxStyle then 14 else 17
	badge.TextColor3 = if isRobuxStyle then Color3.fromRGB(255, 238, 120) else Color3.new(1, 1, 1)
	badge.Parent = btn
	makeCorner(badge, if isRobuxStyle then 8 else 10)
	makeBorderStroke(badge, if isRobuxStyle then Color3.fromRGB(255, 226, 96) else Color3.fromRGB(255, 255, 255), 1.4)
	if isRobuxStyle then
		makeTextOutline(badge, 1.2)
	end

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Label"
	lbl.Position = UDim2.new(0, 42, 0, 2)
	lbl.Size = UDim2.new(1, -46, 1, -4)
	lbl.BackgroundTransparency = 1
	lbl.Font = FONT_TITLE
	lbl.Text = labelText
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Parent = btn
	makeTextOutline(lbl, 1.4)

	if keyHint and keyHint ~= "" then
		local keyCap = Instance.new("TextLabel")
		keyCap.Name = "KeyCap"
		keyCap.AnchorPoint = Vector2.new(1, 0)
		keyCap.Position = UDim2.new(1, -4, 0, -6)
		keyCap.Size = UDim2.fromOffset(18, 16)
		keyCap.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
		keyCap.Font = FONT_TITLE
		keyCap.Text = keyHint
		keyCap.TextSize = 10
		keyCap.TextColor3 = Color3.fromRGB(255, 228, 124)
		keyCap.Parent = btn
		makeCorner(keyCap, 5)
		makeBorderStroke(keyCap, Color3.fromRGB(140, 160, 198), 1)
	end

	btn.MouseButton1Click:Connect(onClick)
	return btn, lbl
end

function HUDController.Init(
	onOpenMenu: OpenMenuCallback,
	onQuickServe: QuickServeCallback,
	onReturnHome: ReturnHomeCallback?,
	onToggleScooter: ToggleScooterCallback?,
	onAcceptExpress: AcceptExpressCallback?
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

	local _, cLbl = createStatPill(topBar, "Coins", 1, Color3.fromRGB(218, 146, 20), Color3.fromRGB(255, 198, 28), "G", "90 Gold")
	coinsLabel = cLbl

	local _, rLbl = createStatPill(topBar, "Reputation", 2, Color3.fromRGB(132, 58, 206), Color3.fromRGB(238, 178, 36), "👑", "0 Rep")
	repLabel = rLbl

	local _, lLbl = createStatPill(topBar, "Level", 3, Color3.fromRGB(36, 134, 212), Color3.fromRGB(72, 186, 255), "⭐", "Lv.1 • 0 XP")
	levelLabel = lLbl

	local bFrame, bLbl = createStatPill(topBar, "BaseSlot", 4, Color3.fromRGB(58, 68, 90), Color3.fromRGB(40, 48, 68), "🏰", "Base: --")
	basePillFrame = bFrame
	baseBadge = bLbl

	-- Food Emperor Crown Banner
	local emp = Instance.new("TextLabel")
	emp.Name = "FoodEmperorBanner"
	emp.AnchorPoint = Vector2.new(0.5, 0)
	emp.Position = UDim2.new(0.5, 0, 0, 56)
	emp.Size = UDim2.fromOffset(330, 26)
	emp.BackgroundColor3 = Color3.fromRGB(32, 24, 18)
	emp.BackgroundTransparency = 0.08
	emp.Font = FONT_BODY
	emp.Text = "👑 Food Emperor: --"
	emp.TextSize = 13
	emp.TextColor3 = Color3.fromRGB(255, 224, 96)
	emp.Parent = gui
	makeCorner(emp, 9)
	makeBorderStroke(emp, Color3.fromRGB(240, 186, 48), 1.6)
	makeTextOutline(emp, 1.2)
	emperorBanner = emp

	-- Active Central District Event Pill
	local evBanner = Instance.new("TextLabel")
	evBanner.Name = "ActiveEventBanner"
	evBanner.AnchorPoint = Vector2.new(0.5, 0)
	evBanner.Position = UDim2.new(0.5, 0, 0, 86)
	evBanner.Size = UDim2.fromOffset(360, 24)
	evBanner.BackgroundColor3 = Color3.fromRGB(168, 38, 56)
	evBanner.BackgroundTransparency = 0.1
	evBanner.Font = FONT_BODY
	evBanner.TextSize = 12
	evBanner.TextColor3 = Color3.fromRGB(255, 245, 215)
	evBanner.Parent = gui
	makeCorner(evBanner, 8)
	makeBorderStroke(evBanner, Color3.fromRGB(255, 198, 120), 1.3)
	makeTextOutline(evBanner, 1.0)

	local function refreshEventText()
		local title = ReplicatedStorage:GetAttribute("ActiveEventTitle")
		evBanner.Text = "🔥 " .. (if typeof(title) == "string" then title else "Central District Market Open!")
	end
	refreshEventText()
	ReplicatedStorage:GetAttributeChangedSignal("ActiveEventTitle"):Connect(refreshEventText)

	-- Territory Ownership Strip (Top-Left, Fishing Port first to match starter Fish Warehouse!)
	local terrPanel = Instance.new("Frame")
	terrPanel.Name = "TerritoryStrip"
	terrPanel.Position = UDim2.new(0, 14, 0, 68)
	terrPanel.Size = UDim2.fromOffset(224, 138)
	terrPanel.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
	terrPanel.BackgroundTransparency = 0.12
	terrPanel.Parent = gui
	makeCorner(terrPanel, 12)
	makeBorderStroke(terrPanel, Color3.fromRGB(86, 106, 142), 1.6)

	local terrHeader = Instance.new("TextLabel")
	terrHeader.Size = UDim2.new(1, 0, 0, 26)
	terrHeader.BackgroundTransparency = 1
	terrHeader.Font = FONT_TITLE
	terrHeader.Text = "🚚 CORNER SHIPMENTS"
	terrHeader.TextSize = 13
	terrHeader.TextColor3 = Color3.fromRGB(255, 222, 112)
	terrHeader.Parent = terrPanel
	makeTextOutline(terrHeader, 1.2)

	local listHolder = Instance.new("Frame")
	listHolder.Position = UDim2.new(0, 10, 0, 28)
	listHolder.Size = UDim2.new(1, -20, 1, -34)
	listHolder.BackgroundTransparency = 1
	listHolder.Parent = terrPanel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = listHolder

	local sectorOrder = { "FishingPort", "VegetableFarm", "FruitOrchard", "Ranch" }
	for _, sectorId in ipairs(sectorOrder) do
		local entry = SectorConfig.Sectors[sectorId]
		if entry then
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 23)
			row.BackgroundTransparency = 1
			row.Parent = listHolder

			local dot = Instance.new("Frame")
			dot.Size = UDim2.fromOffset(12, 12)
			dot.Position = UDim2.new(0, 2, 0.5, -6)
			dot.BackgroundColor3 = SectorConfig.FactionColors.Neutral
			dot.Parent = row
			makeCorner(dot, 6)
			makeBorderStroke(dot, Color3.fromRGB(255, 255, 255), 1)
			sectorDots[sectorId] = dot

			local icon = SECTOR_ICONS[sectorId] or "•"
			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 20, 0, 0)
			nameLbl.Size = UDim2.new(1, -20, 1, 0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = FONT_BODY
			nameLbl.Text = icon .. " " .. entry.DisplayName
			nameLbl.TextSize = 12
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextColor3 = Color3.fromRGB(240, 244, 252)
			nameLbl.Parent = row
			sectorStatusLabels[sectorId] = nameLbl
		end
	end

	-- Next Goal Guide Panel
	local goalPanel = Instance.new("Frame")
	goalPanel.Name = "ObjectivePanel"
	goalPanel.Position = UDim2.new(0, 14, 0, 214)
	goalPanel.Size = UDim2.fromOffset(206, 80)
	goalPanel.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
	goalPanel.BackgroundTransparency = 0.12
	goalPanel.Parent = gui
	makeCorner(goalPanel, 12)
	makeBorderStroke(goalPanel, Color3.fromRGB(240, 186, 48), 1.6)

	local goalHeader = Instance.new("TextLabel")
	goalHeader.Size = UDim2.new(1, 0, 0, 22)
	goalHeader.BackgroundTransparency = 1
	goalHeader.Font = FONT_TITLE
	goalHeader.Text = "🎯 NEXT GOAL"
	goalHeader.TextSize = 12
	goalHeader.TextColor3 = Color3.fromRGB(255, 222, 112)
	goalHeader.Parent = goalPanel
	makeTextOutline(goalHeader, 1.0)

	local goalTxt = Instance.new("TextLabel")
	goalTxt.Position = UDim2.new(0, 10, 0, 22)
	goalTxt.Size = UDim2.new(1, -20, 1, -26)
	goalTxt.BackgroundTransparency = 1
	goalTxt.Font = FONT_BODY
	goalTxt.TextWrapped = true
	goalTxt.TextXAlignment = Enum.TextXAlignment.Left
	goalTxt.TextYAlignment = Enum.TextYAlignment.Top
	goalTxt.TextSize = 12
	goalTxt.TextColor3 = Color3.fromRGB(238, 242, 250)
	goalTxt.Text = "1. Capture 🐟 Fishing Port (SE) to fill your starter Fish Warehouse!"
	goalTxt.Parent = goalPanel
	objectiveLabel = goalTxt

	-- Timed VIP Food Critic Order Card
	local vipPanel = Instance.new("Frame")
	vipPanel.Name = "VIPOrderPanel"
	vipPanel.Position = UDim2.new(0, 14, 0, 302)
	vipPanel.Size = UDim2.fromOffset(206, 74)
	vipPanel.BackgroundColor3 = Color3.fromRGB(36, 26, 18)
	vipPanel.BackgroundTransparency = 0.1
	vipPanel.Parent = gui
	makeCorner(vipPanel, 12)
	makeBorderStroke(vipPanel, Color3.fromRGB(255, 206, 54), 1.8)

	local vipHeader = Instance.new("TextLabel")
	vipHeader.Size = UDim2.new(1, 0, 0, 22)
	vipHeader.BackgroundTransparency = 1
	vipHeader.Font = FONT_TITLE
	vipHeader.Text = "👑 VIP CRITIC ORDER"
	vipHeader.TextSize = 12
	vipHeader.TextColor3 = Color3.fromRGB(255, 218, 72)
	vipHeader.Parent = vipPanel
	makeTextOutline(vipHeader, 1.0)

	local vipTxt = Instance.new("TextLabel")
	vipTxt.Position = UDim2.new(0, 10, 0, 22)
	vipTxt.Size = UDim2.new(1, -20, 1, -26)
	vipTxt.BackgroundTransparency = 1
	vipTxt.Font = FONT_BODY
	vipTxt.TextWrapped = true
	vipTxt.TextXAlignment = Enum.TextXAlignment.Left
	vipTxt.TextYAlignment = Enum.TextYAlignment.Top
	vipTxt.TextSize = 12
	vipTxt.TextColor3 = Color3.fromRGB(255, 246, 220)
	vipTxt.Text = "Waiting for VIP Critic..."
	vipTxt.Parent = vipPanel
	vipOrderLabel = vipTxt

	-- Live Express Delivery Mission Card (Motorbike Rush!)
	local expPanel = Instance.new("Frame")
	expPanel.Name = "ExpressDeliveryPanel"
	expPanel.Position = UDim2.new(0, 14, 0, 384)
	expPanel.Size = UDim2.fromOffset(224, 96)
	expPanel.BackgroundColor3 = Color3.fromRGB(22, 34, 48)
	expPanel.BackgroundTransparency = 0.08
	expPanel.Parent = gui
	makeCorner(expPanel, 12)
	makeBorderStroke(expPanel, Color3.fromRGB(54, 212, 138), 1.8)

	local expHeader = Instance.new("TextLabel")
	expHeader.Size = UDim2.new(1, 0, 0, 22)
	expHeader.BackgroundTransparency = 1
	expHeader.Font = FONT_TITLE
	expHeader.Text = "🛵 MOTORBIKE RUSH"
	expHeader.TextSize = 12
	expHeader.TextColor3 = Color3.fromRGB(118, 248, 178)
	expHeader.Parent = expPanel
	makeTextOutline(expHeader, 1.0)

	local expTxt = Instance.new("TextLabel")
	expTxt.Position = UDim2.new(0, 10, 0, 21)
	expTxt.Size = UDim2.new(1, -20, 0, 42)
	expTxt.BackgroundTransparency = 1
	expTxt.Font = FONT_BODY
	expTxt.TextWrapped = true
	expTxt.TextXAlignment = Enum.TextXAlignment.Left
	expTxt.TextYAlignment = Enum.TextYAlignment.Top
	expTxt.TextSize = 11
	expTxt.TextColor3 = Color3.fromRGB(236, 246, 255)
	expTxt.Text = "Express delivery calls arriving..."
	expTxt.Parent = expPanel
	expressOrderLabel = expTxt

	local expBtn = Instance.new("TextButton")
	expBtn.Name = "AcceptExpressBtn"
	expBtn.Position = UDim2.new(0, 10, 1, -30)
	expBtn.Size = UDim2.new(1, -20, 0, 24)
	expBtn.BackgroundColor3 = Color3.fromRGB(44, 186, 98)
	expBtn.Font = FONT_TITLE
	expBtn.Text = "🛵 Accept Express Delivery"
	expBtn.TextSize = 11
	expBtn.TextColor3 = Color3.new(1, 1, 1)
	expBtn.Parent = expPanel
	makeCorner(expBtn, 7)
	makeBorderStroke(expBtn, Color3.fromRGB(18, 24, 34), 1.2)
	expBtn.MouseButton1Click:Connect(function()
		if onAcceptExpress then
			onAcceptExpress()
		end
	end)
	expressAcceptBtn = expBtn

	-- Icon-First Bottom Action Dock (Cleanly ABOVE Roblox's Backpack hotbar!)
	local dock = Instance.new("Frame")
	dock.Name = "BottomDock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Position = UDim2.new(0.5, 0, 1, -92)
	dock.Size = UDim2.fromOffset(1050, 50)
	dock.BackgroundTransparency = 1
	dock.Parent = gui

	local dockLayout = Instance.new("UIListLayout")
	dockLayout.FillDirection = Enum.FillDirection.Horizontal
	dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dockLayout.Padding = UDim.new(0, 6)
	dockLayout.Parent = dock

	createDockButton(dock, "KitchenBtn", "🍳", "Kitchen", "C", Color3.fromRGB(218, 86, 44), Color3.fromRGB(174, 58, 24), 1, false, function()
		onOpenMenu("Kitchen")
	end)
	createDockButton(dock, "WarehouseBtn", "📦", "Storage", "B", Color3.fromRGB(36, 138, 214), Color3.fromRGB(22, 96, 162), 2, false, function()
		onOpenMenu("Warehouses")
	end)
	createDockButton(dock, "UpgradeBtn", "⬆️", "Empire", "U", Color3.fromRGB(132, 58, 206), Color3.fromRGB(92, 36, 158), 3, false, function()
		onOpenMenu("Upgrades")
	end)
	local bmBtn = createDockButton(dock, "BlackMarketBtn", "🕶️", "Black Market", "M", Color3.fromRGB(184, 30, 56), Color3.fromRGB(36, 20, 38), 4, false, function()
		onOpenMenu("BlackMarket")
	end)
	bmBtn.Size = UDim2.fromOffset(146, 46)
	createDockButton(dock, "RobuxShopBtn", "R$", "Pro Shop", "P", Color3.fromRGB(222, 152, 20), Color3.fromRGB(38, 158, 78), 5, true, function()
		onOpenMenu("Shop")
	end)
	local sBtn, sLbl = createDockButton(dock, "SellBtn", "🍽️", "Sell (0)", nil, Color3.fromRGB(72, 82, 98), Color3.fromRGB(48, 58, 74), 6, false, onQuickServe)
	sellBadgeBtn = sBtn
	sellTextLabel = sLbl

	if onToggleScooter then
		local _, bikeLbl = createDockButton(dock, "ScooterBtn", "🛵", "Bike", "V", Color3.fromRGB(38, 164, 174), Color3.fromRGB(24, 118, 132), 7, false, onToggleScooter)
		bikeTextLabel = bikeLbl
	end
	if onReturnHome then
		createDockButton(dock, "BaseBtn", "🏰", "My Base", "H", Color3.fromRGB(64, 78, 108), Color3.fromRGB(42, 52, 76), 8, false, onReturnHome)
	end

	-- Subtle Quick Controls Hint Strip
	local hintStrip = Instance.new("TextLabel")
	hintStrip.Name = "ControlsHint"
	hintStrip.AnchorPoint = Vector2.new(0.5, 1)
	hintStrip.Position = UDim2.new(0.5, 0, 1, -72)
	hintStrip.Size = UDim2.fromOffset(520, 18)
	hintStrip.BackgroundTransparency = 1
	hintStrip.Font = FONT_BODY
	hintStrip.Text = "[M] Go to Black Market   •   [F] Carry Crate   •   [G] Guide Arrow   •   [Shift] Sprint"
	hintStrip.TextSize = 11
	hintStrip.TextColor3 = Color3.fromRGB(235, 240, 250)
	hintStrip.Parent = gui
	makeTextOutline(hintStrip, 1.1)

	-- Toast Feedback Banner
	local toast = Instance.new("TextLabel")
	toast.Name = "ToastBanner"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -148)
	toast.Size = UDim2.fromOffset(470, 36)
	toast.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
	toast.BackgroundTransparency = 0.08
	toast.Font = FONT_BODY
	toast.Text = ""
	toast.TextSize = 14
	toast.TextColor3 = Color3.fromRGB(130, 245, 165)
	toast.Visible = false
	toast.Parent = gui
	makeCorner(toast, 10)
	makeBorderStroke(toast, Color3.fromRGB(240, 186, 48), 1.5)
	toastLabel = toast

	-- Thermal-Paper Printed Restaurant Receipt Pop-Up (Above bottom-right Minimap)
	local ticket = Instance.new("Frame")
	ticket.Name = "ReceiptTicket"
	ticket.AnchorPoint = Vector2.new(1, 1)
	ticket.Position = UDim2.new(1, -14, 1, -184)
	ticket.Size = UDim2.fromOffset(212, 138)
	ticket.BackgroundColor3 = Color3.fromRGB(252, 248, 234)
	ticket.Visible = false
	ticket.Parent = gui
	makeCorner(ticket, 8)
	makeBorderStroke(ticket, Color3.fromRGB(52, 58, 72), 2)
	receiptTicket = ticket

	local rHead = Instance.new("TextLabel")
	rHead.Name = "Header"
	rHead.Size = UDim2.new(1, 0, 0, 24)
	rHead.BackgroundColor3 = Color3.fromRGB(30, 36, 50)
	rHead.Font = FONT_TITLE
	rHead.Text = "RECEIPT #1"
	rHead.TextSize = 12
	rHead.TextColor3 = Color3.fromRGB(255, 224, 96)
	rHead.Parent = ticket
	makeCorner(rHead, 6)
	receiptHeaderLbl = rHead

	local rBody = Instance.new("TextLabel")
	rBody.Name = "Body"
	rBody.Position = UDim2.new(0, 8, 0, 28)
	rBody.Size = UDim2.new(1, -16, 1, -34)
	rBody.BackgroundTransparency = 1
	rBody.Font = Enum.Font.Code
	rBody.TextWrapped = true
	rBody.TextXAlignment = Enum.TextXAlignment.Left
	rBody.TextYAlignment = Enum.TextYAlignment.Top
	rBody.TextSize = 12
	rBody.TextColor3 = Color3.fromRGB(28, 32, 42)
	rBody.Text = ""
	rBody.Parent = ticket
	receiptBodyLbl = rBody

	-- Top-Right Urban Turf Control Card (Cleanly in the open gap between Armor Bar and Minimap!)
	local turfCard = Instance.new("Frame")
	turfCard.Name = "UrbanTurfCard"
	turfCard.AnchorPoint = Vector2.new(1, 0)
	turfCard.Position = UDim2.new(1, -14, 0, 152)
	turfCard.Size = UDim2.fromOffset(216, 54)
	turfCard.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
	turfCard.BackgroundTransparency = 0.08
	turfCard.Parent = gui
	makeCorner(turfCard, 10)
	makeBorderStroke(turfCard, Color3.fromRGB(246, 192, 54), 1.6)

	local tHead = Instance.new("TextLabel")
	tHead.Size = UDim2.new(1, 0, 0, 18)
	tHead.BackgroundTransparency = 1
	tHead.Font = FONT_TITLE
	tHead.Text = "🏙️ URBAN TURF CONTROL"
	tHead.TextSize = 11
	tHead.TextColor3 = Color3.fromRGB(255, 224, 108)
	tHead.Parent = turfCard
	makeTextOutline(tHead, 1.0)

	local tSum = Instance.new("TextLabel")
	tSum.Position = UDim2.new(0, 8, 0, 18)
	tSum.Size = UDim2.new(1, -16, 0, 17)
	tSum.BackgroundTransparency = 1
	tSum.Font = FONT_TITLE
	tSum.Text = "Blocks: 0 / 16  •  +0G / 20s"
	tSum.TextSize = 11
	tSum.TextColor3 = Color3.fromRGB(134, 248, 178)
	tSum.Parent = turfCard
	turfSummaryLabel = tSum

	local tAlert = Instance.new("TextLabel")
	tAlert.Position = UDim2.new(0, 8, 0, 35)
	tAlert.Size = UDim2.new(1, -16, 0, 16)
	tAlert.BackgroundTransparency = 1
	tAlert.Font = FONT_BODY
	tAlert.Text = "Click minimap blocks to raid Mafia!"
	tAlert.TextSize = 10
	tAlert.TextColor3 = Color3.fromRGB(208, 220, 242)
	tAlert.TextTruncate = Enum.TextTruncate.AtEnd
	tAlert.Parent = turfCard
	turfAlertLabel = tAlert

	-- Top-Center Contextual Live Block Capture Banner (auto-shows when standing in any of the 16 Urban Block Plazas!)
	local bBanner = Instance.new("Frame")
	bBanner.Name = "ActiveBlockCaptureBanner"
	bBanner.AnchorPoint = Vector2.new(0.5, 0)
	bBanner.Position = UDim2.new(0.5, 0, 0, 116)
	bBanner.Size = UDim2.fromOffset(356, 56)
	bBanner.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
	bBanner.BackgroundTransparency = 0.08
	bBanner.Visible = false
	bBanner.Parent = gui
	makeCorner(bBanner, 12)
	makeBorderStroke(bBanner, Color3.fromRGB(246, 198, 56), 1.8)
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
			activeBlockTitle.Text = "🏙️ " .. string.upper(tostring(foundBlock.DisplayName or "BLOCK"))
		end
		if activeBlockOwnerPill then
			if foundBlock.Status == "Contested" then
				activeBlockOwnerPill.Text = "⚔️ CONTESTED"
				activeBlockOwnerPill.BackgroundColor3 = TurfConfig.ContestedColor
			else
				activeBlockOwnerPill.Text = tostring(foundBlock.OwnerName or "MAFIA")
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
				activeBlockSub.Text = "⚔️ CONTESTED! Defeat or drive out rivals in the plaza!"
			elseif prog > 0.01 then
				activeBlockSub.Text = string.format("⚡ %s CAPTURING... %d%%", tostring(foundBlock.CapturingName or "CAPTURING"), math.floor(prog * 100))
			elseif TurfConfig.IsMafiaFaction(tostring(foundBlock.Owner or "")) then
				activeBlockSub.Text = if defs > 0
					then string.format("🕶️ %d Mafia Defender(s) • Clear & hold plaza!", defs)
					else "⚡ Guards cleared! Stand in plaza to capture!"
			else
				activeBlockSub.Text = string.format("🛡️ Controlled (+%dG/20s) • %d Guard(s) on patrol", tonumber(foundBlock.IncomeGold) or 18, defs)
			end
		end
	end)

	return gui
end

function HUDController.ShowToast(message: string, isError: boolean?): ()
	if not toastLabel then
		return
	end
	toastToken += 1
	local myToken = toastToken
	toastLabel.Text = (if isError then "⚠️ " else "✨ ") .. message
	toastLabel.TextColor3 = if isError then Color3.fromRGB(255, 134, 134) else Color3.fromRGB(136, 248, 168)
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
			levelLabel.Text = string.format("Lv.%d • %d XP", profile.Level or 1, profile.EXP or 0)
		end
	end

	local slot = state.BaseSlot
	if baseBadge and typeof(slot) == "string" then
		baseBadge.Text = slot .. " Base"
		local col = SectorConfig.FactionColors[slot]
		if col and basePillFrame then
			basePillFrame.BackgroundColor3 = col
		end
	end

	local emperor = state.FoodEmperor
	if emperorBanner and typeof(emperor) == "table" then
		emperorBanner.Text = string.format("👑 Food Emperor: %s (%d Rep)", emperor.Name or "--", emperor.Reputation or 0)
	end

	local kitchen = state.Kitchen
	local waiting = state.WaitingCustomer
	if sellBadgeBtn and sellTextLabel and kitchen then
		local ready = kitchen.ReadyTotal or 0
		if ready > 0 then
			sellTextLabel.Text = string.format("Sell (%d)", ready)
			sellBadgeBtn.BackgroundColor3 = Color3.fromRGB(46, 184, 82)
		elseif typeof(waiting) == "table" and waiting.IsBeingCooked then
			sellTextLabel.Text = "Cooking!"
			sellBadgeBtn.BackgroundColor3 = Color3.fromRGB(232, 134, 38)
		elseif typeof(waiting) == "table" and waiting.CustomerName then
			sellTextLabel.Text = "Serve!"
			sellBadgeBtn.BackgroundColor3 = Color3.fromRGB(46, 184, 82)
		else
			sellTextLabel.Text = "Sell (0)"
			sellBadgeBtn.BackgroundColor3 = Color3.fromRGB(72, 82, 98)
		end
	end

	-- Pop up Printed Restaurant Receipt Ticket whenever a new order is rung up!
	local latest = state.LatestReceipt
	if typeof(latest) == "table" and typeof(latest.OrderNo) == "number" and latest.OrderNo > lastReceiptOrderNo then
		lastReceiptOrderNo = latest.OrderNo
		if receiptTicket and receiptHeaderLbl and receiptBodyLbl then
			receiptHeaderLbl.Text = string.format("RECEIPT #%d  •  PAID", latest.OrderNo)
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
		bikeTextLabel.Text = if ownsBike then "Bike" else "🔒 Bike"
	end

	local shipments = state.Shipments
	local readyShipmentCount = 0
	if typeof(shipments) == "table" then
		for sectorId, dot in pairs(sectorDots) do
			local sh = shipments[sectorId]
			local lbl = sectorStatusLabels[sectorId]
			local icon = SECTOR_ICONS[sectorId] or "•"
			if typeof(sh) == "table" then
				local shortName = if sectorId == "FishingPort" then "Fish Port"
					elseif sectorId == "VegetableFarm" then "Veg Farm"
					elseif sectorId == "FruitOrchard" then "Orchard"
					else "Ranch"
				if sh.Phase == "EnRoute" then
					dot.BackgroundColor3 = Color3.fromRGB(250, 184, 38)
					if lbl then
						lbl.Text = icon .. " " .. shortName .. ": OUT -> CTR!"
						lbl.TextColor3 = Color3.fromRGB(255, 226, 112)
					end
				elseif sh.Phase == "Arrived" then
					readyShipmentCount += 1
					dot.BackgroundColor3 = Color3.fromRGB(54, 212, 108)
					if lbl then
						lbl.Text = icon .. " " .. shortName .. ": AT CENTER!"
						lbl.TextColor3 = Color3.fromRGB(134, 248, 168)
					end
				else
					dot.BackgroundColor3 = SectorConfig.FactionColors.Neutral
					if lbl then
						lbl.Text = string.format("%s %s: %ds", icon, shortName, tonumber(sh.SecondsUntilNext) or 0)
						lbl.TextColor3 = Color3.fromRGB(224, 230, 242)
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

		if totalStock < 3 and readyDishes == 0 then
			if readyShipmentCount > 0 then
				objectiveLabel.Text = "1. Grab the arrived 🐟 Shipment in Central Plaza (Press E)!"
			else
				objectiveLabel.Text = "1. Watch Corner Shipments & head to Central Plaza to claim goods!"
			end
		elseif readyDishes > 0 then
			objectiveLabel.Text = "3. Click 🍽️ Sell Food to earn Gold, Receipt & 👑 Rep!"
		elseif rep < 20 then
			objectiveLabel.Text = "2. Open 🍳 Kitchen (C) & cook 🐟 Grilled Fish for customers!"
		elseif unlockedWh < 4 then
			objectiveLabel.Text = string.format("4. Open 📦 Storage (B) to build all 4 Warehouses (%d/4)!", unlockedWh)
		elseif restLv < 2 then
			objectiveLabel.Text = "5. Open ⬆️ Empire (U) to upgrade Restaurant, Crew & Raiders!"
		else
			objectiveLabel.Text = "👑 Control Central Shipments & reign as Food Emperor!"
		end
	end

	if vipOrderLabel then
		local vip = state.VIPOrder
		if typeof(vip) == "table" and vip.DisplayName then
			vipOrderLabel.Text = string.format(
				"Serve %s!\n+%d Gold | 👑 +%d (%ds)",
				vip.DisplayName,
				vip.BonusCoins or 0,
				vip.BonusRep or 0,
				vip.Remaining or 0
			)
		else
			vipOrderLabel.Text = "New VIP Critic Order arriving soon!"
		end
	end

	if expressOrderLabel and expressAcceptBtn then
		local exp = state.ExpressDelivery
		if typeof(exp) == "table" then
			local comboStr = if (exp.Combo or 0) > 0 then string.format(" [x%d]", exp.Combo) else ""
			if exp.Status == "Active" then
				expressOrderLabel.Text = string.format(
					"Rush %s -> %s!\n⏱ %ds left | +%dG + Tip%s",
					tostring(exp.DishName or "Meal"),
					tostring(exp.DropName or "Center"),
					tonumber(exp.Remaining) or 0,
					tonumber(exp.BaseGold) or 100,
					comboStr
				)
				expressAcceptBtn.Text = string.format("🔥 EN ROUTE (%ds)", tonumber(exp.Remaining) or 0)
				expressAcceptBtn.BackgroundColor3 = Color3.fromRGB(234, 142, 36)
			elseif exp.Status == "Available" then
				expressOrderLabel.Text = string.format(
					"%s wants %s at %s!\n+%dG + Speed Tip (%ds)%s",
					tostring(exp.CustomerName or "Guest"),
					tostring(exp.DishName or "Meal"),
					tostring(exp.DropName or "Center"),
					tonumber(exp.BaseGold) or 100,
					tonumber(exp.Duration) or 45,
					comboStr
				)
				expressAcceptBtn.Text = "🛵 Accept Express Delivery!"
				expressAcceptBtn.BackgroundColor3 = Color3.fromRGB(44, 186, 98)
			else
				expressOrderLabel.Text = string.format("Next Express Call in %ds...%s", tonumber(exp.Remaining) or 5, comboStr)
				expressAcceptBtn.Text = "⏳ Waiting for Call..."
				expressAcceptBtn.BackgroundColor3 = Color3.fromRGB(68, 78, 96)
			end
		end
	end

	-- Update Urban Turf Control Card & cache latest block states for live proximity capture banner
	local turf = state.Turf
	if typeof(turf) == "table" then
		latestTurfState = turf
		local owned = tonumber(turf.OwnedCount) or 0
		local total = tonumber(turf.TotalBlocks) or 16
		local inc = tonumber(turf.IncomePerCycle) or 0
		local mono = tonumber(turf.Monopolies) or 0
		if turfSummaryLabel then
			local monoTag = if mono > 0 then string.format(" ★%d", mono) else ""
			turfSummaryLabel.Text = string.format("Blocks: %d/%d • +%dG/20s%s", owned, total, inc, monoTag)
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
				turfAlertLabel.Text = "🚨 RAID AT " .. string.upper(underAttackName) .. "!"
				turfAlertLabel.TextColor3 = Color3.fromRGB(255, 114, 114)
			elseif owned == 0 then
				turfAlertLabel.Text = "Fight Mafia in Mid-Town blocks!"
				turfAlertLabel.TextColor3 = Color3.fromRGB(210, 224, 246)
			else
				turfAlertLabel.Text = "Capture all 4 in a quadrant for +50%!"
				turfAlertLabel.TextColor3 = Color3.fromRGB(154, 238, 192)
			end
		end
	end
end

return HUDController
