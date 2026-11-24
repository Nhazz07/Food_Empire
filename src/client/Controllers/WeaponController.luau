--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local WeaponConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WeaponConfig")
)
local AudioController = require("./AudioController")

local WeaponController = {}

type WeaponProfile = {
	DisplayName: string,
	Icon: string,
	AmmoType: string,
	ReloadStyle: "Magazine" | "ShellByShell",
	AutoFire: boolean,
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
	IsMelee: boolean,
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

local CATEGORY_HANDLING: { [WeaponConfig.WeaponCategory]: {
	BladedYawDeg: number,
	StancePos: Vector3,
	LeftGripLocal: Vector3,
	ReloadPortLocal: Vector3,
	RecoverSpeed: number,
	CrosshairBloom: number,
} } = {
	Pistol = {
		BladedYawDeg = 12,
		StancePos = Vector3.new(0.18, 0.78, -1.40),
		LeftGripLocal = Vector3.new(-0.14, -0.04, -0.14),
		ReloadPortLocal = Vector3.new(0, -0.45, 0.02),
		RecoverSpeed = 12.5,
		CrosshairBloom = 5,
	},
	Shotgun = {
		BladedYawDeg = 25,
		StancePos = Vector3.new(0.41, 0.68, -0.82),
		LeftGripLocal = Vector3.new(-0.12, 0.34, -1.48),
		ReloadPortLocal = Vector3.new(-0.04, 0.24, -0.48),
		RecoverSpeed = 8.0,
		CrosshairBloom = 11,
	},
	SMG = {
		BladedYawDeg = 23,
		StancePos = Vector3.new(0.39, 0.70, -0.86),
		LeftGripLocal = Vector3.new(-0.10, 0.12, -1.36),
		ReloadPortLocal = Vector3.new(0, -0.35, -0.82),
		RecoverSpeed = 13.5,
		CrosshairBloom = 4,
	},
	AssaultRifle = {
		BladedYawDeg = 25,
		StancePos = Vector3.new(0.40, 0.69, -0.84),
		LeftGripLocal = Vector3.new(-0.10, 0.24, -1.62),
		ReloadPortLocal = Vector3.new(0, -0.32, -0.86),
		RecoverSpeed = 11.8,
		CrosshairBloom = 5.5,
	},
	Sniper = {
		BladedYawDeg = 27,
		StancePos = Vector3.new(0.42, 0.70, -0.80),
		LeftGripLocal = Vector3.new(-0.10, 0.34, -1.72),
		ReloadPortLocal = Vector3.new(0, 0.02, -0.78),
		RecoverSpeed = 7.5,
		CrosshairBloom = 10,
	},
	Melee = {
		BladedYawDeg = 18,
		StancePos = Vector3.new(0.56, 0.56, -1.02),
		LeftGripLocal = Vector3.new(-0.14, -0.18, 0.10),
		ReloadPortLocal = Vector3.new(0, 0, 0),
		RecoverSpeed = 14.0,
		CrosshairBloom = 4,
	},
}

local WEAPON_PROFILES: { [string]: WeaponProfile } = {}
for _, wid in ipairs(WeaponConfig.WEAPON_ORDER) do
	local w = WeaponConfig.WEAPONS[wid]
	if w then
		local h = CATEGORY_HANDLING[w.Category] or CATEGORY_HANDLING.Pistol
		local ammoSpec = WeaponConfig.AMMO_TYPES[w.AmmoType]
		WEAPON_PROFILES[wid] = {
			DisplayName = string.upper(w.DisplayName),
			Icon = w.Icon,
			AmmoType = string.upper(if ammoSpec then ammoSpec.ShortName else w.AmmoType),
			ReloadStyle = w.ReloadType,
			AutoFire = w.AutoFire,
			DefaultMag = w.MagSize,
			DefaultReserve = if ammoSpec then ammoSpec.StarterReserve else 60,
			Cooldown = w.Cooldown,
			ReloadTime = if w.ReloadType == "Magazine" then w.ReloadTime else 0,
			ShellStartTime = if w.ReloadType == "ShellByShell" then 0.20 else 0,
			ShellLoadTime = if w.ReloadType == "ShellByShell" then w.ReloadTime else 0,
			ShellFinishTime = w.ShellFinishTime or 0.24,
			BladedYawDeg = h.BladedYawDeg,
			StancePos = h.StancePos,
			LeftGripLocal = h.LeftGripLocal,
			ReloadPortLocal = h.ReloadPortLocal,
			KickBack = w.RecoilBackStuds,
			KickUp = w.RecoilBackStuds * 0.34,
			KickPitchDeg = w.RecoilPitchDeg,
			KickYawDeg = w.RecoilYawDeg,
			MaxPitchDeg = w.RecoilCapDeg,
			MaxBack = math.min(0.46, w.RecoilBackStuds * 1.65),
			RecoverSpeed = h.RecoverSpeed,
			CrosshairBloom = h.CrosshairBloom,
			AccentColor = w.AccentColor,
			IsMelee = (w.IsMelee == true),
		}
	end
end

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
local hpPillFrame: Frame? = nil
local armorPillFrame: Frame? = nil
local reticleFrame: Frame? = nil
local reticleTicks: { [string]: Frame } = {}
local playerHpFill: Frame? = nil
local playerHpLabel: TextLabel? = nil
local playerArmorFill: Frame? = nil
local playerArmorLabel: TextLabel? = nil

-- Shadow Sniper Functional Scope System State & UI References
local SNIPER_ZOOM_LEVELS = {
	{ Label = "2.0x", FOV = 34, Sens = 0.55 },
	{ Label = "4.0x", FOV = 18, Sens = 0.30 },
	{ Label = "8.0x", FOV = 9,  Sens = 0.16 },
}
local DEFAULT_CAMERA_FOV = 70

local isScoped = false
local scopeZoomIndex = 2 -- Defaults to comfortable 4.0x magnification
local savedCameraMode: Enum.CameraMode = Enum.CameraMode.Classic
local savedHudEnabled: { [ScreenGui]: boolean } = {}
local scopeOverlay: Frame? = nil
local scopeLensBox: Frame? = nil
local scopeLensCircle: Frame? = nil
local scopeLensMaskStroke: UIStroke? = nil
local scopeTopMask: Frame? = nil
local scopeBottomMask: Frame? = nil
local scopeLeftMask: Frame? = nil
local scopeRightMask: Frame? = nil
local scopeZoomReadout: TextLabel? = nil
local scopeDistReadout: TextLabel? = nil
local scopeAmmoReadout: TextLabel? = nil
local scopeZoomBtns: { TextButton } = {}
local scopeTriggerBtn: TextButton? = nil
local scopeFireBtn: TextButton? = nil
local scopeRecoilKick = 0
local disableGunIK: () -> ()

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

-- Smoothed Aiming, Sway, Shooter Locomotion & 2-Axis Recoil State
local smoothedAimDir: Vector3? = nil
local smoothedMoveBlend = 0
local swayPhase = 0
local aimFaceHoldUntil = 0

-- Real Third-Person Shooter Movement State (Strafe, Tactical Sprint, ADS & Crouch)
local isShiftHeld = false
local isAimingADS = false
local isCrouching = false
local adsBlend = 0
local sprintBlend = 0
local crouchBlend = 0
local lowReadyBlend = 0
local lastMeleeSlashAt = -10
local meleeSlashSide = 1
local hitmarkerFrame: Frame? = nil
local hitmarkerHideAt = 0
local killFeedHolder: Frame? = nil
local gunCameraBlend = 0

local function isScopeRifle(wid: string?): boolean
	return wid == "ShadowSniper" or wid == "PhantomAssassinRifle"
end
local smoothedLocalFwd = 0
local smoothedLocalRight = 0
local locomotionDist = 0
local gunMovementActive = false
local gunWalkSpeedManaged = false
local activeCharScale = 1.0

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

-- Clean, filtered cursor (or center-lens when scoped!) raycast that ignores the player, their bike, guide arrow, and transient combat VFX
local function getCleanAimWorldPoint(char: Model, root: BasePart): (Vector3, number?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return root.Position + root.CFrame.LookVector * 60, nil
	end

	local unitRay: Ray
	if isScoped then
		local vp = camera.ViewportSize
		unitRay = camera:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5)
	else
		local mouseLoc = UserInputService:GetMouseLocation()
		unitRay = camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
	end

	local ignoreList: { Instance } = { char }
	local playerName = Players.LocalPlayer.Name
	local bike = Workspace:FindFirstChild("SportMotorbike_" .. playerName)
	if bike then table.insert(ignoreList, bike) end
	local arrow = Workspace:FindFirstChild("FoodEmpireGuideArrow")
	if arrow then table.insert(ignoreList, arrow) end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignoreList

	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 480, rayParams)
	local hitPos = if result then result.Position else (unitRay.Origin + unitRay.Direction * 260)
	local hitDist: number? = if result then (result.Position - unitRay.Origin).Magnitude else nil

	-- Guard against camera-adjacent wall/pillar hits closer than 4.5 studs from the player's torso
	if not isScoped then
		local toHit = hitPos - root.Position
		if toHit.Magnitude < 4.5 then
			hitPos = unitRay.Origin + unitRay.Direction * 60
		end
	end

	return hitPos, hitDist
end

local function setLocalCharacterHiddenForScope(hidden: boolean): ()
	local char = Players.LocalPlayer.Character
	if not char then return end
	local mod = if hidden then 1 else 0
	for _, desc in ipairs(char:GetDescendants()) do
		if desc:IsA("BasePart") or desc:IsA("Decal") then
			desc.LocalTransparencyModifier = mod
		end
	end
end

local function refreshScopeZoomButtons(): ()
	for i, b in ipairs(scopeZoomBtns) do
		local active = (i == scopeZoomIndex)
		b.BackgroundColor3 = if active then Color3.fromRGB(134, 28, 36) else Color3.fromRGB(20, 22, 28)
		b.TextColor3 = if active then Color3.fromRGB(244, 240, 232) else Color3.fromRGB(162, 166, 174)
	end
end

