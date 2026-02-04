
local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local Bar = MidnightUI:NewModule("Bar", "AceEvent-3.0")
local LDB = LibStub("LibDataBroker-1.1")
local LSM = LibStub("LibSharedMedia-3.0")
local Masque = LibStub("Masque", true)

-- Update all bar widgets' fonts when the global font changes
function Bar:UpdateAllFonts()
    for barID, bar in pairs(bars) do
        self:UpdateBarLayout(barID)
    end
end

-- ============================================================================
-- 1. LOCAL VARIABLES & DATA CACHES
-- ============================================================================
local bars = {}         
local widgets = {}      
local masqueGroup = nil 

-- Layout Cache
local layoutCache = { 
    LEFT = {}, 
    CENTER = {}, 
    RIGHT = {} 
}

-- Interactive Frame References
local friendsFrame, guildFrame, volFrame
local scrollChild, gScrollChild
local guildMotD, listSeparator
local friendTitle, friendFooter, guildTitle, guildFooter
local headerRefs, guildHeaderRefs = {}, {}

-- Module Object References
local friendObj, guildObj, diffObj, clockObj, sysObj, goldObj, bagObj, duraObj, locObj, tokenObj, volObj, ilvlObj

-- Data Cache
local lastState = { 
    timeH = -1, timeM = -1, fps = -1, ms = -1, 
    bagFree = -1, bagTotal = -1, gold = -1, dura = -1, 
    friends = -1, guild = -1, zone = "", diffID = -1, 
    diffPlayers = -1, vol = -1, token = -1, ilvl = -1
}

-- Mappings
local LABEL_MAP_FULL = { 
    MidnightDiff = "Difficulty", MidnightVolume = "Volume", MidnightDura = "Durability", 
    MidnightClock = "Clock", MidnightBags = "Bags", MidnightFriends = "Friends", 
    MidnightGold = "Gold", MidnightGuild = "Guild", MidnightLocation = "Location", 
    MidnightSystem = "System", MidnightToken = "Token", MidnightILvl = "Item Level"
}

local LABEL_MAP_SHORT = { 
    MidnightDiff = "Diff", MidnightVolume = "Vol", MidnightDura = "Dura", 
    MidnightClock = "Time", MidnightBags = "Bags", MidnightFriends = "Frnd", 
    MidnightGold = "Gold", MidnightGuild = "Gld", MidnightLocation = "Loc", 
    MidnightSystem = "Sys", MidnightToken = "Tok", MidnightILvl = "iLvL" 
}

local SHORTEN_REPLACEMENTS = {
    ["Heroic"] = "H", ["Mythic"] = "M", ["Normal"] = "N", ["Finder"] = "LFR", 
    ["Player"] = "P", ["Timewalking"] = "TW", ["Follower"] = "F", ["Tier"] = "T", 
    ["Story"] = "S", ["Delve"] = "D", ["Keystone"] = "+", ["%("] = "", ["%)"] = "",
}

local classTokenLookup = {}
if _G.FillLocalizedClassList then
    local temp = {}
    FillLocalizedClassList(temp, false) 
    for token, name in pairs(temp) do 
        classTokenLookup[name] = token 
    end
    wipe(temp)
    FillLocalizedClassList(temp, true) 
    for token, name in pairs(temp) do 
        classTokenLookup[name] = token 
    end
end

-- SKINS DEFINITIONS
local SKINS = {
    ["Midnight"] = { 
        backdrop = { 
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground", 
            edgeFile = nil, 
            tile = false, tileSize = 0, edgeSize = 0, 
            insets = { left = 0, right = 0, top = 0, bottom = 0 } 
        }, 
        borderAlpha = 0 
    },
    ["Blizzard"] = { 
        backdrop = { 
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", 
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", 
            tile = true, tileSize = 16, edgeSize = 16, 
            insets = { left = 4, right = 4, top = 4, bottom = 4 } 
        }, 
        borderAlpha = 1 
    },
    ["Glass"] = { 
        backdrop = { 
            bgFile = "Interface\\Buttons\\WHITE8X8", 
            edgeFile = "Interface\\Buttons\\WHITE8X8", 
            tile = false, tileSize = 0, edgeSize = 1, 
            insets = { left = 1, right = 1, top = 1, bottom = 1 } 
        }, 
        borderAlpha = 0.4 
    },
    ["Flat"] = { 
        backdrop = { 
            bgFile = "Interface\\Buttons\\WHITE8X8", 
            edgeFile = "Interface\\Buttons\\WHITE8X8", 
            tile = false, tileSize = 0, edgeSize = 1, 
            insets = { left = 0, right = 0, top = 0, bottom = 0 } 
        }, 
        borderAlpha = 1 
    },
    ["Transparent"] = { 
        backdrop = { 
            bgFile = nil, 
            edgeFile = nil, 
            tile = false, tileSize = 0, edgeSize = 0, 
            insets = { left = 0, right = 0, top = 0, bottom = 0 } 
        }, 
        borderAlpha = 0 
    },
    ["Outline"] = { 
        backdrop = { 
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", 
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", 
            tile = true, tileSize = 16, edgeSize = 12, 
            insets = { left = 3, right = 3, top = 3, bottom = 3 } 
        }, 
        borderAlpha = 1 
    },
    ["Tooltip"] = { 
        backdrop = { 
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", 
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", 
            tile = true, tileSize = 16, edgeSize = 16, 
            insets = { left = 4, right = 4, top = 4, bottom = 4 } 
        }, 
        borderAlpha = 1 
    }
}

-- ============================================================================
-- 2. DATABASE DEFAULTS
-- ============================================================================
local defaults = {
    profile = {
        locked = false,
        font = "Friz Quadrata TT",
        fontSize = 12,
        fontColor = {r = 1, g = 1, b = 1},
        useClassColor = false,
        useStandardTime = true,
        spacing = 15,
        goldData = {},      
        tokenHistory = {},
        brokers = {}, -- Initialize empty brokers table
        lastVolume = 1, -- PERSISTENT VOLUME STORAGE
        barSkin = "Midnight", 
        bars = { 
            ["MainBar"] = { 
                enabled = true, 
                fullWidth = true, 
                width = 600, 
                height = 24, 
                scale = 1.0,
                alpha = 0.6, 
                color = {r = 0.1, g = 0.1, b = 0.1}, 
                texture = "Blizzard", 
                skin = "Midnight",    
                padding = 10, 
                point = "TOP", 
                x = 0, y = 0,
                font = "Friz Quadrata TT",
            },
        },
    }
}

local function ShortenValue(text)
    if not text or text == "" then 
        return "" 
    end
    if tostring(text):find("|TInterface") then 
        return text 
    end
    local short = tostring(text)
    for k, v in pairs(SHORTEN_REPLACEMENTS) do 
        short = short:gsub(k, v) 
    end
    if strlenutf8(short) > 60 then 
        short = short:sub(1, 60) 
    end
    return short
end

local function GetColor()
    -- FIX: Ensure DB is loaded if Helper is called early
    if not Bar.db then return 1, 1, 1 end
    
    local db = Bar.db.profile
    if db.useClassColor then
        local _, class = UnitClass("player")
        local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        return color.r, color.g, color.b
    end
    return db.fontColor.r, db.fontColor.g, db.fontColor.b
end

local function FormatTimeDisplay(h, m, standard)
    if standard then
        local suffix = (h >= 12) and " PM" or " AM"
        local hour = h % 12
        if hour == 0 then 
            hour = 12 
        end
        return string.format("%d:%02d%s", hour, m, suffix)
    else
        return string.format("%02d:%02d", h, m)
    end
end

local function FormatSeconds(seconds)
    if not seconds or seconds <= 0 then 
        return "Now" 
    end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    if days > 0 then 
        return string.format("%dd %dh %dm", days, hours, mins)
    else 
        return string.format("%dh %dm", hours, mins) 
    end
end

