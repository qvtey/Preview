--!strict

local Reconcile = {}

function Reconcile.copy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end

	local clone = {}

	for key, entry in value do
		clone[key] = Reconcile.copy(entry)
	end

	return clone
end

function Reconcile.fill(target: { [any]: any }, template: { [any]: any }): number
	local changes = 0

	for key, value in template do
		local current = target[key]

		if typeof(value) == "table" then
			if typeof(current) == "table" then
				changes += Reconcile.fill(current, value)
			else
				target[key] = Reconcile.copy(value)
				changes += 1
			end
		elseif current == nil or typeof(current) ~= typeof(value) then
			target[key] = value
			changes += 1
		end
	end

	return changes
end

return Reconcile
