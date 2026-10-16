
local SectorConfig = {
    GreenfieldMarket = {
        DisplayName = "Greenfield Market",
        Owner = "Neutral",
        Status = "Available",
        IngredientType = "Vegetables",
        ProductionRate = 5,
    },

    IronMarket = {
        DisplayName = "Iron Market",
        Owner = "Rival",
        Status = "Controlled",
        IngredientType = "Meat",
        ProductionRate = 5,
    },
}

return SectorConfig

-- Owner (which faction controls the sector)
-- Status (Wheater it's available or controlled)
-- IngredientType(What resource the sector produces)
-- ProductRate(Amount produced per production interval)
