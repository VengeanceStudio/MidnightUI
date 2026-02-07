local AceGUI = LibStub("AceGUI-3.0")
local ColorPalette = _G.MidnightUI_ColorPalette

if not ColorPalette then return end

-- Lua APIs
local min, max, floor = math.min, math.max, math.floor
local select, pairs, ipairs = select, pairs, ipairs

-- WoW APIs
local UIParent, CreateFrame = UIParent, CreateFrame

local Type = "MidnightDropdown-Pullout"
local Version = 1

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function fixlevels(parent, ...)
    local i = 1
    local child = select(i, ...)
    while child do
        child:SetFrameLevel(parent:GetFrameLevel() + 1)
        fixlevels(child, child:GetChildren())
        i = i + 1
        child = select(i, ...)
    end
end

local function fixstrata(strata, parent, ...)
    local i = 1
    local child = select(i, ...)
    parent:SetFrameStrata(strata)
    while child do
        fixstrata(strata, child, child:GetChildren())
        i = i + 1
        child = select(i, ...)
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

local function OnEnter(item)
    local self = item.pullout
    for k, v in ipairs(self.items) do
        if v.CloseMenu and v ~= item then
            v:CloseMenu()
        end
    end
end

local function OnMouseWheel(this, value)
    this.obj:MoveScroll(value)
end

local function OnScrollValueChanged(this, value)
    this.obj:SetScroll(value)
end

local function OnSizeChanged(this)
    this.obj:FixScroll()
end

-- ============================================================================
-- METHODS
-- ============================================================================

