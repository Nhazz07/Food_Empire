--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShipmentService = require("./ShipmentService")
local BlackMarketService = require("./BlackMarketService")

local RivalAIService = {}

local MAX_RIVAL_UNITS = 12 -- 3 Rivals taking care of each of the 4 Territories!
local OPENING_GRACE_SECONDS = 8
local DECISION_INTERVAL = 2.0
local RESPAWN_DELAY = 12
local RIVAL_ATTACK_RANGE = 11.5
local RIVAL_ATTACK_COOLDOWN = 1.2

type RivalTierSpec = {
	Tier: number,
	Title: string,
	MaxHP: number,
	Damage: number,
	GunDamage: number,
	Scale: number,
	WalkSpeed: number,
	HasGun: boolean,
	CoatColor: Color3,
	HatColor: Color3,
	BadgeColor: Color3,
	BountyGold: number,
}

-- Random Rival Ranks from Low (Lv.1) to High (Lv.5)!
local RIVAL_TIERS: { RivalTierSpec } = {
	{
		Tier = 1,
		Title = "Lv.1 Sous Rival",
		MaxHP = 110,
		Damage = 11,
		GunDamage = 0,
		Scale = 0.90,
		WalkSpeed = 15.5,
		HasGun = false,
		CoatColor = Color3.fromRGB(224, 96, 58),
		HatColor = Color3.fromRGB(232, 112, 68),
		BadgeColor = Color3.fromRGB(178, 78, 42),
		BountyGold = 35,
	},
	{
		Tier = 2,
		Title = "Lv.2 Line Rival",
		MaxHP = 155,
		Damage = 15,
		GunDamage = 0,
		Scale = 0.98,
		WalkSpeed = 16.5,
		HasGun = false,
		CoatColor = Color3.fromRGB(204, 48, 52),
		HatColor = Color3.fromRGB(214, 52, 58),
		BadgeColor = Color3.fromRGB(186, 38, 46),
		BountyGold = 50,
	},
	{
		Tier = 3,
		Title = "Lv.3 Head Rival",
		MaxHP = 215,
		Damage = 19,
		GunDamage = 13,
		Scale = 1.06,
		WalkSpeed = 17.2,
		HasGun = true,
		CoatColor = Color3.fromRGB(168, 28, 42),
		HatColor = Color3.fromRGB(184, 32, 48),
		BadgeColor = Color3.fromRGB(156, 26, 42),
		BountyGold = 75,
	},
	{
		Tier = 4,
		Title = "Lv.4 Exec Rival",
		MaxHP = 285,
		Damage = 25,
		GunDamage = 17,
		Scale = 1.15,
		WalkSpeed = 17.8,
		HasGun = true,
		CoatColor = Color3.fromRGB(118, 22, 56),
		HatColor = Color3.fromRGB(136, 26, 66),
		BadgeColor = Color3.fromRGB(128, 24, 62),
		BountyGold = 110,
	},
	{
		Tier = 5,
		Title = "👑 Lv.5 Master Rival",
		MaxHP = 380,
		Damage = 32,
		GunDamage = 22,
		Scale = 1.25,
		WalkSpeed = 18.5,
		HasGun = true,
		CoatColor = Color3.fromRGB(38, 22, 32),
		HatColor = Color3.fromRGB(232, 178, 42),
		BadgeColor = Color3.fromRGB(168, 118, 18),
		BountyGold = 160,
	},
}

type TerritoryCareSpec = {
	Id: string,
	ShortName: string,
	CareTasks: { string },
	WorkSpots: { Vector3 },
	GateSpot: Vector3,
	HighwaySpot: Vector3,
}

