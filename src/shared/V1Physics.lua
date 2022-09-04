--StarterCharacterScripts
--Old single script physics
--For historical purposes

--Made by dthecoolest

local char = script.Parent
local RunService = game:GetService("RunService")

local humanoid : Humanoid = char:WaitForChild("Humanoid")
local rootPart = humanoid.RootPart
local UserInputService = game:GetService("UserInputService")

local attachment = Instance.new("Attachment")
attachment.Parent = rootPart
attachment.Name = "VectorForceAttachment"
attachment.WorldPosition = rootPart.AssemblyCenterOfMass

local movementForce = Instance.new("VectorForce")
movementForce.Attachment0 = attachment
--movementForce.ApplyAtCenterOfMass = true
movementForce.Force = Vector3.new()
movementForce.RelativeTo = Enum.ActuatorRelativeTo.World
movementForce.Parent = char

humanoid.PlatformStand = true

local dragForce = Instance.new("VectorForce")
dragForce.Attachment0 = attachment
dragForce.Force = Vector3.new()
--dragForce.ApplyAtCenterOfMass = true
dragForce.RelativeTo = Enum.ActuatorRelativeTo.World
dragForce.Parent = char

local alignOrientation = Instance.new("AlignOrientation")
alignOrientation.Attachment0 = attachment
local alignmentAttachment = Instance.new("Attachment",workspace.Terrain)
alignOrientation.Attachment1 = alignmentAttachment
alignOrientation.Responsiveness = 20
alignOrientation.Parent = char

local visualizePart = Instance.new("WedgePart")
visualizePart.CanCollide = false
visualizePart.CanQuery = false
visualizePart.Anchored = true
visualizePart.Parent = workspace

local XZ_VECTOR = Vector3.new(1,0,1)
local ZERO_VECTOR = Vector3.new(0,0,0)
local DOWN_VECTOR = Vector3.new(0,-1,0)

print(humanoid.HipHeight)
local hipHeight
if humanoid.RigType == Enum.HumanoidRigType.R6 then
	hipHeight = char["Left Leg"].Size.Y +rootPart.Size.Y*0.5  + 0.5
else
	hipHeight = humanoid.HipHeight +rootPart.Size.Y*0.5  + 0.5
end
char:SetAttribute("HipHeight", hipHeight)
char:GetAttributeChangedSignal("HipHeight"):Connect(function()
	local newHipHeight = char:GetAttribute("HipHeight")
	hipHeight = newHipHeight
end)

local standUpForce = Instance.new("VectorForce")
--standUpForce.ApplyAtCenterOfMass = true
standUpForce.Attachment0 = attachment
standUpForce.Force = Vector3.new()
standUpForce.RelativeTo = Enum.ActuatorRelativeTo.World
standUpForce.Parent = char

local raycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = {char}

local humanoidRootPart = char.HumanoidRootPart

local reactionForce = Instance.new("VectorForce")
reactionForce.ApplyAtCenterOfMass = true
reactionForce.Attachment0 = attachment
reactionForce.Force = Vector3.new()
reactionForce.RelativeTo = Enum.ActuatorRelativeTo.World
reactionForce.Parent = char


char:SetAttribute("Suspension", 11000)
char:SetAttribute("Bounce", 200)

--XZ Movement
local XZ_DRAG_NUMBER = 3
char:SetAttribute("XZDragFactorVSquared", XZ_DRAG_NUMBER)
char:SetAttribute("FlatFriction", 500)
char:SetAttribute("WalkSpeed", 16)
char:SetAttribute("EnableAirStrafe", false)
char:SetAttribute("DisableMovement", false)


local onGround = true

local debounce = false

function onJumpRequest()
	if (not debounce) and onGround then
		debounce = true
		onGround = false
		local connection = RunService.RenderStepped:Connect(function()
			standUpForce.Force = ZERO_VECTOR
		end)
		--print(math.round(standUpForce.Force.Y))
		standUpForce.Force = ZERO_VECTOR
		rootPart:ApplyImpulse(Vector3.new(0,1,0)*1000)
		standUpForce.Force = ZERO_VECTOR
		task.wait(0.2)
		connection:Disconnect()
		debounce = false
	end
end

