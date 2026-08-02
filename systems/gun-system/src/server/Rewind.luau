--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type Snapshot = {
	time: number,
	root: CFrame,
	head: CFrame,
}

local HISTORY_SECONDS = 1

local histories: { [Player]: { Snapshot } } = {}
local running = false

local Rewind = {}

local function capture()
	local now = os.clock()

	for _, player in Players:GetPlayers() do
		local character = player.Character

		if character == nil then
			continue
		end

		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local head = character:FindFirstChild("Head") :: BasePart?

		if root == nil or head == nil then
			continue
		end

		local history = histories[player]

		if history == nil then
			history = {}
			histories[player] = history
		end

		table.insert(history, {
			time = now,
			root = root.CFrame,
			head = head.CFrame,
		})

		while #history > 1 and now - history[1].time > HISTORY_SECONDS do
			table.remove(history, 1)
		end
	end
end

function Rewind.start()
	if running then
		return
	end

	running = true

	RunService.Heartbeat:Connect(capture)
	Players.PlayerRemoving:Connect(function(player)
		histories[player] = nil
	end)
end

function Rewind.forget(player: Player)
	histories[player] = nil
end

function Rewind.at(player: Player, timestamp: number): Snapshot?
	local history = histories[player]

	if history == nil or #history == 0 then
		return nil
	end

	local newest = history[#history]

	if timestamp >= newest.time then
		return newest
	end

	if timestamp <= history[1].time then
		return history[1]
	end

	for index = #history, 2, -1 do
		local older = history[index - 1]

		if timestamp >= older.time then
			local newer = history[index]
			local span = newer.time - older.time
			local alpha = if span > 0 then (timestamp - older.time) / span else 0

			return {
				time = timestamp,
				root = older.root:Lerp(newer.root, alpha),
				head = older.head:Lerp(newer.head, alpha),
			}
		end
	end

	return history[1]
end

return Rewind
