--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local AudioController = require("./AudioController")

local WeaponController = {}

type WeaponProfile = {
	DisplayName: string,
	Icon: string,
	AmmoType: string,
	ReloadStyle: "Magazine" | "ShellByShell",
	DefaultMag: number,
	DefaultReserve: number,
	Cooldown: number,
	ReloadTime: number,
	ShellStartTime: number,
	ShellLoadTime: number,
	ShellFinishTime: number,
	BladedYawDeg: number,
	StancePos: Vector3,
	LeftGripLocal: Vector3,
	ReloadPortLocal: Vector3,
	KickBack: number,
	KickUp: number,
	KickPitchDeg: number,
	KickYawDeg: number,
	MaxPitchDeg: number,
	MaxBack: number,
	RecoverSpeed: number,
	CrosshairBloom: number,
	AccentColor: Color3,
}

type AmmoState = {
	Mag: number,
	MaxMag: number,
	Reserve: number,
	ReserveMax: number,
	ReloadStyle: "Magazine" | "ShellByShell",
}

type ReloadAnimState = {
	WeaponId: string,
	Style: "Magazine" | "ShellByShell",
	Phase: "Magazine" | "Enter" | "InsertShell" | "Exit",
	PhaseStart: number,
	PhaseDuration: number,
	StartTime: number,
	TotalDuration: number,
	ShellTime: number,
	FinishTime: number,
	LatchPlayed: boolean,
	PumpPlayed: boolean,
	FirstShell: boolean,
}

local WEAPON_PROFILES: { [string]: WeaponProfile } = {
	StreetPistol = {
		DisplayName = "STREET PISTOL",
		Icon = "🔫",
		AmmoType = "9mm MAG",
		ReloadStyle = "Magazine",
		DefaultMag = 12,
		DefaultReserve = 96,
		Cooldown = 0.36,
		ReloadTime = 1.45,
		ShellStartTime = 0,
		ShellLoadTime = 0,
		ShellFinishTime = 0,
		BladedYawDeg = 8,
		StancePos = Vector3.new(0.20, 0.72, -1.55),
		LeftGripLocal = Vector3.new(-0.18, -0.05, -0.16),
		ReloadPortLocal = Vector3.new(0, -0.45, 0.02),
		KickBack = 0.16,
		KickUp = 0.055,
		KickPitchDeg = 6.5,
		KickYawDeg = 0.8,
		MaxPitchDeg = 14,
		MaxBack = 0.30,
		RecoverSpeed = 12.0,
		CrosshairBloom = 5,
		AccentColor = Color3.fromRGB(162, 178, 206),
	},
	PepperShotgun = {
		DisplayName = "PEPPER SHOTGUN",
		Icon = "💥",
		AmmoType = "12G SHELLS",
		ReloadStyle = "ShellByShell",
		DefaultMag = 6,
		DefaultReserve = 36,
		Cooldown = 0.85,
		ReloadTime = 0,
		ShellStartTime = 0.22,
		ShellLoadTime = 0.44,
		ShellFinishTime = 0.28,
		BladedYawDeg = 22,
		StancePos = Vector3.new(0.44, 0.64, -0.94),
		LeftGripLocal = Vector3.new(-0.14, 0.34, -1.55),
		ReloadPortLocal = Vector3.new(-0.04, 0.24, -0.48),
		KickBack = 0.34,
		KickUp = 0.11,
		KickPitchDeg = 12.0,
		KickYawDeg = 1.5,
		MaxPitchDeg = 20,
		MaxBack = 0.45,
		RecoverSpeed = 7.8,
		CrosshairBloom = 11,
		AccentColor = Color3.fromRGB(244, 108, 56),
	},
	TacticalSMG = {
		DisplayName = "TACTICAL SMG",
		Icon = "🔥",
		AmmoType = "SMG MAG",
		ReloadStyle = "Magazine",
		DefaultMag = 30,
		DefaultReserve = 180,
		Cooldown = 0.175,
		ReloadTime = 1.85,
		ShellStartTime = 0,
		ShellLoadTime = 0,
		ShellFinishTime = 0,
		BladedYawDeg = 20,
		StancePos = Vector3.new(0.42, 0.66, -0.96),
		LeftGripLocal = Vector3.new(-0.12, 0.10, -1.44),
		ReloadPortLocal = Vector3.new(0, -0.35, -0.82),
		KickBack = 0.10,
		KickUp = 0.032,
		KickPitchDeg = 3.2,
		KickYawDeg = 1.0,
		MaxPitchDeg = 11,
		MaxBack = 0.26,
		RecoverSpeed = 13.5,
		CrosshairBloom = 4,
		AccentColor = Color3.fromRGB(246, 188, 52),
	},
}

local fireEv: RemoteEvent? = nil
local reloadEv: RemoteEvent? = nil
local isMouseDown = false
local lastClientFire = 0
local lastDryFireAt = 0
local lastShotgunPumpStart = -10
local shotSeqCounter = 0
local lastSentSeqByWeapon: { [string]: number } = {}
local lastShotTimeByWeapon: { [string]: number } = {}

-- Client-side synchronized ammo cache & reload animation state
local localAmmo: { [string]: AmmoState } = {}
local reloadState: ReloadAnimState? = nil
local emptyFlashUntil = 0

-- HUD References
local aimGui: ScreenGui? = nil
local reticleFrame: Frame? = nil
local reticleTicks: { [string]: Frame } = {}
local playerHpFill: Frame? = nil
local playerHpLabel: TextLabel? = nil
local playerArmorFill: Frame? = nil
local playerArmorLabel: TextLabel? = nil

-- Weapon Ammo HUD References
local ammoCard: Frame? = nil
local ammoCardStroke: UIStroke? = nil
local ammoWeaponLabel: TextLabel? = nil
local ammoTypeBadge: TextLabel? = nil
local ammoMagLabel: TextLabel? = nil
local ammoMaxLabel: TextLabel? = nil
local ammoReserveLabel: TextLabel? = nil
local ammoBarBg: Frame? = nil
local ammoBarFill: Frame? = nil
local shellPipHolder: Frame? = nil
local shellPips: { Frame } = {}
local reloadBarBg: Frame? = nil
local reloadBarFill: Frame? = nil
local reloadStatusLabel: TextLabel? = nil

-- Stabilized Dual-Hand Procedural IK & Recoil Spring State
local ikCharacter: Model? = nil
local headLookIK: IKControl? = nil
local rightArmIK: IKControl? = nil
local leftArmIK: IKControl? = nil
local lookTargetAtt: Attachment? = nil
local rightHandTargetAtt: Attachment? = nil
local leftHandTargetAtt: Attachment? = nil
local rightElbowPoleAtt: Attachment? = nil
local leftElbowPoleAtt: Attachment? = nil
local autoRotateOverridden = false
local lastEquippedTool: Tool? = nil
local lastEquippedWid: string? = nil

-- Smoothed Aiming, Sway & 2-Axis Recoil State
local smoothedAimDir: Vector3? = nil
local smoothedMoveBlend = 0
local swayPhase = 0
local aimFaceHoldUntil = 0

local recoilBack = 0
local recoilUp = 0
local recoilPitch = 0
local recoilYaw = 0
local recoilSpreadPx = 0
local recoilYawSign = 1

local BLACK_COLOR = Color3.fromRGB(10, 10, 12)

