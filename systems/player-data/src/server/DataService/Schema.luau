--!strict

export type PlayerData = {
	schemaVersion: number,
	currency: {
		coins: number,
		gems: number,
	},
	pets: {
		owned: { [string]: number },
		equipped: { string },
	},
	stats: {
		rolls: number,
		playtimeSeconds: number,
		bestRarity: string,
	},
	settings: {
		musicVolume: number,
		lowGraphics: boolean,
	},
}

local Schema = {}

Schema.VERSION = 4

function Schema.template(): PlayerData
	return {
		schemaVersion = Schema.VERSION,
		currency = {
			coins = 0,
			gems = 0,
		},
		pets = {
			owned = {},
			equipped = {},
		},
		stats = {
			rolls = 0,
			playtimeSeconds = 0,
			bestRarity = "None",
		},
		settings = {
			musicVolume = 0.5,
			lowGraphics = false,
		},
	}
end

return Schema
