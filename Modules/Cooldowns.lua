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
    self.hookedLayouts = {}
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
    
    -- WoW 12.0 Cooldown Manager Frame Structure (actual frame names from /fstack):
    -- - EssentialCooldownViewer (essential/rotational abilities)
    -- - UtilityCooldownViewer (defensives/utility)
    -- - BuffIconCooldownViewer (offensive buffs/procs)
    
    local foundFrames = {}
    
    -- Find and skin the viewer frames
    local viewerFrames = {
        ["EssentialCooldownViewer"] = "Essential Cooldowns",
        ["UtilityCooldownViewer"] = "Utility Cooldowns",
        ["BuffIconCooldownViewer"] = "Buff Icon Cooldowns",
    }
    
    for frameName, displayName in pairs(viewerFrames) do
        local frame = _G[frameName]
        if frame then
            print("MidnightUI Cooldowns: Found", displayName, "("..frameName..")")
            self:ApplyCooldownManagerSkin(frame)
            foundFrames[frameName] = true
        else
            print("MidnightUI Cooldowns:", frameName, "not found")
        end
    end
    
    -- Hook UpdateLayout on each viewer if it exists
    for frameName in pairs(viewerFrames) do
        local frame = _G[frameName]
        if frame and not self.hookedLayouts[frameName] then
            if frame.UpdateLayout then
                hooksecurefunc(frame, "UpdateLayout", function()
                    self:StyleCooldownIcons(frame)
                end)
                self.hookedLayouts[frameName] = true
                print("MidnightUI Cooldowns: Hooked UpdateLayout for", frameName)
            end
            
            -- Also hook Update if it exists
            if frame.Update then
                hooksecurefunc(frame, "Update", function()
                    self:StyleCooldownIcons(frame)
                end)
                print("MidnightUI Cooldowns: Hooked Update for", frameName)
            end
        end
    end
    
    if next(foundFrames) then
        print("MidnightUI Cooldowns: Successfully skinned", #foundFrames, "Cooldown Manager viewer(s)")
        self:UpdateAttachment()
    else
        print("MidnightUI Cooldowns: No Cooldown Manager viewers found. Make sure you have enabled the Cooldown Manager in WoW's Edit Mode.")
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
    elseif not frame.midnightBg then
        -- Create background texture if no backdrop support
        frame.midnightBg = frame:CreateTexture(nil, "BACKGROUND")
        frame.midnightBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.midnightBg:SetAllPoints(frame)
        frame.midnightBg:SetColorTexture(unpack(db.backgroundColor))
        
        frame.midnightBorder = frame:CreateTexture(nil, "BORDER")
        frame.midnightBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.midnightBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
        frame.midnightBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
        frame.midnightBorder:SetColorTexture(unpack(db.borderColor))
    end
    
    -- Style child cooldown icons using the CooldownManagerIconTemplate
    self:StyleCooldownIcons(frame)
    
    self.styledFrames[frame] = true
end

function Cooldowns:StyleCooldownIcons(parent)
    if not parent then return end
    
    local db = self.db.profile
    
    -- Look for icon template instances
    if parent.icons then
        for _, icon in pairs(parent.icons) do
            self:StyleSingleIcon(icon)
        end
    end
    
    -- Also check for direct children
    if parent.GetChildren then
        for _, child in ipairs({parent:GetChildren()}) do
            -- Check if it's an icon frame
            if child.icon or child.Icon or child.texture then
                self:StyleSingleIcon(child)
            end
            
            -- Recursively check children
            if child.GetChildren then
                self:StyleCooldownIcons(child)
            end
        end
    end
end

function Cooldowns:StyleSingleIcon(icon)
    if not icon or icon.midnightStyled then return end
    
    local db = self.db.profile
    
    -- Find the icon texture
    local iconTexture = icon.icon or icon.Icon or icon.texture
    
    if iconTexture and iconTexture.SetTexCoord then
        -- Crop the icon
        iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    
    -- Add border around the icon
    if not icon.midnightBorder then
        icon.midnightBorder = icon:CreateTexture(nil, "OVERLAY")
        icon.midnightBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
        icon.midnightBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
        icon.midnightBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
        icon.midnightBorder:SetColorTexture(unpack(db.borderColor))
        icon.midnightBorder:SetDrawLayer("OVERLAY", 7)
        
        -- Create inner cutout
        icon.midnightInner = icon:CreateTexture(nil, "BORDER")
        icon.midnightInner:SetTexture("Interface\\Buttons\\WHITE8X8")
        icon.midnightInner:SetAllPoints(icon)
        icon.midnightInner:SetColorTexture(0, 0, 0, 1)
    end
    
    -- Style cooldown text if it exists
    if icon.cooldownText then
        local fontPath = LSM:Fetch("font", db.font)
        if fontPath then
            icon.cooldownText:SetFont(fontPath, db.fontSize, db.fontFlag)
        end
    end
    
    -- Style duration text if it exists
    if icon.durationText then
        local fontPath = LSM:Fetch("font", db.font)
        if fontPath then
            icon.durationText:SetFont(fontPath, db.fontSize, db.fontFlag)
        end
    end
    
    icon.midnightStyled = true
end

function Cooldowns:UpdateAllCooldownFrames()
    -- Called when CooldownManagerFrame updates its layout
    -- Re-style any new icons that appeared
    for frame in pairs(self.styledFrames) do
        if frame and frame:IsShown() then
            self:StyleCooldownIcons(frame)
        end
    end
end

function Cooldowns:UpdateColors()
    local db = self.db.profile
    
    -- Update all styled frames
    for frame in pairs(self.styledFrames) do
        if frame and frame:IsShown() then
            -- Update backdrop colors
            if frame.SetBackdropColor then
                frame:SetBackdropColor(unpack(db.backgroundColor))
            elseif frame.midnightBg then
                frame.midnightBg:SetColorTexture(unpack(db.backgroundColor))
            end
            
            if frame.SetBackdropBorderColor then
                frame.SetBackdropBorderColor(unpack(db.borderColor))
            elseif frame.midnightBorder then
                frame.midnightBorder:SetColorTexture(unpack(db.borderColor))
            end
            
            -- Update child icon borders
            self:UpdateIconBorders(frame)
        end
    end
end

function Cooldowns:UpdateIconBorders(parent)
    if not parent then return end
    
    local db = self.db.profile
    
    -- Update icon borders in icons table
    if parent.icons then
        for _, icon in pairs(parent.icons) do
            if icon and icon.midnightBorder then
                icon.midnightBorder:SetColorTexture(unpack(db.borderColor))
            end
        end
    end
    
    -- Update child borders
    if parent.GetChildren then
        for _, child in ipairs({parent:GetChildren()}) do
            if child and child.midnightBorder then
                child.midnightBorder:SetColorTexture(unpack(db.borderColor))
            end
            
            if child.GetChildren then
                self:UpdateIconBorders(child)
            end
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
    if not ResourceBars or not ResourceBars.primaryBar then 
        print("MidnightUI Cooldowns: ResourceBars module not found or primary bar not created")
        return 
    end
    
    local db = self.db.profile
    local anchor = ResourceBars.primaryBar
    
    -- Find the Essential Cooldown Viewer to attach (main one)
    local mainFrame = _G["EssentialCooldownViewer"]
    if not mainFrame then
        print("MidnightUI Cooldowns: EssentialCooldownViewer not found for attachment")
        return
    end
    
    -- Position relative to resource bar
    mainFrame:ClearAllPoints()
    
    if db.attachPosition == "BOTTOM" then
        mainFrame:SetPoint("TOP", anchor, "BOTTOM", db.attachOffsetX, db.attachOffsetY)
    elseif db.attachPosition == "TOP" then
        mainFrame:SetPoint("BOTTOM", anchor, "TOP", db.attachOffsetX, db.attachOffsetY)
    elseif db.attachPosition == "LEFT" then
        mainFrame:SetPoint("RIGHT", anchor, "LEFT", db.attachOffsetX, db.attachOffsetY)
    elseif db.attachPosition == "RIGHT" then
        mainFrame:SetPoint("LEFT", anchor, "RIGHT", db.attachOffsetX, db.attachOffsetY)
    end
    
    print("MidnightUI Cooldowns: Attached EssentialCooldownViewer to ResourceBar at", db.attachPosition)
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

