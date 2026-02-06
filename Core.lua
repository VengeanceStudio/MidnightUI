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
            active = "MidnightGlass",  -- Active framework theme
            font = "Friz Quadrata TT",
            fontSize = 12,
            bgColor = {0.1, 0.1, 0.1, 0.8},
            borderColor = {0, 0, 0, 1},
        },
        modules = {
            skins = true,
            bar = true,
            UIButtons = true,
            maps = true,
            actionbars = true,
            unitframes = true,
            cooldowns = false,
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
            for i, tab in pairs(widget.tabs) do
                -- Function to hide Blizzard textures
                local function HideTabTextures(t)
                    for _, region in ipairs({t:GetRegions()}) do
                        if region:GetObjectType() == "Texture" and region ~= t.text then
                            region:Hide()
                        end
                    end
                end
                
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
                    tab:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8",
                        tile = false, edgeSize = 1,
                        insets = { left = 1, right = 1, top = 1, bottom = 1 }
                    })
                    
                    -- Check if this tab is selected
                    local isSelected = (widget.selected == tab.value)
                    if isSelected then
                        -- Selected tab: brighter background, accent border
                        local r, g, b, a = ColorPalette:GetColor('button-bg')
                        tab:SetBackdropColor(r * 1.5, g * 1.5, b * 1.5, a)
                        tab:SetBackdropBorderColor(0.1608, 0.5216, 0.5804, 1) -- Teal accent
                    else
                        -- Unselected tab: normal colors
                        tab:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                        tab:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
                    end
                end
                
                if tab.text and FontKit then
                    FontKit:SetFont(tab.text, 'button', 'normal')
                    tab.text:SetTextColor(ColorPalette:GetColor('text-primary'))
                end
                
                -- Hook tab click to update styling
                if not tab.customTabHooked then
                    tab:HookScript("OnClick", function()
                        -- Reskin all tabs to update selected state
                        for _, t in pairs(widget.tabs) do
                            -- Hide Blizzard textures again
                            HideTabTextures(t)
                            
                            if t.SetBackdrop then
                                local selected = (widget.selected == t.value)
                                if selected then
                                    local r, g, b, a = ColorPalette:GetColor('button-bg')
                                    t:SetBackdropColor(r * 1.5, g * 1.5, b * 1.5, a)
                                    t:SetBackdropBorderColor(0.1608, 0.5216, 0.5804, 1)
                                else
                                    t:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                                    t:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
                                end
                            end
                        end
                    end)
                    
                    -- Also hook OnShow to prevent textures from reappearing
                    tab:HookScript("OnShow", function()
                        HideTabTextures(tab)
                    end)
                    
                    tab.customTabHooked = true
                end
            end
        end
        
    elseif widgetType == "InlineGroup" or widgetType == "SimpleGroup" or widgetType == "TreeGroup" then
        if widget.content and widget.content:GetObjectType() == "Frame" then
            if widget.content.SetBackdrop then
                widget.content:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, edgeSize = 1,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 }
                })
                widget.content:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
                widget.content:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
            end
        end
        
        -- Add top padding to TreeGroup tree container
        if widgetType == "TreeGroup" and widget.treeframe then
            widget.treeframe:ClearAllPoints()
            widget.treeframe:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 0, -70)
            widget.treeframe:SetPoint("BOTTOMLEFT", widget.frame, "BOTTOMLEFT", 0, 0)
        end
        
    elseif widgetType == "Button" then
        if widget.frame then
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
                        widget.frame:SetBackdropBorderColor(0.1608, 0.5216, 0.5804, 1)
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
                            widget.toggleBg:SetVertexColor(0.1608, 0.5216, 0.5804, 1)
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
                    widget.toggleBg:SetVertexColor(0.1608, 0.5216, 0.5804, 1)
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
        if widget.slider then
            -- Style the slider track
            if widget.slider.SetBackdrop then
                widget.slider:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, edgeSize = 1,
                    insets = { left = 0, right = 0, top = 0, bottom = 0 }
                })
                widget.slider:SetBackdropColor(ColorPalette:GetColor('input-bg'))
                widget.slider:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
            end
            
            -- Style the thumb
            widget.slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
            local thumb = widget.slider:GetThumbTexture()
            if thumb then
                thumb:SetVertexColor(ColorPalette:GetColor('accent-primary'))
                thumb:SetSize(12, 20)
            end
        end
        
        if widget.label and FontKit then
            FontKit:SetFont(widget.label, 'body', 'normal')
            widget.label:SetTextColor(ColorPalette:GetColor('text-primary'))
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
                widget.editbox:SetBackdropColor(ColorPalette:GetColor('input-bg'))
                widget.editbox:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
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
            -- Move dropdown frame slightly right to prevent border cutoff
            local point, relativeTo, relativePoint, xOfs, yOfs = widget.frame:GetPoint()
            if point and xOfs and yOfs then
                widget.frame:ClearAllPoints()
                widget.frame:SetPoint(point, relativeTo, relativePoint, xOfs + 17, yOfs)
            end
        end
        
        if widget.dropdown then
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
                widget.dropdown:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                widget.dropdown:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                widget.dropdown:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
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
                    widget.button:HookScript("OnShow", ClearButtonTextures)
                    widget.button:HookScript("OnUpdate", ClearButtonTextures)
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
                            tile = false, edgeSize = 2,
                            insets = { left = 2, right = 2, top = 2, bottom = 2 }
                        })
                        widget.dropdown:SetBackdropColor(ColorPalette:GetColor('button-bg'))
                        widget.dropdown:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
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
                                    tile = false, edgeSize = 2,
                                    insets = { left = 0, right = 0, top = 0, bottom = 0 }
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
                            
                            -- Hide all frame textures
                            for _, region in ipairs({frame:GetRegions()}) do
                                if region:GetObjectType() == "Texture" then
                                    region:SetTexture(nil)
                                    region:Hide()
                                end
                            end
                            
                            if frame.SetBackdrop then
                                frame:SetBackdrop({
                                    bgFile = "Interface\\Buttons\\WHITE8X8",
                                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                                    tile = false, edgeSize = 2,
                                    insets = { left = 0, right = 0, top = 0, bottom = 0 }
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
                                    
                                    -- Style item text
                                    if item.text and FontKit then
                                        FontKit:SetFont(item.text, 'body', 'normal')
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
                    end
                end
            end
            widget.customPulloutSetup = true
        end
        
        if widget.text and FontKit then
            FontKit:SetFont(widget.text, 'body', 'normal')
            widget.text:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
        
        if widget.label and FontKit then
            FontKit:SetFont(widget.label, 'body', 'normal')
            widget.label:SetTextColor(ColorPalette:GetColor('text-primary'))
            
            -- Adjust label position for Active Theme and Global Font dropdowns
            local labelText = widget.label:GetText()
            if labelText and (labelText:find("Active Theme") or labelText:find("Global Font")) then
                if not widget.customLabelMoved then
                    local point, relativeTo, relativePoint, xOfs, yOfs = widget.label:GetPoint()
                    if point and xOfs and yOfs then
                        widget.label:ClearAllPoints()
                        widget.label:SetPoint(point, relativeTo, relativePoint, xOfs - 15, yOfs + 3)
                        widget.customLabelMoved = true
                    end
                end
            end
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
    end
end

function MidnightUI:HookConfigDialogFrames()
    local AceGUI = LibStub("AceGUI-3.0")
    if not AceGUI then return end
    
    -- Hook AceGUI:Create to skin widgets as they're created
    local oldCreate = AceGUI.Create
    AceGUI.Create = function(self, widgetType)
        local widget = oldCreate(self, widgetType)
        if widget then
            C_Timer.After(0, function()
                MidnightUI:SkinAceGUIWidget(widget, widgetType)
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
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    
    frame:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
    frame:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Skin the title frame and text
    if frame.obj then
        -- Add logo texture
        if not frame.logoTexture then
            frame.logoTexture = frame:CreateTexture(nil, "ARTWORK")
            frame.logoTexture:SetTexture("Interface\\AddOns\\MidnightUI\\Media\\midnightUI_icon.tga")
            frame.logoTexture:SetSize(40, 40)
            frame.logoTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -18)
        end
        
        -- Find and skin title text
        for _, region in ipairs({frame:GetRegions()}) do
            if region:GetObjectType() == "FontString" then
                -- Make title larger and reposition next to logo
                region:SetFont("Fonts\\FRIZQT__.TTF", 28, "OUTLINE")
                region:SetTextColor(ColorPalette:GetColor('text-primary'))
                region:ClearAllPoints()
                region:SetPoint("LEFT", frame.logoTexture, "RIGHT", 12, 0)
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
        
        -- Hide the status bar (placeholder bar before close button)
        if frame.obj.statusbg then
            frame.obj.statusbg:Hide()
        end
        if frame.obj.statustext then
            frame.obj.statustext:Hide()
        end
    end
    
    -- Skin the close button if it exists
    if frame.obj and frame.obj.closebutton then
        local closeBtn = frame.obj.closebutton
        if ColorPalette then
            closeBtn:SetNormalTexture("")
            closeBtn:SetPushedTexture("")
            closeBtn:SetHighlightTexture("")
            
            local text = closeBtn:CreateFontString(nil, "OVERLAY")
            text:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
            text:SetText("×")
            text:SetPoint("CENTER", 0, 1)
            text:SetTextColor(ColorPalette:GetColor('text-primary'))
        end
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
        tile = false, tileSize = 0, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
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
function MidnightUI:GetOptions()
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
                    themeHeader = { type = "header", order = 0.7, name = "UI Theme" },
                    themeSelect = {
                        type = "select",
                        name = "Active Theme",
                        desc = "Choose the visual theme for MidnightUI framework components.",
                        order = 0.8,
                        values = {
                            ["MidnightGlass"] = "Midnight Dark Glass",
                            ["NeonSciFi"] = "Neon Sci-Fi",
                        },
                        get = function(info) return self.db.profile.theme.active end,
                        set = function(info, value)
                            self.db.profile.theme.active = value
                            if self.FrameFactory then
                                self.FrameFactory:SetTheme(value)
                            end
                            if self.ColorPalette then
                                self.ColorPalette:SetActiveTheme(value)
                            end
                            if self.FontKit then
                                self.FontKit:SetActiveTheme(value)
                            end
                            self:Print("Theme changed to " .. value .. ". Some changes may require a /reload to take full effect.")
                        end,
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
                                resInfo = resInfo .. "Physical Resolution: |cffcccccc" .. physicalWidth .. "x" .. physicalHeight .. "|r\n"
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
                        name = "Scale Layout to My Resolution",
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
                    modulesHeader = { type = "header", order = 2.0, name = "Modules" },
                    modulesDesc = { type = "description", order = 2.01, name = "Toggle modules. Requires Reload." },
                    bar = { name = "Data Brokers", type = "toggle", order = 2.1, width = "full",
                        get = function() return self.db.profile.modules.bar end,
                        set = function(_, v) self.db.profile.modules.bar = v; C_UI.Reload() end },
                    UIButtons = { name = "UI Buttons", type = "toggle", order = 2.2, width = "full",
                        get = function() return self.db.profile.modules.UIButtons end,
                        set = function(_, v) self.db.profile.modules.UIButtons = v; C_UI.Reload() end },
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
                        desc = "Work in progress - Cannot be enabled at this time.",
                        get = function() return self.db.profile.modules.cooldowns end,
                        set = function(_, v)
                            if v then
                                print("|cffff6b6b[MidnightUI]|r Cooldown Manager is a work in progress and cannot be enabled at this time.")
                                return
                            end
                            self.db.profile.modules.cooldowns = v
                            C_UI.Reload()
                        end },
                    tweaks = { name = "Tweaks", type = "toggle", order = 9, width = "full",
                        get = function() return self.db.profile.modules.tweaks end,
                        set = function(_, v) self.db.profile.modules.tweaks = v; C_UI.Reload() end }
                }  -- closes args table for general
            },  -- closes general group
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
            end
            if name == "UnitFrames" then
                options.args.unitframes = module:GetOptions()
                options.args.unitframes.name = "Unit Frames"
                options.args.unitframes.order = 8
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

