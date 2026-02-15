local MidnightUI = LibStub("AceAddon-3.0"):NewAddon("MidnightUI", "AceConsole-3.0", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

MidnightUI.version = "1.0.0"

-- Define reload confirmation dialog
StaticPopupDialogs["MIDNIGHTUI_RELOAD_CONFIRM"] = {
    text = "This action requires a UI reload. Reload now?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        if not InCombatLockdown() then
            C_UI.Reload()
        else
            print("|cffff0000MidnightUI:|r Cannot reload UI while in combat. Please leave combat and run /reload.")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ============================================================================
-- 1. DATABASE DEFAULTS
-- ============================================================================
local defaults = {
    profile = {
        theme = {
            active = "MidnightTransparent",  -- Active framework theme
            font = "Friz Quadrata TT",
            fontSize = 12,
            bgColor = {0.1, 0.1, 0.1, 0.8},
            borderColor = {0, 0, 0, 1},
            customThemes = {},  -- User-created themes
        },
        modules = {
            skins = true,
            bar = true,
            UIButtons = true,
            tooltips = true,
            mailbox = true,
            maps = true,
            actionbars = true,
            unitframes = true,
            cooldowns = false,
            resourceBars = true,
            castBar = true,
            tweaks = true,
            setup = true
        }
    }
}

-- ============================================================================
-- 2. INITIALIZATION
-- ============================================================================
function MidnightUI:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MidnightUIDB", defaults, true)
    
    -- Register slash commands
    self:RegisterChatCommand("mui", "SlashCommand")
    self:RegisterChatCommand("midnightui", "SlashCommand")
    self:RegisterChatCommand("muimove", "ToggleMoveMode")
    self:RegisterChatCommand("demo", "OpenDemo")
end

function MidnightUI:OnEnable()
    -- Load custom themes FIRST before validating
    self:LoadCustomThemes()
    
    -- Validate and migrate theme setting
    local ColorPalette = _G.MidnightUI_ColorPalette
    if ColorPalette and self.db.profile.theme.active then
        local currentTheme = self.db.profile.theme.active
        -- Check if the current theme exists in the palette
        if not ColorPalette.palettes[currentTheme] then
            -- Theme doesn't exist, fall back to MidnightUIDefault
            self.db.profile.theme.active = "MidnightUIDefault"
            self:Print("Previous theme not found. Switched to MidnightUI Default theme.")
        end
        -- Set the active theme in ColorPalette
        ColorPalette:SetActiveTheme(self.db.profile.theme.active)
    end
    
    -- Send the message after all modules have registered
    C_Timer.After(0.1, function()
        self:SendMessage("MIDNIGHTUI_DB_READY")
    end)
    
    -- Register options after modules load
    C_Timer.After(0.2, function()
        AceConfig:RegisterOptionsTable("MidnightUI", function() return self:GetOptions() end)
        AceConfigDialog:AddToBlizOptions("MidnightUI", "Midnight UI")
        -- Set a larger default size for the options window
        if AceConfigDialog.SetDefaultSize then
            AceConfigDialog:SetDefaultSize("MidnightUI", 1100, 800)
        end
        
        -- Hook into AceConfigDialog Open (kept for future use if needed)
        if AceConfigDialog.Open and not AceConfigDialog.MidnightOpenHooked then
            AceConfigDialog.MidnightOpenHooked = true
        end
        
        -- Hook AceGUI:Create to use our custom widgets
        local AceGUI = LibStub("AceGUI-3.0")
        if AceGUI and not AceGUI.MidnightCreateHooked then
            local originalCreate = AceGUI.Create
            AceGUI.Create = function(self, type, ...)
                -- Replace standard widgets with Midnight versions
                if type == "Slider" then
                    type = "MidnightSlider"
                elseif type == "CheckBox" then
                    type = "MidnightCheckBox"
                elseif type == "EditBox" then
                    type = "MidnightEditBox"
                elseif type == "MultiLineEditBox" then
                    type = "MidnightMultiLineEditBox"
                elseif type == "ColorPicker" then
                    type = "MidnightColorPicker"
                elseif type == "InlineGroup" then
                    type = "MidnightInlineGroup"
                elseif type == "Button" then
                    type = "MidnightButton"
                elseif type == "Dropdown" then
                    type = "MidnightDropdown"
                elseif type == "Dropdown-Pullout" then
                    type = "MidnightDropdown-Pullout"
                elseif type == "Heading" then
                    type = "MidnightHeading"
                elseif type == "TabGroup" then
                    type = "MidnightTabGroup"
                end
                local widget = originalCreate(self, type, ...)
                -- Ensure type is preserved
                if widget and type and (type == "MidnightSlider" or type == "MidnightCheckBox" or type == "MidnightEditBox" or type == "MidnightMultiLineEditBox" or type == "MidnightColorPicker" or type == "MidnightInlineGroup" or type == "MidnightButton" or type == "MidnightDropdown" or type == "MidnightDropdown-Pullout" or type == "MidnightHeading" or type == "MidnightTabGroup") then
                    widget.type = type
                end
                
                -- Style LSM widgets after creation
                if widget and type and (type == "LSM30_Font" or type == "LSM30_Statusbar" or type == "LSM30_Border" or type == "LSM30_Background" or type == "LSM30_Sound") then
                    MidnightUI:StyleLSMWidget(widget)
                end
                
                -- Style ScrollFrame widgets
                if widget and type == "ScrollFrame" then
                    MidnightUI:StyleScrollFrame(widget)
                end
                
                -- Style scrollbar in MultiLineEditBox
                if widget and type == "MidnightMultiLineEditBox" and widget.scrollBar then
                    -- Get the scroll buttons from the scrollbar (UIPanelScrollFrameTemplate creates these as global children)
                    local scrollBar = widget.scrollBar
                    local scrollBarName = scrollBar:GetName()
                    local upButton = _G[scrollBarName .. "ScrollUpButton"]
                    local downButton = _G[scrollBarName .. "ScrollDownButton"]
                    
                    -- Attach buttons as properties so StyleScrollFrame can find them
                    scrollBar.ScrollUpButton = upButton
                    scrollBar.ScrollDownButton = downButton
                    
                    -- Create a ScrollFrame-like object for our styling function
                    local scrollFrameWidget = {
                        scrollbar = scrollBar
                    }
                    MidnightUI:StyleScrollFrame(scrollFrameWidget)
                end
                
                return widget
            end
            AceGUI.MidnightCreateHooked = true
        end
        
        -- Register theme change callback to refresh widget colors
        if ColorPalette and not ColorPalette.MidnightCallbackRegistered then
            ColorPalette:RegisterCallback(function(themeName)
                -- Close and reopen config dialog to apply new theme
                if AceConfigDialog then
                    local frame = AceConfigDialog.OpenFrames["MidnightUI"]
                    if frame then
                        C_Timer.After(0.1, function()
                            AceConfigDialog:Close("MidnightUI")
                            C_Timer.After(0.1, function()
                                AceConfigDialog:Open("MidnightUI")
                            end)
                        end)
                    end
                end
            end)
            ColorPalette.MidnightCallbackRegistered = true
        end
        
        -- Hook AceConfigDialog to apply themed backdrop
        self:HookConfigDialogFrames()
    end)
    
    -- Initialize Framework
    if _G.MidnightUI_FrameFactory then
        _G.MidnightUI_FrameFactory:Initialize(self)
        
        -- Apply saved theme
        local savedTheme = self.db.profile.theme.active
        if self.FrameFactory and savedTheme then
            self.FrameFactory:SetTheme(savedTheme)
        end
    end
    
    -- Load Focus Frame if present
    if UnitFrames and UnitFrames.CreateFocusFrame then
        UnitFrames:CreateFocusFrame()
    end
end

-- Style LibSharedMedia widgets (LSM30_Font, LSM30_Statusbar, etc.)
function MidnightUI:StyleLSMWidget(widget)
    if not widget or not widget.frame then return end
    
    local frame = widget.frame
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    if not ColorPalette then return end
    
    -- Mark this widget so backdrop hooks can identify it
    widget.isLSMWidget = true
    frame.isLSMWidget = true
    
    -- Create background and border manually since frame doesn't support backdrop
    if not frame.midnightBg then
        -- Add semi-transparent dark background
        frame.midnightBg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        frame.midnightBg:SetAllPoints(frame)
        local r, g, b = ColorPalette:GetColor('button-bg')
        frame.midnightBg:SetColorTexture(r, g, b, 0.3)
    end
    
    -- Hide Blizzard textures (DLeft, DMiddle, DRight)
    if frame.DLeft then frame.DLeft:Hide() end
    if frame.DMiddle then frame.DMiddle:Hide() end
    if frame.DRight then frame.DRight:Hide() end
    
    -- Style label (the dropdown name) - FORCE white color and prevent yellow
    if frame.label then
        if FontKit then
            FontKit:SetFont(frame.label, 'body', 'normal')
        end
        
        -- Hook SetTextColor itself to block yellow (NORMAL_FONT_COLOR is yellow)
        if not frame.label.colorHooked then
            local originalSetTextColor = frame.label.SetTextColor
            frame.label.SetTextColor = function(self, r, g, b, a)
                -- If it's trying to set yellow (normal font color ~1, 0.82, 0), override to white
                if r and r > 0.9 and g and g > 0.7 and g < 0.9 and b and b < 0.1 then
                    local wr, wg, wb, wa = ColorPalette:GetColor('text-primary')
                    return originalSetTextColor(self, wr, wg, wb, wa or 1)
                end
                return originalSetTextColor(self, r, g, b, a)
            end
            frame.label.colorHooked = true
        end
        
        -- Set initial color
        local r, g, b, a = ColorPalette:GetColor('text-primary')
        frame.label:SetTextColor(r, g, b, a or 1)
    end
    
    -- Hook SetLabel to force color
    if widget.SetLabel and not widget.setLabelHooked then
        local originalSetLabel = widget.SetLabel
        widget.SetLabel = function(self, text)
            originalSetLabel(self, text)
            if self.frame and self.frame.label then
                local r, g, b, a = ColorPalette:GetColor('text-primary')
                self.frame.label:SetTextColor(r, g, b, a or 1)
            end
        end
        widget.setLabelHooked = true
    end
    
    -- Hook OnAcquire to reapply colors when widget is recycled
    if widget.OnAcquire and not widget.onAcquireHooked then
        local originalOnAcquire = widget.OnAcquire
        widget.OnAcquire = function(self)
            originalOnAcquire(self)
            C_Timer.After(0.05, function()
                if self.frame and self.frame.label then
                    local r, g, b, a = ColorPalette:GetColor('text-primary')
                    self.frame.label:SetTextColor(r, g, b, a or 1)
                end
            end)
        end
        widget.onAcquireHooked = true
    end
    
    -- Delayed reapply to catch any late color setting
    C_Timer.After(0.1, function()
        if frame.label then
            local r, g, b, a = ColorPalette:GetColor('text-primary')
            frame.label:SetTextColor(r, g, b, a or 1)
        end
    end)
    
    -- Style the selected value text
    if frame.text then
        if FontKit then
            FontKit:SetFont(frame.text, 'button', 'normal')
        end
        local r, g, b, a = ColorPalette:GetColor('text-primary')
        frame.text:SetTextColor(r, g, b, a or 1)
    end
    
    -- Style the dropdown button and create custom arrow
    if frame.dropButton then
        local btn = frame.dropButton
        btn.isLSMWidget = true
        
        -- Remove backdrop on button
        if btn.SetBackdrop then
            btn:SetBackdrop(nil)
        end
        
        -- Hide all textures on button
        for _, region in ipairs({btn:GetRegions()}) do
            if region:GetObjectType() == "Texture" then
                region:Hide()
            end
        end
        
        local normalTex = btn:GetNormalTexture()
        if normalTex then normalTex:SetTexture(nil) end
        local pushedTex = btn:GetPushedTexture()
        if pushedTex then pushedTex:SetTexture(nil) end
        local highlightTex = btn:GetHighlightTexture()
        if highlightTex then highlightTex:SetTexture(nil) end
        local disabledTex = btn:GetDisabledTexture()
        if disabledTex then disabledTex:SetTexture(nil) end
        
        -- Create custom teal arrow
        if not btn.customArrow then
            btn.customArrow = btn:CreateTexture(nil, "OVERLAY")
            btn.customArrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
            btn.customArrow:SetTexCoord(0, 1, 0, 0.5)  -- Down arrow
            btn.customArrow:SetSize(16, 16)
            btn.customArrow:SetPoint("CENTER", 0, 0)
        end
        local r, g, b = ColorPalette:GetColor('accent-primary')
        btn.customArrow:SetVertexColor(r, g, b, 1)
        btn.customArrow:Show()
        
        -- Hook the button click to style pullout after it opens
        if not btn.lsmClickHooked then
            btn:HookScript("OnClick", function()
                C_Timer.After(0.05, function()
                    local pullout = widget.pullout or widget.dropdown
                    if pullout and pullout.SetBackdrop then
                        -- Create persistent background using manual texture since backdrop gets cleared
                        if not pullout.midnightBg then
                            pullout.midnightBg = pullout:CreateTexture(nil, "BACKGROUND", nil, -8)
                            pullout.midnightBg:SetAllPoints(pullout)
                            local r, g, b = ColorPalette:GetColor('panel-bg')
                            pullout.midnightBg:SetColorTexture(r, g, b, 1)
                            
                            -- Create border textures
                            local br, bg, bb = ColorPalette:GetColor('accent-primary')
                            
                            pullout.midnightBorderTop = pullout:CreateTexture(nil, "BORDER")
                            pullout.midnightBorderTop:SetHeight(1)
                            pullout.midnightBorderTop:SetPoint("TOPLEFT")
                            pullout.midnightBorderTop:SetPoint("TOPRIGHT")
                            pullout.midnightBorderTop:SetColorTexture(br, bg, bb, 1)
                            
                            pullout.midnightBorderBottom = pullout:CreateTexture(nil, "BORDER")
                            pullout.midnightBorderBottom:SetHeight(1)
                            pullout.midnightBorderBottom:SetPoint("BOTTOMLEFT")
                            pullout.midnightBorderBottom:SetPoint("BOTTOMRIGHT")
                            pullout.midnightBorderBottom:SetColorTexture(br, bg, bb, 1)
                            
                            pullout.midnightBorderLeft = pullout:CreateTexture(nil, "BORDER")
                            pullout.midnightBorderLeft:SetWidth(1)
                            pullout.midnightBorderLeft:SetPoint("TOPLEFT")
                            pullout.midnightBorderLeft:SetPoint("BOTTOMLEFT")
                            pullout.midnightBorderLeft:SetColorTexture(br, bg, bb, 1)
                            
                            pullout.midnightBorderRight = pullout:CreateTexture(nil, "BORDER")
                            pullout.midnightBorderRight:SetWidth(1)
                            pullout.midnightBorderRight:SetPoint("TOPRIGHT")
                            pullout.midnightBorderRight:SetPoint("BOTTOMRIGHT")
                            pullout.midnightBorderRight:SetColorTexture(br, bg, bb, 1)
                        end
                        
                        -- NOW mark it so backdrop hooks skip it
                        pullout.isLSMWidget = true
                        
                        -- Style the scrollframe if it exists
                        if pullout.frame then
                            pullout.frame.isLSMWidget = true
                        end
                        
                        -- Hide Blizzard textures
                        for _, region in ipairs({pullout:GetRegions()}) do
                            if region:GetObjectType() == "Texture" then
                                region:Hide()
                            end
                        end
                        
                        -- Style all item buttons in pullout (they're in a scrollframe)
                        for _, child in ipairs({pullout:GetChildren()}) do
                            -- Check if it's a scrollframe with buttons inside
                            if child:GetObjectType() == "ScrollFrame" or child.scrollframe then
                                local scrollChild = child.scrollframe or child:GetScrollChild()
                                if scrollChild then
                                    for _, btn in ipairs({scrollChild:GetChildren()}) do
                                        if btn:GetObjectType() == "Button" or btn:GetObjectType() == "CheckButton" then
                                            btn.isLSMWidget = true
                                            
                                            -- Style item text
                                            local text = btn:GetFontString()
                                            if text and FontKit then
                                                FontKit:SetFont(text, 'body', 'normal')
                                                local r, g, b, a = ColorPalette:GetColor('text-primary')
                                                text:SetTextColor(r, g, b, a or 1)
                                            end
                                            
                                            -- Remove Blizzard backdrop
                                            if btn.SetBackdrop then
                                                btn:SetBackdrop(nil)
                                            end
                                            
                                            -- Style highlight
                                            local highlight = btn:GetHighlightTexture()
                                            if highlight then
                                                highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
                                                local r, g, b = ColorPalette:GetColor('accent-primary')
                                                highlight:SetVertexColor(r, g, b, 0.15)
                                            end
                                        end
                                    end
                                end
                            end
                            
                            -- Also check direct children in case they're not in a scrollframe
                            if child:GetObjectType() == "Button" or child:GetObjectType() == "CheckButton" then
                                child.isLSMWidget = true
                                
                                local text = child:GetFontString()
                                if text and FontKit then
                                    FontKit:SetFont(text, 'body', 'normal')
                                    local r, g, b, a = ColorPalette:GetColor('text-primary')
                                    text:SetTextColor(r, g, b, a or 1)
                                end
                                
                                if child.SetBackdrop then
                                    child:SetBackdrop(nil)
                                end
                                
                                local highlight = child:GetHighlightTexture()
                                if highlight then
                                    highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
                                    local r, g, b = ColorPalette:GetColor('accent-primary')
                                    highlight:SetVertexColor(r, g, b, 0.15)
                                end
                            end
                        end
                    end
                end)
            end)
            btn.lsmClickHooked = true
        end
    end
end

-- Style ScrollFrame widgets
function MidnightUI:StyleScrollFrame(widget)
    if not widget or not widget.scrollbar then return end
    
    local scrollbar = widget.scrollbar
    local ColorPalette = _G.MidnightUI_ColorPalette
    if not ColorPalette then return end
    
    -- Get the actual thumb texture
    local thumbTexture = scrollbar:GetThumbTexture()
    if thumbTexture then
        local r, g, b = ColorPalette:GetColor('accent-primary')
        thumbTexture:SetColorTexture(r, g, b, 1)
        thumbTexture:SetSize(12, 24)
    end
    
    -- Style the scrollbar track background
    if not scrollbar.midnightBg then
        scrollbar.midnightBg = scrollbar:CreateTexture(nil, "BACKGROUND")
        scrollbar.midnightBg:SetAllPoints(scrollbar)
        local r, g, b = ColorPalette:GetColor('button-bg')
        scrollbar.midnightBg:SetColorTexture(r, g, b, 0.3)
    end
    
    -- Hide and restyle scroll up button
    if scrollbar.ScrollUpButton then
        local upBtn = scrollbar.ScrollUpButton
        
        -- Hide all texture regions
        for _, region in pairs({upBtn:GetRegions()}) do
            if region:GetObjectType() == "Texture" and region ~= upBtn.customArrow then
                region:SetTexture(nil)
                region:Hide()
            end
        end
        
        -- Create custom up arrow
        if not upBtn.customArrow then
            upBtn.customArrow = upBtn:CreateTexture(nil, "ARTWORK")
            upBtn.customArrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
            upBtn.customArrow:SetTexCoord(0, 1, 1, 0)  -- Flip it upside down for up arrow
            upBtn.customArrow:SetSize(12, 12)
            upBtn.customArrow:SetPoint("CENTER")
            local r, g, b = ColorPalette:GetColor('accent-primary')
            upBtn.customArrow:SetVertexColor(r, g, b, 1)
            upBtn.customArrow:SetDesaturated(true)  -- Remove baked-in color
        end
        -- Always ensure the custom arrow is visible
        upBtn.customArrow:Show()
    end
    
    -- Hide and restyle scroll down button
    if scrollbar.ScrollDownButton then
        local downBtn = scrollbar.ScrollDownButton
        
        -- Hide all texture regions
        for _, region in pairs({downBtn:GetRegions()}) do
            if region:GetObjectType() == "Texture" and region ~= downBtn.customArrow then
                region:SetTexture(nil)
                region:Hide()
            end
        end
        
        -- Create custom down arrow
        if not downBtn.customArrow then
            downBtn.customArrow = downBtn:CreateTexture(nil, "ARTWORK")
            downBtn.customArrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
            downBtn.customArrow:SetSize(12, 12)
            downBtn.customArrow:SetPoint("CENTER")
            local r, g, b = ColorPalette:GetColor('accent-primary')
            downBtn.customArrow:SetVertexColor(r, g, b, 1)
            downBtn.customArrow:SetDesaturated(true)  -- Remove baked-in color
        end
        -- Always ensure the custom arrow is visible
        downBtn.customArrow:Show()
    end
end

function MidnightUI:SlashCommand(input)
    if not input or input:trim() == "" then
        self:OpenConfig()
    elseif input:lower() == "move" then
        self:ToggleMoveMode()
    else
        self:OpenConfig()
    end
end

function MidnightUI:OpenDemo()
    local demo = self:GetModule("FrameworkDemo", true)
    if demo then
        demo:Toggle()
    else
        self:Print("Framework Demo module not loaded.")
    end
end

-- ============================================================================
-- 3. UTILITY FUNCTIONS
-- ============================================================================

-- Reference resolution for default layouts (effective UI resolution at 2560x1440 with auto-scaling)
MidnightUI.REFERENCE_WIDTH = 2133
MidnightUI.REFERENCE_HEIGHT = 1200

-- Scale position from reference resolution to current resolution
function MidnightUI:ScalePosition(x, y)
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    
    local scaleX = screenWidth / self.REFERENCE_WIDTH
    local scaleY = screenHeight / self.REFERENCE_HEIGHT
    
    return x * scaleX, y * scaleY
end

-- Scale all movable frames to current resolution
function MidnightUI:ScaleLayoutToResolution()
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    
    local scaleX = screenWidth / self.REFERENCE_WIDTH
    local scaleY = screenHeight / self.REFERENCE_HEIGHT
    
    print("|cff00ff00MidnightUI:|r Scaling layout from " .. self.REFERENCE_WIDTH .. "x" .. self.REFERENCE_HEIGHT .. " to " .. math.floor(screenWidth) .. "x" .. math.floor(screenHeight))
    print("|cff00ff00Scale factors:|r X=" .. string.format("%.2f", scaleX) .. " Y=" .. string.format("%.2f", scaleY))
    
    -- Scale Bar module positions
    if _G.Bar and _G.Bar.db and _G.Bar.db.profile and _G.Bar.db.profile.bars then
        for barID, barData in pairs(_G.Bar.db.profile.bars) do
            if barData.x and barData.y then
                barData.x = math.floor(barData.x * scaleX)
                barData.y = math.floor(barData.y * scaleY)
            end
        end
    end
    
    -- Scale UIButtons position
    if _G.UIButtons and _G.UIButtons.db and _G.UIButtons.db.profile and _G.UIButtons.db.profile.position then
        local pos = _G.UIButtons.db.profile.position
        if pos.x and pos.y then
            pos.x = math.floor(pos.x * scaleX)
            pos.y = math.floor(pos.y * scaleY)
        end
    end
    
    -- Scale UnitFrames positions
    if _G.UnitFrames and _G.UnitFrames.db and _G.UnitFrames.db.profile then
        local uf = _G.UnitFrames.db.profile
        for _, frame in pairs({"player", "target", "targettarget", "focus", "pet"}) do
            if uf[frame] and uf[frame].position then
                local pos = uf[frame].position
                if pos.x and pos.y then
                    pos.x = math.floor(pos.x * scaleX)
                    pos.y = math.floor(pos.y * scaleY)
                end
            end
        end
    end
    
    -- Scale Cooldowns position
    if _G.Cooldowns and _G.Cooldowns.db and _G.Cooldowns.db.profile then
        local cd = _G.Cooldowns.db.profile
        if cd.x and cd.y then
            cd.x = math.floor(cd.x * scaleX)
            cd.y = math.floor(cd.y * scaleY)
        end
    end
    
    -- Scale Maps position
    if _G.Maps and _G.Maps.db and _G.Maps.db.profile then
        local maps = _G.Maps.db.profile
        if maps.minimap and maps.minimap.position then
            local pos = maps.minimap.position
            if pos.x and pos.y then
                pos.x = math.floor(pos.x * scaleX)
                pos.y = math.floor(pos.y * scaleY)
            end
        end
    end
    
    print("|cff00ff00MidnightUI:|r Layout scaled to your resolution!")
    StaticPopup_Show("MIDNIGHTUI_RELOAD_CONFIRM")
end

function MidnightUI:SkinAceGUIWidget(widget, widgetType)
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    if not ColorPalette then return end
    
    -- Skin based on widget type
    if widgetType == "Frame" then
        if widget.frame then
            self:SkinConfigFrame(widget.frame)
        end
        
    elseif widgetType == "TabGroup" then
        -- Check if this is our custom MidnightTabGroup (it handles its own styling)
        if widget.type == "MidnightTabGroup" then
            -- Don't apply any styling to MidnightTabGroup - it handles everything itself
            return
        end
        
        if widget.border then
            widget.border:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, edgeSize = 1,
                insets = { left = 1, right = 1, top = 26, bottom = 1 }
            })
            widget.border:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
            widget.border:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
        end
        
        -- Style the horizontal bar at the top (tab separator)
        if widget.tabs and widget.tabs[1] then
            local tabParent = widget.tabs[1]:GetParent()
            if tabParent then
                for _, region in ipairs({tabParent:GetRegions()}) do
                    if region:GetObjectType() == "Texture" then
                        -- Check if this is a thin horizontal line (separator) not a background
                        local width = region:GetWidth()
                        local height = region:GetHeight()
                        if height and height < 10 and width and width > 100 then
                            -- This is likely the horizontal separator line
                            region:SetTexture("Interface\\Buttons\\WHITE8X8")
                            region:SetVertexColor(ColorPalette:GetColor('panel-border'))
                        end
                    end
                end
            end
        end
        
        -- Skin tabs
        if widget.tabs then
            -- Function to hide Blizzard textures (defined outside loop for reuse)
            local function HideTabTextures(t)
                for _, region in ipairs({t:GetRegions()}) do
                    if region:GetObjectType() == "Texture" and region ~= t.text then
                        -- Don't hide backdrop textures (borders and background)
                        if region ~= t.Center and region ~= t.TopEdge and region ~= t.BottomEdge and 
                           region ~= t.LeftEdge and region ~= t.RightEdge and 
                           region ~= t.TopLeftCorner and region ~= t.TopRightCorner and 
                           region ~= t.BottomLeftCorner and region ~= t.BottomRightCorner then
                            region:Hide()
                        end
                    end
                end
            end
            
            for i, tab in pairs(widget.tabs) do
                
                -- Hide all Blizzard textures on tab
                HideTabTextures(tab)
                for _, region in ipairs({tab:GetRegions()}) do
                    if region:GetObjectType() == "Texture" and region ~= tab.text then
                        region:Hide()
                    end
                end
                
                -- Add BackdropTemplate if needed
                if not tab.SetBackdrop and BackdropTemplateMixin then
                    Mixin(tab, BackdropTemplateMixin)
                    if tab.OnBackdropLoaded then
                        tab:OnBackdropLoaded()
                    end
                end
                
                if tab.SetBackdrop then
                    -- Hook SetBackdrop to intercept and prevent clearing
                    if not tab.backdropHooked then
                        local originalSetBackdrop = tab.SetBackdrop
                        tab.SetBackdrop = function(self, backdrop)
                            -- Check if this is one of our custom widgets by checking the frame name or LSM flag
                            local frameName = self:GetName() or ""
                            if frameName:match("^Midnight") or self.isLSMWidget then
                                -- This is a Midnight widget or LSM widget, don't interfere
                                return originalSetBackdrop(self, backdrop)
                            end
                            
                            -- If trying to clear backdrop, apply our styled one instead
                            if not backdrop or backdrop == {} then
                                backdrop = {
                                    bgFile = "Interface\\Buttons\\WHITE8X8",
                                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                                    tile = false, edgeSize = 1,
                                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                                }
                            else
                                -- Force edgeSize to 1 for pixel-perfect borders
                                -- BUT: Skip if this is a MidnightUI custom widget (they handle their own borders)
                                if backdrop.edgeFile and backdrop.edgeSize ~= 1 then
                                    -- Check if this is one of our custom widgets by checking the frame name
                                    local frameName = self:GetName() or ""
                                    if not frameName:match("^Midnight") then
                                        backdrop.edgeSize = 1
                                        if not backdrop.insets then
                                            backdrop.insets = { left = 1, right = 1, top = 1, bottom = 1 }
                                        end
                                    end
                                end
                            end
                            originalSetBackdrop(self, backdrop)
                        end
                        
                        -- Hook SetBackdropColor to enforce our selection colors
                        local originalSetBackdropColor = tab.SetBackdropColor
                        tab.SetBackdropColor = function(self, r, g, b, a)
                            local selected = (widget.selected == self.value) or (self.selected == true)
                            if selected then
                                -- Use theme color for selected tabs
                                originalSetBackdropColor(self, ColorPalette:GetColor('tab-selected-bg'))
                            else
                                -- Allow normal color for unselected tabs
                                originalSetBackdropColor(self, r, g, b, a)
                            end
                        end
                        
                        tab.backdropHooked = true
                    end
                    
                    tab:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8",
                        tile = false, edgeSize = 1,
                        insets = { left = 1, right = 1, top = 1, bottom = 1 }
                    })
                    
                    -- Protect backdrop texture regions from being hidden
                    if not tab.backdropProtected then
                        local protectTexture = function(texture)
                            if texture and texture.Hide and not texture.originalHide then
                                texture.originalHide = texture.Hide
                                texture.Hide = function(self)
                                    -- Don't allow hiding of backdrop textures
                                    -- Only allow if parent tab is being hidden
                                    if not tab:IsShown() then
                                        texture.originalHide(self)
                                    end
                                end
                            end
                        end
                        
                        -- Protect all backdrop edge textures
                        protectTexture(tab.TopEdge)
                        protectTexture(tab.BottomEdge)
                        protectTexture(tab.LeftEdge)
                        protectTexture(tab.RightEdge)
                        protectTexture(tab.TopLeftCorner)
                        protectTexture(tab.TopRightCorner)
                        protectTexture(tab.BottomLeftCorner)
                        protectTexture(tab.BottomRightCorner)
                        
                        -- Protect background texture regions (the colored part!)
                        protectTexture(tab.Center)
                        protectTexture(tab.Bg)
                        
                        tab.backdropProtected = true
                    end
                    
                    -- Check if this tab is selected
                    local isSelected = (widget.selected == tab.value)
                    if isSelected then
                        -- Selected tab: use theme colors
                        tab:SetBackdropColor(ColorPalette:GetColor('tab-selected-bg'))
                        tab:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
                    else
                        -- Unselected tab: normal colors
                        tab:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                        tab:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
                    end
                end
                
                if tab.text and FontKit then
                    FontKit:SetFont(tab.text, 'button', 'normal')
                    -- Set text color based on selection
                    local isSelected = (widget.selected == tab.value)
                    if isSelected then
                        tab.text:SetTextColor(ColorPalette:GetColor('accent-primary'))
                    else
                        tab.text:SetTextColor(ColorPalette:GetColor('text-primary'))
                    end
                    
                    -- Auto-adjust tab width based on text width
                    if not tab.customWidthAdjusted then
                        C_Timer.After(0, function()
                            if tab.text then
                                local textWidth = tab.text:GetStringWidth()
                                local padding = 32 -- Enough padding to prevent text wrapping
                                local minWidth = textWidth + padding
                                
                                -- Get current width
                                local currentWidth = tab:GetWidth()
                                
                                -- Only increase if text is wider than current
                                if minWidth > currentWidth then
                                    tab:SetWidth(minWidth)
                                end
                            end
                        end)
                        tab.customWidthAdjusted = true
                    end
                end
                
                -- Hook tab click to update styling
                if not tab.customTabHooked then
                    tab:HookScript("OnClick", function()
                        -- Hide Blizzard textures immediately
                        for _, t in pairs(widget.tabs) do
                            HideTabTextures(t)
                        end
                        
                        -- Wait for widget.selected to update, then trigger color update
                        C_Timer.After(0.05, function()
                            for _, t in pairs(widget.tabs) do
                                HideTabTextures(t)
                                
                                -- Check both widget.selected and the tab's own selected property
                                local selected = (widget.selected == t.value) or (t.selected == true)
                                
                                -- Trigger SetBackdropColor which will be intercepted by our hook
                                if selected then
                                    t:SetBackdropColor(ColorPalette:GetColor('tab-selected-bg'))
                                    t:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
                                    if t.text then
                                        t.text:SetTextColor(ColorPalette:GetColor('accent-primary'))
                                    end
                                else
                                    t:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                                    t:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
                                    if t.text then
                                        t.text:SetTextColor(ColorPalette:GetColor('text-primary'))
                                    end
                                end
                            end
                        end)
                    end)
                    
                    -- Also hook OnShow to prevent textures from reappearing and reapply styling
                    tab:HookScript("OnShow", function()
                        HideTabTextures(tab)
                        
                        -- Reapply backdrop and colors when tab is shown
                        if not tab.backdropReapplied then
                            tab:SetBackdrop({
                                bgFile = "Interface\\Buttons\\WHITE8X8",
                                edgeFile = "Interface\\Buttons\\WHITE8X8",
                                tile = false, edgeSize = 1,
                                insets = { left = 1, right = 1, top = 1, bottom = 1 }
                            })
                            
                            -- Reapply colors based on selection state
                            local selected = (widget.selected == tab.value) or (tab.selected == true)
                            if selected then
                                tab:SetBackdropColor(ColorPalette:GetColor('tab-selected-bg'))
                                tab:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
                            else
                                tab:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                                tab:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
                            end
                            
                            tab.backdropReapplied = true
                            -- Reset flag after a moment to allow future reapplications
                            C_Timer.After(0.5, function()
                                tab.backdropReapplied = false
                            end)
                        end
                    end)
                    
                    tab.customTabHooked = true
                end
            end
            
            -- Delayed check to ensure initial selected tab gets correct styling
            if not widget.customInitialSelectionApplied then
                C_Timer.After(0.1, function()
                    if widget.tabs then
                        for _, t in pairs(widget.tabs) do
                            local selected = (widget.selected == t.value) or (t.selected == true)
                            if selected then
                                t:SetBackdropColor(ColorPalette:GetColor('tab-selected-bg'))
                                t:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
                                if t.text then
                                    t.text:SetTextColor(ColorPalette:GetColor('accent-primary'))
                                end
                            end
                        end
                    end
                end)
                widget.customInitialSelectionApplied = true
            end
            
            -- Hook TabGroup frame OnShow to restore all tab backdrops
            if widget.frame and not widget.customTabGroupOnShow then
                widget.frame:HookScript("OnShow", function()
                    C_Timer.After(0, function()
                        if widget.tabs then
                            for _, t in pairs(widget.tabs) do
                                -- Force backdrop reapplication
                                if t.SetBackdrop then
                                    t:SetBackdrop({
                                        bgFile = "Interface\\Buttons\\WHITE8X8",
                                        edgeFile = "Interface\\Buttons\\WHITE8X8",
                                        tile = false, edgeSize = 1,
                                        insets = { left = 1, right = 1, top = 1, bottom = 1 }
                                    })
                                    
                                    -- Force show all backdrop textures
                                    if t.Center then t.Center:Show() end
                                    if t.TopEdge then t.TopEdge:Show() end
                                    if t.BottomEdge then t.BottomEdge:Show() end
                                    if t.LeftEdge then t.LeftEdge:Show() end
                                    if t.RightEdge then t.RightEdge:Show() end
                                    if t.TopLeftCorner then t.TopLeftCorner:Show() end
                                    if t.TopRightCorner then t.TopRightCorner:Show() end
                                    if t.BottomLeftCorner then t.BottomLeftCorner:Show() end
                                    if t.BottomRightCorner then t.BottomRightCorner:Show() end
                                    
                                    -- Reapply colors
                                    local selected = (widget.selected == t.value) or (t.selected == true)
                                    if selected then
                                        t:SetBackdropColor(ColorPalette:GetColor('tab-selected-bg'))
                                        t:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
                                        if t.text then
                                            t.text:SetTextColor(ColorPalette:GetColor('accent-primary'))
                                        end
                                    else
                                        t:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                                        t:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
                                        if t.text then
                                            t.text:SetTextColor(ColorPalette:GetColor('text-primary'))
                                        end
                                    end
                                    
                                    HideTabTextures(t)
                                end
                            end
                        end
                    end)
                end)
                widget.customTabGroupOnShow = true
            end
        end
        
    elseif widgetType == "InlineGroup" or widgetType == "SimpleGroup" or widgetType == "TreeGroup" then
        if widget.content and widget.content:GetObjectType() == "Frame" then
            if widget.content.SetBackdrop then
                widget.content:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, edgeSize = 2,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 }
                })
                widget.content:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
                widget.content:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
            end
        end
        
        -- Style TreeGroup specifically
        if widgetType == "TreeGroup" then
            -- Hide all Blizzard border textures
            if widget.border then
                for _, region in ipairs({widget.border:GetRegions()}) do
                    if region:GetObjectType() == "Texture" then
                        region:Hide()
                    end
                end
            end
            
            -- Style the tree frame (vertical navigation)
            if widget.treeframe then
                -- Add BackdropTemplate if needed
                if not widget.treeframe.SetBackdrop and BackdropTemplateMixin then
                    Mixin(widget.treeframe, BackdropTemplateMixin)
                    if widget.treeframe.OnBackdropLoaded then
                        widget.treeframe:OnBackdropLoaded()
                    end
                end
                
                -- Apply themed backdrop to tree navigation
                if widget.treeframe.SetBackdrop then
                    widget.treeframe:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8",
                        tile = false, edgeSize = 2,
                        insets = { left = 2, right = 2, top = 2, bottom = 2 }
                    })
                    widget.treeframe:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
                    widget.treeframe:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
                end
                
                -- Hide Blizzard textures in tree frame
                for _, region in ipairs({widget.treeframe:GetRegions()}) do
                    if region:GetObjectType() == "Texture" then
                        region:Hide()
                    end
                end
                
                -- Position tree frame below logo
                widget.treeframe:ClearAllPoints()
                widget.treeframe:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 6, -76)
                widget.treeframe:SetPoint("BOTTOMLEFT", widget.frame, "BOTTOMLEFT", 6, 6)
                
                -- Create visible border overlays for TreeGroup
                if not widget.customBorders then
                    -- Vertical border between tree list and content
                    local verticalBorder = widget.frame:CreateTexture(nil, "OVERLAY")
                    verticalBorder:SetColorTexture(ColorPalette:GetColor('panel-border'))
                    verticalBorder:SetWidth(2)
                    verticalBorder:SetPoint("TOPLEFT", widget.treeframe, "TOPRIGHT", 0, 0)
                    verticalBorder:SetPoint("BOTTOMLEFT", widget.treeframe, "BOTTOMRIGHT", 0, 0)
                    
                    -- Horizontal border at top of content
                    local horizontalBorder = widget.frame:CreateTexture(nil, "OVERLAY")
                    horizontalBorder:SetColorTexture(ColorPalette:GetColor('panel-border'))
                    horizontalBorder:SetHeight(2)
                    horizontalBorder:SetPoint("TOPLEFT", widget.border or widget.content, "TOPLEFT", 0, 0)
                    horizontalBorder:SetPoint("TOPRIGHT", widget.border or widget.content, "TOPRIGHT", 0, 0)
                    
                    widget.customBorders = {verticalBorder, horizontalBorder}
                end
                
                -- Style tree buttons (navigation items)
                if not widget.treeButtonsStyled then
                    -- Store reference to widget for button click handling
                    local treeWidget = widget
                    
                    -- Hook to style buttons as they're created/shown
                    hooksecurefunc(widget, "RefreshTree", function()
                        if widget.buttons then
                            for _, button in pairs(widget.buttons) do
                                if button and not button.customStyled then
                                    -- Hide Blizzard textures
                                    if button.toggle then
                                        button.toggle:SetNormalTexture("")
                                        button.toggle:SetPushedTexture("")
                                        button.toggle:SetHighlightTexture("")
                                    end
                                    
                                    -- Hide all button textures
                                    for _, region in ipairs({button:GetRegions()}) do
                                        if region:GetObjectType() == "Texture" and region ~= button.icon then
                                            region:Hide()
                                        end
                                    end
                                    
                                    -- Add BackdropTemplate if needed
                                    if not button.SetBackdrop and BackdropTemplateMixin then
                                        Mixin(button, BackdropTemplateMixin)
                                        if button.OnBackdropLoaded then
                                            button:OnBackdropLoaded()
                                        end
                                    end
                                    
                                    -- Apply themed backdrop
                                    if button.SetBackdrop then
                                        button:SetBackdrop({
                                            bgFile = "Interface\\Buttons\\WHITE8X8",
                                            edgeFile = "Interface\\Buttons\\WHITE8X8",
                                            tile = false, edgeSize = 1,
                                            insets = { left = 1, right = 1, top = 1, bottom = 1 }
                                        })
                                        button:SetBackdropColor(0, 0, 0, 0)
                                        button:SetBackdropBorderColor(0, 0, 0, 0)
                                    end
                                    
                                    -- Style text
                                    if button.text then
                                        if FontKit then
                                            FontKit:SetFont(button.text, 'body', 'normal')
                                        end
                                        button.text:SetTextColor(ColorPalette:GetColor('text-primary'))
                                    end
                                    
                                    -- Hover effect - subtle and modern
                                    button:HookScript("OnEnter", function(self)
                                        if button.SetBackdropColor then
                                            -- Very subtle teal glow on hover, no border
                                            local r, g, b = ColorPalette:GetColor('accent-primary')
                                            button:SetBackdropColor(r, g, b, 0.15)
                                            button:SetBackdropBorderColor(0, 0, 0, 0)
                                        end
                                    end)
                                    button:HookScript("OnLeave", function(self)
                                        if button.SetBackdropColor then
                                            -- Clear background on leave
                                            button:SetBackdropColor(0, 0, 0, 0)
                                            button:SetBackdropBorderColor(0, 0, 0, 0)
                                        end
                                    end)
                                    
                                    -- Hook button click to update all button colors
                                    button:HookScript("OnClick", function(self)
                                        C_Timer.After(0.05, function()
                                            -- Update all buttons in the tree
                                            if treeWidget.buttons then
                                                for _, btn in pairs(treeWidget.buttons) do
                                                    if btn and btn.text then
                                                        if btn.selected then
                                                            -- Use theme accent color for selected item
                                                            btn.text:SetTextColor(ColorPalette:GetColor('accent-primary'))
                                                        else
                                                            -- Normal white/gray text for non-selected items
                                                            btn.text:SetTextColor(ColorPalette:GetColor('text-primary'))
                                                        end
                                                    end
                                                end
                                            end
                                        end)
                                    end)
                                    
                                    -- Apply color immediately if already selected
                                    if button.selected and button.text then
                                        button.text:SetTextColor(ColorPalette:GetColor('accent-primary'))
                                    end
                                    
                                    button.customStyled = true
                                end
                            end
                        end
                    end)
                    widget.treeButtonsStyled = true
                end
            end
            
            -- Style the content area border
            if widget.border then
                if not widget.border.SetBackdrop and BackdropTemplateMixin then
                    Mixin(widget.border, BackdropTemplateMixin)
                    if widget.border.OnBackdropLoaded then
                        widget.border:OnBackdropLoaded()
                    end
                end
                
                if widget.border.SetBackdrop then
                    widget.border:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8",
                        tile = false, edgeSize = 1,
                        insets = { left = 1, right = 1, top = 1, bottom = 1 }
                    })
                    widget.border:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
                    widget.border:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
                end
            end
        end
        
    elseif widgetType == "Button" then
        if widget.frame then
            -- Move button to the right and down slightly to avoid label overlap
            if not widget.customButtonMoved then
                local point, relativeTo, relativePoint, xOfs, yOfs = widget.frame:GetPoint()
                if point and xOfs and yOfs then
                    widget.frame:ClearAllPoints()
                    widget.frame:SetPoint(point, relativeTo, relativePoint, xOfs + 20, yOfs - 15)
                    widget.customButtonMoved = true
                end
            end
            
            -- Ensure frame has BackdropTemplate
            if not widget.frame.SetBackdrop and BackdropTemplateMixin then
                Mixin(widget.frame, BackdropTemplateMixin)
                if widget.frame.OnBackdropLoaded then
                    widget.frame:OnBackdropLoaded()
                end
            end
            
            -- Hide Blizzard textures
            if widget.frame.Left then widget.frame.Left:Hide() end
            if widget.frame.Right then widget.frame.Right:Hide() end
            if widget.frame.Middle then widget.frame.Middle:Hide() end
            if widget.frame.SetNormalTexture then widget.frame:SetNormalTexture("") end
            if widget.frame.SetHighlightTexture then 
                widget.frame:SetHighlightTexture("")
                -- Remove the highlight texture entirely
                local highlight = widget.frame:GetHighlightTexture()
                if highlight then
                    highlight:SetTexture(nil)
                    highlight:SetAlpha(0)
                end
            end
            if widget.frame.SetPushedTexture then widget.frame:SetPushedTexture("") end
            if widget.frame.SetDisabledTexture then widget.frame:SetDisabledTexture("") end
            
            -- Apply themed backdrop
            if widget.frame.SetBackdrop and not widget.customButtonSkinned then
                widget.frame:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                widget.frame:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                widget.frame:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
                
                -- Create custom hover effect
                widget.frame:HookScript("OnEnter", function(self)
                    if widget.frame.SetBackdropColor then
                        local r, g, b, a = ColorPalette:GetColor('button-bg')
                        r = math.min((r * 2) + 0.15, 1)
                        g = math.min((g * 2) + 0.15, 1)
                        b = math.min((b * 2) + 0.15, 1)
                        widget.frame:SetBackdropColor(r, g, b, a)
                    end
                    if widget.frame.SetBackdropBorderColor then
                        widget.frame:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
                    end
                end)
                widget.frame:HookScript("OnLeave", function(self)
                    if widget.frame.SetBackdropColor then
                        widget.frame:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                    end
                    if widget.frame.SetBackdropBorderColor then
                        widget.frame:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
                    end
                end)
                
                widget.customButtonSkinned = true
            end
        end
        
        if widget.text and FontKit then
            FontKit:SetFont(widget.text, 'button', 'normal')
            widget.text:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
        
    elseif widgetType == "CheckBox" then
        -- Increase the overall frame height to add spacing and prevent label overlap
        if widget.frame and not widget.customFrameHeight then
            local currentHeight = widget.frame:GetHeight()
            if currentHeight then
                widget.frame:SetHeight(currentHeight + 10)
            end
            widget.customFrameHeight = true
        end
        
        if widget.frame then
            -- Hide original checkbox elements
            if widget.checkbg then widget.checkbg:Hide() end
            if widget.highlight then widget.highlight:Hide() end
            if widget.check then widget.check:Hide() end
            for _, region in ipairs({widget.frame:GetRegions()}) do
                if region:GetObjectType() == "Texture" and region ~= widget.toggleBg and region ~= widget.toggleBorder and region ~= widget.toggleKnob then
                    region:SetTexture(nil)
                    region:Hide()
                end
            end
            
            -- Adjust text position to make room for toggle slider
            if widget.text then
                widget.text:ClearAllPoints()
                widget.text:SetPoint("LEFT", widget.frame, "LEFT", 50, 0)
                widget.text:SetPoint("RIGHT", widget.frame, "RIGHT", -10, 0)
                widget.text:SetWordWrap(true)
                widget.text:SetJustifyH("LEFT")
            end
            
            -- Create toggle slider background
            if not widget.toggleBg then
                widget.toggleBg = widget.frame:CreateTexture(nil, "BACKGROUND")
                widget.toggleBg:SetSize(40, 20)
                widget.toggleBg:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 4, -4)
                widget.toggleBg:SetTexture("Interface\\Buttons\\WHITE8X8")
                widget.toggleBg:SetDrawLayer("ARTWORK")
                widget.toggleBg:SetAlpha(1)
                -- Very dark off state - near black
                widget.toggleBg:SetVertexColor(0.02, 0.02, 0.02, 1)
                
                -- Add border
                widget.toggleBorder = widget.frame:CreateTexture(nil, "BORDER")
                widget.toggleBorder:SetSize(42, 22)
                widget.toggleBorder:SetPoint("CENTER", widget.toggleBg, "CENTER")
                widget.toggleBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
                widget.toggleBorder:SetVertexColor(ColorPalette:GetColor('panel-border'))
                
                -- Create slider knob
                widget.toggleKnob = widget.frame:CreateTexture(nil, "OVERLAY")
                widget.toggleKnob:SetSize(16, 16)
                widget.toggleKnob:SetTexture("Interface\\Buttons\\WHITE8X8")
                widget.toggleKnob:SetVertexColor(ColorPalette:GetColor('text-primary'))
            end
            
            -- Hook to animate toggle
            if not widget.customCheckHooked then
                hooksecurefunc(widget, "SetValue", function(self, value)
                    if widget.toggleKnob and widget.toggleBg then
                        if value then
                            widget.toggleKnob:SetPoint("CENTER", widget.toggleBg, "CENTER", 10, 0)
                            widget.toggleBg:SetVertexColor(ColorPalette:GetColor('accent-primary'))
                        else
                            widget.toggleKnob:SetPoint("CENTER", widget.toggleBg, "CENTER", -10, 0)
                            -- Very dark off state - near black
                            widget.toggleBg:SetVertexColor(0.02, 0.02, 0.02, 1)
                        end
                    end
                end)
                widget.customCheckHooked = true
                
                -- Set initial state
                if widget.checked then
                    widget.toggleKnob:SetPoint("CENTER", widget.toggleBg, "CENTER", 10, 0)
                    widget.toggleBg:SetVertexColor(ColorPalette:GetColor('accent-primary'))
                else
                    widget.toggleKnob:SetPoint("CENTER", widget.toggleBg, "CENTER", -10, 0)
                    widget.toggleBg:SetVertexColor(0.02, 0.02, 0.02, 1)
                end
            end
        end
        
        if widget.text and FontKit then
            FontKit:SetFont(widget.text, 'body', 'normal')
            widget.text:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
        
    elseif widgetType == "Slider" then
        -- Increase the overall frame height significantly to add spacing
        if widget.frame and not widget.customFrameHeight then
            local currentHeight = widget.frame:GetHeight()
            if currentHeight then
                widget.frame:SetHeight(currentHeight + 40)
            end
            widget.customFrameHeight = true
        end
        
        if widget.slider then
            -- Style the slider track - make it thinner
            if widget.slider.SetBackdrop then
                widget.slider:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, edgeSize = 1,
                    insets = { left = 0, right = 0, top = 0, bottom = 0 }
                })
                -- Use theme accent color for the slider bar
                local r, g, b, a = ColorPalette:GetColor('accent-primary')
                widget.slider:SetBackdropColor(r, g, b, 0.5)
                widget.slider:SetBackdropBorderColor(r, g, b, 1)
            end
            
            -- Make the slider track thinner
            local height = widget.slider:GetHeight()
            if height and height > 8 then
                widget.slider:SetHeight(4)
            end
            
            -- Style the thumb - make it smaller
            widget.slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
            local thumb = widget.slider:GetThumbTexture()
            if thumb then
                thumb:SetVertexColor(ColorPalette:GetColor('text-primary'))
                thumb:SetSize(6, 10)
            end
            
            -- Add vertical spacing by moving the slider down from the label
            if not widget.customSliderSpacing then
                C_Timer.After(0.05, function()
                    if widget.slider and widget.label then
                        widget.slider:ClearAllPoints()
                        widget.slider:SetPoint("TOPLEFT", widget.label, "BOTTOMLEFT", 10, -8)
                        widget.slider:SetPoint("TOPRIGHT", widget.label, "BOTTOMRIGHT", -10, -8)
                    end
                end)
                widget.customSliderSpacing = true
            end
        end
        
        if widget.label and FontKit then
            FontKit:SetFont(widget.label, 'body', 'normal')
            widget.label:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
        
        -- Add spacing for the editbox below the slider
        if widget.editbox and not widget.customEditBoxSpacing then
            -- Remove Blizzard textures from slider editbox
            if widget.editbox.Left then widget.editbox.Left:Hide() end
            if widget.editbox.Right then widget.editbox.Right:Hide() end
            if widget.editbox.Middle then widget.editbox.Middle:Hide() end
            
            -- Style the slider editbox
            if widget.editbox.SetBackdrop then
                widget.editbox:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, edgeSize = 1,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 }
                })
                -- Use theme background color
                widget.editbox:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                widget.editbox:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
            end
            
            if FontKit then
                -- Get the font from FontKit and apply with smaller size
                local fontData = FontKit.fonts['body']
                if fontData and fontData.path then
                    widget.editbox:SetFont(fontData.path, 10, "OUTLINE")
                end
                widget.editbox:SetTextColor(ColorPalette:GetColor('text-primary'))
            end
            
            C_Timer.After(0.05, function()
                if widget.editbox and widget.slider then
                    widget.editbox:ClearAllPoints()
                    widget.editbox:SetPoint("TOP", widget.slider, "BOTTOM", 0, -8)
                end
            end)
            widget.customEditBoxSpacing = true
        end
        
    elseif widgetType == "EditBox" or widgetType == "MultiLineEditBox" then
        if widget.editbox then
            -- Remove Blizzard textures
            if widget.editbox.Left then widget.editbox.Left:Hide() end
            if widget.editbox.Right then widget.editbox.Right:Hide() end
            if widget.editbox.Middle then widget.editbox.Middle:Hide() end
            
            if widget.editbox.SetBackdrop then
                widget.editbox:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, edgeSize = 1,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 }
                })
                widget.editbox:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                widget.editbox:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
            end
            
            if FontKit then
                FontKit:SetFont(widget.editbox, 'body', 'normal')
                widget.editbox:SetTextColor(ColorPalette:GetColor('text-primary'))
            end
        end
        
        if widget.label and FontKit then
            FontKit:SetFont(widget.label, 'body', 'normal')
            widget.label:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
        
    elseif widgetType == "Dropdown" then
        if widget.frame then
            -- Move dropdown frame to the right to prevent border/label cutoff
            local point, relativeTo, relativePoint, xOfs, yOfs = widget.frame:GetPoint()
            if point and xOfs and yOfs then
                widget.frame:ClearAllPoints()
                widget.frame:SetPoint(point, relativeTo, relativePoint, xOfs + 20, yOfs)
            end
        end
        
        -- Move label up and adjust horizontal position
        if widget.label and not widget.customLabelMoved then
            local point, relativeTo, relativePoint, xOfs, yOfs = widget.label:GetPoint()
            if point and xOfs and yOfs then
                widget.label:ClearAllPoints()
                widget.label:SetPoint(point, relativeTo, relativePoint, xOfs - 10, yOfs + 4)
                widget.customLabelMoved = true
            end
        end
        
        if widget.dropdown then
            -- Skip if this is a MidnightUI custom dropdown widget
            local dropdownName = widget.dropdown:GetName() or ""
            if not dropdownName:match("^Midnight") then
                -- Not a Midnight widget, apply standard dropdown styling
            
                -- Ensure dropdown has BackdropTemplate
                if not widget.dropdown.SetBackdrop and BackdropTemplateMixin then
                Mixin(widget.dropdown, BackdropTemplateMixin)
                if widget.dropdown.OnBackdropLoaded then
                    widget.dropdown:OnBackdropLoaded()
                end
            end
            
            -- Hide all Blizzard dropdown frame elements
            for _, region in ipairs({widget.dropdown:GetRegions()}) do
                if region:GetObjectType() == "Texture" then
                    region:Hide()
                end
            end
            
            -- Apply themed backdrop
            if widget.dropdown.SetBackdrop then
                -- Hook SetBackdrop to intercept and prevent clearing
                if not widget.dropdown.backdropHooked then
                    local originalSetBackdrop = widget.dropdown.SetBackdrop
                    widget.dropdown.SetBackdrop = function(self, backdrop)
                        -- Check if this is one of our custom widgets by checking the frame name or LSM flag
                        local frameName = self:GetName() or ""
                        if frameName:match("^Midnight") or self.isLSMWidget then
                            -- This is a Midnight widget or LSM widget, don't interfere
                            return originalSetBackdrop(self, backdrop)
                        end
                        
                        -- If trying to clear backdrop, apply our styled one instead
                        if not backdrop or backdrop == {} then
                            backdrop = {
                                bgFile = "Interface\\Buttons\\WHITE8X8",
                                edgeFile = "Interface\\Buttons\\WHITE8X8",
                                tile = false, edgeSize = 1,
                                insets = { left = 1, right = 1, top = 1, bottom = 1 }
                            }
                        else
                            -- Force edgeSize to 1 for pixel-perfect borders
                            -- BUT: Skip if this is a MidnightUI custom widget (they handle their own borders)
                            if backdrop.edgeFile and backdrop.edgeSize ~= 1 then
                                -- Check if this is one of our custom widgets by checking the frame name
                                local frameName = self:GetName() or ""
                                if not frameName:match("^Midnight") then
                                    backdrop.edgeSize = 1
                                    if not backdrop.insets then
                                        backdrop.insets = { left = 1, right = 1, top = 1, bottom = 1 }
                                    end
                                end
                            end
                        end
                        originalSetBackdrop(self, backdrop)
                        
                        -- Reapply colors immediately after backdrop change
                        self:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                        self:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
                    end
                    widget.dropdown.backdropHooked = true
                end
                
                widget.dropdown:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                widget.dropdown:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                widget.dropdown:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
                
                -- Protect dropdown backdrop texture regions from being hidden
                if not widget.dropdown.backdropProtected then
                    local protectTexture = function(texture)
                        if texture and texture.Hide and not texture.originalHide then
                            texture.originalHide = texture.Hide
                            texture.Hide = function(self)
                                -- Don't allow hiding unless parent is being hidden
                                if not widget.dropdown:IsShown() then
                                    texture.originalHide(self)
                                end
                            end
                        end
                    end
                    
                    protectTexture(widget.dropdown.TopEdge)
                    protectTexture(widget.dropdown.BottomEdge)
                    protectTexture(widget.dropdown.LeftEdge)
                    protectTexture(widget.dropdown.RightEdge)
                    protectTexture(widget.dropdown.TopLeftCorner)
                    protectTexture(widget.dropdown.TopRightCorner)
                    protectTexture(widget.dropdown.BottomLeftCorner)
                    protectTexture(widget.dropdown.BottomRightCorner)
                    
                    widget.dropdown.backdropProtected = true
                end
            end
            
            -- Style the dropdown button
            if widget.button then
                -- Reposition button to align with dropdown right edge (inside the border)
                widget.button:ClearAllPoints()
                widget.button:SetPoint("TOPRIGHT", widget.dropdown, "TOPRIGHT", -2, -2)
                widget.button:SetPoint("BOTTOMRIGHT", widget.dropdown, "BOTTOMRIGHT", -2, 2)
                widget.button:SetWidth(18)
                
                -- Ensure button has BackdropTemplate
                if not widget.button.SetBackdrop and BackdropTemplateMixin then
                    Mixin(widget.button, BackdropTemplateMixin)
                    if widget.button.OnBackdropLoaded then
                        widget.button:OnBackdropLoaded()
                    end
                end
                
                -- Hide all button textures
                for _, region in ipairs({widget.button:GetRegions()}) do
                    if region:GetObjectType() == "Texture" then
                        region:Hide()
                    end
                end
                
                -- Clear texture methods
                if widget.button.SetNormalTexture then widget.button:SetNormalTexture("") end
                if widget.button.SetHighlightTexture then widget.button:SetHighlightTexture("") end
                if widget.button.SetPushedTexture then widget.button:SetPushedTexture("") end
                if widget.button.SetDisabledTexture then widget.button:SetDisabledTexture("") end
                if widget.button.Middle then widget.button.Middle:Hide() end
                if widget.button.Right then widget.button.Right:Hide() end
                
                -- Apply backdrop to button itself
                if widget.button.SetBackdrop then
                    widget.button:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8",
                        tile = false, edgeSize = 1,
                        insets = { left = 1, right = 1, top = 1, bottom = 1 }
                    })
                    widget.button:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                    widget.button:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
                end
                
                -- Create custom dropdown arrow
                if widget.customArrow and widget.customArrow.SetText then
                    widget.customArrow:Hide()
                    widget.customArrow = nil
                end
                if not widget.customArrow then
                    widget.customArrow = widget.button:CreateTexture(nil, "OVERLAY")
                    widget.customArrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
                    widget.customArrow:SetSize(10, 10)
                    widget.customArrow:SetPoint("CENTER")
                    widget.customArrow:SetRotation(-1.57)
                    widget.customArrow:SetVertexColor(ColorPalette:GetColor('text-secondary'))
                end
                
                -- Hook to prevent textures from reappearing
                if not widget.customButtonTextureHook then
                    local function ClearButtonTextures()
                        for _, region in ipairs({widget.button:GetRegions()}) do
                            if region:GetObjectType() == "Texture" and region ~= widget.customArrow then
                                region:SetTexture(nil)
                                region:Hide()
                            end
                        end
                        if widget.button.SetNormalTexture then widget.button:SetNormalTexture("") end
                        if widget.button.SetHighlightTexture then widget.button:SetHighlightTexture("") end
                        if widget.button.SetPushedTexture then widget.button:SetPushedTexture("") end
                        if widget.button.SetDisabledTexture then widget.button:SetDisabledTexture("") end
                    end
                    
                    widget.button:HookScript("OnClick", ClearButtonTextures)
                    widget.button:HookScript("OnShow", function()
                        ClearButtonTextures()
                        if widget.customArrow then
                            widget.customArrow:Show()
                            widget.customArrow:SetAlpha(1)
                        end
                    end)
                    widget.button:HookScript("OnUpdate", function()
                        if widget.customArrow and not widget.customArrow:IsShown() then
                            widget.customArrow:Show()
                            widget.customArrow:SetAlpha(1)
                        end
                    end)
                    widget.customButtonTextureHook = true
                end
            end
            
            -- Hook to restore styling after tab switches
            if not widget.customDropdownShowHook then
                widget.dropdown:HookScript("OnShow", function()
                    -- Hide Blizzard textures again
                    for _, region in ipairs({widget.dropdown:GetRegions()}) do
                        if region:GetObjectType() == "Texture" then
                            region:Hide()
                        end
                    end
                    
                    -- Reapply full backdrop
                    if widget.dropdown.SetBackdrop then
                        widget.dropdown:SetBackdrop({
                            bgFile = "Interface\\Buttons\\WHITE8X8",
                            edgeFile = "Interface\\Buttons\\WHITE8X8",
                            tile = false, edgeSize = 1,
                            insets = { left = 1, right = 1, top = 1, bottom = 1 }
                        })
                        widget.dropdown:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                        widget.dropdown:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
                    end
                    
                    -- Ensure button and arrow are visible
                    if widget.button then
                        widget.button:Show()
                        if widget.customArrow then
                            widget.customArrow:Show()
                        end
                        -- Reposition button
                        widget.button:ClearAllPoints()
                        widget.button:SetPoint("TOPRIGHT", widget.dropdown, "TOPRIGHT", -2, -2)
                        widget.button:SetPoint("BOTTOMRIGHT", widget.dropdown, "BOTTOMRIGHT", -2, 2)
                    end
                end)
                widget.customDropdownShowHook = true
            end
            end -- end of "not Midnight" check
        end

        -- Hook to skin the dropdown pullout list when it opens
        if not widget.customPulloutSetup then
            local originalOpen = widget.Open
            if originalOpen then
                widget.Open = function(self)
                    originalOpen(self)
                    
                    -- Now skin the pullout that was just created
                    if self.pullout and self.pullout.frame then
                        local frame = self.pullout.frame
                        local scrollFrame = self.pullout.scrollFrame
                        
                        -- Apply backdrop to scrollFrame for better visibility
                        if scrollFrame and not scrollFrame.customSkinned then
                            if not scrollFrame.SetBackdrop and BackdropTemplateMixin then
                                Mixin(scrollFrame, BackdropTemplateMixin)
                                if scrollFrame.OnBackdropLoaded then
                                    scrollFrame:OnBackdropLoaded()
                                end
                            end
                            
                            if scrollFrame.SetBackdrop then
                                scrollFrame:SetBackdrop({
                                    bgFile = "Interface\\Buttons\\WHITE8X8",
                                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                                    tile = false, edgeSize = 1,
                                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                                })
                                scrollFrame:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
                                scrollFrame:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
                            end
                            scrollFrame.customSkinned = true
                        end
                        
                        -- Also apply to main frame
                        if not frame.customSkinned then
                            if not frame.SetBackdrop and BackdropTemplateMixin then
                                Mixin(frame, BackdropTemplateMixin)
                                if frame.OnBackdropLoaded then
                                    frame:OnBackdropLoaded()
                                end
                            end
                            
                            -- Hide all frame textures and children textures
                            for _, region in ipairs({frame:GetRegions()}) do
                                if region:GetObjectType() == "Texture" then
                                    region:SetTexture(nil)
                                    region:Hide()
                                    region:SetAlpha(0)
                                end
                            end
                            
                            -- Hide textures in all child frames
                            local children = {frame:GetChildren()}
                            for _, child in ipairs(children) do
                                if child ~= scrollFrame then
                                    for _, region in ipairs({child:GetRegions()}) do
                                        if region:GetObjectType() == "Texture" then
                                            region:SetTexture(nil)
                                            region:Hide()
                                            region:SetAlpha(0)
                                        end
                                    end
                                end
                            end
                            
                            if frame.SetBackdrop then
                                frame:SetBackdrop({
                                    bgFile = "Interface\\Buttons\\WHITE8X8",
                                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                                    tile = false, edgeSize = 1,
                                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                                })
                                frame:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
                                frame:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
                            end
                            frame.customSkinned = true
                        end
                        
                        -- Skin individual pullout items
                        if self.pullout.items then
                            for _, item in pairs(self.pullout.items) do
                                if item.frame and not item.customSkinned then
                                    -- Hide Blizzard textures on items
                                    for _, region in ipairs({item.frame:GetRegions()}) do
                                        if region:GetObjectType() == "Texture" then
                                            region:Hide()
                                        end
                                    end
                                    
                                    -- Style item text with larger font
                                    if item.text then
                                        -- Use larger font size for better readability
                                        local font, _, flags = item.text:GetFont()
                                        item.text:SetFont(font or "Fonts\\FRIZQT__.TTF", 16, flags or "OUTLINE")
                                        item.text:SetTextColor(ColorPalette:GetColor('text-primary'))
                                    end
                                    
                                    -- Add hover effect to items
                                    item.frame:HookScript("OnEnter", function()
                                        item.frame:SetAlpha(0.7)
                                    end)
                                    item.frame:HookScript("OnLeave", function()
                                        item.frame:SetAlpha(1)
                                    end)
                                    item.customSkinned = true
                                end
                            end
                        end
                        
                        -- Also hook SetScroll to catch items added after initial open
                        if self.pullout and not self.pullout.customScrollHook then
                            hooksecurefunc(self.pullout, "SetScroll", function()
                                if self.pullout.items then
                                    for _, item in pairs(self.pullout.items) do
                                        if item.text and not item.fontResized then
                                            local font, _, flags = item.text:GetFont()
                                            item.text:SetFont(font or "Fonts\\FRIZQT__.TTF", 16, flags or "OUTLINE")
                                            item.text:SetTextColor(ColorPalette:GetColor('text-primary'))
                                            item.fontResized = true
                                        end
                                    end
                                end
                            end)
                            self.pullout.customScrollHook = true
                        end
                    end
                end
            end
            widget.customPulloutSetup = true
        end
        
        if widget.text and FontKit then
            FontKit:SetFont(widget.text, 'body', 'normal')
            widget.text:SetTextColor(ColorPalette:GetColor('text-primary'))
            
            -- Reposition dropdown text to reduce left padding (only for standard Dropdown, not MidnightDropdown)
            if widgetType == "Dropdown" and widget.dropdown and widget.button then
                local dropdownName = widget.dropdown:GetName() or ""
                if not dropdownName:match("^Midnight") then
                    widget.text:ClearAllPoints()
                    widget.text:SetPoint("LEFT", widget.dropdown, "LEFT", 4, 0)
                    widget.text:SetPoint("RIGHT", widget.button, "LEFT", -2, 0)
                    widget.text:SetJustifyH("LEFT")
                end
            end
        end
        
        if widget.label and FontKit then
            FontKit:SetFont(widget.label, 'body', 'normal')
            widget.label:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
        
    elseif widgetType == "Button" then
        if widget.frame then
            -- Ensure button has BackdropTemplate
            if not widget.frame.SetBackdrop and BackdropTemplateMixin then
                Mixin(widget.frame, BackdropTemplateMixin)
                if widget.frame.OnBackdropLoaded then
                    widget.frame:OnBackdropLoaded()
                end
            end
            
            -- Hide all button textures
            for _, region in ipairs({widget.frame:GetRegions()}) do
                if region:GetObjectType() == "Texture" and region ~= widget.text then
                    region:Hide()
                end
            end
            
            -- Apply themed backdrop with visible border
            if widget.frame.SetBackdrop then
                widget.frame:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                widget.frame:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                widget.frame:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
                
                -- Add hover effect
                if not widget.customHoverHook then
                    widget.frame:HookScript("OnEnter", function()
                        local r, g, b, a = ColorPalette:GetColor('button-bg')
                        widget.frame:SetBackdropColor(math.min(r * 2 + 0.15, 1), math.min(g * 2 + 0.15, 1), math.min(b * 2 + 0.15, 1), a)
                    end)
                    widget.frame:HookScript("OnLeave", function()
                        widget.frame:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                    end)
                    widget.customHoverHook = true
                end
            end
        end
        
        if widget.text and FontKit then
            FontKit:SetFont(widget.text, 'button', 'normal')
            widget.text:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
        
    elseif widgetType == "Heading" or widgetType == "Label" then
        if widget.label and FontKit then
            if widgetType == "Heading" then
                FontKit:SetFont(widget.label, 'heading', 'large')
            else
                FontKit:SetFont(widget.label, 'body', 'normal')
            end
            widget.label:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
        
        -- Add bottom spacing for Labels/descriptions to prevent overlap with next element
        if widgetType == "Label" and widget.frame then
            widget.frame:SetHeight(widget.frame:GetHeight() + 20)
        end
        
    elseif widgetType == "Dropdown-Pullout" then
        -- Skin the dropdown pullout menu
        if widget.frame then
            -- Add BackdropTemplate if needed
            if not widget.frame.SetBackdrop and BackdropTemplateMixin then
                Mixin(widget.frame, BackdropTemplateMixin)
                if widget.frame.OnBackdropLoaded then
                    widget.frame:OnBackdropLoaded()
                end
            end
            
            -- Hide all Blizzard textures
            for _, region in ipairs({widget.frame:GetRegions()}) do
                if region:GetObjectType() == "Texture" then
                    region:SetTexture(nil)
                    region:Hide()
                    region:SetAlpha(0)
                end
            end
            
            -- Apply themed backdrop
            if widget.frame.SetBackdrop then
                widget.frame:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                widget.frame:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
                widget.frame:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
            end
        end
        
        -- Style the scroll frame
        if widget.scrollFrame then
            if not widget.scrollFrame.SetBackdrop and BackdropTemplateMixin then
                Mixin(widget.scrollFrame, BackdropTemplateMixin)
                if widget.scrollFrame.OnBackdropLoaded then
                    widget.scrollFrame:OnBackdropLoaded()
                end
            end
            
            if widget.scrollFrame.SetBackdrop then
                widget.scrollFrame:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, edgeSize = 1,
                    insets = { left = 0, right = 0, top = 0, bottom = 0 }
                })
                widget.scrollFrame:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
                widget.scrollFrame:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
            end
        end
    end
