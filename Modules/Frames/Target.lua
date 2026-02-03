
if not UnitFrames then return end
-- MidnightUI UnitFrames: Target Frame Module




function UnitFrames:GetTargetOptions_Real()
    return self:GenerateFrameOptions("Target Frame", "target", "CreateTargetFrame", "MidnightUI_TargetFrame")
end

-- Add any target-specific logic here
