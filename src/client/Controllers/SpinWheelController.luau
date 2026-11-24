--!strict

-- SpinWheelController: AAA dark-noir Underground Syndicate Luxury Vault Roulette modal (760x496).
-- Features:
--  * Dual-border obsidian & 24K brushed brass chassis, live Gold balance badge & Event status pill.
--  * 716x148 high-drama roulette window with left/right vignette fades, rarity-tinted luxury 3D tiles,
--    exact Drop Odds % badges, strict horizontal ViewportFrame GPU culling (<= 8 visible),
--    flashing 24K brass laser center needle, quintic near-miss deceleration & pitch-escalating ticks.
--  * Full 8-Prize Odds & Jackpot Legend Strip below the reel.
--  * Expanded Prize Showcase Banner with a live 96x96 slowly orbiting 3D ViewportFrame preview.
--  * Automatically launches CinematicRevealController's full-screen Vault Breach & surprise bass/gong
--    drop on Legendary (Bodyguard) and Epic (Black Market Firearm) wins!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AudioController = require("./AudioController")
local ModelPreviewHelper = require("./ModelPreviewHelper")
local CinematicRevealController = require("./CinematicRevealController")
local CurrencyIconHelper = require("./CurrencyIconHelper")

local SpinWheelController = {}

local C_OBS = Color3.fromRGB(10, 11, 16)
local C_PANEL = Color3.fromRGB(16, 18, 24)
local C_CARD = Color3.fromRGB(22, 24, 32)
local C_BORDER = Color3.fromRGB(52, 56, 68)
local C_BRASS = Color3.fromRGB(196, 158, 82)
local C_GOLD_HI = Color3.fromRGB(252, 220, 128)
local C_OXBLOOD = Color3.fromRGB(148, 28, 38)
local C_CRIMSON_HI = Color3.fromRGB(226, 58, 72)
local C_EMERALD = Color3.fromRGB(46, 114, 76)
local C_BONE = Color3.fromRGB(240, 236, 228)
local C_ASH = Color3.fromRGB(158, 164, 176)

local backdrop: Frame? = nil
local modal: Frame? = nil
local eventBannerLbl: TextLabel? = nil
local goldPillLbl: TextLabel? = nil
local statusPillLbl: TextLabel? = nil
local reelStrip: Frame? = nil
local legendHost: Frame? = nil
local needleLine: Frame? = nil
local topPointer: Frame? = nil
local botPointer: Frame? = nil
local spinBtn: TextButton? = nil
local statusLbl: TextLabel? = nil
local resultCard: Frame? = nil
local resultCardStroke: UIStroke? = nil
local resultPreviewHost: Frame? = nil
local resultRarityPill: TextLabel? = nil
local resultTitleLbl: TextLabel? = nil
local resultDetailLbl: TextLabel? = nil
local replayBtn: TextButton? = nil

local isSpinning = false
local latestSnapshot: { [string]: any }? = nil
local latestResult: { [string]: any }? = nil
local playerGold = 0
local actionFn: RemoteFunction? = nil
local onStateUpdated: ((any) -> ())? = nil

local TILE_W = 124
local TILE_GAP = 10
local TILE_STRIDE = TILE_W + TILE_GAP
local TILE_H = 136
local REEL_WINDOW_W = 716
local REEL_WINDOW_H = 148
local REEL_CYCLES = 6

type ReelTileEntry = {
	OffsetX: number,
	Viewport: ViewportFrame?,
}
local reelTileEntries: { ReelTileEntry } = {}
local headerPreviewVp: ViewportFrame? = nil
local resultPreviewVp: ViewportFrame? = nil
local resultOrbitCam: Camera? = nil
local resultOrbitCenter = Vector3.new(0, 0, 0)
local resultOrbitDist = 5.5
local resultOrbitHeight = 0.8
local resultOrbitConn: RBXScriptConnection? = nil

local function formatGold(n: number): string
	local s = tostring(math.max(0, math.floor(n)))
	local formatted = s
	while true do
		local nextStr, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = nextStr
		if k == 0 then break end
	end
	return formatted
end

local function updateVisibleReelViewports(stripX: number?): ()
	local revealPlaying = CinematicRevealController.IsActive()
	local isOpen = (modal ~= nil and modal.Visible) and (not revealPlaying)
	if headerPreviewVp and headerPreviewVp.Parent then
		headerPreviewVp.Visible = isOpen
	end
	if resultPreviewVp and resultPreviewVp.Parent then
		resultPreviewVp.Visible = isOpen and (resultCard ~= nil and resultCard.Visible)
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
				-- Strict horizontal GPU culling: only render tiles visible inside the 716px window (<= 6-7 active)!
				vp.Visible = (rightEdge >= -28) and (leftEdge <= REEL_WINDOW_W + 28)
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

local function makeStroke(parent: Instance, col: Color3, thick: number, trans: number?): UIStroke
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = col
	st.Thickness = thick
	if trans then
		st.Transparency = trans
	end
	st.Parent = parent
	return st
end

local function getRarityColors(rarity: string, fallbackCol: Color3): (Color3, Color3, Color3)
	if rarity == "Legendary" then
		return Color3.fromRGB(36, 28, 14), C_BRASS, C_GOLD_HI
	elseif rarity == "Epic" then
		return Color3.fromRGB(34, 14, 18), C_OXBLOOD, C_CRIMSON_HI
	elseif rarity == "Rare" then
		return Color3.fromRGB(18, 25, 36), fallbackCol, fallbackCol:Lerp(C_BONE, 0.45)
	end
	return C_CARD, fallbackCol:Lerp(C_BORDER, 0.25), fallbackCol:Lerp(C_BONE, 0.35)
