--!strict

-- CurrencyIconHelper: Crisp, front-page Roblox studio-grade vector currency & category icons
-- (24K Gold Bullion Coin, clean geometric Robux Hex Token & bold outlined price decorations).

local CurrencyIconHelper = {}

local function addCorner(parent: Instance, r: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function addStroke(parent: Instance, col: Color3, thick: number, trans: number?): UIStroke
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = col
	st.Thickness = thick
	if trans then
		st.Transparency = trans
	end
	st.Parent = parent
	return st
end

-- Studio-grade sunlit 24K Gold Coin (bold dark cartoon-AAA outline, bright shine slash & crisp G stamp)
function CurrencyIconHelper.CreateGoldCoin(parent: Instance, sizePx: number, pos: UDim2?, zIndex: number?): Frame
	local z = zIndex or 2
	local coin = Instance.new("Frame")
	coin.Name = "GoldCoinIcon"
	coin.Size = UDim2.fromOffset(sizePx, sizePx)
	if pos then
		coin.Position = pos
	end
	coin.BackgroundColor3 = Color3.fromRGB(255, 214, 58)
	coin.BorderSizePixel = 0
	coin.ZIndex = z
	coin.Parent = parent
	addCorner(coin, math.ceil(sizePx * 0.5))
	addStroke(coin, Color3.fromRGB(58, 32, 6), math.clamp(sizePx * 0.11, 1.6, 2.6))

	local outerGrad = Instance.new("UIGradient")
	outerGrad.Rotation = 125
	outerGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 178)),
		ColorSequenceKeypoint.new(0.42, Color3.fromRGB(255, 206, 46)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 124, 12)),
	})
	outerGrad.Parent = coin

	local innerSize = math.max(8, sizePx - math.max(5, math.floor(sizePx * 0.26)))
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromOffset(innerSize, innerSize)
	inner.BackgroundColor3 = Color3.fromRGB(246, 174, 24)
	inner.BorderSizePixel = 0
	inner.ZIndex = z + 1
	inner.Parent = coin
	addCorner(inner, math.ceil(innerSize * 0.5))
	addStroke(inner, Color3.fromRGB(255, 245, 172), 1.1, 0.15)

	-- Crisp top-left glossy specular pill
	local glint = Instance.new("Frame")
	glint.Position = UDim2.fromScale(0.16, 0.12)
	glint.Size = UDim2.fromScale(0.32, 0.20)
	glint.Rotation = -30
	glint.BackgroundColor3 = Color3.fromRGB(255, 255, 242)
	glint.BackgroundTransparency = 0.18
	glint.BorderSizePixel = 0
	glint.ZIndex = z + 2
	glint.Parent = inner
	addCorner(glint, 6)

	local stamp = Instance.new("TextLabel")
	stamp.Size = UDim2.fromScale(1, 1)
	stamp.BackgroundTransparency = 1
	stamp.Font = Enum.Font.GothamBlack
	stamp.Text = "G"
	stamp.TextSize = math.max(9, math.floor(sizePx * 0.56))
	stamp.TextColor3 = Color3.fromRGB(255, 248, 206)
	stamp.ZIndex = z + 3
	stamp.Parent = inner
	local stText = Instance.new("UIStroke")
	stText.Color = Color3.fromRGB(116, 62, 6)
	stText.Thickness = 1.4
	stText.Parent = stamp

	return coin
end

