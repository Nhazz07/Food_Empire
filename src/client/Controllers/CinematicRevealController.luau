--!strict

-- CinematicRevealController: AAA dark-noir full-screen cinematic reveal & unit welcome system.
-- Powers:
--  1. Legendary & Epic Central Market Lucky Spin Vault Breach (trembling obsidian vault doors,
--     24K gold/crimson fractures, 0.075s anime impact frame, volumetric sunbeams, double shockwaves,
--     300x300 orbiting 3D ViewportFrame showcase, animated stat bars & surprise bass/gong drop!)
--  2. Hired Ninja Assassin Welcome (Crimson Eclipse moon, kunai streak barrage, silver X-slash
--     impact frame, smoke rings, orbiting 3D R15 Ninja Assassin & surprise katana/whoosh SFX!)
--  3. Hired Samurai Mafia Welcome (Shogun crest halo, drifting sakura petals, blazing crescent
--     iaijutsu slash impact frame, orbiting 3D R15 Samurai & gong/unsheathe SFX!)
--  4. Recruited Bodyguard Welcome (Syndicate brass spotlight, rotating crest ring, exact R15
--     Bodyguard class showcase, live combat stats & tactical rack/fanfare SFX!)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioController = require("./AudioController")
local ModelPreviewHelper = require("./ModelPreviewHelper")
local BodyguardConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("BodyguardConfig")
)
local WeaponConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WeaponConfig")
)

export type StatRow = {
	Label: string,
	Value: string,
	Pct: number,
}

export type RevealPayload = {
	Theme: "Legendary" | "Epic" | "Rare" | "Ninja" | "Samurai" | "Bodyguard",
	Badge: string,
	Title: string,
	Subtitle: string,
	ButtonText: string?,
	PreviewKind: string,
	PreviewId: string,
	Stats: { StatRow }?,
}

local CinematicRevealController = {}

local C_OBS = Color3.fromRGB(9, 10, 14)
local C_PANEL = Color3.fromRGB(16, 18, 24)
local C_BRASS = Color3.fromRGB(214, 174, 88)
local C_GOLD_HI = Color3.fromRGB(255, 226, 134)
local C_OXBLOOD = Color3.fromRGB(168, 34, 46)
local C_CRIMSON_HI = Color3.fromRGB(238, 68, 82)
local C_SILVER = Color3.fromRGB(204, 218, 242)
local C_BONE = Color3.fromRGB(242, 238, 230)
local C_ASH = Color3.fromRGB(166, 172, 184)
local C_SAKURA = Color3.fromRGB(242, 162, 184)

local overlayRoot: Frame? = nil
local activeConn: RBXScriptConnection? = nil
local activeToken = 0
local isActive = false
local visibilityCb: ((boolean) -> ())? = nil
local savedCameraFov: number? = nil

function CinematicRevealController.SetVisibilityChangedCallback(cb: (boolean) -> ()): ()
	visibilityCb = cb
end

function CinematicRevealController.IsActive(): boolean
	return isActive
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

local function triggerCameraPunch(fovBoost: number, shakeDuration: number, shakeIntensity: number): ()
	local cam = Workspace.CurrentCamera
	if not cam then return end
	if savedCameraFov == nil then
		savedCameraFov = cam.FieldOfView
	end
	local baseFov = savedCameraFov or 70
	cam.FieldOfView = math.clamp(baseFov + fovBoost, 55, 96)
	TweenService:Create(cam, TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
		FieldOfView = baseFov,
	}):Play()

	if overlayRoot then
		local root = overlayRoot
		local t0 = os.clock()
		task.spawn(function()
			while os.clock() - t0 < shakeDuration do
				if not root.Parent or not isActive then break end
				local decay = 1 - ((os.clock() - t0) / shakeDuration)
				local mag = shakeIntensity * decay * decay
				root.Position = UDim2.fromOffset(
					math.floor((math.random() * 2 - 1) * mag),
					math.floor((math.random() * 2 - 1) * mag)
				)
				RunService.RenderStepped:Wait()
			end
			if root.Parent then
				root.Position = UDim2.new()
			end
		end)
	end
end

local function closeReveal(): ()
	activeToken += 1
	if activeConn then
		activeConn:Disconnect()
		activeConn = nil
	end
	if overlayRoot then
		overlayRoot.Visible = false
		overlayRoot.Position = UDim2.new()
		for _, ch in ipairs(overlayRoot:GetChildren()) do
			ch:Destroy()
		end
	end
	local cam = Workspace.CurrentCamera
	if cam and savedCameraFov ~= nil then
		cam.FieldOfView = savedCameraFov
		savedCameraFov = nil
	end
	if isActive then
		isActive = false
		if visibilityCb then
			visibilityCb(false)
		end
	end
end

local function getThemePalette(theme: string): (Color3, Color3, Color3)
	if theme == "Legendary" then
		return C_BRASS, C_GOLD_HI, Color3.fromRGB(26, 20, 10)
	elseif theme == "Epic" then
		return C_OXBLOOD, C_CRIMSON_HI, Color3.fromRGB(28, 11, 15)
	elseif theme == "Ninja" then
		return C_OXBLOOD, C_SILVER, Color3.fromRGB(16, 12, 22)
	elseif theme == "Samurai" then
		return C_OXBLOOD, C_GOLD_HI, Color3.fromRGB(26, 12, 14)
	elseif theme == "Bodyguard" then
		return C_BRASS, C_GOLD_HI, Color3.fromRGB(16, 20, 28)
	end
	return Color3.fromRGB(84, 142, 198), Color3.fromRGB(174, 214, 250), Color3.fromRGB(12, 18, 28)
