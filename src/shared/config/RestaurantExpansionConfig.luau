--!strict

-- RestaurantExpansionConfig: Reusable Level 1-10 physical restaurant expansion
-- templates, footprint boundaries, seating capacities, and kitchen capacities.
-- Designed for the expanded 336x288 Grand Castle Base (WarehousePlots shifted to Z=-90).
-- Airy grand ceilings: Floor 1 top = Y 0.80 | Floor 2 top = Y 22.20 (1.4-stud deck) | Floor 3 top = Y 43.60 (1.4-stud deck).
-- Every seat Y sits +2.95 studs above its floor so customer feet NEVER clip through ceilings!

export type ExpansionDiningSpot = {
	Space: "HQ" | "Base",
	Zone: "Indoor" | "EastWing" | "WestWing" | "RearAtrium" | "SecondFloor" | "ThirdFloor" | "VIP" | "Patio",
	Floor: number,
	MinLevel: number,
	TableOffset: Vector3,
	PlateOffset: Vector3,
	SeatOffset: Vector3,
	WaiterOffset: Vector3,
	IsVIP: boolean,
}

export type ExpansionTierSpec = {
	Tier: number,
	DisplayName: string,
	Subtitle: string,
	Summary: string,
	FrontPavilionName: string,
	FrontPavilionSummary: string,
	WidthStuds: number,
	HeightStuds: number,
	DepthStuds: number,
	Floors: number,
	MaxCustomers: number,
	KitchenReadyCapacity: number,
	MaxConcurrentOrders: number,
	RecommendedMaxCrew: number,
}

export type SafeBoundsSpec = {
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
	MaxY: number,
}

local RestaurantExpansionConfig = {}

-- Strict safe envelope inside the expanded 336x288 Grand Base Estate (HQ local space):
-- * Expanded Base walls: X = +/-168, Z = -156..+132
-- * Shifted WarehousePlots: Z <= -90 -> keep HQ Z >= -80 (10+ studs service avenue clear!)
-- * FrontDiningPlaza Pergolas: Z >= +52 -> keep HQ Z <= +36 (16+ studs courtyard clear!)
RestaurantExpansionConfig.SAFE_BOUNDS = {
	MinX = -156,
	MaxX = 156,
	MinZ = -82.0,
	MaxZ = 38.0,
	MaxY = 132.0,
} :: SafeBoundsSpec

RestaurantExpansionConfig.MAX_PHYSICAL_TIER = 15