local function smoothstep(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

local function getProfile(wid: string): WeaponProfile
	return WEAPON_PROFILES[wid] or WEAPON_PROFILES.StreetPistol
end

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

local function ensureLocalAmmo(wid: string, tool: Tool?): AmmoState
	local profile = getProfile(wid)
	local st = localAmmo[wid]
	if not st then
		local attrMag = if tool then tool:GetAttribute("AmmoMag") else nil
		local attrMax = if tool then tool:GetAttribute("AmmoMaxMag") else nil
		local attrRes = if tool then tool:GetAttribute("AmmoReserve") else nil
		local attrResMax = if tool then tool:GetAttribute("AmmoReserveMax") else nil
		st = {
			Mag = if typeof(attrMag) == "number" then attrMag else profile.DefaultMag,
			MaxMag = if typeof(attrMax) == "number" then attrMax else profile.DefaultMag,
			Reserve = if typeof(attrRes) == "number" then attrRes else profile.DefaultReserve,
			ReserveMax = if typeof(attrResMax) == "number" then attrResMax else profile.DefaultReserve,
			ReloadStyle = profile.ReloadStyle,
		}
		localAmmo[wid] = st
	end
	return st
end

-- Clean, filtered cursor raycast that ignores the player, their bike, guide arrow, and transient combat VFX
local function getCleanAimWorldPoint(char: Model, root: BasePart): Vector3
	local camera = Workspace.CurrentCamera
	if not camera then
		return root.Position + root.CFrame.LookVector * 60
	end

	local mouseLoc = UserInputService:GetMouseLocation()
	local unitRay = camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)

	local ignoreList: { Instance } = { char }
	local playerName = Players.LocalPlayer.Name
	local bike = Workspace:FindFirstChild("SportMotorbike_" .. playerName)
	if bike then table.insert(ignoreList, bike) end
	local arrow = Workspace:FindFirstChild("FoodEmpireGuideArrow")
	if arrow then table.insert(ignoreList, arrow) end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignoreList

	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 420, rayParams)
	local hitPos = if result then result.Position else (unitRay.Origin + unitRay.Direction * 240)

	-- Guard against camera-adjacent wall/pillar hits closer than 4.5 studs from the player's torso
	local toHit = hitPos - root.Position
	if toHit.Magnitude < 4.5 then
		hitPos = unitRay.Origin + unitRay.Direction * 60
	end

	return hitPos
end

-- Spawns a crisp Muzzle Flash + spinning Brass / Red Shotgun Shell Casing
local function playMuzzleFlash(tool: Tool, wid: string): ()
	local muzzle = tool:FindFirstChild("MuzzleTip", true)
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

		task.delay(0.05, function()
			if flashLight.Parent then flashLight:Destroy() end
			if spark.Parent then spark:Destroy() end
		end)
	end
end

local function ejectShellCasing(tool: Tool, wid: string): ()
	local handle = tool:FindFirstChild("Handle")
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
			+ Vector3.new(0, 8.5 + math.random() * 2, 0)
		shell.AssemblyAngularVelocity = Vector3.new(math.random(-22, 22), math.random(-22, 22), math.random(-22, 22))

		task.delay(0.65, function()
			if shell.Parent then shell:Destroy() end
		end)
	end
end

-- Sets up Stabilized 3-Chain IK with Elbow Poles and Root-Anchored Dual Hand Targets (zero feedback wobble!)
local function ensureCharacterGunIK(char: Model): boolean
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	local upperTorso = char:FindFirstChild("UpperTorso")
	local head = char:FindFirstChild("Head")
	local rUpper = char:FindFirstChild("RightUpperArm")
	local rHand = char:FindFirstChild("RightHand")
	local lUpper = char:FindFirstChild("LeftUpperArm")
	local lHand = char:FindFirstChild("LeftHand")

	if not hum or not root or not root:IsA("BasePart") or not upperTorso or not head or not rUpper or not rHand or not lUpper or not lHand then
		return false
	end

	if ikCharacter == char
		and headLookIK and headLookIK.Parent
		and rightArmIK and rightArmIK.Parent
		and leftArmIK and leftArmIK.Parent
		and rightHandTargetAtt and rightHandTargetAtt.Parent == root
		and leftHandTargetAtt and leftHandTargetAtt.Parent == root
	then
		return true
	end

	ikCharacter = char

	local function createRootAtt(name: string, localPos: Vector3?): Attachment
		local old = root:FindFirstChild(name)
		if old then old:Destroy() end
		local att = Instance.new("Attachment")
		att.Name = name
		if localPos then
			att.Position = localPos
		end
		att.Parent = root
		return att
	end

	lookTargetAtt = createRootAtt("GunAimLookTargetAtt", nil)
	rightHandTargetAtt = createRootAtt("GunRightHandTargetAtt", nil)
	leftHandTargetAtt = createRootAtt("GunLeftHandTargetAtt", nil)
	rightElbowPoleAtt = createRootAtt("GunRightElbowPoleAtt", Vector3.new(1.55, -0.55, 0.75))
	leftElbowPoleAtt = createRootAtt("GunLeftElbowPoleAtt", Vector3.new(-1.55, -0.55, 0.75))

	for _, ch in ipairs(hum:GetChildren()) do
		if ch:IsA("IKControl") and string.find(ch.Name, "GunIK_") then
			ch:Destroy()
		end
	end

	-- Subtle UpperTorso -> Head look (does NOT twist LowerTorso/shoulders, preventing shoulder jitter!)
	local hIK = Instance.new("IKControl")
	hIK.Name = "GunIK_HeadLook"
	hIK.Type = Enum.IKControlType.LookAt
	hIK.ChainRoot = upperTorso
	hIK.EndEffector = head
	hIK.Target = lookTargetAtt
	hIK.Weight = 0.52
	hIK.SmoothTime = 0.12
	hIK.Priority = 10
	hIK.Enabled = false
	hIK.Parent = hum
	headLookIK = hIK

	local rIK = Instance.new("IKControl")
	rIK.Name = "GunIK_RightArm"
	rIK.Type = Enum.IKControlType.Transform
	rIK.ChainRoot = rUpper
	rIK.EndEffector = rHand
	rIK.Target = rightHandTargetAtt
	rIK.Pole = rightElbowPoleAtt
	rIK.Weight = 1.0
	rIK.SmoothTime = 0.075
	rIK.Priority = 25
	rIK.Enabled = false
	rIK.Parent = hum
	rightArmIK = rIK

	local lIK = Instance.new("IKControl")
	lIK.Name = "GunIK_LeftArm"
	lIK.Type = Enum.IKControlType.Position
	lIK.ChainRoot = lUpper
	lIK.EndEffector = lHand
	lIK.Target = leftHandTargetAtt
	lIK.Pole = leftElbowPoleAtt
	lIK.Weight = 1.0
	lIK.SmoothTime = 0.075
	lIK.Priority = 25
	lIK.Enabled = false
	lIK.Parent = hum
	leftArmIK = lIK

	return true
end

local function restoreAutoRotate(): ()
	if not autoRotateOverridden then
		return
	end
	autoRotateOverridden = false
	local char = Players.LocalPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if hum then
		hum.AutoRotate = true
	end
end

local function disableGunIK(): ()
	if headLookIK then headLookIK.Enabled = false end
	if rightArmIK then rightArmIK.Enabled = false end
	if leftArmIK then leftArmIK.Enabled = false end
	restoreAutoRotate()
	smoothedAimDir = nil
	recoilBack = 0
	recoilUp = 0
	recoilPitch = 0
	recoilYaw = 0
	recoilSpreadPx = 0
