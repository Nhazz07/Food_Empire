--!strict

-- ScoreboardController:
-- Replaces Roblox's default top-right PlayerList with a responsive, dark-gold
-- 8-Player Co-op Base Scoreboard grouped by Base (North, South, East, West — 2 slots each).
-- Displays Player Name, Avatar, Online / Inactive / Disconnected status, live Ping (ms),
-- compact Level / Rep / Coins, local player highlight, and total X/8 player count.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)

local ScoreboardController = {}

local FONT_TITLE = Enum.Font.GothamBlack
local FONT_BODY = Enum.Font.GothamBold
local FONT_REG = Enum.Font.Gotham

-- Luxury "Noir Syndicate Bistro" Palette (matches HUDController)
local C_OBS = Color3.fromRGB(15, 18, 25)
local C_OBS_DEEP = Color3.fromRGB(10, 12, 18)
local C_INNER = Color3.fromRGB(22, 26, 36)
local C_BORDER = Color3.fromRGB(54, 60, 74)
local C_GOLD = Color3.fromRGB(212, 178, 102)
local C_GOLD_DIM = Color3.fromRGB(122, 102, 58)
local C_BONE = Color3.fromRGB(240, 238, 232)
local C_ASH = Color3.fromRGB(154, 162, 178)
local C_MUTED = Color3.fromRGB(98, 106, 122)

-- Status & Ping Semantic Colors
local C_ONLINE = Color3.fromRGB(68, 206, 126)
local C_ONLINE_BG = Color3.fromRGB(20, 48, 34)
local C_INACTIVE = Color3.fromRGB(242, 182, 58)
local C_INACTIVE_BG = Color3.fromRGB(52, 40, 18)
local C_DISCONN = Color3.fromRGB(228, 78, 88)
local C_DISCONN_BG = Color3.fromRGB(48, 20, 26)
local C_LOCAL_BG = Color3.fromRGB(36, 31, 20)
local C_PARTNER_BG = Color3.fromRGB(20, 34, 28)
local C_GOLD_TEXT = Color3.fromRGB(252, 224, 132)
local C_LEVEL_TEXT = Color3.fromRGB(190, 162, 248)
local C_REP_TEXT = Color3.fromRGB(238, 132, 142)

local SLOT_ORDER: { string } = { "North", "South", "East", "West" }
local SLOT_CODES: { [string]: string } = {
	North = "N",
	South = "S",
	East = "E",
	West = "W",
}
local SLOT_DISPLAY: { [string]: string } = {
	North = "NORTH BASE",
	South = "SOUTH BASE",
	East = "EAST BASE",
	West = "WEST BASE",
}

local CLIENT_INACTIVE_AFTER_SEC = 45
local CLIENT_UNFOCUSED_INACTIVE_SEC = 15

type PlayerRowWidgets = {
	Root: Frame,
	Stroke: UIStroke,
	AvatarWrap: Frame,
	AvatarImg: ImageLabel,
	AvatarFallback: TextLabel,
	NameRow: Frame,
	NameLbl: TextLabel,
	SelfTag: TextLabel,
	PartnerTag: TextLabel,
	SubLbl: TextLabel,
	StatusPill: Frame,
	StatusDot: Frame,
	StatusLbl: TextLabel,
	StatsFrame: Frame,
	LvLbl: TextLabel,
	RepLbl: TextLabel,
	CoinsLbl: TextLabel,
	PingFrame: Frame,
	PingBar1: Frame,
	PingBar2: Frame,
	PingBar3: Frame,
	PingLbl: TextLabel,
	EmptyLbl: TextLabel,
	CurrentAvatarUserId: number,
}

type BaseCardWidgets = {
	Root: Frame,
	Stroke: UIStroke,
	AccentTop: Frame,
	HeaderTint: Frame,
	CodeBadge: TextLabel,
	TitleLbl: TextLabel,
	YourBaseTag: TextLabel,
	HQLbl: TextLabel,
	CountPill: TextLabel,
	Rows: { PlayerRowWidgets },
}

local initialized = false
local isOpen = false
local onClickSfx: (() -> ())? = nil
local parentGuiRef: ScreenGui? = nil
local overlayGui: ScreenGui? = nil
local overlayScale: UIScale? = nil

local toggleBtn: TextButton? = nil
local toggleStroke: UIStroke? = nil
local toggleCountLbl: TextLabel? = nil
local toggleSubLbl: TextLabel? = nil
local toggleDot: Frame? = nil

local backdrop: TextButton? = nil
local cardFrame: Frame? = nil
local cardScale: UIScale? = nil
local headerCountLbl: TextLabel? = nil
local headerSubCountLbl: TextLabel? = nil
local gridScroll: ScrollingFrame? = nil
local gridLayout: UIGridLayout? = nil
local unassignedBar: Frame? = nil
local unassignedLbl: TextLabel? = nil

local baseCards: { [string]: BaseCardWidgets } = {}
local latestSnapshot: { [string]: any }? = nil
local avatarCache: { [number]: string } = {}
local avatarPending: { [number]: boolean } = {}

local lastInputAt = os.clock()
local isWindowFocused = true
local lastReportedActive = true
local lastReportedFocus = true
local activityRemoteRef: RemoteEvent? = nil

local function makeCorner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function makeStroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function addGradient(parent: Instance, topCol: Color3, botCol: Color3): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, topCol),
		ColorSequenceKeypoint.new(1, botCol),
	})
	g.Parent = parent
	return g
end

local function formatCompactCoins(n: number): string
	local v = math.max(0, math.floor(n))
	if v >= 1_000_000 then
		return string.format("%.1fM", v / 1_000_000)
	elseif v >= 10_000 then
		return string.format("%.1fK", v / 1_000)
	elseif v >= 1_000 then
		return string.format("%.1fK", v / 1_000)
	end
	return tostring(v)
end

local function getInitials(displayName: string): string
	local trimmed = string.gsub(displayName, "^%s*(.-)%s*$", "%1")
	if #trimmed == 0 then
		return "?"
	end
	return string.upper(string.sub(trimmed, 1, 2))
end

local function loadAvatarAsync(userId: number, img: ImageLabel, fallback: TextLabel, rowRef: PlayerRowWidgets): ()
	if userId <= 0 then
		img.Visible = false
		fallback.Visible = true
		return
	end
	local cached = avatarCache[userId]
	if cached then
		if cached ~= "" then
			img.Image = cached
			img.Visible = true
			fallback.Visible = false
		else
			img.Visible = false
			fallback.Visible = true
		end
		return
	end

	img.Visible = false
	fallback.Visible = true
	if avatarPending[userId] then
		return
	end
	avatarPending[userId] = true

	task.spawn(function()
		local ok, content, isReady = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		avatarPending[userId] = nil
		if ok and isReady and typeof(content) == "string" and content ~= "" then
			avatarCache[userId] = content
			if rowRef.CurrentAvatarUserId == userId and img.Parent then
				img.Image = content
				img.Visible = true
				fallback.Visible = false
			end
		else
			avatarCache[userId] = ""
		end
	end)
end

local function disableDefaultPlayerList(): ()
	task.spawn(function()
		for _ = 1, 12 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end)
			if ok then
				-- Keep asserting a couple times during early join so CoreGui never re-shows it
				task.wait(0.8)
				pcall(function()
					StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
				end)
				return
			end
			task.wait(0.4)
		end
	end)
end

