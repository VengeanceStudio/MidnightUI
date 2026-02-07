local Type, Version = "MidnightMultiLineEditBox", 34
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local pairs = pairs

-- WoW APIs
local GetCursorInfo, ClearCursor = GetCursorInfo, ClearCursor
local CreateFrame, UIParent = CreateFrame, UIParent
local _G = _G

-- Get our color palette
local ColorPalette = MidnightUI and MidnightUI.ColorPalette or {
    GetColor = function(_, key)
        local colors = {
            ['text-primary'] = {0.82, 0.82, 0.82},
            ['accent-primary'] = {0.16, 0.52, 0.58},
            ['button-bg'] = {0.15, 0.15, 0.15},
            ['panel-bg'] = {0.1, 0.1, 0.1},
        }
        return unpack(colors[key] or {1, 1, 1})
    end
}

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]

if not AceGUIMultiLineEditBoxInsertLink then
	-- upgradeable hook
	if ChatFrameUtil and ChatFrameUtil.InsertLink then
		hooksecurefunc(ChatFrameUtil, "InsertLink", function(...) return _G.AceGUIMultiLineEditBoxInsertLink(...) end)
	elseif ChatEdit_InsertLink then
		hooksecurefunc("ChatEdit_InsertLink", function(...) return _G.AceGUIMultiLineEditBoxInsertLink(...) end)
	end
end

function _G.AceGUIMultiLineEditBoxInsertLink(text)
	for i = 1, AceGUI:GetWidgetCount("MultiLineEditBox") do
		local editbox = _G[("MultiLineEditBox%uEdit"):format(i)]
		if editbox and editbox:IsVisible() and editbox:HasFocus() then
			editbox:Insert(text)
			return true
		end
	end
	-- Also check our custom widget
	for i = 1, AceGUI:GetWidgetCount(Type) do
		local editbox = _G[("MidnightMultiLineEditBox%uEdit"):format(i)]
		if editbox and editbox:IsVisible() and editbox:HasFocus() then
			editbox:Insert(text)
			return true
		end
	end
end


local function Layout(self)
	self:SetHeight(self.numlines * 14 + (self.disablebutton and 19 or 41) + self.labelHeight)

	if self.labelHeight == 0 then
		self.scrollBar:SetPoint("TOP", self.frame, "TOP", 0, -23)
	else
		self.scrollBar:SetPoint("TOP", self.label, "BOTTOM", 0, -19)
	end

	if self.disablebutton then
		self.scrollBar:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 21)
		self.scrollBG:SetPoint("BOTTOMLEFT", 0, 4)
	else
		self.scrollBar:SetPoint("BOTTOM", self.button, "TOP", 0, 18)
		self.scrollBG:SetPoint("BOTTOMLEFT", self.button, "TOPLEFT")
	end
end

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function OnClick(self)                                                     -- Button
	self = self.obj
	self.editBox:ClearFocus()
	if not self:Fire("OnEnterPressed", self.editBox:GetText()) then
		self.button:Disable()
	end
end

local function OnCursorChanged(self, _, y, _, cursorHeight)                      -- EditBox
	self, y = self.obj.scrollFrame, -y
	local offset = self:GetVerticalScroll()
	if y < offset then
		self:SetVerticalScroll(y)
	else
		y = y + cursorHeight - self:GetHeight()
		if y > offset then
			self:SetVerticalScroll(y)
		end
	end
end

local function OnEditFocusLost(self)                                             -- EditBox
	self:HighlightText(0, 0)
	self.obj:Fire("OnEditFocusLost")
end

local function OnEnter(self)                                                     -- EditBox / ScrollFrame
	self = self.obj
	if not self.entered then
		self.entered = true
		self:Fire("OnEnter")
	end
end

local function OnLeave(self)                                                     -- EditBox / ScrollFrame
	self = self.obj
	if self.entered then
		self.entered = nil
		self:Fire("OnLeave")
	end
end

local function OnMouseUp(self)                                                   -- ScrollFrame
	self = self.obj.editBox
	self:SetFocus()
	self:SetCursorPosition(self:GetNumLetters())
end

local function OnReceiveDrag(self)                                               -- EditBox / ScrollFrame
	local type, id, info = GetCursorInfo()
	if type and id then
		self = self.obj
		self.editBox:Insert(info)
		ClearCursor()
	end
end

local function OnSizeChanged(self, width, height)                               -- ScrollFrame
	self.obj.editBox:SetWidth(width)
