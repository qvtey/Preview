--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Remotes = require(GunSystem:WaitForChild("Remotes"))

local AmmoState = require(script:WaitForChild("AmmoState"))
local FireHandler = require(script:WaitForChild("FireHandler"))
local Rewind = require(script:WaitForChild("Rewind"))

local fireRemote = Remotes.event(Remotes.FIRE)
local reloadRemote = Remotes.event(Remotes.RELOAD)
local equipRemote = Remotes.event(Remotes.EQUIP)

Rewind.start()

local function watch(player: Player)
	player.CharacterAdded:Connect(function()
		AmmoState.reset(player)
		FireHandler.pushAmmo(player)
	end)
end

for _, player in Players:GetPlayers() do
	watch(player)
end

Players.PlayerAdded:Connect(watch)

Players.PlayerRemoving:Connect(function(player)
	AmmoState.clear(player)
	FireHandler.forget(player)
	Rewind.forget(player)
end)

fireRemote.OnServerEvent:Connect(FireHandler.handle)
reloadRemote.OnServerEvent:Connect(FireHandler.handleReload)
equipRemote.OnServerEvent:Connect(FireHandler.handleEquip)
