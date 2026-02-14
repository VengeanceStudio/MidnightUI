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
        
        -- WoW 12.0 Cooldown Manager Frame Skinning
        skinCooldownManager = true,
        
        -- Frame
        scale = 1.0,
        
        -- Colors
        backgroundColor = {0.05, 0.05, 0.05, 0.9},
        borderColor = {0.2, 0.8, 1.0, 1.0},
        
        -- Font
        font = "Expressway",
        fontSize = 14,
        fontFlag = "OUTLINE",
        
        -- Positioning for resource bar attachment
        attachToResourceBar = false,
        attachPosition = "BOTTOM",
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
        self:FindAndSkinCooldownManager()
    end)
end

function Cooldowns:ADDON_LOADED(event, addonName)
    -- Hook into PlayerSpells addon if it loads
    if addonName == "Blizzard_PlayerSpells" then
        C_Timer.After(0.5, function()
            self:FindAndSkinCooldownManager()
        end)
    end
end

-- -----------------------------------------------------------------------------
-- FIND AND SKIN WOW 12.0 COOLDOWN MANAGER
-- -----------------------------------------------------------------------------
function Cooldowns:FindAndSkinCooldownManager()
    if not self.db.profile.skinCooldownManager then return end
    
    -- In WoW 12.0+, the Cooldown Manager is a separate frame that displays spell cooldowns
    -- It's NOT the action bars - it's a resource tracker showing your spell icons
    
    -- Try to find the frame through EditMode first
    local cooldownFrame = nil
    
    if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
        for _, systemFrame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            if systemFrame then
                -- Look for frames that might be the cooldown manager
                local frameName = systemFrame:GetName()
                if frameName and (
                    frameName:find("Cooldown") or 
                    frameName:find("SpellActivation") or
                    frameName == "PlayerCastingBarFrame" -- Sometimes cooldowns attach here
                ) then
                    print("MidnightUI Cooldowns: Found potential frame:", frameName)
                    cooldownFrame = systemFrame
                    break
                end
            end
        end
    end
    
    -- Try direct global references
    if not cooldownFrame then
        local possibleFrames = {
            "PlayerSpellsFrame",
            "SpellbookFrame",
            "SpellActivationOverlayFrame",
            "CooldownFrame",
            "PlayerCooldownFrame",
        }
        
        for _, frameName in ipairs(possibleFrames) do
            local frame = _G[frameName]
            if frame then
                print("MidnightUI Cooldowns: Found frame via global:", frameName)
                cooldownFrame = frame
                break
            end
        end
    end
    
    if cooldownFrame then
        self:ApplyCooldownManagerSkin(cooldownFrame)
        self:UpdateAttachment()
    else
        print("MidnightUI Cooldowns: Could not find Cooldown Manager frame. It may not be visible yet.")
    end
end

function Cooldowns:ApplyCooldownManagerSkin(frame)
    if not frame or self.styledFrames[frame] then return end
    
    local db = self.db.profile
    
    print("MidnightUI Cooldowns: Applying skin to frame:", frame:GetName() or "unnamed")
    
    -- Apply scale
    if frame.SetScale then
        frame:SetScale(db.scale)
    end
    
    -- Create backdrop if frame supports it
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        frame:SetBackdropColor(unpack(db.backgroundColor))
        frame:SetBackdropBorderColor(unpack(db.borderColor))
    end
    
    -- Style child cooldown icons
    self:StyleCooldownChildren(frame)
    
    -- Hook to catch new children being added
    if not self.hookedChildCreation then
        hooksecurefunc(frame, "Show", function()
            C_Timer.After(0.1, function()
                self:StyleCooldownChildren(frame)
            end)
        end)
        self.hookedChildCreation = true
    end
    
    self.styledFrames[frame] = true
end