end

local function OnTextChanged(self, userInput)                                   -- EditBox
	if userInput then
		self = self.obj
		self:Fire("OnTextChanged", self.editBox:GetText())
		self.button:Enable()
	end
end

local function OnTextSet(self)                                                  -- EditBox
	self:HighlightText(0, 0)
	self:SetCursorPosition(self:GetNumLetters())
	self:SetCursorPosition(0)
	self.obj.button:Disable()
end

local function OnVerticalScroll(self, offset)                                   -- ScrollFrame
	local editBox = self:GetScrollChild()
	editBox:SetHitRectInsets(0, 0, offset, editBox:GetHeight() - offset - self:GetHeight())
end

local function OnScrollRangeChanged(self, xrange, yrange)
	if yrange == 0 then
		self.obj.editBox:SetHitRectInsets(0, 0, 0, 0)
	else
		OnVerticalScroll(self, self:GetVerticalScroll())
	end
end

local function OnShowFocus(self)
	self.obj.editBox:SetFocus()
	self:SetScript("OnShow", nil)
end

local function OnEditFocusGained(self)
	AceGUI:SetFocus(self.obj)
	self.obj:Fire("OnEditFocusGained")
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		self.editBox:SetText("")
		self:SetDisabled(false)
		self:SetWidth(200)
		self:SetNumLines(4)
		self:DisableButton(false)
		self.entered = nil
		self:SetMaxLetters(0)
		
		-- Re-style scrollbar on acquire (in case widget was recycled)
		if self.scrollBar and MidnightUI and MidnightUI.StyleScrollFrame then
			local scrollBar = self.scrollBar
			local scrollBarName = scrollBar:GetName()
			if scrollBarName then
				local upButton = _G[scrollBarName .. "ScrollUpButton"]
				local downButton = _G[scrollBarName .. "ScrollDownButton"]
				
				-- Attach buttons as properties
				scrollBar.ScrollUpButton = upButton
				scrollBar.ScrollDownButton = downButton
				
				-- Style the scrollbar
				local scrollFrameWidget = {
					scrollbar = scrollBar
				}
				MidnightUI:StyleScrollFrame(scrollFrameWidget)
			end
		end
	end,

	["OnRelease"] = function(self)
		self:ClearFocus()
	end,

	["SetDisabled"] = function(self, disabled)
		local editBox = self.editBox
		if disabled then
			editBox:ClearFocus()
			editBox:EnableMouse(false)
			editBox:SetTextColor(0.5, 0.5, 0.5)
			self.label:SetTextColor(0.5, 0.5, 0.5)
			self.button:Disable()
			self.scrollFrame:EnableMouse(false)
		else
			editBox:EnableMouse(true)
			editBox:SetTextColor(ColorPalette:GetColor('text-primary'))
			self.label:SetTextColor(ColorPalette:GetColor('text-primary'))
			self.scrollFrame:EnableMouse(true)
		end
	end,

	["SetLabel"] = function(self, text)
		if text and text ~= "" then
			self.label:SetText(text)
			self.label:Show()
			self.labelHeight = 10
		else
			self.label:SetText("")
			self.label:Hide()
			self.labelHeight = 0
		end
		Layout(self)
	end,

	["SetNumLines"] = function(self, value)
		if not value or value < 4 then
			value = 4
		end
		self.numlines = value
		Layout(self)
	end,

	["SetText"] = function(self, text)
		self.editBox:SetText(text)
	end,

	["GetText"] = function(self)
		return self.editBox:GetText()
	end,

	["SetMaxLetters"] = function (self, num)
		self.editBox:SetMaxLetters(num or 0)
	end,

	["DisableButton"] = function(self, disabled)
		self.disablebutton = disabled
		if disabled then
			self.button:Hide()
		else
			self.button:Show()
		end
		Layout(self)
	end,

	["ClearFocus"] = function(self)
		self.editBox:ClearFocus()
		self.frame:SetScript("OnShow", nil)
	end,

	["SetFocus"] = function(self)
		self.editBox:SetFocus()
		if not self.frame:IsShown() then
			self.frame:SetScript("OnShow", OnShowFocus)
		end
	end,

	["HighlightText"] = function(self, from, to)
		self.editBox:HighlightText(from, to)
	end,

	["GetCursorPosition"] = function(self)
		return self.editBox:GetCursorPosition()
	end,

	["SetCursorPosition"] = function(self, ...)
		return self.editBox:SetCursorPosition(...)
	end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local backdrop = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 }
}

