--!strict

-- Studio-lit 3D ViewportFrame thumbnail generator for Weapons, Tools, Ammo, Bodyguards,
-- Equipment, Dishes, Warehouses, Empire Operations & Robux Store items.
-- Replaces plain 3-letter badges and fallback boxes with crisp, unmistakable 3D icons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local BodyguardConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("BodyguardConfig")
)

local ModelPreviewHelper = {}

local P = MafiaVisualBuilder.PALETTE

local function addPart(model: Model, name: string, size: Vector3, cf: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = col
	p.Material = mat
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function addWedge(model: Model, name: string, size: Vector3, cf: CFrame, col: Color3, mat: Enum.Material): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Color = col
	w.Material = mat
	w.Anchored = true
	w.CanCollide = false
	w.CanTouch = false
	w.CanQuery = false
	w.CastShadow = false
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = model
	return w
end

local function freezeModelForPreview(model: Model): Model
	local isCustomTpl = model:GetAttribute("IsCustomNPCTemplate") == true
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
			desc.CastShadow = false
		elseif desc:IsA("BillboardGui") then
			desc:Destroy()
		elseif (not isCustomTpl) and (desc:IsA("JointInstance") or desc:IsA("WeldConstraint") or desc:IsA("Humanoid")) then
			desc:Destroy()
		end
	end
	return model
end

local function buildWeaponModel(weaponId: string): Model
	local m = Instance.new("Model")
	m.Name = "Preview_" .. weaponId
	local matteBlack = Color3.fromRGB(28, 32, 38)
	local darkSteel = Color3.fromRGB(58, 64, 76)
	local brushedSteel = Color3.fromRGB(162, 170, 184)
	local chrome = Color3.fromRGB(218, 224, 234)
	local gripCol = Color3.fromRGB(34, 38, 46)
	local walnut = Color3.fromRGB(122, 74, 42)
	local brass = Color3.fromRGB(224, 182, 68)
	local oxblood = Color3.fromRGB(184, 34, 48)
	local olive = Color3.fromRGB(76, 88, 70)
	local boreDark = Color3.fromRGB(12, 14, 18)

	local function addPicatinnyRail(y: number, zStart: number, zEnd: number, col: Color3)
		addPart(m, "RailBase", Vector3.new(0.24, 0.06, math.abs(zEnd - zStart)), CFrame.new(0, y, (zStart + zEnd) * 0.5), col, Enum.Material.Metal, nil)
		local steps = math.max(2, math.floor(math.abs(zEnd - zStart) / 0.24))
		for i = 0, steps do
			local z = zStart + (zEnd - zStart) * (i / steps)
			addPart(m, "RailNotch_" .. i, Vector3.new(0.26, 0.07, 0.10), CFrame.new(0, y + 0.04, z), col, Enum.Material.Metal, nil)
		end
	end

	local function addErgonomicGrip(gripColor: Color3, zOff: number?)
		local z = zOff or 0.0
		-- Angled tactical pistol grip + palm swell + floorplate + closed trigger guard + curved trigger
		addPart(m, "PistolGrip", Vector3.new(0.27, 0.94, 0.42), CFrame.new(0, -0.02, z + 0.08) * CFrame.Angles(math.rad(-15), 0, 0), gripColor, Enum.Material.SmoothPlastic, nil)
		addPart(m, "GripPlate", Vector3.new(0.30, 0.10, 0.46), CFrame.new(0, -0.48, z + 0.20) * CFrame.Angles(math.rad(-15), 0, 0), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "TriggerGuardBot", Vector3.new(0.14, 0.07, 0.48), CFrame.new(0, 0.10, z - 0.34), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "TriggerGuardFront", Vector3.new(0.14, 0.34, 0.07), CFrame.new(0, 0.26, z - 0.56), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "Trigger", Vector3.new(0.06, 0.24, 0.09), CFrame.new(0, 0.26, z - 0.30) * CFrame.Angles(math.rad(22), 0, 0), brushedSteel, Enum.Material.Metal, nil)
	end

	if weaponId == "GoldenSpatula" then
		addPart(m, "Handle", Vector3.new(0.28, 2.25, 0.28), CFrame.new(0, -0.6, 0), walnut, Enum.Material.Wood, nil)
		addPart(m, "Pommel", Vector3.new(0.32, 0.18, 0.32), CFrame.new(0, -1.72, 0), brass, Enum.Material.Metal, nil)
		addPart(m, "Neck", Vector3.new(0.18, 0.72, 0.14), CFrame.new(0, 0.85, 0), brass, Enum.Material.Metal, nil)
		addPart(m, "Blade", Vector3.new(1.18, 1.38, 0.10), CFrame.new(0, 1.74, 0), brass, Enum.Material.Metal, nil)
		for sx = -0.32, 0.32, 0.32 do
			addPart(m, "Slot_" .. tostring(sx), Vector3.new(0.12, 0.82, 0.14), CFrame.new(sx, 1.74, 0), boreDark, Enum.Material.Metal, nil)
		end
		return m
	elseif weaponId == "MafiaKnife" then
		addPart(m, "Grip", Vector3.new(0.24, 0.26, 1.15), CFrame.new(0, 0, 0.56), gripCol, Enum.Material.Leather, nil)
		addPart(m, "Pommel", Vector3.new(0.28, 0.28, 0.18), CFrame.new(0, 0, 1.18), brass, Enum.Material.Metal, nil)
		addPart(m, "Guard", Vector3.new(0.46, 0.36, 0.14), CFrame.new(0, 0, -0.04), brass, Enum.Material.Metal, nil)
		addPart(m, "StilettoBlade", Vector3.new(0.08, 0.24, 1.65), CFrame.new(0, 0, -0.94), chrome, Enum.Material.Metal, nil)
		addPart(m, "Fuller", Vector3.new(0.10, 0.06, 1.25), CFrame.new(0, 0.04, -0.86), darkSteel, Enum.Material.Metal, nil)
		addWedge(m, "BladeTip", Vector3.new(0.08, 0.24, 0.52), CFrame.new(0, 0, -2.02) * CFrame.Angles(0, math.rad(180), 0), chrome, Enum.Material.Metal)
		return m
	elseif weaponId == "SamuraiKatana" then
		addPart(m, "Tsuka", Vector3.new(0.22, 0.28, 1.48), CFrame.new(0, 0, 1.15), matteBlack, Enum.Material.Fabric, nil)
		for i = 0, 5 do
			addPart(m, "DiamondWrap_" .. i, Vector3.new(0.24, 0.20, 0.14), CFrame.new(0, 0, 0.56 + i * 0.22) * CFrame.Angles(math.rad(45), 0, 0), oxblood, Enum.Material.Fabric, nil)
		end
		addPart(m, "Kashira", Vector3.new(0.24, 0.30, 0.14), CFrame.new(0, 0, 1.92), brass, Enum.Material.Metal, nil)
		addPart(m, "Tsuba", Vector3.new(0.12, 0.62, 0.62), CFrame.new(0, 0, 0.38) * CFrame.Angles(0, math.rad(90), 0), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Habaki", Vector3.new(0.14, 0.28, 0.24), CFrame.new(0, 0.01, 0.20), brass, Enum.Material.Metal, nil)
		addPart(m, "BladeBase", Vector3.new(0.08, 0.25, 2.45), CFrame.new(0, 0.02, -1.14), chrome, Enum.Material.Metal, nil)
		addPart(m, "BladeCurve", Vector3.new(0.07, 0.23, 1.55), CFrame.new(0, 0.10, -3.12) * CFrame.Angles(math.rad(6), 0, 0), chrome, Enum.Material.Metal, nil)
		addWedge(m, "KissakiTip", Vector3.new(0.07, 0.23, 0.50), CFrame.new(0, 0.18, -4.12) * CFrame.Angles(math.rad(6), math.rad(180), 0), brushedSteel, Enum.Material.Metal)
		return m
	end

	addErgonomicGrip(if weaponId == "GoldenEmperorPistol" then P.OffWhite else gripCol, 0)

	if weaponId == "PepperShotgun" then
		-- Classic Trench Pump Shotgun (walnut stock + recoil pad + side ejection + barrel clamp + ribbed pump + bead sight)
		addPart(m, "Stock", Vector3.new(0.32, 0.60, 1.38), CFrame.new(0, 0.24, 0.86) * CFrame.Angles(math.rad(-10), 0, 0), walnut, Enum.Material.Wood, nil)
		addPart(m, "RecoilPad", Vector3.new(0.34, 0.64, 0.14), CFrame.new(0, 0.12, 1.56) * CFrame.Angles(math.rad(-10), 0, 0), matteBlack, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Receiver", Vector3.new(0.38, 0.50, 1.34), CFrame.new(0, 0.54, -0.40), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "EjectionPort", Vector3.new(0.40, 0.18, 0.44), CFrame.new(0, 0.60, -0.46), brushedSteel, Enum.Material.Metal, nil)
		addPart(m, "Barrel", Vector3.new(2.58, 0.23, 0.23), CFrame.new(0, 0.65, -2.32) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "MuzzleBore", Vector3.new(0.08, 0.15, 0.15), CFrame.new(0, 0.65, -3.60) * CFrame.Angles(0, math.rad(90), 0), boreDark, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "MagTube", Vector3.new(2.12, 0.22, 0.22), CFrame.new(0, 0.40, -2.08) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "BarrelClamp", Vector3.new(0.28, 0.48, 0.18), CFrame.new(0, 0.52, -3.02), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "Pump", Vector3.new(0.42, 0.36, 0.96), CFrame.new(0, 0.40, -1.84), walnut, Enum.Material.Wood, nil)
		for r = -2, 2 do
			addPart(m, "PumpRib_" .. r, Vector3.new(0.45, 0.34, 0.06), CFrame.new(0, 0.40, -1.84 + r * 0.16), Color3.fromRGB(86, 48, 26), Enum.Material.Wood, nil)
		end
		addPart(m, "BeadSight", Vector3.new(0.10, 0.12, 0.10), CFrame.new(0, 0.80, -3.50), brass, Enum.Material.Metal, Enum.PartType.Ball)
	elseif weaponId == "AutoCombatShotgun" then
		-- Tactical Combat Auto-Shotgun (adjustable stock + top rail + red-dot optic + vented heatshield + choke)
		addPart(m, "Stock", Vector3.new(0.34, 0.66, 1.28), CFrame.new(0, 0.36, 0.86), matteBlack, Enum.Material.SmoothPlastic, nil)
		addPart(m, "CheekRest", Vector3.new(0.36, 0.18, 0.72), CFrame.new(0, 0.68, 0.92), darkSteel, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Receiver", Vector3.new(0.42, 0.54, 1.44), CFrame.new(0, 0.56, -0.44), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "EjectionPort", Vector3.new(0.44, 0.18, 0.46), CFrame.new(0, 0.60, -0.48), chrome, Enum.Material.Metal, nil)
		addPicatinnyRail(0.85, 0.18, -1.10, matteBlack)
		addPart(m, "OpticHood", Vector3.new(0.30, 0.32, 0.44), CFrame.new(0, 1.04, -0.32), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "OpticLens", Vector3.new(0.22, 0.22, 0.46), CFrame.new(0, 1.04, -0.32), Color3.fromRGB(48, 128, 198), Enum.Material.Glass, nil)
		addPart(m, "HeatShield", Vector3.new(0.36, 0.28, 2.02), CFrame.new(0, 0.66, -2.14), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "BarrelChoke", Vector3.new(0.36, 0.27, 0.27), CFrame.new(0, 0.65, -3.28) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Tube", Vector3.new(2.26, 0.26, 0.26), CFrame.new(0, 0.38, -2.12) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Pump", Vector3.new(0.46, 0.38, 1.08), CFrame.new(0, 0.38, -1.82), matteBlack, Enum.Material.SmoothPlastic, nil)
		addPart(m, "ShellHolder", Vector3.new(0.46, 0.24, 0.64), CFrame.new(0, 0.56, -0.44), oxblood, Enum.Material.SmoothPlastic, nil)
	elseif weaponId == "TacticalSMG" then
		-- MP5/MPX-Style Suppressed Tactical SMG (curved banana mag + rail + holo optic + vented shroud + ribbed suppressor + folding stock)
		addPart(m, "UpperRec", Vector3.new(0.34, 0.30, 1.44), CFrame.new(0, 0.68, -0.46), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "LowerRec", Vector3.new(0.32, 0.24, 1.24), CFrame.new(0, 0.44, -0.38), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "BoltPort", Vector3.new(0.36, 0.14, 0.38), CFrame.new(0, 0.68, -0.52), chrome, Enum.Material.Metal, nil)
		addPicatinnyRail(0.85, 0.16, -1.82, darkSteel)
		-- Two-segment curved banana magazine
		addPart(m, "MagTop", Vector3.new(0.22, 0.64, 0.34), CFrame.new(0, 0.04, -0.78) * CFrame.Angles(math.rad(-10), 0, 0), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "MagCurve", Vector3.new(0.22, 0.62, 0.34), CFrame.new(0, -0.48, -0.94) * CFrame.Angles(math.rad(-24), 0, 0), darkSteel, Enum.Material.Metal, nil)
		-- Holographic Optic
		addPart(m, "HoloHood", Vector3.new(0.30, 0.34, 0.48), CFrame.new(0, 1.06, -0.38), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "HoloGlass", Vector3.new(0.22, 0.24, 0.50), CFrame.new(0, 1.06, -0.38), Color3.fromRGB(56, 174, 224), Enum.Material.Glass, nil)
		addPart(m, "Handguard", Vector3.new(0.36, 0.38, 0.88), CFrame.new(0, 0.56, -1.56), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "AngledGrip", Vector3.new(0.22, 0.24, 0.52), CFrame.new(0, 0.28, -1.62) * CFrame.Angles(math.rad(28), 0, 0), gripCol, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Suppressor", Vector3.new(1.18, 0.28, 0.28), CFrame.new(0, 0.58, -2.56) * CFrame.Angles(0, math.rad(90), 0), matteBlack, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "SuppCollar", Vector3.new(0.18, 0.32, 0.32), CFrame.new(0, 0.58, -2.02) * CFrame.Angles(0, math.rad(90), 0), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "MuzzleBore", Vector3.new(0.06, 0.16, 0.16), CFrame.new(0, 0.58, -3.14) * CFrame.Angles(0, math.rad(90), 0), boreDark, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "StockButt", Vector3.new(0.28, 0.68, 0.18), CFrame.new(0, 0.42, 1.24), matteBlack, Enum.Material.SmoothPlastic, nil)
		addPart(m, "StrutTop", Vector3.new(0.14, 0.12, 1.04), CFrame.new(0, 0.64, 0.72), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "StrutBot", Vector3.new(0.14, 0.10, 1.04), CFrame.new(0, 0.34, 0.72) * CFrame.Angles(math.rad(-14), 0, 0), darkSteel, Enum.Material.Metal, nil)
	elseif weaponId == "SilencedDeagle" then
		-- Heavy Chrome Desert Eagle + Ribbed Suppressor + Iron Sights + Ejection Port + Hammer
		addPart(m, "LowerFrame", Vector3.new(0.30, 0.24, 1.66), CFrame.new(0, 0.42, -0.56), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "UnderRail", Vector3.new(0.24, 0.08, 0.78), CFrame.new(0, 0.28, -0.96), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Slide", Vector3.new(0.34, 0.34, 1.78), CFrame.new(0, 0.68, -0.58), chrome, Enum.Material.Metal, nil)
		addPart(m, "SlidePort", Vector3.new(0.36, 0.16, 0.44), CFrame.new(0, 0.72, -0.46), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Hammer", Vector3.new(0.12, 0.20, 0.18), CFrame.new(0, 0.72, 0.34) * CFrame.Angles(math.rad(-28), 0, 0), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "RearSight", Vector3.new(0.26, 0.12, 0.12), CFrame.new(0, 0.89, 0.18), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "FrontSight", Vector3.new(0.10, 0.14, 0.16), CFrame.new(0, 0.89, -1.34), oxblood, Enum.Material.Metal, nil)
		addPart(m, "Suppressor", Vector3.new(1.10, 0.26, 0.26), CFrame.new(0, 0.66, -2.02) * CFrame.Angles(0, math.rad(90), 0), matteBlack, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "SuppRing", Vector3.new(0.14, 0.29, 0.29), CFrame.new(0, 0.66, -1.52) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "MuzzleBore", Vector3.new(0.06, 0.14, 0.14), CFrame.new(0, 0.66, -2.56) * CFrame.Angles(0, math.rad(90), 0), boreDark, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif weaponId == "SyndicateCarbine" or weaponId == "CrimsonDragonAR" then
		-- Realistic M4/HK416 Tactical Assault Rifle (crane stock, beveled receiver, curved mag, picatinny rail, ACOG/red-dot, vented handguard, gas block, ported muzzle brake!)
		local isCrimson = (weaponId == "CrimsonDragonAR")
		local accent = if isCrimson then oxblood else olive
		local trimCol = if isCrimson then brass else brushedSteel
		addPart(m, "BufferTube", Vector3.new(1.02, 0.24, 0.24), CFrame.new(0, 0.58, 0.72) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "CraneStock", Vector3.new(0.34, 0.74, 0.74), CFrame.new(0, 0.44, 1.26), accent, Enum.Material.SmoothPlastic, nil)
		addPart(m, "RecoilPad", Vector3.new(0.36, 0.78, 0.12), CFrame.new(0, 0.44, 1.66), matteBlack, Enum.Material.SmoothPlastic, nil)
		addPart(m, "UpperRec", Vector3.new(0.36, 0.30, 1.54), CFrame.new(0, 0.68, -0.48), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "LowerRec", Vector3.new(0.34, 0.26, 1.38), CFrame.new(0, 0.44, -0.44), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "EjectionPort", Vector3.new(0.38, 0.14, 0.46), CFrame.new(0, 0.68, -0.58), chrome, Enum.Material.Metal, nil)
		addPart(m, "Stripe", Vector3.new(0.39, 0.10, 1.38), CFrame.new(0, 0.60, -0.48), accent, Enum.Material.Metal, nil)
		-- Two-piece curved 30-rd STANAG tactical magazine
		addPart(m, "MagUpper", Vector3.new(0.24, 0.64, 0.42), CFrame.new(0, 0.04, -0.84) * CFrame.Angles(math.rad(-8), 0, 0), if isCrimson then oxblood else gripCol, Enum.Material.Metal, nil)
		addPart(m, "MagLower", Vector3.new(0.24, 0.66, 0.42), CFrame.new(0, -0.48, -1.00) * CFrame.Angles(math.rad(-22), 0, 0), if isCrimson then oxblood else darkSteel, Enum.Material.Metal, nil)
		addPart(m, "MagBase", Vector3.new(0.28, 0.10, 0.46), CFrame.new(0, -0.78, -1.14) * CFrame.Angles(math.rad(-22), 0, 0), trimCol, Enum.Material.Metal, nil)
		-- Vented M-LOK Handguard + Foregrip + Top Picatinny Rail
		addPart(m, "Handguard", Vector3.new(0.38, 0.42, 1.52), CFrame.new(0, 0.58, -1.96), if isCrimson then matteBlack else accent, Enum.Material.Metal, nil)
		for v = 0, 3 do
			addPart(m, "Vent_" .. v, Vector3.new(0.41, 0.10, 0.22), CFrame.new(0, 0.58, -1.42 - v * 0.34), trimCol, Enum.Material.Metal, nil)
		end
		addPart(m, "VertForegrip", Vector3.new(0.22, 0.52, 0.24), CFrame.new(0, 0.14, -2.04) * CFrame.Angles(math.rad(10), 0, 0), matteBlack, Enum.Material.SmoothPlastic, nil)
		addPicatinnyRail(0.84, 0.20, -2.68, if isCrimson then brass else matteBlack)
		-- Tactical ACOG Optic with Elevated Mount & Tinted Objective Lens
		addPart(m, "OpticMount", Vector3.new(0.22, 0.18, 0.52), CFrame.new(0, 0.94, -0.46), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "OpticTube", Vector3.new(0.84, 0.32, 0.32), CFrame.new(0, 1.12, -0.48) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "OpticRing", Vector3.new(0.18, 0.36, 0.36), CFrame.new(0, 1.12, -0.88) * CFrame.Angles(0, math.rad(90), 0), trimCol, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "OpticLens", Vector3.new(0.08, 0.26, 0.26), CFrame.new(0, 1.12, -0.96) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(56, 152, 232), Enum.Material.Glass, Enum.PartType.Cylinder)
		-- Gas Block + Front Sight + Fluted Barrel + Multi-Port Muzzle Brake
		addPart(m, "FrontSight", Vector3.new(0.12, 0.26, 0.16), CFrame.new(0, 0.92, -2.66), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "Barrel", Vector3.new(1.12, 0.20, 0.20), CFrame.new(0, 0.59, -3.22) * CFrame.Angles(0, math.rad(90), 0), trimCol, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "MuzzleBrake", Vector3.new(0.30, 0.28, 0.44), CFrame.new(0, 0.59, -3.86), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "MuzzleBore", Vector3.new(0.08, 0.15, 0.15), CFrame.new(0, 0.59, -4.08) * CFrame.Angles(0, math.rad(90), 0), boreDark, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif weaponId == "ShadowSniper" or weaponId == "PhantomAssassinRifle" then
		-- Long-Range Precision Sniper / Suppressed Assassin Rifle (precision cheek stock, bolt knob, box mag, bipod, twin scope rings, high-power scope, brake/suppressor)
		local isPhantom = (weaponId == "PhantomAssassinRifle")
		addPart(m, "Stock", Vector3.new(0.34, 0.72, 1.48), CFrame.new(0, 0.40, 0.96), matteBlack, Enum.Material.SmoothPlastic, nil)
		addPart(m, "CheekRiser", Vector3.new(0.36, 0.24, 0.68), CFrame.new(0, 0.78, 0.98), darkSteel, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Chassis", Vector3.new(0.38, 0.50, 2.38), CFrame.new(0, 0.56, -0.88), if isPhantom then Color3.fromRGB(24, 28, 36) else darkSteel, Enum.Material.Metal, nil)
		if isPhantom then
			addPart(m, "AccentStripe", Vector3.new(0.41, 0.10, 1.78), CFrame.new(0, 0.64, -0.84), oxblood, Enum.Material.Metal, nil)
		end
		addPart(m, "BoltHandle", Vector3.new(0.46, 0.10, 0.10), CFrame.new(0.24, 0.64, -0.26), chrome, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "BoxMag", Vector3.new(0.26, 0.68, 0.50), CFrame.new(0, 0.02, -0.80), brushedSteel, Enum.Material.Metal, nil)
		addPicatinnyRail(0.84, 0.16, -1.96, matteBlack)
		addPart(m, "ScopeRing1", Vector3.new(0.30, 0.30, 0.14), CFrame.new(0, 0.98, -0.28), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "ScopeRing2", Vector3.new(0.30, 0.30, 0.14), CFrame.new(0, 0.98, -1.04), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "ScopeTube", Vector3.new(1.76, 0.28, 0.28), CFrame.new(0, 1.12, -0.68) * CFrame.Angles(0, math.rad(90), 0), matteBlack, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "ScopeBell", Vector3.new(0.42, 0.38, 0.38), CFrame.new(0, 1.12, -1.62) * CFrame.Angles(0, math.rad(90), 0), if isPhantom then oxblood else brass, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "ScopeLens", Vector3.new(0.08, 0.30, 0.30), CFrame.new(0, 1.12, -1.82) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(56, 178, 242), Enum.Material.Glass, Enum.PartType.Cylinder)
		-- Folded Tactical Bipod under forend
		addPart(m, "BipodL", Vector3.new(0.10, 0.10, 0.92), CFrame.new(-0.22, 0.24, -2.06) * CFrame.Angles(math.rad(-12), 0, 0), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "BipodR", Vector3.new(0.10, 0.10, 0.92), CFrame.new(0.22, 0.24, -2.06) * CFrame.Angles(math.rad(-12), 0, 0), darkSteel, Enum.Material.Metal, nil)
		if isPhantom then
			addPart(m, "SuppressedBarrel", Vector3.new(2.58, 0.30, 0.30), CFrame.new(0, 0.60, -3.28) * CFrame.Angles(0, math.rad(90), 0), matteBlack, Enum.Material.Metal, Enum.PartType.Cylinder)
			addPart(m, "MuzzleBore", Vector3.new(0.06, 0.16, 0.16), CFrame.new(0, 0.60, -4.56) * CFrame.Angles(0, math.rad(90), 0), boreDark, Enum.Material.Metal, Enum.PartType.Cylinder)
		else
			addPart(m, "LongBarrel", Vector3.new(2.26, 0.22, 0.22), CFrame.new(0, 0.60, -3.14) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
			addPart(m, "Brake", Vector3.new(0.34, 0.30, 0.44), CFrame.new(0, 0.60, -4.38), matteBlack, Enum.Material.Metal, nil)
			addPart(m, "MuzzleBore", Vector3.new(0.06, 0.16, 0.16), CFrame.new(0, 0.60, -4.60) * CFrame.Angles(0, math.rad(90), 0), boreDark, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	elseif weaponId == "GoldenEmperorPistol" then
		-- 24K Engraved Mafia Custom Pistol (pearl grip, black steel lower, gleaming gold slide + vented compensator + gold hammer + iron sights!)
		addPart(m, "Lower", Vector3.new(0.30, 0.24, 1.54), CFrame.new(0, 0.42, -0.52), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "Slide", Vector3.new(0.34, 0.34, 1.66), CFrame.new(0, 0.68, -0.54), brass, Enum.Material.Metal, nil)
		addPart(m, "EjectPort", Vector3.new(0.36, 0.14, 0.42), CFrame.new(0, 0.72, -0.44), chrome, Enum.Material.Metal, nil)
		addPart(m, "Compensator", Vector3.new(0.34, 0.32, 0.44), CFrame.new(0, 0.68, -1.58), brass, Enum.Material.Metal, nil)
		addPart(m, "CompPort", Vector3.new(0.36, 0.12, 0.18), CFrame.new(0, 0.74, -1.58), boreDark, Enum.Material.Metal, nil)
		addPart(m, "Hammer", Vector3.new(0.12, 0.20, 0.16), CFrame.new(0, 0.72, 0.32) * CFrame.Angles(math.rad(-26), 0, 0), brass, Enum.Material.Metal, nil)
		addPart(m, "RearSight", Vector3.new(0.24, 0.12, 0.12), CFrame.new(0, 0.89, 0.18), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "FrontSight", Vector3.new(0.10, 0.14, 0.14), CFrame.new(0, 0.89, -1.66), oxblood, Enum.Material.Metal, nil)
		addPart(m, "MuzzleBore", Vector3.new(0.06, 0.16, 0.16), CFrame.new(0, 0.68, -1.80) * CFrame.Angles(0, math.rad(90), 0), boreDark, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif weaponId == "SyndicateTommyDrum" then
		-- Iconic 1928 Mafia Thompson Submachine Gun (walnut stock + cooling fins + circular 100-rd drum mag + brass hub + vertical walnut foregrip + Cutts compensator!)
		addPart(m, "WoodStock", Vector3.new(0.32, 0.66, 1.46), CFrame.new(0, 0.32, 0.88) * CFrame.Angles(math.rad(-9), 0, 0), walnut, Enum.Material.Wood, nil)
		addPart(m, "ButtPlate", Vector3.new(0.34, 0.68, 0.10), CFrame.new(0, 0.20, 1.62) * CFrame.Angles(math.rad(-9), 0, 0), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Receiver", Vector3.new(0.38, 0.48, 1.60), CFrame.new(0, 0.58, -0.50), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "TopKnob", Vector3.new(0.16, 0.18, 0.16), CFrame.new(0, 0.90, -0.34), chrome, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "DrumMag", Vector3.new(0.44, 1.12, 1.12), CFrame.new(0, -0.02, -0.86), matteBlack, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "DrumRing", Vector3.new(0.48, 0.78, 0.78), CFrame.new(0, -0.02, -0.86), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "DrumBrass", Vector3.new(0.52, 0.36, 0.36), CFrame.new(0, -0.02, -0.86), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Foregrip", Vector3.new(0.26, 0.72, 0.30), CFrame.new(0, 0.12, -1.76) * CFrame.Angles(math.rad(12), 0, 0), walnut, Enum.Material.Wood, nil)
		addPart(m, "FinBarrel", Vector3.new(1.78, 0.22, 0.22), CFrame.new(0, 0.60, -2.14) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		for f = 0, 5 do
			addPart(m, "CoolFin_" .. f, Vector3.new(0.06, 0.32, 0.32), CFrame.new(0, 0.60, -1.42 - f * 0.14) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		addPart(m, "CuttsComp", Vector3.new(0.24, 0.28, 0.36), CFrame.new(0, 0.60, -3.14), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "FrontBlade", Vector3.new(0.08, 0.18, 0.14), CFrame.new(0, 0.80, -3.16), brass, Enum.Material.Metal, nil)
	else
		-- Realistic Street 9mm Semi-Auto Pistol (textured grip, polymer lower + picatinny rail, brushed steel slide + serrations + ejection port + tritium sights + bore!)
		addPart(m, "Lower", Vector3.new(0.28, 0.22, 1.44), CFrame.new(0, 0.42, -0.48), matteBlack, Enum.Material.SmoothPlastic, nil)
		addPart(m, "UnderRail", Vector3.new(0.22, 0.08, 0.52), CFrame.new(0, 0.29, -0.88), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Slide", Vector3.new(0.32, 0.32, 1.54), CFrame.new(0, 0.66, -0.50), brushedSteel, Enum.Material.Metal, nil)
		addPart(m, "EjectPort", Vector3.new(0.34, 0.14, 0.38), CFrame.new(0, 0.70, -0.42), darkSteel, Enum.Material.Metal, nil)
		for s = 0, 2 do
			addPart(m, "Serr_" .. s, Vector3.new(0.34, 0.22, 0.05), CFrame.new(0, 0.66, 0.06 - s * 0.10), darkSteel, Enum.Material.Metal, nil)
		end
		addPart(m, "RearSight", Vector3.new(0.24, 0.12, 0.10), CFrame.new(0, 0.86, 0.16), matteBlack, Enum.Material.Metal, nil)
		addPart(m, "FrontSight", Vector3.new(0.10, 0.12, 0.12), CFrame.new(0, 0.86, -1.16), oxblood, Enum.Material.Metal, nil)
		addPart(m, "Barrel", Vector3.new(0.28, 0.18, 0.18), CFrame.new(0, 0.65, -1.32) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "MuzzleBore", Vector3.new(0.06, 0.12, 0.12), CFrame.new(0, 0.65, -1.46) * CFrame.Angles(0, math.rad(90), 0), boreDark, Enum.Material.Metal, Enum.PartType.Cylinder)
	end

	return m
end

local function buildAmmoModel(ammoId: string): Model
	local m = Instance.new("Model")
	m.Name = "PreviewAmmo_" .. ammoId
	local brass = Color3.fromRGB(186, 148, 66)
	local copper = Color3.fromRGB(168, 96, 52)
	local steelBox = Color3.fromRGB(40, 46, 42)
	local redShell = Color3.fromRGB(136, 28, 34)

	if ammoId == "Shotgun12G" then
		addPart(m, "ShellBox", Vector3.new(1.3, 0.9, 1.0), CFrame.new(-0.35, 0.45, 0.25), Color3.fromRGB(48, 32, 32), Enum.Material.Fabric, nil)
		for i = 0, 2 do
			local x = 0.48 + i * 0.34
			addPart(m, "BrassBase", Vector3.new(0.26, 0.24, 0.24), CFrame.new(x, 0.13, -0.25) * CFrame.Angles(0, 0, math.rad(90)), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
			addPart(m, "Hull", Vector3.new(0.68, 0.23, 0.23), CFrame.new(x, 0.58, -0.25) * CFrame.Angles(0, 0, math.rad(90)), redShell, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	elseif ammoId == "Sniper308" then
		addPart(m, "AmmoTin", Vector3.new(1.6, 0.95, 1.0), CFrame.new(-0.35, 0.48, 0.30), steelBox, Enum.Material.Metal, nil)
		for i = 0, 2 do
			local x = 0.56 + i * 0.30
			addPart(m, "Casing", Vector3.new(0.82, 0.18, 0.18), CFrame.new(x, 0.42, -0.28) * CFrame.Angles(0, 0, math.rad(90)), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
			addPart(m, "Tip", Vector3.new(0.36, 0.15, 0.15), CFrame.new(x, 0.98, -0.28) * CFrame.Angles(0, 0, math.rad(90)), copper, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	elseif ammoId == "Rifle556" or ammoId == "SMG45" then
		local magH = if ammoId == "Rifle556" then 1.48 else 1.62
		addPart(m, "Mag", Vector3.new(0.38, magH, 0.68), CFrame.new(-0.32, magH * 0.5, 0.10) * CFrame.Angles(math.rad(-14), 0, 0), P.Gunmetal, Enum.Material.Metal, nil)
		for i = 0, 2 do
			local x = 0.32 + i * 0.28
			addPart(m, "Case", Vector3.new(0.56, 0.16, 0.16), CFrame.new(x, 0.28, -0.18) * CFrame.Angles(0, 0, math.rad(90)), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
			addPart(m, "Bullet", Vector3.new(0.24, 0.14, 0.14), CFrame.new(x, 0.66, -0.18) * CFrame.Angles(0, 0, math.rad(90)), copper, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	else
		addPart(m, "Box", Vector3.new(1.2, 0.72, 0.9), CFrame.new(-0.35, 0.36, 0.20), P.Charcoal, Enum.Material.Fabric, nil)
		addPart(m, "Mag", Vector3.new(0.26, 1.15, 0.44), CFrame.new(0.45, 0.58, 0.10) * CFrame.Angles(math.rad(-10), 0, 0), P.Gunmetal, Enum.Material.Metal, nil)
		for i = 0, 1 do
			local x = 0.26 + i * 0.26
			addPart(m, "Round", Vector3.new(0.36, 0.15, 0.15), CFrame.new(x, 0.18, -0.40) * CFrame.Angles(0, 0, math.rad(90)), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
	return m
end

-- ============================================================================
-- SCULPTED 3D VEHICLE ICONS (Motorbike, Mafia Sedan, Armored Van, Coupe)
-- ============================================================================
local function buildMotorbikeModel(withCargoBox: boolean, tankColor: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "PreviewMotorbike"
	local tireCol = Color3.fromRGB(22, 24, 28)
	local rimCol = Color3.fromRGB(192, 198, 210)
	local bodyCol = tankColor or Color3.fromRGB(168, 36, 44)
	local steel = Color3.fromRGB(92, 98, 112)

	-- Wheels (front & rear)
	addPart(m, "FrontTire", Vector3.new(0.42, 1.18, 1.18), CFrame.new(0, 0.58, -1.45), tireCol, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	addPart(m, "FrontRim", Vector3.new(0.46, 0.68, 0.68), CFrame.new(0, 0.58, -1.45), rimCol, Enum.Material.Metal, Enum.PartType.Cylinder)
	addPart(m, "RearTire", Vector3.new(0.46, 1.18, 1.18), CFrame.new(0, 0.58, 1.35), tireCol, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	addPart(m, "RearRim", Vector3.new(0.50, 0.68, 0.68), CFrame.new(0, 0.58, 1.35), rimCol, Enum.Material.Metal, Enum.PartType.Cylinder)
	-- Frame, Engine, Tank, Fairing, Seat & Handlebars
	addPart(m, "Engine", Vector3.new(0.66, 0.68, 1.25), CFrame.new(0, 0.72, -0.05), steel, Enum.Material.Metal, nil)
	addPart(m, "FuelTank", Vector3.new(0.76, 0.46, 1.12), CFrame.new(0, 1.25, -0.35) * CFrame.Angles(math.rad(-12), 0, 0), bodyCol, Enum.Material.Metal, nil)
	addPart(m, "FrontFairing", Vector3.new(0.68, 0.74, 0.84), CFrame.new(0, 1.32, -1.18) * CFrame.Angles(math.rad(-26), 0, 0), bodyCol, Enum.Material.Metal, nil)
	addPart(m, "Headlight", Vector3.new(0.42, 0.24, 0.16), CFrame.new(0, 1.28, -1.58), Color3.fromRGB(250, 232, 178), Enum.Material.SmoothPlastic, nil)
	addPart(m, "FrontFork", Vector3.new(0.54, 1.12, 0.16), CFrame.new(0, 1.05, -1.25) * CFrame.Angles(math.rad(22), 0, 0), rimCol, Enum.Material.Metal, nil)
	addPart(m, "Handlebar", Vector3.new(1.52, 0.14, 0.14), CFrame.new(0, 1.62, -0.98), rimCol, Enum.Material.Metal, nil)
	addPart(m, "Seat", Vector3.new(0.66, 0.24, 1.28), CFrame.new(0, 1.10, 0.65), P.WornLeather, Enum.Material.Leather, nil)
	addPart(m, "Exhaust", Vector3.new(1.35, 0.18, 0.18), CFrame.new(0.42, 0.62, 0.92) * CFrame.Angles(0, math.rad(90), math.rad(8)), rimCol, Enum.Material.Metal, Enum.PartType.Cylinder)

	if withCargoBox then
		addPart(m, "CargoCrate", Vector3.new(0.95, 0.78, 0.95), CFrame.new(0, 1.56, 1.25), Color3.fromRGB(148, 102, 58), Enum.Material.WoodPlanks, nil)
		addPart(m, "CrateTrim", Vector3.new(0.99, 0.12, 0.99), CFrame.new(0, 1.84, 1.25), P.TarnishedBrass, Enum.Material.Metal, nil)
	end
	return m
end

local function buildCarModel(carKind: "Sedan" | "Van" | "Coupe" | "Truck"): Model
	local m = Instance.new("Model")
	m.Name = "PreviewVehicle_" .. carKind
	local tireCol = Color3.fromRGB(20, 22, 26)
	local rimCol = Color3.fromRGB(186, 192, 204)
	local glassCol = Color3.fromRGB(48, 60, 78)
	local bodyCol = if carKind == "Coupe"
		then Color3.fromRGB(36, 38, 46)
		elseif carKind == "Van" then Color3.fromRGB(48, 52, 60)
		elseif carKind == "Truck" then Color3.fromRGB(44, 54, 48)
		else Color3.fromRGB(26, 28, 34)
	local accentCol = if carKind == "Coupe"
		then Color3.fromRGB(162, 34, 42)
		elseif carKind == "Truck" then Color3.fromRGB(186, 148, 68)
		else Color3.fromRGB(168, 138, 76)

	local bodyLen = if carKind == "Van" or carKind == "Truck" then 3.5 else 3.8
	local wheelZ = bodyLen * 0.34
	for _, sx in ipairs({ -0.96, 0.96 }) do
		for _, sz in ipairs({ -wheelZ, wheelZ }) do
			addPart(m, "Tire", Vector3.new(0.36, 0.82, 0.82), CFrame.new(sx, 0.41, sz), tireCol, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			addPart(m, "Rim", Vector3.new(0.40, 0.46, 0.46), CFrame.new(sx, 0.41, sz), rimCol, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end

	if carKind == "Van" then
		addPart(m, "LowerBody", Vector3.new(1.92, 0.78, 3.55), CFrame.new(0, 0.78, 0), bodyCol, Enum.Material.Metal, nil)
		addPart(m, "CargoCabin", Vector3.new(1.86, 1.02, 2.75), CFrame.new(0, 1.54, 0.32), bodyCol, Enum.Material.Metal, nil)
		addPart(m, "Windshield", Vector3.new(1.66, 0.62, 0.18), CFrame.new(0, 1.48, -1.10) * CFrame.Angles(math.rad(-16), 0, 0), glassCol, Enum.Material.Glass, nil)
		addPart(m, "Bullbar", Vector3.new(1.78, 0.42, 0.22), CFrame.new(0, 0.68, -1.86), rimCol, Enum.Material.Metal, nil)
		addPart(m, "Stripe", Vector3.new(1.96, 0.14, 3.45), CFrame.new(0, 0.98, 0), accentCol, Enum.Material.Metal, nil)
	elseif carKind == "Truck" then
		addPart(m, "Chassis", Vector3.new(1.88, 0.44, 3.65), CFrame.new(0, 0.62, 0), P.Charcoal, Enum.Material.Metal, nil)
		addPart(m, "Cab", Vector3.new(1.78, 1.15, 1.22), CFrame.new(0, 1.38, -1.18), bodyCol, Enum.Material.Metal, nil)
		addPart(m, "CabGlass", Vector3.new(1.56, 0.48, 0.16), CFrame.new(0, 1.54, -1.78), glassCol, Enum.Material.Glass, nil)
		addPart(m, "CargoVault", Vector3.new(1.88, 1.24, 2.22), CFrame.new(0, 1.44, 0.68), Color3.fromRGB(58, 62, 72), Enum.Material.Metal, nil)
		addPart(m, "VaultTrim", Vector3.new(1.94, 0.18, 2.26), CFrame.new(0, 1.98, 0.68), accentCol, Enum.Material.Metal, nil)
	elseif carKind == "Coupe" then
		addPart(m, "Chassis", Vector3.new(1.94, 0.56, 3.85), CFrame.new(0, 0.64, 0), bodyCol, Enum.Material.Metal, nil)
		addPart(m, "Cabin", Vector3.new(1.62, 0.58, 1.65), CFrame.new(0, 1.14, 0.22), bodyCol, Enum.Material.Metal, nil)
		addPart(m, "Windshield", Vector3.new(1.48, 0.46, 0.20), CFrame.new(0, 1.12, -0.62) * CFrame.Angles(math.rad(-34), 0, 0), glassCol, Enum.Material.Glass, nil)
		addPart(m, "RacingStripe", Vector3.new(0.42, 0.08, 3.82), CFrame.new(0, 0.94, 0), accentCol, Enum.Material.Metal, nil)
		addPart(m, "Spoiler", Vector3.new(1.88, 0.12, 0.34), CFrame.new(0, 1.18, 1.76), accentCol, Enum.Material.Metal, nil)
	else
		-- Classic Mafia V8 Sedan
		addPart(m, "Chassis", Vector3.new(1.92, 0.68, 3.85), CFrame.new(0, 0.72, 0), bodyCol, Enum.Material.Metal, nil)
		addPart(m, "Cabin", Vector3.new(1.68, 0.68, 1.88), CFrame.new(0, 1.32, 0.16), bodyCol, Enum.Material.Metal, nil)
		addPart(m, "Windshield", Vector3.new(1.52, 0.52, 0.18), CFrame.new(0, 1.28, -0.80) * CFrame.Angles(math.rad(-24), 0, 0), glassCol, Enum.Material.Glass, nil)
		addPart(m, "ChromeGrille", Vector3.new(0.95, 0.38, 0.14), CFrame.new(0, 0.72, -1.94), rimCol, Enum.Material.Metal, nil)
		addPart(m, "SideTrim", Vector3.new(1.98, 0.09, 3.65), CFrame.new(0, 0.86, 0), accentCol, Enum.Material.Metal, nil)
	end

	-- Twin Warm Headlights
	addPart(m, "HeadlightL", Vector3.new(0.36, 0.22, 0.12), CFrame.new(-0.66, 0.76, -bodyLen * 0.50), Color3.fromRGB(252, 236, 186), Enum.Material.SmoothPlastic, nil)
	addPart(m, "HeadlightR", Vector3.new(0.36, 0.22, 0.12), CFrame.new(0.66, 0.76, -bodyLen * 0.50), Color3.fromRGB(252, 236, 186), Enum.Material.SmoothPlastic, nil)
	return m
end

-- ============================================================================
-- SCULPTED REALISTIC 3D KITCHEN DISH ICONS (Every Recipe + Active Order Cloche!)
-- ============================================================================
local function buildDishModel(dishId: string): Model
	local m = Instance.new("Model")
	m.Name = "PreviewDish_" .. dishId
	local porcelain = Color3.fromRGB(244, 242, 236)
	local plateRim = Color3.fromRGB(218, 182, 82)
	local darkSlate = Color3.fromRGB(32, 36, 44)
	local gold = Color3.fromRGB(238, 192, 62)
	local salmon = Color3.fromRGB(246, 118, 82)
	local lobsterRed = Color3.fromRGB(218, 44, 38)
	local steakBrown = Color3.fromRGB(108, 52, 32)
	local charDark = Color3.fromRGB(48, 24, 16)
	local bunGold = Color3.fromRGB(224, 152, 68)
	local sesameCol = Color3.fromRGB(252, 238, 196)
	local cheddar = Color3.fromRGB(252, 194, 36)
	local lettuce = Color3.fromRGB(76, 184, 68)
	local lemon = Color3.fromRGB(248, 218, 62)
	local woodBoard = Color3.fromRGB(142, 92, 52)
	local fryGold = Color3.fromRGB(244, 194, 62)

	if dishId == "ActiveOrder" then
		-- Silver Fine-Dining Serving Cloche on Gold-Rimmed Porcelain Plate with Steam Plume
		addPart(m, "PlateRim", Vector3.new(0.14, 2.52, 2.52), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), plateRim, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Plate", Vector3.new(0.18, 2.34, 2.34), CFrame.new(0, 0.11, 0) * CFrame.Angles(0, 0, math.rad(90)), porcelain, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "DomeLip", Vector3.new(0.18, 2.02, 2.02), CFrame.new(0, 0.28, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(184, 192, 206), Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "DomeBase", Vector3.new(0.42, 1.88, 1.88), CFrame.new(0, 0.50, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(204, 212, 224), Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "DomeTop", Vector3.new(1.82, 1.24, 1.82), CFrame.new(0, 0.72, 0), Color3.fromRGB(224, 230, 240), Enum.Material.Metal, Enum.PartType.Ball)
		addPart(m, "HandleNeck", Vector3.new(0.18, 0.24, 0.24), CFrame.new(0, 1.38, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Knob", Vector3.new(0.38, 0.34, 0.38), CFrame.new(0, 1.56, 0), gold, Enum.Material.Metal, Enum.PartType.Ball)
		return m
	elseif dishId == "TropicalSmoothie" then
		-- Tall Crystal Hurricane Glass with Layered Mango-Berry Smoothie, Swirled Whipped Cream, Orange Wheel, Cherry & Bendy Straw
		addPart(m, "GlassFoot", Vector3.new(0.16, 1.06, 1.06), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(224, 238, 248), Enum.Material.Glass, Enum.PartType.Cylinder)
		addPart(m, "GlassStem", Vector3.new(0.32, 0.34, 0.34), CFrame.new(0, 0.28, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(224, 238, 248), Enum.Material.Glass, Enum.PartType.Cylinder)
		addPart(m, "LayerBot", Vector3.new(0.68, 1.08, 1.08), CFrame.new(0, 0.76, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(242, 92, 68), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "LayerMid", Vector3.new(0.64, 1.18, 1.18), CFrame.new(0, 1.34, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(252, 166, 36), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "LayerTop", Vector3.new(0.34, 1.24, 1.24), CFrame.new(0, 1.78, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(254, 212, 62), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		-- Swirled triple-tier whipped cream + ruby cherry + citrus wheel + striped bendy straw
		addPart(m, "Whip1", Vector3.new(1.06, 0.42, 1.06), CFrame.new(0, 2.02, 0), Color3.fromRGB(252, 248, 238), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Whip2", Vector3.new(0.76, 0.36, 0.76), CFrame.new(0, 2.28, 0), Color3.fromRGB(252, 248, 238), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "WhipPeak", Vector3.new(0.42, 0.28, 0.42), CFrame.new(0, 2.48, 0), Color3.fromRGB(255, 252, 244), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Cherry", Vector3.new(0.30, 0.30, 0.30), CFrame.new(0.18, 2.54, -0.14), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "OrangeRind", Vector3.new(0.12, 0.74, 0.74), CFrame.new(0.62, 1.98, -0.16) * CFrame.Angles(0, math.rad(25), math.rad(18)), Color3.fromRGB(246, 134, 24), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "OrangePulp", Vector3.new(0.15, 0.56, 0.56), CFrame.new(0.62, 1.98, -0.16) * CFrame.Angles(0, math.rad(25), math.rad(18)), Color3.fromRGB(254, 186, 56), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "StrawLower", Vector3.new(1.18, 0.12, 0.12), CFrame.new(-0.28, 2.34, 0) * CFrame.Angles(0, 0, math.rad(76)), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "StrawBend", Vector3.new(0.58, 0.12, 0.12), CFrame.new(-0.62, 2.94, 0) * CFrame.Angles(0, 0, math.rad(22)), porcelain, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		return m
	elseif dishId == "ClassicBurger" then
		-- Mouth-Watering Gourmet Brioche Cheeseburger + Sesame Seeds + Melted Dripping Cheddar + Skewered Olive + Golden Fries!
		addPart(m, "PlateRim", Vector3.new(0.14, 2.66, 2.66), CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(218, 214, 206), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Plate", Vector3.new(0.18, 2.46, 2.46), CFrame.new(0, 0.10, 0) * CFrame.Angles(0, 0, math.rad(90)), porcelain, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		local bx = -0.22
		addPart(m, "BottomBun", Vector3.new(0.30, 1.48, 1.48), CFrame.new(bx, 0.34, 0) * CFrame.Angles(0, 0, math.rad(90)), bunGold, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		-- Ruffled layered lettuce base
		for a = 0, 5 do
			local ang = math.rad(a * 60)
			addPart(m, "Let_" .. a, Vector3.new(0.56, 0.12, 0.56), CFrame.new(bx + math.cos(ang) * 0.52, 0.52, math.sin(ang) * 0.52) * CFrame.Angles(math.rad(10), ang, 0), lettuce, Enum.Material.SmoothPlastic, nil)
		end
		-- Thick flame-grilled beef patty with char edge
		addPart(m, "Patty", Vector3.new(0.36, 1.56, 1.56), CFrame.new(bx, 0.72, 0) * CFrame.Angles(0, 0, math.rad(90)), steakBrown, Enum.Material.Fabric, Enum.PartType.Cylinder)
		-- Melted cheddar square + draped melted corner flaps!
		addPart(m, "Cheese", Vector3.new(1.52, 0.12, 1.52), CFrame.new(bx, 0.94, 0) * CFrame.Angles(0, math.rad(28), 0), cheddar, Enum.Material.SmoothPlastic, nil)
		addWedge(m, "CheeseDrip1", Vector3.new(0.46, 0.28, 0.18), CFrame.new(bx + 0.58, 0.80, -0.52) * CFrame.Angles(math.rad(165), math.rad(35), 0), cheddar, Enum.Material.SmoothPlastic)
		addWedge(m, "CheeseDrip2", Vector3.new(0.46, 0.28, 0.18), CFrame.new(bx - 0.56, 0.80, -0.54) * CFrame.Angles(math.rad(165), math.rad(-35), 0), cheddar, Enum.Material.SmoothPlastic)
		-- Twin ruby tomato slices + crisp onion ring
		addPart(m, "Tomato1", Vector3.new(0.14, 0.86, 0.86), CFrame.new(bx - 0.26, 1.06, -0.22) * CFrame.Angles(0, 0, math.rad(90)), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Tomato2", Vector3.new(0.14, 0.86, 0.86), CFrame.new(bx + 0.26, 1.06, 0.18) * CFrame.Angles(0, 0, math.rad(90)), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		-- Glossy toasted brioche crown bun + 7 golden sesame seeds + olive skewer!
		addPart(m, "TopBunBase", Vector3.new(0.24, 1.52, 1.52), CFrame.new(bx, 1.24, 0) * CFrame.Angles(0, 0, math.rad(90)), bunGold, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "TopBunDome", Vector3.new(1.52, 0.78, 1.52), CFrame.new(bx, 1.38, 0), Color3.fromRGB(214, 138, 52), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for s = 0, 5 do
			local ang = math.rad(s * 60 + 18)
			addPart(m, "Seed_" .. s, Vector3.new(0.12, 0.06, 0.18), CFrame.new(bx + math.cos(ang) * 0.42, 1.72, math.sin(ang) * 0.42) * CFrame.Angles(0, -ang, 0), sesameCol, Enum.Material.SmoothPlastic, nil)
		end
		addPart(m, "SeedTop", Vector3.new(0.14, 0.06, 0.18), CFrame.new(bx, 1.78, 0), sesameCol, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Skewer", Vector3.new(0.06, 0.56, 0.06), CFrame.new(bx, 1.98, 0), woodBoard, Enum.Material.Wood, nil)
		addPart(m, "Olive", Vector3.new(0.24, 0.24, 0.24), CFrame.new(bx, 2.04, 0), Color3.fromRGB(98, 148, 54), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		-- Golden French fries bundle tucked beside the burger on the plate!
		for f = 0, 5 do
			local fAng = math.rad(-18 + f * 9)
			addPart(m, "Fry_" .. f, Vector3.new(0.14, 0.74, 0.14), CFrame.new(0.76 + (f % 2) * 0.18, 0.46, -0.32 + f * 0.12) * CFrame.Angles(fAng, math.rad(14 * f), math.rad(-22)), fryGold, Enum.Material.SmoothPlastic, nil)
		end
		return m
	elseif dishId == "FreshSushi" or dishId == "GoldenTunaSashimi" then
		-- Handcrafted Cedar Geta Sushi Board with Marbled Nigiri, Soy Bowl, Ginger, Wasabi & Lacquered Chopsticks!
		local isGolden = (dishId == "GoldenTunaSashimi")
		local fishCol = if isGolden then gold else salmon
		addPart(m, "BoardTop", Vector3.new(2.38, 0.18, 1.56), CFrame.new(0, 0.26, 0), woodBoard, Enum.Material.Wood, nil)
		addPart(m, "FootL", Vector3.new(0.22, 0.20, 1.38), CFrame.new(-0.84, 0.10, 0), Color3.fromRGB(98, 62, 34), Enum.Material.Wood, nil)
		addPart(m, "FootR", Vector3.new(0.22, 0.20, 1.38), CFrame.new(0.84, 0.10, 0), Color3.fromRGB(98, 62, 34), Enum.Material.Wood, nil)
		for i = -1, 1 do
			local x = i * 0.64 - 0.12
			addPart(m, "Rice_" .. i, Vector3.new(0.46, 0.34, 0.82), CFrame.new(x, 0.50, 0.08), Color3.fromRGB(250, 248, 244), Enum.Material.SmoothPlastic, nil)
			addPart(m, "Fish_" .. i, Vector3.new(0.50, 0.16, 1.06), CFrame.new(x, 0.72, 0.08) * CFrame.Angles(math.rad(-6), 0, 0), fishCol, if isGolden then Enum.Material.Metal else Enum.Material.SmoothPlastic, nil)
			-- Delicate white sashimi marbling stripes across each cut!
			for st = -1, 1 do
				addPart(m, "Marble_" .. i .. "_" .. st, Vector3.new(0.52, 0.04, 0.07), CFrame.new(x, 0.79, 0.08 + st * 0.24) * CFrame.Angles(0, math.rad(16), 0), Color3.fromRGB(252, 232, 224), Enum.Material.SmoothPlastic, nil)
			end
			addPart(m, "Nori_" .. i, Vector3.new(0.54, 0.44, 0.20), CFrame.new(x, 0.60, 0.08), Color3.fromRGB(20, 32, 22), Enum.Material.Fabric, nil)
		end
		addPart(m, "Wasabi", Vector3.new(0.32, 0.26, 0.32), CFrame.new(0.88, 0.44, -0.44), Color3.fromRGB(116, 198, 72), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Ginger", Vector3.new(0.38, 0.14, 0.30), CFrame.new(0.88, 0.40, 0.02) * CFrame.Angles(0, math.rad(22), 0), Color3.fromRGB(246, 178, 174), Enum.Material.SmoothPlastic, nil)
		-- Ceramic Soy Sauce Dish
		addPart(m, "SoyDish", Vector3.new(0.16, 0.54, 0.54), CFrame.new(0.86, 0.42, 0.46) * CFrame.Angles(0, 0, math.rad(90)), darkSlate, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "SoySauce", Vector3.new(0.18, 0.40, 0.40), CFrame.new(0.86, 0.43, 0.46) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(36, 18, 12), Enum.Material.Glass, Enum.PartType.Cylinder)
		-- Lacquered Chopsticks along front edge
		addPart(m, "Stick1", Vector3.new(2.15, 0.08, 0.08), CFrame.new(-0.08, 0.42, -0.62) * CFrame.Angles(0, math.rad(3), 0), Color3.fromRGB(32, 20, 18), Enum.Material.Wood, nil)
		addPart(m, "Stick2", Vector3.new(2.15, 0.08, 0.08), CFrame.new(-0.08, 0.42, -0.50) * CFrame.Angles(0, math.rad(-2), 0), Color3.fromRGB(32, 20, 18), Enum.Material.Wood, nil)
		return m
	elseif dishId == "GrilledFish" then
		-- Whole Char-Grilled Snapper with Sculpted Forked Tail, Dorsal/Pectoral Fins, Eye, Diagonal Grill Marks & Lemon Rounds!
		addPart(m, "Plate", Vector3.new(0.16, 2.52, 2.52), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), porcelain, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "FishBody", Vector3.new(1.78, 0.52, 0.86), CFrame.new(-0.18, 0.44, 0), Color3.fromRGB(132, 168, 198), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "BellySheen", Vector3.new(1.38, 0.34, 0.72), CFrame.new(-0.18, 0.32, 0.16), Color3.fromRGB(224, 232, 238), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		-- Forked wedge tail fin + dorsal fin + pectoral fin
		addWedge(m, "TailTop", Vector3.new(0.14, 0.38, 0.58), CFrame.new(0.86, 0.44, -0.18) * CFrame.Angles(math.rad(-24), math.rad(-90), 0), Color3.fromRGB(98, 134, 166), Enum.Material.SmoothPlastic)
		addWedge(m, "TailBot", Vector3.new(0.14, 0.38, 0.58), CFrame.new(0.86, 0.44, 0.18) * CFrame.Angles(math.rad(24), math.rad(-90), 0), Color3.fromRGB(98, 134, 166), Enum.Material.SmoothPlastic)
		addWedge(m, "DorsalFin", Vector3.new(0.12, 0.26, 0.78), CFrame.new(-0.14, 0.52, -0.44) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(108, 144, 176), Enum.Material.SmoothPlastic)
		addPart(m, "FishEye", Vector3.new(0.16, 0.16, 0.16), CFrame.new(-0.84, 0.54, -0.16), Color3.fromRGB(24, 26, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for i = -1, 2 do
			addPart(m, "GrillMark_" .. i, Vector3.new(0.08, 0.42, 0.68), CFrame.new(-0.34 + i * 0.28, 0.52, 0) * CFrame.Angles(0, math.rad(20), 0), charDark, Enum.Material.SmoothPlastic, nil)
		end
		addPart(m, "Lemon1", Vector3.new(0.12, 0.54, 0.54), CFrame.new(-0.46, 0.24, 0.66) * CFrame.Angles(0, 0, math.rad(90)), lemon, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Lemon2", Vector3.new(0.12, 0.50, 0.50), CFrame.new(0.24, 0.24, 0.68) * CFrame.Angles(0, 0, math.rad(90)), lemon, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Parsley", Vector3.new(0.42, 0.16, 0.36), CFrame.new(-0.24, 0.72, 0.08), lettuce, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		return m
	elseif dishId == "SizzlingSteak" then
		-- Heavy Cast-Iron Skillet with Diamond-Seared Ribeye, Melting Herb Garlic Butter, Roasted Cherry Tomatoes & Baby Potatoes!
		addPart(m, "SkilletOuter", Vector3.new(0.32, 2.30, 2.30), CFrame.new(0, 0.18, 0) * CFrame.Angles(0, 0, math.rad(90)), darkSlate, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "SkilletInner", Vector3.new(0.24, 2.08, 2.08), CFrame.new(0, 0.24, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(44, 48, 56), Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Handle", Vector3.new(0.28, 0.18, 1.08), CFrame.new(0, 0.28, 1.56), darkSlate, Enum.Material.Metal, nil)
		addPart(m, "SteakMain", Vector3.new(1.42, 0.44, 0.98), CFrame.new(-0.14, 0.52, -0.10) * CFrame.Angles(0, math.rad(-10), 0), steakBrown, Enum.Material.Fabric, nil)
		addPart(m, "SteakCap", Vector3.new(0.86, 0.42, 0.78), CFrame.new(0.34, 0.50, 0.08), steakBrown, Enum.Material.Fabric, Enum.PartType.Ball)
		-- Diamond crosshatch grill sear marks!
		for g = -1, 1 do
			addPart(m, "SearA_" .. g, Vector3.new(0.07, 0.06, 0.92), CFrame.new(-0.14 + g * 0.32, 0.76, -0.10) * CFrame.Angles(0, math.rad(32), 0), charDark, Enum.Material.SmoothPlastic, nil)
			addPart(m, "SearB_" .. g, Vector3.new(0.07, 0.06, 0.92), CFrame.new(-0.14 + g * 0.32, 0.76, -0.10) * CFrame.Angles(0, math.rad(-32), 0), charDark, Enum.Material.SmoothPlastic, nil)
		end
		addPart(m, "HerbButter", Vector3.new(0.44, 0.16, 0.44), CFrame.new(-0.08, 0.84, -0.06) * CFrame.Angles(0, math.rad(28), 0), Color3.fromRGB(252, 232, 128), Enum.Material.SmoothPlastic, nil)
		addPart(m, "Rosemary", Vector3.new(0.58, 0.10, 0.16), CFrame.new(0.26, 0.80, -0.22) * CFrame.Angles(0, math.rad(-25), 0), lettuce, Enum.Material.SmoothPlastic, nil)
		-- Blistered cherry tomatoes & golden roasted garlic potatoes
		addPart(m, "Tom1", Vector3.new(0.32, 0.32, 0.32), CFrame.new(-0.62, 0.46, 0.56), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Tom2", Vector3.new(0.30, 0.30, 0.30), CFrame.new(-0.30, 0.45, 0.68), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Potato1", Vector3.new(0.42, 0.32, 0.34), CFrame.new(0.56, 0.46, -0.58), bunGold, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Potato2", Vector3.new(0.38, 0.30, 0.32), CFrame.new(0.22, 0.44, -0.72), bunGold, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		return m
	elseif dishId == "CrabFeast" or dishId == "KingCrabPlatter" then
		-- Realistic Jointed Crimson Crab / Giant King Crab with Articulated Legs, Raised Snapper Claws, Eye Stalks & Butter Cup!
		local isKing = (dishId == "KingCrabPlatter")
		local plateCol = if isKing then darkSlate else porcelain
		local crabCol = if isKing then Color3.fromRGB(232, 56, 38) else Color3.fromRGB(218, 70, 44)
		addPart(m, "Plate", Vector3.new(0.16, 2.58, 2.58), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), plateCol, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Carapace", Vector3.new(1.26, 0.58, 1.06), CFrame.new(0, 0.46, 0.14), crabCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "EyeL", Vector3.new(0.12, 0.22, 0.12), CFrame.new(-0.24, 0.66, -0.34), Color3.fromRGB(24, 24, 28), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "EyeR", Vector3.new(0.12, 0.22, 0.12), CFrame.new(0.24, 0.66, -0.34), Color3.fromRGB(24, 24, 28), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		-- Jointed snapper claws
		for _, sign in ipairs({ -1, 1 }) do
			addPart(m, "ClawArm_" .. sign, Vector3.new(0.22, 0.22, 0.58), CFrame.new(sign * 0.64, 0.48, -0.36) * CFrame.Angles(0, math.rad(-sign * 26), 0), crabCol, Enum.Material.SmoothPlastic, nil)
			addPart(m, "PincerOuter_" .. sign, Vector3.new(0.44, 0.34, 0.64), CFrame.new(sign * 0.78, 0.58, -0.78) * CFrame.Angles(0, math.rad(sign * 26), 0), crabCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			addWedge(m, "PincerTip_" .. sign, Vector3.new(0.18, 0.20, 0.42), CFrame.new(sign * 0.54, 0.56, -0.94) * CFrame.Angles(0, math.rad(sign * 42), 0), Color3.fromRGB(248, 224, 198), Enum.Material.SmoothPlastic)
			for lIdx, sz in ipairs({ -0.06, 0.24, 0.52 }) do
				addPart(m, "LegUp_" .. sign .. "_" .. lIdx, Vector3.new(0.56, 0.14, 0.14), CFrame.new(sign * 0.76, 0.44, sz) * CFrame.Angles(0, math.rad(-sign * 10 * (lIdx - 2)), math.rad(sign * 18)), crabCol, Enum.Material.SmoothPlastic, nil)
				addPart(m, "LegLow_" .. sign .. "_" .. lIdx, Vector3.new(0.46, 0.11, 0.11), CFrame.new(sign * 1.12, 0.28, sz + 0.04) * CFrame.Angles(0, 0, math.rad(-sign * 34)), crabCol, Enum.Material.SmoothPlastic, nil)
			end
		end
		addPart(m, "ButterCup", Vector3.new(0.26, 0.52, 0.52), CFrame.new(0, 0.28, -0.88) * CFrame.Angles(0, 0, math.rad(90)), porcelain, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "ButterMelt", Vector3.new(0.28, 0.40, 0.40), CFrame.new(0, 0.30, -0.88) * CFrame.Angles(0, 0, math.rad(90)), lemon, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		return m
	elseif dishId == "GoldLeafLobster" then
		-- Michelin Gold-Leaf Lobster Thermidor: Articulated Segmented Tail, Fanned Tail Flippers, Hinged Claws, Sweeping Antennae & 24K Gold Leaf!
		addPart(m, "PlateRim", Vector3.new(0.14, 2.62, 2.62), CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Plate", Vector3.new(0.18, 2.46, 2.46), CFrame.new(0, 0.10, 0) * CFrame.Angles(0, 0, math.rad(90)), darkSlate, Enum.Material.Marble, Enum.PartType.Cylinder)
		-- Segmented curved lobster body + tail rings
		addPart(m, "HeadShell", Vector3.new(0.84, 0.56, 0.94), CFrame.new(0, 0.48, -0.34), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for seg = 0, 3 do
			local w = 0.76 - seg * 0.11
			local h = 0.46 - seg * 0.05
			addPart(m, "TailSeg_" .. seg, Vector3.new(w, h, 0.34), CFrame.new(0, 0.44 - seg * 0.04, 0.16 + seg * 0.24) * CFrame.Angles(math.rad(-seg * 5), 0, 0), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
		-- Fanned 3-blade tail flippers
		addPart(m, "TailMid", Vector3.new(0.36, 0.10, 0.44), CFrame.new(0, 0.26, 1.14), lobsterRed, Enum.Material.SmoothPlastic, nil)
		addPart(m, "TailL", Vector3.new(0.30, 0.10, 0.42), CFrame.new(-0.28, 0.26, 1.08) * CFrame.Angles(0, math.rad(-26), 0), lobsterRed, Enum.Material.SmoothPlastic, nil)
		addPart(m, "TailR", Vector3.new(0.30, 0.10, 0.42), CFrame.new(0.28, 0.26, 1.08) * CFrame.Angles(0, math.rad(26), 0), lobsterRed, Enum.Material.SmoothPlastic, nil)
		-- Creamy thermidor gratin + shimmering 24K gold leaf strip!
		addPart(m, "ThermidorSauce", Vector3.new(0.54, 0.16, 1.08), CFrame.new(0, 0.72, 0.04), Color3.fromRGB(246, 224, 162), Enum.Material.SmoothPlastic, nil)
		addPart(m, "GoldLeafTop", Vector3.new(0.42, 0.10, 0.88), CFrame.new(0, 0.82, 0.04), gold, Enum.Material.Metal, nil)
		-- Twin hinged claws + sweeping thin golden antennae
		for _, sign in ipairs({ -1, 1 }) do
			addPart(m, "Arm_" .. sign, Vector3.new(0.22, 0.20, 0.46), CFrame.new(sign * 0.54, 0.44, -0.58) * CFrame.Angles(0, math.rad(-sign * 20), 0), lobsterRed, Enum.Material.SmoothPlastic, nil)
			addPart(m, "Claw_" .. sign, Vector3.new(0.42, 0.34, 0.68), CFrame.new(sign * 0.66, 0.48, -0.94) * CFrame.Angles(0, math.rad(sign * 22), 0), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			addPart(m, "Antenna_" .. sign, Vector3.new(0.05, 0.05, 1.12), CFrame.new(sign * 0.24, 0.58, -1.04) * CFrame.Angles(math.rad(12), math.rad(-sign * 22), 0), Color3.fromRGB(238, 124, 72), Enum.Material.SmoothPlastic, nil)
		end
		addPart(m, "Lemon", Vector3.new(0.14, 0.46, 0.46), CFrame.new(-0.82, 0.26, 0.44) * CFrame.Angles(0, 0, math.rad(90)), lemon, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Herb", Vector3.new(0.32, 0.14, 0.32), CFrame.new(0.76, 0.30, 0.46), lettuce, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		return m
	elseif dishId == "SmokedCartelRibs" then
		-- Oak Butcher Board + Sculpted Glazed BBQ Rib Rack with Bone Tips + Buttered Sweet Corn Cob!
		addPart(m, "Board", Vector3.new(2.38, 0.22, 1.68), CFrame.new(0, 0.12, 0), woodBoard, Enum.Material.WoodPlanks, nil)
		addPart(m, "RibRack", Vector3.new(1.80, 0.52, 0.94), CFrame.new(-0.08, 0.48, 0.16), Color3.fromRGB(116, 42, 26), Enum.Material.SmoothPlastic, nil)
		for i = -2, 2 do
			addPart(m, "RibRidge_" .. i, Vector3.new(0.26, 0.58, 0.92), CFrame.new(-0.08 + i * 0.34, 0.52, 0.16), Color3.fromRGB(134, 48, 28), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			addPart(m, "BoneTip_" .. i, Vector3.new(0.14, 0.14, 0.48), CFrame.new(-0.08 + i * 0.34, 0.38, -0.44), porcelain, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
		addPart(m, "CornCob", Vector3.new(0.92, 0.38, 0.38), CFrame.new(0.46, 0.40, -0.58) * CFrame.Angles(0, math.rad(14), 0), Color3.fromRGB(248, 206, 48), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Parsley", Vector3.new(0.34, 0.16, 0.34), CFrame.new(-0.78, 0.42, -0.54), lettuce, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		return m
	elseif dishId == "TruffleWagyuTartare" then
		-- Molded Ruby Wagyu Beef Tower + Glossy Egg Yolk + Shaved Black Truffles + Golden Crostini Toast!
		addPart(m, "Plate", Vector3.new(0.16, 2.38, 2.38), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), darkSlate, Enum.Material.Slate, Enum.PartType.Cylinder)
		addPart(m, "Tartare", Vector3.new(0.66, 1.34, 1.34), CFrame.new(-0.14, 0.48, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(178, 42, 46), Enum.Material.Fabric, Enum.PartType.Cylinder)
		addPart(m, "EggYolk", Vector3.new(0.56, 0.38, 0.56), CFrame.new(-0.14, 0.92, 0), Color3.fromRGB(252, 186, 28), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "TruffleL", Vector3.new(0.28, 0.08, 0.28), CFrame.new(-0.56, 0.84, -0.26) * CFrame.Angles(0, math.rad(24), 0), P.Obsidian, Enum.Material.Slate, nil)
		addPart(m, "TruffleR", Vector3.new(0.28, 0.08, 0.28), CFrame.new(0.24, 0.84, 0.26) * CFrame.Angles(0, math.rad(-18), 0), P.Obsidian, Enum.Material.Slate, nil)
		addPart(m, "Crostini1", Vector3.new(0.14, 0.54, 0.44), CFrame.new(0.68, 0.44, -0.22) * CFrame.Angles(0, math.rad(16), math.rad(-26)), bunGold, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Crostini2", Vector3.new(0.14, 0.54, 0.44), CFrame.new(0.76, 0.40, 0.24) * CFrame.Angles(0, math.rad(-14), math.rad(-34)), bunGold, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Chives", Vector3.new(0.52, 0.06, 0.08), CFrame.new(-0.14, 1.10, -0.18) * CFrame.Angles(0, math.rad(30), 0), lettuce, Enum.Material.SmoothPlastic, nil)
		return m
	elseif dishId == "DonsMidnightTiramisu" then
		-- Layered Espresso Ladyfinger & Mascarpone Tiramisu + Piped Cream Rosettes + Chocolate Shard + Gold Leaf + Mint!
		addPart(m, "Plate", Vector3.new(0.16, 2.38, 2.38), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), porcelain, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Layer1", Vector3.new(1.38, 0.26, 1.38), CFrame.new(0, 0.29, 0), Color3.fromRGB(82, 48, 30), Enum.Material.Fabric, nil)
		addPart(m, "Layer2", Vector3.new(1.40, 0.30, 1.40), CFrame.new(0, 0.58, 0), Color3.fromRGB(248, 240, 222), Enum.Material.SmoothPlastic, nil)
		addPart(m, "Layer3", Vector3.new(1.38, 0.24, 1.38), CFrame.new(0, 0.85, 0), Color3.fromRGB(82, 48, 30), Enum.Material.Fabric, nil)
		addPart(m, "CocoaTop", Vector3.new(1.42, 0.14, 1.42), CFrame.new(0, 1.04, 0), Color3.fromRGB(54, 30, 18), Enum.Material.Fabric, nil)
		for _, off in ipairs({ { -0.38, -0.38 }, { 0.38, -0.38 }, { -0.38, 0.38 }, { 0.38, 0.38 } }) do
			addPart(m, "PipedCream", Vector3.new(0.36, 0.26, 0.36), CFrame.new(off[1], 1.20, off[2]), Color3.fromRGB(252, 246, 232), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
		addPart(m, "ChocShard", Vector3.new(0.10, 0.62, 0.44), CFrame.new(0.10, 1.36, -0.06) * CFrame.Angles(math.rad(-14), math.rad(24), math.rad(18)), Color3.fromRGB(42, 22, 14), Enum.Material.SmoothPlastic, nil)
		addPart(m, "GoldLeaf", Vector3.new(0.28, 0.12, 0.28), CFrame.new(-0.18, 1.18, 0.06), gold, Enum.Material.Metal, nil)
		addWedge(m, "MintLeaf", Vector3.new(0.24, 0.08, 0.38), CFrame.new(-0.28, 1.24, -0.14) * CFrame.Angles(0, math.rad(-35), 0), lettuce, Enum.Material.SmoothPlastic)
		return m
	else
		-- EmperorPlatter (Royal 24K Gold Banquet Charger with Seared Steak, Curled Lobster, Garnish & Jeweled Mini Crown!)
		addPart(m, "GoldPlatter", Vector3.new(0.20, 2.66, 2.66), CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "InnerPlate", Vector3.new(0.22, 2.24, 2.24), CFrame.new(0, 0.14, 0) * CFrame.Angles(0, 0, math.rad(90)), porcelain, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Roast", Vector3.new(0.92, 0.56, 0.78), CFrame.new(-0.46, 0.50, 0.12) * CFrame.Angles(0, math.rad(14), 0), steakBrown, Enum.Material.Fabric, nil)
		addPart(m, "Lobster", Vector3.new(0.76, 0.46, 0.88), CFrame.new(0.48, 0.46, -0.16), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Garnish", Vector3.new(0.68, 0.26, 0.56), CFrame.new(0.18, 0.36, 0.56), lettuce, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Lemon", Vector3.new(0.14, 0.44, 0.44), CFrame.new(-0.56, 0.30, -0.58) * CFrame.Angles(0, 0, math.rad(90)), lemon, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "CrownBand", Vector3.new(0.32, 0.76, 0.76), CFrame.new(0, 0.98, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		for i = 0, 4 do
			local ang = math.rad(i * 72)
			addWedge(m, "CrownTine_" .. i, Vector3.new(0.18, 0.34, 0.18), CFrame.new(math.cos(ang) * 0.32, 1.24, math.sin(ang) * 0.32), gold, Enum.Material.Metal)
		end
		return m
	end
end

-- ============================================================================
-- SCULPTED REALISTIC 3D WAREHOUSE CRATES (Real Fish, Veg, Fruit & Meat!)
-- ============================================================================
local function buildRealFruitCluster(m: Model, yBase: number): ()
	-- 1. REAL GLOSSY RED APPLE (Double-lobed sculpted apple + curved wood stem + pointed emerald leaf!)
	local appleRed = Color3.fromRGB(224, 28, 38)
	local ax, az = -0.52, 0.18
	addPart(m, "AppleLobeL", Vector3.new(0.56, 0.66, 0.64), CFrame.new(ax - 0.12, yBase + 0.34, az), appleRed, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	addPart(m, "AppleLobeR", Vector3.new(0.56, 0.66, 0.64), CFrame.new(ax + 0.12, yBase + 0.34, az), appleRed, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	addPart(m, "AppleHighlight", Vector3.new(0.22, 0.28, 0.22), CFrame.new(ax - 0.20, yBase + 0.46, az - 0.22), Color3.fromRGB(252, 128, 128), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	addPart(m, "AppleStem", Vector3.new(0.08, 0.30, 0.08), CFrame.new(ax, yBase + 0.74, az) * CFrame.Angles(0, 0, math.rad(-16)), Color3.fromRGB(98, 58, 28), Enum.Material.Wood, Enum.PartType.Cylinder)
	addWedge(m, "AppleLeaf", Vector3.new(0.26, 0.08, 0.42), CFrame.new(ax + 0.20, yBase + 0.80, az - 0.04) * CFrame.Angles(math.rad(-14), math.rad(72), math.rad(18)), Color3.fromRGB(54, 184, 58), Enum.Material.SmoothPlastic)

	-- 2. REAL TROPICAL PINEAPPLE (Textured golden-amber barrel + 6 spiky emerald crown leaves!)
	local px, pz = 0.44, -0.22
	addPart(m, "PineappleBody", Vector3.new(0.68, 0.92, 0.68), CFrame.new(px, yBase + 0.46, pz), Color3.fromRGB(238, 168, 28), Enum.Material.Cobblestone, Enum.PartType.Ball)
	addPart(m, "PineappleBand", Vector3.new(0.62, 0.56, 0.62), CFrame.new(px, yBase + 0.46, pz), Color3.fromRGB(246, 194, 46), Enum.Material.Cobblestone, Enum.PartType.Ball)
	for f = 0, 5 do
		local ang = math.rad(f * 60)
		addWedge(
			m,
			"PineCrown_" .. f,
			Vector3.new(0.14, 0.54, 0.24),
			CFrame.new(px + math.cos(ang) * 0.16, yBase + 1.06, pz + math.sin(ang) * 0.16)
				* CFrame.Angles(0, -ang + math.rad(90), math.rad(24)),
			Color3.fromRGB(48, 164, 56),
			Enum.Material.SmoothPlastic
		)
	end

	-- 3. REAL CURVED GOLDEN BANANA BUNCH (3 arched 3-segment crescents joined at a green stem crown!)
	local bananaCol = Color3.fromRGB(252, 222, 44)
	local bananaTip = Color3.fromRGB(68, 46, 22)
	local bx, bz = 0.18, 0.42
	addPart(m, "BananaCrown", Vector3.new(0.22, 0.18, 0.22), CFrame.new(bx - 0.36, yBase + 0.52, bz), Color3.fromRGB(122, 148, 44), Enum.Material.Wood, nil)
	for b = -1, 1 do
		local zOff = bz + b * 0.16
		addPart(m, "BanA_" .. b, Vector3.new(0.36, 0.18, 0.18), CFrame.new(bx - 0.18, yBase + 0.42, zOff) * CFrame.Angles(0, 0, math.rad(-26)), bananaCol, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "BanB_" .. b, Vector3.new(0.40, 0.20, 0.20), CFrame.new(bx + 0.14, yBase + 0.34, zOff) * CFrame.Angles(0, 0, math.rad(4)), bananaCol, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "BanC_" .. b, Vector3.new(0.34, 0.16, 0.16), CFrame.new(bx + 0.44, yBase + 0.44, zOff) * CFrame.Angles(0, 0, math.rad(34)), bananaCol, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "BanTip_" .. b, Vector3.new(0.08, 0.10, 0.10), CFrame.new(bx + 0.60, yBase + 0.54, zOff), bananaTip, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end

	-- 4. REAL SLICED WATERMELON WEDGE (Dark emerald rind + white pith + ruby flesh + black seeds!)
	local wx, wz = -0.34, -0.44
	local wCF = CFrame.new(wx, yBase + 0.34, wz) * CFrame.Angles(math.rad(-14), math.rad(32), 0)
	addWedge(m, "MelonFlesh", Vector3.new(0.24, 0.54, 0.72), wCF, Color3.fromRGB(238, 46, 66), Enum.Material.SmoothPlastic)
	addPart(m, "MelonPith", Vector3.new(0.26, 0.08, 0.78), wCF * CFrame.new(0, -0.28, 0), Color3.fromRGB(236, 246, 224), Enum.Material.SmoothPlastic, nil)
	addPart(m, "MelonRind", Vector3.new(0.28, 0.10, 0.82), wCF * CFrame.new(0, -0.34, 0), Color3.fromRGB(34, 134, 52), Enum.Material.SmoothPlastic, nil)
	for sd = -1, 1 do
		addPart(m, "MelonSeed_" .. sd, Vector3.new(0.27, 0.06, 0.08), wCF * CFrame.new(0, -0.06 + math.abs(sd) * 0.06, sd * 0.16), Color3.fromRGB(24, 20, 18), Enum.Material.SmoothPlastic, nil)
	end
end

local function buildWarehouseModel(category: string): Model
	local m = Instance.new("Model")
	m.Name = "PreviewWarehouse_" .. category
	local crateWood = Color3.fromRGB(142, 94, 52)
	local crateTrim = Color3.fromRGB(96, 62, 34)

	-- Slatted open-top wooden supply crate base
	addPart(m, "CrateBase", Vector3.new(2.04, 0.94, 1.62), CFrame.new(0, 0.47, 0), crateWood, Enum.Material.WoodPlanks, nil)
	addPart(m, "TrimBottom", Vector3.new(2.14, 0.16, 1.72), CFrame.new(0, 0.12, 0), crateTrim, Enum.Material.Wood, nil)
	addPart(m, "TrimTop", Vector3.new(2.14, 0.16, 1.72), CFrame.new(0, 0.90, 0), crateTrim, Enum.Material.Wood, nil)
	for _, cx in ipairs({ -0.98, 0.98 }) do
		for _, cz in ipairs({ -0.78, 0.78 }) do
			addPart(m, "Post", Vector3.new(0.18, 0.98, 0.18), CFrame.new(cx, 0.49, cz), crateTrim, Enum.Material.Wood, nil)
		end
	end

	if category == "Fish" then
		-- Crushed glistening ice bed + detailed sculpted ocean snapper & salmon with forked wedge tails, fins & jumbo curved shrimp!
		addPart(m, "IceBed", Vector3.new(1.86, 0.24, 1.44), CFrame.new(0, 1.00, 0), Color3.fromRGB(204, 236, 252), Enum.Material.Ice, nil)
		-- Blue Ocean Snapper
		addPart(m, "Fish1", Vector3.new(1.42, 0.46, 0.56), CFrame.new(-0.24, 1.34, -0.20) * CFrame.Angles(0, math.rad(14), math.rad(16)), Color3.fromRGB(68, 148, 218), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addWedge(m, "Tail1A", Vector3.new(0.12, 0.30, 0.42), CFrame.new(0.56, 1.56, -0.32) * CFrame.Angles(math.rad(-20), math.rad(-76), math.rad(16)), Color3.fromRGB(54, 126, 194), Enum.Material.SmoothPlastic)
		addWedge(m, "Tail1B", Vector3.new(0.12, 0.30, 0.42), CFrame.new(0.54, 1.42, -0.32) * CFrame.Angles(math.rad(20), math.rad(-76), math.rad(16)), Color3.fromRGB(54, 126, 194), Enum.Material.SmoothPlastic)
		addPart(m, "Eye1", Vector3.new(0.14, 0.14, 0.14), CFrame.new(-0.76, 1.24, -0.32), Color3.fromRGB(20, 24, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		-- Coral Salmon
		addPart(m, "Fish2", Vector3.new(1.26, 0.40, 0.50), CFrame.new(0.24, 1.28, 0.32) * CFrame.Angles(0, math.rad(-18), math.rad(-14)), Color3.fromRGB(244, 118, 84), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addWedge(m, "Tail2", Vector3.new(0.12, 0.36, 0.38), CFrame.new(-0.48, 1.44, 0.48) * CFrame.Angles(0, math.rad(72), 0), Color3.fromRGB(218, 96, 66), Enum.Material.SmoothPlastic)
		addPart(m, "Eye2", Vector3.new(0.13, 0.13, 0.13), CFrame.new(0.72, 1.20, 0.16), Color3.fromRGB(20, 24, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	elseif category == "Vegetable" then
		-- Layered leafy green cabbage + 2 tapered orange carrots with feathery tops + glossy ruby tomato with star calyx + golden corn cob!
		addPart(m, "CabbageCore", Vector3.new(0.78, 0.76, 0.78), CFrame.new(-0.46, 1.30, 0.14), Color3.fromRGB(118, 206, 98), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for lf = 0, 3 do
			local ang = math.rad(lf * 90 + 20)
			addPart(m, "CabLeaf_" .. lf, Vector3.new(0.46, 0.62, 0.34), CFrame.new(-0.46 + math.cos(ang) * 0.28, 1.28, 0.14 + math.sin(ang) * 0.28) * CFrame.Angles(0, -ang, 0), Color3.fromRGB(62, 168, 66), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
		-- Tapered 2-stage orange carrot + leafy green crown
		addPart(m, "CarrotTop", Vector3.new(0.56, 0.34, 0.34), CFrame.new(0.46, 1.44, -0.22) * CFrame.Angles(0, 0, math.rad(48)), Color3.fromRGB(246, 126, 28), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "CarrotTip", Vector3.new(0.48, 0.20, 0.20), CFrame.new(0.14, 1.12, -0.22) * CFrame.Angles(0, 0, math.rad(48)), Color3.fromRGB(236, 114, 22), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		for g = -1, 1 do
			addWedge(m, "CarrotFrond_" .. g, Vector3.new(0.10, 0.42, 0.18), CFrame.new(0.74, 1.78, -0.22 + g * 0.12) * CFrame.Angles(math.rad(g * 18), 0, math.rad(-24)), Color3.fromRGB(48, 158, 52), Enum.Material.SmoothPlastic)
		end
		-- Glossy red farm tomato + green star calyx + golden sweet corn
		addPart(m, "Tomato", Vector3.new(0.58, 0.50, 0.58), CFrame.new(0.42, 1.24, 0.34), Color3.fromRGB(228, 42, 42), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "TomatoStem", Vector3.new(0.24, 0.10, 0.24), CFrame.new(0.42, 1.50, 0.34), Color3.fromRGB(54, 154, 54), Enum.Material.SmoothPlastic, nil)
		addPart(m, "Corn", Vector3.new(0.78, 0.30, 0.30), CFrame.new(-0.18, 1.22, -0.44) * CFrame.Angles(0, math.rad(22), math.rad(14)), Color3.fromRGB(252, 212, 44), Enum.Material.Cobblestone, Enum.PartType.Cylinder)
	elseif category == "Fruit" then
		-- Real Fruit Crate: Glossy Red Apple + Pineapple + Curved Banana Bunch + Watermelon Wedge!
		buildRealFruitCluster(m, 0.94)
	else
		-- Real Butcher Meat Crate: Bone-In Marbled Ribeye Steak + Smoked Ham Shank with Bone + Rosemary!
		addPart(m, "Parchment", Vector3.new(1.88, 0.08, 1.46), CFrame.new(0, 0.98, 0), Color3.fromRGB(246, 238, 222), Enum.Material.SmoothPlastic, nil)
		-- Marbled Tomahawk Ribeye Steak
		local stCF = CFrame.new(-0.34, 1.28, 0.10) * CFrame.Angles(0, math.rad(14), math.rad(14))
		addPart(m, "BeefCut", Vector3.new(1.12, 0.44, 0.90), stCF, Color3.fromRGB(184, 42, 48), Enum.Material.Fabric, nil)
		addPart(m, "FatCap", Vector3.new(1.16, 0.46, 0.14), stCF * CFrame.new(0, 0, -0.42), Color3.fromRGB(248, 238, 228), Enum.Material.SmoothPlastic, nil)
		addPart(m, "Marbling1", Vector3.new(0.14, 0.47, 0.56), stCF * CFrame.new(-0.22, 0, 0.04) * CFrame.Angles(0, math.rad(28), 0), Color3.fromRGB(246, 234, 226), Enum.Material.SmoothPlastic, nil)
		addPart(m, "RibBone", Vector3.new(0.76, 0.18, 0.18), stCF * CFrame.new(-0.78, 0, 0.22), Color3.fromRGB(248, 244, 234), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		-- Glazed Smoked Ham Shank with Bone End
		local hamCF = CFrame.new(0.52, 1.32, -0.18) * CFrame.Angles(0, math.rad(-22), math.rad(-14))
		addPart(m, "Ham", Vector3.new(0.92, 0.66, 0.72), hamCF, Color3.fromRGB(204, 82, 74), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "HamBone", Vector3.new(0.56, 0.20, 0.20), hamCF * CFrame.new(0.56, 0.06, 0), Color3.fromRGB(248, 244, 234), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "HerbSprig", Vector3.new(0.46, 0.10, 0.18), CFrame.new(-0.18, 1.56, 0.06) * CFrame.Angles(0, math.rad(-20), 0), Color3.fromRGB(64, 158, 62), Enum.Material.SmoothPlastic, nil)
	end
	return m
end

-- ============================================================================
-- DEDICATED HERO CATEGORY ICONS (REAL FOOD, REAL FRUIT, REAL GUN, REAL NINJA!)
-- ============================================================================
local function buildCategoryIconModel(catId: string): (Model, "Weapon" | "Character" | "Object")
	if catId == "Food" then
		return buildDishModel("ClassicBurger"), "Object"
	elseif catId == "Fruit" then
		local m = Instance.new("Model")
		m.Name = "CategoryIcon_Fruit"
		buildRealFruitCluster(m, 0)
		return m, "Object"
	elseif catId == "Gun" then
		return buildWeaponModel("CrimsonDragonAR"), "Weapon"
	elseif catId == "Ammo" then
		return buildAmmoModel("Rifle556"), "Object"
	elseif catId == "Empire" then
		-- Gleaming 24K Royal Gold Crown with Crimson Velvet & Ruby/Sapphire Jewels
		local m = Instance.new("Model")
		m.Name = "CategoryIcon_Empire"
		local gold = Color3.fromRGB(246, 198, 48)
		local ruby = Color3.fromRGB(224, 34, 58)
		local sapphire = Color3.fromRGB(42, 138, 246)
		addPart(m, "VelvetCore", Vector3.new(1.24, 0.92, 1.24), CFrame.new(0, 0.62, 0), Color3.fromRGB(154, 24, 42), Enum.Material.Fabric, Enum.PartType.Ball)
		addPart(m, "CrownBase", Vector3.new(0.44, 1.48, 1.48), CFrame.new(0, 0.34, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "CrownRim", Vector3.new(0.14, 1.56, 1.56), CFrame.new(0, 0.14, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 224, 96), Enum.Material.Metal, Enum.PartType.Cylinder)
		for i = 0, 5 do
			local ang = math.rad(i * 60)
			addWedge(m, "Tine_" .. i, Vector3.new(0.24, 0.64, 0.28), CFrame.new(math.cos(ang) * 0.64, 0.84, math.sin(ang) * 0.64) * CFrame.Angles(0, -ang + math.rad(90), 0), gold, Enum.Material.Metal)
			addPart(m, "Orb_" .. i, Vector3.new(0.20, 0.20, 0.20), CFrame.new(math.cos(ang) * 0.66, 1.20, math.sin(ang) * 0.66), Color3.fromRGB(255, 232, 128), Enum.Material.Metal, Enum.PartType.Ball)
			addPart(m, "Gem_" .. i, Vector3.new(0.22, 0.22, 0.16), CFrame.new(math.cos(ang) * 0.74, 0.36, math.sin(ang) * 0.74) * CFrame.Angles(0, -ang + math.rad(90), 0), if i % 2 == 0 then ruby else sapphire, Enum.Material.Glass, nil)
		end
		addPart(m, "TopCross", Vector3.new(0.26, 0.42, 0.26), CFrame.new(0, 1.24, 0), gold, Enum.Material.Metal, Enum.PartType.Ball)
		return m, "Object"
	elseif catId == "Guard" then
		-- Iconic Armored Tactical Bodyguard Bust (Ballistic Helmet, Dark Shades, Suit & Crimson Tie)
		local m = Instance.new("Model")
		m.Name = "CategoryIcon_Guard"
		addPart(m, "Shoulders", Vector3.new(1.86, 0.96, 0.92), CFrame.new(0, 0.48, 0), Color3.fromRGB(26, 30, 40), Enum.Material.Fabric, nil)
		addPart(m, "Shirt", Vector3.new(0.56, 0.88, 0.16), CFrame.new(0, 0.50, -0.44), Color3.fromRGB(244, 242, 238), Enum.Material.Fabric, nil)
		addPart(m, "Tie", Vector3.new(0.20, 0.78, 0.18), CFrame.new(0, 0.46, -0.48), Color3.fromRGB(204, 34, 48), Enum.Material.Fabric, nil)
		addPart(m, "Head", Vector3.new(1.04, 1.04, 1.04), CFrame.new(0, 1.48, 0), P.SkinWarm, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Helmet", Vector3.new(1.18, 0.72, 1.22), CFrame.new(0, 1.78, 0.04), Color3.fromRGB(36, 42, 54), Enum.Material.Metal, Enum.PartType.Ball)
		addPart(m, "Shades", Vector3.new(0.96, 0.28, 0.24), CFrame.new(0, 1.50, -0.44), Color3.fromRGB(16, 20, 28), Enum.Material.Glass, nil)
		return m, "Object"
	else
		-- REAL SHINOBI NINJA BUST ("Ninja"): Sleek Black Cowl, Crimson Hachimaki Headband + Riveted Steel Clan Plate + Sweeping Tails, Fierce Warrior Eyes & Crossed Twin Back Katanas!
		local m = Instance.new("Model")
		m.Name = "CategoryIcon_Ninja"
		local cowlBlack = Color3.fromRGB(22, 25, 34)
		local maskChar = Color3.fromRGB(32, 36, 48)
		local crimson = Color3.fromRGB(218, 28, 48)
		local steel = Color3.fromRGB(198, 206, 220)
		local gold = Color3.fromRGB(238, 192, 62)

		-- Crossed Twin Back Katanas forming the iconic X behind shoulders!
		for _, sign in ipairs({ -1, 1 }) do
			local cf = CFrame.new(sign * 0.16, 1.02, 0.58) * CFrame.Angles(0, 0, math.rad(-sign * 36))
			addPart(m, "Scabbard_" .. sign, Vector3.new(0.18, 2.38, 0.20), cf, Color3.fromRGB(18, 20, 26), Enum.Material.Metal, nil)
			addPart(m, "Tsuba_" .. sign, Vector3.new(0.46, 0.12, 0.46), cf * CFrame.new(0, 0.92, 0), gold, Enum.Material.Metal, nil)
			addPart(m, "Hilt_" .. sign, Vector3.new(0.20, 0.68, 0.22), cf * CFrame.new(0, 1.32, 0), crimson, Enum.Material.Fabric, nil)
			addPart(m, "Pommel_" .. sign, Vector3.new(0.22, 0.12, 0.24), cf * CFrame.new(0, 1.68, 0), gold, Enum.Material.Metal, nil)
		end

		-- Shinobi Armored Shoulders + Crimson Scarf Collar
		addPart(m, "Shoulders", Vector3.new(1.88, 0.94, 0.92), CFrame.new(0, 0.46, 0), cowlBlack, Enum.Material.Fabric, nil)
		addPart(m, "ArmorVest", Vector3.new(1.42, 0.78, 1.00), CFrame.new(0, 0.48, 0), Color3.fromRGB(38, 44, 58), Enum.Material.Metal, nil)
		addPart(m, "ScarfCollar", Vector3.new(1.38, 0.30, 1.12), CFrame.new(0, 0.98, 0), crimson, Enum.Material.Fabric, nil)

		-- Rounded Shinobi Head + Black Balaclava Hood + Exposed Eye Slit + Lower Cloth Mask
		addPart(m, "FaceCore", Vector3.new(1.06, 1.06, 1.06), CFrame.new(0, 1.56, 0), P.SkinWarm, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "CowlCrown", Vector3.new(1.18, 0.68, 1.20), CFrame.new(0, 1.88, 0.04), cowlBlack, Enum.Material.Fabric, Enum.PartType.Ball)
		addPart(m, "CowlBack", Vector3.new(1.16, 1.12, 0.76), CFrame.new(0, 1.54, 0.26), cowlBlack, Enum.Material.Fabric, Enum.PartType.Ball)
		addPart(m, "FaceMask", Vector3.new(1.16, 0.62, 0.68), CFrame.new(0, 1.30, -0.26), maskChar, Enum.Material.Fabric, Enum.PartType.Ball)
		-- Fierce Narrowed Shinobi Eyes!
		addPart(m, "EyeL", Vector3.new(0.28, 0.12, 0.10), CFrame.new(-0.24, 1.62, -0.50) * CFrame.Angles(0, math.rad(14), math.rad(-14)), Color3.fromRGB(255, 252, 244), Enum.Material.SmoothPlastic, nil)
		addPart(m, "EyeR", Vector3.new(0.28, 0.12, 0.10), CFrame.new(0.24, 1.62, -0.50) * CFrame.Angles(0, math.rad(-14), math.rad(14)), Color3.fromRGB(255, 252, 244), Enum.Material.SmoothPlastic, nil)
		addPart(m, "IrisL", Vector3.new(0.11, 0.11, 0.11), CFrame.new(-0.23, 1.62, -0.53), crimson, Enum.Material.SmoothPlastic, nil)
		addPart(m, "IrisR", Vector3.new(0.11, 0.11, 0.11), CFrame.new(0.23, 1.62, -0.53), crimson, Enum.Material.SmoothPlastic, nil)
		-- Bright Crimson Hachimaki Headband + Riveted Steel Clan Forehead Plate + Sweeping Ribbon Tails!
		addPart(m, "Headband", Vector3.new(0.26, 1.24, 1.24), CFrame.new(0, 1.84, 0.02) * CFrame.Angles(0, 0, math.rad(90)), crimson, Enum.Material.Fabric, Enum.PartType.Cylinder)
		addPart(m, "ForeheadPlate", Vector3.new(0.76, 0.24, 0.14), CFrame.new(0, 1.84, -0.59), steel, Enum.Material.Metal, nil)
		addPart(m, "RivetL", Vector3.new(0.08, 0.08, 0.16), CFrame.new(-0.28, 1.84, -0.60), gold, Enum.Material.Metal, nil)
		addPart(m, "RivetR", Vector3.new(0.08, 0.08, 0.16), CFrame.new(0.28, 1.84, -0.60), gold, Enum.Material.Metal, nil)
		addPart(m, "TailL", Vector3.new(0.18, 0.88, 0.08), CFrame.new(-0.62, 1.56, 0.42) * CFrame.Angles(math.rad(18), 0, math.rad(-34)), crimson, Enum.Material.Fabric, nil)
		addPart(m, "TailR", Vector3.new(0.16, 0.72, 0.08), CFrame.new(0.58, 1.62, 0.44) * CFrame.Angles(math.rad(16), 0, math.rad(30)), crimson, Enum.Material.Fabric, nil)
		return m, "Object"
	end
end

-- ============================================================================
-- SCULPTED 3D EMPIRE / SYNDICATE OPERATION ICONS
-- ============================================================================
local function buildEmpireModel(code: string): (Model, "Character" | "Object" | "Weapon")
	local m = Instance.new("Model")
	m.Name = "PreviewEmpire_" .. code
	local gold = Color3.fromRGB(214, 174, 72)
	local oxblood = Color3.fromRGB(154, 34, 42)
	local steel = Color3.fromRGB(142, 148, 162)
	local darkStone = Color3.fromRGB(42, 46, 54)
	local brick = Color3.fromRGB(118, 52, 42)
	local cream = Color3.fromRGB(238, 234, 224)

	if code == "CRW" then
		local rig = MafiaVisualBuilder.BuildChefRig("PreviewCrewChef", P.DeepRed, 1.0, CFrame.new(), false)
		return freezeModelForPreview(rig.Model), "Character"
	elseif code == "WTR" then
		local rig = MafiaVisualBuilder.BuildWaiterRig("PreviewWaiter", false, 1.0, CFrame.new())
		return freezeModelForPreview(rig.Model), "Character"
	elseif code == "RDR" then
		local rig = MafiaVisualBuilder.BuildSyndicateSpecialistRig("PreviewRaider", "ApexAssassin", 1.0, CFrame.new(), true)
		return rig.Model, "Character"
	elseif code == "GRD" then
		local rig = MafiaVisualBuilder.BuildBodyguardRig("PreviewSquadGuard", "TacticalGuard", 1.0, CFrame.new(), nil, true)
		return rig.Model, "Character"
	elseif code == "SMR" then
		local rig = MafiaVisualBuilder.BuildSyndicateSpecialistRig("PreviewSamuraiMerc", "SamuraiMafia", 1.0, CFrame.new(), true)
		return rig.Model, "Character"
	elseif code == "NJA" then
		local rig = MafiaVisualBuilder.BuildSyndicateSpecialistRig("PreviewNinjaMerc", "NinjaMafia", 1.0, CFrame.new(), true)
		return rig.Model, "Character"
	elseif code == "MTR" then
		return buildMotorbikeModel(true, Color3.fromRGB(58, 152, 214)), "Object"
	elseif code == "BKE" then
		return buildMotorbikeModel(false, oxblood), "Object"
	elseif code == "SDN" then
		return buildCarModel("Sedan"), "Object"
	elseif code == "VAN" then
		return buildCarModel("Van"), "Object"
	elseif code == "CPE" then
		return buildCarModel("Coupe"), "Object"
	elseif code == "CNV" or code == "WTH" then
		return buildCarModel("Truck"), "Object"
	elseif code == "HQ" or code == "PRK" or code == "RST" or code == "RST_Noodle" or code == "RST_Steak" or code == "RST_Oyster" then
		-- Miniature Restaurant Building with Striped Awning, Warm Window & Roof Cornice
		local awningCol = if code == "PRK"
			then Color3.fromRGB(52, 138, 86)
			elseif code == "RST_Oyster" then Color3.fromRGB(52, 92, 148)
			elseif code == "RST_Steak" then gold
			else oxblood
		addPart(m, "Base", Vector3.new(2.2, 0.24, 1.8), CFrame.new(0, 0.12, 0), darkStone, Enum.Material.Slate, nil)
		addPart(m, "Building", Vector3.new(1.9, 1.45, 1.45), CFrame.new(0, 0.96, 0), if code == "HQ" then brick else Color3.fromRGB(36, 38, 46), Enum.Material.Brick, nil)
		addPart(m, "Roof", Vector3.new(2.1, 0.24, 1.65), CFrame.new(0, 1.80, 0), darkStone, Enum.Material.Metal, nil)
		addPart(m, "GoldCornice", Vector3.new(2.16, 0.12, 1.70), CFrame.new(0, 1.96, 0), gold, Enum.Material.Metal, nil)
		addPart(m, "Window", Vector3.new(1.26, 0.62, 0.12), CFrame.new(0, 0.88, -0.74), Color3.fromRGB(246, 214, 134), Enum.Material.SmoothPlastic, nil)
		addPart(m, "Awning", Vector3.new(1.76, 0.18, 0.62), CFrame.new(0, 1.38, -0.94) * CFrame.Angles(math.rad(22), 0, 0), awningCol, Enum.Material.Fabric, nil)
		return m, "Object"
	elseif code == "STV" then
		-- Commercial Dual-Burner Stainless Steel Range with Twin Skillets
		addPart(m, "OvenBody", Vector3.new(2.05, 1.42, 1.35), CFrame.new(0, 0.71, 0), steel, Enum.Material.Metal, nil)
		addPart(m, "OvenGlass", Vector3.new(1.38, 0.68, 0.10), CFrame.new(0, 0.62, -0.68), Color3.fromRGB(28, 32, 38), Enum.Material.Glass, nil)
		addPart(m, "OvenHandle", Vector3.new(1.42, 0.10, 0.16), CFrame.new(0, 1.06, -0.74), gold, Enum.Material.Metal, nil)
		addPart(m, "BurnerL", Vector3.new(0.14, 0.62, 0.62), CFrame.new(-0.48, 1.48, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(234, 96, 38), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "BurnerR", Vector3.new(0.14, 0.62, 0.62), CFrame.new(0.48, 1.48, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(234, 96, 38), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "PanL", Vector3.new(0.20, 0.74, 0.74), CFrame.new(-0.48, 1.62, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "PanR", Vector3.new(0.20, 0.74, 0.74), CFrame.new(0.48, 1.62, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
		return m, "Object"
	elseif code == "VIP" then
		-- Luxury Oxblood Velvet Booth Sofa + Walnut Table + Brass Lamp
		addPart(m, "SofaBack", Vector3.new(1.95, 1.12, 0.36), CFrame.new(0, 0.82, 0.62), oxblood, Enum.Material.Fabric, nil)
		addPart(m, "SofaSeat", Vector3.new(1.95, 0.42, 0.72), CFrame.new(0, 0.42, 0.32), oxblood, Enum.Material.Fabric, nil)
		addPart(m, "TableTop", Vector3.new(1.48, 0.16, 0.84), CFrame.new(0, 0.78, -0.46), Color3.fromRGB(118, 72, 42), Enum.Material.Wood, nil)
		addPart(m, "TableLeg", Vector3.new(0.24, 0.72, 0.24), CFrame.new(0, 0.38, -0.46), gold, Enum.Material.Metal, nil)
		addPart(m, "BrassLamp", Vector3.new(0.36, 0.48, 0.36), CFrame.new(0, 1.08, -0.46), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		return m, "Object"
	elseif code == "SPN" then
		-- 3D Lucky Spin Prize Wheel on Brass Pedestal
		addPart(m, "StandBase", Vector3.new(1.25, 0.22, 0.75), CFrame.new(0, 0.12, 0), darkStone, Enum.Material.Metal, nil)
		addPart(m, "StandPost", Vector3.new(0.24, 1.35, 0.24), CFrame.new(0, 0.80, 0.18), gold, Enum.Material.Metal, nil)
		addPart(m, "WheelRim", Vector3.new(0.26, 1.85, 1.85), CFrame.new(0, 1.42, 0) * CFrame.Angles(0, math.rad(90), 0), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "WheelFace", Vector3.new(0.30, 1.56, 1.56), CFrame.new(0, 1.42, 0) * CFrame.Angles(0, math.rad(90), 0), oxblood, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "SpokeA", Vector3.new(0.34, 1.52, 0.26), CFrame.new(0, 1.42, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(48, 162, 92), Enum.Material.SmoothPlastic, nil)
		addPart(m, "SpokeB", Vector3.new(0.34, 0.26, 1.52), CFrame.new(0, 1.42, 0) * CFrame.Angles(0, math.rad(90), 0), gold, Enum.Material.Metal, nil)
		addPart(m, "Pointer", Vector3.new(0.28, 0.38, 0.22), CFrame.new(0, 2.38, -0.10), gold, Enum.Material.Metal, nil)
		return m, "Object"
	elseif code == "DEF" then
		-- Fortified Watchtower Twin-Barrel Defense Turret
		addPart(m, "TowerBase", Vector3.new(1.45, 1.25, 1.45), CFrame.new(0, 0.62, 0), darkStone, Enum.Material.Concrete, nil)
		addPart(m, "TurretRing", Vector3.new(0.32, 1.24, 1.24), CFrame.new(0, 1.40, 0) * CFrame.Angles(0, 0, math.rad(90)), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "TurretHead", Vector3.new(0.95, 0.64, 1.15), CFrame.new(0, 1.72, 0.08), Color3.fromRGB(54, 60, 72), Enum.Material.Metal, nil)
		addPart(m, "BarrelL", Vector3.new(1.25, 0.16, 0.16), CFrame.new(-0.24, 1.74, -0.96) * CFrame.Angles(0, math.rad(90), 0), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "BarrelR", Vector3.new(1.25, 0.16, 0.16), CFrame.new(0.24, 1.74, -0.96) * CFrame.Angles(0, math.rad(90), 0), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
		return m, "Object"
	elseif code == "GAR" then
		-- Syndicate Garage: Armor Plate + Spray Can + Steel Wrench
		addPart(m, "ArmorPlate", Vector3.new(1.42, 1.48, 0.24), CFrame.new(-0.34, 0.85, 0.20), steel, Enum.Material.Metal, nil)
		addPart(m, "PaintCan", Vector3.new(1.05, 0.56, 0.56), CFrame.new(0.62, 0.56, -0.22) * CFrame.Angles(0, 0, math.rad(90)), oxblood, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "CanCap", Vector3.new(0.24, 0.42, 0.42), CFrame.new(0.62, 1.20, -0.22) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Wrench", Vector3.new(0.22, 1.42, 0.16), CFrame.new(-0.12, 0.82, -0.32) * CFrame.Angles(0, 0, math.rad(-28)), Color3.fromRGB(196, 202, 214), Enum.Material.Metal, nil)
		return m, "Object"
	elseif code == "DAY" or code == "VLT" or code == "BIZ" then
		-- Heavy Steel Syndicate Bank Vault Safe with Brass Dial & Gold Bars
		local accent = if code == "VLT" then oxblood else gold
		addPart(m, "SafeBody", Vector3.new(1.68, 1.72, 1.48), CFrame.new(0, 0.88, 0), darkStone, Enum.Material.Metal, nil)
		addPart(m, "SafeDoor", Vector3.new(1.38, 1.42, 0.16), CFrame.new(0, 0.88, -0.78), Color3.fromRGB(58, 64, 76), Enum.Material.Metal, nil)
		addPart(m, "DialWheel", Vector3.new(0.20, 0.72, 0.72), CFrame.new(0.10, 0.92, -0.92) * CFrame.Angles(0, math.rad(90), 0), accent, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "GoldBar1", Vector3.new(0.72, 0.28, 0.36), CFrame.new(-0.36, 1.88, -0.10), gold, Enum.Material.Metal, nil)
		addPart(m, "GoldBar2", Vector3.new(0.72, 0.28, 0.36), CFrame.new(0.36, 1.88, 0.12), gold, Enum.Material.Metal, nil)
		return m, "Object"
	elseif code == "PRS" or code == "EMP" or code == "RK" then
		-- 24K Imperial Gold Crown on Oxblood Velvet Cushion / Pedestal
		addPart(m, "Pedestal", Vector3.new(1.68, 0.42, 1.68), CFrame.new(0, 0.22, 0), if code == "EMP" then cream else oxblood, Enum.Material.Fabric, nil)
		addPart(m, "CrownRing", Vector3.new(0.52, 1.28, 1.28), CFrame.new(0, 0.74, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		for i = 0, 5 do
			local ang = math.rad(i * 60)
			addPart(m, "Point_" .. i, Vector3.new(0.24, 0.48, 0.24), CFrame.new(math.cos(ang) * 0.56, 1.18, math.sin(ang) * 0.56), gold, Enum.Material.Metal, nil)
		end
		addPart(m, "Ruby", Vector3.new(0.26, 0.26, 0.18), CFrame.new(0, 0.74, -0.66), oxblood, Enum.Material.Glass, nil)
		return m, "Object"
	elseif code == "FAM" then
		-- Syndicate Family Crest Shield with Gold Emblem
		addPart(m, "Shield", Vector3.new(1.52, 1.82, 0.28), CFrame.new(0, 0.92, 0), darkStone, Enum.Material.Metal, nil)
		addPart(m, "ShieldTrim", Vector3.new(1.62, 1.92, 0.18), CFrame.new(0, 0.92, 0.06), gold, Enum.Material.Metal, nil)
		addPart(m, "CrestCenter", Vector3.new(0.78, 0.78, 0.18), CFrame.new(0, 1.02, -0.16) * CFrame.Angles(0, 0, math.rad(45)), oxblood, Enum.Material.Metal, nil)
		addPart(m, "CrestCrown", Vector3.new(0.56, 0.28, 0.20), CFrame.new(0, 1.48, -0.16), gold, Enum.Material.Metal, nil)
		return m, "Object"
	elseif code == "HST" then
		-- Crimson Don Noir Skyscraper Penthouse Tower
		addPart(m, "TowerMain", Vector3.new(1.36, 2.35, 1.36), CFrame.new(0, 1.18, 0), darkStone, Enum.Material.Metal, nil)
		addPart(m, "PenthouseTop", Vector3.new(1.52, 0.48, 1.52), CFrame.new(0, 2.36, 0), oxblood, Enum.Material.Metal, nil)
		addPart(m, "GoldSpire", Vector3.new(0.20, 0.75, 0.20), CFrame.new(0, 2.92, 0), gold, Enum.Material.Metal, nil)
		for row = 0, 2 do
			addPart(m, "Win_" .. row, Vector3.new(0.96, 0.22, 0.10), CFrame.new(0, 0.64 + row * 0.54, -0.70), Color3.fromRGB(244, 212, 128), Enum.Material.SmoothPlastic, nil)
		end
		return m, "Object"
	elseif code == "BNT" then
		-- Hit Contract Crosshair Reticle & Crimson Dossier
		addPart(m, "TargetDisc", Vector3.new(0.18, 1.72, 1.72), CFrame.new(0, 0.92, 0) * CFrame.Angles(0, math.rad(90), 0), darkStone, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "OuterRing", Vector3.new(0.22, 1.38, 1.38), CFrame.new(0, 0.92, 0) * CFrame.Angles(0, math.rad(90), 0), oxblood, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Bullseye", Vector3.new(0.26, 0.56, 0.56), CFrame.new(0, 0.92, 0) * CFrame.Angles(0, math.rad(90), 0), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "CrossH", Vector3.new(0.30, 0.14, 1.98), CFrame.new(0, 0.92, 0) * CFrame.Angles(0, math.rad(90), 0), cream, Enum.Material.Metal, nil)
		addPart(m, "CrossV", Vector3.new(0.30, 1.98, 0.14), CFrame.new(0, 0.92, 0) * CFrame.Angles(0, math.rad(90), 0), cream, Enum.Material.Metal, nil)
		return m, "Object"
	elseif code == "RUN" or code == "WAR" then
		-- Contraband / Freight Supply Chest with Brass Straps
		local lidCol = if code == "WAR" then oxblood else Color3.fromRGB(134, 90, 50)
		addPart(m, "Chest", Vector3.new(1.85, 1.15, 1.25), CFrame.new(0, 0.58, 0), darkStone, Enum.Material.Metal, nil)
		addPart(m, "Lid", Vector3.new(1.92, 0.30, 1.32), CFrame.new(0, 1.26, 0), lidCol, Enum.Material.Metal, nil)
		addPart(m, "StrapL", Vector3.new(0.20, 1.48, 1.36), CFrame.new(-0.56, 0.74, 0), gold, Enum.Material.Metal, nil)
		addPart(m, "StrapR", Vector3.new(0.20, 1.48, 1.36), CFrame.new(0.56, 0.74, 0), gold, Enum.Material.Metal, nil)
		return m, "Object"
	else
		-- Syndicate Contract Dossier Briefcase with Wax Seal ("CT")
		addPart(m, "Briefcase", Vector3.new(1.88, 1.32, 0.52), CFrame.new(0, 0.72, 0), P.WornLeather, Enum.Material.Leather, nil)
		addPart(m, "Handle", Vector3.new(0.68, 0.22, 0.18), CFrame.new(0, 1.50, 0), gold, Enum.Material.Metal, nil)
		addPart(m, "Seal", Vector3.new(0.48, 0.48, 0.16), CFrame.new(0, 0.72, -0.30), oxblood, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "ClaspL", Vector3.new(0.20, 0.22, 0.58), CFrame.new(-0.58, 1.22, 0), gold, Enum.Material.Metal, nil)
		addPart(m, "ClaspR", Vector3.new(0.20, 0.22, 0.58), CFrame.new(0.58, 1.22, 0), gold, Enum.Material.Metal, nil)
		return m, "Object"
	end
end

local function buildEquipmentModel(itemId: string): Model
	local m = Instance.new("Model")
	m.Name = "PreviewEquip_" .. itemId

	if itemId == "SmokeGrenade" then
		-- 3D Tactical Smoke Grenade Canister with Pin & Smoke Puff Cap
		addPart(m, "Canister", Vector3.new(1.28, 0.62, 0.62), CFrame.new(0, 0.64, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(64, 74, 62), Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Stripe", Vector3.new(0.26, 0.66, 0.66), CFrame.new(0, 0.86, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(198, 204, 214), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "FuseCap", Vector3.new(0.38, 0.34, 0.38), CFrame.new(0, 1.42, 0), P.Obsidian, Enum.Material.Metal, nil)
		addPart(m, "PullRing", Vector3.new(0.10, 0.34, 0.34), CFrame.new(0.32, 1.44, 0), P.TarnishedBrass, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "SmokePuff", Vector3.new(0.54, 0.44, 0.54), CFrame.new(-0.18, 1.72, 0), Color3.fromRGB(204, 210, 220), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		return m
	elseif itemId == "Flashbang" then
		-- 3D M84-Style Tactical Stun Flashbang Canister with Brass Spoon & Gold Stun Ring
		addPart(m, "Body", Vector3.new(1.36, 0.58, 0.58), CFrame.new(0, 0.68, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(156, 164, 176), Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "StunBand", Vector3.new(0.24, 0.62, 0.62), CFrame.new(0, 0.92, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(224, 184, 64), Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "VentBand", Vector3.new(0.22, 0.62, 0.62), CFrame.new(0, 0.34, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "FuseHead", Vector3.new(0.34, 0.38, 0.34), CFrame.new(0, 1.48, 0), P.Charcoal, Enum.Material.Metal, nil)
		addPart(m, "SpoonLever", Vector3.new(0.12, 1.02, 0.24), CFrame.new(-0.34, 1.04, 0) * CFrame.Angles(0, 0, math.rad(-10)), P.TarnishedBrass, Enum.Material.Metal, nil)
		addPart(m, "PinRing", Vector3.new(0.08, 0.32, 0.32), CFrame.new(0.30, 1.50, 0), Color3.fromRGB(226, 230, 238), Enum.Material.Metal, Enum.PartType.Cylinder)
		return m
	elseif itemId == "C4Charge" then
		-- 3D Tactical C4 Breach Explosive Brick with Straps, Keypad Screen & Red Detonator LED
		addPart(m, "ExplosivePack", Vector3.new(1.64, 0.64, 1.06), CFrame.new(0, 0.52, 0) * CFrame.Angles(math.rad(-22), 0, 0), Color3.fromRGB(72, 82, 66), Enum.Material.SmoothPlastic, nil)
		addPart(m, "StrapL", Vector3.new(0.22, 0.68, 1.12), CFrame.new(-0.48, 0.52, 0) * CFrame.Angles(math.rad(-22), 0, 0), P.Obsidian, Enum.Material.Fabric, nil)
		addPart(m, "StrapR", Vector3.new(0.22, 0.68, 1.12), CFrame.new(0.48, 0.52, 0) * CFrame.Angles(math.rad(-22), 0, 0), P.Obsidian, Enum.Material.Fabric, nil)
		addPart(m, "KeypadBody", Vector3.new(0.68, 0.16, 0.66), CFrame.new(0, 0.88, -0.06) * CFrame.Angles(math.rad(-22), 0, 0), P.Charcoal, Enum.Material.Metal, nil)
		addPart(m, "Screen", Vector3.new(0.48, 0.10, 0.22), CFrame.new(0, 0.96, -0.22) * CFrame.Angles(math.rad(-22), 0, 0), Color3.fromRGB(54, 108, 72), Enum.Material.Glass, nil)
		addPart(m, "DetonatorLED", Vector3.new(0.20, 0.14, 0.20), CFrame.new(0.26, 0.96, 0.14) * CFrame.Angles(math.rad(-22), 0, 0), Color3.fromRGB(218, 38, 48), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Antenna", Vector3.new(0.08, 0.66, 0.08), CFrame.new(0.62, 1.08, 0.22), P.BrushedSteel, Enum.Material.Metal, nil)
		return m
	elseif itemId == "ShadowDash" then
		-- 3D Ninja Shadow Smoke Emblem: Obsidian Smoke Orb + Crossed Steel Kunai + Crimson Wrap
		addPart(m, "SmokeCore", Vector3.new(1.06, 1.06, 1.06), CFrame.new(0, 0.88, 0), Color3.fromRGB(32, 36, 46), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "SmokeCloudL", Vector3.new(0.68, 0.62, 0.68), CFrame.new(-0.56, 0.68, 0.12), Color3.fromRGB(68, 74, 88), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "SmokeCloudR", Vector3.new(0.64, 0.58, 0.64), CFrame.new(0.56, 0.72, -0.10), Color3.fromRGB(56, 62, 74), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "KunaiBlade", Vector3.new(0.22, 1.54, 0.10), CFrame.new(0, 1.12, -0.44) * CFrame.Angles(0, 0, math.rad(-32)), Color3.fromRGB(192, 200, 214), Enum.Material.Metal, nil)
		addPart(m, "KunaiWrap", Vector3.new(0.24, 0.42, 0.16), CFrame.new(-0.34, 0.54, -0.44) * CFrame.Angles(0, 0, math.rad(-32)), P.DeepRed, Enum.Material.Fabric, nil)
		addPart(m, "KunaiRing", Vector3.new(0.10, 0.34, 0.34), CFrame.new(-0.52, 0.24, -0.44) * CFrame.Angles(0, math.rad(90), 0), P.TarnishedBrass, Enum.Material.Metal, Enum.PartType.Cylinder)
		return m
	elseif itemId == "KevlarVest" or itemId == "GuardKevlarPlate" or itemId == "GuardJuggernautArmor" then
		local col = if itemId == "GuardJuggernautArmor" then Color3.fromRGB(48, 52, 60) elseif itemId == "KevlarVest" then Color3.fromRGB(36, 44, 54) else Color3.fromRGB(44, 52, 62)
		local bulk = if itemId == "GuardJuggernautArmor" then 1.22 else 1.0
		addPart(m, "Chest", Vector3.new(1.65 * bulk, 1.55 * bulk, 0.78 * bulk), CFrame.new(), col, Enum.Material.Metal, nil)
		addPart(m, "FrontPlate", Vector3.new(1.22 * bulk, 1.12 * bulk, 0.18), CFrame.new(0, 0.05, -0.44 * bulk), P.Charcoal, Enum.Material.Metal, nil)
		addPart(m, "StrapL", Vector3.new(0.32, 0.48, 0.74 * bulk), CFrame.new(-0.56 * bulk, 0.92 * bulk, 0), P.Obsidian, Enum.Material.Fabric, nil)
		addPart(m, "StrapR", Vector3.new(0.32, 0.48, 0.74 * bulk), CFrame.new(0.56 * bulk, 0.92 * bulk, 0), P.Obsidian, Enum.Material.Fabric, nil)
		return m
	elseif itemId == "Medkit" or itemId == "GuardFieldMedPack" then
		addPart(m, "Case", Vector3.new(1.55, 1.15, 0.62), CFrame.new(), P.Charcoal, Enum.Material.Metal, nil)
		addPart(m, "Handle", Vector3.new(0.62, 0.18, 0.18), CFrame.new(0, 0.68, 0), P.Obsidian, Enum.Material.Metal, nil)
		addPart(m, "CrossH", Vector3.new(0.64, 0.18, 0.08), CFrame.new(0, 0, -0.34), P.DeepRed, Enum.Material.SmoothPlastic, nil)
		addPart(m, "CrossV", Vector3.new(0.18, 0.64, 0.08), CFrame.new(0, 0, -0.34), P.DeepRed, Enum.Material.SmoothPlastic, nil)
		return m
	elseif itemId == "GuardBallisticHelmet" or itemId == "GuardTitaniumHelm" or itemId == "GuardReconVisor" then
		local col = if itemId == "GuardTitaniumHelm" then Color3.fromRGB(116, 98, 62) elseif itemId == "GuardReconVisor" then Color3.fromRGB(46, 56, 54) else Color3.fromRGB(48, 52, 60)
		addPart(m, "Dome", Vector3.new(1.42, 0.92, 1.48), CFrame.new(0, 0.15, 0), col, Enum.Material.Metal, nil)
		addPart(m, "Brim", Vector3.new(1.48, 0.18, 1.54), CFrame.new(0, -0.22, 0), P.Obsidian, Enum.Material.Metal, nil)
		if itemId == "GuardReconVisor" then
			addPart(m, "OpticL", Vector3.new(0.36, 0.28, 0.42), CFrame.new(-0.32, -0.28, -0.78), P.Gunmetal, Enum.Material.Metal, nil)
			addPart(m, "OpticR", Vector3.new(0.36, 0.28, 0.42), CFrame.new(0.32, -0.28, -0.78), P.Gunmetal, Enum.Material.Metal, nil)
		elseif itemId == "GuardTitaniumHelm" then
			addPart(m, "Visor", Vector3.new(1.36, 0.56, 0.16), CFrame.new(0, -0.34, -0.76), Color3.fromRGB(24, 28, 34), Enum.Material.Glass, nil)
		end
		return m
	elseif itemId == "GuardShadowSuit" or itemId == "GuardSyndicateSuit" or itemId == "GoldenEmperorSuit" then
		local col = if itemId == "GoldenEmperorSuit" then Color3.fromRGB(142, 118, 66) elseif itemId == "GuardSyndicateSuit" then Color3.fromRGB(72, 26, 40) else Color3.fromRGB(28, 32, 42)
		addPart(m, "Jacket", Vector3.new(1.65, 1.85, 0.72), CFrame.new(), col, Enum.Material.Fabric, nil)
		addPart(m, "Shirt", Vector3.new(0.54, 1.45, 0.14), CFrame.new(0, 0.14, -0.36), P.OffWhite, Enum.Material.Fabric, nil)
		addPart(m, "Tie", Vector3.new(0.18, 1.18, 0.16), CFrame.new(0, 0.10, -0.40), if itemId == "GoldenEmperorSuit" then P.Obsidian else P.DeepRed, Enum.Material.Fabric, nil)
		return m
	elseif itemId == "GuardTacticalSMG" then
		return buildWeaponModel("TacticalSMG")
	elseif itemId == "GuardAssaultRifle" then
		return buildWeaponModel("SyndicateCarbine")
	elseif itemId == "GuardHeavyShotgun" then
		return buildWeaponModel("AutoCombatShotgun")
	elseif itemId == "GuardPrecisionSniper" then
		return buildWeaponModel("ShadowSniper")
	elseif itemId == "GuardHoloSight" then
		addPart(m, "Base", Vector3.new(0.52, 0.24, 1.18), CFrame.new(0, -0.36, 0), P.Obsidian, Enum.Material.Metal, nil)
		addPart(m, "Hood", Vector3.new(0.68, 0.78, 0.86), CFrame.new(0, 0.12, 0), P.Gunmetal, Enum.Material.Metal, nil)
		addPart(m, "Lens", Vector3.new(0.52, 0.56, 0.10), CFrame.new(0, 0.14, -0.40), Color3.fromRGB(36, 44, 52), Enum.Material.Glass, nil)
		return m
	elseif itemId == "GuardExtendedMag" then
		addPart(m, "DrumL", Vector3.new(0.62, 0.84, 0.84), CFrame.new(-0.36, -0.18, 0) * CFrame.Angles(0, math.rad(90), 0), P.Gunmetal, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "DrumR", Vector3.new(0.62, 0.84, 0.84), CFrame.new(0.36, -0.18, 0) * CFrame.Angles(0, math.rad(90), 0), P.Gunmetal, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Tower", Vector3.new(0.34, 0.88, 0.48), CFrame.new(0, 0.56, 0), P.Obsidian, Enum.Material.Metal, nil)
		return m
	elseif itemId == "GuardSuppressor" then
		addPart(m, "Can", Vector3.new(1.85, 0.42, 0.42), CFrame.new() * CFrame.Angles(0, math.rad(90), 0), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Collar", Vector3.new(0.32, 0.48, 0.48), CFrame.new(0, 0, 0.82) * CFrame.Angles(0, math.rad(90), 0), P.BrushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		return m
	elseif itemId == "GuardFlashbangKit" then
		addPart(m, "Canister", Vector3.new(1.18, 0.52, 0.52), CFrame.new() * CFrame.Angles(0, 0, math.rad(90)), P.Gunmetal, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Band", Vector3.new(0.24, 0.56, 0.56), CFrame.new(0, 0.14, 0) * CFrame.Angles(0, 0, math.rad(90)), P.TarnishedBrass, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Fuse", Vector3.new(0.34, 0.28, 0.34), CFrame.new(0, 0.72, 0), P.Obsidian, Enum.Material.Metal, nil)
		return m
	elseif itemId == "GuardRiotPlate" then
		addPart(m, "Shield", Vector3.new(1.38, 2.15, 0.18), CFrame.new(), P.Gunmetal, Enum.Material.Metal, nil)
		addPart(m, "Viewport", Vector3.new(0.84, 0.34, 0.22), CFrame.new(0, 0.48, 0), Color3.fromRGB(36, 44, 54), Enum.Material.Glass, nil)
		return m
	elseif itemId == "DoubleEmpireVIP" then
		-- Twin Stacked 24K Gold Coin Towers & Emerald VIP Ribbon
		local gold = Color3.fromRGB(224, 182, 68)
		for i = 0, 4 do
			addPart(m, "CoinL_" .. i, Vector3.new(0.22, 0.92, 0.92), CFrame.new(-0.52, 0.14 + i * 0.26, 0.08) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		for i = 0, 6 do
			addPart(m, "CoinR_" .. i, Vector3.new(0.22, 0.92, 0.92), CFrame.new(0.48, 0.14 + i * 0.26, -0.08) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		addPart(m, "VIPTag", Vector3.new(1.22, 0.48, 0.18), CFrame.new(0, 0.72, -0.66), Color3.fromRGB(48, 152, 88), Enum.Material.Metal, nil)
		return m
	elseif itemId == "TacticalAmmoCrate" or itemId == "SyndicateArmorBundle" or itemId == "InstantEmpireCrate" then
		local lidCol = if itemId == "SyndicateArmorBundle" then P.DeepRed elseif itemId == "TacticalAmmoCrate" then P.OliveCharcoal else Color3.fromRGB(204, 162, 64)
		addPart(m, "CrateBody", Vector3.new(1.75, 1.10, 1.20), CFrame.new(0, -0.05, 0), P.Charcoal, Enum.Material.Metal, nil)
		addPart(m, "CrateLid", Vector3.new(1.82, 0.26, 1.26), CFrame.new(0, 0.58, 0), lidCol, Enum.Material.Metal, nil)
		addPart(m, "LatchL", Vector3.new(0.18, 0.38, 0.12), CFrame.new(-0.52, 0.44, -0.64), P.TarnishedBrass, Enum.Material.Metal, nil)
		addPart(m, "LatchR", Vector3.new(0.18, 0.38, 0.12), CFrame.new(0.52, 0.44, -0.64), P.TarnishedBrass, Enum.Material.Metal, nil)
		if itemId == "InstantEmpireCrate" then
			addPart(m, "GoldIngot1", Vector3.new(0.62, 0.26, 0.34), CFrame.new(-0.34, 0.84, 0), Color3.fromRGB(224, 182, 68), Enum.Material.Metal, nil)
			addPart(m, "GoldIngot2", Vector3.new(0.62, 0.26, 0.34), CFrame.new(0.36, 0.84, 0), Color3.fromRGB(224, 182, 68), Enum.Material.Metal, nil)
		end
		return m
	else
		-- Crisp 3D Gold Syndicate Medallion fallback
		addPart(m, "Coin", Vector3.new(0.28, 1.48, 1.48), CFrame.new() * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(208, 168, 72), Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Center", Vector3.new(0.34, 0.86, 0.86), CFrame.new() * CFrame.Angles(0, math.rad(90), 0), P.DeepRed, Enum.Material.Metal, Enum.PartType.Cylinder)
		return m
	end
end

local function frameCameraToModel(viewport: ViewportFrame, model: Model, viewMode: "Weapon" | "Character" | "Object" | "IconPortrait" | "IconObject" | "IconWeapon"): ()
	local cf, sz = model:GetBoundingBox()
	local center = cf.Position
	local maxDim = math.max(sz.X, sz.Y, sz.Z, 0.8)

	local cam = Instance.new("Camera")
	cam.FieldOfView = 36
	cam.Parent = viewport
	viewport.CurrentCamera = cam

	if viewMode == "Character" then
		local focus = center + Vector3.new(0, sz.Y * 0.20, 0)
		local dist = maxDim * 1.12
		local eye = focus + Vector3.new(dist * 0.34, dist * 0.08, -dist * 0.94)
		cam.CFrame = CFrame.lookAt(eye, focus)
	elseif viewMode == "IconPortrait" then
		local focus = center + Vector3.new(0, sz.Y * 0.08, 0)
		local dist = maxDim * 1.22
		local eye = focus + Vector3.new(dist * 0.24, dist * 0.12, -dist * 0.96)
		cam.CFrame = CFrame.lookAt(eye, focus)
	elseif viewMode == "IconWeapon" then
		local dist = maxDim * 1.24
		local eye = center + Vector3.new(dist * 0.96, dist * 0.16, -dist * 0.22)
		cam.CFrame = CFrame.lookAt(eye, center)
	elseif viewMode == "IconObject" then
		local dist = maxDim * 1.24
		local eye = center + Vector3.new(dist * 0.48, dist * 0.42, -dist * 0.78)
		cam.CFrame = CFrame.lookAt(eye, center)
	elseif viewMode == "Weapon" then
		local dist = maxDim * 1.38
		local eye = center + Vector3.new(dist * 0.94, dist * 0.20, -dist * 0.24)
		cam.CFrame = CFrame.lookAt(eye, center)
	else
		local dist = maxDim * 1.42
		local eye = center + Vector3.new(dist * 0.56, dist * 0.44, -dist * 0.78)
		cam.CFrame = CFrame.lookAt(eye, center)
	end
end

local function setupViewportShell(parent: Instance, size: UDim2, pos: UDim2, bgColor: Color3?, borderColor: Color3?): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview3D"
	vp.Position = pos
	vp.Size = size
	vp.BackgroundColor3 = bgColor or Color3.fromRGB(20, 22, 29)
	vp.BackgroundTransparency = 0
	vp.BorderSizePixel = 0
	vp.Ambient = Color3.fromRGB(242, 246, 255)
	vp.LightColor = Color3.fromRGB(255, 250, 240)
	vp.LightDirection = Vector3.new(-0.45, -0.70, 0.55)
	vp.Parent = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = vp

	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = borderColor or Color3.fromRGB(54, 58, 68)
	st.Thickness = 1
	st.Parent = vp

	return vp
end

-- Creates a crisp, borderless transparent 3D Category Icon (Real Food, Real Fruit, Real Gun, Real Ninja, Empire Crown, Ammo, Guard)!
function ModelPreviewHelper.CreateCategoryIcon(
	parent: Instance,
	catId: "Food" | "Fruit" | "Gun" | "Ninja" | "Empire" | "Ammo" | "Guard",
	sizePx: number,
	pos: UDim2?,
	zIndex: number?
): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Name = "CategoryIcon3D_" .. catId
	vp.Size = UDim2.fromOffset(sizePx, sizePx)
	if pos then
		vp.Position = pos
	end
	vp.BackgroundTransparency = 1
	vp.BorderSizePixel = 0
	vp.Active = false
	vp.Selectable = false
	vp.Ambient = Color3.fromRGB(248, 250, 255)
	vp.LightColor = Color3.fromRGB(255, 252, 244)
	vp.LightDirection = Vector3.new(-0.35, -0.65, 0.65)
	if zIndex then
		vp.ZIndex = zIndex
	end
	vp.Parent = parent

	local model, rawMode = buildCategoryIconModel(catId)
	local iconMode: "IconPortrait" | "IconObject" | "IconWeapon" = if catId == "Ninja" or catId == "Guard"
		then "IconPortrait"
		elseif rawMode == "Weapon" then "IconWeapon"
		else "IconObject"
	model.Parent = vp
	frameCameraToModel(vp, model, iconMode)
	return vp
end

function ModelPreviewHelper.CreatePreview(
	parent: Instance,
	kind: "Weapon" | "Ammo" | "Bodyguard" | "Equipment" | "Premium" | "Dish" | "Warehouse" | "Empire" | "CategoryIcon",
	itemId: string,
	size: UDim2,
	pos: UDim2,
	bgColor: Color3?,
	borderColor: Color3?
): ViewportFrame
	local vp = setupViewportShell(parent, size, pos, bgColor, borderColor)
	local model: Model
	local viewMode: "Weapon" | "Character" | "Object" | "IconPortrait" | "IconObject" | "IconWeapon" = "Object"

	if kind == "CategoryIcon" then
		local catModel, rawMode = buildCategoryIconModel(itemId)
		model = catModel
		viewMode = if itemId == "Ninja" or itemId == "Guard"
			then "IconPortrait"
			elseif rawMode == "Weapon" then "IconWeapon"
			else "IconObject"
	elseif kind == "Weapon" then
		model = buildWeaponModel(itemId)
		viewMode = if itemId == "GoldenSpatula" then "Object" else "Weapon"
	elseif kind == "Ammo" then
		model = buildAmmoModel(itemId)
		viewMode = "Object"
	elseif kind == "Bodyguard" then
		local rig = MafiaVisualBuilder.BuildBodyguardRig("PreviewGuard_" .. itemId, itemId, 1.0, CFrame.new(), nil, true)
		model = rig.Model
		viewMode = "Character"
	elseif kind == "Dish" then
		model = buildDishModel(itemId)
		viewMode = "Object"
	elseif kind == "Warehouse" then
		model = buildWarehouseModel(itemId)
		viewMode = "Object"
	elseif kind == "Empire" then
		model, viewMode = buildEmpireModel(itemId)
	elseif kind == "Premium" then
		if itemId == "DeliveryMotorbike" then
			model = buildMotorbikeModel(false, Color3.fromRGB(48, 168, 186))
			viewMode = "Object"
		elseif itemId == "RaiderChefSquad" then
			local rig = MafiaVisualBuilder.BuildChefRig("PreviewRaiderChef", P.DeepRed, 1.0, CFrame.new(), false)
			model = freezeModelForPreview(rig.Model)
			viewMode = "Character"
		elseif itemId == "MasterProChef" then
			local rig = MafiaVisualBuilder.BuildChefRig("PreviewMasterProChef", P.TarnishedBrass, 1.0, CFrame.new(), true)
			model = freezeModelForPreview(rig.Model)
			viewMode = "Character"
		elseif itemId == "VIPEmpireStaff" then
			local rig = MafiaVisualBuilder.BuildWaiterRig("PreviewVIPStaff", false, 1.0, CFrame.new())
			model = freezeModelForPreview(rig.Model)
			viewMode = "Character"
		elseif itemId == "SamuraiMafiaContract" then
			local rig = MafiaVisualBuilder.BuildSyndicateSpecialistRig("PreviewSamuraiPass", "SamuraiMafia", 1.0, CFrame.new(), true)
			model = rig.Model
			viewMode = "Character"
		elseif itemId == "NinjaMafiaContract" then
			local rig = MafiaVisualBuilder.BuildSyndicateSpecialistRig("PreviewNinjaPass", "NinjaMafia", 1.0, CFrame.new(), true)
			model = rig.Model
			viewMode = "Character"
		elseif itemId == "GoldenEmperorPistolPass" then
			model = buildWeaponModel("GoldenEmperorPistol")
			viewMode = "Weapon"
		elseif itemId == "CrimsonDragonARPass" then
			model = buildWeaponModel("CrimsonDragonAR")
			viewMode = "Weapon"
		elseif itemId == "BossBodyguardPass" then
			local rig = MafiaVisualBuilder.BuildBodyguardRig("PreviewBossGuard", "BossBodyguard", 1.0, CFrame.new(), nil, true)
			model = rig.Model
			viewMode = "Character"
		elseif itemId == "GoldenEmperorSuitPass" then
			model = buildEquipmentModel("GoldenEmperorSuit")
			viewMode = "Object"
		else
			model = buildEquipmentModel(itemId)
			viewMode = "Object"
		end
	else
		local gSpec = BodyguardConfig.GEAR[itemId]
		if gSpec and gSpec.Slot == "Weapon" then
			model = buildEquipmentModel(itemId)
			viewMode = "Weapon"
		else
			model = buildEquipmentModel(itemId)
			viewMode = "Object"
		end
	end

	-- Wrap custom Roblox NPC templates in a WorldModel so Shirts, Pants, BodyColors & Layered Clothing render cleanly!
	if model:GetAttribute("IsCustomNPCTemplate") == true then
		local wm = Instance.new("WorldModel")
		wm.Name = "PreviewWorld"
		wm.Parent = vp
		model.Parent = wm
	else
		model.Parent = vp
	end
	frameCameraToModel(vp, model, viewMode)
	return vp
end

-- Renders ANY live Roblox Tool (Golden Spatula, Street Pistol, Shadow Sniper, etc.) cleanly for the 1-5 Hotbar!
function ModelPreviewHelper.CreateToolPreview(parent: Instance, tool: Tool, size: UDim2, pos: UDim2): ViewportFrame
	local wid = tool:GetAttribute("WeaponId")
	if typeof(wid) == "string" then
		return ModelPreviewHelper.CreatePreview(parent, "Weapon", wid, size, pos, Color3.fromRGB(24, 26, 33))
	end
	if string.find(string.lower(tool.Name), "spatula") then
		return ModelPreviewHelper.CreatePreview(parent, "Weapon", "GoldenSpatula", size, pos, Color3.fromRGB(24, 26, 33))
	end

	local vp = setupViewportShell(parent, size, pos, Color3.fromRGB(24, 26, 33))
	local cloneModel = Instance.new("Model")
	cloneModel.Name = "ToolPreviewClone"
	for _, desc in ipairs(tool:GetDescendants()) do
		if desc:IsA("BasePart") then
			local cp = desc:Clone()
			cp.Anchored = true
			cp.CanCollide = false
			cp.CanTouch = false
			cp.CanQuery = false
			for _, sub in ipairs(cp:GetChildren()) do
				if sub:IsA("JointInstance") or sub:IsA("WeldConstraint") or sub:IsA("Script") or sub:IsA("LocalScript") then
					sub:Destroy()
				end
			end
			cp.Parent = cloneModel
		end
	end
	cloneModel.Parent = vp
	if #cloneModel:GetChildren() > 0 then
		frameCameraToModel(vp, cloneModel, "Object")
	end
	return vp
end

return ModelPreviewHelper