end

function CinematicRevealController.Play(payload: RevealPayload): ()
	if not overlayRoot then return end
	closeReveal()

	activeToken += 1
	local myToken = activeToken
	isActive = true
	if visibilityCb then
		visibilityCb(true)
	end

	local root = overlayRoot
	root.Visible = true
	root.BackgroundColor3 = Color3.fromRGB(4, 5, 8)
	root.BackgroundTransparency = 1

	local theme = payload.Theme
	local primaryCol, glowCol, tintBg = getThemePalette(theme)

	-- Soft Dark Backdrop Fade-In
	TweenService:Create(root, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.14,
	}):Play()

	-- Radial Glow Backdrop Card (soft ambient theater vignette)
	local bgGlow = Instance.new("Frame")
	bgGlow.Name = "BackdropGlow"
	bgGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	bgGlow.Position = UDim2.fromScale(0.5, 0.48)
	bgGlow.Size = UDim2.fromOffset(660, 660)
	bgGlow.BackgroundColor3 = tintBg
	bgGlow.BackgroundTransparency = 0.25
	bgGlow.BorderSizePixel = 0
	bgGlow.ZIndex = 81
	bgGlow.Parent = root
	makeCorner(bgGlow, 330)
	makeStroke(bgGlow, primaryCol, 2, 0.55)

	-- Cinema Letterbox Bars (Top & Bottom — iconic movie presentation)
	local topBar = Instance.new("Frame")
	topBar.Name = "LetterboxTop"
	topBar.Size = UDim2.new(1, 0, 0, 0)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(4, 4, 7)
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 96
	topBar.Parent = root
	local topRule = Instance.new("Frame")
	topRule.AnchorPoint = Vector2.new(0, 1)
	topRule.Position = UDim2.fromScale(0, 1)
	topRule.Size = UDim2.new(1, 0, 0, 2)
	topRule.BackgroundColor3 = primaryCol
	topRule.BorderSizePixel = 0
	topRule.ZIndex = 97
	topRule.Parent = topBar

	local botBar = Instance.new("Frame")
	botBar.Name = "LetterboxBottom"
	botBar.AnchorPoint = Vector2.new(0, 1)
	botBar.Position = UDim2.fromScale(0, 1)
	botBar.Size = UDim2.new(1, 0, 0, 0)
	botBar.BackgroundColor3 = Color3.fromRGB(4, 4, 7)
	botBar.BorderSizePixel = 0
	botBar.ZIndex = 96
	botBar.Parent = root
	local botRule = Instance.new("Frame")
	botRule.Size = UDim2.new(1, 0, 0, 2)
	botRule.BackgroundColor3 = primaryCol
	botRule.BorderSizePixel = 0
	botRule.ZIndex = 97
	botRule.Parent = botBar

	TweenService:Create(topBar, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 0, 52),
	}):Play()
	TweenService:Create(botBar, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 0, 52),
	}):Play()

	-- Stage Container (holds sunbeams, shockwaves, moon, showcase hero & stat card)
	local stage = Instance.new("Frame")
	stage.Name = "ShowcaseStage"
	stage.Size = UDim2.fromScale(1, 1)
	stage.BackgroundTransparency = 1
	stage.ZIndex = 82
	stage.Parent = root

	-- Rotating Volumetric Sunbeams Container (12 angled light shafts behind the hero!)
	local beamHub = Instance.new("Frame")
	beamHub.Name = "SunbeamHub"
	beamHub.AnchorPoint = Vector2.new(0.5, 0.5)
	beamHub.Position = UDim2.fromScale(0.5, 0.42)
	beamHub.Size = UDim2.fromOffset(10, 10)
	beamHub.BackgroundTransparency = 1
	beamHub.Visible = false
	beamHub.ZIndex = 83
	beamHub.Parent = stage

	local beamParts: { Frame } = {}
	for i = 1, 12 do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(if i % 2 == 0 then 28 else 14, 760)
		ray.Rotation = (i - 1) * 30
		ray.BackgroundColor3 = if i % 2 == 0 then glowCol else primaryCol
		ray.BackgroundTransparency = 0.84
		ray.BorderSizePixel = 0
		ray.ZIndex = 83
		ray.Parent = beamHub
		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.32, 0.52),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(0.68, 0.52),
			NumberSequenceKeypoint.new(1, 1),
		})
		grad.Parent = ray
		table.insert(beamParts, ray)
	end

	-- Theme-Specific Backdrop Symbol (Crimson Full Moon for Ninja, Syndicate Crest Ring for Samurai/Bodyguard/Spin)
	local emblemRing = Instance.new("Frame")
	emblemRing.Name = "EmblemRing"
	emblemRing.AnchorPoint = Vector2.new(0.5, 0.5)
	emblemRing.Position = UDim2.fromScale(0.5, 0.41)
	emblemRing.Size = UDim2.fromOffset(310, 310)
	emblemRing.BackgroundColor3 = if theme == "Ninja" then Color3.fromRGB(164, 24, 34) else C_OBS
	emblemRing.BackgroundTransparency = if theme == "Ninja" then 0.22 else 0.72
	emblemRing.Visible = false
	emblemRing.BorderSizePixel = 0
	emblemRing.ZIndex = 84
	emblemRing.Parent = stage
	makeCorner(emblemRing, 155)
	makeStroke(emblemRing, glowCol, if theme == "Ninja" then 4 else 2.5, 0.18)

	if theme == "Ninja" then
		-- Dark Eclipse Shadow cutting across the Crimson Moon!
		local eclipseCut = Instance.new("Frame")
		eclipseCut.AnchorPoint = Vector2.new(0.5, 0.5)
		eclipseCut.Position = UDim2.fromScale(0.58, 0.45)
		eclipseCut.Size = UDim2.fromOffset(252, 252)
		eclipseCut.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
		eclipseCut.BackgroundTransparency = 0.08
		eclipseCut.BorderSizePixel = 0
		eclipseCut.ZIndex = 85
		eclipseCut.Parent = emblemRing
		makeCorner(eclipseCut, 126)
	end

	-- Live 3D Orbiting Hero Portrait Showcase Frame (clean rounded portrait card — zero square-in-circle clipping!)
	local heroShell = Instance.new("Frame")
	heroShell.Name = "Hero3DShell"
	heroShell.AnchorPoint = Vector2.new(0.5, 0.5)
	heroShell.Position = UDim2.fromScale(0.5, 0.37)
	heroShell.Size = UDim2.fromOffset(244, 268)
	heroShell.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
	heroShell.BackgroundTransparency = 0.08
	heroShell.Visible = false
	heroShell.ZIndex = 86
	heroShell.Parent = stage
	makeCorner(heroShell, 12)
	makeStroke(heroShell, glowCol, 2.4, 0.08)

	local heroTopBar = Instance.new("Frame")
	heroTopBar.Size = UDim2.new(1, 0, 0, 3)
	heroTopBar.BackgroundColor3 = glowCol
	heroTopBar.BorderSizePixel = 0
	heroTopBar.ZIndex = 88
	heroTopBar.Parent = heroShell

	local heroViewport: ViewportFrame? = nil
	local orbitCam: Camera? = nil
	local orbitCenter = Vector3.new(0, 0, 0)
	local orbitDist = 9.5
	local orbitHeight = 1.2
	local baseOrbitAngle = math.pi

	if isValidPreviewKind(payload.PreviewKind) then
		local vp = ModelPreviewHelper.CreatePreview(
			heroShell,
			payload.PreviewKind :: any,
			payload.PreviewId,
			UDim2.new(1, -12, 1, -12),
			UDim2.fromOffset(6, 6),
			Color3.fromRGB(10, 12, 18),
			primaryCol
		)
		vp.BackgroundTransparency = 0.06
		vp.Ambient = Color3.fromRGB(190, 194, 208)
		vp.LightColor = Color3.fromRGB(255, 244, 224)
		vp.ZIndex = 87
		makeCorner(vp, 8)
		heroViewport = vp
		orbitCam = vp.CurrentCamera
		local mdl = vp:FindFirstChildOfClass("Model")
		if mdl then
			local bbCF, bbSz = mdl:GetBoundingBox()
			orbitCenter = bbCF.Position + Vector3.new(0, bbSz.Y * 0.03, 0)
			local maxDim = math.max(bbSz.X, bbSz.Y, bbSz.Z, 2.2)
			if orbitCam then
				orbitCam.FieldOfView = 38
				local rel = orbitCam.CFrame.Position - bbCF.Position
				-- Preserve the model's exact front-facing azimuth from ModelPreviewHelper, pulled back for full head-to-toe hero framing!
				baseOrbitAngle = math.atan2(rel.X, rel.Z)
				orbitDist = math.max(rel.Magnitude * 1.18, maxDim * 1.68)
				orbitHeight = math.max(0.65, bbSz.Y * 0.16)
				local sx = orbitCenter.X + math.sin(baseOrbitAngle) * orbitDist
				local sz = orbitCenter.Z + math.cos(baseOrbitAngle) * orbitDist
				orbitCam.CFrame = CFrame.lookAt(Vector3.new(sx, orbitCenter.Y + orbitHeight, sz), orbitCenter)
			end
		end
	end

	-- Holographic Dark-Noir Info & Animated Stat Card (cleanly positioned well above bottom letterbox!)
	local infoCard = Instance.new("Frame")
	infoCard.Name = "RevealInfoCard"
	infoCard.AnchorPoint = Vector2.new(0.5, 0)
	infoCard.Position = UDim2.new(0.5, 0, 0.59, 26)
	infoCard.Size = UDim2.fromOffset(580, 182)
	infoCard.BackgroundColor3 = C_PANEL
	infoCard.BackgroundTransparency = 0.04
	infoCard.Visible = false
	infoCard.ZIndex = 89
	infoCard.Parent = stage
	makeCorner(infoCard, 8)
	makeStroke(infoCard, primaryCol, 1.8, 0.08)

	local cardAccent = Instance.new("Frame")
	cardAccent.Size = UDim2.new(1, 0, 0, 3)
	cardAccent.BackgroundColor3 = glowCol
	cardAccent.BorderSizePixel = 0
	cardAccent.ZIndex = 90
	cardAccent.Parent = infoCard

	local badgeLbl = Instance.new("TextLabel")
	badgeLbl.AnchorPoint = Vector2.new(0.5, 0)
	badgeLbl.Position = UDim2.new(0.5, 0, 0, 10)
	badgeLbl.Size = UDim2.fromOffset(380, 20)
	badgeLbl.BackgroundColor3 = primaryCol
	badgeLbl.BackgroundTransparency = 0.22
	badgeLbl.Font = Enum.Font.GothamBlack
	badgeLbl.Text = string.upper(payload.Badge)
	badgeLbl.TextSize = 10
	badgeLbl.TextColor3 = C_BONE
	badgeLbl.ZIndex = 90
	badgeLbl.Parent = infoCard
	makeCorner(badgeLbl, 4)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Position = UDim2.new(0, 16, 0, 34)
	titleLbl.Size = UDim2.new(1, -32, 0, 28)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBlack
	titleLbl.Text = string.upper(payload.Title)
	titleLbl.TextSize = 21
	titleLbl.TextColor3 = glowCol
	titleLbl.ZIndex = 90
	titleLbl.Parent = infoCard

	local subLbl = Instance.new("TextLabel")
	subLbl.Position = UDim2.new(0, 18, 0, 62)
	subLbl.Size = UDim2.new(1, -36, 0, 18)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = Enum.Font.GothamMedium
	subLbl.Text = payload.Subtitle
	subLbl.TextSize = 11
	subLbl.TextColor3 = C_ASH
	subLbl.ZIndex = 90
	subLbl.Parent = infoCard

	-- Animated Stat Bars (3 crisp side-by-side holographic bars!)
	local statFills: { { Fill: Frame, TargetPct: number } } = {}
	local stats = payload.Stats
	if stats and #stats > 0 then
		local count = math.min(3, #stats)
		local rowW = math.floor((524 - (count - 1) * 12) / count)
		for i = 1, count do
			local st = stats[i]
			local box = Instance.new("Frame")
			box.Position = UDim2.fromOffset(18 + (i - 1) * (rowW + 12), 86)
			box.Size = UDim2.fromOffset(rowW, 38)
			box.BackgroundColor3 = Color3.fromRGB(11, 13, 18)
			box.BorderSizePixel = 0
			box.ZIndex = 90
			box.Parent = infoCard
			makeCorner(box, 5)
			makeStroke(box, primaryCol, 1, 0.62)

			local sl = Instance.new("TextLabel")
			sl.Position = UDim2.fromOffset(8, 4)
			sl.Size = UDim2.new(0.58, -8, 0, 14)
			sl.BackgroundTransparency = 1
			sl.Font = Enum.Font.GothamBold
			sl.TextXAlignment = Enum.TextXAlignment.Left
			sl.Text = string.upper(st.Label)
			sl.TextSize = 9
			sl.TextColor3 = C_ASH
			sl.ZIndex = 91
			sl.Parent = box

			local sv = Instance.new("TextLabel")
			sv.Position = UDim2.new(0.55, 0, 0, 4)
			sv.Size = UDim2.new(0.45, -8, 0, 14)
			sv.BackgroundTransparency = 1
			sv.Font = Enum.Font.GothamBlack
			sv.TextXAlignment = Enum.TextXAlignment.Right
			sv.Text = st.Value
			sv.TextSize = 10
			sv.TextColor3 = C_BONE
			sv.ZIndex = 91
			sv.Parent = box

			local barBg = Instance.new("Frame")
			barBg.Position = UDim2.new(0, 8, 0, 24)
			barBg.Size = UDim2.new(1, -16, 0, 7)
			barBg.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
			barBg.BorderSizePixel = 0
			barBg.ZIndex = 91
			barBg.Parent = box
			makeCorner(barBg, 3)

			local barFill = Instance.new("Frame")
			barFill.Size = UDim2.fromScale(0, 1)
			barFill.BackgroundColor3 = glowCol
			barFill.BorderSizePixel = 0
			barFill.ZIndex = 92
			barFill.Parent = barBg
			makeCorner(barFill, 3)

			table.insert(statFills, { Fill = barFill, TargetPct = math.clamp(st.Pct, 0.08, 1) })
		end
	end

	-- Collect / Dismiss Action Button
	local closeActionBtn = Instance.new("TextButton")
	closeActionBtn.Name = "CollectBtn"
	closeActionBtn.AnchorPoint = Vector2.new(0.5, 1)
	closeActionBtn.Position = UDim2.new(0.5, 0, 1, -10)
	closeActionBtn.Size = UDim2.fromOffset(230, 34)
	closeActionBtn.BackgroundColor3 = primaryCol
	closeActionBtn.Font = Enum.Font.GothamBlack
	closeActionBtn.Text = string.upper(payload.ButtonText or "COLLECT & DEPLOY")
	closeActionBtn.TextSize = 12
	closeActionBtn.TextColor3 = C_BONE
	closeActionBtn.ZIndex = 92
	closeActionBtn.Parent = infoCard
	makeCorner(closeActionBtn, 5)
	makeStroke(closeActionBtn, glowCol, 1.3, 0.15)
	closeActionBtn.MouseButton1Click:Connect(function()
		AudioController.PlayClick()
		closeReveal()
	end)

	-- Floating Ambient Particles (Embers for Legendary/Epic/Bodyguard, Sakura Petals for Samurai, Silver Sparks for Ninja)
	type ParticleItem = {
		Frame: Frame,
		X: number,
		Y: number,
		VX: number,
		VY: number,
		RotSpeed: number,
	}
	local particles: { ParticleItem } = {}
	local function spawnAmbientParticles(): ()
		local isSakura = (theme == "Samurai")
		local pCount = 26
		for _ = 1, pCount do
			local f = Instance.new("Frame")
			local sz = if isSakura then math.random(7, 13) else math.random(4, 8)
			f.Size = if isSakura then UDim2.fromOffset(sz, math.floor(sz * 0.58)) else UDim2.fromOffset(sz, sz)
			f.BackgroundColor3 = if isSakura
				then (if math.random() < 0.7 then C_SAKURA else C_GOLD_HI)
				elseif theme == "Ninja" then (if math.random() < 0.6 then C_SILVER else C_CRIMSON_HI)
				else glowCol
			f.BackgroundTransparency = 0.15 + math.random() * 0.35
			f.BorderSizePixel = 0
			f.ZIndex = 88
			f.Parent = stage
			makeCorner(f, if isSakura then 5 else 4)

			local sx = math.random()
			local sy = if isSakura then -0.05 - math.random() * 0.5 else 0.35 + math.random() * 0.55
			f.Position = UDim2.fromScale(sx, sy)
			table.insert(particles, {
				Frame = f,
				X = sx,
				Y = sy,
				VX = if isSakura then (0.08 + math.random() * 0.14) else ((math.random() - 0.5) * 0.22),
				VY = if isSakura then (0.18 + math.random() * 0.20) else (-0.16 - math.random() * 0.26),
				RotSpeed = (math.random() - 0.5) * 260,
			})
		end
	end

	-- Shockwave Ring Spawner
	local function fireShockwave(col: Color3, startSz: number, endSz: number, dur: number, delaySec: number): ()
		task.delay(delaySec, function()
			if activeToken ~= myToken or not stage.Parent then return end
			local ring = Instance.new("Frame")
			ring.AnchorPoint = Vector2.new(0.5, 0.5)
			ring.Position = UDim2.fromScale(0.5, 0.41)
			ring.Size = UDim2.fromOffset(startSz, startSz)
			ring.BackgroundTransparency = 1
			ring.ZIndex = 93
			ring.Parent = stage
			makeCorner(ring, math.floor(endSz * 0.5))
			local st = makeStroke(ring, col, 6, 0)

			TweenService:Create(ring, TweenInfo.new(dur, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(endSz, endSz),
			}):Play()
			TweenService:Create(st, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Thickness = 1,
				Transparency = 1,
			}):Play()
			task.delay(dur + 0.05, function()
				if ring.Parent then ring:Destroy() end
			end)
		end)
	end

	-- Full-Screen High-Contrast Anime Impact Frame Flash (0.075s!)
	local function fireImpactFlash(flashCol: Color3, slashStyle: "None" | "X" | "Crescent"): ()
		if activeToken ~= myToken or not root.Parent then return end
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = flashCol
		flash.BackgroundTransparency = 0.08
		flash.BorderSizePixel = 0
		flash.ZIndex = 98
		flash.Parent = root

		if slashStyle == "X" or slashStyle == "Crescent" then
			local angles = if slashStyle == "X" then { -34, 34 } else { -24 }
			for _, ang in ipairs(angles) do
				local cut = Instance.new("Frame")
				cut.AnchorPoint = Vector2.new(0.5, 0.5)
				cut.Position = UDim2.fromScale(0.5, 0.44)
				cut.Size = UDim2.new(1.5, 0, 0, if slashStyle == "Crescent" then 26 else 14)
				cut.Rotation = ang
				cut.BackgroundColor3 = if slashStyle == "Crescent" then C_GOLD_HI else Color3.fromRGB(255, 255, 255)
				cut.BorderSizePixel = 0
				cut.ZIndex = 99
				cut.Parent = root
				TweenService:Create(cut, TweenInfo.new(0.28, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
					Size = UDim2.new(1.5, 0, 0, 0),
					BackgroundTransparency = 1,
				}):Play()
				task.delay(0.32, function()
					if cut.Parent then cut:Destroy() end
				end)
			end
		end

		TweenService:Create(flash, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.26, function()
			if flash.Parent then flash:Destroy() end
		end)
	end

	-- Function that reveals the orbiting 3D hero + sunbeams + animated stat card!
	local function revealHeroStage(): ()
		if activeToken ~= myToken or not stage.Parent then return end

		beamHub.Visible = true
		emblemRing.Visible = true
		heroShell.Visible = true
		infoCard.Visible = true

		heroShell.Size = UDim2.fromOffset(70, 76)
		TweenService:Create(heroShell, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(244, 268),
		}):Play()

		emblemRing.Size = UDim2.fromOffset(90, 90)
		TweenService:Create(emblemRing, TweenInfo.new(0.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(336, 336),
		}):Play()

		TweenService:Create(infoCard, TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.59, 0),
		}):Play()

		-- Animate stat bars sweeping smoothly from 0% to target!
		for idx, item in ipairs(statFills) do
			task.delay(0.14 + idx * 0.08, function()
				if activeToken ~= myToken or not item.Fill.Parent then return end
				TweenService:Create(item.Fill, TweenInfo.new(0.52, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Size = UDim2.fromScale(item.TargetPct, 1),
				}):Play()
			end)
		end

		fireShockwave(glowCol, 80, 640, 0.55, 0)
		fireShockwave(primaryCol, 60, 780, 0.72, 0.11)
		spawnAmbientParticles()
	end

	-- =========================================================================
	-- OPENING CHOREOGRAPHY BY THEME
	-- =========================================================================
	if theme == "Legendary" or theme == "Epic" then
		-- TWIN OBSIDIAN STEEL VAULT DOORS + ROTATING 24K BRASS DIAL + GLOWING CRACKS!
		AudioController.PlayVaultCharge()

		local doorL = Instance.new("Frame")
		doorL.Name = "VaultDoorL"
		doorL.Size = UDim2.fromScale(0.505, 1)
		doorL.Position = UDim2.fromScale(-0.5, 0)
		doorL.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
		doorL.BorderSizePixel = 0
		doorL.ZIndex = 94
		doorL.Parent = root
		makeStroke(doorL, primaryCol, 2, 0.35)

		local doorR = Instance.new("Frame")
		doorR.Name = "VaultDoorR"
		doorR.Size = UDim2.fromScale(0.505, 1)
		doorR.Position = UDim2.fromScale(1.0, 0)
		doorR.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
		doorR.BorderSizePixel = 0
		doorR.ZIndex = 94
		doorR.Parent = root
		makeStroke(doorR, primaryCol, 2, 0.35)

		-- Central Rotating Brass Vault Lock Wheel
		local dial = Instance.new("Frame")
		dial.AnchorPoint = Vector2.new(0.5, 0.5)
		dial.Position = UDim2.fromScale(0.5, 0.5)
		dial.Size = UDim2.fromOffset(148, 148)
		dial.BackgroundColor3 = C_OBS
		dial.ZIndex = 95
		dial.Parent = root
		makeCorner(dial, 74)
		makeStroke(dial, glowCol, 5, 0)

		for k = 0, 3 do
			local spoke = Instance.new("Frame")
			spoke.AnchorPoint = Vector2.new(0.5, 0.5)
			spoke.Position = UDim2.fromScale(0.5, 0.5)
			spoke.Size = UDim2.fromOffset(132, 8)
			spoke.Rotation = k * 45
			spoke.BackgroundColor3 = primaryCol
			spoke.BorderSizePixel = 0
			spoke.ZIndex = 95
			spoke.Parent = dial
		end

		-- Slam doors shut quickly -> lock spins & glows -> BLAST OPEN!
		TweenService:Create(doorL, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0, 0),
		}):Play()
		TweenService:Create(doorR, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.498, 0),
		}):Play()
		TweenService:Create(dial, TweenInfo.new(0.52, Enum.EasingStyle.Back, Enum.EasingDirection.InOut), {
			Rotation = 225,
		}):Play()

		-- Glowing golden/crimson seam crack appearing down the center before detonation!
		local seam = Instance.new("Frame")
		seam.AnchorPoint = Vector2.new(0.5, 0.5)
		seam.Position = UDim2.fromScale(0.5, 0.5)
		seam.Size = UDim2.new(0, 2, 0, 0)
		seam.BackgroundColor3 = glowCol
		seam.BorderSizePixel = 0
		seam.ZIndex = 95
		seam.Parent = root
		TweenService:Create(seam, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 10, 1, 0),
		}):Play()

		task.delay(0.56, function()
			if activeToken ~= myToken or not root.Parent then return end
			if theme == "Legendary" then
				AudioController.PlayLegendarySurpriseDrop()
				triggerCameraPunch(12, 0.36, 12)
				fireImpactFlash(C_GOLD_HI, "None")
			else
				AudioController.PlayEpicRevealDrop()
				triggerCameraPunch(9, 0.28, 9)
				fireImpactFlash(C_CRIMSON_HI, "None")
			end

			dial:Destroy()
			seam:Destroy()
			TweenService:Create(doorL, TweenInfo.new(0.36, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(-0.56, 0),
			}):Play()
			TweenService:Create(doorR, TweenInfo.new(0.36, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(1.06, 0),
			}):Play()
			task.delay(0.4, function()
				if doorL.Parent then doorL:Destroy() end
				if doorR.Parent then doorR:Destroy() end
			end)

			revealHeroStage()
		end)
	elseif theme == "Ninja" then
		-- KUNAI BARRAGE -> SMOKE SUB DROP -> SILVER X-SLASH IMPACT FRAME -> CRIMSON ECLIPSE!
		AudioController.PlayNinjaArrivalSFX()

		for k = 1, 5 do
			task.delay((k - 1) * 0.055, function()
				if activeToken ~= myToken or not root.Parent then return end
				local kunai = Instance.new("Frame")
				kunai.AnchorPoint = Vector2.new(0.5, 0.5)
				local startY = 0.14 + (k - 1) * 0.15
				kunai.Position = UDim2.fromScale(-0.1, startY)
				kunai.Size = UDim2.fromOffset(180, 5)
				kunai.Rotation = 16
				kunai.BackgroundColor3 = C_SILVER
				kunai.BorderSizePixel = 0
				kunai.ZIndex = 95
				kunai.Parent = root
				TweenService:Create(kunai, TweenInfo.new(0.18, Enum.EasingStyle.Linear), {
					Position = UDim2.fromScale(1.15, startY + 0.22),
				}):Play()
				task.delay(0.2, function()
					if kunai.Parent then kunai:Destroy() end
				end)
			end)
		end

		task.delay(0.32, function()
			if activeToken ~= myToken or not root.Parent then return end
			triggerCameraPunch(11, 0.30, 11)
			fireImpactFlash(Color3.fromRGB(235, 240, 255), "X")
			revealHeroStage()
		end)
	elseif theme == "Samurai" then
		-- KATANA UNSHEATHE -> SAKURA WIND -> BLAZING CRIMSON-GOLD CRESCENT SLASH!
		AudioController.PlaySamuraiArrivalSFX()

		task.delay(0.42, function()
			if activeToken ~= myToken or not root.Parent then return end
			triggerCameraPunch(11, 0.32, 10)
			fireImpactFlash(C_CRIMSON_HI, "Crescent")
			revealHeroStage()
		end)
	elseif theme == "Bodyguard" then
		-- SYNDICATE SPOTLIGHT DROP -> TACTICAL RACK -> BRASS CREST REVEAL!
		AudioController.PlayBodyguardArrivalSFX()

		task.delay(0.30, function()
			if activeToken ~= myToken or not root.Parent then return end
			triggerCameraPunch(8, 0.24, 7)
			fireImpactFlash(C_GOLD_HI, "None")
			revealHeroStage()
		end)
	else
		-- Crisp Rare Celebration
		AudioController.PlayRareRevealDrop()
		triggerCameraPunch(6, 0.18, 5)
		fireImpactFlash(glowCol, "None")
		revealHeroStage()
	end

	-- 60 FPS Continuous Orbit Loop (rotates Volumetric Sunbeams, Heroic Front-Facing 3D Turntable & Particles!)
	local elapsedOrbit = 0
	activeConn = RunService.RenderStepped:Connect(function(dt: number)
		local safeDt = math.min(dt, 0.05)
		elapsedOrbit += safeDt

		if beamHub.Parent and beamHub.Visible then
			beamHub.Rotation = (beamHub.Rotation + safeDt * 18) % 360
		end
		if orbitCam and heroViewport and heroViewport.Parent then
			-- Smooth heroic turntable starting from the front-facing 3/4 pose!
			local ang = baseOrbitAngle + math.sin(elapsedOrbit * 1.15) * 0.58 + elapsedOrbit * 0.35
			local cx = orbitCenter.X + math.sin(ang) * orbitDist
			local cz = orbitCenter.Z + math.cos(ang) * orbitDist
			local cy = orbitCenter.Y + orbitHeight + math.sin(elapsedOrbit * 1.8) * 0.12
			orbitCam.CFrame = CFrame.lookAt(Vector3.new(cx, cy, cz), orbitCenter)
		end

		for _, pt in ipairs(particles) do
			if pt.Frame.Parent then
				pt.X += pt.VX * safeDt
				pt.Y += pt.VY * safeDt
				if pt.Y < -0.08 then
					pt.Y = 1.05
					pt.X = math.random()
				elseif pt.Y > 1.08 then
					pt.Y = -0.05
					pt.X = math.random()
				end
				if pt.X > 1.08 then pt.X = -0.05 end
				if pt.X < -0.08 then pt.X = 1.05 end
				pt.Frame.Position = UDim2.fromScale(pt.X, pt.Y)
				pt.Frame.Rotation = (pt.Frame.Rotation + pt.RotSpeed * safeDt) % 360
			end
		end
	end)

	-- Safe auto-close after 5.6s so player is never stuck if they don't click Collect!
	task.delay(5.6, function()
		if activeToken == myToken and isActive then
			closeReveal()
		end
	end)
