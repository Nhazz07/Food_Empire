--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local BaseService = require("./BaseService")
local WarehouseVisualBuilder = require("./WarehouseVisualBuilder")

export type WarehouseCategory = WarehouseConfig.WarehouseCategory
export type WarehouseSnapshot = {
	Levels: { [WarehouseCategory]: number },
	Stock: { [string]: number },
	CategoryTotals: { [WarehouseCategory]: number },
	Capacities: { [WarehouseCategory]: number },
}
export type InventoryChangedCallback = (player: Player, snapshot: WarehouseSnapshot) -> ()
export type SpendCoinsFn = (player: Player, amount: number) -> boolean

type PlayerWarehouseState = {
	Levels: { [WarehouseCategory]: number },
	Stock: { [string]: number },
}

local WarehouseService = {}

local slotStates: { [BaseService.BaseSlot]: PlayerWarehouseState } = {}
local unboundStates: { [Player]: PlayerWarehouseState } = {}
local listeners: { InventoryChangedCallback } = {}
local spendCoinsHandler: SpendCoinsFn? = nil
local isRunning = false
local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local unsubscribeBaseAssigned: (() -> ())? = nil
local unsubscribeBaseReleased: (() -> ())? = nil
local promptConnections: { RBXScriptConnection } = {}

local function createDefaultState(): PlayerWarehouseState
	-- Players start with ONLY the Fish Warehouse unlocked (Lv.1); Meat, Vegetable & Fruit start locked (Lv.0)
	local levels: { [WarehouseCategory]: number } = {
		Fish = 1,
		Meat = 0,
		Vegetable = 0,
		Fruit = 0,
	}
	local stock: { [string]: number } = {}
	for ingredient in pairs(WarehouseConfig.IngredientToCategory) do
		stock[ingredient] = 0
	end
	return {
		Levels = levels,
		Stock = stock,
	}
end

local function getCategoryTotalFromState(state: PlayerWarehouseState, category: WarehouseCategory): number
	local spec = WarehouseConfig.Specs[category]
	if not spec then
		return 0
	end
	local total = 0
	for _, ingredient in ipairs(spec.Ingredients) do
		total += state.Stock[ingredient] or 0
	end
	return total
end

local function getCapacityFromState(state: PlayerWarehouseState, category: WarehouseCategory): number
	local level = state.Levels[category] or 0
	if level <= 0 then
		return 0
	end
	local tier = WarehouseConfig.Tiers[level] or WarehouseConfig.Tiers[1]
	return tier.Capacity
end

local function mergeWarehouseStates(target: PlayerWarehouseState, incoming: PlayerWarehouseState): ()
	for _, category in ipairs(WarehouseConfig.Categories) do
		local minLv = if category == "Fish" then 1 else 0
		local lvA = target.Levels[category] or minLv
		local lvB = incoming.Levels[category] or minLv
		target.Levels[category] = math.clamp(math.max(lvA, lvB), minLv, WarehouseConfig.MaxLevel)
	end
	for _, category in ipairs(WarehouseConfig.Categories) do
		local spec = WarehouseConfig.Specs[category]
		if spec then
			local cap = getCapacityFromState(target, category)
			local curTotal = getCategoryTotalFromState(target, category)
			local spaceLeft = math.max(0, cap - curTotal)
			for _, ing in ipairs(spec.Ingredients) do
				local addQty = math.min(math.max(0, math.floor(incoming.Stock[ing] or 0)), spaceLeft)
				if addQty > 0 then
					target.Stock[ing] = (target.Stock[ing] or 0) + addQty
					spaceLeft -= addQty
				end
			end
		end
	end
end

local function ensureSlotState(slot: BaseService.BaseSlot): PlayerWarehouseState
	local existing = slotStates[slot]
	if existing then
		return existing
	end
	local created = createDefaultState()
	slotStates[slot] = created
	return created
end

local function ensureState(player: Player): PlayerWarehouseState
	local slot = BaseService.GetPlayerBaseSlot(player)
	if slot then
		return ensureSlotState(slot)
	end
	local existing = unboundStates[player]
	if existing then
		return existing
	end
	local created = createDefaultState()
	unboundStates[player] = created
	return created
end

function WarehouseService.SetSpendCoinsHandler(handler: SpendCoinsFn): ()
	spendCoinsHandler = handler
end

function WarehouseService.GetWarehouseLevel(player: Player, category: WarehouseCategory): number
	local state = ensureState(player)
	local lv = state.Levels[category]
	return if lv ~= nil then lv else 0
end

function WarehouseService.IsUnlocked(player: Player, category: WarehouseCategory): boolean
	return WarehouseService.GetWarehouseLevel(player, category) >= 1
