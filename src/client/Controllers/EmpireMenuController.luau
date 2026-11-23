--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RecipeConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RecipeConfig")
)
local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local MonetizationConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("MonetizationConfig")
)

export type MenuTab = "Kitchen" | "Warehouses" | "Upgrades" | "BlackMarket" | "Shop"
export type ActionCallback = (action: string, arg: any?) -> ()

local EmpireMenuController = {}

local DEFENSE_COSTS: { [number]: number } = { [2] = 500, [3] = 1200 }
local SHOP_ICONS: { [string]: string } = {
	DeliveryMotorbike = "🛵",
	RaiderChefSquad = "⚔️",
	MasterProChef = "👨‍🍳",
	VIPEmpireStaff = "👥",
	DoubleEmpireVIP = "⚡",
	InstantEmpireCrate = "🎁",
}

local modalFrame: Frame? = nil
local titleLabel: TextLabel? = nil
local scrollFrame: ScrollingFrame? = nil
local tabButtons: { [MenuTab]: TextButton } = {}
local currentTab: MenuTab = "Kitchen"
local latestState: { [string]: any }? = nil
local dispatchAction: ActionCallback? = nil

local function makeCorner(parent: Instance, radius: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeStroke(parent: Instance, color: Color3, thickness: number, mode: Enum.ApplyStrokeMode?): ()
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	st.Color = color
	st.Thickness = thickness
	st.Parent = parent
end

local function makeCard(parent: Instance, height: number, accent: Color3): Frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, height)
	card.BackgroundColor3 = Color3.fromRGB(32, 40, 58)
	card.BorderSizePixel = 0
	card.Parent = parent
	makeCorner(card, 12)
	makeStroke(card, Color3.fromRGB(56, 68, 96), 1.2)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 7, 1, 0)
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Parent = card
	makeCorner(bar, 6)

	return card
end

local function makeIconBox(parent: Instance, icon: string, bg: Color3, yPos: number): TextLabel
	local box = Instance.new("TextLabel")
	box.Position = UDim2.new(0, 16, 0, yPos)
	box.Size = UDim2.fromOffset(48, 48)
	box.BackgroundColor3 = bg
	box.Font = Enum.Font.GothamBlack
	box.Text = icon
	box.TextSize = 24
	box.TextColor3 = Color3.new(1, 1, 1)
	box.Parent = parent
	makeCorner(box, 12)
	makeStroke(box, Color3.fromRGB(255, 255, 255), 1.2)
	return box
end

