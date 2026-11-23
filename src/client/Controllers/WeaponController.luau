--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local AudioController = require("./AudioController")

local WeaponController = {}

local fireEv: RemoteEvent? = nil
local isMouseDown = false
local lastClientFire = 0

-- Pure-Black Concentric Target Reticle (follows mouse cursor only — NO auto-lock, NO red dots!) + Player HP Bar
local aimGui: ScreenGui? = nil
local reticleFrame: Frame? = nil
local playerHpFill: Frame? = nil
local playerHpLabel: TextLabel? = nil
local playerArmorFill: Frame? = nil
local playerArmorLabel: TextLabel? = nil

-- Full-Body Procedural IK Aiming, Two-Handed Stance, Breathing Sway & Recoil State
local ikCharacter: Model? = nil
local headLookIK: IKControl? = nil
local rightArmIK: IKControl? = nil
local leftArmIK: IKControl? = nil
local lookTargetAtt: Attachment? = nil
local rightHandTargetAtt: Attachment? = nil
local leftGripAttOnTool: Attachment? = nil
local activeGripTool: Tool? = nil

local recoilKick = 0
local swayClock = 0

local BLACK_COLOR = Color3.fromRGB(10, 10, 12)

local function getEquippedToolAndId(): (Tool?, string?)
	local char = Players.LocalPlayer.Character
	if not char then return nil, nil end
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then return nil, nil end
	local wid = tool:GetAttribute("WeaponId")
	if typeof(wid) == "string" then
		return tool, wid
	end
	return nil, nil
end

local function getEquippedWeaponId(): string?
	local _, wid = getEquippedToolAndId()
	return wid
end

-- Spawns a realistic dynamic Muzzle Flash + ejects a spinning Brass Shell Casing on every shot!
local function playMuzzleFlashAndShellEject(tool: Tool, wid: string): ()
	local muzzle = tool:FindFirstChild("MuzzleTip", true)
	local handle = tool:FindFirstChild("Handle")
	if muzzle and muzzle:IsA("BasePart") then
		local flashLight = Instance.new("PointLight")
		flashLight.Color = Color3.fromRGB(255, 196, 84)
		flashLight.Brightness = 2.6
		flashLight.Range = 16
		flashLight.Shadows = false
		flashLight.Parent = muzzle

		local spark = Instance.new("Part")
		spark.Name = "MuzzleFlashSpark"
		spark.Size = if wid == "PepperShotgun" then Vector3.new(0.80, 0.80, 1.25) else Vector3.new(0.48, 0.48, 0.88)
		spark.Color = Color3.fromRGB(255, 214, 92)
		spark.Material = Enum.Material.SmoothPlastic
		spark.Transparency = 0.15
		spark.CanCollide = false
		spark.CanTouch = false
		spark.CanQuery = false
		spark.Massless = true
		spark.Anchored = true
		spark.CFrame = muzzle.CFrame * CFrame.new(0, 0, -0.45) * CFrame.Angles(0, 0, math.rad(math.random(0, 180)))
		spark.Parent = Workspace

		task.delay(0.055, function()
			if flashLight.Parent then flashLight:Destroy() end
			if spark.Parent then spark:Destroy() end
		end)
	end

	if handle and handle:IsA("BasePart") then
		local shell = Instance.new("Part")
		shell.Name = "EjectedShell"
		shell.Shape = Enum.PartType.Cylinder
		shell.Size = if wid == "PepperShotgun" then Vector3.new(0.32, 0.14, 0.14) else Vector3.new(0.22, 0.10, 0.10)
		shell.Color = if wid == "PepperShotgun" then Color3.fromRGB(204, 44, 44) else Color3.fromRGB(242, 198, 72)
		shell.Material = Enum.Material.Metal
		shell.CanCollide = false
		shell.CanTouch = false
		shell.CanQuery = false
		shell.CFrame = handle.CFrame * CFrame.new(0.25, 0.58, -0.42)
		shell.Parent = Workspace
		shell.AssemblyLinearVelocity = (handle.CFrame.RightVector * (7 + math.random() * 3))
			+ Vector3.new(0, 9 + math.random() * 2, 0)
		shell.AssemblyAngularVelocity = Vector3.new(math.random(-25, 25), math.random(-25, 25), math.random(-25, 25))

		task.delay(0.65, function()
			if shell.Parent then shell:Destroy() end
		end)
	end
end

