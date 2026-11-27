--!strict

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local RecipeConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RecipeConfig")
)
local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local MonetizationConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("MonetizationConfig")
)
local RestaurantSecurityConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RestaurantSecurityConfig")
)
local RestaurantExpansionConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RestaurantExpansionConfig")
)
local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local BaseService = require("./BaseService")
local RestaurantExpansionBuilder = require("./RestaurantExpansionBuilder")
local WarehouseService = require("./WarehouseService")
local PlayerDataService = require("./PlayerDataService")
local CrewService = require("./CrewService")
local SectorService = require("./SectorService")
local ScooterService = require("./ScooterService")
local MonetizationService = require("./MonetizationService")
local VIPOrderService = require("./VIPOrderService")
local RaiderChefService = require("./RaiderChefService")
local ShipmentService = require("./ShipmentService")
local ExpressDeliveryService = require("./ExpressDeliveryService")
local DeliveryRunnerService = require("./DeliveryRunnerService")
local BodyguardService = require("./BodyguardService")
local BlackMarketService = require("./BlackMarketService")
local DayNightService = require("./DayNightService")
local TurfService = require("./TurfService")
local CentralParkBranchService = require("./CentralParkBranchService")
local SpinEventService = require("./SpinEventService")
local SyndicateContractService = require("./SyndicateContractService")
local CentralEventService = require("./CentralEventService")
local WeatherService = require("./WeatherService")
local MafiaBusinessService = require("./MafiaBusinessService")
local BountyService = require("./BountyService")
local SyndicateRaidService = require("./SyndicateRaidService")
local MafiaRestaurantService = require("./MafiaRestaurantService")
local MercenaryMafiaService = require("./MercenaryMafiaService")
local SyndicateFamilyService = require("./SyndicateFamilyService")
local PrestigeVaultService = require("./PrestigeVaultService")
local CombatLockService = require("./CombatLockService")
local NightMafiaRaidService = require("./NightMafiaRaidService")
local DefenseCompanionService = require("./DefenseCompanionService")

local COLLISION_GROUP_PLAYERS = "FoodEmpirePlayers"
local COLLISION_GROUP_NPCS = "FoodEmpireRestaurantNPCs"
local collisionGroupsReady = false

local function ensureRestaurantCollisionGroups(): ()
	if collisionGroupsReady then
		return
	end
	collisionGroupsReady = true
	pcall(function()
		PhysicsService:RegisterCollisionGroup(COLLISION_GROUP_PLAYERS)
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(COLLISION_GROUP_NPCS)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP_PLAYERS, COLLISION_GROUP_NPCS, false)
		PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP_NPCS, COLLISION_GROUP_NPCS, false)
	end)
end

local function assignModelCollisionGroup(model: Instance, groupName: string): ()
	ensureRestaurantCollisionGroups()
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CollisionGroup = groupName
		end
	end
end

type KitchenState = {
	IsCooking: boolean,
	CurrentRecipeId: string?,
	CookEndsAt: number,
	Boosted1: boolean,
	Token1: number,
	IsCooking2: boolean,
	CurrentRecipeId2: string?,
	CookEndsAt2: number,
	Boosted2: boolean,
	Token2: number,
	MasterworkBonusCount: number,
	ReadyDishes: { [string]: number },
}

type WaitingOrder = {
	OrderId: number,
	CustomerName: string,
	DishName: string,
	RecipeId: string?,
	BaseGold: number,
	BaseRep: number,
	IsBeingCooked: boolean,
	Cancelled: boolean?,
	PatienceTotal: number?,
	PatienceExpiresAt: number?,
}

type ReceiptEntry = {
	OrderNo: number,
	CustomerName: string,
	DishName: string,
	GoldEarned: number,
	RepEarned: number,
	ChefName: string,
}

local RestaurantService = {}

local DEFENSE_UPGRADE_COSTS: { [number]: number } = {
	[2] = 2500,
	[3] = 6000,
}

local CUSTOMER_NAMES = { "Alex", "Mia", "Leo", "Chloe", "Kai", "Zoe", "Noah", "Lily", "Sam", "Nora" }
local VIP_CRITIC_NAMES = { "[VIP] Don Vittore", "[CRITIC] M. Laurent", "[VIP] Capo Sterling", "[CRITIC] Chef Vane" }
local SPECIALTY_RECIPE_IDS: { [string]: boolean } = {
	FreshSushi = true,
	SizzlingSteak = true,
	CrabFeast = true,
	EmperorPlatter = true,
	GoldenTunaSashimi = true,
	KingCrabPlatter = true,
}
local STAR_TITLES: { [number]: string } = {
	[1] = "1-STAR STREET DINER",
	[2] = "2-STAR NEIGHBORHOOD BISTRO",
	[3] = "3-STAR SYNDICATE GRILL",
	[4] = "4-STAR GRAND BRASSERIE",
	[5] = "5-STAR IMPERIAL PALACE",
}
local specialtyCookCounts: { [Player]: number } = {}
local HOUSE_SPECIALS: { { Name: string, Gold: number, Rep: number, Color: Color3 } } = {
	{ Name = "Crispy Fish Skewers", Gold = 11, Rep = 3, Color = Color3.fromRGB(78, 192, 234) },
	{ Name = "Chef's Island Soup", Gold = 10, Rep = 3, Color = Color3.fromRGB(246, 178, 62) },
	{ Name = "Garlic Shrimp Bowl", Gold = 12, Rep = 4, Color = Color3.fromRGB(244, 118, 86) },
	{ Name = "Golden Fried Rice", Gold = 10, Rep = 3, Color = Color3.fromRGB(238, 198, 72) },
}

local kitchens: { [Player]: KitchenState } = {}
local waitingOrders: { [Player]: WaitingOrder } = {}
local orderCounters: { [Player]: number } = {}
local receiptHistory: { [Player]: { ReceiptEntry } } = {}

function RestaurantService.GetRestaurantStarInfo(player: Player): { [string]: any }
	local prof = PlayerDataService.GetProfile(player)
	local served = orderCounters[player] or 0
	local specCount = specialtyCookCounts[player] or 0
	local stars = 1
	if prof.RestaurantLevel >= 2 or served >= 2 then
		stars += 1
	end
	if CrewService.GetCrewCount(player) >= 1 and CrewService.GetWaiterCount(player) >= 1 then
		stars += 1
	end
	if prof.OwnsCentralParkBranch or prof.HasDualStove or specCount >= 2 or served >= 5 then
		stars += 1
	end
	if prof.RestaurantLevel >= 3 or prof.HasVIPBooths or prof.Reputation >= 200 or specCount >= 4 then
		stars += 1
	end
	stars = math.clamp(stars, 1, 5)
	local vipBoothMult = if prof.HasVIPBooths then 0.20 else 0.0
	local mult = 1.0 + (stars - 1) * 0.125 + vipBoothMult
	return {
		Stars = stars,
		Title = STAR_TITLES[stars] or "1-STAR STREET DINER",
		BonusPct = math.floor((mult - 1.0) * 100 + 0.5),
		Multiplier = mult,
		DishesServed = served,
		SpecialtyCount = specCount,
		HasVIPBooths = prof.HasVIPBooths == true,
		HasDualStove = prof.HasDualStove == true,
	}
end
local customerModels: { [Player]: { Model } } = {}
local platterModels: { [Player]: { Model } } = {}
local isRunning = false
local customerOrderThread: thread? = nil
local patienceThread: thread? = nil
local nextOrderId = 0
local promptConnections: { RBXScriptConnection } = {}
local playerRemovingConn: RBXScriptConnection? = nil
local unsubBase: (() -> ())? = nil
local stateEvent: RemoteEvent? = nil
local actionFunc: RemoteFunction? = nil
local unsubProfile: (() -> ())? = nil
local unsubWarehouse: (() -> ())? = nil
local unsubSector: (() -> ())? = nil
local unsubShipments: (() -> ())? = nil
local unsubTurf: (() -> ())? = nil

local CUSTOMER_COLORS: { Color3 } = {
	Color3.fromRGB(72, 168, 238),
	Color3.fromRGB(244, 134, 62),
	Color3.fromRGB(148, 92, 224),
	Color3.fromRGB(68, 192, 118),
	Color3.fromRGB(238, 86, 128),
	Color3.fromRGB(242, 186, 48),
}

local HAIR_COLORS: { Color3 } = {
	Color3.fromRGB(58, 38, 24),
	Color3.fromRGB(186, 134, 58),
	Color3.fromRGB(36, 36, 44),
	Color3.fromRGB(132, 62, 34),
}

type DiningSpot = {
	Space: "HQ" | "Base",
	Zone: "Indoor" | "Patio" | "VIP" | "EastWing" | "WestWing" | "RearAtrium" | "SecondFloor" | "ThirdFloor",
	Floor: number?,
	MinLevel: number?,
	TableOffset: Vector3,
	PlateOffset: Vector3,
	SeatOffset: Vector3,
	WaiterOffset: Vector3,
	IsVIP: boolean,
}

-- Unified Dining Pool: Indoor Restaurant Tables + VIP Private Booth + Outdoor String-Lit Pergola Patio!
local ALL_DINING_SPOTS: { DiningSpot } = {
	-- === INDOOR RESTAURANT TABLES (HQ Space) ===
	-- Table 1 (Right Front: 18, 4.08, 6)
	{ Space = "HQ", Zone = "Indoor", TableOffset = Vector3.new(18.0, 4.08, 6.0), PlateOffset = Vector3.new(18.0, 4.10, 7.35), SeatOffset = Vector3.new(18.0, 2.95, 9.25), WaiterOffset = Vector3.new(13.2, 3.6, 6.8), IsVIP = false },
	{ Space = "HQ", Zone = "Indoor", TableOffset = Vector3.new(18.0, 4.08, 6.0), PlateOffset = Vector3.new(18.0, 4.10, 4.65), SeatOffset = Vector3.new(18.0, 2.95, 2.75), WaiterOffset = Vector3.new(13.2, 3.6, 5.2), IsVIP = false },
	-- Table 2 (Right Mid: 18, 4.08, -10)
	{ Space = "HQ", Zone = "Indoor", TableOffset = Vector3.new(18.0, 4.08, -10.0), PlateOffset = Vector3.new(18.0, 4.10, -8.65), SeatOffset = Vector3.new(18.0, 2.95, -6.75), WaiterOffset = Vector3.new(13.2, 3.6, -9.2), IsVIP = false },
	{ Space = "HQ", Zone = "Indoor", TableOffset = Vector3.new(18.0, 4.08, -10.0), PlateOffset = Vector3.new(18.0, 4.10, -11.35), SeatOffset = Vector3.new(18.0, 2.95, -13.25), WaiterOffset = Vector3.new(13.2, 3.6, -10.8), IsVIP = false },
	-- Table 3 (Right Back: 18, 4.08, -22)
	{ Space = "HQ", Zone = "Indoor", TableOffset = Vector3.new(18.0, 4.08, -22.0), PlateOffset = Vector3.new(18.0, 4.10, -20.65), SeatOffset = Vector3.new(18.0, 2.95, -18.75), WaiterOffset = Vector3.new(13.2, 3.6, -21.2), IsVIP = false },
	{ Space = "HQ", Zone = "Indoor", TableOffset = Vector3.new(18.0, 4.08, -22.0), PlateOffset = Vector3.new(18.0, 4.10, -23.35), SeatOffset = Vector3.new(18.0, 2.95, -25.25), WaiterOffset = Vector3.new(13.2, 3.6, -22.8), IsVIP = false },
	-- Table 4 (Left Front: -22, 4.08, 6)
	{ Space = "HQ", Zone = "Indoor", TableOffset = Vector3.new(-22.0, 4.08, 6.0), PlateOffset = Vector3.new(-22.0, 4.10, 7.35), SeatOffset = Vector3.new(-22.0, 2.95, 9.25), WaiterOffset = Vector3.new(-17.0, 3.6, 6.8), IsVIP = false },
	{ Space = "HQ", Zone = "Indoor", TableOffset = Vector3.new(-22.0, 4.08, 6.0), PlateOffset = Vector3.new(-22.0, 4.10, 4.65), SeatOffset = Vector3.new(-22.0, 2.95, 2.75), WaiterOffset = Vector3.new(-17.0, 3.6, 5.2), IsVIP = false },

	-- === OUTDOOR STRING-LIT PERGOLA PATIO (Base Space — FrontDiningPlaza!) ===
	-- Left Pergola Patio (4 Round Marble Cafe Tables)
	{ Space = "Base", Zone = "Patio", TableOffset = Vector3.new(-69.0, 3.72, 43.0), PlateOffset = Vector3.new(-69.0, 3.72, 44.35), SeatOffset = Vector3.new(-69.0, 2.68, 46.5), WaiterOffset = Vector3.new(-63.5, 3.6, 44.5), IsVIP = false },
	{ Space = "Base", Zone = "Patio", TableOffset = Vector3.new(-47.0, 3.72, 43.0), PlateOffset = Vector3.new(-47.0, 3.72, 44.35), SeatOffset = Vector3.new(-47.0, 2.68, 46.5), WaiterOffset = Vector3.new(-41.8, 3.6, 44.5), IsVIP = false },
	{ Space = "Base", Zone = "Patio", TableOffset = Vector3.new(-69.0, 3.72, 62.0), PlateOffset = Vector3.new(-69.0, 3.72, 63.35), SeatOffset = Vector3.new(-69.0, 2.68, 65.5), WaiterOffset = Vector3.new(-63.5, 3.6, 63.5), IsVIP = false },
	{ Space = "Base", Zone = "Patio", TableOffset = Vector3.new(-47.0, 3.72, 62.0), PlateOffset = Vector3.new(-47.0, 3.72, 63.35), SeatOffset = Vector3.new(-47.0, 2.68, 65.5), WaiterOffset = Vector3.new(-41.8, 3.6, 63.5), IsVIP = false },
	-- Right Pergola Patio (4 Round Marble Cafe Tables)
	{ Space = "Base", Zone = "Patio", TableOffset = Vector3.new(47.0, 3.72, 43.0), PlateOffset = Vector3.new(47.0, 3.72, 44.35), SeatOffset = Vector3.new(47.0, 2.68, 46.5), WaiterOffset = Vector3.new(41.8, 3.6, 44.5), IsVIP = false },
	{ Space = "Base", Zone = "Patio", TableOffset = Vector3.new(69.0, 3.72, 43.0), PlateOffset = Vector3.new(69.0, 3.72, 44.35), SeatOffset = Vector3.new(69.0, 2.68, 46.5), WaiterOffset = Vector3.new(63.5, 3.6, 44.5), IsVIP = false },
	{ Space = "Base", Zone = "Patio", TableOffset = Vector3.new(47.0, 3.72, 62.0), PlateOffset = Vector3.new(47.0, 3.72, 63.35), SeatOffset = Vector3.new(47.0, 2.68, 65.5), WaiterOffset = Vector3.new(41.8, 3.6, 63.5), IsVIP = false },
	{ Space = "Base", Zone = "Patio", TableOffset = Vector3.new(69.0, 3.72, 62.0), PlateOffset = Vector3.new(69.0, 3.72, 63.35), SeatOffset = Vector3.new(69.0, 2.68, 65.5), WaiterOffset = Vector3.new(63.5, 3.6, 63.5), IsVIP = false },

	-- === OUTDOOR FRONT BISTRO TERRACE TABLES (HQ Space, right outside entrance!) ===
	{ Space = "HQ", Zone = "Patio", TableOffset = Vector3.new(-32.5, 3.92, 28.0), PlateOffset = Vector3.new(-31.2, 3.92, 28.0), SeatOffset = Vector3.new(-29.2, 2.85, 28.0), WaiterOffset = Vector3.new(-26.0, 3.6, 26.5), IsVIP = false },
	{ Space = "HQ", Zone = "Patio", TableOffset = Vector3.new(33.0, 3.92, 28.0), PlateOffset = Vector3.new(31.7, 3.92, 28.0), SeatOffset = Vector3.new(29.7, 2.85, 28.0), WaiterOffset = Vector3.new(26.5, 3.6, 26.5), IsVIP = false },

	-- === INDOOR VIP PRIVATE BOOTH (HQ Space, unlocked with VIP Booths or HQ Lv.6+) ===
	{ Space = "HQ", Zone = "VIP", TableOffset = Vector3.new(-25.5, 4.00, -6.5), PlateOffset = Vector3.new(-25.5, 4.02, -7.85), SeatOffset = Vector3.new(-25.5, 2.95, -9.45), WaiterOffset = Vector3.new(-19.5, 3.6, -7.2), IsVIP = true },
	{ Space = "HQ", Zone = "VIP", TableOffset = Vector3.new(-25.5, 4.00, -6.5), PlateOffset = Vector3.new(-25.5, 4.02, -5.15), SeatOffset = Vector3.new(-25.5, 2.95, -3.55), WaiterOffset = Vector3.new(-19.5, 3.6, -5.8), IsVIP = true },
}

-- Append reusable Level 2-15 Physical Expansion dining spots (East/West Wings + 2nd/3rd Floors & VIP Banquet)!
for _, extraSpot in ipairs(RestaurantExpansionConfig.EXTRA_DINING_SPOTS) do
	table.insert(ALL_DINING_SPOTS, {
		Space = extraSpot.Space,
		Zone = extraSpot.Zone,
		Floor = extraSpot.Floor,
		MinLevel = extraSpot.MinLevel,
		TableOffset = extraSpot.TableOffset,
		PlateOffset = extraSpot.PlateOffset,
		SeatOffset = extraSpot.SeatOffset,
		WaiterOffset = extraSpot.WaiterOffset,
		IsVIP = extraSpot.IsVIP,
	})
end

-- Append progressive Lv.2-15 Front Wood Restaurant with Roof (FrontDiningPlaza) outdoor dining spots!
for _, patioSpot in ipairs(RestaurantExpansionConfig.FRONT_PAVILION_SPOTS) do
	table.insert(ALL_DINING_SPOTS, {
		Space = patioSpot.Space,
		Zone = patioSpot.Zone,
		Floor = patioSpot.Floor,
		MinLevel = patioSpot.MinLevel,
		TableOffset = patioSpot.TableOffset,
		PlateOffset = patioSpot.PlateOffset,
		SeatOffset = patioSpot.SeatOffset,
		WaiterOffset = patioSpot.WaiterOffset,
		IsVIP = patioSpot.IsVIP,
	})
end

local function resolveSpotWorldPositions(spot: DiningSpot, bCF: CFrame, hqCF: CFrame): (Vector3, Vector3, Vector3, Vector3)
	local refCF = if spot.Space == "Base" then bCF else hqCF
	return (refCF * CFrame.new(spot.TableOffset)).Position,
		(refCF * CFrame.new(spot.PlateOffset)).Position,
		(refCF * CFrame.new(spot.SeatOffset)).Position,
		(refCF * CFrame.new(spot.WaiterOffset)).Position
end