-- Helper to format numbers with commas (e.g., 1,234,567)
local function FormatWithCommas(amount)
    local formatted = tostring(amount)
    while true do
        formatted, k = formatted:gsub("^(%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function FormatMoney(amount)
    if not amount then 
        return "0c" 
    end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    local str = ""
    if gold > 0 then 
        str = str .. string.format("%s|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t ", FormatWithCommas(gold)) 
    end
    if silver > 0 or gold > 0 then 
        str = str .. string.format("%02d|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t ", silver) 
    end
    str = str .. string.format("%02d|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t ", copper)
    return str
end

local function FormatTokenPrice(amount)
    if not amount then 
        return "N/A" 
    end
    local gold = math.floor(amount / 10000)
    return string.format("%s|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t", FormatWithCommas(gold))
end

local function ApplyTooltipStyle(tip)
    if not tip then return end
    
    -- Don't style tooltips with embedded content to avoid taint
    if tip.ItemTooltip and tip.ItemTooltip:IsShown() then
        return
    end
    
    -- Use pcall to safely apply styling without causing taint
    local success = pcall(function()
        local db = Bar.db.profile
        local fontPath = LSM:Fetch("font", db.font) or "Fonts\\FRIZQT__.ttf"
        local name = tip:GetName()
        
        if not name then return end
        
        if _G[name.."TextLeft1"] then
            _G[name.."TextLeft1"]:SetFont(fontPath, db.fontSize + 2, "OUTLINE")
        end
        if _G[name.."TextRight1"] then
            _G[name.."TextRight1"]:SetFont(fontPath, db.fontSize + 2, "OUTLINE")
        end
        
        local numLines = tip:NumLines()
        if numLines then
            for i = 2, numLines do
                local l, r = _G[name.."TextLeft"..i], _G[name.."TextRight"..i]
                if l then 
                    l:SetFont(fontPath, db.fontSize, "OUTLINE") 
                end
                if r then 
                    r:SetFont(fontPath, db.fontSize, "OUTLINE") 
                end
            end
        end
    end)
    
    -- Silently fail if styling causes issues (e.g., with embedded item tooltips)
end

local function SmartAnchor(tooltip, owner)
    tooltip:ClearAllPoints()
    local bottom = owner:GetBottom()
    local sH, sW = GetScreenHeight(), GetScreenWidth()
    
    local vP, rP, yO
    if bottom and bottom > sH/2 then
        vP, rP, yO = "TOP", "BOTTOM", -2
    else
        vP, rP, yO = "BOTTOM", "TOP", 2
    end
    
    tooltip:SetPoint(vP, owner, rP, 0, yO)
    
    local tW = tooltip:GetWidth() or 200
    local oC = owner:GetCenter() or sW/2
    
    if (oC + tW/2) > sW then 
        tooltip:SetPoint(vP.."RIGHT", owner, rP.."RIGHT", 0, yO)
    elseif (oC - tW/2) < 0 then 
        tooltip:SetPoint(vP.."LEFT", owner, rP.."LEFT", 0, yO) 
    end
end

-- HELPER: DIFFICULTY STRING LOGIC
local function GetDifficultyLabel()
    local _, instanceType, difficultyID, _, _, _, _, _, instanceGroupSize = GetInstanceInfo()
    
    if instanceType == "none" then return "World" end
    if instanceType == "pvp" or instanceType == "arena" then return "BG" end
    
    -- Dungeons & Raids
    -- Timewalking (24 = Dungeon, 33 = Raid)
    if difficultyID == 24 or difficultyID == 33 then return "TW" end
    
    -- Legacy Raids
    if difficultyID == 3 then return "N10" end
    if difficultyID == 4 then return "N25" end
    if difficultyID == 5 then return "H10" end
    if difficultyID == 6 then return "H25" end
    
    -- Standard Dungeons
    if difficultyID == 1 then return "N" end
    if difficultyID == 2 then return "H" end
    if difficultyID == 23 then return "M0" end
    if difficultyID == 8 then return "M+" end
    
    -- Follower Dungeons (Check ID or Fallback Name)
    if difficultyID == 205 then return "F" end
    
    -- Raids
    if difficultyID == 7 or difficultyID == 17 then return "LFR" end
    if difficultyID == 16 then return "M20" end -- Mythic Raid fixed
    
    -- Flex Raids (Normal 14, Heroic 15)
    if difficultyID == 14 then 
        local num = GetNumGroupMembers()
        if num == 0 then num = 1 end 
        return "N"..num
    end
    if difficultyID == 15 then 
        local num = GetNumGroupMembers()
        if num == 0 then num = 1 end
        return "H"..num
    end
    
    -- Fallback for Delves (Check Name)
    local diffName = select(4, GetInstanceInfo())
    if diffName then
        if diffName:find("Delve") then return "D" end
        if diffName:find("Follower") then return "F" end
    end
    
    return diffName or ""
end

-- ============================================================================
-- 4. INTERACTIVE FRAMES (Friends, Guild, Volume)
-- ============================================================================

-- WRAPPER FUNCTION TO FIX NIL ERROR
function Bar:CreateInteractiveFrames()
    self:CreateVolumeFrame()
    self:CreateFriendsFrame()
    self:CreateGuildFrame()
end

-- VOLUME MIXER
function Bar:CreateVolumeFrame()
    if volFrame then return end
    volFrame = CreateFrame("Frame", "MidnightVolumePopout", UIParent, "BackdropTemplate")
    volFrame:SetSize(220, 320); volFrame:SetFrameStrata("DIALOG"); volFrame:EnableMouse(true); volFrame:Hide()
    MidnightUI:SkinFrame(volFrame)

    local vTitle = volFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    vTitle:SetPoint("TOP", 0, -10)
    vTitle:SetText("Volume Mixer")

    -- Add OnShow script to update Title Font/Color dynamically based on current settings
    volFrame:SetScript("OnShow", function()
        local db = Bar.db.profile
        local fontPath = LSM:Fetch("font", db.font) or "Fonts\\FRIZQT__.ttf"
        local r, g, b = GetColor()
        vTitle:SetFont(fontPath, db.fontSize + 2, "OUTLINE")
        vTitle:SetTextColor(r, g, b)
    end)


    volFrame:SetScript("OnUpdate", function(self, elapsed)
        if MouseIsOver(self) or (self.owner and MouseIsOver(self.owner)) then
            self.timer = 0
        else
            self.timer = (self.timer or 0) + elapsed
            if self.timer > 0.2 then
                self:Hide()
            end
        end
    end)

    -- Move slider and checkbox creation inside the function
    local function CreateSlider(name, label, cvar, parent, yOffset)
        local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
        s:SetPoint("TOP", parent, "TOP", 0, yOffset); s:SetWidth(180)
        s:SetMinMaxValues(0, 1); s:SetValueStep(0.05) -- Snap to 5% steps
        _G[s:GetName().."Text"]:SetText(label)
        s:SetScript("OnShow", function(self) 
            self:SetValue(tonumber(GetCVar(cvar)) or 0) 
        end)
        s:SetScript("OnValueChanged", function(self, value) 
            -- Snap to nearest multiple of 5% (0.05)
            value = math.max(0, math.min(1, value))
            value = math.floor((value * 20) + 0.5) / 20
            SetCVar(cvar, value)
            if cvar == "Sound_MasterVolume" then 
                Bar:UpdateAllModules() 
            end 
        end)
    end
    CreateSlider("MUI_VolMaster", "Master", "Sound_MasterVolume", volFrame, -50)
    CreateSlider("MUI_VolMusic", "Music", "Sound_MusicVolume", volFrame, -90)
    CreateSlider("MUI_VolAmbience", "Ambience", "Sound_AmbienceVolume", volFrame, -130)
    CreateSlider("MUI_VolDialog", "Dialog", "Sound_DialogVolume", volFrame, -170)

    local function CreateCheck(label, cvar, parent, yOffset)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, yOffset)
        if cb.Text then 
            cb.Text:SetText(label) 
        elseif cb.text then 
            cb.text:SetText(label) 
        end
        cb:SetScript("OnShow", function(self) 
            self:SetChecked(GetCVar(cvar)=="1") 
        end)
        cb:SetScript("OnClick", function(self) 
            SetCVar(cvar, self:GetChecked() and "1" or "0") 
        end)
    end
    -- UPDATED CHECKBOX LABELS
    CreateCheck("Loop Music", "Sound_ZoneMusicNoDelay", volFrame, -210)
    CreateCheck("Sound in Background", "Sound_EnableSoundWhenGameIsInBG", volFrame, -240) 
    CreateCheck("Play Error Speech", "Sound_EnableErrorSpeech", volFrame, -270)
end

-- FRIENDS LIST
function Bar:CreateFriendsFrame()
    if friendsFrame then return end
    friendsFrame = CreateFrame("Frame", "MidnightFriendsPopup", UIParent, "BackdropTemplate")
    friendsFrame:SetSize(600, 400); friendsFrame:SetFrameStrata("DIALOG"); friendsFrame:EnableMouse(true); friendsFrame:Hide()
    MidnightUI:SkinFrame(friendsFrame)

    friendTitle = friendsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    friendTitle:SetPoint("TOP", 0, -10); friendTitle:SetText("Friends List")

    friendFooter = friendsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    friendFooter:SetPoint("BOTTOM", 0, 8); friendFooter:SetText("|cff00ff00Click: Whisper • Ctrl-Click: Invite|r")

    local fScroll = CreateFrame("ScrollFrame", nil, friendsFrame, "UIPanelScrollFrameTemplate")
    fScroll:SetPoint("TOPLEFT", 10, -55); fScroll:SetPoint("BOTTOMRIGHT", -25, 25)
    scrollChild = CreateFrame("Frame"); scrollChild:SetSize(560, 1); fScroll:SetScrollChild(scrollChild)
    listSeparator = scrollChild:CreateTexture(nil, "ARTWORK"); listSeparator:SetHeight(1); listSeparator:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    local fHeader = CreateFrame("Frame", nil, friendsFrame)
    fHeader:SetPoint("TOPLEFT", 10, -30); fHeader:SetSize(560, 20)
    
    -- Create horizontal line after headers
    local headerLine = friendsFrame:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetColorTexture(0.5, 0.5, 0.5, 0.8)
    headerLine:SetPoint("TOPLEFT", 10, -50)
    headerLine:SetPoint("TOPRIGHT", -25, -50)
    
    local function CreateHeader(text, width, xPos)
        local fs = fHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetText(text); fs:SetWidth(width); fs:SetJustifyH("LEFT"); fs:SetPoint("LEFT", xPos, 0)
        table.insert(headerRefs, fs) 
    end
    -- Columns (Adjusted faction column width)
    local colW = { btag=135, char=100, lvl=30, zone=120, realm=80, fac=50 }
    local colX = { btag=5, char=145, lvl=250, zone=285, realm=410, fac=495 }
    CreateHeader("BattleTag", colW.btag, colX.btag); CreateHeader("Character", colW.char, colX.char)
    CreateHeader("Lvl", colW.lvl, colX.lvl); CreateHeader("Zone", colW.zone, colX.zone)
    CreateHeader("Realm", colW.realm, colX.realm); CreateHeader("Faction", colW.fac, colX.fac)

    -- Add OnShow script to update fonts/colors dynamically
    friendsFrame:SetScript("OnShow", function()
        local db = Bar.db.profile
        local fontPath = LSM:Fetch("font", db.font) or "Fonts\\FRIZQT__.ttf"
        local r, g, b = GetColor()
        
        -- Update title
        friendTitle:SetFont(fontPath, db.fontSize + 2, "OUTLINE")
        friendTitle:SetTextColor(r, g, b)
        
        -- Update footer
        friendFooter:SetFont(fontPath, db.fontSize, "OUTLINE")
        
        -- Update headers
        for _, fs in ipairs(headerRefs) do
            fs:SetFont(fontPath, db.fontSize, "OUTLINE")
            fs:SetTextColor(r, g, b)
        end
    end)

    friendsFrame:SetScript("OnUpdate", function(self, elapsed)
        if MouseIsOver(self) or (self.owner and MouseIsOver(self.owner)) then 
            self.timer = 0
        else 
            self.timer = (self.timer or 0) + elapsed
            if self.timer > 0.2 then 
                self:Hide() 
            end 
        end
    end)
