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
	Player = { Scale = 1.50, IsPlayerProfile = true },
	NPC = {
		Basic = { Scale = 0.75 },
		Elite = { Scale = 0.87 },
		Boss = { Scale = 1.10 },
	},
}

return CharacterScaleConfig
