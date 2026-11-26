--!strict

-- RaidWarningController (Stage 4 — Raid Warning and Alarm)
-- Displays a high-visibility on-screen Mafia Raid Warning Banner and plays a
-- validated alarm sound strictly for the affected restaurant owner.
--
-- Features:
--  * Displays clear warning lines ("WARNING! MAFIA RAID DETECTED!",
--    "Enemies are approaching your restaurant!", "Protect your money and warehouse supplies!").
--  * Clearly identifies the attacking Enemy Group (Normal / Ninja / Strong / Elite Mafia)
--    and the affected Restaurant.
--  * Live countdown timer & shrinking progress bar during the pre-attack warning period.
--  * Stays visible until the raid starts or is cancelled, then stops the alarm cleanly.
--  * Uses verified ProSoundEffects alarm asset with automatic built-in Roblox fallback
--    if primary asset is empty or unavailable — never plays a missing/invalid sound ID.
--  * Anti-spam & duplicate notification guards by RaidId and minimum retrigger cooldown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local RestaurantSecurityConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RestaurantSecurityConfig")
)

local RaidWarningController = {}

local FONT_TITLE = Enum.Font.GothamBlack
local FONT_BOLD = Enum.Font.GothamBold
local FONT_REG = Enum.Font.Gotham

local isInitialized = false
local bannerFrame: Frame? = nil
local bannerStroke: UIStroke? = nil
local topBeaconBar: Frame? = nil
local titleLabel: TextLabel? = nil
local countdownPill: TextLabel? = nil
local groupBadge: TextLabel? = nil
local restaurantBadge: TextLabel? = nil
local subtitleLabel: TextLabel? = nil
local detailLabel: TextLabel? = nil
local progressFill: Frame? = nil
local edgeGlowBar: Frame? = nil

local alarmSound: Sound? = nil
local fallbackSound: Sound? = nil
local primaryAudioVerified = false
local fallbackPulseThread: thread? = nil

local activeWarningRaidId: string? = nil
local warningStartedAt = 0
local warningEndsAt = 0
local warningDuration = 8
local warningAccent = Color3.fromRGB(220, 52, 62)
local lastAlarmPlayedAt = 0
local lastHandledPhaseKey = ""

local alertConn: RBXScriptConnection? = nil
local renderConn: RBXScriptConnection? = nil

local function getAlarmCfg(): RestaurantSecurityConfig.RaidAlarmConfig
	return RestaurantSecurityConfig.RaidAlarm
end

local function initAlarmSounds(): ()
	local cfg = getAlarmCfg()

	local existingPrimary = SoundService:FindFirstChild("FoodEmpireRaidAlarm")
	if existingPrimary then
		existingPrimary:Destroy()
	end
	local existingFallback = SoundService:FindFirstChild("FoodEmpireRaidAlarmFallback")
	if existingFallback then
		existingFallback:Destroy()
	end

	local fb = Instance.new("Sound")
	fb.Name = "FoodEmpireRaidAlarmFallback"
	fb.SoundId = if typeof(cfg.FallbackSoundId) == "string" and cfg.FallbackSoundId ~= ""
		then cfg.FallbackSoundId
		else "rbxasset://sounds/electronicpingshort.wav"
	fb.Volume = math.clamp(cfg.Volume * 0.85, 0.1, 1.0)
	fb.PlaybackSpeed = 0.86
	fb.Looped = false
	fb.Parent = SoundService
	fallbackSound = fb

	if typeof(cfg.SoundId) == "string" and cfg.SoundId ~= "" then
		local snd = Instance.new("Sound")
		snd.Name = "FoodEmpireRaidAlarm"
		snd.SoundId = cfg.SoundId
		snd.Volume = math.clamp(cfg.Volume, 0.1, 1.0)
		snd.PlaybackSpeed = cfg.PlaybackSpeed or 1.0
		snd.Looped = cfg.LoopedDuringWarning ~= false
		snd.Parent = SoundService
		alarmSound = snd

		-- Preload asynchronously and verify valid load state so we never play a broken sound
		task.spawn(function()
			local ok = pcall(function()
				ContentProvider:PreloadAsync({ snd })
			end)
			if ok and snd.Parent and (snd.IsLoaded or snd.TimeLength > 0) then
				primaryAudioVerified = true
			else
				-- Give Studio/client a brief grace check for TimeLength resolution
				task.wait(0.8)
				if snd.Parent and (snd.IsLoaded or snd.TimeLength > 0) then
					primaryAudioVerified = true
				end
			end
		end)
	end
