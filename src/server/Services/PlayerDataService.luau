--!strict

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require("./BaseService")
local WarehouseService = require("./WarehouseService")

export type PlayerProfile = {
	Coins: number,
	EXP: number,
	Level: number,
	Reputation: number,
	RestaurantLevel: number,
	DefenseLevel: number,
	CrewCount: number,
	RaiderCount: number,
	BodyguardCount: number,
	OwnsMotorbike: boolean,
	OwnedWeapons: { [string]: boolean },
	HasKevlarVest: boolean,
	Armor: number,
}

export type ProfileChangedCallback = (player: Player, profile: PlayerProfile) -> ()

local PlayerDataService = {}

local DATASTORE_NAME = "FoodEmpire_PlayerData_v1"
local STARTER_COINS = 90
local EXP_PER_LEVEL = 120

local dataStore: GlobalDataStore? = nil
local profiles: { [Player]: PlayerProfile } = {}
local listeners: { ProfileChangedCallback } = {}
local isRunning = false
local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil

local function initDataStore(): ()
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok and store then
		dataStore = store
	else
		warn("[PlayerDataService] DataStore unavailable (Studio API Services disabled?); running session-only fallback.")
	end
end

local function createDefaultProfile(): PlayerProfile
	return {
		Coins = STARTER_COINS,
		EXP = 0,
		Level = 1,
		Reputation = 0,
		RestaurantLevel = 1,
		DefenseLevel = 1,
		CrewCount = 0,
		RaiderCount = 0,
		BodyguardCount = 0,
		OwnsMotorbike = false,
		OwnedWeapons = {},
		HasKevlarVest = false,
		Armor = 0,
	}
end

local function updateLeaderstats(player: Player, profile: PlayerProfile): ()
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
		ls = folder

		local coinsVal = Instance.new("IntValue")
		coinsVal.Name = "Coins"
		coinsVal.Parent = folder

		local repVal = Instance.new("IntValue")
		repVal.Name = "Reputation"
		repVal.Parent = folder

		local lvlVal = Instance.new("IntValue")
		lvlVal.Name = "Level"
		lvlVal.Parent = folder
	end

	local c = ls:FindFirstChild("Coins")
	if c and c:IsA("IntValue") then
		c.Value = math.floor(profile.Coins)
	end
	local r = ls:FindFirstChild("Reputation")
	if r and r:IsA("IntValue") then
		r.Value = math.floor(profile.Reputation)
	end
	local l = ls:FindFirstChild("Level")
	if l and l:IsA("IntValue") then
		l.Value = math.floor(profile.Level)
	end
end

local function notifyChanged(player: Player): ()
	local profile = profiles[player]
	if not profile then
		return
	end
	updateLeaderstats(player, profile)
	for _, cb in ipairs(listeners) do
		task.spawn(cb, player, profile)
	end
end

function PlayerDataService.OnProfileChanged(callback: ProfileChangedCallback): () -> ()
	table.insert(listeners, callback)
	return function()
		local idx = table.find(listeners, callback)
		if idx then
			table.remove(listeners, idx)
		end
	end
end

function PlayerDataService.GetProfile(player: Player): PlayerProfile
	local existing = profiles[player]
	if existing then
		return existing
	end
	local created = createDefaultProfile()
	profiles[player] = created
	updateLeaderstats(player, created)
	return created
end

function PlayerDataService.AddCoins(player: Player, amount: number): number
	if amount <= 0 then
		return PlayerDataService.GetProfile(player).Coins
	end
	local profile = PlayerDataService.GetProfile(player)
	profile.Coins += math.floor(amount)
	notifyChanged(player)
	return profile.Coins
end

function PlayerDataService.SpendCoins(player: Player, amount: number): boolean
	if amount <= 0 then
		return true
	end
	local profile = PlayerDataService.GetProfile(player)
	local cost = math.floor(amount)
	if profile.Coins < cost then
		return false
	end
	profile.Coins -= cost
	notifyChanged(player)
	return true
end

