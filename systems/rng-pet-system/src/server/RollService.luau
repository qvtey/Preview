--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetSystem = ReplicatedStorage:WaitForChild("PetSystem")
local LuckCurve = require(PetSystem:WaitForChild("LuckCurve"))
local PetRegistry = require(PetSystem:WaitForChild("PetRegistry"))
local Types = require(PetSystem:WaitForChild("Types"))
local WeightedPool = require(PetSystem:WaitForChild("WeightedPool"))

local RateLimiter = require(script.Parent:WaitForChild("RateLimiter"))

type PetDefinition = Types.PetDefinition
type Pool = WeightedPool.Pool<PetDefinition>

local BURST_SIZE = 5
local ROLLS_PER_SECOND = 3
local LUCK_PRECISION = 100

local pools: { [number]: Pool } = {}
local generators: { [Player]: Random } = {}
local rollCounts: { [Player]: number } = {}
local luckValues: { [Player]: number } = {}

local limiter = RateLimiter.new(BURST_SIZE, ROLLS_PER_SECOND)
local rolled = Instance.new("BindableEvent")

local RollService = {}

RollService.enabled = true
RollService.rolled = rolled.Event

local function poolFor(luck: number): Pool
	local quantised = math.round(LuckCurve.clamp(luck) * LUCK_PRECISION)
	local cached = pools[quantised]

	if cached then
		return cached
	end

	local entries: { WeightedPool.Entry<PetDefinition> } = {}

	for _, definition in PetRegistry.all() do
		table.insert(entries, {
			value = definition,
			weight = LuckCurve.weightFor(definition, quantised / LUCK_PRECISION),
		})
	end

	local pool = WeightedPool.new(entries)
	pools[quantised] = pool

	return pool
end

function RollService.bind(player: Player)
	generators[player] = Random.new()
	rollCounts[player] = rollCounts[player] or 0
	luckValues[player] = luckValues[player] or LuckCurve.MIN
end

function RollService.unbind(player: Player)
	generators[player] = nil
	rollCounts[player] = nil
	luckValues[player] = nil
	limiter:forget(tostring(player.UserId))
end

function RollService.setLuck(player: Player, luck: number)
	luckValues[player] = LuckCurve.clamp(luck)
end

function RollService.setRollCount(player: Player, count: number)
	rollCounts[player] = math.max(0, math.floor(count))
end

function RollService.getRollCount(player: Player): number
	return rollCounts[player] or 0
end

function RollService.odds(luck: number): { [string]: number }
	local pool = poolFor(luck)
	local chances: { [string]: number } = {}

	for _, definition in PetRegistry.all() do
		chances[definition.id] = pool:chanceOf(definition)
	end

	return chances
end

function RollService.roll(player: Player): Types.RollResponse
	if not RollService.enabled then
		return { ok = false, rejection = { code = "Disabled", retryAfter = 0 } }
	end

	local generator = generators[player]
	if generator == nil then
		return { ok = false, rejection = { code = "NotReady", retryAfter = 1 } }
	end

	local key = tostring(player.UserId)
	if not limiter:take(key) then
		return { ok = false, rejection = { code = "Cooldown", retryAfter = limiter:retryAfter(key) } }
	end

	local luck = luckValues[player] or LuckCurve.MIN
	local pool = poolFor(luck)
	local definition = pool:sample(generator)
	local count = (rollCounts[player] or 0) + 1

	rollCounts[player] = count

	local result: Types.RollResult = {
		petId = definition.id,
		rarity = definition.rarity,
		chance = pool:chanceOf(definition),
		luck = luck,
		rollNumber = count,
	}

	rolled:Fire(player, result)

	return { ok = true, result = result }
end

return RollService
