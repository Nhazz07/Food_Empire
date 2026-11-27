--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require("./BaseService")
local SectorService = require("./SectorService")
local WarehouseService = require("./WarehouseService")
local PlayerDataService = require("./PlayerDataService")

export type MilestoneSpec = {
	Id: string,
	Title: string,
	Coins: number,
	Exp: number,
	Rep: number,
}

local MilestoneService = {}

local MILESTONES: { [string]: MilestoneSpec } = {
	FirstCapture = { Id = "FirstCapture", Title = "First Territory Captured!", Coins = 100, Exp = 30, Rep = 20 },
	DoubleTerritory = { Id = "DoubleTerritory", Title = "Island Expansion (2+ Sectors)!", Coins = 350, Exp = 80, Rep = 60 },
	FreshSupply = { Id = "FreshSupply", Title = "Stocked Warehouses (20+ Items)!", Coins = 120, Exp = 35, Rep = 20 },
	FirstUpgrade = { Id = "FirstUpgrade", Title = "Empire Builder (First Upgrade)!", Coins = 180, Exp = 50, Rep = 30 },
	RisingChef = { Id = "RisingChef", Title = "Rising Chef (50+ Reputation)!", Coins = 250, Exp = 60, Rep = 35 },
	FoodEmperor = { Id = "FoodEmperor", Title = "CROWNED FOOD EMPEROR (250+ Rep)!", Coins = 600, Exp = 150, Rep = 100 },
}

local completed: { [Player]: { [string]: boolean } } = {}
local isRunning = false
local unsubSector: (() -> ())? = nil
local unsubWarehouse: (() -> ())? = nil
local unsubProfile: (() -> ())? = nil
local playerRemovingConn: RBXScriptConnection? = nil

local function awardMilestone(player: Player, milestoneId: string): ()
	local spec = MILESTONES[milestoneId]
	if not spec or not player.Parent then
		return
	end

	local done = completed[player]
	if not done then
		done = {}
		completed[player] = done
	end
	if done[milestoneId] then
		return
	end
	done[milestoneId] = true

	PlayerDataService.AddRewards(player, spec.Coins, spec.Exp, spec.Rep)

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local toastEvent = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if toastEvent and toastEvent:IsA("RemoteEvent") then
		toastEvent:FireClient(
			player,
			string.format("MILESTONE: %s (+%d Coins, +%d Rep)", spec.Title, spec.Coins, spec.Rep)
		)
	end

	print(string.format("[MilestoneService] %s completed %s!", player.Name, spec.Title))
end

local function checkSectorMilestones(ownerId: string): ()
	local owners = BaseService.GetPlayersForFaction(ownerId)
	if #owners == 0 then
		return
	end

	local ownedCount = #SectorService.GetOwnedSectors(ownerId)
	for _, player in ipairs(owners) do
		if ownedCount >= 1 then
			awardMilestone(player, "FirstCapture")
		end
		if ownedCount >= 2 then
			awardMilestone(player, "DoubleTerritory")
		end
	end
end

function MilestoneService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		local f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
		remotes = f
	end
	if not remotes:FindFirstChild("MilestoneToast") then
		local ev = Instance.new("RemoteEvent")
		ev.Name = "MilestoneToast"
		ev.Parent = remotes
	end

	unsubSector = SectorService.OnSectorChanged(function(_, sector)
		if sector.Status == "Controlled" and (string.sub(sector.Owner, 1, 7) == "Player_" or string.sub(sector.Owner, 1, 5) == "Base_") then
			checkSectorMilestones(sector.Owner)
		end
	end)

	unsubWarehouse = WarehouseService.OnInventoryChanged(function(player, snapshot)
		local total = 0
		for _, v in pairs(snapshot.CategoryTotals) do
			total += v
		end
		if total >= 20 then
			awardMilestone(player, "FreshSupply")
		end
		for _, lv in pairs(snapshot.Levels) do
			if lv >= 2 then
				awardMilestone(player, "FirstUpgrade")
				break
			end
		end
	end)

	unsubProfile = PlayerDataService.OnProfileChanged(function(player, profile)
		if profile.RestaurantLevel >= 2 or profile.DefenseLevel >= 2 or profile.CrewCount >= 1 then
			awardMilestone(player, "FirstUpgrade")
		end
		if profile.Reputation >= 50 then
			awardMilestone(player, "RisingChef")
		end
		if profile.Reputation >= 250 then
			awardMilestone(player, "FoodEmperor")
		end
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		completed[player] = nil
	end)

	print("[Food Empire] MilestoneService started (6 Empire Progression Milestones active)!")
end

function MilestoneService.Stop(): ()
	isRunning = false
	if unsubSector then unsubSector(); unsubSector = nil end
	if unsubWarehouse then unsubWarehouse(); unsubWarehouse = nil end
	if unsubProfile then unsubProfile(); unsubProfile = nil end
	if playerRemovingConn then playerRemovingConn:Disconnect(); playerRemovingConn = nil end
	table.clear(completed)
end

return MilestoneService
