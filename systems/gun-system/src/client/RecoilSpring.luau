--!strict

export type Spring = {
	impulse: (self: Spring, amount: Vector2) -> (),
	step: (self: Spring, deltaTime: number) -> Vector2,
	reset: (self: Spring) -> (),
}

local MAX_STEP = 1 / 120
local MAX_FRAME = 0.1

local function build(stiffness: number, damping: number): Spring
	local position = Vector2.zero
	local velocity = Vector2.zero

	local spring: Spring
	spring = {
		impulse = function(_, amount)
			velocity += amount
		end,

		step = function(_, deltaTime)
			local remaining = math.min(deltaTime, MAX_FRAME)

			while remaining > 0 do
				local slice = math.min(remaining, MAX_STEP)
				local acceleration = -stiffness * position - damping * velocity

				velocity += acceleration * slice
				position += velocity * slice
				remaining -= slice
			end

			return position
		end,

		reset = function()
			position = Vector2.zero
			velocity = Vector2.zero
		end,
	}

	return table.freeze(spring)
end

return {
	new = build,
}
