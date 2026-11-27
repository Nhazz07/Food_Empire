--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)
local TurfConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("TurfConfig")
)
local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local MinimapMapData = require("./MinimapMapData")
local WaypointController = require("./WaypointController")
local AudioController = require("./AudioController")

export type MinimapSizePreset = "Compact" | "Standard" | "Large"

export type MinimapSizeState = {
	Preset: MinimapSizePreset,
	ViewportSize: number,
	FrameWidth: number,
	FrameHeight: number,
	MinViewport: number,
	MaxViewport: number,
	IsCustom: boolean,
}

local MinimapController = {}

-- World coordinate projection (1:1 accurate to FoodEmpireMap [-1020, +1020] inside [-1060, +1060])
local MAP_HALF_WORLD = MinimapMapData.MAP_HALF_WORLD
local WORLD_SPAN = MAP_HALF_WORLD * 2
local ISLAND_LIMIT = MinimapMapData.ISLAND_HALF - 12

-- Dynamic resizable minimap presets & hard bounds (Standard = exact 200x236 original geometry)
local BASE_VIEWPORT_SIZE = 186
local MIN_VIEWPORT_SIZE = 132
local MAX_VIEWPORT_SIZE = 344
local PRESET_SNAP_THRESHOLD = 9

local PRESET_ORDER: { MinimapSizePreset } = { "Compact", "Standard", "Large" }
local PRESET_VIEWPORT_SIZES: { [MinimapSizePreset]: number } = {
	Compact = 144,
	Standard = 186,
	Large = 284,
}
local PRESET_BADGES: { [MinimapSizePreset]: string } = {
	Compact = "S",
	Standard = "M",
	Large = "L",
}
local PRESET_DISPLAY_NAMES: { [MinimapSizePreset]: string } = {
	Compact = "COMPACT",
	Standard = "STANDARD",
	Large = "LARGE",
}

-- Smooth zoom bounds
local MIN_ZOOM = 1.0
local MAX_ZOOM = 3.5
local ZOOM_STEP = 0.45

-- Tactical Dark Military Palette (consistent with Food Empire Noir Syndicate UI)
local C_FRAME_BG = Color3.fromRGB(15, 18, 25)
local C_STATUS_BG = Color3.fromRGB(11, 13, 18)
local C_GOLD = Color3.fromRGB(212, 178, 102)
local C_GOLD_DIM = Color3.fromRGB(122, 102, 58)
local C_TEXT_MUTED = Color3.fromRGB(158, 165, 180)
local C_OCEAN = Color3.fromRGB(13, 24, 32)
local C_ISLAND = Color3.fromRGB(27, 42, 32)
local C_ISLAND_EDGE = Color3.fromRGB(40, 62, 48)
local C_PARK_ZONE = Color3.fromRGB(18, 35, 24)
local C_PARK_LAWN = Color3.fromRGB(24, 54, 34)
local C_DISTRICT_PAD = Color3.fromRGB(34, 40, 50)
local C_WALKWAY = Color3.fromRGB(48, 56, 68)
local C_FOUNTAIN_WATER = Color3.fromRGB(42, 92, 118)
local C_ALLEY = Color3.fromRGB(38, 45, 56)
local C_ROAD_SECONDARY = Color3.fromRGB(59, 69, 86)
local C_ROAD_PRIMARY = Color3.fromRGB(93, 106, 126)
local C_ROUNDABOUT_CORE = Color3.fromRGB(28, 36, 44)
local C_BUILDING = Color3.fromRGB(50, 59, 75)
local C_BUILDING_MAJOR = Color3.fromRGB(70, 82, 102)
local C_PLAZA_PAD = Color3.fromRGB(42, 49, 59)
local C_CYAN = Color3.fromRGB(52, 230, 255)
local C_ALLY_PLAYER = Color3.fromRGB(44, 232, 168)
local C_ALLY_SQUAD = Color3.fromRGB(92, 184, 255)
local C_ENEMY = Color3.fromRGB(242, 62, 78)
local C_ENEMY_HIGH = Color3.fromRGB(255, 186, 52)
local C_OBJECTIVE = Color3.fromRGB(255, 206, 64)

local HOSTILE_UNIT_TAGS = {
	"RivalAIUnit",
	"MafiaUnit",
	"ApexMafiaUnit",
	"RivalSamuraiUnit",
	"PenthouseBossUnit",
	"TurfGuardUnit",
}

local ALLY_UNIT_TAGS = {
	"PlayerBodyguardUnit",
	"MercenaryMafiaUnit",
	"PlayerDeliveryRunner",
}

-- Threat ping records from existing CombatSFX / AudioController threat bus
type ThreatPulse = {
	Pos: Vector3,
	ExpiresAt: number,
}

type DynamicDot = {
	Frame: Frame,
	Stroke: UIStroke,
	Corner: UICorner?,
	U: number,
	V: number,
	BaseSize: number,
	BaseStroke: number,
	Active: boolean,
}

type PingRing = {
	Frame: Frame,
	Stroke: UIStroke,
	Pos: Vector3,
	StartedAt: number,
	Duration: number,
}

type ChromeMetrics = {
	ViewportPx: number,
	ScaleRatio: number,
	MarkerScale: number,
	Pad: number,
	HeaderH: number,
	StatusH: number,
	GapMid: number,
	GapBot: number,
	FrameW: number,
	FrameH: number,
	CornerR: number,
	ViewportCornerR: number,
	ScaleBarPx: number,
}

type ResponsiveBounds = {
	MinViewport: number,
	MaxViewport: number,
	RightMargin: number,
	BottomMargin: number,
	LogicalW: number,
	LogicalH: number,
	ElevatedAboveDock: boolean,
}

type ScaledMarkerEntry = {
	Gui: GuiObject,
	Corner: UICorner?,
	Stroke: UIStroke?,
	BaseW: number,
	BaseH: number,
	BaseTextSize: number?,
	BaseCorner: number?,
	BaseStroke: number,
	IsRound: boolean?,
}

type DetailSubLabel = {
	Label: TextLabel,
	Stroke: UIStroke?,
	AnchorParent: GuiObject,
	Above: boolean,
	BaseTextSize: number,
	MinEffectivePx: number,
	FullEffectivePx: number,
	TargetTransparency: number,
}

type PlayerIndicatorRefs = {
	Holder: Frame,
	Halo: Frame,
	HaloCorner: UICorner,
	Glyph: TextLabel,
	GlyphStroke: UIStroke,
	Nose: Frame,
	NoseCorner: UICorner,
}

-- Controller runtime UI references
local hostScreenGui: ScreenGui? = nil
local islandFrame: Frame? = nil
local islandFrameCorner: UICorner? = nil
local islandFrameStroke: UIStroke? = nil
local headerFrame: Frame? = nil
local titleLabel: TextLabel? = nil
local headerControlsRow: Frame? = nil
local headerControlsLayout: UIListLayout? = nil
local zoomOutBtn: TextButton? = nil
local zoomInBtn: TextButton? = nil
local zoomReadoutBtn: TextButton? = nil
local followBtn: TextButton? = nil
local sizeToggleBtn: TextButton? = nil
local sizeToggleStroke: UIStroke? = nil
local resizeGripBtn: TextButton? = nil
local resizeGripBars: { Frame } = {}

local mapViewport: Frame? = nil
local mapViewportCorner: UICorner? = nil
local geoClipCorner: UICorner? = nil
local geoWorld: Frame? = nil
local overlayWorld: Frame? = nil
local playerIndicator: Frame? = nil
local playerRefs: PlayerIndicatorRefs? = nil
local gpsPinBtn: TextButton? = nil
local gpsPinCorner: UICorner? = nil
local gpsPinStroke: UIStroke? = nil
local gpsPinCore: Frame? = nil
local gpsPinCoreCorner: UICorner? = nil
local gpsPinPulse: Frame? = nil
local gpsPinPulseCorner: UICorner? = nil
local routeLine: Frame? = nil
local edgeArrowFrame: Frame? = nil
local edgeArrowIcon: TextLabel? = nil
local edgeArrowStroke: UIStroke? = nil
local edgeDistLabel: TextLabel? = nil
local statusBarFrame: Frame? = nil
local statusBarCorner: UICorner? = nil
local gpsStatusLabel: TextLabel? = nil
local gpsDistLabel: TextLabel? = nil
local zoneReadoutLabel: TextLabel? = nil
local clearPinBtn: TextButton? = nil
local scaleBarFrame: Frame? = nil
local scaleLineFrame: Frame? = nil
local scaleBarLabel: TextLabel? = nil
local hoverTipLabel: TextLabel? = nil
local hoverTipConstraint: UISizeConstraint? = nil
local resizeToastLabel: TextLabel? = nil
local cardinalTicks: { TextLabel } = {}
local intercardinalTicks: { TextLabel } = {}
local nwIntercardinalTick: TextLabel? = nil
local bezelTicks: { Frame } = {}

-- Landmark & dynamic marker references
local bmMarkerBtn: TextButton? = nil
local bmFootprintFrame: Frame? = nil
local bmWorldX = MinimapMapData.BlackMarketDefault.x
local bmWorldZ = MinimapMapData.BlackMarketDefault.z
local baseMarkers: { [string]: TextButton } = {}
local baseStrokes: { [string]: UIStroke } = {}
local baseStrokeBases: { [string]: number } = {}
local baseSpawnMarkers: { [string]: TextButton } = {}
local baseSpawnStrokes: { [string]: UIStroke } = {}
local baseSpawnStrokeBases: { [string]: number } = {}
local turfMarkers: { [string]: TextButton } = {}
local turfStrokes: { [string]: UIStroke } = {}
local turfStrokeBases: { [string]: number } = {}
local shipmentBayMarkers: { [string]: TextButton } = {}
local shipmentBayEntries: { [string]: ScaledMarkerEntry } = {}
local expressObjMarker: TextButton? = nil
local expressObjPos: Vector3? = nil
local bistroMarker: TextButton? = nil
local bistroStroke: UIStroke? = nil
local bistroStrokeBase = 1.3
local penthouseMarker: TextButton? = nil
local penthouseStroke: UIStroke? = nil
local penthouseStrokeBase = 1.3
local crateWarehouseMarker: TextButton? = nil
local crateWarehousePos: Vector3? = nil

local scaledMarkers: { ScaledMarkerEntry } = {}
local detailSubLabels: { DetailSubLabel } = {}

-- Pooled entity indicators (zero Instance churn during gameplay)
local allyPool: { DynamicDot } = {}
local enemyPool: { DynamicDot } = {}
local pingRings: { PingRing } = {}

-- Live resizing & responsive layout state
local activePreset: MinimapSizePreset = "Standard"
local isCustomSize = false
local preferredViewportSize = BASE_VIEWPORT_SIZE
local currentViewportSize = BASE_VIEWPORT_SIZE
local targetViewportSize = BASE_VIEWPORT_SIZE
local currentMarkerScale = 1.0
local currentScaleBarPx = 28
local currentRightMargin = 14
local targetRightMargin = 14
local currentBottomMargin = 14
local targetBottomMargin = 14
local cachedBounds: ResponsiveBounds = {
	MinViewport = MIN_VIEWPORT_SIZE,
	MaxViewport = MAX_VIEWPORT_SIZE,
	RightMargin = 14,
	BottomMargin = 14,
	LogicalW = 1360,
	LogicalH = 702,
	ElevatedAboveDock = false,
}
local lastAppliedViewportSize = -1
local lastAppliedMarginX = -1
local lastAppliedMarginY = -1
local lastPublishedFrameW = -1
local lastPublishedFrameH = -1
local lastPublishedBottom = -1
local lastPublishedRight = -1
local resizePulse = 0
local resizeToastExpiresAt = 0
local isHoveringResizeGrip = false

-- Corner drag-resize tracking
local isResizing = false
local didDragResize = false
local resizeStartScreen = Vector2.zero
local resizeStartVp = BASE_VIEWPORT_SIZE
local lastGripTapAt = 0

-- Live navigation, zoom, and detection state
local currentZoom = 1.0
local targetZoom = 1.0
local viewCenterU = 0.5
local viewCenterV = 0.5
local targetCenterU = 0.5
local targetCenterV = 0.5
local followPlayer = true
local lastAppliedZoom = -1
local lastAppliedU = -1
local lastAppliedV = -1
local lastDetailEffectivePx = -1

local activeWaypointPos: Vector3? = nil
local activeWaypointLabel: string? = nil
local lastRenderedDist = -1
local lastRenderedBearing = ""
local lastRenderedZone = ""

local localBaseSlot: string? = nil
local recentThreats: { ThreatPulse } = {}
local revealedEnemyUntil: { [Instance]: number } = {}
local underAttackBlocks: { [string]: boolean } = {}
local lastLiveSyncAt = 0
local lastRadarScanAt = 0
local lastPlayerWorldPos: Vector3? = nil

-- Drag/Pan tracking
local isPointerDown = false
local didDragPan = false
local dragStartScreen = Vector2.zero
local dragStartCenterU = 0.5
local dragStartCenterV = 0.5

-- Active connections for clean re-init
local connections: { RBXScriptConnection } = {}
local threatBusBound = false

-- ============================================================================
-- COORDINATE & GEOMETRY HELPERS
-- ============================================================================

local function worldToUV(x: number, z: number): (number, number)
	local u = (x + MAP_HALF_WORLD) / WORLD_SPAN
	local v = (z + MAP_HALF_WORLD) / WORLD_SPAN
	return u, v
end

local function worldToScale(x: number, z: number): UDim2
	local u, v = worldToUV(x, z)
	return UDim2.fromScale(u, v)
end

local function uvToWorld(u: number, v: number): (number, number)
	local x = math.clamp(u * WORLD_SPAN - MAP_HALF_WORLD, -ISLAND_LIMIT, ISLAND_LIMIT)
	local z = math.clamp(v * WORLD_SPAN - MAP_HALF_WORLD, -ISLAND_LIMIT, ISLAND_LIMIT)
	return x, z
end

local function uvToViewport(u: number, v: number): (number, number)
	local vx = 0.5 + (u - viewCenterU) * currentZoom
	local vy = 0.5 + (v - viewCenterV) * currentZoom
	return vx, vy
end

local function clampViewCenter(u: number, v: number, zoom: number): (number, number)
	if zoom <= 1.001 then
		return 0.5, 0.5
	end
	local halfSpan = 0.5 / zoom
	return math.clamp(u, halfSpan, 1 - halfSpan), math.clamp(v, halfSpan, 1 - halfSpan)
end

local function getCardinalBearing(dx: number, dz: number): string
	-- North is -Z, East is +X
	local deg = (math.deg(math.atan2(dx, -dz)) + 360) % 360
	if deg >= 337.5 or deg < 22.5 then
		return "N"
	elseif deg < 67.5 then
		return "NE"
	elseif deg < 112.5 then
		return "E"
	elseif deg < 157.5 then
		return "SE"
	elseif deg < 202.5 then
		return "S"
	elseif deg < 247.5 then
		return "SW"
	elseif deg < 292.5 then
		return "W"
	else
		return "NW"
	end
end

-- Liang-Barsky 2D line segment clipping against viewport rect [minB, maxB]
-- Ensures rotated route beam never extends outside MapOverlayClip!
local function clipSegmentToBox(
	x0: number,
	y0: number,
	x1: number,
	y1: number,
	minB: number,
	maxB: number
): (boolean, number, number, number, number)
	local dx = x1 - x0
	local dy = y1 - y0
	local t0 = 0.0
	local t1 = 1.0

	local function clipEdge(p: number, q: number): boolean
		if math.abs(p) < 1e-6 then
			return q >= 0
		end
		local r = q / p
		if p < 0 then
			if r > t1 then
				return false
			end
			if r > t0 then
				t0 = r
			end
		else
			if r < t0 then
				return false
			end
			if r < t1 then
				t1 = r
			end
		end
		return true
	end

	if not clipEdge(-dx, x0 - minB) then return false, 0, 0, 0, 0 end
	if not clipEdge(dx, maxB - x0) then return false, 0, 0, 0, 0 end
	if not clipEdge(-dy, y0 - minB) then return false, 0, 0, 0, 0 end
	if not clipEdge(dy, maxB - y0) then return false, 0, 0, 0, 0 end

	return true, x0 + t0 * dx, y0 + t0 * dy, x0 + t1 * dx, y0 + t1 * dy
end

-- ============================================================================
-- UI FACTORY HELPERS
-- ============================================================================

