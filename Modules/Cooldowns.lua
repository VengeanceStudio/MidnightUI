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
        showBackground = true,
        showFrameBorder = false,
        backgroundColor = {0.05, 0.05, 0.05, 0.9},
        borderColor = {0.2, 0.8, 1.0, 1.0},
        
        -- Font
        font = "Friz Quadrata TT",
        fontSize = 14,
        fontFlag = "OUTLINE",
        
        -- Positioning for resource bar attachment
        attachToResourceBar = false,
        attachPosition = "BOTTOM",
        attachOffsetX = 0,
        attachOffsetY = -2,
        
        -- Resource bar width matching
        matchPrimaryBarWidth = false,
        matchSecondaryBarWidth = false,
        
        -- Frame Grouping (attach frames to each other)
        groupFrames = false,
        
        -- Individual frame settings (default order: Buffs, Primary Bar, Secondary Bar, Essential, Utility, Tracked Bars)
        frames = {
            essential = {
                enabled = true,
                isAnchor = true,  -- Essential is the main anchor
            },
            buffs = {
                enabled = true,
                attachTo = "primaryBar",
                attachPosition = "TOP",
                offsetX = 0,
                offsetY = 2,
            },
            utility = {
                enabled = true,
                attachTo = "essential",
                attachPosition = "BOTTOM",
                offsetX = 0,
                offsetY = -2,
            },
            bars = {
                enabled = true,
                attachTo = "utility",
                attachPosition = "BOTTOM",
                offsetX = 0,
                offsetY = -2,
            },
        },
    }
}

-- -----------------------------------------------------------------------------
-- INITIALIZATION
-- -----------------------------------------------------------------------------
function Cooldowns:OnInitialize()
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "OnDBReady")
    self.styledFrames = {}
    self.hookedLayouts = {}
    self.styledIcons = {}
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
    
    -- Check if we're already in world (PLAYER_ENTERING_WORLD may have fired before we registered)
    if IsPlayerInWorld and IsPlayerInWorld() then
        C_Timer.After(0.5, function()
            self:FindAndSkinCooldownManager()
        end)
        C_Timer.After(2, function()
            self:FindAndSkinCooldownManager()
        end)
    end
end

function Cooldowns:PLAYER_ENTERING_WORLD()
    -- Try immediately
    self:FindAndSkinCooldownManager()
    
    -- Try again after 1 second
    C_Timer.After(1, function()
        self:FindAndSkinCooldownManager()
    end)
    
    -- Try again after 3 seconds (in case frames load late)
    C_Timer.After(3, function()
        self:FindAndSkinCooldownManager()
    end)
end

function Cooldowns:ADDON_LOADED(event, addonName)
    -- Hook into PlayerSpells addon if it loads
    if addonName == "Blizzard_PlayerSpells" or addonName == "Blizzard_EditMode" then
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
    
    local foundFrames = {}
    
    -- Find and skin the viewer frames
    local viewerFrames = {
        ["EssentialCooldownViewer"] = "Essential Cooldowns",
        ["UtilityCooldownViewer"] = "Utility Cooldowns",
        ["BuffIconCooldownViewer"] = "Buff Icon Cooldowns",
        ["BuffBarCooldownViewer"] = "Buff Bar Cooldowns",
    }
    
    for frameName, displayName in pairs(viewerFrames) do
        local frame = _G[frameName]
        if frame then
            self:ApplyCooldownManagerSkin(frame)
            foundFrames[frameName] = true
        end
    end
    
    -- Hook UpdateLayout on each viewer if it exists
    for frameName in pairs(viewerFrames) do
        local frame = _G[frameName]
        if frame and not self.hookedLayouts[frameName] then
            if frame.UpdateLayout then
                hooksecurefunc(frame, "UpdateLayout", function()
                    self:StyleCooldownIcons(frame)
                    -- Update resource bar widths when Essential layout changes
                    if frameName == "EssentialCooldownViewer" then
                        self:UpdateResourceBarWidths()
                    end
                    -- Reapply positioning after layout updates
                    C_Timer.After(0.1, function()
                        self:UpdateAttachment()
                    end)
                end)
                self.hookedLayouts[frameName] = true
            end
            
            -- Also hook Update if it exists
            if frame.Update then
                hooksecurefunc(frame, "Update", function()
                    self:StyleCooldownIcons(frame)
                end)
            end
            
            -- Hook SetPoint to intercept Edit Mode repositioning
            if not frame.midnightHookedSetPoint then
                hooksecurefunc(frame, "SetPoint", function(self)
                    -- If we're attached to resource bar, reapply our positioning after a brief delay
                    if Cooldowns.db.profile.attachToResourceBar then
                        C_Timer.After(0.05, function()
                            Cooldowns:UpdateAttachment()
                        end)
                    end
                end)
                frame.midnightHookedSetPoint = true
            end
            
            -- Add periodic refresh to maintain square icons
            if not frame.midnightRefreshTimer then
                frame.midnightRefreshTimer = C_Timer.NewTicker(2, function()
                    if frame and frame:IsShown() then
                        self:StyleCooldownIcons(frame)
                    end
                end)
            end
        end
    end
    
    if next(foundFrames) then
        self:UpdateAttachment()
    end
