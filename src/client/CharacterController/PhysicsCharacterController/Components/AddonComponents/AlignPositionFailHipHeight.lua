--[[
    Handles vectorforces to keep the rootPart standing
    Ignore, this fail module attempts to use align position, but align position controls all axis and cannot be used for y axis only :((
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
local HIPHEIGHT_ATTRIBUTE_NAME = "HipHeightIncludingTorso" --Normal hipheight doesn't include the size of the root torso, this controller one does tho

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

    local divisions = 3
    local xDivisionSize = 2*topRightCorner.X/divisions
    local zDivisionSize = 2*topRightCorner.Z/divisions

    local attachments = {}
    local vectorForces = {}
    self.VectorForces = vectorForces
    self._HipheightRaycastAttachments = attachments
    self._vectorSpringDragForce = setupVectorForceRelativeToWorld(data._CenterAttachment, rootPart, true)
    self.OnGround = true --Readable property

    --Vector force representing the spring forces
    self._CenterSpringVectorForce = setupVectorForceRelativeToWorld(data._CenterAttachment, rootPart, true)

    local alignAttach = Instance.new("Attachment")
    alignAttach.Position = data._CenterAttachment.WorldPosition
    alignAttach.Parent = workspace.Terrain

    local alignPosition = Instance.new("AlignPosition")
    alignPosition.RigidityEnabled = false
    alignPosition.Attachment0 = data._CenterAttachment
    alignPosition.Attachment1 = alignAttach
    alignPosition.Parent = workspace

    self._AlignPosition = alignPosition
    self._AlignAttach1 = alignAttach
    --0,1,2,3,4,5
    --Multiple raycasts across rootpart
    for x = 0, divisions  do
        for z = 0, divisions do
            local position = Vector3.new(xDivisionSize*x-topRightCorner.X,0,zDivisionSize*z-topRightCorner.Z)
            local attachment = Instance.new("Attachment")
            attachment.Position = position
            attachment.Parent = rootPart
            table.insert(attachments, attachment)
        end
    end
    local model = data._Model

    -- model:SetAttribute("Suspension", 1000) --Not used anymore, now calculated using hipheight and SpringFreeLengthRatio
    model:SetAttribute("SpringFreeLengthRatio", 2)
    model:SetAttribute("Bounce", 3)

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
        hipHeight = model["Left Leg"].Size.Y + rootPart.Size.Y*0.5 -- + 0.5
    else
        hipHeight = humanoid.HipHeight + rootPart.Size.Y*0.5  --+ 0.5
    end
    model:SetAttribute(HIPHEIGHT_ATTRIBUTE_NAME, hipHeight)    

    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {model}
    self.RayParams = raycastParams
end
local DOWN_VECTOR = -Vector3.yAxis

local function predictVelocity(currentNetForce, mass, currentYVelocity, timeStep : number)
    local acceleration = currentNetForce/mass --F = ma
    local addedVelocity = acceleration*timeStep --Integrate acceleration, assuming constant acceleration
    return currentYVelocity + addedVelocity , addedVelocity
end

local function predictDisplacement(currentNetForce, mass, currentYVelocity, timeStep)
    local acceleration = currentNetForce/mass --F = ma
    return currentYVelocity*timeStep + 0.5*acceleration*timeStep^2
end

local function roundToDecimal(number, decimal)
    local factor = 10^decimal
    return math.round(number*factor)/factor
end

local function calculateSpringState(hipheightAttachments, freeLengthOfSpring, rayParams, rootPart)
    local onGround = false

    local maxExtension = 0
    local minimumSpringLength = 0
    local signOfExtensionValue = 0
    local totalNormalVector = Vector3.zero
    local GlobalRaycastResult
    for _, attachment : Attachment in pairs(hipheightAttachments) do
        local raycastResult = workspace:Raycast(attachment.WorldPosition, DOWN_VECTOR*freeLengthOfSpring, rayParams)
        if raycastResult then
            local currentSpringLength = (raycastResult.Position - rootPart.Position).Magnitude
            
            --Taken from X_O Jeep, a bit too bouncy spring  
            --(hipHeight - currentSpringLength)^2) * (suspensionForceFactor / hipHeight^2)  
            --(suspensionForceFactor / hipHeight^2)
            local extension = freeLengthOfSpring - currentSpringLength

            --take the biggest extension, more extension = more force needed
            local absExtension = math.abs(extension)
            if maxExtension < absExtension then
                maxExtension = absExtension
                minimumSpringLength = currentSpringLength
                signOfExtensionValue = math.sign(extension)
            end
            GlobalRaycastResult = raycastResult 

            --Currently uses F = k * dx spring, k = spring constant, dx = extension
            totalNormalVector += raycastResult.Normal
            onGround = true
        end
    end
    local averageNormalVector = totalNormalVector / (#hipheightAttachments)

    local extension = maxExtension*signOfExtensionValue

    return extension, averageNormalVector, onGround, minimumSpringLength, GlobalRaycastResult
end

--Luanoid method of hipheight, works great and rigid however cannot solve for overshoot, ends up bouncy
local function calculateForces(targetHeight, currentHeight, currentYVelocity, t, mass, hipHeight, dt)
    -- counter gravity and then solve constant acceleration eq
    -- (x1 = x0 + v*t + 0.5*a*t*t) for a to aproach target height over time
    local aUp = workspace.Gravity + 2*((targetHeight - currentHeight) - currentYVelocity*t)/(t*t)

    -- Don't go past a maxmium velocity or we'll overshoot our target height.
    -- Calculate the intitial velocity that under constant acceleration would crest at the target height.
    -- Humans can't really thrust downward, just allow gravity to pull us down. So if we go over this 
    -- velocity we'll overshoot the target height and "jump." This is the physical limit for responsiveness.
    -- local deltaHeight = math.max((targetHeight - currentHeight)*1.000001, 0) -- 1% fudge factor to prevent jitter while idle
    -- deltaHeight = math.min(deltaHeight, hipHeight)
    -- local maxUpVelocity = math.sqrt(2.0*workspace.Gravity*deltaHeight)
    -- -- Upward acceleration that would cause us to achieve this velocity in one step
    -- -- Would /dt, but not using dt here. Our dt jumps is weird due to throttling and the physics solver using a 240Hz 
    -- -- step rate internally, not always the right thing for us here. Having to deal with not having a proper step event...
    --  local maxUpImpulse = math.max((maxUpVelocity - currentYVelocity)*60/dt, 0)
    -- aUp = math.min(aUp, maxUpImpulse)
    aUp = math.max(-1, aUp)

    return aUp*mass
end

function HipHeight:Update(data : PhysicsCharacterController, dt)
    local rootPart = data.RootPart
    local stateMachine = data._StateMachine
    local model = self.PhysicsCharacterController._Model
    local hipHeight = model:GetAttribute(HIPHEIGHT_ATTRIBUTE_NAME) or 2.5
    local mass = rootPart.AssemblyMass
    local hipheightAttachments = self._HipheightRaycastAttachments

    local freeLengthRatio = model:GetAttribute("SpringFreeLengthRatio") or 1.5 --Length of the raycast spring, compared to the hipheight
    local freeLengthOfSpring = hipHeight*freeLengthRatio
    --Calculate spring constant, for given hipheight against gravity, from equilibrium
    local weight = mass*workspace.Gravity
    local ratio = hipHeight*(freeLengthRatio-1)
    local totalSuspensionValue = weight/ratio

    local extension, averageNormalVector, onGround, minimumSpringLength, GlobalRaycastResult = calculateSpringState(hipheightAttachments, freeLengthOfSpring, self.RayParams, rootPart)
    self.OnGround = onGround
    -- print(extension, hipHeight, freeLengthOfSpring)

    local springVectorForce : VectorForce = self._CenterSpringVectorForce
    local dragVectorForce = self._vectorSpringDragForce

    local bounce = model:GetAttribute("Bounce")

    local alignPosition : AlignPosition = self._AlignPosition
    local alignAttach : Attachment = self._AlignAttach1
    local rootPartPosition = rootPart.Position

    alignAttach.Position = rootPartPosition

    --Disable hipheight spring when jumping, or else spring forces will assist in the players jump
    if onGround and stateMachine.current ~= "Jumping" then
        --Calculate initial spring force
        local targetHeight = GlobalRaycastResult.Position.Y + hipHeight

        local currentYVelocity = rootPart.AssemblyLinearVelocity.Y
        local rootPartPosition = rootPart.Position
        local currentHeight = rootPartPosition.Y
		local t = 0.05

        -- self._AlignPosition = alignPosition
        alignPosition.Enabled = true

        -- springVectorForce.Force = Vector3.new(0,upwardForce,0)
    else
        self._vectorSpringDragForce.Force  = ZERO_VECTOR
        springVectorForce.Force = ZERO_VECTOR
        alignPosition.Enabled = false
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

    for i,v in pairs(self._HipheightRaycastAttachments) do
        v:Destroy()
    end

end

return HipHeight