end

-- High-level helper for Central Market Lucky Spin prizes (Legendary / Epic / Rare)
function CinematicRevealController.PlaySpinReveal(res: { [string]: any }): ()
	local rarity = tostring(res.Rarity or "Rare")
	local previewKind = tostring(res.PreviewKind or "Equipment")
	local previewId = tostring(res.PreviewId or "InstantEmpireCrate")
	local title = tostring(res.PrizeTitle or "SYNDICATE JACKPOT")
	local detail = tostring(res.Detail or "Credited to your Food Empire!")

	local stats: { StatRow } = {}
	if previewKind == "Bodyguard" then
		local spec = BodyguardConfig.CLASSES[previewId :: BodyguardConfig.GuardClassId]
		if spec then
			title = spec.DisplayName
			stats = {
				{ Label = "MAX HP", Value = tostring(spec.MaxHP), Pct = math.clamp(spec.MaxHP / 950, 0.25, 1) },
				{ Label = "FIREPOWER", Value = tostring(spec.Damage) .. " DMG", Pct = math.clamp(spec.Damage / 120, 0.25, 1) },
				{ Label = "RANGE", Value = tostring(spec.AttackRange) .. "M", Pct = math.clamp(spec.AttackRange / 110, 0.25, 1) },
			}
		end
	elseif previewKind == "Weapon" then
		local wSpec = WeaponConfig.WEAPONS[previewId]
		if wSpec then
			title = wSpec.DisplayName
			local rpm = math.floor(60 / math.max(0.08, wSpec.Cooldown))
			stats = {
				{ Label = "DAMAGE", Value = tostring(wSpec.Damage), Pct = math.clamp(wSpec.Damage / 95, 0.25, 1) },
				{ Label = "FIRE RATE", Value = tostring(rpm) .. " RPM", Pct = math.clamp(rpm / 650, 0.25, 1) },
				{ Label = "RANGE", Value = tostring(wSpec.Range) .. "M", Pct = math.clamp(wSpec.Range / 220, 0.25, 1) },
			}
		end
	else
		stats = {
			{ Label = "RARITY", Value = string.upper(rarity), Pct = if rarity == "Legendary" then 1 elseif rarity == "Epic" then 0.85 else 0.65 },
			{ Label = "VAULT TIER", Value = "SYNDICATE", Pct = 0.82 },
			{ Label = "STATUS", Value = "CREDITED", Pct = 1.0 },
		}
	end

	local theme: "Legendary" | "Epic" | "Rare" = if rarity == "Legendary"
		then "Legendary"
		elseif rarity == "Epic" then "Epic"
		else "Rare"

	CinematicRevealController.Play({
		Theme = theme,
		Badge = if rarity == "Legendary"
			then "LEGENDARY VAULT JACKPOT  |  6% DROP"
			elseif rarity == "Epic" then "EPIC BLACK MARKET ARMORY  |  6% DROP"
			else "RARE CENTRAL MARKET WIN",
		Title = title,
		Subtitle = detail,
		ButtonText = if previewKind == "Bodyguard" then "DEPLOY TO SQUAD" else "COLLECT REWARD",
		PreviewKind = previewKind,
		PreviewId = previewId,
		Stats = stats,
	})
