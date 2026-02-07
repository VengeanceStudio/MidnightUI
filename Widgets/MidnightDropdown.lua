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
        local pullout = AceGUI:Create("Dropdown-Pullout")
        self.pullout = pullout
        pullout.userdata.obj = self
        pullout:SetCallback("OnClose", function(widget)
            self.open = nil
            self:Fire("OnClosed")
        end)
        pullout:SetCallback("OnOpen", function(widget)
            local value = self.value
            if not self.multiselect then
                for i, item in widget:IterateItems() do
                    item:SetValue(item.userdata.value == value)
                end
            end
            self.open = true
            self:Fire("OnOpened")
        end)
        self.pullout.frame:SetFrameLevel(self.frame:GetFrameLevel() + 1)
        
        self:SetHeight(44)
        self:SetWidth(200)
        self:SetLabel()
        self:SetPulloutWidth(nil)
        self.list = {}
    end,
    
    ["OnRelease"] = function(self)
        if self.open then
            self.pullout:Close()
        end
        AceGUI:Release(self.pullout)
        self.pullout = nil
        
        self:SetText("")
        self:SetDisabled(false)
        self:SetMultiselect(false)
        
        self.value = nil
        self.list = nil
        self.open = nil
        self.hasClose = nil
    end,
    
    ["SetDisabled"] = function(self, disabled)
        self.disabled = disabled
        if disabled then
            self.button:Disable()
            self.text:SetTextColor(ColorPalette:GetColor('text-disabled'))
            self.label:SetTextColor(ColorPalette:GetColor('text-disabled'))
        else
            self.button:Enable()
            self.text:SetTextColor(ColorPalette:GetColor('text-primary'))
            self.label:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
    end,
    
    ["ClearFocus"] = function(self)
        if self.open then
            self.pullout:Close()
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
            self:SetHeight(44)
            self.alignoffset = 30
        else
            self.label:SetText("")
            self.label:Hide()
            self.dropdown:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
            self:SetHeight(26)
            self.alignoffset = 12
        end
    end,
    
    ["SetValue"] = function(self, value)
        self:SetText(self.list[value] or "")
        self.value = value
    end,
    
    ["GetValue"] = function(self)
        return self.value
    end,
    
    ["SetList"] = function(self, list, order, itemType)
        self.list = list or {}
        self.pullout:Clear()
        if not list then return end
        
        local items = {}
        if order then
            for i, key in ipairs(order) do
                local text = list[key]
                if text then
                    items[i] = {text = text, value = key}
                end
            end
        else
            for key, text in pairs(list) do
                items[#items + 1] = {text = text, value = key}
            end
        end
        
        for i, item in ipairs(items) do
            local widgetType = itemType or "Dropdown-Item-Toggle"
            local widget = AceGUI:Create(widgetType)
            widget:SetText(item.text)
            widget.userdata.obj = self
            widget.userdata.value = item.value
            widget:SetCallback("OnValueChanged", function(widget, event, checked)
                if self.multiselect then
                    self:Fire("OnValueChanged", item.value, checked)
                else
                    if checked then
                        self:SetValue(item.value)
                        self:Fire("OnValueChanged", item.value)
                    else
                        widget:SetValue(true)
                    end
                    if self.open then
                        self.pullout:Close()
                    end
                end
            end)
            self.pullout:AddItem(widget)
        end
    end,
    
    ["SetPulloutWidth"] = function(self, width)
        self.pulloutWidth = width
    end,
    
    ["SetMultiselect"] = function(self, multi)
        self.multiselect = multi
    end,
    
    ["SetItemValue"] = function(self, item, value)
        if not self.multiselect then return end
        for i, widget in self.pullout:IterateItems() do
            if widget.userdata.value == item then
                if widget.SetValue then
                    widget:SetValue(value)
                end
            end
        end
    end,
    
    ["SetItemDisabled"] = function(self, item, disabled)
        for i, widget in self.pullout:IterateItems() do
            if widget.userdata.value == item then
                widget:SetDisabled(disabled)
            end
        end
    end,
    
    ["OnWidthSet"] = function(self, width)
        -- Width handled by frame
    end,
    
    ["OnHeightSet"] = function(self, height)
        -- Height controlled by SetLabel
    end,
    
    ["RefreshColors"] = function(self)
        local r, g, b = ColorPalette:GetColor('button-bg')
        self.dropdown:SetBackdropColor(r, g, b, 1)
        r, g, b = ColorPalette:GetColor('accent-primary')
        self.dropdown:SetBackdropBorderColor(r, g, b, 1)
        self.arrow:SetVertexColor(ColorPalette:GetColor('text-secondary'))
        if self.disabled then
            self.text:SetTextColor(ColorPalette:GetColor('text-disabled'))
            self.label:SetTextColor(ColorPalette:GetColor('text-disabled'))
        else
            self.text:SetTextColor(ColorPalette:GetColor('text-primary'))
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
    
    local dropdown = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    dropdown:SetHeight(26)
    dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -18)
    dropdown:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -18)
    
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    
    local r, g, b = ColorPalette:GetColor('button-bg')
    dropdown:SetBackdropColor(r, g, b, 1)
    r, g, b = ColorPalette:GetColor('accent-primary')
    dropdown:SetBackdropBorderColor(r, g, b, 1)
    
    -- Debug: Check actual dimensions after frame update
    C_Timer.After(0.1, function()
        local width = dropdown:GetWidth()
        local height = dropdown:GetHeight()
        print(string.format("MidnightDropdown: Frame size = %.1f x %.1f", width or 0, height or 0))
        
        -- Try to force a redraw
        dropdown:SetBackdropBorderColor(r, g, b, 1)
    end)
    
    dropdown:Show()
    
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
    
    local text = dropdown:CreateFontString(nil, "ARTWORK")
    FontKit:SetFont(text, 'body', 'normal')
    text:SetTextColor(ColorPalette:GetColor('text-primary'))
    text:SetPoint("LEFT", dropdown, "LEFT", 4, 0)
    text:SetPoint("RIGHT", button, "LEFT", -2, 0)
    text:SetJustifyH("LEFT")
    
    button:SetScript("OnClick", function(self)
        local widget = self.obj
        if widget.open then
            widget.open = nil
            widget.pullout:Close()
            AceGUI:ClearFocus()
        else
            widget.open = true
            widget.pullout:SetWidth(widget.pulloutWidth or widget.frame:GetWidth())
            widget.pullout:Open("TOPLEFT", widget.frame, "BOTTOMLEFT", 0, widget.label:IsShown() and -2 or 0)
            AceGUI:SetFocus(widget)
        end
    end)
    
    button:SetScript("OnEnter", function(self)
        self.obj:Fire("OnEnter")
    end)
    
    button:SetScript("OnLeave", function(self)
        self.obj:Fire("OnLeave")
    end)
    
    frame:SetScript("OnHide", function(self)
        local widget = self.obj
        if widget.open then
            widget.pullout:Close()
        end
    end)
    
    local widget = {
        frame = frame,
        dropdown = dropdown,
        button = button,
        text = text,
        label = label,
        arrow = arrow,
        type = Type
    }
    
    for method, func in pairs(methods) do
        widget[method] = func
    end
    
    frame.obj = widget
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
