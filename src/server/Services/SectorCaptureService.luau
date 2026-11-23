--!strict

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local SectorService = require("./SectorService")

local SectorCaptureService = {}

local CHECK_INTERVAL = 0.2
local DECAY_PER_SECOND = 0.25
local EXTRA_UNIT_SPEED_BONUS = 0.25

local isRunning = false
local captureThread: thread? = nil

local function isPositionInsideZone(position: Vector3, zone: BasePart): boolean
	local localPos = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size * 0.5

	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y
		and math.abs(localPos.Z) <= half.Z
end

local function getLivingRoot(model: Model?): BasePart?
	if not model then
		return nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end

	return root
end

local function collectOccupants(zone: BasePart): { [string]: number }
	local factionCounts: { [string]: number } = {}

	-- 1. Live Players
	for _, player in ipairs(Players:GetPlayers()) do
		local root = getLivingRoot(player.Character)
		if root and isPositionInsideZone(root.Position, zone) then
			local factionId = "Player_" .. tostring(player.UserId)
			factionCounts[factionId] = (factionCounts[factionId] or 0) + 1
		end
	end

	-- 2. Live Player Raider Chefs (capture territories for their owner!)
	for _, unit in ipairs(CollectionService:GetTagged("PlayerRaiderUnit")) do
		if unit:IsA("Model") then
			local root = getLivingRoot(unit)
			if root and isPositionInsideZone(root.Position, zone) then
				local factionAttr = unit:GetAttribute("Faction")
				if typeof(factionAttr) == "string" then
					factionCounts[factionAttr] = (factionCounts[factionAttr] or 0) + 1
				end
			end
		end
	end

	-- 3. Live Rival AI Units
	for _, unit in ipairs(CollectionService:GetTagged("RivalAIUnit")) do
		if unit:IsA("Model") then
			local root = getLivingRoot(unit)
			if root and isPositionInsideZone(root.Position, zone) then
				local factionAttr = unit:GetAttribute("Faction")
				local factionId = if typeof(factionAttr) == "string" then factionAttr else "Rival"
				factionCounts[factionId] = (factionCounts[factionId] or 0) + 1
			end
		end
	end

	return factionCounts
end

local function stepZone(zone: BasePart, dt: number): ()
	local sectorIdAttr = zone:GetAttribute("SectorId")
	if typeof(sectorIdAttr) ~= "string" then
		return
	end

	local sector = SectorService.GetSector(sectorIdAttr)
	if not sector then
		return
	end

	local occupants = collectOccupants(zone)
	local uniqueFactions: { string } = {}
	for factionId in pairs(occupants) do
		table.insert(uniqueFactions, factionId)
	end

	-- Case 1: Multiple factions inside zone -> Contested standoff
	if #uniqueFactions > 1 then
		SectorService.SetCaptureState(sectorIdAttr, sector.CapturingFaction, sector.CaptureProgress, true)
		return
	end

	-- Case 2: Exactly one faction inside zone
	if #uniqueFactions == 1 then
		local activeFaction = uniqueFactions[1]
		local unitCount = occupants[activeFaction]

		-- Already owns this territory: clear any leftover enemy capture progress
		if sector.Owner == activeFaction then
			if sector.CaptureProgress > 0 or sector.Status == "Contested" then
				local healed = math.max(0, sector.CaptureProgress - DECAY_PER_SECOND * 2 * dt)
				local capFaction = if healed > 0 then sector.CapturingFaction else nil
				SectorService.SetCaptureState(sectorIdAttr, capFaction, healed, false)
			end
			return
		end

		-- Different faction starts capturing -> reset progress first if switching capturer
		local currentProgress = if sector.CapturingFaction == activeFaction then sector.CaptureProgress else 0
		local speedMultiplier = 1 + math.max(0, unitCount - 1) * EXTRA_UNIT_SPEED_BONUS
		local nextProgress = currentProgress + (dt / math.max(1, sector.CaptureTime)) * speedMultiplier

		if nextProgress >= 1 then
			SectorService.SetOwner(sectorIdAttr, activeFaction)
		else
			SectorService.SetCaptureState(sectorIdAttr, activeFaction, nextProgress, false)
		end
		return
	end

	-- Case 3: Empty zone -> decay any partial capture progress back to 0
	if sector.CaptureProgress > 0 or sector.Status == "Contested" then
		local decayed = math.max(0, sector.CaptureProgress - DECAY_PER_SECOND * dt)
		local capFaction = if decayed > 0 then sector.CapturingFaction else nil
		SectorService.SetCaptureState(sectorIdAttr, capFaction, decayed, false)
	end
end

function SectorCaptureService.Start(): ()
	if isRunning then
		return
	end

	isRunning = true
	-- All 4 map corners are True Neutral, uninteractable supply origins (Shipments depart to Central District).
	print("[Food Empire] SectorCaptureService active (4 corners locked as True Neutral Supply Hubs)!")
end

function SectorCaptureService.Stop(): ()
	isRunning = false
	if captureThread then
		task.cancel(captureThread)
		captureThread = nil
	end
end

return SectorCaptureService
