--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WeaponConfig")
)
local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local PlayerDataService = require("./PlayerDataService")
local WarehouseService = require("./WarehouseService")
local MercenaryMafiaService = require("./MercenaryMafiaService")

local PrestigeVaultService = {}

local DAILY_REWARDS = {
	[1] = { Label = "DAY 1: +250 Gold & +25 Rep", Gold = 250, Rep = 25 },
	[2] = { Label = "DAY 2: +400 Gold & +5 All Ingredients", Gold = 400, Rep = 35, AllIng = 5 },
	[3] = { Label = "DAY 3: +550 Gold & +60 Rep", Gold = 550, Rep = 60 },
	[4] = { Label = "DAY 4: +750 Gold, 3x Smoke & Full Ammo", Gold = 750, Rep = 75, Smoke = 3, FullAmmo = true },
	[5] = { Label = "DAY 5: +950 Gold, +1 Golden Tuna & +1 King Crab", Gold = 950, Rep = 90, RareCatch = true },
	[6] = { Label = "DAY 6: +1,200 Gold & +120 Rep", Gold = 1200, Rep = 120 },
	[7] = { Label = "DAY 7: +1,600 Gold & FREE 5-MIN SAMURAI MAFIA CONTRACT!", Gold = 1600, Rep = 180, FreeSamurai = true },
}

local function getCurrentUtcDay(): number
	return math.floor(os.time() / 86400)
end

function PrestigeVaultService.ClaimDailyVault(player: Player): (boolean, string)
	local prof = PlayerDataService.GetProfile(player)
	local today = getCurrentUtcDay()
	if (prof.LastDailyClaimDay or 0) == today then
		return false, "Today's Daily Syndicate Vault reward is already claimed! Return tomorrow for your next streak reward."
	end

	local prevDay = prof.LastDailyClaimDay or 0
	local nextStreak = if prevDay == (today - 1) then ((prof.DailyStreak or 0) % 7) + 1 else 1
	local reward = DAILY_REWARDS[nextStreak] or DAILY_REWARDS[1]

	PlayerDataService.SetDailyVaultProgress(player, nextStreak, today)
	PlayerDataService.AddRewards(player, reward.Gold, math.floor(reward.Gold * 0.25), reward.Rep)

	if reward.AllIng then
		for _, cat in ipairs(WarehouseConfig.Categories) do
			if WarehouseService.IsUnlocked(player, cat) then
				local spec = WarehouseConfig.Specs[cat]
				for _, ing in ipairs(spec.Ingredients) do
					if ing ~= "golden_tuna" and ing ~= "king_crab" then
						WarehouseService.AddIngredient(player, ing, reward.AllIng)
					end
				end
			end
		end
	end
	if reward.Smoke then
		PlayerDataService.AddSmokeGrenades(player, reward.Smoke)
	end
	if reward.FullAmmo then
		for _, aid in ipairs(WeaponConfig.AMMO_ORDER) do
			local aSpec = WeaponConfig.AMMO_TYPES[aid]
			if aSpec then
				PlayerDataService.SetAmmo(player, aid, aSpec.MaxReserve, aSpec.MaxReserve)
			end
		end
	end
	if reward.RareCatch and WarehouseService.IsUnlocked(player, "Fish") then
		WarehouseService.AddIngredient(player, "golden_tuna", 1)
		WarehouseService.AddIngredient(player, "king_crab", 1)
	end
	if reward.FreeSamurai then
		MercenaryMafiaService.ActivateContract(player, "Samurai")
	end

	return true, string.format("DAILY SYNDICATE VAULT CLAIMED (%s)!", reward.Label)
end

function PrestigeVaultService.TriggerGodfatherPrestige(player: Player): (boolean, string)
	local prof = PlayerDataService.GetProfile(player)
	if prof.RestaurantLevel < 10 and prof.Reputation < 2000 then
		return false, string.format("Requires Restaurant HQ Lv.10 OR 2,000 Reputation for Godfather Prestige (Current: HQ Lv.%d, %d Rep)!", prof.RestaurantLevel, prof.Reputation)
	end
	local newPrestige = PlayerDataService.IncrementPrestige(player)
	return true, string.format("REBORN AS GODFATHER PRESTIGE P%d! Permanent +%d%% Lifetime Gold & Rep Boost unlocked (all weapons, vehicles & bodyguards kept)!", newPrestige, newPrestige * 25)
end

function PrestigeVaultService.GetSnapshot(player: Player): { [string]: any }
	local prof = PlayerDataService.GetProfile(player)
	local today = getCurrentUtcDay()
	local canClaim = (prof.LastDailyClaimDay or 0) ~= today
	local previewDay = if canClaim
		then (if (prof.LastDailyClaimDay or 0) == (today - 1) then ((prof.DailyStreak or 0) % 7) + 1 else 1)
		else math.max(1, prof.DailyStreak or 1)
	local rew = DAILY_REWARDS[previewDay] or DAILY_REWARDS[1]
	return {
		Streak = prof.DailyStreak or 0,
		CanClaimToday = canClaim,
		NextDayNum = previewDay,
		NextRewardLabel = rew.Label,
		PrestigeLevel = prof.PrestigeLevel or 0,
		PrestigeBonusPct = (prof.PrestigeLevel or 0) * 25,
		CanPrestige = (prof.RestaurantLevel >= 10) or (prof.Reputation >= 2000),
	}
end

return PrestigeVaultService
