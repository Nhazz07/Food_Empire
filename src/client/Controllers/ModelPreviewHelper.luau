--!strict

-- Studio-lit 3D ViewportFrame thumbnail generator for Weapons, Tools, Ammo, Bodyguards & Equipment.
-- Replaces cartoon emojis with crisp, consistent, realistic in-game 3D renders across the 1-5 Hotbar & Black Market UI.

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

local function buildWeaponModel(weaponId: string): Model
	local m = Instance.new("Model")
	m.Name = "Preview_" .. weaponId
	local darkSteel = Color3.fromRGB(64, 70, 82)
	local brushedSteel = Color3.fromRGB(156, 164, 178)
	local chrome = Color3.fromRGB(204, 210, 220)
	local gripCol = Color3.fromRGB(38, 42, 50)
	local walnut = Color3.fromRGB(118, 72, 42)
	local brass = Color3.fromRGB(204, 168, 76)
	local oxblood = Color3.fromRGB(156, 34, 44)
	local olive = Color3.fromRGB(74, 84, 70)

	if weaponId == "GoldenSpatula" then
		addPart(m, "Handle", Vector3.new(0.28, 2.4, 0.28), CFrame.new(0, -0.6, 0), walnut, Enum.Material.Wood, nil)
		addPart(m, "Neck", Vector3.new(0.20, 0.65, 0.16), CFrame.new(0, 0.88, 0), brass, Enum.Material.Metal, nil)
		addPart(m, "Blade", Vector3.new(1.15, 1.38, 0.12), CFrame.new(0, 1.72, 0), brass, Enum.Material.Metal, nil)
		return m
	end

	-- Shared pistol/rifle grip
	addPart(m, "Handle", Vector3.new(0.28, 0.92, 0.42), CFrame.new(), if weaponId == "GoldenEmperorPistol" then P.OffWhite else gripCol, Enum.Material.SmoothPlastic, nil)
	addPart(m, "TriggerGuard", Vector3.new(0.14, 0.08, 0.42), CFrame.new(0, 0.16, -0.34), darkSteel, Enum.Material.Metal, nil)

	if weaponId == "PepperShotgun" then
		addPart(m, "Stock", Vector3.new(0.32, 0.56, 1.35), CFrame.new(0, 0.28, 0.78) * CFrame.Angles(math.rad(-10), 0, 0), walnut, Enum.Material.Wood, nil)
		addPart(m, "Receiver", Vector3.new(0.36, 0.48, 1.25), CFrame.new(0, 0.52, -0.38), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Barrel", Vector3.new(2.45, 0.24, 0.24), CFrame.new(0, 0.62, -2.15) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "MagTube", Vector3.new(1.95, 0.22, 0.22), CFrame.new(0, 0.39, -1.90) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Pump", Vector3.new(0.42, 0.36, 0.92), CFrame.new(0, 0.38, -1.78), walnut, Enum.Material.Wood, nil)
	elseif weaponId == "AutoCombatShotgun" then
		addPart(m, "Stock", Vector3.new(0.34, 0.60, 1.30), CFrame.new(0, 0.34, 0.80), gripCol, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Receiver", Vector3.new(0.40, 0.54, 1.40), CFrame.new(0, 0.54, -0.42), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Optic", Vector3.new(0.28, 0.26, 0.40), CFrame.new(0, 0.99, -0.32), gripCol, Enum.Material.Metal, nil)
		addPart(m, "HeatShield", Vector3.new(0.34, 0.28, 1.95), CFrame.new(0, 0.64, -2.02), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Tube", Vector3.new(2.25, 0.26, 0.26), CFrame.new(0, 0.38, -2.05) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Pump", Vector3.new(0.46, 0.38, 1.05), CFrame.new(0, 0.38, -1.78), gripCol, Enum.Material.SmoothPlastic, nil)
	elseif weaponId == "TacticalSMG" then
		addPart(m, "Receiver", Vector3.new(0.34, 0.46, 1.35), CFrame.new(0, 0.56, -0.42), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Rail", Vector3.new(0.26, 0.10, 1.28), CFrame.new(0, 0.82, -0.42), brass, Enum.Material.Metal, nil)
		addPart(m, "Mag", Vector3.new(0.24, 1.05, 0.34), CFrame.new(0, -0.14, -0.78) * CFrame.Angles(math.rad(-14), 0, 0), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Holo", Vector3.new(0.28, 0.30, 0.42), CFrame.new(0, 0.98, -0.35), gripCol, Enum.Material.Metal, nil)
		addPart(m, "Handguard", Vector3.new(0.36, 0.38, 0.85), CFrame.new(0, 0.52, -1.48), gripCol, Enum.Material.Metal, nil)
		addPart(m, "Suppressor", Vector3.new(1.05, 0.28, 0.28), CFrame.new(0, 0.54, -2.35) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Stock", Vector3.new(0.28, 0.62, 0.16), CFrame.new(0, 0.42, 1.18), gripCol, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Strut", Vector3.new(0.16, 0.18, 0.95), CFrame.new(0, 0.52, 0.72), darkSteel, Enum.Material.Metal, nil)
	elseif weaponId == "SilencedDeagle" then
		addPart(m, "Lower", Vector3.new(0.30, 0.25, 1.62), CFrame.new(0, 0.43, -0.56), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Slide", Vector3.new(0.34, 0.36, 1.72), CFrame.new(0, 0.68, -0.58), chrome, Enum.Material.Metal, nil)
		addPart(m, "Suppressor", Vector3.new(0.95, 0.24, 0.24), CFrame.new(0, 0.66, -1.88) * CFrame.Angles(0, math.rad(90), 0), gripCol, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif weaponId == "SyndicateCarbine" then
		addPart(m, "Buffer", Vector3.new(0.95, 0.24, 0.24), CFrame.new(0, 0.56, 0.68) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Stock", Vector3.new(0.32, 0.72, 0.56), CFrame.new(0, 0.44, 1.18), olive, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Receiver", Vector3.new(0.36, 0.50, 1.48), CFrame.new(0, 0.56, -0.46), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Mag", Vector3.new(0.24, 1.10, 0.42), CFrame.new(0, -0.18, -0.84) * CFrame.Angles(math.rad(-16), 0, 0), gripCol, Enum.Material.Metal, nil)
		addPart(m, "Handguard", Vector3.new(0.38, 0.42, 1.38), CFrame.new(0, 0.56, -1.84), olive, Enum.Material.Metal, nil)
		addPart(m, "Scope", Vector3.new(0.68, 0.30, 0.30), CFrame.new(0, 0.96, -0.42) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Barrel", Vector3.new(1.15, 0.20, 0.20), CFrame.new(0, 0.58, -3.02) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif weaponId == "ShadowSniper" then
		addPart(m, "Stock", Vector3.new(0.34, 0.68, 1.45), CFrame.new(0, 0.40, 0.92), gripCol, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Chassis", Vector3.new(0.38, 0.48, 2.25), CFrame.new(0, 0.54, -0.82), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "BoxMag", Vector3.new(0.26, 0.65, 0.48), CFrame.new(0, 0.04, -0.78), brushedSteel, Enum.Material.Metal, nil)
		addPart(m, "Scope", Vector3.new(1.48, 0.26, 0.26), CFrame.new(0, 1.02, -0.62) * CFrame.Angles(0, math.rad(90), 0), gripCol, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "LensRing", Vector3.new(0.32, 0.34, 0.34), CFrame.new(0, 1.02, -1.40) * CFrame.Angles(0, math.rad(90), 0), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "LongBarrel", Vector3.new(2.25, 0.22, 0.22), CFrame.new(0, 0.60, -2.98) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Brake", Vector3.new(0.32, 0.28, 0.38), CFrame.new(0, 0.60, -4.18), darkSteel, Enum.Material.Metal, nil)
	elseif weaponId == "GoldenEmperorPistol" then
		addPart(m, "Lower", Vector3.new(0.30, 0.24, 1.48), CFrame.new(0, 0.42, -0.50), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Slide", Vector3.new(0.32, 0.34, 1.58), CFrame.new(0, 0.66, -0.52), brass, Enum.Material.Metal, nil)
		addPart(m, "Comp", Vector3.new(0.32, 0.32, 0.38), CFrame.new(0, 0.66, -1.46), brass, Enum.Material.Metal, nil)
	elseif weaponId == "CrimsonDragonAR" then
		addPart(m, "Stock", Vector3.new(0.34, 0.72, 0.58), CFrame.new(0, 0.44, 1.18), oxblood, Enum.Material.Metal, nil)
		addPart(m, "Buffer", Vector3.new(0.95, 0.24, 0.24), CFrame.new(0, 0.56, 0.68) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Receiver", Vector3.new(0.38, 0.52, 1.52), CFrame.new(0, 0.56, -0.46), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Stripe", Vector3.new(0.40, 0.16, 1.42), CFrame.new(0, 0.68, -0.48), oxblood, Enum.Material.Metal, nil)
		addPart(m, "Mag", Vector3.new(0.24, 1.24, 0.44), CFrame.new(0, -0.22, -0.84) * CFrame.Angles(math.rad(-16), 0, 0), oxblood, Enum.Material.Metal, nil)
		addPart(m, "Handguard", Vector3.new(0.40, 0.44, 1.45), CFrame.new(0, 0.56, -1.86), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "Rail", Vector3.new(0.26, 0.10, 2.55), CFrame.new(0, 0.84, -1.16), brass, Enum.Material.Metal, nil)
		addPart(m, "Barrel", Vector3.new(1.22, 0.22, 0.22), CFrame.new(0, 0.58, -3.08) * CFrame.Angles(0, math.rad(90), 0), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
	else
		-- StreetPistol
		addPart(m, "Lower", Vector3.new(0.28, 0.22, 1.38), CFrame.new(0, 0.42, -0.45), gripCol, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Slide", Vector3.new(0.30, 0.30, 1.46), CFrame.new(0, 0.64, -0.46), brushedSteel, Enum.Material.Metal, nil)
		addPart(m, "Barrel", Vector3.new(0.32, 0.18, 0.18), CFrame.new(0, 0.63, -1.26) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
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
		-- Cardboard ammo box + 3 upright 12-gauge shells with brass bases
		addPart(m, "ShellBox", Vector3.new(1.3, 0.9, 1.0), CFrame.new(-0.35, 0.45, 0.25), Color3.fromRGB(48, 32, 32), Enum.Material.Fabric, nil)
		for i = 0, 2 do
			local x = 0.48 + i * 0.34
			addPart(m, "BrassBase", Vector3.new(0.26, 0.24, 0.24), CFrame.new(x, 0.13, -0.25) * CFrame.Angles(0, 0, math.rad(90)), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
			addPart(m, "Hull", Vector3.new(0.68, 0.23, 0.23), CFrame.new(x, 0.58, -0.25) * CFrame.Angles(0, 0, math.rad(90)), redShell, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	elseif ammoId == "Sniper308" then
		-- Heavy steel ammo tin + 3 long precision .308 brass cartridges
		addPart(m, "AmmoTin", Vector3.new(1.6, 0.95, 1.0), CFrame.new(-0.35, 0.48, 0.30), steelBox, Enum.Material.Metal, nil)
		for i = 0, 2 do
			local x = 0.56 + i * 0.30
			addPart(m, "Casing", Vector3.new(0.82, 0.18, 0.18), CFrame.new(x, 0.42, -0.28) * CFrame.Angles(0, 0, math.rad(90)), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
			addPart(m, "Tip", Vector3.new(0.36, 0.15, 0.15), CFrame.new(x, 0.98, -0.28) * CFrame.Angles(0, 0, math.rad(90)), copper, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	elseif ammoId == "Rifle556" or ammoId == "SMG45" then
		-- Curved tactical magazine + upright brass cartridges beside it
		local magH = if ammoId == "Rifle556" then 1.48 else 1.62
		addPart(m, "Mag", Vector3.new(0.38, magH, 0.68), CFrame.new(-0.32, magH * 0.5, 0.10) * CFrame.Angles(math.rad(-14), 0, 0), P.Gunmetal, Enum.Material.Metal, nil)
		for i = 0, 2 do
			local x = 0.32 + i * 0.28
			addPart(m, "Case", Vector3.new(0.56, 0.16, 0.16), CFrame.new(x, 0.28, -0.18) * CFrame.Angles(0, 0, math.rad(90)), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
			addPart(m, "Bullet", Vector3.new(0.24, 0.14, 0.14), CFrame.new(x, 0.66, -0.18) * CFrame.Angles(0, 0, math.rad(90)), copper, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	else
		-- 9mm box + compact pistol magazine + rounds
		addPart(m, "Box", Vector3.new(1.2, 0.72, 0.9), CFrame.new(-0.35, 0.36, 0.20), P.Charcoal, Enum.Material.Fabric, nil)
		addPart(m, "Mag", Vector3.new(0.26, 1.15, 0.44), CFrame.new(0.45, 0.58, 0.10) * CFrame.Angles(math.rad(-10), 0, 0), P.Gunmetal, Enum.Material.Metal, nil)
		for i = 0, 1 do
			local x = 0.26 + i * 0.26
			addPart(m, "Round", Vector3.new(0.36, 0.15, 0.15), CFrame.new(x, 0.18, -0.40) * CFrame.Angles(0, 0, math.rad(90)), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
	return m
end

local function buildEquipmentModel(itemId: string): Model
	local m = Instance.new("Model")
	m.Name = "PreviewEquip_" .. itemId

	if itemId == "KevlarVest" or itemId == "GuardKevlarPlate" or itemId == "GuardJuggernautArmor" then
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
	elseif itemId == "TacticalAmmoCrate" or itemId == "SyndicateArmorBundle" or itemId == "InstantEmpireCrate" then
		local lidCol = if itemId == "SyndicateArmorBundle" then P.DeepRed elseif itemId == "TacticalAmmoCrate" then P.OliveCharcoal else P.TarnishedBrass
		addPart(m, "CrateBody", Vector3.new(1.75, 1.10, 1.20), CFrame.new(0, -0.05, 0), P.Charcoal, Enum.Material.Metal, nil)
		addPart(m, "CrateLid", Vector3.new(1.82, 0.26, 1.26), CFrame.new(0, 0.58, 0), lidCol, Enum.Material.Metal, nil)
		addPart(m, "LatchL", Vector3.new(0.18, 0.38, 0.12), CFrame.new(-0.52, 0.44, -0.64), P.TarnishedBrass, Enum.Material.Metal, nil)
		addPart(m, "LatchR", Vector3.new(0.18, 0.38, 0.12), CFrame.new(0.52, 0.44, -0.64), P.TarnishedBrass, Enum.Material.Metal, nil)
		return m
	else
		-- Generic dark steel emblem crate fallback
		addPart(m, "Emblem", Vector3.new(1.4, 1.4, 0.4), CFrame.new(), P.TarnishedBrass, Enum.Material.Metal, nil)
		return m
	end
end

local function frameCameraToModel(viewport: ViewportFrame, model: Model, viewMode: "Weapon" | "Character" | "Object"): ()
	local cf, sz = model:GetBoundingBox()
	local center = cf.Position
	local maxDim = math.max(sz.X, sz.Y, sz.Z, 0.8)

	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	cam.Parent = viewport
	viewport.CurrentCamera = cam

	if viewMode == "Character" then
		-- Framing intimidating 3/4 upper-body + head portrait facing forward-right
		local focus = center + Vector3.new(0, sz.Y * 0.22, 0)
		local dist = maxDim * 1.15
		local eye = focus + Vector3.new(dist * 0.34, dist * 0.08, -dist * 0.94)
		cam.CFrame = CFrame.lookAt(eye, focus)
	elseif viewMode == "Weapon" then
		-- Side-angled 3/4 gun profile showing silhouette clearly (barrels point along -Z)
		local dist = maxDim * 1.45
		local eye = center + Vector3.new(dist * 0.92, dist * 0.24, -dist * 0.28)
		cam.CFrame = CFrame.lookAt(eye, center)
	else
		local dist = maxDim * 1.55
		local eye = center + Vector3.new(dist * 0.58, dist * 0.38, -dist * 0.78)
		cam.CFrame = CFrame.lookAt(eye, center)
	end
end

local function setupViewportShell(parent: Instance, size: UDim2, pos: UDim2, bgColor: Color3?): (ViewportFrame, WorldModel)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview3D"
	vp.Position = pos
	vp.Size = size
	vp.BackgroundColor3 = bgColor or Color3.fromRGB(24, 26, 33)
	vp.BackgroundTransparency = 0
	vp.BorderSizePixel = 0
	vp.Ambient = Color3.fromRGB(224, 228, 238)
	vp.LightColor = Color3.fromRGB(255, 252, 246)
	vp.LightDirection = Vector3.new(-0.45, -0.65, 0.65)
	vp.Parent = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = vp

	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = Color3.fromRGB(50, 54, 64)
	st.Thickness = 1
	st.Parent = vp

	local wm = Instance.new("WorldModel")
	wm.Parent = vp
	return vp, wm
end

function ModelPreviewHelper.CreatePreview(
	parent: Instance,
	kind: "Weapon" | "Ammo" | "Bodyguard" | "Equipment" | "Premium",
	itemId: string,
	size: UDim2,
	pos: UDim2,
	bgColor: Color3?
): ViewportFrame
	local vp, wm = setupViewportShell(parent, size, pos, bgColor)
	local model: Model
	local viewMode: "Weapon" | "Character" | "Object" = "Object"

	if kind == "Weapon" then
		model = buildWeaponModel(itemId)
		viewMode = if itemId == "GoldenSpatula" then "Object" else "Weapon"
	elseif kind == "Ammo" then
		model = buildAmmoModel(itemId)
		viewMode = "Object"
	elseif kind == "Bodyguard" then
		local rig = MafiaVisualBuilder.BuildBodyguardRig("PreviewGuard_" .. itemId, itemId, 1.0, CFrame.new(), nil, true)
		model = rig.Model
		viewMode = "Character"
	elseif kind == "Premium" then
		if itemId == "GoldenEmperorPistolPass" then
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
		-- Guard gear or Player armor/medkit
		local gSpec = BodyguardConfig.GEAR[itemId]
		if gSpec and gSpec.Slot == "Weapon" then
			model = buildEquipmentModel(itemId)
			viewMode = "Weapon"
		else
			model = buildEquipmentModel(itemId)
			viewMode = "Object"
		end
	end

	model.Parent = wm
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

	-- Generic clone fallback for any other custom tool
	local vp, wm = setupViewportShell(parent, size, pos, Color3.fromRGB(24, 26, 33))
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
	cloneModel.Parent = wm
	if #cloneModel:GetChildren() > 0 then
		frameCameraToModel(vp, cloneModel, "Object")
	end
	return vp
end

return ModelPreviewHelper