end

function Cooldowns:ApplyCooldownManagerSkin(frame)
    if not frame or self.styledFrames[frame] then return end
    
    local db = self.db.profile
    
    -- Apply scale
    if frame.SetScale then
        frame:SetScale(db.scale)
    end
    
    -- Create a background frame that is parented to the viewer's parent
    -- This ensures it renders completely behind the viewer
    if not frame.midnightBgFrame then
        local parent = frame:GetParent() or UIParent
        
        frame.midnightBgFrame = CreateFrame("Frame", nil, parent)
        frame.midnightBgFrame:SetAllPoints(frame)
        frame.midnightBgFrame:SetFrameStrata("BACKGROUND")
        frame.midnightBgFrame:SetFrameLevel(1)
        
        -- Background texture
        frame.midnightBg = frame.midnightBgFrame:CreateTexture(nil, "BACKGROUND")
        frame.midnightBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.midnightBg:SetAllPoints(frame.midnightBgFrame)
        frame.midnightBg:SetColorTexture(unpack(db.backgroundColor))
        
        -- Show/hide based on setting
        if db.showBackground then
            frame.midnightBg:Show()
        else
            frame.midnightBg:Hide()
        end
        
        -- Border textures
        local borderSize = 2
        local r, g, b, a = unpack(db.borderColor)
        
        frame.midnightBorderTop = frame.midnightBgFrame:CreateTexture(nil, "ARTWORK")
        frame.midnightBorderTop:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.midnightBorderTop:SetColorTexture(r, g, b, a)
        frame.midnightBorderTop:SetPoint("TOPLEFT", frame.midnightBgFrame, "TOPLEFT", 0, 0)
        frame.midnightBorderTop:SetPoint("TOPRIGHT", frame.midnightBgFrame, "TOPRIGHT", 0, 0)
        frame.midnightBorderTop:SetHeight(borderSize)
        
        frame.midnightBorderBottom = frame.midnightBgFrame:CreateTexture(nil, "ARTWORK")
        frame.midnightBorderBottom:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.midnightBorderBottom:SetColorTexture(r, g, b, a)
        frame.midnightBorderBottom:SetPoint("BOTTOMLEFT", frame.midnightBgFrame, "BOTTOMLEFT", 0, 0)
        frame.midnightBorderBottom:SetPoint("BOTTOMRIGHT", frame.midnightBgFrame, "BOTTOMRIGHT", 0, 0)
        frame.midnightBorderBottom:SetHeight(borderSize)
        
        frame.midnightBorderLeft = frame.midnightBgFrame:CreateTexture(nil, "ARTWORK")
        frame.midnightBorderLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.midnightBorderLeft:SetColorTexture(r, g, b, a)
        frame.midnightBorderLeft:SetPoint("TOPLEFT", frame.midnightBgFrame, "TOPLEFT", 0, 0)
        frame.midnightBorderLeft:SetPoint("BOTTOMLEFT", frame.midnightBgFrame, "BOTTOMLEFT", 0, 0)
        frame.midnightBorderLeft:SetWidth(borderSize)
        
        frame.midnightBorderRight = frame.midnightBgFrame:CreateTexture(nil, "ARTWORK")
        frame.midnightBorderRight:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.midnightBorderRight:SetColorTexture(r, g, b, a)
        frame.midnightBorderRight:SetPoint("TOPRIGHT", frame.midnightBgFrame, "TOPRIGHT", 0, 0)
        frame.midnightBorderRight:SetPoint("BOTTOMRIGHT", frame.midnightBgFrame, "BOTTOMRIGHT", 0, 0)
        frame.midnightBorderRight:SetWidth(borderSize)
        
        -- Show/hide frame borders based on setting
        if db.showFrameBorder then
            frame.midnightBorderTop:Show()
            frame.midnightBorderBottom:Show()
            frame.midnightBorderLeft:Show()
            frame.midnightBorderRight:Show()
        else
            frame.midnightBorderTop:Hide()
            frame.midnightBorderBottom:Hide()
            frame.midnightBorderLeft:Hide()
            frame.midnightBorderRight:Hide()
        end
        
        -- Make sure the background frame updates position if the viewer moves
        frame:HookScript("OnUpdate", function()
            if frame.midnightBgFrame then
                frame.midnightBgFrame:SetAllPoints(frame)
            end
        end)
    else
        -- Update existing colors
        frame.midnightBg:SetColorTexture(unpack(db.backgroundColor))
        local r, g, b, a = unpack(db.borderColor)
        frame.midnightBorderTop:SetColorTexture(r, g, b, a)
        frame.midnightBorderBottom:SetColorTexture(r, g, b, a)
        frame.midnightBorderLeft:SetColorTexture(r, g, b, a)
        frame.midnightBorderRight:SetColorTexture(r, g, b, a)
    end
    
    -- Style child cooldown icons
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
    if not icon then return end
    
    local db = self.db.profile
    
    -- Find the icon texture - may be nested
    local iconTexture = icon.icon or icon.Icon or icon.texture
    
    -- If iconTexture is a frame, look for the actual texture inside it
    if iconTexture and iconTexture.GetObjectType and iconTexture:GetObjectType() == "Frame" then
        -- Check for common texture names
        iconTexture = iconTexture.Icon or iconTexture.icon or iconTexture.texture
    end
    
    -- Apply texture coordinate cropping to cut off rounded corners
    -- Don't hide masks as they may be required for icons to display
    if iconTexture and iconTexture.GetObjectType and iconTexture:GetObjectType() == "Texture" then
        if iconTexture.SetTexCoord then
            -- More aggressive crop to remove rounded corners completely
            iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        end
    end
    
    -- Add border frame only once
    if not icon.midnightBorderFrame then
        icon.midnightBorderFrame = CreateFrame("Frame", nil, icon, "BackdropTemplate")
        
        -- Tighter inset to match the cropped icon texture
        icon.midnightBorderFrame:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
        icon.midnightBorderFrame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
        
        icon.midnightBorderFrame:SetFrameStrata("MEDIUM")
        icon.midnightBorderFrame:SetFrameLevel(icon:GetFrameLevel() + 5)
        
        icon.midnightBorderFrame:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        icon.midnightBorderFrame:SetBackdropBorderColor(unpack(db.borderColor))
        
        self.styledIcons[icon] = true
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
    
    self.styledIcons[icon] = true
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
            -- Update background
            if frame.midnightBg then
                frame.midnightBg:SetColorTexture(unpack(db.backgroundColor))
                
                -- Show/hide based on setting
                if db.showBackground then
                    frame.midnightBg:Show()
                else
                    frame.midnightBg:Hide()
                end
            end
            
            -- Update border (4 sides)
            local r, g, b, a = unpack(db.borderColor)
            if frame.midnightBorderTop then
                frame.midnightBorderTop:SetColorTexture(r, g, b, a)
                frame.midnightBorderBottom:SetColorTexture(r, g, b, a)
                frame.midnightBorderLeft:SetColorTexture(r, g, b, a)
                frame.midnightBorderRight:SetColorTexture(r, g, b, a)
                
                -- Show/hide frame borders based on setting
                if db.showFrameBorder then
                    frame.midnightBorderTop:Show()
                    frame.midnightBorderBottom:Show()
                    frame.midnightBorderLeft:Show()
                    frame.midnightBorderRight:Show()
                else
                    frame.midnightBorderTop:Hide()
                    frame.midnightBorderBottom:Hide()
                    frame.midnightBorderLeft:Hide()
                    frame.midnightBorderRight:Hide()
                end
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
            if icon and icon.midnightBorderFrame then
                icon.midnightBorderFrame:SetBackdropBorderColor(unpack(db.borderColor))
            end
        end
    end
    
    -- Update child borders
    if parent.GetChildren then
        for _, child in ipairs({parent:GetChildren()}) do
            if child and child.midnightBorderFrame then
                child.midnightBorderFrame:SetBackdropBorderColor(unpack(db.borderColor))
            end
            
            if child.GetChildren then
                self:UpdateIconBorders(child)
            end
        end
    end
