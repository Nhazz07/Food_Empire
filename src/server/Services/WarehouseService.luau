--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local BaseService = require("./BaseService")

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

local states: { [Player]: PlayerWarehouseState } = {}
local listeners: { InventoryChangedCallback } = {}
local spendCoinsHandler: SpendCoinsFn? = nil
local isRunning = false
local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local unsubscribeBaseAssigned: (() -> ())? = nil
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

local function ensureState(player: Player): PlayerWarehouseState
	local existing = states[player]
	if existing then
		return existing
	end
	local created = createDefaultState()
	states[player] = created
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

local function updateWarehouseVisualsForPlayer(player: Player): ()
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return
	end

	for _, plot in ipairs(CollectionService:GetTagged("WarehousePlot")) do
		if plot:GetAttribute("BaseSlot") == slot then
			local catAttr = plot:GetAttribute("Category")
			if typeof(catAttr) == "string" and WarehouseConfig.Specs[catAttr :: WarehouseCategory] then
				local category = catAttr :: WarehouseCategory
				local spec = WarehouseConfig.Specs[category]
				local level = WarehouseService.GetWarehouseLevel(player, category)
				local total = WarehouseService.GetCategoryTotal(player, category)
				local cap = WarehouseService.GetCapacity(player, category)

				-- Update progressive Lv.2 -> Lv.10 visual architecture on the 3D Warehouse building!
				local tier2Folder = plot:FindFirstChild("Tier2")
				local tier3Folder = plot:FindFirstChild("Tier3")
				local padPart = plot:FindFirstChild("PlotPivot")

				if padPart and padPart:IsA("BasePart") then
					if tier2Folder then tier2Folder:ClearAllChildren() end
					if tier3Folder then tier3Folder:ClearAllChildren() end

					local evoFolder = plot:FindFirstChild("WarehouseEvolutionVisuals")
					local builtLv = if evoFolder then evoFolder:GetAttribute("BuiltLevel") else -1
					if builtLv ~= level then
						if evoFolder then
							evoFolder:Destroy()
						end
						if level >= 2 then
							local evo = Instance.new("Folder")
							evo.Name = "WarehouseEvolutionVisuals"
							evo:SetAttribute("BuiltLevel", level)
							local baseCF = padPart.CFrame
							local gold = Color3.fromRGB(248, 196, 56)
							local neonGold = Color3.fromRGB(255, 224, 96)
							local diamond = Color3.fromRGB(112, 232, 255)
							local steel = Color3.fromRGB(168, 178, 192)
							local darkSteel = Color3.fromRGB(54, 60, 74)

							local function wPart(name: string, sz: Vector3, rel: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?, transp: number?): Part
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
								p.Parent = evo
								return p
							end

							-- Lv.2: Rooftop Storage Loft + Warm Entry Lanterns
							wPart("Lv2_Loft", Vector3.new(14, 4.8, 12), CFrame.new(0, 21.2, -2), Color3.fromRGB(246, 240, 228), Enum.Material.SmoothPlastic, nil, nil)
							wPart("Lv2_LoftRoof", Vector3.new(15.6, 1.5, 13.6), CFrame.new(0, 24.4, -2), spec.AccentColor, Enum.Material.SmoothPlastic, nil, nil)
							for _, lx in ipairs({ -12.0, 12.0 }) do
								wPart("Lv2_Lantern", Vector3.new(1.4, 1.8, 1.4), CFrame.new(lx, 10.4, 10.6), Color3.fromRGB(255, 226, 152), Enum.Material.Neon, nil, nil)
							end

							-- Lv.3: Gold Architectural Trim Band + Glowing Roof Orb
							if level >= 3 then
								wPart("Lv3_GoldTrim", Vector3.new(23.4, 1.1, 21.4), CFrame.new(0, 11.2, -2), gold, Enum.Material.Metal, nil, nil)
								local orb = wPart("Lv3_Beacon", Vector3.new(3.4, 3.4, 3.4), CFrame.new(0, 27.2, -2), neonGold, Enum.Material.Neon, Enum.PartType.Ball, nil)
								local pl = Instance.new("PointLight")
								pl.Color = neonGold
								pl.Brightness = 1.4
								pl.Range = 26
								pl.Shadows = false
								pl.Parent = orb
							end

							-- Lv.4: Side Refrigerated Silo Tank + Industrial Piping
							if level >= 4 then
								wPart("Lv4_SiloTank", Vector3.new(13.0, 6.2, 6.2), CFrame.new(14.5, 7.2, -2) * CFrame.Angles(0, 0, math.rad(90)), steel, Enum.Material.Metal, Enum.PartType.Cylinder, nil)
								wPart("Lv4_SiloBand", Vector3.new(1.6, 6.6, 6.6), CFrame.new(14.5, 9.5, -2) * CFrame.Angles(0, 0, math.rad(90)), spec.AccentColor, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, nil)
								wPart("Lv4_SiloCap", Vector3.new(6.2, 3.2, 6.2), CFrame.new(14.5, 13.8, -2), steel, Enum.Material.Metal, Enum.PartType.Ball, nil)
							end

							-- Lv.5: Glowing Neon Category Trim Frame + Dual Cargo Floodlights
							if level >= 5 then
								wPart("Lv5_NeonRim", Vector3.new(24.0, 0.7, 22.0), CFrame.new(0, 17.6, -2), spec.AccentColor, Enum.Material.Neon, nil, nil)
								for _, fx in ipairs({ -8.0, 8.0 }) do
									wPart("Lv5_Flood", Vector3.new(2.2, 1.0, 1.2), CFrame.new(fx, 16.5, 9.4), Color3.fromRGB(255, 246, 212), Enum.Material.Neon, nil, nil)
								end
							end

							-- Lv.6: Steel Rooftop Cargo Crane Gantry
							if level >= 6 then
								wPart("Lv6_CraneMast", Vector3.new(1.6, 12.0, 1.6), CFrame.new(-9.0, 26.0, -2), darkSteel, Enum.Material.Metal, nil, nil)
								wPart("Lv6_CraneBoom", Vector3.new(14.5, 1.2, 1.4), CFrame.new(-3.0, 31.6, -2), gold, Enum.Material.Metal, nil, nil)
								wPart("Lv6_CraneCable", Vector3.new(0.25, 4.0, 0.25), CFrame.new(2.5, 29.0, -2), darkSteel, Enum.Material.Metal, nil, nil)
							end

							-- Lv.7: Twin Illuminated Corner Glass Storage Towers
							if level >= 7 then
								for _, tx in ipairs({ -13.5, 13.5 }) do
									wPart("Lv7_GlassTower", Vector3.new(4.4, 16.5, 4.4), CFrame.new(tx, 9.0, 7.5), Color3.fromRGB(168, 228, 250), Enum.Material.Glass, nil, 0.35)
									wPart("Lv7_TowerCap", Vector3.new(5.2, 1.2, 5.2), CFrame.new(tx, 17.8, 7.5), gold, Enum.Material.Metal, nil, nil)
								end
							end

							-- Lv.8: Upper Logistics Observatory Deck + Glass Penthouse
							if level >= 8 then
								wPart("Lv8_ObsGlass", Vector3.new(11.0, 4.6, 10.0), CFrame.new(0, 27.6, -2), Color3.fromRGB(174, 232, 255), Enum.Material.Glass, nil, 0.3)
								wPart("Lv8_ObsRoof", Vector3.new(13.2, 1.2, 12.2), CFrame.new(0, 30.4, -2), gold, Enum.Material.Metal, nil, nil)
							end

							-- Lv.9: Golden Corner Columns + Glowing Supply Halo Ring
							if level >= 9 then
								for _, cx in ipairs({ -12.0, 12.0 }) do
									for _, cz in ipairs({ -12.0, 8.5 }) do
										wPart("Lv9_GoldCol", Vector3.new(1.5, 18.0, 1.5), CFrame.new(cx, 9.5, cz), gold, Enum.Material.Metal, nil, nil)
									end
								end
								wPart("Lv9_HaloRing", Vector3.new(0.8, 16.5, 16.5), CFrame.new(0, 32.8, -2) * CFrame.Angles(0, 0, math.rad(90)), neonGold, Enum.Material.Neon, Enum.PartType.Cylinder, 0.25)
							end

							-- Lv.10 (MAX MEGA DEPOT): Radiant Diamond-Gold Spire + Sky Beacon!
							if level >= 10 then
								local spire = wPart("Lv10_DiamondSpire", Vector3.new(4.2, 7.5, 4.2), CFrame.new(0, 36.8, -2) * CFrame.Angles(0, math.rad(45), 0), diamond, Enum.Material.Neon, nil, nil)
								wPart("Lv10_SkyBeam", Vector3.new(42, 2.2, 2.2), CFrame.new(0, 56, -2) * CFrame.Angles(0, 0, math.rad(90)), diamond, Enum.Material.Neon, Enum.PartType.Cylinder, 0.65)
								local pl10 = Instance.new("PointLight")
								pl10.Color = diamond
								pl10.Brightness = 2.2
								pl10.Range = 42
								pl10.Shadows = false
								pl10.Parent = spire
							end

							evo.Parent = plot
						end
					end
				end

				-- Show Blueprint Ghost for Locked Warehouses (Lv.0) vs Solid Building when Unlocked (Lv.1+)
				local isLocked = (level <= 0)
				local evoVis = plot:FindFirstChild("WarehouseEvolutionVisuals")
				for _, desc in ipairs(plot:GetDescendants()) do
					if desc:IsA("BasePart") then
						local n = desc.Name
						local isExempt = (n == "PlotPivot" or n == "BasePad" or n == "SignPlate" or n == "CargoDoor" or n == "Foundation")
						local inEvo = evoVis ~= nil and desc:IsDescendantOf(evoVis)
						if not isExempt and not inEvo and desc.Parent ~= tier2Folder and desc.Parent ~= tier3Folder then
							if desc:GetAttribute("OrigTrans") == nil then
								desc:SetAttribute("OrigTrans", desc.Transparency)
								desc:SetAttribute("OrigCollide", desc.CanCollide)
							end
							if isLocked then
								desc.Transparency = 0.78
								desc.CanCollide = false
							else
								local ot = desc:GetAttribute("OrigTrans")
								local oc = desc:GetAttribute("OrigCollide")
								desc.Transparency = if typeof(ot) == "number" then ot else 0
								desc.CanCollide = if typeof(oc) == "boolean" then oc else true
							end
						end
					end
				end

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