end

function WarehouseService.GetCapacity(player: Player, category: WarehouseCategory): number
	local level = WarehouseService.GetWarehouseLevel(player, category)
	if level <= 0 then
		return 0
	end
	local tier = WarehouseConfig.Tiers[level] or WarehouseConfig.Tiers[1]
	return tier.Capacity
end

function WarehouseService.GetCategoryTotal(player: Player, category: WarehouseCategory): number
	local state = ensureState(player)
	local spec = WarehouseConfig.Specs[category]
	if not spec then
		return 0
	end
	local total = 0
	for _, ingredient in ipairs(spec.Ingredients) do
		total += state.Stock[ingredient] or 0
	end
	return total
end

function WarehouseService.GetInventorySnapshot(player: Player): WarehouseSnapshot
	local state = ensureState(player)
	local levelsCopy: { [WarehouseCategory]: number } = {
		Fish = state.Levels.Fish,
		Meat = state.Levels.Meat,
		Vegetable = state.Levels.Vegetable,
		Fruit = state.Levels.Fruit,
	}
	local stockCopy: { [string]: number } = {}
	for ingredient, qty in pairs(state.Stock) do
		stockCopy[ingredient] = qty
	end
	local totals: { [WarehouseCategory]: number } = {
		Fish = WarehouseService.GetCategoryTotal(player, "Fish"),
		Meat = WarehouseService.GetCategoryTotal(player, "Meat"),
		Vegetable = WarehouseService.GetCategoryTotal(player, "Vegetable"),
		Fruit = WarehouseService.GetCategoryTotal(player, "Fruit"),
	}
	local caps: { [WarehouseCategory]: number } = {
		Fish = WarehouseService.GetCapacity(player, "Fish"),
		Meat = WarehouseService.GetCapacity(player, "Meat"),
		Vegetable = WarehouseService.GetCapacity(player, "Vegetable"),
		Fruit = WarehouseService.GetCapacity(player, "Fruit"),
	}
	return {
		Levels = levelsCopy,
		Stock = stockCopy,
		CategoryTotals = totals,
		Capacities = caps,
	}
end

local function updateWarehouseVisualsForSlot(slot: BaseService.BaseSlot, state: PlayerWarehouseState): ()
	for _, plot in ipairs(CollectionService:GetTagged("WarehousePlot")) do
		if plot:GetAttribute("BaseSlot") == slot then
			local catAttr = plot:GetAttribute("Category")
			if typeof(catAttr) == "string" and WarehouseConfig.Specs[catAttr :: WarehouseCategory] then
				local category = catAttr :: WarehouseCategory
				local spec = WarehouseConfig.Specs[category]
				local level = state.Levels[category] or 0
				local total = getCategoryTotalFromState(state, category)
				local cap = getCapacityFromState(state, category)

				-- Apply 100% UI-icon-matched 3D Warehouse architecture & cohesive Lv.0 -> Lv.10 upgrades!
				if plot:IsA("Model") then
					WarehouseVisualBuilder.ApplyToPlot(plot, category, level)
				end
				local isLocked = (level <= 0)

				-- Update SignPlate label with locked/unlocked status & live capacity
				local signPlate = plot:FindFirstChild("SignPlate", true)
				if signPlate then
					local label = signPlate:FindFirstChildOfClass("SurfaceGui")
					if label then
						local textLbl = label:FindFirstChildOfClass("TextLabel")
						if textLbl then
							if isLocked then
								textLbl.Text = string.format("LOCKED %s WAREHOUSE (%dG)", string.upper(spec.ShortLabel), spec.UnlockCost)
							else
								textLbl.Text = string.format("%s WAREHOUSE %d/%d (Lv.%d)", string.upper(spec.ShortLabel), total, cap, level)
							end
						end
					end
				end

				-- Update world Build / Upgrade ProximityPrompt on CargoDoor
				local door = plot:FindFirstChild("CargoDoor", true)
				if door and door:IsA("BasePart") then
					local prompt = door:FindFirstChild("WarehouseUpgradePrompt")
					if prompt and prompt:IsA("ProximityPrompt") then
						if isLocked then
							prompt.Enabled = true
							prompt.ActionText = string.format("Unlock %s (%dG)", spec.DisplayName, spec.UnlockCost)
							prompt.ObjectText = "Locked Ingredient Warehouse"
						else
							local nextTier = WarehouseConfig.Tiers[level + 1]
							if nextTier then
								prompt.Enabled = true
								prompt.ActionText = string.format("Upgrade Lv.%d (%dG)", nextTier.Level, nextTier.UpgradeCost)
								prompt.ObjectText = string.format("%s (%d/%d)", spec.DisplayName, total, cap)
							else
								prompt.Enabled = true
								prompt.ActionText = "MAX LEVEL"
								prompt.ObjectText = string.format("%s (%d/%d)", spec.DisplayName, total, cap)
							end
						end
					end
				end
			end
		end
	end
