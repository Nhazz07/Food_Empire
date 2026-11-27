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
	WaiterCount: number,
	CourierCount: number,
	OwnsCentralParkBranch: boolean,
	CentralParkBranchStaffed: boolean,
	LastFreeSpinAt: number,
	RaiderCount: number,
	BodyguardCount: number,
	OwnsMotorbike: boolean,
	OwnedWeapons: { [string]: boolean },
	HasKevlarVest: boolean,
	Armor: number,
	AmmoInventory: { [string]: number },
	ActiveBodyguards: { string },
	UnlockedGuardClasses: { [string]: boolean },
	OwnedGuardGear: { [string]: boolean },
	GuardLoadouts: { [string]: { [string]: string } },
	HasDualStove: boolean,
	HasVIPBooths: boolean,
	OwnsMafiaSedan: boolean,
	GuardStance: string,
	WeaponMods: { [string]: { [string]: boolean } },
	OwnedBusinesses: { [string]: boolean },
	MenuPricing: string,
	SmokeGrenades: number,
	Flashbangs: number,
	C4Charges: number,
	HasShadowDash: boolean,
	WeaponKills: { [string]: number },
	WeaponSkins: { [string]: string },
	HasPenthouseTrophy: boolean,
	OwnsArmoredVan: boolean,
	OwnsGetawayCoupe: boolean,
	HasVehicleArmor: boolean,
	VehiclePaint: string,
	DailyStreak: number,
	LastDailyClaimDay: number,
	PrestigeLevel: number,
	TotalDishesServed: number,
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
		WaiterCount = 0,
		CourierCount = 0,
		OwnsCentralParkBranch = false,
		CentralParkBranchStaffed = false,
		LastFreeSpinAt = 0,
		RaiderCount = 0,
		BodyguardCount = 0,
		OwnsMotorbike = false,
		OwnedWeapons = {},
		HasKevlarVest = false,
		Armor = 0,
		AmmoInventory = {
			Pistol9mm = 60,
			Shotgun12G = 24,
			SMG45 = 120,
			Rifle556 = 90,
			Sniper308 = 20,
		},
		ActiveBodyguards = {},
		UnlockedGuardClasses = {},
		OwnedGuardGear = {},
		GuardLoadouts = {},
		HasDualStove = false,
		HasVIPBooths = false,
		OwnsMafiaSedan = false,
		GuardStance = "Follow",
		WeaponMods = {},
		OwnedBusinesses = {},
		MenuPricing = "Standard",
		SmokeGrenades = 2,
		Flashbangs = 0,
		C4Charges = 0,
		HasShadowDash = false,
		WeaponKills = {},
		WeaponSkins = {},
		HasPenthouseTrophy = false,
		OwnsArmoredVan = false,
		OwnsGetawayCoupe = false,
		HasVehicleArmor = false,
		VehiclePaint = "Obsidian",
		DailyStreak = 0,
		LastDailyClaimDay = 0,
		PrestigeLevel = 0,
		TotalDishesServed = 0,
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

-- Deducts up to `amount` coins clamped strictly >= 0 (never negative); returns actual amount deducted.
function PlayerDataService.DeductCoinsClamped(player: Player, amount: number): number
	if amount <= 0 then
		return 0
	end
	local profile = PlayerDataService.GetProfile(player)
	local want = math.floor(amount)
	local actual = math.min(math.max(0, profile.Coins), want)
	if actual > 0 then
		profile.Coins = math.max(0, profile.Coins - actual)
		notifyChanged(player)
	end
	return actual
end

-- Deducts up to `amount` reputation clamped strictly >= 0 (never negative); returns actual amount lost.
function PlayerDataService.DeductReputation(player: Player, amount: number): number
	if amount <= 0 then
		return 0
	end
	local profile = PlayerDataService.GetProfile(player)
	local want = math.floor(amount)
	local actual = math.min(math.max(0, profile.Reputation), want)
	if actual > 0 then
		profile.Reputation = math.max(0, profile.Reputation - actual)
		notifyChanged(player)
	end
	return actual
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

local function syncSharedBaseProgress(player: Player, mutator: (p: PlayerProfile) -> ()): ()
	local slot = BaseService.GetPlayerBaseSlot(player)
	if slot then
		for _, member in ipairs(BaseService.GetBasePlayers(slot)) do
			local p = PlayerDataService.GetProfile(member)
			mutator(p)
			notifyChanged(member)
		end
	else
		local p = PlayerDataService.GetProfile(player)
		mutator(p)
		notifyChanged(player)
	end