end

local function populateLegendStrip(prizes: { any }): ()
	if not legendHost then return end
	for _, ch in ipairs(legendHost:GetChildren()) do
		ch:Destroy()
	end
	local count = #prizes
	if count == 0 then return end
	local gap = 6
	local pillW = math.floor((REEL_WINDOW_W - (count - 1) * gap) / count)
	for i, p in ipairs(prizes) do
		local col = Color3.fromRGB(tonumber(p.ColorR) or 120, tonumber(p.ColorG) or 120, tonumber(p.ColorB) or 120)
		local rarity = tostring(p.Rarity or "Common")
		local bgCol, strokeCol, hiCol = getRarityColors(rarity, col)

		local pill = Instance.new("Frame")
		pill.Position = UDim2.fromOffset((i - 1) * (pillW + gap), 0)
		pill.Size = UDim2.fromOffset(pillW, 28)
		pill.BackgroundColor3 = bgCol
		pill.BorderSizePixel = 0
		pill.ZIndex = 37
		pill.Parent = legendHost
		makeCorner(pill, 4)
		makeStroke(pill, strokeCol, if rarity == "Legendary" or rarity == "Epic" then 1.3 else 1, 0.25)

		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, 0, 0, 2)
		bar.BackgroundColor3 = hiCol
		bar.BorderSizePixel = 0
		bar.ZIndex = 38
		bar.Parent = pill

		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.fromOffset(3, 3)
		lbl.Size = UDim2.new(1, -6, 0, 12)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		lbl.Text = tostring(p.ShortLabel or "PRIZE")
		lbl.TextSize = 8
		lbl.TextColor3 = C_BONE
		lbl.ZIndex = 38
		lbl.Parent = pill

		local odds = tonumber(p.OddsPct) or 10
		local oddsLbl = Instance.new("TextLabel")
		oddsLbl.Position = UDim2.fromOffset(3, 14)
		oddsLbl.Size = UDim2.new(1, -6, 0, 11)
		oddsLbl.BackgroundTransparency = 1
		oddsLbl.Font = Enum.Font.GothamBold
		oddsLbl.Text = string.format("%s  %d%%", string.sub(string.upper(rarity), 1, 3), odds)
		oddsLbl.TextSize = 8
		oddsLbl.TextColor3 = hiCol
		oddsLbl.ZIndex = 38
		oddsLbl.Parent = pill
	end
end