local function exitSniperScope(): ()
	if not isScoped then
		return
	end
	isScoped = false
	scopeRecoilKick = 0

	if scopeOverlay then
		scopeOverlay.Visible = false
	end
	if hpPillFrame then hpPillFrame.Visible = true end
	if armorPillFrame then armorPillFrame.Visible = true end

	-- Restore every hidden ScreenGui back to its exact previous Enabled state
	for gui, wasEnabled in pairs(savedHudEnabled) do
		if gui and gui.Parent then
			gui.Enabled = wasEnabled
		end
	end
	table.clear(savedHudEnabled)

	-- Restore normal camera, sensitivity & character visibility smoothly
	Players.LocalPlayer.CameraMode = savedCameraMode
	UserInputService.MouseDeltaSensitivity = 1.0
	setLocalCharacterHiddenForScope(false)
end

local function enterSniperScope(): ()
	local tool, wid = getEquippedToolAndId()
	if not tool or wid ~= "ShadowSniper" then
		return
	end
	if reloadState and reloadState.WeaponId == wid then
		return
	end
	local char = Players.LocalPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not hum or hum.Health <= 0 then
		return
	end
	if isScoped then
		return
	end

	isScoped = true
	isAimingADS = false
	adsBlend = 0
	sprintBlend = 0
	hum.CameraOffset = Vector3.zero
	disableGunIK()

	-- Hide unnecessary HUD elements cleanly while preserving exact restore state
	table.clear(savedHudEnabled)
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		for _, ch in ipairs(playerGui:GetChildren()) do
			if ch:IsA("ScreenGui") and ch ~= aimGui then
				savedHudEnabled[ch] = ch.Enabled
				ch.Enabled = false
			end
		end
	end

	if hpPillFrame then hpPillFrame.Visible = false end
	if armorPillFrame then armorPillFrame.Visible = false end
	if ammoCard then ammoCard.Visible = false end
	if reticleFrame then reticleFrame.Visible = false end
	if scopeTriggerBtn then scopeTriggerBtn.Visible = false end
	if scopeOverlay then scopeOverlay.Visible = true end

	savedCameraMode = Players.LocalPlayer.CameraMode
	Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	local zSpec = SNIPER_ZOOM_LEVELS[scopeZoomIndex] or SNIPER_ZOOM_LEVELS[2]
	UserInputService.MouseDeltaSensitivity = zSpec.Sens
	setLocalCharacterHiddenForScope(true)
	refreshScopeZoomButtons()
	AudioController.PlayClick()
end

local function toggleSniperScope(): ()
	if isScoped then
		exitSniperScope()
	else
		enterSniperScope()
	end
end

local function setSniperZoomIndex(nextIdx: number): ()
	local clamped = math.clamp(nextIdx, 1, #SNIPER_ZOOM_LEVELS)
	if clamped == scopeZoomIndex then
		return
	end
	scopeZoomIndex = clamped
	local zSpec = SNIPER_ZOOM_LEVELS[scopeZoomIndex]
	if isScoped and zSpec then
		UserInputService.MouseDeltaSensitivity = zSpec.Sens
	end
	refreshScopeZoomButtons()
	AudioController.PlayClick()
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
		local isHeavyFlash = (wid == "PepperShotgun" or wid == "AutoCombatShotgun" or wid == "ShadowSniper")
		spark.Size = if isHeavyFlash then Vector3.new(0.80, 0.80, 1.25) else Vector3.new(0.48, 0.48, 0.88)
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
		local isShotgunShell = (wid == "PepperShotgun" or wid == "AutoCombatShotgun")
		shell.Size = if isShotgunShell then Vector3.new(0.32, 0.14, 0.14) else Vector3.new(0.22, 0.10, 0.10)
		shell.Color = if isShotgunShell then Color3.fromRGB(204, 44, 44) else Color3.fromRGB(242, 198, 72)
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

disableGunIK = function(): ()
	if headLookIK then headLookIK.Enabled = false end
	if rightArmIK then rightArmIK.Enabled = false end
	if leftArmIK then leftArmIK.Enabled = false end
	restoreAutoRotate()
	gunMovementActive = false
	smoothedAimDir = nil
	recoilBack = 0
	recoilUp = 0
	recoilPitch = 0
	recoilYaw = 0
	recoilSpreadPx = 0
	if gunWalkSpeedManaged then
		gunWalkSpeedManaged = false
		local char = Players.LocalPlayer.Character
		local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		if hum and not hum.Sit and hum.WalkSpeed < 27.5 then
			hum.WalkSpeed = if isShiftHeld then 26 else 16
		end
	end
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
	activeCharScale = charScale
	gunMovementActive = not hum.Sit

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
	local crouchDropY = 1.10 * charScale * crouchBlend
	local shoulderOrigin = root.Position + Vector3.new(0, 0.80 * charScale - crouchDropY, 0)
	local rawVec = rawAimWorldPos - shoulderOrigin
	local rawDir = if rawVec.Magnitude > 0.5 then rawVec.Unit else root.CFrame.LookVector
	if not smoothedAimDir then
		smoothedAimDir = rawDir
	else
		local aimAlpha = 1 - math.exp(-20 * clampedDt)
		local blended = smoothedAimDir:Lerp(rawDir, aimAlpha)
		smoothedAimDir = if blended.Magnitude > 0.01 then blended.Unit else rawDir
	end
	local aimDir = smoothedAimDir :: Vector3

	-- 3. Evaluate Real Third-Person Shooter Stances: Tactical Sprint, Over-the-Shoulder ADS & Combat Crouch
	local moveDir = hum.MoveDirection
	local moveSpeed = moveDir.Magnitude
	local activelyShooting = isMouseDown or (now < aimFaceHoldUntil)
	local isReloadingNow = (reloadState ~= nil)
	local wantADS = isAimingADS and (not isScopeRifle(wid)) and (not profile.IsMelee) and not isScoped and not isReloadingNow and not hum.Sit
	local wantSprint = isShiftHeld and (moveSpeed > 0.18) and not activelyShooting and not isReloadingNow and not wantADS and not isScoped and not hum.Sit
	local wantLowReady = (not profile.IsMelee) and (not activelyShooting) and (not wantADS) and (not isReloadingNow) and (not wantSprint) and (not isScoped)

	if wantSprint or hum.Sit or hum:GetState() == Enum.HumanoidStateType.Jumping then
		isCrouching = false
	end
	local wantCrouch = isCrouching and not wantSprint and not hum.Sit

	adsBlend += ((if wantADS then 1 else 0) - adsBlend) * (1 - math.exp(-15 * clampedDt))
	sprintBlend += ((if wantSprint then 1 else 0) - sprintBlend) * (1 - math.exp(-(if wantSprint then 10 else 18) * clampedDt))
	crouchBlend += ((if wantCrouch then 1 else 0) - crouchBlend) * (1 - math.exp(-13 * clampedDt))
	lowReadyBlend += ((if wantLowReady then 1 else 0) - lowReadyBlend) * (1 - math.exp(-(if wantLowReady then 5.5 else 20) * clampedDt))
	if adsBlend < 0.004 then adsBlend = 0 end
	if sprintBlend < 0.004 then sprintBlend = 0 end
	if crouchBlend < 0.004 then crouchBlend = 0 end
	if lowReadyBlend < 0.004 then lowReadyBlend = 0 end

	-- 4. Subtle, smoothly blended idle breathing, walking & tactical sprint rhythm
	smoothedMoveBlend += (math.clamp(moveSpeed, 0, 1) - smoothedMoveBlend) * (1 - math.exp(-10 * clampedDt))
	local horizVel = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local actualSpeed = horizVel.Magnitude
	if actualSpeed > 0.4 and not hum.Sit then
		locomotionDist += actualSpeed * clampedDt
	end
	swayPhase += clampedDt * (1.7 + smoothedMoveBlend * (4.8 + sprintBlend * 3.4))

	local firingSteadiness = (if activelyShooting then 0.45 else 1.0) * (1 - 0.42 * adsBlend) * (1 - 0.35 * crouchBlend)
	local swayAmpY = (0.006 + smoothedMoveBlend * 0.014) * firingSteadiness
	local swayAmpX = (0.0035 + smoothedMoveBlend * 0.009) * firingSteadiness
	local swayY = math.sin(swayPhase) * swayAmpY
	local swayX = math.cos(swayPhase * 0.5) * swayAmpX

	-- 5. AAA Third-Person Shooter Facing (NO AutoRotate flip-flop spin!)
	--    * Combat Ready / Strafe / ADS / Firing: Always smoothly faces downrange/aim so W/A/S/D strafing feels locked-in!
	--    * Tactical Sprint (Shift): Smoothly faces travel direction for agile repositioning, snapping right back on fire!
	local camera = Workspace.CurrentCamera
	local camFlatLook = if camera
		then Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
		else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if camFlatLook.Magnitude > 0.05 then
		camFlatLook = camFlatLook.Unit
	else
		camFlatLook = Vector3.new(0, 0, -1)
	end

	local flatAim = Vector3.new(aimDir.X, 0, aimDir.Z)
	local combatFacingDir: Vector3
	if flatAim.Magnitude > 0.05 then
		local aimUnit = flatAim.Unit
		-- If walking/strafing without actively shooting and cursor drifts behind camera, stay facing downrange (camera look)
		if (not activelyShooting) and (not wantADS) and (moveSpeed > 0.12) and (aimUnit:Dot(camFlatLook) < -0.15) then
			combatFacingDir = camFlatLook
		else
			combatFacingDir = aimUnit
		end
	else
		combatFacingDir = camFlatLook
	end

	if not hum.Sit then
		if hum.AutoRotate then
			hum.AutoRotate = false
			autoRotateOverridden = true
		end

		local desiredDir: Vector3
		if sprintBlend > 0.55 and moveSpeed > 0.15 then
			local flatMove = Vector3.new(moveDir.X, 0, moveDir.Z)
			desiredDir = if flatMove.Magnitude > 0.05 then flatMove.Unit else combatFacingDir
		else
			-- Subtle bladed tactical stance (tightens cleanly during ADS/firing, relaxes slightly during strafing)
			local bladeDeg = profile.BladedYawDeg * (0.72 + 0.28 * math.max(adsBlend, if activelyShooting then 1 else 0))
			desiredDir = (CFrame.Angles(0, -math.rad(bladeDeg), 0):VectorToWorldSpace(combatFacingDir)).Unit
		end

		-- Shortest-angle pure yaw rotation (NEVER fights Humanoid floor position or tilts root!)
		local _, curYaw, _ = root.CFrame:ToOrientation()
		local targetYaw = math.atan2(-desiredDir.X, -desiredDir.Z)
		local deltaYaw = math.atan2(math.sin(targetYaw - curYaw), math.cos(targetYaw - curYaw))
		local turnSpeed = if activelyShooting or wantADS then 20 elseif sprintBlend > 0.55 then 12 else 15
		local turnAlpha = 1 - math.exp(-turnSpeed * clampedDt)
		local nextYaw = curYaw + deltaYaw * turnAlpha
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, nextYaw, 0)
		root.AssemblyAngularVelocity = Vector3.zero
	else
		restoreAutoRotate()
	end

	-- 6. Project real horizontal velocity into character local frame for Split-Body Strafe, Lean & Footwork
	local localMove = root.CFrame:VectorToObjectSpace(if moveSpeed > 0.05 then moveDir.Unit * math.min(moveSpeed, 1) else Vector3.zero)
	local rawLocalFwd = -localMove.Z
	local rawLocalRight = localMove.X
	local velAlpha = 1 - math.exp(-12 * clampedDt)
	smoothedLocalFwd += (rawLocalFwd - smoothedLocalFwd) * velAlpha
	smoothedLocalRight += (rawLocalRight - smoothedLocalRight) * velAlpha
	if math.abs(smoothedLocalFwd) < 0.005 then smoothedLocalFwd = 0 end
	if math.abs(smoothedLocalRight) < 0.005 then smoothedLocalRight = 0 end

	-- 7. Responsive Shooter WalkSpeed Curve (respects Medkit 28 adrenaline burst & motorbike!)
	if not hum.Sit and hum.WalkSpeed < 27.5 then
		local baseCombatSpeed = if smoothedLocalFwd < -0.45 then 14.0 else 16.5
		local targetSpeed = baseCombatSpeed
		if wantCrouch then
			targetSpeed = 10.5
		elseif wantADS or isReloadingNow then
			targetSpeed = 11.8
		elseif wantSprint then
			targetSpeed = 23.8
		end
		hum.WalkSpeed = hum.WalkSpeed + (targetSpeed - hum.WalkSpeed) * (1 - math.exp(-14 * clampedDt))
		gunWalkSpeedManaged = true
	end

	-- Adapt elbow poles for natural ADS tuck & low-ready sprint carry
	if rightElbowPoleAtt then
		rightElbowPoleAtt.Position = Vector3.new((2.15 - 0.30 * adsBlend) * charScale, (-0.75 - 0.15 * crouchBlend) * charScale, (0.90 + 0.15 * sprintBlend) * charScale)
	end
	if leftElbowPoleAtt then
		leftElbowPoleAtt.Position = Vector3.new((-2.15 + 0.35 * adsBlend) * charScale, (-0.75 - 0.15 * crouchBlend) * charScale, (0.90 + 0.25 * sprintBlend) * charScale)
	end

	-- 8. Compute natural clamped forward aim direction relative to character body
	local localAimDir = root.CFrame:VectorToObjectSpace(aimDir)
	local horizLen = math.sqrt(localAimDir.X * localAimDir.X + localAimDir.Z * localAimDir.Z)
	local clampedLocalDir: Vector3
	if horizLen > 0.01 then
		local yaw = math.atan2(localAimDir.X, -localAimDir.Z)
		local clampedYaw = math.clamp(yaw, math.rad(-58), math.rad(68))
		local clampedPitchY = math.clamp(localAimDir.Y, -0.60, 0.68)
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

	-- 9. Position Handle cleanly in aim frame (with Realistic Cheek-Weld ADS, Tactical Low-Ready Carry, Crouch drop & Recoil kick!)
	local adsShift = Vector3.new(-0.10 * adsBlend, 0.14 * adsBlend, 0.18 * adsBlend) * charScale
	local lowReadyShift = Vector3.new(-0.08 * lowReadyBlend, -0.18 * lowReadyBlend, 0.08 * lowReadyBlend) * charScale
	local crouchShift = Vector3.new(0, -crouchDropY, -0.06 * crouchBlend * charScale)
	local strafeSway = Vector3.new(-smoothedLocalRight * 0.05 * charScale, -math.abs(smoothedLocalRight) * 0.02 * charScale, 0)
	local stanceWithRecoil = (profile.StancePos * charScale) + adsShift + lowReadyShift + crouchShift + strafeSway + Vector3.new(swayX, swayY + recoilUp, recoilBack)
	local handleWorldPos = (aimBasisCF * CFrame.new(stanceWithRecoil)).Position
	local lookPoint = handleWorldPos + worldClampedDir * 40
	local strafeRollDeg = -smoothedLocalRight * (3.2 * (1 - 0.5 * adsBlend))
	local lowReadyPitchDeg = -14.5 * lowReadyBlend
	local lowReadyYawDeg = 18.0 * lowReadyBlend
	local lowReadyRollDeg = 8.0 * lowReadyBlend
	local baseHandleCF = CFrame.lookAt(handleWorldPos, lookPoint)
		* CFrame.Angles(math.rad(recoilPitch + lowReadyPitchDeg), math.rad(recoilYaw + lowReadyYawDeg), math.rad(strafeRollDeg + lowReadyRollDeg))

	-- Procedural Melee Slash & Katana Cleave Arc Animation!
	if profile.IsMelee then
		local slashDt = now - lastMeleeSlashAt
		local slashDur = if wid == "SamuraiKatana" then 0.34 else 0.24
		if slashDt >= 0 and slashDt <= slashDur then
			local u = slashDt / slashDur
			local swing = math.sin(u * math.pi)
			local arcYaw = meleeSlashSide * (-58 + u * 135)
			local arcPitch = -24 + swing * 42
			local lungeFwd = -0.58 * swing * charScale
			baseHandleCF = baseHandleCF
				* CFrame.new(meleeSlashSide * (0.28 - u * 0.65) * charScale, 0.12 * swing * charScale, lungeFwd)
				* CFrame.Angles(math.rad(arcPitch), math.rad(arcYaw), math.rad(meleeSlashSide * 38 * swing))
		end
	end

	-- 10. Blend seamlessly into Tactical Low-Ready Cross-Chest Sprint Carry Pose when holding [Shift]!
	if sprintBlend > 0.005 then
		local bobX = math.sin(locomotionDist * 0.62) * 0.11 * charScale
		local bobY = math.abs(math.cos(locomotionDist * 0.62)) * 0.09 * charScale
		local sprintPos = (root.CFrame * CFrame.new(
			(0.24 * charScale) + bobX,
			(0.28 * charScale) - crouchDropY + bobY,
			(-1.12 * charScale)
		)).Position
		local sprintCarryCF = CFrame.new(sprintPos)
			* (root.CFrame - root.CFrame.Position)
			* CFrame.Angles(math.rad(-20 + math.sin(locomotionDist * 0.62) * 4), math.rad(46), math.rad(16))
		baseHandleCF = baseHandleCF:Lerp(sprintCarryCF, smoothstep(sprintBlend))
	end

	-- 11. Apply Reload animation OR post-shot Shotgun pump-action cycle
	local finalHandleCF, finalLeftHandPos = computeReloadOffsets(now, profile, charScale, root.CFrame, baseHandleCF)

	if not reloadState and profile.ReloadStyle == "ShellByShell" then
		local pumpElapsed = now - lastShotgunPumpStart
		if pumpElapsed >= 0.22 and pumpElapsed <= 0.62 then
			local u = (pumpElapsed - 0.22) / 0.40
			local pull = math.sin(u * math.pi)
			finalHandleCF = finalHandleCF * CFrame.Angles(math.rad(pull * 2.5), 0, math.rad(pull * 4.0))
			finalLeftHandPos = (finalHandleCF * CFrame.new(profile.LeftGripLocal + Vector3.new(0, 0, 0.46 * pull))).Position
		end
	end

	-- 12. Convert desired Handle CFrame to EXACT RightHand CFrame using the live RightGrip weld
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