function PlayerDataService.AddRewards(player: Player, coins: number, exp: number, reputation: number): ()
	local profile = PlayerDataService.GetProfile(player)
	if coins > 0 then
		profile.Coins += math.floor(coins)
	end
	if reputation > 0 then
		profile.Reputation += math.floor(reputation)
	end
	if exp > 0 then
		profile.EXP += math.floor(exp)
		while profile.EXP >= profile.Level * EXP_PER_LEVEL do
			profile.EXP -= profile.Level * EXP_PER_LEVEL
			profile.Level += 1
			print(string.format("[PlayerDataService] %s leveled up to Level %d!", player.Name, profile.Level))
		end
	end
	notifyChanged(player)
end

function PlayerDataService.SetRestaurantLevel(player: Player, level: number): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.RestaurantLevel = math.clamp(math.floor(level), 1, 10)
	notifyChanged(player)
end

function PlayerDataService.SetDefenseLevel(player: Player, level: number): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.DefenseLevel = math.clamp(math.floor(level), 1, 3)
	local slot = BaseService.GetPlayerBaseSlot(player)
	if slot then
		BaseService.SetDefenseTier(slot, profile.DefenseLevel)
	end
	notifyChanged(player)
end

function PlayerDataService.SetCrewCount(player: Player, count: number): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.CrewCount = math.max(0, math.floor(count))
	notifyChanged(player)
end

function PlayerDataService.SetRaiderCount(player: Player, count: number): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.RaiderCount = math.clamp(math.floor(count), 0, 2)
	notifyChanged(player)
end

function PlayerDataService.SetBodyguardCount(player: Player, count: number): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.BodyguardCount = math.clamp(math.floor(count), 0, 2)
	notifyChanged(player)
end

function PlayerDataService.SetOwnsMotorbike(player: Player, owned: boolean): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.OwnsMotorbike = owned
	notifyChanged(player)
end

function PlayerDataService.UnlockWeapon(player: Player, weaponId: string): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.OwnedWeapons[weaponId] = true
	notifyChanged(player)
end

function PlayerDataService.SetHasKevlarVest(player: Player, owned: boolean): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.HasKevlarVest = owned
	profile.Armor = if owned then 100 else 0
	notifyChanged(player)
end

function PlayerDataService.SetArmor(player: Player, armorAmount: number): ()
	local profile = PlayerDataService.GetProfile(player)
	local clamped = math.clamp(math.floor(armorAmount), 0, 100)
	if profile.Armor == clamped and profile.HasKevlarVest == (clamped > 0) then
		return
	end
	profile.Armor = clamped
	profile.HasKevlarVest = (clamped > 0)
	notifyChanged(player)
end

-- Applies a 30% Gold and 30% Reputation penalty (and breaks remaining Armor) whenever the player dies!
function PlayerDataService.ApplyDeathPenalty(player: Player): (number, number)
	local profile = PlayerDataService.GetProfile(player)
	local lostGold = math.floor(profile.Coins * 0.30)
	local lostRep = math.floor(profile.Reputation * 0.30)
	profile.Coins = math.max(0, profile.Coins - lostGold)
	profile.Reputation = math.max(0, profile.Reputation - lostRep)
	profile.Armor = 0
	profile.HasKevlarVest = false
	notifyChanged(player)

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local toastEv = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if toastEv and toastEv:IsA("RemoteEvent") then
		toastEv:FireClient(
			player,
			string.format("💀 YOU DIED! Lost 30%% Gold (-%dG) & 30%% Reputation (-%d Rep)!", lostGold, lostRep)
		)
	end
	return lostGold, lostRep
end

local function hookPlayerDeathPenalty(player: Player): ()
	local function onCharacter(char: Model)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum and hum:IsA("Humanoid") then
			local penalized = false
			hum.Died:Connect(function()
				if penalized then return end
				penalized = true
				PlayerDataService.ApplyDeathPenalty(player)
			end)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

