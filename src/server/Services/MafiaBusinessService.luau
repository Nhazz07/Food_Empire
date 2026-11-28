--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require("./PlayerDataService")

export type BusinessSpec = {
	Id: string,
	DisplayName: string,
	Cost: number,
	PerkLabel: string,
	CycleGold: number,
	CycleRep: number,
	MaxSafeGold: number,
	Position: Vector3,
	AccentColor: Color3,
}

local MafiaBusinessService = {}

MafiaBusinessService.ORDER = {
	"HarborCannery",
	"DowntownLounge",
	"BackAlleyArms",
}

MafiaBusinessService.SPECS = {
	HarborCannery = {
		Id = "HarborCannery",
		DisplayName = "Harbor Fish Cannery",
		Cost = 3750,
		PerkLabel = "+25% Fish Production + Passive Wall Safe",
		CycleGold = 38,
		CycleRep = 6,
		MaxSafeGold = 450,
		Position = Vector3.new(212, 1.35, 198),
		AccentColor = Color3.fromRGB(68, 108, 146),
	},
	DowntownLounge = {
		Id = "DowntownLounge",
		DisplayName = "Downtown Espresso & Cigar Lounge",
		Cost = 4500,
		PerkLabel = "+15% Waiter Tips + Passive Wall Safe & Rep",
		CycleGold = 48,
		CycleRep = 10,
		MaxSafeGold = 550,
		Position = Vector3.new(-210, 1.35, -198),
		AccentColor = Color3.fromRGB(168, 134, 72),
	},
	BackAlleyArms = {
		Id = "BackAlleyArms",
		DisplayName = "Back-Alley Arms & Butcher Syndicate",
		Cost = 5500,
		PerkLabel = "-20% Black Market Ammo Cost + Passive Wall Safe",
		CycleGold = 60,
		CycleRep = 10,
		MaxSafeGold = 650,
		Position = Vector3.new(-214, 1.35, 190),
		AccentColor = Color3.fromRGB(142, 36, 44),
	},
} :: { [string]: BusinessSpec }

local safeGoldByPlayer: { [Player]: { [string]: number } } = {}
local safeRepByPlayer: { [Player]: { [string]: number } } = {}
local folder: Folder? = nil
local isRunning = false
local tickThread: thread? = nil
local playerRemovingConn: RBXScriptConnection? = nil

local function ensureSafeMaps(player: Player): ({ [string]: number }, { [string]: number })
	local g = safeGoldByPlayer[player]
	if not g then
		g = {}
		safeGoldByPlayer[player] = g
	end
	local r = safeRepByPlayer[player]
	if not r then
		r = {}
		safeRepByPlayer[player] = r
	end
	return g, r
end

function MafiaBusinessService.BuyBusiness(player: Player, businessId: string): (boolean, string)
	local spec = MafiaBusinessService.SPECS[businessId]
	if not spec then
		return false, "Unknown Mafia Front Business!"
	end
	if PlayerDataService.HasBusiness(player, businessId) then
		return false, spec.DisplayName .. " is already owned! Collect cash from its Wall Safe."
	end
	if not PlayerDataService.SpendCoins(player, spec.Cost) then
		return false, string.format("Need %d Gold to acquire %s!", spec.Cost, spec.DisplayName)
	end
	PlayerDataService.SetOwnedBusiness(player, businessId, true)
	local gMap, rMap = ensureSafeMaps(player)
	gMap[businessId] = spec.CycleGold
	rMap[businessId] = spec.CycleRep
	return true, string.format("Acquired %s! (%s)", spec.DisplayName, spec.PerkLabel)
end

function MafiaBusinessService.CollectSafe(player: Player, businessId: string?): (boolean, string)
	local gMap, rMap = ensureSafeMaps(player)
	local totalG = 0
	local totalR = 0
	local ids = if typeof(businessId) == "string" and MafiaBusinessService.SPECS[businessId]
		then { businessId }
		else MafiaBusinessService.ORDER

	for _, bid in ipairs(ids) do
		if PlayerDataService.HasBusiness(player, bid) then
			local g = gMap[bid] or 0
			local r = rMap[bid] or 0
			if g > 0 or r > 0 then
				totalG += g
				totalR += r
				gMap[bid] = 0
				rMap[bid] = 0
			end
		end
	end

	if totalG <= 0 and totalR <= 0 then
		return false, "Business Wall Safes are empty right now — check back in 20s!"
	end
	PlayerDataService.AddRewards(player, totalG, math.floor(totalG * 0.25), totalR)
	return true, string.format("Collected +%d Gold & +%d Rep from your Mafia Front Business Safes!", totalG, totalR)
end

