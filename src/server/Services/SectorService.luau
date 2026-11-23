--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)

export type SectorStatus = "Available" | "Contested" | "Controlled"

export type SectorData = {
	Id: string,
	DisplayName: string,
	Owner: string,
	Status: SectorStatus,
	Category: string,
	IngredientType: string,
	Ingredients: { string },
	ProductionRate: number,
	CaptureTime: number,
	CaptureProgress: number,
	CapturingFaction: string?,
}

export type SectorChangedCallback = (sectorId: string, sector: SectorData) -> ()

local SectorService = {}
local sectors: { [string]: SectorData } = {}
local listeners: { SectorChangedCallback } = {}

local function notifyChanged(sectorId: string, sector: SectorData): ()
	for _, callback in ipairs(listeners) do
		task.spawn(callback, sectorId, sector)
	end
end

function SectorService.Initialize(): ()
	table.clear(sectors)

	for sectorId, config in pairs(SectorConfig.Sectors) do
		local ingredientsCopy: { string } = {}
		for _, item in ipairs(config.Ingredients) do
			table.insert(ingredientsCopy, item)
		end

		sectors[sectorId] = {
			Id = sectorId,
			DisplayName = config.DisplayName,
			Owner = config.Owner,
			Status = config.Status,
			Category = config.Category,
			IngredientType = config.IngredientType,
			Ingredients = ingredientsCopy,
			ProductionRate = config.ProductionRate,
			CaptureTime = config.CaptureTime,
			CaptureProgress = 0,
			CapturingFaction = nil,
		}
	end

	print("[Food Empire] SectorService initialized with 4 territories!")
end

function SectorService.OnSectorChanged(callback: SectorChangedCallback): () -> ()
	table.insert(listeners, callback)
	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

function SectorService.GetSector(sectorId: string): SectorData?
	return sectors[sectorId]
end

function SectorService.GetAllSectors(): { [string]: SectorData }
	return sectors
end

function SectorService.GetOwnedSectors(ownerId: string): { SectorData }
	local owned: { SectorData } = {}
	for _, sector in pairs(sectors) do
		if sector.Owner == ownerId and sector.Status == "Controlled" then
			table.insert(owned, sector)
		end
	end
	return owned
end

function SectorService.SetCaptureState(
	sectorId: string,
	capturingFaction: string?,
	progress: number,
	isContested: boolean
): boolean
	local sector = sectors[sectorId]
	if not sector then
		return false
	end

	local clamped = math.clamp(progress, 0, 1)
	local newStatus: SectorStatus
	if isContested then
		newStatus = "Contested"
	elseif sector.Owner == "Neutral" then
		newStatus = "Available"
	else
		newStatus = "Controlled"
	end

	local changed = sector.CaptureProgress ~= clamped
		or sector.CapturingFaction ~= capturingFaction
		or sector.Status ~= newStatus

	sector.CaptureProgress = clamped
	sector.CapturingFaction = capturingFaction
	sector.Status = newStatus

	if changed then
		notifyChanged(sectorId, sector)
	end

	return true
end

function SectorService.SetOwner(sectorId: string, newOwner: string): boolean
	local sector = sectors[sectorId]

	if not sector then
		warn("[SectorService] Sector not found:", sectorId)
		return false
	end

	sector.Owner = newOwner
	sector.Status = if newOwner == "Neutral" then "Available" else "Controlled"
	sector.CaptureProgress = 0
	sector.CapturingFaction = nil

	print(string.format("[SectorService] %s is now controlled by %s", sector.DisplayName, newOwner))
	notifyChanged(sectorId, sector)
	return true
end

return SectorService
