--!strict

-- DeliveryRunnerService:
--  1. Hireable Autonomous Motorbike Supply Couriers (up to 2 per player):
--     Drives a real 3D Delivery Motorbike from your Base -> Central Market Shipment Bay -> loads visible
--     ingredient crate onto rear rack -> drives back to your Warehouse -> stores fresh ingredients!
--  2. Manual Central Park Stealth Courier Dispatch (upgraded onto a real 3D Motorbike!).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
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
local MonetizationService = require("./MonetizationService")
local SyndicateContractService = require("./SyndicateContractService")

type DeliveryTarget = {
	Name: string,
	Pos: Vector3,
}

type RunnerSession = {
	Owner: Player,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	StatusLabel: TextLabel,
	Target: DeliveryTarget,
	SpottedWarned: boolean,
}

type CourierPhase = "ToMarket" | "Loading" | "ToWarehouse" | "Storing"

type SupplyCourier = {
	Owner: Player,
	SlotIndex: number,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	CratePart: BasePart,
	StatusLabel: TextLabel,
	Phase: CourierPhase,
	Category: WarehouseConfig.WarehouseCategory,
	PhaseUntil: number,
	StuckTicks: number,
	LastPos: Vector3,
}

local DeliveryRunnerService = {}

DeliveryRunnerService.MAX_COURIERS = 2
DeliveryRunnerService.COURIER_COSTS = { [1] = 1500, [2] = 2700 }

local COOLDOWN_SECONDS = 15
local RUNNER_MAX_HP = 180
local BIKE_COURIER_SPEED = 29.0
local BASE_PAYOUT_GOLD = 95
local BASE_PAYOUT_REP = 24
local BASE_PAYOUT_EXP = 45
local COURIER_STOCK_PER_TRIP = 5

local CENTRAL_MARKET_BAYS: { [WarehouseConfig.WarehouseCategory]: Vector3 } = {
	Fish = Vector3.new(66, 4.5, 66),
	Meat = Vector3.new(66, 4.5, -66),
	Vegetable = Vector3.new(-66, 4.5, -66),
	Fruit = Vector3.new(-66, 4.5, 66),
}

local CENTRAL_PARK_TARGETS: { DeliveryTarget } = {
	{ Name = "Central Park Fountain", Pos = Vector3.new(0, 4.5, 24) },
	{ Name = "Central Park North Lawn", Pos = Vector3.new(0, 4.5, -52) },
	{ Name = "Central Park Cherry Bench", Pos = Vector3.new(-78, 4.5, 78) },
	{ Name = "Central Park East Garden", Pos = Vector3.new(78, 4.5, -78) },
	{ Name = "Central Park West Plaza", Pos = Vector3.new(-78, 4.5, -22) },
}

local isRunning = false
local runnerFolder: Folder? = nil
local activeRunners: { [Player]: RunnerSession } = {}
local supplyCouriers: { [Player]: { SupplyCourier } } = {}
local courierRespawnUntil: { [Player]: { [number]: number } } = {}
local lastDispatchAt: { [Player]: number } = {}
local aiThread: thread? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local unsubBase: (() -> ())? = nil

local function sendToast(player: Player, msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg)
	end
end

local function clearRunner(player: Player): ()
	local s = activeRunners[player]
	if s then
		if s.Model.Parent then
			s.Model:Destroy()
		end
		activeRunners[player] = nil
	end
end

local function clearSupplyCouriers(player: Player): ()
	local list = supplyCouriers[player]
	if list then
		for _, c in ipairs(list) do
			if c.Model.Parent then
				c.Model:Destroy()
			end
		end
		supplyCouriers[player] = nil
	end
	courierRespawnUntil[player] = nil
end

local function getFrontGateSpawn(player: Player, sideOffset: number?): Vector3
	local slot = BaseService.GetPlayerBaseSlot(player)
	if slot then
		local base = BaseService.GetBaseModel(slot)
		local bp = if base then (base:FindFirstChild("BasePivot") or base.PrimaryPart) else nil
		if bp and bp:IsA("BasePart") then
			return (bp.CFrame * CFrame.new(sideOffset or 0, 4.5, 114)).Position
		end
	end
	return Vector3.new(sideOffset or 0, 4.5, 220)