local function populateReel(prizes: { any }): ()
	if not reelStrip then return end
	for _, ch in ipairs(reelStrip:GetChildren()) do
		ch:Destroy()
	end
	table.clear(reelTileEntries)

	local count = #prizes
	if count == 0 then return end
	populateLegendStrip(prizes)

	local totalTiles = count * REEL_CYCLES
	reelStrip.Size = UDim2.fromOffset(totalTiles * TILE_STRIDE, REEL_WINDOW_H - 2)

	for cycle = 0, REEL_CYCLES - 1 do
		for i, p in ipairs(prizes) do
			local idx = cycle * count + (i - 1)
			local offsetX = idx * TILE_STRIDE
			local col = Color3.fromRGB(tonumber(p.ColorR) or 120, tonumber(p.ColorG) or 120, tonumber(p.ColorB) or 120)
			local rarity = tostring(p.Rarity or "Common")
			local bgCol, strokeCol, hiCol = getRarityColors(rarity, col)

			local tile = Instance.new("Frame")
			tile.Name = "Tile_" .. tostring(idx)
			tile.Position = UDim2.fromOffset(offsetX, 6)
			tile.Size = UDim2.fromOffset(TILE_W, TILE_H)
			tile.BackgroundColor3 = bgCol
			tile.BorderSizePixel = 0
			tile.ZIndex = 37
			tile.Parent = reelStrip
			makeCorner(tile, 7)
			makeStroke(tile, strokeCol, if rarity == "Legendary" then 2.0 elseif rarity == "Epic" then 1.8 else 1.2)

			-- Subtle luxury vertical card gradient
			local tileGrad = Instance.new("UIGradient")
			tileGrad.Rotation = 90
			tileGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 185, 195)),
			})
			tileGrad.Parent = tile

			-- Top Rarity Bar
			local topStrip = Instance.new("Frame")
			topStrip.Size = UDim2.new(1, 0, 0, 4)
			topStrip.BackgroundColor3 = hiCol
			topStrip.BorderSizePixel = 0
			topStrip.ZIndex = 38
			topStrip.Parent = tile

			-- Rarity Label (top-left) + Exact Drop Odds % Badge (top-right)
			local rar = Instance.new("TextLabel")
			rar.Position = UDim2.new(0, 7, 0, 7)
			rar.Size = UDim2.new(0.62, -4, 0, 12)
			rar.BackgroundTransparency = 1
			rar.Font = Enum.Font.GothamBlack
			rar.TextXAlignment = Enum.TextXAlignment.Left
			rar.Text = string.upper(rarity)
			rar.TextSize = 8
			rar.TextColor3 = hiCol
			rar.ZIndex = 38
			rar.Parent = tile

			local oddsVal = tonumber(p.OddsPct) or 10
			local oddsBadge = Instance.new("TextLabel")
			oddsBadge.AnchorPoint = Vector2.new(1, 0)
			oddsBadge.Position = UDim2.new(1, -6, 0, 6)
			oddsBadge.Size = UDim2.fromOffset(30, 14)
			oddsBadge.BackgroundColor3 = Color3.fromRGB(12, 13, 18)
			oddsBadge.BackgroundTransparency = 0.2
			oddsBadge.Font = Enum.Font.GothamBold
			oddsBadge.Text = string.format("%d%%", oddsVal)
			oddsBadge.TextSize = 8
			oddsBadge.TextColor3 = hiCol
			oddsBadge.ZIndex = 38
			oddsBadge.Parent = tile
			makeCorner(oddsBadge, 3)

			-- Oversized 68x68 Studio-Lit 3D ViewportFrame Icon Box
			local iconBox = Instance.new("Frame")
			iconBox.Name = "IconBox"
			iconBox.AnchorPoint = Vector2.new(0.5, 0)
			iconBox.Position = UDim2.new(0.5, 0, 0, 24)
			iconBox.Size = UDim2.fromOffset(68, 68)
			iconBox.BackgroundColor3 = Color3.fromRGB(13, 15, 21)
			iconBox.BorderSizePixel = 0
			iconBox.ZIndex = 38
			iconBox.Parent = tile
			makeCorner(iconBox, 7)
			makeStroke(iconBox, strokeCol:Lerp(C_BORDER, 0.35), 1.1)

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
					Color3.fromRGB(13, 15, 21)
				)
				created.ZIndex = 39
				created.Visible = false
				vp = created
			end

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 5, 0, 96)
			nameLbl.Size = UDim2.new(1, -10, 0, 34)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.GothamBlack
			nameLbl.TextWrapped = true
			nameLbl.Text = tostring(p.ShortLabel or p.Title or "PRIZE")
			nameLbl.TextSize = 11
			nameLbl.TextColor3 = if rarity == "Legendary" then C_GOLD_HI else C_BONE
			nameLbl.ZIndex = 38
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

	if goldPillLbl then
		goldPillLbl.Text = string.format("%s G", formatGold(playerGold))
	end

	if eventBannerLbl then
		if snap.EventActive then
			eventBannerLbl.Text = string.format("SYNDICATE SPIN EVENT LIVE  |  %ds LEFT  |  200G DISCOUNT SPINS", tonumber(snap.EventTimeLeft) or 0)
			eventBannerLbl.TextColor3 = Color3.fromRGB(142, 224, 168)
		else
			local rem = tonumber(snap.NextFreeIn) or 0
			eventBannerLbl.Text = if snap.CanFreeSpin
				then "FREE CENTRAL MARKET SPIN READY TO CLAIM NOW"
				else string.format("NEXT FREE SPIN IN %ds  |  WIN BODYGUARDS, RARE GUNS & CRATES", rem)
			eventBannerLbl.TextColor3 = C_BRASS
		end
	end

	if statusPillLbl then
		if snap.CanFreeSpin then
			statusPillLbl.Text = if snap.IsEventFreeSpin then "EVENT FREE SPIN" else "FREE SPIN READY"
			statusPillLbl.BackgroundColor3 = C_EMERALD
			statusPillLbl.TextColor3 = C_BONE
		elseif snap.EventActive then
			statusPillLbl.Text = string.format("EVENT LIVE  %ds", tonumber(snap.EventTimeLeft) or 0)
			statusPillLbl.BackgroundColor3 = C_OXBLOOD
			statusPillLbl.TextColor3 = C_GOLD_HI
		else
			statusPillLbl.Text = string.format("SPIN: %dG", tonumber(snap.SpinCost) or 350)
			statusPillLbl.BackgroundColor3 = C_CARD
			statusPillLbl.TextColor3 = C_BRASS
		end
	end

	if spinBtn and not isSpinning then
		local cost = tonumber(snap.SpinCost) or 350
		if snap.CanFreeSpin or cost <= 0 then
			spinBtn.Text = if snap.IsEventFreeSpin then "CLAIM FREE EVENT SPIN" else "SPIN FOR FREE"
			spinBtn.BackgroundColor3 = C_EMERALD
		else
			spinBtn.Text = string.format("SPIN SYNDICATE VAULT  (%d GOLD)", cost)
			spinBtn.BackgroundColor3 = C_OXBLOOD
		end
	end

	if reelStrip and #reelStrip:GetChildren() == 0 and typeof(snap.Prizes) == "table" then
		populateReel(snap.Prizes)
	end
end

local function stopResultOrbit(): ()
	if resultOrbitConn then
		resultOrbitConn:Disconnect()
		resultOrbitConn = nil
	end
	resultOrbitCam = nil
end

