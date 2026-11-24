--!strict

-- SpinWheelController: Dark-noir interactive Central Market Lucky Spin roulette modal.
-- Connects to OpenSpinWheel RemoteEvent and ActionRequest("SpinMarketWheel"), animates a smooth
-- ticking reel landing cleanly on the server-awarded prize with a 3D ViewportFrame prize reveal!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AudioController = require("./AudioController")
local ModelPreviewHelper = require("./ModelPreviewHelper")

local SpinWheelController = {}

local C_OBS = Color3.fromRGB(13, 14, 18)
local C_CARD = Color3.fromRGB(20, 22, 28)
local C_BORDER = Color3.fromRGB(48, 52, 62)
local C_BRASS = Color3.fromRGB(172, 142, 76)
local C_OXBLOOD = Color3.fromRGB(134, 28, 36)
local C_BONE = Color3.fromRGB(236, 232, 224)
local C_ASH = Color3.fromRGB(154, 158, 168)

local modal: Frame? = nil
local eventBannerLbl: TextLabel? = nil
local reelStrip: Frame? = nil
local spinBtn: TextButton? = nil
local statusLbl: TextLabel? = nil
local resultCard: Frame? = nil
local resultPreviewHost: Frame? = nil
local resultTitleLbl: TextLabel? = nil
local resultDetailLbl: TextLabel? = nil
local isSpinning = false
local latestSnapshot: { [string]: any }? = nil
local actionFn: RemoteFunction? = nil
local onStateUpdated: ((any) -> ())? = nil

local TILE_W = 112
local TILE_GAP = 8
local TILE_STRIDE = TILE_W + TILE_GAP
local TILE_H = 116
local REEL_WINDOW_W = 580
local REEL_WINDOW_H = 126
local REEL_CYCLES = 6

type ReelTileEntry = {
	OffsetX: number,
	Viewport: ViewportFrame?,
}
local reelTileEntries: { ReelTileEntry } = {}
local headerPreviewVp: ViewportFrame? = nil

local function updateVisibleReelViewports(stripX: number?): ()
	local isOpen = modal ~= nil and modal.Visible
	if headerPreviewVp then
		headerPreviewVp.Visible = isOpen
	end
	local curX = if stripX ~= nil
		then stripX
		elseif reelStrip then reelStrip.Position.X.Offset
		else 0
	for _, entry in ipairs(reelTileEntries) do
		local vp = entry.Viewport
		if vp and vp.Parent then
			if not isOpen then
				vp.Visible = false
			else
				local leftEdge = curX + entry.OffsetX
				local rightEdge = leftEdge + TILE_W
				-- Only render ViewportFrames intersecting the 580px window (+half-tile buffer) to stay well under GPU atlas cap!
				vp.Visible = (rightEdge >= -40) and (leftEdge <= REEL_WINDOW_W + 40)
			end
		end
	end
end

local function isValidPreviewKind(kind: string): boolean
	return kind == "Weapon"
		or kind == "Ammo"
		or kind == "Bodyguard"
		or kind == "Equipment"
		or kind == "Premium"
		or kind == "Warehouse"
		or kind == "Dish"
		or kind == "Empire"
end

