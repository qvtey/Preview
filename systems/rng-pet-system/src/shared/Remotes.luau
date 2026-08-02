--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "PetSystemRemotes"
local WAIT_TIMEOUT = 15

local Remotes = {}

Remotes.ROLL_REQUEST = "PetRollRequest"
Remotes.ROLL_RESULT = "PetRollResult"

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

function Remotes.event(name: string): RemoteEvent
	local folder = container()

	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end

		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder

		return remote
	end

	local replicated = folder:WaitForChild(name, WAIT_TIMEOUT)
	return assert(replicated, `remote "{name}" never replicated to this client`) :: RemoteEvent
end

return Remotes
