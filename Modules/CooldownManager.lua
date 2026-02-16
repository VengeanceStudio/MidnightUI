-- CooldownManager.lua
-- Skins and positions Blizzard's cooldown manager frames with MidnightUI styling

local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local LSM = LibStub("LibSharedMedia-3.0")

-- Create the module
local CooldownManager = MidnightUI:NewModule("CooldownManager", "AceEvent-3.0", "AceHook-3.0")

-- Module reference for global access
_G.CooldownManager = CooldownManager

--------------------------------------------------------------------------------
-- Defaults
--------------------------------------------------------------------------------

local defaults = {
    profile = {
        enabled = true,
        
        -- Essential Cooldowns
        essential = {
            enabled = true,
            position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = -200 },
            iconWidth = 44,
            iconHeight = 44,
            iconSpacing = 4,
            maxPerRow = 12,
            borderThickness = 2,
            borderColor = { 0, 0, 0, 1 },
            backgroundColor = { 0, 0, 0, 0.8 },
            font = "Friz Quadrata TT",
            fontSize = 14,
            fontFlag = "OUTLINE",
        },
        
        -- Utility Cooldowns
        utility = {
            enabled = true,
            position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = -250 },
            iconWidth = 36,
            iconHeight = 36,
            iconSpacing = 4,
            maxPerRow = 16,
            borderThickness = 2,
            borderColor = { 0, 0, 0, 1 },
            backgroundColor = { 0, 0, 0, 0.8 },
            font = "Friz Quadrata TT",
            fontSize = 12,
            fontFlag = "OUTLINE",
        },
        
        -- Font settings
        font = "Friz Quadrata TT",
        fontSize = 14,
        fontFlag = "OUTLINE",
    }
}

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function CooldownManager:OnInitialize()
    -- Setup database
    self.db = MidnightUI.db:RegisterNamespace("CooldownManager", defaults)
    
    -- Create container frames
    self:CreateContainerFrames()
end

function CooldownManager:OnEnable()
    if not self.db.profile.enabled then return end
    
    -- Enable Blizzard's cooldown manager
    C_CVar.SetCVar("cooldownViewerEnabled", "1")
    
    -- Hook Blizzard's cooldown manager updates
    self:HookBlizzardCooldownManager()
    
    -- Initial styling and layout
    self:UpdateCooldownManager()
    
    -- Register events
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateCooldownManager")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "UpdateCooldownManager")
    self:RegisterEvent("SPELLS_CHANGED", "UpdateCooldownManager")
end

function CooldownManager:OnDisable()
    self:UnhookAll()
    self:UnregisterAllEvents()
    
    if self.essentialFrame then
        self.essentialFrame:Hide()
    end
    if self.utilityFrame then
        self.utilityFrame:Hide()
    end
end

--------------------------------------------------------------------------------
-- Container Frames
--------------------------------------------------------------------------------

function CooldownManager:CreateContainerFrames()
    -- Essential cooldowns container
    self.essentialFrame = CreateFrame("Frame", "MidnightUI_EssentialCooldowns", UIParent)
    self.essentialFrame:SetSize(600, 50)
    self.essentialFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    self.essentialFrame.displayType = "essential"
    
    -- Utility cooldowns container
    self.utilityFrame = CreateFrame("Frame", "MidnightUI_UtilityCooldowns", UIParent)
    self.utilityFrame:SetSize(600, 40)
    self.utilityFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -250)
    self.utilityFrame.displayType = "utility"
    
    -- Apply positions from saved variables
    self:ApplyFramePosition(self.essentialFrame, "essential")
    self:ApplyFramePosition(self.utilityFrame, "utility")
end

function CooldownManager:ApplyFramePosition(frame, displayType)
    local pos = self.db.profile[displayType].position
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, _G[pos.relativeTo] or UIParent, pos.relativePoint, pos.x, pos.y)
end

function CooldownManager:SaveFramePosition(frame, displayType)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    local pos = self.db.profile[displayType].position
    pos.point = point
    pos.relativeTo = relativeTo and relativeTo:GetName() or "UIParent"
    pos.relativePoint = relativePoint
    pos.x = x
    pos.y = y
end

--------------------------------------------------------------------------------
-- Blizzard Frame Hooking
--------------------------------------------------------------------------------

function CooldownManager:HookBlizzardCooldownManager()
    -- Hook when Blizzard's cooldown manager updates
    if CooldownViewerSettings then
        self:SecureHook(CooldownViewerSettings, "RefreshLayout", function()
            C_Timer.After(0.1, function()
                self:UpdateCooldownManager()
            end)
        end)
    end
    
    -- Hook Edit Mode changes
    if EditModeManagerFrame then
        self:SecureHook(EditModeManagerFrame, "EnterEditMode", "OnEditModeEnter")
        self:SecureHook(EditModeManagerFrame, "ExitEditMode", "OnEditModeExit")
    end
end

function CooldownManager:OnEditModeEnter()
    -- User is in Blizzard's Edit Mode - don't interfere
