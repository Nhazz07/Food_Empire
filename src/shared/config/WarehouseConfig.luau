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
	Tag: string,
	Icon: string,
	ShipmentName: string,
	ShipmentShortName: string,
	IngredientSummary: string,
	FoodUnlockSummary: string,
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
	IngredientDisplayNames: { [string]: string },
	GetRequiredWarehousesForIngredients: (ingredients: { [string]: number }) -> { WarehouseCategory },
}

local Specs: { [WarehouseCategory]: WarehouseCategorySpec } = {
	Fish = {
		DisplayName = "Seafood & Fish Ingredient Warehouse",
		ShortLabel = "Seafood & Fish",
		Tag = "FISH",
		Icon = "FISH",
		ShipmentName = "Mafia Seafood & Fish Shipment",
		ShipmentShortName = "MAFIA SEAFOOD SHIPMENT",
		IngredientSummary = "Fish, Shrimp, Crab",
		FoodUnlockSummary = "Grilled Island Fish, Golden Tuna Sashimi, King Crab Platter, Gold-Leaf Lobster",
		UnlockCost = 0, -- Starter Warehouse (Unlocked from the start!)
		AccentColor = Color3.fromRGB(46, 162, 232),
		Ingredients = { "fish", "shrimp", "crab", "golden_tuna", "king_crab" },
	},
	Vegetable = {
		DisplayName = "Farm Vegetable Ingredient Warehouse",
		ShortLabel = "Farm Vegetables",
		Tag = "VEG",
		Icon = "VEG",
		ShipmentName = "Mafia Vegetable Ingredient Shipment",
		ShipmentShortName = "MAFIA VEGETABLE SHIPMENT",
		IngredientSummary = "Carrot, Potato, Cabbage",
		FoodUnlockSummary = "Fresh Sushi, Classic Burger, Truffle Wagyu Tartare, Smoked Cartel Ribs",
		UnlockCost = 1100,
		AccentColor = Color3.fromRGB(74, 188, 86),
		Ingredients = { "carrot", "potato", "cabbage" },
	},
	Fruit = {
		DisplayName = "Orchard Fruit Ingredient Warehouse",
		ShortLabel = "Orchard Fruit",
		Tag = "FRUIT",
		Icon = "FRUIT",
		ShipmentName = "Mafia Fruit Ingredient Shipment",
		ShipmentShortName = "MAFIA FRUIT SHIPMENT",
		IngredientSummary = "Mango, Banana, Orange",
		FoodUnlockSummary = "Tropical Smoothie, Crab Feast, Don's Midnight Tiramisu, Emperor's Platter",
		UnlockCost = 1800,
		AccentColor = Color3.fromRGB(248, 154, 38),
		Ingredients = { "mango", "banana", "orange" },
	},
	Meat = {
		DisplayName = "Butcher Meat Ingredient Warehouse",
		ShortLabel = "Butcher Meat",
		Tag = "MEAT",
		Icon = "MEAT",
		ShipmentName = "Mafia Meat Ingredient Shipment",
		ShipmentShortName = "MAFIA MEAT SHIPMENT",
		IngredientSummary = "Beef, Chicken, Pork",
		FoodUnlockSummary = "Sizzling Steak, Classic Burger, Truffle Wagyu Tartare, Smoked Cartel Ribs",
		UnlockCost = 2600,
		AccentColor = Color3.fromRGB(214, 64, 68),
		Ingredients = { "beef", "chicken", "pork" },
	},
}

local IngredientDisplayNames: { [string]: string } = {
	fish = "Fish",
	shrimp = "Shrimp",
	crab = "Crab",
	golden_tuna = "Golden Tuna",
	king_crab = "King Crab",
	carrot = "Carrot",
	potato = "Potato",
	cabbage = "Cabbage",
	mango = "Mango",
	banana = "Banana",
	orange = "Orange",
	beef = "Beef",
	chicken = "Chicken",
	pork = "Pork",
}

local CategoryOrder: { WarehouseCategory } = { "Fish", "Vegetable", "Fruit", "Meat" }

local IngredientToCategory: { [string]: WarehouseCategory } = {}
for category, spec in pairs(Specs) do
	for _, ingredient in ipairs(spec.Ingredients) do
		IngredientToCategory[ingredient] = category
	end
end

local function getRequiredWarehousesForIngredients(ingredients: { [string]: number }): { WarehouseCategory }
	local needed: { [WarehouseCategory]: boolean } = {}
	for ing, qty in pairs(ingredients) do
		if qty > 0 then
			local cat = IngredientToCategory[ing]
			if cat then
				needed[cat] = true
			end
		end
	end
	local result: { WarehouseCategory } = {}
	for _, cat in ipairs(CategoryOrder) do
		if needed[cat] then
			table.insert(result, cat)
		end
	end
	return result
end

local WarehouseConfig: WarehouseConfigType = {
	Categories = CategoryOrder,
	Specs = Specs,
	Tiers = {
		[0] = { Level = 0, Capacity = 0, UpgradeCost = 0 },
		[1] = { Level = 1, Capacity = 50, UpgradeCost = 0 },
		[2] = { Level = 2, Capacity = 110, UpgradeCost = 1750 },
		[3] = { Level = 3, Capacity = 190, UpgradeCost = 3500 },
		[4] = { Level = 4, Capacity = 290, UpgradeCost = 5750 },
		[5] = { Level = 5, Capacity = 420, UpgradeCost = 8750 },
		[6] = { Level = 6, Capacity = 580, UpgradeCost = 12500 },
		[7] = { Level = 7, Capacity = 770, UpgradeCost = 17000 },
		[8] = { Level = 8, Capacity = 990, UpgradeCost = 22500 },
		[9] = { Level = 9, Capacity = 1230, UpgradeCost = 29000 },
		[10] = { Level = 10, Capacity = 1500, UpgradeCost = 37500 },
	},
	MaxLevel = 10,
	IngredientToCategory = IngredientToCategory,
	IngredientDisplayNames = IngredientDisplayNames,
	GetRequiredWarehousesForIngredients = getRequiredWarehousesForIngredients,
}

return WarehouseConfig
