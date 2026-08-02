--!strict

local ContextActionService = game:GetService("ContextActionService")

local RollController = require(script:WaitForChild("RollController"))

local ACTION_NAME = "PetSystemRoll"

RollController.start()

ContextActionService:BindAction(ACTION_NAME, function(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		RollController.request()
	end

	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonY)

ContextActionService:SetTitle(ACTION_NAME, "Roll")
