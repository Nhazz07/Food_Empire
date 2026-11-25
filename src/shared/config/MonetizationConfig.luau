--!strict

export type MonetizationKind = "GamePass" | "DevProduct"

export type MonetizationItem = {
	Id: string,
	DisplayName: string,
	Kind: MonetizationKind,
	AssetId: number, -- Paste your published Roblox Game Pass / Developer Product ID here from Creator Hub!
	RobuxPrice: number,
	Badge: string,
	Description: string,
	AccentColor: Color3,
}

export type DualRobuxOptionSpec = {
	Key: string,
	DisplayName: string,
	RobuxPrice: number,
	AssetId: number, -- Replace 0 with Developer Product ID in Creator Hub for live purchases
}

export type MonetizationConfigType = {
	Order: { string },
	Items: { [string]: MonetizationItem },
	DualRobuxOptions: { [string]: DualRobuxOptionSpec },
	GetHQUpgradeRobuxPrice: (nextLevel: number) -> number,
}

local Items: { [string]: MonetizationItem } = {
	MasterProChef = {
		Id = "MasterProChef",
		DisplayName = "Master Pro Chef",
		Kind = "GamePass",
		AssetId = 0, -- Replace 0 with your Game Pass ID from Roblox Creator Hub
		RobuxPrice = 149,
		Badge = "BEST SELLER",
		Description = "Hustling Golden Pro Chef in your HQ! Sources free Gourmet Fish every 16s, Auto-Cooks & Auto-Serves every 4s (+50% Speed & +35% Value)!",
		AccentColor = Color3.fromRGB(246, 178, 38),
	},
	RaiderChefSquad = {
		Id = "RaiderChefSquad",
		DisplayName = "Raider Chef Squad (2x)",
		Kind = "GamePass",
		AssetId = 0, -- Replace 0 with your Game Pass ID from Roblox Creator Hub
		RobuxPrice = 99,
		Badge = "AUTO CAPTURE",
		Description = "Instantly deploys 2 Team Raider Chefs who march across the island capturing Neutral & Rival territories and fighting Rival Chefs for you!",
		AccentColor = Color3.fromRGB(232, 74, 88),
	},
	VIPEmpireStaff = {
		Id = "VIPEmpireStaff",
		DisplayName = "VIP Empire Staff Pack",
		Kind = "GamePass",
		AssetId = 0, -- Replace 0 with your Game Pass ID from Roblox Creator Hub
		RobuxPrice = 249,
		Badge = "FAST EMPIRE",
		Description = "Spawns 2 Elite Sous-Chefs in your HQ + +2 Bonus Staff Slots + 2x Ingredient Auto-Delivery from Territories!",
		AccentColor = Color3.fromRGB(148, 76, 232),
	},
	DoubleEmpireVIP = {
		Id = "DoubleEmpireVIP",
		DisplayName = "2x Coins & Rep VIP",
		Kind = "GamePass",
		AssetId = 0, -- Replace 0 with your Game Pass ID from Roblox Creator Hub
		RobuxPrice = 199,
		Badge = "2X BOOST",
		Description = "Permanent 2x Coins & 2x Reputation on all food sold! Climb to Food Emperor twice as fast.",
		AccentColor = Color3.fromRGB(52, 178, 108),
	},
	InstantEmpireCrate = {
		Id = "InstantEmpireCrate",
		DisplayName = "Instant Empire Crate",
		Kind = "DevProduct",
		AssetId = 0, -- Replace 0 with your Developer Product ID from Roblox Creator Hub
		RobuxPrice = 49,
		Badge = "INSTANT BOOST",
		Description = "Instant +600 Coins & +10 of EVERY ingredient (Fish, Meat, Veg & Fruit) straight into your Warehouses!",
		AccentColor = Color3.fromRGB(48, 156, 234),
	},
	DeliveryMotorbike = {
		Id = "DeliveryMotorbike",
		DisplayName = "Sport Delivery Motorbike",
		Kind = "GamePass",
		AssetId = 0, -- Replace 0 with your Game Pass ID from Roblox Creator Hub
		RobuxPrice = 79,
		Badge = "FAST RIDE",
		Description = "Realistic Sport Delivery Motorbike (42 Speed, spinning wheels, corner lean & seated rider)! Unlock with 3,750 Gold OR 79 R$.",
		AccentColor = Color3.fromRGB(42, 174, 184),
	},
	GoldenEmperorPistolPass = {
		Id = "GoldenEmperorPistolPass",
		DisplayName = "Golden Emperor Pistol",
		Kind = "GamePass",
		AssetId = 0, -- Replace 0 with your Game Pass ID from Roblox Creator Hub
		RobuxPrice = 129,
		Badge = "BLACK MARKET VIP",
		Description = "Permanent Mythic 24K Gold 9mm pistol (15-rd mag, 46 DMG, rapid 1.2s reload) + starter ammo!",
		AccentColor = Color3.fromRGB(255, 208, 56),
	},
	CrimsonDragonARPass = {
		Id = "CrimsonDragonARPass",
		DisplayName = "Crimson Dragon AR",
		Kind = "GamePass",
		AssetId = 0, -- Replace 0 with your Game Pass ID from Roblox Creator Hub
		RobuxPrice = 249,
		Badge = "MYTHIC RIFLE",
		Description = "Permanent Mythic Crimson-Gold 5.56mm assault rifle (35-rd mag, 39 DMG, tight recoil)!",
		AccentColor = Color3.fromRGB(238, 52, 74),
	},
	BossBodyguardPass = {
		Id = "BossBodyguardPass",
		DisplayName = "Boss Bodyguard Commander",
		Kind = "GamePass",
		AssetId = 0, -- Replace 0 with your Game Pass ID from Roblox Creator Hub
		RobuxPrice = 199,
		Badge = "ELITE SQUAD",
		Description = "Permanently unlocks the 780 HP Boss Bodyguard (+20% Squad Command Aura) with no level requirement!",
		AccentColor = Color3.fromRGB(246, 186, 48),
	},
	GoldenEmperorSuitPass = {
		Id = "GoldenEmperorSuitPass",
		DisplayName = "Golden Emperor Guard Suit",
		Kind = "GamePass",
		AssetId = 0, -- Replace 0 with your Game Pass ID from Roblox Creator Hub
		RobuxPrice = 119,
		Badge = "ROYAL COSMETIC",
		Description = "Permanent Mythic Royal Gold Armored Suit for your Bodyguards (+130 HP, +12 DMG, +2 Speed)!",
		AccentColor = Color3.fromRGB(246, 196, 48),
	},
	TacticalAmmoCrate = {
		Id = "TacticalAmmoCrate",
		DisplayName = "Full Ammo Resupply Crate",
		Kind = "DevProduct",
		AssetId = 0, -- Replace 0 with your Developer Product ID from Roblox Creator Hub
		RobuxPrice = 39,
		Badge = "CONSUMABLE",
		Description = "Instantly refills ALL 5 Black Market ammunition calibers (9mm, 12G, .45, 5.56mm, .308) to 100% Max Reserve!",
		AccentColor = Color3.fromRGB(242, 168, 48),
	},
	SyndicateArmorBundle = {
		Id = "SyndicateArmorBundle",
		DisplayName = "Syndicate War Chest",
		Kind = "DevProduct",
		AssetId = 0, -- Replace 0 with your Developer Product ID from Roblox Creator Hub
		RobuxPrice = 59,
		Badge = "WAR PACK",
		Description = "Instant 100/100 Kevlar Armor + Full Base HP + +750 Gold & +60 rounds for your equipped weapon!",
		AccentColor = Color3.fromRGB(52, 164, 242),
	},
	SamuraiMafiaContract = {
		Id = "SamuraiMafiaContract",
		DisplayName = "Samurai Mafia Strike Squad (5m)",
		Kind = "DevProduct",
		AssetId = 0, -- Replace 0 with your Developer Product ID from Roblox Creator Hub
		RobuxPrice = 199,
		Badge = "5M CONTRACT",
		Description = "Hires 3 elite Kurogane Samurai Mafia enforcers (stronger than rival samurai) for 5 minutes to fight rival mafia & capture restaurants (or hire for 100,000 Gold)!",
		AccentColor = Color3.fromRGB(168, 42, 48),
	},
	NinjaMafiaContract = {
		Id = "NinjaMafiaContract",
		DisplayName = "Ninja Assassin Mafia Squad (5m)",
		Kind = "DevProduct",
		AssetId = 0, -- Replace 0 with your Developer Product ID from Roblox Creator Hub
		RobuxPrice = 199,
		Badge = "5M CONTRACT",
		Description = "Hires 3 elite Kage Ninja Mafia assassins (stronger than rival mafia) for 5 minutes with shadow-step blade clashes (or hire for 100,000 Gold)!",
		AccentColor = Color3.fromRGB(62, 68, 86),
	},
}

