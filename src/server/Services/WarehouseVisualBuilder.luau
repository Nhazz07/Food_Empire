--!strict

-- WarehouseVisualBuilder: Builds 100% UI-icon-matched 3D Clash-style Ingredient Warehouses
-- (Fish Harbor Barn, Vegetable Farm Barn, Fruit Orchard Barn, Meat Brick Smokehouse)
-- with cohesive Lv.0 (blueprint ghost) -> Lv.1 (exact icon match) -> Lv.10 (Royal Depot) upgrades!

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)

export type WarehouseCategory = WarehouseConfig.WarehouseCategory

local WarehouseVisualBuilder = {}

-- Old placeholder part names inside the base WarehousePlot model to hide cleanly
local LEGACY_HIDE_NAMES: { [string]: boolean } = {
	Body = true,
	Roof_Left = true,
	Roof_Right = true,
	TrimBand = true,
	FrontAwning = true,
	DoorFrame = true,
	CrateBase = true,
	CategoryProp = true,
}

type CategoryTheme = {
	RoofMain: Color3,
	RoofAlt: Color3,
	RoofRidge: Color3,
	WallMain: Color3,
	WallMat: Enum.Material,
	TimberTrim: Color3,
	PlinthCol: Color3,
	PlinthMat: Enum.Material,
	BeaconCol: Color3,
}

local THEMES: { [WarehouseCategory]: CategoryTheme } = {
	Fish = {
		RoofMain = Color3.fromRGB(46, 134, 224),
		RoofAlt = Color3.fromRGB(34, 110, 194),
		RoofRidge = Color3.fromRGB(28, 86, 158),
		WallMain = Color3.fromRGB(184, 126, 72),
		WallMat = Enum.Material.WoodPlanks,
		TimberTrim = Color3.fromRGB(106, 66, 38),
		PlinthCol = Color3.fromRGB(116, 122, 134),
		PlinthMat = Enum.Material.Cobblestone,
		BeaconCol = Color3.fromRGB(96, 218, 255),
	},
	Vegetable = {
		RoofMain = Color3.fromRGB(52, 174, 72),
		RoofAlt = Color3.fromRGB(38, 146, 56),
		RoofRidge = Color3.fromRGB(28, 114, 42),
		WallMain = Color3.fromRGB(178, 116, 64),
		WallMat = Enum.Material.WoodPlanks,
		TimberTrim = Color3.fromRGB(102, 62, 34),
		PlinthCol = Color3.fromRGB(122, 116, 102),
		PlinthMat = Enum.Material.Cobblestone,
		BeaconCol = Color3.fromRGB(112, 242, 132),
	},
	Fruit = {
		RoofMain = Color3.fromRGB(238, 142, 36),
		RoofAlt = Color3.fromRGB(210, 116, 26),
		RoofRidge = Color3.fromRGB(172, 88, 18),
		WallMain = Color3.fromRGB(194, 134, 72),
		WallMat = Enum.Material.WoodPlanks,
		TimberTrim = Color3.fromRGB(120, 72, 38),
		PlinthCol = Color3.fromRGB(158, 140, 112),
		PlinthMat = Enum.Material.Cobblestone,
		BeaconCol = Color3.fromRGB(255, 206, 84),
	},
	Meat = {
		RoofMain = Color3.fromRGB(198, 46, 54),
		RoofAlt = Color3.fromRGB(168, 34, 42),
		RoofRidge = Color3.fromRGB(134, 24, 30),
		WallMain = Color3.fromRGB(176, 78, 58),
		WallMat = Enum.Material.Brick,
		TimberTrim = Color3.fromRGB(118, 70, 40),
		PlinthCol = Color3.fromRGB(96, 98, 108),
		PlinthMat = Enum.Material.Slate,
		BeaconCol = Color3.fromRGB(255, 116, 92),
	},
}