end

function PlayerDataService.ReconcileCoopBaseProfiles(slot: BaseService.BaseSlot): ()
	local members = BaseService.GetBasePlayers(slot)
	if #members == 0 then
		return
	end
	local maxRestLv = 1
	local maxDefLv = 1
	local maxCrew = 0
	local maxWaiters = 0
	local maxDishes = 0
	local anyDual = false
	local anyVIP = false

	for _, m in ipairs(members) do
		local p = PlayerDataService.GetProfile(m)
		maxRestLv = math.max(maxRestLv, p.RestaurantLevel or 1)
		maxDefLv = math.max(maxDefLv, p.DefenseLevel or 1)
		maxCrew = math.max(maxCrew, p.CrewCount or 0)
		maxWaiters = math.max(maxWaiters, p.WaiterCount or 0)
		maxDishes = math.max(maxDishes, p.TotalDishesServed or 0)
		if p.HasDualStove then anyDual = true end
		if p.HasVIPBooths then anyVIP = true end
	end

	for _, m in ipairs(members) do
		local p = PlayerDataService.GetProfile(m)
		p.RestaurantLevel = maxRestLv
		p.DefenseLevel = maxDefLv
		p.CrewCount = maxCrew
		p.WaiterCount = maxWaiters
		p.TotalDishesServed = maxDishes
		p.HasDualStove = anyDual
		p.HasVIPBooths = anyVIP
	end

	BaseService.SetDefenseTier(slot, maxDefLv)
	BaseService.SyncInteriorStations(slot, anyDual, anyVIP)

	for _, m in ipairs(members) do
		notifyChanged(m)
	end
end

function PlayerDataService.SetRestaurantLevel(player: Player, level: number): ()
	local clamped = math.clamp(math.floor(level), 1, 15)
	syncSharedBaseProgress(player, function(p)
		p.RestaurantLevel = clamped
	end)
end

function PlayerDataService.AddDishesServed(player: Player, count: number): number
	local add = math.max(0, math.floor(count))
	if add > 0 then
		syncSharedBaseProgress(player, function(p)
			p.TotalDishesServed = (p.TotalDishesServed or 0) + add
		end)
	end
	return PlayerDataService.GetProfile(player).TotalDishesServed or 0
end

function PlayerDataService.GetDishesServed(player: Player): number
	local profile = PlayerDataService.GetProfile(player)
	return profile.TotalDishesServed or 0
end

function PlayerDataService.SetDefenseLevel(player: Player, level: number): ()
	local clamped = math.clamp(math.floor(level), 1, 3)
	syncSharedBaseProgress(player, function(p)
		p.DefenseLevel = clamped
	end)
	local slot = BaseService.GetPlayerBaseSlot(player)
	if slot then
		local profile = PlayerDataService.GetProfile(player)
		BaseService.SetDefenseTier(slot, clamped)
		BaseService.SyncInteriorStations(slot, profile.HasDualStove, profile.HasVIPBooths)
	end
end

function PlayerDataService.SetCrewCount(player: Player, count: number): ()
	local clamped = math.max(0, math.floor(count))
	syncSharedBaseProgress(player, function(p)
		p.CrewCount = clamped
	end)
end

function PlayerDataService.SetWaiterCount(player: Player, count: number): ()
	local clamped = math.clamp(math.floor(count), 0, 5)
	syncSharedBaseProgress(player, function(p)
		p.WaiterCount = clamped
	end)
end

function PlayerDataService.SetCourierCount(player: Player, count: number): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.CourierCount = math.clamp(math.floor(count), 0, 2)
	notifyChanged(player)
end

function PlayerDataService.SetCentralParkBranch(player: Player, owned: boolean, staffed: boolean?): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.OwnsCentralParkBranch = owned
	if staffed ~= nil then
		profile.CentralParkBranchStaffed = staffed
	end
	notifyChanged(player)
end

function PlayerDataService.SetLastFreeSpinAt(player: Player, timestamp: number): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.LastFreeSpinAt = math.max(0, math.floor(timestamp))
	notifyChanged(player)
end