local function makeCorner(parent: Instance, r: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function makeStroke(parent: Instance, col: Color3, thick: number): UIStroke
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = col
	st.Thickness = thick
	st.Parent = parent
	return st
end

local function populateReel(prizes: { any }): ()
	if not reelStrip then return end
	for _, ch in ipairs(reelStrip:GetChildren()) do
		ch:Destroy()
	end
	table.clear(reelTileEntries)

	local count = #prizes
	if count == 0 then return end
	local totalTiles = count * REEL_CYCLES
	reelStrip.Size = UDim2.fromOffset(totalTiles * TILE_STRIDE, REEL_WINDOW_H - 2)

	for cycle = 0, REEL_CYCLES - 1 do
		for i, p in ipairs(prizes) do
			local idx = cycle * count + (i - 1)
			local offsetX = idx * TILE_STRIDE
			local tile = Instance.new("Frame")
			tile.Name = "Tile_" .. tostring(idx)
			tile.Position = UDim2.fromOffset(offsetX, 5)
			tile.Size = UDim2.fromOffset(TILE_W, TILE_H)
			tile.BackgroundColor3 = C_CARD
			tile.BorderSizePixel = 0
			tile.Parent = reelStrip
			makeCorner(tile, 6)

			local col = Color3.fromRGB(tonumber(p.ColorR) or 120, tonumber(p.ColorG) or 120, tonumber(p.ColorB) or 120)
			makeStroke(tile, col, 1.3)

			local topStrip = Instance.new("Frame")
			topStrip.Size = UDim2.new(1, 0, 0, 4)
			topStrip.BackgroundColor3 = col
			topStrip.BorderSizePixel = 0
			topStrip.Parent = tile

			local rar = Instance.new("TextLabel")
			rar.Position = UDim2.new(0, 6, 0, 7)
			rar.Size = UDim2.new(1, -12, 0, 12)
			rar.BackgroundTransparency = 1
			rar.Font = Enum.Font.GothamBold
			rar.Text = string.upper(tostring(p.Rarity or "COMMON"))
			rar.TextSize = 8
			rar.TextColor3 = col:Lerp(C_BONE, 0.35)
			rar.Parent = tile

			-- Studio-lit 3D Icon Box centered in every Lucky Spin reel card!
			local iconBox = Instance.new("Frame")
			iconBox.Name = "IconBox"
			iconBox.AnchorPoint = Vector2.new(0.5, 0)
			iconBox.Position = UDim2.new(0.5, 0, 0, 22)
			iconBox.Size = UDim2.fromOffset(60, 60)
			iconBox.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
			iconBox.BorderSizePixel = 0
			iconBox.Parent = tile
			makeCorner(iconBox, 6)
			makeStroke(iconBox, col:Lerp(C_BORDER, 0.55), 1)

			local pKind = tostring(p.PreviewKind or "Equipment")
			local pId = tostring(p.PreviewId or "InstantEmpireCrate")
			local vp: ViewportFrame? = nil
			if isValidPreviewKind(pKind) then
				local created = ModelPreviewHelper.CreatePreview(
					iconBox,
					pKind :: any,
					pId,
					UDim2.fromScale(1, 1),
					UDim2.new(),
					Color3.fromRGB(16, 18, 24)
				)
				created.Visible = false
				vp = created
			end

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 4, 0, 86)
			nameLbl.Size = UDim2.new(1, -8, 0, 26)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.GothamBlack
			nameLbl.TextWrapped = true
			nameLbl.Text = tostring(p.ShortLabel or p.Title or "PRIZE")
			nameLbl.TextSize = 11
			nameLbl.TextColor3 = C_BONE
			nameLbl.Parent = tile

			table.insert(reelTileEntries, {
				OffsetX = offsetX,
				Viewport = vp,
			})
		end
	end

	updateVisibleReelViewports(reelStrip.Position.X.Offset)
end

local function refreshSnapshotUI(snap: { [string]: any }?): ()
	if not snap then return end
	latestSnapshot = snap

	if eventBannerLbl then
		if snap.EventActive then
			eventBannerLbl.Text = string.format("LUCKY SPIN EVENT LIVE  |  %ds LEFT  |  200G SPINS", tonumber(snap.EventTimeLeft) or 0)
			eventBannerLbl.TextColor3 = Color3.fromRGB(142, 212, 162)
		else
			local rem = tonumber(snap.NextFreeIn) or 0
			eventBannerLbl.Text = if snap.CanFreeSpin
				then "FREE CENTRAL MARKET SPIN AVAILABLE NOW"
				else string.format("NEXT FREE SPIN IN %ds  |  PAID SPIN: %d GOLD", rem, tonumber(snap.SpinCost) or 350)
			eventBannerLbl.TextColor3 = C_BRASS
		end
	end

	if spinBtn and not isSpinning then
		local cost = tonumber(snap.SpinCost) or 350
		if snap.CanFreeSpin or cost <= 0 then
			spinBtn.Text = if snap.IsEventFreeSpin then "CLAIM FREE EVENT SPIN" else "FREE SPIN"
			spinBtn.BackgroundColor3 = Color3.fromRGB(48, 96, 66)
		else
			spinBtn.Text = string.format("SPIN WHEEL  (%d GOLD)", cost)
			spinBtn.BackgroundColor3 = C_OXBLOOD
		end
	end

	if reelStrip and #reelStrip:GetChildren() == 0 and typeof(snap.Prizes) == "table" then
		populateReel(snap.Prizes)
	end
end