-- Sets up 3-Chain Inverse Kinematics (Head/Torso Sight-Look, Right-Arm Aim & Recoil, Left-Arm Two-Handed Foregrip)
local function ensureCharacterGunIK(char: Model): boolean
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	local lowerTorso = char:FindFirstChild("LowerTorso")
	local upperTorso = char:FindFirstChild("UpperTorso")
	local head = char:FindFirstChild("Head")
	local rUpper = char:FindFirstChild("RightUpperArm")
	local rHand = char:FindFirstChild("RightHand")
	local lUpper = char:FindFirstChild("LeftUpperArm")
	local lHand = char:FindFirstChild("LeftHand")

	if not hum or not root or not root:IsA("BasePart") or not upperTorso or not head or not rUpper or not rHand or not lUpper or not lHand then
		return false
	end

	if ikCharacter == char and headLookIK and headLookIK.Parent and rightArmIK and rightArmIK.Parent and leftArmIK and leftArmIK.Parent then
		return true
	end

	ikCharacter = char

	local oldLookAtt = root:FindFirstChild("GunAimLookTargetAtt")
	if oldLookAtt then oldLookAtt:Destroy() end
	local lAtt = Instance.new("Attachment")
	lAtt.Name = "GunAimLookTargetAtt"
	lAtt.Parent = root
	lookTargetAtt = lAtt

	local oldRHandAtt = root:FindFirstChild("GunRightHandTargetAtt")
	if oldRHandAtt then oldRHandAtt:Destroy() end
	local rAtt = Instance.new("Attachment")
	rAtt.Name = "GunRightHandTargetAtt"
	rAtt.Parent = root
	rightHandTargetAtt = rAtt

	for _, ch in ipairs(hum:GetChildren()) do
		if ch:IsA("IKControl") and string.find(ch.Name, "GunIK_") then
			ch:Destroy()
		end
	end

	local hIK = Instance.new("IKControl")
	hIK.Name = "GunIK_HeadLook"
	hIK.Type = Enum.IKControlType.LookAt
	hIK.ChainRoot = lowerTorso or upperTorso
	hIK.EndEffector = head
	hIK.Target = lAtt
	hIK.Weight = 0.80
	hIK.SmoothTime = 0.06
	hIK.Priority = 10
	hIK.Enabled = false
	hIK.Parent = hum
	headLookIK = hIK

	local rIK = Instance.new("IKControl")
	rIK.Name = "GunIK_RightArm"
	rIK.Type = Enum.IKControlType.Transform
	rIK.ChainRoot = rUpper
	rIK.EndEffector = rHand
	rIK.Target = rAtt
	rIK.Weight = 0.96
	rIK.SmoothTime = 0.04
	rIK.Priority = 20
	rIK.Enabled = false
	rIK.Parent = hum
	rightArmIK = rIK

	local lIK = Instance.new("IKControl")
	lIK.Name = "GunIK_LeftArm"
	lIK.Type = Enum.IKControlType.Position
	lIK.ChainRoot = lUpper
	lIK.EndEffector = lHand
	lIK.Weight = 0.95
	lIK.SmoothTime = 0.04
	lIK.Priority = 20
	lIK.Enabled = false
	lIK.Parent = hum
	leftArmIK = lIK

	return true
end

local function ensureToolLeftGripAttachment(tool: Tool, wid: string): Attachment?
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return nil
	end
	if activeGripTool == tool and leftGripAttOnTool and leftGripAttOnTool.Parent == handle then
		return leftGripAttOnTool
	end
	local existing = handle:FindFirstChild("LeftHandForeGripAtt")
	if existing and existing:IsA("Attachment") then
		activeGripTool = tool
		leftGripAttOnTool = existing
		return existing
	end

	local att = Instance.new("Attachment")
	att.Name = "LeftHandForeGripAtt"
	if wid == "PepperShotgun" then
		att.Position = Vector3.new(-0.14, 0.34, -1.72)
	elseif wid == "TacticalSMG" then
		att.Position = Vector3.new(-0.12, 0.10, -1.46)
	else
		att.Position = Vector3.new(-0.16, -0.04, -0.22)
	end
	att.Parent = handle
	activeGripTool = tool
	leftGripAttOnTool = att
	return att
end

local function disableGunIK(): ()
	if headLookIK then headLookIK.Enabled = false end
	if rightArmIK then rightArmIK.Enabled = false end
	if leftArmIK then leftArmIK.Enabled = false end
end

