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
    model:SetAttribute("SpringFreeLengthRatio", 1.5)
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
    local signOfExtensionValue = 0
    local totalNormalVector = Vector3.zero
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
                signOfExtensionValue = math.sign(extension)
            end
            --Currently uses F = k * dx spring, k = spring constant, dx = extension
            totalNormalVector += raycastResult.Normal
            onGround = true
        end
    end
    local averageNormalVector = totalNormalVector / (#hipheightAttachments)

    local extension = maxExtension*signOfExtensionValue

    return extension, averageNormalVector, onGround
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

    local extension, averageNormalVector, onGround = calculateSpringState(hipheightAttachments, freeLengthOfSpring, self.RayParams, rootPart)
    self.OnGround = onGround
    -- print(extension, hipHeight, freeLengthOfSpring)
    -- print(freeLengthOfSpring - extension) --equals hipheight

    local springVectorForce : VectorForce = self._CenterSpringVectorForce
    local dragVectorForce = self._vectorSpringDragForce

    local bounce = model:GetAttribute("Bounce")

    --Disable hipheight spring when jumping, or else spring forces will assist in the players jump
    if onGround and stateMachine.current ~= "Jumping" then
        --Calculate initial spring force
        local springForce = totalSuspensionValue*(extension) -- F = -kx spring formula
        -- springForce = math.clamp(springForce, 0, weight*1.1) --works a bit but not completely, also causes legs to sink into the ground due to no upward force
    
        local standupForce = Vector3.yAxis*springForce
    
        local netForce = springForce - weight
    
        springVectorForce.Force = standupForce

        --Taken from X_O Jeep, works great
        local damping = totalSuspensionValue/bounce
        -- F = - cV 
        local currentYVelocity = rootPart.AssemblyLinearVelocity.Y

        local newDragYForce = -currentYVelocity*damping
        
        netForce += newDragYForce

        -- print(roundToDecimal(currentYVelocity, 2), roundToDecimal(velocityPrediction, 2))
        dragVectorForce.Force  = Vector3.new(0,newDragYForce,0)

        local substepDivisions = 5 --Smaller the time increments the better it seems, probably due to integration overshoot
        local substepTimeIncrement = dt/substepDivisions
        --Perform substep
        local predictedVelocity = predictVelocity(netForce, mass, currentYVelocity, substepTimeIncrement)
        local predictedDisplacement = predictDisplacement(netForce, mass, currentYVelocity, substepTimeIncrement)
        local newExtension = extension + predictedDisplacement

        local springLength = freeLengthOfSpring - extension

        local predictedDrag = -predictedVelocity*damping

        
        local predictedSpringForce
        local predictedNewSpringLength = springLength + predictedDisplacement
        if predictedNewSpringLength > hipHeight then
            predictedSpringForce = 0
        else
            predictedSpringForce = totalSuspensionValue*(newExtension)
        end

        local averageDrag = (predictedDrag + newDragYForce) * 0.5
        local averageSpringForce = (predictedSpringForce + springForce) * 0.5

        self._vectorSpringDragForce.Force = Vector3.new(0,averageDrag,0)
        springVectorForce.Force = Vector3.new(0,averageSpringForce,0)

        --Perform another substep experimental, probably should clean it up into a function
        --Continues from the previous substep
        local newNetForce = averageDrag + averageSpringForce - weight

        local predictedVelocity = predictVelocity(newNetForce, mass, predictedVelocity, substepTimeIncrement)
        local predictedDisplacement = predictDisplacement(newNetForce, mass, predictedDisplacement, substepTimeIncrement)
        local newExtension = extension + predictedDisplacement
        local predictedDrag = -predictedVelocity*damping

        local predictedSpringForce
        local predictedNewSpringLength = predictedNewSpringLength + predictedDisplacement
        if predictedNewSpringLength > hipHeight then
            predictedSpringForce = 0
        else
            predictedSpringForce = totalSuspensionValue*(newExtension)
        end

        local averageDrag = (predictedDrag + averageDrag) * 0.5
        local averageSpringForce = (predictedSpringForce + averageSpringForce) * 0.5

        self._vectorSpringDragForce.Force = Vector3.new(0,averageDrag,0)
        springVectorForce.Force = Vector3.new(0,averageSpringForce,0)
    else
        self._vectorSpringDragForce.Force  = ZERO_VECTOR
        springVectorForce.Force = ZERO_VECTOR

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