end

local function updateWarehouseVisualsForPlayer(player: Player): ()
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return
	end
	updateWarehouseVisualsForSlot(slot, ensureSlotState(slot))
end

local function notifyChanged(player: Player): ()
	local slot = BaseService.GetPlayerBaseSlot(player)
	if slot then
		updateWarehouseVisualsForSlot(slot, ensureSlotState(slot))
		for _, member in ipairs(BaseService.GetBasePlayers(slot)) do
			local snapshot = WarehouseService.GetInventorySnapshot(member)
			for _, cb in ipairs(listeners) do
				task.spawn(cb, member, snapshot)
			end
		end
	else
		local snapshot = WarehouseService.GetInventorySnapshot(player)
		for _, cb in ipairs(listeners) do
			task.spawn(cb, player, snapshot)
		end
	end
end

function WarehouseService.OnInventoryChanged(callback: InventoryChangedCallback): () -> ()
	table.insert(listeners, callback)
	return function()
		local idx = table.find(listeners, callback)
		if idx then
			table.remove(listeners, idx)
		end
	end
end

function WarehouseService.AddIngredient(player: Player, ingredient: string, amount: number): number
	if amount <= 0 then
		return 0
	end

	local category = WarehouseConfig.IngredientToCategory[ingredient]
	if not category then
		warn("[WarehouseService] Unknown ingredient:", ingredient)
		return 0
	end

	local state = ensureState(player)
	local currentTotal = WarehouseService.GetCategoryTotal(player, category)
	local capacity = WarehouseService.GetCapacity(player, category)
	local spaceLeft = math.max(0, capacity - currentTotal)
	local added = math.min(amount, spaceLeft)

	if added > 0 then
		state.Stock[ingredient] = (state.Stock[ingredient] or 0) + added
		notifyChanged(player)
	end

	return added
end

function WarehouseService.HasIngredients(player: Player, required: { [string]: number }): boolean
	local state = ensureState(player)
	for ingredient, needed in pairs(required) do
		if (state.Stock[ingredient] or 0) < needed then
			return false
		end
	end
	return true
end

function WarehouseService.ConsumeIngredients(player: Player, required: { [string]: number }): boolean
	if not WarehouseService.HasIngredients(player, required) then
		return false
	end

	local state = ensureState(player)
	for ingredient, needed in pairs(required) do
		state.Stock[ingredient] = math.max(0, (state.Stock[ingredient] or 0) - needed)
	end

	notifyChanged(player)
	return true
end

