--!strict

local Players = game:GetService("Players")

local Config = require(script.Config)
local Migrations = require(script.Migrations)
local Mirror = require(script.Mirror)
local Profile = require(script.Profile)
local Reconcile = require(script.Reconcile)
local Schema = require(script.Schema)
local Store = require(script.Store)
local Types = require(script.Types)

local profiles: { [Player]: Types.Profile } = {}
local loading: { [Player]: boolean } = {}
local loadedEvent = Instance.new("BindableEvent")
local started = false

local DataService = {}

DataService.loaded = loadedEvent.Event

function DataService.get(player: Player): Types.Profile?
	return profiles[player]
end

function DataService.await(player: Player, timeout: number?): Types.Profile?
	local deadline = os.clock() + (timeout or Config.loadTimeout)

	while profiles[player] == nil and os.clock() < deadline do
		if not player:IsDescendantOf(Players) then
			return nil
		end

		task.wait(0.1)
	end

	return profiles[player]
end

function DataService.all(): { [Player]: Types.Profile }
	return table.clone(profiles)
end

local function unload(player: Player)
	local profile = profiles[player]

	if profile then
		profile:release()
	end
end

local function load(player: Player)
	if loading[player] or profiles[player] then
		return
	end

	loading[player] = true

	local key = Config.keyPrefix .. player.UserId
	local ok, record, message, blocked = Store.acquire(key)

	loading[player] = nil

	if not player:IsDescendantOf(Players) then
		if ok and record then
			Store.commit(key, record.data, true)
		end

		return
	end

	if not ok or record == nil then
		warn(`[DataService] load failed for {player.Name} ({player.UserId}): {message}`)
		player:Kick(if blocked then Config.kickMessages.locked else Config.kickMessages.load)

		return
	end

	local data = record.data
	local storedVersion = tonumber(data.schemaVersion) or record.version

	if storedVersion > Schema.VERSION then
		Store.commit(key, data, true)
		player:Kick(Config.kickMessages.newerVersion)

		return
	end

	local reached, applied = Migrations.run(data, storedVersion)

	if applied > 0 then
		print(`[DataService] migrated {player.Name} from schema {storedVersion} to {reached}`)
	end

	if reached < Schema.VERSION then
		warn(`[DataService] {player.Name} stopped at schema {reached}, expected {Schema.VERSION}`)
	end

	Reconcile.fill(data, Schema.template())
	data.schemaVersion = Schema.VERSION

	local profile = Profile.new(player, key, data)
	profiles[player] = profile

	profile.released:Connect(function(saved: boolean)
		if profiles[player] == profile then
			profiles[player] = nil
		end

		Mirror.clear(player)

		if not saved and player:IsDescendantOf(Players) then
			player:Kick(Config.kickMessages.lost)
		end
	end)

	Mirror.push(player, profile.data)
	loadedEvent:Fire(player, profile)
end

local function autosaveLoop()
	while true do
		task.wait(Config.autosaveInterval + math.random() * Config.autosaveJitter)

		local pending: { Types.Profile } = {}

		for _, profile in profiles do
			local stale = profile:secondsSinceCommit() >= Config.heartbeatInterval

			if profile:isActive() and (profile:isDirty() or stale) then
				table.insert(pending, profile)
			end
		end

		for _, profile in pending do
			task.spawn(function()
				if profile:save() then
					Mirror.push(profile.player, profile.data)
				end
			end)
		end
	end
end

local function shutdown()
	local pending: { Types.Profile } = {}

	for _, profile in profiles do
		table.insert(pending, profile)
	end

	if #pending == 0 then
		return
	end

	local finished = 0

	for _, profile in pending do
		task.spawn(function()
			profile:release()
			finished += 1
		end)
	end

	local deadline = os.clock() + Config.shutdownTimeout

	while finished < #pending and os.clock() < deadline do
		task.wait(0.1)
	end

	if finished < #pending then
		warn(`[DataService] shutdown ran out of time with {#pending - finished} profiles still saving`)
	end
end

function DataService.start()
	if started then
		return
	end

	started = true

	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)

	Players.PlayerRemoving:Connect(unload)

	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	task.spawn(autosaveLoop)
	game:BindToClose(shutdown)
end

return DataService
