--!strict

local TweenService = game:GetService("TweenService")

local FeedbackController = {}

local hostGui: ScreenGui? = nil
local lastCoins: number? = nil
local lastRep: number? = nil

local function spawnFloatingPopup(text: string, color: Color3, xOffset: number): ()
	if not hostGui then
		return
	end

	local pop = Instance.new("TextLabel")
	pop.AnchorPoint = Vector2.new(0.5, 0.5)
	pop.Position = UDim2.new(0.5, xOffset, 0.34, 0)
	pop.Size = UDim2.fromOffset(220, 34)
	pop.BackgroundTransparency = 1
	pop.Font = Enum.Font.GothamBlack
	pop.Text = text
	pop.TextSize = 22
	pop.TextColor3 = color
	pop.TextStrokeTransparency = 0.15
	pop.ZIndex = 20
	pop.Parent = hostGui

	local tween = TweenService:Create(
		pop,
		TweenInfo.new(1.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = UDim2.new(0.5, xOffset, 0.22, 0),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	tween:Play()
	tween.Completed:Connect(function()
		if pop.Parent then
			pop:Destroy()
		end
	end)
end

function FeedbackController.Init(parentGui: ScreenGui): ()
	hostGui = parentGui
end

function FeedbackController.OnStateUpdate(state: { [string]: any }): ()
	local profile = state.Profile
	if typeof(profile) ~= "table" then
		return
	end

	local coins = profile.Coins
	local rep = profile.Reputation

	if typeof(coins) == "number" then
		if lastCoins ~= nil and coins > lastCoins then
			spawnFloatingPopup(string.format("+%d Coins!", coins - lastCoins), Color3.fromRGB(255, 224, 72), -45)
		end
		lastCoins = coins
	end

	if typeof(rep) == "number" then
		if lastRep ~= nil and rep > lastRep then
			spawnFloatingPopup(string.format("+%d Rep!", rep - lastRep), Color3.fromRGB(204, 146, 255), 55)
		end
		lastRep = rep
	end
end

return FeedbackController
