local PhysicsCharacterController = require(script.PhysicsCharacterController)

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local AnimateFunction = require(script.Parent.AnimateModule)

local initChar = function(newCharacter : Model)
	local rootPart = newCharacter:WaitForChild("HumanoidRootPart")
	local humanoid : Humanoid = newCharacter:WaitForChild("Humanoid")
	humanoid.PlatformStand = true

    --Object auto destroys input when character is not in workspace (Destroyed)
	--Within InitUpdateDefaultControls()
    --Dirty but works
	repeat task.wait() 
		-- warn("Waiting until workspace")
	until newCharacter.Parent == workspace

	local characterController = PhysicsCharacterController.new(rootPart)
	characterController:AddDefaultComponents()
	characterController:AddComponent("Slide")
	-- characterController:AddComponent("AirStrafe") --Component is WIP

	characterController:Run()
	characterController:ConnectComponentsToInput()
	task.spawn(AnimateFunction, newCharacter, characterController)
end

player.CharacterAdded:Connect(initChar)

initChar(character)