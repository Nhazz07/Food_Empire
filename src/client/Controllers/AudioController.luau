--!strict

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local AudioController = {}

local PING_URL = "rbxasset://sounds/electronicpingshort.wav"
local CLICK_URL = "rbxasset://sounds/button.wav"
local SWING_URL = "rbxasset://sounds/action_jump.mp3"
local HIT_URL = "rbxasset://sounds/hit.wav"
local SNAP_URL = "rbxasset://sounds/snap.wav"
local EXPLOSION_URL = "rbxasset://sounds/impact_explosion_03.mp3"

-- Verified Creator Store realistic gunshots, reload & punch fighting SFX
local PISTOL_SFX_URL = "rbxassetid://127604219525464"
local SHOTGUN_SFX_URL = "rbxassetid://3102797479"
local SMG_SFX_URL = "rbxassetid://92011177452282"
local PUNCH_SFX_URL = "rbxassetid://87384287237291"
local RELOAD_MAG_URL = "rbxassetid://117963160131194"
local SHOTGUN_SHELL_URL = "rbxassetid://113268851418553"
local SHOTGUN_PUMP_URL = "rbxassetid://139827026287805"

type PoolSpec = {
	SoundId: string,
	PoolSize: number,
	BaseVolume: number,
	BaseSpeed: number,
	StartOffset: number,
	PitchJitter: number,
	Distort: number?,
}

type PoolEntry = {
	Sounds: { Sound },
	Cursor: number,
	BaseVolume: number,
	BaseSpeed: number,
	StartOffset: number,
	PitchJitter: number,
}

local POOL_SPECS: { [string]: PoolSpec } = {
	PistolShot = {
		SoundId = PISTOL_SFX_URL,
		PoolSize = 4,
		BaseVolume = 0.78,
		BaseSpeed = 1.05,
		StartOffset = 0,
		PitchJitter = 0.03,
	},
	ShotgunBlast = {
		SoundId = SHOTGUN_SFX_URL,
		PoolSize = 3,
		BaseVolume = 0.88,
		BaseSpeed = 0.90,
		StartOffset = 0,
		PitchJitter = 0.025,
	},
	ShotgunBoomTail = {
		SoundId = EXPLOSION_URL,
		PoolSize = 3,
		BaseVolume = 0.30,
		BaseSpeed = 1.72,
		StartOffset = 0,
		PitchJitter = 0.03,
	},
	SMGShot = {
		SoundId = SMG_SFX_URL,
		PoolSize = 6,
		BaseVolume = 0.65,
		BaseSpeed = 1.22,
		StartOffset = 0,
		PitchJitter = 0.035,
	},
	ReloadMag = {
		SoundId = RELOAD_MAG_URL,
		PoolSize = 2,
		BaseVolume = 0.86,
		BaseSpeed = 1.0,
		StartOffset = 0,
		PitchJitter = 0.02,
	},
	ShotgunShell = {
		SoundId = SHOTGUN_SHELL_URL,
		PoolSize = 3,
		BaseVolume = 0.88,
		BaseSpeed = 1.04,
		StartOffset = 0,
		PitchJitter = 0.04,
	},
	ShotgunPump = {
		SoundId = SHOTGUN_PUMP_URL,
		PoolSize = 2,
		BaseVolume = 0.85,
		BaseSpeed = 1.05,
		StartOffset = 0.08,
		PitchJitter = 0.02,
	},
	DryFireClick = {
		SoundId = CLICK_URL,
		PoolSize = 2,
		BaseVolume = 0.45,
		BaseSpeed = 1.85,
		StartOffset = 0,
		PitchJitter = 0.03,
	},
	DryFireSnap = {
		SoundId = SNAP_URL,
		PoolSize = 2,
		BaseVolume = 0.30,
		BaseSpeed = 1.60,
		StartOffset = 0,
		PitchJitter = 0.03,
	},
	MeleeSwing = {
		SoundId = SWING_URL,
		PoolSize = 3,
		BaseVolume = 0.42,
		BaseSpeed = 1.55,
		StartOffset = 0,
		PitchJitter = 0.04,
	},
	MeleeSnap = {
		SoundId = SNAP_URL,
		PoolSize = 3,
		BaseVolume = 0.25,
		BaseSpeed = 1.30,
		StartOffset = 0,
		PitchJitter = 0.04,
	},
	MeleePunch = {
		SoundId = PUNCH_SFX_URL,
		PoolSize = 4,
		BaseVolume = 0.72,
		BaseSpeed = 1.05,
		StartOffset = 0,
		PitchJitter = 0.04,
	},
	MeleeHitTail = {
		SoundId = HIT_URL,
		PoolSize = 4,
		BaseVolume = 0.42,
		BaseSpeed = 1.15,
		StartOffset = 0,
		PitchJitter = 0.04,
		Distort = 0.2,
	},
}

