--!strict

-- Refined Dark-Mafia Empire Menu & Black Market Controller.
-- Minimalist, intimidating obsidian/charcoal palette, crisp typographic hierarchy,
-- real 3D ViewportFrame previews via ModelPreviewHelper, zero emojis, zero neon borders.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local RecipeConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RecipeConfig")
)
local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local MonetizationConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("MonetizationConfig")
)
local WeaponConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WeaponConfig")
)
local BodyguardConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("BodyguardConfig")
)
local RestaurantSecurityConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RestaurantSecurityConfig")
)
local ModelPreviewHelper = require("./ModelPreviewHelper")
local CurrencyIconHelper = require("./CurrencyIconHelper")
local AudioController = require("./AudioController")

export type MenuTab = "Kitchen" | "Warehouses" | "Upgrades" | "Market" | "BlackMarket" | "Shop"
export type ActionCallback = (action: string, arg: any?) -> ()
type EmpireSubTab = "HQ" | "Security" | "Syndicate"
type SecuritySubView = "Timed" | "Classes" | "Gear"
type MarketSubTab = "Weapons" | "Supplies" | "Bodyguards" | "GuardGear"
type BlackMarketSubTab = "Weapons" | "Gadgets" | "Bodyguards" | "Mercenaries" | "Premium"
type WeaponFilter = "All" | "Melee" | "Pistol" | "Shotgun" | "SMG" | "AssaultRifle" | "Sniper" | "Gear"
type GuardViewMode = "Classes" | "Gear"
type GuardGearFilter = "All" | "Armor" | "Helmet" | "Outfit" | "Weapon" | "Attachment" | "Tactical"

local EmpireMenuController = {}

-- Front-Page Roblox Arcade-Syndicate Vibrant Palette (NOT dull flat dark AI slop!)
local C_BG_MODAL = Color3.fromRGB(16, 22, 36)
local C_BG_SIDEBAR = Color3.fromRGB(12, 16, 28)
local C_BG_CARD = Color3.fromRGB(24, 33, 52)
local C_BG_CARD_ALT = Color3.fromRGB(30, 41, 64)
local C_BG_SUBTLE = Color3.fromRGB(38, 52, 82)
local C_BORDER = Color3.fromRGB(54, 72, 108)
local C_BORDER_STRONG = Color3.fromRGB(88, 114, 164)
local C_OUTLINE_DARK = Color3.fromRGB(8, 11, 18)
local C_TEXT_PRIMARY = Color3.fromRGB(252, 250, 246)
local C_TEXT_MUTED = Color3.fromRGB(184, 196, 220)
local C_TEXT_DIM = Color3.fromRGB(132, 148, 178)
local C_OXBLOOD = Color3.fromRGB(220, 38, 62)
local C_OXBLOOD_DARK = Color3.fromRGB(136, 24, 42)
local C_TEAL = Color3.fromRGB(14, 158, 154)
local C_TEAL_DARK = Color3.fromRGB(12, 88, 96)
local C_BRASS = Color3.fromRGB(245, 168, 28)
local C_GOLD_HI = Color3.fromRGB(255, 224, 94)
local C_STEEL = Color3.fromRGB(37, 132, 236)
local C_OWNED = Color3.fromRGB(22, 163, 74)
local C_ROBUX = Color3.fromRGB(16, 172, 92)
local C_DISABLED = Color3.fromRGB(48, 56, 74)

local DEFENSE_COSTS: { [number]: number } = { [2] = 2500, [3] = 6000 }

local BLACK_MARKET_ROBUX_IDS = {
	"BossBodyguardPass",
	"SamuraiMafiaContract",
	"NinjaMafiaContract",
	"GoldenEmperorPistolPass",
	"CrimsonDragonARPass",
	"GoldenEmperorSuitPass",
	"TacticalAmmoCrate",
	"SyndicateArmorBundle",
}

local RARITY_MUTED_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(100, 116, 139),
	Uncommon = Color3.fromRGB(34, 197, 94),
	Rare = Color3.fromRGB(56, 152, 248),
	Epic = Color3.fromRGB(168, 85, 247),
	Legendary = Color3.fromRGB(245, 176, 28),
	Mythic = Color3.fromRGB(239, 44, 72),
}

local TAB_THEMES: { [MenuTab]: { Accent: Color3, Dark: Color3, Title: string, Sub: string } } = {
	Kitchen = {
		Accent = Color3.fromRGB(245, 158, 11),
		Dark = Color3.fromRGB(146, 74, 12),
		Title = "MASTER KITCHEN",
		Sub = "Cook gourmet dishes, chase 2X Cravings & stack profits!",
	},
	Warehouses = {
		Accent = Color3.fromRGB(14, 165, 233),
		Dark = Color3.fromRGB(16, 86, 146),
		Title = "INGREDIENT WAREHOUSES",
		Sub = "Unlock warehouses to unlock kitchen dishes & steal Mafia shipments!",
	},
	Upgrades = {
		Accent = Color3.fromRGB(234, 179, 8),
		Dark = Color3.fromRGB(142, 94, 14),
		Title = "SYNDICATE EMPIRE",
		Sub = "Upgrade HQ, hire crew & deploy Restaurant Defense Bodyguards!",
	},
	Market = {
		Accent = Color3.fromRGB(14, 165, 160),
		Dark = Color3.fromRGB(12, 88, 98),
		Title = "CITY MARKET",
		Sub = "Standard firearms, ammo crates, medkits & city bodyguards — shop from anywhere!",
	},
	BlackMarket = {
		Accent = Color3.fromRGB(225, 29, 72),
		Dark = Color3.fromRGB(110, 14, 34),
		Title = "BLACK MARKET",
		Sub = "Underground contraband weapons, C4 & stealth gadgets, elite enforcers & mafia squads!",
	},
	Shop = {
		Accent = Color3.fromRGB(16, 185, 104),
		Dark = Color3.fromRGB(12, 108, 62),
		Title = "ROBUX STORE",
		Sub = "Permanent VIP Game Passes & instant empire power-ups!",
	},
}

local backdropFrame: Frame? = nil
local modalFrame: Frame? = nil
local stageHeaderBar: Frame? = nil
local stageHeaderGrad: UIGradient? = nil
local stageHeaderIconSlot: Frame? = nil
local lastHeaderIconTab: MenuTab? = nil
local titleLabel: TextLabel? = nil
local subtitleLabel: TextLabel? = nil
local headerGoldValLbl: TextLabel? = nil
local headerRankValLbl: TextLabel? = nil
local scrollFrame: ScrollingFrame? = nil
local nextAutoOrder: number = 0
local confirmOverlay: Frame? = nil
local confirmTitleLbl: TextLabel? = nil
local confirmDescLbl: TextLabel? = nil
local confirmYesBtn: TextButton? = nil
local pendingConfirmCallback: (() -> ())? = nil
local tabButtons: { [MenuTab]: TextButton } = {}
local tabLabels: { [MenuTab]: TextLabel } = {}
local tabActiveBars: { [MenuTab]: Frame } = {}
local currentTab: MenuTab = "Kitchen"
local currentEmpireSubTab: EmpireSubTab = "HQ"
local currentSecuritySubView: SecuritySubView = "Timed"
local currentMarketSubTab: MarketSubTab = "Weapons"
local currentMarketWeaponFilter: WeaponFilter = "All"
local currentBMSubTab: BlackMarketSubTab = "Weapons"
local currentWeaponFilter: WeaponFilter = "All"
local currentGuardView: GuardViewMode = "Classes"
local currentGuardGearFilter: GuardGearFilter = "All"
local selectedGuardSlot: number = 1
local latestState: { [string]: any }? = nil
local dispatchAction: ActionCallback? = nil
local lastRenderedTabSig: string = ""
local deferredRenderQueued: boolean = false

local function formatCommaInt(n: number): string
	local s = tostring(math.max(0, math.floor(n)))
	local formatted = s
	while true do
		local nextStr, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = nextStr
		if k == 0 then break end
	end
	return formatted
end

local function makeCorner(parent: Instance, radius: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeStroke(parent: Instance, color: Color3, thickness: number, trans: number?): UIStroke
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = color
	st.Thickness = thickness
	if trans then
		st.Transparency = trans
	end
	st.Parent = parent
	return st
end

local function addTextOutline(lbl: TextLabel | TextButton, thick: number?, col: Color3?): UIStroke
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	st.Color = col or C_OUTLINE_DARK
	st.Thickness = thick or 1.8
	st.Parent = lbl
	return st
end

-- Chunky Front-Page Roblox Game Card (vibrant top color wash, crisp 2px outline, 3D bottom depth lip!)
local function makeCard(parent: Instance, height: number, accentBar: Color3?): Frame
	local accent = accentBar or C_BORDER_STRONG
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -6, 0, height)
	card.BackgroundColor3 = C_BG_CARD:Lerp(accent, 0.14)
	card.BorderSizePixel = 0
	card.Parent = parent
	makeCorner(card, 10)
	makeStroke(card, accent:Lerp(C_OUTLINE_DARK, 0.35), 2.0)

	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(178, 186, 206)),
	})
	grad.Parent = card

	-- Glossy top inner rim highlight
	local topGloss = Instance.new("Frame")
	topGloss.Size = UDim2.new(1, -16, 0, 2)
	topGloss.Position = UDim2.fromOffset(8, 2)
	topGloss.BackgroundColor3 = Color3.new(1, 1, 1)
	topGloss.BackgroundTransparency = 0.84
	topGloss.BorderSizePixel = 0
	topGloss.Parent = card

	-- Chunky 3D bottom shaded lip
	local botLip = Instance.new("Frame")
	botLip.AnchorPoint = Vector2.new(0, 1)
	botLip.Position = UDim2.fromScale(0, 1)
	botLip.Size = UDim2.new(1, 0, 0, 4)
	botLip.BackgroundColor3 = C_OUTLINE_DARK
	botLip.BackgroundTransparency = 0.45
	botLip.BorderSizePixel = 0
	botLip.Parent = card

	if accentBar then
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0, 5, 1, -16)
		bar.Position = UDim2.new(0, 3, 0, 7)
		bar.BackgroundColor3 = accentBar
		bar.BorderSizePixel = 0
		bar.Parent = card
		makeCorner(bar, 3)
	end

	return card
end

local function makeMonogramBox(parent: Instance, tagText: string, accent: Color3, yPos: number): TextLabel
	local box = Instance.new("TextLabel")
	box.Position = UDim2.new(0, 14, 0, yPos)
	box.Size = UDim2.fromOffset(54, 54)
	box.BackgroundColor3 = Color3.fromRGB(14, 20, 34)
	box.Font = Enum.Font.GothamBlack
	box.Text = tagText
	box.TextSize = 14
	box.TextColor3 = C_GOLD_HI
	box.Parent = parent
	makeCorner(box, 9)
	makeStroke(box, accent, 2.0)
	addTextOutline(box, 1.8)
	return box
end

-- Chunky 3D Extruded Tactile Roblox Game Button (glossy top sheen, dark 3D bottom lip, outlined bold text & auto Coin/Robux icon!)
local function makeBtn(parent: Instance, text: string, bg: Color3, pos: UDim2, size: UDim2, onClick: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.Position = pos
	btn.Size = size
	btn.BackgroundColor3 = bg
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.GothamBlack
	btn.Text = text
	btn.TextSize = 12
	btn.TextColor3 = C_TEXT_PRIMARY
	btn.ClipsDescendants = true
	btn.Parent = parent
	makeCorner(btn, 8)

	local isVivid = (bg == C_OXBLOOD or bg == C_ROBUX or bg == C_BRASS or bg == C_OWNED or bg == C_STEEL or bg == C_TEAL)
	local baseStrokeCol = if bg == C_ROBUX
		then Color3.fromRGB(10, 68, 36)
		elseif bg == C_OXBLOOD then Color3.fromRGB(88, 12, 24)
		elseif bg == C_TEAL then Color3.fromRGB(8, 66, 68)
		elseif bg == C_BRASS then Color3.fromRGB(112, 62, 6)
		elseif bg == C_OWNED then Color3.fromRGB(12, 74, 34)
		else C_OUTLINE_DARK
	local stroke = makeStroke(btn, baseStrokeCol, if isVivid then 2.2 else 1.6)

	-- Vibrant glossy vertical button gradient
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(232, 236, 244)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(162, 170, 188)),
	})
	grad.Parent = btn

	-- Bright glossy arcade top highlight strip
	local sheen = Instance.new("Frame")
	sheen.Name = "TopSheen"
	sheen.Position = UDim2.fromOffset(4, 2)
	sheen.Size = UDim2.new(1, -8, 0, 3)
	sheen.BackgroundColor3 = Color3.new(1, 1, 1)
	sheen.BackgroundTransparency = if isVivid then 0.65 else 0.84
	sheen.BorderSizePixel = 0
	sheen.Active = false
	sheen.Selectable = false
	sheen.ZIndex = btn.ZIndex + 1
	sheen.Parent = btn
	makeCorner(sheen, 3)

	-- Chunky 3D shaded bottom extrusion lip!
	local lip = Instance.new("Frame")
	lip.Name = "BottomLip"
	lip.AnchorPoint = Vector2.new(0, 1)
	lip.Position = UDim2.fromScale(0, 1)
	lip.Size = UDim2.new(1, 0, 0, 4)
	lip.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	lip.BackgroundTransparency = if isVivid then 0.58 else 0.68
	lip.BorderSizePixel = 0
	lip.Active = false
	lip.Selectable = false
	lip.ZIndex = btn.ZIndex + 1
	lip.Parent = btn

	addTextOutline(btn, 1.6)

	-- Automatically embed studio-grade Gold Coin or Robux Icon on EVERY currency button!
	CurrencyIconHelper.DecorateCurrencyButton(btn, text, 16)

	btn:SetAttribute("BaseBg", bg)
	btn:SetAttribute("BaseStroke", baseStrokeCol)
	local function getBaseBg(): Color3
		local v = btn:GetAttribute("BaseBg")
		return if typeof(v) == "Color3" then v else bg
	end
	local function getBaseStroke(): Color3
		local v = btn:GetAttribute("BaseStroke")
		return if typeof(v) == "Color3" then v else baseStrokeCol
	end

	btn.MouseEnter:Connect(function()
		local curBase = getBaseBg()
		btn.BackgroundColor3 = curBase:Lerp(Color3.new(1, 1, 1), 0.16)
		stroke.Color = if isVivid then C_GOLD_HI else Color3.fromRGB(168, 196, 240)
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = getBaseBg()
		stroke.Color = getBaseStroke()
	end)
	btn.MouseButton1Down:Connect(function()
		btn.BackgroundColor3 = getBaseBg():Lerp(Color3.new(0, 0, 0), 0.12)
	end)
	btn.MouseButton1Up:Connect(function()
		btn.BackgroundColor3 = getBaseBg():Lerp(Color3.new(1, 1, 1), 0.12)
	end)
	-- Use Activated (supports mouse clicks, quick clicks, touch taps & gamepad cleanly!)
	btn.Activated:Connect(onClick)
	return btn
end

local function makeTag(parent: Instance, text: string, bg: Color3, pos: UDim2, size: UDim2): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Position = pos
	lbl.Size = size
	lbl.BackgroundColor3 = bg
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = text
	lbl.TextSize = 9
	lbl.TextColor3 = C_TEXT_PRIMARY
	lbl.Parent = parent
	makeCorner(lbl, 5)
	makeStroke(lbl, C_OUTLINE_DARK, 1.4)
	addTextOutline(lbl, 1.2)
	return lbl
end

-- Helper: Creates a clean multi-column card grid container inside ScrollingFrame (2-col or 3-col!)
local function makeGridContainer(parent: Instance, cols: number, cellHeight: number, gap: number): Frame
	local container = Instance.new("Frame")
	container.Name = "CardGrid"
	container.Size = UDim2.new(1, -6, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.BackgroundTransparency = 1
	container.Parent = parent

	local grid = Instance.new("UIGridLayout")
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(gap, gap)
	local fracW = 1 / cols
	local offsetW = -math.ceil(gap * (cols - 1) / cols)
	grid.CellSize = UDim2.new(fracW, offsetW, 0, cellHeight)
	grid.Parent = container
	return container
end

-- Helper: Creates a vibrant Collectible Vertical Store Card (for 3-col Robux Store / Black Market VIP!)
local function makeStoreCollectibleCard(
	parent: Instance,
	layoutOrder: number,
	themeCol: Color3,
	badgeText: string,
	kindText: string,
	titleText: string,
	descText: string,
	previewKind: string,
	previewId: string,
	btnText: string,
	btnCol: Color3,
	onClick: () -> ()
): Frame
	local card = Instance.new("Frame")
	card.Name = "StoreCard_" .. previewId
	card.LayoutOrder = layoutOrder
	card.BackgroundColor3 = C_BG_CARD:Lerp(themeCol, 0.14)
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = parent
	makeCorner(card, 12)
	makeStroke(card, themeCol:Lerp(C_OUTLINE_DARK, 0.2), 2.2)

	-- Vibrant colored upper showcase bay
	local topBay = Instance.new("Frame")
	topBay.Size = UDim2.new(1, 0, 0, 118)
	topBay.BackgroundColor3 = themeCol:Lerp(Color3.fromRGB(16, 22, 36), 0.42)
	topBay.BorderSizePixel = 0
	topBay.Parent = card
	local topGrad = Instance.new("UIGradient")
	topGrad.Rotation = 135
	topGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(128, 138, 164)),
	})
	topGrad.Parent = topBay

	-- Glowing circular pedestal aura behind the 3D showcase model
	local aura = Instance.new("Frame")
	aura.AnchorPoint = Vector2.new(0.5, 0.5)
	aura.Position = UDim2.fromScale(0.5, 0.56)
	aura.Size = UDim2.fromOffset(96, 96)
	aura.BackgroundColor3 = themeCol
	aura.BackgroundTransparency = 0.62
	aura.BorderSizePixel = 0
	aura.Parent = topBay
	makeCorner(aura, 48)
	makeStroke(aura, Color3.new(1, 1, 1), 1.4, 0.65)

	local vp = ModelPreviewHelper.CreatePreview(
		topBay,
		previewKind :: any,
		previewId,
		UDim2.fromOffset(96, 96),
		UDim2.new(0.5, -48, 0.5, -44),
		Color3.fromRGB(18, 24, 38)
	)
	vp.BackgroundTransparency = 1
	local vpSt = vp:FindFirstChildOfClass("UIStroke")
	if vpSt then vpSt:Destroy() end

	-- Crisp corner pill badges
	makeTag(topBay, badgeText, themeCol:Lerp(C_OUTLINE_DARK, 0.25), UDim2.fromOffset(8, 7), UDim2.fromOffset(92, 17))
	makeTag(
		topBay,
		kindText,
		if kindText == "PERMANENT" then C_STEEL else C_OXBLOOD_DARK,
		UDim2.new(1, -84, 0, 7),
		UDim2.fromOffset(76, 17)
	)

	-- Bold outlined title
	local nLbl = Instance.new("TextLabel")
	nLbl.Position = UDim2.new(0, 10, 0, 124)
	nLbl.Size = UDim2.new(1, -20, 0, 32)
	nLbl.BackgroundTransparency = 1
	nLbl.Font = Enum.Font.GothamBlack
	nLbl.TextWrapped = true
	nLbl.TextXAlignment = Enum.TextXAlignment.Center
	nLbl.TextYAlignment = Enum.TextYAlignment.Top
	nLbl.TextSize = 13
	nLbl.TextColor3 = C_TEXT_PRIMARY
	nLbl.Text = titleText
	nLbl.Parent = card
	addTextOutline(nLbl, 1.6)

	local dLbl = Instance.new("TextLabel")
	dLbl.Position = UDim2.new(0, 10, 0, 156)
	dLbl.Size = UDim2.new(1, -20, 0, 44)
	dLbl.BackgroundTransparency = 1
	dLbl.Font = Enum.Font.GothamMedium
	dLbl.TextWrapped = true
	dLbl.TextTruncate = Enum.TextTruncate.AtEnd
	dLbl.TextXAlignment = Enum.TextXAlignment.Center
	dLbl.TextYAlignment = Enum.TextYAlignment.Top
	dLbl.TextSize = 10
	dLbl.TextColor3 = C_TEXT_MUTED
	dLbl.Text = descText
	dLbl.Parent = card

	-- Chunky full-width 3D Buy Button across the bottom!
	local btn = makeBtn(card, btnText, btnCol, UDim2.new(0, 10, 1, -46), UDim2.new(1, -20, 0, 36), onClick)
	btn.TextSize = 13

	-- Smooth AAA hover border highlight on store cards
	local cardSt = card:FindFirstChildOfClass("UIStroke")
	local origBg = card.BackgroundColor3
	local origStCol = if cardSt then cardSt.Color else themeCol
	card.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = origBg:Lerp(themeCol, 0.14),
		}):Play()
		if cardSt then
			TweenService:Create(cardSt, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = themeCol:Lerp(C_GOLD_HI, 0.45),
				Thickness = 2.7,
			}):Play()
		end
	end)
	card.MouseLeave:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = origBg,
		}):Play()
		if cardSt then
			TweenService:Create(cardSt, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = origStCol,
				Thickness = 2.2,
			}):Play()
		end
	end)

	return card
end

-- Helper: Subtle AAA hover border highlight & tint lift on collectible cards!
local function attachCardHoverGlow(card: Frame, glowCol: Color3): ()
	local st = card:FindFirstChildOfClass("UIStroke")
	local origBg = card.BackgroundColor3
	local origStroke = if st then st.Color else glowCol
	local origThick = if st then st.Thickness else 2.2
	card.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = origBg:Lerp(glowCol, 0.14),
		}):Play()
		if st then
			TweenService:Create(st, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = glowCol:Lerp(C_GOLD_HI, 0.45),
				Thickness = origThick + 0.5,
			}):Play()
		end
	end)
	card.MouseLeave:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = origBg,
		}):Play()
		if st then
			TweenService:Create(st, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = origStroke,
				Thickness = origThick,
			}):Play()
		end
	end)
end

-- Helper: Creates a vibrant studio-lit Showcase Pedestal Bay at the top of any modern collectible card!
local function createShowcasePedestalBay(
	card: Frame,
	bayHeight: number,
	themeCol: Color3,
	previewKind: string,
	previewId: string,
	isWideWeapon: boolean?
): Frame
	attachCardHoverGlow(card, themeCol)

	local topBay = Instance.new("Frame")
	topBay.Name = "ShowcaseBay"
	topBay.Size = UDim2.new(1, 0, 0, bayHeight)
	topBay.BackgroundColor3 = themeCol:Lerp(Color3.fromRGB(12, 18, 32), 0.44)
	topBay.BorderSizePixel = 0
	topBay.ClipsDescendants = true
	topBay.Parent = card

	local topGrad = Instance.new("UIGradient")
	topGrad.Rotation = 135
	topGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(184, 194, 220)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(108, 120, 152)),
	})
	topGrad.Parent = topBay

	-- Crisp top glass rim reflection
	local topGloss = Instance.new("Frame")
	topGloss.Position = UDim2.fromOffset(10, 2)
	topGloss.Size = UDim2.new(1, -20, 0, 2)
	topGloss.BackgroundColor3 = Color3.new(1, 1, 1)
	topGloss.BackgroundTransparency = 0.72
	topGloss.BorderSizePixel = 0
	topGloss.Parent = topBay
	makeCorner(topGloss, 2)

	-- Twin angled studio light beams
	local ray = Instance.new("Frame")
	ray.AnchorPoint = Vector2.new(0.5, 0.5)
	ray.Position = UDim2.fromScale(0.30, 0.5)
	ray.Size = UDim2.new(0, 44, 2.2, 0)
	ray.Rotation = 22
	ray.BackgroundColor3 = Color3.new(1, 1, 1)
	ray.BackgroundTransparency = 0.89
	ray.BorderSizePixel = 0
	ray.Parent = topBay

	local ray2 = Instance.new("Frame")
	ray2.AnchorPoint = Vector2.new(0.5, 0.5)
	ray2.Position = UDim2.fromScale(0.72, 0.5)
	ray2.Size = UDim2.new(0, 20, 2.2, 0)
	ray2.Rotation = 22
	ray2.BackgroundColor3 = Color3.new(1, 1, 1)
	ray2.BackgroundTransparency = 0.93
	ray2.BorderSizePixel = 0
	ray2.Parent = topBay

	-- Double-ring glowing circular studio spotlight pedestal behind artwork icon
	local auraSz = math.max(70, bayHeight - 10)
	local aura = Instance.new("Frame")
	aura.AnchorPoint = Vector2.new(0.5, 0.5)
	aura.Position = UDim2.fromScale(0.5, 0.53)
	aura.Size = UDim2.fromOffset(auraSz, auraSz)
	aura.BackgroundColor3 = themeCol
	aura.BackgroundTransparency = 0.64
	aura.BorderSizePixel = 0
	aura.Parent = topBay
	makeCorner(aura, math.floor(auraSz * 0.5))
	makeStroke(aura, Color3.new(1, 1, 1), 1.4, 0.58)

	local innerAuraSz = math.max(46, auraSz - 20)
	local innerAura = Instance.new("Frame")
	innerAura.AnchorPoint = Vector2.new(0.5, 0.5)
	innerAura.Position = UDim2.fromScale(0.5, 0.5)
	innerAura.Size = UDim2.fromOffset(innerAuraSz, innerAuraSz)
	innerAura.BackgroundColor3 = Color3.new(1, 1, 1)
	innerAura.BackgroundTransparency = 0.84
	innerAura.BorderSizePixel = 0
	innerAura.Parent = aura
	makeCorner(innerAura, math.floor(innerAuraSz * 0.5))

	local vpSize: UDim2
	local vpPos: UDim2
	if isWideWeapon then
		local h = bayHeight - 6
		vpSize = UDim2.new(1, -20, 0, h)
		vpPos = UDim2.new(0, 10, 0, 3)
	else
		local sz = bayHeight - 4
		vpSize = UDim2.fromOffset(sz, sz)
		vpPos = UDim2.new(0.5, -math.floor(sz * 0.5), 0.5, -math.floor(sz * 0.5) + 1)
	end

	local vp = ModelPreviewHelper.CreatePreview(
		topBay,
		previewKind :: any,
		previewId,
		vpSize,
		vpPos,
		Color3.fromRGB(16, 22, 36)
	)
	vp.BackgroundTransparency = 1
	local vpStroke = vp:FindFirstChildOfClass("UIStroke")
	if vpStroke then vpStroke:Destroy() end

	-- Crisp glowing bottom accent trim separating bay from card body
	local trim = Instance.new("Frame")
	trim.AnchorPoint = Vector2.new(0, 1)
	trim.Position = UDim2.fromScale(0, 1)
	trim.Size = UDim2.new(1, 0, 0, 2)
	trim.BackgroundColor3 = themeCol:Lerp(Color3.new(1, 1, 1), 0.25)
	trim.BackgroundTransparency = 0.25
	trim.BorderSizePixel = 0
	trim.Parent = topBay

	return topBay
end

local function makeSectionDivider(parent: Instance, titleText: string, accentCol: Color3): Frame
	local bar = Instance.new("Frame")
	bar.Name = "SectionDivider"
	bar.Size = UDim2.new(1, -6, 0, 26)
	bar.BackgroundColor3 = C_BG_CARD:Lerp(accentCol, 0.18)
	bar.BorderSizePixel = 0
	bar.Parent = parent
	makeCorner(bar, 7)
	makeStroke(bar, accentCol:Lerp(C_OUTLINE_DARK, 0.35), 1.4)

	local pip = Instance.new("Frame")
	pip.Position = UDim2.fromOffset(8, 5)
	pip.Size = UDim2.fromOffset(4, 16)
	pip.BackgroundColor3 = accentCol
	pip.BorderSizePixel = 0
	pip.Parent = bar
	makeCorner(pip, 2)

	local lbl = Instance.new("TextLabel")
	lbl.Position = UDim2.fromOffset(18, 0)
	lbl.Size = UDim2.new(1, -24, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextSize = 11
	lbl.TextColor3 = C_TEXT_PRIMARY
	lbl.Text = titleText
	lbl.Parent = bar
	addTextOutline(lbl, 1.3)
	return bar
end

local function hideConfirmDialog(): ()
	pendingConfirmCallback = nil
	if confirmOverlay then
		confirmOverlay.Visible = false
	end
end

local function showConfirmDialog(titleText: string, detailText: string, btnLabel: string, btnColor: Color3, onConfirm: () -> ()): ()
	if not confirmOverlay or not confirmTitleLbl or not confirmDescLbl or not confirmYesBtn then
		onConfirm()
		return
	end
	pendingConfirmCallback = onConfirm
	confirmTitleLbl.Text = titleText
	confirmDescLbl.Text = detailText
	local oldRow = confirmYesBtn:FindFirstChild("CurrencyIconRow")
	if oldRow then oldRow:Destroy() end
	confirmYesBtn.Text = btnLabel
	confirmYesBtn.BackgroundColor3 = btnColor
	CurrencyIconHelper.DecorateCurrencyButton(confirmYesBtn, btnLabel, 17)
	confirmOverlay.Visible = true
end

local render: () -> ()
local renderBodyguardsForTier: (
	state: { [string]: any },
	targetTier: BodyguardConfig.MarketTier | "All",
	forcedView: GuardViewMode?,
	autoDefendHQ: boolean?
) -> ()

local function clearScroll(): ()
	nextAutoOrder = 0
	if not scrollFrame then
		return
	end
	for _, ch in ipairs(scrollFrame:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
			ch:Destroy()
		end
	end
end

local TAB_ICON_MAP: { [MenuTab]: "Food" | "Storage" | "Empire" | "Market" | "Gun" | "Robux" } = {
	Kitchen = "Food",
	Warehouses = "Storage",
	Upgrades = "Empire",
	Market = "Market",
	BlackMarket = "Gun",
	Shop = "Robux",
}

local function refreshTabStyles(): ()
	for tabName, btn in pairs(tabButtons) do
		local active = (tabName == currentTab)
		local theme = TAB_THEMES[tabName]
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		local bar = tabActiveBars[tabName]
		local tLbl = tabLabels[tabName]
		if active then
			btn.BackgroundColor3 = theme.Accent
			btn:SetAttribute("BaseBg", theme.Accent)
			btn:SetAttribute("BaseStroke", Color3.new(1, 1, 1))
			btn.TextColor3 = Color3.new(1, 1, 1)
			if tLbl then tLbl.TextColor3 = Color3.new(1, 1, 1) end
			if stroke then
				stroke.Color = Color3.new(1, 1, 1)
				stroke.Thickness = 2.2
			end
			if bar then bar.Visible = true end
		else
			btn.BackgroundColor3 = C_BG_CARD
			btn:SetAttribute("BaseBg", C_BG_CARD)
			btn:SetAttribute("BaseStroke", C_OUTLINE_DARK)
			btn.TextColor3 = C_TEXT_MUTED
			if tLbl then tLbl.TextColor3 = C_TEXT_MUTED end
			if stroke then
				stroke.Color = C_OUTLINE_DARK
				stroke.Thickness = 1.8
			end
			if bar then bar.Visible = false end
		end
	end

	local curTheme = TAB_THEMES[currentTab]
	if stageHeaderBar and curTheme then
		stageHeaderBar.BackgroundColor3 = curTheme.Accent
	end
	if stageHeaderGrad and curTheme then
		stageHeaderGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, curTheme.Accent),
			ColorSequenceKeypoint.new(0.65, curTheme.Dark),
			ColorSequenceKeypoint.new(1, C_BG_MODAL),
		})
	end
	if stageHeaderIconSlot and lastHeaderIconTab ~= currentTab then
		lastHeaderIconTab = currentTab
		for _, ch in ipairs(stageHeaderIconSlot:GetChildren()) do
			if not ch:IsA("UICorner") and not ch:IsA("UIStroke") then
				ch:Destroy()
			end
		end
		local iconKind = TAB_ICON_MAP[currentTab]
		CurrencyIconHelper.CreateCategoryIcon(stageHeaderIconSlot, iconKind, if iconKind == "Robux" then 32 else 40, if iconKind == "Robux" then UDim2.fromOffset(9, 9) else UDim2.fromOffset(5, 5), 4)
	end
end

