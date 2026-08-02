--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetSystem = ReplicatedStorage:WaitForChild("PetSystem")
local Remotes = require(PetSystem:WaitForChild("Remotes"))

local RollService = require(script:WaitForChild("RollService"))

local rollRequest = Remotes.event(Remotes.ROLL_REQUEST)
local rollResult = Remotes.event(Remotes.ROLL_RESULT)

for _, player in Players:GetPlayers() do
	RollService.bind(player)
end

Players.PlayerAdded:Connect(RollService.bind)
Players.PlayerRemoving:Connect(RollService.unbind)

rollRequest.OnServerEvent:Connect(function(player: Player)
	rollResult:FireClient(player, RollService.roll(player))
end)
