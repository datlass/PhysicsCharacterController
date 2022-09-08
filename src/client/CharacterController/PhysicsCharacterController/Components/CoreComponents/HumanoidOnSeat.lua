--[[
    Fixes bug with humanoid on seat
]]

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

local HumanoidOnSeat = {}
HumanoidOnSeat.__index = HumanoidOnSeat


function HumanoidOnSeat.new(data : PhysicsCharacterController)
    local self = setmetatable({}, HumanoidOnSeat)

    local humanoid : Humanoid = data._Model:FindFirstChild("Humanoid")
    print("Humanoid on seat init")
    -- humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    if humanoid then
        self._SeatedConnection = humanoid.Seated:Connect(function(active, currentSeatPart)
            humanoid.UseJumpPower = false
            humanoid.JumpHeight = 0.000000000000000000000001

            if active == false then
                local tries = 0
                --Problem platform standing is set to false by server on unseat
                task.spawn(function()
                    while humanoid.PlatformStand == false do
                        humanoid.PlatformStand = true
                        tries += 1
                        -- print(tries, " Try test") --Usually only needs 1
                        task.wait()
                    end
                end)
            end
        end)

        local debounce = false
        self._PlatformStanding = humanoid.PlatformStanding:Connect(function(active)
            if active == false and humanoid.SeatPart == nil then
                local debounceTime = data._Model:GetAttribute("JumpDebounceTime")
                local Jump = data:GetComponent("Jump")
        
                humanoid.PlatformStand = true
                if not debounce then
                    debounce = true
                    print("Jump")
                    Jump:_RawJump(data, 240)

                    task.wait(debounceTime)
                    debounce = false
                end
            end
        end)

    end
    return self
end


function HumanoidOnSeat:Destroy()
    if self._SeatedConnection then
        self._SeatedConnection:Disconnect()
    end
    if self._PlatformStanding then
        self._PlatformStanding:Disconnect()
    end

end


return HumanoidOnSeat