-- Server-authoritative theft of actually stored warehouse ingredients (used by Nighttime Mafia Raids).
-- Strictly steals only ingredients with positive stock in valid (and unlocked) warehouses,
-- never produces negative quantities, never steals nonexistent items, and never touches Robux purchases
-- or warehouse unlock levels.
function WarehouseService.StealRandomStoredIngredients(
	player: Player,
	maxQuantity: number,
	theftPercent: number?,
	onlyUnlocked: boolean?
): ({ [string]: number }, number)
	local limit = math.max(0, math.floor(maxQuantity))
	local stolen: { [string]: number } = {}
	if limit <= 0 then
		return stolen, 0
	end

	local state = ensureState(player)
	local requireUnlocked = (onlyUnlocked ~= false)

	-- First compute actual stealable stock across valid (unlocked) warehouses
	local totalStealable = 0
	for ingredient, qty in pairs(state.Stock) do
		local cat = WarehouseConfig.IngredientToCategory[ingredient]
		if cat ~= nil and typeof(qty) == "number" and qty > 0 then
			if not requireUnlocked or (state.Levels[cat] or 0) >= 1 then
				totalStealable += math.floor(qty)
			end
		end
	end

	-- Empty warehouse: safe no-op, zero errors, zero negative counts!
	if totalStealable <= 0 then
		return stolen, 0
	end

	local targetCount = limit
	if typeof(theftPercent) == "number" and theftPercent > 0 then
		local pctTarget = math.max(1, math.ceil(totalStealable * math.clamp(theftPercent, 0.05, 1.0)))
		targetCount = math.min(limit, pctTarget)
	end
	targetCount = math.min(targetCount, totalStealable)

	local totalStolen = 0
	for _ = 1, targetCount do
		local availableKeys: { string } = {}
		for ingredient, qty in pairs(state.Stock) do
			local cat = WarehouseConfig.IngredientToCategory[ingredient]
			if cat ~= nil and typeof(qty) == "number" and qty > 0 then
				if not requireUnlocked or (state.Levels[cat] or 0) >= 1 then
					table.insert(availableKeys, ingredient)
				end
			end
		end
		if #availableKeys == 0 then
			break
		end
		local chosen = availableKeys[math.random(1, #availableKeys)]
		local current = state.Stock[chosen] or 0
		if current > 0 then
			state.Stock[chosen] = math.max(0, current - 1)
			stolen[chosen] = (stolen[chosen] or 0) + 1
			totalStolen += 1
		end
	end

	if totalStolen > 0 then
		notifyChanged(player)
	end

	return stolen, totalStolen
end

function WarehouseService.ClearAllStockForTest(player: Player): ()
	local state = ensureState(player)
	for ingredient in pairs(state.Stock) do
		state.Stock[ingredient] = 0
	end
	notifyChanged(player)
end

function WarehouseService.TryUpgradeWarehouse(player: Player, category: WarehouseCategory, bypassGold: boolean?): (boolean, string)
	local state = ensureState(player)
	local currentLevel = state.Levels[category] or 0
	local spec = WarehouseConfig.Specs[category]
	if not spec then
		return false, "Unknown warehouse"
	end

	-- Unlock / Build locked warehouse (Lv.0 -> Lv.1)
	if currentLevel <= 0 then
		local unlockCost = spec.UnlockCost or 150
		if not bypassGold and spendCoinsHandler and unlockCost > 0 then
			local paid = spendCoinsHandler(player, unlockCost)
			if not paid then
				return false, string.format("Need %d Gold to unlock %s!", unlockCost, spec.DisplayName)
			end
		end
		state.Levels[category] = 1
		notifyChanged(player)
		print(string.format("[WarehouseService] %s unlocked %s (Lv.1, Cap: 50)!", player.Name, spec.DisplayName))
		return true, string.format("Unlocked %s! Matching kitchen dishes & %s stealing are now unlocked!", spec.DisplayName, spec.ShipmentName)
	end

	local nextTier = WarehouseConfig.Tiers[currentLevel + 1]
	if not nextTier then
		return false, "Already at max level"
	end

	if not bypassGold and spendCoinsHandler then
		local paid = spendCoinsHandler(player, nextTier.UpgradeCost)
		if not paid then
			return false, string.format("Need %d Gold to upgrade %s!", nextTier.UpgradeCost, spec.DisplayName)
		end
	end

	state.Levels[category] = nextTier.Level
	notifyChanged(player)
	print(
		string.format(
			"[WarehouseService] %s upgraded %s Warehouse to Lv.%d (Cap: %d)!",
			player.Name,
			category,
			nextTier.Level,
			nextTier.Capacity
		)
	)
	return true, string.format("Upgraded %s to Lv.%d!", spec.DisplayName, nextTier.Level)
end

function WarehouseService.MoveWarehouseToNextPlot(player: Player, category: WarehouseCategory): (boolean, string)
	if not WarehouseService.IsUnlocked(player, category) then
		return false, "Build this Warehouse first!"
	end
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return false, "No castle base assigned"
	end

	local plotsByIndex: { [number]: Model } = {}
	local targetModel: Model? = nil
	local targetIndex: number? = nil

	for _, plot in ipairs(CollectionService:GetTagged("WarehousePlot")) do
		if plot:IsA("Model") and plot:GetAttribute("BaseSlot") == slot then
			local idxAttr = plot:GetAttribute("PlotIndex")
			if typeof(idxAttr) == "number" then
				plotsByIndex[idxAttr] = plot
				if plot:GetAttribute("Category") == category then
					targetModel = plot
					targetIndex = idxAttr
				end
			end
		end
	end

	if not targetModel or not targetIndex then
		return false, "Warehouse plot not found in your base"
	end

	local nextIndex = (targetIndex % 4) + 1
	local swapModel = plotsByIndex[nextIndex]
	if not swapModel then
		return false, "Next plot unavailable"
	end

	local cfA = targetModel:GetPivot()
	local cfB = swapModel:GetPivot()
	targetModel:PivotTo(cfB)
	swapModel:PivotTo(cfA)
	targetModel:SetAttribute("PlotIndex", nextIndex)
	swapModel:SetAttribute("PlotIndex", targetIndex)

	notifyChanged(player)
	local spec = WarehouseConfig.Specs[category]
	local whName = if spec then spec.DisplayName else (category .. " Ingredient Warehouse")
	return true, string.format("Moved %s to Plot #%d!", whName, nextIndex)
end

function WarehouseService.LoadPlayerState(
	player: Player,
	savedLevels: { [string]: number }?,
	savedStock: { [string]: number }?
): ()
	local loaded = createDefaultState()
	if savedLevels then
		for _, category in ipairs(WarehouseConfig.Categories) do
			local lv = savedLevels[category]
			if typeof(lv) == "number" then
				local minLv = if category == "Fish" then 1 else 0
				loaded.Levels[category] = math.clamp(math.floor(lv), minLv, WarehouseConfig.MaxLevel)
			end
		end
	end
	if savedStock then
		for ingredient in pairs(WarehouseConfig.IngredientToCategory) do
			local qty = savedStock[ingredient]
			if typeof(qty) == "number" and qty >= 0 then
				loaded.Stock[ingredient] = math.floor(qty)
			end
		end
	end

	local slot = BaseService.GetPlayerBaseSlot(player)
	if slot then
		if slotStates[slot] and BaseService.GetBasePlayerCount(slot) >= 2 then
			mergeWarehouseStates(slotStates[slot], loaded)
		else
			slotStates[slot] = loaded
		end
	else
		unboundStates[player] = loaded
	end
	notifyChanged(player)
end

local function wireWarehousePrompts(): ()
	for _, plot in ipairs(CollectionService:GetTagged("WarehousePlot")) do
		local catAttr = plot:GetAttribute("Category")
		local slotAttr = plot:GetAttribute("BaseSlot")
		local door = plot:FindFirstChild("CargoDoor", true)

		if
			typeof(catAttr) == "string"
			and typeof(slotAttr) == "string"
			and door
			and door:IsA("BasePart")
			and WarehouseConfig.Specs[catAttr :: WarehouseCategory]
		then
			local category = catAttr :: WarehouseCategory
			local existing = door:FindFirstChild("WarehouseUpgradePrompt")
			local prompt: ProximityPrompt
			if existing and existing:IsA("ProximityPrompt") then
				prompt = existing
				prompt.MaxActivationDistance = 18
			else
				prompt = Instance.new("ProximityPrompt")
				prompt.Name = "WarehouseUpgradePrompt"
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.HoldDuration = 0.35
				prompt.MaxActivationDistance = 18
				prompt.RequiresLineOfSight = false
				prompt.ActionText = "Upgrade Warehouse"
				prompt.ObjectText = WarehouseConfig.Specs[category].DisplayName
				prompt.Parent = door
			end

			local conn = prompt.Triggered:Connect(function(triggerPlayer)
				if BaseService.GetPlayerBaseSlot(triggerPlayer) ~= slotAttr then
					return
				end
				WarehouseService.TryUpgradeWarehouse(triggerPlayer, category)
			end)
			table.insert(promptConnections, conn)
		end
	end
end

function WarehouseService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	wireWarehousePrompts()

	-- Immediately apply the icon-matched 3D Warehouse architecture across all 4 base estates on startup!
	for _, slot in ipairs(BaseService.GetSlotOrder()) do
		updateWarehouseVisualsForSlot(slot, slotStates[slot] or createDefaultState())
	end

	playerAddedConn = Players.PlayerAdded:Connect(function(player)
		ensureState(player)
		updateWarehouseVisualsForPlayer(player)
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		unboundStates[player] = nil
	end)

	unsubscribeBaseAssigned = BaseService.OnBaseAssigned(function(player, slot)
		local pending = unboundStates[player]
		unboundStates[player] = nil
		if not slotStates[slot] then
			slotStates[slot] = pending or createDefaultState()
		elseif pending then
			mergeWarehouseStates(slotStates[slot], pending)
		end
		notifyChanged(player)
	end)

	unsubscribeBaseReleased = BaseService.OnBaseReleased(function(slot, _, remainingCount)
		if remainingCount == 0 then
			slotStates[slot] = nil
			updateWarehouseVisualsForSlot(slot, createDefaultState())
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		ensureState(player)
		updateWarehouseVisualsForPlayer(player)
	end

	print("[Food Empire] WarehouseService started (Shared Co-op Fish, Meat, Vegetable, Fruit storage & upgrades live)!")
end

function WarehouseService.Stop(): ()
	isRunning = false
	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	if unsubscribeBaseAssigned then
		unsubscribeBaseAssigned()
		unsubscribeBaseAssigned = nil
	end
	if unsubscribeBaseReleased then
		unsubscribeBaseReleased()
		unsubscribeBaseReleased = nil
	end
	for _, conn in ipairs(promptConnections) do
		conn:Disconnect()
	end
	table.clear(promptConnections)
end

return WarehouseService
