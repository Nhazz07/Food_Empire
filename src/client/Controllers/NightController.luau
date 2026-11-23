--!strict

-- NightController: Client-side Night Mode experience.
--  * Live HUD clock pill (DAY / DUSK / NIGHT) — click or press [N] to switch phase.
--  * Soft personal lantern glow around your character at night so you can always see.
--  * Looping night cricket ambience that fades in at dusk and out at dawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local NightController = {}

local CRICKETS_SOUND_ID = "rbxassetid://9112764573"

local clockPill: TextButton? = nil
local clockLabel: TextLabel? = nil
local bonusLabel: TextLabel? = nil
local pillStroke: UIStroke? = nil
local ambience: Sound? = nil
local personalLight: PointLight? = nil
local ambienceTargetVol = -1

local function formatClock(c: number): string
	local h = math.floor(c) % 24
	local m = math.floor((c - math.floor(c)) * 60)
	local suffix = if h >= 12 then "PM" else "AM"
	local h12 = h % 12
	if h12 == 0 then h12 = 12 end
	return string.format("%d:%02d %s", h12, m, suffix)
end

local function ensurePersonalLight(): PointLight?
	local char = Players.LocalPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return nil
	end
	if personalLight and personalLight.Parent == root then
		return personalLight
	end
	local pl = Instance.new("PointLight")
	pl.Name = "NightPersonalGlow"
	pl.Color = Color3.fromRGB(255, 226, 170)
	pl.Range = 26
	pl.Brightness = 0
	pl.Shadows = false
	pl.Parent = root
	personalLight = pl
	return pl
end

function NightController.Init(parentGui: ScreenGui, onSkip: () -> ()): ()
	local pill = Instance.new("TextButton")
	pill.Name = "DayNightClock"
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, -14, 0, 8)
	pill.Size = UDim2.fromOffset(216, 46)
	pill.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	pill.BackgroundTransparency = 0.06
	pill.AutoButtonColor = false
	pill.Text = ""
	pill.Parent = parentGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(52, 56, 66)
	stroke.Thickness = 1.2
	stroke.Parent = pill
	pillStroke = stroke

	local lbl = Instance.new("TextLabel")
	lbl.Position = UDim2.new(0, 10, 0, 4)
	lbl.Size = UDim2.new(1, -20, 0, 20)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = "DAY  |  2:00 PM"
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = Color3.fromRGB(234, 231, 224)
	lbl.Parent = pill
	clockLabel = lbl

	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.new(0, 10, 0, 24)
	sub.Size = UDim2.new(1, -20, 0, 16)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.Text = "Click or [N] to switch phase"
	sub.TextSize = 10
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = Color3.fromRGB(152, 156, 166)
	sub.Parent = pill
	bonusLabel = sub

	clockPill = pill
	pill.MouseButton1Click:Connect(onSkip)

	-- Drain DayNightSync RemoteEvent cleanly so Studio's invocation queue never warns
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
		local dnSync = if remotes then remotes:WaitForChild("DayNightSync", 10) else nil
		if dnSync and dnSync:IsA("RemoteEvent") then
			dnSync.OnClientEvent:Connect(function() end)
		end
	end)

	-- Looping cricket night ambience
	local snd = Instance.new("Sound")
	snd.Name = "NightCricketsAmbience"
	snd.SoundId = CRICKETS_SOUND_ID
	snd.Looped = true
	snd.Volume = 0
	snd.Parent = SoundService
	ambience = snd

	RunService.Heartbeat:Connect(function()
		local clockAttr = ReplicatedStorage:GetAttribute("GameClock")
		local phaseAttr = ReplicatedStorage:GetAttribute("DayPhase")
		local nfAttr = ReplicatedStorage:GetAttribute("NightFactor")
		local c = if typeof(clockAttr) == "number" then clockAttr else 14
		local phase = if typeof(phaseAttr) == "string" then phaseAttr else "Day"
		local nf = if typeof(nfAttr) == "number" then nfAttr else 0
		local isNight = ReplicatedStorage:GetAttribute("IsNight") == true

		if clockLabel and bonusLabel and clockPill and pillStroke then
			clockLabel.Text = string.format("%s  |  %s", string.upper(phase), formatClock(c))
			if isNight then
				bonusLabel.Text = "+35% Gold  |  Mafia Alert  [N]"
				bonusLabel.TextColor3 = Color3.fromRGB(196, 166, 102)
			else
				bonusLabel.Text = "Press [N] to switch to Night"
				bonusLabel.TextColor3 = Color3.fromRGB(152, 156, 166)
			end
			clockPill.BackgroundColor3 = Color3.fromRGB(22, 24, 30):Lerp(Color3.fromRGB(14, 15, 20), nf)
			pillStroke.Color = Color3.fromRGB(58, 62, 72):Lerp(Color3.fromRGB(118, 32, 38), nf)
		end

		-- Personal lantern glow so the player never gets lost in the dark
		local pl = ensurePersonalLight()
		if pl then
			pl.Brightness = 1.25 * nf
			pl.Enabled = nf > 0.05
		end

		-- Fade cricket ambience in/out
		if ambience then
			local target = math.floor(nf * 0.32 * 100 + 0.5) / 100
			if target ~= ambienceTargetVol then
				ambienceTargetVol = target
				if target > 0 and not ambience.IsPlaying then
					ambience:Play()
				end
				TweenService:Create(ambience, TweenInfo.new(1.5), { Volume = target }):Play()
			end
			if target <= 0 and ambience.IsPlaying and ambience.Volume <= 0.01 then
				ambience:Stop()
			end
		end
	end)
end

return NightController