local TERRITORY_SPECS: { TerritoryCareSpec } = {
	{
		Id = "VegetableFarm",
		ShortName = "Veg Farm",
		CareTasks = { "🥕 Watering Vegetable Farm crops", "🚜 Tending Farm Tractor & Crates", "🛡️ Guarding Vegetable Farm Gate" },
		WorkSpots = { Vector3.new(-710, 4, -715), Vector3.new(-755, 4, -735), Vector3.new(-685, 4, -745) },
		GateSpot = Vector3.new(-630, 4, -630),
		HighwaySpot = Vector3.new(-360, 4, -360),
	},
	{
		Id = "Ranch",
		ShortName = "Meat Ranch",
		CareTasks = { "🥩 Tending Meat Ranch livestock", "🌾 Checking Ranch Grain Silos", "🛡️ Guarding Meat Ranch Gate" },
		WorkSpots = { Vector3.new(715, 4, -715), Vector3.new(755, 4, -740), Vector3.new(695, 4, -750) },
		GateSpot = Vector3.new(630, 4, -630),
		HighwaySpot = Vector3.new(360, 4, -360),
	},
	{
		Id = "FruitOrchard",
		ShortName = "Orchard",
		CareTasks = { "🍎 Harvesting Fruit Orchard trees", "📦 Packing Fresh Fruit Crates", "🛡️ Guarding Fruit Orchard Gate" },
		WorkSpots = { Vector3.new(-715, 4, 715), Vector3.new(-745, 4, 755), Vector3.new(-685, 4, 735) },
		GateSpot = Vector3.new(-630, 4, 630),
		HighwaySpot = Vector3.new(-360, 4, 360),
	},
	{
		Id = "FishingPort",
		ShortName = "Fish Port",
		CareTasks = { "🐟 Inspecting Fishing Port catch", "⚓ Loading Harbor Seafood Crates", "🛡️ Guarding Fishing Port Road" },
		WorkSpots = { Vector3.new(740, 4, 760), Vector3.new(775, 4, 790), Vector3.new(710, 4, 740) },
		GateSpot = Vector3.new(650, 4, 665),
		HighwaySpot = Vector3.new(360, 4, 360),
	},
}

type RivalAgent = {
	UnitIndex: number,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	TierSpec: RivalTierSpec,
	Territory: TerritoryCareSpec,
	RoleSlot: number, -- 1 = Caretaker A, 2 = Caretaker B / Gate Guard, 3 = Territory & Highway Escort
	WorkStep: number,
	TaskLabel: TextLabel,
	LastAttackAt: number,
	HasGun: boolean,
}

local isRunning = false
local aiFolder: Folder? = nil
local activeAgents: { RivalAgent } = {}
local aiThread: thread? = nil

local function pickRandomTier(roleSlot: number): RivalTierSpec
	-- Weighted random tier from Low (Lv.1) to High (Lv.5) so every territory has a mix of low, mid & high rivals!
	local roll = math.random(1, 100)
	if roleSlot == 1 then
		-- Caretaker slot skews Low-to-Mid (Lv.1 - Lv.3)
		if roll <= 45 then return RIVAL_TIERS[1]
		elseif roll <= 80 then return RIVAL_TIERS[2]
		else return RIVAL_TIERS[3] end
	elseif roleSlot == 2 then
		-- Gate Defender skews Mid-to-High (Lv.2 - Lv.4)
		if roll <= 30 then return RIVAL_TIERS[2]
		elseif roll <= 70 then return RIVAL_TIERS[3]
		else return RIVAL_TIERS[4] end
	else
		-- Territory Commander / Highway Escort skews High (Lv.3 - Lv.5)
		if roll <= 30 then return RIVAL_TIERS[3]
		elseif roll <= 70 then return RIVAL_TIERS[4]
		else return RIVAL_TIERS[5] end
	end
end