local function getMaxCustomersForHQ(player: Player): number
	local prof = PlayerDataService.GetProfile(player)
	local lv = math.clamp(prof.RestaurantLevel or 1, 1, RestaurantExpansionConfig.MAX_PHYSICAL_TIER)
	local hasVip = prof.HasVIPBooths == true
	local expTier = RestaurantExpansionConfig.GetTierSpec(lv)
	local baseCap = expTier.MaxCustomers
	local vipBonus = if hasVip then 2 else 0
	return math.clamp(baseCap + vipBonus, 4, #ALL_DINING_SPOTS)
end

type WalkingCustomer = {
	OrderId: number,
	Order: WaitingOrder?,
	Name: string,
	IsVIPPatron: boolean,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	BubbleText: TextLabel,
	PatienceBarBg: Frame,
	PatienceBarFill: Frame,
	PatienceTimeLabel: TextLabel,
	PatienceTotal: number,
	PatienceStartedAt: number,
	PatienceExpiresAt: number,
	PatienceActive: boolean,
	IsServed: boolean,
	IsExpired: boolean,
	PenaltyApplied: boolean,
	IsBeingCooked: boolean,
	VipTipPaid: boolean,
	Phase: "Approaching" | "Ordering" | "SeatedWaiting" | "Eating" | "Leaving",
	TableIndex: number,
	IsSeated: boolean,
	TableMeal: Model?,
	EatingFork: Part?,
}

type WaiterNPC = {
	Name: string,
	RoleTitle: string,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	BubbleText: TextLabel,
	HomeOffset: Vector3,
	IsBusy: boolean,
	CarriedPlate: Model?,
}

local activeWalkingCustomers: { [Player]: { WalkingCustomer } } = {}
local activeWaitStaff: { [Player]: { WaiterNPC } } = {}

local function buildDistinctFoodOnPlate(
	parent: Instance,
	plateCF: CFrame,
	dishHint: string,
	weldTarget: BasePart?
): Model
	local meal = Instance.new("Model")
	meal.Name = "DistinctPlate_" .. dishHint

	local function mPart(
		name: string,
		sz: Vector3,
		rel: CFrame,
		col: Color3,
		mat: Enum.Material?,
		shape: Enum.PartType?,
		transp: number?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = plateCF * rel
		p.Color = col
		p.Material = mat or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		if transp then
			p.Transparency = transp
		end
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		if weldTarget then
			p.Anchored = false
			p.Massless = true
			p.Parent = meal
			local w = Instance.new("WeldConstraint")
			w.Part0 = weldTarget
			w.Part1 = p
			w.Parent = p
		else
			p.Anchored = true
			p.Parent = meal
		end
		return p
	end

	local hint = string.lower(dishHint)
	local isEmperor = string.find(hint, "emperor") ~= nil
	local isBurger = string.find(hint, "burger") ~= nil
	local isSushi = string.find(hint, "sushi") ~= nil or string.find(hint, "sashimi") ~= nil
	local isCrab = string.find(hint, "crab") ~= nil or string.find(hint, "shrimp") ~= nil
	local isSteak = string.find(hint, "steak") ~= nil
	local isSmoothie = string.find(hint, "smoothie") ~= nil
	local isSoupOrRice = string.find(hint, "soup") ~= nil or string.find(hint, "rice") ~= nil
	local isGoldenTuna = string.find(hint, "tuna") ~= nil or string.find(hint, "golden") ~= nil

	-- Base porcelain/gold plate (or deep ceramic bowl for soup/rice)
	local plateCol = if isEmperor then Color3.fromRGB(246, 206, 78) else Color3.fromRGB(252, 252, 255)
	local plateDiam = if isEmperor then 2.4 else 2.05
	local basePlate = mPart(
		"PlateBase",
		Vector3.new(0.2, plateDiam, plateDiam),
		CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		plateCol,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder,
		nil
	)
	mPart(
		"PlateRim",
		Vector3.new(0.12, plateDiam - 0.35, plateDiam - 0.35),
		CFrame.new(0, 0.21, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(240, 240, 244),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder,
		nil
	)

	if isBurger then
		-- Sculpted gourmet cheeseburger: bottom bun, beef patty, cheddar cheese, lettuce, tomato, sesame top bun + fries!
		mPart("BottomBun", Vector3.new(0.32, 1.32, 1.32), CFrame.new(0, 0.36, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(224, 158, 72), nil, Enum.PartType.Cylinder, nil)
		mPart("BeefPatty", Vector3.new(0.28, 1.38, 1.38), CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(96, 48, 28), Enum.Material.Slate, Enum.PartType.Cylinder, nil)
		mPart("CheddarCheese", Vector3.new(1.36, 0.12, 1.36), CFrame.new(0, 0.80, 0) * CFrame.Angles(0, math.rad(22), 0), Color3.fromRGB(255, 202, 42), nil, nil, nil)
		mPart("Lettuce", Vector3.new(0.14, 1.46, 1.46), CFrame.new(0, 0.90, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(78, 194, 72), nil, Enum.PartType.Cylinder, nil)
		mPart("Tomato", Vector3.new(0.14, 1.24, 1.24), CFrame.new(0, 1.02, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(228, 52, 44), nil, Enum.PartType.Cylinder, nil)
		mPart("TopBun", Vector3.new(1.34, 0.72, 1.34), CFrame.new(0, 1.22, 0), Color3.fromRGB(232, 166, 74), nil, Enum.PartType.Ball, nil)
		-- Crispy side fries
		for fi = -1, 1 do
			mPart("Fry" .. tostring(fi), Vector3.new(0.14, 0.7, 0.14), CFrame.new(0.68, 0.48, fi * 0.22) * CFrame.Angles(math.rad(14 * fi), 0, math.rad(-25)), Color3.fromRGB(248, 208, 66), nil, nil, nil)
		end
	elseif isSushi then
		-- 3 distinct Maki/Nigiri sushi rolls + pink salmon topping + green wasabi + soy dish!
		local sushiCol = if isGoldenTuna then Color3.fromRGB(255, 212, 62) else Color3.fromRGB(248, 118, 92)
		for i = -1, 1 do
			local xo = i * 0.56
			mPart("SushiNori" .. tostring(i), Vector3.new(0.42, 0.52, 0.52), CFrame.new(xo, 0.42, -0.15) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(22, 34, 24), nil, Enum.PartType.Cylinder, nil)
			mPart("SushiRice" .. tostring(i), Vector3.new(0.46, 0.44, 0.44), CFrame.new(xo, 0.44, -0.15) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(250, 250, 246), nil, Enum.PartType.Cylinder, nil)
			mPart("SushiFish" .. tostring(i), Vector3.new(0.36, 0.18, 0.52), CFrame.new(xo, 0.72, -0.15), sushiCol, if isGoldenTuna then Enum.Material.Neon else Enum.Material.SmoothPlastic, nil, nil)
		end
		mPart("Wasabi", Vector3.new(0.34, 0.28, 0.34), CFrame.new(-0.45, 0.36, 0.5), Color3.fromRGB(122, 208, 72), nil, Enum.PartType.Ball, nil)
		mPart("SoyDish", Vector3.new(0.16, 0.52, 0.52), CFrame.new(0.45, 0.32, 0.5) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(48, 26, 18), nil, Enum.PartType.Cylinder, nil)
	elseif isCrab then
		-- Crimson King Crab shell & splayed legs on crushed ocean ice!
		mPart("IceBed", Vector3.new(0.14, 1.7, 1.7), CFrame.new(0, 0.28, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(186, 232, 255), Enum.Material.Ice, Enum.PartType.Cylinder, 0.25)
		mPart("CrabShell", Vector3.new(1.15, 0.62, 1.05), CFrame.new(0, 0.58, 0), Color3.fromRGB(228, 54, 42), nil, Enum.PartType.Ball, nil)
		for _, side in ipairs({ -1, 1 }) do
			for leg = -1, 1 do
				mPart("CrabLeg", Vector3.new(0.75, 0.16, 0.16), CFrame.new(side * 0.68, 0.42, leg * 0.34) * CFrame.Angles(0, math.rad(leg * 18 * side), math.rad(side * -18)), Color3.fromRGB(238, 72, 52), nil, nil, nil)
			end
			mPart("CrabClaw", Vector3.new(0.38, 0.32, 0.56), CFrame.new(side * 0.42, 0.48, -0.68) * CFrame.Angles(0, math.rad(side * -24), 0), Color3.fromRGB(246, 86, 56), nil, Enum.PartType.Ball, nil)
		end
	elseif isSteak then
		-- Sizzling T-bone steak with char marks, melting golden butter pat, roasted potatoes & green broccoli!
		mPart("SteakSlab", Vector3.new(1.38, 0.36, 0.96), CFrame.new(-0.1, 0.42, -0.1) * CFrame.Angles(0, math.rad(12), 0), Color3.fromRGB(118, 52, 34), Enum.Material.Slate, nil, nil)
		mPart("GrillMark1", Vector3.new(1.1, 0.06, 0.1), CFrame.new(-0.1, 0.62, -0.25) * CFrame.Angles(0, math.rad(12), 0), Color3.fromRGB(48, 22, 14), nil, nil, nil)
		mPart("GrillMark2", Vector3.new(1.1, 0.06, 0.1), CFrame.new(-0.1, 0.62, 0.05) * CFrame.Angles(0, math.rad(12), 0), Color3.fromRGB(48, 22, 14), nil, nil, nil)
		mPart("HerbButter", Vector3.new(0.38, 0.18, 0.38), CFrame.new(-0.1, 0.68, -0.1) * CFrame.Angles(0, math.rad(35), 0), Color3.fromRGB(255, 228, 102), nil, nil, nil)
		mPart("Potato1", Vector3.new(0.46, 0.36, 0.46), CFrame.new(0.55, 0.42, 0.45), Color3.fromRGB(216, 158, 66), nil, Enum.PartType.Ball, nil)
		mPart("Broccoli", Vector3.new(0.48, 0.48, 0.48), CFrame.new(-0.45, 0.46, 0.52), Color3.fromRGB(58, 162, 58), Enum.Material.Grass, Enum.PartType.Ball, nil)
	elseif isSmoothie then
		-- Tall Tropical Mango Smoothie glass with whipped cream, bright straw & orange wheel!
		mPart("SmoothieCup", Vector3.new(1.45, 0.88, 0.88), CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 192, 42), Enum.Material.Glass, Enum.PartType.Cylinder, 0.12)
		mPart("WhippedTop", Vector3.new(0.84, 0.45, 0.84), CFrame.new(0, 1.72, 0), Color3.fromRGB(255, 250, 238), nil, Enum.PartType.Ball, nil)
		mPart("Straw", Vector3.new(0.11, 0.95, 0.11), CFrame.new(0.18, 2.02, 0) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(246, 78, 118), nil, nil, nil)
		mPart("OrangeSlice", Vector3.new(0.12, 0.56, 0.56), CFrame.new(-0.42, 1.65, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 138, 32), nil, Enum.PartType.Cylinder, nil)
	elseif isSoupOrRice then
		-- Deep ceramic ramen/soup/fried-rice bowl with steaming golden contents & chopsticks!
		mPart("SoupBowl", Vector3.new(0.68, 1.55, 1.55), CFrame.new(0, 0.56, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(186, 52, 44), nil, Enum.PartType.Cylinder, nil)
		mPart("BrothTop", Vector3.new(0.16, 1.36, 1.36), CFrame.new(0, 0.88, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(246, 186, 62), nil, Enum.PartType.Cylinder, nil)
		mPart("EggHalf", Vector3.new(0.4, 0.2, 0.34), CFrame.new(-0.28, 0.98, -0.15), Color3.fromRGB(255, 252, 244), nil, Enum.PartType.Ball, nil)
		mPart("Yolk", Vector3.new(0.22, 0.16, 0.22), CFrame.new(-0.28, 1.04, -0.15), Color3.fromRGB(255, 166, 32), nil, Enum.PartType.Ball, nil)
		mPart("Scallion", Vector3.new(0.32, 0.14, 0.32), CFrame.new(0.25, 0.98, 0.2), Color3.fromRGB(72, 198, 72), nil, Enum.PartType.Ball, nil)
		mPart("Chopstick1", Vector3.new(1.75, 0.08, 0.08), CFrame.new(0, 0.98, 0.55) * CFrame.Angles(0, math.rad(14), 0), Color3.fromRGB(188, 136, 76), Enum.Material.Wood, nil, nil)
	elseif isEmperor then
		-- Grand Emperor's Feast Platter: steak + golden tuna + lobster tail + crown garnish!
		mPart("FeastSteak", Vector3.new(0.95, 0.36, 0.72), CFrame.new(-0.48, 0.44, 0), Color3.fromRGB(132, 56, 36), Enum.Material.Slate, nil, nil)
		mPart("FeastLobster", Vector3.new(0.95, 0.4, 0.65), CFrame.new(0.48, 0.46, 0), Color3.fromRGB(242, 68, 52), nil, Enum.PartType.Ball, nil)
		mPart("FeastGoldCrown", Vector3.new(0.46, 0.56, 0.46), CFrame.new(0, 0.76, -0.35), Color3.fromRGB(255, 218, 64), Enum.Material.Neon, Enum.PartType.Ball, nil)
		mPart("FeastGreens", Vector3.new(0.6, 0.28, 0.5), CFrame.new(0, 0.38, 0.55), Color3.fromRGB(68, 188, 76), Enum.Material.Grass, Enum.PartType.Ball, nil)
	else
		-- Grilled Island Fish / Golden Tuna Fillet with tail fin, lemon slice & herbs!
		local fishCol = if isGoldenTuna then Color3.fromRGB(255, 206, 56) else Color3.fromRGB(92, 178, 218)
		local fishMat = if isGoldenTuna then Enum.Material.Neon else Enum.Material.SmoothPlastic
		mPart("FishFillet", Vector3.new(1.45, 0.46, 0.78), CFrame.new(-0.12, 0.46, 0), fishCol, fishMat, Enum.PartType.Ball, nil)
		mPart("FishTail", Vector3.new(0.52, 0.34, 0.68), CFrame.new(0.65, 0.44, 0) * CFrame.Angles(0, math.rad(25), 0), fishCol, fishMat, nil, nil)
		mPart("LemonSlice", Vector3.new(0.14, 0.52, 0.52), CFrame.new(-0.2, 0.7, 0.28) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 232, 58), nil, Enum.PartType.Cylinder, nil)
		mPart("HerbSprig", Vector3.new(0.45, 0.16, 0.38), CFrame.new(0.15, 0.68, -0.25), Color3.fromRGB(64, 186, 68), Enum.Material.Grass, Enum.PartType.Ball, nil)
	end

	-- Subtle savory steam rising off fresh plated dishes when served on a dining table!
	if not weldTarget and not isSmoothie then
		local steam = Instance.new("ParticleEmitter")
		steam.Name = "DishSteam"
		steam.Color = ColorSequence.new(Color3.fromRGB(242, 238, 230))
		steam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.65),
			NumberSequenceKeypoint.new(0.5, 0.78),
			NumberSequenceKeypoint.new(1, 1.0),
		})
		steam.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.28),
			NumberSequenceKeypoint.new(1, 0.85),
		})
		steam.Lifetime = NumberRange.new(1.0, 1.6)
		steam.Rate = 6
		steam.Speed = NumberRange.new(0.8, 1.6)
		steam.SpreadAngle = Vector2.new(14, 14)
		steam.EmissionDirection = Enum.NormalId.Top
		steam.Parent = basePlate
	end

	meal.PrimaryPart = basePlate
	meal.Parent = parent
	return meal
end

local function clearCustomers(player: Player): ()
	local list = customerModels[player]
	if list then
		for _, m in ipairs(list) do
			if m.Parent then
				m:Destroy()
			end
		end
		customerModels[player] = nil
	end
	local wList = activeWalkingCustomers[player]
	if wList then
		for _, wc in ipairs(wList) do
			wc.PatienceActive = false
			wc.IsExpired = true
			wc.IsBeingCooked = false
			if wc.Order then
				wc.Order.Cancelled = true
				wc.Order.IsBeingCooked = false
			end
			if wc.TableMeal and wc.TableMeal.Parent then
				wc.TableMeal:Destroy()
			end
			if wc.Model.Parent then
				wc.Model:Destroy()
			end
		end
		activeWalkingCustomers[player] = nil
	end
	waitingOrders[player] = nil
	local staff = activeWaitStaff[player]
	if staff then
		for _, w in ipairs(staff) do
			if w.CarriedPlate and w.CarriedPlate.Parent then
				w.CarriedPlate:Destroy()
			end
			if w.Model.Parent then
				w.Model:Destroy()
			end
		end
		activeWaitStaff[player] = nil
	end
end

local function buildWalkingCustomerModel(
	parent: Instance,
	custName: string,
	spawnPos: Vector3,
	styleIdx: number
): (Model, Humanoid, BasePart, TextLabel, Frame, Frame, TextLabel)
	local rig = MafiaVisualBuilder.BuildCustomerRig("CityCustomer_" .. custName, styleIdx, 1.0, CFrame.new(spawnPos))
	local cust = rig.Model
	local root = rig.Root
	local head = rig.Head

	local bb = Instance.new("BillboardGui")
	bb.Name = "CustomerBubble"
	bb.Size = UDim2.fromOffset(186, 42)
	bb.StudsOffset = Vector3.new(0, 2.35, 0)
	bb.MaxDistance = 48
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Name = "BubbleText"
	lbl.Position = UDim2.fromOffset(0, 0)
	lbl.Size = UDim2.new(1, 0, 0, 24)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 17, 21)
	lbl.BackgroundTransparency = 0.14
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = custName .. "  |  Arriving"
	lbl.TextSize = 10
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.TextColor3 = Color3.fromRGB(232, 228, 218)
	lbl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 5)
	c.Parent = lbl
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(152, 126, 74)
	st.Thickness = 1
	st.Parent = lbl

	-- Overhead Customer Patience Bar (hidden while walking in; activates when seated!)
	local pBg = Instance.new("Frame")
	pBg.Name = "PatienceBarBg"
	pBg.Position = UDim2.new(0.03, 0, 0, 31)
	pBg.Size = UDim2.new(0.94, 0, 0, 15)
	pBg.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
	pBg.BackgroundTransparency = 0.06
	pBg.ClipsDescendants = true
	pBg.Visible = false
	pBg.Parent = bb
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 4)
	pc.Parent = pBg
	local pst = Instance.new("UIStroke")
	pst.Color = Color3.fromRGB(72, 76, 88)
	pst.Thickness = 1
	pst.Parent = pBg

	local pFill = Instance.new("Frame")
	pFill.Name = "Fill"
	pFill.Size = UDim2.fromScale(1, 1)
	pFill.BackgroundColor3 = Color3.fromRGB(56, 158, 102)
	pFill.BorderSizePixel = 0
	pFill.Parent = pBg
	local pfc = Instance.new("UICorner")
	pfc.CornerRadius = UDim.new(0, 3)
	pfc.Parent = pFill

	local pLbl = Instance.new("TextLabel")
	pLbl.Name = "PatienceText"
	pLbl.Size = UDim2.fromScale(1, 1)
	pLbl.BackgroundTransparency = 1
	pLbl.Font = Enum.Font.GothamBlack
	pLbl.Text = "WAIT 18s"
	pLbl.TextSize = 9
	pLbl.TextColor3 = Color3.fromRGB(246, 246, 248)
	pLbl.ZIndex = 3
	pLbl.Parent = pBg

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 100
	hum.Health = 100
	hum.WalkSpeed = 18 + math.random() * 2.5
	hum.HipHeight = 2.42
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = cust

	CollectionService:AddTag(cust, "AnimatedCustomerLimbs")
	assignModelCollisionGroup(cust, COLLISION_GROUP_NPCS)
	cust.Parent = parent
	return cust, hum, root, lbl, pBg, pFill, pLbl
end

local function setCustomerSeated(wc: WalkingCustomer, seated: boolean, seatWorldPos: Vector3?, lookAtWorldPos: Vector3?): ()
	if not wc.Model.Parent or not wc.Root.Parent then
		return
	end
	wc.IsSeated = seated
	if seated then
		wc.Humanoid.WalkSpeed = 0
		wc.Humanoid.HipHeight = 1.45
		wc.Root.Anchored = true
		if seatWorldPos and lookAtWorldPos then
			local flatLook = Vector3.new(lookAtWorldPos.X, seatWorldPos.Y, lookAtWorldPos.Z)
			wc.Root.CFrame = CFrame.lookAt(seatWorldPos, flatLook)
		end
		wc.Model:SetAttribute("DiningPose", "SeatedWaiting")
	else
		wc.Model:SetAttribute("DiningPose", "Standing")
		if wc.EatingFork and wc.EatingFork.Parent then
			wc.EatingFork:Destroy()
			wc.EatingFork = nil
		end
		-- Lift cleanly above the floor slab BEFORE un-anchoring so 2nd/3rd-floor guests NEVER dip into the ceiling!
		wc.Root.CFrame = wc.Root.CFrame + Vector3.new(0, 1.25, 0)
		wc.Humanoid.HipHeight = 2.42
		wc.Humanoid.WalkSpeed = 19
		wc.Root.Anchored = false
	end
end

local function attachEatingFork(wc: WalkingCustomer): ()
	if wc.EatingFork and wc.EatingFork.Parent then
		return
	end
	local rHand = wc.Model:FindFirstChild("RightHand") or wc.Model:FindFirstChild("RightLowerArm")
	if not rHand or not rHand:IsA("BasePart") then
		return
	end
	local fork = Instance.new("Part")
	fork.Name = "DiningFork"
	fork.Size = Vector3.new(0.08, 0.06, 0.72)
	fork.Color = Color3.fromRGB(204, 210, 222)
	fork.Material = Enum.Material.Metal
	fork.CanCollide = false
	fork.CanTouch = false
	fork.CanQuery = false
	fork.Massless = true
	fork.CFrame = rHand.CFrame * CFrame.new(0, -0.02, -0.40)
	fork.Parent = wc.Model
	local w = Instance.new("WeldConstraint")
	w.Part0 = rHand
	w.Part1 = fork
	w.Parent = fork
	wc.EatingFork = fork
end

local function moveNpcTo(model: Model, hum: Humanoid, root: BasePart, dest: Vector3, timeoutSec: number, arriveDist: number?): boolean
	local started = os.clock()
	local stopRadius = arriveDist or 4.2
	while isRunning and model.Parent and hum.Health > 0 do
		if root.Anchored then
			return true
		end
		local deltaXZ = Vector3.new(dest.X - root.Position.X, 0, dest.Z - root.Position.Z).Magnitude
		local deltaY = math.abs(dest.Y - root.Position.Y)
		if deltaXZ <= stopRadius and deltaY <= 5.5 then
			return true
		end
		hum:MoveTo(dest)
		if (os.clock() - started) >= timeoutSec then
			-- If multi-floor stair climb timed out on the wrong floor, snap cleanly onto the target landing (never trap inside a ceiling!)
			if deltaY > 4.5 or deltaXZ > stopRadius + 6 then
				model:PivotTo(CFrame.new(dest + Vector3.new(0, 1.2, 0)))
			end
			return true
		end
		task.wait(0.12)
	end
	return false
end

local function moveCustomerTo(wc: WalkingCustomer, dest: Vector3, timeoutSec: number): boolean
	return moveNpcTo(wc.Model, wc.Humanoid, wc.Root, dest, timeoutSec, 4.2)
end

local function getBaseGeometry(player: Player): (Model?, BasePart?, Model?)
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then return nil, nil, nil end
	local baseModel = BaseService.GetBaseModel(slot)
	if not baseModel then return nil, nil, nil end
	local bp = baseModel:FindFirstChild("BasePivot") or baseModel.PrimaryPart
	local hq = baseModel:FindFirstChild("RestaurantHQ")
	if not bp or not bp:IsA("BasePart") or not hq or not hq:IsA("Model") or not hq.PrimaryPart then
		return nil, nil, nil
	end
	return baseModel, bp, hq
end

