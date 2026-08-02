--!strict

local Config = require(script.Parent.Config)
local Store = require(script.Parent.Store)
local Types = require(script.Parent.Types)

local function build(player: Player, key: string, data: Types.PlayerData): Types.Profile
	local releasedEvent = Instance.new("BindableEvent")
	local active = true
	local dirty = false
	local lastCommit = os.clock()

	local profile: Types.Profile
	profile = {
		player = player,
		key = key,
		data = data,
		released = releasedEvent.Event,

		isActive = function()
			return active
		end,

		isDirty = function()
			return dirty
		end,

		markDirty = function()
			dirty = true
		end,

		secondsSinceCommit = function()
			return os.clock() - lastCommit
		end,

		save = function(_, force)
			if not active then
				return false
			end

			if not force and os.clock() - lastCommit < Config.minSaveInterval then
				return false
			end

			lastCommit = os.clock()
			dirty = false

			local ok, message, lockLost = Store.commit(key, data, false)

			if ok then
				return true
			end

			dirty = true
			warn(`[DataService] save failed for {player.Name}: {message}`)

			if lockLost then
				active = false
				releasedEvent:Fire(false)
			end

			return false
		end,

		release = function()
			if not active then
				return
			end

			active = false
			lastCommit = os.clock()

			local ok, message = Store.commit(key, data, true)

			if not ok then
				warn(`[DataService] final save failed for {player.Name}: {message}`)
			end

			releasedEvent:Fire(ok)
		end,
	}

	return table.freeze(profile)
end

return {
	new = build,
}
