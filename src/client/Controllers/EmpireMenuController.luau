--!strict

-- Refined Dark-Mafia Empire Menu & Black Market Controller.
-- Minimalist, intimidating obsidian/charcoal palette, crisp typographic hierarchy,
-- real 3D ViewportFrame previews via ModelPreviewHelper, zero emojis, zero neon borders.

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
local WeaponConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WeaponConfig")
)
local BodyguardConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("BodyguardConfig")
)
local ModelPreviewHelper = require("./ModelPreviewHelper")

export type MenuTab = "Kitchen" | "Warehouses" | "Upgrades" | "BlackMarket" | "Shop"
export type ActionCallback = (action: string, arg: any?) -> ()
type BlackMarketSubTab = "Weapons" | "Ammo" | "Bodyguards" | "Premium"
type WeaponFilter = "All" | "Pistol" | "Shotgun" | "SMG" | "AssaultRifle" | "Sniper" | "Gear"
type GuardViewMode = "Classes" | "Gear"
type GuardGearFilter = "All" | "Armor" | "Helmet" | "Outfit" | "Weapon" | "Attachment" | "Tactical"

local EmpireMenuController = {}

-- Restrained Dark Mafia Palette
local C_BG_MODAL = Color3.fromRGB(13, 14, 18)
local C_BG_CARD = Color3.fromRGB(19, 21, 26)
local C_BG_CARD_ALT = Color3.fromRGB(23, 25, 31)
local C_BG_SUBTLE = Color3.fromRGB(27, 30, 37)
local C_BORDER = Color3.fromRGB(42, 46, 54)
local C_BORDER_STRONG = Color3.fromRGB(68, 72, 82)
local C_TEXT_PRIMARY = Color3.fromRGB(234, 231, 224)
local C_TEXT_MUTED = Color3.fromRGB(150, 154, 164)
local C_TEXT_DIM = Color3.fromRGB(108, 112, 122)
local C_OXBLOOD = Color3.fromRGB(134, 28, 36)
local C_OXBLOOD_DARK = Color3.fromRGB(82, 22, 28)
local C_BRASS = Color3.fromRGB(168, 138, 76)
local C_STEEL = Color3.fromRGB(66, 76, 92)
local C_OWNED = Color3.fromRGB(48, 86, 62)
local C_ROBUX = Color3.fromRGB(36, 94, 62)
local C_DISABLED = Color3.fromRGB(38, 41, 49)

local DEFENSE_COSTS: { [number]: number } = { [2] = 500, [3] = 1200 }

local BLACK_MARKET_ROBUX_IDS = {
	"GoldenEmperorPistolPass",
	"CrimsonDragonARPass",
	"BossBodyguardPass",
	"GoldenEmperorSuitPass",
	"TacticalAmmoCrate",
	"SyndicateArmorBundle",
}

local RARITY_MUTED_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(72, 76, 86),
	Uncommon = Color3.fromRGB(54, 92, 68),
	Rare = Color3.fromRGB(52, 78, 108),
	Epic = Color3.fromRGB(86, 58, 104),
	Legendary = Color3.fromRGB(136, 106, 52),
	Mythic = Color3.fromRGB(134, 30, 38),
}

local modalFrame: Frame? = nil
local titleLabel: TextLabel? = nil
local subtitleLabel: TextLabel? = nil
local scrollFrame: ScrollingFrame? = nil
local confirmOverlay: Frame? = nil
local confirmTitleLbl: TextLabel? = nil
local confirmDescLbl: TextLabel? = nil
local confirmYesBtn: TextButton? = nil
local pendingConfirmCallback: (() -> ())? = nil
local tabButtons: { [MenuTab]: TextButton } = {}
local currentTab: MenuTab = "Kitchen"
local currentBMSubTab: BlackMarketSubTab = "Weapons"
local currentWeaponFilter: WeaponFilter = "All"
local currentGuardView: GuardViewMode = "Classes"
local currentGuardGearFilter: GuardGearFilter = "All"
local selectedGuardSlot: number = 1
local latestState: { [string]: any }? = nil
local dispatchAction: ActionCallback? = nil

local function makeCorner(parent: Instance, radius: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeStroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = color
	st.Thickness = thickness
	st.Parent = parent
	return st
end

local function makeCard(parent: Instance, height: number, accentBar: Color3?): Frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -6, 0, height)
	card.BackgroundColor3 = C_BG_CARD
	card.BorderSizePixel = 0
	card.Parent = parent
	makeCorner(card, 6)
	makeStroke(card, C_BORDER, 1)

	if accentBar then
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0, 3, 1, -12)
		bar.Position = UDim2.new(0, 0, 0, 6)
		bar.BackgroundColor3 = accentBar
		bar.BorderSizePixel = 0
		bar.Parent = card
	end

	return card
end

local function makeMonogramBox(parent: Instance, tagText: string, accent: Color3, yPos: number): TextLabel
	local box = Instance.new("TextLabel")
	box.Position = UDim2.new(0, 14, 0, yPos)
	box.Size = UDim2.fromOffset(52, 52)
	box.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
	box.Font = Enum.Font.GothamBlack
	box.Text = tagText
	box.TextSize = 13
	box.TextColor3 = C_TEXT_PRIMARY
	box.Parent = parent
	makeCorner(box, 5)
	makeStroke(box, accent, 1)
	return box
end

local function makeBtn(parent: Instance, text: string, bg: Color3, pos: UDim2, size: UDim2, onClick: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.Position = pos
	btn.Size = size
	btn.BackgroundColor3 = bg
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.GothamBold
	btn.Text = text
	btn.TextSize = 12
	btn.TextColor3 = C_TEXT_PRIMARY
	btn.Parent = parent
	makeCorner(btn, 5)
	local stroke = makeStroke(btn, C_BORDER_STRONG, 1)

	local baseBg = bg
	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = baseBg:Lerp(Color3.new(1, 1, 1), 0.08)
		stroke.Color = Color3.fromRGB(120, 124, 136)
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = baseBg
		stroke.Color = C_BORDER_STRONG
	end)
	btn.MouseButton1Click:Connect(onClick)
	return btn
end

local function makeTag(parent: Instance, text: string, bg: Color3, pos: UDim2, size: UDim2): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Position = pos
	lbl.Size = size
	lbl.BackgroundColor3 = bg
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = text
	lbl.TextSize = 9
	lbl.TextColor3 = C_TEXT_PRIMARY
	lbl.Parent = parent
	makeCorner(lbl, 3)
	return lbl
end

local function hideConfirmDialog(): ()
	pendingConfirmCallback = nil
	if confirmOverlay then
		confirmOverlay.Visible = false
	end
end

local function showConfirmDialog(titleText: string, detailText: string, btnLabel: string, btnColor: Color3, onConfirm: () -> ()): ()
	if not confirmOverlay or not confirmTitleLbl or not confirmDescLbl or not confirmYesBtn then
		onConfirm()
		return
	end
	pendingConfirmCallback = onConfirm
	confirmTitleLbl.Text = titleText
	confirmDescLbl.Text = detailText
	confirmYesBtn.Text = btnLabel
	confirmYesBtn.BackgroundColor3 = btnColor
	confirmOverlay.Visible = true
end

local render: () -> ()

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
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if active then
			btn.BackgroundColor3 = if tabName == "BlackMarket"
				then C_OXBLOOD
				elseif tabName == "Shop" then C_ROBUX
				else C_BG_SUBTLE
			btn.TextColor3 = C_TEXT_PRIMARY
			if stroke then
				stroke.Color = if tabName == "Shop" then C_BRASS else Color3.fromRGB(168, 166, 160)
			end
		else
			btn.BackgroundColor3 = C_BG_CARD
			btn.TextColor3 = C_TEXT_MUTED
			if stroke then
				stroke.Color = C_BORDER
			end
		end
	end
end