local function renderKitchen(state: { [string]: any }): ()
	if not scrollFrame then return end
	local stock = (state.Warehouse and state.Warehouse.Stock) or {}
	local kitchen = state.Kitchen or {}
	local restLevel = (state.Profile and state.Profile.RestaurantLevel) or 1
	local starInfo = state.StarRating
	local starCount = if typeof(starInfo) == "table" and typeof(starInfo.Stars) == "number" then starInfo.Stars else 1
	local starTitle = if typeof(starInfo) == "table" and typeof(starInfo.Title) == "string" then starInfo.Title else "1-STAR STREET DINER"
	local starBonus = if typeof(starInfo) == "table" and typeof(starInfo.BonusPct) == "number" then starInfo.BonusPct else 0

	local craving = state.CityCraving
	local cravingId = if typeof(craving) == "table" then tostring(craving.RecipeId or "") else ""
	local cravingName = if typeof(craving) == "table" then tostring(craving.DisplayName or "Sizzling Steak") else "Sizzling Steak"
	local cravingRem = if typeof(craving) == "table" and typeof(craving.TimeRemaining) == "number" then craving.TimeRemaining else 120
	local curPricing = tostring(state.MenuPricing or "Standard")

	-- Compact Unified Culinary Command Header (Star Rating + Live 2X City Craving + Menu Pricing in ONE sleek bar!)
	local dashCard = makeCard(scrollFrame, 60, C_BRASS)
	dashCard.Name = "KitchenCommandDashboard"

	local starStars = string.rep("*", starCount)
	local dashTop = Instance.new("TextLabel")
	dashTop.Position = UDim2.new(0, 14, 0, 6)
	dashTop.Size = UDim2.new(1, -290, 0, 18)
	dashTop.BackgroundTransparency = 1
	dashTop.Font = Enum.Font.GothamBlack
	dashTop.TextXAlignment = Enum.TextXAlignment.Left
	dashTop.TextTruncate = Enum.TextTruncate.AtEnd
	dashTop.TextSize = 11
	dashTop.TextColor3 = C_GOLD_HI
	dashTop.Text = string.format("%s  (%d/5 %s)  •  +%d%% GOLD & REP", starTitle, starCount, starStars, starBonus)
	dashTop.Parent = dashCard
	addTextOutline(dashTop, 1.3)

	local cravPill = Instance.new("TextLabel")
	cravPill.Position = UDim2.new(0, 14, 0, 29)
	cravPill.Size = UDim2.new(1, -296, 0, 22)
	cravPill.BackgroundColor3 = Color3.fromRGB(48, 18, 28)
	cravPill.Font = Enum.Font.GothamBlack
	cravPill.TextXAlignment = Enum.TextXAlignment.Left
	cravPill.TextTruncate = Enum.TextTruncate.AtEnd
	cravPill.TextSize = 10
	cravPill.TextColor3 = Color3.fromRGB(255, 226, 134)
	cravPill.Text = string.format("  2.0X CITY CRAVING: %s  (%ds LEFT)", string.upper(cravingName), cravingRem)
	cravPill.Parent = dashCard
	makeCorner(cravPill, 6)
	makeStroke(cravPill, C_OXBLOOD, 1.3)

	local pOpts = {
		{ Id = "Budget", Label = "BUDGET +25%R" },
		{ Id = "Standard", Label = "STANDARD" },
		{ Id = "Luxury", Label = "LUXURY +35%G" },
	}
	for i, po in ipairs(pOpts) do
		local isSel = (curPricing == po.Id)
		local pb = makeBtn(
			dashCard,
			po.Label,
			if isSel then C_OWNED else C_BG_SUBTLE,
			UDim2.new(1, -276 + (i - 1) * 90, 0.5, -16),
			UDim2.fromOffset(86, 32),
			function()
				if dispatchAction then dispatchAction("SetMenuPricing", po.Id) end
			end
		)
		pb.TextSize = 8
	end

	-- Live Stove Line Control Strip (with glowing cook progress bar!)
	local banner = makeCard(scrollFrame, 56, C_TEAL)
	banner.Name = "KitchenStoveBar"
	local statusLbl = Instance.new("TextLabel")
	statusLbl.Position = UDim2.new(0, 14, 0, 7)
	statusLbl.Size = UDim2.new(1, -294, 0, 20)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Font = Enum.Font.GothamBlack
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.TextTruncate = Enum.TextTruncate.AtEnd
	statusLbl.TextSize = 11
	statusLbl.TextColor3 = C_TEXT_PRIMARY
	local stoveParts: { string } = {}
	local activeCookPct = 0
	if kitchen.IsCooking and kitchen.CurrentRecipeId then
		local r1 = RecipeConfig.Recipes[kitchen.CurrentRecipeId]
		local total1 = if r1 then math.max(1, r1.CookTime) else 10
		activeCookPct = math.clamp(1 - ((tonumber(kitchen.TimeRemaining) or 0) / total1), 0.08, 1)
		table.insert(stoveParts, string.format("STOVE #1: %s (%.1fs)%s", string.upper(if r1 then r1.DisplayName else kitchen.CurrentRecipeId), kitchen.TimeRemaining or 0, if kitchen.Boosted1 then " [SEARED]" else ""))
	end
	if kitchen.IsCooking2 and kitchen.CurrentRecipeId2 then
		local r2 = RecipeConfig.Recipes[kitchen.CurrentRecipeId2]
		table.insert(stoveParts, string.format("STOVE #2: %s (%.1fs)%s", string.upper(if r2 then r2.DisplayName else kitchen.CurrentRecipeId2), kitchen.TimeRemaining2 or 0, if kitchen.Boosted2 then " [SEARED]" else ""))
	end
	if #stoveParts > 0 then
		statusLbl.Text = table.concat(stoveParts, "  |  ")
	else
		local dualTag = if kitchen.HasDualStove then "DUAL-STOVE LINE READY" else "CHEF STOVE READY"
		statusLbl.Text = string.format("%s  •  %d DISHES READY TO SERVE", dualTag, kitchen.ReadyTotal or 0)
	end
	statusLbl.Parent = banner
	addTextOutline(statusLbl, 1.3)

	local stoveTrack = Instance.new("Frame")
	stoveTrack.Position = UDim2.new(0, 14, 0, 32)
	stoveTrack.Size = UDim2.new(1, -300, 0, 12)
	stoveTrack.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
	stoveTrack.BorderSizePixel = 0
	stoveTrack.Parent = banner
	makeCorner(stoveTrack, 6)
	makeStroke(stoveTrack, C_BORDER, 1.2)
	local stoveFill = Instance.new("Frame")
	stoveFill.Size = UDim2.fromScale(if #stoveParts > 0 then activeCookPct elseif (kitchen.ReadyTotal or 0) > 0 then 1 else 0, 1)
	stoveFill.BackgroundColor3 = if #stoveParts > 0 then C_BRASS else C_OWNED
	stoveFill.BorderSizePixel = 0
	stoveFill.Parent = stoveTrack
	makeCorner(stoveFill, 6)

	local canSear = (kitchen.IsCooking and not kitchen.Boosted1) or (kitchen.IsCooking2 and not kitchen.Boosted2)
	makeBtn(
		banner,
		if canSear then "SEAR BOOST" else "SEAR [E]",
		if canSear then C_BRASS else C_DISABLED,
		UDim2.new(1, -276, 0.5, -17),
		UDim2.fromOffset(118, 34),
		function()
			if dispatchAction then
				dispatchAction("SearBoostCook", nil)
			end
		end
	)

	makeBtn(
		banner,
		string.format("SELL (%d)", kitchen.ReadyTotal or 0),
		if (kitchen.ReadyTotal or 0) > 0 then C_OWNED else C_DISABLED,
		UDim2.new(1, -148, 0.5, -17),
		UDim2.fromOffset(136, 34),
		function()
			if dispatchAction then dispatchAction("ServeFood", nil) end
		end
	)

	-- Active Customer Order Spotlight Card (with gleaming AAA Silver Cloche Icon!)
	local waiting = state.WaitingCustomer
	if typeof(waiting) == "table" and waiting.CustomerName then
		local isCookingOrder = waiting.IsBeingCooked == true
		local orderAcc = if isCookingOrder then C_BRASS else C_OWNED
		local orderCard = makeCard(scrollFrame, 74, orderAcc)
		orderCard.Name = "ActiveOrderSpotlight"
		orderCard.BackgroundColor3 = C_BG_CARD:Lerp(orderAcc, 0.22)
		ModelPreviewHelper.CreatePreview(orderCard, "Dish", "ActiveOrder", UDim2.fromOffset(58, 58), UDim2.new(0, 14, 0.5, -29), Color3.fromRGB(16, 22, 36), orderAcc)

		makeTag(orderCard, if isCookingOrder then "PREPARING" else "GUEST WAITING", orderAcc:Lerp(C_OUTLINE_DARK, 0.2), UDim2.fromOffset(80, 8), UDim2.fromOffset(96, 17))

		local custTitle = Instance.new("TextLabel")
		custTitle.Position = UDim2.new(0, 182, 0, 7)
		custTitle.Size = UDim2.new(1, -340, 0, 19)
		custTitle.BackgroundTransparency = 1
		custTitle.Font = Enum.Font.GothamBlack
		custTitle.TextXAlignment = Enum.TextXAlignment.Left
		custTitle.TextTruncate = Enum.TextTruncate.AtEnd
		custTitle.TextSize = 13
		custTitle.TextColor3 = C_TEXT_PRIMARY
		custTitle.Text = string.upper(tostring(waiting.CustomerName))
		custTitle.Parent = orderCard
		addTextOutline(custTitle, 1.4)

		local custDesc = Instance.new("TextLabel")
		custDesc.Position = UDim2.new(0, 80, 0, 31)
		custDesc.Size = UDim2.new(1, -242, 0, 34)
		custDesc.BackgroundTransparency = 1
		custDesc.Font = Enum.Font.GothamBold
		custDesc.TextWrapped = true
		custDesc.TextXAlignment = Enum.TextXAlignment.Left
		custDesc.TextSize = 12
		custDesc.TextColor3 = C_GOLD_HI
		custDesc.Text = string.format(
			"%s   •   +%d GOLD   •   +%d REP",
			tostring(waiting.DishName or "House Special"),
			tonumber(waiting.BaseGold) or 25,
			tonumber(waiting.BaseRep) or 5
		)
		custDesc.Parent = orderCard

		makeBtn(
			orderCard,
			if isCookingOrder then "COOKING..." else "COOK & SERVE",
			if isCookingOrder then C_DISABLED else C_OWNED,
			UDim2.new(1, -148, 0.5, -18),
			UDim2.fromOffset(136, 36),
			function()
				if not isCookingOrder and dispatchAction then
					dispatchAction("ServeCustomerOrder", nil)
				end
			end
		)
	end

	makeSectionDivider(scrollFrame, "GOURMET MENU COLLECTION  •  READY DISHES FIRST", C_BRASS)

	local whLevels = (state.Warehouse and state.Warehouse.Levels) or {}
	local playerRep = (state.Profile and state.Profile.Reputation) or 0
	-- Modern AAA 2-Column Culinary Collectible Grid (matches Market/Black Market Showcase Quality!)
	local recipeGrid = makeGridContainer(scrollFrame, 2, 224, 10)
	recipeGrid.Name = "KitchenDishGrid"

	-- Sort recipes smartly: 1. Ready to cook -> 2. Unlocked (needs stock) -> 3. Warehouse-locked -> 4. HQ/Rep locked
	local sortedRecipes: { { Id: string, Tier: number, Reward: number } } = {}
	for _, recipeId in ipairs(RecipeConfig.Order) do
		local recipe = RecipeConfig.Recipes[recipeId]
		if recipe then
			local reqWh = WarehouseConfig.GetRequiredWarehousesForIngredients(recipe.Ingredients)
			local whLocked = false
			for _, cat in ipairs(reqWh) do
				if (whLevels[cat] or 0) < 1 then
					whLocked = true
					break
				end
			end
			local repLocked = (recipe.RequiredRep ~= nil and playerRep < recipe.RequiredRep)
			local hqLocked = (restLevel < recipe.RequiredRestaurantLevel)
			local hasStock = true
			for ing, need in pairs(recipe.Ingredients) do
				if (stock[ing] or 0) < need then
					hasStock = false
					break
				end
			end
			local tier = if (not whLocked and not repLocked and not hqLocked and hasStock)
				then 1
				elseif (not whLocked and not repLocked and not hqLocked) then 2
				elseif whLocked then 3
				else 4
			table.insert(sortedRecipes, { Id = recipeId, Tier = tier, Reward = recipe.CoinsReward })
		end
	end
	table.sort(sortedRecipes, function(a, b)
		if a.Tier ~= b.Tier then
			return a.Tier < b.Tier
		end
		return a.Reward > b.Reward
	end)

	local recipeOrder = 0
	for _, entry in ipairs(sortedRecipes) do
		local recipeId = entry.Id
		local recipe = RecipeConfig.Recipes[recipeId]
		if recipe then
			recipeOrder += 1
			local reqWh = WarehouseConfig.GetRequiredWarehousesForIngredients(recipe.Ingredients)
			local missingWhNames: { string } = {}
			local reqWhTags: { string } = {}
			for _, cat in ipairs(reqWh) do
				local spec = WarehouseConfig.Specs[cat]
				table.insert(reqWhTags, if spec then spec.Tag else string.upper(cat))
				if (whLevels[cat] or 0) < 1 then
					table.insert(missingWhNames, if spec then spec.ShortLabel else cat)
				end
			end
			local whLocked = (#missingWhNames > 0)
			local repLocked = (recipe.RequiredRep ~= nil and playerRep < recipe.RequiredRep)
			local hqLocked = (restLevel < recipe.RequiredRestaurantLevel)
			local isCravingDish = (recipeId == cravingId)
			local hasAllStock = true
			local ingRows: { { Name: string, Have: number, Need: number, Ok: boolean } } = {}
			for ing, need in pairs(recipe.Ingredients) do
				local have = stock[ing] or 0
				local ok = (have >= need)
				if not ok then hasAllStock = false end
				local ingName = WarehouseConfig.IngredientDisplayNames[ing] or ing
				table.insert(ingRows, { Name = ingName, Have = have, Need = need, Ok = ok })
			end
			table.sort(ingRows, function(a, b) return a.Name < b.Name end)
			local canCookNow = (not whLocked) and (not repLocked) and (not hqLocked) and hasAllStock

			local themeCol = if isCravingDish
				then C_OXBLOOD
				elseif canCookNow then C_OWNED
				elseif whLocked then Color3.fromRGB(162, 54, 72)
				elseif recipe.IsSecretSyndicate then Color3.fromRGB(168, 85, 247)
				elseif recipe.CoinsReward >= 200 then C_BRASS
				else C_STEEL

			local card = Instance.new("Frame")
			card.Name = "DishCard_" .. recipeId
			card.LayoutOrder = recipeOrder
			card.BackgroundColor3 = if whLocked
				then Color3.fromRGB(22, 18, 28)
				else C_BG_CARD:Lerp(themeCol, if isCravingDish then 0.22 else 0.14)
			card.BorderSizePixel = 0
			card.ClipsDescendants = true
			card.Parent = recipeGrid
			makeCorner(card, 12)
			makeStroke(card, if isCravingDish then C_GOLD_HI else themeCol:Lerp(C_OUTLINE_DARK, 0.22), if isCravingDish then 2.6 else 2.2)

			-- Radiant AAA Culinary Showcase Bay with huge floating hand-painted dish icon!
			local topBay = createShowcasePedestalBay(card, 94, themeCol, "Dish", recipeId, false)

			local leftBadgeTxt = if isCravingDish
				then "2X CRAVING!"
				elseif whLocked then "LOCKED"
				elseif canCookNow then "READY!"
				elseif recipe.IsSecretSyndicate then "SECRET VIP"
				elseif recipe.CoinsReward >= 200 then "GOURMET"
				else table.concat(reqWhTags, "+")
			local leftBadgeCol = if isCravingDish
				then C_OXBLOOD
				elseif whLocked then C_OXBLOOD_DARK
				elseif canCookNow then C_OWNED
				elseif recipe.IsSecretSyndicate then Color3.fromRGB(124, 58, 237)
				else themeCol:Lerp(C_OUTLINE_DARK, 0.25)
			makeTag(topBay, leftBadgeTxt, leftBadgeCol, UDim2.fromOffset(8, 7), UDim2.fromOffset(78, 17))

			-- Gleaming 24K Gold Payout Pill in top-right of showcase bay!
			local payPill = Instance.new("Frame")
			payPill.AnchorPoint = Vector2.new(1, 0)
			payPill.Position = UDim2.new(1, -8, 0, 6)
			payPill.Size = UDim2.fromOffset(78, 20)
			payPill.BackgroundColor3 = Color3.fromRGB(26, 20, 10)
			payPill.BorderSizePixel = 0
			payPill.Parent = topBay
			makeCorner(payPill, 6)
			makeStroke(payPill, C_GOLD_HI, 1.4)
			CurrencyIconHelper.CreateGoldCoin(payPill, 14, UDim2.new(0, 4, 0.5, -7), 3)
			local payTxt = Instance.new("TextLabel")
			payTxt.Position = UDim2.fromOffset(21, 0)
			payTxt.Size = UDim2.new(1, -23, 1, 0)
			payTxt.BackgroundTransparency = 1
			payTxt.Font = Enum.Font.GothamBlack
			payTxt.TextXAlignment = Enum.TextXAlignment.Left
			payTxt.TextSize = 10
			payTxt.TextColor3 = C_GOLD_HI
			payTxt.Text = string.format("+%dG", recipe.CoinsReward)
			payTxt.Parent = payPill
			addTextOutline(payTxt, 1.2)

			-- Bottom-left cook time & bottom-right Rep tags inside bay
			makeTag(topBay, string.format("%.0fs COOK", recipe.CookTime), Color3.fromRGB(16, 22, 36), UDim2.new(0, 8, 1, -22), UDim2.fromOffset(64, 15))
			makeTag(topBay, string.format("+%d REP", recipe.ReputationReward), Color3.fromRGB(20, 32, 52), UDim2.new(1, -68, 1, -22), UDim2.fromOffset(60, 15))

			-- Bold Outlined Dish Title
			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 10, 0, 99)
			nameLbl.Size = UDim2.new(1, -20, 0, 20)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.GothamBlack
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nameLbl.TextSize = 13
			nameLbl.TextColor3 = if isCravingDish then C_GOLD_HI elseif whLocked then Color3.fromRGB(232, 182, 188) else C_TEXT_PRIMARY
			nameLbl.Text = string.upper(recipe.DisplayName)
			nameLbl.Parent = card
			addTextOutline(nameLbl, 1.5)

			-- Visual Color-Coded Ingredient Stock Chips (or Crimson Warehouse Lock Banner)
			if whLocked then
				local lockPill = Instance.new("TextLabel")
				lockPill.Position = UDim2.new(0, 10, 0, 122)
				lockPill.Size = UDim2.new(1, -20, 0, 46)
				lockPill.BackgroundColor3 = Color3.fromRGB(46, 18, 26)
				lockPill.Font = Enum.Font.GothamBold
				lockPill.TextWrapped = true
				lockPill.TextTruncate = Enum.TextTruncate.AtEnd
				lockPill.TextXAlignment = Enum.TextXAlignment.Left
				lockPill.TextSize = 10
				lockPill.TextColor3 = Color3.fromRGB(255, 196, 196)
				lockPill.Text = "  LOCKED: Unlock " .. table.concat(missingWhNames, " + ") .. " in Storage [B]"
				lockPill.Parent = card
				makeCorner(lockPill, 6)
				makeStroke(lockPill, C_OXBLOOD, 1.2)
			else
				local chipWrap = Instance.new("Frame")
				chipWrap.Position = UDim2.new(0, 10, 0, 122)
				chipWrap.Size = UDim2.new(1, -20, 0, 48)
				chipWrap.BackgroundTransparency = 1
				chipWrap.Parent = card
				local chipGrid = Instance.new("UIGridLayout")
				chipGrid.FillDirection = Enum.FillDirection.Horizontal
				chipGrid.SortOrder = Enum.SortOrder.LayoutOrder
				chipGrid.CellPadding = UDim2.fromOffset(5, 4)
				local cols = if #ingRows <= 2 then math.max(1, #ingRows) else 2
				chipGrid.CellSize = UDim2.new(1 / cols, if cols == 2 then -3 else 0, 0, 21)
				chipGrid.Parent = chipWrap

				for cIdx, ir in ipairs(ingRows) do
					local chip = Instance.new("TextLabel")
					chip.LayoutOrder = cIdx
					chip.BackgroundColor3 = if ir.Ok then Color3.fromRGB(16, 56, 36) else Color3.fromRGB(28, 22, 34)
					chip.Font = Enum.Font.GothamBold
					chip.TextTruncate = Enum.TextTruncate.AtEnd
					chip.TextSize = 9
					chip.TextColor3 = if ir.Ok then Color3.fromRGB(142, 248, 178) else Color3.fromRGB(246, 182, 168)
					chip.Text = string.format("%s %d/%d", ir.Name, ir.Have, ir.Need)
					chip.Parent = chipWrap
					makeCorner(chip, 5)
					makeStroke(chip, if ir.Ok then C_OWNED else Color3.fromRGB(118, 56, 68), 1.1)
				end
			end

			local allStovesBusy = kitchen.IsCooking and (not kitchen.HasDualStove or kitchen.IsCooking2)
			local btnText = if whLocked
				then "UNLOCK WAREHOUSE"
				elseif repLocked then string.format("REQ %d REP", recipe.RequiredRep or 150)
				elseif hqLocked then string.format("HQ LV.%d LOCK", recipe.RequiredRestaurantLevel)
				elseif allStovesBusy then "STOVES BUSY"
				elseif not hasAllStock then "NEED STOCK"
				else "COOK DISH"
			local btnColor = if whLocked
				then C_STEEL
				elseif canCookNow and not allStovesBusy then C_OWNED
				else C_DISABLED

			local cBtn = makeBtn(
				card,
				btnText,
				btnColor,
				UDim2.new(0, 10, 1, -46),
				UDim2.new(1, -20, 0, 36),
				function()
					if whLocked then
						EmpireMenuController.ToggleTab("Warehouses")
					elseif dispatchAction then
						dispatchAction("CookRecipe", recipeId)
					end
				end
			)
			cBtn.TextSize = 11
		end
	end

	local receipts = state.Receipts
	local receiptCount = if typeof(receipts) == "table" then #receipts else 0
	local ledgerHeight = math.max(78, 40 + math.min(receiptCount, 5) * 18)
	local ledger = makeCard(scrollFrame, ledgerHeight, C_BORDER_STRONG)

	local ledgerHead = Instance.new("TextLabel")
	ledgerHead.Position = UDim2.new(0, 16, 0, 8)
	ledgerHead.Size = UDim2.new(1, -28, 0, 20)
	ledgerHead.BackgroundTransparency = 1
	ledgerHead.Font = Enum.Font.GothamBlack
	ledgerHead.TextXAlignment = Enum.TextXAlignment.Left
	ledgerHead.TextSize = 12
	ledgerHead.TextColor3 = C_BRASS
	ledgerHead.Text = string.format("RECENT LEDGER RECEIPTS (%d)", receiptCount)
	ledgerHead.Parent = ledger

	local lines: { string } = {}
	if typeof(receipts) == "table" and #receipts > 0 then
		for i = 1, math.min(#receipts, 5) do
			local rec = receipts[i]
			if typeof(rec) == "table" then
				table.insert(lines, string.format(
					"#%d  |  %s  |  %s  |  +%dG (+%d Rep)  [%s]",
					tonumber(rec.OrderNo) or i,
					tostring(rec.CustomerName or "Guest"),
					tostring(rec.DishName or "Meal"),
					tonumber(rec.GoldEarned) or 0,
					tonumber(rec.RepEarned) or 0,
					tostring(rec.ChefName or "Chef")
				))
			end
		end
	else
		table.insert(lines, "No receipts recorded yet.")
	end

	local ledgerBody = Instance.new("TextLabel")
	ledgerBody.Position = UDim2.new(0, 16, 0, 30)
	ledgerBody.Size = UDim2.new(1, -28, 1, -36)
	ledgerBody.BackgroundTransparency = 1
	ledgerBody.Font = Enum.Font.Code
	ledgerBody.TextWrapped = true
	ledgerBody.TextXAlignment = Enum.TextXAlignment.Left
	ledgerBody.TextYAlignment = Enum.TextYAlignment.Top
	ledgerBody.TextSize = 11
	ledgerBody.TextColor3 = C_TEXT_MUTED
	ledgerBody.Text = table.concat(lines, "\n")
	ledgerBody.Parent = ledger
end

local function renderWarehouses(state: { [string]: any }): ()
	if not scrollFrame then return end
	local wh = state.Warehouse or {}
	local levels = wh.Levels or {}
	local stock = wh.Stock or {}
	local totals = wh.CategoryTotals or {}
	local caps = wh.Capacities or {}

	local catColors: { [string]: Color3 } = {
		Fish = Color3.fromRGB(14, 165, 233),
		Meat = Color3.fromRGB(225, 29, 72),
		Vegetable = Color3.fromRGB(22, 163, 74),
		Fruit = Color3.fromRGB(245, 158, 11),
	}

	makeSectionDivider(scrollFrame, "INGREDIENT SUPPLY WAREHOUSES  •  STEAL MAFIA SHIPMENTS TO FILL FAST", C_STEEL)

	-- 2x2 Big AAA Isometric Warehouse Showcase Grid!
	local grid = makeGridContainer(scrollFrame, 2, 272, 10)
	grid.Name = "WarehouseCardGrid"
	for idx, category in ipairs(WarehouseConfig.Categories) do
		local spec = WarehouseConfig.Specs[category]
		local level = levels[category] or 0
		local isLocked = (level <= 0)
		local total = totals[category] or 0
		local cap = caps[category] or 0
		local nextTier = WarehouseConfig.Tiers[level + 1]
		local themeCol = if isLocked then C_BORDER_STRONG else (catColors[category] or C_STEEL)

		local card = Instance.new("Frame")
		card.Name = "WarehouseCard_" .. category
		card.LayoutOrder = idx
		card.BackgroundColor3 = C_BG_CARD:Lerp(themeCol, if isLocked then 0.08 else 0.16)
		card.BorderSizePixel = 0
		card.ClipsDescendants = true
		card.Parent = grid
		makeCorner(card, 12)
		makeStroke(card, themeCol:Lerp(C_OUTLINE_DARK, 0.2), 2.2)

		-- Radiant AAA Isometric Warehouse Building Pedestal Bay!
		local topBay = createShowcasePedestalBay(card, 102, themeCol, "Warehouse", category, false)
		makeTag(topBay, spec.Tag, themeCol:Lerp(C_OUTLINE_DARK, 0.25), UDim2.fromOffset(8, 7), UDim2.fromOffset(56, 17))
		makeTag(
			topBay,
			if isLocked then "LOCKED" else string.format("LV.%d / %d", level, WarehouseConfig.MaxLevel),
			if isLocked then C_OXBLOOD_DARK else C_OWNED,
			UDim2.new(1, -74, 0, 7),
			UDim2.fromOffset(66, 17)
		)
		makeTag(
			topBay,
			if isLocked then "UNLOCK TO STEAL" else string.format("STOCK %d / %d", total, cap),
			Color3.fromRGB(16, 22, 36),
			UDim2.new(0, 8, 1, -22),
			UDim2.fromOffset(108, 15)
		)

		local hLbl = Instance.new("TextLabel")
		hLbl.Position = UDim2.new(0, 10, 0, 107)
		hLbl.Size = UDim2.new(1, -20, 0, 19)
		hLbl.BackgroundTransparency = 1
		hLbl.Font = Enum.Font.GothamBlack
		hLbl.TextXAlignment = Enum.TextXAlignment.Left
		hLbl.TextTruncate = Enum.TextTruncate.AtEnd
		hLbl.TextSize = 13
		hLbl.TextColor3 = C_TEXT_PRIMARY
		hLbl.Text = string.upper(spec.DisplayName)
		hLbl.Parent = card
		addTextOutline(hLbl, 1.5)

		-- Chunky Glossy Capacity Progress Bar
		local barBg = Instance.new("Frame")
		barBg.Position = UDim2.new(0, 10, 0, 129)
		barBg.Size = UDim2.new(1, -20, 0, 10)
		barBg.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
		barBg.BorderSizePixel = 0
		barBg.Parent = card
		makeCorner(barBg, 5)
		makeStroke(barBg, C_OUTLINE_DARK, 1.4)
		local barFill = Instance.new("Frame")
		barFill.Size = UDim2.fromScale(if not isLocked and cap > 0 then math.clamp(total / cap, 0, 1) else 0, 1)
		barFill.BackgroundColor3 = themeCol
		barFill.BorderSizePixel = 0
		barFill.Parent = barBg
		makeCorner(barFill, 5)

		-- Individual Ingredient Stock Pill Chips!
		local ingRow = Instance.new("Frame")
		ingRow.Position = UDim2.new(0, 10, 0, 144)
		ingRow.Size = UDim2.new(1, -20, 0, 22)
		ingRow.BackgroundTransparency = 1
		ingRow.Parent = card
		local il = Instance.new("UIListLayout")
		il.FillDirection = Enum.FillDirection.Horizontal
		il.SortOrder = Enum.SortOrder.LayoutOrder
		il.Padding = UDim.new(0, 4)
		il.Parent = ingRow

		local maxChips = math.min(#spec.Ingredients, 4)
		for iIdx = 1, maxChips do
			local ing = spec.Ingredients[iIdx]
			local ingName = WarehouseConfig.IngredientDisplayNames[ing] or ing
			local qty = stock[ing] or 0
			local pill = Instance.new("TextLabel")
			pill.LayoutOrder = iIdx
			pill.Size = UDim2.new(1 / maxChips, -3, 1, 0)
			pill.BackgroundColor3 = if not isLocked and qty > 0 then Color3.fromRGB(16, 48, 36) else Color3.fromRGB(16, 22, 34)
			pill.Font = Enum.Font.GothamBold
			pill.TextTruncate = Enum.TextTruncate.AtEnd
			pill.TextSize = 9
			pill.TextColor3 = if not isLocked and qty > 0 then Color3.fromRGB(154, 248, 188) else C_TEXT_MUTED
			pill.Text = if isLocked then ingName else string.format("%s: %d", ingName, qty)
			pill.Parent = ingRow
			makeCorner(pill, 5)
			makeStroke(pill, if not isLocked and qty > 0 then themeCol:Lerp(C_OUTLINE_DARK, 0.35) else C_BORDER, 1)
		end

		local dishLbl = Instance.new("TextLabel")
		dishLbl.Position = UDim2.new(0, 10, 0, 171)
		dishLbl.Size = UDim2.new(1, -20, 0, 42)
		dishLbl.BackgroundTransparency = 1
		dishLbl.Font = Enum.Font.GothamBold
		dishLbl.TextWrapped = true
		dishLbl.TextTruncate = Enum.TextTruncate.AtEnd
		dishLbl.TextXAlignment = Enum.TextXAlignment.Left
		dishLbl.TextYAlignment = Enum.TextYAlignment.Top
		dishLbl.TextSize = 10
		dishLbl.TextColor3 = if isLocked then Color3.fromRGB(246, 206, 128) else Color3.fromRGB(172, 228, 196)
		dishLbl.Text = string.format("DISHES: %s\nRAID: %s", spec.FoodUnlockSummary, spec.ShipmentShortName)
		dishLbl.Parent = card

		if isLocked then
			local unlockRobux = MonetizationConfig.DualRobuxOptions.UnlockWarehouse.RobuxPrice
			local gBtn = makeBtn(card, string.format("UNLOCK %sG", formatCommaInt(spec.UnlockCost)), C_OXBLOOD, UDim2.new(0, 10, 1, -46), UDim2.new(0.58, -12, 0, 36), function()
				if dispatchAction then dispatchAction("UpgradeWarehouse", category) end
			end)
			gBtn.TextSize = 11
			local rBtn = makeBtn(card, string.format("R$ %d", unlockRobux), C_ROBUX, UDim2.new(0.58, 2, 1, -46), UDim2.new(0.42, -12, 0, 36), function()
				if dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "UpgradeWarehouse", Arg = category }) end
			end)
			rBtn.TextSize = 11
		else
			makeBtn(card, "MOVE", C_BG_SUBTLE, UDim2.new(0, 10, 1, -46), UDim2.fromOffset(62, 36), function()
				if dispatchAction then dispatchAction("MoveWarehouse", category) end
			end)
			if nextTier then
				local upgRobux = MonetizationConfig.DualRobuxOptions.UpgradeWarehouse.RobuxPrice
				local uBtn = makeBtn(
					card,
					string.format("UPG %sG", formatCommaInt(nextTier.UpgradeCost)),
					C_OWNED,
					UDim2.new(0, 78, 1, -46),
					UDim2.new(1, -174, 0, 36),
					function()
						if dispatchAction then dispatchAction("UpgradeWarehouse", category) end
					end
				)
				uBtn.TextSize = 10
				local rBtn = makeBtn(
					card,
					string.format("R$ %d", upgRobux),
					C_ROBUX,
					UDim2.new(1, -90, 1, -46),
					UDim2.fromOffset(80, 36),
					function()
						if dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "UpgradeWarehouse", Arg = category }) end
					end
				)
				rBtn.TextSize = 11
			else
				makeBtn(
					card,
					"MAX LEVEL",
					C_DISABLED,
					UDim2.new(0, 78, 1, -46),
					UDim2.new(1, -88, 0, 36),
					function() end
				)
			end
		end
	end
end

