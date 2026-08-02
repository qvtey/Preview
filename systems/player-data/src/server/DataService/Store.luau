--!strict

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local MemoryBackend = require(script.Parent.MemoryBackend)
local Retry = require(script.Parent.Retry)
local Schema = require(script.Parent.Schema)
local SessionLock = require(script.Parent.SessionLock)
local Types = require(script.Parent.Types)

type Record = Types.Record

local JOB_ID = if game.JobId ~= "" then game.JobId else `studio-{os.time()}`

local backend: Types.Backend? = nil

local Store = {}

Store.jobId = JOB_ID

local function blankRecord(): Record
	local now = os.time()

	return {
		version = Schema.VERSION,
		data = Schema.template(),
		lock = nil,
		meta = {
			created = now,
			updated = now,
			saves = 0,
			placeVersion = game.PlaceVersion,
		},
	}
end

local function normalise(stored: Record): Record
	local record = stored

	if typeof(record.data) ~= "table" then
		record.data = Schema.template()
	end

	if typeof(record.meta) ~= "table" then
		local now = os.time()
		record.meta = {
			created = now,
			updated = now,
			saves = 0,
			placeVersion = game.PlaceVersion,
		}
	end

	record.version = tonumber(record.version) or 1

	return record
end

local function apiAccessEnabled(): boolean
	local ok = pcall(function()
		DataStoreService:GetDataStore("DataServiceProbe"):GetAsync("probe")
	end)

	return ok
end

local function liveBackend(): Types.Backend
	local dataStore = DataStoreService:GetDataStore(Config.storeName, Config.storeScope)

	return table.freeze({
		update = function(key: string, transform: (Record?) -> Record?): Record?
			return dataStore:UpdateAsync(key, transform) :: Record?
		end,
	})
end

local function resolveBackend(): Types.Backend
	local current = backend

	if current then
		return current
	end

	local created: Types.Backend

	if Config.forceMemoryBackend or (RunService:IsStudio() and not apiAccessEnabled()) then
		warn("[DataService] using the in memory backend, nothing written here survives the session")
		created = MemoryBackend.new()
	else
		created = liveBackend()
	end

	backend = created

	return created
end

local function waitForBudget()
	if RunService:IsStudio() then
		return
	end

	local deadline = os.clock() + Config.budgetTimeout

	while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync) < 1 do
		if os.clock() >= deadline then
			return
		end

		task.wait(1)
	end
end

function Store.useBackend(replacement: Types.Backend)
	backend = replacement
end

function Store.acquire(key: string): (boolean, Record?, string?, boolean)
	local lastAttemptBlocked = false

	local ok, record, message = Retry.attempt(Config.loadRetry, function(): Record
		waitForBudget()

		local blocked = false
		local captured: Record? = nil

		resolveBackend().update(key, function(stored: Record?): Record?
			local current = if stored then normalise(stored) else blankRecord()

			if SessionLock.blocks(current.lock, JOB_ID, os.time(), Config.lockTimeout) then
				blocked = true
				return nil
			end

			current.lock = SessionLock.stamp(JOB_ID)
			captured = current

			return current
		end)

		lastAttemptBlocked = blocked

		if blocked then
			error("the profile is locked by another server", 0)
		end

		return assert(captured, "UpdateAsync returned without running the transform")
	end)

	return ok, record, message, lastAttemptBlocked
end

function Store.commit(key: string, data: any, releaseLock: boolean): (boolean, string?, boolean)
	local lockLost = false

	local ok, _, message = Retry.attempt(Config.saveRetry, function(): boolean
		waitForBudget()

		local lost = false

		resolveBackend().update(key, function(stored: Record?): Record?
			local record = if stored then normalise(stored) else blankRecord()

			if not SessionLock.isOwnedBy(record.lock, JOB_ID) then
				lost = true
				return nil
			end

			record.data = data
			record.version = Schema.VERSION
			record.meta.updated = os.time()
			record.meta.saves += 1
			record.meta.placeVersion = game.PlaceVersion
			record.lock = if releaseLock then nil else SessionLock.stamp(JOB_ID)

			return record
		end)

		if lost then
			lockLost = true
			Retry.fatal("the session lock was taken over by another server")
		end

		return true
	end)

	return ok, message, lockLost
end

return Store
