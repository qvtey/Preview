--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Ballistics = require(GunSystem:WaitForChild("Ballistics"))
local Remotes = require(GunSystem:WaitForChild("Remotes"))
local Types = require(GunSystem:WaitForChild("Types"))
local WeaponConfig = require(GunSystem:WaitForChild("WeaponConfig"))

local RecoilSpring = require(script.Parent:WaitForChild("RecoilSpring"))
local TracerEmitter = require(script.Parent:WaitForChild("TracerEmitter"))

local RECOIL_BINDING = "GunSystemRecoil"

local player = Players.LocalPlayer

local fireRemote = Remotes.event(Remotes.FIRE)
local reloadRemote = Remotes.event(Remotes.RELOAD)
local equipRemote = Remotes.event(Remotes.EQUIP)
local shotRemote = Remotes.event(Remotes.SHOT)
local ammoRemote = Remotes.event(Remotes.AMMO)
local tracerRemote = Remotes.unreliable(Remotes.TRACER)

local ammoEvent = Instance.new("BindableEvent")
local random = Random.new()

local config: Types.WeaponConfig? = nil
local spring = RecoilSpring.new(90, 14)
local magazine = 0
local reserve = 0
local reloading = false
local bloom = 0
local lastShot = 0
local firing = false
local aiming = false
local started = false

local WeaponController = {}

WeaponController.ammoChanged = ammoEvent.Event

local function currentCamera(): Camera?
	return workspace.CurrentCamera
end

local function muzzlePosition(): Vector3?
	local character = player.Character

	if character == nil then
		return nil
	end

	local head = character:FindFirstChild("Head") :: BasePart?

	return if head then head.Position else nil
end

local function aimPoint(camera: Camera, range: number): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: any }
	params.IgnoreWater = true

	local frame = camera.CFrame
	local result = workspace:Raycast(frame.Position, frame.LookVector * range, params)

	return if result then result.Position else frame.Position + frame.LookVector * range
end

local function tracerEnd(origin: Vector3, direction: Vector3, range: number): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: any }
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, direction * range, params)

	return if result then result.Position else origin + direction * range
end

local function publishAmmo()
	local active = config

	ammoEvent:Fire({
		weaponId = if active then active.id else "",
		magazine = magazine,
		reserve = reserve,
		reloading = reloading,
		reloadTime = if active then active.reloadTime else 0,
	})
end

local function tryFire()
	local active = config

	if active == nil or reloading or magazine <= 0 then
		return
	end

	local now = os.clock()

	if now - lastShot < Ballistics.fireInterval(active) then
		return
	end

	local camera = currentCamera()
	local origin = muzzlePosition()

	if camera == nil or origin == nil then
		return
	end

	local offset = aimPoint(camera, active.range) - origin

	if offset.Magnitude < 0.1 then
		return
	end

	local aim = offset.Unit
	local angle = Ballistics.spreadAngle(active, bloom, aiming)
	local predicted = Ballistics.coneDirection(aim, angle, random)

	lastShot = now
	magazine -= 1
	bloom = Ballistics.bloomAfterShot(active, bloom)

	TracerEmitter.tracer(origin, tracerEnd(origin, predicted, active.range))

	spring:impulse(Vector2.new(
		(random:NextNumber() * 2 - 1) * active.recoil.horizontal,
		active.recoil.vertical
	))

	fireRemote:FireServer({
		weaponId = active.id,
		origin = origin,
		aim = aim,
		aiming = aiming,
	})

	publishAmmo()
end

function WeaponController.equip(weaponId: string)
	local requested = WeaponConfig.find(weaponId)

	if requested == nil or (config ~= nil and config.id == weaponId) then
		return
	end

	config = requested
	spring = RecoilSpring.new(requested.recoil.stiffness, requested.recoil.damping)
	bloom = 0
	firing = false

	equipRemote:FireServer(weaponId)
end

function WeaponController.setFiring(value: boolean)
	firing = value

	if value then
		tryFire()
	end
end

function WeaponController.setAiming(value: boolean)
	aiming = value
end

function WeaponController.reload()
	local active = config

	if active == nil or reloading or reserve <= 0 or magazine >= active.magazineSize then
		return
	end

	reloadRemote:FireServer()
end

function WeaponController.snapshot(): Types.AmmoReport
	local active = config

	return {
		weaponId = if active then active.id else "",
		magazine = magazine,
		reserve = reserve,
		reloading = reloading,
		reloadTime = if active then active.reloadTime else 0,
	}
end

function WeaponController.start()
	if started then
		return
	end

	started = true

	ammoRemote.OnClientEvent:Connect(function(report: Types.AmmoReport)
		if typeof(report) ~= "table" then
			return
		end

		local active = WeaponConfig.find(report.weaponId)

		if active == nil then
			return
		end

		if config == nil or config.id ~= active.id then
			config = active
			spring = RecoilSpring.new(active.recoil.stiffness, active.recoil.damping)
		end

		magazine = report.magazine
		reserve = report.reserve
		reloading = report.reloading

		publishAmmo()
	end)

	shotRemote.OnClientEvent:Connect(function(report: Types.ShotReport)
		if typeof(report) ~= "table" then
			return
		end

		magazine = report.magazine
		TracerEmitter.impact(report.position)
		publishAmmo()
	end)

	tracerRemote.OnClientEvent:Connect(function(packet: Types.TracerPacket)
		if typeof(packet) ~= "table" or packet.shooter == player then
			return
		end

		TracerEmitter.tracer(packet.origin, packet.position)
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		local active = config

		if active == nil then
			return
		end

		bloom = Ballistics.decayBloom(active, bloom, deltaTime)

		if firing and active.automatic then
			tryFire()
		end
	end)

	RunService:BindToRenderStep(RECOIL_BINDING, Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
		local camera = currentCamera()
		local offset = spring:step(deltaTime)

		if camera then
			camera.CFrame *= CFrame.Angles(math.rad(offset.Y), math.rad(offset.X), 0)
		end
	end)
end

return WeaponController
