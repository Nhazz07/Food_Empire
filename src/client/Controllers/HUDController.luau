--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)
local TurfConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("TurfConfig")
)
local RestaurantSecurityConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RestaurantSecurityConfig")
)
local CurrencyIconHelper = require("./CurrencyIconHelper")

export type OpenMenuCallback = (tabName: "Kitchen" | "Warehouses" | "Upgrades" | "Shop" | "BlackMarket") -> ()
export type QuickServeCallback = () -> ()
export type ReturnHomeCallback = () -> ()
export type ToggleScooterCallback = () -> ()
export type AcceptExpressCallback = () -> ()

local HUDController = {}

local FONT_TITLE = Enum.Font.GothamBlack
local FONT_BODY = Enum.Font.GothamBold
local FONT_REG = Enum.Font.Gotham

local SECTOR_TAGS: { [string]: string } = {
	FishingPort = "FISH",
	VegetableFarm = "VEG",
	Ranch = "MEAT",
	FruitOrchard = "FRUIT",
}

-- Luxury "Noir Syndicate Bistro" Palette
local C_OBS = Color3.fromRGB(15, 18, 25)
local C_OBS_DEEP = Color3.fromRGB(11, 13, 19)
local C_INNER = Color3.fromRGB(22, 26, 36)
local C_BORDER = Color3.fromRGB(54, 60, 74)
local C_GOLD = Color3.fromRGB(212, 178, 102)
local C_GOLD_DIM = Color3.fromRGB(122, 102, 58)
local C_BONE = Color3.fromRGB(240, 238, 232)
local C_ASH = Color3.fromRGB(158, 165, 180)
local C_EMERALD = Color3.fromRGB(46, 152, 92)
local C_EMERALD_BRIGHT = Color3.fromRGB(68, 178, 112)
local C_OXBLOOD = Color3.fromRGB(152, 34, 44)
local C_CRIMSON_BG = Color3.fromRGB(46, 19, 25)
local C_STEEL = Color3.fromRGB(62, 108, 156)
local C_VIOLET = Color3.fromRGB(142, 92, 212)

local screenGui: ScreenGui? = nil
local uiScaleInst: UIScale? = nil
local coinsLabel: TextLabel? = nil
local repLabel: TextLabel? = nil
local levelLabel: TextLabel? = nil
local xpSubLabel: TextLabel? = nil
local xpBarFill: Frame? = nil
local baseBadge: TextLabel? = nil
local baseAccentBar: Frame? = nil
local emperorBanner: TextLabel? = nil
local objectiveLabel: TextLabel? = nil
local vipOrderLabel: TextLabel? = nil
local expressOrderLabel: TextLabel? = nil
local expressAcceptBtn: TextButton? = nil
local sellBadgeBtn: TextButton? = nil
local sellTextLabel: TextLabel? = nil
local bikeTextLabel: TextLabel? = nil
local bikeKeyLabel: TextLabel? = nil
local bikeBtnRef: TextButton? = nil
local toastLabel: TextLabel? = nil
local receiptTicket: Frame? = nil
local receiptHeaderLbl: TextLabel? = nil
local receiptBodyLbl: TextLabel? = nil
local turfBlocksLabel: TextLabel? = nil
local turfIncomeLabel: TextLabel? = nil
local turfProgressFill: Frame? = nil
local turfAlertLabel: TextLabel? = nil
local activeBlockBanner: Frame? = nil
local activeBlockTitle: TextLabel? = nil
local activeBlockOwnerPill: TextLabel? = nil
local activeBlockFill: Frame? = nil
local activeBlockSub: TextLabel? = nil

-- Top-Right Customer Patience Queue Card (below UrbanTurfCard)
type PatienceRowUI = {
	Row: Frame,
	NameLbl: TextLabel,
	TimeLbl: TextLabel,
	BarFill: Frame,
}
local patienceCard: Frame? = nil
local patienceCardStroke: UIStroke? = nil
local patienceHeaderLabel: TextLabel? = nil
local patienceRows: { PatienceRowUI } = {}
local latestPatienceList: { { [string]: any } } = {}
local patienceReceivedAt = 0

-- Bottom-Center Integrated Combat, Vitals & Squad Widgets
local vitalsDockFrame: Frame? = nil
local playerHpFill: Frame? = nil
local playerHpLabel: TextLabel? = nil
local playerArmorFill: Frame? = nil
local playerArmorLabel: TextLabel? = nil
local tacticalGridFrame: Frame? = nil
local actionClusterFrame: Frame? = nil
local attackBtnRef: TextButton? = nil
local recallBtnRef: TextButton? = nil
local flashBtnRef: TextButton? = nil
local flashMainLbl: TextLabel? = nil
local c4BtnRef: TextButton? = nil
local c4MainLbl: TextLabel? = nil
local dashBtnRef: TextButton? = nil
local dashMainLbl: TextLabel? = nil

local latestTurfState: { [string]: any }? = nil
local turfProximityConn: RBXScriptConnection? = nil
local vitalsConn: RBXScriptConnection? = nil
local scaleConn: RBXScriptConnection? = nil
local hotbarWidthConn: RBXScriptConnection? = nil
local sectorPills: { [string]: Frame } = {}
local sectorDots: { [string]: Frame } = {}
local sectorStatusLabels: { [string]: TextLabel } = {}
local toastToken = 0
local lastReceiptOrderNo = 0
local receiptHideToken = 0

local function formatNumber(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local formatted = string.reverse(s):gsub("(%d%d%d)", "%1,")
	formatted = string.reverse(formatted)
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	return formatted
end

local function makeCorner(parent: Instance, radius: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeBorderStroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
	return s
end

local function makeTextOutline(parent: GuiObject, thickness: number?): ()
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = Color3.fromRGB(10, 12, 18)
	s.Thickness = thickness or 1.4
	s.Transparency = 0.2
	s.Parent = parent
end

local function addSubtleGradient(parent: Instance, topCol: Color3, botCol: Color3): ()
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(topCol, botCol)
	g.Parent = parent
end

local function computeHudScale(): number
	local cam = Workspace.CurrentCamera
	if not cam then
		return 1
	end
	local vp = cam.ViewportSize
	if vp.X <= 1 or vp.Y <= 1 then
		return 1
	end
	return math.clamp(math.min(vp.X / 1360, vp.Y / 760), 0.62, 1.15)
end

local function createDockGridButton(
	parent: Instance,
	name: string,
	labelText: string,
	keyHint: string,
	bg: Color3,
	borderCol: Color3,
	accentText: Color3,
	layoutOrder: number,
	onClick: () -> ()
): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.LayoutOrder = layoutOrder
	btn.BackgroundColor3 = bg
	btn.BackgroundTransparency = 0.02
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.ClipsDescendants = true
	btn.Parent = parent
	makeCorner(btn, 8)
	local stroke = makeBorderStroke(btn, borderCol, 1.8)

	local sheen = Instance.new("Frame")
	sheen.Position = UDim2.fromOffset(3, 2)
	sheen.Size = UDim2.new(1, -6, 0, 3)
	sheen.BackgroundColor3 = Color3.new(1, 1, 1)
	sheen.BackgroundTransparency = 0.72
	sheen.BorderSizePixel = 0
	sheen.Active = false
	sheen.Parent = btn
	makeCorner(sheen, 2)

	local lip = Instance.new("Frame")
	lip.AnchorPoint = Vector2.new(0, 1)
	lip.Position = UDim2.fromScale(0, 1)
	lip.Size = UDim2.new(1, 0, 0, 4)
	lip.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	lip.BackgroundTransparency = 0.56
	lip.BorderSizePixel = 0
	lip.Active = false
	lip.Parent = btn

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Label"
	lbl.Position = UDim2.new(0, 2, 0, 8)
	lbl.Size = UDim2.new(1, -4, 0, 16)
	lbl.BackgroundTransparency = 1
	lbl.Font = FONT_TITLE
	lbl.Text = string.upper(labelText)
	lbl.TextSize = 10
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Active = false
	lbl.Parent = btn
	makeTextOutline(lbl, 1.5)

	local keyLbl = Instance.new("TextLabel")
	keyLbl.Name = "KeyCap"
	keyLbl.Position = UDim2.new(0, 2, 0, 25)
	keyLbl.Size = UDim2.new(1, -4, 0, 14)
	keyLbl.BackgroundTransparency = 1
	keyLbl.Font = FONT_TITLE
	keyLbl.Text = "[" .. keyHint .. "]"
	keyLbl.TextSize = 10
	keyLbl.TextColor3 = accentText
	keyLbl.Active = false
	keyLbl.Parent = btn
	makeTextOutline(keyLbl, 1.2)

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = bg:Lerp(Color3.new(1, 1, 1), 0.16)
		stroke.Color = Color3.new(1, 1, 1)
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = bg
		stroke.Color = borderCol
	end)
	btn.Activated:Connect(onClick)
	return btn
end

local function createTacticalTile(
	parent: Instance,
	name: string,
	titleText: string,
	keyText: string,
	bg: Color3,
	borderCol: Color3,
	keyCol: Color3,
	layoutOrder: number,
	cb: (() -> ())?
): (TextButton, TextLabel, TextLabel)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.LayoutOrder = layoutOrder
	btn.BackgroundColor3 = bg
	btn.BackgroundTransparency = 0.05
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.Parent = parent
	makeCorner(btn, 6)
	local stroke = makeBorderStroke(btn, borderCol, 1.2)

	local topLbl = Instance.new("TextLabel")
	topLbl.Name = "Title"
	topLbl.Position = UDim2.new(0, 2, 0, 5)
	topLbl.Size = UDim2.new(1, -4, 0, 14)
	topLbl.BackgroundTransparency = 1
	topLbl.Font = FONT_TITLE
	topLbl.Text = titleText
	topLbl.TextSize = 10
	topLbl.TextColor3 = C_BONE
	topLbl.Parent = btn

	local botLbl = Instance.new("TextLabel")
	botLbl.Name = "KeyLabel"
	botLbl.Position = UDim2.new(0, 2, 0, 21)
	botLbl.Size = UDim2.new(1, -4, 0, 13)
	botLbl.BackgroundTransparency = 1
	botLbl.Font = FONT_BODY
	botLbl.Text = keyText
	botLbl.TextSize = 9
	botLbl.TextColor3 = keyCol
	botLbl.Parent = btn

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = bg:Lerp(Color3.new(1, 1, 1), 0.12)
		stroke.Color = borderCol:Lerp(Color3.new(1, 1, 1), 0.2)
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = bg
		stroke.Color = borderCol
	end)
	btn.MouseButton1Click:Connect(function()
		if cb then
			cb()
		end
	end)
	return btn, topLbl, botLbl
