---------------------------------------------------------------
-- Q-SYS dBFS Boost Multiplier
-- Riley Watson | rwatson@onediversified.com
---------------------------------------------------------------
DBFS_MIN = -100
DBFS_MAX = 20

function Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function NormalizeControlArray(ctl)
  if ctl == nil then return {} end
  if ctl.Value ~= nil then return {ctl} end
  return ctl
end

local Inputs = NormalizeControlArray(Controls.dBFS_Input)
local Outputs = NormalizeControlArray(Controls.dBFS_Output)

for i, inp in ipairs(Inputs) do
  inp.EventHandler = function()
    local out = Outputs[i]
    if out then
      local boost = Controls.Boost and Controls.Boost.Value or 1
      local pos = Clamp((inp.Value - DBFS_MIN) / (DBFS_MAX - DBFS_MIN), 0, 1)
      if boost ~= 0 then pos = Clamp(pos * boost, 0, 1) end
      out.Value = DBFS_MIN + pos * (DBFS_MAX - DBFS_MIN)
    end
  end
end

print(string.format("Boost Multiplier: %d channels", #Inputs))