end

local function computeReloadOffsets(
	now: number,
	profile: WeaponProfile,
	charScale: number,
	rootCF: CFrame,
	baseHandleCF: CFrame
): (CFrame, Vector3)
	local foreGripWorld = (baseHandleCF * CFrame.new(profile.LeftGripLocal)).Position
	local rs = reloadState
	if not rs then
		return baseHandleCF, foreGripWorld
	end

	local hipPouchWorld = (rootCF * CFrame.new(-0.68 * charScale, -0.22 * charScale, -0.65 * charScale)).Position

	if rs.Style == "Magazine" then
		local t = math.clamp((now - rs.StartTime) / math.max(0.1, rs.TotalDuration), 0, 1)

		-- Smoothly cant & lift weapon during mag swap
		local cantEnv: number
		if t < 0.16 then
			cantEnv = smoothstep(t / 0.16)
		elseif t < 0.84 then
			cantEnv = 1
		else
			cantEnv = 1 - smoothstep((t - 0.84) / 0.16)
		end

		-- Subtle tactile bump right when fresh mag seats (~0.70..0.78)
		local seatBump = 0
		if t > 0.68 and t < 0.80 then
			seatBump = math.sin(((t - 0.68) / 0.12) * math.pi) * 0.065
		end

		local relHandleCF = baseHandleCF
			* CFrame.new(-0.10 * cantEnv, 0.05 * cantEnv + seatBump, 0.14 * cantEnv)
			* CFrame.Angles(math.rad(16 * cantEnv + seatBump * 45), math.rad(-10 * cantEnv), math.rad(28 * cantEnv))

		local fgWorld = (relHandleCF * CFrame.new(profile.LeftGripLocal)).Position
		local magWellWorld = (relHandleCF * CFrame.new(profile.ReloadPortLocal)).Position
		local rackFrontWorld = (relHandleCF * CFrame.new(-0.16, 0.56, -0.45)).Position
		local rackBackWorld = (relHandleCF * CFrame.new(-0.16, 0.56, -0.10)).Position

		local leftPos: Vector3
		if t < 0.22 then
			leftPos = fgWorld:Lerp(magWellWorld, smoothstep(t / 0.22))
		elseif t < 0.48 then
			leftPos = magWellWorld:Lerp(hipPouchWorld, smoothstep((t - 0.22) / 0.26))
		elseif t < 0.72 then
			leftPos = hipPouchWorld:Lerp(magWellWorld, smoothstep((t - 0.48) / 0.24))
		elseif t < 0.88 then
			local u = (t - 0.72) / 0.16
			if u < 0.45 then
				leftPos = magWellWorld:Lerp(rackFrontWorld, smoothstep(u / 0.45))
			else
				if not rs.LatchPlayed then
					rs.LatchPlayed = true
					AudioController.PlayMagLatch()
				end
				leftPos = rackFrontWorld:Lerp(rackBackWorld, smoothstep((u - 0.45) / 0.55))
			end
		else
			leftPos = rackBackWorld:Lerp(fgWorld, smoothstep((t - 0.88) / 0.12))
		end

		return relHandleCF, leftPos
	else
		-- Shell-by-shell Pepper Shotgun animation synchronized with each loaded shell
		local phaseEl = math.max(0, now - rs.PhaseStart)
		local phaseT = math.clamp(phaseEl / math.max(0.05, rs.PhaseDuration), 0, 1)

		local cantEnv = 1
		local insertBump = 0
		if rs.Phase == "Enter" then
			cantEnv = smoothstep(phaseT)
		elseif rs.Phase == "Exit" then
			cantEnv = 1 - smoothstep(phaseT)
		elseif rs.Phase == "InsertShell" then
			cantEnv = 1
			if phaseT > 0.62 and phaseT < 0.90 then
				insertBump = math.sin(((phaseT - 0.62) / 0.28) * math.pi) * 0.06
			end
		end

		local relHandleCF = baseHandleCF
			* CFrame.new(-0.08 * cantEnv, 0.08 * cantEnv + insertBump, 0.10 * cantEnv)
			* CFrame.Angles(math.rad(20 * cantEnv + insertBump * 42), math.rad(-12 * cantEnv), math.rad(34 * cantEnv))

		local fgWorld = (relHandleCF * CFrame.new(profile.LeftGripLocal)).Position
		local portWorld = (relHandleCF * CFrame.new(profile.ReloadPortLocal)).Position

		local leftPos: Vector3
		if rs.Phase == "Enter" then
			leftPos = fgWorld:Lerp(hipPouchWorld, smoothstep(phaseT))
		elseif rs.Phase == "InsertShell" then
			if rs.FirstShell then
				if phaseT < 0.76 then
					leftPos = hipPouchWorld:Lerp(portWorld, smoothstep(phaseT / 0.76))
				else
					leftPos = portWorld
				end
			else
				if phaseT < 0.38 then
					leftPos = portWorld:Lerp(hipPouchWorld, smoothstep(phaseT / 0.38))
				elseif phaseT < 0.84 then
					leftPos = hipPouchWorld:Lerp(portWorld, smoothstep((phaseT - 0.38) / 0.46))
				else
					leftPos = portWorld
				end
			end
		else
			-- Exit: snap left hand to pump grip and rack action forward!
			local pumpBack = (relHandleCF * CFrame.new(profile.LeftGripLocal + Vector3.new(0, 0, 0.42))).Position
			if phaseT < 0.45 then
				leftPos = portWorld:Lerp(pumpBack, smoothstep(phaseT / 0.45))
			else
				leftPos = pumpBack:Lerp(fgWorld, smoothstep((phaseT - 0.45) / 0.55))
			end
		end

		return relHandleCF, leftPos
	end
end

