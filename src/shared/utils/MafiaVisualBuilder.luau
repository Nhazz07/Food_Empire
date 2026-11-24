--!strict

-- Authentic Roblox R15 Character Builder for Food Empires.
-- Clones a genuine native Roblox R15 MeshPart character rig (via Players:CreateHumanoidModelFromDescription)
-- with smooth beveled anatomy, official Roblox Dynamic Head face, full 15-joint R15 Motor6D skeleton,
-- and uniquely designed layered outfits/accessories for Chefs, Waiters, Citizens, Bodyguards,
-- Rival Factions, Mafia, Samurai Mafia, Ninja Assassin Mafia, Apex Warlords & Motorbike Couriers.
-- Zero neon parts, zero emojis, shared seamlessly by server NPCs and client ViewportFrame portraits.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MafiaVisualBuilder = {}

-- Restrained Dark Mafia & Urban Character Palette (Zero Neon!)
MafiaVisualBuilder.PALETTE = {
	Obsidian = Color3.fromRGB(18, 20, 24),
	Charcoal = Color3.fromRGB(34, 38, 44),
	Slate = Color3.fromRGB(54, 58, 68),
	MutedGrey = Color3.fromRGB(102, 106, 116),
	DarkBrown = Color3.fromRGB(64, 44, 34),
	WornLeather = Color3.fromRGB(52, 36, 28),
	OliveCharcoal = Color3.fromRGB(48, 54, 44),
	OffWhite = Color3.fromRGB(224, 222, 216),
	DeepRed = Color3.fromRGB(128, 28, 34),
	DarkWine = Color3.fromRGB(82, 22, 28),
	Gunmetal = Color3.fromRGB(42, 46, 54),
	BrushedSteel = Color3.fromRGB(128, 134, 146),
	Walnut = Color3.fromRGB(92, 58, 36),
	TarnishedBrass = Color3.fromRGB(168, 138, 76),
	SkinWarm = Color3.fromRGB(228, 188, 154),
	SkinPale = Color3.fromRGB(220, 184, 158),
	SkinWeathered = Color3.fromRGB(196, 154, 122),
	HairDark = Color3.fromRGB(28, 24, 24),
	HairSilver = Color3.fromRGB(148, 150, 156),
}

local P = MafiaVisualBuilder.PALETTE

export type RigHandle = {
	Model: Model,
	Root: BasePart,
	Torso: BasePart,
	LowerTorso: BasePart,
	Head: BasePart,
	LeftArm: BasePart,
	RightArm: BasePart,
	LeftLowerArm: BasePart,
	RightLowerArm: BasePart,
	LeftHand: BasePart,
	RightHand: BasePart,
	LeftLeg: BasePart,
	RightLeg: BasePart,
	LeftLowerLeg: BasePart,
	RightLowerLeg: BasePart,
	LeftFoot: BasePart,
	RightFoot: BasePart,
	AddPart: (parentPart: BasePart, name: string, size: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?) -> Part,
}

-- Standard Roblox R15 Joint Chain (ordered parent -> child so world CFrames compute cleanly!)
local R15_JOINT_CHAIN: { { Name: string, Part0: string, Part1: string, Att: string } } = {
	{ Name = "Root", Part0 = "HumanoidRootPart", Part1 = "LowerTorso", Att = "RootRigAttachment" },
	{ Name = "Waist", Part0 = "LowerTorso", Part1 = "UpperTorso", Att = "WaistRigAttachment" },
	{ Name = "Neck", Part0 = "UpperTorso", Part1 = "Head", Att = "NeckRigAttachment" },
	{ Name = "LeftShoulder", Part0 = "UpperTorso", Part1 = "LeftUpperArm", Att = "LeftShoulderRigAttachment" },
	{ Name = "LeftElbow", Part0 = "LeftUpperArm", Part1 = "LeftLowerArm", Att = "LeftElbowRigAttachment" },
	{ Name = "LeftWrist", Part0 = "LeftLowerArm", Part1 = "LeftHand", Att = "LeftWristRigAttachment" },
	{ Name = "RightShoulder", Part0 = "UpperTorso", Part1 = "RightUpperArm", Att = "RightShoulderRigAttachment" },
	{ Name = "RightElbow", Part0 = "RightUpperArm", Part1 = "RightLowerArm", Att = "RightElbowRigAttachment" },
	{ Name = "RightWrist", Part0 = "RightLowerArm", Part1 = "RightHand", Att = "RightWristRigAttachment" },
	{ Name = "LeftHip", Part0 = "LowerTorso", Part1 = "LeftUpperLeg", Att = "LeftHipRigAttachment" },
	{ Name = "LeftKnee", Part0 = "LeftUpperLeg", Part1 = "LeftLowerLeg", Att = "LeftKneeRigAttachment" },
	{ Name = "LeftAnkle", Part0 = "LeftLowerLeg", Part1 = "LeftFoot", Att = "LeftAnkleRigAttachment" },
	{ Name = "RightHip", Part0 = "LowerTorso", Part1 = "RightUpperLeg", Att = "RightHipRigAttachment" },
	{ Name = "RightKnee", Part0 = "RightUpperLeg", Part1 = "RightLowerLeg", Att = "RightKneeRigAttachment" },
	{ Name = "RightAnkle", Part0 = "RightLowerLeg", Part1 = "RightFoot", Att = "RightAnkleRigAttachment" },
}

-- Cached native Roblox R15 MeshPart character template (built once, cloned in ~0.2ms per NPC!)
local cachedR15Template: Model? = nil

local function getOrBuildR15Template(): Model?
	if cachedR15Template then
		return cachedR15Template
	end
	local ok, raw = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not raw or not raw:IsA("Model") then
		return nil
	end

	-- Strip runtime scripts/physics constraints/humanoid (each service adds its own configured Humanoid!)
	for _, d in ipairs(raw:GetDescendants()) do
		if d:IsA("Humanoid")
			or d:IsA("LocalScript")
			or d:IsA("Script")
			or d:IsA("BodyColors")
			or d:IsA("AnimationConstraint")
			or d:IsA("BallSocketConstraint")
			or d:IsA("NoCollisionConstraint")
			or d:IsA("WrapTarget")
			or d:IsA("FaceControls")
			or d:IsA("Motor6D")
		then
			d:Destroy()
		end
	end

	local hrp = raw:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		raw:Destroy()
		return nil
	end

	-- Normalize HumanoidRootPart at origin with standard R15 collision volume
	hrp.Size = Vector3.new(2.0, 2.0, 1.0)
	hrp.Transparency = 1
	hrp.CFrame = CFrame.new(0, 0, 0)
	hrp.Anchored = true
	hrp.CanCollide = true
	hrp.CanTouch = true
	hrp.CanQuery = true
	hrp.TopSurface = Enum.SurfaceType.Smooth
	hrp.BottomSurface = Enum.SurfaceType.Smooth

	-- Rebuild exact R15 Motor6D skeleton from native RigAttachments and pose every MeshPart cleanly
	for _, spec in ipairs(R15_JOINT_CHAIN) do
		local p0 = raw:FindFirstChild(spec.Part0)
		local p1 = raw:FindFirstChild(spec.Part1)
		if p0 and p0:IsA("BasePart") and p1 and p1:IsA("BasePart") then
			local a0 = p0:FindFirstChild(spec.Att)
			local a1 = p1:FindFirstChild(spec.Att)
			if a0 and a0:IsA("Attachment") and a1 and a1:IsA("Attachment") then
				p1.CFrame = p0.CFrame * a0.CFrame * a1.CFrame:Inverse()
				p1.Anchored = false
				p1.CanCollide = false
				p1.CanTouch = false
				p1.CanQuery = true
				p1.Massless = true
				local m = Instance.new("Motor6D")
				m.Name = spec.Name
				m.Part0 = p0
				m.Part1 = p1
				m.C0 = a0.CFrame
				m.C1 = a1.CFrame
				m.Parent = p1
			end
		end
	end

	-- Clean up leftover attachments now that Motor6D joints are built
	for _, d in ipairs(raw:GetDescendants()) do
		if d:IsA("Attachment") or d:IsA("Vector3Value") then
			d:Destroy()
		end
	end

	raw.PrimaryPart = hrp
	cachedR15Template = raw
	return raw
end

