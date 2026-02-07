-- MidnightUI Custom EditBox Widget
-- Theme-aware edit box

local AceGUI = LibStub("AceGUI-3.0")
local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

local Type = "MidnightEditBox"
local Version = 1

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function ShowButton(self)
    if not self.disablebutton then
        self.button:Show()
        self.editbox:SetTextInsets(4, 44, 2, 2)  -- Make room for button
    end
end

local function HideButton(self)
    self.button:Hide()
    self.editbox:SetTextInsets(4, 4, 2, 2)
end

-- ============================================================================
-- METHODS
-- ============================================================================

local methods = {
    ["OnAcquire"] = function(self)
        self:SetWidth(200)
        self:SetDisabled(false)
        self:SetLabel()
        self:SetText()
        self:DisableButton(false)
        self:SetMaxLetters(0)
    end,
    
    ["OnRelease"] = function(self)
        self:ClearFocus()
    end,
    
    ["OnWidthSet"] = function(self, width)
        -- Width handled by frame
    end,
    
    ["OnHeightSet"] = function(self, height)
        -- Height controlled by SetLabel
    end,
    
    ["SetDisabled"] = function(self, disabled)
        self.disabled = disabled
        if disabled then
            self.editbox:EnableMouse(false)
            self.editbox:ClearFocus()
            self.editbox:SetTextColor(ColorPalette:GetColor('text-disabled'))
            self.label:SetTextColor(ColorPalette:GetColor('text-disabled'))
        else
            self.editbox:EnableMouse(true)
            self.editbox:SetTextColor(ColorPalette:GetColor('text-primary'))
            self.label:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
    end,
    
    ["SetText"] = function(self, text)
        self.lasttext = text or ""
        self.editbox:SetText(text or "")
        self.editbox:SetCursorPosition(0)
        HideButton(self)
    end,
    
    ["GetText"] = function(self)
        return self.editbox:GetText()
    end,
    
    ["SetLabel"] = function(self, text)
        if text and text ~= "" then
            self.label:SetText(text)
            self.label:Show()
            self.editbox:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -18)
            self:SetHeight(44)
            self.alignoffset = 30
        else
            self.label:SetText("")
            self.label:Hide()
            self.editbox:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
            self:SetHeight(26)
            self.alignoffset = 12
        end
    end,
    
    ["SetMaxLetters"] = function(self, num)
        self.editbox:SetMaxLetters(num or 0)
    end,
    
    ["DisableButton"] = function(self, disabled)
        self.disablebutton = disabled
        if disabled then
            HideButton(self)
        end
    end,
    
    ["ClearFocus"] = function(self)
        self.editbox:ClearFocus()
        self.frame:SetScript("OnShow", nil)
    end,
    
    ["SetFocus"] = function(self)
        self.editbox:SetFocus()
        self.frame:SetScript("OnShow", nil)
    end,
    
    ["HighlightText"] = function(self, from, to)
        self.editbox:HighlightText(from, to)
    end,
    
    ["GetCursorPosition"] = function(self)
        return self.editbox:GetCursorPosition()
    end,
    
    ["SetCursorPosition"] = function(self, ...)
        return self.editbox:SetCursorPosition(...)
    end,
    
    ["RefreshColors"] = function(self)
        self.editbox:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
        if self.disabled then
            self.editbox:SetTextColor(ColorPalette:GetColor('text-disabled'))
            self.label:SetTextColor(ColorPalette:GetColor('text-disabled'))
        else
            self.editbox:SetTextColor(ColorPalette:GetColor('text-primary'))
            self.label:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
    end,
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
    
    local editbox = CreateFrame("EditBox", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
    editbox:SetHeight(26)
    editbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -18)
    editbox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -18)
    editbox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    editbox:SetBackdropColor(0.15, 0.15, 0.15, 1)
    editbox:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
    
    editbox:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    editbox:SetTextColor(ColorPalette:GetColor('text-primary'))
    editbox:SetTextInsets(4, 4, 2, 2)
    editbox:SetAutoFocus(false)
    editbox:SetMaxLetters(0)
    
    editbox:SetScript("OnEscapePressed", function(frame)
        frame:ClearFocus()
    end)
    
    editbox:SetScript("OnEnterPressed", function(frame)
        local self = frame.obj
        local value = frame:GetText()
        local cancel = self:Fire("OnEnterPressed", value)
        if not cancel then
            PlaySound(856) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
            HideButton(self)
        end
    end)
    
    editbox:SetScript("OnEnter", function(frame)
        frame.obj:Fire("OnEnter")
    end)
    
    editbox:SetScript("OnLeave", function(frame)
        frame.obj:Fire("OnLeave")
    end)
    
    editbox:SetScript("OnTextChanged", function(frame)
        local self = frame.obj
        local value = frame:GetText()
        if tostring(value) ~= tostring(self.lasttext) then
            self:Fire("OnTextChanged", value)
            self.lasttext = value
            ShowButton(self)
        end
    end)
    
    editbox:SetScript("OnEditFocusGained", function(frame)
        AceGUI:SetFocus(frame.obj)
    end)
    
    -- Create OK button
    local button = CreateFrame("Button", nil, editbox, nil)
    button:SetSize(40, 20)
    button:SetPoint("RIGHT", -2, 0)
    button:SetText(OKAY)
    
    -- Style the button with MidnightUI theme
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    button:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    button:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
    
    local buttonText = button:CreateFontString(nil, "OVERLAY")
    FontKit:SetFont(buttonText, 'button', 'normal')
    buttonText:SetTextColor(ColorPalette:GetColor('text-primary'))
    buttonText:SetPoint("CENTER")
    buttonText:SetText(OKAY)
    button.text = buttonText
    
    button:SetScript("OnClick", function(btn)
        local editbox = btn:GetParent()
        editbox:ClearFocus()
        local self = editbox.obj
        local value = editbox:GetText()
        local cancel = self:Fire("OnEnterPressed", value)
        if not cancel then
            PlaySound(856)
            HideButton(self)
        end
    end)
    
    button:Hide()
    
    local widget = {
        frame = frame,
        editbox = editbox,
        label = label,
        button = button,
        type = Type
    }
    
    for method, func in pairs(methods) do
        widget[method] = func
    end
    
    editbox.obj = widget
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
