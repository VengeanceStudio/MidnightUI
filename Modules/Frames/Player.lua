
if not UnitFrames then return end
-- MidnightUI UnitFrames: Player Frame Module

function UnitFrames:GetPlayerOptions_Real()
    return self:GenerateFrameOptions("Player Frame", "player", "CreatePlayerFrame", "MidnightUI_PlayerFrame")
end

