--!strict

export type SpreadConfig = {
	hip: number,
	aim: number,
	perShot: number,
	decay: number,
	max: number,
}

export type RecoilConfig = {
	vertical: number,
	horizontal: number,
	stiffness: number,
	damping: number,
}

export type WeaponConfig = {
	id: string,
	displayName: string,
	automatic: boolean,
	roundsPerMinute: number,
	damage: number,
	headshotMultiplier: number,
	range: number,
	falloffStart: number,
	falloffEnd: number,
	falloffFloor: number,
	magazineSize: number,
	reserveAmmo: number,
	reloadTime: number,
	spread: SpreadConfig,
	recoil: RecoilConfig,
}

export type FirePacket = {
	weaponId: string,
	origin: Vector3,
	aim: Vector3,
	aiming: boolean,
}

export type TracerPacket = {
	shooter: Player,
	origin: Vector3,
	position: Vector3,
}

export type ShotReport = {
	origin: Vector3,
	position: Vector3,
	hit: boolean,
	headshot: boolean,
	damage: number,
	magazine: number,
}

export type AmmoReport = {
	weaponId: string,
	magazine: number,
	reserve: number,
	reloading: boolean,
	reloadTime: number,
}

return {}
