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
        self:SetHeight(24)
        self:SetWidth(200)
        self:SetDisabled(false)
        self:SetAutoWidth(false)
        self:SetText()
    end,
    
    ["OnRelease"] = function(self)
        -- Reset to defaults
    end,
    
    ["SetText"] = function(self, text)
        self.text:SetText(text or "")
        if self.autoWidth then
            self:SetWidth(self.text:GetStringWidth() + 30)
        end
    end,
    
    ["SetAutoWidth"] = function(self, autoWidth)
        self.autoWidth = autoWidth
        if self.autoWidth then
            self:SetWidth(self.text:GetStringWidth() + 30)
        end
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
        -- Width is set by frame
    end,
    
    ["OnHeightSet"] = function(self, height)
        -- Height is set by frame
    end,
    
    ["RefreshColors"] = function(self)
        self.frame:SetBackdropColor(ColorPalette:GetColor('button-bg'))
        self.frame:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
        if self.disabled then
            self.text:SetTextColor(ColorPalette:GetColor('text-disabled'))
        else
            self.text:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
    end,
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
    
    button:SetScript("OnClick", function(self, ...)
        AceGUI:ClearFocus()
        PlaySound(852) -- SOUNDKIT.IG_MAINMENU_OPTION
        self.obj:Fire("OnClick", ...)
    end)
    
    button:SetScript("OnEnter", function(self)
        self.obj:Fire("OnEnter")
        local r, g, b, a = ColorPalette:GetColor('button-bg')
        self:SetBackdropColor(math.min(r * 2 + 0.15, 1), math.min(g * 2 + 0.15, 1), math.min(b * 2 + 0.15, 1), a)
    end)
    
    button:SetScript("OnLeave", function(self)
        self.obj:Fire("OnLeave")
        self:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    end)
    
    local widget = {
        frame = button,
        text = text,
        type = Type
    }
    
    for method, func in pairs(methods) do
        widget[method] = func
    end
    
    button.obj = widget
    
    local registeredWidget = AceGUI:RegisterAsWidget(widget)
    
    -- Protect the type field from being set to nil
    local widgetType = Type
    local mt = getmetatable(registeredWidget) or {}
    mt.__newindex = function(t, k, v)
        if k == "type" and v == nil then
            rawset(t, k, widgetType)
        else
            rawset(t, k, v)
        end
    end
    setmetatable(registeredWidget, mt)
    
    return registeredWidget
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
