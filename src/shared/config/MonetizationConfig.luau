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

export type MonetizationConfigType = {
	Order: { string },
	Items: { [string]: MonetizationItem },
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
		Description = "Realistic Sport Delivery Motorbike (42 Speed, spinning wheels, corner lean & seated rider)! Unlock with 450 Gold OR 79 R$.",
		AccentColor = Color3.fromRGB(42, 174, 184),
	},
}

local MonetizationConfig: MonetizationConfigType = {
	Order = {
		"DeliveryMotorbike",
		"RaiderChefSquad",
		"MasterProChef",
		"VIPEmpireStaff",
		"DoubleEmpireVIP",
		"InstantEmpireCrate",
	},
	Items = Items,
}

return MonetizationConfig