local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:Hide()

	local widgetNum = AceGUI:GetNextWidgetNum(Type)

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -4)
	label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -4)
	label:SetJustifyH("LEFT")
	label:SetText(ACCEPT)
	label:SetHeight(10)
	label:SetTextColor(ColorPalette:GetColor('text-primary'))

	local button = CreateFrame("Button", ("%s%dButton"):format(Type, widgetNum), frame, BackdropTemplateMixin and "BackdropTemplate")
	button:SetPoint("BOTTOMLEFT", 0, 4)
	button:SetHeight(22)
	button:SetWidth(100)
	
	-- Style button with MidnightUI theme
	button:SetBackdrop(backdrop)
	button:SetBackdropColor(ColorPalette:GetColor('button-bg'))
	button:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
	
	-- Create button text
	local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	buttonText:SetPoint("CENTER")
	buttonText:SetText(ACCEPT)
	buttonText:SetTextColor(ColorPalette:GetColor('text-primary'))
	
	button:SetScript("OnClick", OnClick)
	button:Disable()
	
	-- Button hover effects
	button:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(1, 1, 1, 1)
	end)
	button:SetScript("OnLeave", function(self)
		self:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
	end)

	local scrollBG = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	scrollBG:SetBackdrop(backdrop)
	scrollBG:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
	scrollBG:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
	scrollBG:EnableMouse(false)  -- Don't intercept mouse clicks - let them pass through to editBox

	local scrollFrame = CreateFrame("ScrollFrame", ("%s%dScrollFrame"):format(Type, widgetNum), frame, "UIPanelScrollFrameTemplate")

	local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOP", label, "BOTTOM", 0, -19)
	scrollBar:SetPoint("BOTTOM", button, "TOP", 0, 18)
	scrollBar:SetPoint("RIGHT", frame, "RIGHT")

	scrollBG:SetPoint("TOPRIGHT", scrollBar, "TOPLEFT", 0, 19)
	scrollBG:SetPoint("BOTTOMLEFT", button, "TOPLEFT")

	scrollFrame:SetPoint("TOPLEFT", scrollBG, "TOPLEFT", 5, -6)
	scrollFrame:SetPoint("BOTTOMRIGHT", scrollBG, "BOTTOMRIGHT", -4, 4)
	scrollFrame:SetScript("OnEnter", OnEnter)
	scrollFrame:SetScript("OnLeave", OnLeave)
	scrollFrame:SetScript("OnMouseUp", OnMouseUp)
	scrollFrame:SetScript("OnReceiveDrag", OnReceiveDrag)
	scrollFrame:SetScript("OnSizeChanged", OnSizeChanged)
	scrollFrame:HookScript("OnVerticalScroll", OnVerticalScroll)
	scrollFrame:HookScript("OnScrollRangeChanged", OnScrollRangeChanged)

	local editBox = CreateFrame("EditBox", ("%s%dEdit"):format(Type, widgetNum), scrollFrame)
	editBox:SetAllPoints()
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetMultiLine(true)
	editBox:EnableMouse(true)
	editBox:SetAutoFocus(false)
	editBox:SetCountInvisibleLetters(false)
	editBox:SetTextColor(ColorPalette:GetColor('text-primary'))
	editBox:SetScript("OnCursorChanged", OnCursorChanged)
	editBox:SetScript("OnEditFocusLost", OnEditFocusLost)
	editBox:SetScript("OnEnter", OnEnter)
	editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
	editBox:SetScript("OnLeave", OnLeave)
	editBox:SetScript("OnMouseDown", OnReceiveDrag)
	editBox:SetScript("OnReceiveDrag", OnReceiveDrag)
	editBox:SetScript("OnTextChanged", OnTextChanged)
	editBox:SetScript("OnTextSet", OnTextSet)
	editBox:SetScript("OnEditFocusGained", OnEditFocusGained)

	scrollFrame:SetScrollChild(editBox)

	local widget = {
		button      = button,
		editBox     = editBox,
		frame       = frame,
		label       = label,
		labelHeight = 10,
		numlines    = 4,
		scrollBar   = scrollBar,
		scrollBG    = scrollBG,
		scrollFrame = scrollFrame,
		type        = Type
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	button.obj, editBox.obj, scrollFrame.obj = widget, widget, widget

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
