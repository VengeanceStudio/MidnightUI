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
        
        -- Position & Size
        locked = false,
        point = "CENTER",
        x = 0,
        y = 150,
        scale = 1.0,
        iconSize = 36,
        iconSpacing = 4,
        
        -- Layout
        growthDirection = "RIGHT", -- RIGHT, LEFT, UP, DOWN
        maxIcons = 12,
        
        -- Appearance
        showBorder = true,
        borderColor = {0, 0, 0, 1},
        backgroundColor = {0, 0, 0, 0.5},
        
        -- Font (for cooldown text)
        font = "Friz Quadrata TT",
        fontSize = 12,
        fontOutline = "OUTLINE",
        
        -- Filtering
        minCooldown = 10, -- Only track cooldowns longer than this (seconds)
        showOffensives = true,
        showDefensives = true,
        showUtility = true,
        showMovement = false,
    }
}

-- -----------------------------------------------------------------------------
-- INITIALIZATION
-- -----------------------------------------------------------------------------
function Cooldowns:OnInitialize()
    -- Just register for DB ready message, don't check MidnightUI.db here
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "OnDBReady")
end

function Cooldowns:OnDBReady()
    -- NOW it's safe to check MidnightUI.db
    if not MidnightUI.db or not MidnightUI.db.profile or not MidnightUI.db.profile.modules.cooldowns then
        self:Disable()
        return
    end
    
    self.db = MidnightUI.db:RegisterNamespace("Cooldowns", defaults)
    
    -- Register event
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Register for Move Mode changes using AceEvent's message system
    self:RegisterMessage("MIDNIGHTUI_MOVEMODE_CHANGED", "OnMoveModeChanged")
end

function Cooldowns:PLAYER_ENTERING_WORLD()
    C_Timer.After(1, function()
        self:SetupCooldownFrame()
    end)
end

-- -----------------------------------------------------------------------------
-- COOLDOWN FRAME SETUP
-- -----------------------------------------------------------------------------
function Cooldowns:SetupCooldownFrame()
    -- The new Blizzard cooldown frame is SpellActivationOverlayFrame or might be under a different name
    -- Let's check for the main cooldown tracking frame
    local cooldownFrame = _G["PlayerSpellsFrame"] and _G["PlayerSpellsFrame"].SpellBookFrame
    
    -- If we can't find it, look for the actual cooldown overlay
    if not cooldownFrame then
        -- The new system might be called differently, let's hook into it
        -- Check for the new Cooldown Manager addon integration point
        if C_Spell and C_Spell.GetSpellCooldown then
            self:CreateCustomCooldownTracker()
            return
        end
    end
    
    -- If we found the Blizzard frame, customize it
    if cooldownFrame then
        self:CustomizeBlizzardFrame(cooldownFrame)
    else
        print("|cff00ff00MidnightUI:|r Blizzard Cooldown Manager not found. Creating custom tracker.")
        self:CreateCustomCooldownTracker()
    end
end

function Cooldowns:CustomizeBlizzardFrame(frame)
    -- This would customize the actual Blizzard cooldown manager if we can find it
    -- For now, let's create our own since the Blizzard implementation might vary
    self:CreateCustomCooldownTracker()
end