end

function MidnightUI:HookConfigDialogFrames()
    local AceGUI = LibStub("AceGUI-3.0")
    if not AceGUI then return end
    
    local ColorPalette = _G.MidnightUI_ColorPalette
    if not ColorPalette then return end
    
    -- Track styled frames to restore their backdrops
    local styledFrames = {}
    
    -- Global backdrop monitor - hook the frame metatable
    local FrameMT = getmetatable(CreateFrame("Frame")).__index
    if FrameMT and FrameMT.SetBackdrop then
        hooksecurefunc(FrameMT, "SetBackdrop", function(frame, backdrop)
            if styledFrames[frame] and (not backdrop or backdrop == {}) then
                -- This frame had styling and is being cleared, restore it immediately
                C_Timer.After(0, function()
                    if styledFrames[frame] and frame.SetBackdrop then
                        local info = styledFrames[frame]
                        frame:SetBackdrop(info.backdrop)
                        if info.bgColor then
                            frame:SetBackdropColor(unpack(info.bgColor))
                        end
                        if info.borderColor then
                            frame:SetBackdropBorderColor(unpack(info.borderColor))
                        end
                    end
                end)
            end
        end)
    end
    
    -- Hook AceGUI:Create to skin widgets as they're created
    local oldCreate = AceGUI.Create
    AceGUI.Create = function(self, widgetType)
        local widget = oldCreate(self, widgetType)
        if widget then
            C_Timer.After(0, function()
                MidnightUI:SkinAceGUIWidget(widget, widgetType)
                
                -- Register frames that we've styled
                if widgetType == "TabGroup" and widget.tabs then
                    for _, tab in pairs(widget.tabs) do
                        if tab.SetBackdrop then
                            local isSelected = (widget.selected == tab.value)
                            local r, g, b, a
                            if isSelected then
                                r, g, b, a = ColorPalette:GetColor('button-bg')
                                r, g, b = r * 1.5, g * 1.5, b * 1.5
                            else
                                r, g, b, a = ColorPalette:GetColor('button-bg')
                            end
                            
                            styledFrames[tab] = {
                                backdrop = {
                                    bgFile = "Interface\\Buttons\\WHITE8X8",
                                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                                    tile = false, edgeSize = 1,
                                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                                },
                                bgColor = {r, g, b, a},
                                borderColor = isSelected and {0.1608, 0.5216, 0.5804, 1} or {ColorPalette:GetColor('panel-border')}
                            }
                        end
                    end
                elseif widgetType == "Dropdown" and widget.dropdown then
                    if widget.dropdown.SetBackdrop then
                        styledFrames[widget.dropdown] = {
                            backdrop = {
                                bgFile = "Interface\\Buttons\\WHITE8X8",
                                edgeFile = "Interface\\Buttons\\WHITE8X8",
                                tile = false, edgeSize = 1,
                                insets = { left = 1, right = 1, top = 1, bottom = 1 }
                            },
                            bgColor = {ColorPalette:GetColor('button-bg')},
                            borderColor = {ColorPalette:GetColor('panel-border')}
                        }
                    end
                end
            end)
        end
        return widget
    end