RestaurantExpansionConfig.TIERS = {
	[1] = {
		Tier = 1,
		DisplayName = "Grand Starter Bistro",
		Subtitle = "LEVEL 1  •  AIRY STARTER BISTRO & TIMBER PERGOLA",
		Summary = "Tall 21-stud dining hall, open kitchen & Twin Starter Wood Pergola Terraces out front.",
		FrontPavilionName = "Open Timber Pergola Deck",
		FrontPavilionSummary = "Starter cedar plank terraces with string lights & 8 patio seats.",
		WidthStuds = 86,
		HeightStuds = 26,
		DepthStuds = 56,
		Floors = 1,
		MaxCustomers = 4,
		KitchenReadyCapacity = 5,
		MaxConcurrentOrders = 1,
		RecommendedMaxCrew = 2,
	},
	[2] = {
		Tier = 2,
		DisplayName = "East Conservatory Bistro",
		Subtitle = "LEVEL 2  •  EAST CONSERVATORY & CEDAR ROOF PAVILION",
		Summary = "East Glass Conservatory (+3 HQ tables) + Full Pitched Cedar & Slate Wood Restaurant Roof (+8 front seats)!",
		FrontPavilionName = "Cedar-Roofed Wood Restaurant",
		FrontPavilionSummary = "Pitched cedar & slate roof, warm wood soffits, brass eaves & +4 front wood tables.",
		WidthStuds = 130,
		HeightStuds = 28,
		DepthStuds = 62,
		Floors = 1,
		MaxCustomers = 6,
		KitchenReadyCapacity = 7,
		MaxConcurrentOrders = 1,
		RecommendedMaxCrew = 3,
	},
	[3] = {
		Tier = 3,
		DisplayName = "Two-Story Atrium Bistro",
		Subtitle = "LEVEL 3  •  2ND FLOOR & WOOD HOST COUNTERS",
		Summary = "Rear Staircase Atrium, 2nd-Floor Gallery (+4 tables) & Front Wood Restaurant Host Bars.",
		FrontPavilionName = "Skylight Wood Bistro & Host Bar",
		FrontPavilionSummary = "Frosted skylight roof ridge, wooden host & drink counters & warm hanging lanterns.",
		WidthStuds = 154,
		HeightStuds = 50,
		DepthStuds = 82,
		Floors = 2,
		MaxCustomers = 8,
		KitchenReadyCapacity = 10,
		MaxConcurrentOrders = 2,
		RecommendedMaxCrew = 4,
	},
	[4] = {
		Tier = 4,
		DisplayName = "Modern Culinary Pavilion",
		Subtitle = "LEVEL 4  •  GLASS PAVILION & TIMBER GABLES",
		Summary = "Symmetrical wings, glass portico, wine wall & Timber-Gabled Front Wood Dining Hall.",
		FrontPavilionName = "Gabled Timber Dining Hall",
		FrontPavilionSummary = "Carved cedar gables, planter balustrades & warm brass acoustic eaves.",
		WidthStuds = 168,
		HeightStuds = 54,
		DepthStuds = 86,
		Floors = 2,
		MaxCustomers = 9,
		KitchenReadyCapacity = 12,
		MaxConcurrentOrders = 2,
		RecommendedMaxCrew = 5,
	},
	[5] = {
		Tier = 5,
		DisplayName = "Grand Syndicate Brasserie",
		Subtitle = "LEVEL 5  •  EAST BANQUET & EXPANDED WOOD VERANDAS",
		Summary = "East Banquet Hall (+3 HQ tables) + Twin Covered Side Wood Restaurant Verandas (+6 wood tables, +12 seats)!",
		FrontPavilionName = "Twin Expanded Wood Verandas",
		FrontPavilionSummary = "Expands wood plank decks & pitched cedar roofs outward with +6 new wood tables!",
		WidthStuds = 192,
		HeightStuds = 56,
		DepthStuds = 90,
		Floors = 2,
		MaxCustomers = 11,
		KitchenReadyCapacity = 15,
		MaxConcurrentOrders = 3,
		RecommendedMaxCrew = 6,
	},
	[6] = {
		Tier = 6,
		DisplayName = "Dual-Wing Estate Bistro",
		Subtitle = "LEVEL 6  •  WEST WING & OUTDOOR WOOD GRILL BARS",
		Summary = "West Estate Dining Pavilion (+3 HQ tables) & Smoking Cedar Wood-Fired Grill Bars out front.",
		FrontPavilionName = "Wood-Fired Grill Veranda",
		FrontPavilionSummary = "Adds twin outdoor cedar & stone wood-fired grill bars and warm bistro lighting.",
		WidthStuds = 214,
		HeightStuds = 58,
		DepthStuds = 92,
		Floors = 2,
		MaxCustomers = 12,
		KitchenReadyCapacity = 17,
		MaxConcurrentOrders = 3,
		RecommendedMaxCrew = 6,
	},
	[7] = {
		Tier = 7,
		DisplayName = "Three-Story Sky Terrace",
		Subtitle = "LEVEL 7  •  3RD FLOOR SKY-DECK & LANTERN ARCHES",
		Summary = "Walkable 3rd-Floor Marble Sky-Terrace + Carved Cedar Entry Archways on Front Wood Restaurant.",
		FrontPavilionName = "Lantern-Crowned Timber Veranda",
		FrontPavilionSummary = "Grand cedar entry archways, hanging brass lanterns & lush courtyard planters.",
		WidthStuds = 224,
		HeightStuds = 74,
		DepthStuds = 98,
		Floors = 3,
		MaxCustomers = 14,
		KitchenReadyCapacity = 19,
		MaxConcurrentOrders = 3,
		RecommendedMaxCrew = 6,
	},
	[8] = {
		Tier = 8,
		DisplayName = "Imperial Colonnade Hall",
		Subtitle = "LEVEL 8  •  MARBLE COLONNADES & BRASS TIMBER TRUSSES",
		Summary = "Marble & Brass Colonnades (+3 VIP tables), Crystal Chandelier & Brass-Trimmed Timber Roof Trusses.",
		FrontPavilionName = "Brass-Trussed Timber Pavilion",
		FrontPavilionSummary = "Exposed cedar king-post trusses, brushed brass capitals & VIP patio lighting.",
		WidthStuds = 244,
		HeightStuds = 78,
		DepthStuds = 102,
		Floors = 3,
		MaxCustomers = 15,
		KitchenReadyCapacity = 22,
		MaxConcurrentOrders = 4,
		RecommendedMaxCrew = 7,
	},
	[9] = {
		Tier = 9,
		DisplayName = "Royal Grand Ballroom",
		Subtitle = "LEVEL 9  •  3F BALLROOM & 2-TIER PAGODA WOOD ROOFS",
		Summary = "3rd-Floor Royal Ballroom + 2nd-Tier Clerestory Pagoda Wood Roofs & +6 Outer Veranda Wood Tables!",
		FrontPavilionName = "Two-Tier Pagoda Wood Restaurant",
		FrontPavilionSummary = "Raised clerestory pagoda roofs, illuminated wood marquees & +6 outer wood tables!",
		WidthStuds = 256,
		HeightStuds = 88,
		DepthStuds = 106,
		Floors = 3,
		MaxCustomers = 17,
		KitchenReadyCapacity = 25,
		MaxConcurrentOrders = 4,
		RecommendedMaxCrew = 7,
	},
	[10] = {
		Tier = 10,
		DisplayName = "Food Emperor Imperial Palace",
		Subtitle = "LEVEL 10  •  SKY-ATRIUM DOME & GRAND TIMBER HALL",
		Summary = "268-stud 3-story Imperial Palace with 106-stud Sky-Atrium Dome & Illuminated Timber Marquee Pavilions.",
		FrontPavilionName = "Grand Timber Courtyard Hall",
		FrontPavilionSummary = "Twin illuminated wood restaurant marquees, brass chandeliers & full veranda seating.",
		WidthStuds = 268,
		HeightStuds = 106,
		DepthStuds = 114,
		Floors = 3,
		MaxCustomers = 18,
		KitchenReadyCapacity = 28,
		MaxConcurrentOrders = 4,
		RecommendedMaxCrew = 8,
	},
	[11] = {
		Tier = 11,
		DisplayName = "Grand Imperial Veranda Palace",
		Subtitle = "LEVEL 11  •  OUTER IMPERIAL WINGS & TWIN WOOD ARCADES",
		Summary = "Expands outer Imperial Banquet Arcades (280 studs wide, +4 VIP tables) & Twin Cedar Courtyard Bridges.",
		FrontPavilionName = "Imperial Cedar Arcade Restaurant",
		FrontPavilionSummary = "Connected cedar timber arcades, warm hanging chandeliers & VIP host podiums.",
		WidthStuds = 280,
		HeightStuds = 108,
		DepthStuds = 114,
		Floors = 3,
		MaxCustomers = 20,
		KitchenReadyCapacity = 31,
		MaxConcurrentOrders = 5,
		RecommendedMaxCrew = 8,
	},
	[12] = {
		Tier = 12,
		DisplayName = "Twin Sky-Tower Brasserie",
		Subtitle = "LEVEL 12  •  ROOFTOP SKY-TOWERS & ROYAL WOOD WINGS",
		Summary = "Crowned with Dual 3F Glass Sky-Pavilions + Outer Royal Wood Restaurant Wings (+4 VIP wood tables)!",
		FrontPavilionName = "Royal Three-Bay Wood Pavilion",
		FrontPavilionSummary = "Expands wood restaurant wings out to 157 studs with pitched roofs & +4 VIP wood tables!",
		WidthStuds = 286,
		HeightStuds = 112,
		DepthStuds = 116,
		Floors = 3,
		MaxCustomers = 21,
		KitchenReadyCapacity = 34,
		MaxConcurrentOrders = 5,
		RecommendedMaxCrew = 9,
	},
	[13] = {
		Tier = 13,
		DisplayName = "Gilded Syndicate Palazzo",
		Subtitle = "LEVEL 13  •  GOLDEN FACADE & TEPPANYAKI WOOD ROTUNDAS",
		Summary = "Illuminated Golden Pilaster Colonnades, 3F Sky-Lounge VIPs & Outdoor Cedar Teppanyaki Chef Bars.",
		FrontPavilionName = "Gilded Cedar Teppanyaki Pavilion",
		FrontPavilionSummary = "Gilded cedar gables, live outdoor teppanyaki counters & warm amber lanterns.",
		WidthStuds = 292,
		HeightStuds = 116,
		DepthStuds = 116,
		Floors = 3,
		MaxCustomers = 23,
		KitchenReadyCapacity = 37,
		MaxConcurrentOrders = 5,
		RecommendedMaxCrew = 9,
	},
	[14] = {
		Tier = 14,
		DisplayName = "Four-Spire Culinary Citadel",
		Subtitle = "LEVEL 14  •  FOUR IMPERIAL SPIRES & GRAND WOOD BANQUET",
		Summary = "Four soaring Golden Corner Spire Towers + Full Royal Wood Banquet Pavilions (+2 VIP wood tables)!",
		FrontPavilionName = "Grand Imperial Wood Banquet Hall",
		FrontPavilionSummary = "Twin golden roof finials, ornate cedar rafters & full 44-seat outdoor wood dining!",
		WidthStuds = 298,
		HeightStuds = 122,
		DepthStuds = 118,
		Floors = 3,
		MaxCustomers = 24,
		KitchenReadyCapacity = 40,
		MaxConcurrentOrders = 6,
		RecommendedMaxCrew = 10,
	},
	[15] = {
		Tier = 15,
		DisplayName = "Supreme Food Empire Citadel",
		Subtitle = "LEVEL 15 MAX  •  STRONGEST FOOD EMPIRE IN THE CITY",
		Summary = "Monumental 304-stud Supreme Citadel with 128-stud Golden Crown Beacon & Imperial Wood Restaurant Complex!",
		FrontPavilionName = "Supreme Golden-Roof Wood Empire",
		FrontPavilionSummary = "Gilded multi-tier cedar roofs, golden crest marquees & maximum city customer draw!",
		WidthStuds = 304,
		HeightStuds = 128,
		DepthStuds = 118,
		Floors = 3,
		MaxCustomers = 26,
		KitchenReadyCapacity = 44,
		MaxConcurrentOrders = 6,
		RecommendedMaxCrew = 10,
	},
} :: { [number]: ExpansionTierSpec }

