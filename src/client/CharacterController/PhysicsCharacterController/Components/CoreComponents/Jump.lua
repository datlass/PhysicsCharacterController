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
    local data = self.PhysicsCharacterController
    local stateMachine = data._StateMachine
    local hipHeightObject = data:GetComponent("HipHeight")
    assert(hipHeightObject, "Running Component requires HipHeight Component make sure the :Add(HipHeightModuleScript) on Physics Character Controller")

    local onGround = hipHeightObject.OnGround

    if (not self._JumpDebounce) and onGround then
		self._JumpDebounce = true
		onGround = false
		data.RootPart:ApplyImpulse(UP_VECTOR*1000)
        if stateMachine.current == "Standing" then
            stateMachine.jump()
        elseif stateMachine.current == "Running" then
            stateMachine.leap()
        end
        self.JumpAnimTransitionTime = 0.31
		task.wait(0.2)
		self._JumpDebounce = false
	end
end

function Jump:Destroy()

end

return Jump