end

function Bar:UpdateFriendList()
    if not scrollChild then return end
    for _, child in ipairs({scrollChild:GetChildren()}) do 
        child:Hide() 
    end
    
    local wowFriends, bnetFriends = {}, {}
    local numBNet = BNGetNumFriends() or 0
    for i = 1, numBNet do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.gameAccountInfo and info.gameAccountInfo.isOnline then
            local g = info.gameAccountInfo
            if (g.clientProgram == BNET_CLIENT_WOW) and (g.wowProjectID == 1) then
                -- Use classID to get proper class token for coloring
                local classToken = g.className
                if g.classID then
                    local classInfo = C_CreatureInfo.GetClassInfo(g.classID)
                    if classInfo then
                        classToken = classInfo.classFile
                    end
                end
                table.insert(wowFriends, {name=g.characterName, bnet=info.battleTag, level=g.characterLevel, zone=g.areaName, realm=g.realmName, faction=g.factionName, class=classToken or g.className})
            else
                table.insert(bnetFriends, {bnet=info.battleTag, game=g.richPresence or g.clientProgram, status=(g.isWowMobile and "Mobile" or "Online")})
            end
        end
    end

    local yOffset, db, fontPath = 0, Bar.db.profile, LSM:Fetch("font", Bar.db.profile.font)
    local colW = { btag=135, char=100, lvl=30, zone=120, realm=80, fac=50 }
    local colX = { btag=5, char=145, lvl=250, zone=285, realm=410, fac=495 }

    local function CreateRow(data, isWoW)
        local btn = CreateFrame("Button", nil, scrollChild); btn:SetSize(560, 20); btn:SetPoint("TOPLEFT", 0, yOffset)
        local function AddText(t, w, x, c)
            local fs = btn:CreateFontString(nil, "OVERLAY"); fs:SetFont(fontPath, db.fontSize, "OUTLINE")
            local sT = tostring(t or "")
            if #sT > 20 then 
                sT = sT:sub(1, 20).."..." 
            end
            fs:SetText(sT); fs:SetWidth(w); fs:SetJustifyH("LEFT"); fs:SetPoint("LEFT", x, 0)
            if c then fs:SetTextColor(c.r, c.g, c.b) end
        end
        if isWoW then
            local cToken = classTokenLookup[data.class] or data.class
            -- Use RAID_CLASS_COLORS instead of C_ClassColor
            local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[cToken] or {r=1,g=1,b=1}
            AddText(data.bnet, colW.btag, colX.btag, {r=0.51,g=0.77,b=1}); AddText(data.name, colW.char, colX.char, color)
            AddText(data.level, colW.lvl, colX.lvl, {r=1,g=1,b=1}); AddText(data.zone, colW.zone, colX.zone, {r=1,g=0.82,b=0})
            AddText(data.realm, colW.realm, colX.realm, {r=1,g=1,b=1})
            
            -- Fixed faction icon logic with proper texture markup
            local facIcon = ""
            if data.faction == "Horde" then
                facIcon = "|TInterface\\Icons\\INV_BannerPVP_01:16:16:0:0|t"
            elseif data.faction == "Alliance" then
                facIcon = "|TInterface\\Icons\\INV_BannerPVP_02:16:16:0:0|t"
            end
            AddText(facIcon, colW.fac, colX.fac)

            btn:SetScript("OnClick", function() 
                local t = data.name
                if data.realm then 
                    t=t.."-"..data.realm:gsub("%s+","") 
                end
                if IsControlKeyDown() then 
                    C_PartyInfo.InviteUnit(t) 
                else 
                    ChatFrame_SendTell(t) 
                end 
            end)
        else
            AddText(data.bnet, colW.btag, colX.btag, {r=0.51,g=0.77,b=1}); AddText(data.game, colW.char, colX.char, {r=0.6,g=0.6,b=0.6})
            AddText(data.status, colW.zone, colX.zone, (data.status=="Mobile" and {r=0.5,g=0.5,b=0.5} or {r=0,g=1,b=0}))
            btn:SetScript("OnClick", function() 
                ChatFrame_SendTell(data.bnet) 
            end)
        end
        local hl = btn:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1,1,1,0.1)
        yOffset = yOffset - 20
    end

    for _, f in ipairs(wowFriends) do 
        CreateRow(f, true) 
    end
    if #wowFriends > 0 and #bnetFriends > 0 then
        listSeparator:ClearAllPoints()
        listSeparator:SetPoint("TOPLEFT", 5, yOffset-2)
        listSeparator:SetPoint("TOPRIGHT", -5, yOffset-2)
        listSeparator:Show()
        yOffset = yOffset - 5
    else 
        listSeparator:Hide() 
    end
    for _, f in ipairs(bnetFriends) do 
        CreateRow(f, false) 
    end
    
    -- Adjust scroll child height to fit content
    local contentHeight = math.abs(yOffset) + 10
    scrollChild:SetHeight(contentHeight)
    
    -- Adjust friends frame height dynamically (min 200, max 600)
    local frameHeight = math.min(600, math.max(200, contentHeight + 90))
    friendsFrame:SetHeight(frameHeight)
end

-- GUILD LIST
function Bar:CreateGuildFrame()
    if guildFrame then return end
    guildFrame = CreateFrame("Frame", "MidnightGuildPopup", UIParent, "BackdropTemplate")
    guildFrame:SetSize(600, 450); guildFrame:SetFrameStrata("DIALOG"); guildFrame:EnableMouse(true); guildFrame:Hide()
    MidnightUI:SkinFrame(guildFrame)
    
    guildTitle = guildFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    guildTitle:SetPoint("TOP", 0, -10); guildTitle:SetText("Guild List")

    guildMotD = guildFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    guildMotD:SetPoint("TOP", 0, -35); guildMotD:SetWidth(560); guildMotD:SetTextColor(0, 1, 0)

    guildFooter = guildFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    guildFooter:SetPoint("BOTTOM", 0, 8); guildFooter:SetText("|cff00ff00Click: Whisper • Ctrl-Click: Invite|r")

    local gScroll = CreateFrame("ScrollFrame", nil, guildFrame, "UIPanelScrollFrameTemplate")
    gScroll:SetPoint("TOPLEFT", 10, -90); gScroll:SetPoint("BOTTOMRIGHT", -25, 25)
    gScrollChild = CreateFrame("Frame"); gScrollChild:SetSize(560, 1); gScroll:SetScrollChild(gScrollChild)

    local gHeader = CreateFrame("Frame", nil, guildFrame)
    gHeader:SetPoint("TOPLEFT", 10, -65); gHeader:SetSize(560, 20)
    
    -- Create horizontal line after headers
    local headerLine = guildFrame:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetColorTexture(0.5, 0.5, 0.5, 0.8)
    headerLine:SetPoint("TOPLEFT", 10, -85)
    headerLine:SetPoint("TOPRIGHT", -25, -85)
    
    local function CreateGHeader(t, w, x)
        local fs = gHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetText(t); fs:SetWidth(w); fs:SetJustifyH("LEFT"); fs:SetPoint("LEFT", x, 0)
        table.insert(guildHeaderRefs, fs)
    end
    -- Columns
    local gW = { name=100, lvl=30, zone=120, rank=100, note=200 }
    local gX = { name=5, lvl=110, zone=145, rank=270, note=375 }
    CreateGHeader("Name", gW.name, gX.name); CreateGHeader("Lvl", gW.lvl, gX.lvl)
    CreateGHeader("Zone", gW.zone, gX.zone); CreateGHeader("Rank", gW.rank, gX.rank); CreateGHeader("Note", gW.note, gX.note)

    -- Add OnShow script to update fonts/colors dynamically
    guildFrame:SetScript("OnShow", function()
        local db = Bar.db.profile
        local fontPath = LSM:Fetch("font", db.font) or "Fonts\\FRIZQT__.ttf"
        local r, g, b = GetColor()
        
        -- Update title
        guildTitle:SetFont(fontPath, db.fontSize + 2, "OUTLINE")
        guildTitle:SetTextColor(r, g, b)
        
        -- Update MotD with larger font
        guildMotD:SetFont(fontPath, db.fontSize + 1, "OUTLINE")
        
        -- Update footer
        guildFooter:SetFont(fontPath, db.fontSize, "OUTLINE")
        
        -- Update headers
        for _, fs in ipairs(guildHeaderRefs) do
            fs:SetFont(fontPath, db.fontSize, "OUTLINE")
            fs:SetTextColor(r, g, b)
        end
    end)

    guildFrame:SetScript("OnUpdate", function(self, elapsed)
        if MouseIsOver(self) or (self.owner and MouseIsOver(self.owner)) then 
            self.timer = 0
        else 
            self.timer = (self.timer or 0) + elapsed
            if self.timer > 0.2 then 
                self:Hide() 
            end 
        end
    end)
end