local function createPlayerRow(parent: Instance, layoutOrder: number): PlayerRowWidgets
	local row = Instance.new("Frame")
	row.Name = "PlayerRow_" .. tostring(layoutOrder)
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, 48)
	row.BackgroundColor3 = C_OBS_DEEP
	row.BackgroundTransparency = 0.08
	row.BorderSizePixel = 0
	row.Parent = parent
	makeCorner(row, 8)
	local stroke = makeStroke(row, C_BORDER, 1, 0.35)

	-- Avatar circle (32x32)
	local avatarWrap = Instance.new("Frame")
	avatarWrap.Name = "AvatarWrap"
	avatarWrap.Position = UDim2.new(0, 8, 0.5, -16)
	avatarWrap.Size = UDim2.fromOffset(32, 32)
	avatarWrap.BackgroundColor3 = C_INNER
	avatarWrap.BorderSizePixel = 0
	avatarWrap.ClipsDescendants = true
	avatarWrap.Parent = row
	makeCorner(avatarWrap, 16)
	makeStroke(avatarWrap, C_BORDER, 1, 0.25)

	local avatarImg = Instance.new("ImageLabel")
	avatarImg.Name = "AvatarImg"
	avatarImg.Size = UDim2.fromScale(1, 1)
	avatarImg.BackgroundTransparency = 1
	avatarImg.ScaleType = Enum.ScaleType.Crop
	avatarImg.Visible = false
	avatarImg.Parent = avatarWrap
	makeCorner(avatarImg, 16)

	local avatarFallback = Instance.new("TextLabel")
	avatarFallback.Name = "AvatarFallback"
	avatarFallback.Size = UDim2.fromScale(1, 1)
	avatarFallback.BackgroundTransparency = 1
	avatarFallback.Font = FONT_TITLE
	avatarFallback.Text = "+"
	avatarFallback.TextSize = 13
	avatarFallback.TextColor3 = C_MUTED
	avatarFallback.Parent = avatarWrap

	-- Empty slot text (shown when no player & no disconnected ghost occupies slot)
	local emptyLbl = Instance.new("TextLabel")
	emptyLbl.Name = "EmptySlotLabel"
	emptyLbl.Position = UDim2.new(0, 48, 0, 0)
	emptyLbl.Size = UDim2.new(1, -58, 1, 0)
	emptyLbl.BackgroundTransparency = 1
	emptyLbl.Font = FONT_BODY
	emptyLbl.Text = "OPEN CO-OP SLOT  ·  Waiting for teammate"
	emptyLbl.TextSize = 11
	emptyLbl.TextXAlignment = Enum.TextXAlignment.Left
	emptyLbl.TextColor3 = C_MUTED
	emptyLbl.Visible = true
	emptyLbl.Parent = row

	-- Name & Tags container (fluid fill between avatar [8..40] and right columns [W-232..W])
	local nameRow = Instance.new("Frame")
	nameRow.Name = "NameRow"
	nameRow.Position = UDim2.new(0, 48, 0, 5)
	nameRow.Size = UDim2.new(1, -286, 0, 19)
	nameRow.BackgroundTransparency = 1
	nameRow.ClipsDescendants = true
	nameRow.Visible = false
	nameRow.Parent = row

	local nameList = Instance.new("UIListLayout")
	nameList.FillDirection = Enum.FillDirection.Horizontal
	nameList.VerticalAlignment = Enum.VerticalAlignment.Center
	nameList.SortOrder = Enum.SortOrder.LayoutOrder
	nameList.Padding = UDim.new(0, 5)
	nameList.Parent = nameRow

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "DisplayName"
	nameLbl.LayoutOrder = 1
	nameLbl.AutomaticSize = Enum.AutomaticSize.X
	nameLbl.Size = UDim2.fromOffset(0, 18)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = FONT_TITLE
	nameLbl.Text = "Player"
	nameLbl.TextSize = 12
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextColor3 = C_BONE
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	nameLbl.Parent = nameRow

	local nameConstraint = Instance.new("UISizeConstraint")
	nameConstraint.MaxSize = Vector2.new(112, 20)
	nameConstraint.Parent = nameLbl

	local selfTag = Instance.new("TextLabel")
	selfTag.Name = "YouTag"
	selfTag.LayoutOrder = 2
	selfTag.Size = UDim2.fromOffset(30, 15)
	selfTag.BackgroundColor3 = C_GOLD
	selfTag.Font = FONT_TITLE
	selfTag.Text = "YOU"
	selfTag.TextSize = 8
	selfTag.TextColor3 = C_OBS_DEEP
	selfTag.Visible = false
	selfTag.Parent = nameRow
	makeCorner(selfTag, 4)

	local partnerTag = Instance.new("TextLabel")
	partnerTag.Name = "PartnerTag"
	partnerTag.LayoutOrder = 3
	partnerTag.Size = UDim2.fromOffset(46, 15)
	partnerTag.BackgroundColor3 = C_ONLINE_BG
	partnerTag.Font = FONT_TITLE
	partnerTag.Text = "PARTNER"
	partnerTag.TextSize = 8
	partnerTag.TextColor3 = C_ONLINE
	partnerTag.Visible = false
	partnerTag.Parent = nameRow
	makeCorner(partnerTag, 4)
	makeStroke(partnerTag, C_ONLINE, 1, 0.4)

	local subLbl = Instance.new("TextLabel")
	subLbl.Name = "SubText"
	subLbl.Position = UDim2.new(0, 48, 0, 26)
	subLbl.Size = UDim2.new(1, -286, 0, 16)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = FONT_REG
	subLbl.Text = "@username"
	subLbl.TextSize = 10
	subLbl.TextXAlignment = Enum.TextXAlignment.Left
	subLbl.TextColor3 = C_ASH
	subLbl.TextTruncate = Enum.TextTruncate.AtEnd
	subLbl.Visible = false
	subLbl.Parent = row

	-- Status Pill (right-anchored cleanly to left of StatsFrame: [W-232 .. W-144])
	local statusPill = Instance.new("Frame")
	statusPill.Name = "StatusPill"
	statusPill.AnchorPoint = Vector2.new(1, 0.5)
	statusPill.Position = UDim2.new(1, -144, 0.5, 0)
	statusPill.Size = UDim2.fromOffset(88, 22)
	statusPill.BackgroundColor3 = C_ONLINE_BG
	statusPill.BorderSizePixel = 0
	statusPill.Visible = false
	statusPill.Parent = row
	makeCorner(statusPill, 11)

	local statusDot = Instance.new("Frame")
	statusDot.Name = "Dot"
	statusDot.Position = UDim2.new(0, 7, 0.5, -3)
	statusDot.Size = UDim2.fromOffset(6, 6)
	statusDot.BackgroundColor3 = C_ONLINE
	statusDot.BorderSizePixel = 0
	statusDot.Parent = statusPill
	makeCorner(statusDot, 3)

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Name = "StatusText"
	statusLbl.Position = UDim2.new(0, 16, 0, 0)
	statusLbl.Size = UDim2.new(1, -20, 1, 0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Font = FONT_TITLE
	statusLbl.Text = "ONLINE"
	statusLbl.TextSize = 8
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.TextColor3 = C_ONLINE
	statusLbl.Parent = statusPill

	-- Compact Stats Block (Level / Rep / Coins: [W-138 .. W-58])
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "CompactStats"
	statsFrame.AnchorPoint = Vector2.new(1, 0.5)
	statsFrame.Position = UDim2.new(1, -58, 0.5, 0)
	statsFrame.Size = UDim2.fromOffset(80, 36)
	statsFrame.BackgroundTransparency = 1
	statsFrame.Visible = false
	statsFrame.Parent = row

	local lvLbl = Instance.new("TextLabel")
	lvLbl.Name = "LvLbl"
	lvLbl.Position = UDim2.fromOffset(0, 1)
	lvLbl.Size = UDim2.fromOffset(38, 16)
	lvLbl.BackgroundTransparency = 1
	lvLbl.Font = FONT_TITLE
	lvLbl.Text = "LV.1"
	lvLbl.TextSize = 10
	lvLbl.TextXAlignment = Enum.TextXAlignment.Right
	lvLbl.TextColor3 = C_LEVEL_TEXT
	lvLbl.Parent = statsFrame

	local repLbl = Instance.new("TextLabel")
	repLbl.Name = "RepLbl"
	repLbl.Position = UDim2.fromOffset(40, 1)
	repLbl.Size = UDim2.fromOffset(40, 16)
	repLbl.BackgroundTransparency = 1
	repLbl.Font = FONT_BODY
	repLbl.Text = "0R"
	repLbl.TextSize = 10
	repLbl.TextXAlignment = Enum.TextXAlignment.Right
	repLbl.TextColor3 = C_REP_TEXT
	repLbl.Parent = statsFrame

	local coinsLbl = Instance.new("TextLabel")
	coinsLbl.Name = "CoinsLbl"
	coinsLbl.Position = UDim2.fromOffset(0, 19)
	coinsLbl.Size = UDim2.new(1, 0, 0, 16)
	coinsLbl.BackgroundTransparency = 1
	coinsLbl.Font = FONT_TITLE
	coinsLbl.Text = "0G"
	coinsLbl.TextSize = 11
	coinsLbl.TextXAlignment = Enum.TextXAlignment.Right
	coinsLbl.TextColor3 = C_GOLD_TEXT
	coinsLbl.Parent = statsFrame

	-- Ping & Signal Bars Block (far right: [W-52 .. W-8])
	local pingFrame = Instance.new("Frame")
	pingFrame.Name = "PingBlock"
	pingFrame.AnchorPoint = Vector2.new(1, 0.5)
	pingFrame.Position = UDim2.new(1, -8, 0.5, 0)
	pingFrame.Size = UDim2.fromOffset(44, 34)
	pingFrame.BackgroundTransparency = 1
	pingFrame.Visible = false
	pingFrame.Parent = row

	local barsWrap = Instance.new("Frame")
	barsWrap.AnchorPoint = Vector2.new(1, 0)
	barsWrap.Position = UDim2.new(1, 0, 0, 3)
	barsWrap.Size = UDim2.fromOffset(18, 12)
	barsWrap.BackgroundTransparency = 1
	barsWrap.Parent = pingFrame

	local function makeSignalBar(x: number, h: number): Frame
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0, 1)
		b.Position = UDim2.new(0, x, 1, 0)
		b.Size = UDim2.fromOffset(4, h)
		b.BackgroundColor3 = C_ONLINE
		b.BorderSizePixel = 0
		b.Parent = barsWrap
		makeCorner(b, 1)
		return b
	end

	local b1 = makeSignalBar(0, 5)
	local b2 = makeSignalBar(6, 8)
	local b3 = makeSignalBar(12, 12)

	local pingLbl = Instance.new("TextLabel")
	pingLbl.Name = "PingText"
	pingLbl.Position = UDim2.new(0, 0, 0, 17)
	pingLbl.Size = UDim2.new(1, 0, 0, 15)
	pingLbl.BackgroundTransparency = 1
	pingLbl.Font = FONT_TITLE
	pingLbl.Text = "--"
	pingLbl.TextSize = 10
	pingLbl.TextXAlignment = Enum.TextXAlignment.Right
	pingLbl.TextColor3 = C_ASH
	pingLbl.Parent = pingFrame

	return {
		Root = row,
		Stroke = stroke,
		AvatarWrap = avatarWrap,
		AvatarImg = avatarImg,
		AvatarFallback = avatarFallback,
		NameRow = nameRow,
		NameLbl = nameLbl,
		SelfTag = selfTag,
		PartnerTag = partnerTag,
		SubLbl = subLbl,
		StatusPill = statusPill,
		StatusDot = statusDot,
		StatusLbl = statusLbl,
		StatsFrame = statsFrame,
		LvLbl = lvLbl,
		RepLbl = repLbl,
		CoinsLbl = coinsLbl,
		PingFrame = pingFrame,
		PingBar1 = b1,
		PingBar2 = b2,
		PingBar3 = b3,
		PingLbl = pingLbl,
		EmptyLbl = emptyLbl,
		CurrentAvatarUserId = 0,
	}
