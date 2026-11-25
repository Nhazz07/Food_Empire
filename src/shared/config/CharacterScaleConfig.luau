--!strict
-- Visual-only scale profiles. These values never alter health, damage, or combat stats.

export type PlayerScaleProfile = {
	Scale: number,
	IsPlayerProfile: boolean,
}

export type NPCScaleProfile = {
	Scale: number,
}

export type CharacterScaleConfigType = {
	Player: PlayerScaleProfile,
	NPC: { [string]: NPCScaleProfile },
}

local CharacterScaleConfig: CharacterScaleConfigType = {
	-- Realistic human proportions: player is only subtly taller (~0.4-0.5 studs) than NPCs, never a giant!
	Player = { Scale = 1.06, IsPlayerProfile = true },
	NPC = {
		Basic = { Scale = 0.96 },
		Elite = { Scale = 1.02 },
		Boss = { Scale = 1.15 },
	},
}

return CharacterScaleConfig