local function makeBtn(parent: Instance, text: string, bg: Color3, pos: UDim2, size: UDim2, onClick: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.Position = pos
	btn.Size = size
	btn.BackgroundColor3 = bg
	btn.Font = Enum.Font.GothamBlack
	btn.Text = text
	btn.TextSize = 13
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Parent = parent
	makeCorner(btn, 10)
	makeStroke(btn, Color3.fromRGB(16, 20, 30), 1.4, Enum.ApplyStrokeMode.Contextual)
	btn.MouseButton1Click:Connect(onClick)
	return btn
end

local function clearScroll(): ()
	if not scrollFrame then
		return
	end
	for _, ch in ipairs(scrollFrame:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
			ch:Destroy()
		end
	end
end

local function refreshTabStyles(): ()
	for tabName, btn in pairs(tabButtons) do
		local active = (tabName == currentTab)
		if tabName == "Shop" then
			btn.BackgroundColor3 = if active then Color3.fromRGB(238, 168, 26) else Color3.fromRGB(64, 52, 28)
		elseif tabName == "BlackMarket" then
			btn.BackgroundColor3 = if active then Color3.fromRGB(196, 36, 58) else Color3.fromRGB(62, 26, 38)
		else
			btn.BackgroundColor3 = if active then Color3.fromRGB(64, 142, 224) else Color3.fromRGB(40, 48, 68)
		end
		btn.TextColor3 = if active then Color3.new(1, 1, 1) else Color3.fromRGB(196, 208, 228)
	end
end

local function renderKitchen(state: { [string]: any }): ()
	if not scrollFrame then
		return
	end
	local stock = (state.Warehouse and state.Warehouse.Stock) or {}
	local kitchen = state.Kitchen or {}
	local restLevel = (state.Profile and state.Profile.RestaurantLevel) or 1

	-- Status Banner Card
	local banner = makeCard(scrollFrame, 64, Color3.fromRGB(238, 142, 42))
	local statusLbl = Instance.new("TextLabel")
	statusLbl.Position = UDim2.new(0, 18, 0, 8)
	statusLbl.Size = UDim2.new(1, -174, 1, -16)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Font = Enum.Font.GothamBold
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.TextSize = 15
	statusLbl.TextColor3 = Color3.new(1, 1, 1)
	if kitchen.IsCooking and kitchen.CurrentRecipeId then
		local r = RecipeConfig.Recipes[kitchen.CurrentRecipeId]
		statusLbl.Text = string.format("🔥 Cooking %s... (%.1fs left)", if r then r.DisplayName else kitchen.CurrentRecipeId, kitchen.TimeRemaining or 0)
	else
		statusLbl.Text = string.format("🍳 Kitchen Ready  |  🍽️ %d dish(es) ready to sell", kitchen.ReadyTotal or 0)
	end
	statusLbl.Parent = banner

	makeBtn(
		banner,
		string.format("🍽️ Sell (%d)", kitchen.ReadyTotal or 0),
		if (kitchen.ReadyTotal or 0) > 0 then Color3.fromRGB(48, 186, 86) else Color3.fromRGB(78, 88, 106),
		UDim2.new(1, -152, 0.5, -19),
		UDim2.fromOffset(138, 38),
		function()
			if dispatchAction then
				dispatchAction("ServeFood", nil)
			end
		end
	)

	-- Live Walk-In Customer Order Card (Click to Cook & Print Receipt!)
	local waiting = state.WaitingCustomer
	if typeof(waiting) == "table" and waiting.CustomerName then
		local isCookingOrder = waiting.IsBeingCooked == true
		local orderCard = makeCard(scrollFrame, 76, if isCookingOrder then Color3.fromRGB(242, 148, 38) else Color3.fromRGB(54, 194, 106))
		makeIconBox(orderCard, if isCookingOrder then "🔥" else "🙋", if isCookingOrder then Color3.fromRGB(196, 104, 24) else Color3.fromRGB(36, 146, 78), 14)

		local custTitle = Instance.new("TextLabel")
		custTitle.Position = UDim2.new(0, 74, 0, 10)
		custTitle.Size = UDim2.new(1, -242, 0, 22)
		custTitle.BackgroundTransparency = 1
		custTitle.Font = Enum.Font.GothamBlack
		custTitle.TextXAlignment = Enum.TextXAlignment.Left
		custTitle.TextSize = 15
		custTitle.TextColor3 = Color3.fromRGB(255, 232, 134)
		custTitle.Text = string.format("Customer Order: %s", tostring(waiting.CustomerName))
		custTitle.Parent = orderCard

		local custDesc = Instance.new("TextLabel")
		custDesc.Position = UDim2.new(0, 74, 0, 34)
		custDesc.Size = UDim2.new(1, -242, 0, 32)
		custDesc.BackgroundTransparency = 1
		custDesc.Font = Enum.Font.GothamBold
		custDesc.TextWrapped = true
		custDesc.TextXAlignment = Enum.TextXAlignment.Left
		custDesc.TextSize = 12
		custDesc.TextColor3 = Color3.fromRGB(230, 238, 250)
		custDesc.Text = string.format(
			"Ordered: %s  (+%d Gold • +%d Rep)",
			tostring(waiting.DishName or "House Special"),
			tonumber(waiting.BaseGold) or 25,
			tonumber(waiting.BaseRep) or 5
		)
		custDesc.Parent = orderCard

		makeBtn(
			orderCard,
			if isCookingOrder then "🔥 Cooking..." else "🍳 Cook & Serve",
			if isCookingOrder then Color3.fromRGB(214, 126, 36) else Color3.fromRGB(46, 184, 88),
			UDim2.new(1, -158, 0.5, -19),
			UDim2.fromOffset(144, 38),
			function()
				if not isCookingOrder and dispatchAction then
					dispatchAction("ServeCustomerOrder", nil)
				end
			end
		)
	end

	-- Recipe Cards
	for _, recipeId in ipairs(RecipeConfig.Order) do
		local recipe = RecipeConfig.Recipes[recipeId]
		if recipe then
			local canAfford = restLevel >= recipe.RequiredRestaurantLevel
			local parts: { string } = {}
			for ing, need in pairs(recipe.Ingredients) do
				local have = stock[ing] or 0
				if have < need then
					canAfford = false
				end
				table.insert(parts, string.format("%s %d/%d", ing, have, need))
			end

			local accent = if canAfford then Color3.fromRGB(68, 188, 86) else Color3.fromRGB(108, 118, 138)
			local card = makeCard(scrollFrame, 80, accent)
			makeIconBox(card, recipe.Icon or "🍽️", if canAfford then Color3.fromRGB(46, 126, 62) else Color3.fromRGB(48, 56, 76), 16)

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 74, 0, 10)
			nameLbl.Size = UDim2.new(1, -226, 0, 24)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.GothamBlack
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextSize = 15
			nameLbl.TextColor3 = Color3.new(1, 1, 1)
			nameLbl.Text = string.format("%s   +%d Gold  •  👑 +%d", recipe.DisplayName, recipe.CoinsReward, recipe.ReputationReward)
			nameLbl.Parent = card

			local reqLbl = Instance.new("TextLabel")
			reqLbl.Position = UDim2.new(0, 74, 0, 36)
			reqLbl.Size = UDim2.new(1, -226, 0, 36)
			reqLbl.BackgroundTransparency = 1
			reqLbl.Font = Enum.Font.Gotham
			reqLbl.TextWrapped = true
			reqLbl.TextXAlignment = Enum.TextXAlignment.Left
			reqLbl.TextSize = 12
			reqLbl.TextColor3 = Color3.fromRGB(205, 214, 232)
			reqLbl.Text = "Needs: " .. table.concat(parts, ", ")
			reqLbl.Parent = card

			local btnText = if restLevel < recipe.RequiredRestaurantLevel
				then string.format("🔒 HQ Lv.%d", recipe.RequiredRestaurantLevel)
				elseif kitchen.IsCooking then "⏳ Busy"
				else "🍳 Cook"

			makeBtn(
				card,
				btnText,
				if canAfford and not kitchen.IsCooking then Color3.fromRGB(234, 104, 46) else Color3.fromRGB(76, 84, 100),
				UDim2.new(1, -138, 0.5, -19),
				UDim2.fromOffset(124, 38),
				function()
					if dispatchAction then
						dispatchAction("CookRecipe", recipeId)
					end
				end
			)
		end
	end

	-- Restaurant Receipt Ledger Card (Last 5 Printed Receipts)
	local receipts = state.Receipts
	local receiptCount = if typeof(receipts) == "table" then #receipts else 0
	local ledgerHeight = math.max(82, 42 + math.min(receiptCount, 5) * 20)
	local ledger = makeCard(scrollFrame, ledgerHeight, Color3.fromRGB(246, 206, 92))
	ledger.BackgroundColor3 = Color3.fromRGB(40, 44, 58)

	local ledgerHead = Instance.new("TextLabel")
	ledgerHead.Position = UDim2.new(0, 18, 0, 8)
	ledgerHead.Size = UDim2.new(1, -28, 0, 22)
	ledgerHead.BackgroundTransparency = 1
	ledgerHead.Font = Enum.Font.GothamBlack
	ledgerHead.TextXAlignment = Enum.TextXAlignment.Left
	ledgerHead.TextSize = 14
	ledgerHead.TextColor3 = Color3.fromRGB(255, 226, 114)
	ledgerHead.Text = string.format("RECENT RESTAURANT RECEIPTS (%d)", receiptCount)
	ledgerHead.Parent = ledger

	local lines: { string } = {}
	if typeof(receipts) == "table" and #receipts > 0 then
		for i = 1, math.min(#receipts, 5) do
			local rec = receipts[i]
			if typeof(rec) == "table" then
				table.insert(
					lines,
					string.format(
						"#%d  |  %s  |  %s  |  +%d Gold (+%d Rep)  [%s]",
						tonumber(rec.OrderNo) or i,
						tostring(rec.CustomerName or "Guest"),
						tostring(rec.DishName or "Meal"),
						tonumber(rec.GoldEarned) or 0,
						tonumber(rec.RepEarned) or 0,
						tostring(rec.ChefName or "Chef")
					)
				)
			end
		end
	else
		table.insert(lines, "No receipts printed yet — serve a customer order or press E at your Cash Register!")
	end

	local ledgerBody = Instance.new("TextLabel")
	ledgerBody.Position = UDim2.new(0, 18, 0, 32)
	ledgerBody.Size = UDim2.new(1, -28, 1, -38)
	ledgerBody.BackgroundTransparency = 1
	ledgerBody.Font = Enum.Font.Code
	ledgerBody.TextWrapped = true
	ledgerBody.TextXAlignment = Enum.TextXAlignment.Left
	ledgerBody.TextYAlignment = Enum.TextYAlignment.Top
	ledgerBody.TextSize = 12
	ledgerBody.TextColor3 = Color3.fromRGB(246, 240, 220)
	ledgerBody.Text = table.concat(lines, "\n")
	ledgerBody.Parent = ledger
end

local function renderWarehouses(state: { [string]: any }): ()
	if not scrollFrame then
		return
	end
	local wh = state.Warehouse or {}
	local levels = wh.Levels or {}
	local stock = wh.Stock or {}
	local totals = wh.CategoryTotals or {}
	local caps = wh.Capacities or {}

	for _, category in ipairs(WarehouseConfig.Categories) do
		local spec = WarehouseConfig.Specs[category]
		local level = levels[category] or 0
		local isLocked = (level <= 0)
		local total = totals[category] or 0
		local cap = caps[category] or 0
		local nextTier = WarehouseConfig.Tiers[level + 1]

		local itemStrs: { string } = {}
		for _, ing in ipairs(spec.Ingredients) do
			table.insert(itemStrs, string.format("%s: %d", ing, stock[ing] or 0))
		end

		local card = makeCard(scrollFrame, 92, if isLocked then Color3.fromRGB(108, 118, 138) else spec.AccentColor)
		makeIconBox(card, if isLocked then "🔒" else spec.Icon, if isLocked then Color3.fromRGB(54, 62, 82) else spec.AccentColor, 22)

		local header = Instance.new("TextLabel")
		header.Position = UDim2.new(0, 74, 0, 8)
		header.Size = UDim2.new(1, -335, 0, 22)
		header.BackgroundTransparency = 1
		header.Font = Enum.Font.GothamBlack
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextSize = 15
		header.TextColor3 = if isLocked then Color3.fromRGB(190, 200, 218) else Color3.new(1, 1, 1)
		header.Text = if isLocked
			then string.format("%s %s  (LOCKED)", spec.Icon, spec.DisplayName)
			else string.format("%s  (Lv.%d • %d/%d)", spec.DisplayName, level, total, cap)
		header.Parent = card

		local detail = Instance.new("TextLabel")
		detail.Position = UDim2.new(0, 74, 0, 32)
		detail.Size = UDim2.new(1, -335, 0, 22)
		detail.BackgroundTransparency = 1
		detail.Font = Enum.Font.Gotham
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.TextSize = 12
		detail.TextColor3 = Color3.fromRGB(205, 214, 232)
		detail.Text = if isLocked
			then ("Stores: " .. table.concat(spec.Ingredients, ", ") .. " — Build to unlock!")
			else table.concat(itemStrs, "  |  ")
		detail.Parent = card

		-- Visual Storage Fill Bar for Unlocked Warehouses
		if not isLocked then
			local barBg = Instance.new("Frame")
			barBg.Position = UDim2.new(0, 74, 0, 62)
			barBg.Size = UDim2.new(1, -345, 0, 12)
			barBg.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
			barBg.Parent = card
			makeCorner(barBg, 6)

			local fillFrac = if cap > 0 then math.clamp(total / cap, 0, 1) else 0
			local barFill = Instance.new("Frame")
			barFill.Size = UDim2.fromScale(fillFrac, 1)
			barFill.BackgroundColor3 = spec.AccentColor
			barFill.Parent = barBg
			makeCorner(barFill, 6)
		end

		if isLocked then
			makeBtn(
				card,
				string.format("🔨 Build (%d G)", spec.UnlockCost),
				Color3.fromRGB(48, 184, 92),
				UDim2.new(1, -178, 0.5, -20),
				UDim2.fromOffset(164, 40),
				function()
					if dispatchAction then
						dispatchAction("UpgradeWarehouse", category)
					end
				end
			)
		else
			makeBtn(
				card,
				"🔄 Move",
				Color3.fromRGB(82, 96, 124),
				UDim2.new(1, -252, 0.5, -19),
				UDim2.fromOffset(88, 38),
				function()
					if dispatchAction then
						dispatchAction("MoveWarehouse", category)
					end
				end
			)
			makeBtn(
				card,
				if nextTier then string.format("⬆️ %d Gold", nextTier.UpgradeCost) else "✅ MAX",
				if nextTier then spec.AccentColor else Color3.fromRGB(78, 86, 102),
				UDim2.new(1, -156, 0.5, -19),
				UDim2.fromOffset(142, 38),
				function()
					if dispatchAction then
						dispatchAction("UpgradeWarehouse", category)
					end
				end
			)
		end
	end
end

local function renderUpgrades(state: { [string]: any }): ()
	if not scrollFrame then
		return
	end
	local profile = state.Profile or {}
	local restLv = profile.RestaurantLevel or 1
	local defLv = profile.DefenseLevel or 1
	local crewCount = profile.CrewCount or 0
	local maxCrew = state.MaxCrew or 2
	local nextCrewCost = state.NextCrewCost or 180

	-- 1. Restaurant HQ Upgrade
	do
		local nextTier = RecipeConfig.RestaurantTiers[restLv + 1]
		local card = makeCard(scrollFrame, 86, Color3.fromRGB(238, 128, 48))
		makeIconBox(card, "🏰", Color3.fromRGB(206, 98, 32), 19)

		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, 74, 0, 10)
		lbl.Size = UDim2.new(1, -238, 0, 24)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextSize = 15
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.Text = string.format("Restaurant HQ  (Lv.%d / %d)", restLv, RecipeConfig.MaxRestaurantLevel)
		lbl.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Position = UDim2.new(0, 74, 0, 36)
		desc.Size = UDim2.new(1, -238, 0, 42)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextSize = 12
		desc.TextColor3 = Color3.fromRGB(210, 220, 238)
		desc.Text = "Boosts dish Gold payout, cooking speed, Max Crew & unlocks Emperor's Platter!"
		desc.TextWrapped = true
		desc.Parent = card

		makeBtn(
			card,
			if nextTier then string.format("⬆️ %d Gold", nextTier.UpgradeCost) else "✅ MAX",
			if nextTier then Color3.fromRGB(238, 128, 48) else Color3.fromRGB(78, 86, 102),
			UDim2.new(1, -156, 0.5, -19),
			UDim2.fromOffset(142, 38),
			function()
				if dispatchAction then
					dispatchAction("UpgradeRestaurant", nil)
				end
			end
		)
	end

	-- 2. Hire Crew Chef
	do
		local canHire = crewCount < maxCrew
		local card = makeCard(scrollFrame, 86, Color3.fromRGB(58, 184, 108))
		makeIconBox(card, "👨‍🍳", Color3.fromRGB(38, 146, 82), 19)

		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, 74, 0, 10)
		lbl.Size = UDim2.new(1, -238, 0, 24)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextSize = 15
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.Text = string.format("Hire Crew Chefs  (%d / %d)", crewCount, maxCrew)
		lbl.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Position = UDim2.new(0, 74, 0, 36)
		desc.Size = UDim2.new(1, -238, 0, 42)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextSize = 12
		desc.TextColor3 = Color3.fromRGB(210, 220, 238)
		desc.Text = "+15% faster cooking per chef & automatically sells cooked food for you!"
		desc.TextWrapped = true
		desc.Parent = card

		makeBtn(
			card,
			if canHire then string.format("Hire (%d G)", nextCrewCost) else "✅ MAX",
			if canHire then Color3.fromRGB(58, 184, 108) else Color3.fromRGB(78, 86, 102),
			UDim2.new(1, -156, 0.5, -19),
			UDim2.fromOffset(142, 38),
			function()
				if dispatchAction then
					dispatchAction("HireCrew", nil)
				end
			end
		)
	end

	-- 3. Castle Defenses
	do
		local nextCost = DEFENSE_COSTS[defLv + 1]
		local card = makeCard(scrollFrame, 86, Color3.fromRGB(152, 72, 224))
		makeIconBox(card, "🛡️", Color3.fromRGB(112, 46, 178), 19)

		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, 74, 0, 10)
		lbl.Size = UDim2.new(1, -238, 0, 24)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextSize = 15
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.Text = string.format("Castle Defenses  (Tier %d / 3)", defLv)
		lbl.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Position = UDim2.new(0, 74, 0, 36)
		desc.Size = UDim2.new(1, -238, 0, 42)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextSize = 12
		desc.TextColor3 = Color3.fromRGB(210, 220, 238)
		desc.Text = "Mounts Watchtower Turrets (T2) & Golden Emperor Shield Arch (T3) to repel Rival AI!"
		desc.TextWrapped = true
		desc.Parent = card

		makeBtn(
			card,
			if nextCost then string.format("⬆️ %d Gold", nextCost) else "✅ MAX",
			if nextCost then Color3.fromRGB(152, 72, 224) else Color3.fromRGB(78, 86, 102),
			UDim2.new(1, -156, 0.5, -19),
			UDim2.fromOffset(142, 38),
			function()
				if dispatchAction then
					dispatchAction("UpgradeDefenses", nil)
				end
			end
		)
	end

	-- 4. Sport Delivery Motorbike (Dual Purchase Options: Gold Coins OR Robux!)
	do
		local ownsBike = state.OwnsMotorbike == true
		local coinCost = state.MotorbikeCoinCost or 450
		local bikeSpec = MonetizationConfig.Items.DeliveryMotorbike
		local robuxPrice = if bikeSpec then bikeSpec.RobuxPrice else 79
		local card = makeCard(scrollFrame, 96, Color3.fromRGB(42, 174, 184))
		makeIconBox(card, "🛵", Color3.fromRGB(28, 132, 146), 24)

		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, 74, 0, 8)
		lbl.Size = UDim2.new(1, -305, 0, 24)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextSize = 15
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.Text = "Sport Delivery Motorbike (Press V)"
		lbl.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Position = UDim2.new(0, 74, 0, 34)
		desc.Size = UDim2.new(1, -305, 0, 52)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextSize = 12
		desc.TextColor3 = Color3.fromRGB(210, 220, 238)
		desc.Text = "42 Speed realistic motorbike with spinning alloy wheels, corner lean & seated rider! Buy with Gold OR Robux."
		desc.TextWrapped = true
		desc.Parent = card

		if ownsBike then
			makeBtn(
				card,
				"✅ OWNED (Ride V)",
				Color3.fromRGB(48, 178, 92),
				UDim2.new(1, -172, 0.5, -20),
				UDim2.fromOffset(158, 40),
				function()
					if dispatchAction then
						dispatchAction("ToggleScooter", nil)
					end
				end
			)
		else
			makeBtn(
				card,
				string.format("%d Gold", coinCost),
				Color3.fromRGB(224, 152, 24),
				UDim2.new(1, -226, 0.5, -20),
				UDim2.fromOffset(102, 40),
				function()
					if dispatchAction then
						dispatchAction("BuyMotorbikeCoins", nil)
					end
				end
			)
			local rBtn = makeBtn(
				card,
				string.format("R$ %d", robuxPrice),
				Color3.fromRGB(44, 182, 88),
				UDim2.new(1, -116, 0.5, -20),
				UDim2.fromOffset(102, 40),
				function()
					if dispatchAction then
						dispatchAction("BuyRobuxItem", "DeliveryMotorbike")
					end
				end
			)
			makeStroke(rBtn, Color3.fromRGB(255, 224, 96), 1.8)
		end
	end

	-- 5. Empire Raider Chefs (March Out & Capture Neutral / Rival Territories For You!)
	do
		local raiderCount = state.RaiderCount or 0
		local maxRaiders = state.MaxRaiders or 2
		local nextCost = state.NextRaiderCost
		local squadSpec = MonetizationConfig.Items.RaiderChefSquad
		local robuxPrice = if squadSpec then squadSpec.RobuxPrice else 99
		local card = makeCard(scrollFrame, 96, Color3.fromRGB(232, 74, 88))
		makeIconBox(card, "⚔️", Color3.fromRGB(184, 42, 56), 24)

		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, 74, 0, 8)
		lbl.Size = UDim2.new(1, -305, 0, 24)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextSize = 15
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.Text = string.format("Empire Raider Chefs (%d / %d)", raiderCount, maxRaiders)
		lbl.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Position = UDim2.new(0, 74, 0, 34)
		desc.Size = UDim2.new(1, -305, 0, 52)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextSize = 12
		desc.TextColor3 = Color3.fromRGB(210, 220, 238)
		desc.Text = "Full-body team chefs who march out to CAPTURE Neutral & Rival territories and duel Rival Chefs for you!"
		desc.TextWrapped = true
		desc.Parent = card

		if raiderCount >= maxRaiders or not nextCost then
			makeBtn(
				card,
				"✅ SQUAD ACTIVE",
				Color3.fromRGB(48, 178, 92),
				UDim2.new(1, -172, 0.5, -20),
				UDim2.fromOffset(158, 40),
				function() end
			)
		else
			makeBtn(
				card,
				string.format("%d Gold", nextCost),
				Color3.fromRGB(224, 152, 24),
				UDim2.new(1, -226, 0.5, -20),
				UDim2.fromOffset(102, 40),
				function()
					if dispatchAction then
						dispatchAction("HireRaider", nil)
					end
				end
			)
			local rBtn = makeBtn(
				card,
				string.format("R$ %d (2x)", robuxPrice),
				Color3.fromRGB(44, 182, 88),
				UDim2.new(1, -116, 0.5, -20),
				UDim2.fromOffset(102, 40),
				function()
					if dispatchAction then
						dispatchAction("BuyRobuxItem", "RaiderChefSquad")
					end
				end
			)
			makeStroke(rBtn, Color3.fromRGB(255, 224, 96), 1.8)
		end
	end

	-- 6. Loyal Bodyguard Protectors (Follow YOU & Defend You from Mafia & Rival Chefs!)
	do
		local guardCount = state.BodyguardCount or 0
		local maxGuards = state.MaxBodyguards or 2
		local nextCost = state.NextBodyguardCost
		local card = makeCard(scrollFrame, 94, Color3.fromRGB(48, 152, 238))
		makeIconBox(card, "🛡️", Color3.fromRGB(28, 102, 186), 23)

		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, 74, 0, 8)
		lbl.Size = UDim2.new(1, -242, 0, 24)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextSize = 15
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.Text = string.format("Bodyguard Protectors (%d / %d)", guardCount, maxGuards)
		lbl.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Position = UDim2.new(0, 74, 0, 34)
		desc.Size = UDim2.new(1, -242, 0, 52)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextSize = 12
		desc.TextColor3 = Color3.fromRGB(210, 220, 238)
		desc.Text = "Loyal 240 HP armed guards who follow YOU everywhere & automatically fight off Mafia & Rival Chefs if they attack you!"
		desc.TextWrapped = true
		desc.Parent = card

		makeBtn(
			card,
			if nextCost then string.format("Hire (%d G)", nextCost) else "✅ MAX GUARDS",
			if nextCost then Color3.fromRGB(48, 152, 238) else Color3.fromRGB(78, 86, 102),
			UDim2.new(1, -158, 0.5, -20),
			UDim2.fromOffset(144, 40),
			function()
				if nextCost and dispatchAction then
					dispatchAction("HireBodyguard", nil)
				end
			end
		)
	end

	-- 7. Stealth Food Delivery Runner NPC -> Central Park (Don't let Rivals see him!)
	do
		local isActive = state.DeliveryRunnerActive == true
		local cd = state.DeliveryRunnerCooldown or 0
		local card = makeCard(scrollFrame, 94, Color3.fromRGB(54, 196, 118))
		makeIconBox(card, "📦", Color3.fromRGB(36, 146, 82), 23)

		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, 74, 0, 8)
		lbl.Size = UDim2.new(1, -242, 0, 24)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextSize = 15
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.Text = "Stealth Delivery Runner -> Central Park"
		lbl.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Position = UDim2.new(0, 74, 0, 34)
		desc.Size = UDim2.new(1, -242, 0, 52)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextSize = 12
		desc.TextColor3 = Color3.fromRGB(210, 220, 238)
		desc.Text = "Sends your Delivery NPC into Central Park (+165G)! If Rival Chefs or Mafia see him they will fight him — escort with Bodyguards!"
		desc.TextWrapped = true
		desc.Parent = card

		local btnText = if isActive then "🏃 EN ROUTE..." elseif cd > 0 then string.format("⏳ Ready %ds", cd) else "📦 Send Runner!"
		makeBtn(
			card,
			btnText,
			if not isActive and cd <= 0 then Color3.fromRGB(46, 186, 98) else Color3.fromRGB(78, 86, 102),
			UDim2.new(1, -158, 0.5, -20),
			UDim2.fromOffset(144, 40),
			function()
				if not isActive and cd <= 0 and dispatchAction then
					dispatchAction("DispatchDeliveryRunner", nil)
				end
			end
		)
	end
