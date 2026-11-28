--!strict

-- ItemIconAssets: Permanent Roblox Cloud-hosted AAA 1024x1024 RGBA Icon Sprite Atlases
-- (8 Atlases x 256x256 retina transparent tiles = 100+ bespoke front-page illustrated game icons!).

local ContentProvider = game:GetService("ContentProvider")

export type IconSpriteSpec = {
	AssetId: string,
	RectOffset: Vector2,
	RectSize: Vector2,
	Tint: Color3?,
}

local ItemIconAssets = {}

-- Uploaded 1024x1024 4x4 RGBA Transparent Sprite Atlases (256x256px per tile)
local ATLAS_1 = "rbxassetid://91470026595862"  -- 14 Kitchen Dishes + Fish & Vegetable Warehouses
local ATLAS_2 = "rbxassetid://94324972908095"  -- Fruit & Meat Warehouses + All 14 Weapons
local ATLAS_3 = "rbxassetid://114426782879710" -- 6 Supplies/Gadgets + 5 Ammo Crates + 5 Armor/Helmets
local ATLAS_4 = "rbxassetid://117152382072020" -- 9 Guard Gear + Restaurant HQ
local ATLAS_5 = "rbxassetid://122952703674385" -- Dual Stove, VIP Booth, Chef, Waiter, Courier, Turret, Park Bistro
local ATLAS_6 = "rbxassetid://123993499661838" -- 9 Stylized Roblox R15 Bodyguards + 7 Syndicate Ops & Royal Family Crest
local ATLAS_7 = "rbxassetid://89209337157765"  -- Bounty, Rank Medal, 3 Mafia Restaurants, 3 Front Businesses, Convoy, Drop, Contracts, 2X VIP, Motorbike, Crate, Spin Wheel, Raider Chef
local ATLAS_8 = "rbxassetid://82134417523803"  -- VIP Staff Pack, Samurai Mafia, Ninja Assassin Mafia, Armored Delivery Runner

ItemIconAssets.ALL_ATLAS_IDS = {
	ATLAS_1,
	ATLAS_2,
	ATLAS_3,
	ATLAS_4,
	ATLAS_5,
	ATLAS_6,
	ATLAS_7,
	ATLAS_8,
}

local TILE = 256

local function cell(assetId: string, index0: number, tint: Color3?, padLeft: number?): IconSpriteSpec
	local col = index0 % 4
	local row = math.floor(index0 / 4)
	local pl = padLeft or 0
	return {
		AssetId = assetId,
		RectOffset = Vector2.new(col * TILE + pl, row * TILE),
		RectSize = Vector2.new(TILE - pl, TILE),
		Tint = tint,
	}
end