local function renderTimedSecurityContracts(state: { [string]: any }): ()
	if not scrollFrame then return end
	local profile = state.Profile or {}
	local playerCoins = tonumber(profile.Coins) or 0
	local hcCfg = RestaurantSecurityConfig.HiredCompanions
	local hcState = if typeof(state.HiredCompanions) == "table" then state.HiredCompanions else {}
	local hcContracts = if typeof(hcState.Contracts) == "table" then hcState.Contracts else {}
	local hcActiveCount = tonumber(hcState.ActiveCount) or 0
	local hcMax = tonumber(hcState.MaxActive) or hcCfg.MaxActiveContractsPerPlayer

	makeSectionDivider(
		scrollFrame,
		string.format("TIMED RESTAURANT DEFENDERS (%d / %d ACTIVE)  •  5M / 10M CONTRACTS  •  AUTO-RESPAWNS IN %ds", hcActiveCount, hcMax, hcCfg.RespawnDelaySeconds),
		C_GOLD_HI
	)

	-- Modern 2-Column Collectible Showcase Grid for all 4 Timed Defenders (Shadow Ninja, Crimson Assassin, Restaurant Bodyguard, Elite Bodyguard — Dual Gold & Robux!)
	local grid = makeGridContainer(scrollFrame, 2, 286, 10)
	grid.Name = "TimedDefenderGrid"

	for idx, compType in ipairs(hcCfg.TypeOrder) do
		local cSpec = hcCfg.Types[compType]
		if not cSpec then continue end
		local activeEntry = hcContracts[compType]
		local isDeployed = typeof(activeEntry) == "table" and activeEntry.State ~= "Expired"
		local isRespawning = isDeployed and activeEntry.State == "Respawning"
		local remSec = if isDeployed then (tonumber(activeEntry.TimeRemaining) or 0) else 0
		local respSec = if isRespawning then (tonumber(activeEntry.RespawnRemaining) or 0) else 0
		local themeCol = if isRespawning then C_GOLD_HI elseif isDeployed then C_OWNED else cSpec.AccentColor

		local card = Instance.new("Frame")
		card.Name = "TimedDefenderCard_" .. compType
		card.LayoutOrder = idx
		card.BackgroundColor3 = C_BG_CARD:Lerp(themeCol, 0.14)
		card.BorderSizePixel = 0
		card.ClipsDescendants = true
		card.Parent = grid
		makeCorner(card, 12)
		makeStroke(card, themeCol:Lerp(C_OUTLINE_DARK, 0.22), 2.2)

		local topBay = createShowcasePedestalBay(card, 92, themeCol, cSpec.PreviewCategory, cSpec.PreviewId, false)
		makeTag(topBay, cSpec.RoleTag, cSpec.AccentColor:Lerp(C_OUTLINE_DARK, 0.22), UDim2.fromOffset(8, 7), UDim2.fromOffset(118, 16))
		local statusTagTxt = if isRespawning then "RESPAWNING" elseif isDeployed then "DEPLOYED" else "5M / 10M"
		local statusTagCol = if isRespawning then C_BRASS elseif isDeployed then C_OWNED else Color3.fromRGB(16, 22, 36)
		makeTag(topBay, statusTagTxt, statusTagCol, UDim2.new(1, -86, 0, 7), UDim2.fromOffset(78, 16))

		local title = Instance.new("TextLabel")
		title.Position = UDim2.new(0, 10, 0, 98)
		title.Size = UDim2.new(1, -20, 0, 19)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.TextSize = 14
		title.TextColor3 = C_TEXT_PRIMARY
		title.Text = string.upper(cSpec.DisplayName)
		title.Parent = card
		addTextOutline(title, 1.5)

		-- 4 Color-Coded Stat Pills (HP / DMG / SPD / STYLE)
		local statRow = Instance.new("Frame")
		statRow.Position = UDim2.new(0, 10, 0, 121)
		statRow.Size = UDim2.new(1, -20, 0, 19)
		statRow.BackgroundTransparency = 1
		statRow.Parent = card
		local statPills = {
			{ Text = string.format("HP %d", cSpec.MaxHealth), Col = C_OWNED },
			{ Text = string.format("DMG %d", cSpec.Damage), Col = C_OXBLOOD },
			{ Text = string.format("SPD %.0f", cSpec.WalkSpeed), Col = C_BRASS },
			{ Text = if cSpec.CombatStyle == "Melee" then "BLADE" else "RANGED", Col = cSpec.AccentColor },
		}
		for sIdx, sp in ipairs(statPills) do
			local pill = Instance.new("TextLabel")
			pill.Position = UDim2.new((sIdx - 1) * 0.255, 0, 0, 0)
			pill.Size = UDim2.new(0.24, 0, 1, 0)
			pill.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
			pill.Font = Enum.Font.GothamBold
			pill.TextSize = 9
			pill.TextColor3 = sp.Col:Lerp(Color3.new(1, 1, 1), 0.35)
			pill.Text = sp.Text
			pill.Parent = statRow
			makeCorner(pill, 4)
			makeStroke(pill, sp.Col:Lerp(C_OUTLINE_DARK, 0.45), 1)
		end

		local desc = Instance.new("TextLabel")
		desc.Position = UDim2.new(0, 10, 0, 145)
		desc.Size = UDim2.new(1, -20, 0, 46)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.GothamMedium
		desc.TextWrapped = true
		desc.TextTruncate = Enum.TextTruncate.AtEnd
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextSize = 10
		desc.TextColor3 = C_TEXT_MUTED
		desc.Text = cSpec.Description
		desc.Parent = card

		if isDeployed then
			local m = math.floor(remSec / 60)
			local s = remSec % 60
			local statusBadge = Instance.new("TextLabel")
			statusBadge.Position = UDim2.new(0, 10, 1, -56)
			statusBadge.Size = UDim2.new(1, -20, 0, 44)
			statusBadge.BackgroundColor3 = if isRespawning then Color3.fromRGB(78, 52, 16) else Color3.fromRGB(22, 68, 42)
			statusBadge.Font = Enum.Font.GothamBlack
			statusBadge.TextWrapped = true
			statusBadge.TextSize = 11
			statusBadge.TextColor3 = if isRespawning then Color3.fromRGB(255, 224, 128) else Color3.fromRGB(168, 245, 194)
			statusBadge.Text = if isRespawning
				then string.format("RESPAWNING IN %ds  •  %02d:%02d LEFT", respSec, m, s)
				else string.format("DEFENDING HQ  •  %02d:%02d LEFT", m, s)
			statusBadge.Parent = card
			makeCorner(statusBadge, 8)
			makeStroke(statusBadge, if isRespawning then C_GOLD_HI else C_OWNED, 1.5)
		else
			-- Row 1: Gold 5m & 10m Options
			local b5 = makeBtn(
				card,
				string.format("5M %sG", formatCommaInt(cSpec.Cost5Min)),
				if playerCoins >= cSpec.Cost5Min then C_TEAL else C_DISABLED,
				UDim2.new(0, 10, 1, -84),
				UDim2.new(0.5, -13, 0, 34),
				function()
					if dispatchAction then
						dispatchAction("HireDefenseCompanion", { CompanionType = cSpec.Id, DurationMinutes = 5 })
					end
				end
			)
			b5.TextSize = 10

			local b10 = makeBtn(
				card,
				string.format("10M %sG", formatCommaInt(cSpec.Cost10Min)),
				if playerCoins >= cSpec.Cost10Min then C_BRASS else C_DISABLED,
				UDim2.new(0.5, 3, 1, -84),
				UDim2.new(0.5, -13, 0, 34),
				function()
					if dispatchAction then
						dispatchAction("HireDefenseCompanion", { CompanionType = cSpec.Id, DurationMinutes = 10 })
					end
				end
			)
			b10.TextSize = 10

			-- Row 2: Robux 5m & 10m Dual-Currency Options
			local r5 = makeBtn(
				card,
				string.format("5M R$ %d", cSpec.Robux5Min),
				C_ROBUX,
				UDim2.new(0, 10, 1, -44),
				UDim2.new(0.5, -13, 0, 34),
				function()
					if dispatchAction then
						dispatchAction("BuyWithRobuxOption", { Kind = "HireDefenseCompanion", Arg = { CompanionType = cSpec.Id, DurationMinutes = 5 } })
					end
				end
			)
			r5.TextSize = 10

			local r10 = makeBtn(
				card,
				string.format("10M R$ %d", cSpec.Robux10Min),
				C_ROBUX,
				UDim2.new(0.5, 3, 1, -44),
				UDim2.new(0.5, -13, 0, 34),
				function()
					if dispatchAction then
						dispatchAction("BuyWithRobuxOption", { Kind = "HireDefenseCompanion", Arg = { CompanionType = cSpec.Id, DurationMinutes = 10 } })
					end
				end
			)
			r10.TextSize = 10
		end
	end
end

local function renderSecurityHub(state: { [string]: any }): ()
	if not scrollFrame then return end
	local profile = state.Profile or {}
	local defLv = tonumber(profile.DefenseLevel) or 1
	local bgState = if typeof(state.Bodyguards) == "table" then state.Bodyguards else {}
	local activeSquad = if typeof(bgState.ActiveSquad) == "table" then bgState.ActiveSquad else {}
	local hcState = if typeof(state.HiredCompanions) == "table" then state.HiredCompanions else {}
	local hcActiveCount = tonumber(hcState.ActiveCount) or 0
	local hcMax = tonumber(hcState.MaxActive) or RestaurantSecurityConfig.HiredCompanions.MaxActiveContractsPerPlayer

	local hubBanner = makeCard(scrollFrame, 56, C_TEAL)
	hubBanner.Name = "SecurityHubBanner"
	local hLbl = Instance.new("TextLabel")
	hLbl.Position = UDim2.new(0, 14, 0, 6)
	hLbl.Size = UDim2.new(1, -28, 1, -12)
	hLbl.BackgroundTransparency = 1
	hLbl.Font = Enum.Font.GothamBold
	hLbl.TextWrapped = true
	hLbl.TextXAlignment = Enum.TextXAlignment.Left
	hLbl.TextSize = 11
	hLbl.TextColor3 = C_TEXT_PRIMARY
	hLbl.Text = string.format(
		"UNIFIED RESTAURANT SECURITY & BODYGUARD HUB  |  PERMANENT SQUAD: %d / %d  •  TIMED DEFENDERS: %d / %d  •  TURRETS TIER %d / 3\nCommand all 8 permanent Bodyguard classes, outfit all 18 Guard Gear items, or deploy 5m/10m Timed Defenders.",
		#activeSquad,
		BodyguardConfig.MAX_ACTIVE_GUARDS,
		hcActiveCount,
		hcMax,
		defLv
	)
	hLbl.Parent = hubBanner

	-- 3 Clean Security Hub Category Pills (Timed Contracts | All 8 Bodyguards | All 18 Guard Gear)
	local viewBar = Instance.new("Frame")
	viewBar.Name = "SecurityViewBar"
	viewBar.Size = UDim2.new(1, -6, 0, 34)
	viewBar.BackgroundTransparency = 1
	viewBar.Parent = scrollFrame
	local vl = Instance.new("UIListLayout")
	vl.FillDirection = Enum.FillDirection.Horizontal
	vl.SortOrder = Enum.SortOrder.LayoutOrder
	vl.Padding = UDim.new(0, 6)
	vl.Parent = viewBar

	local secViews: { { Id: SecuritySubView, Label: string, Col: Color3 } } = {
		{ Id = "Timed", Label = string.format("TIMED DEFENDERS (%d)", #RestaurantSecurityConfig.HiredCompanions.TypeOrder), Col = C_BRASS },
		{ Id = "Classes", Label = string.format("ALL BODYGUARDS (%d)", #BodyguardConfig.CLASS_ORDER), Col = C_TEAL },
		{ Id = "Gear", Label = string.format("ALL GUARD GEAR (%d)", #BodyguardConfig.GEAR_ORDER), Col = C_STEEL },
	}
	for vIdx, sv in ipairs(secViews) do
		local active = (currentSecuritySubView == sv.Id)
		local vb = makeBtn(viewBar, sv.Label, if active then sv.Col else C_BG_CARD_ALT, UDim2.new(), UDim2.new(1 / 3, -4, 0, 32), function()
			AudioController.PlayClick()
			currentSecuritySubView = sv.Id
			render()
		end)
		vb.Name = "SecurityView_" .. sv.Id
		vb.LayoutOrder = vIdx
		vb.TextSize = 10
		if active then
			local st = vb:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = C_GOLD_HI
				st.Thickness = 1.8
			end
		end
	end

	if currentSecuritySubView == "Timed" then
		renderTimedSecurityContracts(state)
	elseif currentSecuritySubView == "Classes" then
		renderBodyguardsForTier(state, "All", "Classes", true)
	else
		renderBodyguardsForTier(state, "All", "Gear", true)
	end
end

local function renderUpgrades(state: { [string]: any }): ()
	if not scrollFrame then return end
	local profile = state.Profile or {}
	local restLv = profile.RestaurantLevel or 1
	local defLv = profile.DefenseLevel or 1
	local crewCount = profile.CrewCount or 0
	local maxCrew = state.MaxCrew or 2
	local nextCrewCost = state.NextCrewCost or 180

	-- Top 3-Tab Empire Navigation Bar: HQ & STAFF | SECURITY HUB | SYNDICATE OPS (cleanly eliminates 35-row endless scroll!)
	local empSubBar = Instance.new("Frame")
	empSubBar.Name = "EmpireSubTabBar"
	empSubBar.Size = UDim2.new(1, -6, 0, 38)
	empSubBar.BackgroundTransparency = 1
	empSubBar.Parent = scrollFrame
	local esl = Instance.new("UIListLayout")
	esl.FillDirection = Enum.FillDirection.Horizontal
	esl.SortOrder = Enum.SortOrder.LayoutOrder
	esl.Padding = UDim.new(0, 6)
	esl.Parent = empSubBar

	local bgStateTop = if typeof(state.Bodyguards) == "table" then state.Bodyguards else {}
	local sqCountTop = if typeof(bgStateTop.ActiveSquad) == "table" then #bgStateTop.ActiveSquad else 0
	local hcCountTop = if typeof(state.HiredCompanions) == "table" then (tonumber(state.HiredCompanions.ActiveCount) or 0) else 0
	local totalSecActive = sqCountTop + hcCountTop

	local empTabs: { { Id: EmpireSubTab, Label: string, ActiveCol: Color3, Icon: "Empire" | "Guard" | "Ninja" } } = {
		{ Id = "HQ", Label = "HQ & STAFF", ActiveCol = C_BRASS, Icon = "Empire" },
		{ Id = "Security", Label = if totalSecActive > 0 then string.format("SECURITY HUB (%d)", totalSecActive) else "SECURITY HUB", ActiveCol = C_TEAL, Icon = "Guard" },
		{ Id = "Syndicate", Label = "SYNDICATE OPS", ActiveCol = C_OXBLOOD, Icon = "Ninja" },
	}
	for tIdx, et in ipairs(empTabs) do
		local active = (currentEmpireSubTab == et.Id)
		local btn = makeBtn(empSubBar, "", if active then et.ActiveCol else C_BG_CARD_ALT, UDim2.new(), UDim2.new(1 / 3, -4, 0, 36), function()
			AudioController.PlayClick()
			currentEmpireSubTab = et.Id
			if scrollFrame then
				scrollFrame.CanvasPosition = Vector2.new(0, 0)
			end
			render()
		end)
		btn.Name = "EmpireSubTab_" .. et.Id
		btn.LayoutOrder = tIdx
		CurrencyIconHelper.CreateCategoryIcon(btn, et.Icon, 24, UDim2.new(0, 10, 0.5, -12), btn.ZIndex + 2)
		local lbl = Instance.new("TextLabel")
		lbl.Name = "SubTabLabel"
		lbl.Position = UDim2.fromOffset(40, 0)
		lbl.Size = UDim2.new(1, -44, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		lbl.Text = et.Label
		lbl.TextSize = 11
		lbl.TextColor3 = if active then Color3.new(1, 1, 1) else C_TEXT_PRIMARY
		lbl.ZIndex = btn.ZIndex + 2
		lbl.Active = false
		lbl.Parent = btn
		addTextOutline(lbl, 1.4)
		if active then
			local st = btn:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = C_GOLD_HI
				st.Thickness = 1.8
			end
		end
	end

	if currentEmpireSubTab == "Security" then
		renderSecurityHub(state)
		return
	end

	local function addUpgradeRow(
		code: string,
		titleTxt: string,
		descTxt: string,
		btnTxt: string,
		btnBg: Color3,
		onClick: () -> (),
		robuxPrice: number?,
		onRobuxClick: (() -> ())?
	): Frame
		local hasDual = (typeof(robuxPrice) == "number" and robuxPrice > 0 and onRobuxClick ~= nil)
		local cardAcc = if btnBg == C_DISABLED then C_BORDER_STRONG else btnBg
		local card = makeCard(scrollFrame :: ScrollingFrame, if hasDual then 94 else 88, cardAcc)
		local vp = ModelPreviewHelper.CreatePreview(card, "Empire", code, UDim2.fromOffset(60, 60), UDim2.new(0, 14, 0.5, -30), Color3.fromRGB(16, 22, 36), cardAcc)
		makeCorner(vp, 9)
		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, 84, 0, 10)
		lbl.Size = UDim2.new(1, -254, 0, 22)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		lbl.TextSize = 13
		lbl.TextColor3 = C_TEXT_PRIMARY
		lbl.Text = titleTxt
		lbl.Parent = card
		addTextOutline(lbl, 1.5)

		local desc = Instance.new("TextLabel")
		desc.Position = UDim2.new(0, 84, 0, 34)
		desc.Size = UDim2.new(1, -254, 0, 48)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.GothamMedium
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextSize = 11
		desc.TextColor3 = C_TEXT_MUTED
		desc.Text = descTxt
		desc.TextWrapped = true
		desc.Parent = card

		if hasDual and robuxPrice and onRobuxClick then
			local gBtn = makeBtn(card, btnTxt, btnBg, UDim2.new(1, -162, 0, 10), UDim2.fromOffset(150, 34), onClick)
			gBtn.TextSize = 11
			local rBtn = makeBtn(card, string.format("R$ %d", robuxPrice), C_ROBUX, UDim2.new(1, -162, 0, 50), UDim2.fromOffset(150, 34), onRobuxClick)
			rBtn.TextSize = 11
		else
			makeBtn(card, btnTxt, btnBg, UDim2.new(1, -162, 0.5, -18), UDim2.fromOffset(150, 36), onClick)
		end
		return card
	end

	local dualOpts = MonetizationConfig.DualRobuxOptions
	if currentEmpireSubTab == "HQ" then
		local nextTier = RecipeConfig.RestaurantTiers[restLv + 1]
	local expInfo = state.Expansion
	local expName = if typeof(expInfo) == "table" and typeof(expInfo.DisplayName) == "string" then expInfo.DisplayName else "Starter Bistro"
	local frontWoodName = if typeof(expInfo) == "table" and typeof(expInfo.FrontPavilionName) == "string" and expInfo.FrontPavilionName ~= ""
		then expInfo.FrontPavilionName
		else "Cedar Wood Pavilion"
	local curPlrLv = tonumber(profile.Level) or 1
	local curFoodSold = if typeof(expInfo) == "table" and typeof(expInfo.TotalDishesServed) == "number"
		then expInfo.TotalDishesServed
		else (tonumber(profile.TotalDishesServed) or 0)
	local reqPlrLv = if nextTier then (nextTier.RequiredPlayerLevel or 1) else 20
	local reqFoodSold = if nextTier then (nextTier.RequiredDishesServed or 0) else 2250
	local canUpgReq = if nextTier
		then (if typeof(expInfo) == "table" and typeof(expInfo.CanUpgradeHQRequirements) == "boolean"
			then expInfo.CanUpgradeHQRequirements
			else (curPlrLv >= reqPlrLv and curFoodSold >= reqFoodSold))
		else false
	local curCoins = tonumber(profile.Coins) or 0

	-- Featured Restaurant HQ + Front Wood Restaurant Card (Lv.1 -> Lv.15 with Live Requirements!)
	do
		local hqAccent = if not nextTier then C_GOLD_HI elseif canUpgReq then C_BRASS else C_STEEL
		local hqCard = makeCard(scrollFrame :: ScrollingFrame, if nextTier then 112 else 94, hqAccent)
		local hqVp = ModelPreviewHelper.CreatePreview(hqCard, "Empire", "HQ", UDim2.fromOffset(72, 72), UDim2.new(0, 12, 0.5, -36), Color3.fromRGB(16, 22, 36), hqAccent)
		makeCorner(hqVp, 9)

		local hqTitle = Instance.new("TextLabel")
		hqTitle.Position = UDim2.new(0, 94, 0, 8)
		hqTitle.Size = UDim2.new(1, -268, 0, 20)
		hqTitle.BackgroundTransparency = 1
		hqTitle.Font = Enum.Font.GothamBlack
		hqTitle.TextXAlignment = Enum.TextXAlignment.Left
		hqTitle.TextTruncate = Enum.TextTruncate.AtEnd
		hqTitle.TextSize = 13
		hqTitle.TextColor3 = C_GOLD_HI
		hqTitle.Text = string.format("RESTAURANT HQ & WOOD PAVILION  |  LV.%d / %d", restLv, RecipeConfig.MaxRestaurantLevel)
		hqTitle.Parent = hqCard
		addTextOutline(hqTitle, 1.5)

		local reqLbl = Instance.new("TextLabel")
		reqLbl.Position = UDim2.new(0, 94, 0, 29)
		reqLbl.Size = UDim2.new(1, -268, 0, 17)
		reqLbl.BackgroundTransparency = 1
		reqLbl.Font = Enum.Font.GothamBlack
		reqLbl.TextXAlignment = Enum.TextXAlignment.Left
		reqLbl.TextTruncate = Enum.TextTruncate.AtEnd
		reqLbl.TextSize = 10
		if nextTier then
			reqLbl.TextColor3 = if canUpgReq then Color3.fromRGB(74, 222, 128) else Color3.fromRGB(251, 191, 36)
			reqLbl.Text = string.format(
				"REQ FOR LV.%d:  PLAYER LV.%d (YOU: LV.%d)   •   FOOD SOLD: %d / %d   %s",
				nextTier.Level,
				reqPlrLv,
				curPlrLv,
				curFoodSold,
				reqFoodSold,
				if canUpgReq then "[READY!]" else "[LOCKED]"
			)
		else
			reqLbl.TextColor3 = C_GOLD_HI
			reqLbl.Text = string.format("SUPREME FOOD EMPIRE MAXED  •  FOOD SOLD: %s", formatCommaInt(curFoodSold))
		end
		reqLbl.Parent = hqCard

		local hqDesc = Instance.new("TextLabel")
		hqDesc.Position = UDim2.new(0, 94, 0, 48)
		hqDesc.Size = UDim2.new(1, -268, 0, 56)
		hqDesc.BackgroundTransparency = 1
		hqDesc.Font = Enum.Font.GothamMedium
		hqDesc.TextXAlignment = Enum.TextXAlignment.Left
		hqDesc.TextYAlignment = Enum.TextYAlignment.Top
		hqDesc.TextWrapped = true
		hqDesc.TextSize = 10
		hqDesc.TextColor3 = C_TEXT_MUTED
		local curFloors = if typeof(expInfo) == "table" then (tonumber(expInfo.Floors) or 1) else 1
		local curCust = if typeof(expInfo) == "table" then (tonumber(expInfo.MaxCustomers) or 4) else 4
		local nextCust = if typeof(expInfo) == "table" and typeof(expInfo.NextMaxCustomers) == "number" then expInfo.NextMaxCustomers else (curCust + 2)
		hqDesc.Text = if nextTier and typeof(expInfo) == "table" and typeof(expInfo.NextSummary) == "string" and expInfo.NextSummary ~= ""
			then string.format(
				"Now: %s + %s (%dF • %d Max Customers).\nNEXT LV.%d (%d Customers): %s",
				expName,
				frontWoodName,
				curFloors,
				curCust,
				nextTier.Level,
				nextCust,
				expInfo.NextSummary
			)
			else string.format(
				"%s + %s (%dF • %d Max Customers • 4.5x Dish Payout & 4.0x Cook Speed). Strongest Food Empire in the City!",
				expName,
				frontWoodName,
				curFloors,
				curCust
			)
		hqDesc.Parent = hqCard

		if nextTier then
			local rPrice = MonetizationConfig.GetHQUpgradeRobuxPrice(nextTier.Level)
			local goldLabel = if not canUpgReq
				then string.format("LOCKED (%d/%d FOOD)", math.min(curFoodSold, reqFoodSold), reqFoodSold)
				else string.format("UPG %sG", formatCommaInt(nextTier.UpgradeCost))
			local goldBg = if canUpgReq and curCoins >= nextTier.UpgradeCost then C_OXBLOOD else C_DISABLED
			local gBtn = makeBtn(hqCard, goldLabel, goldBg, UDim2.new(1, -162, 0, 14), UDim2.fromOffset(150, 38), function()
				if dispatchAction then dispatchAction("UpgradeRestaurant", nil) end
			end)
			gBtn.TextSize = 10

			local robuxLabel = if canUpgReq then string.format("R$ %d", rPrice) else string.format("R$ %d • LOCKED", rPrice)
			local robuxBg = if canUpgReq then C_ROBUX else C_DISABLED
			local rBtn = makeBtn(hqCard, robuxLabel, robuxBg, UDim2.new(1, -162, 0, 60), UDim2.fromOffset(150, 38), function()
				if dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "UpgradeRestaurant" }) end
			end)
			rBtn.TextSize = 10
		else
			makeBtn(hqCard, "MAX LV.15", C_OWNED, UDim2.new(1, -162, 0.5, -19), UDim2.fromOffset(150, 38), function() end)
		end
	end

	local hasDualStove = profile.HasDualStove == true
	addUpgradeRow(
		"STV",
		if hasDualStove then "DUAL-STOVE KITCHEN LINE  |  INSTALLED" else "DUAL-STOVE KITCHEN LINE  |  2X SIMULTANEOUS COOKING",
		"Installs a second commercial burner range so you and your Chefs can cook 2 dishes at the same time (+Star Rating).",
		if hasDualStove then "INSTALLED" else "BUY 3,250G",
		if hasDualStove then C_OWNED else C_OXBLOOD,
		function()
			if not hasDualStove and dispatchAction then
				dispatchAction("BuyDualStove", nil)
			end
		end,
		if not hasDualStove then dualOpts.BuyDualStove.RobuxPrice else nil,
		if not hasDualStove then function() if dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "BuyDualStove" }) end end else nil
	)

	local hasVIPBooths = profile.HasVIPBooths == true
	addUpgradeRow(
		"VIP",
		if hasVIPBooths then "VIP PRIVATE DINING BOOTHS  |  INSTALLED" else "VIP PRIVATE DINING BOOTHS  |  +20% DISH PAYOUT",
		"Builds luxury velvet & brass private syndicate booths inside your dining room (+20% Gold on all dishes & +Star Rating).",
		if hasVIPBooths then "INSTALLED" else "BUY 4,250G",
		if hasVIPBooths then C_OWNED else C_OXBLOOD,
		function()
			if not hasVIPBooths and dispatchAction then
				dispatchAction("BuyVIPBooths", nil)
			end
		end,
		if not hasVIPBooths then dualOpts.BuyVIPBooths.RobuxPrice else nil,
		if not hasVIPBooths then function() if dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "BuyVIPBooths" }) end end else nil
	)

	local canHire = crewCount < maxCrew
	addUpgradeRow(
		"CRW",
		string.format("KITCHEN CHEFS  |  %d / %d", crewCount, maxCrew),
		"Fetches ingredients from Warehouses and cooks plated dishes onto the Kitchen Counter (+15% cook speed each).",
		if canHire then string.format("HIRE %sG", formatCommaInt(nextCrewCost)) else "MAX CHEFS",
		if canHire then C_OWNED else C_DISABLED,
		function() if dispatchAction then dispatchAction("HireCrew", nil) end end,
		if canHire then dualOpts.HireCrew.RobuxPrice else nil,
		if canHire then function() if dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "HireCrew" }) end end else nil
	)

	local waiterCount = state.WaiterCount or 0
	local maxWaiters = state.MaxWaiters or 3
	local nextWaiterCost = state.NextWaiterCost
	addUpgradeRow(
		"WTR",
		string.format("DINING WAITERS  |  %d / %d", waiterCount, maxWaiters),
		"Picks up cooked dishes from the Kitchen Counter on a silver tray and serves seated customers (+10% tip each).",
		if nextWaiterCost then string.format("HIRE %sG", formatCommaInt(nextWaiterCost)) else "MAX WAITERS",
		if nextWaiterCost then C_OWNED else C_DISABLED,
		function() if nextWaiterCost and dispatchAction then dispatchAction("HireWaiter", nil) end end,
		if nextWaiterCost then dualOpts.HireWaiter.RobuxPrice else nil,
		if nextWaiterCost then function() if dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "HireWaiter" }) end end else nil
	)

	local courierCount = state.CourierCount or 0
	local maxCouriers = state.MaxCouriers or 2
	local nextCourierCost = state.NextCourierCost
	addUpgradeRow(
		"MTR",
		string.format("MOTORBIKE COURIERS  |  %d / %d", courierCount, maxCouriers),
		"Drives a delivery motorbike to Central Market, loads fresh ingredient crates, and stores them in your Warehouses.",
		if nextCourierCost then string.format("HIRE %sG", formatCommaInt(nextCourierCost)) else "FLEET ACTIVE",
		if nextCourierCost then C_OXBLOOD else C_OWNED,
		function() if nextCourierCost and dispatchAction then dispatchAction("HireCourier", nil) end end,
		if nextCourierCost then dualOpts.HireCourier.RobuxPrice else nil,
		if nextCourierCost then function() if dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "HireCourier" }) end end else nil
	)

	local branch = state.CentralParkBranch
	local ownsBranch = typeof(branch) == "table" and branch.Owned == true
	local branchStaffed = typeof(branch) == "table" and branch.Staffed == true
	local underShakedown = typeof(branch) == "table" and branch.UnderShakedown == true
	local shakedownRem = if typeof(branch) == "table" and typeof(branch.ShakedownTimeLeft) == "number" then branch.ShakedownTimeLeft else 0
	local branchCost = if typeof(branch) == "table" and typeof(branch.Cost) == "number" then branch.Cost else 3750
	if not ownsBranch then
		addUpgradeRow(
			"PRK",
			"CENTRAL PARK BISTRO  |  BRANCH",
			"Own a prime outdoor restaurant in Central Park Plaza. Call your hired Chef & Waiter here for passive Gold & Rep.",
			string.format("BUY %sG", formatCommaInt(branchCost)),
			C_OXBLOOD,
			function() if dispatchAction then dispatchAction("BuyCentralParkBranch", nil) end end,
			dualOpts.BuyCentralParkBranch.RobuxPrice,
			function() if dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "BuyCentralParkBranch" }) end end
		)
	else
		local cardAccent = if underShakedown then C_OXBLOOD elseif branchStaffed then C_OWNED else C_BRASS
		local card = makeCard(scrollFrame :: ScrollingFrame, 88, cardAccent)
		ModelPreviewHelper.CreatePreview(card, "Empire", "PRK", UDim2.fromOffset(54, 54), UDim2.new(0, 14, 0, 17), Color3.fromRGB(22, 24, 31), cardAccent)
		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, 78, 0, 10)
		lbl.Size = UDim2.new(1, -334, 0, 20)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextSize = 13
		lbl.TextColor3 = C_TEXT_PRIMARY
		lbl.Text = if underShakedown
			then string.format("CENTRAL PARK BISTRO  |  SHAKEDOWN (%ds)", shakedownRem)
			elseif branchStaffed then "CENTRAL PARK BISTRO  |  OPEN & STAFFED"
			else "CENTRAL PARK BISTRO  |  OWNED (UNSTAFFED)"
		lbl.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Position = UDim2.new(0, 78, 0, 32)
		desc.Size = UDim2.new(1, -334, 0, 44)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextSize = 11
		desc.TextColor3 = C_TEXT_MUTED
		desc.TextWrapped = true
		desc.Text = if underShakedown
			then "ALERT: Syndicate Extortionist at your Bistro! Click DEFEND (+260G & +45 Rep) or fight them off!"
			elseif branchStaffed then "Your Chef & Waiter are serving Central Park patrons right now (+Gold & +Rep every cycle)."
			else "Call your hired Chef (and Waiter if hired) to operate your Central Park Bistro and earn Gold."
		desc.Parent = card

		makeBtn(card, "VISIT", C_BG_SUBTLE, UDim2.new(1, -242, 0.5, -17), UDim2.fromOffset(78, 34), function()
			EmpireMenuController.Close()
			if dispatchAction then dispatchAction("TeleportCentralParkBranch", nil) end
		end)
		if underShakedown then
			makeBtn(card, "DEFEND +260G", C_OXBLOOD, UDim2.new(1, -156, 0.5, -17), UDim2.fromOffset(144, 34), function()
				EmpireMenuController.Close()
				if dispatchAction then dispatchAction("DefendCentralParkBranch", nil) end
			end)
		else
			makeBtn(
				card,
				if branchStaffed then "RECALL STAFF" else "CALL STAFF",
				if branchStaffed then C_STEEL else C_OWNED,
				UDim2.new(1, -156, 0.5, -17),
				UDim2.fromOffset(144, 34),
				function()
					if dispatchAction then dispatchAction("ToggleCentralParkStaff", nil) end
				end
			)
		end
	end

	local spinInfo = state.SpinEvent
	local spinFree = typeof(spinInfo) == "table" and spinInfo.CanFreeSpin == true
	local spinEventLive = typeof(spinInfo) == "table" and spinInfo.EventActive == true
	local spinBtnTxt = if spinFree
		then "FREE SPIN"
		elseif spinEventLive then "EVENT LIVE"
		else "VISIT WHEEL"
	addUpgradeRow(
		"SPN",
		if spinEventLive then "CENTRAL MARKET SPIN  |  EVENT LIVE" else "CENTRAL MARKET LUCKY SPIN",
		"Spin the Central Market Wheel to win random Bodyguards, Black Market Guns, Gold Jackpots, or Fish/Meat/Veg/Fruit crates.",
		spinBtnTxt,
		if spinFree or spinEventLive then C_OXBLOOD else C_STEEL,
		function()
			EmpireMenuController.Close()
			if dispatchAction then dispatchAction("TeleportSpinWheel", nil) end
		end
	)

	local nextDefCost = DEFENSE_COSTS[defLv + 1]
	addUpgradeRow(
		"DEF",
		string.format("BASE DEFENSES  |  TIER %d / 3", defLv),
		"Installs Watchtower Turrets (Tier 2) and fortified perimeter defenses (Tier 3).",
		if nextDefCost then string.format("UPG %sG", formatCommaInt(nextDefCost)) else "MAX TIER",
		if nextDefCost then C_OXBLOOD else C_DISABLED,
		function() if dispatchAction then dispatchAction("UpgradeDefenses", nil) end end,
		if nextDefCost then dualOpts.UpgradeDefenses.RobuxPrice else nil,
		if nextDefCost then function() if dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "UpgradeDefenses" }) end end else nil
	)

	-- Quick-link Card into the Unified Restaurant Security & Bodyguard Hub!
	addUpgradeRow(
		"GRD",
		string.format("RESTAURANT SECURITY HUB  |  %d ACTIVE DEFENDERS", totalSecActive),
		"Open the Unified Security Hub to hire 5m/10m Timed Defenders, manage all 8 Bodyguard Classes & equip all 18 Gear upgrades!",
		"OPEN SECURITY HUB",
		C_TEAL,
		function()
			AudioController.PlayClick()
			currentEmpireSubTab = "Security"
			if scrollFrame then scrollFrame.CanvasPosition = Vector2.new(0, 0) end
			render()
		end
	)
	return
	end

	-- =========================================================================
	-- SYNDICATE OPS SUB-TAB (Prestige, Families, Vault Heists, Mafia Restaurants & Contracts)
	-- =========================================================================
	-- 7-Day Daily Syndicate Vault & Godfather Prestige Rebirth
	local pv = state.PrestigeVault
	if typeof(pv) == "table" then
		local canClaim = pv.CanClaimToday == true
		addUpgradeRow(
			"DAY",
			string.format("7-DAY SYNDICATE VAULT  |  STREAK: %d / 7", tonumber(pv.Streak) or 0),
			tostring(pv.NextRewardLabel or "Daily login rewards escalating up to a FREE 5-Minute Samurai Mafia Contract on Day 7!"),
			if canClaim then "CLAIM VAULT" else "CLAIMED TODAY",
			if canClaim then C_OWNED else C_DISABLED,
			function()
				if canClaim and dispatchAction then dispatchAction("ClaimDailyVault", nil) end
			end
		)

		local pLv = tonumber(pv.PrestigeLevel) or 0
		local maxP = tonumber(pv.MaxPrestigeLevel) or 10
		local reqRep = tonumber(pv.RequiredRep) or 2000
		local isMaxP = pv.IsMaxPrestige == true
		local canP = pv.CanPrestige == true
		local reqLabel = if isMaxP
			then "MAX PRESTIGE"
			elseif pLv == 0 then string.format("REQ LV.10 / %s REP", formatCommaInt(reqRep))
			else string.format("REQ LV.10 & %s REP", formatCommaInt(reqRep))
		addUpgradeRow(
			"PRS",
			string.format("GODFATHER PRESTIGE  |  CURRENT: P%d / P%d (+%d%% GOLD & REP)", pLv, maxP, pLv * 25),
			if isMaxP
				then "Maximum Godfather Prestige reached! Enjoy your permanent +250% lifetime Gold & Reputation multiplier!"
				elseif pLv == 0 then string.format("At HQ Lv.10 or %s Rep, rebirth your HQ for a permanent +25%% lifetime multiplier while keeping all weapons, gear & bodyguards!", formatCommaInt(reqRep))
				else string.format("Rebuild HQ to Lv.10 & reach %s Rep to ascend to P%d (+%d%% lifetime Gold & Rep). Keeps all weapons, gear & bodyguards!", formatCommaInt(reqRep), pLv + 1, (pLv + 1) * 25),
			if isMaxP then "MAXED" elseif canP then "PRESTIGE NOW" else reqLabel,
			if canP then C_BRASS else C_DISABLED,
			function()
				if canP and dispatchAction then dispatchAction("TriggerGodfatherPrestige", nil) end
			end
		)
	end

	-- Note: Syndicate Families moved directly to the On-Screen HUD (SyndicateFamilyController) for instant access!

	local keycards = tonumber(state.VaultKeycards) or 0
	addUpgradeRow(
		"VLT",
		string.format("TERRITORY SUPPLY VAULT HEIST  |  KEYCARDS: %d", keycards),
		"Crack a Corner Territory Supply Vault for +320G (+440G with Keycard from Territory Rivals), +55 Rep, +15 Stock & 1 Rare Catch!",
		if keycards > 0 then "KEYCARD HEIST" else "CRACK VAULT",
		C_OXBLOOD,
		function()
			if dispatchAction then
				dispatchAction("CrackTerritoryVault", nil)
			end
		end
	)

	addUpgradeRow(
		"EMP",
		"FOOD EMPEROR SYNDICATE MONUMENT  |  CENTRAL PLAZA",
		"Claim your live Food Emperor Tribute (+150G & +25 Rep as #1 Food Emperor, or +65G Syndicate Stipend) from the Central Monument.",
		"CLAIM TRIBUTE",
		C_BRASS,
		function()
			if dispatchAction then
				dispatchAction("ClaimEmperorTribute", nil)
			end
		end
	)

	-- Dynamic Noir Weather & Midnight Blackout Bullion Truck
	local weather = state.Weather
	if typeof(weather) == "table" then
		local blackoutLive = weather.BlackoutTruckActive == true
		addUpgradeRow(
			"WTH",
			string.format("CITY WEATHER: %s", tostring(weather.Title or "CLEAR NOIR")),
			tostring(weather.BonusDesc or "Dynamic Noir Rainstorm, Harbor Fog & Midnight Blackout events."),
			if blackoutLive then "RAID TRUCK +480G" else "SHIFT WEATHER",
			if blackoutLive then C_OXBLOOD else C_STEEL,
			function()
				if dispatchAction then
					dispatchAction(if blackoutLive then "RaidBlackoutTruck" else "CycleWeather", nil)
				end
			end
		)
	end

	-- 3-Stage Crimson Don's Penthouse Heist (Endgame Raid)
	local heist = state.PenthouseHeist
	local heistStage = if typeof(heist) == "table" and typeof(heist.ActiveStage) == "number" then heist.ActiveStage else 0
	local heistCd = if typeof(heist) == "table" and typeof(heist.Cooldown) == "number" then heist.Cooldown else 0
	addUpgradeRow(
		"HST",
		if heistStage > 0 then string.format("CRIMSON DON PENTHOUSE HEIST  |  STAGE %d / 3 LIVE", heistStage) else "THE CRIMSON DON'S PENTHOUSE HEIST  |  3-STAGE RAID",
		"Breach the fortified Syndicate Penthouse Compound, crack the Gold Vault & defeat the Armored Crimson Don (+1,200G, +180 Rep & Trophy)!",
		if heistStage > 0 then "WARP TO RAID" elseif heistCd > 0 then string.format("LOCKED %ds", heistCd) else "LAUNCH HEIST",
		if heistStage > 0 or heistCd <= 0 then C_OXBLOOD else C_DISABLED,
		function()
			if (heistStage > 0 or heistCd <= 0) and dispatchAction then
				EmpireMenuController.Close()
				dispatchAction("StartPenthouseHeist", nil)
			end
		end
	)

	-- Syndicate Bounty Board & Hit Contracts
	local bnt = state.Bounties
	local hitLive = typeof(bnt) == "table" and bnt.HitActive == true
	local hitCd = if typeof(bnt) == "table" and typeof(bnt.HitCooldown) == "number" then bnt.HitCooldown else 0
	local bntCard = makeCard(scrollFrame :: ScrollingFrame, 84, C_OXBLOOD)
	ModelPreviewHelper.CreatePreview(bntCard, "Empire", "BNT", UDim2.fromOffset(54, 54), UDim2.new(0, 14, 0, 15), Color3.fromRGB(22, 24, 31), C_OXBLOOD)
	local bLbl = Instance.new("TextLabel")
	bLbl.Position = UDim2.new(0, 78, 0, 10)
	bLbl.Size = UDim2.new(1, -334, 0, 20)
	bLbl.BackgroundTransparency = 1
	bLbl.Font = Enum.Font.GothamBlack
	bLbl.TextXAlignment = Enum.TextXAlignment.Left
	bLbl.TextSize = 13
	bLbl.TextColor3 = C_TEXT_PRIMARY
	bLbl.Text = if hitLive then string.format("ACTIVE HIT CONTRACT: %s", string.upper(tostring(bnt.HitTargetName or "TARGET"))) else "SYNDICATE BOUNTY BOARD & HIT CONTRACTS"
	bLbl.Parent = bntCard
	local bDesc = Instance.new("TextLabel")
	bDesc.Position = UDim2.new(0, 78, 0, 32)
	bDesc.Size = UDim2.new(1, -334, 0, 42)
	bDesc.BackgroundTransparency = 1
	bDesc.Font = Enum.Font.Gotham
	bDesc.TextWrapped = true
	bDesc.TextXAlignment = Enum.TextXAlignment.Left
	bDesc.TextSize = 11
	bDesc.TextColor3 = C_TEXT_MUTED
	bDesc.Text = "Accept high-value Hit Contracts on armored Syndicate Lieutenants (+460G–620G) or post a 250G bounty on a rival player."
	bDesc.Parent = bntCard
	makeBtn(bntCard, "BOUNTY 250G", C_BG_SUBTLE, UDim2.new(1, -242, 0.5, -17), UDim2.fromOffset(82, 34), function()
		if dispatchAction then dispatchAction("PlacePlayerBounty", { Amount = 250 }) end
	end)
	makeBtn(bntCard, if hitLive then "WARP TARGET" elseif hitCd > 0 then string.format("READY %ds", hitCd) else "ACCEPT HIT", if hitLive or hitCd <= 0 then C_OXBLOOD else C_DISABLED, UDim2.new(1, -152, 0.5, -17), UDim2.fromOffset(140, 34), function()
		if (hitLive or hitCd <= 0) and dispatchAction then
			EmpireMenuController.Close()
			dispatchAction("AcceptHitContract", nil)
		end
	end)

	-- 3 Apex Mafia-Controlled City Restaurants (Conquer -> Hire Chef -> Sell Food -> Defend Revenge!)
	local mafiaRests = state.MafiaRestaurants
	if typeof(mafiaRests) == "table" then
		for _, mr in ipairs(mafiaRests) do
			if typeof(mr) == "table" and typeof(mr.Id) == "string" then
				local rid = mr.Id
				local owned = mr.OwnedByMe == true
				local chefHired = mr.ChefHired == true
				local underRev = mr.UnderRevenge == true
				local cardAcc = if underRev then C_OXBLOOD elseif owned then C_OWNED else C_BRASS
				local mCard = makeCard(scrollFrame :: ScrollingFrame, 88, cardAcc)
				local restIcon = if rid == "ObsidianNoodleHouse" then "RST_Noodle" elseif rid == "VelvetSteakhouse" then "RST_Steak" else "RST_Oyster"
				ModelPreviewHelper.CreatePreview(mCard, "Empire", restIcon, UDim2.fromOffset(54, 54), UDim2.new(0, 14, 0, 17), Color3.fromRGB(22, 24, 31), cardAcc)

				local mTitle = Instance.new("TextLabel")
				mTitle.Position = UDim2.new(0, 78, 0, 10)
				mTitle.Size = UDim2.new(1, -334, 0, 20)
				mTitle.BackgroundTransparency = 1
				mTitle.Font = Enum.Font.GothamBlack
				mTitle.TextXAlignment = Enum.TextXAlignment.Left
				mTitle.TextSize = 13
				mTitle.TextColor3 = C_TEXT_PRIMARY
				mTitle.Text = if underRev
					then string.format("%s  |  REVENGE RAID (%ds)!", string.upper(tostring(mr.DisplayName)), tonumber(mr.RevengeTimeLeft) or 0)
					elseif owned and chefHired then string.format("%s  |  OWNED & SELLING (+%dG)", string.upper(tostring(mr.DisplayName)), tonumber(mr.CycleGold) or 100)
					elseif owned then string.format("%s  |  CONQUERED (HIRE CHEF)", string.upper(tostring(mr.DisplayName)))
					else string.format("%s  |  %s (%d ALIVE)", string.upper(tostring(mr.DisplayName)), string.upper(tostring(mr.FactionName)), tonumber(mr.DefendersAlive) or 3)
				mTitle.Parent = mCard

				local mDesc = Instance.new("TextLabel")
				mDesc.Position = UDim2.new(0, 78, 0, 32)
				mDesc.Size = UDim2.new(1, -334, 0, 44)
				mDesc.BackgroundTransparency = 1
				mDesc.Font = Enum.Font.Gotham
				mDesc.TextWrapped = true
				mDesc.TextXAlignment = Enum.TextXAlignment.Left
				mDesc.TextSize = 11
				mDesc.TextColor3 = C_TEXT_MUTED
				mDesc.Text = if underRev
					then "ALERT: Defeated Apex Mafia is raiding to take back this restaurant! Defend it or dispatch Samurai/Ninja Mafia!"
					elseif owned then string.format("You control this City Restaurant! Hire a Chef (%dG) to cook & sell for +%dG & +%d Rep every 18s.", tonumber(mr.ChefHireCost) or 450, tonumber(mr.CycleGold) or 100, tonumber(mr.CycleRep) or 20)
					else string.format("Guarded by strong %s! Wipe them out yourself or hire Samurai/Ninja Mafia in Black Market -> Mercenaries to conquer it.", tostring(mr.FactionName))
				mDesc.Parent = mCard

				makeBtn(mCard, "VISIT", C_BG_SUBTLE, UDim2.new(1, -242, 0.5, -17), UDim2.fromOffset(78, 34), function()
					EmpireMenuController.Close()
					if dispatchAction then dispatchAction("TeleportMafiaRestaurant", rid) end
				end)
				if owned and not chefHired then
					makeBtn(mCard, string.format("CHEF %dG", tonumber(mr.ChefHireCost) or 450), C_OWNED, UDim2.new(1, -156, 0.5, -17), UDim2.fromOffset(144, 34), function()
						if dispatchAction then dispatchAction("HireMafiaRestaurantChef", rid) end
					end)
				elseif owned and chefHired then
					makeBtn(mCard, if underRev then "SEND MERCS" else "CHEF ACTIVE", if underRev then C_OXBLOOD else C_DISABLED, UDim2.new(1, -156, 0.5, -17), UDim2.fromOffset(144, 34), function()
						if underRev and dispatchAction then dispatchAction("OrderMercenaryAssault", rid) end
					end)
				else
					makeBtn(mCard, "SEND MERCS", C_OXBLOOD, UDim2.new(1, -156, 0.5, -17), UDim2.fromOffset(144, 34), function()
						if dispatchAction then dispatchAction("OrderMercenaryAssault", rid) end
					end)
				end
			end
		end
	end

	-- 3 Ownable Mafia Front Businesses (Passive Wall Safes + Permanent Perks)
	local frontBiz = state.FrontBusinesses
	if typeof(frontBiz) == "table" then
		for _, biz in ipairs(frontBiz) do
			if typeof(biz) == "table" and typeof(biz.Id) == "string" then
				local bid = biz.Id
				local owned = biz.Owned == true
				local safeG = tonumber(biz.SafeGold) or 0
				addUpgradeRow(
					"BIZ_" .. bid,
					if owned then string.format("%s  |  SAFE: %d / %dG", string.upper(tostring(biz.DisplayName)), safeG, tonumber(biz.MaxSafeGold) or 700) else string.format("FRONT BUSINESS: %s", string.upper(tostring(biz.DisplayName))),
					tostring(biz.PerkLabel or "Passive Wall Safe Gold & Empire Perk."),
					if owned then (if safeG > 0 then string.format("COLLECT +%dG", safeG) else "FILLING...") else string.format("BUY  %dG", tonumber(biz.Cost) or 800),
					if owned then (if safeG > 0 then C_OWNED else C_DISABLED) else C_OXBLOOD,
					function()
						if dispatchAction then
							dispatchAction(if owned then "CollectBusinessSafe" else "BuyFrontBusiness", bid)
						end
					end
				)
			end
		end
	end

	local raiderCount = state.RaiderCount or 0
	local maxRaiders = state.MaxRaiders or 2
	local nextRaider = state.NextRaiderCost
	addUpgradeRow(
		"RDR",
		string.format("EMPIRE RAIDERS  |  %d / %d", raiderCount, maxRaiders),
		"Autonomous syndicate raiders that march across the island capturing Neutral & Rival sectors.",
		if nextRaider then string.format("HIRE  %dG", nextRaider) else "SQUAD ACTIVE",
		if nextRaider then C_OXBLOOD else C_OWNED,
		function() if nextRaider and dispatchAction then dispatchAction("HireRaider", nil) end end
	)

	local guardCount = state.BodyguardCount or 0
	local maxGuards = state.MaxBodyguards or 4
	addUpgradeRow(
		"GRD",
		string.format("BODYGUARD SQUAD  |  %d / %d", guardCount, maxGuards),
		"Recruit up to 4 guards across all 8 specialized classes, outfit all 18 gear items, or deploy timed 5m/10m defenders in the Security Hub.",
		"SECURITY HUB",
		C_TEAL,
		function()
			currentTab = "Upgrades"
			currentEmpireSubTab = "Security"
			currentSecuritySubView = "Classes"
			render()
		end
	)

	local isRunActive = state.DeliveryRunnerActive == true
	local runCd = state.DeliveryRunnerCooldown or 0
	addUpgradeRow(
		"RUN",
		"DELIVERY RUNNER  |  CENTRAL PLAZA",
		"Dispatches a runner carrying high-value freight into Central Plaza (+165G). Escort with bodyguards.",
		if isRunActive then "EN ROUTE" elseif runCd > 0 then string.format("READY %ds", runCd) else "DISPATCH",
		if not isRunActive and runCd <= 0 then C_OWNED else C_DISABLED,
		function() if not isRunActive and runCd <= 0 and dispatchAction then dispatchAction("DispatchDeliveryRunner", nil) end end
	)

	local syn = state.Syndicate
	if typeof(syn) == "table" then
		local rankTitle = tostring(syn.RankTitle or "STREET RUNNER")
		local rankTier = tonumber(syn.RankTier) or 1
		local bonusPct = tonumber(syn.PayoutBonusPct) or 0
		local bonusHp = tonumber(syn.BonusMaxHP) or 0
		local nextTitle = tostring(syn.NextRankTitle or "MAX RANK")
		local nextRep = tonumber(syn.NextRankRep) or 0

		local rankCard = makeCard(scrollFrame :: ScrollingFrame, 64, C_BRASS)
		ModelPreviewHelper.CreatePreview(rankCard, "Empire", "RK", UDim2.fromOffset(52, 52), UDim2.new(0, 14, 0, 6), Color3.fromRGB(22, 24, 31), C_BRASS)
		local rHead = Instance.new("TextLabel")
		rHead.Position = UDim2.new(0, 78, 0, 8)
		rHead.Size = UDim2.new(1, -92, 0, 20)
		rHead.BackgroundTransparency = 1
		rHead.Font = Enum.Font.GothamBlack
		rHead.TextXAlignment = Enum.TextXAlignment.Left
		rHead.TextSize = 13
		rHead.TextColor3 = C_BRASS
		rHead.Text = string.format("SYNDICATE RANK: %s  (TIER %d / 6)", rankTitle, rankTier)
		rHead.Parent = rankCard

		local rSub = Instance.new("TextLabel")
		rSub.Position = UDim2.new(0, 78, 0, 30)
		rSub.Size = UDim2.new(1, -92, 0, 26)
		rSub.BackgroundTransparency = 1
		rSub.Font = Enum.Font.Gotham
		rSub.TextXAlignment = Enum.TextXAlignment.Left
		rSub.TextSize = 11
		rSub.TextColor3 = C_TEXT_MUTED
		rSub.Text = string.format(
			"Perks: +%d%% Dish Gold Payout  |  +%d Max HP  |  Next Rank: %s (%d Rep)",
			bonusPct,
			bonusHp,
			nextTitle,
			nextRep
		)
		rSub.Parent = rankCard

		local convoyActive = syn.ConvoyActive == true
		local convoyCd = tonumber(syn.ConvoyCooldown) or 0
		addUpgradeRow(
			"CNV",
			"SMUGGLER CONVOY ESCORT  |  CORNER -> PLAZA",
			"Escort an armored supply transport against Rival Highway Ambushers (+420G, +65 Rep, +8 Ingredients & Ammo).",
			if convoyActive then "CONVOY LIVE" elseif convoyCd > 0 then string.format("READY %ds", convoyCd) else "LAUNCH CONVOY",
			if not convoyActive and convoyCd <= 0 then C_OXBLOOD else C_DISABLED,
			function()
				if not convoyActive and convoyCd <= 0 and dispatchAction then
					dispatchAction("StartSmugglerConvoy", nil)
				end
			end
		)

		local gwActive = syn.GangWarActive == true
		local gwCd = tonumber(syn.GangWarCooldown) or 0
		addUpgradeRow(
			"WAR",
			if gwActive then "GANG WAR CONTRABAND DROP  |  ACTIVE NOW" else "GANG WAR CONTRABAND DROP  |  SKIRMISH",
			"Contested Central District contraband chest guarded by 2 Elite Enforcers (+380G, +55 Rep & 100 Kevlar Armor).",
			if gwActive then "WARP TO DROP" elseif gwCd > 0 then string.format("READY %ds", gwCd) else "CALL DROP",
			if gwActive or gwCd <= 0 then C_OXBLOOD else C_DISABLED,
			function()
				if (gwActive or gwCd <= 0) and dispatchAction then
					EmpireMenuController.Close()
					dispatchAction("StartGangWarDrop", nil)
				end
			end
		)

		local contracts = syn.Contracts
		if typeof(contracts) == "table" then
			for idx, c in ipairs(contracts) do
				if typeof(c) == "table" then
					local prog = tonumber(c.Progress) or 0
					local goal = math.max(1, tonumber(c.Goal) or 1)
					local rewG = tonumber(c.RewardGold) or 220
					local rewR = tonumber(c.RewardRep) or 35
					local slotIdx = tonumber(c.SlotIndex) or idx
					local done = c.Completed == true
					addUpgradeRow(
						string.format("CT%d", idx),
						string.format("CONTRACT #%d: %s  (%d / %d)", idx, tostring(c.Title or "CONTRACT"), prog, goal),
						string.format("%s  |  Reward: +%d Gold & +%d Rep", tostring(c.Description or ""), rewG, rewR),
						if done then "DONE" else "NEW ORDER",
						if done then C_OWNED else C_BG_SUBTLE,
						function()
							if dispatchAction then
								dispatchAction("ClaimSyndicateContract", slotIdx)
							end
						end
					)
				end
			end
		end
	end
