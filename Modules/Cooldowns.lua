local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local Cooldowns = MidnightUI:NewModule("Cooldowns", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- Get ColorPalette and FontKit from Framework
local ColorPalette = MidnightUI.ColorPalette
local FontKit = MidnightUI.FontKit

-- -----------------------------------------------------------------------------
-- DATABASE DEFAULTS
-- -----------------------------------------------------------------------------
local defaults = {
    profile = {
        enabled = true,
        
        -- Blizzard Cooldown Manager Skinning
        skinCooldownManager = true,
        skinActionBars = true,
        
        -- Frame
        scale = 1.0,
        alpha = 1.0,
        
        -- Icon styling
        iconSize = 40,
        iconSpacing = 4,
        borderSize = 2,
        hideBlizzardArt = true,
        
        -- Colors
        backgroundColor = {0.05, 0.05, 0.05, 0.9},
        borderColor = {0.2, 0.8, 1.0, 1.0}, -- Teal border
        
        -- Font
        font = "Expressway",
        fontSize = 18,
        fontFlag = "OUTLINE",
        fontColor = {1, 1, 1, 1},
        
        -- Positioning for resource bar attachment
        attachToResourceBar = false,
        attachPosition = "BOTTOM", -- BOTTOM, TOP, LEFT, RIGHT
        attachOffsetX = 0,
        attachOffsetY = -2,
    }
}

-- -----------------------------------------------------------------------------
-- INITIALIZATION
-- -----------------------------------------------------------------------------
function Cooldowns:OnInitialize()
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "OnDBReady")
    self.styledFrames = {}
    self.cooldownFrames = {}
end

function Cooldowns:OnDBReady()
    if not MidnightUI.db or not MidnightUI.db.profile or not MidnightUI.db.profile.modules.cooldowns then
        self:Disable()
        return
    end
    
    self.db = MidnightUI.db:RegisterNamespace("Cooldowns", defaults)
    
    -- Register events
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
end

function Cooldowns:PLAYER_ENTERING_WORLD()
    C_Timer.After(1, function()
        self:InitializeCooldownSkinning()
    end)
end

function Cooldowns:ACTIONBAR_UPDATE_COOLDOWN()
    if self.db.profile.skinActionBars then
        self:SkinActionBarCooldowns()
    end
end

function Cooldowns:SPELL_UPDATE_COOLDOWN()
    if self.db.profile.skinCooldownManager then
        self:UpdateCooldownDisplay()
    end
end

-- -----------------------------------------------------------------------------
-- SKIN BLIZZARD COOLDOWN MANAGER AND ACTION BARS
-- -----------------------------------------------------------------------------
function Cooldowns:InitializeCooldownSkinning()
    if self.db.profile.skinActionBars then
        self:SkinActionBarCooldowns()
    end
    
    if self.db.profile.skinCooldownManager then
        self:SkinPlayerSpellActivationAlerts()
    end
    
    -- Hook into action button creation
    if not self.hookedActionButtons then
        hooksecurefunc("ActionButton_UpdateCooldown", function(button)
            if button and self.db.profile.skinActionBars then
                self:StyleActionButtonCooldown(button)
            end
        end)
        self.hookedActionButtons = true
    end
end

-- Skin Action Bar Cooldowns (the numbers and swirls on action buttons)
function Cooldowns:SkinActionBarCooldowns()
    local db = self.db.profile
    
    -- Action bars 1-8
    for i = 1, 8 do
        for j = 1, 12 do
            local button = _G["ActionButton"..j] or
                          _G["MultiBarBottomLeftButton"..j] or
                          _G["MultiBarBottomRightButton"..j] or
                          _G["MultiBarRightButton"..j] or
                          _G["MultiBarLeftButton"..j] or
                          _G["MultiBar5Button"..j] or
                          _G["MultiBar6Button"..j] or
                          _G["MultiBar7Button"..j]
            
            if button then
                self:StyleActionButtonCooldown(button)
            end
        end
    end
    
    -- Pet bar
    for i = 1, NUM_PET_ACTION_SLOTS do
        local button = _G["PetActionButton"..i]
        if button then
            self:StyleActionButtonCooldown(button)
        end
    end
    
    -- Stance bar
    for i = 1, NUM_STANCE_SLOTS do
        local button = _G["StanceButton"..i]
        if button then
            self:StyleActionButtonCooldown(button)
        end
    end