end

local function createBaseCard(parent: Instance, slot: string, layoutOrder: number): BaseCardWidgets
	local teamCol = SectorConfig.FactionColors[slot] or C_GOLD

	local card = Instance.new("Frame")
	card.Name = "BaseCard_" .. slot
	card.LayoutOrder = layoutOrder
	card.BackgroundColor3 = C_OBS
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = parent
	makeCorner(card, 10)
	local stroke = makeStroke(card, teamCol:Lerp(C_BORDER, 0.55), 1.3, 0.15)

	-- Colored Top Accent Bar identifying Base team color
	local accentTop = Instance.new("Frame")
	accentTop.Name = "TeamAccentTop"
	accentTop.Size = UDim2.new(1, 0, 0, 3)
	accentTop.BackgroundColor3 = teamCol
	accentTop.BorderSizePixel = 0
	accentTop.Parent = card

	-- Base Header Strip
	local header = Instance.new("Frame")
	header.Name = "BaseHeader"
	header.Position = UDim2.fromOffset(0, 3)
	header.Size = UDim2.new(1, 0, 0, 34)
	header.BackgroundColor3 = teamCol:Lerp(C_OBS_DEEP, 0.84)
	header.BorderSizePixel = 0
	header.Parent = card

	local codeBadge = Instance.new("TextLabel")
	codeBadge.Name = "CodeBadge"
	codeBadge.Position = UDim2.new(0, 10, 0.5, -11)
	codeBadge.Size = UDim2.fromOffset(22, 22)
	codeBadge.BackgroundColor3 = teamCol
	codeBadge.Font = FONT_TITLE
	codeBadge.Text = SLOT_CODES[slot] or string.sub(slot, 1, 1)
	codeBadge.TextSize = 11
	codeBadge.TextColor3 = if slot == "South" then C_OBS_DEEP else Color3.new(1, 1, 1)
	codeBadge.Parent = header
	makeCorner(codeBadge, 5)

	local titleWrap = Instance.new("Frame")
	titleWrap.Position = UDim2.new(0, 40, 0, 0)
	titleWrap.Size = UDim2.new(0.62, -40, 1, 0)
	titleWrap.BackgroundTransparency = 1
	titleWrap.Parent = header

	local titleList = Instance.new("UIListLayout")
	titleList.FillDirection = Enum.FillDirection.Horizontal
	titleList.VerticalAlignment = Enum.VerticalAlignment.Center
	titleList.SortOrder = Enum.SortOrder.LayoutOrder
	titleList.Padding = UDim.new(0, 7)
	titleList.Parent = titleWrap

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name = "BaseTitle"
	titleLbl.LayoutOrder = 1
	titleLbl.AutomaticSize = Enum.AutomaticSize.X
	titleLbl.Size = UDim2.fromOffset(0, 20)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = FONT_TITLE
	titleLbl.Text = SLOT_DISPLAY[slot] or (string.upper(slot) .. " BASE")
	titleLbl.TextSize = 13
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.TextColor3 = C_BONE
	titleLbl.Parent = titleWrap

	local yourBaseTag = Instance.new("TextLabel")
	yourBaseTag.Name = "YourBaseTag"
	yourBaseTag.LayoutOrder = 2
	yourBaseTag.Size = UDim2.fromOffset(64, 16)
	yourBaseTag.BackgroundColor3 = C_LOCAL_BG
	yourBaseTag.Font = FONT_TITLE
	yourBaseTag.Text = "YOUR BASE"
	yourBaseTag.TextSize = 8
	yourBaseTag.TextColor3 = C_GOLD
	yourBaseTag.Visible = false
	yourBaseTag.Parent = titleWrap
	makeCorner(yourBaseTag, 4)
	makeStroke(yourBaseTag, C_GOLD, 1, 0.2)

	local rightWrap = Instance.new("Frame")
	rightWrap.AnchorPoint = Vector2.new(1, 0.5)
	rightWrap.Position = UDim2.new(1, -10, 0.5, 0)
	rightWrap.Size = UDim2.fromOffset(118, 22)
	rightWrap.BackgroundTransparency = 1
	rightWrap.Parent = header

	local rightList = Instance.new("UIListLayout")
	rightList.FillDirection = Enum.FillDirection.Horizontal
	rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rightList.VerticalAlignment = Enum.VerticalAlignment.Center
	rightList.SortOrder = Enum.SortOrder.LayoutOrder
	rightList.Padding = UDim.new(0, 6)
	rightList.Parent = rightWrap

	local hqLbl = Instance.new("TextLabel")
	hqLbl.Name = "HQBadge"
	hqLbl.LayoutOrder = 1
	hqLbl.Size = UDim2.fromOffset(54, 18)
	hqLbl.BackgroundColor3 = C_OBS_DEEP
	hqLbl.BackgroundTransparency = 0.25
	hqLbl.Font = FONT_BODY
	hqLbl.Text = "HQ LV.1"
	hqLbl.TextSize = 9
	hqLbl.TextColor3 = C_ASH
	hqLbl.Parent = rightWrap
	makeCorner(hqLbl, 4)

	local countPill = Instance.new("TextLabel")
	countPill.Name = "SlotCount"
	countPill.LayoutOrder = 2
	countPill.Size = UDim2.fromOffset(38, 20)
	countPill.BackgroundColor3 = C_INNER
	countPill.Font = FONT_TITLE
	countPill.Text = "0/2"
	countPill.TextSize = 10
	countPill.TextColor3 = C_ASH
	countPill.Parent = rightWrap
	makeCorner(countPill, 5)
	makeStroke(countPill, teamCol:Lerp(C_BORDER, 0.4), 1, 0.2)

	-- Column Subheader
	local colBar = Instance.new("Frame")
	colBar.Name = "ColumnSubheader"
	colBar.Position = UDim2.fromOffset(10, 40)
	colBar.Size = UDim2.new(1, -20, 0, 14)
	colBar.BackgroundTransparency = 1
	colBar.Parent = card

	local function addColTitle(txt: string, pos: UDim2, sz: UDim2, align: Enum.TextXAlignment): ()
		local l = Instance.new("TextLabel")
		l.Position = pos
		l.Size = sz
		l.BackgroundTransparency = 1
		l.Font = FONT_BODY
		l.Text = txt
		l.TextSize = 8
		l.TextXAlignment = align
		l.TextColor3 = C_MUTED
		l.Parent = colBar
	end

	addColTitle("PLAYER", UDim2.fromOffset(48, 0), UDim2.new(1, -286, 1, 0), Enum.TextXAlignment.Left)
	addColTitle("STATUS", UDim2.new(1, -232, 0, 0), UDim2.fromOffset(88, 14), Enum.TextXAlignment.Left)
	addColTitle("STATS", UDim2.new(1, -138, 0, 0), UDim2.fromOffset(80, 14), Enum.TextXAlignment.Right)
	addColTitle("PING", UDim2.new(1, -52, 0, 0), UDim2.fromOffset(44, 14), Enum.TextXAlignment.Right)

	-- 2 Teammate Rows Container
	local rowsWrap = Instance.new("Frame")
	rowsWrap.Name = "RowsContainer"
	rowsWrap.Position = UDim2.fromOffset(10, 56)
	rowsWrap.Size = UDim2.new(1, -20, 1, -64)
	rowsWrap.BackgroundTransparency = 1
	rowsWrap.Parent = card

	local rowsList = Instance.new("UIListLayout")
	rowsList.FillDirection = Enum.FillDirection.Vertical
	rowsList.SortOrder = Enum.SortOrder.LayoutOrder
	rowsList.Padding = UDim.new(0, 6)
	rowsList.Parent = rowsWrap

	local r1 = createPlayerRow(rowsWrap, 1)
	local r2 = createPlayerRow(rowsWrap, 2)

	return {
		Root = card,
		Stroke = stroke,
		AccentTop = accentTop,
		HeaderTint = header,
		CodeBadge = codeBadge,
		TitleLbl = titleLbl,
		YourBaseTag = yourBaseTag,
		HQLbl = hqLbl,
		CountPill = countPill,
		Rows = { r1, r2 },
	}
