-- MidnightUI Frame Factory
-- Component creation system with theme support

local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local FrameFactory = {}
MidnightUI.FrameFactory = FrameFactory

-- Cache framework systems
local Atlas, ColorPalette, FontKit, LayoutHelper

-- Initialize on addon load
function FrameFactory:Initialize()
    Atlas = MidnightUI.Atlas
    ColorPalette = MidnightUI.ColorPalette
    FontKit = MidnightUI.FontKit
    LayoutHelper = MidnightUI.LayoutHelper
end

-- Current theme
FrameFactory.activeTheme = "MidnightGlass"

-- ============================================================================
-- THEME MANAGEMENT
-- ============================================================================

function FrameFactory:SetTheme(themeName)
    self.activeTheme = themeName
    if ColorPalette then ColorPalette:SetActiveTheme(themeName) end
    if FontKit then FontKit:SetActiveTheme(themeName) end
end

function FrameFactory:GetTheme()
    return self.activeTheme
end

-- ============================================================================
-- BUTTON FACTORY
-- ============================================================================

function FrameFactory:CreateButton(parent, width, height, text)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 120, height or 32)
    
    -- Background texture
    button.normalTexture = button:CreateTexture(nil, "BACKGROUND")
    button.normalTexture:SetAllPoints()
    Atlas:SetTexture(button.normalTexture, self.activeTheme, "button-normal")
    ColorPalette:GetColor("button-normal")
    button.normalTexture:SetVertexColor(ColorPalette:GetColor("button-bg"))
    
    button.hoverTexture = button:CreateTexture(nil, "BACKGROUND")
    button.hoverTexture:SetAllPoints()
    Atlas:SetTexture(button.hoverTexture, self.activeTheme, "button-hover")
    button.hoverTexture:SetVertexColor(ColorPalette:GetColor("button-hover"))
    button.hoverTexture:Hide()
    
    button.pressedTexture = button:CreateTexture(nil, "BACKGROUND")
    button.pressedTexture:SetAllPoints()
    Atlas:SetTexture(button.pressedTexture, self.activeTheme, "button-pressed")
    button.pressedTexture:SetVertexColor(ColorPalette:GetColor("button-pressed"))
    button.pressedTexture:Hide()
    
    -- Text
    button.text = FontKit:CreateFontString(button, "button", "normal")
    button.text:SetPoint("CENTER")
    button.text:SetText(text or "Button")
    button.text:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    -- Interactivity
    button:SetScript("OnEnter", function(self)
        self.hoverTexture:Show()
        self.normalTexture:Hide()
    end)
    
    button:SetScript("OnLeave", function(self)
        self.hoverTexture:Hide()
        self.normalTexture:Show()
    end)
    
    button:SetScript("OnMouseDown", function(self)
        self.pressedTexture:Show()
        self.hoverTexture:Hide()
    end)
    
    button:SetScript("OnMouseUp", function(self)
        self.pressedTexture:Hide()
        if self:IsMouseOver() then
            self.hoverTexture:Show()
        else
            self.normalTexture:Show()
        end
    end)
    
    -- Custom SetText function
    function button:SetButtonText(txt)
        self.text:SetText(txt)
    end
    
    return button
end

-- ============================================================================
-- PANEL FACTORY
-- ============================================================================

function FrameFactory:CreatePanel(parent, width, height)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(width or 400, height or 300)
    
    -- Background
    panel.bg = panel:CreateTexture(nil, "BACKGROUND")
    panel.bg:SetAllPoints()
    Atlas:SetTexture(panel.bg, self.activeTheme, "panel-bg")
    panel.bg:SetVertexColor(ColorPalette:GetColor("panel-bg"))
    
    -- Border
    panel.border = panel:CreateTexture(nil, "BORDER")
    panel.border:SetAllPoints()
    Atlas:SetTexture(panel.border, self.activeTheme, "panel-border")
    panel.border:SetVertexColor(ColorPalette:GetColor("panel-border"))
    
    return panel
end

-- ============================================================================
-- TAB FACTORY
-- ============================================================================