end

-- High-level helper for Hired Ninja, Samurai & Recruited Bodyguard Welcomes
function CinematicRevealController.PlayUnitWelcome(data: { [string]: any }): ()
	local kind = tostring(data.Kind or "Bodyguard")
	if kind == "Ninja" then
		CinematicRevealController.Play({
			Theme = "Ninja",
			Badge = "SHADOW NINJA CLAN DEPLOYED  |  05:00 CONTRACT",
			Title = tostring(data.Title or "KAGE NINJA ASSASSIN SQUAD"),
			Subtitle = tostring(data.Subtitle or "3 Elite Shadow Assassins dropped onto your perimeter — Press [Y] to Unleash!"),
			ButtonText = "UNLEASH SHADOWS",
			PreviewKind = "Premium",
			PreviewId = "NinjaMafiaContract",
			Stats = {
				{ Label = "SQUAD HP", Value = "1,350 x3", Pct = 0.88 },
				{ Label = "CRIT STRIKE", Value = "198 DMG", Pct = 0.96 },
				{ Label = "AGILITY", Value = "29 SPD", Pct = 1.0 },
			},
		})
	elseif kind == "Samurai" then
		CinematicRevealController.Play({
			Theme = "Samurai",
			Badge = "IRON SHOGUN SAMURAI DEPLOYED  |  05:00 CONTRACT",
			Title = tostring(data.Title or "KUROGANE SAMURAI MAFIA"),
			Subtitle = tostring(data.Subtitle or "3 Armored Katana Ronin sworn to your Empire — Press [Y] to Command Assault!"),
			ButtonText = "COMMAND RONIN",
			PreviewKind = "Premium",
			PreviewId = "SamuraiMafiaContract",
			Stats = {
				{ Label = "SQUAD HP", Value = "1,550 x3", Pct = 1.0 },
				{ Label = "KATANA DMG", Value = "134 DMG", Pct = 0.90 },
				{ Label = "DURATION", Value = "05:00", Pct = 0.85 },
			},
		})
	else
		local classId = tostring(data.PreviewId or "BasicGuard")
		local spec = BodyguardConfig.CLASSES[classId :: BodyguardConfig.GuardClassId]
		local stats: { StatRow } = if spec
			then {
				{ Label = "MAX HP", Value = tostring(spec.MaxHP), Pct = math.clamp(spec.MaxHP / 950, 0.25, 1) },
				{ Label = "DAMAGE", Value = tostring(spec.Damage) .. " DMG", Pct = math.clamp(spec.Damage / 120, 0.25, 1) },
				{ Label = "RANGE", Value = tostring(spec.AttackRange) .. "M", Pct = math.clamp(spec.AttackRange / 110, 0.25, 1) },
			}
			else {
				{ Label = "STATUS", Value = "ON DUTY", Pct = 1.0 },
				{ Label = "LOYALTY", Value = "100%", Pct = 1.0 },
				{ Label = "ESCORT", Value = "ACTIVE", Pct = 0.92 },
			}

		CinematicRevealController.Play({
			Theme = "Bodyguard",
			Badge = tostring(data.Badge or "SYNDICATE BODYGUARD REPORTING FOR DUTY"),
			Title = tostring(data.Title or (if spec then spec.DisplayName else "ELITE BODYGUARD")),
			Subtitle = tostring(data.Subtitle or (if spec then spec.Role .. " — Assigned to your personal security detail!" else "Assigned to your personal escort squad!")),
			ButtonText = "WELCOME TO SQUAD",
			PreviewKind = "Bodyguard",
			PreviewId = classId,
			Stats = stats,
		})
	end