local function updateFullBodyGunAiming(dt: number, tool: Tool, wid: string, rawAimWorldPos: Vector3): ()
	local char = Players.LocalPlayer.Character
	if not char or not ensureCharacterGunIK(char) then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local upperTorso = char:FindFirstChild("UpperTorso")
	local hum = char:FindFirstChildOfClass("Humanoid")
	local rHand = char:FindFirstChild("RightHand")
	if not root or not root:IsA("BasePart") or not upperTorso or not upperTorso:IsA("BasePart") or not hum or hum.Health <= 0 or not rHand then
		disableGunIK()
		return
	end

	-- Automatically adapt stance & elbow poles to character scale (e.g. Food Empire's 1.5x CharacterScaleService!)
	local charScale = math.clamp(upperTorso.Size.Y / 1.6, 0.75, 2.2)
	if rightElbowPoleAtt then
		rightElbowPoleAtt.Position = Vector3.new(2.2 * charScale, -0.75 * charScale, 0.9 * charScale)
	end
	if leftElbowPoleAtt then
		leftElbowPoleAtt.Position = Vector3.new(-2.2 * charScale, -0.75 * charScale, 0.9 * charScale)
	end

	local profile = getProfile(wid)
	local now = os.clock()
	local clampedDt = math.min(dt, 0.05)

	-- 1. Smoothly recover 2-axis weapon recoil + crosshair bloom (frame-rate independent!)
	local recDecay = math.exp(-profile.RecoverSpeed * clampedDt)
	recoilBack *= recDecay
	recoilUp *= recDecay
	recoilPitch *= recDecay
	recoilYaw *= recDecay
	recoilSpreadPx *= math.exp(-14 * clampedDt)
	if recoilBack < 0.001 then recoilBack = 0 end
	if recoilUp < 0.001 then recoilUp = 0 end
	if math.abs(recoilPitch) < 0.01 then recoilPitch = 0 end
	if math.abs(recoilYaw) < 0.01 then recoilYaw = 0 end
	if recoilSpreadPx < 0.05 then recoilSpreadPx = 0 end

	-- 2. Smoothly low-pass filter aim direction to completely eliminate cursor depth-jump jitter
	local shoulderOrigin = root.Position + Vector3.new(0, 0.80 * charScale, 0)
	local rawVec = rawAimWorldPos - shoulderOrigin
	local rawDir = if rawVec.Magnitude > 0.5 then rawVec.Unit else root.CFrame.LookVector
	if not smoothedAimDir then
		smoothedAimDir = rawDir
	else
		local aimAlpha = 1 - math.exp(-18 * clampedDt)
		local blended = smoothedAimDir:Lerp(rawDir, aimAlpha)
		smoothedAimDir = if blended.Magnitude > 0.01 then blended.Unit else rawDir
	end
	local aimDir = smoothedAimDir :: Vector3

	-- 3. Subtle, smoothly blended idle breathing & walking rhythm (NO sudden speed jumps!)
	local moveSpeed = hum.MoveDirection.Magnitude
	smoothedMoveBlend += (math.clamp(moveSpeed, 0, 1) - smoothedMoveBlend) * (1 - math.exp(-8 * clampedDt))
	swayPhase += clampedDt * (1.7 + smoothedMoveBlend * 5.2)

	local firingSteadiness = if isMouseDown or (now < aimFaceHoldUntil) then 0.45 else 1.0
	local swayAmpY = (0.007 + smoothedMoveBlend * 0.016) * firingSteadiness
	local swayAmpX = (0.004 + smoothedMoveBlend * 0.011) * firingSteadiness
	local swayY = math.sin(swayPhase) * swayAmpY
	local swayX = math.cos(swayPhase * 0.5) * swayAmpX

	-- 4. Smooth character yaw alignment with bladed tactical stance (NO AutoRotate fighting!)
	local flatAim = Vector3.new(aimDir.X, 0, aimDir.Z)
	local activelyAiming = isMouseDown or (now < aimFaceHoldUntil) or (reloadState ~= nil)
	local standingStill = moveSpeed < 0.08

	if flatAim.Magnitude > 0.05 and not hum.Sit and (activelyAiming or standingStill) then
		if hum.AutoRotate then
			hum.AutoRotate = false
			autoRotateOverridden = true
		end
		local flatDir = flatAim.Unit
		-- Subtle bladed tactical shoulder angle so both arms stay comfortably bent & natural
		local bladedDir = (CFrame.Angles(0, -math.rad(profile.BladedYawDeg), 0):VectorToWorldSpace(flatDir)).Unit
		local desiredRootCF = CFrame.lookAt(root.Position, root.Position + bladedDir)
		local turnSpeed = if activelyAiming then 16 else 9
		local turnAlpha = 1 - math.exp(-turnSpeed * clampedDt)
		root.CFrame = root.CFrame:Lerp(desiredRootCF, turnAlpha)
	else
		restoreAutoRotate()
	end

	-- 5. Compute natural clamped forward aim direction relative to character body
	local localAimDir = root.CFrame:VectorToObjectSpace(aimDir)
	local horizLen = math.sqrt(localAimDir.X * localAimDir.X + localAimDir.Z * localAimDir.Z)
	local clampedLocalDir: Vector3
	if horizLen > 0.01 then
		local yaw = math.atan2(localAimDir.X, -localAimDir.Z)
		-- Clamp horizontal aim cone within natural shoulder arc (-55° to +65° accounting for bladed stance)
		local clampedYaw = math.clamp(yaw, math.rad(-55), math.rad(65))
		local clampedPitchY = math.clamp(localAimDir.Y, -0.58, 0.65)
		local cosP = math.sqrt(math.max(0.05, 1 - clampedPitchY * clampedPitchY))
		clampedLocalDir = Vector3.new(math.sin(clampedYaw) * cosP, clampedPitchY, -math.cos(clampedYaw) * cosP).Unit
	else
		clampedLocalDir = Vector3.new(0, 0, -1)
	end
	local worldClampedDir = root.CFrame:VectorToWorldSpace(clampedLocalDir).Unit

	-- Build stable aim-aligned reference frame at character center
	local flatClamped = Vector3.new(worldClampedDir.X, 0, worldClampedDir.Z)
	local aimBasisCF = if flatClamped.Magnitude > 0.05
		then CFrame.lookAt(root.Position, root.Position + flatClamped.Unit)
		else root.CFrame

	-- 6. Position Handle cleanly in aim frame (scaled to avatar size!) + subtle sway + backward/upward recoil kick
	local stanceWithRecoil = (profile.StancePos * charScale) + Vector3.new(swayX, swayY + recoilUp, recoilBack)
	local handleWorldPos = (aimBasisCF * CFrame.new(stanceWithRecoil)).Position
	local lookPoint = handleWorldPos + worldClampedDir * 40
	local baseHandleCF = CFrame.lookAt(handleWorldPos, lookPoint)
		* CFrame.Angles(math.rad(recoilPitch), math.rad(recoilYaw), 0)

	-- 7. Apply Reload animation OR post-shot Shotgun pump-action cycle
	local finalHandleCF, finalLeftHandPos = computeReloadOffsets(now, profile, charScale, root.CFrame, baseHandleCF)

	if not reloadState and wid == "PepperShotgun" then
		local pumpElapsed = now - lastShotgunPumpStart
		if pumpElapsed >= 0.22 and pumpElapsed <= 0.62 then
			local u = (pumpElapsed - 0.22) / 0.40
			local pull = math.sin(u * math.pi)
			finalHandleCF = finalHandleCF * CFrame.Angles(math.rad(pull * 2.5), 0, math.rad(pull * 4.0))
			finalLeftHandPos = (finalHandleCF * CFrame.new(profile.LeftGripLocal + Vector3.new(0, 0, 0.46 * pull))).Position
		end
	end

	-- 8. Convert desired Handle CFrame to EXACT RightHand CFrame using the live RightGrip weld
	local rightGrip = rHand:FindFirstChild("RightGrip")
	local handleToHandCF: CFrame
	if rightGrip and rightGrip:IsA("JointInstance") then
		handleToHandCF = rightGrip.C1 * rightGrip.C0:Inverse()
	else
		handleToHandCF = CFrame.new(0, -0.25, 0.15) * CFrame.Angles(math.rad(90), 0, 0)
	end
	local desiredRightHandWorldCF = finalHandleCF * handleToHandCF

	-- Update all 3 IK targets simultaneously on HumanoidRootPart (ZERO 1-frame feedback lag!)
	if rightHandTargetAtt then
		rightHandTargetAtt.WorldCFrame = desiredRightHandWorldCF
	end
	if leftHandTargetAtt then
		leftHandTargetAtt.WorldPosition = finalLeftHandPos
	end
	if lookTargetAtt then
		lookTargetAtt.WorldPosition = lookPoint
	end

	if leftArmIK then leftArmIK.Enabled = true end
	if rightArmIK then rightArmIK.Enabled = true end
	if headLookIK then headLookIK.Enabled = true end
end

local function updateReticleBloom(): ()
	local offset = 6 + math.floor(recoilSpreadPx + 0.5)
	local top = reticleTicks.Top
	local bot = reticleTicks.Bottom
	local left = reticleTicks.Left
	local right = reticleTicks.Right
	if top then top.Position = UDim2.new(0.5, 0, 0.5, -offset) end
	if bot then bot.Position = UDim2.new(0.5, 0, 0.5, offset) end
	if left then left.Position = UDim2.new(0.5, -offset, 0.5, 0) end
	if right then right.Position = UDim2.new(0.5, offset, 0.5, 0) end
end

local function updateAmmoHUD(tool: Tool?, wid: string?): ()
	if not ammoCard then
		return
	end
	if not tool or not wid then
		ammoCard.Visible = false
		return
	end

	ammoCard.Visible = true
	local profile = getProfile(wid)
	local st = ensureLocalAmmo(wid, tool)
	local now = os.clock()

	if ammoWeaponLabel then
		ammoWeaponLabel.Text = string.format("%s %s", profile.Icon, profile.DisplayName)
	end
	if ammoTypeBadge then
		ammoTypeBadge.Text = profile.AmmoType
		ammoTypeBadge.BackgroundColor3 = profile.AccentColor
	end

	local isReloading = reloadState ~= nil and reloadState.WeaponId == wid
	local isEmpty = st.Mag <= 0
	local isLow = st.Mag > 0 and (st.Mag / math.max(1, st.MaxMag)) <= 0.25
	local isFlashingEmpty = now < emptyFlashUntil

	if ammoMagLabel then
		ammoMagLabel.Text = tostring(st.Mag)
		ammoMagLabel.TextColor3 = if isEmpty
			then Color3.fromRGB(255, 76, 84)
			elseif isLow then Color3.fromRGB(255, 206, 72)
			else Color3.fromRGB(255, 255, 255)
	end
	if ammoMaxLabel then
		ammoMaxLabel.Text = string.format("/ %d", st.MaxMag)
	end
	if ammoReserveLabel then
		ammoReserveLabel.Text = string.format("%d", st.Reserve)
		ammoReserveLabel.TextColor3 = if st.Reserve <= 0
			then Color3.fromRGB(255, 96, 96)
			else Color3.fromRGB(148, 224, 255)
	end

	if ammoCardStroke then
		if isFlashingEmpty then
			ammoCardStroke.Color = Color3.fromRGB(255, 62, 68)
			ammoCardStroke.Thickness = 2.6
		elseif isReloading then
			ammoCardStroke.Color = Color3.fromRGB(82, 226, 255)
			ammoCardStroke.Thickness = 2.0
		elseif isEmpty then
			ammoCardStroke.Color = Color3.fromRGB(246, 84, 72)
			ammoCardStroke.Thickness = 2.0
		else
			ammoCardStroke.Color = profile.AccentColor
			ammoCardStroke.Thickness = 1.6
		end
	end

	-- Visual magazine bar vs individual shotgun shell pips
	local isShellStyle = (profile.ReloadStyle == "ShellByShell")
	if shellPipHolder and ammoBarBg then
		shellPipHolder.Visible = isShellStyle
		ammoBarBg.Visible = not isShellStyle
		if isShellStyle then
			for i, pip in ipairs(shellPips) do
				pip.Visible = (i <= st.MaxMag)
				if i <= st.Mag then
					pip.BackgroundColor3 = Color3.fromRGB(238, 72, 54)
				elseif isReloading and i == (st.Mag + 1) then
					local pulse = 0.5 + 0.5 * math.sin(now * 14)
					pip.BackgroundColor3 = Color3.fromRGB(245, 194, 58):Lerp(Color3.fromRGB(96, 72, 28), 1 - pulse)
				else
					pip.BackgroundColor3 = Color3.fromRGB(36, 44, 62)
				end
			end
		elseif ammoBarFill then
			local frac = math.clamp(st.Mag / math.max(1, st.MaxMag), 0, 1)
			ammoBarFill.Size = UDim2.fromScale(frac, 1)
			ammoBarFill.BackgroundColor3 = if isEmpty
				then Color3.fromRGB(238, 62, 68)
				elseif isLow then Color3.fromRGB(248, 192, 54)
				else profile.AccentColor
		end
	end

	-- Bottom Reload Progress / Controls Status Bar
	if reloadBarFill and reloadStatusLabel then
		if isReloading and reloadState then
			local rs = reloadState
			local prog: number
			if rs.Style == "Magazine" then
				prog = math.clamp((now - rs.StartTime) / math.max(0.1, rs.TotalDuration), 0, 1)
				reloadStatusLabel.Text = string.format("🔄 RELOADING... %d%%", math.floor(prog * 100))
			else
				if rs.Phase == "InsertShell" then
					prog = math.clamp((now - rs.PhaseStart) / math.max(0.1, rs.PhaseDuration), 0, 1)
					reloadStatusLabel.Text = if st.Mag >= 1
						then string.format("🔄 LOADING SHELL (%d/%d)  •  LMB Shoot", st.Mag, st.MaxMag)
						else string.format("🔄 LOADING SHELL (%d/%d)...", st.Mag, st.MaxMag)
				elseif rs.Phase == "Exit" then
					prog = 1
					reloadStatusLabel.Text = "🔄 RACKING PUMP..."
				else
					prog = 0.12
					reloadStatusLabel.Text = "🔄 LOADING SHELLS..."
				end
			end
			reloadBarFill.Size = UDim2.fromScale(prog, 1)
			reloadBarFill.BackgroundColor3 = Color3.fromRGB(64, 212, 248)
			reloadStatusLabel.TextColor3 = Color3.fromRGB(230, 250, 255)
		elseif isEmpty then
			reloadBarFill.Size = UDim2.fromScale(if isFlashingEmpty then 1 else 0, 1)
			reloadBarFill.BackgroundColor3 = Color3.fromRGB(196, 42, 52)
			if st.Reserve > 0 then
				reloadStatusLabel.Text = "⚠️ EMPTY — PRESS [R] TO RELOAD"
				reloadStatusLabel.TextColor3 = Color3.fromRGB(255, 198, 108)
			else
				reloadStatusLabel.Text = "⚠️ OUT OF AMMO — Base / Black Market"
				reloadStatusLabel.TextColor3 = Color3.fromRGB(255, 134, 134)
			end
		elseif isLow and st.Reserve > 0 then
			reloadBarFill.Size = UDim2.fromScale(0, 1)
			reloadStatusLabel.Text = "LOW AMMO  •  PRESS [R] TO RELOAD"
			reloadStatusLabel.TextColor3 = Color3.fromRGB(255, 224, 118)
		else
			reloadBarFill.Size = UDim2.fromScale(0, 1)
			reloadStatusLabel.Text = "[LMB] Fire   •   [R] Reload"
			reloadStatusLabel.TextColor3 = Color3.fromRGB(186, 204, 232)
		end
	end
end

local function startReload(): ()
	local tool, wid = getEquippedToolAndId()
	if not tool or not wid or not reloadEv then
		return
	end
	if reloadState and reloadState.WeaponId == wid then
		return
	end

	local profile = getProfile(wid)
	local st = ensureLocalAmmo(wid, tool)
	if st.Mag >= st.MaxMag then
		return
	end
	if st.Reserve <= 0 then
		-- Notify server anyway in case player is standing inside their own base safe-zone for free restock
		reloadEv:FireServer(wid, "Start")
		AudioController.PlayDryFire()
		emptyFlashUntil = os.clock() + 0.45
		return
	end

	local now = os.clock()
	if profile.ReloadStyle == "ShellByShell" then
		local startT = profile.ShellStartTime
		local shellT = profile.ShellLoadTime
		reloadState = {
			WeaponId = wid,
			Style = "ShellByShell",
			Phase = "Enter",
			PhaseStart = now,
			PhaseDuration = startT,
			StartTime = now,
			TotalDuration = shellT,
			ShellTime = shellT,
			FinishTime = profile.ShellFinishTime,
			LatchPlayed = false,
			PumpPlayed = false,
			FirstShell = true,
		}
		task.delay(startT, function()
			if reloadState and reloadState.WeaponId == wid and reloadState.StartTime == now and reloadState.Phase == "Enter" then
				reloadState.Phase = "InsertShell"
				reloadState.PhaseStart = os.clock()
				reloadState.PhaseDuration = shellT
			end
		end)
	else
		reloadState = {
			WeaponId = wid,
			Style = "Magazine",
			Phase = "Magazine",
			PhaseStart = now,
			PhaseDuration = profile.ReloadTime,
			StartTime = now,
			TotalDuration = profile.ReloadTime,
			ShellTime = 0,
			FinishTime = 0,
			LatchPlayed = false,
			PumpPlayed = false,
			FirstShell = true,
		}
		AudioController.PlayMagReload(wid)
	end

	reloadEv:FireServer(wid, "Start")
end

local function tryShoot(): ()
	local tool, wid = getEquippedToolAndId()
	if not tool or not wid or not fireEv then
		return
	end

	local char = Players.LocalPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not char or not root or not root:IsA("BasePart") or not hum or hum.Health <= 0 then
		return
	end

	local profile = getProfile(wid)
	local st = ensureLocalAmmo(wid, tool)
	local now = os.clock()

	-- Block firing during magazine reload; allow interrupting shotgun shell-by-shell reload when >= 1 shell loaded
	if reloadState and reloadState.WeaponId == wid then
		if profile.ReloadStyle == "ShellByShell" and st.Mag >= 1 then
			reloadState = nil
		else
			return
		end
	end

	-- Prevent firing when empty and require the player to press [R] to reload!
	if st.Mag <= 0 then
		if (now - lastDryFireAt) >= 0.28 then
			lastDryFireAt = now
			AudioController.PlayDryFire()
			emptyFlashUntil = now + 0.45
		end
		return
	end

	if (now - lastClientFire) < profile.Cooldown then
		return
	end
	lastClientFire = now

	-- 1. IMMEDIATE 0ms gunshot audio response! (Preloaded & pooled, zero server-RTT delay!)
	AudioController.PlayWeaponFire(wid, 1.0)

	-- 2. Optimistic client magazine decrement (sequence-tracked for flicker-free server sync)
	st.Mag = math.max(0, st.Mag - 1)
	shotSeqCounter += 1
	local seq = shotSeqCounter
	lastSentSeqByWeapon[wid] = seq
	lastShotTimeByWeapon[wid] = now

	-- 3. Moderate, realistic weapon-specific 2-axis recoil impulse (upward climb + backward kick!)
	recoilYawSign = -recoilYawSign
	recoilBack = math.min(profile.MaxBack, recoilBack + profile.KickBack)
	recoilUp = math.min(0.22, recoilUp + profile.KickUp)
	recoilPitch = math.min(profile.MaxPitchDeg, recoilPitch + profile.KickPitchDeg)
	recoilYaw = math.clamp(recoilYaw + recoilYawSign * profile.KickYawDeg * (0.6 + math.random() * 0.6), -4.5, 4.5)
	recoilSpreadPx = math.min(18, recoilSpreadPx + profile.CrosshairBloom)
	aimFaceHoldUntil = now + 0.55

	-- 4. Immediate Muzzle Flash + Shell Ejection (Shotgun pumps & ejects red shell on backstroke!)
	playMuzzleFlash(tool, wid)
	if wid == "PepperShotgun" then
		lastShotgunPumpStart = now
		local capturedTool = tool
		task.delay(0.28, function()
			local curTool, curWid = getEquippedToolAndId()
			if curTool == capturedTool and curWid == "PepperShotgun" and not reloadState then
				AudioController.PlayShotgunPump()
				ejectShellCasing(capturedTool, "PepperShotgun")
			end
		end)
	else
		ejectShellCasing(tool, wid)
	end

	-- 5. Fire authoritative shot to server using clean filtered aim target (NO hard character snap!)
	local hitPos = getCleanAimWorldPoint(char, root)
	fireEv:FireServer(wid, hitPos, seq)
end

local function handleAmmoSync(payload: any): ()
	if typeof(payload) ~= "table" then
		return
	end
	local eventType = payload.Type
	if eventType == "Full" and typeof(payload.Weapons) == "table" then
		for wid, data in pairs(payload.Weapons) do
			if typeof(wid) == "string" and typeof(data) == "table" then
				local profile = getProfile(wid)
				localAmmo[wid] = {
					Mag = if typeof(data.Mag) == "number" then data.Mag else profile.DefaultMag,
					MaxMag = if typeof(data.MaxMag) == "number" then data.MaxMag else profile.DefaultMag,
					Reserve = if typeof(data.Reserve) == "number" then data.Reserve else profile.DefaultReserve,
					ReserveMax = if typeof(data.ReserveMax) == "number" then data.ReserveMax else profile.DefaultReserve,
					ReloadStyle = profile.ReloadStyle,
				}
			end
		end
		return
	end

	local wid = payload.WeaponId
	if typeof(wid) ~= "string" then
		return
	end
	local profile = getProfile(wid)
	local st = ensureLocalAmmo(wid, nil)
	local now = os.clock()

	-- Always keep Reserve & Max synced; guard Mag against stale in-flight SMG shot ACKs
	if typeof(payload.MaxMag) == "number" then st.MaxMag = payload.MaxMag end
	if typeof(payload.Reserve) == "number" then st.Reserve = payload.Reserve end
	if typeof(payload.ReserveMax) == "number" then st.ReserveMax = payload.ReserveMax end

	local ackSeq = payload.AckSeq
	local lastSeq = lastSentSeqByWeapon[wid] or 0
	local lastShotAt = lastShotTimeByWeapon[wid] or 0
	local acceptMag = (eventType ~= "Update")
		or (typeof(ackSeq) ~= "number")
		or (ackSeq >= lastSeq)
		or ((now - lastShotAt) > 0.6)

	if acceptMag and typeof(payload.Mag) == "number" then
		st.Mag = payload.Mag
	end

	if eventType == "ReloadStart" then
		if payload.ReloadStyle == "ShellByShell" then
			local startT = if typeof(payload.StartTime) == "number" then payload.StartTime else profile.ShellStartTime
			local shellT = if typeof(payload.ShellTime) == "number" then payload.ShellTime else profile.ShellLoadTime
			local finishT = if typeof(payload.FinishTime) == "number" then payload.FinishTime else profile.ShellFinishTime
			if not reloadState or reloadState.WeaponId ~= wid then
				reloadState = {
					WeaponId = wid,
					Style = "ShellByShell",
					Phase = "Enter",
					PhaseStart = now,
					PhaseDuration = startT,
					StartTime = now,
					TotalDuration = shellT,
					ShellTime = shellT,
					FinishTime = finishT,
					LatchPlayed = false,
					PumpPlayed = false,
					FirstShell = true,
				}
			end
			-- Transition from Enter to first InsertShell phase aligned with start time
			local capturedStart = reloadState.StartTime
			local remainingEnter = math.max(0, startT - (now - capturedStart))
			task.delay(remainingEnter, function()
				if reloadState and reloadState.WeaponId == wid and reloadState.StartTime == capturedStart and reloadState.Phase == "Enter" then
					reloadState.Phase = "InsertShell"
					reloadState.PhaseStart = os.clock()
					reloadState.PhaseDuration = shellT
				end
			end)
		else
			local dur = if typeof(payload.Duration) == "number" then payload.Duration else profile.ReloadTime
			if not reloadState or reloadState.WeaponId ~= wid then
				reloadState = {
					WeaponId = wid,
					Style = "Magazine",
					Phase = "Magazine",
					PhaseStart = now,
					PhaseDuration = dur,
					StartTime = now,
					TotalDuration = dur,
					ShellTime = 0,
					FinishTime = 0,
					LatchPlayed = false,
					PumpPlayed = false,
					FirstShell = true,
				}
				AudioController.PlayMagReload(wid)
			else
				reloadState.TotalDuration = dur
				reloadState.PhaseDuration = dur
			end
		end
	elseif eventType == "ShellLoaded" then
		-- Synchronized individual shell insertion sound & animation step!
		AudioController.PlayShotgunShellInsert()
		if reloadState and reloadState.WeaponId == wid then
			local hasMore = payload.HasMore == true
			if hasMore then
				local shellT = if typeof(payload.ShellTime) == "number" then payload.ShellTime else profile.ShellLoadTime
				reloadState.Phase = "InsertShell"
				reloadState.FirstShell = false
				reloadState.PhaseStart = now
				reloadState.PhaseDuration = shellT
			else
				local finishT = if typeof(payload.FinishTime) == "number" then payload.FinishTime else profile.ShellFinishTime
				reloadState.Phase = "Exit"
				reloadState.PhaseStart = now
				reloadState.PhaseDuration = finishT
				if not reloadState.PumpPlayed then
					reloadState.PumpPlayed = true
					AudioController.PlayShotgunPump()
				end
			end
		end
	elseif eventType == "ReloadComplete" then
		if reloadState and reloadState.WeaponId == wid then
			if reloadState.Style == "Magazine" and not reloadState.LatchPlayed then
				AudioController.PlayMagLatch()
			end
			reloadState = nil
		end
	elseif eventType == "ReloadCancel" then
		if reloadState and reloadState.WeaponId == wid then
			reloadState = nil
		end
	elseif eventType == "DryFire" then
		st.Mag = 0
		emptyFlashUntil = now + 0.45
	end
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

-- Compact, razor-sharp "+" Crosshair with smooth dynamic recoil expansion
local function buildCompactPlusCrosshair(parent: Instance): Frame
	table.clear(reticleTicks)
	local root = Instance.new("Frame")
	root.Name = "BlackTargetReticle"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Size = UDim2.fromOffset(36, 36)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = parent

	local centerDot = Instance.new("Frame")
	centerDot.Name = "CenterDot"
	centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
	centerDot.Position = UDim2.fromScale(0.5, 0.5)
	centerDot.Size = UDim2.fromOffset(2, 2)
	centerDot.BackgroundColor3 = BLACK_COLOR
	centerDot.BorderSizePixel = 0
	centerDot.Parent = root

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
		reticleTicks[ts.Name] = line
	end

	return root
end

local function buildWeaponAmmoCard(parent: Instance): ()
	-- Right-column tactical Ammo Card: cleanly below UrbanTurfCard (Y=264) and above IslandMinimap (Y=356+)
	local card = Instance.new("Frame")
	card.Name = "WeaponAmmoCard"
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, -14, 0, 268)
	card.Size = UDim2.fromOffset(216, 82)
	card.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
	card.BackgroundTransparency = 0.08
	card.Visible = false
	card.Parent = parent
	ammoCard = card

	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 10)
	cc.Parent = card

	local cs = Instance.new("UIStroke")
	cs.Color = Color3.fromRGB(246, 192, 54)
	cs.Thickness = 1.6
	cs.Parent = card
	ammoCardStroke = cs

	-- Header row: Weapon name (left) + Ammo type badge (right)
	local wLbl = Instance.new("TextLabel")
	wLbl.Name = "WeaponName"
	wLbl.Position = UDim2.new(0, 8, 0, 4)
	wLbl.Size = UDim2.new(1, -76, 0, 16)
	wLbl.BackgroundTransparency = 1
	wLbl.Font = Enum.Font.GothamBlack
	wLbl.TextXAlignment = Enum.TextXAlignment.Left
	wLbl.Text = "🔫 STREET PISTOL"
	wLbl.TextSize = 10
	wLbl.TextColor3 = Color3.fromRGB(242, 246, 255)
	wLbl.Parent = card
	ammoWeaponLabel = wLbl

	local tBadge = Instance.new("TextLabel")
	tBadge.Name = "AmmoTypeBadge"
	tBadge.AnchorPoint = Vector2.new(1, 0)
	tBadge.Position = UDim2.new(1, -7, 0, 4)
	tBadge.Size = UDim2.fromOffset(64, 15)
	tBadge.BackgroundColor3 = Color3.fromRGB(142, 152, 174)
	tBadge.Font = Enum.Font.GothamBlack
	tBadge.Text = "9mm MAG"
	tBadge.TextSize = 8
	tBadge.TextColor3 = Color3.fromRGB(16, 20, 30)
	tBadge.Parent = card
	local tbc = Instance.new("UICorner")
	tbc.CornerRadius = UDim.new(0, 4)
	tbc.Parent = tBadge
	ammoTypeBadge = tBadge

	-- Main Numeric Ammo Counter: [12] [/ 12]   |   [96]
	local magLbl = Instance.new("TextLabel")
	magLbl.Name = "MagCount"
	magLbl.Position = UDim2.new(0, 8, 0, 19)
	magLbl.Size = UDim2.fromOffset(46, 26)
	magLbl.BackgroundTransparency = 1
	magLbl.Font = Enum.Font.GothamBlack
	magLbl.TextXAlignment = Enum.TextXAlignment.Right
	magLbl.Text = "12"
	magLbl.TextSize = 23
	magLbl.TextColor3 = Color3.new(1, 1, 1)
	magLbl.Parent = card
	ammoMagLabel = magLbl

	local maxLbl = Instance.new("TextLabel")
	maxLbl.Name = "MaxCount"
	maxLbl.Position = UDim2.new(0, 57, 0, 26)
	maxLbl.Size = UDim2.fromOffset(44, 18)
	maxLbl.BackgroundTransparency = 1
	maxLbl.Font = Enum.Font.GothamBold
	maxLbl.TextXAlignment = Enum.TextXAlignment.Left
	maxLbl.Text = "/ 12"
	maxLbl.TextSize = 13
	maxLbl.TextColor3 = Color3.fromRGB(158, 172, 198)
	maxLbl.Parent = card
	ammoMaxLabel = maxLbl

	local divider = Instance.new("Frame")
	divider.Position = UDim2.new(0, 108, 0, 24)
	divider.Size = UDim2.fromOffset(2, 20)
	divider.BackgroundColor3 = Color3.fromRGB(64, 78, 106)
	divider.BorderSizePixel = 0
	divider.Parent = card

	local resCaption = Instance.new("TextLabel")
	resCaption.Position = UDim2.new(0, 118, 0, 20)
	resCaption.Size = UDim2.fromOffset(88, 11)
	resCaption.BackgroundTransparency = 1
	resCaption.Font = Enum.Font.GothamBold
	resCaption.TextXAlignment = Enum.TextXAlignment.Left
	resCaption.Text = "RESERVE"
	resCaption.TextSize = 8
	resCaption.TextColor3 = Color3.fromRGB(142, 162, 194)
	resCaption.Parent = card

	local resLbl = Instance.new("TextLabel")
	resLbl.Name = "ReserveCount"
	resLbl.Position = UDim2.new(0, 118, 0, 29)
	resLbl.Size = UDim2.fromOffset(88, 18)
	resLbl.BackgroundTransparency = 1
	resLbl.Font = Enum.Font.GothamBlack
	resLbl.TextXAlignment = Enum.TextXAlignment.Left
	resLbl.Text = "96"
	resLbl.TextSize = 15
	resLbl.TextColor3 = Color3.fromRGB(148, 224, 255)
	resLbl.Parent = card
	ammoReserveLabel = resLbl

	-- Magazine Fill Bar (Pistol / SMG)
	local mBarBg = Instance.new("Frame")
	mBarBg.Name = "MagFillBarBg"
	mBarBg.Position = UDim2.new(0, 8, 0, 49)
	mBarBg.Size = UDim2.new(1, -16, 0, 7)
	mBarBg.BackgroundColor3 = Color3.fromRGB(32, 40, 58)
	mBarBg.BorderSizePixel = 0
	mBarBg.Parent = card
	local mbgc = Instance.new("UICorner")
	mbgc.CornerRadius = UDim.new(0, 4)
	mbgc.Parent = mBarBg
	ammoBarBg = mBarBg

	local mBarFill = Instance.new("Frame")
	mBarFill.Name = "Fill"
	mBarFill.Size = UDim2.fromScale(1, 1)
	mBarFill.BackgroundColor3 = Color3.fromRGB(246, 188, 52)
	mBarFill.BorderSizePixel = 0
	mBarFill.Parent = mBarBg
	local mfc = Instance.new("UICorner")
	mfc.CornerRadius = UDim.new(0, 4)
	mfc.Parent = mBarFill
	ammoBarFill = mBarFill

	-- Individual Shell Pips Row (Shotgun!)
	local pipHolder = Instance.new("Frame")
	pipHolder.Name = "ShotgunShellPips"
	pipHolder.Position = UDim2.new(0, 8, 0, 48)
	pipHolder.Size = UDim2.new(1, -16, 0, 9)
	pipHolder.BackgroundTransparency = 1
	pipHolder.Visible = false
	pipHolder.Parent = card
	shellPipHolder = pipHolder

	local pipLayout = Instance.new("UIListLayout")
	pipLayout.FillDirection = Enum.FillDirection.Horizontal
	pipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	pipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pipLayout.Padding = UDim.new(0, 5)
	pipLayout.Parent = pipHolder

	table.clear(shellPips)
	for i = 1, 8 do
		local pip = Instance.new("Frame")
		pip.Name = "Shell_" .. tostring(i)
		pip.Size = UDim2.fromOffset(29, 8)
		pip.BackgroundColor3 = Color3.fromRGB(238, 72, 54)
		pip.BorderSizePixel = 0
		pip.Parent = pipHolder
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0, 3)
		pc.Parent = pip
		table.insert(shellPips, pip)
	end

	-- Bottom Reload Progress / Hint Bar
	local rBg = Instance.new("Frame")
	rBg.Name = "ReloadStatusBar"
	rBg.Position = UDim2.new(0, 8, 1, -20)
	rBg.Size = UDim2.new(1, -16, 0, 15)
	rBg.BackgroundColor3 = Color3.fromRGB(11, 16, 26)
	rBg.BorderSizePixel = 0
	rBg.Parent = card
	local rbgc = Instance.new("UICorner")
	rbgc.CornerRadius = UDim.new(0, 4)
	rbgc.Parent = rBg
	reloadBarBg = rBg

	local rFill = Instance.new("Frame")
	rFill.Name = "ProgressFill"
	rFill.Size = UDim2.fromScale(0, 1)
	rFill.BackgroundColor3 = Color3.fromRGB(64, 212, 248)
	rFill.BorderSizePixel = 0
	rFill.Parent = rBg
	local rfc = Instance.new("UICorner")
	rfc.CornerRadius = UDim.new(0, 4)
	rfc.Parent = rFill
	reloadBarFill = rFill

	local rLbl = Instance.new("TextLabel")
	rLbl.Name = "StatusText"
	rLbl.Size = UDim2.fromScale(1, 1)
	rLbl.BackgroundTransparency = 1
	rLbl.Font = Enum.Font.GothamBlack
	rLbl.Text = "[LMB] Fire   •   [R] Reload"
	rLbl.TextSize = 9
	rLbl.TextColor3 = Color3.fromRGB(186, 204, 232)
	rLbl.ZIndex = 3
	rLbl.Parent = rBg
	reloadStatusLabel = rLbl
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

	-- 3. Bottom-Left Weapon Ammo & Reload HUD
	buildWeaponAmmoCard(gui)

	-- 4. Compact Dynamic "+" Target Crosshair
	reticleFrame = buildCompactPlusCrosshair(gui)