function Cooldowns:StyleCooldownChildren(parent)
    if not parent or not parent.GetChildren then return end
    
    local db = self.db.profile
    
    for _, child in ipairs({parent:GetChildren()}) do
        if child and not child.midnightStyled then
            -- Look for cooldown icon frames
            if child.icon or child.Icon then
                local icon = child.icon or child.Icon
                
                -- Crop the icon
                if icon.SetTexCoord then
                    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                end
                
                -- Add border
                if not child.midnightBorder then
                    child.midnightBorder = child:CreateTexture(nil, "OVERLAY")
                    child.midnightBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
                    child.midnightBorder:SetAllPoints(child)
                    child.midnightBorder:SetColorTexture(unpack(db.borderColor))
                    child.midnightBorder:SetDrawLayer("OVERLAY", 7)
                end
                
                child.midnightStyled = true
            end
            
            -- Recursively style children
            if child.GetChildren then
                self:StyleCooldownChildren(child)
            end
        end
    end
end

function Cooldowns:UpdateColors()
    local db = self.db.profile
    
    -- Update all styled frames
    for frame in pairs(self.styledFrames) do
        if frame and frame:IsShown() then
            if frame.SetBackdropColor then
                frame:SetBackdropColor(unpack(db.backgroundColor))
            end
            if frame.SetBackdropBorderColor then
                frame:SetBackdropBorderColor(unpack(db.borderColor))
            end
            
            -- Update child borders
            self:UpdateChildBorders(frame)
        end
    end
end

function Cooldowns:UpdateChildBorders(parent)
    if not parent or not parent.GetChildren then return end
    
    local db = self.db.profile
    
    for _, child in ipairs({parent:GetChildren()}) do
        if child and child.midnightBorder then
            child.midnightBorder:SetColorTexture(unpack(db.borderColor))
        end
        
        if child.GetChildren then
            self:UpdateChildBorders(child)
        end
    end
end

