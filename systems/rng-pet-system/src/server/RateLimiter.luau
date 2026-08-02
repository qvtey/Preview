--!strict

export type Bucket = {
	take: (self: Bucket, key: string) -> boolean,
	retryAfter: (self: Bucket, key: string) -> number,
	forget: (self: Bucket, key: string) -> (),
}

local function build(capacity: number, refillPerSecond: number): Bucket
	assert(capacity > 0 and refillPerSecond > 0, "a bucket needs a positive capacity and refill rate")

	local tokens: { [string]: number } = {}
	local stamps: { [string]: number } = {}

	local function refresh(key: string): number
		local now = os.clock()
		local last = stamps[key]
		local available = tokens[key]

		if last == nil or available == nil then
			tokens[key] = capacity
			stamps[key] = now

			return capacity
		end

		available = math.min(capacity, available + (now - last) * refillPerSecond)
		tokens[key] = available
		stamps[key] = now

		return available
	end

	local bucket: Bucket
	bucket = {
		take = function(_, key)
			local available = refresh(key)
			if available < 1 then
				return false
			end

			tokens[key] = available - 1

			return true
		end,

		retryAfter = function(_, key)
			local missing = 1 - refresh(key)
			if missing <= 0 then
				return 0
			end

			return missing / refillPerSecond
		end,

		forget = function(_, key)
			tokens[key] = nil
			stamps[key] = nil
		end,
	}

	return table.freeze(bucket)
end

return {
	new = build,
}
