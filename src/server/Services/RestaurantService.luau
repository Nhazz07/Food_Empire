--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local RecipeConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RecipeConfig")
)
local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local BaseService = require("./BaseService")
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
	CustomerName: string,
	DishName: string,
	RecipeId: string?,
	BaseGold: number,
	BaseRep: number,
	IsBeingCooked: boolean,
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
	[2] = 500,
	[3] = 1200,
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
	{ Name = "Crispy Fish Skewers", Gold = 14, Rep = 3, Color = Color3.fromRGB(78, 192, 234) },
	{ Name = "Chef's Island Soup", Gold = 12, Rep = 3, Color = Color3.fromRGB(246, 178, 62) },
	{ Name = "Garlic Shrimp Bowl", Gold = 16, Rep = 4, Color = Color3.fromRGB(244, 118, 86) },
	{ Name = "Golden Fried Rice", Gold = 14, Rep = 3, Color = Color3.fromRGB(238, 198, 72) },
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
	TableOffset: Vector3,
	SeatOffset: Vector3,
	WaiterOffset: Vector3,
}

local FRONT_DINING_SPOTS: { DiningSpot } = {
	{ TableOffset = Vector3.new(-69, 3.88, 43), SeatOffset = Vector3.new(-69, 3.55, 46.5), WaiterOffset = Vector3.new(-65.2, 4.2, 43) },
	{ TableOffset = Vector3.new(-47, 3.88, 43), SeatOffset = Vector3.new(-47, 3.55, 46.5), WaiterOffset = Vector3.new(-43.2, 4.2, 43) },
	{ TableOffset = Vector3.new(-69, 3.88, 62), SeatOffset = Vector3.new(-69, 3.55, 65.5), WaiterOffset = Vector3.new(-65.2, 4.2, 62) },
	{ TableOffset = Vector3.new(-47, 3.88, 62), SeatOffset = Vector3.new(-47, 3.55, 65.5), WaiterOffset = Vector3.new(-43.2, 4.2, 62) },
	{ TableOffset = Vector3.new(47, 3.88, 43), SeatOffset = Vector3.new(47, 3.55, 46.5), WaiterOffset = Vector3.new(43.2, 4.2, 43) },
	{ TableOffset = Vector3.new(69, 3.88, 43), SeatOffset = Vector3.new(69, 3.55, 46.5), WaiterOffset = Vector3.new(65.2, 4.2, 43) },
	{ TableOffset = Vector3.new(47, 3.88, 62), SeatOffset = Vector3.new(47, 3.55, 65.5), WaiterOffset = Vector3.new(43.2, 4.2, 62) },
	{ TableOffset = Vector3.new(69, 3.88, 62), SeatOffset = Vector3.new(69, 3.55, 65.5), WaiterOffset = Vector3.new(65.2, 4.2, 62) },
}

type WalkingCustomer = {
	Name: string,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	BubbleText: TextLabel,
	Phase: "Approaching" | "Ordering" | "SeatedWaiting" | "Eating" | "Leaving",
	TableIndex: number,
	IsSeated: boolean,
	TableMeal: Model?,
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
			if wc.TableMeal and wc.TableMeal.Parent then
				wc.TableMeal:Destroy()
			end
			if wc.Model.Parent then
				wc.Model:Destroy()
			end
		end
		activeWalkingCustomers[player] = nil
	end
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
): (Model, Humanoid, BasePart, TextLabel)
	local rig = MafiaVisualBuilder.BuildCustomerRig("CityCustomer_" .. custName, styleIdx, 1.0, CFrame.new(spawnPos))
	local cust = rig.Model
	local root = rig.Root
	local head = rig.Head

	local bb = Instance.new("BillboardGui")
	bb.Name = "CustomerBubble"
	bb.Size = UDim2.fromOffset(214, 32)
	bb.StudsOffset = Vector3.new(0, 2.35, 0)
	bb.MaxDistance = 135
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Name = "BubbleText"
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 17, 21)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = custName .. "  |  Arriving for dining"
	lbl.TextSize = 11
	lbl.TextColor3 = Color3.fromRGB(232, 228, 218)
	lbl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 5)
	c.Parent = lbl
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(152, 126, 74)
	st.Thickness = 1
	st.Parent = lbl

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 100
	hum.Health = 100
	hum.WalkSpeed = 14 + math.random() * 2.2
	hum.HipHeight = 2.42
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = cust

	CollectionService:AddTag(cust, "AnimatedCustomerLimbs")
	cust.Parent = parent
	return cust, hum, root, lbl
end

