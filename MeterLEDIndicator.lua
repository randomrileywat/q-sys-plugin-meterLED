---------------------------------------------------------------
-- Q-SYS Script for Meter LED Indicator
-- Riley Watson
-- rwatson@onediversified.com
--
-- Current Version:
-- v260206.1 (RWatson)
--  Feature: Initial release
--  Feature: dBFS meter input mapped to LED opacity (0.0–1.0)
--  Feature: User-configurable #RRGGBB color input with #OORRGGBB opacity output
--  Feature: Input validation for hex color strings
--  Feature: Fallback to position-based opacity when no color is set
--
---------------------------------------------------------------
-- Global Variables and Constants
---------------------------------------------------------------
DBFS_MIN = -60   -- dBFS value that maps to fully transparent (0.0)
DBFS_MAX = 0     -- dBFS value that maps to fully opaque (1.0)
UPDATE_INTERVAL = 0.1  -- Timer interval in seconds

---------------------------------------------------------------
-- Properties
---------------------------------------------------------------

-- DBFS_MIN: Lower bound of the meter range (fully transparent)
-- DBFS_MAX: Upper bound of the meter range (fully opaque)
-- UPDATE_INTERVAL: How often the LED updates (seconds)

---------------------------------------------------------------
-- Helper Functions
---------------------------------------------------------------

-- Clamp a value between a minimum and maximum
function Clamp(value, min, max)
  if value < min then return min end
  if value > max then return max end
  return value
end

-- Map a dBFS value to an opacity (0.0 to 1.0)
function dBFSToOpacity(dBFS)
  local clamped = Clamp(dBFS, DBFS_MIN, DBFS_MAX)
  local opacity = (clamped - DBFS_MIN) / (DBFS_MAX - DBFS_MIN)
  return opacity
end

-- Validate a #RRGGBB hex color string
function IsValidHexColor(colorStr)
  if colorStr and colorStr:match("^#%x%x%x%x%x%x$") then
    return true
  end
  return false
end

-- Build a #OORRGGBB color string from a #RRGGBB base color and opacity (0.0 to 1.0)
function BuildColorWithOpacity(hexColor, opacity)
  local alphaByte = math.floor(Clamp(opacity, 0, 1) * 255 + 0.5)
  local alphaHex = string.format("%02X", alphaByte)
  -- Insert opacity bytes after the '#': #RRGGBB -> #OORRGGBB
  return "#" .. alphaHex .. hexColor:sub(2)
end

---------------------------------------------------------------
-- Runtime Code
---------------------------------------------------------------

UpdateTimer = Timer.New()
UpdateTimer:Start(UPDATE_INTERVAL)

UpdateTimer.EventHandler = function()
  local meterValue = Controls.dBFS_Input.Value
  local opacity = dBFSToOpacity(meterValue)
  local baseColor = Controls.ColorInput.String

  if IsValidHexColor(baseColor) then
    -- Build #OORRGGBB and apply to LED indicator
    local colorWithOpacity = BuildColorWithOpacity(baseColor, opacity)
    Controls.LED_Indicator.Color = colorWithOpacity
  else
    -- Fallback: use position for opacity if no valid color is set
    Controls.LED_Indicator.Position = opacity
  end
end

---------------------------------------------------------------
-- Initialization
---------------------------------------------------------------

-- Validate color input when the user changes it
Controls.ColorInput.EventHandler = function(ctl)
  if IsValidHexColor(ctl.String) then
    print("LED color set to: " .. ctl.String)
  else
    print("Invalid color format. Use #RRGGBB format (e.g. #FF0000).")
  end
end

print("Meter LED Indicator Plugin Initialized")
print(string.format("  Range: %d dBFS to %d dBFS", DBFS_MIN, DBFS_MAX))
print(string.format("  Update Interval: %.2f seconds", UPDATE_INTERVAL))


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