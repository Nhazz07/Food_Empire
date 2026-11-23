--!strict

-- CentralParkBranchService:
--  * Builds a physical, ownable "CENTRAL PARK BISTRO" flagship restaurant branch right on Central Park Plaza.
--  * Players can buy the Central Park Restaurant (750 Gold) and call their hired Chefs & Waiters to staff it.
--  * Staffed branches spawn live animated Chef, Waiter & dining Central Park patrons and earn high-margin Gold & Rep!

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local RivalFactionConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RivalFactionConfig")
)
local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local WarehouseService = require("./WarehouseService")
local CrewService = require("./CrewService")
local MonetizationService = require("./MonetizationService")
local SyndicateContractService = require("./SyndicateContractService")

local CentralParkBranchService = {}

CentralParkBranchService.BRANCH_COST = 750
local BRANCH_POS = Vector3.new(48, 1.35, 98)
local BRANCH_LOOK_AT = Vector3.new(0, 1.35, 0)
local SERVE_TICK_SECONDS = 8.5

local isRunning = false
local branchModel: Model? = nil
local branchCF: CFrame = CFrame.lookAt(BRANCH_POS, BRANCH_LOOK_AT)
local signOwnerLabel: TextLabel? = nil
local signSubLabel: TextLabel? = nil
local mainPrompt: ProximityPrompt? = nil
local promptConn: RBXScriptConnection? = nil
local steamEmitter: ParticleEmitter? = nil
local staffFolder: Folder? = nil
local loopThread: thread? = nil
local onChangedCb: ((Player) -> ())? = nil
local activeStaffModels: { Model } = {}
local activeWaiterModel: Model? = nil
local activeWaiterHum: Humanoid? = nil
local activeWaiterRoot: BasePart? = nil
local activeWaiterLabel: TextLabel? = nil
local currentDisplayOwner: Player? = nil
local shakedownEnforcer: Model? = nil
local shakedownDeadline = 0
local shakedownTargetOwner: Player? = nil

local PATIO_TABLE_OFFSETS = {
	Vector3.new(-7.5, 0, -10.5),
	Vector3.new(0, 0, -12.0),
	Vector3.new(7.5, 0, -10.5),
}

local function sendToast(player: Player, msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg)
	end
end

function CentralParkBranchService.SetChangedCallback(cb: (Player) -> ()): ()
	onChangedCb = cb
end

local function clearBranchStaffVisuals(): ()
	for _, m in ipairs(activeStaffModels) do
		if m.Parent then
			m:Destroy()
		end
	end
	table.clear(activeStaffModels)
	activeWaiterModel = nil
	activeWaiterHum = nil
	activeWaiterRoot = nil
	activeWaiterLabel = nil
	if steamEmitter then
		steamEmitter.Rate = 0
	end
end