local function showResultBanner(res: { [string]: any }): ()
	if not resultCard or not resultTitleLbl or not resultDetailLbl or not resultPreviewHost then return end
	latestResult = res
	stopResultOrbit()

	local rarity = tostring(res.Rarity or "Common")
	local _, strokeCol, hiCol = getRarityColors(rarity, C_BRASS)

	resultCard.Visible = true
	if resultCardStroke then
		resultCardStroke.Color = hiCol
		resultCardStroke.Thickness = if rarity == "Legendary" or rarity == "Epic" then 2.0 else 1.3
	end
	if resultRarityPill then
		resultRarityPill.Text = string.upper(rarity) .. " REWARD"
		resultRarityPill.BackgroundColor3 = strokeCol
		resultRarityPill.TextColor3 = C_BONE
	end
	resultTitleLbl.Text = string.upper(tostring(res.PrizeTitle or "SYNDICATE PRIZE"))
	resultTitleLbl.TextColor3 = hiCol
	resultDetailLbl.Text = tostring(res.Detail or "")

	if replayBtn then
		replayBtn.Visible = (rarity == "Legendary" or rarity == "Epic" or rarity == "Rare")
	end

	for _, ch in ipairs(resultPreviewHost:GetChildren()) do
		ch:Destroy()
	end
	resultPreviewVp = nil

	local pKind = tostring(res.PreviewKind or "Equipment")
	local pId = tostring(res.PreviewId or "InstantEmpireCrate")
	if isValidPreviewKind(pKind) then
		local vp = ModelPreviewHelper.CreatePreview(
			resultPreviewHost,
			pKind :: any,
			pId,
			UDim2.fromScale(1, 1),
			UDim2.new(),
			Color3.fromRGB(16, 18, 25),
			strokeCol
		)
		vp.ZIndex = 39
		resultPreviewVp = vp
		resultOrbitCam = vp.CurrentCamera
		local mdl = vp:FindFirstChildOfClass("Model")
		if mdl and resultOrbitCam then
			local bbCF, bbSz = mdl:GetBoundingBox()
			resultOrbitCenter = bbCF.Position + Vector3.new(0, bbSz.Y * 0.03, 0)
			local rel = resultOrbitCam.CFrame.Position - bbCF.Position
			local baseAng = math.atan2(rel.X, rel.Z)
			local maxDim = math.max(bbSz.X, bbSz.Y, bbSz.Z, 1.8)
			resultOrbitDist = math.max(rel.Magnitude * 1.15, maxDim * 1.55)
			resultOrbitHeight = math.max(0.45, bbSz.Y * 0.16)
			local t = 0
			resultOrbitConn = RunService.RenderStepped:Connect(function(dt: number)
				if not modal or not modal.Visible or CinematicRevealController.IsActive() or not vp.Parent or not resultOrbitCam then
					return
				end
				t += math.min(dt, 0.05)
				local ang = baseAng + math.sin(t * 1.0) * 0.55 + t * 0.32
				local cx = resultOrbitCenter.X + math.sin(ang) * resultOrbitDist
				local cz = resultOrbitCenter.Z + math.cos(ang) * resultOrbitDist
				resultOrbitCam.CFrame = CFrame.lookAt(Vector3.new(cx, resultOrbitCenter.Y + resultOrbitHeight, cz), resultOrbitCenter)
			end)
		end
	end

	updateVisibleReelViewports()
end

local function showFeaturedJackpotSpotlight(): ()
	if latestResult ~= nil then return end
	showResultBanner({
		Rarity = "Legendary",
		PrizeTitle = "FEATURED JACKPOT: ELITE BODYGUARD & RARE GUNS",
		Detail = "Spin to unlock Elite Bodyguards (6%), Black Market Firearms (6%), +550 Gold Vaults (12%), Kevlar Armor + Ammo (10%), or x12 Fresh Ingredient Crates!",
		PreviewKind = "Bodyguard",
		PreviewId = "EliteGuard",
	})
	latestResult = nil
	if resultRarityPill then
		resultRarityPill.Text = "JACKPOT SPOTLIGHT"
	end
	if replayBtn then
		replayBtn.Visible = false
	end
end

local function pulseCenterNeedle(): ()
	if needleLine then
		needleLine.BackgroundColor3 = Color3.fromRGB(255, 246, 198)
		TweenService:Create(needleLine, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = C_GOLD_HI,
		}):Play()
	end
	if topPointer then
		topPointer.BackgroundColor3 = C_GOLD_HI
		TweenService:Create(topPointer, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = C_CRIMSON_HI,
		}):Play()
	end
	if botPointer then
		botPointer.BackgroundColor3 = C_GOLD_HI
		TweenService:Create(botPointer, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = C_CRIMSON_HI,
		}):Play()
	end
end