local audioPoolFolder: Folder? = nil
local pools: { [string]: PoolEntry } = {}
local isPreloaded = false

local function ensurePoolInitialized(): ()
	if audioPoolFolder and audioPoolFolder.Parent then
		return
	end

	local existing = SoundService:FindFirstChild("FoodEmpireAudioPool")
	if existing and existing:IsA("Folder") then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "FoodEmpireAudioPool"
	folder.Parent = SoundService
	audioPoolFolder = folder

	local preloadList: { Instance } = {}
	table.clear(pools)

	for key, spec in pairs(POOL_SPECS) do
		local sounds: { Sound } = {}
		for i = 1, spec.PoolSize do
			local s = Instance.new("Sound")
			s.Name = key .. "_" .. tostring(i)
			s.SoundId = spec.SoundId
			s.Volume = spec.BaseVolume
			s.PlaybackSpeed = spec.BaseSpeed
			if spec.Distort and spec.Distort > 0 then
				local d = Instance.new("DistortionSoundEffect")
				d.Level = spec.Distort
				d.Parent = s
			end
			s.Parent = folder
			table.insert(sounds, s)
			if i == 1 then
				table.insert(preloadList, s)
			end
		end
		pools[key] = {
			Sounds = sounds,
			Cursor = 1,
			BaseVolume = spec.BaseVolume,
			BaseSpeed = spec.BaseSpeed,
			StartOffset = spec.StartOffset,
			PitchJitter = spec.PitchJitter,
		}
	end

	if not isPreloaded then
		isPreloaded = true
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(preloadList)
			end)
		end)
	end
end

