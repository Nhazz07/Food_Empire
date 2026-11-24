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

local function freezeModelForPreview(model: Model): Model
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
			desc.CastShadow = false
		elseif desc:IsA("JointInstance") or desc:IsA("WeldConstraint") or desc:IsA("BillboardGui") or desc:IsA("Humanoid") then
			desc:Destroy()
		end
	end
	return model
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
	elseif weaponId == "MafiaKnife" then
		addPart(m, "Grip", Vector3.new(0.24, 0.26, 1.15), CFrame.new(0, 0, 0.55), gripCol, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Bolster", Vector3.new(0.32, 0.34, 0.16), CFrame.new(0, 0, -0.05), brass, Enum.Material.Metal, nil)
		addPart(m, "StilettoBlade", Vector3.new(0.08, 0.24, 1.75), CFrame.new(0, 0, -1.0), chrome, Enum.Material.Metal, nil)
		addPart(m, "BladeTip", Vector3.new(0.06, 0.14, 0.42), CFrame.new(0, 0, -2.02), brushedSteel, Enum.Material.Metal, nil)
		return m
	elseif weaponId == "SamuraiKatana" then
		addPart(m, "Tsuka", Vector3.new(0.22, 0.28, 1.45), CFrame.new(0, 0, 1.15), gripCol, Enum.Material.Fabric, nil)
		addPart(m, "SilkWrap", Vector3.new(0.24, 0.30, 0.14), CFrame.new(0, 0, 1.55), oxblood, Enum.Material.Fabric, nil)
		addPart(m, "Tsuba", Vector3.new(0.56, 0.56, 0.12), CFrame.new(0, 0, 0.38), brass, Enum.Material.Metal, nil)
		addPart(m, "BladeBase", Vector3.new(0.08, 0.26, 2.65), CFrame.new(0, 0.02, -0.98), chrome, Enum.Material.Metal, nil)
		addPart(m, "BladeEdge", Vector3.new(0.06, 0.22, 1.65), CFrame.new(0, 0.12, -3.05) * CFrame.Angles(math.rad(6), 0, 0), brushedSteel, Enum.Material.Metal, nil)
		return m
	end

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
	elseif weaponId == "SyndicateTommyDrum" then
		addPart(m, "WoodStock", Vector3.new(0.32, 0.62, 1.42), CFrame.new(0, 0.34, 0.86) * CFrame.Angles(math.rad(-8), 0, 0), walnut, Enum.Material.Wood, nil)
		addPart(m, "Receiver", Vector3.new(0.38, 0.48, 1.56), CFrame.new(0, 0.58, -0.48), darkSteel, Enum.Material.Metal, nil)
		addPart(m, "DrumMag", Vector3.new(0.42, 1.05, 1.05), CFrame.new(0, 0.02, -0.82), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "DrumBrass", Vector3.new(0.46, 0.36, 0.36), CFrame.new(0, 0.02, -0.82), brass, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Foregrip", Vector3.new(0.26, 0.66, 0.30), CFrame.new(0, 0.16, -1.68), walnut, Enum.Material.Wood, nil)
		addPart(m, "FinBarrel", Vector3.new(1.65, 0.24, 0.24), CFrame.new(0, 0.60, -2.06) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif weaponId == "PhantomAssassinRifle" then
		addPart(m, "Stock", Vector3.new(0.34, 0.68, 1.48), CFrame.new(0, 0.42, 0.94), gripCol, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Chassis", Vector3.new(0.38, 0.50, 2.30), CFrame.new(0, 0.54, -0.84), Color3.fromRGB(26, 28, 34), Enum.Material.Metal, nil)
		addPart(m, "AccentStripe", Vector3.new(0.40, 0.10, 1.65), CFrame.new(0, 0.62, -0.78), oxblood, Enum.Material.Metal, nil)
		addPart(m, "Scope", Vector3.new(1.55, 0.28, 0.28), CFrame.new(0, 1.04, -0.62) * CFrame.Angles(0, math.rad(90), 0), gripCol, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "SuppressedBarrel", Vector3.new(2.55, 0.30, 0.30), CFrame.new(0, 0.60, -3.15) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
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
-- SCULPTED 3D KITCHEN DISH ICONS (Every Recipe + Active Order Cloche!)
-- ============================================================================
local function buildDishModel(dishId: string): Model
	local m = Instance.new("Model")
	m.Name = "PreviewDish_" .. dishId
	local porcelain = Color3.fromRGB(238, 236, 230)
	local darkSlate = Color3.fromRGB(38, 42, 50)
	local gold = Color3.fromRGB(214, 174, 72)
	local salmon = Color3.fromRGB(236, 118, 86)
	local lobsterRed = Color3.fromRGB(204, 52, 46)
	local steakBrown = Color3.fromRGB(112, 58, 38)
	local bunGold = Color3.fromRGB(218, 158, 82)
	local lettuce = Color3.fromRGB(84, 174, 78)
	local lemon = Color3.fromRGB(244, 212, 74)
	local woodBoard = Color3.fromRGB(128, 84, 48)

	if dishId == "ActiveOrder" then
		-- Silver Restaurant Serving Cloche & Brass Bell Knob
		addPart(m, "Plate", Vector3.new(0.18, 2.35, 2.35), CFrame.new(0, 0.10, 0) * CFrame.Angles(0, 0, math.rad(90)), porcelain, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "DomeBase", Vector3.new(0.42, 1.86, 1.86), CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(192, 198, 208), Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "DomeTop", Vector3.new(1.76, 1.18, 1.76), CFrame.new(0, 0.68, 0), Color3.fromRGB(206, 212, 222), Enum.Material.Metal, Enum.PartType.Ball)
		addPart(m, "Knob", Vector3.new(0.36, 0.36, 0.36), CFrame.new(0, 1.32, 0), gold, Enum.Material.Metal, Enum.PartType.Ball)
		return m
	elseif dishId == "TropicalSmoothie" then
		-- Tall Glass Mango-Banana Smoothie with Whipped Cream & Straw
		addPart(m, "GlassBase", Vector3.new(0.22, 0.92, 0.92), CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), porcelain, Enum.Material.Glass, Enum.PartType.Cylinder)
		addPart(m, "SmoothieCup", Vector3.new(1.65, 1.05, 1.05), CFrame.new(0, 1.02, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(246, 166, 44), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "WhipCream", Vector3.new(0.95, 0.56, 0.95), CFrame.new(0, 1.92, 0), Color3.fromRGB(248, 244, 232), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "OrangeSlice", Vector3.new(0.14, 0.66, 0.66), CFrame.new(0.52, 1.85, -0.18) * CFrame.Angles(0, math.rad(25), math.rad(20)), Color3.fromRGB(242, 134, 38), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Straw", Vector3.new(1.45, 0.14, 0.14), CFrame.new(-0.24, 2.25, 0) * CFrame.Angles(0, 0, math.rad(74)), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		return m
	elseif dishId == "ClassicBurger" then
		-- Iconic Multi-Layer Gourmet Cheeseburger on Plate
		addPart(m, "Plate", Vector3.new(0.16, 2.35, 2.35), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), porcelain, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "BottomBun", Vector3.new(0.32, 1.48, 1.48), CFrame.new(0, 0.32, 0) * CFrame.Angles(0, 0, math.rad(90)), bunGold, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Patty", Vector3.new(0.34, 1.54, 1.54), CFrame.new(0, 0.64, 0) * CFrame.Angles(0, 0, math.rad(90)), steakBrown, Enum.Material.Fabric, Enum.PartType.Cylinder)
		addPart(m, "Cheese", Vector3.new(1.46, 0.12, 1.46), CFrame.new(0, 0.84, 0) * CFrame.Angles(0, math.rad(22), 0), Color3.fromRGB(246, 198, 48), Enum.Material.SmoothPlastic, nil)
		addPart(m, "Lettuce", Vector3.new(0.16, 1.62, 1.62), CFrame.new(0, 0.96, 0) * CFrame.Angles(0, 0, math.rad(90)), lettuce, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Tomato", Vector3.new(0.14, 1.38, 1.38), CFrame.new(0, 1.09, 0) * CFrame.Angles(0, 0, math.rad(90)), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "TopBun", Vector3.new(1.52, 0.72, 1.52), CFrame.new(0, 1.34, 0), bunGold, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		return m
	elseif dishId == "FreshSushi" or dishId == "GoldenTunaSashimi" then
		-- Dark Slate Sushi Board with 3 Nigiri / Golden Tuna Slices + Wasabi
		local isGolden = (dishId == "GoldenTunaSashimi")
		local fishCol = if isGolden then Color3.fromRGB(238, 186, 58) else salmon
		addPart(m, "Board", Vector3.new(2.25, 0.22, 1.52), CFrame.new(0, 0.14, 0), darkSlate, Enum.Material.Slate, nil)
		for i = -1, 1 do
			local x = i * 0.64
			addPart(m, "Rice", Vector3.new(0.46, 0.34, 0.88), CFrame.new(x, 0.42, 0), Color3.fromRGB(246, 246, 242), Enum.Material.SmoothPlastic, nil)
			addPart(m, "Fish", Vector3.new(0.50, 0.18, 0.98), CFrame.new(x, 0.66, 0), fishCol, if isGolden then Enum.Material.Metal else Enum.Material.SmoothPlastic, nil)
			addPart(m, "Nori", Vector3.new(0.54, 0.44, 0.20), CFrame.new(x, 0.54, 0), Color3.fromRGB(24, 34, 24), Enum.Material.Fabric, nil)
		end
		addPart(m, "Wasabi", Vector3.new(0.32, 0.26, 0.32), CFrame.new(0.84, 0.36, -0.48), lettuce, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		return m
	elseif dishId == "GrilledFish" then
		-- Grilled Island Fish on Oval White Platter + Lemon
		addPart(m, "Plate", Vector3.new(0.16, 2.45, 2.45), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), porcelain, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "FishBody", Vector3.new(1.72, 0.48, 0.84), CFrame.new(-0.12, 0.42, 0), Color3.fromRGB(118, 158, 192), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "FishTail", Vector3.new(0.48, 0.16, 0.72), CFrame.new(0.84, 0.42, 0) * CFrame.Angles(0, math.rad(18), 0), Color3.fromRGB(98, 138, 172), Enum.Material.SmoothPlastic, nil)
		for i = -1, 1 do
			addPart(m, "GrillMark", Vector3.new(0.10, 0.50, 0.62), CFrame.new(-0.12 + i * 0.34, 0.44, 0), Color3.fromRGB(64, 42, 28), Enum.Material.SmoothPlastic, nil)
		end
		addPart(m, "Lemon", Vector3.new(0.24, 0.46, 0.46), CFrame.new(-0.48, 0.30, 0.66) * CFrame.Angles(0, 0, math.rad(90)), lemon, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		return m
	elseif dishId == "SizzlingSteak" then
		-- Cast-Iron Skillet with Seared Ribeye Steak & Butter Pat
		addPart(m, "Skillet", Vector3.new(0.26, 2.15, 2.15), CFrame.new(0, 0.16, 0) * CFrame.Angles(0, 0, math.rad(90)), darkSlate, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "Handle", Vector3.new(0.30, 0.18, 1.05), CFrame.new(0, 0.24, 1.48), darkSlate, Enum.Material.Metal, nil)
		addPart(m, "Steak", Vector3.new(1.42, 0.44, 1.06), CFrame.new(0, 0.46, -0.06), steakBrown, Enum.Material.Fabric, nil)
		addPart(m, "Butter", Vector3.new(0.42, 0.16, 0.42), CFrame.new(0, 0.74, -0.06) * CFrame.Angles(0, math.rad(30), 0), lemon, Enum.Material.SmoothPlastic, nil)
		addPart(m, "Herb", Vector3.new(0.38, 0.12, 0.24), CFrame.new(0.46, 0.70, 0.22), lettuce, Enum.Material.SmoothPlastic, nil)
		return m
	elseif dishId == "CrabFeast" or dishId == "KingCrabPlatter" then
		-- Bright Crimson Crab / Giant King Crab with Raised Claws
		local isKing = (dishId == "KingCrabPlatter")
		local plateCol = if isKing then darkSlate else porcelain
		local crabCol = if isKing then Color3.fromRGB(224, 62, 42) else Color3.fromRGB(212, 74, 48)
		addPart(m, "Plate", Vector3.new(0.16, 2.48, 2.48), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), plateCol, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Shell", Vector3.new(1.22, 0.56, 1.04), CFrame.new(0, 0.44, 0.10), crabCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "ClawL", Vector3.new(0.48, 0.42, 0.72), CFrame.new(-0.78, 0.56, -0.66) * CFrame.Angles(0, math.rad(28), 0), crabCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "ClawR", Vector3.new(0.48, 0.42, 0.72), CFrame.new(0.78, 0.56, -0.66) * CFrame.Angles(0, math.rad(-28), 0), crabCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for _, sx in ipairs({ -0.82, 0.82 }) do
			for _, sz in ipairs({ -0.10, 0.24, 0.54 }) do
				addPart(m, "Leg", Vector3.new(0.56, 0.14, 0.14), CFrame.new(sx, 0.30, sz), crabCol, Enum.Material.SmoothPlastic, nil)
			end
		end
		addPart(m, "Lemon", Vector3.new(0.22, 0.44, 0.44), CFrame.new(0, 0.28, -0.82) * CFrame.Angles(0, 0, math.rad(90)), lemon, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		return m
	elseif dishId == "GoldLeafLobster" then
		-- Gold-Leaf Lobster Thermidor on Marble Dish
		addPart(m, "Plate", Vector3.new(0.18, 2.50, 2.50), CFrame.new(0, 0.09, 0) * CFrame.Angles(0, 0, math.rad(90)), darkSlate, Enum.Material.Marble, Enum.PartType.Cylinder)
		addPart(m, "LobsterBody", Vector3.new(0.84, 0.54, 1.72), CFrame.new(0, 0.44, 0.06), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "GoldLeafTop", Vector3.new(0.52, 0.12, 1.18), CFrame.new(0, 0.72, 0.04), gold, Enum.Material.Metal, nil)
		addPart(m, "ClawL", Vector3.new(0.42, 0.36, 0.68), CFrame.new(-0.62, 0.46, -0.78) * CFrame.Angles(0, math.rad(22), 0), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "ClawR", Vector3.new(0.42, 0.36, 0.68), CFrame.new(0.62, 0.46, -0.78) * CFrame.Angles(0, math.rad(-22), 0), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "TailFan", Vector3.new(0.76, 0.14, 0.44), CFrame.new(0, 0.34, 0.96), lobsterRed, Enum.Material.SmoothPlastic, nil)
		return m
	elseif dishId == "SmokedCartelRibs" then
		-- Wooden Board + Glazed Rack of BBQ Ribs with White Bone Tips
		addPart(m, "Board", Vector3.new(2.25, 0.22, 1.58), CFrame.new(0, 0.12, 0), woodBoard, Enum.Material.WoodPlanks, nil)
		addPart(m, "RibRack", Vector3.new(1.76, 0.56, 0.92), CFrame.new(0, 0.50, 0.05), Color3.fromRGB(118, 46, 30), Enum.Material.SmoothPlastic, nil)
		for i = -2, 2 do
			addPart(m, "BoneTip", Vector3.new(0.14, 0.14, 0.42), CFrame.new(i * 0.36, 0.42, -0.52), porcelain, Enum.Material.SmoothPlastic, nil)
		end
		addPart(m, "Glaze", Vector3.new(1.60, 0.10, 0.68), CFrame.new(0, 0.80, 0.05), Color3.fromRGB(154, 58, 32), Enum.Material.Glass, nil)
		return m
	elseif dishId == "TruffleWagyuTartare" then
		-- Molded Ruby Wagyu Beef Tower + Golden Egg Yolk + Black Truffles
		addPart(m, "Plate", Vector3.new(0.16, 2.28, 2.28), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), darkSlate, Enum.Material.Slate, Enum.PartType.Cylinder)
		addPart(m, "Tartare", Vector3.new(0.68, 1.32, 1.32), CFrame.new(0, 0.48, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(168, 44, 48), Enum.Material.Fabric, Enum.PartType.Cylinder)
		addPart(m, "EggYolk", Vector3.new(0.56, 0.36, 0.56), CFrame.new(0, 0.92, 0), Color3.fromRGB(248, 188, 36), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "TruffleL", Vector3.new(0.22, 0.10, 0.22), CFrame.new(-0.42, 0.84, -0.26), P.Obsidian, Enum.Material.Slate, nil)
		addPart(m, "TruffleR", Vector3.new(0.22, 0.10, 0.22), CFrame.new(0.42, 0.84, 0.26), P.Obsidian, Enum.Material.Slate, nil)
		return m
	elseif dishId == "DonsMidnightTiramisu" then
		-- Layered Espresso & Mascarpone Tiramisu Cube with Cocoa Top
		addPart(m, "Plate", Vector3.new(0.16, 2.25, 2.25), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), porcelain, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Layer1", Vector3.new(1.36, 0.28, 1.36), CFrame.new(0, 0.30, 0), Color3.fromRGB(84, 52, 34), Enum.Material.Fabric, nil)
		addPart(m, "Layer2", Vector3.new(1.36, 0.32, 1.36), CFrame.new(0, 0.60, 0), Color3.fromRGB(242, 232, 212), Enum.Material.SmoothPlastic, nil)
		addPart(m, "Layer3", Vector3.new(1.36, 0.24, 1.36), CFrame.new(0, 0.88, 0), Color3.fromRGB(84, 52, 34), Enum.Material.Fabric, nil)
		addPart(m, "CocoaTop", Vector3.new(1.38, 0.18, 1.38), CFrame.new(0, 1.08, 0), Color3.fromRGB(58, 34, 22), Enum.Material.Fabric, nil)
		addPart(m, "GoldMint", Vector3.new(0.36, 0.18, 0.36), CFrame.new(0, 1.24, 0), gold, Enum.Material.Metal, nil)
		return m
	else
		-- EmperorPlatter (Royal Gold-Rimmed Feast with Mini Crown!)
		addPart(m, "GoldPlatter", Vector3.new(0.20, 2.55, 2.55), CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		addPart(m, "InnerPlate", Vector3.new(0.22, 2.15, 2.15), CFrame.new(0, 0.14, 0) * CFrame.Angles(0, 0, math.rad(90)), porcelain, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Roast", Vector3.new(0.86, 0.56, 0.72), CFrame.new(-0.42, 0.48, 0.10), steakBrown, Enum.Material.Fabric, nil)
		addPart(m, "Lobster", Vector3.new(0.76, 0.42, 0.72), CFrame.new(0.46, 0.42, -0.18), lobsterRed, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Garnish", Vector3.new(0.64, 0.28, 0.56), CFrame.new(0.18, 0.36, 0.52), lettuce, Enum.Material.SmoothPlastic, nil)
		addPart(m, "CrownBand", Vector3.new(0.34, 0.74, 0.74), CFrame.new(0, 0.96, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
		return m
	end
end

-- ============================================================================
-- SCULPTED 3D WAREHOUSE CRATE ICONS (Fish, Vegetable, Fruit, Meat)
-- ============================================================================
local function buildWarehouseModel(category: string): Model
	local m = Instance.new("Model")
	m.Name = "PreviewWarehouse_" .. category
	local crateWood = Color3.fromRGB(134, 90, 50)
	local crateTrim = Color3.fromRGB(92, 60, 34)

	-- Open-top wooden supply crate base
	addPart(m, "CrateBase", Vector3.new(1.95, 0.98, 1.55), CFrame.new(0, 0.49, 0), crateWood, Enum.Material.WoodPlanks, nil)
	addPart(m, "TrimBottom", Vector3.new(2.04, 0.16, 1.64), CFrame.new(0, 0.14, 0), crateTrim, Enum.Material.Wood, nil)
	addPart(m, "TrimTop", Vector3.new(2.04, 0.16, 1.64), CFrame.new(0, 0.94, 0), crateTrim, Enum.Material.Wood, nil)

	if category == "Fish" then
		-- Crushed ice + 2 silver-blue fish + coral shrimp
		addPart(m, "IceBed", Vector3.new(1.76, 0.22, 1.36), CFrame.new(0, 1.02, 0), Color3.fromRGB(204, 232, 248), Enum.Material.Ice, nil)
		addPart(m, "Fish1", Vector3.new(1.32, 0.44, 0.54), CFrame.new(-0.22, 1.32, -0.18) * CFrame.Angles(0, math.rad(14), math.rad(18)), Color3.fromRGB(84, 152, 212), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Tail1", Vector3.new(0.42, 0.18, 0.48), CFrame.new(0.56, 1.48, -0.28) * CFrame.Angles(0, math.rad(14), math.rad(26)), Color3.fromRGB(68, 132, 192), Enum.Material.SmoothPlastic, nil)
		addPart(m, "Fish2", Vector3.new(1.18, 0.38, 0.48), CFrame.new(0.24, 1.26, 0.30) * CFrame.Angles(0, math.rad(-20), math.rad(-14)), Color3.fromRGB(236, 122, 86), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	elseif category == "Vegetable" then
		-- Crisp green cabbage + orange carrots with green tops + potatoes
		addPart(m, "Cabbage", Vector3.new(0.88, 0.84, 0.88), CFrame.new(-0.38, 1.28, 0.12), Color3.fromRGB(82, 178, 76), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Carrot1", Vector3.new(0.95, 0.30, 0.30), CFrame.new(0.42, 1.34, -0.18) * CFrame.Angles(0, 0, math.rad(52)), Color3.fromRGB(242, 128, 36), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "CarrotLeaf", Vector3.new(0.32, 0.38, 0.32), CFrame.new(0.74, 1.78, -0.18), Color3.fromRGB(58, 148, 56), Enum.Material.SmoothPlastic, nil)
		addPart(m, "Potato", Vector3.new(0.62, 0.44, 0.48), CFrame.new(0.32, 1.18, 0.38), Color3.fromRGB(168, 130, 86), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	elseif category == "Fruit" then
		-- Bright golden mangoes, oranges & yellow bananas
		addPart(m, "Orange1", Vector3.new(0.72, 0.72, 0.72), CFrame.new(-0.46, 1.26, 0.16), Color3.fromRGB(244, 138, 32), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Mango", Vector3.new(0.86, 0.62, 0.64), CFrame.new(0.34, 1.28, -0.18) * CFrame.Angles(0, math.rad(24), math.rad(14)), Color3.fromRGB(242, 178, 42), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Banana1", Vector3.new(1.02, 0.28, 0.28), CFrame.new(0.18, 1.44, 0.34) * CFrame.Angles(0, math.rad(-18), math.rad(24)), Color3.fromRGB(248, 224, 58), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(m, "Leaf", Vector3.new(0.36, 0.10, 0.24), CFrame.new(-0.46, 1.64, 0.16), Color3.fromRGB(68, 166, 62), Enum.Material.SmoothPlastic, nil)
	else
		-- Meat: Marbled crimson beef steaks, pork roast & white butcher bone
		addPart(m, "BeefCut", Vector3.new(1.18, 0.48, 0.92), CFrame.new(-0.24, 1.24, 0.04) * CFrame.Angles(0, math.rad(14), math.rad(12)), Color3.fromRGB(178, 48, 52), Enum.Material.Fabric, nil)
		addPart(m, "Marbling", Vector3.new(0.34, 0.50, 0.26), CFrame.new(-0.34, 1.25, 0.04) * CFrame.Angles(0, math.rad(14), math.rad(12)), Color3.fromRGB(242, 232, 224), Enum.Material.SmoothPlastic, nil)
		addPart(m, "Ham", Vector3.new(0.92, 0.62, 0.68), CFrame.new(0.46, 1.28, -0.14) * CFrame.Angles(0, math.rad(-20), math.rad(-16)), Color3.fromRGB(204, 92, 86), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		addPart(m, "Bone", Vector3.new(0.56, 0.20, 0.20), CFrame.new(0.86, 1.46, -0.22) * CFrame.Angles(0, math.rad(-20), math.rad(-16)), Color3.fromRGB(244, 240, 232), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	return m
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

local function frameCameraToModel(viewport: ViewportFrame, model: Model, viewMode: "Weapon" | "Character" | "Object"): ()
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
	elseif viewMode == "Weapon" then
		local dist = maxDim * 1.42
		local eye = center + Vector3.new(dist * 0.92, dist * 0.24, -dist * 0.28)
		cam.CFrame = CFrame.lookAt(eye, center)
	else
		local dist = maxDim * 1.46
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
	vp.Ambient = Color3.fromRGB(236, 240, 248)
	vp.LightColor = Color3.fromRGB(255, 250, 242)
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

function ModelPreviewHelper.CreatePreview(
	parent: Instance,
	kind: "Weapon" | "Ammo" | "Bodyguard" | "Equipment" | "Premium" | "Dish" | "Warehouse" | "Empire",
	itemId: string,
	size: UDim2,
	pos: UDim2,
	bgColor: Color3?,
	borderColor: Color3?
): ViewportFrame
	local vp = setupViewportShell(parent, size, pos, bgColor, borderColor)
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

	-- Parent anchored model directly to ViewportFrame for immediate, deterministic first-frame rendering!
	model.Parent = vp
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