function Bar:UpdateGuildList()
    if not gScrollChild then return end
    for _, child in ipairs({gScrollChild:GetChildren()}) do 
        child:Hide() 
    end
    local members = {}; local num = GetNumGuildMembers(); guildMotD:SetText(GetGuildRosterMOTD() or "No Message")
    for i = 1, num do
        local name, rank, rankIndex, level, _, zone, note, _, online, _, class = GetGuildRosterInfo(i)
        if online then 
            table.insert(members, {name=name, rank=rank, rIdx=rankIndex, level=level, zone=zone, note=note, class=class}) 
        end
    end
    table.sort(members, function(a, b) return (a.rIdx == b.rIdx) and (a.name < b.name) or (a.rIdx < b.rIdx) end)
    
    local yOffset, db, fontPath = 0, Bar.db.profile, LSM:Fetch("font", Bar.db.profile.font)
    local gW = { name=100, lvl=30, zone=120, rank=100, note=200 }
    local gX = { name=5, lvl=110, zone=145, rank=270, note=375 }

    for _, m in ipairs(members) do
        local btn = CreateFrame("Button", nil, gScrollChild); btn:SetSize(560, 20); btn:SetPoint("TOPLEFT", 0, yOffset)
        local function AddTxt(t, w, x, c, lim)
            local fs = btn:CreateFontString(nil, "OVERLAY"); fs:SetFont(fontPath, db.fontSize, "OUTLINE")
            local sT = tostring(t or "")
            if lim and #sT > lim then 
                sT = sT:sub(1, lim).."..." 
            end
            fs:SetText(sT); fs:SetWidth(w); fs:SetJustifyH("LEFT"); fs:SetPoint("LEFT", x, 0)
            if c then fs:SetTextColor(c.r, c.g, c.b) end
        end
        -- Use RAID_CLASS_COLORS instead of C_ClassColor
        local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[m.class] or {r=1,g=1,b=1}
        AddTxt(m.name:gsub("%-.+", ""), gW.name, gX.name, color, 12); AddTxt(m.level, gW.lvl, gX.lvl, {r=1,g=1,b=1})
        AddTxt(m.zone, gW.zone, gX.zone, {r=1,g=0.82,b=0}); AddTxt(m.rank, gW.rank, gX.rank, {r=1,g=1,b=1})
        AddTxt(m.note, gW.note, gX.note, {r=0.8,g=0.8,b=0.8})
        btn:SetScript("OnClick", function() 
            if IsControlKeyDown() then 
                C_PartyInfo.InviteUnit(m.name) 
            else 
                ChatFrame_SendTell(m.name) 
            end 
        end)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1,1,1,0.1)
        yOffset = yOffset - 20
    end
    
    -- Adjust scroll child height to fit content
    local contentHeight = math.abs(yOffset) + 10
    gScrollChild:SetHeight(contentHeight)
    
    -- Adjust guild frame height dynamically (min 200, max 600)
    local frameHeight = math.min(600, math.max(200, contentHeight + 140))
    guildFrame:SetHeight(frameHeight)
end

-- ============================================================================
-- 5. BROKER OBJECTS (LDB)
-- ============================================================================

function Bar:InitializeBrokers()
    -- FRIENDS
    friendObj = LDB:NewDataObject("MidnightFriends", {
        type = "data source", text = "0", icon = "Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon",
        OnClick = function() ToggleFriendsFrame(1) end,
        OnEnter = function(self) 
            if not friendsFrame then 
                Bar:CreateFriendsFrame() 
            end
            friendsFrame.owner = self
            Bar:UpdateFriendList()
            SmartAnchor(friendsFrame, self)
            friendsFrame:Show() 
        end
    })

    -- GUILD
    guildObj = LDB:NewDataObject("MidnightGuild", {
        type = "data source", text = "0", icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
        OnClick = function() ToggleGuildFrame() end,
        OnEnter = function(self) 
            if IsInGuild() then 
                C_GuildInfo.GuildRoster()
                if not guildFrame then 
                    Bar:CreateGuildFrame() 
                end
                guildFrame.owner = self
                Bar:UpdateGuildList()
                SmartAnchor(guildFrame, self)
                guildFrame:Show() 
            end 
        end
    })

    -- GOLD
    goldObj = LDB:NewDataObject("MidnightGold", { 
        type = "data source", text = "0g", icon = "Interface\\Icons\\INV_Misc_Coin_01",
        OnEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            SmartAnchor(GameTooltip, self)
            local r, g, b = GetColor()
            GameTooltip:AddLine("Account Gold Summary", r, g, b)
            GameTooltip:AddLine(" ")
            local total = 0
            for charKey, data in pairs(Bar.db.profile.goldData) do
                local charColor = {r=1, g=1, b=1}
                if type(data) == "table" and data.class then 
                    local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[data.class]
                    if c then charColor = c end 
                end
                local amt = type(data) == "table" and data.amount or data
                total = total + amt
                GameTooltip:AddDoubleLine(charKey:match("^(.-) %-") or charKey, FormatMoney(amt), charColor.r, charColor.g, charColor.b)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Total", FormatMoney(total), 1, 0.82, 0)
            ApplyTooltipStyle(GameTooltip)
            GameTooltip:Show()
        end,
        OnLeave = function() 
            GameTooltip:Hide() 
        end
    })

    -- SYSTEM (TOP 60 ADDONS) - COLORING UPDATE FOR TOOLTIP
    sysObj = LDB:NewDataObject("MidnightSystem", {
        type = "data source", text = "0 FPS", icon = "Interface\\Icons\\Trade_Engineering",
        OnTooltipShow = function(tip)
            local r, g, b = GetColor()
            UpdateAddOnMemoryUsage()
            local addons = {}
            for i = 1, C_AddOns.GetNumAddOns() do 
                local u = GetAddOnMemoryUsage(i)
                if u > 0 then 
                    table.insert(addons, {n = C_AddOns.GetAddOnInfo(i), m = u}) 
                end 
            end
            table.sort(addons, function(a, b) return a.m > b.m end)
            tip:AddLine("System Performance", r, g, b)
            local _, _, _, world = GetNetStats()
            local fps = math.floor(GetFramerate())
            
            -- FPS Coloring for Tooltip (Matches Bar)
            local fr, fg, fb = 0.2, 1, 0.2 -- Green Default
            if fps < 20 then
                fr, fg, fb = 0.87, 0.09, 0.09 -- Red
            elseif fps < 40 then
                fr, fg, fb = 1, 0.49, 0.04 -- Orange
            elseif fps < 60 then
                fr, fg, fb = 1, 0.82, 0 -- Yellow
            end
            
            -- Latency Coloring for Tooltip (Matches Bar)
            local lr, lg, lb = 0.2, 1, 0.2 -- Green Default
            if world >= 200 then
                lr, lg, lb = 0.87, 0.09, 0.09 -- Red
            elseif world >= 100 then
                lr, lg, lb = 1, 0.82, 0 -- Yellow
            end
            
            tip:AddDoubleLine("FPS:", fps, 1, 1, 1, fr, fg, fb)
            tip:AddDoubleLine("Latency:", world.."ms", 1, 1, 1, lr, lg, lb)
            tip:AddLine(" ")
            tip:AddLine("Top Addon Memory", r, g, b)
            
            for i, data in ipairs(addons) do
                if i > 60 then break end
                
                -- Determine Formatting (KB vs MB)
                local memString = ""
                local val = data.m -- Raw value in KB
                if val < 1024 then
                    memString = string.format("%.0f KB", val)
                else
                    memString = string.format("%.2f MB", val / 1024)
                end
                
                -- Determine Coloring (Red > 10MB, Yellow > 1MB, Green < 1MB)
                local cr, cg, cb
                if val > 10240 then -- Red (0.87, 0.09, 0.09)
                    cr, cg, cb = 0.87, 0.09, 0.09
                elseif val > 1024 then -- Yellow (1.0, 0.82, 0.0)
                    cr, cg, cb = 1, 0.82, 0
                else -- Green (0.2, 1.0, 0.2)
                    cr, cg, cb = 0.2, 1, 0.2
                end
                
                -- Apply color to BOTH Name and Value
                tip:AddDoubleLine(data.n, memString, cr, cg, cb, cr, cg, cb)
            end
            ApplyTooltipStyle(tip)
        end
    })

    -- BAGS
    bagObj = LDB:NewDataObject("MidnightBags", {
        type = "data source", text = "0/0", icon = "Interface\\Icons\\INV_Misc_Bag_08", OnClick = function() ToggleAllBags() end,
        OnTooltipShow = function(tip)
            local r, g, b = GetColor()
            tip:AddLine("Bag Storage", r, g, b)
            for i = 0, 4 do
                local s = C_Container.GetContainerNumSlots(i)
                if s > 0 then
                    local f = C_Container.GetContainerNumFreeSlots(i)
                    local name = (i==0) and "Backpack" or "Bag "..i
                    local br, bg, bb = 1, 1, 1
                    if i > 0 then
                        local link = GetInventoryItemLink("player", C_Container.ContainerIDToInventoryID(i))
                        if link then 
                            local _, _, q = C_Item.GetItemInfo(link)
                            if q then 
                                br, bg, bb = C_Item.GetItemQualityColor(q) 
                            end
                            name = GetItemInfo(link) 
                        end
                    end
                    tip:AddDoubleLine(name, (s-f).."/"..s, br, bg, bb, 1, 1, 1)
                end
            end
            ApplyTooltipStyle(tip)
        end
    })

    -- TOKEN
    tokenObj = LDB:NewDataObject("MidnightToken", {
        type = "data source", text = "Loading...", icon = "Interface\\Icons\\WoW_Token01", 
        OnClick = function() 
            C_WowTokenPublic.UpdateMarketPrice() -- Manual refresh on click
        end,
        OnTooltipShow = function(tip)
            local r, g, b = GetColor()
            tip:AddLine("WoW Token", r, g, b)
            local c = C_WowTokenPublic.GetCurrentMarketPrice()
            if c then 
                tip:AddDoubleLine("Current:", FormatTokenPrice(c), 1,1,1) 
            else
                tip:AddLine("Price not available", 0.8, 0.8, 0.8)
            end
            tip:AddLine(" ")
            tip:AddLine("Price History", 1, 0.82, 0)
            local h = Bar.db.profile.tokenHistory or {}
            if #h > 0 then
                for _, e in ipairs(h) do 
                    tip:AddDoubleLine(date("%m/%d %I:%M %p", e.time), FormatTokenPrice(e.price), 1,1,1) 
                end
            else
                tip:AddLine("No history available", 0.6, 0.6, 0.6)
            end
            tip:AddLine(" ")
            tip:AddLine("|cffaaaaaa(Click to refresh price)|r", 0.7, 0.7, 0.7)
            ApplyTooltipStyle(tip)
        end
    })

    -- VOLUME
    volObj = LDB:NewDataObject("MidnightVolume", { 
        type = "data source", text = "0%", icon = "Interface\\Common\\VoiceChat-Speaker",
        OnClick = function(self, button) 
            if button == "RightButton" then 
                if not volFrame then 
                    Bar:CreateVolumeFrame() 
                end
                volFrame.owner = self
                SmartAnchor(volFrame, self)
                volFrame:Show()
            else 
                local current = tonumber(GetCVar("Sound_MasterVolume")) or 0
                if current > 0 then
                    -- Muting: Save current PERCENTAGE value (whole number) to DB
                    local currentPercent = math.floor(current * 100)
                    Bar.db.profile.lastVolume = currentPercent
                    SetCVar("Sound_MasterVolume", "0")
                else
                    -- Unmuting: Restore from DB as decimal
                    local restorePercent = Bar.db.profile.lastVolume or 100
                    if restorePercent == 0 then restorePercent = 100 end
                    -- Convert percentage back to decimal (0.0 - 1.0)
                    local restoreDecimal = restorePercent / 100
                    SetCVar("Sound_MasterVolume", tostring(restoreDecimal))
                end
                Bar:UpdateAllModules()
            end
        end,
        OnMouseWheel = function(_, d) 
            local v = (tonumber(GetCVar("Sound_MasterVolume")) or 0) + (d>0 and 0.05 or -0.05)
            -- Snap to nearest multiple of 5% (0.05)
            v = math.max(0, math.min(1, v))
            v = math.floor((v * 20) + 0.5) / 20 -- 20 steps in 0-1, each is 0.05
            SetCVar("Sound_MasterVolume", v)
            Bar:UpdateAllModules() 
        end
    })

    duraObj = LDB:NewDataObject("MidnightDura", { 
        type = "data source", text = "100%", icon = "Interface\\Icons\\Trade_BlackSmithing", 
        OnTooltipShow = function(tip) 
            tip:AddLine("Durability Details", GetColor())
            for i=1,18 do 
                local c,m=GetInventoryItemDurability(i)
                if c and m then 
                    tip:AddDoubleLine(GetInventoryItemLink("player",i), math.floor((c/m)*100).."%") 
                end 
            end
            ApplyTooltipStyle(tip) 
        end 
    })
    
    locObj = LDB:NewDataObject("MidnightLocation", { 
        type = "data source", text = "Loc", icon = "Interface\\Icons\\INV_Misc_Map02", 
        OnClick = function() ToggleWorldMap() end 
    })
    
    diffObj = LDB:NewDataObject("MidnightDiff", { 
        type = "data source", text = "World", icon = "Interface\\Icons\\inv_misc_groupneedmore" 
    })
    
    ilvlObj = LDB:NewDataObject("MidnightILvl", { 
        type = "data source", text = "0", icon = "Interface\\Icons\\INV_Helmet_03", 
        OnTooltipShow = function(tip) 
            tip:AddLine("Item Level", GetColor())
            for i=1,18 do 
                local l=GetInventoryItemLink("player",i)
                if l then 
                    tip:AddDoubleLine(l, GetDetailedItemLevelInfo(l)) 
                end 
            end
            ApplyTooltipStyle(tip) 
        end 
    })
    
    -- UPDATED CLOCK TOOLTIP
    clockObj = LDB:NewDataObject("MidnightClock", { 
        type = "data source", text = "00:00", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", 
        OnTooltipShow = function(tip) 
            local r,g,b = GetColor()
            local db = Bar.db.profile
            tip:AddLine("Midnight Clock", r,g,b) -- UPDATED TITLE
            
            -- Local Time
            local localTime = date("*t")
            tip:AddDoubleLine("Local Time:", FormatTimeDisplay(localTime.hour, localTime.min, db.useStandardTime), 1,1,1, 1,1,1)
            
            -- Realm Time
            local realmH, realmM = GetGameTime()
            tip:AddDoubleLine("Realm Time:", FormatTimeDisplay(realmH, realmM, db.useStandardTime), 1,1,1, 1,1,1)
            
            tip:AddLine(" ")
            
            -- Resets
            tip:AddLine("Resets", r, g, b) -- ADDED TITLE
            local dailyReset = C_DateAndTime.GetSecondsUntilDailyReset()
            if dailyReset then
                tip:AddDoubleLine("Daily Reset:", FormatSeconds(dailyReset), 1,1,1, 1,1,1)
            end
            
            local weeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
            if weeklyReset then
                tip:AddDoubleLine("Weekly Reset:", FormatSeconds(weeklyReset), 1,1,1, 1,1,1)
            end
            
            ApplyTooltipStyle(tip) 
        end 
    })