local function playPooled(key: string, volScale: number?, speedScale: number?): ()
	ensurePoolInitialized()
	local entry = pools[key]
	if not entry or #entry.Sounds == 0 then
		return
	end
	local s = entry.Sounds[entry.Cursor]
	entry.Cursor = (entry.Cursor % #entry.Sounds) + 1

	local v = volScale or 1
	local sp = speedScale or 1
	local jitter = if entry.PitchJitter > 0 then (1 + (math.random() * 2 - 1) * entry.PitchJitter) else 1

	if s.IsPlaying then
		s:Stop()
	end
	s.Volume = entry.BaseVolume * v
	s.PlaybackSpeed = entry.BaseSpeed * sp * jitter
	s.TimePosition = entry.StartOffset
	s:Play()
end

local function playTone(soundId: string, volume: number, speed: number, delaySec: number?, distort: number?): ()
	local function fire()
		local s = Instance.new("Sound")
		s.SoundId = soundId
		s.Volume = volume
		s.PlaybackSpeed = speed
		if distort and distort > 0 then
			local d = Instance.new("DistortionSoundEffect")
			d.Level = distort
			d.Parent = s
		end
		s.Parent = SoundService
		s:Play()
		s.Ended:Connect(function()
			s:Destroy()
		end)
		task.delay(2.5, function()
			if s.Parent then
				s:Destroy()
			end
		end)
	end

	if delaySec and delaySec > 0 then
		task.delay(delaySec, fire)
	else
		fire()
	end
end

function AudioController.Preload(): ()
	ensurePoolInitialized()
end

function AudioController.PlayClick(): ()
	playTone(CLICK_URL, 0.35, 1.18, 0)
end

function AudioController.PlayCook(): ()
	playTone(PING_URL, 0.32, 1.0, 0)
	playTone(PING_URL, 0.28, 1.25, 0.08)
end

function AudioController.PlayCoins(): ()
	-- Bright ascending coin chime
	playTone(PING_URL, 0.42, 1.35, 0)
	playTone(PING_URL, 0.45, 1.68, 0.09)
end

function AudioController.PlayFanfare(): ()
	-- Cheerful 4-note major chord arpeggio for milestones, VIP orders & Robux Pro Chef unlocks
	playTone(PING_URL, 0.40, 1.00, 0.00)
	playTone(PING_URL, 0.42, 1.26, 0.09)
	playTone(PING_URL, 0.45, 1.50, 0.18)
	playTone(PING_URL, 0.50, 2.00, 0.28)
end

function AudioController.PlayError(): ()
	playTone(CLICK_URL, 0.38, 0.65, 0)
	playTone(CLICK_URL, 0.35, 0.55, 0.09)
end

-- Crisp Melee Fighting Swing & Punch Impact Sound Effects (preloaded & pooled)
function AudioController.PlayMeleeSwing(volScale: number?): ()
	local v = volScale or 1
	playPooled("MeleeSwing", v, 1)
	task.delay(0.02, function()
		playPooled("MeleeSnap", v, 1)
	end)
end

function AudioController.PlayMeleeHit(volScale: number?): ()
	local v = volScale or 1
	playPooled("MeleePunch", v, 1)
	playPooled("MeleeHitTail", v, 1)
end

-- Immediate Zero-Latency Preloaded & Pooled Gunshot Sound Effects
function AudioController.PlayPistolShot(volScale: number?): ()
	playPooled("PistolShot", volScale or 1, 1)
end

function AudioController.PlayShotgunBlast(volScale: number?): ()
	local v = volScale or 1
	playPooled("ShotgunBlast", v, 1)
	playPooled("ShotgunBoomTail", v, 1)
end

function AudioController.PlaySMGShot(volScale: number?): ()
	playPooled("SMGShot", volScale or 1, 1)
end

function AudioController.PlayWeaponFire(weaponId: string, volScale: number?): ()
	if weaponId == "PepperShotgun" then
		AudioController.PlayShotgunBlast(volScale)
	elseif weaponId == "TacticalSMG" then
		AudioController.PlaySMGShot(volScale)
	else
		AudioController.PlayPistolShot(volScale)
	end
end

-- Reload, Shell Insert, Pump Action & Dry-Fire SFX
function AudioController.PlayDryFire(): ()
	playPooled("DryFireClick", 1, 1)
	playPooled("DryFireSnap", 0.85, 1.05)
end

function AudioController.PlayMagReload(weaponId: string): ()
	local speed = if weaponId == "TacticalSMG" then 0.84 else 1.04
	playPooled("ReloadMag", 1, speed)
end

function AudioController.PlayMagLatch(): ()
	playPooled("DryFireSnap", 0.95, 1.15)
end

function AudioController.PlayShotgunShellInsert(): ()
	playPooled("ShotgunShell", 1, 1)
end

function AudioController.PlayShotgunPump(): ()
	playPooled("ShotgunPump", 1, 1)
end

function AudioController.PlayCombatSFX(kind: string, volScale: number?): ()
	if kind == "PistolShot" or kind == "EnemyShot" then
		AudioController.PlayPistolShot(volScale)
	elseif kind == "ShotgunBlast" then
		AudioController.PlayShotgunBlast(volScale)
	elseif kind == "SMGShot" then
		AudioController.PlaySMGShot(volScale)
	elseif kind == "MeleeHit" then
		AudioController.PlayMeleeHit(volScale)
	elseif kind == "MeleeSwing" then
		AudioController.PlayMeleeSwing(volScale)
	elseif kind == "ShotgunPump" then
		AudioController.PlayShotgunPump()
	end
end

-- Warm up & preload all combat & weapon audio pools immediately on module load
ensurePoolInitialized()

return AudioController