end

-- -----------------------------------------------------------------------------
-- FRAME GROUPING
-- -----------------------------------------------------------------------------
function Cooldowns:UpdateFrameGrouping()
    if not self.db.profile.groupFrames then return end
    
    local db = self.db.profile
    
    -- Get ResourceBars module for bar references
    local ResourceBars = MidnightUI:GetModule("ResourceBars", true)
    
    -- Map of frame names to WoW global names or resource bars
    local frameMap = {
        essential = "EssentialCooldownViewer",
        utility = "UtilityCooldownViewer",
        buffs = "BuffIconCooldownViewer",
        bars = "BuffBarCooldownViewer",
        primaryBar = ResourceBars and ResourceBars.primaryBar,
        secondaryBar = ResourceBars and ResourceBars.secondaryBar,
    }
    
    -- Process each frame
    for frameName, settings in pairs(db.frames) do
        local frame = type(frameMap[frameName]) == "string" and _G[frameMap[frameName]] or frameMap[frameName]
        if frame and settings.enabled and not settings.isAnchor then
            -- Find the anchor frame
            local anchorReference = frameMap[settings.attachTo]
            local anchorFrame = type(anchorReference) == "string" and _G[anchorReference] or anchorReference
            
            if anchorFrame then
                frame:ClearAllPoints()
                
                local pos = settings.attachPosition
                if pos == "BOTTOM" then
                    frame:SetPoint("TOP", anchorFrame, "BOTTOM", settings.offsetX, settings.offsetY)
                elseif pos == "TOP" then
                    frame:SetPoint("BOTTOM", anchorFrame, "TOP", settings.offsetX, settings.offsetY)
                elseif pos == "LEFT" then
                    frame:SetPoint("RIGHT", anchorFrame, "LEFT", settings.offsetX, settings.offsetY)
                elseif pos == "RIGHT" then
                    frame:SetPoint("LEFT", anchorFrame, "RIGHT", settings.offsetX, settings.offsetY)
                end
            end
        end
    end