local function notifyChanged(player: Player): ()
	updateWarehouseVisualsForPlayer(player)
	local snapshot = WarehouseService.GetInventorySnapshot(player)
	for _, cb in ipairs(listeners) do
		task.spawn(cb, player, snapshot)
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
	local state = ensureState(player)
	if savedLevels then
		for _, category in ipairs(WarehouseConfig.Categories) do
			local lv = savedLevels[category]
			if typeof(lv) == "number" then
				local minLv = if category == "Fish" then 1 else 0
				state.Levels[category] = math.clamp(math.floor(lv), minLv, WarehouseConfig.MaxLevel)
			end
		end
	end
	if savedStock then
		for ingredient in pairs(WarehouseConfig.IngredientToCategory) do
			local qty = savedStock[ingredient]
			if typeof(qty) == "number" and qty >= 0 then
				state.Stock[ingredient] = math.floor(qty)
			end
		end
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
			else
				prompt = Instance.new("ProximityPrompt")
				prompt.Name = "WarehouseUpgradePrompt"
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.HoldDuration = 0.35
				prompt.MaxActivationDistance = 14
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

	playerAddedConn = Players.PlayerAdded:Connect(function(player)
		ensureState(player)
		updateWarehouseVisualsForPlayer(player)
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	unsubscribeBaseAssigned = BaseService.OnBaseAssigned(function(player)
		ensureState(player)
		updateWarehouseVisualsForPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		ensureState(player)
		updateWarehouseVisualsForPlayer(player)
	end

	print("[Food Empire] WarehouseService started (Fish, Meat, Vegetable, Fruit storage & upgrades live)!")
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
	for _, conn in ipairs(promptConnections) do
		conn:Disconnect()
	end
	table.clear(promptConnections)
end

return WarehouseService
