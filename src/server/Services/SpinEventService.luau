--!strict

-- SpinEventService:
--  * Builds a physical rotating 3D "CENTRAL MARKET LUCKY SPIN" wheel monument in Central Market Plaza.
--  * Runs periodic Central Market Lucky Spin Events (granting 1 Free Event Spin + discounted 200G spins).
--  * 100% Server-Authoritative weighted RNG awarding Fish, Meat, Vegetables, Fruit, Gold, Kevlar/Ammo,
--    random Gold-tier Black Market Firearms, and random Gold-tier Bodyguards (strictly excludes Robux items!).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local WeaponConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WeaponConfig")
)
local BodyguardConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("BodyguardConfig")
)
local PlayerDataService = require("./PlayerDataService")
local WarehouseService = require("./WarehouseService")
local BlackMarketService = require("./BlackMarketService")
local BodyguardService = require("./BodyguardService")

export type SpinPrizeSpec = {
	Index: number,
	Id: string,
	Title: string,
	ShortLabel: string,
	Category: "Fish" | "Meat" | "Vegetable" | "Fruit" | "Gold" | "Armor" | "Gun" | "Bodyguard",
	Rarity: "Common" | "Rare" | "Epic" | "Legendary",
	Weight: number,
	AccentColor: Color3,
	PreviewKind: "Weapon" | "Ammo" | "Bodyguard" | "Equipment" | "Premium",
	PreviewId: string,
}

local SpinEventService = {}

SpinEventService.NORMAL_SPIN_COST = 350
SpinEventService.EVENT_SPIN_COST = 200
SpinEventService.FREE_SPIN_COOLDOWN = 180 -- 1 free spin every 3 minutes
local EVENT_CYCLE_IDLE = 115
local EVENT_CYCLE_ACTIVE = 65
local WHEEL_POS = Vector3.new(0, 1.35, 48)

SpinEventService.PRIZES = {
	{
		Index = 1, Id = "FishCrate", Title = "Fresh Fish Crate (+12)", ShortLabel = "FISH x12",
		Category = "Fish", Rarity = "Common", Weight = 17, AccentColor = Color3.fromRGB(58, 128, 168),
		PreviewKind = "Equipment", PreviewId = "InstantEmpireCrate",
	},
	{
		Index = 2, Id = "MeatCrate", Title = "Prime Meat Crate (+12)", ShortLabel = "MEAT x12",
		Category = "Meat", Rarity = "Common", Weight = 16, AccentColor = Color3.fromRGB(152, 58, 52),
		PreviewKind = "Equipment", PreviewId = "SyndicateArmorBundle",
	},
	{
		Index = 3, Id = "VegCrate", Title = "Farm Vegetable Crate (+12)", ShortLabel = "VEG x12",
		Category = "Vegetable", Rarity = "Common", Weight = 17, AccentColor = Color3.fromRGB(64, 134, 78),
		PreviewKind = "Equipment", PreviewId = "TacticalAmmoCrate",
	},
	{
		Index = 4, Id = "FruitCrate", Title = "Exotic Fruit Crate (+12)", ShortLabel = "FRUIT x12",
		Category = "Fruit", Rarity = "Common", Weight = 16, AccentColor = Color3.fromRGB(172, 118, 52),
		PreviewKind = "Equipment", PreviewId = "InstantEmpireCrate",
	},
	{
		Index = 5, Id = "GoldJackpot", Title = "Syndicate Gold Vault (+550G)", ShortLabel = "+550 GOLD",
		Category = "Gold", Rarity = "Rare", Weight = 12, AccentColor = Color3.fromRGB(186, 152, 74),
		PreviewKind = "Equipment", PreviewId = "InstantEmpireCrate",
	},
	{
		Index = 6, Id = "ArmorAmmo", Title = "Kevlar Vest + Ammo Pack", ShortLabel = "ARMOR + AMMO",
		Category = "Armor", Rarity = "Rare", Weight = 10, AccentColor = Color3.fromRGB(68, 108, 148),
		PreviewKind = "Equipment", PreviewId = "KevlarVest",
	},
	{
		Index = 7, Id = "RandomGun", Title = "Black Market Firearm", ShortLabel = "RARE GUN",
		Category = "Gun", Rarity = "Epic", Weight = 6, AccentColor = Color3.fromRGB(142, 34, 42),
		PreviewKind = "Weapon", PreviewId = "SyndicateCarbine",
	},
	{
		Index = 8, Id = "RandomBodyguard", Title = "Bodyguard Contract", ShortLabel = "BODYGUARD",
		Category = "Bodyguard", Rarity = "Legendary", Weight = 6, AccentColor = Color3.fromRGB(168, 138, 76),
		PreviewKind = "Bodyguard", PreviewId = "EliteGuard",
	},
} :: { SpinPrizeSpec }