-- Helper to construct a 2-seat dining table pair with strict zero-clipping floor clearance
-- floorY: Floor 1 = 0.80, Floor 2 = 16.70, Floor 3 = 33.10
local function addTablePair(
	list: { ExpansionDiningSpot },
	zone: "Indoor" | "EastWing" | "WestWing" | "RearAtrium" | "SecondFloor" | "ThirdFloor" | "VIP",
	floor: number,
	minLevel: number,
	tx: number,
	floorY: number,
	tz: number,
	isVIP: boolean
): ()
	local tableY = floorY + 3.28
	local plateY = floorY + 3.30
	local seatY = floorY + 2.95 -- Keeps seated customer legs strictly above floorY (zero ceiling poke!)
	local waiterY = floorY + 2.90
	local wX = if tx >= 0 then tx - 4.8 else tx + 4.8
	table.insert(list, {
		Space = "HQ",
		Zone = zone,
		Floor = floor,
		MinLevel = minLevel,
		TableOffset = Vector3.new(tx, tableY, tz),
		PlateOffset = Vector3.new(tx, plateY, tz + 1.35),
		SeatOffset = Vector3.new(tx, seatY, tz + 3.25),
		WaiterOffset = Vector3.new(wX, waiterY, tz + 0.8),
		IsVIP = isVIP,
	})
	table.insert(list, {
		Space = "HQ",
		Zone = zone,
		Floor = floor,
		MinLevel = minLevel,
		TableOffset = Vector3.new(tx, tableY, tz),
		PlateOffset = Vector3.new(tx, plateY, tz - 1.35),
		SeatOffset = Vector3.new(tx, seatY, tz - 3.25),
		WaiterOffset = Vector3.new(wX, waiterY, tz - 0.8),
		IsVIP = isVIP,
	})
