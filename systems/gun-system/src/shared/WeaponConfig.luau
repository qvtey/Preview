--!strict

local Types = require(script.Parent.Types)

type WeaponConfig = Types.WeaponConfig

local CONFIGS: { [string]: WeaponConfig } = {
	rifle = {
		id = "rifle",
		displayName = "Service Rifle",
		automatic = true,
		roundsPerMinute = 700,
		damage = 24,
		headshotMultiplier = 1.8,
		range = 900,
		falloffStart = 60,
		falloffEnd = 300,
		falloffFloor = 0.55,
		magazineSize = 30,
		reserveAmmo = 120,
		reloadTime = 2.4,
		spread = {
			hip = 3.2,
			aim = 0.4,
			perShot = 0.35,
			decay = 4,
			max = 4.5,
		},
		recoil = {
			vertical = 1.1,
			horizontal = 0.45,
			stiffness = 90,
			damping = 14,
		},
	},

	pistol = {
		id = "pistol",
		displayName = "Sidearm",
		automatic = false,
		roundsPerMinute = 400,
		damage = 32,
		headshotMultiplier = 2,
		range = 500,
		falloffStart = 30,
		falloffEnd = 140,
		falloffFloor = 0.5,
		magazineSize = 12,
		reserveAmmo = 60,
		reloadTime = 1.6,
		spread = {
			hip = 2.4,
			aim = 0.3,
			perShot = 0.5,
			decay = 5,
			max = 5,
		},
		recoil = {
			vertical = 1.4,
			horizontal = 0.6,
			stiffness = 110,
			damping = 16,
		},
	},
}

local ids: { string } = {}

for id, config in CONFIGS do
	assert(id == config.id, `weapon "{id}" does not match its own id field`)
	assert(config.falloffEnd > config.falloffStart, `weapon "{id}" has an inverted falloff range`)
	assert(config.roundsPerMinute > 0, `weapon "{id}" needs a positive fire rate`)

	table.freeze(config.spread)
	table.freeze(config.recoil)
	table.freeze(config)
	table.insert(ids, id)
end

table.sort(ids)
table.freeze(ids)
table.freeze(CONFIGS)

local WeaponConfig = {}

function WeaponConfig.ids(): { string }
	return ids
end

function WeaponConfig.find(id: string): WeaponConfig?
	if typeof(id) ~= "string" then
		return nil
	end

	return CONFIGS[id]
end

function WeaponConfig.expect(id: string): WeaponConfig
	return assert(CONFIGS[id], `unknown weapon "{id}"`)
end

return WeaponConfig
