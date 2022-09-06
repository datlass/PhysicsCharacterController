--[[
    Handles vectorforces to keep the rootPart standing
]]

export type PhysicsCharacterController = {
    RootPart : BasePart, --Rootpart
    _Model : Model,
    _CenterAttachment : Attachment,
    _MovementComponent : {},
    _XZ_Speed : Vector3,
    _XZ_Velocity : Vector3,
    Velocity : Vector3,
}

local ZERO_VECTOR = Vector3.zero

local HipHeight = {}
HipHeight.__index = HipHeight

local function setupVectorForceRelativeToWorld(attachment, parent, centerOfmass)
    local standUpForce = Instance.new("VectorForce")
    standUpForce.ApplyAtCenterOfMass = centerOfmass or true
    standUpForce.Attachment0 = attachment
    standUpForce.Force = Vector3.new()
    standUpForce.RelativeTo = Enum.ActuatorRelativeTo.World
    standUpForce.Parent = parent

    return standUpForce
end

function HipHeight.new(data : PhysicsCharacterController)
    local self = setmetatable({}, HipHeight)

    self.PhysicsCharacterController = data
    local rootPart = self.PhysicsCharacterController.RootPart
    --corners based on birds eye view, assumes hrp is (0,0,0)
    local topRightCorner = rootPart.Size*Vector3.new(1,0,1)/2

    local divisions = 2
    local xDivisionSize = 2*topRightCorner.X/divisions
    local zDivisionSize = 2*topRightCorner.Z/divisions

    local attachments = {}
    local vectorForces = {}
    self.VectorForces = vectorForces
    self.Attachments = attachments
    self._vectorSpringDragForce = setupVectorForceRelativeToWorld(data._CenterAttachment, rootPart, true)
    self.OnGround = true

    --0,1,2,3,4,5
    for x = 0, divisions  do
        for z = 0, divisions do
            local position = Vector3.new(xDivisionSize*x-topRightCorner.X,0,zDivisionSize*z-topRightCorner.Z)
            local attachment = Instance.new("Attachment")
            attachment.Position = position
            attachment.Parent = rootPart
            local vectorForce = setupVectorForceRelativeToWorld(attachment, rootPart, true)
            table.insert(attachments, attachment)
            table.insert(vectorForces, vectorForce)
        end
    end
    local model = data._Model

    model:SetAttribute("Suspension", 21000)
    model:SetAttribute("Bounce", 200)

    local humanoid = model:FindFirstChild("Humanoid")
    if humanoid then
        self:SetupHipHeightForHumanoid(humanoid)
    end
    
    self.MassPerForce = rootPart.AssemblyMass/#vectorForces
    return self
end

function HipHeight:SetupHipHeightForHumanoid(humanoid)
    local rootPart = self.PhysicsCharacterController.RootPart
    local hipHeight
    local model = self.PhysicsCharacterController._Model

    if humanoid.RigType == Enum.HumanoidRigType.R6 then
        hipHeight = model["Left Leg"].Size.Y + rootPart.Size.Y*0.5  + 0.5
    else
        hipHeight = humanoid.HipHeight + rootPart.Size.Y*0.5  + 0.5
    end
    model:SetAttribute("HipHeight", hipHeight)    

    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {model}
    self.RayParams = raycastParams
end
local DOWN_VECTOR = -Vector3.yAxis

function HipHeight:Update(data : PhysicsCharacterController)
    local rootPart = data.RootPart
    local stateMachine = data._StateMachine
    local model = self.PhysicsCharacterController._Model
    local hipHeight = model:GetAttribute("HipHeight") or 2.5

    local onGround = false
    local vectorForces = self.VectorForces
    local totalSuspensionValue = model:GetAttribute("Suspension")
    
    local indivudalSuspension = totalSuspensionValue / #vectorForces

    for _, v : VectorForce in pairs(vectorForces) do
        local attachment = v.Attachment0
        local raycastResult = workspace:Raycast(attachment.WorldPosition, DOWN_VECTOR*hipHeight, self.RayParams)
        if raycastResult then
    
            local currentSpringLength = (raycastResult.Position - rootPart.Position).Magnitude
            
            local suspensionForceFactor = rootPart.AssemblyMass*indivudalSuspension
            --Taken from X_O Jeep, works great    
            local standupForce = Vector3.new(0, ((hipHeight - currentSpringLength)^2) * (suspensionForceFactor / hipHeight^2), 0)
    
            v.Force = standupForce
            v.Force += self.MassPerForce*raycastResult.Normal
            
            onGround = true
        else
            v.Force = ZERO_VECTOR
        end
    end

    self.OnGround = onGround
    local bounce = model:GetAttribute("Bounce")
    if onGround then
        local suspensionForceFactor = rootPart.AssemblyMass*totalSuspensionValue
        --Taken from X_O Jeep, works great
        local damping = suspensionForceFactor/bounce
        -- F = - cV 
        self._vectorSpringDragForce.Force  = Vector3.new(0,-rootPart.AssemblyLinearVelocity.Y*damping,0)
    else
        self._vectorSpringDragForce.Force  = ZERO_VECTOR
    end

    if onGround and stateMachine.current == "FreeFalling" then
        stateMachine.land() --Transition from landed
        stateMachine.recover() --Transition from landed to standing state
    end
end

function HipHeight:Destroy()
    self._SpringDragForce:Destroy()

    for i,v in pairs(self.VectorForces) do
        v:Destroy()
    end

    for i,v in pairs(self.Attachments) do
        v:Destroy()
    end

end

return HipHeight
