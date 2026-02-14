local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local Cooldowns = MidnightUI:NewModule("Cooldowns", "AceEvent-3.0", "AceHook-3.0")

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
        
        -- Colors
        backgroundColor = {0.05, 0.05, 0.05, 0.9},
        borderColor = {0, 0, 0, 1},
        accentColor = {0.2, 0.8, 1.0, 1.0}, -- Teal accent
    }
}

-- -----------------------------------------------------------------------------
-- INITIALIZATION
-- -----------------------------------------------------------------------------
function Cooldowns:OnInitialize()
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "OnDBReady")
end

function Cooldowns:OnDBReady()
    if not MidnightUI.db or not MidnightUI.db.profile or not MidnightUI.db.profile.modules.cooldowns then
        self:Disable()
        return
    end
    
    self.db = MidnightUI.db:RegisterNamespace("Cooldowns", defaults)
    
    -- Register events
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ADDON_LOADED")
end

function Cooldowns:PLAYER_ENTERING_WORLD()
    C_Timer.After(1, function()
        self:SkinBlizzardCooldownManager()
    end)
end

function Cooldowns:ADDON_LOADED(event, addonName)
    if addonName == "Blizzard_SpellActivationOverlay" or addonName == "Blizzard_PlayerSpells" then
        C_Timer.After(0.5, function()
            self:SkinBlizzardCooldownManager()
        end)
    end
end

-- -----------------------------------------------------------------------------
-- SKIN BLIZZARD COOLDOWN MANAGER
-- -----------------------------------------------------------------------------
function Cooldowns:SkinBlizzardCooldownManager()
    if not self.db.profile.skinCooldownManager then return end
    
    -- Try to find the Blizzard Cooldown Manager frame
    -- In WoW 12.0+, this might be under various names
    local cooldownFrame = nil
    
    -- Check for EditMode overlays
    if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
        for _, systemFrame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            if systemFrame and systemFrame.system then
                -- system might be a number (Enum value) or string, handle both
                local systemType = type(systemFrame.system)
                if systemType == "string" then
                    if systemFrame.system == "SpellActivationOverlay" or 
                       systemFrame.system == "ActionBar" or
                       systemFrame.system:find("Cooldown") then
                        cooldownFrame = systemFrame
                        break
                    end
                elseif systemType == "number" then
                    -- For numeric enum values, check system constants
                    if Enum and Enum.EditModeSystem then
                        if systemFrame.system == Enum.EditModeSystem.ActionBar or
                           systemFrame.system == Enum.EditModeSystem.SpellActivationOverlay then
                            cooldownFrame = systemFrame
                            break
                        end
                    end
                end
            end
        end
    end
    
    -- Try direct frame references
    if not cooldownFrame then
        cooldownFrame = _G["SpellActivationOverlayFrame"] or 
                       _G["PlayerSpellsFrame"] or
                       _G["CooldownFrame"]
    end
    
    if cooldownFrame then
        self:ApplyCooldownSkin(cooldownFrame)
    end
    
    -- Hook into spell activation overlays
    self:HookSpellActivationOverlays()
end

function Cooldowns:ApplyCooldownSkin(frame)
    if not frame then return end
    
    local db = self.db.profile
    
    -- Apply backdrop if frame supports it
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        frame:SetBackdropColor(unpack(db.backgroundColor))
        frame:SetBackdropBorderColor(unpack(db.borderColor))
    end
    
    -- Style child frames (spell icons, cooldown indicators)
    if frame.GetChildren then
        for _, child in ipairs({frame:GetChildren()}) do
            self:StyleCooldownChild(child)
        end
    end
    
    -- Hook creation of new cooldown indicators
    if not self.hookedCooldownCreation then
        hooksecurefunc(frame, "Show", function()
            C_Timer.After(0.1, function()
                if frame.GetChildren then
                    for _, child in ipairs({frame:GetChildren()}) do
                        self:StyleCooldownChild(child)
                    end
                end
            end)
        end)
        self.hookedCooldownCreation = true
    end
end

function Cooldowns:StyleCooldownChild(child)
    if not child or child.midnightStyled then return end
    
    local db = self.db.profile
    
    -- Apply backdrop to cooldown icons
    if child.SetBackdrop and not child:GetBackdrop() then
        child:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        child:SetBackdropBorderColor(unpack(db.borderColor))
    end
    
    -- Style textures
    if child.GetRegions then
        for _, region in ipairs({child:GetRegions()}) do
            if region:GetObjectType() == "Texture" then
                -- Make icon textures use proper cropping
                if region:GetTexture() and not region.midnightCropped then
                    region:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    region.midnightCropped = true
                end
            end
        end
    end
    
    child.midnightStyled = true
end

function Cooldowns:HookSpellActivationOverlays()
    -- Hook the spell activation overlay system (if it exists)
    if SpellActivationOverlayFrame and not self.hookedOverlays then
        -- Check if the function exists before trying to hook it
        if SpellActivationOverlay_ShowOverlay and type(SpellActivationOverlay_ShowOverlay) == "function" then
            hooksecurefunc("SpellActivationOverlay_ShowOverlay", function(frame, spellID, texture, position, scale, r, g, b)
                -- Could add custom styling here if needed
                -- For now, just ensure it's visible and properly positioned
            end)
            self.hookedOverlays = true
        end
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
                name = "Blizzard Cooldown Manager Skinning",
                order = 1
            },
            desc = {
                type = "description",
                name = "Applies MidnightUI styling to Blizzard's cooldown manager and spell activation overlays.",
                order = 2
            },
            
            skinCooldownManager = {
                name = "Enable Cooldown Manager Skinning",
                type = "toggle",
                order = 10,
                get = function() return self.db.profile.skinCooldownManager end,
                set = function(_, v)
                    self.db.profile.skinCooldownManager = v
                    ReloadUI()
                end
            },
            
            headerColors = { type = "header", name = "Colors", order = 20 },
            backgroundColor = {
                name = "Background Color",
                type = "color",
                order = 21,
                hasAlpha = true,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function()
                    local c = self.db.profile.backgroundColor
                    return c[1], c[2], c[3], c[4]
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.backgroundColor = {r, g, b, a}
                    self:SkinBlizzardCooldownManager()
                end
            },
            borderColor = {
                name = "Border Color",
                type = "color",
                order = 22,
                hasAlpha = true,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function()
                    local c = self.db.profile.borderColor
                    return c[1], c[2], c[3], c[4]
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.borderColor = {r, g, b, a}
                    self:SkinBlizzardCooldownManager()
                end
            },
        }
    }
end