local TOTAL_WEIGHT = 0
for _, p in ipairs(SpinEventService.PRIZES) do
	TOTAL_WEIGHT += p.Weight
end

local GOLD_POOL_GUNS = { "StreetPistol", "PepperShotgun", "TacticalSMG", "SilencedDeagle", "AutoCombatShotgun", "SyndicateCarbine", "ShadowSniper" }
local GOLD_POOL_GUARDS = { "BasicGuard", "HeavyGuard", "AssaultGuard", "SniperGuard", "TacticalGuard", "EliteGuard" }

local isRunning = false
local eventActive = false
local eventEndsAt = 0
local eventIdCounter = 0
local claimedEventSpin: { [Player]: number } = {}
local spinLock: { [Player]: number } = {}
local openWheelEv: RemoteEvent? = nil
local wheelModel: Model? = nil
local boardStatusLbl: TextLabel? = nil
local promptConn: RBXScriptConnection? = nil
local eventThread: thread? = nil

local function broadcastToast(msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireAllClients(msg)
	end
end

local function build3DSpinWheelMonument(): ()
	local map = Workspace:FindFirstChild("FoodEmpireMap")
	local central = if map then map:FindFirstChild("CentralDistrict") else nil
	local plaza = if central then central:FindFirstChild("CentralPlaza") else nil
	local parentFolder = plaza or Workspace

	local old = parentFolder:FindFirstChild("CentralMarketSpinWheel")
	if old then old:Destroy() end

	local m = Instance.new("Model")
	m.Name = "CentralMarketSpinWheel"
	local baseCF = CFrame.new(WHEEL_POS) * CFrame.Angles(0, math.pi, 0) -- Faces North toward Fountain

	local function wPart(name: string, sz: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?, collide: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = baseCF * relCF
		p.Color = col
		p.Material = mat
		if shape then p.Shape = shape end
		p.Anchored = true
		p.CanCollide = if collide == nil then true else collide
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end

	local obsidian = Color3.fromRGB(18, 20, 25)
	local charcoal = Color3.fromRGB(34, 38, 46)
	local brass = Color3.fromRGB(172, 142, 76)
	local oxblood = Color3.fromRGB(134, 28, 36)

	-- Octagonal Stage & Brass Trim
	local stage = wPart("SpinStage", Vector3.new(1.2, 13.5, 13.5), CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), obsidian, Enum.Material.Slate, Enum.PartType.Cylinder, true)
	wPart("StageRim", Vector3.new(0.45, 14.0, 14.0), CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.rad(90)), brass, Enum.Material.Metal, Enum.PartType.Cylinder, false)

	-- Twin Heavy Steel Uprights & Crossbeam
	wPart("PillarL", Vector3.new(1.1, 13.2, 1.1), CFrame.new(-5.8, 7.6, 0), charcoal, Enum.Material.Metal, nil, true)
	wPart("PillarR", Vector3.new(1.1, 13.2, 1.1), CFrame.new(5.8, 7.6, 0), charcoal, Enum.Material.Metal, nil, true)
	wPart("ArchTop", Vector3.new(13.2, 1.2, 1.4), CFrame.new(0, 14.4, 0), obsidian, Enum.Material.Metal, nil, false)
	-- Pointer Arrow at Top Center pointing down at the winning wedge
	wPart("PointerNeedle", Vector3.new(1.1, 1.8, 0.8), CFrame.new(0, 13.1, -0.8) * CFrame.Angles(0, 0, math.rad(45)), oxblood, Enum.Material.Metal, nil, false)

	-- Rotating 3D Prize Wheel Disc (tagged SpinningMarketWheel -> rotates at 60 FPS on Client!)
	local disc = wPart("PrizeWheelDisc", Vector3.new(0.75, 9.8, 9.8), CFrame.new(0, 8.2, 0) * CFrame.Angles(0, math.rad(90), 0), obsidian, Enum.Material.Metal, Enum.PartType.Cylinder, false)
	CollectionService:AddTag(disc, "SpinningMarketWheel")

	-- Visual Brass Center Hub + Outer Bezel Ring
	wPart("WheelHub", Vector3.new(1.1, 2.4, 2.4), CFrame.new(0, 8.2, 0) * CFrame.Angles(0, math.rad(90), 0), brass, Enum.Material.Metal, Enum.PartType.Cylinder, false)

	-- SurfaceGui with 8 crisp radial pie labels on the spinning wheel face
	for _, face in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
		local wGui = Instance.new("SurfaceGui")
		wGui.Face = face
		wGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		wGui.PixelsPerStud = 30
		wGui.Parent = disc
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
		bg.Parent = wGui
		Instance.new("UICorner", bg).CornerRadius = UDim.new(0.5, 0)
		local st = Instance.new("UIStroke")
		st.Color = brass
		st.Thickness = 6
		st.Parent = bg

		for i, prize in ipairs(SpinEventService.PRIZES) do
			local ang = ((i - 1) / #SpinEventService.PRIZES) * math.pi * 2
			local r = 0.34
			local pill = Instance.new("TextLabel")
			pill.AnchorPoint = Vector2.new(0.5, 0.5)
			pill.Position = UDim2.fromScale(0.5 + math.cos(ang) * r, 0.5 + math.sin(ang) * r)
			pill.Size = UDim2.fromScale(0.28, 0.11)
			pill.BackgroundColor3 = prize.AccentColor
			pill.Font = Enum.Font.GothamBlack
			pill.Text = prize.ShortLabel
			pill.TextScaled = true
			pill.TextColor3 = Color3.fromRGB(244, 240, 232)
			pill.Parent = bg
			Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 6)
		end
	end

	-- Top Marquee Signboard
	local sign = wPart("SpinSignBoard", Vector3.new(13.8, 2.8, 0.6), CFrame.new(0, 16.4, 0), obsidian, Enum.Material.Metal, nil, false)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sgui = Instance.new("SurfaceGui")
		sgui.Face = face
		sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sgui.PixelsPerStud = 30
		sgui.Parent = sign
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
		f.BorderSizePixel = 0
		f.Parent = sgui

		local t1 = Instance.new("TextLabel")
		t1.Position = UDim2.new(0.02, 0, 0.06, 0)
		t1.Size = UDim2.new(0.96, 0, 0.46, 0)
		t1.BackgroundTransparency = 1
		t1.Font = Enum.Font.GothamBlack
		t1.TextScaled = true
		t1.Text = "CENTRAL MARKET LUCKY SPIN"
		t1.TextColor3 = Color3.fromRGB(236, 232, 224)
		t1.Parent = f

		local t2 = Instance.new("TextLabel")
		t2.Position = UDim2.new(0.02, 0, 0.54, 0)
		t2.Size = UDim2.new(0.96, 0, 0.38, 0)
		t2.BackgroundTransparency = 1
		t2.Font = Enum.Font.GothamBold
		t2.TextScaled = true
		t2.Text = "WIN GUNS, BODYGUARDS & FRESH CRATES  [E]"
		t2.TextColor3 = Color3.fromRGB(214, 184, 118)
		t2.Parent = f
		if face == Enum.NormalId.Front then
			boardStatusLbl = t2
		end
	end

	-- Subtle Warm Overhead Spot Light
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(255, 222, 168)
	pl.Brightness = 1.6
	pl.Range = 26
	pl.Shadows = false
	pl.Parent = sign

	-- Front Pedestal Console with [E] ProximityPrompt
	local console = wPart("SpinConsole", Vector3.new(2.8, 3.2, 1.8), CFrame.new(0, 2.2, -5.2), charcoal, Enum.Material.Metal, nil, true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenSpinWheelPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.ActionText = "Open Lucky Spin Wheel"
	prompt.ObjectText = "Central Market Spin"
	prompt.Parent = console

	promptConn = prompt.Triggered:Connect(function(player: Player)
		if openWheelEv then
			openWheelEv:FireClient(player, SpinEventService.GetSnapshot(player))
		end
	end)

	m.PrimaryPart = stage
	m.Parent = parentFolder
	wheelModel = m
end

local function rollWeightedPrize(): SpinPrizeSpec
	local roll = math.random() * TOTAL_WEIGHT
	local acc = 0
	for _, spec in ipairs(SpinEventService.PRIZES) do
		acc += spec.Weight
		if roll <= acc then
			return spec
		end
	end
	return SpinEventService.PRIZES[1]
end

local function grantCategoryCrate(player: Player, category: WarehouseConfig.WarehouseCategory, qty: number): string
	local spec = WarehouseConfig.Specs[category]
	local added = 0
	if WarehouseService.IsUnlocked(player, category) then
		for i = 1, qty do
			local ing = spec.Ingredients[((i - 1) % #spec.Ingredients) + 1]
			if ing ~= "golden_tuna" and ing ~= "king_crab" then
				if WarehouseService.AddIngredient(player, ing, 1) > 0 then
					added += 1
				end
			end
		end
	end
	if added > 0 then
		return string.format("+%d %s stored in Warehouse!", added, category)
	end
	-- If Warehouse category is still locked or completely full, pay equivalent market Gold value so spin is NEVER wasted!
	PlayerDataService.AddCoins(player, 280)
	return string.format("%s Warehouse full/locked — converted to +280 Gold!", category)
end

local function hasFreeSpinAvailable(player: Player): (boolean, boolean, number)
	local nowUnix = os.time()
	if eventActive and claimedEventSpin[player] ~= eventIdCounter then
		return true, true, 0
	end
	local prof = PlayerDataService.GetProfile(player)
	local elapsed = nowUnix - (prof.LastFreeSpinAt or 0)
	local rem = math.max(0, SpinEventService.FREE_SPIN_COOLDOWN - elapsed)
	return rem <= 0, false, rem
end

function SpinEventService.GetSnapshot(player: Player): { [string]: any }
	local canFree, isEventFree, freeRem = hasFreeSpinAvailable(player)
	local cost = if canFree then 0 elseif eventActive then SpinEventService.EVENT_SPIN_COST else SpinEventService.NORMAL_SPIN_COST
	local prizesOut = {}
	for _, p in ipairs(SpinEventService.PRIZES) do
		table.insert(prizesOut, {
			Index = p.Index,
			Id = p.Id,
			Title = p.Title,
			ShortLabel = p.ShortLabel,
			Category = p.Category,
			Rarity = p.Rarity,
			ColorR = math.floor(p.AccentColor.R * 255),
			ColorG = math.floor(p.AccentColor.G * 255),
			ColorB = math.floor(p.AccentColor.B * 255),
			PreviewKind = p.PreviewKind,
			PreviewId = p.PreviewId,
		})
	end
	return {
		EventActive = eventActive,
		EventTimeLeft = if eventActive then math.max(0, math.ceil(eventEndsAt - os.clock())) else 0,
		CanFreeSpin = canFree,
		IsEventFreeSpin = isEventFree,
		NextFreeIn = freeRem,
		SpinCost = cost,
		Prizes = prizesOut,
	}
end

function SpinEventService.TrySpin(player: Player): (boolean, string, { [string]: any }?)
	local now = os.clock()
	if (spinLock[player] or 0) > now then
		return false, "Wheel is already spinning!", nil
	end
	spinLock[player] = now + 3.4

	local canFree, isEventFree = hasFreeSpinAvailable(player)
	local cost = if canFree then 0 elseif eventActive then SpinEventService.EVENT_SPIN_COST else SpinEventService.NORMAL_SPIN_COST

	if cost > 0 then
		if not PlayerDataService.SpendCoins(player, cost) then
			spinLock[player] = 0
			return false, string.format("Need %d Gold to spin the Central Market Wheel!", cost), nil
		end
	else
		if isEventFree then
			claimedEventSpin[player] = eventIdCounter
		else
			PlayerDataService.SetLastFreeSpinAt(player, os.time())
		end
	end

	local prize = rollWeightedPrize()
	local detailMsg = prize.Title
	local previewKind = prize.PreviewKind
	local previewId = prize.PreviewId

	if prize.Category == "Fish" or prize.Category == "Meat" or prize.Category == "Vegetable" or prize.Category == "Fruit" then
		detailMsg = grantCategoryCrate(player, prize.Category :: WarehouseConfig.WarehouseCategory, 12)
	elseif prize.Category == "Gold" then
		PlayerDataService.AddCoins(player, 550)
		detailMsg = "+550 Gold credited to your syndicate vault!"
	elseif prize.Category == "Armor" then
		PlayerDataService.SetArmor(player, 100)
		for _, aid in ipairs(WeaponConfig.AMMO_ORDER) do
			local aSpec = WeaponConfig.AMMO_TYPES[aid]
			if aSpec then
				PlayerDataService.AddAmmo(player, aid, aSpec.Packs[1].Quantity, aSpec.MaxReserve)
			end
		end
		BlackMarketService.SyncPlayerAmmoAndGear(player)
		detailMsg = "100 Kevlar Armor equipped + Caliber Ammo resupply!"
	elseif prize.Category == "Gun" then
		local prof = PlayerDataService.GetProfile(player)
		local unowned: { string } = {}
		for _, wid in ipairs(GOLD_POOL_GUNS) do
			if not prof.OwnedWeapons[wid] then
				table.insert(unowned, wid)
			end
		end
		if #unowned > 0 then
			local wonWid = unowned[math.random(1, #unowned)]
			local wSpec = WeaponConfig.WEAPONS[wonWid]
			PlayerDataService.UnlockWeapon(player, wonWid)
			BlackMarketService.SyncPlayerAmmoAndGear(player)
			previewKind = "Weapon"
			previewId = wonWid
			detailMsg = string.format("Unlocked %s! Ready in your hotbar.", if wSpec then wSpec.DisplayName else wonWid)
		else
			PlayerDataService.AddCoins(player, 750)
			detailMsg = "All Black Market guns owned — awarded +750 Gold Cashback!"
		end
	elseif prize.Category == "Bodyguard" then
		local prof = PlayerDataService.GetProfile(player)
		local unowned: { string } = {}
		for _, cid in ipairs(GOLD_POOL_GUARDS) do
			if not prof.UnlockedGuardClasses[cid] then
				table.insert(unowned, cid)
			end
		end
		if #unowned > 0 then
			local wonCid = unowned[math.random(1, #unowned)]
			local gSpec = BodyguardConfig.CLASSES[wonCid :: BodyguardConfig.GuardClassId]
			PlayerDataService.AddBodyguardClass(player, wonCid)
			BodyguardService.RebuildGuardsForPlayer(player)
			previewKind = "Bodyguard"
			previewId = wonCid
			detailMsg = string.format("Recruited %s (%s) into your squad!", if gSpec then gSpec.DisplayName else wonCid, if gSpec then gSpec.Role else "Guard")
		else
			PlayerDataService.AddCoins(player, 850)
			detailMsg = "All Gold bodyguard classes unlocked — awarded +850 Gold Bonus!"
		end
	end

	local result = {
		SegmentIndex = prize.Index,
		PrizeId = prize.Id,
		PrizeTitle = prize.Title,
		Detail = detailMsg,
		Rarity = prize.Rarity,
		PreviewKind = previewKind,
		PreviewId = previewId,
	}
	return true, detailMsg, result
end

function SpinEventService.TeleportToWheel(player: Player): (boolean, string)
	local char = player.Character
	if not char then
		return false, "Character unavailable"
	end
	local warpPos = WHEEL_POS + Vector3.new(0, 4.5, -14)
	local lookPos = WHEEL_POS + Vector3.new(0, 6.0, 0)
	pcall(function()
		player:RequestStreamAroundAsync(warpPos)
	end)
	char:PivotTo(CFrame.lookAt(warpPos, lookPos))
	if openWheelEv then
		openWheelEv:FireClient(player, SpinEventService.GetSnapshot(player))
	end
	return true, "Arrived at the Central Market Lucky Spin Wheel."
end

function SpinEventService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		local f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
		remotes = f
	end
	local existingEv = remotes:FindFirstChild("OpenSpinWheel")
	if existingEv and existingEv:IsA("RemoteEvent") then
		openWheelEv = existingEv
	else
		local ev = Instance.new("RemoteEvent")
		ev.Name = "OpenSpinWheel"
		ev.Parent = remotes
		openWheelEv = ev
	end

	build3DSpinWheelMonument()

	-- Live Central Market Lucky Spin Event Cycle!
	eventThread = task.spawn(function()
		task.wait(12)
		while isRunning do
			eventActive = true
			eventIdCounter += 1
			eventEndsAt = os.clock() + EVENT_CYCLE_ACTIVE
			ReplicatedStorage:SetAttribute("SpinEventActive", true)
			if boardStatusLbl then
				boardStatusLbl.Text = "SPIN EVENT LIVE  |  FREE BONUS SPIN & 200G SPINS  [E]"
				boardStatusLbl.TextColor3 = Color3.fromRGB(142, 212, 162)
			end
			broadcastToast("CENTRAL MARKET SPIN EVENT LIVE! Free Bonus Spin + 200G Spins at Central Plaza!")
			task.wait(EVENT_CYCLE_ACTIVE)
			if not isRunning then break end

			eventActive = false
			ReplicatedStorage:SetAttribute("SpinEventActive", false)
			if boardStatusLbl then
				boardStatusLbl.Text = "WIN GUNS, BODYGUARDS & FRESH CRATES  [E]"
				boardStatusLbl.TextColor3 = Color3.fromRGB(214, 184, 118)
			end
			task.wait(EVENT_CYCLE_IDLE)
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		claimedEventSpin[p] = nil
		spinLock[p] = nil
	end)

	print("[Food Empire] SpinEventService started (3D Central Market Lucky Spin Wheel & Live Events active)!")
end

function SpinEventService.Stop(): ()
	isRunning = false
	if eventThread then task.cancel(eventThread); eventThread = nil end
	if promptConn then promptConn:Disconnect(); promptConn = nil end
	if wheelModel and wheelModel.Parent then
		wheelModel:Destroy()
	end
	wheelModel = nil
end

return SpinEventService