-- Supports both legacy Motor6D and modern Roblox Avatar Joint Upgrade AnimationConstraint!
local function getAnimJoint(parent: Instance?, jointName: string): any?
	if not parent then
		return nil
	end
	local j = parent:FindFirstChild(jointName)
	if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
		return j
	end
	return nil
end

-- AAA Split-Body Procedural Locomotion (Runs on Stepped AFTER Animator, BEFORE Render!)
-- Adds: Hip-Torso 8-Way Strafe Counter-Rotation, Weighty Strafe Lean, Grounded Backpedal & Lateral Footwork, and Combat Crouch!
local function applyProceduralShooterLocomotion(): ()
	local char = Players.LocalPlayer.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or hum.Sit or not root or not root:IsA("BasePart") then
		return
	end
	if not gunMovementActive or isScoped then
		return
	end

	local state = hum:GetState()
	local airborne = (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping)
	local charScale = activeCharScale
	local moveMag = math.clamp(math.sqrt(smoothedLocalFwd * smoothedLocalFwd + smoothedLocalRight * smoothedLocalRight), 0, 1)

	-- R15 Full Split-Body Articulation (LowerTorso + Waist + Hips + Knees + Ankles)
	local rootMotor = getAnimJoint(char:FindFirstChild("LowerTorso"), "Root")
	local waistMotor = getAnimJoint(char:FindFirstChild("UpperTorso"), "Waist")

	if rootMotor and waistMotor then
		-- 1. Hip-Torso Counter-Rotation so legs angle naturally into diagonal strafes while chest stays locked on target!
		local hipYaw = 0
		if moveMag > 0.08 and sprintBlend < 0.85 and not airborne then
			local strafeAmt = math.clamp(smoothedLocalRight, -1, 1)
			local fwdSign = if smoothedLocalFwd < -0.18 then -1 else 1
			hipYaw = -strafeAmt * fwdSign * math.rad(34) * (1 - sprintBlend) * math.clamp(moveMag * 1.4, 0, 1)
		end

		-- 2. Combat Crouch vertical hip drop + subtle rhythmic sprint/crouch bob
		local crouchDrop = -1.12 * charScale * crouchBlend
		local sprintBob = if sprintBlend > 0.1 and not airborne then math.abs(math.sin(locomotionDist * 0.62)) * 0.14 * charScale * sprintBlend else 0
		rootMotor.Transform = rootMotor.Transform
			* CFrame.new(0, crouchDrop + sprintBob, 0)
			* CFrame.Angles(0, hipYaw, 0)

		-- 3. Counter-rotate UpperTorso + apply weighty tactical strafe banking & athletic forward lean
		local leanPitch = -math.rad(
			3.5 * (1 - sprintBlend)
			+ 4.5 * adsBlend
			+ 10.5 * sprintBlend
			+ 8.5 * crouchBlend
			+ smoothedLocalFwd * 3.8 * (1 - sprintBlend)
		)
		local leanRoll = -smoothedLocalRight * math.rad(6.2 * (1 - 0.35 * adsBlend))
		waistMotor.Transform = waistMotor.Transform
			* CFrame.Angles(leanPitch, -hipYaw * 0.92, leanRoll)

		-- 4. Grounded Backpedal, Side-Strafe & Combat Crouch Leg Articulation (Fixes Roblox forward-moonwalk skating!)
		if not airborne then
			local lHip = getAnimJoint(char:FindFirstChild("LeftUpperLeg"), "LeftHip")
			local rHip = getAnimJoint(char:FindFirstChild("RightUpperLeg"), "RightHip")
			local lKnee = getAnimJoint(char:FindFirstChild("LeftLowerLeg"), "LeftKnee")
			local rKnee = getAnimJoint(char:FindFirstChild("RightLowerLeg"), "RightKnee")
			local lAnkle = getAnimJoint(char:FindFirstChild("LeftFoot"), "LeftAnkle")
			local rAnkle = getAnimJoint(char:FindFirstChild("RightFoot"), "RightAnkle")

			if lHip and rHip and lKnee and rKnee then
				local backWeight = math.clamp((-smoothedLocalFwd - 0.12) / 0.55, 0, 1)
				local pureSideWeight = math.clamp((math.abs(smoothedLocalRight) - 0.48) / 0.40, 0, 1) * (1 - math.clamp(math.abs(smoothedLocalFwd) * 1.6, 0, 1))
				local footworkBlend = math.clamp(math.max(backWeight, pureSideWeight), 0, 1) * (1 - sprintBlend) * (1 - crouchBlend * 0.85)

				if footworkBlend > 0.02 then
					local stridePhase = locomotionDist * 0.62
					local sinP = math.sin(stridePhase)
					local cosP = math.cos(stridePhase)

					-- Reversed stride for backpedaling; crisp lateral abduction & athletic knee flex for side-strafing!
					local lHipPitch = -sinP * math.rad(28) * backWeight + sinP * math.rad(12) * pureSideWeight
					local rHipPitch = sinP * math.rad(28) * backWeight - sinP * math.rad(12) * pureSideWeight
					local lHipRoll = -math.max(0, sinP) * math.rad(18) * pureSideWeight
					local rHipRoll = math.max(0, -sinP) * math.rad(18) * pureSideWeight
					local lKneeFlex = -math.rad(14 + math.max(0, -cosP) * 34)
					local rKneeFlex = -math.rad(14 + math.max(0, cosP) * 34)

					lHip.Transform = lHip.Transform:Lerp(CFrame.Angles(lHipPitch, 0, lHipRoll), footworkBlend)
					rHip.Transform = rHip.Transform:Lerp(CFrame.Angles(rHipPitch, 0, rHipRoll), footworkBlend)
					lKnee.Transform = lKnee.Transform:Lerp(CFrame.Angles(lKneeFlex, 0, 0), footworkBlend)
					rKnee.Transform = rKnee.Transform:Lerp(CFrame.Angles(rKneeFlex, 0, 0), footworkBlend)
				end

				-- Combat Crouch kneel/bent-knee athletic posture (blends smoothly even while crouch-walking!)
				if crouchBlend > 0.01 then
					local cPhase = locomotionDist * 0.72
					local cStride = math.sin(cPhase) * moveMag * math.rad(22)
					local cHipL = CFrame.Angles(math.rad(54) + cStride, 0, math.rad(-5))
					local cHipR = CFrame.Angles(math.rad(46) - cStride, 0, math.rad(5))
					local cKneeL = CFrame.Angles(math.rad(-88) - math.max(0, -cStride) * 0.4, 0, 0)
					local cKneeR = CFrame.Angles(math.rad(-82) - math.max(0, cStride) * 0.4, 0, 0)
					local cAnkle = CFrame.Angles(math.rad(34), 0, 0)

					lHip.Transform = lHip.Transform:Lerp(cHipL, crouchBlend)
					rHip.Transform = rHip.Transform:Lerp(cHipR, crouchBlend)
					lKnee.Transform = lKnee.Transform:Lerp(cKneeL, crouchBlend)
					rKnee.Transform = rKnee.Transform:Lerp(cKneeR, crouchBlend)
					if lAnkle then
						lAnkle.Transform = lAnkle.Transform:Lerp(cAnkle, crouchBlend)
					end
					if rAnkle then
						rAnkle.Transform = rAnkle.Transform:Lerp(cAnkle, crouchBlend)
					end
				end
			end
		end
	else
		-- R6 Graceful Fallback: lean & crouch drop on RootJoint
		local r6Root = getAnimJoint(root, "RootJoint")
		if r6Root then
			local leanPitch = -math.rad(6 * sprintBlend + 4 * adsBlend + 6 * crouchBlend)
			local leanRoll = -smoothedLocalRight * math.rad(5.5)
			r6Root.Transform = r6Root.Transform
				* CFrame.new(0, -0.95 * charScale * crouchBlend, 0)
				* CFrame.Angles(leanPitch, 0, leanRoll)
		end
	end
