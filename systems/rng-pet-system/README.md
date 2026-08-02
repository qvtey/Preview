# RNG Pet System

A weighted pet roll with three pets and a luck stat. The roll happens on the server, the client only asks for it and renders the answer.

Three pets keep the example readable. Adding a fourth one is a single line in `PetRegistry`, nothing else changes.

## Odds

Weights are integers, not percentages. Percentages drift the moment you add a pet, integer weights do not.

| Pet | Rarity | Weight | Chance at luck 1 |
| --- | --- | ---: | ---: |
| Rabbit | Common | 8000 | 80.00 % |
| Dog | Uncommon | 1990 | 19.90 % |
| Turtle | Legendary | 10 | 0.10 % (1 in 1000) |

## Luck

Luck does not shift every pet by the same factor. Each rarity has an influence value that says how much luck is allowed to touch it:

```
effectiveWeight = weight * (1 + (luck - 1) * influence)
```

| Rarity | Influence |
| --- | ---: |
| Common | 0.00 |
| Uncommon | 0.35 |
| Legendary | 1.00 |

Common stays at its base weight forever. Everything else grows and pushes Common down through renormalisation, so a luck potion feels good without ever making the Turtle common.

| Luck | Rabbit | Dog | Turtle |
| ---: | ---: | ---: | ---: |
| 1 | 80.00 % | 19.90 % | 0.100 % (1 in 1000) |
| 2 | 74.72 % | 25.09 % | 0.187 % (1 in 535) |
| 5 | 62.37 % | 37.24 % | 0.390 % (1 in 257) |
| 10 | 48.90 % | 50.48 % | 0.611 % (1 in 164) |

Luck is clamped to the range 1 to 10 in `LuckCurve.clamp`, including a NaN check. A NaN weight silently poisons the cumulative table and makes every roll return the same pet, which is the kind of bug you only find in production.

## How a roll is picked

`WeightedPool` builds a cumulative weight table once and samples it with a binary search, so a roll is `O(log n)` instead of walking the list every time. That does not matter for three pets. It matters when a client asks for 200 pets and the roll button is spammable.

The pool for a given luck value is built once and cached. Luck is quantised to two decimals before it is used as a cache key, otherwise a float from a gamepass multiplier creates a fresh pool per player per roll.

Every player gets their own `Random` object. A shared generator means two players rolling in the same frame can be correlated, and `math.random` is a global that anything in the place can reseed.

## Request path

1. Client presses E, `RollController.request()` throttles locally and fires `PetRollRequest`.
2. Server receives the event and ignores every argument the client sent. A roll request carries intent, not data.
3. `RollService.roll` checks the token bucket, samples the pool, increments the roll counter and fires `RollService.rolled`.
4. Server replies on `PetRollResult` with a tagged response, either `{ ok = true, result = ... }` or `{ ok = false, rejection = ... }`.
5. Client raises `RollController.rolled` or `RollController.rejected` for the UI layer.

Both directions are `RemoteEvent`s. A `RemoteFunction` would force the caller to sit on a thread waiting for an answer, and it makes it awkward to push a result the client never asked for, for example a pet granted by a code or an admin command.

## Rate limiting

`RateLimiter` is a token bucket, 5 tokens with 3 refilling per second. A burst of clicks goes through instantly, a held autoclicker settles at 3 per second. A flat debounce cannot do both.

The rejection carries `retryAfter` in seconds so the UI can grey the button out for exactly that long instead of guessing.

## Wiring it into a game

The service does not know what an inventory is. It announces rolls and something else decides what that means:

```lua
local RollService = require(ServerScriptService.PetSystemServer.RollService)

RollService.rolled:Connect(function(player, result)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local owned = profile.data.pets.owned
	owned[result.petId] = (owned[result.petId] or 0) + 1
	profile.data.stats.rolls = result.rollNumber
	profile:markDirty()
end)
```

Luck comes from the same direction, whatever the source is:

```lua
RollService.setLuck(player, 2.5)
```

On the client the controller is the only thing the UI has to know about:

```lua
local RollController = require(script.Parent.PetSystemClient.RollController)

RollController.rolled:Connect(function(result)
	if result.rarity == "Legendary" then
		playBigReveal(result.petId)
	end
end)
```

## What the client cannot do

- It cannot pick a pet. It has no say in the outcome at all.
- It cannot pass a luck value. Luck lives in a server table.
- It cannot skip the rate limit. The limiter runs before the sample.
- The local throttle in `RollController` exists to keep the remote quiet, not to protect anything. It is the first thing an exploiter deletes and that is fine.

## Left out on purpose

- No UI. The controller exposes two signals and stops there, because the pet reveal animation is the part every client wants built their way.
- No pet models. `PetRegistry` stores a model name, resolving it to an instance belongs to the asset pipeline of the actual game.
- No inventory or persistence. That is the `player-data` system in this repo.
- No pity counter. It is roughly ten lines on top of `rollNumber` but it changes the maths of the table above, and I would rather show honest odds.

## Files

| File | Role |
| --- | --- |
| `src/shared/Types.luau` | Shared type definitions, including the tagged roll response |
| `src/shared/PetRegistry.luau` | Pet definitions, frozen and validated at require time |
| `src/shared/WeightedPool.luau` | Generic weighted sampler, cumulative table plus binary search |
| `src/shared/LuckCurve.luau` | Luck clamping and per rarity weight scaling |
| `src/shared/Remotes.luau` | Creates remotes on the server, waits for them on the client |
| `src/server/RollService.luau` | Roll logic, pool cache, per player generators, luck state |
| `src/server/RateLimiter.luau` | Token bucket keyed by user id |
| `src/server/init.server.luau` | Player binding and remote plumbing |
| `src/client/RollController.luau` | Request throttle and signal surface for the UI |
| `src/client/init.client.luau` | Input binding for keyboard, gamepad and touch |