end

local function updateResponsiveLayout(): ()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local vp = cam.ViewportSize
	if vp.X <= 1 or vp.Y <= 1 then
		return
	end

	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local scaleAttr = if playerGui then playerGui:GetAttribute("FoodEmpireHUDScale") else nil
	local hudScale = if typeof(scaleAttr) == "number" and scaleAttr > 0.1
		then scaleAttr
		else math.clamp(math.min(vp.X / 1360, vp.Y / 760), 0.62, 1.15)
	if overlayScale then
		overlayScale.Scale = hudScale
	end

	local logicalW = vp.X / hudScale
	local logicalH = vp.Y / hudScale

	-- Position HUD Roster Toggle Button with guaranteed zero overlap across all screen widths
	if toggleBtn and toggleSubLbl then
		if logicalW >= 1180 then
			toggleBtn.AnchorPoint = Vector2.new(0, 0)
			toggleBtn.Position = UDim2.new(0.5, 308, 0, 8)
			toggleBtn.Size = UDim2.fromOffset(112, 44)
			toggleSubLbl.Visible = true
		else
			toggleBtn.AnchorPoint = Vector2.new(0.5, 0)
			toggleBtn.Position = UDim2.new(0.5, 0, 0, 84)
			toggleBtn.Size = UDim2.fromOffset(132, 28)
			toggleSubLbl.Visible = false
		end
	end

	-- Responsive 2x2 Grid on Desktop / Landscape vs Clean 1-Column Scroll Stack on Narrow/Portrait
	if cardFrame and gridScroll and gridLayout then
		local padX = 14
		local padY = 10
		local headerTotalH = 86
		local footerReserve = if unassignedBar and unassignedBar.Visible then 34 else 12
		gridScroll.Size = UDim2.new(1, -32, 1, -(84 + footerReserve))

		if logicalW >= 960 then
			local cardW = math.clamp(math.floor(logicalW - 76), 880, 980)
			local cellW = math.floor((cardW - 32 - padX) / 2)
			local cellH = 170
			local contentH = cellH * 2 + padY + 4
			local cardH = math.min(math.floor(logicalH - 40), headerTotalH + contentH + footerReserve)

			cardFrame.Size = UDim2.fromOffset(cardW, cardH)
			gridLayout.CellPadding = UDim2.fromOffset(padX, padY)
			gridLayout.CellSize = UDim2.fromOffset(cellW, cellH)
			gridScroll.CanvasSize = UDim2.fromOffset(0, contentH)
		else
			local cardW = math.clamp(math.floor(logicalW - 24), 420, 620)
			local cellW = cardW - 34
			local cellH = 170
			local contentH = cellH * 4 + padY * 3 + 6
			local cardH = math.clamp(math.floor(logicalH - 44), 320, 620)

			cardFrame.Size = UDim2.fromOffset(cardW, cardH)
			gridLayout.CellPadding = UDim2.fromOffset(0, padY)
			gridLayout.CellSize = UDim2.fromOffset(cellW, cellH)
			gridScroll.CanvasSize = UDim2.fromOffset(0, contentH)
		end
	end
end

local function stylePingWidgets(row: PlayerRowWidgets, pingMs: number?, status: string): ()
	if status == "Disconnected" or typeof(pingMs) ~= "number" then
		row.PingLbl.Text = "--"
		row.PingLbl.TextColor3 = C_MUTED
		row.PingBar1.BackgroundColor3 = C_MUTED
		row.PingBar2.BackgroundColor3 = C_MUTED
		row.PingBar3.BackgroundColor3 = C_MUTED
		row.PingBar1.BackgroundTransparency = 0.65
		row.PingBar2.BackgroundTransparency = 0.65
		row.PingBar3.BackgroundTransparency = 0.65
		return
	end

	local col: Color3
	local barsLit = 3
	if pingMs < 80 then
		col = C_ONLINE
		barsLit = 3
	elseif pingMs <= 160 then
		col = C_INACTIVE
		barsLit = 2
	else
		col = C_DISCONN
		barsLit = 1
	end

	row.PingLbl.Text = if pingMs <= 0 then "<1 ms" else string.format("%d ms", pingMs)
	row.PingLbl.TextColor3 = col
	row.PingBar1.BackgroundColor3 = if barsLit >= 1 then col else C_MUTED
	row.PingBar2.BackgroundColor3 = if barsLit >= 2 then col else C_MUTED
	row.PingBar3.BackgroundColor3 = if barsLit >= 3 then col else C_MUTED
	row.PingBar1.BackgroundTransparency = if barsLit >= 1 then 0 else 0.72
	row.PingBar2.BackgroundTransparency = if barsLit >= 2 then 0 else 0.72
	row.PingBar3.BackgroundTransparency = if barsLit >= 3 then 0 else 0.72