-- Ultra-clean Roblox-authentic Robux Diamond/Hex Token (zero overlapping border muddiness!)
function CurrencyIconHelper.CreateRobuxIcon(parent: Instance, sizePx: number, pos: UDim2?, zIndex: number?): Frame
	local z = zIndex or 2
	local holder = Instance.new("Frame")
	holder.Name = "RobuxIcon"
	holder.Size = UDim2.fromOffset(sizePx, sizePx)
	if pos then
		holder.Position = pos
	end
	holder.BackgroundTransparency = 1
	holder.ZIndex = z
	holder.Parent = parent

	-- Clean crisp rotated diamond nut with bold dark outline
	local diaSize = math.max(10, math.floor(sizePx * 0.72))
	local outer = Instance.new("Frame")
	outer.AnchorPoint = Vector2.new(0.5, 0.5)
	outer.Position = UDim2.fromScale(0.5, 0.5)
	outer.Size = UDim2.fromOffset(diaSize, diaSize)
	outer.Rotation = 45
	outer.BackgroundColor3 = Color3.fromRGB(238, 255, 244)
	outer.BorderSizePixel = 0
	outer.ZIndex = z + 1
	outer.Parent = holder
	addCorner(outer, math.max(2, math.floor(diaSize * 0.22)))
	addStroke(outer, Color3.fromRGB(14, 62, 36), math.clamp(sizePx * 0.11, 1.6, 2.4))

	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(172, 248, 204)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(64, 214, 134)),
	})
	grad.Parent = outer

	-- Crisp inner cutout frame
	local holeSize = math.max(6, math.floor(diaSize * 0.58))
	local hole = Instance.new("Frame")
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.fromScale(0.5, 0.5)
	hole.Size = UDim2.fromOffset(holeSize, holeSize)
	hole.Rotation = 45
	hole.BackgroundColor3 = Color3.fromRGB(16, 72, 42)
	hole.BorderSizePixel = 0
	hole.ZIndex = z + 2
	hole.Parent = holder
	addCorner(hole, math.max(1, math.floor(holeSize * 0.22)))

	-- Signature upright center Robux square gem!
	local gemSize = math.max(4, math.floor(sizePx * 0.24))
	local gem = Instance.new("Frame")
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromScale(0.5, 0.5)
	gem.Size = UDim2.fromOffset(gemSize, gemSize)
	gem.BackgroundColor3 = Color3.fromRGB(255, 252, 224)
	gem.BorderSizePixel = 0
	gem.ZIndex = z + 3
	gem.Parent = holder
	addCorner(gem, 1)

	return holder
end

-- Detects whether a button label represents a Robux or Gold currency action and attaches a crisp inline icon!
function CurrencyIconHelper.DecorateCurrencyButton(btn: TextButton, labelText: string, iconSize: number?): ()
	local upper = string.upper(labelText)
	local isRobux = (string.find(upper, "R$", 1, true) ~= nil) or (string.find(upper, "ROBUX", 1, true) ~= nil)
	local isGold = (not isRobux) and (
		string.find(upper, "%d+%s*G%f[^%a]") ~= nil
		or string.find(upper, "%d+,%d+%s*G%f[^%a]") ~= nil
		or string.find(upper, "%d+%s*GOLD") ~= nil
		or string.find(upper, "%d+,%d+%s*GOLD") ~= nil
	)
	if not isRobux and not isGold then
		return
	end

	local prev = btn:FindFirstChild("CurrencyIconRow")
	if prev then prev:Destroy() end

	local sz = iconSize or 16
	local textCol = btn.TextColor3
	local textSz = btn.TextSize
	local font = btn.Font
	btn.Text = ""

	local row = Instance.new("Frame")
	row.Name = "CurrencyIconRow"
	row.Size = UDim2.fromScale(1, 1)
	row.BackgroundTransparency = 1
	row.Active = false
	row.Selectable = false
	row.ZIndex = btn.ZIndex + 1
	row.Parent = btn

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row

	local iconFrame = if isRobux
		then CurrencyIconHelper.CreateRobuxIcon(row, sz, nil, btn.ZIndex + 2)
		else CurrencyIconHelper.CreateGoldCoin(row, sz, nil, btn.ZIndex + 2)
	iconFrame.LayoutOrder = 1

	local lbl = Instance.new("TextLabel")
	lbl.Name = "PriceText"
	lbl.LayoutOrder = 2
	lbl.AutomaticSize = Enum.AutomaticSize.X
	lbl.Size = UDim2.fromOffset(0, sz + 6)
	lbl.BackgroundTransparency = 1
	lbl.Font = font
	lbl.Text = labelText
	lbl.TextSize = textSz
	lbl.TextColor3 = textCol
	lbl.ZIndex = btn.ZIndex + 2
	lbl.Parent = row

	local txtStroke = Instance.new("UIStroke")
	txtStroke.Color = Color3.fromRGB(10, 12, 18)
	txtStroke.Thickness = 1.6
	txtStroke.Parent = lbl

	btn:GetPropertyChangedSignal("TextSize"):Connect(function()
		if lbl.Parent then lbl.TextSize = btn.TextSize end
	end)
	btn:GetPropertyChangedSignal("TextColor3"):Connect(function()
		if lbl.Parent then lbl.TextColor3 = btn.TextColor3 end
	end)