end

local function getWarehouseDoorPos(player: Player, category: WarehouseConfig.WarehouseCategory): Vector3
	local slot = BaseService.GetPlayerBaseSlot(player)
	if slot then
		for _, plot in ipairs(CollectionService:GetTagged("WarehousePlot")) do
			if plot:GetAttribute("BaseSlot") == slot and plot:GetAttribute("Category") == category then
				local door = plot:FindFirstChild("CargoDoor", true)
				if door and door:IsA("BasePart") then
					return Vector3.new(door.Position.X, 4.5, door.Position.Z)
				end
				local piv = plot:FindFirstChild("PlotPivot")
				if piv and piv:IsA("BasePart") then
					return Vector3.new(piv.Position.X, 4.5, piv.Position.Z)
				end
			end
		end
	end
	return getFrontGateSpawn(player, 0)
end

-- Pick the unlocked Warehouse category with the lowest stock ratio so couriers automatically keep ALL warehouses supplied!
local function pickBestCategoryToRestock(player: Player, slotIndex: number): WarehouseConfig.WarehouseCategory
	local snap = WarehouseService.GetInventorySnapshot(player)
	local bestCat: WarehouseConfig.WarehouseCategory = "Fish"
	local bestRatio = math.huge
	local unlocked: { WarehouseConfig.WarehouseCategory } = {}

	for _, cat in ipairs(WarehouseConfig.Categories) do
		if (snap.Levels[cat] or 0) >= 1 then
			table.insert(unlocked, cat)
			local cap = math.max(1, snap.Capacities[cat] or 25)
			local ratio = (snap.CategoryTotals[cat] or 0) / cap
			if ratio < bestRatio then
				bestRatio = ratio
				bestCat = cat
			end
		end
	end

	-- If player has 2 couriers and multiple unlocked categories, stagger slot #2 to diversify!
	if slotIndex == 2 and #unlocked >= 2 then
		for _, cat in ipairs(unlocked) do
			if cat ~= bestCat then
				return cat
			end
		end
	end
	return bestCat
end

local function buildBikeCourierNPC(
	owner: Player,
	modelName: string,
	spawnPos: Vector3,
	titleText: string
): (Model, Humanoid, BasePart, BasePart, TextLabel)
	local slot = BaseService.GetPlayerBaseSlot(owner)
	local teamCol = if slot and SectorConfig.FactionColors[slot]
		then SectorConfig.FactionColors[slot]
		else Color3.fromRGB(168, 138, 76)

	local rig, cratePart = MafiaVisualBuilder.BuildMotorbikeCourierRig(modelName, teamCol, 1.0, CFrame.new(spawnPos))
	local model = rig.Model
	local root = rig.Root
	local head = rig.Head

	local bb = Instance.new("BillboardGui")
	bb.Name = "CourierBadge"
	bb.Size = UDim2.fromOffset(224, 42)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.MaxDistance = 220
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 22)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = titleText
	lbl.TextSize = 10
	lbl.TextColor3 = Color3.fromRGB(224, 198, 134)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(64, 68, 78)
	st.Thickness = 1.1
	st.Parent = lbl

	local hpBg = Instance.new("Frame")
	hpBg.Position = UDim2.new(0.06, 0, 0, 26)
	hpBg.Size = UDim2.new(0.88, 0, 0, 10)
	hpBg.BackgroundColor3 = Color3.fromRGB(14, 15, 19)
	hpBg.Parent = bb
	Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 3)

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(72, 134, 92)
	hpFill.Parent = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = RUNNER_MAX_HP
	hum.Health = RUNNER_MAX_HP
	hum.WalkSpeed = BIKE_COURIER_SPEED
	hum.HipHeight = 3.45
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	hum.HealthChanged:Connect(function(hp: number)
		local frac = math.clamp(hp / math.max(1, hum.MaxHealth), 0, 1)
		hpFill.Size = UDim2.fromScale(frac, 1)
		hpFill.BackgroundColor3 = if frac > 0.5
			then Color3.fromRGB(72, 134, 92)
			elseif frac > 0.25 then Color3.fromRGB(178, 140, 58)
			else Color3.fromRGB(154, 34, 42)
	end)

	model.PrimaryPart = root
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("Faction", "Player_" .. tostring(owner.UserId))
	CollectionService:AddTag(model, "PlayerDeliveryRunner")
	model.Parent = runnerFolder or Workspace

	return model, hum, root, cratePart, lbl