local function buildWaiterModel(
	parent: Instance,
	staffName: string,
	roleTitle: string,
	isFemale: boolean,
	spawnPos: Vector3
): (Model, Humanoid, BasePart, TextLabel)
	local modelName = if isFemale then "RestaurantWaitress" else "RestaurantWaiter"
	local rig = MafiaVisualBuilder.BuildWaiterRig(modelName, isFemale, 1.02, CFrame.new(spawnPos))
	local npc = rig.Model
	local root = rig.Root
	local head = rig.Head

	local bb = Instance.new("BillboardGui")
	bb.Name = "StaffBadge"
	bb.Size = UDim2.fromOffset(172, 26)
	bb.StudsOffset = Vector3.new(0, 2.25, 0)
	bb.MaxDistance = 40
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Name = "BubbleText"
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 17, 21)
	lbl.BackgroundTransparency = 0.14
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = roleTitle .. " " .. staffName .. "  |  READY"
	lbl.TextSize = 9
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.TextColor3 = Color3.fromRGB(224, 198, 128)
	lbl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 5)
	c.Parent = lbl
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(152, 126, 74)
	st.Thickness = 1
	st.Parent = lbl

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 120
	hum.Health = 120
	hum.WalkSpeed = 32
	hum.HipHeight = 2.45
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = npc

	CollectionService:AddTag(npc, "AnimatedCustomerLimbs")
	assignModelCollisionGroup(npc, COLLISION_GROUP_NPCS)
	npc.Parent = parent
	return npc, hum, root, lbl
end

local function spawnWaitStaffForPlayer(player: Player): ()
	local baseModel, _, hq = getBaseGeometry(player)
	if not baseModel or not hq or not hq.PrimaryPart then
		return
	end
	local existing = activeWaitStaff[player]
	if existing then
		for _, w in ipairs(existing) do
			if w.CarriedPlate and w.CarriedPlate.Parent then w.CarriedPlate:Destroy() end
			if w.Model.Parent then w.Model:Destroy() end
		end
	end

	-- Players start with 0 waiters and must hire them with Gold!
	local hiredCount = CrewService.GetWaiterCount(player)
	if hiredCount <= 0 then
		activeWaitStaff[player] = {}
		return
	end

	local staffDefs = {
		{ Name = "Marco", Title = "WAITER", IsFemale = false, Home = Vector3.new(-5.5, 3.6, -5.0) },
		{ Name = "Sofia", Title = "WAITRESS", IsFemale = true, Home = Vector3.new(5.5, 3.6, -5.0) },
		{ Name = "Luca", Title = "HEAD WAITER", IsFemale = false, Home = Vector3.new(0.0, 3.6, -1.5) },
		{ Name = "Elena", Title = "EXPRESS WAITRESS", IsFemale = true, Home = Vector3.new(-9.0, 3.6, 2.0) },
		{ Name = "Dante", Title = "VIP STEWARD", IsFemale = false, Home = Vector3.new(9.0, 3.6, 2.0) },
	}
	local list: { WaiterNPC } = {}
	for i = 1, math.min(hiredCount, #staffDefs) do
		local def = staffDefs[i]
		local worldHome = (hq.PrimaryPart.CFrame * CFrame.new(def.Home)).Position
		local model, hum, root, lbl = buildWaiterModel(baseModel, def.Name, def.Title, def.IsFemale, worldHome)
		model:SetAttribute("IsWaiterStaff", true)
		model:SetAttribute("WaiterState", "Idle")
		table.insert(list, {
			Name = def.Name,
			RoleTitle = def.Title,
			Model = model,
			Humanoid = hum,
			Root = root,
			BubbleText = lbl,
			HomeOffset = def.Home,
			IsBusy = false,
			CarriedPlate = nil,
		})
	end
	activeWaitStaff[player] = list
end

local function pickAvailableTableIndex(player: Player): number
	local prof = PlayerDataService.GetProfile(player)
	local hqLevel = prof.RestaurantLevel or 1
	local allowVIP = (prof.HasVIPBooths == true) or (hqLevel >= 5)
	local used: { [number]: boolean } = {}
	local indoorActive = 0
	local patioActive = 0
	local expandedActive = 0
	local list = activeWalkingCustomers[player]
	if list then
		for _, wc in ipairs(list) do
			used[wc.TableIndex] = true
			local sp = ALL_DINING_SPOTS[wc.TableIndex]
			if sp then
				if sp.Zone == "Patio" then
					patioActive += 1
				elseif sp.Zone == "EastWing" or sp.Zone == "WestWing" or sp.Zone == "SecondFloor" or sp.Zone == "ThirdFloor" then
					expandedActive += 1
				else
					indoorActive += 1
				end
			end
		end
	end

	local expandedFree: { number } = {}
	local preferredFree: { number } = {}
	local anyFree: { number } = {}
	local preferPatio = (patioActive <= math.max(2, math.floor((indoorActive + expandedActive) * 0.85)))
	for i, spot in ipairs(ALL_DINING_SPOTS) do
		local minLv = spot.MinLevel or 1
		if hqLevel >= minLv and (not spot.IsVIP or allowVIP) and not used[i] then
			table.insert(anyFree, i)
			if spot.Zone == "EastWing" or spot.Zone == "WestWing" or spot.Zone == "SecondFloor" or spot.Zone == "ThirdFloor" then
				table.insert(expandedFree, i)
			end
			if (preferPatio and spot.Zone == "Patio") or ((not preferPatio) and spot.Zone ~= "Patio") then
				table.insert(preferredFree, i)
			end
		end
	end

	-- Balance seating smoothly across the upgraded Front Wood Restaurant Pavilions & Indoor Multi-Floor Wings!
	if preferPatio and #preferredFree > 0 then
		return preferredFree[math.random(1, #preferredFree)]
	end
	if #expandedFree > 0 and expandedActive <= math.max(2, indoorActive) then
		return expandedFree[math.random(1, #expandedFree)]
	end
	if #preferredFree > 0 then
		return preferredFree[math.random(1, #preferredFree)]
	end
	if #anyFree > 0 then
		return anyFree[math.random(1, #anyFree)]
	end
	return 1
end

local spawnSingleCityCustomer: (player: Player, startDistanceZ: number) -> ()

local function sendCustomerToast(player: Player, message: string): ()
	if not player.Parent then
		return
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local toastEv = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if toastEv and toastEv:IsA("RemoteEvent") then
		toastEv:FireClient(player, message)
	end
end

local function createOrderForGuest(player: Player, custName: string, isVIPPatron: boolean): WaitingOrder
	nextOrderId += 1
	local vipMult = if isVIPPatron then 1.65 else 1.0
	local bestRecipe = RestaurantService.PickBestAvailableRecipe(player)
	if bestRecipe then
		local spec = RecipeConfig.Recipes[bestRecipe]
		return {
			OrderId = nextOrderId,
			CustomerName = custName,
			DishName = if spec then spec.DisplayName else bestRecipe,
			RecipeId = bestRecipe,
			BaseGold = math.floor((if spec then spec.CoinsReward else 40) * vipMult),
			BaseRep = math.floor((if spec then spec.ReputationReward else 10) * vipMult),
			IsBeingCooked = false,
			Cancelled = false,
		}
	end
	local special = HOUSE_SPECIALS[math.random(1, #HOUSE_SPECIALS)]
	return {
		OrderId = nextOrderId,
		CustomerName = custName,
		DishName = special.Name,
		RecipeId = nil,
		BaseGold = math.floor(special.Gold * vipMult),
		BaseRep = math.floor(special.Rep * vipMult),
		IsBeingCooked = false,
		Cancelled = false,
	}
end

local function findMostUrgentWaitingCustomer(player: Player, allowBeingCooked: boolean?): WalkingCustomer?
	local list = activeWalkingCustomers[player]
	if not list then
		return nil
	end
	local best: WalkingCustomer? = nil
	local bestExpires = math.huge
	for _, wc in ipairs(list) do
		if wc.Model.Parent
			and wc.Phase == "SeatedWaiting"
			and wc.PatienceActive
			and not wc.IsServed
			and not wc.IsExpired
			and (allowBeingCooked or not wc.IsBeingCooked)
		then
			if wc.PatienceExpiresAt < bestExpires then
				bestExpires = wc.PatienceExpiresAt
				best = wc
			end
		end
	end
	return best
end

local function syncPrimaryWaitingOrder(player: Player): ()
	local urgent = findMostUrgentWaitingCustomer(player, true)
	if urgent and urgent.Order and not urgent.Order.Cancelled then
		waitingOrders[player] = urgent.Order
	else
		waitingOrders[player] = nil
	end
end

local function stopCustomerPatience(wc: WalkingCustomer): ()
	wc.PatienceActive = false
	if wc.PatienceBarBg.Parent then
		wc.PatienceBarBg.Visible = false
	end
end

local function startCustomerPatience(player: Player, wc: WalkingCustomer, zoneTag: string): ()
	if wc.IsServed or wc.IsExpired or not wc.Model.Parent then
		return
	end
	local cfg = RestaurantSecurityConfig.CustomerPatience
	local minSec = math.max(5, math.floor(cfg.MinSeconds))
	local maxSec = math.max(minSec, math.floor(cfg.MaxSeconds))
	local dur = math.random(minSec, maxSec)
	local now = os.clock()

	local order = createOrderForGuest(player, wc.Name, wc.IsVIPPatron)
	order.PatienceTotal = dur
	order.PatienceExpiresAt = now + dur

	wc.OrderId = order.OrderId
	wc.Order = order
	wc.PatienceTotal = dur
	wc.PatienceStartedAt = now
	wc.PatienceExpiresAt = now + dur
	wc.PatienceActive = true
	wc.IsBeingCooked = false

	wc.Model:SetAttribute("CustomerOrderId", wc.OrderId)
	wc.Model:SetAttribute("PatienceTotal", dur)
	wc.Model:SetAttribute("PatienceExpiresAt", wc.PatienceExpiresAt)
	wc.Model:SetAttribute("PatienceExpired", false)

	wc.BubbleText.Text = string.format("%s (%s): 1x %s please!", wc.Name, zoneTag, order.DishName)
	wc.PatienceBarBg.Visible = true
	wc.PatienceBarFill.Size = UDim2.fromScale(1, 1)
	wc.PatienceBarFill.BackgroundColor3 = Color3.fromRGB(56, 158, 102)
	wc.PatienceTimeLabel.Text = string.format("WAIT %ds", dur)

	syncPrimaryWaitingOrder(player)
	RestaurantService.PushStateToClient(player)
end

local function handleCustomerPatienceExpired(player: Player, wc: WalkingCustomer): ()
	-- Strict atomic guard: never punish twice, never expire an already-served customer
	if wc.IsExpired or wc.IsServed or wc.PenaltyApplied then
		return
	end
	wc.IsExpired = true
	wc.PenaltyApplied = true
	wc.PatienceActive = false
	wc.IsBeingCooked = false
	wc.Phase = "Leaving"

	if wc.Order then
		wc.Order.Cancelled = true
		wc.Order.IsBeingCooked = false
	end
	syncPrimaryWaitingOrder(player)

	if wc.Model.Parent then
		wc.Model:SetAttribute("PatienceExpired", true)
		wc.Model:SetAttribute("DiningPose", "Unhappy")
		wc.BubbleText.Text = string.format("%s: Waited too long! Leaving!", wc.Name)
		wc.BubbleText.TextColor3 = Color3.fromRGB(238, 108, 114)
		wc.PatienceBarBg.Visible = true
		wc.PatienceBarFill.Size = UDim2.fromScale(0, 1)
		wc.PatienceBarFill.BackgroundColor3 = Color3.fromRGB(196, 46, 56)
		wc.PatienceTimeLabel.Text = "UNHAPPY - NO PAY"
	end

	local cfg = RestaurantSecurityConfig.CustomerPatience
	local lostRep = PlayerDataService.DeductReputation(player, cfg.ExpiryReputationLoss)
	if lostRep > 0 then
		sendCustomerToast(player, string.format("%s left unhappy (unserved)! -%d Reputation.", wc.Name, lostRep))
	else
		sendCustomerToast(player, string.format("%s left unhappy (unserved) without paying!", wc.Name))
	end
	RestaurantService.PushStateToClient(player)

	task.spawn(function()
		task.wait(cfg.UnhappyPauseSeconds)
		local baseModel, bp, hq = getBaseGeometry(player)
		if wc.TableMeal and wc.TableMeal.Parent then
			wc.TableMeal:Destroy()
			wc.TableMeal = nil
		end
		if wc.Model.Parent then
			setCustomerSeated(wc, false, nil, nil)
			if wc.PatienceBarBg.Parent then
				wc.PatienceBarBg.Visible = false
			end
			if baseModel and bp and hq and hq.PrimaryPart then
				local bCF = bp.CFrame
				local hqCF = hq.PrimaryPart.CFrame
				local spot = ALL_DINING_SPOTS[wc.TableIndex] or ALL_DINING_SPOTS[1]
				local doorWaypointPos = (hqCF * CFrame.new(0, 3.6, 22.0)).Position
				local wp = RestaurantExpansionConfig.STAIR_WAYPOINTS
				if spot.Floor == 3 or spot.Zone == "ThirdFloor" then
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.Floor3Entry)).Position, 7)
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.Floor3TopLanding)).Position, 6)
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.Floor2StairMid)).Position, 6)
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.Floor2StairStart)).Position, 6)
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.TopLanding)).Position, 6)
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.MidStairs)).Position, 6)
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.BottomLobby)).Position, 6)
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.RearAtriumDoor)).Position, 6)
					moveCustomerTo(wc, doorWaypointPos, 7)
				elseif spot.Floor == 2 or spot.Zone == "SecondFloor" then
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.Floor2Entry)).Position, 7)
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.TopLanding)).Position, 6)
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.MidStairs)).Position, 6)
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.BottomLobby)).Position, 6)
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.RearAtriumDoor)).Position, 6)
					moveCustomerTo(wc, doorWaypointPos, 7)
				elseif spot.Zone == "EastWing" then
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.EastWingArchway)).Position, 7)
					moveCustomerTo(wc, doorWaypointPos, 7)
				elseif spot.Zone == "WestWing" then
					moveCustomerTo(wc, (hqCF * CFrame.new(wp.WestWingArchway)).Position, 7)
					moveCustomerTo(wc, doorWaypointPos, 7)
				elseif spot.Zone ~= "Patio" then
					moveCustomerTo(wc, doorWaypointPos, 7)
				end
				local frontGateExit = (bCF * CFrame.new(math.random(-6, 6), 3.6, 108.0)).Position
				local cityRoadExit = (bCF * CFrame.new(math.random(-16, 16), 3.6, 225.0)).Position
				moveCustomerTo(wc, frontGateExit, 14)
				moveCustomerTo(wc, cityRoadExit, 16)
			end
		end
		if wc.Model.Parent then
			wc.Model:Destroy()
		end
		local curList = activeWalkingCustomers[player]
		if curList then
			local idx = table.find(curList, wc)
			if idx then
				table.remove(curList, idx)
			end
		end
		task.delay(cfg.ReplacementSpawnDelay, function()
			if isRunning and player.Parent and BaseService.GetPlayerBaseSlot(player) then
				spawnSingleCityCustomer(player, 195)
			end
		end)
	end)
end

local function buildSeatedPatienceSnapshot(player: Player): { { [string]: any } }
	local list = activeWalkingCustomers[player]
	if not list then
		return {}
	end
	local now = os.clock()
	local result: { { [string]: any } } = {}
	for _, wc in ipairs(list) do
		if wc.Model.Parent
			and wc.Phase == "SeatedWaiting"
			and wc.PatienceActive
			and not wc.IsServed
			and not wc.IsExpired
			and wc.Order
			and not wc.Order.Cancelled
		then
			table.insert(result, {
				OrderId = wc.OrderId,
				CustomerName = wc.Name,
				DishName = wc.Order.DishName,
				IsVIP = wc.IsVIPPatron,
				IsBeingCooked = wc.IsBeingCooked,
				TotalSeconds = wc.PatienceTotal,
				RemainingSeconds = math.max(0, wc.PatienceExpiresAt - now),
			})
		end
	end
	table.sort(result, function(a, b)
		return (a.RemainingSeconds :: number) < (b.RemainingSeconds :: number)
	end)
	return result
end

spawnSingleCityCustomer = function(player: Player, startDistanceZ: number): ()
	local baseModel, bp, hq = getBaseGeometry(player)
	if not baseModel or not bp or not hq or not hq.PrimaryPart then
		return
	end

	local list = activeWalkingCustomers[player]
	if not list then
		list = {}
		activeWalkingCustomers[player] = list
	end
	local hqMax = getMaxCustomersForHQ(player)
	if #list >= hqMax then
		return
	end

	local prof = PlayerDataService.GetProfile(player)
	local hqLevel = prof.RestaurantLevel or 1
	local bCF = bp.CFrame
	local hqCF = hq.PrimaryPart.CFrame
	local custName = CUSTOMER_NAMES[math.random(1, #CUSTOMER_NAMES)]
	local vipChance = math.clamp((hqLevel - 2) * 0.08, 0, 0.45)
	local isVIPPatron = (hqLevel >= 3) and (math.random() < vipChance)
	local displayName = if isVIPPatron then ("[VIP] " .. custName) else custName
	local styleIdx = math.random(1, 8)
	local tableIdx = pickAvailableTableIndex(player)
	local spot = ALL_DINING_SPOTS[tableIdx] or ALL_DINING_SPOTS[1]

	-- Spawn out on the City Boulevard approaching your Castle Base Front Gate!
	local spawnZ = math.clamp(startDistanceZ, 128, 225)
	local spawnPos = (bCF * CFrame.new(math.random(-14, 14), 3.6, spawnZ)).Position
	local frontGatePos = (bCF * CFrame.new(math.random(-6, 6), 3.6, 108.0)).Position
	local restaurantOrderPos = (hqCF * CFrame.new(math.random(-5, 5), 3.6, 26.0)).Position
	local doorPos = (hqCF * CFrame.new(math.random(-3, 3), 3.6, 18.0)).Position
	local tableLookPos, _, seatPos, _ = resolveSpotWorldPositions(spot, bCF, hqCF)

	local custModel, hum, root, bubble, pBg, pFill, pLbl = buildWalkingCustomerModel(baseModel, displayName, spawnPos, styleIdx)
	if isVIPPatron then
		bubble.TextColor3 = Color3.fromRGB(238, 204, 118)
	end
	custModel:SetAttribute("DiningPose", "Standing")
	custModel:SetAttribute("DiningZone", spot.Zone)
	local wc: WalkingCustomer = {
		OrderId = 0,
		Order = nil,
		Name = displayName,
		IsVIPPatron = isVIPPatron,
		Model = custModel,
		Humanoid = hum,
		Root = root,
		BubbleText = bubble,
		PatienceBarBg = pBg,
		PatienceBarFill = pFill,
		PatienceTimeLabel = pLbl,
		PatienceTotal = 0,
		PatienceStartedAt = 0,
		PatienceExpiresAt = 0,
		PatienceActive = false,
		IsServed = false,
		IsExpired = false,
		PenaltyApplied = false,
		IsBeingCooked = false,
		VipTipPaid = false,
		Phase = "Approaching",
		TableIndex = tableIdx,
		IsSeated = false,
		TableMeal = nil,
		EatingFork = nil,
	}
	table.insert(list, wc)

	-- Guarantee timer & order cleanup if customer model is ever destroyed externally
	custModel.Destroying:Connect(function()
		wc.PatienceActive = false
		if wc.Order and not wc.IsServed then
			wc.Order.Cancelled = true
			wc.Order.IsBeingCooked = false
		end
	end)

	-- Full Living Journey: Walk in from the City -> Front Gate -> Order at Restaurant -> Sit Indoor OR Outdoor Pergola Patio!
	task.spawn(function()
		wc.BubbleText.Text = displayName .. ": Heading from the city to eat!"
		moveCustomerTo(wc, frontGatePos, 15)
		if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end

		-- Walk up to the Restaurant Front to order food first!
		wc.BubbleText.Text = displayName .. ": Ordering food at the restaurant!"
		moveCustomerTo(wc, restaurantOrderPos, 14)
		if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end

		local wp = RestaurantExpansionConfig.STAIR_WAYPOINTS
		if spot.Zone == "Patio" then
			wc.BubbleText.Text = displayName .. ": Taking an outdoor pavilion table."
			moveCustomerTo(wc, seatPos, 12)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
		elseif spot.Zone == "EastWing" then
			wc.BubbleText.Text = displayName .. ": Heading into the East Wing."
			moveCustomerTo(wc, doorPos, 7)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.EastWingArchway)).Position, 7)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, seatPos, 9)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
		elseif spot.Zone == "WestWing" then
			wc.BubbleText.Text = displayName .. ": Heading into the West Wing."
			moveCustomerTo(wc, doorPos, 7)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.WestWingArchway)).Position, 7)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, seatPos, 9)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
		elseif spot.Floor == 3 or spot.Zone == "ThirdFloor" then
			wc.BubbleText.Text = displayName .. ": Heading up to the 3rd Floor!"
			moveCustomerTo(wc, doorPos, 7)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.RearAtriumDoor)).Position, 7)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.BottomLobby)).Position, 6)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.MidStairs)).Position, 6)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.TopLanding)).Position, 6)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.Floor2StairStart)).Position, 6)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.Floor2StairMid)).Position, 6)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.Floor3TopLanding)).Position, 6)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.Floor3Entry)).Position, 6)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, seatPos, 8)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
		elseif spot.Floor == 2 or spot.Zone == "SecondFloor" then
			wc.BubbleText.Text = displayName .. ": Heading up to the 2nd floor!"
			moveCustomerTo(wc, doorPos, 7)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.RearAtriumDoor)).Position, 7)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.BottomLobby)).Position, 6)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.MidStairs)).Position, 6)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.TopLanding)).Position, 6)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, (hqCF * CFrame.new(wp.Floor2Entry)).Position, 6)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, seatPos, 8)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
		else
			wc.BubbleText.Text = displayName .. ": Stepping inside for a table."
			moveCustomerTo(wc, doorPos, 7)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			local aislePos = (hqCF * CFrame.new(if spot.TableOffset.X > 0 then 9.5 else -11.0, 3.6, math.clamp(spot.TableOffset.Z, -18, 12))).Position
			moveCustomerTo(wc, aislePos, 7)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			moveCustomerTo(wc, seatPos, 7)
			if not wc.Model.Parent or not player.Parent or wc.IsServed or wc.IsExpired or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
		end

		setCustomerSeated(wc, true, seatPos, tableLookPos)
		wc.Phase = "SeatedWaiting"
		local zoneTag = if spot.Zone == "Patio"
			then "Patio"
			elseif spot.Zone == "EastWing" then "East Wing"
			elseif spot.Zone == "WestWing" then "West Wing"
			elseif spot.Zone == "SecondFloor" then "2nd Floor"
			elseif spot.Zone == "ThirdFloor" then "3rd Floor"
			else "Indoor"
		startCustomerPatience(player, wc, zoneTag)
	end)
