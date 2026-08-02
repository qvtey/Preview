--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Ballistics = require(GunSystem:WaitForChild("Ballistics"))
local Remotes = require(GunSystem:WaitForChild("Remotes"))
local Types = require(GunSystem:WaitForChild("Types"))
local WeaponConfig = require(GunSystem:WaitForChild("WeaponConfig"))

local AmmoState = require(script.Parent:WaitForChild("AmmoState"))
local DamageService = require(script.Parent:WaitForChild("DamageService"))
local HitDetection = require(script.Parent:WaitForChild("HitDetection"))

local MAX_ORIGIN_OFFSET = 6
local MAX_REWIND = 0.25
local MAX_COORDINATE = 100000

local shotRemote = Remotes.event(Remotes.SHOT)
local ammoRemote = Remotes.event(Remotes.AMMO)
local tracerRemote = Remotes.unreliable(Remotes.TRACER)

local generators: { [Player]: Random } = {}

local FireHandler = {}

local function generatorFor(player: Player): Random
	local generator = generators[player]

	if generator == nil then
		generator = Random.new()
		generators[player] = generator
	end

	return generator
end

local function isSane(vector: Vector3): boolean
	local magnitude = vector.Magnitude

	return magnitude == magnitude and magnitude < MAX_COORDINATE
end

local function readPacket(payload: any): Types.FirePacket?
	if typeof(payload) ~= "table" then
		return nil
	end

	local weaponId = payload.weaponId
	local origin = payload.origin
	local aim = payload.aim

	if typeof(weaponId) ~= "string" or typeof(origin) ~= "Vector3" or typeof(aim) ~= "Vector3" then
		return nil
	end

	if not isSane(origin) or not isSane(aim) then
		return nil
	end

	local length = aim.Magnitude

	if length < 0.9 or length > 1.1 then
		return nil
	end

	return {
		weaponId = weaponId,
		origin = origin,
		aim = aim.Unit,
		aiming = payload.aiming == true,
	}
end

function FireHandler.pushAmmo(player: Player)
	local report = AmmoState.report(player)

	if report then
		ammoRemote:FireClient(player, report)
	end
end

function FireHandler.forget(player: Player)
	generators[player] = nil
end

function FireHandler.handle(player: Player, payload: any)
	local packet = readPacket(payload)

	if packet == nil then
		return
	end

	local state = AmmoState.get(player)

	if state == nil or state.weaponId ~= packet.weaponId then
		FireHandler.pushAmmo(player)
		return
	end

	local config = WeaponConfig.find(state.weaponId)
	local character = player.Character

	if config == nil or character == nil then
		return
	end

	local head = character:FindFirstChild("Head") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if head == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end

	if (packet.origin - head.Position).Magnitude > MAX_ORIGIN_OFFSET then
		return
	end

	local now = os.clock()
	local angle = AmmoState.consume(player, now, packet.aiming)

	if angle == nil then
		FireHandler.pushAmmo(player)
		return
	end

	local direction = Ballistics.coneDirection(packet.aim, angle, generatorFor(player))
	local rewindTo = now - math.clamp(player:GetNetworkPing(), 0, MAX_REWIND)
	local hit = HitDetection.cast(player, packet.origin, direction, config.range, rewindTo)

	local impact = packet.origin + direction * config.range
	local damage = 0
	local headshot = false

	if hit ~= nil and not HitDetection.isBlocked(head.Position, hit.position) then
		local amount = Ballistics.damageAt(config, hit.distance)

		if hit.headshot then
			amount *= config.headshotMultiplier
		end

		damage = DamageService.apply(player, hit.player, hit.humanoid, amount, config.id)
		headshot = hit.headshot
		impact = hit.position
	else
		local world = HitDetection.castWorld(packet.origin, direction, config.range)

		if world then
			impact = world.Position
		end
	end

	local report: Types.ShotReport = {
		origin = packet.origin,
		position = impact,
		hit = damage > 0,
		headshot = headshot and damage > 0,
		damage = damage,
		magazine = AmmoState.magazine(player),
	}

	shotRemote:FireClient(player, report)

	local tracer: Types.TracerPacket = {
		shooter = player,
		origin = packet.origin,
		position = impact,
	}

	for _, other in Players:GetPlayers() do
		if other ~= player then
			tracerRemote:FireClient(other, tracer)
		end
	end
end

function FireHandler.handleReload(player: Player)
	local token = AmmoState.beginReload(player)

	if token == nil then
		return
	end

	local state = AmmoState.get(player)
	local config = if state then WeaponConfig.find(state.weaponId) else nil

	if config == nil then
		return
	end

	FireHandler.pushAmmo(player)

	task.delay(config.reloadTime, function()
		if AmmoState.finishReload(player, token) then
			FireHandler.pushAmmo(player)
		end
	end)
end

function FireHandler.handleEquip(player: Player, weaponId: any)
	if typeof(weaponId) ~= "string" then
		return
	end

	if AmmoState.equip(player, weaponId) then
		FireHandler.pushAmmo(player)
	end
end

return FireHandler