end

local function updateReticleBloom(): ()
	local baseGap = 6 - 1.5 * adsBlend - 1.0 * crouchBlend + 4.5 * sprintBlend
	local offset = math.max(3, math.floor(baseGap + recoilSpreadPx + 0.5))
	local tickTrans = 0.45 * sprintBlend
	local top = reticleTicks.Top
	local bot = reticleTicks.Bottom
	local left = reticleTicks.Left
	local right = reticleTicks.Right
	if top then top.Position = UDim2.new(0.5, 0, 0.5, -offset); top.BackgroundTransparency = tickTrans end
	if bot then bot.Position = UDim2.new(0.5, 0, 0.5, offset); bot.BackgroundTransparency = tickTrans end
	if left then left.Position = UDim2.new(0.5, -offset, 0.5, 0); left.BackgroundTransparency = tickTrans end
	if right then right.Position = UDim2.new(0.5, offset, 0.5, 0); right.BackgroundTransparency = tickTrans end
end

local function updateAmmoHUD(tool: Tool?, wid: string?): ()
	if not ammoCard then
		return
	end
	if not tool or not wid or isScoped then
		ammoCard.Visible = false
		if scopeTriggerBtn then
			scopeTriggerBtn.Visible = false
		end
		return
	end

	ammoCard.Visible = true
	local topInset = GuiService:GetGuiInset().Y
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local hudScale = if pg and typeof(pg:GetAttribute("FoodEmpireHUDScale")) == "number" then (pg:GetAttribute("FoodEmpireHUDScale") :: number) else 1
	local baseY = topInset + math.floor(156 * hudScale)
	local isSniperEquipped = isScopeRifle(wid)
	ammoCard.Position = UDim2.new(1, -14, 0, baseY + (if isSniperEquipped then 32 else 0))
	if scopeTriggerBtn then
		scopeTriggerBtn.Position = UDim2.new(1, -14, 0, baseY)
		scopeTriggerBtn.Visible = isSniperEquipped
	end
	local profile = getProfile(wid)
	local st = ensureLocalAmmo(wid, tool)
	local now = os.clock()

	if profile.IsMelee then
		if ammoWeaponLabel then ammoWeaponLabel.Text = profile.DisplayName end
		if ammoTypeBadge then ammoTypeBadge.Text = "MELEE BLADE" end
		if ammoMagLabel then ammoMagLabel.Text = "BLADE"; ammoMagLabel.TextColor3 = Color3.fromRGB(232, 230, 224) end
		if ammoMaxLabel then ammoMaxLabel.Text = "CLOSE QUARTERS" end
		if ammoReserveLabel then ammoReserveLabel.Text = "INF"; ammoReserveLabel.TextColor3 = Color3.fromRGB(178, 184, 196) end
		if shellPipHolder then shellPipHolder.Visible = false end
		if ammoBarBg then ammoBarBg.Visible = true end
		if ammoBarFill then ammoBarFill.Size = UDim2.fromScale(1, 1); ammoBarFill.BackgroundColor3 = profile.AccentColor end
		if reloadStatusLabel then reloadStatusLabel.Text = "[LMB] SLASH  |  BACKSTAB = 1.75x CRIT  |  [T] SMOKE" end
		return
	end

	if ammoWeaponLabel then
		ammoWeaponLabel.Text = profile.DisplayName
	end
	if ammoTypeBadge then
		ammoTypeBadge.Text = profile.AmmoType
		ammoTypeBadge.BackgroundColor3 = Color3.fromRGB(36, 40, 48)
		ammoTypeBadge.TextColor3 = Color3.fromRGB(214, 212, 206)
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
			ammoCardStroke.Color = Color3.fromRGB(178, 38, 46)
			ammoCardStroke.Thickness = 1.8
		elseif isReloading then
			ammoCardStroke.Color = Color3.fromRGB(168, 174, 184)
			ammoCardStroke.Thickness = 1.4
		elseif isEmpty then
			ammoCardStroke.Color = Color3.fromRGB(154, 34, 42)
			ammoCardStroke.Thickness = 1.5
		else
			ammoCardStroke.Color = Color3.fromRGB(48, 52, 62)
			ammoCardStroke.Thickness = 1.2
		end
	end

	-- Visual magazine bar vs individual shotgun shell pips
	local isShellStyle = (profile.ReloadStyle == "ShellByShell")
	if shellPipHolder and ammoBarBg then
		shellPipHolder.Visible = isShellStyle
		ammoBarBg.Visible = not isShellStyle
		if isShellStyle then
			local maxPips = math.clamp(st.MaxMag, 1, #shellPips)
			local pipW = math.floor((198 - (maxPips - 1) * 4) / maxPips)
			for i, pip in ipairs(shellPips) do
				pip.Visible = (i <= maxPips)
				pip.Size = UDim2.fromOffset(pipW, 8)
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
				reloadStatusLabel.Text = string.format("RELOADING  %d%%", math.floor(prog * 100))
			else
				if rs.Phase == "InsertShell" then
					prog = math.clamp((now - rs.PhaseStart) / math.max(0.1, rs.PhaseDuration), 0, 1)
					reloadStatusLabel.Text = if st.Mag >= 1
						then string.format("SHELL %d/%d  |  LMB FIRE", st.Mag, st.MaxMag)
						else string.format("LOADING SHELL %d/%d", st.Mag, st.MaxMag)
				elseif rs.Phase == "Exit" then
					prog = 1
					reloadStatusLabel.Text = "CHAMBERING"
				else
					prog = 0.12
					reloadStatusLabel.Text = "LOADING SHELLS"
				end
			end
			reloadBarFill.Size = UDim2.fromScale(prog, 1)
			reloadBarFill.BackgroundColor3 = Color3.fromRGB(148, 154, 166)
			reloadStatusLabel.TextColor3 = Color3.fromRGB(232, 230, 224)
		elseif isEmpty then
			reloadBarFill.Size = UDim2.fromScale(if isFlashingEmpty then 1 else 0, 1)
			reloadBarFill.BackgroundColor3 = Color3.fromRGB(154, 32, 40)
			if st.Reserve > 0 then
				reloadStatusLabel.Text = "EMPTY  |  PRESS [R] TO RELOAD"
				reloadStatusLabel.TextColor3 = Color3.fromRGB(224, 184, 128)
			else
				reloadStatusLabel.Text = "OUT OF AMMO  |  MARKET [M]"
				reloadStatusLabel.TextColor3 = Color3.fromRGB(216, 118, 124)
			end
		elseif isLow and st.Reserve > 0 then
			reloadBarFill.Size = UDim2.fromScale(0, 1)
			reloadStatusLabel.Text = "LOW AMMO  |  [R] RELOAD"
			reloadStatusLabel.TextColor3 = Color3.fromRGB(214, 188, 126)
		else
			reloadBarFill.Size = UDim2.fromScale(0, 1)
			local stanceHint = if adsBlend > 0.45
				then "AIMING  |  [LMB] FIRE  |  [R] RELOAD"
				elseif crouchBlend > 0.45 then "CROUCHED  |  [CTRL] STAND  |  [R] RELOAD"
				elseif sprintBlend > 0.45 then "SPRINT CARRY  |  [LMB] SNAP AIM"
				elseif wid == "ShadowSniper" then "[LMB] FIRE  |  [RMB/Q] SCOPE  |  [CTRL] CROUCH"
				else "[RMB] AIM  |  [CTRL] CROUCH  |  [R] RELOAD"
			reloadStatusLabel.Text = stanceHint
			reloadStatusLabel.TextColor3 = if adsBlend > 0.45 or crouchBlend > 0.45
				then Color3.fromRGB(204, 178, 118)
				else Color3.fromRGB(152, 158, 168)
		end
	end
end

local function startReload(): ()
	local tool, wid = getEquippedToolAndId()
	if not tool or not wid or not reloadEv then
		return
	end
	if isScoped then
		exitSniperScope()
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

	local mMultAttr = tool:GetAttribute("MasteryReloadMult")
	local mMult = if typeof(mMultAttr) == "number" then math.clamp(mMultAttr, 0.72, 1.0) else 1.0

	-- Melee Blade Swing Path (Knife & Samurai Katana: zero ammo cost, instant cleave + lunge!)
	if profile.IsMelee then
		if (now - lastClientFire) < (profile.Cooldown * mMult) then
			return
		end
		lastClientFire = now
		lastMeleeSlashAt = now
		meleeSlashSide = -meleeSlashSide
		aimFaceHoldUntil = now + 0.55
		sprintBlend = 0
		AudioController.PlayMeleeSwing(0.95)
		AudioController.NotifyCombatThreat(root.Position, "MeleeSwing")
		local hitPos = getCleanAimWorldPoint(char, root)
		fireEv:FireServer(wid, hitPos, 0)
		return
	end

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

	if (now - lastClientFire) < (profile.Cooldown * mMult) then
		return
	end
	lastClientFire = now

	-- 1. IMMEDIATE 0ms gunshot audio response! (Preloaded & pooled, zero server-RTT delay!)
	local hasSuppressor = tool:GetAttribute("Mod_Suppressor") == true
	AudioController.PlayWeaponFire(wid, if hasSuppressor then 0.65 else 1.0, hasSuppressor)
	if not hasSuppressor then
		AudioController.NotifyCombatThreat(root.Position, "Gunshot")
	end

	-- 2. Optimistic client magazine decrement (sequence-tracked for flicker-free server sync)
	st.Mag = math.max(0, st.Mag - 1)
	shotSeqCounter += 1
	local seq = shotSeqCounter
	lastSentSeqByWeapon[wid] = seq
	lastShotTimeByWeapon[wid] = now

	-- 3. Moderate, realistic weapon-specific 2-axis recoil impulse (tighter when ADS, Crouched, or with Heavy Barrel!)
	sprintBlend = 0
	local heavyBarrelMult = if tool:GetAttribute("Mod_HeavyBarrel") == true then 0.75 else 1.0
	local stabilityMult = (1 - 0.28 * adsBlend) * (1 - 0.30 * crouchBlend) * heavyBarrelMult
	recoilYawSign = -recoilYawSign
	recoilBack = math.min(profile.MaxBack, recoilBack + profile.KickBack * stabilityMult)
	recoilUp = math.min(0.22, recoilUp + profile.KickUp * stabilityMult)
	recoilPitch = math.min(profile.MaxPitchDeg, recoilPitch + profile.KickPitchDeg * stabilityMult)
	recoilYaw = math.clamp(recoilYaw + recoilYawSign * profile.KickYawDeg * stabilityMult * (0.6 + math.random() * 0.6), -4.5, 4.5)
	recoilSpreadPx = math.min(18, recoilSpreadPx + profile.CrosshairBloom * stabilityMult)
	aimFaceHoldUntil = now + 0.65

	-- 4. Immediate Muzzle Flash + Shell Ejection (Shotguns pump & eject red shell on backstroke!)
	playMuzzleFlash(tool, wid)
	if profile.ReloadStyle == "ShellByShell" then
		lastShotgunPumpStart = now
		local capturedTool = tool
		local capturedWid = wid
		task.delay(0.26, function()
			local curTool, curWid = getEquippedToolAndId()
			if curTool == capturedTool and curWid == capturedWid and not reloadState then
				AudioController.PlayShotgunPump()
				ejectShellCasing(capturedTool, capturedWid)
			end
		end)
	else
		ejectShellCasing(tool, wid)
	end

	-- 5. Fire authoritative shot to server using clean filtered aim target (exact crosshair center when scoped!)
	local hitPos = getCleanAimWorldPoint(char, root)
	if isScoped then
		scopeRecoilKick = math.min(18, scopeRecoilKick + 10)
		local cam = Workspace.CurrentCamera
		if cam then
			cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(1.15), math.rad((math.random() - 0.5) * 0.35), 0)
		end
	end
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
	elseif eventType == "NoReserve" then
		st.Reserve = 0
		emptyFlashUntil = now + 0.55
		AudioController.PlayDryFire()
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
	bb.PlayerToHideFrom = Players.LocalPlayer
	bb.Parent = head

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(15, 17, 21)
	bg.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 5)
	c.Parent = bg
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(54, 58, 68)
	st.Thickness = 1.2
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
			then string.format("%d HP  |  %d ARMOR", baseHp, armor)
			else string.format("%d / 100 HP", baseHp)
		fill.BackgroundColor3 = if armor > 0
			then Color3.fromRGB(68, 108, 148)
			elseif frac > 0.5 then Color3.fromRGB(72, 134, 92)
			elseif frac > 0.25 then Color3.fromRGB(168, 134, 62)
			else Color3.fromRGB(156, 36, 44)
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
					hpText.Text = string.format("%d / %d HP", math.max(0, math.ceil(hum.Health)), math.max(1, math.ceil(hum.MaxHealth)))
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
	local topInset = GuiService:GetGuiInset().Y
	local card = Instance.new("Frame")
	card.Name = "WeaponAmmoCard"
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, -14, 0, topInset + 176)
	card.Size = UDim2.fromOffset(216, 82)
	card.BackgroundColor3 = Color3.fromRGB(15, 17, 21)
	card.BackgroundTransparency = 0.05
	card.Visible = false
	card.Parent = parent
	ammoCard = card

	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 6)
	cc.Parent = card

	local cs = Instance.new("UIStroke")
	cs.Color = Color3.fromRGB(48, 52, 62)
	cs.Thickness = 1.2
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
	wLbl.Text = "STREET PISTOL"
	wLbl.TextSize = 10
	wLbl.TextColor3 = Color3.fromRGB(232, 230, 224)
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
	pipLayout.Padding = UDim.new(0, 4)
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

