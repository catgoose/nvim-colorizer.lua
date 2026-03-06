local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.css_color").parser

local T = new_set()

-- srgb ------------------------------------------------------------------------

T["srgb"] = new_set()

T["srgb"]["color(srgb 1 0 0) is red"] = function()
  local len, hex = parser("color(srgb 1 0 0)", 1, {})
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["srgb"]["color(srgb 0 1 0) is green"] = function()
  local len, hex = parser("color(srgb 0 1 0)", 1, {})
  eq(true, len ~= nil)
  eq("00ff00", hex)
end

T["srgb"]["color(srgb 0 0 1) is blue"] = function()
  local len, hex = parser("color(srgb 0 0 1)", 1, {})
  eq(true, len ~= nil)
  eq("0000ff", hex)
end

T["srgb"]["color(srgb 1 1 1) is white"] = function()
  local len, hex = parser("color(srgb 1 1 1)", 1, {})
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

T["srgb"]["color(srgb 0 0 0) is black"] = function()
  local len, hex = parser("color(srgb 0 0 0)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["srgb"]["color(srgb 0.5 0.5 0.5) is mid-gray"] = function()
  local len, hex = parser("color(srgb 0.5 0.5 0.5)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r >= 126 and r <= 128)
end

-- srgb-linear -----------------------------------------------------------------

T["srgb-linear"] = new_set()

T["srgb-linear"]["color(srgb-linear 1 0 0) is red"] = function()
  local len, hex = parser("color(srgb-linear 1 0 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r >= 254) -- linear 1.0 -> sRGB ~1.0, rounding may give fe or ff
end

T["srgb-linear"]["color(srgb-linear 0 0 0) is black"] = function()
  local len, hex = parser("color(srgb-linear 0 0 0)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["srgb-linear"]["mid value is brighter than srgb (gamma)"] = function()
  local _, hex_linear = parser("color(srgb-linear 0.5 0.5 0.5)", 1, {})
  local _, hex_srgb = parser("color(srgb 0.5 0.5 0.5)", 1, {})
  -- Linear 0.5 should map to higher sRGB value than 0.5 due to gamma
  local r_linear = tonumber(hex_linear:sub(1, 2), 16)
  local r_srgb = tonumber(hex_srgb:sub(1, 2), 16)
  eq(true, r_linear > r_srgb)
end

-- display-p3 ------------------------------------------------------------------

T["display-p3"] = new_set()

T["display-p3"]["color(display-p3 1 0 0) is reddish"] = function()
  local len, hex = parser("color(display-p3 1 0 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r > 200) -- P3 red maps to vivid sRGB red
end

T["display-p3"]["color(display-p3 0 0 0) is black"] = function()
  local len, hex = parser("color(display-p3 0 0 0)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["display-p3"]["color(display-p3 1 1 1) is white"] = function()
  local len, hex = parser("color(display-p3 1 1 1)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r > 250)
end

-- a98-rgb ---------------------------------------------------------------------

T["a98-rgb"] = new_set()

T["a98-rgb"]["color(a98-rgb 1 0 0) is reddish"] = function()
  local len, hex = parser("color(a98-rgb 1 0 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r > 200)
end

T["a98-rgb"]["color(a98-rgb 0 0 0) is black"] = function()
  local len, hex = parser("color(a98-rgb 0 0 0)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

-- prophoto-rgb ----------------------------------------------------------------

T["prophoto-rgb"] = new_set()

T["prophoto-rgb"]["color(prophoto-rgb 0 0 0) is black"] = function()
  local len, hex = parser("color(prophoto-rgb 0 0 0)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["prophoto-rgb"]["color(prophoto-rgb 1 1 1) is white"] = function()
  local len, hex = parser("color(prophoto-rgb 1 1 1)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r > 250)
end

-- rec2020 ---------------------------------------------------------------------

T["rec2020"] = new_set()

T["rec2020"]["color(rec2020 1 0 0) is reddish"] = function()
  local len, hex = parser("color(rec2020 1 0 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r > 200)
end

T["rec2020"]["color(rec2020 0 0 0) is black"] = function()
  local len, hex = parser("color(rec2020 0 0 0)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

-- Percentage values -----------------------------------------------------------

T["percentage"] = new_set()

T["percentage"]["color(srgb 100% 0% 0%) is red"] = function()
  local len, hex = parser("color(srgb 100% 0% 0%)", 1, {})
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["percentage"]["color(srgb 50% 50% 50%)"] = function()
  local len, hex = parser("color(srgb 50% 50% 50%)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r >= 126 and r <= 128)
end

-- Alpha -----------------------------------------------------------------------

T["alpha"] = new_set()

T["alpha"]["color with decimal alpha"] = function()
  local len, hex = parser("color(srgb 1 0 0 / 0.5)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r >= 126 and r <= 128)
end

T["alpha"]["color with percentage alpha"] = function()
  local len, hex = parser("color(srgb 1 0 0 / 50%)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r >= 126 and r <= 128)
end

T["alpha"]["alpha clamped to 1"] = function()
  local len1, hex1 = parser("color(srgb 1 0 0 / 1.5)", 1, {})
  local len2, hex2 = parser("color(srgb 1 0 0 / 1)", 1, {})
  eq(hex1, hex2)
end

T["alpha"]["zero alpha is black"] = function()
  local len, hex = parser("color(srgb 1 0 0 / 0)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

-- Invalid ---------------------------------------------------------------------

T["invalid"] = new_set()

T["invalid"]["unknown color space"] = function()
  local len = parser("color(unknown 1 0 0)", 1, {})
  eq(nil, len)
end

T["invalid"]["missing channel"] = function()
  local len = parser("color(srgb 1 0)", 1, {})
  eq(nil, len)
end

T["invalid"]["empty color()"] = function()
  local len = parser("color()", 1, {})
  eq(nil, len)
end

T["invalid"]["space before paren"] = function()
  local len = parser("color (srgb 1 0 0)", 1, {})
  eq(nil, len)
end

T["invalid"]["comma separated"] = function()
  local len = parser("color(srgb, 1, 0, 0)", 1, {})
  eq(nil, len)
end

T["invalid"]["alpha without slash"] = function()
  local len = parser("color(srgb 1 0 0 0.5)", 1, {})
  eq(nil, len)
end

-- Whitespace ------------------------------------------------------------------

T["whitespace"] = new_set()

T["whitespace"]["extra internal spaces"] = function()
  local len, hex = parser("color(  srgb   1   0   0  )", 1, {})
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

-- Offset ----------------------------------------------------------------------

T["offset"] = new_set()

T["offset"]["mid-line match"] = function()
  local len, hex = parser("bg: color(srgb 1 0 0);", 5, {})
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

-- Return length ---------------------------------------------------------------

T["return length"] = new_set()

T["return length"]["returns correct end index"] = function()
  local len, hex = parser("color(srgb 1 0 0)", 1, {})
  eq(17, len) -- match_end - 1 from the sub(i) match
  eq("ff0000", hex)
end

return T