end

local function renderRow(
	row: PlayerRowWidgets,
	entry: { [string]: any }?,
	teamCol: Color3,
	isLocalBase: boolean
): ()
	if not entry then
		row.CurrentAvatarUserId = 0
		row.Root.BackgroundColor3 = C_OBS_DEEP
		row.Root.BackgroundTransparency = 0.22
		row.Stroke.Color = C_BORDER
		row.Stroke.Thickness = 1
		row.Stroke.Transparency = 0.58

		row.AvatarImg.Visible = false
		row.AvatarFallback.Visible = true
		row.AvatarFallback.Text = "+"
		row.AvatarFallback.TextColor3 = C_MUTED
		row.AvatarWrap.BackgroundColor3 = C_OBS

		row.EmptyLbl.Visible = true
		row.NameRow.Visible = false
		row.SubLbl.Visible = false
		row.StatusPill.Visible = false
		row.StatsFrame.Visible = false
		row.PingFrame.Visible = false
		return
	end

	local localUid = Players.LocalPlayer.UserId
	local uid = tonumber(entry.UserId) or 0
	local isLocalPlayer = (uid == localUid)
	local status = tostring(entry.Status or "Online")
	local displayName = tostring(entry.DisplayName or "Player")
	local username = tostring(entry.Username or "")

	row.EmptyLbl.Visible = false
	row.NameRow.Visible = true
	row.SubLbl.Visible = true
	row.StatusPill.Visible = true
	row.StatsFrame.Visible = true
	row.PingFrame.Visible = true

	-- Avatar loading with cache
	row.AvatarFallback.Text = getInitials(displayName)
	row.AvatarFallback.TextColor3 = if status == "Disconnected" then C_MUTED else C_BONE
	row.AvatarImg.ImageTransparency = if status == "Disconnected"
		then 0.55
		elseif status == "Inactive" then 0.22
		else 0
	if row.CurrentAvatarUserId ~= uid then
		row.CurrentAvatarUserId = uid
		loadAvatarAsync(uid, row.AvatarImg, row.AvatarFallback, row)
	end

	-- Local player highlight vs Co-op partner vs Online / Inactive / Disconnected
	row.SelfTag.Visible = isLocalPlayer
	row.PartnerTag.Visible = (not isLocalPlayer) and isLocalBase and status ~= "Disconnected"

	if isLocalPlayer then
		row.Root.BackgroundColor3 = C_LOCAL_BG
		row.Root.BackgroundTransparency = 0.04
		row.Stroke.Color = C_GOLD
		row.Stroke.Thickness = 1.6
		row.Stroke.Transparency = 0.05
	elseif status == "Disconnected" then
		row.Root.BackgroundColor3 = Color3.fromRGB(24, 16, 20)
		row.Root.BackgroundTransparency = 0.14
		row.Stroke.Color = C_DISCONN
		row.Stroke.Thickness = 1
		row.Stroke.Transparency = 0.52
	elseif status == "Inactive" then
		row.Root.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
		row.Root.BackgroundTransparency = 0.1
		row.Stroke.Color = C_INACTIVE
		row.Stroke.Thickness = 1
		row.Stroke.Transparency = 0.52
	elseif isLocalBase then
		row.Root.BackgroundColor3 = C_PARTNER_BG
		row.Root.BackgroundTransparency = 0.06
		row.Stroke.Color = teamCol:Lerp(C_ONLINE, 0.35)
		row.Stroke.Thickness = 1.2
		row.Stroke.Transparency = 0.25
	else
		row.Root.BackgroundColor3 = C_INNER
		row.Root.BackgroundTransparency = 0.06
		row.Stroke.Color = C_BORDER
		row.Stroke.Thickness = 1
		row.Stroke.Transparency = 0.3
	end

	-- Name & subtext
	row.NameLbl.Text = displayName
	if status == "Disconnected" then
		row.NameLbl.TextColor3 = C_MUTED
		local ago = tonumber(entry.DisconnectedSecondsAgo) or 0
		row.SubLbl.Text = string.format("Disconnected · %ds ago", math.max(0, math.floor(ago)))
		row.SubLbl.TextColor3 = Color3.fromRGB(186, 102, 110)
	elseif status == "Inactive" then
		row.NameLbl.TextColor3 = Color3.fromRGB(198, 198, 204)
		row.SubLbl.Text = if username ~= "" then ("@" .. username .. " · AFK") else "Inactive"
		row.SubLbl.TextColor3 = Color3.fromRGB(196, 168, 108)
	else
		row.NameLbl.TextColor3 = if isLocalPlayer then C_GOLD_TEXT else C_BONE
		row.SubLbl.Text = if username ~= "" then ("@" .. username) else "Online"
		row.SubLbl.TextColor3 = C_ASH
	end

	-- Status Pill styling
	if status == "Disconnected" then
		row.StatusPill.BackgroundColor3 = C_DISCONN_BG
		row.StatusDot.BackgroundColor3 = C_DISCONN
		row.StatusLbl.Text = "DISCONNECTED"
		row.StatusLbl.TextSize = 7
		row.StatusLbl.TextColor3 = C_DISCONN
	elseif status == "Inactive" then
		row.StatusPill.BackgroundColor3 = C_INACTIVE_BG
		row.StatusDot.BackgroundColor3 = C_INACTIVE
		row.StatusLbl.Text = "INACTIVE"
		row.StatusLbl.TextSize = 8
		row.StatusLbl.TextColor3 = C_INACTIVE
	else
		row.StatusPill.BackgroundColor3 = C_ONLINE_BG
		row.StatusDot.BackgroundColor3 = C_ONLINE
		row.StatusLbl.Text = "ONLINE"
		row.StatusLbl.TextSize = 8
		row.StatusLbl.TextColor3 = C_ONLINE
	end

	-- Compact Progression Stats (LV / REP / Coins)
	local lv = tonumber(entry.Level) or 1
	local rep = tonumber(entry.Reputation) or 0
	local coins = tonumber(entry.Coins) or 0
	row.LvLbl.Text = "LV." .. tostring(lv)
	row.RepLbl.Text = tostring(rep) .. "R"
	row.CoinsLbl.Text = formatCompactCoins(coins) .. "G"
	local statsDim = (status == "Disconnected")
	row.LvLbl.TextColor3 = if statsDim then C_MUTED else C_LEVEL_TEXT
	row.RepLbl.TextColor3 = if statsDim then C_MUTED else C_REP_TEXT
	row.CoinsLbl.TextColor3 = if statsDim then C_MUTED else C_GOLD_TEXT

	-- Ping & Signal Bars
	stylePingWidgets(row, entry.PingMs, status)
end

