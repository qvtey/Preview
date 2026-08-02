--!strict

local ContextActionService = game:GetService("ContextActionService")

local WeaponController = require(script:WaitForChild("WeaponController"))

local FIRE_ACTION = "GunSystemFire"
local AIM_ACTION = "GunSystemAim"
local RELOAD_ACTION = "GunSystemReload"
local SWAP_PRIMARY = "GunSystemPrimary"
local SWAP_SECONDARY = "GunSystemSecondary"

WeaponController.start()
WeaponController.equip("rifle")

ContextActionService:BindAction(FIRE_ACTION, function(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		WeaponController.setFiring(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		WeaponController.setFiring(false)
	end

	return Enum.ContextActionResult.Pass
end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

ContextActionService:BindAction(AIM_ACTION, function(_, state: Enum.UserInputState)
	WeaponController.setAiming(state == Enum.UserInputState.Begin)

	return Enum.ContextActionResult.Pass
end, true, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)

ContextActionService:BindAction(RELOAD_ACTION, function(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		WeaponController.reload()
	end

	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)

ContextActionService:BindAction(SWAP_PRIMARY, function(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		WeaponController.equip("rifle")
	end

	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.One)

ContextActionService:BindAction(SWAP_SECONDARY, function(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		WeaponController.equip("pistol")
	end

	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Two)

ContextActionService:SetTitle(FIRE_ACTION, "Fire")
ContextActionService:SetTitle(AIM_ACTION, "Aim")
ContextActionService:SetTitle(RELOAD_ACTION, "Reload")
