---------------------------------------------------------------
-- Q-SYS Script for Meter LED Indicator
-- Riley Watson
-- rwatson@onediversified.com
--
-- Current Version:
-- v260209.1 (RWatson)
--  Feature: Scalable multi-channel support (configurable LED_COUNT)
--  Feature: Color gradient metering (green → yellow → red)
--  Feature: Multiple color scheme presets with selector
--  Feature: Smooth gradient interpolation between colors
--  Feature: dBFS meter input mapped to LED color with opacity
--  Feature: User-configurable fallback color input
--
-- Previous Versions:
-- v260206.1 (RWatson)
--  Feature: Initial release
--
---------------------------------------------------------------
-- Global Variables and Constants
---------------------------------------------------------------
DBFS_MIN = -60           -- dBFS value that maps to minimum (0.0)
DBFS_MAX = 0             -- dBFS value that maps to maximum (1.0)
UPDATE_INTERVAL = 0.05   -- Timer interval in seconds (faster for smoother response)

---------------------------------------------------------------
-- Color Scheme Definitions
-- Each scheme is an array of {position, {R, G, B}} stops
-- Position: 0.0 = minimum level, 1.0 = maximum level
-- RGB values: 0-255
---------------------------------------------------------------
ColorSchemes = {
  -- Classic VU Meter: Green → Yellow → Red
  ["Green-Yellow-Red"] = {
    {0.00, {0, 200, 0}},      -- Green (low levels)
    {0.60, {0, 255, 0}},      -- Bright green
    {0.75, {255, 255, 0}},    -- Yellow (approaching hot)
    {0.90, {255, 128, 0}},    -- Orange (hot)
    {1.00, {255, 0, 0}}       -- Red (clipping/max)
  },
  
  -- Cool Meter: Blue → Cyan → Green → Yellow
  ["Blue-Green-Yellow"] = {
    {0.00, {0, 100, 255}},    -- Blue (low levels)
    {0.35, {0, 200, 255}},    -- Cyan
    {0.60, {0, 255, 128}},    -- Cyan-green
    {0.80, {100, 255, 0}},    -- Yellow-green
    {1.00, {255, 255, 0}}     -- Yellow (max)
  },
  
  -- Broadcast: Green → Yellow → Orange → Red (tighter response)
  ["Broadcast"] = {
    {0.00, {0, 180, 0}},      -- Dark green (low)
    {0.50, {0, 255, 0}},      -- Green
    {0.70, {200, 255, 0}},    -- Yellow-green
    {0.85, {255, 200, 0}},    -- Yellow-orange
    {0.95, {255, 100, 0}},    -- Orange
    {1.00, {255, 0, 0}}       -- Red
  },
  
  -- Purple Haze: Purple → Magenta → Pink → White
  ["Purple-Pink"] = {
    {0.00, {80, 0, 160}},     -- Deep purple
    {0.40, {160, 0, 200}},    -- Purple
    {0.70, {255, 0, 200}},    -- Magenta
    {0.90, {255, 100, 200}},  -- Pink
    {1.00, {255, 200, 255}}   -- Light pink/white
  },
  
  -- Ice: Cyan → Blue → Purple
  ["Ice-Cold"] = {
    {0.00, {0, 50, 100}},     -- Dark blue
    {0.30, {0, 150, 200}},    -- Teal
    {0.60, {0, 200, 255}},    -- Cyan
    {0.85, {100, 100, 255}},  -- Light blue
    {1.00, {200, 150, 255}}   -- Lavender
  },
  
  -- Monochrome: Black → White
  ["Monochrome"] = {
    {0.00, {30, 30, 30}},     -- Near black
    {0.50, {128, 128, 128}},  -- Gray
    {1.00, {255, 255, 255}}   -- White
  }
}

-- Ordered list of scheme names for the selector
ColorSchemeNames = {
  "Green-Yellow-Red",
  "Blue-Green-Yellow", 
  "Broadcast",
  "Purple-Pink",
  "Ice-Cold",
  "Monochrome"
}

-- Current active color scheme
ActiveColorScheme = "Green-Yellow-Red"

