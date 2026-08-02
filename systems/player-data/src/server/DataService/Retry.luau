--!strict

export type Options = {
	attempts: number,
	baseDelay: number,
	maxDelay: number,
	label: string,
}

type Fatal = {
	fatal: boolean,
	message: string,
}

local Retry = {}

function Retry.fatal(message: string)
	error({ fatal = true, message = message }, 0)
end

function Retry.attempt<T>(options: Options, action: () -> T): (boolean, T?, string?)
	local lastMessage: string? = nil

	for tries = 1, options.attempts do
		local ok, result = pcall(action)

		if ok then
			return true, result, nil
		end

		if typeof(result) == "table" and (result :: Fatal).fatal then
			return false, nil, (result :: Fatal).message
		end

		lastMessage = tostring(result)
		warn(`[{options.label}] attempt {tries} of {options.attempts} failed: {lastMessage}`)

		if tries < options.attempts then
			local backoff = math.min(options.maxDelay, options.baseDelay * 2 ^ (tries - 1))
			task.wait(backoff * (0.75 + math.random() * 0.5))
		end
	end

	return false, nil, lastMessage
end

return Retry
