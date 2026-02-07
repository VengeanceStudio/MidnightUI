-- MidnightUI Custom CheckBox Widget
-- Theme-aware checkbox

local AceGUI = LibStub("AceGUI-3.0")
local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

local Type = "MidnightCheckBox"
local Version = 1

-- ============================================================================
-- METHODS
-- ============================================================================

local methods = {
    ["OnAcquire"] = function(self)
        self:SetWidth(200)
        self:SetType()
        self:SetValue(false)
        self:SetTriState(nil)
        self.checked = false
    end,
    
    ["OnRelease"] = function(self)
        self:SetDisabled(false)
        self:SetLabel()
        self:SetDescription()
        self:SetValue(false)
        self:SetType()
        self:SetTriState(nil)
        self.checked = false
        self.tristate = nil
    end,
    
    ["OnWidthSet"] = function(self, width)
        if self.desc then
            self.desc:SetWidth(width - 30)
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
    
    ["SetValue"] = function(self, value)
        local check = self.check
        self.checked = value
        if value then
            SetDesaturation(check, false)
            check:Show()
        else
            if self.tristate and value == nil then
                SetDesaturation(check, true)
                check:Show()
            else
                check:Hide()
            end
        end
        self:Fire("OnValueChanged", value)
    end,
    
    ["GetValue"] = function(self)
        return self.checked
    end,
    
    ["SetTriState"] = function(self, enabled)
        self.tristate = enabled
        self:SetValue(self:GetValue())
    end,
    
    ["SetType"] = function(self, type)
        local checkbg = self.checkbg
        local check = self.check
        local highlight = self.highlight
        
        local size
        if type == "radio" then
            size = 16
            checkbg:SetTexture("Interface\\Buttons\\UI-RadioButton")
            checkbg:SetTexCoord(0, 0.25, 0, 1)
            check:SetTexture("Interface\\Buttons\\UI-RadioButton")
            check:SetTexCoord(0.25, 0.5, 0, 1)
            check:SetBlendMode("ADD")
            highlight:SetTexture("Interface\\Buttons\\UI-RadioButton")
            highlight:SetTexCoord(0.5, 0.75, 0, 1)
        else
            size = 24
            checkbg:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
            checkbg:SetTexCoord(0, 1, 0, 1)
            check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            check:SetTexCoord(0, 1, 0, 1)
            check:SetBlendMode("BLEND")
            highlight:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
            highlight:SetTexCoord(0, 1, 0, 1)
        end
        checkbg:SetHeight(size)
        checkbg:SetWidth(size)
        self.type = type
    end,
    
    ["SetLabel"] = function(self, label)
        self.text:SetText(label or "")
        if label and label ~= "" then
            self.text:Show()
        else
            self.text:Hide()
        end
    end,
    
    ["SetDescription"] = function(self, desc)
        if desc and desc ~= "" then
            if not self.desc then
                local desc = self.frame:CreateFontString(nil, "OVERLAY")
                desc:SetPoint("TOPLEFT", self.checkbg, "TOPRIGHT", 5, -21)
                desc:SetWidth(self.frame:GetWidth() - 30)
                desc:SetJustifyH("LEFT")
                desc:SetJustifyV("TOP")
                FontKit:SetFont(desc, 'body', 'small')
                desc:SetTextColor(ColorPalette:GetColor('text-secondary'))
                self.desc = desc
            end
            self.desc:Show()
            self.desc:SetText(desc)
        else
            if self.desc then
                self.desc:Hide()
            end
        end
    end,
}

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

local function Constructor()
    local frame = CreateFrame("Button", nil, UIParent)
    frame:SetWidth(200)
    frame:SetHeight(24)
    
    local checkbg = frame:CreateTexture(nil, "ARTWORK")
    checkbg:SetWidth(24)
    checkbg:SetHeight(24)
    checkbg:SetPoint("TOPLEFT")
    checkbg:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    
    local check = frame:CreateTexture(nil, "OVERLAY")
    check:SetAllPoints(checkbg)
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:Hide()
    
    local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(checkbg)
    highlight:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    highlight:SetBlendMode("ADD")
    
    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", checkbg, "RIGHT", 5, 1)
    text:SetJustifyH("LEFT")
    FontKit:SetFont(text, 'body', 'normal')
    text:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    frame:SetScript("OnClick", function(self)
        local widget = self.obj
        if not widget.disabled then
            widget:SetValue(not widget:GetValue())
            widget:Fire("OnValueChanged", widget:GetValue())
        end
    end)
    
    local widget = {
        checkbg = checkbg,
        check = check,
        highlight = highlight,
        text = text,
        frame = frame,
        type = Type
    }
    
    for method, func in pairs(methods) do
        widget[method] = func
    end
    
    frame.obj = widget
    
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
