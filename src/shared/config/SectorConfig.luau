local SectorConfig= {
    GreenfieldMarket = {
        DisplayName = "Greenfield Market",
        owner = "Netural",
        Status = "Available",
        IngredientType = "Vegetables",
        ProductRate = 5,
    },

    IronMarket = {
        DisplayName = "Iron Market",
        Owner = "Rival",
        Status = "Controlled",
        IngredientType = "Meat",
        ProductRate = 5,
    },
}

return SectorConfig

-- Owner (which faction controls the sector)
-- Status (Wheater it's available or controlled)
-- IngredientType(What resource the sector produces)
-- ProductRate(Amount produced per production interval)
