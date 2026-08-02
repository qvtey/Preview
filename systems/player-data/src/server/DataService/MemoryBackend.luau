--!strict

local Reconcile = require(script.Parent.Reconcile)
local Types = require(script.Parent.Types)

local SIMULATED_LATENCY = 0.05

local function build(): Types.Backend
	local storage: { [string]: Types.Record } = {}

	return table.freeze({
		update = function(key: string, transform: (Types.Record?) -> Types.Record?): Types.Record?
			task.wait(SIMULATED_LATENCY)

			local current = storage[key]
			local result = transform(if current then Reconcile.copy(current) else nil)

			if result == nil then
				return current
			end

			storage[key] = Reconcile.copy(result)

			return result
		end,
	})
end

return {
	new = build,
}