end

local function pickWaiterForPlayer(player: Player): WaiterNPC?
	local hiredCount = CrewService.GetWaiterCount(player)
	if hiredCount <= 0 then
		return nil
	end
	local staff = activeWaitStaff[player]
	if not staff or #staff ~= hiredCount then
		spawnWaitStaffForPlayer(player)
		staff = activeWaitStaff[player]
	end
	if not staff or #staff == 0 then
		return nil
	end
	for _, w in ipairs(staff) do
		if not w.IsBusy and w.Model.Parent then
			return w
		end
	end
	for _, w in ipairs(staff) do
		if w.Model.Parent then
			return w
		end
	end
	return nil
end

local function dispatchCustomerToEatAndLeave(
	player: Player,
	earnedGold: number,
	dishHint: string?,
	dishDisplayName: string?,
	specificCustomer: WalkingCustomer?
): boolean
	local list = activeWalkingCustomers[player]
	if not list or #list == 0 then
		return false
	end

	-- Strict safety: never serve an expired, leaving, eating, or already-served customer!
	local target: WalkingCustomer? = nil
	if specificCustomer then
		if specificCustomer.Model.Parent
			and not specificCustomer.IsExpired
			and not specificCustomer.IsServed
			and specificCustomer.Phase ~= "Leaving"
			and specificCustomer.Phase ~= "Eating"
		then
			target = specificCustomer
		else
			return false
		end
	else
		-- Prefer the most urgent SeatedWaiting guest first!
		target = findMostUrgentWaitingCustomer(player, true)
		if not target then
			for _, wc in ipairs(list) do
				if wc.Model.Parent
					and not wc.IsExpired
					and not wc.IsServed
					and (wc.Phase == "Ordering" or wc.Phase == "Approaching")
				then
					target = wc
					break
				end
			end
		end
	end
	if not target then
		return false
	end

	local servedCust = target
	local resolvedHint = dishHint or dishDisplayName or "GrilledFish"
	local resolvedLabel = dishDisplayName or resolvedHint
	servedCust.IsServed = true
	servedCust.IsBeingCooked = false
	servedCust.Phase = "Eating"
	stopCustomerPatience(servedCust)
	if servedCust.Order then
		servedCust.Order.IsBeingCooked = false
	end
	syncPrimaryWaitingOrder(player)

	local baseModel, bp, hq = getBaseGeometry(player)
	if not baseModel or not bp or not hq or not hq.PrimaryPart then
		return false
	end

	local bCF = bp.CFrame
	local hqCF = hq.PrimaryPart.CFrame
	local spot = ALL_DINING_SPOTS[servedCust.TableIndex] or ALL_DINING_SPOTS[1]
	local tablePos, platePos, seatPos, waiterDropPos = resolveSpotWorldPositions(spot, bCF, hqCF)
	local kitchenPickupPos = (hqCF * CFrame.new(-11.0, 3.6, -10.0)).Position
	local doorWaypointPos = (hqCF * CFrame.new(0, 3.6, 22.0)).Position

	-- VIP patron bonus tip (strictly paid at most once per customer!)
	local vipBonusGold = 0
	if servedCust.IsVIPPatron and not servedCust.VipTipPaid then
		servedCust.VipTipPaid = true
		vipBonusGold = math.max(12, math.floor(earnedGold * 0.35))
		PlayerDataService.AddCoins(player, vipBonusGold)
	end
	local totalDisplayedGold = earnedGold + vipBonusGold

	-- Step 1: Ensure customer walks directly to their indoor dining table and sits down!
	local customerSeatedReady = false
	task.spawn(function()
		if not servedCust.IsSeated and servedCust.Model.Parent then
			servedCust.BubbleText.Text = string.format("%s: Ordered %s! Taking a seat!", servedCust.Name, resolvedLabel)
			moveCustomerTo(servedCust, seatPos, 9)
			if servedCust.Model.Parent then
				setCustomerSeated(servedCust, true, seatPos, tablePos)
			end
		end
		if servedCust.Model.Parent then
			servedCust.BubbleText.Text = string.format("%s: Waiting at table for %s...", servedCust.Name, resolvedLabel)
		end
		customerSeatedReady = true
	end)

	-- Step 2: Dedicated Hired Waiter walks to Kitchen Pass -> picks up real 3D plated dish on silver tray -> delivers DIRECTLY to customer's table!
	local waiter = pickWaiterForPlayer(player)
	task.spawn(function()
		if waiter and waiter.Model.Parent then
			waiter.IsBusy = true
			waiter.Model:SetAttribute("WaiterState", "WalkingToKitchen")
			waiter.BubbleText.Text = string.format("WAITER %s  |  PICKING UP %s", waiter.Name, string.upper(resolvedLabel))
			moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, kitchenPickupPos, 7, 3.8)

			-- Attach the distinct 3D plated dish right onto the Waiter's RightHand silver serving tray!
			if waiter.Model.Parent then
				if waiter.CarriedPlate and waiter.CarriedPlate.Parent then
					waiter.CarriedPlate:Destroy()
				end
				local trayBase = waiter.Model:FindFirstChild("RightHand") or waiter.Root
				if trayBase and trayBase:IsA("BasePart") then
					local trayCF = if trayBase == waiter.Root
						then waiter.Root.CFrame * CFrame.new(0, 0.38, -1.68)
						else trayBase.CFrame * CFrame.new(0, 0.32, -0.68)
					waiter.CarriedPlate = buildDistinctFoodOnPlate(waiter.Model, trayCF, resolvedHint, trayBase)
				end
				waiter.Model:SetAttribute("WaiterState", "CarryingTray")
				waiter.BubbleText.Text = string.format("%s  |  SERVING %s", waiter.Name, servedCust.Name)
			end

			-- Walk swiftly directly to the customer's table (32-speed Express Waiters across 1F, 2F, 3F, East/West Wings & Patio!)
			local wp = RestaurantExpansionConfig.STAIR_WAYPOINTS
			if spot.Zone == "Patio" then
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, doorWaypointPos, 4, 4.5)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, waiterDropPos, 8, 4.5)
			elseif spot.Zone == "EastWing" then
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.EastWingArchway)).Position, 5, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, waiterDropPos, 6, 4.0)
			elseif spot.Zone == "WestWing" then
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.WestWingArchway)).Position, 5, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, waiterDropPos, 6, 4.0)
			elseif spot.Floor == 3 or spot.Zone == "ThirdFloor" then
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.RearAtriumDoor)).Position, 4, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.BottomLobby)).Position, 4, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.MidStairs)).Position, 4, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.TopLanding)).Position, 4, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.Floor2StairStart)).Position, 4, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.Floor2StairMid)).Position, 4, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.Floor3TopLanding)).Position, 4, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.Floor3Entry)).Position, 4, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, waiterDropPos, 6, 4.0)
			elseif spot.Floor == 2 or spot.Zone == "SecondFloor" then
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.RearAtriumDoor)).Position, 4, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.BottomLobby)).Position, 4, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.MidStairs)).Position, 4, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.TopLanding)).Position, 4, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hqCF * CFrame.new(wp.Floor2Entry)).Position, 4, 4.2)
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, waiterDropPos, 6, 4.0)
			else
				moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, waiterDropPos, 6, 4.0)
			end

			local waitStart = os.clock()
			while not customerSeatedReady and (os.clock() - waitStart) < 3.0 do
				task.wait(0.1)
			end

			-- Polite table-side presentation & set steaming 3D dish directly in front of the seated customer!
			if waiter.Model.Parent then
				waiter.Model:SetAttribute("WaiterState", "ServingTable")
				waiter.BubbleText.Text = string.format("BON APPETIT, %s!", string.upper(servedCust.Name))
				task.wait(0.20)
			end
			if waiter.CarriedPlate and waiter.CarriedPlate.Parent then
				waiter.CarriedPlate:Destroy()
				waiter.CarriedPlate = nil
			end
			if servedCust.Model.Parent and baseModel.Parent then
				local plateCF = CFrame.new(platePos) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
				servedCust.TableMeal = buildDistinctFoodOnPlate(baseModel, plateCF, resolvedHint, nil)
				attachEatingFork(servedCust)
				servedCust.Model:SetAttribute("DiningPose", "Eating")
				servedCust.BubbleText.Text = string.format("%s: Eating %s (+%dG)", servedCust.Name, resolvedLabel, totalDisplayedGold)
			end

			if waiter.Model.Parent then
				waiter.Model:SetAttribute("WaiterState", "Idle")
				task.delay(0.20, function()
					if waiter.Model.Parent and hq.PrimaryPart then
						local wpBack = RestaurantExpansionConfig.STAIR_WAYPOINTS
						if spot.Zone == "Patio" then
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, doorWaypointPos, 6, 4.5)
						elseif spot.Zone == "EastWing" then
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.EastWingArchway)).Position, 5, 4.2)
						elseif spot.Zone == "WestWing" then
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.WestWingArchway)).Position, 5, 4.2)
						elseif spot.Floor == 3 or spot.Zone == "ThirdFloor" then
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.Floor3Entry)).Position, 4, 4.2)
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.Floor3TopLanding)).Position, 4, 4.2)
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.Floor2StairMid)).Position, 4, 4.2)
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.Floor2StairStart)).Position, 4, 4.2)
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.TopLanding)).Position, 4, 4.2)
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.MidStairs)).Position, 4, 4.2)
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.BottomLobby)).Position, 4, 4.2)
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.RearAtriumDoor)).Position, 4, 4.2)
						elseif spot.Floor == 2 or spot.Zone == "SecondFloor" then
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.Floor2Entry)).Position, 4, 4.2)
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.TopLanding)).Position, 4, 4.2)
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.MidStairs)).Position, 4, 4.2)
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.BottomLobby)).Position, 4, 4.2)
							moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, (hq.PrimaryPart.CFrame * CFrame.new(wpBack.RearAtriumDoor)).Position, 4, 4.2)
						end
						local homePos = (hq.PrimaryPart.CFrame * CFrame.new(waiter.HomeOffset)).Position
						moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, homePos, 5, 3.8)
						if waiter.Model.Parent then
							waiter.BubbleText.Text = waiter.RoleTitle .. " " .. waiter.Name .. "  |  READY"
						end
					end
					waiter.IsBusy = false
				end)
			else
				waiter.IsBusy = false
			end
		else
			-- Served directly by the Owner (before hiring Waiters) -> still places steaming 3D food on the table!
			local waitStart = os.clock()
			while not customerSeatedReady and (os.clock() - waitStart) < 4.5 do
				task.wait(0.15)
			end
			if servedCust.Model.Parent and baseModel.Parent then
				local plateCF = CFrame.new(platePos) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
				servedCust.TableMeal = buildDistinctFoodOnPlate(baseModel, plateCF, resolvedHint, nil)
				attachEatingFork(servedCust)
				servedCust.Model:SetAttribute("DiningPose", "Eating")
				servedCust.BubbleText.Text = string.format("%s: Eating %s (+%dG)", servedCust.Name, resolvedLabel, totalDisplayedGold)
			end
		end

		-- Customer sits inside the restaurant visibly eating their steaming 3D meal!
		if servedCust.Model.Parent then
			task.wait(4.2)
			if servedCust.Model.Parent then
				servedCust.BubbleText.Text = string.format("%s: Delicious %s!", servedCust.Name, resolvedLabel)
			end
			task.wait(4.0)
		end

		-- Stand up from indoor or outdoor patio chair, clear empty plate, and walk ALL THE WAY BACK TO THE CITY!
		if servedCust.TableMeal and servedCust.TableMeal.Parent then
			servedCust.TableMeal:Destroy()
			servedCust.TableMeal = nil
		end
		if servedCust.Model.Parent then
			setCustomerSeated(servedCust, false, nil, nil)
			servedCust.Phase = "Leaving"
			servedCust.BubbleText.Text = servedCust.Name .. ": Incredible food! Heading back to the city!"
			local wpExit = RestaurantExpansionConfig.STAIR_WAYPOINTS
			if spot.Floor == 3 or spot.Zone == "ThirdFloor" then
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.Floor3Entry)).Position, 7)
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.Floor3TopLanding)).Position, 6)
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.Floor2StairMid)).Position, 6)
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.Floor2StairStart)).Position, 6)
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.TopLanding)).Position, 6)
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.MidStairs)).Position, 6)
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.BottomLobby)).Position, 6)
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.RearAtriumDoor)).Position, 6)
				moveCustomerTo(servedCust, doorWaypointPos, 7)
			elseif spot.Floor == 2 or spot.Zone == "SecondFloor" then
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.Floor2Entry)).Position, 7)
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.TopLanding)).Position, 6)
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.MidStairs)).Position, 6)
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.BottomLobby)).Position, 6)
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.RearAtriumDoor)).Position, 6)
				moveCustomerTo(servedCust, doorWaypointPos, 7)
			elseif spot.Zone == "EastWing" then
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.EastWingArchway)).Position, 7)
				moveCustomerTo(servedCust, doorWaypointPos, 7)
			elseif spot.Zone == "WestWing" then
				moveCustomerTo(servedCust, (hqCF * CFrame.new(wpExit.WestWingArchway)).Position, 7)
				moveCustomerTo(servedCust, doorWaypointPos, 7)
			elseif spot.Zone ~= "Patio" then
				moveCustomerTo(servedCust, doorWaypointPos, 7)
			end
			local frontGateExit = (bCF * CFrame.new(math.random(-6, 6), 3.6, 108.0)).Position
			local cityRoadExit = (bCF * CFrame.new(math.random(-16, 16), 3.6, 225.0)).Position
			moveCustomerTo(servedCust, frontGateExit, 14)
			moveCustomerTo(servedCust, cityRoadExit, 16)
		end

		if servedCust.Model.Parent then
			servedCust.Model:Destroy()
		end
		local curList = activeWalkingCustomers[player]
		if curList then
			local idx = table.find(curList, servedCust)
			if idx then
				table.remove(curList, idx)
			end
		end
		-- Bring in a fresh walk-in customer from the City Boulevard right away!
		if isRunning and player.Parent then
			spawnSingleCityCustomer(player, 195)
		end
	end)
	return true
end

local function spawnCustomersForPlayer(player: Player): ()
	clearCustomers(player)
	spawnWaitStaffForPlayer(player)
	-- Stagger initial city guests walking in from the City Boulevard to fill BOTH Indoor & Outdoor Pergola Patio tables!
	local initialCount = math.min(getMaxCustomersForHQ(player), 4)
	for i = 1, initialCount do
		task.delay((i - 1) * 1.6, function()
			if isRunning and player.Parent then
				spawnSingleCityCustomer(player, 132 + i * 18)
			end
		end)
	end
end

local function updateCustomerSpeech(player: Player, text: string): ()
	local wList = activeWalkingCustomers[player]
	if not wList then
		return
	end
	for _, wc in ipairs(wList) do
		if (wc.Phase == "Ordering" or wc.Phase == "SeatedWaiting") and wc.Model.Parent then
			wc.BubbleText.Text = text
			return
		end
	end
	for _, wc in ipairs(wList) do
		if wc.Phase == "Approaching" and wc.Model.Parent then
			wc.BubbleText.Text = text
			return
		end
	end
end

local DISH_COLORS: { [string]: Color3 } = {
	GrilledFish = Color3.fromRGB(72, 186, 232),
	ClassicBurger = Color3.fromRGB(214, 134, 58),
	FreshSushi = Color3.fromRGB(246, 108, 92),
	TropicalSmoothie = Color3.fromRGB(255, 198, 48),
	SizzlingSteak = Color3.fromRGB(156, 68, 48),
	CrabFeast = Color3.fromRGB(238, 72, 62),
	EmperorPlatter = Color3.fromRGB(255, 214, 68),
}

local function setGrillCookingVisual(player: Player, cooking: boolean, dishColor: Color3?): ()
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return
	end
	local baseModel = BaseService.GetBaseModel(slot)
	local hq = if baseModel then baseModel:FindFirstChild("RestaurantHQ") else nil
	local station = if hq then hq:FindFirstChild("OrderReceiptStation") else nil
	if not station then
		return
	end

	local foodProp = station:FindFirstChild("CookingFoodProp")
	if foodProp and foodProp:IsA("BasePart") then
		foodProp.Transparency = if cooking then 0 else 1
		if dishColor then
			foodProp.Color = dishColor
		end
	end
	local steam = station:FindFirstChild("ChefSizzleSteam", true)
	if steam and steam:IsA("ParticleEmitter") then
		steam.Rate = if cooking then 18 else 0
	end
end

local function getPrimaryCategoryForRecipe(recipeId: string): WarehouseConfig.WarehouseCategory
	local spec = RecipeConfig.Recipes[recipeId]
	if spec then
		for ing in pairs(spec.Ingredients) do
			local cat = WarehouseConfig.IngredientToCategory[ing]
			if cat then
				return cat
			end
		end
	end
	return "Fish"
end

-- Spawns a visible animated Chef Supply Runner who walks from the player's Warehouse to the Restaurant Grill carrying ingredients!
local function spawnWarehouseFetchChef(
	player: Player,
	category: WarehouseConfig.WarehouseCategory,
	dishName: string,
	chefLabel: string
): ()
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return
	end
	local baseModel = BaseService.GetBaseModel(slot)
	local hq = if baseModel then baseModel:FindFirstChild("RestaurantHQ") else nil
	local station = if hq then hq:FindFirstChild("OrderReceiptStation") else nil
	local grill = if station then station:FindFirstChild("SizzleSkillet") else nil
	if not hq or not grill or not grill:IsA("BasePart") then
		return
	end

	local doorPart: BasePart? = nil
	for _, plot in ipairs(CollectionService:GetTagged("WarehousePlot")) do
		if plot:GetAttribute("BaseSlot") == slot and plot:GetAttribute("Category") == category then
			local d = plot:FindFirstChild("CargoDoor", true)
			if d and d:IsA("BasePart") then
				doorPart = d
				break
			end
		end
	end
	if not doorPart then
		return
	end

	local spec = WarehouseConfig.Specs[category]
	local startPos = Vector3.new(doorPart.Position.X, doorPart.Position.Y + 1.0, doorPart.Position.Z)
	local endPos = Vector3.new(grill.Position.X, startPos.Y, grill.Position.Z)
	local dir = endPos - startPos
	if dir.Magnitude < 2 then
		return
	end

	local lookCF = CFrame.lookAt(startPos, endPos)
	local rig = MafiaVisualBuilder.BuildChefRig("WarehouseFetchChef", spec.AccentColor, 1.0, lookCF, false)
	local runner = rig.Model
	-- Pose arms forward carrying the Warehouse ingredient crate cleanly
	local laj = rig.Root:FindFirstChild("LeftArmJoint")
	local raj = rig.Root:FindFirstChild("RightArmJoint")
	if laj and laj:IsA("Motor6D") then
		laj.C0 = CFrame.new(-1.38, 0.85, -0.1) * CFrame.Angles(math.rad(68), 0, 0)
	end
	if raj and raj:IsA("Motor6D") then
		raj.C0 = CFrame.new(1.38, 0.85, -0.1) * CFrame.Angles(math.rad(68), 0, 0)
	end

	-- Carried Ingredient Supply Crate from Warehouse!
	rig.AddPart(rig.Root, "CarriedCrate", Vector3.new(1.95, 1.35, 1.55), CFrame.new(0, 0.32, -1.65), spec.AccentColor, Enum.Material.WoodPlanks, nil)

	for _, desc in ipairs(runner:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = (desc == rig.Root)
			desc.Massless = (desc ~= rig.Root)
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
		end
	end

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(224, 30)
	bb.StudsOffset = Vector3.new(0, 2.55, 0)
	bb.MaxDistance = 120
	bb.Parent = rig.Head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 17, 21)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = string.format("%s  |  %s -> %s", string.upper(chefLabel), string.upper(spec.ShortLabel), dishName)
	lbl.TextSize = 10
	lbl.TextColor3 = Color3.fromRGB(224, 198, 128)
	lbl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 5)
	c.Parent = lbl
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(152, 126, 74)
	st.Thickness = 1
	st.Parent = lbl

	runner.PrimaryPart = rig.Root
	runner.Parent = hq

	task.spawn(function()
		local steps = 22
		for i = 1, steps do
			if not runner.Parent then
				return
			end
			local alpha = i / steps
			local p = startPos:Lerp(endPos, alpha)
			local bob = math.abs(math.sin(alpha * math.pi * 6)) * 0.42
			runner:PivotTo(CFrame.lookAt(p + Vector3.new(0, bob, 0), endPos + Vector3.new(0, bob, 0)))
			task.wait(0.055)
		end
		task.wait(0.25)
		if runner.Parent then
			runner:Destroy()
		end
	end)
