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
        self.disabled = false
        self.checked = false
        self.tristate = nil
        self.check:Hide()
        self.text:SetText("")
        if self.desc then
            self.desc:Hide()
            self.desc:SetText("")
        end
    end,
    
    ["OnWidthSet"] = function(self, width)
        if self.desc then
            self.desc:SetWidth(width - 30)
        end
    end,
    
    ["OnHeightSet"] = function(self, height)
        -- CheckBox height is fixed
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
    
    ["SetValue"] = function(self, value, silent)
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
        self:SetDisabled(self.disabled)
        if not silent then
            self:Fire("OnValueChanged", value)
        end
    end,
    
    ["GetValue"] = function(self)
        return self.checked
    end,
    
    ["ToggleChecked"] = function(self)
        local value = not self.checked
        self:SetValue(value, true)  -- silent = true to avoid double-firing
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
            -- Apply theme color to radio button
            check:SetVertexColor(ColorPalette:GetColor("accent-primary"))
            highlight:SetTexture("Interface\\Buttons\\UI-RadioButton")
            highlight:SetTexCoord(0.5, 0.75, 0, 1)
            highlight:SetVertexColor(ColorPalette:GetColor("accent-primary"))
        else
            size = 24
            checkbg:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
            checkbg:SetTexCoord(0, 1, 0, 1)
            check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            check:SetTexCoord(0, 1, 0, 1)
            check:SetBlendMode("BLEND")
            -- Apply theme color to the check mark
            check:SetVertexColor(ColorPalette:GetColor("accent-primary"))
            highlight:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
            highlight:SetTexCoord(0, 1, 0, 1)
            -- Apply theme color to highlight
            highlight:SetVertexColor(ColorPalette:GetColor("accent-primary"))
        end
        checkbg:SetHeight(size)
        checkbg:SetWidth(size)
        self.type = type
    end,
    
    ["SetLabel"] = function(self, label)
        self.text:SetText(label or "")
    end,
    
    ["SetDescription"] = function(self, desc)
        if desc and desc ~= "" then
            if not self.desc then
                local descText = self.frame:CreateFontString(nil, "OVERLAY")
                descText:SetPoint("TOPLEFT", self.checkbg, "TOPRIGHT", 5, -21)
                descText:SetWidth(self.frame:GetWidth() - 30)
                descText:SetJustifyH("LEFT")
                descText:SetJustifyV("TOP")
                FontKit:SetFont(descText, 'body', 'small')
                descText:SetTextColor(ColorPalette:GetColor('text-secondary'))
                self.desc = descText
            end
            self.desc:Show()
            self.desc:SetText(desc)
            self:OnWidthSet(self.frame:GetWidth())
        else
            if self.desc then
                self.desc:Hide()
                self.desc:SetText("")
            end
            self:SetHeight(24)
        end
    end,
    
    ["RefreshColors"] = function(self)
        if self.disabled then
            self.text:SetTextColor(ColorPalette:GetColor('text-disabled'))
            if self.desc then
                self.desc:SetTextColor(ColorPalette:GetColor('text-disabled'))
            end
        else
            self.text:SetTextColor(ColorPalette:GetColor('text-primary'))
            if self.desc then
                self.desc:SetTextColor(ColorPalette:GetColor('text-secondary'))
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
    -- Apply theme color to check mark
    check:SetVertexColor(ColorPalette:GetColor("accent-primary"))
    
    local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(checkbg)
    highlight:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    highlight:SetBlendMode("ADD")
    -- Apply theme color to highlight
    highlight:SetVertexColor(ColorPalette:GetColor("accent-primary"))
    
    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", checkbg, "RIGHT", 5, 1)
    text:SetJustifyH("LEFT")
    FontKit:SetFont(text, 'body', 'normal')
    text:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    frame:SetScript("OnMouseDown", function(self)
        local widget = self.obj
        if not widget.disabled then
            widget.text:SetPoint("LEFT", widget.checkbg, "RIGHT", 6, 0)
        end
    end)
    
    frame:SetScript("OnMouseUp", function(self)
        local widget = self.obj
        if not widget.disabled then
            widget:ToggleChecked()
            if widget.checked then
                PlaySound(856) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
            else
                PlaySound(857) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
            end
            widget:Fire("OnValueChanged", widget.checked)
            widget.text:SetPoint("LEFT", widget.checkbg, "RIGHT", 5, 1)
        end
    end)
    
    frame:SetScript("OnEnter", function(self)
        self.obj:Fire("OnEnter")
    end)
    
    frame:SetScript("OnLeave", function(self)
        self.obj:Fire("OnLeave")
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
    
    local registeredWidget = AceGUI:RegisterAsWidget(widget)
    
    -- Protect the type field from being set to nil
    local widgetType = Type
    local mt = getmetatable(registeredWidget) or {}
    local oldIndex = mt.__index
    mt.__newindex = function(t, k, v)
        if k == "type" and v == nil then
            -- Prevent type from being set to nil
            rawset(t, k, widgetType)
        else
            rawset(t, k, v)
        end
    end
    setmetatable(registeredWidget, mt)
    
    return registeredWidget
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