local function refreshBranchVisuals(): ()
	-- Find the first online player who owns & staffed the Central Park Bistro (or just owns it) to showcase live staff
	local showcaseOwner: Player? = nil
	local showcaseStaffed = false
	for _, p in ipairs(Players:GetPlayers()) do
		local prof = PlayerDataService.GetProfile(p)
		if prof.OwnsCentralParkBranch then
			if prof.CentralParkBranchStaffed and CrewService.GetCrewCount(p) > 0 then
				showcaseOwner = p
				showcaseStaffed = true
				break
			elseif not showcaseOwner then
				showcaseOwner = p
			end
		end
	end

	if signOwnerLabel and signSubLabel then
		if showcaseOwner and showcaseStaffed then
			local chefs = CrewService.GetCrewCount(showcaseOwner)
			local waiters = CrewService.GetWaiterCount(showcaseOwner)
			signOwnerLabel.Text = string.upper(showcaseOwner.DisplayName) .. "'S CENTRAL PARK BISTRO"
			signSubLabel.Text = string.format("OPEN FOR SERVICE  |  %d CHEF%s  |  %d WAITER%s", chefs, if chefs == 1 then "" else "S", waiters, if waiters == 1 then "" else "S")
			signSubLabel.TextColor3 = Color3.fromRGB(142, 212, 162)
		elseif showcaseOwner then
			signOwnerLabel.Text = string.upper(showcaseOwner.DisplayName) .. "'S CENTRAL PARK BISTRO"
			signSubLabel.Text = "CLOSED  |  PRESS [E] TO CALL YOUR CHEF & WAITER"
			signSubLabel.TextColor3 = Color3.fromRGB(214, 184, 118)
		else
			signOwnerLabel.Text = "CENTRAL PARK BISTRO  |  FOR SALE"
			signSubLabel.Text = string.format("OWN PRIME PARK FRANCHISE FOR %d GOLD  [E]", CentralParkBranchService.BRANCH_COST)
			signSubLabel.TextColor3 = Color3.fromRGB(224, 198, 134)
		end
	end

	if not showcaseStaffed then
		clearBranchStaffVisuals()
		currentDisplayOwner = showcaseOwner
		return
	end

	if currentDisplayOwner == showcaseOwner and #activeStaffModels > 0 then
		return
	end

	clearBranchStaffVisuals()
	currentDisplayOwner = showcaseOwner
	if not staffFolder or not showcaseOwner then
		return
	end

	-- 1. Spawn Central Park Bistro Chef behind the open kitchen grill!
	local chefCF = branchCF * CFrame.new(-3.2, 3.6, 2.2)
	local chefRig = MafiaVisualBuilder.BuildChefRig("CentralParkChef", Color3.fromRGB(134, 28, 36), 1.04, chefCF, false)
	for _, desc in ipairs(chefRig.Model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanQuery = false
		end
	end
	local cbb = Instance.new("BillboardGui")
	cbb.Size = UDim2.fromOffset(160, 26)
	cbb.StudsOffset = Vector3.new(0, 2.9, 0)
	cbb.MaxDistance = 95
	cbb.Parent = chefRig.Head
	local clbl = Instance.new("TextLabel")
	clbl.Size = UDim2.fromScale(1, 1)
	clbl.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	clbl.Font = Enum.Font.GothamBlack
	clbl.Text = "PARK CHEF  |  COOKING"
	clbl.TextSize = 10
	clbl.TextColor3 = Color3.fromRGB(224, 198, 134)
	clbl.Parent = cbb
	Instance.new("UICorner", clbl).CornerRadius = UDim.new(0, 4)
	chefRig.Model.PrimaryPart = chefRig.Root
	CollectionService:AddTag(chefRig.Model, "AnimatedKitchenChef")
	chefRig.Model.Parent = staffFolder
	table.insert(activeStaffModels, chefRig.Model)

	if steamEmitter then
		steamEmitter.Rate = 14
	end

	-- 2. If player also hired a Waiter, spawn a live animated Central Park Waiter delivering to patio tables!
	if CrewService.GetWaiterCount(showcaseOwner) > 0 then
		local waitCF = branchCF * CFrame.new(3.5, 3.8, -5.2)
		local wRig = MafiaVisualBuilder.BuildWaiterRig("CentralParkWaiter", false, 1.02, waitCF)
		local wHum = Instance.new("Humanoid")
		wHum.MaxHealth = 120
		wHum.Health = 120
		wHum.WalkSpeed = 16
		wHum.HipHeight = 2.45
		wHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		wHum.Parent = wRig.Model

		local wbb = Instance.new("BillboardGui")
		wbb.Size = UDim2.fromOffset(175, 26)
		wbb.StudsOffset = Vector3.new(0, 2.9, 0)
		wbb.MaxDistance = 95
		wbb.Parent = wRig.Head
		local wlbl = Instance.new("TextLabel")
		wlbl.Size = UDim2.fromScale(1, 1)
		wlbl.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
		wlbl.Font = Enum.Font.GothamBlack
		wlbl.Text = "PARK WAITER  |  SERVING"
		wlbl.TextSize = 10
		wlbl.TextColor3 = Color3.fromRGB(142, 212, 162)
		wlbl.Parent = wbb
		Instance.new("UICorner", wlbl).CornerRadius = UDim.new(0, 4)

		wRig.Model.PrimaryPart = wRig.Root
		CollectionService:AddTag(wRig.Model, "AnimatedCustomerLimbs")
		wRig.Model.Parent = staffFolder
		table.insert(activeStaffModels, wRig.Model)
		activeWaiterModel = wRig.Model
		activeWaiterHum = wHum
		activeWaiterRoot = wRig.Root
		activeWaiterLabel = wlbl
	end

	-- 3. Spawn 2 realistic seated Central Park Bistro Patrons at the outdoor café tables!
	for idx = 1, 2 do
		local tblOff = PATIO_TABLE_OFFSETS[idx]
		local seatPos = (branchCF * CFrame.new(tblOff + Vector3.new(0, 2.6, -2.2))).Position
		local tablePos = (branchCF * CFrame.new(tblOff + Vector3.new(0, 2.6, 0))).Position
		local pRig = MafiaVisualBuilder.BuildCustomerRig("CentralParkPatron_" .. idx, idx + 1, 0.98, CFrame.lookAt(seatPos, tablePos))
		for _, desc in ipairs(pRig.Model:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
				desc.CanQuery = false
			end
		end
		local llj = pRig.Root:FindFirstChild("LeftLegJoint")
		local rlj = pRig.Root:FindFirstChild("RightLegJoint")
		if llj and llj:IsA("Motor6D") then llj.C0 = llj.C0 * CFrame.Angles(math.rad(80), 0, 0) end
		if rlj and rlj:IsA("Motor6D") then rlj.C0 = rlj.C0 * CFrame.Angles(math.rad(80), 0, 0) end
		pRig.Model.Parent = staffFolder
		table.insert(activeStaffModels, pRig.Model)
	end
end

local function buildCentralParkBistroMonument(): ()
	local map = Workspace:FindFirstChild("FoodEmpireMap")
	local central = if map then map:FindFirstChild("CentralDistrict") else nil
	local plaza = if central then central:FindFirstChild("CentralPlaza") else nil
	local parentFolder = plaza or Workspace

	local old = parentFolder:FindFirstChild("CentralParkBistroBranch")
	if old then old:Destroy() end

	local m = Instance.new("Model")
	m.Name = "CentralParkBistroBranch"
	branchCF = CFrame.lookAt(BRANCH_POS, BRANCH_LOOK_AT)

	local function bPart(name: string, size: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?, collide: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = branchCF * relCF
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

	local obsidian = Color3.fromRGB(20, 22, 27)
	local charcoal = Color3.fromRGB(36, 40, 48)
	local brick = Color3.fromRGB(72, 42, 38)
	local brass = Color3.fromRGB(168, 138, 76)
	local wood = Color3.fromRGB(88, 56, 36)
	local marble = Color3.fromRGB(214, 210, 202)
	local oxblood = Color3.fromRGB(118, 26, 34)

	-- Raised Patio Deck & Bistro Pavilion Structure
	local floor = bPart("PatioFloor", Vector3.new(24, 0.8, 22), CFrame.new(0, 0.4, -4), charcoal, Enum.Material.Slate, nil, true)
	bPart("BackWall", Vector3.new(18, 10.5, 1.2), CFrame.new(0, 5.6, 5.8), brick, Enum.Material.Brick, nil, true)
	bPart("SideWallL", Vector3.new(1.2, 10.5, 9.0), CFrame.new(-8.6, 5.6, 1.6), brick, Enum.Material.Brick, nil, true)
	bPart("SideWallR", Vector3.new(1.2, 10.5, 9.0), CFrame.new(8.6, 5.6, 1.6), brick, Enum.Material.Brick, nil, true)
	bPart("RoofSlab", Vector3.new(20.5, 1.0, 12.0), CFrame.new(0, 11.2, 1.2), obsidian, Enum.Material.Metal, nil, true)
	bPart("AwningTrim", Vector3.new(20.8, 0.45, 0.6), CFrame.new(0, 10.6, -4.8), brass, Enum.Material.Metal, nil, false)
	bPart("AwningCanopy", Vector3.new(20.0, 0.35, 4.6), CFrame.new(0, 9.6, -6.8) * CFrame.Angles(math.rad(-16), 0, 0), oxblood, Enum.Material.Fabric, nil, false)

	-- Open Bistro Counter + Stainless Grill with Sizzle Steam!
	local counter = bPart("ServiceCounter", Vector3.new(14.5, 3.2, 2.4), CFrame.new(0, 2.4, -2.6), wood, Enum.Material.WoodPlanks, nil, true)
	bPart("CounterTop", Vector3.new(15.0, 0.35, 2.8), CFrame.new(0, 4.15, -2.6), marble, Enum.Material.Marble, nil, true)
	local grill = bPart("BistroGrill", Vector3.new(4.8, 2.8, 2.2), CFrame.new(-3.2, 2.2, 3.8), Color3.fromRGB(92, 98, 108), Enum.Material.Metal, nil, true)
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "BistroSteam"
	steam.Color = ColorSequence.new(Color3.fromRGB(224, 224, 224))
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.0) })
	steam.Lifetime = NumberRange.new(0.8, 1.4)
	steam.Speed = NumberRange.new(2, 4)
	steam.Rate = 0
	steam.Parent = grill
	steamEmitter = steam

	-- Warm Bistro Overhead Light
	local lamp = bPart("WarmLamp", Vector3.new(12, 0.3, 0.6), CFrame.new(0, 10.3, -2.4), Color3.fromRGB(255, 226, 174), Enum.Material.SmoothPlastic, nil, false)
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(255, 214, 152)
	pl.Brightness = 1.6
	pl.Range = 28
	pl.Shadows = false
	pl.Parent = lamp

	-- 3 Outdoor Central Park Bistro Dining Tables + Chairs
	for idx, off in ipairs(PATIO_TABLE_OFFSETS) do
		bPart("TablePost_" .. idx, Vector3.new(0.5, 2.6, 0.5), CFrame.new(off + Vector3.new(0, 2.0, 0)), obsidian, Enum.Material.Metal, nil, true)
		bPart("TableTop_" .. idx, Vector3.new(0.32, 3.6, 3.6), CFrame.new(off + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), marble, Enum.Material.Marble, Enum.PartType.Cylinder, true)
		bPart("ChairSeat_" .. idx, Vector3.new(1.8, 0.35, 1.8), CFrame.new(off + Vector3.new(0, 2.0, -2.3)), wood, Enum.Material.Wood, nil, true)
		bPart("ChairBack_" .. idx, Vector3.new(1.8, 2.0, 0.3), CFrame.new(off + Vector3.new(0, 3.0, -3.1)), wood, Enum.Material.Wood, nil, true)
	end

	-- Marquee Signboard on Bistro Roof
	local signBoard = bPart("BistroSignBoard", Vector3.new(18.0, 3.6, 0.6), CFrame.new(0, 13.4, -4.4), obsidian, Enum.Material.Metal, nil, false)
	local sgui = Instance.new("SurfaceGui")
	sgui.Face = Enum.NormalId.Front
	sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sgui.PixelsPerStud = 32
	sgui.Parent = signBoard

	local sBg = Instance.new("Frame")
	sBg.Size = UDim2.fromScale(1, 1)
	sBg.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
	sBg.BorderSizePixel = 0
	sBg.Parent = sgui

	local topLine = Instance.new("Frame")
	topLine.Size = UDim2.new(1, 0, 0, 5)
	topLine.BackgroundColor3 = oxblood
	topLine.BorderSizePixel = 0
	topLine.Parent = sBg

	local oLbl = Instance.new("TextLabel")
	oLbl.Position = UDim2.new(0.03, 0, 0.10, 0)
	oLbl.Size = UDim2.new(0.94, 0, 0.44, 0)
	oLbl.BackgroundTransparency = 1
	oLbl.Font = Enum.Font.GothamBlack
	oLbl.TextScaled = true
	oLbl.Text = "CENTRAL PARK BISTRO  |  FOR SALE"
	oLbl.TextColor3 = Color3.fromRGB(236, 232, 224)
	oLbl.Parent = sBg
	signOwnerLabel = oLbl

	local subLbl = Instance.new("TextLabel")
	subLbl.Position = UDim2.new(0.03, 0, 0.58, 0)
	subLbl.Size = UDim2.new(0.94, 0, 0.32, 0)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = Enum.Font.GothamBold
	subLbl.TextScaled = true
	subLbl.Text = string.format("OWN PRIME PARK FRANCHISE FOR %d GOLD  [E]", CentralParkBranchService.BRANCH_COST)
	subLbl.TextColor3 = Color3.fromRGB(214, 184, 118)
	subLbl.Parent = sBg
	signSubLabel = subLbl

	-- Interactive ProximityPrompt on Front Counter
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CentralParkBranchPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.ActionText = "Manage Central Park Bistro"
	prompt.ObjectText = "Central Park Restaurant"
	prompt.Parent = counter
	mainPrompt = prompt

	local promptConn = prompt.Triggered:Connect(function(player: Player)
		local prof = PlayerDataService.GetProfile(player)
		local ok, msg
		if shakedownEnforcer and shakedownEnforcer.Parent then
			ok, msg = CentralParkBranchService.TryDefendShakedown(player)
		elseif not prof.OwnsCentralParkBranch then
			ok, msg = CentralParkBranchService.TryBuyBranch(player)
		else
			ok, msg = CentralParkBranchService.TryToggleStaff(player)
		end
		sendToast(player, msg)
		if onChangedCb then
			onChangedCb(player)
		end
	end)

	local sf = Instance.new("Folder")
	sf.Name = "BranchStaff"
	sf.Parent = m
	staffFolder = sf

	m.PrimaryPart = floor
	m.Parent = parentFolder
	branchModel = m