end

function Cooldowns:StyleActionButtonCooldown(button)
    if not button or button.midnightCooldownStyled then return end
    
    local db = self.db.profile
    local cooldown = button.cooldown
    
    if cooldown then
        -- Style the cooldown frame
        if db.hideBlizzardArt and cooldown.SetDrawBling then
            cooldown:SetDrawBling(false)
        end
        
        -- Set cooldown text color and font
        if cooldown.SetCountdownFont then
            local fontPath = LSM:Fetch("font", db.font or "Expressway")
            cooldown:SetCountdownFont(fontPath)
        end
        
        -- Apply custom backdrop to icon
        if button.icon then
            button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        
        -- Style border
        if not button.midnightBorder then
            button.midnightBorder = button:CreateTexture(nil, "OVERLAY")
            button.midnightBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
            button.midnightBorder:SetPoint("TOPLEFT", button, "TOPLEFT", -db.borderSize, db.borderSize)
            button.midnightBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", db.borderSize, -db.borderSize)
            button.midnightBorder:SetColorTexture(unpack(db.borderColor))
            button.midnightBorder:SetDrawLayer("OVERLAY", 7)
        end
        
        -- Create inner border cutout
        if not button.midnightInner and button.icon then
            button.midnightInner = button:CreateTexture(nil, "BORDER")
            button.midnightInner:SetTexture("Interface\\Buttons\\WHITE8X8")
            button.midnightInner:SetPoint("TOPLEFT", button.icon, "TOPLEFT", 0, 0)
            button.midnightInner:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 0, 0)
            button.midnightInner:SetColorTexture(0, 0, 0, 1)
        end
    end
    
    button.midnightCooldownStyled = true
end

-- Skin Spell Activation Overlays (proc alerts)
function Cooldowns:SkinPlayerSpellActivationAlerts()
    local db = self.db.profile
    
    -- In WoW 12.0+, the spell activation system uses SpellActivationOverlayFrame
    if SpellActivationOverlayFrame then
        -- Apply scale and alpha
        SpellActivationOverlayFrame:SetScale(db.scale)
        SpellActivationOverlayFrame:SetAlpha(db.alpha)
        
        -- Hook into overlay showing
        if not self.hookedOverlays and SpellActivationOverlayFrame.ShowOverlay then
            hooksecurefunc(SpellActivationOverlayFrame, "ShowOverlay", function(self, spellID, texturePath, position, scale, r, g, b, autoPulse)
                -- Find and style the overlay
                C_Timer.After(0.05, function()
                    Cooldowns:StyleSpellActivationOverlay(spellID)
                end)
            end)
            self.hookedOverlays = true
        end
        
        -- Style existing overlays
        if SpellActivationOverlayFrame.overlays then
            for _, overlay in pairs(SpellActivationOverlayFrame.overlays) do
                self:StyleOverlayFrame(overlay)
            end
        end
    end
end

function Cooldowns:StyleSpellActivationOverlay(spellID)
    if not SpellActivationOverlayFrame or not SpellActivationOverlayFrame.overlays then return end
    
    for _, overlay in pairs(SpellActivationOverlayFrame.overlays) do
        if overlay and overlay:IsShown() then
            self:StyleOverlayFrame(overlay)
        end
    end
end

function Cooldowns:StyleOverlayFrame(overlay)
    if not overlay or overlay.midnightStyled then return end
    
    local db = self.db.profile
    
    -- Create or update border
    if not overlay.midnightBorder then
        overlay.midnightBorder = overlay:CreateTexture(nil, "OVERLAY")
        overlay.midnightBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
        overlay.midnightBorder:SetAllPoints(overlay)
        overlay.midnightBorder:SetColorTexture(unpack(db.borderColor))
        overlay.midnightBorder:SetDrawLayer("OVERLAY", 7)
    else
        overlay.midnightBorder:SetColorTexture(unpack(db.borderColor))
    end
    
    -- Apply custom glow color if texture exists
    if overlay.texture then
        -- You can tint the overlay texture here
        -- overlay.texture:SetVertexColor(unpack(db.borderColor))
    end
    
    overlay.midnightStyled = true
