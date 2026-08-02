# Applications

Files in this folder are written for skill role applications, not as part of the portfolio
showcases in [`systems/`](../systems). They follow different rules on purpose: one file, no
`require` on anything else, and comments in the source, because that is what the application
asks for.

## BallisticTurretRange.server.luau

A self-contained server `Script`. Drop it into `ServerScriptService` and press play; it builds
its own turrets, targets, tracers, control pad and readout at runtime and needs nothing else in
the place.

What it demonstrates:

| Area | Where |
| --- | --- |
| CFrame math | `beamCFrame`, barrel orientation with `CFrame.lookAt`, cylinder roll on the turret base |
| Physics | quadratic drag, gravity and wind integrated on a fixed timestep with semi-implicit Euler |
| Metatables | `Spring`, `TracerPool`, `Projectile`, `Target` and `Turret` are metatable classes with `typeof(setmetatable(...))` types |
| Roblox API | `Workspace:Raycast` with a reused `RaycastParams`, `RunService.Heartbeat`, `ClickDetector`, `SurfaceGui`, `Players` character tracking |
| Optimisation | tracer part pooling, swap removal, cached hit lookup table, readout written only on change |

Roughly 450 lines of code and 165 lines of comments.

**Demo place:**[ _(Demo Place)_]([https://create.roblox.com/dashboard/creations/experiences/10619251603/configure](https://www.roblox.com/games/132371824335861/Preview))
