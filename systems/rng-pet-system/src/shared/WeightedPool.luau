--!strict

export type Entry<T> = {
	value: T,
	weight: number,
}

export type Pool<T> = {
	total: number,
	sample: (self: Pool<T>, random: Random) -> T,
	chanceOf: (self: Pool<T>, value: T) -> number,
}

local function build<T>(entries: { Entry<T> }): Pool<T>
	assert(#entries > 0, "a weighted pool needs at least one entry")

	local values: { T } = table.create(#entries)
	local weights: { number } = table.create(#entries)
	local cumulative: { number } = table.create(#entries)
	local total = 0

	for index, entry in entries do
		assert(entry.weight > 0, "weights must be above zero")

		total += entry.weight
		values[index] = entry.value
		weights[index] = entry.weight
		cumulative[index] = total
	end

	local function lowerBound(target: number): number
		local low, high = 1, #cumulative

		while low < high do
			local middle = (low + high) // 2
			if cumulative[middle] < target then
				low = middle + 1
			else
				high = middle
			end
		end

		return low
	end

	local pool: Pool<T>
	pool = {
		total = total,

		sample = function(_, random)
			return values[lowerBound(random:NextNumber() * total)]
		end,

		chanceOf = function(_, value)
			for index, candidate in values do
				if candidate == value then
					return weights[index] / total
				end
			end

			return 0
		end,
	}

	return table.freeze(pool)
end

return {
	new = build,
}