end

-- ============================================================================
-- 6. UPDATE ENGINE
-- ============================================================================

function Bar:UpdateAllModules()
    -- CLOCK
    local h, m = tonumber(date("%H")), tonumber(date("%M"))
    if h ~= lastState.timeH or m ~= lastState.timeM then
        lastState.timeH, lastState.timeM = h, m
        clockObj.text = FormatTimeDisplay(h, m, self.db.profile.useStandardTime)
    end

    -- SYSTEM (FPS/MS) - Color Logic for Bar Text
    local _, _, _, world = GetNetStats()
    local fps = math.floor(GetFramerate())
    if fps ~= lastState.fps or world ~= lastState.ms then
        lastState.fps, lastState.ms = fps, world
        
        -- Custom FPS Colors: Red < 20, Orange < 40, Yellow < 60, Green >= 60
        local color = "ff33ff33" -- Green (Default)
        if fps < 20 then color = "ffde1818"      -- Red
        elseif fps < 40 then color = "ffff7d0a"  -- Orange
        elseif fps < 60 then color = "ffffd200"  -- Yellow
        end
        
        -- Custom MS Colors: Green < 100, Yellow < 200, Red >= 200
        local msColor = "ff33ff33" -- Green (Default)
        if world >= 200 then msColor = "ffde1818"     -- Red
        elseif world >= 100 then msColor = "ffffd200" -- Yellow
        end
        
        sysObj.text = string.format("FPS: |c%s%d|r MS: |c%s%d|r", color, fps, msColor, world)
    end

    -- BAGS
    local free, total = 0, 0
    for i = 0, 5 do 
        local s = C_Container.GetContainerNumSlots(i)
        if s > 0 then 
            free = free + C_Container.GetContainerNumFreeSlots(i)
            total = total + s 
        end 
    end
    if free ~= lastState.bagFree or total ~= lastState.bagTotal then 
        lastState.bagFree, lastState.bagTotal = free, total
        bagObj.text = (total-free).."/"..total 
    end

    -- GOLD & TOKEN
    local money = GetMoney()
    if money ~= lastState.gold then 
        lastState.gold = money
        goldObj.text = FormatMoney(money) 
    end
    
    local price = C_WowTokenPublic.GetCurrentMarketPrice()
    if price and price ~= lastState.token then 
        lastState.token = price
        tokenObj.text = FormatTokenPrice(price) 
    end

    -- COUNTS
    local _, online = GetNumGuildMembers()
    if online ~= lastState.guild then 
        lastState.guild = online
        guildObj.text = tostring(online or 0) 
    end
    
    -- FIXED FRIENDS COUNT: Count only online WoW Retail friends
    local wowOnline = 0
    local numBNet = BNGetNumFriends() or 0
    for i = 1, numBNet do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.gameAccountInfo and info.gameAccountInfo.isOnline then
            local g = info.gameAccountInfo
            if (g.clientProgram == BNET_CLIENT_WOW) and (g.wowProjectID == 1) then
                wowOnline = wowOnline + 1
            end
        end
    end
    if wowOnline ~= lastState.friends then 
        lastState.friends = wowOnline
        friendObj.text = tostring(wowOnline) 
    end
    
    -- DURABILITY
    local low = 100
    for i = 1, 18 do 
        local c, m = GetInventoryItemDurability(i)
        if c and m then 
            local p = (c/m)*100
            if p < low then low = p end 
        end 
    end
    low = math.floor(low)
    if low ~= lastState.dura then 
        lastState.dura = low
        duraObj.text = low.."%" 
    end
    
    -- LOCATION
    local z = GetZoneText() or "Unknown"
    if z ~= lastState.zone then 
        lastState.zone = z
        locObj.text = z 
    end
    
    -- DIFFICULTY & FLEX
    local diff = GetDifficultyLabel()
    local num = GetNumGroupMembers()
    if diff ~= lastState.diffID or num ~= lastState.diffPlayers then
        lastState.diffID = diff
        lastState.diffPlayers = num
        diffObj.text = diff
    end
    
    -- ITEM LEVEL
    local avgIlvl, equippedIlvl = GetAverageItemLevel()
    equippedIlvl = math.floor(equippedIlvl or 0)
    if equippedIlvl ~= lastState.ilvl then
        lastState.ilvl = equippedIlvl
        ilvlObj.text = tostring(equippedIlvl)
    end
    
    -- VOLUME - FIXED: Always Whole Number Formatting
    local v = math.floor((tonumber(GetCVar("Sound_MasterVolume")) or 0) * 100)
    if v ~= lastState.vol then 
        lastState.vol = v
        volObj.text = string.format("%d%%", v) -- Force integer display
    end