local function runSpinAnimation(): ()
	if isSpinning or not actionFn or not reelStrip or not modal then
		return
	end
	isSpinning = true
	if spinBtn then
		spinBtn.Text = "ROLLING SYNDICATE VAULT..."
		spinBtn.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
	end
	if resultCard then
		resultCard.Visible = false
	end
	if statusLbl then
		statusLbl.Text = "Spinning Central Market Vault — watch the 24K brass laser needle!"
		statusLbl.TextColor3 = C_GOLD_HI
	end

	local ok, response = pcall(function()
		return (actionFn :: RemoteFunction):InvokeServer("SpinMarketWheel", nil)
	end)

	if not ok or typeof(response) ~= "table" or not response.Success or typeof(response.SpinResult) ~= "table" then
		isSpinning = false
		AudioController.PlayError()
		if statusLbl then
			statusLbl.TextColor3 = C_CRIMSON_HI
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
	local viewportW = REEL_WINDOW_W
	local targetTileIdx = (REEL_CYCLES - 2) * count + (winSeg - 1)
	local jitter = math.random(-28, 28)
	local targetX = -(targetTileIdx * TILE_STRIDE + TILE_W * 0.5 - viewportW * 0.5 + jitter)

	local startX = 0
	reelStrip.Position = UDim2.fromOffset(startX, 0)
	updateVisibleReelViewports(startX)

	local duration = 3.85
	local elapsed = 0
	local lastNotch = -1
	local conn: RBXScriptConnection? = nil

	conn = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += math.min(dt, 0.05)
		local u = math.clamp(elapsed / duration, 0, 1)
		-- Quintic ease-out for heart-pounding near-miss slowdown!
		local inv = 1 - u
		local ease = 1 - inv * inv * inv * inv * inv
		local curX = startX + (targetX - startX) * ease
		if reelStrip then
			local snappedX = math.floor(curX + 0.5)
			reelStrip.Position = UDim2.fromOffset(snappedX, 0)
			updateVisibleReelViewports(snappedX)
		end

		local notch = math.floor((math.abs(curX) + viewportW * 0.5) / TILE_STRIDE)
		if notch ~= lastNotch then
			lastNotch = notch
			AudioController.PlaySpinTick(u)
			pulseCenterNeedle()
		end

		if u >= 1 then
			if conn then conn:Disconnect(); conn = nil end
			isSpinning = false
			showResultBanner(res)

			if statusLbl then
				statusLbl.TextColor3 = C_BONE
				statusLbl.Text = tostring(res.Detail or "Prize awarded!")
			end
			if typeof(response.State) == "table" then
				if onStateUpdated then onStateUpdated(response.State) end
				if typeof(response.State.SpinEvent) == "table" then
					refreshSnapshotUI(response.State.SpinEvent)
				end
			end

			-- Surprise Cinematic Reveal on Legendary & Epic jackpots (plus crisp audio on Rare/Common)!
			local rarity = tostring(res.Rarity or "Common")
			if rarity == "Legendary" or rarity == "Epic" then
				CinematicRevealController.PlaySpinReveal(res)
			elseif rarity == "Rare" then
				AudioController.PlayRareRevealDrop()
			else
				AudioController.PlayCoins()
			end
		end
	end)
end

function SpinWheelController.Open(snap: { [string]: any }?): ()
	if snap then
		refreshSnapshotUI(snap)
	end
	if backdrop then
		backdrop.Visible = true
	end
	if modal then
		modal.Visible = true
		if latestResult == nil then
			showFeaturedJackpotSpotlight()
		end
		modal.Size = UDim2.fromOffset(720, 468)
		TweenService:Create(modal, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(760, 496),
		}):Play()
		updateVisibleReelViewports()
		AudioController.PlayClick()
	end
end

function SpinWheelController.Close(): ()
	if isSpinning then return end
	if backdrop then backdrop.Visible = false end
	if modal then modal.Visible = false end
	updateVisibleReelViewports()
end

function SpinWheelController.Update(state: { [string]: any }): ()
	if typeof(state.Profile) == "table" and typeof(state.Profile.Coins) == "number" then
		playerGold = state.Profile.Coins
	end
	if typeof(state.SpinEvent) == "table" then
		refreshSnapshotUI(state.SpinEvent)
	elseif goldPillLbl then
		goldPillLbl.Text = string.format("%s G", formatGold(playerGold))
	end
end

