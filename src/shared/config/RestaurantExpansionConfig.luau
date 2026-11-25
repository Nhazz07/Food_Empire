--!strict

-- RestaurantExpansionConfig: Reusable Level 1-10 physical restaurant expansion
-- templates, footprint boundaries, seating capacities, and kitchen capacities.
-- Designed for the expanded 336x288 Grand Castle Base (WarehousePlots shifted to Z=-90).
-- Airy grand ceilings: Floor 1 top = Y 0.80 | Floor 2 top = Y 22.20 (1.4-stud deck) | Floor 3 top = Y 43.60 (1.4-stud deck).
-- Every seat Y sits +2.95 studs above its floor so customer feet NEVER clip through ceilings!

export type ExpansionDiningSpot = {
	Space: "HQ",
	Zone: "Indoor" | "EastWing" | "WestWing" | "RearAtrium" | "SecondFloor" | "ThirdFloor" | "VIP",
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
	MinX = -148,
	MaxX = 148,
	MinZ = -82.0,
	MaxZ = 38.0,
	MaxY = 116.0,
} :: SafeBoundsSpec

RestaurantExpansionConfig.MAX_PHYSICAL_TIER = 10

RestaurantExpansionConfig.TIERS = {
	[1] = {
		Tier = 1,
		DisplayName = "Grand Starter Bistro",
		Subtitle = "LEVEL 1  •  AIRY STARTER RESTAURANT",
		Summary = "Tall 21-stud ceiling dining hall, wide 24-stud grand entrance & open kitchen (86x26x56).",
		WidthStuds = 86,
		HeightStuds = 26,
		DepthStuds = 56,
		Floors = 1,
		MaxCustomers = 3,
		KitchenReadyCapacity = 5,
		MaxConcurrentOrders = 1,
		RecommendedMaxCrew = 2,
	},
	[2] = {
		Tier = 2,
		DisplayName = "East Conservatory Bistro",
		Subtitle = "LEVEL 2  •  EAST GLASS CONSERVATORY",
		Summary = "Opens tall panoramic East Glass Conservatory (+3 spacious tables) & stainless prep island (130x28x62).",
		WidthStuds = 130,
		HeightStuds = 28,
		DepthStuds = 62,
		Floors = 1,
		MaxCustomers = 4,
		KitchenReadyCapacity = 7,
		MaxConcurrentOrders = 1,
		RecommendedMaxCrew = 3,
	},
	[3] = {
		Tier = 3,
		DisplayName = "Two-Story Atrium Bistro",
		Subtitle = "LEVEL 3  •  2ND FLOOR & REAR ATRIUM",
		Summary = "Soaring Rear Staircase Atrium, airy 2nd-Floor Gallery (+4 tables) & West Culinary Wing (154x50x82).",
		WidthStuds = 154,
		HeightStuds = 50,
		DepthStuds = 82,
		Floors = 2,
		MaxCustomers = 5,
		KitchenReadyCapacity = 10,
		MaxConcurrentOrders = 2,
		RecommendedMaxCrew = 4,
	},
	[4] = {
		Tier = 4,
		DisplayName = "Modern Culinary Pavilion",
		Subtitle = "LEVEL 4  •  MODERN GLASS PAVILION",
		Summary = "Symmetrical tall wings, soaring cantilevered glass portico, wine wall & 2nd-floor lounges (168x54x86).",
		WidthStuds = 168,
		HeightStuds = 54,
		DepthStuds = 86,
		Floors = 2,
		MaxCustomers = 6,
		KitchenReadyCapacity = 12,
		MaxConcurrentOrders = 2,
		RecommendedMaxCrew = 5,
	},
	[5] = {
		Tier = 5,
		DisplayName = "Grand Syndicate Brasserie",
		Subtitle = "LEVEL 5  •  EAST BANQUET HALL",
		Summary = "Grand East Banquet Hall wing (+3 tables), unobstructed red carpet portico & twin marble fountains (192x56x90).",
		WidthStuds = 192,
		HeightStuds = 56,
		DepthStuds = 90,
		Floors = 2,
		MaxCustomers = 7,
		KitchenReadyCapacity = 15,
		MaxConcurrentOrders = 3,
		RecommendedMaxCrew = 6,
	},
	[6] = {
		Tier = 6,
		DisplayName = "Dual-Wing Estate Bistro",
		Subtitle = "LEVEL 6  •  WEST ESTATE DINING WING",
		Summary = "Grand West Estate Dining Pavilion (+3 tables), executive copper kitchen hood & glass terraces (214x58x92).",
		WidthStuds = 214,
		HeightStuds = 58,
		DepthStuds = 92,
		Floors = 2,
		MaxCustomers = 8,
		KitchenReadyCapacity = 17,
		MaxConcurrentOrders = 3,
		RecommendedMaxCrew = 6,
	},
	[7] = {
		Tier = 7,
		DisplayName = "Three-Story Sky Terrace",
		Subtitle = "LEVEL 7  •  WALKABLE 3RD FLOOR SKY-DECK",
		Summary = "Unlocks soaring 3rd-Floor Marble Sky-Terrace with upper grand staircase & glass balustrades (224x74x98).",
		WidthStuds = 224,
		HeightStuds = 74,
		DepthStuds = 98,
		Floors = 3,
		MaxCustomers = 9,
		KitchenReadyCapacity = 19,
		MaxConcurrentOrders = 3,
		RecommendedMaxCrew = 6,
	},
	[8] = {
		Tier = 8,
		DisplayName = "Imperial Colonnade Hall",
		Subtitle = "LEVEL 8  •  MARBLE COLONNADE PAVILIONS",
		Summary = "Tall Marble & Brass Colonnade Pavilions (+3 VIP tables) & 2-story Crystal Atrium Chandelier (244x78x102).",
		WidthStuds = 244,
		HeightStuds = 78,
		DepthStuds = 102,
		Floors = 3,
		MaxCustomers = 10,
		KitchenReadyCapacity = 21,
		MaxConcurrentOrders = 4,
		RecommendedMaxCrew = 6,
	},
	[9] = {
		Tier = 9,
		DisplayName = "Royal Grand Ballroom",
		Subtitle = "LEVEL 9  •  3RD-FLOOR ROYAL BALLROOM",
		Summary = "Full glass-and-marble enclosed 3rd-Floor Royal Ballroom, mansard gold roof & VIP ballroom tables (256x88x106).",
		WidthStuds = 256,
		HeightStuds = 88,
		DepthStuds = 106,
		Floors = 3,
		MaxCustomers = 11,
		KitchenReadyCapacity = 23,
		MaxConcurrentOrders = 4,
		RecommendedMaxCrew = 6,
	},
	[10] = {
		Tier = 10,
		DisplayName = "Food Emperor Imperial Palace",
		Subtitle = "LEVEL 10  •  MAX IMPERIAL PALACE EMPIRE",
		Summary = "Monumental 268-stud 3-story Imperial Palace crowned with a soaring 106-stud Glass & Gold Sky-Atrium Dome (268x106x114).",
		WidthStuds = 268,
		HeightStuds = 106,
		DepthStuds = 114,
		Floors = 3,
		MaxCustomers = 12,
		KitchenReadyCapacity = 26,
		MaxConcurrentOrders = 4,
		RecommendedMaxCrew = 6,
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

-- LEVEL 10 (MAX): Imperial Palace Penthouse & Grand Wing Banquet -> +6 seats
addTablePair(extraSpots, "EastWing", 1, 10, 124.0, 0.80, -4.0, true)
addTablePair(extraSpots, "WestWing", 1, 10, -124.0, 0.80, -4.0, true)
addTablePair(extraSpots, "ThirdFloor", 3, 10, 0.0, 43.60, -28.0, true)

RestaurantExpansionConfig.EXTRA_DINING_SPOTS = extraSpots

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