end

local function renderShop(state: { [string]: any }): ()
	if not scrollFrame then
		return
	end
	local owned = state.OwnedPasses or {}

	local intro = makeCard(scrollFrame, 50, Color3.fromRGB(246, 186, 42))
	local introLbl = Instance.new("TextLabel")
	introLbl.Position = UDim2.new(0, 18, 0, 6)
	introLbl.Size = UDim2.new(1, -28, 1, -12)
	introLbl.BackgroundTransparency = 1
	introLbl.Font = Enum.Font.GothamBold
	introLbl.TextWrapped = true
	introLbl.TextXAlignment = Enum.TextXAlignment.Left
	introLbl.TextSize = 13
	introLbl.TextColor3 = Color3.fromRGB(255, 232, 148)
	introLbl.Text = "💎 Grow your Food Empire faster! Hire a Golden Pro Chef, Elite Staff, or 2x Boosts with Robux."
	introLbl.Parent = intro

	for _, itemId in ipairs(MonetizationConfig.Order) do
		local spec = MonetizationConfig.Items[itemId]
		if spec then
			local isBike = (itemId == "DeliveryMotorbike")
			local isOwned = (spec.Kind == "GamePass" and owned[itemId] == true) or (isBike and state.OwnsMotorbike == true)
			local card = makeCard(scrollFrame, 96, spec.AccentColor)
			makeIconBox(card, SHOP_ICONS[itemId] or "💎", spec.AccentColor, 24)

			local badge = Instance.new("TextLabel")
			badge.Position = UDim2.new(0, 74, 0, 8)
			badge.Size = UDim2.fromOffset(102, 18)
			badge.BackgroundColor3 = spec.AccentColor
			badge.Font = Enum.Font.GothamBlack
			badge.Text = spec.Badge
			badge.TextSize = 10
			badge.TextColor3 = Color3.new(1, 1, 1)
			badge.Parent = card
			makeCorner(badge, 6)

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 182, 0, 5)
			nameLbl.Size = UDim2.new(1, if isBike and not isOwned then -412 else -342, 0, 24)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.GothamBlack
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextSize = 15
			nameLbl.TextColor3 = Color3.new(1, 1, 1)
			nameLbl.Text = spec.DisplayName
			nameLbl.Parent = card

			local descLbl = Instance.new("TextLabel")
			descLbl.Position = UDim2.new(0, 74, 0, 32)
			descLbl.Size = UDim2.new(1, if isBike and not isOwned then -310 else -236, 0, 56)
			descLbl.BackgroundTransparency = 1
			descLbl.Font = Enum.Font.Gotham
			descLbl.TextWrapped = true
			descLbl.TextXAlignment = Enum.TextXAlignment.Left
			descLbl.TextYAlignment = Enum.TextYAlignment.Top
			descLbl.TextSize = 12
			descLbl.TextColor3 = Color3.fromRGB(214, 224, 242)
			descLbl.Text = spec.Description
			descLbl.Parent = card

			if isBike and not isOwned then
				local coinCost = state.MotorbikeCoinCost or 450
				makeBtn(
					card,
					string.format("%d Gold", coinCost),
					Color3.fromRGB(224, 152, 24),
					UDim2.new(1, -226, 0.5, -21),
					UDim2.fromOffset(102, 42),
					function()
						if dispatchAction then
							dispatchAction("BuyMotorbikeCoins", nil)
						end
					end
				)
				local rBtn = makeBtn(
					card,
					string.format("R$ %d", spec.RobuxPrice),
					Color3.fromRGB(44, 182, 88),
					UDim2.new(1, -116, 0.5, -21),
					UDim2.fromOffset(102, 42),
					function()
						if dispatchAction then
							dispatchAction("BuyRobuxItem", itemId)
						end
					end
				)
				makeStroke(rBtn, Color3.fromRGB(255, 224, 96), 1.8)
			else
				local btn = makeBtn(
					card,
					if isOwned then "✅ OWNED" else string.format("R$ %d", spec.RobuxPrice),
					if isOwned then Color3.fromRGB(78, 86, 102) else Color3.fromRGB(44, 182, 88),
					UDim2.new(1, -152, 0.5, -21),
					UDim2.fromOffset(138, 42),
					function()
						if not isOwned and dispatchAction then
							dispatchAction("BuyRobuxItem", itemId)
						end
					end
				)
				if not isOwned then
					makeStroke(btn, Color3.fromRGB(255, 224, 96), 1.8)
				end
			end
		end
	end