end

function CentralParkBranchService.TryBuyBranch(player: Player): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your main Restaurant Base first!"
	end
	local prof = PlayerDataService.GetProfile(player)
	if prof.OwnsCentralParkBranch then
		return true, "You already own the Central Park Bistro!"
	end
	if not PlayerDataService.SpendCoins(player, CentralParkBranchService.BRANCH_COST) then
		return false, string.format("Need %d Gold to purchase the Central Park Bistro!", CentralParkBranchService.BRANCH_COST)
	end

	local autoStaff = CrewService.GetCrewCount(player) > 0
	PlayerDataService.SetCentralParkBranch(player, true, autoStaff)
	SyndicateContractService.RecordProgress(player, "EmpireExpansion", 1)
	refreshBranchVisuals()
	if autoStaff then
		return true, "Purchased Central Park Bistro! Your Chef has been called in to cook & earn Gold!"
	end
	return true, "Purchased Central Park Bistro! Hire a Chef & Waiter, then call them to work here."
end

function CentralParkBranchService.TryToggleStaff(player: Player): (boolean, string)
	local prof = PlayerDataService.GetProfile(player)
	if not prof.OwnsCentralParkBranch then
		return false, string.format("Purchase the Central Park Bistro (%d Gold) first!", CentralParkBranchService.BRANCH_COST)
	end

	if prof.CentralParkBranchStaffed then
		PlayerDataService.SetCentralParkBranch(player, true, false)
		refreshBranchVisuals()
		return true, "Recalled your staff from Central Park Bistro."
	end

	if CrewService.GetCrewCount(player) <= 0 then
		return false, "Hire at least 1 Kitchen Chef first (Empire [U]) to work at Central Park!"
	end

	PlayerDataService.SetCentralParkBranch(player, true, true)
	refreshBranchVisuals()
	local waiterNote = if CrewService.GetWaiterCount(player) > 0
		then "Your Chef & Waiter are now serving Central Park patrons!"
		else "Your Chef is now cooking at Central Park! Hire a Waiter for +35% faster service & tips."
	return true, waiterNote
