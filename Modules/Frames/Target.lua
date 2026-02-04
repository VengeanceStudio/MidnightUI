
local UnitFrames = MidnightUI:GetModule("UnitFrames")
if not UnitFrames then return end
-- MidnightUI UnitFrames: Target Frame Module

-- ============================================================================
-- TARGET FRAME CREATION
-- ============================================================================

function UnitFrames:CreateTargetFrame()
    if not self.db.profile.showTarget then return end
    local db = self.db.profile
    -- Anchor TargetFrame to CENTER
    local anchorTo = UIParent
    local posX = (db.target and db.target.posX) or 0
    local posY = (db.target and db.target.posY) or 0
    self:CreateUnitFrame("TargetFrame", "target", anchorTo, "CENTER", "CENTER", posX, posY)
    -- Only show TargetFrame if a target exists
    local customTargetFrame = _G["MidnightUI_TargetFrame"]
    if customTargetFrame then
        -- Start hidden - state driver will show when target exists
        customTargetFrame:Hide()
        -- Also hide child bars explicitly (they don't auto-hide with parent)
        if customTargetFrame.healthBar then customTargetFrame.healthBar:Hide() end
        if customTargetFrame.powerBar then customTargetFrame.powerBar:Hide() end
        if customTargetFrame.infoBar then customTargetFrame.infoBar:Hide() end
        -- Safely unregister/register state drivers (protected call)
        if not InCombatLockdown() then
            UnregisterStateDriver(customTargetFrame, "visibility")
            RegisterStateDriver(customTargetFrame, "visibility", "[@target,exists] show; hide")
        end
        -- If target exists right now, force update
        if UnitExists("target") then
            self:UpdateUnitFrame("TargetFrame", "target")
        end
    end
end

-- ============================================================================
-- OPTIONS
-- ============================================================================

function UnitFrames:GetTargetOptions_Real()
    return self:GenerateFrameOptions("Target Frame", "target", "CreateTargetFrame", "MidnightUI_TargetFrame")
end