end

local BLACK_MARKET_CATALOG = {
	{ Id = "StreetPistol",  Name = "Street Pistol",      Icon = "🔫", Price = 250, Kind = "Weapon",     Desc = "Semi-auto sidearm (32 DMG, 95 range). Equip from hotbar & click to shoot Rivals & Mafia!", Accent = Color3.fromRGB(142, 152, 174) },
	{ Id = "PepperShotgun", Name = "Pepper Shotgun",     Icon = "💥", Price = 550, Kind = "Weapon",     Desc = "4-pellet scattergun (96 burst DMG!). Shreds Mafia Enforcers & Rival Chefs up close!", Accent = Color3.fromRGB(238, 92, 48) },
	{ Id = "TacticalSMG",   Name = "Tactical SMG",       Icon = "🔥", Price = 950, Kind = "Weapon",     Desc = "Hold-to-fire automatic SMG (22 DMG, rapid fire, 100 range). Melts Mafia Bosses!", Accent = Color3.fromRGB(238, 174, 38) },
	{ Id = "KevlarVest",    Name = "Kevlar Chef Armor",  Icon = "🛡️", Price = 420, Kind = "Armor",      Desc = "+100 Breakable Tactical Armor Shield! Absorbs bullet & melee hits until it breaks — rebuy anytime at Black Market!", Accent = Color3.fromRGB(48, 158, 232) },
	{ Id = "Medkit",        Name = "Flash-Spice Medkit", Icon = "💊", Price = 150, Kind = "Consumable", Desc = "Instant 100% Full Heal + 6-second speed surge! Buy anytime you're injured.", Accent = Color3.fromRGB(54, 196, 108) },
}