-- Builds a genuine Roblox R15 Character Rig with beveled MeshParts, authentic Roblox face, and 15-joint skeleton!
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
	local isPreview = forPreview == true
	local handCol = gloveCol or skinCol
	local handMat = if gloveCol then Enum.Material.Leather else Enum.Material.SmoothPlastic
	local template = getOrBuildR15Template()

	local model: Model
	local root: BasePart
	local upperTorso: BasePart
	local lowerTorso: BasePart
	local head: BasePart
	local leftUpperArm: BasePart
	local rightUpperArm: BasePart
	local leftLowerArm: BasePart
	local rightLowerArm: BasePart
	local leftHand: BasePart
	local rightHand: BasePart
	local leftUpperLeg: BasePart
	local rightUpperLeg: BasePart
	local leftLowerLeg: BasePart
	local rightLowerLeg: BasePart
	local leftFoot: BasePart
	local rightFoot: BasePart

	if template then
		model = template:Clone()
		model.Name = modelName
		root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		upperTorso = model:FindFirstChild("UpperTorso") :: BasePart
		lowerTorso = model:FindFirstChild("LowerTorso") :: BasePart
		head = model:FindFirstChild("Head") :: BasePart
		leftUpperArm = model:FindFirstChild("LeftUpperArm") :: BasePart
		rightUpperArm = model:FindFirstChild("RightUpperArm") :: BasePart
		leftLowerArm = model:FindFirstChild("LeftLowerArm") :: BasePart
		rightLowerArm = model:FindFirstChild("RightLowerArm") :: BasePart
		leftHand = model:FindFirstChild("LeftHand") :: BasePart
		rightHand = model:FindFirstChild("RightHand") :: BasePart
		leftUpperLeg = model:FindFirstChild("LeftUpperLeg") :: BasePart
		rightUpperLeg = model:FindFirstChild("RightUpperLeg") :: BasePart
		leftLowerLeg = model:FindFirstChild("LeftLowerLeg") :: BasePart
		rightLowerLeg = model:FindFirstChild("RightLowerLeg") :: BasePart
		leftFoot = model:FindFirstChild("LeftFoot") :: BasePart
		rightFoot = model:FindFirstChild("RightFoot") :: BasePart

		-- Scale entire authentic R15 MeshPart rig cleanly
		if math.abs(s - 1.0) > 0.005 then
			model:ScaleTo(s)
		end

		-- Apply crisp realistic materials & colors to every R15 body segment
		head.Color = skinCol
		head.Material = Enum.Material.SmoothPlastic
		upperTorso.Color = torsoCol
		upperTorso.Material = Enum.Material.Fabric
		lowerTorso.Color = pantsCol
		lowerTorso.Material = Enum.Material.Fabric

		leftUpperArm.Color = armCol; leftUpperArm.Material = Enum.Material.Fabric
		rightUpperArm.Color = armCol; rightUpperArm.Material = Enum.Material.Fabric
		leftLowerArm.Color = armCol; leftLowerArm.Material = Enum.Material.Fabric
		rightLowerArm.Color = armCol; rightLowerArm.Material = Enum.Material.Fabric
		leftHand.Color = handCol; leftHand.Material = handMat
		rightHand.Color = handCol; rightHand.Material = handMat

		leftUpperLeg.Color = pantsCol; leftUpperLeg.Material = Enum.Material.Fabric
		rightUpperLeg.Color = pantsCol; rightUpperLeg.Material = Enum.Material.Fabric
		leftLowerLeg.Color = pantsCol; leftLowerLeg.Material = Enum.Material.Fabric
		rightLowerLeg.Color = pantsCol; rightLowerLeg.Material = Enum.Material.Fabric
		leftFoot.Color = P.Obsidian; leftFoot.Material = Enum.Material.Leather
		rightFoot.Color = P.Obsidian; rightFoot.Material = Enum.Material.Leather

		-- Position character at spawnCF cleanly
		model:PivotTo(spawnCF)

		-- Configure anchoring/collision for live NPC vs ViewportFrame preview
		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("BasePart") then
				local isRoot = (desc == root)
				desc.Anchored = isPreview
				desc.CanCollide = (not isPreview) and isRoot
				desc.CanTouch = (not isPreview) and isRoot
				desc.CanQuery = not isPreview
				desc.Massless = not isRoot
				desc.CastShadow = (not isPreview) and (not isRoot)
			elseif isPreview and desc:IsA("Motor6D") then
				desc:Destroy()
			end
		end
	else
		-- Safety fallback if CreateHumanoidModelFromDescription is unavailable
		model = Instance.new("Model")
		model.Name = modelName
		local function mk(n: string, sz: Vector3, col: Color3, mat: Enum.Material, collide: boolean): Part
			local p = Instance.new("Part")
			p.Name = n; p.Size = sz * s; p.Color = col; p.Material = mat
			p.Anchored = isPreview; p.CanCollide = (not isPreview) and collide
			p.Massless = not collide; p.Parent = model
			return p
		end
		root = mk("HumanoidRootPart", Vector3.new(2, 2, 1), torsoCol, Enum.Material.Fabric, true)
		root.Transparency = 1; root.CFrame = spawnCF
		upperTorso = mk("UpperTorso", Vector3.new(1.94, 1.69, 1), torsoCol, Enum.Material.Fabric, false)
		upperTorso.CFrame = root.CFrame * CFrame.new(0, 0.25 * s, 0)
		lowerTorso = mk("LowerTorso", Vector3.new(1.94, 0.45, 1), pantsCol, Enum.Material.Fabric, false)
		lowerTorso.CFrame = root.CFrame * CFrame.new(0, -0.75 * s, 0)
		head = mk("Head", Vector3.new(1.18, 1.18, 1.18), skinCol, Enum.Material.SmoothPlastic, false)
		head.CFrame = root.CFrame * CFrame.new(0, 1.68 * s, 0)
		local hm = Instance.new("SpecialMesh"); hm.MeshType = Enum.MeshType.Head; hm.Scale = Vector3.new(1.22, 1.22, 1.22); hm.Parent = head
		local face = Instance.new("Decal"); face.Name = "face"; face.Face = Enum.NormalId.Front; face.Texture = "rbxasset://textures/face.png"; face.Parent = head
		leftUpperArm = mk("LeftUpperArm", Vector3.new(0.95, 1.2, 0.95), armCol, Enum.Material.Fabric, false)
		leftUpperArm.CFrame = root.CFrame * CFrame.new(-1.46 * s, 0.45 * s, 0)
		rightUpperArm = mk("RightUpperArm", Vector3.new(0.95, 1.2, 0.95), armCol, Enum.Material.Fabric, false)
		rightUpperArm.CFrame = root.CFrame * CFrame.new(1.46 * s, 0.45 * s, 0)
		leftLowerArm = leftUpperArm; rightLowerArm = rightUpperArm; leftHand = leftUpperArm; rightHand = rightUpperArm
		leftUpperLeg = mk("LeftUpperLeg", Vector3.new(0.95, 1.35, 0.95), pantsCol, Enum.Material.Fabric, false)
		leftUpperLeg.CFrame = root.CFrame * CFrame.new(-0.50 * s, -1.65 * s, 0)
		rightUpperLeg = mk("RightUpperLeg", Vector3.new(0.95, 1.35, 0.95), pantsCol, Enum.Material.Fabric, false)
		rightUpperLeg.CFrame = root.CFrame * CFrame.new(0.50 * s, -1.65 * s, 0)
		leftLowerLeg = leftUpperLeg; rightLowerLeg = rightUpperLeg; leftFoot = leftUpperLeg; rightFoot = rightUpperLeg
		model.PrimaryPart = root
	end

	local function addPart(parentPart: BasePart, name: string, size: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * s
		p.Color = col
		p.Material = mat
		if shape then
			p.Shape = shape
		end
		p.Anchored = isPreview
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = not isPreview
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local pos = relCF.Position * s
		local rot = relCF - relCF.Position
		p.CFrame = parentPart.CFrame * CFrame.new(pos) * rot
		p.Parent = model
		if not isPreview then
			local w = Instance.new("WeldConstraint")
			w.Part0 = parentPart
			w.Part1 = p
			w.Parent = p
		end
		return p
	end

	-- Crisp tailored waist belt & metal buckle on LowerTorso for polished R15 silhouette
	addPart(lowerTorso, "WaistBelt", Vector3.new(2.04, 0.22, 1.08), CFrame.new(0, 0.08, 0), P.Obsidian, Enum.Material.Leather, nil)
	addPart(lowerTorso, "BeltBuckle", Vector3.new(0.28, 0.18, 0.08), CFrame.new(0, 0.08, -0.56), P.BrushedSteel, Enum.Material.Metal, nil)

	model:SetAttribute("IsR15Rig", true)
	model:SetAttribute("BaseScale", s)
	model.PrimaryPart = root

	return {
		Model = model,
		Root = root,
		Torso = upperTorso,
		LowerTorso = lowerTorso,
		Head = head,
		LeftArm = leftUpperArm,
		RightArm = rightUpperArm,
		LeftLowerArm = leftLowerArm,
		RightLowerArm = rightLowerArm,
		LeftHand = leftHand,
		RightHand = rightHand,
		LeftLeg = leftUpperLeg,
		RightLeg = rightUpperLeg,
		LeftLowerLeg = leftLowerLeg,
		RightLowerLeg = rightLowerLeg,
		LeftFoot = leftFoot,
		RightFoot = rightFoot,
		AddPart = addPart,
	}
end

-- ============================================================================
-- STUDIO NPC TEMPLATE OVERRIDE SYSTEM (ReplicatedStorage.NPCTemplates)
-- Drop any custom Roblox R15 (or R6) NPC Model inside ReplicatedStorage.NPCTemplates
-- (directly or in subfolders like Rivals / Bodyguards / Specialists / Staff / Citizens).
-- Matching models automatically override the procedural rigs while preserving Shirts,
-- Pants, BodyColors, Accessories, Layered Clothing, R15 Motor6D animations & death physics!
-- Optional Model Attributes on your custom Studio template:
--   * PreserveTemplateScale = true  -> keeps your exact Studio size instead of applying game scale
--   * AttachDefaultWeapon   = true  -> also attaches MafiaVisualBuilder's built-in weapon prop
--   * KeepTemplateUI        = true  -> preserves any BillboardGui / ProximityPrompt you added
--   * Disabled              = true  -> temporarily ignores this template and falls back to code rig
-- ============================================================================
local function normalizeTemplateKey(name: string): string
	return (string.gsub(string.lower(name), "[%s_%-]", ""))
end

local function isValidTemplateModel(inst: Instance): boolean
	if not inst:IsA("Model") then
		return false
	end
	if string.sub(inst.Name, 1, 1) == "_" then
		return false
	end
	if inst:GetAttribute("Disabled") == true then
		return false
	end
	local hasRoot = inst:FindFirstChild("HumanoidRootPart") ~= nil
		or inst.PrimaryPart ~= nil
		or inst:FindFirstChild("UpperTorso") ~= nil
		or inst:FindFirstChild("Torso") ~= nil
	return hasRoot
end

function MafiaVisualBuilder.FindNPCTemplate(candidateNames: { string }): Model?
	local rootFolder = ReplicatedStorage:FindFirstChild("NPCTemplates")
	if not rootFolder then
		return nil
	end

	-- Collect all direct & subfolder Model templates once for fast prioritized matching
	local exactMap: { [string]: Model } = {}
	local normMap: { [string]: Model } = {}

	local function scanFolder(container: Instance): ()
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Folder") then
				scanFolder(child)
			elseif isValidTemplateModel(child) then
				local m = child :: Model
				if not exactMap[m.Name] then
					exactMap[m.Name] = m
				end
				local nk = normalizeTemplateKey(m.Name)
				if not normMap[nk] then
					normMap[nk] = m
				end
			end
		end
	end
	scanFolder(rootFolder)

	for _, candidate in ipairs(candidateNames) do
		local exact = exactMap[candidate]
		if exact then
			return exact
		end
		local norm = normMap[normalizeTemplateKey(candidate)]
		if norm then
			return norm
		end
	end

	return nil
end

local function findFirstPart(model: Model, names: { string }, fallback: BasePart): BasePart
	for _, n in ipairs(names) do
		local ch = model:FindFirstChild(n)
		if ch and ch:IsA("BasePart") then
			return ch
		end
	end
	return fallback
end

function MafiaVisualBuilder.TryBuildFromTemplate(
	candidateNames: { string },
	modelName: string,
	scale: number,
	spawnCF: CFrame,
	forPreview: boolean?,
	combatStyle: string?
): (RigHandle?, Model?)
	local template = MafiaVisualBuilder.FindNPCTemplate(candidateNames)
	if not template then
		return nil, nil
	end

	local isPreview = forPreview == true
	local keepTemplateUI = template:GetAttribute("KeepTemplateUI") == true
	local preserveScale = template:GetAttribute("PreserveTemplateScale") == true

	local clone = template:Clone()
	clone.Name = modelName

	-- Strip any embedded scripts (e.g. Toolbox Animate/AI scripts) & old Humanoids/UI
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("BaseScript") or desc:IsA("ModuleScript") or desc:IsA("Humanoid") then
			desc:Destroy()
		elseif (not keepTemplateUI) and (desc:IsA("BillboardGui") or desc:IsA("ProximityPrompt")) then
			desc:Destroy()
		end
	end

	-- Locate HumanoidRootPart / PrimaryPart cleanly
	local hrpInst = clone:FindFirstChild("HumanoidRootPart")
	local root: BasePart? = if hrpInst and hrpInst:IsA("BasePart")
		then hrpInst
		elseif clone.PrimaryPart then clone.PrimaryPart
		else nil
	if not root then
		local fallbackTorso = clone:FindFirstChild("UpperTorso") or clone:FindFirstChild("Torso") or clone:FindFirstChildWhichIsA("BasePart", true)
		if fallbackTorso and fallbackTorso:IsA("BasePart") then
			root = fallbackTorso
		end
	end
	if not root then
		clone:Destroy()
		return nil, nil
	end

	clone.PrimaryPart = root
	if root.Name == "HumanoidRootPart" then
		root.Transparency = 1
	end

	local isR15 = (clone:FindFirstChild("UpperTorso") ~= nil and clone:FindFirstChild("LowerTorso") ~= nil)
	local upperTorso = findFirstPart(clone, { "UpperTorso", "Torso" }, root)
	local lowerTorso = findFirstPart(clone, { "LowerTorso", "Torso" }, upperTorso)
	local head = findFirstPart(clone, { "Head" }, upperTorso)
	local leftUpperArm = findFirstPart(clone, { "LeftUpperArm", "Left Arm" }, upperTorso)
	local rightUpperArm = findFirstPart(clone, { "RightUpperArm", "Right Arm" }, upperTorso)
	local leftLowerArm = findFirstPart(clone, { "LeftLowerArm", "Left Arm" }, leftUpperArm)
	local rightLowerArm = findFirstPart(clone, { "RightLowerArm", "Right Arm" }, rightUpperArm)
	local leftHand = findFirstPart(clone, { "LeftHand", "Left Arm" }, leftLowerArm)
	local rightHand = findFirstPart(clone, { "RightHand", "Right Arm" }, rightLowerArm)
	local leftUpperLeg = findFirstPart(clone, { "LeftUpperLeg", "Left Leg" }, lowerTorso)
	local rightUpperLeg = findFirstPart(clone, { "RightUpperLeg", "Right Leg" }, lowerTorso)
	local leftLowerLeg = findFirstPart(clone, { "LeftLowerLeg", "Left Leg" }, leftUpperLeg)
	local rightLowerLeg = findFirstPart(clone, { "RightLowerLeg", "Right Leg" }, rightUpperLeg)
	local leftFoot = findFirstPart(clone, { "LeftFoot", "Left Leg" }, leftLowerLeg)
	local rightFoot = findFirstPart(clone, { "RightFoot", "Right Leg" }, rightLowerLeg)

	-- Convert modern Roblox AnimationConstraints -> standard R15 Motor6Ds (keeping all Attachments & FaceControls!)
	-- so 60 FPS cooking, walking, combat & death animations work seamlessly on any Rig Builder / Avatar template!
	if isR15 then
		local needsMotor6D = (upperTorso:FindFirstChild("Waist") == nil) or (rightUpperArm:FindFirstChild("RightShoulder") == nil)
		if needsMotor6D then
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("AnimationConstraint") or d:IsA("BallSocketConstraint") or d:IsA("NoCollisionConstraint") then
					d:Destroy()
				end
			end
			for _, spec in ipairs(R15_JOINT_CHAIN) do
				local p0 = clone:FindFirstChild(spec.Part0)
				local p1 = clone:FindFirstChild(spec.Part1)
				if p0 and p0:IsA("BasePart") and p1 and p1:IsA("BasePart") then
					local existingMot = p1:FindFirstChild(spec.Name)
					if not (existingMot and existingMot:IsA("Motor6D")) then
						local a0 = p0:FindFirstChild(spec.Att)
						local a1 = p1:FindFirstChild(spec.Att)
						if a0 and a0:IsA("Attachment") and a1 and a1:IsA("Attachment") then
							p1.CFrame = p0.CFrame * a0.CFrame * a1.CFrame:Inverse()
							local mot = Instance.new("Motor6D")
							mot.Name = spec.Name
							mot.Part0 = p0
							mot.Part1 = p1
							mot.C0 = a0.CFrame
							mot.C1 = a1.CFrame
							mot.Parent = p1
						end
					end
				end
			end
		end
	end

	-- Apply game scale cleanly unless creator opted into PreserveTemplateScale = true
	if (not preserveScale) and math.abs(scale - 1.0) > 0.005 then
		pcall(function()
			clone:ScaleTo(scale)
		end)
	end

	-- Position character at spawnCF
	clone:PivotTo(spawnCF)

	-- Build attachment lookup on body parts so any un-welded Studio Accessories attach automatically
	local bodyPartsList: { BasePart } = {
		root, upperTorso, lowerTorso, head,
		leftUpperArm, rightUpperArm, leftLowerArm, rightLowerArm, leftHand, rightHand,
		leftUpperLeg, rightUpperLeg, leftLowerLeg, rightLowerLeg, leftFoot, rightFoot,
	}
	local bodyAttachments: { [string]: Attachment } = {}
	for _, bp in ipairs(bodyPartsList) do
		for _, ch in ipairs(bp:GetChildren()) do
			if ch:IsA("Attachment") and not bodyAttachments[ch.Name] then
				bodyAttachments[ch.Name] = ch
			end
		end
	end

	-- Track which BaseParts already participate in a joint/weld
	local jointedParts: { [BasePart]: boolean } = { [root] = true }
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("JointInstance") or desc:IsA("WeldConstraint") then
			if desc.Part0 then jointedParts[desc.Part0] = true end
			if desc.Part1 then jointedParts[desc.Part1] = true end
		elseif desc:IsA("RigidConstraint") then
			if desc.Attachment0 and desc.Attachment0.Parent and desc.Attachment0.Parent:IsA("BasePart") then
				jointedParts[desc.Attachment0.Parent] = true
			end
			if desc.Attachment1 and desc.Attachment1.Parent and desc.Attachment1.Parent:IsA("BasePart") then
				jointedParts[desc.Attachment1.Parent] = true
			end
		end
	end

	-- Snap every Accessory Handle cleanly into place (via AccessoryWeld or Attachment match) & weld if loose!
	for _, acc in ipairs(clone:GetChildren()) do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local weld = handle:FindFirstChildOfClass("Weld")
				if weld and weld.Part0 == handle and weld.Part1 then
					handle.CFrame = weld.Part1.CFrame * weld.C1 * weld.C0:Inverse()
				elseif weld and weld.Part1 == handle and weld.Part0 then
					handle.CFrame = weld.Part0.CFrame * weld.C0 * weld.C1:Inverse()
				else
					local targetBodyPart: BasePart = head
					for _, att in ipairs(handle:GetChildren()) do
						if att:IsA("Attachment") then
							local bodyAtt = bodyAttachments[att.Name]
							if bodyAtt and bodyAtt.Parent and bodyAtt.Parent:IsA("BasePart") then
								handle.CFrame = bodyAtt.WorldCFrame * att.CFrame:Inverse()
								targetBodyPart = bodyAtt.Parent
								break
							end
						end
					end
					if (not isPreview) and (not jointedParts[handle]) then
						local w = Instance.new("WeldConstraint")
						w.Name = "AutoAccessoryWeld"
						w.Part0 = targetBodyPart
						w.Part1 = handle
						w.Parent = handle
						jointedParts[handle] = true
					end
				end
			end
		end
	end

	-- Configure anchoring, collisions & auto-weld any loose custom Studio parts so nothing falls apart
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("BasePart") then
			local isRootPart = (desc == root)
			local isAccPart = (desc:FindFirstAncestorOfClass("Accessory") ~= nil)
			desc.Anchored = isPreview
			desc.CanCollide = (not isPreview) and isRootPart
			desc.CanTouch = (not isPreview) and isRootPart
			desc.CanQuery = (not isPreview) and (not isAccPart)
			desc.Massless = not isRootPart
			desc.CastShadow = (not isPreview) and (not isRootPart)

			if (not isPreview) and (not isRootPart) and (not jointedParts[desc]) then
				local nearestPart = upperTorso
				local nearestDist = math.huge
				for _, bp in ipairs(bodyPartsList) do
					if bp ~= desc then
						local d = (bp.Position - desc.Position).Magnitude
						if d < nearestDist then
							nearestDist = d
							nearestPart = bp
						end
					end
				end
				local w = Instance.new("WeldConstraint")
				w.Name = "AutoPropWeld"
				w.Part0 = nearestPart
				w.Part1 = desc
				w.Parent = desc
				jointedParts[desc] = true
			end
		end
	end

	-- Lightweight display Humanoid so Shirts, Pants, BodyColors & Layered Clothing always render!
	-- CRITICAL: Must set RigType = R15 on R15 models (Instance.new("Humanoid") defaults to R6, which skips R15 Shirt/Pants compositing!).
	-- Automatically transfers RigType = R15 and destroys itself if any server Service adds a real Gameplay Humanoid.
	local displayHum = Instance.new("Humanoid")
	displayHum.Name = "Humanoid"
	displayHum.RigType = if isR15 then Enum.HumanoidRigType.R15 else Enum.HumanoidRigType.R6
	displayHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	displayHum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	displayHum.EvaluateStateMachine = false
	displayHum:SetAttribute("IsTemplateDisplayHumanoid", true)
	displayHum.Parent = clone

	local humConn: RBXScriptConnection? = nil
	humConn = clone.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Humanoid") and child ~= displayHum then
			if isR15 then
				child.RigType = Enum.HumanoidRigType.R15
			end
			if displayHum.Parent then
				displayHum:Destroy()
			end
			-- Trigger R15 Shirt/Pants texture recomposite on services that parent Instance.new("Humanoid") (default R6)
			if isR15 then
				task.defer(function()
					if clone.Parent then
						for _, clothing in ipairs(clone:GetChildren()) do
							if clothing:IsA("Shirt") or clothing:IsA("Pants") then
								clothing.Parent = nil
								clothing.Parent = clone
							end
						end
					end
				end)
			end
			if humConn then
				humConn:Disconnect()
				humConn = nil
			end
		end
	end)

	local s = if preserveScale then 1.0 else scale
	local function addPart(parentPart: BasePart, name: string, size: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * s
		p.Color = col
		p.Material = mat
		if shape then
			p.Shape = shape
		end
		p.Anchored = isPreview
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = not isPreview
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local pos = relCF.Position * s
		local rot = relCF - relCF.Position
		p.CFrame = parentPart.CFrame * CFrame.new(pos) * rot
		p.Parent = clone
		if not isPreview then
			local w = Instance.new("WeldConstraint")
			w.Part0 = parentPart
			w.Part1 = p
			w.Parent = p
		end
		return p
	end

	clone:SetAttribute("IsR15Rig", isR15)
	clone:SetAttribute("BaseScale", scale)
	clone:SetAttribute("IsCustomNPCTemplate", true)
	clone:SetAttribute("TemplateSource", template.Name)
	if combatStyle and clone:GetAttribute("CombatStyle") == nil then
		clone:SetAttribute("CombatStyle", combatStyle)
	end

	return {
		Model = clone,
		Root = root,
		Torso = upperTorso,
		LowerTorso = lowerTorso,
		Head = head,
		LeftArm = leftUpperArm,
		RightArm = rightUpperArm,
		LeftLowerArm = leftLowerArm,
		RightLowerArm = rightLowerArm,
		LeftHand = leftHand,
		RightHand = rightHand,
		LeftLeg = leftUpperLeg,
		RightLeg = rightUpperLeg,
		LeftLowerLeg = leftLowerLeg,
		RightLowerLeg = rightLowerLeg,
		LeftFoot = leftFoot,
		RightFoot = rightFoot,
		AddPart = addPart,
	}, template
end

-- Helper: Sculpted layered Roblox hair styles for distinct character silhouettes
local function addHairStyle(rig: RigHandle, style: "Slick" | "Swept" | "Bun" | "Bob" | "Spiky" | "Parted", hairCol: Color3): ()
	local add = rig.AddPart
	local h = rig.Head
	if style == "Slick" then
		add(h, "HairCrown", Vector3.new(1.24, 0.34, 1.28), CFrame.new(0, 0.50, 0.06), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "HairBack", Vector3.new(1.22, 0.62, 0.38), CFrame.new(0, 0.16, 0.48), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "HairSideL", Vector3.new(0.16, 0.44, 0.72), CFrame.new(-0.58, 0.26, 0.14), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "HairSideR", Vector3.new(0.16, 0.44, 0.72), CFrame.new(0.58, 0.26, 0.14), hairCol, Enum.Material.SmoothPlastic, nil)
	elseif style == "Bun" then
		add(h, "HairCrown", Vector3.new(1.26, 0.38, 1.28), CFrame.new(0, 0.48, 0.06), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "HairBun", Vector3.new(0.62, 0.58, 0.62), CFrame.new(0, 0.42, 0.68), hairCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		add(h, "HairLockL", Vector3.new(0.20, 0.68, 0.78), CFrame.new(-0.58, 0.08, 0.14), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "HairLockR", Vector3.new(0.20, 0.68, 0.78), CFrame.new(0.58, 0.08, 0.14), hairCol, Enum.Material.SmoothPlastic, nil)
	elseif style == "Bob" then
		add(h, "HairTop", Vector3.new(1.28, 0.38, 1.32), CFrame.new(0, 0.48, 0.04), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "HairBangs", Vector3.new(1.12, 0.22, 0.20), CFrame.new(0, 0.36, -0.56), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "BobL", Vector3.new(0.24, 0.94, 0.96), CFrame.new(-0.60, -0.02, 0.12), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "BobR", Vector3.new(0.24, 0.94, 0.96), CFrame.new(0.60, -0.02, 0.12), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "BobBack", Vector3.new(1.26, 0.96, 0.34), CFrame.new(0, -0.02, 0.50), hairCol, Enum.Material.SmoothPlastic, nil)
	elseif style == "Spiky" then
		add(h, "HairBase", Vector3.new(1.24, 0.36, 1.24), CFrame.new(0, 0.48, 0.04), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "Spike1", Vector3.new(0.42, 0.38, 0.66), CFrame.new(-0.24, 0.66, -0.10) * CFrame.Angles(math.rad(16), 0, math.rad(14)), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "Spike2", Vector3.new(0.42, 0.42, 0.68), CFrame.new(0.18, 0.70, -0.14) * CFrame.Angles(math.rad(20), 0, math.rad(-12)), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "HairBack", Vector3.new(1.20, 0.54, 0.36), CFrame.new(0, 0.18, 0.46), hairCol, Enum.Material.SmoothPlastic, nil)
	elseif style == "Parted" then
		add(h, "HairL", Vector3.new(0.76, 0.36, 1.28), CFrame.new(-0.28, 0.50, 0.04) * CFrame.Angles(0, 0, math.rad(8)), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "HairR", Vector3.new(0.64, 0.30, 1.24), CFrame.new(0.34, 0.46, 0.04) * CFrame.Angles(0, 0, math.rad(-10)), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "HairBack", Vector3.new(1.22, 0.56, 0.36), CFrame.new(0, 0.18, 0.48), hairCol, Enum.Material.SmoothPlastic, nil)
	else
		-- Swept
		add(h, "HairTop", Vector3.new(1.26, 0.38, 1.32), CFrame.new(0, 0.50, 0.02), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "HairSweep", Vector3.new(1.06, 0.24, 0.42), CFrame.new(0.08, 0.56, -0.44) * CFrame.Angles(math.rad(-14), math.rad(8), 0), hairCol, Enum.Material.SmoothPlastic, nil)
		add(h, "HairBack", Vector3.new(1.22, 0.58, 0.36), CFrame.new(0, 0.18, 0.48), hairCol, Enum.Material.SmoothPlastic, nil)
	end
end

-- Helper: Realistic matte firearm / melee prop gripped directly in R15 RightHand (tags parts for weapon drop on death!)
local function attachNPCWeapon(rig: RigHandle, kind: "Crowbar" | "Pistol" | "Shotgun" | "SMG" | "Carbine" | "Sniper" | "BossRifle" | "TommyDrum" | "AssassinRifle" | "Katana" | "DualTantos", overrideCol: Color3?): ()
	local rawAdd = rig.AddPart
	local function add(parentPart: BasePart, name: string, size: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
		local p = rawAdd(parentPart, name, size, relCF, col, mat, shape)
		p:SetAttribute("IsNPCWeapon", true)
		return p
	end
	local hand = rig.RightHand
	local metalCol = overrideCol or P.Gunmetal
	local steel = P.BrushedSteel

	if kind == "Katana" then
		add(hand, "KatanaHilt", Vector3.new(0.14, 0.16, 0.92), CFrame.new(0, 0.02, -0.30), P.Obsidian, Enum.Material.Fabric, nil)
		add(hand, "KatanaWrap", Vector3.new(0.16, 0.18, 0.18), CFrame.new(0, 0.02, -0.10), P.DeepRed, Enum.Material.Fabric, nil)
		add(hand, "KatanaTsuba", Vector3.new(0.40, 0.40, 0.08), CFrame.new(0, 0.02, -0.78), P.TarnishedBrass, Enum.Material.Metal, nil)
		add(hand, "KatanaBlade", Vector3.new(0.06, 0.16, 3.25), CFrame.new(0, 0.04, -2.44), steel, Enum.Material.Metal, nil)
		return
	elseif kind == "DualTantos" then
		add(hand, "TantoGripR", Vector3.new(0.13, 0.15, 0.64), CFrame.new(0, 0, -0.26), P.Obsidian, Enum.Material.SmoothPlastic, nil)
		add(hand, "TantoGuardR", Vector3.new(0.26, 0.26, 0.08), CFrame.new(0, 0, -0.58), P.TarnishedBrass, Enum.Material.Metal, nil)
		add(hand, "TantoBladeR", Vector3.new(0.06, 0.15, 1.72), CFrame.new(0, 0, -1.44), steel, Enum.Material.Metal, nil)
		add(rig.LeftHand, "TantoGripL", Vector3.new(0.13, 0.15, 0.64), CFrame.new(0, 0, -0.26), P.Obsidian, Enum.Material.SmoothPlastic, nil)
		add(rig.LeftHand, "TantoGuardL", Vector3.new(0.26, 0.26, 0.08), CFrame.new(0, 0, -0.58), P.TarnishedBrass, Enum.Material.Metal, nil)
		add(rig.LeftHand, "TantoBladeL", Vector3.new(0.06, 0.15, 1.64), CFrame.new(0, 0, -1.40), steel, Enum.Material.Metal, nil)
		return
	end

	if kind == "Crowbar" then
		add(hand, "WeaponShaft", Vector3.new(0.14, 0.14, 1.85), CFrame.new(0, -0.06, -0.82), P.Gunmetal, Enum.Material.Metal, nil)
		add(hand, "CleaverHead", Vector3.new(0.08, 0.52, 0.90), CFrame.new(0, 0.02, -1.66), steel, Enum.Material.Metal, nil)
	elseif kind == "Pistol" then
		add(hand, "Grip", Vector3.new(0.20, 0.48, 0.26), CFrame.new(0, -0.10, -0.20), P.Obsidian, Enum.Material.SmoothPlastic, nil)
		add(hand, "Slide", Vector3.new(0.22, 0.26, 1.08), CFrame.new(0, 0.10, -0.62), metalCol, Enum.Material.Metal, nil)
		add(hand, "Barrel", Vector3.new(0.24, 0.13, 0.13), CFrame.new(0, 0.10, -1.24) * CFrame.Angles(0, math.rad(90), 0), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif kind == "Shotgun" then
		add(hand, "Stock", Vector3.new(0.24, 0.40, 0.92), CFrame.new(0, 0.04, 0.30), P.Walnut, Enum.Material.Wood, nil)
		add(hand, "Receiver", Vector3.new(0.28, 0.36, 1.04), CFrame.new(0, 0.10, -0.62), metalCol, Enum.Material.Metal, nil)
		add(hand, "UpperBarrel", Vector3.new(1.72, 0.19, 0.19), CFrame.new(0, 0.18, -1.90) * CFrame.Angles(0, math.rad(90), 0), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
		add(hand, "PumpGrip", Vector3.new(0.32, 0.26, 0.70), CFrame.new(0, 0.00, -1.60), P.Walnut, Enum.Material.Wood, nil)
	elseif kind == "SMG" then
		add(hand, "Receiver", Vector3.new(0.26, 0.34, 1.15), CFrame.new(0, 0.08, -0.64), metalCol, Enum.Material.Metal, nil)
		add(hand, "CurvedMag", Vector3.new(0.18, 0.74, 0.24), CFrame.new(0, -0.36, -0.86) * CFrame.Angles(math.rad(-14), 0, 0), P.Obsidian, Enum.Material.Metal, nil)
		add(hand, "Suppressor", Vector3.new(0.75, 0.19, 0.19), CFrame.new(0, 0.10, -1.56) * CFrame.Angles(0, math.rad(90), 0), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif kind == "TommyDrum" then
		add(hand, "TommyStock", Vector3.new(0.24, 0.44, 0.96), CFrame.new(0, 0.04, 0.34), P.Walnut, Enum.Material.Wood, nil)
		add(hand, "TommyReceiver", Vector3.new(0.30, 0.38, 1.48), CFrame.new(0, 0.12, -0.74), P.Gunmetal, Enum.Material.Metal, nil)
		add(hand, "TommyDrum", Vector3.new(0.36, 0.88, 0.88), CFrame.new(0, -0.28, -1.00), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
		add(hand, "TommyBrass", Vector3.new(0.40, 0.30, 0.30), CFrame.new(0, -0.28, -1.00), P.TarnishedBrass, Enum.Material.Metal, Enum.PartType.Cylinder)
		add(hand, "TommyBarrel", Vector3.new(1.45, 0.18, 0.18), CFrame.new(0, 0.14, -2.14) * CFrame.Angles(0, math.rad(90), 0), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif kind == "AssassinRifle" then
		add(hand, "RifleStock", Vector3.new(0.24, 0.44, 0.98), CFrame.new(0, 0.04, 0.32), P.Obsidian, Enum.Material.SmoothPlastic, nil)
		add(hand, "RifleChassis", Vector3.new(0.28, 0.36, 1.95), CFrame.new(0, 0.10, -1.02), P.Gunmetal, Enum.Material.Metal, nil)
		add(hand, "CrimsonRail", Vector3.new(0.30, 0.08, 1.35), CFrame.new(0, 0.24, -0.96), P.DeepRed, Enum.Material.Metal, nil)
		add(hand, "Optic", Vector3.new(1.12, 0.20, 0.20), CFrame.new(0, 0.44, -0.88) * CFrame.Angles(0, math.rad(90), 0), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
		add(hand, "Suppressor", Vector3.new(1.38, 0.22, 0.22), CFrame.new(0, 0.12, -2.62) * CFrame.Angles(0, math.rad(90), 0), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif kind == "Sniper" then
		add(hand, "Stock", Vector3.new(0.24, 0.44, 0.98), CFrame.new(0, 0.04, 0.30), P.Obsidian, Enum.Material.SmoothPlastic, nil)
		add(hand, "Chassis", Vector3.new(0.28, 0.34, 1.62), CFrame.new(0, 0.08, -0.92), metalCol, Enum.Material.Metal, nil)
		add(hand, "Scope", Vector3.new(1.02, 0.19, 0.19), CFrame.new(0, 0.38, -0.84) * CFrame.Angles(0, math.rad(90), 0), P.Obsidian, Enum.Material.Metal, Enum.PartType.Cylinder)
		add(hand, "LongBarrel", Vector3.new(1.88, 0.15, 0.15), CFrame.new(0, 0.10, -2.56) * CFrame.Angles(0, math.rad(90), 0), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif kind == "BossRifle" then
		add(hand, "WalnutStock", Vector3.new(0.26, 0.46, 1.02), CFrame.new(0, 0.04, 0.30), P.Walnut, Enum.Material.Wood, nil)
		add(hand, "Receiver", Vector3.new(0.32, 0.40, 1.44), CFrame.new(0, 0.10, -0.84), P.Obsidian, Enum.Material.Metal, nil)
		add(hand, "BrassTrim", Vector3.new(0.34, 0.09, 1.00), CFrame.new(0, 0.12, -0.84), P.TarnishedBrass, Enum.Material.Metal, nil)
		add(hand, "Mag", Vector3.new(0.19, 0.74, 0.28), CFrame.new(0, -0.38, -1.04) * CFrame.Angles(math.rad(-14), 0, 0), P.Gunmetal, Enum.Material.Metal, nil)
		add(hand, "Barrel", Vector3.new(1.22, 0.19, 0.19), CFrame.new(0, 0.12, -2.12) * CFrame.Angles(0, math.rad(90), 0), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
	else
		add(hand, "Stock", Vector3.new(0.24, 0.44, 0.82), CFrame.new(0, 0.04, 0.26), P.Obsidian, Enum.Material.SmoothPlastic, nil)
		add(hand, "Receiver", Vector3.new(0.28, 0.36, 1.28), CFrame.new(0, 0.08, -0.76), metalCol, Enum.Material.Metal, nil)
		add(hand, "Mag", Vector3.new(0.19, 0.68, 0.26), CFrame.new(0, -0.36, -0.96) * CFrame.Angles(math.rad(-14), 0, 0), P.Obsidian, Enum.Material.Metal, nil)
		add(hand, "Barrel", Vector3.new(1.06, 0.17, 0.17), CFrame.new(0, 0.10, -1.88) * CFrame.Angles(0, math.rad(90), 0), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
end

-- Helper: Sculpted layered tactical & tailored combatant polish (zero neon!)
-- Upgrades ALL Rival NPCs & Comrade NPCs with fierce brows, structured shoulders, wrist cuffs/bracers,
-- belt pouches/holsters, knee guards & tailored boots so every fighter looks sharp up close!
local function addCombatantDetail(
	rig: RigHandle,
	archetype: "Suited" | "Tactical" | "Street" | "Samurai" | "Ninja",
	combatStyle: "Katana" | "DualNinja" | "Melee" | "Pistol" | "Rifle" | "Shield",
	accentCol: Color3
): ()
	local add = rig.AddPart
	rig.Model:SetAttribute("CombatStyle", combatStyle)

	-- Fierce determined eyebrows on Head (gives every fighter sharp, intense expression!)
	if archetype ~= "Ninja" then
		add(rig.Head, "BrowL", Vector3.new(0.28, 0.06, 0.08), CFrame.new(-0.22, 0.22, -0.56) * CFrame.Angles(0, 0, math.rad(-14)), P.HairDark, Enum.Material.SmoothPlastic, nil)
		add(rig.Head, "BrowR", Vector3.new(0.28, 0.06, 0.08), CFrame.new(0.22, 0.22, -0.56) * CFrame.Angles(0, 0, math.rad(14)), P.HairDark, Enum.Material.SmoothPlastic, nil)
	end

	-- Sculpted combat boots / tailored dress shoes with sole trim
	add(rig.LeftFoot, "BootToeL", Vector3.new(0.96, 0.34, 1.18), CFrame.new(0, -0.06, -0.10), P.Obsidian, Enum.Material.Leather, nil)
	add(rig.RightFoot, "BootToeR", Vector3.new(0.96, 0.34, 1.18), CFrame.new(0, -0.06, -0.10), P.Obsidian, Enum.Material.Leather, nil)

	if archetype == "Suited" then
		-- Tailored Mafia / Bodyguard details: lapel brass pin, crisp white shirt cuffs, luxury gold watch, hip holster
		add(rig.Torso, "SyndicateLapelPin", Vector3.new(0.14, 0.14, 0.08), CFrame.new(-0.46, 0.44, -0.56), accentCol, Enum.Material.Metal, nil)
		add(rig.LeftLowerArm, "ShirtCuffL", Vector3.new(0.98, 0.14, 0.98), CFrame.new(0, -0.34, 0), P.OffWhite, Enum.Material.Fabric, nil)
		add(rig.RightLowerArm, "ShirtCuffR", Vector3.new(0.98, 0.14, 0.98), CFrame.new(0, -0.34, 0), P.OffWhite, Enum.Material.Fabric, nil)
		add(rig.LeftLowerArm, "GoldWatch", Vector3.new(1.02, 0.12, 1.02), CFrame.new(0, -0.24, 0), P.TarnishedBrass, Enum.Material.Metal, nil)
		add(rig.LowerTorso, "ConcealedHolster", Vector3.new(0.24, 0.48, 0.40), CFrame.new(1.06, -0.06, 0.06), P.Obsidian, Enum.Material.Leather, nil)
	elseif archetype == "Tactical" then
		-- Armored kneepads, forearm tactical bracers, drop-leg pouch, shoulder morale patch
		add(rig.LeftLowerLeg, "KneePadL", Vector3.new(0.98, 0.42, 0.24), CFrame.new(0, 0.32, -0.46), P.Obsidian, Enum.Material.Metal, nil)
		add(rig.RightLowerLeg, "KneePadR", Vector3.new(0.98, 0.42, 0.24), CFrame.new(0, 0.32, -0.46), P.Obsidian, Enum.Material.Metal, nil)
		add(rig.LeftLowerArm, "TacBracerL", Vector3.new(1.02, 0.48, 1.02), CFrame.new(0, -0.06, 0), P.Gunmetal, Enum.Material.Metal, nil)
		add(rig.RightLowerArm, "TacBracerR", Vector3.new(1.02, 0.48, 1.02), CFrame.new(0, -0.06, 0), P.Gunmetal, Enum.Material.Metal, nil)
		add(rig.RightArm, "ShoulderPatch", Vector3.new(0.10, 0.34, 0.46), CFrame.new(0.50, 0.16, 0), accentCol, Enum.Material.Fabric, nil)
		add(rig.RightLeg, "DropLegPouch", Vector3.new(0.26, 0.56, 0.52), CFrame.new(0.54, 0.02, 0), P.Charcoal, Enum.Material.Fabric, nil)
	elseif archetype == "Street" then
		-- Wrist wraps, belt chain, knee reinforcement
		add(rig.LeftLowerArm, "WristWrapL", Vector3.new(1.00, 0.30, 1.00), CFrame.new(0, -0.24, 0), P.OffWhite, Enum.Material.Fabric, nil)
		add(rig.RightLowerArm, "WristWrapR", Vector3.new(1.00, 0.30, 1.00), CFrame.new(0, -0.24, 0), P.OffWhite, Enum.Material.Fabric, nil)
		add(rig.LowerTorso, "BeltPouch", Vector3.new(0.32, 0.36, 0.34), CFrame.new(-0.98, 0.02, -0.18), P.WornLeather, Enum.Material.Leather, nil)
	elseif archetype == "Samurai" then
		-- Layered Suneate armored shin plates, brass hip buckle, crimson-gold crest trim
		add(rig.LeftLowerLeg, "SuneateL", Vector3.new(1.04, 0.96, 0.24), CFrame.new(0, 0.02, -0.46), P.Gunmetal, Enum.Material.Metal, nil)
		add(rig.RightLowerLeg, "SuneateR", Vector3.new(1.04, 0.96, 0.24), CFrame.new(0, 0.02, -0.46), P.Gunmetal, Enum.Material.Metal, nil)
		add(rig.LeftLowerLeg, "SuneateTrimL", Vector3.new(1.08, 0.14, 0.28), CFrame.new(0, 0.34, -0.47), P.TarnishedBrass, Enum.Material.Metal, nil)
		add(rig.RightLowerLeg, "SuneateTrimR", Vector3.new(1.08, 0.14, 0.28), CFrame.new(0, 0.34, -0.47), P.TarnishedBrass, Enum.Material.Metal, nil)
		add(rig.LowerTorso, "ObiKnot", Vector3.new(0.42, 0.42, 0.24), CFrame.new(0, 0.04, -0.60), P.TarnishedBrass, Enum.Material.Metal, nil)
	elseif archetype == "Ninja" then
		-- Shinobi kunai thigh holster, red waist sash knot, steel shoulder guards
		add(rig.LeftArm, "ShinobiGuardL", Vector3.new(1.06, 0.38, 1.06), CFrame.new(-0.04, 0.28, 0), P.Gunmetal, Enum.Material.Metal, nil)
		add(rig.RightArm, "ShinobiGuardR", Vector3.new(1.06, 0.38, 1.06), CFrame.new(0.04, 0.28, 0), P.Gunmetal, Enum.Material.Metal, nil)
		add(rig.LowerTorso, "ShinobiSash", Vector3.new(2.12, 0.26, 1.14), CFrame.new(0, 0.04, 0), P.DeepRed, Enum.Material.Fabric, nil)
		add(rig.RightLeg, "KunaiHolster", Vector3.new(0.24, 0.56, 0.44), CFrame.new(0.52, 0.06, 0), P.Obsidian, Enum.Material.Leather, nil)
		add(rig.RightLeg, "SpareKunai", Vector3.new(0.10, 0.52, 0.10), CFrame.new(0.62, 0.24, -0.06), P.BrushedSteel, Enum.Material.Metal, nil)
	end
end

-- ============================================================================
-- 1. RIVAL FACTION CHARACTER MODELS (5 Unique R15 Criminal-to-Don Designs)
-- ============================================================================
function MafiaVisualBuilder.BuildRivalRig(
	modelName: string,
	factionId: string,
	isEscort: boolean,
	scale: number,
	spawnCF: CFrame,
	forPreview: boolean?
): RigHandle
	-- Check Studio NPCTemplates override first
	local rivalCandidates: { string } = {}
	if string.find(modelName, "BistroExtortionEnforcer") then
		table.insert(rivalCandidates, "BistroExtortionEnforcer")
	elseif string.find(modelName, "ConvoyAmbusher") then
		table.insert(rivalCandidates, "ConvoyAmbusher")
	elseif string.find(modelName, "GangWarEnforcer") then
		table.insert(rivalCandidates, "GangWarEnforcer")
	elseif string.find(modelName, "MafiaCapoBoss") then
		table.insert(rivalCandidates, "MafiaCapoBoss")
	elseif string.find(modelName, "MafiaEnforcer") then
		table.insert(rivalCandidates, "MafiaEnforcer")
	end

	local combatStyle = "Rifle"
	local weaponKind: "Crowbar" | "Pistol" | "Shotgun" | "SMG" | "Carbine" | "Sniper" | "BossRifle" | "TommyDrum" | "AssassinRifle" = "SMG"
	if factionId == "StreetSkilletGang" then
		table.insert(rivalCandidates, "StreetSkilletGang")
		table.insert(rivalCandidates, "StreetSkillet")
		combatStyle = "Melee"
		weaponKind = "Crowbar"
	elseif factionId == "HarborHookCartel" then
		table.insert(rivalCandidates, "HarborHookCartel")
		table.insert(rivalCandidates, "HarborHook")
		combatStyle = "Pistol"
		weaponKind = "Pistol"
	elseif factionId == "IronCleaverSyndicate" then
		table.insert(rivalCandidates, "IronCleaverSyndicate")
		table.insert(rivalCandidates, "IronCleaver")
		combatStyle = "Rifle"
		weaponKind = "SMG"
	elseif factionId == "ObsidianKnifeOrder" then
		table.insert(rivalCandidates, "ObsidianKnifeOrder")
		table.insert(rivalCandidates, "ObsidianOrder")
		combatStyle = "Rifle"
		weaponKind = "Carbine"
	else
		if isEscort then
			table.insert(rivalCandidates, "CrimsonDonEscort")
			table.insert(rivalCandidates, "DonsEnforcer")
			table.insert(rivalCandidates, "MafiaEnforcer")
			combatStyle = "Rifle"
			weaponKind = "SMG"
		else
			table.insert(rivalCandidates, "TheCrimsonDon")
			table.insert(rivalCandidates, "CrimsonDonEmpire")
			table.insert(rivalCandidates, "CrimsonDon")
			combatStyle = "Rifle"
			weaponKind = "BossRifle"
		end
	end

	local customRig, customTpl = MafiaVisualBuilder.TryBuildFromTemplate(rivalCandidates, modelName, scale, spawnCF, forPreview, combatStyle)
	if customRig then
		if customTpl and customTpl:GetAttribute("AttachDefaultWeapon") == true then
			attachNPCWeapon(customRig, weaponKind, nil)
		end
		return customRig
	end

	if factionId == "StreetSkilletGang" then
		-- EASY: Street Hoodlum — charcoal hoodie, tilted knit beanie, kangaroo pocket, scar, heavy cleaver
		local rig = MafiaVisualBuilder.CreateBaseRig(
			modelName, scale, spawnCF, P.SkinWarm,
			Color3.fromRGB(52, 54, 60), Color3.fromRGB(34, 38, 46),
			Color3.fromRGB(52, 54, 60), nil, 1.0, forPreview
		)
		local add = rig.AddPart
		add(rig.Torso, "HoodCollar", Vector3.new(1.48, 0.38, 0.72), CFrame.new(0, 0.80, 0.34), Color3.fromRGB(42, 44, 50), Enum.Material.Fabric, nil)
		add(rig.Torso, "HoodiePocket", Vector3.new(1.42, 0.56, 0.16), CFrame.new(0, -0.46, -0.52), Color3.fromRGB(42, 44, 50), Enum.Material.Fabric, nil)
		add(rig.Torso, "DrawstringL", Vector3.new(0.06, 0.48, 0.06), CFrame.new(-0.22, 0.46, -0.53), P.OffWhite, Enum.Material.Fabric, nil)
		add(rig.Torso, "DrawstringR", Vector3.new(0.06, 0.48, 0.06), CFrame.new(0.22, 0.46, -0.53), P.OffWhite, Enum.Material.Fabric, nil)
		add(rig.Head, "KnitBeanie", Vector3.new(1.28, 0.58, 1.30), CFrame.new(0, 0.48, 0.06) * CFrame.Angles(math.rad(-10), 0, math.rad(4)), Color3.fromRGB(36, 32, 32), Enum.Material.Fabric, nil)
		add(rig.Head, "BeanieCuff", Vector3.new(1.34, 0.22, 1.34), CFrame.new(0, 0.28, 0.02) * CFrame.Angles(math.rad(-10), 0, math.rad(4)), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Head, "CheekScar", Vector3.new(0.05, 0.26, 0.05), CFrame.new(-0.30, -0.06, -0.57) * CFrame.Angles(0, 0, math.rad(18)), Color3.fromRGB(134, 62, 58), Enum.Material.SmoothPlastic, nil)
		attachNPCWeapon(rig, "Crowbar", nil)
		addCombatantDetail(rig, "Street", "Melee", P.DeepRed)
		return rig

	elseif factionId == "HarborHookCartel" then
		-- MEDIUM: Dockside Gangster — worn brown leather jacket over dark henley, flat dock cap, shades, pistol
		local rig = MafiaVisualBuilder.CreateBaseRig(
			modelName, scale, spawnCF, P.SkinWeathered,
			P.DarkBrown, Color3.fromRGB(30, 34, 40),
			P.DarkBrown, P.Obsidian, 1.0, forPreview
		)
		local add = rig.AddPart
		add(rig.Torso, "InnerShirt", Vector3.new(0.72, 1.54, 0.14), CFrame.new(0, 0.04, -0.49), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Torso, "JacketCollarL", Vector3.new(0.38, 0.56, 0.20), CFrame.new(-0.52, 0.62, -0.48) * CFrame.Angles(0, 0, math.rad(-18)), P.WornLeather, Enum.Material.Leather, nil)
		add(rig.Torso, "JacketCollarR", Vector3.new(0.38, 0.56, 0.20), CFrame.new(0.52, 0.62, -0.48) * CFrame.Angles(0, 0, math.rad(18)), P.WornLeather, Enum.Material.Leather, nil)
		add(rig.LowerTorso, "SideHolster", Vector3.new(0.28, 0.52, 0.42), CFrame.new(-1.08, -0.04, 0.05), P.WornLeather, Enum.Material.Leather, nil)
		add(rig.Head, "DockCapTop", Vector3.new(1.30, 0.38, 1.40), CFrame.new(0, 0.50, 0.04), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Head, "DockCapBrim", Vector3.new(1.14, 0.09, 0.54), CFrame.new(0, 0.32, -0.72) * CFrame.Angles(math.rad(8), 0, 0), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Head, "Shades", Vector3.new(1.12, 0.24, 0.14), CFrame.new(0, 0.08, -0.56), P.Obsidian, Enum.Material.Glass, nil)
		add(rig.Head, "JawStubble", Vector3.new(0.76, 0.28, 0.30), CFrame.new(0, -0.32, -0.44), Color3.fromRGB(48, 38, 34), Enum.Material.Fabric, nil)
		attachNPCWeapon(rig, "Pistol", P.Gunmetal)
		addCombatantDetail(rig, "Street", "Pistol", P.TarnishedBrass)
		return rig

	elseif factionId == "IronCleaverSyndicate" then
		-- HARD: Syndicate Enforcer — tactical chest rig, 3 mag pouches, crimson armband, half-face gaiter, patrol cap, SMG
		local rig = MafiaVisualBuilder.CreateBaseRig(
			modelName, scale, spawnCF, P.SkinWarm,
			P.Slate, P.Charcoal,
			P.Slate, P.Obsidian, 1.0, forPreview
		)
		local add = rig.AddPart
		add(rig.Torso, "ChestRig", Vector3.new(2.02, 1.32, 1.18), CFrame.new(0, 0.04, 0), P.Obsidian, Enum.Material.Fabric, nil)
		for _, mx in ipairs({ -0.50, 0, 0.50 }) do
			add(rig.Torso, "MagPouch", Vector3.new(0.34, 0.54, 0.22), CFrame.new(mx, -0.22, -0.64), P.Charcoal, Enum.Material.Fabric, nil)
		end
		add(rig.LeftArm, "SyndicateBand", Vector3.new(1.06, 0.24, 1.06), CFrame.new(0, 0.04, 0), P.DeepRed, Enum.Material.Fabric, nil)
		add(rig.Head, "FaceGaiter", Vector3.new(1.22, 0.52, 1.22), CFrame.new(0, -0.24, -0.02), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Head, "TacCap", Vector3.new(1.28, 0.40, 1.30), CFrame.new(0, 0.50, 0.02), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Head, "TacBrim", Vector3.new(1.10, 0.08, 0.54), CFrame.new(0, 0.32, -0.70) * CFrame.Angles(math.rad(6), 0, 0), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Head, "CommsCup", Vector3.new(0.18, 0.32, 0.28), CFrame.new(-0.64, 0.04, 0), P.Gunmetal, Enum.Material.Metal, nil)
		attachNPCWeapon(rig, "SMG", P.Gunmetal)
		addCombatantDetail(rig, "Tactical", "Rifle", P.DeepRed)
		return rig

	elseif factionId == "ObsidianKnifeOrder" then
		-- ELITE: Cold Hitman — tailored obsidian trenchcoat, high collar, oxblood tie, slicked hair, aviators, carbine
		local rig = MafiaVisualBuilder.CreateBaseRig(
			modelName, scale, spawnCF, P.SkinPale,
			P.Obsidian, P.Obsidian,
			P.Obsidian, P.Obsidian, 1.0, forPreview
		)
		local add = rig.AddPart
		add(rig.Torso, "ShirtPeek", Vector3.new(0.60, 1.32, 0.14), CFrame.new(0, 0.16, -0.49), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Torso, "OxbloodTie", Vector3.new(0.20, 1.08, 0.16), CFrame.new(0, 0.12, -0.53), P.DeepRed, Enum.Material.Fabric, nil)
		add(rig.Torso, "HighCollarBack", Vector3.new(1.42, 0.48, 0.32), CFrame.new(0, 0.88, 0.40), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Torso, "LapelL", Vector3.new(0.32, 1.08, 0.14), CFrame.new(-0.44, 0.22, -0.52) * CFrame.Angles(0, 0, math.rad(-14)), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Torso, "LapelR", Vector3.new(0.32, 1.08, 0.14), CFrame.new(0.44, 0.22, -0.52) * CFrame.Angles(0, 0, math.rad(14)), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.LowerTorso, "CoatTailBack", Vector3.new(2.04, 1.56, 0.22), CFrame.new(0, -0.78, 0.46), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.LowerTorso, "CoatTailL", Vector3.new(0.20, 1.48, 0.98), CFrame.new(-0.98, -0.74, 0.04), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.LowerTorso, "CoatTailR", Vector3.new(0.20, 1.48, 0.98), CFrame.new(0.98, -0.74, 0.04), P.Obsidian, Enum.Material.Fabric, nil)
		addHairStyle(rig, "Slick", P.HairDark)
		add(rig.Head, "Aviators", Vector3.new(1.12, 0.26, 0.14), CFrame.new(0, 0.08, -0.57), P.Obsidian, Enum.Material.Glass, nil)
		attachNPCWeapon(rig, "Carbine", P.Obsidian)
		addCombatantDetail(rig, "Suited", "Rifle", P.DeepRed)
		return rig

	else
		-- BOSS FACTION: Crimson Don Empire (The Crimson Don Boss OR his Dedicated Mafia Enforcers)
		if isEscort then
			local rig = MafiaVisualBuilder.CreateBaseRig(
				modelName, scale, spawnCF, P.SkinWeathered,
				P.Charcoal, P.Obsidian,
				P.Charcoal, P.Obsidian, 1.0, forPreview
			)
			local add = rig.AddPart
			add(rig.Torso, "Shirt", Vector3.new(0.64, 1.46, 0.14), CFrame.new(0, 0.08, -0.49), P.OffWhite, Enum.Material.Fabric, nil)
			add(rig.Torso, "Tie", Vector3.new(0.20, 1.18, 0.16), CFrame.new(0, 0.04, -0.53), P.DeepRed, Enum.Material.Fabric, nil)
			add(rig.LowerTorso, "CoatSkirt", Vector3.new(2.08, 1.24, 0.22), CFrame.new(0, -0.62, 0.46), P.Charcoal, Enum.Material.Fabric, nil)
			add(rig.Head, "Shades", Vector3.new(1.12, 0.24, 0.14), CFrame.new(0, 0.08, -0.57), P.Obsidian, Enum.Material.Glass, nil)
			add(rig.Head, "FedoraBrim", Vector3.new(0.14, 1.98, 1.98), CFrame.new(0, 0.52, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Fabric, Enum.PartType.Cylinder)
			add(rig.Head, "FedoraCrown", Vector3.new(0.58, 1.32, 1.32), CFrame.new(0, 0.82, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Fabric, Enum.PartType.Cylinder)
			add(rig.Head, "FedoraBand", Vector3.new(0.14, 1.38, 1.38), CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), P.DeepRed, Enum.Material.Fabric, Enum.PartType.Cylinder)
			attachNPCWeapon(rig, "SMG", P.Gunmetal)
			addCombatantDetail(rig, "Suited", "Rifle", P.DeepRed)
			return rig
		else
			-- THE CRIMSON DON: Obsidian Mafia Greatcoat, Fur Collar, Oxblood Silk Tie, Brass Clip, Silver Beard, Classic Fedora
			local rig = MafiaVisualBuilder.CreateBaseRig(
				modelName, scale, spawnCF, P.SkinWeathered,
				P.Charcoal, P.Obsidian,
				P.Obsidian, P.Obsidian, 1.0, forPreview
			)
			local add = rig.AddPart
			add(rig.Torso, "DressShirt", Vector3.new(0.70, 1.54, 0.14), CFrame.new(0, 0.10, -0.49), P.OffWhite, Enum.Material.Fabric, nil)
			add(rig.Torso, "SilkTie", Vector3.new(0.24, 1.26, 0.16), CFrame.new(0, 0.04, -0.53), P.DeepRed, Enum.Material.Fabric, nil)
			add(rig.Torso, "TieClip", Vector3.new(0.28, 0.07, 0.08), CFrame.new(0, -0.04, -0.58), P.TarnishedBrass, Enum.Material.Metal, nil)
			add(rig.Torso, "FurCollar", Vector3.new(2.24, 0.44, 1.18), CFrame.new(0, 0.82, 0.08), Color3.fromRGB(28, 22, 24), Enum.Material.Fabric, nil)
			add(rig.Torso, "RedPocketSq", Vector3.new(0.24, 0.14, 0.08), CFrame.new(0.62, 0.36, -0.53), P.DeepRed, Enum.Material.Fabric, nil)
			add(rig.LowerTorso, "CoatTailBack", Vector3.new(2.22, 1.78, 0.24), CFrame.new(0, -0.88, 0.48), P.Obsidian, Enum.Material.Fabric, nil)
			add(rig.LowerTorso, "CoatTailL", Vector3.new(0.22, 1.72, 1.04), CFrame.new(-1.04, -0.84, 0.04), P.Obsidian, Enum.Material.Fabric, nil)
			add(rig.LowerTorso, "CoatTailR", Vector3.new(0.22, 1.72, 1.04), CFrame.new(1.04, -0.84, 0.04), P.Obsidian, Enum.Material.Fabric, nil)
			add(rig.Head, "SilverBeard", Vector3.new(0.96, 0.38, 0.40), CFrame.new(0, -0.38, -0.40), P.HairSilver, Enum.Material.Fabric, nil)
			add(rig.Head, "Mustache", Vector3.new(0.62, 0.13, 0.14), CFrame.new(0, -0.16, -0.57), P.HairSilver, Enum.Material.Fabric, nil)
			add(rig.Head, "Shades", Vector3.new(1.12, 0.24, 0.14), CFrame.new(0, 0.08, -0.57), P.Obsidian, Enum.Material.Glass, nil)
			add(rig.Head, "DonFedoraBrim", Vector3.new(0.14, 2.18, 2.18), CFrame.new(0, 0.54, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Fabric, Enum.PartType.Cylinder)
			add(rig.Head, "DonFedoraCrown", Vector3.new(0.66, 1.40, 1.40), CFrame.new(0, 0.88, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Fabric, Enum.PartType.Cylinder)
			add(rig.Head, "DonFedoraRibbon", Vector3.new(0.16, 1.46, 1.46), CFrame.new(0, 0.64, 0) * CFrame.Angles(0, 0, math.rad(90)), P.DeepRed, Enum.Material.Fabric, Enum.PartType.Cylinder)
			attachNPCWeapon(rig, "BossRifle", P.Obsidian)
			addCombatantDetail(rig, "Suited", "Rifle", P.TarnishedBrass)
			return rig
		end
	end
end

-- ============================================================================
-- 2. PLAYER BODYGUARD MODELS (7 Distinct R15 Professional Enforcer Designs)
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

	-- Check Studio NPCTemplates override first
	local guardCandidates: { string } = {}
	if string.find(modelName, "PlayerTurfGuard") then
		table.insert(guardCandidates, "TurfGuard")
		table.insert(guardCandidates, "PlayerTurfGuard")
	end
	table.insert(guardCandidates, classId)

	local guardCombatStyle = if classId == "HeavyGuard" or ov.HasRiotPlate
		then "Shield"
		elseif classId == "BasicGuard" and not ov.IsRanged then "Pistol"
		else "Rifle"
	local customRig, customTpl = MafiaVisualBuilder.TryBuildFromTemplate(guardCandidates, modelName, scale, spawnCF, forPreview, guardCombatStyle)
	if customRig then
		if customTpl and customTpl:GetAttribute("AttachDefaultWeapon") == true then
			local wKind: "Crowbar" | "Pistol" | "Shotgun" | "SMG" | "Carbine" | "Sniper" | "BossRifle" | "TommyDrum" | "AssassinRifle" =
				if classId == "HeavyGuard" then "Shotgun"
				elseif classId == "SniperGuard" then "Sniper"
				elseif classId == "BossBodyguard" then "BossRifle"
				elseif classId == "BasicGuard" then (if ov.IsRanged then "SMG" else "Pistol")
				else "Carbine"
			attachNPCWeapon(customRig, wKind, ov.WeaponColor)
			if classId == "HeavyGuard" or ov.HasRiotPlate then
				customRig.AddPart(customRig.LeftLowerArm, "BallisticShield", Vector3.new(0.22, 2.24, 1.44), CFrame.new(-0.62, -0.05, -0.18), P.Gunmetal, Enum.Material.Metal, nil)
				customRig.AddPart(customRig.LeftLowerArm, "ShieldViewport", Vector3.new(0.26, 0.30, 0.78), CFrame.new(-0.62, 0.58, -0.18), Color3.fromRGB(36, 44, 52), Enum.Material.Glass, nil)
			end
		end
		return customRig
	end

	if classId == "HeavyGuard" then
		local suit = ov.OutfitColor or P.Charcoal
		local armor = ov.ArmorColor or Color3.fromRGB(42, 46, 54)
		local helm = ov.HelmetColor or P.Obsidian
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWarm, suit, P.Obsidian, suit, P.Obsidian, 1.0, forPreview)
		local add = rig.AddPart
		add(rig.Torso, "HeavyCarrier", Vector3.new(2.24, 1.56, 1.36), CFrame.new(0, 0.04, 0), armor, Enum.Material.Metal, nil)
		add(rig.Torso, "ThroatGuard", Vector3.new(1.30, 0.34, 1.06), CFrame.new(0, 0.88, 0), armor, Enum.Material.Metal, nil)
		add(rig.LowerTorso, "GroinPlate", Vector3.new(1.18, 0.60, 0.22), CFrame.new(0, -0.26, -0.58), armor, Enum.Material.Metal, nil)
		add(rig.LeftArm, "PauldronL", Vector3.new(1.14, 0.72, 1.14), CFrame.new(-0.08, 0.22, 0), armor, Enum.Material.Metal, nil)
		add(rig.RightArm, "PauldronR", Vector3.new(1.14, 0.72, 1.14), CFrame.new(0.08, 0.22, 0), armor, Enum.Material.Metal, nil)
		add(rig.Head, "RiotHelm", Vector3.new(1.38, 0.78, 1.42), CFrame.new(0, 0.42, 0.04), helm, Enum.Material.Metal, nil)
		add(rig.Head, "RiotVisor", Vector3.new(1.28, 0.44, 0.14), CFrame.new(0, 0.06, -0.68), Color3.fromRGB(22, 26, 32), Enum.Material.Glass, nil)
		add(rig.LeftLowerArm, "BallisticShield", Vector3.new(0.22, 2.24, 1.44), CFrame.new(-0.62, -0.05, -0.18), P.Gunmetal, Enum.Material.Metal, nil)
		add(rig.LeftLowerArm, "ShieldViewport", Vector3.new(0.26, 0.30, 0.78), CFrame.new(-0.62, 0.58, -0.18), Color3.fromRGB(36, 44, 52), Enum.Material.Glass, nil)
		attachNPCWeapon(rig, "Shotgun", ov.WeaponColor or P.Gunmetal)
		addCombatantDetail(rig, "Tactical", "Shield", P.TarnishedBrass)
		return rig

	elseif classId == "AssaultGuard" then
		local suit = ov.OutfitColor or Color3.fromRGB(40, 44, 52)
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWarm, suit, P.Obsidian, suit, P.Obsidian, 1.0, forPreview)
		local add = rig.AddPart
		local vestCol = ov.ArmorColor or P.Obsidian
		add(rig.Torso, "TacVest", Vector3.new(2.06, 1.42, 1.22), CFrame.new(0, 0.02, 0), vestCol, Enum.Material.Fabric, nil)
		for _, mx in ipairs({ -0.52, 0, 0.52 }) do
			add(rig.Torso, "RiflePouch", Vector3.new(0.34, 0.56, 0.24), CFrame.new(mx, -0.26, -0.66), P.Charcoal, Enum.Material.Fabric, nil)
		end
		add(rig.Torso, "RadioUnit", Vector3.new(0.24, 0.48, 0.22), CFrame.new(-0.78, 0.44, 0.62), P.Obsidian, Enum.Material.Metal, nil)
		add(rig.Torso, "RadioAntenna", Vector3.new(0.05, 1.08, 0.05), CFrame.new(-0.78, 1.14, 0.62), P.Obsidian, Enum.Material.Metal, nil)
		local helmCol = ov.HelmetColor or P.Obsidian
		add(rig.Head, "OperatorCap", Vector3.new(1.28, 0.42, 1.30), CFrame.new(0, 0.48, 0.02), helmCol, Enum.Material.Fabric, nil)
		add(rig.Head, "CapBrim", Vector3.new(1.10, 0.08, 0.52), CFrame.new(0, 0.30, -0.70) * CFrame.Angles(math.rad(6), 0, 0), helmCol, Enum.Material.Fabric, nil)
		add(rig.Head, "TacGoggles", Vector3.new(1.16, 0.26, 0.16), CFrame.new(0, 0.08, -0.57), Color3.fromRGB(22, 24, 28), Enum.Material.Glass, nil)
		add(rig.Head, "HeadsetL", Vector3.new(0.18, 0.34, 0.28), CFrame.new(-0.64, 0.04, 0), P.Gunmetal, Enum.Material.Metal, nil)
		add(rig.Head, "HeadsetR", Vector3.new(0.18, 0.34, 0.28), CFrame.new(0.64, 0.04, 0), P.Gunmetal, Enum.Material.Metal, nil)
		attachNPCWeapon(rig, "Carbine", ov.WeaponColor or P.Gunmetal)
		addCombatantDetail(rig, "Tactical", "Rifle", P.TarnishedBrass)
		return rig

	elseif classId == "SniperGuard" then
		local suit = ov.OutfitColor or P.OliveCharcoal
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinPale, suit, P.Charcoal, suit, P.Obsidian, 1.0, forPreview)
		local add = rig.AddPart
		add(rig.Torso, "ReconCapeBack", Vector3.new(2.02, 1.68, 0.18), CFrame.new(0, -0.10, 0.60) * CFrame.Angles(math.rad(6), 0, 0), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Torso, "ShoulderMantle", Vector3.new(2.26, 0.40, 1.24), CFrame.new(0, 0.72, 0.06), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.Torso, "AmmoStrap", Vector3.new(0.22, 2.02, 1.14), CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.rad(36)), P.WornLeather, Enum.Material.Leather, nil)
		if ov.ArmorColor then
			add(rig.Torso, "LightPlate", Vector3.new(1.86, 1.16, 1.18), CFrame.new(0, 0.04, 0), ov.ArmorColor, Enum.Material.Metal, nil)
		end
		local helmCol = ov.HelmetColor or P.Charcoal
		add(rig.Head, "ReconHoodTop", Vector3.new(1.40, 0.52, 1.46), CFrame.new(0, 0.44, 0.08), helmCol, Enum.Material.Fabric, nil)
		add(rig.Head, "ReconHoodSideL", Vector3.new(0.18, 1.06, 1.30), CFrame.new(-0.62, 0.02, 0.08), helmCol, Enum.Material.Fabric, nil)
		add(rig.Head, "ReconHoodSideR", Vector3.new(0.18, 1.06, 1.30), CFrame.new(0.62, 0.02, 0.08), helmCol, Enum.Material.Fabric, nil)
		add(rig.Head, "FaceWrap", Vector3.new(1.18, 0.46, 1.18), CFrame.new(0, -0.26, -0.02), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Head, "RangefinderLens", Vector3.new(0.24, 0.24, 0.32), CFrame.new(0.24, 0.08, -0.62), P.Gunmetal, Enum.Material.Metal, nil)
		attachNPCWeapon(rig, "Sniper", ov.WeaponColor or P.Gunmetal)
		addCombatantDetail(rig, "Tactical", "Rifle", P.TarnishedBrass)
		return rig

	elseif classId == "TacticalGuard" then
		local suit = ov.OutfitColor or P.Charcoal
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWarm, suit, P.Obsidian, suit, P.Obsidian, 1.0, forPreview)
		local add = rig.AddPart
		local vestCol = ov.ArmorColor or P.Slate
		add(rig.Torso, "UtilityRig", Vector3.new(2.06, 1.44, 1.22), CFrame.new(0, 0.02, 0), vestCol, Enum.Material.Fabric, nil)
		add(rig.Torso, "TraumaPack", Vector3.new(1.28, 1.38, 0.58), CFrame.new(0, 0.02, 0.80), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Torso, "MedCrossH", Vector3.new(0.40, 0.12, 0.06), CFrame.new(0, 0.16, 1.10), P.DeepRed, Enum.Material.SmoothPlastic, nil)
		add(rig.Torso, "MedCrossV", Vector3.new(0.12, 0.40, 0.06), CFrame.new(0, 0.16, 1.10), P.DeepRed, Enum.Material.SmoothPlastic, nil)
		add(rig.LeftArm, "MedicArmband", Vector3.new(1.06, 0.30, 1.06), CFrame.new(0, 0.04, 0), P.DeepRed, Enum.Material.Fabric, nil)
		local helmCol = ov.HelmetColor or P.Charcoal
		add(rig.Head, "TacHelmet", Vector3.new(1.36, 0.68, 1.38), CFrame.new(0, 0.44, 0.04), helmCol, Enum.Material.Metal, nil)
		add(rig.Head, "CommsMic", Vector3.new(0.08, 0.08, 0.52), CFrame.new(-0.52, -0.18, -0.40) * CFrame.Angles(0, math.rad(28), 0), P.Obsidian, Enum.Material.Metal, nil)
		attachNPCWeapon(rig, "Carbine", ov.WeaponColor or P.Gunmetal)
		addCombatantDetail(rig, "Tactical", "Rifle", P.DeepRed)
		return rig

	elseif classId == "EliteGuard" then
		local suit = ov.OutfitColor or P.Obsidian
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinPale, suit, P.Obsidian, suit, P.Obsidian, 1.0, forPreview)
		local add = rig.AddPart
		add(rig.Torso, "DressShirt", Vector3.new(0.64, 1.48, 0.14), CFrame.new(0, 0.10, -0.49), P.OffWhite, Enum.Material.Fabric, nil)
		add(rig.Torso, "SlimTie", Vector3.new(0.18, 1.18, 0.16), CFrame.new(0, 0.08, -0.53), P.Obsidian, Enum.Material.Fabric, nil)
		if ov.ArmorColor then
			add(rig.Torso, "UnderVest", Vector3.new(1.94, 1.24, 1.16), CFrame.new(0, 0.02, 0), ov.ArmorColor, Enum.Material.Metal, nil)
		end
		add(rig.Torso, "HighCollar", Vector3.new(1.44, 0.42, 0.38), CFrame.new(0, 0.86, 0.36), suit, Enum.Material.Fabric, nil)
		add(rig.LowerTorso, "CoatTailBack", Vector3.new(2.08, 1.64, 0.22), CFrame.new(0, -0.80, 0.46), suit, Enum.Material.Fabric, nil)
		add(rig.LowerTorso, "CoatTailL", Vector3.new(0.20, 1.56, 1.00), CFrame.new(-0.98, -0.78, 0.04), suit, Enum.Material.Fabric, nil)
		add(rig.LowerTorso, "CoatTailR", Vector3.new(0.20, 1.56, 1.00), CFrame.new(0.98, -0.78, 0.04), suit, Enum.Material.Fabric, nil)
		addHairStyle(rig, "Slick", P.HairDark)
		add(rig.Head, "DarkGlasses", Vector3.new(1.12, 0.24, 0.14), CFrame.new(0, 0.08, -0.57), P.Obsidian, Enum.Material.Glass, nil)
		if ov.HelmetColor then
			add(rig.Head, "EliteHelm", Vector3.new(1.36, 0.60, 1.38), CFrame.new(0, 0.48, 0.04), ov.HelmetColor, Enum.Material.Metal, nil)
		end
		attachNPCWeapon(rig, "Carbine", ov.WeaponColor or P.Obsidian)
		addCombatantDetail(rig, "Suited", "Rifle", P.TarnishedBrass)
		return rig

	elseif classId == "BossBodyguard" then
		local suit = ov.OutfitColor or P.Obsidian
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWeathered, suit, P.Obsidian, suit, P.Obsidian, 1.0, forPreview)
		local add = rig.AddPart
		add(rig.Torso, "DressShirt", Vector3.new(0.70, 1.54, 0.14), CFrame.new(0, 0.10, -0.49), P.OffWhite, Enum.Material.Fabric, nil)
		add(rig.Torso, "UnderbossTie", Vector3.new(0.22, 1.24, 0.16), CFrame.new(0, 0.04, -0.53), P.DeepRed, Enum.Material.Fabric, nil)
		add(rig.Torso, "BrassPin", Vector3.new(0.26, 0.08, 0.08), CFrame.new(0, -0.02, -0.58), P.TarnishedBrass, Enum.Material.Metal, nil)
		add(rig.Torso, "CoatCollar", Vector3.new(2.20, 0.42, 1.16), CFrame.new(0, 0.80, 0.08), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.LowerTorso, "OvercoatBack", Vector3.new(2.16, 1.72, 0.24), CFrame.new(0, -0.84, 0.46), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.LowerTorso, "OvercoatL", Vector3.new(0.22, 1.64, 1.02), CFrame.new(-1.02, -0.80, 0.04), P.Charcoal, Enum.Material.Fabric, nil)
		add(rig.LowerTorso, "OvercoatR", Vector3.new(0.22, 1.64, 1.02), CFrame.new(1.02, -0.80, 0.04), P.Charcoal, Enum.Material.Fabric, nil)
		if ov.ArmorColor then
			add(rig.Torso, "ConcealedPlate", Vector3.new(2.04, 1.26, 1.18), CFrame.new(0, 0.02, 0), ov.ArmorColor, Enum.Material.Metal, nil)
		end
		add(rig.Head, "Shades", Vector3.new(1.12, 0.24, 0.14), CFrame.new(0, 0.08, -0.57), P.Obsidian, Enum.Material.Glass, nil)
		add(rig.Head, "Goatee", Vector3.new(0.52, 0.30, 0.22), CFrame.new(0, -0.34, -0.46), P.HairSilver, Enum.Material.Fabric, nil)
		local hatCol = ov.HelmetColor or P.Obsidian
		add(rig.Head, "BorsalinoBrim", Vector3.new(0.14, 2.12, 2.12), CFrame.new(0, 0.54, 0) * CFrame.Angles(0, 0, math.rad(90)), hatCol, Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(rig.Head, "BorsalinoCrown", Vector3.new(0.64, 1.38, 1.38), CFrame.new(0, 0.86, 0) * CFrame.Angles(0, 0, math.rad(90)), hatCol, Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(rig.Head, "BorsalinoBand", Vector3.new(0.14, 1.44, 1.44), CFrame.new(0, 0.64, 0) * CFrame.Angles(0, 0, math.rad(90)), P.TarnishedBrass, Enum.Material.Fabric, Enum.PartType.Cylinder)
		attachNPCWeapon(rig, "BossRifle", ov.WeaponColor or P.Obsidian)
		addCombatantDetail(rig, "Suited", "Rifle", P.TarnishedBrass)
		return rig

	else
		-- BASIC GUARD: Tailored charcoal 2-piece suit, white dress shirt, narrow black tie, sunglasses, coiled earpiece
		local suit = ov.OutfitColor or P.Charcoal
		local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWarm, suit, suit, suit, P.Obsidian, 1.0, forPreview)
		local add = rig.AddPart
		add(rig.Torso, "DressShirt", Vector3.new(0.68, 1.50, 0.14), CFrame.new(0, 0.08, -0.49), P.OffWhite, Enum.Material.Fabric, nil)
		add(rig.Torso, "BlackTie", Vector3.new(0.18, 1.22, 0.16), CFrame.new(0, 0.04, -0.53), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Torso, "SuitLapelL", Vector3.new(0.30, 1.06, 0.12), CFrame.new(-0.44, 0.18, -0.51) * CFrame.Angles(0, 0, math.rad(-14)), P.Obsidian, Enum.Material.Fabric, nil)
		add(rig.Torso, "SuitLapelR", Vector3.new(0.30, 1.06, 0.12), CFrame.new(0.44, 0.18, -0.51) * CFrame.Angles(0, 0, math.rad(14)), P.Obsidian, Enum.Material.Fabric, nil)
		if ov.ArmorColor then
			add(rig.Torso, "KevlarVest", Vector3.new(2.04, 1.32, 1.20), CFrame.new(0, 0.04, 0), ov.ArmorColor, Enum.Material.Metal, nil)
		end
		addHairStyle(rig, "Parted", P.HairDark)
		add(rig.Head, "Shades", Vector3.new(1.10, 0.24, 0.14), CFrame.new(0, 0.08, -0.57), P.Obsidian, Enum.Material.Glass, nil)
		add(rig.Head, "Earpiece", Vector3.new(0.09, 0.26, 0.09), CFrame.new(0.60, -0.14, 0.04), P.OffWhite, Enum.Material.SmoothPlastic, nil)
		if ov.HelmetColor then
			add(rig.Head, "GuardHelm", Vector3.new(1.34, 0.60, 1.36), CFrame.new(0, 0.46, 0.04), ov.HelmetColor, Enum.Material.Metal, nil)
		end
		if ov.HasRiotPlate then
			add(rig.LeftLowerArm, "CompactShield", Vector3.new(0.20, 1.95, 1.28), CFrame.new(-0.56, -0.05, -0.16), P.Gunmetal, Enum.Material.Metal, nil)
		end
		attachNPCWeapon(rig, if ov.IsRanged then "SMG" else "Pistol", ov.WeaponColor or P.Gunmetal)
		addCombatantDetail(rig, "Suited", if ov.HasRiotPlate then "Shield" elseif ov.IsRanged then "Rifle" else "Pistol", P.TarnishedBrass)
		return rig
	end
end

-- ============================================================================
-- 3. AUTHENTIC R15 STAFF, CITIZENS, NEIGHBORS, MARKET BROKER & COURIERS
-- ============================================================================
function MafiaVisualBuilder.BuildChefRig(
	modelName: string,
	accentCol: Color3,
	scale: number,
	spawnCF: CFrame,
	isProChef: boolean?
): RigHandle
	local chefCandidates: { string } = {}
	if string.find(modelName, "MasterProChef") then
		table.insert(chefCandidates, "MasterProChef")
	elseif string.find(modelName, "EliteSousChef") then
		table.insert(chefCandidates, "EliteSousChef")
	elseif string.find(modelName, "RaiderChef") then
		table.insert(chefCandidates, "RaiderChef")
	elseif string.find(modelName, "WarehouseFetchChef") then
		table.insert(chefCandidates, "WarehouseFetchChef")
	elseif string.find(modelName, "CentralParkChef") then
		table.insert(chefCandidates, "CentralParkChef")
	elseif string.find(modelName, "CapturedRestaurantChef") then
		table.insert(chefCandidates, "CapturedRestaurantChef")
	elseif string.find(modelName, "CrewChef") then
		table.insert(chefCandidates, "CrewChef")
	end
	if isProChef then
		table.insert(chefCandidates, "ProChef")
	end
	table.insert(chefCandidates, "Chef")
	local customRig = MafiaVisualBuilder.TryBuildFromTemplate(chefCandidates, modelName, scale, spawnCF, false, nil)
	if customRig then
		return customRig
	end

	local coatCol = Color3.fromRGB(238, 236, 230)
	local scarfCol = if isProChef then P.TarnishedBrass else P.DeepRed
	local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWarm, coatCol, P.Charcoal, coatCol, nil, 1.0, false)
	local add = rig.AddPart

	-- Double-breasted tailored R15 Chef Jacket with collar, neckerchief, buttons & waist apron
	add(rig.Torso, "MandarinCollar", Vector3.new(1.16, 0.30, 1.08), CFrame.new(0, 0.82, 0), coatCol, Enum.Material.Fabric, nil)
	add(rig.Torso, "Neckerchief", Vector3.new(0.64, 0.38, 0.22), CFrame.new(0, 0.68, -0.49), scarfCol, Enum.Material.Fabric, nil)
	for row = 0, 2 do
		local y = 0.28 - row * 0.34
		add(rig.Torso, "BtnL_" .. row, Vector3.new(0.10, 0.10, 0.08), CFrame.new(-0.26, y, -0.52), P.Obsidian, Enum.Material.SmoothPlastic, nil)
		add(rig.Torso, "BtnR_" .. row, Vector3.new(0.10, 0.10, 0.08), CFrame.new(0.26, y, -0.52), P.Obsidian, Enum.Material.SmoothPlastic, nil)
	end
	add(rig.LowerTorso, "ChefApron", Vector3.new(2.08, 1.24, 1.14), CFrame.new(0, -0.42, -0.02), accentCol, Enum.Material.Fabric, nil)
	add(rig.LowerTorso, "ApronTowel", Vector3.new(0.34, 0.64, 0.16), CFrame.new(0.72, -0.34, -0.56), P.OffWhite, Enum.Material.Fabric, nil)

	-- Sculpted pleated multi-puff Chef Toque + Hair + Chef Mustache
	add(rig.Head, "SideHair", Vector3.new(1.22, 0.32, 1.24), CFrame.new(0, 0.28, 0.08), P.HairDark, Enum.Material.SmoothPlastic, nil)
	add(rig.Head, "ToqueBand", Vector3.new(0.46, 1.24, 1.24), CFrame.new(0, 0.66, 0) * CFrame.Angles(0, 0, math.rad(90)), coatCol, Enum.Material.Fabric, Enum.PartType.Cylinder)
	add(rig.Head, "ToqueCrown", Vector3.new(0.56, 1.48, 1.48), CFrame.new(0, 1.06, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(246, 244, 240), Enum.Material.Fabric, Enum.PartType.Cylinder)
	add(rig.Head, "ToquePuffL", Vector3.new(0.72, 0.64, 0.72), CFrame.new(-0.34, 1.24, 0), Color3.fromRGB(246, 244, 240), Enum.Material.Fabric, Enum.PartType.Ball)
	add(rig.Head, "ToquePuffR", Vector3.new(0.72, 0.64, 0.72), CFrame.new(0.34, 1.24, 0), Color3.fromRGB(246, 244, 240), Enum.Material.Fabric, Enum.PartType.Ball)
	if isProChef then
		add(rig.Head, "ProTrim", Vector3.new(0.12, 1.30, 1.30), CFrame.new(0, 0.52, 0) * CFrame.Angles(0, 0, math.rad(90)), P.TarnishedBrass, Enum.Material.Metal, Enum.PartType.Cylinder)
		add(rig.Head, "ChefMustache", Vector3.new(0.54, 0.12, 0.12), CFrame.new(0, -0.14, -0.57), P.HairDark, Enum.Material.Fabric, nil)
	end

	-- Stainless steel sauté pan (or Golden Pro Spatula!) held in RightHand
	add(rig.RightHand, "PanHandle", Vector3.new(0.12, 0.12, 0.92), CFrame.new(0, -0.02, -0.52), P.Obsidian, Enum.Material.SmoothPlastic, nil)
	add(rig.RightHand, "SteelPan", Vector3.new(0.20, 0.92, 0.92), CFrame.new(0, -0.02, -1.18) * CFrame.Angles(0, 0, math.rad(90)), if isProChef then P.TarnishedBrass else P.BrushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
	return rig
end

function MafiaVisualBuilder.BuildWaiterRig(
	modelName: string,
	isFemale: boolean,
	scale: number,
	spawnCF: CFrame
): RigHandle
	local waiterCandidates = if isFemale
		then { "WaiterFemale", "Waitress", "Waiter" }
		else { "WaiterMale", "Waiter" }
	local customRig, customTpl = MafiaVisualBuilder.TryBuildFromTemplate(waiterCandidates, modelName, scale, spawnCF, false, nil)
	if customRig then
		if customTpl and customTpl:GetAttribute("AttachDefaultProp") == true then
			customRig.AddPart(customRig.RightHand, "SilverTray", Vector3.new(0.10, 1.72, 1.72), CFrame.new(0, 0.12, -0.68) * CFrame.Angles(0, 0, math.rad(90)), P.BrushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
			customRig.AddPart(customRig.RightHand, "TrayCloche", Vector3.new(1.06, 0.64, 1.06), CFrame.new(0, 0.44, -0.68), Color3.fromRGB(206, 212, 222), Enum.Material.Metal, Enum.PartType.Ball)
			customRig.AddPart(customRig.RightHand, "ClocheKnob", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, 0.80, -0.68), P.TarnishedBrass, Enum.Material.Metal, Enum.PartType.Ball)
		end
		return customRig
	end

	local vestCol = P.Obsidian
	local shirtCol = Color3.fromRGB(240, 238, 232)
	local skinCol = if isFemale then P.SkinPale else P.SkinWarm
	local hairCol = if isFemale then P.DarkBrown else P.HairDark
	local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, skinCol, vestCol, P.Charcoal, shirtCol, P.OffWhite, 1.0, false)
	local add = rig.AddPart

	add(rig.Torso, "ShirtFront", Vector3.new(0.72, 1.28, 0.14), CFrame.new(0, 0.18, -0.49), shirtCol, Enum.Material.Fabric, nil)
	add(rig.Torso, "BowTie", Vector3.new(0.44, 0.18, 0.12), CFrame.new(0, 0.72, -0.54), P.DeepRed, Enum.Material.Fabric, nil)
	add(rig.Torso, "VestLapelL", Vector3.new(0.24, 0.92, 0.12), CFrame.new(-0.38, 0.20, -0.51) * CFrame.Angles(0, 0, math.rad(-14)), P.Charcoal, Enum.Material.Fabric, nil)
	add(rig.Torso, "VestLapelR", Vector3.new(0.24, 0.92, 0.12), CFrame.new(0.38, 0.20, -0.51) * CFrame.Angles(0, 0, math.rad(14)), P.Charcoal, Enum.Material.Fabric, nil)
	add(rig.LowerTorso, "BistroApron", Vector3.new(2.04, 1.18, 1.12), CFrame.new(0, -0.40, -0.02), shirtCol, Enum.Material.Fabric, nil)

	addHairStyle(rig, if isFemale then "Bun" else "Swept", hairCol)

	-- Polished silver serving tray & cloche carried naturally in RightHand!
	add(rig.RightHand, "SilverTray", Vector3.new(0.10, 1.72, 1.72), CFrame.new(0, 0.12, -0.68) * CFrame.Angles(0, 0, math.rad(90)), P.BrushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
	add(rig.RightHand, "TrayCloche", Vector3.new(1.06, 0.64, 1.06), CFrame.new(0, 0.44, -0.68), Color3.fromRGB(206, 212, 222), Enum.Material.Metal, Enum.PartType.Ball)
	add(rig.RightHand, "ClocheKnob", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, 0.80, -0.68), P.TarnishedBrass, Enum.Material.Metal, Enum.PartType.Ball)
	return rig
end

-- 8 Distinct Authentic Roblox R15 Citizen & Neighbor Character Wardrobes!
local CUSTOMER_WARDROBES: { { Coat: Color3, Pants: Color3, Accent: Color3, Skin: Color3, Hair: Color3, HairStyle: "Slick" | "Swept" | "Bun" | "Bob" | "Spiky" | "Parted", Style: string } } = {
	{ Coat = Color3.fromRGB(132, 104, 76), Pants = Color3.fromRGB(36, 38, 46), Accent = Color3.fromRGB(128, 34, 42), Skin = P.SkinWarm, Hair = P.HairDark, HairStyle = "Swept", Style = "Trench" },
	{ Coat = Color3.fromRGB(44, 56, 74), Pants = Color3.fromRGB(28, 32, 40), Accent = P.OffWhite, Skin = P.SkinPale, Hair = P.DarkBrown, HairStyle = "Bun", Style = "Handbag" },
	{ Coat = Color3.fromRGB(58, 68, 52), Pants = Color3.fromRGB(40, 46, 58), Accent = Color3.fromRGB(158, 126, 84), Skin = P.SkinWeathered, Hair = P.HairDark, HairStyle = "Spiky", Style = "Bomber" },
	{ Coat = Color3.fromRGB(98, 34, 44), Pants = Color3.fromRGB(28, 30, 36), Accent = P.TarnishedBrass, Skin = P.SkinPale, Hair = P.HairSilver, HairStyle = "Parted", Style = "Critic" },
	{ Coat = Color3.fromRGB(54, 40, 34), Pants = Color3.fromRGB(34, 44, 62), Accent = P.BrushedSteel, Skin = P.SkinWarm, Hair = P.HairDark, HairStyle = "Spiky", Style = "Biker" },
	{ Coat = Color3.fromRGB(192, 182, 162), Pants = Color3.fromRGB(48, 54, 68), Accent = Color3.fromRGB(72, 108, 86), Skin = P.SkinPale, Hair = Color3.fromRGB(92, 54, 34), HairStyle = "Bob", Style = "Student" },
	{ Coat = Color3.fromRGB(38, 42, 52), Pants = Color3.fromRGB(26, 28, 34), Accent = P.TarnishedBrass, Skin = P.SkinWeathered, Hair = P.HairDark, HairStyle = "Slick", Style = "Banker" },
	{ Coat = Color3.fromRGB(66, 74, 88), Pants = Color3.fromRGB(32, 36, 44), Accent = Color3.fromRGB(142, 42, 46), Skin = P.SkinWarm, Hair = P.DarkBrown, HairStyle = "Swept", Style = "Hoodie" },
}

function MafiaVisualBuilder.BuildCustomerRig(
	modelName: string,
	styleIdx: number,
	scale: number,
	spawnCF: CFrame
): RigHandle
	local slotIdx = ((styleIdx - 1) % #CUSTOMER_WARDROBES) + 1
	local w = CUSTOMER_WARDROBES[slotIdx]

	local citizenCandidates = {
		"Citizen_" .. tostring(slotIdx),
		"Citizen_" .. w.Style,
		"Customer_" .. tostring(slotIdx),
		"Customer_" .. w.Style,
		"Citizen",
		"Customer",
	}
	local customRig = MafiaVisualBuilder.TryBuildFromTemplate(citizenCandidates, modelName, scale, spawnCF, false, nil)
	if customRig then
		return customRig
	end

	local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, w.Skin, w.Coat, w.Pants, w.Coat, nil, 1.0, false)
	local add = rig.AddPart

	add(rig.Torso, "InnerShirt", Vector3.new(0.72, 1.44, 0.14), CFrame.new(0, 0.08, -0.49), P.OffWhite, Enum.Material.Fabric, nil)
	add(rig.Torso, "JacketCollar", Vector3.new(1.78, 0.30, 1.08), CFrame.new(0, 0.78, 0.04), w.Coat, Enum.Material.Fabric, nil)

	if w.Style == "Trench" then
		add(rig.Torso, "Scarf", Vector3.new(1.22, 0.30, 1.16), CFrame.new(0, 0.84, -0.04), w.Accent, Enum.Material.Fabric, nil)
		add(rig.LowerTorso, "CoatTail", Vector3.new(1.98, 1.24, 0.20), CFrame.new(0, -0.62, 0.44), w.Coat, Enum.Material.Fabric, nil)
	elseif w.Style == "Critic" or w.Style == "Banker" then
		add(rig.Torso, "NeckTie", Vector3.new(0.18, 1.14, 0.14), CFrame.new(0, 0.06, -0.53), w.Accent, Enum.Material.Fabric, nil)
		add(rig.Head, "Spectacles", Vector3.new(1.06, 0.22, 0.12), CFrame.new(0, 0.08, -0.56), P.Charcoal, Enum.Material.Glass, nil)
		if w.Style == "Banker" then
			add(rig.Head, "HatBrim", Vector3.new(0.12, 1.92, 1.92), CFrame.new(0, 0.52, 0) * CFrame.Angles(0, 0, math.rad(90)), w.Coat, Enum.Material.Fabric, Enum.PartType.Cylinder)
			add(rig.Head, "HatCrown", Vector3.new(0.52, 1.26, 1.26), CFrame.new(0, 0.78, 0) * CFrame.Angles(0, 0, math.rad(90)), w.Coat, Enum.Material.Fabric, Enum.PartType.Cylinder)
		end
	elseif w.Style == "Handbag" then
		add(rig.Torso, "PurseStrap", Vector3.new(0.12, 1.72, 1.12), CFrame.new(0.72, -0.10, 0) * CFrame.Angles(0, 0, math.rad(16)), P.WornLeather, Enum.Material.Leather, nil)
		add(rig.LowerTorso, "Handbag", Vector3.new(0.36, 0.74, 0.86), CFrame.new(1.02, -0.34, 0.12), P.WornLeather, Enum.Material.Leather, nil)
		add(rig.Head, "Glasses", Vector3.new(1.04, 0.22, 0.12), CFrame.new(0, 0.08, -0.56), P.DarkBrown, Enum.Material.Glass, nil)
	elseif w.Style == "Student" then
		add(rig.Torso, "Backpack", Vector3.new(1.26, 1.32, 0.54), CFrame.new(0, -0.02, 0.72), w.Accent, Enum.Material.Fabric, nil)
		add(rig.Torso, "PackPocket", Vector3.new(0.92, 0.56, 0.16), CFrame.new(0, -0.26, 1.02), P.WornLeather, Enum.Material.Leather, nil)
	elseif w.Style == "Biker" then
		add(rig.Torso, "LeatherLapelL", Vector3.new(0.34, 0.62, 0.16), CFrame.new(-0.48, 0.42, -0.50) * CFrame.Angles(0, 0, math.rad(-18)), P.Obsidian, Enum.Material.Leather, nil)
		add(rig.Torso, "LeatherLapelR", Vector3.new(0.34, 0.62, 0.16), CFrame.new(0.48, 0.42, -0.50) * CFrame.Angles(0, 0, math.rad(18)), P.Obsidian, Enum.Material.Leather, nil)
		add(rig.Head, "Shades", Vector3.new(1.08, 0.24, 0.14), CFrame.new(0, 0.08, -0.57), P.Obsidian, Enum.Material.Glass, nil)
	elseif w.Style == "Hoodie" then
		add(rig.Torso, "HoodBack", Vector3.new(1.40, 0.36, 0.66), CFrame.new(0, 0.78, 0.32), w.Coat, Enum.Material.Fabric, nil)
		add(rig.Head, "HeadphoneBand", Vector3.new(1.36, 0.14, 0.22), CFrame.new(0, 0.62, 0), w.Accent, Enum.Material.Metal, nil)
		add(rig.Head, "EarCupL", Vector3.new(0.22, 0.42, 0.42), CFrame.new(-0.64, 0.06, 0), P.Obsidian, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		add(rig.Head, "EarCupR", Vector3.new(0.22, 0.42, 0.42), CFrame.new(0.64, 0.06, 0), P.Obsidian, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	elseif w.Style == "Bomber" then
		add(rig.Head, "KnitCap", Vector3.new(1.26, 0.50, 1.28), CFrame.new(0, 0.48, 0.06) * CFrame.Angles(math.rad(-8), 0, 0), P.Charcoal, Enum.Material.Fabric, nil)
	end

	if w.Style ~= "Bomber" and w.Style ~= "Banker" then
		addHairStyle(rig, w.HairStyle, w.Hair)
	end
	return rig
end

function MafiaVisualBuilder.BuildMarketBrokerRig(modelName: string, spawnCF: CFrame): RigHandle
	local customRig = MafiaVisualBuilder.TryBuildFromTemplate({ "MarketBroker", "CentralMarketTrader", "MarketSyndicateBroker" }, modelName, 1.08, spawnCF, true, nil)
	if customRig then
		return customRig
	end

	local rig = MafiaVisualBuilder.CreateBaseRig(modelName, 1.08, spawnCF, P.SkinWeathered, P.Obsidian, P.Charcoal, P.Obsidian, P.WornLeather, 1.0, true)
	local add = rig.AddPart
	add(rig.Torso, "DressShirt", Vector3.new(0.72, 1.50, 0.14), CFrame.new(0, 0.08, -0.49), P.OffWhite, Enum.Material.Fabric, nil)
	add(rig.Torso, "Cravat", Vector3.new(0.30, 0.80, 0.18), CFrame.new(0, 0.28, -0.54), P.DeepRed, Enum.Material.Fabric, nil)
	add(rig.Torso, "WatchChain", Vector3.new(0.82, 0.08, 0.10), CFrame.new(0.30, -0.52, -0.54) * CFrame.Angles(0, 0, math.rad(-14)), P.TarnishedBrass, Enum.Material.Metal, nil)
	add(rig.Head, "Shades", Vector3.new(1.12, 0.24, 0.14), CFrame.new(0, 0.08, -0.57), P.Obsidian, Enum.Material.Glass, nil)
	add(rig.Head, "Mustache", Vector3.new(0.54, 0.13, 0.14), CFrame.new(0, -0.16, -0.57), P.HairSilver, Enum.Material.Fabric, nil)
	add(rig.Head, "HatBrim", Vector3.new(0.14, 2.08, 2.08), CFrame.new(0, 0.54, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Charcoal, Enum.Material.Fabric, Enum.PartType.Cylinder)
	add(rig.Head, "HatCrown", Vector3.new(0.64, 1.36, 1.36), CFrame.new(0, 0.86, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Charcoal, Enum.Material.Fabric, Enum.PartType.Cylinder)
	add(rig.Head, "HatRibbon", Vector3.new(0.14, 1.42, 1.42), CFrame.new(0, 0.64, 0) * CFrame.Angles(0, 0, math.rad(90)), P.TarnishedBrass, Enum.Material.Fabric, Enum.PartType.Cylinder)
	return rig
end

-- Helper: Poses an R15 rider naturally onto the 3D Street Delivery Motorbike chassis with spinning wheels & cargo crate
local function mountRiderOnMotorbike(rig: RigHandle, teamCol: Color3, scale: number): BasePart
	local add = rig.AddPart
	local root = rig.Root

	-- Pose R15 rider shoulders, elbows, hips & knees naturally gripping handlebars & straddling seat!
	local function setJointAngle(part: BasePart, jointName: string, rot: CFrame): ()
		local m = part:FindFirstChild(jointName)
		if m and m:IsA("Motor6D") then
			m.C0 = m.C0 * rot
		end
	end
	setJointAngle(rig.LeftArm, "LeftShoulder", CFrame.Angles(math.rad(62), math.rad(12), 0))
	setJointAngle(rig.LeftLowerArm, "LeftElbow", CFrame.Angles(math.rad(18), 0, 0))
	setJointAngle(rig.RightArm, "RightShoulder", CFrame.Angles(math.rad(62), math.rad(-12), 0))
	setJointAngle(rig.RightLowerArm, "RightElbow", CFrame.Angles(math.rad(18), 0, 0))
	setJointAngle(rig.LeftLeg, "LeftHip", CFrame.Angles(math.rad(56), 0, math.rad(-14)))
	setJointAngle(rig.LeftLowerLeg, "LeftKnee", CFrame.Angles(math.rad(-48), 0, 0))
	setJointAngle(rig.RightLeg, "RightHip", CFrame.Angles(math.rad(56), 0, math.rad(14)))
	setJointAngle(rig.RightLowerLeg, "RightKnee", CFrame.Angles(math.rad(-48), 0, 0))

	-- Propagate posed Motor6D CFrames immediately so Edit-mode previews & initial frames render cleanly seated!
	local R15_POSE_ORDER = {
		{ "HumanoidRootPart", "LowerTorso", "Root" },
		{ "LowerTorso", "UpperTorso", "Waist" },
		{ "UpperTorso", "Head", "Neck" },
		{ "UpperTorso", "LeftUpperArm", "LeftShoulder" },
		{ "LeftUpperArm", "LeftLowerArm", "LeftElbow" },
		{ "LeftLowerArm", "LeftHand", "LeftWrist" },
		{ "UpperTorso", "RightUpperArm", "RightShoulder" },
		{ "RightUpperArm", "RightLowerArm", "RightElbow" },
		{ "RightLowerArm", "RightHand", "RightWrist" },
		{ "LowerTorso", "LeftUpperLeg", "LeftHip" },
		{ "LeftUpperLeg", "LeftLowerLeg", "LeftKnee" },
		{ "LeftLowerLeg", "LeftFoot", "LeftAnkle" },
		{ "LowerTorso", "RightUpperLeg", "RightHip" },
		{ "RightUpperLeg", "RightLowerLeg", "RightKnee" },
		{ "RightLowerLeg", "RightFoot", "RightAnkle" },
	}
	for _, spec in ipairs(R15_POSE_ORDER) do
		local p0 = rig.Model:FindFirstChild(spec[1])
		local p1 = rig.Model:FindFirstChild(spec[2])
		if p0 and p0:IsA("BasePart") and p1 and p1:IsA("BasePart") then
			local m = p1:FindFirstChild(spec[3])
			if m and m:IsA("Motor6D") then
				p1.CFrame = p0.CFrame * m.C0 * m.C1:Inverse()
			end
		end
	end
	for _, acc in ipairs(rig.Model:GetChildren()) do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local weld = handle:FindFirstChildOfClass("Weld")
				if weld and weld.Part0 == handle and weld.Part1 then
					handle.CFrame = weld.Part1.CFrame * weld.C1 * weld.C0:Inverse()
				elseif weld and weld.Part1 == handle and weld.Part0 then
					handle.CFrame = weld.Part0.CFrame * weld.C0 * weld.C1:Inverse()
				end
			end
		end
	end

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
		tire.CanCollide = false; tire.CanTouch = false; tire.CanQuery = false; tire.Massless = true
		tire.Parent = rig.Model

		local m = Instance.new("Motor6D")
		m.Name = jointName; m.Part0 = root; m.Part1 = tire
		m.C0 = CFrame.new(0, wheelY * scale, zOff * scale); m.C1 = CFrame.new()
		m.Parent = root

		local rim = Instance.new("Part")
		rim.Name = jointName .. "_Rim"; rim.Shape = Enum.PartType.Cylinder
		rim.Size = Vector3.new(0.92, 1.75, 1.75) * scale; rim.CFrame = tire.CFrame
		rim.Color = chrome; rim.Material = Enum.Material.Metal
		rim.CanCollide = false; rim.CanTouch = false; rim.CanQuery = false; rim.Massless = true
		rim.Parent = rig.Model
		local rw = Instance.new("WeldConstraint"); rw.Part0 = tire; rw.Part1 = rim; rw.Parent = rim

		local spoke = Instance.new("Part")
		spoke.Name = jointName .. "_Spoke"
		spoke.Size = Vector3.new(0.98, 0.24, 1.72) * scale; spoke.CFrame = tire.CFrame
		spoke.Color = teamCol; spoke.Material = Enum.Material.Metal
		spoke.CanCollide = false; spoke.CanTouch = false; spoke.CanQuery = false; spoke.Massless = true
		spoke.Parent = rig.Model
		local sw = Instance.new("WeldConstraint"); sw.Part0 = tire; sw.Part1 = spoke; sw.Parent = spoke
	end

	makeSpinWheel("FrontWheelJoint", -3.25)
	makeSpinWheel("RearWheelJoint", 2.95)

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

	add(root, "CargoRack", Vector3.new(1.92, 0.18, 2.10), CFrame.new(0, -0.68, 2.65), darkSteel, Enum.Material.Metal, nil)
	local crate = add(root, "CarriedCargoCrate", Vector3.new(1.82, 1.48, 1.88), CFrame.new(0, 0.16, 2.65), P.Walnut, Enum.Material.WoodPlanks, nil)
	crate.Transparency = 1

	CollectionService:AddTag(rig.Model, "AnimatedMotorbikeWheels")
	return crate
end

-- Realistic R15 Leather-Jacket Delivery Rider seated on a sculpted 3D Street Delivery Motorbike with spinning wheels & cargo crate!
function MafiaVisualBuilder.BuildMotorbikeCourierRig(
	modelName: string,
	teamCol: Color3,
	scale: number,
	spawnCF: CFrame
): (RigHandle, BasePart)
	local bikeCandidates = if string.find(modelName, "SmugglerConvoy")
		then { "SmugglerConvoy", "MotorbikeCourier", "BikeCourier" }
		else { "MotorbikeCourier", "BikeCourier" }
	local customRig = MafiaVisualBuilder.TryBuildFromTemplate(bikeCandidates, modelName, scale, spawnCF, false, nil)
	if customRig then
		-- If the Studio template already includes its own custom motorbike wheels, preserve them;
		-- otherwise mount our real Roblox R15 rider cleanly onto the 3D spinning-wheel motorbike!
		if customRig.Root:FindFirstChild("FrontWheelJoint") or customRig.Root:FindFirstChild("RearWheelJoint") then
			local existingCrate = customRig.Model:FindFirstChild("CarriedCargoCrate", true)
			local cratePart: BasePart
			if existingCrate and existingCrate:IsA("BasePart") then
				cratePart = existingCrate
			else
				cratePart = customRig.AddPart(customRig.Root, "CarriedCargoCrate", Vector3.new(1.5, 1.2, 1.5), CFrame.new(0, 0.2, 2.2), P.Walnut, Enum.Material.WoodPlanks, nil)
				cratePart.Transparency = 1
			end
			CollectionService:AddTag(customRig.Model, "AnimatedMotorbikeWheels")
			return customRig, cratePart
		end
		local mountedCrate = mountRiderOnMotorbike(customRig, teamCol, scale)
		return customRig, mountedCrate
	end

	local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, P.SkinWarm, P.Obsidian, P.Charcoal, P.Obsidian, P.WornLeather, 1.0, false)
	local add = rig.AddPart

	-- Moto jacket stripes + sleek full-face helmet with dark visor
	add(rig.Torso, "MotoStripeL", Vector3.new(0.16, 1.40, 1.06), CFrame.new(-0.78, 0.06, 0), teamCol, Enum.Material.Leather, nil)
	add(rig.Torso, "MotoStripeR", Vector3.new(0.16, 1.40, 1.06), CFrame.new(0.78, 0.06, 0), teamCol, Enum.Material.Leather, nil)
	add(rig.Head, "MotoHelmet", Vector3.new(1.46, 1.38, 1.52), CFrame.new(0, 0.12, 0.04), P.Charcoal, Enum.Material.Metal, Enum.PartType.Ball)
	add(rig.Head, "HelmetStripe", Vector3.new(0.22, 1.40, 1.56), CFrame.new(0, 0.14, 0.04), teamCol, Enum.Material.SmoothPlastic, nil)
	add(rig.Head, "HelmetVisor", Vector3.new(1.28, 0.44, 0.40), CFrame.new(0, 0.08, -0.62), P.Obsidian, Enum.Material.Glass, nil)

	local crate = mountRiderOnMotorbike(rig, teamCol, scale)
	return rig, crate
end

-- ============================================================================
-- 4. ARTICULATED TACTICAL DEATH ANIMATION SYSTEM (R15 Rivals, Guards & Mafia)
-- ============================================================================
local ACTIVE_COMBAT_TAGS = {
	"RivalAIUnit",
	"MafiaUnit",
	"ApexMafiaUnit",
	"RivalSamuraiUnit",
	"PenthouseBossUnit",
	"MercenaryMafiaUnit",
	"PlayerBodyguardUnit",
	"TurfGuardUnit",
	"AnimatedRaiderLimbs",
}

local function findDeathFloorY(model: Model, root: BasePart, hum: Humanoid): number
	local ignore: { Instance } = { model }
	for _, folderName in ipairs({ "RivalAIUnits", "PlayerBodyguards", "MafiaSyndicateUnits", "TurfNPCs", "UrbanTurfForces", "CentralParkRivalSamurai", "ApexMafiaUnits", "MercenaryMafiaUnits" }) do
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

	local dropModel = Instance.new("Model")
	dropModel.Name = "DroppedNPCWeapon"
	local primary: BasePart? = nil
	for _, wp in ipairs(weaponParts) do
		local clone = wp:Clone()
		clone.Anchored = false
		clone.CanCollide = (primary == nil)
		clone.CanTouch = false
		clone.CanQuery = false
		clone.Massless = (primary ~= nil)
		for _, ch in ipairs(clone:GetChildren()) do
			if ch:IsA("WeldConstraint") or ch:IsA("Motor6D") then
				ch:Destroy()
			end
		end
		clone.Parent = dropModel
		if not primary then
			primary = clone
		else
			local w = Instance.new("WeldConstraint")
			w.Part0 = primary
			w.Part1 = clone
			w.Parent = clone
		end
		wp.Transparency = 1
	end

	if primary then
		dropModel.PrimaryPart = primary
		dropModel.Parent = Workspace
		local sideVec = Vector3.new(-hitDir.Z, 0, hitDir.X) * sideSign
		primary.AssemblyLinearVelocity = hitDir * 7.5 + sideVec * 4.5 + Vector3.new(0, 6.0, 0)
		primary.AssemblyAngularVelocity = Vector3.new(math.random(-7, 7), math.random(-7, 7), math.random(-7, 7))
		task.delay(2.75, function()
			if dropModel.Parent then
				dropModel:Destroy()
			end
		end)
	end
end

function MafiaVisualBuilder.PlayDeathSequence(
	model: Model,
	isBoss: boolean?,
	onGroundImpact: ((impactPos: Vector3) -> ())?
): ()
	if not model.Parent or model:GetAttribute("IsDying") == true then
		return
	end
	model:SetAttribute("IsDying", true)

	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not hum then
		task.delay(0.25, function()
			if model.Parent then model:Destroy() end
		end)
		return
	end

	for _, tagName in ipairs(ACTIVE_COMBAT_TAGS) do
		if CollectionService:HasTag(model, tagName) then
			CollectionService:RemoveTag(model, tagName)
		end
	end

	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BillboardGui") then
			desc.Enabled = false
		end
	end

	local scale = tonumber(model:GetAttribute("BaseScale")) or 1.0
	local floorY = findDeathFloorY(model, root, hum)
	local hitAttr = model:GetAttribute("LastHitDir")
	local hitDir = if typeof(hitAttr) == "Vector3" and hitAttr.Magnitude > 0.05
		then hitAttr.Unit
		else -root.CFrame.LookVector
	local flatHit = Vector3.new(hitDir.X, 0, hitDir.Z)
	if flatHit.Magnitude < 0.05 then
		flatHit = Vector3.new(0, 0, 1)
	else
		flatHit = flatHit.Unit
	end

	local style = if isBoss then 2 else math.random(1, 3)
	local sideSign = if math.random() < 0.5 then -1 else 1

	dropNPCWeaponOnDeath(model, flatHit, sideSign)

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

-- Triggers a synchronized 60 FPS realistic weapon-matched fighting animation (3-hit Katana/Ninja combos,
-- rifle/pistol recoil kicks, or cleaver swings) on ANY Rival or Comrade NPC!
function MafiaVisualBuilder.TriggerAttackAnim(model: Model): ()
	if not model.Parent then return end
	local nextStep = ((tonumber(model:GetAttribute("AttackCombo")) or 0) % 3) + 1
	model:SetAttribute("AttackCombo", nextStep)
	model:SetAttribute("LastAttackAt", Workspace:GetServerTimeNow())
end

-- ============================================================================
-- 5. ELITE R15 SYNDICATE SPECIALISTS (Samurai Mafia, Ninja Assassin, Warlord, Assassin)
-- ============================================================================
function MafiaVisualBuilder.BuildSyndicateSpecialistRig(
	modelName: string,
	specialistKind: "SamuraiMafia" | "NinjaMafia" | "ApexWarlord" | "ApexAssassin",
	scale: number,
	spawnCF: CFrame,
	forPreview: boolean?
): RigHandle
	local specCombatStyle = if specialistKind == "SamuraiMafia"
		then "Katana"
		elseif specialistKind == "NinjaMafia" then "DualNinja"
		else "Rifle"
	local customRig, customTpl = MafiaVisualBuilder.TryBuildFromTemplate({ specialistKind }, modelName, scale, spawnCF, forPreview, specCombatStyle)
	if customRig then
		if customTpl and customTpl:GetAttribute("AttachDefaultWeapon") == true then
			if specialistKind == "SamuraiMafia" then
				attachNPCWeapon(customRig, "Katana", P.BrushedSteel)
			elseif specialistKind == "NinjaMafia" then
				attachNPCWeapon(customRig, "DualTantos", P.BrushedSteel)
			elseif specialistKind == "ApexWarlord" then
				attachNPCWeapon(customRig, "TommyDrum", P.Gunmetal)
			elseif specialistKind == "ApexAssassin" then
				attachNPCWeapon(customRig, "AssassinRifle", P.Gunmetal)
			end
		end
		return customRig
	end

	local isSamurai = (specialistKind == "SamuraiMafia")
	local isNinja = (specialistKind == "NinjaMafia")
	local isWarlord = (specialistKind == "ApexWarlord")
	local torsoCol = if isSamurai then P.Obsidian elseif isNinja then P.Charcoal elseif isWarlord then Color3.fromRGB(24, 24, 30) else P.Obsidian
	local pantsCol = P.Obsidian
	local armCol = if isSamurai then P.Charcoal else torsoCol
	local skinCol = P.SkinWarm

	local rig = MafiaVisualBuilder.CreateBaseRig(modelName, scale, spawnCF, skinCol, torsoCol, pantsCol, armCol, P.Obsidian, 1.0, forPreview)
	local rawAdd = rig.AddPart
	local function add(parentPart: BasePart, name: string, size: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?, isWeapon: boolean?): Part
		local p = rawAdd(parentPart, name, size, relCF, col, mat, shape)
		if isWeapon then p:SetAttribute("IsNPCWeapon", true) end
		return p
	end

	if isSamurai then
		-- KUROGANE SAMURAI MAFIA (Authentic R15 Yakuza Ronin):
		-- Dark haori coat, crimson lapels & obi sash, lamellar steel chest do, layered sode pauldrons,
		-- braided Ronin Kasa hat with tarnished brass crescent clan crest, Oni menpo lower mask, hip saya & curved forged katana!
		add(rig.Torso, "HaoriLapelL", Vector3.new(0.28, 1.62, 1.08), CFrame.new(-0.48, 0.04, -0.02), P.DeepRed, Enum.Material.Fabric, nil, false)
		add(rig.Torso, "HaoriLapelR", Vector3.new(0.28, 1.62, 1.08), CFrame.new(0.48, 0.04, -0.02), P.DeepRed, Enum.Material.Fabric, nil, false)
		add(rig.Torso, "ChestDoArmor", Vector3.new(1.88, 1.24, 0.24), CFrame.new(0, 0.08, -0.50), P.Gunmetal, Enum.Material.Metal, nil, false)
		add(rig.Torso, "ChestCord", Vector3.new(1.94, 0.14, 0.28), CFrame.new(0, 0.42, -0.52), P.TarnishedBrass, Enum.Material.Metal, nil, false)
		add(rig.LowerTorso, "ObiSash", Vector3.new(2.14, 0.44, 1.18), CFrame.new(0, 0.04, 0), P.DeepRed, Enum.Material.Fabric, nil, false)
		add(rig.LowerTorso, "KusazuriL", Vector3.new(0.88, 0.72, 0.18), CFrame.new(-0.54, -0.44, -0.54), P.Gunmetal, Enum.Material.Metal, nil, false)
		add(rig.LowerTorso, "KusazuriR", Vector3.new(0.88, 0.72, 0.18), CFrame.new(0.54, -0.44, -0.54), P.Gunmetal, Enum.Material.Metal, nil, false)
		add(rig.LeftArm, "SodePauldronL", Vector3.new(1.12, 0.72, 1.14), CFrame.new(-0.14, 0.22, 0), P.Gunmetal, Enum.Material.Metal, nil, false)
		add(rig.LeftArm, "SodeTrimL", Vector3.new(1.16, 0.14, 1.18), CFrame.new(-0.14, -0.08, 0), P.DeepRed, Enum.Material.Fabric, nil, false)
		add(rig.RightArm, "SodePauldronR", Vector3.new(1.12, 0.72, 1.14), CFrame.new(0.14, 0.22, 0), P.Gunmetal, Enum.Material.Metal, nil, false)
		add(rig.RightArm, "SodeTrimR", Vector3.new(1.16, 0.14, 1.18), CFrame.new(0.14, -0.08, 0), P.DeepRed, Enum.Material.Fabric, nil, false)
		add(rig.LeftLowerArm, "KoteBracerL", Vector3.new(1.06, 0.76, 1.06), CFrame.new(0, -0.04, 0), P.Gunmetal, Enum.Material.Metal, nil, false)
		add(rig.RightLowerArm, "KoteBracerR", Vector3.new(1.06, 0.76, 1.06), CFrame.new(0, -0.04, 0), P.Gunmetal, Enum.Material.Metal, nil, false)
		-- Conical Ronin Kasa Hat + Brass Clan Crest + Oni Menpo Lower Mask
		add(rig.Head, "KasaBrim", Vector3.new(0.20, 2.48, 2.48), CFrame.new(0, 0.56, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Fabric, Enum.PartType.Cylinder, false)
		add(rig.Head, "KasaCrown", Vector3.new(0.42, 1.38, 1.38), CFrame.new(0, 0.84, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Charcoal, Enum.Material.Fabric, Enum.PartType.Cylinder, false)
		add(rig.Head, "ClanCrestL", Vector3.new(0.12, 0.52, 0.12), CFrame.new(-0.24, 0.92, -0.70) * CFrame.Angles(0, 0, math.rad(34)), P.TarnishedBrass, Enum.Material.Metal, nil, false)
		add(rig.Head, "ClanCrestR", Vector3.new(0.12, 0.52, 0.12), CFrame.new(0.24, 0.92, -0.70) * CFrame.Angles(0, 0, math.rad(-34)), P.TarnishedBrass, Enum.Material.Metal, nil, false)
		add(rig.Head, "OniMenpo", Vector3.new(1.12, 0.44, 0.44), CFrame.new(0, -0.24, -0.40), P.Obsidian, Enum.Material.Metal, nil, false)
		-- Hip Saya Scabbard + Curved Forged Katana gripped directly in R15 RightHand!
		add(rig.LowerTorso, "SayaScabbard", Vector3.new(0.16, 0.20, 3.05), CFrame.new(-1.06, -0.08, 0.42) * CFrame.Angles(math.rad(-14), 0, 0), P.Obsidian, Enum.Material.SmoothPlastic, nil, false)
		add(rig.RightHand, "KatanaHilt", Vector3.new(0.16, 0.18, 0.96), CFrame.new(0, 0.02, -0.32), P.Obsidian, Enum.Material.Fabric, nil, true)
		add(rig.RightHand, "KatanaWrap", Vector3.new(0.18, 0.20, 0.18), CFrame.new(0, 0.02, -0.10), P.DeepRed, Enum.Material.Fabric, nil, true)
		add(rig.RightHand, "KatanaTsuba", Vector3.new(0.44, 0.44, 0.09), CFrame.new(0, 0.02, -0.82), P.TarnishedBrass, Enum.Material.Metal, nil, true)
		add(rig.RightHand, "KatanaBlade", Vector3.new(0.07, 0.18, 3.35), CFrame.new(0, 0.04, -2.52), P.BrushedSteel, Enum.Material.Metal, nil, true)
		addCombatantDetail(rig, "Samurai", "Katana", P.TarnishedBrass)

	elseif isNinja then
		-- KAGE NINJA ASSASSIN MAFIA (Authentic R15 Shadow Shinobi):
		-- Matte-black shinobi cowl + crimson hachimaki headband with riveted steel clan plate & sweeping tails,
		-- fierce narrowed warrior eyes through the cowl slit, layered cloth face mask, crossed twin back katanas,
		-- ballistic harness, shin/forearm wraps & dual forged tanto blades!
		add(rig.Torso, "StealthHarness", Vector3.new(2.04, 1.44, 1.14), CFrame.new(0, 0.04, 0), P.Obsidian, Enum.Material.Fabric, nil, false)
		add(rig.Torso, "HarnessStrapL", Vector3.new(0.22, 1.54, 1.20), CFrame.new(-0.54, 0.04, 0), P.Gunmetal, Enum.Material.Leather, nil, false)
		add(rig.Torso, "HarnessStrapR", Vector3.new(0.22, 1.54, 1.20), CFrame.new(0.54, 0.04, 0), P.Gunmetal, Enum.Material.Leather, nil, false)
		add(rig.Torso, "ChestKunai1", Vector3.new(0.10, 0.48, 0.08), CFrame.new(-0.34, 0.16, -0.62) * CFrame.Angles(0, 0, math.rad(-18)), P.BrushedSteel, Enum.Material.Metal, nil, false)
		add(rig.Torso, "ChestKunai2", Vector3.new(0.10, 0.48, 0.08), CFrame.new(-0.14, 0.16, -0.62) * CFrame.Angles(0, 0, math.rad(-18)), P.BrushedSteel, Enum.Material.Metal, nil, false)
		add(rig.Torso, "CrimsonScarf", Vector3.new(1.56, 0.32, 1.24), CFrame.new(0, 0.78, 0), P.DeepRed, Enum.Material.Fabric, nil, false)
		add(rig.Torso, "ScarfTailL", Vector3.new(0.26, 1.32, 0.10), CFrame.new(-0.36, 0.20, 0.68) * CFrame.Angles(math.rad(16), 0, math.rad(-12)), P.DeepRed, Enum.Material.Fabric, nil, false)
		add(rig.Torso, "ScarfTailR", Vector3.new(0.24, 1.12, 0.10), CFrame.new(0.28, 0.28, 0.66) * CFrame.Angles(math.rad(14), 0, math.rad(14)), P.DeepRed, Enum.Material.Fabric, nil, false)
		-- Crossed Twin Back Katanas (Iconic X-Silhouette behind shoulders!)
		add(rig.Torso, "BackNinjatoR", Vector3.new(0.14, 2.95, 0.18), CFrame.new(0.08, 0.18, 0.64) * CFrame.Angles(0, 0, math.rad(-32)), P.Obsidian, Enum.Material.Metal, nil, false)
		add(rig.Torso, "NinjatoTsubaR", Vector3.new(0.36, 0.10, 0.36), CFrame.new(0.76, 1.24, 0.64) * CFrame.Angles(0, 0, math.rad(-32)), P.TarnishedBrass, Enum.Material.Metal, nil, false)
		add(rig.Torso, "NinjatoHiltR", Vector3.new(0.16, 0.66, 0.20), CFrame.new(0.98, 1.58, 0.64) * CFrame.Angles(0, 0, math.rad(-32)), P.DeepRed, Enum.Material.Fabric, nil, false)
		add(rig.Torso, "BackNinjatoL", Vector3.new(0.14, 2.95, 0.18), CFrame.new(-0.08, 0.18, 0.68) * CFrame.Angles(0, 0, math.rad(32)), P.Obsidian, Enum.Material.Metal, nil, false)
		add(rig.Torso, "NinjatoTsubaL", Vector3.new(0.36, 0.10, 0.36), CFrame.new(-0.76, 1.24, 0.68) * CFrame.Angles(0, 0, math.rad(32)), P.TarnishedBrass, Enum.Material.Metal, nil, false)
		add(rig.Torso, "NinjatoHiltL", Vector3.new(0.16, 0.66, 0.20), CFrame.new(-0.98, 1.58, 0.68) * CFrame.Angles(0, 0, math.rad(32)), P.DeepRed, Enum.Material.Fabric, nil, false)
		-- Forearm & Shin Stealth Wraps
		add(rig.LeftLowerArm, "ArmWrapL", Vector3.new(1.06, 0.84, 1.06), CFrame.new(0, 0, 0), P.Obsidian, Enum.Material.Fabric, nil, false)
		add(rig.RightLowerArm, "ArmWrapR", Vector3.new(1.06, 0.84, 1.06), CFrame.new(0, 0, 0), P.Obsidian, Enum.Material.Fabric, nil, false)
		add(rig.LeftLowerLeg, "ShinWrapL", Vector3.new(1.04, 0.92, 1.04), CFrame.new(0, 0, 0), P.Obsidian, Enum.Material.Fabric, nil, false)
		add(rig.RightLowerLeg, "ShinWrapR", Vector3.new(1.04, 0.92, 1.04), CFrame.new(0, 0, 0), P.Obsidian, Enum.Material.Fabric, nil, false)
		-- Shinobi Cowl + Crimson Hachimaki Headband + Riveted Steel Clan Plate + Fierce Eyes + Face Mask
		add(rig.Head, "CowlTop", Vector3.new(1.26, 0.56, 1.28), CFrame.new(0, 0.42, 0.04), P.Obsidian, Enum.Material.Fabric, nil, false)
		add(rig.Head, "CowlBack", Vector3.new(1.24, 1.08, 0.74), CFrame.new(0, 0.02, 0.34), P.Obsidian, Enum.Material.Fabric, nil, false)
		add(rig.Head, "HachimakiBand", Vector3.new(1.30, 0.24, 1.32), CFrame.new(0, 0.34, 0.02), P.DeepRed, Enum.Material.Fabric, nil, false)
		add(rig.Head, "HeadbandPlate", Vector3.new(0.74, 0.24, 0.12), CFrame.new(0, 0.34, -0.63), P.BrushedSteel, Enum.Material.Metal, nil, false)
		add(rig.Head, "BandTailL", Vector3.new(0.18, 0.78, 0.08), CFrame.new(-0.22, 0.16, 0.74) * CFrame.Angles(math.rad(28), 0, math.rad(-22)), P.DeepRed, Enum.Material.Fabric, nil, false)
		add(rig.Head, "BandTailR", Vector3.new(0.16, 0.64, 0.08), CFrame.new(0.18, 0.22, 0.74) * CFrame.Angles(math.rad(24), 0, math.rad(18)), P.DeepRed, Enum.Material.Fabric, nil, false)
		add(rig.Head, "StealthMask", Vector3.new(1.24, 0.56, 0.56), CFrame.new(0, -0.24, -0.38), P.Obsidian, Enum.Material.Fabric, nil, false)
		-- Sharp focused shinobi eyes inside cowl slit (SmoothPlastic — zero Neon!)
		add(rig.Head, "ShinobiEyeL", Vector3.new(0.24, 0.10, 0.08), CFrame.new(-0.22, 0.10, -0.58) * CFrame.Angles(0, 0, math.rad(-10)), Color3.fromRGB(252, 248, 236), Enum.Material.SmoothPlastic, nil, false)
		add(rig.Head, "ShinobiEyeR", Vector3.new(0.24, 0.10, 0.08), CFrame.new(0.22, 0.10, -0.58) * CFrame.Angles(0, 0, math.rad(10)), Color3.fromRGB(252, 248, 236), Enum.Material.SmoothPlastic, nil, false)
		add(rig.Head, "ShinobiIrisL", Vector3.new(0.10, 0.09, 0.09), CFrame.new(-0.22, 0.10, -0.59), Color3.fromRGB(214, 34, 48), Enum.Material.SmoothPlastic, nil, false)
		add(rig.Head, "ShinobiIrisR", Vector3.new(0.10, 0.09, 0.09), CFrame.new(0.22, 0.10, -0.59), Color3.fromRGB(214, 34, 48), Enum.Material.SmoothPlastic, nil, false)
		-- Dual Forged Tanto Blades gripped directly in R15 RightHand & LeftHand!
		add(rig.RightHand, "TantoGripR", Vector3.new(0.14, 0.16, 0.68), CFrame.new(0, 0, -0.28), P.Obsidian, Enum.Material.SmoothPlastic, nil, true)
		add(rig.RightHand, "TantoGuardR", Vector3.new(0.28, 0.28, 0.08), CFrame.new(0, 0, -0.62), P.TarnishedBrass, Enum.Material.Metal, nil, true)
		add(rig.RightHand, "TantoBladeR", Vector3.new(0.07, 0.17, 1.82), CFrame.new(0, 0, -1.52), P.BrushedSteel, Enum.Material.Metal, nil, true)
		add(rig.LeftHand, "TantoGripL", Vector3.new(0.14, 0.16, 0.68), CFrame.new(0, 0, -0.28), P.Obsidian, Enum.Material.SmoothPlastic, nil, true)
		add(rig.LeftHand, "TantoGuardL", Vector3.new(0.28, 0.28, 0.08), CFrame.new(0, 0, -0.62), P.TarnishedBrass, Enum.Material.Metal, nil, true)
		add(rig.LeftHand, "TantoBladeL", Vector3.new(0.07, 0.17, 1.72), CFrame.new(0, 0, -1.46), P.BrushedSteel, Enum.Material.Metal, nil, true)
		addCombatantDetail(rig, "Ninja", "DualNinja", P.DeepRed)

	elseif isWarlord then
		-- APEX SYNDICATE WARLORD COMMANDER (Authentic R15 Boss Mobster + Drum Tommy Gun!)
		add(rig.Torso, "ArmoredPlate", Vector3.new(2.14, 1.54, 1.24), CFrame.new(0, 0.04, 0), P.Gunmetal, Enum.Material.Metal, nil, false)
		add(rig.Torso, "DressShirt", Vector3.new(0.64, 1.38, 0.14), CFrame.new(0, 0.12, -0.58), P.OffWhite, Enum.Material.Fabric, nil, false)
		add(rig.Torso, "CrimsonTie", Vector3.new(0.24, 1.18, 0.12), CFrame.new(0, 0.08, -0.64), P.DeepRed, Enum.Material.Fabric, nil, false)
		add(rig.LowerTorso, "OvercoatTail", Vector3.new(2.24, 1.44, 1.22), CFrame.new(0, -0.68, 0.10), P.Obsidian, Enum.Material.Fabric, nil, false)
		add(rig.Head, "FedoraBrim", Vector3.new(0.16, 2.08, 2.08), CFrame.new(0, 0.54, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Fabric, Enum.PartType.Cylinder, false)
		add(rig.Head, "FedoraCrown", Vector3.new(0.62, 1.34, 1.34), CFrame.new(0, 0.86, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Obsidian, Enum.Material.Fabric, Enum.PartType.Cylinder, false)
		add(rig.Head, "FedoraBand", Vector3.new(0.16, 1.40, 1.40), CFrame.new(0, 0.64, 0) * CFrame.Angles(0, 0, math.rad(90)), P.DeepRed, Enum.Material.Fabric, Enum.PartType.Cylinder, false)
		add(rig.Head, "DarkShades", Vector3.new(1.12, 0.24, 0.14), CFrame.new(0, 0.08, -0.57), P.Obsidian, Enum.Material.Glass, nil, false)
		attachNPCWeapon(rig, "TommyDrum", P.Gunmetal)
		addCombatantDetail(rig, "Suited", "Rifle", P.DeepRed)

	else
		-- APEX ASSASSIN MAFIA (Authentic R15 Shadow Hitman + Suppressed Assassin Rifle!)
		add(rig.Torso, "TacRig", Vector3.new(2.02, 1.42, 1.18), CFrame.new(0, 0.04, 0), P.Charcoal, Enum.Material.Metal, nil, false)
		add(rig.Torso, "CrimsonCollar", Vector3.new(1.52, 0.28, 1.18), CFrame.new(0, 0.80, 0), P.DeepRed, Enum.Material.Fabric, nil, false)
		add(rig.LowerTorso, "AssassinCoat", Vector3.new(2.08, 1.44, 1.16), CFrame.new(0, -0.68, 0.10), P.Obsidian, Enum.Material.Fabric, nil, false)
		addHairStyle(rig, "Slick", P.HairDark)
		add(rig.Head, "AssassinMask", Vector3.new(1.22, 0.52, 0.46), CFrame.new(0, -0.24, -0.40), P.Obsidian, Enum.Material.Metal, nil, false)
		add(rig.Head, "AssassinShades", Vector3.new(1.10, 0.24, 0.14), CFrame.new(0, 0.08, -0.57), P.Obsidian, Enum.Material.Glass, nil, false)
		attachNPCWeapon(rig, "AssassinRifle", P.Gunmetal)
		addCombatantDetail(rig, "Tactical", "Rifle", P.DeepRed)
	end

	return rig
end

return MafiaVisualBuilder