-- -----------------------------------------------------------------------------
-- CUSTOM COOLDOWN TRACKER (Based on Blizzard's system)
-- -----------------------------------------------------------------------------
function Cooldowns:CreateCustomCooldownTracker()
    if self.cooldownFrame then return end
    
    local db = self.db.profile
    
    -- Create main container
    local frame = CreateFrame("Frame", "MidnightCooldownTracker", UIParent, "BackdropTemplate")
    frame:SetSize(db.iconSize * db.maxIcons + db.iconSpacing * (db.maxIcons - 1), db.iconSize)
    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    frame:SetScale(db.scale)
    frame:SetMovable(true)
    frame:EnableMouse(false)
    frame:SetClampedToScreen(true)
    
    -- Backdrop
    if db.showBorder then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        frame:SetBackdropColor(unpack(db.backgroundColor))
        frame:SetBackdropBorderColor(unpack(db.borderColor))
    end
    
    -- Store frame
    self.cooldownFrame = frame
    self.cooldownIcons = {}
    
    -- Create icon pool
    for i = 1, db.maxIcons do
        local icon = self:CreateCooldownIcon(frame, i)
        table.insert(self.cooldownIcons, icon)
    end
    
    -- Setup dragging
    self:SetupDragging()
    
    -- Start tracking cooldowns
    self:StartTracking()
end

function Cooldowns:CreateCooldownIcon(parent, index)
    local db = self.db.profile
    local size = db.iconSize
    
    local icon = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    icon:SetSize(size, size)
    icon:Hide()
    
    -- Background
    icon.bg = icon:CreateTexture(nil, "BACKGROUND")
    icon.bg:SetAllPoints()
    icon.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    
    -- Icon texture
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetPoint("CENTER")
    icon.texture:SetSize(size - 4, size - 4)
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Border
    icon:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    icon:SetBackdropBorderColor(0, 0, 0, 1)
    
    -- Cooldown overlay (spiral)
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints(icon.texture)
    icon.cooldown:SetReverse(true)
    icon.cooldown:SetHideCountdownNumbers(false)
    
    -- Cooldown text
    icon.text = icon:CreateFontString(nil, "OVERLAY")
    icon.text:SetPoint("CENTER", 0, 0)
    local font = LSM:Fetch("font", db.font)
    icon.text:SetFont(font, db.fontSize, db.fontOutline)
    icon.text:SetTextColor(1, 1, 1, 1)
    icon.text:SetShadowOffset(1, -1)
    icon.text:SetShadowColor(0, 0, 0, 1)
    
    -- Stacks text
    icon.stacks = icon:CreateFontString(nil, "OVERLAY")
    icon.stacks:SetPoint("BOTTOMRIGHT", -2, 2)
    icon.stacks:SetFont(font, db.fontSize - 2, db.fontOutline)
    icon.stacks:SetTextColor(1, 1, 1, 1)
    
    return icon
end

function Cooldowns:StartTracking()
    if self.trackingTimer then return end
    
    -- Update cooldowns every 0.1 seconds
    self.trackingTimer = C_Timer.NewTicker(0.1, function()
        self:UpdateCooldownDisplay()
    end)
end

function Cooldowns:UpdateCooldownDisplay()
    if not self.cooldownFrame then return end
    
    local db = self.db.profile
    local activeCooldowns = {}
    
    -- Get all player spell cooldowns using the new API
    -- Use C_SpellBook to iterate through known spells
    local slotType = Enum.SpellBookSpellBank.Player
    local numSpells = C_SpellBook.GetNumSpellBookSkillLines()
    
    for i = 1, 200 do -- Still iterate through spell slots
        -- Try to get spell info using the new API
        local spellInfo = C_SpellBook.GetSpellBookItemInfo(i, slotType)
        
        if not spellInfo then break end
        
        -- Check if it's a spell (not a flyout or pet action)
        if spellInfo.itemType == Enum.SpellBookItemType.Spell or spellInfo.itemType == 1 then
            local spellID = spellInfo.actionID or spellInfo.spellID
            local spellName = spellInfo.name
            
            if spellID then
                local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
                
                -- Safely check cooldown info - some values may be "secret" and protected
                if cooldownInfo and cooldownInfo.startTime and cooldownInfo.duration then
                    local start = cooldownInfo.startTime
                    local duration = cooldownInfo.duration
                    
                    -- Use pcall to safely compare secret values
                    local success, isLongCooldown = pcall(function() return duration > 1.5 end)
                    
                    if success and isLongCooldown then
                        local remaining = start + duration - GetTime()
                        
                        if remaining > 0 then
                            local texture = C_Spell.GetSpellTexture(spellID)
                            
                            table.insert(activeCooldowns, {
                                spellID = spellID,
                                name = spellName,
                                texture = texture,
                                start = start,
                                duration = duration,
                                remaining = remaining,
                            })
                        end
                    end
                end
            end
        end
    end
    
    -- Sort by remaining time
    table.sort(activeCooldowns, function(a, b) return a.remaining < b.remaining end)
    
    -- Update icon display
    for i, iconFrame in ipairs(self.cooldownIcons) do
        local cd = activeCooldowns[i]
        
        if cd then
            iconFrame.texture:SetTexture(cd.texture)
            iconFrame.cooldown:SetCooldown(cd.start, cd.duration)
            
            -- Update text
            local timeText = self:FormatTime(cd.remaining)
            iconFrame.text:SetText(timeText)
            
            -- Position icon
            self:PositionIcon(iconFrame, i)
            
            iconFrame:Show()
        else
            iconFrame:Hide()
        end
    end
end

function Cooldowns:PositionIcon(icon, index)
    local db = self.db.profile
    local offset = (index - 1) * (db.iconSize + db.iconSpacing)
    
    icon:ClearAllPoints()
    
    if db.growthDirection == "RIGHT" then
        icon:SetPoint("LEFT", self.cooldownFrame, "LEFT", offset, 0)
    elseif db.growthDirection == "LEFT" then
        icon:SetPoint("RIGHT", self.cooldownFrame, "RIGHT", -offset, 0)
    elseif db.growthDirection == "UP" then
        icon:SetPoint("BOTTOM", self.cooldownFrame, "BOTTOM", 0, offset)
    elseif db.growthDirection == "DOWN" then
        icon:SetPoint("TOP", self.cooldownFrame, "TOP", 0, -offset)
    end
end

function Cooldowns:FormatTime(seconds)
    if seconds >= 86400 then
        return string.format("%dd", math.floor(seconds / 86400))
    elseif seconds >= 3600 then
        return string.format("%dh", math.floor(seconds / 3600))
    elseif seconds >= 60 then
        return string.format("%dm", math.floor(seconds / 60))
    elseif seconds >= 10 then
        return string.format("%d", math.floor(seconds))
    else
        return string.format("%.1f", seconds)
    end
end

-- -----------------------------------------------------------------------------
-- DRAGGING SUPPORT
-- -----------------------------------------------------------------------------
function Cooldowns:SetupDragging()
    local frame = self.cooldownFrame
    if not frame then return end
    
    local Movable = MidnightUI:GetModule("Movable")
    
    Movable:MakeFrameDraggable(
        frame,
        function(point, x, y)
            Cooldowns.db.profile.point = point
            Cooldowns.db.profile.x = x
            Cooldowns.db.profile.y = y
        end,
        nil  -- No unlock check, always use CTRL+ALT or Move Mode
    )
end

function Cooldowns:OnMoveModeChanged(event, enabled)
    if not self.cooldownFrame then return end
    
    if enabled then
        self.cooldownFrame:EnableMouse(true)
    else
        self.cooldownFrame:EnableMouse(false)
    end
end

-- -----------------------------------------------------------------------------
-- OPTIONS
-- -----------------------------------------------------------------------------
function Cooldowns:GetOptions()
    return {
        type = "group",
        name = "Cooldown Tracker",
        order = 10,
        args = {
            header = {
                type = "header",
                name = "Cooldown Tracker Display",
                order = 1
            },
            desc = {
                type = "description",
                name = "Tracks and displays spell cooldowns similar to the Blizzard Cooldown Manager.\n\nHold CTRL+ALT to drag, or use /muimove to enable Move Mode.",
                order = 2
            },
            
            headerPosition = { type = "header", name = "Position & Size", order = 10 },
            scale = {
                name = "Scale",
                type = "range",
                order = 11,
                min = 0.5,
                max = 2.0,
                step = 0.1,
                get = function() return self.db.profile.scale end,
                set = function(_, v)
                    self.db.profile.scale = v
                    if self.cooldownFrame then
                        self.cooldownFrame:SetScale(v)
                    end
                end
            },
            iconSize = {
                name = "Icon Size",
                type = "range",
                order = 12,
                min = 20,
                max = 80,
                step = 1,
                get = function() return self.db.profile.iconSize end,
                set = function(_, v)
                    self.db.profile.iconSize = v
                    ReloadUI()
                end
            },
            iconSpacing = {
                name = "Icon Spacing",
                type = "range",
                order = 13,
                min = 0,
                max = 20,
                step = 1,
                get = function() return self.db.profile.iconSpacing end,
                set = function(_, v)
                    self.db.profile.iconSpacing = v
                    ReloadUI()
                end
            },
            maxIcons = {
                name = "Maximum Icons",
                type = "range",
                order = 14,
                min = 5,
                max = 20,
                step = 1,
                get = function() return self.db.profile.maxIcons end,
                set = function(_, v)
                    self.db.profile.maxIcons = v
                    ReloadUI()
                end
            },
            growthDirection = {
                name = "Growth Direction",
                type = "select",
                order = 15,
                values = {
                    RIGHT = "Right",
                    LEFT = "Left",
                    UP = "Up",
                    DOWN = "Down"
                },
                get = function() return self.db.profile.growthDirection end,
                set = function(_, v)
                    self.db.profile.growthDirection = v
                    ReloadUI()
                end
            },
            
            headerAppearance = { type = "header", name = "Appearance", order = 20 },
            showBorder = {
                name = "Show Border",
                type = "toggle",
                order = 21,
                get = function() return self.db.profile.showBorder end,
                set = function(_, v)
                    self.db.profile.showBorder = v
                    ReloadUI()
                end
            },
            font = {
                name = "Font",
                type = "select",
                order = 22,
                dialogControl = "LSM30_Font",
                values = LSM:HashTable("font"),
                get = function() return self.db.profile.font end,
                set = function(_, v)
                    self.db.profile.font = v
                    ReloadUI()
                end
            },
            fontSize = {
                name = "Font Size",
                type = "range",
                order = 23,
                min = 8,
                max = 32,
                step = 1,
                get = function() return self.db.profile.fontSize end,
                set = function(_, v)
                    self.db.profile.fontSize = v
                    ReloadUI()
                end
            },
            
            headerReset = { type = "header", name = "Reset", order = 30 },
            resetPosition = {
                name = "Reset Position",
                type = "execute",
                order = 31,
                func = function()
                    self.db.profile.point = "CENTER"
                    self.db.profile.x = 0
                    self.db.profile.y = 200
                    if self.cooldownFrame then
                        self.cooldownFrame:ClearAllPoints()
                        self.cooldownFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
                    end
                end
            }
        }
    }
end