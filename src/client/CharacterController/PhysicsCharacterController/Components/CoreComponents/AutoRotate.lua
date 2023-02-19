export type AutoRotate = {
    AlignOrientation : AlignOrientation, --Rootpart
}

export type PhysicsCharacterController = {
    RootPart : BasePart, --Rootpart
    _Model : Model,
    _CenterAttachment : Attachment,
    _MovementComponent : {},
    _XZ_Speed : Vector3,
    _XZ_Velocity : Vector3,
    Velocity : Vector3,
    MoveDirection : Vector3
}

local ZERO_VECTOR = Vector3.zero

local function notNaN(a)
    return a == a
end

local AutoRotate : AutoRotate = {}
AutoRotate.__index = AutoRotate

function AutoRotate.new(PhysicsCharacterController : PhysicsCharacterController)
    local self = setmetatable({}, AutoRotate)

    local alignOrientation = Instance.new("AlignOrientation")


    alignOrientation.Attachment0 = PhysicsCharacterController._CenterAttachment
    PhysicsCharacterController._CenterAttachment.Name = "CenterAttach"
    alignOrientation.MaxAngularVelocity = 100
    alignOrientation.Responsiveness = 1000
    alignOrientation.RigidityEnabled = true

    self.AlignOrientation = alignOrientation

    local alignmentAttachment = Instance.new("Attachment",workspace.Terrain)
    alignmentAttachment.Name = "TerrainAttach"
    alignOrientation.Attachment1 = alignmentAttachment
    alignOrientation.Responsiveness = 20
    alignOrientation.Parent = PhysicsCharacterController._Model

    self._AlignmentAttachment = alignmentAttachment

    self._Before = CFrame.new()
    self._After = CFrame.new()
    self._OverrideCF = nil

    return self
end

local debugPart = Instance.new("Part")
debugPart.CanCollide = false
debugPart.CanQuery = false
debugPart.Anchored = true
debugPart.Parent = workspace

function AutoRotate:Update(PhysicsCharacterController : PhysicsCharacterController)
    --HumanoidAutoRotate
    local unitXZ = (PhysicsCharacterController._XZ_Velocity).Unit
    local alignmentAttachment = self._AlignmentAttachment
    local moveDirection = PhysicsCharacterController.MoveDirection
    local rootPart = PhysicsCharacterController.RootPart

    if self.getCF then
        
        alignmentAttachment.CFrame = self.getCF()*alignmentAttachment.CFrame

    else

        if moveDirection.Magnitude > 0 then
            alignmentAttachment.CFrame = CFrame.lookAt(ZERO_VECTOR, moveDirection)
        else
            --Maintain current orientation
            local _, y, _ = rootPart.CFrame.Rotation:ToOrientation()
            alignmentAttachment.CFrame = CFrame.fromOrientation(0, y, 0)
        end

    end
    
    alignmentAttachment.CFrame = self._Before*alignmentAttachment.CFrame*self._After

    -- debugPart.CFrame = alignmentAttachment.CFrame.Rotation + rootPart.CFrame.Position + Vector3.new(0,5,0)
end

function AutoRotate:Destroy()

    self._AlignmentAttachment:Destroy()
    
    self.AlignOrientation:Destroy()
    
end

return AutoRotate