function FrameFactory:CreateTab(parent, width, height, text)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(width or 120, height or 32)
    
    -- Inactive texture
    tab.inactiveTexture = tab:CreateTexture(nil, "BACKGROUND")
    tab.inactiveTexture:SetAllPoints()
    Atlas:SetTexture(tab.inactiveTexture, self.activeTheme, "tab-inactive")
    tab.inactiveTexture:SetVertexColor(ColorPalette:GetColor("tab-inactive"))
    
    -- Active texture
    tab.activeTexture = tab:CreateTexture(nil, "BACKGROUND")
    tab.activeTexture:SetAllPoints()
    Atlas:SetTexture(tab.activeTexture, self.activeTheme, "tab-active")
    tab.activeTexture:SetVertexColor(ColorPalette:GetColor("tab-active"))
    tab.activeTexture:Hide()
    
    -- Text
    tab.text = FontKit:CreateFontString(tab, "tab", "normal")
    tab.text:SetPoint("CENTER")
    tab.text:SetText(text or "Tab")
    tab.text:SetTextColor(ColorPalette:GetColor("text-secondary"))
    
    tab.isActive = false
    
    function tab:SetActive(active)
        self.isActive = active
        if active then
            self.activeTexture:Show()
            self.inactiveTexture:Hide()
            self.text:SetTextColor(ColorPalette:GetColor("text-primary"))
        else
            self.activeTexture:Hide()
            self.inactiveTexture:Show()
            self.text:SetTextColor(ColorPalette:GetColor("text-secondary"))
        end
    end
    
    return tab
end

-- ============================================================================
-- SCROLLBAR FACTORY
-- ============================================================================

function FrameFactory:CreateScrollBar(parent, height)
    local scrollbar = CreateFrame("Slider", nil, parent)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetSize(16, height or 400)
    scrollbar:SetMinMaxValues(0, 100)
    scrollbar:SetValue(0)
    scrollbar:SetValueStep(1)
    
    -- Track
    scrollbar.track = scrollbar:CreateTexture(nil, "BACKGROUND")
    scrollbar.track:SetAllPoints()
    Atlas:SetTexture(scrollbar.track, self.activeTheme, "scrollbar-track")
    scrollbar.track:SetVertexColor(ColorPalette:GetColor("scrollbar-track"))
    
    -- Thumb
    scrollbar.thumb = scrollbar:CreateTexture(nil, "OVERLAY")
    scrollbar.thumb:SetSize(16, 32)
    scrollbar:SetThumbTexture(scrollbar.thumb)
    Atlas:SetTexture(scrollbar.thumb, self.activeTheme, "scrollbar-thumb")
    scrollbar.thumb:SetVertexColor(ColorPalette:GetColor("scrollbar-thumb"))
    
    return scrollbar
end

-- ============================================================================
-- TOOLTIP FACTORY
-- ============================================================================

function FrameFactory:CreateTooltip(name)
    local tooltip = CreateFrame("GameTooltip", name or "MidnightUITooltip", UIParent, "GameTooltipTemplate")
    
    -- Background
    if tooltip.NineSlice then
        tooltip.NineSlice:Hide()
    end
    
    tooltip.bg = tooltip:CreateTexture(nil, "BACKGROUND")
    tooltip.bg:SetAllPoints()
    Atlas:SetTexture(tooltip.bg, self.activeTheme, "tooltip-bg")
    tooltip.bg:SetVertexColor(ColorPalette:GetColor("tooltip-bg"))
    
    -- Apply font to tooltip lines
    for i = 1, 30 do
        local leftLine = _G[name .. "TextLeft" .. i]
        local rightLine = _G[name .. "TextRight" .. i]
        
        if leftLine then
            FontKit:SetFont(leftLine, "tooltip", "small")
        end
        if rightLine then
            FontKit:SetFont(rightLine, "tooltip", "small")
        end
    end
    
    return tooltip
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Apply theme to existing frame
function FrameFactory:ApplyTheme(frame, componentType)
    -- This would reapply theme textures and colors to an existing frame
    -- Implementation depends on frame type
end

return FrameFactory