end

local function stopAlarmAudio(): ()
	if fallbackPulseThread then
		local th = fallbackPulseThread
		fallbackPulseThread = nil
		if coroutine.running() ~= th then
			pcall(task.cancel, th)
		end
	end
	if alarmSound and alarmSound.Parent and alarmSound.IsPlaying then
		local snd = alarmSound
		local fade = TweenService:Create(snd, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0,
		})
		fade:Play()
		task.delay(0.24, function()
			if snd.Parent and activeWarningRaidId == nil then
				snd:Stop()
				snd.Volume = math.clamp(getAlarmCfg().Volume, 0.1, 1.0)
			end
		end)
	end
	if fallbackSound and fallbackSound.Parent and fallbackSound.IsPlaying then
		fallbackSound:Stop()
	end
end

local function startAlarmAudio(raidId: string): ()
	local cfg = getAlarmCfg()
	local now = os.clock()
	if (now - lastAlarmPlayedAt) < math.max(1, cfg.MinRetriggerSeconds) then
		return
	end
	lastAlarmPlayedAt = now

	-- Stop any previous fallback loop before starting
	if fallbackPulseThread then
		local th = fallbackPulseThread
		fallbackPulseThread = nil
		if coroutine.running() ~= th then
			pcall(task.cancel, th)
		end
	end

	local canUsePrimary = alarmSound ~= nil
		and alarmSound.Parent ~= nil
		and (primaryAudioVerified or alarmSound.IsLoaded or alarmSound.TimeLength > 0)

	if canUsePrimary and alarmSound then
		alarmSound.Volume = math.clamp(cfg.Volume, 0.1, 1.0)
		alarmSound.PlaybackSpeed = cfg.PlaybackSpeed or 1.0
		alarmSound.Looped = cfg.LoopedDuringWarning ~= false
		alarmSound.TimePosition = 0
		alarmSound:Play()
		return
	end

	-- Guaranteed built-in pulsed fallback alarm (zero invalid/missing SoundId errors!)
	if fallbackSound and fallbackSound.Parent then
		fallbackPulseThread = task.spawn(function()
			local flip = false
			while activeWarningRaidId == raidId and fallbackSound and fallbackSound.Parent do
				flip = not flip
				fallbackSound.PlaybackSpeed = if flip then 0.96 else 0.78
				fallbackSound.Volume = math.clamp(cfg.Volume * 0.85, 0.1, 1.0)
				fallbackSound:Play()
				task.wait(0.68)
			end
		end)
	end
end

local function hideWarningBanner(): ()
	activeWarningRaidId = nil
	stopAlarmAudio()
	if bannerFrame then
		bannerFrame.Visible = false
	end
	if edgeGlowBar then
		edgeGlowBar.Visible = false
	end
end