end

-- ============================================================================
-- 7. FRAME & LAYOUT LOGIC
-- ============================================================================

local function SortByOrder(a, b) 
    local db = Bar.db.profile.brokers
    if not db then return false end
    return (db[a] and db[a].order or 0) < (db[b] and db[b].order or 0) 
end

function Bar:GetSafeConfig(name)
    -- Ensure brokers table exists
    if not self.db.profile.brokers then
        self.db.profile.brokers = {}
    end
    
    if not self.db.profile.brokers[name] then
        -- Determine if this is a MidnightUI broker or external addon
        local isMidnightBroker = name and name:match("^Midnight")
        local defaultBar = isMidnightBroker and "MainBar" or "None"
        
        self.db.profile.brokers[name] = { 
            bar = defaultBar, 
            align = "CENTER", 
            order = 10, 
            showIcon = true, 
            showText = true, 
            showLabel = false, 
            showCoords = false 
        } 
    end
    return self.db.profile.brokers[name]
end

function Bar:UpdateBarLayout(barID)
    local bar = bars[barID]
    local db = self.db.profile.bars[barID]
    if not bar or not db then return end
    
    -- Ensure bar has proper size before positioning widgets
    local barWidth, barHeight = bar:GetSize()
    if barWidth == 0 or barHeight == 0 then
        -- Bar hasn't been sized yet, apply settings first
        self:ApplyBarSettings(barID)
        return  -- ApplyBarSettings will call UpdateBarLayout again
    end
    
    wipe(layoutCache.LEFT)
    wipe(layoutCache.CENTER)
    wipe(layoutCache.RIGHT)
    
    local brokersForThisBar = {}
    
    for name, w in pairs(widgets) do
        local config = self:GetSafeConfig(name)
        if config and config.bar == barID then 
            table.insert(layoutCache[config.align or "CENTER"], name)
            table.insert(brokersForThisBar, name)
            w:Show()
        elseif config and config.bar == "None" then
            -- Only hide widgets explicitly set to "None", don't hide widgets assigned to other bars
            w:Hide() 
        end
    end
    
    local fontPath = LSM:Fetch("font", self.db.profile.font) or "Fonts\\FRIZQT__.ttf"
    local r, g, b = GetColor()
    
    for align, list in pairs(layoutCache) do
        table.sort(list, SortByOrder)
        local lastWidget = nil
        local first = true
        local totalW = 0
        
        -- Center Calculation
        if align == "CENTER" then
            for _, name in ipairs(list) do
                local w = widgets[name]
                local obj = LDB:GetDataObjectByName(name)
                
                -- FIXED TEXT CONSTRUCTION FOR WIDTH CALC
                local bCfg = self:GetSafeConfig(name)
                local map = bCfg.useShortLabel and LABEL_MAP_SHORT or LABEL_MAP_FULL
                local labelPart = bCfg.showLabel and (map[name] or obj.label or name) or ""
                local rawText = tostring(obj.text or "")
                
                local textValue = rawText
                if name ~= "MidnightLocation" then
                    textValue = ShortenValue(rawText)
                end
                
                if name == "MidnightLocation" and bCfg.showCoords then
                    textValue = textValue .. " (00, 00)" -- Placeholder for sizing
                end
                
                local displayString = (labelPart ~= "" and labelPart .. ": " or "") .. (bCfg.showText and textValue or "")
                
                w.text:SetFont(fontPath, self.db.profile.fontSize, "OUTLINE")
                w.text:SetText(displayString)
                
                local iconSize = (db.height or 24) * 0.85
                totalW = totalW + w.text:GetStringWidth() + (bCfg.showIcon and (iconSize + 4) or 4) + self.db.profile.spacing
            end
            totalW = totalW - self.db.profile.spacing
        end

        for _, name in ipairs(list) do
            local w, obj, bCfg = widgets[name], LDB:GetDataObjectByName(name), self:GetSafeConfig(name)
            w:SetParent(bar)
            w:SetFrameLevel(bar:GetFrameLevel() + 1)  -- Ensure widgets are above the bar's background
            w:ClearAllPoints()
            w.text:SetTextColor(r,g,b)
            
            local rawText = tostring(obj.text or "")
            local map = bCfg.useShortLabel and LABEL_MAP_SHORT or LABEL_MAP_FULL
            local labelPart = bCfg.showLabel and (map[name] or obj.label or name) or ""
            
            local textValue = rawText
            
            -- LOCATION LOGIC (DECIMALS & TRUNCATION BYPASS)
            if name == "MidnightLocation" then
                if bCfg.showCoords then 
                    local m = C_Map.GetBestMapForUnit("player")
                    if m then 
                        local p = C_Map.GetPlayerMapPosition(m, "player")
                        if p then 
                            local decimals = bCfg.coordDecimals or 0
                            if decimals == 0 then
                                textValue = textValue .. string.format(" (%d, %d)", p.x*100, p.y*100)
                            elseif decimals == 1 then
                                textValue = textValue .. string.format(" (%.1f, %.1f)", p.x*100, p.y*100)
                            else -- 2 decimals
                                textValue = textValue .. string.format(" (%.2f, %.2f)", p.x*100, p.y*100)
                            end
                        end 
                    end 
                end
                -- No ShortenValue() call for location, showing full zone name
            else
                textValue = ShortenValue(rawText)
            end
            
            local displayString = (labelPart ~= "" and labelPart .. ": " or "") .. (bCfg.showText and textValue or "")
            w.text:SetText(displayString)

            -- FORCE GLOBAL FONT FOR ALL WIDGETS
            w.text:SetFont(fontPath, self.db.profile.fontSize, "OUTLINE")

            local iconSize = (db.height or 24) * 0.85
            if bCfg.showIcon and obj.icon then 
                w.icon:SetTexture(obj.icon)
                w.icon:SetSize(iconSize, iconSize)
                w.icon:Show()
                w.icon:SetPoint("LEFT", w, "LEFT", 2, 0)
                w.text:SetPoint("LEFT", w.icon, "RIGHT", 4, 0) 
            else 
                w.icon:Hide()
                w.text:SetPoint("LEFT", w, "LEFT", 2, 0) 
            end
            
            local contentWidth = w.text:GetStringWidth() + (bCfg.showIcon and (iconSize + 4) or 4)
            w:SetSize(contentWidth, db.height)
            
            if align == "LEFT" then 
                w:SetPoint("LEFT", lastWidget or bar, lastWidget and "RIGHT" or "LEFT", lastWidget and self.db.profile.spacing or 10, 0)
            elseif align == "RIGHT" then 
                w:SetPoint("RIGHT", lastWidget or bar, lastWidget and "LEFT" or "RIGHT", lastWidget and -self.db.profile.spacing or -10, 0)
            else 
                if first then 
                    w:SetPoint("LEFT", bar, "CENTER", -(totalW/2), 0) 
                else 
                    w:SetPoint("LEFT", lastWidget, "RIGHT", self.db.profile.spacing, 0) 
                end 
            end
            
            lastWidget = w
            first = false
        end
    end
end

function Bar:CreateBarFrame(id)
    local Movable = MidnightUI:GetModule("Movable")
    
    local f = CreateFrame("Frame", "MidnightBar_"..id, UIParent, "BackdropTemplate")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    
    -- Use Movable for drag functionality
    Movable:MakeFrameDraggable(
        f,
        function(point, x, y)
            local db = Bar.db.profile.bars[id]
            if db then
                db.point = point or "CENTER"
                db.x = x or 0
                db.y = y or 0
            end
        end,
        function() return not Bar.db.profile.locked end
    )
    
    -- Create compact arrow controls for this bar (like UIButtons)
    local nudgeFrame = Movable:CreateNudgeArrows(
        f,
        { offsetX = 0, offsetY = 0 },
        function()
            local db = Bar.db.profile.bars[id]
            local nudgeDB = nudgeFrame.db
            
            -- Apply nudge offset to saved position
            db.x = (db.x or 0) + (nudgeDB.offsetX or 0)
            db.y = (db.y or 0) + (nudgeDB.offsetY or 0)
            
            -- Reset nudge offset
            nudgeDB.offsetX = 0
            nudgeDB.offsetY = 0
            
            -- Update bar position
            f:ClearAllPoints()
            if db.fullWidth then
                f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, db.y)
                f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, db.y)
            else
                f:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x, db.y)
            end
            
            Movable:UpdateNudgeDisplay(nudgeFrame, nudgeDB)
        end,
        nil
    )
    
    f.nudgeFrame = nudgeFrame
    
    -- Register nudge frame
    if nudgeFrame then
        Movable:RegisterNudgeFrame(nudgeFrame, f)
    end
    
    bars[id] = f
end

function Bar:ApplyBarSettings(barID)
    local f, db = bars[barID], self.db.profile.bars[barID]
    if not f or not db then return end
    
    local skin = SKINS[db.skin == "Global" and self.db.profile.barSkin or db.skin] or SKINS["Midnight"]
    f:SetScale(db.scale or 1.0)
    f:ClearAllPoints()
    
    if db.fullWidth then 
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, db.y or 0)
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, db.y or 0)
    else 
        f:SetSize(db.width or 400, db.height or 24)
        f:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or 0)
    end
    
    f:SetHeight(db.height or 24)
    f.bg:SetTexture(LSM:Fetch("statusbar", db.texture or "Flat"))
    f.bg:SetVertexColor(db.color.r, db.color.g, db.color.b, db.alpha or 0.5)
    f:SetBackdrop(skin.backdrop)
    f:SetBackdropColor(0,0,0,0)
    f:SetBackdropBorderColor(1, 1, 1, skin.borderAlpha)
    
    if db.enabled then 
        f:Show()
    else 
        f:Hide()
    end
    self:UpdateBarLayout(barID)
