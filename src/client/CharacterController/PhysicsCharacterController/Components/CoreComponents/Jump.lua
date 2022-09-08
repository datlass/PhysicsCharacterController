export type PhysicsCharacterController = {
    RootPart : BasePart, --Rootpart
    _Model : Model,
    _CenterAttachment : Attachment,
    _MovementComponent : {},
    _XZ_Speed : Vector3,
    _XZ_Velocity : Vector3,
    Velocity : Vector3,
}

local Jump = {}
Jump.__index = Jump

function Jump.new(data : PhysicsCharacterController)
    local self = setmetatable({}, Jump)

    self.PhysicsCharacterController = data
    local rootPart = self.PhysicsCharacterController.RootPart

    local model = data._Model
    model:SetAttribute("JumpPower", 1000)
    model:SetAttribute("JumpDebounceTime", 0.2)

    self.MassPerForce = rootPart.AssemblyMass

    self._JumpDebounce = false
    self.JumpAnimTransitionTime = 0

    --Uses UIS jump request
    self.UseJumpRequest = true

    return self
end

local UP_VECTOR = Vector3.yAxis

local hipHeightModule = script.Parent.HipHeight

function Jump:InputBegan()
    local data : PhysicsCharacterController = self.PhysicsCharacterController
    local stateMachine = data._StateMachine
    local hipHeightObject = data:GetComponent("HipHeight")
    assert(hipHeightObject, "Running Component requires HipHeight Component make sure the :Add(HipHeightModuleScript) on Physics Character Controller")

    local onGround = hipHeightObject.OnGround

    if (not self._JumpDebounce) and onGround then
		self._JumpDebounce = true
		onGround = false
        self:_RawJump(data)
        local waitTime = data._Model:GetAttribute("JumpDebounceTime")

		task.wait(waitTime)
		self._JumpDebounce = false
	end
end

function Jump:_RawJump(data, decreaseJumpPower)
    local stateMachine = data._StateMachine

    decreaseJumpPower = decreaseJumpPower or 0

    local jumpPower = data._Model:GetAttribute("JumpPower") - decreaseJumpPower
    
    jumpPower = math.max(0, jumpPower)

    data.RootPart:ApplyImpulse(UP_VECTOR*jumpPower)

    if stateMachine.current == "Standing" then
        stateMachine.jump()
    elseif stateMachine.current == "Running" then
        stateMachine.leap()
    end
    self.JumpAnimTransitionTime = 0.31
end
function Jump:Destroy()

end

return Jump
