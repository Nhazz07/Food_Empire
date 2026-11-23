--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local WarehouseService = require("./WarehouseService")
local PlayerDataService = require("./PlayerDataService")
local MonetizationService = require("./MonetizationService")

export type ShipmentPhase = "Loading" | "EnRoute" | "Arrived"

export type ShipmentStatus = {
	SectorId: string,
	DisplayName: string,
	Category: WarehouseConfig.WarehouseCategory,
	Phase: ShipmentPhase,
	SecondsUntilNext: number,
	BayPosition: Vector3,
}

type CornerRoute = {
	SectorId: string,
	DisplayName: string,
	Category: WarehouseConfig.WarehouseCategory,
	OriginPos: Vector3,
	MidPos: Vector3,
	BayPos: Vector3,
	InitialDelay: number,
}

type ActiveShipmentState = {
	Route: CornerRoute,
	Phase: ShipmentPhase,
	NextDispatchAt: number,
	CycleDuration: number,
	CartModel: Model?,
	CrateModel: Model?,
	CratePromptConn: RBXScriptConnection?,
}

local ShipmentService = {}

local CYCLE_SECONDS = 24
local TRANSIT_SECONDS = 8.5
local CLAIM_PER_ITEM = 6 -- +6 of all 3 category ingredients = +18 total stock!
local CLAIM_BONUS_GOLD = 20
local CLAIM_BONUS_EXP = 12

local ROUTES: { CornerRoute } = {
	{
		SectorId = "FishingPort",
		DisplayName = "Fishing Port",
		Category = "Fish",
		OriginPos = Vector3.new(752, 2.2, 797),
		MidPos = Vector3.new(490, 2.2, 490),
		BayPos = Vector3.new(66, 2.2, 66),
		InitialDelay = 4, -- First Fish shipment goes out almost right away!
	},
	{
		SectorId = "VegetableFarm",
		DisplayName = "Vegetable Farm",
		Category = "Vegetable",
		OriginPos = Vector3.new(-725, 2.2, -725),
		MidPos = Vector3.new(-490, 2.2, -490),
		BayPos = Vector3.new(-66, 2.2, -66),
		InitialDelay = 10,
	},
	{
		SectorId = "FruitOrchard",
		DisplayName = "Fruit Orchard",
		Category = "Fruit",
		OriginPos = Vector3.new(-725, 2.2, 725),
		MidPos = Vector3.new(-490, 2.2, 490),
		BayPos = Vector3.new(-66, 2.2, 66),
		InitialDelay = 16,
	},
	{
		SectorId = "Ranch",
		DisplayName = "Ranch Territory",
		Category = "Meat",
		OriginPos = Vector3.new(725, 2.2, -725),
		MidPos = Vector3.new(490, 2.2, -490),
		BayPos = Vector3.new(66, 2.2, -66),
		InitialDelay = 22,
	},
}

local statesBySector: { [string]: ActiveShipmentState } = {}
local isRunning = false
local mainThread: thread? = nil
local shipmentFolder: Folder? = nil
local onChangedCallbacks: { () -> () } = {}

local function sendToast(player: Player, msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg)
	end
end

local function notifyChanged(): ()
	for _, cb in ipairs(onChangedCallbacks) do
		task.spawn(cb)
	end
end

function ShipmentService.OnShipmentsChanged(cb: () -> ()): () -> ()
	table.insert(onChangedCallbacks, cb)
	return function()
		local idx = table.find(onChangedCallbacks, cb)
		if idx then
			table.remove(onChangedCallbacks, idx)
		end
	end
end

