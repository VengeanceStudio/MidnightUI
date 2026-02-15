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
        
        -- Custom Buff Bars (replace Blizzard's Tracked Bars)
        customBuffBars = {
            enabled = true,
            maxBars = 8,
            barHeight = 20,
            barWidth = 300,
            spacing = 2,
            showIcons = true,
            showTimers = true,
            showStacks = true,
            iconSize = 20,
            font = "Friz Quadrata TT",
            fontSize = 12,
            fontFlag = "OUTLINE",
            barColor = {0.2, 0.8, 1.0, 1.0},  -- Bar color (R, G, B, A)
            barBorderColor = {1, 1, 1, 1},  -- Bar border color (white for visibility)
            useClassColor = false,  -- Use class color instead of custom color
            fadeColor = true,  -- Fade color as time decreases
        },
        
        -- Individual display settings
        essential = {
            enabled = true,
            iconsPerRow = 10,
            iconWidth = 40,
            iconHeight = 40,
            iconSpacing = 2,
            borderThickness = 2,
            borderColor = {0.2, 0.8, 1.0, 1.0},
            attachTo = "none",  -- "none", "primaryBar", "secondaryBar", etc.
            attachPosition = "BOTTOM",
            offsetX = 0,
            offsetY = -2,
        },
        utility = {
            enabled = true,
            iconsPerRow = 10,
            iconWidth = 40,
            iconHeight = 40,
            iconSpacing = 2,
            borderThickness = 2,
            borderColor = {0.2, 0.8, 1.0, 1.0},
            attachTo = "essential",
            attachPosition = "BOTTOM",
            offsetX = 0,
            offsetY = -2,
        },
        buffs = {
            enabled = true,
            iconsPerRow = 10,
            iconWidth = 40,
            iconHeight = 40,
            iconSpacing = 2,
            borderThickness = 2,
            borderColor = {0.2, 0.8, 1.0, 1.0},
            attachTo = "utility",
            attachPosition = "BOTTOM",
            offsetX = 0,
            offsetY = -2,
        },
        
        -- Custom Buff Bars (Tracked Bars)
        customBuffBars = {
            enabled = true,
            maxBars = 8,
            barHeight = 20,
            barWidth = 300,
            spacing = 2,
            showIcons = true,
            showTimers = true,
            showStacks = true,
            iconSize = 20,
            font = "Friz Quadrata TT",
            fontSize = 12,
            fontFlag = "OUTLINE",
            barColor = {0.2, 0.8, 1.0, 1.0},  -- Bar color (R, G, B, A)
            barBorderColor = {1, 1, 1, 1},  -- Bar border color (white for visibility)
            useClassColor = false,  -- Use class color instead of custom color
            fadeColor = true,  -- Fade color as time decreases
            fontFlag = "OUTLINE",
            borderThickness = 2,
            borderColor = {0.2, 0.8, 1.0, 1.0},
            attachTo = "buffs",
            attachPosition = "BOTTOM",
            offsetX = 0,
            offsetY = -2,
        },
        
        -- Individual frame settings (DEPRECATED - kept for compatibility)
        frames = {
            essential = {
                enabled = true,
                isAnchor = true,
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
    
    -- Create charge color curve for WoW 12.0 secret value handling
    self:CreateChargeColorCurve()
    
    -- Throttle flags to prevent memory leaks
    self.updateAttachmentPending = false
    self.editModeUpdatePending = false
    self.lastStyleUpdate = 0
    
    -- Custom display frames
    self.customFrames = {
        essential = nil,
        utility = nil,
        buffs = nil,
        cooldowns = nil, -- Tracked bars
    }
    self.iconPools = {}
    self.barPools = {}
end

function Cooldowns:CreateChargeColorCurve()
    -- WoW 12.0: Create a color curve to map charge counts to colors
    -- This works even for secret values since Blizzard handles evaluation internally
    if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then
        -- Fallback if API not available
        self.chargeCurve = nil
        return
    end
    
    local curve = C_CurveUtil.CreateColorCurve()
    
    -- Set to Step mode so it doesn't fade between colors (charges are whole numbers)
    curve:SetType(Enum.LuaCurveType.Step)
    
    -- Add color points: (Value, Color)
    -- 0 Charges: Red (no charges available)
    curve:AddPoint(0, CreateColor(1, 0, 0, 1))
    -- 1 Charge: Yellow (low charges)
    curve:AddPoint(1, CreateColor(1, 1, 0, 1))
    -- 2+ Charges: White/Full (good charges)
    curve:AddPoint(2, CreateColor(1, 1, 1, 1))
    
    self.chargeCurve = curve
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
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    
    -- WoW 12.0 Charge Event System
    self:RegisterEvent("SPELL_UPDATE_CHARGES")  -- Fires when charges change (even for secrets)
    self:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entering combat (data becomes secret)
    self:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Exiting combat (data becomes readable)
    
    -- WoW 12.0 Proc Glow System (Blizzard controls when spells proc)
    self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW") -- Blizzard says spell is ready/proc'd
    self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE") -- Proc ends
    
    -- WoW 12.0 Tracked Bars System
    -- UNIT_AURA fires when buffs start/end, filter for player in handler
    self:RegisterEvent("UNIT_AURA")
    
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

function Cooldowns:EDIT_MODE_LAYOUTS_UPDATED()
    -- Throttle this event to prevent repeated calls
    if self.editModeUpdatePending then return end
    self.editModeUpdatePending = true
    
    -- Immediately reapply positioning when Edit Mode updates layouts
    self:UpdateAttachment()
    self:UpdateFrameGrouping()
    
    -- Also reapply after a delay to catch late updates
    C_Timer.After(0.2, function()
        Cooldowns:UpdateAttachment()
        Cooldowns:UpdateFrameGrouping()
        Cooldowns.editModeUpdatePending = false
    end)
end

function Cooldowns:SPELL_UPDATE_CHARGES()
    -- WoW 12.0: Event fires when any spell charges change (even for secret values)
    -- Refresh icon displays to update charge counters
    self:UpdateAllDisplays()
end

function Cooldowns:PLAYER_REGEN_DISABLED()
    -- Entering combat - charge values may become secret
    -- Refresh displays to switch to pass-through mode
    self:UpdateAllDisplays()
end

function Cooldowns:PLAYER_REGEN_ENABLED()
    -- Exiting combat - charge values become readable again
    -- Refresh displays to restore full functionality
    self:UpdateAllDisplays()
end

function Cooldowns:SPELL_ACTIVATION_OVERLAY_GLOW_SHOW(event, spellID)
    -- Blizzard says this spell is proc'd/ready - show glow on matching icon
    self:ShowIconGlow(spellID)
end

function Cooldowns:SPELL_ACTIVATION_OVERLAY_GLOW_HIDE(event, spellID)
    -- Proc ended - hide glow on matching icon
    self:HideIconGlow(spellID)
end

function Cooldowns:ShowIconGlow(spellID)
    if not spellID or not self.customFrames then return end
    
    -- Find icon with matching spellID in essential and utility frames
    for _, displayType in ipairs({"essential", "utility"}) do
        local frame = self.customFrames[displayType]
        if frame and frame.icons then
            for _, icon in ipairs(frame.icons) do
                -- WoW 12.0: Use secret-aware matching API for spellID comparison
                local matches = false
                if icon.spellID and C_Spell and C_Spell.IsSecretSpellIDMatch then
                    matches = C_Spell.IsSecretSpellIDMatch(icon.spellID, spellID)
                elseif icon.spellID then
                    -- Fallback for older API versions
                    local ok, result = pcall(function() return icon.spellID == spellID end)
                    if ok then matches = result end
                end
                
                if matches and icon:IsShown() then
                    -- Show glow using our glow texture or method
                    if icon.ShowOverlayGlow then
                        icon:ShowOverlayGlow()
                    end
                end
            end
        end
    end
end

function Cooldowns:HideIconGlow(spellID)
    if not spellID or not self.customFrames then return end
    
    -- Find icon with matching spellID in essential and utility frames
    for _, displayType in ipairs({"essential", "utility"}) do
        local frame = self.customFrames[displayType]
        if frame and frame.icons then
            for _, icon in ipairs(frame.icons) do
                -- WoW 12.0: Use secret-aware matching API for spellID comparison
                local matches = false
                if icon.spellID and C_Spell and C_Spell.IsSecretSpellIDMatch then
                    matches = C_Spell.IsSecretSpellIDMatch(icon.spellID, spellID)
                elseif icon.spellID then
                    -- Fallback for older API versions
                    local ok, result = pcall(function() return icon.spellID == spellID end)
                    if ok then matches = result end
                end
                
                if matches then
                    -- Hide glow
                    if icon.HideOverlayGlow then
                        icon:HideOverlayGlow()
                    end
                end
            end
        end
    end
end

-- WoW 12.0: Get tracked bars data - use C_CooldownViewer API with hasAura flag
function Cooldowns:GetTrackedBarsData()
    local cooldowns = {}
    
    if not C_CooldownViewer then
        return cooldowns
    end
    
    -- Check GetLayoutData() - this might return active bars
    if C_CooldownViewer.GetLayoutData then
        local layoutData = C_CooldownViewer.GetLayoutData()
        if layoutData then
            print("=== GetLayoutData() ===")
            print("Type:", type(layoutData))
            if type(layoutData) == "table" then
                for k, v in pairs(layoutData) do
                    print("  " .. tostring(k) .. " = " .. tostring(v))
                    if type(v) == "table" then
                        print("    (table contents):")
                        for k2, v2 in pairs(v) do
                            print("      " .. tostring(k2) .. " = " .. tostring(v2))
                        end
                    end
                end
            end
            print("=======================")
        end
    end
    
    return cooldowns
end

function Cooldowns:UNIT_AURA(event, unitTarget)
    -- Player auras changed
    if unitTarget == "player" then
        self:UpdateAllDisplays()
    end
end

-- -----------------------------------------------------------------------------
-- FIND AND SKIN WOW 12.0 COOLDOWN MANAGER
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- CUSTOM COOLDOWN DISPLAYS
-- -----------------------------------------------------------------------------

function Cooldowns:GetCooldownData(displayName)
    -- WoW 12.0: Use API for tracked bars instead of frame iteration
    if displayName == "cooldowns" then
        return self:GetTrackedBarsData()
    end
    
    -- Get data from Blizzard's actual frames since C_CooldownManager API doesn't exist
    local blizzardFrameMap = {
        essential = "EssentialCooldownViewer",
        utility = "UtilityCooldownViewer",
        buffs = "BuffIconCooldownViewer",
        cooldowns = "BuffBarCooldownViewer",
    }
    
    local frameName = blizzardFrameMap[displayName]
    if not frameName then return {} end
    
    local blizzFrame = _G[frameName]
    if not blizzFrame then 
        return {}
    end
    
    -- Try to get cooldowns from the frame's children
    local cooldowns = {}
    local children = {blizzFrame:GetChildren()}
    
    for _, child in ipairs(children) do
        -- For tracked buffs, check if frame has valid data
        -- For tracked bars, check if they have bar element and valid auraInstanceID
        local shouldInclude = true
        
        if displayName == "buffs" then
            -- Only include if the child has an auraInstanceID (indicates active tracking)
            -- and has size (Blizzard sizes inactive frames to 0)
            local hasValidAura = child.auraInstanceID and child.auraInstanceID > 0
            local hasSize = child:GetWidth() > 0
            shouldInclude = hasValidAura and hasSize
        elseif displayName == "cooldowns" then
            -- WoW 12.0: For tracked bars, use proper API instead of frame iteration
            -- This is handled by GetTrackedBarsData() function instead
            shouldInclude = false
        end
        
        -- Check if child has an Icon (or Bar for tracked bars) and should be included
        local hasContent = child.Icon or (displayName == "cooldowns" and child.Bar)
        if hasContent and shouldInclude then
            local iconTexture = nil
            
            -- For tracked bars, get icon from child.Icon (not Bar regions)
            if displayName == "cooldowns" and child.Icon then
                if child.Icon.GetTexture then
                    iconTexture = child.Icon:GetTexture()
                elseif child.Icon.Texture then
                    iconTexture = child.Icon.Texture:GetTexture()
                else
                    -- Look for texture children in Icon
                    local regions = {child.Icon:GetRegions()}
                    for _, region in ipairs(regions) do
                        if region:GetObjectType() == "Texture" then
                            iconTexture = region:GetTexture()
                            if iconTexture then break end
                        end
                    end
                end
            -- For tracked buffs, get icon from Icon
            elseif child.Icon then
                if child.Icon.GetTexture then
                    iconTexture = child.Icon:GetTexture()
                elseif child.Icon.Texture then
                    iconTexture = child.Icon.Texture:GetTexture()
                else
                    -- Look for texture children
                    local regions = {child.Icon:GetRegions()}
                    for _, region in ipairs(regions) do
                        if region:GetObjectType() == "Texture" then
                            iconTexture = region:GetTexture()
                            if iconTexture then break end
                        end
                    end
                end
            end
            
            if iconTexture then
                local data = {
                    icon = iconTexture,
                    name = "",
                    remainingTime = 0,
                    charges = 1,
                    spellID = child.spellID, -- Store spellID for charge lookups (WoW 12.0)
                    layoutIndex = child.layoutIndex, -- Preserve Blizzard's user-configured order
                }
                
                -- Try to get name from various possible locations
                if child.Name and child.Name.GetText then
                    data.name = child.Name:GetText() or ""
                elseif child.Bar and child.Bar.Name and child.Bar.Name.GetText then
                    data.name = child.Bar.Name:GetText() or ""
                end
                
                -- For tracked bars, try to get spellID from multiple sources
                local spellID = nil
                if displayName == "cooldowns" then
                    spellID = child.spellID or (child.Bar and child.Bar.spellID)
                    
                    -- Store spellID in data for later use
                    if spellID then
                        data.spellID = spellID
                    end
                end
                
                -- Try to get duration data for bars (protect against secret values)
                local hasValidName = false
                if displayName == "cooldowns" and data.name then
                    local ok, result = pcall(function() return data.name ~= "" end)
                    if ok and result then
                        hasValidName = true
                    end
                end
                
                if hasValidName then
                    -- Try by spellID first if available
                    if spellID then
                        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
                        if auraData then
                            -- Check for secret values (12.0 API protection)
                            if type(auraData.duration) == "number" then
                                data.duration = auraData.duration
                            end
                            if type(auraData.expirationTime) == "number" then
                                if auraData.expirationTime == 0 then
                                    -- Permanent aura (e.g., Paladin Auras)
                                    data.remainingTime = data.duration or 1
                                elseif auraData.expirationTime > 0 then
                                    data.remainingTime = math.max(0, auraData.expirationTime - GetTime())
                                end
                            end
                        end
                    end
                    
                    -- If no spellID or no data, scan all auras by name
                    if not data.duration then
                        for i = 1, 40 do
                            local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
                            if not auraData then break end
                            -- Safely compare names (both could be secret values)
                            local namesMatch = false
                            if auraData.name and data.name then
                                local ok, result = pcall(function() return auraData.name == data.name end)
                                if ok then namesMatch = result end
                            end
                            if namesMatch then
                                -- Check for secret values
                                if type(auraData.duration) == "number" then
                                    data.duration = auraData.duration
                                end
                                if type(auraData.expirationTime) == "number" then
                                    if auraData.expirationTime == 0 then
                                        -- Permanent aura
                                        data.remainingTime = data.duration or 1
                                    elseif auraData.expirationTime > 0 then
                                        data.remainingTime = math.max(0, auraData.expirationTime - GetTime())
                                    end
                                end
                                break
                            end
                        end
                    end
                end
                
                -- Try to get cooldown info (for non-bar displays)
                if displayName ~= "cooldowns" and child.Cooldown then
                    local start, duration = child.Cooldown:GetCooldownTimes()
                    if displayName == "cooldowns" then
                        print("  Found child.Cooldown - start:", start, "duration:", duration)
                    end
                    if start and duration then
                        -- Safely check duration using pcall to avoid taint
                        local ok, isValid = pcall(function() return duration > 0 end)
                        if ok and isValid then
                            local ok2, remaining = pcall(function() 
                                return (start + duration - GetTime() * 1000) / 1000 
                            end)
                            if ok2 and remaining then
                                data.remainingTime = remaining
                                -- Convert duration from milliseconds to seconds
                                data.duration = duration / 1000
                            end
                        end
                    end
                elseif displayName == "cooldowns" and child.Bar then
                    -- Try to get cooldown from Bar element
                    if child.Bar.Cooldown then
                        local start, duration = child.Bar.Cooldown:GetCooldownTimes()
                        if start and duration then
                            local ok, isValid = pcall(function() return duration > 0 end)
                            if ok and isValid then
                                local ok2, remaining = pcall(function() 
                                    return (start + duration - GetTime() * 1000) / 1000 
                                end)
                                if ok2 and remaining then
                                    data.remainingTime = remaining
                                    data.duration = duration / 1000
                                end
                            end
                        end
                    end
                end
                
                -- Try to get charges/stacks - Applications could be Frame or FontString
                if child.Applications then
                    local count = nil
                    if child.Applications.GetText then
                        count = child.Applications:GetText()
                    elseif child.Applications.GetChildren then
                        -- Applications is a Frame, look for FontString inside
                        local regions = {child.Applications:GetRegions()}
                        for _, region in ipairs(regions) do
                            if region:GetObjectType() == "FontString" then
                                count = region:GetText()
                                break
                            end
                        end
                    end
                    if count and tonumber(count) then
                        data.charges = tonumber(count)
                    end
                end
                
                -- For essential and utility cooldowns, get charges from spell charges API (WoW 12.0)
                if displayName == "essential" or displayName == "utility" then
                    -- Try multiple methods to find spellID from the child frame
                    local spellID = child.spellID
                    
                    -- Try alternate spellID locations
                    if not spellID and child.spell then
                        spellID = child.spell
                    end
                    if not spellID and child.Spell then
                        spellID = child.Spell
                    end
                    if not spellID and child.GetSpellID then
                        spellID = child:GetSpellID()
                    end
                    
                    -- Try to get spell name and lookup spellID (protect against secret values)
                    if not spellID and data.name then
                        local hasName = false
                        local ok, result = pcall(function() return data.name ~= "" end)
                        if ok and result then
                            hasName = true
                        end
                        
                        if hasName then
                            -- Try to find the spell ID from the spell name
                            local ok2, spellInfo = pcall(function() return C_Spell.GetSpellInfo(data.name) end)
                            if ok2 and spellInfo and spellInfo.spellID then
                                spellID = spellInfo.spellID
                            end
                        end
                    end
                    
                    if spellID then
                        data.spellID = spellID -- Store for later use
                        local chargeInfo = C_Spell.GetSpellCharges(spellID)
                        if chargeInfo then
                            -- Store charge values even if they're secret (WoW 12.0 pass-through)
                            -- FontString can render secret values even though we can't read them
                            -- Use rawget to check existence, not truthiness (secrets might be falsy)
                            if chargeInfo.currentCharges ~= nil then
                                -- Use Applications charge count if available, otherwise use API
                                if not data.charges or data.charges == 1 then
                                    data.charges = chargeInfo.currentCharges -- Store even if secret
                                end
                            end
                            if chargeInfo.maxCharges ~= nil then
                                data.maxCharges = chargeInfo.maxCharges -- Store even if secret
                            end
                        end
                    end
                end
                
                table.insert(cooldowns, data)
            end
        end
    end
    
    -- Sort cooldowns by layoutIndex to preserve Blizzard's user-configured order
    -- This respects the order users set in Blizzard's Cooldown Manager settings
    if displayName == "essential" or displayName == "utility" then
        table.sort(cooldowns, function(a, b)
            -- Sort by layoutIndex if both have it (Blizzard's intended order)
            if a.layoutIndex and b.layoutIndex then
                return a.layoutIndex < b.layoutIndex
            end
            -- If only one has layoutIndex, prioritize it
            if a.layoutIndex then return true end
            if b.layoutIndex then return false end
            -- Fallback to spellID for consistency
            if a.spellID and b.spellID then
                return a.spellID < b.spellID
            end
            -- Final fallback to icon texture ID
            return (a.icon or 0) < (b.icon or 0)
        end)
    end
    
    return cooldowns
end

function Cooldowns:SetupMoveMode(displayName, displayTitle, dbKey)
    local frame = self.customFrames[displayName]
    if not frame then return end
    
    -- Use dbKey if provided, otherwise use displayName
    local frameDB = self.db.profile[dbKey or displayName]
    if not frameDB then return end
    
    -- Get the Movable module
    local Movable = MidnightUI:GetModule("Movable")
    if not Movable then return end
    
    -- Clean up any existing highlight frame
    if frame.movableHighlightFrame then
        frame.movableHighlightFrame:Hide()
        frame.movableHighlightFrame:SetParent(nil)
        frame.movableHighlightFrame = nil
    end
    
    -- Create a dedicated child frame above all content
    frame.movableHighlightFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame.movableHighlightFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame.movableHighlightFrame:SetFrameLevel(10000)
    frame.movableHighlightFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.movableHighlightFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    
    -- Keep highlight frame in sync with frame position/size
    frame:HookScript("OnHide", function()
        if frame.movableHighlightFrame then
            frame.movableHighlightFrame:Hide()
        end
    end)
    frame:HookScript("OnShow", function()
        if frame.movableHighlightFrame and MidnightUI.moveMode then
            frame.movableHighlightFrame:Show()
        end
    end)
    frame:HookScript("OnSizeChanged", function()
        if frame.movableHighlightFrame then
            frame.movableHighlightFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            frame.movableHighlightFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        end
    end)
    
    -- Green highlight (hidden by default)
    frame.movableHighlightFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame.movableHighlightFrame:SetBackdropColor(0, 0.5, 0, 0.2)  -- Semi-transparent green
    frame.movableHighlightFrame:SetBackdropBorderColor(0, 1, 0, 1) -- Bright green border
    
    -- Add a centered label with the frame name
    frame.movableHighlightLabel = frame.movableHighlightFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.movableHighlightLabel:SetPoint("CENTER")
    frame.movableHighlightLabel:SetText(displayTitle)
    frame.movableHighlightLabel:SetTextColor(1, 1, 1, 1)
    frame.movableHighlightLabel:SetShadowOffset(2, -2)
    frame.movableHighlightLabel:SetShadowColor(0, 0, 0, 1)
    frame.movableHighlightFrame:Hide() -- Hide by default
    
    -- Store original SetAlpha and create custom one for move mode fading
    if not frame.originalSetAlpha then
        frame.originalSetAlpha = frame.SetAlpha
    end
    frame.SetAlpha = function(self, alpha)
        -- Call original SetAlpha if it exists
        if self.originalSetAlpha then
            self.originalSetAlpha(self, alpha)
        end
        -- Also fade all icons/bars
        for _, icon in pairs(self.icons or {}) do
            if icon:IsShown() then
                icon:SetAlpha(alpha)
            end
        end
        for _, bar in pairs(self.bars or {}) do
            if bar:IsShown() then
                bar:SetAlpha(alpha)
            end
        end
    end
    
    -- Enable the actual frame to be movable
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    
    -- Make the highlight frame draggable
    frame.movableHighlightFrame:SetMovable(true)
    frame.movableHighlightFrame:EnableMouse(true)
    frame.movableHighlightFrame:RegisterForDrag("LeftButton")
    frame.movableHighlightFrame:SetClampedToScreen(true)
    
    local isDragging = false
    frame.movableHighlightFrame:SetScript("OnDragStart", function(self)
        if MidnightUI.moveMode then
            isDragging = true
            frame:StartMoving()
        end
    end)
    
    frame.movableHighlightFrame:SetScript("OnDragStop", function(self)
        if not isDragging then return end
        frame:StopMovingOrSizing()
        isDragging = false
        
        -- Save position
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        -- Store in custom position table if it doesn't exist
        if not frameDB.position then
            frameDB.position = {}
        end
        frameDB.position.point = point or "CENTER"
        frameDB.position.relativePoint = relativePoint or "CENTER"
        frameDB.position.x = xOfs or 0
        frameDB.position.y = yOfs or 0
    end)
    
    -- Store reference to highlight frame on parent frame for Movable module
    frame.movableHighlight = frame.movableHighlightFrame
    frame.movableHighlightFrame.parentFrame = frame
    
    -- Register the frame (not the highlight) with Movable
    table.insert(Movable.registeredFrames, frame)
    
    -- Add nudge arrows
    Movable:CreateNudgeArrows(frame, frameDB.position or {}, function()
        -- Reset callback: center the frame
        if not frameDB.position then
            frameDB.position = {}
        end
        frameDB.position.point = "CENTER"
        frameDB.position.relativePoint = "CENTER"
        frameDB.position.x = 0
        frameDB.position.y = 0
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end)
end

function Cooldowns:CreateCustomDisplays()
    local db = self.db.profile
    
    -- Create Essential Cooldowns (icons)
    if not self.customFrames.essential then
        local f = CreateFrame("Frame", "MidnightEssentialCooldowns", UIParent)
        
        -- Load saved position or use default
        local pos = db.essential.position
        if pos and pos.point then
            f:SetPoint(pos.point, UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
        else
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
        end
        
        f:SetSize(400, 60)
        f:SetFrameStrata("MEDIUM")
        f:EnableMouse(true)
        
        -- No container background - icons will have their own backgrounds
        
        f.icons = {}
        f.activeIcons = {}
        f.displayType = "essential"
        f:Show()
        self.customFrames.essential = f
    end
    
    -- Create Utility Cooldowns (icons)
    if not self.customFrames.utility then
        local f = CreateFrame("Frame", "MidnightUtilityCooldowns", UIParent)
        
        -- Load saved position or use default
        local pos = db.utility.position
        if pos and pos.point then
            f:SetPoint(pos.point, UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
        else
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
        end
        
        f:SetSize(400, 60)
        f:SetFrameStrata("MEDIUM")
        f:EnableMouse(true)
        
        f.icons = {}
        f.activeIcons = {}
        f.displayType = "utility"
        f:Show()
        self.customFrames.utility = f
    end
    
    -- Create Tracked Buffs (icons)
    if not self.customFrames.buffs then
        local f = CreateFrame("Frame", "MidnightTrackedBuffs", UIParent)
        
        -- Load saved position or use default
        local pos = db.buffs.position
        if pos and pos.point then
            f:SetPoint(pos.point, UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
        else
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        
        f:SetSize(400, 44)
        f:SetFrameStrata("MEDIUM")
        f:EnableMouse(true)
        
        f.icons = {}
        f.activeIcons = {}
        f.displayType = "buffs"
        f:Show()
        self.customFrames.buffs = f
    end
    
    -- Create Tracked Bars (buff bars)
    if not self.customFrames.cooldowns then
        local f = CreateFrame("Frame", "MidnightTrackedBars", UIParent)
        
        -- Load saved position or use default
        local pos = db.customBuffBars.position
        if pos and pos.point then
            f:SetPoint(pos.point, UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
        else
            f:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
        end
        
        -- Use bar width + padding for frame width, or minimum 400 for visibility in move mode
        local buffDB = db.customBuffBars
        local frameWidth = math.max(buffDB.barWidth + 4, 400)
        f:SetSize(frameWidth, 90)
        f:SetFrameStrata("MEDIUM")
        f:EnableMouse(true)
        
        f.bars = {}
        f.activeBars = {}
        f.displayType = "cooldowns"
        
        -- Create the bar frames
        local buffDB = db.customBuffBars
        for i = 1, buffDB.maxBars do
            f.bars[i] = self:CreateBar(f, i)
        end
        
        f:Show()
        self.customFrames.cooldowns = f
    end
    
    -- Setup move mode for all displays
    self:SetupMoveMode("essential", "Essential Cooldowns")
    self:SetupMoveMode("utility", "Utility Cooldowns")
    self:SetupMoveMode("buffs", "Tracked Buffs")
    self:SetupMoveMode("cooldowns", "Tracked Bars", "customBuffBars")
end

function Cooldowns:CreateIconDisplay(name, displayType)
    local db = self.db.profile
    
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(300, 40) -- Will auto-resize based on icons
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(10)
    frame:SetScale(db.scale)
    frame.displayType = displayType
    
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(unpack(db.backgroundColor))
    frame.bg:SetShown(db.showBackground)
    
    -- Borders
    local borderSize = 2
    local r, g, b, a = unpack(db.borderColor)
    
    frame.borderTop = frame:CreateTexture(nil, "OVERLAY")
    frame.borderTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.borderTop:SetColorTexture(r, g, b, a)
    frame.borderTop:SetPoint("TOPLEFT", 0, 0)
    frame.borderTop:SetPoint("TOPRIGHT", 0, 0)
    frame.borderTop:SetHeight(borderSize)
    frame.borderTop:SetShown(db.showFrameBorder)
    
    frame.borderBottom = frame:CreateTexture(nil, "OVERLAY")
    frame.borderBottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.borderBottom:SetColorTexture(r, g, b, a)
    frame.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    frame.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.borderBottom:SetHeight(borderSize)
    frame.borderBottom:SetShown(db.showFrameBorder)
    
    frame.borderLeft = frame:CreateTexture(nil, "OVERLAY")
    frame.borderLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.borderLeft:SetColorTexture(r, g, b, a)
    frame.borderLeft:SetPoint("TOPLEFT", 0, 0)
    frame.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    frame.borderLeft:SetWidth(borderSize)
    frame.borderLeft:SetShown(db.showFrameBorder)
    
    frame.borderRight = frame:CreateTexture(nil, "OVERLAY")
    frame.borderRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.borderRight:SetColorTexture(r, g, b, a)
    frame.borderRight:SetPoint("TOPRIGHT", 0, 0)
    frame.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.borderRight:SetWidth(borderSize)
    frame.borderRight:SetShown(db.showFrameBorder)
    
    -- Icon pool
    frame.icons = {}
    frame.activeIcons = {}
    
    return frame
end

function Cooldowns:CreateBarDisplay(name, displayType)
    local db = self.db.profile
    local buffDB = db.customBuffBars
    
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(buffDB.barWidth, buffDB.barHeight * buffDB.maxBars + 2 * (buffDB.maxBars - 1))
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(10)
    frame:SetScale(db.scale)
    frame.displayType = displayType
    
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(unpack(db.backgroundColor))
    frame.bg:SetShown(db.showBackground)
    
    -- Borders
    local borderSize = 2
    local r, g, b, a = unpack(db.borderColor)
    
    frame.borderTop = frame:CreateTexture(nil, "OVERLAY")
    frame.borderTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.borderTop:SetColorTexture(r, g, b, a)
    frame.borderTop:SetPoint("TOPLEFT", 0, 0)
    frame.borderTop:SetPoint("TOPRIGHT", 0, 0)
    frame.borderTop:SetHeight(borderSize)
    frame.borderTop:SetShown(db.showFrameBorder)
    
    frame.borderBottom = frame:CreateTexture(nil, "OVERLAY")
    frame.borderBottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.borderBottom:SetColorTexture(r, g, b, a)
    frame.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    frame.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.borderBottom:SetHeight(borderSize)
    frame.borderBottom:SetShown(db.showFrameBorder)
    
    frame.borderLeft = frame:CreateTexture(nil, "OVERLAY")
    frame.borderLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.borderLeft:SetColorTexture(r, g, b, a)
    frame.borderLeft:SetPoint("TOPLEFT", 0, 0)
    frame.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    frame.borderLeft:SetWidth(borderSize)
    frame.borderLeft:SetShown(db.showFrameBorder)
    
    frame.borderRight = frame:CreateTexture(nil, "OVERLAY")
    frame.borderRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.borderRight:SetColorTexture(r, g, b, a)
    frame.borderRight:SetPoint("TOPRIGHT", 0, 0)
    frame.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.borderRight:SetWidth(borderSize)
    frame.borderRight:SetShown(db.showFrameBorder)
    
    -- Bar pool
    frame.bars = {}
    for i = 1, buffDB.maxBars do
        frame.bars[i] = self:CreateBar(frame, i)
    end
    
    return frame
end

function Cooldowns:CreateIcon(parent, displayType)
    local db = self.db.profile[displayType] or self.db.profile.essential
    
    local icon = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    icon:SetSize(db.iconWidth, db.iconHeight)
    
    -- Background
    icon:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = db.borderThickness,
    })
    icon:SetBackdropColor(0, 0, 0, 0.8)
    icon:SetBackdropBorderColor(db.borderColor[1], db.borderColor[2], db.borderColor[3], db.borderColor[4])
    
    -- Icon texture
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetPoint("TOPLEFT", db.borderThickness, -db.borderThickness)
    icon.texture:SetPoint("BOTTOMRIGHT", -db.borderThickness, db.borderThickness)
    icon.texture:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Crop rounded corners
    
    -- Cooldown text
    local fontPath = LSM:Fetch("font", db.font or self.db.profile.font)
    local fontFlag = db.fontFlag or self.db.profile.fontFlag or "OUTLINE"
    local fontSize = db.fontSize or self.db.profile.fontSize or 14
    
    icon.cooldownText = icon:CreateFontString(nil, "OVERLAY")
    icon.cooldownText:SetFont(fontPath, fontSize, fontFlag)
    icon.cooldownText:SetPoint("CENTER")
    icon.cooldownText:SetTextColor(1, 1, 1)
    
    -- Stack count
    icon.stackText = icon:CreateFontString(nil, "OVERLAY")
    icon.stackText:SetFont(fontPath, fontSize + 2, fontFlag)
    icon.stackText:SetPoint("BOTTOMRIGHT", -2, 2)
    icon.stackText:SetTextColor(1, 1, 1)
    
    -- Add overlay glow support for Blizzard proc events (WoW 12.0)
    -- Use ActionButton_ShowOverlayGlow API for proper glow effects
    icon.ShowOverlayGlow = function(self)
        -- Use Blizzard's action button glow API
        if ActionButton_ShowOverlayGlow then
            ActionButton_ShowOverlayGlow(self)
        end
    end
    
    icon.HideOverlayGlow = function(self)
        -- Use Blizzard's action button glow API
        if ActionButton_HideOverlayGlow then
            ActionButton_HideOverlayGlow(self)
        end
    end
    
    icon:Hide()
    return icon
end

function Cooldowns:CreateBar(parent, index)
    local db = self.db.profile.customBuffBars
    
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(db.barWidth - 4, db.barHeight)
    -- Center bars horizontally within parent frame
    local yOffset = -2 - (index - 1) * (db.barHeight + 2)
    bar:SetPoint("TOP", parent, "TOP", 0, yOffset)
    -- Use solid color texture instead of Blizzard texture
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:GetStatusBarTexture():SetHorizTile(false)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:Hide()
    
    -- Create border using textures (1px)
    local borderSize = 1
    local br, bg, bb, ba = unpack(db.barBorderColor)
    
    bar.borderTop = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    bar.borderTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar.borderTop:SetColorTexture(br, bg, bb, ba)
    bar.borderTop:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.borderTop:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    bar.borderTop:SetHeight(borderSize)
    
    bar.borderBottom = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    bar.borderBottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar.borderBottom:SetColorTexture(br, bg, bb, ba)
    bar.borderBottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    bar.borderBottom:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    bar.borderBottom:SetHeight(borderSize)
    
    bar.borderLeft = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    bar.borderLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar.borderLeft:SetColorTexture(br, bg, bb, ba)
    bar.borderLeft:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.borderLeft:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    bar.borderLeft:SetWidth(borderSize)
    
    bar.borderRight = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    bar.borderRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar.borderRight:SetColorTexture(br, bg, bb, ba)
    bar.borderRight:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    bar.borderRight:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    bar.borderRight:SetWidth(borderSize)
    
    -- Background behind the status bar (darker color for empty portion)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    bar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar.bg:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    bar.bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
    bar.bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    
    -- Icon (if enabled)
    bar.icon = nil
    if db.showIcons then
        bar.icon = bar:CreateTexture(nil, "OVERLAY")
        bar.icon:SetSize(db.barHeight - 2, db.barHeight - 2)
        bar.icon:SetPoint("LEFT", bar, "LEFT", 2, 0)
        bar.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    end
    
    -- Name text (high sublevel to ensure visibility)
    local fontPath = LSM:Fetch("font", db.font)
    local fontFlag = db.fontFlag or "OUTLINE"
    bar.name = bar:CreateFontString(nil, "OVERLAY", nil, 7)
    bar.name:SetFont(fontPath, db.fontSize, fontFlag)
    if db.showIcons and bar.icon then
        bar.name:SetPoint("LEFT", bar.icon, "RIGHT", 4, 0)
    else
        bar.name:SetPoint("LEFT", bar, "LEFT", 4, 0)
    end
    bar.name:SetJustifyH("LEFT")
    bar.name:SetTextColor(1, 1, 1)
    
    -- Timer text (always create it, just hide if not needed)
    bar.timer = bar:CreateFontString(nil, "OVERLAY", nil, 7)
    bar.timer:SetFont(fontPath, db.fontSize, fontFlag)
    bar.timer:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.timer:SetJustifyH("RIGHT")
    bar.timer:SetTextColor(1, 1, 1)
    if not db.showTimers then
        bar.timer:Hide()
    end
    
    -- Stack count
    bar.stack = nil
    if db.showIcons and bar.icon then
        bar.stack = bar:CreateFontString(nil, "OVERLAY", nil, 7)
        bar.stack:SetFont(fontPath, db.fontSize + 2, fontFlag)
        bar.stack:SetPoint("LEFT", bar.icon, "BOTTOMLEFT", 0, 0)
        bar.stack:SetJustifyH("LEFT")
        bar.stack:SetTextColor(1, 1, 1)
        if not db.showStacks then
            bar.stack:Hide()
        end
    end
    
    return bar
end

function Cooldowns:UpdateAllDisplays()
    if not self.customFrames then return end
    
    -- Update each display type
    for displayType, frame in pairs(self.customFrames) do
        if frame and frame.displayType then
            if displayType == "cooldowns" then
                self:UpdateBarDisplay(frame)
            else
                self:UpdateIconDisplay(frame)
            end
        end
    end
end

function Cooldowns:UpdateIconDisplay(frame)
    if not frame then return end
    
    local cooldowns = self:GetCooldownData(frame.displayType)
    local db = self.db.profile[frame.displayType] or self.db.profile.essential
    
    -- Hide all icons first
    for _, icon in ipairs(frame.activeIcons) do
        icon:Hide()
    end
    wipe(frame.activeIcons)
    
    -- Calculate layout
    local iconSize = db.iconWidth
    local spacing = db.iconSpacing
    local iconsPerRow = db.iconsPerRow
    local numIcons = #cooldowns
    
    for i, cooldownData in ipairs(cooldowns) do
        -- Get or create icon
        local icon = frame.icons[i]
        if not icon then
            icon = self:CreateIcon(frame, frame.displayType)
            frame.icons[i] = icon
        end
        
        -- Position icon
        local row = math.floor((i - 1) / iconsPerRow)
        local col = (i - 1) % iconsPerRow
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2 + col * (iconSize + spacing), -2 - row * (iconSize + spacing))
        
        -- Set icon texture
        if cooldownData.icon then
            icon.texture:SetTexture(cooldownData.icon)
        end
        
        -- Store spellID on icon for future lookups
        icon.spellID = cooldownData.spellID
        
        -- Set cooldown text (protect against secret values)
        local hasRemainingTime = false
        local remainingTimeValue = 0
        if cooldownData.remainingTime then
            local ok, result = pcall(function() return cooldownData.remainingTime > 0 end)
            if ok and result then
                hasRemainingTime = true
                -- Safely get the value
                local ok2, value = pcall(function() return cooldownData.remainingTime end)
                if ok2 then
                    remainingTimeValue = value
                end
            end
        end
        
        if hasRemainingTime and remainingTimeValue > 0 then
            if remainingTimeValue > 60 then
                icon.cooldownText:SetFormattedText("%.1fm", remainingTimeValue / 60)
            else
                icon.cooldownText:SetFormattedText("%.0f", remainingTimeValue)
            end
        else
            icon.cooldownText:SetText("")
        end
        
        -- Handle charges (WoW 12.0 event-driven pass-through)
        -- Fetch fresh charge data on every update and pass directly to SetText
        if icon.spellID and (frame.displayType == "essential" or frame.displayType == "utility") then
            local chargeInfo = C_Spell.GetSpellCharges(icon.spellID)
            if chargeInfo and chargeInfo.currentCharges ~= nil then
                local current = chargeInfo.currentCharges
                
                -- Pass charge value to FontString (works for both normal and secret values)
                icon.stackText:SetText(current)
                icon.stackText:Show()
                
                -- Try to use curve for color (may fail if module is tainted)
                -- Taint comes from hooksecurefunc on NineSlice
                if self.chargeCurve then
                    local ok, color = pcall(function() return self.chargeCurve:Evaluate(current) end)
                    if ok and color then
                        local r, g, b, a = color:GetRGBA()
                        icon.stackText:SetTextColor(r, g, b, a)
                    else
                        -- Fallback to white if tainted or secret value not allowed
                        icon.stackText:SetTextColor(1, 1, 1)
                    end
                else
                    icon.stackText:SetTextColor(1, 1, 1)
                end
                
                icon.texture:SetDesaturated(false)
            else
                -- No charge system
                icon.stackText:Hide()
                icon.texture:SetDesaturated(false)
            end
        elseif cooldownData.charges ~= nil then
            -- Fallback to stored charge data (for buffs/other displays)
            local current = cooldownData.charges
            
            icon.stackText:SetText(current)
            icon.stackText:Show()
            
            -- Try curve-based color (with taint protection)
            if self.chargeCurve then
                local ok, color = pcall(function() return self.chargeCurve:Evaluate(current) end)
                if ok and color then
                    local r, g, b, a = color:GetRGBA()
                    icon.stackText:SetTextColor(r, g, b, a)
                else
                    icon.stackText:SetTextColor(1, 1, 1)
                end
            else
                icon.stackText:SetTextColor(1, 1, 1)
            end
            icon.texture:SetDesaturated(false)
        else
            -- No charge system - hide charge counter
            icon.stackText:Hide()
            icon.texture:SetDesaturated(false)
            icon.stackText:SetTextColor(1, 1, 1)
        end
        
        icon:Show()
        table.insert(frame.activeIcons, icon)
    end
    
    -- Resize frame to fit icons (keep minimum size)
    if numIcons > 0 then
        local rows = math.ceil(numIcons / iconsPerRow)
        local cols = math.min(numIcons, iconsPerRow)
        frame:SetSize(
            4 + cols * iconSize + (cols - 1) * spacing,
            4 + rows * iconSize + (rows - 1) * spacing
        )
    end
    -- Don't resize if no icons - keep original size for visibility
end

function Cooldowns:UpdateBarDisplay(frame)
    if not frame or not frame.bars then return end
    
    local cooldowns = self:GetCooldownData(frame.displayType)
    local db = self.db.profile.customBuffBars
    
    -- Update bars
    for i, bar in ipairs(frame.bars) do
        local data = cooldowns[i]
        
        -- Safely check if data has a valid name (protect against secret values)
        local hasValidData = false
        if data and data.name then
            local ok, result = pcall(function() return data.name ~= "" and data.name ~= nil end)
            if ok and result then
                hasValidData = true
            end
        end
        
        if hasValidData then
            bar:Show()
            
            -- Set bar color with optional class color or fading
            local r, g, b, a
            if db.useClassColor then
                -- Get class color
                local _, class = UnitClass("player")
                local classColor = RAID_CLASS_COLORS[class]
                if classColor then
                    r, g, b, a = classColor.r, classColor.g, classColor.b, 1
                else
                    r, g, b, a = unpack(db.barColor)
                end
            else
                r, g, b, a = unpack(db.barColor)
            end
            
            if db.fadeColor and data.remainingTime and data.duration and data.duration > 0 then
                -- Calculate fade factor (0 to 1) based on remaining time percentage
                local fadeFactor = data.remainingTime / data.duration
                -- Darken the color as time decreases
                r = r * fadeFactor
                g = g * fadeFactor
                b = b * fadeFactor
            end
            bar:SetStatusBarColor(r, g, b, a or 1)
            
            -- Set duration
            if data.remainingTime and data.remainingTime > 0 and data.duration and data.duration > 0 then
                bar:SetMinMaxValues(0, data.duration)
                bar:SetValue(data.remainingTime)
            else
                bar:SetMinMaxValues(0, 1)
                bar:SetValue(1)
            end
            
            -- Icon
            if bar.icon and data.icon then
                bar.icon:SetTexture(data.icon)
                bar.icon:Show()
            end
            
            -- Name (safely get name or use empty string)
            local nameText = ""
            if data.name then
                local ok, result = pcall(function() return data.name end)
                if ok and result then
                    nameText = result
                end
            end
            bar.name:SetText(nameText)
            
            -- Timer
            if bar.timer then
                if db.showTimers then
                    if data.remainingTime and data.remainingTime > 0 then
                        if data.remainingTime > 60 then
                            bar.timer:SetFormattedText("%.1fm", data.remainingTime / 60)
                        else
                            bar.timer:SetFormattedText("%.0f", data.remainingTime)
                        end
                        bar.timer:Show()
                    else
                        bar.timer:SetText("")
                    end
                else
                    bar.timer:Hide()
                end
            end
            
            -- Stacks
            if bar.stack then
                if data.charges and data.charges > 1 then
                    bar.stack:SetText(data.charges)
                    bar.stack:Show()
                else
                    bar.stack:Hide()
                end
            end
        else
            bar:Hide()
        end
    end
end

function Cooldowns:FindAndSkinCooldownManager()
    if not self.db.profile.skinCooldownManager then return end
    
    -- Hide all Blizzard cooldown viewer frames
    local blizzardFrames = {
        "EssentialCooldownViewer",
        "UtilityCooldownViewer", 
        "BuffIconCooldownViewer",
        "BuffBarCooldownViewer",
    }
    
    for _, frameName in ipairs(blizzardFrames) do
        local frame = _G[frameName]
        if frame then
            -- Make frame invisible but keep it functional so we can read data from it
            frame:SetAlpha(0)
            frame:EnableMouse(false)
            frame:SetFrameStrata("BACKGROUND")
            
            -- Move it off-screen
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, -10000)
        end
    end
    
    -- Create our custom displays
    self:CreateCustomDisplays()
    
    -- Register for updates using WoW 12.0 CDM events
    if not self.updateFrame then
        self.updateFrame = CreateFrame("Frame")
        
        -- Primary CDM events (12.0)
        pcall(function()
            self.updateFrame:RegisterEvent("COOLDOWN_MANAGER_UPDATE")         -- Spells added/removed/reordered
            self.updateFrame:RegisterEvent("COOLDOWN_MANAGER_DISPLAY_UPDATE") -- Layout changes (Edit Mode)
        end)
        
        -- Performance-heavy tracking (Essential/Utility)
        self.updateFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")   -- Standard cooldown updates
        self.updateFrame:RegisterEvent("SPELL_UPDATE_USABLE")     -- Proc highlights and usable status
        
        -- Inventory & Power
        self.updateFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED") -- Trinket CD changes
        self.updateFrame:RegisterEvent("UNIT_POWER_UPDATE")        -- Resource tracking
        
        -- Target & Aura Tracking (12.0 optimized)
        -- Use RegisterUnitEvent for performance - only player and target, not all nameplates
        pcall(function()
            self.updateFrame:RegisterUnitEvent("UNIT_AURA", "player", "target")
        end)
        self.updateFrame:RegisterEvent("PLAYER_TARGET_CHANGED")    -- Target debuff tracking
        
        self.updateFrame:SetScript("OnEvent", function(frame, event, ...)
            Cooldowns:UpdateAllDisplays()
        end)
        
        -- Fallback ticker for systems without CDM events (0.5s polling)
        self.updateTicker = C_Timer.NewTicker(0.5, function()
            Cooldowns:UpdateAllDisplays()
        end)
    end
    
    -- Initial update
    self:UpdateAllDisplays()
end

function Cooldowns:ApplyCooldownManagerSkin(frame)
    if not frame or self.styledFrames[frame] then return end
    
    local db = self.db.profile
    
    -- Apply scale
    if frame.SetScale then
        frame:SetScale(db.scale)
    end
    
    -- Strip Blizzard borders for BuffBar immediately
    local frameName = frame:GetName()
    if frameName == "BuffBarCooldownViewer" then
        self:StripBlizzardBorders(frame)
    end
    
    -- Aggressively remove Blizzard's default styling
    -- Remove backdrop
    if frame.SetBackdrop then
        frame:SetBackdrop(nil)
    end
    
    -- Hide Blizzard's default borders/backdrop for all frames
    if frame.NineSlice then
        frame.NineSlice:Hide()
        frame.NineSlice:SetAlpha(0)
        -- Hook to prevent it from showing again
        -- COMMENTED OUT: This hook causes taint which prevents curve evaluation with secret values
        -- if not frame.midnightNineSliceHooked then
        --     hooksecurefunc(frame.NineSlice, "Show", function()
        --         frame.NineSlice:Hide()
        --     end)
        --     frame.midnightNineSliceHooked = true
        -- end
    end
    
    -- Create a background frame that is parented to the viewer's parent
    -- This ensures it renders completely behind the viewer
    if not frame.midnightBgFrame then
        local parent = frame:GetParent() or UIParent
        
        frame.midnightBgFrame = CreateFrame("Frame", nil, parent)
        frame.midnightBgFrame:SetAllPoints(frame)
        frame.midnightBgFrame:SetFrameStrata("LOW")
        frame.midnightBgFrame:SetFrameLevel(frame:GetFrameLevel() - 1)
        
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
        frame.midnightBorderTop:SetDrawLayer("OVERLAY", 7)
        
        frame.midnightBorderBottom = frame.midnightBgFrame:CreateTexture(nil, "ARTWORK")
        frame.midnightBorderBottom:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.midnightBorderBottom:SetColorTexture(r, g, b, a)
        frame.midnightBorderBottom:SetPoint("BOTTOMLEFT", frame.midnightBgFrame, "BOTTOMLEFT", 0, 0)
        frame.midnightBorderBottom:SetPoint("BOTTOMRIGHT", frame.midnightBgFrame, "BOTTOMRIGHT", 0, 0)
        frame.midnightBorderBottom:SetHeight(borderSize)
        frame.midnightBorderBottom:SetDrawLayer("OVERLAY", 7)
        
        frame.midnightBorderLeft = frame.midnightBgFrame:CreateTexture(nil, "ARTWORK")
        frame.midnightBorderLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.midnightBorderLeft:SetColorTexture(r, g, b, a)
        frame.midnightBorderLeft:SetPoint("TOPLEFT", frame.midnightBgFrame, "TOPLEFT", 0, 0)
        frame.midnightBorderLeft:SetPoint("BOTTOMLEFT", frame.midnightBgFrame, "BOTTOMLEFT", 0, 0)
        frame.midnightBorderLeft:SetWidth(borderSize)
        frame.midnightBorderLeft:SetDrawLayer("OVERLAY", 7)
        
        frame.midnightBorderRight = frame.midnightBgFrame:CreateTexture(nil, "ARTWORK")
        frame.midnightBorderRight:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.midnightBorderRight:SetColorTexture(r, g, b, a)
        frame.midnightBorderRight:SetPoint("TOPRIGHT", frame.midnightBgFrame, "TOPRIGHT", 0, 0)
        frame.midnightBorderRight:SetPoint("BOTTOMRIGHT", frame.midnightBgFrame, "BOTTOMRIGHT", 0, 0)
        frame.midnightBorderRight:SetWidth(borderSize)
        frame.midnightBorderRight:SetDrawLayer("OVERLAY", 7)
        
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
    
    -- Limit how many icons we track to prevent unbounded table growth
    local MAX_TRACKED_ICONS = 200
    local iconCount = 0
    for _ in pairs(self.styledIcons) do
        iconCount = iconCount + 1
    end
    
    -- Clear old entries if we exceed limit
    if iconCount > MAX_TRACKED_ICONS then
        -- Keep only icons that still exist
        local newTable = {}
        for icon, _ in pairs(self.styledIcons) do
            if icon and icon:IsShown() then
                newTable[icon] = true
            end
        end
        self.styledIcons = newTable
    end
    
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
    
    -- Skip if already fully styled to prevent redundant work
    if self.styledIcons[icon] then return end
    
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
    end
    
    -- Style cooldown text if it exists (only once)
    if icon.cooldownText and not icon.cooldownText.midnightStyled then
        local fontPath = LSM:Fetch("font", db.font)
        if fontPath then
            icon.cooldownText:SetFont(fontPath, db.fontSize, db.fontFlag)
            icon.cooldownText.midnightStyled = true
        end
    end
    
    -- Style duration text if it exists (only once)
    if icon.durationText and not icon.durationText.midnightStyled then
        local fontPath = LSM:Fetch("font", db.font)
        if fontPath then
            icon.durationText:SetFont(fontPath, db.fontSize, db.fontFlag)
            icon.durationText.midnightStyled = true
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
        ResourceBars.db.profile.primary.width = essentialWidth
    end
    
    -- Match secondary bar width if enabled
    if db.matchSecondaryBarWidth and ResourceBars.secondaryBar then
        ResourceBars.secondaryBar:SetWidth(essentialWidth)
        ResourceBars.db.profile.secondary.width = essentialWidth
        
        -- Recreate segments to redistribute them across the new width
        if ResourceBars.secondaryBar.segments then
            for _, segment in ipairs(ResourceBars.secondaryBar.segments) do
                segment:Hide()
                segment:SetParent(nil)
            end
            wipe(ResourceBars.secondaryBar.segments)
        end
        ResourceBars:CreateSecondarySegments()
        ResourceBars:UpdateSecondaryResourceBar()
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
    
    -- Find the Essential Cooldown Viewer (this is our anchor)
    local essentialFrame = _G["EssentialCooldownViewer"]
    if not essentialFrame then return end
    
    -- Attach RESOURCE BAR to Essential Cooldowns (not the other way around!)
    ResourceBars.primaryBar:ClearAllPoints()
    
    if db.attachPosition == "BOTTOM" then
        -- Resource bar goes ABOVE Essential (Essential is below)
        ResourceBars.primaryBar:SetPoint("BOTTOM", essentialFrame, "TOP", db.attachOffsetX, -db.attachOffsetY)
    elseif db.attachPosition == "TOP" then
        -- Resource bar goes BELOW Essential (Essential is above)
        ResourceBars.primaryBar:SetPoint("TOP", essentialFrame, "BOTTOM", db.attachOffsetX, -db.attachOffsetY)
    elseif db.attachPosition == "LEFT" then
        -- Resource bar goes RIGHT of Essential (Essential is left)
        ResourceBars.primaryBar:SetPoint("LEFT", essentialFrame, "RIGHT", -db.attachOffsetX, db.attachOffsetY)
    elseif db.attachPosition == "RIGHT" then
        -- Resource bar goes LEFT of Essential (Essential is right)
        ResourceBars.primaryBar:SetPoint("RIGHT", essentialFrame, "LEFT", -db.attachOffsetX, db.attachOffsetY)
    end
    
    -- Update frame grouping if enabled
    self:UpdateFrameGrouping()
    
    -- Update resource bar widths if enabled
    self:UpdateResourceBarWidths()
end

-- -----------------------------------------------------------------------------
-- CUSTOM BUFF BAR TRACKER
-- -----------------------------------------------------------------------------
function Cooldowns:CreateCustomBuffBarFrame()
    if self.buffBarFrame then
        self:UpdateCustomBuffBars()
        return
    end
    
    local db = self.db.profile
    local buffDB = db.customBuffBars
    
    -- Create main container frame
    self.buffBarFrame = CreateFrame("Frame", "MidnightBuffBarViewer", UIParent)
    self.buffBarFrame:SetSize(buffDB.barWidth, buffDB.barHeight * buffDB.maxBars + buffDB.spacing * (buffDB.maxBars - 1))
    self.buffBarFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.buffBarFrame:SetFrameStrata("MEDIUM")
    self.buffBarFrame:SetScale(db.scale)
    
    -- Background
    local bg = self.buffBarFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(db.backgroundColor))
    self.buffBarFrame.bg = bg
    
    if db.showBackground then
        bg:Show()
    else
        bg:Hide()
    end
    
    -- Borders
    local borderSize = 2
    local r, g, b, a = unpack(db.borderColor)
    
    local borderTop = self.buffBarFrame:CreateTexture(nil, "OVERLAY")
    borderTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    borderTop:SetColorTexture(r, g, b, a)
    borderTop:SetPoint("TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", 0, 0)
    borderTop:SetHeight(borderSize)
    self.buffBarFrame.borderTop = borderTop
    
    local borderBottom = self.buffBarFrame:CreateTexture(nil, "OVERLAY")
    borderBottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    borderBottom:SetColorTexture(r, g, b, a)
    borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    borderBottom:SetHeight(borderSize)
    self.buffBarFrame.borderBottom = borderBottom
    
    local borderLeft = self.buffBarFrame:CreateTexture(nil, "OVERLAY")
    borderLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    borderLeft:SetColorTexture(r, g, b, a)
    borderLeft:SetPoint("TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    borderLeft:SetWidth(borderSize)
    self.buffBarFrame.borderLeft = borderLeft
    
    local borderRight = self.buffBarFrame:CreateTexture(nil, "OVERLAY")
    borderRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    borderRight:SetColorTexture(r, g, b, a)
    borderRight:SetPoint("TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    borderRight:SetWidth(borderSize)
    self.buffBarFrame.borderRight = borderRight
    
    if db.showFrameBorder then
        borderTop:Show()
        borderBottom:Show()
        borderLeft:Show()
        borderRight:Show()
    else
        borderTop:Hide()
        borderBottom:Hide()
        borderLeft:Hide()
        borderRight:Hide()
    end
    
    -- Create individual buff bars
    self.customBuffBars = {}
    for i = 1, buffDB.maxBars do
        local bar = self:CreateBuffBar(i)
        self.customBuffBars[i] = bar
    end
    
    -- Register events
    self:RegisterEvent("UNIT_AURA", "UpdateCustomBuffBars")
    
    -- Initial update
    self:UpdateCustomBuffBars()
end

function Cooldowns:CreateBuffBar(index)
    local db = self.db.profile.customBuffBars
    
    local bar = CreateFrame("StatusBar", nil, self.buffBarFrame)
    bar:SetSize(db.barWidth - 4, db.barHeight)
    bar:SetPoint("TOPLEFT", self.buffBarFrame, "TOPLEFT", 2, -2 - (index - 1) * (db.barHeight + db.spacing))
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:GetStatusBarTexture():SetHorizTile(false)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:Hide()
    
    -- Background
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetAllPoints()
    bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)
    bar.bg = bg
    
    -- Icon
    if db.showIcons then
        bar.icon = bar:CreateTexture(nil, "ARTWORK")
        bar.icon:SetSize(db.iconSize, db.iconSize)
        bar.icon:SetPoint("LEFT", bar, "LEFT", 2, 0)
        bar.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    end
    
    -- Name text
    bar.name = bar:CreateFontString(nil, "OVERLAY")
    local font, _, fontFlag = FontKit:GetFont(db.font, db.fontSize, db.fontFlag)
    bar.name:SetFont(font, db.fontSize, fontFlag)
    if db.showIcons then
        bar.name:SetPoint("LEFT", bar.icon, "RIGHT", 4, 0)
    else
        bar.name:SetPoint("LEFT", bar, "LEFT", 4, 0)
    end
    bar.name:SetJustifyH("LEFT")
    bar.name:SetTextColor(1, 1, 1)
    
    -- Timer text
    if db.showTimers then
        bar.timer = bar:CreateFontString(nil, "OVERLAY")
        bar.timer:SetFont(font, db.fontSize, fontFlag)
        bar.timer:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        bar.timer:SetJustifyH("RIGHT")
        bar.timer:SetTextColor(1, 1, 1)
    end
    
    -- Stack count
    if db.showStacks then
        bar.stack = bar:CreateFontString(nil, "OVERLAY")
        bar.stack:SetFont(font, db.fontSize + 2, fontFlag)
        bar.stack:SetPoint("LEFT", bar.icon, "BOTTOMLEFT", 0, 0)
        bar.stack:SetJustifyH("LEFT")
        bar.stack:SetTextColor(1, 1, 1)
    end
    
    return bar
end

function Cooldowns:UpdateCustomBuffBars()
    if not self.buffBarFrame or not self.db.profile.customBuffBars.enabled then return end
    
    local trackedAuras = {}
    
    -- Get tracked buffs from Blizzard's system
    if C_Auras and C_Auras.GetTrackedAuras then
        local auras = C_Auras.GetTrackedAuras("player")
        if auras then
            for _, auraInfo in ipairs(auras) do
                if auraInfo then
                    table.insert(trackedAuras, auraInfo)
                end
            end
        end
    end
    
    -- Update bars
    for i, bar in ipairs(self.customBuffBars) do
        local aura = trackedAuras[i]
        
        if aura and aura.name then
            bar:Show()
            
            -- Set bar color
            local r, g, b = 0.3, 0.7, 1.0
            if aura.dispelName then
                -- Color by dispel type if available
                r, g, b = 0.8, 0.5, 0.2
            end
            bar:SetStatusBarColor(r, g, b, 1)
            
            -- Set duration
            if aura.expirationTime and aura.expirationTime > 0 then
                local duration = aura.expirationTime - GetTime()
                local maxDuration = aura.duration or 1
                if maxDuration > 0 then
                    bar:SetMinMaxValues(0, maxDuration)
                    bar:SetValue(duration)
                end
            else
                bar:SetMinMaxValues(0, 1)
                bar:SetValue(1)
            end
            
            -- Icon
            if bar.icon and aura.icon then
                bar.icon:SetTexture(aura.icon)
                bar.icon:Show()
            end
            
            -- Name
            bar.name:SetText(aura.name)
            
            -- Timer
            if bar.timer then
                if aura.expirationTime and aura.expirationTime > 0 then
                    local duration = aura.expirationTime - GetTime()
                    if duration > 60 then
                        bar.timer:SetFormattedText("%.1fm", duration / 60)
                    else
                        bar.timer:SetFormattedText("%.0f", duration)
                    end
                else
                    bar.timer:SetText("")
                end
            end
            
            -- Stacks
            if bar.stack then
                if aura.applications and aura.applications > 1 then
                    bar.stack:SetText(aura.applications)
                    bar.stack:Show()
                else
                    bar.stack:Hide()
                end
            end
        else
            bar:Hide()
        end
    end
end

-- -----------------------------------------------------------------------------
-- OPTIONS
-- -----------------------------------------------------------------------------
-- -----------------------------------------------------------------------------
-- OPTIONS
-- -----------------------------------------------------------------------------

function Cooldowns:GetDisplayOptions(displayName, displayTitle, order)
    local db = function() return self.db.profile[displayName] end
    
    return {
        [displayName .. "Header"] = {
            type = "header",
            name = displayTitle,
            order = order,
        },
        [displayName .. "IconsPerRow"] = {
            name = "Icons Per Row",
            desc = "Number of icons to display per row.",
            type = "range",
            order = order + 1,
            min = 2, max = 12, step = 1,
            disabled = function() return not db().enabled end,
            get = function() return db().iconsPerRow end,
            set = function(_, v)
                db().iconsPerRow = v
                if self.customFrames[displayName] then
                    self:UpdateIconDisplay(self.customFrames[displayName])
                end
            end,
        },
        [displayName .. "IconWidth"] = {
            name = "Icon Width",
            desc = "Width of each cooldown icon. |cffFF6B6BRequires /reload|r",
            type = "range",
            order = order + 2,
            min = 20, max = 80, step = 1,
            disabled = function() return not db().enabled end,
            get = function() return db().iconWidth end,
            set = function(_, v)
                db().iconWidth = v
                print("|cffFFFF00MidnightUI:|r Icon width changed. Type |cff00FF00/reload|r to apply.")
            end,
        },
        [displayName .. "IconHeight"] = {
            name = "Icon Height",
            desc = "Height of each cooldown icon. |cffFF6B6BRequires /reload|r",
            type = "range",
            order = order + 3,
            min = 20, max = 80, step = 1,
            disabled = function() return not db().enabled end,
            get = function() return db().iconHeight end,
            set = function(_, v)
                db().iconHeight = v
                print("|cffFFFF00MidnightUI:|r Icon height changed. Type |cff00FF00/reload|r to apply.")
            end,
        },
        [displayName .. "IconSpacing"] = {
            name = "Icon Spacing",
            desc = "Space between cooldown icons.",
            type = "range",
            order = order + 4,
            min = 0, max = 10, step = 1,
            disabled = function() return not db().enabled end,
            get = function() return db().iconSpacing end,
            set = function(_, v)
                db().iconSpacing = v
                if self.customFrames[displayName] then
                    self:UpdateIconDisplay(self.customFrames[displayName])
                end
            end,
        },
        [displayName .. "BorderThickness"] = {
            name = "Border Thickness",
            desc = "Thickness of the border around each icon. |cffFF6B6BRequires /reload|r",
            type = "range",
            order = order + 5,
            min = 1, max = 5, step = 1,
            disabled = function() return not db().enabled end,
            get = function() return db().borderThickness end,
            set = function(_, v)
                db().borderThickness = v
                print("|cffFFFF00MidnightUI:|r Border thickness changed. Type |cff00FF00/reload|r to apply.")
            end,
        },
        [displayName .. "BorderColor"] = {
            name = "Border Color",
            desc = "Color of the border around each icon. ",
            type = "color",
            order = order + 6,
            hasAlpha = true,
            disabled = function() return not db().enabled end,
            get = function()
                local c = db().borderColor
                return c[1], c[2], c[3], c[4]
            end,
            set = function(_, r, g, b, a)
                db().borderColor = {r, g, b, a}
                
            end,
        },
        [displayName .. "AttachTo"] = {
            name = "Attach To",
            desc = "Which frame to attach this display to.",
            type = "select",
            order = order + 7,
            values = {
                ["none"] = "None (Independent)",
                ["essential"] = "Essential Cooldowns",
                ["utility"] = "Utility Cooldowns",
                ["buffs"] = "Tracked Buffs",
                ["bars"] = "Tracked Bars",
                ["primaryBar"] = "Primary Resource Bar",
                ["secondaryBar"] = "Secondary Resource Bar",
            },
            disabled = function() return not db().enabled end,
            get = function() return db().attachTo end,
            set = function(_, v)
                db().attachTo = v
                
            end,
        },
        [displayName .. "AttachPosition"] = {
            name = "Attach Position",
            desc = "Where to attach relative to the anchor frame.",
            type = "select",
            order = order + 8,
            values = {
                ["BOTTOM"] = "Below",
                ["TOP"] = "Above",
                ["LEFT"] = "Left",
                ["RIGHT"] = "Right",
            },
            disabled = function() return not db().enabled end,
            get = function() return db().attachPosition end,
            set = function(_, v)
                db().attachPosition = v
                
            end,
        },
        [displayName .. "OffsetX"] = {
            name = "Horizontal Offset",
            desc = "Horizontal offset from the anchor point.",
            type = "range",
            order = order + 9,
            min = -200, max = 200, step = 1,
            disabled = function() return not db().enabled end,
            get = function() return db().offsetX end,
            set = function(_, v)
                db().offsetX = v
                
            end,
        },
        [displayName .. "OffsetY"] = {
            name = "Vertical Offset",
            desc = "Vertical offset from the anchor point.",
            type = "range",
            order = order + 10,
            min = -200, max = 200, step = 1,
            disabled = function() return not db().enabled end,
            get = function() return db().offsetY end,
            set = function(_, v)
                db().offsetY = v
                
            end,
        },
    }
end

function Cooldowns:GetOptions()
    local options = {
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
                name = "Custom cooldown tracking displays for Essential Cooldowns, Utility Cooldowns, Tracked Buffs, and Tracked Bars.\n\n" ..
                      "|cffFFFF00Note:|r All displays are movable and fully customizable.",
                order = 2
            },
            
            -- Settings
            headerFrame = { type = "header", name = "Settings", order = 20 },
            
            scale = {
                name = "Scale",
                desc = "Scale of all cooldown display frames.",
                type = "range",
                order = 21,
                min = 0.5, max = 2.0, step = 0.05,
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
            
            font = {
                name = "Font",
                desc = "Font for cooldown text.",
                type = "select",
                order = 22,
                values = function()
                    local fonts = LSM:List("font")
                    local out = {}
                    for _, font in ipairs(fonts) do out[font] = font end
                    return out
                end,
                get = function() return self.db.profile.font or "Friz Quadrata TT" end,
                set = function(_, v)
                    self.db.profile.font = v
                end
            },
            
            fontSize = {
                name = "Font Size",
                desc = "Size of cooldown text.",
                type = "range",
                order = 23,
                min = 8, max = 32, step = 1,
                get = function() return self.db.profile.fontSize end,
                set = function(_, v)
                    self.db.profile.fontSize = v
                end
            },
            
            fontFlag = {
                name = "Font Outline",
                desc = "Outline style for cooldown text.",
                type = "select",
                order = 24,
                values = {
                    ["NONE"] = "None",
                    ["OUTLINE"] = "Outline",
                    ["THICKOUTLINE"] = "Thick Outline",
                    ["MONOCHROME"] = "Monochrome"
                },
                get = function() return self.db.profile.fontFlag end,
                set = function(_, v)
                    self.db.profile.fontFlag = v
                end
            },
            
            -- Tracked Bars Display
            headerCustomBuffBars = { type = "header", name = "Tracked Bars Display", order = 90 },
            
            customBuffBarsDesc = {
                type = "description",
                name = "Tracked bars show active buffs/debuffs with progress bars indicating remaining duration.",
                order = 90.2,
            },
            
            customBuffBarsMaxBars = {
                name = "Max Bars",
                desc = "Maximum number of buff bars to display. |cffFF6B6BRequires /reload|r",
                type = "range",
                order = 90.3,
                min = 1, max = 15, step = 1,
                get = function() return self.db.profile.customBuffBars.maxBars end,
                set = function(_, v)
                    self.db.profile.customBuffBars.maxBars = v
                    print("|cffFFFF00MidnightUI:|r Max bars changed. Type |cff00FF00/reload|r to apply.")
                end
            },
            
            customBuffBarsHeight = {
                name = "Bar Height",
                desc = "Height of each buff bar. |cffFF6B6BRequires /reload|r",
                type = "range",
                order = 90.4,
                min = 12, max = 40, step = 1,
                get = function() return self.db.profile.customBuffBars.barHeight end,
                set = function(_, v)
                    self.db.profile.customBuffBars.barHeight = v
                    print("|cffFFFF00MidnightUI:|r Bar height changed. Type |cff00FF00/reload|r to apply.")
                end
            },
            
            customBuffBarsWidth = {
                name = "Bar Width",
                desc = "Width of each buff bar. |cffFF6B6BRequires /reload|r",
                type = "range",
                order = 90.5,
                min = 100, max = 500, step = 10,
                get = function() return self.db.profile.customBuffBars.barWidth end,
                set = function(_, v)
                    self.db.profile.customBuffBars.barWidth = v
                    print("|cffFFFF00MidnightUI:|r Bar width changed. Type |cff00FF00/reload|r to apply.")
                end
            },
            
            customBuffBarsShowIcons = {
                name = "Show Icons",
                desc = "Display buff icons on the left side of each bar.",
                type = "toggle",
                order = 90.6,
                get = function() return self.db.profile.customBuffBars.showIcons end,
                set = function(_, v)
                    self.db.profile.customBuffBars.showIcons = v
                    
                end
            },
            
            customBuffBarsShowTimers = {
                name = "Show Timers",
                desc = "Display remaining duration on the right side of each bar.",
                type = "toggle",
                order = 90.7,
                get = function() return self.db.profile.customBuffBars.showTimers end,
                set = function(_, v)
                    self.db.profile.customBuffBars.showTimers = v
                    
                end
            },
            
            customBuffBarsShowStacks = {
                name = "Show Stack Count",
                desc = "Display the stack count for stackable buffs.",
                type = "toggle",
                order = 90.8,
                get = function() return self.db.profile.customBuffBars.showStacks end,
                set = function(_, v)
                    self.db.profile.customBuffBars.showStacks = v
                    
                end
            },
            
            customBuffBarsBarColor = {
                name = "Bar Color",
                desc = "Color of the tracked bar fill.",
                type = "color",
                order = 90.9,
                hasAlpha = true,
                disabled = function() return self.db.profile.customBuffBars.useClassColor end,
                get = function()
                    local c = self.db.profile.customBuffBars.barColor
                    return c[1], c[2], c[3], c[4]
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.customBuffBars.barColor = {r, g, b, a}
                    self:UpdateAllDisplays()
                end
            },
            
            customBuffBarsBarBorderColor = {
                name = "Bar Border Color",
                desc = "Color of the border around each tracked bar.",
                type = "color",
                order = 90.91,
                hasAlpha = true,
                get = function()
                    local c = self.db.profile.customBuffBars.barBorderColor
                    return c[1], c[2], c[3], c[4]
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.customBuffBars.barBorderColor = {r, g, b, a}
                    -- Update existing bar borders
                    if self.customFrames.cooldowns and self.customFrames.cooldowns.bars then
                        for _, bar in ipairs(self.customFrames.cooldowns.bars) do
                            if bar.borderTop then
                                bar.borderTop:SetColorTexture(r, g, b, a)
                                bar.borderBottom:SetColorTexture(r, g, b, a)
                                bar.borderLeft:SetColorTexture(r, g, b, a)
                                bar.borderRight:SetColorTexture(r, g, b, a)
                            end
                        end
                    end
                end
            },
            
            customBuffBarsUseClassColor = {
                name = "Use Class Color",
                desc = "Use your class color for the tracked bars instead of the custom color.",
                type = "toggle",
                order = 90.95,
                get = function() return self.db.profile.customBuffBars.useClassColor end,
                set = function(_, v)
                    self.db.profile.customBuffBars.useClassColor = v
                    self:UpdateAllDisplays()
                end
            },
            
            customBuffBarsFadeColor = {
                name = "Fade Color Over Time",
                desc = "Darken the bar color as the timer decreases, similar to Blizzard's tracked bars.",
                type = "toggle",
                order = 91.0,
                get = function() return self.db.profile.customBuffBars.fadeColor end,
                set = function(_, v)
                    self.db.profile.customBuffBars.fadeColor = v
                    self:UpdateAllDisplays()
                end
            },
            
            -- Resource Bar Attachment
            headerAttachment = { type = "header", name = "Resource Bar Attachment", order = 110 },
            
            attachPosition = {
                name = "Attach Position",
                desc = "Where to attach the Cooldown Manager relative to the resource bar.",
                type = "select",
                order = 112,
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
                order = 113,
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
                order = 114,
                min = -200, max = 200, step = 1,
                disabled = function() return not self.db.profile.attachToResourceBar or not self.db.profile.skinCooldownManager end,
                get = function() return self.db.profile.attachOffsetY end,
                set = function(_, v)
                    self.db.profile.attachOffsetY = v
                    self:UpdateAttachment()
                end
            },
            
            -- Resource Bar Width Matching
            
            matchPrimaryBarWidth = {
                name = "Match Primary Bar Width",
                desc = "Make the Primary Resource Bar width match the Essential Cooldowns bar width.",
                type = "toggle",
                order = 131,
                width = "full",
                
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
                order = 132,
                width = "full",
                
                get = function() return self.db.profile.matchSecondaryBarWidth end,
                set = function(_, v)
                    self.db.profile.matchSecondaryBarWidth = v
                    self:UpdateResourceBarWidths()
                end
            },
        }
    }
    
    -- Add display-specific options
    local displayOptions = self:GetDisplayOptions("essential", "Essential Cooldowns Display", 30)
    for k, v in pairs(displayOptions) do
        options.args[k] = v
    end
    
    displayOptions = self:GetDisplayOptions("utility", "Utility Cooldowns Display", 50)
    for k, v in pairs(displayOptions) do
        options.args[k] = v
    end
    
    displayOptions = self:GetDisplayOptions("buffs", "Tracked Buffs Display", 70)
    for k, v in pairs(displayOptions) do
        options.args[k] = v
    end
    
    return options
end

