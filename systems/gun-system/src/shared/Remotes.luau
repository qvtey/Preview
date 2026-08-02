--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "GunSystemRemotes"
local WAIT_TIMEOUT = 15

local Remotes = {}

Remotes.FIRE = "WeaponFire"
Remotes.RELOAD = "WeaponReload"
Remotes.EQUIP = "WeaponEquip"
Remotes.SHOT = "WeaponShot"
Remotes.AMMO = "WeaponAmmo"
Remotes.TRACER = "WeaponTracer"

local function container(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing :: Folder
		end

		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage

		return folder
	end

	local replicated = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT)
	return assert(replicated, `{FOLDER_NAME} never replicated to this client`) :: Folder
end

local function resolve(name: string, className: string): Instance
	local folder = container()

	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end

		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder

		return remote
	end

	local replicated = folder:WaitForChild(name, WAIT_TIMEOUT)
	return assert(replicated, `remote "{name}" never replicated to this client`)
end

function Remotes.event(name: string): RemoteEvent
	return resolve(name, "RemoteEvent") :: RemoteEvent
end

function Remotes.unreliable(name: string): UnreliableRemoteEvent
	return resolve(name, "UnreliableRemoteEvent") :: UnreliableRemoteEvent
end

return Remotes
