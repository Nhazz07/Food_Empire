
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SectorConfig = require(
    ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)

local SectorService = {}

local sectors = {}

function SectorService.Initialize()
    for sectorId, config in pairs(SectorConfig) do
        sectors[sectorId] = {
            Id = sectorId,
            DisplayName = config.DisplayName,
            Owner = config.Owner,
            Status = config.Status,
            IngredientType = config.IngredientType,
            ProductionRate = config.ProductionRate,
        }
    end

    print("Food Empires: Sector system initialized!")
end

function SectorService.GetSector(sectorId)
    return sectors[sectorId]
end

function SectorService.GetAllSectors()
    return sectors
end

function SectorService.SetOwner(sectorId, newOwner)
    local sector = sectors[sectorId]

    if not sector then
        warn("Sector not found:", sectorId)
        return false
    end

    sector.Owner = newOwner
    sector.Status = "Controlled"

    print(sector.DisplayName .. " is now controlled by " .. newOwner)

    return true
end

return SectorService
