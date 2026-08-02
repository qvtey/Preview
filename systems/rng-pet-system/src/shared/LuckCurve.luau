--!strict

local Types = require(script.Parent.Types)

local INFLUENCE: { [Types.Rarity]: number } = {
	Common = 0,
	Uncommon = 0.35,
	Legendary = 1,
}

local LuckCurve = {}

LuckCurve.MIN = 1
LuckCurve.MAX = 10

function LuckCurve.clamp(luck: number): number
	if luck ~= luck then
		return LuckCurve.MIN
	end

	return math.clamp(luck, LuckCurve.MIN, LuckCurve.MAX)
end

function LuckCurve.weightFor(definition: Types.PetDefinition, luck: number): number
	local influence = INFLUENCE[definition.rarity]

	return definition.weight * (1 + (LuckCurve.clamp(luck) - 1) * influence)
end

return LuckCurve