-- Dual-Currency Robux Alternatives for Gold Upgrades & Shop Items (Existing Robux Store prices above stay 100% unchanged!)
local DualRobuxOptions: { [string]: DualRobuxOptionSpec } = {
	UpgradeHQ_Low = { Key = "UpgradeHQ_Low", DisplayName = "Restaurant HQ Upgrade (Lv.2-3)", RobuxPrice = 49, AssetId = 0 },
	UpgradeHQ_Mid = { Key = "UpgradeHQ_Mid", DisplayName = "Restaurant HQ Upgrade (Lv.4-5)", RobuxPrice = 79, AssetId = 0 },
	UpgradeHQ_High = { Key = "UpgradeHQ_High", DisplayName = "Restaurant HQ Upgrade (Lv.6-8)", RobuxPrice = 119, AssetId = 0 },
	UpgradeHQ_Max = { Key = "UpgradeHQ_Max", DisplayName = "Restaurant HQ Upgrade (Lv.9-10)", RobuxPrice = 169, AssetId = 0 },
	UpgradeHQ_Imperial = { Key = "UpgradeHQ_Imperial", DisplayName = "Restaurant HQ Upgrade (Lv.11-13)", RobuxPrice = 219, AssetId = 0 },
	UpgradeHQ_Supreme = { Key = "UpgradeHQ_Supreme", DisplayName = "Restaurant HQ Upgrade (Lv.14-15)", RobuxPrice = 279, AssetId = 0 },
	UnlockWarehouse = { Key = "UnlockWarehouse", DisplayName = "Unlock Ingredient Warehouse", RobuxPrice = 39, AssetId = 0 },
	UpgradeWarehouse = { Key = "UpgradeWarehouse", DisplayName = "Upgrade Ingredient Warehouse", RobuxPrice = 49, AssetId = 0 },
	BuyDualStove = { Key = "BuyDualStove", DisplayName = "Dual-Stove Kitchen Line", RobuxPrice = 59, AssetId = 0 },
	BuyVIPBooths = { Key = "BuyVIPBooths", DisplayName = "VIP Private Dining Booths", RobuxPrice = 79, AssetId = 0 },
	HireCrew = { Key = "HireCrew", DisplayName = "Hire Kitchen Chef", RobuxPrice = 39, AssetId = 0 },
	HireWaiter = { Key = "HireWaiter", DisplayName = "Hire Dining Waiter", RobuxPrice = 39, AssetId = 0 },
	HireCourier = { Key = "HireCourier", DisplayName = "Hire Motorbike Courier", RobuxPrice = 49, AssetId = 0 },
	BuyCentralParkBranch = { Key = "BuyCentralParkBranch", DisplayName = "Central Park Bistro Branch", RobuxPrice = 69, AssetId = 0 },
	UpgradeDefenses = { Key = "UpgradeDefenses", DisplayName = "Base Defenses Upgrade", RobuxPrice = 59, AssetId = 0 },
}