end

function DeliveryRunnerService.GetCourierCount(player: Player): number
	return PlayerDataService.GetProfile(player).CourierCount
end

function DeliveryRunnerService.GetNextCourierCost(player: Player): number?
	local count = DeliveryRunnerService.GetCourierCount(player)
	if count >= DeliveryRunnerService.MAX_COURIERS then
		return nil
	end
	return DeliveryRunnerService.COURIER_COSTS[count + 1] or 540
end

function DeliveryRunnerService.SyncCouriersForPlayer(player: Player): ()
	if not BaseService.GetPlayerBaseSlot(player) then
		return
	end
	local count = DeliveryRunnerService.GetCourierCount(player)
	if count <= 0 then
		clearSupplyCouriers(player)
		return
	end

	local list = supplyCouriers[player]
	if not list then
		list = {}
		supplyCouriers[player] = list
	end

	for i = #list, 1, -1 do
		if not list[i].Model.Parent or list[i].Humanoid.Health <= 0 then
			table.remove(list, i)
		end
	end

	local now = os.clock()
	local cdMap = courierRespawnUntil[player]
	for slotIdx = 1, math.min(count, DeliveryRunnerService.MAX_COURIERS) do
		local exists = false
		for _, c in ipairs(list) do
			if c.SlotIndex == slotIdx then
				exists = true
				break
			end
		end
		if not exists then
			if cdMap and (cdMap[slotIdx] or 0) > now then
				continue
			end
			local cat = pickBestCategoryToRestock(player, slotIdx)
			local spawnPos = getFrontGateSpawn(player, if slotIdx == 1 then -8 else 8)
			local model, hum, root, cratePart, lbl = buildBikeCourierNPC(
				player,
				string.format("MotorbikeCourier_%d_%d", player.UserId, slotIdx),
				spawnPos,
				string.format("MOTO COURIER #%d  |  TO MARKET", slotIdx)
			)

			local courier: SupplyCourier = {
				Owner = player,
				SlotIndex = slotIdx,
				Model = model,
				Humanoid = hum,
				Root = root,
				CratePart = cratePart,
				StatusLabel = lbl,
				Phase = "ToMarket",
				Category = cat,
				PhaseUntil = 0,
				StuckTicks = 0,
				LastPos = spawnPos,
			}

			hum.Died:Connect(function()
				local map = courierRespawnUntil[player]
				if not map then
					map = {}
					courierRespawnUntil[player] = map
				end
				map[slotIdx] = os.clock() + 12
				MafiaVisualBuilder.PlayDeathSequence(model, false, nil)
				sendToast(player, string.format("Motorbike Courier #%d was ambushed! Respawning in 12s.", slotIdx))
			end)

			table.insert(list, courier)
		end
	end
end

function DeliveryRunnerService.TryHireCourier(player: Player, bypassGold: boolean?): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Restaurant Plaza first!"
	end
	local current = DeliveryRunnerService.GetCourierCount(player)
	local cost = DeliveryRunnerService.GetNextCourierCost(player)
	if not cost then
		return false, string.format("Max Motorbike Couriers hired (%d / %d)!", DeliveryRunnerService.MAX_COURIERS, DeliveryRunnerService.MAX_COURIERS)
	end
	if not bypassGold and not PlayerDataService.SpendCoins(player, cost) then
		return false, string.format("Need %d Gold to hire Motorbike Courier #%d!", cost, current + 1)
	end

	PlayerDataService.SetCourierCount(player, current + 1)
	DeliveryRunnerService.SyncCouriersForPlayer(player)
	return true, string.format("Hired Motorbike Courier #%d! Riding to Central Market to stock your Warehouses.", current + 1)
end

function DeliveryRunnerService.GetActiveRunnerPosition(player: Player): Vector3?
	local s = activeRunners[player]
	if s and s.Model.Parent and s.Humanoid.Health > 0 then
		return s.Root.Position
	end
	local list = supplyCouriers[player]
	if list then
		for _, c in ipairs(list) do
			if c.Model.Parent and c.Humanoid.Health > 0 then
				return c.Root.Position
			end
		end
	end
	return nil