local function renderKitchen(state: { [string]: any }): ()
	if not scrollFrame then return end
	local stock = (state.Warehouse and state.Warehouse.Stock) or {}
	local kitchen = state.Kitchen or {}
	local restLevel = (state.Profile and state.Profile.RestaurantLevel) or 1
	local starInfo = state.StarRating
	local starCount = if typeof(starInfo) == "table" and typeof(starInfo.Stars) == "number" then starInfo.Stars else 1
	local starTitle = if typeof(starInfo) == "table" and typeof(starInfo.Title) == "string" then starInfo.Title else "1-STAR STREET DINER"
	local starBonus = if typeof(starInfo) == "table" and typeof(starInfo.BonusPct) == "number" then starInfo.BonusPct else 0

	local starBar = makeCard(scrollFrame, 42, C_BRASS)
	local starLbl = Instance.new("TextLabel")
	starLbl.Position = UDim2.new(0, 16, 0, 6)
	starLbl.Size = UDim2.new(1, -32, 1, -12)
	starLbl.BackgroundTransparency = 1
	starLbl.Font = Enum.Font.GothamBlack
	starLbl.TextXAlignment = Enum.TextXAlignment.Left
	starLbl.TextSize = 12
	starLbl.TextColor3 = C_BRASS
	starLbl.Text = string.format(
		"RATING: %s (%d / 5 STARS)  |  +%d%% DISH GOLD & REP  |  VIP CRITICS AT 2+ STARS",
		starTitle,
		starCount,
		starBonus
	)
	starLbl.Parent = starBar

	local banner = makeCard(scrollFrame, 56, C_BRASS)
	local statusLbl = Instance.new("TextLabel")
	statusLbl.Position = UDim2.new(0, 16, 0, 8)
	statusLbl.Size = UDim2.new(1, -172, 1, -16)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Font = Enum.Font.GothamBold
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.TextSize = 13
	statusLbl.TextColor3 = C_TEXT_PRIMARY
	if kitchen.IsCooking and kitchen.CurrentRecipeId then
		local r = RecipeConfig.Recipes[kitchen.CurrentRecipeId]
		statusLbl.Text = string.format("COOKING %s  |  %.1fs REMAINING", string.upper(if r then r.DisplayName else kitchen.CurrentRecipeId), kitchen.TimeRemaining or 0)
	else
		statusLbl.Text = string.format("KITCHEN READY  |  %d DISHES READY TO SERVE", kitchen.ReadyTotal or 0)
	end
	statusLbl.Parent = banner

	makeBtn(
		banner,
		string.format("SELL (%d)", kitchen.ReadyTotal or 0),
		if (kitchen.ReadyTotal or 0) > 0 then C_OWNED else C_DISABLED,
		UDim2.new(1, -148, 0.5, -17),
		UDim2.fromOffset(136, 34),
		function()
			if dispatchAction then dispatchAction("ServeFood", nil) end
		end
	)

	local waiting = state.WaitingCustomer
	if typeof(waiting) == "table" and waiting.CustomerName then
		local isCookingOrder = waiting.IsBeingCooked == true
		local orderCard = makeCard(scrollFrame, 72, if isCookingOrder then C_BRASS else C_OWNED)
		makeMonogramBox(orderCard, "ORD", if isCookingOrder then C_BRASS else C_OWNED, 10)

		local custTitle = Instance.new("TextLabel")
		custTitle.Position = UDim2.new(0, 78, 0, 10)
		custTitle.Size = UDim2.new(1, -242, 0, 20)
		custTitle.BackgroundTransparency = 1
		custTitle.Font = Enum.Font.GothamBlack
		custTitle.TextXAlignment = Enum.TextXAlignment.Left
		custTitle.TextSize = 13
		custTitle.TextColor3 = C_TEXT_PRIMARY
		custTitle.Text = string.format("ACTIVE ORDER  |  %s", string.upper(tostring(waiting.CustomerName)))
		custTitle.Parent = orderCard

		local custDesc = Instance.new("TextLabel")
		custDesc.Position = UDim2.new(0, 78, 0, 32)
		custDesc.Size = UDim2.new(1, -242, 0, 28)
		custDesc.BackgroundTransparency = 1
		custDesc.Font = Enum.Font.Gotham
		custDesc.TextWrapped = true
		custDesc.TextXAlignment = Enum.TextXAlignment.Left
		custDesc.TextSize = 12
		custDesc.TextColor3 = C_TEXT_MUTED
		custDesc.Text = string.format(
			"%s  |  +%d Gold  |  +%d Rep",
			tostring(waiting.DishName or "House Special"),
			tonumber(waiting.BaseGold) or 25,
			tonumber(waiting.BaseRep) or 5
		)
		custDesc.Parent = orderCard

		makeBtn(
			orderCard,
			if isCookingOrder then "COOKING..." else "COOK & SERVE",
			if isCookingOrder then C_DISABLED else C_OWNED,
			UDim2.new(1, -148, 0.5, -17),
			UDim2.fromOffset(136, 34),
			function()
				if not isCookingOrder and dispatchAction then
					dispatchAction("ServeCustomerOrder", nil)
				end
			end
		)
	end

	for idx, recipeId in ipairs(RecipeConfig.Order) do
		local recipe = RecipeConfig.Recipes[recipeId]
		if recipe then
			local canAfford = restLevel >= recipe.RequiredRestaurantLevel
			local parts: { string } = {}
			for ing, need in pairs(recipe.Ingredients) do
				local have = stock[ing] or 0
				if have < need then canAfford = false end
				table.insert(parts, string.format("%s %d/%d", ing, have, need))
			end

			local card = makeCard(scrollFrame, 76, if canAfford then C_BRASS else C_BORDER_STRONG)
			makeMonogramBox(card, string.format("R%02d", idx), if canAfford then C_BRASS else C_BORDER, 12)

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 78, 0, 10)
			nameLbl.Size = UDim2.new(1, -226, 0, 22)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.GothamBlack
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextSize = 13
			nameLbl.TextColor3 = C_TEXT_PRIMARY
			nameLbl.Text = string.format(
				"%s  |  %.0fs COOK  |  +%dG  |  +%d REP",
				string.upper(recipe.DisplayName),
				recipe.CookTime,
				recipe.CoinsReward,
				recipe.ReputationReward
			)
			nameLbl.Parent = card

			local reqLbl = Instance.new("TextLabel")
			reqLbl.Position = UDim2.new(0, 78, 0, 34)
			reqLbl.Size = UDim2.new(1, -226, 0, 32)
			reqLbl.BackgroundTransparency = 1
			reqLbl.Font = Enum.Font.Gotham
			reqLbl.TextWrapped = true
			reqLbl.TextXAlignment = Enum.TextXAlignment.Left
			reqLbl.TextSize = 11
			reqLbl.TextColor3 = C_TEXT_MUTED
			reqLbl.Text = "Requires: " .. table.concat(parts, ", ")
			reqLbl.Parent = card

			local btnText = if restLevel < recipe.RequiredRestaurantLevel
				then string.format("LOCKED HQ LV.%d", recipe.RequiredRestaurantLevel)
				elseif kitchen.IsCooking then "BUSY"
				else "COOK"

			makeBtn(
				card,
				btnText,
				if canAfford and not kitchen.IsCooking then C_OXBLOOD else C_DISABLED,
				UDim2.new(1, -138, 0.5, -17),
				UDim2.fromOffset(126, 34),
				function()
					if dispatchAction then dispatchAction("CookRecipe", recipeId) end
				end
			)
		end
	end

	local receipts = state.Receipts
	local receiptCount = if typeof(receipts) == "table" then #receipts else 0
	local ledgerHeight = math.max(78, 40 + math.min(receiptCount, 5) * 18)
	local ledger = makeCard(scrollFrame, ledgerHeight, C_BORDER_STRONG)

	local ledgerHead = Instance.new("TextLabel")
	ledgerHead.Position = UDim2.new(0, 16, 0, 8)
	ledgerHead.Size = UDim2.new(1, -28, 0, 20)
	ledgerHead.BackgroundTransparency = 1
	ledgerHead.Font = Enum.Font.GothamBlack
	ledgerHead.TextXAlignment = Enum.TextXAlignment.Left
	ledgerHead.TextSize = 12
	ledgerHead.TextColor3 = C_BRASS
	ledgerHead.Text = string.format("RECENT LEDGER RECEIPTS (%d)", receiptCount)
	ledgerHead.Parent = ledger

	local lines: { string } = {}
	if typeof(receipts) == "table" and #receipts > 0 then
		for i = 1, math.min(#receipts, 5) do
			local rec = receipts[i]
			if typeof(rec) == "table" then
				table.insert(lines, string.format(
					"#%d  |  %s  |  %s  |  +%dG (+%d Rep)  [%s]",
					tonumber(rec.OrderNo) or i,
					tostring(rec.CustomerName or "Guest"),
					tostring(rec.DishName or "Meal"),
					tonumber(rec.GoldEarned) or 0,
					tonumber(rec.RepEarned) or 0,
					tostring(rec.ChefName or "Chef")
				))
			end
		end
	else
		table.insert(lines, "No receipts recorded yet.")
	end

	local ledgerBody = Instance.new("TextLabel")
	ledgerBody.Position = UDim2.new(0, 16, 0, 30)
	ledgerBody.Size = UDim2.new(1, -28, 1, -36)
	ledgerBody.BackgroundTransparency = 1
	ledgerBody.Font = Enum.Font.Code
	ledgerBody.TextWrapped = true
	ledgerBody.TextXAlignment = Enum.TextXAlignment.Left
	ledgerBody.TextYAlignment = Enum.TextYAlignment.Top
	ledgerBody.TextSize = 11
	ledgerBody.TextColor3 = C_TEXT_MUTED
	ledgerBody.Text = table.concat(lines, "\n")
	ledgerBody.Parent = ledger
end

local function renderWarehouses(state: { [string]: any }): ()
	if not scrollFrame then return end
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

		local card = makeCard(scrollFrame, 86, if isLocked then C_BORDER_STRONG else C_STEEL)
		makeMonogramBox(card, string.upper(string.sub(category, 1, 3)), if isLocked then C_BORDER else C_STEEL, 17)

		local header = Instance.new("TextLabel")
		header.Position = UDim2.new(0, 78, 0, 9)
		header.Size = UDim2.new(1, -335, 0, 20)
		header.BackgroundTransparency = 1
		header.Font = Enum.Font.GothamBlack
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextSize = 13
		header.TextColor3 = if isLocked then C_TEXT_MUTED else C_TEXT_PRIMARY
		header.Text = if isLocked
			then string.format("%s  (LOCKED)", string.upper(spec.DisplayName))
			else string.format("%s  |  LV.%d  (%d/%d)", string.upper(spec.DisplayName), level, total, cap)
		header.Parent = card

		local detail = Instance.new("TextLabel")
		detail.Position = UDim2.new(0, 78, 0, 31)
		detail.Size = UDim2.new(1, -335, 0, 20)
		detail.BackgroundTransparency = 1
		detail.Font = Enum.Font.Gotham
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.TextSize = 11
		detail.TextColor3 = C_TEXT_MUTED
		detail.Text = if isLocked
			then ("Stores: " .. table.concat(spec.Ingredients, ", "))
			else table.concat(itemStrs, "  |  ")
		detail.Parent = card

		if not isLocked then
			local barBg = Instance.new("Frame")
			barBg.Position = UDim2.new(0, 78, 0, 58)
			barBg.Size = UDim2.new(1, -345, 0, 8)
			barBg.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
			barBg.Parent = card
			makeCorner(barBg, 4)
			local barFill = Instance.new("Frame")
			barFill.Size = UDim2.fromScale(if cap > 0 then math.clamp(total / cap, 0, 1) else 0, 1)
			barFill.BackgroundColor3 = C_BRASS
			barFill.Parent = barBg
			makeCorner(barFill, 4)
		end

		if isLocked then
			makeBtn(card, string.format("BUILD  %dG", spec.UnlockCost), C_OXBLOOD, UDim2.new(1, -166, 0.5, -17), UDim2.fromOffset(154, 34), function()
				if dispatchAction then dispatchAction("UpgradeWarehouse", category) end
			end)
		else
			makeBtn(card, "MOVE", C_BG_SUBTLE, UDim2.new(1, -246, 0.5, -17), UDim2.fromOffset(82, 34), function()
				if dispatchAction then dispatchAction("MoveWarehouse", category) end
			end)
			makeBtn(
				card,
				if nextTier then string.format("UPGRADE  %dG", nextTier.UpgradeCost) else "MAX LEVEL",
				if nextTier then C_OXBLOOD else C_DISABLED,
				UDim2.new(1, -156, 0.5, -17),
				UDim2.fromOffset(144, 34),
				function()
					if dispatchAction then dispatchAction("UpgradeWarehouse", category) end
				end
			)
		end
	end
end

local function renderUpgrades(state: { [string]: any }): ()
	if not scrollFrame then return end
	local profile = state.Profile or {}
	local restLv = profile.RestaurantLevel or 1
	local defLv = profile.DefenseLevel or 1
	local crewCount = profile.CrewCount or 0
	local maxCrew = state.MaxCrew or 2
	local nextCrewCost = state.NextCrewCost or 180

	local function addUpgradeRow(code: string, titleTxt: string, descTxt: string, btnTxt: string, btnBg: Color3, onClick: () -> ()): Frame
		local card = makeCard(scrollFrame :: ScrollingFrame, 84, C_BORDER_STRONG)
		makeMonogramBox(card, code, C_BORDER_STRONG, 16)
		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, 78, 0, 10)
		lbl.Size = UDim2.new(1, -242, 0, 20)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextSize = 13
		lbl.TextColor3 = C_TEXT_PRIMARY
		lbl.Text = titleTxt
		lbl.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Position = UDim2.new(0, 78, 0, 32)
		desc.Size = UDim2.new(1, -242, 0, 42)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextSize = 11
		desc.TextColor3 = C_TEXT_MUTED
		desc.Text = descTxt
		desc.TextWrapped = true
		desc.Parent = card

		makeBtn(card, btnTxt, btnBg, UDim2.new(1, -156, 0.5, -17), UDim2.fromOffset(144, 34), onClick)
		return card
	end

	local nextTier = RecipeConfig.RestaurantTiers[restLv + 1]
	addUpgradeRow(
		"HQ",
		string.format("RESTAURANT HQ  |  LV.%d / %d", restLv, RecipeConfig.MaxRestaurantLevel),
		"Increases dish Gold payout, kitchen cook speed, crew capacity, and unlocks high-tier platters.",
		if nextTier then string.format("UPGRADE  %dG", nextTier.UpgradeCost) else "MAX LEVEL",
		if nextTier then C_OXBLOOD else C_DISABLED,
		function() if dispatchAction then dispatchAction("UpgradeRestaurant", nil) end end
	)

	local canHire = crewCount < maxCrew
	addUpgradeRow(
		"CRW",
		string.format("KITCHEN CHEFS  |  %d / %d", crewCount, maxCrew),
		"Fetches ingredients from Warehouses and cooks plated dishes onto the Kitchen Counter (+15% cook speed each).",
		if canHire then string.format("HIRE  %dG", nextCrewCost) else "MAX CHEFS",
		if canHire then C_OWNED else C_DISABLED,
		function() if dispatchAction then dispatchAction("HireCrew", nil) end end
	)

	local waiterCount = state.WaiterCount or 0
	local maxWaiters = state.MaxWaiters or 3
	local nextWaiterCost = state.NextWaiterCost
	addUpgradeRow(
		"WTR",
		string.format("DINING WAITERS  |  %d / %d", waiterCount, maxWaiters),
		"Picks up cooked dishes from the Kitchen Counter on a silver tray and serves seated customers (+10% tip each).",
		if nextWaiterCost then string.format("HIRE  %dG", nextWaiterCost) else "MAX WAITERS",
		if nextWaiterCost then C_OWNED else C_DISABLED,
		function() if nextWaiterCost and dispatchAction then dispatchAction("HireWaiter", nil) end end
	)

	local courierCount = state.CourierCount or 0
	local maxCouriers = state.MaxCouriers or 2
	local nextCourierCost = state.NextCourierCost
	addUpgradeRow(
		"MTR",
		string.format("MOTORBIKE COURIERS  |  %d / %d", courierCount, maxCouriers),
		"Drives a delivery motorbike to Central Market, loads fresh ingredient crates, and stores them in your Warehouses.",
		if nextCourierCost then string.format("HIRE  %dG", nextCourierCost) else "FLEET ACTIVE",
		if nextCourierCost then C_OXBLOOD else C_OWNED,
		function() if nextCourierCost and dispatchAction then dispatchAction("HireCourier", nil) end end
	)

	local branch = state.CentralParkBranch
	local ownsBranch = typeof(branch) == "table" and branch.Owned == true
	local branchStaffed = typeof(branch) == "table" and branch.Staffed == true
	local underShakedown = typeof(branch) == "table" and branch.UnderShakedown == true
	local shakedownRem = if typeof(branch) == "table" and typeof(branch.ShakedownTimeLeft) == "number" then branch.ShakedownTimeLeft else 0
	local branchCost = if typeof(branch) == "table" and typeof(branch.Cost) == "number" then branch.Cost else 750
	if not ownsBranch then
		addUpgradeRow(
			"PRK",
			"CENTRAL PARK BISTRO  |  BRANCH",
			"Own a prime outdoor restaurant in Central Park Plaza. Call your hired Chef & Waiter here for passive Gold & Rep.",
			string.format("BUY  %dG", branchCost),
			C_OXBLOOD,
			function() if dispatchAction then dispatchAction("BuyCentralParkBranch", nil) end end
		)
	else
		local cardAccent = if underShakedown then C_OXBLOOD elseif branchStaffed then C_OWNED else C_BRASS
		local card = makeCard(scrollFrame :: ScrollingFrame, 88, cardAccent)
		makeMonogramBox(card, "PRK", cardAccent, 18)
		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.new(0, 78, 0, 10)
		lbl.Size = UDim2.new(1, -334, 0, 20)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextSize = 13
		lbl.TextColor3 = C_TEXT_PRIMARY
		lbl.Text = if underShakedown
			then string.format("CENTRAL PARK BISTRO  |  SHAKEDOWN (%ds)", shakedownRem)
			elseif branchStaffed then "CENTRAL PARK BISTRO  |  OPEN & STAFFED"
			else "CENTRAL PARK BISTRO  |  OWNED (UNSTAFFED)"
		lbl.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Position = UDim2.new(0, 78, 0, 32)
		desc.Size = UDim2.new(1, -334, 0, 44)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextSize = 11
		desc.TextColor3 = C_TEXT_MUTED
		desc.TextWrapped = true
		desc.Text = if underShakedown
			then "ALERT: Syndicate Extortionist at your Bistro! Click DEFEND (+260G & +45 Rep) or fight them off!"
			elseif branchStaffed then "Your Chef & Waiter are serving Central Park patrons right now (+Gold & +Rep every cycle)."
			else "Call your hired Chef (and Waiter if hired) to operate your Central Park Bistro and earn Gold."
		desc.Parent = card

		makeBtn(card, "VISIT", C_BG_SUBTLE, UDim2.new(1, -242, 0.5, -17), UDim2.fromOffset(78, 34), function()
			EmpireMenuController.Close()
			if dispatchAction then dispatchAction("TeleportCentralParkBranch", nil) end
		end)
		if underShakedown then
			makeBtn(card, "DEFEND +260G", C_OXBLOOD, UDim2.new(1, -156, 0.5, -17), UDim2.fromOffset(144, 34), function()
				EmpireMenuController.Close()
				if dispatchAction then dispatchAction("DefendCentralParkBranch", nil) end
			end)
		else
			makeBtn(
				card,
				if branchStaffed then "RECALL STAFF" else "CALL STAFF",
				if branchStaffed then C_STEEL else C_OWNED,
				UDim2.new(1, -156, 0.5, -17),
				UDim2.fromOffset(144, 34),
				function()
					if dispatchAction then dispatchAction("ToggleCentralParkStaff", nil) end
				end
			)
		end
	end

	local spinInfo = state.SpinEvent
	local spinFree = typeof(spinInfo) == "table" and spinInfo.CanFreeSpin == true
	local spinEventLive = typeof(spinInfo) == "table" and spinInfo.EventActive == true
	local spinBtnTxt = if spinFree
		then "FREE SPIN"
		elseif spinEventLive then "EVENT LIVE"
		else "VISIT WHEEL"
	addUpgradeRow(
		"SPN",
		if spinEventLive then "CENTRAL MARKET SPIN  |  EVENT LIVE" else "CENTRAL MARKET LUCKY SPIN",
		"Spin the Central Market Wheel to win random Bodyguards, Black Market Guns, Gold Jackpots, or Fish/Meat/Veg/Fruit crates.",
		spinBtnTxt,
		if spinFree or spinEventLive then C_OXBLOOD else C_STEEL,
		function()
			EmpireMenuController.Close()
			if dispatchAction then dispatchAction("TeleportSpinWheel", nil) end
		end
	)

	local nextDefCost = DEFENSE_COSTS[defLv + 1]
	addUpgradeRow(
		"DEF",
		string.format("BASE DEFENSES  |  TIER %d / 3", defLv),
		"Installs Watchtower Turrets (Tier 2) and fortified perimeter defenses (Tier 3).",
		if nextDefCost then string.format("UPGRADE  %dG", nextDefCost) else "MAX TIER",
		if nextDefCost then C_OXBLOOD else C_DISABLED,
		function() if dispatchAction then dispatchAction("UpgradeDefenses", nil) end end
	)

	local ownsBike = state.OwnsMotorbike == true
	local coinCost = state.MotorbikeCoinCost or 450
	addUpgradeRow(
		"BKE",
		"DELIVERY MOTORBIKE  |  KEY [V] + NITRO [SHIFT]",
		"High-speed 44-speed street motorbike with 66-speed Nitro Overdrive ([LeftShift] while riding).",
		if ownsBike then "NITRO RIDE" else string.format("BUY  %dG", coinCost),
		if ownsBike then C_OWNED else C_OXBLOOD,
		function()
			if dispatchAction then
				dispatchAction(if ownsBike then "TriggerBikeTurbo" else "BuyMotorbikeCoins", nil)
			end
		end
	)

	local raiderCount = state.RaiderCount or 0
	local maxRaiders = state.MaxRaiders or 2
	local nextRaider = state.NextRaiderCost
	addUpgradeRow(
		"RDR",
		string.format("EMPIRE RAIDERS  |  %d / %d", raiderCount, maxRaiders),
		"Autonomous syndicate raiders that march across the island capturing Neutral & Rival sectors.",
		if nextRaider then string.format("HIRE  %dG", nextRaider) else "SQUAD ACTIVE",
		if nextRaider then C_OXBLOOD else C_OWNED,
		function() if nextRaider and dispatchAction then dispatchAction("HireRaider", nil) end end
	)

	local guardCount = state.BodyguardCount or 0
	local maxGuards = state.MaxBodyguards or 4
	addUpgradeRow(
		"GRD",
		string.format("BODYGUARD SQUAD  |  %d / %d", guardCount, maxGuards),
		"Recruit up to 4 guards across 7 specialized classes and outfit them with compatible gear in the Black Market.",
		"MANAGE SQUAD",
		C_STEEL,
		function()
			currentTab = "BlackMarket"
			currentBMSubTab = "Bodyguards"
			render()
		end
	)

	local isRunActive = state.DeliveryRunnerActive == true
	local runCd = state.DeliveryRunnerCooldown or 0
	addUpgradeRow(
		"RUN",
		"DELIVERY RUNNER  |  CENTRAL PLAZA",
		"Dispatches a runner carrying high-value freight into Central Plaza (+165G). Escort with bodyguards.",
		if isRunActive then "EN ROUTE" elseif runCd > 0 then string.format("READY %ds", runCd) else "DISPATCH",
		if not isRunActive and runCd <= 0 then C_OWNED else C_DISABLED,
		function() if not isRunActive and runCd <= 0 and dispatchAction then dispatchAction("DispatchDeliveryRunner", nil) end end
	)

	local syn = state.Syndicate
	if typeof(syn) == "table" then
		local rankTitle = tostring(syn.RankTitle or "STREET RUNNER")
		local rankTier = tonumber(syn.RankTier) or 1
		local bonusPct = tonumber(syn.PayoutBonusPct) or 0
		local bonusHp = tonumber(syn.BonusMaxHP) or 0
		local nextTitle = tostring(syn.NextRankTitle or "MAX RANK")
		local nextRep = tonumber(syn.NextRankRep) or 0

		local rankCard = makeCard(scrollFrame :: ScrollingFrame, 64, C_BRASS)
		makeMonogramBox(rankCard, string.format("RK%d", rankTier), C_BRASS, 6)
		local rHead = Instance.new("TextLabel")
		rHead.Position = UDim2.new(0, 78, 0, 8)
		rHead.Size = UDim2.new(1, -92, 0, 20)
		rHead.BackgroundTransparency = 1
		rHead.Font = Enum.Font.GothamBlack
		rHead.TextXAlignment = Enum.TextXAlignment.Left
		rHead.TextSize = 13
		rHead.TextColor3 = C_BRASS
		rHead.Text = string.format("SYNDICATE RANK: %s  (TIER %d / 6)", rankTitle, rankTier)
		rHead.Parent = rankCard

		local rSub = Instance.new("TextLabel")
		rSub.Position = UDim2.new(0, 78, 0, 30)
		rSub.Size = UDim2.new(1, -92, 0, 26)
		rSub.BackgroundTransparency = 1
		rSub.Font = Enum.Font.Gotham
		rSub.TextXAlignment = Enum.TextXAlignment.Left
		rSub.TextSize = 11
		rSub.TextColor3 = C_TEXT_MUTED
		rSub.Text = string.format(
			"Perks: +%d%% Dish Gold Payout  |  +%d Max HP  |  Next Rank: %s (%d Rep)",
			bonusPct,
			bonusHp,
			nextTitle,
			nextRep
		)
		rSub.Parent = rankCard

		local convoyActive = syn.ConvoyActive == true
		local convoyCd = tonumber(syn.ConvoyCooldown) or 0
		addUpgradeRow(
			"CNV",
			"SMUGGLER CONVOY ESCORT  |  CORNER -> PLAZA",
			"Escort an armored supply transport against Rival Highway Ambushers (+420G, +65 Rep, +8 Ingredients & Ammo).",
			if convoyActive then "CONVOY LIVE" elseif convoyCd > 0 then string.format("READY %ds", convoyCd) else "LAUNCH CONVOY",
			if not convoyActive and convoyCd <= 0 then C_OXBLOOD else C_DISABLED,
			function()
				if not convoyActive and convoyCd <= 0 and dispatchAction then
					dispatchAction("StartSmugglerConvoy", nil)
				end
			end
		)

		local gwActive = syn.GangWarActive == true
		local gwCd = tonumber(syn.GangWarCooldown) or 0
		addUpgradeRow(
			"WAR",
			if gwActive then "GANG WAR CONTRABAND DROP  |  ACTIVE NOW" else "GANG WAR CONTRABAND DROP  |  SKIRMISH",
			"Contested Central District contraband chest guarded by 2 Elite Enforcers (+380G, +55 Rep & 100 Kevlar Armor).",
			if gwActive then "WARP TO DROP" elseif gwCd > 0 then string.format("READY %ds", gwCd) else "CALL DROP",
			if gwActive or gwCd <= 0 then C_OXBLOOD else C_DISABLED,
			function()
				if (gwActive or gwCd <= 0) and dispatchAction then
					EmpireMenuController.Close()
					dispatchAction("StartGangWarDrop", nil)
				end
			end
		)

		local contracts = syn.Contracts
		if typeof(contracts) == "table" then
			for idx, c in ipairs(contracts) do
				if typeof(c) == "table" then
					local prog = tonumber(c.Progress) or 0
					local goal = math.max(1, tonumber(c.Goal) or 1)
					local rewG = tonumber(c.RewardGold) or 220
					local rewR = tonumber(c.RewardRep) or 35
					local slotIdx = tonumber(c.SlotIndex) or idx
					local done = c.Completed == true
					addUpgradeRow(
						string.format("CT%d", idx),
						string.format("CONTRACT #%d: %s  (%d / %d)", idx, tostring(c.Title or "CONTRACT"), prog, goal),
						string.format("%s  |  Reward: +%d Gold & +%d Rep", tostring(c.Description or ""), rewG, rewR),
						if done then "DONE" else "NEW ORDER",
						if done then C_OWNED else C_BG_SUBTLE,
						function()
							if dispatchAction then
								dispatchAction("ClaimSyndicateContract", slotIdx)
							end
						end
					)
				end
			end
		end
	end
