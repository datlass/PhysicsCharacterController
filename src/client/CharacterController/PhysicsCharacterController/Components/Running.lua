export type PhysicsCharacterController = {
    RootPart : BasePart, --Rootpart
    _Model : Model,
    _CenterAttachment : Attachment,
    _MovementComponents : {},
    _XZ_Speed : Vector3,
    _XZ_Velocity : Vector3,
    Velocity : Vector3,
    MoveDirection : Vector3
}

local ZERO_VECTOR = Vector3.new(0, 0, 0)

local Running = {}
Running.__index = Running


function Running.new(data : PhysicsCharacterController)
    local self = setmetatable({}, Running)

    local model = data._Model
    local XZ_DRAG_NUMBER = 3
    self._XZ_DRAG_NUMBER = XZ_DRAG_NUMBER
    model:SetAttribute("XZDragFactorVSquared", XZ_DRAG_NUMBER)
    model:SetAttribute("FlatFriction", 500)
    model:SetAttribute("WalkSpeed", 16)
    model:SetAttribute("EnableAirStrafe", false)
    model:SetAttribute("DisableMovement", false)


    local attachment = data._CenterAttachment
    local dragForce = Instance.new("VectorForce")
    dragForce.Attachment0 = attachment
    dragForce.Force = Vector3.new()
    dragForce.ApplyAtCenterOfMass = true
    dragForce.RelativeTo = Enum.ActuatorRelativeTo.World
    dragForce.Parent = model
    self.DragForce = dragForce

    local movementForce = Instance.new("VectorForce")
    movementForce.Attachment0 = attachment
    movementForce.ApplyAtCenterOfMass = true
    movementForce.Force = Vector3.new()
    movementForce.RelativeTo = Enum.ActuatorRelativeTo.World
    movementForce.Parent = model

    self.MovementForce = movementForce

    return self
end

local hipHeightModule = script.Parent.HipHeight

function Running:Update(data : PhysicsCharacterController)

    local hipHeightObject = data._MovementComponents[hipHeightModule]
    assert(hipHeightObject, "Running Component requires HipHeight Component make sure the :Add(HipHeightModuleScript) on Physics Character Controller")
    local onGround = hipHeightObject.OnGround

    local xzSpeed = data._XZ_Speed
    -- local xzVelocity = data._XZ_Velocity
    -- local rootVelocity = data.Velocity
    local moveDirection = data.MoveDirection
    local unitXZ = data._RootPartUnitXZVelocity

    local model = data._Model
    local dragForce = self.DragForce

    local movementForceScalar = (model:GetAttribute("WalkSpeed")^2)*model:GetAttribute("XZDragFactorVSquared") + model:GetAttribute("FlatFriction")
    self.MovementForce.Force = moveDirection*movementForceScalar

    local isMoving = unitXZ.X == unitXZ.X
    if isMoving then
        local netDragForce = -unitXZ*(xzSpeed^2)*model:GetAttribute("XZDragFactorVSquared")
		dragForce.Force = netDragForce
	else
		dragForce.Force = ZERO_VECTOR
	end

    if onGround and isMoving then
        local flatFrictionScalar = model:GetAttribute("FlatFriction")*(1.0-math.exp(-xzSpeed))
        dragForce.Force += -unitXZ*flatFrictionScalar
    end

    --handle state
    local stateMachine = data._StateMachine

    if stateMachine.current == "Standing" and isMoving and xzSpeed >= 0.1 then
        stateMachine.run()
    end
    if stateMachine.current == "Running" and xzSpeed < 0.1 then
        stateMachine.stand()
    end
end

function Running:Destroy()

    self.DragForce:Destroy()
    
    self.MovementForce:Destroy()

end


return Running
