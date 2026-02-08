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
            showItemLevel = true,
            fontSize = 12,
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
    
    -- Listen for theme changes
    self:RegisterMessage("MIDNIGHTUI_THEME_CHANGED", "OnThemeChanged")
end

-- ============================================================================
-- Tooltip Styling
-- ============================================================================

function Tooltips:StyleTooltips()
    if not self.ColorPalette then return end
    
    for _, tooltip in ipairs(self.tooltips) do
        if tooltip and tooltip.SetBackdrop then
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
    
    -- Set backdrop
    tooltip:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = self.db.profile.borderSize or 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    
    tooltip:SetBackdropColor(bgr, bgg, bgb, bga)
    tooltip:SetBackdropBorderColor(br, bg, bb, ba)
    
    -- Style fonts if FontKit is available
    if self.FontKit and tooltip.NineSlice then
        -- Hook to update font when tooltip shows
        if not self:IsHooked(tooltip, "OnShow") then
            self:HookScript(tooltip, "OnShow", "OnTooltipShow")
        end
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
    
    -- Reapply styling when tooltip anchor is set
    self:StyleTooltip(tooltip)
end

function Tooltips:OnThemeChanged()
    -- Reapply styling when theme changes
    self:StyleTooltips()
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
            appearanceHeader = {
                type = "header",
                name = "Appearance Settings",
                order = 4,
            },
            borderSize = {
                type = "range",
                name = "Border Size",
                desc = "Thickness of tooltip borders",
                min = 1,
                max = 5,
                step = 1,
                order = 5,
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
                order = 6,
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
                order = 7,
                get = function() return self.db.profile.fontSize end,
                set = function(_, value)
                    self.db.profile.fontSize = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self.db.profile.enabled end,
            },
        }
    }
end