end

function Bar:CreateWidget(name, obj)
    local btn = widgets[name]
    if not btn then
        btn = CreateFrame("Button", nil, UIParent)
        btn:RegisterForClicks("AnyUp") -- CRITICAL FIX: ENABLE RIGHT CLICK
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if masqueGroup then 
            masqueGroup:AddButton(btn, { Icon = btn.icon }) 
        end
        widgets[name] = btn
    end
    btn:SetScript("OnEnter", function(self) 
        if obj.OnEnter then 
            obj.OnEnter(self) 
        elseif obj.OnTooltipShow then 
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            SmartAnchor(GameTooltip, self)
            obj.OnTooltipShow(GameTooltip)
            -- FORCE STYLE FOR ALL TOOLTIPS
            ApplyTooltipStyle(GameTooltip)
            GameTooltip:Show() 
        end 
        -- Fallback check for addons that use weird tooltip methods
        if GameTooltip:IsShown() and GameTooltip:GetOwner() == self then
             ApplyTooltipStyle(GameTooltip)
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(self, button) 
        if name == "MidnightLocation" then 
            ToggleWorldMap() 
        elseif obj.OnClick then 
            obj.OnClick(self, button) 
        end 
    end)
    btn:EnableMouseWheel(true)
    btn:SetScript("OnMouseWheel", function(self, delta) 
        if obj.OnMouseWheel then 
            obj.OnMouseWheel(obj, delta) 
        end 
    end)
    LDB.RegisterCallback(self, "LibDataBroker_AttributeChanged_"..name, function() 
        local config = Bar:GetSafeConfig(name)
        if config and config.bar and config.bar ~= "None" then
            Bar:UpdateBarLayout(config.bar)
        end
    end)
end

-- ============================================================================
-- 8. INITIALIZATION & EVENTS
-- ============================================================================

function Bar:OnInitialize()
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "OnDBReady")
end

function Bar:OnDBReady()
    if not MidnightUI.db.profile.modules.bar then return end
    
    self.db = MidnightUI.db:RegisterNamespace("Bar", defaults)
    
    if Masque then 
        masqueGroup = Masque:Group("Midnight Bar") 
    end

    for id in pairs(self.db.profile.bars) do 
        self:CreateBarFrame(id) 
    end
    
    LDB.RegisterCallback(self, "LibDataBroker_DataObjectCreated", function(_, name, obj) 
        self:CreateWidget(name, obj) 
    end)
    
    self:CreateInteractiveFrames()
    self:InitializeBrokers()
    
    for name, obj in LDB:DataObjectIterator() do 
        self:CreateWidget(name, obj) 
    end
    
    -- REMOVED: self:RegisterEvent("PLAYER_LOGIN") - Not needed, no handler exists
    self:RegisterEvent("PLAYER_MONEY", "UpdateGoldData")
    self:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED", "UpdateTokenHistory")
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAllModules")
    self:RegisterEvent("BAG_UPDATE", "UpdateAllModules")
    self:RegisterEvent("ZONE_CHANGED", "UpdateAllModules")
    
    self:UpdateGoldData()
    
    -- Request initial WoW Token price
    C_Timer.After(2, function()
        C_WowTokenPublic.UpdateMarketPrice()
    end)
    
    C_Timer.NewTicker(1.0, function() self:UpdateAllModules() end)
    
    C_Timer.After(1.0, function() 
        for id in pairs(bars) do 
            Bar:ApplyBarSettings(id) 
        end 
    end)
end

function Bar:PLAYER_ENTERING_WORLD()
    -- Just update modules, initialization already done
    self:UpdateAllModules()
end

function Bar:UpdateGoldData()
    local key = UnitName("player") .. " - " .. GetRealmName()
    self.db.profile.goldData[key] = { amount = GetMoney(), class = select(2, UnitClass("player")) }
end

function Bar:UpdateTokenHistory()
    local price = C_WowTokenPublic.GetCurrentMarketPrice()
    if not price then return end
    
    local h = self.db.profile.tokenHistory
    
    -- Check if this price is different from the most recent entry
    if #h > 0 and h[1].price == price then
        return -- Don't add duplicate prices
    end
    
    -- Add new entry at the beginning
    table.insert(h, 1, { price = price, time = time() })
    
    -- Keep only the 5 most recent entries
    while #h > 5 do 
        table.remove(h) 
    end
    
    -- Update the display immediately
    tokenObj.text = FormatTokenPrice(price)
    self:UpdateBarLayout("MainBar")
end

function Bar:GUILD_ROSTER_UPDATE() 
    if guildFrame and guildFrame:IsShown() then 
        self:UpdateGuildList() 
    end
    self:UpdateAllModules() 
end

-- ============================================================================
-- 9. OPTIONS
-- ============================================================================

function Bar:MoveBroker(name, direction)
    local config = self:GetSafeConfig(name)
    if not config or config.bar == "None" then 
        return 
    end
    
    -- Ensure brokers table exists
    if not self.db.profile.brokers then
        self.db.profile.brokers = {}
    end
    
    -- For RIGHT-aligned brokers, reverse the direction since they're laid out right-to-left
    -- (higher order values appear further left visually)
    if config.align == "RIGHT" then
        direction = -direction
    end
    
    -- Build list of brokers in same bar/align
    local list = {}
    for n, c in pairs(self.db.profile.brokers) do 
        if c.bar == config.bar and c.align == config.align then 
            table.insert(list, {name=n, order=c.order or 10}) 
        end 
    end
    table.sort(list, function(a, b) 
        if a.order == b.order then
            return a.name < b.name  -- Secondary sort by name for consistency
        end
        return a.order < b.order 
    end)
    
    -- First, ensure all brokers have unique sequential order values
    for i, d in ipairs(list) do
        self.db.profile.brokers[d.name].order = i * 10
        list[i].order = i * 10  -- Update the list entry too
    end
    
    -- Find current index
    local idx
    for i, d in ipairs(list) do 
        if d.name == name then idx = i end 
    end
    
    if not idx then
        return
    end
    
    local target = idx + direction
    
    -- Check if move is valid
    if target < 1 or target > #list then 
        return
    end
    
    -- Swap only the order values of these two brokers
    local currentBrokerName = list[idx].name
    local targetBrokerName = list[target].name
    
    self.db.profile.brokers[currentBrokerName].order, self.db.profile.brokers[targetBrokerName].order = 
        self.db.profile.brokers[targetBrokerName].order, self.db.profile.brokers[currentBrokerName].order
    
    self:UpdateBarLayout(config.bar)
end

function Bar:GetPluginOptions()
    local options = { 
        name = "Brokers", 
        type = "group", 
        childGroups = "tree", 
        args = {} 
    }
    
    local barList = { ["None"] = "None" }; 
    for bID in pairs(self.db.profile.bars) do 
        barList[bID] = bID 
    end
    
    local nameMap = { 
        MidnightDura = "Midnight Durability", 
        MidnightClock = "Midnight Clock", 
        MidnightBags = "Midnight Bags", 
        MidnightFriends = "Midnight Friends", 
        MidnightGold = "Midnight Gold", 
        MidnightGuild = "Midnight Guild", 
        MidnightLocation = "Midnight Location", 
        MidnightSystem = "Midnight System", 
        MidnightDiff = "Midnight Difficulty", 
        MidnightToken = "Midnight Token", 
        MidnightVolume = "Midnight Volume", 
        MidnightILvl = "Midnight Item Level" 
    }

    for name in pairs(widgets) do
        self:GetSafeConfig(name)
        local displayName = nameMap[name] or name
        local isLoc = (name == "MidnightLocation")
        local isVol = (name == "MidnightVolume")
        local isGold = (name == "MidnightGold")

        options.args[name:gsub("%s", "_")] = {
            name = (self.db.profile.brokers[name].bar ~= "None") and displayName or "|cff808080"..displayName.."|r", 
            type = "group", 
            order = 1,
            args = {
                enable = { 
                    name = "Enable", 
                    type = "toggle", 
                    order = 1, 
                    width = "normal", 
                    get = function() return self.db.profile.brokers[name].bar ~= "None" end, 
                    set = function(_, v) self.db.profile.brokers[name].bar = v and "MainBar" or "None"; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
                },
                moveL = { 
                    name = "Move Left", 
                    type = "execute", 
                    order = 1.1, 
                    width = "half", 
                    func = function() self:MoveBroker(name, -1) end 
                },
                moveR = { 
                    name = "Move Right", 
                    type = "execute", 
                    order = 1.2, 
                    width = "half", 
                    func = function() self:MoveBroker(name, 1) end 
                },

                -- Row 2: Bar and Align (now order 4 and 4.1)
                bar = { 
                    name = "Bar", 
                    type = "select", 
                    order = 4, 
                    width = "half",
                    values = barList, 
                    get = function() return self.db.profile.brokers[name].bar end, 
                    set = function(_, v) self.db.profile.brokers[name].bar = v; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
                },
                align = { 
                    name = "Align", 
                    type = "select", 
                    order = 4.1, 
                    width = "half",
                    values = {LEFT="Left", CENTER="Center", RIGHT="Right"}, 
                    get = function() return self.db.profile.brokers[name].align end, 
                    set = function(_, v) self.db.profile.brokers[name].align = v; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
                },

                -- Row 3: Checkboxes and toggles (start at order 5)
                showIcon = { 
                    name = "Show Icon", 
                    type = "toggle", 
                    order = 5, 
                    get = function() return self.db.profile.brokers[name].showIcon end, 
                    set = function(_, v) self.db.profile.brokers[name].showIcon = v; self:UpdateBarLayout(self.db.profile.brokers[name].bar) end 
                },
                showText = { 
                    name = "Show Value", 
                    type = "toggle", 
                    order = 6, 
                    get = function() return self.db.profile.brokers[name].showText end, 
                    set = function(_, v) self.db.profile.brokers[name].showText = v; self:UpdateBarLayout(self.db.profile.brokers[name].bar) end 
                },
                showLabel = { 
                    name = "Show Label", 
                    type = "toggle", 
                    order = 7, 
                    get = function() return self.db.profile.brokers[name].showLabel end, 
                    set = function(_, v) self.db.profile.brokers[name].showLabel = v; self:UpdateBarLayout(self.db.profile.brokers[name].bar) end 
                },
                useShortLabel = { 
                    name = "Use Short Label", 
                    type = "toggle", 
                    order = 8, 
                    disabled = function() return not self.db.profile.brokers[name].showLabel end, 
                    get = function() return self.db.profile.brokers[name].useShortLabel end, 
                    set = function(_, v) self.db.profile.brokers[name].useShortLabel = v; self:UpdateBarLayout(self.db.profile.brokers[name].bar) end 
                },
                
                showCoords = isLoc and { 
                    name = "Show Coords", 
                    type = "toggle", 
                    order = 10, 
                    get = function() return self.db.profile.brokers[name].showCoords end, 
                    set = function(_, v) self.db.profile.brokers[name].showCoords = v; self:UpdateBarLayout(self.db.profile.brokers[name].bar) end 
                } or nil,
                coordDecimals = isLoc and { 
                    name = "Decimal Places", 
                    type = "select", 
                    order = 11, 
                    values = { [0] = "None (60, 45)", [1] = "One (60.5, 45.3)", [2] = "Two (60.52, 45.37)" },
                    get = function() return self.db.profile.brokers[name].coordDecimals or 0 end, 
                    set = function(_, v) self.db.profile.brokers[name].coordDecimals = v; self:UpdateBarLayout(self.db.profile.brokers[name].bar) end 
                } or nil,
                volumeStep = isVol and {
                    name = "Step Size",
                    type = "select",
                    order = 12,
                    values = { [0.01] = "1%", [0.05] = "5%" },
                    get = function() return self.db.profile.brokers[name].volumeStep or 0.01 end,
                    set = function(_, v) self.db.profile.brokers[name].volumeStep = v end
                } or nil,
                deleteChar = isGold and { 
                    name = "Delete Character Data", 
                    type = "select", 
                    order = 13, 
                    values = function() local t = {}; for k in pairs(self.db.profile.goldData) do t[k] = k end; return t end, 
                    set = function(_, v) self.db.profile.goldData[v] = nil end, confirm = true 
                } or nil
            }
        }
    end
    return options