local function buildSniperScopeOverlay(parent: Instance): ()
	local overlay = Instance.new("Frame")
	overlay.Name = "ShadowSniperScopeOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.ClipsDescendants = true
	overlay.Visible = false
	overlay.ZIndex = 30
	overlay.Parent = parent
	scopeOverlay = overlay

	local maskColor = Color3.fromRGB(4, 5, 7)

	-- 4 Solid Matte-Black Outer Flanks surrounding the central circular lens box (zero edge leak on ultrawides!)
	local function makeOuterMask(name: string): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundColor3 = maskColor
		f.BorderSizePixel = 0
		f.ZIndex = 31
		f.Parent = overlay
		return f
	end
	scopeTopMask = makeOuterMask("TopMask")
	scopeBottomMask = makeOuterMask("BottomMask")
	scopeLeftMask = makeOuterMask("LeftMask")
	scopeRightMask = makeOuterMask("RightMask")

	-- Centered Square Clip Box containing the exact Circular Optical Aperture
	local lensBox = Instance.new("Frame")
	lensBox.Name = "LensBox"
	lensBox.AnchorPoint = Vector2.new(0.5, 0.5)
	lensBox.Position = UDim2.fromScale(0.5, 0.5)
	lensBox.Size = UDim2.fromOffset(640, 640)
	lensBox.BackgroundTransparency = 1
	lensBox.ClipsDescendants = true
	lensBox.ZIndex = 31
	lensBox.Parent = overlay
	scopeLensBox = lensBox

	-- True Anti-Aliased Circular Mask via Border UIStroke on a Circular Frame
	local lensCircle = Instance.new("Frame")
	lensCircle.Name = "CircularAperture"
	lensCircle.AnchorPoint = Vector2.new(0.5, 0.5)
	lensCircle.Position = UDim2.fromScale(0.5, 0.5)
	lensCircle.Size = UDim2.fromScale(1, 1)
	lensCircle.BackgroundTransparency = 1
	lensCircle.ZIndex = 32
	lensCircle.Parent = lensBox
	local lc = Instance.new("UICorner")
	lc.CornerRadius = UDim.new(0.5, 0)
	lc.Parent = lensCircle
	local maskStroke = Instance.new("UIStroke")
	maskStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	maskStroke.Color = maskColor
	maskStroke.Thickness = 220
	maskStroke.Parent = lensCircle
	scopeLensCircle = lensCircle
	scopeLensMaskStroke = maskStroke

	-- Subtle Machined Gunmetal Inner Optic Rim
	local rimRing = Instance.new("Frame")
	rimRing.Name = "OpticBezelRim"
	rimRing.AnchorPoint = Vector2.new(0.5, 0.5)
	rimRing.Position = UDim2.fromScale(0.5, 0.5)
	rimRing.Size = UDim2.new(1, -2, 1, -2)
	rimRing.BackgroundTransparency = 1
	rimRing.ZIndex = 33
	rimRing.Parent = lensBox
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0.5, 0)
	rc.Parent = rimRing
	local rimStroke = Instance.new("UIStroke")
	rimStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rimStroke.Color = Color3.fromRGB(36, 40, 48)
	rimStroke.Thickness = 2.5
	rimStroke.Parent = rimRing

	-- Precision Fine Mil-Dot Crosshair Lines inside the circular optic
	local hWire = Instance.new("Frame")
	hWire.Name = "CrosshairH"
	hWire.AnchorPoint = Vector2.new(0.5, 0.5)
	hWire.Position = UDim2.fromScale(0.5, 0.5)
	hWire.Size = UDim2.new(1, 0, 0, 1)
	hWire.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
	hWire.BackgroundTransparency = 0.15
	hWire.BorderSizePixel = 0
	hWire.ZIndex = 33
	hWire.Parent = lensBox

	local vWire = Instance.new("Frame")
	vWire.Name = "CrosshairV"
	vWire.AnchorPoint = Vector2.new(0.5, 0.5)
	vWire.Position = UDim2.fromScale(0.5, 0.5)
	vWire.Size = UDim2.new(0, 1, 1, 0)
	vWire.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
	vWire.BackgroundTransparency = 0.15
	vWire.BorderSizePixel = 0
	vWire.ZIndex = 33
	vWire.Parent = lensBox

	-- Thick outer stadia posts (real military scope look!)
	local stadiaSpecs = {
		{ Pos = UDim2.new(0.08, 0, 0.5, 0),  Size = UDim2.new(0.16, 0, 0, 3) },
		{ Pos = UDim2.new(0.92, 0, 0.5, 0),  Size = UDim2.new(0.16, 0, 0, 3) },
		{ Pos = UDim2.new(0.5, 0, 0.90, 0),  Size = UDim2.new(0, 3, 0.20, 0) },
	}
	for _, st in ipairs(stadiaSpecs) do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = st.Pos
		bar.Size = st.Size
		bar.BackgroundColor3 = Color3.fromRGB(10, 11, 14)
		bar.BorderSizePixel = 0
		bar.ZIndex = 33
		bar.Parent = lensBox
	end

	-- Subtle Mil-Hash Ticks on Horizontal & Vertical Wires
	for step = 1, 4 do
		local off = step * 0.065
		local tickLen = if step % 2 == 0 then 10 else 6
		for _, sign in ipairs({ -1, 1 }) do
			local ht = Instance.new("Frame")
			ht.AnchorPoint = Vector2.new(0.5, 0.5)
			ht.Position = UDim2.fromScale(0.5 + sign * off, 0.5)
			ht.Size = UDim2.fromOffset(1, tickLen)
			ht.BackgroundColor3 = Color3.fromRGB(14, 15, 18)
			ht.BorderSizePixel = 0
			ht.ZIndex = 33
			ht.Parent = lensBox

			local vt = Instance.new("Frame")
			vt.AnchorPoint = Vector2.new(0.5, 0.5)
			vt.Position = UDim2.fromScale(0.5, 0.5 + sign * off)
			vt.Size = UDim2.fromOffset(tickLen, 1)
			vt.BackgroundColor3 = Color3.fromRGB(14, 15, 18)
			vt.BorderSizePixel = 0
			vt.ZIndex = 33
			vt.Parent = lensBox
		end
	end

	-- Subtle Illuminated Deep-Red Center Precision Dot
	local centerDot = Instance.new("Frame")
	centerDot.Name = "PrecisionDot"
	centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
	centerDot.Position = UDim2.fromScale(0.5, 0.5)
	centerDot.Size = UDim2.fromOffset(4, 4)
	centerDot.BackgroundColor3 = Color3.fromRGB(184, 34, 42)
	centerDot.BorderSizePixel = 0
	centerDot.ZIndex = 34
	centerDot.Parent = lensBox
	local cdc = Instance.new("UICorner")
	cdc.CornerRadius = UDim.new(0.5, 0)
	cdc.Parent = centerDot

	-- Restrained Rangefinder, Zoom & Ammo Telemetry inside Lower Optic Arc
	local telemetryBar = Instance.new("Frame")
	telemetryBar.Name = "ScopeTelemetry"
	telemetryBar.AnchorPoint = Vector2.new(0.5, 1)
	telemetryBar.Position = UDim2.new(0.5, 0, 1, -18)
	telemetryBar.Size = UDim2.fromOffset(380, 26)
	telemetryBar.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
	telemetryBar.BackgroundTransparency = 0.25
	telemetryBar.ZIndex = 35
	telemetryBar.Parent = overlay
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 5)
	tc.Parent = telemetryBar
	local tst = Instance.new("UIStroke")
	tst.Color = Color3.fromRGB(48, 52, 60)
	tst.Thickness = 1
	tst.Parent = telemetryBar

	local function makeTelLabel(name: string, xScale: number, wScale: number, align: Enum.TextXAlignment, initTxt: string): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.Position = UDim2.fromScale(xScale, 0)
		l.Size = UDim2.fromScale(wScale, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Code
		l.Text = initTxt
		l.TextSize = 12
		l.TextXAlignment = align
		l.TextColor3 = Color3.fromRGB(214, 212, 204)
		l.ZIndex = 36
		l.Parent = telemetryBar
		return l
	end

	scopeZoomReadout = makeTelLabel("ZoomReadout", 0.03, 0.28, Enum.TextXAlignment.Left, "ZOOM  4.0x")
	scopeDistReadout = makeTelLabel("DistReadout", 0.34, 0.32, Enum.TextXAlignment.Center, "DIST  ---")
	scopeAmmoReadout = makeTelLabel("AmmoReadout", 0.67, 0.30, Enum.TextXAlignment.Right, "AMMO  5/5")

	-- Compact PC & Mobile Zoom Selector + Exit Bar (positioned cleanly at bottom-right outside lens center)
	local ctrlBar = Instance.new("Frame")
	ctrlBar.Name = "ScopeControlsBar"
	ctrlBar.AnchorPoint = Vector2.new(1, 1)
	ctrlBar.Position = UDim2.new(1, -20, 1, -18)
	ctrlBar.Size = UDim2.fromOffset(224, 34)
	ctrlBar.BackgroundTransparency = 1
	ctrlBar.ZIndex = 36
	ctrlBar.Parent = overlay
	local cl = Instance.new("UIListLayout")
	cl.FillDirection = Enum.FillDirection.Horizontal
	cl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	cl.Padding = UDim.new(0, 5)
	cl.Parent = ctrlBar

	table.clear(scopeZoomBtns)
	for i, z in ipairs(SNIPER_ZOOM_LEVELS) do
		local zb = Instance.new("TextButton")
		zb.Name = "ZoomBtn_" .. tostring(i)
		zb.LayoutOrder = i
		zb.Size = UDim2.fromOffset(44, 32)
		zb.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
		zb.Font = Enum.Font.GothamBold
		zb.Text = z.Label
		zb.TextSize = 11
		zb.TextColor3 = Color3.fromRGB(168, 172, 180)
		zb.ZIndex = 37
		zb.Parent = ctrlBar
		local zc = Instance.new("UICorner")
		zc.CornerRadius = UDim.new(0, 5)
		zc.Parent = zb
		local zs = Instance.new("UIStroke")
		zs.Color = Color3.fromRGB(54, 58, 66)
		zs.Thickness = 1
		zs.Parent = zb
		zb.MouseButton1Click:Connect(function()
			setSniperZoomIndex(i)
		end)
		table.insert(scopeZoomBtns, zb)
	end

	local exitBtn = Instance.new("TextButton")
	exitBtn.Name = "ExitScopeBtn"
	exitBtn.LayoutOrder = 9
	exitBtn.Size = UDim2.fromOffset(74, 32)
	exitBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
	exitBtn.Font = Enum.Font.GothamBlack
	exitBtn.Text = "EXIT [Q]"
	exitBtn.TextSize = 10
	exitBtn.TextColor3 = Color3.fromRGB(228, 226, 220)
	exitBtn.ZIndex = 37
	exitBtn.Parent = ctrlBar
	local ec = Instance.new("UICorner")
	ec.CornerRadius = UDim.new(0, 5)
	ec.Parent = exitBtn
	local es = Instance.new("UIStroke")
	es.Color = Color3.fromRGB(84, 88, 98)
	es.Thickness = 1
	es.Parent = exitBtn
	exitBtn.MouseButton1Click:Connect(exitSniperScope)

	-- Dedicated Mobile Touch Fire Button while Scoped (hidden on mouse-only desktop)
	if UserInputService.TouchEnabled then
		local fBtn = Instance.new("TextButton")
		fBtn.Name = "MobileScopeFireBtn"
		fBtn.AnchorPoint = Vector2.new(1, 0.5)
		fBtn.Position = UDim2.new(1, -26, 0.55, 0)
		fBtn.Size = UDim2.fromOffset(76, 76)
		fBtn.BackgroundColor3 = Color3.fromRGB(132, 26, 34)
		fBtn.Font = Enum.Font.GothamBlack
		fBtn.Text = "FIRE"
		fBtn.TextSize = 14
		fBtn.TextColor3 = Color3.fromRGB(244, 240, 232)
		fBtn.ZIndex = 37
		fBtn.Parent = overlay
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0.5, 0)
		fc.Parent = fBtn
		local fs = Instance.new("UIStroke")
		fs.Color = Color3.fromRGB(214, 210, 202)
		fs.Thickness = 1.5
		fs.Parent = fBtn
		fBtn.MouseButton1Click:Connect(function()
			tryShoot()
		end)
		scopeFireBtn = fBtn
	end

	-- Unobtrusive Scope Toggle Button (visible on PC & Mobile ONLY while holding Shadow Sniper unscoped)
	local topInset = GuiService:GetGuiInset().Y
	local trig = Instance.new("TextButton")
	trig.Name = "SniperScopeToggleBtn"
	trig.AnchorPoint = Vector2.new(1, 0)
	trig.Position = UDim2.new(1, -14, 0, topInset + 176)
	trig.Size = UDim2.fromOffset(216, 26)
	trig.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	trig.Font = Enum.Font.GothamBlack
	trig.Text = if UserInputService.TouchEnabled then "ACTIVATE SCOPE" else "SCOPE  [RMB / Q]"
	trig.TextSize = 11
	trig.TextColor3 = Color3.fromRGB(228, 224, 216)
	trig.Visible = false
	trig.ZIndex = 12
	trig.Parent = parent
	local trc = Instance.new("UICorner")
	trc.CornerRadius = UDim.new(0, 5)
	trc.Parent = trig
	local trs = Instance.new("UIStroke")
	trs.Color = Color3.fromRGB(134, 28, 36)
	trs.Thickness = 1.2
	trs.Parent = trig
	trig.MouseButton1Click:Connect(toggleSniperScope)
	scopeTriggerBtn = trig