local function loadPlayer(player: Player): ()
	local profile = createDefaultProfile()
	local savedWarehouseLevels: { [string]: number }? = nil
	local savedWarehouseStock: { [string]: number }? = nil

	if dataStore then
		local key = "Player_" .. tostring(player.UserId)
		local ok, saved = pcall(function()
			return (dataStore :: GlobalDataStore):GetAsync(key)
		end)
		if ok and typeof(saved) == "table" then
			if typeof(saved.Coins) == "number" then profile.Coins = saved.Coins end
			if typeof(saved.EXP) == "number" then profile.EXP = saved.EXP end
			if typeof(saved.Level) == "number" then profile.Level = math.max(1, saved.Level) end
			if typeof(saved.Reputation) == "number" then profile.Reputation = saved.Reputation end
			if typeof(saved.RestaurantLevel) == "number" then profile.RestaurantLevel = math.clamp(saved.RestaurantLevel, 1, 10) end
			if typeof(saved.DefenseLevel) == "number" then profile.DefenseLevel = math.clamp(saved.DefenseLevel, 1, 3) end
			if typeof(saved.CrewCount) == "number" then profile.CrewCount = math.max(0, saved.CrewCount) end
			if typeof(saved.RaiderCount) == "number" then profile.RaiderCount = math.clamp(saved.RaiderCount, 0, 2) end
			if typeof(saved.BodyguardCount) == "number" then profile.BodyguardCount = math.clamp(saved.BodyguardCount, 0, 2) end
			if typeof(saved.OwnsMotorbike) == "boolean" then profile.OwnsMotorbike = saved.OwnsMotorbike end
			if typeof(saved.Armor) == "number" then
				profile.Armor = math.clamp(math.floor(saved.Armor), 0, 100)
				profile.HasKevlarVest = (profile.Armor > 0)
			elseif typeof(saved.HasKevlarVest) == "boolean" then
				profile.HasKevlarVest = false
				profile.Armor = 0
			end
			if typeof(saved.OwnedWeapons) == "table" then
				for wid, val in pairs(saved.OwnedWeapons) do
					if typeof(wid) == "string" and val == true then
						profile.OwnedWeapons[wid] = true
					end
				end
			end
			if typeof(saved.WarehouseLevels) == "table" then savedWarehouseLevels = saved.WarehouseLevels end
			if typeof(saved.WarehouseStock) == "table" then savedWarehouseStock = saved.WarehouseStock end
		end
	end

	profiles[player] = profile
	WarehouseService.LoadPlayerState(player, savedWarehouseLevels, savedWarehouseStock)

	local slot = BaseService.GetPlayerBaseSlot(player)
	if slot then
		BaseService.SetDefenseTier(slot, profile.DefenseLevel)
	end

	notifyChanged(player)
end

local function savePlayer(player: Player): ()
	local profile = profiles[player]
	if not profile or not dataStore then
		return
	end

	local snapshot = WarehouseService.GetInventorySnapshot(player)
	local payload = {
		Coins = profile.Coins,
		EXP = profile.EXP,
		Level = profile.Level,
		Reputation = profile.Reputation,
		RestaurantLevel = profile.RestaurantLevel,
		DefenseLevel = profile.DefenseLevel,
		CrewCount = profile.CrewCount,
		RaiderCount = profile.RaiderCount,
		BodyguardCount = profile.BodyguardCount,
		OwnsMotorbike = profile.OwnsMotorbike,
		HasKevlarVest = profile.HasKevlarVest,
		Armor = profile.Armor,
		OwnedWeapons = profile.OwnedWeapons,
		WarehouseLevels = snapshot.Levels,
		WarehouseStock = snapshot.Stock,
	}

	local key = "Player_" .. tostring(player.UserId)
	local ok, err = pcall(function()
		(dataStore :: GlobalDataStore):SetAsync(key, payload)
	end)
	if not ok then
		warn("[PlayerDataService] Failed to save data for", player.Name, ":", err)
	end
end

function PlayerDataService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	initDataStore()
	WarehouseService.SetSpendCoinsHandler(PlayerDataService.SpendCoins)

	BaseService.OnBaseAssigned(function(player, slot)
		local profile = PlayerDataService.GetProfile(player)
		BaseService.SetDefenseTier(slot, profile.DefenseLevel)
		notifyChanged(player)
	end)

	playerAddedConn = Players.PlayerAdded:Connect(function(player)
		loadPlayer(player)
		hookPlayerDeathPenalty(player)
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		savePlayer(player)
		profiles[player] = nil
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayer(player)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		loadPlayer(player)
		hookPlayerDeathPenalty(player)
	end

	print("[Food Empire] PlayerDataService started (Coins, EXP, Reputation, Upgrades & DataStore persistence)!")
end

function PlayerDataService.Stop(): ()
	isRunning = false
	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
end

return PlayerDataService