local function applySnapshot(snap: { [string]: any }): ()
	latestSnapshot = snap

	local maxPlayers = tonumber(snap.MaxPlayers) or 8
	local onlineCount = tonumber(snap.OnlineCount) or #Players:GetPlayers()
	local inactiveCount = tonumber(snap.InactiveCount) or 0
	local disconnectedCount = tonumber(snap.DisconnectedCount) or 0

	-- Update HUD Toggle Button counter
	if toggleCountLbl then
		toggleCountLbl.Text = string.format("%d/%d", onlineCount, maxPlayers)
	end
	if toggleDot then
		toggleDot.BackgroundColor3 = if onlineCount > 0 then C_ONLINE else C_MUTED
	end

	-- Update Header counters
	if headerCountLbl then
		headerCountLbl.Text = string.format("%d / %d PLAYERS", onlineCount, maxPlayers)
	end
	if headerSubCountLbl then
		local parts: { string } = {}
		table.insert(parts, string.format("%d ONLINE", math.max(0, onlineCount - inactiveCount)))
		if inactiveCount > 0 then
			table.insert(parts, string.format("%d INACTIVE", inactiveCount))
		end
		if disconnectedCount > 0 then
			table.insert(parts, string.format("%d DISCONNECTED", disconnectedCount))
		end
		headerSubCountLbl.Text = table.concat(parts, "  ·  ")
	end

	local localSlotAttr = Players.LocalPlayer:GetAttribute("BaseSlot")
	local localSlot = if typeof(localSlotAttr) == "string" then localSlotAttr else nil

	local basesBySlot: { [string]: { [string]: any } } = {}
	if typeof(snap.Bases) == "table" then
		for _, b in ipairs(snap.Bases) do
			if typeof(b) == "table" and typeof(b.Slot) == "string" then
				basesBySlot[b.Slot] = b
			end
		end
	end

	for _, slot in ipairs(SLOT_ORDER) do
		local widgets = baseCards[slot]
		if widgets then
			local bData = basesBySlot[slot]
			local teamCol = SectorConfig.FactionColors[slot] or C_GOLD
			local isMine = (localSlot == slot)
			local memCount = if bData then (tonumber(bData.MemberCount) or 0) else 0
			local maxMem = if bData then (tonumber(bData.MaxMembers) or 2) else 2
			local hqLv = if bData then (tonumber(bData.HQLevel) or 1) else 1
			local entries = if bData and typeof(bData.Entries) == "table" then bData.Entries else {}

			widgets.YourBaseTag.Visible = isMine
			widgets.Stroke.Color = if isMine then teamCol else teamCol:Lerp(C_BORDER, 0.55)
			widgets.Stroke.Thickness = if isMine then 1.6 else 1.2
			widgets.HQLbl.Text = string.format("HQ LV.%d", hqLv)
			widgets.CountPill.Text = string.format("%d/%d", memCount, maxMem)
			widgets.CountPill.TextColor3 = if memCount >= maxMem
				then C_ONLINE
				elseif memCount > 0 then C_BONE
				else C_MUTED

			for rIdx = 1, 2 do
				renderRow(widgets.Rows[rIdx], entries[rIdx], teamCol, isMine)
			end
		end
	end

	-- Optional unassigned lobby bar if someone just joined and hasn't been assigned a base yet
	if unassignedBar and unassignedLbl then
		local unList = snap.Unassigned
		if typeof(unList) == "table" and #unList > 0 then
			local names: { string } = {}
			for _, u in ipairs(unList) do
				if typeof(u) == "table" then
					table.insert(names, tostring(u.DisplayName or "Player"))
				end
			end
			unassignedLbl.Text = "ASSIGNING BASE: " .. table.concat(names, ", ")
			unassignedBar.Visible = true
		else
			unassignedBar.Visible = false
		end
	end

	updateResponsiveLayout()
end

local function buildFallbackSnapshot(): { [string]: any }
	local bases: { { [string]: any } } = {}
	local slotMap: { [string]: { { [string]: any } } } = { North = {}, South = {}, East = {}, West = {} }
	local unassigned: { { [string]: any } } = {}
	local allPlayers = Players:GetPlayers()

	for _, plr in ipairs(allPlayers) do
		local entry = {
			UserId = plr.UserId,
			DisplayName = plr.DisplayName,
			Username = plr.Name,
			Status = "Online",
			PingMs = 0,
			Level = 1,
			Reputation = 0,
			Coins = 0,
		}
		local slotAttr = plr:GetAttribute("BaseSlot")
		if typeof(slotAttr) == "string" and slotMap[slotAttr] then
			table.insert(slotMap[slotAttr], entry)
		else
			table.insert(unassigned, entry)
		end
	end

	for _, slot in ipairs(SLOT_ORDER) do
		table.insert(bases, {
			Slot = slot,
			DisplayName = SLOT_DISPLAY[slot],
			MemberCount = #slotMap[slot],
			MaxMembers = 2,
			HQLevel = 1,
			Entries = slotMap[slot],
		})
	end

	return {
		MaxPlayers = 8,
		OnlineCount = #allPlayers,
		ActiveCount = #allPlayers,
		InactiveCount = 0,
		DisconnectedCount = 0,
		Bases = bases,
		Unassigned = unassigned,
	}
end

local function setOverlayOpen(openState: boolean): ()
	if isOpen == openState then
		return
	end
	isOpen = openState

	if toggleStroke then
		toggleStroke.Color = if isOpen then C_GOLD else C_GOLD_DIM
		toggleStroke.Thickness = if isOpen then 1.8 else 1.2
	end
	if toggleBtn then
		toggleBtn.BackgroundColor3 = if isOpen then Color3.fromRGB(30, 27, 20) else C_OBS
	end

	if not backdrop or not cardFrame or not cardScale then
		return
	end

	if isOpen then
		if not latestSnapshot then
			applySnapshot(buildFallbackSnapshot())
		else
			updateResponsiveLayout()
		end
		backdrop.Visible = true
		backdrop.BackgroundTransparency = 1
		cardScale.Scale = 0.94
		TweenService:Create(backdrop, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.42,
		}):Play()
		TweenService:Create(cardScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	else
		local bgRef = backdrop
		local scRef = cardScale
		local t1 = TweenService:Create(bgRef, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		})
		TweenService:Create(scRef, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.95,
		}):Play()
		t1:Play()
		t1.Completed:Connect(function()
			if not isOpen and bgRef.Parent then
				bgRef.Visible = false
			end
		end)
	end
end

function ScoreboardController.IsOpen(): boolean
	return isOpen
end

function ScoreboardController.Open(): ()
	setOverlayOpen(true)
end

function ScoreboardController.Close(): ()
	setOverlayOpen(false)
end

function ScoreboardController.Toggle(): ()
	if onClickSfx then
		onClickSfx()
	end
	setOverlayOpen(not isOpen)
end

local function startActivityTracker(): ()
	local function markInput(): ()
		lastInputAt = os.clock()
		if not lastReportedActive and activityRemoteRef then
			lastReportedActive = true
			activityRemoteRef:FireServer(true, isWindowFocused)
		end
	end

	UserInputService.InputBegan:Connect(function()
		markInput()
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local now = os.clock()
			if (now - lastInputAt) >= 2.0 then
				markInput()
			end
		end
	end)
	UserInputService.WindowFocused:Connect(function()
		isWindowFocused = true
		lastInputAt = os.clock()
		lastReportedFocus = true
		lastReportedActive = true
		if activityRemoteRef then
			activityRemoteRef:FireServer(true, true)
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		isWindowFocused = false
		lastReportedFocus = false
		if activityRemoteRef then
			activityRemoteRef:FireServer(lastReportedActive, false)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(3)
			local now = os.clock()
			local idle = now - lastInputAt
			local activeNow = if isWindowFocused
				then (idle < CLIENT_INACTIVE_AFTER_SEC)
				else (idle < CLIENT_UNFOCUSED_INACTIVE_SEC)
			if (activeNow ~= lastReportedActive or isWindowFocused ~= lastReportedFocus) and activityRemoteRef then
				lastReportedActive = activeNow
				lastReportedFocus = isWindowFocused
				activityRemoteRef:FireServer(activeNow, isWindowFocused)
			end
		end
	end)
end

