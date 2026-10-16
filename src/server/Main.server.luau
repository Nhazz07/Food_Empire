
local ServerScriptService = game:GetService("ServerScriptService")

local SectorService = require(
    ServerScriptService:WaitForChild("Services"):WaitForChild("SectorService")
)

SectorService.Initialize()

for sectorId, sector in pairs(SectorService.GetAllSectors()) do
    print(
        sectorId,
        "Owner:", sector.Owner,
        "Ingredient:", sector.IngredientType
    )
end
