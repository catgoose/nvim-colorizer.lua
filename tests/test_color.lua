local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local color = require("colorizer.color")

local T = new_set()

-- hue_to_rgb -----------------------------------------------------------------

T["hue_to_rgb"] = new_set()

T["hue_to_rgb"]["t < 1/6 branch"] = function()
  -- p=0, q=1, t=0.1  =>  0 + (1-0)*6*0.1 = 0.6
  local result = color.hue_to_rgb(0, 1, 0.1)
  eq(true, math.abs(result - 0.6) < 1e-10)
end

T["hue_to_rgb"]["t < 1/2 branch returns q"] = function()
  eq(0.8, color.hue_to_rgb(0.2, 0.8, 0.3))
end

T["hue_to_rgb"]["t < 2/3 branch"] = function()
  local result = color.hue_to_rgb(0.2, 0.8, 0.6)
  eq(true, math.abs(result - (0.2 + (0.8 - 0.2) * (2 / 3 - 0.6) * 6)) < 1e-10)
end

T["hue_to_rgb"]["t >= 2/3 returns p"] = function()
  eq(0.2, color.hue_to_rgb(0.2, 0.8, 0.9))
end

T["hue_to_rgb"]["negative t wraps around"] = function()
  -- t = -0.1 becomes 0.9 => >= 2/3 => returns p
  eq(0.3, color.hue_to_rgb(0.3, 0.7, -0.1))
end

T["hue_to_rgb"]["t > 1 wraps around"] = function()
  -- t = 1.1 becomes 0.1 => < 1/6 branch
  local result = color.hue_to_rgb(0, 1, 1.1)
  eq(true, math.abs(result - 0.6) < 1e-10)
end

-- hsl_to_rgb ------------------------------------------------------------------

T["hsl_to_rgb"] = new_set()

T["hsl_to_rgb"]["pure red"] = function()
  local r, g, b = color.hsl_to_rgb(0, 1, 0.5)
  eq(true, math.abs(r - 255) < 1)
  eq(true, g < 1)
  eq(true, b < 1)
end

T["hsl_to_rgb"]["pure green"] = function()
  local r, g, b = color.hsl_to_rgb(1 / 3, 1, 0.5)
  eq(true, r < 1)
  eq(true, math.abs(g - 255) < 1)
  eq(true, b < 1)
end

T["hsl_to_rgb"]["pure blue"] = function()
  local r, g, b = color.hsl_to_rgb(2 / 3, 1, 0.5)
  eq(true, r < 1)
  eq(true, g < 1)
  eq(true, math.abs(b - 255) < 1)
end

T["hsl_to_rgb"]["white (s=0, l=1)"] = function()
  local r, g, b = color.hsl_to_rgb(0, 0, 1)
  eq(255, r)
  eq(255, g)
  eq(255, b)
end

T["hsl_to_rgb"]["black (s=0, l=0)"] = function()
  local r, g, b = color.hsl_to_rgb(0, 0, 0)
  eq(0, r)
  eq(0, g)
  eq(0, b)
end

T["hsl_to_rgb"]["gray (s=0, l=0.5)"] = function()
  local r, g, b = color.hsl_to_rgb(0, 0, 0.5)
  eq(true, math.abs(r - 127.5) < 0.01)
  eq(r, g)
  eq(g, b)
end

T["hsl_to_rgb"]["returns nil when out of range"] = function()
  eq(nil, color.hsl_to_rgb(2, 0.5, 0.5))
  eq(nil, color.hsl_to_rgb(0.5, 2, 0.5))
  eq(nil, color.hsl_to_rgb(0.5, 0.5, 2))
end

-- oklch_to_rgb ----------------------------------------------------------------

T["oklch_to_rgb"] = new_set()

T["oklch_to_rgb"]["black (L=0)"] = function()
  local r, g, b = color.oklch_to_rgb(0, 0, 0)
  eq(true, r ~= nil)
  eq(true, math.abs(r) < 1)
  eq(true, math.abs(g) < 1)
  eq(true, math.abs(b) < 1)
end

T["oklch_to_rgb"]["white (L=1, C=0)"] = function()
  local r, g, b = color.oklch_to_rgb(1, 0, 0)
  eq(true, math.abs(r - 255) < 2)
  eq(true, math.abs(g - 255) < 2)
  eq(true, math.abs(b - 255) < 2)
end

T["oklch_to_rgb"]["mid gray (L=0.5, C=0)"] = function()
  local r, g, b = color.oklch_to_rgb(0.5, 0, 0)
  eq(true, r ~= nil)
  -- Gray: r == g == b
  eq(true, math.abs(r - g) < 1)
  eq(true, math.abs(g - b) < 1)
end

T["oklch_to_rgb"]["returns nil when L > 1"] = function()
  eq(nil, color.oklch_to_rgb(1.5, 0.2, 180))
end

T["oklch_to_rgb"]["returns nil when C < 0"] = function()
  eq(nil, color.oklch_to_rgb(0.5, -0.1, 180))
end

T["oklch_to_rgb"]["clamps to 0-255 range"] = function()
  local r, g, b = color.oklch_to_rgb(0.5, 0.3, 90)
  eq(true, r ~= nil)
  eq(true, r >= 0 and r <= 255)
  eq(true, g >= 0 and g <= 255)
  eq(true, b >= 0 and b <= 255)
end

-- is_bright -------------------------------------------------------------------

T["is_bright"] = new_set()

T["is_bright"]["white is bright"] = function()
  eq(true, color.is_bright(255, 255, 255))
end

T["is_bright"]["black is not bright"] = function()
  eq(false, color.is_bright(0, 0, 0))
end

T["is_bright"]["pure green is bright"] = function()
  -- Luminance = 0.587 * 255 / 255 = 0.587 > 0.5
  eq(true, color.is_bright(0, 255, 0))
end

T["is_bright"]["pure blue is not bright"] = function()
  -- Luminance = 0.114 * 255 / 255 = 0.114 < 0.5
  eq(false, color.is_bright(0, 0, 255))
end

T["is_bright"]["pure red is not bright"] = function()
  -- Luminance = 0.299 * 255 / 255 = 0.299 < 0.5
  eq(false, color.is_bright(255, 0, 0))
end

return T
