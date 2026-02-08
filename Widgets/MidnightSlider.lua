-- MidnightUI Custom Slider Widget
-- Theme-aware slider with proper spacing

local AceGUI = LibStub("AceGUI-3.0")
local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

local Type = "MidnightSlider"
local Version = 1

-- ============================================================================
-- METHODS
-- ============================================================================

local methods = {
    ["OnAcquire"] = function(self)
        self:SetWidth(200)
        self:SetLabel()
        self:SetSliderValues(0, 100, 1)
        self:SetValue(0)
    end,
    
    ["OnRelease"] = function(self)
        self:SetDisabled(false)
        self:SetLabel()
    end,
    
    ["SetDisabled"] = function(self, disabled)
        self.disabled = disabled
        if disabled then
            self.slider:Disable()
            self.label:SetTextColor(ColorPalette:GetColor('text-disabled'))
        else
            self.slider:Enable()
            self.label:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
    end,
    
    ["SetLabel"] = function(self, text)
        self.label:SetText(text or "")
    end,
    
    ["SetSliderValues"] = function(self, min, max, step)
        self.slider:SetMinMaxValues(min, max)
        self.slider:SetValueStep(step)
        self.min = min
        self.max = max
        self.step = step
    end,
    
    ["SetValue"] = function(self, value)
        self.slider:SetValue(value)
        self.editbox:SetText(tostring(value))
    end,
    
    ["GetValue"] = function(self)
        return self.slider:GetValue()
    end,
    
    ["SetIsPercent"] = function(self, value)
        self.ispercent = value
    end,
    
    ["RefreshColors"] = function(self)
        local r, g, b, a = ColorPalette:GetColor('accent-primary')
        if self.track then self.track:SetVertexColor(r, g, b, a) end
        if self.thumb then self.thumb:SetVertexColor(r, g, b, a) end
        if self.editbox then
            self.editbox:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
            self.editbox:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
        if self.label then
            self.label:SetTextColor(self.disabled and ColorPalette:GetColor('text-disabled') or ColorPalette:GetColor('text-primary'))
        end
    end,
    
    ["OnWidthSet"] = function(self, width)
        self.slider:SetWidth(width - 20)
    end,
    
    ["OnHeightSet"] = function(self, height)
        -- Custom height with spacing
    end
}

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetHeight(80)  -- Extra height for spacing
    frame:SetWidth(200)
    
    local label = frame:CreateFontString(nil, "OVERLAY")
    FontKit:SetFont(label, 'body', 'normal')
    label:SetTextColor(ColorPalette:GetColor('text-primary'))
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetHeight(14)
    
    local slider = CreateFrame("Slider", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(20)
    slider:SetPoint("TOP", label, "BOTTOM", 0, -8)
    slider:SetPoint("LEFT", frame, "LEFT", 10, 0)
    slider:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    
    -- Slider track
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture("Interface\\Buttons\\WHITE8X8")
    track:SetVertexColor(ColorPalette:GetColor('accent-primary'))
    track:SetHeight(4)
    track:SetPoint("CENTER", slider, "CENTER", 0, 0)
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    
    -- Slider thumb
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
    thumb:SetVertexColor(ColorPalette:GetColor('accent-primary'))
    thumb:SetSize(6, 10)
    slider:SetThumbTexture(thumb)
    
    local editbox = CreateFrame("EditBox", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
    editbox:SetHeight(20)
    editbox:SetWidth(60)
    editbox:SetPoint("TOP", slider, "BOTTOM", 0, -8)
    editbox:SetAutoFocus(false)
    editbox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    editbox:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    editbox:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Set font directly on editbox
    editbox:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    editbox:SetTextColor(ColorPalette:GetColor('text-primary'))
    editbox:SetTextInsets(4, 4, 0, 0)
    editbox:SetJustifyH("CENTER")
    
    slider:SetScript("OnValueChanged", function(self, value)
        editbox:SetText(tostring(math.floor(value + 0.5)))
    end)
    
    editbox:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            slider:SetValue(value)
        end
        self:ClearFocus()
    end)
    
    local widget = {
        frame = frame,
        slider = slider,
        editbox = editbox,
        label = label,
        track = track,
        thumb = thumb,
        type = Type
    }
    
    for method, func in pairs(methods) do
        widget[method] = func
    end
    
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
