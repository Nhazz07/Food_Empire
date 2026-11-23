--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local playerScripts = script.Parent :: Instance
local controllersFolder = playerScripts:WaitForChild("Controllers")

local HUDController = require(controllersFolder:WaitForChild("HUDController"))
local EmpireMenuController = require(controllersFolder:WaitForChild("EmpireMenuController"))
local MinimapController = require(controllersFolder:WaitForChild("MinimapController"))
local FeedbackController = require(controllersFolder:WaitForChild("FeedbackController"))
local WaypointController = require(controllersFolder:WaitForChild("WaypointController"))
local AmbientEffectsController = require(controllersFolder:WaitForChild("AmbientEffectsController"))
local CentralNPCController = require(controllersFolder:WaitForChild("CentralNPCController"))
local AudioController = require(controllersFolder:WaitForChild("AudioController"))
local MotorbikeController = require(controllersFolder:WaitForChild("MotorbikeController"))
local BaseSelectController = require(controllersFolder:WaitForChild("BaseSelectController"))
local FishingController = require(controllersFolder:WaitForChild("FishingController"))
local WeaponController = require(controllersFolder:WaitForChild("WeaponController"))
local NightController = require(controllersFolder:WaitForChild("NightController"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stateSync = remotes:WaitForChild("StateSync") :: RemoteEvent
local actionRequest = remotes:WaitForChild("ActionRequest") :: RemoteFunction

local lastPrintedReceiptNo = 0

local function applyState(state: { [string]: any }): ()
	local latest = state.LatestReceipt
	if typeof(latest) == "table" and typeof(latest.OrderNo) == "number" and latest.OrderNo > lastPrintedReceiptNo then
		lastPrintedReceiptNo = latest.OrderNo
		AudioController.PlayCoins()
	end
	HUDController.Update(state)
	EmpireMenuController.Update(state)
	MinimapController.Update(state)
	FeedbackController.OnStateUpdate(state)
	WaypointController.Update(state)
	BaseSelectController.Update(state)
end

local function sendAction(action: string, arg: any?): ()
	local ok, response = pcall(function()
		return actionRequest:InvokeServer(action, arg)
	end)
	if not ok or typeof(response) ~= "table" then
		HUDController.ShowToast("Action failed—try again!", true)
		return
	end

	if typeof(response.State) == "table" then
		applyState(response.State)
	end
	if response.Message == "LOCKED_BIKE" then
		AudioController.PlayClick()
		HUDController.ShowToast("Unlock the Sport Motorbike for 750 Gold OR 79 R$!", false)
		EmpireMenuController.ToggleTab("Shop")
		return
	end
	if typeof(response.Message) == "string" and response.Message ~= "OK" then
		HUDController.ShowToast(response.Message, not response.Success)
	end
	if not response.Success then
		AudioController.PlayError()
	elseif action == "ServeFood" then
		AudioController.PlayCoins()
	elseif action == "CookRecipe" or action == "ServeCustomerOrder" then
		AudioController.PlayCook()
	elseif action == "BuyRobuxItem" or action == "BuyMotorbikeCoins" or action == "ChooseBase" or action == "UpgradeRestaurant" or action == "UpgradeDefenses" or action == "UpgradeWarehouse" or action == "HireCrew" or action == "HireRaider" or action == "HireBodyguard" or action == "DispatchDeliveryRunner" or action == "BuyBlackMarketItem" or action == "SkipDayNight" then
		AudioController.PlayFanfare()
	elseif action ~= "GetState" and action ~= "SetSprint" then
		AudioController.PlayClick()
	end
end

local function openAndVisitBlackMarket(): ()
	AudioController.PlayClick()
	task.spawn(sendAction, "TeleportBlackMarket", nil)
	EmpireMenuController.ToggleTab("BlackMarket")
end

-- Initialize HUD, Tabbed Empire Menu, Minimap, Feedback VFX, Guide Arrow & Ambient Windmill/Boats
local hudGui = HUDController.Init(function(tab)
	if tab == "BlackMarket" then
		openAndVisitBlackMarket()
		return
	end
	AudioController.PlayClick()
	EmpireMenuController.ToggleTab(tab)
end, function()
	sendAction("ServeFood", nil)
end, function()
	sendAction("ReturnHome", nil)
end, function()
	sendAction("ToggleScooter", nil)
end, function()
	sendAction("AcceptExpressDelivery", nil)
end)

EmpireMenuController.Init(hudGui, sendAction)
BaseSelectController.Init(hudGui, function(slot)
	sendAction("ChooseBase", slot)
end)
MinimapController.Init(hudGui)
FeedbackController.Init(hudGui)
FishingController.Init(hudGui)
NightController.Init(hudGui, function()
	sendAction("SkipDayNight", nil)
end)
WaypointController.Start()
AmbientEffectsController.Start()
CentralNPCController.Start()
MotorbikeController.Start()
WeaponController.Start(function()
	EmpireMenuController.ToggleTab("BlackMarket")
end)

-- Keyboard shortcuts (C = Kitchen, B = Warehouses, U = Upgrades, H = Base, G = Guide Arrow, LeftShift = Sprint)
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.C then
		EmpireMenuController.ToggleTab("Kitchen")
	elseif input.KeyCode == Enum.KeyCode.B then
		EmpireMenuController.ToggleTab("Warehouses")
	elseif input.KeyCode == Enum.KeyCode.U then
		AudioController.PlayClick()
		EmpireMenuController.ToggleTab("Upgrades")
	elseif input.KeyCode == Enum.KeyCode.P then
		AudioController.PlayClick()
		EmpireMenuController.ToggleTab("Shop")
	elseif input.KeyCode == Enum.KeyCode.M then
		openAndVisitBlackMarket()
	elseif input.KeyCode == Enum.KeyCode.N then
		sendAction("SkipDayNight", nil)
	elseif input.KeyCode == Enum.KeyCode.H then
		sendAction("ReturnHome", nil)
	elseif input.KeyCode == Enum.KeyCode.V then
		sendAction("ToggleScooter", nil)
	elseif input.KeyCode == Enum.KeyCode.G then
		local on = WaypointController.Toggle()
		HUDController.ShowToast(if on then "Objective Guide Arrow: ON" else "Objective Guide Arrow: OFF", false)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		task.spawn(sendAction, "SetSprint", true)
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		task.spawn(sendAction, "SetSprint", false)
	end
end)

stateSync.OnClientEvent:Connect(function(state: { [string]: any })
	if typeof(state) == "table" then
		applyState(state)
	end
end)

task.spawn(function()
	local milestoneEv = remotes:WaitForChild("MilestoneToast", 10)
	if milestoneEv and milestoneEv:IsA("RemoteEvent") then
		milestoneEv.OnClientEvent:Connect(function(msg: string)
			AudioController.PlayFanfare()
			HUDController.ShowToast(msg, false)
		end)
	end
end)

task.spawn(function()
	sendAction("GetState", nil)
end)

print("[Food Empire] All Client Controllers active (HUD, Menu, Minimap, Feedback, Waypoint, Sprint & Base Return) for", Players.LocalPlayer.Name)