end

local function renderShop(state: { [string]: any }): ()
	if not scrollFrame then return end
	local owned = state.OwnedPasses or {}

	-- 1. HERO FEATURED SPOTLIGHT BANNER AT TOP OF ROBUX STORE!
	local heroId = "DoubleEmpireVIP"
	local heroSpec = MonetizationConfig.Items[heroId]
	if heroSpec then
		local heroOwned = owned[heroId] == true
		local heroCard = Instance.new("Frame")
		heroCard.Name = "FeaturedHeroBanner"
		heroCard.LayoutOrder = 1
		heroCard.Size = UDim2.new(1, -6, 0, 134)
		heroCard.BackgroundColor3 = Color3.fromRGB(24, 58, 42)
		heroCard.BorderSizePixel = 0
		heroCard.ClipsDescendants = true
		heroCard.Parent = scrollFrame
		makeCorner(heroCard, 12)
		makeStroke(heroCard, C_GOLD_HI, 2.4)

		local heroGrad = Instance.new("UIGradient")
		heroGrad.Rotation = 15
		heroGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 152, 86)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(18, 64, 52)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 30, 52)),
		})
		heroGrad.Parent = heroCard

		-- Decorative angled diagonal game-shop accent rays
		for r = 1, 3 do
			local stripe = Instance.new("Frame")
			stripe.AnchorPoint = Vector2.new(0.5, 0.5)
			stripe.Position = UDim2.fromScale(0.18 + r * 0.24, 0.5)
			stripe.Size = UDim2.new(0, 34, 1.8, 0)
			stripe.Rotation = 22
			stripe.BackgroundColor3 = C_GOLD_HI
			stripe.BackgroundTransparency = 0.90
			stripe.BorderSizePixel = 0
			stripe.Parent = heroCard
		end

		local pedestal = Instance.new("Frame")
		pedestal.Position = UDim2.fromOffset(16, 14)
		pedestal.Size = UDim2.fromOffset(106, 106)
		pedestal.BackgroundColor3 = Color3.fromRGB(14, 24, 34)
		pedestal.BackgroundTransparency = 0.2
		pedestal.Parent = heroCard
		makeCorner(pedestal, 53)
		makeStroke(pedestal, C_GOLD_HI, 2.2)

		local heroVp = ModelPreviewHelper.CreatePreview(heroCard, "Premium", heroId, UDim2.fromOffset(104, 104), UDim2.fromOffset(17, 15), Color3.fromRGB(14, 24, 34))
		heroVp.BackgroundTransparency = 1
		local heroVpSt = heroVp:FindFirstChildOfClass("UIStroke")
		if heroVpSt then heroVpSt:Destroy() end

		makeTag(heroCard, "MOST POPULAR  |  VIP", C_BRASS, UDim2.fromOffset(136, 14), UDim2.fromOffset(146, 20))
		makeTag(heroCard, "PERMANENT PASS", C_STEEL, UDim2.fromOffset(288, 14), UDim2.fromOffset(108, 20))

		local hTitle = Instance.new("TextLabel")
		hTitle.Position = UDim2.fromOffset(136, 40)
		hTitle.Size = UDim2.new(1, -320, 0, 28)
		hTitle.BackgroundTransparency = 1
		hTitle.Font = Enum.Font.GothamBlack
		hTitle.TextXAlignment = Enum.TextXAlignment.Left
		hTitle.TextSize = 20
		hTitle.TextColor3 = C_GOLD_HI
		hTitle.Text = string.upper(heroSpec.DisplayName)
		hTitle.Parent = heroCard
		addTextOutline(hTitle, 2.0)

		local hDesc = Instance.new("TextLabel")
		hDesc.Position = UDim2.fromOffset(136, 72)
		hDesc.Size = UDim2.new(1, -320, 0, 46)
		hDesc.BackgroundTransparency = 1
		hDesc.Font = Enum.Font.GothamBold
		hDesc.TextWrapped = true
		hDesc.TextXAlignment = Enum.TextXAlignment.Left
		hDesc.TextYAlignment = Enum.TextYAlignment.Top
		hDesc.TextSize = 12
		hDesc.TextColor3 = C_TEXT_PRIMARY
		hDesc.Text = heroSpec.Description
		hDesc.Parent = heroCard

		local hBtn = makeBtn(
			heroCard,
			if heroOwned then "OWNED" else string.format("R$ %d", heroSpec.RobuxPrice),
			if heroOwned then C_DISABLED else C_ROBUX,
			UDim2.new(1, -172, 0.5, -22),
			UDim2.fromOffset(156, 44),
			function()
				if not heroOwned and dispatchAction then
					showConfirmDialog(
						"CONFIRM ROBUX PURCHASE",
						string.format("%s (Permanent Game Pass)\nPrice: R$ %d\n\n%s", heroSpec.DisplayName, heroSpec.RobuxPrice, heroSpec.Description),
						string.format("BUY  R$ %d", heroSpec.RobuxPrice),
						C_ROBUX,
						function()
							if dispatchAction then dispatchAction("BuyRobuxItem", heroId) end
						end
					)
				end
			end
		)
		hBtn.TextSize = 15
	end

	-- 2. 3-COLUMN COLLECTIBLE GAME STORE CARD GRID!
	local storeGrid = makeGridContainer(scrollFrame, 3, 250, 10)
	storeGrid.LayoutOrder = 2
	local cardColors = { C_BRASS, C_STEEL, C_OXBLOOD, Color3.fromRGB(168, 85, 247), C_ROBUX }
	local orderIdx = 0
	for _, itemId in ipairs(MonetizationConfig.Order) do
		if itemId ~= heroId then
			local spec = MonetizationConfig.Items[itemId]
			if spec then
				orderIdx += 1
				local isBike = (itemId == "DeliveryMotorbike")
				local isOwned = (spec.Kind == "GamePass" and owned[itemId] == true) or (isBike and state.OwnsMotorbike == true)
				local themeCol = if isOwned then C_OWNED else cardColors[((orderIdx - 1) % #cardColors) + 1]
				makeStoreCollectibleCard(
					storeGrid,
					orderIdx,
					themeCol,
					string.upper(spec.Badge),
					if spec.Kind == "GamePass" then "PERMANENT" else "PACK",
					string.upper(spec.DisplayName),
					spec.Description,
					"Premium",
					itemId,
					if isOwned then "OWNED" else string.format("R$ %d", spec.RobuxPrice),
					if isOwned then C_DISABLED else C_ROBUX,
					function()
						if not isOwned and dispatchAction then
							local kindTxt = if spec.Kind == "GamePass" then "Permanent Game Pass" else "Repeatable Developer Product"
							showConfirmDialog(
								"CONFIRM ROBUX PURCHASE",
								string.format("%s (%s)\nPrice: R$ %d\n\n%s", spec.DisplayName, kindTxt, spec.RobuxPrice, spec.Description),
								string.format("BUY  R$ %d", spec.RobuxPrice),
								C_ROBUX,
								function()
									if dispatchAction then dispatchAction("BuyRobuxItem", itemId) end
								end
							)
						end
					end
				)
			end
		end
	end
end

local function renderWeaponsForTier(state: { [string]: any }, targetTier: WeaponConfig.MarketTier): ()
	if not scrollFrame then return end
	local isBlackMarket = (targetTier == "BlackMarket")
	local accentCol = if isBlackMarket then C_OXBLOOD else C_TEAL
	local profile = state.Profile or {}
	local playerLevel = tonumber(profile.Level) or 1
	local playerCoins = tonumber(profile.Coins) or 0
	local bm = state.BlackMarket or {}
	local ownedWeapons = bm.OwnedWeapons or {}
	local weaponMods = bm.WeaponMods or {}
	local ammoInv = bm.AmmoInventory or {}
	local weaponKills = if typeof(bm.WeaponKills) == "table" then bm.WeaponKills else {}
	local weaponSkins = if typeof(bm.WeaponSkins) == "table" then bm.WeaponSkins else {}

	local activeFilter = if isBlackMarket then currentWeaponFilter else currentMarketWeaponFilter
	if activeFilter == "Gear" then
		activeFilter = "All"
	end

	-- Sleek Weapon Category Filter Bar tailored to this store's inventory
	local filterRow = Instance.new("Frame")
	filterRow.Name = "WeaponFilterRow"
	filterRow.Size = UDim2.new(1, -6, 0, 30)
	filterRow.BackgroundTransparency = 1
	filterRow.Parent = scrollFrame
	local fl = Instance.new("UIListLayout")
	fl.FillDirection = Enum.FillDirection.Horizontal
	fl.Padding = UDim.new(0, 5)
	fl.Parent = filterRow

	local filters: { { Id: WeaponFilter, Label: string } } = if isBlackMarket
		then {
			{ Id = "All", Label = "ALL CONTRABAND" },
			{ Id = "Melee", Label = "BLADES" },
			{ Id = "Shotgun", Label = "SHOTGUNS" },
			{ Id = "SMG", Label = "SMG" },
			{ Id = "AssaultRifle", Label = "RIFLES" },
			{ Id = "Sniper", Label = "SNIPER" },
		}
		else {
			{ Id = "All", Label = "ALL STANDARD" },
			{ Id = "Melee", Label = "BLADES" },
			{ Id = "Pistol", Label = "PISTOLS" },
			{ Id = "Shotgun", Label = "SHOTGUNS" },
			{ Id = "SMG", Label = "SMG" },
		}

	for _, f in ipairs(filters) do
		local active = (activeFilter == f.Id)
		local b = makeBtn(
			filterRow,
			f.Label,
			if active then accentCol else C_BG_CARD_ALT,
			UDim2.new(),
			UDim2.new(1 / #filters, -4, 0, 28),
			function()
				if isBlackMarket then
					currentWeaponFilter = f.Id
				else
					currentMarketWeaponFilter = f.Id
				end
				render()
			end
		)
		b.TextSize = 10
	end

	-- Modern 2-Column Collectible Weapon Showcase Grid (compact 252px height so full row + Buy buttons sit cleanly above the fold!)
	local grid = makeGridContainer(scrollFrame, 2, 252, 10)
	grid.Name = "WeaponCardGrid"
	local cardOrder = 0

	local activeDeal = if typeof(bm.SmugglerDeal) == "table" then bm.SmugglerDeal else nil

	for _, wid in ipairs(WeaponConfig.WEAPON_ORDER) do
		local w = WeaponConfig.WEAPONS[wid]
		if w and not w.RobuxItemId and WeaponConfig.GetMarketTier(wid) == targetTier and (activeFilter == "All" or activeFilter == w.Category) then
			cardOrder += 1
			local isOwned = ownedWeapons[wid] == true
			local isSmugglerDeal = isBlackMarket and (not isOwned) and activeDeal ~= nil and activeDeal.Category == "Weapon" and activeDeal.ItemId == wid
			local dealDiscPct = if isSmugglerDeal then (tonumber(activeDeal.DiscountPct) or 35) else 0
			local effectivePrice = if isSmugglerDeal and typeof(activeDeal.DealPrice) == "number" then activeDeal.DealPrice else w.Price
			local locked = playerLevel < w.RequiredLevel
			local canAfford = playerCoins >= effectivePrice
			local ammoSpec = WeaponConfig.AMMO_TYPES[w.AmmoType]
			local curAmmo = tonumber(ammoInv[w.AmmoType]) or 0
			local maxAmmo = if ammoSpec then ammoSpec.MaxReserve else 96
			local quickPack = if ammoSpec then ammoSpec.Packs[1] else nil
			local rarityCol = RARITY_MUTED_COLORS[w.Rarity] or C_STEEL
			local themeCol = if isOwned then C_OWNED elseif isSmugglerDeal then C_GOLD_HI else rarityCol

			local card = Instance.new("Frame")
			card.Name = "WeaponCard_" .. wid
			card.LayoutOrder = cardOrder
			card.BackgroundColor3 = C_BG_CARD:Lerp(themeCol, if isSmugglerDeal then 0.20 else 0.14)
			card.BorderSizePixel = 0
			card.ClipsDescendants = true
			card.Parent = grid
			makeCorner(card, 12)
			makeStroke(card, if isSmugglerDeal then C_GOLD_HI else themeCol:Lerp(C_OUTLINE_DARK, 0.22), if isSmugglerDeal then 2.6 else 2.2)

			local topBay = createShowcasePedestalBay(card, 88, themeCol, "Weapon", wid, true)

			-- Crisp corner pill tags inside Showcase Bay
			makeTag(topBay, string.upper(w.Rarity), rarityCol, UDim2.fromOffset(8, 6), UDim2.fromOffset(70, 16))
			if isOwned then
				makeTag(topBay, "OWNED", C_OWNED, UDim2.new(1, -68, 0, 6), UDim2.fromOffset(60, 16))
			elseif isSmugglerDeal then
				makeTag(topBay, string.format("-%d%% DROP", dealDiscPct), C_BRASS, UDim2.new(1, -86, 0, 6), UDim2.fromOffset(78, 16))
			elseif isBlackMarket then
				makeTag(topBay, "BM EXCLUSIVE", C_OXBLOOD_DARK, UDim2.new(1, -98, 0, 6), UDim2.fromOffset(90, 16))
			else
				makeTag(
					topBay,
					if locked then string.format("REQ LV.%d", w.RequiredLevel) else string.format("LV.%d+", w.RequiredLevel),
					if locked then C_OXBLOOD_DARK else C_TEAL_DARK,
					UDim2.new(1, -68, 0, 6),
					UDim2.fromOffset(60, 16)
				)
			end
			-- Bottom-left bay badge: Level req (for Black Market) + Reload/Melee type
			local leftMeta = if isBlackMarket and not isOwned
				then string.format("LV.%d+ • %s", w.RequiredLevel, if w.IsMelee then "MELEE" else string.upper(w.Category))
				elseif w.IsMelee then "MELEE BLADE"
				elseif w.ReloadType == "ShellByShell" then string.format("SHELL • %d RD", w.MagSize)
				else string.format("MAG %d", w.MagSize)
			makeTag(topBay, leftMeta, Color3.fromRGB(16, 22, 36), UDim2.new(0, 8, 1, -21), UDim2.fromOffset(102, 15))

			-- Title & Ammo Reserve Pill
			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 10, 0, 93)
			nameLbl.Size = UDim2.new(1, -92, 0, 19)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.GothamBlack
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nameLbl.TextSize = 13
			nameLbl.TextColor3 = C_TEXT_PRIMARY
			nameLbl.Text = string.upper(w.DisplayName)
			nameLbl.Parent = card
			addTextOutline(nameLbl, 1.5)

			local ammoPillText = if w.IsMelee
				then "NO AMMO"
				else string.format("%s %d/%d", if ammoSpec then ammoSpec.ShortName else w.AmmoType, curAmmo, maxAmmo)
			local ammoPill = Instance.new("TextLabel")
			ammoPill.Position = UDim2.new(1, -84, 0, 94)
			ammoPill.Size = UDim2.fromOffset(74, 16)
			ammoPill.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
			ammoPill.Font = Enum.Font.GothamBold
			ammoPill.Text = ammoPillText
			ammoPill.TextSize = 9
			ammoPill.TextColor3 = C_GOLD_HI
			ammoPill.TextTruncate = Enum.TextTruncate.AtEnd
			ammoPill.Parent = card
			makeCorner(ammoPill, 4)
			makeStroke(ammoPill, C_BORDER, 1)

			-- Clean 3-Column Labeled Visual Stat Meters (DMG / ROF / RNG)
			local dmgText = if w.Pellets > 1 then string.format("%dx%d", w.Pellets, w.Damage) else tostring(w.Damage)
			local rofVal = 1 / math.max(0.05, w.Cooldown)
			local fireRate = string.format("%.1f/s", rofVal)
			local statSpecs = {
				{ Label = "DMG " .. dmgText, Pct = math.clamp((w.Damage * math.max(1, w.Pellets)) / 110, 0.16, 1), Col = accentCol },
				{ Label = (if w.IsMelee then "SWG " else "ROF ") .. fireRate, Pct = math.clamp(rofVal / 10, 0.16, 1), Col = C_BRASS },
				{ Label = string.format("RNG %d", w.Range), Pct = math.clamp(w.Range / 220, 0.14, 1), Col = C_STEEL },
			}
			local statsHolder = Instance.new("Frame")
			statsHolder.Position = UDim2.new(0, 10, 0, 115)
			statsHolder.Size = UDim2.new(1, -20, 0, 24)
			statsHolder.BackgroundTransparency = 1
			statsHolder.Parent = card
			for sIdx, ss in ipairs(statSpecs) do
				local colFrame = Instance.new("Frame")
				colFrame.Position = UDim2.new((sIdx - 1) * 0.34, 0, 0, 0)
				colFrame.Size = UDim2.new(0.32, 0, 1, 0)
				colFrame.BackgroundTransparency = 1
				colFrame.Parent = statsHolder

				local sTxt = Instance.new("TextLabel")
				sTxt.Size = UDim2.new(1, 0, 0, 12)
				sTxt.BackgroundTransparency = 1
				sTxt.Font = Enum.Font.GothamBold
				sTxt.TextXAlignment = Enum.TextXAlignment.Left
				sTxt.TextSize = 9
				sTxt.TextColor3 = C_TEXT_MUTED
				sTxt.Text = ss.Label
				sTxt.Parent = colFrame

				local barBg = Instance.new("Frame")
				barBg.Position = UDim2.fromOffset(0, 15)
				barBg.Size = UDim2.new(1, 0, 0, 6)
				barBg.BackgroundColor3 = Color3.fromRGB(11, 14, 22)
				barBg.BorderSizePixel = 0
				barBg.Parent = colFrame
				makeCorner(barBg, 3)

				local fill = Instance.new("Frame")
				fill.Size = UDim2.fromScale(ss.Pct, 1)
				fill.BackgroundColor3 = ss.Col
				fill.BorderSizePixel = 0
				fill.Parent = barBg
				makeCorner(fill, 3)
			end

			if isOwned then
				-- OWNED WORKBENCH STRIP: Gunsmith Mods Row + Mastery Finishes Row!
				if not w.IsMelee then
					local modRow = Instance.new("Frame")
					modRow.Position = UDim2.new(0, 10, 0, 144)
					modRow.Size = UDim2.new(1, -20, 0, 24)
					modRow.BackgroundTransparency = 1
					modRow.Parent = card
					local modLayout = Instance.new("UIListLayout")
					modLayout.FillDirection = Enum.FillDirection.Horizontal
					modLayout.Padding = UDim.new(0, 4)
					modLayout.Parent = modRow

					local myMods = if typeof(weaponMods[wid]) == "table" then weaponMods[wid] else {}
					for _, modId in ipairs(WeaponConfig.GUNSMITH_MOD_ORDER) do
						local mSpec = WeaponConfig.GUNSMITH_MODS[modId]
						if mSpec then
							local hasMod = myMods[modId] == true
							local mTxt = if hasMod
								then mSpec.ShortLabel .. " [ON]"
								else string.format("+%s %dG", mSpec.ShortLabel, mSpec.Price)
							local mCol = if hasMod
								then C_OWNED
								elseif playerCoins >= mSpec.Price then C_BG_SUBTLE
								else C_DISABLED
							local mb = makeBtn(modRow, mTxt, mCol, UDim2.new(), UDim2.new(1 / 3, -3, 0, 23), function()
								if not hasMod and dispatchAction then
									dispatchAction("BuyWeaponMod", { WeaponId = wid, ModId = modId })
								end
							end)
							mb.TextSize = 8
						end
					end
				else
					local meleeBadge = Instance.new("TextLabel")
					meleeBadge.Position = UDim2.new(0, 10, 0, 145)
					meleeBadge.Size = UDim2.new(1, -20, 0, 22)
					meleeBadge.BackgroundColor3 = Color3.fromRGB(16, 26, 36)
					meleeBadge.Font = Enum.Font.GothamBold
					meleeBadge.TextSize = 9
					meleeBadge.TextColor3 = C_GOLD_HI
					meleeBadge.Text = "MELEE READY  •  1.75X BACKSTAB CRIT"
					meleeBadge.Parent = card
					makeCorner(meleeBadge, 5)
					makeStroke(meleeBadge, C_BORDER, 1)
				end

				-- Weapon Mastery Finishes Row
				local wKills = tonumber(weaponKills[wid]) or 0
				local activeSkin = tostring(weaponSkins[wid] or "Standard")
				local masteryRow = Instance.new("Frame")
				masteryRow.Position = UDim2.new(0, 10, 0, 172)
				masteryRow.Size = UDim2.new(1, -20, 0, 24)
				masteryRow.BackgroundTransparency = 1
				masteryRow.Parent = card
				local mLayout = Instance.new("UIListLayout")
				mLayout.FillDirection = Enum.FillDirection.Horizontal
				mLayout.Padding = UDim.new(0, 4)
				mLayout.Parent = masteryRow

				local kTag = Instance.new("TextLabel")
				kTag.Size = UDim2.fromOffset(44, 23)
				kTag.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
				kTag.Font = Enum.Font.GothamBlack
				kTag.Text = string.format("%d K", wKills)
				kTag.TextSize = 9
				kTag.TextColor3 = C_BRASS
				kTag.Parent = masteryRow
				makeCorner(kTag, 4)
				makeStroke(kTag, C_BORDER, 1)

				for _, skinId in ipairs({ "Standard", "Damascus", "Crimson", "Gold" }) do
					local mTier = WeaponConfig.MASTERY_TIERS[skinId]
					if mTier then
						local unlocked = (wKills >= mTier.KillsRequired)
						local equipped = (activeSkin == skinId)
						local sTxt = if equipped
							then mTier.ShortLabel .. "*"
							elseif unlocked then mTier.ShortLabel
							else string.format("%s %dK", string.sub(mTier.ShortLabel, 1, 3), mTier.KillsRequired)
						local sCol = if equipped
							then C_OWNED
							elseif unlocked then mTier.SwatchColor:Lerp(C_BG_SUBTLE, 0.55)
							else C_DISABLED
						local sb = makeBtn(masteryRow, sTxt, sCol, UDim2.new(), UDim2.new(0.25, -15, 0, 23), function()
							if unlocked and not equipped and dispatchAction then
								dispatchAction("EquipWeaponMasterySkin", { WeaponId = wid, SkinId = skinId })
							end
						end)
						sb.TextSize = 8
					end
				end
			else
				-- UNOWNED CLEAN DESCRIPTION + PERK HINT (Zero disabled button clutter!)
				local descLbl = Instance.new("TextLabel")
				descLbl.Position = UDim2.new(0, 10, 0, 143)
				descLbl.Size = UDim2.new(1, -20, 0, 32)
				descLbl.BackgroundTransparency = 1
				descLbl.Font = Enum.Font.GothamMedium
				descLbl.TextWrapped = true
				descLbl.TextTruncate = Enum.TextTruncate.AtEnd
				descLbl.TextXAlignment = Enum.TextXAlignment.Left
				descLbl.TextYAlignment = Enum.TextYAlignment.Top
				descLbl.TextSize = 10
				descLbl.TextColor3 = C_TEXT_MUTED
				descLbl.Text = w.Description
				descLbl.Parent = card

				local perkHint = Instance.new("TextLabel")
				perkHint.Position = UDim2.new(0, 10, 0, 178)
				perkHint.Size = UDim2.new(1, -20, 0, 19)
				perkHint.BackgroundColor3 = Color3.fromRGB(15, 20, 32)
				perkHint.Font = Enum.Font.GothamBold
				perkHint.TextSize = 9
				perkHint.TextColor3 = C_TEXT_DIM
				perkHint.Text = if w.IsMelee
					then "UNLOCKS: 4 MASTERY BLADE FINISHES"
					else "UNLOCKS: 3 GUNSMITH MODS + 4 MASTERY SKINS"
				perkHint.Parent = card
				makeCorner(perkHint, 5)
				makeStroke(perkHint, C_BORDER, 1)
			end

			-- Bottom Action Row (Dual-Currency Gold + Robux, OR Owned Equip + Quick Ammo!)
			local hasRobuxOpt = (not isOwned) and typeof(w.RobuxPrice) == "number" and w.RobuxPrice > 0
			local hasQuickAmmo = isOwned and (not w.IsMelee) and quickPack ~= nil and ammoSpec ~= nil

			local buyText = if isOwned
				then "EQUIP"
				elseif locked then string.format("LV.%d LOCK", w.RequiredLevel)
				elseif isSmugglerDeal then string.format("%sG (-%d%%)", formatCommaInt(effectivePrice), dealDiscPct)
				else string.format("%sG", formatCommaInt(effectivePrice))
			local buyCol = if isOwned
				then C_OWNED
				elseif locked or not canAfford then C_DISABLED
				elseif isSmugglerDeal then C_BRASS
				else accentCol

			local leftWidth = if hasRobuxOpt then UDim2.new(0.54, -12, 0, 36)
				elseif hasQuickAmmo then UDim2.new(0.46, -12, 0, 36)
				else UDim2.new(1, -20, 0, 36)

			local buyBtn = makeBtn(card, buyText, buyCol, UDim2.new(0, 10, 1, -44), leftWidth, function()
				if locked or isOwned then
					if dispatchAction then dispatchAction("BuyBlackMarketItem", wid) end
					return
				end
				if effectivePrice >= 2500 then
					local dealLine = if isSmugglerDeal
						then string.format("\nDON VINNIE'S DROP: -%d%% OFF (Was %sG — Save %sG!)", dealDiscPct, formatCommaInt(w.Price), formatCommaInt(math.max(0, w.Price - effectivePrice)))
						else ""
					showConfirmDialog(
						"CONFIRM WEAPON PURCHASE",
						string.format("Acquire %s (%s %s) for %s Gold?%s\nStats: %s DMG  |  %d Range  |  %d Mag", w.DisplayName, w.Rarity, w.Category, formatCommaInt(effectivePrice), dealLine, dmgText, w.Range, w.MagSize),
						string.format("BUY %sG", formatCommaInt(effectivePrice)),
						if isSmugglerDeal then C_BRASS else accentCol,
						function()
							if dispatchAction then dispatchAction("BuyBlackMarketItem", wid) end
						end
					)
				elseif dispatchAction then
					dispatchAction("BuyBlackMarketItem", wid)
				end
			end)
			buyBtn.TextSize = if isSmugglerDeal then 10 else 11

			if hasRobuxOpt and w.RobuxPrice then
				local rBtn = makeBtn(card, string.format("R$ %d", w.RobuxPrice), C_ROBUX, UDim2.new(0.54, 2, 1, -44), UDim2.new(0.46, -12, 0, 36), function()
					if dispatchAction then
						dispatchAction("BuyWithRobuxOption", { Kind = "BuyBlackMarketItem", Arg = wid })
					end
				end)
				rBtn.TextSize = 11
			elseif hasQuickAmmo and quickPack and ammoSpec then
				local ammoFull = curAmmo >= maxAmmo
				local ammoBtnText = if ammoFull
					then "AMMO FULL"
					else string.format("+%d (%sG)", quickPack.Quantity, formatCommaInt(quickPack.Price))
				local aBtn = makeBtn(card, ammoBtnText, if ammoFull then C_DISABLED else C_STEEL, UDim2.new(0.46, 2, 1, -44), UDim2.new(0.54, -12, 0, 36), function()
					if not ammoFull and dispatchAction then
						dispatchAction("BuyAmmo", { AmmoType = w.AmmoType, PackIndex = 1 })
					end
				end)
				aBtn.TextSize = 10
			end
		end
	end
end

local function renderBlackMarketGadgets(state: { [string]: any }): ()
	if not scrollFrame then return end
	local profile = state.Profile or {}
	local playerCoins = tonumber(profile.Coins) or 0
	local bm = state.BlackMarket or {}
	local flashCount = tonumber(bm.Flashbangs) or 0
	local c4Count = tonumber(bm.C4Charges) or 0
	local hasDash = bm.HasShadowDash == true

	makeSectionDivider(scrollFrame, "UNDERGROUND CONTRABAND GADGETS  •  2X-4X BLACK MARKET EXCLUSIVES", C_OXBLOOD)

	local grid = makeGridContainer(scrollFrame, 2, 236, 10)
	grid.Name = "GadgetCardGrid"

	local dualOpts = MonetizationConfig.DualRobuxOptions
	local gp = WeaponConfig.GADGET_PRICES
	local activeDeal = if typeof(bm.SmugglerDeal) == "table" then bm.SmugglerDeal else nil
	local dashIsDeal = (not hasDash) and activeDeal ~= nil and activeDeal.Category == "ShadowDash"
	local dashDiscPct = if dashIsDeal then (tonumber(activeDeal.DiscountPct) or 35) else 0
	local dashPrice = if dashIsDeal and typeof(activeDeal.DealPrice) == "number" then activeDeal.DealPrice else gp.ShadowDash

	local gadgetSpecs = {
		{
			Id = "Flashbang",
			Name = "FLASHBANG STUN GRENADES",
			LeftTag = "BM EXCLUSIVE",
			LeftTagCol = C_OXBLOOD_DARK,
			Badge = string.format("%d / 12  •  KEY [6]", flashCount),
			Desc = "Contraband concussion tech: blinds, freezes & disorients Rival Samurai, Ninja & Mafia squads for 4 full seconds.",
			Col = C_BRASS,
			IsDone = (flashCount >= 12),
			IsDeal = false,
			BtnText = if flashCount >= 12 then "FULL (12)" else string.format("3X %sG", formatCommaInt(gp.Flashbang)),
			BtnCol = if flashCount >= 12 then C_DISABLED elseif playerCoins >= gp.Flashbang then C_OXBLOOD else C_DISABLED,
			RobuxPrice = dualOpts.BuyFlashbangs.RobuxPrice,
			OnClick = function()
				if flashCount < 12 and dispatchAction then dispatchAction("BuyFlashbangs", nil) end
			end,
			OnRobux = function()
				if flashCount < 12 and dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "BuyFlashbangs" }) end
			end,
		},
		{
			Id = "C4Charge",
			Name = "C4 BREACH CHARGES",
			LeftTag = "BM EXCLUSIVE",
			LeftTagCol = C_OXBLOOD_DARK,
			Badge = string.format("%d / 8  •  KEY [7]", c4Count),
			Desc = "Illicit demolition bricks: blows open Armored Mafia Cash Vans & vaults (+280-450G) and blasts squads for 125 DMG.",
			Col = C_OXBLOOD,
			IsDone = (c4Count >= 8),
			IsDeal = false,
			BtnText = if c4Count >= 8 then "FULL (8)" else string.format("2X %sG", formatCommaInt(gp.C4Charge)),
			BtnCol = if c4Count >= 8 then C_DISABLED elseif playerCoins >= gp.C4Charge then C_OXBLOOD else C_DISABLED,
			RobuxPrice = dualOpts.BuyC4Charges.RobuxPrice,
			OnClick = function()
				if c4Count < 8 and dispatchAction then dispatchAction("BuyC4Charges", nil) end
			end,
			OnRobux = function()
				if c4Count < 8 and dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "BuyC4Charges" }) end
			end,
		},
		{
			Id = "ShadowDash",
			Name = "SHADOW SMOKE DASH",
			LeftTag = if dashIsDeal then string.format("-%d%% DROP", dashDiscPct) else "BM EXCLUSIVE",
			LeftTagCol = if dashIsDeal then C_BRASS else C_OXBLOOD_DARK,
			Badge = if hasDash then "UNLOCKED  •  KEY [8]" else "PERMANENT  •  KEY [8]",
			Desc = "26-stud ninja smoke dash with afterimage trail (5s CD). Dodges fire & grants 1.5x Backstab Crit!",
			Col = if hasDash then C_OWNED elseif dashIsDeal then C_GOLD_HI else Color3.fromRGB(139, 92, 246),
			IsDone = hasDash,
			IsDeal = dashIsDeal,
			BtnText = if hasDash then "ACTIVE  [8]" elseif dashIsDeal then string.format("%sG (-%d%%)", formatCommaInt(dashPrice), dashDiscPct) else string.format("%sG", formatCommaInt(dashPrice)),
			BtnCol = if hasDash then C_OWNED elseif playerCoins >= dashPrice then (if dashIsDeal then C_BRASS else C_OXBLOOD) else C_DISABLED,
			RobuxPrice = dualOpts.BuyShadowDash.RobuxPrice,
			OnClick = function()
				if not hasDash and dispatchAction then dispatchAction("BuyShadowDash", nil) end
			end,
			OnRobux = function()
				if not hasDash and dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "BuyShadowDash" }) end
			end,
		},
	}

	for idx, g in ipairs(gadgetSpecs) do
		local card = Instance.new("Frame")
		card.Name = "GadgetCard_" .. g.Id
		card.LayoutOrder = idx
		card.BackgroundColor3 = C_BG_CARD:Lerp(g.Col, if g.IsDeal then 0.20 else 0.14)
		card.BorderSizePixel = 0
		card.ClipsDescendants = true
		card.Parent = grid
		makeCorner(card, 12)
		makeStroke(card, if g.IsDeal then C_GOLD_HI else g.Col:Lerp(C_OUTLINE_DARK, 0.22), if g.IsDeal then 2.6 else 2.2)

		local topBay = createShowcasePedestalBay(card, 96, g.Col, "Equipment", g.Id, false)
		makeTag(topBay, g.LeftTag, g.LeftTagCol, UDim2.fromOffset(8, 7), UDim2.fromOffset(90, 17))
		makeTag(topBay, g.Badge, Color3.fromRGB(16, 22, 36), UDim2.new(1, -118, 0, 7), UDim2.fromOffset(110, 17))

		local nLbl = Instance.new("TextLabel")
		nLbl.Position = UDim2.new(0, 10, 0, 104)
		nLbl.Size = UDim2.new(1, -20, 0, 20)
		nLbl.BackgroundTransparency = 1
		nLbl.Font = Enum.Font.GothamBlack
		nLbl.TextXAlignment = Enum.TextXAlignment.Left
		nLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nLbl.TextSize = 13
		nLbl.TextColor3 = C_TEXT_PRIMARY
		nLbl.Text = g.Name
		nLbl.Parent = card
		addTextOutline(nLbl, 1.5)

		local dLbl = Instance.new("TextLabel")
		dLbl.Position = UDim2.new(0, 10, 0, 128)
		dLbl.Size = UDim2.new(1, -20, 0, 50)
		dLbl.BackgroundTransparency = 1
		dLbl.Font = Enum.Font.GothamMedium
		dLbl.TextWrapped = true
		dLbl.TextXAlignment = Enum.TextXAlignment.Left
		dLbl.TextYAlignment = Enum.TextYAlignment.Top
		dLbl.TextSize = 11
		dLbl.TextColor3 = C_TEXT_MUTED
		dLbl.Text = g.Desc
		dLbl.Parent = card

		if g.IsDone then
			local btn = makeBtn(card, g.BtnText, g.BtnCol, UDim2.new(0, 10, 1, -48), UDim2.new(1, -20, 0, 38), g.OnClick)
			btn.TextSize = 11
		else
			local gBtn = makeBtn(card, g.BtnText, g.BtnCol, UDim2.new(0, 10, 1, -48), UDim2.new(0.55, -12, 0, 38), g.OnClick)
			gBtn.TextSize = 10
			local rBtn = makeBtn(card, string.format("R$ %d", g.RobuxPrice), C_ROBUX, UDim2.new(0.55, 2, 1, -48), UDim2.new(0.45, -12, 0, 38), g.OnRobux)
			rBtn.TextSize = 11
		end
	end
