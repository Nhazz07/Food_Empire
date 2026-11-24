--!strict

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WeaponConfig")
)

local AudioController = {}

local PING_URL = "rbxasset://sounds/electronicpingshort.wav"
local CLICK_URL = "rbxasset://sounds/button.wav"
local SWING_URL = "rbxasset://sounds/action_jump.mp3"
local HIT_URL = "rbxasset://sounds/hit.wav"
local SNAP_URL = "rbxasset://sounds/snap.wav"
local EXPLOSION_URL = "rbxasset://sounds/impact_explosion_03.mp3"

-- Upgraded Verified Creator Store Realistic Firearms Audio (distinct per weapon class!)
local PISTOL_SFX_URL = "rbxassetid://17599184153"      -- P226 9mm Outdoor crisp handgun report
local SUPPRESSED_SFX_URL = "rbxassetid://800000918"    -- PB Suppressed tactical muffled report
local RIFLE_SFX_URL = "rbxassetid://77193661877789"    -- AK-74 urban outdoor rifle crack with reverb
local SMG_SFX_URL = "rbxassetid://102442472539680"     -- 9A-91 rapid automatic tactical burst
local SHOTGUN_SFX_URL = "rbxassetid://133201577670746" -- Remington 870 heavy shotgun blast
local SNIPER_SFX_URL = "rbxassetid://5682471970"       -- High-caliber sniper rifle thunder

-- Melee, Reload & Shell Mechanics
local PUNCH_SFX_URL = "rbxassetid://87384287237291"
local RELOAD_MAG_URL = "rbxassetid://117963160131194"
local SHOTGUN_SHELL_URL = "rbxassetid://113268851418553"
local SHOTGUN_PUMP_URL = "rbxassetid://139827026287805"

-- Official ProSoundEffects + Verified Combat Hit Screams, Pain Grunts & Civilian Panic Screams
local PLAYER_HURT_A_URL = "rbxassetid://9120417632"      -- ProSoundEffects: Fight Vocals / Getting Hit Grunt
local PLAYER_HURT_B_URL = "rbxassetid://118159008749338" -- Damage Grunt 2
local ENEMY_HIT_A_URL = "rbxassetid://9125653559"        -- ProSoundEffects: Male Scream / Short Yell / Death Cry
local ENEMY_HIT_B_URL = "rbxassetid://121052703957549"   -- Combat Hurt Vocal 2
local CIVILIAN_PANIC_A_URL = "rbxassetid://9114399475"   -- ProSoundEffects: Short Screams & Panic Yells
local CIVILIAN_PANIC_B_URL = "rbxassetid://103266285456711" -- Scared Civilian Scream 1

-- Verified Official ProSoundEffects, APMOfficial & Creator Store Cinematic Surprise Audio Suite
local CINEMATIC_BOOM_URL = "rbxassetid://9125484367"       -- ProSoundEffects: Deep Hits Big Reverberant Booms 2
local SUB_DROP_URL = "rbxassetid://1837830050"             -- APMOfficial: BOOM-Sub Boom 01
local VAULT_RUMBLE_URL = "rbxassetid://9125484526"         -- ProSoundEffects: Deep Hits Big Reverberant Booms 1
local KATANA_DRAW_URL = "rbxassetid://79499154333475"      -- Crisp Steel Katana Unsheathe
local KATANA_SLASH_WIND_URL = "rbxassetid://130317074796316" -- Katana Slash Wind 7
local PETAL_WHOOSH_URL = "rbxassetid://81471688425359"     -- Long Petal Woosh SFX
local NINJA_WHOOSH_URL = "rbxassetid://80454497832356"     -- Fast Kunai / Smoke Whoosh
local LEGENDARY_CHIME_URL = "rbxassetid://73774648241042"  -- RatingExcellent Jackpot Chime
local MYSTERY_STING_URL = "rbxassetid://9042321434"        -- APMOfficial: Dramatic Reveal Sting

