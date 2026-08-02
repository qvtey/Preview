--!strict

local Schema = require(script.Parent.Schema)

export type PlayerData = Schema.PlayerData

export type Lock = {
	jobId: string,
	placeId: number,
	heartbeat: number,
}

export type Meta = {
	created: number,
	updated: number,
	saves: number,
	placeVersion: number,
}

export type Record = {
	version: number,
	data: any,
	lock: Lock?,
	meta: Meta,
}

export type Backend = {
	update: (key: string, transform: (Record?) -> Record?) -> Record?,
}

export type Profile = {
	player: Player,
	key: string,
	data: PlayerData,
	released: RBXScriptSignal,
	isActive: (self: Profile) -> boolean,
	isDirty: (self: Profile) -> boolean,
	markDirty: (self: Profile) -> (),
	secondsSinceCommit: (self: Profile) -> number,
	save: (self: Profile, force: boolean?) -> boolean,
	release: (self: Profile) -> (),
}

return {}