local function showResultBanner(res: { [string]: any }): ()
	if not resultCard or not resultTitleLbl or not resultDetailLbl or not resultPreviewHost then return end
	resultCard.Visible = true
	resultTitleLbl.Text = string.format("[%s]  %s", string.upper(tostring(res.Rarity or "PRIZE")), string.upper(tostring(res.PrizeTitle or "WON")))
	resultDetailLbl.Text = tostring(res.Detail or "")

	for _, ch in ipairs(resultPreviewHost:GetChildren()) do
		ch:Destroy()
	end
	local pKind = tostring(res.PreviewKind or "Equipment")
	local pId = tostring(res.PreviewId or "InstantEmpireCrate")
	if isValidPreviewKind(pKind) then
		ModelPreviewHelper.CreatePreview(
			resultPreviewHost,
			pKind :: any,
			pId,
			UDim2.fromScale(1, 1),
			UDim2.new(),
			Color3.fromRGB(24, 26, 33)
		)
	end
end

local function runSpinAnimation(): ()
	if isSpinning or not actionFn or not reelStrip or not modal then
		return
	end
	isSpinning = true
	if spinBtn then
		spinBtn.Text = "SPINNING..."
		spinBtn.BackgroundColor3 = Color3.fromRGB(42, 46, 54)
	end
	if resultCard then
		resultCard.Visible = false
	end
	if statusLbl then
		statusLbl.Text = "Rolling Central Market Syndicate Wheel..."
	end

	local ok, response = pcall(function()
		return (actionFn :: RemoteFunction):InvokeServer("SpinMarketWheel", nil)
	end)

	if not ok or typeof(response) ~= "table" or not response.Success or typeof(response.SpinResult) ~= "table" then
		isSpinning = false
		AudioController.PlayError()
		if statusLbl then
			statusLbl.Text = if typeof(response) == "table" and typeof(response.Message) == "string"
				then response.Message
				else "Unable to spin right now."
		end
		if typeof(response) == "table" and typeof(response.State) == "table" then
			if onStateUpdated then onStateUpdated(response.State) end
			if typeof(response.State.SpinEvent) == "table" then
				refreshSnapshotUI(response.State.SpinEvent)
			end
		end
		return
	end

	local res = response.SpinResult
	local prizes = if latestSnapshot and typeof(latestSnapshot.Prizes) == "table" then latestSnapshot.Prizes else {}
	local count = math.max(1, #prizes)
	if #reelStrip:GetChildren() == 0 and count > 0 then
		populateReel(prizes)
	end

	local winSeg = math.clamp(tonumber(res.SegmentIndex) or 1, 1, count)
	-- Land cleanly inside cycle 4 on the exact winning segment centered beneath the needle!
	local viewportW = REEL_WINDOW_W
	local targetTileIdx = (REEL_CYCLES - 2) * count + (winSeg - 1)
	local jitter = math.random(-22, 22)
	local targetX = -(targetTileIdx * TILE_STRIDE + TILE_W * 0.5 - viewportW * 0.5 + jitter)

	local startX = 0
	reelStrip.Position = UDim2.fromOffset(startX, 0)
	updateVisibleReelViewports(startX)

	local duration = 3.25
	local elapsed = 0
	local lastNotch = -1
	local conn: RBXScriptConnection? = nil

	conn = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += math.min(dt, 0.05)
		local u = math.clamp(elapsed / duration, 0, 1)
		-- Quartic ease-out for crisp authentic roulette deceleration!
		local inv = 1 - u
		local ease = 1 - inv * inv * inv * inv
		local curX = startX + (targetX - startX) * ease
		if reelStrip then
			local snappedX = math.floor(curX + 0.5)
			reelStrip.Position = UDim2.fromOffset(snappedX, 0)
			updateVisibleReelViewports(snappedX)
		end

		local notch = math.floor((math.abs(curX) + viewportW * 0.5) / TILE_STRIDE)
		if notch ~= lastNotch then
			lastNotch = notch
			AudioController.PlayClick()
		end

		if u >= 1 then
			if conn then conn:Disconnect(); conn = nil end
			isSpinning = false
			AudioController.PlayFanfare()
			showResultBanner(res)
			if statusLbl then
				statusLbl.Text = tostring(res.Detail or "Prize awarded!")
			end
			if typeof(response.State) == "table" then
				if onStateUpdated then onStateUpdated(response.State) end
				if typeof(response.State.SpinEvent) == "table" then
					refreshSnapshotUI(response.State.SpinEvent)
				end
			end
		end
	end)
end

function SpinWheelController.Open(snap: { [string]: any }?): ()
	if snap then
		refreshSnapshotUI(snap)
	end
	if modal then
		modal.Visible = true
		updateVisibleReelViewports()
		AudioController.PlayClick()
	end
end

function SpinWheelController.Update(state: { [string]: any }): ()
	if typeof(state.SpinEvent) == "table" then
		refreshSnapshotUI(state.SpinEvent)
	end
end