-- -----------------------------------------------------------------------------
-- RESOURCE BAR ATTACHMENT
-- -----------------------------------------------------------------------------
function Cooldowns:UpdateAttachment()
    if not self.db.profile.attachToResourceBar then return end
    
    -- Try to find the MidnightUI ResourceBars module
    local ResourceBars = MidnightUI:GetModule("ResourceBars", true)
    if not ResourceBars or not ResourceBars.primaryBar then return end
    
    local db = self.db.profile
    local anchor = ResourceBars.primaryBar
    
    -- Find a cooldown frame to attach
    for frame in pairs(self.styledFrames) do
        if frame and frame:IsShown() then
            frame:ClearAllPoints()
            
            if db.attachPosition == "BOTTOM" then
                frame:SetPoint("TOP", anchor, "BOTTOM", db.attachOffsetX, db.attachOffsetY)
            elseif db.attachPosition == "TOP" then
                frame:SetPoint("BOTTOM", anchor, "TOP", db.attachOffsetX, db.attachOffsetY)
            elseif db.attachPosition == "LEFT" then
                frame:SetPoint("RIGHT", anchor, "LEFT", db.attachOffsetX, db.attachOffsetY)
            elseif db.attachPosition == "RIGHT" then
                frame:SetPoint("LEFT", anchor, "RIGHT", db.attachOffsetX, db.attachOffsetY)
            end
            
            break -- Only attach the first found frame
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
                name = "WoW 12.0 Cooldown Manager",
                order = 1
            },
            desc = {
                type = "description",
                name = "Applies MidnightUI styling to the WoW 12.0 Cooldown Manager resource display.\n\n" ..
                      "|cffFFFF00Note:|r The Cooldown Manager is a separate frame from action bars that shows spell cooldowns.\n\n" ..
                      "|cffFF6B6BDebug:|r Check your chat for messages about which frames were found.",
                order = 2
            },
            
            skinCooldownManager = {
                name = "Enable Cooldown Manager Skinning",
                desc = "Apply MidnightUI styling to the Cooldown Manager frame.",
                type = "toggle",
                order = 10,
                width = "full",
                get = function() return self.db.profile.skinCooldownManager end,
                set = function(_, v)
                    self.db.profile.skinCooldownManager = v
                    if v then
                        self:FindAndSkinCooldownManager()
                    else
                        ReloadUI()
                    end
                end
            },
            
            rescan = {
                name = "Rescan for Cooldown Manager",
                desc = "Try to find and skin the Cooldown Manager frame again.",
                type = "execute",
                order = 11,
                func = function()
                    self:FindAndSkinCooldownManager()
                end
            },
            
            -- Frame Settings
            headerFrame = { type = "header", name = "Frame Settings", order = 20 },
            
            scale = {
                name = "Scale",
                desc = "Scale of the Cooldown Manager frame.",
                type = "range",
                order = 21,
                min = 0.5, max = 2.0, step = 0.05,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.scale end,
                set = function(_, v)
                    self.db.profile.scale = v
                    for frame in pairs(self.styledFrames) do
                        if frame and frame.SetScale then
                            frame:SetScale(v)
                        end
                    end
                end
            },
            
            -- Colors
            headerColors = { type = "header", name = "Colors", order = 30 },
            
            backgroundColor = {
                name = "Background Color",
                desc = "Background color for the Cooldown Manager frame.",
                type = "color",
                order = 31,
                hasAlpha = true,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function()
                    local c = self.db.profile.backgroundColor
                    return c[1], c[2], c[3], c[4]
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.backgroundColor = {r, g, b, a}
                    self:UpdateColors()
                end
            },
            
            borderColor = {
                name = "Border Color",
                desc = "Border color for cooldown icons.",
                type = "color",
                order = 32,
                hasAlpha = true,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function()
                    local c = self.db.profile.borderColor
                    return c[1], c[2], c[3], c[4]
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.borderColor = {r, g, b, a}
                    self:UpdateColors()
                end
            },
            
            -- Font Settings
            headerFont = { type = "header", name = "Font", order = 40 },
            
            font = {
                name = "Font",
                desc = "Font for cooldown text.",
                type = "select",
                order = 41,
                dialogControl = "LSM30_Font",
                values = LSM:HashTable("font"),
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.font end,
                set = function(_, v)
                    self.db.profile.font = v
                    -- Font changes would require frame recreation
                end
            },
            
            fontSize = {
                name = "Font Size",
                desc = "Size of cooldown text.",
                type = "range",
                order = 42,
                min = 8, max = 32, step = 1,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.fontSize end,
                set = function(_, v)
                    self.db.profile.fontSize = v
                end
            },
            
            fontFlag = {
                name = "Font Outline",
                desc = "Outline style for cooldown text.",
                type = "select",
                order = 43,
                values = {
                    ["NONE"] = "None",
                    ["OUTLINE"] = "Outline",
                    ["THICKOUTLINE"] = "Thick Outline",
                    ["MONOCHROME"] = "Monochrome"
                },
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.fontFlag end,
                set = function(_, v)
                    self.db.profile.fontFlag = v
                end
            },
            
            -- Resource Bar Attachment
            headerAttachment = { type = "header", name = "Resource Bar Attachment", order = 50 },
            
            attachToResourceBar = {
                name = "Attach to Resource Bar",
                desc = "Attach the Cooldown Manager to the MidnightUI Resource Bar for a seamless look.",
                type = "toggle",
                order = 51,
                width = "full",
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.attachToResourceBar end,
                set = function(_, v)
                    self.db.profile.attachToResourceBar = v
                    self:UpdateAttachment()
                end
            },
            
            attachPosition = {
                name = "Attach Position",
                desc = "Where to attach the Cooldown Manager relative to the resource bar.",
                type = "select",
                order = 52,
                values = {
                    ["BOTTOM"] = "Below",
                    ["TOP"] = "Above",
                    ["LEFT"] = "Left",
                    ["RIGHT"] = "Right"
                },
                disabled = function() return not self.db.profile.attachToResourceBar or not self.db.profile.skinCooldownManager end,
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
                order = 53,
                min = -200, max = 200, step = 1,
                disabled = function() return not self.db.profile.attachToResourceBar or not self.db.profile.skinCooldownManager end,
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
                order = 54,
                min = -200, max = 200, step = 1,
                disabled = function() return not self.db.profile.attachToResourceBar or not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.attachOffsetY end,
                set = function(_, v)
                    self.db.profile.attachOffsetY = v
                    self:UpdateAttachment()
                end
            },
        }
    }
end