end

-- ============================================================================
-- STUDIO-GRADE VECTOR CATEGORY ICONS (ZERO ViewportFrame GPU SLOTS!)
-- Crisp, unmistakable Real Food, Real Fruit, Real Gun, Real Ninja, Empire Crown,
-- Brass Ammo & Tactical Bodyguard icons that render razor-sharp at any size!
-- ============================================================================
local function makeShape(
	parent: Instance,
	pos: UDim2,
	size: UDim2,
	col: Color3,
	cornerPx: number,
	z: number,
	rot: number?,
	strokeCol: Color3?,
	strokeThick: number?
): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = col
	f.BorderSizePixel = 0
	f.Active = false
	f.Selectable = false
	f.ZIndex = z
	if rot then
		f.Rotation = rot
	end
	f.Parent = parent
	if cornerPx > 0 then
		addCorner(f, cornerPx)
	end
	if strokeCol and strokeThick and strokeThick > 0 then
		addStroke(f, strokeCol, strokeThick)
	end
	return f
end

local function addVertGrad(parent: Instance, topCol: Color3, botCol: Color3, rot: number?): ()
	local g = Instance.new("UIGradient")
	g.Rotation = rot or 90
	g.Color = ColorSequence.new(topCol, botCol)
	g.Parent = parent
end

