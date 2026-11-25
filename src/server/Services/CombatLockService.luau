--!strict

-- CombatLockService: Server-authoritative Combat / Attacking Field teleport lock.
-- Whenever a rival or Mafia unit shoots, slashes, or damages a player, teleporting
-- (Return Home, Branch Warp, Wheel Warp, Black Market Warp, etc.) is blocked until
-- the player physically escapes the attacking field and exits active combat!

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

type CombatState = {
	LastHitAt: number,
	LockUntil: number,
	FieldCenter: Vector3,
	AttackerName: string,
}

local CombatLockService = {}

local COMBAT_LOCK_SECONDS = 12.0
local FIELD_ESCAPE_RADIUS = 115.0
local ACTIVE_THREAT_RADIUS = 75.0
local MIN_SECONDS_AFTER_HIT = 3.0

local HOSTILE_TAGS = {
	"RivalAIUnit",
	"MafiaUnit",
	"MafiaSyndicateUnit",
	"TurfGuardUnit",
	"ApexMafiaUnit",
	"RivalSamuraiUnit",
	"CentralParkRivalSamurai",
	"PenthouseBossUnit",
	"PenthouseGuard",
	"BountyTarget",
}

local states: { [Player]: CombatState } = {}
local isInitialized = false

local function getPlayerPos(player: Player): Vector3?
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function ensureInit(): ()
	if isInitialized then
		return
	end
	isInitialized = true
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	local function hookPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			states[player] = nil
			player:SetAttribute("InCombatUntil", nil)
			player:SetAttribute("CombatAttackerName", nil)
		end)
	end
	Players.PlayerAdded:Connect(hookPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayer(p)
	end
end

local function findNearestLivingHostileDist(player: Player, playerPos: Vector3): number
	local myFaction = "Player_" .. tostring(player.UserId)
	local nearest = math.huge
	for _, tagName in ipairs(HOSTILE_TAGS) do
		for _, unit in ipairs(CollectionService:GetTagged(tagName)) do
			if unit:IsA("Model") and unit.Parent then
				if tagName == "TurfGuardUnit" and unit:GetAttribute("Faction") == myFaction then
					continue
				end
				local hum = unit:FindFirstChildOfClass("Humanoid")
				local root = unit:FindFirstChild("HumanoidRootPart")
				if hum and hum.Health > 0 and root and root:IsA("BasePart") then
					local d = (root.Position - playerPos).Magnitude
					if d < nearest then
						nearest = d
					end
				end
			end
		end
	end
	return nearest
end

function CombatLockService.MarkUnderAttack(player: Player, attackerPos: Vector3?, attackerName: string?): ()
	ensureInit()
	if not player or not player.Parent then
		return
	end
	local now = os.clock()
	local center = attackerPos or getPlayerPos(player) or Vector3.new(0, 4, 0)
	local nameStr = if typeof(attackerName) == "string" and attackerName ~= "" then attackerName else "Hostile Rival"
	local lockUntil = now + COMBAT_LOCK_SECONDS

	states[player] = {
		LastHitAt = now,
		LockUntil = lockUntil,
		FieldCenter = center,
		AttackerName = nameStr,
	}
	player:SetAttribute("InCombatUntil", workspace:GetServerTimeNow() + COMBAT_LOCK_SECONDS)
	player:SetAttribute("CombatAttackerName", nameStr)
end

function CombatLockService.Clear(player: Player): ()
	states[player] = nil
	if player.Parent then
		player:SetAttribute("InCombatUntil", nil)
		player:SetAttribute("CombatAttackerName", nil)
	end
end

function CombatLockService.IsInCombat(player: Player): boolean
	local ok = CombatLockService.CanTeleport(player)
	return not ok
end

function CombatLockService.CanTeleport(player: Player): (boolean, string)
	ensureInit()
	local st = states[player]
	if not st then
		return true, "OK"
	end

	local now = os.clock()
	local pos = getPlayerPos(player)
	if not pos then
		states[player] = nil
		return true, "OK"
	end

	local flatField = Vector3.new(st.FieldCenter.X - pos.X, 0, st.FieldCenter.Z - pos.Z).Magnitude
	local nearestHostile = findNearestLivingHostileDist(player, pos)

	-- Still inside the active combat lock window after being shot or attacked by a rival:
	if now < st.LockUntil then
		-- Allow early escape once player has physically fled outside the attacking field & clear of hostiles!
		local escapedField = (flatField >= FIELD_ESCAPE_RADIUS)
			and (nearestHostile >= ACTIVE_THREAT_RADIUS)
			and ((now - st.LastHitAt) >= MIN_SECONDS_AFTER_HIT)
		if escapedField then
			CombatLockService.Clear(player)
			return true, "OK"
		end

		local remSec = math.max(1, math.ceil(st.LockUntil - now))
		local studsToEscape = math.max(0, math.ceil(FIELD_ESCAPE_RADIUS - flatField))
		if studsToEscape > 0 then
			return false, string.format(
				"COMBAT LOCK: Under attack by %s! Leave the attacking field (%d studs away or %ds) before teleporting!",
				st.AttackerName,
				studsToEscape,
				remSec
			)
		end
		return false, string.format(
			"COMBAT LOCK: Hostile rivals nearby (%s)! Escape combat (%ds) before teleporting!",
			st.AttackerName,
			remSec
		)
	end

	-- Even after timer ticks down, if the player was recently attacked (<25s) and is STILL within 65 studs of active hostiles:
	if (now - st.LastHitAt) < 25.0 and nearestHostile <= 65.0 then
		return false, string.format(
			"COMBAT LOCK: Still inside %s's attacking field (%d studs away)! Escape farther to teleport!",
			st.AttackerName,
			math.max(5, math.ceil(75 - nearestHostile))
		)
	end

	CombatLockService.Clear(player)
	return true, "OK"
end

return CombatLockService
