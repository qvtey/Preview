--!strict

local Players = game:GetService("Players")

local Rewind = require(script.Parent.Rewind)

export type Hit = {
	player: Player,
	humanoid: Humanoid,
	position: Vector3,
	distance: number,
	headshot: boolean,
}

local HEAD_SIZE = Vector3.new(1.6, 1.6, 1.6)
local BODY_SIZE = Vector3.new(2.4, 4.2, 1.8)
local BODY_OFFSET = CFrame.new(0, 0.1, 0)
local WALL_EPSILON = 0.25

local HitDetection = {}

local function slab(origin: number, direction: number, half: number, near: number, far: number): (number, number)
	if math.abs(direction) < 1e-6 then
		if math.abs(origin) > half then
			return 1, -1
		end

		return near, far
	end

	local inverse = 1 / direction
	local first = (-half - origin) * inverse
	local second = (half - origin) * inverse

	if first > second then
		first, second = second, first
	end

	return math.max(near, first), math.min(far, second)
end

local function rayBox(origin: Vector3, direction: Vector3, frame: CFrame, size: Vector3): number?
	local localOrigin = frame:PointToObjectSpace(origin)
	local localDirection = frame:VectorToObjectSpace(direction)
	local half = size * 0.5

	local near, far = 0, math.huge

	near, far = slab(localOrigin.X, localDirection.X, half.X, near, far)
	near, far = slab(localOrigin.Y, localDirection.Y, half.Y, near, far)
	near, far = slab(localOrigin.Z, localDirection.Z, half.Z, near, far)

	if near > far then
		return nil
	end

	return near
end

local function characterFilter(): { Instance }
	local filter: { Instance } = {}

	for _, player in Players:GetPlayers() do
		local character = player.Character

		if character then
			table.insert(filter, character)
		end
	end

	return filter
end

function HitDetection.cast(shooter: Player, origin: Vector3, direction: Vector3, range: number, timestamp: number): Hit?
	local closest: Hit? = nil

	for _, player in Players:GetPlayers() do
		if player == shooter then
			continue
		end

		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil

		if humanoid == nil or humanoid.Health <= 0 then
			continue
		end

		local snapshot = Rewind.at(player, timestamp)

		if snapshot == nil then
			continue
		end

		local toHead = rayBox(origin, direction, snapshot.head, HEAD_SIZE)
		local toBody = rayBox(origin, direction, snapshot.root * BODY_OFFSET, BODY_SIZE)

		local distance: number
		local headshot: boolean

		if toHead ~= nil and (toBody == nil or toHead <= toBody) then
			distance, headshot = toHead, true
		elseif toBody ~= nil then
			distance, headshot = toBody, false
		else
			continue
		end

		if distance > range then
			continue
		end

		if closest ~= nil and closest.distance <= distance then
			continue
		end

		closest = {
			player = player,
			humanoid = humanoid,
			position = origin + direction * distance,
			distance = distance,
			headshot = headshot,
		}
	end

	return closest
end

function HitDetection.isBlocked(from: Vector3, to: Vector3): boolean
	local offset = to - from
	local distance = offset.Magnitude

	if distance <= WALL_EPSILON then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characterFilter()
	params.IgnoreWater = true

	local result = workspace:Raycast(from, offset, params)

	return result ~= nil and result.Distance < distance - WALL_EPSILON
end

function HitDetection.castWorld(origin: Vector3, direction: Vector3, range: number): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characterFilter()
	params.IgnoreWater = true

	return workspace:Raycast(origin, direction * range, params)
end

return HitDetection