end

local function renderBlackMarketAmmo(state: { [string]: any }): ()
	if not scrollFrame then return end
	local bm = state.BlackMarket or {}
	local ammoInv = bm.AmmoInventory or {}
	local coins = tonumber(state.Profile and state.Profile.Coins) or 0

	makeSectionDivider(scrollFrame, "CALIBER-MATCHED AMMUNITION CRATES  •  SHARED RESERVES", C_BRASS)

	local ammoGrid = makeGridContainer(scrollFrame, 2, 162, 10)
	ammoGrid.Name = "AmmoCardGrid"

	for aIdx, ammoId in ipairs(WeaponConfig.AMMO_ORDER) do
		local aSpec = WeaponConfig.AMMO_TYPES[ammoId]
		if aSpec then
			local cur = tonumber(ammoInv[ammoId]) or 0
			local maxRes = aSpec.MaxReserve
			local isFull = cur >= maxRes
			local compatList = WeaponConfig.GetCompatibleWeaponsForAmmo(ammoId)
			local themeCol = if isFull then C_OWNED else C_BRASS

			local card = Instance.new("Frame")
			card.Name = "AmmoCard_" .. ammoId
			card.LayoutOrder = aIdx
			card.BackgroundColor3 = C_BG_CARD:Lerp(themeCol, 0.14)
			card.BorderSizePixel = 0
			card.ClipsDescendants = true
			card.Parent = ammoGrid
			makeCorner(card, 12)
			makeStroke(card, themeCol:Lerp(C_OUTLINE_DARK, 0.25), 2.0)

			-- Glowing miniature 3D Ammo Pedestal on Top-Left
			local iconBay = Instance.new("Frame")
			iconBay.Position = UDim2.fromOffset(10, 10)
			iconBay.Size = UDim2.fromOffset(72, 72)
			iconBay.BackgroundColor3 = themeCol:Lerp(Color3.fromRGB(14, 18, 30), 0.65)
			iconBay.BorderSizePixel = 0
			iconBay.Parent = card
			makeCorner(iconBay, 10)
			makeStroke(iconBay, themeCol, 1.4, 0.4)

			local vp = ModelPreviewHelper.CreatePreview(iconBay, "Ammo", ammoId, UDim2.fromOffset(66, 66), UDim2.fromOffset(3, 3), Color3.fromRGB(14, 18, 30))
			vp.BackgroundTransparency = 1
			local vpSt = vp:FindFirstChildOfClass("UIStroke")
			if vpSt then vpSt:Destroy() end

			local title = Instance.new("TextLabel")
			title.Position = UDim2.new(0, 90, 0, 10)
			title.Size = UDim2.new(1, -98, 0, 18)
			title.BackgroundTransparency = 1
			title.Font = Enum.Font.GothamBlack
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextTruncate = Enum.TextTruncate.AtEnd
			title.TextSize = 12
			title.TextColor3 = C_TEXT_PRIMARY
			title.Text = string.upper(aSpec.DisplayName)
			title.Parent = card
			addTextOutline(title, 1.4)

			local resLbl = Instance.new("TextLabel")
			resLbl.Position = UDim2.new(0, 90, 0, 30)
			resLbl.Size = UDim2.new(1, -98, 0, 14)
			resLbl.BackgroundTransparency = 1
			resLbl.Font = Enum.Font.GothamBold
			resLbl.TextXAlignment = Enum.TextXAlignment.Left
			resLbl.TextSize = 10
			resLbl.TextColor3 = if isFull then C_OWNED else C_GOLD_HI
			resLbl.Text = string.format("RESERVE: %d / %d", cur, maxRes)
			resLbl.Parent = card

			local barBg = Instance.new("Frame")
			barBg.Position = UDim2.new(0, 90, 0, 48)
			barBg.Size = UDim2.new(1, -100, 0, 7)
			barBg.BackgroundColor3 = Color3.fromRGB(11, 14, 22)
			barBg.BorderSizePixel = 0
			barBg.Parent = card
			makeCorner(barBg, 3)
			local barFill = Instance.new("Frame")
			barFill.Size = UDim2.fromScale(math.clamp(cur / math.max(1, maxRes), 0, 1), 1)
			barFill.BackgroundColor3 = themeCol
			barFill.BorderSizePixel = 0
			barFill.Parent = barBg
			makeCorner(barFill, 3)

			local compatLbl = Instance.new("TextLabel")
			compatLbl.Position = UDim2.new(0, 90, 0, 59)
			compatLbl.Size = UDim2.new(1, -98, 0, 26)
			compatLbl.BackgroundTransparency = 1
			compatLbl.Font = Enum.Font.Gotham
			compatLbl.TextWrapped = true
			compatLbl.TextTruncate = Enum.TextTruncate.AtEnd
			compatLbl.TextXAlignment = Enum.TextXAlignment.Left
			compatLbl.TextYAlignment = Enum.TextYAlignment.Top
			compatLbl.TextSize = 9
			compatLbl.TextColor3 = C_TEXT_MUTED
			compatLbl.Text = "Fits: " .. table.concat(compatList, ", ")
			compatLbl.Parent = card

			local btnHolder = Instance.new("Frame")
			btnHolder.Position = UDim2.new(0, 10, 1, -46)
			btnHolder.Size = UDim2.new(1, -20, 0, 36)
			btnHolder.BackgroundTransparency = 1
			btnHolder.Parent = card
			local bl = Instance.new("UIListLayout")
			bl.FillDirection = Enum.FillDirection.Horizontal
			bl.Padding = UDim.new(0, 5)
			bl.Parent = btnHolder

			for pIdx, pack in ipairs(aSpec.Packs) do
				local canAfford = coins >= pack.Price
				local bText = if isFull
					then "FULL"
					else string.format("+%d (%dG)", pack.Quantity, pack.Price)
				local bCol = if isFull
					then C_DISABLED
					elseif canAfford then C_TEAL
					else C_DISABLED
				local pb = makeBtn(btnHolder, bText, bCol, UDim2.new(), UDim2.new(1 / #aSpec.Packs, -4, 0, 34), function()
					if not isFull and dispatchAction then
						dispatchAction("BuyAmmo", { AmmoType = ammoId, PackIndex = pIdx })
					end
				end)
				pb.TextSize = 9
			end
		end
	end
end

local function renderMarketSupplies(state: { [string]: any }): ()
	if not scrollFrame then return end
	local bm = state.BlackMarket or {}
	local currentArmor = if typeof(bm.Armor) == "number" then bm.Armor else 0
	local smokeCount = tonumber(bm.SmokeGrenades) or 0

	makeSectionDivider(scrollFrame, "SURVIVAL & TACTICAL SUPPLIES  •  CITY MARKET", C_TEAL)

	-- 2-Column Collectible Survival Supplies Grid (Kevlar Armor, Medkit & Smoke Grenades)
	local supGrid = makeGridContainer(scrollFrame, 2, 232, 10)
	supGrid.Name = "SupplyCardGrid"

	local supplyItems = {
		{
			Id = "KevlarVest",
			Name = "KEVLAR PLATE ARMOR",
			LeftTag = "ARMOR",
			RightTag = string.format("%d / 100", currentArmor),
			Desc = "+100 breakable ballistic protection. Absorbs gunfire and melee hits until depleted.",
			Col = if currentArmor >= 100 then C_OWNED else C_TEAL,
			IsFull = (currentArmor >= 100),
			GoldLabel = if currentArmor >= 100 then "ARMOR FULL" elseif currentArmor > 0 then "REFILL 2,100G" else "BUY 2,100G",
			RobuxPrice = 29,
			OnGold = function()
				if currentArmor < 100 and dispatchAction then dispatchAction("BuyBlackMarketItem", "KevlarVest") end
			end,
			OnRobux = function()
				if currentArmor < 100 and dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "BuyBlackMarketItem", Arg = "KevlarVest" }) end
			end,
		},
		{
			Id = "Medkit",
			Name = "FIELD TRAUMA KIT",
			LeftTag = "MEDICAL",
			RightTag = "INSTANT HEAL",
			Desc = "Immediate 100% Base Health recovery plus a 6-second sprint adrenaline boost.",
			Col = C_OWNED,
			IsFull = false,
			GoldLabel = "BUY 750G",
			RobuxPrice = 19,
			OnGold = function()
				if dispatchAction then dispatchAction("BuyBlackMarketItem", "Medkit") end
			end,
			OnRobux = function()
				if dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "BuyBlackMarketItem", Arg = "Medkit" }) end
			end,
		},
		{
			Id = "SmokeGrenade",
			Name = "TACTICAL SMOKE GRENADES",
			LeftTag = "KEY [T]",
			RightTag = string.format("%d / 12", smokeCount),
			Desc = "Deploys a dense 10-second tactical smoke screen breaking Mafia line-of-sight during escapes.",
			Col = C_STEEL,
			IsFull = (smokeCount >= 12),
			GoldLabel = if smokeCount >= 12 then "FULL (12)" else "3X 900G",
			RobuxPrice = MonetizationConfig.DualRobuxOptions.BuySmokeGrenades.RobuxPrice,
			OnGold = function()
				if smokeCount < 12 and dispatchAction then dispatchAction("BuySmokeGrenades", nil) end
			end,
			OnRobux = function()
				if smokeCount < 12 and dispatchAction then dispatchAction("BuyWithRobuxOption", { Kind = "BuySmokeGrenades" }) end
			end,
		},
	}

	for idx, item in ipairs(supplyItems) do
		local card = Instance.new("Frame")
		card.Name = "SupplyCard_" .. item.Id
		card.LayoutOrder = idx
		card.BackgroundColor3 = C_BG_CARD:Lerp(item.Col, 0.14)
		card.BorderSizePixel = 0
		card.ClipsDescendants = true
		card.Parent = supGrid
		makeCorner(card, 12)
		makeStroke(card, item.Col:Lerp(C_OUTLINE_DARK, 0.22), 2.2)

		local topBay = createShowcasePedestalBay(card, 94, item.Col, "Equipment", item.Id, false)
		makeTag(topBay, item.LeftTag, item.Col:Lerp(C_OUTLINE_DARK, 0.25), UDim2.fromOffset(8, 7), UDim2.fromOffset(72, 17))
		makeTag(topBay, item.RightTag, Color3.fromRGB(16, 22, 36), UDim2.new(1, -94, 0, 7), UDim2.fromOffset(86, 17))

		local nLbl = Instance.new("TextLabel")
		nLbl.Position = UDim2.new(0, 10, 0, 102)
		nLbl.Size = UDim2.new(1, -20, 0, 20)
		nLbl.BackgroundTransparency = 1
		nLbl.Font = Enum.Font.GothamBlack
		nLbl.TextXAlignment = Enum.TextXAlignment.Left
		nLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nLbl.TextSize = 13
		nLbl.TextColor3 = C_TEXT_PRIMARY
		nLbl.Text = item.Name
		nLbl.Parent = card
		addTextOutline(nLbl, 1.5)

		local dLbl = Instance.new("TextLabel")
		dLbl.Position = UDim2.new(0, 10, 0, 126)
		dLbl.Size = UDim2.new(1, -20, 0, 48)
		dLbl.BackgroundTransparency = 1
		dLbl.Font = Enum.Font.GothamMedium
		dLbl.TextWrapped = true
		dLbl.TextXAlignment = Enum.TextXAlignment.Left
		dLbl.TextYAlignment = Enum.TextYAlignment.Top
		dLbl.TextSize = 11
		dLbl.TextColor3 = C_TEXT_MUTED
		dLbl.Text = item.Desc
		dLbl.Parent = card

		if item.IsFull then
			makeBtn(card, item.GoldLabel, C_OWNED, UDim2.new(0, 10, 1, -48), UDim2.new(1, -20, 0, 38), function() end)
		elseif item.RobuxPrice and item.OnRobux then
			local gBtn = makeBtn(card, item.GoldLabel, C_TEAL, UDim2.new(0, 10, 1, -48), UDim2.new(0.56, -12, 0, 38), item.OnGold)
			gBtn.TextSize = 10
			local rBtn = makeBtn(card, string.format("R$ %d", item.RobuxPrice), C_ROBUX, UDim2.new(0.56, 2, 1, -48), UDim2.new(0.44, -12, 0, 38), item.OnRobux)
			rBtn.TextSize = 11
		else
			local gBtn = makeBtn(card, item.GoldLabel, C_TEAL, UDim2.new(0, 10, 1, -48), UDim2.new(1, -20, 0, 38), item.OnGold)
			gBtn.TextSize = 11
		end
	end

	-- Full Caliber-Matched Ammunition Crates
	renderBlackMarketAmmo(state)
