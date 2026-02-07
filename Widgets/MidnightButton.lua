-- MidnightUI Custom Button Widget
-- Theme-aware button with proper width

local AceGUI = LibStub("AceGUI-3.0")
local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

local Type = "MidnightButton"
local Version = 1

-- ============================================================================
-- METHODS
-- ============================================================================

local methods = {
    ["OnAcquire"] = function(self)
        self:SetWidth(200)
        self:SetText()
        self:SetDisabled(false)
    end,
    
    ["OnRelease"] = function(self)
        self:SetText()
        self:SetDisabled(false)
    end,
    
    ["SetText"] = function(self, text)
        self.text:SetText(text or "")
    end,
    
    ["SetDisabled"] = function(self, disabled)
        self.disabled = disabled
        if disabled then
            self.frame:Disable()
            self.text:SetTextColor(ColorPalette:GetColor('text-disabled'))
        else
            self.frame:Enable()
            self.text:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
    end,
    
    ["OnWidthSet"] = function(self, width)
        -- Reduce width by 25px
        self.frame:SetWidth(width - 25)
    end,
    
    ["OnHeightSet"] = function(self, height)
        self.frame:SetHeight(height)
    end
}

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

local function Constructor()
    local button = CreateFrame("Button", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
    button:SetHeight(24)
    button:SetWidth(200)
    
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    button:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    button:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
    
    local text = button:CreateFontString(nil, "OVERLAY")
    FontKit:SetFont(text, 'button', 'normal')
    text:SetTextColor(ColorPalette:GetColor('text-primary'))
    text:SetPoint("CENTER")
    
    button:SetScript("OnEnter", function(self)
        local r, g, b, a = ColorPalette:GetColor('button-bg')
        button:SetBackdropColor(math.min(r * 2 + 0.15, 1), math.min(g * 2 + 0.15, 1), math.min(b * 2 + 0.15, 1), a)
        button:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
    end)
    
    button:SetScript("OnLeave", function(self)
        button:SetBackdropColor(ColorPalette:GetColor('button-bg'))
        button:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
    end)
    
    local widget = {
        frame = button,
        text = text,
        type = Type
    }
    
    for method, func in pairs(methods) do
        widget[method] = func
    end
    
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