end

function MidnightUI:SkinConfigFrame(frame)
    if not frame or not frame.SetBackdrop then return end
    
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    if not ColorPalette then return end
    
    -- Apply themed backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    
    frame:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
    frame:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Skin the title frame and text
    if frame.obj then
        -- Add logo texture
        if not frame.logoTexture then
            frame.logoTexture = frame:CreateTexture(nil, "ARTWORK")
            frame.logoTexture:SetTexture("Interface\\AddOns\\MidnightUI\\Media\\midnightUI_icon.tga")
            frame.logoTexture:SetSize(80, 80)
            frame.logoTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -18)
        end
        
        -- Create draggable area over the top portion of the frame (excluding close button area)
        if not frame.dragArea then
            frame.dragArea = CreateFrame("Frame", nil, frame)
            frame.dragArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            frame.dragArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -50, 0)  -- Leave 50px for close button
            frame.dragArea:SetHeight(100)
            frame.dragArea:EnableMouse(true)
            frame.dragArea:RegisterForDrag("LeftButton")
            frame.dragArea:SetScript("OnDragStart", function()
                frame:StartMoving()
            end)
            frame.dragArea:SetScript("OnDragStop", function()
                frame:StopMovingOrSizing()
            end)
        end
        
        -- Add custom title text next to logo (no need for it to be draggable, the dragArea handles it)
        if not frame.customTitle then
            frame.customTitle = frame:CreateFontString(nil, "OVERLAY")
            frame.customTitle:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
            frame.customTitle:SetText("Midnight UI")
            frame.customTitle:SetTextColor(ColorPalette:GetColor('text-primary'))
            frame.customTitle:SetPoint("LEFT", frame.logoTexture, "RIGHT", 15, 0)
        end
        
        -- Find and hide default title text
        for _, region in ipairs({frame:GetRegions()}) do
            if region:GetObjectType() == "FontString" and region ~= frame.customTitle then
                region:Hide()
            elseif region:GetObjectType() == "Texture" and region:GetDrawLayer() == "OVERLAY" then
                -- Hide title frame textures
                region:Hide()
            end
        end
        
        -- Skin titlebar background if it exists
        local titleBG = frame.obj.titlebg
        if titleBG then
            titleBG:SetTexture("Interface\\Buttons\\WHITE8X8")
            titleBG:SetVertexColor(ColorPalette:GetColor('button-bg'))
        end
        
        -- Hide all status bar elements completely - try multiple approaches
        if frame.obj.statusbg and frame.obj.statusbg.Hide then
            frame.obj.statusbg:Hide()
            frame.obj.statusbg:SetAlpha(0)
            if frame.obj.statusbg.SetParent then
                frame.obj.statusbg:SetParent(nil)
            end
        end
        if frame.obj.statustext and frame.obj.statustext.Hide then
            frame.obj.statustext:Hide()
            if frame.obj.statustext.SetParent then
                frame.obj.statustext:SetParent(nil)
            end
        end
        
        -- Hide the status frame that contains the close button (if it exists)
        if frame.obj.status and frame.obj.status.Hide then
            frame.obj.status:Hide()
            if frame.obj.status.SetAlpha then
                frame.obj.status:SetAlpha(0)
            end
            if frame.obj.status.SetParent then
                frame.obj.status:SetParent(nil)
            end
        end
        
        -- Also hide the line/closebutton container at the bottom
        if frame.obj.line and frame.obj.line.Hide then
            frame.obj.line:Hide()
            if frame.obj.line.SetParent then
                frame.obj.line:SetParent(nil)
            end
        end
        
        -- Hide all children that might be status-related (one-time check)
        local children = {frame:GetChildren()}
        for _, child in ipairs(children) do
            if child:GetName() and (child:GetName():find("Status") or child:GetName():find("Close")) then
                child:Hide()
                child:SetAlpha(0)
            end
            -- Check if child is positioned at bottom
            local numPoints = child:GetNumPoints()
            if numPoints > 0 then
                for i = 1, numPoints do
                    local point, relativeTo, relativePoint = child:GetPoint(i)
                    if point and (point:find("BOTTOM") or (relativePoint and relativePoint:find("BOTTOM"))) then
                        -- This might be a status bar element - check its height
                        local height = child:GetHeight()
                        if height and height < 40 then
                            child:Hide()
                            child:SetAlpha(0)
                        end
                    end
                end
            end
        end
    end
    
    -- Create custom close button
    if frame.obj and not frame.customCloseBtn then
        -- Hide ALL original close buttons (both bottom and any other positions)
        if frame.obj.closebutton then
            frame.obj.closebutton:Hide()
            frame.obj.closebutton:SetAlpha(0)
        end
        
        -- Hide close buttons in status container
        if frame.obj.status and frame.obj.status.closebutton then
            frame.obj.status.closebutton:Hide()
            frame.obj.status.closebutton:SetAlpha(0)
        end
        
        -- Create new themed close button
        frame.customCloseBtn = CreateFrame("Button", nil, frame)
        frame.customCloseBtn:SetSize(28, 28)
        frame.customCloseBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
        
        -- Add BackdropTemplate
        if BackdropTemplateMixin then
            Mixin(frame.customCloseBtn, BackdropTemplateMixin)
            if frame.customCloseBtn.OnBackdropLoaded then
                frame.customCloseBtn:OnBackdropLoaded()
            end
        end
        
        -- Apply themed backdrop
        frame.customCloseBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        frame.customCloseBtn:SetBackdropColor(ColorPalette:GetColor('button-bg'))
        frame.customCloseBtn:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
        
        -- Add × text (standard theme size: 26)
        local closeText = frame.customCloseBtn:CreateFontString(nil, "OVERLAY")
        closeText:SetFont("Fonts\\FRIZQT__.TTF", 26, "OUTLINE")
        closeText:SetText("×")
        closeText:SetPoint("CENTER", 0, 0)
        closeText:SetTextColor(ColorPalette:GetColor('text-primary'))
        
        -- Hover effects - highlight full background like Setup window
        frame.customCloseBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(ColorPalette:GetColor('button-hover'))
            self:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
        end)
        frame.customCloseBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(ColorPalette:GetColor('button-bg'))
            self:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
        end)
        
        -- Click to close
        frame.customCloseBtn:SetScript("OnClick", function()
            if frame.obj and frame.obj.Hide then
                frame.obj:Hide()
            end
        end)
    end
