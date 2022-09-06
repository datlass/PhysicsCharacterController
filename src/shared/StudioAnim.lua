--[[
    Credits to @EgoMoose

    --Command bar code to setup studio animation
local core = game.ReplicatedStorage.CustomMovement;
local studioAnim = require(core.Utility:WaitForChild("StudioAnim"));
local animations = core:WaitForChild("Animations");
studioAnim(animations);
--]]

local RUNSERVICE = game:GetService("RunService");
local KFSP = game:GetService("KeyframeSequenceProvider");

local function convert(anim)
	local kfs = anim:FindFirstChildWhichIsA("KeyframeSequence");
	if (kfs) then
		anim.AnimationId = KFSP:RegisterKeyframeSequence(kfs);
	end
end

return function(animFolder)
	for k, anim in next, animFolder:GetChildren() do
		convert(anim);
	end
end