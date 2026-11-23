--!strict

-- Shared realistic dark-mafia 3D character & equipment visual builder.
-- Used by RivalAIService, BodyguardService, and client ModelPreviewHelper (ViewportFrames)
-- so every in-world character and UI thumbnail shares identical silhouettes, proportions, and restrained tones.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local MafiaVisualBuilder = {}

-- Restrained Dark Mafia Material Palette (Zero Neon!)
MafiaVisualBuilder.PALETTE = {
	Obsidian = Color3.fromRGB(16, 17, 20),
	Charcoal = Color3.fromRGB(30, 33, 38),
	Slate = Color3.fromRGB(48, 52, 60),
	MutedGrey = Color3.fromRGB(92, 96, 104),
	DarkBrown = Color3.fromRGB(58, 41, 32),
	WornLeather = Color3.fromRGB(46, 34, 28),
	OliveCharcoal = Color3.fromRGB(42, 47, 40),
	OffWhite = Color3.fromRGB(212, 209, 202),
	DeepRed = Color3.fromRGB(116, 24, 30),
	DarkWine = Color3.fromRGB(74, 20, 26),
	Gunmetal = Color3.fromRGB(36, 40, 46),
	BrushedSteel = Color3.fromRGB(112, 118, 128),
	Walnut = Color3.fromRGB(84, 52, 34),
	TarnishedBrass = Color3.fromRGB(152, 126, 74),
	SkinWarm = Color3.fromRGB(214, 178, 148),
	SkinPale = Color3.fromRGB(204, 172, 148),
	SkinWeathered = Color3.fromRGB(186, 148, 120),
	HairDark = Color3.fromRGB(24, 22, 22),
	HairSilver = Color3.fromRGB(132, 134, 138),
}

local P = MafiaVisualBuilder.PALETTE

export type RigHandle = {
	Model: Model,
	Root: Part,
	Torso: Part,
	Head: Part,
	LeftArm: Part,
	RightArm: Part,
	LeftLeg: Part,
	RightLeg: Part,
	AddPart: (parentPart: BasePart, name: string, size: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?) -> Part,
}