function MafiaBusinessService.GetSnapshot(player: Player): { [string]: any }
	local gMap = safeGoldByPlayer[player] or {}
	local out: { { [string]: any } } = {}
	for _, bid in ipairs(MafiaBusinessService.ORDER) do
		local spec = MafiaBusinessService.SPECS[bid]
		table.insert(out, {
			Id = spec.Id,
			DisplayName = spec.DisplayName,
			Cost = spec.Cost,
			PerkLabel = spec.PerkLabel,
			Owned = PlayerDataService.HasBusiness(player, bid),
			SafeGold = gMap[bid] or 0,
			MaxSafeGold = spec.MaxSafeGold,
		})
	end
	return out
end

local function buildStorefronts(): ()
	for _, bid in ipairs(MafiaBusinessService.ORDER) do
		local spec = MafiaBusinessService.SPECS[bid]
		local m = Instance.new("Model")
		m.Name = "MafiaBusiness_" .. bid
		local cf = CFrame.lookAt(spec.Position, Vector3.new(0, spec.Position.Y, 0))

		local function bPart(name: string, sz: Vector3, rel: CFrame, col: Color3, mat: Enum.Material): Part
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

		local shell = bPart("StorefrontHull", Vector3.new(18, 10, 14), CFrame.new(0, 5, 0), Color3.fromRGB(24, 26, 32), Enum.Material.Brick)
		bPart("TrimRoof", Vector3.new(18.8, 0.9, 14.8), CFrame.new(0, 10.4, 0), spec.AccentColor, Enum.Material.Metal)
		local safe = bPart("WallSafe", Vector3.new(3.2, 3.6, 1.4), CFrame.new(0, 3.2, -7.2), Color3.fromRGB(42, 46, 54), Enum.Material.Metal)
		bPart("SafeDial", Vector3.new(0.4, 1.2, 1.2), CFrame.new(0, 3.2, -8.0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(184, 148, 76), Enum.Material.Metal)

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(280, 42)
		bb.StudsOffset = Vector3.new(0, 8.2, 0)
		bb.MaxDistance = 240
		bb.Parent = shell
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
		lbl.BackgroundTransparency = 0.08
		lbl.Font = Enum.Font.GothamBlack
		lbl.Text = string.format("%s  |  WALL SAFE [E]", string.upper(spec.DisplayName))
		lbl.TextSize = 11
		lbl.TextColor3 = Color3.fromRGB(232, 200, 128)
		lbl.Parent = bb
		Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 5)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BusinessSafePrompt"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.ActionText = string.format("Buy / Collect Wall Safe (%s)", spec.DisplayName)
		prompt.ObjectText = "Mafia Front Business"
		prompt.Parent = safe

		prompt.Triggered:Connect(function(player: Player)
			local _, msg
			if PlayerDataService.HasBusiness(player, bid) then
				_, msg = MafiaBusinessService.CollectSafe(player, bid)
			else
				_, msg = MafiaBusinessService.BuyBusiness(player, bid)
			end
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
			if ev and ev:IsA("RemoteEvent") then
				ev:FireClient(player, msg)
			end
		end)

		m.PrimaryPart = shell
		m.Parent = folder or Workspace
	end
end

function MafiaBusinessService.Start(): ()
	if isRunning then return end
	isRunning = true

	local existing = Workspace:FindFirstChild("MafiaFrontBusinesses")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		folder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "MafiaFrontBusinesses"
		f.Parent = Workspace
		folder = f
	end

	buildStorefronts()

	playerRemovingConn = Players.PlayerRemoving:Connect(function(p: Player)
		safeGoldByPlayer[p] = nil
		safeRepByPlayer[p] = nil
	end)

	tickThread = task.spawn(function()
		while isRunning do
			task.wait(20)
			if not isRunning then break end
			for _, p in ipairs(Players:GetPlayers()) do
				local gMap, rMap = ensureSafeMaps(p)
				for _, bid in ipairs(MafiaBusinessService.ORDER) do
					if PlayerDataService.HasBusiness(p, bid) then
						local spec = MafiaBusinessService.SPECS[bid]
						gMap[bid] = math.min(spec.MaxSafeGold, (gMap[bid] or 0) + spec.CycleGold)
						rMap[bid] = math.min(200, (rMap[bid] or 0) + spec.CycleRep)
					end
				end
			end
		end
	end)

	print("[Food Empire] MafiaBusinessService started (3 Ownable Mafia Front Businesses + Wall Safes active)!")
end

function MafiaBusinessService.Stop(): ()
	isRunning = false
	if tickThread then task.cancel(tickThread); tickThread = nil end
	if playerRemovingConn then playerRemovingConn:Disconnect(); playerRemovingConn = nil end
end

return MafiaBusinessService