local function renderBlackMarket(state: { [string]: any }): ()
	if not scrollFrame then return end
	local bm = state.BlackMarket or {}
	local ownedWeapons = bm.OwnedWeapons or {}
	local currentArmor = if typeof(bm.Armor) == "number" then bm.Armor else 0

	-- Top Warp Banner leading the user directly to the physical 3D Black Market Alley!
	local warpCard = makeCard(scrollFrame, 64, Color3.fromRGB(218, 42, 68))
	warpCard.BackgroundColor3 = Color3.fromRGB(44, 24, 34)
	local wLbl = Instance.new("TextLabel")
	wLbl.Position = UDim2.new(0, 18, 0, 8)
	wLbl.Size = UDim2.new(1, -210, 1, -16)
	wLbl.BackgroundTransparency = 1
	wLbl.Font = Enum.Font.GothamBold
	wLbl.TextWrapped = true
	wLbl.TextXAlignment = Enum.TextXAlignment.Left
	wLbl.TextSize = 13
	wLbl.TextColor3 = Color3.fromRGB(255, 212, 220)
	wLbl.Text = "🕶️ Underground Arms Market — Buy guns & Kevlar armor to fight armed Rival Chefs & Food Mafia!"
	wLbl.Parent = warpCard

	makeBtn(
		warpCard,
		"📍 Go to Black Market",
		Color3.fromRGB(206, 42, 68),
		UDim2.new(1, -184, 0.5, -19),
		UDim2.fromOffset(170, 38),
		function()
			if modalFrame then modalFrame.Visible = false end
			if dispatchAction then
				dispatchAction("TeleportBlackMarket", nil)
			end
		end
	)

	for _, item in ipairs(BLACK_MARKET_CATALOG) do
		local isWeaponOwned = (item.Kind == "Weapon" and ownedWeapons[item.Id] == true)
		local isArmorFull = (item.Kind == "Armor" and currentArmor >= 100)
		local isOwned = isWeaponOwned or isArmorFull
		local card = makeCard(scrollFrame, 88, item.Accent)
		makeIconBox(card, item.Icon, item.Accent, 20)

		local nLbl = Instance.new("TextLabel")
		nLbl.Position = UDim2.new(0, 74, 0, 10)
		nLbl.Size = UDim2.new(1, -238, 0, 24)
		nLbl.BackgroundTransparency = 1
		nLbl.Font = Enum.Font.GothamBlack
		nLbl.TextXAlignment = Enum.TextXAlignment.Left
		nLbl.TextSize = 15
		nLbl.TextColor3 = Color3.new(1, 1, 1)
		nLbl.Text = if item.Kind == "Armor"
			then string.format("%s (%d / 100)", item.Name, currentArmor)
			else item.Name
		nLbl.Parent = card

		local dLbl = Instance.new("TextLabel")
		dLbl.Position = UDim2.new(0, 74, 0, 34)
		dLbl.Size = UDim2.new(1, -238, 0, 44)
		dLbl.BackgroundTransparency = 1
		dLbl.Font = Enum.Font.Gotham
		dLbl.TextWrapped = true
		dLbl.TextXAlignment = Enum.TextXAlignment.Left
		dLbl.TextSize = 12
		dLbl.TextColor3 = Color3.fromRGB(210, 218, 236)
		dLbl.Text = item.Desc
		dLbl.Parent = card

		local btnText = if isWeaponOwned
			then "✅ EQUIP"
			elseif isArmorFull then "✅ FULL (100)"
			elseif item.Kind == "Armor" and currentArmor > 0 then string.format("Refill (%d G)", item.Price)
			else string.format("Buy (%d G)", item.Price)
		makeBtn(
			card,
			btnText,
			if isOwned then Color3.fromRGB(52, 168, 92) else Color3.fromRGB(214, 48, 68),
			UDim2.new(1, -156, 0.5, -19),
			UDim2.fromOffset(142, 38),
			function()
				if dispatchAction then
					dispatchAction("BuyBlackMarketItem", item.Id)
				end
			end
		)
	end