-- Builds a properly proportioned realistic human figure (NO giant cartoon ball head, NO neon!)
function MafiaVisualBuilder.CreateBaseRig(
	modelName: string,
	scale: number,
	spawnCF: CFrame,
	skinCol: Color3,
	torsoCol: Color3,
	pantsCol: Color3,
	armCol: Color3,
	gloveCol: Color3?,
	shoulderWidthScale: number?,
	forPreview: boolean?
): RigHandle
	local s = scale
	local shW = shoulderWidthScale or 1.0
	local isPreview = forPreview == true
	local model = Instance.new("Model")
	model.Name = modelName

	local function rawPart(name: string, size: Vector3, col: Color3, mat: Enum.Material, shape: Enum.PartType?, collide: boolean): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * s
		p.Color = col
		p.Material = mat
		if shape then
			p.Shape = shape
		end
		p.Anchored = isPreview
		p.CanCollide = (not isPreview) and collide
		p.CanTouch = (not isPreview) and collide
		p.CanQuery = not isPreview
		p.Massless = not collide
		p.CastShadow = not isPreview
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local function weldTo(parentPart: BasePart, childPart: BasePart, relCF: CFrame): ()
		local pos = relCF.Position * s
		local rot = relCF - relCF.Position
		childPart.CFrame = parentPart.CFrame * CFrame.new(pos) * rot
		if not isPreview then
			local w = Instance.new("WeldConstraint")
			w.Part0 = parentPart
			w.Part1 = childPart
			w.Parent = childPart
		end
	end

	local function makeJoint(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): ()
		local sc0 = CFrame.new(c0.Position * s) * (c0 - c0.Position)
		local sc1 = CFrame.new(c1.Position * s) * (c1 - c1.Position)
		part1.CFrame = part0.CFrame * sc0 * sc1:Inverse()
		if not isPreview then
			local m = Instance.new("Motor6D")
			m.Name = name
			m.Part0 = part0
			m.Part1 = part1
			m.C0 = sc0
			m.C1 = sc1
			m.Parent = part0
		end
	end

	local function addPart(parentPart: BasePart, name: string, size: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
		local p = rawPart(name, size, col, mat, shape, false)
		weldTo(parentPart, p, relCF)
		return p
	end

	-- Core Invisible/Structural HumanoidRootPart + Tailored Upper/Lower Torso Silhouette
	local root = rawPart("HumanoidRootPart", Vector3.new(2.05 * shW, 2.35, 1.12), torsoCol, Enum.Material.Fabric, nil, true)
	root.CFrame = spawnCF

	-- Subtle broad shoulders & tapered waist belt for strong athletic posture
	addPart(root, "UpperChest", Vector3.new(2.16 * shW, 1.15, 1.18), CFrame.new(0, 0.52, 0), torsoCol, Enum.Material.Fabric, nil)
	addPart(root, "WaistBelt", Vector3.new(2.08 * shW, 0.24, 1.18), CFrame.new(0, -1.04, 0), P.Obsidian, Enum.Material.Leather, nil)
	addPart(root, "BeltBuckle", Vector3.new(0.32, 0.20, 0.08), CFrame.new(0, -1.04, -0.60), P.BrushedSteel, Enum.Material.Metal, nil)

	-- Realistic Roblox Head (proper human ratio 1.24x1.28x1.24 with SpecialMesh Head, NOT giant 2.0 ball!)
	local neck = addPart(root, "Neck", Vector3.new(0.56, 0.42, 0.56), CFrame.new(0, 1.32, 0), skinCol, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	neck.CFrame = root.CFrame * CFrame.new(0, 1.32 * s, 0) * CFrame.Angles(0, 0, math.rad(90))
	if not isPreview then
		local nw = neck:FindFirstChildOfClass("WeldConstraint")
		if nw then nw:Destroy() end
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = neck
		w.Parent = neck
	end

	local head = rawPart("Head", Vector3.new(1.26, 1.28, 1.26), skinCol, Enum.Material.SmoothPlastic, nil, false)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.18, 1.16, 1.18)
	headMesh.Parent = head
	makeJoint("NeckJoint", root, head, CFrame.new(0, 1.32, 0), CFrame.new(0, -0.66, 0))

	-- Intimidating facial structure: deep-set eyes, angled dark furrowed brows, stern mouth line
	for _, side in ipairs({ -1, 1 }) do
		addPart(head, "Eye", Vector3.new(0.16, 0.12, 0.08), CFrame.new(side * 0.24, 0.08, -0.60), P.Obsidian, Enum.Material.SmoothPlastic, nil)
		addPart(head, "Brow", Vector3.new(0.30, 0.08, 0.09), CFrame.new(side * 0.25, 0.22, -0.61) * CFrame.Angles(0, 0, math.rad(-14 * side)), P.HairDark, Enum.Material.SmoothPlastic, nil)
	end
	addPart(head, "SternMouth", Vector3.new(0.30, 0.05, 0.06), CFrame.new(0, -0.26, -0.60), Color3.fromRGB(122, 86, 74), Enum.Material.SmoothPlastic, nil)

	-- Articulated Arms + Leather Gloves / Hands
	local armX = 1.44 * shW
	local handCol = gloveCol or skinCol
	local handMat = if gloveCol then Enum.Material.Leather else Enum.Material.SmoothPlastic

	local leftArm = rawPart("LeftArm", Vector3.new(0.78, 2.15, 0.78), armCol, Enum.Material.Fabric, nil, false)
	makeJoint("LeftArmJoint", root, leftArm, CFrame.new(-armX, 0.96, 0), CFrame.new(0, 0.92, 0))
	addPart(leftArm, "LeftHand", Vector3.new(0.72, 0.42, 0.72), CFrame.new(0, -1.16, 0), handCol, handMat, nil)

	local rightArm = rawPart("RightArm", Vector3.new(0.78, 2.15, 0.78), armCol, Enum.Material.Fabric, nil, false)
	makeJoint("RightArmJoint", root, rightArm, CFrame.new(armX, 0.96, 0), CFrame.new(0, 0.92, 0))
	addPart(rightArm, "RightHand", Vector3.new(0.72, 0.42, 0.72), CFrame.new(0, -1.16, 0), handCol, handMat, nil)

	-- Articulated Legs + Dark Dress Shoes / Tactical Boots
	local leftLeg = rawPart("LeftLeg", Vector3.new(0.86, 2.28, 0.88), pantsCol, Enum.Material.Fabric, nil, false)
	makeJoint("LeftLegJoint", root, leftLeg, CFrame.new(-0.52 * shW, -1.18, 0), CFrame.new(0, 1.12, 0))
	addPart(leftLeg, "LeftBoot", Vector3.new(0.90, 0.46, 1.18), CFrame.new(0, -1.10, -0.14), P.Obsidian, Enum.Material.Leather, nil)

	local rightLeg = rawPart("RightLeg", Vector3.new(0.86, 2.28, 0.88), pantsCol, Enum.Material.Fabric, nil, false)
	makeJoint("RightLegJoint", root, rightLeg, CFrame.new(0.52 * shW, -1.18, 0), CFrame.new(0, 1.12, 0))
	addPart(rightLeg, "RightBoot", Vector3.new(0.90, 0.46, 1.18), CFrame.new(0, -1.10, -0.14), P.Obsidian, Enum.Material.Leather, nil)

	model.PrimaryPart = root
	return {
		Model = model,
		Root = root,
		Torso = root,
		Head = head,
		LeftArm = leftArm,
		RightArm = rightArm,
		LeftLeg = leftLeg,
		RightLeg = rightLeg,
		AddPart = addPart,
	}
end

-- Helper: Realistic matte firearm prop welded cleanly to an NPC's right hand (tags parts for weapon drop on death!)
local function attachNPCWeapon(rig: RigHandle, kind: "Crowbar" | "Pistol" | "Shotgun" | "SMG" | "Carbine" | "Sniper" | "BossRifle", overrideCol: Color3?): ()
	local rawAdd = rig.AddPart
	local function add(parentPart: BasePart, name: string, size: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
		local p = rawAdd(parentPart, name, size, relCF, col, mat, shape)
		p:SetAttribute("IsNPCWeapon", true)
		return p
	end
	local hand = rig.RightArm
	local metalCol = overrideCol or P.Gunmetal
	local steel = P.BrushedSteel

	if kind == "Crowbar" then
		-- Street weapon: dark rusted steel pry-bar / cleaver (no glow)
		add(hand, "WeaponShaft", Vector3.new(0.16, 0.16, 1.85), CFrame.new(0, -1.18, -0.92), P.Gunmetal, Enum.Material.Metal, nil)
		add(hand, "CleaverHead", Vector3.new(0.10, 0.56, 0.95), CFrame.new(0, -1.10, -1.78), steel, Enum.Material.Metal, nil)
	elseif kind == "Pistol" then
		add(hand, "Grip", Vector3.new(0.22, 0.52, 0.28), CFrame.new(0, -1.20, -0.32), P.Obsidian, Enum.Material.SmoothPlastic, nil)
		add(hand, "Slide", Vector3.new(0.24, 0.28, 1.12), CFrame.new(0, -0.98, -0.74), metalCol, Enum.Material.Metal, nil)
		add(hand, "Barrel", Vector3.new(0.24, 0.14, 0.14), CFrame.new(0, -0.98, -1.36) * CFrame.Angles(0, math.rad(90), 0), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif kind == "Shotgun" then
		add(hand, "Stock", Vector3.new(0.26, 0.42, 0.95), CFrame.new(0, -1.04, 0.18), P.Walnut, Enum.Material.Wood, nil)
		add(hand, "Receiver", Vector3.new(0.30, 0.38, 1.05), CFrame.new(0, -0.98, -0.74), metalCol, Enum.Material.Metal, nil)
		add(hand, "UpperBarrel", Vector3.new(1.75, 0.20, 0.20), CFrame.new(0, -0.90, -2.04) * CFrame.Angles(0, math.rad(90), 0), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
		add(hand, "PumpGrip", Vector3.new(0.34, 0.28, 0.72), CFrame.new(0, -1.08, -1.74), P.Walnut, Enum.Material.Wood, nil)
	elseif kind == "SMG" then
		add(hand, "Receiver", Vector3.new(0.28, 0.36, 1.18), CFrame.new(0, -1.00, -0.78), metalCol, Enum.Material.Metal, nil)
		add(hand, "CurvedMag", Vector3.new(0.18, 0.76, 0.24), CFrame.new(0, -1.46, -0.98) * CFrame.Angles(math.rad(-14), 0, 0), P.Obsidian, Enum.Material.Metal, nil)
		add(hand, "Suppressor", Vector3.new(0.75, 0.20, 0.20), CFrame.new(0, -0.98, -1.70) * CFrame.Angles(0, math.rad(90), 0), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif kind == "Sniper" then
		add(hand, "Stock", Vector3.new(0.26, 0.46, 1.02), CFrame.new(0, -1.02, 0.18), P.Obsidian, Enum.Material.SmoothPlastic, nil)
		add(hand, "Chassis", Vector3.new(0.30, 0.36, 1.65), CFrame.new(0, -0.98, -1.05), metalCol, Enum.Material.Metal, nil)
		add(hand, "Scope", Vector3.new(1.05, 0.20, 0.20), CFrame.new(0, -0.68, -0.96) * CFrame.Angles(0, math.rad(90), 0), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
		add(hand, "LongBarrel", Vector3.new(1.95, 0.16, 0.16), CFrame.new(0, -0.96, -2.72) * CFrame.Angles(0, math.rad(90), 0), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif kind == "BossRifle" then
		add(hand, "WalnutStock", Vector3.new(0.28, 0.48, 1.05), CFrame.new(0, -1.02, 0.18), P.Walnut, Enum.Material.Wood, nil)
		add(hand, "Receiver", Vector3.new(0.34, 0.42, 1.48), CFrame.new(0, -0.98, -0.96), P.Obsidian, Enum.Material.Metal, nil)
		add(hand, "BrassTrim", Vector3.new(0.36, 0.09, 1.02), CFrame.new(0, -0.96, -0.96), P.TarnishedBrass, Enum.Material.Metal, nil)
		add(hand, "Mag", Vector3.new(0.20, 0.78, 0.30), CFrame.new(0, -1.48, -1.16) * CFrame.Angles(math.rad(-14), 0, 0), P.Gunmetal, Enum.Material.Metal, nil)
		add(hand, "Barrel", Vector3.new(1.25, 0.20, 0.20), CFrame.new(0, -0.96, -2.26) * CFrame.Angles(0, math.rad(90), 0), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
	else
		-- Carbine
		add(hand, "Stock", Vector3.new(0.26, 0.46, 0.85), CFrame.new(0, -1.02, 0.15), P.Obsidian, Enum.Material.SmoothPlastic, nil)
		add(hand, "Receiver", Vector3.new(0.30, 0.38, 1.32), CFrame.new(0, -0.98, -0.88), metalCol, Enum.Material.Metal, nil)
		add(hand, "Mag", Vector3.new(0.20, 0.72, 0.28), CFrame.new(0, -1.44, -1.08) * CFrame.Angles(math.rad(-14), 0, 0), P.Obsidian, Enum.Material.Metal, nil)
		add(hand, "Barrel", Vector3.new(1.10, 0.18, 0.18), CFrame.new(0, -0.96, -2.02) * CFrame.Angles(0, math.rad(90), 0), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
end

-- ============================================================================
-- 1. RIVAL FACTION CHARACTER MODELS (5 Distinct Criminal-to-Don Silhouettes)
-- ============================================================================
function MafiaVisualBuilder.BuildRivalRig(
	modelName: string,
	factionId: string,
	isEscort: boolean,
	scale: number,
	spawnCF: CFrame,
	forPreview: boolean?
): RigHandle
	if factionId == "StreetSkilletGang" then
		-- EASY: Ordinary street thugs — worn charcoal hoodie, tilted knit beanie, rolled sleeves, crowbar/cleaver
		local rig = MafiaVisualBuilder.CreateBaseRig(
			modelName, scale, spawnCF, P.SkinWarm,
			Color3.fromRGB(48, 50, 54), Color3.fromRGB(34, 36, 40),
			Color3.fromRGB(48, 50, 54), nil, 0.98, forPreview
		)
		local add = rig.AddPart
		-- Hood collar bunched behind neck + hoodie pocket & strings
		add(rig.Root, "HoodCollar", Vector3.new(1.55, 0.42, 0.82), CFrame.new(0, 1.15, 0.36), Color3.fromRGB(40, 42, 46), Enum.Material.Fabric, nil)
		add(rig.Root, "HoodiePocket", Vector3.new(1.48, 0.62, 0.16), CFrame.new(0, -0.52, -0.60), Color3.fromRGB(40, 42, 46), Enum.Material.Fabric, nil)
		add(rig.Root, "DrawstringL", Vector3.new(0.06, 0.52, 0.06), CFrame.new(-0.24, 0.68, -0.61), P.MutedGrey, Enum.Material.Fabric, nil)
		add(rig.Root, "DrawstringR", Vector3.new(0.06, 0.52, 0.06), CFrame.new(0.24, 0.68, -0.61), P.MutedGrey, Enum.Material.Fabric, nil)
		-- Tilted dark knit street beanie + stubble + cheek scar
		add(rig.Head, "KnitBeanie", Vector3.new(1.36, 0.62, 1.38), CFrame.new(0, 0.52, 0.08) * CFrame.Angles(math.rad(-10), 0, math.rad(4)), Color3.fromRGB(32, 30, 30), Enum.Material.Fabric, nil)
		add(rig.Head, "BeanieCuff", Vector3.new(1.42, 0.24, 1.42), CFrame.new(0, 0.32, 0.04) * CFrame.Angles(math.rad(-10), 0, math.rad(4)), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Head, "CheekScar", Vector3.new(0.05, 0.28, 0.05), CFrame.new(-0.32, -0.06, -0.62) * CFrame.Angles(0, 0, math.rad(18)), Color3.fromRGB(134, 62, 58), Enum.Material.SmoothPlastic, nil)
		attachNPCWeapon(rig, "Crowbar", nil)
		return rig

	elseif factionId == "HarborHookCartel" then
		-- MEDIUM: Dockside gang — weathered dark brown leather jacket over black shirt, flat dock cap, shades, pistol
		local rig = MafiaVisualBuilder.CreateBaseRig(
			modelName, scale, spawnCF, P.SkinWeathered,
			P.DarkBrown, Color3.fromRGB(28, 30, 34),
			P.DarkBrown, P.Obsidian, 1.02, forPreview
		)
		local add = rig.AddPart
		-- Open leather jacket front exposing dark charcoal henley + upright leather collar + waist holster
		add(rig.Root, "InnerShirt", Vector3.new(0.76, 1.85, 0.14), CFrame.new(0, 0.05, -0.58), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Root, "JacketCollarL", Vector3.new(0.42, 0.62, 0.22), CFrame.new(-0.56, 0.92, -0.56) * CFrame.Angles(0, 0, math.rad(-18)), P.WornLeather, Enum.Material.Leather, nil)
		add(rig.Root, "JacketCollarR", Vector3.new(0.42, 0.62, 0.22), CFrame.new(0.56, 0.92, -0.56) * CFrame.Angles(0, 0, math.rad(18)), P.WornLeather, Enum.Material.Leather, nil)
		add(rig.Root, "SidePouch", Vector3.new(0.28, 0.56, 0.44), CFrame.new(-1.12, -0.82, 0.05), P.WornLeather, Enum.Material.Leather, nil)
		-- Flat dark dock cap + dark shades + goatee stubble
		add(rig.Head, "DockCapTop", Vector3.new(1.38, 0.42, 1.48), CFrame.new(0, 0.54, 0.04), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Head, "DockCapBrim", Vector3.new(1.24, 0.10, 0.58), CFrame.new(0, 0.36, -0.78) * CFrame.Angles(math.rad(8), 0, 0), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Head, "Shades", Vector3.new(1.16, 0.26, 0.16), CFrame.new(0, 0.08, -0.62), P.Obsidian, Enum.Material.SmoothPlastic, nil)
		add(rig.Head, "JawStubble", Vector3.new(0.84, 0.32, 0.34), CFrame.new(0, -0.34, -0.48), Color3.fromRGB(48, 38, 34), Enum.Material.Fabric, nil)
		attachNPCWeapon(rig, "Pistol", P.Gunmetal)
		return rig

	elseif factionId == "IronCleaverSyndicate" then
		-- HARD: Experienced syndicate enforcers — dark charcoal chest rig, half-face gaiter mask, tactical cap, SMG
		local rig = MafiaVisualBuilder.CreateBaseRig(
			modelName, scale, spawnCF, P.SkinWarm,
			P.Slate, P.Charcoal,
			P.Slate, P.Obsidian, 1.06, forPreview
		)
		local add = rig.AddPart
		-- Matte-black tactical chest rig + 3 mag pouches + dark red shoulder patch (restrained!)
		add(rig.Root, "ChestRig", Vector3.new(1.96, 1.38, 1.30), CFrame.new(0, 0.14, 0), P.Obsidian, Enum.Material.Fabric, nil)
		for _, mx in ipairs({ -0.52, 0, 0.52 }) do
			add(rig.Root, "MagPouch", Vector3.new(0.36, 0.58, 0.24), CFrame.new(mx, -0.18, -0.72), P.Charcoal, Enum.Material.Fabric, nil)
		end
		add(rig.LeftArm, "SyndicateBand", Vector3.new(0.84, 0.22, 0.84), CFrame.new(0, 0.42, 0), P.DeepRed, Enum.Material.Fabric, nil)
		-- Half-face dark cloth gaiter mask + dark patrol cap + comms earpiece
		add(rig.Head, "FaceGaiter", Vector3.new(1.30, 0.58, 1.28), CFrame.new(0, -0.26, -0.04), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Head, "TacCap", Vector3.new(1.36, 0.44, 1.38), CFrame.new(0, 0.54, 0.02), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Head, "TacBrim", Vector3.new(1.18, 0.09, 0.58), CFrame.new(0, 0.34, -0.76) * CFrame.Angles(math.rad(6), 0, 0), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Head, "CommsCup", Vector3.new(0.18, 0.34, 0.30), CFrame.new(-0.70, 0.04, 0), P.Gunmetal, Enum.Material.Metal, nil)
		attachNPCWeapon(rig, "SMG", P.Gunmetal)
		return rig

	elseif factionId == "ObsidianKnifeOrder" then
		-- ELITE: Cold professional hitmen — long tailored obsidian overcoat with draped coat tails, high collar, aviators, carbine
		local rig = MafiaVisualBuilder.CreateBaseRig(
			modelName, scale, spawnCF, P.SkinPale,
			P.Obsidian, P.Obsidian,
			P.Obsidian, P.Obsidian, 1.05, forPreview
		)
		local add = rig.AddPart
		-- Draped long tailored overcoat skirt + upturned collar + deep oxblood dress shirt/tie peek
		add(rig.Root, "ShirtPeek", Vector3.new(0.62, 1.38, 0.14), CFrame.new(0, 0.42, -0.58), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Root, "OxbloodTie", Vector3.new(0.22, 1.15, 0.16), CFrame.new(0, 0.36, -0.62), P.DeepRed, Enum.Material.Fabric, nil)
		add(rig.Root, "HighCollarBack", Vector3.new(1.48, 0.54, 0.36), CFrame.new(0, 1.22, 0.44), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Root, "LapelL", Vector3.new(0.36, 1.15, 0.14), CFrame.new(-0.46, 0.48, -0.60) * CFrame.Angles(0, 0, math.rad(-14)), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Root, "LapelR", Vector3.new(0.36, 1.15, 0.14), CFrame.new(0.46, 0.48, -0.60) * CFrame.Angles(0, 0, math.rad(14)), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Root, "CoatTailBack", Vector3.new(2.14, 1.62, 0.24), CFrame.new(0, -1.78, 0.48), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Root, "CoatTailL", Vector3.new(0.22, 1.56, 1.04), CFrame.new(-1.02, -1.75, 0.04), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Root, "CoatTailR", Vector3.new(0.22, 1.56, 1.04), CFrame.new(1.02, -1.75, 0.04), P.Obsidian, Enum.Material.Fabric, nil)
		-- Slicked-back dark hair + narrow dark aviators
		add(rig.Head, "SlickHairTop", Vector3.new(1.32, 0.36, 1.38), CFrame.new(0, 0.56, 0.06), P.HairDark, Enum.Material.SmoothPlastic, nil)
		add(rig.Head, "SlickHairBack", Vector3.new(1.30, 0.72, 0.42), CFrame.new(0, 0.22, 0.52), P.HairDark, Enum.Material.SmoothPlastic, nil)
		add(rig.Head, "Aviators", Vector3.new(1.18, 0.28, 0.14), CFrame.new(0, 0.08, -0.63), P.Obsidian, Enum.Material.Glass, nil)
		attachNPCWeapon(rig, "Carbine", P.Obsidian)
		return rig

	else
		-- BOSS FACTION: Crimson Don Empire (The Crimson Don Boss OR his 2 Dedicated Enforcers)
		if isEscort then
			-- Don's Heavy Enforcer: structured dark charcoal greatcoat, dark fedora, black gloves, SMG
			local rig = MafiaVisualBuilder.CreateBaseRig(
				modelName, scale, spawnCF, P.SkinWeathered,
				P.Charcoal, P.Obsidian,
				P.Charcoal, P.Obsidian, 1.08, forPreview
			)
			local add = rig.AddPart
			add(rig.Root, "Shirt", Vector3.new(0.68, 1.55, 0.14), CFrame.new(0, 0.30, -0.58), P.OffWhite, Enum.Material.Fabric, nil)
			add(rig.Root, "Tie", Vector3.new(0.22, 1.25, 0.16), CFrame.new(0, 0.25, -0.62), P.DarkWine, Enum.Material.Fabric, nil)
			add(rig.Root, "CoatSkirt", Vector3.new(2.24, 1.28, 0.24), CFrame.new(0, -1.62, 0.48), P.Charcoal, Enum.Material.Fabric, nil)
			add(rig.Head, "Shades", Vector3.new(1.18, 0.26, 0.14), CFrame.new(0, 0.08, -0.63), P.Obsidian, Enum.Material.Glass, nil)
			add(rig.Head, "FedoraBrim", Vector3.new(0.14, 2.05, 2.05), CFrame.new(0, 0.56, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Fabric, Enum.PartType.Cylinder)
			add(rig.Head, "FedoraCrown", Vector3.new(0.62, 1.38, 1.38), CFrame.new(0, 0.88, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Fabric, Enum.PartType.Cylinder)
			add(rig.Head, "FedoraBand", Vector3.new(0.14, 1.44, 1.44), CFrame.new(0, 0.66, 0) * CFrame.Angles(0, 0, math.rad(90)), P.DeepRed, Enum.Material.Fabric, Enum.PartType.Cylinder)
			attachNPCWeapon(rig, "SMG", P.Gunmetal)
			return rig
		else
			-- THE CRIMSON DON: Commanding presence without fantasy glow!
			-- Broad double-breasted charcoal suit + heavy obsidian mafia greatcoat draped over shoulders + deep fur collar + classic fedora + silver beard!
			local rig = MafiaVisualBuilder.CreateBaseRig(
				modelName, scale, spawnCF, P.SkinWeathered,
				P.Charcoal, P.Obsidian,
				P.Obsidian, P.Obsidian, 1.14, forPreview
			)
			local add = rig.AddPart
			-- Tailored suit vest, crisp dress shirt, deep oxblood silk tie & gold tie clip
			add(rig.Root, "DressShirt", Vector3.new(0.76, 1.68, 0.14), CFrame.new(0, 0.34, -0.58), P.OffWhite, Enum.Material.Fabric, nil)
			add(rig.Root, "SilkTie", Vector3.new(0.26, 1.38, 0.16), CFrame.new(0, 0.28, -0.62), P.DeepRed, Enum.Material.Fabric, nil)
			add(rig.Root, "TieClip", Vector3.new(0.30, 0.07, 0.08), CFrame.new(0, 0.18, -0.67), P.TarnishedBrass, Enum.Material.Metal, nil)
			-- Heavy draped Mafia Trench Coat shoulders, dark fur collar & long sweeping coat tails
			add(rig.Root, "FurCollar", Vector3.new(2.42, 0.48, 1.24), CFrame.new(0, 1.14, 0.10), Color3.fromRGB(24, 20, 22), Enum.Material.Fabric, nil)
			add(rig.Root, "CoatShoulderL", Vector3.new(0.78, 0.42, 1.26), CFrame.new(-1.38, 1.02, 0), P.Obsidian, Enum.Material.Fabric, nil)
			add(rig.Root, "CoatShoulderR", Vector3.new(0.78, 0.42, 1.26), CFrame.new(1.38, 1.02, 0), P.Obsidian, Enum.Material.Fabric, nil)
			add(rig.Root, "CoatTailBack", Vector3.new(2.48, 1.92, 0.28), CFrame.new(0, -1.88, 0.52), P.Obsidian, Enum.Material.Fabric, nil)
			add(rig.Root, "CoatTailL", Vector3.new(0.24, 1.84, 1.12), CFrame.new(-1.18, -1.84, 0.04), P.Obsidian, Enum.Material.Fabric, nil)
			add(rig.Root, "CoatTailR", Vector3.new(0.24, 1.84, 1.12), CFrame.new(1.18, -1.84, 0.04), P.Obsidian, Enum.Material.Fabric, nil)
			add(rig.Root, "RedPocketSq", Vector3.new(0.24, 0.14, 0.08), CFrame.new(0.68, 0.64, -0.62), P.DeepRed, Enum.Material.Fabric, nil)
			-- Weathered silver beard, intimidating dark brows & classic Mafia Fedora with deep red silk band
			add(rig.Head, "SilverBeard", Vector3.new(1.06, 0.42, 0.44), CFrame.new(0, -0.40, -0.44), P.HairSilver, Enum.Material.Fabric, nil)
			add(rig.Head, "Mustache", Vector3.new(0.68, 0.14, 0.14), CFrame.new(0, -0.18, -0.62), P.HairSilver, Enum.Material.Fabric, nil)
			add(rig.Head, "DonFedoraBrim", Vector3.new(0.14, 2.28, 2.28), CFrame.new(0, 0.58, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Fabric, Enum.PartType.Cylinder)
			add(rig.Head, "DonFedoraCrown", Vector3.new(0.70, 1.46, 1.46), CFrame.new(0, 0.94, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Fabric, Enum.PartType.Cylinder)
			add(rig.Head, "DonFedoraRibbon", Vector3.new(0.16, 1.52, 1.52), CFrame.new(0, 0.68, 0) * CFrame.Angles(0, 0, math.rad(90)), P.DeepRed, Enum.Material.Fabric, Enum.PartType.Cylinder)
			attachNPCWeapon(rig, "BossRifle", P.Obsidian)
			return rig
		end
	end
end

-- ============================================================================
-- 2. PLAYER BODYGUARD MODELS (7 Distinct Professional Enforcer Silhouettes)
-- ============================================================================
export type BodyguardVisualOverrides = {
	OutfitColor: Color3?,
	ArmorColor: Color3?,
	HelmetColor: Color3?,
	WeaponColor: Color3?,
	HasRiotPlate: boolean?,
	IsRanged: boolean?,
}

function MafiaVisualBuilder.BuildBodyguardRig(
	modelName: string,
	classId: string,
	scale: number,
	spawnCF: CFrame,
	overrides: BodyguardVisualOverrides?,
	forPreview: boolean?
): RigHandle
	local ov = overrides or {}

	if classId == "HeavyGuard" then
		-- HEAVY GUARD: Broad armored breacher silhouette — matte plate carrier, layered shoulder pauldrons, riot helmet w/ tinted shield visor, pump shotgun + steel riot shield
		local suit = ov.OutfitColor or P.Charcoal
		local armor = ov.ArmorColor or Color3.fromRGB(36, 40, 46)
		local helm = ov.HelmetColor or P.Obsidian
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWarm, suit, P.Obsidian, suit, P.Obsidian, 1.18, forPreview)
		local add = rig.AddPart
		-- Layered matte ceramic plate carrier & collar + shoulder pads
		add(rig.Root, "HeavyCarrier", Vector3.new(2.54, 1.72, 1.52), CFrame.new(0, 0.14, 0), armor, Enum.Material.Metal, nil)
		add(rig.Root, "ThroatGuard", Vector3.new(1.38, 0.36, 1.12), CFrame.new(0, 1.14, 0), armor, Enum.Material.Metal, nil)
		add(rig.Root, "GroinPlate", Vector3.new(1.24, 0.68, 0.24), CFrame.new(0, -1.24, -0.68), armor, Enum.Material.Metal, nil)
		add(rig.LeftArm, "PauldronL", Vector3.new(0.96, 0.78, 0.96), CFrame.new(-0.08, 0.68, 0), armor, Enum.Material.Metal, nil)
		add(rig.RightArm, "PauldronR", Vector3.new(0.96, 0.78, 0.96), CFrame.new(0.08, 0.68, 0), armor, Enum.Material.Metal, nil)
		-- Ballistic Riot Helmet + smoked polycarbonate visor
		add(rig.Head, "RiotHelm", Vector3.new(1.48, 0.84, 1.52), CFrame.new(0, 0.44, 0.04), helm, Enum.Material.Metal, nil)
		add(rig.Head, "RiotVisor", Vector3.new(1.38, 0.48, 0.14), CFrame.new(0, 0.06, -0.74), Color3.fromRGB(22, 26, 32), Enum.Material.Glass, nil)
		-- Matte steel ballistic shield on left forearm
		add(rig.LeftArm, "BallisticShield", Vector3.new(0.24, 2.38, 1.54), CFrame.new(-0.56, -0.24, -0.20), P.Gunmetal, Enum.Material.Metal, nil)
		add(rig.LeftArm, "ShieldViewport", Vector3.new(0.28, 0.32, 0.82), CFrame.new(-0.56, 0.44, -0.20), Color3.fromRGB(36, 44, 52), Enum.Material.Glass, nil)
		attachNPCWeapon(rig, "Shotgun", ov.WeaponColor or P.Gunmetal)
		return rig

	elseif classId == "AssaultGuard" then
		-- ASSAULT GUARD: Sleek tactical operator — fitted slate combat shirt, chest rig w/ mags, shoulder radio antenna, patrol cap & comms headset, carbine
		local suit = ov.OutfitColor or Color3.fromRGB(38, 42, 48)
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWarm, suit, P.Obsidian, suit, P.Obsidian, 1.04, forPreview)
		local add = rig.AddPart
		local vestCol = ov.ArmorColor or P.Obsidian
		add(rig.Root, "TacVest", Vector3.new(2.14, 1.52, 1.32), CFrame.new(0, 0.12, 0), vestCol, Enum.Material.Fabric, nil)
		for _, mx in ipairs({ -0.56, 0, 0.56 }) do
			add(rig.Root, "RiflePouch", Vector3.new(0.36, 0.62, 0.26), CFrame.new(mx, -0.22, -0.74), P.Charcoal, Enum.Material.Fabric, nil)
		end
		add(rig.Root, "RadioUnit", Vector3.new(0.26, 0.52, 0.24), CFrame.new(-0.84, 0.56, 0.68), P.Obsidian, Enum.Material.Metal, nil)
		add(rig.Root, "RadioAntenna", Vector3.new(0.05, 1.15, 0.05), CFrame.new(-0.84, 1.32, 0.68), P.Obsidian, Enum.Material.Metal, nil)
		local helmCol = ov.HelmetColor or P.Obsidian
		add(rig.Head, "OperatorCap", Vector3.new(1.36, 0.46, 1.38), CFrame.new(0, 0.52, 0.02), helmCol, Enum.Material.Fabric, nil)
		add(rig.Head, "CapBrim", Vector3.new(1.18, 0.08, 0.56), CFrame.new(0, 0.34, -0.76) * CFrame.Angles(math.rad(6), 0, 0), helmCol, Enum.Material.Fabric, nil)
		add(rig.Head, "TacGoggles", Vector3.new(1.22, 0.28, 0.18), CFrame.new(0, 0.10, -0.63), Color3.fromRGB(22, 24, 28), Enum.Material.Glass, nil)
		add(rig.Head, "HeadsetL", Vector3.new(0.18, 0.36, 0.30), CFrame.new(-0.70, 0.04, 0), P.Gunmetal, Enum.Material.Metal, nil)
		add(rig.Head, "HeadsetR", Vector3.new(0.18, 0.36, 0.30), CFrame.new(0.70, 0.04, 0), P.Gunmetal, Enum.Material.Metal, nil)
		attachNPCWeapon(rig, "Carbine", ov.WeaponColor or P.Gunmetal)
		return rig

	elseif classId == "SniperGuard" then
		-- SNIPER GUARD: Distinct recon marksman silhouette — hooded charcoal-olive cloak/capelet, asymmetric chest bandolier, recon visor eyepiece, long scoped sniper
		local suit = ov.OutfitColor or P.OliveCharcoal
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinPale, suit, P.Charcoal, suit, P.Obsidian, 0.96, forPreview)
		local add = rig.AddPart
		-- Draped hooded recon mantle & diagonal .308 cartridge bandolier
		add(rig.Root, "ReconCapeBack", Vector3.new(2.08, 1.72, 0.18), CFrame.new(0, 0.04, 0.64) * CFrame.Angles(math.rad(6), 0, 0), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Root, "ShoulderMantle", Vector3.new(2.38, 0.44, 1.32), CFrame.new(0, 0.96, 0.08), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Root, "AmmoStrap", Vector3.new(0.24, 2.18, 1.24), CFrame.new(0, 0.10, 0) * CFrame.Angles(0, 0, math.rad(36)), P.WornLeather, Enum.Material.Leather, nil)
		if ov.ArmorColor then
			add(rig.Root, "LightPlate", Vector3.new(1.88, 1.22, 1.24), CFrame.new(0, 0.12, 0), ov.ArmorColor, Enum.Material.Metal, nil)
		end
		-- Low-profile Recon Hood + single right-eye rangefinder optic
		local helmCol = ov.HelmetColor or P.Charcoal
		add(rig.Head, "ReconHoodTop", Vector3.new(1.48, 0.56, 1.56), CFrame.new(0, 0.46, 0.08), helmCol, Enum.Material.Fabric, nil)
		add(rig.Head, "ReconHoodSideL", Vector3.new(0.20, 1.12, 1.38), CFrame.new(-0.68, 0.02, 0.08), helmCol, Enum.Material.Fabric, nil)
		add(rig.Head, "ReconHoodSideR", Vector3.new(0.20, 1.12, 1.38), CFrame.new(0.68, 0.02, 0.08), helmCol, Enum.Material.Fabric, nil)
		add(rig.Head, "FaceWrap", Vector3.new(1.26, 0.48, 1.24), CFrame.new(0, -0.28, -0.02), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Head, "RangefinderLens", Vector3.new(0.24, 0.24, 0.34), CFrame.new(0.26, 0.10, -0.68), P.Gunmetal, Enum.Material.Metal, nil)
		attachNPCWeapon(rig, "Sniper", ov.WeaponColor or P.Gunmetal)
		return rig

	elseif classId == "TacticalGuard" then
		-- TACTICAL GUARD: Field Support Specialist — charcoal utility jacket, cross-body trauma kit bag, subtle oxblood medic armband, matte comms helmet, carbine
		local suit = ov.OutfitColor or P.Charcoal
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWarm, suit, P.Obsidian, suit, P.Obsidian, 1.04, forPreview)
		local add = rig.AddPart
		local vestCol = ov.ArmorColor or P.Slate
		add(rig.Root, "UtilityRig", Vector3.new(2.14, 1.56, 1.32), CFrame.new(0, 0.10, 0), vestCol, Enum.Material.Fabric, nil)
		-- Trauma backpack & subtle dark-red field medic patch on arm
		add(rig.Root, "TraumaPack", Vector3.new(1.36, 1.48, 0.62), CFrame.new(0, 0.10, 0.88), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Root, "MedCrossH", Vector3.new(0.42, 0.12, 0.06), CFrame.new(0, 0.24, 1.20), P.DeepRed, Enum.Material.SmoothPlastic, nil)
		add(rig.Root, "MedCrossV", Vector3.new(0.12, 0.42, 0.06), CFrame.new(0, 0.24, 1.20), P.DeepRed, Enum.Material.SmoothPlastic, nil)
		add(rig.LeftArm, "MedicArmband", Vector3.new(0.84, 0.32, 0.84), CFrame.new(0, 0.40, 0), P.DeepRed, Enum.Material.Fabric, nil)
		local helmCol = ov.HelmetColor or P.Charcoal
		add(rig.Head, "TacHelmet", Vector3.new(1.44, 0.72, 1.46), CFrame.new(0, 0.48, 0.04), helmCol, Enum.Material.Metal, nil)
		add(rig.Head, "CommsMic", Vector3.new(0.08, 0.08, 0.56), CFrame.new(-0.56, -0.18, -0.44) * CFrame.Angles(0, math.rad(28), 0), P.Obsidian, Enum.Material.Metal, nil)
		attachNPCWeapon(rig, "Carbine", ov.WeaponColor or P.Gunmetal)
		return rig

	elseif classId == "EliteGuard" then
		-- ELITE GUARD: Executive Hitman — razor-tailored long matte-black trench coat, structured lapels, slicked hair, dark glasses, suppressed precision rifle
		local suit = ov.OutfitColor or P.Obsidian
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinPale, suit, P.Obsidian, suit, P.Obsidian, 1.07, forPreview)
		local add = rig.AddPart
		add(rig.Root, "DressShirt", Vector3.new(0.68, 1.56, 0.14), CFrame.new(0, 0.36, -0.58), P.OffWhite, Enum.Material.Fabric, nil)
		add(rig.Root, "SlimTie", Vector3.new(0.20, 1.26, 0.16), CFrame.new(0, 0.32, -0.62), P.Obsidian, Enum.Material.Fabric, nil)
		if ov.ArmorColor then
			add(rig.Root, "UnderVest", Vector3.new(1.96, 1.28, 1.24), CFrame.new(0, 0.08, 0), ov.ArmorColor, Enum.Material.Metal, nil)
		end
		add(rig.Root, "HighCollar", Vector3.new(1.52, 0.46, 0.42), CFrame.new(0, 1.20, 0.40), suit, Enum.Material.Fabric, nil)
		add(rig.Root, "CoatTailBack", Vector3.new(2.20, 1.72, 0.24), CFrame.new(0, -1.80, 0.48), suit, Enum.Material.Fabric, nil)
		add(rig.Root, "CoatTailL", Vector3.new(0.22, 1.66, 1.06), CFrame.new(-1.05, -1.78, 0.04), suit, Enum.Material.Fabric, nil)
		add(rig.Root, "CoatTailR", Vector3.new(0.22, 1.66, 1.06), CFrame.new(1.05, -1.78, 0.04), suit, Enum.Material.Fabric, nil)
		add(rig.Head, "SlickHair", Vector3.new(1.32, 0.34, 1.38), CFrame.new(0, 0.56, 0.06), P.HairDark, Enum.Material.SmoothPlastic, nil)
		add(rig.Head, "DarkGlasses", Vector3.new(1.18, 0.25, 0.14), CFrame.new(0, 0.08, -0.63), P.Obsidian, Enum.Material.Glass, nil)
		if ov.HelmetColor then
			add(rig.Head, "EliteHelm", Vector3.new(1.44, 0.64, 1.46), CFrame.new(0, 0.52, 0.04), ov.HelmetColor, Enum.Material.Metal, nil)
		end
		attachNPCWeapon(rig, "Carbine", ov.WeaponColor or P.Obsidian)
		return rig

	elseif classId == "BossBodyguard" then
		-- BOSS BODYGUARD: Underboss Commander — commanding tall build, obsidian 3-piece suit, draped dark overcoat, deep red silk tie, classic black fedora, tarnished brass clip, heavy battle rifle
		local suit = ov.OutfitColor or P.Obsidian
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWeathered, suit, P.Obsidian, suit, P.Obsidian, 1.15, forPreview)
		local add = rig.AddPart
		add(rig.Root, "DressShirt", Vector3.new(0.76, 1.66, 0.14), CFrame.new(0, 0.34, -0.58), P.OffWhite, Enum.Material.Fabric, nil)
		add(rig.Root, "UnderbossTie", Vector3.new(0.24, 1.34, 0.16), CFrame.new(0, 0.28, -0.62), P.DeepRed, Enum.Material.Fabric, nil)
		add(rig.Root, "BrassPin", Vector3.new(0.28, 0.08, 0.08), CFrame.new(0, 0.20, -0.67), P.TarnishedBrass, Enum.Material.Metal, nil)
		add(rig.Root, "CoatCollar", Vector3.new(2.38, 0.44, 1.24), CFrame.new(0, 1.12, 0.08), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Root, "OvercoatBack", Vector3.new(2.44, 1.88, 0.28), CFrame.new(0, -1.86, 0.50), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Root, "OvercoatL", Vector3.new(0.24, 1.80, 1.12), CFrame.new(-1.16, -1.82, 0.04), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Root, "OvercoatR", Vector3.new(0.24, 1.80, 1.12), CFrame.new(1.16, -1.82, 0.04), P.Charcoal, Enum.Material.Fabric, nil)
		if ov.ArmorColor then
			add(rig.Root, "ConcealedPlate", Vector3.new(2.12, 1.32, 1.24), CFrame.new(0, 0.06, 0), ov.ArmorColor, Enum.Material.Metal, nil)
		end
		add(rig.Head, "Shades", Vector3.new(1.20, 0.26, 0.14), CFrame.new(0, 0.08, -0.63), P.Obsidian, Enum.Material.Glass, nil)
		add(rig.Head, "Goatee", Vector3.new(0.56, 0.34, 0.24), CFrame.new(0, -0.36, -0.52), P.HairSilver, Enum.Material.Fabric, nil)
		local hatCol = ov.HelmetColor or P.Obsidian
		add(rig.Head, "BorsalinoBrim", Vector3.new(0.14, 2.24, 2.24), CFrame.new(0, 0.58, 0) * CFrame.Angles(0, 0, math.rad(90)), hatCol, Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(rig.Head, "BorsalinoCrown", Vector3.new(0.68, 1.44, 1.44), CFrame.new(0, 0.92, 0) * CFrame.Angles(0, 0, math.rad(90)), hatCol, Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(rig.Head, "BorsalinoBand", Vector3.new(0.14, 1.50, 1.50), CFrame.new(0, 0.68, 0) * CFrame.Angles(0, 0, math.rad(90)), P.TarnishedBrass, Enum.Material.Fabric, Enum.PartType.Cylinder)
		attachNPCWeapon(rig, "BossRifle", ov.WeaponColor or P.Obsidian)
		return rig

	else
		-- BASIC GUARD: Clean private security / suit detail — tailored charcoal 2-piece suit, white dress shirt, narrow black tie, sunglasses, coiled earpiece!
		local suit = ov.OutfitColor or P.Charcoal
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWarm, suit, suit, suit, P.Obsidian, 1.02, forPreview)
		local add = rig.AddPart
		add(rig.Root, "DressShirt", Vector3.new(0.72, 1.62, 0.14), CFrame.new(0, 0.32, -0.58), P.OffWhite, Enum.Material.Fabric, nil)
		add(rig.Root, "BlackTie", Vector3.new(0.20, 1.32, 0.16), CFrame.new(0, 0.26, -0.62), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Root, "SuitLapelL", Vector3.new(0.32, 1.15, 0.12), CFrame.new(-0.46, 0.44, -0.60) * CFrame.Angles(0, 0, math.rad(-14)), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Root, "SuitLapelR", Vector3.new(0.32, 1.15, 0.12), CFrame.new(0.46, 0.44, -0.60) * CFrame.Angles(0, 0, math.rad(14)), P.Obsidian, Enum.Material.Fabric, nil)
		if ov.ArmorColor then
			add(rig.Root, "KevlarVest", Vector3.new(2.08, 1.38, 1.26), CFrame.new(0, 0.10, 0), ov.ArmorColor, Enum.Material.Metal, nil)
		end
		add(rig.Head, "ShortHair", Vector3.new(1.30, 0.34, 1.34), CFrame.new(0, 0.56, 0.04), P.HairDark, Enum.Material.SmoothPlastic, nil)
		add(rig.Head, "Shades", Vector3.new(1.16, 0.25, 0.14), CFrame.new(0, 0.08, -0.63), P.Obsidian, Enum.Material.Glass, nil)
		add(rig.Head, "Earpiece", Vector3.new(0.10, 0.28, 0.10), CFrame.new(0.66, -0.14, 0.04), P.OffWhite, Enum.Material.SmoothPlastic, nil)
		if ov.HelmetColor then
			add(rig.Head, "GuardHelm", Vector3.new(1.42, 0.64, 1.44), CFrame.new(0, 0.50, 0.04), ov.HelmetColor, Enum.Material.Metal, nil)
		end
		if ov.HasRiotPlate then
			add(rig.LeftArm, "CompactShield", Vector3.new(0.22, 2.05, 1.36), CFrame.new(-0.54, -0.22, -0.18), P.Gunmetal, Enum.Material.Metal, nil)
		end
		attachNPCWeapon(rig, if ov.IsRanged then "SMG" else "Pistol", ov.WeaponColor or P.Gunmetal)
		return rig
	end
end

-- ============================================================================
-- 3. REALISTIC STAFF, CUSTOMER, MARKET BROKER & MOTORBIKE COURIER RIGS
-- ============================================================================
function MafiaVisualBuilder.BuildChefRig(
	modelName: string,
	accentCol: Color3,
	scale: number,
	spawnCF: CFrame,
	isProChef: boolean?
): RigHandle
	local coatCol = Color3.fromRGB(232, 230, 224)
	local scarfCol = if isProChef then P.TarnishedBrass else P.DeepRed
	local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWarm, coatCol, P.Charcoal, coatCol, nil, 1.02, false)
	local add = rig.AddPart

	-- Double-breasted tailored chef jacket buttons, collar, neckerchief & waist apron
	add(rig.Root, "MandarinCollar", Vector3.new(1.22, 0.34, 1.16), CFrame.new(0, 1.12, 0), coatCol, Enum.Material.Fabric, nil)
	add(rig.Root, "Neckerchief", Vector3.new(0.68, 0.42, 0.24), CFrame.new(0, 0.96, -0.56), scarfCol, Enum.Material.Fabric, nil)
	for row = 0, 2 do
		local y = 0.52 - row * 0.36
		add(rig.Root, "BtnL_" .. row, Vector3.new(0.11, 0.11, 0.08), CFrame.new(-0.28, y, -0.60), P.Obsidian, Enum.Material.SmoothPlastic, nil)
		add(rig.Root, "BtnR_" .. row, Vector3.new(0.11, 0.11, 0.08), CFrame.new(0.28, y, -0.60), P.Obsidian, Enum.Material.SmoothPlastic, nil)
	end
	add(rig.Root, "ChefApron", Vector3.new(2.14, 1.25, 1.24), CFrame.new(0, -0.78, -0.02), accentCol, Enum.Material.Fabric, nil)
	add(rig.Root, "ApronTowel", Vector3.new(0.36, 0.68, 0.18), CFrame.new(0.76, -0.88, -0.58), P.OffWhite, Enum.Material.Fabric, nil)

	-- Realistic proportioned hair & pleated chef toque (NO giant sphere!)
	add(rig.Head, "SideHair", Vector3.new(1.30, 0.38, 1.32), CFrame.new(0, 0.28, 0.08), P.HairDark, Enum.Material.SmoothPlastic, nil)
	add(rig.Head, "ToqueBand", Vector3.new(0.46, 1.34, 1.34), CFrame.new(0, 0.72, 0) * CFrame.Angles(0, 0, math.rad(90)), coatCol, Enum.Material.Fabric, Enum.PartType.Cylinder)
	add(rig.Head, "ToqueCrown", Vector3.new(0.58, 1.54, 1.54), CFrame.new(0, 1.12, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(242, 240, 236), Enum.Material.Fabric, Enum.PartType.Cylinder)
	if isProChef then
		add(rig.Head, "ProTrim", Vector3.new(0.12, 1.38, 1.38), CFrame.new(0, 0.56, 0) * CFrame.Angles(0, 0, math.rad(90)), P.TarnishedBrass, Enum.Material.Metal, Enum.PartType.Cylinder)
	end

	-- Steel sauté spatula / kitchen tool in right hand
	add(rig.RightArm, "PanHandle", Vector3.new(0.12, 0.12, 0.95), CFrame.new(0, -1.16, -0.56), P.Obsidian, Enum.Material.SmoothPlastic, nil)
	add(rig.RightArm, "SteelPan", Vector3.new(0.22, 0.96, 0.96), CFrame.new(0, -1.16, -1.25) * CFrame.Angles(0, 0, math.rad(90)), P.BrushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
	return rig
end

function MafiaVisualBuilder.BuildWaiterRig(
	modelName: string,
	isFemale: boolean,
	scale: number,
	spawnCF: CFrame
): RigHandle
	local vestCol = P.Obsidian
	local shirtCol = Color3.fromRGB(236, 234, 228)
	local skinCol = if isFemale then P.SkinPale else P.SkinWarm
	local hairCol = if isFemale then P.DarkBrown else P.HairDark
	local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, skinCol, vestCol, P.Charcoal, shirtCol, P.OffWhite, if isFemale then 0.94 else 1.0, false)
	local add = rig.AddPart

	-- Crisp dress shirt V-front, deep-oxblood bowtie, waistcoat buttons & half-bistro apron
	add(rig.Root, "ShirtFront", Vector3.new(0.76, 1.36, 0.16), CFrame.new(0, 0.42, -0.56), shirtCol, Enum.Material.Fabric, nil)
	add(rig.Root, "BowTie", Vector3.new(0.46, 0.18, 0.12), CFrame.new(0, 1.02, -0.62), P.DeepRed, Enum.Material.Fabric, nil)
	add(rig.Root, "VestLapelL", Vector3.new(0.26, 0.96, 0.12), CFrame.new(-0.42, 0.44, -0.59) * CFrame.Angles(0, 0, math.rad(-14)), P.Charcoal, Enum.Material.Fabric, nil)
	add(rig.Root, "VestLapelR", Vector3.new(0.26, 0.96, 0.12), CFrame.new(0.42, 0.44, -0.59) * CFrame.Angles(0, 0, math.rad(14)), P.Charcoal, Enum.Material.Fabric, nil)
	add(rig.Root, "BistroApron", Vector3.new(2.08, 1.24, 1.20), CFrame.new(0, -0.82, -0.02), shirtCol, Enum.Material.Fabric, nil)

	-- Realistic hair
	add(rig.Head, "HairCrown", Vector3.new(1.34, 0.42, 1.38), CFrame.new(0, 0.54, 0.06), hairCol, Enum.Material.SmoothPlastic, nil)
	if isFemale then
		add(rig.Head, "HairBun", Vector3.new(0.68, 0.64, 0.68), CFrame.new(0, 0.48, 0.72), hairCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		add(rig.Head, "SideHairL", Vector3.new(0.22, 0.64, 0.88), CFrame.new(-0.62, 0.12, 0.12), hairCol, Enum.Material.SmoothPlastic, nil)
		add(rig.Head, "SideHairR", Vector3.new(0.22, 0.64, 0.88), CFrame.new(0.62, 0.12, 0.12), hairCol, Enum.Material.SmoothPlastic, nil)
	end

	-- Polished stainless serving tray carried naturally forward
	add(rig.Root, "SilverTray", Vector3.new(0.12, 2.05, 2.05), CFrame.new(0, 0.28, -1.68) * CFrame.Angles(0, 0, math.rad(90)), P.BrushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
	add(rig.Root, "TrayRim", Vector3.new(0.16, 1.72, 1.72), CFrame.new(0, 0.30, -1.68) * CFrame.Angles(0, 0, math.rad(90)), P.OffWhite, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	return rig
end

local CUSTOMER_WARDROBES = {
	{ Coat = Color3.fromRGB(118, 92, 68), Pants = Color3.fromRGB(34, 36, 42), Accent = Color3.fromRGB(122, 34, 40), Skin = P.SkinWarm, Hair = P.HairDark, Style = "Trench" },
	{ Coat = Color3.fromRGB(44, 52, 64), Pants = Color3.fromRGB(28, 30, 36), Accent = P.OffWhite, Skin = P.SkinPale, Hair = P.DarkBrown, Style = "Blazer" },
	{ Coat = Color3.fromRGB(54, 60, 48), Pants = Color3.fromRGB(38, 44, 54), Accent = Color3.fromRGB(142, 118, 86), Skin = P.SkinWeathered, Hair = P.HairDark, Style = "Bomber" },
	{ Coat = Color3.fromRGB(92, 36, 44), Pants = Color3.fromRGB(26, 28, 34), Accent = P.TarnishedBrass, Skin = P.SkinPale, Hair = Color3.fromRGB(82, 48, 30), Style = "Handbag" },
	{ Coat = Color3.fromRGB(38, 42, 50), Pants = Color3.fromRGB(24, 26, 30), Accent = P.TarnishedBrass, Skin = P.SkinWarm, Hair = P.HairSilver, Style = "Critic" },
	{ Coat = Color3.fromRGB(52, 40, 34), Pants = Color3.fromRGB(36, 44, 58), Accent = P.MutedGrey, Skin = P.SkinWeathered, Hair = P.HairDark, Style = "Leather" },
}

function MafiaVisualBuilder.BuildCustomerRig(
	modelName: string,
	styleIdx: number,
	scale: number,
	spawnCF: CFrame
): RigHandle
	local w = CUSTOMER_WARDROBES[((styleIdx - 1) % #CUSTOMER_WARDROBES) + 1]
	local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, w.Skin, w.Coat, w.Pants, w.Coat, nil, 0.98, false)
	local add = rig.AddPart

	add(rig.Root, "InnerShirt", Vector3.new(0.76, 1.55, 0.14), CFrame.new(0, 0.34, -0.56), P.OffWhite, Enum.Material.Fabric, nil)
	add(rig.Root, "JacketCollar", Vector3.new(1.88, 0.36, 1.18), CFrame.new(0, 1.10, 0.04), w.Coat, Enum.Material.Fabric, nil)

	if w.Style == "Trench" then
		add(rig.Root, "Scarf", Vector3.new(1.25, 0.34, 1.24), CFrame.new(0, 1.14, -0.04), w.Accent, Enum.Material.Fabric, nil)
		add(rig.Root, "CoatTail", Vector3.new(2.06, 1.32, 0.22), CFrame.new(0, -1.62, 0.44), w.Coat, Enum.Material.Fabric, nil)
	elseif w.Style == "Blazer" or w.Style == "Critic" then
		add(rig.Root, "NeckTie", Vector3.new(0.18, 1.24, 0.14), CFrame.new(0, 0.28, -0.60), w.Accent, Enum.Material.Fabric, nil)
		add(rig.Head, "Spectacles", Vector3.new(1.12, 0.24, 0.12), CFrame.new(0, 0.08, -0.62), P.Charcoal, Enum.Material.Glass, nil)
	elseif w.Style == "Handbag" then
		add(rig.Root, "PurseStrap", Vector3.new(0.12, 1.85, 1.22), CFrame.new(0.78, -0.15, 0) * CFrame.Angles(0, 0, math.rad(16)), P.WornLeather, Enum.Material.Leather, nil)
		add(rig.Root, "Handbag", Vector3.new(0.38, 0.78, 0.92), CFrame.new(1.08, -1.02, 0.12), P.WornLeather, Enum.Material.Leather, nil)
		add(rig.Head, "HairBun", Vector3.new(0.64, 0.60, 0.64), CFrame.new(0, 0.44, 0.72), w.Hair, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	elseif w.Style == "Leather" then
		add(rig.Head, "KnitCap", Vector3.new(1.36, 0.54, 1.38), CFrame.new(0, 0.54, 0.06) * CFrame.Angles(math.rad(-8), 0, 0), P.Charcoal, Enum.Material.Fabric, nil)
	end

	if w.Style ~= "Leather" then
		add(rig.Head, "HairTop", Vector3.new(1.34, 0.40, 1.38), CFrame.new(0, 0.54, 0.05), w.Hair, Enum.Material.SmoothPlastic, nil)
		add(rig.Head, "HairBack", Vector3.new(1.28, 0.62, 0.34), CFrame.new(0, 0.22, 0.56), w.Hair, Enum.Material.SmoothPlastic, nil)
	end
	return rig
end

function MafiaVisualBuilder.BuildMarketBrokerRig(modelName: string, spawnCF: CFrame): RigHandle
	local rig = MafiaVisualBuilder.CreateBaseRig(modelName, 1.10, spawnCF, P.SkinWeathered, P.Obsidian, P.Charcoal, P.Obsidian, P.WornLeather, 1.08, true)
	local add = rig.AddPart
	add(rig.Root, "DressShirt", Vector3.new(0.78, 1.60, 0.14), CFrame.new(0, 0.34, -0.58), P.OffWhite, Enum.Material.Fabric, nil)
	add(rig.Root, "Cravat", Vector3.new(0.32, 0.85, 0.18), CFrame.new(0, 0.52, -0.62), P.DeepRed, Enum.Material.Fabric, nil)
	add(rig.Root, "WatchChain", Vector3.new(0.86, 0.08, 0.10), CFrame.new(0.32, -0.42, -0.62) * CFrame.Angles(0, 0, math.rad(-14)), P.TarnishedBrass, Enum.Material.Metal, nil)
	add(rig.Head, "Shades", Vector3.new(1.18, 0.24, 0.14), CFrame.new(0, 0.08, -0.63), P.Obsidian, Enum.Material.Glass, nil)
	add(rig.Head, "Mustache", Vector3.new(0.56, 0.14, 0.14), CFrame.new(0, -0.18, -0.62), P.HairSilver, Enum.Material.Fabric, nil)
	add(rig.Head, "HatBrim", Vector3.new(0.14, 2.15, 2.15), CFrame.new(0, 0.58, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Charcoal, Enum.Material.Fabric, Enum.PartType.Cylinder)
	add(rig.Head, "HatCrown", Vector3.new(0.68, 1.42, 1.42), CFrame.new(0, 0.92, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Charcoal, Enum.Material.Fabric, Enum.PartType.Cylinder)
	add(rig.Head, "HatRibbon", Vector3.new(0.14, 1.48, 1.48), CFrame.new(0, 0.68, 0) * CFrame.Angles(0, 0, math.rad(90)), P.TarnishedBrass, Enum.Material.Fabric, Enum.PartType.Cylinder)
	return rig
end

-- Realistic Leather-Jacket Delivery Rider seated on a sculpted 3D Street Delivery Motorbike with spinning alloy wheels & rear cargo crate rack!
function MafiaVisualBuilder.BuildMotorbikeCourierRig(
	modelName: string,
	teamCol: Color3,
	scale: number,
	spawnCF: CFrame
): (RigHandle, BasePart)
	local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWarm, P.Obsidian, P.Charcoal, P.Obsidian, P.WornLeather, 1.02, false)
	local add = rig.AddPart
	local root = rig.Root

	-- Rider gear: padded dark-leather moto jacket stripe + aerodynamic full-face helmet with dark visor
	add(rig.Root, "MotoStripeL", Vector3.new(0.18, 1.48, 1.20), CFrame.new(-0.82, 0.28, 0), teamCol, Enum.Material.Leather, nil)
	add(rig.Root, "MotoStripeR", Vector3.new(0.18, 1.48, 1.20), CFrame.new(0.82, 0.28, 0), teamCol, Enum.Material.Leather, nil)
	add(rig.Head, "MotoHelmet", Vector3.new(1.56, 1.46, 1.62), CFrame.new(0, 0.14, 0.04), P.Charcoal, Enum.Material.Metal, Enum.PartType.Ball)
	add(rig.Head, "HelmetStripe", Vector3.new(0.24, 1.48, 1.66), CFrame.new(0, 0.16, 0.04), teamCol, Enum.Material.SmoothPlastic, nil)
	add(rig.Head, "HelmetVisor", Vector3.new(1.36, 0.46, 0.42), CFrame.new(0, 0.10, -0.66), P.Obsidian, Enum.Material.Glass, nil)

	-- Pose rider arms forward gripping handlebars & legs straddling bike seat
	local laj = root:FindFirstChild("LeftArmJoint")
	local raj = root:FindFirstChild("RightArmJoint")
	local llj = root:FindFirstChild("LeftLegJoint")
	local rlj = root:FindFirstChild("RightLegJoint")
	if laj and laj:IsA("Motor6D") then
		laj.C0 = CFrame.new(-1.38 * scale, 0.92 * scale, -0.15 * scale) * CFrame.Angles(math.rad(68), math.rad(10), 0)
	end
	if raj and raj:IsA("Motor6D") then
		raj.C0 = CFrame.new(1.38 * scale, 0.92 * scale, -0.15 * scale) * CFrame.Angles(math.rad(68), math.rad(-10), 0)
	end
	if llj and llj:IsA("Motor6D") then
		llj.C0 = CFrame.new(-0.92 * scale, -1.05 * scale, -0.25 * scale) * CFrame.Angles(math.rad(54), 0, math.rad(-10))
	end
	if rlj and rlj:IsA("Motor6D") then
		rlj.C0 = CFrame.new(0.92 * scale, -1.05 * scale, -0.25 * scale) * CFrame.Angles(math.rad(54), 0, math.rad(10))
	end

	-- Sculpted 3D Street Delivery Motorbike welded beneath the rider (wheel radius = 1.45 * scale)
	local wheelY = -2.08
	local darkSteel = P.Gunmetal
	local chrome = P.BrushedSteel

	local function makeSpinWheel(jointName: string, zOff: number): ()
		local tire = Instance.new("Part")
		tire.Name = jointName .. "_Tire"
		tire.Shape = Enum.PartType.Cylinder
		tire.Size = Vector3.new(0.85, 2.8, 2.8) * scale
		tire.CFrame = root.CFrame * CFrame.new(0, wheelY * scale, zOff * scale)
		tire.Color = P.Obsidian
		tire.Material = Enum.Material.SmoothPlastic
		tire.CanCollide = false
		tire.CanTouch = false
		tire.CanQuery = false
		tire.Massless = true
		tire.Parent = rig.Model

		local m = Instance.new("Motor6D")
		m.Name = jointName
		m.Part0 = root
		m.Part1 = tire
		m.C0 = CFrame.new(0, wheelY * scale, zOff * scale)
		m.C1 = CFrame.new()
		m.Parent = root

		local rim = Instance.new("Part")
		rim.Name = jointName .. "_Rim"
		rim.Shape = Enum.PartType.Cylinder
		rim.Size = Vector3.new(0.92, 1.75, 1.75) * scale
		rim.CFrame = tire.CFrame
		rim.Color = chrome
		rim.Material = Enum.Material.Metal
		rim.CanCollide = false; rim.CanTouch = false; rim.CanQuery = false; rim.Massless = true
		rim.Parent = rig.Model
		local rw = Instance.new("WeldConstraint"); rw.Part0 = tire; rw.Part1 = rim; rw.Parent = rim

		local spoke = Instance.new("Part")
		spoke.Name = jointName .. "_Spoke"
		spoke.Size = Vector3.new(0.98, 0.24, 1.72) * scale
		spoke.CFrame = tire.CFrame
		spoke.Color = teamCol
		spoke.Material = Enum.Material.Metal
		spoke.CanCollide = false; spoke.CanTouch = false; spoke.CanQuery = false; spoke.Massless = true
		spoke.Parent = rig.Model
		local sw = Instance.new("WeldConstraint"); sw.Part0 = tire; sw.Part1 = spoke; sw.Parent = spoke
	end

	makeSpinWheel("FrontWheelJoint", -3.25)
	makeSpinWheel("RearWheelJoint", 2.95)

	-- Frame, Engine, Tank, Fairing, Forks, Handlebars, Exhaust & Headlight
	add(root, "BikeEngine", Vector3.new(1.55, 1.45, 2.15), CFrame.new(0, -1.45, -0.35), darkSteel, Enum.Material.Metal, nil)
	add(root, "BikeTank", Vector3.new(1.62, 0.92, 1.88), CFrame.new(0, -0.42, -1.25) * CFrame.Angles(math.rad(-14), 0, 0), teamCol, Enum.Material.Metal, nil)
	add(root, "BikeFairing", Vector3.new(1.52, 1.38, 1.42), CFrame.new(0, -0.45, -2.55) * CFrame.Angles(math.rad(-22), 0, 0), P.Charcoal, Enum.Material.Metal, nil)
	add(root, "BikeHeadlight", Vector3.new(0.86, 0.42, 0.20), CFrame.new(0, -0.42, -3.28), Color3.fromRGB(255, 240, 196), Enum.Material.SmoothPlastic, nil)
	add(root, "BikeSeat", Vector3.new(1.38, 0.42, 2.35), CFrame.new(0, -0.96, 0.55), P.WornLeather, Enum.Material.Leather, nil)
	add(root, "FrontForkL", Vector3.new(0.24, 2.85, 0.24), CFrame.new(-0.56, -0.95, -2.65) * CFrame.Angles(math.rad(22), 0, 0), chrome, Enum.Material.Metal, nil)
	add(root, "FrontForkR", Vector3.new(0.24, 2.85, 0.24), CFrame.new(0.56, -0.95, -2.65) * CFrame.Angles(math.rad(22), 0, 0), chrome, Enum.Material.Metal, nil)
	add(root, "Handlebar", Vector3.new(2.75, 0.22, 0.22), CFrame.new(0, 0.35, -2.02), darkSteel, Enum.Material.Metal, nil)
	add(root, "ExhaustL", Vector3.new(3.2, 0.36, 0.36), CFrame.new(-0.96, -1.85, 1.65) * CFrame.Angles(0, math.rad(90), math.rad(8)), chrome, Enum.Material.Metal, Enum.PartType.Cylinder)
	add(root, "ExhaustR", Vector3.new(3.2, 0.36, 0.36), CFrame.new(0.96, -1.85, 1.65) * CFrame.Angles(0, math.rad(90), math.rad(8)), chrome, Enum.Material.Metal, Enum.PartType.Cylinder)

	-- Steel Rear Cargo Rack + Toggleable Visible Ingredient Cargo Crate!
	add(root, "CargoRack", Vector3.new(1.92, 0.18, 2.10), CFrame.new(0, -0.68, 2.65), darkSteel, Enum.Material.Metal, nil)
	local crate = add(root, "CarriedCargoCrate", Vector3.new(1.82, 1.48, 1.88), CFrame.new(0, 0.16, 2.65), P.Walnut, Enum.Material.WoodPlanks, nil)
	crate.Transparency = 1 -- Visible when loaded with Market ingredients!

	CollectionService:AddTag(rig.Model, "AnimatedMotorbikeWheels")
	return rig, crate
end

-- ============================================================================
-- 4. ARTICULATED TACTICAL DEATH ANIMATION SYSTEM (Rivals, Bodyguards, Mafia)
-- ============================================================================
local ACTIVE_COMBAT_TAGS = {
	"RivalAIUnit",
	"MafiaUnit",
	"PlayerBodyguardUnit",
	"TurfGuardUnit",
	"AnimatedRaiderLimbs",
}

local function findDeathFloorY(model: Model, root: BasePart, hum: Humanoid): number
	local ignore: { Instance } = { model }
	for _, folderName in ipairs({ "RivalAIUnits", "PlayerBodyguards", "MafiaSyndicateUnits", "TurfNPCs" }) do
		local f = Workspace:FindFirstChild(folderName)
		if f then
			table.insert(ignore, f)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end

	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignore

	local res = Workspace:Raycast(root.Position + Vector3.new(0, 2.5, 0), Vector3.new(0, -18, 0), rp)
	if res then
		return res.Position.Y
	end
	return root.Position.Y - (hum.HipHeight + root.Size.Y * 0.5)
end

local function dropNPCWeaponOnDeath(model: Model, hitDir: Vector3, sideSign: number): ()
	local weaponParts: { BasePart } = {}
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") and desc:GetAttribute("IsNPCWeapon") == true then
			table.insert(weaponParts, desc)
		end
	end
	if #weaponParts == 0 then
		return
	end

	local dropFolder = Instance.new("Model")
	dropFolder.Name = "DroppedNPCWeapon"
	local primary = weaponParts[1]
	for _, wp in ipairs(weaponParts) do
		for _, ch in ipairs(wp:GetChildren()) do
			if ch:IsA("WeldConstraint") or ch:IsA("JointInstance") then
				ch:Destroy()
			end
		end
		wp.Anchored = false
		wp.CanCollide = (wp == primary)
		wp.CanTouch = false
		wp.CanQuery = false
		wp.Massless = (wp ~= primary)
		wp.Parent = dropFolder
		if wp ~= primary then
			local w = Instance.new("WeldConstraint")
			w.Part0 = primary
			w.Part1 = wp
			w.Parent = wp
		end
	end
	dropFolder.PrimaryPart = primary
	dropFolder.Parent = Workspace

	local sideVec = Vector3.new(-hitDir.Z, 0, hitDir.X) * sideSign
	primary.AssemblyLinearVelocity = (hitDir * 4.5) + (sideVec * 4.2) + Vector3.new(0, 5.5, 0)
	primary.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-12, 12), math.random(-10, 10))

	task.delay(3.05, function()
		if dropFolder.Parent then
			dropFolder:Destroy()
		end
	end)
end

-- Server-side trigger: stops AI/physics cleanly, detaches weapon to clatter onto the street,
-- tags model for 60 FPS client articulated collapse + ground dust + fade-out, and destroys after 3.15s.
function MafiaVisualBuilder.PlayDeathSequence(
	model: Model,
	isBoss: boolean?,
	onGroundImpact: ((Vector3) -> ())?
): ()
	if not model.Parent or model:GetAttribute("IsDying") == true then
		return
	end
	model:SetAttribute("IsDying", true)

	for _, tag in ipairs(ACTIVE_COMBAT_TAGS) do
		if CollectionService:HasTag(model, tag) then
			CollectionService:RemoveTag(model, tag)
		end
	end

	-- Immediately hide overhead nameplate / health bar
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BillboardGui") then
			desc.Enabled = false
		end
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root or not root:IsA("BasePart") then
		task.delay(0.5, function()
			if model.Parent then model:Destroy() end
		end)
		return
	end

	hum.BreakJointsOnDeath = false
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.AutoRotate = false
	hum.PlatformStand = true

	local floorY = findDeathFloorY(model, root, hum)
	local scale = math.clamp(root.Size.Y / 2.35, 0.75, 1.8)
	local sideSign = if math.random() < 0.5 then -1 else 1

	local rawHit = model:GetAttribute("LastHitDir")
	local flatHit: Vector3
	if typeof(rawHit) == "Vector3" then
		local h = Vector3.new(rawHit.X, 0, rawHit.Z)
		flatHit = if h.Magnitude > 0.05 then h.Unit else -root.CFrame.LookVector
	else
		local back = -root.CFrame.LookVector
		local hb = Vector3.new(back.X, 0, back.Z)
		flatHit = if hb.Magnitude > 0.05 then hb.Unit else Vector3.new(0, 0, 1)
	end

	-- Pick weighted tactical death style: 1 = Back Stagger Fall, 2 = Drop-to-Knees Face-Down, 3 = Side-Spin Collapse
	local style: number
	if isBoss then
		style = if math.random() < 0.72 then 2 else 1
	else
		local r = math.random()
		if r < 0.42 then
			style = 1
		elseif r < 0.76 then
			style = 2
		else
			style = 3
		end
	end

	-- Detach NPC weapon so it pops free and clatters on the ground
	dropNPCWeaponOnDeath(model, flatHit, sideSign)

	-- Disable collisions & queries on corpse so players/bullets never snag on fallen units
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
		end
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true

	model:SetAttribute("DeathStartTime", Workspace:GetServerTimeNow())
	model:SetAttribute("DeathStyle", style)
	model:SetAttribute("DeathSide", sideSign)
	model:SetAttribute("DeathFloorY", floorY)
	model:SetAttribute("DeathScale", scale)
	model:SetAttribute("DeathBaseCF", root.CFrame)
	model:SetAttribute("DeathHitDir", flatHit)
	CollectionService:AddTag(model, "DyingNPCUnit")

	-- Emit muffled body-drop impact SFX synced with pavement hit
	if onGroundImpact then
		local impactDelay = if style == 2 then 0.80 else 0.50
		local impactPos = Vector3.new(root.Position.X, floorY, root.Position.Z)
		task.delay(impactDelay, function()
			if model.Parent then
				onGroundImpact(impactPos)
			end
		end)
	end

	task.delay(3.15, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

return MafiaVisualBuilder