function PlayerDataService.SetRaiderCount(player: Player, count: number): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.RaiderCount = math.clamp(math.floor(count), 0, 2)
	notifyChanged(player)
end

function PlayerDataService.SetBodyguardCount(player: Player, count: number): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.BodyguardCount = math.clamp(math.floor(count), 0, 4)
	-- Keep ActiveBodyguards synchronized if legacy SetBodyguardCount is invoked
	while #profile.ActiveBodyguards < profile.BodyguardCount do
		table.insert(profile.ActiveBodyguards, "BasicGuard")
		profile.UnlockedGuardClasses.BasicGuard = true
	end
	while #profile.ActiveBodyguards > profile.BodyguardCount do
		table.remove(profile.ActiveBodyguards)
	end
	notifyChanged(player)
end

function PlayerDataService.AddBodyguardClass(player: Player, classId: string): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.UnlockedGuardClasses[classId] = true
	if #profile.ActiveBodyguards < 4 then
		table.insert(profile.ActiveBodyguards, classId)
	else
		profile.ActiveBodyguards[#profile.ActiveBodyguards] = classId
	end
	profile.BodyguardCount = #profile.ActiveBodyguards
	notifyChanged(player)
end

function PlayerDataService.ReplaceBodyguardSlot(player: Player, slotIndex: number, classId: string): ()
	local profile = PlayerDataService.GetProfile(player)
	if slotIndex < 1 or slotIndex > 4 then
		return
	end
	profile.UnlockedGuardClasses[classId] = true
	if slotIndex > #profile.ActiveBodyguards then
		table.insert(profile.ActiveBodyguards, classId)
	else
		profile.ActiveBodyguards[slotIndex] = classId
	end
	profile.BodyguardCount = #profile.ActiveBodyguards
	notifyChanged(player)
end

function PlayerDataService.UnlockGuardGear(player: Player, gearId: string): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.OwnedGuardGear[gearId] = true
	notifyChanged(player)
end

function PlayerDataService.SetGuardGearSlot(player: Player, slotKey: string, gearSlot: string, gearId: string?): ()
	local profile = PlayerDataService.GetProfile(player)
	local loadout = profile.GuardLoadouts[slotKey]
	if not loadout then
		loadout = {}
		profile.GuardLoadouts[slotKey] = loadout
	end
	loadout[gearSlot] = gearId :: any
	notifyChanged(player)
end

function PlayerDataService.GetAmmo(player: Player, ammoType: string): number
	local profile = PlayerDataService.GetProfile(player)
	return math.max(0, math.floor(profile.AmmoInventory[ammoType] or 0))
end

function PlayerDataService.SetAmmo(player: Player, ammoType: string, amount: number, maxCap: number?): number
	local profile = PlayerDataService.GetProfile(player)
	local cap = maxCap or 999
	local nextVal = math.clamp(math.floor(amount), 0, cap)
	profile.AmmoInventory[ammoType] = nextVal
	notifyChanged(player)
	return nextVal
end

function PlayerDataService.AddAmmo(player: Player, ammoType: string, delta: number, maxCap: number?): number
	local cur = PlayerDataService.GetAmmo(player, ammoType)
	return PlayerDataService.SetAmmo(player, ammoType, cur + delta, maxCap)
end

function PlayerDataService.SetOwnsMotorbike(player: Player, owned: boolean): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.OwnsMotorbike = owned
	notifyChanged(player)
end

function PlayerDataService.SetHasDualStove(player: Player, owned: boolean): ()
	syncSharedBaseProgress(player, function(p)
		p.HasDualStove = owned
	end)
	local slot = BaseService.GetPlayerBaseSlot(player)
	if slot then
		local profile = PlayerDataService.GetProfile(player)
		BaseService.SyncInteriorStations(slot, profile.HasDualStove, profile.HasVIPBooths)
	end
end

function PlayerDataService.SetHasVIPBooths(player: Player, owned: boolean): ()
	syncSharedBaseProgress(player, function(p)
		p.HasVIPBooths = owned
	end)
	local slot = BaseService.GetPlayerBaseSlot(player)
	if slot then
		local profile = PlayerDataService.GetProfile(player)
		BaseService.SyncInteriorStations(slot, profile.HasDualStove, profile.HasVIPBooths)
	end
end

function PlayerDataService.SetOwnsMafiaSedan(player: Player, owned: boolean): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.OwnsMafiaSedan = owned
	notifyChanged(player)
end

function PlayerDataService.SetGuardStance(player: Player, stance: string): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.GuardStance = stance
	notifyChanged(player)
end

function PlayerDataService.UnlockWeaponMod(player: Player, weaponId: string, modId: string): ()
	local profile = PlayerDataService.GetProfile(player)
	local map = profile.WeaponMods[weaponId]
	if not map then
		map = {}
		profile.WeaponMods[weaponId] = map
	end
	map[modId] = true
	notifyChanged(player)
end

function PlayerDataService.HasWeaponMod(player: Player, weaponId: string, modId: string): boolean
	local profile = PlayerDataService.GetProfile(player)
	local map = profile.WeaponMods[weaponId]
	return map ~= nil and map[modId] == true
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

function PlayerDataService.SetOwnedBusiness(player: Player, businessId: string, owned: boolean): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.OwnedBusinesses[businessId] = if owned then true else nil
	notifyChanged(player)
end

function PlayerDataService.HasBusiness(player: Player, businessId: string): boolean
	return PlayerDataService.GetProfile(player).OwnedBusinesses[businessId] == true
end

function PlayerDataService.SetMenuPricing(player: Player, tier: string): ()
	local profile = PlayerDataService.GetProfile(player)
	if tier ~= "Budget" and tier ~= "Standard" and tier ~= "Luxury" then
		return
	end
	profile.MenuPricing = tier
	notifyChanged(player)
end

function PlayerDataService.AddSmokeGrenades(player: Player, amount: number): number
	local profile = PlayerDataService.GetProfile(player)
	profile.SmokeGrenades = math.clamp((profile.SmokeGrenades or 0) + math.floor(amount), 0, 12)
	notifyChanged(player)
	return profile.SmokeGrenades
end

function PlayerDataService.ConsumeSmokeGrenade(player: Player): boolean
	local profile = PlayerDataService.GetProfile(player)
	if (profile.SmokeGrenades or 0) <= 0 then
		return false
	end
	profile.SmokeGrenades -= 1
	notifyChanged(player)
	return true
end

function PlayerDataService.AddFlashbangs(player: Player, amount: number): number
	local profile = PlayerDataService.GetProfile(player)
	profile.Flashbangs = math.clamp((profile.Flashbangs or 0) + math.floor(amount), 0, 12)
	notifyChanged(player)
	return profile.Flashbangs
end

function PlayerDataService.ConsumeFlashbang(player: Player): boolean
	local profile = PlayerDataService.GetProfile(player)
	if (profile.Flashbangs or 0) <= 0 then
		return false
	end
	profile.Flashbangs -= 1
	notifyChanged(player)
	return true
end

function PlayerDataService.AddC4Charges(player: Player, amount: number): number
	local profile = PlayerDataService.GetProfile(player)
	profile.C4Charges = math.clamp((profile.C4Charges or 0) + math.floor(amount), 0, 8)
	notifyChanged(player)
	return profile.C4Charges
end

function PlayerDataService.ConsumeC4Charge(player: Player): boolean
	local profile = PlayerDataService.GetProfile(player)
	if (profile.C4Charges or 0) <= 0 then
		return false
	end
	profile.C4Charges -= 1
	notifyChanged(player)
	return true
end

function PlayerDataService.UnlockShadowDash(player: Player): ()
	local profile = PlayerDataService.GetProfile(player)
	if not profile.HasShadowDash then
		profile.HasShadowDash = true
		notifyChanged(player)
	end
end

function PlayerDataService.HasShadowDash(player: Player): boolean
	return PlayerDataService.GetProfile(player).HasShadowDash == true
end

function PlayerDataService.GetWeaponKills(player: Player, weaponId: string): number
	local profile = PlayerDataService.GetProfile(player)
	return (profile.WeaponKills and profile.WeaponKills[weaponId]) or 0
end

function PlayerDataService.GetWeaponSkin(player: Player, weaponId: string): string
	local profile = PlayerDataService.GetProfile(player)
	return (profile.WeaponSkins and profile.WeaponSkins[weaponId]) or "Standard"
end

function PlayerDataService.AddWeaponKill(player: Player, weaponId: string): (number, string?)
	local profile = PlayerDataService.GetProfile(player)
	if not profile.WeaponKills then profile.WeaponKills = {} end
	if not profile.WeaponSkins then profile.WeaponSkins = {} end
	local prev = profile.WeaponKills[weaponId] or 0
	local nextK = prev + 1
	profile.WeaponKills[weaponId] = nextK

	local unlocked: string? = nil
	if prev < 3 and nextK >= 3 then
		unlocked = "Damascus"
	elseif prev < 8 and nextK >= 8 then
		unlocked = "Crimson"
	elseif prev < 15 and nextK >= 15 then
		unlocked = "Gold"
	end
	if unlocked then
		profile.WeaponSkins[weaponId] = unlocked
	end
	notifyChanged(player)
	return nextK, unlocked
end

function PlayerDataService.SetWeaponSkin(player: Player, weaponId: string, skinId: string): (boolean, string)
	local profile = PlayerDataService.GetProfile(player)
	if not profile.WeaponKills then profile.WeaponKills = {} end
	if not profile.WeaponSkins then profile.WeaponSkins = {} end
	local kills = profile.WeaponKills[weaponId] or 0
	local req = if skinId == "Gold" then 15 elseif skinId == "Crimson" then 8 elseif skinId == "Damascus" then 3 else 0
	if skinId ~= "Standard" and skinId ~= "Damascus" and skinId ~= "Crimson" and skinId ~= "Gold" then
		return false, "Invalid weapon finish."
	end
	if kills < req then
		return false, string.format("Need %d kills with this weapon to unlock %s (%d/%d).", req, skinId, kills, req)
	end
	profile.WeaponSkins[weaponId] = skinId
	notifyChanged(player)
	return true, string.format("Equipped %s finish!", skinId)
end

function PlayerDataService.SetHasPenthouseTrophy(player: Player, owned: boolean): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.HasPenthouseTrophy = owned
	notifyChanged(player)
end

function PlayerDataService.SetOwnsArmoredVan(player: Player, owned: boolean): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.OwnsArmoredVan = owned
	notifyChanged(player)
end

function PlayerDataService.SetOwnsGetawayCoupe(player: Player, owned: boolean): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.OwnsGetawayCoupe = owned
	notifyChanged(player)
end

function PlayerDataService.SetHasVehicleArmor(player: Player, owned: boolean): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.HasVehicleArmor = owned
	notifyChanged(player)
end

function PlayerDataService.SetVehiclePaint(player: Player, paintId: string): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.VehiclePaint = paintId
	notifyChanged(player)
end

function PlayerDataService.SetDailyVaultProgress(player: Player, streak: number, dayNum: number): ()
	local profile = PlayerDataService.GetProfile(player)
	profile.DailyStreak = math.clamp(math.floor(streak), 0, 7)
	profile.LastDailyClaimDay = math.floor(dayNum)
	notifyChanged(player)
end

function PlayerDataService.IncrementPrestige(player: Player): number
	local profile = PlayerDataService.GetProfile(player)
	profile.PrestigeLevel = (profile.PrestigeLevel or 0) + 1
	profile.RestaurantLevel = 1
	profile.TotalDishesServed = 0
	profile.Coins = 500
	notifyChanged(player)
	return profile.PrestigeLevel
end

function PlayerDataService.GetPrestigeMultiplier(player: Player): number
	local pLv = PlayerDataService.GetProfile(player).PrestigeLevel or 0
	return 1.0 + (pLv * 0.25)
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
			if typeof(saved.RestaurantLevel) == "number" then profile.RestaurantLevel = math.clamp(saved.RestaurantLevel, 1, 15) end
			if typeof(saved.DefenseLevel) == "number" then profile.DefenseLevel = math.clamp(saved.DefenseLevel, 1, 3) end
			if typeof(saved.CrewCount) == "number" then profile.CrewCount = math.max(0, saved.CrewCount) end
			if typeof(saved.RaiderCount) == "number" then profile.RaiderCount = math.clamp(saved.RaiderCount, 0, 2) end
			if typeof(saved.BodyguardCount) == "number" then profile.BodyguardCount = math.clamp(saved.BodyguardCount, 0, 4) end
			if typeof(saved.ActiveBodyguards) == "table" then
				table.clear(profile.ActiveBodyguards)
				for _, cid in ipairs(saved.ActiveBodyguards) do
					if typeof(cid) == "string" and #profile.ActiveBodyguards < 4 then
						table.insert(profile.ActiveBodyguards, cid)
						profile.UnlockedGuardClasses[cid] = true
					end
				end
				profile.BodyguardCount = #profile.ActiveBodyguards
			elseif profile.BodyguardCount > 0 then
				for _ = 1, profile.BodyguardCount do
					table.insert(profile.ActiveBodyguards, "BasicGuard")
				end
				profile.UnlockedGuardClasses.BasicGuard = true
			end
			if typeof(saved.UnlockedGuardClasses) == "table" then
				for cid, val in pairs(saved.UnlockedGuardClasses) do
					if typeof(cid) == "string" and val == true then
						profile.UnlockedGuardClasses[cid] = true
					end
				end
			end
			if typeof(saved.OwnedGuardGear) == "table" then
				for gid, val in pairs(saved.OwnedGuardGear) do
					if typeof(gid) == "string" and val == true then
						profile.OwnedGuardGear[gid] = true
					end
				end
			end
			if typeof(saved.GuardLoadouts) == "table" then
				for sk, ld in pairs(saved.GuardLoadouts) do
					if typeof(sk) == "string" and typeof(ld) == "table" then
						local copy: { [string]: string } = {}
						for slotName, gId in pairs(ld) do
							if typeof(slotName) == "string" and typeof(gId) == "string" then
								copy[slotName] = gId
							end
						end
						profile.GuardLoadouts[sk] = copy
					end
				end
			end
			if typeof(saved.AmmoInventory) == "table" then
				for ammoKey, qty in pairs(saved.AmmoInventory) do
					if typeof(ammoKey) == "string" and typeof(qty) == "number" then
						profile.AmmoInventory[ammoKey] = math.max(0, math.floor(qty))
					end
				end
			end
			if typeof(saved.OwnsMotorbike) == "boolean" then profile.OwnsMotorbike = saved.OwnsMotorbike end
			if typeof(saved.HasDualStove) == "boolean" then profile.HasDualStove = saved.HasDualStove end
			if typeof(saved.HasVIPBooths) == "boolean" then profile.HasVIPBooths = saved.HasVIPBooths end
			if typeof(saved.OwnsMafiaSedan) == "boolean" then profile.OwnsMafiaSedan = saved.OwnsMafiaSedan end
			if typeof(saved.GuardStance) == "string" then profile.GuardStance = saved.GuardStance end
			if typeof(saved.WeaponMods) == "table" then
				for wid, mMap in pairs(saved.WeaponMods) do
					if typeof(wid) == "string" and typeof(mMap) == "table" then
						local copy: { [string]: boolean } = {}
						for mid, v in pairs(mMap) do
							if typeof(mid) == "string" and v == true then
								copy[mid] = true
							end
						end
						profile.WeaponMods[wid] = copy
					end
				end
			end
			if typeof(saved.OwnedBusinesses) == "table" then
				for bid, v in pairs(saved.OwnedBusinesses) do
					if typeof(bid) == "string" and v == true then
						profile.OwnedBusinesses[bid] = true
					end
				end
			end
			if typeof(saved.MenuPricing) == "string" then
				profile.MenuPricing = saved.MenuPricing
			end
			if typeof(saved.SmokeGrenades) == "number" then
				profile.SmokeGrenades = math.clamp(math.floor(saved.SmokeGrenades), 0, 12)
			end
			if typeof(saved.Flashbangs) == "number" then
				profile.Flashbangs = math.clamp(math.floor(saved.Flashbangs), 0, 12)
			end
			if typeof(saved.C4Charges) == "number" then
				profile.C4Charges = math.clamp(math.floor(saved.C4Charges), 0, 8)
			end
			if typeof(saved.HasShadowDash) == "boolean" then
				profile.HasShadowDash = saved.HasShadowDash
			end
			if typeof(saved.WeaponKills) == "table" then
				for wid, v in pairs(saved.WeaponKills) do
					if typeof(wid) == "string" and typeof(v) == "number" then
						profile.WeaponKills[wid] = math.max(0, math.floor(v))
					end
				end
			end
			if typeof(saved.WeaponSkins) == "table" then
				for wid, v in pairs(saved.WeaponSkins) do
					if typeof(wid) == "string" and typeof(v) == "string" then
						profile.WeaponSkins[wid] = v
					end
				end
			end
			if typeof(saved.HasPenthouseTrophy) == "boolean" then
				profile.HasPenthouseTrophy = saved.HasPenthouseTrophy
			end
			if typeof(saved.OwnsArmoredVan) == "boolean" then profile.OwnsArmoredVan = saved.OwnsArmoredVan end
			if typeof(saved.OwnsGetawayCoupe) == "boolean" then profile.OwnsGetawayCoupe = saved.OwnsGetawayCoupe end
			if typeof(saved.HasVehicleArmor) == "boolean" then profile.HasVehicleArmor = saved.HasVehicleArmor end
			if typeof(saved.VehiclePaint) == "string" then profile.VehiclePaint = saved.VehiclePaint end
			if typeof(saved.DailyStreak) == "number" then profile.DailyStreak = math.clamp(math.floor(saved.DailyStreak), 0, 7) end
			if typeof(saved.LastDailyClaimDay) == "number" then profile.LastDailyClaimDay = math.floor(saved.LastDailyClaimDay) end
			if typeof(saved.PrestigeLevel) == "number" then profile.PrestigeLevel = math.max(0, math.floor(saved.PrestigeLevel)) end
			if typeof(saved.TotalDishesServed) == "number" then profile.TotalDishesServed = math.max(0, math.floor(saved.TotalDishesServed)) end
			if typeof(saved.WaiterCount) == "number" then profile.WaiterCount = math.clamp(math.floor(saved.WaiterCount), 0, 5) end
			if typeof(saved.CourierCount) == "number" then profile.CourierCount = math.clamp(math.floor(saved.CourierCount), 0, 2) end
			if typeof(saved.OwnsCentralParkBranch) == "boolean" then profile.OwnsCentralParkBranch = saved.OwnsCentralParkBranch end
			if typeof(saved.CentralParkBranchStaffed) == "boolean" then profile.CentralParkBranchStaffed = saved.CentralParkBranchStaffed end
			if typeof(saved.LastFreeSpinAt) == "number" then profile.LastFreeSpinAt = math.max(0, math.floor(saved.LastFreeSpinAt)) end
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
		PlayerDataService.ReconcileCoopBaseProfiles(slot)
	else
		notifyChanged(player)
	end
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
		WaiterCount = profile.WaiterCount,
		CourierCount = profile.CourierCount,
		OwnsCentralParkBranch = profile.OwnsCentralParkBranch,
		CentralParkBranchStaffed = profile.CentralParkBranchStaffed,
		LastFreeSpinAt = profile.LastFreeSpinAt,
		RaiderCount = profile.RaiderCount,
		BodyguardCount = profile.BodyguardCount,
		ActiveBodyguards = profile.ActiveBodyguards,
		UnlockedGuardClasses = profile.UnlockedGuardClasses,
		OwnedGuardGear = profile.OwnedGuardGear,
		GuardLoadouts = profile.GuardLoadouts,
		AmmoInventory = profile.AmmoInventory,
		OwnsMotorbike = profile.OwnsMotorbike,
		HasDualStove = profile.HasDualStove,
		HasVIPBooths = profile.HasVIPBooths,
		OwnsMafiaSedan = profile.OwnsMafiaSedan,
		GuardStance = profile.GuardStance,
		WeaponMods = profile.WeaponMods,
		OwnedBusinesses = profile.OwnedBusinesses,
		MenuPricing = profile.MenuPricing,
		SmokeGrenades = profile.SmokeGrenades,
		Flashbangs = profile.Flashbangs,
		C4Charges = profile.C4Charges,
		HasShadowDash = profile.HasShadowDash,
		WeaponKills = profile.WeaponKills,
		WeaponSkins = profile.WeaponSkins,
		HasPenthouseTrophy = profile.HasPenthouseTrophy,
		OwnsArmoredVan = profile.OwnsArmoredVan,
		OwnsGetawayCoupe = profile.OwnsGetawayCoupe,
		HasVehicleArmor = profile.HasVehicleArmor,
		VehiclePaint = profile.VehiclePaint,
		DailyStreak = profile.DailyStreak,
		LastDailyClaimDay = profile.LastDailyClaimDay,
		PrestigeLevel = profile.PrestigeLevel,
		TotalDishesServed = profile.TotalDishesServed,
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
		PlayerDataService.ReconcileCoopBaseProfiles(slot)
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
