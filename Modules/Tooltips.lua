local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local Tooltips = MidnightUI:NewModule("Tooltips", "AceEvent-3.0", "AceHook-3.0")

-- ============================================================================
-- Module Initialization
-- ============================================================================

function Tooltips:OnInitialize()
    self.db = MidnightUI.db:RegisterNamespace("Tooltips", {
        profile = {
            enabled = true,
            borderSize = 2,
            backdropAlpha = 0.95,
            fontSize = 12,
            
            -- Cursor Following
            cursorFollow = false,
            cursorAnchor = "BOTTOMRIGHT",
            offsetX = 0,
            offsetY = 0,
            fadeDelay = 0.2,
            scale = 1.0,
            
            -- Player Information
            classColor = true,
            showGuild = true,
            yourGuildColor = {r = 0.25, g = 1.0, b = 0.25},
            otherGuildColor = {r = 0.67, g = 0.83, b = 0.45},
            showStatus = true,
            showItemLevel = true,
            showFaction = true,
            showMount = true,
            showRole = true,
            showMythicScore = true,
            showTargetOf = true,
        }
    })
    
    -- Store references to tooltip frames we'll be styling
    self.tooltips = {
        GameTooltip,
        ItemRefTooltip,
        ShoppingTooltip1,
        ShoppingTooltip2,
        FriendsTooltip,
        WorldMapTooltip,
        WorldMapCompareTooltip1,
        WorldMapCompareTooltip2,
    }
    
    -- Cache for player data
    self.playerCache = {}
end

function Tooltips:OnEnable()
    if not self.db.profile.enabled then return end
    
    -- Wait for theme system to be ready
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "Initialize")
end

function Tooltips:OnDisable()
    self:UnhookAll()
end

function Tooltips:Initialize()
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    
    if not ColorPalette or not FontKit then
        MidnightUI:Print("Tooltips module: ColorPalette or FontKit not available")
        return
    end
    
    self.ColorPalette = ColorPalette
    self.FontKit = FontKit
    
    -- Apply styling to all tooltip frames
    self:StyleTooltips()
    
    -- Hook for dynamic tooltips
    self:SecureHook("GameTooltip_SetDefaultAnchor")
    
    -- Hook tooltip show events for cursor following
    if self.db.profile.cursorFollow then
        self:EnableCursorFollow()
    end
    
    -- Hook unit tooltips for player information using modern API
    if TooltipDataProcessor then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            self:OnTooltipSetUnit(tooltip)
        end)
    else
        -- Fallback for older API - hook OnShow and check for unit
        GameTooltip:HookScript("OnShow", function(tooltip)
            local _, unit = tooltip:GetUnit()
            if unit then
                self:OnTooltipSetUnit(tooltip)
            end
        end)
    end
    
    -- Listen for inspect data
    self:RegisterEvent("INSPECT_READY")
    
    -- Listen for theme changes
    self:RegisterMessage("MIDNIGHTUI_THEME_CHANGED", "OnThemeChanged")
end

-- ============================================================================
-- Tooltip Styling
-- ============================================================================

function Tooltips:StyleTooltips()
    if not self.ColorPalette then return end
    
    for _, tooltip in ipairs(self.tooltips) do
        if tooltip then
            self:StyleTooltip(tooltip)
        end
    end
end

