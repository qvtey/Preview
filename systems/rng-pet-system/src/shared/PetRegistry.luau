--!strict

local Types = require(script.Parent.Types)

type PetDefinition = Types.PetDefinition

local DEFINITIONS: { PetDefinition } = {
	{ id = "rabbit", displayName = "Rabbit", rarity = "Common", weight = 8000, model = "Rabbit" },
	{ id = "dog", displayName = "Dog", rarity = "Uncommon", weight = 1990, model = "Dog" },
	{ id = "turtle", displayName = "Turtle", rarity = "Legendary", weight = 10, model = "Turtle" },
}

local byId: { [string]: PetDefinition } = {}
local totalWeight = 0

for _, definition in DEFINITIONS do
	assert(byId[definition.id] == nil, `duplicate pet id "{definition.id}"`)
	assert(definition.weight > 0, `pet "{definition.id}" needs a weight above zero`)

	byId[definition.id] = table.freeze(definition)
	totalWeight += definition.weight
end

table.freeze(DEFINITIONS)
table.freeze(byId)

local PetRegistry = {}

PetRegistry.totalWeight = totalWeight

function PetRegistry.all(): { PetDefinition }
	return DEFINITIONS
end

function PetRegistry.find(id: string): PetDefinition?
	return byId[id]
end

function PetRegistry.expect(id: string): PetDefinition
	return assert(byId[id], `unknown pet id "{id}"`)
end

function PetRegistry.baseChance(id: string): number
	return PetRegistry.expect(id).weight / totalWeight
end

return PetRegistry