type PoolSpec = {
	SoundId: string,
	PoolSize: number,
	BaseVolume: number,
	BaseSpeed: number,
	StartOffset: number,
	PitchJitter: number,
	Distort: number?,
	LowGain: number?,
	MidGain: number?,
	HighGain: number?,
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
		PoolSize = 6,
		BaseVolume = 0.86,
		BaseSpeed = 1.02,
		StartOffset = 0.01,
		PitchJitter = 0.035,
		LowGain = 3.5,
		MidGain = 1.5,
	},
	SuppressedShot = {
		SoundId = SUPPRESSED_SFX_URL,
		PoolSize = 5,
		BaseVolume = 0.72,
		BaseSpeed = 1.06,
		StartOffset = 0.01,
		PitchJitter = 0.04,
		LowGain = 2.0,
		HighGain = -3.0,
	},
	RifleShot = {
		SoundId = RIFLE_SFX_URL,
		PoolSize = 8,
		BaseVolume = 0.84,
		BaseSpeed = 1.02,
		StartOffset = 0.01,
		PitchJitter = 0.035,
		LowGain = 4.0,
		MidGain = 1.2,
	},
	SMGShot = {
		SoundId = SMG_SFX_URL,
		PoolSize = 8,
		BaseVolume = 0.76,
		BaseSpeed = 1.08,
		StartOffset = 0.01,
		PitchJitter = 0.04,
		LowGain = 2.5,
	},
	ShotgunBlast = {
		SoundId = SHOTGUN_SFX_URL,
		PoolSize = 4,
		BaseVolume = 0.94,
		BaseSpeed = 0.94,
		StartOffset = 0.01,
		PitchJitter = 0.025,
		LowGain = 5.5,
		MidGain = 1.5,
	},
	ShotgunBoomTail = {
		SoundId = EXPLOSION_URL,
		PoolSize = 4,
		BaseVolume = 0.28,
		BaseSpeed = 1.68,
		StartOffset = 0.02,
		PitchJitter = 0.03,
	},
	SniperShot = {
		SoundId = SNIPER_SFX_URL,
		PoolSize = 4,
		BaseVolume = 0.96,
		BaseSpeed = 0.96,
		StartOffset = 0.01,
		PitchJitter = 0.02,
		LowGain = 5.0,
		HighGain = 1.5,
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
	BodyDrop = {
		SoundId = PUNCH_SFX_URL,
		PoolSize = 4,
		BaseVolume = 0.68,
		BaseSpeed = 0.44,
		StartOffset = 0.02,
		PitchJitter = 0.06,
	},
	BodyDropTail = {
		SoundId = HIT_URL,
		PoolSize = 4,
		BaseVolume = 0.36,
		BaseSpeed = 0.50,
		StartOffset = 0,
		PitchJitter = 0.06,
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
		BaseVolume = 0.44,
		BaseSpeed = 1.55,
		StartOffset = 0,
		PitchJitter = 0.04,
	},
	MeleeSnap = {
		SoundId = SNAP_URL,
		PoolSize = 3,
		BaseVolume = 0.26,
		BaseSpeed = 1.30,
		StartOffset = 0,
		PitchJitter = 0.04,
	},
	MeleePunch = {
		SoundId = PUNCH_SFX_URL,
		PoolSize = 4,
		BaseVolume = 0.74,
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
	-- Combat Hit Screams, Pain Grunts & Civilian Panic Screams
	PlayerHurtA = {
		SoundId = PLAYER_HURT_A_URL,
		PoolSize = 3,
		BaseVolume = 0.90,
		BaseSpeed = 1.00,
		StartOffset = 0,
		PitchJitter = 0.06,
	},
	PlayerHurtB = {
		SoundId = PLAYER_HURT_B_URL,
		PoolSize = 3,
		BaseVolume = 0.88,
		BaseSpeed = 1.00,
		StartOffset = 0,
		PitchJitter = 0.06,
	},
	EnemyHitA = {
		SoundId = ENEMY_HIT_A_URL,
		PoolSize = 4,
		BaseVolume = 0.82,
		BaseSpeed = 1.04,
		StartOffset = 0,
		PitchJitter = 0.08,
	},
	EnemyHitB = {
		SoundId = ENEMY_HIT_B_URL,
		PoolSize = 4,
		BaseVolume = 0.86,
		BaseSpeed = 1.00,
		StartOffset = 0,
		PitchJitter = 0.08,
	},
	EnemyDeathScream = {
		SoundId = ENEMY_HIT_A_URL,
		PoolSize = 4,
		BaseVolume = 0.96,
		BaseSpeed = 0.88,
		StartOffset = 0,
		PitchJitter = 0.06,
		LowGain = 2.0,
	},
	CivilianPanicA = {
		SoundId = CIVILIAN_PANIC_A_URL,
		PoolSize = 3,
		BaseVolume = 0.72,
		BaseSpeed = 1.02,
		StartOffset = 0,
		PitchJitter = 0.07,
	},
	CivilianPanicB = {
		SoundId = CIVILIAN_PANIC_B_URL,
		PoolSize = 3,
		BaseVolume = 0.68,
		BaseSpeed = 1.04,
		StartOffset = 0,
		PitchJitter = 0.07,
	},
	-- Surprise Cinematic Reveal & Unit Welcome Audio Suite
	CinematicBoom = {
		SoundId = CINEMATIC_BOOM_URL,
		PoolSize = 2,
		BaseVolume = 1.0,
		BaseSpeed = 1.0,
		StartOffset = 0,
		PitchJitter = 0.02,
		LowGain = 6.0,
		MidGain = 1.5,
	},
	SubDrop = {
		SoundId = SUB_DROP_URL,
		PoolSize = 2,
		BaseVolume = 1.0,
		BaseSpeed = 0.96,
		StartOffset = 0,
		PitchJitter = 0.02,
		LowGain = 6.5,
	},
	VaultRumble = {
		SoundId = VAULT_RUMBLE_URL,
		PoolSize = 2,
		BaseVolume = 0.85,
		BaseSpeed = 0.82,
		StartOffset = 0,
		PitchJitter = 0.02,
		LowGain = 5.0,
	},
	KatanaDraw = {
		SoundId = KATANA_DRAW_URL,
		PoolSize = 2,
		BaseVolume = 0.92,
		BaseSpeed = 1.02,
		StartOffset = 0,
		PitchJitter = 0.03,
		HighGain = 3.0,
	},
	KatanaSlashWind = {
		SoundId = KATANA_SLASH_WIND_URL,
		PoolSize = 3,
		BaseVolume = 0.90,
		BaseSpeed = 1.05,
		StartOffset = 0,
		PitchJitter = 0.04,
		HighGain = 2.0,
	},
	PetalWhoosh = {
		SoundId = PETAL_WHOOSH_URL,
		PoolSize = 2,
		BaseVolume = 0.86,
		BaseSpeed = 1.0,
		StartOffset = 0,
		PitchJitter = 0.03,
	},
	NinjaWhoosh = {
		SoundId = NINJA_WHOOSH_URL,
		PoolSize = 4,
		BaseVolume = 0.84,
		BaseSpeed = 1.18,
		StartOffset = 0,
		PitchJitter = 0.06,
	},
	LegendaryChime = {
		SoundId = LEGENDARY_CHIME_URL,
		PoolSize = 2,
		BaseVolume = 0.95,
		BaseSpeed = 1.0,
		StartOffset = 0,
		PitchJitter = 0.01,
		HighGain = 2.5,
	},
	MysterySting = {
		SoundId = MYSTERY_STING_URL,
		PoolSize = 2,
		BaseVolume = 0.82,
		BaseSpeed = 1.04,
		StartOffset = 0,
		PitchJitter = 0.02,
	},
}

local audioPoolFolder: Folder? = nil
local pools: { [string]: PoolEntry } = {}
local isPreloaded = false

-- Smart throttle timestamps so combat vocal screams stay realistic and never spam/clip
local lastPlayerHurtAt = 0
local lastEnemyHitAt = 0
local lastEnemyDeathAt = 0
local lastCivilianPanicAt = 0
local playerHurtFlip = false
local enemyHitFlip = false
local civilianPanicFlip = false

-- Shared Client Combat Threat Bus (alerts Central & Urban Civilian NPCs to panic and flee!)
type CombatThreatListener = (worldPos: Vector3, threatKind: string) -> ()
local threatListeners: { CombatThreatListener } = {}

function AudioController.OnCombatThreat(cb: CombatThreatListener): ()
	table.insert(threatListeners, cb)
end

function AudioController.NotifyCombatThreat(worldPos: Vector3, threatKind: string): ()
	for _, cb in ipairs(threatListeners) do
		cb(worldPos, threatKind)
	end
end

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
			if spec.LowGain ~= nil or spec.MidGain ~= nil or spec.HighGain ~= nil then
				local eq = Instance.new("EqualizerSoundEffect")
				eq.LowGain = spec.LowGain or 0
				eq.MidGain = spec.MidGain or 0
				eq.HighGain = spec.HighGain or 0
				eq.Parent = s
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
	playTone(PING_URL, 0.42, 1.35, 0)
	playTone(PING_URL, 0.45, 1.68, 0.09)
end

function AudioController.PlayFanfare(): ()
	playTone(PING_URL, 0.40, 1.00, 0.00)
	playTone(PING_URL, 0.42, 1.26, 0.09)
	playTone(PING_URL, 0.45, 1.50, 0.18)
	playTone(PING_URL, 0.50, 2.00, 0.28)
end

function AudioController.PlayError(): ()
	playTone(CLICK_URL, 0.38, 0.65, 0)
	playTone(CLICK_URL, 0.35, 0.55, 0.09)
end

-- Crisp Melee Fighting Swing & Punch Impact Sound Effects
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

-- Upgraded Zero-Latency Preloaded & Pooled Realistic Firearms Audio
function AudioController.PlayPistolShot(volScale: number?): ()
	playPooled("PistolShot", volScale or 1, 1)
end

function AudioController.PlaySuppressedShot(volScale: number?): ()
	playPooled("SuppressedShot", volScale or 1, 1)
end

function AudioController.PlayRifleShot(volScale: number?): ()
	playPooled("RifleShot", volScale or 1, 1)
end

function AudioController.PlayShotgunBlast(volScale: number?): ()
	local v = volScale or 1
	playPooled("ShotgunBlast", v, 1)
	playPooled("ShotgunBoomTail", v, 1)
end

function AudioController.PlaySMGShot(volScale: number?): ()
	playPooled("SMGShot", volScale or 1, 1)
end

function AudioController.PlaySniperShot(volScale: number?): ()
	local v = volScale or 1
	playPooled("SniperShot", v, 1)
	playPooled("ShotgunBoomTail", v * 0.72, 1.40)
end

function AudioController.PlayWeaponFire(weaponId: string, volScale: number?, isSuppressed: boolean?): ()
	local v = volScale or 1
	local spec = WeaponConfig.WEAPONS[weaponId]
	local suppressed = (isSuppressed == true) or (spec ~= nil and spec.AlwaysSuppressed == true)

	if suppressed then
		playPooled("SuppressedShot", v * 1.15, if weaponId == "PhantomAssassinRifle" then 0.88 else 1.02)
		return
	end

	if weaponId == "ShadowSniper" then
		AudioController.PlaySniperShot(v)
		return
	elseif weaponId == "SilencedDeagle" then
		AudioController.PlaySuppressedShot(v * 1.1)
		return
	elseif weaponId == "SyndicateCarbine" or weaponId == "CrimsonDragonAR" then
		playPooled("RifleShot", v, if weaponId == "CrimsonDragonAR" then 0.94 else 1.02)
		return
	elseif weaponId == "GoldenEmperorPistol" then
		playPooled("PistolShot", v * 1.05, 0.92)
		return
	end

	local audioKey = if spec then spec.AudioKey else "PistolShot"
	if audioKey == "ShotgunBlast" then
		AudioController.PlayShotgunBlast(v)
	elseif audioKey == "SMGShot" then
		AudioController.PlaySMGShot(v)
	else
		AudioController.PlayPistolShot(v)
	end
end

-- Realistic Combat Hit Screams, Pain Grunts & Panicked Civilian Screams
function AudioController.PlayPlayerHurtScream(volScale: number?): ()
	local now = os.clock()
	if (now - lastPlayerHurtAt) < 0.55 then
		return
	end
	lastPlayerHurtAt = now
	playerHurtFlip = not playerHurtFlip
	playPooled(if playerHurtFlip then "PlayerHurtA" else "PlayerHurtB", volScale or 1, 1)
end

function AudioController.PlayEnemyHitScream(volScale: number?): ()
	local now = os.clock()
	if (now - lastEnemyHitAt) < 0.36 then
		return
	end
	lastEnemyHitAt = now
	enemyHitFlip = not enemyHitFlip
	playPooled(if enemyHitFlip then "EnemyHitA" else "EnemyHitB", volScale or 1, 1)
end

function AudioController.PlayEnemyDeathScream(volScale: number?): ()
	local now = os.clock()
	if (now - lastEnemyDeathAt) < 0.26 then
		return
	end
	lastEnemyDeathAt = now
	playPooled("EnemyDeathScream", volScale or 1, 1)
end

function AudioController.PlayCivilianPanicScream(volScale: number?): ()
	local now = os.clock()
	if (now - lastCivilianPanicAt) < 1.65 then
		return
	end
	lastCivilianPanicAt = now
	civilianPanicFlip = not civilianPanicFlip
	playPooled(if civilianPanicFlip then "CivilianPanicA" else "CivilianPanicB", volScale or 1, 1)
end

-- Reload, Shell Insert, Pump Action & Dry-Fire SFX
function AudioController.PlayDryFire(): ()
	playPooled("DryFireClick", 1, 1)
	playPooled("DryFireSnap", 0.85, 1.05)
end

function AudioController.PlayMagReload(weaponId: string): ()
	local spec = WeaponConfig.WEAPONS[weaponId]
	local dur = if spec then spec.ReloadTime else 1.45
	local speed = math.clamp(1.50 / math.max(0.8, dur), 0.68, 1.28)
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

function AudioController.PlayBodyDrop(volScale: number?): ()
	local v = volScale or 1
	playPooled("BodyDrop", v, 1)
	playPooled("BodyDropTail", v, 1)
end

-- Black Market Tier 2 Tactical Gadget SFX (Flashbang, C4 Breach Charge, Shadow Smoke Dash)
function AudioController.PlayFlashbangPop(volScale: number?): ()
	local v = volScale or 1
	playPooled("ShotgunBlast", v * 0.85, 1.55)
	playTone(PING_URL, 0.36 * v, 2.35, 0.04)
end

function AudioController.PlayC4Beep(volScale: number?): ()
	local v = volScale or 1
	playTone(PING_URL, 0.42 * v, 1.85, 0)
end

function AudioController.PlayC4Explosion(volScale: number?): ()
	local v = volScale or 1
	playPooled("ShotgunBoomTail", v * 1.45, 0.62)
	playPooled("ShotgunBlast", v * 1.15, 0.68)
end

function AudioController.PlayShadowDash(volScale: number?): ()
	local v = volScale or 1
	playPooled("MeleeSwing", v * 1.25, 0.78)
	playPooled("MeleeSnap", v * 0.9, 0.85)
end

-- =========================================================================
-- SURPRISE CINEMATIC AUDIO SUITE (Roulette Tick, Vault Drop, Ninja, Samurai, Bodyguard)
-- =========================================================================

-- Crisp pitch-escalating roulette peg click as the spin slows toward a jackpot!
function AudioController.PlaySpinTick(progress01: number): ()
	local p = math.clamp(progress01, 0, 1)
	local pitch = 0.92 + p * 0.62
	local vol = 0.30 + p * 0.22
	playTone(CLICK_URL, vol, pitch, 0)
	if p > 0.68 then
		playTone(SNAP_URL, 0.22 * p, 1.45 + p * 0.35, 0)
	end
end

-- Tense obsidian vault buildup right before doors blast apart
function AudioController.PlayVaultCharge(): ()
	playPooled("VaultRumble", 0.78, 0.76)
	playPooled("MysterySting", 0.72, 0.96)
	playTone(SNAP_URL, 0.42, 0.72, 0.14)
	playTone(SNAP_URL, 0.48, 0.88, 0.30)
	playTone(SNAP_URL, 0.56, 1.08, 0.44)
end

-- Jaw-dropping LEGENDARY surprise impact drop + reverberant gong + 24K golden chord arpeggio!
function AudioController.PlayLegendarySurpriseDrop(): ()
	playPooled("SubDrop", 1.15, 0.92)
	playPooled("CinematicBoom", 1.05, 0.98)
	task.delay(0.05, function()
		playPooled("LegendaryChime", 1.05, 1.0)
	end)
	-- Sparkling ascending syndicate brass/crystal chord
	playTone(PING_URL, 0.48, 1.00, 0.08)
	playTone(PING_URL, 0.50, 1.25, 0.17)
	playTone(PING_URL, 0.54, 1.50, 0.26)
	playTone(PING_URL, 0.58, 2.00, 0.36)
	playTone(PING_URL, 0.42, 2.50, 0.48)
end

-- Dramatic EPIC Black Market firearm reveal drop (Sub Drop + Heavy Rack + Chime)
function AudioController.PlayEpicRevealDrop(): ()
	playPooled("SubDrop", 1.0, 1.0)
	playPooled("CinematicBoom", 0.88, 1.06)
	task.delay(0.12, function()
		playPooled("ShotgunPump", 0.95, 0.96)
	end)
	task.delay(0.22, function()
		playPooled("LegendaryChime", 0.85, 1.06)
	end)
	playTone(PING_URL, 0.44, 1.18, 0.14)
	playTone(PING_URL, 0.48, 1.50, 0.25)
	playTone(PING_URL, 0.50, 1.88, 0.36)
end

-- Crisp RARE celebration chime
function AudioController.PlayRareRevealDrop(): ()
	playPooled("LegendaryChime", 0.82, 1.08)
	AudioController.PlayFanfare()
end

-- Surprise NINJA ASSASSIN Welcome SFX: whistling kunai barrage -> smoke sub drop -> razor katana X-slash!
function AudioController.PlayNinjaArrivalSFX(): ()
	playPooled("KatanaDraw", 0.95, 1.10)
	playPooled("NinjaWhoosh", 0.88, 1.32)
	task.delay(0.11, function()
		playPooled("NinjaWhoosh", 0.85, 1.18)
	end)
	task.delay(0.21, function()
		playPooled("NinjaWhoosh", 0.92, 1.04)
	end)
	task.delay(0.32, function()
		playPooled("SubDrop", 1.12, 0.94)
		playPooled("KatanaSlashWind", 1.05, 1.08)
	end)
	task.delay(0.46, function()
		playPooled("KatanaSlashWind", 0.90, 1.24)
		playPooled("MysterySting", 0.78, 1.08)
	end)
end

-- Surprise SAMURAI MAFIA Welcome SFX: slow metallic iaijutsu blade draw -> sakura petal whoosh -> deep gong boom!
function AudioController.PlaySamuraiArrivalSFX(): ()
	playPooled("KatanaDraw", 1.05, 0.92)
	task.delay(0.18, function()
		playPooled("PetalWhoosh", 0.95, 0.96)
	end)
	task.delay(0.42, function()
		playPooled("CinematicBoom", 1.08, 0.94)
		playPooled("SubDrop", 1.02, 0.96)
		playPooled("KatanaSlashWind", 1.02, 0.94)
	end)
	task.delay(0.62, function()
		playPooled("LegendaryChime", 0.88, 0.96)
		playTone(PING_URL, 0.44, 1.00, 0.00)
		playTone(PING_URL, 0.46, 1.33, 0.11)
		playTone(PING_URL, 0.50, 1.50, 0.22)
	end)
end

-- Surprise BODYGUARD Recruitment Welcome SFX: sub bass impact -> tactical rack -> brass fanfare chime!
function AudioController.PlayBodyguardArrivalSFX(): ()
	playPooled("SubDrop", 1.04, 0.98)
	playPooled("MysterySting", 0.82, 0.98)
	task.delay(0.16, function()
		playPooled("ShotgunPump", 0.96, 1.02)
	end)
	task.delay(0.32, function()
		playPooled("CinematicBoom", 0.85, 1.06)
		playPooled("LegendaryChime", 0.96, 1.02)
	end)
	playTone(PING_URL, 0.44, 1.12, 0.34)
	playTone(PING_URL, 0.48, 1.50, 0.46)
	playTone(PING_URL, 0.52, 2.00, 0.58)
end

function AudioController.PlayCombatSFX(kind: string, volScale: number?): ()
	if kind == "PistolShot" or kind == "EnemyShot" then
		AudioController.PlayPistolShot(volScale)
	elseif kind == "SuppressedShot" then
		AudioController.PlaySuppressedShot(volScale)
	elseif kind == "RifleShot" then
		AudioController.PlayRifleShot(volScale)
	elseif kind == "ShotgunBlast" then
		AudioController.PlayShotgunBlast(volScale)
	elseif kind == "SMGShot" then
		AudioController.PlaySMGShot(volScale)
	elseif kind == "SniperShot" then
		AudioController.PlaySniperShot(volScale)
	elseif kind == "MeleeHit" then
		AudioController.PlayMeleeHit(volScale)
	elseif kind == "MeleeSwing" then
		AudioController.PlayMeleeSwing(volScale)
	elseif kind == "ShotgunPump" then
		AudioController.PlayShotgunPump()
	elseif kind == "BodyDrop" then
		AudioController.PlayBodyDrop(volScale)
	elseif kind == "FlashbangPop" then
		AudioController.PlayFlashbangPop(volScale)
	elseif kind == "C4Beep" then
		AudioController.PlayC4Beep(volScale)
	elseif kind == "C4Explosion" then
		AudioController.PlayC4Explosion(volScale)
	elseif kind == "ShadowDash" then
		AudioController.PlayShadowDash(volScale)
	elseif kind == "PlayerHurtScream" then
		AudioController.PlayPlayerHurtScream(volScale)
	elseif kind == "EnemyHitScream" then
		AudioController.PlayEnemyHitScream(volScale)
	elseif kind == "EnemyDeathScream" then
		AudioController.PlayEnemyDeathScream(volScale)
	elseif kind == "CivilianPanicScream" then
		AudioController.PlayCivilianPanicScream(volScale)
	end
end

-- Warm up & preload all combat & weapon audio pools immediately on module load
ensurePoolInitialized()

return AudioController