local function makeCorner(parent: Instance, r: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
	return c
end

local function makeStroke(parent: Instance, color: Color3, thickness: number, mode: Enum.ApplyStrokeMode?): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
	return s
end

local function scaledPx(basePx: number, scale: number?): number
	local sc = scale or currentMarkerScale
	return math.max(2, math.floor(basePx * sc + 0.5))
end

local function scaledStroke(baseThickness: number, scale: number?): number
	local sc = scale or currentMarkerScale
	local factor = math.clamp(0.62 + 0.38 * sc, 0.78, 1.38)
	return math.floor((baseThickness * factor) * 20 + 0.5) / 20
end

local function registerScaledMarker(
	gui: GuiObject,
	corner: UICorner?,
	stroke: UIStroke?,
	baseW: number,
	baseH: number,
	baseTextSize: number?,
	baseCorner: number?,
	baseStroke: number,
	isRound: boolean?
): ScaledMarkerEntry
	local entry: ScaledMarkerEntry = {
		Gui = gui,
		Corner = corner,
		Stroke = stroke,
		BaseW = baseW,
		BaseH = baseH,
		BaseTextSize = baseTextSize,
		BaseCorner = baseCorner,
		BaseStroke = baseStroke,
		IsRound = isRound,
	}
	table.insert(scaledMarkers, entry)
	return entry
end

local function updateCornerTickOcclusion(): ()
	if nwIntercardinalTick then
		local blocked = (hoverTipLabel ~= nil and hoverTipLabel.Visible)
			or (resizeToastLabel ~= nil and resizeToastLabel.Visible)
		if blocked then
			nwIntercardinalTick.Visible = false
		else
			local alpha = math.clamp((currentViewportSize - 215) / 50, 0, 1)
			nwIntercardinalTick.Visible = alpha > 0.04
		end
	end
end

local function showHoverTip(text: string?): ()
	if not hoverTipLabel then
		return
	end
	if text and text ~= "" then
		hoverTipLabel.Text = " " .. text .. " "
		hoverTipLabel.Visible = true
	else
		hoverTipLabel.Visible = false
	end
	updateCornerTickOcclusion()
end

local function showResizeToast(text: string, duration: number?): ()
	if not resizeToastLabel then
		return
	end
	resizeToastLabel.Text = " " .. text .. " "
	resizeToastLabel.TextTransparency = 0
	resizeToastLabel.BackgroundTransparency = 0.08
	local st = resizeToastLabel:FindFirstChildOfClass("UIStroke")
	if st then
		st.Transparency = 0
	end
	resizeToastLabel.Visible = true
	resizeToastExpiresAt = os.clock() + (duration or 1.15)
	updateCornerTickOcclusion()
end

local function addGeoRect(
	parent: Instance,
	x: number,
	z: number,
	sx: number,
	sz: number,
	color: Color3,
	zIndex: number,
	rotDeg: number?,
	cornerPx: number?,
	strokeColor: Color3?
): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = worldToScale(x, z)
	f.Size = UDim2.fromScale(sx / WORLD_SPAN, sz / WORLD_SPAN)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = zIndex
	if rotDeg and rotDeg ~= 0 then
		f.Rotation = rotDeg
	end
	f.Parent = parent
	if cornerPx and cornerPx > 0 then
		makeCorner(f, cornerPx)
	end
	if strokeColor then
		local st = makeStroke(f, strokeColor, 0.75, Enum.ApplyStrokeMode.Border)
		st.Transparency = 0.25
	end
	return f
end

local function addGeoCircle(parent: Instance, x: number, z: number, diameter: number, color: Color3, zIndex: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = worldToScale(x, z)
	f.Size = UDim2.fromScale(diameter / WORLD_SPAN, diameter / WORLD_SPAN)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = zIndex
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	return f
end

local function setMapDestination(x: number, z: number, label: string): ()
	AudioController.PlayClick()
	WaypointController.SetCustomWaypoint(Vector3.new(x, 4, z), label)
end

-- ============================================================================
-- STATIC WORLD GEOGRAPHY BUILDER (ONCE AT INIT, 100% REAL WORLD COORDS)
-- ============================================================================

local function buildWorldGeography(world: Frame): ()
	-- 1. Playable Island Landmass (2040 x 2040)
	local island = addGeoRect(
		world,
		0,
		0,
		MinimapMapData.ISLAND_HALF * 2,
		MinimapMapData.ISLAND_HALF * 2,
		C_ISLAND,
		1,
		nil,
		3,
		C_ISLAND_EDGE
	)
	island.Name = "IslandLandmass"

	-- 2. Darker Green Parks & Open Forested Meadow Corridors
	for _, p in ipairs(MinimapMapData.ParkZones) do
		addGeoRect(world, p.x, p.z, p.sx, p.sz, C_PARK_ZONE, 2, nil, 3)
	end

	-- 3. Major District Pads (Central HUB Platform, 4 Player Base Compounds, 28 Turf Capture Plazas)
	local cp = MinimapMapData.CentralPlatform
	addGeoRect(world, cp.x, cp.z, cp.sx, cp.sz, C_DISTRICT_PAD, 3, nil, 2, Color3.fromRGB(48, 56, 70))

	for _, b in ipairs(MinimapMapData.Bases) do
		local fCol = SectorConfig.FactionColors[b.Slot] or C_GOLD_DIM
		local tintBorder = fCol:Lerp(C_DISTRICT_PAD, 0.55)
		addGeoRect(world, b.CenterX, b.CenterZ, b.Size, b.Size, C_DISTRICT_PAD, 3, nil, 2, tintBorder)
	end

	for _, blockId in ipairs(TurfConfig.BlockOrder) do
		local spec = TurfConfig.Blocks[blockId]
		if spec then
			local psz = if spec.Ring == "Inner" then 44 else 48
			addGeoRect(world, spec.PlazaPos.X, spec.PlazaPos.Z, psz, psz, C_PLAZA_PAD, 3)
		end
	end

	-- 4. Central Park Lawns, Base Gardens, Grand Walkways & Central Fountain
	for _, lawn in ipairs(MinimapMapData.ParkLawns) do
		addGeoRect(world, lawn.x, lawn.z, lawn.sx, lawn.sz, C_PARK_LAWN, 4, nil, 1)
	end
	for _, wk in ipairs(MinimapMapData.CentralWalkways) do
		addGeoRect(world, wk.x, wk.z, wk.sx, wk.sz, C_WALKWAY, 4)
	end
	local ft = MinimapMapData.CentralFountain
	addGeoCircle(world, ft.x, ft.z, ft.d, C_WALKWAY, 4)
	addGeoCircle(world, ft.x, ft.z, ft.d * 0.58, C_FOUNTAIN_WATER, 5)

	-- 5. Subtle Cobblestone Alleys (tertiary)
	for _, al in ipairs(MinimapMapData.Alleys) do
		addGeoRect(world, al.x, al.z, al.sx, al.sz, C_ALLEY, 5)
	end

	-- 6. Secondary Roads (Wedge Cross-Streets & Corner Expansion Streets)
	for _, sr in ipairs(MinimapMapData.SecondaryRoads) do
		addGeoRect(world, sr.x, sr.z, sr.sx, sr.sz, C_ROAD_SECONDARY, 6, sr.rot)
	end

	-- 7. Main Arterial Road Network (Inner Ring, 4 Boulevards, Mid Ring, Corner Borders, 4 Diagonal Highways)
	for _, pr in ipairs(MinimapMapData.PrimaryRoads) do
		addGeoRect(world, pr.x, pr.z, pr.sx, pr.sz, C_ROAD_PRIMARY, 7, pr.rot)
	end

	-- 12 Traffic Roundabouts
	for _, rb in ipairs(MinimapMapData.Roundabouts) do
		addGeoCircle(world, rb.x, rb.z, rb.d, C_ROAD_PRIMARY, 7)
		addGeoCircle(world, rb.x, rb.z, rb.d * 0.44, C_ROUNDABOUT_CORE, 8)
	end

	-- 8. Simplified Rectangular Building Blocks (all real footprints from FoodEmpireMap)
	-- Solid crisp rectangles (no muddy per-building strokes at 1x scale; high perf)
	for _, bldg in ipairs(MinimapMapData.Buildings) do
		local fill = if bldg.major then C_BUILDING_MAJOR else C_BUILDING
		addGeoRect(world, bldg.x, bldg.z, bldg.sx, bldg.sz, fill, 9, bldg.rot)
	end

	-- Black Market Outpost physical footprint (live-synced if streamed in)
	local bm = MinimapMapData.BlackMarketDefault
	bmFootprintFrame = addGeoRect(
		world,
		bm.x,
		bm.z,
		bm.sx,
		bm.sz,
		Color3.fromRGB(98, 30, 44),
		9,
		nil,
		nil,
		Color3.fromRGB(162, 46, 68)
	)
end

-- ============================================================================
-- CLICKABLE LANDMARK & PLAYER INDICATOR BUILDERS
-- ============================================================================

local function addLandmarkBadge(
	parent: Instance,
	x: number,
	z: number,
	wPx: number,
	hPx: number,
	bgColor: Color3,
	textColor: Color3,
	shortLabel: string,
	fullName: string,
	zIndex: number,
	baseTextSize: number?
): (TextButton, UIStroke, ScaledMarkerEntry)
	local txtSize = baseTextSize or 9
	local btn = Instance.new("TextButton")
	btn.Name = "Marker_" .. shortLabel
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = worldToScale(x, z)
	btn.Size = UDim2.fromOffset(wPx, hPx)
	btn.BackgroundColor3 = bgColor
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.GothamBlack
	btn.Text = shortLabel
	btn.TextSize = txtSize
	btn.TextColor3 = textColor
	btn.ZIndex = zIndex
	btn.Parent = parent
	local corner = makeCorner(btn, 4)

	local st = makeStroke(btn, Color3.fromRGB(12, 16, 24), 1.3, Enum.ApplyStrokeMode.Border)
	local entry = registerScaledMarker(btn, corner, st, wPx, hPx, txtSize, 4, 1.3, false)

	btn.MouseEnter:Connect(function()
		showHoverTip(fullName)
	end)
	btn.MouseLeave:Connect(function()
		showHoverTip(nil)
	end)
	btn.MouseButton1Click:Connect(function()
		setMapDestination(x, z, fullName)
	end)

	return btn, st, entry
end

local function addDetailSubLabel(
	parentMarker: GuiObject,
	text: string,
	above: boolean,
	baseTextSize: number,
	minEffectivePx: number,
	fullEffectivePx: number,
	textColor: Color3?,
	targetTransparency: number?
): DetailSubLabel
	local lbl = Instance.new("TextLabel")
	lbl.Name = "DetailSubLabel"
	lbl.AnchorPoint = Vector2.new(0.5, if above then 1 else 0)
	lbl.Position = if above then UDim2.new(0.5, 0, 0, -1) else UDim2.new(0.5, 0, 1, 1)
	lbl.AutomaticSize = Enum.AutomaticSize.X
	lbl.Size = UDim2.fromOffset(0, baseTextSize + 2)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = text
	lbl.TextSize = baseTextSize
	lbl.TextColor3 = textColor or Color3.fromRGB(232, 236, 244)
	lbl.TextTransparency = 1
	lbl.Active = false
	lbl.Visible = false
	lbl.ZIndex = math.max(parentMarker.ZIndex + 1, 6)
	lbl.Parent = parentMarker

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.fromRGB(10, 13, 20)
	stroke.Thickness = 1.4
	stroke.Transparency = 1
	stroke.Parent = lbl

	local spec: DetailSubLabel = {
		Label = lbl,
		Stroke = stroke,
		AnchorParent = parentMarker,
		Above = above,
		BaseTextSize = baseTextSize,
		MinEffectivePx = minEffectivePx,
		FullEffectivePx = fullEffectivePx,
		TargetTransparency = targetTransparency or 0.14,
	}
	table.insert(detailSubLabels, spec)
	return spec
end

-- Sleek rotating directional player triangle built purely from crisp Roblox UI elements
local function buildPlayerTriangle(parent: Instance): (Frame, PlayerIndicatorRefs)
	local holder = Instance.new("Frame")
	holder.Name = "PlayerDirectionalTriangle"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(18, 18)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 12
	holder.Parent = parent

	-- Subtle dark contrast halo so white arrow reads crisply on any map color
	local halo = Instance.new("Frame")
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.54)
	halo.Size = UDim2.fromOffset(12, 12)
	halo.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
	halo.BackgroundTransparency = 0.35
	halo.BorderSizePixel = 0
	halo.ZIndex = 12
	halo.Parent = holder
	local haloCorner = makeCorner(halo, 6)

	-- Crisp directional triangle (▲ points North / -Z at Rotation = 0)
	local tri = Instance.new("TextLabel")
	tri.Name = "TriangleGlyph"
	tri.AnchorPoint = Vector2.new(0.5, 0.5)
	tri.Position = UDim2.fromScale(0.5, 0.48)
	tri.Size = UDim2.fromOffset(18, 18)
	tri.BackgroundTransparency = 1
	tri.Font = Enum.Font.GothamBlack
	tri.Text = "▲"
	tri.TextSize = 15
	tri.TextColor3 = Color3.fromRGB(255, 255, 255)
	tri.ZIndex = 13
	tri.Parent = holder

	local tStroke = Instance.new("UIStroke")
	tStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	tStroke.Color = Color3.fromRGB(10, 14, 22)
	tStroke.Thickness = 2.0
	tStroke.Parent = tri

	-- Bright cyan forward nose pip to make fine heading unmistakably clear
	local nose = Instance.new("Frame")
	nose.Name = "HeadingTip"
	nose.AnchorPoint = Vector2.new(0.5, 0.5)
	nose.Position = UDim2.fromScale(0.5, 0.14)
	nose.Size = UDim2.fromOffset(3, 3)
	nose.BackgroundColor3 = C_CYAN
	nose.BorderSizePixel = 0
	nose.ZIndex = 14
	nose.Parent = holder
	local noseCorner = makeCorner(nose, 2)

	return holder, {
		Holder = holder,
		Halo = halo,
		HaloCorner = haloCorner,
		Glyph = tri,
		GlyphStroke = tStroke,
		Nose = nose,
		NoseCorner = noseCorner,
	}
end

-- ============================================================================
-- POOLED DYNAMIC MARKERS & RADAR PINGS
-- ============================================================================

local function acquireDot(pool: { DynamicDot }, index: number, parent: Instance, zIndex: number, isDiamond: boolean): DynamicDot
	local existing = pool[index]
	if existing then
		return existing
	end
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(scaledPx(7), scaledPx(7))
	f.BorderSizePixel = 0
	f.Visible = false
	f.ZIndex = zIndex
	local corner: UICorner? = nil
	if isDiamond then
		f.Rotation = 45
	else
		corner = makeCorner(f, 8)
	end
	f.Parent = parent

	local st = makeStroke(f, Color3.fromRGB(10, 14, 20), scaledStroke(1.2), Enum.ApplyStrokeMode.Border)
	local dot: DynamicDot = {
		Frame = f,
		Stroke = st,
		Corner = corner,
		U = 0.5,
		V = 0.5,
		BaseSize = 7,
		BaseStroke = 1.2,
		Active = false,
	}
	pool[index] = dot
	return dot
end

local function refreshRotatedMarkerClipping(): ()
	for _, dot in ipairs(enemyPool) do
		if dot.Active then
			local vx, vy = uvToViewport(dot.U, dot.V)
			dot.Frame.Visible = vx >= 0.03 and vx <= 0.97 and vy >= 0.03 and vy <= 0.97
		else
			dot.Frame.Visible = false
		end
	end
	if expressObjMarker then
		if expressObjPos then
			local u, v = worldToUV(expressObjPos.X, expressObjPos.Z)
			local vx, vy = uvToViewport(u, v)
			expressObjMarker.Position = UDim2.fromScale(u, v)
			expressObjMarker.Visible = vx >= 0.03 and vx <= 0.97 and vy >= 0.03 and vy <= 0.97
		else
			expressObjMarker.Visible = false
		end
	end
	if crateWarehouseMarker then
		if crateWarehousePos then
			local u, v = worldToUV(crateWarehousePos.X, crateWarehousePos.Z)
			local vx, vy = uvToViewport(u, v)
			crateWarehouseMarker.Position = UDim2.fromScale(u, v)
			crateWarehouseMarker.Visible = vx >= 0.03 and vx <= 0.97 and vy >= 0.03 and vy <= 0.97
		else
			crateWarehouseMarker.Visible = false
		end
	end
end

local function spawnRadarPing(worldPos: Vector3, color: Color3): ()
	if not overlayWorld then
		return
	end
	-- Cap concurrent radar ping rings for steady performance
	if #pingRings >= 8 then
		local oldest = table.remove(pingRings, 1)
		if oldest and oldest.Frame.Parent then
			oldest.Frame:Destroy()
		end
	end
	local initPx = scaledPx(6)
	local f = Instance.new("Frame")
	f.Name = "RadarPing"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = worldToScale(worldPos.X, worldPos.Z)
	f.Size = UDim2.fromOffset(initPx, initPx)
	f.BackgroundTransparency = 1
	f.ZIndex = 8
	f.Parent = overlayWorld
	makeCorner(f, 36)
	local st = makeStroke(f, color, scaledStroke(1.5), Enum.ApplyStrokeMode.Border)

	table.insert(pingRings, {
		Frame = f,
		Stroke = st,
		Pos = worldPos,
		StartedAt = os.clock(),
		Duration = 1.15,
	})
end

-- ============================================================================
-- RESPONSIVE GEOMETRY, DYNAMIC RESIZING & ADAPTIVE MAP READABILITY
-- ============================================================================

local function getHudScale(): number
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		local attr = pg:GetAttribute("FoodEmpireHUDScale")
		if typeof(attr) == "number" and attr > 0.1 then
			return attr
		end
	end
	if hostScreenGui then
		local uis = hostScreenGui:FindFirstChildOfClass("UIScale")
		if uis and uis.Scale > 0.1 then
			return uis.Scale
		end
	end
	return 1.0
end

local function computeChromeMetrics(vpFloat: number): ChromeMetrics
	local vpPx = math.max(96, math.floor(vpFloat + 0.5))
	local s = vpFloat / BASE_VIEWPORT_SIZE
	local markerScale = math.clamp(0.45 + 0.55 * s, 0.78, 1.50)
	local pad = math.floor(math.clamp(4 + 3 * s, 5, 10) + 0.5)
	local headerH = math.floor(math.clamp(18 + 4 * s, 20, 28) + 0.5)
	local statusH = math.floor(math.clamp(16 + 4 * s, 18, 26) + 0.5)
	local gapMid = math.floor(math.clamp(2 + 1 * s, 3, 6) + 0.5)
	local gapBot = math.floor(math.clamp(3 + 1 * s, 3, 6) + 0.5)
	local frameW = vpPx + pad * 2
	local frameH = (headerH + 1) + vpPx + gapMid + statusH + gapBot
	local cornerR = math.floor(math.clamp(6 + 2 * s, 6, 11) + 0.5)
	local viewportCornerR = math.floor(math.clamp(4 + 1 * s, 4, 7) + 0.5)
	local scaleBarPx = math.floor(math.clamp(16 + 12 * s, 22, 46) + 0.5)

	return {
		ViewportPx = vpPx,
		ScaleRatio = s,
		MarkerScale = markerScale,
		Pad = pad,
		HeaderH = headerH,
		StatusH = statusH,
		GapMid = gapMid,
		GapBot = gapBot,
		FrameW = frameW,
		FrameH = frameH,
		CornerR = cornerR,
		ViewportCornerR = viewportCornerR,
		ScaleBarPx = scaleBarPx,
	}
end

local function resolveNearestPreset(vpPx: number): MinimapSizePreset
	if vpPx < 166 then
		return "Compact"
	elseif vpPx < 236 then
		return "Standard"
	else
		return "Large"
	end
end

local function computeResponsiveBounds(): ResponsiveBounds
	local hudScale = getHudScale()
	local logicalW = 1360
	local logicalH = 702

	if hostScreenGui and hostScreenGui.AbsoluteSize.X > 1 and hostScreenGui.AbsoluteSize.Y > 1 then
		logicalW = hostScreenGui.AbsoluteSize.X / hudScale
		logicalH = hostScreenGui.AbsoluteSize.Y / hudScale
	else
		local cam = Workspace.CurrentCamera
		if cam and cam.ViewportSize.X > 1 and cam.ViewportSize.Y > 1 then
			logicalW = cam.ViewportSize.X / hudScale
			logicalH = math.max(320, (cam.ViewportSize.Y - 58) / hudScale)
		end
	end

	local rightMargin = if logicalW < 760 then 10 else 14
	local baseBottomMargin = if logicalH < 480 then 10 else 14

	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local hotbarHalfW = if pg and typeof(pg:GetAttribute("FoodEmpireHotbarHalfW")) == "number"
		then (pg:GetAttribute("FoodEmpireHotbarHalfW") :: number)
		else 207

	-- Right edge of Bottom-Center ActionSquadCluster (SERVE / ATTACK / RECALL)
	local actionRightEdge = logicalW * 0.5 + hotbarHalfW + 10 + 146
	if hostScreenGui then
		local actCluster = hostScreenGui:FindFirstChild("ActionSquadCluster")
		if actCluster and actCluster:IsA("GuiObject") and actCluster.Visible and actCluster.AbsoluteSize.X > 1 then
			local liveRight = ((actCluster.AbsolutePosition.X - hostScreenGui.AbsolutePosition.X) + actCluster.AbsoluteSize.X) / hudScale
			if liveRight > logicalW * 0.5 and liveRight < logicalW then
				actionRightEdge = math.max(actionRightEdge, liveRight)
			end
		end
	end

	-- Persistent Top-Right rail ceiling (DayNightClock + UrbanTurfCard)
	local rightRailCeiling = 146
	if hostScreenGui then
		local turfCard = hostScreenGui:FindFirstChild("UrbanTurfCard")
		if turfCard and turfCard:IsA("GuiObject") and turfCard.Visible and turfCard.AbsoluteSize.Y > 1 then
			local liveBottom = ((turfCard.AbsolutePosition.Y - hostScreenGui.AbsolutePosition.Y) + turfCard.AbsoluteSize.Y) / hudScale
			if liveBottom > 60 and liveBottom < logicalH * 0.45 then
				rightRailCeiling = math.max(rightRailCeiling, liveBottom)
			end
		end
	end

	local minChrome = computeChromeMetrics(MIN_VIEWPORT_SIZE)
	local clearWBottom = logicalW - rightMargin - actionRightEdge - 10
	local elevated = false
	local bottomMargin = baseBottomMargin
	local availFrameW = clearWBottom

	-- On narrow / portrait screens where bottom hotbar spans across the bottom row,
	-- elevate cleanly above BottomVitalsDock so zero HUD overlap occurs!
	if clearWBottom < minChrome.FrameW then
		elevated = true
		bottomMargin = 154
		availFrameW = math.min(logicalW - rightMargin * 2, math.max(minChrome.FrameW, logicalW * 0.56))
	end

	local availFrameH = (logicalH - bottomMargin) - (rightRailCeiling + 10)
	local propMaxW = logicalW * (if elevated then 0.54 else 0.38)
	local propMaxH = logicalH * 0.58

	local allowedFrameW = math.max(124, math.min(availFrameW, propMaxW))
	local allowedFrameH = math.max(166, math.min(availFrameH, propMaxH))

	-- Solve exact max square viewport side that fits inside (allowedFrameW, allowedFrameH)
	local maxVp = math.min(MAX_VIEWPORT_SIZE, allowedFrameW - 14, allowedFrameH - 50)
	for _ = 1, 3 do
		local probe = computeChromeMetrics(math.clamp(maxVp, 104, MAX_VIEWPORT_SIZE))
		local wOver = probe.FrameW - allowedFrameW
		local hOver = probe.FrameH - allowedFrameH
		local worstOver = math.max(wOver, hOver)
		if worstOver > 0 then
			maxVp -= worstOver
		else
			break
		end
	end

	maxVp = math.floor(math.clamp(maxVp, 108, MAX_VIEWPORT_SIZE))
	local minVp = math.min(MIN_VIEWPORT_SIZE, maxVp)

	return {
		MinViewport = minVp,
		MaxViewport = maxVp,
		RightMargin = rightMargin,
		BottomMargin = bottomMargin,
		LogicalW = logicalW,
		LogicalH = logicalH,
		ElevatedAboveDock = elevated,
	}
end

local function publishMinimapMetricsToHUD(frameW: number, frameH: number, bottomMargin: number, rightMargin: number, force: boolean?): ()
	if
		not force
		and math.abs(frameW - lastPublishedFrameW) < 0.5
		and math.abs(frameH - lastPublishedFrameH) < 0.5
		and math.abs(bottomMargin - lastPublishedBottom) < 0.5
		and math.abs(rightMargin - lastPublishedRight) < 0.5
	then
		return
	end
	lastPublishedFrameW = frameW
	lastPublishedFrameH = frameH
	lastPublishedBottom = bottomMargin
	lastPublishedRight = rightMargin

	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		pg:SetAttribute("FoodEmpireMinimapWidth", frameW)
		pg:SetAttribute("FoodEmpireMinimapHeight", frameH)
		pg:SetAttribute("FoodEmpireMinimapBottomOffset", bottomMargin)
		pg:SetAttribute("FoodEmpireMinimapRightOffset", rightMargin)
	end
end

local function resolvePlayerZoneName(worldPos: Vector3?): string
	if not worldPos then
		return ""
	end
	local x, z = worldPos.X, worldPos.Z
	if math.abs(x) <= 195 and math.abs(z) <= 195 then
		return "CENTRAL HUB"
	end
	for _, b in ipairs(MinimapMapData.Bases) do
		if math.abs(x - b.CenterX) <= 125 and math.abs(z - b.CenterZ) <= 125 then
			return string.upper(b.Slot) .. " BASE"
		end
	end
	local nearestName: string? = nil
	local nearestDistSq = 120 * 120
	for _, blockId in ipairs(TurfConfig.BlockOrder) do
		local spec = TurfConfig.Blocks[blockId]
		if spec then
			local dx = x - spec.PlazaPos.X
			local dz = z - spec.PlazaPos.Z
			local dSq = dx * dx + dz * dz
			if dSq < nearestDistSq then
				nearestDistSq = dSq
				nearestName = spec.ShortCode .. " • " .. spec.Quadrant
			end
		end
	end
	if nearestName then
		return nearestName
	end
	local ns = if z < 0 then "N" else "S"
	local ew = if x < 0 then "W" else "E"
	return ns .. ew .. " SECTOR"
end

local function updateDetailLabelsVisibility(force: boolean?): ()
	local effectivePx = currentViewportSize * math.max(1, currentZoom)
	if not force and math.abs(effectivePx - lastDetailEffectivePx) < 1.5 then
		return
	end
	lastDetailEffectivePx = effectivePx

	local mScale = currentMarkerScale
	for _, spec in ipairs(detailSubLabels) do
		local span = math.max(1, spec.FullEffectivePx - spec.MinEffectivePx)
		local alpha = math.clamp((effectivePx - spec.MinEffectivePx) / span, 0, 1)
		if alpha <= 0.02 then
			spec.Label.Visible = false
		else
			spec.Label.Visible = true
			local txtSz = math.floor(math.clamp(spec.BaseTextSize * (0.72 + 0.28 * mScale), 7, 11) + 0.5)
			spec.Label.TextSize = txtSz
			spec.Label.Size = UDim2.fromOffset(0, txtSz + 2)
			spec.Label.TextTransparency = 1 - alpha * (1 - spec.TargetTransparency)
			if spec.Stroke then
				spec.Stroke.Transparency = 1 - alpha * 0.78
			end
		end
	end
end

local function applyMarkerScaling(mScale: number): ()
	currentMarkerScale = mScale

	for _, entry in ipairs(scaledMarkers) do
		local w = scaledPx(entry.BaseW, mScale)
		local h = scaledPx(entry.BaseH, mScale)
		entry.Gui.Size = UDim2.fromOffset(w, h)
		if entry.BaseTextSize and (entry.Gui:IsA("TextButton") or entry.Gui:IsA("TextLabel")) then
			(entry.Gui :: TextButton).TextSize = math.max(6, math.floor(entry.BaseTextSize * mScale + 0.5))
		end
		if entry.Corner then
			if entry.IsRound then
				entry.Corner.CornerRadius = UDim.new(0, math.max(2, math.ceil(math.max(w, h) * 0.5)))
			elseif entry.BaseCorner then
				entry.Corner.CornerRadius = UDim.new(0, math.max(1, math.floor(entry.BaseCorner * mScale + 0.5)))
			end
		end
		if entry.Stroke then
			entry.Stroke.Thickness = scaledStroke(entry.BaseStroke, mScale)
		end
	end

	-- Re-apply semantic state stroke weights on Bases, Spawns, Turf, Bistro, Penthouse
	for slot, st in pairs(baseStrokes) do
		st.Thickness = scaledStroke(baseStrokeBases[slot] or 1.2, mScale)
	end
	for slot, st in pairs(baseSpawnStrokes) do
		st.Thickness = scaledStroke(baseSpawnStrokeBases[slot] or 1.0, mScale)
	end
	for blockId, st in pairs(turfStrokes) do
		st.Thickness = scaledStroke(turfStrokeBases[blockId] or 1.0, mScale)
	end
	if bistroStroke then
		bistroStroke.Thickness = scaledStroke(bistroStrokeBase, mScale)
	end
	if penthouseStroke then
		penthouseStroke.Thickness = scaledStroke(penthouseStrokeBase, mScale)
	end

	-- Player Directional Triangle
	if playerRefs then
		local holderPx = scaledPx(18, mScale)
		local haloPx = scaledPx(12, mScale)
		local nosePx = math.max(2, math.floor(3 * mScale + 0.5))
		playerRefs.Holder.Size = UDim2.fromOffset(holderPx, holderPx)
		playerRefs.Glyph.Size = UDim2.fromOffset(holderPx, holderPx)
		playerRefs.Glyph.TextSize = math.max(11, math.floor(15 * mScale + 0.5))
		playerRefs.GlyphStroke.Thickness = scaledStroke(2.0, mScale)
		playerRefs.Halo.Size = UDim2.fromOffset(haloPx, haloPx)
		playerRefs.HaloCorner.CornerRadius = UDim.new(0, math.ceil(haloPx * 0.5))
		playerRefs.Nose.Size = UDim2.fromOffset(nosePx, nosePx)
		playerRefs.NoseCorner.CornerRadius = UDim.new(0, math.ceil(nosePx * 0.5))
	end

	-- GPS Pin
	if gpsPinBtn then
		local pinPx = scaledPx(12, mScale)
		gpsPinBtn.Size = UDim2.fromOffset(pinPx, pinPx)
		if gpsPinCorner then
			gpsPinCorner.CornerRadius = UDim.new(0, math.ceil(pinPx * 0.5))
		end
		if gpsPinStroke then
			gpsPinStroke.Thickness = scaledStroke(1.8, mScale)
		end
		if gpsPinCore then
			local corePx = math.max(3, math.floor(4 * mScale + 0.5))
			gpsPinCore.Size = UDim2.fromOffset(corePx, corePx)
			if gpsPinCoreCorner then
				gpsPinCoreCorner.CornerRadius = UDim.new(0, math.ceil(corePx * 0.5))
			end
		end
	end

	-- Off-screen Waypoint Edge Arrow
	if edgeArrowFrame and edgeArrowIcon and edgeDistLabel then
		local ew = scaledPx(26, mScale)
		local eh = scaledPx(22, mScale)
		edgeArrowFrame.Size = UDim2.fromOffset(ew, eh)
		local iconPx = scaledPx(14, mScale)
		edgeArrowIcon.Size = UDim2.fromOffset(iconPx, iconPx)
		edgeArrowIcon.TextSize = math.max(9, math.floor(12 * mScale + 0.5))
		if edgeArrowStroke then
			edgeArrowStroke.Thickness = scaledStroke(1.8, mScale)
		end
		local distTxtSz = math.max(7, math.floor(7.2 * mScale + 0.5))
		edgeDistLabel.TextSize = distTxtSz
		edgeDistLabel.Size = UDim2.fromOffset(0, distTxtSz + 3)
	end

	-- Pooled dynamic ally & enemy dots
	for _, dot in ipairs(allyPool) do
		local px = scaledPx(dot.BaseSize, mScale)
		dot.Frame.Size = UDim2.fromOffset(px, px)
		dot.Stroke.Thickness = scaledStroke(dot.BaseStroke, mScale)
		if dot.Corner then
			dot.Corner.CornerRadius = UDim.new(0, math.ceil(px * 0.5) + 1)
		end
	end
	for _, dot in ipairs(enemyPool) do
		local px = scaledPx(dot.BaseSize, mScale)
		dot.Frame.Size = UDim2.fromOffset(px, px)
		dot.Stroke.Thickness = scaledStroke(dot.BaseStroke, mScale)
	end

	updateDetailLabelsVisibility(true)
end

local function updateSizeToggleChrome(): ()
	if not sizeToggleBtn then
		return
	end
	local tier = resolveNearestPreset(targetViewportSize)
	sizeToggleBtn.Text = PRESET_BADGES[tier]
	if sizeToggleStroke then
		sizeToggleStroke.Color = if isResizing
			then C_CYAN
			elseif tier == "Large" then C_GOLD
			elseif tier == "Compact" then Color3.fromRGB(92, 108, 132)
			else C_GOLD_DIM
	end
	sizeToggleBtn.TextColor3 = if tier == "Large" then C_GOLD else Color3.fromRGB(234, 226, 200)
end

local function updateStatusBarContentLayout(): ()
	if not gpsStatusLabel or not gpsDistLabel or not clearPinBtn then
		return
	end
	local m = computeChromeMetrics(currentViewportSize)
	local clrW = math.max(15, m.StatusH - 2)
	local clrH = math.max(14, m.StatusH - 4)
	clearPinBtn.Size = UDim2.fromOffset(clrW, clrH)
	clearPinBtn.TextSize = math.max(8, math.floor(7.5 + 1.5 * m.ScaleRatio + 0.5))

	local distW = math.floor(math.clamp(42 + 12 * m.ScaleRatio, 44, 68) + 0.5)
	gpsDistLabel.Position = UDim2.new(1, -(clrW + 5), 0, 0)
	gpsDistLabel.Size = UDim2.new(0, distW, 1, 0)
	gpsDistLabel.TextSize = math.max(8, math.floor(7.5 + 1.6 * m.ScaleRatio + 0.5))

	local statusTxtSz = math.max(8, math.floor(7.4 + 1.7 * m.ScaleRatio + 0.5))
	gpsStatusLabel.TextSize = statusTxtSz

	local showZone = (activeWaypointPos == nil) and (m.FrameW >= 252) and (lastRenderedZone ~= "")
	if zoneReadoutLabel then
		zoneReadoutLabel.Visible = showZone
		zoneReadoutLabel.TextSize = math.max(8, statusTxtSz - 1)
	end

	if activeWaypointPos then
		gpsStatusLabel.Size = UDim2.new(1, -(clrW + distW + 12), 1, 0)
		gpsStatusLabel.Text = "WP: " .. (activeWaypointLabel or "Map Pin")
		gpsStatusLabel.TextColor3 = C_GOLD
		clearPinBtn.Visible = true
		gpsDistLabel.Visible = true
	else
		if showZone and zoneReadoutLabel then
			local zoneW = math.floor(math.clamp(78 + 18 * m.ScaleRatio, 82, 118))
			zoneReadoutLabel.Size = UDim2.new(0, zoneW, 1, 0)
			gpsStatusLabel.Size = UDim2.new(1, -(zoneW + 14), 1, 0)
		else
			gpsStatusLabel.Size = UDim2.new(1, -12, 1, 0)
		end
		gpsStatusLabel.Text = if m.FrameW < 184 then "Click to set pin" else "Click map to set waypoint"
		gpsStatusLabel.TextColor3 = C_TEXT_MUTED
		clearPinBtn.Visible = false
		gpsDistLabel.Visible = false
	end
end

-- ============================================================================
-- ZOOM & VIEWPORT TRANSFORM (SINGLE-PARENT SCALE -> ZERO MARKER DRIFT!)
-- ============================================================================

local function updateZoomChrome(): ()
	if zoomReadoutBtn then
		zoomReadoutBtn.Text = string.format("%.1fx", targetZoom)
	end
	if scaleBarLabel then
		-- Exact world meters spanned by current scale bar pixel width at live viewport & zoom
		local meters = math.floor((currentScaleBarPx / (math.max(96, currentViewportSize) * math.max(1, currentZoom))) * WORLD_SPAN + 0.5)
		local rounded = math.max(10, math.floor((meters + 5) / 10) * 10)
		scaleBarLabel.Text = tostring(rounded) .. "m"
	end
	if followBtn then
		local isCentered = followPlayer or targetZoom <= 1.02
		followBtn.TextColor3 = if isCentered then C_CYAN else C_GOLD
	end
end

local function applyMinimapLayout(force: boolean?): ()
	if not islandFrame or not mapViewport then
		return
	end
	if
		not force
		and math.abs(currentViewportSize - lastAppliedViewportSize) < 0.12
		and math.abs(currentRightMargin - lastAppliedMarginX) < 0.12
		and math.abs(currentBottomMargin - lastAppliedMarginY) < 0.12
	then
		return
	end

	lastAppliedViewportSize = currentViewportSize
	lastAppliedMarginX = currentRightMargin
	lastAppliedMarginY = currentBottomMargin

	local m = computeChromeMetrics(currentViewportSize)
	currentScaleBarPx = m.ScaleBarPx

	-- 1. Outer frame (strictly anchored bottom-right, zero drift)
	islandFrame.Position = UDim2.new(1, -math.floor(currentRightMargin + 0.5), 1, -math.floor(currentBottomMargin + 0.5))
	islandFrame.Size = UDim2.fromOffset(m.FrameW, m.FrameH)
	if islandFrameCorner then
		islandFrameCorner.CornerRadius = UDim.new(0, m.CornerR)
	end
	if islandFrameStroke then
		islandFrameStroke.Thickness = math.clamp(1.1 + 0.22 * m.ScaleRatio, 1.1, 1.75)
	end

	-- 2. Top-left corner drag-resize grip
	if resizeGripBtn then
		local gripHit = math.floor(math.clamp(15 + 3 * m.ScaleRatio, 16, 24) + 0.5)
		resizeGripBtn.Size = UDim2.fromOffset(gripHit, gripHit)
	end

	-- 3. Responsive Header Bar (zero button/title overlap at any size!)
	if headerFrame then
		headerFrame.Size = UDim2.new(1, 0, 0, m.HeaderH)
	end
	local btnH = math.floor(math.clamp(13 + 3 * m.ScaleRatio, 14, 21) + 0.5)
	local btnTxtSz = math.floor(math.clamp(7.5 + 1.8 * m.ScaleRatio, 8, 12) + 0.5)
	local btnGap = if m.FrameW >= 245 then 3 else 2
	local showReadout = m.FrameW >= 186

	local wZoom = math.floor(math.clamp(13 + 2.8 * m.ScaleRatio, 14, 20) + 0.5)
	local wReadout = math.floor(math.clamp(22 + 5.5 * m.ScaleRatio, 24, 38) + 0.5)
	local wFollow = math.floor(math.clamp(14 + 3.0 * m.ScaleRatio, 15, 22) + 0.5)
	local wSize = math.floor(math.clamp(15 + 3.5 * m.ScaleRatio, 16, 24) + 0.5)

	local totalControlsW = wZoom + wZoom + wFollow + wSize + btnGap * 3
	if showReadout then
		totalControlsW += wReadout + btnGap
	end

	if headerControlsLayout then
		headerControlsLayout.Padding = UDim.new(0, btnGap)
	end
	if headerControlsRow then
		headerControlsRow.Position = UDim2.new(1, -m.Pad, 0, 0)
		headerControlsRow.Size = UDim2.new(0, totalControlsW + 2, 1, 0)
	end
	if zoomOutBtn then
		zoomOutBtn.Size = UDim2.fromOffset(wZoom, btnH)
		zoomOutBtn.TextSize = btnTxtSz
	end
	if zoomReadoutBtn then
		zoomReadoutBtn.Visible = showReadout
		zoomReadoutBtn.Size = UDim2.fromOffset(wReadout, btnH)
		zoomReadoutBtn.TextSize = math.max(8, btnTxtSz - 1)
	end
	if zoomInBtn then
		zoomInBtn.Size = UDim2.fromOffset(wZoom, btnH)
		zoomInBtn.TextSize = btnTxtSz
	end
	if followBtn then
		followBtn.Size = UDim2.fromOffset(wFollow, btnH)
		followBtn.TextSize = btnTxtSz
	end
	if sizeToggleBtn then
		sizeToggleBtn.Size = UDim2.fromOffset(wSize, btnH)
		sizeToggleBtn.TextSize = math.max(8, btnTxtSz)
	end

	if titleLabel then
		local titleLeft = math.floor(math.clamp(12 + 2.5 * m.ScaleRatio, 13, 18) + 0.5)
		local reservedRight = totalControlsW + m.Pad + 4
		titleLabel.Position = UDim2.new(0, titleLeft, 0, 0)
		titleLabel.Size = UDim2.new(1, -(titleLeft + reservedRight), 1, 0)
		titleLabel.TextSize = math.floor(math.clamp(7.4 + 1.8 * m.ScaleRatio, 8, 12) + 0.5)
		titleLabel.Text = if m.FrameW < 194 then "MAP" else "TACTICAL MAP"
	end

	-- 4. Strictly 1:1 Square Map Viewport
	mapViewport.Position = UDim2.fromOffset(m.Pad, m.HeaderH + 1)
	mapViewport.Size = UDim2.fromOffset(m.ViewportPx, m.ViewportPx)
	if mapViewportCorner then
		mapViewportCorner.CornerRadius = UDim.new(0, m.ViewportCornerR)
	end
	if geoClipCorner then
		geoClipCorner.CornerRadius = UDim.new(0, m.ViewportCornerR)
	end

	-- 5. Viewport Chrome (Compass ticks, intercardinals, reticle bezel ticks, scale bar, tooltips)
	local cardSz = math.floor(math.clamp(6.4 + 1.7 * m.ScaleRatio, 7, 11) + 0.5)
	for _, lbl in ipairs(cardinalTicks) do
		lbl.TextSize = cardSz
		lbl.Size = UDim2.fromOffset(cardSz + 5, cardSz + 3)
	end

	local largeChromeAlpha = math.clamp((currentViewportSize - 215) / 50, 0, 1)
	local interSz = math.floor(math.clamp(5.8 + 1.2 * m.ScaleRatio, 7, 9) + 0.5)
	for _, lbl in ipairs(intercardinalTicks) do
		if largeChromeAlpha <= 0.04 then
			lbl.Visible = false
		else
			lbl.TextSize = interSz
			lbl.TextTransparency = 1 - largeChromeAlpha * 0.58
			lbl.Visible = true
		end
	end
	updateCornerTickOcclusion()

	for _, tick in ipairs(bezelTicks) do
		if largeChromeAlpha <= 0.04 then
			tick.Visible = false
		else
			tick.BackgroundTransparency = 1 - largeChromeAlpha * 0.45
			tick.Visible = true
		end
	end

	if scaleBarFrame and scaleLineFrame and scaleBarLabel then
		local sTxtSz = math.floor(math.clamp(6.2 + 1.1 * m.ScaleRatio, 7, 10) + 0.5)
		scaleBarFrame.Size = UDim2.fromOffset(m.ScaleBarPx + 4, sTxtSz + 5)
		scaleLineFrame.Size = UDim2.fromOffset(m.ScaleBarPx, 2)
		scaleBarLabel.Size = UDim2.new(1, 0, 0, sTxtSz + 2)
		scaleBarLabel.TextSize = sTxtSz
	end

	if hoverTipLabel then
		local tipTxtSz = math.floor(math.clamp(7.0 + 1.4 * m.ScaleRatio, 8, 11) + 0.5)
		hoverTipLabel.TextSize = tipTxtSz
		hoverTipLabel.Size = UDim2.fromOffset(0, tipTxtSz + 6)
		if hoverTipConstraint then
			hoverTipConstraint.MaxSize = Vector2.new(math.max(90, m.ViewportPx - 10), 28)
		end
	end
	if resizeToastLabel then
		local rtSz = math.floor(math.clamp(7.2 + 1.4 * m.ScaleRatio, 8, 11) + 0.5)
		resizeToastLabel.TextSize = rtSz
		resizeToastLabel.Size = UDim2.fromOffset(0, rtSz + 6)
	end

	-- 6. Bottom GPS Status Bar
	if statusBarFrame then
		statusBarFrame.Position = UDim2.new(0, m.Pad, 1, -(m.GapBot + m.StatusH))
		statusBarFrame.Size = UDim2.new(1, -(m.Pad * 2), 0, m.StatusH)
		if statusBarCorner then
			statusBarCorner.CornerRadius = UDim.new(0, math.max(3, m.ViewportCornerR - 1))
		end
	end
	updateStatusBarContentLayout()

	-- 7. Marker & icon proportional scaling + detail LOD
	applyMarkerScaling(m.MarkerScale)
	updateZoomChrome()
	updateSizeToggleChrome()

	-- 8. Notify sibling HUD panels (ReceiptTicket, HiredSecurityCard, PatienceCard) to stay zero-overlap
	publishMinimapMetricsToHUD(m.FrameW, m.FrameH, math.floor(currentBottomMargin + 0.5), math.floor(currentRightMargin + 0.5), force)
end

local function refreshResponsiveLayout(immediate: boolean?): ()
	local bounds = computeResponsiveBounds()
	cachedBounds = bounds
	targetRightMargin = bounds.RightMargin
	targetBottomMargin = bounds.BottomMargin

	local desired = if isCustomSize
		then preferredViewportSize
		else (PRESET_VIEWPORT_SIZES[activePreset] or BASE_VIEWPORT_SIZE)
	targetViewportSize = math.clamp(desired, bounds.MinViewport, bounds.MaxViewport)

	if immediate then
		currentRightMargin = targetRightMargin
		currentBottomMargin = targetBottomMargin
		currentViewportSize = targetViewportSize
		applyMinimapLayout(true)
	else
		updateSizeToggleChrome()
	end
end

local function setMinimapSizePresetInternal(preset: MinimapSizePreset, showFeedback: boolean?): ()
	activePreset = preset
	isCustomSize = false
	preferredViewportSize = PRESET_VIEWPORT_SIZES[preset] or BASE_VIEWPORT_SIZE
	refreshResponsiveLayout(false)
	resizePulse = 1.0
	if showFeedback then
		local shownPx = math.floor(targetViewportSize + 0.5)
		showResizeToast(string.format("%s MAP  •  %dpx", PRESET_DISPLAY_NAMES[preset], shownPx), 1.15)
	end
end

local function cycleMinimapSizeInternal(step: number?): ()
	local delta = step or 1
	local bounds = computeResponsiveBounds()
	cachedBounds = bounds

	-- Build effective distinct preset list for the current screen size so every click gives a clear change
	local effectivePresets: { MinimapSizePreset } = {}
	local lastVp = -999
	for _, presetName in ipairs(PRESET_ORDER) do
		local clampedVp = math.clamp(PRESET_VIEWPORT_SIZES[presetName], bounds.MinViewport, bounds.MaxViewport)
		if math.abs(clampedVp - lastVp) >= 14 then
			table.insert(effectivePresets, presetName)
			lastVp = clampedVp
		end
	end
	if #effectivePresets <= 1 then
		setMinimapSizePresetInternal("Standard", true)
		return
	end

	local curTier = resolveNearestPreset(targetViewportSize)
	local curIdx = table.find(effectivePresets, curTier) or 1
	local nextIdx = ((curIdx - 1 + delta) % #effectivePresets) + 1
	setMinimapSizePresetInternal(effectivePresets[nextIdx], true)
end

local function applyWorldTransform(force: boolean?): ()
	if not geoWorld or not overlayWorld then
		return
	end
	if
		not force
		and math.abs(currentZoom - lastAppliedZoom) < 0.0005
		and math.abs(viewCenterU - lastAppliedU) < 0.0002
		and math.abs(viewCenterV - lastAppliedV) < 0.0002
	then
		return
	end
	lastAppliedZoom = currentZoom
	lastAppliedU = viewCenterU
	lastAppliedV = viewCenterV

	local size = UDim2.fromScale(currentZoom, currentZoom)
	local pos = UDim2.fromScale(
		0.5 - (viewCenterU - 0.5) * currentZoom,
		0.5 - (viewCenterV - 0.5) * currentZoom
	)
	geoWorld.Size = size
	geoWorld.Position = pos
	overlayWorld.Size = size
	overlayWorld.Position = pos
	refreshRotatedMarkerClipping()
	updateDetailLabelsVisibility(false)
	updateZoomChrome()
end

local function setTargetZoom(newZoom: number): ()
	targetZoom = math.clamp(newZoom, MIN_ZOOM, MAX_ZOOM)
	if targetZoom <= 1.02 then
		targetZoom = 1.0
		followPlayer = true
		targetCenterU, targetCenterV = 0.5, 0.5
	else
		if followPlayer and lastPlayerWorldPos then
			local pu, pv = worldToUV(lastPlayerWorldPos.X, lastPlayerWorldPos.Z)
			targetCenterU, targetCenterV = clampViewCenter(pu, pv, targetZoom)
		else
			targetCenterU, targetCenterV = clampViewCenter(targetCenterU, targetCenterV, targetZoom)
		end
	end
	updateZoomChrome()
end

-- ============================================================================
-- EXISTING GAME MECHANIC DETECTION (ALLIES, ENEMIES, SMOKE STEALTH, LIVE SYNC)
-- ============================================================================

local function getSmokeCloudCenters(): { Vector3 }
	local out: { Vector3 } = {}
	for _, ch in ipairs(Workspace:GetChildren()) do
		if ch.Name == "TacticalSmokeCanister" and ch:IsA("BasePart") then
			table.insert(out, ch.Position)
		end
	end
	return out
end

local function isConcealedInSmoke(pos: Vector3, smokeCenters: { Vector3 }): boolean
	for _, sPos in ipairs(smokeCenters) do
		local dx = pos.X - sPos.X
		local dz = pos.Z - sPos.Z
		if (dx * dx + dz * dz) <= (18 * 18) then
			return true
		end
	end
	return false
end

local function hasRecentThreatNear(pos: Vector3, now: number, radius: number): boolean
	local rSq = radius * radius
	for _, t in ipairs(recentThreats) do
		if t.ExpiresAt > now then
			local dx = pos.X - t.Pos.X
			local dz = pos.Z - t.Pos.Z
			if (dx * dx + dz * dz) <= rSq then
				return true
			end
		end
	end
	return false
end

local function hasLineOfSight(fromPos: Vector3, toPos: Vector3, targetModel: Model, localChar: Model?): boolean
	local origin = fromPos + Vector3.new(0, 3.0, 0)
	local dest = toPos + Vector3.new(0, 2.5, 0)
	local dir = dest - origin
	local dist = dir.Magnitude
	if dist < 2 then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	if localChar then
		table.insert(ignore, localChar)
	end
	table.insert(ignore, targetModel)
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(origin, dir, params)
	return hit == nil
end

local function isEnemyInUnderAttackBlock(pos: Vector3): boolean
	for blockId, active in pairs(underAttackBlocks) do
		if active then
			local spec = TurfConfig.Blocks[blockId]
			if spec then
				local dx = pos.X - spec.PlazaPos.X
				local dz = pos.Z - spec.PlazaPos.Z
				local r = (spec.CaptureRadius or 30) + 28
				if (dx * dx + dz * dz) <= (r * r) then
					return true
				end
			end
		end
	end
	return false
end

local function syncLiveStreamedLandmarks(): ()
	local mapFolder = Workspace:FindFirstChild("FoodEmpireMap")
	if not mapFolder then
		return
	end
	-- Live-sync BlackMarketOutpost when streamed in
	local bmOutpost = mapFolder:FindFirstChild("BlackMarketOutpost")
	if bmOutpost and bmOutpost:IsA("Model") then
		local cf = bmOutpost:GetPivot()
		bmWorldX = cf.Position.X
		bmWorldZ = cf.Position.Z
		local sc = worldToScale(bmWorldX, bmWorldZ)
		if bmMarkerBtn then
			bmMarkerBtn.Position = sc
		end
		if bmFootprintFrame then
			bmFootprintFrame.Position = sc
		end
	end
	-- Live-sync BaseSpawn positions when streamed in
	local basesFolder = mapFolder:FindFirstChild("PlayerBases")
	if basesFolder then
		for _, meta in ipairs(MinimapMapData.Bases) do
			local bm = basesFolder:FindFirstChild(meta.Slot .. "Base")
			local sp = if bm then bm:FindFirstChild("BaseSpawn") else nil
			local spMarker = baseSpawnMarkers[meta.Slot]
			if sp and sp:IsA("BasePart") and spMarker then
				spMarker.Position = worldToScale(sp.Position.X, sp.Position.Z)
			end
		end
	end
end

local function scanTacticalEntities(now: number): ()
	if not overlayWorld then
		return
	end

	-- Prune expired combat threat pings
	for i = #recentThreats, 1, -1 do
		if recentThreats[i].ExpiresAt <= now then
			table.remove(recentThreats, i)
		end
	end
	for inst, exp in pairs(revealedEnemyUntil) do
		if exp <= now or not inst.Parent then
			revealedEnemyUntil[inst] = nil
		end
	end

	local localPlayer = Players.LocalPlayer
	local localUserId = localPlayer.UserId
	local localFaction = "Player_" .. tostring(localUserId)
	local localFamilyAttr = localPlayer:GetAttribute("SyndicateFamilyName")
	local localFamily = if typeof(localFamilyAttr) == "string" and localFamilyAttr ~= "" then localFamilyAttr else nil
	local localChar = localPlayer.Character
	local localRoot = if localChar then localChar:FindFirstChild("HumanoidRootPart") else nil
	local playerPos = if localRoot and localRoot:IsA("BasePart") then localRoot.Position else nil

	local smokeCenters = getSmokeCloudCenters()
	local allySpotters: { Vector3 } = {}

	-- =========================================================================
	-- 1. TEAMMATES & ALLIED SQUAD (Family Players + Personal Guards/Mercs/Runners)
	-- =========================================================================
	local allyIdx = 0
	local enemyIdx = 0

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= localPlayer then
			local char = other.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
			local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
			if char and root and root:IsA("BasePart") and hum and hum.Health > 0 then
				local oFam = other:GetAttribute("SyndicateFamilyName")
				local isFamilyTeammate = localFamily ~= nil and typeof(oFam) == "string" and oFam == localFamily

				if isFamilyTeammate then
					table.insert(allySpotters, root.Position)
					allyIdx += 1
					local dot = acquireDot(allyPool, allyIdx, overlayWorld, 8, false)
					local oSlot = other:GetAttribute("BaseSlot")
					local teamCol = if typeof(oSlot) == "string" and SectorConfig.FactionColors[oSlot]
						then SectorConfig.FactionColors[oSlot]:Lerp(C_ALLY_PLAYER, 0.35)
						else C_ALLY_PLAYER
					dot.BaseSize = 9
					dot.BaseStroke = 1.5
					local allyPx = scaledPx(9)
					dot.Frame.Size = UDim2.fromOffset(allyPx, allyPx)
					if dot.Corner then
						dot.Corner.CornerRadius = UDim.new(0, math.ceil(allyPx * 0.5) + 1)
					end
					dot.Frame.BackgroundColor3 = teamCol
					dot.Stroke.Color = Color3.new(1, 1, 1)
					dot.Stroke.Thickness = scaledStroke(1.5)
					dot.Frame.Position = worldToScale(root.Position.X, root.Position.Z)
					dot.Frame.Visible = true
				else
					-- Rival Player: display ONLY when detected or revealed through existing mechanics!
					local bountyAttr = other:GetAttribute("SyndicateBounty")
					local hasBounty = typeof(bountyAttr) == "number" and bountyAttr > 0
					local inSmoke = isConcealedInSmoke(root.Position, smokeCenters)
					local revealed = hasBounty
					if not revealed and hasRecentThreatNear(root.Position, now, 28) then
						revealedEnemyUntil[other] = math.max(revealedEnemyUntil[other] or 0, now + 5.5)
						revealed = true
					end
					if not revealed and (revealedEnemyUntil[other] or 0) > now then
						revealed = true
					end
					if not revealed and not inSmoke and playerPos then
						local dist = (root.Position - playerPos).Magnitude
						if dist <= 105 and hasLineOfSight(playerPos, root.Position, char, localChar) then
							revealed = true
						end
					end

					if revealed then
						local u, v = worldToUV(root.Position.X, root.Position.Z)
						local vx, vy = uvToViewport(u, v)
						local inBounds = vx >= 0.03 and vx <= 0.97 and vy >= 0.03 and vy <= 0.97
						enemyIdx += 1
						local dot = acquireDot(enemyPool, enemyIdx, overlayWorld, 9, true)
						dot.U = u
						dot.V = v
						dot.Active = true
						dot.BaseSize = if hasBounty then 9 else 7
						dot.BaseStroke = if hasBounty then 1.6 else 1.2
						local ePx = scaledPx(dot.BaseSize)
						dot.Frame.Size = UDim2.fromOffset(ePx, ePx)
						dot.Frame.BackgroundColor3 = if hasBounty then C_ENEMY_HIGH else C_ENEMY
						dot.Stroke.Color = if hasBounty then C_ENEMY else Color3.fromRGB(14, 16, 22)
						dot.Stroke.Thickness = scaledStroke(dot.BaseStroke)
						dot.Frame.Position = UDim2.fromScale(u, v)
						dot.Frame.Visible = inBounds
					end
				end
			end
		end
	end

	-- Allied NPC Squad (Bodyguards, Hired Samurai/Ninja Mercenaries, Supply Couriers)
	for _, tagName in ipairs(ALLY_UNIT_TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
			if inst:IsA("Model") and inst:IsDescendantOf(Workspace) then
				local ownerId = inst:GetAttribute("OwnerUserId")
				local isMine = ownerId == localUserId
				local isFamilyAllyUnit = false
				if not isMine and localFamily and typeof(ownerId) == "number" then
					local ownerP = Players:GetPlayerByUserId(ownerId)
					if ownerP and ownerP:GetAttribute("SyndicateFamilyName") == localFamily then
						isFamilyAllyUnit = true
					end
				end
				if isMine or isFamilyAllyUnit then
					local root = inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart")
					local hum = inst:FindFirstChildOfClass("Humanoid")
					if root and root:IsA("BasePart") and (not hum or hum.Health > 0) then
						if tagName ~= "PlayerDeliveryRunner" then
							table.insert(allySpotters, root.Position)
						end
						allyIdx += 1
						local dot = acquireDot(allyPool, allyIdx, overlayWorld, 8, false)
						dot.BaseSize = 6
						dot.BaseStroke = 1.1
						local sqPx = scaledPx(6)
						dot.Frame.Size = UDim2.fromOffset(sqPx, sqPx)
						if dot.Corner then
							dot.Corner.CornerRadius = UDim.new(0, math.ceil(sqPx * 0.5) + 1)
						end
						dot.Frame.BackgroundColor3 = if tagName == "PlayerDeliveryRunner"
							then Color3.fromRGB(116, 224, 192)
							else C_ALLY_SQUAD
						dot.Stroke.Color = Color3.fromRGB(14, 18, 28)
						dot.Stroke.Thickness = scaledStroke(1.1)
						dot.Frame.Position = worldToScale(root.Position.X, root.Position.Z)
						dot.Frame.Visible = true
					end
				end
			end
		end
	end

	-- Also check Player-owned Turf Guard units as subtle squad allies if close
	local seenModels: { [Instance]: boolean } = {}
	local losChecksLeft = 6 -- Cap raycasts per 0.2s tick for rock-solid performance

	-- =========================================================================
	-- 2. HOSTILE UNITS (ONLY SHOWN WHEN DETECTED OR REVEALED!)
	-- =========================================================================
	for _, tagName in ipairs(HOSTILE_UNIT_TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
			if inst:IsA("Model") and not seenModels[inst] and inst:IsDescendantOf(Workspace) then
				seenModels[inst] = true
				local hum = inst:FindFirstChildOfClass("Humanoid")
				local root = inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and hum and hum.Health > 0 and inst:GetAttribute("IsDying") ~= true then
					-- Skip player's own turf defenders
					if tagName == "TurfGuardUnit" and inst:GetAttribute("Faction") == localFaction then
						continue
					end

					local pos = root.Position
					local isHitContract = inst:GetAttribute("HitContractOwner") == localUserId
					local isPenthouseUnit = inst:GetAttribute("IsPenthouseRaidUnit") == true
					local isBoss = inst:GetAttribute("IsMafiaBoss") == true
						or inst:GetAttribute("IsRivalBoss") == true
						or isHitContract
					local isProvoked = inst:GetAttribute("Provoked") == true
					local isDamaged = hum.Health < (hum.MaxHealth - 1) or inst:GetAttribute("LastHitDir") ~= nil
					local inSmoke = isConcealedInSmoke(pos, smokeCenters)

					local revealed = isHitContract or isPenthouseUnit or isProvoked or isDamaged

					-- Combat sound / gunfire reveal (existing CombatSFX bus)
					if not revealed and hasRecentThreatNear(pos, now, 26) then
						revealedEnemyUntil[inst] = math.max(revealedEnemyUntil[inst] or 0, now + 5.5)
						revealed = true
					end

					-- Timed reveal memory
					if not revealed and (revealedEnemyUntil[inst] or 0) > now then
						revealed = true
					end

					-- Active raid on one of the player's turf blocks
					if not revealed and isEnemyInUnderAttackBlock(pos) then
						revealed = true
					end

					-- Direct close-range unobstructed line-of-sight spotting (blocked by walls & smoke!)
					if not revealed and not inSmoke and playerPos then
						local dist = (pos - playerPos).Magnitude
						if dist <= 105 then
							if dist <= 34 then
								revealed = true
							elseif losChecksLeft > 0 then
								losChecksLeft -= 1
								if hasLineOfSight(playerPos, pos, inst, localChar) then
									revealedEnemyUntil[inst] = now + 2.5
									revealed = true
								end
							end
						end
					end

					-- Allied bodyguard / teammate spotting within 55 studs (blocked by smoke)
					if not revealed and not inSmoke then
						for _, spPos in ipairs(allySpotters) do
							local dx = pos.X - spPos.X
							local dz = pos.Z - spPos.Z
							if (dx * dx + dz * dz) <= (55 * 55) then
								revealed = true
								break
							end
						end
					end

					if revealed then
						local u, v = worldToUV(pos.X, pos.Z)
						local vx, vy = uvToViewport(u, v)
						local inBounds = vx >= 0.03 and vx <= 0.97 and vy >= 0.03 and vy <= 0.97
						enemyIdx += 1
						local dot = acquireDot(enemyPool, enemyIdx, overlayWorld, 9, true)
						dot.U = u
						dot.V = v
						dot.Active = true
						local isPriority = isBoss or isHitContract or isPenthouseUnit
						dot.BaseSize = if isPriority then 8 else 6
						dot.BaseStroke = if isPriority then 1.5 else 1.1
						local ePx = scaledPx(dot.BaseSize)
						dot.Frame.Size = UDim2.fromOffset(ePx, ePx)
						dot.Frame.BackgroundColor3 = if isHitContract then C_ENEMY_HIGH else C_ENEMY
						dot.Stroke.Color = if isPriority then C_GOLD else Color3.fromRGB(14, 16, 22)
						dot.Stroke.Thickness = scaledStroke(dot.BaseStroke)
						dot.Frame.Position = UDim2.fromScale(u, v)
						dot.Frame.Visible = inBounds
					end
				end
			end
		end
	end

	-- Hide unused pooled markers
	for i = allyIdx + 1, #allyPool do
		allyPool[i].Active = false
		allyPool[i].Frame.Visible = false
	end
	for i = enemyIdx + 1, #enemyPool do
		enemyPool[i].Active = false
		enemyPool[i].Frame.Visible = false
	end

	-- Update Carrying Crate warehouse objective marker (existing game mechanic!)
	if crateWarehouseMarker then
		local carrying = localPlayer:GetAttribute("CarryingCrate")
		local foundPlotPos: Vector3? = nil
		if typeof(carrying) == "string" and typeof(localBaseSlot) == "string" then
			for _, plot in ipairs(CollectionService:GetTagged("WarehousePlot")) do
				if plot:IsA("Model") and plot:GetAttribute("BaseSlot") == localBaseSlot and plot:GetAttribute("Category") == carrying then
					foundPlotPos = plot:GetPivot().Position
					break
				end
			end
		end
		crateWarehousePos = foundPlotPos
		if foundPlotPos then
			local u, v = worldToUV(foundPlotPos.X, foundPlotPos.Z)
			local vx, vy = uvToViewport(u, v)
			crateWarehouseMarker.Position = UDim2.fromScale(u, v)
			crateWarehouseMarker.Visible = vx >= 0.03 and vx <= 0.97 and vy >= 0.03 and vy <= 0.97
		else
			crateWarehouseMarker.Visible = false
		end
	end
end

-- ============================================================================
-- WAYPOINT ROUTE BEAM, LIVE DISTANCE & OFF-SCREEN EDGE INDICATOR
-- ============================================================================

local function updateWaypointVisuals(playerPos: Vector3?, now: number): ()
	local wpPos = activeWaypointPos
	if not wpPos then
		if routeLine then routeLine.Visible = false end
		if edgeArrowFrame then edgeArrowFrame.Visible = false end
		if gpsPinBtn then gpsPinBtn.Visible = false end
		return
	end

	local wu, wv = worldToUV(wpPos.X, wpPos.Z)
	local wvx, wvy = uvToViewport(wu, wv)
	local wpVisibleInView = wvx >= 0.04 and wvx <= 0.96 and wvy >= 0.04 and wvy <= 0.96

	if gpsPinBtn then
		gpsPinBtn.Position = UDim2.fromScale(wu, wv)
		gpsPinBtn.Visible = wpVisibleInView
	end
	if gpsPinPulse and wpVisibleInView then
		local pulse = 0.5 + 0.5 * math.sin(now * 5.2)
		local sz = math.max(8, math.floor((13 + pulse * 7) * currentMarkerScale + 0.5))
		gpsPinPulse.Size = UDim2.fromOffset(sz, sz)
		if gpsPinPulseCorner then
			gpsPinPulseCorner.CornerRadius = UDim.new(0, math.ceil(sz * 0.5))
		end
		gpsPinPulse.BackgroundTransparency = 0.55 + pulse * 0.35
	end

	-- Distance & bearing readout in bottom GPS bar
	if playerPos then
		local dx = wpPos.X - playerPos.X
		local dz = wpPos.Z - playerPos.Z
		local dist = math.floor(math.sqrt(dx * dx + dz * dz) + 0.5)
		local bearing = getCardinalBearing(dx, dz)

		if gpsDistLabel and (dist ~= lastRenderedDist or bearing ~= lastRenderedBearing) then
			lastRenderedDist = dist
			lastRenderedBearing = bearing
			gpsDistLabel.Text = string.format("%dm %s", dist, bearing)
			gpsDistLabel.Visible = true
		end

		-- Clipped tactical bearing beam from player to waypoint inside MapOverlayClip
		if routeLine then
			local pu, pv = worldToUV(playerPos.X, playerPos.Z)
			local pvx, pvy = uvToViewport(pu, pv)
			local ok, cx0, cy0, cx1, cy1 = clipSegmentToBox(pvx, pvy, wvx, wvy, 0.02, 0.98)
			if ok then
				local liveVp = math.max(96, currentViewportSize)
				local sx = (cx1 - cx0) * liveVp
				local sy = (cy1 - cy0) * liveVp
				local segLen = math.sqrt(sx * sx + sy * sy)
				if segLen >= 8 then
					local lineThick = math.max(2, math.floor(1.6 + 0.55 * currentMarkerScale + 0.5))
					routeLine.Position = UDim2.fromScale((cx0 + cx1) * 0.5, (cy0 + cy1) * 0.5)
					routeLine.Size = UDim2.fromOffset(math.floor(segLen), lineThick)
					routeLine.Rotation = math.deg(math.atan2(sy, sx))
					routeLine.Visible = true
				else
					routeLine.Visible = false
				end
			else
				routeLine.Visible = false
			end
		end

		-- Edge-clamped directional indicator whenever waypoint is outside zoomed viewport
		if edgeArrowFrame and edgeArrowIcon and edgeDistLabel then
			if not wpVisibleInView then
				local dirX = wvx - 0.5
				local dirY = wvy - 0.5
				local maxAxis = math.max(math.abs(dirX), math.abs(dirY), 0.001)
				local clampedX = 0.5 + (dirX / maxAxis) * 0.40
				local clampedY = 0.5 + (dirY / maxAxis) * 0.40
				edgeArrowFrame.Position = UDim2.fromScale(clampedX, clampedY)
				edgeArrowIcon.Rotation = math.deg(math.atan2(dirX, -dirY))
				edgeDistLabel.Text = " " .. tostring(dist) .. "m "
				edgeArrowFrame.Visible = true
			else
				edgeArrowFrame.Visible = false
			end
		end
	else
		if routeLine then routeLine.Visible = false end
		if edgeArrowFrame then edgeArrowFrame.Visible = false end
	end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function disconnectAll(): ()
	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	table.clear(connections)
end

function MinimapController.Init(parentGui: ScreenGui): ()
	disconnectAll()
	table.clear(allyPool)
	table.clear(enemyPool)
	table.clear(pingRings)
	table.clear(baseMarkers)
	table.clear(baseStrokes)
	table.clear(baseStrokeBases)
	table.clear(baseSpawnMarkers)
	table.clear(baseSpawnStrokes)
	table.clear(baseSpawnStrokeBases)
	table.clear(turfMarkers)
	table.clear(turfStrokes)
	table.clear(turfStrokeBases)
	table.clear(shipmentBayMarkers)
	table.clear(shipmentBayEntries)
	table.clear(scaledMarkers)
	table.clear(detailSubLabels)
	table.clear(cardinalTicks)
	table.clear(intercardinalTicks)
	table.clear(bezelTicks)
	table.clear(resizeGripBars)

	hostScreenGui = parentGui
	activePreset = "Standard"
	isCustomSize = false
	preferredViewportSize = BASE_VIEWPORT_SIZE
	currentViewportSize = BASE_VIEWPORT_SIZE
	targetViewportSize = BASE_VIEWPORT_SIZE
	currentMarkerScale = 1.0
	currentScaleBarPx = 28
	currentRightMargin = 14
	targetRightMargin = 14
	currentBottomMargin = 14
	targetBottomMargin = 14
	lastAppliedViewportSize = -1
	lastAppliedMarginX = -1
	lastAppliedMarginY = -1
	lastPublishedFrameW = -1
	lastPublishedFrameH = -1
	lastPublishedBottom = -1
	lastPublishedRight = -1
	resizePulse = 0
	resizeToastExpiresAt = 0
	isHoveringResizeGrip = false
	isResizing = false
	didDragResize = false
	lastGripTapAt = 0

	currentZoom = 1.0
	targetZoom = 1.0
	viewCenterU = 0.5
	viewCenterV = 0.5
	targetCenterU = 0.5
	targetCenterV = 0.5
	followPlayer = true
	lastAppliedZoom = -1
	lastAppliedU = -1
	lastAppliedV = -1
	lastDetailEffectivePx = -1
	lastRenderedZone = ""
	isPointerDown = false
	didDragPan = false
	expressObjPos = nil
	crateWarehousePos = nil
	bistroStrokeBase = 1.3
	penthouseStrokeBase = 1.3
	nwIntercardinalTick = nil

	local existing = parentGui:FindFirstChild("IslandMinimap")
	if existing then
		existing:Destroy()
	end

	local initMetrics = computeChromeMetrics(BASE_VIEWPORT_SIZE)

	-- Outer dark military tactical container (retains identity & noir brass border, anchored bottom-right)
	local frame = Instance.new("Frame")
	frame.Name = "IslandMinimap"
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -14, 1, -14)
	frame.Size = UDim2.fromOffset(initMetrics.FrameW, initMetrics.FrameH)
	frame.BackgroundColor3 = C_FRAME_BG
	frame.BackgroundTransparency = 0.04
	frame.Parent = parentGui
	islandFrame = frame
	islandFrameCorner = makeCorner(frame, initMetrics.CornerR)
	islandFrameStroke = makeStroke(frame, C_GOLD_DIM, 1.3, Enum.ApplyStrokeMode.Border)

	-- Subtle Top-Left Corner Drag-Resize Grip (drags upward/leftward from fixed bottom-right anchor!)
	local grip = Instance.new("TextButton")
	grip.Name = "ResizeGrip"
	grip.Position = UDim2.fromOffset(0, 0)
	grip.Size = UDim2.fromOffset(18, 18)
	grip.BackgroundTransparency = 1
	grip.BorderSizePixel = 0
	grip.AutoButtonColor = false
	grip.Text = ""
	grip.ZIndex = 22
	grip.Parent = frame
	resizeGripBtn = grip

	-- Geometric L-corner brass bracket + diagonal micro-pip (pure UI frames -> zero missing glyph boxes!)
	local function addGripBar(x: number, y: number, w: number, h: number): Frame
		local bar = Instance.new("Frame")
		bar.Position = UDim2.fromOffset(x, y)
		bar.Size = UDim2.fromOffset(w, h)
		bar.BackgroundColor3 = C_GOLD_DIM
		bar.BackgroundTransparency = 0.25
		bar.BorderSizePixel = 0
		bar.Active = false
		bar.ZIndex = 23
		bar.Parent = grip
		table.insert(resizeGripBars, bar)
		return bar
	end
	addGripBar(3, 3, 7, 2) -- Top horizontal arm
	addGripBar(3, 3, 2, 7) -- Left vertical arm
	addGripBar(6, 6, 2, 2) -- Subtle inner diagonal grip dot

	local function refreshGripVisual(): ()
		local col = if isResizing then C_CYAN elseif isHoveringResizeGrip then C_GOLD else C_GOLD_DIM
		local transp = if isResizing or isHoveringResizeGrip then 0.0 else 0.25
		for _, bar in ipairs(resizeGripBars) do
			bar.BackgroundColor3 = col
			bar.BackgroundTransparency = transp
		end
	end

	grip.MouseEnter:Connect(function()
		isHoveringResizeGrip = true
		refreshGripVisual()
		showHoverTip("Drag corner to resize  •  Double-click to reset")
	end)
	grip.MouseLeave:Connect(function()
		isHoveringResizeGrip = false
		refreshGripVisual()
		if not isResizing then
			showHoverTip(nil)
		end
	end)
	table.insert(
		connections,
		grip.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				isResizing = true
				didDragResize = false
				isPointerDown = false
				didDragPan = false
				resizeStartScreen = Vector2.new(input.Position.X, input.Position.Y)
				resizeStartVp = currentViewportSize
				cachedBounds = computeResponsiveBounds()
				resizePulse = 1.0
				refreshGripVisual()
				updateSizeToggleChrome()
			end
		end)
	)

	-- Header Bar: "TACTICAL MAP" + Responsive UIListLayout Zoom, Follow & Size Controls
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, initMetrics.HeaderH)
	header.BackgroundTransparency = 1
	header.Parent = frame
	headerFrame = header

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.new(0, 14, 0, 0)
	title.Size = UDim2.new(1, -118, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = "TACTICAL MAP"
	title.TextSize = 9
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextColor3 = C_GOLD
	title.Parent = header
	titleLabel = title

	local controlsRow = Instance.new("Frame")
	controlsRow.Name = "ControlsRow"
	controlsRow.AnchorPoint = Vector2.new(1, 0)
	controlsRow.Position = UDim2.new(1, -initMetrics.Pad, 0, 0)
	controlsRow.Size = UDim2.new(0, 102, 1, 0)
	controlsRow.BackgroundTransparency = 1
	controlsRow.Parent = header
	headerControlsRow = controlsRow

	local ctrlLayout = Instance.new("UIListLayout")
	ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
	ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	ctrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	ctrlLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ctrlLayout.Padding = UDim.new(0, 2)
	ctrlLayout.Parent = controlsRow
	headerControlsLayout = ctrlLayout

	local function makeHeaderBtn(
		layoutOrder: number,
		width: number,
		text: string,
		tip: string,
		onClick: () -> (),
		strokeCol: Color3?,
		onRightClick: (() -> ())?
	): (TextButton, UIStroke)
		local b = Instance.new("TextButton")
		b.LayoutOrder = layoutOrder
		b.Size = UDim2.fromOffset(width, 15)
		b.BackgroundColor3 = Color3.fromRGB(24, 29, 39)
		b.AutoButtonColor = false
		b.Font = Enum.Font.GothamBlack
		b.Text = text
		b.TextSize = 9
		b.TextColor3 = Color3.fromRGB(224, 226, 232)
		b.Parent = controlsRow
		makeCorner(b, 3)
		local st = makeStroke(b, strokeCol or Color3.fromRGB(56, 64, 80), 0.9, Enum.ApplyStrokeMode.Border)
		b.MouseEnter:Connect(function()
			b.BackgroundColor3 = Color3.fromRGB(36, 44, 58)
			showHoverTip(tip)
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundColor3 = Color3.fromRGB(24, 29, 39)
			showHoverTip(nil)
		end)
		b.MouseButton1Click:Connect(function()
			AudioController.PlayClick()
			onClick()
		end)
		if onRightClick then
			b.MouseButton2Click:Connect(function()
				AudioController.PlayClick()
				onRightClick()
			end)
		end
		return b, st
	end

	-- Header controls left-to-right: [−] [1.0x] [+] [◎] [M]
	zoomOutBtn = makeHeaderBtn(1, 15, "−", "Zoom Out (Scroll Down)", function()
		setTargetZoom(targetZoom - ZOOM_STEP)
	end)
	zoomReadoutBtn = makeHeaderBtn(2, 26, "1.0x", "Reset Zoom (1.0x)", function()
		setTargetZoom(1.0)
	end)
	zoomInBtn = makeHeaderBtn(3, 15, "+", "Zoom In (Scroll Up)", function()
		setTargetZoom(targetZoom + ZOOM_STEP)
	end)
	followBtn = makeHeaderBtn(4, 16, "◎", "Center on Player", function()
		followPlayer = true
		if lastPlayerWorldPos and targetZoom > 1.02 then
			local pu, pv = worldToUV(lastPlayerWorldPos.X, lastPlayerWorldPos.Z)
			targetCenterU, targetCenterV = clampViewCenter(pu, pv, targetZoom)
		else
			targetCenterU, targetCenterV = 0.5, 0.5
		end
		updateZoomChrome()
	end)
	local sBtn, sSt = makeHeaderBtn(
		5,
		17,
		"M",
		"Resize Map S/M/L  ([ / ] or drag corner)",
		function()
			cycleMinimapSizeInternal(1)
		end,
		C_GOLD_DIM,
		function()
			cycleMinimapSizeInternal(-1)
		end
	)
	sBtn.Name = "SizeToggleBtn"
	sBtn.TextColor3 = Color3.fromRGB(234, 226, 200)
	sizeToggleBtn = sBtn
	sizeToggleStroke = sSt

	-- =========================================================================
	-- MAP VIEWPORT (STRICTLY 1:1 SQUARE, ACTIVE TO CAPTURE WHEEL ZOOM CLEANLY)
	-- =========================================================================
	local viewport = Instance.new("Frame")
	viewport.Name = "MapViewport"
	viewport.Position = UDim2.fromOffset(initMetrics.Pad, initMetrics.HeaderH + 1)
	viewport.Size = UDim2.fromOffset(initMetrics.ViewportPx, initMetrics.ViewportPx)
	viewport.BackgroundColor3 = C_OCEAN
	viewport.BorderSizePixel = 0
	viewport.ClipsDescendants = true
	viewport.Active = true
	viewport.Parent = frame
	mapViewportCorner = makeCorner(viewport, initMetrics.ViewportCornerR)
	makeStroke(viewport, Color3.fromRGB(46, 56, 70), 1.0, Enum.ApplyStrokeMode.Border)
	mapViewport = viewport

	-- Layer 1: CanvasGroup-clipped World Geography (clips all +-45° highways & rounded corners cleanly!)
	local geoClip = Instance.new("CanvasGroup")
	geoClip.Name = "MapGeoClip"
	geoClip.Size = UDim2.fromScale(1, 1)
	geoClip.BackgroundTransparency = 1
	geoClip.BorderSizePixel = 0
	geoClip.ZIndex = 1
	geoClip.Parent = viewport
	geoClipCorner = makeCorner(geoClip, initMetrics.ViewportCornerR)
	local geoAspect = Instance.new("UIAspectRatioConstraint")
	geoAspect.AspectRatio = 1
	geoAspect.DominantAxis = Enum.DominantAxis.Width
	geoAspect.Parent = geoClip

	local gWorld = Instance.new("Frame")
	gWorld.Name = "GeoWorld"
	gWorld.AnchorPoint = Vector2.new(0.5, 0.5)
	gWorld.Position = UDim2.fromScale(0.5, 0.5)
	gWorld.Size = UDim2.fromScale(1, 1)
	gWorld.BackgroundTransparency = 1
	gWorld.BorderSizePixel = 0
	gWorld.Parent = geoClip
	geoWorld = gWorld

	buildWorldGeography(gWorld)

	-- Layer 2: Crisp Interactive Tactical Overlay (exact shared transform, never raster-blurred!)
	local overlayClip = Instance.new("Frame")
	overlayClip.Name = "MapOverlayClip"
	overlayClip.Size = UDim2.fromScale(1, 1)
	overlayClip.BackgroundTransparency = 1
	overlayClip.ClipsDescendants = true
	overlayClip.ZIndex = 3
	overlayClip.Parent = viewport
	local ovAspect = Instance.new("UIAspectRatioConstraint")
	ovAspect.AspectRatio = 1
	ovAspect.DominantAxis = Enum.DominantAxis.Width
	ovAspect.Parent = overlayClip

	-- Background click/drag target inside overlayClip (below interactive buttons)
	local clickCanvas = Instance.new("TextButton")
	clickCanvas.Name = "MapCanvas"
	clickCanvas.Size = UDim2.fromScale(1, 1)
	clickCanvas.BackgroundTransparency = 1
	clickCanvas.Text = ""
	clickCanvas.AutoButtonColor = false
	clickCanvas.ZIndex = 1
	clickCanvas.Parent = overlayClip

	local oWorld = Instance.new("Frame")
	oWorld.Name = "OverlayWorld"
	oWorld.AnchorPoint = Vector2.new(0.5, 0.5)
	oWorld.Position = UDim2.fromScale(0.5, 0.5)
	oWorld.Size = UDim2.fromScale(1, 1)
	oWorld.BackgroundTransparency = 1
	oWorld.BorderSizePixel = 0
	oWorld.ZIndex = 2
	oWorld.Parent = overlayClip
	overlayWorld = oWorld

	-- Viewport-space clipped route bearing line (from player -> waypoint)
	local rLine = Instance.new("Frame")
	rLine.Name = "WaypointRouteLine"
	rLine.AnchorPoint = Vector2.new(0.5, 0.5)
	rLine.Size = UDim2.fromOffset(0, 2)
	rLine.BackgroundColor3 = C_CYAN
	rLine.BackgroundTransparency = 0.25
	rLine.BorderSizePixel = 0
	rLine.Visible = false
	rLine.ZIndex = 6
	rLine.Parent = overlayClip
	routeLine = rLine

	-- =========================================================================
	-- STATIC & LIVE-SYNCED TACTICAL MARKERS (INSIDE OverlayWorld)
	-- =========================================================================

	-- 52 Urban Territory Block Tiles & Mini Outpost Diamonds (exact TurfConfig PlazaPos + live faction sync)
	for _, blockId in ipairs(TurfConfig.BlockOrder) do
		local spec = TurfConfig.Blocks[blockId]
		if spec then
			local initCol = TurfConfig.ResolveFactionColor(spec.InitialOwner)
			local isMini = spec.IsMiniOutpost == true
			local sz = if spec.IsHQ then 9 elseif isMini then 5 else 7
			local baseStroke = if isMini then 0.9 else 1.0
			local baseCorner = if isMini then 1 else 2
			local tile = Instance.new("TextButton")
			tile.Name = "TurfTile_" .. blockId
			tile.AnchorPoint = Vector2.new(0.5, 0.5)
			tile.Position = worldToScale(spec.PlazaPos.X, spec.PlazaPos.Z)
			tile.Size = UDim2.fromOffset(sz, sz)
			tile.Rotation = if isMini then 45 else 0
			tile.BackgroundColor3 = initCol
			tile.BorderSizePixel = 0
			tile.AutoButtonColor = false
			tile.Font = Enum.Font.GothamBlack
			tile.Text = if spec.IsHQ then "★" else ""
			tile.TextSize = 7
			tile.TextColor3 = Color3.new(1, 1, 1)
			tile.ZIndex = if isMini then 4 else 3
			tile.Parent = oWorld
			local tileCorner = makeCorner(tile, baseCorner)

			local st = makeStroke(tile, Color3.fromRGB(14, 18, 26), baseStroke, Enum.ApplyStrokeMode.Border)
			registerScaledMarker(
				tile,
				tileCorner,
				st,
				sz,
				sz,
				if spec.IsHQ then 7 else nil,
				baseCorner,
				baseStroke,
				false
			)

			-- Adaptive HQ ShortCode micro-label (smoothly fades in on Large view or when zoomed!)
			if spec.IsHQ and typeof(spec.ShortCode) == "string" and spec.ShortCode ~= "" then
				local placeAbove = spec.PlazaPos.Z < 0
				addDetailSubLabel(tile, spec.ShortCode, placeAbove, 7, 240, 300, Color3.fromRGB(242, 232, 200), 0.14)
			end

			tile.MouseEnter:Connect(function()
				local suffix = if spec.IsHQ then " [HQ]" elseif isMini then " [OUTPOST]" else ""
				showHoverTip(spec.DisplayName .. suffix)
			end)
			tile.MouseLeave:Connect(function()
				showHoverTip(nil)
			end)
			tile.MouseButton1Click:Connect(function()
				setMapDestination(spec.PlazaPos.X, spec.PlazaPos.Z, spec.DisplayName)
			end)

			turfMarkers[blockId] = tile
			turfStrokes[blockId] = st
			turfStrokeBases[blockId] = baseStroke
		end
	end

	-- Dedicated Spawn Point Icons (4 real BaseSpawn locations, live-synced when streamed in)
	for _, b in ipairs(MinimapMapData.Bases) do
		local sp = Instance.new("TextButton")
		sp.Name = "Spawn_" .. b.Slot
		sp.AnchorPoint = Vector2.new(0.5, 0.5)
		sp.Position = worldToScale(b.SpawnX, b.SpawnZ)
		sp.Size = UDim2.fromOffset(6, 6)
		sp.BackgroundColor3 = Color3.fromRGB(22, 28, 38)
		sp.BorderSizePixel = 0
		sp.AutoButtonColor = false
		sp.Font = Enum.Font.GothamBlack
		sp.Text = "+"
		sp.TextSize = 7
		sp.TextColor3 = Color3.fromRGB(236, 240, 248)
		sp.ZIndex = 6
		sp.Parent = oWorld
		local spCorner = makeCorner(sp, 3)

		local spSt = makeStroke(sp, SectorConfig.FactionColors[b.Slot] or C_GOLD, 1.0, Enum.ApplyStrokeMode.Border)
		registerScaledMarker(sp, spCorner, spSt, 6, 6, 7, 3, 1.0, true)
		sp.MouseEnter:Connect(function()
			showHoverTip(b.Slot .. " Base Spawn")
		end)
		sp.MouseLeave:Connect(function()
			showHoverTip(nil)
		end)
		sp.MouseButton1Click:Connect(function()
			setMapDestination(b.SpawnX, b.SpawnZ, b.Slot .. " Base Spawn")
		end)

		baseSpawnMarkers[b.Slot] = sp
		baseSpawnStrokes[b.Slot] = spSt
		baseSpawnStrokeBases[b.Slot] = 1.0
	end

	-- 4 Central Shipment Bay Objective Indicators (active when Arrived / EnRoute)
	local bayCoords = {
		Fish = Vector3.new(66, 2, 66),
		Vegetable = Vector3.new(-66, 2, -66),
		Meat = Vector3.new(66, 2, -66),
		Fruit = Vector3.new(-66, 2, 66),
	}
	for cat, pos in pairs(bayCoords) do
		local bayBtn = Instance.new("TextButton")
		bayBtn.Name = "ShipmentBay_" .. cat
		bayBtn.AnchorPoint = Vector2.new(0.5, 0.5)
		bayBtn.Position = worldToScale(pos.X, pos.Z)
		bayBtn.Size = UDim2.fromOffset(6, 6)
		bayBtn.BackgroundColor3 = Color3.fromRGB(92, 108, 128)
		bayBtn.BackgroundTransparency = 0.25
		bayBtn.BorderSizePixel = 0
		bayBtn.Text = ""
		bayBtn.AutoButtonColor = false
		bayBtn.ZIndex = 4
		bayBtn.Parent = oWorld
		local bayCorner = makeCorner(bayBtn, 2)
		local bayStroke = makeStroke(bayBtn, Color3.fromRGB(14, 18, 26), 1.0, Enum.ApplyStrokeMode.Border)
		local bayEntry = registerScaledMarker(bayBtn, bayCorner, bayStroke, 6, 6, nil, 2, 1.0, false)
		shipmentBayEntries[cat] = bayEntry
		local spec = WarehouseConfig.Specs[cat :: WarehouseConfig.WarehouseCategory]
		local bayTitle = if spec then (spec.ShipmentName .. " (Central Park)") else (cat .. " Shipment Bay")
		bayBtn.MouseEnter:Connect(function()
			showHoverTip(bayTitle)
		end)
		bayBtn.MouseLeave:Connect(function()
			showHoverTip(nil)
		end)
		bayBtn.MouseButton1Click:Connect(function()
			setMapDestination(pos.X, pos.Z, bayTitle)
		end)
		shipmentBayMarkers[cat] = bayBtn
	end

	-- Important Central Landmarks: Central Park Bistro & Penthouse Heist Compound
	local bp = MinimapMapData.CentralParkBranchPos
	local bBtn, bSt = addLandmarkBadge(
		oWorld,
		bp.X,
		bp.Z,
		9,
		9,
		Color3.fromRGB(36, 114, 72),
		Color3.fromRGB(246, 232, 176),
		"B",
		"Central Park Bistro",
		4,
		7
	)
	bistroMarker = bBtn
	bistroStroke = bSt

	local pp = MinimapMapData.PenthouseCompoundPos
	local pBtn, pSt = addLandmarkBadge(
		oWorld,
		pp.X,
		pp.Z,
		10,
		10,
		Color3.fromRGB(82, 24, 34),
		C_GOLD,
		"H",
		"Crimson Don Penthouse",
		4,
		7
	)
	penthouseMarker = pBtn
	penthouseStroke = pSt

	-- Primary Landmarks: Central HUB, Black Market, and 4 Player Bases (N/S/E/W)
	local hubBtn = addLandmarkBadge(
		oWorld,
		0,
		0,
		24,
		13,
		Color3.fromRGB(214, 194, 148),
		Color3.fromRGB(16, 20, 28),
		"HUB",
		"Central Market HUB",
		5,
		9
	)
	addDetailSubLabel(hubBtn, "MARKET", true, 7, 300, 380, C_GOLD, 0.16)

	local bmBtn = Instance.new("TextButton")
	bmBtn.Name = "Marker_BM"
	bmBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	bmBtn.Position = worldToScale(bmWorldX, bmWorldZ)
	bmBtn.Size = UDim2.fromOffset(19, 13)
	bmBtn.BackgroundColor3 = Color3.fromRGB(184, 30, 56)
	bmBtn.BorderSizePixel = 0
	bmBtn.AutoButtonColor = false
	bmBtn.Font = Enum.Font.GothamBlack
	bmBtn.Text = "BM"
	bmBtn.TextSize = 9
	bmBtn.TextColor3 = Color3.new(1, 1, 1)
	bmBtn.ZIndex = 5
	bmBtn.Parent = oWorld
	local bmCorner = makeCorner(bmBtn, 4)
	local bmSt = makeStroke(bmBtn, Color3.fromRGB(12, 16, 24), 1.3, Enum.ApplyStrokeMode.Border)
	registerScaledMarker(bmBtn, bmCorner, bmSt, 19, 13, 9, 4, 1.3, false)
	bmBtn.MouseEnter:Connect(function()
		showHoverTip("Black Market Outpost")
	end)
	bmBtn.MouseLeave:Connect(function()
		showHoverTip(nil)
	end)
	bmBtn.MouseButton1Click:Connect(function()
		setMapDestination(bmWorldX, bmWorldZ, "Black Market Outpost")
	end)
	bmMarkerBtn = bmBtn

	for _, b in ipairs(MinimapMapData.Bases) do
		local fCol = SectorConfig.FactionColors[b.Slot] or C_GOLD
		local btn, st = addLandmarkBadge(
			oWorld,
			b.HQX,
			b.HQZ,
			13,
			13,
			fCol,
			Color3.new(1, 1, 1),
			b.Short,
			b.FullName,
			5,
			9
		)
		baseMarkers[b.Slot] = btn
		baseStrokes[b.Slot] = st
		baseStrokeBases[b.Slot] = 1.2
	end

	-- Dedicated Active Objective Markers (Express Delivery & Carrying Crate Warehouse)
	local expObj = Instance.new("TextButton")
	expObj.Name = "ExpressObjective"
	expObj.AnchorPoint = Vector2.new(0.5, 0.5)
	expObj.Size = UDim2.fromOffset(10, 10)
	expObj.BackgroundColor3 = C_OBJECTIVE
	expObj.BorderSizePixel = 0
	expObj.AutoButtonColor = false
	expObj.Text = ""
	expObj.Rotation = 45
	expObj.Visible = false
	expObj.ZIndex = 7
	expObj.Parent = oWorld
	local expSt = makeStroke(expObj, Color3.fromRGB(16, 18, 26), 1.5, Enum.ApplyStrokeMode.Border)
	registerScaledMarker(expObj, nil, expSt, 10, 10, nil, nil, 1.5, false)
	expObj.MouseEnter:Connect(function()
		showHoverTip("Express Delivery Drop-Off")
	end)
	expObj.MouseLeave:Connect(function()
		showHoverTip(nil)
	end)
	expObj.MouseButton1Click:Connect(function()
		if expressObjPos then
			setMapDestination(expressObjPos.X, expressObjPos.Z, "Express Drop-Off")
		end
	end)
	expressObjMarker = expObj

	local whObj = Instance.new("TextButton")
	whObj.Name = "WarehouseObjective"
	whObj.AnchorPoint = Vector2.new(0.5, 0.5)
	whObj.Size = UDim2.fromOffset(9, 9)
	whObj.BackgroundColor3 = Color3.fromRGB(76, 232, 144)
	whObj.BorderSizePixel = 0
	whObj.AutoButtonColor = false
	whObj.Text = ""
	whObj.Rotation = 45
	whObj.Visible = false
	whObj.ZIndex = 7
	whObj.Parent = oWorld
	local whSt = makeStroke(whObj, Color3.new(1, 1, 1), 1.3, Enum.ApplyStrokeMode.Border)
	registerScaledMarker(whObj, nil, whSt, 9, 9, nil, nil, 1.3, false)
	whObj.MouseEnter:Connect(function()
		showHoverTip("Crate Warehouse Drop-Off")
	end)
	whObj.MouseLeave:Connect(function()
		showHoverTip(nil)
	end)
	whObj.MouseButton1Click:Connect(function()
		if crateWarehousePos then
			setMapDestination(crateWarehousePos.X, crateWarehousePos.Z, "Crate Warehouse")
		end
	end)
	crateWarehouseMarker = whObj

	-- Custom GPS Waypoint Pin (clickable to remove directly!)
	local pinBtn = Instance.new("TextButton")
	pinBtn.Name = "GPSPin"
	pinBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	pinBtn.Size = UDim2.fromOffset(12, 12)
	pinBtn.BackgroundColor3 = C_CYAN
	pinBtn.BorderSizePixel = 0
	pinBtn.Text = ""
	pinBtn.AutoButtonColor = false
	pinBtn.Visible = false
	pinBtn.ZIndex = 10
	pinBtn.Parent = oWorld
	gpsPinCorner = makeCorner(pinBtn, 6)
	gpsPinStroke = makeStroke(pinBtn, Color3.new(1, 1, 1), 1.8, Enum.ApplyStrokeMode.Border)

	local pinCore = Instance.new("Frame")
	pinCore.AnchorPoint = Vector2.new(0.5, 0.5)
	pinCore.Position = UDim2.fromScale(0.5, 0.5)
	pinCore.Size = UDim2.fromOffset(4, 4)
	pinCore.BackgroundColor3 = Color3.fromRGB(12, 18, 28)
	pinCore.BorderSizePixel = 0
	pinCore.ZIndex = 11
	pinCore.Parent = pinBtn
	gpsPinCore = pinCore
	gpsPinCoreCorner = makeCorner(pinCore, 2)

	local pinPulse = Instance.new("Frame")
	pinPulse.Name = "PulseRing"
	pinPulse.AnchorPoint = Vector2.new(0.5, 0.5)
	pinPulse.Position = UDim2.fromScale(0.5, 0.5)
	pinPulse.Size = UDim2.fromOffset(18, 18)
	pinPulse.BackgroundColor3 = C_CYAN
	pinPulse.BackgroundTransparency = 0.72
	pinPulse.BorderSizePixel = 0
	pinPulse.ZIndex = 9
	pinPulse.Parent = pinBtn
	gpsPinPulseCorner = makeCorner(pinPulse, 12)
	gpsPinPulse = pinPulse

	pinBtn.MouseEnter:Connect(function()
		showHoverTip((activeWaypointLabel or "Waypoint") .. " (Click to clear)")
	end)
	pinBtn.MouseLeave:Connect(function()
		showHoverTip(nil)
	end)
	pinBtn.MouseButton1Click:Connect(function()
		AudioController.PlayClick()
		WaypointController.ClearCustomWaypoint()
	end)
	gpsPinBtn = pinBtn

	-- Local Player Rotating Directional Triangle
	local pInd, pRefs = buildPlayerTriangle(oWorld)
	playerIndicator = pInd
	playerRefs = pRefs

	-- =========================================================================
	-- LAYER 3: FIXED VIEWPORT TACTICAL CHROME (COMPASS TICKS, EDGE ARROW, SCALE)
	-- =========================================================================
	local chrome = Instance.new("Frame")
	chrome.Name = "ViewportChrome"
	chrome.Size = UDim2.fromScale(1, 1)
	chrome.BackgroundTransparency = 1
	chrome.ZIndex = 15
	chrome.Parent = viewport

	-- Subtle perimeter compass ticks (N/S/E/W)
	local function addCompassTick(anchor: Vector2, pos: UDim2, letter: string, col: Color3): TextLabel
		local lbl = Instance.new("TextLabel")
		lbl.AnchorPoint = anchor
		lbl.Position = pos
		lbl.Size = UDim2.fromOffset(12, 10)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.Text = letter
		lbl.TextSize = 8
		lbl.TextColor3 = col
		lbl.TextTransparency = 0.25
		lbl.ZIndex = 15
		lbl.Parent = chrome
		table.insert(cardinalTicks, lbl)
		return lbl
	end
	addCompassTick(Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 1), "N", C_GOLD)
	addCompassTick(Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -1), "S", C_TEXT_MUTED)
	addCompassTick(Vector2.new(1, 0.5), UDim2.new(1, -1, 0.5, 0), "E", C_TEXT_MUTED)
	addCompassTick(Vector2.new(0, 0.5), UDim2.new(0, 1, 0.5, 0), "W", C_TEXT_MUTED)

	-- Adaptive intercardinal compass ticks (fade in smoothly when enlarged!)
	local function addIntercardinalTick(anchor: Vector2, pos: UDim2, letter: string): TextLabel
		local lbl = Instance.new("TextLabel")
		lbl.AnchorPoint = anchor
		lbl.Position = pos
		lbl.Size = UDim2.fromOffset(18, 10)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.Text = letter
		lbl.TextSize = 7
		lbl.TextColor3 = C_TEXT_MUTED
		lbl.TextTransparency = 1
		lbl.Visible = false
		lbl.ZIndex = 15
		lbl.Parent = chrome
		table.insert(intercardinalTicks, lbl)
		return lbl
	end
	nwIntercardinalTick = addIntercardinalTick(Vector2.new(0, 0), UDim2.new(0, 4, 0, 2), "NW")
	addIntercardinalTick(Vector2.new(1, 0), UDim2.new(1, -4, 0, 2), "NE")
	addIntercardinalTick(Vector2.new(0, 1), UDim2.new(0, 4, 1, -2), "SW")
	addIntercardinalTick(Vector2.new(1, 1), UDim2.new(1, -4, 1, -18), "SE")

	-- Subtle perimeter radar reticle ticks (fade in cleanly on Large minimap!)
	local bezelDefs = {
		{ Pos = UDim2.new(0.25, 0, 0, 0), Size = UDim2.fromOffset(1, 4), Anchor = Vector2.new(0.5, 0) },
		{ Pos = UDim2.new(0.75, 0, 0, 0), Size = UDim2.fromOffset(1, 4), Anchor = Vector2.new(0.5, 0) },
		{ Pos = UDim2.new(0.25, 0, 1, 0), Size = UDim2.fromOffset(1, 4), Anchor = Vector2.new(0.5, 1) },
		{ Pos = UDim2.new(0.75, 0, 1, 0), Size = UDim2.fromOffset(1, 4), Anchor = Vector2.new(0.5, 1) },
		{ Pos = UDim2.new(0, 0, 0.25, 0), Size = UDim2.fromOffset(4, 1), Anchor = Vector2.new(0, 0.5) },
		{ Pos = UDim2.new(0, 0, 0.75, 0), Size = UDim2.fromOffset(4, 1), Anchor = Vector2.new(0, 0.5) },
		{ Pos = UDim2.new(1, 0, 0.25, 0), Size = UDim2.fromOffset(4, 1), Anchor = Vector2.new(1, 0.5) },
		{ Pos = UDim2.new(1, 0, 0.75, 0), Size = UDim2.fromOffset(4, 1), Anchor = Vector2.new(1, 0.5) },
	}
	for _, td in ipairs(bezelDefs) do
		local t = Instance.new("Frame")
		t.AnchorPoint = td.Anchor
		t.Position = td.Pos
		t.Size = td.Size
		t.BackgroundColor3 = C_GOLD_DIM
		t.BackgroundTransparency = 1
		t.BorderSizePixel = 0
		t.Visible = false
		t.ZIndex = 15
		t.Parent = chrome
		table.insert(bezelTicks, t)
	end

	-- Subtle military scale bar in bottom-right corner of viewport
	local scaleBar = Instance.new("Frame")
	scaleBar.Name = "ScaleBar"
	scaleBar.AnchorPoint = Vector2.new(1, 1)
	scaleBar.Position = UDim2.new(1, -5, 1, -4)
	scaleBar.Size = UDim2.fromOffset(32, 11)
	scaleBar.BackgroundTransparency = 1
	scaleBar.ZIndex = 15
	scaleBar.Parent = chrome
	scaleBarFrame = scaleBar

	local scaleLine = Instance.new("Frame")
	scaleLine.AnchorPoint = Vector2.new(0.5, 1)
	scaleLine.Position = UDim2.fromScale(0.5, 1)
	scaleLine.Size = UDim2.fromOffset(28, 2)
	scaleLine.BackgroundColor3 = Color3.fromRGB(186, 194, 208)
	scaleLine.BackgroundTransparency = 0.35
	scaleLine.BorderSizePixel = 0
	scaleLine.Parent = scaleBar
	scaleLineFrame = scaleLine

	local sLbl = Instance.new("TextLabel")
	sLbl.Size = UDim2.new(1, 0, 0, 9)
	sLbl.BackgroundTransparency = 1
	sLbl.Font = Enum.Font.GothamBold
	sLbl.Text = "320m"
	sLbl.TextSize = 7
	sLbl.TextColor3 = Color3.fromRGB(196, 204, 218)
	sLbl.TextTransparency = 0.2
	sLbl.Parent = scaleBar
	scaleBarLabel = sLbl

	-- Compact hover tooltip chip (top-left of viewport, width-constrained so it never overflows!)
	local tip = Instance.new("TextLabel")
	tip.Name = "HoverTip"
	tip.Position = UDim2.fromOffset(4, 4)
	tip.AutomaticSize = Enum.AutomaticSize.X
	tip.Size = UDim2.fromOffset(0, 14)
	tip.BackgroundColor3 = Color3.fromRGB(12, 15, 22)
	tip.BackgroundTransparency = 0.1
	tip.Font = Enum.Font.GothamBold
	tip.Text = ""
	tip.TextSize = 8
	tip.TextTruncate = Enum.TextTruncate.AtEnd
	tip.TextColor3 = Color3.fromRGB(236, 234, 226)
	tip.Visible = false
	tip.ZIndex = 18
	tip.Parent = chrome
	makeCorner(tip, 3)
	makeStroke(tip, C_GOLD_DIM, 0.9, Enum.ApplyStrokeMode.Border)
	local tipConstraint = Instance.new("UISizeConstraint")
	tipConstraint.MaxSize = Vector2.new(176, 24)
	tipConstraint.Parent = tip
	hoverTipLabel = tip
	hoverTipConstraint = tipConstraint

	-- Subtle transient size-change feedback badge (shown briefly when switching sizes or dragging)
	local rToast = Instance.new("TextLabel")
	rToast.Name = "ResizeToast"
	rToast.Position = UDim2.fromOffset(4, 4)
	rToast.AutomaticSize = Enum.AutomaticSize.X
	rToast.Size = UDim2.fromOffset(0, 15)
	rToast.BackgroundColor3 = Color3.fromRGB(14, 19, 28)
	rToast.BackgroundTransparency = 0.08
	rToast.Font = Enum.Font.GothamBlack
	rToast.Text = ""
	rToast.TextSize = 8
	rToast.TextColor3 = C_GOLD
	rToast.Visible = false
	rToast.ZIndex = 19
	rToast.Parent = chrome
	makeCorner(rToast, 3)
	makeStroke(rToast, C_GOLD, 1.0, Enum.ApplyStrokeMode.Border)
	resizeToastLabel = rToast

	-- Off-Screen Edge-Clamped Directional Waypoint Indicator
	local edgeWrap = Instance.new("Frame")
	edgeWrap.Name = "OffscreenWaypointIndicator"
	edgeWrap.AnchorPoint = Vector2.new(0.5, 0.5)
	edgeWrap.Size = UDim2.fromOffset(26, 22)
	edgeWrap.BackgroundTransparency = 1
	edgeWrap.Visible = false
	edgeWrap.ZIndex = 16
	edgeWrap.Parent = chrome

	local eIcon = Instance.new("TextLabel")
	eIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	eIcon.Position = UDim2.fromScale(0.5, 0.36)
	eIcon.Size = UDim2.fromOffset(14, 14)
	eIcon.BackgroundTransparency = 1
	eIcon.Font = Enum.Font.GothamBlack
	eIcon.Text = "▲"
	eIcon.TextSize = 12
	eIcon.TextColor3 = C_CYAN
	eIcon.ZIndex = 17
	eIcon.Parent = edgeWrap
	local eStroke = Instance.new("UIStroke")
	eStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	eStroke.Color = Color3.fromRGB(10, 14, 20)
	eStroke.Thickness = 1.8
	eStroke.Parent = eIcon
	edgeArrowStroke = eStroke

	local eDist = Instance.new("TextLabel")
	eDist.AnchorPoint = Vector2.new(0.5, 1)
	eDist.Position = UDim2.fromScale(0.5, 1.05)
	eDist.AutomaticSize = Enum.AutomaticSize.X
	eDist.Size = UDim2.fromOffset(0, 10)
	eDist.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
	eDist.BackgroundTransparency = 0.15
	eDist.Font = Enum.Font.GothamBlack
	eDist.Text = ""
	eDist.TextSize = 7
	eDist.TextColor3 = C_CYAN
	eDist.ZIndex = 17
	eDist.Parent = edgeWrap
	makeCorner(eDist, 3)

	edgeArrowFrame = edgeWrap
	edgeArrowIcon = eIcon
	edgeDistLabel = eDist

	-- =========================================================================
	-- INTERACTION: RESIZE DRAG/KEYS, WAYPOINT CLICK, DRAG PAN, SCROLL ZOOM, RMB CLEAR
	-- =========================================================================
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then
				return
			end
			if input.KeyCode == Enum.KeyCode.RightBracket then
				AudioController.PlayClick()
				local curTier = resolveNearestPreset(targetViewportSize)
				if curTier == "Compact" then
					setMinimapSizePresetInternal("Standard", true)
				elseif curTier == "Standard" then
					setMinimapSizePresetInternal("Large", true)
				else
					-- Already Large: gently step up toward max safe viewport if room remains
					local bounds = computeResponsiveBounds()
					cachedBounds = bounds
					if targetViewportSize < bounds.MaxViewport - 6 then
						isCustomSize = true
						preferredViewportSize = math.min(bounds.MaxViewport, targetViewportSize + 36)
						targetViewportSize = preferredViewportSize
						resizePulse = 1.0
						showResizeToast(string.format("EXPANDED  •  %dpx", math.floor(targetViewportSize + 0.5)), 1.15)
						updateSizeToggleChrome()
					end
				end
			elseif input.KeyCode == Enum.KeyCode.LeftBracket then
				AudioController.PlayClick()
				local curTier = resolveNearestPreset(targetViewportSize)
				if targetViewportSize > PRESET_VIEWPORT_SIZES.Large + 12 then
					setMinimapSizePresetInternal("Large", true)
				elseif curTier == "Large" then
					setMinimapSizePresetInternal("Standard", true)
				else
					setMinimapSizePresetInternal("Compact", true)
				end
			end
		end)
	)

	table.insert(
		connections,
		clickCanvas.InputBegan:Connect(function(input: InputObject)
			if isResizing then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				isPointerDown = true
				didDragPan = false
				dragStartScreen = Vector2.new(input.Position.X, input.Position.Y)
				dragStartCenterU = targetCenterU
				dragStartCenterV = targetCenterV
			end
		end)
	)

	table.insert(
		connections,
		viewport.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton2 and activeWaypointPos then
				AudioController.PlayClick()
				WaypointController.ClearCustomWaypoint()
			end
		end)
	)

	table.insert(
		connections,
		viewport.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				local delta = input.Position.Z
				if delta > 0 then
					setTargetZoom(targetZoom + ZOOM_STEP)
				elseif delta < 0 then
					setTargetZoom(targetZoom - ZOOM_STEP)
				end
			end
		end)
	)

	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			-- Priority 1: Live diagonal corner drag-resizing (1:1 aspect ratio locked!)
			if isResizing then
				local curPos = Vector2.new(input.Position.X, input.Position.Y)
				local delta = curPos - resizeStartScreen
				if not didDragResize and delta.Magnitude > 3 then
					didDragResize = true
				end
				if didDragResize then
					local hudScale = getHudScale()
					-- Bottom-right is anchored: dragging left (-X) or up (-Y) grows the square map
					local diagDelta = ((-delta.X) + (-delta.Y)) * 0.5 / hudScale
					local newVp = math.clamp(resizeStartVp + diagDelta, cachedBounds.MinViewport, cachedBounds.MaxViewport)
					preferredViewportSize = newVp
					targetViewportSize = newVp
					isCustomSize = true
					activePreset = resolveNearestPreset(newVp)
					showResizeToast(string.format("RESIZE  •  %dpx", math.floor(newVp + 0.5)), 0.85)
					updateSizeToggleChrome()
				end
				return
			end

			-- Priority 2: Map pan when zoomed in
			if not isPointerDown then
				return
			end
			if targetZoom <= 1.03 or not mapViewport then
				return
			end
			local curPos = Vector2.new(input.Position.X, input.Position.Y)
			local delta = curPos - dragStartScreen
			if not didDragPan and delta.Magnitude > 6 then
				didDragPan = true
				followPlayer = false
			end
			if didDragPan then
				local vpSize = mapViewport.AbsoluteSize
				if vpSize.X > 1 and vpSize.Y > 1 then
					local du = -delta.X / (vpSize.X * currentZoom)
					local dv = -delta.Y / (vpSize.Y * currentZoom)
					targetCenterU, targetCenterV = clampViewCenter(dragStartCenterU + du, dragStartCenterV + dv, targetZoom)
					updateZoomChrome()
				end
			end
		end)
	)

	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			if isResizing then
				local wasDrag = didDragResize
				isResizing = false
				didDragResize = false
				refreshGripVisual()

				if not wasDrag then
					local now = os.clock()
					if (now - lastGripTapAt) <= 0.35 then
						lastGripTapAt = 0
						AudioController.PlayClick()
						setMinimapSizePresetInternal("Standard", true)
					else
						lastGripTapAt = now
						showResizeToast("DRAG CORNER TO RESIZE", 0.95)
					end
				else
					-- Gentle magnetic snap when released very close to a named preset
					local snappedPreset: MinimapSizePreset? = nil
					for _, presetName in ipairs(PRESET_ORDER) do
						local presetVp = math.clamp(
							PRESET_VIEWPORT_SIZES[presetName],
							cachedBounds.MinViewport,
							cachedBounds.MaxViewport
						)
						if math.abs(targetViewportSize - presetVp) <= PRESET_SNAP_THRESHOLD then
							snappedPreset = presetName
							break
						end
					end
					if snappedPreset then
						setMinimapSizePresetInternal(snappedPreset, true)
					else
						activePreset = resolveNearestPreset(targetViewportSize)
						resizePulse = 0.75
						showResizeToast(string.format("CUSTOM  •  %dpx", math.floor(targetViewportSize + 0.5)), 1.0)
						updateSizeToggleChrome()
					end
				end
				return
			end

			if not isPointerDown then
				return
			end
			local wasDrag = didDragPan
			isPointerDown = false
			didDragPan = false

			if not wasDrag and mapViewport then
				local vpPos = mapViewport.AbsolutePosition
				local vpSize = mapViewport.AbsoluteSize
				if vpSize.X > 1 and vpSize.Y > 1 then
					local vx = (input.Position.X - vpPos.X) / vpSize.X
					local vy = (input.Position.Y - vpPos.Y) / vpSize.Y
					if vx >= 0 and vx <= 1 and vy >= 0 and vy <= 1 then
						local u = viewCenterU + (vx - 0.5) / currentZoom
						local v = viewCenterV + (vy - 0.5) / currentZoom
						if u >= 0 and u <= 1 and v >= 0 and v <= 1 then
							local wx, wz = uvToWorld(u, v)
							setMapDestination(wx, wz, "Map Pin")
						end
					end
				end
			end
		end)
	)

	-- =========================================================================
	-- BOTTOM GPS WAYPOINT STATUS, LIVE DISTANCE, ZONE READOUT & CLEAR STRIP
	-- =========================================================================
	local statusBar = Instance.new("Frame")
	statusBar.Name = "GPSStatusBar"
	statusBar.Position = UDim2.new(0, initMetrics.Pad, 1, -(initMetrics.GapBot + initMetrics.StatusH))
	statusBar.Size = UDim2.new(1, -(initMetrics.Pad * 2), 0, initMetrics.StatusH)
	statusBar.BackgroundColor3 = C_STATUS_BG
	statusBar.Parent = frame
	statusBarFrame = statusBar
	statusBarCorner = makeCorner(statusBar, 4)
	makeStroke(statusBar, Color3.fromRGB(38, 44, 56), 0.9, Enum.ApplyStrokeMode.Border)

	local stLbl = Instance.new("TextLabel")
	stLbl.Position = UDim2.new(0, 6, 0, 0)
	stLbl.Size = UDim2.new(1, -12, 1, 0)
	stLbl.BackgroundTransparency = 1
	stLbl.Font = Enum.Font.GothamBold
	stLbl.Text = "Click map to set waypoint"
	stLbl.TextSize = 9
	stLbl.TextXAlignment = Enum.TextXAlignment.Left
	stLbl.TextColor3 = C_TEXT_MUTED
	stLbl.TextTruncate = Enum.TextTruncate.AtEnd
	stLbl.Parent = statusBar
	gpsStatusLabel = stLbl

	local zLbl = Instance.new("TextLabel")
	zLbl.Name = "ZoneReadout"
	zLbl.AnchorPoint = Vector2.new(1, 0)
	zLbl.Position = UDim2.new(1, -6, 0, 0)
	zLbl.Size = UDim2.new(0, 96, 1, 0)
	zLbl.BackgroundTransparency = 1
	zLbl.Font = Enum.Font.GothamBlack
	zLbl.Text = ""
	zLbl.TextSize = 8
	zLbl.TextXAlignment = Enum.TextXAlignment.Right
	zLbl.TextColor3 = C_GOLD
	zLbl.TextTruncate = Enum.TextTruncate.AtEnd
	zLbl.Visible = false
	zLbl.Parent = statusBar
	zoneReadoutLabel = zLbl

	local dLbl = Instance.new("TextLabel")
	dLbl.AnchorPoint = Vector2.new(1, 0)
	dLbl.Position = UDim2.new(1, -23, 0, 0)
	dLbl.Size = UDim2.new(0, 52, 1, 0)
	dLbl.BackgroundTransparency = 1
	dLbl.Font = Enum.Font.GothamBlack
	dLbl.Text = ""
	dLbl.TextSize = 9
	dLbl.TextXAlignment = Enum.TextXAlignment.Right
	dLbl.TextColor3 = C_CYAN
	dLbl.Visible = false
	dLbl.Parent = statusBar
	gpsDistLabel = dLbl

	local clr = Instance.new("TextButton")
	clr.AnchorPoint = Vector2.new(1, 0.5)
	clr.Position = UDim2.new(1, -2, 0.5, 0)
	clr.Size = UDim2.fromOffset(18, 16)
	clr.BackgroundColor3 = Color3.fromRGB(142, 30, 38)
	clr.Font = Enum.Font.GothamBlack
	clr.Text = "X"
	clr.TextSize = 9
	clr.TextColor3 = Color3.fromRGB(240, 238, 232)
	clr.Visible = false
	clr.Parent = statusBar
	makeCorner(clr, 3)
	clr.MouseButton1Click:Connect(function()
		AudioController.PlayClick()
		WaypointController.ClearCustomWaypoint()
	end)
	clearPinBtn = clr

	-- Sync WaypointController callback
	local function applyWaypointState(pos: Vector3?, label: string?): ()
		activeWaypointPos = pos
		activeWaypointLabel = label
		lastRenderedDist = -1
		lastRenderedBearing = ""
		updateStatusBarContentLayout()
		if not pos then
			if gpsPinBtn then gpsPinBtn.Visible = false end
			if routeLine then routeLine.Visible = false end
			if edgeArrowFrame then edgeArrowFrame.Visible = false end
		end
	end

	WaypointController.OnCustomWaypointChanged(applyWaypointState)
	local initWpPos, initWpLbl = WaypointController.GetCustomWaypoint()
	applyWaypointState(initWpPos, initWpLbl)

	-- Responsive listeners: adapt automatically to resolution, aspect ratio, HUD scale & hotbar width changes!
	table.insert(
		connections,
		parentGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			refreshResponsiveLayout(false)
		end)
	)
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		table.insert(
			connections,
			playerGui:GetAttributeChangedSignal("FoodEmpireHUDScale"):Connect(function()
				refreshResponsiveLayout(false)
			end)
		)
		table.insert(
			connections,
			playerGui:GetAttributeChangedSignal("FoodEmpireHotbarHalfW"):Connect(function()
				refreshResponsiveLayout(false)
			end)
		)
	end

	-- Subscribe once to existing Combat Threat Bus (gunshots / explosions reveal enemies!)
	if not threatBusBound then
		threatBusBound = true
		AudioController.OnCombatThreat(function(worldPos: Vector3, threatKind: string)
			if threatKind == "SuppressedShot" or threatKind == "MeleeSwing" then
				return
			end
			-- Ignore gunfire pings caused by the local player firing at their own position
			if
				lastPlayerWorldPos
				and (worldPos - lastPlayerWorldPos).Magnitude < 8
				and threatKind ~= "Explosion"
				and threatKind ~= "PlayerHit"
			then
				return
			end
			table.insert(recentThreats, {
				Pos = worldPos,
				ExpiresAt = os.clock() + 5.5,
			})
			if #recentThreats > 24 then
				table.remove(recentThreats, 1)
			end
			if threatKind ~= "PlayerHit" then
				spawnRadarPing(worldPos, C_ENEMY)
			end
		end)
	end

	syncLiveStreamedLandmarks()
	refreshResponsiveLayout(true)
	applyWorldTransform(true)
	task.defer(function()
		if islandFrame and islandFrame.Parent then
			refreshResponsiveLayout(true)
		end
	end)

	-- =========================================================================
	-- MAIN HEARTBEAT LOOP (SMOOTH RESIZE + ZOOM/PAN + PLAYER ROTATION + RADAR)
	-- =========================================================================
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			local now = os.clock()
			local clampedDt = math.min(dt, 0.1)

			-- Smooth animated resizing & responsive anchor transitions
			local resizeSpeed = if isResizing then 30 else 13
			local rAlpha = 1 - math.exp(-clampedDt * resizeSpeed)
			if math.abs(targetViewportSize - currentViewportSize) > 0.12 then
				currentViewportSize += (targetViewportSize - currentViewportSize) * rAlpha
				if math.abs(targetViewportSize - currentViewportSize) <= 0.15 then
					currentViewportSize = targetViewportSize
				end
			else
				currentViewportSize = targetViewportSize
			end
			if math.abs(targetRightMargin - currentRightMargin) > 0.12 then
				currentRightMargin += (targetRightMargin - currentRightMargin) * rAlpha
				if math.abs(targetRightMargin - currentRightMargin) <= 0.15 then
					currentRightMargin = targetRightMargin
				end
			else
				currentRightMargin = targetRightMargin
			end
			if math.abs(targetBottomMargin - currentBottomMargin) > 0.12 then
				currentBottomMargin += (targetBottomMargin - currentBottomMargin) * rAlpha
				if math.abs(targetBottomMargin - currentBottomMargin) <= 0.15 then
					currentBottomMargin = targetBottomMargin
				end
			else
				currentBottomMargin = targetBottomMargin
			end
			applyMinimapLayout(false)

			-- Subtle border brass highlight pulse during resize transitions
			if islandFrameStroke then
				if isResizing then
					islandFrameStroke.Color = C_GOLD:Lerp(C_CYAN, 0.45)
					resizePulse = 0.85
				elseif resizePulse > 0.005 then
					resizePulse = math.max(0, resizePulse - clampedDt * 2.4)
					islandFrameStroke.Color = C_GOLD_DIM:Lerp(C_GOLD, resizePulse)
				else
					islandFrameStroke.Color = C_GOLD_DIM
				end
			end

			-- Smooth fade-out for transient resize badge toast
			if resizeToastLabel and resizeToastLabel.Visible and not isResizing then
				local rem = resizeToastExpiresAt - now
				if rem <= 0 then
					resizeToastLabel.Visible = false
					updateCornerTickOcclusion()
				elseif rem < 0.28 then
					local fadeFrac = math.clamp(1 - (rem / 0.28), 0, 1)
					resizeToastLabel.TextTransparency = fadeFrac
					resizeToastLabel.BackgroundTransparency = 0.08 + fadeFrac * 0.92
					local st = resizeToastLabel:FindFirstChildOfClass("UIStroke")
					if st then
						st.Transparency = fadeFrac
					end
				end
			end

			local char = Players.LocalPlayer.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
			local playerPos: Vector3? = nil

			if root and root:IsA("BasePart") then
				playerPos = root.Position
				lastPlayerWorldPos = playerPos

				-- Follow player smoothly when zoomed in & follow mode is enabled
				if followPlayer and targetZoom > 1.02 then
					local pu, pv = worldToUV(playerPos.X, playerPos.Z)
					targetCenterU, targetCenterV = clampViewCenter(pu, pv, targetZoom)
				end
			end

			-- Smooth zoom & pan interpolation (exponential smoothing)
			local alpha = 1 - math.exp(-clampedDt * 12)
			currentZoom += (targetZoom - currentZoom) * alpha
			if math.abs(targetZoom - currentZoom) < 0.002 then
				currentZoom = targetZoom
			end
			local clampedTU, clampedTV = clampViewCenter(targetCenterU, targetCenterV, currentZoom)
			viewCenterU += (clampedTU - viewCenterU) * alpha
			viewCenterV += (clampedTV - viewCenterV) * alpha
			viewCenterU, viewCenterV = clampViewCenter(viewCenterU, viewCenterV, currentZoom)
			applyWorldTransform(false)

			-- Update player directional triangle position & exact facing rotation
			if playerPos and root and root:IsA("BasePart") and playerIndicator then
				local pu, pv = worldToUV(playerPos.X, playerPos.Z)
				local pvx, pvy = uvToViewport(pu, pv)
				local inView = pvx >= 0.03 and pvx <= 0.97 and pvy >= 0.03 and pvy <= 0.97
				playerIndicator.Position = UDim2.fromScale(pu, pv)
				local look = root.CFrame.LookVector
				-- North is -Z (0 deg), East is +X (+90 deg)
				playerIndicator.Rotation = math.deg(math.atan2(look.X, -look.Z))
				playerIndicator.Visible = inView
			end

			-- Update waypoint bearing line, live distance & off-screen edge chevron
			updateWaypointVisuals(playerPos, now)

			-- Animate expanding combat radar ping rings (proportionally scaled!)
			for i = #pingRings, 1, -1 do
				local ring = pingRings[i]
				local age = now - ring.StartedAt
				if age >= ring.Duration or not ring.Frame.Parent then
					if ring.Frame.Parent then
						ring.Frame:Destroy()
					end
					table.remove(pingRings, i)
				else
					local frac = age / ring.Duration
					local px = math.max(4, math.floor((6 + frac * 22) * currentMarkerScale + 0.5))
					ring.Frame.Size = UDim2.fromOffset(px, px)
					ring.Stroke.Thickness = scaledStroke(1.5)
					ring.Stroke.Transparency = math.clamp(0.15 + frac * 0.85, 0, 1)
				end
			end

			-- Throttled teammate & detected-enemy radar scan + live zone readout (5 Hz -> zero frame spikes!)
			if now - lastRadarScanAt >= 0.20 then
				lastRadarScanAt = now
				scanTacticalEntities(now)
				if playerPos then
					local nextZone = resolvePlayerZoneName(playerPos)
					if nextZone ~= lastRenderedZone then
						lastRenderedZone = nextZone
						if zoneReadoutLabel then
							zoneReadoutLabel.Text = nextZone
						end
						updateStatusBarContentLayout()
					end
				end
			end

			-- Low-frequency streamed landmark position verification (every 2.5s)
			if now - lastLiveSyncAt >= 2.5 then
				lastLiveSyncAt = now
				syncLiveStreamedLandmarks()
			end
		end)
	)