end

-- -----------------------------------------------------------------------------
-- RESOURCE BAR WIDTH MATCHING
-- -----------------------------------------------------------------------------
function Cooldowns:UpdateResourceBarWidths()
    local db = self.db.profile
    
    -- Get the Essential Cooldown Viewer
    local essentialFrame = _G["EssentialCooldownViewer"]
    if not essentialFrame then return end
    
    local essentialWidth = essentialFrame:GetWidth()
    if not essentialWidth or essentialWidth == 0 then return end
    
    -- Get ResourceBars module
    local ResourceBars = MidnightUI:GetModule("ResourceBars", true)
    if not ResourceBars then return end
    
    -- Match primary bar width if enabled
    if db.matchPrimaryBarWidth and ResourceBars.primaryBar then
        ResourceBars.primaryBar:SetWidth(essentialWidth)
    end
    
    -- Match secondary bar width if enabled
    if db.matchSecondaryBarWidth and ResourceBars.secondaryBar then
        ResourceBars.secondaryBar:SetWidth(essentialWidth)
    end
end

-- -----------------------------------------------------------------------------
-- RESOURCE BAR WIDTH MATCHING
-- -----------------------------------------------------------------------------
function Cooldowns:UpdateResourceBarWidths()
    local db = self.db.profile
    
    -- Get the Essential Cooldown Viewer
    local essentialFrame = _G["EssentialCooldownViewer"]
    if not essentialFrame then return end
    
    local essentialWidth = essentialFrame:GetWidth()
    if not essentialWidth or essentialWidth == 0 then return end
    
    -- Get ResourceBars module
    local ResourceBars = MidnightUI:GetModule("ResourceBars", true)
    if not ResourceBars then return end
    
    -- Match primary bar width if enabled
    if db.matchPrimaryBarWidth and ResourceBars.primaryBar then
        ResourceBars.primaryBar:SetWidth(essentialWidth)
    end
    
    -- Match secondary bar width if enabled
    if db.matchSecondaryBarWidth and ResourceBars.secondaryBar then
        ResourceBars.secondaryBar:SetWidth(essentialWidth)
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
    
    -- Find the Essential Cooldown Viewer to attach (main one)
    local mainFrame = _G["EssentialCooldownViewer"]
    if not mainFrame then return end
    
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
    
    -- Update frame grouping if enabled
    self:UpdateFrameGrouping()
    
    -- Update resource bar widths if enabled
    self:UpdateResourceBarWidths()
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
            
            showBackground = {
                name = "Show Background",
                desc = "Show or hide the background behind the Cooldown Manager.",
                type = "toggle",
                order = 30.5,
                width = "full",
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.showBackground end,
                set = function(_, v)
                    self.db.profile.showBackground = v
                    self:UpdateColors()
                end
            },
                        showFrameBorder = {
                name = "Show Frame Border",
                desc = "Show or hide the border around the entire Cooldown Manager frame. Individual icon borders are controlled separately.",
                type = "toggle",
                order = 30.6,
                width = "full",
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.showFrameBorder end,
                set = function(_, v)
                    self.db.profile.showFrameBorder = v
                    self:UpdateColors()
                end
            },
                        showFrameBorder = {
                name = "Show Frame Border",
                desc = "Show or hide the border around the entire Cooldown Manager frame. Individual icon borders are controlled separately.",
                type = "toggle",
                order = 30.6,
                width = "full",
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.showFrameBorder end,
                set = function(_, v)
                    self.db.profile.showFrameBorder = v
                    self:UpdateColors()
                end
            },
            
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
                values = function()
                    local fonts = LSM:List("font")
                    local out = {}
                    for _, font in ipairs(fonts) do out[font] = font end
                    return out
                end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.font or "Friz Quadrata TT" end,
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
            
            -- Width Matching
            headerWidthMatch = { type = "header", name = "Resource Bar Width Matching", order = 55 },
            
            matchPrimaryBarWidth = {
                name = "Match Primary Bar Width",
                desc = "Make the Primary Resource Bar width match the Essential Cooldowns bar width.",
                type = "toggle",
                order = 56,
                width = "full",
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.matchPrimaryBarWidth end,
                set = function(_, v)
                    self.db.profile.matchPrimaryBarWidth = v
                    self:UpdateResourceBarWidths()
                end
            },
            
            matchSecondaryBarWidth = {
                name = "Match Secondary Bar Width",
                desc = "Make the Secondary Resource Bar width match the Essential Cooldowns bar width.",
                type = "toggle",
                order = 57,
                width = "full",
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.matchSecondaryBarWidth end,
                set = function(_, v)
                    self.db.profile.matchSecondaryBarWidth = v
                    self:UpdateResourceBarWidths()
                end
            },
            
            -- Frame Grouping
            headerGrouping = { type = "header", name = "Frame Grouping", order = 60 },
            
            groupFrames = {
                name = "Enable Frame Grouping",
                desc = "Attach cooldown frames to each other so they move and resize as a group.",
                type = "toggle",
                order = 61,
                width = "full",
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.groupFrames end,
                set = function(_, v)
                    self.db.profile.groupFrames = v
                    self:UpdateFrameGrouping()
                end
            },
            
            groupingDesc = {
                type = "description",
                name = "Configure how each cooldown frame attaches to others. Essential Cooldowns is the main anchor frame.",
                order = 62,
                hidden = function() return not self.db.profile.groupFrames end,
            },
            
            -- Essential Cooldowns
            headerEssential = { type = "header", name = "Essential Cooldowns", order = 75, hidden = function() return not self.db.profile.groupFrames end },
            
            essentialAttachTo = {
                name = "Attach To",
                desc = "Which frame to attach Essential Cooldowns to.",
                type = "select",
                order = 76,
                values = {
                    ["buffs"] = "Tracked Buffs",
                    ["primaryBar"] = "Primary Resource Bar",
                    ["secondaryBar"] = "Secondary Resource Bar",
                    ["utility"] = "Utility Cooldowns",
                    ["bars"] = "Tracked Bars",
                },
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.essential.attachTo end,
                set = function(_, v)
                    self.db.profile.frames.essential.attachTo = v
                    self:UpdateFrameGrouping()
                end
            },
            
            essentialPosition = {
                name = "Position",
                desc = "Where to attach relative to the anchor frame.",
                type = "select",
                order = 77,
                values = {
                    ["BOTTOM"] = "Below",
                    ["TOP"] = "Above",
                    ["LEFT"] = "Left",
                    ["RIGHT"] = "Right"
                },
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.essential.attachPosition end,
                set = function(_, v)
                    self.db.profile.frames.essential.attachPosition = v
                    self:UpdateFrameGrouping()
                end
            },
            
            essentialOffsetX = {
                name = "Horizontal Offset",
                type = "range",
                order = 78,
                min = -200, max = 200, step = 1,
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.essential.offsetX end,
                set = function(_, v)
                    self.db.profile.frames.essential.offsetX = v
                    self:UpdateFrameGrouping()
                end
            },
            
            essentialOffsetY = {
                name = "Vertical Offset",
                type = "range",
                order = 79,
                min = -200, max = 200, step = 1,
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.essential.offsetY end,
                set = function(_, v)
                    self.db.profile.frames.essential.offsetY = v
                    self:UpdateFrameGrouping()
                end
            },
            
            -- Utility Cooldowns
            headerUtility = { type = "header", name = "Utility Cooldowns", order = 80, hidden = function() return not self.db.profile.groupFrames end },
            
            utilityAttachTo = {
                name = "Attach To",
                desc = "Which frame to attach Utility Cooldowns to.",
                type = "select",
                order = 81,
                values = {
                    ["buffs"] = "Tracked Buffs",
                    ["primaryBar"] = "Primary Resource Bar",
                    ["secondaryBar"] = "Secondary Resource Bar",
                    ["essential"] = "Essential Cooldowns",
                    ["bars"] = "Tracked Bars",
                },
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.utility.attachTo end,
                set = function(_, v)
                    self.db.profile.frames.utility.attachTo = v
                    self:UpdateFrameGrouping()
                end
            },
            
            utilityPosition = {
                name = "Position",
                desc = "Where to attach relative to the anchor frame.",
                type = "select",
                order = 82,
                values = {
                    ["BOTTOM"] = "Below",
                    ["TOP"] = "Above",
                    ["LEFT"] = "Left",
                    ["RIGHT"] = "Right"
                },
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.utility.attachPosition end,
                set = function(_, v)
                    self.db.profile.frames.utility.attachPosition = v
                    self:UpdateFrameGrouping()
                end
            },
            
            utilityOffsetX = {
                name = "Horizontal Offset",
                type = "range",
                order = 83,
                min = -200, max = 200, step = 1,
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.utility.offsetX end,
                set = function(_, v)
                    self.db.profile.frames.utility.offsetX = v
                    self:UpdateFrameGrouping()
                end
            },
            
            utilityOffsetY = {
                name = "Vertical Offset",
                type = "range",
                order = 84,
                min = -200, max = 200, step = 1,
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.utility.offsetY end,
                set = function(_, v)
                    self.db.profile.frames.utility.offsetY = v
                    self:UpdateFrameGrouping()
                end
            },
            
            -- Tracked Buffs
            headerBuffs = { type = "header", name = "Tracked Buffs", order = 90, hidden = function() return not self.db.profile.groupFrames end },
            
            buffsAttachTo = {
                name = "Attach To",
                desc = "Which frame to attach Tracked Buffs to.",
                type = "select",
                order = 91,
                values = {
                    ["primaryBar"] = "Primary Resource Bar",
                    ["secondaryBar"] = "Secondary Resource Bar",
                    ["essential"] = "Essential Cooldowns",
                    ["utility"] = "Utility Cooldowns",
                    ["bars"] = "Tracked Bars",
                },
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.buffs.attachTo end,
                set = function(_, v)
                    self.db.profile.frames.buffs.attachTo = v
                    self:UpdateFrameGrouping()
                end
            },
            
            buffsPosition = {
                name = "Position",
                desc = "Where to attach relative to the anchor frame.",
                type = "select",
                order = 92,
                values = {
                    ["BOTTOM"] = "Below",
                    ["TOP"] = "Above",
                    ["LEFT"] = "Left",
                    ["RIGHT"] = "Right"
                },
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.buffs.attachPosition end,
                set = function(_, v)
                    self.db.profile.frames.buffs.attachPosition = v
                    self:UpdateFrameGrouping()
                end
            },
            
            buffsOffsetX = {
                name = "Horizontal Offset",
                type = "range",
                order = 93,
                min = -200, max = 200, step = 1,
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.buffs.offsetX end,
                set = function(_, v)
                    self.db.profile.frames.buffs.offsetX = v
                    self:UpdateFrameGrouping()
                end
            },
            
            buffsOffsetY = {
                name = "Vertical Offset",
                type = "range",
                order = 94,
                min = -200, max = 200, step = 1,
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.buffs.offsetY end,
                set = function(_, v)
                    self.db.profile.frames.buffs.offsetY = v
                    self:UpdateFrameGrouping()
                end
            },
            
            -- Tracked Bars
            headerBars = { type = "header", name = "Tracked Bars", order = 100, hidden = function() return not self.db.profile.groupFrames end },
            
            barsAttachTo = {
                name = "Attach To",
                desc = "Which frame to attach Tracked Bars to.",
                type = "select",
                order = 101,
                values = {
                    ["buffs"] = "Tracked Buffs",
                    ["primaryBar"] = "Primary Resource Bar",
                    ["secondaryBar"] = "Secondary Resource Bar",
                    ["essential"] = "Essential Cooldowns",
                    ["utility"] = "Utility Cooldowns",
                },
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.bars.attachTo end,
                set = function(_, v)
                    self.db.profile.frames.bars.attachTo = v
                    self:UpdateFrameGrouping()
                end
            },
            
            barsPosition = {
                name = "Position",
                desc = "Where to attach relative to the anchor frame.",
                type = "select",
                order = 102,
                values = {
                    ["BOTTOM"] = "Below",
                    ["TOP"] = "Above",
                    ["LEFT"] = "Left",
                    ["RIGHT"] = "Right"
                },
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.bars.attachPosition end,
                set = function(_, v)
                    self.db.profile.frames.bars.attachPosition = v
                    self:UpdateFrameGrouping()
                end
            },
            
            barsOffsetX = {
                name = "Horizontal Offset",
                type = "range",
                order = 93,
                min = -200, max = 200, step = 1,
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.bars.offsetX end,
                set = function(_, v)
                    self.db.profile.frames.bars.offsetX = v
                    self:UpdateFrameGrouping()
                end
            },
            
            barsOffsetY = {
                name = "Vertical Offset",
                type = "range",
                order = 94,
                min = -200, max = 200, step = 1,
                hidden = function() return not self.db.profile.groupFrames end,
                disabled = function() return not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.frames.bars.offsetY end,
                set = function(_, v)
                    self.db.profile.frames.bars.offsetY = v
                    self:UpdateFrameGrouping()
                end
            },
        }
    }
end