end

local function printRestaurantReceipt(
	player: Player,
	customerName: string,
	dishName: string,
	goldEarned: number,
	repEarned: number,
	chefName: string
): ReceiptEntry
	local nextNo = (orderCounters[player] or 0) + 1
	orderCounters[player] = nextNo

	local entry: ReceiptEntry = {
		OrderNo = nextNo,
		CustomerName = customerName,
		DishName = dishName,
		GoldEarned = goldEarned,
		RepEarned = repEarned,
		ChefName = chefName,
	}

	local hist = receiptHistory[player]
	if not hist then
		hist = {}
		receiptHistory[player] = hist
	end
	table.insert(hist, 1, entry)
	while #hist > 5 do
		table.remove(hist)
	end

	-- Update the 3D Printed Receipt Board & Cash Register Screen inside the player's Restaurant HQ!
	local slot = BaseService.GetPlayerBaseSlot(player)
	local baseModel = if slot then BaseService.GetBaseModel(slot) else nil
	local hq = if baseModel then baseModel:FindFirstChild("RestaurantHQ") else nil
	local station = if hq then hq:FindFirstChild("OrderReceiptStation") else nil
	if station then
		local priceLbl = station:FindFirstChild("PriceText", true)
		if priceLbl and priceLbl:IsA("TextLabel") then
			priceLbl.Text = string.format("#%d • +%dG", nextNo, goldEarned)
		end

		local receiptText = string.format(
			"ORDER #%d\nCustomer: %s\nChef: %s\n--------------------\n1x %s\n--------------------\nTOTAL:   +%d GOLD\nREP:     +%d REP\n\nTHANK YOU! COME AGAIN!",
			nextNo,
			customerName,
			chefName,
			dishName,
			goldEarned,
			repEarned
		)
		for _, d in ipairs(station:GetDescendants()) do
			if d.Name == "ReceiptBody" and d:IsA("TextLabel") then
				d.Text = receiptText
			end
		end
	end

	return entry
end