end

function Bar:GetOptions()
    -- SAFETY CHECK: Ensure DB is loaded if GetOptions is called before OnInitialize
    if not self.db then
        self.db = MidnightUI.db:RegisterNamespace("Bar", defaults)
    end

    local function GetSkinList() 
        local list = { ["Global"] = "Global (Use General Setting)" }
        for k in pairs(SKINS) do list[k] = k end
        return list 
    end
    
    local screenWidth = math.floor(GetScreenWidth())
    local options = { 
        type = "group", 
        name = "Data Brokers", 
        childGroups = "tab", 
        args = {
            font = { 
                name = "Global Font", 
                type = "select", 
                order = 1, 
                dialogControl = "LSM30_Font", 
                values = LSM:HashTable("font"), 
                get = function() return self.db.profile.font end, 
                set = function(_, v) self.db.profile.font = v; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
            },
            fontSize = { 
                name = "Font Size", 
                type = "range", 
                min = 6, 
                max = 32, 
                step = 1, 
                order = 2, 
                get = function() return self.db.profile.fontSize end, 
                set = function(_, v) self.db.profile.fontSize = v; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
            },
            spacing = { 
                name = "Spacing", 
                type = "range", 
                min = 0, 
                max = 50, 
                step = 1, 
                order = 3, 
                get = function() return self.db.profile.spacing end, 
                set = function(_, v) self.db.profile.spacing = v; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
            },
            useClassColor = { 
                name = "Use Class Color", 
                type = "toggle", 
                order = 4, 
                get = function() return self.db.profile.useClassColor end, 
                set = function(_, v) self.db.profile.useClassColor = v; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
            },
            color = { 
                name = "Custom Font Color", 
                type = "color", 
                order = 5, 
                disabled = function() return self.db.profile.useClassColor end, 
                get = function() local c = self.db.profile.fontColor; return c.r, c.g, c.b end, 
                set = function(_, r, g, b) self.db.profile.fontColor = {r=r, g=g, b=b}; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
            },
            useStandardTime = { 
                name = "Use 24-Hour Time", 
                type = "toggle", 
                order = 6, 
                get = function() return self.db.profile.useStandardTime end, 
                set = function(_, v) self.db.profile.useStandardTime = v; self:UpdateAllModules() end 
            },
            lock = { 
                name = "Lock", 
                type = "toggle", 
                order = 7, 
                get = function() return self.db.profile.locked end, 
                set = function(_, v) self.db.profile.locked = v; for id in pairs(bars) do self:ApplyBarSettings(id) end end 
            },
            bars = { 
                name = "Bars", 
                type = "group", 
                order = 8, 
                args = { 
                    create = { 
                        name = "Create New Bar", 
                        type = "input", 
                        order = 1, 
                        set = function(_, v) if v ~= "" and not self.db.profile.bars[v] then self.db.profile.bars[v] = { enabled = true, fullWidth = false, width = 400, height = 24, scale = 1.0, alpha = 0.5, color = {r=0,g=0,b=0}, texture = "Blizzard", skin = "Global", padding = 5, point = "CENTER", x = 0, y = 0 }; self:CreateBarFrame(v); self:ApplyBarSettings(v) end end 
                    } 
                } 
            },
            brokers = self:GetPluginOptions()
        }
    }
    local sortedBars = {}; for id in pairs(self.db.profile.bars) do table.insert(sortedBars, id) end; table.sort(sortedBars)
    for i, id in ipairs(sortedBars) do
        options.args.bars.args[id] = { 
            name = id, 
            type = "group", 
            order = 10 + i, 
            args = {
                enabled = { 
                    name = "Enabled", 
                    type = "toggle", 
                    order = 1, 
                    get = function() return self.db.profile.bars[id].enabled end, 
                    set = function(_, v) self.db.profile.bars[id].enabled = v; self:ApplyBarSettings(id) end 
                },
                fullWidth = { 
                    name = "Full Width", 
                    type = "toggle", 
                    order = 2, 
                    get = function() return self.db.profile.bars[id].fullWidth end, 
                    set = function(_, v) self.db.profile.bars[id].fullWidth = v; self:ApplyBarSettings(id) end 
                },
                width = { 
                    name = "Width", 
                    type = "range", 
                    order = 3, 
                    min = 50, 
                    max = screenWidth, 
                    step = 1, 
                    disabled = function() return self.db.profile.brokers[id] and self.db.profile.brokers[id].fullWidth or false end, 
                    get = function() return self.db.profile.bars[id].width end, 
                    set = function(_, v) self.db.profile.bars[id].width = v; self:ApplyBarSettings(id) end 
                },
                height = { 
                    name = "Height", 
                    type = "range", 
                    order = 4, 
                    min = 10, 
                    max = 100, 
                    step = 1, 
                    get = function() return self.db.profile.bars[id].height end, 
                    set = function(_, v) self.db.profile.bars[id].height = v; self:ApplyBarSettings(id) end 
                },
                scale = { 
                    name = "Scale", 
                    type = "range", 
                    order = 4.5, 
                    min = 0.5, 
                    max = 3.0, 
                    step = 0.1, 
                    get = function() return self.db.profile.bars[id].scale or 1.0 end, 
                    set = function(_, v) self.db.profile.bars[id].scale = v; self:ApplyBarSettings(id) end 
                },
                skin = { 
                    name = "Skin", 
                    type = "select", 
                    order = 5, 
                    values = GetSkinList, 
                    get = function() return self.db.profile.bars[id].skin or "Global" end, 
                    set = function(_, v) self.db.profile.bars[id].skin = v; self:ApplyBarSettings(id) end 
                },
                texture = { 
                    name = "Texture", 
                    type = "select", 
                    order = 6, 
                    dialogControl = "LSM30_Statusbar", 
                    values = LSM:HashTable("statusbar"), 
                    get = function() return self.db.profile.bars[id].texture end, 
                    set = function(_, v) self.db.profile.bars[id].texture = v; self:ApplyBarSettings(id) end 
                },
                color = { 
                    name = "Color", 
                    type = "color", 
                    hasAlpha = true, 
                    order = 7, 
                    get = function() local c = self.db.profile.bars[id].color; return c.r, c.g, c.b, self.db.profile.bars[id].alpha end, 
                    set = function(_, r, g, b, a) self.db.profile.bars[id].color = {r=r, g=g, b=b}; self.db.profile.bars[id].alpha = a; self:ApplyBarSettings(id) end 
                },
                delete = {
                    name = "Delete Bar",
                    type = "execute",
                    order = 99,
                    confirm = function() return string.format("Are you sure you want to delete %s?", id) end,
                    disabled = function() return id == "MainBar" end,
                    func = function()
                        self.db.profile.bars[id] = nil
                        if bars[id] then bars[id]:Hide(); bars[id] = nil end
                        if self.db.profile.brokers then
                            for name, config in pairs(self.db.profile.brokers) do if config.bar == id then config.bar = "None" end end
                        end
                        MidnightUI:OpenConfig()
                    end
                },
        }}
    end
    return options
end

function Bar:ScheduleLayout() 
    Bar.layoutQueued = true
    C_Timer.After(0.05, function() 
        Bar.layoutQueued = false
        for id in pairs(bars) do 
            Bar:UpdateBarLayout(id) 
        end 
    end) 
end