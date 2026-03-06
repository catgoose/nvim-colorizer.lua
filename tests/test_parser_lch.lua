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

-- Clamping --------------------------------------------------------------------

T["clamping"] = new_set()

T["clamping"]["L > 100 clamped to 100"] = function()
  local len1, hex1 = parser("lch(150 0 0)", 1, {})
  local len2, hex2 = parser("lch(100 0 0)", 1, {})
  eq(true, len1 ~= nil)
  eq(hex1, hex2) -- both should be white
end

T["clamping"]["negative L clamped to 0"] = function()
  local len1, hex1 = parser("lch(-50 0 0)", 1, {})
  local len2, hex2 = parser("lch(0 0 0)", 1, {})
  eq(true, len1 ~= nil)
  eq(hex1, hex2) -- both should be black
end

T["clamping"]["negative chroma clamped to 0"] = function()
  local len1, hex1 = parser("lch(50 -100 0)", 1, {})
  local len2, hex2 = parser("lch(50 0 0)", 1, {})
  eq(true, len1 ~= nil)
  eq(hex1, hex2) -- both should be mid-gray
end

T["clamping"]["negative hue wraps"] = function()
  local len, hex = parser("lch(50 100 -90)", 1, {})
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["clamping"]["negative alpha clamped to 0"] = function()
  local len, hex = parser("lch(50 100 0 / -0.5)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

-- Decimals --------------------------------------------------------------------

T["decimals"] = new_set()

T["decimals"]["decimal L, C, H"] = function()
  local len, hex = parser("lch(50.5 80.2 120.7)", 1, {})
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

-- Extra whitespace ------------------------------------------------------------

T["whitespace"] = new_set()

T["whitespace"]["extra internal spaces"] = function()
  local len, hex = parser("lch(  0   0   0  )", 1, {})
  eq(true, len ~= nil)
end

T["whitespace"]["extra spaces around alpha slash"] = function()
  local len, hex = parser("lch(50 100 0   /   0.5)", 1, {})
  eq(true, len ~= nil)
end

-- Return length ---------------------------------------------------------------

T["return length"] = new_set()

T["return length"]["returns correct end index"] = function()
  local len, hex = parser("lch(0 0 0)", 1, {})
  eq(10, len) -- length of "lch(0 0 0)"
end

-- Cross-parser consistency ----------------------------------------------------

T["cross-parser"] = new_set()

T["cross-parser"]["lch(50 0 0) matches lab(50 0 0) (both are gray)"] = function()
  local lab_parser = require("colorizer.parser.lab").parser
  local _, lch_hex = parser("lch(50 0 0)", 1, {})
  local _, lab_hex = lab_parser("lab(50 0 0)", 1, {})
  eq(lch_hex, lab_hex) -- C=0 means a=0,b=0, so LCH and Lab should agree
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