-- Lookup tables grouped by ModelPreviewHelper kind
local BY_KIND: { [string]: { [string]: IconSpriteSpec } } = {
	Dish = {
		KingCrabPlatter = cell(ATLAS_1, 0),
		GoldenTunaSashimi = cell(ATLAS_1, 1),
		GrilledFish = cell(ATLAS_1, 2),
		EmperorPlatter = cell(ATLAS_1, 3),
		ClassicBurger = cell(ATLAS_1, 4),
		FreshSushi = cell(ATLAS_1, 5),
		TropicalSmoothie = cell(ATLAS_1, 6),
		SizzlingSteak = cell(ATLAS_1, 7),
		CrabFeast = cell(ATLAS_1, 8),
		TruffleWagyuTartare = cell(ATLAS_1, 9),
		SmokedCartelRibs = cell(ATLAS_1, 10),
		GoldLeafLobster = cell(ATLAS_1, 11),
		DonsMidnightTiramisu = cell(ATLAS_1, 12),
		ActiveOrder = cell(ATLAS_1, 13),
	},
	Warehouse = {
		Fish = cell(ATLAS_1, 14),
		Vegetable = cell(ATLAS_1, 15),
		Fruit = cell(ATLAS_2, 0),
		Meat = cell(ATLAS_2, 1),
	},
	Weapon = {
		GoldenSpatula = cell(ATLAS_2, 2),
		MafiaKnife = cell(ATLAS_2, 3),
		SamuraiKatana = cell(ATLAS_2, 4),
		StreetPistol = cell(ATLAS_2, 5),
		SilencedDeagle = cell(ATLAS_2, 6),
		PepperShotgun = cell(ATLAS_2, 7),
		AutoCombatShotgun = cell(ATLAS_2, 8),
		TacticalSMG = cell(ATLAS_2, 9),
		SyndicateCarbine = cell(ATLAS_2, 10),
		SyndicateTommyDrum = cell(ATLAS_2, 11),
		ShadowSniper = cell(ATLAS_2, 12),
		PhantomAssassinRifle = cell(ATLAS_2, 13),
		GoldenEmperorPistol = cell(ATLAS_2, 14),
		CrimsonDragonAR = cell(ATLAS_2, 15),
	},
	Ammo = {
		Pistol9mm = cell(ATLAS_3, 6),
		Shotgun12G = cell(ATLAS_3, 7),
		SMG45 = cell(ATLAS_3, 8),
		Rifle556 = cell(ATLAS_3, 9),
		Sniper308 = cell(ATLAS_3, 10),
	},
	Equipment = {
		-- Survival Supplies & Contraband Gadgets
		KevlarVest = cell(ATLAS_3, 0),
		Medkit = cell(ATLAS_3, 1),
		SmokeGrenade = cell(ATLAS_3, 2),
		Flashbang = cell(ATLAS_3, 3),
		C4Charge = cell(ATLAS_3, 4),
		ShadowDash = cell(ATLAS_3, 5),
		InstantEmpireCrate = cell(ATLAS_7, 13),
		-- All 18 Bodyguard Gear Items
		GuardKevlarPlate = cell(ATLAS_3, 11),
		GuardJuggernautArmor = cell(ATLAS_3, 12),
		GuardBallisticHelmet = cell(ATLAS_3, 13),
		GuardReconVisor = cell(ATLAS_3, 14),
		GuardTitaniumHelm = cell(ATLAS_3, 15),
		GuardShadowSuit = cell(ATLAS_4, 0),
		GuardSyndicateSuit = cell(ATLAS_4, 1),
		GoldenEmperorSuit = cell(ATLAS_4, 2),
		GuardHoloSight = cell(ATLAS_4, 3),
		GuardExtendedMag = cell(ATLAS_4, 4),
		GuardSuppressor = cell(ATLAS_4, 5),
		GuardFieldMedPack = cell(ATLAS_4, 6),
		GuardFlashbangKit = cell(ATLAS_4, 7),
		GuardRiotPlate = cell(ATLAS_4, 8),
		GuardTacticalSMG = cell(ATLAS_2, 9),
		GuardAssaultRifle = cell(ATLAS_2, 10),
		GuardHeavyShotgun = cell(ATLAS_2, 8),
		GuardPrecisionSniper = cell(ATLAS_2, 12),
	},
	-- Stylized Chunky Roblox R15 Collectible Bodyguard Figurines (All 8 Classes + All 4 Timed Defenders)
	Bodyguard = {
		BasicGuard = cell(ATLAS_6, 0),
		TacticalGuard = cell(ATLAS_6, 1),
		HeavyGuard = cell(ATLAS_6, 2),
		AssaultGuard = cell(ATLAS_6, 3),
		SniperGuard = cell(ATLAS_6, 4),
		NinjaGuard = cell(ATLAS_6, 5),
		EliteGuard = cell(ATLAS_6, 6),
		BossBodyguard = cell(ATLAS_6, 7),
		CrimsonAssassin = cell(ATLAS_6, 8),
		-- Timed Restaurant Defense Companions
		RestaurantBodyguard = cell(ATLAS_6, 0),
		ShadowNinja = cell(ATLAS_6, 5),
		EliteBodyguard = cell(ATLAS_6, 6),
	},
	Empire = {
		-- HQ, Kitchen & Staff Upgrades
		HQ = cell(ATLAS_4, 15),
		STV = cell(ATLAS_5, 0),
		VIP = cell(ATLAS_5, 1),
		CHEF = cell(ATLAS_5, 2),
		CREW = cell(ATLAS_5, 2),
		CRW = cell(ATLAS_5, 2),
		WAIT = cell(ATLAS_5, 3),
		WTR = cell(ATLAS_5, 3),
		COUR = cell(ATLAS_5, 4, nil, 14),
		MTR = cell(ATLAS_7, 12),
		DEF = cell(ATLAS_5, 5),
		PRK = cell(ATLAS_5, 6),
		SPN = cell(ATLAS_7, 14),
		GRD = cell(ATLAS_6, 7),
		-- Syndicate Operations, Prestige, Heists & Bounties
		DAY = cell(ATLAS_6, 9),
		PRS = cell(ATLAS_6, 10),
		VLT = cell(ATLAS_6, 11),
		EMP = cell(ATLAS_6, 12),
		FAM = cell(ATLAS_6, 13),
		WTH = cell(ATLAS_6, 14),
		HST = cell(ATLAS_6, 15),
		BNT = cell(ATLAS_7, 0),
		RK = cell(ATLAS_7, 1),
		-- Conquerable Mafia City Restaurants
		RST_Noodle = cell(ATLAS_7, 2),
		RST_Steak = cell(ATLAS_7, 3),
		RST_Oyster = cell(ATLAS_7, 4),
		-- Ownable Mafia Front Businesses
		BIZ_HarborCannery = cell(ATLAS_7, 5),
		BIZ_DowntownLounge = cell(ATLAS_7, 6),
		BIZ_BackAlleyArms = cell(ATLAS_7, 7),
		-- Raids, Convoys, Contracts & Mercenary Squads
		CNV = cell(ATLAS_7, 8),
		WAR = cell(ATLAS_7, 9),
		CT1 = cell(ATLAS_7, 10),
		CT2 = cell(ATLAS_7, 10),
		CT3 = cell(ATLAS_7, 10),
		RDR = cell(ATLAS_7, 15),
		RUN = cell(ATLAS_8, 3),
		SMR = cell(ATLAS_8, 1),
		NJA = cell(ATLAS_8, 2),
	},
	Premium = {
		DoubleEmpireVIP = cell(ATLAS_7, 11),
		DeliveryMotorbike = cell(ATLAS_7, 12),
		InstantEmpireCrate = cell(ATLAS_7, 13),
		RaiderChefSquad = cell(ATLAS_7, 15),
		VIPEmpireStaff = cell(ATLAS_8, 0),
		BossBodyguardPass = cell(ATLAS_6, 7),
		SamuraiMafiaContract = cell(ATLAS_8, 1),
		NinjaMafiaContract = cell(ATLAS_8, 2),
		GoldenEmperorPistolPass = cell(ATLAS_2, 14),
		CrimsonDragonARPass = cell(ATLAS_2, 15),
		GoldenEmperorSuitPass = cell(ATLAS_4, 2),
		TacticalAmmoCrate = cell(ATLAS_3, 9),
		SyndicateArmorBundle = cell(ATLAS_3, 0),
		MasterProChef = cell(ATLAS_5, 2),
	},
}

-- Alias Guard -> Bodyguard
BY_KIND.Guard = BY_KIND.Bodyguard

function ItemIconAssets.GetIcon(kind: string, itemId: string): IconSpriteSpec?
	local bucket = BY_KIND[kind]
	if bucket then
		local hit = bucket[itemId]
		if hit then
			return hit
		end
	end
	return nil
end

local preloaded = false
function ItemIconAssets.PreloadAll(): ()
	if preloaded then
		return
	end
	preloaded = true
	pcall(function()
		local imgs: { Instance } = {}
		for _, id in ipairs(ItemIconAssets.ALL_ATLAS_IDS) do
			local img = Instance.new("ImageLabel")
			img.Image = id
			table.insert(imgs, img)
		end
		ContentProvider:PreloadAsync(imgs)
		for _, img in ipairs(imgs) do
			img:Destroy()
		end
	end)
end

return ItemIconAssets