end

local function renderShop(state: { [string]: any }): ()
	if not scrollFrame then return end
	local owned = state.OwnedPasses or {}

	local intro = makeCard(scrollFrame, 44, C_BRASS)
	local introLbl = Instance.new("TextLabel")
	introLbl.Position = UDim2.new(0, 14, 0, 6)
	introLbl.Size = UDim2.new(1, -24, 1, -12)
	introLbl.BackgroundTransparency = 1
	introLbl.Font = Enum.Font.GothamMedium
	introLbl.TextWrapped = true
	introLbl.TextXAlignment = Enum.TextXAlignment.Left
	introLbl.TextSize = 11
	introLbl.TextColor3 = C_TEXT_MUTED
	introLbl.Text = "Optional Robux Store — Permanent Game Passes and consumable supply packs verified server-side via Roblox MarketplaceService."
	introLbl.Parent = intro

	for _, itemId in ipairs(MonetizationConfig.Order) do
		local spec = MonetizationConfig.Items[itemId]
		if spec then
			local isBike = (itemId == "DeliveryMotorbike")
			local isOwned = (spec.Kind == "GamePass" and owned[itemId] == true) or (isBike and state.OwnsMotorbike == true)
			local card = makeCard(scrollFrame, 96, if isOwned then C_OWNED else C_BRASS)
			ModelPreviewHelper.CreatePreview(card, "Premium", itemId, UDim2.fromOffset(74, 68), UDim2.new(0, 14, 0, 14), Color3.fromRGB(24, 26, 33))

			makeTag(card, string.upper(spec.Badge), C_BG_SUBTLE, UDim2.new(0, 98, 0, 10), UDim2.fromOffset(104, 16))
			makeTag(
				card,
				if spec.Kind == "GamePass" then "PERMANENT PASS" else "CONSUMABLE",
				if spec.Kind == "GamePass" then C_STEEL else C_OXBLOOD_DARK,
				UDim2.new(0, 208, 0, 10),
				UDim2.fromOffset(102, 16)
			)

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 98, 0, 30)
			nameLbl.Size = UDim2.new(1, -264, 0, 20)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.GothamBlack
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextSize = 14
			nameLbl.TextColor3 = C_TEXT_PRIMARY
			nameLbl.Text = string.upper(spec.DisplayName)
			nameLbl.Parent = card

			local descLbl = Instance.new("TextLabel")
			descLbl.Position = UDim2.new(0, 98, 0, 52)
			descLbl.Size = UDim2.new(1, -264, 0, 38)
			descLbl.BackgroundTransparency = 1
			descLbl.Font = Enum.Font.Gotham
			descLbl.TextWrapped = true
			descLbl.TextXAlignment = Enum.TextXAlignment.Left
			descLbl.TextYAlignment = Enum.TextYAlignment.Top
			descLbl.TextSize = 11
			descLbl.TextColor3 = C_TEXT_MUTED
			descLbl.Text = spec.Description
			descLbl.Parent = card

			local btn = makeBtn(
				card,
				if isOwned then "OWNED" else string.format("R$ %d", spec.RobuxPrice),
				if isOwned then C_DISABLED else C_ROBUX,
				UDim2.new(1, -152, 0.5, -18),
				UDim2.fromOffset(140, 36),
				function()
					if not isOwned and dispatchAction then
						local kindTxt = if spec.Kind == "GamePass" then "Permanent Game Pass" else "Repeatable Developer Product"
						showConfirmDialog(
							"CONFIRM ROBUX PURCHASE",
							string.format("%s (%s)\nPrice: R$ %d\n\n%s", spec.DisplayName, kindTxt, spec.RobuxPrice, spec.Description),
							string.format("BUY  R$ %d", spec.RobuxPrice),
							C_ROBUX,
							function()
								if dispatchAction then dispatchAction("BuyRobuxItem", itemId) end
							end
						)
					end
				end
			)
			if not isOwned then
				local st = btn:FindFirstChildOfClass("UIStroke")
				if st then st.Color = C_BRASS end
			end
		end
	end
