--!strict

-- ItemIconAssets: Permanent Roblox Cloud-hosted AAA 1024x1024 RGBA Icon Sprite Atlases
-- (5 Atlases x 256x256 retina transparent tiles = 72 bespoke front-page illustrated game icons!).

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
local ATLAS_4 = "rbxassetid://117152382072020" -- 9 Guard Gear + 6 Bodyguard Portraits + Restaurant HQ
local ATLAS_5 = "rbxassetid://122952703674385" -- Dual Stove, VIP Booth, Chef, Waiter, Courier, Turret, Park Bistro, Family Crest

ItemIconAssets.ALL_ATLAS_IDS = {
	ATLAS_1,
	ATLAS_2,
	ATLAS_3,
	ATLAS_4,
	ATLAS_5,
}

local TILE = 256
local FULL_SIZE = Vector2.new(TILE, TILE)

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
	Bodyguard = {
		BasicGuard = cell(ATLAS_4, 9),
		TacticalGuard = cell(ATLAS_4, 10),
		HeavyGuard = cell(ATLAS_4, 11),
		AssaultGuard = cell(ATLAS_4, 12),
		SniperGuard = cell(ATLAS_4, 13),
		NinjaGuard = cell(ATLAS_4, 14),
		-- Timed Restaurant Defenders (clean portrait matches)
		RestaurantBodyguard = cell(ATLAS_4, 9),
		ShadowNinja = cell(ATLAS_4, 14),
		EliteBodyguard = cell(ATLAS_4, 11),
	},
	Empire = {
		HQ = cell(ATLAS_4, 15),
		STV = cell(ATLAS_5, 0),
		VIP = cell(ATLAS_5, 1),
		CHEF = cell(ATLAS_5, 2),
		CREW = cell(ATLAS_5, 2),
		WAIT = cell(ATLAS_5, 3),
		COUR = cell(ATLAS_5, 4, nil, 14), -- Trims 14px left margin cleanly
		DEF = cell(ATLAS_5, 5),
		PRK = cell(ATLAS_5, 6),
		FAM = cell(ATLAS_5, 7),
	},
	Premium = {
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
