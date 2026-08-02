--!strict

export type Rarity = "Common" | "Uncommon" | "Legendary"

export type PetDefinition = {
	id: string,
	displayName: string,
	rarity: Rarity,
	weight: number,
	model: string,
}

export type RollResult = {
	petId: string,
	rarity: Rarity,
	chance: number,
	luck: number,
	rollNumber: number,
}

export type RejectionCode = "Cooldown" | "NotReady" | "Disabled"

export type RollRejection = {
	code: RejectionCode,
	retryAfter: number,
}

export type RollResponse = {
	ok: true,
	result: RollResult,
} | {
	ok: false,
	rejection: RollRejection,
}

return {}