end

function Cooldowns:UpdateCooldownDisplay()
    -- Refresh all styled frames with new colors/settings
    if self.db.profile.skinActionBars then
        for i = 1, 8 do
            for j = 1, 12 do
                local button = _G["ActionButton"..j] or
                              _G["MultiBarBottomLeftButton"..j] or
                              _G["MultiBarBottomRightButton"..j] or
                              _G["MultiBarRightButton"..j] or
                              _G["MultiBarLeftButton"..j] or
                              _G["MultiBar5Button"..j] or
                              _G["MultiBar6Button"..j] or
                              _G["MultiBar7Button"..j]
                
                if button and button.midnightBorder then
                    button.midnightBorder:SetColorTexture(unpack(self.db.profile.borderColor))
                end
            end
        end
    end
end

-- -----------------------------------------------------------------------------
-- RESOURCE BAR ATTACHMENT
-- -----------------------------------------------------------------------------
function Cooldowns:AttachToResourceBar()
    if not self.db.profile.attachToResourceBar then return end
    
    -- Try to find the MidnightUI ResourceBars module
    local ResourceBars = MidnightUI:GetModule("ResourceBars", true)
    if not ResourceBars or not ResourceBars.primaryBar then return end
    
    local db = self.db.profile
    local anchor = ResourceBars.primaryBar
    
    -- Find or create a container for cooldown icons
    if not self.cooldownContainer then
        self.cooldownContainer = CreateFrame("Frame", "MidnightUICooldownContainer", UIParent)
        self.cooldownContainer:SetSize(db.iconSize * 12 + db.iconSpacing * 11, db.iconSize)
    end
    
    -- Position relative to resource bar
    self.cooldownContainer:ClearAllPoints()
    
    if db.attachPosition == "BOTTOM" then
        self.cooldownContainer:SetPoint("TOP", anchor, "BOTTOM", db.attachOffsetX, db.attachOffsetY)
    elseif db.attachPosition == "TOP" then
        self.cooldownContainer:SetPoint("BOTTOM", anchor, "TOP", db.attachOffsetX, db.attachOffsetY)
    elseif db.attachPosition == "LEFT" then
        self.cooldownContainer:SetPoint("RIGHT", anchor, "LEFT", db.attachOffsetX, db.attachOffsetY)
    elseif db.attachPosition == "RIGHT" then
        self.cooldownContainer:SetPoint("LEFT", anchor, "RIGHT", db.attachOffsetX, db.attachOffsetY)
    end
end

function Cooldowns:UpdateAttachment()
    if self.db.profile.attachToResourceBar then
        self:AttachToResourceBar()
    elseif self.cooldownContainer then
        -- Detach and return to default position
        self.cooldownContainer:ClearAllPoints()
        self.cooldownContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- -----------------------------------------------------------------------------