local function updateCornerVisuals(st: ActiveShipmentState): ()
	local spec = WarehouseConfig.Specs[st.Route.Category]
	local accent = if spec then spec.AccentColor else Color3.fromRGB(246, 196, 56)
	local neutralCol = Color3.fromRGB(154, 166, 184)
	local now = os.clock()
	local rem = math.max(0, math.ceil(st.NextDispatchAt - now))
	local fillFrac = if st.Phase == "Loading"
		then math.clamp(1 - (rem / math.max(1, st.CycleDuration)), 0, 1)
		else 1

	local statusText = if st.Phase == "EnRoute"
		then "SHIPMENT GOING OUT -> CENTER!"
		elseif st.Phase == "Arrived" then "SHIPMENT AT CENTRAL PLAZA!"
		else string.format("NEUTRAL HUB  •  NEXT SHIPMENT: %ds", rem)

	local pillColor = if st.Phase == "EnRoute"
		then Color3.fromRGB(246, 168, 32)
		elseif st.Phase == "Arrived" then accent
		else neutralCol

	for _, root in ipairs(CollectionService:GetTagged("SectorVisualRoot")) do
		if root:GetAttribute("SectorId") == st.Route.SectorId then
			local rig = root:FindFirstChild("TerritoryCaptureRig") or root
			-- Keep neutral zone ring neutral while loading, glowing accent/gold when dispatching!
			for _, desc in ipairs(rig:GetDescendants()) do
				if desc:IsA("BasePart") and CollectionService:HasTag(desc, "TeamColorPart") then
					desc.Color = pillColor
				end
			end

			local bb = rig:FindFirstChild("SectorBillboard", true)
			if bb and bb:IsA("BillboardGui") then
				local nameLbl = bb:FindFirstChild("SectorName")
				if nameLbl and nameLbl:IsA("TextLabel") then
					nameLbl.Text = string.upper(st.Route.DisplayName) .. " (NEUTRAL)"
				end
				local ownLbl = bb:FindFirstChild("SectorOwner")
				if ownLbl and ownLbl:IsA("TextLabel") then
					ownLbl.Text = statusText
					ownLbl.BackgroundColor3 = pillColor
				end
				local bar = bb:FindFirstChild("ProgressBar")
				local fill = if bar then bar:FindFirstChild("ProgressFill") else nil
				if fill and fill:IsA("Frame") then
					fill.Size = UDim2.new(fillFrac, 0, 1, 0)
					fill.BackgroundColor3 = if st.Phase == "Loading" then accent else Color3.fromRGB(255, 224, 96)
				end
			end

			-- Show tall vertical glowing Dispatch Sky-Beacon while a shipment is leaving so players see it from across the island!
			local beacon = rig:FindFirstChild("CornerDispatchBeacon")
			if st.Phase == "EnRoute" then
				if not beacon then
					local zone = rig:FindFirstChild("CaptureZone")
					local bPos = if zone and zone:IsA("BasePart") then zone.Position else st.Route.OriginPos
					local beam = Instance.new("Part")
					beam.Name = "CornerDispatchBeacon"
					beam.Shape = Enum.PartType.Cylinder
					beam.Size = Vector3.new(95, 5.5, 5.5)
					beam.CFrame = CFrame.new(bPos.X, 48, bPos.Z) * CFrame.Angles(0, 0, math.rad(90))
					beam.Color = accent
					beam.Material = Enum.Material.Neon
					beam.Transparency = 0.45
					beam.Anchored = true
					beam.CanCollide = false
					beam.CanTouch = false
					beam.CanQuery = false
					beam.CastShadow = false
					beam.Parent = rig
				end
			elseif beacon then
				beacon:Destroy()
			end
		end
	end
end

local function clearCrate(st: ActiveShipmentState): ()
	if st.CratePromptConn then
		st.CratePromptConn:Disconnect()
		st.CratePromptConn = nil
	end
	if st.CrateModel and st.CrateModel.Parent then
		st.CrateModel:Destroy()
	end
	st.CrateModel = nil
end

local function clearCart(st: ActiveShipmentState): ()
	if st.CartModel and st.CartModel.Parent then
		st.CartModel:Destroy()
	end
	st.CartModel = nil
end

