--!strict

-- DefenseCompanionService (Stage 5 & Stage 6 — Hiring Ninjas/Bodyguards + Restaurant Defense AI)
-- Server-authoritative timed restaurant defense companion contract, 20s respawn & 4-tier Defense AI.
--
-- Supports 4 companion types:
--   1. Ninja          (Fast melee interceptor within bounded restaurant defense perimeter)
--   2. Assassin       (High-DPS striker, faster attacks, warehouse & high-threat flanker)
--   3. Bodyguard      (Defensive entrance protector, ranged, clear-LOS fire discipline)
--   4. EliteBodyguard (Heavy defender, higher survivability, guards entrance & money vault)
--
-- Stage 5 Server Guarantees:
--   * Timed contracts for 5 minutes (300s) or 10 minutes (600s), starting upon deployment.
--   * Separate configurable HP & damage strictly lower than Player default HP (100); NOT invincible!
--   * Exact 20-second respawn timer if killed while contract is active, restoring configured HP,
--     returning to assigned post, and continuing remaining contract duration.
--   * Never respawns if contract expires while dead.
--   * Strictly prevents multiple copies of the same hired companion from spawning.
--
-- Stage 6 Restaurant Defense AI Guarantees:
--   * Priority 1: Attack Mafia actively threatening/attacking the Restaurant HQ & dining zone.
--   * Priority 2: Protect Warehouses & Money Storage (Serve Counter / Vault) from threats.
--   * Priority 3: Protect the Restaurant Entrance / Grand Front Gate from incoming Mafia.
--   * Priority 4: Return smoothly to assigned defensive post when no threat remains (facing outward).
--   * Obstacle-aware navigation (LOS raycast + PathfindingService + sidestep/jump recovery around
--     doors, walls, counters, and dining tables) and clear-LOS ranged firing.
--   * Strict bounded restaurant base perimeter — companions NEVER wander or chase across the map!

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local RestaurantSecurityConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RestaurantSecurityConfig")
)
local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)

local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local BlackMarketService = require("./BlackMarketService")
local WarehouseService = require("./WarehouseService")
local NightMafiaRaidService = require("./NightMafiaRaidService")

export type CompanionTypeId = RestaurantSecurityConfig.CompanionTypeId
export type CompanionState = "Active" | "Respawning" | "Expired"
export type DefenseMode =
	"P1_ATTACK_RESTAURANT"
	| "P2_PROTECT_STORAGE"
	| "P3_PROTECT_ENTRANCE"
	| "P4_RETURN_POST"
	| "POST_GUARD"
	| "RAID_ALERT"

export type CompanionContractSnapshot = {
	ContractId: string,
	CompanionType: CompanionTypeId,
	DisplayName: string,
	ShortTitle: string,
	RoleTag: string,
	State: CompanionState,
	DefenseMode: DefenseMode,
	PriorityTier: number,
	DurationSeconds: number,
	TimeRemaining: number,
	RespawnRemaining: number,
	CurrentHP: number,
	MaxHP: number,
}

export type PlayerCompanionsSnapshot = {
	ActiveCount: number,
	MaxActive: number,
	RespawnDelaySeconds: number,
	Contracts: { [CompanionTypeId]: CompanionContractSnapshot },
	List: { CompanionContractSnapshot },
}

type PathNode = {
	Pos: Vector3,
	Jump: boolean,
}

type BaseDefenseZones = {
	BaseCF: CFrame,
	BaseCenterPos: Vector3,
	ForwardDir: Vector3,
	RightDir: Vector3,
	GateEntrancePos: Vector3,
	RestaurantFrontPos: Vector3,
	MoneyStoragePos: Vector3,
	PrimaryWarehousePos: Vector3,
	WarehouseAnchors: { Vector3 },
	ComputedAt: number,
}

type DefenseDirective = {
	PriorityTier: number, -- 1, 2, 3, or 4
	Mode: DefenseMode,
	StatusText: string,
	StatusColor: Color3,
	TargetModel: Model?,
	TargetHumanoid: Humanoid?,
	TargetPos: Vector3?,
	GuardAnchorPos: Vector3,
}

type CompanionContract = {
	ContractId: string,
	Owner: Player,
	BaseSlot: BaseService.BaseSlot,
	CompanionType: CompanionTypeId,
	Spec: RestaurantSecurityConfig.CompanionSpec,
	ConfiguredMaxHP: number,
	DurationSeconds: number,
	DeployedAt: number,
	ExpiresAt: number,
	State: CompanionState,
	RespawnAt: number?,
	SpawnGeneration: number,
	Zones: BaseDefenseZones,
	AssignedPostPos: Vector3,
	BaseCenterPos: Vector3,
	Model: Model?,
	Humanoid: Humanoid?,
	Root: BasePart?,
	TimerLabel: TextLabel?,
	HPFill: Frame?,
	HPText: TextLabel?,
	DefenseMode: DefenseMode,
	PriorityTier: number,
	CurrentTargetName: string?,
	LastAttackAt: number,
	AttacksLanded: number,
	LastPos: Vector3,
	StuckTime: number,
	HardStuckTime: number,
	StuckRecoveries: number,
	SideStepSign: number,
	UsingPathfinding: boolean,
	PathWaypoints: { PathNode }?,
	PathIndex: number,
	LastPathAt: number,
	LastPathGoal: Vector3,
}

local DefenseCompanionService = {}

local HOSTILE_TAGS = {
	"NightRaidMafiaUnit",
	"MafiaUnit",
	"RivalAIUnit",
	"ApexMafiaUnit",
	"RivalSamuraiUnit",
}

local STATUS_COLORS = {
	P1 = Color3.fromRGB(246, 98, 106),
	P2 = Color3.fromRGB(246, 198, 74),
	P3 = Color3.fromRGB(96, 186, 250),
	P4 = Color3.fromRGB(184, 196, 214),
	Guard = Color3.fromRGB(168, 232, 188),
	Alert = Color3.fromRGB(255, 168, 68),
}

local isRunning = false
local companionFolder: Folder? = nil
local testDummyFolder: Folder? = nil
local aiThread: thread? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local testBridge: BindableFunction? = nil
local onChangedCb: ((player: Player) -> ())? = nil
local raidWarningHooked = false

local contractSerial = 0
local contractsByPlayer: { [Player]: { [CompanionTypeId]: CompanionContract } } = {}

local function getCfg(): RestaurantSecurityConfig.HiredCompanionsConfig
	return RestaurantSecurityConfig.HiredCompanions
end

local function getAICfg(): RestaurantSecurityConfig.DefenseAIConfig
	return RestaurantSecurityConfig.DefenseAI
end

local function sendToast(player: Player, msg: string): ()
	if not player.Parent then
		return
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg)
	end
end

local function notifyChanged(player: Player): ()
	if onChangedCb and player.Parent then
		task.spawn(onChangedCb, player)
	end
end

local function formatMMSS(sec: number): string
	local s = math.max(0, math.ceil(sec))
	return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