end

function CentralParkBranchService.TeleportToBranch(player: Player): (boolean, string)
	local char = player.Character
	if not char then
		return false, "Character unavailable"
	end
	local warpPos = (branchCF * CFrame.new(0, 4.5, -18)).Position
	local lookPos = (branchCF * CFrame.new(0, 4.5, 0)).Position
	pcall(function()
		player:RequestStreamAroundAsync(warpPos)
	end)
	char:PivotTo(CFrame.lookAt(warpPos, lookPos))
	return true, "Arrived at Central Park Bistro."
end

function CentralParkBranchService.TryDefendShakedown(player: Player): (boolean, string)
	if not shakedownEnforcer or not shakedownEnforcer.Parent then
		-- If not currently under shakedown, allow player to trigger an immediate Bistro Protection Patrol check or warp there!
		CentralParkBranchService.TeleportToBranch(player)
		return true, "Central Park Bistro is secure! Patrolling the terrace."
	end

	local enf = shakedownEnforcer
	shakedownEnforcer = nil
	shakedownDeadline = 0
	shakedownTargetOwner = nil
	MafiaVisualBuilder.PlayDeathSequence(enf, false, nil)
	PlayerDataService.AddRewards(player, 260, 65, 45)
	SyndicateContractService.RecordProgress(player, "EliminateHostiles", 1)
	refreshBranchVisuals()
	if onChangedCb then
		onChangedCb(player)
	end
	return true, "Defended Central Park Bistro from Syndicate Shakedown (+260 Gold & +45 Rep)!"