local function showWarningBanner(payload: { [string]: any }): ()
	local raidId = tostring(payload.RaidId or "")
	if raidId == "" then
		return
	end
	-- Prevent duplicate notification & alarm spam for the same raid!
	if activeWarningRaidId == raidId then
		return
	end

	local cfg = getAlarmCfg()
	local leadSec = if typeof(payload.LeadSeconds) == "number" then math.max(1, payload.LeadSeconds) else 8
	local groupName = tostring(payload.GroupName or "Mafia")
	local restaurantName = tostring(payload.RestaurantName or (tostring(payload.BaseSlot or "Your") .. " Restaurant"))
	local accent = if typeof(payload.AccentColor) == "Color3" then payload.AccentColor else Color3.fromRGB(220, 52, 62)

	activeWarningRaidId = raidId
	warningAccent = accent
	warningDuration = leadSec
	warningStartedAt = os.clock()
	warningEndsAt = warningStartedAt + leadSec

	if titleLabel then
		titleLabel.Text = tostring(payload.TitleText or cfg.TitleText)
	end
	if subtitleLabel then
		subtitleLabel.Text = tostring(payload.SubtitleText or cfg.SubtitleText)
	end
	if detailLabel then
		detailLabel.Text = tostring(payload.DetailText or cfg.DetailText)
	end
	if groupBadge then
		groupBadge.Text = "ATTACKERS: " .. string.upper(groupName)
		groupBadge.BackgroundColor3 = accent:Lerp(Color3.fromRGB(28, 16, 20), 0.55)
		local gStroke = groupBadge:FindFirstChildOfClass("UIStroke")
		if gStroke then
			gStroke.Color = accent
		end
	end
	if restaurantBadge then
		restaurantBadge.Text = "AFFECTED: " .. string.upper(restaurantName)
	end
	if countdownPill then
		countdownPill.Text = string.format("IMPACT IN %ds", math.ceil(leadSec))
	end
	if topBeaconBar then
		topBeaconBar.BackgroundColor3 = accent
	end
	if progressFill then
		progressFill.BackgroundColor3 = accent
		progressFill.Size = UDim2.fromScale(1, 1)
	end
	if bannerStroke then
		bannerStroke.Color = accent
	end
	if bannerFrame then
		bannerFrame.Visible = true
		bannerFrame.Position = UDim2.new(0.5, 0, 0, 92)
		TweenService:Create(
			bannerFrame,
			TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 0, 108) }
		):Play()
	end
	if edgeGlowBar then
		edgeGlowBar.BackgroundColor3 = accent
		edgeGlowBar.Visible = true
	end

	startAlarmAudio(raidId)
end

local function handleRaidAlert(payload: any): ()
	if typeof(payload) ~= "table" then
		return
	end
	local phase = tostring(payload.Phase or "")
	local raidId = tostring(payload.RaidId or "")
	local phaseKey = raidId .. ":" .. phase
	if raidId ~= "" and phaseKey == lastHandledPhaseKey then
		return
	end
	lastHandledPhaseKey = phaseKey

	if phase == "Warning" then
		showWarningBanner(payload)
	elseif phase == "Started" or phase == "Cancelled" or phase == "Ended" then
		if activeWarningRaidId == nil or raidId == "" or activeWarningRaidId == raidId then
			hideWarningBanner()
		end
	end
end