function Tooltips:StyleTooltip(tooltip)
    if not tooltip or not self.ColorPalette then return end
    
    local br, bg, bb, ba = self.ColorPalette:GetColor("panel-border")
    local bgr, bgg, bgb, bga = self.ColorPalette:GetColor("tooltip-bg")
    
    -- Apply backdrop alpha override if set
    if self.db.profile.backdropAlpha then
        bga = self.db.profile.backdropAlpha
    end
    
    -- Modern WoW uses NineSlice system for tooltips
    if tooltip.NineSlice then
        -- Style the NineSlice border textures
        local borderSize = self.db.profile.borderSize or 2
        
        -- Set border color
        if tooltip.NineSlice.TopEdge then
            tooltip.NineSlice.TopEdge:SetColorTexture(br, bg, bb, ba)
            tooltip.NineSlice.TopEdge:SetHeight(borderSize)
        end
        if tooltip.NineSlice.BottomEdge then
            tooltip.NineSlice.BottomEdge:SetColorTexture(br, bg, bb, ba)
            tooltip.NineSlice.BottomEdge:SetHeight(borderSize)
        end
        if tooltip.NineSlice.LeftEdge then
            tooltip.NineSlice.LeftEdge:SetColorTexture(br, bg, bb, ba)
            tooltip.NineSlice.LeftEdge:SetWidth(borderSize)
        end
        if tooltip.NineSlice.RightEdge then
            tooltip.NineSlice.RightEdge:SetColorTexture(br, bg, bb, ba)
            tooltip.NineSlice.RightEdge:SetWidth(borderSize)
        end
        
        -- Set corner colors
        if tooltip.NineSlice.TopLeftCorner then
            tooltip.NineSlice.TopLeftCorner:SetColorTexture(br, bg, bb, ba)
        end
        if tooltip.NineSlice.TopRightCorner then
            tooltip.NineSlice.TopRightCorner:SetColorTexture(br, bg, bb, ba)
        end
        if tooltip.NineSlice.BottomLeftCorner then
            tooltip.NineSlice.BottomLeftCorner:SetColorTexture(br, bg, bb, ba)
        end
        if tooltip.NineSlice.BottomRightCorner then
            tooltip.NineSlice.BottomRightCorner:SetColorTexture(br, bg, bb, ba)
        end
        
        -- Create or update background texture
        if not tooltip.MidnightBG then
            tooltip.MidnightBG = tooltip:CreateTexture(nil, "BACKGROUND")
            tooltip.MidnightBG:SetAllPoints(tooltip)
            tooltip.MidnightBG:SetDrawLayer("BACKGROUND", -8)
        end
        tooltip.MidnightBG:SetColorTexture(bgr, bgg, bgb, bga)
    end
    
    -- Hook to update font when tooltip shows
    if self.FontKit and not self:IsHooked(tooltip, "OnShow") then
        self:HookScript(tooltip, "OnShow", "OnTooltipShow")
    end
end

function Tooltips:OnTooltipShow(tooltip)
    if not self.FontKit or not tooltip then return end
    
    -- Apply font to tooltip text
    local font, size = self.FontKit:GetFont("body", "small")
    local fontSize = self.db.profile.fontSize or 12
    
    -- Update header font
    if tooltip.TextLeft1 then
        tooltip.TextLeft1:SetFont(font, fontSize + 2, "OUTLINE")
    end
    
    -- Update all other text lines
    for i = 2, tooltip:NumLines() do
        local leftText = _G[tooltip:GetName() .. "TextLeft" .. i]
        local rightText = _G[tooltip:GetName() .. "TextRight" .. i]
        
        if leftText then
            leftText:SetFont(font, fontSize, "")
        end
        if rightText then
            rightText:SetFont(font, fontSize, "")
        end
    end
end

function Tooltips:GameTooltip_SetDefaultAnchor(tooltip, parent)
    if not self.db.profile.enabled then return end
    
    -- Handle cursor following
    if self.db.profile.cursorFollow then
        tooltip:SetOwner(parent, "ANCHOR_CURSOR")
        tooltip:ClearAllPoints()
        
        local scale = self.db.profile.scale or 1.0
        tooltip:SetScale(scale)
        
        local x, y = GetCursorPosition()
        local uiScale = UIParent:GetEffectiveScale()
        x = x / uiScale
        y = y / uiScale
        
        local anchor = self.db.profile.cursorAnchor or "BOTTOMRIGHT"
        local offsetX = self.db.profile.offsetX or 0
        local offsetY = self.db.profile.offsetY or 0
        
        tooltip:SetPoint(anchor, UIParent, "BOTTOMLEFT", x + offsetX, y + offsetY)
        
        -- Set fade delay
        if tooltip.FadeOut then
            tooltip.FadeOut:SetStartDelay(self.db.profile.fadeDelay or 0.2)
        end
    else
        -- Apply scale even when not cursor following
        local scale = self.db.profile.scale or 1.0
        tooltip:SetScale(scale)
    end
    
    -- Reapply styling when tooltip anchor is set
    self:StyleTooltip(tooltip)