end

local extraSpots: { ExpansionDiningSpot } = {}

-- LEVEL 2+: East Dining Conservatory Wing (Floor 1, X = +54, generous 14-stud spacing!) -> +6 seats
addTablePair(extraSpots, "EastWing", 1, 2, 54.0, 0.80, 8.0, false)
addTablePair(extraSpots, "EastWing", 1, 2, 54.0, 0.80, -6.0, false)
addTablePair(extraSpots, "EastWing", 1, 2, 54.0, 0.80, -20.0, false)

-- LEVEL 3+: Walkable 2nd Floor Gallery (Floor 2 top = 22.20, ZERO ceiling clipping!) -> +8 seats
addTablePair(extraSpots, "SecondFloor", 2, 3, 24.0, 22.20, 8.0, false)
addTablePair(extraSpots, "SecondFloor", 2, 3, 24.0, 22.20, -10.0, false)
addTablePair(extraSpots, "SecondFloor", 2, 3, -24.0, 22.20, 8.0, false)
addTablePair(extraSpots, "SecondFloor", 2, 3, 0.0, 22.20, 8.0, false)

-- LEVEL 4+: Modern 2nd Floor Lounges -> +6 seats
addTablePair(extraSpots, "SecondFloor", 2, 4, -24.0, 22.20, -10.0, false)
addTablePair(extraSpots, "SecondFloor", 2, 4, 24.0, 22.20, -23.0, false)
addTablePair(extraSpots, "SecondFloor", 2, 4, -24.0, 22.20, -23.0, false)