local function buildShipmentTruck(route: CornerRoute): Model
	local spec = WarehouseConfig.Specs[route.Category]
	local accent = spec.AccentColor
	local truck = Instance.new("Model")
	truck.Name = "OutboundShipment_" .. route.Category

	local cf = CFrame.lookAt(route.OriginPos, route.MidPos)
	local function tPart(name: string, sz: Vector3, rel: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = cf * rel
		p.Color = col
		p.Material = mat
		if shape then p.Shape = shape end
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Parent = truck
		return p
	end

	-- Stylized Cargo Delivery Cart loaded with glowing crates!
	local chassis = tPart("Chassis", Vector3.new(5.2, 1.2, 10.0), CFrame.new(0, 1.4, 0), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, nil)
	tPart("Cab", Vector3.new(4.8, 3.6, 3.4), CFrame.new(0, 3.6, -3.2), accent, Enum.Material.SmoothPlastic, nil)
	tPart("Windshield", Vector3.new(4.2, 1.6, 0.3), CFrame.new(0, 4.1, -4.95), Color3.fromRGB(168, 224, 248), Enum.Material.Glass, nil)
	tPart("Headlights", Vector3.new(4.4, 0.7, 0.3), CFrame.new(0, 2.3, -5.05), Color3.fromRGB(255, 242, 168), Enum.Material.Neon, nil)
	-- Stacked Supply Crates on Flatbed
	tPart("CargoCrate1", Vector3.new(4.4, 2.8, 4.6), CFrame.new(0, 3.4, 1.8), accent, Enum.Material.WoodPlanks, nil)
	tPart("CargoCrate2", Vector3.new(3.6, 1.8, 3.6), CFrame.new(0, 5.6, 1.8), Color3.fromRGB(246, 206, 86), Enum.Material.WoodPlanks, nil)
	-- 4 Wheels
	for _, wx in ipairs({ -2.7, 2.7 }) do
		for _, wz in ipairs({ -3.2, 3.0 }) do
			tPart("Wheel", Vector3.new(0.9, 2.2, 2.2), CFrame.new(wx, 1.1, wz), Color3.fromRGB(26, 28, 34), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	end

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(230, 36)
	bb.StudsOffset = Vector3.new(0, 7.2, 0)
	bb.MaxDistance = 260
	bb.Parent = chassis
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(22, 28, 42)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = string.format("%s %s SHIPMENT -> CENTER", spec.Icon, spec.ShortLabel)
	lbl.TextSize = 13
	lbl.TextColor3 = Color3.fromRGB(255, 232, 118)
	lbl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 7)
	c.Parent = lbl
	local st = Instance.new("UIStroke")
	st.Color = accent
	st.Thickness = 2
	st.Parent = lbl

	truck.PrimaryPart = chassis
	truck.Parent = shipmentFolder or Workspace
	return truck
end

local function claimShipmentForPlayer(st: ActiveShipmentState, player: Player, byRaider: boolean): boolean
	if st.Phase ~= "Arrived" or not st.CrateModel then
		return false
	end

	local cat = st.Route.Category
	local spec = WarehouseConfig.Specs[cat]
	if not WarehouseService.IsUnlocked(player, cat) then
		if not byRaider then
			sendToast(player, string.format("Build %s (%d Gold) in Storage (B) to claim %s Shipments!", spec.DisplayName, spec.UnlockCost, spec.ShortLabel))
		end
		return false
	end

	local mult = MonetizationService.GetDeliveryMultiplier(player)
	local totalAdded = 0
	local parts: { string } = {}
	for _, ing in ipairs(spec.Ingredients) do
		-- Keep rare pier catches exclusive to the Fishing Port Mini-Game!
		if ing ~= "golden_tuna" and ing ~= "king_crab" then
			local added = WarehouseService.AddIngredient(player, ing, CLAIM_PER_ITEM * mult)
			if added > 0 then
				totalAdded += added
				table.insert(parts, string.format("+%d %s", added, ing))
			end
		end
	end

	if totalAdded <= 0 then
		if not byRaider then
			sendToast(player, string.format("%s is FULL! Upgrade it or cook dishes first!", spec.DisplayName))
		end
		return false
	end

	clearCrate(st)
	st.Phase = "Loading"
	st.NextDispatchAt = os.clock() + st.CycleDuration

	PlayerDataService.AddRewards(player, CLAIM_BONUS_GOLD, CLAIM_BONUS_EXP, 4)
	local prefix = if byRaider then "Raider Chef claimed " else "Claimed "
	sendToast(player, string.format("%s %s%s Shipment (%s, +%dG)!", spec.Icon, prefix, spec.ShortLabel, table.concat(parts, ", "), CLAIM_BONUS_GOLD))

	updateCornerVisuals(st)
	notifyChanged()
	return true
end

local function spawnArrivedCrate(st: ActiveShipmentState): ()
	clearCrate(st)
	local spec = WarehouseConfig.Specs[st.Route.Category]
	local accent = spec.AccentColor
	local bayPos = st.Route.BayPos

	local crateModel = Instance.new("Model")
	crateModel.Name = "CentralShipmentCrate_" .. st.Route.Category

	local box = Instance.new("Part")
	box.Name = "CrateBody"
	box.Size = Vector3.new(6.0, 4.6, 6.0)
	box.CFrame = CFrame.new(bayPos.X, 3.9, bayPos.Z)
	box.Color = accent
	box.Material = Enum.Material.WoodPlanks
	box.Anchored = true
	box.CanCollide = true
	box.Parent = crateModel

	local band = Instance.new("Part")
	band.Name = "GoldBand"
	band.Size = Vector3.new(6.3, 0.8, 6.3)
	band.CFrame = box.CFrame
	band.Color = Color3.fromRGB(255, 214, 62)
	band.Material = Enum.Material.Neon
	band.Anchored = true
	band.CanCollide = false
	band.Parent = crateModel

	local light = Instance.new("PointLight")
	light.Color = accent
	light.Brightness = 2.0
	light.Range = 28
	light.Shadows = false
	light.Parent = box

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 42)
	bb.StudsOffset = Vector3.new(0, 4.8, 0)
	bb.MaxDistance = 220
	bb.Parent = box
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(20, 28, 42)
	lbl.BackgroundTransparency = 0.06
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = string.format("%s %s SHIPMENT READY! [E]", spec.Icon, spec.ShortLabel)
	lbl.TextSize = 13
	lbl.TextColor3 = Color3.fromRGB(134, 248, 168)
	lbl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = lbl

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ClaimShipmentPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.ActionText = string.format("Claim %s Shipment (+18 Stock)", spec.ShortLabel)
	prompt.ObjectText = "Central Shipment Bay"
	prompt.Parent = box

	st.CratePromptConn = prompt.Triggered:Connect(function(player)
		claimShipmentForPlayer(st, player, false)
	end)

	crateModel.PrimaryPart = box
	crateModel.Parent = shipmentFolder or Workspace
	st.CrateModel = crateModel