end

-- ============================================================================
-- STATE SYNCHRONIZATION (REUSES EXISTING SERVER STATE PAYLOAD!)
-- ============================================================================

function MinimapController.Update(state: { [string]: any }): ()
	local slot = state.BaseSlot
	if typeof(slot) == "string" then
		localBaseSlot = slot
	end
	local localFaction = "Player_" .. tostring(Players.LocalPlayer.UserId)

	-- Highlight local player's claimed Base & active Spawn Point
	for _, b in ipairs(MinimapMapData.Bases) do
		local st = baseStrokes[b.Slot]
		local spSt = baseSpawnStrokes[b.Slot]
		local isMine = (typeof(slot) == "string" and b.Slot == slot)
		if st then
			local baseThick = if isMine then 1.8 else 1.2
			baseStrokeBases[b.Slot] = baseThick
			st.Color = if isMine then C_GOLD else Color3.fromRGB(12, 16, 24)
			st.Thickness = scaledStroke(baseThick)
		end
		if spSt then
			local spThick = if isMine then 1.4 else 1.0
			baseSpawnStrokeBases[b.Slot] = spThick
			spSt.Color = if isMine then Color3.new(1, 1, 1) else (SectorConfig.FactionColors[b.Slot] or C_GOLD_DIM)
			spSt.Thickness = scaledStroke(spThick)
		end
	end

	-- Sync all 52 Urban Territory Blocks to controlling faction Base Color & raid status
	table.clear(underAttackBlocks)
	local turf = state.Turf
	if typeof(turf) == "table" and typeof(turf.Blocks) == "table" then
		for blockId, tile in pairs(turfMarkers) do
			local b = turf.Blocks[blockId]
			if typeof(b) == "table" then
				local st = turfStrokes[blockId]
				local spec = TurfConfig.Blocks[blockId]
				local defaultThick = if spec and spec.IsMiniOutpost == true then 0.9 else 1.0
				local isRaidOnMine = (b.Owner == localFaction) and (b.UnderAttack == true or b.Status == "Contested")
				if isRaidOnMine then
					underAttackBlocks[blockId] = true
				end
				if b.Status == "Contested" then
					tile.BackgroundColor3 = TurfConfig.ContestedColor
					if st then
						turfStrokeBases[blockId] = 1.6
						st.Color = Color3.new(1, 1, 1)
						st.Thickness = scaledStroke(1.6)
					end
				else
					local r = tonumber(b.ColorR) or 160
					local g = tonumber(b.ColorG) or 160
					local bl = tonumber(b.ColorB) or 160
					tile.BackgroundColor3 = Color3.fromRGB(r, g, bl)
					if st then
						if b.UnderAttack == true then
							turfStrokeBases[blockId] = 1.8
							st.Color = Color3.fromRGB(255, 82, 86)
							st.Thickness = scaledStroke(1.8)
						else
							turfStrokeBases[blockId] = defaultThick
							st.Color = Color3.fromRGB(14, 18, 26)
							st.Thickness = scaledStroke(defaultThick)
						end
					end
				end
			end
		end
	end

	-- Sync 4 Central Shipment Bay Objective Indicators
	local shipments = state.Shipments
	if typeof(shipments) == "table" then
		for _, sh in pairs(shipments) do
			if typeof(sh) == "table" and typeof(sh.Category) == "string" then
				local bay = shipmentBayMarkers[sh.Category]
				local entry = shipmentBayEntries[sh.Category]
				if bay then
					local baseSz: number
					if sh.Phase == "Arrived" then
						bay.BackgroundColor3 = C_CYAN
						bay.BackgroundTransparency = 0
						baseSz = 8
					elseif sh.Phase == "EnRoute" then
						bay.BackgroundColor3 = C_OBJECTIVE
						bay.BackgroundTransparency = 0.05
						baseSz = 7
					else
						bay.BackgroundColor3 = Color3.fromRGB(82, 94, 112)
						bay.BackgroundTransparency = 0.4
						baseSz = 5
					end
					if entry then
						entry.BaseW = baseSz
						entry.BaseH = baseSz
					end
					local px = scaledPx(baseSz)
					bay.Size = UDim2.fromOffset(px, px)
				end
			end
		end
	end

	-- Sync Express Delivery Active Objective Icon
	local express = state.ExpressDelivery
	if expressObjMarker then
		if
			typeof(express) == "table"
			and express.Status == "Active"
			and typeof(express.DropX) == "number"
			and typeof(express.DropZ) == "number"
		then
			expressObjPos = Vector3.new(express.DropX, 4, express.DropZ)
			local u, v = worldToUV(express.DropX, express.DropZ)
			local vx, vy = uvToViewport(u, v)
			expressObjMarker.Position = UDim2.fromScale(u, v)
			expressObjMarker.Visible = vx >= 0.03 and vx <= 0.97 and vy >= 0.03 and vy <= 0.97
		else
			expressObjPos = nil
			expressObjMarker.Visible = false
		end
	end

	-- Sync Central Park Bistro & Penthouse Heist Status
	local bistro = state.CentralParkBranch
	if bistroMarker and bistroStroke and typeof(bistro) == "table" then
		if bistro.ShakedownActive == true then
			bistroMarker.BackgroundColor3 = C_ENEMY
			bistroStroke.Color = C_GOLD
			bistroStrokeBase = 1.6
		elseif bistro.Owned == true then
			bistroMarker.BackgroundColor3 = Color3.fromRGB(46, 168, 98)
			bistroStroke.Color = C_GOLD
			bistroStrokeBase = 1.3
		else
			bistroMarker.BackgroundColor3 = Color3.fromRGB(36, 102, 68)
			bistroStroke.Color = Color3.fromRGB(14, 18, 26)
			bistroStrokeBase = 1.0
		end
		bistroStroke.Thickness = scaledStroke(bistroStrokeBase)
	end

	local heist = state.PenthouseHeist
	if penthouseMarker and penthouseStroke and typeof(heist) == "table" then
		local active = (tonumber(heist.Stage) or 0) > 0
		penthouseMarker.BackgroundColor3 = if active then C_ENEMY else Color3.fromRGB(82, 24, 34)
		penthouseStroke.Color = if active then C_GOLD else Color3.fromRGB(14, 18, 26)
		penthouseStrokeBase = if active then 1.6 else 1.0
		penthouseStroke.Thickness = scaledStroke(penthouseStrokeBase)
	end