end

function Tooltips:OnThemeChanged()
    -- Reapply styling when theme changes
    self:StyleTooltips()
end

-- ============================================================================
-- Cursor Following
-- ============================================================================

function Tooltips:EnableCursorFollow()
    for _, tooltip in ipairs(self.tooltips) do
        if tooltip and not self:IsHooked(tooltip, "OnUpdate") then
            self:HookScript(tooltip, "OnUpdate", "OnTooltipUpdate")
        end
    end
end

function Tooltips:OnTooltipUpdate(tooltip, elapsed)
    if not self.db.profile.cursorFollow or not tooltip:IsShown() then return end
    
    local x, y = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale()
    x = x / uiScale
    y = y / uiScale
    
    local anchor = self.db.profile.cursorAnchor or "BOTTOMRIGHT"
    local offsetX = self.db.profile.offsetX or 0
    local offsetY = self.db.profile.offsetY or 0
    
    tooltip:ClearAllPoints()
    tooltip:SetPoint(anchor, UIParent, "BOTTOMLEFT", x + offsetX, y + offsetY)
end

-- ============================================================================
-- Player Information
-- ============================================================================

function Tooltips:OnTooltipSetUnit(tooltip)
    if not self.db.profile.enabled then return end
    
    local _, unit = tooltip:GetUnit()
    if not unit or not UnitExists(unit) then return end
    
    -- Only process players
    if not UnitIsPlayer(unit) then return end
    
    local name, realm = UnitName(unit)
    local guid = UnitGUID(unit)
    
    if not name or not guid then return end
    
    -- Class coloring for player names
    if self.db.profile.classColor then
        local _, class = UnitClass(unit)
        if class then
            local color = RAID_CLASS_COLORS[class]
            if color then
                tooltip:ClearLines()
                tooltip:AddLine(name, color.r, color.g, color.b)
            end
        end
    end
    
    -- Guild information
    if self.db.profile.showGuild then
        local guildName, guildRankName, guildRankIndex = GetGuildInfo(unit)
        if guildName then
            local playerGuildName = GetGuildInfo("player")
            local color = self.db.profile.otherGuildColor
            
            if guildName == playerGuildName then
                color = self.db.profile.yourGuildColor
            end
            
            tooltip:AddLine(string.format("<%s>", guildName), color.r, color.g, color.b)
            if guildRankName then
                tooltip:AddLine(guildRankName, 0.7, 0.7, 0.7)
            end
        end
    end
    
    -- Player status (AFK/DND)
    if self.db.profile.showStatus then
        if UnitIsAFK(unit) then
            tooltip:AddLine("|cffFF0000<AFK>|r")
        elseif UnitIsDND(unit) then
            tooltip:AddLine("|cffFF0000<DND>|r")
        end
    end
    
    -- Faction
    if self.db.profile.showFaction then
        local faction = UnitFactionGroup(unit)
        if faction then
            local color = faction == "Horde" and {r = 1, g = 0.1, b = 0.1} or {r = 0.1, g = 0.3, b = 1}
            tooltip:AddLine(faction, color.r, color.g, color.b)
        end
    end
    
    -- Target of target
    if self.db.profile.showTargetOf then
        local target = unit .. "target"
        if UnitExists(target) then
            local targetName = UnitName(target)
            if targetName then
                tooltip:AddLine("Target: " .. targetName, 0.7, 0.7, 1)
            end
        end
    end
    
    -- Role
    if self.db.profile.showRole then
        local role = UnitGroupRolesAssigned(unit)
        if role and role ~= "NONE" then
            local roleText = role == "TANK" and "Tank" or role == "HEALER" and "Healer" or role == "DAMAGER" and "DPS" or role
            local roleColor = role == "TANK" and {r = 0.2, g = 0.6, b = 1} or 
                              role == "HEALER" and {r = 0.2, g = 1, b = 0.2} or 
                              {r = 1, g = 0.2, b = 0.2}
            tooltip:AddLine("Role: " .. roleText, roleColor.r, roleColor.g, roleColor.b)
        end
    end
    
    -- Item Level (from cache)
    if self.db.profile.showItemLevel then
        local cachedIlvl = self:GetCachedItemLevel(guid)
        if cachedIlvl then
            tooltip:AddLine("Item Level: " .. cachedIlvl, 1, 0.82, 0)
        elseif CanInspect(unit) then
            -- Request inspect data
            NotifyInspect(unit)
        end
    end
    
    -- Mythic+ Rating
    if self.db.profile.showMythicScore and C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
        if summary and summary.currentSeasonScore and summary.currentSeasonScore > 0 then
            local score = summary.currentSeasonScore
            local color = C_ChallengeMode.GetDungeonScoreRarityColor(score) or {r = 1, g = 1, b = 1}
            tooltip:AddLine(string.format("M+ Rating: %.0f", score), color.r, color.g, color.b)
        end
    end
    
    -- Mount information
    if self.db.profile.showMount then
        local mountID = self:GetUnitMountID(unit)
        if mountID then
            local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, 
                  faction, shouldHideOnChar, isCollected, mountID = C_MountJournal.GetMountInfoByID(mountID)
            if name then
                local collectedText = isCollected and "|cff00ff00(Collected)|r" or "|cffff0000(Not Collected)|r"
                tooltip:AddLine("Mount: " .. name .. " " .. collectedText, 1, 0.82, 0)
            end
        end
    end
    
    tooltip:Show()
