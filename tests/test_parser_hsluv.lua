local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.hsluv").parser

local T = new_set()

local hsluv_opts = { prefix = "hsluv" }
local hsluvu_opts = { prefix = "hsluvu" }

-- HSLuv basic -----------------------------------------------------------------

T["hsluv basic"] = new_set()

T["hsluv basic"]["comma separated hsluv(0, 100, 50)"] = function()
  local len, hex = parser("hsluv(0, 100, 50)", 1, hsluv_opts)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["hsluv basic"]["space separated hsluv(0 100 50)"] = function()
  local len, hex = parser("hsluv(0 100 50)", 1, hsluv_opts)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["hsluv basic"]["hsluv(0, 0, 100) is white"] = function()
  local len, hex = parser("hsluv(0, 0, 100)", 1, hsluv_opts)
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

T["hsluv basic"]["hsluv(0, 0, 0) is black"] = function()
  local len, hex = parser("hsluv(0, 0, 0)", 1, hsluv_opts)
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["hsluv basic"]["hsluv(0, 100, 50) is reddish"] = function()
  local len, hex = parser("hsluv(0, 100, 50)", 1, hsluv_opts)
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r > 200)
end

-- HSLuv with degrees and turns ------------------------------------------------

T["hsluv deg/turn"] = new_set()

T["hsluv deg/turn"]["hsluv with deg suffix"] = function()
  local len, hex = parser("hsluv(0deg, 100, 50)", 1, hsluv_opts)
  eq(true, len ~= nil)
end

T["hsluv deg/turn"]["hsluv with turn"] = function()
  local len, hex = parser("hsluv(0.5turn, 100, 50)", 1, hsluv_opts)
  eq(true, len ~= nil)
end

-- HSLuv with alpha ------------------------------------------------------------

T["hsluv alpha"] = new_set()

T["hsluv alpha"]["hsluv with slash alpha"] = function()
  local len, hex = parser("hsluv(0 100 50 / 0.5)", 1, hsluv_opts)
  eq(true, len ~= nil)
end

T["hsluv alpha"]["hsluv with comma alpha"] = function()
  local len, hex = parser("hsluv(0, 100, 50, 0.5)", 1, hsluv_opts)
  eq(true, len ~= nil)
end

T["hsluv alpha"]["hsluv with percentage alpha"] = function()
  local len, hex = parser("hsluv(0 100 50 / 50%)", 1, hsluv_opts)
  eq(true, len ~= nil)
end

T["hsluv alpha"]["alpha 0 blends to black"] = function()
  local len, hex = parser("hsluv(0, 100, 50, 0)", 1, hsluv_opts)
  eq(true, len ~= nil)
  eq("000000", hex)
end

-- HSLuv clamping --------------------------------------------------------------

T["hsluv clamping"] = new_set()

T["hsluv clamping"]["hue > 360 wraps around"] = function()
  local len, hex = parser("hsluv(720, 100, 50)", 1, hsluv_opts)
  eq(true, len ~= nil)
end

T["hsluv clamping"]["saturation > 100 clamped"] = function()
  local len, hex = parser("hsluv(0, 200, 50)", 1, hsluv_opts)
  eq(true, len ~= nil)
end

T["hsluv clamping"]["alpha > 1 clamped to 1"] = function()
  local len1, hex1 = parser("hsluv(0, 100, 50, 1)", 1, hsluv_opts)
  local len2, hex2 = parser("hsluv(0, 100, 50, 5)", 1, hsluv_opts)
  eq(hex1, hex2)
end

-- HSLuvu (alpha variant) ------------------------------------------------------

T["hsluvu"] = new_set()

T["hsluvu"]["basic hsluvu(0 100 50)"] = function()
  local len, hex = parser("hsluvu(0 100 50)", 1, hsluvu_opts)
  eq(true, len ~= nil)
end

T["hsluvu"]["hsluvu with alpha"] = function()
  local len, hex = parser("hsluvu(0, 100, 50, 0.5)", 1, hsluvu_opts)
  eq(true, len ~= nil)
end

-- HSLuv invalid ---------------------------------------------------------------

T["hsluv invalid"] = new_set()

T["hsluv invalid"]["empty hsluv()"] = function()
  local len = parser("hsluv()", 1, hsluv_opts)
  eq(nil, len)
end

T["hsluv invalid"]["missing closing paren"] = function()
  local len = parser("hsluv(0, 100, 50", 1, hsluv_opts)
  eq(nil, len)
end

T["hsluv invalid"]["space before paren"] = function()
  local len = parser("hsluv (0, 100, 50)", 1, hsluv_opts)
  eq(nil, len)
end

T["hsluv invalid"]["mixed separators rejected"] = function()
  local len = parser("hsluv(0 100 50 1)", 1, hsluv_opts)
  eq(nil, len)
end

T["hsluv invalid"]["line too short"] = function()
  local len = parser("hsluv(", 1, hsluv_opts)
  eq(nil, len)
end

T["hsluv invalid"]["trailing comma with missing lightness"] = function()
  local len = parser("hsluv(0, 100,)", 1, hsluv_opts)
  eq(nil, len)
end

-- HSLuv decimals --------------------------------------------------------------

T["hsluv decimals"] = new_set()

T["hsluv decimals"]["decimal hue"] = function()
  local len, hex = parser("hsluv(180.5, 50, 50)", 1, hsluv_opts)
  eq(true, len ~= nil)
end

T["hsluv decimals"]["decimal saturation and lightness"] = function()
  local len, hex = parser("hsluv(0, 50.5, 50.5)", 1, hsluv_opts)
  eq(true, len ~= nil)
end

return T