end

renderBodyguardsForTier = function(state: { [string]: any }, targetTier: BodyguardConfig.MarketTier | "All", forcedView: GuardViewMode?, autoDefendHQ: boolean?): ()
	if not scrollFrame then return end
	local isAllUnified = (targetTier == "All")
	local isBlackMarket = (targetTier == "BlackMarket")
	local accentCol = if isBlackMarket then C_OXBLOOD else C_TEAL
	local profile = state.Profile or {}
	local playerLevel = tonumber(profile.Level) or 1
	local playerCoins = tonumber(profile.Coins) or 0
	local ownedPasses = state.OwnedPasses or {}
	local bgState = state.Bodyguards or {}
	local activeSquad: { string } = bgState.ActiveSquad or {}
	local unlockedClasses: { [string]: boolean } = bgState.UnlockedClasses or {}
	local ownedGear: { [string]: boolean } = bgState.OwnedGear or {}
	local loadouts: { [string]: { [string]: string } } = bgState.Loadouts or {}
	local maxSlots = tonumber(bgState.MaxSlots) or BodyguardConfig.MAX_ACTIVE_GUARDS
	local currentStance = tostring(bgState.Stance or state.GuardStance or "Follow")
	selectedGuardSlot = math.clamp(selectedGuardSlot, 1, maxSlots)

	-- Squad Tactical Command Bar (Follow Me, Guard Central Park Bistro, Patrol Base, Free-Fire Aggressive)
	local stanceCard = makeCard(scrollFrame, 68, C_BRASS)
	local stHead = Instance.new("TextLabel")
	stHead.Position = UDim2.new(0, 14, 0, 6)
	stHead.Size = UDim2.new(1, -24, 0, 16)
	stHead.BackgroundTransparency = 1
	stHead.Font = Enum.Font.GothamBlack
	stHead.TextXAlignment = Enum.TextXAlignment.Left
	stHead.TextSize = 11
	stHead.TextColor3 = C_BRASS
	stHead.Text = string.format("BODYGUARD SQUAD TACTICAL ORDER [KEY X]  —  ACTIVE: %s", string.upper(tostring(bgState.StanceLabel or currentStance)))
	stHead.Parent = stanceCard

	local stRow = Instance.new("Frame")
	stRow.Position = UDim2.new(0, 14, 0, 26)
	stRow.Size = UDim2.new(1, -28, 0, 32)
	stRow.BackgroundTransparency = 1
	stRow.Parent = stanceCard
	local stl = Instance.new("UIListLayout")
	stl.FillDirection = Enum.FillDirection.Horizontal
	stl.Padding = UDim.new(0, 6)
	stl.Parent = stRow

	local stances = {
		{ Id = "PatrolBase", Label = "DEFEND HQ" },
		{ Id = "Follow", Label = "FOLLOW ME" },
		{ Id = "GuardBistro", Label = "GUARD BISTRO" },
		{ Id = "Aggressive", Label = "AGGRESSIVE" },
	}
	for _, stOpt in ipairs(stances) do
		local isAct = (currentStance == stOpt.Id)
		local sb = makeBtn(
			stRow,
			stOpt.Label,
			if isAct then C_OWNED else C_BG_SUBTLE,
			UDim2.new(),
			UDim2.new(0.25, -5, 0, 30),
			function()
				if dispatchAction then
					dispatchAction("SetGuardStance", stOpt.Id)
				end
			end
		)
		sb.TextSize = 10
	end

	-- Active 4-Slot Squad Selector (with one-click shortcut to Unified Security Hub when viewed inside Market/BlackMarket!)
	local squadCard = makeCard(scrollFrame, 78, C_STEEL)
	local sHead = Instance.new("TextLabel")
	sHead.Position = UDim2.new(0, 14, 0, 7)
	sHead.Size = UDim2.new(1, if isAllUnified then -24 else -168, 0, 18)
	sHead.BackgroundTransparency = 1
	sHead.Font = Enum.Font.GothamBlack
	sHead.TextXAlignment = Enum.TextXAlignment.Left
	sHead.TextSize = 11
	sHead.TextColor3 = C_BRASS
	sHead.Text = string.format("ACTIVE BODYGUARD DETAIL  (%d / %d)  —  SELECT TARGET SLOT", #activeSquad, maxSlots)
	sHead.Parent = squadCard

	if not isAllUnified then
		local hubJump = makeBtn(squadCard, "SECURITY HUB >", C_TEAL, UDim2.new(1, -142, 0, 4), UDim2.fromOffset(130, 22), function()
			AudioController.PlayClick()
			currentTab = "Upgrades"
			currentEmpireSubTab = "Security"
			currentSecuritySubView = if (forcedView or currentGuardView) == "Gear" then "Gear" else "Classes"
			if scrollFrame then scrollFrame.CanvasPosition = Vector2.new(0, 0) end
			lastRenderedTabSig = ""
			render()
		end)
		hubJump.Name = "OpenSecurityHubShortcutBtn"
		hubJump.TextSize = 9
	end

	local slotRow = Instance.new("Frame")
	slotRow.Position = UDim2.new(0, 14, 0, 30)
	slotRow.Size = UDim2.new(1, -28, 0, 38)
	slotRow.BackgroundTransparency = 1
	slotRow.Parent = squadCard
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.Padding = UDim.new(0, 6)
	sl.Parent = slotRow

	for idx = 1, maxSlots do
		local cid = activeSquad[idx]
		local cSpec = if cid then BodyguardConfig.CLASSES[cid :: BodyguardConfig.GuardClassId] else nil
		local isSel = (selectedGuardSlot == idx)
		local label = if cSpec
			then string.format("#%d  %s", idx, string.upper(cSpec.DisplayName))
			else string.format("#%d  EMPTY", idx)
		local btn = makeBtn(
			slotRow,
			label,
			if isSel then accentCol elseif cSpec then C_BG_SUBTLE else C_BG_CARD_ALT,
			UDim2.new(),
			UDim2.new(0.25, -5, 0, 36),
			function()
				selectedGuardSlot = idx
				render()
			end
		)
		btn.TextSize = 10
		btn.TextWrapped = true
		if isSel then
			local st = btn:FindFirstChildOfClass("UIStroke")
			if st then st.Color = C_TEXT_PRIMARY end
		end
	end

	-- Count items in this tier for crisp toggle labels
	local tierClassCount = 0
	for _, cid in ipairs(BodyguardConfig.CLASS_ORDER) do
		if isAllUnified or BodyguardConfig.GetClassMarketTier(cid) == targetTier then
			tierClassCount += 1
		end
	end
	local tierGearCount = 0
	for _, gid in ipairs(BodyguardConfig.GEAR_ORDER) do
		if isAllUnified or BodyguardConfig.GetGearMarketTier(gid) == targetTier then
			tierGearCount += 1
		end
	end

	local viewMode: GuardViewMode = forcedView or currentGuardView
	if not forcedView then
		-- Toggle Classes vs Gear inside Black Market Elite Guards
		local modeRow = Instance.new("Frame")
		modeRow.Size = UDim2.new(1, -6, 0, 32)
		modeRow.BackgroundTransparency = 1
		modeRow.Parent = scrollFrame
		local ml = Instance.new("UIListLayout")
		ml.FillDirection = Enum.FillDirection.Horizontal
		ml.Padding = UDim.new(0, 6)
		ml.Parent = modeRow

		local cModeBtn = makeBtn(
			modeRow,
			string.format("ELITE CLASSES  (%d)", tierClassCount),
			if viewMode == "Classes" then accentCol else C_BG_CARD_ALT,
			UDim2.new(),
			UDim2.new(0.5, -3, 0, 30),
			function()
				currentGuardView = "Classes"
				render()
			end
		)
		cModeBtn.TextSize = 11

		local gModeBtn = makeBtn(
			modeRow,
			string.format("CONTRABAND GUARD GEAR  (%d)", tierGearCount),
			if viewMode == "Gear" then accentCol else C_BG_CARD_ALT,
			UDim2.new(),
			UDim2.new(0.5, -3, 0, 30),
			function()
				currentGuardView = "Gear"
				render()
			end
		)
		gModeBtn.TextSize = 11
	end

	local activeDeal = if typeof(state.BlackMarket) == "table" and typeof(state.BlackMarket.SmugglerDeal) == "table" then state.BlackMarket.SmugglerDeal else nil

	if viewMode == "Classes" then
		local classGrid = makeGridContainer(scrollFrame, 2, 276, 10)
		classGrid.Name = "GuardClassCardGrid"
		local classOrder = 0

		for _, classId in ipairs(BodyguardConfig.CLASS_ORDER) do
			local cSpec = BodyguardConfig.CLASSES[classId]
			local itemTier = BodyguardConfig.GetClassMarketTier(classId)
			if cSpec and (isAllUnified or itemTier == targetTier) then
				classOrder += 1
				local isItemBM = (itemTier == "BlackMarket")
				local cardAccentBtn = if isItemBM then C_OXBLOOD else C_TEAL
				local isUnlocked = unlockedClasses[classId] == true
					or (cSpec.RobuxItemId ~= nil and ownedPasses[cSpec.RobuxItemId] == true)
				local isSmugglerDeal = isItemBM and (not isUnlocked) and activeDeal ~= nil and activeDeal.Category == "GuardClass" and activeDeal.ItemId == classId
				local dealDiscPct = if isSmugglerDeal then (tonumber(activeDeal.DiscountPct) or 35) else 0
				local effectiveCost = if isSmugglerDeal and typeof(activeDeal.DealPrice) == "number" then activeDeal.DealPrice else cSpec.Cost
				local locked = (not isUnlocked) and (playerLevel < cSpec.RequiredLevel)
				local isRobuxOnly = (not isUnlocked) and cSpec.Cost <= 0 and typeof(cSpec.RobuxPrice) == "number" and cSpec.RobuxPrice > 0
				local hasRobuxOption = (not isUnlocked) and cSpec.Cost > 0 and typeof(cSpec.RobuxPrice) == "number" and cSpec.RobuxPrice > 0
				local inSelectedSlot = (activeSquad[selectedGuardSlot] == classId)
				local rarityCol = RARITY_MUTED_COLORS[cSpec.Rarity] or C_STEEL
				local themeCol = if inSelectedSlot then C_OWNED elseif isSmugglerDeal then C_GOLD_HI else rarityCol

				local card = Instance.new("Frame")
				card.Name = "GuardClassCard_" .. classId
				card.LayoutOrder = classOrder
				card.BackgroundColor3 = C_BG_CARD:Lerp(themeCol, if isSmugglerDeal then 0.20 else 0.14)
				card.BorderSizePixel = 0
				card.ClipsDescendants = true
				card.Parent = classGrid
				makeCorner(card, 12)
				makeStroke(card, if isSmugglerDeal then C_GOLD_HI else themeCol:Lerp(C_OUTLINE_DARK, 0.22), if isSmugglerDeal then 2.6 else 2.2)

				local topBay = createShowcasePedestalBay(card, 104, themeCol, "Bodyguard", classId, false)
				makeTag(topBay, string.upper(cSpec.Rarity), rarityCol, UDim2.fromOffset(8, 7), UDim2.fromOffset(72, 17))
				if inSelectedSlot then
					makeTag(topBay, "ACTIVE #" .. tostring(selectedGuardSlot), C_OWNED, UDim2.new(1, -82, 0, 7), UDim2.fromOffset(74, 17))
				elseif isSmugglerDeal then
					makeTag(topBay, string.format("-%d%% DROP", dealDiscPct), C_BRASS, UDim2.new(1, -86, 0, 7), UDim2.fromOffset(78, 17))
				elseif isItemBM then
					makeTag(topBay, "BM EXCLUSIVE", C_OXBLOOD_DARK, UDim2.new(1, -98, 0, 7), UDim2.fromOffset(90, 17))
				elseif isAllUnified then
					makeTag(topBay, "CITY MARKET", C_TEAL_DARK, UDim2.new(1, -88, 0, 7), UDim2.fromOffset(80, 17))
				else
					makeTag(
						topBay,
						if locked then string.format("REQ LV.%d", cSpec.RequiredLevel) else string.format("LV.%d+", cSpec.RequiredLevel),
						if locked then C_OXBLOOD_DARK else C_TEAL_DARK,
						UDim2.new(1, -68, 0, 7),
						UDim2.fromOffset(60, 17)
					)
				end
				makeTag(topBay, string.upper(cSpec.Role), Color3.fromRGB(16, 22, 36), UDim2.new(0, 8, 1, -23), UDim2.fromOffset(118, 16))

				local title = Instance.new("TextLabel")
				title.Position = UDim2.new(0, 10, 0, 110)
				title.Size = UDim2.new(1, -20, 0, 20)
				title.BackgroundTransparency = 1
				title.Font = Enum.Font.GothamBlack
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextTruncate = Enum.TextTruncate.AtEnd
				title.TextSize = 14
				title.TextColor3 = C_TEXT_PRIMARY
				title.Text = string.upper(cSpec.DisplayName)
				title.Parent = card
				addTextOutline(title, 1.5)

				-- Crisp 4-Pill Stat Row (HP / DMG / RNG / SPD)
				local statRow = Instance.new("Frame")
				statRow.Position = UDim2.new(0, 10, 0, 134)
				statRow.Size = UDim2.new(1, -20, 0, 20)
				statRow.BackgroundTransparency = 1
				statRow.Parent = card
				local statPills = {
					{ Text = string.format("HP %d", cSpec.MaxHP), Col = C_OWNED },
					{ Text = string.format("DMG %d", cSpec.Damage), Col = cardAccentBtn },
					{ Text = string.format("RNG %d", cSpec.AttackRange), Col = C_STEEL },
					{ Text = string.format("SPD %.0f", cSpec.WalkSpeed), Col = C_BRASS },
				}
				for sIdx, sp in ipairs(statPills) do
					local pill = Instance.new("TextLabel")
					pill.Position = UDim2.new((sIdx - 1) * 0.255, 0, 0, 0)
					pill.Size = UDim2.new(0.24, 0, 1, 0)
					pill.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
					pill.Font = Enum.Font.GothamBold
					pill.TextSize = 9
					pill.TextColor3 = sp.Col:Lerp(Color3.new(1, 1, 1), 0.35)
					pill.Text = sp.Text
					pill.Parent = statRow
					makeCorner(pill, 4)
					makeStroke(pill, sp.Col:Lerp(C_OUTLINE_DARK, 0.45), 1)
				end

				local abilLbl = Instance.new("TextLabel")
				abilLbl.Position = UDim2.new(0, 10, 0, 159)
				abilLbl.Size = UDim2.new(1, -20, 0, 15)
				abilLbl.BackgroundTransparency = 1
				abilLbl.Font = Enum.Font.GothamBlack
				abilLbl.TextXAlignment = Enum.TextXAlignment.Left
				abilLbl.TextTruncate = Enum.TextTruncate.AtEnd
				abilLbl.TextSize = 10
				abilLbl.TextColor3 = C_GOLD_HI
				abilLbl.Text = "ABILITY: " .. string.upper(cSpec.AbilityName)
				abilLbl.Parent = card

				local descLbl = Instance.new("TextLabel")
				descLbl.Position = UDim2.new(0, 10, 0, 176)
				descLbl.Size = UDim2.new(1, -20, 0, 44)
				descLbl.BackgroundTransparency = 1
				descLbl.Font = Enum.Font.GothamMedium
				descLbl.TextWrapped = true
				descLbl.TextTruncate = Enum.TextTruncate.AtEnd
				descLbl.TextXAlignment = Enum.TextXAlignment.Left
				descLbl.TextYAlignment = Enum.TextYAlignment.Top
				descLbl.TextSize = 10
				descLbl.TextColor3 = C_TEXT_MUTED
				descLbl.Text = cSpec.AbilityDesc .. " " .. cSpec.Description
				descLbl.Parent = card

				local targetSlotLabel = if activeSquad[selectedGuardSlot] then string.format("#%d", selectedGuardSlot) else string.format("#%d", math.min(maxSlots, #activeSquad + 1))
				if isRobuxOnly and cSpec.RobuxPrice then
					local rPrice = cSpec.RobuxPrice
					local vipBtn = makeBtn(card, string.format("R$ %d  UNLOCK", rPrice), C_ROBUX, UDim2.new(0, 10, 1, -48), UDim2.new(1, -20, 0, 38), function()
						if dispatchAction then
							if cSpec.RobuxItemId then
								dispatchAction("BuyRobuxItem", cSpec.RobuxItemId)
							else
								dispatchAction("RecruitBodyguard", { ClassId = classId, SlotIndex = selectedGuardSlot, UseRobux = true, AutoDefendHQ = autoDefendHQ == true })
							end
						end
					end)
					vipBtn.TextSize = 11
				else
					local recruitText = if inSelectedSlot
						then "ACTIVE  SLOT #" .. tostring(selectedGuardSlot)
						elseif isUnlocked then "ASSIGN  SLOT " .. targetSlotLabel
						elseif locked then string.format("LV.%d LOCK", cSpec.RequiredLevel)
						elseif isSmugglerDeal then string.format("%sG (-%d%%)", formatCommaInt(effectiveCost), dealDiscPct)
						else string.format("HIRE %sG", formatCommaInt(effectiveCost))
					local recruitCol = if inSelectedSlot
						then C_OWNED
						elseif isUnlocked then C_STEEL
						elseif locked or playerCoins < effectiveCost then C_DISABLED
						elseif isSmugglerDeal then C_BRASS
						else cardAccentBtn

					local leftW = if hasRobuxOption then UDim2.new(0.55, -12, 0, 38) else UDim2.new(1, -20, 0, 38)
					local rBtn = makeBtn(
						card,
						recruitText,
						recruitCol,
						UDim2.new(0, 10, 1, -48),
						leftW,
						function()
							if inSelectedSlot then return end
							local argPayload = { ClassId = classId, SlotIndex = selectedGuardSlot, AutoDefendHQ = autoDefendHQ == true }
							if not isUnlocked and not locked and effectiveCost >= 2500 then
								local dealLine = if isSmugglerDeal
									then string.format("\nDON VINNIE'S DROP: -%d%% OFF (Was %sG — Save %sG!)", dealDiscPct, formatCommaInt(cSpec.Cost), formatCommaInt(math.max(0, cSpec.Cost - effectiveCost)))
									else ""
								showConfirmDialog(
									"CONFIRM BODYGUARD RECRUIT",
									string.format("Recruit %s (%s) into Slot %s for %s Gold?%s\nHP: %d  |  DMG: %d  |  Ability: %s", cSpec.DisplayName, cSpec.Role, targetSlotLabel, formatCommaInt(effectiveCost), dealLine, cSpec.MaxHP, cSpec.Damage, cSpec.AbilityName),
									string.format("HIRE %sG", formatCommaInt(effectiveCost)),
									if isSmugglerDeal then C_BRASS else cardAccentBtn,
									function()
										if dispatchAction then dispatchAction("RecruitBodyguard", argPayload) end
									end
								)
							elseif dispatchAction then
								dispatchAction("RecruitBodyguard", argPayload)
							end
						end
					)
					rBtn.TextSize = if isSmugglerDeal then 10 else 11

					if hasRobuxOption and cSpec.RobuxPrice then
						local rPrice = cSpec.RobuxPrice
						local vipBtn = makeBtn(card, string.format("R$ %d", rPrice), C_ROBUX, UDim2.new(0.55, 2, 1, -48), UDim2.new(0.45, -12, 0, 38), function()
							if dispatchAction then
								if cSpec.RobuxItemId then
									dispatchAction("BuyRobuxItem", cSpec.RobuxItemId)
								else
									dispatchAction("RecruitBodyguard", { ClassId = classId, SlotIndex = selectedGuardSlot, UseRobux = true, AutoDefendHQ = autoDefendHQ == true })
								end
							end
						end)
						vipBtn.TextSize = 11
						local vst = vipBtn:FindFirstChildOfClass("UIStroke")
						if vst then vst.Color = C_BRASS end
					end
				end
			end
		end
	else
		-- Bodyguard Gear Filter Row
		local gFilterRow = Instance.new("Frame")
		gFilterRow.Size = UDim2.new(1, -6, 0, 28)
		gFilterRow.BackgroundTransparency = 1
		gFilterRow.Parent = scrollFrame
		local gl = Instance.new("UIListLayout")
		gl.FillDirection = Enum.FillDirection.Horizontal
		gl.Padding = UDim.new(0, 4)
		gl.Parent = gFilterRow

		local gFilters: { { Id: GuardGearFilter, Label: string } } = {
			{ Id = "All", Label = "ALL" },
			{ Id = "Armor", Label = "ARMOR" },
			{ Id = "Helmet", Label = "HELMETS" },
			{ Id = "Outfit", Label = "OUTFITS" },
			{ Id = "Weapon", Label = "WEAPONS" },
			{ Id = "Attachment", Label = "ATTACH" },
			{ Id = "Tactical", Label = "TACTICAL" },
		}
		for _, gf in ipairs(gFilters) do
			local active = (currentGuardGearFilter == gf.Id)
			local fb = makeBtn(gFilterRow, gf.Label, if active then accentCol else C_BG_CARD_ALT, UDim2.new(), UDim2.new(1 / #gFilters, -4, 0, 26), function()
				currentGuardGearFilter = gf.Id
				render()
			end)
			fb.TextSize = 9
		end

		local selClassId = activeSquad[selectedGuardSlot]
		local selClassSpec = if selClassId then BodyguardConfig.CLASSES[selClassId :: BodyguardConfig.GuardClassId] else nil
		local selLoadout = loadouts[tostring(selectedGuardSlot)] or {}

		-- Modern 2-Column Collectible Bodyguard Gear Grid!
		local gearGrid = makeGridContainer(scrollFrame, 2, 246, 10)
		gearGrid.Name = "GuardGearCardGrid"
		local gearOrder = 0

		for _, gearId in ipairs(BodyguardConfig.GEAR_ORDER) do
			local gSpec = BodyguardConfig.GEAR[gearId]
			local gearTier = BodyguardConfig.GetGearMarketTier(gearId)
			if gSpec and (isAllUnified or gearTier == targetTier) and (currentGuardGearFilter == "All" or currentGuardGearFilter == gSpec.Slot) then
				gearOrder += 1
				local isGearBM = (gearTier == "BlackMarket")
				local gearBuyAccent = if isGearBM then C_OXBLOOD else C_TEAL
				local ownsGear = ownedGear[gearId] == true
					or (gSpec.RobuxItemId ~= nil and ownedPasses[gSpec.RobuxItemId] == true)
				local isSmugglerDeal = isGearBM and (not ownsGear) and (not gSpec.RobuxItemId) and activeDeal ~= nil and activeDeal.Category == "GuardGear" and activeDeal.ItemId == gearId
				local dealDiscPct = if isSmugglerDeal then (tonumber(activeDeal.DiscountPct) or 35) else 0
				local effectivePrice = if isSmugglerDeal and typeof(activeDeal.DealPrice) == "number" then activeDeal.DealPrice else gSpec.Price
				local isEquippedOnSlot = (selLoadout[gSpec.Slot] == gearId)
				local isCompatible = if selClassId then BodyguardConfig.IsGearCompatible(selClassId :: BodyguardConfig.GuardClassId, gearId) else false
				local locked = (not ownsGear) and (not gSpec.RobuxItemId) and (playerLevel < gSpec.RequiredLevel)
				local rarityCol = RARITY_MUTED_COLORS[gSpec.Rarity] or C_STEEL
				local themeCol = if isEquippedOnSlot then C_OWNED elseif isSmugglerDeal then C_GOLD_HI else rarityCol

				local bonusParts: { string } = {}
				if gSpec.BonusHP ~= 0 then table.insert(bonusParts, string.format("+%d HP", gSpec.BonusHP)) end
				if gSpec.BonusDamage ~= 0 then table.insert(bonusParts, string.format("+%d DMG", gSpec.BonusDamage)) end
				if gSpec.BonusRange ~= 0 then table.insert(bonusParts, string.format("+%d RNG", gSpec.BonusRange)) end
				if gSpec.BonusSpeed > 0 then table.insert(bonusParts, string.format("+%.1f SPD", gSpec.BonusSpeed)) end
				if gSpec.CooldownMult < 1 then table.insert(bonusParts, string.format("+%d%% ROF", math.floor((1 - gSpec.CooldownMult) * 100))) end
				if gSpec.HealAuraBonus > 0 then table.insert(bonusParts, string.format("+%d HEAL", gSpec.HealAuraBonus)) end
				if gSpec.StunEffect then table.insert(bonusParts, "STUN") end

				local card = Instance.new("Frame")
				card.Name = "GuardGearCard_" .. gearId
				card.LayoutOrder = gearOrder
				card.BackgroundColor3 = C_BG_CARD:Lerp(themeCol, if isSmugglerDeal then 0.20 else 0.14)
				card.BorderSizePixel = 0
				card.ClipsDescendants = true
				card.Parent = gearGrid
				makeCorner(card, 12)
				makeStroke(card, if isSmugglerDeal then C_GOLD_HI else themeCol:Lerp(C_OUTLINE_DARK, 0.22), if isSmugglerDeal then 2.6 else 2.2)

				local topBay = createShowcasePedestalBay(card, 94, themeCol, "Equipment", gearId, gSpec.Slot == "Weapon")
				makeTag(topBay, string.upper(gSpec.Slot), C_BG_SUBTLE, UDim2.fromOffset(8, 7), UDim2.fromOffset(66, 17))
				makeTag(topBay, string.upper(gSpec.Rarity), rarityCol, UDim2.fromOffset(78, 7), UDim2.fromOffset(64, 17))
				if isSmugglerDeal then
					makeTag(topBay, string.format("-%d%% DROP", dealDiscPct), C_BRASS, UDim2.new(0, 8, 1, -22), UDim2.fromOffset(78, 15))
				elseif isGearBM then
					makeTag(topBay, "BM EXCLUSIVE", C_OXBLOOD_DARK, UDim2.new(0, 8, 1, -22), UDim2.fromOffset(88, 15))
				elseif isAllUnified then
					makeTag(topBay, "CITY MARKET", C_TEAL_DARK, UDim2.new(0, 8, 1, -22), UDim2.fromOffset(78, 15))
				end

				local compatText = if not selClassSpec
					then "SLOT #" .. tostring(selectedGuardSlot) .. " EMPTY"
					elseif isCompatible then "FITS #" .. tostring(selectedGuardSlot)
					else "NO FIT #" .. tostring(selectedGuardSlot)
				local compatCol = if not selClassSpec
					then C_DISABLED
					elseif isCompatible then C_OWNED
					else C_OXBLOOD_DARK
				makeTag(topBay, compatText, compatCol, UDim2.new(1, -86, 0, 7), UDim2.fromOffset(78, 17))

				local title = Instance.new("TextLabel")
				title.Position = UDim2.new(0, 10, 0, 100)
				title.Size = UDim2.new(1, -20, 0, 20)
				title.BackgroundTransparency = 1
				title.Font = Enum.Font.GothamBlack
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextTruncate = Enum.TextTruncate.AtEnd
				title.TextSize = 13
				title.TextColor3 = C_TEXT_PRIMARY
				title.Text = string.upper(gSpec.DisplayName)
				title.Parent = card
				addTextOutline(title, 1.5)

				local statLbl = Instance.new("TextLabel")
				statLbl.Position = UDim2.new(0, 10, 0, 122)
				statLbl.Size = UDim2.new(1, -20, 0, 18)
				statLbl.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
				statLbl.Font = Enum.Font.GothamBold
				statLbl.TextSize = 10
				statLbl.TextColor3 = C_GOLD_HI
				statLbl.TextTruncate = Enum.TextTruncate.AtEnd
				statLbl.Text = "  " .. table.concat(bonusParts, "  •  ")
				statLbl.TextXAlignment = Enum.TextXAlignment.Left
				statLbl.Parent = card
				makeCorner(statLbl, 4)
				makeStroke(statLbl, C_BORDER, 1)

				local descLbl = Instance.new("TextLabel")
				descLbl.Position = UDim2.new(0, 10, 0, 146)
				descLbl.Size = UDim2.new(1, -20, 0, 44)
				descLbl.BackgroundTransparency = 1
				descLbl.Font = Enum.Font.GothamMedium
				descLbl.TextWrapped = true
				descLbl.TextTruncate = Enum.TextTruncate.AtEnd
				descLbl.TextXAlignment = Enum.TextXAlignment.Left
				descLbl.TextYAlignment = Enum.TextYAlignment.Top
				descLbl.TextSize = 10
				descLbl.TextColor3 = C_TEXT_MUTED
				descLbl.Text = gSpec.Description
				descLbl.Parent = card

				if ownsGear then
					local eqText = if isEquippedOnSlot
						then "EQUIPPED  #" .. tostring(selectedGuardSlot)
						elseif not selClassSpec then "SELECT GUARD"
						elseif not isCompatible then "INCOMPATIBLE"
						else "EQUIP  GUARD #" .. tostring(selectedGuardSlot)
					local eqCol = if isEquippedOnSlot then C_OWNED elseif isCompatible then C_STEEL else C_DISABLED
					local eqBtn = makeBtn(card, eqText, eqCol, UDim2.new(0, 10, 1, -48), UDim2.new(1, -20, 0, 38), function()
						if isCompatible and not isEquippedOnSlot and dispatchAction then
							dispatchAction("EquipGuardGear", { SlotIndex = selectedGuardSlot, GearId = gearId })
						end
					end)
					eqBtn.TextSize = 11
				elseif gSpec.RobuxItemId and gSpec.RobuxPrice then
					local rId = gSpec.RobuxItemId
					local rPrice = gSpec.RobuxPrice
					local rBtn = makeBtn(card, string.format("R$ %d", rPrice), C_ROBUX, UDim2.new(0, 10, 1, -48), UDim2.new(1, -20, 0, 38), function()
						showConfirmDialog(
							"CONFIRM ROBUX OUTFIT",
							string.format("Unlock %s permanently for R$ %d?\n%s", gSpec.DisplayName, rPrice, gSpec.Description),
							string.format("BUY  R$ %d", rPrice),
							C_ROBUX,
							function()
								if dispatchAction then dispatchAction("BuyRobuxItem", rId) end
							end
						)
					end)
					local rst = rBtn:FindFirstChildOfClass("UIStroke")
					if rst then rst.Color = C_BRASS end
				else
					local hasRobuxOpt = typeof(gSpec.RobuxPrice) == "number" and gSpec.RobuxPrice > 0
					local bText = if locked
						then string.format("LV.%d LOCK", gSpec.RequiredLevel)
						elseif isSmugglerDeal then string.format("%sG (-%d%%)", formatCommaInt(effectivePrice), dealDiscPct)
						else string.format("%sG", formatCommaInt(effectivePrice))
					local bCol = if locked or playerCoins < effectivePrice then C_DISABLED elseif isSmugglerDeal then C_BRASS else gearBuyAccent
					local leftW = if hasRobuxOpt then UDim2.new(0.55, -12, 0, 38) else UDim2.new(1, -20, 0, 38)
					local bBtn = makeBtn(card, bText, bCol, UDim2.new(0, 10, 1, -48), leftW, function()
						if locked then
							if dispatchAction then dispatchAction("BuyGuardGear", gearId) end
							return
						end
						if effectivePrice >= 500 then
							local dealLine = if isSmugglerDeal
								then string.format("\nDON VINNIE'S DROP: -%d%% OFF (Was %sG — Save %sG!)", dealDiscPct, formatCommaInt(gSpec.Price), formatCommaInt(math.max(0, gSpec.Price - effectivePrice)))
								else ""
							showConfirmDialog(
								"CONFIRM EQUIPMENT PURCHASE",
								string.format("Purchase %s (%s) for %s Gold?%s\nBonuses: %s", gSpec.DisplayName, gSpec.Slot, formatCommaInt(effectivePrice), dealLine, table.concat(bonusParts, ", ")),
								string.format("BUY  %sG", formatCommaInt(effectivePrice)),
								if isSmugglerDeal then C_BRASS else gearBuyAccent,
								function()
									if dispatchAction then dispatchAction("BuyGuardGear", gearId) end
								end
							)
						elseif dispatchAction then
							dispatchAction("BuyGuardGear", gearId)
						end
					end)
					bBtn.TextSize = if isSmugglerDeal then 10 else 11

					if hasRobuxOpt and gSpec.RobuxPrice then
						local rPrice = gSpec.RobuxPrice
						local rBtn = makeBtn(card, string.format("R$ %d", rPrice), C_ROBUX, UDim2.new(0.55, 2, 1, -48), UDim2.new(0.45, -12, 0, 38), function()
							if dispatchAction then
								dispatchAction("BuyWithRobuxOption", { Kind = "BuyGuardGear", Arg = gearId })
							end
						end)
						rBtn.TextSize = 11
						local rst = rBtn:FindFirstChildOfClass("UIStroke")
						if rst then rst.Color = C_BRASS end
					end
				end
			end
		end
	end
end

local function renderBlackMarketMercenaries(state: { [string]: any }): ()
	if not scrollFrame then return end
	local merc = state.MercenaryMafia or {}
	local active = merc.Active == true
	local mercType = tostring(merc.MercType or "")
	local remSec = tonumber(merc.TimeRemaining) or 0
	local targetRest = merc.TargetRestaurantId
	local goldCost = tonumber(merc.GoldCost) or 100000
	local coins = tonumber(state.Profile and state.Profile.Coins) or 0

	local statusCard = makeCard(scrollFrame, 56, if active then C_OWNED else C_OXBLOOD)
	local sLbl = Instance.new("TextLabel")
	sLbl.Position = UDim2.new(0, 14, 0, 6)
	sLbl.Size = UDim2.new(1, -28, 1, -12)
	sLbl.BackgroundTransparency = 1
	sLbl.Font = Enum.Font.GothamBlack
	sLbl.TextWrapped = true
	sLbl.TextXAlignment = Enum.TextXAlignment.Left
	sLbl.TextSize = 12
	sLbl.TextColor3 = if active then Color3.fromRGB(178, 232, 184) else C_BRASS
	if active then
		local mins = math.floor(remSec / 60)
		local secs = remSec % 60
		sLbl.Text = string.format(
			"ACTIVE 5-MIN CONTRACT: %s MAFIA (%02d:%02d LEFT)  |  MODE: %s",
			string.upper(mercType),
			mins,
			secs,
			string.upper(tostring(merc.Mode or "ATTACK"))
		)
	else
		sLbl.Text = string.format("HIRE STRONGER 5-MINUTE MERCENARY MAFIA (%s GOLD OR 199 R$)\nStronger than Rival Samurai/Ninja Mafia! Clash with Blade Spark VFX & storm Mafia Restaurants!", formatCommaInt(goldCost))
	end
	sLbl.Parent = statusCard

	-- SIDE-BY-SIDE FIGHTER SHOWDOWN CARDS (Samurai Mafia vs Ninja Assassin Mafia!)
	local vsGrid = makeGridContainer(scrollFrame, 2, 268, 10)
	local mercSpecs = {
		{
			Type = "Samurai",
			Code = "SMR",
			Badge = "IRON SHOGUN  |  5 MIN",
			Name = "KUROGANE SAMURAI MAFIA",
			Stats = "3 ENFORCERS  |  1,550 HP  |  134 KATANA DMG",
			Desc = "Heavy armored Yakuza Samurai Enforcers. Dominates Central Park blade clashes & storms Mafia Restaurants!",
			RobuxId = "SamuraiMafiaContract",
			Col = C_OXBLOOD,
		},
		{
			Type = "Ninja",
			Code = "NJA",
			Badge = "SHADOW CLAN  |  5 MIN",
			Name = "KAGE NINJA ASSASSINS",
			Stats = "3 ASSASSINS  |  1,350 HP  |  1.6X CRIT  |  29 SPD",
			Desc = "Blinding-fast Shinobi Assassins with shadow-step crits & dual tanto flurries. Shreds Rival Mafia squads!",
			RobuxId = "NinjaMafiaContract",
			Col = Color3.fromRGB(124, 58, 237),
		},
	}

	for idx, ms in ipairs(mercSpecs) do
		local c = Instance.new("Frame")
		c.LayoutOrder = idx
		c.BackgroundColor3 = C_BG_CARD:Lerp(ms.Col, 0.18)
		c.BorderSizePixel = 0
		c.ClipsDescendants = true
		c.Parent = vsGrid
		makeCorner(c, 12)
		makeStroke(c, ms.Col, 2.4)

		local topBay = Instance.new("Frame")
		topBay.Size = UDim2.new(1, 0, 0, 122)
		topBay.BackgroundColor3 = ms.Col:Lerp(C_BG_MODAL, 0.45)
		topBay.BorderSizePixel = 0
		topBay.Parent = c

		local aura = Instance.new("Frame")
		aura.AnchorPoint = Vector2.new(0.5, 0.5)
		aura.Position = UDim2.fromScale(0.5, 0.54)
		aura.Size = UDim2.fromOffset(102, 102)
		aura.BackgroundColor3 = ms.Col
		aura.BackgroundTransparency = 0.55
		aura.Parent = topBay
		makeCorner(aura, 51)
		makeStroke(aura, C_GOLD_HI, 1.8, 0.35)

		local vp = ModelPreviewHelper.CreatePreview(topBay, "Empire", ms.Code, UDim2.fromOffset(106, 106), UDim2.new(0.5, -53, 0.5, -50), Color3.fromRGB(18, 24, 38))
		vp.BackgroundTransparency = 1
		local vpSt = vp:FindFirstChildOfClass("UIStroke")
		if vpSt then vpSt:Destroy() end
		makeTag(topBay, ms.Badge, ms.Col:Lerp(C_OUTLINE_DARK, 0.2), UDim2.fromOffset(10, 8), UDim2.fromOffset(132, 18))

		local t = Instance.new("TextLabel")
		t.Position = UDim2.new(0, 12, 0, 128)
		t.Size = UDim2.new(1, -24, 0, 22)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextSize = 15
		t.TextColor3 = C_GOLD_HI
		t.Text = ms.Name
		t.Parent = c
		addTextOutline(t, 1.8)

		local stLbl = Instance.new("TextLabel")
		stLbl.Position = UDim2.new(0, 12, 0, 150)
		stLbl.Size = UDim2.new(1, -24, 0, 16)
		stLbl.BackgroundTransparency = 1
		stLbl.Font = Enum.Font.GothamBold
		stLbl.TextSize = 10
		stLbl.TextColor3 = C_TEXT_PRIMARY
		stLbl.Text = ms.Stats
		stLbl.Parent = c

		local d = Instance.new("TextLabel")
		d.Position = UDim2.new(0, 12, 0, 168)
		d.Size = UDim2.new(1, -24, 0, 42)
		d.BackgroundTransparency = 1
		d.Font = Enum.Font.GothamMedium
		d.TextWrapped = true
		d.TextSize = 10
		d.TextColor3 = C_TEXT_MUTED
		d.Text = ms.Desc
		d.Parent = c

		local gBtn = makeBtn(c, string.format("%s G", formatCommaInt(goldCost)), if coins >= goldCost then C_OXBLOOD else C_DISABLED, UDim2.new(0, 12, 1, -48), UDim2.new(0.5, -16, 0, 38), function()
			if dispatchAction then dispatchAction("HireMercenaryMafia", ms.Type) end
		end)
		gBtn.TextSize = 11

		local rBtn = makeBtn(c, "R$ 199", C_ROBUX, UDim2.new(0.5, 4, 1, -48), UDim2.new(0.5, -16, 0, 38), function()
			showConfirmDialog(
				"CONFIRM 5-MIN MAFIA CONTRACT",
				string.format("Deploy %s for 5 minutes for R$ 199?\nStronger than Rival Samurai/Ninja Mafia — use ATTACK [Y] & CALL BACK [Z] anytime!", ms.Name),
				"HIRE  R$ 199",
				C_ROBUX,
				function()
					if dispatchAction then dispatchAction("BuyRobuxItem", ms.RobuxId) end
				end
			)
		end)
		rBtn.TextSize = 12
	end

	-- Command Panel: Direct your Samurai/Ninja Mafia to storm a Mafia-Controlled Restaurant!
	local cmdCard = makeCard(scrollFrame, 84, C_BRASS)
	local cHead = Instance.new("TextLabel")
	cHead.Position = UDim2.new(0, 14, 0, 6)
	cHead.Size = UDim2.new(1, -24, 0, 18)
	cHead.BackgroundTransparency = 1
	cHead.Font = Enum.Font.GothamBlack
	cHead.TextXAlignment = Enum.TextXAlignment.Left
	cHead.TextSize = 11
	cHead.TextColor3 = C_BRASS
	cHead.Text = "COMMAND HIRED MAFIA SQUAD  —  SELECT TARGET RESTAURANT TO CONQUER"
	cHead.Parent = cmdCard

	local cRow = Instance.new("Frame")
	cRow.Position = UDim2.new(0, 14, 0, 28)
	cRow.Size = UDim2.new(1, -28, 0, 44)
	cRow.BackgroundTransparency = 1
	cRow.Parent = cmdCard
	local cl = Instance.new("UIListLayout")
	cl.FillDirection = Enum.FillDirection.Horizontal
	cl.Padding = UDim.new(0, 6)
	cl.Parent = cRow

	local orders = {
		{ Id = "ObsidianNoodleHouse", Label = "STORM NOODLE HOUSE" },
		{ Id = "VelvetSteakhouse", Label = "STORM STEAKHOUSE" },
		{ Id = "ImperialOysterBar", Label = "STORM OYSTER BAR" },
		{ Id = "Follow", Label = "ESCORT ME" },
	}
	for _, ord in ipairs(orders) do
		local isCur = active and ((ord.Id == "Follow" and targetRest == nil) or (targetRest == ord.Id))
		local ob = makeBtn(cRow, ord.Label, if isCur then C_OWNED elseif active then C_OXBLOOD else C_DISABLED, UDim2.new(), UDim2.new(0.25, -5, 0, 40), function()
			if dispatchAction then dispatchAction("OrderMercenaryAssault", ord.Id) end
		end)
		ob.TextSize = 9
		ob.TextWrapped = true
	end
end

local function renderBlackMarketPremium(state: { [string]: any }): ()
	if not scrollFrame then return end
	local ownedPasses = state.OwnedPasses or {}
	local ownedWeapons = (state.BlackMarket and state.BlackMarket.OwnedWeapons) or {}
	local ownedGear = (state.Bodyguards and state.Bodyguards.OwnedGear) or {}

	-- 3-Column Collectible Black Market VIP Showcase Grid!
	local vipGrid = makeGridContainer(scrollFrame, 3, 250, 10)
	local colors = { C_BRASS, C_OXBLOOD, Color3.fromRGB(124, 58, 237), C_GOLD_HI, C_OXBLOOD, C_BRASS, C_STEEL, C_ROBUX }
	for idx, itemId in ipairs(BLACK_MARKET_ROBUX_IDS) do
		local spec = MonetizationConfig.Items[itemId]
		if spec then
			local isOwned = spec.Kind == "GamePass" and (
				ownedPasses[itemId] == true
				or (itemId == "GoldenEmperorPistolPass" and ownedWeapons.GoldenEmperorPistol == true)
				or (itemId == "CrimsonDragonARPass" and ownedWeapons.CrimsonDragonAR == true)
				or (itemId == "GoldenEmperorSuitPass" and ownedGear.GoldenEmperorSuit == true)
			)
			local themeCol = if isOwned then C_OWNED else colors[((idx - 1) % #colors) + 1]
			makeStoreCollectibleCard(
				vipGrid,
				idx,
				themeCol,
				string.upper(spec.Badge),
				if spec.Kind == "GamePass" then "PERMANENT" else "PACK",
				string.upper(spec.DisplayName),
				spec.Description,
				"Premium",
				itemId,
				if isOwned then "OWNED" else string.format("R$ %d", spec.RobuxPrice),
				if isOwned then C_DISABLED else C_ROBUX,
				function()
					if not isOwned and dispatchAction then
						local kindTxt = if spec.Kind == "GamePass" then "Permanent Game Pass" else "Repeatable Developer Product"
						showConfirmDialog(
							"CONFIRM ROBUX PURCHASE",
							string.format("%s (%s)\nPrice: R$ %d\n\n%s", spec.DisplayName, kindTxt, spec.RobuxPrice, spec.Description),
							string.format("BUY  R$ %d", spec.RobuxPrice),
							C_ROBUX,
							function()
								if dispatchAction then dispatchAction("BuyRobuxItem", itemId) end
							end
						)
					end
				end
			)
		end
	end
end

local function renderMarket(state: { [string]: any }): ()
	if not scrollFrame then return end
	local profile = state.Profile or {}
	local coins = tonumber(profile.Coins) or 0
	local level = tonumber(profile.Level) or 1

	local banner = makeCard(scrollFrame, 56, C_TEAL)
	banner.Name = "CityMarketBanner"
	local bLbl = Instance.new("TextLabel")
	bLbl.Position = UDim2.new(0, 14, 0, 6)
	bLbl.Size = UDim2.new(1, -196, 1, -12)
	bLbl.BackgroundTransparency = 1
	bLbl.Font = Enum.Font.GothamBold
	bLbl.TextWrapped = true
	bLbl.TextXAlignment = Enum.TextXAlignment.Left
	bLbl.TextSize = 11
	bLbl.TextColor3 = C_TEXT_PRIMARY
	bLbl.Text = string.format("CITY MARKET  •  STANDARD AFFORDABLE RATES  |  %s GOLD  |  LEVEL %d\nEveryday firearms, ammo crates, kevlar & city guards — fair street prices, open anywhere!", formatCommaInt(coins), level)
	bLbl.Parent = banner

	local openBmBtn = makeBtn(banner, "BLACK MARKET >", C_OXBLOOD, UDim2.new(1, -174, 0.5, -16), UDim2.fromOffset(162, 32), function()
		AudioController.PlayClick()
		if scrollFrame then
			scrollFrame.CanvasPosition = Vector2.new(0, 0)
		end
		currentTab = "BlackMarket"
		lastRenderedTabSig = ""
		render()
	end)
	openBmBtn.Name = "OpenBlackMarketTabBtn"
	openBmBtn.TextSize = 10

	-- 4 City Market Category Sub-Tabs
	local subBar = Instance.new("Frame")
	subBar.Name = "MarketSubTabBar"
	subBar.Size = UDim2.new(1, -6, 0, 38)
	subBar.BackgroundTransparency = 1
	subBar.Parent = scrollFrame
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.SortOrder = Enum.SortOrder.LayoutOrder
	sl.Padding = UDim.new(0, 5)
	sl.Parent = subBar

	local subTabs: { { Id: MarketSubTab, Label: string, ActiveCol: Color3, Icon: "Gun" | "Ammo" | "Guard" | "Empire" } } = {
		{ Id = "Weapons", Label = "WEAPONS", ActiveCol = C_TEAL, Icon = "Gun" },
		{ Id = "Supplies", Label = "AMMO & GEAR", ActiveCol = C_STEEL, Icon = "Ammo" },
		{ Id = "Bodyguards", Label = "BODYGUARDS", ActiveCol = C_TEAL, Icon = "Guard" },
		{ Id = "GuardGear", Label = "GUARD GEAR", ActiveCol = C_BRASS, Icon = "Empire" },
	}
	for sIdx, st in ipairs(subTabs) do
		local active = (currentMarketSubTab == st.Id)
		local btn = makeBtn(subBar, "", if active then st.ActiveCol else C_BG_CARD_ALT, UDim2.new(), UDim2.new(0.25, -4, 0, 36), function()
			AudioController.PlayClick()
			currentMarketSubTab = st.Id
			render()
		end)
		btn.Name = "MarketSubTab_" .. st.Id
		btn.LayoutOrder = sIdx
		CurrencyIconHelper.CreateCategoryIcon(btn, st.Icon, 24, UDim2.new(0, 8, 0.5, -12), btn.ZIndex + 2)
		local lbl = Instance.new("TextLabel")
		lbl.Name = "SubTabLabel"
		lbl.Position = UDim2.fromOffset(36, 0)
		lbl.Size = UDim2.new(1, -40, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		lbl.Text = st.Label
		lbl.TextSize = 10
		lbl.TextColor3 = if active then Color3.new(1, 1, 1) else C_TEXT_PRIMARY
		lbl.ZIndex = btn.ZIndex + 2
		lbl.Active = false
		lbl.Parent = btn
		addTextOutline(lbl, 1.4)
		if active then
			local stroke = btn:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = C_GOLD_HI
				stroke.Thickness = 1.8
			end
		end
	end

	if currentMarketSubTab == "Weapons" then
		renderWeaponsForTier(state, "Market")
	elseif currentMarketSubTab == "Supplies" then
		renderMarketSupplies(state)
	elseif currentMarketSubTab == "Bodyguards" then
		renderBodyguardsForTier(state, "Market", "Classes")
	else
		renderBodyguardsForTier(state, "Market", "Gear")
	end
end

local function renderBlackMarket(state: { [string]: any }): ()
	if not scrollFrame then return end
	local profile = state.Profile or {}
	local coins = tonumber(profile.Coins) or 0
	local level = tonumber(profile.Level) or 1
	local bm = if typeof(state.BlackMarket) == "table" then state.BlackMarket else {}
	local deal = if typeof(bm.SmugglerDeal) == "table" then bm.SmugglerDeal else nil
	local quip = if deal and typeof(deal.Quip) == "string"
		then deal.Quip
		else "\"2x-4x contraband markup? Hey, bribing the Health Inspector ain't cheap!\""

	local warpCard = makeCard(scrollFrame, 60, C_OXBLOOD)
	warpCard.Name = "BlackMarketBanner"
	local wLbl = Instance.new("TextLabel")
	wLbl.Position = UDim2.new(0, 14, 0, 6)
	wLbl.Size = UDim2.new(1, -284, 0, 19)
	wLbl.BackgroundTransparency = 1
	wLbl.Font = Enum.Font.GothamBlack
	wLbl.TextTruncate = Enum.TextTruncate.AtEnd
	wLbl.TextXAlignment = Enum.TextXAlignment.Left
	wLbl.TextSize = 11
	wLbl.TextColor3 = C_TEXT_PRIMARY
	wLbl.Text = string.format("UNDERGROUND BLACK MARKET  •  2X-4X CONTRABAND  |  %s GOLD  |  LV.%d", formatCommaInt(coins), level)
	wLbl.Parent = warpCard

	local qLbl = Instance.new("TextLabel")
	qLbl.Name = "SmugglerQuipLabel"
	qLbl.Position = UDim2.new(0, 14, 0, 26)
	qLbl.Size = UDim2.new(1, -284, 0, 28)
	qLbl.BackgroundTransparency = 1
	qLbl.Font = Enum.Font.GothamMedium
	qLbl.TextWrapped = true
	qLbl.TextTruncate = Enum.TextTruncate.AtEnd
	qLbl.TextXAlignment = Enum.TextXAlignment.Left
	qLbl.TextSize = 10
	qLbl.TextColor3 = C_GOLD_HI
	qLbl.Text = "DON VINNIE: " .. quip
	qLbl.Parent = warpCard

	local marketSwitchBtn = makeBtn(warpCard, "< CITY MARKET", C_TEAL, UDim2.new(1, -268, 0.5, -16), UDim2.fromOffset(118, 32), function()
		AudioController.PlayClick()
		if scrollFrame then
			scrollFrame.CanvasPosition = Vector2.new(0, 0)
		end
		currentTab = "Market"
		lastRenderedTabSig = ""
		render()
	end)
	marketSwitchBtn.Name = "BackToCityMarketBtn"
	marketSwitchBtn.TextSize = 10

	local visitBtn = makeBtn(warpCard, "TELEPORT OUTPOST", C_BG_SUBTLE, UDim2.new(1, -144, 0.5, -16), UDim2.fromOffset(134, 32), function()
		EmpireMenuController.Close()
		if dispatchAction then dispatchAction("TeleportBlackMarket", nil) end
	end)
	visitBtn.Name = "TeleportOutpostBtn"
	visitBtn.TextSize = 10

	-- LIVE ROTATING 5-MINUTE SMUGGLER'S SECRET DROP (35% OFF DAY / 45% OFF NIGHT — HUGE CCU RETENTION HOOK!)
	if deal and typeof(deal.ItemId) == "string" then
		local ownedWeapons = if typeof(bm.OwnedWeapons) == "table" then bm.OwnedWeapons else {}
		local bgState = if typeof(state.Bodyguards) == "table" then state.Bodyguards else {}
		local unlockedClasses = if typeof(bgState.UnlockedClasses) == "table" then bgState.UnlockedClasses else {}
		local ownedGear = if typeof(bgState.OwnedGear) == "table" then bgState.OwnedGear else {}
		local ownedPasses = if typeof(state.OwnedPasses) == "table" then state.OwnedPasses else {}

		local dealOwned = false
		if deal.Category == "Weapon" then
			dealOwned = ownedWeapons[deal.ItemId] == true
		elseif deal.Category == "GuardClass" then
			dealOwned = unlockedClasses[deal.ItemId] == true or (deal.RobuxItemId ~= nil and ownedPasses[deal.RobuxItemId] == true)
		elseif deal.Category == "GuardGear" then
			dealOwned = ownedGear[deal.ItemId] == true or (deal.RobuxItemId ~= nil and ownedPasses[deal.RobuxItemId] == true)
		else
			dealOwned = bm.HasShadowDash == true
		end

		local reqLv = tonumber(deal.RequiredLevel) or 1
		local dealLocked = (not dealOwned) and level < reqLv
		local dealPrice = tonumber(deal.DealPrice) or 0
		local basePrice = tonumber(deal.BasePrice) or dealPrice
		local discPct = tonumber(deal.DiscountPct) or 35
		local remSec = math.max(0, tonumber(deal.TimeRemaining) or 0)
		local remM = math.floor(remSec / 60)
		local remS = remSec % 60
		local isNightSale = deal.IsNightBonus == true

		local dropCard = makeCard(scrollFrame, 72, if isNightSale then Color3.fromRGB(168, 85, 247) else C_GOLD_HI)
		dropCard.Name = "SmugglerDropCard"
		dropCard.BackgroundColor3 = C_BG_CARD:Lerp(if isNightSale then Color3.fromRGB(124, 58, 237) else C_BRASS, 0.20)
		local dropStroke = dropCard:FindFirstChildOfClass("UIStroke")
		if dropStroke then
			dropStroke.Color = C_GOLD_HI
			dropStroke.Thickness = 2.2
		end

		local prevCat = tostring(deal.PreviewCategory or "Weapon")
		local prevId = tostring(deal.PreviewId or deal.ItemId)
		ModelPreviewHelper.CreatePreview(dropCard, prevCat :: any, prevId, UDim2.fromOffset(56, 56), UDim2.new(0, 10, 0.5, -28), Color3.fromRGB(18, 22, 34), C_GOLD_HI)

		local saleBadgeTxt = if isNightSale
			then string.format("MIDNIGHT HEIST  •  -%d%% GOLD", discPct)
			else string.format("DON VINNIE'S DROP  •  -%d%% GOLD", discPct)
		makeTag(dropCard, saleBadgeTxt, if isNightSale then Color3.fromRGB(124, 58, 237) else C_OXBLOOD, UDim2.fromOffset(74, 7), UDim2.fromOffset(184, 17))
		makeTag(dropCard, string.format("ROTATES %02d:%02d", remM, remS), Color3.fromRGB(16, 22, 36), UDim2.fromOffset(264, 7), UDim2.fromOffset(102, 17))

		local dTitle = Instance.new("TextLabel")
		dTitle.Position = UDim2.new(0, 74, 0, 27)
		dTitle.Size = UDim2.new(1, -304, 0, 19)
		dTitle.BackgroundTransparency = 1
		dTitle.Font = Enum.Font.GothamBlack
		dTitle.TextXAlignment = Enum.TextXAlignment.Left
		dTitle.TextTruncate = Enum.TextTruncate.AtEnd
		dTitle.TextSize = 13
		dTitle.TextColor3 = Color3.new(1, 1, 1)
		dTitle.Text = string.upper(tostring(deal.DisplayName or deal.ItemId))
		dTitle.Parent = dropCard
		addTextOutline(dTitle, 1.5)

		local dSub = Instance.new("TextLabel")
		dSub.Position = UDim2.new(0, 74, 0, 48)
		dSub.Size = UDim2.new(1, -304, 0, 16)
		dSub.BackgroundTransparency = 1
		dSub.Font = Enum.Font.GothamBold
		dSub.TextXAlignment = Enum.TextXAlignment.Left
		dSub.TextTruncate = Enum.TextTruncate.AtEnd
		dSub.TextSize = 10
		dSub.TextColor3 = C_GOLD_HI
		dSub.Text = string.format(
			"STREET %sG  ->  DROP %sG  (SAVE %sG!%s)",
			formatCommaInt(basePrice),
			formatCommaInt(dealPrice),
			formatCommaInt(math.max(0, basePrice - dealPrice)),
			if isNightSale then " • NIGHT BONUS!" else " • 45% OFF AT NIGHT"
		)
		dSub.Parent = dropCard

		if dealOwned then
			local ownBtn = makeBtn(dropCard, "ALREADY OWNED", C_OWNED, UDim2.new(1, -158, 0.5, -18), UDim2.fromOffset(146, 36), function() end)
			ownBtn.TextSize = 10
		else
			local hasDealRobux = typeof(deal.RobuxPrice) == "number" and deal.RobuxPrice > 0
			local gBtnW = if hasDealRobux then 124 else 206
			local gBtnX = if hasDealRobux then -218 else -218
			local gTxt = if dealLocked then string.format("LV.%d LOCK", reqLv) else string.format("SNAG %sG", formatCommaInt(dealPrice))
			local gCol = if dealLocked or coins < dealPrice then C_DISABLED else C_BRASS
			local snagBtn = makeBtn(dropCard, gTxt, gCol, UDim2.new(1, gBtnX, 0.5, -18), UDim2.fromOffset(gBtnW, 36), function()
				if not dispatchAction then return end
				if deal.Category == "Weapon" then
					dispatchAction("BuyBlackMarketItem", deal.ItemId)
				elseif deal.Category == "GuardClass" then
					dispatchAction("RecruitBodyguard", { ClassId = deal.ItemId, SlotIndex = selectedGuardSlot })
				elseif deal.Category == "GuardGear" then
					dispatchAction("BuyGuardGear", deal.ItemId)
				else
					dispatchAction("BuyShadowDash", nil)
				end
			end)
			snagBtn.Name = "SmugglerDropBuyGoldBtn"
			snagBtn.TextSize = 10

			if hasDealRobux and deal.RobuxPrice then
				local rPrice = deal.RobuxPrice
				local rBtn = makeBtn(dropCard, string.format("R$ %d", rPrice), C_ROBUX, UDim2.new(1, -88, 0.5, -18), UDim2.fromOffset(78, 36), function()
					if not dispatchAction then return end
					if deal.RobuxItemId then
						dispatchAction("BuyRobuxItem", deal.RobuxItemId)
					elseif deal.Category == "Weapon" then
						dispatchAction("BuyWithRobuxOption", { Kind = "BuyBlackMarketItem", Arg = deal.ItemId })
					elseif deal.Category == "GuardClass" then
						dispatchAction("RecruitBodyguard", { ClassId = deal.ItemId, SlotIndex = selectedGuardSlot, UseRobux = true })
					elseif deal.Category == "GuardGear" then
						dispatchAction("BuyWithRobuxOption", { Kind = "BuyGuardGear", Arg = deal.ItemId })
					else
						dispatchAction("BuyWithRobuxOption", { Kind = "BuyShadowDash" })
					end
				end)
				rBtn.Name = "SmugglerDropBuyRobuxBtn"
				rBtn.TextSize = 10
			end
		end
	end

	-- 5 Underground Black Market Sub-Tabs
	local subBar = Instance.new("Frame")
	subBar.Name = "BMSubTabBar"
	subBar.Size = UDim2.new(1, -6, 0, 38)
	subBar.BackgroundTransparency = 1
	subBar.Parent = scrollFrame
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.SortOrder = Enum.SortOrder.LayoutOrder
	sl.Padding = UDim.new(0, 5)
	sl.Parent = subBar

	local subTabs: { { Id: BlackMarketSubTab, Label: string, ActiveCol: Color3, Icon: "Gun" | "Ammo" | "Guard" | "Ninja" | "Robux" } } = {
		{ Id = "Weapons", Label = "CONTRABAND", ActiveCol = C_OXBLOOD, Icon = "Gun" },
		{ Id = "Gadgets", Label = "GADGETS", ActiveCol = C_BRASS, Icon = "Ammo" },
		{ Id = "Bodyguards", Label = "ELITE GUARDS", ActiveCol = C_OXBLOOD, Icon = "Guard" },
		{ Id = "Mercenaries", Label = "MAFIA HIRE", ActiveCol = C_OXBLOOD, Icon = "Ninja" },
		{ Id = "Premium", Label = "R$ VIP", ActiveCol = C_ROBUX, Icon = "Robux" },
	}
	for sIdx, st in ipairs(subTabs) do
		local active = (currentBMSubTab == st.Id)
		local btn = makeBtn(subBar, if st.Icon == "Robux" then st.Label else "", if active then st.ActiveCol else C_BG_CARD_ALT, UDim2.new(), UDim2.new(0.20, -4, 0, 36), function()
			AudioController.PlayClick()
			currentBMSubTab = st.Id
			render()
		end)
		btn.Name = "BMSubTab_" .. st.Id
		btn.LayoutOrder = sIdx
		btn.TextSize = 10
		if st.Icon ~= "Robux" then
			CurrencyIconHelper.CreateCategoryIcon(btn, st.Icon, 24, UDim2.new(0, 7, 0.5, -12), btn.ZIndex + 2)
			local lbl = Instance.new("TextLabel")
			lbl.Name = "SubTabLabel"
			lbl.Position = UDim2.fromOffset(34, 0)
			lbl.Size = UDim2.new(1, -38, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamBlack
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.Text = st.Label
			lbl.TextSize = 10
			lbl.TextColor3 = if active then Color3.new(1, 1, 1) else C_TEXT_PRIMARY
			lbl.ZIndex = btn.ZIndex + 2
			lbl.Active = false
			lbl.Parent = btn
			addTextOutline(lbl, 1.4)
		end
		if active then
			local stroke = btn:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if st.Id == "Premium" then C_GOLD_HI else C_BRASS
				stroke.Thickness = 1.8
			end
		end
	end

	if currentBMSubTab == "Weapons" then
		renderWeaponsForTier(state, "BlackMarket")
	elseif currentBMSubTab == "Gadgets" then
		renderBlackMarketGadgets(state)
	elseif currentBMSubTab == "Bodyguards" then
		renderBodyguardsForTier(state, "BlackMarket", nil)
	elseif currentBMSubTab == "Mercenaries" then
		renderBlackMarketMercenaries(state)
	else
		renderBlackMarketPremium(state)
	end
end

local function updateVisibleViewports(): ()
	local sf = scrollFrame
	if not sf or not modalFrame or not modalFrame.Visible then
		return
	end
	if sf.AbsoluteSize.Y <= 10 then
		return
	end
	local viewTop = sf.AbsolutePosition.Y - 120
	local viewBot = sf.AbsolutePosition.Y + sf.AbsoluteSize.Y + 120
	local visibleCount = 0
	for _, desc in ipairs(sf:GetDescendants()) do
		if desc:IsA("ViewportFrame") then
			-- Wait until layout has actually positioned this ViewportFrame (avoid false-culling at Y=0 on frame 0!)
			if desc.AbsoluteSize.Y > 1 then
				local cTop = desc.AbsolutePosition.Y
				local cBot = cTop + desc.AbsoluteSize.Y
				local inView = (cBot >= viewTop) and (cTop <= viewBot)
				local wantVis = inView and visibleCount < 24
				if wantVis then
					visibleCount += 1
				end
				if desc.Visible ~= wantVis then
					desc.Visible = wantVis
					if wantVis and desc.CurrentCamera then
						local cam = desc.CurrentCamera
						desc.CurrentCamera = nil
						desc.CurrentCamera = cam
					end
				end
			end
		end
	end
end

render = function(): ()
	if not modalFrame or not modalFrame.Visible then
		return
	end
	local state = latestState or {}
	clearScroll()
	refreshTabStyles()
	local prof = if typeof(state.Profile) == "table" then state.Profile else {}
	if headerGoldValLbl then
		headerGoldValLbl.Text = formatCommaInt(tonumber(prof.Coins) or 0)
	end
	if headerRankValLbl then
		headerRankValLbl.Text = string.format("LV.%d  |  %s REP", tonumber(prof.Level) or 1, formatCommaInt(tonumber(prof.Reputation) or 0))
	end
	local curTheme = TAB_THEMES[currentTab]
	if titleLabel and subtitleLabel and curTheme then
		titleLabel.Text = curTheme.Title
		subtitleLabel.Text = curTheme.Sub
	end
	if currentTab == "Kitchen" then
		renderKitchen(state)
	elseif currentTab == "Warehouses" then
		renderWarehouses(state)
	elseif currentTab == "Market" then
		renderMarket(state)
	elseif currentTab == "BlackMarket" then
		renderBlackMarket(state)
	elseif currentTab == "Shop" then
		renderShop(state)
	else
		renderUpgrades(state)
	end
	-- Wait for UIListLayout / UIGridLayout to compute positions before culling offscreen 3D ViewportFrames!
	task.defer(updateVisibleViewports)
	task.delay(0.10, updateVisibleViewports)
	task.delay(0.30, updateVisibleViewports)
end

function EmpireMenuController.Init(_parentGui: ScreenGui, onAction: ActionCallback): ()
	dispatchAction = onAction

	-- Dedicated DisplayOrder = 40 ScreenGui (ZIndexBehavior = Sibling, IgnoreGuiInset = false so modal never collides with TopBar/Chat!)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local oldGui = pg:FindFirstChild("EmpireMenuGui")
	if oldGui then oldGui:Destroy() end
	local menuGui = Instance.new("ScreenGui")
	menuGui.Name = "EmpireMenuGui"
	menuGui.DisplayOrder = 40
	menuGui.IgnoreGuiInset = false
	menuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	menuGui.ResetOnSpawn = false
	menuGui.Parent = pg

	local dim = Instance.new("Frame")
	dim.Name = "EmpireMenuBackdrop"
	dim.Position = UDim2.fromOffset(0, -64)
	dim.Size = UDim2.new(1, 0, 1, 128)
	dim.BackgroundColor3 = Color3.fromRGB(6, 9, 16)
	dim.BackgroundTransparency = 0.38
	dim.BorderSizePixel = 0
	dim.Active = false
	dim.Visible = false
	dim.ZIndex = 1
	dim.Parent = menuGui
	backdropFrame = dim

	-- FRONT-PAGE ROBLOX GAME WINDOW CHASSIS (Left Game Sidebar + Right Dynamic Showcase Stage!)
	local modal = Instance.new("Frame")
	modal.Name = "EmpireMenuModal"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.51)
	modal.Size = UDim2.fromScale(0.88, 0.82)
	modal.BackgroundColor3 = C_BG_MODAL
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ClipsDescendants = true
	modal.ZIndex = 2
	modal.Parent = menuGui
	makeCorner(modal, 14)
	makeStroke(modal, C_OUTLINE_DARK, 3.2)
	local sizeCon = Instance.new("UISizeConstraint")
	sizeCon.MinSize = Vector2.new(680, 420)
	sizeCon.MaxSize = Vector2.new(940, 570)
	sizeCon.Parent = modal
	modalFrame = modal

	-- Thick 3D Bottom Chassis Shadow Bar
	local chassisBottomLip = Instance.new("Frame")
	chassisBottomLip.AnchorPoint = Vector2.new(0, 1)
	chassisBottomLip.Position = UDim2.fromScale(0, 1)
	chassisBottomLip.Size = UDim2.new(1, 0, 0, 6)
	chassisBottomLip.BackgroundColor3 = C_OUTLINE_DARK
	chassisBottomLip.BackgroundTransparency = 0.25
	chassisBottomLip.BorderSizePixel = 0
	chassisBottomLip.Active = false
	chassisBottomLip.ZIndex = 20
	chassisBottomLip.Parent = modal

	-- =========================================================================
	-- LEFT VERTICAL GAME NAVIGATION SIDEBAR (184px wide with Real 3D Category Icons!)
	-- =========================================================================
	local sidebar = Instance.new("Frame")
	sidebar.Name = "GameNavSidebar"
	sidebar.Position = UDim2.new(0, 0, 0, 0)
	sidebar.Size = UDim2.new(0, 184, 1, 0)
	sidebar.BackgroundColor3 = C_BG_SIDEBAR
	sidebar.BorderSizePixel = 0
	sidebar.ZIndex = 4
	sidebar.Parent = modal

	local sideDivider = Instance.new("Frame")
	sideDivider.AnchorPoint = Vector2.new(1, 0)
	sideDivider.Position = UDim2.fromScale(1, 0)
	sideDivider.Size = UDim2.new(0, 2, 1, 0)
	sideDivider.BackgroundColor3 = C_BORDER
	sideDivider.BorderSizePixel = 0
	sideDivider.Parent = sidebar

	-- Bold Game Logo Emblem at Top-Left of Sidebar (Y = 12..62)
	local brandCard = Instance.new("Frame")
	brandCard.Position = UDim2.fromOffset(12, 12)
	brandCard.Size = UDim2.new(1, -24, 0, 50)
	brandCard.BackgroundColor3 = Color3.fromRGB(28, 38, 62)
	brandCard.BorderSizePixel = 0
	brandCard.Parent = sidebar
	makeCorner(brandCard, 10)
	makeStroke(brandCard, C_BRASS, 2.0)

	local bGrad = Instance.new("UIGradient")
	bGrad.Rotation = 135
	bGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(245, 168, 28)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(168, 32, 48)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 32, 54)),
	})
	bGrad.Parent = brandCard

	local brandTop = Instance.new("TextLabel")
	brandTop.Position = UDim2.fromOffset(0, 5)
	brandTop.Size = UDim2.new(1, 0, 0, 22)
	brandTop.BackgroundTransparency = 1
	brandTop.Font = Enum.Font.GothamBlack
	brandTop.Text = "FOOD EMPIRE"
	brandTop.TextSize = 16
	brandTop.TextColor3 = Color3.new(1, 1, 1)
	brandTop.Parent = brandCard
	addTextOutline(brandTop, 2.0)

	local brandSub = Instance.new("TextLabel")
	brandSub.Position = UDim2.fromOffset(0, 28)
	brandSub.Size = UDim2.new(1, 0, 0, 16)
	brandSub.BackgroundTransparency = 1
	brandSub.Font = Enum.Font.GothamBlack
	brandSub.Text = "SYNDICATE HQ"
	brandSub.TextSize = 10
	brandSub.TextColor3 = C_GOLD_HI
	brandSub.Parent = brandCard
	addTextOutline(brandSub, 1.4)

	-- Live Player Wallet Card directly under Logo (Y = 66..148) — keeps ALL 6 nav buttons safely BELOW CoreGui ExperienceChat's top-left hitbox and inside 420px min modal height!
	local walletCard = Instance.new("Frame")
	walletCard.Name = "SidebarWalletCard"
	walletCard.Position = UDim2.fromOffset(12, 66)
	walletCard.Size = UDim2.new(1, -24, 0, 82)
	walletCard.BackgroundColor3 = Color3.fromRGB(22, 30, 48)
	walletCard.BorderSizePixel = 0
	walletCard.Parent = sidebar
	makeCorner(walletCard, 10)
	makeStroke(walletCard, C_BRASS, 1.8)

	local wLabel = Instance.new("TextLabel")
	wLabel.Position = UDim2.fromOffset(10, 5)
	wLabel.Size = UDim2.new(1, -20, 0, 13)
	wLabel.BackgroundTransparency = 1
	wLabel.Font = Enum.Font.GothamBlack
	wLabel.TextXAlignment = Enum.TextXAlignment.Left
	wLabel.Text = "YOUR BALANCE"
	wLabel.TextSize = 9
	wLabel.TextColor3 = C_TEXT_DIM
	wLabel.Parent = walletCard

	local goldPill = Instance.new("Frame")
	goldPill.Name = "HeaderGoldPill"
	goldPill.Position = UDim2.fromOffset(8, 20)
	goldPill.Size = UDim2.new(1, -16, 0, 30)
	goldPill.BackgroundColor3 = Color3.fromRGB(34, 26, 12)
	goldPill.BorderSizePixel = 0
	goldPill.Parent = walletCard
	makeCorner(goldPill, 7)
	makeStroke(goldPill, C_GOLD_HI, 1.6)
	CurrencyIconHelper.CreateGoldCoin(goldPill, 20, UDim2.new(0, 7, 0.5, -10), 4)
	local gVal = Instance.new("TextLabel")
	gVal.Position = UDim2.new(0, 32, 0, 0)
	gVal.Size = UDim2.new(1, -36, 1, 0)
	gVal.BackgroundTransparency = 1
	gVal.Font = Enum.Font.GothamBlack
	gVal.TextXAlignment = Enum.TextXAlignment.Left
	gVal.Text = "0"
	gVal.TextSize = 15
	gVal.TextColor3 = C_GOLD_HI
	gVal.Parent = goldPill
	addTextOutline(gVal, 1.6)
	headerGoldValLbl = gVal

	local rankPill = Instance.new("TextLabel")
	rankPill.Name = "HeaderRankPill"
	rankPill.Position = UDim2.fromOffset(8, 55)
	rankPill.Size = UDim2.new(1, -16, 0, 20)
	rankPill.BackgroundColor3 = Color3.fromRGB(16, 22, 36)
	rankPill.Font = Enum.Font.GothamBlack
	rankPill.Text = "LV.1  |  0 REP"
	rankPill.TextSize = 10
	rankPill.TextColor3 = C_TEXT_PRIMARY
	rankPill.Parent = walletCard
	makeCorner(rankPill, 5)
	makeStroke(rankPill, C_BORDER, 1.2)
	headerRankValLbl = rankPill

	-- 6 Chunky Tactile 3D Sidebar Nav Buttons (Y = 156..409 — fits cleanly at 420px min height & 100% clear of Chat!)
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Position = UDim2.fromOffset(12, 156)
	tabBar.Size = UDim2.new(1, -24, 1, -166)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = sidebar

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Vertical
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 5)
	tabLayout.Parent = tabBar

	local tabs: { { Id: MenuTab, Label: string, Icon: "Food" | "Storage" | "Empire" | "Market" | "Gun" | "Robux", BadgeBg: Color3 } } = {
		{ Id = "Kitchen", Label = "KITCHEN", Icon = "Food", BadgeBg = Color3.fromRGB(64, 42, 16) },
		{ Id = "Warehouses", Label = "STORAGE", Icon = "Storage", BadgeBg = Color3.fromRGB(16, 48, 76) },
		{ Id = "Upgrades", Label = "EMPIRE", Icon = "Empire", BadgeBg = Color3.fromRGB(68, 52, 14) },
		{ Id = "Market", Label = "MARKET", Icon = "Market", BadgeBg = Color3.fromRGB(12, 62, 68) },
		{ Id = "BlackMarket", Label = "BLACK MARKET", Icon = "Gun", BadgeBg = Color3.fromRGB(76, 18, 30) },
		{ Id = "Shop", Label = "ROBUX STORE", Icon = "Robux", BadgeBg = Color3.fromRGB(14, 60, 40) },
	}
	table.clear(tabButtons)
	table.clear(tabLabels)
	table.clear(tabActiveBars)
	for tIdx, t in ipairs(tabs) do
		local tb = makeBtn(tabBar, "", C_BG_CARD, UDim2.new(), UDim2.new(1, 0, 0, 38), function()
			AudioController.PlayClick()
			hideConfirmDialog()
			if currentTab ~= t.Id and scrollFrame then
				scrollFrame.CanvasPosition = Vector2.new(0, 0)
			end
			currentTab = t.Id
			lastRenderedTabSig = ""
			render()
		end)
		tb.Name = "SidebarTab_" .. t.Id
		tb.LayoutOrder = tIdx

		local activeBar = Instance.new("Frame")
		activeBar.Position = UDim2.fromOffset(4, 6)
		activeBar.Size = UDim2.new(0, 4, 1, -15)
		activeBar.BackgroundColor3 = Color3.new(1, 1, 1)
		activeBar.BorderSizePixel = 0
		activeBar.Active = false
		activeBar.Visible = false
		activeBar.ZIndex = 5
		activeBar.Parent = tb
		makeCorner(activeBar, 3)

		-- Framed high-contrast Icon Medallion so EVERY category icon pops sharply on any tab state!
		local iconMedallion = Instance.new("Frame")
		iconMedallion.Name = "IconMedallion"
		iconMedallion.Position = UDim2.new(0, 10, 0.5, -15)
		iconMedallion.Size = UDim2.fromOffset(28, 28)
		iconMedallion.BackgroundColor3 = t.BadgeBg
		iconMedallion.BorderSizePixel = 0
		iconMedallion.Active = false
		iconMedallion.ZIndex = 4
		iconMedallion.Parent = tb
		makeCorner(iconMedallion, 7)
		makeStroke(iconMedallion, Color3.fromRGB(12, 14, 22), 1.4)

		local iconSz = if t.Icon == "Robux" then 20 else 22
		local iconOff = math.floor((28 - iconSz) * 0.5)
		CurrencyIconHelper.CreateCategoryIcon(
			iconMedallion,
			t.Icon,
			iconSz,
			UDim2.fromOffset(iconOff, iconOff),
			5
		)

		local tLbl = Instance.new("TextLabel")
		tLbl.Name = "TabLabel"
		tLbl.Position = UDim2.fromOffset(44, 0)
		tLbl.Size = UDim2.new(1, -48, 1, -3)
		tLbl.BackgroundTransparency = 1
		tLbl.Font = Enum.Font.GothamBlack
		tLbl.TextXAlignment = Enum.TextXAlignment.Left
		tLbl.TextTruncate = Enum.TextTruncate.AtEnd
		tLbl.Text = t.Label
		tLbl.TextSize = 11
		tLbl.TextColor3 = C_TEXT_MUTED
		tLbl.Active = false
		tLbl.ZIndex = 4
		tLbl.Parent = tb
		addTextOutline(tLbl, 1.6)

		tabActiveBars[t.Id] = activeBar
		tabLabels[t.Id] = tLbl
		tabButtons[t.Id] = tb
	end

	-- =========================================================================
	-- RIGHT DYNAMIC SHOWCASE STAGE (Vibrant Themed Header + Multi-Column Scroll Stage!)
	-- =========================================================================
	local stagePane = Instance.new("Frame")
	stagePane.Name = "StagePane"
	stagePane.Position = UDim2.fromOffset(184, 0)
	stagePane.Size = UDim2.new(1, -184, 1, 0)
	stagePane.BackgroundTransparency = 1
	stagePane.ZIndex = 3
	stagePane.Parent = modal

	-- Dynamic Per-Tab Colored Header Banner with Diagonal Light Rays & Hero Category Icon!
	local headBar = Instance.new("Frame")
	headBar.Name = "StageHeaderBanner"
	headBar.Size = UDim2.new(1, 0, 0, 72)
	headBar.BackgroundColor3 = C_BRASS
	headBar.BorderSizePixel = 0
	headBar.ClipsDescendants = true
	headBar.Parent = stagePane
	stageHeaderBar = headBar

	local hGrad = Instance.new("UIGradient")
	hGrad.Rotation = 12
	hGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C_BRASS),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(128, 72, 16)),
		ColorSequenceKeypoint.new(1, C_BG_MODAL),
	})
	hGrad.Parent = headBar
	stageHeaderGrad = hGrad

	-- Dynamic diagonal shine stripes across header
	for sIdx = 1, 3 do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.25 + sIdx * 0.22, 0.5)
		ray.Size = UDim2.new(0, 30, 2.2, 0)
		ray.Rotation = 24
		ray.BackgroundColor3 = Color3.new(1, 1, 1)
		ray.BackgroundTransparency = 0.88
		ray.BorderSizePixel = 0
		ray.Parent = headBar
	end

	local headLine = Instance.new("Frame")
	headLine.AnchorPoint = Vector2.new(0, 1)
	headLine.Position = UDim2.fromScale(0, 1)
	headLine.Size = UDim2.new(1, 0, 0, 3)
	headLine.BackgroundColor3 = C_OUTLINE_DARK
	headLine.BackgroundTransparency = 0.25
	headLine.BorderSizePixel = 0
	headLine.Parent = headBar

	-- Glowing Category Hero Icon Medallion inside the Stage Header Banner!
	local hIconSlot = Instance.new("Frame")
	hIconSlot.Name = "StageHeaderIconSlot"
	hIconSlot.Position = UDim2.fromOffset(14, 11)
	hIconSlot.Size = UDim2.fromOffset(50, 50)
	hIconSlot.BackgroundColor3 = Color3.fromRGB(14, 20, 34)
	hIconSlot.BackgroundTransparency = 0.28
	hIconSlot.BorderSizePixel = 0
	hIconSlot.ZIndex = 3
	hIconSlot.Parent = headBar
	makeCorner(hIconSlot, 12)
	makeStroke(hIconSlot, Color3.new(1, 1, 1), 1.6, 0.45)
	stageHeaderIconSlot = hIconSlot
	lastHeaderIconTab = nil

	local header = Instance.new("TextLabel")
	header.Position = UDim2.new(0, 74, 0, 10)
	header.Size = UDim2.new(1, -142, 0, 30)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBlack
	header.Text = "FOOD EMPIRE"
	header.TextSize = 24
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Color3.new(1, 1, 1)
	header.Parent = headBar
	addTextOutline(header, 2.4)
	titleLabel = header

	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.new(0, 74, 0, 42)
	sub.Size = UDim2.new(1, -142, 0, 18)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.Text = ""
	sub.TextSize = 11
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = Color3.fromRGB(242, 246, 255)
	sub.Parent = headBar
	addTextOutline(sub, 1.3)
	subtitleLabel = sub

	-- Chunky 3D Bright-Red [X] Close Button!
	local closeBtn = makeBtn(headBar, "X", Color3.fromRGB(225, 29, 64), UDim2.new(1, -54, 0.5, -20), UDim2.fromOffset(40, 40), function()
		AudioController.PlayClick()
		EmpireMenuController.Close()
	end)
	closeBtn.Name = "CloseMenuBtn"
	closeBtn.TextSize = 18

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.new(0, 14, 0, 82)
	scroll.Size = UDim2.new(1, -24, 1, -96)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = C_BRASS
	scroll.Parent = stagePane

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = scroll
	nextAutoOrder = 0
	scroll.ChildAdded:Connect(function(ch: Instance)
		if ch:IsA("GuiObject") and ch.LayoutOrder == 0 then
			nextAutoOrder += 1
			ch.LayoutOrder = nextAutoOrder
		end
	end)
	scrollFrame = scroll
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateVisibleViewports)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateVisibleViewports)

	-- Chunky Confirmation Dialog Overlay (for expensive Gold >= 500G & Robux purchases)
	local overlay = Instance.new("Frame")
	overlay.Name = "ConfirmPurchaseOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(4, 6, 12)
	overlay.BackgroundTransparency = 0.22
	overlay.Visible = false
	overlay.ZIndex = 40
	overlay.Parent = modal
	makeCorner(overlay, 14)
	confirmOverlay = overlay

	local dialog = Instance.new("Frame")
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	dialog.Position = UDim2.fromScale(0.5, 0.5)
	dialog.Size = UDim2.fromOffset(436, 224)
	dialog.BackgroundColor3 = C_BG_CARD
	dialog.ZIndex = 41
	dialog.Parent = overlay
	makeCorner(dialog, 12)
	makeStroke(dialog, C_GOLD_HI, 2.4)

	local cTitle = Instance.new("TextLabel")
	cTitle.Position = UDim2.new(0, 18, 0, 14)
	cTitle.Size = UDim2.new(1, -36, 0, 26)
	cTitle.BackgroundTransparency = 1
	cTitle.Font = Enum.Font.GothamBlack
	cTitle.Text = "CONFIRM PURCHASE"
	cTitle.TextSize = 17
	cTitle.TextXAlignment = Enum.TextXAlignment.Left
	cTitle.TextColor3 = C_GOLD_HI
	cTitle.ZIndex = 42
	cTitle.Parent = dialog
	addTextOutline(cTitle, 1.8)
	confirmTitleLbl = cTitle

	local cDesc = Instance.new("TextLabel")
	cDesc.Position = UDim2.new(0, 18, 0, 44)
	cDesc.Size = UDim2.new(1, -36, 0, 104)
	cDesc.BackgroundTransparency = 1
	cDesc.Font = Enum.Font.Gotham
	cDesc.TextWrapped = true
	cDesc.TextXAlignment = Enum.TextXAlignment.Left
	cDesc.TextYAlignment = Enum.TextYAlignment.Top
	cDesc.TextSize = 12
	cDesc.TextColor3 = C_TEXT_PRIMARY
	cDesc.Text = ""
	cDesc.ZIndex = 42
	cDesc.Parent = dialog
	confirmDescLbl = cDesc

	local cancelBtn = makeBtn(dialog, "CANCEL", C_BG_SUBTLE, UDim2.new(0, 18, 1, -52), UDim2.fromOffset(182, 38), function()
		hideConfirmDialog()
	end)
	cancelBtn.ZIndex = 42

	local yesBtn = makeBtn(dialog, "CONFIRM", C_OXBLOOD, UDim2.new(1, -200, 1, -52), UDim2.fromOffset(182, 38), function()
		local cb = pendingConfirmCallback
		hideConfirmDialog()
		if cb then cb() end
	end)
	yesBtn.ZIndex = 42
	confirmYesBtn = yesBtn
