--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local RecipeConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RecipeConfig")
)
local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local MonetizationService = require("./MonetizationService")

export type AutoServeCallback = (player: Player) -> ()
export type AutoCookOnlyCallback = (player: Player) -> ()
export type AutoWaiterCallback = (player: Player) -> ()
export type WaiterChangedCallback = (player: Player) -> ()

local CrewService = {}

CrewService.MAX_WAITERS = 3
CrewService.WAITER_COSTS = { [1] = 200, [2] = 360, [3] = 540 }

local CREW_SPEED_BONUS_PER_MEMBER = 0.15
local AUTO_COOK_INTERVAL = 4.2
local AUTO_WAITER_INTERVAL = 2.6

local crewModels: { [Player]: { Model } } = {}
local autoServeHandler: AutoServeCallback? = nil
local autoCookOnlyHandler: AutoCookOnlyCallback? = nil
local autoWaiterHandler: AutoWaiterCallback? = nil
local waiterChangedHandler: WaiterChangedCallback? = nil
local isRunning = false
local loopThread: thread? = nil
local waiterThread: thread? = nil
local chefChoreoThread: thread? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local unsubscribeProfile: (() -> ())? = nil
local unsubscribeBase: (() -> ())? = nil

-- Realistic Commercial Kitchen Line Stations (facing -Z directly over Stove 1, Stove 2, Prep & Pass!)
local CREW_STATIONS: { { Pos: Vector3, Action: string, Label: string } } = {
	{ Pos = Vector3.new(-20.0, 0.85, -13.0), Action = "TossingPan", Label = "TOSSING PAN" },
	{ Pos = Vector3.new(-15.0, 0.85, -13.0), Action = "Searing",    Label = "SEARING" },
	{ Pos = Vector3.new(-9.6,  0.85, -13.0), Action = "Chopping",   Label = "PREP & CHOP" },
	{ Pos = Vector3.new(-4.8,  0.85, -13.0), Action = "Plating",    Label = "PLATING DISH" },
	{ Pos = Vector3.new(-24.2, 0.85, -13.0), Action = "Searing",    Label = "GRILLING" },
	{ Pos = Vector3.new(-0.6,  0.85, -13.0), Action = "Plating",    Label = "GARNISHING" },
}

local CHEF_CYCLE_ACTIONS: { { Action: string, Label: string } } = {
	{ Action = "TossingPan", Label = "TOSSING PAN" },
	{ Action = "Searing",    Label = "SEARING" },
	{ Action = "Chopping",   Label = "CHOPPING PREP" },
	{ Action = "Plating",    Label = "PLATING DISH" },
}

function CrewService.SetAutoServeHandler(handler: AutoServeCallback): ()
	autoServeHandler = handler
end

function CrewService.SetAutoCookOnlyHandler(handler: AutoCookOnlyCallback): ()
	autoCookOnlyHandler = handler
end

function CrewService.SetAutoWaiterHandler(handler: AutoWaiterCallback): ()
	autoWaiterHandler = handler
end

function CrewService.SetWaiterChangedHandler(handler: WaiterChangedCallback): ()
	waiterChangedHandler = handler
end

function CrewService.GetCrewCount(player: Player): number
	return PlayerDataService.GetProfile(player).CrewCount
end

function CrewService.GetWaiterCount(player: Player): number
	return PlayerDataService.GetProfile(player).WaiterCount
end

function CrewService.GetNextWaiterCost(player: Player): number?
	local count = CrewService.GetWaiterCount(player)
	if count >= CrewService.MAX_WAITERS then
		return nil
	end
	return CrewService.WAITER_COSTS[count + 1] or 540
end

function CrewService.GetWaiterTipMultiplier(player: Player): number
	return 1 + CrewService.GetWaiterCount(player) * 0.10
end

function CrewService.GetNextHireCost(player: Player): number
	local count = CrewService.GetCrewCount(player)
	return RecipeConfig.CrewHireBaseCost + count * RecipeConfig.CrewHireCostStep
end

function CrewService.GetMaxCrew(player: Player): number
	local level = PlayerDataService.GetProfile(player).RestaurantLevel
	local tier = RecipeConfig.RestaurantTiers[level] or RecipeConfig.RestaurantTiers[1]
	return tier.MaxCrew + MonetizationService.GetBonusCrewSlots(player)
end

function CrewService.GetCookSpeedMultiplier(player: Player): number
	local count = CrewService.GetCrewCount(player)
	return 1 + count * CREW_SPEED_BONUS_PER_MEMBER
end

local function clearCrewVisuals(player: Player): ()
	local list = crewModels[player]
	if not list then
		return
	end
	for _, m in ipairs(list) do
		if m.Parent then
			m:Destroy()
		end
	end
	crewModels[player] = nil
end