local function spawnRandomCustomerOrder(player: Player): WaitingOrder
	local starInfo = RestaurantService.GetRestaurantStarInfo(player)
	local isVipGuest = (starInfo.Stars >= 2 and math.random() < 0.38)
	local cName = if isVipGuest
		then VIP_CRITIC_NAMES[math.random(1, #VIP_CRITIC_NAMES)]
		else CUSTOMER_NAMES[math.random(1, #CUSTOMER_NAMES)]
	local vipMult = if isVipGuest then 1.65 else 1.0
	local bestRecipe = RestaurantService.PickBestAvailableRecipe(player)
	local order: WaitingOrder

	if bestRecipe then
		nextOrderId += 1
		local spec = RecipeConfig.Recipes[bestRecipe]
		order = {
			OrderId = nextOrderId,
			CustomerName = cName,
			DishName = if spec then spec.DisplayName else bestRecipe,
			RecipeId = bestRecipe,
			BaseGold = math.floor((if spec then spec.CoinsReward else 40) * vipMult),
			BaseRep = math.floor((if spec then spec.ReputationReward else 10) * vipMult),
			IsBeingCooked = false,
			Cancelled = false,
		}
	else
		nextOrderId += 1
		local special = HOUSE_SPECIALS[math.random(1, #HOUSE_SPECIALS)]
		order = {
			OrderId = nextOrderId,
			CustomerName = cName,
			DishName = special.Name,
			RecipeId = nil,
			BaseGold = math.floor(special.Gold * vipMult),
			BaseRep = math.floor(special.Rep * vipMult),
			IsBeingCooked = false,
			Cancelled = false,
		}
	end

	waitingOrders[player] = order
	updateCustomerSpeech(player, string.format("%s: 1x %s please!", order.CustomerName, order.DishName))
	return order
end

local function clearPlatters(player: Player): ()
	local list = platterModels[player]
	if not list then
		return
	end
	for _, m in ipairs(list) do
		if m.Parent then
			m:Destroy()
		end
	end
	platterModels[player] = nil
end

local function syncCounterPlatters(player: Player): ()
	clearPlatters(player)
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return
	end

	local servePart: BasePart? = nil
	for _, p in ipairs(CollectionService:GetTagged("ServeCounter")) do
		if p:IsA("BasePart") and p:GetAttribute("BaseSlot") == slot then
			servePart = p
			break
		end
	end
	if not servePart then
		return
	end

	local kitchen = kitchens[player]
	if not kitchen then
		return
	end

	local spawned: { Model } = {}
	local idx = 0
	for recipeId, qty in pairs(kitchen.ReadyDishes) do
		for _ = 1, qty do
			idx += 1
			if idx > 5 then
				break
			end
			local xOff = -4.8 + (idx - 1) * 2.4
			local cf = servePart.CFrame * CFrame.new(xOff, servePart.Size.Y / 2 + 0.05, 0)
			local platter = buildDistinctFoodOnPlate(servePart, cf, recipeId, nil)
			platter.Name = "Platter_" .. tostring(idx) .. "_" .. recipeId
			table.insert(spawned, platter)
		end
		if idx >= 5 then
			break
		end
	end
	platterModels[player] = spawned
end

local function tryReturnHome(player: Player): (boolean, string)
	local canTp, tpReason = CombatLockService.CanTeleport(player)
	if not canTp then
		return false, tpReason
	end
	if player:GetAttribute("CarryingCrate") ~= nil then
		return false, "Deliver your carried crate on foot first!"
	end
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return false, "No base assigned"
	end
	local baseModel = BaseService.GetBaseModel(slot)
	local spawnPart = if baseModel then baseModel:FindFirstChild("BaseSpawn") else nil
	local char = player.Character
	if not spawnPart or not spawnPart:IsA("BasePart") or not char then
		return false, "Base spawn unavailable"
	end
	pcall(function()
		player:RequestStreamAroundAsync(spawnPart.Position)
	end)
	char:PivotTo(spawnPart.CFrame + Vector3.new(0, 4.5, 0))
	return true, "Returned to " .. slot .. " Castle Base!"
end

local function setPlayerSprint(player: Player, enabled: boolean): (boolean, string)
	if ScooterService.IsOnScooter(player) then
		if enabled then
			return ScooterService.TriggerTurbo(player)
		end
		return true, "OK"
	end
	local char = player.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not hum then
		return false, "OK"
	end
	hum.WalkSpeed = if enabled then 26 else 16
	return true, "OK"
end

local function getFoodEmperor(): { Name: string, Reputation: number }
	local topPlayer: Player? = nil
	local topName = "None Yet"
	local topRep = -1
	for _, p in ipairs(Players:GetPlayers()) do
		local rep = PlayerDataService.GetProfile(p).Reputation
		if rep > topRep then
			topRep = rep
			topName = p.DisplayName
			topPlayer = p
		end
	end

	-- Equip floating 3D Golden Emperor Crown on the #1 Reputation leader (once Rep >= 25)
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if char then
			local existingCrown = char:FindFirstChild("FoodEmperorCrown")
			local shouldWear = (p == topPlayer and topRep >= 25)
			if shouldWear and not existingCrown then
				local head = char:FindFirstChild("Head")
				if head and head:IsA("BasePart") then
					local crown = Instance.new("Part")
					crown.Name = "FoodEmperorCrown"
					crown.Shape = Enum.PartType.Cylinder
					crown.Size = Vector3.new(0.85, 2.1, 2.1)
					crown.Color = Color3.fromRGB(246, 196, 48)
					crown.Material = Enum.Material.Metal
					crown.CanCollide = false
					crown.CanTouch = false
					crown.CanQuery = false
					crown.Massless = true
					crown.CastShadow = false
					crown.CFrame = head.CFrame * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(90))
					crown.Parent = char

					local weld = Instance.new("WeldConstraint")
					weld.Part0 = head
					weld.Part1 = crown
					weld.Parent = crown
				end
			elseif not shouldWear and existingCrown then
				existingCrown:Destroy()
			end
		end
	end

	return {
		Name = topName,
		Reputation = math.max(0, topRep),
	}
end

local function syncRestaurantVisuals(player: Player): ()
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return
	end
	local baseModel = BaseService.GetBaseModel(slot)
	local hq = if baseModel then baseModel:FindFirstChild("RestaurantHQ") else nil
	if not baseModel or not hq or not hq:IsA("Model") or not hq.PrimaryPart then
		return
	end

	local level = PlayerDataService.GetProfile(player).RestaurantLevel
	local result = RestaurantExpansionBuilder.BuildTierForHQ(baseModel, hq, slot, level)
	RestaurantExpansionBuilder.BuildFrontWoodPavilion(baseModel, slot, level)
	if result.BoundsViolations > 0 then
		warn(string.format("[RestaurantService] %s HQ Tier %d reported %d bounds clamp(s)", slot, result.Tier, result.BoundsViolations))
	end
end

function RestaurantService.CheckHQUpgradeRequirements(player: Player): (boolean, string, number, number, number, number)
	local profile = PlayerDataService.GetProfile(player)
	local curRestLv = profile.RestaurantLevel or 1
	local nextTier = RecipeConfig.RestaurantTiers[curRestLv + 1]
	if not nextTier then
		return false, "Restaurant HQ is already at Max Level 15!", 20, profile.Level or 1, 2250, profile.TotalDishesServed or 0
	end
	local curLv = profile.Level or 1
	local reqLv = nextTier.RequiredPlayerLevel or 1
	local curFood = profile.TotalDishesServed or 0
	local reqFood = nextTier.RequiredDishesServed or 0

	if curLv < reqLv and curFood < reqFood then
		return false, string.format(
			"LOCKED: Reach Player Lv.%d (now Lv.%d) & sell %d Food (%d/%d sold) before upgrading HQ to Lv.%d!",
			reqLv,
			curLv,
			reqFood,
			curFood,
			reqFood,
			nextTier.Level
		), reqLv, curLv, reqFood, curFood
	elseif curLv < reqLv then
		return false, string.format(
			"LOCKED: Reach Player Lv.%d first (currently Lv.%d) to upgrade Restaurant HQ to Lv.%d!",
			reqLv,
			curLv,
			nextTier.Level
		), reqLv, curLv, reqFood, curFood
	elseif curFood < reqFood then
		return false, string.format(
			"LOCKED: Sell %d Food first (%d/%d sold) before upgrading Restaurant HQ to Lv.%d!",
			reqFood,
			curFood,
			reqFood,
			nextTier.Level
		), reqLv, curLv, reqFood, curFood
	end
	return true, "OK", reqLv, curLv, reqFood, curFood
end

local function ensureKitchen(player: Player): KitchenState
	local existing = kitchens[player]
	if existing then
		return existing
	end
	local created: KitchenState = {
		IsCooking = false,
		CurrentRecipeId = nil,
		CookEndsAt = 0,
		Boosted1 = false,
		Token1 = 0,
		IsCooking2 = false,
		CurrentRecipeId2 = nil,
		CookEndsAt2 = 0,
		Boosted2 = false,
		Token2 = 0,
		MasterworkBonusCount = 0,
		ReadyDishes = {},
	}
	kitchens[player] = created
	return created
end

local function countReadyDishes(kitchen: KitchenState): number
	local total = 0
	for _, qty in pairs(kitchen.ReadyDishes) do
		total += qty
	end
	return total
end

local CRAVING_POOL = { "GrilledFish", "ClassicBurger", "FreshSushi", "SizzlingSteak", "CrabFeast", "EmperorPlatter", "TruffleWagyuTartare", "SmokedCartelRibs" }
local cityCravingRecipeId = "SizzlingSteak"
local cityCravingEndsAt = os.clock() + 180

local function refreshCityCraving(): ()
	local now = os.clock()
	if now >= cityCravingEndsAt then
		cityCravingRecipeId = CRAVING_POOL[math.random(1, #CRAVING_POOL)]
		cityCravingEndsAt = now + 180
	end
end

local function buildClientPayload(player: Player): { [string]: any }
	refreshCityCraving()
	local profile = PlayerDataService.GetProfile(player)
	local inv = WarehouseService.GetInventorySnapshot(player)
	local kitchen = ensureKitchen(player)
	local sectorsSummary: { [string]: any } = {}
	for id, s in pairs(SectorService.GetAllSectors()) do
		sectorsSummary[id] = {
			DisplayName = s.DisplayName,
			Owner = s.Owner,
			Status = s.Status,
			Category = s.Category,
			CaptureProgress = s.CaptureProgress,
		}
	end
	local cravingSpec = RecipeConfig.Recipes[cityCravingRecipeId]
	local expSpec = RestaurantExpansionConfig.GetTierSpec(profile.RestaurantLevel or 1)
	local nextExpSpec = if (profile.RestaurantLevel or 1) < RestaurantExpansionConfig.MAX_PHYSICAL_TIER
		then RestaurantExpansionConfig.GetTierSpec((profile.RestaurantLevel or 1) + 1)
		else nil
	local canUpgHQ, hqLockReason, reqPlrLv, _, reqFoodSold, curFoodSold = RestaurantService.CheckHQUpgradeRequirements(player)

	return {
		BaseSlot = BaseService.GetPlayerBaseSlot(player),
		Profile = profile,
		Expansion = {
			Tier = expSpec.Tier,
			DisplayName = expSpec.DisplayName,
			Subtitle = expSpec.Subtitle,
			Summary = expSpec.Summary,
			FrontPavilionName = expSpec.FrontPavilionName,
			FrontPavilionSummary = expSpec.FrontPavilionSummary,
			WidthStuds = expSpec.WidthStuds,
			HeightStuds = expSpec.HeightStuds,
			DepthStuds = expSpec.DepthStuds,
			Floors = expSpec.Floors,
			MaxCustomers = getMaxCustomersForHQ(player),
			KitchenReadyCapacity = expSpec.KitchenReadyCapacity,
			MaxConcurrentOrders = expSpec.MaxConcurrentOrders + (if profile.HasDualStove then 1 else 0),
			NextSummary = if nextExpSpec then nextExpSpec.Summary else "",
			NextFrontPavilionName = if nextExpSpec then nextExpSpec.FrontPavilionName else "",
			NextFrontPavilionSummary = if nextExpSpec then nextExpSpec.FrontPavilionSummary else "",
			NextMaxCustomers = if nextExpSpec then (nextExpSpec.MaxCustomers + (if profile.HasVIPBooths then 2 else 0)) else getMaxCustomersForHQ(player),
			TotalDishesServed = curFoodSold,
			NextHQReqLevel = reqPlrLv,
			NextHQReqFood = reqFoodSold,
			CanUpgradeHQRequirements = canUpgHQ,
			HQLockReason = hqLockReason,
		},
		Warehouse = inv,
		Kitchen = {
			IsCooking = kitchen.IsCooking,
			CurrentRecipeId = kitchen.CurrentRecipeId,
			TimeRemaining = if kitchen.IsCooking then math.max(0, kitchen.CookEndsAt - os.clock()) else 0,
			Boosted1 = kitchen.Boosted1,
			IsCooking2 = kitchen.IsCooking2,
			CurrentRecipeId2 = kitchen.CurrentRecipeId2,
			TimeRemaining2 = if kitchen.IsCooking2 then math.max(0, kitchen.CookEndsAt2 - os.clock()) else 0,
			Boosted2 = kitchen.Boosted2,
			HasDualStove = profile.HasDualStove == true,
			HasVIPBooths = profile.HasVIPBooths == true,
			MasterworkBonusCount = kitchen.MasterworkBonusCount,
			ReadyDishes = kitchen.ReadyDishes,
			ReadyTotal = countReadyDishes(kitchen),
		},
		Sectors = sectorsSummary,
		NextCrewCost = CrewService.GetNextHireCost(player),
		MaxCrew = CrewService.GetMaxCrew(player),
		WaiterCount = CrewService.GetWaiterCount(player),
		MaxWaiters = CrewService.MAX_WAITERS,
		NextWaiterCost = CrewService.GetNextWaiterCost(player),
		CourierCount = DeliveryRunnerService.GetCourierCount(player),
		MaxCouriers = DeliveryRunnerService.MAX_COURIERS,
		NextCourierCost = DeliveryRunnerService.GetNextCourierCost(player),
		CentralParkBranch = CentralParkBranchService.GetSnapshot(player),
		SpinEvent = SpinEventService.GetSnapshot(player),
		StarRating = RestaurantService.GetRestaurantStarInfo(player),
		Syndicate = SyndicateContractService.GetSnapshot(player),
		FoodEmperor = getFoodEmperor(),
		OwnedPasses = MonetizationService.GetOwnedMap(player),
		VIPOrder = VIPOrderService.GetOrderSnapshot(player),
		OwnsMotorbike = ScooterService.OwnsMotorbike(player),
		MotorbikeCoinCost = ScooterService.MOTORBIKE_COIN_COST,
		OwnsMafiaSedan = ScooterService.OwnsMafiaSedan(player),
		MafiaSedanCost = ScooterService.SEDAN_COIN_COST,
		OwnsArmoredVan = ScooterService.OwnsArmoredVan(player),
		ArmoredVanCost = ScooterService.VAN_COIN_COST,
		OwnsGetawayCoupe = ScooterService.OwnsGetawayCoupe(player),
		GetawayCoupeCost = ScooterService.COUPE_COIN_COST,
		HasVehicleArmor = profile.HasVehicleArmor == true,
		VehiclePaint = profile.VehiclePaint or "Obsidian",
		GuardStance = BodyguardService.GetSquadStance(player),
		VaultKeycards = tonumber(player:GetAttribute("VaultKeycards")) or 0,
		RaiderCount = RaiderChefService.GetRaiderCount(player),
		MaxRaiders = RaiderChefService.MAX_RAIDERS,
		NextRaiderCost = RaiderChefService.GetNextCost(player),
		BaseSlots = BaseService.GetSlotAvailability(),
		WaitingCustomer = waitingOrders[player],
		SeatedPatience = buildSeatedPatienceSnapshot(player),
		NightRaid = NightMafiaRaidService.GetSnapshot(player),
		HiredCompanions = DefenseCompanionService.GetSnapshot(player),
		Receipts = receiptHistory[player] or {},
		LatestReceipt = if receiptHistory[player] then receiptHistory[player][1] else nil,
		Shipments = ShipmentService.GetSnapshot(),
		ExpressDelivery = ExpressDeliveryService.GetSnapshot(player),
		BodyguardCount = BodyguardService.GetGuardCount(player),
		MaxBodyguards = BodyguardService.MAX_BODYGUARDS,
		NextBodyguardCost = BodyguardService.GetNextCost(player),
		Bodyguards = BodyguardService.GetBodyguardPayload(player),
		DeliveryRunnerActive = DeliveryRunnerService.IsActive(player),
		DeliveryRunnerCooldown = DeliveryRunnerService.GetCooldownRemaining(player),
		BlackMarket = BlackMarketService.GetCatalogPayload(player),
		Turf = TurfService.GetSnapshotForPlayer(player),
		CityCraving = {
			RecipeId = cityCravingRecipeId,
			DisplayName = if cravingSpec then cravingSpec.DisplayName else cityCravingRecipeId,
			TimeRemaining = math.max(0, math.ceil(cityCravingEndsAt - os.clock())),
		},
		MenuPricing = profile.MenuPricing or "Standard",
		Weather = WeatherService.GetSnapshot(),
		FrontBusinesses = MafiaBusinessService.GetSnapshot(player),
		Bounties = BountyService.GetSnapshot(player),
		PenthouseHeist = SyndicateRaidService.GetSnapshot(),
		MafiaRestaurants = MafiaRestaurantService.GetSnapshot(player),
		MercenaryMafia = MercenaryMafiaService.GetSnapshot(player),
		SyndicateFamily = SyndicateFamilyService.GetSnapshot(player),
		PrestigeVault = PrestigeVaultService.GetSnapshot(player),
	}
end

function RestaurantService.PushStateToClient(player: Player): ()
	if stateEvent and player.Parent then
		stateEvent:FireClient(player, buildClientPayload(player))
	end
end

local function getMissingWarehousesForRecipe(player: Player, recipe: RecipeConfig.RecipeSpec): { WarehouseConfig.WarehouseCategory }
	local required = WarehouseConfig.GetRequiredWarehousesForIngredients(recipe.Ingredients)
	local missing: { WarehouseConfig.WarehouseCategory } = {}
	for _, cat in ipairs(required) do
		if not WarehouseService.IsUnlocked(player, cat) then
			table.insert(missing, cat)
		end
	end
	return missing
end

local function formatMissingWarehouseNames(missing: { WarehouseConfig.WarehouseCategory }): string
	local names: { string } = {}
	for _, cat in ipairs(missing) do
		local spec = WarehouseConfig.Specs[cat]
		table.insert(names, if spec then spec.DisplayName else (cat .. " Ingredient Warehouse"))
	end
	return table.concat(names, " & ")
end

function RestaurantService.PickBestAvailableRecipe(player: Player): string?
	local profile = PlayerDataService.GetProfile(player)
	local restLevel = profile.RestaurantLevel
	local rep = profile.Reputation or 0
	for _, recipeId in ipairs(RecipeConfig.Order) do
		local recipe = RecipeConfig.Recipes[recipeId]
		if recipe and restLevel >= recipe.RequiredRestaurantLevel then
			local repOk = (recipe.RequiredRep == nil) or (rep >= recipe.RequiredRep)
			if repOk and #getMissingWarehousesForRecipe(player, recipe) == 0 then
				if WarehouseService.HasIngredients(player, recipe.Ingredients) then
					return recipeId
				end
			end
		end
	end
	return nil
end

local function finishCookSlot(player: Player, slotNum: number, token: number, recipeId: string): ()
	if not player.Parent then
		return
	end
	local kitchen = ensureKitchen(player)
	local wasBoosted = false
	if slotNum == 1 then
		if not kitchen.IsCooking or kitchen.Token1 ~= token then
			return
		end
		wasBoosted = kitchen.Boosted1
		kitchen.IsCooking = false
		kitchen.CurrentRecipeId = nil
		kitchen.CookEndsAt = 0
		kitchen.Boosted1 = false
	else
		if not kitchen.IsCooking2 or kitchen.Token2 ~= token then
			return
		end
		wasBoosted = kitchen.Boosted2
		kitchen.IsCooking2 = false
		kitchen.CurrentRecipeId2 = nil
		kitchen.CookEndsAt2 = 0
		kitchen.Boosted2 = false
	end

	kitchen.ReadyDishes[recipeId] = (kitchen.ReadyDishes[recipeId] or 0) + 1
	if wasBoosted then
		kitchen.MasterworkBonusCount += 1
	end
	if not kitchen.IsCooking and not kitchen.IsCooking2 then
		setGrillCookingVisual(player, false, nil)
	end
	syncCounterPlatters(player)
	if SPECIALTY_RECIPE_IDS[recipeId] then
		specialtyCookCounts[player] = (specialtyCookCounts[player] or 0) + 1
		SyndicateContractService.RecordProgress(player, "SpecialtyFeast", 1)
	end
	local recipe = RecipeConfig.Recipes[recipeId]
	updateCustomerSpeech(player, "Food Ready! Sell Now!")
	print(string.format("[RestaurantService] %s finished cooking %s (Stove #%d)!", player.Name, if recipe then recipe.DisplayName else recipeId, slotNum))
	RestaurantService.PushStateToClient(player)
end

function RestaurantService.CookRecipe(player: Player, recipeId: string): (boolean, string)
	local recipe = RecipeConfig.Recipes[recipeId]
	if not recipe then
		return false, "Unknown recipe"
	end

	local missingWh = getMissingWarehousesForRecipe(player, recipe)
	if #missingWh > 0 then
		return false, string.format(
			"LOCKED DISH: Unlock your %s in Storage [B] to unlock %s!",
			formatMissingWarehouseNames(missingWh),
			recipe.DisplayName
		)
	end

	local profile = PlayerDataService.GetProfile(player)
	if profile.RestaurantLevel < recipe.RequiredRestaurantLevel then
		return false, string.format("Requires Restaurant HQ Lv.%d", recipe.RequiredRestaurantLevel)
	end
	if recipe.RequiredRep and profile.Reputation < recipe.RequiredRep then
		return false, string.format("Secret Syndicate Dish requires %d Reputation!", recipe.RequiredRep)
	end

	local kitchen = ensureKitchen(player)
	local hasDual = profile.HasDualStove == true
	local useSlot = 0
	if not kitchen.IsCooking then
		useSlot = 1
	elseif hasDual and not kitchen.IsCooking2 then
		useSlot = 2
	else
		return false, if hasDual
			then "Both Stove Lines are busy! Use SEAR BOOST to speed up cooking!"
			else "Stove is busy! Unlock Dual-Stove Line (650G) or press SEAR BOOST!"
	end

	if not WarehouseService.ConsumeIngredients(player, recipe.Ingredients) then
		return false, "Not enough ingredients in Warehouses!"
	end

	local tier = RecipeConfig.RestaurantTiers[profile.RestaurantLevel] or RecipeConfig.RestaurantTiers[1]
	local speedMult = tier.CookSpeedMultiplier * CrewService.GetCookSpeedMultiplier(player) * MonetizationService.GetCookSpeedMultiplier(player)
	local duration = math.max(0.6, recipe.CookTime / speedMult)

	local myToken: number
	if useSlot == 1 then
		kitchen.Token1 += 1
		myToken = kitchen.Token1
		kitchen.IsCooking = true
		kitchen.CurrentRecipeId = recipeId
		kitchen.CookEndsAt = os.clock() + duration
		kitchen.Boosted1 = false
	else
		kitchen.Token2 += 1
		myToken = kitchen.Token2
		kitchen.IsCooking2 = true
		kitchen.CurrentRecipeId2 = recipeId
		kitchen.CookEndsAt2 = os.clock() + duration
		kitchen.Boosted2 = false
	end

	setGrillCookingVisual(player, true, DISH_COLORS[recipeId])
	local cat = getPrimaryCategoryForRecipe(recipeId)
	local activeChef = if MonetizationService.HasPass(player, "MasterProChef")
		then "Pro Chef"
		elseif CrewService.GetCrewCount(player) > 0 then "Crew Chef"
		else "Kitchen"
	spawnWarehouseFetchChef(player, cat, recipe.DisplayName, activeChef)
	RestaurantService.PushStateToClient(player)

	task.delay(duration, function()
		finishCookSlot(player, useSlot, myToken, recipeId)
	end)

	return true, string.format("Stove #%d Cooking %s (%.1fs) — Press SEAR BOOST for Masterwork!", useSlot, recipe.DisplayName, duration)
end

-- Interactive Timing Sear Boost: Cuts remaining cook time by 40% and upgrades the dish to CHEF'S MASTERWORK (+50% Gold)!
function RestaurantService.TrySearBoost(player: Player): (boolean, string)
	local kitchen = ensureKitchen(player)
	local now = os.clock()
	if kitchen.IsCooking and not kitchen.Boosted1 then
		local rem = math.max(0.4, (kitchen.CookEndsAt - now) * 0.60)
		kitchen.Boosted1 = true
		kitchen.Token1 += 1
		local tok = kitchen.Token1
		local recId = kitchen.CurrentRecipeId or "GrilledFish"
		kitchen.CookEndsAt = now + rem
		RestaurantService.PushStateToClient(player)
		if RecipeConfig.Recipes[recId] then
			task.delay(rem, function()
				finishCookSlot(player, 1, tok, recId)
			end)
		end
		return true, string.format("CHEF'S MASTERWORK SEAR! Stove #1 time cut to %.1fs (+50%% Gold Bonus)!", rem)
	elseif kitchen.IsCooking2 and not kitchen.Boosted2 then
		local rem = math.max(0.4, (kitchen.CookEndsAt2 - now) * 0.60)
		kitchen.Boosted2 = true
		kitchen.Token2 += 1
		local tok = kitchen.Token2
		local recId = kitchen.CurrentRecipeId2 or "GrilledFish"
		kitchen.CookEndsAt2 = now + rem
		RestaurantService.PushStateToClient(player)
		if RecipeConfig.Recipes[recId] then
			task.delay(rem, function()
				finishCookSlot(player, 2, tok, recId)
			end)
		end
		return true, string.format("CHEF'S MASTERWORK SEAR! Stove #2 time cut to %.1fs (+50%% Gold Bonus)!", rem)
	elseif kitchen.IsCooking or kitchen.IsCooking2 then
		return false, "Active dish is already Sear-Boosted to Chef's Masterwork!"
	end
	return false, "Start cooking a dish first, then trigger Sear Boost!"
end

function RestaurantService.TryBuyDualStove(player: Player, bypassGold: boolean?): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Restaurant Plaza Base first!"
	end
	local prof = PlayerDataService.GetProfile(player)
	if prof.HasDualStove then
		return true, "Dual-Stove Commercial Range is already installed!"
	end
	if not bypassGold and not PlayerDataService.SpendCoins(player, 3250) then
		return false, "Need 3,250 Gold to install the 2nd Commercial Stove Line!"
	end
	PlayerDataService.SetHasDualStove(player, true)
	SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1)
	RestaurantService.PushStateToClient(player)
	return true, "Installed 2nd Commercial Stove Line! Cook 2 dishes simultaneously!"
end

function RestaurantService.TryBuyVIPBooths(player: Player, bypassGold: boolean?): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Restaurant Plaza Base first!"
	end
	local prof = PlayerDataService.GetProfile(player)
	if prof.HasVIPBooths then
		return true, "VIP Private Dining Booths are already installed!"
	end
	if not bypassGold and not PlayerDataService.SpendCoins(player, 4250) then
		return false, "Need 4,250 Gold to install VIP Private Dining Booths!"
	end
	PlayerDataService.SetHasVIPBooths(player, true)
	SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1)
	RestaurantService.PushStateToClient(player)
	return true, "Installed Luxury VIP Private Dining Booths (+20% Dish Payout & +1 Star Rating)!"
end

function RestaurantService.ServeAllReadyDishes(player: Player): (boolean, string)
	local kitchen = ensureKitchen(player)
	local totalDishes = countReadyDishes(kitchen)
	if totalDishes <= 0 then
		return false, "No cooked dishes ready to serve"
	end

	local profile = PlayerDataService.GetProfile(player)
	local tier = RecipeConfig.RestaurantTiers[profile.RestaurantLevel] or RecipeConfig.RestaurantTiers[1]
	local eventCoinsMultAttr = ReplicatedStorage:GetAttribute("ActiveEventCoinsMult")
	local eventRepMultAttr = ReplicatedStorage:GetAttribute("ActiveEventRepMult")
	local eventCoinsMult = (if typeof(eventCoinsMultAttr) == "number" then eventCoinsMultAttr else 1.0) * (if ReplicatedStorage:GetAttribute("IsNight") == true then 1.35 else 1.0)
	local eventRepMult = if typeof(eventRepMultAttr) == "number" then eventRepMultAttr else 1.0
	local passCoinsMult = MonetizationService.GetPayoutMultiplier(player)
	local passRepMult = MonetizationService.GetRepMultiplier(player)
	local waiterTipMult = CrewService.GetWaiterTipMultiplier(player) * (if PlayerDataService.HasBusiness(player, "DowntownLounge") then 1.15 else 1.0)
	local starMult = RestaurantService.GetRestaurantStarInfo(player).Multiplier or 1.0
	local rankMult = SyndicateContractService.GetRankPayoutMultiplier(player) * PlayerDataService.GetPrestigeMultiplier(player)
	local pricing = profile.MenuPricing or "Standard"
	local priceCoinMult = if pricing == "Luxury" then 1.35 elseif pricing == "Budget" then 0.85 else 1.0
	local priceRepMult = if pricing == "Budget" then 1.25 else 1.0
	local weatherHotAttr = ReplicatedStorage:GetAttribute("HotComfortWeatherMult")
	local weatherHotMult = if typeof(weatherHotAttr) == "number" then weatherHotAttr else 1.0
	refreshCityCraving()
	local totalCoins = 0
	local totalExp = 0
	local totalRep = 0
	local servedCopy: { [string]: number } = {}
	local dishNames: { string } = {}

	for recipeId, qty in pairs(kitchen.ReadyDishes) do
		local recipe = RecipeConfig.Recipes[recipeId]
		if recipe and qty > 0 then
			servedCopy[recipeId] = qty
			table.insert(dishNames, recipe.DisplayName)
			local mwCount = math.min(qty, kitchen.MasterworkBonusCount)
			kitchen.MasterworkBonusCount = math.max(0, kitchen.MasterworkBonusCount - mwCount)
			local normalCount = qty - mwCount
			local cravingMult = if recipeId == cityCravingRecipeId then 1.50 else 1.0
			local dishHotMult = if recipe.IsHotComfort then weatherHotMult else 1.0
			-- Additive bonus economy with realistic cap (prevents runaway 30,000G+ single-dish inflation!)
			local bonusSum = (tier.PayoutMultiplier - 1.0)
				+ (eventCoinsMult - 1.0) * 0.50
				+ (waiterTipMult - 1.0)
				+ (starMult - 1.0)
				+ (rankMult - 1.0)
				+ (priceCoinMult - 1.0)
				+ (cravingMult - 1.0)
				+ (dishHotMult - 1.0)
			local cappedFreeMult = math.clamp(1.0 + bonusSum, 0.85, 3.50)
			local finalMult = math.min(cappedFreeMult * passCoinsMult, 6.00)
			local baseCoin = recipe.CoinsReward * finalMult
			totalCoins += math.floor(baseCoin) * normalCount + math.floor(baseCoin * 1.25) * mwCount
			totalExp += recipe.ExpReward * qty
			local baseRep = recipe.ReputationReward * math.min(eventRepMult * passRepMult * starMult * priceRepMult, 4.0)
			totalRep += math.floor(baseRep) * normalCount + math.floor(baseRep * 1.25) * mwCount
		end
	end

	table.clear(kitchen.ReadyDishes)
	clearPlatters(player)
	PlayerDataService.AddDishesServed(player, totalDishes)
	PlayerDataService.AddRewards(player, totalCoins, totalExp, totalRep)
	SyndicateContractService.RecordProgress(player, "CookDishes", totalDishes)
	local vipCompleted, vipMsg = VIPOrderService.TryFulfillFromServed(player, servedCopy)
	local urgentCust = findMostUrgentWaitingCustomer(player, true)
	local custName = if urgentCust
		then urgentCust.Name
		elseif waitingOrders[player] then waitingOrders[player].CustomerName
		else CUSTOMER_NAMES[math.random(1, #CUSTOMER_NAMES)]
	local chefLabel = if MonetizationService.HasPass(player, "MasterProChef")
		then "Master Pro Chef"
		elseif CrewService.GetCrewCount(player) > 0 then "Crew Chef"
		else player.DisplayName
	local firstRecipeId: string? = nil
	for recipeId in pairs(servedCopy) do
		firstRecipeId = recipeId
		break
	end
	local receipt = printRestaurantReceipt(player, custName, table.concat(dishNames, ", "), totalCoins, totalRep, chefLabel)
	local dishesToDeliver = math.clamp(totalDishes, 1, 3)
	local perDishGold = math.max(1, math.floor(totalCoins / dishesToDeliver))
	for dIdx = 1, dishesToDeliver do
		local dHint = if dIdx == 1 then (firstRecipeId or dishNames[1]) else (dishNames[dIdx] or firstRecipeId or "House Feast")
		local dLabel = dishNames[dIdx] or dishNames[1] or "House Feast"
		if dIdx == 1 then
			dispatchCustomerToEatAndLeave(player, perDishGold, dHint, dLabel, urgentCust)
		else
			task.delay((dIdx - 1) * 0.45, function()
				if isRunning and player.Parent then
					dispatchCustomerToEatAndLeave(player, perDishGold, dHint, dLabel, nil)
				end
			end)
		end
	end
	syncPrimaryWaitingOrder(player)
	RestaurantService.PushStateToClient(player)

	local msg = if vipCompleted and vipMsg
		then vipMsg
		else string.format("Receipt #%d: +%d Gold, +%d EXP, +%d Rep!", receipt.OrderNo, totalCoins, totalExp, totalRep)
	print("[RestaurantService]", player.Name, msg)
	return true, msg
end

function RestaurantService.ServeWaitingCustomerOrder(player: Player, chefOverride: string?): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Castle Base first!"
	end

	-- Respect kitchen capacity (scales with physical HQ expansion Lv.1-5 + Dual Stove bonus) to prevent spam/duplicate cooking!
	local profCheck = PlayerDataService.GetProfile(player)
	local expSpecCheck = RestaurantExpansionConfig.GetTierSpec(profCheck.RestaurantLevel or 1)
	local maxConcurrent = expSpecCheck.MaxConcurrentOrders + (if profCheck.HasDualStove == true then 1 else 0)
	local cookingNow = 0
	local curList = activeWalkingCustomers[player]
	if curList then
		for _, wc in ipairs(curList) do
			if wc.Model.Parent and wc.IsBeingCooked and not wc.IsExpired and not wc.IsServed then
				cookingNow += 1
			end
		end
	end
	if cookingNow >= maxConcurrent then
		return false, if maxConcurrent >= 2
			then string.format("All %d kitchen stations are already cooking active table orders!", maxConcurrent)
			else "Stove is already cooking an active table order!"
	end

	-- Bind strictly to the most urgent seated, non-expired, unserved customer!
	local targetCust = findMostUrgentWaitingCustomer(player, false)
	if not targetCust then
		local alreadyCooking = findMostUrgentWaitingCustomer(player, true)
		if alreadyCooking and alreadyCooking.IsBeingCooked then
			return false, "Chef is already cooking for " .. alreadyCooking.Name .. "!"
		end
		return false, "No seated customer waiting right now!"
	end

	local order = targetCust.Order
	if not order or order.Cancelled or targetCust.IsExpired or targetCust.IsServed then
		syncPrimaryWaitingOrder(player)
		return false, "That customer's order is no longer active!"
	end
	if order.IsBeingCooked or targetCust.IsBeingCooked then
		return false, "Chef is already cooking for " .. targetCust.Name .. "!"
	end

	local orderId = targetCust.OrderId
	targetCust.IsBeingCooked = true
	order.IsBeingCooked = true
	waitingOrders[player] = order

	local usedRecipeId: string? = nil
	if order.RecipeId then
		local spec = RecipeConfig.Recipes[order.RecipeId]
		if spec and WarehouseService.ConsumeIngredients(player, spec.Ingredients) then
			usedRecipeId = order.RecipeId
		end
	end

	local chefName = chefOverride or (if MonetizationService.HasPass(player, "MasterProChef")
		then "Master Pro Chef"
		elseif CrewService.GetCrewCount(player) > 0 then "Crew Chef"
		else player.DisplayName)

	local cookColor = if usedRecipeId and DISH_COLORS[usedRecipeId] then DISH_COLORS[usedRecipeId] else Color3.fromRGB(246, 178, 62)
	setGrillCookingVisual(player, true, cookColor)
	if usedRecipeId then
		local cat = getPrimaryCategoryForRecipe(usedRecipeId)
		spawnWarehouseFetchChef(player, cat, order.DishName, chefName)
		if targetCust.Model.Parent and not targetCust.IsExpired then
			targetCust.BubbleText.Text = string.format("%s: Chef preparing %s...", targetCust.Name, order.DishName)
		end
		if MonetizationService.HasPass(player, "MasterProChef") then
			MonetizationService.SetProChefStatus(player, string.format("Fetched %s -> Cooking %s!", cat, order.DishName), true)
		end
	else
		if targetCust.Model.Parent and not targetCust.IsExpired then
			targetCust.BubbleText.Text = string.format("%s: Chef cooking %s...", targetCust.Name, order.DishName)
		end
		if MonetizationService.HasPass(player, "MasterProChef") then
			MonetizationService.SetProChefStatus(player, "Cooking " .. order.DishName .. " for " .. order.CustomerName .. "!", true)
		end
	end

	local profile = PlayerDataService.GetProfile(player)
	local tier = RecipeConfig.RestaurantTiers[profile.RestaurantLevel] or RecipeConfig.RestaurantTiers[1]
	local speedMult = tier.CookSpeedMultiplier * CrewService.GetCookSpeedMultiplier(player) * MonetizationService.GetCookSpeedMultiplier(player)
	local baseCookSec = 5.0
	if order.RecipeId and RecipeConfig.Recipes[order.RecipeId] then
		baseCookSec = RecipeConfig.Recipes[order.RecipeId].CookTime
	end
	local maxQuickSec = RestaurantSecurityConfig.CustomerPatience.MaxQuickServeCookSeconds
	local cookTime = math.clamp(baseCookSec / speedMult, 1.8, maxQuickSec)
	local kitchen = ensureKitchen(player)
	local ownsStoveVisual = not kitchen.IsCooking
	if ownsStoveVisual then
		kitchen.IsCooking = true
		kitchen.CurrentRecipeId = order.RecipeId or order.DishName
		kitchen.CookEndsAt = os.clock() + cookTime
	end
	RestaurantService.PushStateToClient(player)

	task.delay(cookTime, function()
		if not player.Parent then
			return
		end
		if ownsStoveVisual then
			kitchen.IsCooking = false
			kitchen.CurrentRecipeId = nil
			kitchen.CookEndsAt = 0
		end
		setGrillCookingVisual(player, false, nil)

		-- Strict anti-duplicate & expiry guard: NEVER pay or serve if customer expired, left, or was already served!
		if order.Cancelled
			or targetCust.IsExpired
			or targetCust.IsServed
			or targetCust.Phase ~= "SeatedWaiting"
			or not targetCust.Model.Parent
			or targetCust.OrderId ~= orderId
		then
			targetCust.IsBeingCooked = false
			order.IsBeingCooked = false
			syncPrimaryWaitingOrder(player)
			RestaurantService.PushStateToClient(player)
			return
		end

		-- Atomically stop patience timer & lock customer served BEFORE awarding payment!
		stopCustomerPatience(targetCust)
		targetCust.IsBeingCooked = false
		order.IsBeingCooked = false

		local eventCoinsMultAttr = ReplicatedStorage:GetAttribute("ActiveEventCoinsMult")
		local eventRepMultAttr = ReplicatedStorage:GetAttribute("ActiveEventRepMult")
		local eventCoinsMult = (if typeof(eventCoinsMultAttr) == "number" then eventCoinsMultAttr else 1.0) * (if ReplicatedStorage:GetAttribute("IsNight") == true then 1.35 else 1.0)
		local eventRepMult = if typeof(eventRepMultAttr) == "number" then eventRepMultAttr else 1.0
		local passCoinsMult = MonetizationService.GetPayoutMultiplier(player)
		local passRepMult = MonetizationService.GetRepMultiplier(player)
		local waiterTipMult = CrewService.GetWaiterTipMultiplier(player)
		local starMult = RestaurantService.GetRestaurantStarInfo(player).Multiplier or 1.0
		local rankMult = SyndicateContractService.GetRankPayoutMultiplier(player)

		local bonusSum = (tier.PayoutMultiplier - 1.0)
			+ (eventCoinsMult - 1.0) * 0.50
			+ (waiterTipMult - 1.0)
			+ (starMult - 1.0)
			+ (rankMult - 1.0)
		local cappedFreeMult = math.clamp(1.0 + bonusSum, 0.85, 3.25)
		local finalMult = math.min(cappedFreeMult * passCoinsMult, 5.50)
		local earnedGold = math.max(8, math.floor(order.BaseGold * finalMult))
		local earnedRep = math.max(3, math.floor(order.BaseRep * math.min(eventRepMult * passRepMult * starMult, 4.0)))
		local earnedExp = math.max(10, math.floor(order.BaseGold * 0.4))

		local dispatched = dispatchCustomerToEatAndLeave(player, earnedGold, usedRecipeId or order.DishName, order.DishName, targetCust)
		if not dispatched then
			syncPrimaryWaitingOrder(player)
			RestaurantService.PushStateToClient(player)
			return
		end

		PlayerDataService.AddDishesServed(player, 1)
		PlayerDataService.AddRewards(player, earnedGold, earnedExp, earnedRep)
		SyndicateContractService.RecordProgress(player, "CookDishes", 1)
		if usedRecipeId and SPECIALTY_RECIPE_IDS[usedRecipeId] then
			specialtyCookCounts[player] = (specialtyCookCounts[player] or 0) + 1
			SyndicateContractService.RecordProgress(player, "SpecialtyFeast", 1)
		end
		if usedRecipeId then
			VIPOrderService.TryFulfillFromServed(player, { [usedRecipeId] = 1 })
		end

		local receipt = printRestaurantReceipt(player, order.CustomerName, order.DishName, earnedGold, earnedRep, chefName)
		if MonetizationService.HasPass(player, "MasterProChef") then
			MonetizationService.SetProChefStatus(player, string.format("Receipt #%d (+%d Gold)!", receipt.OrderNo, earnedGold), true)
		end

		syncPrimaryWaitingOrder(player)
		RestaurantService.PushStateToClient(player)
	end)

	return true, string.format("%s is cooking %s for %s!", chefName, order.DishName, order.CustomerName)
end

function RestaurantService.TryUpgradeRestaurant(player: Player, bypassGold: boolean?): (boolean, string)
	local profile = PlayerDataService.GetProfile(player)
	local nextTier = RecipeConfig.RestaurantTiers[profile.RestaurantLevel + 1]
	if not nextTier then
		return false, "Restaurant HQ is at Max Level 15!"
	end

	-- Enforce Food Sold & Player Level requirements on BOTH Gold AND Robux upgrades (prevents unfair Level-1 Robux skipping!)
	local reqOk, reqMsg = RestaurantService.CheckHQUpgradeRequirements(player)
	if not reqOk then
		return false, reqMsg
	end

	if not bypassGold and not PlayerDataService.SpendCoins(player, nextTier.UpgradeCost) then
		return false, string.format("Need %d Gold to upgrade Restaurant HQ!", nextTier.UpgradeCost)
	end

	PlayerDataService.SetRestaurantLevel(player, nextTier.Level)
	syncRestaurantVisuals(player)
	RestaurantService.PushStateToClient(player)
	local newExp = RestaurantExpansionConfig.GetTierSpec(nextTier.Level)
	return true, string.format(
		"Expanded Restaurant HQ & %s to Lv.%d (%dF • %d Max Customers)!",
		newExp.FrontPavilionName,
		nextTier.Level,
		newExp.Floors,
		getMaxCustomersForHQ(player)
	)
end

function RestaurantService.TryUpgradeDefenses(player: Player, bypassGold: boolean?): (boolean, string)
	local profile = PlayerDataService.GetProfile(player)
	local nextLevel = profile.DefenseLevel + 1
	local cost = DEFENSE_UPGRADE_COSTS[nextLevel]
	if not cost then
		return false, "Castle Defenses are at Max Tier!"
	end

	if not bypassGold and not PlayerDataService.SpendCoins(player, cost) then
		return false, string.format("Need %d Gold to upgrade Defenses!", cost)
	end

	PlayerDataService.SetDefenseLevel(player, nextLevel)
	RestaurantService.PushStateToClient(player)
	return true, string.format("Upgraded Castle Defenses to Tier %d!", nextLevel)
end

local function ensurePrompt(parent: BasePart, name: string, actionText: string, objectText: string): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		existing.ActionText = actionText
		existing.ObjectText = objectText
		return existing
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = 0.25
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.ActionText = actionText
	p.ObjectText = objectText
	p.Parent = parent
	return p
end

local function wireRestaurantPrompts(): ()
	for _, cookPart in ipairs(CollectionService:GetTagged("CookingStation")) do
		if cookPart:IsA("BasePart") then
			local slotAttr = cookPart:GetAttribute("BaseSlot")
			local prompt = ensurePrompt(cookPart, "CookPrompt", "Cook / Sear Boost [E]", "Commercial Chef's Range")
			table.insert(
				promptConnections,
				prompt.Triggered:Connect(function(player)
					if typeof(slotAttr) == "string" and BaseService.GetPlayerBaseSlot(player) ~= slotAttr then
						return
					end
					local k = ensureKitchen(player)
					if (k.IsCooking and not k.Boosted1) or (k.IsCooking2 and not k.Boosted2) then
						local _, msg = RestaurantService.TrySearBoost(player)
						local remotes = ReplicatedStorage:FindFirstChild("Remotes")
						local toastEv = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
						if toastEv and toastEv:IsA("RemoteEvent") then
							toastEv:FireClient(player, msg)
						end
						return
					end
					local best = RestaurantService.PickBestAvailableRecipe(player)
					if best then
						RestaurantService.CookRecipe(player, best)
					else
						RestaurantService.PushStateToClient(player)
					end
				end)
			)
		end
	end

	for _, servePart in ipairs(CollectionService:GetTagged("ServeCounter")) do
		if servePart:IsA("BasePart") then
			local slotAttr = servePart:GetAttribute("BaseSlot")
			local prompt = ensurePrompt(servePart, "ServePrompt", "Sell Ready Food", "Serve Counter")
			table.insert(
				promptConnections,
				prompt.Triggered:Connect(function(player)
					if typeof(slotAttr) == "string" and BaseService.GetPlayerBaseSlot(player) ~= slotAttr then
						return
					end
					RestaurantService.ServeAllReadyDishes(player)
				end)
			)
		end
	end

	for _, upgPart in ipairs(CollectionService:GetTagged("UpgradePad")) do
		if upgPart:IsA("BasePart") then
			local slotAttr = upgPart:GetAttribute("BaseSlot")
			local prompt = ensurePrompt(upgPart, "UpgradeHQPrompt", "Upgrade Restaurant HQ", "Empire Upgrades")
			table.insert(
				promptConnections,
				prompt.Triggered:Connect(function(player)
					if typeof(slotAttr) == "string" and BaseService.GetPlayerBaseSlot(player) ~= slotAttr then
						return
					end
					local okUpg, msgUpg = RestaurantService.TryUpgradeRestaurant(player)
					local remotes = ReplicatedStorage:FindFirstChild("Remotes")
					local toastEv = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
					if toastEv and toastEv:IsA("RemoteEvent") then
						toastEv:FireClient(player, (if okUpg then "🏛️ " else "🔒 ") .. msgUpg)
					end
				end)
			)
		end
	end

	-- Wire Cash Register Order & Receipt Prompts in all 4 Restaurant HQs!
	local map = workspace:FindFirstChild("FoodEmpireMap")
	local bases = if map then map:FindFirstChild("PlayerBases") else nil
	if bases then
		for _, base in ipairs(bases:GetChildren()) do
			local slotAttr = base:GetAttribute("BaseSlot")
			local regPrompt = base:FindFirstChild("TakeCustomerOrderPrompt", true)
			if regPrompt and regPrompt:IsA("ProximityPrompt") then
				table.insert(
					promptConnections,
					regPrompt.Triggered:Connect(function(player)
						if typeof(slotAttr) == "string" and BaseService.GetPlayerBaseSlot(player) ~= slotAttr then
							return
						end
						RestaurantService.ServeWaitingCustomerOrder(player, nil)
					end)
				)
			end
			-- Wire Front Staff Hiring Kiosk Prompt in all 4 Restaurant Plazas!
			local staffPrompt = base:FindFirstChild("HireStaffKioskPrompt", true)
			if staffPrompt and staffPrompt:IsA("ProximityPrompt") then
				table.insert(
					promptConnections,
					staffPrompt.Triggered:Connect(function(player)
						if typeof(slotAttr) == "string" and BaseService.GetPlayerBaseSlot(player) ~= slotAttr then
							return
						end
						local ok, msg = CrewService.TryHireCrew(player)
						local remotes = ReplicatedStorage:FindFirstChild("Remotes")
						local toastEv = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
						if toastEv and toastEv:IsA("RemoteEvent") then
							toastEv:FireClient(player, (if ok then "👨‍🍳 " else "⚠️ ") .. msg)
						end
						RestaurantService.PushStateToClient(player)
					end)
				)
			end
		end
	end
end

local function setupRemotes(): ()
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		local f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
		remotesFolder = f
	end

	local ev = remotesFolder:FindFirstChild("StateSync")
	if ev and ev:IsA("RemoteEvent") then
		stateEvent = ev
	else
		local created = Instance.new("RemoteEvent")
		created.Name = "StateSync"
		created.Parent = remotesFolder
		stateEvent = created
	end

	local fn = remotesFolder:FindFirstChild("ActionRequest")
	if fn and fn:IsA("RemoteFunction") then
		actionFunc = fn
	else
		local created = Instance.new("RemoteFunction")
		created.Name = "ActionRequest"
		created.Parent = remotesFolder
		actionFunc = created
	end

	if actionFunc then
		actionFunc.OnServerInvoke = function(player: Player, action: string, arg: any): { Success: boolean, Message: string, SpinResult: any?, State: any }
			local ok = false
			local msg = "Invalid action"
			local spinResult: any = nil

			if action == "GetState" then
				ok, msg = true, "OK"
			elseif action == "CookRecipe" and typeof(arg) == "string" then
				ok, msg = RestaurantService.CookRecipe(player, arg)
			elseif action == "ServeFood" then
				local k = ensureKitchen(player)
				if countReadyDishes(k) > 0 then
					ok, msg = RestaurantService.ServeAllReadyDishes(player)
				else
					ok, msg = RestaurantService.ServeWaitingCustomerOrder(player, nil)
				end
			elseif action == "ServeCustomerOrder" then
				ok, msg = RestaurantService.ServeWaitingCustomerOrder(player, nil)
			elseif action == "AcceptExpressDelivery" then
				ok, msg = ExpressDeliveryService.AcceptDelivery(player)
			elseif action == "HireBodyguard" then
				ok, msg = BodyguardService.TryHireBodyguard(player)
			elseif action == "RecruitBodyguard" and typeof(arg) == "table" and typeof(arg.ClassId) == "string" then
				local slotIdx = if typeof(arg.SlotIndex) == "number" then arg.SlotIndex else nil
				local useRobux = arg.UseRobux == true
				local autoDefendHQ = arg.AutoDefendHQ == true
				ok, msg = BodyguardService.TryRecruitClass(player, arg.ClassId, slotIdx, useRobux, autoDefendHQ)
			elseif action == "BuyGuardGear" and typeof(arg) == "string" then
				ok, msg = BodyguardService.TryBuyGear(player, arg)
			elseif action == "EquipGuardGear" and typeof(arg) == "table" and typeof(arg.SlotIndex) == "number" and typeof(arg.GearId) == "string" then
				ok, msg = BodyguardService.TryEquipGear(player, arg.SlotIndex, arg.GearId)
			elseif action == "DispatchDeliveryRunner" then
				ok, msg = DeliveryRunnerService.DispatchRunner(player)
			elseif action == "HireCourier" then
				ok, msg = DeliveryRunnerService.TryHireCourier(player)
				if ok then SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1) end
			elseif action == "HireWaiter" then
				ok, msg = CrewService.TryHireWaiter(player)
				if ok then SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1) end
			elseif action == "BuyCentralParkBranch" then
				ok, msg = CentralParkBranchService.TryBuyBranch(player)
			elseif action == "ToggleCentralParkStaff" then
				ok, msg = CentralParkBranchService.TryToggleStaff(player)
			elseif action == "TeleportCentralParkBranch" then
				ok, msg = CentralParkBranchService.TeleportToBranch(player)
			elseif action == "DefendCentralParkBranch" then
				ok, msg = CentralParkBranchService.TryDefendShakedown(player)
			elseif action == "ClaimSyndicateContract" and typeof(arg) == "number" then
				ok, msg = SyndicateContractService.ClaimOrRerollContract(player, math.floor(arg))
			elseif action == "StartSmugglerConvoy" then
				ok, msg = SyndicateContractService.StartSmugglerConvoy(player)
			elseif action == "StartGangWarDrop" then
				ok, msg = SyndicateContractService.StartGangWarDrop(player)
			elseif action == "TriggerBikeTurbo" then
				ok, msg = ScooterService.TriggerTurbo(player)
			elseif action == "BuyDualStove" then
				ok, msg = RestaurantService.TryBuyDualStove(player)
			elseif action == "BuyVIPBooths" then
				ok, msg = RestaurantService.TryBuyVIPBooths(player)
			elseif action == "SearBoostCook" then
				ok, msg = RestaurantService.TrySearBoost(player)
			elseif action == "SetGuardStance" then
				ok, msg = if typeof(arg) == "string" and arg ~= "" then BodyguardService.SetSquadStance(player, arg) else BodyguardService.CycleSquadStance(player)
			elseif action == "CrackTerritoryVault" then
				ok, msg = ShipmentService.TryCrackTerritoryVault(player, if typeof(arg) == "string" then arg else nil)
			elseif action == "BuyMafiaSedan" then
				ok, msg = ScooterService.BuySedanWithCoins(player)
			elseif action == "ToggleMafiaSedan" then
				ok, msg = ScooterService.ToggleMafiaSedan(player)
			elseif action == "BuyWeaponMod" and typeof(arg) == "table" and typeof(arg.WeaponId) == "string" and typeof(arg.ModId) == "string" then
				ok, msg = BlackMarketService.BuyWeaponMod(player, arg.WeaponId, arg.ModId)
			elseif action == "ClaimEmperorTribute" then
				ok, msg = CentralEventService.TryClaimEmperorTribute(player)
			elseif action == "SetMenuPricing" and typeof(arg) == "string" then
				PlayerDataService.SetMenuPricing(player, arg)
				ok, msg = true, string.format("Restaurant Menu Pricing set to %s!", string.upper(arg))
			elseif action == "BuySmokeGrenades" then
				ok, msg = BlackMarketService.BuySmokeGrenades(player)
			elseif action == "ThrowSmokeGrenade" then
				ok, msg = BlackMarketService.ThrowSmokeGrenade(player)
			elseif action == "BuyFlashbangs" then
				ok, msg = BlackMarketService.BuyFlashbangs(player)
			elseif action == "ThrowFlashbang" then
				ok, msg = BlackMarketService.ThrowFlashbang(player)
			elseif action == "BuyC4Charges" then
				ok, msg = BlackMarketService.BuyC4Charges(player)
			elseif action == "DeployC4Charge" then
				ok, msg = BlackMarketService.DeployC4Charge(player)
			elseif action == "BuyShadowDash" then
				ok, msg = BlackMarketService.BuyShadowDash(player)
			elseif action == "TriggerShadowDash" then
				ok, msg = BlackMarketService.TriggerShadowDash(player)
			elseif action == "EquipWeaponMasterySkin" and typeof(arg) == "table" and typeof(arg.WeaponId) == "string" and typeof(arg.SkinId) == "string" then
				ok, msg = BlackMarketService.EquipWeaponMasterySkin(player, arg.WeaponId, arg.SkinId)
			elseif action == "HireMercenaryMafia" and typeof(arg) == "string" then
				ok, msg = MercenaryMafiaService.TryHireWithGold(player, arg)
			elseif action == "HireDefenseCompanion" and typeof(arg) == "table" and typeof(arg.CompanionType) == "string" then
				local durMin = if typeof(arg.DurationMinutes) == "number" then arg.DurationMinutes else 5
				ok, msg = DefenseCompanionService.TryHireCompanion(player, arg.CompanionType, durMin, false)
			elseif action == "OrderMercenaryAssault" then
				ok, msg = MercenaryMafiaService.OrderAssault(player, if typeof(arg) == "string" then arg else nil)
			elseif action == "HireMafiaRestaurantChef" and typeof(arg) == "string" then
				ok, msg = MafiaRestaurantService.TryHireChef(player, arg)
			elseif action == "TeleportMafiaRestaurant" and typeof(arg) == "string" then
				ok, msg = MafiaRestaurantService.TeleportToRestaurant(player, arg)
			elseif action == "BuyFrontBusiness" and typeof(arg) == "string" then
				ok, msg = MafiaBusinessService.BuyBusiness(player, arg)
			elseif action == "CollectBusinessSafe" then
				ok, msg = MafiaBusinessService.CollectSafe(player, if typeof(arg) == "string" then arg else nil)
			elseif action == "StartPenthouseHeist" then
				ok, msg = SyndicateRaidService.StartHeist(player)
			elseif action == "AcceptHitContract" then
				ok, msg = BountyService.AcceptHitContract(player)
			elseif action == "PlacePlayerBounty" then
				local targetN = if typeof(arg) == "table" and typeof(arg.Target) == "string" then arg.Target else nil
				local amt = if typeof(arg) == "table" and typeof(arg.Amount) == "number" then arg.Amount else 250
				ok, msg = BountyService.PlacePlayerBounty(player, targetN, amt)
			elseif action == "RaidBlackoutTruck" then
				ok, msg = WeatherService.TryRaidBlackoutTruck(player)
			elseif action == "CycleWeather" then
				ok, msg = WeatherService.CycleWeather()
			elseif action == "CommandAllAttack" then
				local bgOk, bgMsg = BodyguardService.CommandAttack(player)
				local mOk, mMsg = MercenaryMafiaService.CommandAttack(player)
				ok = bgOk or mOk
				msg = if mOk then "ALL UNITS (BODYGUARDS & HIRED MAFIA) ORDERED TO ATTACK!" else bgMsg
			elseif action == "CommandAllRecall" then
				local bgOk, bgMsg = BodyguardService.CommandRecall(player)
				local mOk, mMsg = MercenaryMafiaService.CommandRecall(player)
				ok = bgOk or mOk
				msg = if mOk then "ALL UNITS (BODYGUARDS & HIRED MAFIA) CALLED BACK TO YOUR SIDE!" else bgMsg
			elseif action == "CreateFamily" then
				ok, msg = SyndicateFamilyService.CreateFamily(player, if typeof(arg) == "string" then arg else nil)
			elseif action == "JoinFamily" then
				ok, msg = SyndicateFamilyService.JoinFamily(player, if typeof(arg) == "string" then arg else nil)
			elseif action == "LeaveFamily" then
				ok, msg = SyndicateFamilyService.LeaveFamily(player)
			elseif action == "BuyArmoredVan" then
				ok, msg = ScooterService.BuyArmoredVan(player)
			elseif action == "ToggleArmoredVan" then
				ok, msg = ScooterService.ToggleArmoredVan(player)
			elseif action == "BuyGetawayCoupe" then
				ok, msg = ScooterService.BuyGetawayCoupe(player)
			elseif action == "ToggleGetawayCoupe" then
				ok, msg = ScooterService.ToggleGetawayCoupe(player)
			elseif action == "BuyVehicleArmor" then
				ok, msg = ScooterService.BuyVehicleArmor(player)
			elseif action == "SetVehiclePaint" and typeof(arg) == "string" then
				ok, msg = ScooterService.SetVehiclePaint(player, arg)
			elseif action == "ClaimDailyVault" then
				ok, msg = PrestigeVaultService.ClaimDailyVault(player)
			elseif action == "TriggerGodfatherPrestige" then
				ok, msg = PrestigeVaultService.TriggerGodfatherPrestige(player)
				if ok then syncRestaurantVisuals(player) end
			elseif action == "TeleportSpinWheel" then
				ok, msg = SpinEventService.TeleportToWheel(player)
			elseif action == "SpinMarketWheel" then
				ok, msg, spinResult = SpinEventService.TrySpin(player)
			elseif action == "BuyBlackMarketItem" and typeof(arg) == "string" then
				ok, msg = BlackMarketService.BuyItem(player, arg)
			elseif action == "BuyAmmo" and typeof(arg) == "table" and typeof(arg.AmmoType) == "string" and typeof(arg.PackIndex) == "number" then
				ok, msg = BlackMarketService.BuyAmmo(player, arg.AmmoType, arg.PackIndex)
			elseif action == "TeleportBlackMarket" then
				ok, msg = BlackMarketService.TeleportToBlackMarket(player)
			elseif action == "SkipDayNight" then
				ok, msg = DayNightService.SkipPhase(player)
			elseif action == "UpgradeRestaurant" then
				ok, msg = RestaurantService.TryUpgradeRestaurant(player)
				if ok then SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1) end
			elseif action == "UpgradeWarehouse" and typeof(arg) == "string" and WarehouseConfig.Specs[arg :: WarehouseConfig.WarehouseCategory] then
				ok, msg = WarehouseService.TryUpgradeWarehouse(player, arg :: WarehouseConfig.WarehouseCategory)
				if ok then SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1) end
			elseif action == "MoveWarehouse" and typeof(arg) == "string" and WarehouseConfig.Specs[arg :: WarehouseConfig.WarehouseCategory] then
				ok, msg = WarehouseService.MoveWarehouseToNextPlot(player, arg :: WarehouseConfig.WarehouseCategory)
			elseif action == "HireCrew" then
				ok, msg = CrewService.TryHireCrew(player)
				if ok then SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1) end
			elseif action == "HireRaider" then
				ok, msg = RaiderChefService.TryHireRaider(player)
			elseif action == "UpgradeDefenses" then
				ok, msg = RestaurantService.TryUpgradeDefenses(player)
			elseif action == "ReturnHome" then
				ok, msg = tryReturnHome(player)
			elseif action == "ToggleScooter" then
				ok, msg = ScooterService.ToggleScooter(player)
			elseif action == "BuyMotorbikeCoins" then
				ok, msg = ScooterService.BuyWithCoins(player)
			elseif action == "BuyRobuxItem" and typeof(arg) == "string" then
				ok, msg = MonetizationService.TryPromptPurchase(player, arg)
			elseif action == "BuyWithRobuxOption" and typeof(arg) == "table" and typeof(arg.Kind) == "string" then
				local kind = arg.Kind
				local subArg = arg.Arg
				local dualOpts = MonetizationConfig.DualRobuxOptions
				if kind == "UpgradeRestaurant" then
					local prof = PlayerDataService.GetProfile(player)
					local nextT = RecipeConfig.RestaurantTiers[prof.RestaurantLevel + 1]
					if not nextT then
						ok, msg = false, "Restaurant HQ is already at Max Level 15!"
					else
						local reqOk, reqMsg = RestaurantService.CheckHQUpgradeRequirements(player)
						if not reqOk then
							ok, msg = false, reqMsg
						else
							local rPrice = MonetizationConfig.GetHQUpgradeRobuxPrice(nextT.Level)
							local pKey = if nextT.Level <= 3 then "UpgradeHQ_Low"
								elseif nextT.Level <= 5 then "UpgradeHQ_Mid"
								elseif nextT.Level <= 8 then "UpgradeHQ_High"
								elseif nextT.Level <= 10 then "UpgradeHQ_Max"
								elseif nextT.Level <= 13 then "UpgradeHQ_Imperial"
								else "UpgradeHQ_Supreme"
							ok, msg = MonetizationService.TryPromptDualPurchase(player, pKey, rPrice, "Restaurant HQ Lv." .. tostring(nextT.Level), function()
								local uOk, uMsg = RestaurantService.TryUpgradeRestaurant(player, true)
								if uOk then SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1) end
								return uOk, uMsg
							end)
						end
					end
				elseif kind == "UpgradeWarehouse" and typeof(subArg) == "string" and WarehouseConfig.Specs[subArg :: WarehouseConfig.WarehouseCategory] then
					local cat = subArg :: WarehouseConfig.WarehouseCategory
					local spec = WarehouseConfig.Specs[cat]
					local curLv = WarehouseService.GetWarehouseLevel(player, cat)
					if curLv >= WarehouseConfig.MaxLevel then
						ok, msg = false, spec.DisplayName .. " is already at Max Level!"
					else
						local pKey = if curLv <= 0 then "UnlockWarehouse" else "UpgradeWarehouse"
						local opt = dualOpts[pKey]
						ok, msg = MonetizationService.TryPromptDualPurchase(player, pKey, opt.RobuxPrice, spec.DisplayName, function()
							local uOk, uMsg = WarehouseService.TryUpgradeWarehouse(player, cat, true)
							if uOk then SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1) end
							return uOk, uMsg
						end)
					end
				elseif kind == "BuyDualStove" then
					local opt = dualOpts.BuyDualStove
					ok, msg = MonetizationService.TryPromptDualPurchase(player, "BuyDualStove", opt.RobuxPrice, opt.DisplayName, function()
						return RestaurantService.TryBuyDualStove(player, true)
					end)
				elseif kind == "BuyVIPBooths" then
					local opt = dualOpts.BuyVIPBooths
					ok, msg = MonetizationService.TryPromptDualPurchase(player, "BuyVIPBooths", opt.RobuxPrice, opt.DisplayName, function()
						return RestaurantService.TryBuyVIPBooths(player, true)
					end)
				elseif kind == "HireCrew" then
					local opt = dualOpts.HireCrew
					ok, msg = MonetizationService.TryPromptDualPurchase(player, "HireCrew", opt.RobuxPrice, opt.DisplayName, function()
						local hOk, hMsg = CrewService.TryHireCrew(player, true)
						if hOk then SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1) end
						return hOk, hMsg
					end)
				elseif kind == "HireWaiter" then
					local opt = dualOpts.HireWaiter
					ok, msg = MonetizationService.TryPromptDualPurchase(player, "HireWaiter", opt.RobuxPrice, opt.DisplayName, function()
						local hOk, hMsg = CrewService.TryHireWaiter(player, true)
						if hOk then SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1) end
						return hOk, hMsg
					end)
				elseif kind == "HireCourier" then
					local opt = dualOpts.HireCourier
					ok, msg = MonetizationService.TryPromptDualPurchase(player, "HireCourier", opt.RobuxPrice, opt.DisplayName, function()
						local hOk, hMsg = DeliveryRunnerService.TryHireCourier(player, true)
						if hOk then SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1) end
						return hOk, hMsg
					end)
				elseif kind == "BuyCentralParkBranch" then
					local opt = dualOpts.BuyCentralParkBranch
					ok, msg = MonetizationService.TryPromptDualPurchase(player, "BuyCentralParkBranch", opt.RobuxPrice, opt.DisplayName, function()
						return CentralParkBranchService.TryBuyBranch(player, true)
					end)
				elseif kind == "UpgradeDefenses" then
					local opt = dualOpts.UpgradeDefenses
					ok, msg = MonetizationService.TryPromptDualPurchase(player, "UpgradeDefenses", opt.RobuxPrice, opt.DisplayName, function()
						return RestaurantService.TryUpgradeDefenses(player, true)
					end)
				elseif kind == "BuyBlackMarketItem" and typeof(subArg) == "string" then
					ok, msg = BlackMarketService.BuyItem(player, subArg, true, false)
				elseif kind == "BuyGuardGear" and typeof(subArg) == "string" then
					ok, msg = BodyguardService.TryBuyGear(player, subArg, true)
				elseif kind == "BuySmokeGrenades" then
					local prof = PlayerDataService.GetProfile(player)
					if (prof.SmokeGrenades or 0) >= 12 then
						ok, msg = false, "Smoke Grenades full (12/12)!"
					else
						local opt = dualOpts.BuySmokeGrenades
						ok, msg = MonetizationService.TryPromptDualPurchase(player, "BuySmokeGrenades", opt.RobuxPrice, opt.DisplayName, function()
							return BlackMarketService.BuySmokeGrenades(player, true)
						end)
					end
				elseif kind == "BuyFlashbangs" then
					local prof = PlayerDataService.GetProfile(player)
					if (prof.Flashbangs or 0) >= 12 then
						ok, msg = false, "Flashbangs full (12/12)!"
					else
						local opt = dualOpts.BuyFlashbangs
						ok, msg = MonetizationService.TryPromptDualPurchase(player, "BuyFlashbangs", opt.RobuxPrice, opt.DisplayName, function()
							return BlackMarketService.BuyFlashbangs(player, true)
						end)
					end
				elseif kind == "BuyC4Charges" then
					local prof = PlayerDataService.GetProfile(player)
					if (prof.C4Charges or 0) >= 8 then
						ok, msg = false, "C4 Breach Charges full (8/8)!"
					else
						local opt = dualOpts.BuyC4Charges
						ok, msg = MonetizationService.TryPromptDualPurchase(player, "BuyC4Charges", opt.RobuxPrice, opt.DisplayName, function()
							return BlackMarketService.BuyC4Charges(player, true)
						end)
					end
				elseif kind == "BuyShadowDash" then
					if PlayerDataService.HasShadowDash(player) then
						ok, msg = false, "Shadow Smoke Dash already unlocked!"
					else
						local opt = dualOpts.BuyShadowDash
						ok, msg = MonetizationService.TryPromptDualPurchase(player, "BuyShadowDash", opt.RobuxPrice, opt.DisplayName, function()
							return BlackMarketService.BuyShadowDash(player, true)
						end)
					end
				elseif kind == "HireDefenseCompanion" and typeof(subArg) == "table" and typeof(subArg.CompanionType) == "string" then
					local compType = subArg.CompanionType
					local durMin = if typeof(subArg.DurationMinutes) == "number" and subArg.DurationMinutes == 10 then 10 else 5
					local cSpec = RestaurantSecurityConfig.HiredCompanions.Types[compType :: RestaurantSecurityConfig.CompanionTypeId]
					if not cSpec then
						ok, msg = false, "Unknown defense companion!"
					else
						local canOk, canMsg = DefenseCompanionService.CanHireCompanion(player, compType, durMin)
						if not canOk then
							ok, msg = false, canMsg
						else
							local rPrice = if durMin == 10 then cSpec.Robux10Min else cSpec.Robux5Min
							local pKey = string.format("HireCompanion_%s_%dm", compType, durMin)
							ok, msg = MonetizationService.TryPromptDualPurchase(
								player,
								pKey,
								rPrice,
								string.format("%s (%dm Contract)", cSpec.DisplayName, durMin),
								function()
									return DefenseCompanionService.TryHireCompanion(player, compType, durMin, true)
								end
							)
						end
					end
				end
			elseif action == "ChooseBase" and typeof(arg) == "string" then
				ok, msg = BaseService.ClaimBaseSlot(player, arg :: any)
			elseif action == "SetSprint" and typeof(arg) == "boolean" then
				ok, msg = setPlayerSprint(player, arg)
			end

			return {
				Success = ok,
				Message = msg,
				SpinResult = spinResult,
				State = buildClientPayload(player),
			}
		end
	end