end

function CooldownManager:OnEditModeExit()
    -- Re-apply our styling after Edit Mode changes
    self:UpdateCooldownManager()
end

--------------------------------------------------------------------------------
-- Main Update Function
--------------------------------------------------------------------------------

function CooldownManager:UpdateCooldownManager()
    if not self.db.profile.enabled then return end
    if InCombatLockdown() then
        -- Queue update for after combat
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UpdateCooldownManager()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        end)
        return
    end
    
    -- Update Essential Cooldowns
    if self.db.profile.essential.enabled then
        self:UpdateViewerDisplay("EssentialCooldownViewer", "essential")
    end
    
    -- Update Utility Cooldowns
    if self.db.profile.utility.enabled then
        self:UpdateViewerDisplay("UtilityCooldownViewer", "utility")
    end
end

function CooldownManager:UpdateViewerDisplay(viewerName, displayType)
    local viewer = _G[viewerName]
    if not viewer then return end
    
    -- Hide the Blizzard frame itself (we only want its children)
    viewer:SetAlpha(0)
    viewer:EnableMouse(false)
    
    -- Get all child frames from Blizzard's viewer
    local children = { viewer:GetChildren() }
    local visibleFrames = {}
    
    -- Skin and collect visible frames
    for _, childFrame in ipairs(children) do
        if childFrame and childFrame.layoutIndex and childFrame:IsShown() then
            self:SkinBlizzardFrame(childFrame, displayType)
            table.insert(visibleFrames, childFrame)
        end
    end
    
    -- Sort by layout index
    table.sort(visibleFrames, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    
    -- Layout the frames
    self:LayoutFrames(visibleFrames, displayType)
end

--------------------------------------------------------------------------------
-- Frame Styling
--------------------------------------------------------------------------------

function CooldownManager:SkinBlizzardFrame(childFrame, displayType)
    local db = self.db.profile[displayType]
    
    -- Resize the frame
    childFrame:SetSize(db.iconWidth, db.iconHeight)
    
    -- Reparent to our container
    local container = displayType == "essential" and self.essentialFrame or self.utilityFrame
    childFrame:SetParent(container)
    childFrame:SetFrameLevel(container:GetFrameLevel() + 1)
    
    -- Style the icon
    if childFrame.Icon then
        childFrame.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        childFrame.Icon:ClearAllPoints()
        childFrame.Icon:SetPoint("TOPLEFT", childFrame, "TOPLEFT", db.borderThickness, -db.borderThickness)
        childFrame.Icon:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", -db.borderThickness, db.borderThickness)
    end
    
    -- Style the cooldown swipe
    if childFrame.Cooldown then
        childFrame.Cooldown:SetSwipeColor(0, 0, 0, 0.8)
        childFrame.Cooldown:SetDrawEdge(false)
        childFrame.Cooldown:SetDrawSwipe(true)
        childFrame.Cooldown:SetHideCountdownNumbers(true)
        childFrame.Cooldown:ClearAllPoints()
        childFrame.Cooldown:SetPoint("TOPLEFT", childFrame, "TOPLEFT", db.borderThickness, -db.borderThickness)
        childFrame.Cooldown:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", -db.borderThickness, db.borderThickness)
    end
    
    -- Add custom border if it doesn't exist
    if not childFrame.customBorder then
        childFrame.customBorder = childFrame:CreateTexture(nil, "BORDER")
        childFrame.customBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
        childFrame.customBorder:SetAllPoints(childFrame)
        childFrame.customBorder:SetVertexColor(db.borderColor[1], db.borderColor[2], db.borderColor[3], db.borderColor[4])
    end
    
    -- Add custom background
    if not childFrame.customBackground then
        childFrame.customBackground = childFrame:CreateTexture(nil, "BACKGROUND")
        childFrame.customBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
        childFrame.customBackground:SetPoint("TOPLEFT", childFrame, "TOPLEFT", db.borderThickness, -db.borderThickness)
        childFrame.customBackground:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", -db.borderThickness, db.borderThickness)
        childFrame.customBackground:SetVertexColor(db.backgroundColor[1], db.backgroundColor[2], db.backgroundColor[3], db.backgroundColor[4])
    end
    
    -- Style charge count text
    if childFrame.ChargeCount and childFrame.ChargeCount.Current then
        local fontPath = LSM:Fetch("font", db.font)
        childFrame.ChargeCount.Current:SetFont(fontPath, db.fontSize, db.fontFlag)
        childFrame.ChargeCount.Current:SetTextColor(1, 1, 1, 1)
    end
    
    -- Style application count text
    if childFrame.Applications and childFrame.Applications.Applications then
        local fontPath = LSM:Fetch("font", db.font)
        childFrame.Applications.Applications:SetFont(fontPath, db.fontSize, db.fontFlag)
        childFrame.Applications.Applications:SetTextColor(1, 1, 1, 1)
    end
    
    -- Hide elements we don't want
    if childFrame.CooldownFlash then
        childFrame.CooldownFlash:SetAlpha(0)
    end
    if childFrame.DebuffBorder then
        childFrame.DebuffBorder:SetAlpha(0)
    end
    
    -- Make sure the frame is visible
    childFrame:Show()
end

--------------------------------------------------------------------------------
-- Frame Layout
--------------------------------------------------------------------------------

function CooldownManager:LayoutFrames(frames, displayType)
    local db = self.db.profile[displayType]
    local container = displayType == "essential" and self.essentialFrame or self.utilityFrame
    
    if #frames == 0 then
        container:Hide()
        return
    end
    
    container:Show()
    
    local iconWidth = db.iconWidth
    local iconHeight = db.iconHeight
    local spacing = db.iconSpacing
    local maxPerRow = db.maxPerRow
    
    local row = 0
    local col = 0
    
    for i, frame in ipairs(frames) do
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", col * (iconWidth + spacing), -row * (iconHeight + spacing))
        
        col = col + 1
        if col >= maxPerRow then
            col = 0
            row = row + 1
        end
    end
    
    -- Resize container to fit content
    local numRows = math.ceil(#frames / maxPerRow)
    local numCols = math.min(#frames, maxPerRow)
    local containerWidth = (numCols * iconWidth) + ((numCols - 1) * spacing)
    local containerHeight = (numRows * iconHeight) + ((numRows - 1) * spacing)
    container:SetSize(containerWidth, containerHeight)
end

--------------------------------------------------------------------------------
-- Configuration Options
--------------------------------------------------------------------------------

function CooldownManager:GetOptions()
    return {
        type = "group",
        name = "Cooldown Manager",
        args = {
            enabled = {
                type = "toggle",
                name = "Enable Cooldown Manager",
                desc = "Enable the cooldown manager module",
                order = 1,
                get = function() return self.db.profile.enabled end,
                set = function(_, value)
                    self.db.profile.enabled = value
                    if value then
                        self:Enable()
                    else
                        self:Disable()
                    end
                end,
            },
            essential = {
                type = "group",
                name = "Essential Cooldowns",
                order = 2,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enable",
                        order = 1,
                        get = function() return self.db.profile.essential.enabled end,
                        set = function(_, value)
                            self.db.profile.essential.enabled = value
                            self:UpdateCooldownManager()
                        end,
                    },
                    iconSize = {
                        type = "range",
                        name = "Icon Size",
                        order = 2,
                        min = 24,
                        max = 64,
                        step = 2,
                        get = function() return self.db.profile.essential.iconWidth end,
                        set = function(_, value)
                            self.db.profile.essential.iconWidth = value
                            self.db.profile.essential.iconHeight = value
                            self:UpdateCooldownManager()
                        end,
                    },
                    spacing = {
                        type = "range",
                        name = "Icon Spacing",
                        order = 3,
                        min = 0,
                        max = 20,
                        step = 1,
                        get = function() return self.db.profile.essential.iconSpacing end,
                        set = function(_, value)
                            self.db.profile.essential.iconSpacing = value
                            self:UpdateCooldownManager()
                        end,
                    },
                    maxPerRow = {
                        type = "range",
                        name = "Icons Per Row",
                        order = 4,
                        min = 1,
                        max = 20,
                        step = 1,
                        get = function() return self.db.profile.essential.maxPerRow end,
                        set = function(_, value)
                            self.db.profile.essential.maxPerRow = value
                            self:UpdateCooldownManager()
                        end,
                    },
                },
            },
            utility = {
                type = "group",
                name = "Utility Cooldowns",
                order = 3,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enable",
                        order = 1,
                        get = function() return self.db.profile.utility.enabled end,
                        set = function(_, value)
                            self.db.profile.utility.enabled = value
                            self:UpdateCooldownManager()
                        end,
                    },
                    iconSize = {
                        type = "range",
                        name = "Icon Size",
                        order = 2,
                        min = 24,
                        max = 64,
                        step = 2,
                        get = function() return self.db.profile.utility.iconWidth end,
                        set = function(_, value)
                            self.db.profile.utility.iconWidth = value
                            self.db.profile.utility.iconHeight = value
                            self:UpdateCooldownManager()
                        end,
                    },
                    spacing = {
                        type = "range",
                        name = "Icon Spacing",
                        order = 3,
                        min = 0,
                        max = 20,
                        step = 1,
                        get = function() return self.db.profile.utility.iconSpacing end,
                        set = function(_, value)
                            self.db.profile.utility.iconSpacing = value
                            self:UpdateCooldownManager()
                        end,
                    },
                    maxPerRow = {
                        type = "range",
                        name = "Icons Per Row",
                        order = 4,
                        min = 1,
                        max = 20,
                        step = 1,
                        get = function() return self.db.profile.utility.maxPerRow end,
                        set = function(_, value)
                            self.db.profile.utility.maxPerRow = value
                            self:UpdateCooldownManager()
                        end,
                    },
                },
            },
        },
    }
end

return CooldownManager