end

local function renderBlackMarketWeapons(state: { [string]: any }): ()
	if not scrollFrame then return end
	local profile = state.Profile or {}
	local playerLevel = tonumber(profile.Level) or 1
	local playerCoins = tonumber(profile.Coins) or 0
	local bm = state.BlackMarket or {}
	local ownedWeapons = bm.OwnedWeapons or {}
	local ammoInv = bm.AmmoInventory or {}
	local currentArmor = if typeof(bm.Armor) == "number" then bm.Armor else 0

	-- Restrained Weapon Category Filter Bar
	local filterRow = Instance.new("Frame")
	filterRow.Size = UDim2.new(1, -6, 0, 30)
	filterRow.BackgroundTransparency = 1
	filterRow.Parent = scrollFrame
	local fl = Instance.new("UIListLayout")
	fl.FillDirection = Enum.FillDirection.Horizontal
	fl.Padding = UDim.new(0, 5)
	fl.Parent = filterRow

	local filters: { { Id: WeaponFilter, Label: string } } = {
		{ Id = "All", Label = "ALL" },
		{ Id = "Pistol", Label = "PISTOLS" },
		{ Id = "Shotgun", Label = "SHOTGUNS" },
		{ Id = "SMG", Label = "SMG" },
		{ Id = "AssaultRifle", Label = "RIFLES" },
		{ Id = "Sniper", Label = "SNIPER" },
		{ Id = "Gear", Label = "ARMOR / MED" },
	}
	for _, f in ipairs(filters) do
		local active = (currentWeaponFilter == f.Id)
		local b = makeBtn(
			filterRow,
			f.Label,
			if active then C_OXBLOOD else C_BG_CARD_ALT,
			UDim2.new(),
			UDim2.new(1 / #filters, -4, 0, 28),
			function()
				currentWeaponFilter = f.Id
				render()
			end
		)
		b.TextSize = 10
	end

	-- Gold Firearms Catalog with Live 3D ViewportFrame Previews & Per-Weapon Compatible Ammo Buttons
	if currentWeaponFilter ~= "Gear" then
		for _, wid in ipairs(WeaponConfig.WEAPON_ORDER) do
			local w = WeaponConfig.WEAPONS[wid]
			if w and not w.RobuxItemId and (currentWeaponFilter == "All" or currentWeaponFilter == w.Category) then
				local isOwned = ownedWeapons[wid] == true
				local locked = playerLevel < w.RequiredLevel
				local canAfford = playerCoins >= w.Price
				local ammoSpec = WeaponConfig.AMMO_TYPES[w.AmmoType]
				local curAmmo = tonumber(ammoInv[w.AmmoType]) or 0
				local maxAmmo = if ammoSpec then ammoSpec.MaxReserve else 96
				local quickPack = if ammoSpec then ammoSpec.Packs[1] else nil
				local rarityCol = RARITY_MUTED_COLORS[w.Rarity] or C_STEEL

				local card = makeCard(scrollFrame, 114, if isOwned then C_OWNED else rarityCol)
				ModelPreviewHelper.CreatePreview(card, "Weapon", wid, UDim2.fromOffset(82, 82), UDim2.new(0, 14, 0, 16), Color3.fromRGB(24, 26, 33))

				local nameLbl = Instance.new("TextLabel")
				nameLbl.Position = UDim2.new(0, 108, 0, 10)
				nameLbl.Size = UDim2.new(1, -278, 0, 20)
				nameLbl.BackgroundTransparency = 1
				nameLbl.Font = Enum.Font.GothamBlack
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left
				nameLbl.TextSize = 14
				nameLbl.TextColor3 = C_TEXT_PRIMARY
				nameLbl.Text = string.upper(w.DisplayName)
				nameLbl.Parent = card

				makeTag(card, string.upper(w.Rarity), rarityCol, UDim2.new(0, 108, 0, 32), UDim2.fromOffset(68, 16))
				makeTag(
					card,
					if locked then string.format("REQ LV.%d", w.RequiredLevel) else string.format("LV.%d+", w.RequiredLevel),
					if locked then C_OXBLOOD_DARK else C_BG_SUBTLE,
					UDim2.new(0, 182, 0, 32),
					UDim2.fromOffset(58, 16)
				)
				makeTag(
					card,
					if w.ReloadType == "ShellByShell" then "SHELL RELOAD" else "MAGAZINE",
					C_BG_SUBTLE,
					UDim2.new(0, 246, 0, 32),
					UDim2.fromOffset(84, 16)
				)

				local dmgText = if w.Pellets > 1 then string.format("%dx%d", w.Pellets, w.Damage) else tostring(w.Damage)
				local fireRate = string.format("%.1f/s", 1 / math.max(0.05, w.Cooldown))
				local statsLbl = Instance.new("TextLabel")
				statsLbl.Position = UDim2.new(0, 108, 0, 52)
				statsLbl.Size = UDim2.new(1, -272, 0, 16)
				statsLbl.BackgroundTransparency = 1
				statsLbl.Font = Enum.Font.Code
				statsLbl.TextXAlignment = Enum.TextXAlignment.Left
				statsLbl.TextSize = 11
				statsLbl.TextColor3 = Color3.fromRGB(204, 200, 192)
				statsLbl.Text = string.format(
					"DMG %s  |  ROF %s  |  RNG %d  |  MAG %d  |  %s (%d/%d)",
					dmgText,
					fireRate,
					w.Range,
					w.MagSize,
					if ammoSpec then ammoSpec.ShortName else w.AmmoType,
					curAmmo,
					maxAmmo
				)
				statsLbl.Parent = card

				local descLbl = Instance.new("TextLabel")
				descLbl.Position = UDim2.new(0, 108, 0, 72)
				descLbl.Size = UDim2.new(1, -272, 0, 34)
				descLbl.BackgroundTransparency = 1
				descLbl.Font = Enum.Font.Gotham
				descLbl.TextWrapped = true
				descLbl.TextXAlignment = Enum.TextXAlignment.Left
				descLbl.TextYAlignment = Enum.TextYAlignment.Top
				descLbl.TextSize = 11
				descLbl.TextColor3 = C_TEXT_MUTED
				descLbl.Text = w.Description
				descLbl.Parent = card

				local buyText = if isOwned
					then "OWNED  |  EQUIP"
					elseif locked then string.format("LOCKED  LV.%d", w.RequiredLevel)
					else string.format("BUY  %d G", w.Price)
				local buyCol = if isOwned
					then C_OWNED
					elseif locked or not canAfford then C_DISABLED
					else C_OXBLOOD

				local buyBtn = makeBtn(card, buyText, buyCol, UDim2.new(1, -158, 0, 16), UDim2.fromOffset(146, 36), function()
					if locked or isOwned then
						if dispatchAction then dispatchAction("BuyBlackMarketItem", wid) end
						return
					end
					if w.Price >= 500 then
						showConfirmDialog(
							"CONFIRM WEAPON PURCHASE",
							string.format("Acquire %s (%s %s) for %d Gold?\nStats: %s DMG  |  %d Range  |  %d Mag", w.DisplayName, w.Rarity, w.Category, w.Price, dmgText, w.Range, w.MagSize),
							string.format("BUY  %d G", w.Price),
							C_OXBLOOD,
							function()
								if dispatchAction then dispatchAction("BuyBlackMarketItem", wid) end
							end
						)
					elseif dispatchAction then
						dispatchAction("BuyBlackMarketItem", wid)
					end
				end)
				buyBtn.TextSize = 11

				if quickPack and ammoSpec then
					local ammoFull = curAmmo >= maxAmmo
					local ammoBtnText = if ammoFull
						then string.format("%s FULL", string.upper(ammoSpec.ShortName))
						else string.format("+%d %s  (%dG)", quickPack.Quantity, ammoSpec.ShortName, quickPack.Price)
					local aBtn = makeBtn(card, ammoBtnText, if ammoFull then C_DISABLED else C_BG_SUBTLE, UDim2.new(1, -158, 0, 60), UDim2.fromOffset(146, 36), function()
						if not ammoFull and dispatchAction then
							dispatchAction("BuyAmmo", { AmmoType = w.AmmoType, PackIndex = 1 })
						end
					end)
					aBtn.TextSize = 10
				end
			end
		end
	end

	-- Tactical Player Armor & Field Medkit with 3D Thumbnails
	if currentWeaponFilter == "All" or currentWeaponFilter == "Gear" then
		local gearItems = {
			{ Id = "KevlarVest", Name = "Kevlar Plate Armor", Price = 420, Kind = "Armor", Desc = "+100 breakable ballistic protection. Absorbs gunfire and melee hits until depleted." },
			{ Id = "Medkit", Name = "Field Trauma Kit", Price = 150, Kind = "Consumable", Desc = "Immediate 100% Base Health recovery and 6-second sprint adrenaline." },
		}
		for _, item in ipairs(gearItems) do
			local isArmorFull = (item.Kind == "Armor" and currentArmor >= 100)
			local card = makeCard(scrollFrame, 92, if isArmorFull then C_OWNED else C_STEEL)
			ModelPreviewHelper.CreatePreview(card, "Equipment", item.Id, UDim2.fromOffset(72, 68), UDim2.new(0, 14, 0, 12), Color3.fromRGB(24, 26, 33))

			local nLbl = Instance.new("TextLabel")
			nLbl.Position = UDim2.new(0, 98, 0, 12)
			nLbl.Size = UDim2.new(1, -264, 0, 20)
			nLbl.BackgroundTransparency = 1
			nLbl.Font = Enum.Font.GothamBlack
			nLbl.TextXAlignment = Enum.TextXAlignment.Left
			nLbl.TextSize = 14
			nLbl.TextColor3 = C_TEXT_PRIMARY
			nLbl.Text = if item.Kind == "Armor"
				then string.format("%s  (%d / 100)", string.upper(item.Name), currentArmor)
				else string.upper(item.Name)
			nLbl.Parent = card

			local dLbl = Instance.new("TextLabel")
			dLbl.Position = UDim2.new(0, 98, 0, 36)
			dLbl.Size = UDim2.new(1, -264, 0, 44)
			dLbl.BackgroundTransparency = 1
			dLbl.Font = Enum.Font.Gotham
			dLbl.TextWrapped = true
			dLbl.TextXAlignment = Enum.TextXAlignment.Left
			dLbl.TextSize = 11
			dLbl.TextColor3 = C_TEXT_MUTED
			dLbl.Text = item.Desc
			dLbl.Parent = card

			local btnText = if isArmorFull
				then "FULL  (100)"
				elseif item.Kind == "Armor" and currentArmor > 0 then string.format("REFILL  %dG", item.Price)
				else string.format("BUY  %dG", item.Price)
			makeBtn(card, btnText, if isArmorFull then C_OWNED else C_OXBLOOD, UDim2.new(1, -158, 0.5, -18), UDim2.fromOffset(146, 36), function()
				if dispatchAction then dispatchAction("BuyBlackMarketItem", item.Id) end
			end)
		end
	end
end

local function renderBlackMarketAmmo(state: { [string]: any }): ()
	if not scrollFrame then return end
	local bm = state.BlackMarket or {}
	local ammoInv = bm.AmmoInventory or {}
	local coins = tonumber(state.Profile and state.Profile.Coins) or 0

	local info = makeCard(scrollFrame, 42, C_STEEL)
	local infoLbl = Instance.new("TextLabel")
	infoLbl.Position = UDim2.new(0, 14, 0, 6)
	infoLbl.Size = UDim2.new(1, -24, 1, -12)
	infoLbl.BackgroundTransparency = 1
	infoLbl.Font = Enum.Font.GothamMedium
	infoLbl.TextXAlignment = Enum.TextXAlignment.Left
	infoLbl.TextSize = 11
	infoLbl.TextColor3 = C_TEXT_MUTED
	infoLbl.Text = "Caliber-matched ammunition reserves shared across compatible firearms. Purchase in small, standard, or bulk crates."
	infoLbl.Parent = info

	for _, ammoId in ipairs(WeaponConfig.AMMO_ORDER) do
		local aSpec = WeaponConfig.AMMO_TYPES[ammoId]
		if aSpec then
			local cur = tonumber(ammoInv[ammoId]) or 0
			local maxRes = aSpec.MaxReserve
			local isFull = cur >= maxRes
			local compatList = WeaponConfig.GetCompatibleWeaponsForAmmo(ammoId)

			local card = makeCard(scrollFrame, 114, if isFull then C_OWNED else C_BRASS)
			ModelPreviewHelper.CreatePreview(card, "Ammo", ammoId, UDim2.fromOffset(78, 78), UDim2.new(0, 14, 0, 18), Color3.fromRGB(24, 26, 33))

			local title = Instance.new("TextLabel")
			title.Position = UDim2.new(0, 104, 0, 10)
			title.Size = UDim2.new(1, -118, 0, 20)
			title.BackgroundTransparency = 1
			title.Font = Enum.Font.GothamBlack
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextSize = 13
			title.TextColor3 = C_TEXT_PRIMARY
			title.Text = string.format("%s  |  %d / %d RESERVE", string.upper(aSpec.DisplayName), cur, maxRes)
			title.Parent = card

			local compatLbl = Instance.new("TextLabel")
			compatLbl.Position = UDim2.new(0, 104, 0, 31)
			compatLbl.Size = UDim2.new(1, -118, 0, 16)
			compatLbl.BackgroundTransparency = 1
			compatLbl.Font = Enum.Font.Gotham
			compatLbl.TextXAlignment = Enum.TextXAlignment.Left
			compatLbl.TextSize = 11
			compatLbl.TextColor3 = C_TEXT_MUTED
			compatLbl.Text = "Compatible: " .. table.concat(compatList, ", ")
			compatLbl.Parent = card

			local barBg = Instance.new("Frame")
			barBg.Position = UDim2.new(0, 104, 0, 52)
			barBg.Size = UDim2.new(1, -118, 0, 7)
			barBg.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
			barBg.Parent = card
			makeCorner(barBg, 3)
			local barFill = Instance.new("Frame")
			barFill.Size = UDim2.fromScale(math.clamp(cur / math.max(1, maxRes), 0, 1), 1)
			barFill.BackgroundColor3 = if isFull then C_OWNED else C_BRASS
			barFill.Parent = barBg
			makeCorner(barFill, 3)

			local btnHolder = Instance.new("Frame")
			btnHolder.Position = UDim2.new(0, 104, 0, 68)
			btnHolder.Size = UDim2.new(1, -118, 0, 34)
			btnHolder.BackgroundTransparency = 1
			btnHolder.Parent = card
			local bl = Instance.new("UIListLayout")
			bl.FillDirection = Enum.FillDirection.Horizontal
			bl.Padding = UDim.new(0, 6)
			bl.Parent = btnHolder

			for pIdx, pack in ipairs(aSpec.Packs) do
				local canAfford = coins >= pack.Price
				local bText = if isFull
					then "RESERVE FULL"
					else string.format("+%d ROUNDS  (%dG)", pack.Quantity, pack.Price)
				local bCol = if isFull
					then C_DISABLED
					elseif canAfford then C_BG_SUBTLE
					else C_DISABLED
				local pb = makeBtn(btnHolder, bText, bCol, UDim2.new(), UDim2.new(1 / #aSpec.Packs, -4, 0, 32), function()
					if not isFull and dispatchAction then
						dispatchAction("BuyAmmo", { AmmoType = ammoId, PackIndex = pIdx })
					end
				end)
				pb.TextSize = 10
			end
		end
	end
end

local function renderBlackMarketBodyguards(state: { [string]: any }): ()
	if not scrollFrame then return end
	local profile = state.Profile or {}
	local playerLevel = tonumber(profile.Level) or 1
	local playerCoins = tonumber(profile.Coins) or 0
	local ownedPasses = state.OwnedPasses or {}
	local bgState = state.Bodyguards or {}
	local activeSquad: { string } = bgState.ActiveSquad or {}
	local unlockedClasses: { [string]: boolean } = bgState.UnlockedClasses or {}
	local ownedGear: { [string]: boolean } = bgState.OwnedGear or {}
	local loadouts: { [string]: { [string]: string } } = bgState.Loadouts or {}
	local maxSlots = tonumber(bgState.MaxSlots) or BodyguardConfig.MAX_ACTIVE_GUARDS
	selectedGuardSlot = math.clamp(selectedGuardSlot, 1, maxSlots)

	-- Active 4-Slot Squad Selector
	local squadCard = makeCard(scrollFrame, 78, C_STEEL)
	local sHead = Instance.new("TextLabel")
	sHead.Position = UDim2.new(0, 14, 0, 7)
	sHead.Size = UDim2.new(1, -24, 0, 18)
	sHead.BackgroundTransparency = 1
	sHead.Font = Enum.Font.GothamBlack
	sHead.TextXAlignment = Enum.TextXAlignment.Left
	sHead.TextSize = 11
	sHead.TextColor3 = C_BRASS
	sHead.Text = string.format("ACTIVE BODYGUARD DETAIL  (%d / %d)  —  SELECT TARGET SLOT", #activeSquad, maxSlots)
	sHead.Parent = squadCard

	local slotRow = Instance.new("Frame")
	slotRow.Position = UDim2.new(0, 14, 0, 30)
	slotRow.Size = UDim2.new(1, -28, 0, 38)
	slotRow.BackgroundTransparency = 1
	slotRow.Parent = squadCard
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.Padding = UDim.new(0, 6)
	sl.Parent = slotRow

	for idx = 1, maxSlots do
		local cid = activeSquad[idx]
		local cSpec = if cid then BodyguardConfig.CLASSES[cid :: BodyguardConfig.GuardClassId] else nil
		local isSel = (selectedGuardSlot == idx)
		local label = if cSpec
			then string.format("#%d  %s", idx, string.upper(cSpec.DisplayName))
			else string.format("#%d  EMPTY", idx)
		local btn = makeBtn(
			slotRow,
			label,
			if isSel then C_OXBLOOD elseif cSpec then C_BG_SUBTLE else C_BG_CARD_ALT,
			UDim2.new(),
			UDim2.new(0.25, -5, 0, 36),
			function()
				selectedGuardSlot = idx
				render()
			end
		)
		btn.TextSize = 10
		btn.TextWrapped = true
		if isSel then
			local st = btn:FindFirstChildOfClass("UIStroke")
			if st then st.Color = C_TEXT_PRIMARY end
		end
	end

	-- Toggle Classes vs Gear
	local modeRow = Instance.new("Frame")
	modeRow.Size = UDim2.new(1, -6, 0, 32)
	modeRow.BackgroundTransparency = 1
	modeRow.Parent = scrollFrame
	local ml = Instance.new("UIListLayout")
	ml.FillDirection = Enum.FillDirection.Horizontal
	ml.Padding = UDim.new(0, 6)
	ml.Parent = modeRow

	local cModeBtn = makeBtn(modeRow, "RECRUIT CLASSES  (7)", if currentGuardView == "Classes" then C_OXBLOOD else C_BG_CARD_ALT, UDim2.new(), UDim2.new(0.5, -3, 0, 30), function()
		currentGuardView = "Classes"
		render()
	end)
	cModeBtn.TextSize = 11

	local gModeBtn = makeBtn(modeRow, "BODYGUARD EQUIPMENT  (18)", if currentGuardView == "Gear" then C_OXBLOOD else C_BG_CARD_ALT, UDim2.new(), UDim2.new(0.5, -3, 0, 30), function()
		currentGuardView = "Gear"
		render()
	end)
	gModeBtn.TextSize = 11

	if currentGuardView == "Classes" then
		for _, classId in ipairs(BodyguardConfig.CLASS_ORDER) do
			local cSpec = BodyguardConfig.CLASSES[classId]
			if cSpec then
				local isUnlocked = unlockedClasses[classId] == true
					or (cSpec.RobuxItemId ~= nil and ownedPasses[cSpec.RobuxItemId] == true)
				local locked = (not isUnlocked) and (playerLevel < cSpec.RequiredLevel)
				local hasRobuxOption = (cSpec.RobuxItemId ~= nil and cSpec.RobuxPrice ~= nil and not isUnlocked)
				local inSelectedSlot = (activeSquad[selectedGuardSlot] == classId)
				local rarityCol = RARITY_MUTED_COLORS[cSpec.Rarity] or C_STEEL

				local card = makeCard(scrollFrame, 120, if inSelectedSlot then C_OWNED else rarityCol)
				ModelPreviewHelper.CreatePreview(card, "Bodyguard", classId, UDim2.fromOffset(82, 88), UDim2.new(0, 14, 0, 16), Color3.fromRGB(24, 26, 33))

				local title = Instance.new("TextLabel")
				title.Position = UDim2.new(0, 108, 0, 10)
				title.Size = UDim2.new(1, -276, 0, 20)
				title.BackgroundTransparency = 1
				title.Font = Enum.Font.GothamBlack
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextSize = 14
				title.TextColor3 = C_TEXT_PRIMARY
				title.Text = string.format("%s  |  %s", string.upper(cSpec.DisplayName), string.upper(cSpec.Role))
				title.Parent = card

				makeTag(card, string.upper(cSpec.Rarity), rarityCol, UDim2.new(0, 108, 0, 32), UDim2.fromOffset(68, 16))
				makeTag(
					card,
					if locked then string.format("REQ LV.%d", cSpec.RequiredLevel) else string.format("LV.%d+", cSpec.RequiredLevel),
					if locked then C_OXBLOOD_DARK else C_BG_SUBTLE,
					UDim2.new(0, 182, 0, 32),
					UDim2.fromOffset(58, 16)
				)
				makeTag(card, string.upper(cSpec.AbilityName), C_BG_SUBTLE, UDim2.new(0, 246, 0, 32), UDim2.fromOffset(132, 16))

				local statLbl = Instance.new("TextLabel")
				statLbl.Position = UDim2.new(0, 108, 0, 52)
				statLbl.Size = UDim2.new(1, -272, 0, 16)
				statLbl.BackgroundTransparency = 1
				statLbl.Font = Enum.Font.Code
				statLbl.TextXAlignment = Enum.TextXAlignment.Left
				statLbl.TextSize = 11
				statLbl.TextColor3 = Color3.fromRGB(204, 200, 192)
				statLbl.Text = string.format("HP %d  |  DMG %d  |  RNG %d  |  SPD %.0f", cSpec.MaxHP, cSpec.Damage, cSpec.AttackRange, cSpec.WalkSpeed)
				statLbl.Parent = card

				local descLbl = Instance.new("TextLabel")
				descLbl.Position = UDim2.new(0, 108, 0, 72)
				descLbl.Size = UDim2.new(1, -272, 0, 40)
				descLbl.BackgroundTransparency = 1
				descLbl.Font = Enum.Font.Gotham
				descLbl.TextWrapped = true
				descLbl.TextXAlignment = Enum.TextXAlignment.Left
				descLbl.TextYAlignment = Enum.TextYAlignment.Top
				descLbl.TextSize = 11
				descLbl.TextColor3 = C_TEXT_MUTED
				descLbl.Text = cSpec.AbilityDesc .. " " .. cSpec.Description
				descLbl.Parent = card

				local targetSlotLabel = if activeSquad[selectedGuardSlot] then string.format("SLOT #%d", selectedGuardSlot) else string.format("SLOT #%d", math.min(maxSlots, #activeSquad + 1))
				local recruitText = if inSelectedSlot
					then "ACTIVE  #" .. tostring(selectedGuardSlot)
					elseif isUnlocked then "ASSIGN  " .. targetSlotLabel
					elseif locked then string.format("LOCKED  LV.%d", cSpec.RequiredLevel)
					else string.format("HIRE  %d G", cSpec.Cost)
				local recruitCol = if inSelectedSlot
					then C_OWNED
					elseif isUnlocked then C_STEEL
					elseif locked or playerCoins < cSpec.Cost then C_DISABLED
					else C_OXBLOOD

				local rBtn = makeBtn(
					card,
					recruitText,
					recruitCol,
					UDim2.new(1, -158, 0, if hasRobuxOption then 16 else 42),
					UDim2.fromOffset(146, 36),
					function()
						if inSelectedSlot then return end
						local argPayload = { ClassId = classId, SlotIndex = selectedGuardSlot }
						if not isUnlocked and not locked and cSpec.Cost >= 500 then
							showConfirmDialog(
								"CONFIRM BODYGUARD RECRUIT",
								string.format("Recruit %s (%s) into %s for %d Gold?\nHP: %d  |  DMG: %d  |  Ability: %s", cSpec.DisplayName, cSpec.Role, targetSlotLabel, cSpec.Cost, cSpec.MaxHP, cSpec.Damage, cSpec.AbilityName),
								string.format("HIRE  %d G", cSpec.Cost),
								C_OXBLOOD,
								function()
									if dispatchAction then dispatchAction("RecruitBodyguard", argPayload) end
								end
							)
						elseif dispatchAction then
							dispatchAction("RecruitBodyguard", argPayload)
						end
					end
				)
				rBtn.TextSize = 11

				if hasRobuxOption and cSpec.RobuxItemId and cSpec.RobuxPrice then
					local robuxId = cSpec.RobuxItemId
					local rPrice = cSpec.RobuxPrice
					local vipBtn = makeBtn(card, string.format("R$ %d  UNLOCK", rPrice), C_ROBUX, UDim2.new(1, -158, 0, 60), UDim2.fromOffset(146, 36), function()
						showConfirmDialog(
							"CONFIRM ROBUX UNLOCK",
							string.format("Unlock %s permanently (bypasses level requirement) for R$ %d?\n%s", cSpec.DisplayName, rPrice, cSpec.AbilityDesc),
							string.format("BUY  R$ %d", rPrice),
							C_ROBUX,
							function()
								if dispatchAction then dispatchAction("BuyRobuxItem", robuxId) end
							end
						)
					end)
					vipBtn.TextSize = 11
					local vst = vipBtn:FindFirstChildOfClass("UIStroke")
					if vst then vst.Color = C_BRASS end
				end
			end
		end
	else
		-- Bodyguard Gear Filter Row
		local gFilterRow = Instance.new("Frame")
		gFilterRow.Size = UDim2.new(1, -6, 0, 28)
		gFilterRow.BackgroundTransparency = 1
		gFilterRow.Parent = scrollFrame
		local gl = Instance.new("UIListLayout")
		gl.FillDirection = Enum.FillDirection.Horizontal
		gl.Padding = UDim.new(0, 4)
		gl.Parent = gFilterRow

		local gFilters: { { Id: GuardGearFilter, Label: string } } = {
			{ Id = "All", Label = "ALL" },
			{ Id = "Armor", Label = "ARMOR" },
			{ Id = "Helmet", Label = "HELMETS" },
			{ Id = "Outfit", Label = "OUTFITS" },
			{ Id = "Weapon", Label = "WEAPONS" },
			{ Id = "Attachment", Label = "ATTACH" },
			{ Id = "Tactical", Label = "TACTICAL" },
		}
		for _, gf in ipairs(gFilters) do
			local active = (currentGuardGearFilter == gf.Id)
			local fb = makeBtn(gFilterRow, gf.Label, if active then C_OXBLOOD else C_BG_CARD_ALT, UDim2.new(), UDim2.new(1 / #gFilters, -4, 0, 26), function()
				currentGuardGearFilter = gf.Id
				render()
			end)
			fb.TextSize = 9
		end

		local selClassId = activeSquad[selectedGuardSlot]
		local selClassSpec = if selClassId then BodyguardConfig.CLASSES[selClassId :: BodyguardConfig.GuardClassId] else nil
		local selLoadout = loadouts[tostring(selectedGuardSlot)] or {}

		for _, gearId in ipairs(BodyguardConfig.GEAR_ORDER) do
			local gSpec = BodyguardConfig.GEAR[gearId]
			if gSpec and (currentGuardGearFilter == "All" or currentGuardGearFilter == gSpec.Slot) then
				local ownsGear = ownedGear[gearId] == true
					or (gSpec.RobuxItemId ~= nil and ownedPasses[gSpec.RobuxItemId] == true)
				local isEquippedOnSlot = (selLoadout[gSpec.Slot] == gearId)
				local isCompatible = if selClassId then BodyguardConfig.IsGearCompatible(selClassId :: BodyguardConfig.GuardClassId, gearId) else false
				local locked = (not ownsGear) and (not gSpec.RobuxItemId) and (playerLevel < gSpec.RequiredLevel)
				local rarityCol = RARITY_MUTED_COLORS[gSpec.Rarity] or C_STEEL

				local bonusParts: { string } = {}
				if gSpec.BonusHP ~= 0 then table.insert(bonusParts, string.format("+%d HP", gSpec.BonusHP)) end
				if gSpec.BonusDamage ~= 0 then table.insert(bonusParts, string.format("+%d DMG", gSpec.BonusDamage)) end
				if gSpec.BonusRange ~= 0 then table.insert(bonusParts, string.format("+%d RNG", gSpec.BonusRange)) end
				if gSpec.BonusSpeed > 0 then table.insert(bonusParts, string.format("+%.1f SPD", gSpec.BonusSpeed)) end
				if gSpec.CooldownMult < 1 then table.insert(bonusParts, string.format("+%d%% ROF", math.floor((1 - gSpec.CooldownMult) * 100))) end
				if gSpec.HealAuraBonus > 0 then table.insert(bonusParts, string.format("+%d HEAL", gSpec.HealAuraBonus)) end
				if gSpec.StunEffect then table.insert(bonusParts, "STUN") end

				local card = makeCard(scrollFrame, 112, if isEquippedOnSlot then C_OWNED else rarityCol)
				ModelPreviewHelper.CreatePreview(card, "Equipment", gearId, UDim2.fromOffset(78, 78), UDim2.new(0, 14, 0, 17), Color3.fromRGB(24, 26, 33))

				local title = Instance.new("TextLabel")
				title.Position = UDim2.new(0, 104, 0, 10)
				title.Size = UDim2.new(1, -270, 0, 20)
				title.BackgroundTransparency = 1
				title.Font = Enum.Font.GothamBlack
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextSize = 13
				title.TextColor3 = C_TEXT_PRIMARY
				title.Text = string.upper(gSpec.DisplayName)
				title.Parent = card

				makeTag(card, string.upper(gSpec.Slot), C_BG_SUBTLE, UDim2.new(0, 104, 0, 32), UDim2.fromOffset(64, 16))
				makeTag(card, string.upper(gSpec.Rarity), rarityCol, UDim2.new(0, 174, 0, 32), UDim2.fromOffset(64, 16))

				local compatText = if not selClassSpec
					then "RECRUIT SLOT #" .. tostring(selectedGuardSlot)
					elseif isCompatible then "COMPATIBLE: " .. string.upper(selClassSpec.DisplayName)
					else "INCOMPATIBLE: " .. string.upper(selClassSpec.DisplayName)
				local compatCol = if not selClassSpec
					then C_DISABLED
					elseif isCompatible then C_OWNED
					else C_OXBLOOD_DARK
				makeTag(card, compatText, compatCol, UDim2.new(0, 244, 0, 32), UDim2.fromOffset(162, 16))

				local statLbl = Instance.new("TextLabel")
				statLbl.Position = UDim2.new(0, 104, 0, 52)
				statLbl.Size = UDim2.new(1, -268, 0, 16)
				statLbl.BackgroundTransparency = 1
				statLbl.Font = Enum.Font.Code
				statLbl.TextXAlignment = Enum.TextXAlignment.Left
				statLbl.TextSize = 11
				statLbl.TextColor3 = Color3.fromRGB(204, 200, 192)
				statLbl.Text = table.concat(bonusParts, "  |  ")
				statLbl.Parent = card

				local descLbl = Instance.new("TextLabel")
				descLbl.Position = UDim2.new(0, 104, 0, 70)
				descLbl.Size = UDim2.new(1, -268, 0, 34)
				descLbl.BackgroundTransparency = 1
				descLbl.Font = Enum.Font.Gotham
				descLbl.TextWrapped = true
				descLbl.TextXAlignment = Enum.TextXAlignment.Left
				descLbl.TextYAlignment = Enum.TextYAlignment.Top
				descLbl.TextSize = 11
				descLbl.TextColor3 = C_TEXT_MUTED
				descLbl.Text = gSpec.Description
				descLbl.Parent = card

				if ownsGear then
					local eqText = if isEquippedOnSlot
						then "EQUIPPED  #" .. tostring(selectedGuardSlot)
						elseif not selClassSpec then "SELECT GUARD"
						elseif not isCompatible then "INCOMPATIBLE"
						else "EQUIP  GUARD #" .. tostring(selectedGuardSlot)
					local eqCol = if isEquippedOnSlot then C_OWNED elseif isCompatible then C_STEEL else C_DISABLED
					local eqBtn = makeBtn(card, eqText, eqCol, UDim2.new(1, -158, 0.5, -18), UDim2.fromOffset(146, 36), function()
						if isCompatible and not isEquippedOnSlot and dispatchAction then
							dispatchAction("EquipGuardGear", { SlotIndex = selectedGuardSlot, GearId = gearId })
						end
					end)
					eqBtn.TextSize = 10
				elseif gSpec.RobuxItemId and gSpec.RobuxPrice then
					local rId = gSpec.RobuxItemId
					local rPrice = gSpec.RobuxPrice
					local rBtn = makeBtn(card, string.format("R$ %d", rPrice), C_ROBUX, UDim2.new(1, -158, 0.5, -18), UDim2.fromOffset(146, 36), function()
						showConfirmDialog(
							"CONFIRM ROBUX OUTFIT",
							string.format("Unlock %s permanently for R$ %d?\n%s", gSpec.DisplayName, rPrice, gSpec.Description),
							string.format("BUY  R$ %d", rPrice),
							C_ROBUX,
							function()
								if dispatchAction then dispatchAction("BuyRobuxItem", rId) end
							end
						)
					end)
					local rst = rBtn:FindFirstChildOfClass("UIStroke")
					if rst then rst.Color = C_BRASS end
				else
					local bText = if locked then string.format("LOCKED  LV.%d", gSpec.RequiredLevel) else string.format("BUY  %d G", gSpec.Price)
					local bCol = if locked or playerCoins < gSpec.Price then C_DISABLED else C_OXBLOOD
					local bBtn = makeBtn(card, bText, bCol, UDim2.new(1, -158, 0.5, -18), UDim2.fromOffset(146, 36), function()
						if locked then
							if dispatchAction then dispatchAction("BuyGuardGear", gearId) end
							return
						end
						if gSpec.Price >= 500 then
							showConfirmDialog(
								"CONFIRM EQUIPMENT PURCHASE",
								string.format("Purchase %s (%s) for %d Gold?\nBonuses: %s", gSpec.DisplayName, gSpec.Slot, gSpec.Price, table.concat(bonusParts, ", ")),
								string.format("BUY  %d G", gSpec.Price),
								C_OXBLOOD,
								function()
									if dispatchAction then dispatchAction("BuyGuardGear", gearId) end
								end
							)
						elseif dispatchAction then
							dispatchAction("BuyGuardGear", gearId)
						end
					end)
					bBtn.TextSize = 11
				end
			end
		end
	end
end

local function renderBlackMarketPremium(state: { [string]: any }): ()
	if not scrollFrame then return end
	local ownedPasses = state.OwnedPasses or {}
	local ownedWeapons = (state.BlackMarket and state.BlackMarket.OwnedWeapons) or {}
	local ownedGear = (state.Bodyguards and state.Bodyguards.OwnedGear) or {}

	local intro = makeCard(scrollFrame, 48, C_BRASS)
	local introLbl = Instance.new("TextLabel")
	introLbl.Position = UDim2.new(0, 14, 0, 6)
	introLbl.Size = UDim2.new(1, -24, 1, -12)
	introLbl.BackgroundTransparency = 1
	introLbl.Font = Enum.Font.GothamMedium
	introLbl.TextWrapped = true
	introLbl.TextXAlignment = Enum.TextXAlignment.Left
	introLbl.TextSize = 11
	introLbl.TextColor3 = C_TEXT_MUTED
	introLbl.Text = "Optional Robux Exclusives — Clearly separated from Gold currency items. All Game Passes and Developer Products are verified server-side."
	introLbl.Parent = intro

	for _, itemId in ipairs(BLACK_MARKET_ROBUX_IDS) do
		local spec = MonetizationConfig.Items[itemId]
		if spec then
			local isOwned = spec.Kind == "GamePass" and (
				ownedPasses[itemId] == true
				or (itemId == "GoldenEmperorPistolPass" and ownedWeapons.GoldenEmperorPistol == true)
				or (itemId == "CrimsonDragonARPass" and ownedWeapons.CrimsonDragonAR == true)
				or (itemId == "GoldenEmperorSuitPass" and ownedGear.GoldenEmperorSuit == true)
			)
			local card = makeCard(scrollFrame, 102, if isOwned then C_OWNED else C_BRASS)
			ModelPreviewHelper.CreatePreview(card, "Premium", itemId, UDim2.fromOffset(78, 74), UDim2.new(0, 14, 0, 14), Color3.fromRGB(24, 26, 33))

			makeTag(card, string.upper(spec.Badge), C_BG_SUBTLE, UDim2.new(0, 104, 0, 10), UDim2.fromOffset(108, 16))
			makeTag(
				card,
				if spec.Kind == "GamePass" then "PERMANENT PASS" else "CONSUMABLE",
				if spec.Kind == "GamePass" then C_STEEL else C_OXBLOOD_DARK,
				UDim2.new(0, 218, 0, 10),
				UDim2.fromOffset(102, 16)
			)

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 104, 0, 30)
			nameLbl.Size = UDim2.new(1, -270, 0, 20)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.GothamBlack
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextSize = 14
			nameLbl.TextColor3 = C_TEXT_PRIMARY
			nameLbl.Text = string.upper(spec.DisplayName)
			nameLbl.Parent = card

			local descLbl = Instance.new("TextLabel")
			descLbl.Position = UDim2.new(0, 104, 0, 52)
			descLbl.Size = UDim2.new(1, -270, 0, 42)
			descLbl.BackgroundTransparency = 1
			descLbl.Font = Enum.Font.Gotham
			descLbl.TextWrapped = true
			descLbl.TextXAlignment = Enum.TextXAlignment.Left
			descLbl.TextYAlignment = Enum.TextYAlignment.Top
			descLbl.TextSize = 11
			descLbl.TextColor3 = C_TEXT_MUTED
			descLbl.Text = spec.Description
			descLbl.Parent = card

			local btn = makeBtn(
				card,
				if isOwned then "OWNED" else string.format("R$ %d", spec.RobuxPrice),
				if isOwned then C_DISABLED else C_ROBUX,
				UDim2.new(1, -158, 0.5, -18),
				UDim2.fromOffset(146, 36),
				function()
					if not isOwned and dispatchAction then
						local kindTxt = if spec.Kind == "GamePass" then "Permanent Game Pass" else "Repeatable Developer Product"
						showConfirmDialog(
							"CONFIRM ROBUX PURCHASE",
							string.format("%s (%s)\nPrice: R$ %d\n\n%s", spec.DisplayName, kindTxt, spec.RobuxPrice, spec.Description),
							string.format("BUY  R$ %d", spec.RobuxPrice),
							C_ROBUX,
							function()
								if dispatchAction then dispatchAction("BuyRobuxItem", itemId) end
							end
						)
					end
				end
			)
			if not isOwned then
				local st = btn:FindFirstChildOfClass("UIStroke")
				if st then st.Color = C_BRASS end
			end
		end
	end
end

local function renderBlackMarket(state: { [string]: any }): ()
	if not scrollFrame then return end
	local profile = state.Profile or {}
	local coins = tonumber(profile.Coins) or 0
	local level = tonumber(profile.Level) or 1

	local warpCard = makeCard(scrollFrame, 52, C_OXBLOOD)
	local wLbl = Instance.new("TextLabel")
	wLbl.Position = UDim2.new(0, 14, 0, 6)
	wLbl.Size = UDim2.new(1, -186, 1, -12)
	wLbl.BackgroundTransparency = 1
	wLbl.Font = Enum.Font.GothamBold
	wLbl.TextWrapped = true
	wLbl.TextXAlignment = Enum.TextXAlignment.Left
	wLbl.TextSize = 11
	wLbl.TextColor3 = C_TEXT_PRIMARY
	wLbl.Text = string.format("UNDERGROUND ARMS SYNDICATE  |  %d GOLD  |  LEVEL %d\nAcquire firearms, caliber-matched ammunition, and bodyguard equipment.", coins, level)
	wLbl.Parent = warpCard

	local visitBtn = makeBtn(warpCard, "VISIT OUTPOST", C_BG_SUBTLE, UDim2.new(1, -162, 0.5, -16), UDim2.fromOffset(150, 32), function()
		if modalFrame then modalFrame.Visible = false end
		if dispatchAction then dispatchAction("TeleportBlackMarket", nil) end
	end)
	visitBtn.TextSize = 11

	-- 4 Clean Sub-Category Tabs
	local subBar = Instance.new("Frame")
	subBar.Size = UDim2.new(1, -6, 0, 34)
	subBar.BackgroundTransparency = 1
	subBar.Parent = scrollFrame
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.Padding = UDim.new(0, 6)
	sl.Parent = subBar

	local subTabs: { { Id: BlackMarketSubTab, Label: string, ActiveCol: Color3 } } = {
		{ Id = "Weapons", Label = "WEAPONS", ActiveCol = C_OXBLOOD },
		{ Id = "Ammo", Label = "AMMUNITION", ActiveCol = C_STEEL },
		{ Id = "Bodyguards", Label = "BODYGUARDS", ActiveCol = C_OXBLOOD },
		{ Id = "Premium", Label = "PREMIUM  (R$)", ActiveCol = C_ROBUX },
	}
	for _, st in ipairs(subTabs) do
		local active = (currentBMSubTab == st.Id)
		local btn = makeBtn(subBar, st.Label, if active then st.ActiveCol else C_BG_CARD_ALT, UDim2.new(), UDim2.new(0.25, -5, 0, 32), function()
			currentBMSubTab = st.Id
			render()
		end)
		btn.TextSize = 11
		if active then
			local stroke = btn:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if st.Id == "Premium" then C_BRASS else C_TEXT_PRIMARY
			end
		end
	end

	if currentBMSubTab == "Weapons" then
		renderBlackMarketWeapons(state)
	elseif currentBMSubTab == "Ammo" then
		renderBlackMarketAmmo(state)
	elseif currentBMSubTab == "Bodyguards" then
		renderBlackMarketBodyguards(state)
	else
		renderBlackMarketPremium(state)
	end
end

render = function(): ()
	if not modalFrame or not modalFrame.Visible or not latestState then
		return
	end
	clearScroll()
	refreshTabStyles()
	if titleLabel and subtitleLabel then
		local titleMap: { [MenuTab]: { T: string, S: string } } = {
			Kitchen = { T = "KITCHEN OPERATIONS", S = "Cook recipes, fulfill customer orders, and review ledger receipts" },
			Warehouses = { T = "WAREHOUSE STORAGE", S = "Manage district ingredient supply capacity and storage plots" },
			Upgrades = { T = "SYNDICATE OPERATIONS", S = "Expand restaurant HQ, perimeter defenses, raiders, and transport" },
			BlackMarket = { T = "BLACK MARKET EXCHANGE", S = "Firearms, caliber-matched ammunition, bodyguard detail, and exclusives" },
			Shop = { T = "ROBUX EXCHANGE", S = "Optional permanent Game Passes and consumable supply crates" },
		}
		local entry = titleMap[currentTab] or { T = "FOOD EMPIRE", S = "" }
		titleLabel.Text = entry.T
		subtitleLabel.Text = entry.S
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
	modal.Position = UDim2.fromScale(0.5, 0.43)
	modal.Size = UDim2.fromScale(0.84, 0.68)
	modal.BackgroundColor3 = C_BG_MODAL
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = parentGui
	makeCorner(modal, 8)
	makeStroke(modal, C_BORDER_STRONG, 1.2)
	local sizeCon = Instance.new("UISizeConstraint")
	sizeCon.MinSize = Vector2.new(560, 340)
	sizeCon.MaxSize = Vector2.new(740, 464)
	sizeCon.Parent = modal
	modalFrame = modal

	-- Restrained top oxblood accent hairline
	local topAccent = Instance.new("Frame")
	topAccent.Size = UDim2.new(1, 0, 0, 2)
	topAccent.BackgroundColor3 = C_OXBLOOD
	topAccent.BorderSizePixel = 0
	topAccent.Parent = modal

	local header = Instance.new("TextLabel")
	header.Position = UDim2.new(0, 18, 0, 10)
	header.Size = UDim2.new(1, -80, 0, 22)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBlack
	header.Text = "FOOD EMPIRE"
	header.TextSize = 16
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = C_TEXT_PRIMARY
	header.Parent = modal
	titleLabel = header

	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.new(0, 18, 0, 31)
	sub.Size = UDim2.new(1, -80, 0, 15)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.Text = ""
	sub.TextSize = 11
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = C_TEXT_DIM
	sub.Parent = modal
	subtitleLabel = sub

	local closeBtn = makeBtn(modal, "X", C_BG_CARD_ALT, UDim2.new(1, -46, 0, 12), UDim2.fromOffset(32, 30), function()
		hideConfirmDialog()
		modal.Visible = false
	end)
	closeBtn.TextSize = 13

	-- Clean 5-Section Top Navigation Bar
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Position = UDim2.new(0, 16, 0, 54)
	tabBar.Size = UDim2.new(1, -32, 0, 32)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = modal

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabBar

	local tabs: { { Id: MenuTab, Label: string } } = {
		{ Id = "Kitchen", Label = "KITCHEN" },
		{ Id = "Warehouses", Label = "STORAGE" },
		{ Id = "Upgrades", Label = "EMPIRE" },
		{ Id = "BlackMarket", Label = "BLACK MARKET" },
		{ Id = "Shop", Label = "ROBUX STORE" },
	}
	for _, t in ipairs(tabs) do
		local tb = makeBtn(tabBar, t.Label, C_BG_CARD, UDim2.new(), UDim2.new(0.2, -5, 0, 30), function()
			hideConfirmDialog()
			currentTab = t.Id
			render()
		end)
		tb.TextSize = 11
		tabButtons[t.Id] = tb
	end

	-- Hairline Divider below tabs
	local divider = Instance.new("Frame")
	divider.Position = UDim2.new(0, 16, 0, 92)
	divider.Size = UDim2.new(1, -32, 0, 1)
	divider.BackgroundColor3 = C_BORDER
	divider.BorderSizePixel = 0
	divider.Parent = modal

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.new(0, 16, 0, 100)
	scroll.Size = UDim2.new(1, -32, 1, -112)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = C_BORDER_STRONG
	scroll.Parent = modal

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll
	scrollFrame = scroll

	-- Restrained Confirmation Dialog Overlay (for expensive Gold >= 500G & Robux purchases)
	local overlay = Instance.new("Frame")
	overlay.Name = "ConfirmPurchaseOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(6, 7, 10)
	overlay.BackgroundTransparency = 0.22
	overlay.Visible = false
	overlay.ZIndex = 40
	overlay.Parent = modal
	makeCorner(overlay, 8)
	confirmOverlay = overlay

	local dialog = Instance.new("Frame")
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	dialog.Position = UDim2.fromScale(0.5, 0.5)
	dialog.Size = UDim2.fromOffset(396, 206)
	dialog.BackgroundColor3 = C_BG_CARD
	dialog.ZIndex = 41
	dialog.Parent = overlay
	makeCorner(dialog, 6)
	makeStroke(dialog, C_BRASS, 1.2)

	local cTitle = Instance.new("TextLabel")
	cTitle.Position = UDim2.new(0, 18, 0, 14)
	cTitle.Size = UDim2.new(1, -36, 0, 22)
	cTitle.BackgroundTransparency = 1
	cTitle.Font = Enum.Font.GothamBlack
	cTitle.Text = "CONFIRM PURCHASE"
	cTitle.TextSize = 14
	cTitle.TextXAlignment = Enum.TextXAlignment.Left
	cTitle.TextColor3 = C_TEXT_PRIMARY
	cTitle.ZIndex = 42
	cTitle.Parent = dialog
	confirmTitleLbl = cTitle

	local cDesc = Instance.new("TextLabel")
	cDesc.Position = UDim2.new(0, 18, 0, 44)
	cDesc.Size = UDim2.new(1, -36, 0, 96)
	cDesc.BackgroundTransparency = 1
	cDesc.Font = Enum.Font.Gotham
	cDesc.TextWrapped = true
	cDesc.TextXAlignment = Enum.TextXAlignment.Left
	cDesc.TextYAlignment = Enum.TextYAlignment.Top
	cDesc.TextSize = 12
	cDesc.TextColor3 = C_TEXT_MUTED
	cDesc.Text = ""
	cDesc.ZIndex = 42
	cDesc.Parent = dialog
	confirmDescLbl = cDesc

	local cancelBtn = makeBtn(dialog, "CANCEL", C_BG_SUBTLE, UDim2.new(0, 18, 1, -50), UDim2.fromOffset(172, 36), function()
		hideConfirmDialog()
	end)
	cancelBtn.ZIndex = 42

	local yesBtn = makeBtn(dialog, "CONFIRM", C_OXBLOOD, UDim2.new(1, -190, 1, -50), UDim2.fromOffset(172, 36), function()
		local cb = pendingConfirmCallback
		hideConfirmDialog()
		if cb then cb() end
	end)
	yesBtn.ZIndex = 42
	confirmYesBtn = yesBtn
end

function EmpireMenuController.Close(): ()
	hideConfirmDialog()
	if modalFrame then
		modalFrame.Visible = false
	end
end

function EmpireMenuController.ToggleTab(tab: MenuTab): ()
	if not modalFrame then return end
	hideConfirmDialog()
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