end

function RestaurantService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	ensureRestaurantCollisionGroups()
	local function hookPlayerCollision(player: Player)
		player.CharacterAdded:Connect(function(char: Model)
			task.defer(function()
				assignModelCollisionGroup(char, COLLISION_GROUP_PLAYERS)
			end)
		end)
		if player.Character then
			assignModelCollisionGroup(player.Character, COLLISION_GROUP_PLAYERS)
		end
	end
	Players.PlayerAdded:Connect(hookPlayerCollision)
	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayerCollision(p)
	end

	setupRemotes()
	wireRestaurantPrompts()

	-- True supply-chain separation:
	-- 1) Hired Chefs ONLY fetch ingredients from Warehouse & cook plated food onto Kitchen Counter!
	CrewService.SetAutoCookOnlyHandler(function(player)
		local kitchen = ensureKitchen(player)
		local prof = PlayerDataService.GetProfile(player)
		local hasDual = prof.HasDualStove == true
		local expTier = RestaurantExpansionConfig.GetTierSpec(prof.RestaurantLevel or 1)
		local canCookNow = (not kitchen.IsCooking) or (hasDual and not kitchen.IsCooking2)
		if canCookNow and countReadyDishes(kitchen) < expTier.KitchenReadyCapacity then
			local best = RestaurantService.PickBestAvailableRecipe(player)
			if best then
				RestaurantService.CookRecipe(player, best)
			end
		end
	end)

	-- 2) Hired Waiters ONLY pick up ready plated dishes from Kitchen Counter & deliver them to seated Customers!
	CrewService.SetAutoWaiterHandler(function(player)
		local kitchen = ensureKitchen(player)
		if countReadyDishes(kitchen) > 0 then
			RestaurantService.ServeAllReadyDishes(player)
		end
	end)

	CrewService.SetWaiterChangedHandler(function(player)
		spawnWaitStaffForPlayer(player)
		RestaurantService.PushStateToClient(player)
	end)

	CentralParkBranchService.SetChangedCallback(function(player)
		RestaurantService.PushStateToClient(player)
	end)

	SyndicateContractService.SetChangedCallback(function(player)
		RestaurantService.PushStateToClient(player)
	end)

	MafiaRestaurantService.SetChangedCallback(function(player)
		if player then
			RestaurantService.PushStateToClient(player)
		else
			for _, p in ipairs(Players:GetPlayers()) do
				RestaurantService.PushStateToClient(p)
			end
		end
	end)

	MercenaryMafiaService.SetChangedCallback(function(player)
		RestaurantService.PushStateToClient(player)
	end)

	DefenseCompanionService.SetChangedCallback(function(player)
		RestaurantService.PushStateToClient(player)
	end)

	NightMafiaRaidService.OnRaidWarning(function(payload)
		if payload.Owner and payload.Owner.Parent then
			RestaurantService.PushStateToClient(payload.Owner)
		end
	end)
	NightMafiaRaidService.OnRaidStarted(function(payload)
		if payload.Owner and payload.Owner.Parent then
			RestaurantService.PushStateToClient(payload.Owner)
		end
	end)
	NightMafiaRaidService.OnRaidEnded(function(summary)
		local owner = Players:GetPlayerByUserId(summary.OwnerUserId)
		if owner and owner.Parent then
			RestaurantService.PushStateToClient(owner)
		end
	end)

	MonetizationService.SetAutoCookHandler(function(player)
		local kitchen = ensureKitchen(player)
		if countReadyDishes(kitchen) > 0 then
			local servedOk, serveMsg = RestaurantService.ServeAllReadyDishes(player)
			if servedOk then
				MonetizationService.SetProChefStatus(player, "💰 Auto-Sold! " .. serveMsg, true)
			end
		end
		if not kitchen.IsCooking then
			local best = RestaurantService.PickBestAvailableRecipe(player)
			if best then
				local spec = RecipeConfig.Recipes[best]
				local cookOk = RestaurantService.CookRecipe(player, best)
				if cookOk then
					MonetizationService.SetProChefStatus(player, "🔥 Cooking " .. (if spec then spec.DisplayName else best) .. "!", true)
				end
			else
				MonetizationService.SetProChefStatus(player, "🐟 Sourcing ingredients soon...", false)
			end
		end
	end)

	MonetizationService.SetPurchaseChangedHandler(function(player, msg)
		RaiderChefService.SyncRaidersForPlayer(player)
		BlackMarketService.SyncPlayerAmmoAndGear(player)
		BodyguardService.RebuildGuardsForPlayer(player)
		RestaurantService.PushStateToClient(player)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local toastEv = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
		if toastEv and toastEv:IsA("RemoteEvent") then
			toastEv:FireClient(player, msg)
		end
	end)

	VIPOrderService.SetOrderUpdatedCallback(function(player, msg)
		RestaurantService.PushStateToClient(player)
		if msg then
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local toastEv = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
			if toastEv and toastEv:IsA("RemoteEvent") then
				toastEv:FireClient(player, msg)
			end
		end
	end)

	ExpressDeliveryService.SetUpdatedCallback(function(player, msg)
		RestaurantService.PushStateToClient(player)
		if msg then
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local toastEv = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
			if toastEv and toastEv:IsA("RemoteEvent") then
				toastEv:FireClient(player, msg)
			end
		end
	end)

	unsubProfile = PlayerDataService.OnProfileChanged(function(player)
		RestaurantService.PushStateToClient(player)
	end)

	unsubWarehouse = WarehouseService.OnInventoryChanged(function(player)
		RestaurantService.PushStateToClient(player)
	end)

	unsubSector = SectorService.OnSectorChanged(function()
		for _, p in ipairs(Players:GetPlayers()) do
			RestaurantService.PushStateToClient(p)
		end
	end)

	unsubShipments = ShipmentService.OnShipmentsChanged(function()
		for _, p in ipairs(Players:GetPlayers()) do
			RestaurantService.PushStateToClient(p)
		end
	end)

	unsubTurf = TurfService.OnTurfChanged(function()
		for _, p in ipairs(Players:GetPlayers()) do
			RestaurantService.PushStateToClient(p)
		end
	end)

	unsubBase = BaseService.OnBaseAssigned(function(player)
		spawnCustomersForPlayer(player)
		syncRestaurantVisuals(player)
		syncPrimaryWaitingOrder(player)
		for _, p in ipairs(Players:GetPlayers()) do
			RestaurantService.PushStateToClient(p)
		end
	end)

	for _, p in ipairs(Players:GetPlayers()) do
		if BaseService.GetPlayerBaseSlot(p) then
			spawnCustomersForPlayer(p)
			syncRestaurantVisuals(p)
			syncPrimaryWaitingOrder(p)
		end
	end

	-- Dedicated Server-Authoritative Customer Patience Loop (15-20s configurable timer, zero leaks, zero double-punish)
	patienceThread = task.spawn(function()
		local cfg = RestaurantSecurityConfig.CustomerPatience
		while isRunning do
			task.wait(math.max(0.1, cfg.TickInterval))
			if not isRunning then
				break
			end
			local now = os.clock()
			for player, list in pairs(activeWalkingCustomers) do
				if not player.Parent then
					clearCustomers(player)
					continue
				end
				for i = #list, 1, -1 do
					local wc = list[i]
					if not wc.Model.Parent then
						wc.PatienceActive = false
						if wc.Order and not wc.IsServed then
							wc.Order.Cancelled = true
						end
						table.remove(list, i)
					elseif wc.Phase == "SeatedWaiting" and wc.PatienceActive and not wc.IsServed and not wc.IsExpired then
						local rem = wc.PatienceExpiresAt - now
						if rem <= 0 then
							handleCustomerPatienceExpired(player, wc)
						else
							local frac = math.clamp(rem / math.max(1, wc.PatienceTotal), 0, 1)
							wc.PatienceBarFill.Size = UDim2.fromScale(frac, 1)
							if rem <= cfg.CriticalThresholdSeconds then
								wc.PatienceBarFill.BackgroundColor3 = Color3.fromRGB(204, 48, 56)
								wc.PatienceTimeLabel.Text = string.format("HURRY! %ds", math.ceil(rem))
							elseif rem <= cfg.WarningThresholdSeconds then
								wc.PatienceBarFill.BackgroundColor3 = Color3.fromRGB(214, 152, 42)
								wc.PatienceTimeLabel.Text = string.format("WAIT %ds", math.ceil(rem))
							else
								wc.PatienceBarFill.BackgroundColor3 = Color3.fromRGB(56, 158, 102)
								wc.PatienceTimeLabel.Text = if wc.IsBeingCooked
									then string.format("COOKING %ds", math.ceil(rem))
									else string.format("WAIT %ds", math.ceil(rem))
							end
						end
					end
				end
			end
		end
	end)

	-- Live Walk-In Customer Loop (scaled dynamically across Restaurant HQ & Front Wood Pavilion Levels 1-15!)
	customerOrderThread = task.spawn(function()
		while isRunning do
			task.wait(3.2)
			if not isRunning then
				break
			end
			for _, p in ipairs(Players:GetPlayers()) do
				if BaseService.GetPlayerBaseSlot(p) then
					-- Bigger Restaurant + Front Wood Pavilion attracts more simultaneous city customers!
					local wList = activeWalkingCustomers[p]
					local curCount = if wList then #wList else 0
					local maxGuests = getMaxCustomersForHQ(p)
					if curCount < maxGuests then
						local hqLv = PlayerDataService.GetProfile(p).RestaurantLevel or 1
						local waveCount = if hqLv >= 11 then 3 elseif hqLv >= 5 then 2 else 1
						local toSpawn = math.min(waveCount, maxGuests - curCount)
						for sIdx = 1, toSpawn do
							if sIdx == 1 then
								spawnSingleCityCustomer(p, 190)
							else
								task.delay((sIdx - 1) * 0.75, function()
									if isRunning and p.Parent and BaseService.GetPlayerBaseSlot(p) then
										spawnSingleCityCustomer(p, 198 + sIdx * 10)
									end
								end)
							end
						end
					end
					local urgent = findMostUrgentWaitingCustomer(p, false)
					if urgent then
						local hasChef = CrewService.GetCrewCount(p) > 0
						local hasWaiter = CrewService.GetWaiterCount(p) > 0
						local hasProChef = MonetizationService.HasPass(p, "MasterProChef")
						if (hasChef and hasWaiter) or hasProChef then
							RestaurantService.ServeWaitingCustomerOrder(p, nil)
						end
					end
				end
			end
		end
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		kitchens[player] = nil
		waitingOrders[player] = nil
		orderCounters[player] = nil
		receiptHistory[player] = nil
		clearCustomers(player)
		clearPlatters(player)
	end)

	print("[Food Empire] RestaurantService started (Cooking, Serving, Customer Patience 15-20s, HQ Upgrades & Remotes ready)!")
end

function RestaurantService.Stop(): ()
	isRunning = false
	if customerOrderThread then
		task.cancel(customerOrderThread)
		customerOrderThread = nil
	end
	if patienceThread then
		task.cancel(patienceThread)
		patienceThread = nil
	end
	for _, conn in ipairs(promptConnections) do
		conn:Disconnect()
	end
	table.clear(promptConnections)
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	if unsubBase then unsubBase(); unsubBase = nil end
	if unsubProfile then unsubProfile(); unsubProfile = nil end
	if unsubWarehouse then unsubWarehouse(); unsubWarehouse = nil end
	if unsubSector then unsubSector(); unsubSector = nil end
	if unsubShipments then unsubShipments(); unsubShipments = nil end
	if unsubTurf then unsubTurf(); unsubTurf = nil end
	for p in pairs(customerModels) do
		clearCustomers(p)
	end
	for p in pairs(activeWalkingCustomers) do
		clearCustomers(p)
	end
	for p in pairs(activeWaitStaff) do
		clearCustomers(p)
	end
end

return RestaurantService