end

local function updateSniperScopeFrame(dt: number, tool: Tool?, wid: string?): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local clampedDt = math.min(dt, 0.05)
	local char = Players.LocalPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local holdingGun = (tool ~= nil) and (wid ~= nil) and (hum ~= nil) and (hum.Health > 0) and (not hum.Sit)

	-- Smooth Over-the-Shoulder Third-Person Shooter Camera Framing + Dynamic FOV (Hip / ADS / Sprint / Sniper Scope!)
	gunCameraBlend += ((if holdingGun and not isScoped then 1 else 0) - gunCameraBlend) * (1 - math.exp(-10 * clampedDt))
	if gunCameraBlend < 0.004 then gunCameraBlend = 0 end

	if hum then
		if gunCameraBlend > 0.004 then
			local cs = activeCharScale
			local hipOffset = Vector3.new(1.50 * cs, 0.28 * cs, 0)
			local adsOffset = Vector3.new(1.68 * cs, 0.28 * cs, -1.55 * cs)
			local sprintBobY = math.sin(locomotionDist * 0.62) * 0.06 * sprintBlend
			local sprintOffset = Vector3.new(1.15 * cs, 0.20 * cs + sprintBobY, 0.45 * cs)
			local targetOff = hipOffset:Lerp(adsOffset, adsBlend):Lerp(sprintOffset, sprintBlend)
				+ Vector3.new(0, -1.10 * cs * crouchBlend, 0)
			local desiredCamOff = Vector3.zero:Lerp(targetOff, gunCameraBlend)
			hum.CameraOffset = hum.CameraOffset:Lerp(desiredCamOff, 1 - math.exp(-14 * clampedDt))
		elseif hum.CameraOffset.Magnitude > 0.005 then
			hum.CameraOffset = hum.CameraOffset:Lerp(Vector3.zero, 1 - math.exp(-12 * clampedDt))
			if hum.CameraOffset.Magnitude <= 0.005 then
				hum.CameraOffset = Vector3.zero
			end
		end
	end

	-- Unified Smooth FOV Interpolation (Shadow Sniper Scope -> Tactical ADS -> Tactical Sprint -> Default 70)
	local targetFOV = DEFAULT_CAMERA_FOV
	if isScoped then
		local zSpec = SNIPER_ZOOM_LEVELS[scopeZoomIndex] or SNIPER_ZOOM_LEVELS[2]
		targetFOV = zSpec.FOV
	elseif holdingGun then
		targetFOV = DEFAULT_CAMERA_FOV - 15 * adsBlend + 5 * sprintBlend
		UserInputService.MouseDeltaSensitivity = 1.0 - 0.26 * adsBlend
	elseif UserInputService.MouseDeltaSensitivity ~= 1.0 then
		UserInputService.MouseDeltaSensitivity = 1.0
	end
	local fovAlpha = 1 - math.exp(-14 * clampedDt)
	if math.abs(camera.FieldOfView - targetFOV) > 0.05 then
		camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * fovAlpha
	else
		camera.FieldOfView = targetFOV
	end

	if not isScoped then
		return
	end

	-- Safety exit if player died or swapped away from ShadowSniper
	local char = Players.LocalPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not tool or wid ~= "ShadowSniper" or not char or not root or not root:IsA("BasePart") or not hum or hum.Health <= 0 then
		exitSniperScope()
		return
	end

	setLocalCharacterHiddenForScope(true)

	-- Dynamic responsive circular aperture + flanking outer matte bars
	local vp = camera.ViewportSize
	local lensDiam = math.max(220, math.floor(math.min(vp.X, vp.Y) * 0.84))
	scopeRecoilKick *= math.exp(-12 * math.min(dt, 0.05))
	local kickPx = math.floor(scopeRecoilKick + 0.5)

	if scopeLensBox and scopeLensMaskStroke then
		scopeLensBox.Size = UDim2.fromOffset(lensDiam, lensDiam)
		scopeLensBox.Position = UDim2.new(0.5, 0, 0.5, -kickPx)
		scopeLensMaskStroke.Thickness = math.ceil(lensDiam * 0.30)
	end

	local halfL = lensDiam * 0.5
	local cx = vp.X * 0.5
	local cy = vp.Y * 0.5 - kickPx
	if scopeTopMask then
		scopeTopMask.Position = UDim2.fromOffset(0, 0)
		scopeTopMask.Size = UDim2.fromOffset(vp.X, math.max(0, math.ceil(cy - halfL) + 2))
	end
	if scopeBottomMask then
		local botY = math.floor(cy + halfL) - 1
		scopeBottomMask.Position = UDim2.fromOffset(0, botY)
		scopeBottomMask.Size = UDim2.fromOffset(vp.X, math.max(0, vp.Y - botY + 4))
	end
	if scopeLeftMask then
		scopeLeftMask.Position = UDim2.fromOffset(0, math.floor(cy - halfL) - 2)
		scopeLeftMask.Size = UDim2.fromOffset(math.max(0, math.ceil(cx - halfL) + 2), lensDiam + 4)
	end
	if scopeRightMask then
		local rightX = math.floor(cx + halfL) - 1
		scopeRightMask.Position = UDim2.fromOffset(rightX, math.floor(cy - halfL) - 2)
		scopeRightMask.Size = UDim2.fromOffset(math.max(0, vp.X - rightX + 4), lensDiam + 4)
	end

	-- Update Live Laser Rangefinder Distance, Zoom & Ammo Readouts
	local zSpec = SNIPER_ZOOM_LEVELS[scopeZoomIndex] or SNIPER_ZOOM_LEVELS[2]
	if scopeZoomReadout then
		scopeZoomReadout.Text = "ZOOM  " .. zSpec.Label
	end
	local _, hitDist = getCleanAimWorldPoint(char, root)
	if scopeDistReadout then
		if hitDist and hitDist <= 460 then
			scopeDistReadout.Text = string.format("DIST  %dm", math.floor(hitDist + 0.5))
		else
			scopeDistReadout.Text = "DIST  ---"
		end
	end
	if scopeAmmoReadout then
		local st = ensureLocalAmmo(wid, tool)
		scopeAmmoReadout.Text = string.format("AMMO  %d/%d  (%d)", st.Mag, st.MaxMag, st.Reserve)
	end
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

	local topInset = GuiService:GetGuiInset().Y

	-- Player HP & Armor bars are now rendered cleanly in the Bottom-Center Dual Vitals Dock inside HUDController!
	hpPillFrame = nil
	playerHpFill = nil
	playerHpLabel = nil
	armorPillFrame = nil
	playerArmorFill = nil
	playerArmorLabel = nil

	-- 3. Weapon Ammo & Reload HUD
	buildWeaponAmmoCard(gui)

	-- 4. Compact Dynamic "+" Target Crosshair
	reticleFrame = buildCompactPlusCrosshair(gui)

	-- 5. Shadow Sniper Functional Scope Overlay & Controls
	buildSniperScopeOverlay(gui)

	-- 6. Minimalist Hitmarker Cross (Body White / Headshot & Kill Crimson) + Top-Right Syndicate Kill Feed
	local hm = Instance.new("Frame")
	hm.Name = "CombatHitmarker"
	hm.AnchorPoint = Vector2.new(0.5, 0.5)
	hm.Position = UDim2.fromScale(0.5, 0.5)
	hm.Size = UDim2.fromOffset(26, 26)
	hm.BackgroundTransparency = 1
	hm.Visible = false
	hm.ZIndex = 45
	hm.Parent = gui
	hitmarkerFrame = hm

	local hmOffsets = {
		{ Pos = UDim2.new(0.5, -6, 0.5, -6), Rot = 45 },
		{ Pos = UDim2.new(0.5, 6, 0.5, -6), Rot = -45 },
		{ Pos = UDim2.new(0.5, -6, 0.5, 6), Rot = -45 },
		{ Pos = UDim2.new(0.5, 6, 0.5, 6), Rot = 45 },
	}
	for i, cfg in ipairs(hmOffsets) do
		local t = Instance.new("Frame")
		t.Name = "Tick" .. tostring(i)
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = cfg.Pos
		t.Size = UDim2.fromOffset(8, 2)
		t.Rotation = cfg.Rot
		t.BackgroundColor3 = Color3.fromRGB(238, 236, 232)
		t.BorderSizePixel = 0
		t.ZIndex = 45
		t.Parent = hm
	end

	local kf = Instance.new("Frame")
	kf.Name = "SyndicateKillFeed"
	kf.AnchorPoint = Vector2.new(1, 0)
	kf.Position = UDim2.new(1, -242, 0, topInset + 14)
	kf.Size = UDim2.fromOffset(290, 140)
	kf.BackgroundTransparency = 1
	kf.ZIndex = 20
	kf.Parent = gui
	local kfl = Instance.new("UIListLayout")
	kfl.Padding = UDim.new(0, 4)
	kfl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	kfl.Parent = kf
	killFeedHolder = kf
