--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Ballistics = require(GunSystem:WaitForChild("Ballistics"))
local Types = require(GunSystem:WaitForChild("Types"))
local WeaponConfig = require(GunSystem:WaitForChild("WeaponConfig"))

local RATE_TOLERANCE = 0.02
local EQUIP_INTERVAL = 0.25

type Pocket = {
	magazine: number,
	reserve: number,
}

export type State = {
	weaponId: string,
	pockets: { [string]: Pocket },
	reloading: boolean,
	reloadToken: number,
	lastShot: number,
	lastEquip: number,
	bloom: number,
}

local states: { [Player]: State } = {}

local AmmoState = {}

local function pocketFor(state: State, config: Types.WeaponConfig): Pocket
	local pocket = state.pockets[config.id]

	if pocket == nil then
		pocket = {
			magazine = config.magazineSize,
			reserve = config.reserveAmmo,
		}

		state.pockets[config.id] = pocket
	end

	return pocket
end

function AmmoState.get(player: Player): State?
	return states[player]
end

function AmmoState.clear(player: Player)
	states[player] = nil
end

function AmmoState.reset(player: Player)
	local state = states[player]

	if state then
		states[player] = nil
		AmmoState.equip(player, state.weaponId)
	end
end

function AmmoState.equip(player: Player, weaponId: string): boolean
	local config = WeaponConfig.find(weaponId)

	if config == nil then
		return false
	end

	local now = os.clock()
	local state = states[player]

	if state == nil then
		state = {
			weaponId = config.id,
			pockets = {},
			reloading = false,
			reloadToken = 0,
			lastShot = 0,
			lastEquip = now,
			bloom = 0,
		}

		states[player] = state
		pocketFor(state, config)

		return true
	end

	if now - state.lastEquip < EQUIP_INTERVAL then
		return false
	end

	state.weaponId = config.id
	state.lastEquip = now
	state.lastShot = now
	state.reloading = false
	state.reloadToken += 1
	state.bloom = 0

	pocketFor(state, config)

	return true
end

function AmmoState.consume(player: Player, now: number, aiming: boolean): number?
	local state = states[player]

	if state == nil or state.reloading then
		return nil
	end

	local config = WeaponConfig.find(state.weaponId)

	if config == nil then
		return nil
	end

	local pocket = pocketFor(state, config)

	if pocket.magazine <= 0 then
		return nil
	end

	local elapsed = now - state.lastShot

	if elapsed < Ballistics.fireInterval(config) - RATE_TOLERANCE then
		return nil
	end

	local bloom = Ballistics.decayBloom(config, state.bloom, elapsed)
	local angle = Ballistics.spreadAngle(config, bloom, aiming)

	pocket.magazine -= 1
	state.lastShot = now
	state.bloom = Ballistics.bloomAfterShot(config, bloom)

	return angle
end

function AmmoState.beginReload(player: Player): number?
	local state = states[player]

	if state == nil or state.reloading then
		return nil
	end

	local config = WeaponConfig.find(state.weaponId)

	if config == nil then
		return nil
	end

	local pocket = pocketFor(state, config)

	if pocket.magazine >= config.magazineSize or pocket.reserve <= 0 then
		return nil
	end

	state.reloading = true
	state.reloadToken += 1

	return state.reloadToken
end

function AmmoState.finishReload(player: Player, token: number): boolean
	local state = states[player]

	if state == nil or not state.reloading or state.reloadToken ~= token then
		return false
	end

	local config = WeaponConfig.find(state.weaponId)

	if config == nil then
		return false
	end

	local pocket = pocketFor(state, config)
	local moved = math.min(config.magazineSize - pocket.magazine, pocket.reserve)

	pocket.magazine += moved
	pocket.reserve -= moved
	state.reloading = false
	state.bloom = 0

	return true
end

function AmmoState.magazine(player: Player): number
	local state = states[player]

	if state == nil then
		return 0
	end

	local config = WeaponConfig.find(state.weaponId)

	if config == nil then
		return 0
	end

	return pocketFor(state, config).magazine
end

function AmmoState.report(player: Player): Types.AmmoReport?
	local state = states[player]

	if state == nil then
		return nil
	end

	local config = WeaponConfig.find(state.weaponId)

	if config == nil then
		return nil
	end

	local pocket = pocketFor(state, config)

	return {
		weaponId = state.weaponId,
		magazine = pocket.magazine,
		reserve = pocket.reserve,
		reloading = state.reloading,
		reloadTime = config.reloadTime,
	}
end

return AmmoState