end

local function spawnBistroShakedown(targetOwner: Player): ()
	if shakedownEnforcer and shakedownEnforcer.Parent then
		return
	end
	local spawnCF = branchCF * CFrame.new(0, 2.8, -8.5) * CFrame.Angles(0, math.pi, 0)
	local rig = MafiaVisualBuilder.BuildRivalRig(
		"BistroExtortionEnforcer",
		"IronCleaverSyndicate",
		false,
		1.06,
		spawnCF,
		false
	)
	local model = rig.Model

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 200
	hum.Health = 200
	hum.WalkSpeed = 14
	hum.HipHeight = 2.45
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 34)
	bb.StudsOffset = Vector3.new(0, 3.1, 0)
	bb.MaxDistance = 160
	bb.Parent = rig.Head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(118, 24, 32)
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = "BISTRO EXTORTIONIST  |  SHAKEDOWN"
	lbl.TextSize = 10
	lbl.TextColor3 = Color3.fromRGB(242, 236, 226)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)

	model.PrimaryPart = rig.Root
	model:SetAttribute("Faction", "Rival")
	model:SetAttribute("RivalTitle", "BISTRO EXTORTIONIST")
	model:SetAttribute("BountyGold", 260)
	model:SetAttribute("BountyExp", 65)
	model:SetAttribute("BountyRep", 45)
	CollectionService:AddTag(model, "RivalAIUnit")
	model.Parent = branchModel or Workspace

	shakedownEnforcer = model
	shakedownTargetOwner = targetOwner
	shakedownDeadline = os.clock() + 26

	if signSubLabel then
		signSubLabel.Text = "UNDER SYNDICATE SHAKEDOWN  |  DEFEND BISTRO [E] (+260G)"
		signSubLabel.TextColor3 = Color3.fromRGB(232, 92, 98)
	end

	hum.Died:Connect(function()
		if shakedownEnforcer == model then
			shakedownEnforcer = nil
			shakedownDeadline = 0
			local owner = shakedownTargetOwner
			shakedownTargetOwner = nil
			MafiaVisualBuilder.PlayDeathSequence(model, false, nil)
			if owner and owner.Parent then
				PlayerDataService.AddRewards(owner, 260, 65, 45)
				SyndicateContractService.RecordProgress(owner, "EliminateHostiles", 1)
				sendToast(owner, "Central Park Bistro Shakedown repelled! (+260 Gold & +45 Rep)")
				if onChangedCb then onChangedCb(owner) end
			end
			refreshBranchVisuals()
		end
	end)

	sendToast(targetOwner, "ALERT: Syndicate Extortionist is shaking down your Central Park Bistro! Defend it for +260G!")
	if onChangedCb then
		onChangedCb(targetOwner)
	end