-- LEVEL 5+: Grand East Banquet Hall Extension (Floor 1, X = +80) -> +6 seats
addTablePair(extraSpots, "EastWing", 1, 5, 80.0, 0.80, 8.0, false)
addTablePair(extraSpots, "EastWing", 1, 5, 80.0, 0.80, -6.0, false)
addTablePair(extraSpots, "EastWing", 1, 5, 80.0, 0.80, -20.0, false)

-- LEVEL 6+: Grand West Estate Dining Pavilion (Floor 1, X = -84) -> +6 seats
addTablePair(extraSpots, "WestWing", 1, 6, -84.0, 0.80, 8.0, false)
addTablePair(extraSpots, "WestWing", 1, 6, -84.0, 0.80, -6.0, false)
addTablePair(extraSpots, "WestWing", 1, 6, -84.0, 0.80, -20.0, false)

-- LEVEL 7+: Walkable 3rd Floor Sky-Terrace (Floor 3 top = 43.60!) -> +6 seats
addTablePair(extraSpots, "ThirdFloor", 3, 7, 24.0, 43.60, 8.0, false)
addTablePair(extraSpots, "ThirdFloor", 3, 7, -24.0, 43.60, 8.0, false)
addTablePair(extraSpots, "ThirdFloor", 3, 7, 0.0, 43.60, 8.0, false)