end

local function dispatchShipment(st: ActiveShipmentState): ()
	clearCrate(st)
	clearCart(st)
	st.Phase = "EnRoute"
	updateCornerVisuals(st)
	notifyChanged()

	local truck = buildShipmentTruck(st.Route)
	st.CartModel = truck

	task.spawn(function()
		local p0 = st.Route.OriginPos
		local p1 = st.Route.MidPos
		local p2 = st.Route.BayPos
		local steps = 68
		local dt = TRANSIT_SECONDS / steps

		for i = 1, steps do
			if not isRunning or not truck.Parent then
				return
			end
			local t = i / steps
			local pos: Vector3
			local nextPos: Vector3
			if t <= 0.5 then
				local a = t * 2
				pos = p0:Lerp(p1, a)
				nextPos = p0:Lerp(p1, math.min(1, a + 0.04))
			else
				local a = (t - 0.5) * 2
				pos = p1:Lerp(p2, a)
				nextPos = p1:Lerp(p2, math.min(1, a + 0.04))
			end
			if (nextPos - pos).Magnitude > 0.05 then
				truck:PivotTo(CFrame.lookAt(pos, nextPos))
			end
			task.wait(dt)
		end

		if not isRunning then
			return
		end
		clearCart(st)
		st.Phase = "Arrived"
		spawnArrivedCrate(st)
		updateCornerVisuals(st)
		notifyChanged()
	end)