end

local function computeTabSignature(tab: MenuTab, state: { [string]: any }): string
	local prof = if typeof(state.Profile) == "table" then state.Profile else {}
	local base = string.format(
		"%s|%d|%d|%d|%d",
		tab,
		tonumber(prof.Coins) or 0,
		tonumber(prof.Level) or 1,
		tonumber(prof.Reputation) or 0,
		tonumber(prof.RestaurantLevel) or 1
	)
	if tab == "Warehouses" then
		local wh = if typeof(state.Warehouse) == "table" then state.Warehouse else {}
		local lv = if typeof(wh.Levels) == "table" then wh.Levels else {}
		local tot = if typeof(wh.CategoryTotals) == "table" then wh.CategoryTotals else {}
		return string.format(
			"%s|W:%d,%d,%d,%d|%d,%d,%d,%d",
			base,
			tonumber(lv.Fish) or 0, tonumber(lv.Vegetable) or 0, tonumber(lv.Fruit) or 0, tonumber(lv.Meat) or 0,
			tonumber(tot.Fish) or 0, tonumber(tot.Vegetable) or 0, tonumber(tot.Fruit) or 0, tonumber(tot.Meat) or 0
		)
	elseif tab == "Kitchen" then
		local k = if typeof(state.Kitchen) == "table" then state.Kitchen else {}
		local w = if typeof(state.WaitingCustomer) == "table" then state.WaitingCustomer else {}
		local wh = if typeof(state.Warehouse) == "table" then state.Warehouse else {}
		local lv = if typeof(wh.Levels) == "table" then wh.Levels else {}
		local tot = if typeof(wh.CategoryTotals) == "table" then wh.CategoryTotals else {}
		local cr = if typeof(state.CityCraving) == "table" then tostring(state.CityCraving.RecipeId or "") else ""
		local rc = if typeof(state.Receipts) == "table" then #state.Receipts else 0
		return string.format(
			"%s|K:%s|%s|%s|%s|%d|%s|%s|%s|%s|%d|%d,%d,%d,%d|WL:%d,%d,%d,%d",
			base,
			tostring(k.IsCooking == true), tostring(k.IsCooking2 == true),
			tostring(k.Boosted1 == true), tostring(k.Boosted2 == true),
			tonumber(k.ReadyTotal) or 0,
			tostring(w.CustomerName or ""), tostring(w.IsBeingCooked == true),
			tostring(state.MenuPricing or ""), cr, rc,
			tonumber(tot.Fish) or 0, tonumber(tot.Vegetable) or 0, tonumber(tot.Fruit) or 0, tonumber(tot.Meat) or 0,
			tonumber(lv.Fish) or 0, tonumber(lv.Vegetable) or 0, tonumber(lv.Fruit) or 0, tonumber(lv.Meat) or 0
		)
	elseif tab == "Shop" then
		local op = if typeof(state.OwnedPasses) == "table" then state.OwnedPasses else {}
		local cnt = 0
		for _, v in pairs(op) do if v then cnt += 1 end end
		return string.format("%s|S:%d|%s", base, cnt, tostring(state.OwnsMotorbike == true))
	elseif tab == "Market" then
		local bm = if typeof(state.BlackMarket) == "table" then state.BlackMarket else {}
		local ow = if typeof(bm.OwnedWeapons) == "table" then bm.OwnedWeapons else {}
		local wCnt = 0
		for _, v in pairs(ow) do if v then wCnt += 1 end end
		local ammoInv = if typeof(bm.AmmoInventory) == "table" then bm.AmmoInventory else {}
		local ammoSum = 0
		for _, v in pairs(ammoInv) do if typeof(v) == "number" then ammoSum += v end end
		local bg = if typeof(state.Bodyguards) == "table" then state.Bodyguards else {}
		local sqList = if typeof(bg.ActiveSquad) == "table" then bg.ActiveSquad else {}
		local og = if typeof(bg.OwnedGear) == "table" then bg.OwnedGear else {}
		local gCnt = 0
		for _, v in pairs(og) do if v then gCnt += 1 end end
		return string.format(
			"%s|MK:%s|%s|%s|%d|%d|%d|%d|%d|%s|%s",
			base,
			currentMarketSubTab,
			currentMarketWeaponFilter,
			currentGuardGearFilter,
			selectedGuardSlot,
			wCnt,
			tonumber(bm.Armor) or 0,
			ammoSum,
			tonumber(bm.SmokeGrenades) or 0,
			table.concat(sqList, ","),
			tostring(gCnt) .. "|" .. tostring(bg.Stance or "")
		)
	elseif tab == "BlackMarket" then
		local bm = if typeof(state.BlackMarket) == "table" then state.BlackMarket else {}
		local ow = if typeof(bm.OwnedWeapons) == "table" then bm.OwnedWeapons else {}
		local wCnt = 0
		for _, v in pairs(ow) do if v then wCnt += 1 end end
		local mc = if typeof(state.MercenaryMafia) == "table" then state.MercenaryMafia else {}
		local bg = if typeof(state.Bodyguards) == "table" then state.Bodyguards else {}
		local sqList = if typeof(bg.ActiveSquad) == "table" then bg.ActiveSquad else {}
		local og = if typeof(bg.OwnedGear) == "table" then bg.OwnedGear else {}
		local gCnt = 0
		for _, v in pairs(og) do if v then gCnt += 1 end end
		local deal = if typeof(bm.SmugglerDeal) == "table" then bm.SmugglerDeal else nil
		local dealSig = if deal
			then string.format("%s:%d:%d", tostring(deal.DealId or ""), tonumber(deal.DiscountPct) or 0, math.floor((tonumber(deal.TimeRemaining) or 0) / 10))
			else ""
		return string.format(
			"%s|BM:%s|%s|%s|%s|%d|%d|%d|%d|%s|%s|%s|%s|%s|%s",
			base,
			currentBMSubTab,
			currentWeaponFilter,
			currentGuardView,
			currentGuardGearFilter,
			selectedGuardSlot,
			wCnt,
			tonumber(bm.Flashbangs) or 0,
			tonumber(bm.C4Charges) or 0,
			tostring(bm.HasShadowDash == true),
			table.concat(sqList, ",") .. ":" .. tostring(gCnt),
			tostring(mc.Active == true),
			tostring(mc.MercType or ""),
			tostring(mc.TargetRestaurantId or ""),
			dealSig
		)
	else
		local bg = if typeof(state.Bodyguards) == "table" then state.Bodyguards else {}
		local sqList = if typeof(bg.ActiveSquad) == "table" then bg.ActiveSquad else {}
		local sqStr = table.concat(sqList, ",")
		local unlMap = if typeof(bg.UnlockedClasses) == "table" then bg.UnlockedClasses else {}
		local unlCnt = 0
		for _, v in pairs(unlMap) do
			if v then unlCnt += 1 end
		end
		local hc = if typeof(state.HiredCompanions) == "table" then state.HiredCompanions else {}
		local hcList = if typeof(hc.List) == "table" then hc.List else {}
		local hcParts: { string } = {}
		for _, item in ipairs(hcList) do
			if typeof(item) == "table" then
				-- Bucket countdown by 5s in menu sig so menu updates smoothly without constant layout jitter
				table.insert(
					hcParts,
					string.format(
						"%s:%s:%d:%d",
						tostring(item.CompanionType),
						tostring(item.State),
						math.floor((tonumber(item.TimeRemaining) or 0) / 5),
						tonumber(item.RespawnRemaining) or 0
					)
				)
			end
		end
		local ogMap = if typeof(bg.OwnedGear) == "table" then bg.OwnedGear else {}
		local ogCnt = 0
		for _, v in pairs(ogMap) do
			if v then ogCnt += 1 end
		end
		local hcSig = table.concat(hcParts, ";")
		return string.format(
			"%s|U:%s|%s|%s|%d|%d|%d|%d|%d|%s|%s|%s|%d|%d|%s|%d|%s|%d",
			base,
			currentEmpireSubTab,
			currentSecuritySubView,
			currentGuardGearFilter,
			tonumber(prof.DefenseLevel) or 1,
			tonumber(prof.CrewCount) or 0,
			tonumber(state.WaiterCount) or 0,
			tonumber(state.CourierCount) or 0,
			ogCnt,
			tostring(prof.HasDualStove == true),
			tostring(prof.HasVIPBooths == true),
			sqStr,
			unlCnt,
			#sqList,
			tostring(bg.Stance or ""),
			selectedGuardSlot,
			hcSig,
			tonumber(prof.TotalDishesServed) or 0
		)
	end
