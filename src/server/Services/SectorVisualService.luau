--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)
local SectorService = require("./SectorService")

local SectorVisualService = {}

local isRunning = false
local unsubscribeSectorChanged: (() -> ())? = nil
local addedConnection: RBXScriptConnection? = nil

local function getFactionColor(factionId: string?): Color3
	if not factionId or factionId == "Neutral" then
		return SectorConfig.FactionColors.Neutral
	end
	if factionId == "Rival" then
		return SectorConfig.FactionColors.Rival
	end

	local baseSlotStr = string.match(factionId, "^Base_(%a+)$")
	if baseSlotStr and SectorConfig.FactionColors[baseSlotStr] then
		return SectorConfig.FactionColors[baseSlotStr]
	end

	local userIdStr = string.match(factionId, "^Player_(%d+)$")
	if userIdStr then
		local player = Players:GetPlayerByUserId(tonumber(userIdStr) or 0)
		if player then
			local baseSlot = player:GetAttribute("BaseSlot")
			if typeof(baseSlot) == "string" and SectorConfig.FactionColors[baseSlot] then
				return SectorConfig.FactionColors[baseSlot]
			end
		end
		return SectorConfig.FactionColors.Player
	end

	return SectorConfig.FactionColors.Rival
end

local function getOwnerLabel(sector: SectorService.SectorData): (string, Color3)
	if sector.Status == "Contested" then
		return "CONTESTED!", SectorConfig.FactionColors.Contested
	end

	if sector.Owner == "Neutral" then
		return "NEUTRAL SUPPLY HUB", SectorConfig.FactionColors.Neutral
	end

	if sector.Owner == "Rival" then
		return "RIVAL TERRITORY", SectorConfig.FactionColors.Rival
	end

	local baseSlotStr = string.match(sector.Owner, "^Base_(%a+)$")
	if baseSlotStr then
		local color = getFactionColor(sector.Owner)
		local names: { string } = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("BaseSlot") == baseSlotStr then
				table.insert(names, string.upper(p.DisplayName))
			end
		end
		if #names >= 2 then
			return "OWNED BY " .. names[1] .. " & " .. names[2], color
		elseif #names == 1 then
			return "OWNED BY " .. names[1], color
		end
		return string.upper(baseSlotStr) .. " TEAM TERRITORY", color
	end

	local userIdStr = string.match(sector.Owner, "^Player_(%d+)$")
	if userIdStr then
		local player = Players:GetPlayerByUserId(tonumber(userIdStr) or 0)
		local color = getFactionColor(sector.Owner)
		if player then
			return "OWNED BY " .. string.upper(player.DisplayName), color
		end
		return "PLAYER TERRITORY", color
	end

	return string.upper(sector.Owner) .. " TERRITORY", SectorConfig.FactionColors.Rival
end

local function applySectorVisuals(root: Instance, sector: SectorService.SectorData): ()
	local rig = root:FindFirstChild("TerritoryCaptureRig") or root
	local ownerText, ownerColor = getOwnerLabel(sector)

	-- Recolor all TeamColorPart visuals inside the TerritoryCaptureRig (FlagBanner + ZoneRing borders)
	for _, desc in ipairs(rig:GetDescendants()) do
		if desc:IsA("BasePart") and CollectionService:HasTag(desc, "TeamColorPart") then
			desc.Color = ownerColor
		end
	end

	-- Update BillboardGui (SectorName, SectorOwner & live capture ProgressFill)
	local billboard = rig:FindFirstChild("SectorBillboard", true)
	if billboard and billboard:IsA("BillboardGui") then
		local nameLabel = billboard:FindFirstChild("SectorName")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = string.upper(sector.DisplayName)
		end

		local ownerLabel = billboard:FindFirstChild("SectorOwner")
		if ownerLabel and ownerLabel:IsA("TextLabel") then
			ownerLabel.Text = ownerText
			ownerLabel.BackgroundColor3 = ownerColor
		end

		local progressBar = billboard:FindFirstChild("ProgressBar")
		if progressBar then
			local fill = progressBar:FindFirstChild("ProgressFill")
			if fill and fill:IsA("Frame") then
				fill.Size = UDim2.new(math.clamp(sector.CaptureProgress, 0, 1), 0, 1, 0)
				fill.BackgroundColor3 = if sector.CapturingFaction
					then getFactionColor(sector.CapturingFaction)
					else ownerColor
			end
		end
	end
end

local function refreshSectorById(sectorId: string, sector: SectorService.SectorData): ()
	for _, root in ipairs(CollectionService:GetTagged("SectorVisualRoot")) do
		if root:GetAttribute("SectorId") == sectorId then
			applySectorVisuals(root, sector)
		end
	end
end

function SectorVisualService.RefreshAll(): ()
	for _, root in ipairs(CollectionService:GetTagged("SectorVisualRoot")) do
		local sectorIdAttr = root:GetAttribute("SectorId")
		if typeof(sectorIdAttr) == "string" then
			local sector = SectorService.GetSector(sectorIdAttr)
			if sector then
				applySectorVisuals(root, sector)
			end
		end
	end
end

function SectorVisualService.Start(): ()
	if isRunning then
		return
	end

	isRunning = true
	SectorVisualService.RefreshAll()

	unsubscribeSectorChanged = SectorService.OnSectorChanged(function(sectorId, sector)
		refreshSectorById(sectorId, sector)
	end)

	addedConnection = CollectionService:GetInstanceAddedSignal("SectorVisualRoot"):Connect(function(root)
		local sectorIdAttr = root:GetAttribute("SectorId")
		if typeof(sectorIdAttr) == "string" then
			local sector = SectorService.GetSector(sectorIdAttr)
			if sector then
				applySectorVisuals(root, sector)
			end
		end
	end)

	print("[Food Empire] SectorVisualService started (real-time flags, rings & progress bars)!")
end

function SectorVisualService.Stop(): ()
	isRunning = false

	if unsubscribeSectorChanged then
		unsubscribeSectorChanged()
		unsubscribeSectorChanged = nil
	end

	if addedConnection then
		addedConnection:Disconnect()
		addedConnection = nil
	end
end

return SectorVisualService
