--!strict

export type SectorConfigEntry = {
	DisplayName: string,
	Owner: string,
	Status: "Available" | "Contested" | "Controlled",
	Category: "Fish" | "Meat" | "Vegetable" | "Fruit",
	IngredientType: string,
	Ingredients: { string },
	ProductionRate: number,
	CaptureTime: number,
}

export type SectorConfigTable = {
	Sectors: { [string]: SectorConfigEntry },
	FactionColors: { [string]: Color3 },
}

local SectorConfig: SectorConfigTable = {
	Sectors = {
		VegetableFarm = {
			DisplayName = "Vegetable Farm",
			Owner = "Neutral",
			Status = "Available",
			Category = "Vegetable",
			IngredientType = "Vegetable",
			Ingredients = { "carrot", "potato", "cabbage" },
			ProductionRate = 4,
			CaptureTime = 10,
		},
		Ranch = {
			DisplayName = "Ranch Territory",
			Owner = "Neutral",
			Status = "Available",
			Category = "Meat",
			IngredientType = "Meat",
			Ingredients = { "beef", "chicken", "pork" },
			ProductionRate = 4,
			CaptureTime = 10,
		},
		FruitOrchard = {
			DisplayName = "Fruit Orchard",
			Owner = "Neutral",
			Status = "Available",
			Category = "Fruit",
			IngredientType = "Fruit",
			Ingredients = { "mango", "banana", "orange" },
			ProductionRate = 4,
			CaptureTime = 10,
		},
		FishingPort = {
			DisplayName = "Fishing Port",
			Owner = "Neutral",
			Status = "Available",
			Category = "Fish",
			IngredientType = "Fish",
			Ingredients = { "fish", "shrimp", "crab" },
			ProductionRate = 4,
			CaptureTime = 10,
		},
	},

	FactionColors = {
		Neutral = Color3.fromRGB(165, 175, 190),
		Rival = Color3.fromRGB(228, 62, 68),
		Contested = Color3.fromRGB(250, 172, 42),
		Player = Color3.fromRGB(48, 202, 114),
		North = Color3.fromRGB(152, 72, 224),
		South = Color3.fromRGB(245, 200, 42),
		East = Color3.fromRGB(42, 172, 245),
		West = Color3.fromRGB(235, 58, 72),
	},
}

return SectorConfig