local function horizDist(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- =============================================================================
-- DYNAMIC BASE DEFENSE ZONE GEOMETRY (Works on all 4 bases & HQ Lv.1-15!)
-- =============================================================================
local function computeBaseDefenseZones(
	baseModel: Model,
	slot: BaseService.BaseSlot,
	owner: Player
): BaseDefenseZones
	local bp = baseModel:FindFirstChild("BasePivot")
	local baseCF = if bp and bp:IsA("BasePart") then bp.CFrame else baseModel:GetPivot()
	local baseCenter = Vector3.new(baseCF.Position.X, 4.2, baseCF.Position.Z)

	-- Outward forward vector points from BaseCenter toward GrandFrontGate (local +Z)
	local rawFront = (baseCF * CFrame.new(0, 0, 112)).Position
	local fwdFlat = Vector3.new(rawFront.X - baseCenter.X, 0, rawFront.Z - baseCenter.Z)
	local forwardDir = if fwdFlat.Magnitude > 0.1 then fwdFlat.Unit else Vector3.new(0, 0, 1)
	local rightDir = Vector3.new(-forwardDir.Z, 0, forwardDir.X).Unit

	-- 1. Entrance Gate Zone (just inside GrandFrontGate archway, facing incoming Mafia)
	local gatePos = Vector3.new((baseCF * CFrame.new(0, 0, 94)).Position.X, 4.2, (baseCF * CFrame.new(0, 0, 94)).Position.Z)
	local def = baseModel:FindFirstChild("Defenses")
	local gateModel = if def then def:FindFirstChild("GrandFrontGate", true) else nil
	if gateModel and gateModel:IsA("Model") then
		local gateCF = gateModel:GetBoundingBox()
		local toCenter = Vector3.new(baseCenter.X - gateCF.Position.X, 0, baseCenter.Z - gateCF.Position.Z)
		if toCenter.Magnitude > 1 then
			local inward = toCenter.Unit
			gatePos = Vector3.new(gateCF.Position.X, 4.2, gateCF.Position.Z) + inward * 18
		end
	end

	-- 2. Restaurant Front Zone (scales dynamically with Lv.1-15 HQ & Front Wood Pavilion!)
	local restPos = Vector3.new((baseCF * CFrame.new(0, 0, 38)).Position.X, 4.2, (baseCF * CFrame.new(0, 0, 38)).Position.Z)
	local moneyPos = Vector3.new((baseCF * CFrame.new(10, 0, 34)).Position.X, 4.2, (baseCF * CFrame.new(10, 0, 34)).Position.Z)
	local hq = baseModel:FindFirstChild("RestaurantHQ")
	if hq and hq:IsA("Model") then
		local hqCF, hqSize = hq:GetBoundingBox()
		local frontOffset = math.clamp(hqSize.Z * 0.45 + 14, 22, 46)
		local cand = Vector3.new(hqCF.Position.X, 4.2, hqCF.Position.Z) + forwardDir * frontOffset
		restPos = Vector3.new(cand.X, 4.2, cand.Z)

		-- Money Storage / Cash Counter anchor (shifted outside solid counter geometry into open floor!)
		local anchors = hq:FindFirstChild("Anchors")
		local serveCounter = if anchors then anchors:FindFirstChild("ServeCounter") else nil
		if serveCounter and serveCounter:IsA("BasePart") then
			local scPos = Vector3.new(serveCounter.Position.X, 4.2, serveCounter.Position.Z) + forwardDir * 12
			moneyPos = Vector3.new(scPos.X, 4.2, scPos.Z)
		else
			moneyPos = Vector3.new((restPos - forwardDir * 6 + rightDir * 8).X, 4.2, (restPos - forwardDir * 6 + rightDir * 8).Z)
		end
	end

	-- 3. Warehouse Defense Anchors (scans unlocked WarehousePlots on this owner's base!)
	local unlockedAnchors: { Vector3 } = {}
	local allAnchors: { Vector3 } = {}
	local bestStock = -1
	local primaryWhPos = Vector3.new((baseCF * CFrame.new(-32, 0, -64)).Position.X, 4.2, (baseCF * CFrame.new(-32, 0, -64)).Position.Z)

	local inv = if owner.Parent then WarehouseService.GetInventorySnapshot(owner) else nil
	for _, plot in ipairs(CollectionService:GetTagged("WarehousePlot")) do
		if plot:GetAttribute("BaseSlot") == slot then
			local catAttr = plot:GetAttribute("Category")
			local pad = plot:FindFirstChild("PlotPivot")
			if typeof(catAttr) == "string" and pad and pad:IsA("BasePart") then
				local toCenter = Vector3.new(baseCenter.X - pad.Position.X, 0, baseCenter.Z - pad.Position.Z)
				local frontDir = if toCenter.Magnitude > 1 then toCenter.Unit else forwardDir
				local apronPos = Vector3.new(pad.Position.X, 4.2, pad.Position.Z) + frontDir * 16
				table.insert(allAnchors, apronPos)

				local cat = catAttr :: WarehouseConfig.WarehouseCategory
				local lv = if inv and inv.Levels then (inv.Levels[cat] or 0) else 1
				if lv >= 1 then
					table.insert(unlockedAnchors, apronPos)
					local catTotal = if inv and inv.CategoryTotals then (inv.CategoryTotals[cat] or 0) else 0
					if catTotal > bestStock then
						bestStock = catTotal
						primaryWhPos = apronPos
					end
				end
			end
		end
	end

	local warehouseAnchors = if #unlockedAnchors > 0 then unlockedAnchors else allAnchors
	if #warehouseAnchors == 0 then
		table.insert(warehouseAnchors, primaryWhPos)
	elseif bestStock < 0 then
		primaryWhPos = warehouseAnchors[1]
	end

	return {
		BaseCF = baseCF,
		BaseCenterPos = baseCenter,
		ForwardDir = forwardDir,
		RightDir = rightDir,
		GateEntrancePos = gatePos,
		RestaurantFrontPos = restPos,
		MoneyStoragePos = moneyPos,
		PrimaryWarehousePos = primaryWhPos,
		WarehouseAnchors = warehouseAnchors,
		ComputedAt = os.clock(),
	}
end

local function clampToBaseDefenseBounds(worldPos: Vector3, zones: BaseDefenseZones): Vector3
	local aiCfg = getAICfg()
	local localP = zones.BaseCF:PointToObjectSpace(worldPos)
	local cx = math.clamp(localP.X, -aiCfg.BaseLocalBoundsX, aiCfg.BaseLocalBoundsX)
	local cz = math.clamp(localP.Z, aiCfg.BaseLocalBoundsMinZ, aiCfg.BaseLocalBoundsMaxZ)
	local clampedWorld = (zones.BaseCF * CFrame.new(cx, 0, cz)).Position
	local flat = Vector3.new(clampedWorld.X - zones.BaseCenterPos.X, 0, clampedWorld.Z - zones.BaseCenterPos.Z)
	if flat.Magnitude > aiCfg.MaxBaseDefenseRadius then
		local capped = zones.BaseCenterPos + flat.Unit * aiCfg.MaxBaseDefenseRadius
		return Vector3.new(capped.X, 4.2, capped.Z)
	end
	return Vector3.new(clampedWorld.X, 4.2, clampedWorld.Z)
end

local function isInsideBaseDefenseBounds(
	worldPos: Vector3,
	zones: BaseDefenseZones,
	extraGateMargin: number?
): boolean
	local aiCfg = getAICfg()
	local localP = zones.BaseCF:PointToObjectSpace(worldPos)
	local maxZ = aiCfg.BaseLocalBoundsMaxZ + (extraGateMargin or 0)
	if math.abs(localP.X) > aiCfg.BaseLocalBoundsX then
		return false
	end
	if localP.Z < aiCfg.BaseLocalBoundsMinZ or localP.Z > maxZ then
		return false
	end
	local maxRad = aiCfg.MaxBaseDefenseRadius + (extraGateMargin or 0)
	return horizDist(worldPos, zones.BaseCenterPos) <= maxRad
end

local function computeAssignedPostFromZones(zones: BaseDefenseZones, postKind: string): Vector3
	local rawPos: Vector3
	if postKind == "Entrance" then
		-- Bodyguard: anchors left side of Grand Front Gate approach lane
		rawPos = zones.GateEntrancePos - zones.ForwardDir * 10 - zones.RightDir * 12
	elseif postKind == "EntranceAndVault" then
		-- Elite Bodyguard: covers the corridor between Money Storage / Restaurant Entrance & Gate
		local mid = zones.RestaurantFrontPos:Lerp(zones.GateEntrancePos, 0.36)
		rawPos = mid + zones.RightDir * 12
	elseif postKind == "WarehouseFlank" then
		-- Assassin: flanks the Warehouse courtyard with quick sprint lane to Restaurant & Gate
		rawPos = zones.PrimaryWarehousePos + zones.ForwardDir * 10 + zones.RightDir * 8
	else
		-- Shadow Ninja ("PlazaPatrol"): central plaza interceptor with instant access to all zones
		rawPos = zones.RestaurantFrontPos + zones.ForwardDir * 12 - zones.RightDir * 16
	end
	return clampToBaseDefenseBounds(rawPos, zones)
end

local function refreshContractZonesIfNeeded(contract: CompanionContract, now: number, force: boolean?): ()
	local aiCfg = getAICfg()
	if not force and (now - contract.Zones.ComputedAt) < aiCfg.PostRefreshInterval then
		return
	end
	local baseModel = BaseService.GetBaseModel(contract.BaseSlot)
	if not baseModel or not baseModel.Parent then
		return
	end
	local zones = computeBaseDefenseZones(baseModel, contract.BaseSlot, contract.Owner)
	contract.Zones = zones
	contract.BaseCenterPos = zones.BaseCenterPos
	contract.AssignedPostPos = computeAssignedPostFromZones(zones, contract.Spec.AssignedPost)
end

-- =============================================================================
-- OBSTACLE-AWARE RAYCAST & PATHFINDING NAVIGATION
-- =============================================================================
local function buildWorldObstacleRayParams(extraIgnore: Instance?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true

	local ignoreList: { Instance } = {}
	local folderNames = {
		"HiredDefenseCompanions",
		"NightMafiaRaids",
		"ActiveMafia",
		"Customers",
		"RestaurantStaff",
		"PlayerBodyguards",
		"MercenaryMafia",
		"Stage6TestHostiles",
	}
	for _, fn in ipairs(folderNames) do
		local f = Workspace:FindFirstChild(fn)
		if f then
			table.insert(ignoreList, f)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignoreList, p.Character)
		end
	end
	if extraIgnore then
		table.insert(ignoreList, extraIgnore)
	end
	params.FilterDescendantsInstances = ignoreList
	return params
end

local function isMovementPathObstructed(fromPos: Vector3, toPos: Vector3): boolean
	local flat = Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
	local dist = flat.Magnitude
	if dist <= 5.5 then
		return false
	end
	local aiCfg = getAICfg()
	local dir = flat.Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local rayLen = math.max(1.5, dist - 2.5)
	local params = buildWorldObstacleRayParams(nil)
	local yOff = aiCfg.ObstacleRayHeight

	-- Center + dual shoulder rays catch doorways, walls, counters, and dining tables accurately!
	for _, lat in ipairs({ 0, -1.15, 1.15 }) do
		local origin = Vector3.new(fromPos.X, fromPos.Y + yOff, fromPos.Z) + side * lat
		local hit = Workspace:Raycast(origin, dir * rayLen, params)
		if hit and hit.Instance and hit.Instance.CanCollide then
			return true
		end
	end
	return false
end

local function hasClearRangedLOS(fromPos: Vector3, targetPos: Vector3, targetModel: Model?): boolean
	local origin = Vector3.new(fromPos.X, fromPos.Y + 2.2, fromPos.Z)
	local aimPt = Vector3.new(targetPos.X, targetPos.Y + 1.8, targetPos.Z)
	local vec = aimPt - origin
	if vec.Magnitude <= 3.5 then
		return true
	end
	local params = buildWorldObstacleRayParams(targetModel)
	local hit = Workspace:Raycast(origin, vec, params)
	if not hit then
		return true
	end
	-- Allow slight grazing hits right at the target's feet/edge; block true walls/pillars
	return (hit.Position - aimPt).Magnitude <= 3.2
end

local function computePathNodes(fromPos: Vector3, toPos: Vector3): { PathNode }?
	local path = PathfindingService:CreatePath({
		AgentRadius = 2.0,
		AgentHeight = 5.2,
		AgentCanJump = true,
		AgentCanClimb = false,
		WaypointSpacing = 8,
	})
	local ok = pcall(function()
		path:ComputeAsync(fromPos, toPos)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local rawWps = path:GetWaypoints()
	local nodes: { PathNode } = {}
	for idx = 2, #rawWps do
		local wp = rawWps[idx]
		table.insert(nodes, {
			Pos = wp.Position,
			Jump = wp.Action == Enum.PathWaypointAction.Jump,
		})
	end
	return if #nodes > 0 then nodes else nil
end

local function faceHorizontalDir(root: BasePart, dir: Vector3): ()
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.05 then
		return
	end
	local pos = root.Position
	root.CFrame = CFrame.lookAt(pos, pos + flat.Unit)
end

local function moveCompanionSmart(
	contract: CompanionContract,
	rawDest: Vector3,
	now: number,
	dt: number
): ()
	local hum = contract.Humanoid
	local root = contract.Root
	if not hum or not root then
		return
	end

	local aiCfg = getAICfg()
	local zones = contract.Zones
	local pos = root.Position
	local dest = clampToBaseDefenseBounds(rawDest, zones)
	local distToDest = horizDist(pos, dest)

	if distToDest <= 2.4 then
		contract.PathWaypoints = nil
		contract.UsingPathfinding = false
		contract.StuckTime = 0
		contract.HardStuckTime = 0
		return
	end

	local moved = horizDist(pos, contract.LastPos)
	contract.LastPos = pos

	if moved < aiCfg.StuckDistanceThreshold then
		contract.StuckTime += dt
		contract.HardStuckTime += dt
	else
		contract.StuckTime = 0
		contract.HardStuckTime = 0
	end

	local obstructed = isMovementPathObstructed(pos, dest)
	local isStuck = contract.StuckTime >= aiCfg.StuckTimeoutSeconds

	-- Recompute pathfinding route whenever walls/doors/tables obstruct LOS or unit stalls
	if obstructed or isStuck then
		local goalShifted = horizDist(dest, contract.LastPathGoal) >= 9.0
		local needPath = (contract.PathWaypoints == nil) or goalShifted or isStuck
		if needPath and (now - contract.LastPathAt) >= aiCfg.PathRecomputeInterval then
			contract.LastPathAt = now
			contract.LastPathGoal = dest
			local nodes = computePathNodes(pos, dest)
			if nodes then
				contract.PathWaypoints = nodes
				contract.PathIndex = 1
				contract.UsingPathfinding = true
				if isStuck then
					contract.StuckTime = 0
					contract.StuckRecoveries += 1
				end
			elseif isStuck then
				-- Lateral sidestep + hop to clear table legs, chairs, or doorway jambs cleanly!
				contract.StuckTime = 0
				contract.StuckRecoveries += 1
				contract.SideStepSign = -contract.SideStepSign
				local toDest = Vector3.new(dest.X - pos.X, 0, dest.Z - pos.Z)
				if toDest.Magnitude > 0.5 then
					local dir = toDest.Unit
					local side = Vector3.new(-dir.Z, 0, dir.X) * contract.SideStepSign
					local sidestepDest = clampToBaseDefenseBounds(pos + side * 7 + dir * 4, zones)
					hum.Jump = true
					hum:MoveTo(sidestepDest)
					return
				end
			end
		end
	elseif contract.PathWaypoints and distToDest <= 14 then
		-- Direct unobstructed approach inside close range — drop old detour for crisp movement!
		contract.PathWaypoints = nil
		contract.UsingPathfinding = false
	end

	-- Hard unstick safeguard if physically wedged inside furniture/pillars for >5.5s (NEVER leaves base!)
	if contract.HardStuckTime >= aiCfg.HardUnstickSeconds then
		contract.HardStuckTime = 0
		contract.StuckTime = 0
		contract.StuckRecoveries += 1
		local stepTarget = if contract.PathWaypoints and contract.PathWaypoints[contract.PathIndex]
			then contract.PathWaypoints[contract.PathIndex].Pos
			else dest
		local vec = Vector3.new(stepTarget.X - pos.X, 0, stepTarget.Z - pos.Z)
		if vec.Magnitude > 1 then
			local safeStep = clampToBaseDefenseBounds(pos + vec.Unit * math.min(6, vec.Magnitude), zones)
			root.CFrame = CFrame.new(safeStep.X, 4.5, safeStep.Z)
			hum.Jump = true
		end
		return
	end

	-- Follow active obstacle-avoiding Pathfinding waypoints if present
	if contract.PathWaypoints and contract.PathIndex <= #contract.PathWaypoints then
		local node = contract.PathWaypoints[contract.PathIndex]
		if horizDist(pos, node.Pos) <= 5.2 then
			contract.PathIndex += 1
			if contract.PathIndex > #contract.PathWaypoints then
				contract.PathWaypoints = nil
				contract.UsingPathfinding = false
			else
				node = contract.PathWaypoints[contract.PathIndex]
			end
		end
		if contract.PathWaypoints then
			contract.UsingPathfinding = true
			if node.Jump then
				hum.Jump = true
			end
			hum:MoveTo(clampToBaseDefenseBounds(node.Pos, zones))
			return
		end
	end

	contract.UsingPathfinding = false
	hum:MoveTo(dest)
end

-- =============================================================================
-- 4-TIER PRIORITY DEFENSE DECISION ENGINE (STAGE 6)
--   Priority 1: Attack Mafia actively threatening/attacking the Restaurant
--   Priority 2: Protect Warehouses & Money Storage (Serve Counter / Vault)
--   Priority 3: Protect Restaurant Entrance / Grand Front Gate
--   Priority 4: Return smoothly to assigned defensive post
-- =============================================================================
local function getNearestWarehouseDistance(enemyPos: Vector3, zones: BaseDefenseZones): (number, Vector3)
	local bestDist = math.huge
	local bestAnchor = zones.PrimaryWarehousePos
	for _, anchor in ipairs(zones.WarehouseAnchors) do
		local d = horizDist(enemyPos, anchor)
		if d < bestDist then
			bestDist = d
			bestAnchor = anchor
		end
	end
	return bestDist, bestAnchor
end

local function evaluateDefenseDirective(contract: CompanionContract, myPos: Vector3): DefenseDirective
	local aiCfg = getAICfg()
	local spec = contract.Spec
	local zones = contract.Zones
	local owner = contract.Owner

	local ownerPosInBase: Vector3? = nil
	if owner.Character then
		local oRoot = owner.Character:FindFirstChild("HumanoidRootPart")
		if oRoot and oRoot:IsA("BasePart") and isInsideBaseDefenseBounds(oRoot.Position, zones, 8) then
			ownerPosInBase = oRoot.Position
		end
	end

	local bestPriority = 99
	local bestTieScore = math.huge
	local bestModel: Model? = nil
	local bestHum: Humanoid? = nil
	local bestPos: Vector3? = nil
	local bestMode: DefenseMode = "P4_RETURN_POST"
	local bestGuardAnchor = contract.AssignedPostPos

	local seenModels: { [Model]: boolean } = {}

	for _, tagName in ipairs(HOSTILE_TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
			if inst:IsA("Model") and inst.Parent and not seenModels[inst] then
				seenModels[inst] = true

				-- Strict safety filters: NEVER attack players or friendly units!
				if Players:GetPlayerFromCharacter(inst) ~= nil then
					continue
				end
				if CollectionService:HasTag(inst, "HiredDefenseCompanion")
					or CollectionService:HasTag(inst, "PlayerBodyguardUnit")
					or CollectionService:HasTag(inst, "MercenaryMafiaUnit")
				then
					continue
				end

				local hum = inst:FindFirstChildOfClass("Humanoid")
				local root = inst:FindFirstChild("HumanoidRootPart")
				if not hum or hum.Health <= 0 or not root or not root:IsA("BasePart") then
					continue
				end

				local enemyPos = root.Position
				local isNightRaider = CollectionService:HasTag(inst, "NightRaidMafiaUnit")
				local raidOwnerId = inst:GetAttribute("RaidOwnerUserId")
				local isMyRaider = isNightRaider and (raidOwnerId == owner.UserId)

				-- Ignore night raiders belonging to another player's base
				if isNightRaider and raidOwnerId ~= nil and raidOwnerId ~= owner.UserId then
					continue
				end

				-- HARD BOUNDED DEFENSE PERIMETER: never engage or chase enemies outside restaurant property!
				local extraMargin = if isMyRaider then 20 else 0
				if not isInsideBaseDefenseBounds(enemyPos, zones, extraMargin) then
					continue
				end

				local localEnemy = zones.BaseCF:PointToObjectSpace(enemyPos)
				local distToRest = horizDist(enemyPos, zones.RestaurantFrontPos)
				local distToMoney = horizDist(enemyPos, zones.MoneyStoragePos)
				local distToWh, nearestWhAnchor = getNearestWarehouseDistance(enemyPos, zones)
				local distToGate = horizDist(enemyPos, zones.GateEntrancePos)
				local distToMe = horizDist(enemyPos, myPos)
				local distToOwner = if ownerPosInBase then horizDist(enemyPos, ownerPosInBase) else math.huge
				local raidObj = inst:GetAttribute("RaidObjective")

				-- Classify hostile into exact Stage 6 priority tiers (1 -> 2 -> 3)
				local tier: number? = nil
				local mode: DefenseMode = "P3_PROTECT_ENTRANCE"
				local anchor = zones.GateEntrancePos

				local isAttackingRestaurant = (distToRest <= aiCfg.RestaurantThreatRadius)
					or (distToOwner <= 20 and distToRest <= aiCfg.RestaurantThreatRadius)
					or (isMyRaider and raidObj == "Restaurant" and localEnemy.Z <= 80)

				local isThreateningStorage = (distToWh <= aiCfg.StorageThreatRadius)
					or (distToMoney <= 38)
					or (isMyRaider and raidObj == "Warehouse" and localEnemy.Z <= 92)

				local isThreateningEntrance = (distToGate <= aiCfg.EntranceThreatRadius)
					or isMyRaider

				if isAttackingRestaurant then
					-- Priority 1: Mafia attacking / breaching the Restaurant!
					tier = 1
					mode = "P1_ATTACK_RESTAURANT"
					anchor = zones.RestaurantFrontPos
				elseif isThreateningStorage then
					-- Priority 2: Threats near Warehouses or Money Storage!
					tier = 2
					mode = "P2_PROTECT_STORAGE"
					anchor = if distToWh <= distToMoney then nearestWhAnchor else zones.MoneyStoragePos
				elseif isThreateningEntrance then
					-- Priority 3: Threats approaching or contesting the Restaurant Entrance!
					tier = 3
					mode = "P3_PROTECT_ENTRANCE"
					anchor = zones.GateEntrancePos
				else
					-- Hostile still inside outer base yard: engage as Entrance/Perimeter defense (P3)
					tier = 3
					mode = "P3_PROTECT_ENTRANCE"
					anchor = contract.AssignedPostPos
				end

				if tier then
					-- Role-aware tie-breaking WITHIN the same priority tier
					local tieScore = distToMe
					if isMyRaider then
						tieScore *= 0.72
					end
					if spec.Id == "Assassin" then
						-- Assassins focus high-HP bosses & warehouse breachers quickly!
						if inst:GetAttribute("IsMafiaBoss") == true or raidObj == "Warehouse" then
							tieScore *= 0.65
						end
					elseif spec.Id == "Bodyguard" then
						-- Bodyguards favor targets closest to the Front Gate entrance
						tieScore = (distToGate * 0.6) + (distToMe * 0.4)
					elseif spec.Id == "EliteBodyguard" then
						-- Elite Bodyguards favor threats closest to Money Storage / Bosses
						tieScore = (math.min(distToMoney, distToRest) * 0.55) + (distToMe * 0.45)
						if inst:GetAttribute("IsMafiaBoss") == true then
							tieScore *= 0.75
						end
					end

					if tier < bestPriority or (tier == bestPriority and tieScore < bestTieScore) then
						bestPriority = tier
						bestTieScore = tieScore
						bestModel = inst
						bestHum = hum
						bestPos = enemyPos
						bestMode = mode
						bestGuardAnchor = anchor
					end
				end
			end
		end
	end

	if bestModel and bestHum and bestPos then
		if bestPriority == 1 then
			return {
				PriorityTier = 1,
				Mode = "P1_ATTACK_RESTAURANT",
				StatusText = "P1 • DEFENDING RESTAURANT",
				StatusColor = STATUS_COLORS.P1,
				TargetModel = bestModel,
				TargetHumanoid = bestHum,
				TargetPos = bestPos,
				GuardAnchorPos = bestGuardAnchor,
			}
		elseif bestPriority == 2 then
			return {
				PriorityTier = 2,
				Mode = "P2_PROTECT_STORAGE",
				StatusText = "P2 • PROTECTING STORAGE",
				StatusColor = STATUS_COLORS.P2,
				TargetModel = bestModel,
				TargetHumanoid = bestHum,
				TargetPos = bestPos,
				GuardAnchorPos = bestGuardAnchor,
			}
		else
			return {
				PriorityTier = 3,
				Mode = "P3_PROTECT_ENTRANCE",
				StatusText = "P3 • HOLDING ENTRANCE",
				StatusColor = STATUS_COLORS.P3,
				TargetModel = bestModel,
				TargetHumanoid = bestHum,
				TargetPos = bestPos,
				GuardAnchorPos = bestGuardAnchor,
			}
		end
	end

	-- Priority 4: Zero threats in bounded defense perimeter -> return smoothly to assigned post!
	local raidSnap = NightMafiaRaidService.GetSnapshot(owner)
	if raidSnap.Phase == "Warning" then
		-- Pre-raid alert: stand ready at assigned post facing the entrance!
		return {
			PriorityTier = 4,
			Mode = "RAID_ALERT",
			StatusText = "RAID ALERT • READY",
			StatusColor = STATUS_COLORS.Alert,
			TargetModel = nil,
			TargetHumanoid = nil,
			TargetPos = nil,
			GuardAnchorPos = contract.AssignedPostPos,
		}
	end

	local distHome = horizDist(myPos, contract.AssignedPostPos)
	if distHome > aiCfg.PostReturnTolerance then
		return {
			PriorityTier = 4,
			Mode = "P4_RETURN_POST",
			StatusText = "P4 • RETURNING TO POST",
			StatusColor = STATUS_COLORS.P4,
			TargetModel = nil,
			TargetHumanoid = nil,
			TargetPos = nil,
			GuardAnchorPos = contract.AssignedPostPos,
		}
	end

	return {
		PriorityTier = 4,
		Mode = "POST_GUARD",
		StatusText = "ON POST",
		StatusColor = STATUS_COLORS.Guard,
		TargetModel = nil,
		TargetHumanoid = nil,
		TargetPos = nil,
		GuardAnchorPos = contract.AssignedPostPos,
	}
end

-- =============================================================================
-- COMPANION HEALTH, RIGGING & LIFECYCLE (STAGE 5 GUARANTEES PRESERVED)
-- =============================================================================
local function computeConfiguredMaxHP(spec: RestaurantSecurityConfig.CompanionSpec): number
	local bal = RestaurantSecurityConfig.CombatBalance
	local scale = if bal and typeof(bal.CompanionHealthScale) == "number" then bal.CompanionHealthScale else 1.0
	local playerDefault = if bal and typeof(bal.PlayerDefaultMaxHealth) == "number" then bal.PlayerDefaultMaxHealth else 100
	-- Separate configurable companion HP, capped strictly below player default HP when scale == 1
	local raw = math.max(20, math.floor(spec.MaxHealth * scale + 0.5))
	if scale <= 1.0 then
		return math.min(raw, math.max(20, playerDefault - 1))
	end
	return raw
end

local function buildCompanionRig(
	modelName: string,
	spec: RestaurantSecurityConfig.CompanionSpec,
	spawnCF: CFrame
): MafiaVisualBuilder.RigHandle
	if spec.VisualKind == "NinjaGuard" then
		return MafiaVisualBuilder.BuildSyndicateSpecialistRig(modelName, "NinjaMafia", spec.Scale, spawnCF, false)
	elseif spec.VisualKind == "ApexAssassin" then
		return MafiaVisualBuilder.BuildSyndicateSpecialistRig(modelName, "ApexAssassin", spec.Scale, spawnCF, false, true)
	elseif spec.VisualKind == "HeavyGuard" then
		return MafiaVisualBuilder.BuildBodyguardRig(modelName, "HeavyGuard", spec.Scale, spawnCF, nil, false)
	else
		return MafiaVisualBuilder.BuildBodyguardRig(modelName, "BasicGuard", spec.Scale, spawnCF, { IsRanged = true }, false)
	end
end

local function destroyContractModel(contract: CompanionContract): ()
	local mdl = contract.Model
	contract.Model = nil
	contract.Humanoid = nil
	contract.Root = nil
	contract.TimerLabel = nil
	contract.HPFill = nil
	contract.HPText = nil
	if mdl and mdl.Parent then
		CollectionService:RemoveTag(mdl, "HiredDefenseCompanion")
		CollectionService:RemoveTag(mdl, "AnimatedRaiderLimbs")
		mdl:Destroy()
	end
end

local function expireContract(contract: CompanionContract, reason: string?): ()
	if contract.State == "Expired" then
		return
	end
	contract.State = "Expired"
	contract.RespawnAt = nil
	contract.SpawnGeneration += 1
	destroyContractModel(contract)

	local owner = contract.Owner
	local map = contractsByPlayer[owner]
	if map and map[contract.CompanionType] == contract then
		map[contract.CompanionType] = nil
	end

	if owner.Parent and reason == "expired" then
		sendToast(owner, string.format("%s contract expired and stood down.", contract.Spec.DisplayName))
	end
	print(
		string.format(
			"[DefenseCompanionService] Contract %s (%s) for %s ended (%s).",
			contract.ContractId,
			contract.Spec.DisplayName,
			owner.Name,
			reason or "expired"
		)
	)
	notifyChanged(owner)
end

local function spawnCompanionModelForContract(contract: CompanionContract): boolean
	-- Strict single-copy & active-contract guard: never spawn if expired or already alive!
	if contract.State == "Expired" then
		return false
	end
	if os.clock() >= contract.ExpiresAt then
		expireContract(contract, "expired")
		return false
	end
	if contract.Model and contract.Model.Parent then
		return false
	end
	if not contract.Owner.Parent then
		return false
	end

	-- Refresh base geometry right before spawning so respawn lands on current post!
	refreshContractZonesIfNeeded(contract, os.clock(), true)

	local spec = contract.Spec
	contract.SpawnGeneration += 1
	local myGen = contract.SpawnGeneration

	-- Clean up any stale stray model with the same ContractId just in case
	if companionFolder then
		for _, ch in ipairs(companionFolder:GetChildren()) do
			if ch:GetAttribute("ContractId") == contract.ContractId then
				ch:Destroy()
			end
		end
	end

	local modelName = string.format("HiredCompanion_%s_%d", spec.Id, contract.Owner.UserId)
	local spawnPos = contract.AssignedPostPos
	local spawnCF = CFrame.lookAt(spawnPos, spawnPos + contract.Zones.ForwardDir)
	local rig = buildCompanionRig(modelName, spec, spawnCF)
	local model = rig.Model
	local root = rig.Root
	local head = rig.Head

	-- Overhead dark-noir Nameplate + Live HP Bar + Tactical AI Status & Remaining Contract Time
	local bb = Instance.new("BillboardGui")
	bb.Name = "CompanionPlate"
	bb.Size = UDim2.fromOffset(206, 54)
	bb.StudsOffset = Vector3.new(0, 3.25 * spec.Scale, 0)
	bb.MaxDistance = 160
	bb.Parent = head

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, 0, 0, 19)
	titleLbl.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
	titleLbl.BackgroundTransparency = 0.08
	titleLbl.Font = Enum.Font.GothamBlack
	titleLbl.Text = spec.ShortTitle
	titleLbl.TextSize = 10
	titleLbl.TextColor3 = spec.AccentColor
	titleLbl.Parent = bb
	Instance.new("UICorner", titleLbl).CornerRadius = UDim.new(0, 4)
	local st = Instance.new("UIStroke")
	st.Color = spec.AccentColor
	st.Thickness = 1.2
	st.Parent = titleLbl

	local hpBg = Instance.new("Frame")
	hpBg.Position = UDim2.new(0.04, 0, 0, 22)
	hpBg.Size = UDim2.new(0.92, 0, 0, 13)
	hpBg.BackgroundColor3 = Color3.fromRGB(12, 14, 19)
	hpBg.Parent = bb
	Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 3)

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(62, 178, 108)
	hpFill.Parent = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

	local hpText = Instance.new("TextLabel")
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.GothamBold
	hpText.Text = string.format("%d / %d HP", contract.ConfiguredMaxHP, contract.ConfiguredMaxHP)
	hpText.TextSize = 9
	hpText.TextColor3 = Color3.fromRGB(242, 240, 236)
	hpText.ZIndex = 3
	hpText.Parent = hpBg

	local timerLbl = Instance.new("TextLabel")
	timerLbl.Position = UDim2.new(0.02, 0, 0, 38)
	timerLbl.Size = UDim2.new(0.96, 0, 0, 14)
	timerLbl.BackgroundTransparency = 1
	timerLbl.Font = Enum.Font.GothamBold
	timerLbl.Text = "ON POST • " .. formatMMSS(contract.ExpiresAt - os.clock())
	timerLbl.TextSize = 9
	timerLbl.TextColor3 = STATUS_COLORS.Guard
	timerLbl.TextTruncate = Enum.TextTruncate.AtEnd
	timerLbl.Parent = bb

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = contract.ConfiguredMaxHP
	hum.Health = contract.ConfiguredMaxHP
	hum.WalkSpeed = spec.WalkSpeed
	hum.HipHeight = 2.25 * spec.Scale
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	-- Apply optional configured damage reduction (higher survivability for Bodyguard / EliteBodyguard, NEVER invincible!)
	local lastRecordedHP = contract.ConfiguredMaxHP
	hum.HealthChanged:Connect(function(newHP: number)
		if spec.DamageReduction > 0 and newHP > 0 and newHP < lastRecordedHP then
			local delta = lastRecordedHP - newHP
			-- Only mitigate moderate combat hits; lethal overkill still kills cleanly
			if delta > 0 and delta < contract.ConfiguredMaxHP then
				local mitigated = delta * (1 - math.clamp(spec.DamageReduction, 0, 0.35))
				local adjusted = math.max(1, lastRecordedHP - mitigated)
				if adjusted > newHP + 0.5 then
					lastRecordedHP = adjusted
					hum.Health = adjusted
					newHP = adjusted
				else
					lastRecordedHP = newHP
				end
			else
				lastRecordedHP = newHP
			end
		else
			lastRecordedHP = newHP
		end

		local cur = math.max(0, math.ceil(newHP))
		local maxH = math.max(1, math.ceil(hum.MaxHealth))
		hpFill.Size = UDim2.fromScale(math.clamp(newHP / maxH, 0, 1), 1)
		hpText.Text = string.format("%d / %d HP", cur, maxH)
	end)

	hum.Died:Connect(function()
		CollectionService:RemoveTag(model, "HiredDefenseCompanion")
		CollectionService:RemoveTag(model, "AnimatedRaiderLimbs")
		MafiaVisualBuilder.PlayDeathSequence(model, false, function(impactPos: Vector3)
			BlackMarketService.BroadcastSFX("BodyDrop", impactPos)
		end)

		-- Guard against stale generation or already-expired/respawning contract
		if contract.SpawnGeneration ~= myGen or contract.State ~= "Active" then
			return
		end

		contract.Model = nil
		contract.Humanoid = nil
		contract.Root = nil
		contract.TimerLabel = nil
		contract.HPFill = nil
		contract.HPText = nil
		contract.PathWaypoints = nil
		contract.CurrentTargetName = nil

		local now = os.clock()
		if now >= contract.ExpiresAt then
			expireContract(contract, "expired")
			return
		end

		local delaySec = getCfg().RespawnDelaySeconds
		contract.State = "Respawning"
		contract.RespawnAt = now + delaySec
		print(
			string.format(
				"[DefenseCompanionService] %s (%s) died for %s — respawning in exact %.0fs (%.0fs contract left).",
				spec.DisplayName,
				contract.ContractId,
				contract.Owner.Name,
				delaySec,
				math.max(0, contract.ExpiresAt - now)
			)
		)
		sendToast(
			contract.Owner,
			string.format("%s was defeated! Respawning in %ds (contract active).", spec.DisplayName, math.floor(delaySec))
		)
		notifyChanged(contract.Owner)
	end)

	model.PrimaryPart = root
	model:SetAttribute("ContractId", contract.ContractId)
	model:SetAttribute("CompanionType", spec.Id)
	model:SetAttribute("OwnerUserId", contract.Owner.UserId)
	model:SetAttribute("BaseSlot", contract.BaseSlot)
	model:SetAttribute("DefenseMode", "POST_GUARD")
	model:SetAttribute("DefensePriority", 4)
	CollectionService:AddTag(model, "HiredDefenseCompanion")
	CollectionService:AddTag(model, "AnimatedRaiderLimbs")
	model.Parent = companionFolder or Workspace

	contract.State = "Active"
	contract.RespawnAt = nil
	contract.Model = model
	contract.Humanoid = hum
	contract.Root = root
	contract.TimerLabel = timerLbl
	contract.HPFill = hpFill
	contract.HPText = hpText
	contract.DefenseMode = "POST_GUARD"
	contract.PriorityTier = 4
	contract.CurrentTargetName = nil
	contract.LastPos = root.Position
	contract.StuckTime = 0
	contract.HardStuckTime = 0
	contract.PathWaypoints = nil
	contract.UsingPathfinding = false
	return true
end

-- =============================================================================
-- MAIN COMPANION AI TICK
-- =============================================================================
local function stepCompanionContract(contract: CompanionContract, now: number, dt: number): ()
	if contract.State == "Expired" then
		return
	end
	if not contract.Owner.Parent then
		expireContract(contract, "owner_left")
		return
	end

	-- 1. Check contract expiration FIRST (if expired while dead/respawning, NEVER respawn!)
	if now >= contract.ExpiresAt then
		expireContract(contract, "expired")
		return
	end

	-- 2. Handle exact 20-second respawn timer if currently dead
	if contract.State == "Respawning" then
		if contract.RespawnAt and now >= contract.RespawnAt then
			if now < contract.ExpiresAt and contract.Model == nil then
				local ok = spawnCompanionModelForContract(contract)
				if ok then
					print(
						string.format(
							"[DefenseCompanionService] %s (%s) RESPAWNED for %s at %d HP (%.0fs remaining).",
							contract.Spec.DisplayName,
							contract.ContractId,
							contract.Owner.Name,
							contract.ConfiguredMaxHP,
							math.max(0, contract.ExpiresAt - now)
						)
					)
					sendToast(
						contract.Owner,
						string.format(
							"%s respawned at full HP and returned to defend your restaurant (%s left)!",
							contract.Spec.DisplayName,
							formatMMSS(contract.ExpiresAt - now)
						)
					)
					notifyChanged(contract.Owner)
				end
			end
		end
		return
	end

	-- 3. Active companion tick
	local mdl = contract.Model
	local hum = contract.Humanoid
	local root = contract.Root
	if not mdl or not mdl.Parent or not hum or not root or not root.Parent then
		if contract.State == "Active" then
			contract.Model = nil
			contract.Humanoid = nil
			contract.Root = nil
			contract.State = "Respawning"
			contract.RespawnAt = now + getCfg().RespawnDelaySeconds
			notifyChanged(contract.Owner)
		end
		return
	end

	if hum.Health <= 0 then
		return
	end

	-- Keep base defense zones synced if HQ expanded or new Warehouse unlocked
	refreshContractZonesIfNeeded(contract, now, false)

	local aiCfg = getAICfg()
	local pos = root.Position
	local spec = contract.Spec

	-- Safety leash: if physics ever knocked companion outside base defense bounds, steer straight back in!
	if not isInsideBaseDefenseBounds(pos, contract.Zones, 4) then
		local clamped = clampToBaseDefenseBounds(pos, contract.Zones)
		contract.DefenseMode = "P4_RETURN_POST"
		contract.PriorityTier = 4
		contract.CurrentTargetName = nil
		mdl:SetAttribute("DefenseMode", contract.DefenseMode)
		mdl:SetAttribute("DefensePriority", 4)
		moveCompanionSmart(contract, clamped, now, dt)
		if contract.TimerLabel and contract.TimerLabel.Parent then
			contract.TimerLabel.Text = "REFORMING PERIMETER • " .. formatMMSS(contract.ExpiresAt - now)
			contract.TimerLabel.TextColor3 = STATUS_COLORS.P4
		end
		return
	end

	local directive = evaluateDefenseDirective(contract, pos)
	contract.DefenseMode = directive.Mode
	contract.PriorityTier = directive.PriorityTier
	contract.CurrentTargetName = if directive.TargetModel then directive.TargetModel.Name else nil
	mdl:SetAttribute("DefenseMode", directive.Mode)
	mdl:SetAttribute("DefensePriority", directive.PriorityTier)

	if contract.TimerLabel and contract.TimerLabel.Parent then
		contract.TimerLabel.Text = directive.StatusText .. " • " .. formatMMSS(contract.ExpiresAt - now)
		contract.TimerLabel.TextColor3 = directive.StatusColor
	end

	if directive.TargetModel and directive.TargetHumanoid and directive.TargetPos then
		local targetPos = directive.TargetPos
		local dist = (targetPos - pos).Magnitude
		local canFireRanged = true
		if spec.CombatStyle == "Ranged" and aiCfg.RangedLOSRequired then
			canFireRanged = hasClearRangedLOS(pos, targetPos, directive.TargetModel)
		end

		-- Combat engagement
		if dist <= spec.AttackRange and (now - contract.LastAttackAt) >= spec.AttackCooldown then
			if spec.CombatStyle == "Melee" then
				contract.LastAttackAt = now
				contract.AttacksLanded += 1
				faceHorizontalDir(root, targetPos - pos)
				MafiaVisualBuilder.TriggerAttackAnim(mdl)
				directive.TargetHumanoid:TakeDamage(spec.Damage)
				BlackMarketService.BroadcastSFX("MeleeHit", targetPos)
			elseif canFireRanged then
				contract.LastAttackAt = now
				contract.AttacksLanded += 1
				faceHorizontalDir(root, targetPos - pos)
				MafiaVisualBuilder.TriggerAttackAnim(mdl)
				local fromPos = pos + Vector3.new(0, 1.5, 0)
				BlackMarketService.SpawnBulletTracer(fromPos, targetPos + Vector3.new(0, 1.2, 0), spec.AccentColor)
				BlackMarketService.BroadcastSFX(if spec.Id == "EliteBodyguard" then "RifleShot" else "PistolShot", fromPos)
				directive.TargetHumanoid:TakeDamage(spec.Damage)
				BlackMarketService.BroadcastSFX("MeleeHit", targetPos)
			end
		end

		-- Role-appropriate tactical positioning (strictly inside base defense bounds!)
		local desiredDest: Vector3
		if spec.CombatStyle == "Melee" then
			-- Shadow Ninja & Crimson Assassin rush swiftly to intercept raiders within perimeter
			desiredDest = targetPos
		else
			-- Bodyguard & Elite Bodyguard hold defensive ground near the guarded zone anchor
			-- while closing around walls/obstacles if target is out of range or LOS is blocked!
			local preferredRange = spec.AttackRange * aiCfg.RangedPreferredHoldRatio
			if not canFireRanged or dist > preferredRange then
				desiredDest = targetPos
			else
				-- Stay anchored near the prioritized defense point (Entrance / Money Storage / Warehouse)
				local anchorDistToTarget = horizDist(directive.GuardAnchorPos, targetPos)
				if anchorDistToTarget <= spec.AttackRange * 0.92 then
					desiredDest = directive.GuardAnchorPos
				else
					-- Hold firing stance cleanly without rushing blindly into melee!
					desiredDest = pos
					faceHorizontalDir(root, targetPos - pos)
				end
			end
		end

		moveCompanionSmart(contract, desiredDest, now, dt)
	else
		-- Priority 4: Return cleanly to assigned defensive post & face outward toward front gate
		local distHome = horizDist(pos, contract.AssignedPostPos)
		if distHome > aiCfg.PostReturnTolerance then
			moveCompanionSmart(contract, contract.AssignedPostPos, now, dt)
		else
			contract.PathWaypoints = nil
			contract.UsingPathfinding = false
			contract.StuckTime = 0
			contract.HardStuckTime = 0
			-- Smoothly face outward toward approaching threats at the entrance
			faceHorizontalDir(root, contract.Zones.ForwardDir)
		end
	end
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================
function DefenseCompanionService.SetChangedCallback(cb: (player: Player) -> ()): ()
	onChangedCb = cb
end

function DefenseCompanionService.GetCost(companionType: CompanionTypeId, durationMinutes: number): number?
	local spec = getCfg().Types[companionType]
	if not spec then
		return nil
	end
	if durationMinutes == 5 then
		return spec.Cost5Min
	elseif durationMinutes == 10 then
		return spec.Cost10Min
	end
	return nil
end

function DefenseCompanionService.CanHireCompanion(
	player: Player,
	companionType: string,
	durationMinutes: number
): (boolean, string)
	local cfg = getCfg()
	if not cfg.Enabled then
		return false, "Companion hiring is currently disabled."
	end
	local spec = cfg.Types[companionType :: CompanionTypeId]
	if not spec then
		return false, "Unknown companion type!"
	end
	if durationMinutes ~= 5 and durationMinutes ~= 10 then
		return false, "Choose a 5-minute or 10-minute hiring contract!"
	end
	local slot = BaseService.GetPlayerBaseSlot(player)
	local baseModel = if slot then BaseService.GetBaseModel(slot) else nil
	if not slot or not baseModel then
		return false, "Claim your Restaurant Base before hiring defense companions!"
	end
	local map = contractsByPlayer[player]
	if map then
		local existing = map[spec.Id]
		if existing and existing.State ~= "Expired" then
			local rem = math.max(0, math.ceil(existing.ExpiresAt - os.clock()))
			return false, string.format("%s is already hired (%s remaining)!", spec.DisplayName, formatMMSS(rem))
		end
		local activeCount = 0
		for _, c in pairs(map) do
			if c.State ~= "Expired" then
				activeCount += 1
			end
		end
		if activeCount >= cfg.MaxActiveContractsPerPlayer then
			return false, string.format("Max %d hired defense companions active!", cfg.MaxActiveContractsPerPlayer)
		end
	end
	return true, "OK"
end

function DefenseCompanionService.TryHireCompanion(
	player: Player,
	companionType: string,
	durationMinutes: number,
	bypassGold: boolean?
): (boolean, string)
	local cfg = getCfg()
	if not cfg.Enabled then
		return false, "Companion hiring is currently disabled."
	end
	local spec = cfg.Types[companionType :: CompanionTypeId]
	if not spec then
		return false, "Unknown companion type!"
	end
	if durationMinutes ~= 5 and durationMinutes ~= 10 then
		return false, "Choose a 5-minute or 10-minute hiring contract!"
	end

	local slot = BaseService.GetPlayerBaseSlot(player)
	local baseModel = if slot then BaseService.GetBaseModel(slot) else nil
	if not slot or not baseModel then
		return false, "Claim your Restaurant Base before hiring defense companions!"
	end

	local map = contractsByPlayer[player]
	if not map then
		map = {}
		contractsByPlayer[player] = map
	end

	local existing = map[spec.Id]
	if existing and existing.State ~= "Expired" then
		local rem = math.max(0, math.ceil(existing.ExpiresAt - os.clock()))
		return false, string.format("%s is already hired (%s remaining)!", spec.DisplayName, formatMMSS(rem))
	end

	local activeCount = 0
	for _, c in pairs(map) do
		if c.State ~= "Expired" then
			activeCount += 1
		end
	end
	if activeCount >= cfg.MaxActiveContractsPerPlayer then
		return false, string.format("Max %d hired defense companions active!", cfg.MaxActiveContractsPerPlayer)
	end

	local cost = if durationMinutes == 10 then spec.Cost10Min else spec.Cost5Min
	if not bypassGold then
		if not PlayerDataService.SpendCoins(player, cost) then
			return false, string.format("Need %d Gold to hire %s for %d min!", cost, spec.DisplayName, durationMinutes)
		end
	end

	local zones = computeBaseDefenseZones(baseModel, slot, player)
	local postPos = computeAssignedPostFromZones(zones, spec.AssignedPost)
	local durationSec = durationMinutes * 60
	local now = os.clock()
	contractSerial += 1

	local contract: CompanionContract = {
		ContractId = string.format("COMP_%d_%d", player.UserId, contractSerial),
		Owner = player,
		BaseSlot = slot,
		CompanionType = spec.Id,
		Spec = spec,
		ConfiguredMaxHP = computeConfiguredMaxHP(spec),
		DurationSeconds = durationSec,
		DeployedAt = now,
		ExpiresAt = now + durationSec,
		State = "Active",
		RespawnAt = nil,
		SpawnGeneration = 0,
		Zones = zones,
		AssignedPostPos = postPos,
		BaseCenterPos = zones.BaseCenterPos,
		Model = nil,
		Humanoid = nil,
		Root = nil,
		TimerLabel = nil,
		HPFill = nil,
		HPText = nil,
		DefenseMode = "POST_GUARD",
		PriorityTier = 4,
		CurrentTargetName = nil,
		LastAttackAt = 0,
		AttacksLanded = 0,
		LastPos = postPos,
		StuckTime = 0,
		HardStuckTime = 0,
		StuckRecoveries = 0,
		SideStepSign = 1,
		UsingPathfinding = false,
		PathWaypoints = nil,
		PathIndex = 1,
		LastPathAt = 0,
		LastPathGoal = postPos,
	}

	map[spec.Id] = contract
	local deployed = spawnCompanionModelForContract(contract)
	if not deployed then
		map[spec.Id] = nil
		if not bypassGold then
			PlayerDataService.AddCoins(player, cost)
		end
		return false, "Failed to deploy companion — Gold refunded!"
	end

	local deployTime = os.clock()
	contract.DeployedAt = deployTime
	contract.ExpiresAt = deployTime + durationSec

	print(
		string.format(
			"[DefenseCompanionService] %s hired %s (%d HP, %d DMG) for %d min (%dG) at %s Base!",
			player.Name,
			spec.DisplayName,
			contract.ConfiguredMaxHP,
			spec.Damage,
			durationMinutes,
			cost,
			slot
		)
	)
	notifyChanged(player)
	return true, string.format(
		"Deployed %s (%d HP) for %d minutes to protect your %s Restaurant!",
		spec.DisplayName,
		contract.ConfiguredMaxHP,
		durationMinutes,
		slot
	)
end

function DefenseCompanionService.GetSnapshot(player: Player): PlayerCompanionsSnapshot
	local cfg = getCfg()
	local now = os.clock()
	local map = contractsByPlayer[player] or {}
	local outMap: { [CompanionTypeId]: CompanionContractSnapshot } = {}
	local outList: { CompanionContractSnapshot } = {}

	for _, cType in ipairs(cfg.TypeOrder) do
		local c = map[cType]
		if c and c.State ~= "Expired" then
			local rem = math.max(0, math.ceil(c.ExpiresAt - now))
			local respRem = if c.State == "Respawning" and c.RespawnAt
				then math.max(0, math.ceil(c.RespawnAt - now))
				else 0
			local curHP = if c.Humanoid and c.Humanoid.Parent then math.max(0, math.ceil(c.Humanoid.Health)) else 0
			local entry: CompanionContractSnapshot = {
				ContractId = c.ContractId,
				CompanionType = c.CompanionType,
				DisplayName = c.Spec.DisplayName,
				ShortTitle = c.Spec.ShortTitle,
				RoleTag = c.Spec.RoleTag,
				State = c.State,
				DefenseMode = c.DefenseMode,
				PriorityTier = c.PriorityTier,
				DurationSeconds = c.DurationSeconds,
				TimeRemaining = rem,
				RespawnRemaining = respRem,
				CurrentHP = curHP,
				MaxHP = c.ConfiguredMaxHP,
			}
			outMap[cType] = entry
			table.insert(outList, entry)
		end
	end

	return {
		ActiveCount = #outList,
		MaxActive = cfg.MaxActiveContractsPerPlayer,
		RespawnDelaySeconds = cfg.RespawnDelaySeconds,
		Contracts = outMap,
		List = outList,
	}
end

function DefenseCompanionService.GetActiveModelsForPlayer(player: Player): { Model }
	local out: { Model } = {}
	local map = contractsByPlayer[player]
	if not map then
		return out
	end
	for _, c in pairs(map) do
		if c.State == "Active" and c.Model and c.Model.Parent and c.Humanoid and c.Humanoid.Health > 0 then
			table.insert(out, c.Model)
		end
	end
	return out
end

-- =============================================================================
-- STUDIO-ONLY VERIFICATION BRIDGE (Stage 5 & Stage 6 Automated Live Tests)
-- =============================================================================
local function spawnStudioTestHostile(name: string, pos: Vector3, hp: number, raidOwnerId: number?, raidObj: string?): Model
	if not testDummyFolder or not testDummyFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "Stage6TestHostiles"
		f.Parent = Workspace
		testDummyFolder = f
	end
	local rig = MafiaVisualBuilder.BuildRivalRig(name, "HarborHookCartel", true, 1.0, CFrame.new(pos), false)
	local mdl = rig.Model
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = hp
	hum.Health = hp
	hum.WalkSpeed = 0
	hum.HipHeight = 2.25
	hum.Parent = mdl
	mdl.PrimaryPart = rig.Root
	if raidOwnerId then
		mdl:SetAttribute("RaidOwnerUserId", raidOwnerId)
		CollectionService:AddTag(mdl, "NightRaidMafiaUnit")
	end
	if raidObj then
		mdl:SetAttribute("RaidObjective", raidObj)
	end
	CollectionService:AddTag(mdl, "MafiaUnit")
	hum.Died:Connect(function()
		CollectionService:RemoveTag(mdl, "NightRaidMafiaUnit")
		CollectionService:RemoveTag(mdl, "MafiaUnit")
		task.delay(0.3, function()
			if mdl and mdl.Parent then
				mdl:Destroy()
			end
		end)
	end)
	mdl.Parent = testDummyFolder
	return mdl
end

local function setupStudioTestBridge(): ()
	if not RunService:IsStudio() then
		return
	end
	local existing = ServerStorage:FindFirstChild("CompanionTestBridge")
	if existing then
		existing:Destroy()
	end
	local bf = Instance.new("BindableFunction")
	bf.Name = "CompanionTestBridge"
	bf.OnInvoke = function(action: string, arg1: any, arg2: any, arg3: any, arg4: any): any
		local plr = if typeof(arg1) == "Instance" and arg1:IsA("Player")
			then arg1
			else Players:GetPlayers()[1]
		if not plr then
			return nil
		end

		if action == "GetSnapshot" then
			return DefenseCompanionService.GetSnapshot(plr)
		elseif action == "Hire" then
			local ok, msg = DefenseCompanionService.TryHireCompanion(plr, tostring(arg2), tonumber(arg3) or 5, false)
			return { Ok = ok, Message = msg, Snapshot = DefenseCompanionService.GetSnapshot(plr) }
		elseif action == "KillCompanion" then
			local map = contractsByPlayer[plr]
			local c = if map then map[arg2] else nil
			if not c or not c.Humanoid then
				return { Ok = false, Message = "No live companion" }
			end
			c.Humanoid.Health = 0
			task.wait(0.25)
			return { Ok = true, Snapshot = DefenseCompanionService.GetSnapshot(plr) }
		elseif action == "DamageCompanion" then
			local map = contractsByPlayer[plr]
			local c = if map then map[arg2] else nil
			if not c or not c.Humanoid then
				return { Ok = false }
			end
			local beforeHP = c.Humanoid.Health
			c.Humanoid:TakeDamage(tonumber(arg3) or 20)
			task.wait(0.05)
			return { Ok = true, BeforeHP = beforeHP, AfterHP = c.Humanoid.Health }
		elseif action == "SetRemainingSeconds" then
			local map = contractsByPlayer[plr]
			local c = if map then map[arg2] else nil
			if not c then
				return false
			end
			c.ExpiresAt = os.clock() + (tonumber(arg3) or 1)
			return true
		elseif action == "SetRespawnRemainingSeconds" then
			local map = contractsByPlayer[plr]
			local c = if map then map[arg2] else nil
			if not c or c.State ~= "Respawning" then
				return false
			end
			c.RespawnAt = os.clock() + (tonumber(arg3) or 0.5)
			return true
		elseif action == "GetDefenseZones" then
			local slot = BaseService.GetPlayerBaseSlot(plr)
			local bm = if slot then BaseService.GetBaseModel(slot) else nil
			if not slot or not bm then
				return nil
			end
			local z = computeBaseDefenseZones(bm, slot, plr)
			return {
				BaseSlot = slot,
				BaseCenterPos = z.BaseCenterPos,
				ForwardDir = z.ForwardDir,
				GateEntrancePos = z.GateEntrancePos,
				RestaurantFrontPos = z.RestaurantFrontPos,
				MoneyStoragePos = z.MoneyStoragePos,
				PrimaryWarehousePos = z.PrimaryWarehousePos,
				WarehouseAnchorCount = #z.WarehouseAnchors,
			}
		elseif action == "GetAIState" then
			local map = contractsByPlayer[plr] or {}
			local out: { [string]: any } = {}
			for cType, c in pairs(map) do
				local p = if c.Root and c.Root.Parent then c.Root.Position else nil
				out[cType] = {
					State = c.State,
					Mode = c.DefenseMode,
					PriorityTier = c.PriorityTier,
					TargetName = c.CurrentTargetName,
					Pos = p,
					AssignedPost = c.AssignedPostPos,
					DistFromPost = if p then horizDist(p, c.AssignedPostPos) else -1,
					DistFromBaseCenter = if p then horizDist(p, c.Zones.BaseCenterPos) else -1,
					InsideBounds = if p then isInsideBaseDefenseBounds(p, c.Zones, 0) else false,
					UsingPathfinding = c.UsingPathfinding,
					StuckRecoveries = c.StuckRecoveries,
					AttacksLanded = c.AttacksLanded,
					HP = if c.Humanoid and c.Humanoid.Parent then c.Humanoid.Health else 0,
					MaxHP = c.ConfiguredMaxHP,
				}
			end
			return out
		elseif action == "SpawnTestHostile" then
			-- arg2 = { Name, Pos, HP, IsRaid, Objective }
			if typeof(arg2) ~= "table" or typeof(arg2.Pos) ~= "Vector3" then
				return false
			end
			local mdl = spawnStudioTestHostile(
				tostring(arg2.Name or "TestHostile"),
				arg2.Pos,
				tonumber(arg2.HP) or 250,
				if arg2.IsRaid then plr.UserId else nil,
				if typeof(arg2.Objective) == "string" then arg2.Objective else nil
			)
			return mdl.Name
		elseif action == "ClearTestHostiles" then
			if testDummyFolder then
				testDummyFolder:ClearAllChildren()
			end
			return true
		elseif action == "TeleportCompanion" then
			local map = contractsByPlayer[plr]
			local c = if map then map[arg2] else nil
			if c and c.Root and typeof(arg3) == "Vector3" then
				c.Root.CFrame = CFrame.new(arg3)
				c.LastPos = arg3
				c.PathWaypoints = nil
				return true
			end
			return false
		elseif action == "ClearAll" then
			local map = contractsByPlayer[plr]
			if map then
				local copy = {}
				for _, c in pairs(map) do
					table.insert(copy, c)
				end
				for _, c in ipairs(copy) do
					expireContract(c, "test_clear")
				end
			end
			if testDummyFolder then
				testDummyFolder:ClearAllChildren()
			end
			return true
		elseif action == "CountWorkspaceModels" then
			local n = 0
			if companionFolder then
				for _, ch in ipairs(companionFolder:GetChildren()) do
					if ch:IsA("Model") and ch:GetAttribute("OwnerUserId") == plr.UserId then
						if arg2 == nil or ch:GetAttribute("CompanionType") == arg2 then
							n += 1
						end
					end
				end
			end
			return n
		end
		return nil
	end
	bf.Parent = ServerStorage
	testBridge = bf
end

function DefenseCompanionService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local existing = Workspace:FindFirstChild("HiredDefenseCompanions")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		companionFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "HiredDefenseCompanions"
		f.Parent = Workspace
		companionFolder = f
	end

	-- React immediately when a Night Raid warning fires (8s pre-warning): refresh defense zones & ready posts!
	if not raidWarningHooked then
		raidWarningHooked = true
		NightMafiaRaidService.OnRaidWarning(function(payload)
			local map = contractsByPlayer[payload.Owner]
			if not map then
				return
			end
			local now = os.clock()
			for _, c in pairs(map) do
				if c.State == "Active" then
					refreshContractZonesIfNeeded(c, now, true)
				end
			end
		end)
	end

	playerRemovingConn = Players.PlayerRemoving:Connect(function(plr)
		local map = contractsByPlayer[plr]
		if map then
			local copy = {}
			for _, c in pairs(map) do
				table.insert(copy, c)
			end
			for _, c in ipairs(copy) do
				expireContract(c, "player_left")
			end
			contractsByPlayer[plr] = nil
		end
	end)

	setupStudioTestBridge()

	aiThread = task.spawn(function()
		local last = os.clock()
		while isRunning do
			task.wait(getAICfg().TickInterval)
			if not isRunning then
				break
			end
			local now = os.clock()
			local dt = math.clamp(now - last, 0.05, 1.5)
			last = now

			for _, map in pairs(contractsByPlayer) do
				local snapshotList: { CompanionContract } = {}
				for _, c in pairs(map) do
					table.insert(snapshotList, c)
				end
				for _, c in ipairs(snapshotList) do
					stepCompanionContract(c, now, dt)
				end
			end
		end
	end)

	print("[Food Empire] DefenseCompanionService started (Stage 5 Contracts + Stage 6 4-Tier Restaurant Defense AI active)!")
end

function DefenseCompanionService.Stop(): ()
	isRunning = false
	if aiThread then
		task.cancel(aiThread)
		aiThread = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	if testBridge then
		testBridge:Destroy()
		testBridge = nil
	end
	for plr, map in pairs(contractsByPlayer) do
		local copy = {}
		for _, c in pairs(map) do
			table.insert(copy, c)
		end
		for _, c in ipairs(copy) do
			expireContract(c, "service_stop")
		end
		contractsByPlayer[plr] = nil
	end
	if companionFolder then
		companionFolder:ClearAllChildren()
	end
	if testDummyFolder then
		testDummyFolder:Destroy()
		testDummyFolder = nil
	end
end

return DefenseCompanionService