end

function Tooltips:GetUnitMountID(unit)
    -- Check if unit has a mount buff using modern API
    if not C_UnitAuras then return nil end
    
    for i = 1, 40 do
        local auraData = C_UnitAuras.GetBuffDataByIndex(unit, i)
        if not auraData then break end
        
        -- Check if this buff is a mount
        if auraData.spellId and C_MountJournal then
            for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
                local mountName, mountSpellID = C_MountJournal.GetMountInfoByID(mountID)
                if mountSpellID == auraData.spellId then
                    return mountID
                end
            end
        end
    end
    return nil
end

function Tooltips:INSPECT_READY(event, guid)
    if not guid then return end
    
    -- Cache item level from inspect data
    local unit = self:GetUnitFromGUID(guid)
    if unit then
        local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel(unit)
        if avgItemLevelEquipped then
            self.playerCache[guid] = {
                itemLevel = math.floor(avgItemLevelEquipped),
                timestamp = GetTime()
            }
        end
    end
    
    ClearInspectPlayer()
end

function Tooltips:GetUnitFromGUID(guid)
    -- Check raid/party
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitGUID(unit) == guid then
                return unit
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            local unit = "party" .. i
            if UnitGUID(unit) == guid then
                return unit
            end
        end
    end
    
    -- Check target/focus
    if UnitGUID("target") == guid then return "target" end
    if UnitGUID("focus") == guid then return "focus" end
    if UnitGUID("mouseover") == guid then return "mouseover" end
    
    return nil
end

function Tooltips:GetCachedItemLevel(guid)
    local cache = self.playerCache[guid]
    if cache then
        -- Cache expires after 5 minutes
        if GetTime() - cache.timestamp < 300 then
            return cache.itemLevel
        else
            self.playerCache[guid] = nil
        end
    end
    return nil
end

-- ============================================================================
-- Module Enable/Disable
-- ============================================================================

function Tooltips:Toggle()
    if self.db.profile.enabled then
        self:Disable()
        self.db.profile.enabled = false
        MidnightUI:Print("Tooltips disabled")
    else
        self.db.profile.enabled = true
        self:Enable()
        MidnightUI:Print("Tooltips enabled")
    end
end