local function spawnCrewChef(parent: Instance, index: number, worldCF: CFrame, accentColor: Color3, initialAction: string, initialLabel: string): Model
	local rig = MafiaVisualBuilder.BuildChefRig("CrewChef_" .. tostring(index), accentColor, 1.04, worldCF * CFrame.new(0, 3.05, 0), false)
	local npc = rig.Model

	-- Measure exact foot-to-root offset so every R15 Chef stands flush on the kitchen tile floor
	local footOffset = math.clamp(rig.Root.Position.Y - (rig.LeftFoot.Position.Y - rig.LeftFoot.Size.Y * 0.5), 2.5, 3.6)
	rig.Root.CFrame = worldCF * CFrame.new(0, footOffset, 0)

	-- Anchor ONLY HumanoidRootPart; leave all R15 arms, elbows, torso & head unanchored so 60 FPS cooking animations work!
	rig.Root.Anchored = true
	for _, desc in ipairs(npc:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
			if desc ~= rig.Root then
				desc.Anchored = false
				desc.Massless = true
			end
		end
	end

	-- Attach realistic rising culinary steam & burner sizzle sparks right on the Chef's sauté pan!
	local panPart = npc:FindFirstChild("SteelPan", true)
	if panPart and panPart:IsA("BasePart") then
		local steam = Instance.new("ParticleEmitter")
		steam.Name = "ChefPanSteam"
		steam.Color = ColorSequence.new(Color3.fromRGB(244, 240, 232))
		steam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.58),
			NumberSequenceKeypoint.new(0.5, 0.74),
			NumberSequenceKeypoint.new(1, 1.0),
		})
		steam.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1.15),
		})
		steam.Lifetime = NumberRange.new(0.9, 1.5)
		steam.Rate = 8
		steam.Speed = NumberRange.new(1.2, 2.4)
		steam.SpreadAngle = Vector2.new(18, 18)
		steam.EmissionDirection = Enum.NormalId.Top
		steam.Parent = panPart

		local sizzle = Instance.new("ParticleEmitter")
		sizzle.Name = "ChefSizzleSparks"
		sizzle.Color = ColorSequence.new(Color3.fromRGB(255, 208, 96), Color3.fromRGB(242, 112, 36))
		sizzle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0) })
		sizzle.Lifetime = NumberRange.new(0.22, 0.45)
		sizzle.Rate = 5
		sizzle.Speed = NumberRange.new(2.2, 4.8)
		sizzle.SpreadAngle = Vector2.new(55, 55)
		sizzle.EmissionDirection = Enum.NormalId.Top
		sizzle.LightEmission = 0.8
		sizzle.Parent = panPart
	end

	npc:SetAttribute("ChefAction", initialAction)
	npc:SetAttribute("ChefIndex", index)

	local bb = Instance.new("BillboardGui")
	bb.Name = "ChefBadge"
	bb.Size = UDim2.fromOffset(168, 26)
	bb.StudsOffset = Vector3.new(0, 2.8, 0)
	bb.MaxDistance = 78
	bb.Parent = rig.Head

	local lbl = Instance.new("TextLabel")
	lbl.Name = "StatusText"
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = string.format("CHEF #%d  |  %s", index, initialLabel)
	lbl.TextSize = 10
	lbl.TextColor3 = Color3.fromRGB(234, 231, 224)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(168, 138, 76)
	st.Thickness = 1.1
	st.Parent = lbl

	npc.PrimaryPart = rig.Root
	CollectionService:AddTag(npc, "AnimatedKitchenChef")
	npc.Parent = parent
	return npc
end

