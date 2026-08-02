--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetSystem = ReplicatedStorage:WaitForChild("PetSystem")
local Remotes = require(PetSystem:WaitForChild("Remotes"))
local Types = require(PetSystem:WaitForChild("Types"))

local REQUEST_INTERVAL = 0.2

local rolled = Instance.new("BindableEvent")
local rejected = Instance.new("BindableEvent")

local rollRequest = Remotes.event(Remotes.ROLL_REQUEST)
local rollResult = Remotes.event(Remotes.ROLL_RESULT)

local lastRequest = 0
local connection: RBXScriptConnection? = nil

local RollController = {}

RollController.rolled = rolled.Event
RollController.rejected = rejected.Event

function RollController.start()
	if connection then
		return
	end

	connection = rollResult.OnClientEvent:Connect(function(response: Types.RollResponse)
		if typeof(response) ~= "table" then
			return
		end

		if response.ok then
			rolled:Fire(response.result)
		else
			rejected:Fire(response.rejection)
		end
	end)
end

function RollController.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

function RollController.request(): boolean
	local now = os.clock()
	if now - lastRequest < REQUEST_INTERVAL then
		return false
	end

	lastRequest = now
	rollRequest:FireServer()

	return true
end

return RollController
