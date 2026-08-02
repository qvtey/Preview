--!strict

local RunService = game:GetService("RunService")

local POOL_SIZE = 32
local TRACER_LIFETIME = 0.05
local IMPACT_LIFETIME = 0.14
local TRACER_WIDTH = 0.08
local TRACER_TRANSPARENCY = 0.2
local IMPACT_SIZE = Vector3.new(0.28, 0.28, 0.28)

type Slot = {
	part: BasePart,
	expiry: number,
}

local folder = Instance.new("Folder")
folder.Name = "GunSystemEffects"
folder.Parent = workspace

local free: { BasePart } = {}
local busy: { Slot } = {}

for _ = 1, POOL_SIZE do
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Locked = true
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 226, 148)
	part.Transparency = 1
	part.Size = Vector3.one
	part.Parent = folder

	table.insert(free, part)
end

local function acquire(): BasePart?
	return table.remove(free)
end

local function hold(part: BasePart, lifetime: number)
	table.insert(busy, {
		part = part,
		expiry = os.clock() + lifetime,
	})
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()

	for index = #busy, 1, -1 do
		local slot = busy[index]

		if now >= slot.expiry then
			slot.part.Transparency = 1
			table.insert(free, slot.part)
			table.remove(busy, index)
		end
	end
end)

local TracerEmitter = {}

function TracerEmitter.tracer(from: Vector3, to: Vector3)
	local offset = to - from
	local distance = offset.Magnitude

	if distance < 0.5 then
		return
	end

	local part = acquire()

	if part == nil then
		return
	end

	part.Size = Vector3.new(TRACER_WIDTH, TRACER_WIDTH, distance)
	part.CFrame = CFrame.lookAt(from + offset * 0.5, to)
	part.Transparency = TRACER_TRANSPARENCY

	hold(part, TRACER_LIFETIME)
end

function TracerEmitter.impact(position: Vector3)
	local part = acquire()

	if part == nil then
		return
	end

	part.Size = IMPACT_SIZE
	part.CFrame = CFrame.new(position)
	part.Transparency = 0.35

	hold(part, IMPACT_LIFETIME)
end

return TracerEmitter
