--!strict

local Types = require(script.Parent.Types)

local SessionLock = {}

function SessionLock.stamp(jobId: string): Types.Lock
	return {
		jobId = jobId,
		placeId = game.PlaceId,
		heartbeat = os.time(),
	}
end

function SessionLock.isOwnedBy(lock: Types.Lock?, jobId: string): boolean
	return lock ~= nil and lock.jobId == jobId
end

function SessionLock.isExpired(lock: Types.Lock?, now: number, timeout: number): boolean
	if lock == nil then
		return true
	end

	return now - lock.heartbeat >= timeout
end

function SessionLock.blocks(lock: Types.Lock?, jobId: string, now: number, timeout: number): boolean
	if lock == nil or lock.jobId == jobId then
		return false
	end

	return not SessionLock.isExpired(lock, now, timeout)
end

return SessionLock
