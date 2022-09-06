--[[
    Class that handles movement components
    Mostly used for storing data required such as root part and model
    Also can handle input

    MIT License

    Copyright (c) 2022 dthecoolest

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

    Uses FSM module version from Daniel Perez Alvarez:
    
    MIT License from that project:
    https://github.com/unindented/lua-fsm
    Copyright (c) 2016 Daniel Perez Alvarez

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
]]
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local fsm = require(script.fsm)
local XZ_VECTOR = Vector3.new(1,0,1)
local ZERO_VECTOR = Vector3.zero

local COMPONENTS_FOLDER : Folder = script.Components
local CORE_COMPONENTS_FOLDER : Folder = COMPONENTS_FOLDER.CoreComponents
local MOVEMENT_COMPONENTS_ARRAY = CORE_COMPONENTS_FOLDER:GetChildren()

local Signal = require(script.Signal)

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

local PhysicsCharacterController : PhysicsCharacterController = {}
PhysicsCharacterController.__index = PhysicsCharacterController

function PhysicsCharacterController.new(rootPart : BasePart, humanoid : Humanoid?)
    local self = setmetatable({}, PhysicsCharacterController)

    local model = rootPart:FindFirstAncestorOfClass("Model")
    assert(model, "Rootpart should have a model")
    self._Model = model

    self.RootPart = rootPart
    
    local charEvents = {
        {name = "run",  from = "Standing",  to = "Running"},
        {name = "jump", from = "Standing", to = "Jumping"   },
        {name = "leap", from = "Running", to = "Jumping"   },
        {name = "fall",  from = "Jumping",    to = "FreeFalling"},
        {name = "land", from = "FreeFalling", to = "Landed" },
        {name = "recover", from = "Landed", to = "Standing" },
        {name = "stand",  from = "Running",  to = "Standing"},
    } 

    local StateSignal = {}

    for _, event in pairs(charEvents) do
        local signal = Signal.new()
        local state = event.to
        StateSignal[state] = signal
    end

    self._StateSignals = StateSignal

    local charCallbacks = {}

    for state : string, signal in pairs(StateSignal) do
        charCallbacks["on_"..state] = function(self, event, from, to)
            if state == "Running" then
                local speedVector = rootPart.AssemblyLinearVelocity*XZ_VECTOR
                signal:Fire(speedVector.Magnitude)
                return
            end
            signal:Fire()
        end
    end

    self._StateMachine = fsm.create({
		initial = "Standing",
		events = charEvents,
		callbacks = charCallbacks
	})

    self._RunLoop = true
    task.spawn(function()
        while model.Parent ~= nil and self._RunLoop do
            if  self._StateMachine.current == "Running" then
                local speedVector = rootPart.AssemblyLinearVelocity*XZ_VECTOR
                StateSignal.Running:Fire(speedVector.Magnitude)
            end
            
            RunService.Heartbeat:Wait()
        end
    end)


    self._ValidJumpingStates = {
        Standing = true;
        Running = true;
    }
    
    local centerAttachment = Instance.new("Attachment")
    centerAttachment.WorldPosition = rootPart.CenterOfMass
    centerAttachment.Parent = rootPart
    self._CenterAttachment = centerAttachment
        
    --XZ Movement
    

    self._MovementComponents = {}
    return self
end

function PhysicsCharacterController:AddComponent(componentModule : ModuleScript)
    local componentInitializer = require(componentModule)
    local component = componentInitializer.new(self)
    self._MovementComponents[componentModule] = component

end

function PhysicsCharacterController:RemoveComponent(componentModule)

    local existingComponent = self._MovementComponents[componentModule]
    existingComponent:Destroy()
    self._MovementComponents[componentModule] = nil

end

function PhysicsCharacterController:AddDefaultComponents()
    for i, module in pairs(MOVEMENT_COMPONENTS_ARRAY) do
        
        self:AddComponent(module)
    end
end

function PhysicsCharacterController:Update(moveDirection : Vector3, deltaTime)
    local rootPart = self.RootPart
	local rootVelocity = rootPart.AssemblyLinearVelocity
	local xzVelocity = rootVelocity*XZ_VECTOR
	local xzSpeed = xzVelocity.Magnitude
	local unitXZ = (xzVelocity).Unit

    self._XZ_Speed = xzSpeed
    self._XZ_Velocity = xzVelocity
    self._RootPartUnitXZVelocity = unitXZ
    self.Velocity = rootVelocity
    self.MoveDirection = moveDirection

    for i, component in pairs(self._MovementComponents) do
        if component.Update then
            component:Update(self, deltaTime)
        end
    end

end

function PhysicsCharacterController:InitUpdateDefaultControls()
    local PlayerModule = require(game.Players.LocalPlayer.PlayerScripts.PlayerModule)
    local Controls = PlayerModule:GetControls()
    local humanoid = self._Model:FindFirstChild("Humanoid")

    local connection
    connection = RunService.Stepped:Connect(function(time, deltaTime)
        if self._Model.Parent == nil then
            --Automatic clean up upon character respawn
            connection:Disconnect()
        end
        self:Update(humanoid.MoveDirection, deltaTime)
    end)

    --For jump use JumpRequest
    local jumpModuleScript : ModuleScript = CORE_COMPONENTS_FOLDER.Jump
    local jumpObject = self._MovementComponents[jumpModuleScript]
    local jumpConnection 
    jumpConnection = UserInputService.JumpRequest:Connect(function()
        if self._Model.Parent == nil then
            --Automatic clean up upon character respawn
            jumpConnection:Disconnect()
        end
        jumpObject:InputBegan()
    end)
end

--To do add
function PhysicsCharacterController:Destroy()
    for i, componentObject in pairs(self._MovementComponents) do
        componentObject:Destroy()
    end
    self._CenterAttachment:Destroy()
    self._RunLoop = false
    
    for state : string, signal in pairs(self._StateSignals) do
        signal:DisconnectAll()
    end
end


return PhysicsCharacterController