function ScoreboardController.Init(parentGui: ScreenGui, clickSfxCallback: (() -> ())?): ()
	if initialized then
		return
	end
	initialized = true
	parentGuiRef = parentGui
	onClickSfx = clickSfxCallback

	-- 1. Disable default Roblox PlayerList so top-right HUD panels stay 100% unobstructed!
	disableDefaultPlayerList()

	-- 2. Sleek HUD Toggle Pill Button (inline beside TopStatsBar on desktop, auto-docked below ticker on narrow screens)
	local btn = Instance.new("TextButton")
	btn.Name = "ScoreboardToggleBtn"
	btn.AnchorPoint = Vector2.new(0, 0)
	btn.Position = UDim2.new(0.5, 308, 0, 8)
	btn.Size = UDim2.fromOffset(112, 44)
	btn.BackgroundColor3 = C_OBS
	btn.BackgroundTransparency = 0.06
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.ZIndex = 12
	btn.Parent = parentGui
	makeCorner(btn, 8)
	toggleStroke = makeStroke(btn, C_GOLD_DIM, 1.2, 0.1)
	addGradient(btn, Color3.fromRGB(22, 26, 36), C_OBS_DEEP)
	toggleBtn = btn

	local dot = Instance.new("Frame")
	dot.Name = "OnlineDot"
	dot.Position = UDim2.new(0, 10, 0.5, -4)
	dot.Size = UDim2.fromOffset(8, 8)
	dot.BackgroundColor3 = C_ONLINE
	dot.BorderSizePixel = 0
	dot.Active = false
	dot.Parent = btn
	makeCorner(dot, 4)
	toggleDot = dot

	local cntLbl = Instance.new("TextLabel")
	cntLbl.Name = "PlayerCountText"
	cntLbl.Position = UDim2.new(0, 23, 0, 5)
	cntLbl.Size = UDim2.fromOffset(44, 18)
	cntLbl.BackgroundTransparency = 1
	cntLbl.Font = FONT_TITLE
	cntLbl.Text = "1/8"
	cntLbl.TextSize = 13
	cntLbl.TextXAlignment = Enum.TextXAlignment.Left
	cntLbl.TextColor3 = C_BONE
	cntLbl.Active = false
	cntLbl.Parent = btn
	toggleCountLbl = cntLbl

	local subTxt = Instance.new("TextLabel")
	subTxt.Name = "SubLabel"
	subTxt.Position = UDim2.new(0, 23, 0, 23)
	subTxt.Size = UDim2.fromOffset(48, 13)
	subTxt.BackgroundTransparency = 1
	subTxt.Font = FONT_BODY
	subTxt.Text = "ROSTER"
	subTxt.TextSize = 8
	subTxt.TextXAlignment = Enum.TextXAlignment.Left
	subTxt.TextColor3 = C_ASH
	subTxt.Active = false
	subTxt.Parent = btn
	toggleSubLbl = subTxt

	local tabCap = Instance.new("TextLabel")
	tabCap.Name = "TabKeyCap"
	tabCap.AnchorPoint = Vector2.new(1, 0.5)
	tabCap.Position = UDim2.new(1, -8, 0.5, 0)
	tabCap.Size = UDim2.fromOffset(30, 20)
	tabCap.BackgroundColor3 = C_INNER
	tabCap.Font = FONT_TITLE
	tabCap.Text = "TAB"
	tabCap.TextSize = 9
	tabCap.TextColor3 = C_GOLD
	tabCap.Active = false
	tabCap.Parent = btn
	makeCorner(tabCap, 5)
	makeStroke(tabCap, C_GOLD_DIM, 1, 0.25)

	btn.MouseEnter:Connect(function()
		if not isOpen and toggleStroke then
			toggleStroke.Color = C_GOLD
		end
	end)
	btn.MouseLeave:Connect(function()
		if not isOpen and toggleStroke then
			toggleStroke.Color = C_GOLD_DIM
		end
	end)
	btn.MouseButton1Click:Connect(function()
		ScoreboardController.Toggle()
	end)

	-- 3. Centered 8-Player Co-op Scoreboard Overlay (dedicated ScreenGui above Hotbar & HUD)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existingOverlay = playerGui:FindFirstChild("FoodEmpireScoreboardGui")
	if existingOverlay then
		existingOverlay:Destroy()
	end
	local sbGui = Instance.new("ScreenGui")
	sbGui.Name = "FoodEmpireScoreboardGui"
	sbGui.ResetOnSpawn = false
	sbGui.IgnoreGuiInset = true
	sbGui.DisplayOrder = 50
	sbGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sbGui.Parent = playerGui
	overlayGui = sbGui

	local sbScale = Instance.new("UIScale")
	sbScale.Name = "ResponsiveScoreboardScale"
	sbScale.Scale = 1
	sbScale.Parent = sbGui
	overlayScale = sbScale

	local scrim = Instance.new("TextButton")
	scrim.Name = "CoopScoreboardOverlay"
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Color3.fromRGB(6, 8, 13)
	scrim.BackgroundTransparency = 0.42
	scrim.BorderSizePixel = 0
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.Visible = false
	scrim.ZIndex = 60
	scrim.Parent = sbGui
	backdrop = scrim

	scrim.MouseButton1Click:Connect(function()
		ScoreboardController.Close()
	end)

	local card = Instance.new("TextButton")
	card.Name = "ScoreboardCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(880, 496)
	card.BackgroundColor3 = C_OBS_DEEP
	card.BackgroundTransparency = 0.03
	card.BorderSizePixel = 0
	card.Text = ""
	card.AutoButtonColor = false
	card.ClipsDescendants = true
	card.ZIndex = 62
	card.Parent = scrim
	makeCorner(card, 12)
	makeStroke(card, C_GOLD, 1.5, 0.12)
	addGradient(card, Color3.fromRGB(18, 22, 32), C_OBS_DEEP)
	cardFrame = card

	local sc = Instance.new("UIScale")
	sc.Scale = 1
	sc.Parent = card
	cardScale = sc

	-- Header Bar (54px)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 54)
	header.BackgroundColor3 = Color3.fromRGB(18, 22, 31)
	header.BorderSizePixel = 0
	header.Parent = card

	local headerLine = Instance.new("Frame")
	headerLine.AnchorPoint = Vector2.new(0, 1)
	headerLine.Position = UDim2.fromScale(0, 1)
	headerLine.Size = UDim2.new(1, 0, 0, 1)
	headerLine.BackgroundColor3 = C_GOLD_DIM
	headerLine.BackgroundTransparency = 0.35
	headerLine.BorderSizePixel = 0
	headerLine.Parent = header

	local emblem = Instance.new("TextLabel")
	emblem.Position = UDim2.new(0, 16, 0.5, -16)
	emblem.Size = UDim2.fromOffset(32, 32)
	emblem.BackgroundColor3 = C_LOCAL_BG
	emblem.Font = FONT_TITLE
	emblem.Text = "8P"
	emblem.TextSize = 12
	emblem.TextColor3 = C_GOLD
	emblem.Parent = header
	makeCorner(emblem, 7)
	makeStroke(emblem, C_GOLD, 1.2, 0.15)

	local hTitle = Instance.new("TextLabel")
	hTitle.Position = UDim2.new(0, 58, 0, 8)
	hTitle.Size = UDim2.new(0.5, -58, 0, 20)
	hTitle.BackgroundTransparency = 1
	hTitle.Font = FONT_TITLE
	hTitle.Text = "CO-OP BASE SCOREBOARD"
	hTitle.TextSize = 16
	hTitle.TextXAlignment = Enum.TextXAlignment.Left
	hTitle.TextColor3 = C_BONE
	hTitle.Parent = header

	local hSub = Instance.new("TextLabel")
	hSub.Position = UDim2.new(0, 58, 0, 29)
	hSub.Size = UDim2.new(0.5, -58, 0, 15)
	hSub.BackgroundTransparency = 1
	hSub.Font = FONT_BODY
	hSub.Text = "4 BASES  ·  2 TEAMMATES PER BASE"
	hSub.TextSize = 10
	hSub.TextXAlignment = Enum.TextXAlignment.Left
	hSub.TextColor3 = C_ASH
	hSub.Parent = header

	-- Header Right Controls: Player Count Pill + Close Button
	local countWrap = Instance.new("Frame")
	countWrap.AnchorPoint = Vector2.new(1, 0.5)
	countWrap.Position = UDim2.new(1, -56, 0.5, 0)
	countWrap.Size = UDim2.fromOffset(186, 36)
	countWrap.BackgroundColor3 = C_INNER
	countWrap.BorderSizePixel = 0
	countWrap.Parent = header
	makeCorner(countWrap, 8)
	makeStroke(countWrap, C_GOLD_DIM, 1.1, 0.2)

	local hcLbl = Instance.new("TextLabel")
	hcLbl.Name = "PlayerCountHeader"
	hcLbl.Position = UDim2.fromOffset(10, 3)
	hcLbl.Size = UDim2.new(1, -20, 0, 16)
	hcLbl.BackgroundTransparency = 1
	hcLbl.Font = FONT_TITLE
	hcLbl.Text = "0 / 8 PLAYERS"
	hcLbl.TextSize = 12
	hcLbl.TextXAlignment = Enum.TextXAlignment.Right
	hcLbl.TextColor3 = C_GOLD_TEXT
	hcLbl.Parent = countWrap
	headerCountLbl = hcLbl

	local hscLbl = Instance.new("TextLabel")
	hscLbl.Name = "StatusBreakdown"
	hscLbl.Position = UDim2.fromOffset(10, 19)
	hscLbl.Size = UDim2.new(1, -20, 0, 13)
	hscLbl.BackgroundTransparency = 1
	hscLbl.Font = FONT_BODY
	hscLbl.Text = "0 ONLINE"
	hscLbl.TextSize = 8
	hscLbl.TextXAlignment = Enum.TextXAlignment.Right
	hscLbl.TextColor3 = C_ASH
	hscLbl.Parent = countWrap
	headerSubCountLbl = hscLbl

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -14, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(32, 32)
	closeBtn.BackgroundColor3 = C_INNER
	closeBtn.Font = FONT_TITLE
	closeBtn.Text = "×"
	closeBtn.TextSize = 20
	closeBtn.TextColor3 = C_BONE
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = header
	makeCorner(closeBtn, 7)
	makeStroke(closeBtn, C_BORDER, 1, 0.25)

	closeBtn.MouseButton1Click:Connect(function()
		if onClickSfx then
			onClickSfx()
		end
		ScoreboardController.Close()
	end)

	-- Legend Strip (22px)
	local legendBar = Instance.new("Frame")
	legendBar.Name = "LegendStrip"
	legendBar.Position = UDim2.fromOffset(16, 58)
	legendBar.Size = UDim2.new(1, -32, 0, 22)
	legendBar.BackgroundTransparency = 1
	legendBar.Parent = card

	local legendLeft = Instance.new("Frame")
	legendLeft.Size = UDim2.new(0.68, 0, 1, 0)
	legendLeft.BackgroundTransparency = 1
	legendLeft.Parent = legendBar

	local legLayout = Instance.new("UIListLayout")
	legLayout.FillDirection = Enum.FillDirection.Horizontal
	legLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	legLayout.SortOrder = Enum.SortOrder.LayoutOrder
	legLayout.Padding = UDim.new(0, 14)
	legLayout.Parent = legendLeft

	local function addLegendChip(order: number, dotCol: Color3, text: string): ()
		local wrap = Instance.new("Frame")
		wrap.LayoutOrder = order
		wrap.AutomaticSize = Enum.AutomaticSize.X
		wrap.Size = UDim2.fromOffset(0, 18)
		wrap.BackgroundTransparency = 1
		wrap.Parent = legendLeft

		local d = Instance.new("Frame")
		d.Position = UDim2.new(0, 0, 0.5, -3)
		d.Size = UDim2.fromOffset(6, 6)
		d.BackgroundColor3 = dotCol
		d.BorderSizePixel = 0
		d.Parent = wrap
		makeCorner(d, 3)

		local l = Instance.new("TextLabel")
		l.Position = UDim2.fromOffset(10, 0)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.Size = UDim2.fromOffset(0, 18)
		l.BackgroundTransparency = 1
		l.Font = FONT_BODY
		l.Text = text
		l.TextSize = 9
		l.TextColor3 = C_ASH
		l.Parent = wrap
	end

	addLegendChip(1, C_ONLINE, "ONLINE")
	addLegendChip(2, C_INACTIVE, "INACTIVE")
	addLegendChip(3, C_DISCONN, "DISCONNECTED")

	local keyHintLbl = Instance.new("TextLabel")
	keyHintLbl.AnchorPoint = Vector2.new(1, 0.5)
	keyHintLbl.Position = UDim2.new(1, 0, 0.5, 0)
	keyHintLbl.Size = UDim2.new(0.32, 0, 1, 0)
	keyHintLbl.BackgroundTransparency = 1
	keyHintLbl.Font = FONT_BODY
	keyHintLbl.Text = "[TAB] TOGGLE  ·  [ESC] CLOSE"
	keyHintLbl.TextSize = 9
	keyHintLbl.TextXAlignment = Enum.TextXAlignment.Right
	keyHintLbl.TextColor3 = C_MUTED
	keyHintLbl.Parent = legendBar

	-- Main 4-Base Grid Container
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "BasesGridScroll"
	scroll.Position = UDim2.fromOffset(16, 84)
	scroll.Size = UDim2.new(1, -32, 1, -96)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = C_GOLD_DIM
	scroll.CanvasSize = UDim2.fromOffset(0, 354)
	scroll.Parent = card
	gridScroll = scroll

	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.CellPadding = UDim2.fromOffset(14, 10)
	grid.CellSize = UDim2.fromOffset(416, 170)
	grid.Parent = scroll
	gridLayout = grid

	for idx, slot in ipairs(SLOT_ORDER) do
		baseCards[slot] = createBaseCard(scroll, slot, idx)
	end

	-- Optional bottom strip for newly joined players awaiting base assignment
	local unBar = Instance.new("Frame")
	unBar.Name = "UnassignedBar"
	unBar.AnchorPoint = Vector2.new(0, 1)
	unBar.Position = UDim2.new(0, 16, 1, -8)
	unBar.Size = UDim2.new(1, -32, 0, 22)
	unBar.BackgroundColor3 = C_INNER
	unBar.Visible = false
	unBar.Parent = card
	makeCorner(unBar, 5)

	local unLbl = Instance.new("TextLabel")
	unLbl.Position = UDim2.fromOffset(10, 0)
	unLbl.Size = UDim2.new(1, -20, 1, 0)
	unLbl.BackgroundTransparency = 1
	unLbl.Font = FONT_BODY
	unLbl.Text = ""
	unLbl.TextSize = 10
	unLbl.TextXAlignment = Enum.TextXAlignment.Left
	unLbl.TextColor3 = C_ASH
	unLbl.Parent = unBar
	unassignedBar = unBar
	unassignedLbl = unLbl

	-- 4. Responsive camera & HUD scale binding
	local function bindResize(): ()
		local cam = Workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
		end
	end
	bindResize()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindResize)
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		pg:GetAttributeChangedSignal("FoodEmpireHUDScale"):Connect(updateResponsiveLayout)
	end

	-- 5. Connect Server ScoreboardSync & PlayerActivityPing remotes
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
		if not remotes then
			return
		end
		local sEv = remotes:WaitForChild("ScoreboardSync", 15)
		if sEv and sEv:IsA("RemoteEvent") then
			sEv.OnClientEvent:Connect(function(snap: any)
				if typeof(snap) == "table" then
					applySnapshot(snap)
				end
			end)
		end
		local aEv = remotes:WaitForChild("PlayerActivityPing", 15)
		if aEv and aEv:IsA("RemoteEvent") then
			activityRemoteRef = aEv
			aEv:FireServer(true, isWindowFocused)
		end
	end)

	startActivityTracker()
	applySnapshot(buildFallbackSnapshot())
	updateResponsiveLayout()
end

return ScoreboardController
