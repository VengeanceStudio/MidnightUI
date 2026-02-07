-- MidnightUI Custom TabGroup Widget
-- Replaces AceGUI TabGroup with theme-aware styling

local AceGUI = LibStub("AceGUI-3.0")
local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

-- Widget version
local Type = "MidnightTabGroup"
local Version = 1

-- ============================================================================
-- TAB BUTTON CREATION
-- ============================================================================

local function CreateTab(parent)
    local tab = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
    
    -- Set up backdrop from the start
    tab:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    
    -- Default unselected colors
    tab:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    tab:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Create text
    tab.text = tab:CreateFontString(nil, "OVERLAY")
    FontKit:SetFont(tab.text, 'button', 'normal')
    tab.text:SetTextColor(ColorPalette:GetColor('text-primary'))
    tab.text:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tab.text:SetJustifyH("CENTER")
    tab.text:SetJustifyV("MIDDLE")
    
    return tab
end

-- ============================================================================
-- WIDGET CONSTRUCTOR
-- ============================================================================

local methods = {
    ["OnAcquire"] = function(self)
        self:SetTitle()
    end,
    
    ["OnRelease"] = function(self)
        self.status = nil
        for _, tab in pairs(self.tabs) do
            tab:Hide()
        end
    end,
    
    ["SetTitle"] = function(self, title)
        self.titletext:SetText(title or "")
        if title and title ~= "" then
            self.alignoffset = 25
        else
            self.alignoffset = 18
        end
    end,
    
    ["SetStatusTable"] = function(self, status)
        assert(type(status) == "table")
        self.status = status
        if not status.groups then
            status.groups = {}
        end
    end,
    
    ["SetGroup"] = function(self, group)
        self.status.selected = group
        self:Fire("OnGroupSelected", group)
    end,
    
    ["SelectTab"] = function(self, value)
        self.status.selected = value
        self:DoLayout()
    end,
    
    ["SetTabs"] = function(self, tabs)
        self.tablist = tabs
        self:BuildTabs()
    end,
    
    ["DoLayout"] = function(self)
        local content = self.content
        local contentwidth = content:GetWidth() or 0
        local contentheight = content:GetHeight() or 0
        local tabs = self.tablist
        
        if not tabs then return end
        
        for i, v in ipairs(tabs) do
            local tab = self.tabs[v.value]
            if tab then
                if self.status and self.status.selected == v.value then
                    tab:SetBackdropColor(ColorPalette:GetColor('tab-selected-bg'))
                    tab:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
                    tab.text:SetTextColor(ColorPalette:GetColor('accent-primary'))
                    tab.selected = true
                else
                    tab:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                    tab:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
                    tab.text:SetTextColor(ColorPalette:GetColor('text-primary'))
                    tab.selected = false
                end
            end
        end
        
        -- Layout child widgets
        self:LayoutChildren(contentwidth, contentheight)
    end,
    
    ["LayoutChildren"] = function(self, width, height)
        local obj = self.obj
        if obj and obj.LayoutFinished then
            obj:LayoutFinished(width, height)
        end
    end,
    
    ["SetTitle"] = function(self, text)
        self.titletext:SetText(text or "")
        if text and text ~= "" then
            self.alignoffset = 25
        else
            self.alignoffset = 18
        end
        self:DoLayout()
    end,
    
    ["OnWidthSet"] = function(self, width)
        local content = self.content
        content:SetWidth(width - 20)
        self:DoLayout()
    end,
    
    ["OnHeightSet"] = function(self, height)
        local content = self.content
        content:SetHeight(height - 42)
        self:DoLayout()
    end,
    
    ["BuildTabs"] = function(self)
        local tabs = self.tablist
        if not tabs then return end
        
        local spacing = 2
        
        for i, v in ipairs(tabs) do
            local tab = self.tabs[v.value]
            if not tab then
                tab = CreateTab(self.border)
                self.tabs[v.value] = tab
                
                tab:SetScript("OnClick", function()
                    if not (self.status and self.status.selected == v.value) then
                        self.status.selected = v.value
                        self:Fire("OnGroupSelected", v.value)
                        self:DoLayout()
                    end
                end)
            end
            
            tab.value = v.value
            tab.text:SetText(v.text)
            
            -- Auto-size each tab based on its own text width
            local textWidth = tab.text:GetStringWidth()
            local calculatedWidth = textWidth + 32  -- 16px padding on each side
            
            tab:SetWidth(calculatedWidth)
            tab:SetHeight(24)
            
            -- Position tab
            if i == 1 then
                tab:SetPoint("TOPLEFT", self.border, "TOPLEFT", 10, -6)
            else
                local prevTab = self.tabs[tabs[i-1].value]
                tab:SetPoint("LEFT", prevTab, "RIGHT", spacing, 0)
            end
            
            tab:Show()
        end
        
        -- Select first tab by default if nothing selected
        if self.status and not self.status.selected and tabs[1] then
            self.status.selected = tabs[1].value
        end
        
        self:DoLayout()
    end,
    
    ["LayoutFinished"] = function(self, width, height)
        if self.content:GetWidth() ~= width then
            self.content:SetWidth(width)
        end
        if self.content:GetHeight() ~= height then
            self.content:SetHeight(height)
        end
    end
}

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetHeight(100)
    frame:SetWidth(100)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    
    local border = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", 0, 0)
    border:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    border:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
    border:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    local titletext = border:CreateFontString(nil, "OVERLAY")
    FontKit:SetFont(titletext, 'heading', 'normal')
    titletext:SetTextColor(ColorPalette:GetColor('text-primary'))
    titletext:SetPoint("TOPLEFT", border, "TOPLEFT", 14, -4)
    titletext:SetPoint("TOPRIGHT", border, "TOPRIGHT", -14, -4)
    titletext:SetJustifyH("LEFT")
    titletext:SetHeight(18)
    
    local content = CreateFrame("Frame", nil, border)
    content:SetPoint("TOPLEFT", border, "TOPLEFT", 10, -32)
    content:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -10, 10)
    
    local widget = {
        frame = frame,
        border = border,
        content = content,
        titletext = titletext,
        tabs = {},
        tablist = {},
        status = {
            groups = {},
            selected = nil
        },
        alignoffset = 18,
        type = Type
    }
    
    for method, func in pairs(methods) do
        widget[method] = func
    end
    
    local container = AceGUI:RegisterAsContainer(widget)
    
    -- Set up bi-directional reference for layout system
    widget.obj = container
    content.obj = container
    
    return container
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
