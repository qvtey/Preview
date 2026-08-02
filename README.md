# Portfolio Projects

Hey, I am **qvtey**. I am a Roblox programmer and this is my portfolio preview.

Everything I build for a client is written for their game and stays with them, so there is nothing in here that I sold to someone. Instead I rebuilt three systems from scratch that show how I actually work: how I lay out a module tree, where I put the line between client and server, and what I do when a DataStore call fails at three in the morning.

These are showcases, not products. They are complete enough to drop into a place and run, and small enough that you can read one in ten minutes and know whether you want me on your project.

## Systems

| System | What it shows |
| --- | --- |
| [RNG Pet System](systems/rng-pet-system) | Weighted rolling with cached pools, a luck curve that only touches rare items, server authoritative results, token bucket rate limiting |
| [Player Data](systems/player-data) | Session locked DataStore access, schema migrations, retries with jittered backoff, safe shutdown, a Studio fallback backend |
| [Gun System](systems/gun-system) | Server side hit registration on rewound positions, ray against oriented boxes, ammo authority, spring recoil, unreliable remotes for effects |

Each folder has its own README with the numbers, the data flow, and the parts I deliberately left out.

## How I write this stuff

- **Luau in strict mode.** Every file starts with `--!strict`. Public types live in a `Types` module next to the code that uses them.
- **No comments in the source.** If something needs explaining, the explanation goes in the README where it can hold a table, a diagram and real numbers, and where it cannot silently rot two refactors later. Code that needs a comment to be readable usually needs a better name instead.
- **Side effects at the edges.** Remotes, DataStores and `Players` stay in the outer layer. The logic in the middle takes plain values and returns plain values, which is what makes it testable.
- **Config in one frozen table.** Every timing constant, weight and message sits in one place per system, with `table.freeze` on top so nothing rewrites it at runtime.
- **Nothing from the client is trusted.** A client request carries intent, never a result.
- **Honest limits.** Every README has a section for what the system does not do. A showcase that claims to handle everything is a showcase nobody can review.

## Running one

Each system has its own Rojo project and does not depend on the others.

```bash
rojo serve systems/gun-system/default.project.json
```

Then connect from Studio with the Rojo plugin and press play. The tool versions I use are pinned in `rokit.toml`:

```bash
rokit install
```

`player-data` runs in Studio without API access enabled. It detects that and swaps to an in memory backend that implements the same interface, so a playtest exercises the same load, save and shutdown paths.

## What is next in here

I add a system when I have written something worth showing rather than on a schedule. Likely candidates are a replication layer for player state, a round based match loop, and a shop with receipt handling.

## Contact

Open an issue on this repo, or reach me on Discord as **qvtey**. If you are hiring for a specific system, tell me what the game needs to do and I will tell you how I would build it before you pay me anything.
