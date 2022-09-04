local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsCharacterController = require(ReplicatedStorage.Common.PhysicsCharacterController)

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local AnimateFunction = require(script.Parent.AnimateModule)

local initChar = function(character : Model)
	local rootPart = character:WaitForChild("HumanoidRootPart")
	local humanoid : Humanoid = character:WaitForChild("Humanoid")
	humanoid.PlatformStand = true

	local characterController = PhysicsCharacterController.new(rootPart)
	characterController:AddDefaultComponents()
	characterController:InitUpdateDefaultControls()
	print("Loading animate")
	task.spawn(AnimateFunction, character, characterController)
end

player.CharacterAdded:Connect(initChar)

initChar(character)