function CrewService.SyncCrewVisuals(player: Player): ()
	clearCrewVisuals(player)

	local count = CrewService.GetCrewCount(player)
	if count <= 0 then
		return
	end

	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return
	end

	local baseModel = BaseService.GetBaseModel(slot)
	if not baseModel then
		return
	end

	local hq = baseModel:FindFirstChild("RestaurantHQ")
	if not hq or not hq:IsA("Model") or not hq.PrimaryPart then
		return
	end

	local accentAttr = baseModel:GetAttribute("AccentColor")
	local accentColor = if typeof(accentAttr) == "Color3" then accentAttr else Color3.fromRGB(74, 188, 86)

	local spawned: { Model } = {}
	for i = 1, math.min(count, #CREW_STATIONS) do
		local st = CREW_STATIONS[i]
		-- Face directly toward the sizzling commercial stove range (-Z in HQ local space)!
		local worldCF = hq.PrimaryPart.CFrame * CFrame.new(st.Pos)
		table.insert(spawned, spawnCrewChef(hq, i, worldCF, accentColor, st.Action, st.Label))
	end
	crewModels[player] = spawned
end

function CrewService.TryHireCrew(player: Player): (boolean, string)
	local current = CrewService.GetCrewCount(player)
	local maxCrew = CrewService.GetMaxCrew(player)
	if current >= maxCrew then
		return false, string.format("Max Crew (%d) — Upgrade Restaurant HQ!", maxCrew)
	end

	local cost = CrewService.GetNextHireCost(player)
	if not PlayerDataService.SpendCoins(player, cost) then
		return false, string.format("Need %d Coins", cost)
	end

	PlayerDataService.SetCrewCount(player, current + 1)
	CrewService.SyncCrewVisuals(player)
	print(string.format("[CrewService] %s hired Crew Chef #%d!", player.Name, current + 1))
	return true, string.format("Hired Kitchen Chef #%d! Fetches from Warehouse & cooks dishes.", current + 1)
end

function CrewService.TryHireWaiter(player: Player): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Restaurant Plaza first!"
	end
	local current = CrewService.GetWaiterCount(player)
	local cost = CrewService.GetNextWaiterCost(player)
	if not cost then
		return false, string.format("Max Waiters hired (%d / %d)!", CrewService.MAX_WAITERS, CrewService.MAX_WAITERS)
	end
	if not PlayerDataService.SpendCoins(player, cost) then
		return false, string.format("Need %d Gold to hire Waiter #%d!", cost, current + 1)
	end

	PlayerDataService.SetWaiterCount(player, current + 1)
	if waiterChangedHandler then
		waiterChangedHandler(player)
	end
	print(string.format("[CrewService] %s hired Dining Waiter #%d!", player.Name, current + 1))
	return true, string.format("Hired Dining Waiter #%d! Delivers cooked dishes to customers (+10%% tips).", current + 1)
end

function CrewService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	unsubscribeBase = BaseService.OnBaseAssigned(function(player)
		CrewService.SyncCrewVisuals(player)
	end)

	unsubscribeProfile = PlayerDataService.OnProfileChanged(function(player)
		local existing = crewModels[player]
		local targetCount = CrewService.GetCrewCount(player)
		if (existing and #existing or 0) ~= targetCount then
			CrewService.SyncCrewVisuals(player)
		end
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		clearCrewVisuals(player)
	end)

	-- Hired Chefs loop: fetch ingredients from Warehouse & cook dishes onto the Kitchen Counter!
	loopThread = task.spawn(function()
		while isRunning do
			task.wait(AUTO_COOK_INTERVAL)
			if not isRunning then
				break
			end
			for _, player in ipairs(Players:GetPlayers()) do
				if CrewService.GetCrewCount(player) > 0 then
					if autoCookOnlyHandler then
						autoCookOnlyHandler(player)
					elseif autoServeHandler then
						autoServeHandler(player)
					end
				end
			end
		end
	end)

	-- Hired Waiters loop: pick up ready dishes from Kitchen Counter & deliver them to Customers!
	waiterThread = task.spawn(function()
		while isRunning do
			task.wait(AUTO_WAITER_INTERVAL)
			if not isRunning then
				break
			end
			if autoWaiterHandler then
				for _, player in ipairs(Players:GetPlayers()) do
					if CrewService.GetWaiterCount(player) > 0 then
						autoWaiterHandler(player)
					end
				end
			end
		end
	end)

	-- Dynamic realistic kitchen choreography: cycle Chef actions & live status callouts!
	chefChoreoThread = task.spawn(function()
		local cycleTick = 0
		while isRunning do
			task.wait(5.0)
			if not isRunning then
				break
			end
			cycleTick += 1
			for _, list in pairs(crewModels) do
				for idx, chefModel in ipairs(list) do
					if chefModel.Parent then
						local nextSpec = CHEF_CYCLE_ACTIONS[((cycleTick + idx - 1) % #CHEF_CYCLE_ACTIONS) + 1]
						chefModel:SetAttribute("ChefAction", nextSpec.Action)
						local badge = chefModel:FindFirstChild("ChefBadge", true)
						local lbl = if badge then badge:FindFirstChild("StatusText") else nil
						if lbl and lbl:IsA("TextLabel") then
							lbl.Text = string.format("CHEF #%d  |  %s", idx, nextSpec.Label)
						end
					end
				end
			end
		end
	end)

	print("[Food Empire] CrewService started (Hireable Kitchen Chefs & Dining Waiters supply chain active)!")
end

function CrewService.Stop(): ()
	isRunning = false
	if loopThread then
		task.cancel(loopThread)
		loopThread = nil
	end
	if waiterThread then
		task.cancel(waiterThread)
		waiterThread = nil
	end
	if chefChoreoThread then
		task.cancel(chefChoreoThread)
		chefChoreoThread = nil
	end
	if unsubscribeBase then
		unsubscribeBase()
		unsubscribeBase = nil
	end
	if unsubscribeProfile then
		unsubscribeProfile()
		unsubscribeProfile = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for player in pairs(crewModels) do
		clearCrewVisuals(player)
	end
end

return CrewService
