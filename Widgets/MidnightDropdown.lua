-- MidnightUI Custom Dropdown Widget
-- Theme-aware dropdown with proper text positioning

local AceGUI = LibStub("AceGUI-3.0")
local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

local Type = "MidnightDropdown"
local Version = 1

-- ============================================================================
-- METHODS
-- ============================================================================

local methods = {
    ["OnAcquire"] = function(self)
        self:SetWidth(200)
        self:SetLabel()
    end,
    
    ["OnRelease"] = function(self)
        self:SetText("")
        self:SetLabel()
        self:SetDisabled(false)
        self.value = nil
        self.list = nil
    end,
    
    ["SetDisabled"] = function(self, disabled)
        self.disabled = disabled
        if disabled then
            self.button:Disable()
            self.text:SetTextColor(ColorPalette:GetColor('text-disabled'))
        else
            self.button:Enable()
            self.text:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
    end,
    
    ["SetText"] = function(self, text)
        self.text:SetText(text or "")
    end,
    
    ["SetLabel"] = function(self, text)
        if text and text ~= "" then
            self.label:SetText(text)
            self.label:Show()
            self.dropdown:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -18)
        else
            self.label:SetText("")
            self.label:Hide()
            self.dropdown:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
        end
    end,
    
    ["SetValue"] = function(self, value)
        self.value = value
        if self.list and self.list[value] then
            self:SetText(self.list[value])
        end
    end,
    
    ["SetList"] = function(self, list)
        self.list = list
    end,
    
    ["OnWidthSet"] = function(self, width)
        -- Reduce width by 30px
        local adjustedWidth = width - 30
        self.dropdown:SetWidth(adjustedWidth)
    end,
    
    ["OnHeightSet"] = function(self, height)
        self.dropdown:SetHeight(height)
    end
}

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetHeight(44)
    frame:SetWidth(200)
    
    local label = frame:CreateFontString(nil, "OVERLAY")
    FontKit:SetFont(label, 'body', 'normal')
    label:SetTextColor(ColorPalette:GetColor('text-primary'))
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetHeight(14)
    
    local dropdown = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
    dropdown:SetHeight(26)
    dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -18)
    dropdown:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -18)
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    dropdown:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    dropdown:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    local button = CreateFrame("Button", nil, dropdown)
    button:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -2, -2)
    button:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -2, 2)
    button:SetWidth(18)
    
    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetSize(10, 10)
    arrow:SetPoint("CENTER")
    arrow:SetRotation(-1.57)
    arrow:SetVertexColor(ColorPalette:GetColor('text-secondary'))
    
    local text = dropdown:CreateFontString(nil, "OVERLAY")
    FontKit:SetFont(text, 'body', 'normal')
    text:SetTextColor(ColorPalette:GetColor('text-primary'))
    text:SetPoint("LEFT", dropdown, "LEFT", 4, 0)
    text:SetPoint("RIGHT", button, "LEFT", -2, 0)
    text:SetJustifyH("LEFT")
    
    button:SetScript("OnClick", function()
        -- Placeholder for pullout menu
    end)
    
    local widget = {
        frame = frame,
        dropdown = dropdown,
        button = button,
        text = text,
        label = label,
        type = Type
    }
    
    for method, func in pairs(methods) do
        widget[method] = func
    end
    
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