end

local function showFloatingDamageNumber(worldPos: Vector3, dmg: number, isHeadshot: boolean): ()
	local cam = Workspace.CurrentCamera
	if not cam or not aimGui then return end
	local screenPos, onScreen = cam:WorldToViewportPoint(worldPos + Vector3.new(0, 1.4, 0))
	if not onScreen then return end
	local lbl = Instance.new("TextLabel")
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Position = UDim2.fromOffset(screenPos.X + math.random(-14, 14), screenPos.Y)
	lbl.Size = UDim2.fromOffset(100, 22)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = if isHeadshot then string.format("CRIT -%d", dmg) else string.format("-%d", dmg)
	lbl.TextSize = if isHeadshot then 15 else 12
	lbl.TextColor3 = if isHeadshot then Color3.fromRGB(218, 56, 62) else Color3.fromRGB(234, 232, 226)
	lbl.TextStrokeTransparency = 0.25
	lbl.TextStrokeColor3 = Color3.fromRGB(10, 11, 14)
	lbl.ZIndex = 44
	lbl.Parent = aimGui
	task.spawn(function()
		for i = 1, 14 do
			if not lbl.Parent then return end
			lbl.Position = lbl.Position + UDim2.fromOffset(0, -2)
			lbl.TextTransparency = i / 14
			lbl.TextStrokeTransparency = 0.25 + (i / 14) * 0.75
			task.wait(0.03)
		end
		if lbl.Parent then lbl:Destroy() end
	end)