function RaidWarningController.Init(parentGui: ScreenGui): ()
	if isInitialized then
		return
	end
	isInitialized = true

	initAlarmSounds()

	-- Subtle pulsing top-edge alert accent strip (non-blocking)
	local glow = Instance.new("Frame")
	glow.Name = "RaidWarningTopEdgeGlow"
	glow.Position = UDim2.fromOffset(0, 0)
	glow.Size = UDim2.new(1, 0, 0, 4)
	glow.BackgroundColor3 = Color3.fromRGB(220, 52, 62)
	glow.BackgroundTransparency = 0.15
	glow.BorderSizePixel = 0
	glow.ZIndex = 34
	glow.Visible = false
	glow.Parent = parentGui
	edgeGlowBar = glow

	-- Main Raid Warning Banner (clean dark-noir alert card below top HUD bar)
	local banner = Instance.new("Frame")
	banner.Name = "NightRaidWarningBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 108)
	banner.Size = UDim2.fromOffset(560, 122)
	banner.BackgroundColor3 = Color3.fromRGB(20, 11, 15)
	banner.BackgroundTransparency = 0.04
	banner.BorderSizePixel = 0
	banner.ZIndex = 35
	banner.Visible = false
	banner.Parent = parentGui
	bannerFrame = banner

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 10)
	bCorner.Parent = banner

	local bStroke = Instance.new("UIStroke")
	bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bStroke.Color = Color3.fromRGB(220, 52, 62)
	bStroke.Thickness = 2.2
	bStroke.Parent = banner
	bannerStroke = bStroke

	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(48, 16, 22)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 11, 16)),
	})
	grad.Parent = banner

	-- Top pulsing beacon bar inside banner
	local beacon = Instance.new("Frame")
	beacon.Name = "TopBeacon"
	beacon.Position = UDim2.new(0, 0, 0, 0)
	beacon.Size = UDim2.new(1, 0, 0, 4)
	beacon.BackgroundColor3 = Color3.fromRGB(220, 52, 62)
	beacon.BorderSizePixel = 0
	beacon.ZIndex = 36
	beacon.Parent = banner
	topBeaconBar = beacon

	-- Row 1: Main Warning Headline + Live Countdown Pill
	local title = Instance.new("TextLabel")
	title.Name = "WarningTitle"
	title.Position = UDim2.new(0, 16, 0, 10)
	title.Size = UDim2.new(1, -156, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = FONT_TITLE
	title.Text = "WARNING! MAFIA RAID DETECTED!"
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 226, 138)
	title.ZIndex = 36
	title.Parent = banner
	titleLabel = title

	local cdPill = Instance.new("TextLabel")
	cdPill.Name = "CountdownPill"
	cdPill.AnchorPoint = Vector2.new(1, 0)
	cdPill.Position = UDim2.new(1, -14, 0, 10)
	cdPill.Size = UDim2.fromOffset(128, 24)
	cdPill.BackgroundColor3 = Color3.fromRGB(168, 30, 42)
	cdPill.Font = FONT_TITLE
	cdPill.Text = "IMPACT IN 8s"
	cdPill.TextSize = 12
	cdPill.TextColor3 = Color3.fromRGB(255, 246, 232)
	cdPill.ZIndex = 36
	cdPill.Parent = banner
	countdownPill = cdPill

	local cdCorner = Instance.new("UICorner")
	cdCorner.CornerRadius = UDim.new(0, 6)
	cdCorner.Parent = cdPill

	-- Row 2: Enemy Group Badge + Affected Restaurant Badge
	local grpBadge = Instance.new("TextLabel")
	grpBadge.Name = "EnemyGroupBadge"
	grpBadge.Position = UDim2.new(0, 16, 0, 40)
	grpBadge.Size = UDim2.new(0.42, -10, 0, 22)
	grpBadge.BackgroundColor3 = Color3.fromRGB(78, 24, 34)
	grpBadge.Font = FONT_BOLD
	grpBadge.Text = "ATTACKERS: NORMAL MAFIA"
	grpBadge.TextSize = 11
	grpBadge.TextColor3 = Color3.fromRGB(255, 236, 236)
	grpBadge.ZIndex = 36
	grpBadge.Parent = banner
	groupBadge = grpBadge

	local gCorner = Instance.new("UICorner")
	gCorner.CornerRadius = UDim.new(0, 5)
	gCorner.Parent = grpBadge

	local gStroke = Instance.new("UIStroke")
	gStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	gStroke.Color = Color3.fromRGB(220, 52, 62)
	gStroke.Thickness = 1
	gStroke.Parent = grpBadge

	local restBadge = Instance.new("TextLabel")
	restBadge.Name = "AffectedRestaurantBadge"
	restBadge.Position = UDim2.new(0.42, 12, 0, 40)
	restBadge.Size = UDim2.new(0.58, -26, 0, 22)
	restBadge.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
	restBadge.Font = FONT_BOLD
	restBadge.Text = "AFFECTED: NORTH RESTAURANT"
	restBadge.TextSize = 11
	restBadge.TextTruncate = Enum.TextTruncate.AtEnd
	restBadge.TextColor3 = Color3.fromRGB(238, 212, 142)
	restBadge.ZIndex = 36
	restBadge.Parent = banner
	restaurantBadge = restBadge

	local rCorner = Instance.new("UICorner")
	rCorner.CornerRadius = UDim.new(0, 5)
	rCorner.Parent = restBadge

	local rStroke = Instance.new("UIStroke")
	rStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rStroke.Color = Color3.fromRGB(128, 102, 58)
	rStroke.Thickness = 1
	rStroke.Parent = restBadge

	-- Row 3 & 4: Clear warning directive copy
	local sub = Instance.new("TextLabel")
	sub.Name = "WarningSubtitle"
	sub.Position = UDim2.new(0, 16, 0, 68)
	sub.Size = UDim2.new(1, -32, 0, 18)
	sub.BackgroundTransparency = 1
	sub.Font = FONT_BOLD
	sub.Text = "Enemies are approaching your restaurant!"
	sub.TextSize = 13
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = Color3.fromRGB(246, 242, 236)
	sub.ZIndex = 36
	sub.Parent = banner
	subtitleLabel = sub

	local detail = Instance.new("TextLabel")
	detail.Name = "WarningDetail"
	detail.Position = UDim2.new(0, 16, 0, 86)
	detail.Size = UDim2.new(1, -32, 0, 16)
	detail.BackgroundTransparency = 1
	detail.Font = FONT_REG
	detail.Text = "Protect your money and warehouse supplies!"
	detail.TextSize = 12
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextColor3 = Color3.fromRGB(218, 182, 148)
	detail.ZIndex = 36
	detail.Parent = banner
	detailLabel = detail

	-- Bottom Countdown Progress Bar
	local barBg = Instance.new("Frame")
	barBg.Name = "CountdownBarBg"
	barBg.Position = UDim2.new(0, 16, 1, -12)
	barBg.Size = UDim2.new(1, -32, 0, 6)
	barBg.BackgroundColor3 = Color3.fromRGB(36, 20, 26)
	barBg.BorderSizePixel = 0
	barBg.ZIndex = 36
	barBg.Parent = banner

	local barBgCorner = Instance.new("UICorner")
	barBgCorner.CornerRadius = UDim.new(0, 3)
	barBgCorner.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Name = "CountdownBarFill"
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(220, 52, 62)
	barFill.BorderSizePixel = 0
	barFill.ZIndex = 37
	barFill.Parent = barBg
	progressFill = barFill

	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(0, 3)
	barFillCorner.Parent = barFill

	-- Listen for server-authoritative owner-only NightRaidAlert events
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
		local alertEv = if remotes then remotes:WaitForChild("NightRaidAlert", 15) else nil
		if alertEv and alertEv:IsA("RemoteEvent") then
			if alertConn then
				alertConn:Disconnect()
			end
			alertConn = alertEv.OnClientEvent:Connect(handleRaidAlert)
		end
	end)

	-- Smooth pulse & live countdown bar animation while warning is active
	renderConn = RunService.Heartbeat:Connect(function()
		if activeWarningRaidId == nil or not bannerFrame or not bannerFrame.Visible then
			return
		end
		local now = os.clock()
		local rem = math.max(0, warningEndsAt - now)
		local frac = math.clamp(rem / math.max(0.1, warningDuration), 0, 1)
		local pulse = 0.5 + 0.5 * math.sin(now * 9.0)

		if countdownPill then
			countdownPill.Text = if rem > 0.1 then string.format("IMPACT IN %ds", math.ceil(rem)) else "RAID STARTING!"
		end
		if progressFill then
			progressFill.Size = UDim2.fromScale(frac, 1)
		end
		if bannerStroke then
			bannerStroke.Color = warningAccent:Lerp(Color3.fromRGB(255, 224, 130), pulse * 0.45)
			bannerStroke.Thickness = 2.0 + pulse * 1.0
		end
		if edgeGlowBar then
			edgeGlowBar.BackgroundTransparency = 0.1 + pulse * 0.55
		end
	end)
end

-- Reconcile against periodic StateSync snapshots so stale warnings never linger
function RaidWarningController.Update(state: { [string]: any }): ()
	local nr = state.NightRaid
	if typeof(nr) ~= "table" then
		return
	end
	local phase = nr.Phase
	if phase == "Warning" then
		if activeWarningRaidId == nil and typeof(nr.RaidId) == "string" then
			showWarningBanner({
				RaidId = nr.RaidId,
				GroupId = nr.GroupId,
				GroupName = nr.GroupName,
				BaseSlot = nr.BaseSlot,
				RestaurantName = nr.RestaurantName,
				LeadSeconds = nr.TimeRemaining,
			})
		end
	elseif activeWarningRaidId ~= nil then
		-- Raid transitioned to Active or Idle/Cancelled -> ensure warning & alarm stop cleanly
		hideWarningBanner()
	end
end

function RaidWarningController.IsWarningVisible(): boolean
	return bannerFrame ~= nil and bannerFrame.Visible == true
end

function RaidWarningController.IsAlarmPlaying(): boolean
	return (alarmSound ~= nil and alarmSound.IsPlaying) or (fallbackPulseThread ~= nil)
end

return RaidWarningController