local function buildRivalChefModel(unitIndex: number, territory: TerritoryCareSpec, roleSlot: number, spawnPos: Vector3): RivalAgent
	local tierSpec = pickRandomTier(roleSlot)
	local s = tierSpec.Scale

	local model = Instance.new("Model")
	model.Name = string.format("RivalChef_Lv%d_%s_%d", tierSpec.Tier, territory.Id, unitIndex)

	local function makePart(name: string, size: Vector3, color: Color3, mat: Enum.Material, shape: Enum.PartType?, collide: boolean): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * s
		p.Color = color
		p.Material = mat
		if shape then
			p.Shape = shape
		end
		p.CanCollide = collide
		p.CanTouch = collide
		p.Massless = not collide
		p.CastShadow = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local function weldTo(parentPart: BasePart, childPart: BasePart, relCF: CFrame): ()
		local pos = relCF.Position * s
		local rot = relCF - relCF.Position
		childPart.CFrame = parentPart.CFrame * CFrame.new(pos) * rot
		local w = Instance.new("WeldConstraint")
		w.Part0 = parentPart
		w.Part1 = childPart
		w.Parent = childPart
	end

	local function makeJoint(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
		local sc0 = CFrame.new(c0.Position * s) * (c0 - c0.Position)
		local sc1 = CFrame.new(c1.Position * s) * (c1 - c1.Position)
		part1.CFrame = part0.CFrame * sc0 * sc1:Inverse()
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = part0
		m.Part1 = part1
		m.C0 = sc0
		m.C1 = sc1
		m.Parent = part0
		return m
	end

	local coatCol = tierSpec.CoatColor
	local darkApron = Color3.fromRGB(34, 38, 48)
	local pantsCol = Color3.fromRGB(44, 48, 60)
	local bootCol = Color3.fromRGB(24, 26, 32)
	local skinCol = Color3.fromRGB(244, 206, 172)

	-- 1. Core Torso (HumanoidRootPart) + Apron + Gold Chef Buttons
	local root = makePart("HumanoidRootPart", Vector3.new(2.5, 2.8, 1.4), coatCol, Enum.Material.SmoothPlastic, nil, true)
	root.CFrame = CFrame.new(spawnPos)

	local apron = makePart("Apron", Vector3.new(2.6, 1.5, 1.5), darkApron, Enum.Material.SmoothPlastic, nil, false)
	weldTo(root, apron, CFrame.new(0, -0.7, 0))

	local collar = makePart("Collar", Vector3.new(1.9, 0.45, 1.48), Color3.fromRGB(248, 244, 236), Enum.Material.SmoothPlastic, nil, false)
	weldTo(root, collar, CFrame.new(0, 1.25, 0))

	for b = 1, 2 do
		for _, bx in ipairs({ -0.45, 0.45 }) do
			local btn = makePart("Button", Vector3.new(0.24, 0.24, 0.14), Color3.fromRGB(248, 198, 52), Enum.Material.Metal, Enum.PartType.Ball, false)
			weldTo(root, btn, CFrame.new(bx, 0.7 - (b - 1) * 0.55, -0.72))
		end
	end

	-- 2. Head + Angry Face + Tier-Colored Rival Chef Toque
	local head = makePart("Head", Vector3.new(2.0, 2.0, 2.0), skinCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
	weldTo(root, head, CFrame.new(0, 2.35, 0))

	for _, ex in ipairs({ -0.36, 0.36 }) do
		local eye = makePart("Eye", Vector3.new(0.26, 0.28, 0.14), Color3.fromRGB(24, 24, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
		weldTo(head, eye, CFrame.new(ex, 0.12, -0.92))
		local brow = makePart("Brow", Vector3.new(0.48, 0.14, 0.14), Color3.fromRGB(36, 26, 22), Enum.Material.SmoothPlastic, nil, false)
		weldTo(head, brow, CFrame.new(ex, 0.38, -0.92) * CFrame.Angles(0, 0, math.rad(if ex < 0 then -18 else 18)))
	end
	local stacheL = makePart("MustacheL", Vector3.new(0.55, 0.18, 0.18), Color3.fromRGB(36, 26, 22), Enum.Material.SmoothPlastic, nil, false)
	weldTo(head, stacheL, CFrame.new(-0.28, -0.3, -0.94) * CFrame.Angles(0, 0, math.rad(14)))
	local stacheR = makePart("MustacheR", Vector3.new(0.55, 0.18, 0.18), Color3.fromRGB(36, 26, 22), Enum.Material.SmoothPlastic, nil, false)
	weldTo(head, stacheR, CFrame.new(0.28, -0.3, -0.94) * CFrame.Angles(0, 0, math.rad(-14)))

	local hatBand = makePart("HatBand", Vector3.new(0.75, 2.15, 2.15), tierSpec.BadgeColor, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, false)
	weldTo(head, hatBand, CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local hatPuff = makePart("RivalChefHat", Vector3.new(2.55, 1.65, 2.45), tierSpec.HatColor, Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
	hatPuff.CastShadow = false
	weldTo(head, hatPuff, CFrame.new(0, 1.95, 0))

	-- 3. Articulated Left & Right Arms + Hands + Detailed Gun or Cast-Iron Pan!
	local leftArm = makePart("LeftArm", Vector3.new(0.95, 2.45, 0.95), coatCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("LeftArmJoint", root, leftArm, CFrame.new(-1.75, 1.05, 0), CFrame.new(0, 1.05, 0))
	local leftHand = makePart("LeftHand", Vector3.new(0.82, 0.72, 0.82), skinCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
	weldTo(leftArm, leftHand, CFrame.new(0, -1.35, 0))

	local rightArm = makePart("RightArm", Vector3.new(0.95, 2.45, 0.95), coatCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("RightArmJoint", root, rightArm, CFrame.new(1.75, 1.05, 0), CFrame.new(0, 1.05, 0))
	local rightHand = makePart("RightHand", Vector3.new(0.82, 0.72, 0.82), skinCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
	weldTo(rightArm, rightHand, CFrame.new(0, -1.35, 0))

	local hasGun = tierSpec.HasGun
	if hasGun then
		local gunGrip = makePart("RivalGunGrip", Vector3.new(0.28, 0.85, 0.38), Color3.fromRGB(28, 30, 38), Enum.Material.SmoothPlastic, nil, false)
		weldTo(rightHand, gunGrip, CFrame.new(0, -0.25, -0.35))
		local slideCol = if tierSpec.Tier >= 5 then Color3.fromRGB(238, 186, 48) else Color3.fromRGB(96, 104, 118)
		local gunSlide = makePart("RivalPistol", Vector3.new(0.32, 0.34, 1.65), slideCol, Enum.Material.Metal, nil, false)
		weldTo(gunGrip, gunSlide, CFrame.new(0, 0.52, -0.55))
		local gunBarrel = makePart("RivalBarrel", Vector3.new(0.45, 0.20, 0.20), Color3.fromRGB(36, 40, 48), Enum.Material.Metal, Enum.PartType.Cylinder, false)
		weldTo(gunSlide, gunBarrel, CFrame.new(0, 0, -0.95) * CFrame.Angles(0, math.rad(90), 0))
	else
		local panHandle = makePart("PanHandle", Vector3.new(0.28, 0.28, 1.6), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, nil, false)
		weldTo(rightHand, panHandle, CFrame.new(0, -0.1, -0.95))
		local panBody = makePart("PanBody", Vector3.new(0.45, 1.75, 1.75), Color3.fromRGB(36, 40, 48), Enum.Material.Metal, Enum.PartType.Cylinder, false)
		weldTo(panHandle, panBody, CFrame.new(0, 0, -1.45) * CFrame.Angles(0, 0, math.rad(90)))
	end

	-- 4. Articulated Left & Right Legs + Chef Boots
	local leftLeg = makePart("LeftLeg", Vector3.new(1.05, 2.5, 1.05), pantsCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("LeftLegJoint", root, leftLeg, CFrame.new(-0.62, -1.4, 0), CFrame.new(0, 1.25, 0))
	local leftBoot = makePart("LeftBoot", Vector3.new(1.12, 0.65, 1.45), bootCol, Enum.Material.SmoothPlastic, nil, false)
	weldTo(leftLeg, leftBoot, CFrame.new(0, -1.2, -0.18))

	local rightLeg = makePart("RightLeg", Vector3.new(1.05, 2.5, 1.05), pantsCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("RightLegJoint", root, rightLeg, CFrame.new(0.62, -1.4, 0), CFrame.new(0, 1.25, 0))
	local rightBoot = makePart("RightBoot", Vector3.new(1.12, 0.65, 1.45), bootCol, Enum.Material.SmoothPlastic, nil, false)
	weldTo(rightLeg, rightBoot, CFrame.new(0, -1.2, -0.18))

	-- 5. Floating Nameplate showing Rank + Territory + Task + Numeric HP Bar!
	local bb = Instance.new("BillboardGui")
	bb.Name = "RivalTag"
	bb.Size = UDim2.fromOffset(188, 62)
	bb.StudsOffset = Vector3.new(0, 4.1 * s, 0)
	bb.MaxDistance = 155
	bb.AlwaysOnTop = false
	bb.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 23)
	label.BackgroundColor3 = tierSpec.BadgeColor
	label.BackgroundTransparency = 0.06
	label.Font = Enum.Font.GothamBlack
	label.Text = string.format("%s (%s)", tierSpec.Title, territory.ShortName)
	label.TextSize = 12
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = label
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(24, 18, 22)
	st.Thickness = 1.5
	st.Parent = label

	local taskLbl = Instance.new("TextLabel")
	taskLbl.Name = "TaskText"
	taskLbl.Position = UDim2.new(0.03, 0, 0, 24)
	taskLbl.Size = UDim2.new(0.94, 0, 0, 17)
	taskLbl.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
	taskLbl.BackgroundTransparency = 0.15
	taskLbl.Font = Enum.Font.GothamBold
	taskLbl.Text = territory.CareTasks[1]
	taskLbl.TextSize = 10
	taskLbl.TextColor3 = Color3.fromRGB(255, 232, 136)
	taskLbl.Parent = bb
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 5)
	tc.Parent = taskLbl

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBarBg"
	hpBg.Position = UDim2.new(0.05, 0, 0, 44)
	hpBg.Size = UDim2.new(0.90, 0, 0, 15)
	hpBg.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
	hpBg.Parent = bb
	local hpC = Instance.new("UICorner")
	hpC.CornerRadius = UDim.new(0, 6)
	hpC.Parent = hpBg

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(68, 214, 96)
	hpFill.Parent = hpBg
	local hpFC = Instance.new("UICorner")
	hpFC.CornerRadius = UDim.new(0, 6)
	hpFC.Parent = hpFill

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.GothamBlack
	hpText.Text = string.format("❤️ %d / %d HP", tierSpec.MaxHP, tierSpec.MaxHP)
	hpText.TextSize = 10
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.ZIndex = 3
	hpText.Parent = hpBg

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = tierSpec.MaxHP
	humanoid.Health = tierSpec.MaxHP
	humanoid.WalkSpeed = tierSpec.WalkSpeed
	humanoid.HipHeight = 2.65 * s
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	humanoid.HealthChanged:Connect(function(hp: number)
		local cur = math.max(0, math.ceil(hp))
		local maxH = math.max(1, math.ceil(humanoid.MaxHealth))
		local frac = math.clamp(hp / maxH, 0, 1)
		hpFill.Size = UDim2.fromScale(frac, 1)
		hpText.Text = string.format("❤️ %d / %d HP", cur, maxH)
		hpFill.BackgroundColor3 = if frac > 0.5
			then Color3.fromRGB(68, 214, 96)
			elseif frac > 0.25 then Color3.fromRGB(246, 188, 44)
			else Color3.fromRGB(238, 56, 62)
	end)

	model.PrimaryPart = root
	model:SetAttribute("Faction", "Rival")
	model:SetAttribute("RivalTier", tierSpec.Tier)
	model:SetAttribute("RivalTitle", tierSpec.Title)
	model:SetAttribute("TerritoryId", territory.Id)
	model:SetAttribute("BountyGold", tierSpec.BountyGold)
	CollectionService:AddTag(model, "RivalAIUnit")

	if aiFolder then
		model.Parent = aiFolder
	else
		model.Parent = Workspace
	end

	return {
		UnitIndex = unitIndex,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		TierSpec = tierSpec,
		Territory = territory,
		RoleSlot = roleSlot,
		WorkStep = math.random(1, #territory.WorkSpots),
		TaskLabel = taskLbl,
		LastAttackAt = 0,
		HasGun = hasGun,
	}
end

local function isInsideAnySafeBase(pos: Vector3): boolean
	for _, base in ipairs(CollectionService:GetTagged("PlayerBase")) do
		if base:IsA("Model") and base:IsDescendantOf(Workspace) then
			local piv = base:GetPivot().Position
			local dx = math.abs(pos.X - piv.X)
			local dz = math.abs(pos.Z - piv.Z)
			if dx <= 116 and dz <= 116 then
				return true
			end
		end
	end
	return false
end

local function tryRivalCounterAttack(agent: RivalAgent): boolean
	local now = os.clock()
	local myPos = agent.Root.Position
	local nearestHum: Humanoid? = nil
	local nearestPos: Vector3? = nil
	-- Rivals fiercely defend their assigned territory up to 72 studs!
	local bestDist = if agent.HasGun then 72 else 46

	-- 1. Spot & intercept enemy Player Delivery Runners sneaking into Central Park
	for _, runner in ipairs(CollectionService:GetTagged("PlayerDeliveryRunner")) do
		if runner:IsA("Model") then
			local rRoot = runner:FindFirstChild("HumanoidRootPart")
			local rHum = runner:FindFirstChildOfClass("Humanoid")
			if rRoot and rRoot:IsA("BasePart") and rHum and rHum.Health > 0 and not isInsideAnySafeBase(rRoot.Position) then
				local d = (rRoot.Position - myPos).Magnitude
				if d < (if ReplicatedStorage:GetAttribute("IsNight") == true then 28 else 44) then
					bestDist = d
					nearestHum = rHum
					nearestPos = rRoot.Position
				end
			end
		end
	end

	-- 2. Fight nearby Player Bodyguards & Raider Chefs entering the territory!
	for _, tagName in ipairs({ "PlayerBodyguardUnit", "PlayerRaiderUnit" }) do
		for _, raider in ipairs(CollectionService:GetTagged(tagName)) do
			if raider:IsA("Model") then
				local rRoot = raider:FindFirstChild("HumanoidRootPart")
				local rHum = raider:FindFirstChildOfClass("Humanoid")
				if rRoot and rRoot:IsA("BasePart") and rHum and rHum.Health > 0 and not isInsideAnySafeBase(rRoot.Position) then
					local d = (rRoot.Position - myPos).Magnitude
					if d < bestDist then
						bestDist = d
						nearestHum = rHum
						nearestPos = rRoot.Position
					end
				end
			end
		end
	end

	-- 3. Defend Territory against Players outside safe Restaurant Bases!
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local pRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
		local pHum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		if pRoot and pRoot:IsA("BasePart") and pHum and pHum.Health > 0 and not isInsideAnySafeBase(pRoot.Position) then
			local d = (pRoot.Position - myPos).Magnitude
			if d < bestDist then
				bestDist = d
				nearestHum = pHum
				nearestPos = pRoot.Position
			end
		end
	end

	if nearestHum and nearestPos then
		agent.TaskLabel.Text = "⚔️ Defending " .. agent.Territory.ShortName .. "!"
		if agent.HasGun and bestDist <= 64 and bestDist > RIVAL_ATTACK_RANGE then
			if (now - agent.LastAttackAt) >= 1.5 then
				agent.LastAttackAt = now
				local fromPos = agent.Root.Position + Vector3.new(0, 1.2, 0)
				BlackMarketService.SpawnBulletTracer(fromPos, nearestPos, Color3.fromRGB(255, 76, 68))
				BlackMarketService.BroadcastSFX("EnemyShot", fromPos)
				if math.random() < 0.72 then
					nearestHum:TakeDamage(agent.TierSpec.GunDamage)
					BlackMarketService.BroadcastSFX("MeleeHit", nearestPos)
				end
			end
			agent.Humanoid:MoveTo(nearestPos)
			return true
		elseif bestDist <= RIVAL_ATTACK_RANGE then
			if (now - agent.LastAttackAt) >= RIVAL_ATTACK_COOLDOWN then
				agent.LastAttackAt = now
				nearestHum:TakeDamage(agent.TierSpec.Damage)
				BlackMarketService.BroadcastSFX("MeleeHit", nearestPos)
			end
		end
		agent.Humanoid:MoveTo(nearestPos)
		return true
	end
	return false
end

local function navigateAgentTo(agent: RivalAgent, destination: Vector3): ()
	if agent.Humanoid.Health <= 0 or not agent.Model.Parent then
		return
	end
	if (agent.Root.Position - destination).Magnitude <= 8 then
		return
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2.5,
		AgentHeight = 6,
		AgentCanJump = true,
	})

	local ok = pcall(function()
		path:ComputeAsync(agent.Root.Position, destination)
	end)

	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		local stepTarget = waypoints[math.min(4, #waypoints)]
		if stepTarget then
			if stepTarget.Action == Enum.PathWaypointAction.Jump then
				agent.Humanoid.Jump = true
			end
			agent.Humanoid:MoveTo(stepTarget.Position)
			return
		end
	end

	agent.Humanoid:MoveTo(destination)
end

local function ensureAgents(): ()
	for i = #activeAgents, 1, -1 do
		local agent = activeAgents[i]
		if not agent.Model.Parent or agent.Humanoid.Health <= 0 then
			if agent.Model.Parent then
				local dying = agent.Model
				task.delay(3, function()
					if dying.Parent then
						dying:Destroy()
					end
				end)
			end
			table.remove(activeAgents, i)
		end
	end

	-- Maintain 3 Rival Chefs per Territory (12 total across all 4 territories!)
	for tIdx, terr in ipairs(TERRITORY_SPECS) do
		for roleSlot = 1, 3 do
			local hasSlot = false
			for _, ag in ipairs(activeAgents) do
				if ag.Territory.Id == terr.Id and ag.RoleSlot == roleSlot then
					hasSlot = true
					break
				end
			end
			if not hasSlot and #activeAgents < MAX_RIVAL_UNITS then
				local unitIndex = (tIdx - 1) * 3 + roleSlot
				local spawnPos = if roleSlot == 2 then terr.GateSpot else terr.WorkSpots[roleSlot]
				local agent = buildRivalChefModel(unitIndex, terr, roleSlot, spawnPos)
				table.insert(activeAgents, agent)
			end
		end
	end
end

function RivalAIService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local existingFolder = Workspace:FindFirstChild("RivalAIUnits")
	if existingFolder and existingFolder:IsA("Folder") then
		existingFolder:ClearAllChildren()
		aiFolder = existingFolder
	else
		local folder = Instance.new("Folder")
		folder.Name = "RivalAIUnits"
		folder.Parent = Workspace
		aiFolder = folder
	end

	ensureAgents()
	print("[Food Empire] RivalAIService started (12 Low-to-High Ranked Territory Caretaker & Defender Rivals active)!")

	aiThread = task.spawn(function()
		task.wait(OPENING_GRACE_SECONDS)
		local respawnTimer = 0
		while isRunning do
			task.wait(DECISION_INTERVAL)
			if not isRunning then
				break
			end

			respawnTimer += DECISION_INTERVAL
			if respawnTimer >= RESPAWN_DELAY then
				respawnTimer = 0
				ensureAgents()
			end

			for _, agent in ipairs(activeAgents) do
				if agent.Model.Parent and agent.Humanoid.Health > 0 then
					if not tryRivalCounterAttack(agent) then
						local terr = agent.Territory
						local dest: Vector3
						if agent.RoleSlot == 1 then
							-- Caretaker A: cycles between all 3 territory harvest/care spots
							agent.WorkStep = (agent.WorkStep % #terr.WorkSpots) + 1
							dest = terr.WorkSpots[agent.WorkStep]
							agent.TaskLabel.Text = terr.CareTasks[agent.WorkStep] or terr.CareTasks[1]
						elseif agent.RoleSlot == 2 then
							-- Caretaker B / Gate Warden: patrols between the Territory Gate and front harvest spot
							agent.WorkStep = (agent.WorkStep % 2) + 1
							dest = if agent.WorkStep == 1 then terr.GateSpot else terr.WorkSpots[1]
							agent.TaskLabel.Text = if agent.WorkStep == 1 then terr.CareTasks[3] else terr.CareTasks[2]
						else
							-- Territory Commander: patrols Territory Gate, Highway, and Shipment Route!
							ShipmentService.TryRivalInterceptAtPosition(agent.Root.Position)
							agent.WorkStep = (agent.WorkStep % 3) + 1
							if agent.WorkStep == 1 then
								dest = terr.WorkSpots[2]
								agent.TaskLabel.Text = terr.CareTasks[1]
							elseif agent.WorkStep == 2 then
								dest = terr.GateSpot
								agent.TaskLabel.Text = terr.CareTasks[3]
							else
								dest = terr.HighwaySpot
								agent.TaskLabel.Text = "🛣️ Patrolling " .. terr.ShortName .. " Highway"
							end
						end
						navigateAgentTo(agent, Vector3.new(dest.X, agent.Root.Position.Y, dest.Z))
					end
				end
			end
		end
	end)
end

function RivalAIService.Stop(): ()
	isRunning = false
	if aiThread then
		task.cancel(aiThread)
		aiThread = nil
	end
	table.clear(activeAgents)
end

return RivalAIService
