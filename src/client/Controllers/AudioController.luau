--!strict

local SoundService = game:GetService("SoundService")

local AudioController = {}

local PING_URL = "rbxasset://sounds/electronicpingshort.wav"
local CLICK_URL = "rbxasset://sounds/button.wav"
local SWING_URL = "rbxasset://sounds/action_jump.mp3"
local HIT_URL = "rbxasset://sounds/hit.wav"
local SNAP_URL = "rbxasset://sounds/snap.wav"
local EXPLOSION_URL = "rbxasset://sounds/impact_explosion_03.mp3"

-- Verified Creator Store realistic gunshots & punch fighting SFX!
local PISTOL_SFX_URL = "rbxassetid://127604219525464"
local SHOTGUN_SFX_URL = "rbxassetid://3102797479"
local SMG_SFX_URL = "rbxassetid://92011177452282"
local PUNCH_SFX_URL = "rbxassetid://87384287237291"

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

-- Crisp Melee Fighting Swing & Punch Impact Sound Effects!
function AudioController.PlayMeleeSwing(volScale: number?): ()
	local v = volScale or 1
	playTone(SWING_URL, 0.42 * v, 1.55, 0)
	playTone(SNAP_URL, 0.25 * v, 1.3, 0.02)
end

function AudioController.PlayMeleeHit(volScale: number?): ()
	local v = volScale or 1
	playTone(PUNCH_SFX_URL, 0.72 * v, 1.05, 0)
	playTone(HIT_URL, 0.42 * v, 1.15, 0, 0.2)
end

-- Realistic Gunshot Sound Effects (Pistol, Pepper Shotgun Blast, Rapid Tactical SMG, Enemy Gunfire!)
function AudioController.PlayPistolShot(volScale: number?): ()
	local v = volScale or 1
	playTone(PISTOL_SFX_URL, 0.78 * v, 1.05, 0)
end

function AudioController.PlayShotgunBlast(volScale: number?): ()
	local v = volScale or 1
	playTone(SHOTGUN_SFX_URL, 0.88 * v, 0.88, 0)
	playTone(EXPLOSION_URL, 0.35 * v, 1.65, 0)
end

function AudioController.PlaySMGShot(volScale: number?): ()
	local v = volScale or 1
	playTone(SMG_SFX_URL, 0.65 * v, 1.22, 0)
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
	end
end

return AudioController