-- LEVEL 8+: Imperial East & West Colonnade Pavilions (Floor 1, X = +/-106) -> +6 seats
addTablePair(extraSpots, "EastWing", 1, 8, 106.0, 0.80, 4.0, true)
addTablePair(extraSpots, "EastWing", 1, 8, 106.0, 0.80, -14.0, true)
addTablePair(extraSpots, "WestWing", 1, 8, -106.0, 0.80, -4.0, true)

-- LEVEL 9+: 3rd-Floor Royal Grand Ballroom (Floor 3 top = 43.60) -> +6 seats
addTablePair(extraSpots, "ThirdFloor", 3, 9, 24.0, 43.60, -14.0, true)
addTablePair(extraSpots, "ThirdFloor", 3, 9, -24.0, 43.60, -14.0, true)
addTablePair(extraSpots, "ThirdFloor", 3, 9, 0.0, 43.60, -14.0, true)

-- LEVEL 10: Imperial Palace Penthouse & Grand Wing Banquet -> +6 seats
addTablePair(extraSpots, "EastWing", 1, 10, 124.0, 0.80, -4.0, true)
addTablePair(extraSpots, "WestWing", 1, 10, -124.0, 0.80, -4.0, true)
addTablePair(extraSpots, "ThirdFloor", 3, 10, 0.0, 43.60, -28.0, true)

-- LEVEL 11+: Outer Imperial Banquet Arcades (Floor 1, X = +/-138) -> +8 seats
addTablePair(extraSpots, "EastWing", 1, 11, 138.0, 0.80, 6.0, true)
addTablePair(extraSpots, "EastWing", 1, 11, 138.0, 0.80, -14.0, true)
addTablePair(extraSpots, "WestWing", 1, 11, -138.0, 0.80, 6.0, true)
addTablePair(extraSpots, "WestWing", 1, 11, -138.0, 0.80, -14.0, true)

-- LEVEL 13+: 3rd-Floor Gilded Palazzo VIP Alcoves -> +4 seats
addTablePair(extraSpots, "ThirdFloor", 3, 13, 24.0, 43.60, -28.0, true)
addTablePair(extraSpots, "ThirdFloor", 3, 13, -24.0, 43.60, -28.0, true)

-- LEVEL 15 (MAX): Supreme Food Empire Royal Throne Banquet -> +4 seats
addTablePair(extraSpots, "EastWing", 1, 15, 124.0, 0.80, 10.0, true)
addTablePair(extraSpots, "WestWing", 1, 15, -124.0, 0.80, 10.0, true)

RestaurantExpansionConfig.EXTRA_DINING_SPOTS = extraSpots

-- Front Wood Restaurant with Roof (FrontDiningPlaza in BasePivot space, deck top = Y 0.40)
-- Unlocks progressively as the player upgrades Restaurant HQ from Lv.2 -> Lv.15!
local frontPavilionSpots: { ExpansionDiningSpot } = {}

local function addPatioWoodTablePair(minLevel: number, tx: number, tz: number, isVIP: boolean): ()
	local wX = if tx >= 0 then tx - 4.6 else tx + 4.6
	table.insert(frontPavilionSpots, {
		Space = "Base",
		Zone = "Patio",
		Floor = 1,
		MinLevel = minLevel,
		TableOffset = Vector3.new(tx, 3.28, tz),
		PlateOffset = Vector3.new(tx, 3.30, tz + 1.3),
		SeatOffset = Vector3.new(tx, 2.55, tz + 3.1),
		WaiterOffset = Vector3.new(wX, 2.90, tz + 0.8),
		IsVIP = isVIP,
	})
	table.insert(frontPavilionSpots, {
		Space = "Base",
		Zone = "Patio",
		Floor = 1,
		MinLevel = minLevel,
		TableOffset = Vector3.new(tx, 3.28, tz),
		PlateOffset = Vector3.new(tx, 3.30, tz - 1.3),
		SeatOffset = Vector3.new(tx, 2.55, tz - 3.1),
		WaiterOffset = Vector3.new(wX, 2.90, tz - 0.8),
		IsVIP = isVIP,
	})