local function getHQUpgradeRobuxPrice(nextLevel: number): number
	if nextLevel <= 3 then
		return DualRobuxOptions.UpgradeHQ_Low.RobuxPrice
	elseif nextLevel <= 5 then
		return DualRobuxOptions.UpgradeHQ_Mid.RobuxPrice
	elseif nextLevel <= 8 then
		return DualRobuxOptions.UpgradeHQ_High.RobuxPrice
	elseif nextLevel <= 10 then
		return DualRobuxOptions.UpgradeHQ_Max.RobuxPrice
	elseif nextLevel <= 13 then
		return DualRobuxOptions.UpgradeHQ_Imperial.RobuxPrice
	else
		return DualRobuxOptions.UpgradeHQ_Supreme.RobuxPrice
	end
end

local MonetizationConfig: MonetizationConfigType = {
	Order = {
		"DeliveryMotorbike",
		"RaiderChefSquad",
		"MasterProChef",
		"VIPEmpireStaff",
		"DoubleEmpireVIP",
		"InstantEmpireCrate",
		"GoldenEmperorPistolPass",
		"CrimsonDragonARPass",
		"BossBodyguardPass",
		"GoldenEmperorSuitPass",
		"TacticalAmmoCrate",
		"SyndicateArmorBundle",
		"SamuraiMafiaContract",
		"NinjaMafiaContract",
	},
	Items = Items,
	DualRobuxOptions = DualRobuxOptions,
	GetHQUpgradeRobuxPrice = getHQUpgradeRobuxPrice,
}

return MonetizationConfig
