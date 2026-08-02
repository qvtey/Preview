--!strict

local Types = require(script.Parent.Types)

type WeaponConfig = Types.WeaponConfig

local Ballistics = {}

function Ballistics.fireInterval(config: WeaponConfig): number
	return 60 / config.roundsPerMinute
end

function Ballistics.damageAt(config: WeaponConfig, distance: number): number
	if distance <= config.falloffStart then
		return config.damage
	end

	if distance >= config.falloffEnd then
		return config.damage * config.falloffFloor
	end

	local alpha = (distance - config.falloffStart) / (config.falloffEnd - config.falloffStart)

	return config.damage * (1 - alpha * (1 - config.falloffFloor))
end

function Ballistics.spreadAngle(config: WeaponConfig, bloom: number, aiming: boolean): number
	local base = if aiming then config.spread.aim else config.spread.hip

	return base + math.clamp(bloom, 0, config.spread.max)
end

function Ballistics.bloomAfterShot(config: WeaponConfig, bloom: number): number
	return math.min(config.spread.max, bloom + config.spread.perShot)
end

function Ballistics.decayBloom(config: WeaponConfig, bloom: number, elapsed: number): number
	return math.max(0, bloom - config.spread.decay * elapsed)
end

function Ballistics.coneDirection(direction: Vector3, angleDegrees: number, random: Random): Vector3
	local forward = direction.Unit

	if angleDegrees <= 0 then
		return forward
	end

	local limit = math.rad(angleDegrees)
	local azimuth = random:NextNumber() * math.pi * 2
	local polar = math.acos(1 - random:NextNumber() * (1 - math.cos(limit)))

	local offset = Vector3.new(
		math.sin(polar) * math.cos(azimuth),
		math.sin(polar) * math.sin(azimuth),
		-math.cos(polar)
	)

	return CFrame.lookAlong(Vector3.zero, forward):VectorToWorldSpace(offset).Unit
end

return Ballistics