-- OPTIONS
-- -----------------------------------------------------------------------------
function Cooldowns:GetOptions()
    return {
        type = "group",
        name = "Cooldown Manager",
        order = 10,
        args = {
            header = {
                type = "header",
                name = "Cooldown & Action Bar Skinning",
                order = 1
            },
            desc = {
                type = "description",
                name = "Applies MidnightUI styling to action bar cooldowns and spell activation overlays.\n\n" ..
                      "|cffFFFF00Note:|r Changes to colors will update immediately without a UI reload.",
                order = 2
            },
            
            skinActionBars = {
                name = "Skin Action Bar Cooldowns",
                desc = "Apply MidnightUI styling to cooldown timers and borders on action buttons.",
                type = "toggle",
                order = 10,
                width = "full",
                get = function() return self.db.profile.skinActionBars end,
                set = function(_, v)
                    self.db.profile.skinActionBars = v
                    if v then
                        self:SkinActionBarCooldowns()
                    else
                        ReloadUI()
                    end
                end
            },
            
            skinCooldownManager = {
                name = "Skin Spell Activation Overlays",
                desc = "Apply MidnightUI styling to spell proc alerts and activation overlays.",
                type = "toggle",
                order = 11,
                width = "full",
                get = function() return self.db.profile.skinCooldownManager end,
                set = function(_, v)
                    self.db.profile.skinCooldownManager = v
                    if v then
                        self:SkinPlayerSpellActivationAlerts()
                    end
                end
            },
            
            -- Frame Settings
            headerFrame = { type = "header", name = "Frame Settings", order = 20 },
            
            scale = {
                name = "Scale",
                desc = "Scale of spell activation overlays.",
                type = "range",
                order = 21,
                min = 0.5, max = 2.0, step = 0.05,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.scale end,
                set = function(_, v)
                    self.db.profile.scale = v
                    if SpellActivationOverlayFrame then
                        SpellActivationOverlayFrame:SetScale(v)
                    end
                end
            },
            
            alpha = {
                name = "Alpha",
                desc = "Transparency of spell activation overlays.",
                type = "range",
                order = 22,
                min = 0, max = 1, step = 0.05,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.alpha end,
                set = function(_, v)
                    self.db.profile.alpha = v
                    if SpellActivationOverlayFrame then
                        SpellActivationOverlayFrame:SetAlpha(v)
                    end
                end
            },
            
            -- Icon Settings
            headerIcons = { type = "header", name = "Icon Settings", order = 30 },
            
            iconSize = {
                name = "Icon Size",
                desc = "Size of cooldown icons.",
                type = "range",
                order = 31,
                min = 20, max = 80, step = 1,
                disabled = function() return not self.db.profile.skinActionBars end,
                get = function() return self.db.profile.iconSize end,
                set = function(_, v)
                    self.db.profile.iconSize = v
                    -- Action button sizes are controlled by Blizzard's action bar settings
                end
            },
            
            iconSpacing = {
                name = "Icon Spacing",
                desc = "Space between cooldown icons.",
                type = "range",
                order = 32,
                min = 0, max = 20, step = 1,
                disabled = function() return not self.db.profile.skinActionBars end,
                get = function() return self.db.profile.iconSpacing end,
                set = function(_, v)
                    self.db.profile.iconSpacing = v
                end
            },
            
            borderSize = {
                name = "Border Size",
                desc = "Thickness of the border around icons.",
                type = "range",
                order = 33,
                min = 1, max = 5, step = 1,
                disabled = function() return not self.db.profile.skinActionBars end,
                get = function() return self.db.profile.borderSize end,
                set = function(_, v)
                    self.db.profile.borderSize = v
                    ReloadUI()
                end
            },
            
            hideBlizzardArt = {
                name = "Hide Blizzard Cooldown Bling",
                desc = "Hide the default Blizzard cooldown swirl animation.",
                type = "toggle",
                order = 34,
                width = "full",
                disabled = function() return not self.db.profile.skinActionBars end,
                get = function() return self.db.profile.hideBlizzardArt end,
                set = function(_, v)
                    self.db.profile.hideBlizzardArt = v
                    ReloadUI()
                end
            },
            
            -- Colors
            headerColors = { type = "header", name = "Colors", order = 40 },
            
            backgroundColor = {
                name = "Background Color",
                desc = "Background color for cooldown frames.",
                type = "color",
                order = 41,
                hasAlpha = true,
                get = function()
                    local c = self.db.profile.backgroundColor
                    return c[1], c[2], c[3], c[4]
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.backgroundColor = {r, g, b, a}
                    self:UpdateCooldownDisplay()
                end
            },
            
            borderColor = {
                name = "Border Color",
                desc = "Border color for cooldown icons and overlays.",
                type = "color",
                order = 42,
                hasAlpha = true,
                get = function()
                    local c = self.db.profile.borderColor
                    return c[1], c[2], c[3], c[4]
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.borderColor = {r, g, b, a}
                    self:UpdateCooldownDisplay()
                    -- Update action button borders
                    for i = 1, 8 do
                        for j = 1, 12 do
                            local button = _G["ActionButton"..j] or
                                          _G["MultiBarBottomLeftButton"..j] or
                                          _G["MultiBarBottomRightButton"..j] or
                                          _G["MultiBarRightButton"..j] or
                                          _G["MultiBarLeftButton"..j] or
                                          _G["MultiBar5Button"..j] or
                                          _G["MultiBar6Button"..j] or
                                          _G["MultiBar7Button"..j]
                            
                            if button and button.midnightBorder then
                                button.midnightBorder:SetColorTexture(r, g, b, a)
                            end
                        end
                    end
                end
            },
            
            -- Font Settings
            headerFont = { type = "header", name = "Font", order = 50 },
            
            font = {
                name = "Font",
                desc = "Font for cooldown text.",
                type = "select",
                order = 51,
                dialogControl = "LSM30_Font",
                values = LSM:HashTable("font"),
                disabled = function() return not self.db.profile.skinActionBars end,
                get = function() return self.db.profile.font end,
                set = function(_, v)
                    self.db.profile.font = v
                    ReloadUI()
                end
            },
            
            fontSize = {
                name = "Font Size",
                desc = "Size of cooldown text.",
                type = "range",
                order = 52,
                min = 8, max = 32, step = 1,
                disabled = function() return not self.db.profile.skinActionBars end,
                get = function() return self.db.profile.fontSize end,
                set = function(_, v)
                    self.db.profile.fontSize = v
                    ReloadUI()
                end
            },
            
            fontFlag = {
                name = "Font Outline",
                desc = "Outline style for cooldown text.",
                type = "select",
                order = 53,
                values = {
                    ["NONE"] = "None",
                    ["OUTLINE"] = "Outline",
                    ["THICKOUTLINE"] = "Thick Outline",
                    ["MONOCHROME"] = "Monochrome"
                },
                disabled = function() return not self.db.profile.skinActionBars end,
                get = function() return self.db.profile.fontFlag end,
                set = function(_, v)
                    self.db.profile.fontFlag = v
                    ReloadUI()
                end
            },
            
            -- Resource Bar Attachment
            headerAttachment = { type = "header", name = "Resource Bar Attachment", order = 60 },
            
            attachToResourceBar = {
                name = "Attach to Resource Bar",
                desc = "Attach cooldown icons to the MidnightUI Resource Bar for a seamless look.",
                type = "toggle",
                order = 61,
                width = "full",
                get = function() return self.db.profile.attachToResourceBar end,
                set = function(_, v)
                    self.db.profile.attachToResourceBar = v
                    self:UpdateAttachment()
                end
            },
            
            attachPosition = {
                name = "Attach Position",
                desc = "Where to attach cooldown icons relative to the resource bar.",
                type = "select",
                order = 62,
                values = {
                    ["BOTTOM"] = "Below",
                    ["TOP"] = "Above",
                    ["LEFT"] = "Left",
                    ["RIGHT"] = "Right"
                },
                disabled = function() return not self.db.profile.attachToResourceBar end,
                get = function() return self.db.profile.attachPosition end,
                set = function(_, v)
                    self.db.profile.attachPosition = v
                    self:UpdateAttachment()
                end
            },
            
            attachOffsetX = {
                name = "Horizontal Offset",
                desc = "Horizontal offset from the resource bar.",
                type = "range",
                order = 63,
                min = -200, max = 200, step = 1,
                disabled = function() return not self.db.profile.attachToResourceBar end,
                get = function() return self.db.profile.attachOffsetX end,
                set = function(_, v)
                    self.db.profile.attachOffsetX = v
                    self:UpdateAttachment()
                end
            },
            
            attachOffsetY = {
                name = "Vertical Offset",
                desc = "Vertical offset from the resource bar.",
                type = "range",
                order = 64,
                min = -200, max = 200, step = 1,
                disabled = function() return not self.db.profile.attachToResourceBar end,
                get = function() return self.db.profile.attachOffsetY end,
                set = function(_, v)
                    self.db.profile.attachOffsetY = v
                    self:UpdateAttachment()
                end
            },
        }
    }
end

