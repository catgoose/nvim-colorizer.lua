local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.lab").parser

local T = new_set()

-- Basic -----------------------------------------------------------------------

T["basic"] = new_set()

T["basic"]["lab(100 0 0) is white"] = function()
  local len, hex = parser("lab(100 0 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r > 250)
end

T["basic"]["lab(0 0 0) is black"] = function()
  local len, hex = parser("lab(0 0 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r < 5)
end

T["basic"]["lab(50 0 0) is mid-gray"] = function()
  local len, hex = parser("lab(50 0 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  -- L=50 in Lab should be roughly mid-gray
  eq(true, r > 80 and r < 140)
end

T["basic"]["lab(50 80 0) is reddish"] = function()
  local len, hex = parser("lab(50 80 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  eq(true, r > g) -- positive a-axis is red
end

T["basic"]["lab(50 -80 0) is greenish"] = function()
  local len, hex = parser("lab(50 -80 0)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  eq(true, g > r) -- negative a-axis is green
end

-- Percentage values -----------------------------------------------------------

T["percentage"] = new_set()

T["percentage"]["lab(50% 0 0)"] = function()
  local len, hex = parser("lab(50% 0 0)", 1, {})
  eq(true, len ~= nil)
end

T["percentage"]["lab(50 50% 0)"] = function()
  -- 50% on a-axis = 62.5
  local len, hex = parser("lab(50 50% 0)", 1, {})
  eq(true, len ~= nil)
end

T["percentage"]["lab(50 0 -50%)"] = function()
  -- -50% on b-axis = -62.5
  local len, hex = parser("lab(50 0 -50%)", 1, {})
  eq(true, len ~= nil)
end

-- Alpha -----------------------------------------------------------------------

T["alpha"] = new_set()

T["alpha"]["lab with decimal alpha"] = function()
  local len, hex = parser("lab(50 80 0 / 0.5)", 1, {})
  eq(true, len ~= nil)
end

T["alpha"]["lab with percentage alpha"] = function()
  local len, hex = parser("lab(50 80 0 / 50%)", 1, {})
  eq(true, len ~= nil)
end

T["alpha"]["alpha clamped to 1"] = function()
  local len1, hex1 = parser("lab(50 80 0 / 1.5)", 1, {})
  local len2, hex2 = parser("lab(50 80 0 / 1)", 1, {})
  eq(hex1, hex2)
end

T["alpha"]["zero alpha is black"] = function()
  local len, hex = parser("lab(50 80 0 / 0)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

-- Clamping --------------------------------------------------------------------

T["clamping"] = new_set()

T["clamping"]["L > 100 clamped to 100"] = function()
  local len1, hex1 = parser("lab(150 0 0)", 1, {})
  local len2, hex2 = parser("lab(100 0 0)", 1, {})
  eq(true, len1 ~= nil)
  eq(hex1, hex2) -- both should be white
end

T["clamping"]["negative L clamped to 0"] = function()
  local len1, hex1 = parser("lab(-50 0 0)", 1, {})
  local len2, hex2 = parser("lab(0 0 0)", 1, {})
  eq(true, len1 ~= nil)
  eq(hex1, hex2) -- both should be black
end

T["clamping"]["negative alpha clamped to 0"] = function()
  local len, hex = parser("lab(50 80 0 / -0.5)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

-- Decimals --------------------------------------------------------------------

T["decimals"] = new_set()

T["decimals"]["decimal L, a, b"] = function()
  local len, hex = parser("lab(50.5 30.2 -10.7)", 1, {})
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

-- Extra whitespace ------------------------------------------------------------

T["whitespace"] = new_set()

T["whitespace"]["extra internal spaces"] = function()
  local len, hex = parser("lab(  0   0   0  )", 1, {})
  eq(true, len ~= nil)
end

T["whitespace"]["extra spaces around alpha slash"] = function()
  local len, hex = parser("lab(50 80 0   /   0.5)", 1, {})
  eq(true, len ~= nil)
end

-- Return length ---------------------------------------------------------------

T["return length"] = new_set()

T["return length"]["returns correct end index"] = function()
  local len, hex = parser("lab(0 0 0)", 1, {})
  eq(10, len) -- length of "lab(0 0 0)"
end

-- Invalid ---------------------------------------------------------------------

T["invalid"] = new_set()

T["invalid"]["missing b value"] = function()
  local len = parser("lab(50 80)", 1, {})
  eq(nil, len)
end

T["invalid"]["comma separated"] = function()
  local len = parser("lab(50, 80, 0)", 1, {})
  eq(nil, len)
end

T["invalid"]["empty lab()"] = function()
  local len = parser("lab()", 1, {})
  eq(nil, len)
end

T["invalid"]["space before paren"] = function()
  local len = parser("lab (50 80 0)", 1, {})
  eq(nil, len)
end

T["invalid"]["alpha without slash"] = function()
  local len = parser("lab(50 80 0 1)", 1, {})
  eq(nil, len)
end

-- Offset ----------------------------------------------------------------------

T["offset"] = new_set()

T["offset"]["mid-line match"] = function()
  local len, hex = parser("color: lab(0 0 0);", 8, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r < 5)
end

return T