end

function MidnightUI:OpenConfig()
    if Settings and Settings.OpenToCategory then
        local categoryID = nil
        if SettingsPanel and SettingsPanel.GetCategoryList then
            for _, category in ipairs(SettingsPanel:GetCategoryList()) do
                if category.name == "Midnight UI" then
                    categoryID = category:GetID()
                    break
                end
            end
        end
        if categoryID then Settings.OpenToCategory(categoryID); return end
    end
    
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("Midnight UI")
    else
        LibStub("AceConfigDialog-3.0"):Open("MidnightUI")
    end
end

-- Apply themed backdrop to a frame using ColorPalette
function MidnightUI:ApplyThemedBackdrop(frame)
    if not frame then return end
    
    -- Clear any backdrop on the parent frame itself
    if frame.SetBackdrop then
        frame:SetBackdrop(nil)
    end
    
    -- Force recreation of backdrop to apply new settings
    if frame.muiBackdrop then
        frame.muiBackdrop:Hide()
        frame.muiBackdrop:SetParent(nil)
        frame.muiBackdrop = nil
    end
    
    -- Create new backdrop with correct settings
    frame.muiBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.muiBackdrop:SetAllPoints()
    local level = frame:GetFrameLevel()
    frame.muiBackdrop:SetFrameLevel(level > 0 and level - 1 or 0)
    
    -- Set backdrop parameters
    frame.muiBackdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    
    -- Use framework colors if available
    local ColorPalette = _G.MidnightUI_ColorPalette
    if ColorPalette then
        local r, g, b, a = ColorPalette:GetColor('panel-bg')
        frame.muiBackdrop:SetBackdropColor(r, g, b, a)
        frame.muiBackdrop:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    else
        -- Fallback to database colors
        local cfg = self.db.profile.theme
        frame.muiBackdrop:SetBackdropColor(unpack(cfg.bgColor))
        frame.muiBackdrop:SetBackdropBorderColor(unpack(cfg.borderColor))
    end
    
    frame.muiBackdrop:Show()