end

function EmpireMenuController.Close(): ()
	hideConfirmDialog()
	lastRenderedTabSig = ""
	if backdropFrame then
		backdropFrame.Visible = false
	end
	if modalFrame then
		modalFrame.Visible = false
	end
end

function EmpireMenuController.ToggleTab(tab: MenuTab): ()
	if not modalFrame then return end
	hideConfirmDialog()
	if modalFrame.Visible and currentTab == tab then
		EmpireMenuController.Close()
		return
	end
	if currentTab ~= tab and scrollFrame then
		scrollFrame.CanvasPosition = Vector2.new(0, 0)
	end
	currentTab = tab
	lastRenderedTabSig = ""
	if backdropFrame then
		backdropFrame.Visible = true
	end
	local wasHidden = not modalFrame.Visible
	modalFrame.Visible = true
	if wasHidden then
		modalFrame.Size = UDim2.fromScale(0.83, 0.77)
		TweenService:Create(modalFrame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(0.88, 0.82),
		}):Play()
	end
	if not latestState and dispatchAction then
		task.spawn(dispatchAction, "GetState", nil)
	end
	render()
	if latestState then
		lastRenderedTabSig = computeTabSignature(currentTab, latestState)
	end
end

function EmpireMenuController.Update(state: { [string]: any }): ()
	latestState = state
	if not modalFrame or not modalFrame.Visible then
		return
	end
	-- Always refresh sidebar balance immediately without destroying buttons/Viewports!
	local prof = if typeof(state.Profile) == "table" then state.Profile else {}
	if headerGoldValLbl then
		headerGoldValLbl.Text = formatCommaInt(tonumber(prof.Coins) or 0)
	end
	if headerRankValLbl then
		headerRankValLbl.Text = string.format("LV.%d  |  %s REP", tonumber(prof.Level) or 1, formatCommaInt(tonumber(prof.Reputation) or 0))
	end

	-- Only rebuild ScrollingFrame when current tab's relevant state actually changed (prevents killing buttons mid-click or flickering Viewports!)
	local sig = computeTabSignature(currentTab, state)
	if sig == lastRenderedTabSig then
		return
	end
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		if not deferredRenderQueued then
			deferredRenderQueued = true
			task.delay(0.18, function()
				deferredRenderQueued = false
				if latestState and modalFrame and modalFrame.Visible then
					lastRenderedTabSig = computeTabSignature(currentTab, latestState)
					render()
				end
			end)
		end
		return
	end
	lastRenderedTabSig = sig
	render()
end

return EmpireMenuController