local function setCustomerSeated(wc: WalkingCustomer, seated: boolean, seatWorldPos: Vector3?, lookAtWorldPos: Vector3?): ()
	if not wc.Model.Parent or not wc.Root.Parent then
		return
	end
	wc.IsSeated = seated
	local leftLegJoint = wc.Root:FindFirstChild("LeftLegJoint")
	local rightLegJoint = wc.Root:FindFirstChild("RightLegJoint")
	local leftArmJoint = wc.Root:FindFirstChild("LeftArmJoint")
	local rightArmJoint = wc.Root:FindFirstChild("RightArmJoint")

	if seated then
		wc.Humanoid.WalkSpeed = 0
		wc.Humanoid.HipHeight = 1.45
		wc.Root.Anchored = true
		if seatWorldPos and lookAtWorldPos then
			local flatLook = Vector3.new(lookAtWorldPos.X, seatWorldPos.Y, lookAtWorldPos.Z)
			wc.Root.CFrame = CFrame.lookAt(seatWorldPos, flatLook)
		end
		if leftLegJoint and leftLegJoint:IsA("Motor6D") then
			leftLegJoint.C0 = CFrame.new(-0.51, -1.16, -0.15) * CFrame.Angles(math.rad(82), 0, 0)
		end
		if rightLegJoint and rightLegJoint:IsA("Motor6D") then
			rightLegJoint.C0 = CFrame.new(0.51, -1.16, -0.15) * CFrame.Angles(math.rad(82), 0, 0)
		end
		if leftArmJoint and leftArmJoint:IsA("Motor6D") then
			leftArmJoint.C0 = CFrame.new(-1.41, 0.96, 0) * CFrame.Angles(math.rad(38), 0, 0)
		end
		if rightArmJoint and rightArmJoint:IsA("Motor6D") then
			rightArmJoint.C0 = CFrame.new(1.41, 0.96, 0) * CFrame.Angles(math.rad(38), 0, 0)
		end
	else
		wc.Root.Anchored = false
		wc.Humanoid.HipHeight = 2.42
		wc.Humanoid.WalkSpeed = 15
		if leftLegJoint and leftLegJoint:IsA("Motor6D") then
			leftLegJoint.C0 = CFrame.new(-0.51, -1.18, 0)
		end
		if rightLegJoint and rightLegJoint:IsA("Motor6D") then
			rightLegJoint.C0 = CFrame.new(0.51, -1.18, 0)
		end
		if leftArmJoint and leftArmJoint:IsA("Motor6D") then
			leftArmJoint.C0 = CFrame.new(-1.41, 0.96, 0)
		end
		if rightArmJoint and rightArmJoint:IsA("Motor6D") then
			rightArmJoint.C0 = CFrame.new(1.41, 0.96, 0)
		end
	end
end