end

-- ============================================================================
-- 4. OPTIONS TABLE
-- ============================================================================
function MidnightUI:GetThemeOptions()
    local ColorPalette = _G.MidnightUI_ColorPalette
    if not ColorPalette then
        return {
            header = {
                type = "header",
                name = "Theme System Not Loaded",
                order = 1,
            },
            desc = {
                type = "description",
                name = "The theme system is not yet initialized. Please /reload and try again.",
                order = 2,
            },
        }
    end
    
    -- Get available themes
    local availableThemes = {}
    -- Get all registered themes from ColorPalette
    for themeName, _ in pairs(ColorPalette.palettes) do
        table.insert(availableThemes, themeName)
    end
    -- Add custom themes
    local customThemes = self.db.profile.theme.customThemes or {}
    for themeName, _ in pairs(customThemes) do
        if not ColorPalette.palettes[themeName] then
            table.insert(availableThemes, themeName)
        end
    end
    
    -- Function to convert theme names to readable format
    local function GetDisplayName(themeName)
        -- Add spaces before capital letters (except first)
        local display = themeName:gsub("(%u)", " %1"):gsub("^ ", "")
        return display
    end
    
    -- Sort alphabetically by display name
    table.sort(availableThemes, function(a, b)
        return GetDisplayName(a) < GetDisplayName(b)
    end)
    
    -- Build theme selection dropdown values
    local themeValues = {}
    for _, name in ipairs(availableThemes) do
        themeValues[name] = GetDisplayName(name)
    end
    
    local options = {
        header = {
            type = "header",
            name = "Theme Management",
            order = 1,
        },
        description = {
            type = "description",
            name = "Select an existing theme or create your own custom theme by adjusting the colors below.",
            order = 2,
            fontSize = "medium",
        },
        activeTheme = {
            type = "select",
            name = "Active Theme",
            desc = "Select which theme to use for the MidnightUI framework.",
            order = 3,
            values = themeValues,
            get = function() return self.db.profile.theme.active end,
            set = function(_, value)
                -- If it's a custom theme, reload it from the database first
                if self.db.profile.theme.customThemes and self.db.profile.theme.customThemes[value] then
                    local themeData = self.db.profile.theme.customThemes[value]
                    if ColorPalette then
                        ColorPalette:RegisterPalette(value, themeData)
                    end
                end
                
                self.db.profile.theme.active = value
                if self.FrameFactory then
                    self.FrameFactory:SetTheme(value)
                end
                if ColorPalette then
                    ColorPalette:SetActiveTheme(value)
                end
                if self.FontKit then
                    self.FontKit:SetActiveTheme(value)
                end
                
                -- Clear temp colors when switching themes
                self.tempThemeColors = nil
                
                -- Update color swatches to show new theme colors
                self:UpdateThemeColorSwatches()
                
                -- Notify modules that theme has changed
                self:SendMessage("MIDNIGHTUI_THEME_CHANGED", value)
                
                self:Print("Theme changed to " .. value .. ". Some changes may require a /reload to take full effect.")
                
                -- Refresh options to show current theme colors
                local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
                if AceConfigRegistry then
                    AceConfigRegistry:NotifyChange("MidnightUI")
                end
            end,
        },
        spacer1 = {
            type = "description",
            name = " ",
            order = 3.5,
        },
        customThemeHeader = {
            type = "header",
            name = "Custom Theme Editor",
            order = 4,
        },
        customThemeDesc = {
            type = "description",
            name = "Create a custom theme by adjusting the colors below. These colors are shown from the currently selected theme. To create a custom theme, adjust the colors and then save with a new name.",
            order = 5,
            fontSize = "medium",
        },
        customThemeName = {
            type = "input",
            name = "New Theme Name",
            desc = "Enter a name for your custom theme before saving.",
            order = 6,
            width = "full",
            get = function() return self.customThemeName or "" end,
            set = function(_, v) self.customThemeName = v end,
        },
        saveCustomTheme = {
            type = "execute",
            name = "Save Custom Theme",
            desc = "Save current color settings as a new custom theme.",
            order = 7,
            func = function()
                self:SaveCustomTheme()
            end,
        },
        deleteCustomTheme = {
            type = "execute",
            name = "Delete Custom Theme",
            desc = "Delete the currently selected custom theme (built-in themes cannot be deleted).",
            order = 8,
            disabled = function()
                local active = self.db.profile.theme.active
                local builtInThemes = {
                    "MidnightUIDefault", "MidnightGlass", "MidnightGreen",
                    "MidnightTransparent", "MidnightTransparentGold",
                    "MidnightDeathKnight", "MidnightDemonHunter", "MidnightDruid",
                    "MidnightEvoker", "MidnightHunter", "MidnightMage",
                    "MidnightMonk", "MidnightPaladin", "MidnightPriest",
                    "MidnightRogue", "MidnightShaman", "MidnightWarlock",
                    "MidnightWarrior", "NeonSciFi"
                }
                for _, themeName in ipairs(builtInThemes) do
                    if active == themeName then
                        return true
                    end
                end
                return false
            end,
            func = function()
                self:DeleteCustomTheme()
            end,
            confirm = function()
                return "Are you sure you want to delete the theme '" .. self.db.profile.theme.active .. "'?"
            end,
        },
        spacer2 = {
            type = "description",
            name = " ",
            order = 8.5,
        },
        colorsHeader = {
            type = "header",
            name = "Theme Colors",
            order = 9,
        },
        colorsDesc = {
            type = "description",
            name = "Click any color rectangle below to change its color.",
            order = 10,
        },
        colorPaletteDisplay = {
            type = "description",
            name = function()
                -- Always check and clean up swatches that shouldn't be showing
                if self.colorSwatchContainer then
                    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
                    local status = AceConfigDialog and AceConfigDialog.OpenFrames["MidnightUI"]
                    if status and status.status and status.status.groups and status.status.groups.selected ~= "themes" then
                        -- We're not on themes page but swatches exist - destroy them
                        self.colorSwatchContainer:Hide()
                        self.colorSwatchContainer:SetParent(nil)
                        self.colorSwatchContainer = nil
                        self.themeColorSwatches = nil
                    end
                end
                
                -- This will trigger the creation of custom color swatch frames
                C_Timer.After(0.15, function()
                    self:CreateColorPaletteSwatches()
                end)
                return " "
            end,
            order = 11,
            width = "full",
        },
        spacer3 = {
            type = "description",
            name = " ",
            order = 12,
        },
        spacer4 = {
            type = "description",
            name = " ",
            order = 13,
        },
        spacer5 = {
            type = "description",
            name = " ",
            order = 14,
        },
        spacer6 = {
            type = "description",
            name = " ",
            order = 15,
        },
        spacer7 = {
            type = "description",
            name = " ",
            order = 16,
        },
        spacer2 = {
            type = "description",
            name = " ",
            order = 19,
        },
        resetThemeColors = {
            type = "execute",
            name = "Reset to Theme Defaults",
            desc = "Reset all color changes back to the original theme defaults",
            order = 19.5,
            func = function()
                -- Clear temp colors
                self.tempThemeColors = nil
                
                -- Reload the original palette for the active theme
                local ColorPalette = _G.MidnightUI_ColorPalette
                if ColorPalette then
                    local activeTheme = self.db.profile.theme.active
                    -- Force re-registration from the theme file
                    self:LoadTheme(activeTheme)
                    self:UpdateThemeColorSwatches()
                end
                
                self:Print("Theme colors reset to defaults")
            end,
        },
        spacer8 = {
            type = "description",
            name = " ",
            order = 19.75,
        },        
        openColorEditor = {
            type = "execute",
            name = "Open Theme Editor",
            desc = "Opens a visual mockup window where you can click on elements to edit their colors",
            order = 20,
            func = function()
                self:OpenColorEditorFrame()
            end,
        },
    }
    
    return options
end

function MidnightUI:OpenColorPickerForThemeColor(colorKey, colorName)
    local ColorPalette = _G.MidnightUI_ColorPalette
    if not ColorPalette then
        self:Print("Color system not initialized.")
        return
    end
    
    local r, g, b, a = ColorPalette:GetColor(colorKey)
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b,
        opacity = a,
        hasOpacity = true,
        swatchFunc = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local na = ColorPickerFrame:GetColorAlpha()
            
            -- Store in temp colors
            if not self.tempThemeColors then
                self.tempThemeColors = {}
            end
            self.tempThemeColors[colorKey] = {r = nr, g = ng, b = nb, a = na}
            
            -- Apply the color immediately to preview
            local activeTheme = self.db.profile.theme.active
            local fullPalette = ColorPalette.palettes[activeTheme]
            if fullPalette then
                -- Create a copy and update with temp colors
                local updatedPalette = {}
                for k, v in pairs(fullPalette) do
                    updatedPalette[k] = v
                end
                for tempKey, tempColor in pairs(self.tempThemeColors) do
                    updatedPalette[tempKey] = tempColor
                end
                -- Re-register the theme with updated colors
                ColorPalette:RegisterPalette(activeTheme, updatedPalette)
            end
            
            -- Update color swatch frames if they exist
            self:UpdateThemeColorSwatches()
        end,
        cancelFunc = function()
            -- Restore original color
            if not self.tempThemeColors then
                self.tempThemeColors = {}
            end
            self.tempThemeColors[colorKey] = {r = r, g = g, b = b, a = a}
            
            local activeTheme = self.db.profile.theme.active
            local fullPalette = ColorPalette.palettes[activeTheme]
            if fullPalette then
                ColorPalette:RegisterPalette(activeTheme, fullPalette)
            end
            
            self:UpdateThemeColorSwatches()
        end,
    })
end

function MidnightUI:UpdateThemeColorSwatches()
    -- This will update the color swatch frames when they're created
    if self.themeColorSwatches then
        local ColorPalette = _G.MidnightUI_ColorPalette
        if not ColorPalette then return end
        
        for colorKey, swatchData in pairs(self.themeColorSwatches) do
            if swatchData and swatchData.texture then
                -- Check if there's a temp color for this key (unsaved changes)
                local r, g, b, a
                if self.tempThemeColors and self.tempThemeColors[colorKey] then
                    local tempColor = self.tempThemeColors[colorKey]
                    r, g, b, a = tempColor.r, tempColor.g, tempColor.b, tempColor.a
                else
                    -- Use the color from the active theme
                    r, g, b, a = ColorPalette:GetColor(colorKey)
                end
                swatchData.texture:SetColorTexture(r, g, b, a)
            end
        end
    end
end