end

function CentralParkBranchService.GetSnapshot(player: Player): { [string]: any }
	local prof = PlayerDataService.GetProfile(player)
	local underShakedown = shakedownEnforcer ~= nil and (shakedownEnforcer :: Model).Parent ~= nil
	local rem = if underShakedown then math.max(0, math.ceil(shakedownDeadline - os.clock())) else 0
	return {
		Owned = prof.OwnsCentralParkBranch == true,
		Staffed = prof.CentralParkBranchStaffed == true,
		Cost = CentralParkBranchService.BRANCH_COST,
		UnderShakedown = underShakedown,
		ShakedownTimeLeft = rem,
	}
end

function CentralParkBranchService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	buildCentralParkBistroMonument()
	refreshBranchVisuals()

	local tableCycle = 0
	local shakedownCycle = 0
	loopThread = task.spawn(function()
		while isRunning do
			task.wait(SERVE_TICK_SECONDS)
			if not isRunning then
				break
			end

			-- Resolve expired shakedown or trigger periodic shakedown every 5 ticks (~42s) when staffed
			if shakedownEnforcer and shakedownEnforcer.Parent then
				if os.clock() >= shakedownDeadline then
					local enf = shakedownEnforcer
					local victim = shakedownTargetOwner
					shakedownEnforcer = nil
					shakedownDeadline = 0
					shakedownTargetOwner = nil
					if enf.Parent then enf:Destroy() end
					if victim and victim.Parent then
						PlayerDataService.SpendCoins(victim, math.min(95, PlayerDataService.GetProfile(victim).Coins))
						sendToast(victim, "Bistro Extortionist stole -95G from Central Park Bistro! Station Bodyguards or defend next time.")
						if onChangedCb then onChangedCb(victim) end
					end
				end
			else
				shakedownCycle += 1
				if shakedownCycle >= 5 then
					shakedownCycle = 0
					for _, p in ipairs(Players:GetPlayers()) do
						local prof = PlayerDataService.GetProfile(p)
						if prof.OwnsCentralParkBranch and prof.CentralParkBranchStaffed and CrewService.GetCrewCount(p) > 0 then
							spawnBistroShakedown(p)
							break
						end
					end
				end
			end

			refreshBranchVisuals()
			tableCycle = (tableCycle % #PATIO_TABLE_OFFSETS) + 1

			-- Animate Central Park Waiter walking between counter & patio tables!
			if activeWaiterHum and activeWaiterRoot and activeWaiterModel and activeWaiterModel.Parent then
				local targetTable = (branchCF * CFrame.new(PATIO_TABLE_OFFSETS[tableCycle] + Vector3.new(0, 2.8, 2.0))).Position
				local passPos = (branchCF * CFrame.new(2.5, 2.8, -5.0)).Position
				if activeWaiterLabel then
					activeWaiterLabel.Text = "PARK WAITER  |  SERVING TABLE #" .. tostring(tableCycle)
				end
				activeWaiterHum:MoveTo(targetTable)
				task.delay(3.2, function()
					if activeWaiterHum and activeWaiterModel and activeWaiterModel.Parent then
						activeWaiterHum:MoveTo(passPos)
					end
				end)
			end

			-- Pay live Central Park Bistro revenue to every player who owns & staffed the branch!
			local eventCoinsAttr = ReplicatedStorage:GetAttribute("ActiveEventCoinsMult")
			local eventRepAttr = ReplicatedStorage:GetAttribute("ActiveEventRepMult")
			local eventCoinsMult = (if typeof(eventCoinsAttr) == "number" then eventCoinsAttr else 1.0) * (if ReplicatedStorage:GetAttribute("IsNight") == true then 1.35 else 1.0)
			local eventRepMult = if typeof(eventRepAttr) == "number" then eventRepAttr else 1.0

			for _, player in ipairs(Players:GetPlayers()) do
				local prof = PlayerDataService.GetProfile(player)
				local chefs = CrewService.GetCrewCount(player)
				if prof.OwnsCentralParkBranch and prof.CentralParkBranchStaffed and chefs > 0 then
					local waiters = CrewService.GetWaiterCount(player)
					-- Optionally pull 1 available warehouse ingredient for a +40% specialty menu bonus!
					local specialtyBonus = 1.0
					local snap = WarehouseService.GetInventorySnapshot(player)
					for _, cat in ipairs(WarehouseConfig.Categories) do
						local spec = WarehouseConfig.Specs[cat]
						for _, ing in ipairs(spec.Ingredients) do
							if (snap.Stock[ing] or 0) >= 1 and ing ~= "golden_tuna" and ing ~= "king_crab" then
								if WarehouseService.ConsumeIngredients(player, { [ing] = 1 }) then
									specialtyBonus = 1.40
									break
								end
							end
						end
						if specialtyBonus > 1.0 then break end
					end

					local waiterBonus = 1.0 + waiters * 0.25
					local hqBonus = 1.0 + (prof.RestaurantLevel - 1) * 0.14
					local chefBonus = 1.0 + (chefs - 1) * 0.15
					local passCoins = MonetizationService.GetPayoutMultiplier(player)
					local passRep = MonetizationService.GetRepMultiplier(player)

					local gold = math.floor(72 * specialtyBonus * waiterBonus * hqBonus * chefBonus * eventCoinsMult * passCoins)
					local rep = math.floor(14 * waiterBonus * eventRepMult * passRep)
					local exp = math.floor(gold * 0.22)
					PlayerDataService.AddRewards(player, gold, exp, rep)
					if onChangedCb then
						onChangedCb(player)
					end
				end
			end
		end
	end)

	print("[Food Empire] CentralParkBranchService started (Ownable Central Park Bistro + Callable Chef/Waiter active)!")
end

function CentralParkBranchService.Stop(): ()
	isRunning = false
	if loopThread then task.cancel(loopThread); loopThread = nil end
	if promptConn then promptConn:Disconnect(); promptConn = nil end
	clearBranchStaffVisuals()
	if branchModel and branchModel.Parent then
		branchModel:Destroy()
	end
	branchModel = nil
end

return CentralParkBranchService