end

local function pushKillFeedRow(killer: string, victim: string, weapon: string, isHeadshot: boolean): ()
	if not killFeedHolder then return end
	local existing = killFeedHolder:GetChildren()
	local rowCount = 0
	for _, ch in ipairs(existing) do
		if ch:IsA("TextLabel") then rowCount += 1 end
	end
	if rowCount >= 4 then
		for _, ch in ipairs(existing) do
			if ch:IsA("TextLabel") then ch:Destroy(); break end
		end
	end
	local row = Instance.new("TextLabel")
	row.Size = UDim2.fromOffset(286, 22)
	row.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
	row.BackgroundTransparency = 0.14
	row.Font = Enum.Font.GothamBold
	row.TextSize = 10
	row.TextColor3 = if isHeadshot then Color3.fromRGB(224, 184, 114) else Color3.fromRGB(222, 220, 214)
	row.Text = string.format(" %s  [%s%s]  %s ", killer, string.upper(weapon), if isHeadshot then " HS" else "", victim)
	row.TextXAlignment = Enum.TextXAlignment.Right
	row.ZIndex = 20
	row.Parent = killFeedHolder
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
	local st = Instance.new("UIStroke")
	st.Color = if isHeadshot then Color3.fromRGB(156, 36, 44) else Color3.fromRGB(52, 56, 66)
	st.Thickness = 1
	st.Parent = row
	task.delay(5.5, function()
		if row.Parent then row:Destroy() end
	end)
end

function WeaponController.ExitScope(): ()
	exitSniperScope()
end

function WeaponController.Start(onOpenBlackMarket: () -> ()): ()
	AudioController.Preload()
	buildAimUI()

	-- Hook local player damage to play realistic pain/hurt vocal scream & alert nearby civilians!
	local function bindPlayerHurtAudio(char: Model): ()
		local hum = char:WaitForChild("Humanoid", 8)
		if not hum or not hum:IsA("Humanoid") then return end
		local prevHp = hum.Health
		hum.HealthChanged:Connect(function(newHp: number)
			if newHp < prevHp - 1.5 and newHp > 0 then
				AudioController.PlayPlayerHurtScream(1.0)
				local r = char:FindFirstChild("HumanoidRootPart")
				if r and r:IsA("BasePart") then
					AudioController.NotifyCombatThreat(r.Position, "PlayerHit")
				end
			elseif newHp <= 0 and prevHp > 0 then
				AudioController.PlayEnemyDeathScream(0.95)
			end
			prevHp = newHp
		end)
	end
	if Players.LocalPlayer.Character then
		task.spawn(bindPlayerHurtAudio, Players.LocalPlayer.Character)
	end
	Players.LocalPlayer.CharacterAdded:Connect(bindPlayerHurtAudio)

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
					if kind ~= "ShotgunPump" and kind ~= "BodyDrop" then
						AudioController.NotifyCombatThreat(origin, kind)
					end
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

		local fbEv = remotes:WaitForChild("CombatFeedback", 15)
		if fbEv and fbEv:IsA("RemoteEvent") then
			fbEv.OnClientEvent:Connect(function(payload: any)
				if typeof(payload) ~= "table" then return end
				if payload.Kind == "Hit" then
					local isHS = payload.IsHeadshot == true
					local isKill = payload.IsKill == true
					if hitmarkerFrame then
						local col = if isHS or isKill then Color3.fromRGB(214, 46, 54) else Color3.fromRGB(238, 236, 232)
						for _, ch in ipairs(hitmarkerFrame:GetChildren()) do
							if ch:IsA("Frame") then ch.BackgroundColor3 = col end
						end
						local mp = UserInputService:GetMouseLocation()
						hitmarkerFrame.Position = if isScoped then UDim2.fromScale(0.5, 0.5) else UDim2.fromOffset(mp.X, mp.Y)
						hitmarkerFrame.Visible = true
						hitmarkerHideAt = os.clock() + (if isHS or isKill then 0.22 else 0.14)
					end
					if isHS then
						AudioController.PlayCoins()
					end
					if typeof(payload.HitPos) == "Vector3" and typeof(payload.Damage) == "number" then
						showFloatingDamageNumber(payload.HitPos, payload.Damage, isHS)
					end
				elseif payload.Kind == "KillFeed" then
					pushKillFeedRow(
						tostring(payload.Killer or "Player"),
						tostring(payload.Victim or "Hostile"),
						tostring(payload.Weapon or "Weapon"),
						payload.IsHeadshot == true
					)
				end
			end)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isMouseDown = true
			tryShoot()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			local _, wid = getEquippedToolAndId()
			if isScopeRifle(wid) or isScoped then
				toggleSniperScope()
			elseif wid ~= nil then
				isAimingADS = true
			end
		elseif input.KeyCode == Enum.KeyCode.Q then
			local _, wid = getEquippedToolAndId()
			if isScopeRifle(wid) or isScoped then
				toggleSniperScope()
			end
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			isShiftHeld = true
			isCrouching = false
		elseif input.KeyCode == Enum.KeyCode.LeftControl then
			local _, wid = getEquippedToolAndId()
			if wid ~= nil and not isScoped then
				isCrouching = not isCrouching
			end
		elseif input.KeyCode == Enum.KeyCode.Z then
			if isScoped then
				local nextIdx = (scopeZoomIndex % #SNIPER_ZOOM_LEVELS) + 1
				setSniperZoomIndex(nextIdx)
			end
		elseif input.KeyCode == Enum.KeyCode.Escape then
			if isScoped then
				exitSniperScope()
			end
		elseif input.KeyCode == Enum.KeyCode.R then
			startReload()
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject, gp: boolean)
		if gp or not isScoped then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			if input.Position.Z > 0 then
				setSniperZoomIndex(scopeZoomIndex + 1)
			elseif input.Position.Z < 0 then
				setSniperZoomIndex(scopeZoomIndex - 1)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isMouseDown = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			isAimingADS = false
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			isShiftHeld = false
		end
	end)

	-- Split-Body Procedural Locomotion runs on Stepped (post-Animator, pre-render) for smooth strafing, leaning & crouch!
	RunService.Stepped:Connect(function()
		applyProceduralShooterLocomotion()
	end)

	local lastSyncedTopInset = -1

	RunService.RenderStepped:Connect(function(dt: number)
		local topInset = GuiService:GetGuiInset().Y
		if topInset ~= lastSyncedTopInset then
			lastSyncedTopInset = topInset
			local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
			local hudScale = if pg and typeof(pg:GetAttribute("FoodEmpireHUDScale")) == "number" then (pg:GetAttribute("FoodEmpireHUDScale") :: number) else 1
			local baseY = topInset + math.floor(156 * hudScale)
			if scopeTriggerBtn then
				scopeTriggerBtn.Position = UDim2.new(1, -14, 0, baseY)
			end
			if ammoCard then
				local _, curWid = getEquippedToolAndId()
				ammoCard.Position = UDim2.new(1, -14, 0, baseY + (if curWid == "ShadowSniper" then 32 else 0))
			end
		end

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
				playerHpLabel.Text = string.format("HEALTH  %d / 100", baseHp)
				playerHpFill.BackgroundColor3 = if frac > 0.5
					then Color3.fromRGB(68, 128, 86)
					elseif frac > 0.25 then Color3.fromRGB(168, 134, 62)
					else Color3.fromRGB(156, 36, 44)

				if playerArmorFill and playerArmorLabel then
					playerArmorFill.Size = UDim2.fromScale(math.clamp(armor / 100, 0, 1), 1)
					playerArmorLabel.Text = if armor > 0
						then string.format("ARMOR  %d / 100", armor)
						else "ARMOR  0 / 100  (MARKET)"
				end
			end
		end

		if hitmarkerFrame and hitmarkerFrame.Visible and os.clock() > hitmarkerHideAt then
			hitmarkerFrame.Visible = false
		end

		for _, m in ipairs(CollectionService:GetTagged("MafiaUnit")) do
			if m:IsA("Model") then ensureEnemyOverheadHPText(m) end
		end
		for _, m in ipairs(CollectionService:GetTagged("RivalAIUnit")) do
			if m:IsA("Model") then ensureEnemyOverheadHPText(m) end
		end

		local tool, wid = getEquippedToolAndId()

		-- Detect weapon switch / unequip and cleanly reset aim/reload/scope state
		if tool ~= lastEquippedTool or wid ~= lastEquippedWid then
			if isScoped and not isScopeRifle(wid) then
				exitSniperScope()
			end
			if wid == nil then
				isAimingADS = false
				isCrouching = false
				adsBlend = 0
				sprintBlend = 0
				crouchBlend = 0
			end
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

		-- Update Shadow Sniper Scope camera zoom, circular mask & live rangefinder
		updateSniperScopeFrame(dt, tool, wid)

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
		if not tool or not wid or isScoped then
			if reticleFrame.Visible then
				reticleFrame.Visible = false
				if not isScoped then
					UserInputService.MouseIconEnabled = true
				end
			end
			if isScoped then
				UserInputService.MouseIconEnabled = false
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

		local activeProf = getProfile(wid)
		if isMouseDown and activeProf.AutoFire then
			tryShoot()
		end
	end)
end

return WeaponController
