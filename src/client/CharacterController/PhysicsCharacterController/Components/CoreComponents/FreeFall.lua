--[[
    Only handles change to freefalling state
    After animation debounce of default 0.31 seconds, and negative y velocity
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

local FreeFall = {}
FreeFall.__index = FreeFall


function FreeFall.new(data : PhysicsCharacterController)
    local self = setmetatable({}, FreeFall)

    local model = data._Model

    return self
end

function FreeFall:Update(data : PhysicsCharacterController, deltaTime)

    local stateMachine = data._StateMachine

    local xzSpeed = data._XZ_Speed
    local xzVelocity = data._XZ_Velocity
    local rootVelocity = data.Velocity
    local moveDirection = data.MoveDirection
    local unitXZ = data._RootPartUnitXZVelocity

    local model = data._Model

    local jumpObject = data:GetComponent("Jump")
    assert(jumpObject, "Jump component must be added")
    jumpObject.JumpAnimTransitionTime -= deltaTime

    if rootVelocity.Y < 0 and stateMachine.current == "Jumping" and jumpObject.JumpAnimTransitionTime <= 0 then
        stateMachine.fall()
    end
end

function FreeFall:Destroy()
    
end


return FreeFall
