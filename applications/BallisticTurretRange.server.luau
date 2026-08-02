-- Discord: qvtey | Roblox: vrtaex
--!strict
--[[
	BALLISTIC TURRET RANGE
	A single server Script that builds and runs a complete firing range at runtime.

	Why everything lives in one file and runs on the server:
	the range is meant to be readable top to bottom, and keeping simulation on the server
	means every player in the place watches the exact same shot instead of a client-side
	guess. Nothing here depends on pre-built instances in the place - the script creates
	its own targets, turrets and effects on start, so dropping it into ServerScriptService
	is the whole installation.

	How the pieces fit together:

		Heartbeat -> fixed timestep accumulator
			-> Target:step()      moves targets on an analytic sine path
			-> Turret:step()      springs the aim vector towards a lead solution, fires on cooldown
			-> Projectile:step()  integrates gravity + quadratic drag + wind, raycasts the
			                      segment it travelled this step, reports the hit back to the turret
			-> TracerPool         recycles the beam parts the projectiles leave behind

	The classes are plain Luau metatable classes (Spring, TracerPool, Projectile, Target,
	Turret). Each one owns its own state and exposes a small step/act interface, which is
	what keeps the main loop three lines long.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ============================================================================
-- 1. CONFIGURATION
-- Every tunable number sits in one frozen table. Frozen because a stray write to a
-- shared config is the kind of bug that only shows up an hour into a play session.
-- ============================================================================

local CONFIG = table.freeze({
	-- Simulation. Physics runs on a fixed step so behaviour does not change with framerate:
	-- a 30 fps server and a 60 fps server integrate the exact same trajectory.
	StepTime = 1 / 60,
	MaxStepsPerFrame = 4, -- ceiling on catch-up steps, so a lag spike cannot spiral

	-- Ballistics. Drag is quadratic (proportional to speed squared), which is what makes
	-- a fast round lose speed quickly and then settle into a lazy arc near the end.
	MuzzleVelocity = 220,
	Gravity = 96,
	DragCoefficient = 0.0022,
	ProjectileLifetime = 6,
	LeadIterations = 3, -- fixed-point passes for the intercept solve, see solveIntercept

	-- Turrets.
	TurretCount = 3,
	TurretSpacing = 18,
	FireInterval = 0.85,
	AimTolerance = 0.995, -- dot product the aim must reach before the turret is allowed to fire
	SpringStiffness = 180,
	SpringDamping = 26,

	-- Targets.
	TargetCount = 5,
	TargetSpacing = 14,
	TargetRange = 190,
	TargetHealth = 3,
	TargetRespawnDelay = 2.5,
	BobAmplitude = 11,
	BobFrequency = 0.9,

	-- Presentation.
	TracerWidth = 0.16,
	TracerFadeTime = 0.12,
	TracerPoolSize = 96,
	WindSpeed = 38, -- horizontal wind, toggled from the control pad
})

-- Colours kept apart from the numbers above; they are read once at build time.
local PALETTE = table.freeze({
	Steel = Color3.fromRGB(70, 78, 88),
	Tracer = Color3.fromRGB(255, 196, 94),
	TargetLive = Color3.fromRGB(96, 190, 120),
	TargetDead = Color3.fromRGB(60, 64, 70),
	Pad = Color3.fromRGB(200, 92, 78),
})

-- ============================================================================
-- 2. WORLD CONTAINERS AND RAYCAST FILTER
-- ============================================================================

-- One folder for things shots must ignore (turret bodies, tracers, player characters) and
-- one for things shots must hit (targets). Sorting instances by role at creation time means
-- the raycast filter is a single folder list instead of a per-cast rebuild.
local rangeFolder = Instance.new("Folder")
rangeFolder.Name = "BallisticRange"
rangeFolder.Parent = Workspace

local ignoreFolder = Instance.new("Folder")
ignoreFolder.Name = "Ignore"
ignoreFolder.Parent = rangeFolder

local targetFolder = Instance.new("Folder")
targetFolder.Name = "Targets"
targetFolder.Parent = rangeFolder

-- A single RaycastParams object, reused by every cast. Allocating one per shot is the
-- classic hidden cost in a gun system: it is cheap once and expensive sixty times a second.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.FilterDescendantsInstances = { ignoreFolder }

-- Character models are added to the ignore list as players spawn, so a player standing in
-- the lane watches the rounds pass through instead of soaking them.
local function watchCharacters(player: Player)
	local function ignoreCharacter(character: Model)
		local filter = rayParams.FilterDescendantsInstances
		table.insert(filter, character)
		rayParams.FilterDescendantsInstances = filter -- the property only updates on assignment
	end

	player.CharacterAdded:Connect(ignoreCharacter)
	if player.Character then
		ignoreCharacter(player.Character)
	end
end

Players.PlayerAdded:Connect(watchCharacters)
for _, player in Players:GetPlayers() do
	watchCharacters(player)
end

-- ============================================================================
-- 3. MATH HELPERS
-- ============================================================================

-- Builds the CFrame for a beam between two points: centred on the midpoint, pointing at
-- the far end. lookAt gives the orientation, so the part only needs a length on its Z axis.
local function beamCFrame(from: Vector3, to: Vector3): CFrame
	return CFrame.lookAt((from + to) * 0.5, to)
end

-- Where should the turret aim to hit a moving target with a round that also falls?
--
-- Flight time depends on distance, and distance depends on where the target will be at
-- that flight time, so the two feed each other. Rather than solving the quartic that comes
-- out of doing it exactly, this iterates the estimate: guess a time, move the target by it,
-- measure again. Three passes land within a few centimetres at these ranges and cost three
-- square roots, which is far cheaper than the closed form and much easier to read.
--
-- Gravity is then compensated separately by raising the aim point by the drop the round
-- accumulates over that flight time (1/2 * g * t^2). Drag makes the real flight slightly
-- longer than this estimate, which is deliberate: the turrets are meant to be very good,
-- not perfect, and the residual error is what keeps the accuracy readout interesting.
local function solveIntercept(origin: Vector3, targetPos: Vector3, targetVelocity: Vector3): (Vector3, number)
	local flightTime = (targetPos - origin).Magnitude / CONFIG.MuzzleVelocity

	for _ = 1, CONFIG.LeadIterations do
		local predicted = targetPos + targetVelocity * flightTime
		flightTime = (predicted - origin).Magnitude / CONFIG.MuzzleVelocity
	end

	local aimPoint = targetPos + targetVelocity * flightTime
	local drop = 0.5 * CONFIG.Gravity * flightTime * flightTime
	return aimPoint + Vector3.new(0, drop, 0), flightTime
end

-- ============================================================================
-- 4. SPRING
-- A damped spring driving a Vector3. The turrets use it on their aim direction rather than
-- on angles: springing a direction cannot wind up past a pole or take the long way round a
-- 360 degree wrap, and the result normalises straight into CFrame.lookAt.
-- ============================================================================

local Spring = {}
Spring.__index = Spring

type SpringFields = {
	position: Vector3,
	velocity: Vector3,
	goal: Vector3,
}

export type Spring = typeof(setmetatable({} :: SpringFields, Spring))

local function newSpring(start: Vector3): Spring
	return setmetatable({
		position = start,
		velocity = Vector3.zero,
		goal = start,
	}, Spring)
end

-- Semi-implicit Euler: velocity is updated first and the new velocity moves the position.
-- It costs the same as plain Euler but does not quietly gain energy over long runs, which
-- for a spring that lives for the whole session is the difference between settling and
-- oscillating wider every minute.
function Spring.step(self: Spring, dt: number)
	local offset = self.goal - self.position
	local acceleration = offset * CONFIG.SpringStiffness - self.velocity * CONFIG.SpringDamping

	self.velocity += acceleration * dt
	self.position += self.velocity * dt
end

-- ============================================================================
-- 5. TRACER POOL
-- Tracers are the highest-churn object in the range: a few hundred parts a minute, each
-- alive for a tenth of a second. Creating and destroying them is what turns a smooth range
-- into a stuttering one, so a fixed set of parts is created once and handed out on request.
-- ============================================================================

local TracerPool = {}
TracerPool.__index = TracerPool

type TracerPoolFields = {
	free: { BasePart },
	active: { { part: BasePart, age: number } },
}

export type TracerPool = typeof(setmetatable({} :: TracerPoolFields, TracerPool))

local function newTracerPool(size: number): TracerPool
	local free = table.create(size)

	for _ = 1, size do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false -- a tracer must never block another projectile's raycast
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = PALETTE.Tracer
		part.Transparency = 1
		part.Size = Vector3.new(CONFIG.TracerWidth, CONFIG.TracerWidth, 1)
		part.Parent = ignoreFolder
		table.insert(free, part)
	end

	return setmetatable({
		free = free,
		active = {},
	}, TracerPool)
end

-- Draws one segment. If the pool is empty the request is dropped rather than growing the
-- pool: a missing tracer for one frame is invisible, an unbounded part count is not.
function TracerPool.draw(self: TracerPool, from: Vector3, to: Vector3)
	local part = table.remove(self.free)
	if not part then
		return
	end

	local length = (to - from).Magnitude
	part.Size = Vector3.new(CONFIG.TracerWidth, CONFIG.TracerWidth, length)
	part.CFrame = beamCFrame(from, to)
	part.Transparency = 0

	table.insert(self.active, { part = part, age = 0 })
end

-- Fades the live tracers and returns the expired ones. The loop walks backwards so that
-- removing an entry cannot make it skip the next one.
function TracerPool.step(self: TracerPool, dt: number)
	for index = #self.active, 1, -1 do
		local entry = self.active[index]
		entry.age += dt

		local alpha = entry.age / CONFIG.TracerFadeTime
		if alpha >= 1 then
			entry.part.Transparency = 1
			table.insert(self.free, entry.part)
			table.remove(self.active, index)
		else
			entry.part.Transparency = alpha
		end
	end
end

-- ============================================================================
-- 6. PROJECTILE
-- A round is state, not a part: position, velocity and a way to report what it hit. The
-- visible tracer is a side effect of it moving. That split is what lets the physics run at
-- a fixed step while the visuals stay cheap.
-- ============================================================================

local Projectile = {}
Projectile.__index = Projectile

type ProjectileFields = {
	position: Vector3,
	velocity: Vector3,
	age: number,
	-- A callback rather than a reference to the turret that fired it. The round has no
	-- reason to know what a turret is, and keeping the dependency one-directional means
	-- neither type has to be declared before the other.
	report: (landed: boolean) -> (),
}

export type Projectile = typeof(setmetatable({} :: ProjectileFields, Projectile))

-- Forward declarations. Wind is toggled from the control pad far below, the tracer pool and
-- the hit lookup are built during range assembly. Declaring the locals here keeps the file
-- in reading order - small pieces first - without Luau treating them as globals.
local wind = Vector3.zero
local tracerPool: TracerPool
local resolveHit: (instance: BasePart) -> boolean

local function newProjectile(origin: Vector3, direction: Vector3, report: (boolean) -> ()): Projectile
	return setmetatable({
		position = origin,
		velocity = direction.Unit * CONFIG.MuzzleVelocity,
		age = 0,
		report = report,
	}, Projectile)
end

-- Advances one fixed step and returns false when the round is finished, either because it
-- hit something or because it timed out.
--
-- The raycast goes from the previous position to the new one instead of "forward a bit"
-- from the current position. At 220 studs a second a round covers almost four studs per
-- step, so a target thinner than that would sit in the gap between two samples and never be
-- touched. Casting the segment the round actually travelled makes tunnelling impossible.
function Projectile.step(self: Projectile, dt: number): boolean
	self.age += dt
	if self.age > CONFIG.ProjectileLifetime then
		return false
	end

	local speed = self.velocity.Magnitude

	-- Quadratic drag: the force scales with speed squared and opposes the direction of
	-- travel. Multiplying the velocity vector by its own magnitude gives both at once.
	local drag = -self.velocity * (speed * CONFIG.DragCoefficient)
	local acceleration = drag + wind + Vector3.new(0, -CONFIG.Gravity, 0)

	self.velocity += acceleration * dt
	local nextPosition = self.position + self.velocity * dt

	local result = Workspace:Raycast(self.position, nextPosition - self.position, rayParams)
	if result then
		tracerPool:draw(self.position, result.Position)
		self.report(resolveHit(result.Instance))
		return false
	end

	tracerPool:draw(self.position, nextPosition)
	self.position = nextPosition
	return true
end

-- ============================================================================
-- 7. TARGET
-- Each target slides along its own sine path. The path is evaluated from absolute time
-- rather than accumulated per frame, so a target can never drift out of phase with the
-- others, and its velocity is available in closed form.
-- ============================================================================

local Target = {}
Target.__index = Target

type TargetFields = {
	part: BasePart,
	origin: Vector3,
	phase: number,
	health: number,
	respawnTimer: number,
	alive: boolean,
}

export type Target = typeof(setmetatable({} :: TargetFields, Target))

local function newTarget(origin: Vector3, phase: number): Target
	local part = Instance.new("Part")
	part.Name = "Target"
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = PALETTE.TargetLive
	part.Size = Vector3.new(4, 6, 1)
	part.CFrame = CFrame.new(origin)
	part.Parent = targetFolder

	return setmetatable({
		part = part,
		origin = origin,
		phase = phase,
		health = CONFIG.TargetHealth,
		respawnTimer = 0,
		alive = true,
	}, Target)
end

-- Position and velocity of the sine path at a given time.
--
-- The velocity is the analytic derivative of the position rather than a difference between
-- two frames. It is exact, it costs one cosine, and the turret's lead solve is only as good
-- as the velocity it is handed - a differenced velocity would lag the target by a step and
-- the turrets would consistently shoot just behind it.
function Target.sample(self: Target, clock: number): (Vector3, Vector3)
	local omega = CONFIG.BobFrequency * math.pi * 2
	local angle = omega * clock + self.phase

	local offset = Vector3.new(math.sin(angle) * CONFIG.BobAmplitude, 0, 0)
	local velocity = Vector3.new(math.cos(angle) * CONFIG.BobAmplitude * omega, 0, 0)
	return self.origin + offset, velocity
end

function Target.step(self: Target, dt: number, clock: number)
	if not self.alive then
		self.respawnTimer -= dt
		if self.respawnTimer <= 0 then
			self.alive = true
			self.health = CONFIG.TargetHealth
			self.part.Color = PALETTE.TargetLive
			self.part.CanQuery = true
		end
		return
	end

	local position = self:sample(clock)
	self.part.CFrame = CFrame.new(position)
end

-- Applies one hit. Downed targets keep their part in the world but stop answering raycasts
-- via CanQuery, which removes them from the turrets' consideration without any bookkeeping
-- on the turret side.
function Target.damage(self: Target)
	self.health -= 1
	if self.health > 0 then
		return
	end

	self.alive = false
	self.respawnTimer = CONFIG.TargetRespawnDelay
	self.part.Color = PALETTE.TargetDead
	self.part.CanQuery = false
end

-- ============================================================================
-- 8. TURRET
-- ============================================================================

local Turret = {}
Turret.__index = Turret

type TurretFields = {
	pivot: Vector3,
	barrel: BasePart,
	aim: Spring,
	cooldown: number,
	shots: number,
	hits: number,
	report: (landed: boolean) -> (),
}

export type Turret = typeof(setmetatable({} :: TurretFields, Turret))

local function newTurret(pivot: Vector3): Turret
	local base = Instance.new("Part")
	base.Name = "TurretBase"
	base.Anchored = true
	base.Shape = Enum.PartType.Cylinder
	base.Material = Enum.Material.Metal
	base.Color = PALETTE.Steel
	base.Size = Vector3.new(1.5, 3, 3)
	-- A cylinder's flat faces sit on its X axis, so it has to be rolled 90 degrees to stand
	-- upright. Composing the rotation onto the position keeps that in one expression.
	base.CFrame = CFrame.new(pivot - Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	base.Parent = ignoreFolder

	local barrel = Instance.new("Part")
	barrel.Name = "TurretBarrel"
	barrel.Anchored = true
	barrel.CanCollide = false
	barrel.Material = Enum.Material.Metal
	barrel.Color = PALETTE.Steel
	barrel.Size = Vector3.new(0.5, 0.5, 5)
	barrel.CFrame = CFrame.new(pivot)
	barrel.Parent = ignoreFolder

	-- The scoring callback is built once per turret and handed to every round it fires, so a
	-- hit costs no allocation. Declaring the local first lets the closure capture the turret
	-- it belongs to before the table itself is finished.
	local turret: Turret
	local function report(landed: boolean)
		if landed then
			turret.hits += 1
		end
	end

	turret = setmetatable({
		pivot = pivot,
		barrel = barrel,
		aim = newSpring(Vector3.new(0, 0, -1)),
		cooldown = 0,
		shots = 0,
		hits = 0,
		report = report,
	}, Turret)

	return turret
end

-- The muzzle is the barrel's local -Z end. Reading it off the barrel's own CFrame means the
-- rounds always leave from wherever the model currently points, with no second copy of the
-- aim maths to keep in sync.
function Turret.muzzle(self: Turret): Vector3
	return self.barrel.CFrame * Vector3.new(0, 0, -self.barrel.Size.Z * 0.5)
end

-- One turret update: pick a target, spring the aim towards the intercept solution, point
-- the barrel, and fire when both the cooldown and the aim agree.
function Turret.step(self: Turret, dt: number, clock: number, target: Target?): Projectile?
	self.cooldown -= dt

	if target then
		local position, velocity = target:sample(clock)
		local aimPoint = solveIntercept(self.pivot, position, velocity)
		self.aim.goal = (aimPoint - self.pivot).Unit
	end

	self.aim:step(dt)

	local direction = self.aim.position
	if direction.Magnitude < 1e-4 then
		return nil -- degenerate spring state, skip this frame rather than normalising a zero vector
	end

	direction = direction.Unit
	self.barrel.CFrame = CFrame.lookAt(self.pivot, self.pivot + direction)

	-- Firing while the barrel is still swinging would send rounds off to the side, so the
	-- turret waits until the barrel and the solution point the same way. The dot product of
	-- two unit vectors is the cosine of the angle between them: 0.995 is about six degrees.
	if not target or self.cooldown > 0 or direction:Dot(self.aim.goal) < CONFIG.AimTolerance then
		return nil
	end

	self.cooldown = CONFIG.FireInterval
	self.shots += 1
	return newProjectile(self:muzzle(), direction, self.report)
end

-- ============================================================================
-- 9. RANGE ASSEMBLY
-- ============================================================================

tracerPool = newTracerPool(CONFIG.TracerPoolSize)

local targets: { Target } = table.create(CONFIG.TargetCount)
local turrets: { Turret } = table.create(CONFIG.TurretCount)
local projectiles: { Projectile } = {}

-- Targets are spread across the far end of the lane and each is given a different phase, so
-- they never line up into a single wall of movement.
for index = 1, CONFIG.TargetCount do
	local lateral = (index - (CONFIG.TargetCount + 1) * 0.5) * CONFIG.TargetSpacing
	local origin = Vector3.new(lateral, 8, -CONFIG.TargetRange)
	table.insert(targets, newTarget(origin, index * (math.pi * 2 / CONFIG.TargetCount)))
end

for index = 1, CONFIG.TurretCount do
	local lateral = (index - (CONFIG.TurretCount + 1) * 0.5) * CONFIG.TurretSpacing
	table.insert(turrets, newTurret(Vector3.new(lateral, 6, 0)))
end

-- Targets are handed out round-robin rather than "closest first", which would leave the
-- outer turrets idle and stack every round onto one target.
local function pickTarget(turretIndex: number): Target?
	local count = #targets
	for offset = 0, count - 1 do
		local target = targets[(turretIndex + offset - 1) % count + 1]
		if target.alive then
			return target
		end
	end
	return nil
end

-- Maps a hit part back to its Target. The lookup is a table keyed by part, so a hit costs
-- one index rather than a scan over every target.
local targetByPart: { [BasePart]: Target } = {}
for _, target in targets do
	targetByPart[target.part] = target
end

resolveHit = function(instance: BasePart): boolean
	local target = targetByPart[instance]
	if not target or not target.alive then
		return false
	end

	target:damage()
	return true
end

-- ============================================================================
-- 10. CONTROL PAD AND READOUT
-- A ClickDetector keeps the whole demo interactive without a second script: click handling
-- is delivered straight to the server, so there is no LocalScript and no remote to secure.
-- ============================================================================

local pad = Instance.new("Part")
pad.Name = "WindPad"
pad.Anchored = true
pad.Material = Enum.Material.SmoothPlastic
pad.Color = PALETTE.Pad
pad.Size = Vector3.new(8, 1, 8)
pad.CFrame = CFrame.new(0, 0.5, 16)
pad.Parent = ignoreFolder

local board = Instance.new("Part")
board.Name = "Readout"
board.Anchored = true
board.CanCollide = false
board.Transparency = 1
board.Size = Vector3.new(16, 6, 0.5)
board.CFrame = CFrame.new(0, 14, 22) * CFrame.Angles(0, math.pi, 0)
board.Parent = ignoreFolder

local surface = Instance.new("SurfaceGui")
surface.Face = Enum.NormalId.Front
surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surface.PixelsPerStud = 48
surface.Parent = board

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Font = Enum.Font.Code
label.TextScaled = true
label.TextColor3 = PALETTE.Tracer
label.Text = ""
label.Parent = surface

local clicker = Instance.new("ClickDetector")
clicker.MaxActivationDistance = 32
clicker.Parent = pad

-- Wind is applied to the rounds but deliberately not fed into the intercept solve, so
-- switching it on is a visible demonstration of what an uncompensated crosswind does to a
-- turret that is otherwise near perfect. The readout carries the proof.
clicker.MouseClick:Connect(function()
	wind = if wind == Vector3.zero then Vector3.new(CONFIG.WindSpeed, 0, 0) else Vector3.zero
	pad.Color = if wind == Vector3.zero then PALETTE.Pad else PALETTE.Tracer
end)

-- The readout is rebuilt only when a number it displays has changed. Writing to a TextLabel
-- every frame replicates a property change to every client sixty times a second for text
-- that is identical most of those frames.
local lastShots, lastHits = -1, -1

local function refreshReadout()
	local shots, hits = 0, 0
	for _, turret in turrets do
		shots += turret.shots
		hits += turret.hits
	end

	if shots == lastShots and hits == lastHits then
		return
	end
	lastShots, lastHits = shots, hits

	local accuracy = if shots > 0 then hits / shots * 100 else 0
	label.Text = string.format(
		"BALLISTIC RANGE\nshots %d   hits %d   accuracy %.1f%%\nwind %s   rounds in flight %d",
		shots,
		hits,
		accuracy,
		if wind == Vector3.zero then "calm" else "crosswind",
		#projectiles
	)
end

-- ============================================================================
-- 11. MAIN LOOP
-- Heartbeat delivers a variable delta; the accumulator turns it into whole fixed steps and
-- carries the remainder into the next frame. One connection drives the entire range.
-- ============================================================================

local accumulator = 0
local clock = 0

local function stepRange(dt: number)
	clock += dt

	for index, turret in turrets do
		local fired = turret:step(dt, clock, pickTarget(index))
		if fired then
			table.insert(projectiles, fired)
		end
	end

	for _, target in targets do
		target:step(dt, clock)
	end

	-- Backwards again, and the removal is a swap with the last element instead of a shift:
	-- rounds retire out of order anyway, so paying to preserve their order would be waste.
	for index = #projectiles, 1, -1 do
		if not projectiles[index]:step(dt) then
			projectiles[index] = projectiles[#projectiles]
			projectiles[#projectiles] = nil
		end
	end

	tracerPool:step(dt)
end

RunService.Heartbeat:Connect(function(deltaTime: number)
	accumulator += deltaTime

	local steps = math.min(math.floor(accumulator / CONFIG.StepTime), CONFIG.MaxStepsPerFrame)
	accumulator -= steps * CONFIG.StepTime

	for _ = 1, steps do
		stepRange(CONFIG.StepTime)
	end

	refreshReadout()
end)