function MidnightUI:CreateColorPaletteSwatches()
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    if not ColorPalette or not FontKit then return end
    
    -- Clean up old container if it exists
    if self.colorSwatchContainer then
        self.colorSwatchContainer:Hide()
        self.colorSwatchContainer:SetParent(nil)
        self.colorSwatchContainer = nil
        self.themeColorSwatches = nil
    end
    
    -- Find the AceGUI container for the Themes tab
    local AceGUI = LibStub("AceGUI-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    if not AceGUI or not AceConfigDialog then return end
    
    -- Get the options frame
    local appName = AceConfigDialog.OpenFrames["MidnightUI"]
    if not appName or not appName.frame then return end
    
    -- Check if we're on the Themes tab
    local status = appName.status
    if not status or not status.groups or not status.groups.selected then
        return
    end
    
    -- Only show on Themes tab
    if status.groups.selected ~= "themes" then
        return
    end
    
    -- Destroy any existing container first
    if self.colorSwatchContainer then
        self.colorSwatchContainer:Hide()
        self.colorSwatchContainer:SetParent(nil)
        self.colorSwatchContainer = nil
        self.themeColorSwatches = nil
    end
    
    local container = appName.frame.obj
    if not container or not container.content then return end
    
    -- Find the actual content area (NOT the tree frame)
    -- Look for the ScrollFrame that contains the options
    local contentFrame = nil
    for _, child in ipairs({container.content:GetChildren()}) do
        local childType = child:GetObjectType()
        -- Skip the tree frame, find the ScrollFrame that's for content
        if childType == "ScrollFrame" then
            -- Make sure this isn't the tree's scrollframe by checking its position
            local point = child:GetPoint()
            if point and point ~= "TOPLEFT" then  -- Tree is at TOPLEFT, content is elsewhere
                contentFrame = child
                break
            end
        end
    end
    
    -- If we didn't find a separate scroll frame, look for the content container directly
    if not contentFrame then
        -- The content is likely directly in container.content, but positioned to the right of tree
        contentFrame = container.content
    end
    
    -- Hook the content frame's OnUpdate to detect when it's being reused for another page
    if not contentFrame.MidnightSwatchCleanupHooked then
        contentFrame:HookScript("OnHide", function()
            if self.colorSwatchContainer and self.colorSwatchContainer:IsShown() then
                self.colorSwatchContainer:Hide()
                self.colorSwatchContainer:SetParent(nil)
                self.colorSwatchContainer = nil
                self.themeColorSwatches = nil
            end
        end)
        contentFrame.MidnightSwatchCleanupHooked = true
    end
    
    -- Create container for swatches - attach to the content frame
    local swatchContainer = CreateFrame("Frame", "MidnightUI_ColorSwatches", contentFrame)
    swatchContainer:SetSize(800, 100)
    -- Position relative to the content frame with a left offset to account for tree width
    -- Increased Y offset to position below the "Click any color rectangle" text
    swatchContainer:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 200, -380)
    
    -- Set frame strata and level to ensure it's on top
    local parentStrata = contentFrame:GetFrameStrata()
    swatchContainer:SetFrameStrata(parentStrata)
    swatchContainer:SetFrameLevel(contentFrame:GetFrameLevel() + 100)
    
    self.colorSwatchContainer = swatchContainer
    
    -- Add OnUpdate script to check if we should still be visible
    swatchContainer:SetScript("OnUpdate", function(self)
        local AceConfigDialog = LibStub("AceConfigDialog-3.0")
        if AceConfigDialog and AceConfigDialog.OpenFrames["MidnightUI"] then
            local status = AceConfigDialog.OpenFrames["MidnightUI"].status
            if status and status.groups and status.groups.selected ~= "themes" then
                -- We're not on themes page anymore, hide immediately
                self:Hide()
                self:SetParent(nil)
                MidnightUI.colorSwatchContainer = nil
                MidnightUI.themeColorSwatches = nil
            end
        end
    end)
    
    -- Define the 8 core colors
    local coreColors = {
        {key = "panel-bg", name = "Panel\nBackground"},
        {key = "panel-border", name = "Panel\nBorder"},
        {key = "accent-primary", name = "Accent"},
        {key = "button-bg", name = "Button"},
        {key = "button-hover", name = "Button\nHover"},
        {key = "text-primary", name = "Primary\nText"},
        {key = "text-secondary", name = "Secondary\nText"},
        {key = "tab-active", name = "Active\nTab"},
    }
    
    self.themeColorSwatches = {}
    local xOffset = 0
    
    for i, colorData in ipairs(coreColors) do
        -- Create clickable frame for the swatch
        local swatchFrame = CreateFrame("Button", nil, swatchContainer)
        swatchFrame:SetSize(80, 50)
        swatchFrame:SetPoint("TOPLEFT", xOffset, 0)
        
        -- Create color texture directly (will show on settings window background)
        local colorTexture = swatchFrame:CreateTexture(nil, "ARTWORK")
        colorTexture:SetAllPoints()
        
        -- Check if there's a temp color (unsaved changes), otherwise use active theme
        local r, g, b, a
        if self.tempThemeColors and self.tempThemeColors[colorData.key] then
            local tempColor = self.tempThemeColors[colorData.key]
            r, g, b, a = tempColor.r, tempColor.g, tempColor.b, tempColor.a
        else
            r, g, b, a = ColorPalette:GetColor(colorData.key)
        end
        colorTexture:SetColorTexture(r, g, b, a)
        
        -- Label below
        local label = FontKit:CreateFontString(swatchFrame, "body", "tiny")
        label:SetPoint("TOP", swatchFrame, "BOTTOM", 0, -4)
        label:SetWidth(80)  -- Match swatch width
        label:SetText(colorData.name)
        label:SetTextColor(ColorPalette:GetColor("text-secondary"))
        label:SetJustifyH("CENTER")
        label:SetWordWrap(true)  -- Enable word wrap
        label:SetMaxLines(0)  -- Allow unlimited lines
        
        -- Click handler
        swatchFrame:SetScript("OnClick", function()
            self:OpenColorPickerForThemeColor(colorData.key, colorData.name:gsub("\n", " "))
        end)
        
        -- Hover effect
        swatchFrame:SetScript("OnEnter", function()
            GameTooltip:SetOwner(swatchFrame, "ANCHOR_TOP")
            GameTooltip:SetText(colorData.name:gsub("\n", " "), 1, 1, 1)
            GameTooltip:AddLine("Click to change this color", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        
        swatchFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        -- Store for updates
        self.themeColorSwatches[colorData.key] = {
            texture = colorTexture,
            frame = swatchFrame
        }
        
        xOffset = xOffset + 90
    end
    
    swatchContainer:Show()
end

function MidnightUI:OpenColorEditorFrame()
    -- Create or show the color editor frame
    if self.colorEditorFrame then
        self.colorEditorFrame:Show()
        return
    end
    
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    if not ColorPalette or not FontKit then
        self:Print("Framework not initialized.")
        return
    end
    
    -- Create main frame styled like a real MidnightUI window
    local frame = CreateFrame("Frame", "MidnightUI_ColorEditorFrame", UIParent, "BackdropTemplate")
    frame:SetSize(800, 600)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    
    -- Function to get current color
    local function GetCurrentColor(key)
        local color = self.tempThemeColors and self.tempThemeColors[key]
        if color then
            return color.r, color.g, color.b, color.a
        end
        return ColorPalette:GetColor(key)
    end
    
    -- Function to update frame colors
    local function UpdateFrameColors()
        -- Update main frame
        frame:SetBackdropColor(GetCurrentColor("panel-bg"))
        frame:SetBackdropBorderColor(GetCurrentColor("panel-border"))
        
        -- Update title bar
        if frame.titleBg then
            frame.titleBg:SetColorTexture(GetCurrentColor("panel-bg"))
        end
        
        -- Update inner panel
        if frame.innerPanel then
            frame.innerPanel:SetBackdropColor(GetCurrentColor("panel-bg"))
            frame.innerPanel:SetBackdropBorderColor(GetCurrentColor("accent-primary"))
        end
        
        -- Update buttons
        for _, btn in ipairs(frame.mockButtons or {}) do
            btn:SetBackdropColor(GetCurrentColor("button-bg"))
            btn:SetBackdropBorderColor(GetCurrentColor("accent-primary"))
        end
        
        -- Update tabs
        for i, tab in ipairs(frame.mockTabs or {}) do
            if i == 2 then
                tab:SetBackdropColor(GetCurrentColor("tab-active"))
            else
                tab:SetBackdropColor(GetCurrentColor("button-bg"))
            end
            tab:SetBackdropBorderColor(GetCurrentColor("accent-primary"))
        end
        
        -- Update text
        if frame.titleText then
            frame.titleText:SetTextColor(GetCurrentColor("text-primary"))
        end
        if frame.headerText then
            frame.headerText:SetTextColor(GetCurrentColor("text-primary"))
        end
        if frame.descText then
            frame.descText:SetTextColor(GetCurrentColor("text-secondary"))
        end
        for _, btn in ipairs(frame.mockButtons or {}) do
            if btn.text then
                btn.text:SetTextColor(GetCurrentColor("text-primary"))
            end
        end
        for _, tab in ipairs(frame.mockTabs or {}) do
            if tab.text then
                tab.text:SetTextColor(GetCurrentColor("text-primary"))
            end
        end
    end
    
    -- Apply backdrop styled like settings window
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    
    -- Title bar background (used for dragging, not clickable for color)
    local titleBg = frame:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT", 0, 0)
    titleBg:SetPoint("TOPRIGHT", 0, 0)
    titleBg:SetHeight(60)
    frame.titleBg = titleBg
    
    -- Make title bar draggable (not clickable for color picker)
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(60)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)
    
    -- Title text
    local title = FontKit:CreateFontString(frame, "title", "large")
    title:SetPoint("TOPLEFT", 20, -12)
    title:SetText("Theme Editor")
    frame.titleText = title
    
    -- Instructions in title area
    local instructions = FontKit:CreateFontString(frame, "body", "small")
    instructions:SetPoint("TOPLEFT", 20, -38)
    instructions:SetText("Click on any element below to change its color • Drag title bar to move")
    frame.descText = instructions
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("TOPRIGHT", -12, -12)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    closeBtn:SetBackdropColor(GetCurrentColor("button-bg"))
    closeBtn:SetBackdropBorderColor(GetCurrentColor("panel-border"))
    closeBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    closeTxt:SetFont("Fonts\\FRIZQT__.TTF", 26, "OUTLINE")
    closeTxt:SetText("×")
    closeTxt:SetPoint("CENTER", 0, 0)
    closeTxt:SetTextColor(GetCurrentColor("text-primary"))
    closeBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(GetCurrentColor("button-hover"))
        self:SetBackdropBorderColor(GetCurrentColor("accent-primary"))
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(GetCurrentColor("button-bg"))
        self:SetBackdropBorderColor(GetCurrentColor("panel-border"))
    end)
    closeBtn:SetScript("OnClick", function()
        -- Check if there are any color changes
        if MidnightUI.tempThemeColors and next(MidnightUI.tempThemeColors) ~= nil then
            StaticPopupDialogs["MIDNIGHTUI_THEME_CLOSE_CONFIRM"] = {
                text = "You have unsaved color changes that will be lost. Close anyway?",
                button1 = "Close",
                button2 = "Cancel",
                OnAccept = function()
                    -- Discard changes and close
                    MidnightUI.tempThemeColors = nil
                    frame:Hide()
                end,
                OnCancel = function()
                    -- Cancel - keep window open
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("MIDNIGHTUI_THEME_CLOSE_CONFIRM")
        else
            -- No changes, just close
            frame:Hide()
        end
    end)
    
    -- Background click area (behind everything else) for panel-bg and panel-border colors
    local bgClickArea = CreateFrame("Frame", nil, frame)
    bgClickArea:SetAllPoints(frame)
    bgClickArea:SetFrameLevel(frame:GetFrameLevel() + 1)
    bgClickArea:EnableMouse(true)
    bgClickArea:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        
        -- Get mouse position relative to frame
        local scale = frame:GetEffectiveScale()
        local frameLeft = frame:GetLeft() * scale
        local frameRight = frame:GetRight() * scale
        local frameTop = frame:GetTop() * scale
        local frameBottom = frame:GetBottom() * scale
        local mouseX, mouseY = GetCursorPosition()
        
        -- Check if click is within 20px of any edge
        local edgeThreshold = 20 * scale
        local nearLeftEdge = (mouseX - frameLeft) < edgeThreshold
        local nearRightEdge = (frameRight - mouseX) < edgeThreshold
        local nearTopEdge = (frameTop - mouseY) < edgeThreshold
        local nearBottomEdge = (mouseY - frameBottom) < edgeThreshold
        
        if nearLeftEdge or nearRightEdge or nearTopEdge or nearBottomEdge then
            -- Click near border - change panel-border color
            local r, g, b, a = GetCurrentColor("panel-border")
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                opacity = a,
                hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = ColorPickerFrame:GetColorAlpha()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors["panel-border"] = {r = nr, g = ng, b = nb, a = na}
                    UpdateFrameColors()
                end,
                cancelFunc = function()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors["panel-border"] = {r = r, g = g, b = b, a = a}
                    UpdateFrameColors()
                end,
            })
        else
            -- Click in center - change panel-bg color
            local r, g, b, a = GetCurrentColor("panel-bg")
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                opacity = a,
                hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = ColorPickerFrame:GetColorAlpha()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors["panel-bg"] = {r = nr, g = ng, b = nb, a = na}
                    UpdateFrameColors()
                end,
                cancelFunc = function()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors["panel-bg"] = {r = r, g = g, b = b, a = a}
                    UpdateFrameColors()
                end,
            })
        end
    end)
    bgClickArea:SetScript("OnEnter", function()
        -- Show tooltip based on mouse position
        local scale = frame:GetEffectiveScale()
        local frameLeft = frame:GetLeft() * scale
        local frameRight = frame:GetRight() * scale
        local frameTop = frame:GetTop() * scale
        local frameBottom = frame:GetBottom() * scale
        local mouseX, mouseY = GetCursorPosition()
        
        local edgeThreshold = 20 * scale
        local nearLeftEdge = (mouseX - frameLeft) < edgeThreshold
        local nearRightEdge = (frameRight - mouseX) < edgeThreshold
        local nearTopEdge = (frameTop - mouseY) < edgeThreshold
        local nearBottomEdge = (mouseY - frameBottom) < edgeThreshold
        
        GameTooltip:SetOwner(bgClickArea, "ANCHOR_CURSOR")
        if nearLeftEdge or nearRightEdge or nearTopEdge or nearBottomEdge then
            GameTooltip:SetText("Panel Border", 1, 1, 1)
            GameTooltip:AddLine("Border color for all panels and frames", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Click near edge to change color", 0.0, 1.0, 0.5)
        else
            GameTooltip:SetText("Panel Background", 1, 1, 1)
            GameTooltip:AddLine("Main background color for windows and panels", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Click center area to change color", 0.0, 1.0, 0.5)
        end
        GameTooltip:Show()
    end)
    bgClickArea:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Create inner panel to demonstrate panel border (accent-primary)
    -- This panel is non-interactive so clicks pass through to bgClickArea for proper edge detection
    local innerPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    innerPanel:SetSize(760, 450)
    innerPanel:SetPoint("TOP", 0, -75)
    innerPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    innerPanel:SetFrameLevel(frame:GetFrameLevel() + 2)
    innerPanel:EnableMouse(false)  -- Don't intercept clicks - let them pass through to bgClickArea
    frame.innerPanel = innerPanel
    
    -- Create clickable border areas for accent-primary color editing
    local borderThickness = 8  -- Make borders easier to click
    
    -- Top border
    local topBorder = CreateFrame("Frame", nil, innerPanel)
    topBorder:SetPoint("TOPLEFT", innerPanel, "TOPLEFT", 0, 0)
    topBorder:SetPoint("TOPRIGHT", innerPanel, "TOPRIGHT", 0, 0)
    topBorder:SetHeight(borderThickness)
    topBorder:SetFrameLevel(innerPanel:GetFrameLevel() + 1)
    topBorder:EnableMouse(true)
    
    -- Bottom border
    local bottomBorder = CreateFrame("Frame", nil, innerPanel)
    bottomBorder:SetPoint("BOTTOMLEFT", innerPanel, "BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", innerPanel, "BOTTOMRIGHT", 0, 0)
    bottomBorder:SetHeight(borderThickness)
    bottomBorder:SetFrameLevel(innerPanel:GetFrameLevel() + 1)
    bottomBorder:EnableMouse(true)
    
    -- Left border
    local leftBorder = CreateFrame("Frame", nil, innerPanel)
    leftBorder:SetPoint("TOPLEFT", innerPanel, "TOPLEFT", 0, -borderThickness)
    leftBorder:SetPoint("BOTTOMLEFT", innerPanel, "BOTTOMLEFT", 0, borderThickness)
    leftBorder:SetWidth(borderThickness)
    leftBorder:SetFrameLevel(innerPanel:GetFrameLevel() + 1)
    leftBorder:EnableMouse(true)
    
    -- Right border
    local rightBorder = CreateFrame("Frame", nil, innerPanel)
    rightBorder:SetPoint("TOPRIGHT", innerPanel, "TOPRIGHT", 0, -borderThickness)
    rightBorder:SetPoint("BOTTOMRIGHT", innerPanel, "BOTTOMRIGHT", 0, borderThickness)
    rightBorder:SetWidth(borderThickness)
    rightBorder:SetFrameLevel(innerPanel:GetFrameLevel() + 1)
    rightBorder:EnableMouse(true)
    
    -- Add scripts to all border frames
    local borderFrames = {topBorder, bottomBorder, leftBorder, rightBorder}
    for _, border in ipairs(borderFrames) do
        border:SetScript("OnEnter", function()
            GameTooltip:SetOwner(border, "ANCHOR_CURSOR")
            GameTooltip:SetText("Panel Border (Accent)", 1, 1, 1)
            GameTooltip:AddLine("Highlighted border color for panels and minimap", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Click to change color", 0.0, 1.0, 0.5)
            GameTooltip:Show()
        end)
        border:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        border:SetScript("OnMouseDown", function()
            local r, g, b, a = GetCurrentColor("accent-primary")
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                opacity = a,
                hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = ColorPickerFrame:GetColorAlpha()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors["accent-primary"] = {r = nr, g = ng, b = nb, a = na}
                    UpdateFrameColors()
                end,
                cancelFunc = function()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors["accent-primary"] = {r = r, g = g, b = b, a = a}
                    UpdateFrameColors()
                end,
            })
        end)
    end
    
    -- Header text in panel
    local headerText = FontKit:CreateFontString(innerPanel, "heading", "medium")
    headerText:SetPoint("TOPLEFT", 20, -20)
    headerText:SetText("Sample UI Elements")
    frame.headerText = headerText
    
    -- Tab group mockup
    local tabs = {}
    local tabNames = {"General", "Settings", "Advanced"}
    for i, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", nil, innerPanel, "BackdropTemplate")
        tab:SetSize(120, 32)
        if i == 1 then
            tab:SetPoint("TOPLEFT", 20, -50)
        else
            tab:SetPoint("LEFT", tabs[i-1], "RIGHT", 5, 0)
        end
        tab:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        tab:SetFrameLevel(innerPanel:GetFrameLevel() + 5)
        tab.text = tab:CreateFontString(nil, "OVERLAY")
        tab.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        tab.text:SetText(name)
        tab.text:SetPoint("CENTER")
        tab:EnableMouse(true)
        
        -- Click handler for tab color
        local colorKey = i == 2 and "tab-active" or "button-bg"
        tab:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(i == 2 and "Active Tab" or "Inactive Tab", 1, 1, 1)
            GameTooltip:AddLine(i == 2 and "Background color for the currently selected tab" or "Background color for inactive tabs", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Click to change " .. (i == 2 and "active tab" or "button") .. " color", 0.0, 1.0, 0.5)
            GameTooltip:Show()
        end)
        tab:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        tab:SetScript("OnMouseDown", function()
            local r, g, b, a = GetCurrentColor(colorKey)
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                opacity = a,
                hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = ColorPickerFrame:GetColorAlpha()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors[colorKey] = {r = nr, g = ng, b = nb, a = na}
                    UpdateFrameColors()
                end,
                cancelFunc = function()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors[colorKey] = {r = r, g = g, b = b, a = a}
                    UpdateFrameColors()
                end,
            })
        end)
        
        table.insert(tabs, tab)
    end
    frame.mockTabs = tabs
    
    -- Text samples
    local textLabel1 = FontKit:CreateFontString(innerPanel, "body", "normal")
    textLabel1:SetPoint("TOPLEFT", 20, -100)
    textLabel1:SetText("Primary Text: Main labels and headers")
    textLabel1:EnableMouse(true)
    
    local textClick1 = CreateFrame("Frame", nil, innerPanel)
    textClick1:SetAllPoints(textLabel1)
    textClick1:SetFrameLevel(innerPanel:GetFrameLevel() + 5)
    textClick1:EnableMouse(true)
    textClick1:SetScript("OnEnter", function()
        GameTooltip:SetOwner(textClick1, "ANCHOR_TOP")
        GameTooltip:SetText("Primary Text", 1, 1, 1)
        GameTooltip:AddLine("Main text color for labels and headers", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Click to change color", 0.0, 1.0, 0.5)
        GameTooltip:Show()
    end)
    textClick1:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    textClick1:SetScript("OnMouseDown", function()
        local r, g, b, a = GetCurrentColor("text-primary")
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            opacity = a,
            hasOpacity = true,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = ColorPickerFrame:GetColorAlpha()
                if not MidnightUI.tempThemeColors then
                    MidnightUI.tempThemeColors = {}
                end
                MidnightUI.tempThemeColors["text-primary"] = {r = nr, g = ng, b = nb, a = na}
                UpdateFrameColors()
            end,
            cancelFunc = function()
                if not MidnightUI.tempThemeColors then
                    MidnightUI.tempThemeColors = {}
                end
                MidnightUI.tempThemeColors["text-primary"] = {r = r, g = g, b = b, a = a}
                UpdateFrameColors()
            end,
        })
    end)
    
    local textLabel2 = FontKit:CreateFontString(innerPanel, "body", "normal")
    textLabel2:SetPoint("TOPLEFT", 20, -125)
    textLabel2:SetText("Secondary Text: Descriptions and hints")
    textLabel2:EnableMouse(true)
    
    local textClick2 = CreateFrame("Frame", nil, innerPanel)
    textClick2:SetAllPoints(textLabel2)
    textClick2:SetFrameLevel(innerPanel:GetFrameLevel() + 5)
    textClick2:EnableMouse(true)
    textClick2:SetScript("OnEnter", function()
        GameTooltip:SetOwner(textClick2, "ANCHOR_TOP")
        GameTooltip:SetText("Secondary Text", 1, 1, 1)
        GameTooltip:AddLine("Text color for descriptions and supporting information", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Click to change color", 0.0, 1.0, 0.5)
        GameTooltip:Show()
    end)
    textClick2:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    textClick2:SetScript("OnMouseDown", function()
        local r, g, b, a = GetCurrentColor("text-secondary")
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            opacity = a,
            hasOpacity = true,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = ColorPickerFrame:GetColorAlpha()
                if not MidnightUI.tempThemeColors then
                    MidnightUI.tempThemeColors = {}
                end
                MidnightUI.tempThemeColors["text-secondary"] = {r = nr, g = ng, b = nb, a = na}
                UpdateFrameColors()
            end,
            cancelFunc = function()
                if not MidnightUI.tempThemeColors then
                    MidnightUI.tempThemeColors = {}
                end
                MidnightUI.tempThemeColors["text-secondary"] = {r = r, g = g, b = b, a = a}
                UpdateFrameColors()
            end,
        })
    end)
    
    -- Button mockups
    local buttons = {}
    local buttonNames = {"Button Background", "Button Hover"}
    local buttonKeys = {"button-bg", "button-hover"}
    for i, name in ipairs(buttonNames) do
        local btn = CreateFrame("Button", nil, innerPanel, "BackdropTemplate")
        btn:SetSize(180, 36)
        if i == 1 then
            btn:SetPoint("TOPLEFT", 20, -170)
        else
            btn:SetPoint("LEFT", buttons[i-1], "RIGHT", 20, 0)
        end
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        btn:SetFrameLevel(innerPanel:GetFrameLevel() + 5)
        btn.text = btn:CreateFontString(nil, "OVERLAY")
        btn.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        btn.text:SetText(name)
        btn.text:SetPoint("CENTER")
        btn:EnableMouse(true)
        
        local colorKey = buttonKeys[i]
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(i == 1 and "Background color for all buttons" or "Button color when hovering with mouse", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Click to change color", 0.0, 1.0, 0.5)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        btn:SetScript("OnMouseDown", function()
            local r, g, b, a = GetCurrentColor(colorKey)
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                opacity = a,
                hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = ColorPickerFrame:GetColorAlpha()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors[colorKey] = {r = nr, g = ng, b = nb, a = na}
                    UpdateFrameColors()
                end,
                cancelFunc = function()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors[colorKey] = {r = r, g = g, b = b, a = a}
                    UpdateFrameColors()
                end,
            })
        end)
        
        table.insert(buttons, btn)
    end
    frame.mockButtons = buttons
    
    -- Bottom buttons
    local saveBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    saveBtn:SetSize(200, 36)
    saveBtn:SetPoint("BOTTOMLEFT", 20, 15)
    saveBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    saveBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
    saveBtn:SetBackdropColor(GetCurrentColor("button-bg"))
    saveBtn:SetBackdropBorderColor(GetCurrentColor("accent-primary"))
    local saveTxt = saveBtn:CreateFontString(nil, "OVERLAY")
    saveTxt:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    saveTxt:SetText("Save & Apply")
    saveTxt:SetPoint("CENTER")
    saveTxt:SetTextColor(GetCurrentColor("text-primary"))
    saveBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(GetCurrentColor("button-hover"))
    end)
    saveBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(GetCurrentColor("button-bg"))
    end)
    saveBtn:SetScript("OnClick", function()
        -- Check if there are any color changes
        if not MidnightUI.tempThemeColors or next(MidnightUI.tempThemeColors) == nil then
            MidnightUI:Print("|cffff8800Warning:|r No color changes detected. Please modify at least one color first.")
            return
        end
        
        -- Show save dialog
        StaticPopupDialogs["MIDNIGHTUI_THEME_SAVE_CONFIRM"] = {
            text = "Ready to save your custom theme. The editor will close and the Themes settings page will open where you can enter a name and save.",
            button1 = "Continue",
            button2 = "Cancel",
            OnAccept = function()
                -- Open settings to Themes page so user can enter a name and save
                frame:Hide()
                local AceConfigDialog = LibStub("AceConfigDialog-3.0")
                if AceConfigDialog then
                    AceConfigDialog:Open("MidnightUI")
                    -- Try to select the Themes category
                    C_Timer.After(0.1, function()
                        AceConfigDialog:SelectGroup("MidnightUI", "themes")
                    end)
                end
                MidnightUI:Print("Enter a theme name and click 'Save Custom Theme' to save your changes.")
            end,
            OnCancel = function()
                -- Cancel - keep window open
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("MIDNIGHTUI_THEME_SAVE_CONFIRM")
    end)
    
    -- Reset button at bottom
    local resetBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    resetBtn:SetSize(200, 36)
    resetBtn:SetPoint("BOTTOMRIGHT", -20, 15)
    resetBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    resetBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
    resetBtn:SetBackdropColor(GetCurrentColor("button-bg"))
    resetBtn:SetBackdropBorderColor(GetCurrentColor("accent-primary"))
    local resetTxt = resetBtn:CreateFontString(nil, "OVERLAY")
    resetTxt:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    resetTxt:SetText("Reset to Theme Defaults")
    resetTxt:SetPoint("CENTER")
    resetTxt:SetTextColor(GetCurrentColor("text-primary"))
    resetBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(GetCurrentColor("button-hover"))
    end)
    resetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(GetCurrentColor("button-bg"))
    end)
    resetBtn:SetScript("OnClick", function()
        MidnightUI.tempThemeColors = nil
        UpdateFrameColors()
        MidnightUI:Print("Colors reset to theme defaults.")
    end)
    
    UpdateFrameColors()
    self.colorEditorFrame = frame
    frame:Show()