---------------------------------------------------------------
-- Helper Functions
---------------------------------------------------------------

-- Normalize a control to always be a table/array
-- Q-SYS returns a single control object when count=1, or a table when count>1
function NormalizeControlArray(control)
  if control == nil then
    return {}
  end
  -- Check if it's a single control by looking for control-specific properties
  -- Single controls have .Value, .String, .Boolean etc. directly
  -- Arrays of controls don't have these properties at the top level
  if control.Value ~= nil or control.String ~= nil or control.Boolean ~= nil or control.Position ~= nil then
    -- It's a single control, wrap it in a table
    return {control}
  else
    -- It's already an array
    return control
  end
end

-- Clamp a value between a minimum and maximum
function Clamp(value, min, max)
  if value < min then return min end
  if value > max then return max end
  return value
end

-- Map a dBFS value to a normalized position (0.0 to 1.0)
function dBFSToPosition(dBFS)
  local clamped = Clamp(dBFS, DBFS_MIN, DBFS_MAX)
  local position = (clamped - DBFS_MIN) / (DBFS_MAX - DBFS_MIN)
  return position
end

-- Linear interpolation between two values
function Lerp(a, b, t)
  return a + (b - a) * t
end

-- Interpolate between two RGB color tables
function LerpColor(color1, color2, t)
  return {
    Lerp(color1[1], color2[1], t),
    Lerp(color1[2], color2[2], t),
    Lerp(color1[3], color2[3], t)
  }
end

