local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.oklch").parser

local T = new_set()

-- Basic -----------------------------------------------------------------------

T["basic"] = new_set()

T["basic"]["oklch(0.5 0.2 180)"] = function()
  local len, hex = parser("oklch(0.5 0.2 180)", 1, {})
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["basic"]["oklch(1 0 0) is white"] = function()
  local len, hex = parser("oklch(1 0 0)", 1, {})
  eq(true, len ~= nil)
  -- L=1, C=0 should be white
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r > 250)
end

T["basic"]["oklch(0 0 0) is black"] = function()
  local len, hex = parser("oklch(0 0 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r < 5)
end

-- Percentage lightness --------------------------------------------------------

T["percentage lightness"] = new_set()

T["percentage lightness"]["oklch(50% 0.2 180)"] = function()
  local len, hex = parser("oklch(50% 0.2 180)", 1, {})
  eq(true, len ~= nil)
end

T["percentage lightness"]["oklch(75% 0.15 240)"] = function()
  local len, hex = parser("oklch(75% 0.15 240)", 1, {})
  eq(true, len ~= nil)
end

T["percentage lightness"]["oklch(0.5% 0.2 180)"] = function()
  -- 0.5% = 0.005 lightness
  local len, hex = parser("oklch(0.5% 0.2 180)", 1, {})
  eq(true, len ~= nil)
end

-- Percentage chroma -----------------------------------------------------------

T["percentage chroma"] = new_set()

T["percentage chroma"]["oklch(0.5 50% 180) => C = 0.2"] = function()
  local len, hex = parser("oklch(0.5 50% 180)", 1, {})
  eq(true, len ~= nil)
end

T["percentage chroma"]["oklch(0.5 100% 180) => C = 0.4"] = function()
  local len, hex = parser("oklch(0.5 100% 180)", 1, {})
  eq(true, len ~= nil)
end

-- Hue units -------------------------------------------------------------------

T["hue units"] = new_set()

T["hue units"]["deg suffix"] = function()
  local len, hex = parser("oklch(0.5 0.2 180deg)", 1, {})
  eq(true, len ~= nil)
end

T["hue units"]["turn suffix"] = function()
  local len, hex = parser("oklch(0.5 0.2 0.5turn)", 1, {})
  eq(true, len ~= nil)
end

T["hue units"]["grad suffix"] = function()
  local len, hex = parser("oklch(0.5 0.2 200grad)", 1, {})
  eq(true, len ~= nil)
end

-- Alpha -----------------------------------------------------------------------

T["alpha"] = new_set()

T["alpha"]["oklch with decimal alpha"] = function()
  local len, hex = parser("oklch(0.5 0.2 180 / 0.5)", 1, {})
  eq(true, len ~= nil)
end

T["alpha"]["oklch with percentage alpha"] = function()
  local len, hex = parser("oklch(50% 0.2 180 / 50%)", 1, {})
  eq(true, len ~= nil)
end

T["alpha"]["alpha clamped to 0-1"] = function()
  local len1, hex1 = parser("oklch(0.5 0.2 180 / 1.5)", 1, {})
  local len2, hex2 = parser("oklch(0.5 0.2 180 / 1)", 1, {})
  -- Both should produce same result since alpha > 1 is clamped to 1
  eq(hex1, hex2)
end

T["alpha"]["negative alpha clamped to 0"] = function()
  local len, hex = parser("oklch(0.5 0.2 180 / -0.1)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex) -- alpha=0 means all channels are 0
end

-- Clamping --------------------------------------------------------------------

T["clamping"] = new_set()

T["clamping"]["L > 1 clamped to 1 (white-ish)"] = function()
  -- Parser clamps L to [0,1] before passing to oklch_to_rgb
  local len, hex = parser("oklch(1.5 0.2 180)", 1, {})
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["clamping"]["L > 100% clamped to 1 (white-ish)"] = function()
  local len, hex = parser("oklch(150% 0.2 180)", 1, {})
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["clamping"]["negative C clamped to 0"] = function()
  local len, hex = parser("oklch(0.5 -0.1 180)", 1, {})
  -- Negative chroma is clamped to 0
  eq(true, len ~= nil)
end

T["clamping"]["negative hue wraps"] = function()
  local len, hex = parser("oklch(0.5 0.2 -90)", 1, {})
  eq(true, len ~= nil)
end

-- Invalid ---------------------------------------------------------------------

T["invalid"] = new_set()

T["invalid"]["missing hue"] = function()
  local len = parser("oklch(0.5 0.2)", 1, {})
  eq(nil, len)
end

T["invalid"]["comma separated (not valid CSS)"] = function()
  local len = parser("oklch(0.5, 0.2, 180)", 1, {})
  eq(nil, len)
end

T["invalid"]["empty oklch()"] = function()
  local len = parser("oklch()", 1, {})
  eq(nil, len)
end

T["invalid"]["space before paren"] = function()
  local len = parser("oklch (0.5 0.2 180)", 1, {})
  eq(nil, len)
end

T["invalid"]["alpha without slash"] = function()
  local len = parser("oklch(0.5  0.2  180  1)", 1, {})
  eq(nil, len)
end

return T