local function updateFullBodyGunAiming(dt: number, tool: Tool, wid: string, aimWorldPos: Vector3): ()
	local char = Players.LocalPlayer.Character
	if not char or not ensureCharacterGunIK(char) then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not hum or hum.Health <= 0 then
		return
	end

	recoilKick = math.max(0, recoilKick - dt * 5.8)

	local moveSpeed = hum.MoveDirection.Magnitude
	swayClock += dt * (if moveSpeed > 0.1 then 10.5 else 2.2)
	local breathY = math.sin(swayClock) * (if moveSpeed > 0.1 then 0.075 else 0.025)
	local breathX = math.cos(swayClock * 0.5) * (if moveSpeed > 0.1 then 0.055 else 0.015)

	-- Rotate character body smoothly toward mouse aim when firing or when standing still aiming!
	local toAim = aimWorldPos - root.Position
	local flatAim = Vector3.new(toAim.X, 0, toAim.Z)
	if flatAim.Magnitude > 1.5 and not hum.Sit then
		local turnRate = if isMouseDown or recoilKick > 0.05 then 18 elseif moveSpeed < 0.1 then 10 else 0
		if turnRate > 0 then
			local desiredRootCF = CFrame.lookAt(root.Position, root.Position + flatAim.Unit)
			root.CFrame = root.CFrame:Lerp(desiredRootCF, math.clamp(dt * turnRate, 0, 1))
		end
	end

	local stanceOffset = if wid == "PepperShotgun"
		then Vector3.new(0.92 + breathX, 1.18 + breathY + recoilKick * 0.22, -1.62 + recoilKick * 0.38)
		elseif wid == "TacticalSMG" then Vector3.new(0.86 + breathX, 1.24 + breathY + recoilKick * 0.16, -1.68 + recoilKick * 0.28)
		else Vector3.new(0.58 + breathX, 1.34 + breathY + recoilKick * 0.24, -1.95 + recoilKick * 0.30)

	local handWorldPos = (root.CFrame * CFrame.new(stanceOffset)).Position
	-- Clamp aim direction within a natural front hemisphere so the arms never twist backward while walking away from the cursor
	local localAim = root.CFrame:PointToObjectSpace(aimWorldPos)
	local clampedLocal = Vector3.new(
		math.clamp(localAim.X, -25, 25),
		math.clamp(localAim.Y, -14, 18),
		math.min(-4, localAim.Z)
	)
	local naturalAimWorld = root.CFrame:PointToWorldSpace(clampedLocal)
	local aimDir = (naturalAimWorld - handWorldPos)
	if aimDir.Magnitude < 1 then
		aimDir = root.CFrame.LookVector * 20
	end
	local clampedLookTarget = handWorldPos + aimDir.Unit * 30 + Vector3.new(0, recoilKick * 7.5, 0)

	local desiredHandleWorldCF = CFrame.lookAt(handWorldPos, clampedLookTarget)
	local desiredRightHandWorldCF = desiredHandleWorldCF * CFrame.Angles(math.rad(90), 0, 0)

	if rightHandTargetAtt then
		rightHandTargetAtt.WorldCFrame = desiredRightHandWorldCF
	end
	if lookTargetAtt then
		lookTargetAtt.WorldPosition = clampedLookTarget
	end

	local leftAtt = ensureToolLeftGripAttachment(tool, wid)
	if leftArmIK and leftAtt then
		leftArmIK.Target = leftAtt
		leftArmIK.Enabled = true
	end
	if rightArmIK then rightArmIK.Enabled = true end
	if headLookIK then headLookIK.Enabled = true end
end

local function faceCharacterToward(worldPos: Vector3): ()
	local char = Players.LocalPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if root and root:IsA("BasePart") and (not hum or not hum.Sit) then
		local flat = Vector3.new(worldPos.X, root.Position.Y, worldPos.Z)
		if (flat - root.Position).Magnitude > 1 then
			root.CFrame = CFrame.lookAt(root.Position, flat)
		end
	end
end

local function tryShoot(): ()
	local tool, wid = getEquippedToolAndId()
	if not tool or not wid or not fireEv then
		return
	end
	local now = os.clock()
	local minCd = if wid == "TacticalSMG" then 0.18 elseif wid == "PepperShotgun" then 0.85 else 0.36
	if (now - lastClientFire) < minCd then
		return
	end
	lastClientFire = now

	recoilKick = if wid == "PepperShotgun" then 1.0 elseif wid == "TacticalSMG" then 0.48 else 0.72
	playMuzzleFlashAndShellEject(tool, wid)

	local mouse = Players.LocalPlayer:GetMouse()
	local hitPos = mouse.Hit.Position
	faceCharacterToward(hitPos)
	fireEv:FireServer(wid, hitPos, nil)
