local AceGUI = LibStub("AceGUI-3.0")
local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

local Type = "MidnightHeading"
local Version = 1

-- ============================================================================
-- METHODS
-- ============================================================================

local methods = {
    ["OnAcquire"] = function(self)
        self:SetText()
        self:SetFullWidth()
        self:SetHeight(24)
    end,
    
    ["SetText"] = function(self, text)
        self.label:SetText(text or "")
        if text and text ~= "" then
            self.left:SetPoint("RIGHT", self.label, "LEFT", -8, 0)
            self.right:Show()
        else
            self.left:SetPoint("RIGHT", -3, 0)
            self.right:Hide()
        end
    end,
    
    ["RefreshColors"] = function(self)
        local r, g, b = ColorPalette:GetColor('accent-primary')
        self.left:SetColorTexture(r, g, b, 0.5)
        self.right:SetColorTexture(r, g, b, 0.5)
        self.label:SetTextColor(ColorPalette:GetColor('text-primary'))
    end,
}

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    
    local label = frame:CreateFontString(nil, "OVERLAY")
    FontKit:SetFont(label, 'heading', 'bold')
    label:SetTextColor(ColorPalette:GetColor('text-primary'))
    label:SetPoint("TOP")
    label:SetPoint("BOTTOM")
    label:SetJustifyH("CENTER")
    
    -- Simple solid color lines instead of textured borders
    local left = frame:CreateTexture(nil, "BACKGROUND")
    left:SetHeight(1)
    left:SetPoint("LEFT", 3, 0)
    left:SetPoint("RIGHT", label, "LEFT", -8, 0)
    local r, g, b = ColorPalette:GetColor('accent-primary')
    left:SetColorTexture(r, g, b, 0.5)
    
    local right = frame:CreateTexture(nil, "BACKGROUND")
    right:SetHeight(1)
    right:SetPoint("RIGHT", -3, 0)
    right:SetPoint("LEFT", label, "RIGHT", 8, 0)
    right:SetColorTexture(r, g, b, 0.5)
    
    local widget = {
        frame = frame,
        label = label,
        left = left,
        right = right,
        type = Type
    }
    
    for method, func in pairs(methods) do
        widget[method] = func
    end
    
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
    
    -- Register for theme changes
    ColorPalette:RegisterCallback(function()
        if registeredWidget.RefreshColors then
            registeredWidget:RefreshColors()
        end
    end)
    
    return registeredWidget
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