function WarehouseVisualBuilder.ApplyToPlot(plot: Model, category: WarehouseCategory, level: number): ()
	local padPart = plot:FindFirstChild("PlotPivot")
	if not padPart or not padPart:IsA("BasePart") then
		return
	end
	local theme = THEMES[category]
	if not theme then
		return
	end

	-- Clear legacy Tier2/Tier3 & old WarehouseEvolutionVisuals if present
	local tier2 = plot:FindFirstChild("Tier2")
	if tier2 then tier2:ClearAllChildren() end
	local tier3 = plot:FindFirstChild("Tier3")
	if tier3 then tier3:ClearAllChildren() end
	local oldEvo = plot:FindFirstChild("WarehouseEvolutionVisuals")
	if oldEvo then oldEvo:Destroy() end

	-- Hide legacy primitive parts cleanly while keeping CargoDoor (prompt trigger) & SignPlate functional!
	for _, desc in ipairs(plot:GetDescendants()) do
		if desc:IsA("BasePart") then
			if LEGACY_HIDE_NAMES[desc.Name] then
				desc.Transparency = 1
				desc.CanCollide = false
				desc.CanTouch = false
				desc.CanQuery = false
				desc.CastShadow = false
			elseif desc.Name == "CargoDoor" then
				-- Keep invisible interaction box at front doorway so ProximityPrompt [E] works seamlessly!
				desc.Transparency = 1
				desc.CanCollide = false
			end
		end
	end

	local baseCF = padPart.CFrame

	-- Position SignPlate cleanly above the front gable roof ridge so text never clips shingles
	local signPlate = plot:FindFirstChild("SignPlate", true)
	if signPlate and signPlate:IsA("BasePart") then
		local signY = if level >= 6 then 27.6 else 22.8
		signPlate.Size = Vector3.new(18.5, 3.2, 0.5)
		signPlate.CFrame = baseCF * CFrame.new(0, signY, 10.6)
		signPlate.Color = Color3.fromRGB(20, 24, 34)
		signPlate.Material = Enum.Material.SmoothPlastic
		signPlate.CanCollide = false
	end

	-- Check if we already built the exact same category + level
	local existing = plot:FindFirstChild("WarehouseIconArchitecture")
	if existing
		and existing:GetAttribute("BuiltCategory") == category
		and existing:GetAttribute("BuiltLevel") == level
	then
		return
	end
	if existing then
		existing:Destroy()
	end

	local isGhost = (level <= 0)
	local folder = Instance.new("Folder")
	folder.Name = "WarehouseIconArchitecture"
	folder:SetAttribute("BuiltCategory", category)
	folder:SetAttribute("BuiltLevel", level)

	local gold = Color3.fromRGB(246, 198, 66)
	local neonGold = Color3.fromRGB(255, 224, 128)
	local warmGlow = Color3.fromRGB(255, 218, 138)
	local darkIron = Color3.fromRGB(40, 44, 54)
	local steel = Color3.fromRGB(178, 188, 202)
	local crateWood = Color3.fromRGB(182, 126, 68)
	local crateDark = Color3.fromRGB(124, 78, 40)
	local creamTrim = Color3.fromRGB(238, 228, 206)

	local function wPart(
		name: string,
		sz: Vector3,
		relCF: CFrame,
		col: Color3,
		mat: Enum.Material,
		collide: boolean?,
		shape: Enum.PartType?,
		transp: number?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = baseCF * relCF
		p.Color = col
		p.Material = mat
		if shape then
			p.Shape = shape
		end
		if isGhost then
			p.Transparency = math.max(0.74, transp or 0)
			p.CanCollide = false
		else
			p.Transparency = transp or 0
			p.CanCollide = if collide == nil then true else collide
		end
		p.Anchored = true
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = not isGhost
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = folder
		return p
	end

	local function wWedge(
		name: string,
		sz: Vector3,
		relCF: CFrame,
		col: Color3,
		mat: Enum.Material,
		collide: boolean?
	): WedgePart
		local w = Instance.new("WedgePart")
		w.Name = name
		w.Size = sz
		w.CFrame = baseCF * relCF
		w.Color = col
		w.Material = mat
		if isGhost then
			w.Transparency = 0.74
			w.CanCollide = false
		else
			w.Transparency = 0
			w.CanCollide = if collide == nil then true else collide
		end
		w.Anchored = true
		w.CanTouch = false
		w.CanQuery = false
		w.CastShadow = not isGhost
		w.TopSurface = Enum.SurfaceType.Smooth
		w.BottomSurface = Enum.SurfaceType.Smooth
		w.Parent = folder
		return w
	end

	local function addLantern(name: string, relPos: Vector3, range: number, brightness: number): ()
		wPart(name .. "_Arm", Vector3.new(0.45, 0.35, 1.1), CFrame.new(relPos + Vector3.new(0, 0.65, -0.35)), darkIron, Enum.Material.Metal, false)
		wPart(name .. "_Cap", Vector3.new(1.15, 0.35, 1.15), CFrame.new(relPos + Vector3.new(0, 0.55, 0)), gold, Enum.Material.Metal, false)
		local bulb = wPart(name .. "_Glow", Vector3.new(0.82, 1.05, 0.82), CFrame.new(relPos), warmGlow, Enum.Material.Neon, false)
		if not isGhost then
			local pl = Instance.new("PointLight")
			pl.Color = warmGlow
			pl.Range = range
			pl.Brightness = brightness
			pl.Shadows = false
			pl.Parent = bulb
		end
	end

	-- Reusable true pitched Clash-style shingle gable roof (zero inverted V!)
	local function buildPitchedShingleRoof(
		prefix: string,
		cx: number,
		eaveY: number,
		cz: number,
		spanX: number,
		depthZ: number,
		riseY: number,
		roofMain: Color3,
		roofAlt: Color3,
		roofRidge: Color3,
		gableWallCol: Color3,
		gableWallMat: Enum.Material,
		bargeCol: Color3
	): ()
		local halfX = spanX * 0.5
		local slopeLen = math.sqrt(halfX * halfX + riseY * riseY) + 1.4
		local angle = math.atan2(riseY, halfX) -- positive tilt for left slope rising toward center!
		local midY = eaveY + riseY * 0.5

		-- Left roof slope (rises +X -> +Y, so rotate Z by +angle)
		wPart(
			prefix .. "_SlopeL",
			Vector3.new(slopeLen, 0.85, depthZ),
			CFrame.new(cx - halfX * 0.5 - 0.25, midY, cz) * CFrame.Angles(0, 0, angle),
			roofMain,
			Enum.Material.WoodPlanks,
			true
		)
		-- Right roof slope (falls +X -> -Y, so rotate Z by -angle)
		wPart(
			prefix .. "_SlopeR",
			Vector3.new(slopeLen, 0.85, depthZ),
			CFrame.new(cx + halfX * 0.5 + 0.25, midY, cz) * CFrame.Angles(0, 0, -angle),
			roofMain,
			Enum.Material.WoodPlanks,
			true
		)

		-- Layered horizontal shingle courses along both roof slopes (iconic stylized Clash look!)
		local courses = 4
		for c = 1, courses do
			local frac = (c - 0.5) / courses
			local ox = halfX * (1 - frac) + 0.1
			local oy = eaveY + riseY * frac + 0.42
			local courseCol = if c % 2 == 0 then roofAlt else roofMain
			local courseW = slopeLen / courses + 0.35
			wPart(
				prefix .. "_ShingleL_" .. c,
				Vector3.new(courseW, 0.36, depthZ + 0.25),
				CFrame.new(cx - ox, oy, cz) * CFrame.Angles(0, 0, angle),
				courseCol,
				Enum.Material.SmoothPlastic,
				false
			)
			wPart(
				prefix .. "_ShingleR_" .. c,
				Vector3.new(courseW, 0.36, depthZ + 0.25),
				CFrame.new(cx + ox, oy, cz) * CFrame.Angles(0, 0, -angle),
				courseCol,
				Enum.Material.SmoothPlastic,
				false
			)
		end

		-- Roof Ridge Beam Cap
		wPart(prefix .. "_RidgeCap", Vector3.new(1.75, 1.15, depthZ + 0.9), CFrame.new(cx, eaveY + riseY + 0.45, cz), roofRidge, Enum.Material.Wood, false)

		-- Front & Rear Timber Bargeboard Fascia Trim along gable triangles
		for _, fz in ipairs({ cz + depthZ * 0.5 - 0.15, cz - depthZ * 0.5 + 0.15 }) do
			wPart(
				prefix .. "_BargeL",
				Vector3.new(slopeLen + 0.2, 0.95, 0.65),
				CFrame.new(cx - halfX * 0.5 - 0.25, midY - 0.12, fz) * CFrame.Angles(0, 0, angle),
				bargeCol,
				Enum.Material.Wood,
				false
			)
			wPart(
				prefix .. "_BargeR",
				Vector3.new(slopeLen + 0.2, 0.95, 0.65),
				CFrame.new(cx + halfX * 0.5 + 0.25, midY - 0.12, fz) * CFrame.Angles(0, 0, -angle),
				bargeCol,
				Enum.Material.Wood,
				false
			)
		end

		-- Solid Gable End Triangle Infills (Left & Right WedgeParts on Front & Back -> 100% flush under roof slopes!)
		local wallD = depthZ - 2.6
		local gableHalf = halfX - 0.8
		-- WedgePart has its tall vertical back at local +Z and thin tip at local -Z.
		-- Rotate Y by +90 deg: local +Z maps to +X (center ridge), local -Z maps to -X (left eave)!
		-- Rotate Y by -90 deg: local +Z maps to -X (center ridge), local -Z maps to +X (right eave)!
		for _, gz in ipairs({ cz + wallD * 0.5 - 0.35, cz - wallD * 0.5 + 0.35 }) do
			wWedge(
				prefix .. "_GableL",
				Vector3.new(0.95, riseY - 0.35, gableHalf),
				CFrame.new(cx - gableHalf * 0.5, midY - 0.20, gz) * CFrame.Angles(0, math.rad(90), 0),
				gableWallCol,
				gableWallMat,
				false
			)
			wWedge(
				prefix .. "_GableR",
				Vector3.new(0.95, riseY - 0.35, gableHalf),
				CFrame.new(cx + gableHalf * 0.5, midY - 0.20, gz) * CFrame.Angles(0, math.rad(-90), 0),
				gableWallCol,
				gableWallMat,
				false
			)
		end
	end

	-- Reusable open-top wooden crate builder
	local function buildOpenCrate(prefix: string, pos: Vector3, sz: number, rotDeg: number?): CFrame
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotDeg or 0), 0)
		local h = sz * 0.72
		wPart(prefix .. "_Base", Vector3.new(sz, 0.32, sz), cf * CFrame.new(0, 0.16, 0), crateDark, Enum.Material.WoodPlanks, true)
		wPart(prefix .. "_WallF", Vector3.new(sz, h, 0.28), cf * CFrame.new(0, h * 0.5, sz * 0.5 - 0.14), crateWood, Enum.Material.WoodPlanks, false)
		wPart(prefix .. "_WallB", Vector3.new(sz, h, 0.28), cf * CFrame.new(0, h * 0.5, -sz * 0.5 + 0.14), crateWood, Enum.Material.WoodPlanks, false)
		wPart(prefix .. "_WallL", Vector3.new(0.28, h, sz), cf * CFrame.new(-sz * 0.5 + 0.14, h * 0.5, 0), crateWood, Enum.Material.WoodPlanks, false)
		wPart(prefix .. "_WallR", Vector3.new(0.28, h, sz), cf * CFrame.new(sz * 0.5 - 0.14, h * 0.5, 0), crateWood, Enum.Material.WoodPlanks, false)
		for _, cx in ipairs({ -sz * 0.46, sz * 0.46 }) do
			for _, cz in ipairs({ -sz * 0.46, sz * 0.46 }) do
				wPart(prefix .. "_Corner", Vector3.new(0.38, h + 0.12, 0.38), cf * CFrame.new(cx, h * 0.5, cz), crateDark, Enum.Material.Wood, false)
			end
		end
		return cf
	end

	-- Reusable sealed slatted butcher cargo crate
	local function buildClosedCrate(prefix: string, pos: Vector3, sz: number, rotDeg: number?): ()
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotDeg or 0), 0)
		wPart(prefix .. "_Core", Vector3.new(sz, sz, sz), cf * CFrame.new(0, sz * 0.5, 0), crateWood, Enum.Material.WoodPlanks, true)
		wPart(prefix .. "_TrimT", Vector3.new(sz + 0.22, 0.34, sz + 0.22), cf * CFrame.new(0, sz - 0.16, 0), crateDark, Enum.Material.Wood, false)
		wPart(prefix .. "_TrimB", Vector3.new(sz + 0.22, 0.34, sz + 0.22), cf * CFrame.new(0, 0.18, 0), crateDark, Enum.Material.Wood, false)
		wPart(prefix .. "_StrapF", Vector3.new(sz * 0.92, 0.28, 0.16), cf * CFrame.new(0, sz * 0.5, sz * 0.5 + 0.04) * CFrame.Angles(0, 0, math.rad(40)), crateDark, Enum.Material.Wood, false)
		wPart(prefix .. "_StrapS", Vector3.new(0.16, 0.28, sz * 0.92), cf * CFrame.new(sz * 0.5 + 0.04, sz * 0.5, 0) * CFrame.Angles(math.rad(40), 0, 0), crateDark, Enum.Material.Wood, false)
	end

	-- =========================================================================
	-- CORE ICON-MATCHED BARN STRUCTURE (LV.1 BASE + FOUNDATION + TIMBER FRAME)
	-- =========================================================================
	local wallW = 24.0
	local wallH = 11.2
	local wallD = 20.8
	local barnZ = -0.8
	local plinthH = 1.2
	local wallBotY = 0.3 + plinthH
	local eaveY = wallBotY + wallH

	-- 1. Stone / Cobblestone Plinth Foundation (slightly wider than walls like all 4 icons!)
	wPart("FoundationPlinth", Vector3.new(wallW + 2.8, plinthH, wallD + 2.8), CFrame.new(0, 0.3 + plinthH * 0.5, barnZ), theme.PlinthCol, theme.PlinthMat, true)
	wPart("FoundationStep", Vector3.new(11.4, 0.55, 3.0), CFrame.new(0, 0.58, barnZ + wallD * 0.5 + 2.2), theme.PlinthCol, theme.PlinthMat, true)

	-- 2. Main Barn Body
	wPart("BarnBody", Vector3.new(wallW, wallH, wallD), CFrame.new(0, wallBotY + wallH * 0.5, barnZ), theme.WallMain, theme.WallMat, true)

	-- 3. Corner Timber Posts / Brick Stone Quoins & Horizontal Wainscot Framing
	for _, sx in ipairs({ -wallW * 0.5, wallW * 0.5 }) do
		for _, sz in ipairs({ barnZ - wallD * 0.5, barnZ + wallD * 0.5 }) do
			if category == "Meat" then
				-- Alternating sandstone corner quoins on the Red Brick Butcher Smokehouse!
				for q = 0, 4 do
					local qCol = if q % 2 == 0 then creamTrim else Color3.fromRGB(204, 184, 152)
					wPart("BrickQuoin_" .. q, Vector3.new(1.55, 1.9, 1.55), CFrame.new(sx, wallBotY + 1.1 + q * 2.2, sz), qCol, Enum.Material.Concrete, false)
				end
			else
				wPart("CornerTimber", Vector3.new(1.45, wallH + 0.3, 1.45), CFrame.new(sx, wallBotY + wallH * 0.5, sz), theme.TimberTrim, Enum.Material.Wood, false)
			end
		end
	end
	wPart("TopWallPlateF", Vector3.new(wallW + 1.0, 0.9, 1.1), CFrame.new(0, eaveY - 0.35, barnZ + wallD * 0.5 + 0.15), if category == "Meat" then creamTrim else theme.TimberTrim, Enum.Material.Wood, false)
	wPart("TopWallPlateB", Vector3.new(wallW + 1.0, 0.9, 1.1), CFrame.new(0, eaveY - 0.35, barnZ - wallD * 0.5 - 0.15), if category == "Meat" then creamTrim else theme.TimberTrim, Enum.Material.Wood, false)
	wPart("BaseTrimBelt", Vector3.new(wallW + 0.8, 0.75, wallD + 0.8), CFrame.new(0, wallBotY + 0.35, barnZ), theme.TimberTrim, Enum.Material.Wood, false)

	-- 4. True Pitched Shingle Gable Roof (matches all 4 icons' iconic silhouette!)
	buildPitchedShingleRoof(
		"MainRoof",
		0,
		eaveY,
		barnZ,
		wallW + 2.6,
		wallD + 3.6,
		7.8,
		theme.RoofMain,
		theme.RoofAlt,
		theme.RoofRidge,
		theme.WallMain,
		theme.WallMat,
		if category == "Meat" then creamTrim else theme.TimberTrim
	)

	-- 5. Cozy Illuminated Side Windows (on both left & right sides!)
	for _, side in ipairs({ -1, 1 }) do
		local wx = side * (wallW * 0.5 + 0.15)
		wPart("SideWinFrame", Vector3.new(0.45, 3.8, 4.6), CFrame.new(wx, wallBotY + 6.2, barnZ), theme.TimberTrim, Enum.Material.Wood, false)
		wPart("SideWinGlow", Vector3.new(0.28, 3.0, 3.8), CFrame.new(wx + side * 0.1, wallBotY + 6.2, barnZ), warmGlow, Enum.Material.Neon, false, nil, 0.12)
		wPart("SideWinMullionV", Vector3.new(0.38, 3.2, 0.25), CFrame.new(wx + side * 0.18, wallBotY + 6.2, barnZ), theme.TimberTrim, Enum.Material.Wood, false)
		wPart("SideWinMullionH", Vector3.new(0.38, 0.25, 4.0), CFrame.new(wx + side * 0.18, wallBotY + 6.2, barnZ), theme.TimberTrim, Enum.Material.Wood, false)
	end

	-- =========================================================================
	-- CATEGORY-SPECIFIC SIGNATURE ARCHITECTURE & FRONT PROPS (EXACT ICON MATCH!)
	-- =========================================================================
	local frontZ = barnZ + wallD * 0.5 -- Z = +9.6

	if category == "Fish" then
		-- FISH HARBOR BARN: Heavy Recessed Brushed-Steel Sliding Dock Door + Golden Anchor Emblem + Iced Fish Crates!
		wPart("FishDoorFrameL", Vector3.new(1.15, 8.8, 1.3), CFrame.new(-4.8, wallBotY + 4.4, frontZ + 0.25), theme.TimberTrim, Enum.Material.Wood, false)
		wPart("FishDoorFrameR", Vector3.new(1.15, 8.8, 1.3), CFrame.new(4.8, wallBotY + 4.4, frontZ + 0.25), theme.TimberTrim, Enum.Material.Wood, false)
		wPart("FishDoorHeader", Vector3.new(11.0, 1.15, 1.4), CFrame.new(0, wallBotY + 8.85, frontZ + 0.25), theme.TimberTrim, Enum.Material.Wood, false)
		wPart("FishMetalDoor", Vector3.new(8.6, 8.2, 0.5), CFrame.new(0, wallBotY + 4.1, frontZ + 0.12), steel, Enum.Material.Metal, false)
		for slat = 1, 5 do
			wPart("FishDoorSlat_" .. slat, Vector3.new(8.4, 0.22, 0.62), CFrame.new(0, wallBotY + slat * 1.45, frontZ + 0.18), Color3.fromRGB(122, 134, 150), Enum.Material.Metal, false)
		end
		wPart("FishDoorRail", Vector3.new(12.2, 0.45, 0.65), CFrame.new(0, wallBotY + 9.45, frontZ + 0.55), darkIron, Enum.Material.Metal, false)

		-- Signature Golden Anchor Emblem centered in the Front Gable Triangle (exact icon match!)
		local ancY = eaveY + 3.1
		local ancZ = frontZ + 0.45
		wPart("AnchorPlaque", Vector3.new(5.2, 5.2, 0.35), CFrame.new(0, ancY, ancZ - 0.15) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(32, 74, 134), Enum.Material.SmoothPlastic, false)
		wPart("AnchorRing", Vector3.new(0.42, 1.15, 1.15), CFrame.new(0, ancY + 1.55, ancZ + 0.12) * CFrame.Angles(0, math.rad(90), 0), gold, Enum.Material.Metal, false, Enum.PartType.Cylinder)
		wPart("AnchorShank", Vector3.new(0.55, 3.1, 0.42), CFrame.new(0, ancY - 0.15, ancZ + 0.12), gold, Enum.Material.Metal, false)
		wPart("AnchorStock", Vector3.new(2.35, 0.45, 0.42), CFrame.new(0, ancY + 0.85, ancZ + 0.12), gold, Enum.Material.Metal, false)
		wPart("AnchorArmL", Vector3.new(1.7, 0.5, 0.42), CFrame.new(-0.95, ancY - 1.25, ancZ + 0.12) * CFrame.Angles(0, 0, math.rad(-34)), gold, Enum.Material.Metal, false)
		wPart("AnchorArmR", Vector3.new(1.7, 0.5, 0.42), CFrame.new(0.95, ancY - 1.25, ancZ + 0.12) * CFrame.Angles(0, 0, math.rad(34)), gold, Enum.Material.Metal, false)

		-- Stacked Iced Wooden Fish Crates on Right Front Corner (exact icon match!)
		local fishCrates = {
			{ Pos = Vector3.new(9.2, 0.3, 12.2), Sz = 3.8, Rot = -10 },
			{ Pos = Vector3.new(12.2, 0.3, 9.2), Sz = 3.4, Rot = 12 },
			{ Pos = Vector3.new(-9.6, 0.3, 11.8), Sz = 3.5, Rot = 8 },
		}
		for idx, fc in ipairs(fishCrates) do
			local ccf = buildOpenCrate("FishCrate" .. idx, fc.Pos, fc.Sz, fc.Rot)
			-- Bed of crushed shimmering ice
			wPart("FishIce" .. idx, Vector3.new(fc.Sz - 0.55, 0.85, fc.Sz - 0.55), ccf * CFrame.new(0, fc.Sz * 0.56, 0), Color3.fromRGB(186, 238, 255), Enum.Material.Ice, false)
			-- Silvery-blue fish poking cleanly out of the ice!
			for fi = -1, 1 do
				wPart("FishProp" .. idx .. "_" .. fi, Vector3.new(0.68, 0.55, 2.05), ccf * CFrame.new(fi * 0.82, fc.Sz * 0.78, 0) * CFrame.Angles(math.rad(14), math.rad(fi * 16), 0), Color3.fromRGB(98, 172, 224), Enum.Material.SmoothPlastic, false)
				wPart("FishTail" .. idx .. "_" .. fi, Vector3.new(0.24, 0.65, 0.55), ccf * CFrame.new(fi * 0.82, fc.Sz * 0.92, -1.05) * CFrame.Angles(math.rad(18), math.rad(fi * 16), 0), Color3.fromRGB(64, 134, 194), Enum.Material.SmoothPlastic, false)
			end
		end

	elseif category == "Vegetable" then
		-- VEGETABLE FARM BARN: X-Braced Double Wooden Barn Doors + Upper Hayloft Window + Carrot & Cabbage Crates!
		wPart("VegDoorFrameL", Vector3.new(1.15, 8.8, 1.3), CFrame.new(-4.8, wallBotY + 4.4, frontZ + 0.25), theme.TimberTrim, Enum.Material.Wood, false)
		wPart("VegDoorFrameR", Vector3.new(1.15, 8.8, 1.3), CFrame.new(4.8, wallBotY + 4.4, frontZ + 0.25), theme.TimberTrim, Enum.Material.Wood, false)
		wPart("VegDoorHeader", Vector3.new(11.0, 1.15, 1.4), CFrame.new(0, wallBotY + 8.85, frontZ + 0.25), theme.TimberTrim, Enum.Material.Wood, false)
		for _, side in ipairs({ -1, 1 }) do
			local dx = side * 2.15
			wPart("VegBarnLeaf", Vector3.new(4.1, 8.2, 0.55), CFrame.new(dx, wallBotY + 4.1, frontZ + 0.14), Color3.fromRGB(154, 94, 48), Enum.Material.WoodPlanks, false)
			-- Classic X-Brace cross beams on each barn door leaf!
			wPart("VegXBraceA", Vector3.new(0.45, 7.6, 0.68), CFrame.new(dx, wallBotY + 4.1, frontZ + 0.22) * CFrame.Angles(0, 0, math.rad(24)), theme.TimberTrim, Enum.Material.Wood, false)
			wPart("VegXBraceB", Vector3.new(0.45, 7.6, 0.68), CFrame.new(dx, wallBotY + 4.1, frontZ + 0.22) * CFrame.Angles(0, 0, math.rad(-24)), theme.TimberTrim, Enum.Material.Wood, false)
			wPart("VegHingeT", Vector3.new(1.6, 0.34, 0.72), CFrame.new(side * 3.4, wallBotY + 6.8, frontZ + 0.22), darkIron, Enum.Material.Metal, false)
			wPart("VegHingeB", Vector3.new(1.6, 0.34, 0.72), CFrame.new(side * 3.4, wallBotY + 1.8, frontZ + 0.22), darkIron, Enum.Material.Metal, false)
		end

		-- Cute Upper Hayloft Shuttered Gable Window (exact icon match!)
		local loftY = eaveY + 3.0
		wPart("HayloftFrame", Vector3.new(4.8, 3.8, 0.65), CFrame.new(0, loftY, frontZ + 0.28), theme.TimberTrim, Enum.Material.Wood, false)
		wPart("HayloftGlass", Vector3.new(3.8, 2.8, 0.45), CFrame.new(0, loftY, frontZ + 0.42), warmGlow, Enum.Material.Neon, false, nil, 0.15)
		wPart("HayloftCrossV", Vector3.new(0.32, 3.0, 0.55), CFrame.new(0, loftY, frontZ + 0.5), theme.TimberTrim, Enum.Material.Wood, false)
		wPart("HayloftCrossH", Vector3.new(4.0, 0.32, 0.55), CFrame.new(0, loftY, frontZ + 0.5), theme.TimberTrim, Enum.Material.Wood, false)

		-- Front-Left Carrot Crate (bright orange carrots with leafy green tufts!)
		local ccfL = buildOpenCrate("CarrotCrate", Vector3.new(-9.4, 0.3, 12.0), 4.0, 10)
		for cx = -1.0, 1.0, 1.0 do
			for cz = -0.8, 0.8, 0.8 do
				wPart("CarrotBody", Vector3.new(0.55, 1.45, 0.55), ccfL * CFrame.new(cx, 2.75, cz) * CFrame.Angles(math.rad(16), math.rad(cx * 25), math.rad(cz * 14)), Color3.fromRGB(246, 124, 28), Enum.Material.SmoothPlastic, false)
				wPart("CarrotLeaf", Vector3.new(0.65, 0.65, 0.65), ccfL * CFrame.new(cx, 3.55, cz), Color3.fromRGB(62, 182, 68), Enum.Material.Grass, false, Enum.PartType.Ball)
			end
		end

		-- Front-Right Cabbage & Potato Crates (lush round green cabbages + golden potatoes!)
		local ccfR = buildOpenCrate("CabbageCrate", Vector3.new(9.4, 0.3, 12.0), 4.0, -10)
		for _, off in ipairs({ Vector3.new(-0.9, 2.95, -0.7), Vector3.new(0.9, 2.95, -0.6), Vector3.new(0.0, 3.15, 0.7), Vector3.new(-0.85, 2.85, 0.85), Vector3.new(0.95, 2.85, 0.8) }) do
			wPart("CabbageHead", Vector3.new(1.55, 1.45, 1.55), ccfR * CFrame.new(off), Color3.fromRGB(98, 204, 72), Enum.Material.SmoothPlastic, false, Enum.PartType.Ball)
		end
		local ccfR2 = buildOpenCrate("PotatoCrate", Vector3.new(12.6, 0.3, 8.8), 3.3, 14)
		for _, off in ipairs({ Vector3.new(-0.6, 2.35, -0.5), Vector3.new(0.6, 2.35, -0.4), Vector3.new(0, 2.5, 0.55) }) do
			wPart("PotatoProp", Vector3.new(1.1, 0.85, 1.25), ccfR2 * CFrame.new(off), Color3.fromRGB(216, 172, 98), Enum.Material.SmoothPlastic, false, Enum.PartType.Ball)
		end

	elseif category == "Fruit" then
		-- FRUIT ORCHARD BARN: Arched Wooden Orchard Doors + Sunlit Front Awning + Overflowing Wicker Fruit Baskets!
		wPart("FruitDoorFrameL", Vector3.new(1.15, 8.6, 1.3), CFrame.new(-4.8, wallBotY + 4.3, frontZ + 0.25), theme.TimberTrim, Enum.Material.Wood, false)
		wPart("FruitDoorFrameR", Vector3.new(1.15, 8.6, 1.3), CFrame.new(4.8, wallBotY + 4.3, frontZ + 0.25), theme.TimberTrim, Enum.Material.Wood, false)
		wPart("FruitDoorArch", Vector3.new(10.8, 1.2, 1.4), CFrame.new(0, wallBotY + 8.75, frontZ + 0.25), theme.TimberTrim, Enum.Material.Wood, false)
		wPart("FruitDoorLeafL", Vector3.new(4.1, 8.0, 0.52), CFrame.new(-2.15, wallBotY + 4.0, frontZ + 0.14), Color3.fromRGB(168, 102, 48), Enum.Material.WoodPlanks, false)
		wPart("FruitDoorLeafR", Vector3.new(4.1, 8.0, 0.52), CFrame.new(2.15, wallBotY + 4.0, frontZ + 0.14), Color3.fromRGB(168, 102, 48), Enum.Material.WoodPlanks, false)
		for _, side in ipairs({ -1, 1 }) do
			wPart("FruitDoorHandle", Vector3.new(0.4, 0.9, 0.45), CFrame.new(side * 0.55, wallBotY + 4.0, frontZ + 0.48), gold, Enum.Material.Metal, false)
		end

		-- Signature Front Timber Orchard Awning Overhang (exact icon match!)
		wPart("FruitFrontAwning", Vector3.new(15.2, 0.55, 5.2), CFrame.new(0, wallBotY + 9.4, frontZ + 2.5) * CFrame.Angles(math.rad(16), 0, 0), theme.RoofMain, Enum.Material.WoodPlanks, false)
		wPart("FruitAwningTrim", Vector3.new(15.6, 0.45, 0.5), CFrame.new(0, wallBotY + 8.6, frontZ + 4.9), gold, Enum.Material.Metal, false)
		for _, px in ipairs({ -6.8, 6.8 }) do
			wPart("FruitAwningPost", Vector3.new(0.85, 8.8, 0.85), CFrame.new(px, wallBotY + 4.4, frontZ + 4.5), theme.TimberTrim, Enum.Material.Wood, false)
		end

		-- Sunburst Gable Medallion
		wPart("FruitSunCrest", Vector3.new(0.45, 3.6, 3.6), CFrame.new(0, eaveY + 3.0, frontZ + 0.35) * CFrame.Angles(0, math.rad(90), 0), gold, Enum.Material.Metal, false, Enum.PartType.Cylinder)
		wPart("FruitSunCore", Vector3.new(0.52, 2.2, 2.2), CFrame.new(0, eaveY + 3.0, frontZ + 0.42) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 168, 36), Enum.Material.Neon, false, Enum.PartType.Cylinder, 0.1)

		-- 3 Woven Wicker Baskets Overflowing with Golden Mangoes & Oranges (exact icon match!)
		local basketDefs = {
			{ Pos = Vector3.new(8.2, 0.3, 12.6), Rad = 3.2 },
			{ Pos = Vector3.new(11.6, 0.3, 10.6), Rad = 2.9 },
			{ Pos = Vector3.new(-9.4, 0.3, 12.2), Rad = 3.2 },
		}
		for bi, bd in ipairs(basketDefs) do
			wPart("FruitBasket_" .. bi, Vector3.new(2.3, bd.Rad, bd.Rad), CFrame.new(bd.Pos + Vector3.new(0, 1.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(196, 144, 82), Enum.Material.WoodPlanks, true, Enum.PartType.Cylinder)
			wPart("FruitBasketRim_" .. bi, Vector3.new(0.35, bd.Rad + 0.25, bd.Rad + 0.25), CFrame.new(bd.Pos + Vector3.new(0, 2.25, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(154, 102, 52), Enum.Material.Wood, false, Enum.PartType.Cylinder)
			for fi, off in ipairs({
				Vector3.new(-0.65, 2.55, -0.55),
				Vector3.new(0.65, 2.55, -0.45),
				Vector3.new(-0.5, 2.6, 0.65),
				Vector3.new(0.6, 2.6, 0.6),
				Vector3.new(0.0, 3.05, 0.05),
			}) do
				local fCol = if (fi + bi) % 2 == 0 then Color3.fromRGB(255, 144, 24) else Color3.fromRGB(252, 198, 42)
				wPart("FruitBall_" .. bi .. "_" .. fi, Vector3.new(1.15, 1.05, 1.15), CFrame.new(bd.Pos + off), fCol, Enum.Material.SmoothPlastic, false, Enum.PartType.Ball)
			end
			wPart("FruitLeaf_" .. bi, Vector3.new(0.85, 0.35, 0.55), CFrame.new(bd.Pos + Vector3.new(0.55, 3.35, 0.2)) * CFrame.Angles(0, math.rad(30), math.rad(20)), Color3.fromRGB(64, 188, 68), Enum.Material.Grass, false)
		end

	else
		-- MEAT BRICK BUTCHER SMOKEHOUSE: Brick Walls + Heavy Iron-Banded Oak Door + Stainless Steel Chimney + Rising Smoke + Stacked Meat Crates!
		wPart("MeatDoorArchStoneL", Vector3.new(1.3, 8.8, 1.4), CFrame.new(-4.85, wallBotY + 4.4, frontZ + 0.25), creamTrim, Enum.Material.Concrete, false)
		wPart("MeatDoorArchStoneR", Vector3.new(1.3, 8.8, 1.4), CFrame.new(4.85, wallBotY + 4.4, frontZ + 0.25), creamTrim, Enum.Material.Concrete, false)
		wPart("MeatDoorHeaderStone", Vector3.new(11.2, 1.35, 1.5), CFrame.new(0, wallBotY + 8.95, frontZ + 0.25), creamTrim, Enum.Material.Concrete, false)
		wPart("MeatDoorOak", Vector3.new(8.5, 8.2, 0.55), CFrame.new(0, wallBotY + 4.1, frontZ + 0.14), Color3.fromRGB(112, 64, 38), Enum.Material.WoodPlanks, false)
		for _, by in ipairs({ 1.8, 4.2, 6.6 }) do
			wPart("MeatDoorIronBand", Vector3.new(8.6, 0.42, 0.68), CFrame.new(0, wallBotY + by, frontZ + 0.22), darkIron, Enum.Material.Metal, false)
		end

		-- Signature Tall Gleaming Stainless-Steel Smokestack Chimney on Left Roof Slope (exact icon match!)
		local chimX, chimZ = -7.6, barnZ - 1.5
		wPart("SmokestackBase", Vector3.new(4.0, 3.2, 4.0), CFrame.new(chimX, eaveY + 3.6, chimZ), Color3.fromRGB(132, 60, 48), Enum.Material.Brick, false)
		wPart("SmokestackPipe", Vector3.new(9.5, 2.7, 2.7), CFrame.new(chimX, eaveY + 9.2, chimZ) * CFrame.Angles(0, 0, math.rad(90)), steel, Enum.Material.Metal, false, Enum.PartType.Cylinder)
		wPart("SmokestackCollar", Vector3.new(0.85, 3.2, 3.2), CFrame.new(chimX, eaveY + 7.2, chimZ) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, false, Enum.PartType.Cylinder)
		local chimTop = wPart("SmokestackCap", Vector3.new(1.1, 3.45, 3.45), CFrame.new(chimX, eaveY + 14.0, chimZ) * CFrame.Angles(0, 0, math.rad(90)), steel, Enum.Material.Metal, false, Enum.PartType.Cylinder)
		if not isGhost then
			local smoke = Instance.new("ParticleEmitter")
			smoke.Name = "SmokehouseSteam"
			smoke.Color = ColorSequence.new(Color3.fromRGB(238, 240, 246), Color3.fromRGB(196, 202, 212))
			smoke.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(0.6, 0.72),
				NumberSequenceKeypoint.new(1, 1),
			})
			smoke.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.2),
				NumberSequenceKeypoint.new(1, 3.8),
			})
			smoke.Lifetime = NumberRange.new(2.2, 3.6)
			smoke.Rate = 5
			smoke.Speed = NumberRange.new(2.8, 4.5)
			smoke.SpreadAngle = Vector2.new(14, 14)
			smoke.EmissionDirection = Enum.NormalId.Top
			smoke.Parent = chimTop
		end

		-- Gable Butcher Crest Window
		wPart("MeatGableMedallion", Vector3.new(0.45, 3.6, 3.6), CFrame.new(0, eaveY + 3.0, frontZ + 0.35) * CFrame.Angles(0, math.rad(90), 0), creamTrim, Enum.Material.Concrete, false, Enum.PartType.Cylinder)
		wPart("MeatGableInner", Vector3.new(0.52, 2.5, 2.5), CFrame.new(0, eaveY + 3.0, frontZ + 0.42) * CFrame.Angles(0, math.rad(90), 0), theme.RoofMain, Enum.Material.SmoothPlastic, false, Enum.PartType.Cylinder)

		-- Stacked Heavy Wooden Butcher Crates on Right Front Corner (exact icon match!)
		buildClosedCrate("MeatCrate1", Vector3.new(9.2, 0.3, 12.2), 3.4, -8)
		buildClosedCrate("MeatCrate2", Vector3.new(12.2, 0.3, 9.4), 3.2, 10)
		buildClosedCrate("MeatCrateTop", Vector3.new(10.6, 3.7, 10.9), 2.8, 6)
	end

	-- =========================================================================
	-- COHESIVE LV.2 -> LV.10 THEME-FAITHFUL UPGRADES (ALWAYS MATCHES THE ICON STYLE!)
	-- =========================================================================
	if level >= 2 then
		-- Lv.2: Warm Brass Entry Wall Lanterns + Gilded Ridge Trim
		addLantern("EntryLanternL", Vector3.new(-6.6, wallBotY + 7.2, frontZ + 1.0), 22, 1.1)
		addLantern("EntryLanternR", Vector3.new(6.6, wallBotY + 7.2, frontZ + 1.0), 22, 1.1)
		wPart("Lv2_GoldRidge", Vector3.new(0.85, 0.55, wallD + 4.4), CFrame.new(0, eaveY + 8.7, barnZ), gold, Enum.Material.Metal, false)
	end

	if level >= 3 then
		-- Lv.3: Gilded Architectural Cornice Band + Twin Front Brass Finial Orbs
		wPart("Lv3_GoldBand", Vector3.new(wallW + 1.2, 0.65, wallD + 1.2), CFrame.new(0, wallBotY + 10.6, barnZ), gold, Enum.Material.Metal, false)
		for _, sx in ipairs({ -wallW * 0.5 - 0.1, wallW * 0.5 + 0.1 }) do
			wPart("Lv3_CornerOrb", Vector3.new(1.5, 1.5, 1.5), CFrame.new(sx, eaveY + 0.5, frontZ + 0.4), gold, Enum.Material.Metal, false, Enum.PartType.Ball)
		end
	end

	if level >= 4 then
		-- Lv.4: Matching Side Annex Wing (stays within PlotPivot X = -17.5..+17.5!)
		local annexX = -14.6
		local annexW = 5.4
		local annexH = 7.4
		local annexD = 12.6
		wPart("Lv4_AnnexBase", Vector3.new(annexW + 0.6, 1.0, annexD + 0.6), CFrame.new(annexX, 0.8, barnZ), theme.PlinthCol, theme.PlinthMat, true)
		if category == "Vegetable" then
			-- Glass greenhouse lean-to bay for Vegetable Farm Barn!
			wPart("Lv4_GreenhouseLow", Vector3.new(annexW, 2.6, annexD), CFrame.new(annexX, 2.6, barnZ), theme.WallMain, theme.WallMat, true)
			wPart("Lv4_GreenhouseGlass", Vector3.new(annexW - 0.3, 4.4, annexD - 0.4), CFrame.new(annexX, 6.0, barnZ), Color3.fromRGB(184, 240, 212), Enum.Material.Glass, false, nil, 0.35)
		else
			wPart("Lv4_AnnexBody", Vector3.new(annexW, annexH, annexD), CFrame.new(annexX, 1.3 + annexH * 0.5, barnZ), theme.WallMain, theme.WallMat, true)
		end
		wPart("Lv4_AnnexRoof", Vector3.new(annexW + 1.8, 0.75, annexD + 1.6), CFrame.new(annexX - 0.2, 1.3 + annexH + 0.6, barnZ) * CFrame.Angles(0, 0, math.rad(20)), theme.RoofMain, Enum.Material.WoodPlanks, false)
	end

	if level >= 5 then
		-- Lv.5: Glowing Category Eave Accent Trim + Overhead Timber Cargo Hoist Beam
		wPart("Lv5_HoistBeam", Vector3.new(1.1, 1.1, 4.4), CFrame.new(0, eaveY + 6.4, frontZ + 2.2), theme.TimberTrim, Enum.Material.Wood, false)
		wPart("Lv5_HoistPulley", Vector3.new(0.45, 1.4, 1.4), CFrame.new(0, eaveY + 5.3, frontZ + 3.7), gold, Enum.Material.Metal, false, Enum.PartType.Cylinder)
		wPart("Lv5_AccentGlowF", Vector3.new(wallW + 1.6, 0.35, 0.45), CFrame.new(0, eaveY - 0.05, frontZ + 0.8), theme.BeaconCol, Enum.Material.Neon, false)
	end

	if level >= 6 then
		-- Lv.6-7: Matching 2nd-Tier Shingled Roof Cupola Tower (same theme roof & warm glowing windows!)
		local cupY = eaveY + 6.8
		local cupW = 10.4
		local cupH = 4.6
		local cupD = 10.4
		wPart("Lv6_CupolaBase", Vector3.new(cupW, cupH, cupD), CFrame.new(0, cupY + cupH * 0.5, barnZ), theme.WallMain, theme.WallMat, false)
		wPart("Lv6_CupolaWinF", Vector3.new(5.6, 2.4, 0.4), CFrame.new(0, cupY + cupH * 0.52, barnZ + cupD * 0.5 + 0.08), warmGlow, Enum.Material.Neon, false, nil, 0.1)
		wPart("Lv6_CupolaWinL", Vector3.new(0.4, 2.4, 5.6), CFrame.new(-cupW * 0.5 - 0.08, cupY + cupH * 0.52, barnZ), warmGlow, Enum.Material.Neon, false, nil, 0.1)
		wPart("Lv6_CupolaWinR", Vector3.new(0.4, 2.4, 5.6), CFrame.new(cupW * 0.5 + 0.08, cupY + cupH * 0.52, barnZ), warmGlow, Enum.Material.Neon, false, nil, 0.1)
		buildPitchedShingleRoof(
			"CupolaRoof",
			0,
			cupY + cupH,
			barnZ,
			cupW + 2.0,
			cupD + 2.4,
			3.8,
			theme.RoofMain,
			theme.RoofAlt,
			gold,
			theme.WallMain,
			theme.WallMat,
			gold
		)
	end

	if level >= 7 then
		-- Lv.7: Matching Right-Side Covered Supply Pavilion Wing (symmetrical grand barn silhouette!)
		local wingX = 14.6
		local wingW = 5.4
		local wingH = 7.4
		local wingD = 12.6
		wPart("Lv7_RightWingBase", Vector3.new(wingW + 0.6, 1.0, wingD + 0.6), CFrame.new(wingX, 0.8, barnZ), theme.PlinthCol, theme.PlinthMat, true)
		wPart("Lv7_RightWingBody", Vector3.new(wingW, wingH, wingD), CFrame.new(wingX, 1.3 + wingH * 0.5, barnZ), theme.WallMain, theme.WallMat, true)
		wPart("Lv7_RightWingRoof", Vector3.new(wingW + 1.8, 0.75, wingD + 1.6), CFrame.new(wingX + 0.2, 1.3 + wingH + 0.6, barnZ) * CFrame.Angles(0, 0, math.rad(-20)), theme.RoofMain, Enum.Material.WoodPlanks, false)
	end

	if level >= 8 then
		-- Lv.8: Gilded Corner Timber-and-Brass Grand Columns & Illuminated Eave Lanterns
		for _, sx in ipairs({ -wallW * 0.5 - 0.35, wallW * 0.5 + 0.35 }) do
			for _, sz in ipairs({ barnZ - wallD * 0.5 - 0.35, barnZ + wallD * 0.5 + 0.35 }) do
				wPart("Lv8_GoldCol", Vector3.new(1.55, wallH + 0.8, 1.55), CFrame.new(sx, wallBotY + wallH * 0.5, sz), gold, Enum.Material.Metal, false)
			end
		end
	end

	if level >= 9 then
		-- Lv.9: Illuminated Golden Supply Crown Ring around the Cupola
		wPart("Lv9_CupolaGoldBelt", Vector3.new(11.4, 0.7, 11.4), CFrame.new(0, eaveY + 11.4, barnZ), gold, Enum.Material.Metal, false)
		local glowHalo = wPart("Lv9_CupolaBeaconOrb", Vector3.new(2.8, 2.8, 2.8), CFrame.new(0, eaveY + 16.6, barnZ), neonGold, Enum.Material.Neon, false, Enum.PartType.Ball)
		if not isGhost then
			local pl9 = Instance.new("PointLight")
			pl9.Color = neonGold
			pl9.Range = 30
			pl9.Brightness = 1.5
			pl9.Shadows = false
			pl9.Parent = glowHalo
		end
	end

	if level >= 10 then
		-- Lv.10 (MAX ROYAL DEPOT): Crowned Golden Dome Finial & Radiant Category Spire!
		local topY = eaveY + 15.8
		wPart("Lv10_DomeBase", Vector3.new(1.8, 6.2, 6.2), CFrame.new(0, topY, barnZ) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, false, Enum.PartType.Cylinder)
		wPart("Lv10_RoyalDome", Vector3.new(5.6, 5.2, 5.6), CFrame.new(0, topY + 1.8, barnZ), theme.RoofMain, Enum.Material.Metal, false, Enum.PartType.Ball)
		wPart("Lv10_GoldSpire", Vector3.new(5.4, 1.1, 1.1), CFrame.new(0, topY + 6.4, barnZ) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, false, Enum.PartType.Cylinder)
		local crownOrb = wPart("Lv10_CrownStar", Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, topY + 9.4, barnZ), theme.BeaconCol, Enum.Material.Neon, false, Enum.PartType.Ball)
		if not isGhost then
			local pl10 = Instance.new("PointLight")
			pl10.Color = theme.BeaconCol
			pl10.Range = 44
			pl10.Brightness = 2.0
			pl10.Shadows = false
			pl10.Parent = crownOrb
		end
	end

	folder.Parent = plot
end

return WarehouseVisualBuilder
