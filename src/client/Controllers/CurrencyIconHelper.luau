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
	kind: "Food" | "Fruit" | "Gun" | "Ninja" | "Empire" | "Ammo" | "Guard" | "Robux",
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
	local st = math.clamp(sizePx * 0.045, 1.1, 1.8)

	if kind == "Food" then
		-- REAL GOURMET CHEESEBURGER (Sesame Brioche Bun + Lettuce + Tomato + Dripping Cheddar + Seared Patty!)
		-- Bottom toasted bun
		local botBun = makeShape(root, UDim2.fromScale(0.50, 0.80), UDim2.fromScale(0.80, 0.22), Color3.fromRGB(224, 148, 56), math.ceil(sizePx * 0.14), z + 1, 0, ink, st)
		addVertGrad(botBun, Color3.fromRGB(244, 178, 86), Color3.fromRGB(186, 108, 32))
		-- Thick seared beef patty
		local patty = makeShape(root, UDim2.fromScale(0.50, 0.66), UDim2.fromScale(0.86, 0.22), Color3.fromRGB(118, 56, 30), math.ceil(sizePx * 0.14), z + 2, 0, ink, st)
		addVertGrad(patty, Color3.fromRGB(148, 74, 42), Color3.fromRGB(78, 34, 18))
		-- Melted golden cheddar slice + dripping corner triangle
		makeShape(root, UDim2.fromScale(0.50, 0.56), UDim2.fromScale(0.84, 0.12), Color3.fromRGB(255, 204, 34), 3, z + 3, 0, ink, st * 0.7)
		makeShape(root, UDim2.fromScale(0.68, 0.63), UDim2.fromScale(0.18, 0.18), Color3.fromRGB(255, 194, 24), 2, z + 3, 45, ink, st * 0.6)
		makeShape(root, UDim2.fromScale(0.32, 0.61), UDim2.fromScale(0.14, 0.14), Color3.fromRGB(255, 204, 34), 2, z + 3, 45, ink, st * 0.6)
		-- Juicy ruby tomato slice
		makeShape(root, UDim2.fromScale(0.50, 0.49), UDim2.fromScale(0.78, 0.12), Color3.fromRGB(238, 46, 46), 4, z + 4, 0, ink, st * 0.7)
		-- Crisp wavy emerald lettuce puffs
		for i = 0, 3 do
			makeShape(root, UDim2.fromScale(0.20 + i * 0.20, 0.45), UDim2.fromScale(0.26, 0.15), Color3.fromRGB(72, 204, 68), math.ceil(sizePx * 0.12), z + 5, if i % 2 == 0 then -8 else 8, ink, st * 0.6)
		end
		-- Golden dome brioche top bun
		local topBun = makeShape(root, UDim2.fromScale(0.50, 0.28), UDim2.fromScale(0.82, 0.36), Color3.fromRGB(246, 168, 58), math.ceil(sizePx * 0.35), z + 6, 0, ink, st)
		addVertGrad(topBun, Color3.fromRGB(255, 204, 96), Color3.fromRGB(214, 126, 32))
		-- Glossy sheen + 4 crisp golden sesame seeds
		makeShape(root, UDim2.fromScale(0.32, 0.18), UDim2.fromScale(0.20, 0.08), Color3.fromRGB(255, 246, 204), 8, z + 7, -20)
		makeShape(root, UDim2.fromScale(0.46, 0.22), UDim2.fromScale(0.10, 0.06), Color3.fromRGB(255, 246, 208), 4, z + 7, -14)
		makeShape(root, UDim2.fromScale(0.64, 0.21), UDim2.fromScale(0.10, 0.06), Color3.fromRGB(255, 246, 208), 4, z + 7, 16)
		makeShape(root, UDim2.fromScale(0.34, 0.30), UDim2.fromScale(0.10, 0.06), Color3.fromRGB(255, 246, 208), 4, z + 7, 12)
		makeShape(root, UDim2.fromScale(0.58, 0.31), UDim2.fromScale(0.10, 0.06), Color3.fromRGB(255, 246, 208), 4, z + 7, -16)

	elseif kind == "Fruit" then
		-- REAL GLOSSY RED APPLE + EMERALD LEAF + CURVED GOLDEN BANANA!
		-- Curved bright banana peeking neatly behind right side
		makeShape(root, UDim2.fromScale(0.74, 0.56), UDim2.fromScale(0.28, 0.62), Color3.fromRGB(254, 224, 48), math.ceil(sizePx * 0.32), z + 1, 28, ink, st)
		makeShape(root, UDim2.fromScale(0.84, 0.28), UDim2.fromScale(0.12, 0.12), Color3.fromRGB(108, 78, 32), 4, z + 2, 24)
		-- Plump double-lobed glossy red apple
		local lobeL = makeShape(root, UDim2.fromScale(0.34, 0.60), UDim2.fromScale(0.48, 0.60), Color3.fromRGB(234, 34, 46), math.ceil(sizePx * 0.34), z + 3, -6, ink, st)
		addVertGrad(lobeL, Color3.fromRGB(255, 78, 78), Color3.fromRGB(178, 18, 34))
		local lobeR = makeShape(root, UDim2.fromScale(0.54, 0.60), UDim2.fromScale(0.48, 0.60), Color3.fromRGB(224, 28, 42), math.ceil(sizePx * 0.34), z + 3, 6, ink, st)
		addVertGrad(lobeR, Color3.fromRGB(255, 72, 72), Color3.fromRGB(168, 16, 30))
		-- Seamless apple center blend + bright glossy top-left specular highlight
		local core = makeShape(root, UDim2.fromScale(0.44, 0.61), UDim2.fromScale(0.42, 0.52), Color3.fromRGB(236, 36, 48), math.ceil(sizePx * 0.25), z + 4)
		addVertGrad(core, Color3.fromRGB(255, 78, 76), Color3.fromRGB(182, 20, 36))
		makeShape(root, UDim2.fromScale(0.28, 0.46), UDim2.fromScale(0.14, 0.24), Color3.fromRGB(255, 224, 224), math.ceil(sizePx * 0.14), z + 5, -18)
		-- Curved wooden brown stem + angled vibrant emerald leaf!
		makeShape(root, UDim2.fromScale(0.44, 0.25), UDim2.fromScale(0.10, 0.24), Color3.fromRGB(126, 74, 34), 3, z + 6, 14, ink, st * 0.7)
		local leaf = makeShape(root, UDim2.fromScale(0.62, 0.22), UDim2.fromScale(0.32, 0.18), Color3.fromRGB(58, 204, 66), math.ceil(sizePx * 0.18), z + 7, -26, ink, st * 0.8)
		addVertGrad(leaf, Color3.fromRGB(118, 242, 98), Color3.fromRGB(34, 154, 48))

	elseif kind == "Gun" then
		-- REAL TACTICAL ASSAULT RIFLE (Angled side silhouette: Stock, Receiver, Curved Mag, Optic, Handguard & Muzzle!)
		local gunPivot = Instance.new("Frame")
		gunPivot.AnchorPoint = Vector2.new(0.5, 0.5)
		gunPivot.Position = UDim2.fromScale(0.50, 0.52)
		gunPivot.Size = UDim2.fromScale(1.0, 1.0)
		gunPivot.Rotation = -16
		gunPivot.BackgroundTransparency = 1
		gunPivot.Active = false
		gunPivot.ZIndex = z + 1
		gunPivot.Parent = root

		local gunMetal = Color3.fromRGB(64, 72, 88)
		local darkGun = Color3.fromRGB(30, 34, 44)
		local steelHi = Color3.fromRGB(196, 206, 224)
		local redAccent = Color3.fromRGB(232, 42, 62)

		-- Buttstock + buffer tube
		makeShape(gunPivot, UDim2.fromScale(0.14, 0.54), UDim2.fromScale(0.22, 0.22), darkGun, 3, z + 2, 0, ink, st)
		makeShape(gunPivot, UDim2.fromScale(0.26, 0.48), UDim2.fromScale(0.14, 0.10), gunMetal, 2, z + 2, 0, ink, st * 0.8)
		-- Angled pistol grip & trigger guard
		makeShape(gunPivot, UDim2.fromScale(0.35, 0.67), UDim2.fromScale(0.11, 0.24), darkGun, 3, z + 2, 20, ink, st)
		-- Curved tactical banana magazine!
		makeShape(gunPivot, UDim2.fromScale(0.55, 0.68), UDim2.fromScale(0.12, 0.28), redAccent, 3, z + 2, -16, ink, st)
		-- Upper & Lower Receiver with chrome bolt ejection port
		local rec = makeShape(gunPivot, UDim2.fromScale(0.48, 0.48), UDim2.fromScale(0.36, 0.18), gunMetal, 3, z + 4, 0, ink, st)
		addVertGrad(rec, Color3.fromRGB(104, 116, 138), Color3.fromRGB(46, 52, 66))
		makeShape(gunPivot, UDim2.fromScale(0.52, 0.46), UDim2.fromScale(0.12, 0.06), steelHi, 1, z + 5)
		-- Top Red-Dot Holographic Sight with cyan lens
		makeShape(gunPivot, UDim2.fromScale(0.46, 0.34), UDim2.fromScale(0.18, 0.12), darkGun, 2, z + 5, 0, ink, st * 0.8)
		makeShape(gunPivot, UDim2.fromScale(0.52, 0.34), UDim2.fromScale(0.05, 0.08), Color3.fromRGB(64, 214, 255), 1, z + 6)
		-- Vented Handguard + Sleek Steel Barrel + Front Sight + Ported Muzzle Brake!
		makeShape(gunPivot, UDim2.fromScale(0.70, 0.48), UDim2.fromScale(0.22, 0.14), darkGun, 2, z + 4, 0, ink, st)
		makeShape(gunPivot, UDim2.fromScale(0.84, 0.48), UDim2.fromScale(0.18, 0.07), steelHi, 2, z + 3, 0, ink, st * 0.8)
		makeShape(gunPivot, UDim2.fromScale(0.79, 0.39), UDim2.fromScale(0.05, 0.10), darkGun, 1, z + 5)
		makeShape(gunPivot, UDim2.fromScale(0.92, 0.48), UDim2.fromScale(0.10, 0.11), redAccent, 2, z + 5, 0, ink, st * 0.8)

	elseif kind == "Ninja" then
		-- REAL SHINOBI NINJA (Crossed Twin Katanas + Black Cowl + Crimson Headband + Steel Clan Plate + Fierce Eyes!)
		local crimson = Color3.fromRGB(224, 30, 52)
		local cowl = Color3.fromRGB(24, 28, 38)
		local gold = Color3.fromRGB(246, 198, 52)
		local steel = Color3.fromRGB(204, 214, 228)

		-- Crossed Twin Katana Hilts + Gold Tsubas behind shoulders (X-silhouette!)
		makeShape(root, UDim2.fromScale(0.18, 0.24), UDim2.fromScale(0.12, 0.36), crimson, 3, z + 1, -38, ink, st)
		makeShape(root, UDim2.fromScale(0.26, 0.32), UDim2.fromScale(0.22, 0.07), gold, 2, z + 2, -38, ink, st * 0.7)
		makeShape(root, UDim2.fromScale(0.82, 0.24), UDim2.fromScale(0.12, 0.36), crimson, 3, z + 1, 38, ink, st)
		makeShape(root, UDim2.fromScale(0.74, 0.32), UDim2.fromScale(0.22, 0.07), gold, 2, z + 2, 38, ink, st * 0.7)
		-- Fluttering crimson headband tails on right
		makeShape(root, UDim2.fromScale(0.86, 0.50), UDim2.fromScale(0.22, 0.10), crimson, 3, z + 2, 26, ink, st * 0.7)
		makeShape(root, UDim2.fromScale(0.82, 0.60), UDim2.fromScale(0.20, 0.09), crimson, 3, z + 2, 42, ink, st * 0.7)
		-- Rounded matte-black Shinobi Cowl Head
		local head = makeShape(root, UDim2.fromScale(0.50, 0.54), UDim2.fromScale(0.68, 0.72), cowl, math.ceil(sizePx * 0.36), z + 3, 0, ink, st)
		addVertGrad(head, Color3.fromRGB(48, 54, 72), Color3.fromRGB(16, 18, 26))
		-- Crimson Hachimaki Headband + Riveted Steel Forehead Plate!
		makeShape(root, UDim2.fromScale(0.50, 0.36), UDim2.fromScale(0.72, 0.16), crimson, 4, z + 4, 0, ink, st * 0.8)
		local plate = makeShape(root, UDim2.fromScale(0.50, 0.36), UDim2.fromScale(0.42, 0.14), steel, 3, z + 5, 0, ink, st * 0.8)
		addVertGrad(plate, Color3.fromRGB(242, 248, 255), Color3.fromRGB(142, 154, 174))
		-- Exposed Eye Slit + Fierce Narrowed Warrior Eyes!
		makeShape(root, UDim2.fromScale(0.50, 0.54), UDim2.fromScale(0.52, 0.18), Color3.fromRGB(238, 198, 162), 6, z + 5, 0, ink, st * 0.7)
		makeShape(root, UDim2.fromScale(0.38, 0.54), UDim2.fromScale(0.16, 0.09), Color3.fromRGB(255, 255, 255), 3, z + 6, 12, ink, st * 0.5)
		makeShape(root, UDim2.fromScale(0.62, 0.54), UDim2.fromScale(0.16, 0.09), Color3.fromRGB(255, 255, 255), 3, z + 6, -12, ink, st * 0.5)
		makeShape(root, UDim2.fromScale(0.40, 0.54), UDim2.fromScale(0.07, 0.07), crimson, 4, z + 7)
		makeShape(root, UDim2.fromScale(0.60, 0.54), UDim2.fromScale(0.07, 0.07), crimson, 4, z + 7)
		-- Crimson Shinobi Scarf Collar at chin
		makeShape(root, UDim2.fromScale(0.50, 0.86), UDim2.fromScale(0.64, 0.16), crimson, 6, z + 6, 0, ink, st * 0.8)

	elseif kind == "Empire" then
		-- 24K IMPERIAL ROYAL GOLD CROWN (Crimson Velvet Dome + 3 Gold Peaks + Jewels!)
		local gold = Color3.fromRGB(255, 206, 46)
		local ruby = Color3.fromRGB(232, 32, 58)
		local sapphire = Color3.fromRGB(48, 152, 252)
		makeShape(root, UDim2.fromScale(0.50, 0.54), UDim2.fromScale(0.64, 0.44), Color3.fromRGB(172, 22, 44), math.ceil(sizePx * 0.24), z + 1, 0, ink, st)
		-- 3 Gold Crown Spires
		makeShape(root, UDim2.fromScale(0.24, 0.46), UDim2.fromScale(0.22, 0.44), gold, 3, z + 2, -16, ink, st)
		makeShape(root, UDim2.fromScale(0.76, 0.46), UDim2.fromScale(0.22, 0.44), gold, 3, z + 2, 16, ink, st)
		local midPeak = makeShape(root, UDim2.fromScale(0.50, 0.40), UDim2.fromScale(0.26, 0.54), gold, 3, z + 3, 0, ink, st)
		addVertGrad(midPeak, Color3.fromRGB(255, 244, 152), Color3.fromRGB(224, 146, 18))
		-- Gold Orbs at Spire Tips
		makeShape(root, UDim2.fromScale(0.18, 0.24), UDim2.fromScale(0.16, 0.16), Color3.fromRGB(255, 242, 156), 12, z + 4, 0, ink, st * 0.8)
		makeShape(root, UDim2.fromScale(0.50, 0.14), UDim2.fromScale(0.18, 0.18), Color3.fromRGB(255, 242, 156), 12, z + 4, 0, ink, st * 0.8)
		makeShape(root, UDim2.fromScale(0.82, 0.24), UDim2.fromScale(0.16, 0.16), Color3.fromRGB(255, 242, 156), 12, z + 4, 0, ink, st * 0.8)
		-- Crown Base Band + Ruby & Sapphire Jewels
		local band = makeShape(root, UDim2.fromScale(0.50, 0.72), UDim2.fromScale(0.80, 0.26), gold, 6, z + 5, 0, ink, st)
		addVertGrad(band, Color3.fromRGB(255, 232, 114), Color3.fromRGB(204, 128, 16))
		makeShape(root, UDim2.fromScale(0.50, 0.72), UDim2.fromScale(0.16, 0.16), ruby, 3, z + 6, 45, ink, st * 0.6)
		makeShape(root, UDim2.fromScale(0.26, 0.72), UDim2.fromScale(0.12, 0.12), sapphire, 3, z + 6, 45, ink, st * 0.6)
		makeShape(root, UDim2.fromScale(0.74, 0.72), UDim2.fromScale(0.12, 0.12), sapphire, 3, z + 6, 45, ink, st * 0.6)

	elseif kind == "Ammo" then
		-- 3 GLEAMING BRASS RIFLE CARTRIDGES WITH COPPER BULLET TIPS!
		for i = -1, 1 do
			local cx = 0.50 + i * 0.24
			local yOff = if i == 0 then -0.05 else 0.04
			local tip = makeShape(root, UDim2.fromScale(cx, 0.28 + yOff), UDim2.fromScale(0.17, 0.28), Color3.fromRGB(218, 118, 54), math.ceil(sizePx * 0.16), z + 2, 0, ink, st * 0.8)
			addVertGrad(tip, Color3.fromRGB(248, 168, 98), Color3.fromRGB(168, 76, 32), 0)
			local casing = makeShape(root, UDim2.fromScale(cx, 0.62 + yOff), UDim2.fromScale(0.20, 0.48), Color3.fromRGB(246, 198, 58), 3, z + 3, 0, ink, st)
			addVertGrad(casing, Color3.fromRGB(255, 236, 138), Color3.fromRGB(194, 132, 24), 0)
		end

	else
		-- TACTICAL ARMORED BODYGUARD ("Guard": Ballistic Helmet + Dark Shades + White Collar + Crimson Tie!)
		makeShape(root, UDim2.fromScale(0.50, 0.78), UDim2.fromScale(0.78, 0.34), Color3.fromRGB(28, 34, 48), 8, z + 1, 0, ink, st)
		makeShape(root, UDim2.fromScale(0.50, 0.78), UDim2.fromScale(0.24, 0.28), Color3.fromRGB(246, 246, 248), 3, z + 2)
		makeShape(root, UDim2.fromScale(0.50, 0.80), UDim2.fromScale(0.10, 0.24), Color3.fromRGB(220, 32, 52), 2, z + 3)
		makeShape(root, UDim2.fromScale(0.50, 0.46), UDim2.fromScale(0.48, 0.46), Color3.fromRGB(238, 196, 160), math.ceil(sizePx * 0.24), z + 3, 0, ink, st)
		local helm = makeShape(root, UDim2.fromScale(0.50, 0.28), UDim2.fromScale(0.58, 0.34), Color3.fromRGB(52, 62, 82), math.ceil(sizePx * 0.28), z + 4, 0, ink, st)
		addVertGrad(helm, Color3.fromRGB(96, 112, 142), Color3.fromRGB(32, 38, 52))
		makeShape(root, UDim2.fromScale(0.50, 0.46), UDim2.fromScale(0.46, 0.14), Color3.fromRGB(16, 20, 30), 4, z + 5, 0, ink, st * 0.7)
		makeShape(root, UDim2.fromScale(0.40, 0.45), UDim2.fromScale(0.10, 0.04), Color3.fromRGB(132, 208, 255), 2, z + 6, -18)
	end

	return root
end

return CurrencyIconHelper