end

local function ensureCharacterOverheadHP(char: Model): ()
	local head = char:FindFirstChild("Head")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not head or not head:IsA("BasePart") or not hum then
		return
	end
	if head:FindFirstChild("PlayerOverheadHP") then
		return
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "PlayerOverheadHP"
	bb.Size = UDim2.fromOffset(145, 22)
	bb.StudsOffset = Vector3.new(0, 3.1, 0)
	bb.MaxDistance = 120
	bb.Parent = head

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
	bg.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = bg
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(248, 196, 56)
	st.Thickness = 1.4
	st.Parent = bg

	local fill = Instance.new("Frame")
	fill.Name = "HPFill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(58, 214, 106)
	fill.Parent = bg
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 6)
	fc.Parent = fill

	local txt = Instance.new("TextLabel")
	txt.Name = "HPText"
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundTransparency = 1
	txt.Font = Enum.Font.GothamBlack
	txt.TextSize = 11
	txt.TextColor3 = Color3.new(1, 1, 1)
	txt.ZIndex = 3
	txt.Parent = bg

	local function syncHP()
		local baseHp = math.clamp(math.ceil(hum.Health), 0, 100)
		local armorAttr = char:GetAttribute("Armor")
		local armor = if typeof(armorAttr) == "number" then math.clamp(math.floor(armorAttr), 0, 100) else math.clamp(math.ceil(hum.Health) - 100, 0, 100)
		local frac = math.clamp(baseHp / 100, 0, 1)
		fill.Size = UDim2.fromScale(frac, 1)
		txt.Text = if armor > 0
			then string.format("❤️ %d HP  •  🛡️ %d", baseHp, armor)
			else string.format("❤️ %d / 100 HP", baseHp)
		fill.BackgroundColor3 = if armor > 0
			then Color3.fromRGB(48, 168, 242)
			elseif frac > 0.5 then Color3.fromRGB(58, 214, 106)
			elseif frac > 0.25 then Color3.fromRGB(246, 188, 44)
			else Color3.fromRGB(238, 56, 62)
	end
	syncHP()
	hum.HealthChanged:Connect(syncHP)
end

local function ensureEnemyOverheadHPText(model: Model): ()
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	for _, bb in ipairs(model:GetDescendants()) do
		if bb:IsA("BillboardGui") then
			local hpFill = bb:FindFirstChild("HPFill", true)
			local hpBg = if hpFill and hpFill.Parent and hpFill.Parent:IsA("Frame") then hpFill.Parent else nil
			if hpBg and not hpBg:FindFirstChild("HPText") then
				hpBg.Size = UDim2.new(0.90, 0, 0, 15)
				local hpText = Instance.new("TextLabel")
				hpText.Name = "HPText"
				hpText.Size = UDim2.fromScale(1, 1)
				hpText.BackgroundTransparency = 1
				hpText.Font = Enum.Font.GothamBlack
				hpText.TextSize = 10
				hpText.TextColor3 = Color3.new(1, 1, 1)
				hpText.ZIndex = 4
				hpText.Parent = hpBg
				local function updateTxt()
					hpText.Text = string.format("❤️ %d / %d HP", math.max(0, math.ceil(hum.Health)), math.max(1, math.ceil(hum.MaxHealth)))
				end
				updateTxt()
				hum.HealthChanged:Connect(updateTxt)
			end
		end
	end
end

