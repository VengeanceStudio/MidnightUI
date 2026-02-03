
if not UnitFrames then return end
-- MidnightUI UnitFrames: Target of Target Frame Module




function UnitFrames:GetTargetTargetOptions_Real()
    return self:GenerateFrameOptions("Target of Target Frame", "targettarget", "CreateTargetTargetFrame", "MidnightUI_TargetTargetFrame")
end

-- Add any targettarget-specific logic here
