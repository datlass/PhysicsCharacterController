--[[
    WIP Component, not done yet
    Aims to disable air friction while also allowing forces
    --Goal is to create source engine feel
]]

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

local AirStrafe = {}
AirStrafe.__index = AirStrafe


function AirStrafe.new(data : PhysicsCharacterController)
    local self = setmetatable({}, AirStrafe)

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

function AirStrafe:Update(data : PhysicsCharacterController)

    local hipHeightObject = data:GetComponent("HipHeight")
    assert(hipHeightObject, "AirStrafe Component requires HipHeight Component make sure the :Add(HipHeightModuleScript) on Physics Character Controller")
    local onGround = hipHeightObject.OnGround

    --Ovewrite running system while off air
    local runningComponent = data:GetComponent("Running")
    if runningComponent then
        if not onGround then
            runningComponent.ShouldUpdate = false
            runningComponent.DragForce.Force = ZERO_VECTOR
            runningComponent.MovementForce.Force = ZERO_VECTOR
        else
            runningComponent.ShouldUpdate = true
        end
    end
    if onGround then
        self.DragForce.Force = ZERO_VECTOR
        self.MovementForce.Force = ZERO_VECTOR

        return
    end

    local xzSpeed = data._XZ_Speed
    local moveDirection = data.MoveDirection
    local unitXZ = data._RootPartUnitXZVelocity

    local model = data._Model
    local dragForce = self.DragForce

    local isMoving = unitXZ.X == unitXZ.X -- NaN check

    local totalDragForce = ZERO_VECTOR

    local flatFrictionScalar
    if onGround and isMoving then
        --This equations allows vector forces to stabilize
        --"Decrease flat friction when low speed"
        --Constant friction when above velocity is above 2 usually
        flatFrictionScalar = model:GetAttribute("FlatFriction")*(1.0-math.exp(-2*xzSpeed))
        totalDragForce += -unitXZ*flatFrictionScalar
    end

    local walkSpeed = model:GetAttribute("WalkSpeed")

    local dragCoefficient = model:GetAttribute("XZDragFactorVSquared")
    local counterActGroundFriction = flatFrictionScalar or model:GetAttribute("FlatFriction")
    local counterActDragFriction = (walkSpeed^2)*dragCoefficient

    --If no drag friction, then no counter ground friction to prevent movement
    if counterActDragFriction <= 0.01 then
        counterActGroundFriction = 0
    end

    local movementForceScalar = counterActDragFriction + counterActGroundFriction
    self.MovementForce.Force = moveDirection*movementForceScalar

    if isMoving then
        local netDragForce = -unitXZ*(xzSpeed^2)*model:GetAttribute("XZDragFactorVSquared")
		totalDragForce += netDragForce
	end
    
    -- print("Speed: ",math.round(xzSpeed*100)/100)
    -- print("Drag force: ", math.round(totalDragForce.Magnitude*100)/100)
    -- print("Movement Force: ", math.round(self.MovementForce.Force.Magnitude*100)/100)

    dragForce.Force = totalDragForce
end

function AirStrafe:Destroy()

    self.DragForce:Destroy()
    
    self.MovementForce:Destroy()

end


return AirStrafe