UserInputService.JumpRequest:Connect(onJumpRequest)

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		local forceAmount = 2000
		--constant distance dash
		if not onGround then
			--No need to overcome friction force
			forceAmount -= char:GetAttribute("FlatFriction")
		end

		rootPart:ApplyImpulse((rootPart.CFrame.LookVector*XZ_VECTOR).Unit*forceAmount)
		--rootPart.AssemblyLinearVelocity = (rootPart.CFrame.LookVector*XZ_VECTOR).Unit*forceAmount*XZ_VECTOR/20
		print("Slidee!")
		char:SetAttribute("DisableMovement", true)

		while UserInputService:IsKeyDown(Enum.KeyCode.F) do
			--Remove drag limiting movement
			char:SetAttribute("XZDragFactorVSquared", 0)
			RunService.Stepped:Wait()
		end
		char:SetAttribute("DisableMovement", false)
		char:SetAttribute("XZDragFactorVSquared", XZ_DRAG_NUMBER)
	end
end)


RunService.Stepped:Connect(function(time, dt)

	local rootVelocity = rootPart.AssemblyLinearVelocity
	local xzVelocity = rootVelocity*XZ_VECTOR
	local xzSpeed = xzVelocity.Magnitude
	local moveDirection = humanoid.MoveDirection

	if char:GetAttribute("DisableMovement") then
		movementForce.Force = ZERO_VECTOR
	else
		local movementForceScalar = (char:GetAttribute("WalkSpeed")^2)*char:GetAttribute("XZDragFactorVSquared") + char:GetAttribute("FlatFriction")
		movementForce.Force = moveDirection*movementForceScalar
	end
	--HumanoidAutoRotate
	local unitXZ = (xzVelocity).Unit
	if moveDirection.Magnitude > 0 and unitXZ.X == unitXZ.X then
		alignmentAttachment.CFrame = CFrame.lookAt(ZERO_VECTOR, moveDirection)
	else
		local x, y, z = humanoidRootPart.CFrame.Rotation:ToOrientation()
		alignmentAttachment.CFrame = CFrame.fromOrientation(0, y, 0)
	end
	--Just for visualization for auto rotate
	visualizePart.CFrame = alignmentAttachment.CFrame.Rotation+humanoidRootPart.Position+Vector3.new(0,10,0)
	--Drag force
	--NAN Check
	if unitXZ.X == unitXZ.X then
		dragForce.Force = -unitXZ*(xzSpeed^2)*char:GetAttribute("XZDragFactorVSquared")
	else
		dragForce.Force = ZERO_VECTOR
	end

	--StandUpForce
	local raycastResult = workspace:Raycast(humanoidRootPart.Position, DOWN_VECTOR*hipHeight, raycastParams)

	--if on ground then apply spring
	if raycastResult then
		local currentSpringLength = (raycastResult.Position - humanoidRootPart.Position).Magnitude
		local suspension = char:GetAttribute("Suspension")
		local suspensionForceFactor =humanoidRootPart.AssemblyMass*suspension
		--Taken from X_O Jeep, works great
		standUpForce.Force = Vector3.new(0, ((hipHeight - currentSpringLength)^2) * (suspensionForceFactor / hipHeight^2), 0)
		local damping = suspensionForceFactor/char:GetAttribute("Bounce")
		standUpForce.Force -= Vector3.new(0,rootVelocity.Y*damping,0)

		--apply ground friction
		if unitXZ.X == unitXZ.X then
			--Exponential to reduce friction force when speed equals to zero, for stabilization and prevents "wiggling"
			local flatFrictionScalar = char:GetAttribute("FlatFriction")*(1.0-math.exp(-xzSpeed))
			dragForce.Force += -unitXZ*flatFrictionScalar
		end

		reactionForce.Force = raycastResult.Normal*humanoidRootPart.AssemblyMass
		onGround = true
	else
		--Disable movement force and drag force to allow momentum to be conserved while in the air
		if not char:GetAttribute("EnableAirStrafe") then
			movementForce.Force = ZERO_VECTOR
			dragForce.Force = ZERO_VECTOR
		end		
		onGround = false
		reactionForce.Force = ZERO_VECTOR		
		standUpForce.Force = ZERO_VECTOR
	end
	print(onGround)
end)

return nil