end

function CinematicRevealController.Init(_parentGui: ScreenGui): ()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existingGui = pg:FindFirstChild("CinematicRevealGui")
	if existingGui then existingGui:Destroy() end

	-- Dedicated top-layer ScreenGui (DisplayOrder = 100, IgnoreGuiInset = true) so cinematics & letterbox bars
	-- always render cleanly ABOVE the Hotbar, Topbar & every HUD element!
	local revealGui = Instance.new("ScreenGui")
	revealGui.Name = "CinematicRevealGui"
	revealGui.DisplayOrder = 100
	revealGui.IgnoreGuiInset = true
	revealGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	revealGui.ResetOnSpawn = false
	revealGui.Parent = pg

	local root = Instance.new("Frame")
	root.Name = "CinematicRevealOverlay"
	root.Size = UDim2.fromScale(1, 1)
	root.Position = UDim2.new()
	root.BackgroundColor3 = Color3.fromRGB(4, 5, 8)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Visible = false
	root.ZIndex = 80
	root.Parent = revealGui
	overlayRoot = root

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
		if not remotes then return end
		local welcomeEv = remotes:WaitForChild("PlayUnitWelcome", 15)
		if welcomeEv and welcomeEv:IsA("RemoteEvent") then
			welcomeEv.OnClientEvent:Connect(function(payload: any)
				if typeof(payload) == "table" then
					CinematicRevealController.PlayUnitWelcome(payload)
				end
			end)
		end
	end)
end

return CinematicRevealController
