--!strict

return table.freeze({
	storeName = "PlayerData",
	storeScope = "live",
	keyPrefix = "player_",

	autosaveInterval = 60,
	autosaveJitter = 20,
	heartbeatInterval = 240,

	lockTimeout = 600,
	loadTimeout = 30,
	minSaveInterval = 7,
	budgetTimeout = 30,
	shutdownTimeout = 25,

	forceMemoryBackend = false,

	loadRetry = table.freeze({
		attempts = 5,
		baseDelay = 2,
		maxDelay = 20,
		label = "DataService/load",
	}),

	saveRetry = table.freeze({
		attempts = 3,
		baseDelay = 2,
		maxDelay = 10,
		label = "DataService/save",
	}),

	kickMessages = table.freeze({
		load = "We could not load your data. Please rejoin in a moment.",
		locked = "Your data is still being saved on another server. Please rejoin in about a minute.",
		newerVersion = "Your data was written by a newer version of this game. Please rejoin later.",
		lost = "Your session moved to another server. Please rejoin.",
	}),
})