end

function MidnightUI:SaveCustomTheme()
    local themeName = self.customThemeName
    if not themeName or themeName == "" then
        self:Print("|cffff0000Error:|r Please enter a name for your custom theme.")
        return
    end
    
    -- Don't allow overwriting built-in themes
    local builtInThemes = {
        "MidnightUIDefault",
        "MidnightGlass",
        "MidnightGreen",
        "MidnightTransparent",
        "MidnightTransparentGold",
        "MidnightDeathKnight",
        "MidnightDemonHunter",
        "MidnightDruid",
        "MidnightEvoker",
        "MidnightHunter",
        "MidnightMage",
        "MidnightMonk",
        "MidnightPaladin",
        "MidnightPriest",
        "MidnightRogue",
        "MidnightShaman",
        "MidnightWarlock",
        "MidnightWarrior",
        "NeonSciFi"
    }
    for _, builtInName in ipairs(builtInThemes) do
        if themeName == builtInName then
            self:Print("|cffff0000Error:|r Cannot overwrite built-in themes.")
            return
        end
    end
    
    -- Check if theme already exists
    local isOverwrite = false
    if self.db.profile.theme.customThemes and self.db.profile.theme.customThemes[themeName] then
        isOverwrite = true
    end
    
    -- Only require color changes for NEW themes, allow overwrites without changes
    if not isOverwrite and (not self.tempThemeColors or next(self.tempThemeColors) == nil) then
        self:Print("|cffff0000Error:|r No color changes detected. Please modify at least one color before saving a new theme.")
        return
    end
    
    -- Get full theme palette from current theme as base
    local ColorPalette = _G.MidnightUI_ColorPalette
    local fullTheme = {}
    
    -- Copy all colors from current active theme
    local currentTheme = self.db.profile.theme.active
    local palette = ColorPalette.palettes[currentTheme]
    if palette then
        for key, color in pairs(palette) do
            fullTheme[key] = {r = color.r, g = color.g, b = color.b, a = color.a}
        end
    end
    
    -- Override with custom changes (if any)
    if self.tempThemeColors then
        for key, color in pairs(self.tempThemeColors) do
            fullTheme[key] = color
        end
    end
    
    -- Save theme to database
    if not self.db.profile.theme.customThemes then
        self.db.profile.theme.customThemes = {}
    end
    
    self.db.profile.theme.customThemes[themeName] = fullTheme
    
    -- Register the theme with ColorPalette
    if ColorPalette then
        ColorPalette:RegisterPalette(themeName, fullTheme)
        -- Switch to the newly saved custom theme
        ColorPalette:SetActiveTheme(themeName)
    end
    
    -- Switch the active theme to the newly created theme
    self.db.profile.theme.active = themeName
    if self.FrameFactory then
        self.FrameFactory:SetTheme(themeName)
    end
    if self.FontKit then
        self.FontKit:SetActiveTheme(themeName)
    end
    
    if isOverwrite then
        self:Print("|cff00ff00Success:|r Custom theme '" .. themeName .. "' updated and activated!")
    else
        self:Print("|cff00ff00Success:|r Custom theme '" .. themeName .. "' created and activated!")
    end
    
    -- Clear temporary storage and name
    self.tempThemeColors = nil
    self.customThemeName = ""
    
    -- Update the color swatches to show the new theme colors
    self:UpdateThemeColorSwatches()
    
    -- Refresh options
    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    if AceConfigRegistry then
        AceConfigRegistry:NotifyChange("MidnightUI")
    end
end

function MidnightUI:DeleteCustomTheme()
    local themeName = self.db.profile.theme.active
    
    if not self.db.profile.theme.customThemes or not self.db.profile.theme.customThemes[themeName] then
        self:Print("|cffff0000Error:|r Theme not found or is not a custom theme.")
        return
    end
    
    -- Remove from database
    self.db.profile.theme.customThemes[themeName] = nil
    
    -- Switch to default theme
    self.db.profile.theme.active = "MidnightTransparent"
    local ColorPalette = _G.MidnightUI_ColorPalette
    if ColorPalette then
        ColorPalette:SetActiveTheme("MidnightTransparent")
    end
    if self.FrameFactory then
        self.FrameFactory:SetTheme("MidnightTransparent")
    end
    if self.FontKit then
        self.FontKit:SetActiveTheme("MidnightTransparent")
    end
    
    self:Print("|cff00ff00Success:|r Theme '" .. themeName .. "' deleted. Switched to Midnight Transparent.")
    
    -- Refresh options
    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    if AceConfigRegistry then
        AceConfigRegistry:NotifyChange("MidnightUI")
    end
end

function MidnightUI:LoadCustomThemes()
    local ColorPalette = _G.MidnightUI_ColorPalette
    if not ColorPalette then return end
    
    local customThemes = self.db.profile.theme.customThemes
    if not customThemes then return end
    
    for themeName, themeColors in pairs(customThemes) do
        ColorPalette:RegisterPalette(themeName, themeColors)
    end
end