function SpinWheelController.Init(parentGui: ScreenGui, stateCallback: (any) -> ()): ()
	onStateUpdated = stateCallback
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes then
		local fn = remotes:WaitForChild("ActionRequest", 15)
		if fn and fn:IsA("RemoteFunction") then
			actionFn = fn
		end
		local ev = remotes:WaitForChild("OpenSpinWheel", 15)
		if ev and ev:IsA("RemoteEvent") then
			ev.OnClientEvent:Connect(function(snap: any)
				if typeof(snap) == "table" then
					SpinWheelController.Open(snap)
				else
					SpinWheelController.Open(nil)
				end
			end)
		end
	end

	local frame = Instance.new("Frame")
	frame.Name = "CentralMarketSpinModal"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.45)
	frame.Size = UDim2.fromOffset(620, 424)
	frame.BackgroundColor3 = C_OBS
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 35
	frame.Parent = parentGui
	makeCorner(frame, 8)
	makeStroke(frame, C_BRASS, 1.4)
	modal = frame

	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(1, 0, 0, 3)
	accentBar.BackgroundColor3 = C_OXBLOOD
	accentBar.BorderSizePixel = 0
	accentBar.Parent = frame

	local headerIconHost = Instance.new("Frame")
	headerIconHost.Name = "HeaderWheelIcon"
	headerIconHost.Position = UDim2.new(0, 18, 0, 12)
	headerIconHost.Size = UDim2.fromOffset(40, 40)
	headerIconHost.BackgroundColor3 = C_CARD
	headerIconHost.BorderSizePixel = 0
	headerIconHost.Parent = frame
	makeCorner(headerIconHost, 6)
	makeStroke(headerIconHost, C_BRASS, 1)
	local hVp = ModelPreviewHelper.CreatePreview(
		headerIconHost,
		"Empire",
		"SPN",
		UDim2.fromScale(1, 1),
		UDim2.new(),
		C_CARD
	)
	hVp.Visible = false
	headerPreviewVp = hVp

	local title = Instance.new("TextLabel")
	title.Position = UDim2.new(0, 68, 0, 12)
	title.Size = UDim2.new(1, -126, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "CENTRAL MARKET LUCKY SPIN"
	title.TextSize = 16
	title.TextColor3 = C_BONE
	title.Parent = frame

	local evLbl = Instance.new("TextLabel")
	evLbl.Position = UDim2.new(0, 68, 0, 36)
	evLbl.Size = UDim2.new(1, -126, 0, 16)
	evLbl.BackgroundTransparency = 1
	evLbl.Font = Enum.Font.GothamBold
	evLbl.TextXAlignment = Enum.TextXAlignment.Left
	evLbl.Text = "WIN BODYGUARDS, FIREARMS, GOLD & FRESH INGREDIENT CRATES"
	evLbl.TextSize = 10
	evLbl.TextColor3 = C_BRASS
	evLbl.Parent = frame
	eventBannerLbl = evLbl

	local closeBtn = Instance.new("TextButton")
	closeBtn.Position = UDim2.new(1, -44, 0, 12)
	closeBtn.Size = UDim2.fromOffset(30, 28)
	closeBtn.BackgroundColor3 = C_CARD
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.Text = "X"
	closeBtn.TextSize = 12
	closeBtn.TextColor3 = C_BONE
	closeBtn.Parent = frame
	makeCorner(closeBtn, 5)
	makeStroke(closeBtn, C_BORDER, 1)
	closeBtn.MouseButton1Click:Connect(function()
		if not isSpinning then
			frame.Visible = false
			updateVisibleReelViewports()
		end
	end)

	-- Roulette Viewport Window with Center Brass/Crimson Pointer Needle
	local reelWindow = Instance.new("Frame")
	reelWindow.Name = "ReelWindow"
	reelWindow.Position = UDim2.new(0, 20, 0, 66)
	reelWindow.Size = UDim2.fromOffset(REEL_WINDOW_W, REEL_WINDOW_H)
	reelWindow.BackgroundColor3 = Color3.fromRGB(9, 10, 14)
	reelWindow.ClipsDescendants = true
	reelWindow.Parent = frame
	makeCorner(reelWindow, 6)
	makeStroke(reelWindow, C_BORDER, 1.2)

	local strip = Instance.new("Frame")
	strip.Name = "ReelStrip"
	strip.Position = UDim2.fromOffset(0, 0)
	strip.Size = UDim2.fromOffset(REEL_WINDOW_W, REEL_WINDOW_H - 2)
	strip.BackgroundTransparency = 1
	strip.Parent = reelWindow
	reelStrip = strip

	-- Crisp Vertical Center Selector Line + Top/Bottom Notches
	local needle = Instance.new("Frame")
	needle.AnchorPoint = Vector2.new(0.5, 0)
	needle.Position = UDim2.fromScale(0.5, 0)
	needle.Size = UDim2.new(0, 2, 1, 0)
	needle.BackgroundColor3 = C_BRASS
	needle.BorderSizePixel = 0
	needle.ZIndex = 10
	needle.Parent = reelWindow

	local topNotch = Instance.new("Frame")
	topNotch.AnchorPoint = Vector2.new(0.5, 0)
	topNotch.Position = UDim2.new(0.5, 0, 0, 0)
	topNotch.Size = UDim2.fromOffset(14, 7)
	topNotch.BackgroundColor3 = C_OXBLOOD
	topNotch.BorderSizePixel = 0
	topNotch.ZIndex = 11
	topNotch.Parent = reelWindow

	-- Spin Action Button
	local sBtn = Instance.new("TextButton")
	sBtn.Name = "SpinActionBtn"
	sBtn.AnchorPoint = Vector2.new(0.5, 0)
	sBtn.Position = UDim2.new(0.5, 0, 0, 206)
	sBtn.Size = UDim2.fromOffset(270, 40)
	sBtn.BackgroundColor3 = C_OXBLOOD
	sBtn.Font = Enum.Font.GothamBlack
	sBtn.Text = "SPIN WHEEL  (350 GOLD)"
	sBtn.TextSize = 13
	sBtn.TextColor3 = C_BONE
	sBtn.Parent = frame
	makeCorner(sBtn, 5)
	makeStroke(sBtn, C_BRASS, 1.2)
	sBtn.MouseButton1Click:Connect(runSpinAnimation)
	spinBtn = sBtn

	local stLbl = Instance.new("TextLabel")
	stLbl.Position = UDim2.new(0, 20, 0, 254)
	stLbl.Size = UDim2.new(1, -40, 0, 18)
	stLbl.BackgroundTransparency = 1
	stLbl.Font = Enum.Font.Gotham
	stLbl.Text = "Press SPIN to roll for Guns, Bodyguards, Gold, Kevlar, Fish, Meat, Veg or Fruit!"
	stLbl.TextSize = 11
	stLbl.TextColor3 = C_ASH
	stLbl.Parent = frame
	statusLbl = stLbl

	-- Prize Reveal Result Card (with 3D ViewportFrame thumbnail!)
	local rCard = Instance.new("Frame")
	rCard.Name = "ResultCard"
	rCard.Position = UDim2.new(0, 20, 0, 282)
	rCard.Size = UDim2.new(1, -40, 0, 122)
	rCard.BackgroundColor3 = C_CARD
	rCard.Visible = false
	rCard.Parent = frame
	makeCorner(rCard, 6)
	makeStroke(rCard, C_BRASS, 1.2)
	resultCard = rCard

	local pHost = Instance.new("Frame")
	pHost.Position = UDim2.new(0, 12, 0, 12)
	pHost.Size = UDim2.fromOffset(90, 90)
	pHost.BackgroundColor3 = Color3.fromRGB(24, 26, 33)
	pHost.Parent = rCard
	makeCorner(pHost, 6)
	resultPreviewHost = pHost

	local rtLbl = Instance.new("TextLabel")
	rtLbl.Position = UDim2.new(0, 116, 0, 18)
	rtLbl.Size = UDim2.new(1, -130, 0, 24)
	rtLbl.BackgroundTransparency = 1
	rtLbl.Font = Enum.Font.GothamBlack
	rtLbl.TextXAlignment = Enum.TextXAlignment.Left
	rtLbl.TextSize = 15
	rtLbl.TextColor3 = C_BRASS
	rtLbl.Text = ""
	rtLbl.Parent = rCard
	resultTitleLbl = rtLbl

	local rdLbl = Instance.new("TextLabel")
	rdLbl.Position = UDim2.new(0, 116, 0, 48)
	rdLbl.Size = UDim2.new(1, -130, 0, 50)
	rdLbl.BackgroundTransparency = 1
	rdLbl.Font = Enum.Font.Gotham
	rdLbl.TextWrapped = true
	rdLbl.TextXAlignment = Enum.TextXAlignment.Left
	rdLbl.TextYAlignment = Enum.TextYAlignment.Top
	rdLbl.TextSize = 12
	rdLbl.TextColor3 = C_BONE
	rdLbl.Text = ""
	rdLbl.Parent = rCard
	resultDetailLbl = rdLbl
end

return SpinWheelController