-- Get interpolated color from a color scheme based on position (0.0 to 1.0)
function GetGradientColor(schemeName, position)
  local scheme = ColorSchemes[schemeName]
  if not scheme then
    scheme = ColorSchemes["Green-Yellow-Red"]  -- Fallback
  end
  
  position = Clamp(position, 0, 1)
  
  -- Find the two color stops to interpolate between
  local lowerStop = scheme[1]
  local upperStop = scheme[#scheme]
  
  for i = 1, #scheme - 1 do
    if position >= scheme[i][1] and position <= scheme[i + 1][1] then
      lowerStop = scheme[i]
      upperStop = scheme[i + 1]
      break
    end
  end
  
  -- Calculate interpolation factor between the two stops
  local range = upperStop[1] - lowerStop[1]
  local t = 0
  if range > 0 then
    t = (position - lowerStop[1]) / range
  end
  
  -- Interpolate the color
  return LerpColor(lowerStop[2], upperStop[2], t)
end

-- Convert RGB table {R, G, B} to hex color string #RRGGBB
function RGBToHex(rgb)
  local r = math.floor(Clamp(rgb[1], 0, 255) + 0.5)
  local g = math.floor(Clamp(rgb[2], 0, 255) + 0.5)
  local b = math.floor(Clamp(rgb[3], 0, 255) + 0.5)
  return string.format("#%02X%02X%02X", r, g, b)
end

-- Build a #OORRGGBB color string from RGB table and opacity (0.0 to 1.0)
function BuildColorWithOpacity(rgb, opacity)
  local alphaByte = math.floor(Clamp(opacity, 0, 1) * 255 + 0.5)
  local r = math.floor(Clamp(rgb[1], 0, 255) + 0.5)
  local g = math.floor(Clamp(rgb[2], 0, 255) + 0.5)
  local b = math.floor(Clamp(rgb[3], 0, 255) + 0.5)
  return string.format("#%02X%02X%02X%02X", alphaByte, r, g, b)
end

-- Validate a #RRGGBB hex color string
function IsValidHexColor(colorStr)
  if colorStr and colorStr:match("^#%x%x%x%x%x%x$") then
    return true
  end
  return false
end

-- Parse #RRGGBB hex string to RGB table
function HexToRGB(hexColor)
  if not IsValidHexColor(hexColor) then
    return {255, 255, 255}  -- Fallback to white
  end
  local r = tonumber(hexColor:sub(2, 3), 16)
  local g = tonumber(hexColor:sub(4, 5), 16)
  local b = tonumber(hexColor:sub(6, 7), 16)
  return {r, g, b}
end

-- Update a single LED based on meter value and settings
function UpdateLED(meterCtl, ledCtl)
  if not meterCtl or not ledCtl then return end
  
  local meterValue = meterCtl.Value
  local position = dBFSToPosition(meterValue)
  
  -- Check if we're using gradient mode or manual color
  local useGradient = true
  if Controls.UseGradient then
    useGradient = Controls.UseGradient.Boolean
  end
  
  local finalColor
  
  if useGradient then
    -- Get color from gradient based on level
    local rgb = GetGradientColor(ActiveColorScheme, position)
    -- Apply opacity based on level - fades in as level increases (max 80%)
    local opacity = position * 0.8  -- Opacity scales from 0.0 to 0.8
    finalColor = BuildColorWithOpacity(rgb, opacity)
  else
    -- Manual color mode with opacity based on level
    local manualColor = "#00FF00"  -- Default green
    if Controls.ColorInput then
      manualColor = Controls.ColorInput.String
    end
    
    if IsValidHexColor(manualColor) then
      local rgb = HexToRGB(manualColor)
      finalColor = BuildColorWithOpacity(rgb, position)
    else
      -- Fallback: use position for LED position/value
      ledCtl.Position = position
      return
    end
  end
  
  ledCtl.Color = finalColor
end

---------------------------------------------------------------
-- Runtime Code
---------------------------------------------------------------

-- Normalize controls to arrays (handles both single and multiple controls)
LED_Controls = NormalizeControlArray(Controls.LED_Indicator)
Meter_Controls = NormalizeControlArray(Controls.dBFS_Input)

UpdateTimer = Timer.New()
UpdateTimer:Start(UPDATE_INTERVAL)

UpdateTimer.EventHandler = function()
  -- Update all LED channels dynamically using ipairs
  for i, ledCtl in ipairs(LED_Controls) do
    local meterCtl = Meter_Controls[i]
    if meterCtl and ledCtl then
      UpdateLED(meterCtl, ledCtl)
    end
  end
end

---------------------------------------------------------------
-- Event Handlers
---------------------------------------------------------------

-- Color scheme selector handler
function SetupColorSchemeSelector()
  if Controls.ColorScheme then
    -- Populate choices if this is a combo box
    Controls.ColorScheme.Choices = ColorSchemeNames
    Controls.ColorScheme.String = ActiveColorScheme
    
    Controls.ColorScheme.EventHandler = function(ctl)
      local selected = ctl.String
      if ColorSchemes[selected] then
        ActiveColorScheme = selected
        print("Color scheme changed to: " .. selected)
      end
    end
  end
end

-- Gradient toggle handler
function SetupGradientToggle()
  if Controls.UseGradient then
    Controls.UseGradient.EventHandler = function(ctl)
      if ctl.Boolean then
        print("Gradient mode enabled")
      else
        print("Manual color mode enabled")
      end
    end
  end
end

-- Manual color input handler
function SetupColorInput()
  if Controls.ColorInput then
    Controls.ColorInput.EventHandler = function(ctl)
      if IsValidHexColor(ctl.String) then
        print("Manual LED color set to: " .. ctl.String)
      else
        print("Invalid color format. Use #RRGGBB format (e.g. #FF0000).")
      end
    end
  end
end

---------------------------------------------------------------
-- Initialization
---------------------------------------------------------------

-- Get the number of LED channels dynamically
local ledCount = #LED_Controls

SetupColorSchemeSelector()
SetupGradientToggle()
SetupColorInput()

print("=========================================")
print("  Meter LED Indicator Plugin Initialized")
print("=========================================")
print(string.format("  Channels Detected: %d", ledCount))
print(string.format("  Range: %d dBFS to %d dBFS", DBFS_MIN, DBFS_MAX))
print(string.format("  Update Interval: %.3f seconds", UPDATE_INTERVAL))
print(string.format("  Active Color Scheme: %s", ActiveColorScheme))
print("")
print("  Available Color Schemes:")
for i, name in ipairs(ColorSchemeNames) do
  print(string.format("    %d. %s", i, name))
end
print("=========================================")


---------------------------------------------------------------
--[[Copyright 2026 Riley Watson
Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.]]
---------------------------------------------------------------