function MidnightUI:GetOptions()
    -- Cleanup check every time options are fetched
    if self.colorSwatchContainer then
        local AceConfigDialog = LibStub("AceConfigDialog-3.0")
        if AceConfigDialog and AceConfigDialog.OpenFrames["MidnightUI"] then
            local status = AceConfigDialog.OpenFrames["MidnightUI"].status
            if status and status.groups and status.groups.selected ~= "themes" then
                self.colorSwatchContainer:Hide()
                self.colorSwatchContainer:SetParent(nil)
                self.colorSwatchContainer = nil
                self.themeColorSwatches = nil
            end
        end
    end
    
    local options = {
        name = "Midnight UI",
        type = "group",
        childGroups = "tree",
        args = {
            general = {
                name = "General",
                type = "group",
                order = 1,
                args = {
                    versionInfo = {
                        type = "description",
                        name = function()
                            return "|cff00ccff MidnightUI|r version |cffffaa00" .. (C_AddOns.GetAddOnMetadata("MidnightUI", "Version") or "Unknown") .. "|r"
                        end,
                        order = 0.5,
                        fontSize = "large",
                    },
                    resolutionHeader = {
                        type = "header",
                        name = "Resolution Scaling",
                        order = 1.0,
                    },
                    resolutionDesc = {
                        type = "description",
                        name = function()
                            local screenWidth = math.floor(GetScreenWidth())
                            local screenHeight = math.floor(GetScreenHeight())
                            local physicalWidth = math.floor(GetScreenWidth() * UIParent:GetEffectiveScale())
                            local physicalHeight = math.floor(GetScreenHeight() * UIParent:GetEffectiveScale())
                            local uiScale = UIParent:GetEffectiveScale()
                            local refWidth = MidnightUI.REFERENCE_WIDTH
                            local refHeight = MidnightUI.REFERENCE_HEIGHT
                            
                            local resInfo = "UI Resolution (effective): |cffffaa00" .. screenWidth .. "x" .. screenHeight .. "|r\n"
                            if physicalWidth ~= screenWidth or physicalHeight ~= screenHeight then
                                resInfo = resInfo .. "UI Scale: |cffcccccc" .. string.format("%.1f%%", uiScale * 100) .. "|r\n\n"
                            end
                            
                            if screenWidth == refWidth and screenHeight == refHeight then
                                return resInfo .. "|cff00ff00Your UI resolution matches the default layout resolution (" .. refWidth .. "x" .. refHeight .. ").|r\n" ..
                                       "|cffccccccThis is the standard effective resolution when your game is set to 2560x1440 with 'Use UI Scale' OFF.|r\n" ..
                                       "No scaling needed!"
                            else
                                return resInfo .. "Default layout resolution: " .. refWidth .. "x" .. refHeight .. "\n" ..
                                       "|cffcccccc(Standard for 2560x1440 with 'Use UI Scale' OFF)|r\n\n" ..
                                       "|cffaaaaIf you imported a profile from someone using " .. refWidth .. "x" .. refHeight .. ", use the button below to automatically scale all element positions to your UI resolution.|r"
                            end
                        end,
                        order = 1.01,
                        fontSize = "medium",
                    },
                    scaleToResolution = {
                        type = "execute",
                        name = "Scale Layout Resolution",
                        desc = "Automatically adjusts all element positions from 2133x1200 to your current resolution",
                        order = 1.02,
                        func = function()
                            MidnightUI:ScaleLayoutToResolution()
                        end,
                        confirm = function()
                            local screenWidth = math.floor(GetScreenWidth())
                            local screenHeight = math.floor(GetScreenHeight())
                            return "This will scale all UI element positions from " .. MidnightUI.REFERENCE_WIDTH .. "x" .. MidnightUI.REFERENCE_HEIGHT .. " to " .. screenWidth .. "x" .. screenHeight .. " and reload your UI. Continue?"
                        end,
                    },
                    fontHeaderSpacer = {
                        type = "description",
                        name = " ",
                        order = 1.095,
                    },
                    fontHeader = {
                        type = "header",
                        name = "Global Font",
                        order = 1.1,
                    },
                    globalFont = {
                        type = "select",
                        name = "Global Font",
                        desc = "Select a font to apply to all MidnightUI elements.",
                        order = 1.11,
                        values = function()
                            local fonts = LSM:List("font")
                            local out = {}
                            for _, font in ipairs(fonts) do out[font] = font end
                            return out
                        end,
                        get = function() return self.db.profile.theme.font or "Friz Quadrata TT" end,
                        set = function(_, v) self.db.profile.theme.font = v end,
                    },
                    applyGlobalFont = {
                        type = "execute",
                        name = "Apply to All",
                        desc = "Apply the selected global font to all MidnightUI modules and bars.",
                        order = 1.12,
                        func = function()
                            local font = MidnightUI.db.profile.theme.font or "Friz Quadrata TT"
                            -- UnitFrames
                            if _G.UnitFrames and _G.UnitFrames.db and _G.UnitFrames.db.profile then
                                local uf = _G.UnitFrames.db.profile
                                for _, frame in pairs({"player", "target", "targettarget"}) do
                                    for _, bar in pairs({"health", "power", "info"}) do
                                        if uf[frame] and uf[frame][bar] then
                                            uf[frame][bar].font = font
                                        end
                                    end
                                end
                            end
                            -- Bar module: set all bar fonts to global and update
                            if _G.Bar and _G.Bar.db and _G.Bar.db.profile and _G.Bar.db.profile.bars then
                                for barID, barData in pairs(_G.Bar.db.profile.bars) do
                                    barData.font = font
                                end
                                if _G.Bar.UpdateAllFonts then
                                    _G.Bar:UpdateAllFonts()
                                end
                            end
                            -- Cooldowns module
                            if _G.Cooldowns and _G.Cooldowns.db and _G.Cooldowns.db.profile then
                                _G.Cooldowns.db.profile.font = font
                            end
                            -- Maps module
                            if _G.Maps and _G.Maps.db and _G.Maps.db.profile then
                                _G.Maps.db.profile.font = font
                            end
                            -- ActionBars module
                            if _G.ActionBars and _G.ActionBars.db and _G.ActionBars.db.profile then
                                _G.ActionBars.db.profile.font = font
                            end
                            -- UIButtons module
                            if _G.UIButtons and _G.UIButtons.db and _G.UIButtons.db.profile then
                                _G.UIButtons.db.profile.font = font
                            end
                            -- Tweaks module
                            if _G.Tweaks and _G.Tweaks.db and _G.Tweaks.db.profile then
                                _G.Tweaks.db.profile.font = font
                            end
                            -- Skins module
                            if _G.Skins and _G.Skins.db and _G.Skins.db.profile then
                                _G.Skins.db.profile.font = font
                            end
                            -- Movable module
                            if _G.Movable and _G.Movable.db and _G.Movable.db.profile then
                                _G.Movable.db.profile.font = font
                            end
                            -- Force UI update for UnitFrames
                            if _G.UnitFrames and _G.UnitFrames.UpdateUnitFrame then
                                _G.UnitFrames:UpdateUnitFrame("PlayerFrame", "player")
                                _G.UnitFrames:UpdateUnitFrame("TargetFrame", "target")
                                _G.UnitFrames:UpdateUnitFrame("TargetTargetFrame", "targettarget")
                            end
                            -- Add update calls for other modules as needed
                        end,
                    },
                    modulesHeaderSpacer = {
                        type = "description",
                        name = " ",
                        order = 1.995,
                    },
                    modulesHeader = { type = "header", order = 2.0, name = "Modules" },
                    modulesDesc = { type = "description", order = 2.01, name = "Toggle modules. Requires Reload." },
                    bar = { name = "Data Brokers", type = "toggle", order = 2.1, width = "full",
                        get = function() return self.db.profile.modules.bar end,
                        set = function(_, v) self.db.profile.modules.bar = v; C_UI.Reload() end },
                    UIButtons = { name = "UI Buttons", type = "toggle", order = 2.2, width = "full",
                        get = function() return self.db.profile.modules.UIButtons end,
                        set = function(_, v) self.db.profile.modules.UIButtons = v; C_UI.Reload() end },
                    tooltips = { name = "Tooltips", type = "toggle", order = 2.25, width = "full",
                        get = function() return self.db.profile.modules.tooltips end,
                        set = function(_, v) self.db.profile.modules.tooltips = v; C_UI.Reload() end },
                    mailbox = { name = "Mailbox", type = "toggle", order = 2.27, width = "full",
                        get = function() return self.db.profile.modules.mailbox end,
                        set = function(_, v) self.db.profile.modules.mailbox = v; C_UI.Reload() end },
                    chatcopy = { name = "Chat Copy", type = "toggle", order = 2.3, width = "full",
                        get = function() return self.db.profile.modules.chatcopy ~= false end,
                        set = function(_, v) self.db.profile.modules.chatcopy = v; C_UI.Reload() end },
                    maps = { name = "Maps", type = "toggle", order = 2.4, width = "full",
                        get = function() return self.db.profile.modules.maps end,
                        set = function(_, v) self.db.profile.modules.maps = v; C_UI.Reload() end },
                    actionbars = { name = "Action Bars", type = "toggle", order = 2.5, width = "full",
                        get = function() return self.db.profile.modules.actionbars end,
                        set = function(_, v) self.db.profile.modules.actionbars = v; C_UI.Reload() end },
                    unitframes = { name = "Unit Frames", type = "toggle", order = 2.6, width = "full",
                        get = function() return self.db.profile.modules.unitframes end,
                        set = function(_, v) self.db.profile.modules.unitframes = v; C_UI.Reload() end },
                    cooldowns = { name = "Cooldown Manager", type = "toggle", order = 2.7, width = "full",
                        desc = "Skins and enhances Blizzard's cooldown display manager.",
                        get = function() return self.db.profile.modules.cooldowns end,
                        set = function(_, v) 
                            self.db.profile.modules.cooldowns = v
                            C_UI.Reload()
                        end },
                    resourceBars = { name = "Resource Bars", type = "toggle", order = 2.71, width = "full",
                        desc = "Display primary and secondary resource bars (mana, energy, combo points, etc.)",
                        get = function() return self.db.profile.modules.resourceBars end,
                        set = function(_, v) self.db.profile.modules.resourceBars = v; C_UI.Reload() end },
                    castBar = { name = "Cast Bar", type = "toggle", order = 2.72, width = "full",
                        desc = "Display a custom player cast bar",
                        get = function() return self.db.profile.modules.castBar end,
                        set = function(_, v) self.db.profile.modules.castBar = v; C_UI.Reload() end },
                    tweaks = { name = "Tweaks", type = "toggle", order = 9, width = "full",
                        get = function() return self.db.profile.modules.tweaks end,
                        set = function(_, v) self.db.profile.modules.tweaks = v; C_UI.Reload() end }
                }  -- closes args table for general
            },  -- closes general group
            themes = {
                name = "Themes",
                type = "group",
                order = 40,
                args = self:GetThemeOptions(),
            },  -- closes themes group
            export = {
                name = "Export",
                type = "group",
                order = 50,
                args = {
                    header = {
                        type = "header",
                        name = "Export Profile",
                        order = 1,
                    },
                    description = {
                        type = "description",
                        name = "Export your entire MidnightUI configuration to a string that can be shared with others or saved as a backup.",
                        order = 2,
                        fontSize = "medium",
                    },
                    exportButton = {
                        type = "execute",
                        name = "Generate Export String",
                        desc = "Creates an export string of your current profile",
                        order = 3,
                        func = function()
                            MidnightUI:ExportProfile()
                        end,
                    },
                    spacer = {
                        type = "description",
                        name = " ",
                        order = 3.5,
                    },
                    exportString = {
                        type = "input",
                        name = "Export String (Ctrl+A to select all, Ctrl+C to copy)",
                        desc = "Copy this entire string to share your profile",
                        order = 4,
                        width = "full",
                        multiline = 25,
                        get = function() 
                            return MidnightUI.exportString or ""
                        end,
                        set = function() end,
                    },
                },
            },
            import = {
                name = "Import",
                type = "group",
                order = 51,
                args = {
                    header = {
                        type = "header",
                        name = "Import Profile",
                        order = 1,
                    },
                    description = {
                        type = "description",
                        name = "Import a MidnightUI configuration string.",
                        order = 2,
                        fontSize = "medium",
                    },
                    newProfileName = {
                        type = "input",
                        name = "New Profile Name (Optional)",
                        desc = "Leave empty to overwrite current profile, or enter a name to create a new profile",
                        order = 3,
                        width = "full",
                        get = function() 
                            -- Store in both places to prevent clearing
                            if not MidnightUI.importNewProfileName then
                                MidnightUI.importNewProfileName = ""
                            end
                            return MidnightUI.importNewProfileName 
                        end,
                        set = function(_, v) 
                            MidnightUI.importNewProfileName = v 
                        end,
                    },
                    warning = {
                        type = "description",
                        name = function()
                            local name = MidnightUI.importNewProfileName
                            if name and name ~= "" then
                                return "|cff00ff00Profile will be imported as: '|r" .. name .. "|cff00ff00'|r"
                            else
                                local currentProfile = MidnightUI.db and MidnightUI.db:GetCurrentProfile() or "Default"
                                return "|cffff8800WARNING: This will overwrite your current profile '|r" .. currentProfile .. "|cffff8800'|r"
                            end
                        end,
                        order = 3.5,
                        fontSize = "medium",
                    },
                    importString = {
                        type = "input",
                        name = "Import String",
                        desc = "Paste the export string here (Ctrl+V to paste)\n|cffaaaaaa" .. (MidnightUI.importString and "Current length: " .. #MidnightUI.importString .. " characters" or "") .. "|r",
                        order = 4,
                        width = "full",
                        multiline = 20,
                        get = function() 
                            if not MidnightUI.importString then
                                MidnightUI.importString = ""
                            end
                            return MidnightUI.importString 
                        end,
                        set = function(_, v) 
                            -- Store the full string value
                            MidnightUI.importString = v
                            -- Delayed refresh to avoid interrupting the input
                            C_Timer.After(0.1, function()
                                local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
                                if AceConfigRegistry then
                                    AceConfigRegistry:NotifyChange("MidnightUI")
                                end
                            end)
                        end,
                    },
                    stringInfo = {
                        type = "description",
                        name = function()
                            local str = MidnightUI.importString
                            if str and #str > 0 then
                                return "|cffaaaaaa" .. #str .. " characters stored|r"
                            else
                                return ""
                            end
                        end,
                        order = 4.5,
                        fontSize = "small",
                    },
                    importButton = {
                        type = "execute",
                        name = "Import Profile",
                        desc = "Import the profile from the string above. Requires UI reload.",
                        order = 5,
                        func = function()
                            MidnightUI:ImportProfile()
                        end,
                    },
                },
            },
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
        }  -- closes main args table
    }  -- closes options table
    
    options.args.profiles.order = 100
    
    -- Inject Module Options
    for name, module in self:IterateModules() do
        -- Map module names to their database keys
        local dbKey = name
        if name == "UIButtons" then 
            dbKey = "UIButtons"
        elseif name == "Skin" then
            dbKey = "skins"
        elseif name == "BrokerBar" then
            dbKey = "bar"
        elseif name == "Maps" then
            dbKey = "maps"
        elseif name == "ActionBars" then
            dbKey = "actionbars"
        elseif name == "UnitFrames" then
            dbKey = "unitframes"
        elseif name == "Cooldowns" then
            dbKey = "cooldowns"
        elseif name == "Tweaks" then
            dbKey = "tweaks"
        elseif name == "Setup" then
            dbKey = "setup"
        elseif name == "ResourceBars" then
            dbKey = "resourceBars"
        elseif name == "CastBar" then
            dbKey = "castBar"
        else
            dbKey = string.lower(name)
        end
        
        if module.GetOptions and self.db.profile.modules[dbKey] then
            local displayName = name
            if name == "UIButtons" then 
                displayName = "UI Buttons"
            elseif name == "Skin" then
                displayName = "Skinning"
            elseif name == "BrokerBar" then 
                displayName = "Data Brokers"
            elseif name == "Cooldowns" then
                displayName = "Cooldown Manager"
            end
            if name == "UnitFrames" then
                options.args.unitframes = module:GetOptions()
                options.args.unitframes.name = "Unit Frames"
                options.args.unitframes.order = 8
            elseif name == "Setup" then
                options.args[name] = module:GetOptions()
                options.args[name].name = displayName
                options.args[name].order = 45
            else
                options.args[name] = module:GetOptions()
                options.args[name].name = displayName
                options.args[name].order = 10
            end
        end
    end
    
    return options
end

-- Add Move Mode property
MidnightUI.moveMode = false

-- Add Move Mode toggle function
function MidnightUI:ToggleMoveMode()
    self.moveMode = not self.moveMode
    
    if self.moveMode then
        print("|cff00ff00MidnightUI:|r Move Mode |cff00ff00ENABLED|r - Hover over elements to move them")
    else
        print("|cff00ff00MidnightUI:|r Move Mode |cffff0000DISABLED|r")
    end
    
    -- Use AceEvent's SendMessage (already loaded)
    self:SendMessage("MIDNIGHTUI_MOVEMODE_CHANGED", self.moveMode)
    -- Directly call Movable:OnMoveModeChanged for reliability
    local Movable
    if self.GetModule then
        Movable = self:GetModule("Movable", true)
    end
    if Movable and Movable.OnMoveModeChanged then
        Movable:OnMoveModeChanged("MIDNIGHTUI_MOVEMODE_CHANGED", self.moveMode)
    end
    
end

-- ============================================================================
-- 5. IMPORT/EXPORT FUNCTIONS
-- ============================================================================

-- Hex encoding functions (safe for copy/paste)
local function EncodeHex(str)
    return (str:gsub('.', function(c)
        return string.format('%02X', string.byte(c))
    end))
end

local function DecodeHex(hex)
    return (hex:gsub('..', function(cc)
        return string.char(tonumber(cc, 16))
    end))
end

-- Export Profile
function MidnightUI:ExportProfile()
    local AceSerializer = LibStub("AceSerializer-3.0")
    local LibCompress = LibStub("LibCompress")
    
    if not AceSerializer or not LibCompress then
        print("|cffff0000MidnightUI Error:|r Required libraries not found for export.")
        return
    end
    
    -- Get the entire database including all namespaces
    local exportData = {
        main = self.db.profile,
        namespaces = {}
    }
    
    -- Export all registered namespaces
    -- Use the children table which contains the actual namespace objects
    if self.db.children then
        local namespaceCount = 0
        
        for namespaceName, namespaceDB in pairs(self.db.children) do
            if namespaceDB and namespaceDB.profile then
                exportData.namespaces[namespaceName] = namespaceDB.profile
                namespaceCount = namespaceCount + 1
                print("|cff00ff00MidnightUI:|r   - Exporting: " .. namespaceName)
            end
        end
        print("|cff00ff00MidnightUI:|r Exported " .. namespaceCount .. " module namespaces")
    else
        print("|cffff8800MidnightUI Warning:|r No namespace objects found to export")
    end
    
    -- Serialize the data
    local serialized = AceSerializer:Serialize(exportData)
    
    -- Compress the serialized data
    local compressed = LibCompress:Compress(serialized)
    if not compressed then
        print("|cffff0000MidnightUI Error:|r Failed to compress export data.")
        return
    end
    
    -- Encode to hex (safe for copy/paste)
    local encoded = EncodeHex(compressed)
    
    -- Add version header
    local exportString = "MUIV2:" .. encoded
    
    -- Store for display
    self.exportString = exportString
    MidnightUI.exportString = exportString
    
    print("|cff00ff00MidnightUI:|r Export string generated!")
    print("|cff00ff00MidnightUI:|r String length: " .. #exportString .. " characters")
    print("|cff00ff00MidnightUI:|r Use Ctrl+A to select all, then Ctrl+C to copy.")
    
    -- Refresh the options UI
    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    AceConfigRegistry:NotifyChange("MidnightUI")
end

-- Import Profile
function MidnightUI:ImportProfile()
    local AceSerializer = LibStub("AceSerializer-3.0")
    local LibCompress = LibStub("LibCompress")
    
    if not AceSerializer or not LibCompress then
        print("|cffff0000MidnightUI Error:|r Required libraries not found for import.")
        return
    end
    
    local importString = self.importString
    
    if not importString or importString == "" then
        print("|cffff0000MidnightUI Error:|r No import string provided.")
        return
    end
    
    -- Show length for debugging
    print("|cff00ff00MidnightUI:|r Processing import string (" .. #importString .. " characters)")
    
    -- Check if user wants to create a new profile
    local newProfileName = self.importNewProfileName
    if newProfileName and newProfileName ~= "" then
        -- Trim whitespace
        newProfileName = newProfileName:match("^%s*(.-)%s*$")
    end
    
    if not newProfileName or newProfileName == "" then
        -- Show confirmation dialog before overwriting current profile
        local currentProfileName = self.db:GetCurrentProfile()
        StaticPopupDialogs["MIDNIGHTUI_IMPORT_CONFIRM"] = {
            text = "This will OVERWRITE your current profile '" .. currentProfileName .. "'!\n\nAre you sure you want to continue?",
            button1 = "Yes, Import",
            button2 = "Cancel",
            OnAccept = function()
                MidnightUI:DoImport(importString, nil)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("MIDNIGHTUI_IMPORT_CONFIRM")
    else
        -- Creating new profile - show confirmation with profile name
        StaticPopupDialogs["MIDNIGHTUI_IMPORT_NEW"] = {
            text = "This will create a new profile '" .. newProfileName .. "' and switch to it.\n\nAre you sure you want to continue?",
            button1 = "Yes, Import",
            button2 = "Cancel",
            OnAccept = function()
                MidnightUI:DoImport(importString, newProfileName)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("MIDNIGHTUI_IMPORT_NEW")
    end
end

-- Actually perform the import
function MidnightUI:DoImport(importString, newProfileName, suppressDialog)
    local AceSerializer = LibStub("AceSerializer-3.0")
    local LibCompress = LibStub("LibCompress")
    
    if not AceSerializer or not LibCompress then
        print("|cffff0000MidnightUI Error:|r Required libraries not found for import.")
        return
    end
    
    -- Check for version header
    if not importString:match("^MUIV2:") then
        print("|cffff0000MidnightUI Error:|r Invalid import string format.")
        return
    end
    
    -- Remove version header
    local encoded = importString:sub(7) -- Remove "MUIV2:"
    
    -- Decode from hex
    local success, compressed = pcall(DecodeHex, encoded)
    if not success or not compressed then
        print("|cffff0000MidnightUI Error:|r Failed to decode import string.")
        return
    end
    
    -- Decompress
    local serialized, err = LibCompress:Decompress(compressed)
    if not serialized then
        print("|cffff0000MidnightUI Error:|r Failed to decompress import data: " .. tostring(err or "unknown error"))
        return
    end
    
    -- Deserialize
    local success, exportData = AceSerializer:Deserialize(serialized)
    if not success or not exportData then
        print("|cffff0000MidnightUI Error:|r Failed to deserialize import data.")
        return
    end
    
    -- Handle old format (direct profile data) or new format (structured with namespaces)
    local profileData = exportData.main or exportData
    local namespaceData = exportData.namespaces or {}
    
    local namespaceCount = 0
    for _ in pairs(namespaceData) do
        namespaceCount = namespaceCount + 1
    end
    print("|cff00ff00MidnightUI:|r Import contains " .. namespaceCount .. " module namespaces")
    
    -- Check if user wants to create a new profile
    if newProfileName and newProfileName ~= "" then
        -- Create new profile with the imported data
        self.db:SetProfile(newProfileName)
        
        -- Apply the imported main profile data
        for key, value in pairs(profileData) do
            self.db.profile[key] = value
        end
        
        -- Apply namespace data by getting or creating namespace objects
        if self.db.children then
            local appliedCount = 0
            for namespaceName, data in pairs(namespaceData) do
                local namespace = self.db:GetNamespace(namespaceName, true)
                if namespace then
                    -- Copy all data to the namespace profile
                    for key, value in pairs(data) do
                        namespace.profile[key] = value
                    end
                    appliedCount = appliedCount + 1
                    print("|cff00ff00MidnightUI:|r   - Applied: " .. namespaceName)
                end
            end
            print("|cff00ff00MidnightUI:|r Applied " .. appliedCount .. " module namespaces")
        end
        
        print("|cff00ff00MidnightUI:|r Profile imported as '" .. newProfileName .. "'!")
    else
        -- Overwrite current profile
        local currentProfileName = self.db:GetCurrentProfile()
        
        -- Apply the imported main profile data
        for key, value in pairs(profileData) do
            self.db.profile[key] = value
        end
        
        -- Apply namespace data by getting namespace objects
        if self.db.children then
            local appliedCount = 0
            for namespaceName, data in pairs(namespaceData) do
                local namespace = self.db:GetNamespace(namespaceName, true)
                if namespace then
                    -- Copy all data to the namespace profile
                    for key, value in pairs(data) do
                        namespace.profile[key] = value
                    end
                    appliedCount = appliedCount + 1
                    print("|cff00ff00MidnightUI:|r   - Applied: " .. namespaceName)
                end
            end
            print("|cff00ff00MidnightUI:|r Applied " .. appliedCount .. " module namespaces")
        end
        
        print("|cff00ff00MidnightUI:|r Profile '" .. currentProfileName .. "' updated!")
    end
    
    -- Show reload dialog (unless suppressed by caller)
    if not suppressDialog then
        StaticPopupDialogs["MIDNIGHTUI_IMPORT_RELOAD"] = {
            text = "Profile imported successfully!\n\nReload UI now to apply changes?",
            button1 = "Reload Now",
            button2 = "Later",
            OnAccept = function()
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("MIDNIGHTUI_IMPORT_RELOAD")
    end
end

