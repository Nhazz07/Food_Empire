--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

export type MafiaFactionSpec = {
	Id: string,
	DisplayName: string,
	ShortName: string,
	HQBlockId: string,
	BaseColor: Color3,
	SuitColor: Color3,
	AccentColor: Color3,
	TextColor: Color3,
	WeaponKind: "Pistol" | "SMG" | "Shotgun",
	SpecialistKind: "NinjaMafia" | "SamuraiMafia",
	BladeStyle: "Ninja" | "Samurai",
	GuardTitle: string,
	BossTitle: string,
	Motto: string,
}

export type BlockBuffType = "Speed" | "Heal" | "ArmorPatch" | "CombatStim"

export type TurfBlockSpec = {
	Id: string,
	DisplayName: string,
	ShortCode: string,
	Wedge: "NNW" | "WNW" | "NNE" | "ENE" | "WSW" | "SSW" | "SSE" | "ESE" | "NW_Corner" | "NE_Corner" | "SW_Corner" | "SE_Corner",
	Quadrant: "NW" | "NE" | "SW" | "SE",
	Ring: "Inner" | "Outer" | "Corner",
	InitialOwner: string,
	IsHQ: boolean,
	PlazaPos: Vector3,
	CaptureRadius: number,
	CaptureTime: number,
	IncomeGold: number,
	IncomeRep: number,
	CaptureBountyGold: number,
	CaptureBountyRep: number,
	BuffType: BlockBuffType,
	BuffTitle: string,
	Neighbors: { string },
	PatrolPoints: { Vector3 },
}

local TurfConfig = {}

-- Exact Player Base fallback colors (runtime always checks BaseModel:GetAttribute("AccentColor") first!)
TurfConfig.PlayerSlotFallbackColors = {
	North = Color3.fromRGB(142, 74, 224),
	South = Color3.fromRGB(240, 192, 38),
	East = Color3.fromRGB(48, 168, 238),
	West = Color3.fromRGB(224, 62, 62),
}

TurfConfig.ContestedColor = Color3.fromRGB(255, 174, 38)
TurfConfig.NeutralColor = Color3.fromRGB(156, 166, 184)

-- The 4 Main Mafia Factions (Samurai Mafia & Ninja Assassin Mafia clans) controlling the 4 urban quadrants at server start
TurfConfig.MafiaFactions = {
	Mafia_IronClaw = {
		Id = "Mafia_IronClaw",
		DisplayName = "Iron Shogun Samurai Mafia",
		ShortName = "IRON SAMURAI",
		HQBlockId = "NW_North_Outer",
		BaseColor = Color3.fromRGB(238, 112, 24),
		SuitColor = Color3.fromRGB(36, 30, 28),
		AccentColor = Color3.fromRGB(255, 148, 48),
		TextColor = Color3.fromRGB(255, 244, 226),
		WeaponKind = "Shotgun",
		SpecialistKind = "SamuraiMafia",
		BladeStyle = "Samurai",
		GuardTitle = "SAMURAI MAFIA",
		BossTitle = "IRON SHOGUN CAPO",
		Motto = "NW Samurai Mafia Clan",
	},
	Mafia_JadeDragon = {
		Id = "Mafia_JadeDragon",
		DisplayName = "Jade Viper Ninja Mafia",
		ShortName = "JADE NINJA",
		HQBlockId = "NE_North_Outer",
		BaseColor = Color3.fromRGB(28, 182, 92),
		SuitColor = Color3.fromRGB(24, 38, 32),
		AccentColor = Color3.fromRGB(64, 230, 132),
		TextColor = Color3.fromRGB(230, 255, 238),
		WeaponKind = "SMG",
		SpecialistKind = "NinjaMafia",
		BladeStyle = "Ninja",
		GuardTitle = "NINJA ASSASSIN MAFIA",
		BossTitle = "JADE SHADOW MASTER",
		Motto = "NE Ninja Assassin Mafia",
	},
	Mafia_VelvetRose = {
		Id = "Mafia_VelvetRose",
		DisplayName = "Shadow Lotus Ninja Mafia",
		ShortName = "LOTUS NINJA",
		HQBlockId = "SW_West_Outer",
		BaseColor = Color3.fromRGB(224, 48, 164),
		SuitColor = Color3.fromRGB(40, 24, 38),
		AccentColor = Color3.fromRGB(252, 96, 198),
		TextColor = Color3.fromRGB(255, 232, 248),
		WeaponKind = "Pistol",
		SpecialistKind = "NinjaMafia",
		BladeStyle = "Ninja",
		GuardTitle = "NINJA ASSASSIN MAFIA",
		BossTitle = "LOTUS ASSASSIN BOSS",
		Motto = "SW Ninja Assassin Syndicate",
	},
	Mafia_Obsidian = {
		Id = "Mafia_Obsidian",
		DisplayName = "Obsidian Ronin Samurai Mafia",
		ShortName = "OBSIDIAN SAMURAI",
		HQBlockId = "SE_South_Outer",
		BaseColor = Color3.fromRGB(34, 40, 56),
		SuitColor = Color3.fromRGB(18, 20, 28),
		AccentColor = Color3.fromRGB(196, 212, 238),
		TextColor = Color3.fromRGB(240, 246, 255),
		WeaponKind = "SMG",
		SpecialistKind = "SamuraiMafia",
		BladeStyle = "Samurai",
		GuardTitle = "SAMURAI MAFIA",
		BossTitle = "OBSIDIAN RONIN BOSS",
		Motto = "SE Samurai Mafia Syndicate",
	},
} :: { [string]: MafiaFactionSpec }