end

function WeaponController.Start(onOpenBlackMarket: () -> ()): ()
	AudioController.Preload()
	buildAimUI()

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
		if not remotes then return end

		local wFire = remotes:WaitForChild("WeaponFire", 15)
		if wFire and wFire:IsA("RemoteEvent") then
			fireEv = wFire
		end

		local wReload = remotes:WaitForChild("WeaponReload", 15)
		if wReload and wReload:IsA("RemoteEvent") then
			reloadEv = wReload
		end

		local aSync = remotes:WaitForChild("AmmoSync", 15)
		if aSync and aSync:IsA("RemoteEvent") then
			aSync.OnClientEvent:Connect(handleAmmoSync)
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
		elseif input.KeyCode == Enum.KeyCode.R then
			startReload()
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

		-- Detect weapon switch / unequip and cleanly reset aim/reload state
		if tool ~= lastEquippedTool or wid ~= lastEquippedWid then
			if reloadState and reloadState.WeaponId ~= wid then
				if reloadEv then
					reloadEv:FireServer(reloadState.WeaponId, "Cancel")
				end
				reloadState = nil
			end
			lastEquippedTool = tool
			lastEquippedWid = wid
			smoothedAimDir = nil
			recoilBack = 0
			recoilUp = 0
			recoilPitch = 0
			recoilYaw = 0
			recoilSpreadPx = 0
		end

		-- Safety watchdog in case a reload request was ignored by server
		if reloadState then
			local nowWatch = os.clock()
			if reloadState.Style == "Magazine" and (nowWatch - reloadState.StartTime) > (reloadState.TotalDuration + 1.5) then
				reloadState = nil
			elseif reloadState.Style == "ShellByShell" and (nowWatch - reloadState.PhaseStart) > (math.max(0.5, reloadState.PhaseDuration) + 1.8) then
				reloadState = nil
			end
		end

		updateAmmoHUD(tool, wid)

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

		reticleFrame.Visible = true
		UserInputService.MouseIconEnabled = false
		local mousePos = UserInputService:GetMouseLocation()
		reticleFrame.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
		updateReticleBloom()

		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if char and root and root:IsA("BasePart") then
			local aimWorldPos = getCleanAimWorldPoint(char, root)
			updateFullBodyGunAiming(dt, tool, wid, aimWorldPos)
		end

		if isMouseDown and wid == "TacticalSMG" then
			tryShoot()
		end
	end)
end

return WeaponController