end

-- Allows player Raider Chefs patrolling the Central District to collect arrived shipments for their owner!
function ShipmentService.TryRaiderClaimAtPosition(owner: Player, worldPos: Vector3): boolean
	for _, st in pairs(statesBySector) do
		if st.Phase == "Arrived" and (st.Route.BayPos - worldPos).Magnitude <= 14 then
			if claimShipmentForPlayer(st, owner, true) then
				return true
			end
		end
	end
	return false
end

-- Allows enemy Rival Chefs to steal/sabotage an unclaimed Central Shipment if left unguarded!
function ShipmentService.TryRivalInterceptAtPosition(worldPos: Vector3): boolean
	for _, st in pairs(statesBySector) do
		if st.Phase == "Arrived" and (st.Route.BayPos - worldPos).Magnitude <= 12 then
			clearCrate(st)
			st.Phase = "Loading"
			st.NextDispatchAt = os.clock() + st.CycleDuration
			updateCornerVisuals(st)
			notifyChanged()
			for _, p in ipairs(Players:GetPlayers()) do
				sendToast(p, string.format("Rival Chef stole the %s Shipment in Central Plaza!", st.Route.Category))
			end
			return true
		end
	end
	return false
end

function ShipmentService.GetBestActiveShipmentPosition(preferCategory: WarehouseConfig.WarehouseCategory?): Vector3?
	if preferCategory then
		for _, st in pairs(statesBySector) do
			if st.Route.Category == preferCategory and st.Phase == "Arrived" then
				return st.Route.BayPos
			end
		end
	end
	for _, st in pairs(statesBySector) do
		if st.Phase == "Arrived" then
			return st.Route.BayPos
		end
	end
	for _, st in pairs(statesBySector) do
		if st.Phase == "EnRoute" then
			return st.Route.BayPos
		end
	end
	return Vector3.new(0, 4, 0)
end

function ShipmentService.GetSnapshot(): { [string]: any }
	local now = os.clock()
	local out: { [string]: any } = {}
	for sectorId, st in pairs(statesBySector) do
		out[sectorId] = {
			SectorId = sectorId,
			DisplayName = st.Route.DisplayName,
			Category = st.Route.Category,
			Phase = st.Phase,
			SecondsUntilNext = if st.Phase == "Loading" then math.max(0, math.ceil(st.NextDispatchAt - now)) else 0,
			BayX = st.Route.BayPos.X,
			BayZ = st.Route.BayPos.Z,
		}
	end
	return out
end

function ShipmentService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local existing = Workspace:FindFirstChild("LiveShipments")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		shipmentFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "LiveShipments"
		f.Parent = Workspace
		shipmentFolder = f
	end

	local now = os.clock()
	for _, route in ipairs(ROUTES) do
		local st: ActiveShipmentState = {
			Route = route,
			Phase = "Loading",
			NextDispatchAt = now + route.InitialDelay,
			CycleDuration = CYCLE_SECONDS,
			CartModel = nil,
			CrateModel = nil,
			CratePromptConn = nil,
		}
		statesBySector[route.SectorId] = st
		updateCornerVisuals(st)
	end

	mainThread = task.spawn(function()
		while isRunning do
			task.wait(1.0)
			if not isRunning then
				break
			end
			local t = os.clock()
			for _, st in pairs(statesBySector) do
				if st.Phase == "Loading" then
					if t >= st.NextDispatchAt then
						dispatchShipment(st)
					else
						updateCornerVisuals(st)
					end
				end
			end
			notifyChanged()
		end
	end)

	print("[Food Empire] ShipmentService started (4 True Neutral Corners dispatching live 3D shipments to Expanded Center)!")
end

function ShipmentService.Stop(): ()
	isRunning = false
	if mainThread then
		task.cancel(mainThread)
		mainThread = nil
	end
	for _, st in pairs(statesBySector) do
		clearCrate(st)
		clearCart(st)
	end
	table.clear(statesBySector)
	if shipmentFolder then
		shipmentFolder:ClearAllChildren()
	end
end

return ShipmentService