end

-- LEVEL 2+: Front 3rd row of existing Inner Wood Restaurant tables (Z = 81) -> +8 patio seats
addPatioWoodTablePair(2, -69.0, 81.0, false)
addPatioWoodTablePair(2, -47.0, 81.0, false)
addPatioWoodTablePair(2, 47.0, 81.0, false)
addPatioWoodTablePair(2, 69.0, 81.0, false)

-- LEVEL 5+: Expanded Covered Wood Veranda Column A (X = +/-98, Z = 43, 62, 81) -> +12 patio seats
for _, side in ipairs({ -1, 1 }) do
	for _, tz in ipairs({ 43.0, 62.0, 81.0 }) do
		addPatioWoodTablePair(5, side * 98.0, tz, false)
	end
end

-- LEVEL 9+: Two-Tier Pagoda Wood Veranda Column B (X = +/-116, Z = 43, 62, 81) -> +12 patio seats
for _, side in ipairs({ -1, 1 }) do
	for _, tz in ipairs({ 43.0, 62.0, 81.0 }) do
		addPatioWoodTablePair(9, side * 116.0, tz, false)
	end
end

-- LEVEL 12 & 14+: Royal Outer Wood Restaurant Wings (X = +/-142, Z = 44, 62, 80) -> +12 VIP patio seats
for _, side in ipairs({ -1, 1 }) do
	addPatioWoodTablePair(12, side * 142.0, 44.0, true)
	addPatioWoodTablePair(12, side * 142.0, 80.0, true)
	addPatioWoodTablePair(14, side * 142.0, 62.0, true)
end

RestaurantExpansionConfig.FRONT_PAVILION_SPOTS = frontPavilionSpots

-- Rear Grand Atrium Staircase & Wing Archway Waypoints (matching airy Floor 2 = 22.20 & Floor 3 = 43.60!)
RestaurantExpansionConfig.STAIR_WAYPOINTS = {
	EastWingArchway = Vector3.new(38.0, 3.6, -6.5),
	WestWingArchway = Vector3.new(-38.0, 3.6, -6.5),
	RearAtriumDoor = Vector3.new(0.0, 3.6, -31.0),
	-- 1F -> 2F Rear Grand Staircase (inside Rear Atrium Z = -32..-53, climbing X = -14 -> +12!)
	BottomLobby = Vector3.new(-15.5, 3.6, -40.5),
	MidStairs = Vector3.new(-1.0, 14.3, -40.5),
	TopLanding = Vector3.new(13.5, 25.1, -40.5),
	Floor2Entry = Vector3.new(10.0, 25.1, -27.5),
	-- 2F -> 3F Upper Rear Grand Staircase (inside Rear Atrium Z = -46..-56, climbing X = +12 -> -14!)
	Floor2StairStart = Vector3.new(13.5, 25.1, -50.5),
	Floor2StairMid = Vector3.new(-1.0, 35.8, -50.5),
	Floor3TopLanding = Vector3.new(-15.5, 46.5, -50.5),
	Floor3Entry = Vector3.new(-10.0, 46.5, -27.5),
}

function RestaurantExpansionConfig.GetTierSpec(restaurantLevel: number): ExpansionTierSpec
	local clamped = math.clamp(math.floor(restaurantLevel or 1), 1, RestaurantExpansionConfig.MAX_PHYSICAL_TIER)
	return RestaurantExpansionConfig.TIERS[clamped] or RestaurantExpansionConfig.TIERS[1]
end

return RestaurantExpansionConfig
