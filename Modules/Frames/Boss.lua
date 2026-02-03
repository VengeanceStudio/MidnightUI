
if not UnitFrames then return end
-- MidnightUI UnitFrames: Boss Frames Module




function UnitFrames:GetBossOptions_Real()
    return self:GenerateFrameOptions("Boss Frames", "boss", "CreateBossFrames", "MidnightUI_Boss1Frame")
end

-- Add any boss-specific logic here