TurfConfig.MafiaFactionOrder = {
	"Mafia_IronClaw",
	"Mafia_JadeDragon",
	"Mafia_VelvetRose",
	"Mafia_Obsidian",
}

local function uvToWorld(wedge: string, u: number, v: number, y: number?): Vector3
	local py = y or 2.0
	if wedge == "NNW" then
		return Vector3.new(-u, py, -v)
	elseif wedge == "WNW" then
		return Vector3.new(-v, py, -u)
	elseif wedge == "NNE" then
		return Vector3.new(u, py, -v)
	elseif wedge == "ENE" then
		return Vector3.new(v, py, -u)
	elseif wedge == "WSW" then
		return Vector3.new(-v, py, u)
	elseif wedge == "SSW" then
		return Vector3.new(-u, py, v)
	elseif wedge == "SSE" then
		return Vector3.new(u, py, v)
	else -- ESE
		return Vector3.new(v, py, u)
	end
end

TurfConfig.UVToWorld = uvToWorld

local function makeInnerPatrol(wedge: string, isBlackMarketWedge: boolean): { Vector3 }
	if isBlackMarketWedge then
		return {
			uvToWorld(wedge, 216, 304, 4),
			uvToWorld(wedge, 192, 276, 4),
			uvToWorld(wedge, 238, 326, 4),
			uvToWorld(wedge, 196, 336, 4),
			uvToWorld(wedge, 174, 290, 4),
		}
	end
	return {
		uvToWorld(wedge, 158, 282, 4),
		uvToWorld(wedge, 118, 258, 4),
		uvToWorld(wedge, 196, 280, 4),
		uvToWorld(wedge, 196, 332, 4),
		uvToWorld(wedge, 118, 314, 4),
	}
end

local function makeOuterPatrol(wedge: string): { Vector3 }
	return {
		uvToWorld(wedge, 216, 420, 4),
		uvToWorld(wedge, 176, 398, 4),
		uvToWorld(wedge, 268, 418, 4),
		uvToWorld(wedge, 260, 452, 4),
		uvToWorld(wedge, 176, 444, 4),
	}
end

local function makeCornerPatrol(plazaPos: Vector3): { Vector3 }
	local x, z = plazaPos.X, plazaPos.Z
	return {
		Vector3.new(x, 4, z),
		Vector3.new(x - 30, 4, z - 30),
		Vector3.new(x + 30, 4, z - 30),
		Vector3.new(x + 30, 4, z + 30),
		Vector3.new(x - 30, 4, z + 30),
	}
end

TurfConfig.BlockOrder = {
	"NW_North_Inner",
	"NW_North_Outer",
	"NW_West_Inner",
	"NW_West_Outer",
	"NW_Corner_North",
	"NW_Corner_West",
	"NW_Corner_Apex",
	"NE_North_Inner",
	"NE_North_Outer",
	"NE_East_Inner",
	"NE_East_Outer",
	"NE_Corner_North",
	"NE_Corner_East",
	"NE_Corner_Apex",
	"SW_West_Inner",
	"SW_West_Outer",
	"SW_South_Inner",
	"SW_South_Outer",
	"SW_Corner_South",
	"SW_Corner_West",
	"SW_Corner_Apex",
	"SE_South_Inner",
	"SE_South_Outer",
	"SE_East_Inner",
	"SE_East_Outer",
	"SE_Corner_South",
	"SE_Corner_East",
	"SE_Corner_Apex",
}