function SpinWheelController.Init(parentGui: ScreenGui, stateCallback: (any) -> ()): ()
	onStateUpdated = stateCallback

	-- Keep reel Viewports hidden cleanly whenever the full-screen CinematicRevealOverlay plays!
	CinematicRevealController.SetVisibilityChangedCallback(function(_active: boolean)
		updateVisibleReelViewports()
	end)

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

	-- Dedicated DisplayOrder = 45 ScreenGui so Roulette renders cleanly ABOVE the Hotbar & HUD,
	-- and strictly BELOW CinematicRevealGui (DisplayOrder = 100)!
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local oldGui = pg:FindFirstChild("SyndicateSpinGui")
	if oldGui then oldGui:Destroy() end
	local spinGui = Instance.new("ScreenGui")
	spinGui.Name = "SyndicateSpinGui"
	spinGui.DisplayOrder = 45
	spinGui.IgnoreGuiInset = true
	spinGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	spinGui.ResetOnSpawn = false
	spinGui.Parent = pg

	-- Soft Full-Screen Dark-Noir Dim Backdrop
	local dim = Instance.new("Frame")
	dim.Name = "SpinModalBackdrop"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(4, 5, 8)
	dim.BackgroundTransparency = 0.42
	dim.BorderSizePixel = 0
	dim.Visible = false
	dim.ZIndex = 34
	dim.Parent = spinGui
	backdrop = dim

	-- Luxury 760x496 Dual-Border Syndicate Vault Roulette Chassis
	local frame = Instance.new("Frame")
	frame.Name = "CentralMarketSpinModal"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(760, 496)
	frame.BackgroundColor3 = C_OBS
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 35
	frame.Parent = spinGui
	makeCorner(frame, 10)
	makeStroke(frame, C_BRASS, 2.0)
	modal = frame

	-- Subtle Luxury Inner Frame Highlight
	local innerRim = Instance.new("Frame")
	innerRim.Position = UDim2.fromOffset(5, 5)
	innerRim.Size = UDim2.new(1, -10, 1, -10)
	innerRim.BackgroundTransparency = 1
	innerRim.ZIndex = 35
	innerRim.Parent = frame
	makeCorner(innerRim, 7)
	makeStroke(innerRim, C_BORDER, 1, 0.45)

	-- Top Crimson-to-Gold Luxury Crown Strip
	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(1, 0, 0, 4)
	accentBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	accentBar.BorderSizePixel = 0
	accentBar.ZIndex = 36
	accentBar.Parent = frame
	local accentGrad = Instance.new("UIGradient")
	accentGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C_OXBLOOD),
		ColorSequenceKeypoint.new(0.5, C_GOLD_HI),
		ColorSequenceKeypoint.new(1, C_OXBLOOD),
	})
	accentGrad.Parent = accentBar

	-- Header Section (3D Wheel Emblem + Title + Live Gold Pill + Event Status Pill + Close)
	local headerIconHost = Instance.new("Frame")
	headerIconHost.Name = "HeaderWheelIcon"
	headerIconHost.Position = UDim2.new(0, 22, 0, 14)
	headerIconHost.Size = UDim2.fromOffset(46, 46)
	headerIconHost.BackgroundColor3 = C_PANEL
	headerIconHost.BorderSizePixel = 0
	headerIconHost.ZIndex = 36
	headerIconHost.Parent = frame
	makeCorner(headerIconHost, 8)
	makeStroke(headerIconHost, C_BRASS, 1.3)
	local hVp = ModelPreviewHelper.CreatePreview(
		headerIconHost,
		"Empire",
		"SPN",
		UDim2.fromScale(1, 1),
		UDim2.new(),
		C_PANEL
	)
	hVp.ZIndex = 37
	hVp.Visible = false
	headerPreviewVp = hVp

	local title = Instance.new("TextLabel")
	title.Position = UDim2.new(0, 78, 0, 14)
	title.Size = UDim2.fromOffset(340, 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "SYNDICATE VAULT ROULETTE"
	title.TextSize = 18
	title.TextColor3 = C_BONE
	title.ZIndex = 36
	title.Parent = frame

	local evLbl = Instance.new("TextLabel")
	evLbl.Position = UDim2.new(0, 78, 0, 40)
	evLbl.Size = UDim2.fromOffset(390, 16)
	evLbl.BackgroundTransparency = 1
	evLbl.Font = Enum.Font.GothamBold
	evLbl.TextXAlignment = Enum.TextXAlignment.Left
	evLbl.Text = "CENTRAL MARKET LUCKY SPIN  |  LEGENDARY BODYGUARDS & RARE FIREARMS"
	evLbl.TextSize = 10
	evLbl.TextColor3 = C_BRASS
	evLbl.ZIndex = 36
	evLbl.Parent = frame
	eventBannerLbl = evLbl

	-- Live Gold Balance Pill (with gleaming 24K Gold Coin Icon!)
	local gPillFrame = Instance.new("Frame")
	gPillFrame.Name = "GoldBalancePill"
	gPillFrame.AnchorPoint = Vector2.new(1, 0)
	gPillFrame.Position = UDim2.new(1, -182, 0, 18)
	gPillFrame.Size = UDim2.fromOffset(128, 28)
	gPillFrame.BackgroundColor3 = Color3.fromRGB(24, 22, 16)
	gPillFrame.BorderSizePixel = 0
	gPillFrame.ZIndex = 36
	gPillFrame.Parent = frame
	makeCorner(gPillFrame, 5)
	makeStroke(gPillFrame, C_BRASS, 1.2)
	CurrencyIconHelper.CreateGoldCoin(gPillFrame, 18, UDim2.new(0, 7, 0.5, -9), 37)
	local gPill = Instance.new("TextLabel")
	gPill.Position = UDim2.new(0, 30, 0, 0)
	gPill.Size = UDim2.new(1, -34, 1, 0)
	gPill.BackgroundTransparency = 1
	gPill.Font = Enum.Font.GothamBlack
	gPill.TextXAlignment = Enum.TextXAlignment.Left
	gPill.Text = "0G"
	gPill.TextSize = 11
	gPill.TextColor3 = C_GOLD_HI
	gPill.ZIndex = 37
	gPill.Parent = gPillFrame
	goldPillLbl = gPill

	-- Live Free / Event Status Pill
	local stPill = Instance.new("TextLabel")
	stPill.Name = "SpinStatusPill"
	stPill.AnchorPoint = Vector2.new(1, 0)
	stPill.Position = UDim2.new(1, -56, 0, 18)
	stPill.Size = UDim2.fromOffset(118, 28)
	stPill.BackgroundColor3 = C_CARD
	stPill.Font = Enum.Font.GothamBlack
	stPill.Text = "SPIN: 350G"
	stPill.TextSize = 10
	stPill.TextColor3 = C_BRASS
	stPill.ZIndex = 36
	stPill.Parent = frame
	makeCorner(stPill, 5)
	makeStroke(stPill, C_BORDER, 1)
	statusPillLbl = stPill

	local closeBtn = Instance.new("TextButton")
	closeBtn.Position = UDim2.new(1, -46, 0, 18)
	closeBtn.Size = UDim2.fromOffset(28, 28)
	closeBtn.BackgroundColor3 = C_CARD
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.Text = "X"
	closeBtn.TextSize = 12
	closeBtn.TextColor3 = C_BONE
	closeBtn.ZIndex = 36
	closeBtn.Parent = frame
	makeCorner(closeBtn, 5)
	makeStroke(closeBtn, C_BORDER, 1)
	closeBtn.MouseButton1Click:Connect(function()
		SpinWheelController.Close()
	end)

	-- =========================================================================
	-- OVERSIZED 716x148 LUXURY ROULETTE WINDOW WITH EDGE VIGNETTES & LASER NEEDLE
	-- =========================================================================
	local reelWindow = Instance.new("Frame")
	reelWindow.Name = "ReelWindow"
	reelWindow.Position = UDim2.new(0, 22, 0, 72)
	reelWindow.Size = UDim2.fromOffset(REEL_WINDOW_W, REEL_WINDOW_H)
	reelWindow.BackgroundColor3 = Color3.fromRGB(7, 8, 12)
	reelWindow.ClipsDescendants = true
	reelWindow.ZIndex = 36
	reelWindow.Parent = frame
	makeCorner(reelWindow, 8)
	makeStroke(reelWindow, C_BRASS, 1.5, 0.25)

	local strip = Instance.new("Frame")
	strip.Name = "ReelStrip"
	strip.Position = UDim2.fromOffset(0, 0)
	strip.Size = UDim2.fromOffset(REEL_WINDOW_W, REEL_WINDOW_H - 2)
	strip.BackgroundTransparency = 1
	strip.ZIndex = 37
	strip.Parent = reelWindow
	reelStrip = strip

	-- Smooth Left & Right Dark Vignette Shadows
	local vigL = Instance.new("Frame")
	vigL.Size = UDim2.new(0, 76, 1, 0)
	vigL.Position = UDim2.new(0, 0, 0, 0)
	vigL.BackgroundColor3 = Color3.fromRGB(6, 7, 10)
	vigL.BorderSizePixel = 0
	vigL.ZIndex = 41
	vigL.Parent = reelWindow
	local vigLGrad = Instance.new("UIGradient")
	vigLGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.55, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	vigLGrad.Parent = vigL

	local vigR = Instance.new("Frame")
	vigR.AnchorPoint = Vector2.new(1, 0)
	vigR.Size = UDim2.new(0, 76, 1, 0)
	vigR.Position = UDim2.fromScale(1, 0)
	vigR.BackgroundColor3 = Color3.fromRGB(6, 7, 10)
	vigR.BorderSizePixel = 0
	vigR.ZIndex = 41
	vigR.Parent = reelWindow
	local vigRGrad = Instance.new("UIGradient")
	vigRGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.45, 0.55),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	vigRGrad.Parent = vigR

	-- Center 24K Brass Laser Selector Needle + Top & Bottom Crimson-Gold Diamond Pointers
	local needle = Instance.new("Frame")
	needle.Name = "CenterLaserNeedle"
	needle.AnchorPoint = Vector2.new(0.5, 0)
	needle.Position = UDim2.fromScale(0.5, 0)
	needle.Size = UDim2.new(0, 3, 1, 0)
	needle.BackgroundColor3 = C_GOLD_HI
	needle.BorderSizePixel = 0
	needle.ZIndex = 43
	needle.Parent = reelWindow
	needleLine = needle

	local topNotch = Instance.new("Frame")
	topNotch.AnchorPoint = Vector2.new(0.5, 0.5)
	topNotch.Position = UDim2.new(0.5, 0, 0, 3)
	topNotch.Size = UDim2.fromOffset(14, 14)
	topNotch.Rotation = 45
	topNotch.BackgroundColor3 = C_CRIMSON_HI
	topNotch.BorderSizePixel = 0
	topNotch.ZIndex = 44
	topNotch.Parent = reelWindow
	makeStroke(topNotch, C_GOLD_HI, 1.4)
	topPointer = topNotch

	local botNotch = Instance.new("Frame")
	botNotch.AnchorPoint = Vector2.new(0.5, 0.5)
	botNotch.Position = UDim2.new(0.5, 0, 1, -3)
	botNotch.Size = UDim2.fromOffset(14, 14)
	botNotch.Rotation = 45
	botNotch.BackgroundColor3 = C_CRIMSON_HI
	botNotch.BorderSizePixel = 0
	botNotch.ZIndex = 44
	botNotch.Parent = reelWindow
	makeStroke(botNotch, C_GOLD_HI, 1.4)
	botPointer = botNotch

	-- 8-Prize Drop Odds & Jackpot Legend Strip
	local lHost = Instance.new("Frame")
	lHost.Name = "OddsLegendStrip"
	lHost.Position = UDim2.new(0, 22, 0, 228)
	lHost.Size = UDim2.fromOffset(REEL_WINDOW_W, 28)
	lHost.BackgroundTransparency = 1
	lHost.ZIndex = 36
	lHost.Parent = frame
	legendHost = lHost

	-- Upgraded Beveled Luxury SPIN Action Button
	local sBtn = Instance.new("TextButton")
	sBtn.Name = "SpinActionBtn"
	sBtn.AnchorPoint = Vector2.new(0.5, 0)
	sBtn.Position = UDim2.new(0.5, 0, 0, 268)
	sBtn.Size = UDim2.fromOffset(320, 44)
	sBtn.BackgroundColor3 = C_OXBLOOD
	sBtn.Font = Enum.Font.GothamBlack
	sBtn.Text = "SPIN SYNDICATE VAULT  (350 GOLD)"
	sBtn.TextSize = 14
	sBtn.TextColor3 = C_BONE
	sBtn.ZIndex = 37
	sBtn.Parent = frame
	makeCorner(sBtn, 6)
	makeStroke(sBtn, C_GOLD_HI, 1.6)
	local sBtnGrad = Instance.new("UIGradient")
	sBtnGrad.Rotation = 90
	sBtnGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 185, 195)),
	})
	sBtnGrad.Parent = sBtn
	sBtn.MouseButton1Click:Connect(runSpinAnimation)
	spinBtn = sBtn

	local stLbl = Instance.new("TextLabel")
	stLbl.Position = UDim2.new(0, 22, 0, 320)
	stLbl.Size = UDim2.new(1, -44, 0, 18)
	stLbl.BackgroundTransparency = 1
	stLbl.Font = Enum.Font.GothamMedium
	stLbl.Text = "Land on Legendary Bodyguards (6%) or Epic Firearms (6%) for the Full Vault Breach Reveal!"
	stLbl.TextSize = 11
	stLbl.TextColor3 = C_ASH
	stLbl.ZIndex = 36
	stLbl.Parent = frame
	statusLbl = stLbl

	-- Expanded Bottom Prize Showcase Banner (with 96x96 Orbiting 3D ViewportFrame!)
	local rCard = Instance.new("Frame")
	rCard.Name = "ResultCard"
	rCard.Position = UDim2.new(0, 22, 0, 348)
	rCard.Size = UDim2.fromOffset(REEL_WINDOW_W, 126)
	rCard.BackgroundColor3 = C_PANEL
	rCard.Visible = false
	rCard.ZIndex = 36
	rCard.Parent = frame
	makeCorner(rCard, 8)
	resultCardStroke = makeStroke(rCard, C_BRASS, 1.5)
	resultCard = rCard

	local pHost = Instance.new("Frame")
	pHost.Name = "OrbitPreviewHost"
	pHost.Position = UDim2.new(0, 14, 0, 14)
	pHost.Size = UDim2.fromOffset(98, 98)
	pHost.BackgroundColor3 = Color3.fromRGB(16, 18, 25)
	pHost.ZIndex = 37
	pHost.Parent = rCard
	makeCorner(pHost, 8)
	makeStroke(pHost, C_BRASS, 1.2)
	resultPreviewHost = pHost

	local rPill = Instance.new("TextLabel")
	rPill.Position = UDim2.new(0, 128, 0, 16)
	rPill.Size = UDim2.fromOffset(152, 20)
	rPill.BackgroundColor3 = C_BRASS
	rPill.Font = Enum.Font.GothamBlack
	rPill.Text = "LEGENDARY REWARD"
	rPill.TextSize = 9
	rPill.TextColor3 = C_BONE
	rPill.ZIndex = 37
	rPill.Parent = rCard
	makeCorner(rPill, 4)
	resultRarityPill = rPill

	local rtLbl = Instance.new("TextLabel")
	rtLbl.Position = UDim2.new(0, 128, 0, 42)
	rtLbl.Size = UDim2.new(1, -280, 0, 26)
	rtLbl.BackgroundTransparency = 1
	rtLbl.Font = Enum.Font.GothamBlack
	rtLbl.TextXAlignment = Enum.TextXAlignment.Left
	rtLbl.TextSize = 18
	rtLbl.TextColor3 = C_GOLD_HI
	rtLbl.Text = ""
	rtLbl.ZIndex = 37
	rtLbl.Parent = rCard
	resultTitleLbl = rtLbl

	local rdLbl = Instance.new("TextLabel")
	rdLbl.Position = UDim2.new(0, 128, 0, 72)
	rdLbl.Size = UDim2.new(1, -280, 0, 42)
	rdLbl.BackgroundTransparency = 1
	rdLbl.Font = Enum.Font.Gotham
	rdLbl.TextWrapped = true
	rdLbl.TextXAlignment = Enum.TextXAlignment.Left
	rdLbl.TextYAlignment = Enum.TextYAlignment.Top
	rdLbl.TextSize = 12
	rdLbl.TextColor3 = C_BONE
	rdLbl.Text = ""
	rdLbl.ZIndex = 37
	rdLbl.Parent = rCard
	resultDetailLbl = rdLbl

	local repBtn = Instance.new("TextButton")
	repBtn.Name = "ReplayRevealBtn"
	repBtn.AnchorPoint = Vector2.new(1, 0.5)
	repBtn.Position = UDim2.new(1, -16, 0.5, 0)
	repBtn.Size = UDim2.fromOffset(128, 34)
	repBtn.BackgroundColor3 = C_CARD
	repBtn.Font = Enum.Font.GothamBlack
	repBtn.Text = "REPLAY REVEAL"
	repBtn.TextSize = 10
	repBtn.TextColor3 = C_GOLD_HI
	repBtn.Visible = false
	repBtn.ZIndex = 38
	repBtn.Parent = rCard
	makeCorner(repBtn, 5)
	makeStroke(repBtn, C_BRASS, 1.2)
	repBtn.MouseButton1Click:Connect(function()
		if latestResult then
			CinematicRevealController.PlaySpinReveal(latestResult)
		end
	end)
	replayBtn = repBtn
end

return SpinWheelController
