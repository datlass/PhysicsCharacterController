local RunService = game:GetService("RunService")
export type PhysicsCharacterController = {
    RootPart : BasePart, --Rootpart
    _Model : Model,
    _CenterAttachment : Attachment,
    _MovementComponent : {},
    _XZ_Speed : Vector3,
    _XZ_Velocity : Vector3,
    Velocity : Vector3,
}

local mouse = game.Players.LocalPlayer:GetMouse()

local Web = {}
Web.__index = Web

function Web.new(data : PhysicsCharacterController)
    local self = setmetatable({}, Web)
    self.Name = "Web"
    print("Web")
    self.PhysicsCharacterController = data
    local rootPart = self.PhysicsCharacterController.RootPart

    local model = data._Model

    self.MassPerForce = rootPart.AssemblyMass

    --Uses UIS Web request
    self.KeyCodes = {Enum.KeyCode.E}


    return self
end

local UP_VECTOR = Vector3.yAxis
local web
local originalDrag = 0

local connection
local function getRotationBetween(u, v, axis)
	local dot, uxv = u:Dot(v), u:Cross(v)
	if (dot < -0.99999) then return CFrame.fromAxisAngle(axis, math.pi) end
	return CFrame.new(0, 0, 0, uxv.x, uxv.y, uxv.z, 1 + dot)
end


function Web:InputBegan()
    local data : PhysicsCharacterController = self.PhysicsCharacterController
    local stateMachine = data._StateMachine
    
    local target = Instance.new("Attachment")
    target.Position = data.RootPart.CFrame*CFrame.new(0,50,-50).Position
    target.Parent = workspace.Terrain

    local spring = Instance.new("SpringConstraint")
    spring.Attachment0 = data._CenterAttachment
    spring.Attachment1 = target
    spring.Visible = true
    local vector = target.Position-data._CenterAttachment.WorldPosition
    spring.FreeLength = (vector).Magnitude/3
    spring.Stiffness = 150
    spring.Parent = workspace

    if data._Model:GetAttribute("XZDragFactorVSquared") >= 0.0001 then
        originalDrag = data._Model:GetAttribute("XZDragFactorVSquared")
    end
    data._Model:SetAttribute("XZDragFactorVSquared",0.000001)

    local autoRotateObject = data:GetComponent("AutoRotate")
    local alignmentAttachment = autoRotateObject._AlignmentAttachment

    local rootPart = data.RootPart
    -- rootPart.Transparency = 0
    local function getCF()
        local newVector = target.Position-data._CenterAttachment.WorldPosition

        return getRotationBetween(autoRotateObject._AlignmentAttachment.WorldCFrame.UpVector, newVector.Unit,Vector3.xAxis)
    end
    autoRotateObject.getCF = getCF

    web = spring
end

function Web:InputEnd()
    local data : PhysicsCharacterController = self.PhysicsCharacterController
    local stateMachine = data._StateMachine
    task.spawn(function()
        --Still hacky fix later
        task.wait(0.9)
        if web == nil then
            data._Model:SetAttribute("XZDragFactorVSquared",originalDrag)
        end
    end)

    local autoRotateObject = data:GetComponent("AutoRotate")
    autoRotateObject._OverrideCF = nil
    autoRotateObject.getCF = nil

    web:Destroy()
    web = nil
end


function Web:Destroy()

end

return Web
