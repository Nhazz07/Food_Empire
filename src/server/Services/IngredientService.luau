--!strict

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local SectorService = require("./SectorService")
local WarehouseService = require("./WarehouseService")
local MonetizationService = require("./MonetizationService")

export type SectorInventory = { [string]: number }

local IngredientService = {}

local PRODUCTION_INTERVAL = 8

-- Stores fallback sector stock (e.g. for Rival-owned territories or analytics).
local inventories: { [string]: SectorInventory } = {}
local isRunning = false
local productionThread: thread? = nil

local function ensureSectorInventory(sectorId: string): SectorInventory
	local existing = inventories[sectorId]
	if existing then
		return existing
	end

	local created: SectorInventory = {}
	inventories[sectorId] = created
	return created
end

local function pulseResourceNodes(sectorId: string): ()
	for _, node in ipairs(CollectionService:GetTagged("ResourceNode")) do
		if node:IsA("BasePart") and node:GetAttribute("SectorId") == sectorId then
			local origTransparency = node.Transparency
			node.Transparency = 0.15
			task.delay(0.45, function()
				if node.Parent then
					node.Transparency = origTransparency
				end
			end)
		end
	end
end

local function resolveOwnerPlayer(ownerId: string): Player?
	local userIdStr = string.match(ownerId, "^Player_(%d+)$")
	if not userIdStr then
		return nil
	end
	local userId = tonumber(userIdStr)
	if not userId then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function produceForSector(sectorId: string, sector: SectorService.SectorData): ()
	if sector.Owner == "Neutral" or sector.Status ~= "Controlled" then
		return
	end

	local ingredients = sector.Ingredients
	local totalRate = sector.ProductionRate or 0
	if #ingredients == 0 or totalRate <= 0 then
		return
	end

	local perItem = math.max(1, math.floor(totalRate / #ingredients))
	local ownerPlayer = resolveOwnerPlayer(sector.Owner)

	if ownerPlayer then
		local deliveryMult = MonetizationService.GetDeliveryMultiplier(ownerPlayer)
		local deliveredSummary: { string } = {}
		for _, itemName in ipairs(ingredients) do
			local stored = WarehouseService.AddIngredient(ownerPlayer, itemName, perItem * deliveryMult)
			if stored > 0 then
				table.insert(deliveredSummary, string.format("+%d %s", stored, itemName))
			end
		end

		if #deliveredSummary > 0 then
			pulseResourceNodes(sectorId)
			print(
				string.format(
					"[Supply -> %s] %s delivered %s",
					ownerPlayer.Name,
					sector.DisplayName,
					table.concat(deliveredSummary, ", ")
				)
			)
		end
	else
		-- Rival or offline faction: track inside sector stockpile
		local sectorInv = ensureSectorInventory(sectorId)
		for _, itemName in ipairs(ingredients) do
			sectorInv[itemName] = (sectorInv[itemName] or 0) + perItem
		end
	end
end

function IngredientService.Start(): ()
	if isRunning then
		return
	end

	isRunning = true

	for sectorId in pairs(SectorService.GetAllSectors()) do
		ensureSectorInventory(sectorId)
	end

	print("[Food Empire] IngredientService started (auto-delivering to player Warehouses every 8s)!")

	productionThread = task.spawn(function()
		while isRunning do
			task.wait(PRODUCTION_INTERVAL)

			if not isRunning then
				break
			end

			for sectorId, sector in pairs(SectorService.GetAllSectors()) do
				produceForSector(sectorId, sector)
			end
		end
	end)
end

function IngredientService.GetSectorInventory(sectorId: string): SectorInventory?
	local inventory = inventories[sectorId]
	if not inventory then
		return nil
	end

	local result: SectorInventory = {}
	for ingredient, amount in pairs(inventory) do
		result[ingredient] = amount
	end
	return result
end

function IngredientService.Stop(): ()
	isRunning = false
	if productionThread then
		task.cancel(productionThread)
		productionThread = nil
	end
end

return IngredientService
