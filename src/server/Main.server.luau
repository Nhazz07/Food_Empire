
local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService:WaitForChild("Services")

local SectorService = require(Services:WaitForChild("SectorService"))
local IngredientService = require(Services:WaitForChild("IngredientService"))
local SectorCaptureService = require(Services:WaitForChild("SectorCaptureService"))
local SectorVisualService = require(Services:WaitForChild("SectorVisualService"))

SectorService.Initialize()
IngredientService.Start()
SectorCaptureService.Start()
SectorVisualService.Start()

for sectorId, sector in pairs(SectorService.GetAllSectors()) do
    print(
        sectorId,
        "Owner:", sector.Owner,
        "Ingredient:", sector.IngredientType
    )
end
