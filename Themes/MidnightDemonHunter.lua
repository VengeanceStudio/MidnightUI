-- MidnightUI Theme: Midnight Demon Hunter
-- High transparency theme with Demon Hunter class colors (purple/magenta)

local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

-- ============================================================================
-- COLOR PALETTE
-- ============================================================================

ColorPalette:RegisterPalette("MidnightDemonHunter", {
    -- Core UI Colors (8 main colors for theme editor)
    ["panel-bg"] = {r = 0.239, g = 0.106, b = 0.333, a = 0.65},    -- Dark purple (#3D1B55)
    ["panel-border"] = {r = 0.639, g = 0.207, b = 0.933, a = 0.90}, -- DH purple
    ["accent-primary"] = {r = 0.639, g = 0.207, b = 0.933, a = 0.85}, -- DH purple
    ["button-bg"] = {r = 0.08, g = 0.08, b = 0.10, a = 0.60},      -- Transparent dark charcoal
    ["button-hover"] = {r = 0.70, g = 0.30, b = 0.95, a = 0.75},   -- Brighter purple
    ["text-primary"] = {r = 0.90, g = 0.75, b = 0.98, a = 1.0},    -- Light purple-tinted white
    ["text-secondary"] = {r = 0.70, g = 0.55, b = 0.80, a = 0.95}, -- Purple-grey
    ["tab-active"] = {r = 0.50, g = 0.20, b = 0.75, a = 0.75},     -- Deep purple
    
    -- Extended colors for full UI coverage
    ["primary"] = {r = 0.639, g = 0.207, b = 0.933, a = 0.85},     -- DH purple
    ["secondary"] = {r = 0.10, g = 0.10, b = 0.12, a = 0.65},      -- Dark transparent charcoal
    ["accent"] = {r = 0.70, g = 0.30, b = 0.95, a = 0.80},         -- Bright purple accent
    
    -- Background colors (high transparency)
    ["bg-primary"] = {r = 0.05, g = 0.05, b = 0.05, a = 0.65},     -- Very transparent black
    ["bg-secondary"] = {r = 0.08, g = 0.08, b = 0.10, a = 0.60},   -- Even more transparent
    ["bg-tertiary"] = {r = 0.10, g = 0.10, b = 0.12, a = 0.55},    -- Very transparent charcoal
    
    -- Text colors
    ["text-muted"] = {r = 0.60, g = 0.50, b = 0.70, a = 0.90},     -- Muted purple-grey
    ["text-disabled"] = {r = 0.40, g = 0.35, b = 0.45, a = 0.70},  -- Dark muted purple-grey
    
    -- Component colors
    ["button-pressed"] = {r = 0.80, g = 0.40, b = 1.0, a = 0.90},  -- Bright purple
    ["button-disabled"] = {r = 0.05, g = 0.05, b = 0.05, a = 0.40},
    
    ["tab-inactive"] = {r = 0.08, g = 0.08, b = 0.10, a = 0.55},
    ["tab-selected-bg"] = {r = 0.50, g = 0.20, b = 0.75, a = 0.75},
    
    -- Status colors
    ["success"] = {r = 0.40, g = 0.80, b = 0.50, a = 0.85},        -- Green
    ["warning"] = {r = 0.90, g = 0.70, b = 0.30, a = 0.85},        -- Orange
    ["error"] = {r = 0.90, g = 0.30, b = 0.30, a = 0.85},          -- Red
    ["info"] = {r = 0.639, g = 0.207, b = 0.933, a = 0.85},        -- DH purple
    
    -- Border colors
    ["border-subtle"] = {r = 0.35, g = 0.15, b = 0.45, a = 0.60},
    ["border-medium"] = {r = 0.50, g = 0.20, b = 0.70, a = 0.70},
    ["border-strong"] = {r = 0.639, g = 0.207, b = 0.933, a = 0.85},
    
    -- Tooltip colors
    ["tooltip-bg"] = {r = 0.08, g = 0.05, b = 0.10, a = 0.90},
    
    -- Shadow & highlight
    ["shadow"] = {r = 0.0, g = 0.0, b = 0.0, a = 0.70},
    ["highlight"] = {r = 0.80, g = 0.40, b = 1.0, a = 0.25},
    
    -- Selection & hover states
    ["selected-bg"] = {r = 0.50, g = 0.20, b = 0.75, a = 0.75},
    ["hover-bg"] = {r = 0.40, g = 0.15, b = 0.60, a = 0.70},
    
    -- Scrollbar & progress
    ["scrollbar-thumb"] = {r = 0.639, g = 0.207, b = 0.933, a = 0.75},
    ["scrollbar-track"] = {r = 0.08, g = 0.08, b = 0.10, a = 0.50},
    ["progress-fill"] = {r = 0.639, g = 0.207, b = 0.933, a = 0.85},
})

-- ============================================================================
-- FONT DEFINITIONS
-- ============================================================================

-- This theme uses the default font definitions
-- Custom fonts can be registered here if needed