local function moveNpcTo(model: Model, hum: Humanoid, root: BasePart, dest: Vector3, timeoutSec: number, arriveDist: number?): boolean
	local started = os.clock()
	local stopRadius = arriveDist or 4.2
	while isRunning and model.Parent and hum.Health > 0 do
		if root.Anchored then
			return true
		end
		local delta = Vector3.new(dest.X - root.Position.X, 0, dest.Z - root.Position.Z)
		if delta.Magnitude <= stopRadius then
			return true
		end
		hum:MoveTo(dest)
		if (os.clock() - started) >= timeoutSec then
			return true
		end
		task.wait(0.3)
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
	bb.Size = UDim2.fromOffset(214, 32)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	bb.MaxDistance = 135
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Name = "BubbleText"
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 17, 21)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = roleTitle .. " " .. staffName .. "  |  READY"
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

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 120
	hum.Health = 120
	hum.WalkSpeed = 19
	hum.HipHeight = 2.45
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = npc

	CollectionService:AddTag(npc, "AnimatedCustomerLimbs")
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
		{ Name = "Marco", Title = "WAITER", IsFemale = false, Home = Vector3.new(-6.0, 4.2, 12.0) },
		{ Name = "Sofia", Title = "WAITRESS", IsFemale = true, Home = Vector3.new(6.0, 4.2, 12.0) },
		{ Name = "Luca", Title = "HEAD WAITER", IsFemale = false, Home = Vector3.new(0.0, 4.2, 14.5) },
	}
	local list: { WaiterNPC } = {}
	for i = 1, math.min(hiredCount, #staffDefs) do
		local def = staffDefs[i]
		local worldHome = (hq.PrimaryPart.CFrame * CFrame.new(def.Home)).Position
		local model, hum, root, lbl = buildWaiterModel(baseModel, def.Name, def.Title, def.IsFemale, worldHome)
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
	local used: { [number]: boolean } = {}
	local list = activeWalkingCustomers[player]
	if list then
		for _, wc in ipairs(list) do
			used[wc.TableIndex] = true
		end
	end
	local free: { number } = {}
	for i = 1, #FRONT_DINING_SPOTS do
		if not used[i] then
			table.insert(free, i)
		end
	end
	if #free > 0 then
		return free[math.random(1, #free)]
	end
	return math.random(1, #FRONT_DINING_SPOTS)
end

local function spawnSingleCityCustomer(player: Player, startDistanceZ: number): ()
	local baseModel, bp, hq = getBaseGeometry(player)
	if not baseModel or not bp or not hq or not hq.PrimaryPart then
		return
	end

	local list = activeWalkingCustomers[player]
	if not list then
		list = {}
		activeWalkingCustomers[player] = list
	end
	if #list >= 3 then
		return
	end

	local bCF = bp.CFrame
	local custName = CUSTOMER_NAMES[math.random(1, #CUSTOMER_NAMES)]
	local styleIdx = math.random(1, 6)
	local tableIdx = pickAvailableTableIndex(player)
	local spot = FRONT_DINING_SPOTS[tableIdx] or FRONT_DINING_SPOTS[1]
	local preferBenchWait = (#list % 2 == 1) -- Half sit directly at a dining bench waiting for service; half walk up to front counter!

	-- Spawn out on the Central Market / City Boulevard approaching your Restaurant Plaza!
	local spawnPos = (bCF * CFrame.new(math.random(-10, 10), 4.2, startDistanceZ)).Position
	local gatePos = (bCF * CFrame.new(math.random(-7, 7), 4.2, 112)).Position
	local counterPos = (hq.PrimaryPart.CFrame * CFrame.new(11 + math.random(-3, 4), 4.2, 34.5)).Position
	local seatPos = (bCF * CFrame.new(spot.SeatOffset)).Position
	local tableLookPos = (bCF * CFrame.new(spot.TableOffset)).Position

	local custModel, hum, root, bubble = buildWalkingCustomerModel(baseModel, custName, spawnPos, styleIdx)
	local wc: WalkingCustomer = {
		Name = custName,
		Model = custModel,
		Humanoid = hum,
		Root = root,
		BubbleText = bubble,
		Phase = "Approaching",
		TableIndex = tableIdx,
		IsSeated = false,
		TableMeal = nil,
	}
	table.insert(list, wc)

	-- Walk from Central Market Road -> Front Gate -> either Sit on Dining Bench or Front Counter!
	task.spawn(function()
		moveCustomerTo(wc, gatePos, 16)
		if not wc.Model.Parent or not player.Parent or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end

		local hasWaiter = CrewService.GetWaiterCount(player) > 0
		if preferBenchWait then
			wc.BubbleText.Text = custName .. ": Taking a dining seat."
			moveCustomerTo(wc, seatPos, 15)
			if not wc.Model.Parent or not player.Parent or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			setCustomerSeated(wc, true, seatPos, tableLookPos)
			wc.Phase = "SeatedWaiting"
			local ord = waitingOrders[player]
			if ord then
				ord.CustomerName = wc.Name
				wc.BubbleText.Text = string.format("%s (Seated): 1x %s please!", wc.Name, ord.DishName)
			else
				wc.BubbleText.Text = if hasWaiter then (custName .. ": Seated! Waiting for waiter.") else (custName .. ": Ready! Press [SERVE] or [E]!")
			end
		else
			wc.BubbleText.Text = custName .. ": Stepping into the restaurant."
			moveCustomerTo(wc, counterPos, 14)
			if not wc.Model.Parent or not player.Parent or wc.Phase == "Eating" or wc.Phase == "Leaving" then return end
			wc.Phase = "Ordering"
			local ord = waitingOrders[player]
			if ord then
				ord.CustomerName = wc.Name
				wc.BubbleText.Text = string.format("%s: 1x %s please!", wc.Name, ord.DishName)
			else
				wc.BubbleText.Text = if hasWaiter then (custName .. ": Ready to order!") else (custName .. ": Ready! Press [SERVE] or [E]!")
			end
		end
		RestaurantService.PushStateToClient(player)
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

local function dispatchCustomerToEatAndLeave(player: Player, earnedGold: number, dishHint: string?, dishDisplayName: string?): ()
	local list = activeWalkingCustomers[player]
	if not list or #list == 0 then
		return
	end

	-- Prefer a SeatedWaiting or Ordering customer first, then an Approaching one
	local target: WalkingCustomer? = nil
	for _, wc in ipairs(list) do
		if wc.Phase == "SeatedWaiting" or wc.Phase == "Ordering" then
			target = wc
			break
		end
	end
	if not target then
		for _, wc in ipairs(list) do
			if wc.Phase == "Approaching" then
				target = wc
				break
			end
		end
	end
	if not target then
		return
	end

	local servedCust = target
	local resolvedHint = dishHint or dishDisplayName or "GrilledFish"
	local resolvedLabel = dishDisplayName or resolvedHint
	servedCust.Phase = "Eating"

	local baseModel, bp, hq = getBaseGeometry(player)
	if not baseModel or not bp or not hq or not hq.PrimaryPart then
		return
	end

	local spot = FRONT_DINING_SPOTS[servedCust.TableIndex] or FRONT_DINING_SPOTS[1]
	local bCF = bp.CFrame
	local seatPos = (bCF * CFrame.new(spot.SeatOffset)).Position
	local tablePos = (bCF * CFrame.new(spot.TableOffset)).Position
	local waiterDropPos = (bCF * CFrame.new(spot.WaiterOffset)).Position
	local kitchenPickupPos = (hq.PrimaryPart.CFrame * CFrame.new(-14.0, 4.2, -10.0)).Position

	-- Step 1: Ensure customer walks to their dining table and physically sits down!
	local customerSeatedReady = false
	task.spawn(function()
		if not servedCust.IsSeated and servedCust.Model.Parent then
			servedCust.BubbleText.Text = string.format("%s: Ordered %s! Taking a seat!", servedCust.Name, resolvedLabel)
			moveCustomerTo(servedCust, seatPos, 12)
			if servedCust.Model.Parent then
				setCustomerSeated(servedCust, true, seatPos, tablePos)
			end
		end
		if servedCust.Model.Parent then
			servedCust.BubbleText.Text = string.format("%s: Waiting at table for %s...", servedCust.Name, resolvedLabel)
		end
		customerSeatedReady = true
	end)

	-- Step 2: Dedicated Hired Waiter or Waitress walks INSIDE Kitchen -> picks up distinct 3D plated dish -> serves it right onto the customer's table!
	local waiter = pickWaiterForPlayer(player)
	task.spawn(function()
		if waiter and waiter.Model.Parent then
			waiter.IsBusy = true
			waiter.BubbleText.Text = string.format("PICKING UP %s FROM KITCHEN", string.upper(resolvedLabel))
			moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, kitchenPickupPos, 9, 4.5)

			-- Attach the distinct 3D plated food right onto the Waiter's silver tray!
			if waiter.Model.Parent then
				if waiter.CarriedPlate and waiter.CarriedPlate.Parent then
					waiter.CarriedPlate:Destroy()
				end
				local trayCF = waiter.Root.CFrame * CFrame.new(0, 0.38, -1.68)
				waiter.CarriedPlate = buildDistinctFoodOnPlate(waiter.Model, trayCF, resolvedHint, waiter.Root)
				waiter.BubbleText.Text = string.format("%s  |  SERVING %s", waiter.Name, servedCust.Name)
			end

			-- Walk out to the customer's Front Dining Table!
			moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, waiterDropPos, 12, 4.5)

			-- Wait briefly if customer is still walking to sit down
			local waitStart = os.clock()
			while not customerSeatedReady and (os.clock() - waitStart) < 5 do
				task.wait(0.2)
			end

			-- Set the distinct 3D plated meal directly onto the dining table surface!
			if waiter.CarriedPlate and waiter.CarriedPlate.Parent then
				waiter.CarriedPlate:Destroy()
				waiter.CarriedPlate = nil
			end
			if servedCust.Model.Parent and baseModel.Parent then
				local plateCF = CFrame.new(tablePos) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
				servedCust.TableMeal = buildDistinctFoodOnPlate(baseModel, plateCF, resolvedHint, nil)
				servedCust.BubbleText.Text = string.format("%s: Excellent %s (+%dG)", servedCust.Name, resolvedLabel, earnedGold)
			end

			if waiter.Model.Parent then
				waiter.BubbleText.Text = "SERVED  |  " .. resolvedLabel
				task.delay(0.8, function()
					if waiter.Model.Parent and hq.PrimaryPart then
						local homePos = (hq.PrimaryPart.CFrame * CFrame.new(waiter.HomeOffset)).Position
						moveNpcTo(waiter.Model, waiter.Humanoid, waiter.Root, homePos, 10, 3.8)
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
			-- Served personally by the Owner (before hiring Waiters)
			local waitStart = os.clock()
			while not customerSeatedReady and (os.clock() - waitStart) < 5 do
				task.wait(0.2)
			end
			if servedCust.Model.Parent and baseModel.Parent then
				servedCust.TableMeal = buildDistinctFoodOnPlate(baseModel, CFrame.new(tablePos), resolvedHint, nil)
				servedCust.BubbleText.Text = string.format("%s: Excellent %s (+%dG)", servedCust.Name, resolvedLabel, earnedGold)
			end
		end

		-- Customer sits at the table happily enjoying their distinct food!
		if servedCust.Model.Parent then
			task.wait(7.5)
		end

		-- Stand up from dining bench, clear empty plate, and walk back out to the city!
		if servedCust.TableMeal and servedCust.TableMeal.Parent then
			servedCust.TableMeal:Destroy()
			servedCust.TableMeal = nil
		end
		if servedCust.Model.Parent then
			setCustomerSeated(servedCust, false, nil, nil)
			servedCust.Phase = "Leaving"
			servedCust.BubbleText.Text = servedCust.Name .. ": Amazing meal! Heading back to town!"
			local gatePos = (bCF * CFrame.new(math.random(-6, 6), 4.2, 114)).Position
			local cityExit = (bCF * CFrame.new(math.random(-12, 12), 4.2, 250)).Position
			moveCustomerTo(servedCust, gatePos, 12)
			moveCustomerTo(servedCust, cityExit, 14)
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
		-- Bring in a fresh customer walking in from the Central Market!
		if isRunning and player.Parent then
			spawnSingleCityCustomer(player, 215)
		end
	end)
end

local function spawnCustomersForPlayer(player: Player): ()
	clearCustomers(player)
	spawnWaitStaffForPlayer(player)
	-- Spawn 2 staggered living city customers walking in from the Boulevard right away!
	spawnSingleCityCustomer(player, 132)
	task.delay(3.5, function()
		if isRunning and player.Parent then
			spawnSingleCityCustomer(player, 225)
		end
	end)
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
		local spec = RecipeConfig.Recipes[bestRecipe]
		order = {
			CustomerName = cName,
			DishName = if spec then spec.DisplayName else bestRecipe,
			RecipeId = bestRecipe,
			BaseGold = math.floor((if spec then spec.CoinsReward else 40) * vipMult),
			BaseRep = math.floor((if spec then spec.ReputationReward else 10) * vipMult),
			IsBeingCooked = false,
		}
	else
		local special = HOUSE_SPECIALS[math.random(1, #HOUSE_SPECIALS)]
		order = {
			CustomerName = cName,
			DishName = special.Name,
			RecipeId = nil,
			BaseGold = math.floor(special.Gold * vipMult),
			BaseRep = math.floor(special.Rep * vipMult),
			IsBeingCooked = false,
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
	if not hq or not hq:IsA("Model") or not hq.PrimaryPart then
		return
	end

	local level = PlayerDataService.GetProfile(player).RestaurantLevel
	local oldUpgrades = hq:FindFirstChild("HQUpgradeVisuals")
	if oldUpgrades then
		oldUpgrades:Destroy()
	end
	if level < 2 then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "HQUpgradeVisuals"
	local baseCF = hq.PrimaryPart.CFrame
	local gold = Color3.fromRGB(248, 196, 56)
	local neonGold = Color3.fromRGB(255, 224, 96)
	local warmGlow = Color3.fromRGB(255, 232, 138)
	local crimson = Color3.fromRGB(192, 36, 48)
	local diamond = Color3.fromRGB(112, 234, 255)
	local marble = Color3.fromRGB(246, 244, 238)
	local water = Color3.fromRGB(82, 206, 242)

	local function uPart(name: string, sz: Vector3, rel: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?, transp: number?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = baseCF * rel
		p.Color = col
		p.Material = mat
		if shape then p.Shape = shape end
		if transp then p.Transparency = transp end
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Parent = folder
		return p
	end

	-- Lv.2+: Glowing Golden Patio Pillar Lanterns
	for _, px in ipairs({ -39, 39 }) do
		uPart("Lv2_PatioPillar", Vector3.new(2.0, 12.5, 2.0), CFrame.new(px, 6.8, 30), gold, Enum.Material.Metal, nil, nil)
		local orb = uPart("Lv2_PatioOrb", Vector3.new(3.0, 3.0, 3.0), CFrame.new(px, 14.2, 30), warmGlow, Enum.Material.Neon, Enum.PartType.Ball, nil)
		local pl = Instance.new("PointLight")
		pl.Color = warmGlow
		pl.Brightness = 1.4
		pl.Range = 28
		pl.Shadows = false
		pl.Parent = orb
	end

	-- Lv.3+: Glowing Rooftop Bistro Starlight Crest & Gold Fascia Trim
	if level >= 3 then
		uPart("Lv3_RoofGoldBand", Vector3.new(84.5, 1.0, 57.5), CFrame.new(0, 31.4, -6.5), gold, Enum.Material.Metal, nil, nil)
		uPart("Lv3_MarqueeHalo", Vector3.new(34.8, 0.8, 1.2), CFrame.new(0, 37.9, 19.8), neonGold, Enum.Material.Neon, nil, nil)
	end

	-- Lv.4+: VIP Red Carpet Entrance + Velvet Gold Stanchion Posts
	if level >= 4 then
		uPart("Lv4_RedCarpet", Vector3.new(11.0, 0.14, 19.0), CFrame.new(0, 0.65, 28.5), crimson, Enum.Material.Fabric, nil, nil)
		uPart("Lv4_CarpetTrimL", Vector3.new(0.45, 0.16, 19.0), CFrame.new(-5.5, 0.66, 28.5), gold, Enum.Material.Metal, nil, nil)
		uPart("Lv4_CarpetTrimR", Vector3.new(0.45, 0.16, 19.0), CFrame.new(5.5, 0.66, 28.5), gold, Enum.Material.Metal, nil, nil)
		for _, sx in ipairs({ -6.8, 6.8 }) do
			for _, sz in ipairs({ 24.5, 32.5 }) do
				uPart("Lv4_Stanchion", Vector3.new(0.45, 3.6, 0.45), CFrame.new(sx, 2.3, sz), gold, Enum.Material.Metal, nil, nil)
				uPart("Lv4_StanchionOrb", Vector3.new(0.8, 0.8, 0.8), CFrame.new(sx, 4.3, sz), neonGold, Enum.Material.Neon, Enum.PartType.Ball, nil)
			end
		end
	end

	-- Lv.5+: Illuminated Neon Marquee Border + Twin Golden Topiary Entry Pillars
	if level >= 5 then
		uPart("Lv5_MarqueeGlowL", Vector3.new(0.8, 8.6, 1.0), CFrame.new(-17.4, 33.0, 19.9), neonGold, Enum.Material.Neon, nil, nil)
		uPart("Lv5_MarqueeGlowR", Vector3.new(0.8, 8.6, 1.0), CFrame.new(17.4, 33.0, 19.9), neonGold, Enum.Material.Neon, nil, nil)
		for _, tx in ipairs({ -14.0, 14.0 }) do
			uPart("Lv5_TopiaryPot", Vector3.new(3.2, 3.0, 3.2), CFrame.new(tx, 2.0, 35.5), marble, Enum.Material.Marble, nil, nil)
			uPart("Lv5_TopiaryBall", Vector3.new(4.2, 4.2, 4.2), CFrame.new(tx, 5.4, 35.5), Color3.fromRGB(54, 152, 68), Enum.Material.Grass, Enum.PartType.Ball, nil)
		end
	end

	-- Lv.6+: Grand Rooftop Sky-Terrace Deck with Golden Balustrade Railings
	if level >= 6 then
		uPart("Lv6_SkyDeck", Vector3.new(54.0, 1.4, 24.0), CFrame.new(0, 42.2, -6.5), marble, Enum.Material.Marble, nil, nil)
		uPart("Lv6_RailFront", Vector3.new(54.5, 0.8, 0.8), CFrame.new(0, 45.2, 5.3), gold, Enum.Material.Metal, nil, nil)
		for rx = -24, 24, 8 do
			uPart("Lv6_RailPost", Vector3.new(0.6, 3.2, 0.6), CFrame.new(rx, 44.0, 5.3), gold, Enum.Material.Metal, nil, nil)
		end
	end

	-- Lv.7+: Twin Ornamental Marble Dining Fountains flanking the Patio!
	if level >= 7 then
		for _, fx in ipairs({ -46.0, 46.0 }) do
			uPart("Lv7_FountainBasin", Vector3.new(2.2, 10.0, 10.0), CFrame.new(fx, 1.6, 22.0) * CFrame.Angles(0, 0, math.rad(90)), marble, Enum.Material.Marble, Enum.PartType.Cylinder, nil)
			uPart("Lv7_FountainWater", Vector3.new(0.8, 8.6, 8.6), CFrame.new(fx, 2.4, 22.0) * CFrame.Angles(0, 0, math.rad(90)), water, Enum.Material.Neon, Enum.PartType.Cylinder, 0.25)
			uPart("Lv7_FountainSpire", Vector3.new(4.8, 1.6, 1.6), CFrame.new(fx, 4.8, 22.0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder, nil)
			uPart("Lv7_FountainJet", Vector3.new(2.2, 2.2, 2.2), CFrame.new(fx, 7.6, 22.0), water, Enum.Material.Neon, Enum.PartType.Ball, 0.15)
		end
	end

	-- Lv.8+: Illuminated Grand Golden Facade Columns & Starlight Uplights
	if level >= 8 then
		for _, cx in ipairs({ -38.5, -18.0, 18.0, 38.5 }) do
			uPart("Lv8_GoldColumn", Vector3.new(1.8, 29.0, 1.8), CFrame.new(cx, 15.0, 19.2), gold, Enum.Material.Metal, nil, nil)
			uPart("Lv8_UpLight", Vector3.new(1.2, 1.2, 1.2), CFrame.new(cx, 29.6, 19.5), neonGold, Enum.Material.Neon, Enum.PartType.Ball, nil)
		end
	end

	-- Lv.9+: Imperial Glass Rooftop Pavilion & Warm Chandelier Lounge
	if level >= 9 then
		for _, gx in ipairs({ -16.0, 16.0 }) do
			for _, gz in ipairs({ -14.0, 1.0 }) do
				uPart("Lv9_PavCol", Vector3.new(1.6, 11.0, 1.6), CFrame.new(gx, 48.2, gz), gold, Enum.Material.Metal, nil, nil)
			end
		end
		uPart("Lv9_PavRoof", Vector3.new(38.0, 1.6, 20.0), CFrame.new(0, 54.2, -6.5), gold, Enum.Material.Metal, nil, nil)
		local chand = uPart("Lv9_Chandelier", Vector3.new(5.2, 3.2, 5.2), CFrame.new(0, 51.0, -6.5), warmGlow, Enum.Material.Neon, Enum.PartType.Ball, nil)
		local pl9 = Instance.new("PointLight")
		pl9.Color = warmGlow
		pl9.Brightness = 2.0
		pl9.Range = 45
		pl9.Shadows = false
		pl9.Parent = chand
	end

	-- Lv.10 (MAX — FOOD EMPEROR PALACE): Radiant Diamond-Gold Emperor Crown & Sky Halo!
	if level >= 10 then
		local crown = uPart("Lv10_EmperorCrown", Vector3.new(4.2, 18.0, 18.0), CFrame.new(0, 58.2, -6.5) * CFrame.Angles(0, 0, math.rad(90)), neonGold, Enum.Material.Neon, Enum.PartType.Cylinder, nil)
		uPart("Lv10_DiamondGem", Vector3.new(5.4, 7.6, 5.4), CFrame.new(0, 64.0, -6.5) * CFrame.Angles(0, math.rad(45), 0), diamond, Enum.Material.Neon, nil, nil)
		uPart("Lv10_SkyBeam", Vector3.new(65, 3.2, 3.2), CFrame.new(0, 92.0, -6.5) * CFrame.Angles(0, 0, math.rad(90)), diamond, Enum.Material.Neon, Enum.PartType.Cylinder, 0.68)
		local pl10 = Instance.new("PointLight")
		pl10.Color = diamond
		pl10.Brightness = 2.5
		pl10.Range = 55
		pl10.Shadows = false
		pl10.Parent = crown
	end

	folder.Parent = hq
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

	return {
		BaseSlot = BaseService.GetPlayerBaseSlot(player),
		Profile = profile,
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

function RestaurantService.PickBestAvailableRecipe(player: Player): string?
	local restLevel = PlayerDataService.GetProfile(player).RestaurantLevel
	for _, recipeId in ipairs(RecipeConfig.Order) do
		local recipe = RecipeConfig.Recipes[recipeId]
		if recipe and restLevel >= recipe.RequiredRestaurantLevel then
			if WarehouseService.HasIngredients(player, recipe.Ingredients) then
				return recipeId
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

function RestaurantService.TryBuyDualStove(player: Player): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Restaurant Plaza Base first!"
	end
	local prof = PlayerDataService.GetProfile(player)
	if prof.HasDualStove then
		return true, "Dual-Stove Commercial Range is already installed!"
	end
	if not PlayerDataService.SpendCoins(player, 650) then
		return false, "Need 650 Gold to install the 2nd Commercial Stove Line!"
	end
	PlayerDataService.SetHasDualStove(player, true)
	SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1)
	RestaurantService.PushStateToClient(player)
	return true, "Installed 2nd Commercial Stove Line! Cook 2 dishes simultaneously!"
end

function RestaurantService.TryBuyVIPBooths(player: Player): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Restaurant Plaza Base first!"
	end
	local prof = PlayerDataService.GetProfile(player)
	if prof.HasVIPBooths then
		return true, "VIP Private Dining Booths are already installed!"
	end
	if not PlayerDataService.SpendCoins(player, 850) then
		return false, "Need 850 Gold to install VIP Private Dining Booths!"
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
			local cravingMult = if recipeId == cityCravingRecipeId then 2.0 else 1.0
			local dishHotMult = if recipe.IsHotComfort then weatherHotMult else 1.0
			local baseCoin = recipe.CoinsReward * tier.PayoutMultiplier * eventCoinsMult * passCoinsMult * waiterTipMult * starMult * rankMult * priceCoinMult * cravingMult * dishHotMult
			totalCoins += math.floor(baseCoin) * normalCount + math.floor(baseCoin * 1.50) * mwCount
			totalExp += recipe.ExpReward * qty
			local baseRep = recipe.ReputationReward * eventRepMult * passRepMult * starMult * priceRepMult
			totalRep += math.floor(baseRep) * normalCount + math.floor(baseRep * 1.50) * mwCount
		end
	end

	table.clear(kitchen.ReadyDishes)
	clearPlatters(player)
	PlayerDataService.AddRewards(player, totalCoins, totalExp, totalRep)
	SyndicateContractService.RecordProgress(player, "CookDishes", totalDishes)
	local vipCompleted, vipMsg = VIPOrderService.TryFulfillFromServed(player, servedCopy)
	local custName = if waitingOrders[player] then waitingOrders[player].CustomerName else CUSTOMER_NAMES[math.random(1, #CUSTOMER_NAMES)]
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
	dispatchCustomerToEatAndLeave(player, totalCoins, firstRecipeId or dishNames[1], dishNames[1] or "House Feast")
	task.delay(3.5, function()
		if player.Parent and countReadyDishes(ensureKitchen(player)) == 0 then
			spawnRandomCustomerOrder(player)
			RestaurantService.PushStateToClient(player)
		end
	end)
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

	local order = waitingOrders[player] or spawnRandomCustomerOrder(player)
	if order.IsBeingCooked then
		return false, "Chef is already cooking for " .. order.CustomerName .. "!"
	end

	order.IsBeingCooked = true
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
		updateCustomerSpeech(player, string.format("%s fetched %s from Warehouse -> %s!", chefName, cat, order.DishName))
		if MonetizationService.HasPass(player, "MasterProChef") then
			MonetizationService.SetProChefStatus(player, string.format("📦 Fetched %s -> Cooking %s!", cat, order.DishName), true)
		end
	else
		updateCustomerSpeech(player, string.format("%s cooking %s for %s...", chefName, order.DishName, order.CustomerName))
		if MonetizationService.HasPass(player, "MasterProChef") then
			MonetizationService.SetProChefStatus(player, "🔥 Cooking " .. order.DishName .. " for " .. order.CustomerName .. "!", true)
		end
	end
	RestaurantService.PushStateToClient(player)

	local profile = PlayerDataService.GetProfile(player)
	local tier = RecipeConfig.RestaurantTiers[profile.RestaurantLevel] or RecipeConfig.RestaurantTiers[1]
	local speedMult = tier.CookSpeedMultiplier * CrewService.GetCookSpeedMultiplier(player) * MonetizationService.GetCookSpeedMultiplier(player)
	local baseCookSec = 5.5
	if order.RecipeId and RecipeConfig.Recipes[order.RecipeId] then
		baseCookSec = RecipeConfig.Recipes[order.RecipeId].CookTime
	end
	local cookTime = math.max(1.8, baseCookSec / speedMult)
	local kitchen = ensureKitchen(player)
	kitchen.IsCooking = true
	kitchen.CurrentRecipeId = order.RecipeId or order.DishName
	kitchen.CookEndsAt = os.clock() + cookTime
	RestaurantService.PushStateToClient(player)

	task.delay(cookTime, function()
		if not player.Parent then
			return
		end
		kitchen.IsCooking = false
		kitchen.CurrentRecipeId = nil
		kitchen.CookEndsAt = 0
		setGrillCookingVisual(player, false, nil)

		local eventCoinsMultAttr = ReplicatedStorage:GetAttribute("ActiveEventCoinsMult")
		local eventRepMultAttr = ReplicatedStorage:GetAttribute("ActiveEventRepMult")
		local eventCoinsMult = (if typeof(eventCoinsMultAttr) == "number" then eventCoinsMultAttr else 1.0) * (if ReplicatedStorage:GetAttribute("IsNight") == true then 1.35 else 1.0)
		local eventRepMult = if typeof(eventRepMultAttr) == "number" then eventRepMultAttr else 1.0
		local passCoinsMult = MonetizationService.GetPayoutMultiplier(player)
		local passRepMult = MonetizationService.GetRepMultiplier(player)
		local waiterTipMult = CrewService.GetWaiterTipMultiplier(player)
		local starMult = RestaurantService.GetRestaurantStarInfo(player).Multiplier or 1.0
		local rankMult = SyndicateContractService.GetRankPayoutMultiplier(player)

		local earnedGold = math.max(12, math.floor(order.BaseGold * tier.PayoutMultiplier * eventCoinsMult * passCoinsMult * waiterTipMult * starMult * rankMult))
		local earnedRep = math.max(4, math.floor(order.BaseRep * eventRepMult * passRepMult * starMult))
		local earnedExp = math.max(10, math.floor(order.BaseGold * 0.4))

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
		dispatchCustomerToEatAndLeave(player, earnedGold, usedRecipeId or order.DishName, order.DishName)
		if MonetizationService.HasPass(player, "MasterProChef") then
			MonetizationService.SetProChefStatus(player, string.format("🧾 Receipt #%d (+%d Gold)!", receipt.OrderNo, earnedGold), true)
		end

		waitingOrders[player] = nil
		RestaurantService.PushStateToClient(player)

		task.delay(3.0, function()
			if player.Parent and not waitingOrders[player] then
				spawnRandomCustomerOrder(player)
				RestaurantService.PushStateToClient(player)
			end
		end)
	end)

	return true, string.format("%s is cooking %s for %s!", chefName, order.DishName, order.CustomerName)
end

function RestaurantService.TryUpgradeRestaurant(player: Player): (boolean, string)
	local profile = PlayerDataService.GetProfile(player)
	local nextTier = RecipeConfig.RestaurantTiers[profile.RestaurantLevel + 1]
	if not nextTier then
		return false, "Restaurant HQ is at Max Level!"
	end

	if not PlayerDataService.SpendCoins(player, nextTier.UpgradeCost) then
		return false, string.format("Need %d Coins to upgrade Restaurant HQ", nextTier.UpgradeCost)
	end

	PlayerDataService.SetRestaurantLevel(player, nextTier.Level)
	syncRestaurantVisuals(player)
	RestaurantService.PushStateToClient(player)
	return true, string.format("Upgraded Restaurant HQ to Lv.%d!", nextTier.Level)
end

function RestaurantService.TryUpgradeDefenses(player: Player): (boolean, string)
	local profile = PlayerDataService.GetProfile(player)
	local nextLevel = profile.DefenseLevel + 1
	local cost = DEFENSE_UPGRADE_COSTS[nextLevel]
	if not cost then
		return false, "Castle Defenses are at Max Tier!"
	end

	if not PlayerDataService.SpendCoins(player, cost) then
		return false, string.format("Need %d Coins to upgrade Defenses", cost)
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
					RestaurantService.TryUpgradeRestaurant(player)
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
				ok, msg = BodyguardService.TryRecruitClass(player, arg.ClassId, slotIdx)
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
			elseif action == "HireMercenaryMafia" and typeof(arg) == "string" then
				ok, msg = MercenaryMafiaService.TryHireWithGold(player, arg)
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

	setupRemotes()
	wireRestaurantPrompts()

	-- True supply-chain separation:
	-- 1) Hired Chefs ONLY fetch ingredients from Warehouse & cook plated food onto Kitchen Counter!
	CrewService.SetAutoCookOnlyHandler(function(player)
		local kitchen = ensureKitchen(player)
		local hasDual = PlayerDataService.GetProfile(player).HasDualStove == true
		local canCookNow = (not kitchen.IsCooking) or (hasDual and not kitchen.IsCooking2)
		if canCookNow and countReadyDishes(kitchen) < 6 then
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
		spawnRandomCustomerOrder(player)
		for _, p in ipairs(Players:GetPlayers()) do
			RestaurantService.PushStateToClient(p)
		end
	end)

	for _, p in ipairs(Players:GetPlayers()) do
		if BaseService.GetPlayerBaseSlot(p) then
			spawnCustomersForPlayer(p)
			syncRestaurantVisuals(p)
			spawnRandomCustomerOrder(p)
		end
	end

	-- Live Walk-In Random Customer Orders loop (Chefs auto-cook & ring up receipts for waiting customers!)
	customerOrderThread = task.spawn(function()
		while isRunning do
			task.wait(10)
			if not isRunning then
				break
			end
			for _, p in ipairs(Players:GetPlayers()) do
				if BaseService.GetPlayerBaseSlot(p) then
					local ord = waitingOrders[p]
					if not ord then
						ord = spawnRandomCustomerOrder(p)
						RestaurantService.PushStateToClient(p)
					end
					-- Ensure living city customers continuously walk in from the boulevard!
					local wList = activeWalkingCustomers[p]
					if not wList or #wList < 2 then
						spawnSingleCityCustomer(p, 215)
					end
					if ord and not ord.IsBeingCooked then
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

	print("[Food Empire] RestaurantService started (Cooking, Serving, Customers, HQ Upgrades & Remotes ready)!")
end

function RestaurantService.Stop(): ()
	isRunning = false
	if customerOrderThread then
		task.cancel(customerOrderThread)
		customerOrderThread = nil
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
