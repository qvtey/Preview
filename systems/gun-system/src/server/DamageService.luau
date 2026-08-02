--!strict

local killedEvent = Instance.new("BindableEvent")
local damagedEvent = Instance.new("BindableEvent")

local DamageService = {}

DamageService.friendlyFire = false
DamageService.killed = killedEvent.Event
DamageService.damaged = damagedEvent.Event

local function sameTeam(source: Player, target: Player): boolean
	if source.Neutral or target.Neutral then
		return false
	end

	return source.Team ~= nil and source.Team == target.Team
end

function DamageService.canDamage(source: Player, target: Player): boolean
	if source == target then
		return false
	end

	if not DamageService.friendlyFire and sameTeam(source, target) then
		return false
	end

	local character = target.Character

	if character == nil or character:FindFirstChildWhichIsA("ForceField") ~= nil then
		return false
	end

	return true
end

function DamageService.apply(
	source: Player,
	target: Player,
	humanoid: Humanoid,
	amount: number,
	weaponId: string
): number
	if humanoid.Health <= 0 or amount <= 0 then
		return 0
	end

	if not DamageService.canDamage(source, target) then
		return 0
	end

	local applied = math.min(humanoid.Health, amount)

	humanoid:TakeDamage(applied)
	damagedEvent:Fire(source, target, applied, weaponId)

	if humanoid.Health <= 0 then
		killedEvent:Fire(source, target, weaponId)
	end

	return applied
end

return DamageService