end

local function render(): ()
	if not modalFrame or not modalFrame.Visible or not latestState then
		return
	end
	clearScroll()
	refreshTabStyles()
	if titleLabel then
		local titleMap: { [MenuTab]: string } = {
			Kitchen = "🍳 KITCHEN & COOKING",
			Warehouses = "📦 WAREHOUSES & STORAGE",
			Upgrades = "⬆️ EMPIRE UPGRADES",
			BlackMarket = "🕶️ UNDERGROUND BLACK MARKET",
			Shop = "💎 PRO CHEF & ROBUX SHOP",
		}
		titleLabel.Text = titleMap[currentTab] or "FOOD EMPIRE"
	end
	if currentTab == "Kitchen" then
		renderKitchen(latestState)
	elseif currentTab == "Warehouses" then
		renderWarehouses(latestState)
	elseif currentTab == "BlackMarket" then
		renderBlackMarket(latestState)
	elseif currentTab == "Shop" then
		renderShop(latestState)
	else
		renderUpgrades(latestState)
	end
end

function EmpireMenuController.Init(parentGui: ScreenGui, onAction: ActionCallback): ()
	dispatchAction = onAction

	local modal = Instance.new("Frame")
	modal.Name = "EmpireMenuModal"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.fromOffset(664, 476)
	modal.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
	modal.Visible = false
	modal.Parent = parentGui
	makeCorner(modal, 16)
	makeStroke(modal, Color3.fromRGB(248, 196, 56), 2.2)
	modalFrame = modal

	local header = Instance.new("TextLabel")
	header.Position = UDim2.new(0, 20, 0, 12)
	header.Size = UDim2.new(1, -80, 0, 32)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBlack
	header.Text = "FOOD EMPIRE"
	header.TextSize = 19
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Color3.fromRGB(255, 224, 96)
	header.Parent = modal
	titleLabel = header

	makeBtn(modal, "X", Color3.fromRGB(214, 58, 66), UDim2.new(1, -48, 0, 10), UDim2.fromOffset(36, 34), function()
		modal.Visible = false
	end)

	-- 1-Click Top Tab Switcher Bar inside the Modal!
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Position = UDim2.new(0, 16, 0, 50)
	tabBar.Size = UDim2.new(1, -32, 0, 36)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = modal

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.Parent = tabBar

	local tabs: { { Id: MenuTab, Label: string } } = {
		{ Id = "Kitchen", Label = "🍳 Kitchen" },
		{ Id = "Warehouses", Label = "📦 Storage" },
		{ Id = "Upgrades", Label = "⬆️ Empire" },
		{ Id = "BlackMarket", Label = "🕶️ Market" },
		{ Id = "Shop", Label = "R$ Shop" },
	}
	for _, t in ipairs(tabs) do
		local tb = makeBtn(tabBar, t.Label, Color3.fromRGB(40, 48, 68), UDim2.new(), UDim2.fromOffset(120, 34), function()
			currentTab = t.Id
			render()
		end)
		tabButtons[t.Id] = tb
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.new(0, 16, 0, 96)
	scroll.Size = UDim2.new(1, -32, 1, -110)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ScrollBarThickness = 6
	scroll.Parent = modal

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.Parent = scroll
	scrollFrame = scroll
end

function EmpireMenuController.ToggleTab(tab: MenuTab): ()
	if not modalFrame then
		return
	end
	if modalFrame.Visible and currentTab == tab then
		modalFrame.Visible = false
		return
	end
	currentTab = tab
	modalFrame.Visible = true
	render()
end

function EmpireMenuController.Update(state: { [string]: any }): ()
	latestState = state
	render()
end

return EmpireMenuController