-- Compact, razor-sharp "+" Crosshair (22x22 px total span — small & clean so it never blocks your target!)
local function buildCompactPlusCrosshair(parent: Instance): Frame
	local root = Instance.new("Frame")
	root.Name = "BlackTargetReticle"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Size = UDim2.fromOffset(22, 22)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = parent

	-- Pinpoint 2x2 center dot
	local centerDot = Instance.new("Frame")
	centerDot.Name = "CenterDot"
	centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
	centerDot.Position = UDim2.fromScale(0.5, 0.5)
	centerDot.Size = UDim2.fromOffset(2, 2)
	centerDot.BackgroundColor3 = BLACK_COLOR
	centerDot.BorderSizePixel = 0
	centerDot.Parent = root

	-- 4 compact "+" crosshair ticks (7px long x 2px thin, 3px gap from center)
	local tickSpecs = {
		{ Name = "Top",    Pos = UDim2.new(0.5, 0, 0.5, -6), Size = UDim2.fromOffset(2, 7) },
		{ Name = "Bottom", Pos = UDim2.new(0.5, 0, 0.5,  6), Size = UDim2.fromOffset(2, 7) },
		{ Name = "Left",   Pos = UDim2.new(0.5, -6, 0.5, 0), Size = UDim2.fromOffset(7, 2) },
		{ Name = "Right",  Pos = UDim2.new(0.5,  6, 0.5, 0), Size = UDim2.fromOffset(7, 2) },
	}
	for _, ts in ipairs(tickSpecs) do
		local line = Instance.new("Frame")
		line.Name = "Tick_" .. ts.Name
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = ts.Pos
		line.Size = ts.Size
		line.BackgroundColor3 = BLACK_COLOR
		line.BorderSizePixel = 0
		line.Parent = root
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(255, 255, 255)
		st.Transparency = 0.35
		st.Thickness = 0.8
		st.Parent = line
	end

	return root
end

local function buildAimUI(): ()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("WeaponAimHUD")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "WeaponAimHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 45
	gui.Parent = playerGui
	aimGui = gui

	-- 1. Green Player Base HP Bar (100 / 100 HP)
	local hpPill = Instance.new("Frame")
	hpPill.Name = "PlayerHUDHealthBar"
	hpPill.AnchorPoint = Vector2.new(1, 0)
	hpPill.Position = UDim2.new(1, -14, 0, 146)
	hpPill.Size = UDim2.fromOffset(216, 26)
	hpPill.BackgroundColor3 = Color3.fromRGB(22, 28, 42)
	hpPill.Parent = gui
	local hpc = Instance.new("UICorner")
	hpc.CornerRadius = UDim.new(0, 8)
	hpc.Parent = hpPill
	local hps = Instance.new("UIStroke")
	hps.Color = Color3.fromRGB(78, 226, 126)
	hps.Thickness = 1.6
	hps.Parent = hpPill

	local pFill = Instance.new("Frame")
	pFill.Name = "Fill"
	pFill.Size = UDim2.fromScale(1, 1)
	pFill.BackgroundColor3 = Color3.fromRGB(48, 198, 96)
	pFill.Parent = hpPill
	local pfc = Instance.new("UICorner")
	pfc.CornerRadius = UDim.new(0, 8)
	pfc.Parent = pFill
	playerHpFill = pFill

	local pLbl = Instance.new("TextLabel")
	pLbl.Size = UDim2.fromScale(1, 1)
	pLbl.BackgroundTransparency = 1
	pLbl.Font = Enum.Font.GothamBlack
	pLbl.Text = "❤️ YOUR HP: 100 / 100"
	pLbl.TextSize = 11
	pLbl.TextColor3 = Color3.new(1, 1, 1)
	pLbl.ZIndex = 3
	pLbl.Parent = hpPill
	playerHpLabel = pLbl

	-- 2. Blue Breakable Kevlar Armor Bar (0..100 Armor — bought at Black Market!)
	local armorPill = Instance.new("Frame")
	armorPill.Name = "PlayerHUDArmorBar"
	armorPill.AnchorPoint = Vector2.new(1, 0)
	armorPill.Position = UDim2.new(1, -14, 0, 176)
	armorPill.Size = UDim2.fromOffset(216, 24)
	armorPill.BackgroundColor3 = Color3.fromRGB(18, 26, 42)
	armorPill.Parent = gui
	local apc = Instance.new("UICorner")
	apc.CornerRadius = UDim.new(0, 8)
	apc.Parent = armorPill
	local aps = Instance.new("UIStroke")
	aps.Color = Color3.fromRGB(64, 172, 248)
	aps.Thickness = 1.5
	aps.Parent = armorPill

	local aFill = Instance.new("Frame")
	aFill.Name = "Fill"
	aFill.Size = UDim2.fromScale(0, 1)
	aFill.BackgroundColor3 = Color3.fromRGB(38, 148, 232)
	aFill.Parent = armorPill
	local afc = Instance.new("UICorner")
	afc.CornerRadius = UDim.new(0, 8)
	afc.Parent = aFill
	playerArmorFill = aFill

	local aLbl = Instance.new("TextLabel")
	aLbl.Size = UDim2.fromScale(1, 1)
	aLbl.BackgroundTransparency = 1
	aLbl.Font = Enum.Font.GothamBlack
	aLbl.Text = "🛡️ ARMOR: 0 / 100 (Black Market)"
	aLbl.TextSize = 10
	aLbl.TextColor3 = Color3.fromRGB(198, 232, 255)
	aLbl.ZIndex = 3
	aLbl.Parent = armorPill
	playerArmorLabel = aLbl

	reticleFrame = buildCompactPlusCrosshair(gui)
