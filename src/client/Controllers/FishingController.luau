--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AudioController = require("./AudioController")

local FishingController = {}

local CATCH_MIN = 0.30
local CATCH_MAX = 0.70
local GOLDEN_MIN = 0.455
local GOLDEN_MAX = 0.545

local panel: Frame? = nil
local needle: Frame? = nil
local statusLabel: TextLabel? = nil
local activeToken: number? = nil
local needlePos = 0.1
local needleDir = 1
local needleSpeed = 1.6
local renderConn: RBXScriptConnection? = nil
local resultEv: RemoteEvent? = nil

local function finishCast(): ()
	local token = activeToken
	if not token then
		return
	end
	activeToken = nil

	local accuracy: string
	if needlePos >= GOLDEN_MIN and needlePos <= GOLDEN_MAX then
		accuracy = "Golden"
		AudioController.PlayFanfare()
	elseif needlePos >= CATCH_MIN and needlePos <= CATCH_MAX then
		accuracy = "Good"
		AudioController.PlayCoins()
	else
		accuracy = "Miss"
		AudioController.PlayError()
	end

	if statusLabel then
		statusLabel.Text = if accuracy == "Golden"
			then "🌟 GOLDEN RARE CATCH!!"
			elseif accuracy == "Good" then "🐟 NICE CATCH!"
			else "💨 Missed — try again!"
		statusLabel.TextColor3 = if accuracy == "Golden"
			then Color3.fromRGB(255, 224, 72)
			elseif accuracy == "Good" then Color3.fromRGB(118, 248, 158)
			else Color3.fromRGB(255, 134, 134)
	end

	if resultEv then
		resultEv:FireServer(token, accuracy)
	end

	task.delay(0.7, function()
		if not activeToken and panel then
			panel.Visible = false
		end
	end)
end

function FishingController.Init(parentGui: ScreenGui): ()
	local frame = Instance.new("Frame")
	frame.Name = "FishingMiniGamePanel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -172)
	frame.Size = UDim2.fromOffset(420, 126)
	frame.BackgroundColor3 = Color3.fromRGB(16, 32, 52)
	frame.BackgroundTransparency = 0.06
	frame.Visible = false
	frame.Parent = parentGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(72, 198, 255)
	stroke.Thickness = 2.4
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Position = UDim2.new(0, 12, 0, 6)
	title.Size = UDim2.new(1, -24, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = "🎣 FISHING PORT PIER — HIT GOLD FOR RARE CATCH!"
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(255, 232, 118)
	title.Parent = frame
	statusLabel = title

	-- Timing Track Bar
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.new(0, 20, 0, 38)
	track.Size = UDim2.new(1, -40, 0, 32)
	track.BackgroundColor3 = Color3.fromRGB(24, 48, 76)
	track.Parent = frame
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 8)
	tc.Parent = track
	local ts = Instance.new("UIStroke")
	ts.Color = Color3.fromRGB(16, 24, 36)
	ts.Thickness = 2
	ts.Parent = track

	-- Green Normal Catch Zone
	local greenZone = Instance.new("Frame")
	greenZone.Position = UDim2.fromScale(CATCH_MIN, 0)
	greenZone.Size = UDim2.fromScale(CATCH_MAX - CATCH_MIN, 1)
	greenZone.BackgroundColor3 = Color3.fromRGB(48, 196, 108)
	greenZone.BorderSizePixel = 0
	greenZone.Parent = track
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(0, 6)
	gc.Parent = greenZone

	-- Glowing Golden Rare Bullseye Zone
	local goldZone = Instance.new("Frame")
	goldZone.Position = UDim2.fromScale(GOLDEN_MIN, 0)
	goldZone.Size = UDim2.fromScale(GOLDEN_MAX - GOLDEN_MIN, 1)
	goldZone.BackgroundColor3 = Color3.fromRGB(255, 212, 52)
	goldZone.BorderSizePixel = 0
	goldZone.Parent = track
	local gdc = Instance.new("UICorner")
	gdc.CornerRadius = UDim.new(0, 4)
	gdc.Parent = goldZone

	-- Oscillating Bobber Needle
	local pin = Instance.new("Frame")
	pin.Name = "BobberNeedle"
	pin.AnchorPoint = Vector2.new(0.5, 0.5)
	pin.Position = UDim2.fromScale(0.1, 0.5)
	pin.Size = UDim2.fromOffset(10, 40)
	pin.BackgroundColor3 = Color3.fromRGB(255, 68, 62)
	pin.ZIndex = 5
	pin.Parent = track
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 5)
	pc.Parent = pin
	local ps = Instance.new("UIStroke")
	ps.Color = Color3.new(1, 1, 1)
	ps.Thickness = 2
	ps.Parent = pin
	needle = pin

	-- Big Click / Spacebar Reel Button
	local reelBtn = Instance.new("TextButton")
	reelBtn.Position = UDim2.new(0.5, -105, 1, -44)
	reelBtn.Size = UDim2.fromOffset(210, 34)
	reelBtn.BackgroundColor3 = Color3.fromRGB(44, 182, 224)
	reelBtn.Font = Enum.Font.GothamBlack
	reelBtn.Text = "🎣 REEL IN! [SPACE / CLICK]"
	reelBtn.TextSize = 13
	reelBtn.TextColor3 = Color3.new(1, 1, 1)
	reelBtn.Parent = frame
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 9)
	rc.Parent = reelBtn
	reelBtn.MouseButton1Click:Connect(finishCast)

	panel = frame

	UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
		if gp then
			return
		end
		if activeToken and input.KeyCode == Enum.KeyCode.Space then
			finishCast()
		end
	end)

	renderConn = RunService.RenderStepped:Connect(function(dt: number)
		if not activeToken or not needle then
			return
		end
		needlePos += needleDir * needleSpeed * dt
		if needlePos >= 0.97 then
			needlePos = 0.97
			needleDir = -1
		elseif needlePos <= 0.03 then
			needlePos = 0.03
			needleDir = 1
		end
		needle.Position = UDim2.fromScale(needlePos, 0.5)
	end)

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
		if not remotes then
			return
		end
		local sEv = remotes:WaitForChild("FishingStart", 15)
		local rEv = remotes:WaitForChild("FishingResult", 15)
		if rEv and rEv:IsA("RemoteEvent") then
			resultEv = rEv
		end
		if sEv and sEv:IsA("RemoteEvent") then
			sEv.OnClientEvent:Connect(function(token: number, speed: number)
				activeToken = token
				needlePos = 0.05
				needleDir = 1
				needleSpeed = if typeof(speed) == "number" then speed else 1.65
				if statusLabel then
					statusLabel.Text = "🎣 FISHING PORT PIER — HIT GOLD FOR RARE CATCH!"
					statusLabel.TextColor3 = Color3.fromRGB(255, 232, 118)
				end
				if panel then
					panel.Visible = true
				end
			end)
		end
	end)
end

return FishingController