function CurrencyIconHelper.CreateCategoryIcon(
	parent: Instance,
	kind: "Food" | "Fruit" | "Storage" | "Gun" | "Ninja" | "Empire" | "Ammo" | "Guard" | "Robux",
	sizePx: number,
	pos: UDim2?,
	zIndex: number?
): Frame
	local z = zIndex or 4
	if kind == "Robux" then
		return CurrencyIconHelper.CreateRobuxIcon(parent, sizePx, pos, z)
	end

	local root = Instance.new("Frame")
	root.Name = "CategoryVectorIcon_" .. kind
	root.Size = UDim2.fromOffset(sizePx, sizePx)
	if pos then
		root.Position = pos
	end
	root.BackgroundTransparency = 1
	root.Active = false
	root.Selectable = false
	root.ZIndex = z
	root.Parent = parent

	local ink = Color3.fromRGB(14, 16, 24)
	local st = math.clamp(sizePx * 0.048, 1.2, 1.9)

	if kind == "Food" then
		-- CRISP PLATED GOURMET BURGER (Clean White Ceramic Plate + Brioche Sesame Bun + Lettuce + Tomato + Cheddar + Patty!)
		-- Porcelain plate base for crisp contrast on dark & warm backgrounds
		makeShape(root, UDim2.fromScale(0.50, 0.87), UDim2.fromScale(0.94, 0.16), Color3.fromRGB(238, 242, 248), math.ceil(sizePx * 0.12), z, 0, ink, st * 0.9)
		-- Bottom toasted bun
		local botBun = makeShape(root, UDim2.fromScale(0.50, 0.77), UDim2.fromScale(0.76, 0.18), Color3.fromRGB(224, 148, 56), math.ceil(sizePx * 0.12), z + 1, 0, ink, st)
		addVertGrad(botBun, Color3.fromRGB(246, 182, 88), Color3.fromRGB(186, 108, 32))
		-- Thick seared beef patty
		local patty = makeShape(root, UDim2.fromScale(0.50, 0.64), UDim2.fromScale(0.84, 0.19), Color3.fromRGB(122, 58, 32), math.ceil(sizePx * 0.12), z + 2, 0, ink, st)
		addVertGrad(patty, Color3.fromRGB(154, 78, 44), Color3.fromRGB(82, 36, 18))
		-- Melted golden cheddar slice + dripping corner
		makeShape(root, UDim2.fromScale(0.50, 0.54), UDim2.fromScale(0.82, 0.11), Color3.fromRGB(255, 210, 40), 3, z + 3, 0, ink, st * 0.7)
		makeShape(root, UDim2.fromScale(0.68, 0.61), UDim2.fromScale(0.16, 0.16), Color3.fromRGB(255, 198, 26), 2, z + 3, 45, ink, st * 0.6)
		-- Juicy ruby tomato slice
		makeShape(root, UDim2.fromScale(0.50, 0.46), UDim2.fromScale(0.76, 0.11), Color3.fromRGB(242, 48, 52), 4, z + 4, 0, ink, st * 0.7)
		-- Crisp emerald lettuce puffs
		for i = 0, 3 do
			makeShape(root, UDim2.fromScale(0.22 + i * 0.185, 0.42), UDim2.fromScale(0.24, 0.14), Color3.fromRGB(76, 214, 74), math.ceil(sizePx * 0.12), z + 5, if i % 2 == 0 then -8 else 8, ink, st * 0.6)
		end
		-- Golden dome brioche top bun
		local topBun = makeShape(root, UDim2.fromScale(0.50, 0.25), UDim2.fromScale(0.80, 0.34), Color3.fromRGB(248, 174, 62), math.ceil(sizePx * 0.34), z + 6, 0, ink, st)
		addVertGrad(topBun, Color3.fromRGB(255, 212, 108), Color3.fromRGB(218, 130, 34))
		-- Glossy sheen + sesame seeds
		makeShape(root, UDim2.fromScale(0.32, 0.16), UDim2.fromScale(0.20, 0.08), Color3.fromRGB(255, 250, 218), 8, z + 7, -18)
		makeShape(root, UDim2.fromScale(0.48, 0.20), UDim2.fromScale(0.10, 0.06), Color3.fromRGB(255, 250, 218), 4, z + 7, -12)
		makeShape(root, UDim2.fromScale(0.64, 0.20), UDim2.fromScale(0.10, 0.06), Color3.fromRGB(255, 250, 218), 4, z + 7, 14)

	elseif kind == "Storage" then
		-- UNMISTAKABLE WAREHOUSE SUPPLY CRATE (Golden-Oak Timber Box + Cross-Brace + Brushed Steel Corner Brackets + Sky Cargo Tag!)
		local woodMain = Color3.fromRGB(216, 152, 74)
		local woodTrim = Color3.fromRGB(168, 106, 44)
		local steel = Color3.fromRGB(206, 218, 234)
		-- Main wooden crate body
		local crate = makeShape(root, UDim2.fromScale(0.50, 0.54), UDim2.fromScale(0.82, 0.78), woodMain, math.ceil(sizePx * 0.12), z + 1, 0, ink, st)
		addVertGrad(crate, Color3.fromRGB(238, 178, 96), Color3.fromRGB(178, 114, 48))
		-- Inner recessed plank panel + horizontal plank grooves
		makeShape(root, UDim2.fromScale(0.50, 0.54), UDim2.fromScale(0.62, 0.58), Color3.fromRGB(192, 128, 56), 2, z + 2, 0, woodTrim, st * 0.8)
		makeShape(root, UDim2.fromScale(0.50, 0.44), UDim2.fromScale(0.60, 0.05), woodTrim, 1, z + 3)
		makeShape(root, UDim2.fromScale(0.50, 0.64), UDim2.fromScale(0.60, 0.05), woodTrim, 1, z + 3)
		-- Bold diagonal reinforcement timber brace
		local brace = makeShape(root, UDim2.fromScale(0.50, 0.54), UDim2.fromScale(0.76, 0.14), woodMain, 2, z + 4, -42, ink, st * 0.7)
		addVertGrad(brace, Color3.fromRGB(246, 192, 112), Color3.fromRGB(186, 120, 50))
		-- 4 Gleaming Steel Corner Brackets
		for _, cx in ipairs({ 0.16, 0.84 }) do
			for _, cy in ipairs({ 0.22, 0.86 }) do
				makeShape(root, UDim2.fromScale(cx, cy), UDim2.fromScale(0.18, 0.18), steel, 2, z + 5, 0, ink, st * 0.7)
			end
		end
		-- Top Crate Lid Bevel + Bright Cyan Warehouse Inventory Seal Tag
		makeShape(root, UDim2.fromScale(0.50, 0.16), UDim2.fromScale(0.88, 0.14), Color3.fromRGB(244, 188, 108), 3, z + 6, 0, ink, st * 0.8)
		local tag = makeShape(root, UDim2.fromScale(0.72, 0.36), UDim2.fromScale(0.28, 0.22), Color3.fromRGB(56, 194, 248), 3, z + 7, 0, ink, st * 0.7)
		addVertGrad(tag, Color3.fromRGB(122, 224, 255), Color3.fromRGB(24, 146, 214))

	elseif kind == "Fruit" then
		-- REAL GLOSSY RED APPLE + EMERALD LEAF + CURVED GOLDEN BANANA!
		makeShape(root, UDim2.fromScale(0.74, 0.56), UDim2.fromScale(0.28, 0.62), Color3.fromRGB(254, 224, 48), math.ceil(sizePx * 0.32), z + 1, 28, ink, st)
		makeShape(root, UDim2.fromScale(0.84, 0.28), UDim2.fromScale(0.12, 0.12), Color3.fromRGB(108, 78, 32), 4, z + 2, 24)
		local lobeL = makeShape(root, UDim2.fromScale(0.34, 0.60), UDim2.fromScale(0.48, 0.60), Color3.fromRGB(234, 34, 46), math.ceil(sizePx * 0.34), z + 3, -6, ink, st)
		addVertGrad(lobeL, Color3.fromRGB(255, 78, 78), Color3.fromRGB(178, 18, 34))
		local lobeR = makeShape(root, UDim2.fromScale(0.54, 0.60), UDim2.fromScale(0.48, 0.60), Color3.fromRGB(224, 28, 42), math.ceil(sizePx * 0.34), z + 3, 6, ink, st)
		addVertGrad(lobeR, Color3.fromRGB(255, 72, 72), Color3.fromRGB(168, 16, 30))
		local core = makeShape(root, UDim2.fromScale(0.44, 0.61), UDim2.fromScale(0.42, 0.52), Color3.fromRGB(236, 36, 48), math.ceil(sizePx * 0.25), z + 4)
		addVertGrad(core, Color3.fromRGB(255, 78, 76), Color3.fromRGB(182, 20, 36))
		makeShape(root, UDim2.fromScale(0.28, 0.46), UDim2.fromScale(0.14, 0.24), Color3.fromRGB(255, 224, 224), math.ceil(sizePx * 0.14), z + 5, -18)
		makeShape(root, UDim2.fromScale(0.44, 0.25), UDim2.fromScale(0.10, 0.24), Color3.fromRGB(126, 74, 34), 3, z + 6, 14, ink, st * 0.7)
		local leaf = makeShape(root, UDim2.fromScale(0.62, 0.22), UDim2.fromScale(0.32, 0.18), Color3.fromRGB(58, 204, 66), math.ceil(sizePx * 0.18), z + 7, -26, ink, st * 0.8)
		addVertGrad(leaf, Color3.fromRGB(118, 242, 98), Color3.fromRGB(34, 154, 48))

	elseif kind == "Gun" then
		-- HIGH-CONTRAST CHROME & CRIMSON TACTICAL RIFLE (Razor-sharp bright steel silhouette that POPS on dark backgrounds!)
		local gunPivot = Instance.new("Frame")
		gunPivot.AnchorPoint = Vector2.new(0.5, 0.5)
		gunPivot.Position = UDim2.fromScale(0.50, 0.52)
		gunPivot.Size = UDim2.fromScale(1.0, 1.0)
		gunPivot.Rotation = -22
		gunPivot.BackgroundTransparency = 1
		gunPivot.Active = false
		gunPivot.ZIndex = z + 1
		gunPivot.Parent = root

		local brightSteel = Color3.fromRGB(224, 232, 246)
		local midSteel = Color3.fromRGB(152, 166, 190)
		local gripCol = Color3.fromRGB(98, 110, 132)
		local redAccent = Color3.fromRGB(246, 52, 74)
		local goldGlint = Color3.fromRGB(255, 214, 82)

		-- Buttstock + buffer tube (bright mid-steel so it never vanishes on dark buttons!)
		makeShape(gunPivot, UDim2.fromScale(0.13, 0.54), UDim2.fromScale(0.22, 0.24), midSteel, 3, z + 2, 0, ink, st)
		makeShape(gunPivot, UDim2.fromScale(0.26, 0.48), UDim2.fromScale(0.14, 0.12), brightSteel, 2, z + 2, 0, ink, st * 0.8)
		-- Angled pistol grip
		makeShape(gunPivot, UDim2.fromScale(0.35, 0.68), UDim2.fromScale(0.12, 0.25), gripCol, 3, z + 2, 18, ink, st)
		-- Vibrant crimson curved tactical magazine!
		local mag = makeShape(gunPivot, UDim2.fromScale(0.55, 0.69), UDim2.fromScale(0.14, 0.30), redAccent, 3, z + 2, -16, ink, st)
		addVertGrad(mag, Color3.fromRGB(255, 92, 110), Color3.fromRGB(196, 24, 46))
		-- Gleaming Chrome/Steel Receiver + Gold Bolt Carrier!
		local rec = makeShape(gunPivot, UDim2.fromScale(0.49, 0.48), UDim2.fromScale(0.38, 0.20), brightSteel, 3, z + 4, 0, ink, st)
		addVertGrad(rec, Color3.fromRGB(248, 252, 255), Color3.fromRGB(156, 170, 194))
		makeShape(gunPivot, UDim2.fromScale(0.52, 0.47), UDim2.fromScale(0.14, 0.07), goldGlint, 2, z + 5)
		-- Top Tactical Optic with glowing cyan lens
		makeShape(gunPivot, UDim2.fromScale(0.47, 0.33), UDim2.fromScale(0.20, 0.13), midSteel, 2, z + 5, 0, ink, st * 0.8)
		makeShape(gunPivot, UDim2.fromScale(0.54, 0.33), UDim2.fromScale(0.06, 0.09), Color3.fromRGB(84, 224, 255), 2, z + 6)
		-- Handguard + Bright Chrome Barrel + Crimson Compensator!
		makeShape(gunPivot, UDim2.fromScale(0.71, 0.48), UDim2.fromScale(0.22, 0.16), midSteel, 2, z + 4, 0, ink, st)
		makeShape(gunPivot, UDim2.fromScale(0.84, 0.48), UDim2.fromScale(0.18, 0.09), brightSteel, 2, z + 3, 0, ink, st * 0.8)
		makeShape(gunPivot, UDim2.fromScale(0.93, 0.48), UDim2.fromScale(0.12, 0.13), redAccent, 2, z + 5, 0, ink, st * 0.8)

	elseif kind == "Ninja" then
		-- HIGH-CONTRAST SHINOBI NINJA (Crossed Steel Katanas + Slate-Black Cowl + Crimson Headband + Gleaming Forehead Plate!)
		local crimson = Color3.fromRGB(238, 42, 64)
		local cowl = Color3.fromRGB(58, 66, 86)
		local gold = Color3.fromRGB(252, 206, 62)
		local steel = Color3.fromRGB(224, 234, 248)

		-- Crossed Twin Katana Hilts + Gold Tsubas behind shoulders
		makeShape(root, UDim2.fromScale(0.18, 0.24), UDim2.fromScale(0.13, 0.38), crimson, 3, z + 1, -38, ink, st)
		makeShape(root, UDim2.fromScale(0.26, 0.32), UDim2.fromScale(0.24, 0.08), gold, 2, z + 2, -38, ink, st * 0.7)
		makeShape(root, UDim2.fromScale(0.82, 0.24), UDim2.fromScale(0.13, 0.38), crimson, 3, z + 1, 38, ink, st)
		makeShape(root, UDim2.fromScale(0.74, 0.32), UDim2.fromScale(0.24, 0.08), gold, 2, z + 2, 38, ink, st * 0.7)
		-- Fluttering crimson headband tails
		makeShape(root, UDim2.fromScale(0.86, 0.50), UDim2.fromScale(0.22, 0.11), crimson, 3, z + 2, 26, ink, st * 0.7)
		makeShape(root, UDim2.fromScale(0.82, 0.60), UDim2.fromScale(0.20, 0.10), crimson, 3, z + 2, 42, ink, st * 0.7)
		-- Contrast-lit Shinobi Cowl Head
		local head = makeShape(root, UDim2.fromScale(0.50, 0.54), UDim2.fromScale(0.68, 0.72), cowl, math.ceil(sizePx * 0.36), z + 3, 0, ink, st)
		addVertGrad(head, Color3.fromRGB(92, 102, 128), Color3.fromRGB(36, 42, 58))
		-- Crimson Hachimaki Headband + Riveted Chrome Forehead Plate
		makeShape(root, UDim2.fromScale(0.50, 0.36), UDim2.fromScale(0.72, 0.16), crimson, 4, z + 4, 0, ink, st * 0.8)
		local plate = makeShape(root, UDim2.fromScale(0.50, 0.36), UDim2.fromScale(0.44, 0.15), steel, 3, z + 5, 0, ink, st * 0.8)
		addVertGrad(plate, Color3.fromRGB(252, 254, 255), Color3.fromRGB(162, 174, 198))
		-- Exposed Eye Slit + Fierce Narrowed Warrior Eyes
		makeShape(root, UDim2.fromScale(0.50, 0.54), UDim2.fromScale(0.54, 0.19), Color3.fromRGB(244, 204, 168), 6, z + 5, 0, ink, st * 0.7)
		makeShape(root, UDim2.fromScale(0.38, 0.54), UDim2.fromScale(0.16, 0.09), Color3.fromRGB(255, 255, 255), 3, z + 6, 12, ink, st * 0.5)
		makeShape(root, UDim2.fromScale(0.62, 0.54), UDim2.fromScale(0.16, 0.09), Color3.fromRGB(255, 255, 255), 3, z + 6, -12, ink, st * 0.5)
		makeShape(root, UDim2.fromScale(0.40, 0.54), UDim2.fromScale(0.08, 0.08), crimson, 4, z + 7)
		makeShape(root, UDim2.fromScale(0.60, 0.54), UDim2.fromScale(0.08, 0.08), crimson, 4, z + 7)
		-- Crimson Shinobi Scarf Collar
		makeShape(root, UDim2.fromScale(0.50, 0.86), UDim2.fromScale(0.64, 0.16), crimson, 6, z + 6, 0, ink, st * 0.8)

	elseif kind == "Empire" then
		-- 24K IMPERIAL ROYAL GOLD CROWN (Crimson Velvet Dome + 3 Gleaming Gold Spires + Jewels!)
		local gold = Color3.fromRGB(255, 212, 54)
		local ruby = Color3.fromRGB(238, 36, 62)
		local sapphire = Color3.fromRGB(58, 168, 255)
		makeShape(root, UDim2.fromScale(0.50, 0.54), UDim2.fromScale(0.66, 0.44), Color3.fromRGB(184, 24, 48), math.ceil(sizePx * 0.24), z + 1, 0, ink, st)
		makeShape(root, UDim2.fromScale(0.24, 0.46), UDim2.fromScale(0.22, 0.44), gold, 3, z + 2, -16, ink, st)
		makeShape(root, UDim2.fromScale(0.76, 0.46), UDim2.fromScale(0.22, 0.44), gold, 3, z + 2, 16, ink, st)
		local midPeak = makeShape(root, UDim2.fromScale(0.50, 0.40), UDim2.fromScale(0.26, 0.54), gold, 3, z + 3, 0, ink, st)
		addVertGrad(midPeak, Color3.fromRGB(255, 248, 174), Color3.fromRGB(224, 146, 18))
		makeShape(root, UDim2.fromScale(0.18, 0.23), UDim2.fromScale(0.16, 0.16), Color3.fromRGB(255, 246, 172), 12, z + 4, 0, ink, st * 0.8)
		makeShape(root, UDim2.fromScale(0.50, 0.14), UDim2.fromScale(0.18, 0.18), Color3.fromRGB(255, 246, 172), 12, z + 4, 0, ink, st * 0.8)
		makeShape(root, UDim2.fromScale(0.82, 0.23), UDim2.fromScale(0.16, 0.16), Color3.fromRGB(255, 246, 172), 12, z + 4, 0, ink, st * 0.8)
		local band = makeShape(root, UDim2.fromScale(0.50, 0.72), UDim2.fromScale(0.82, 0.27), gold, 6, z + 5, 0, ink, st)
		addVertGrad(band, Color3.fromRGB(255, 238, 134), Color3.fromRGB(204, 128, 16))
		makeShape(root, UDim2.fromScale(0.50, 0.72), UDim2.fromScale(0.17, 0.17), ruby, 3, z + 6, 45, ink, st * 0.6)
		makeShape(root, UDim2.fromScale(0.25, 0.72), UDim2.fromScale(0.13, 0.13), sapphire, 3, z + 6, 45, ink, st * 0.6)
		makeShape(root, UDim2.fromScale(0.75, 0.72), UDim2.fromScale(0.13, 0.13), sapphire, 3, z + 6, 45, ink, st * 0.6)

	elseif kind == "Ammo" then
		-- 3 GLEAMING BRASS RIFLE CARTRIDGES WITH COPPER BULLET TIPS!
		for i = -1, 1 do
			local cx = 0.50 + i * 0.24
			local yOff = if i == 0 then -0.05 else 0.04
			local tip = makeShape(root, UDim2.fromScale(cx, 0.28 + yOff), UDim2.fromScale(0.18, 0.28), Color3.fromRGB(232, 128, 62), math.ceil(sizePx * 0.16), z + 2, 0, ink, st * 0.8)
			addVertGrad(tip, Color3.fromRGB(255, 184, 114), Color3.fromRGB(178, 82, 34), 0)
			local casing = makeShape(root, UDim2.fromScale(cx, 0.62 + yOff), UDim2.fromScale(0.21, 0.48), Color3.fromRGB(252, 206, 68), 3, z + 3, 0, ink, st)
			addVertGrad(casing, Color3.fromRGB(255, 242, 152), Color3.fromRGB(204, 138, 28), 0)
		end

	else
		-- HIGH-CONTRAST TACTICAL BODYGUARD SHIELD & HELMET EMBLEM ("Guard": Gleaming Steel Helmet + Dark Visor + Crisp Suit & Crimson Tie!)
		makeShape(root, UDim2.fromScale(0.50, 0.78), UDim2.fromScale(0.80, 0.34), Color3.fromRGB(62, 74, 98), 8, z + 1, 0, ink, st)
		makeShape(root, UDim2.fromScale(0.50, 0.78), UDim2.fromScale(0.26, 0.28), Color3.fromRGB(248, 248, 252), 3, z + 2)
		makeShape(root, UDim2.fromScale(0.50, 0.80), UDim2.fromScale(0.11, 0.24), Color3.fromRGB(238, 42, 62), 2, z + 3)
		makeShape(root, UDim2.fromScale(0.50, 0.46), UDim2.fromScale(0.48, 0.46), Color3.fromRGB(244, 202, 166), math.ceil(sizePx * 0.24), z + 3, 0, ink, st)
		local helm = makeShape(root, UDim2.fromScale(0.50, 0.28), UDim2.fromScale(0.60, 0.36), Color3.fromRGB(118, 136, 168), math.ceil(sizePx * 0.28), z + 4, 0, ink, st)
		addVertGrad(helm, Color3.fromRGB(168, 186, 218), Color3.fromRGB(68, 80, 108))
		makeShape(root, UDim2.fromScale(0.50, 0.46), UDim2.fromScale(0.48, 0.15), Color3.fromRGB(20, 26, 38), 4, z + 5, 0, ink, st * 0.7)
		makeShape(root, UDim2.fromScale(0.39, 0.45), UDim2.fromScale(0.12, 0.05), Color3.fromRGB(132, 218, 255), 2, z + 6, -16)
	end

	return root
end

return CurrencyIconHelper