end

function WeaponController.Start(onOpenBlackMarket: () -> ()): ()
	buildAimUI()

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
		if not remotes then return end

		local wFire = remotes:WaitForChild("WeaponFire", 15)
		if wFire and wFire:IsA("RemoteEvent") then
			fireEv = wFire
		end

		local sfx = remotes:WaitForChild("CombatSFX", 15)
		if sfx and sfx:IsA("RemoteEvent") then
			sfx.OnClientEvent:Connect(function(kind: any, origin: any)
				if typeof(kind) ~= "string" then return end
				local volScale = 1.0
				if typeof(origin) == "Vector3" then
					local char = Players.LocalPlayer.Character
					local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
					if root and root:IsA("BasePart") then
						local dist = (root.Position - origin).Magnitude
						if dist > 165 then
							return
						end
						volScale = math.clamp(1 - (dist / 170), 0.18, 1.0)
					end
				end
				AudioController.PlayCombatSFX(kind, volScale)
			end)
		end

		local openBm = remotes:WaitForChild("OpenBlackMarketUI", 15)
		if openBm and openBm:IsA("RemoteEvent") then
			openBm.OnClientEvent:Connect(function()
				AudioController.PlayClick()
				onOpenBlackMarket()
			end)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isMouseDown = true
			tryShoot()
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isMouseDown = false
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		local char = Players.LocalPlayer.Character
		if char then
			ensureCharacterOverheadHP(char)
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and playerHpFill and playerHpLabel then
				local baseHp = math.clamp(math.ceil(hum.Health), 0, 100)
				local armorAttr = char:GetAttribute("Armor")
				local armor = if typeof(armorAttr) == "number" then math.clamp(math.floor(armorAttr), 0, 100) else math.clamp(math.ceil(hum.Health) - 100, 0, 100)
				local frac = math.clamp(baseHp / 100, 0, 1)
				playerHpFill.Size = UDim2.fromScale(frac, 1)
				playerHpLabel.Text = string.format("❤️ YOUR HP: %d / 100", baseHp)
				playerHpFill.BackgroundColor3 = if frac > 0.5
					then Color3.fromRGB(48, 198, 96)
					elseif frac > 0.25 then Color3.fromRGB(242, 178, 38)
					else Color3.fromRGB(234, 52, 62)

				if playerArmorFill and playerArmorLabel then
					playerArmorFill.Size = UDim2.fromScale(math.clamp(armor / 100, 0, 1), 1)
					playerArmorLabel.Text = if armor > 0
						then string.format("🛡️ ARMOR: %d / 100", armor)
						else "🛡️ ARMOR: 0 / 100 (Buy at Black Market)"
				end
			end
		end

		for _, m in ipairs(CollectionService:GetTagged("MafiaUnit")) do
			if m:IsA("Model") then ensureEnemyOverheadHPText(m) end
		end
		for _, m in ipairs(CollectionService:GetTagged("RivalAIUnit")) do
			if m:IsA("Model") then ensureEnemyOverheadHPText(m) end
		end

		local tool, wid = getEquippedToolAndId()
		if not reticleFrame then
			return
		end
		if not tool or not wid then
			if reticleFrame.Visible then
				reticleFrame.Visible = false
				UserInputService.MouseIconEnabled = true
			end
			disableGunIK()
			return
		end

		-- Pure-black concentric target stays strictly on your mouse cursor (no auto-snap, no red box!)
		reticleFrame.Visible = true
		UserInputService.MouseIconEnabled = false
		local mousePos = UserInputService:GetMouseLocation()
		reticleFrame.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)

		local mouse = Players.LocalPlayer:GetMouse()
		updateFullBodyGunAiming(dt, tool, wid, mouse.Hit.Position)

		if isMouseDown and wid == "TacticalSMG" then
			tryShoot()
		end
	end)
end

return WeaponController
