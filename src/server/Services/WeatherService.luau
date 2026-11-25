--!strict

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require("./PlayerDataService")

export type WeatherId = "ClearNoir" | "NoirRainstorm" | "HarborFog" | "MidnightBlackout"

type WeatherSpec = {
	Id: WeatherId,
	Title: string,
	BonusDesc: string,
	FogEnd: number,
	FogColor: Color3,
}

local WeatherService = {}

local WEATHER_ORDER: { WeatherId } = { "ClearNoir", "NoirRainstorm", "HarborFog", "MidnightBlackout" }
local WEATHERS: { [WeatherId]: WeatherSpec } = {
	ClearNoir = {
		Id = "ClearNoir",
		Title = "CLEAR NOIR NIGHT",
		BonusDesc = "Standard visibility across Central Plaza & Corner Territories.",
		FogEnd = 1600,
		FogColor = Color3.fromRGB(20, 24, 34),
	},
	NoirRainstorm = {
		Id = "NoirRainstorm",
		Title = "NOIR RAINSTORM",
		BonusDesc = "+30% Gold on Hot Comfort Dishes (Steaks, Ribs, Platters) + Stealth Rain!",
		FogEnd = 620,
		FogColor = Color3.fromRGB(16, 20, 28),
	},
	HarborFog = {
		Id = "HarborFog",
		Title = "HARBOR MIST & FOG",
		BonusDesc = "2x Rare Catch Odds (Golden Tuna & King Crab) at Fishing Port!",
		FogEnd = 360,
		FogColor = Color3.fromRGB(38, 44, 54),
	},
	MidnightBlackout = {
		Id = "MidnightBlackout",
		Title = "MIDNIGHT BLACKOUT",
		BonusDesc = "Armored Syndicate Bullion Truck spawned in Central District (+480G & +65 Rep)!",
		FogEnd = 480,
		FogColor = Color3.fromRGB(8, 10, 14),
	},
}

local currentIdx = 1
local currentWeather: WeatherId = "ClearNoir"
local isRunning = false
local loopThread: thread? = nil
local truckModel: Model? = nil
local truckRaidedBy: { [Player]: boolean } = {}

local function broadcastToast(msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireAllClients(msg)
	end
end

local function clearBullionTruck(): ()
	if truckModel and truckModel.Parent then
		truckModel:Destroy()
	end
	truckModel = nil
	table.clear(truckRaidedBy)
end

local function spawnBullionTruck(): ()
	clearBullionTruck()
	local m = Instance.new("Model")
	m.Name = "BlackoutBullionTruck"
	local cf = CFrame.new(-48, 2.2, 48) * CFrame.Angles(0, math.rad(42), 0)

	local function tPart(name: string, sz: Vector3, rel: CFrame, col: Color3, mat: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = cf * rel
		p.Color = col
		p.Material = mat
		p.Anchored = true
		p.CanCollide = true
		p.Parent = m
		return p
	end

	local body = tPart("ArmoredHull", Vector3.new(7.4, 5.2, 13.5), CFrame.new(0, 3.4, 0), Color3.fromRGB(20, 22, 28), Enum.Material.Metal)
	tPart("ArmoredCab", Vector3.new(6.8, 4.4, 4.5), CFrame.new(0, 3.0, -8.5), Color3.fromRGB(26, 28, 34), Enum.Material.Metal)
	tPart("GoldStripe", Vector3.new(7.6, 0.5, 13.6), CFrame.new(0, 3.4, 0), Color3.fromRGB(184, 146, 74), Enum.Material.Metal)
	tPart("RedBeacon", Vector3.new(1.2, 0.8, 1.2), CFrame.new(0, 6.4, -7.2), Color3.fromRGB(204, 38, 44), Enum.Material.Neon)

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(290, 42)
	bb.StudsOffset = Vector3.new(0, 6.2, 0)
	bb.MaxDistance = 280
	bb.Parent = body
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
	lbl.BackgroundTransparency = 0.06
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = "BLACKOUT BULLION TRUCK  |  +480G & +65 REP  [E]"
	lbl.TextSize = 11
	lbl.TextColor3 = Color3.fromRGB(240, 202, 122)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 6)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RaidBullionTruckPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.ActionText = "Raid Blackout Bullion Truck (+480G & +65 Rep)"
	prompt.ObjectText = "Armored Syndicate Transport"
	prompt.Parent = body
	prompt.Triggered:Connect(function(player: Player)
		local _, msg = WeatherService.TryRaidBlackoutTruck(player)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
		if ev and ev:IsA("RemoteEvent") then
			ev:FireClient(player, msg)
		end
	end)

	m.PrimaryPart = body
	m.Parent = Workspace
	truckModel = m
end

local function applyWeather(wid: WeatherId): ()
	currentWeather = wid
	local spec = WEATHERS[wid]
	Lighting.FogEnd = spec.FogEnd
	Lighting.FogColor = spec.FogColor

	ReplicatedStorage:SetAttribute("ActiveWeatherId", spec.Id)
	ReplicatedStorage:SetAttribute("ActiveWeatherTitle", spec.Title)
	ReplicatedStorage:SetAttribute("ActiveWeatherBonus", spec.BonusDesc)
	ReplicatedStorage:SetAttribute("HotComfortWeatherMult", if wid == "NoirRainstorm" then 1.30 else 1.0)
	ReplicatedStorage:SetAttribute("DoubleRareCatch", wid == "HarborFog")

	if wid == "MidnightBlackout" then
		spawnBullionTruck()
	else
		clearBullionTruck()
	end
	broadcastToast(string.format("CITY WEATHER: %s — %s", spec.Title, spec.BonusDesc))
end

function WeatherService.GetSnapshot(): { [string]: any }
	local spec = WEATHERS[currentWeather]
	return {
		Id = spec.Id,
		Title = spec.Title,
		BonusDesc = spec.BonusDesc,
		BlackoutTruckActive = (truckModel ~= nil and truckModel.Parent ~= nil),
	}
end

function WeatherService.TryRaidBlackoutTruck(player: Player): (boolean, string)
	if currentWeather ~= "MidnightBlackout" or not truckModel or not truckModel.Parent then
		return false, "Wait for a Midnight Blackout weather event for the Armored Bullion Truck!"
	end
	if truckRaidedBy[player] then
		return false, "You already raided this Blackout Bullion Truck!"
	end
	truckRaidedBy[player] = true
	PlayerDataService.AddRewards(player, 260, 120, 45)
	player:SetAttribute("StolenShipmentUntil", os.clock() + 30)
	return true, "BLACKOUT BULLION HEIST COMPLETE! +260 Gold & +45 Rep!"
end

function WeatherService.CycleWeather(): (boolean, string)
	currentIdx = (currentIdx % #WEATHER_ORDER) + 1
	applyWeather(WEATHER_ORDER[currentIdx])
	local spec = WEATHERS[currentWeather]
	return true, string.format("Weather shifted to %s!", spec.Title)
end

function WeatherService.Start(): ()
	if isRunning then return end
	isRunning = true
	applyWeather("ClearNoir")

	loopThread = task.spawn(function()
		while isRunning do
			task.wait(110)
			if not isRunning then break end
			WeatherService.CycleWeather()
		end
	end)
	print("[Food Empire] WeatherService started (Noir Rainstorm, Harbor Fog & Midnight Blackout Bullion Truck active)!")
end

function WeatherService.Stop(): ()
	isRunning = false
	if loopThread then task.cancel(loopThread); loopThread = nil end
	clearBullionTruck()
end

return WeatherService