local methods = {
    ["OnAcquire"] = function(self)
        self.frame:SetParent(UIParent)
    end,
    
    ["OnRelease"] = function(self)
        self:Clear()
        self.frame:ClearAllPoints()
        self.frame:Hide()
    end,
    
    ["SetScroll"] = function(self, value)
        local status = self.scrollStatus
        local frame, child = self.scrollFrame, self.itemFrame
        local height, viewheight = frame:GetHeight(), child:GetHeight()
        
        local offset
        if height > viewheight then
            offset = 0
        else
            offset = floor((viewheight - height) / 1000 * value)
        end
        child:ClearAllPoints()
        child:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, offset)
        child:SetPoint("TOPRIGHT", frame, "TOPRIGHT", self.slider:IsShown() and -12 or 0, offset)
        status.offset = offset
        status.scrollvalue = value
    end,
    
    ["MoveScroll"] = function(self, value)
        local status = self.scrollStatus
        local frame, child = self.scrollFrame, self.itemFrame
        local height, viewheight = frame:GetHeight(), child:GetHeight()
        
        if height > viewheight then
            self.slider:Hide()
        else
            self.slider:Show()
            local diff = height - viewheight
            local delta = 1
            if value < 0 then
                delta = -1
            end
            self.slider:SetValue(min(max(status.scrollvalue + delta * (1000 / (diff / 45)), 0), 1000))
        end
    end,
    
    ["FixScroll"] = function(self)
        local status = self.scrollStatus
        local frame, child = self.scrollFrame, self.itemFrame
        local height, viewheight = frame:GetHeight(), child:GetHeight()
        local offset = status.offset or 0
        
        if viewheight < height then
            self.slider:Hide()
            child:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, offset)
            self.slider:SetValue(0)
        else
            self.slider:Show()
            local value = (offset / (viewheight - height) * 1000)
            if value > 1000 then value = 1000 end
            self.slider:SetValue(value)
            self:SetScroll(value)
            if value < 1000 then
                child:ClearAllPoints()
                child:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, offset)
                child:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, offset)
                status.offset = offset
            end
        end
    end,
    
    ["AddItem"] = function(self, item)
        self.items[#self.items + 1] = item
        
        local h = #self.items * 16
        self.itemFrame:SetHeight(h)
        self.frame:SetHeight(min(h + 8, self.maxHeight))
        
        item.frame:SetPoint("LEFT", self.itemFrame, "LEFT")
        item.frame:SetPoint("RIGHT", self.itemFrame, "RIGHT")
        
        item:SetPullout(self)
        item:SetOnEnter(OnEnter)
    end,
    
    ["Open"] = function(self, point, relFrame, relPoint, x, y)
        local items = self.items
        local frame = self.frame
        local itemFrame = self.itemFrame
        
        frame:SetPoint(point, relFrame, relPoint, x, y)
        
        local height = 4
        for i, item in pairs(items) do
            item:SetPoint("TOP", itemFrame, "TOP", 0, -2 + (i - 1) * -16)
            item:Show()
            height = height + 16
        end
        itemFrame:SetHeight(height)
        fixstrata("TOOLTIP", frame, frame:GetChildren())
        frame:Show()
        self:Fire("OnOpen")
    end,
    
    ["Close"] = function(self)
        self.frame:Hide()
        self:Fire("OnClose")
    end,
    
    ["Clear"] = function(self)
        local items = self.items
        for i, item in pairs(items) do
            AceGUI:Release(item)
            items[i] = nil
        end
    end,
    
    ["IterateItems"] = function(self)
        return ipairs(self.items)
    end,
    
    ["SetHideOnLeave"] = function(self, val)
        self.hideOnLeave = val
    end,
    
    ["SetMaxHeight"] = function(self, height)
        self.maxHeight = height or 600
        if self.frame:GetHeight() > height then
            self.frame:SetHeight(height)
        elseif (self.itemFrame:GetHeight() + 8) < height then
            self.frame:SetHeight(self.itemFrame:GetHeight() + 8)
        end
    end,
    
    ["GetRightBorderWidth"] = function(self)
        return 3 + (self.slider:IsShown() and 12 or 0)
    end,
    
    ["GetLeftBorderWidth"] = function(self)
        return 3
    end,
    
    ["RefreshColors"] = function(self)
        local r, g, b = ColorPalette:GetColor('panel-bg')
        self.frame:SetBackdropColor(r, g, b, 1)
        r, g, b = ColorPalette:GetColor('accent-primary')
        self.frame:SetBackdropBorderColor(r, g, b, 1)
    end,
}

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "MidnightDropdownPullout" .. count, UIParent, BackdropTemplateMixin and "BackdropTemplate")
    
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    local r, g, b = ColorPalette:GetColor('panel-bg')
    frame:SetBackdropColor(r, g, b, 1)
    r, g, b = ColorPalette:GetColor('accent-primary')
    frame:SetBackdropBorderColor(r, g, b, 1)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetWidth(200)
    frame:SetHeight(600)
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", OnMouseWheel)
    scrollFrame:SetScript("OnSizeChanged", OnSizeChanged)
    scrollFrame:SetToplevel(true)
    scrollFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    
    local itemFrame = CreateFrame("Frame", nil, scrollFrame)
    itemFrame:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    itemFrame:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -12, 0)
    itemFrame:SetHeight(400)
    itemFrame:SetToplevel(true)
    itemFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    
    scrollFrame:SetScrollChild(itemFrame)
    
    local slider = CreateFrame("Slider", "MidnightDropdownPulloutScrollbar" .. count, scrollFrame, BackdropTemplateMixin and "BackdropTemplate")
    slider:SetOrientation("VERTICAL")
    slider:SetHitRectInsets(0, 0, -10, 0)
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    slider:SetWidth(8)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
    slider:SetFrameStrata("FULLSCREEN_DIALOG")
    slider:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -16, 0)
    slider:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -16, 0)
    slider:SetScript("OnValueChanged", OnScrollValueChanged)
    slider:SetMinMaxValues(0, 1000)
    slider:SetValueStep(1)
    slider:SetValue(0)
    
    scrollFrame:Show()
    itemFrame:Show()
    slider:Hide()
    
    local widget = {
        count = count,
        type = Type,
        frame = frame,
        scrollFrame = scrollFrame,
        itemFrame = itemFrame,
        slider = slider,
        items = {},
        scrollStatus = { scrollvalue = 0 },
        maxHeight = 600
    }
    
    for method, func in pairs(methods) do
        widget[method] = func
    end
    
    frame.obj = widget
    scrollFrame.obj = widget
    itemFrame.obj = widget
    slider.obj = widget
    
    widget:FixScroll()
    
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