end

function DeliveryRunnerService.IsActive(player: Player): boolean
	local s = activeRunners[player]
	return s ~= nil and s.Model.Parent ~= nil and s.Humanoid.Health > 0
end

function DeliveryRunnerService.GetCooldownRemaining(player: Player): number
	local last = lastDispatchAt[player] or 0
	return math.max(0, math.ceil((last + COOLDOWN_SECONDS) - os.clock()))
end

function DeliveryRunnerService.DispatchRunner(player: Player): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Restaurant Plaza first!"
	end
	if DeliveryRunnerService.IsActive(player) then
		return false, "Your Motorbike Express Courier is already en route to Central Park!"
	end
	local cd = DeliveryRunnerService.GetCooldownRemaining(player)
	if cd > 0 then
		return false, string.format("Next Express Dispatch ready in %ds!", cd)
	end

	lastDispatchAt[player] = os.clock()
	local target = CENTRAL_PARK_TARGETS[math.random(1, #CENTRAL_PARK_TARGETS)]
	local spawnPos = getFrontGateSpawn(player, 0)
	local model, hum, root, cratePart, lbl = buildBikeCourierNPC(
		player,
		"ExpressMoto_" .. tostring(player.UserId),
		spawnPos,
		"EXPRESS BIKE -> CENTRAL PARK"
	)
	cratePart.Color = Color3.fromRGB(168, 138, 76)
	cratePart.Transparency = 0

	local session: RunnerSession = {
		Owner = player,
		Model = model,
		Humanoid = hum,
		Root = root,
		StatusLabel = lbl,
		Target = target,
		SpottedWarned = false,
	}
	activeRunners[player] = session

	hum.Died:Connect(function()
		if activeRunners[player] == session then
			activeRunners[player] = nil
			sendToast(player, "Rivals ambushed your Motorbike Express Courier! Escort with Bodyguards.")
			MafiaVisualBuilder.PlayDeathSequence(model, false, nil)
		end
	end)

	return true, string.format("Motorbike Courier dispatched to %s (+%dG on delivery).", target.Name, BASE_PAYOUT_GOLD)
end

local function findThreatNear(pos: Vector3, radius: number): Vector3?
	local closest: Vector3? = nil
	local bestDist = radius
	for _, tagName in ipairs({ "RivalAIUnit", "MafiaUnit" }) do
		for _, unit in ipairs(CollectionService:GetTagged(tagName)) do
			if unit:IsA("Model") then
				local r = unit:FindFirstChild("HumanoidRootPart")
				local h = unit:FindFirstChildOfClass("Humanoid")
				if r and r:IsA("BasePart") and h and h.Health > 0 then
					local d = (r.Position - pos).Magnitude
					if d < bestDist then
						bestDist = d
						closest = r.Position
					end
				end
			end
		end
	end
	return closest
end

local function driveBikeTowards(hum: Humanoid, root: BasePart, dest: Vector3): ()
	local pos = root.Position
	local flatDelta = Vector3.new(dest.X - pos.X, 0, dest.Z - pos.Z)
	if flatDelta.Magnitude <= 6 then
		return
	end

	local path = PathfindingService:CreatePath({ AgentRadius = 3.2, AgentHeight = 6, AgentCanJump = false })
	local ok = pcall(function()
		path:ComputeAsync(pos, dest)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		local wps = path:GetWaypoints()
		local step = wps[math.min(6, #wps)]
		if step then
			hum:MoveTo(step.Position)
			return
		end
	end
	hum:MoveTo(dest)
end

local function stepSupplyCourier(c: SupplyCourier, now: number): ()
	if not c.Owner.Parent or not c.Model.Parent or c.Humanoid.Health <= 0 then
		return
	end

	local pos = c.Root.Position
	local spec = WarehouseConfig.Specs[c.Category] or WarehouseConfig.Specs.Fish
	local catName = spec.Tag

	if not WarehouseService.IsUnlocked(c.Owner, c.Category) then
		c.Category = pickBestCategoryToRestock(c.Owner, c.SlotIndex)
		spec = WarehouseConfig.Specs[c.Category] or WarehouseConfig.Specs.Fish
		catName = spec.Tag
	end

	if c.Phase == "ToMarket" then
		local bayPos = CENTRAL_MARKET_BAYS[c.Category] or CENTRAL_MARKET_BAYS.Fish
		local dist = Vector3.new(bayPos.X - pos.X, 0, bayPos.Z - pos.Z).Magnitude
		c.StatusLabel.Text = string.format("MOTO #%d  |  TO MARKET (%s)", c.SlotIndex, catName)
		c.StatusLabel.TextColor3 = Color3.fromRGB(224, 198, 134)
		c.CratePart.Transparency = 1

		if dist <= 15 then
			c.Phase = "Loading"
			c.PhaseUntil = now + 1.8
			c.Humanoid:MoveTo(pos)
			c.StatusLabel.Text = string.format("MOTO #%d  |  LOADING %s CRATE", c.SlotIndex, catName)
			c.CratePart.Color = spec.AccentColor
			c.CratePart.Transparency = 0
		else
			driveBikeTowards(c.Humanoid, c.Root, bayPos)
		end

	elseif c.Phase == "Loading" then
		c.Humanoid:MoveTo(pos)
		if now >= c.PhaseUntil then
			c.Phase = "ToWarehouse"
			c.StuckTicks = 0
		end

	elseif c.Phase == "ToWarehouse" then
		local whPos = getWarehouseDoorPos(c.Owner, c.Category)
		local dist = Vector3.new(whPos.X - pos.X, 0, whPos.Z - pos.Z).Magnitude
		c.StatusLabel.Text = string.format("MOTO #%d  |  %s -> WAREHOUSE", c.SlotIndex, catName)
		c.StatusLabel.TextColor3 = Color3.fromRGB(142, 212, 162)
		c.CratePart.Color = spec.AccentColor
		c.CratePart.Transparency = 0

		if dist <= 16 then
			c.Phase = "Storing"
			c.PhaseUntil = now + 1.8
			c.Humanoid:MoveTo(pos)

			-- Deposit fresh ingredients right into the player's Warehouse!
			local mult = MonetizationService.GetDeliveryMultiplier(c.Owner)
			local totalToAdd = COURIER_STOCK_PER_TRIP * mult
			local addedCount = 0
			local ings = spec.Ingredients
			for i = 1, totalToAdd do
				local pickIng = ings[((i - 1) % #ings) + 1]
				if pickIng ~= "golden_tuna" and pickIng ~= "king_crab" then
					if WarehouseService.AddIngredient(c.Owner, pickIng, 1) > 0 then
						addedCount += 1
					end
				end
			end

			c.CratePart.Transparency = 1
			if addedCount > 0 then
				c.StatusLabel.Text = string.format("MOTO #%d  |  STORED +%d %s", c.SlotIndex, addedCount, catName)
				SyndicateContractService.RecordProgress(c.Owner, "StockWarehouse", addedCount)
			else
				PlayerDataService.AddCoins(c.Owner, 65)
				c.StatusLabel.Text = string.format("MOTO #%d  |  WH FULL (+65G)", c.SlotIndex)
			end
		else
			driveBikeTowards(c.Humanoid, c.Root, whPos)
		end

	elseif c.Phase == "Storing" then
		c.Humanoid:MoveTo(pos)
		if now >= c.PhaseUntil then
			c.Category = pickBestCategoryToRestock(c.Owner, c.SlotIndex)
			c.Phase = "ToMarket"
			c.StuckTicks = 0
		end
	end

	-- Anti-stuck safeguard on long city roads: gently nudge toward target if stuck for > 6 ticks
	if c.Phase == "ToMarket" or c.Phase == "ToWarehouse" then
		if (pos - c.LastPos).Magnitude < 1.5 then
			c.StuckTicks += 1
			if c.StuckTicks >= 7 then
				c.StuckTicks = 0
				local target = if c.Phase == "ToMarket"
					then (CENTRAL_MARKET_BAYS[c.Category] or CENTRAL_MARKET_BAYS.Fish)
					else getWarehouseDoorPos(c.Owner, c.Category)
				local dir = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
				if dir.Magnitude > 8 then
					c.Model:PivotTo(CFrame.lookAt(pos + dir.Unit * 16 + Vector3.new(0, 1, 0), target))
				end
			end
		else
			c.StuckTicks = 0
		end
		c.LastPos = pos
	end
end

function DeliveryRunnerService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local existing = Workspace:FindFirstChild("PlayerDeliveryRunners")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		runnerFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "PlayerDeliveryRunners"
		f.Parent = Workspace
		runnerFolder = f
	end

	unsubBase = BaseService.OnBaseAssigned(function(player)
		DeliveryRunnerService.SyncCouriersForPlayer(player)
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		clearRunner(player)
		clearSupplyCouriers(player)
		lastDispatchAt[player] = nil
	end)

	aiThread = task.spawn(function()
		while isRunning do
			task.wait(0.75)
			if not isRunning then
				break
			end
			local now = os.clock()

			-- 1. Step Autonomous Motorbike Market-to-Warehouse Supply Couriers!
			for _, player in ipairs(Players:GetPlayers()) do
				if DeliveryRunnerService.GetCourierCount(player) > 0 then
					DeliveryRunnerService.SyncCouriersForPlayer(player)
					local list = supplyCouriers[player]
					if list then
						for _, c in ipairs(list) do
							stepSupplyCourier(c, now)
						end
					end
				end
			end

			-- 2. Step Manual Express Central Park Motorbike Dispatches
			for owner, session in pairs(activeRunners) do
				if not owner.Parent or not session.Model.Parent or session.Humanoid.Health <= 0 then
					clearRunner(owner)
					continue
				end

				local pos = session.Root.Position
				local dest = session.Target.Pos
				local distToGoal = (Vector3.new(dest.X, pos.Y, dest.Z) - pos).Magnitude

				if distToGoal <= 14 then
					local passMult = MonetizationService.GetPayoutMultiplier(owner)
					local repMult = MonetizationService.GetRepMultiplier(owner)
					local gold = math.floor(BASE_PAYOUT_GOLD * passMult)
					local rep = math.floor(BASE_PAYOUT_REP * repMult)
					PlayerDataService.AddRewards(owner, gold, BASE_PAYOUT_EXP, rep)
					SyndicateContractService.RecordProgress(owner, "ConvoyOrRunner", 1)
					sendToast(owner, string.format("Motorbike Courier reached %s! +%d Gold & +%d Rep.", session.Target.Name, gold, rep))
					clearRunner(owner)
					continue
				end

				local threatPos = findThreatNear(pos, 42)
				local moveTarget = dest
				if threatPos then
					session.StatusLabel.Text = "EVADING RIVALS ON BIKE"
					session.StatusLabel.TextColor3 = Color3.fromRGB(228, 96, 102)
					if not session.SpottedWarned then
						session.SpottedWarned = true
						sendToast(owner, "Rivals spotted your Motorbike Courier near Central Park!")
					end
					local toGoal = dest - pos
					local away = pos - threatPos
					local evadeDir = Vector3.new(toGoal.X + away.X * 1.4, 0, toGoal.Z + away.Z * 1.4)
					if evadeDir.Magnitude > 0.1 then
						moveTarget = pos + evadeDir.Unit * 32
					end
				else
					session.StatusLabel.Text = "EXPRESS BIKE -> CENTRAL PARK"
					session.StatusLabel.TextColor3 = Color3.fromRGB(142, 212, 162)
				end

				driveBikeTowards(session.Humanoid, session.Root, moveTarget)
			end
		end
	end)

	print("[Food Empire] DeliveryRunnerService started (Autonomous Motorbike Market->Warehouse Couriers active)!")
end

function DeliveryRunnerService.Stop(): ()
	isRunning = false
	if aiThread then
		task.cancel(aiThread)
		aiThread = nil
	end
	if unsubBase then
		unsubBase()
		unsubBase = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for p in pairs(activeRunners) do
		clearRunner(p)
	end
	for p in pairs(supplyCouriers) do
		clearSupplyCouriers(p)
	end
	table.clear(lastDispatchAt)
end

return DeliveryRunnerService