TurfConfig.Blocks = {
	-- ==================== NW QUADRANT (IRON CLAW MAFIA) ====================
	NW_North_Inner = {
		Id = "NW_North_Inner",
		DisplayName = "Little Italy Row",
		ShortCode = "LIT",
		Wedge = "NNW",
		Quadrant = "NW",
		Ring = "Inner",
		InitialOwner = "Mafia_IronClaw",
		IsHQ = false,
		PlazaPos = uvToWorld("NNW", 158, 282, 1.55),
		CaptureRadius = 29,
		CaptureTime = 7,
		IncomeGold = 18,
		IncomeRep = 3,
		CaptureBountyGold = 120,
		CaptureBountyRep = 28,
		BuffType = "Speed",
		BuffTitle = "Espresso Bar (+Speed)",
		Neighbors = { "NW_North_Outer", "NW_West_Inner", "NE_North_Inner" },
		PatrolPoints = makeInnerPatrol("NNW", false),
	},
	NW_North_Outer = {
		Id = "NW_North_Outer",
		DisplayName = "Iron Claw Heights",
		ShortCode = "ICH",
		Wedge = "NNW",
		Quadrant = "NW",
		Ring = "Outer",
		InitialOwner = "Mafia_IronClaw",
		IsHQ = true,
		PlazaPos = uvToWorld("NNW", 216, 420, 1.55),
		CaptureRadius = 31,
		CaptureTime = 9,
		IncomeGold = 28,
		IncomeRep = 5,
		CaptureBountyGold = 240,
		CaptureBountyRep = 55,
		BuffType = "ArmorPatch",
		BuffTitle = "Syndicate Supply (+Heal & Shield)",
		Neighbors = { "NW_North_Inner", "NW_West_Outer", "NE_North_Outer", "NW_Corner_North" },
		PatrolPoints = makeOuterPatrol("NNW"),
	},
	NW_West_Inner = {
		Id = "NW_West_Inner",
		DisplayName = "Noodle Lantern Lane",
		ShortCode = "NLL",
		Wedge = "WNW",
		Quadrant = "NW",
		Ring = "Inner",
		InitialOwner = "Mafia_IronClaw",
		IsHQ = false,
		PlazaPos = uvToWorld("WNW", 158, 282, 1.55),
		CaptureRadius = 29,
		CaptureTime = 7,
		IncomeGold = 18,
		IncomeRep = 3,
		CaptureBountyGold = 120,
		CaptureBountyRep = 28,
		BuffType = "Heal",
		BuffTitle = "Street Ramen Stall (+45 HP)",
		Neighbors = { "NW_West_Outer", "NW_North_Inner", "SW_West_Inner" },
		PatrolPoints = makeInnerPatrol("WNW", false),
	},
	NW_West_Outer = {
		Id = "NW_West_Outer",
		DisplayName = "Westgate Market Block",
		ShortCode = "WGM",
		Wedge = "WNW",
		Quadrant = "NW",
		Ring = "Outer",
		InitialOwner = "Mafia_IronClaw",
		IsHQ = false,
		PlazaPos = uvToWorld("WNW", 216, 420, 1.55),
		CaptureRadius = 30,
		CaptureTime = 8,
		IncomeGold = 22,
		IncomeRep = 4,
		CaptureBountyGold = 150,
		CaptureBountyRep = 35,
		BuffType = "CombatStim",
		BuffTitle = "Deli Power Snack (+HP & Speed)",
		Neighbors = { "NW_West_Inner", "NW_North_Outer", "SW_West_Outer", "NW_Corner_West" },
		PatrolPoints = makeOuterPatrol("WNW"),
	},
	NW_Corner_North = {
		Id = "NW_Corner_North",
		DisplayName = "Shogun Market Terrace",
		ShortCode = "SMT",
		Wedge = "NW_Corner",
		Quadrant = "NW",
		Ring = "Corner",
		InitialOwner = "Mafia_IronClaw",
		IsHQ = false,
		PlazaPos = Vector3.new(-610, 1.55, -838),
		CaptureRadius = 30,
		CaptureTime = 8,
		IncomeGold = 24,
		IncomeRep = 4,
		CaptureBountyGold = 175,
		CaptureBountyRep = 40,
		BuffType = "Speed",
		BuffTitle = "Ginger Shot Stand (+Speed)",
		Neighbors = { "NW_North_Outer", "NW_Corner_West", "NW_Corner_Apex" },
		PatrolPoints = makeCornerPatrol(Vector3.new(-610, 1.55, -838)),
	},
	NW_Corner_West = {
		Id = "NW_Corner_West",
		DisplayName = "Foundry Produce Row",
		ShortCode = "FPR",
		Wedge = "NW_Corner",
		Quadrant = "NW",
		Ring = "Corner",
		InitialOwner = "Mafia_IronClaw",
		IsHQ = false,
		PlazaPos = Vector3.new(-838, 1.55, -610),
		CaptureRadius = 30,
		CaptureTime = 8,
		IncomeGold = 24,
		IncomeRep = 4,
		CaptureBountyGold = 175,
		CaptureBountyRep = 40,
		BuffType = "Heal",
		BuffTitle = "Hot Pot Noodle Bar (+45 HP)",
		Neighbors = { "NW_West_Outer", "NW_Corner_North", "NW_Corner_Apex" },
		PatrolPoints = makeCornerPatrol(Vector3.new(-838, 1.55, -610)),
	},
	NW_Corner_Apex = {
		Id = "NW_Corner_Apex",
		DisplayName = "Iron Citadel Crossing",
		ShortCode = "ICC",
		Wedge = "NW_Corner",
		Quadrant = "NW",
		Ring = "Corner",
		InitialOwner = "Mafia_IronClaw",
		IsHQ = true,
		PlazaPos = Vector3.new(-838, 1.55, -838),
		CaptureRadius = 31,
		CaptureTime = 9,
		IncomeGold = 32,
		IncomeRep = 6,
		CaptureBountyGold = 260,
		CaptureBountyRep = 60,
		BuffType = "ArmorPatch",
		BuffTitle = "Shogun Armory Crate (+Heal & Shield)",
		Neighbors = { "NW_Corner_North", "NW_Corner_West" },
		PatrolPoints = makeCornerPatrol(Vector3.new(-838, 1.55, -838)),
	},

	-- ==================== NE QUADRANT (JADE VIPER TRIAD) ====================
	NE_North_Inner = {
		Id = "NE_North_Inner",
		DisplayName = "Jade Tea Arcade",
		ShortCode = "JTA",
		Wedge = "NNE",
		Quadrant = "NE",
		Ring = "Inner",
		InitialOwner = "Mafia_JadeDragon",
		IsHQ = false,
		PlazaPos = uvToWorld("NNE", 158, 282, 1.55),
		CaptureRadius = 29,
		CaptureTime = 7,
		IncomeGold = 18,
		IncomeRep = 3,
		CaptureBountyGold = 120,
		CaptureBountyRep = 28,
		BuffType = "Speed",
		BuffTitle = "Matcha Tea Kiosk (+Speed)",
		Neighbors = { "NE_North_Outer", "NE_East_Inner", "NW_North_Inner" },
		PatrolPoints = makeInnerPatrol("NNE", false),
	},
	NE_North_Outer = {
		Id = "NE_North_Outer",
		DisplayName = "Dragon Spire Plaza",
		ShortCode = "DSP",
		Wedge = "NNE",
		Quadrant = "NE",
		Ring = "Outer",
		InitialOwner = "Mafia_JadeDragon",
		IsHQ = true,
		PlazaPos = uvToWorld("NNE", 216, 420, 1.55),
		CaptureRadius = 31,
		CaptureTime = 9,
		IncomeGold = 28,
		IncomeRep = 5,
		CaptureBountyGold = 240,
		CaptureBountyRep = 55,
		BuffType = "ArmorPatch",
		BuffTitle = "Jade Med-Cabinet (+Heal & Shield)",
		Neighbors = { "NE_North_Inner", "NE_East_Outer", "NW_North_Outer", "NE_Corner_North" },
		PatrolPoints = makeOuterPatrol("NNE"),
	},
	NE_East_Inner = {
		Id = "NE_East_Inner",
		DisplayName = "Spice Bazaar Square",
		ShortCode = "SBZ",
		Wedge = "ENE",
		Quadrant = "NE",
		Ring = "Inner",
		InitialOwner = "Mafia_JadeDragon",
		IsHQ = false,
		PlazaPos = uvToWorld("ENE", 158, 282, 1.55),
		CaptureRadius = 29,
		CaptureTime = 7,
		IncomeGold = 18,
		IncomeRep = 3,
		CaptureBountyGold = 120,
		CaptureBountyRep = 28,
		BuffType = "Heal",
		BuffTitle = "Spice Kebab Cart (+45 HP)",
		Neighbors = { "NE_East_Outer", "NE_North_Inner", "SE_East_Inner" },
		PatrolPoints = makeInnerPatrol("ENE", false),
	},
	NE_East_Outer = {
		Id = "NE_East_Outer",
		DisplayName = "Eastview Towers",
		ShortCode = "EVT",
		Wedge = "ENE",
		Quadrant = "NE",
		Ring = "Outer",
		InitialOwner = "Mafia_JadeDragon",
		IsHQ = false,
		PlazaPos = uvToWorld("ENE", 216, 420, 1.55),
		CaptureRadius = 30,
		CaptureTime = 8,
		IncomeGold = 22,
		IncomeRep = 4,
		CaptureBountyGold = 150,
		CaptureBountyRep = 35,
		BuffType = "CombatStim",
		BuffTitle = "Skyline Smoothie Bar (+HP & Speed)",
		Neighbors = { "NE_East_Inner", "NE_North_Outer", "SE_East_Outer", "NE_Corner_East" },
		PatrolPoints = makeOuterPatrol("ENE"),
	},
	NE_Corner_North = {
		Id = "NE_Corner_North",
		DisplayName = "Smokehouse Lofts",
		ShortCode = "SHL",
		Wedge = "NE_Corner",
		Quadrant = "NE",
		Ring = "Corner",
		InitialOwner = "Mafia_JadeDragon",
		IsHQ = false,
		PlazaPos = Vector3.new(610, 1.55, -838),
		CaptureRadius = 30,
		CaptureTime = 8,
		IncomeGold = 24,
		IncomeRep = 4,
		CaptureBountyGold = 175,
		CaptureBountyRep = 40,
		BuffType = "CombatStim",
		BuffTitle = "Brisket Fuel Grill (+HP & Speed)",
		Neighbors = { "NE_North_Outer", "NE_Corner_East", "NE_Corner_Apex" },
		PatrolPoints = makeCornerPatrol(Vector3.new(610, 1.55, -838)),
	},
	NE_Corner_East = {
		Id = "NE_Corner_East",
		DisplayName = "Jade Butcher Alley",
		ShortCode = "JBA",
		Wedge = "NE_Corner",
		Quadrant = "NE",
		Ring = "Corner",
		InitialOwner = "Mafia_JadeDragon",
		IsHQ = false,
		PlazaPos = Vector3.new(838, 1.55, -610),
		CaptureRadius = 30,
		CaptureTime = 8,
		IncomeGold = 24,
		IncomeRep = 4,
		CaptureBountyGold = 175,
		CaptureBountyRep = 40,
		BuffType = "Heal",
		BuffTitle = "Wagyu Dumpling Stall (+45 HP)",
		Neighbors = { "NE_East_Outer", "NE_Corner_North", "NE_Corner_Apex" },
		PatrolPoints = makeCornerPatrol(Vector3.new(838, 1.55, -610)),
	},
	NE_Corner_Apex = {
		Id = "NE_Corner_Apex",
		DisplayName = "Viper Exchange Square",
		ShortCode = "VES",
		Wedge = "NE_Corner",
		Quadrant = "NE",
		Ring = "Corner",
		InitialOwner = "Mafia_JadeDragon",
		IsHQ = true,
		PlazaPos = Vector3.new(838, 1.55, -838),
		CaptureRadius = 31,
		CaptureTime = 9,
		IncomeGold = 32,
		IncomeRep = 6,
		CaptureBountyGold = 260,
		CaptureBountyRep = 60,
		BuffType = "ArmorPatch",
		BuffTitle = "Jade Tactical Locker (+Heal & Shield)",
		Neighbors = { "NE_Corner_North", "NE_Corner_East" },
		PatrolPoints = makeCornerPatrol(Vector3.new(838, 1.55, -838)),
	},

	-- ==================== SW QUADRANT (VELVET ROSE CARTEL) ====================
	SW_West_Inner = {
		Id = "SW_West_Inner",
		DisplayName = "Black Market Row",
		ShortCode = "BMR",
		Wedge = "WSW",
		Quadrant = "SW",
		Ring = "Inner",
		InitialOwner = "Mafia_VelvetRose",
		IsHQ = false,
		PlazaPos = uvToWorld("WSW", 216, 304, 1.55),
		CaptureRadius = 28,
		CaptureTime = 7,
		IncomeGold = 20,
		IncomeRep = 4,
		CaptureBountyGold = 140,
		CaptureBountyRep = 32,
		BuffType = "CombatStim",
		BuffTitle = "Speakeasy Tonic (+HP & Speed)",
		Neighbors = { "SW_West_Outer", "SW_South_Inner", "NW_West_Inner" },
		PatrolPoints = makeInnerPatrol("WSW", true),
	},
	SW_West_Outer = {
		Id = "SW_West_Outer",
		DisplayName = "Velvet Rose Quarter",
		ShortCode = "VRQ",
		Wedge = "WSW",
		Quadrant = "SW",
		Ring = "Outer",
		InitialOwner = "Mafia_VelvetRose",
		IsHQ = true,
		PlazaPos = uvToWorld("WSW", 216, 420, 1.55),
		CaptureRadius = 31,
		CaptureTime = 9,
		IncomeGold = 28,
		IncomeRep = 5,
		CaptureBountyGold = 240,
		CaptureBountyRep = 55,
		BuffType = "ArmorPatch",
		BuffTitle = "Velvet Lounge Medkit (+Heal & Shield)",
		Neighbors = { "SW_West_Inner", "SW_South_Outer", "NW_West_Outer", "SW_Corner_West" },
		PatrolPoints = makeOuterPatrol("WSW"),
	},
	SW_South_Inner = {
		Id = "SW_South_Inner",
		DisplayName = "Sunset Cafe Strip",
		ShortCode = "SCS",
		Wedge = "SSW",
		Quadrant = "SW",
		Ring = "Inner",
		InitialOwner = "Mafia_VelvetRose",
		IsHQ = false,
		PlazaPos = uvToWorld("SSW", 158, 282, 1.55),
		CaptureRadius = 29,
		CaptureTime = 7,
		IncomeGold = 18,
		IncomeRep = 3,
		CaptureBountyGold = 120,
		CaptureBountyRep = 28,
		BuffType = "Speed",
		BuffTitle = "Gelato Rush Stand (+Speed)",
		Neighbors = { "SW_South_Outer", "SW_West_Inner", "SE_South_Inner" },
		PatrolPoints = makeInnerPatrol("SSW", false),
	},
	SW_South_Outer = {
		Id = "SW_South_Outer",
		DisplayName = "Southpark Residences",
		ShortCode = "SPR",
		Wedge = "SSW",
		Quadrant = "SW",
		Ring = "Outer",
		InitialOwner = "Mafia_VelvetRose",
		IsHQ = false,
		PlazaPos = uvToWorld("SSW", 216, 420, 1.55),
		CaptureRadius = 30,
		CaptureTime = 8,
		IncomeGold = 22,
		IncomeRep = 4,
		CaptureBountyGold = 150,
		CaptureBountyRep = 35,
		BuffType = "Heal",
		BuffTitle = "Corner Taco Stand (+45 HP)",
		Neighbors = { "SW_South_Inner", "SW_West_Outer", "SE_South_Outer", "SW_Corner_South" },
		PatrolPoints = makeOuterPatrol("SSW"),
	},
	SW_Corner_South = {
		Id = "SW_Corner_South",
		DisplayName = "Lotus Veranda Courts",
		ShortCode = "LVC",
		Wedge = "SW_Corner",
		Quadrant = "SW",
		Ring = "Corner",
		InitialOwner = "Mafia_VelvetRose",
		IsHQ = false,
		PlazaPos = Vector3.new(-610, 1.55, 838),
		CaptureRadius = 30,
		CaptureTime = 8,
		IncomeGold = 24,
		IncomeRep = 4,
		CaptureBountyGold = 175,
		CaptureBountyRep = 40,
		BuffType = "CombatStim",
		BuffTitle = "Citrus Elixir Lounge (+HP & Speed)",
		Neighbors = { "SW_South_Outer", "SW_Corner_West", "SW_Corner_Apex" },
		PatrolPoints = makeCornerPatrol(Vector3.new(-610, 1.55, 838)),
	},
	SW_Corner_West = {
		Id = "SW_Corner_West",
		DisplayName = "Blossom Boulevard",
		ShortCode = "BBL",
		Wedge = "SW_Corner",
		Quadrant = "SW",
		Ring = "Corner",
		InitialOwner = "Mafia_VelvetRose",
		IsHQ = false,
		PlazaPos = Vector3.new(-838, 1.55, 610),
		CaptureRadius = 30,
		CaptureTime = 8,
		IncomeGold = 24,
		IncomeRep = 4,
		CaptureBountyGold = 175,
		CaptureBountyRep = 40,
		BuffType = "Speed",
		BuffTitle = "Mango Rush Bar (+Speed)",
		Neighbors = { "SW_West_Outer", "SW_Corner_South", "SW_Corner_Apex" },
		PatrolPoints = makeCornerPatrol(Vector3.new(-838, 1.55, 610)),
	},
	SW_Corner_Apex = {
		Id = "SW_Corner_Apex",
		DisplayName = "Velvet Promenade Plaza",
		ShortCode = "VPP",
		Wedge = "SW_Corner",
		Quadrant = "SW",
		Ring = "Corner",
		InitialOwner = "Mafia_VelvetRose",
		IsHQ = true,
		PlazaPos = Vector3.new(-838, 1.55, 838),
		CaptureRadius = 31,
		CaptureTime = 9,
		IncomeGold = 32,
		IncomeRep = 6,
		CaptureBountyGold = 260,
		CaptureBountyRep = 60,
		BuffType = "ArmorPatch",
		BuffTitle = "Syndicate Supply Vault (+Heal & Shield)",
		Neighbors = { "SW_Corner_South", "SW_Corner_West" },
		PatrolPoints = makeCornerPatrol(Vector3.new(-838, 1.55, 838)),
	},

	-- ==================== SE QUADRANT (OBSIDIAN SYNDICATE) ====================
	SE_South_Inner = {
		Id = "SE_South_Inner",
		DisplayName = "Harborview Bistro Block",
		ShortCode = "HBB",
		Wedge = "SSE",
		Quadrant = "SE",
		Ring = "Inner",
		InitialOwner = "Mafia_Obsidian",
		IsHQ = false,
		PlazaPos = uvToWorld("SSE", 158, 282, 1.55),
		CaptureRadius = 29,
		CaptureTime = 7,
		IncomeGold = 18,
		IncomeRep = 3,
		CaptureBountyGold = 120,
		CaptureBountyRep = 28,
		BuffType = "Heal",
		BuffTitle = "Harbor Chowder Cart (+45 HP)",
		Neighbors = { "SE_South_Outer", "SE_East_Inner", "SW_South_Inner" },
		PatrolPoints = makeInnerPatrol("SSE", false),
	},
	SE_South_Outer = {
		Id = "SE_South_Outer",
		DisplayName = "Obsidian Crown Plaza",
		ShortCode = "OCP",
		Wedge = "SSE",
		Quadrant = "SE",
		Ring = "Outer",
		InitialOwner = "Mafia_Obsidian",
		IsHQ = true,
		PlazaPos = uvToWorld("SSE", 216, 420, 1.55),
		CaptureRadius = 31,
		CaptureTime = 9,
		IncomeGold = 28,
		IncomeRep = 5,
		CaptureBountyGold = 240,
		CaptureBountyRep = 55,
		BuffType = "ArmorPatch",
		BuffTitle = "Obsidian Tactical Crate (+Heal & Shield)",
		Neighbors = { "SE_South_Inner", "SE_East_Outer", "SW_South_Outer", "SE_Corner_South" },
		PatrolPoints = makeOuterPatrol("SSE"),
	},
	SE_East_Inner = {
		Id = "SE_East_Inner",
		DisplayName = "Saffron Alley District",
		ShortCode = "SAD",
		Wedge = "ESE",
		Quadrant = "SE",
		Ring = "Inner",
		InitialOwner = "Mafia_Obsidian",
		IsHQ = false,
		PlazaPos = uvToWorld("ESE", 158, 282, 1.55),
		CaptureRadius = 29,
		CaptureTime = 7,
		IncomeGold = 18,
		IncomeRep = 3,
		CaptureBountyGold = 120,
		CaptureBountyRep = 28,
		BuffType = "Speed",
		BuffTitle = "Izakaya Matcha Bar (+Speed)",
		Neighbors = { "SE_East_Outer", "SE_South_Inner", "NE_East_Inner" },
		PatrolPoints = makeInnerPatrol("ESE", false),
	},
	SE_East_Outer = {
		Id = "SE_East_Outer",
		DisplayName = "Metro Skyline Block",
		ShortCode = "MSB",
		Wedge = "ESE",
		Quadrant = "SE",
		Ring = "Outer",
		InitialOwner = "Mafia_Obsidian",
		IsHQ = false,
		PlazaPos = uvToWorld("ESE", 216, 420, 1.55),
		CaptureRadius = 30,
		CaptureTime = 8,
		IncomeGold = 22,
		IncomeRep = 4,
		CaptureBountyGold = 150,
		CaptureBountyRep = 35,
		BuffType = "CombatStim",
		BuffTitle = "Roastery Nitro Brew (+HP & Speed)",
		Neighbors = { "SE_East_Inner", "SE_South_Outer", "NE_East_Outer", "SE_Corner_East" },
		PatrolPoints = makeOuterPatrol("ESE"),
	},
	SE_Corner_South = {
		Id = "SE_Corner_South",
		DisplayName = "Pierhead Bistro Row",
		ShortCode = "PBR",
		Wedge = "SE_Corner",
		Quadrant = "SE",
		Ring = "Corner",
		InitialOwner = "Mafia_Obsidian",
		IsHQ = false,
		PlazaPos = Vector3.new(610, 1.55, 838),
		CaptureRadius = 30,
		CaptureTime = 8,
		IncomeGold = 24,
		IncomeRep = 4,
		CaptureBountyGold = 175,
		CaptureBountyRep = 40,
		BuffType = "Heal",
		BuffTitle = "Oyster & Ramen Bar (+45 HP)",
		Neighbors = { "SE_South_Outer", "SE_Corner_East", "SE_Corner_Apex" },
		PatrolPoints = makeCornerPatrol(Vector3.new(610, 1.55, 838)),
	},
	SE_Corner_East = {
		Id = "SE_Corner_East",
		DisplayName = "Anchorage Trade Block",
		ShortCode = "ATB",
		Wedge = "SE_Corner",
		Quadrant = "SE",
		Ring = "Corner",
		InitialOwner = "Mafia_Obsidian",
		IsHQ = false,
		PlazaPos = Vector3.new(838, 1.55, 610),
		CaptureRadius = 30,
		CaptureTime = 8,
		IncomeGold = 24,
		IncomeRep = 4,
		CaptureBountyGold = 175,
		CaptureBountyRep = 40,
		BuffType = "Speed",
		BuffTitle = "Cold Brew Dockside (+Speed)",
		Neighbors = { "SE_East_Outer", "SE_Corner_South", "SE_Corner_Apex" },
		PatrolPoints = makeCornerPatrol(Vector3.new(838, 1.55, 610)),
	},
	SE_Corner_Apex = {
		Id = "SE_Corner_Apex",
		DisplayName = "Obsidian Wharf Heights",
		ShortCode = "OWH",
		Wedge = "SE_Corner",
		Quadrant = "SE",
		Ring = "Corner",
		InitialOwner = "Mafia_Obsidian",
		IsHQ = true,
		PlazaPos = Vector3.new(838, 1.55, 838),
		CaptureRadius = 31,
		CaptureTime = 9,
		IncomeGold = 32,
		IncomeRep = 6,
		CaptureBountyGold = 260,
		CaptureBountyRep = 60,
		BuffType = "ArmorPatch",
		BuffTitle = "Ronin Tactical Cache (+Heal & Shield)",
		Neighbors = { "SE_Corner_South", "SE_Corner_East" },
		PatrolPoints = makeCornerPatrol(Vector3.new(838, 1.55, 838)),
	},
} :: { [string]: TurfBlockSpec }