function Tooltips:UpdateSettings()
    if not self.db.profile.enabled then return end
    
    -- Update cursor following
    if self.db.profile.cursorFollow then
        self:EnableCursorFollow()
    end
    
    -- Reapply all styling with new settings
    self:StyleTooltips()
end

-- ============================================================================
-- Options
-- ============================================================================

function Tooltips:GetOptions()
    return {
        name = "Tooltips",
        type = "group",
        args = {
            header = {
                type = "header",
                name = "Tooltip Styling",
                order = 1,
            },
            enabled = {
                type = "toggle",
                name = "Enable Tooltip Styling",
                desc = "Style all game tooltips with your active theme",
                order = 2,
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
            spacer1 = {
                type = "description",
                name = " ",
                order = 3,
            },
            
            -- Appearance Settings
            appearanceHeader = {
                type = "header",
                name = "Appearance Settings",
                order = 10,
            },
            borderSize = {
                type = "range",
                name = "Border Size",
                desc = "Thickness of tooltip borders",
                min = 1,
                max = 5,
                step = 1,
                order = 11,
                get = function() return self.db.profile.borderSize end,
                set = function(_, value)
                    self.db.profile.borderSize = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            backdropAlpha = {
                type = "range",
                name = "Background Opacity",
                desc = "Opacity of tooltip backgrounds (overrides theme setting)",
                min = 0,
                max = 1,
                step = 0.05,
                order = 12,
                get = function() return self.db.profile.backdropAlpha end,
                set = function(_, value)
                    self.db.profile.backdropAlpha = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            fontSize = {
                type = "range",
                name = "Font Size",
                desc = "Size of tooltip text",
                min = 8,
                max = 18,
                step = 1,
                order = 13,
                get = function() return self.db.profile.fontSize end,
                set = function(_, value)
                    self.db.profile.fontSize = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            spacer2 = {
                type = "description",
                name = " ",
                order = 19,
            },
            
            -- Cursor Following
            cursorHeader = {
                type = "header",
                name = "Cursor Following",
                order = 20,
            },
            cursorFollow = {
                type = "toggle",
                name = "Follow Cursor",
                desc = "Tooltips will follow your mouse cursor",
                order = 21,
                get = function() return self.db.profile.cursorFollow end,
                set = function(_, value)
                    self.db.profile.cursorFollow = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            cursorAnchor = {
                type = "select",
                name = "Cursor Anchor",
                desc = "Where the tooltip anchors to the cursor",
                order = 22,
                values = {
                    ["TOPLEFT"] = "Top Left",
                    ["TOP"] = "Top",
                    ["TOPRIGHT"] = "Top Right",
                    ["LEFT"] = "Left",
                    ["CENTER"] = "Center",
                    ["RIGHT"] = "Right",
                    ["BOTTOMLEFT"] = "Bottom Left",
                    ["BOTTOM"] = "Bottom",
                    ["BOTTOMRIGHT"] = "Bottom Right",
                },
                get = function() return self.db.profile.cursorAnchor end,
                set = function(_, value)
                    self.db.profile.cursorAnchor = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self.db.profile.enabled or not self.db.profile.cursorFollow end,
            },
            offsetX = {
                type = "range",
                name = "X Offset",
                desc = "Horizontal offset from cursor",
                min = -100,
                max = 100,
                step = 1,
                order = 23,
                get = function() return self.db.profile.offsetX end,
                set = function(_, value)
                    self.db.profile.offsetX = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self.db.profile.enabled or not self.db.profile.cursorFollow end,
            },
            offsetY = {
                type = "range",
                name = "Y Offset",
                desc = "Vertical offset from cursor",
                min = -100,
                max = 100,
                step = 1,
                order = 24,
                get = function() return self.db.profile.offsetY end,
                set = function(_, value)
                    self.db.profile.offsetY = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self.db.profile.enabled or not self.db.profile.cursorFollow end,
            },
            fadeDelay = {
                type = "range",
                name = "Fade Delay",
                desc = "How quickly tooltips fade out (in seconds)",
                min = 0,
                max = 2,
                step = 0.1,
                order = 25,
                get = function() return self.db.profile.fadeDelay end,
                set = function(_, value)
                    self.db.profile.fadeDelay = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            scale = {
                type = "range",
                name = "Tooltip Scale",
                desc = "Overall size of tooltips (50% to 200%)",
                min = 0.5,
                max = 2.0,
                step = 0.05,
                order = 26,
                get = function() return self.db.profile.scale end,
                set = function(_, value)
                    self.db.profile.scale = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            spacer3 = {
                type = "description",
                name = " ",
                order = 29,
            },
            
            -- Player Information
            playerInfoHeader = {
                type = "header",
                name = "Player Information",
                order = 30,
            },
            classColor = {
                type = "toggle",
                name = "Class-Colored Names",
                desc = "Display player names in their class colors",
                order = 31,
                get = function() return self.db.profile.classColor end,
                set = function(_, value)
                    self.db.profile.classColor = value
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            showGuild = {
                type = "toggle",
                name = "Show Guild",
                desc = "Display guild information",
                order = 32,
                get = function() return self.db.profile.showGuild end,
                set = function(_, value)
                    self.db.profile.showGuild = value
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            yourGuildColor = {
                type = "color",
                name = "Your Guild Color",
                desc = "Color for your guild members",
                order = 33,
                get = function()
                    local c = self.db.profile.yourGuildColor
                    return c.r, c.g, c.b
                end,
                set = function(_, r, g, b)
                    self.db.profile.yourGuildColor = {r = r, g = g, b = b}
                end,
                disabled = function() return not self.db.profile.enabled or not self.db.profile.showGuild end,
            },
            otherGuildColor = {
                type = "color",
                name = "Other Guild Color",
                desc = "Color for other guild members",
                order = 34,
                get = function()
                    local c = self.db.profile.otherGuildColor
                    return c.r, c.g, c.b
                end,
                set = function(_, r, g, b)
                    self.db.profile.otherGuildColor = {r = r, g = g, b = b}
                end,
                disabled = function() return not self.db.profile.enabled or not self.db.profile.showGuild end,
            },
            showStatus = {
                type = "toggle",
                name = "Show AFK/DND Status",
                desc = "Display player AFK or DND status",
                order = 35,
                get = function() return self.db.profile.showStatus end,
                set = function(_, value)
                    self.db.profile.showStatus = value
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            showItemLevel = {
                type = "toggle",
                name = "Show Item Level",
                desc = "Display player item levels (requires inspect)",
                order = 36,
                get = function() return self.db.profile.showItemLevel end,
                set = function(_, value)
                    self.db.profile.showItemLevel = value
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            showFaction = {
                type = "toggle",
                name = "Show Faction",
                desc = "Display player faction (Horde/Alliance)",
                order = 37,
                get = function() return self.db.profile.showFaction end,
                set = function(_, value)
                    self.db.profile.showFaction = value
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            showMount = {
                type = "toggle",
                name = "Show Mount Info",
                desc = "Display mounted player's mount and if you have it collected",
                order = 38,
                get = function() return self.db.profile.showMount end,
                set = function(_, value)
                    self.db.profile.showMount = value
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            showRole = {
                type = "toggle",
                name = "Show Role",
                desc = "Display player role (Tank/Healer/DPS)",
                order = 39,
                get = function() return self.db.profile.showRole end,
                set = function(_, value)
                    self.db.profile.showRole = value
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            showMythicScore = {
                type = "toggle",
                name = "Show Mythic+ Rating",
                desc = "Display player's Mythic+ score",
                order = 40,
                get = function() return self.db.profile.showMythicScore end,
                set = function(_, value)
                    self.db.profile.showMythicScore = value
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
            showTargetOf = {
                type = "toggle",
                name = "Show Target Of Target",
                desc = "Display who the unit is targeting",
                order = 41,
                get = function() return self.db.profile.showTargetOf end,
                set = function(_, value)
                    self.db.profile.showTargetOf = value
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
        }
    }
end
