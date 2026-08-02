--!strict

local Schema = require(script.Parent.Schema)

type Step = (data: any) -> ()

local STEPS: { [number]: Step } = {
	[1] = function(data)
		data.currency = {
			coins = tonumber(data.coins) or 0,
			gems = tonumber(data.gems) or 0,
		}

		data.coins = nil
		data.gems = nil
	end,

	[2] = function(data)
		local owned: { [string]: number } = {}

		if typeof(data.pets) == "table" then
			for _, petId in data.pets do
				if typeof(petId) == "string" then
					owned[petId] = (owned[petId] or 0) + 1
				end
			end
		end

		data.pets = {
			owned = owned,
			equipped = {},
		}
	end,

	[3] = function(data)
		local stats = if typeof(data.stats) == "table" then data.stats else {}

		stats.playtimeSeconds = math.floor(tonumber(stats.playtime) or 0)
		stats.playtime = nil
		stats.bestRarity = if typeof(stats.bestRarity) == "string" then stats.bestRarity else "None"
		data.stats = stats
	end,
}

local Migrations = {}

function Migrations.run(data: any, from: number): (number, number)
	local version = from
	local applied = 0

	while version < Schema.VERSION do
		local step = STEPS[version]

		if step == nil then
			break
		end

		step(data)
		version += 1
		applied += 1
	end

	data.schemaVersion = version

	return version, applied
end

return Migrations