-- Dynamically reads the controlling faction's Base AccentColor from the live map so territories ALWAYS match their base color!
function TurfConfig.ResolveBaseSlotColor(slot: string): Color3
	local map = Workspace:FindFirstChild("FoodEmpireMap")
	local bases = if map then map:FindFirstChild("PlayerBases") else nil
	local baseModel = if bases then bases:FindFirstChild(slot .. "Base") else nil
	if baseModel then
		local accent = baseModel:GetAttribute("AccentColor")
		if typeof(accent) == "Color3" then
			return accent
		end
	end
	return TurfConfig.PlayerSlotFallbackColors[slot] or Color3.fromRGB(48, 202, 114)
end

function TurfConfig.ResolveFactionColor(factionId: string?): Color3
	if not factionId or factionId == "Neutral" then
		return TurfConfig.NeutralColor
	end

	-- 1. Main Mafia Factions -> read live AccentColor from their physical MafiaFactionBase model first!
	local mafiaSpec = TurfConfig.MafiaFactions[factionId]
	if mafiaSpec then
		for _, hq in ipairs(CollectionService:GetTagged("MafiaFactionBase")) do
			if hq:GetAttribute("FactionId") == factionId then
				local attr = hq:GetAttribute("AccentColor")
				if typeof(attr) == "Color3" then
					return attr
				end
			end
		end
		return mafiaSpec.BaseColor
	end

	-- 2. Player Factions ("Player_<UserId>") -> read live AccentColor from their claimed Castle Base!
	local userIdStr = string.match(factionId, "^Player_(%d+)$")
	if userIdStr then
		local uid = tonumber(userIdStr) or 0
		local player = Players:GetPlayerByUserId(uid)
		if player then
			local slotAttr = player:GetAttribute("BaseSlot")
			if typeof(slotAttr) == "string" then
				return TurfConfig.ResolveBaseSlotColor(slotAttr)
			end
		end
		-- Fallback: scan PlayerBases by OwnerUserId attribute
		local map = Workspace:FindFirstChild("FoodEmpireMap")
		local bases = if map then map:FindFirstChild("PlayerBases") else nil
		if bases then
			for _, baseModel in ipairs(bases:GetChildren()) do
				if baseModel:GetAttribute("OwnerUserId") == uid then
					local accent = baseModel:GetAttribute("AccentColor")
					if typeof(accent) == "Color3" then
						return accent
					end
					local slot = baseModel:GetAttribute("BaseSlot")
					if typeof(slot) == "string" then
						return TurfConfig.ResolveBaseSlotColor(slot)
					end
				end
			end
		end
		return Color3.fromRGB(48, 202, 114)
	end

	-- 3. Direct BaseSlot ("North" / "South" / "East" / "West")
	if TurfConfig.PlayerSlotFallbackColors[factionId] then
		return TurfConfig.ResolveBaseSlotColor(factionId)
	end

	return TurfConfig.NeutralColor
end

function TurfConfig.GetFactionDisplayName(factionId: string?): string
	if not factionId or factionId == "Neutral" then
		return "UNCLAIMED"
	end
	local mafia = TurfConfig.MafiaFactions[factionId]
	if mafia then
		return mafia.ShortName
	end
	local userIdStr = string.match(factionId, "^Player_(%d+)$")
	if userIdStr then
		local player = Players:GetPlayerByUserId(tonumber(userIdStr) or 0)
		if player then
			return string.upper(player.DisplayName)
		end
		return "PLAYER EMPIRE"
	end
	return string.upper(factionId)
end

function TurfConfig.IsMafiaFaction(factionId: string?): boolean
	return factionId ~= nil and TurfConfig.MafiaFactions[factionId] ~= nil
end

return TurfConfig
