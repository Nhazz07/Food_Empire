--!strict

export type WarehouseCategory = "Fish" | "Meat" | "Vegetable" | "Fruit"

export type WarehouseTierInfo = {
	Level: number,
	Capacity: number,
	UpgradeCost: number,
}

export type WarehouseCategorySpec = {
	DisplayName: string,
	ShortLabel: string,
	Icon: string,
	UnlockCost: number,
	AccentColor: Color3,
	Ingredients: { string },
}

export type WarehouseConfigType = {
	Categories: { WarehouseCategory },
	Specs: { [WarehouseCategory]: WarehouseCategorySpec },
	Tiers: { [number]: WarehouseTierInfo },
	MaxLevel: number,
	IngredientToCategory: { [string]: WarehouseCategory },
}

local Specs: { [WarehouseCategory]: WarehouseCategorySpec } = {
	Fish = {
		DisplayName = "Fish Warehouse",
		ShortLabel = "FISH",
		Icon = "🐟",
		UnlockCost = 0, -- Starter Warehouse (Unlocked from the start!)
		AccentColor = Color3.fromRGB(46, 162, 232),
		Ingredients = { "fish", "shrimp", "crab", "golden_tuna", "king_crab" },
	},
	Vegetable = {
		DisplayName = "Vegetable Warehouse",
		ShortLabel = "VEGGIES",
		Icon = "🥕",
		UnlockCost = 220,
		AccentColor = Color3.fromRGB(74, 188, 86),
		Ingredients = { "carrot", "potato", "cabbage" },
	},
	Fruit = {
		DisplayName = "Fruit Warehouse",
		ShortLabel = "FRUIT",
		Icon = "🥭",
		UnlockCost = 360,
		AccentColor = Color3.fromRGB(248, 154, 38),
		Ingredients = { "mango", "banana", "orange" },
	},
	Meat = {
		DisplayName = "Meat Warehouse",
		ShortLabel = "MEAT",
		Icon = "🥩",
		UnlockCost = 520,
		AccentColor = Color3.fromRGB(214, 64, 68),
		Ingredients = { "beef", "chicken", "pork" },
	},
}

local IngredientToCategory: { [string]: WarehouseCategory } = {}
for category, spec in pairs(Specs) do
	for _, ingredient in ipairs(spec.Ingredients) do
		IngredientToCategory[ingredient] = category
	end
end

local WarehouseConfig: WarehouseConfigType = {
	Categories = { "Fish", "Vegetable", "Fruit", "Meat" },
	Specs = Specs,
	Tiers = {
		[0] = { Level = 0, Capacity = 0, UpgradeCost = 0 },
		[1] = { Level = 1, Capacity = 50, UpgradeCost = 0 },
		[2] = { Level = 2, Capacity = 110, UpgradeCost = 350 },
		[3] = { Level = 3, Capacity = 190, UpgradeCost = 700 },
		[4] = { Level = 4, Capacity = 290, UpgradeCost = 1150 },
		[5] = { Level = 5, Capacity = 420, UpgradeCost = 1750 },
		[6] = { Level = 6, Capacity = 580, UpgradeCost = 2500 },
		[7] = { Level = 7, Capacity = 770, UpgradeCost = 3400 },
		[8] = { Level = 8, Capacity = 990, UpgradeCost = 4500 },
		[9] = { Level = 9, Capacity = 1230, UpgradeCost = 5800 },
		[10] = { Level = 10, Capacity = 1500, UpgradeCost = 7500 },
	},
	MaxLevel = 10,
	IngredientToCategory = IngredientToCategory,
}

return WarehouseConfig
