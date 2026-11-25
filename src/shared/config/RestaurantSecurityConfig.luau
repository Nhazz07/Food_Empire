--!strict

-- RestaurantSecurityConfig: Shared configurable tuning for Customer Patience
-- (Stage 1) and upcoming Nighttime Mafia Raids & Restaurant Defense systems.

export type CustomerPatienceConfig = {
	MinSeconds: number,
	MaxSeconds: number,
	WarningThresholdSeconds: number,
	CriticalThresholdSeconds: number,
	ExpiryReputationLoss: number,
	TickInterval: number,
	UnhappyPauseSeconds: number,
	ReplacementSpawnDelay: number,
	MaxQuickServeCookSeconds: number,
}

export type RestaurantSecurityConfigType = {
	CustomerPatience: CustomerPatienceConfig,
}

local RestaurantSecurityConfig: RestaurantSecurityConfigType = {
	CustomerPatience = {
		MinSeconds = 40,
		MaxSeconds = 40,
		WarningThresholdSeconds = 12,
		CriticalThresholdSeconds = 6,
		ExpiryReputationLoss = 3,
		TickInterval = 0.25,
		UnhappyPauseSeconds = 1.4,
		ReplacementSpawnDelay = 3.5,
		MaxQuickServeCookSeconds = 8.5,
	},
}

return RestaurantSecurityConfig
