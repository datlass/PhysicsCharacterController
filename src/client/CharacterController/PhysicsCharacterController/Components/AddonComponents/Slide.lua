export type PhysicsCharacterController = {
    RootPart : BasePart, --Rootpart
    _Model : Model,
    _CenterAttachment : Attachment,
    _MovementComponent : {},
    _XZ_Speed : Vector3,
    _XZ_Velocity : Vector3,
    Velocity : Vector3,
}

local Slide = {}
Slide.__index = Slide

function Slide.new(data : PhysicsCharacterController)
    local self = setmetatable({}, Slide)

    self.PhysicsCharacterController = data
    local rootPart = self.PhysicsCharacterController.RootPart

    local model = data._Model
    
    self.MassPerForce = rootPart.AssemblyMass

    self._SlideDebounce = false

    self.SlideAnimTransitionTime = 0

    self.KeyCodes = {Enum.KeyCode.F}

    return self
end

local UP_VECTOR = Vector3.yAxis

function Slide:InputBegan()
    local data : PhysicsCharacterController = self.PhysicsCharacterController
    local stateMachine = data._StateMachine
    local hipHeightObject = data:GetComponent("HipHeight")
    assert(hipHeightObject, "Slide Component requires HipHeight Component make sure the :Add(HipHeightModuleScript) on Physics Character Controller")

    local autoRotateObject = data:GetComponent("AutoRotate")
    self._AutoRotateObject = autoRotateObject

    local onGround = hipHeightObject.OnGround

    local model = data._Model
    local originalDragValue = model:GetAttribute("XZDragFactorVSquared")
    local walkSpeed = model:GetAttribute("WalkSpeed")

    self._OriginalWalkSpeed = walkSpeed
    self._OriginalDragValue = originalDragValue

    if (not self._SlideDebounce) then
		self._SlideDebounce = true
		onGround = false
        local rootPart = data.RootPart
        model:SetAttribute("XZDragFactorVSquared", 0)
        model:SetAttribute("WalkSpeed", 0)

        -- model:SetAttribute("Suspension", 26000)
        model:SetAttribute("Bounce", 200)
        -- local waist = model:FindFirstChild("Root", true)
        -- if waist then
        --     self._C0_ORIGINAL = waist.C0
        --     waist.C0 = CFrame.new(0,0,0)*CFrame.Angles(math.rad(90),0,0)
        -- end

        self._AutoRotateObject.ShouldUpdate = false
        -- local alignOrientation : AlignOrientation = self._AutoRotateObject.AlignOrientation
		-- self._OriginalAlignMaxTorque = alignOrientation.MaxTorque
        -- alignOrientation.MaxTorque = 0
        
        rootPart:ApplyImpulse(rootPart.CFrame.LookVector*2000)
		task.wait(0.2)
		self._SlideDebounce = false
	end
end

function Slide:InputEnd()
    local data : PhysicsCharacterController = self.PhysicsCharacterController

    local model = data._Model
    if self._AutoRotateObject then
        self._AutoRotateObject.ShouldUpdate = true
        -- local alignOrientation : AlignOrientation = self._AutoRotateObject.AlignOrientation
        -- alignOrientation.MaxTorque = self._OriginalAlignMaxTorque

    end
    -- model:SetAttribute("Suspension", 21000)
    model:SetAttribute("Bounce", 25)
    -- local waist = model:FindFirstChild("Root", true)
    -- if waist then
    --     print(waist)
    --     waist.C0 = self._C0_ORIGINAL
    -- end

    model:SetAttribute("WalkSpeed", self._OriginalWalkSpeed)
    model:SetAttribute("XZDragFactorVSquared", self._OriginalDragValue)

end


function Slide:Destroy()

end

return Slide
