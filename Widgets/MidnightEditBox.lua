-- MidnightUI Custom EditBox Widget
-- Theme-aware edit box

local AceGUI = LibStub("AceGUI-3.0")
local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

local Type = "MidnightEditBox"
local Version = 1

-- ============================================================================
-- METHODS
-- ============================================================================

local methods = {
    ["OnAcquire"] = function(self)
        self:SetWidth(200)
        self:SetDisabled(false)
        self:SetLabel()
        self:SetText()
        self:SetMaxLetters(0)
        self.editbox:SetCursorPosition(0)
        self.editbox:SetScript("OnChar", nil)
        self.editbox:SetScript("OnKeyUp", nil)
        self:SetCallback("OnEnter", nil)
        self:SetCallback("OnLeave", nil)
        self.editbox:SetScript("OnEnterPressed", function(frame)
            local self = frame.obj
            self:Fire("OnEnterPressed", self.editbox:GetText())
        end)
    end,
    
    ["OnRelease"] = function(self)
        self:ClearFocus()
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
        self.editbox:SetText(text or "")
        self.editbox:SetCursorPosition(0)
    end,
    
    ["GetText"] = function(self)
        return self.editbox:GetText()
    end,
    
    ["SetLabel"] = function(self, text)
        if text and text ~= "" then
            self.label:SetText(text)
            self.label:Show()
            self.editbox:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -18)
        else
            self.label:SetText("")
            self.label:Hide()
            self.editbox:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
        end
    end,
    
    ["SetMaxLetters"] = function(self, num)
        self.editbox:SetMaxLetters(num or 0)
    end,
    
    ["ClearFocus"] = function(self)
        self.editbox:ClearFocus()
    end,
    
    ["SetFocus"] = function(self)
        self.editbox:SetFocus()
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
    
    editbox:SetScript("OnEnter", function(frame)
        frame.obj:Fire("OnEnter")
    end)
    
    editbox:SetScript("OnLeave", function(frame)
        frame.obj:Fire("OnLeave")
    end)
    
    editbox:SetScript("OnTextChanged", function(frame)
        if frame:HasFocus() then
            frame.obj:Fire("OnTextChanged", frame:GetText())
        end
    end)
    
    local widget = {
        frame = frame,
        editbox = editbox,
        label = label,
        type = Type
    }
    
    for method, func in pairs(methods) do
        widget[method] = func
    end
    
    editbox.obj = widget
    frame.obj = widget
    
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