end

-- ============================================================================
-- PUBLIC RESIZING API
-- ============================================================================

function MinimapController.SetSizePreset(preset: MinimapSizePreset): ()
	if PRESET_VIEWPORT_SIZES[preset] then
		setMinimapSizePresetInternal(preset, true)
	end
end

function MinimapController.CycleSize(step: number?): ()
	cycleMinimapSizeInternal(step)
end

function MinimapController.SetCustomViewportSize(viewportPx: number): ()
	local bounds = computeResponsiveBounds()
	cachedBounds = bounds
	isCustomSize = true
	preferredViewportSize = math.clamp(viewportPx, bounds.MinViewport, bounds.MaxViewport)
	targetViewportSize = preferredViewportSize
	activePreset = resolveNearestPreset(targetViewportSize)
	resizePulse = 1.0
	updateSizeToggleChrome()
end

function MinimapController.GetSizeState(): MinimapSizeState
	local m = computeChromeMetrics(currentViewportSize)
	return {
		Preset = resolveNearestPreset(targetViewportSize),
		ViewportSize = m.ViewportPx,
		FrameWidth = m.FrameW,
		FrameHeight = m.FrameH,
		MinViewport = cachedBounds.MinViewport,
		MaxViewport = cachedBounds.MaxViewport,
		IsCustom = isCustomSize,
	}
end

return MinimapController