end

local function syncBottomClusterOffsets(): ()
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local halfW = if playerGui and typeof(playerGui:GetAttribute("FoodEmpireHotbarHalfW")) == "number"
		then (playerGui:GetAttribute("FoodEmpireHotbarHalfW") :: number)
		else 207

	if vitalsDockFrame then
		vitalsDockFrame.Size = UDim2.fromOffset(math.max(360, halfW * 2), 24)
	end
	if tacticalGridFrame then
		tacticalGridFrame.Position = UDim2.new(0.5, -(halfW + 10), 1, -30)
	end
	if actionClusterFrame then
		actionClusterFrame.Position = UDim2.new(0.5, halfW + 10, 1, -30)
	end
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

	-- Viewport-responsive UIScale so ALL corners & docks stay zero-overlap from 720p/Studio up to 4K!
	local uis = Instance.new("UIScale")
	uis.Name = "ResponsiveHUDScale"
	uis.Scale = computeHudScale()
	uis.Parent = gui
	uiScaleInst = uis
	playerGui:SetAttribute("FoodEmpireHUDScale", uis.Scale)

	if scaleConn then
		scaleConn:Disconnect()
	end
	local function bindCameraResize(): ()
		local cam = Workspace.CurrentCamera
		if cam then
			local function onResize()
				local sc = computeHudScale()
				if uiScaleInst then
					uiScaleInst.Scale = sc
				end
				playerGui:SetAttribute("FoodEmpireHUDScale", sc)
			end
			onResize()
			scaleConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(onResize)
		end
	end
	bindCameraResize()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if scaleConn then
			scaleConn:Disconnect()
		end
		bindCameraResize()
	end)

	-- =========================================================================
	-- 1. TOP-CENTER: UNIFIED LUXURY OBSIDIAN-GOLD EMPIRE HEADER BAR + TICKER
	-- =========================================================================
	local topBar = Instance.new("Frame")
	topBar.Name = "TopStatsBar"
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.new(0.5, 0, 0, 8)
	topBar.Size = UDim2.fromOffset(600, 44)
	topBar.BackgroundColor3 = C_OBS
	topBar.BackgroundTransparency = 0.06
	topBar.Parent = gui
	makeCorner(topBar, 8)
	makeBorderStroke(topBar, C_GOLD, 1.3)
	addSubtleGradient(topBar, Color3.fromRGB(22, 26, 36), C_OBS_DEEP)

	local function addDivider(xOffset: number): ()
		local div = Instance.new("Frame")
		div.Position = UDim2.new(0, xOffset, 0, 8)
		div.Size = UDim2.new(0, 1, 1, -16)
		div.BackgroundColor3 = C_BORDER
		div.BorderSizePixel = 0
		div.Parent = topBar
	end

	-- Segment 1: Base Slot (0..154)
	local segBase = Instance.new("Frame")
	segBase.Name = "BaseSlot"
	segBase.Position = UDim2.new(0, 0, 0, 0)
	segBase.Size = UDim2.new(0, 154, 1, 0)
	segBase.BackgroundTransparency = 1
	segBase.Parent = topBar

	local bStrip = Instance.new("Frame")
	bStrip.Name = "AccentStrip"
	bStrip.Position = UDim2.new(0, 8, 0.5, -11)
	bStrip.Size = UDim2.fromOffset(4, 22)
	bStrip.BackgroundColor3 = C_GOLD
	bStrip.BorderSizePixel = 0
	bStrip.Parent = segBase
	makeCorner(bStrip, 2)
	baseAccentBar = bStrip

	local baseIcon = Instance.new("TextLabel")
	baseIcon.Position = UDim2.new(0, 17, 0.5, -11)
	baseIcon.Size = UDim2.fromOffset(22, 22)
	baseIcon.BackgroundColor3 = C_INNER
	baseIcon.Font = FONT_TITLE
	baseIcon.Text = "HQ"
	baseIcon.TextSize = 9
	baseIcon.TextColor3 = C_GOLD
	baseIcon.Parent = segBase
	makeCorner(baseIcon, 5)
	makeBorderStroke(baseIcon, C_GOLD_DIM, 1)

	local bLbl = Instance.new("TextLabel")
	bLbl.Name = "ValueText"
	bLbl.Position = UDim2.new(0, 45, 0, 0)
	bLbl.Size = UDim2.new(1, -50, 1, 0)
	bLbl.BackgroundTransparency = 1
	bLbl.Font = FONT_TITLE
	bLbl.Text = "BASE: --"
	bLbl.TextSize = 12
	bLbl.TextXAlignment = Enum.TextXAlignment.Left
	bLbl.TextColor3 = C_BONE
	bLbl.TextTruncate = Enum.TextTruncate.AtEnd
	bLbl.Parent = segBase
	baseBadge = bLbl
	addDivider(154)

	-- Segment 2: Gold Coins (154..292) with gleaming 24K vector Gold Coin icon!
	local segGold = Instance.new("Frame")
	segGold.Name = "Coins"
	segGold.Position = UDim2.new(0, 154, 0, 0)
	segGold.Size = UDim2.new(0, 138, 1, 0)
	segGold.BackgroundTransparency = 1
	segGold.Parent = topBar

	CurrencyIconHelper.CreateGoldCoin(segGold, 24, UDim2.new(0, 11, 0.5, -12), 4)

	local cLbl = Instance.new("TextLabel")
	cLbl.Name = "ValueText"
	cLbl.Position = UDim2.new(0, 41, 0, 0)
	cLbl.Size = UDim2.new(1, -46, 1, 0)
	cLbl.BackgroundTransparency = 1
	cLbl.Font = FONT_TITLE
	cLbl.Text = "90"
	cLbl.TextSize = 14
	cLbl.TextXAlignment = Enum.TextXAlignment.Left
	cLbl.TextColor3 = Color3.fromRGB(252, 224, 132)
	cLbl.Parent = segGold
	coinsLabel = cLbl
	addDivider(292)

	-- Segment 3: Level + Integrated XP Progress Bar (292..448)
	local segLvl = Instance.new("Frame")
	segLvl.Name = "Level"
	segLvl.Position = UDim2.new(0, 292, 0, 0)
	segLvl.Size = UDim2.new(0, 156, 1, 0)
	segLvl.BackgroundTransparency = 1
	segLvl.Parent = topBar

	local lvBadge = Instance.new("TextLabel")
	lvBadge.Position = UDim2.new(0, 12, 0.5, -11)
	lvBadge.Size = UDim2.fromOffset(22, 22)
	lvBadge.BackgroundColor3 = Color3.fromRGB(48, 36, 78)
	lvBadge.Font = FONT_TITLE
	lvBadge.Text = "LV"
	lvBadge.TextSize = 9
	lvBadge.TextColor3 = C_GOLD
	lvBadge.Parent = segLvl
	makeCorner(lvBadge, 5)
	makeBorderStroke(lvBadge, C_VIOLET, 1)

	local lLbl = Instance.new("TextLabel")
	lLbl.Name = "ValueText"
	lLbl.Position = UDim2.new(0, 42, 0, 4)
	lLbl.Size = UDim2.new(1, -48, 0, 15)
	lLbl.BackgroundTransparency = 1
	lLbl.Font = FONT_TITLE
	lLbl.Text = "LV. 1"
	lLbl.TextSize = 12
	lLbl.TextXAlignment = Enum.TextXAlignment.Left
	lLbl.TextColor3 = C_BONE
	lLbl.Parent = segLvl
	levelLabel = lLbl

	local xpBg = Instance.new("Frame")
	xpBg.Position = UDim2.new(0, 42, 0, 22)
	xpBg.Size = UDim2.new(1, -54, 0, 5)
	xpBg.BackgroundColor3 = C_OBS_DEEP
	xpBg.BorderSizePixel = 0
	xpBg.Parent = segLvl
	makeCorner(xpBg, 3)

	local xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.fromScale(0.15, 1)
	xpFill.BackgroundColor3 = C_VIOLET
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpBg
	makeCorner(xpFill, 3)
	xpBarFill = xpFill

	local xpLbl = Instance.new("TextLabel")
	xpLbl.Position = UDim2.new(0, 42, 0, 28)
	xpLbl.Size = UDim2.new(1, -48, 0, 12)
	xpLbl.BackgroundTransparency = 1
	xpLbl.Font = FONT_BODY
	xpLbl.Text = "0 XP"
	xpLbl.TextSize = 9
	xpLbl.TextXAlignment = Enum.TextXAlignment.Left
	xpLbl.TextColor3 = C_ASH
	xpLbl.Parent = segLvl
	xpSubLabel = xpLbl
	addDivider(448)

	-- Segment 4: Reputation (448..600)
	local segRep = Instance.new("Frame")
	segRep.Name = "Reputation"
	segRep.Position = UDim2.new(0, 448, 0, 0)
	segRep.Size = UDim2.new(0, 152, 1, 0)
	segRep.BackgroundTransparency = 1
	segRep.Parent = topBar

	local repBadge = Instance.new("TextLabel")
	repBadge.Position = UDim2.new(0, 12, 0.5, -11)
	repBadge.Size = UDim2.fromOffset(22, 22)
	repBadge.BackgroundColor3 = C_CRIMSON_BG
	repBadge.Font = FONT_TITLE
	repBadge.Text = "R"
	repBadge.TextSize = 11
	repBadge.TextColor3 = Color3.fromRGB(228, 92, 102)
	repBadge.Parent = segRep
	makeCorner(repBadge, 5)
	makeBorderStroke(repBadge, C_OXBLOOD, 1)

	local rLbl = Instance.new("TextLabel")
	rLbl.Name = "ValueText"
	rLbl.Position = UDim2.new(0, 41, 0, 0)
	rLbl.Size = UDim2.new(1, -46, 1, 0)
	rLbl.BackgroundTransparency = 1
	rLbl.Font = FONT_TITLE
	rLbl.Text = "0 REP"
	rLbl.TextSize = 13
	rLbl.TextXAlignment = Enum.TextXAlignment.Left
	rLbl.TextColor3 = C_BONE
	rLbl.Parent = segRep
	repLabel = rLbl

	-- Slim Dual Sub-Ticker directly below Header Bar (Rank/Bistro Pill + Active Event Pill)
	local tickerRow = Instance.new("Frame")
	tickerRow.Name = "TopSubTicker"
	tickerRow.AnchorPoint = Vector2.new(0.5, 0)
	tickerRow.Position = UDim2.new(0.5, 0, 0, 56)
	tickerRow.Size = UDim2.fromOffset(640, 22)
	tickerRow.BackgroundTransparency = 1
	tickerRow.Parent = gui

	local tickerLayout = Instance.new("UIListLayout")
	tickerLayout.FillDirection = Enum.FillDirection.Horizontal
	tickerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tickerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tickerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tickerLayout.Padding = UDim.new(0, 8)
	tickerLayout.Parent = tickerRow

	local emp = Instance.new("TextLabel")
	emp.Name = "FoodEmperorBanner"
	emp.LayoutOrder = 1
	emp.AutomaticSize = Enum.AutomaticSize.X
	emp.Size = UDim2.fromOffset(0, 22)
	emp.BackgroundColor3 = C_OBS
	emp.BackgroundTransparency = 0.08
	emp.Font = FONT_BODY
	emp.Text = "STREET RUNNER  |  1-STAR BISTRO"
	emp.TextSize = 10
	emp.TextColor3 = C_BONE
	emp.Parent = tickerRow
	makeCorner(emp, 5)
	makeBorderStroke(emp, C_BORDER, 1)
	local empPad = Instance.new("UIPadding")
	empPad.PaddingLeft = UDim.new(0, 10)
	empPad.PaddingRight = UDim.new(0, 10)
	empPad.Parent = emp
	emperorBanner = emp

	local evBanner = Instance.new("TextLabel")
	evBanner.Name = "ActiveEventBanner"
	evBanner.LayoutOrder = 2
	evBanner.AutomaticSize = Enum.AutomaticSize.X
	evBanner.Size = UDim2.fromOffset(0, 22)
	evBanner.BackgroundColor3 = C_CRIMSON_BG
	evBanner.BackgroundTransparency = 0.06
	evBanner.Font = FONT_TITLE
	evBanner.TextSize = 10
	evBanner.TextColor3 = C_GOLD
	evBanner.Parent = tickerRow
	makeCorner(evBanner, 5)
	makeBorderStroke(evBanner, C_OXBLOOD, 1)
	local evPad = Instance.new("UIPadding")
	evPad.PaddingLeft = UDim.new(0, 10)
	evPad.PaddingRight = UDim.new(0, 10)
	evPad.Parent = evBanner

	local function refreshEventText()
		local title = ReplicatedStorage:GetAttribute("ActiveEventTitle")
		evBanner.Text = string.upper(if typeof(title) == "string" then title else "CENTRAL MARKET OPEN")
	end
	refreshEventText()
	ReplicatedStorage:GetAttributeChangedSignal("ActiveEventTitle"):Connect(refreshEventText)

	-- =========================================================================
	-- 2. LEFT SIDEBAR: COMPACT 2x2 SHIPMENTS + UNIFIED ACTIVE ORDERS (COLLAPSIBLE!)
	-- =========================================================================
	local leftRail = Instance.new("Frame")
	leftRail.Name = "LeftOpsRail"
	leftRail.Position = UDim2.new(0, 14, 0, 62)
	leftRail.Size = UDim2.fromOffset(220, 410)
	leftRail.BackgroundTransparency = 1
	leftRail.Parent = gui

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.FillDirection = Enum.FillDirection.Vertical
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.Padding = UDim.new(0, 8)
	leftLayout.Parent = leftRail

	-- Card 1: Compact 2x2 Corner Shipments
	local terrPanel = Instance.new("Frame")
	terrPanel.Name = "TerritoryStrip"
	terrPanel.LayoutOrder = 1
	terrPanel.Size = UDim2.fromOffset(220, 88)
	terrPanel.BackgroundColor3 = C_OBS
	terrPanel.BackgroundTransparency = 0.08
	terrPanel.Parent = leftRail
	makeCorner(terrPanel, 8)
	makeBorderStroke(terrPanel, C_GOLD_DIM, 1.1)

	local terrHeader = Instance.new("TextLabel")
	terrHeader.Position = UDim2.new(0, 10, 0, 5)
	terrHeader.Size = UDim2.new(1, -38, 0, 16)
	terrHeader.BackgroundTransparency = 1
	terrHeader.Font = FONT_TITLE
	terrHeader.Text = "MAFIA SHIPMENTS"
	terrHeader.TextSize = 10
	terrHeader.TextXAlignment = Enum.TextXAlignment.Left
	terrHeader.TextColor3 = C_GOLD
	terrHeader.Parent = terrPanel

	local shipGrid = Instance.new("Frame")
	shipGrid.Position = UDim2.new(0, 8, 0, 25)
	shipGrid.Size = UDim2.new(1, -16, 0, 56)
	shipGrid.BackgroundTransparency = 1
	shipGrid.Parent = terrPanel

	local shipGridLayout = Instance.new("UIGridLayout")
	shipGridLayout.CellSize = UDim2.fromOffset(99, 25)
	shipGridLayout.CellPadding = UDim2.fromOffset(6, 5)
	shipGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	shipGridLayout.Parent = shipGrid

	local sectorOrder = { "FishingPort", "VegetableFarm", "FruitOrchard", "Ranch" }
	for idx, sectorId in ipairs(sectorOrder) do
		local tag = SECTOR_TAGS[sectorId] or "SEC"
		local pill = Instance.new("Frame")
		pill.Name = "ShipPill_" .. sectorId
		pill.LayoutOrder = idx
		pill.BackgroundColor3 = C_INNER
		pill.BackgroundTransparency = 0.08
		pill.Parent = shipGrid
		makeCorner(pill, 5)
		makeBorderStroke(pill, C_BORDER, 1)
		sectorPills[sectorId] = pill

		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(7, 7)
		dot.Position = UDim2.new(0, 7, 0.5, -3)
		dot.BackgroundColor3 = SectorConfig.FactionColors.Neutral
		dot.BorderSizePixel = 0
		dot.Parent = pill
		makeCorner(dot, 4)
		sectorDots[sectorId] = dot

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Position = UDim2.new(0, 18, 0, 0)
		nameLbl.Size = UDim2.new(1, -22, 1, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = FONT_BODY
		nameLbl.Text = tag .. " • --"
		nameLbl.TextSize = 9
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextColor3 = C_ASH
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Parent = pill
		sectorStatusLabels[sectorId] = nameLbl
	end

	-- Card 2: Unified Active Orders Card (Objective + VIP Critic + Express Delivery)
	local ordersPanel = Instance.new("Frame")
	ordersPanel.Name = "ActiveOrdersCard"
	ordersPanel.LayoutOrder = 2
	ordersPanel.Size = UDim2.fromOffset(220, 294)
	ordersPanel.BackgroundColor3 = C_OBS
	ordersPanel.BackgroundTransparency = 0.08
	ordersPanel.Parent = leftRail
	makeCorner(ordersPanel, 8)
	makeBorderStroke(ordersPanel, C_GOLD_DIM, 1.1)

	local ordersHeader = Instance.new("TextLabel")
	ordersHeader.Position = UDim2.new(0, 10, 0, 5)
	ordersHeader.Size = UDim2.new(1, -40, 0, 16)
	ordersHeader.BackgroundTransparency = 1
	ordersHeader.Font = FONT_TITLE
	ordersHeader.Text = "ACTIVE ORDERS"
	ordersHeader.TextSize = 10
	ordersHeader.TextXAlignment = Enum.TextXAlignment.Left
	ordersHeader.TextColor3 = C_GOLD
	ordersHeader.Parent = ordersPanel

	local ordersBody = Instance.new("Frame")
	ordersBody.Name = "Body"
	ordersBody.Position = UDim2.new(0, 8, 0, 25)
	ordersBody.Size = UDim2.new(1, -16, 1, -33)
	ordersBody.BackgroundTransparency = 1
	ordersBody.Parent = ordersPanel

	-- Collapse toggle button on Active Orders (minimizes during combat!)
	local ordersCollapsed = false
	local collapseOrdersBtn = Instance.new("TextButton")
	collapseOrdersBtn.Name = "CollapseBtn"
	collapseOrdersBtn.AnchorPoint = Vector2.new(1, 0)
	collapseOrdersBtn.Position = UDim2.new(1, -7, 0, 4)
	collapseOrdersBtn.Size = UDim2.fromOffset(20, 18)
	collapseOrdersBtn.BackgroundColor3 = C_INNER
	collapseOrdersBtn.Font = FONT_TITLE
	collapseOrdersBtn.Text = "−"
	collapseOrdersBtn.TextSize = 12
	collapseOrdersBtn.TextColor3 = C_ASH
	collapseOrdersBtn.Parent = ordersPanel
	makeCorner(collapseOrdersBtn, 4)
	makeBorderStroke(collapseOrdersBtn, C_BORDER, 1)
	collapseOrdersBtn.MouseButton1Click:Connect(function()
		ordersCollapsed = not ordersCollapsed
		ordersBody.Visible = not ordersCollapsed
		ordersPanel.Size = UDim2.fromOffset(220, if ordersCollapsed then 26 else 294)
		collapseOrdersBtn.Text = if ordersCollapsed then "+" else "−"
	end)

	-- Also allow collapsing Shipments cleanly
	local shipCollapsed = false
	local collapseShipBtn = Instance.new("TextButton")
	collapseShipBtn.Name = "CollapseBtn"
	collapseShipBtn.AnchorPoint = Vector2.new(1, 0)
	collapseShipBtn.Position = UDim2.new(1, -7, 0, 4)
	collapseShipBtn.Size = UDim2.fromOffset(20, 18)
	collapseShipBtn.BackgroundColor3 = C_INNER
	collapseShipBtn.Font = FONT_TITLE
	collapseShipBtn.Text = "−"
	collapseShipBtn.TextSize = 12
	collapseShipBtn.TextColor3 = C_ASH
	collapseShipBtn.Parent = terrPanel
	makeCorner(collapseShipBtn, 4)
	makeBorderStroke(collapseShipBtn, C_BORDER, 1)
	collapseShipBtn.MouseButton1Click:Connect(function()
		shipCollapsed = not shipCollapsed
		shipGrid.Visible = not shipCollapsed
		terrPanel.Size = UDim2.fromOffset(220, if shipCollapsed then 26 else 88)
		collapseShipBtn.Text = if shipCollapsed then "+" else "−"
	end)

	local function makeOrderSection(name: string, yPos: number, height: number, title: string): Frame
		local sec = Instance.new("Frame")
		sec.Name = name
		sec.Position = UDim2.new(0, 0, 0, yPos)
		sec.Size = UDim2.new(1, 0, 0, height)
		sec.BackgroundColor3 = C_INNER
		sec.BackgroundTransparency = 0.08
		sec.Parent = ordersBody
		makeCorner(sec, 6)
		makeBorderStroke(sec, C_BORDER, 1)

		local hdr = Instance.new("TextLabel")
		hdr.Position = UDim2.new(0, 8, 0, 4)
		hdr.Size = UDim2.new(1, -16, 0, 14)
		hdr.BackgroundTransparency = 1
		hdr.Font = FONT_TITLE
		hdr.Text = title
		hdr.TextSize = 9
		hdr.TextXAlignment = Enum.TextXAlignment.Left
		hdr.TextColor3 = C_GOLD
		hdr.Parent = sec
		return sec
	end

	-- Section A: Objective
	local objSec = makeOrderSection("ObjectivePanel", 0, 76, "OBJECTIVE")
	local goalTxt = Instance.new("TextLabel")
	goalTxt.Position = UDim2.new(0, 8, 0, 19)
	goalTxt.Size = UDim2.new(1, -16, 1, -23)
	goalTxt.BackgroundTransparency = 1
	goalTxt.Font = FONT_REG
	goalTxt.TextWrapped = true
	goalTxt.TextXAlignment = Enum.TextXAlignment.Left
	goalTxt.TextYAlignment = Enum.TextYAlignment.Top
	goalTxt.TextSize = 10
	goalTxt.TextColor3 = C_BONE
	goalTxt.Text = "Steal a Mafia Seafood & Fish Shipment at Central Park [E] to supply your Seafood Warehouse."
	goalTxt.Parent = objSec
	objectiveLabel = goalTxt

	-- Section B: VIP Critic
	local vipSec = makeOrderSection("VIPOrderPanel", 82, 58, "VIP CRITIC")
	local vipTxt = Instance.new("TextLabel")
	vipTxt.Position = UDim2.new(0, 8, 0, 19)
	vipTxt.Size = UDim2.new(1, -16, 1, -23)
	vipTxt.BackgroundTransparency = 1
	vipTxt.Font = FONT_REG
	vipTxt.TextWrapped = true
	vipTxt.TextXAlignment = Enum.TextXAlignment.Left
	vipTxt.TextYAlignment = Enum.TextYAlignment.Top
	vipTxt.TextSize = 10
	vipTxt.TextColor3 = C_BONE
	vipTxt.Text = "Waiting for VIP Critic..."
	vipTxt.Parent = vipSec
	vipOrderLabel = vipTxt

	-- Section C: Express Delivery + Emerald ACCEPT EXPRESS Button
	local expSec = makeOrderSection("ExpressDeliveryPanel", 146, 115, "EXPRESS DELIVERY")
	local expTxt = Instance.new("TextLabel")
	expTxt.Position = UDim2.new(0, 8, 0, 19)
	expTxt.Size = UDim2.new(1, -16, 0, 56)
	expTxt.BackgroundTransparency = 1
	expTxt.Font = FONT_REG
	expTxt.TextWrapped = true
	expTxt.TextXAlignment = Enum.TextXAlignment.Left
	expTxt.TextYAlignment = Enum.TextYAlignment.Top
	expTxt.TextSize = 10
	expTxt.TextColor3 = C_BONE
	expTxt.Text = "Express dispatch pending..."
	expTxt.Parent = expSec
	expressOrderLabel = expTxt

	local expBtn = Instance.new("TextButton")
	expBtn.Name = "AcceptExpressBtn"
	expBtn.Position = UDim2.new(0, 8, 1, -33)
	expBtn.Size = UDim2.new(1, -16, 0, 26)
	expBtn.BackgroundColor3 = C_EMERALD
	expBtn.AutoButtonColor = false
	expBtn.Font = FONT_TITLE
	expBtn.Text = "ACCEPT EXPRESS"
	expBtn.TextSize = 10
	expBtn.TextColor3 = Color3.new(1, 1, 1)
	expBtn.Parent = expSec
	makeCorner(expBtn, 5)
	makeBorderStroke(expBtn, C_EMERALD_BRIGHT, 1)
	expBtn.MouseButton1Click:Connect(function()
		if onAcceptExpress then
			onAcceptExpress()
		end
	end)
	expressAcceptBtn = expBtn

	-- =========================================================================
	-- 3. BOTTOM-LEFT: CLEAN 2x3 EMPIRE MENU DOCK (ZERO OVERLAP!)
	-- =========================================================================
	local menuDock = Instance.new("Frame")
	menuDock.Name = "BottomDock"
	menuDock.AnchorPoint = Vector2.new(0, 1)
	menuDock.Position = UDim2.new(0, 14, 1, -14)
	menuDock.Size = UDim2.fromOffset(224, 136)
	menuDock.BackgroundColor3 = Color3.fromRGB(14, 20, 34)
	menuDock.BackgroundTransparency = 0.04
	menuDock.ZIndex = 12
	menuDock.Parent = gui
	makeCorner(menuDock, 10)
	makeBorderStroke(menuDock, C_GOLD, 1.8)

	local dockTitle = Instance.new("TextLabel")
	dockTitle.Position = UDim2.new(0, 0, 0, 4)
	dockTitle.Size = UDim2.new(1, 0, 0, 14)
	dockTitle.BackgroundTransparency = 1
	dockTitle.Font = FONT_TITLE
	dockTitle.Text = "EMPIRE MENU DOCK"
	dockTitle.TextSize = 9
	dockTitle.TextColor3 = Color3.fromRGB(255, 224, 94)
	dockTitle.Parent = menuDock
	makeTextOutline(dockTitle, 1.2)

	local dockGrid = Instance.new("Frame")
	dockGrid.Position = UDim2.new(0, 8, 0, 21)
	dockGrid.Size = UDim2.new(1, -16, 1, -28)
	dockGrid.BackgroundTransparency = 1
	dockGrid.Parent = menuDock

	local dockGridLayout = Instance.new("UIGridLayout")
	dockGridLayout.CellSize = UDim2.fromOffset(65, 50)
	dockGridLayout.CellPadding = UDim2.fromOffset(6, 6)
	dockGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dockGridLayout.Parent = dockGrid

	createDockGridButton(dockGrid, "BaseBtn", "Base", "H", Color3.fromRGB(40, 48, 72), C_GOLD, Color3.fromRGB(255, 224, 94), 1, function()
		if onReturnHome then
			onReturnHome()
		end
	end)
	createDockGridButton(dockGrid, "KitchenBtn", "Kitchen", "C", Color3.fromRGB(186, 102, 16), Color3.fromRGB(252, 186, 56), Color3.fromRGB(255, 236, 172), 2, function()
		onOpenMenu("Kitchen")
	end)
	createDockGridButton(dockGrid, "WarehouseBtn", "Storage", "B", Color3.fromRGB(20, 104, 174), Color3.fromRGB(56, 189, 248), Color3.fromRGB(196, 238, 255), 3, function()
		onOpenMenu("Warehouses")
	end)
	createDockGridButton(dockGrid, "UpgradeBtn", "Empire", "U", Color3.fromRGB(154, 112, 16), Color3.fromRGB(250, 204, 21), Color3.fromRGB(255, 240, 172), 4, function()
		onOpenMenu("Upgrades")
	end)
	createDockGridButton(dockGrid, "BlackMarketBtn", "Market", "M", Color3.fromRGB(158, 22, 48), Color3.fromRGB(244, 63, 94), Color3.fromRGB(255, 192, 204), 5, function()
		onOpenMenu("BlackMarket")
	end)
	createDockGridButton(dockGrid, "RobuxShopBtn", "Store", "P", Color3.fromRGB(16, 128, 68), Color3.fromRGB(52, 211, 153), Color3.fromRGB(196, 255, 224), 6, function()
		onOpenMenu("Shop")
	end)

	-- =========================================================================
	-- 4. BOTTOM-CENTER: DUAL HP/ARMOR BAR + LEFT 2x2 TACTICAL GRID + RIGHT SERVE/SQUAD
	-- =========================================================================
	local vitalsDock = Instance.new("Frame")
	vitalsDock.Name = "BottomVitalsDock"
	vitalsDock.AnchorPoint = Vector2.new(0.5, 1)
	vitalsDock.Position = UDim2.new(0.5, 0, 1, -122)
	vitalsDock.Size = UDim2.fromOffset(414, 24)
	vitalsDock.BackgroundTransparency = 1
	vitalsDock.Parent = gui
	vitalsDockFrame = vitalsDock

	-- Left half: HP Bar
	local hpPill = Instance.new("Frame")
	hpPill.Name = "PlayerHUDHealthBar"
	hpPill.Position = UDim2.new(0, 0, 0, 0)
	hpPill.Size = UDim2.new(0.5, -3, 1, 0)
	hpPill.BackgroundColor3 = C_OBS_DEEP
	hpPill.ClipsDescendants = true
	hpPill.Parent = vitalsDock
	makeCorner(hpPill, 6)
	makeBorderStroke(hpPill, C_BORDER, 1.2)

	local hpFill = Instance.new("Frame")
	hpFill.Name = "Fill"
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = C_EMERALD
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpPill
	makeCorner(hpFill, 5)
	playerHpFill = hpFill

	local hpLbl = Instance.new("TextLabel")
	hpLbl.Size = UDim2.fromScale(1, 1)
	hpLbl.BackgroundTransparency = 1
	hpLbl.Font = FONT_TITLE
	hpLbl.Text = "100 / 100 HP"
	hpLbl.TextSize = 11
	hpLbl.TextColor3 = Color3.new(1, 1, 1)
	hpLbl.ZIndex = 3
	hpLbl.Parent = hpPill
	makeTextOutline(hpLbl, 1.1)
	playerHpLabel = hpLbl

	-- Right half: Armor Bar
	local armorPill = Instance.new("Frame")
	armorPill.Name = "PlayerHUDArmorBar"
	armorPill.Position = UDim2.new(0.5, 3, 0, 0)
	armorPill.Size = UDim2.new(0.5, -3, 1, 0)
	armorPill.BackgroundColor3 = C_OBS_DEEP
	armorPill.ClipsDescendants = true
	armorPill.Parent = vitalsDock
	makeCorner(armorPill, 6)
	makeBorderStroke(armorPill, C_BORDER, 1.2)

	local arFill = Instance.new("Frame")
	arFill.Name = "Fill"
	arFill.Size = UDim2.fromScale(0, 1)
	arFill.BackgroundColor3 = C_STEEL
	arFill.BorderSizePixel = 0
	arFill.Parent = armorPill
	makeCorner(arFill, 5)
	playerArmorFill = arFill

	local arLbl = Instance.new("TextLabel")
	arLbl.Size = UDim2.fromScale(1, 1)
	arLbl.BackgroundTransparency = 1
	arLbl.Font = FONT_BODY
	arLbl.Text = "0 / 100 ARMOR"
	arLbl.TextSize = 10
	arLbl.TextColor3 = Color3.fromRGB(210, 216, 228)
	arLbl.ZIndex = 3
	arLbl.Parent = armorPill
	makeTextOutline(arLbl, 1.0)
	playerArmorLabel = arLbl

	-- Left of Hotbar: 2x2 Tactical Grid (C4 [7], FLASH [6], DASH [8], BIKE [V])
	local tacGrid = Instance.new("Frame")
	tacGrid.Name = "SquadTacticalCommandBar"
	tacGrid.AnchorPoint = Vector2.new(1, 1)
	tacGrid.Position = UDim2.new(0.5, -217, 1, -30)
	tacGrid.Size = UDim2.fromOffset(128, 86)
	tacGrid.BackgroundTransparency = 1
	tacGrid.Parent = gui
	tacticalGridFrame = tacGrid

	local tacLayout = Instance.new("UIGridLayout")
	tacLayout.CellSize = UDim2.fromOffset(61, 40)
	tacLayout.CellPadding = UDim2.fromOffset(6, 6)
	tacLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tacLayout.Parent = tacGrid

	local c4Btn, c4Top = createTacticalTile(tacGrid, "GadgetC4Btn", "C4", "[7]", C_OBS, C_BORDER, C_GOLD, 1, onDeployC4)
	c4BtnRef = c4Btn
	c4MainLbl = c4Top
	c4Btn:SetAttribute("IsGadgetBtn", "C4")

	local flashBtn, flashTop = createTacticalTile(tacGrid, "GadgetFlashBtn", "FLASH", "[6]", C_OBS, C_BORDER, C_GOLD, 2, onThrowFlashbang)
	flashBtnRef = flashBtn
	flashMainLbl = flashTop
	flashBtn:SetAttribute("IsGadgetBtn", "Flash")

	local dashBtn, dashTop = createTacticalTile(tacGrid, "GadgetDashBtn", "DASH", "[8]", C_OBS, C_BORDER, C_ASH, 3, onTriggerShadowDash)
	dashBtnRef = dashBtn
	dashMainLbl = dashTop
	dashBtn:SetAttribute("IsGadgetBtn", "Dash")

	local bikeBtn, bikeTop, bikeKey = createTacticalTile(tacGrid, "ScooterBtn", "BIKE", "[V]", C_OBS, C_BORDER, C_ASH, 4, onToggleScooter)
	bikeBtnRef = bikeBtn
	bikeTextLabel = bikeTop
	bikeKeyLabel = bikeKey

	gui:SetAttribute("HasGadgetStrip", true)

	-- Right of Hotbar: Prominent Emerald SERVE + Compact ATTACK [Y] & RECALL [Z]
	local actCluster = Instance.new("Frame")
	actCluster.Name = "ActionSquadCluster"
	actCluster.AnchorPoint = Vector2.new(0, 1)
	actCluster.Position = UDim2.new(0.5, 217, 1, -30)
	actCluster.Size = UDim2.fromOffset(146, 86)
	actCluster.BackgroundTransparency = 1
	actCluster.Parent = gui
	actionClusterFrame = actCluster

	local sBtn = Instance.new("TextButton")
	sBtn.Name = "SellBtn"
	sBtn.Position = UDim2.new(0, 0, 0, 0)
	sBtn.Size = UDim2.fromOffset(146, 42)
	sBtn.BackgroundColor3 = C_EMERALD
	sBtn.AutoButtonColor = false
	sBtn.Text = ""
	sBtn.Parent = actCluster
	makeCorner(sBtn, 6)
	makeBorderStroke(sBtn, C_EMERALD_BRIGHT, 1.3)

	local sLbl = Instance.new("TextLabel")
	sLbl.Name = "Label"
	sLbl.Size = UDim2.fromScale(1, 1)
	sLbl.BackgroundTransparency = 1
	sLbl.Font = FONT_TITLE
	sLbl.Text = "SERVE"
	sLbl.TextSize = 14
	sLbl.TextColor3 = Color3.new(1, 1, 1)
	sLbl.Parent = sBtn
	makeTextOutline(sLbl, 1.0)

	sBtn.MouseButton1Click:Connect(onQuickServe)
	sellBadgeBtn = sBtn
	sellTextLabel = sLbl

	local function makeSquadPill(name: string, xPos: number, title: string, keyStr: string, bg: Color3, borderCol: Color3, keyCol: Color3, cb: (() -> ())?): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.Position = UDim2.new(0, xPos, 0, 48)
		b.Size = UDim2.fromOffset(70, 38)
		b.BackgroundColor3 = bg
		b.AutoButtonColor = false
		b.Text = ""
		b.Parent = actCluster
		makeCorner(b, 6)
		local st = makeBorderStroke(b, borderCol, 1.2)

		local t1 = Instance.new("TextLabel")
		t1.Position = UDim2.new(0, 2, 0, 4)
		t1.Size = UDim2.new(1, -4, 0, 14)
		t1.BackgroundTransparency = 1
		t1.Font = FONT_TITLE
		t1.Text = title
		t1.TextSize = 10
		t1.TextColor3 = C_BONE
		t1.Parent = b

		local t2 = Instance.new("TextLabel")
		t2.Position = UDim2.new(0, 2, 0, 20)
		t2.Size = UDim2.new(1, -4, 0, 13)
		t2.BackgroundTransparency = 1
		t2.Font = FONT_BODY
		t2.Text = keyStr
		t2.TextSize = 9
		t2.TextColor3 = keyCol
		t2.Parent = b

		b.MouseEnter:Connect(function()
			b.BackgroundColor3 = bg:Lerp(Color3.new(1, 1, 1), 0.12)
			st.Color = borderCol:Lerp(Color3.new(1, 1, 1), 0.2)
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundColor3 = bg
			st.Color = borderCol
		end)
		b.MouseButton1Click:Connect(function()
			if cb then
				cb()
			end
		end)
		return b
	end

	attackBtnRef = makeSquadPill("SquadAttackBtn", 0, "ATTACK", "[Y]", C_CRIMSON_BG, C_OXBLOOD, Color3.fromRGB(238, 120, 126), onSquadAttack)
	recallBtnRef = makeSquadPill("SquadRecallBtn", 76, "RECALL", "[Z]", Color3.fromRGB(24, 32, 46), C_STEEL, Color3.fromRGB(168, 198, 232), onSquadRecall)

	-- Clean Dark Translucent Controls Hint Pill tucked neatly below the Hotbar
	local hintStrip = Instance.new("TextLabel")
	hintStrip.Name = "ControlsHint"
	hintStrip.AnchorPoint = Vector2.new(0.5, 1)
	hintStrip.Position = UDim2.new(0.5, 0, 1, -6)
	hintStrip.Size = UDim2.fromOffset(414, 18)
	hintStrip.BackgroundColor3 = C_OBS_DEEP
	hintStrip.BackgroundTransparency = 0.14
	hintStrip.Font = FONT_BODY
	hintStrip.Text = "[1-5] Equip   •   [RMB] Aim   •   [Ctrl] Crouch   •   [Shift] Sprint"
	hintStrip.TextSize = 9
	hintStrip.TextColor3 = Color3.fromRGB(194, 198, 208)
	hintStrip.Parent = gui
	makeCorner(hintStrip, 5)
	makeBorderStroke(hintStrip, C_BORDER, 0.8)

	-- Dynamically keep flanking docks aligned whenever Hotbar slot count changes (5..9 slots)
	if hotbarWidthConn then
		hotbarWidthConn:Disconnect()
	end
	hotbarWidthConn = playerGui:GetAttributeChangedSignal("FoodEmpireHotbarHalfW"):Connect(syncBottomClusterOffsets)
	syncBottomClusterOffsets()

	-- Live Player HP & Armor Bar updater (synced cleanly on Heartbeat)
	if vitalsConn then
		vitalsConn:Disconnect()
	end
	vitalsConn = RunService.Heartbeat:Connect(function()
		local char = Players.LocalPlayer.Character
		local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		if char and hum and playerHpFill and playerHpLabel then
			local baseHp = math.clamp(math.ceil(hum.Health), 0, 100)
			local armorAttr = char:GetAttribute("Armor")
			local armor = if typeof(armorAttr) == "number"
				then math.clamp(math.floor(armorAttr), 0, 100)
				else math.clamp(math.ceil(hum.Health) - 100, 0, 100)
			local frac = math.clamp(baseHp / 100, 0, 1)
			playerHpFill.Size = UDim2.fromScale(frac, 1)
			playerHpLabel.Text = string.format("%d / 100 HP", baseHp)
			playerHpFill.BackgroundColor3 = if frac > 0.5
				then C_EMERALD
				elseif frac > 0.25 then Color3.fromRGB(184, 146, 56)
				else C_OXBLOOD

			if playerArmorFill and playerArmorLabel then
				playerArmorFill.Size = UDim2.fromScale(math.clamp(armor / 100, 0, 1), 1)
				playerArmorLabel.Text = string.format("%d / 100 ARMOR", armor)
			end
		end

		-- Smooth real-time Seated Customer Patience countdown bars
		if patienceCard and patienceHeaderLabel then
			local cfg = RestaurantSecurityConfig.CustomerPatience
			local elapsed = math.max(0, os.clock() - patienceReceivedAt)
			local activeCount = 0
			local minRem = math.huge
			local shown = 0
			for _, item in ipairs(latestPatienceList) do
				local rem0 = tonumber(item.RemainingSeconds) or 0
				local total = math.max(1, tonumber(item.TotalSeconds) or cfg.MaxSeconds)
				local rem = math.max(0, rem0 - elapsed)
				if rem > 0.05 then
					activeCount += 1
					if rem < minRem then
						minRem = rem
					end
					if shown < #patienceRows then
						shown += 1
						local r = patienceRows[shown]
						r.Row.Visible = true
						local cname = tostring(item.CustomerName or "Guest")
						local dish = tostring(item.DishName or "Order")
						r.NameLbl.Text = cname .. " • " .. dish
						local frac = math.clamp(rem / total, 0, 1)
						r.BarFill.Size = UDim2.fromScale(frac, 1)
						local isCook = item.IsBeingCooked == true
						if rem <= cfg.CriticalThresholdSeconds then
							r.BarFill.BackgroundColor3 = Color3.fromRGB(204, 48, 56)
							r.TimeLbl.TextColor3 = Color3.fromRGB(246, 118, 124)
							r.TimeLbl.Text = string.format("%ds!", math.ceil(rem))
						elseif rem <= cfg.WarningThresholdSeconds then
							r.BarFill.BackgroundColor3 = Color3.fromRGB(214, 152, 42)
							r.TimeLbl.TextColor3 = C_GOLD
							r.TimeLbl.Text = if isCook then string.format("COOK %ds", math.ceil(rem)) else string.format("%ds", math.ceil(rem))
						else
							r.BarFill.BackgroundColor3 = C_EMERALD_BRIGHT
							r.TimeLbl.TextColor3 = Color3.fromRGB(168, 232, 188)
							r.TimeLbl.Text = if isCook then string.format("COOK %ds", math.ceil(rem)) else string.format("%ds", math.ceil(rem))
						end
					end
				end
			end
			for idx = shown + 1, #patienceRows do
				patienceRows[idx].Row.Visible = false
			end
			if activeCount > 0 then
				patienceCard.Visible = true
				patienceCard.Size = UDim2.fromOffset(216, 26 + shown * 27)
				patienceHeaderLabel.Text = string.format("WAITING GUESTS (%d)", activeCount)
				if patienceCardStroke then
					patienceCardStroke.Color = if minRem <= cfg.CriticalThresholdSeconds
						then Color3.fromRGB(204, 56, 66)
						elseif minRem <= cfg.WarningThresholdSeconds then C_GOLD
						else C_GOLD_DIM
				end
			else
				patienceCard.Visible = false
			end
		end
	end)

	-- =========================================================================
	-- 5. TOAST BANNER & THERMAL RECEIPT TICKET
	-- =========================================================================
	local toast = Instance.new("TextLabel")
	toast.Name = "ToastBanner"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -158)
	toast.Size = UDim2.fromOffset(470, 32)
	toast.BackgroundColor3 = C_OBS
	toast.BackgroundTransparency = 0.04
	toast.Font = FONT_BODY
	toast.Text = ""
	toast.TextSize = 12
	toast.TextColor3 = C_BONE
	toast.Visible = false
	toast.Parent = gui
	makeCorner(toast, 6)
	makeBorderStroke(toast, C_GOLD, 1.2)
	toastLabel = toast

	local ticket = Instance.new("Frame")
	ticket.Name = "ReceiptTicket"
	ticket.AnchorPoint = Vector2.new(1, 1)
	ticket.Position = UDim2.new(1, -14, 1, -252)
	ticket.Size = UDim2.fromOffset(200, 128)
	ticket.BackgroundColor3 = Color3.fromRGB(242, 238, 226)
	ticket.Visible = false
	ticket.Parent = gui
	makeCorner(ticket, 6)
	makeBorderStroke(ticket, C_GOLD_DIM, 1.2)
	receiptTicket = ticket

	local rHead = Instance.new("TextLabel")
	rHead.Name = "Header"
	rHead.Size = UDim2.new(1, 0, 0, 22)
	rHead.BackgroundColor3 = C_OBS
	rHead.Font = FONT_TITLE
	rHead.Text = "RECEIPT #1"
	rHead.TextSize = 10
	rHead.TextColor3 = C_GOLD
	rHead.Parent = ticket
	makeCorner(rHead, 5)
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
	rBody.TextSize = 10
	rBody.TextColor3 = Color3.fromRGB(28, 30, 36)
	rBody.Text = ""
	rBody.Parent = ticket
	receiptBodyLbl = rBody

	-- =========================================================================
	-- 6. TOP-RIGHT: STREAMLINED URBAN TURF CONTROL CARD (BELOW NIGHT CLOCK)
	-- =========================================================================
	local turfCard = Instance.new("Frame")
	turfCard.Name = "UrbanTurfCard"
	turfCard.AnchorPoint = Vector2.new(1, 0)
	turfCard.Position = UDim2.new(1, -14, 0, 76)
	turfCard.Size = UDim2.fromOffset(216, 70)
	turfCard.BackgroundColor3 = C_OBS
	turfCard.BackgroundTransparency = 0.06
	turfCard.Parent = gui
	makeCorner(turfCard, 8)
	makeBorderStroke(turfCard, C_GOLD_DIM, 1.1)

	local tHead = Instance.new("TextLabel")
	tHead.Position = UDim2.new(0, 10, 0, 6)
	tHead.Size = UDim2.new(1, -20, 0, 14)
	tHead.BackgroundTransparency = 1
	tHead.Font = FONT_TITLE
	tHead.Text = "URBAN TURF CONTROL"
	tHead.TextSize = 10
	tHead.TextXAlignment = Enum.TextXAlignment.Left
	tHead.TextColor3 = C_GOLD
	tHead.Parent = turfCard

	local tBlocks = Instance.new("TextLabel")
	tBlocks.Position = UDim2.new(0, 10, 0, 22)
	tBlocks.Size = UDim2.new(0.58, -10, 0, 16)
	tBlocks.BackgroundTransparency = 1
	tBlocks.Font = FONT_TITLE
	tBlocks.Text = "0 / 28 BLOCKS"
	tBlocks.TextSize = 11
	tBlocks.TextXAlignment = Enum.TextXAlignment.Left
	tBlocks.TextColor3 = C_BONE
	tBlocks.Parent = turfCard
	turfBlocksLabel = tBlocks

	local tInc = Instance.new("TextLabel")
	tInc.AnchorPoint = Vector2.new(1, 0)
	tInc.Position = UDim2.new(1, -10, 0, 22)
	tInc.Size = UDim2.new(0.42, 0, 0, 16)
	tInc.BackgroundTransparency = 1
	tInc.Font = FONT_BODY
	tInc.Text = "+0G/20s"
	tInc.TextSize = 10
	tInc.TextXAlignment = Enum.TextXAlignment.Right
	tInc.TextColor3 = C_EMERALD_BRIGHT
	tInc.Parent = turfCard
	turfIncomeLabel = tInc

	local tBarBg = Instance.new("Frame")
	tBarBg.Position = UDim2.new(0, 10, 0, 42)
	tBarBg.Size = UDim2.new(1, -20, 0, 5)
	tBarBg.BackgroundColor3 = C_OBS_DEEP
	tBarBg.BorderSizePixel = 0
	tBarBg.Parent = turfCard
	makeCorner(tBarBg, 3)

	local tBarFill = Instance.new("Frame")
	tBarFill.Size = UDim2.fromScale(0, 1)
	tBarFill.BackgroundColor3 = C_GOLD
	tBarFill.BorderSizePixel = 0
	tBarFill.Parent = tBarBg
	makeCorner(tBarFill, 3)
	turfProgressFill = tBarFill

	local tAlert = Instance.new("TextLabel")
	tAlert.Position = UDim2.new(0, 10, 0, 50)
	tAlert.Size = UDim2.new(1, -20, 0, 14)
	tAlert.BackgroundTransparency = 1
	tAlert.Font = FONT_REG
	tAlert.Text = "Engage Mafia across 28 urban blocks"
	tAlert.TextSize = 9
	tAlert.TextXAlignment = Enum.TextXAlignment.Left
	tAlert.TextColor3 = C_ASH
	tAlert.TextTruncate = Enum.TextTruncate.AtEnd
	tAlert.Parent = turfCard
	turfAlertLabel = tAlert

	-- =========================================================================
	-- 6B. TOP-RIGHT: SEATED CUSTOMER PATIENCE CARD (BELOW URBAN TURF CARD)
	-- =========================================================================
	local pCard = Instance.new("Frame")
	pCard.Name = "CustomerPatienceCard"
	pCard.AnchorPoint = Vector2.new(1, 0)
	pCard.Position = UDim2.new(1, -14, 0, 154)
	pCard.Size = UDim2.fromOffset(216, 108)
	pCard.BackgroundColor3 = C_OBS
	pCard.BackgroundTransparency = 0.06
	pCard.Visible = false
	pCard.Parent = gui
	makeCorner(pCard, 8)
	patienceCardStroke = makeBorderStroke(pCard, C_GOLD_DIM, 1.1)
	patienceCard = pCard

	local pHead = Instance.new("TextLabel")
	pHead.Position = UDim2.new(0, 10, 0, 6)
	pHead.Size = UDim2.new(1, -20, 0, 14)
	pHead.BackgroundTransparency = 1
	pHead.Font = FONT_TITLE
	pHead.Text = "WAITING GUESTS (0)"
	pHead.TextSize = 10
	pHead.TextXAlignment = Enum.TextXAlignment.Left
	pHead.TextColor3 = C_GOLD
	pHead.Parent = pCard
	patienceHeaderLabel = pHead

	table.clear(patienceRows)
	for rIdx = 1, 3 do
		local row = Instance.new("Frame")
		row.Name = "PatienceRow_" .. tostring(rIdx)
		row.Position = UDim2.new(0, 8, 0, 23 + (rIdx - 1) * 27)
		row.Size = UDim2.new(1, -16, 0, 23)
		row.BackgroundColor3 = C_INNER
		row.BackgroundTransparency = 0.12
		row.Visible = false
		row.Parent = pCard
		makeCorner(row, 4)

		local nLbl = Instance.new("TextLabel")
		nLbl.Position = UDim2.new(0, 6, 0, 1)
		nLbl.Size = UDim2.new(1, -56, 0, 13)
		nLbl.BackgroundTransparency = 1
		nLbl.Font = FONT_BODY
		nLbl.Text = ""
		nLbl.TextSize = 9
		nLbl.TextXAlignment = Enum.TextXAlignment.Left
		nLbl.TextColor3 = C_BONE
		nLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nLbl.Parent = row

		local tmLbl = Instance.new("TextLabel")
		tmLbl.AnchorPoint = Vector2.new(1, 0)
		tmLbl.Position = UDim2.new(1, -6, 0, 1)
		tmLbl.Size = UDim2.fromOffset(48, 13)
		tmLbl.BackgroundTransparency = 1
		tmLbl.Font = FONT_TITLE
		tmLbl.Text = "18s"
		tmLbl.TextSize = 9
		tmLbl.TextXAlignment = Enum.TextXAlignment.Right
		tmLbl.TextColor3 = Color3.fromRGB(168, 232, 188)
		tmLbl.Parent = row

		local barBg = Instance.new("Frame")
		barBg.Position = UDim2.new(0, 6, 0, 16)
		barBg.Size = UDim2.new(1, -12, 0, 4)
		barBg.BackgroundColor3 = C_OBS_DEEP
		barBg.BorderSizePixel = 0
		barBg.ClipsDescendants = true
		barBg.Parent = row
		makeCorner(barBg, 2)

		local barFill = Instance.new("Frame")
		barFill.Size = UDim2.fromScale(1, 1)
		barFill.BackgroundColor3 = C_EMERALD_BRIGHT
		barFill.BorderSizePixel = 0
		barFill.Parent = barBg
		makeCorner(barFill, 2)

		table.insert(patienceRows, {
			Row = row,
			NameLbl = nLbl,
			TimeLbl = tmLbl,
			BarFill = barFill,
		})
	end

	-- =========================================================================
	-- 7. CONTEXTUAL BLOCK CAPTURE BANNER (SHOWN ONLY INSIDE A CAPTURE PLAZA)
	-- =========================================================================
	local bBanner = Instance.new("Frame")
	bBanner.Name = "ActiveBlockCaptureBanner"
	bBanner.AnchorPoint = Vector2.new(0.5, 0)
	bBanner.Position = UDim2.new(0.5, 0, 0, 84)
	bBanner.Size = UDim2.fromOffset(368, 52)
	bBanner.BackgroundColor3 = C_OBS
	bBanner.BackgroundTransparency = 0.05
	bBanner.Visible = false
	bBanner.Parent = gui
	makeCorner(bBanner, 8)
	makeBorderStroke(bBanner, C_GOLD, 1.2)
	activeBlockBanner = bBanner

	local bTitle = Instance.new("TextLabel")
	bTitle.Position = UDim2.new(0, 10, 0, 4)
	bTitle.Size = UDim2.new(0.58, -10, 0, 22)
	bTitle.BackgroundTransparency = 1
	bTitle.Font = FONT_TITLE
	bTitle.TextXAlignment = Enum.TextXAlignment.Left
	bTitle.Text = "LITTLE ITALY ROW"
	bTitle.TextSize = 12
	bTitle.TextColor3 = C_GOLD
	bTitle.Parent = bBanner
	makeTextOutline(bTitle, 1.1)
	activeBlockTitle = bTitle

	local bOwner = Instance.new("TextLabel")
	bOwner.AnchorPoint = Vector2.new(1, 0)
	bOwner.Position = UDim2.new(1, -10, 0, 5)
	bOwner.Size = UDim2.new(0.40, 0, 0, 20)
	bOwner.BackgroundColor3 = Color3.fromRGB(238, 112, 24)
	bOwner.Font = FONT_TITLE
	bOwner.Text = "IRON CLAW"
	bOwner.TextSize = 10
	bOwner.TextColor3 = Color3.new(1, 1, 1)
	bOwner.Parent = bBanner
	makeCorner(bOwner, 5)
	makeTextOutline(bOwner, 1.0)
	activeBlockOwnerPill = bOwner

	local bBarBg = Instance.new("Frame")
	bBarBg.Position = UDim2.new(0, 10, 0, 30)
	bBarBg.Size = UDim2.new(1, -20, 0, 17)
	bBarBg.BackgroundColor3 = C_OBS_DEEP
	bBarBg.Parent = bBanner
	makeCorner(bBarBg, 5)

	local bFill = Instance.new("Frame")
	bFill.Size = UDim2.fromScale(0, 1)
	bFill.BackgroundColor3 = C_EMERALD_BRIGHT
	bFill.Parent = bBarBg
	makeCorner(bFill, 5)
	activeBlockFill = bFill

	local bSub = Instance.new("TextLabel")
	bSub.Size = UDim2.fromScale(1, 1)
	bSub.BackgroundTransparency = 1
	bSub.Font = FONT_TITLE
	bSub.Text = "MAFIA CONTROLLED"
	bSub.TextSize = 10
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
				activeBlockSub.Text = "CONTESTED  •  Clear rival units"
			elseif prog > 0.01 then
				activeBlockSub.Text = string.format("%s CAPTURING... %d%%", string.upper(tostring(foundBlock.CapturingName or "CAPTURING")), math.floor(prog * 100))
			elseif TurfConfig.IsMafiaFaction(tostring(foundBlock.Owner or "")) then
				activeBlockSub.Text = if defs > 0
					then string.format("%d Mafia Defender(s)  •  Clear & hold plaza", defs)
					else "Defenders cleared  •  Hold plaza to claim"
			else
				activeBlockSub.Text = string.format("Controlled (+%dG/20s)  •  %d Guard(s)", tonumber(foundBlock.IncomeGold) or 18, defs)
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
	toastLabel.Text = message
	toastLabel.TextColor3 = if isError then Color3.fromRGB(238, 124, 130) else C_BONE
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
		local coins = tonumber(profile.Coins) or 0
		local rep = tonumber(profile.Reputation) or 0
		local lv = tonumber(profile.Level) or 1
		local xp = tonumber(profile.EXP) or 0
		local nextXp = math.max(100, lv * 100)

		if coinsLabel then
			coinsLabel.Text = formatNumber(coins)
		end
		if repLabel then
			repLabel.Text = formatNumber(rep) .. " REP"
		end
		if levelLabel then
			levelLabel.Text = string.format("LV. %d", lv)
		end
		if xpSubLabel then
			xpSubLabel.Text = string.format("%s XP", formatNumber(xp))
		end
		if xpBarFill then
			xpBarFill.Size = UDim2.fromScale(math.clamp((xp % nextXp) / nextXp, 0.08, 1), 1)
		end
	end

	local slot = state.BaseSlot
	if baseBadge and typeof(slot) == "string" then
		baseBadge.Text = string.upper(slot) .. " BASE"
		local col = SectorConfig.FactionColors[slot]
		if col and baseAccentBar then
			baseAccentBar.BackgroundColor3 = col
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
		local famTag = if typeof(fam) == "table" and fam.InFamily and typeof(fam.FamilyName) == "string" then (" • " .. fam.FamilyName) else ""
		local pTag = if pLv > 0 then string.format(" P%d", pLv) else ""
		emperorBanner.Text = string.format(
			"%s%s  |  %d-STAR BISTRO  |  DON: %s%s",
			rankTitle,
			pTag,
			stars,
			string.upper(emperor.Name or "--"),
			famTag
		)
	end

	local kitchen = state.Kitchen
	local waiting = state.WaitingCustomer
	if typeof(state.SeatedPatience) == "table" then
		latestPatienceList = state.SeatedPatience
		patienceReceivedAt = os.clock()
	else
		latestPatienceList = {}
		patienceReceivedAt = os.clock()
	end
	if sellBadgeBtn and sellTextLabel and kitchen then
		local ready = kitchen.ReadyTotal or 0
		if ready > 0 then
			sellTextLabel.Text = string.format("SELL (%d)", ready)
			sellBadgeBtn.BackgroundColor3 = C_EMERALD
		elseif typeof(waiting) == "table" and waiting.IsBeingCooked then
			sellTextLabel.Text = "COOKING"
			sellBadgeBtn.BackgroundColor3 = Color3.fromRGB(134, 96, 36)
		elseif typeof(waiting) == "table" and waiting.CustomerName then
			sellTextLabel.Text = "SERVE"
			sellBadgeBtn.BackgroundColor3 = C_EMERALD
		else
			sellTextLabel.Text = "SERVE"
			sellBadgeBtn.BackgroundColor3 = Color3.fromRGB(36, 98, 62)
		end
	end

	-- Pop up Printed Restaurant Receipt Ticket above Bottom-Right Minimap
	local latest = state.LatestReceipt
	if typeof(latest) == "table" and typeof(latest.OrderNo) == "number" and latest.OrderNo > lastReceiptOrderNo then
		lastReceiptOrderNo = latest.OrderNo
		if receiptTicket and receiptHeaderLbl and receiptBodyLbl then
			receiptHeaderLbl.Text = string.format("RECEIPT #%d  •  PAID", latest.OrderNo)
			receiptBodyLbl.Text = string.format(
				"FOOD EMPIRE DINER\n-------------------\nGuest: %s\nItem:  %s\nChef:  %s\n-------------------\n+%dG | +%d Rep",
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

	-- Compact 2x2 Bike Tile update
	if bikeTextLabel and bikeKeyLabel then
		local ownsBike = state.OwnsMotorbike == true
		bikeTextLabel.Text = "BIKE"
		bikeKeyLabel.Text = if ownsBike then "[V]" else "[LOCK]"
		bikeKeyLabel.TextColor3 = if ownsBike then C_GOLD else C_ASH
		if bikeBtnRef then
			bikeBtnRef.BackgroundTransparency = if ownsBike then 0.04 else 0.16
		end
	end

	-- Compact 2x2 Central Park Mafia Ingredient Shipment pills (shows LOCKED if matching Warehouse not yet unlocked!)
	local shipments = state.Shipments
	local whLevels = if typeof(state.Warehouse) == "table" and typeof(state.Warehouse.Levels) == "table"
		then state.Warehouse.Levels
		else nil
	if typeof(shipments) == "table" then
		for sectorId, dot in pairs(sectorDots) do
			local sh = shipments[sectorId]
			local lbl = sectorStatusLabels[sectorId]
			local pill = sectorPills[sectorId]
			local tag = SECTOR_TAGS[sectorId] or "SEC"
			if typeof(sh) == "table" then
				local st = if pill then pill:FindFirstChildOfClass("UIStroke") else nil
				local isUnlocked = (whLevels == nil) or ((whLevels[sh.Category] or 0) >= 1)
				if not isUnlocked then
					dot.BackgroundColor3 = C_OXBLOOD
					if pill then pill.BackgroundColor3 = Color3.fromRGB(34, 18, 22) end
					if st then st.Color = Color3.fromRGB(118, 42, 50) end
					if lbl then
						lbl.Text = tag .. " • LOCKED"
						lbl.TextColor3 = Color3.fromRGB(224, 146, 150)
					end
				elseif sh.Phase == "EnRoute" then
					dot.BackgroundColor3 = C_GOLD
					if pill then pill.BackgroundColor3 = Color3.fromRGB(44, 36, 22) end
					if st then st.Color = C_GOLD_DIM end
					if lbl then
						lbl.Text = tag .. " • EN ROUTE"
						lbl.TextColor3 = C_GOLD
					end
				elseif sh.Phase == "Arrived" then
					dot.BackgroundColor3 = C_EMERALD_BRIGHT
					if pill then pill.BackgroundColor3 = Color3.fromRGB(22, 42, 32) end
					if st then st.Color = C_EMERALD end
					if lbl then
						lbl.Text = tag .. " • STEAL!"
						lbl.TextColor3 = Color3.fromRGB(168, 232, 188)
					end
				else
					dot.BackgroundColor3 = C_ASH
					if pill then pill.BackgroundColor3 = C_INNER end
					if st then st.Color = C_BORDER end
					if lbl then
						lbl.Text = string.format("%s • %ds", tag, tonumber(sh.SecondsUntilNext) or 0)
						lbl.TextColor3 = C_BONE
					end
				end
			end
		end
	end

	-- Objective copy
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
				objectiveLabel.Text = "STEP 1: Steal a Mafia Seafood & Fish Shipment at Central Park [E] or spin the Lucky Wheel."
			else
				objectiveLabel.Text = "STEP 2: Open Kitchen [C] to cook your 1st dish, then press [SERVE]!"
			end
		elseif courierCount == 0 or crewCount == 0 or waiterCount == 0 then
			objectiveLabel.Text = string.format(
				"Hire Couriers (%d/2), Chefs (%d), & Waiters (%d/5) in Empire [U].",
				courierCount,
				crewCount,
				waiterCount
			)
		elseif typeof(branch) == "table" and not branch.Owned then
			objectiveLabel.Text = "Buy Central Park Bistro (750G in Empire [U]) & call your staff!"
		elseif unlockedWh < 4 then
			objectiveLabel.Text = string.format("Open Storage [B] to unlock Ingredient Warehouses (%d/4) for more dishes & Mafia shipments.", unlockedWh)
		elseif restLv < 2 then
			objectiveLabel.Text = "Upgrade Restaurant HQ [U], escort Convoys & complete Contracts!"
		else
			objectiveLabel.Text = "Conquer all 28 Turf Blocks, finish Contracts [U] & reign as Food Emperor!"
		end
	end

	-- VIP Critic copy
	if vipOrderLabel then
		local vip = state.VIPOrder
		if typeof(vip) == "table" and vip.DisplayName then
			vipOrderLabel.Text = string.format(
				"%s\n+%dG  •  +%d Rep  •  %ds",
				vip.DisplayName,
				vip.BonusCoins or 0,
				vip.BonusRep or 0,
				vip.Remaining or 0
			)
		else
			vipOrderLabel.Text = "Next VIP Critic order pending..."
		end
	end

	-- Express Delivery copy & button state
	if expressOrderLabel and expressAcceptBtn then
		local exp = state.ExpressDelivery
		if typeof(exp) == "table" then
			local comboStr = if (exp.Combo or 0) > 0 then string.format(" [x%d]", exp.Combo) else ""
			if exp.Status == "Active" then
				expressOrderLabel.Text = string.format(
					"%s -> %s\n%ds left • +%dG + Tip%s",
					tostring(exp.DishName or "Meal"),
					tostring(exp.DropName or "Center"),
					tonumber(exp.Remaining) or 0,
					tonumber(exp.BaseGold) or 100,
					comboStr
				)
				expressAcceptBtn.Text = string.format("EN ROUTE (%ds)", tonumber(exp.Remaining) or 0)
				expressAcceptBtn.BackgroundColor3 = Color3.fromRGB(134, 92, 34)
			elseif exp.Status == "Available" then
				expressOrderLabel.Text = string.format(
					"%s • %s\n%s • +%dG (%ds)%s",
					tostring(exp.CustomerName or "Guest"),
					tostring(exp.DishName or "Meal"),
					tostring(exp.DropName or "Center"),
					tonumber(exp.BaseGold) or 100,
					tonumber(exp.Duration) or 45,
					comboStr
				)
				expressAcceptBtn.Text = "ACCEPT EXPRESS"
				expressAcceptBtn.BackgroundColor3 = C_EMERALD
			else
				expressOrderLabel.Text = string.format("Next express dispatch in %ds%s", tonumber(exp.Remaining) or 5, comboStr)
				expressAcceptBtn.Text = "STANDBY"
				expressAcceptBtn.BackgroundColor3 = C_BORDER
			end
		end
	end

	-- Top-Right Urban Turf Control Card (28 Blocks + Progress Bar)
	local turf = state.Turf
	if typeof(turf) == "table" then
		latestTurfState = turf
		local owned = tonumber(turf.OwnedCount) or 0
		local total = tonumber(turf.TotalBlocks) or 28
		local inc = tonumber(turf.IncomePerCycle) or 0
		local mono = tonumber(turf.Monopolies) or 0
		if turfBlocksLabel then
			turfBlocksLabel.Text = string.format("%d / %d BLOCKS", owned, total)
		end
		if turfIncomeLabel then
			local monoTag = if mono > 0 then string.format(" (%dM)", mono) else ""
			turfIncomeLabel.Text = string.format("+%dG/20s%s", inc, monoTag)
		end
		if turfProgressFill then
			turfProgressFill.Size = UDim2.fromScale(math.clamp(owned / math.max(1, total), 0, 1), 1)
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
				turfAlertLabel.TextColor3 = Color3.fromRGB(232, 102, 108)
			elseif owned == 0 then
				turfAlertLabel.Text = "Engage Mafia across 28 urban blocks"
				turfAlertLabel.TextColor3 = C_ASH
			else
				turfAlertLabel.Text = "Hold all 7 in a quadrant for +50%"
				turfAlertLabel.TextColor3 = Color3.fromRGB(154, 212, 172)
			end
		end
	end

	-- Update 2x2 Tactical Gadgets (always cleanly shown in symmetric 2x2 grid; highlights when owned/ready!)
	local bm = state.BlackMarket
	local flashCount = if typeof(bm) == "table" then (tonumber(bm.Flashbangs) or 0) else 0
	local c4Count = if typeof(bm) == "table" then (tonumber(bm.C4Charges) or 0) else 0
	local hasDash = typeof(bm) == "table" and bm.HasShadowDash == true

	if flashBtnRef and flashMainLbl then
		flashMainLbl.Text = if flashCount > 0 then string.format("FLASH %d", flashCount) else "FLASH"
		flashBtnRef.BackgroundColor3 = if flashCount > 0 then Color3.fromRGB(48, 42, 26) else C_OBS
		flashBtnRef.BackgroundTransparency = if flashCount > 0 then 0.04 else 0.16
		local st = flashBtnRef:FindFirstChildOfClass("UIStroke")
		if st then st.Color = if flashCount > 0 then C_GOLD else C_BORDER end
	end
	if c4BtnRef and c4MainLbl then
		c4MainLbl.Text = if c4Count > 0 then string.format("C4 (%d)", c4Count) else "C4"
		c4BtnRef.BackgroundColor3 = if c4Count > 0 then C_CRIMSON_BG else C_OBS
		c4BtnRef.BackgroundTransparency = if c4Count > 0 then 0.04 else 0.16
		local st = c4BtnRef:FindFirstChildOfClass("UIStroke")
		if st then st.Color = if c4Count > 0 then C_OXBLOOD else C_BORDER end
	end
	if dashBtnRef and dashMainLbl then
		dashMainLbl.Text = "DASH"
		local keyLbl = dashBtnRef:FindFirstChild("KeyLabel")
		if keyLbl and keyLbl:IsA("TextLabel") then
			keyLbl.Text = if hasDash then "[8]" else "[LOCK]"
			keyLbl.TextColor3 = if hasDash then Color3.fromRGB(168, 198, 232) else C_ASH
		end
		dashBtnRef.BackgroundColor3 = if hasDash then Color3.fromRGB(24, 34, 48) else C_OBS
		dashBtnRef.BackgroundTransparency = if hasDash then 0.04 else 0.16
		local st = dashBtnRef:FindFirstChildOfClass("UIStroke")
		if st then st.Color = if hasDash then C_STEEL else C_BORDER end
	end

	-- Update Squad Command Buttons (bright when guards/mercenaries active, subtly dimmed when none hired)
	local hasGuards = (tonumber(state.BodyguardCount) or 0) > 0
	local merc = state.MercenaryMafia
	local hasMerc = typeof(merc) == "table" and merc.Active == true
	local showSquad = hasGuards or hasMerc
	if attackBtnRef then
		attackBtnRef.BackgroundTransparency = if showSquad then 0.04 else 0.22
	end
	if recallBtnRef then
		recallBtnRef.BackgroundTransparency = if showSquad then 0.04 else 0.22
	end
end

return HUDController
