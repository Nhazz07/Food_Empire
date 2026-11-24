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
type BlackMarketSubTab = "Weapons" | "Ammo" | "Bodyguards" | "Mercenaries" | "Premium"
type WeaponFilter = "All" | "Melee" | "Pistol" | "Shotgun" | "SMG" | "AssaultRifle" | "Sniper" | "Gear"
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
	"SamuraiMafiaContract",
	"NinjaMafiaContract",
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

	-- Live City Craving (2.0x Gold Dish) & Menu Pricing Strategy Bar
	local craving = state.CityCraving
	local cravingId = if typeof(craving) == "table" then tostring(craving.RecipeId or "") else ""
	local cravingName = if typeof(craving) == "table" then tostring(craving.DisplayName or "Sizzling Steak") else "Sizzling Steak"
	local cravingRem = if typeof(craving) == "table" and typeof(craving.TimeRemaining) == "number" then craving.TimeRemaining else 120
	local curPricing = tostring(state.MenuPricing or "Standard")

	local econBar = makeCard(scrollFrame, 52, C_STEEL)
	local cravLbl = Instance.new("TextLabel")
	cravLbl.Position = UDim2.new(0, 14, 0, 6)
	cravLbl.Size = UDim2.new(1, -286, 1, -12)
	cravLbl.BackgroundTransparency = 1
	cravLbl.Font = Enum.Font.GothamBlack
	cravLbl.TextWrapped = true
	cravLbl.TextXAlignment = Enum.TextXAlignment.Left
	cravLbl.TextSize = 11
	cravLbl.TextColor3 = C_TEXT_PRIMARY
	cravLbl.Text = string.format("CITY CRAVING (2.0X GOLD): %s (%ds)\nMENU PRICING: %s", string.upper(cravingName), cravingRem, string.upper(curPricing))
	cravLbl.Parent = econBar

	local pOpts = {
		{ Id = "Budget", Label = "BUDGET +25% REP" },
		{ Id = "Standard", Label = "STANDARD" },
		{ Id = "Luxury", Label = "LUXURY +35% G" },
	}
	for i, po in ipairs(pOpts) do
		local isSel = (curPricing == po.Id)
		local pb = makeBtn(
			econBar,
			po.Label,
			if isSel then C_OWNED else C_BG_SUBTLE,
			UDim2.new(1, -276 + (i - 1) * 90, 0.5, -14),
			UDim2.fromOffset(86, 28),
			function()
				if dispatchAction then dispatchAction("SetMenuPricing", po.Id) end
			end
		)
		pb.TextSize = 8
	end

	local banner = makeCard(scrollFrame, 58, C_BRASS)
	local statusLbl = Instance.new("TextLabel")
	statusLbl.Position = UDim2.new(0, 16, 0, 8)
	statusLbl.Size = UDim2.new(1, -296, 1, -16)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Font = Enum.Font.GothamBold
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.TextWrapped = true
	statusLbl.TextSize = 12
	statusLbl.TextColor3 = C_TEXT_PRIMARY
	local stoveParts: { string } = {}
	if kitchen.IsCooking and kitchen.CurrentRecipeId then
		local r1 = RecipeConfig.Recipes[kitchen.CurrentRecipeId]
		table.insert(stoveParts, string.format("STOVE #1: %s (%.1fs)%s", string.upper(if r1 then r1.DisplayName else kitchen.CurrentRecipeId), kitchen.TimeRemaining or 0, if kitchen.Boosted1 then " [SEARED]" else ""))
	end
	if kitchen.IsCooking2 and kitchen.CurrentRecipeId2 then
		local r2 = RecipeConfig.Recipes[kitchen.CurrentRecipeId2]
		table.insert(stoveParts, string.format("STOVE #2: %s (%.1fs)%s", string.upper(if r2 then r2.DisplayName else kitchen.CurrentRecipeId2), kitchen.TimeRemaining2 or 0, if kitchen.Boosted2 then " [SEARED]" else ""))
	end
	if #stoveParts > 0 then
		statusLbl.Text = table.concat(stoveParts, "  |  ")
	else
		local dualTag = if kitchen.HasDualStove then "DUAL-STOVE READY" else "KITCHEN READY"
		statusLbl.Text = string.format("%s  |  %d DISHES READY TO SERVE", dualTag, kitchen.ReadyTotal or 0)
	end
	statusLbl.Parent = banner

	local canSear = (kitchen.IsCooking and not kitchen.Boosted1) or (kitchen.IsCooking2 and not kitchen.Boosted2)
	makeBtn(
		banner,
		if canSear then "SEAR BOOST" else "SEAR [E]",
		if canSear then C_BRASS else C_DISABLED,
		UDim2.new(1, -276, 0.5, -17),
		UDim2.fromOffset(118, 34),
		function()
			if canSear and dispatchAction then
				dispatchAction("SearBoostCook", nil)
			end
		end
	)

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
		ModelPreviewHelper.CreatePreview(orderCard, "Dish", "ActiveOrder", UDim2.fromOffset(54, 54), UDim2.new(0, 14, 0, 9), Color3.fromRGB(22, 24, 31), if isCookingOrder then C_BRASS else C_OWNED)

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

	local playerRep = (state.Profile and state.Profile.Reputation) or 0
	for idx, recipeId in ipairs(RecipeConfig.Order) do
		local recipe = RecipeConfig.Recipes[recipeId]
		if recipe then
			local repLocked = (recipe.RequiredRep ~= nil and playerRep < recipe.RequiredRep)
			local isCravingDish = (recipeId == cravingId)
			local canAfford = (restLevel >= recipe.RequiredRestaurantLevel) and (not repLocked)
			local parts: { string } = {}
			for ing, need in pairs(recipe.Ingredients) do
				local have = stock[ing] or 0
				if have < need then canAfford = false end
				table.insert(parts, string.format("%s %d/%d", ing, have, need))
			end

			local card = makeCard(scrollFrame, 76, if isCravingDish then C_OXBLOOD elseif canAfford then C_BRASS else C_BORDER_STRONG)
			ModelPreviewHelper.CreatePreview(card, "Dish", recipeId, UDim2.fromOffset(54, 54), UDim2.new(0, 14, 0, 11), Color3.fromRGB(22, 24, 31), if isCravingDish then C_OXBLOOD elseif canAfford then C_BRASS else C_BORDER)

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.new(0, 78, 0, 10)
			nameLbl.Size = UDim2.new(1, -226, 0, 22)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.GothamBlack
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextSize = 13
			nameLbl.TextColor3 = if isCravingDish then Color3.fromRGB(246, 212, 124) else C_TEXT_PRIMARY
			nameLbl.Text = string.format(
				"%s%s  |  %.0fs  |  +%dG  |  +%d REP",
				string.upper(recipe.DisplayName),
				if isCravingDish then " [2X CRAVING]" elseif recipe.IsSecretSyndicate then " [SECRET]" else "",
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

			local allStovesBusy = kitchen.IsCooking and (not kitchen.HasDualStove or kitchen.IsCooking2)
			local btnText = if repLocked
				then string.format("REQ %d REP", recipe.RequiredRep or 150)
				elseif restLevel < recipe.RequiredRestaurantLevel then string.format("LOCKED HQ LV.%d", recipe.RequiredRestaurantLevel)
				elseif allStovesBusy then "BUSY"
				else "COOK"

			makeBtn(
				card,
				btnText,
				if canAfford and not allStovesBusy then C_OXBLOOD else C_DISABLED,
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
		ModelPreviewHelper.CreatePreview(card, "Warehouse", category, UDim2.fromOffset(56, 56), UDim2.new(0, 14, 0, 15), Color3.fromRGB(22, 24, 31), if isLocked then C_BORDER else C_STEEL)

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
		ModelPreviewHelper.CreatePreview(card, "Empire", code, UDim2.fromOffset(54, 54), UDim2.new(0, 14, 0, 15), Color3.fromRGB(22, 24, 31), C_BORDER_STRONG)
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

	local hasDualStove = profile.HasDualStove == true
	addUpgradeRow(
		"STV",
		if hasDualStove then "DUAL-STOVE KITCHEN LINE  |  INSTALLED" else "DUAL-STOVE KITCHEN LINE  |  2X SIMULTANEOUS COOKING",
		"Installs a second commercial burner range so you and your Chefs can cook 2 dishes at the same time (+Star Rating).",
		if hasDualStove then "INSTALLED" else "BUY  650G",
		if hasDualStove then C_OWNED else C_OXBLOOD,
		function()
			if not hasDualStove and dispatchAction then
				dispatchAction("BuyDualStove", nil)
			end
		end
	)

	local hasVIPBooths = profile.HasVIPBooths == true
	addUpgradeRow(
		"VIP",
		if hasVIPBooths then "VIP PRIVATE DINING BOOTHS  |  INSTALLED" else "VIP PRIVATE DINING BOOTHS  |  +20% DISH PAYOUT",
		"Builds luxury velvet & brass private syndicate booths inside your dining room (+20% Gold on all dishes & +Star Rating).",
		if hasVIPBooths then "INSTALLED" else "BUY  850G",
		if hasVIPBooths then C_OWNED else C_OXBLOOD,
		function()
			if not hasVIPBooths and dispatchAction then
				dispatchAction("BuyVIPBooths", nil)
			end
		end
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
		ModelPreviewHelper.CreatePreview(card, "Empire", "PRK", UDim2.fromOffset(54, 54), UDim2.new(0, 14, 0, 17), Color3.fromRGB(22, 24, 31), cardAccent)
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

	local ownsSedan = state.OwnsMafiaSedan == true
	local sedanCost = state.MafiaSedanCost or 1250
	addUpgradeRow(
		"SDN",
		"ARMORED BLACK MAFIA SEDAN  |  KEY [J] + BODYGUARD CABIN",
		"50-speed armored syndicate V8 sedan (74-speed Overdrive). Your Bodyguards physically sit inside and fire from the cabin!",
		if ownsSedan then "DRIVE SEDAN [J]" else string.format("BUY  %dG", sedanCost),
		if ownsSedan then C_OWNED else C_OXBLOOD,
		function()
			if dispatchAction then
				dispatchAction(if ownsSedan then "ToggleMafiaSedan" else "BuyMafiaSedan", nil)
			end
		end
	)

	-- Armored Syndicate Van ([K]), Midnight Getaway Coupe ([L]), Garage Armor & Paint!
	local ownsVan = state.OwnsArmoredVan == true
	local vanCost = state.ArmoredVanCost or 1800
	addUpgradeRow(
		"VAN",
		"ARMORED SYNDICATE VAN  |  KEY [K]  |  +25% VAULT BONUS",
		"46-speed heavy ballistic cargo van (68 Overdrive) with sliding doors, bullbar & rear Bodyguard seats.",
		if ownsVan then "DRIVE VAN [K]" else string.format("BUY  %dG", vanCost),
		if ownsVan then C_OWNED else C_OXBLOOD,
		function()
			if dispatchAction then
				dispatchAction(if ownsVan then "ToggleArmoredVan" else "BuyArmoredVan", nil)
			end
		end
	)

	local ownsCoupe = state.OwnsGetawayCoupe == true
	local coupeCost = state.GetawayCoupeCost or 2600
	addUpgradeRow(
		"CPE",
		"MIDNIGHT GETAWAY COUPE  |  KEY [L]  |  84 TOP SPEED",
		"Low-slung dark-noir muscle coupe (62 Base / 84 Twin-Turbo Overdrive). Fastest street getaway car in the city!",
		if ownsCoupe then "DRIVE COUPE [L]" else string.format("BUY  %dG", coupeCost),
		if ownsCoupe then C_OWNED else C_OXBLOOD,
		function()
			if dispatchAction then
				dispatchAction(if ownsCoupe then "ToggleGetawayCoupe" else "BuyGetawayCoupe", nil)
			end
		end
	)

	local hasVehArmor = state.HasVehicleArmor == true
	local curPaint = tostring(state.VehiclePaint or "Obsidian")
	local garCard = makeCard(scrollFrame :: ScrollingFrame, 88, C_STEEL)
	ModelPreviewHelper.CreatePreview(garCard, "Empire", "GAR", UDim2.fromOffset(54, 54), UDim2.new(0, 14, 0, 17), Color3.fromRGB(22, 24, 31), C_STEEL)
	local gTitle = Instance.new("TextLabel")
	gTitle.Position = UDim2.new(0, 78, 0, 8)
	gTitle.Size = UDim2.new(1, -242, 0, 18)
	gTitle.BackgroundTransparency = 1
	gTitle.Font = Enum.Font.GothamBlack
	gTitle.TextXAlignment = Enum.TextXAlignment.Left
	gTitle.TextSize = 12
	gTitle.TextColor3 = C_TEXT_PRIMARY
	gTitle.Text = string.format("SYNDICATE GARAGE  |  PAINT: %s  |  ARMOR: %s", string.upper(curPaint), if hasVehArmor then "INSTALLED" else "NONE")
	gTitle.Parent = garCard

	local pRow = Instance.new("Frame")
	pRow.Position = UDim2.new(0, 78, 0, 34)
	pRow.Size = UDim2.new(1, -242, 0, 34)
	pRow.BackgroundTransparency = 1
	pRow.Parent = garCard
	local pLay = Instance.new("UIListLayout")
	pLay.FillDirection = Enum.FillDirection.Horizontal
	pLay.Padding = UDim.new(0, 5)
	pLay.Parent = pRow

	local paintList = {
		{ Id = "Obsidian", Label = "BLACK" },
		{ Id = "Oxblood", Label = "OXBLOOD" },
		{ Id = "Gunmetal", Label = "STEEL" },
		{ Id = "MidnightNavy", Label = "NAVY" },
		{ Id = "BrushedBrass", Label = "BRASS" },
	}
	for _, pt in ipairs(paintList) do
		local isP = (curPaint == pt.Id)
		local pb = makeBtn(pRow, pt.Label, if isP then C_OWNED else C_BG_SUBTLE, UDim2.new(), UDim2.new(0.20, -4, 0, 30), function()
			if dispatchAction then dispatchAction("SetVehiclePaint", pt.Id) end
		end)
		pb.TextSize = 9
	end

	makeBtn(garCard, if hasVehArmor then "ARMOR ON" else "ARMOR 700G", if hasVehArmor then C_OWNED else C_OXBLOOD, UDim2.new(1, -156, 0.5, -17), UDim2.fromOffset(144, 34), function()
		if not hasVehArmor and dispatchAction then dispatchAction("BuyVehicleArmor", nil) end
	end)

	-- 7-Day Daily Syndicate Vault & Godfather Prestige Rebirth
	local pv = state.PrestigeVault
	if typeof(pv) == "table" then
		local canClaim = pv.CanClaimToday == true
		addUpgradeRow(
			"DAY",
			string.format("7-DAY SYNDICATE VAULT  |  STREAK: %d / 7", tonumber(pv.Streak) or 0),
			tostring(pv.NextRewardLabel or "Daily login rewards escalating up to a FREE 5-Minute Samurai Mafia Contract on Day 7!"),
			if canClaim then "CLAIM VAULT" else "CLAIMED TODAY",
			if canClaim then C_OWNED else C_DISABLED,
			function()
				if canClaim and dispatchAction then dispatchAction("ClaimDailyVault", nil) end
			end
		)

		local pLv = tonumber(pv.PrestigeLevel) or 0
		local canP = pv.CanPrestige == true
		addUpgradeRow(
			"PRS",
			string.format("GODFATHER PRESTIGE  |  CURRENT: P%d (+%d%% GOLD & REP)", pLv, pLv * 25),
			"At HQ Lv.10 or 2,000 Rep, rebirth your HQ for a permanent +25% lifetime multiplier while keeping all weapons, vehicles & bodyguards!",
			if canP then "PRESTIGE NOW" else "REQ LV.10 / 2K REP",
			if canP then C_BRASS else C_DISABLED,
			function()
				if canP and dispatchAction then dispatchAction("TriggerGodfatherPrestige", nil) end
			end
		)
	end

	-- Syndicate Families (Co-op Crew Alliance)
	local fam = state.SyndicateFamily
	if typeof(fam) == "table" then
		local inFam = fam.InFamily == true
		local membersStr = if typeof(fam.Members) == "table" then table.concat(fam.Members, ", ") else ""
		local famCard = makeCard(scrollFrame :: ScrollingFrame, 84, if inFam then C_OWNED else C_BRASS)
		ModelPreviewHelper.CreatePreview(famCard, "Empire", "FAM", UDim2.fromOffset(54, 54), UDim2.new(0, 14, 0, 15), Color3.fromRGB(22, 24, 31), if inFam then C_OWNED else C_BRASS)
		local fTitle = Instance.new("TextLabel")
		fTitle.Position = UDim2.new(0, 78, 0, 10)
		fTitle.Size = UDim2.new(1, -334, 0, 20)
		fTitle.BackgroundTransparency = 1
		fTitle.Font = Enum.Font.GothamBlack
		fTitle.TextXAlignment = Enum.TextXAlignment.Left
		fTitle.TextSize = 13
		fTitle.TextColor3 = C_TEXT_PRIMARY
		fTitle.Text = if inFam then string.format("SYNDICATE FAMILY: %s", tostring(fam.FamilyName or "FAMILY")) else "SYNDICATE FAMILIES  |  CO-OP ALLIANCE"
		fTitle.Parent = famCard

		local fDesc = Instance.new("TextLabel")
		fDesc.Position = UDim2.new(0, 78, 0, 32)
		fDesc.Size = UDim2.new(1, -334, 0, 42)
		fDesc.BackgroundTransparency = 1
		fDesc.Font = Enum.Font.Gotham
		fDesc.TextWrapped = true
		fDesc.TextXAlignment = Enum.TextXAlignment.Left
		fDesc.TextSize = 11
		fDesc.TextColor3 = C_TEXT_MUTED
		fDesc.Text = if inFam
			then ("Members: " .. membersStr .. "  |  No Friendly Fire + +20% Co-op Raid Dividends!")
			else "Found or join a Mafia Family with friends in the server for zero friendly fire & shared +20% raid dividends."
		fDesc.Parent = famCard

		if inFam then
			makeBtn(famCard, "LEAVE FAMILY", C_OXBLOOD_DARK, UDim2.new(1, -156, 0.5, -17), UDim2.fromOffset(144, 34), function()
				if dispatchAction then dispatchAction("LeaveFamily", nil) end
			end)
		else
			makeBtn(famCard, "JOIN OPEN", C_STEEL, UDim2.new(1, -242, 0.5, -17), UDim2.fromOffset(82, 34), function()
				if dispatchAction then dispatchAction("JoinFamily", nil) end
			end)
			makeBtn(famCard, "CREATE FAMILY", C_OWNED, UDim2.new(1, -152, 0.5, -17), UDim2.fromOffset(140, 34), function()
				if dispatchAction then dispatchAction("CreateFamily", nil) end
			end)
		end
	end

	local keycards = tonumber(state.VaultKeycards) or 0
	addUpgradeRow(
		"VLT",
		string.format("TERRITORY SUPPLY VAULT HEIST  |  KEYCARDS: %d", keycards),
		"Crack a Corner Territory Supply Vault for +320G (+440G with Keycard from Territory Rivals), +55 Rep, +15 Stock & 1 Rare Catch!",
		if keycards > 0 then "KEYCARD HEIST" else "CRACK VAULT",
		C_OXBLOOD,
		function()
			if dispatchAction then
				dispatchAction("CrackTerritoryVault", nil)
			end
		end
	)

	addUpgradeRow(
		"EMP",
		"FOOD EMPEROR SYNDICATE MONUMENT  |  CENTRAL PLAZA",
		"Claim your live Food Emperor Tribute (+150G & +25 Rep as #1 Food Emperor, or +65G Syndicate Stipend) from the Central Monument.",
		"CLAIM TRIBUTE",
		C_BRASS,
		function()
			if dispatchAction then
				dispatchAction("ClaimEmperorTribute", nil)
			end
		end
	)

	-- Dynamic Noir Weather & Midnight Blackout Bullion Truck
	local weather = state.Weather
	if typeof(weather) == "table" then
		local blackoutLive = weather.BlackoutTruckActive == true
		addUpgradeRow(
			"WTH",
			string.format("CITY WEATHER: %s", tostring(weather.Title or "CLEAR NOIR")),
			tostring(weather.BonusDesc or "Dynamic Noir Rainstorm, Harbor Fog & Midnight Blackout events."),
			if blackoutLive then "RAID TRUCK +480G" else "SHIFT WEATHER",
			if blackoutLive then C_OXBLOOD else C_STEEL,
			function()
				if dispatchAction then
					dispatchAction(if blackoutLive then "RaidBlackoutTruck" else "CycleWeather", nil)
				end
			end
		)
	end

	-- 3-Stage Crimson Don's Penthouse Heist (Endgame Raid)
	local heist = state.PenthouseHeist
	local heistStage = if typeof(heist) == "table" and typeof(heist.ActiveStage) == "number" then heist.ActiveStage else 0
	local heistCd = if typeof(heist) == "table" and typeof(heist.Cooldown) == "number" then heist.Cooldown else 0
	addUpgradeRow(
		"HST",
		if heistStage > 0 then string.format("CRIMSON DON PENTHOUSE HEIST  |  STAGE %d / 3 LIVE", heistStage) else "THE CRIMSON DON'S PENTHOUSE HEIST  |  3-STAGE RAID",
		"Breach the fortified Syndicate Penthouse Compound, crack the Gold Vault & defeat the Armored Crimson Don (+1,200G, +180 Rep & Trophy)!",
		if heistStage > 0 then "WARP TO RAID" elseif heistCd > 0 then string.format("LOCKED %ds", heistCd) else "LAUNCH HEIST",
		if heistStage > 0 or heistCd <= 0 then C_OXBLOOD else C_DISABLED,
		function()
			if (heistStage > 0 or heistCd <= 0) and dispatchAction then
				EmpireMenuController.Close()
				dispatchAction("StartPenthouseHeist", nil)
			end
		end
	)

	-- Syndicate Bounty Board & Hit Contracts
	local bnt = state.Bounties
	local hitLive = typeof(bnt) == "table" and bnt.HitActive == true
	local hitCd = if typeof(bnt) == "table" and typeof(bnt.HitCooldown) == "number" then bnt.HitCooldown else 0
	local bntCard = makeCard(scrollFrame :: ScrollingFrame, 84, C_OXBLOOD)
	ModelPreviewHelper.CreatePreview(bntCard, "Empire", "BNT", UDim2.fromOffset(54, 54), UDim2.new(0, 14, 0, 15), Color3.fromRGB(22, 24, 31), C_OXBLOOD)
	local bLbl = Instance.new("TextLabel")
	bLbl.Position = UDim2.new(0, 78, 0, 10)
	bLbl.Size = UDim2.new(1, -334, 0, 20)
	bLbl.BackgroundTransparency = 1
	bLbl.Font = Enum.Font.GothamBlack
	bLbl.TextXAlignment = Enum.TextXAlignment.Left
	bLbl.TextSize = 13
	bLbl.TextColor3 = C_TEXT_PRIMARY
	bLbl.Text = if hitLive then string.format("ACTIVE HIT CONTRACT: %s", string.upper(tostring(bnt.HitTargetName or "TARGET"))) else "SYNDICATE BOUNTY BOARD & HIT CONTRACTS"
	bLbl.Parent = bntCard
	local bDesc = Instance.new("TextLabel")
	bDesc.Position = UDim2.new(0, 78, 0, 32)
	bDesc.Size = UDim2.new(1, -334, 0, 42)
	bDesc.BackgroundTransparency = 1
	bDesc.Font = Enum.Font.Gotham
	bDesc.TextWrapped = true
	bDesc.TextXAlignment = Enum.TextXAlignment.Left
	bDesc.TextSize = 11
	bDesc.TextColor3 = C_TEXT_MUTED
	bDesc.Text = "Accept high-value Hit Contracts on armored Syndicate Lieutenants (+460G–620G) or post a 250G bounty on a rival player."
	bDesc.Parent = bntCard
	makeBtn(bntCard, "BOUNTY 250G", C_BG_SUBTLE, UDim2.new(1, -242, 0.5, -17), UDim2.fromOffset(82, 34), function()
		if dispatchAction then dispatchAction("PlacePlayerBounty", { Amount = 250 }) end
	end)
	makeBtn(bntCard, if hitLive then "WARP TARGET" elseif hitCd > 0 then string.format("READY %ds", hitCd) else "ACCEPT HIT", if hitLive or hitCd <= 0 then C_OXBLOOD else C_DISABLED, UDim2.new(1, -152, 0.5, -17), UDim2.fromOffset(140, 34), function()
		if (hitLive or hitCd <= 0) and dispatchAction then
			EmpireMenuController.Close()
			dispatchAction("AcceptHitContract", nil)
		end
	end)

	-- 3 Apex Mafia-Controlled City Restaurants (Conquer -> Hire Chef -> Sell Food -> Defend Revenge!)
	local mafiaRests = state.MafiaRestaurants
	if typeof(mafiaRests) == "table" then
		for _, mr in ipairs(mafiaRests) do
			if typeof(mr) == "table" and typeof(mr.Id) == "string" then
				local rid = mr.Id
				local owned = mr.OwnedByMe == true
				local chefHired = mr.ChefHired == true
				local underRev = mr.UnderRevenge == true
				local cardAcc = if underRev then C_OXBLOOD elseif owned then C_OWNED else C_BRASS
				local mCard = makeCard(scrollFrame :: ScrollingFrame, 88, cardAcc)
				local restIcon = if rid == "ObsidianNoodleHouse" then "RST_Noodle" elseif rid == "VelvetSteakhouse" then "RST_Steak" else "RST_Oyster"
				ModelPreviewHelper.CreatePreview(mCard, "Empire", restIcon, UDim2.fromOffset(54, 54), UDim2.new(0, 14, 0, 17), Color3.fromRGB(22, 24, 31), cardAcc)

				local mTitle = Instance.new("TextLabel")
				mTitle.Position = UDim2.new(0, 78, 0, 10)
				mTitle.Size = UDim2.new(1, -334, 0, 20)
				mTitle.BackgroundTransparency = 1
				mTitle.Font = Enum.Font.GothamBlack
				mTitle.TextXAlignment = Enum.TextXAlignment.Left
				mTitle.TextSize = 13
				mTitle.TextColor3 = C_TEXT_PRIMARY
				mTitle.Text = if underRev
					then string.format("%s  |  REVENGE RAID (%ds)!", string.upper(tostring(mr.DisplayName)), tonumber(mr.RevengeTimeLeft) or 0)
					elseif owned and chefHired then string.format("%s  |  OWNED & SELLING (+%dG)", string.upper(tostring(mr.DisplayName)), tonumber(mr.CycleGold) or 100)
					elseif owned then string.format("%s  |  CONQUERED (HIRE CHEF)", string.upper(tostring(mr.DisplayName)))
					else string.format("%s  |  %s (%d ALIVE)", string.upper(tostring(mr.DisplayName)), string.upper(tostring(mr.FactionName)), tonumber(mr.DefendersAlive) or 3)
				mTitle.Parent = mCard

				local mDesc = Instance.new("TextLabel")
				mDesc.Position = UDim2.new(0, 78, 0, 32)
				mDesc.Size = UDim2.new(1, -334, 0, 44)
				mDesc.BackgroundTransparency = 1
				mDesc.Font = Enum.Font.Gotham
				mDesc.TextWrapped = true
				mDesc.TextXAlignment = Enum.TextXAlignment.Left
				mDesc.TextSize = 11
				mDesc.TextColor3 = C_TEXT_MUTED
				mDesc.Text = if underRev
					then "ALERT: Defeated Apex Mafia is raiding to take back this restaurant! Defend it or dispatch Samurai/Ninja Mafia!"
					elseif owned then string.format("You control this City Restaurant! Hire a Chef (%dG) to cook & sell for +%dG & +%d Rep every 18s.", tonumber(mr.ChefHireCost) or 450, tonumber(mr.CycleGold) or 100, tonumber(mr.CycleRep) or 20)
					else string.format("Guarded by strong %s! Wipe them out yourself or hire Samurai/Ninja Mafia in Black Market -> Mercenaries to conquer it.", tostring(mr.FactionName))
				mDesc.Parent = mCard

				makeBtn(mCard, "VISIT", C_BG_SUBTLE, UDim2.new(1, -242, 0.5, -17), UDim2.fromOffset(78, 34), function()
					EmpireMenuController.Close()
					if dispatchAction then dispatchAction("TeleportMafiaRestaurant", rid) end
				end)
				if owned and not chefHired then
					makeBtn(mCard, string.format("CHEF %dG", tonumber(mr.ChefHireCost) or 450), C_OWNED, UDim2.new(1, -156, 0.5, -17), UDim2.fromOffset(144, 34), function()
						if dispatchAction then dispatchAction("HireMafiaRestaurantChef", rid) end
					end)
				elseif owned and chefHired then
					makeBtn(mCard, if underRev then "SEND MERCS" else "CHEF ACTIVE", if underRev then C_OXBLOOD else C_DISABLED, UDim2.new(1, -156, 0.5, -17), UDim2.fromOffset(144, 34), function()
						if underRev and dispatchAction then dispatchAction("OrderMercenaryAssault", rid) end
					end)
				else
					makeBtn(mCard, "SEND MERCS", C_OXBLOOD, UDim2.new(1, -156, 0.5, -17), UDim2.fromOffset(144, 34), function()
						if dispatchAction then dispatchAction("OrderMercenaryAssault", rid) end
					end)
				end
			end
		end
	end

	-- 3 Ownable Mafia Front Businesses (Passive Wall Safes + Permanent Perks)
	local frontBiz = state.FrontBusinesses
	if typeof(frontBiz) == "table" then
		for _, biz in ipairs(frontBiz) do
			if typeof(biz) == "table" and typeof(biz.Id) == "string" then
				local bid = biz.Id
				local owned = biz.Owned == true
				local safeG = tonumber(biz.SafeGold) or 0
				addUpgradeRow(
					"BIZ",
					if owned then string.format("%s  |  SAFE: %d / %dG", string.upper(tostring(biz.DisplayName)), safeG, tonumber(biz.MaxSafeGold) or 700) else string.format("FRONT BUSINESS: %s", string.upper(tostring(biz.DisplayName))),
					tostring(biz.PerkLabel or "Passive Wall Safe Gold & Empire Perk."),
					if owned then (if safeG > 0 then string.format("COLLECT +%dG", safeG) else "FILLING...") else string.format("BUY  %dG", tonumber(biz.Cost) or 800),
					if owned then (if safeG > 0 then C_OWNED else C_DISABLED) else C_OXBLOOD,
					function()
						if dispatchAction then
							dispatchAction(if owned then "CollectBusinessSafe" else "BuyFrontBusiness", bid)
						end
					end
				)
			end
		end
	end

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
		ModelPreviewHelper.CreatePreview(rankCard, "Empire", "RK", UDim2.fromOffset(52, 52), UDim2.new(0, 14, 0, 6), Color3.fromRGB(22, 24, 31), C_BRASS)
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
	local weaponMods = bm.WeaponMods or {}
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
		{ Id = "Melee", Label = "BLADES" },
		{ Id = "Pistol", Label = "PISTOLS" },
		{ Id = "Shotgun", Label = "SHOTGUNS" },
		{ Id = "SMG", Label = "SMG" },
		{ Id = "AssaultRifle", Label = "RIFLES" },
		{ Id = "Sniper", Label = "SNIPER" },
		{ Id = "Gear", Label = "ARMOR/SMOKE" },
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

				local card = makeCard(scrollFrame, 146, if isOwned then C_OWNED else rarityCol)
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

				if not w.IsMelee and quickPack and ammoSpec then
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

				-- Gunsmith Attachment Workbench Row (for Firearms) or Blade Crit Tag (for Knife/Katana)
				if not w.IsMelee then
					local modRow = Instance.new("Frame")
					modRow.Position = UDim2.new(0, 108, 0, 108)
					modRow.Size = UDim2.new(1, -120, 0, 28)
					modRow.BackgroundTransparency = 1
					modRow.Parent = card
					local modLayout = Instance.new("UIListLayout")
					modLayout.FillDirection = Enum.FillDirection.Horizontal
					modLayout.Padding = UDim.new(0, 6)
					modLayout.Parent = modRow

					local myMods = if typeof(weaponMods[wid]) == "table" then weaponMods[wid] else {}
					for _, modId in ipairs(WeaponConfig.GUNSMITH_MOD_ORDER) do
						local mSpec = WeaponConfig.GUNSMITH_MODS[modId]
						if mSpec then
							local hasMod = myMods[modId] == true
							local mTxt = if hasMod
								then string.format("%s [ON]", mSpec.ShortLabel)
								else string.format("+%s (%dG)", mSpec.ShortLabel, mSpec.Price)
							local mCol = if hasMod
								then C_OWNED
								elseif isOwned and playerCoins >= mSpec.Price then C_BG_SUBTLE
								else C_DISABLED
							local mb = makeBtn(modRow, mTxt, mCol, UDim2.new(), UDim2.new(1 / 3, -4, 0, 26), function()
								if not hasMod and dispatchAction then
									dispatchAction("BuyWeaponMod", { WeaponId = wid, ModId = modId })
								end
							end)
							mb.TextSize = 9
						end
					end
				end
			end
		end
	end

	-- Tactical Player Armor, Field Medkit & Smoke Grenades
	if currentWeaponFilter == "All" or currentWeaponFilter == "Gear" then
		local smokeCount = tonumber(bm.SmokeGrenades) or 0
		local smokeCard = makeCard(scrollFrame, 84, C_STEEL)
		ModelPreviewHelper.CreatePreview(smokeCard, "Equipment", "SmokeGrenade", UDim2.fromOffset(56, 56), UDim2.new(0, 14, 0, 14), Color3.fromRGB(22, 24, 31), C_STEEL)
		local sName = Instance.new("TextLabel")
		sName.Position = UDim2.new(0, 78, 0, 10)
		sName.Size = UDim2.new(1, -246, 0, 20)
		sName.BackgroundTransparency = 1
		sName.Font = Enum.Font.GothamBlack
		sName.TextXAlignment = Enum.TextXAlignment.Left
		sName.TextSize = 13
		sName.TextColor3 = C_TEXT_PRIMARY
		sName.Text = string.format("TACTICAL SMOKE GRENADES  (%d / 12)  |  KEY [T]", smokeCount)
		sName.Parent = smokeCard
		local sDesc = Instance.new("TextLabel")
		sDesc.Position = UDim2.new(0, 78, 0, 34)
		sDesc.Size = UDim2.new(1, -246, 0, 40)
		sDesc.BackgroundTransparency = 1
		sDesc.Font = Enum.Font.Gotham
		sDesc.TextWrapped = true
		sDesc.TextXAlignment = Enum.TextXAlignment.Left
		sDesc.TextSize = 11
		sDesc.TextColor3 = C_TEXT_MUTED
		sDesc.Text = "Deploys a dense 10-second tactical smoke screen that breaks Rival & Apex Mafia line-of-sight during escapes or flanks."
		sDesc.Parent = smokeCard
		makeBtn(smokeCard, if smokeCount >= 12 then "FULL (12)" else "BUY 3X  180G", if smokeCount >= 12 then C_DISABLED else C_OXBLOOD, UDim2.new(1, -158, 0.5, -18), UDim2.fromOffset(146, 36), function()
			if smokeCount < 12 and dispatchAction then dispatchAction("BuySmokeGrenades", nil) end
		end)
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
	local currentStance = tostring(bgState.Stance or state.GuardStance or "Follow")
	selectedGuardSlot = math.clamp(selectedGuardSlot, 1, maxSlots)

	-- Squad Tactical Command Bar (Follow Me, Guard Central Park Bistro, Patrol Base, Free-Fire Aggressive)
	local stanceCard = makeCard(scrollFrame, 68, C_BRASS)
	local stHead = Instance.new("TextLabel")
	stHead.Position = UDim2.new(0, 14, 0, 6)
	stHead.Size = UDim2.new(1, -24, 0, 16)
	stHead.BackgroundTransparency = 1
	stHead.Font = Enum.Font.GothamBlack
	stHead.TextXAlignment = Enum.TextXAlignment.Left
	stHead.TextSize = 11
	stHead.TextColor3 = C_BRASS
	stHead.Text = string.format("BODYGUARD SQUAD TACTICAL ORDER [KEY X]  —  ACTIVE: %s", string.upper(tostring(bgState.StanceLabel or currentStance)))
	stHead.Parent = stanceCard

	local stRow = Instance.new("Frame")
	stRow.Position = UDim2.new(0, 14, 0, 26)
	stRow.Size = UDim2.new(1, -28, 0, 32)
	stRow.BackgroundTransparency = 1
	stRow.Parent = stanceCard
	local stl = Instance.new("UIListLayout")
	stl.FillDirection = Enum.FillDirection.Horizontal
	stl.Padding = UDim.new(0, 6)
	stl.Parent = stRow

	local stances = {
		{ Id = "Follow", Label = "FOLLOW ME" },
		{ Id = "GuardBistro", Label = "GUARD BISTRO" },
		{ Id = "PatrolBase", Label = "PATROL BASE" },
		{ Id = "Aggressive", Label = "AGGRESSIVE" },
	}
	for _, stOpt in ipairs(stances) do
		local isAct = (currentStance == stOpt.Id)
		local sb = makeBtn(
			stRow,
			stOpt.Label,
			if isAct then C_OWNED else C_BG_SUBTLE,
			UDim2.new(),
			UDim2.new(0.25, -5, 0, 30),
			function()
				if dispatchAction then
					dispatchAction("SetGuardStance", stOpt.Id)
				end
			end
		)
		sb.TextSize = 10
	end

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

local function renderBlackMarketMercenaries(state: { [string]: any }): ()
	if not scrollFrame then return end
	local merc = state.MercenaryMafia or {}
	local active = merc.Active == true
	local mercType = tostring(merc.MercType or "")
	local remSec = tonumber(merc.TimeRemaining) or 0
	local targetRest = merc.TargetRestaurantId
	local goldCost = tonumber(merc.GoldCost) or 20000
	local coins = tonumber(state.Profile and state.Profile.Coins) or 0

	local statusCard = makeCard(scrollFrame, 56, if active then C_OWNED else C_OXBLOOD)
	local sLbl = Instance.new("TextLabel")
	sLbl.Position = UDim2.new(0, 14, 0, 6)
	sLbl.Size = UDim2.new(1, -28, 1, -12)
	sLbl.BackgroundTransparency = 1
	sLbl.Font = Enum.Font.GothamBlack
	sLbl.TextWrapped = true
	sLbl.TextXAlignment = Enum.TextXAlignment.Left
	sLbl.TextSize = 12
	sLbl.TextColor3 = if active then Color3.fromRGB(178, 232, 184) else C_BRASS
	if active then
		local mins = math.floor(remSec / 60)
		local secs = remSec % 60
		sLbl.Text = string.format(
			"ACTIVE 5-MIN CONTRACT: %s MAFIA (%02d:%02d LEFT)  |  MODE: %s",
			string.upper(mercType),
			mins,
			secs,
			string.upper(tostring(merc.Mode or "ATTACK"))
		)
	else
		sLbl.Text = "HIRE STRONGER 5-MINUTE MERCENARY MAFIA (20,000 GOLD OR 199 R$)\nStronger than Rival Samurai/Ninja Mafia! Clash with Blade Spark VFX & storm Mafia Restaurants!"
	end
	sLbl.Parent = statusCard

	local mercSpecs = {
		{
			Type = "Samurai",
			Code = "SMR",
			Name = "KUROGANE SAMURAI MAFIA (3 ENFORCERS  |  5 MIN)",
			Desc = "3 elite Yakuza Samurai Enforcers (1,550 HP, 134 DMG katanas — stronger than Rival Samurai). Dominates Central Park Samurai clashes & restaurant raids!",
			RobuxId = "SamuraiMafiaContract",
		},
		{
			Type = "Ninja",
			Code = "NJA",
			Name = "KAGE NINJA ASSASSIN MAFIA (3 ASSASSINS  |  5 MIN)",
			Desc = "3 lethal Shinobi Assassins (1,350 HP, 29 Speed, 1.6x shadow-step crits — stronger than Rival Ninja/Samurai) with steel-spark clash VFX!",
			RobuxId = "NinjaMafiaContract",
		},
	}

	for _, ms in ipairs(mercSpecs) do
		local c = makeCard(scrollFrame, 108, C_OXBLOOD)
		ModelPreviewHelper.CreatePreview(c, "Empire", ms.Code, UDim2.fromOffset(66, 78), UDim2.new(0, 14, 0, 15), Color3.fromRGB(22, 24, 31), C_OXBLOOD)
		local t = Instance.new("TextLabel")
		t.Position = UDim2.new(0, 92, 0, 10)
		t.Size = UDim2.new(1, -266, 0, 20)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextSize = 13
		t.TextColor3 = C_TEXT_PRIMARY
		t.Text = ms.Name
		t.Parent = c

		local d = Instance.new("TextLabel")
		d.Position = UDim2.new(0, 92, 0, 34)
		d.Size = UDim2.new(1, -266, 0, 62)
		d.BackgroundTransparency = 1
		d.Font = Enum.Font.Gotham
		d.TextWrapped = true
		d.TextXAlignment = Enum.TextXAlignment.Left
		d.TextYAlignment = Enum.TextYAlignment.Top
		d.TextSize = 11
		d.TextColor3 = C_TEXT_MUTED
		d.Text = ms.Desc
		d.Parent = c

		local gBtn = makeBtn(c, string.format("HIRE  %d G", goldCost), if coins >= goldCost then C_OXBLOOD else C_DISABLED, UDim2.new(1, -162, 0, 14), UDim2.fromOffset(150, 36), function()
			if dispatchAction then dispatchAction("HireMercenaryMafia", ms.Type) end
		end)
		gBtn.TextSize = 11

		local rBtn = makeBtn(c, "HIRE  R$ 199 (5M)", C_ROBUX, UDim2.new(1, -162, 0, 58), UDim2.fromOffset(150, 36), function()
			showConfirmDialog(
				"CONFIRM 5-MIN MAFIA CONTRACT",
				string.format("Deploy %s for 5 minutes for R$ 199?\nStronger than Rival Samurai/Ninja Mafia — use ATTACK [Y] & CALL BACK [Z] anytime!", ms.Name),
				"HIRE  R$ 199",
				C_ROBUX,
				function()
					if dispatchAction then dispatchAction("BuyRobuxItem", ms.RobuxId) end
				end
			)
		end)
		rBtn.TextSize = 10
		local rst = rBtn:FindFirstChildOfClass("UIStroke")
		if rst then rst.Color = C_BRASS end
	end

	-- Command Panel: Direct your Samurai/Ninja Mafia to storm a Mafia-Controlled Restaurant!
	local cmdCard = makeCard(scrollFrame, 84, C_BRASS)
	local cHead = Instance.new("TextLabel")
	cHead.Position = UDim2.new(0, 14, 0, 6)
	cHead.Size = UDim2.new(1, -24, 0, 18)
	cHead.BackgroundTransparency = 1
	cHead.Font = Enum.Font.GothamBlack
	cHead.TextXAlignment = Enum.TextXAlignment.Left
	cHead.TextSize = 11
	cHead.TextColor3 = C_BRASS
	cHead.Text = "COMMAND HIRED MAFIA SQUAD  —  SELECT TARGET RESTAURANT TO CONQUER"
	cHead.Parent = cmdCard

	local cRow = Instance.new("Frame")
	cRow.Position = UDim2.new(0, 14, 0, 28)
	cRow.Size = UDim2.new(1, -28, 0, 44)
	cRow.BackgroundTransparency = 1
	cRow.Parent = cmdCard
	local cl = Instance.new("UIListLayout")
	cl.FillDirection = Enum.FillDirection.Horizontal
	cl.Padding = UDim.new(0, 6)
	cl.Parent = cRow

	local orders = {
		{ Id = "ObsidianNoodleHouse", Label = "STORM NOODLE HOUSE" },
		{ Id = "VelvetSteakhouse", Label = "STORM STEAKHOUSE" },
		{ Id = "ImperialOysterBar", Label = "STORM OYSTER BAR" },
		{ Id = "Follow", Label = "ESCORT ME" },
	}
	for _, ord in ipairs(orders) do
		local isCur = active and ((ord.Id == "Follow" and targetRest == nil) or (targetRest == ord.Id))
		local ob = makeBtn(cRow, ord.Label, if isCur then C_OWNED elseif active then C_OXBLOOD else C_DISABLED, UDim2.new(), UDim2.new(0.25, -5, 0, 40), function()
			if dispatchAction then dispatchAction("OrderMercenaryAssault", ord.Id) end
		end)
		ob.TextSize = 9
		ob.TextWrapped = true
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
		{ Id = "Ammo", Label = "AMMO", ActiveCol = C_STEEL },
		{ Id = "Bodyguards", Label = "GUARDS", ActiveCol = C_OXBLOOD },
		{ Id = "Mercenaries", Label = "MAFIA HIRE", ActiveCol = C_OXBLOOD },
		{ Id = "Premium", Label = "R$ VIP", ActiveCol = C_ROBUX },
	}
	for _, st in ipairs(subTabs) do
		local active = (currentBMSubTab == st.Id)
		local btn = makeBtn(subBar, st.Label, if active then st.ActiveCol else C_BG_CARD_ALT, UDim2.new(), UDim2.new(0.20, -5, 0, 32), function()
			currentBMSubTab = st.Id
			render()
		end)
		btn.TextSize = 10
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
	elseif currentBMSubTab == "Mercenaries" then
		renderBlackMarketMercenaries(state)
	else
		renderBlackMarketPremium(state)
	end
end

local function updateVisibleViewports(): ()
	local sf = scrollFrame
	if not sf or not modalFrame or not modalFrame.Visible then
		return
	end
	local viewTop = sf.AbsolutePosition.Y - 120
	local viewBot = sf.AbsolutePosition.Y + sf.AbsoluteSize.Y + 120
	for _, card in ipairs(sf:GetChildren()) do
		if card:IsA("GuiObject") then
			local vp = card:FindFirstChild("Preview3D")
			if vp and vp:IsA("ViewportFrame") then
				local cTop = card.AbsolutePosition.Y
				local cBot = cTop + card.AbsoluteSize.Y
				vp.Visible = (cBot >= viewTop) and (cTop <= viewBot)
			end
		end
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
	-- Cull offscreen 3D ViewportFrames so Roblox's GPU viewport atlas never drops top/visible icons!
	updateVisibleViewports()
	task.defer(updateVisibleViewports)
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
			if currentTab ~= t.Id and scrollFrame then
				scrollFrame.CanvasPosition = Vector2.new(0, 0)
			end
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
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateVisibleViewports)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateVisibleViewports)

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
	if currentTab ~= tab and scrollFrame then
		scrollFrame.CanvasPosition = Vector2.new(0, 0)
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
