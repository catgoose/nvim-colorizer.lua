local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.lch").parser

local T = new_set()

-- Basic -----------------------------------------------------------------------

T["basic"] = new_set()

T["basic"]["lch(100 0 0) is white"] = function()
  local len, hex = parser("lch(100 0 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r > 250)
end

T["basic"]["lch(0 0 0) is black"] = function()
  local len, hex = parser("lch(0 0 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r < 5)
end

T["basic"]["lch(50 0 0) is mid-gray"] = function()
  local len, hex = parser("lch(50 0 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r > 80 and r < 140)
end

T["basic"]["lch(50 100 0) is reddish"] = function()
  -- Hue 0 in LCH is along the positive a-axis (red)
  local len, hex = parser("lch(50 100 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  eq(true, r > g)
end

-- Percentage values -----------------------------------------------------------

T["percentage"] = new_set()

T["percentage"]["lch(50% 0 0)"] = function()
  local len, hex = parser("lch(50% 0 0)", 1, {})
  eq(true, len ~= nil)
end

T["percentage"]["lch(50 50% 0) chroma percentage"] = function()
  -- 50% chroma = 75 (100% = 150)
  local len, hex = parser("lch(50 50% 0)", 1, {})
  eq(true, len ~= nil)
end

-- Hue units -------------------------------------------------------------------

T["hue units"] = new_set()

T["hue units"]["deg suffix"] = function()
  local len, hex = parser("lch(50 100 180deg)", 1, {})
  eq(true, len ~= nil)
end

T["hue units"]["turn suffix"] = function()
  local len, hex = parser("lch(50 100 0.5turn)", 1, {})
  eq(true, len ~= nil)
end

T["hue units"]["rad suffix"] = function()
  local len, hex = parser("lch(50 100 3.14159rad)", 1, {})
  eq(true, len ~= nil)
end

T["hue units"]["grad suffix"] = function()
  local len, hex = parser("lch(50 100 200grad)", 1, {})
  eq(true, len ~= nil)
end

-- Alpha -----------------------------------------------------------------------

T["alpha"] = new_set()

T["alpha"]["lch with decimal alpha"] = function()
  local len, hex = parser("lch(50 100 0 / 0.5)", 1, {})
  eq(true, len ~= nil)
end

T["alpha"]["lch with percentage alpha"] = function()
  local len, hex = parser("lch(50 100 0 / 50%)", 1, {})
  eq(true, len ~= nil)
end

T["alpha"]["alpha clamped to 1"] = function()
  local len1, hex1 = parser("lch(50 100 0 / 1.5)", 1, {})
  local len2, hex2 = parser("lch(50 100 0 / 1)", 1, {})
  eq(hex1, hex2)
end

T["alpha"]["zero alpha is black"] = function()
  local len, hex = parser("lch(50 100 0 / 0)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

-- Invalid ---------------------------------------------------------------------

T["invalid"] = new_set()

T["invalid"]["missing hue"] = function()
  local len = parser("lch(50 100)", 1, {})
  eq(nil, len)
end

T["invalid"]["comma separated"] = function()
  local len = parser("lch(50, 100, 0)", 1, {})
  eq(nil, len)
end

T["invalid"]["empty lch()"] = function()
  local len = parser("lch()", 1, {})
  eq(nil, len)
end

T["invalid"]["space before paren"] = function()
  local len = parser("lch (50 100 0)", 1, {})
  eq(nil, len)
end

T["invalid"]["alpha without slash"] = function()
  local len = parser("lch(50 100 0 1)", 1, {})
  eq(nil, len)
end

T["invalid"]["invalid hue unit"] = function()
  local len = parser("lch(50 100 180foo)", 1, {})
  eq(nil, len)
end

-- Offset ----------------------------------------------------------------------

T["offset"] = new_set()

T["offset"]["mid-line match"] = function()
  local len, hex = parser("color: lch(0 0 0);", 8, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r < 5)
end

return T
