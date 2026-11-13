
local SectorService = require(
    game:GetService("ServerScriptService")
        :WaitForChild("Services")
        :WaitForChild("SectorService")
)

local IngredientService = {}

local PRODUCTION_INTERVAL = 10

-- Each sector stores its own produced ingredients.
local inventories = {}
local isRunning = false

function IngredientService.Start()
    if isRunning then
        return
    end

    isRunning = true

    -- Create an inventory for every configured sector.
    for sectorId in pairs(SectorService.GetAllSectors()) do
        inventories[sectorId] = {}
    end

    print("Food Empires: Ingredient production started!")

    task.spawn(function()
        while isRunning do
            task.wait(PRODUCTION_INTERVAL)

            for sectorId, sector in pairs(
                SectorService.GetAllSectors()
            ) do
                -- Neutral or uncontrolled sectors produce nothing.
                if sector.Owner ~= "Neutral"
                    and sector.Status == "Controlled" then

                    local ingredient = sector.IngredientType
                    local amount = sector.ProductionRate or 0

                    if ingredient and amount > 0 then
                        inventories[sectorId][ingredient] =
                            (inventories[sectorId][ingredient] or 0)
                            + amount

                        print(
                            "[Production]",
                            sector.DisplayName,
                            "+", amount, ingredient,
                            "| Total:",
                            inventories[sectorId][ingredient]
                        )
                    end
                end
            end
        end
    end)
end

function IngredientService.GetSectorInventory(sectorId)
    local inventory = inventories[sectorId]

    if not inventory then
        return nil
    end

    -- Return a copy so callers cannot directly change server inventory.
    local result = {}

    for ingredient, amount in pairs(inventory) do
        result[ingredient] = amount
    end

    return result
end

function IngredientService.Stop()
    isRunning = false
end

return IngredientService
