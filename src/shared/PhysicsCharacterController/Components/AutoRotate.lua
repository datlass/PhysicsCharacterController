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
    PhysicsCharacterController._CenterAttachment.Visible = true

    self.AlignOrientation = alignOrientation

    local alignmentAttachment = Instance.new("Attachment",workspace.Terrain)
    alignmentAttachment.Name = "TerrainAttach"
    alignOrientation.Attachment1 = alignmentAttachment
    alignOrientation.Responsiveness = 20
    alignOrientation.Parent = PhysicsCharacterController._Model

    self._AlignmentAttachment = alignmentAttachment

    return self
end

function AutoRotate:Update(PhysicsCharacterController : PhysicsCharacterController)
    --HumanoidAutoRotate
    local unitXZ = (PhysicsCharacterController._XZ_Velocity).Unit
    local alignmentAttachment = self._AlignmentAttachment
    local moveDirection = PhysicsCharacterController.MoveDirection
    local rootPart = PhysicsCharacterController.RootPart

    if moveDirection.Magnitude > 0 then
        alignmentAttachment.CFrame = CFrame.lookAt(ZERO_VECTOR, moveDirection)
    else
        --Maintain current orientation
        local _, y, _ = rootPart.CFrame.Rotation:ToOrientation()
        alignmentAttachment.CFrame = CFrame.fromOrientation(0, y, 0)
    end

end

function AutoRotate:Destroy()
    if self._AlignmentAttachment.Parent ~= nil then
        self._AlignmentAttachment:Destroy()
    end
    if self.AlignOrientation:FindFirstAncestorWhichIsA("Workspace") ~= nil then
        self.AlignOrientation:Destroy()
    end
end


return AutoRotate
