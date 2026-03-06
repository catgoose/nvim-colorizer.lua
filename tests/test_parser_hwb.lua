local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.hwb").parser

local T = new_set()

-- Basic -----------------------------------------------------------------------

T["basic"] = new_set()

T["basic"]["hwb(0 0% 0%) is red"] = function()
  local len, hex = parser("hwb(0 0% 0%)", 1, {})
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["basic"]["hwb(0 100% 0%) is white"] = function()
  local len, hex = parser("hwb(0 100% 0%)", 1, {})
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

T["basic"]["hwb(0 0% 100%) is black"] = function()
  local len, hex = parser("hwb(0 0% 100%)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["basic"]["hwb(120 0% 0%) is green"] = function()
  local len, hex = parser("hwb(120 0% 0%)", 1, {})
  eq(true, len ~= nil)
  -- Pure green in HSL at S=100% L=50% is #00ff00
  eq("00ff00", hex)
end

T["basic"]["hwb(240 0% 0%) is blue"] = function()
  local len, hex = parser("hwb(240 0% 0%)", 1, {})
  eq(true, len ~= nil)
  eq("0000ff", hex)
end

-- Gray normalization ----------------------------------------------------------

T["gray"] = new_set()

T["gray"]["hwb(0 50% 50%) is gray"] = function()
  local len, hex = parser("hwb(0 50% 50%)", 1, {})
  eq(true, len ~= nil)
  -- When w + b = 1, result is gray = w/(w+b) * 255 = 127
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r >= 126 and r <= 128)
end

T["gray"]["hwb(0 75% 75%) normalizes to gray"] = function()
  local len, hex = parser("hwb(0 75% 75%)", 1, {})
  eq(true, len ~= nil)
  -- w + b > 1, normalizes: w/(w+b) = 0.5 => gray ~127
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r >= 126 and r <= 128)
end

-- Hue units -------------------------------------------------------------------

T["hue units"] = new_set()

T["hue units"]["deg suffix"] = function()
  local len, hex = parser("hwb(120deg 0% 0%)", 1, {})
  eq(true, len ~= nil)
  eq("00ff00", hex)
end

T["hue units"]["turn suffix"] = function()
  local len, hex = parser("hwb(0.5turn 0% 0%)", 1, {})
  eq(true, len ~= nil)
  -- 0.5 turn = 180 degrees = cyan
end

T["hue units"]["rad suffix"] = function()
  local len, hex = parser("hwb(3.14159rad 0% 0%)", 1, {})
  eq(true, len ~= nil)
end

T["hue units"]["grad suffix"] = function()
  local len, hex = parser("hwb(200grad 0% 0%)", 1, {})
  eq(true, len ~= nil)
  -- 200 grad = 180 degrees
end

-- Alpha -----------------------------------------------------------------------

T["alpha"] = new_set()

T["alpha"]["hwb with decimal alpha"] = function()
  local len, hex = parser("hwb(0 0% 0% / 0.5)", 1, {})
  eq(true, len ~= nil)
  -- Red with alpha 0.5
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r >= 126 and r <= 128)
end

T["alpha"]["hwb with percentage alpha"] = function()
  local len, hex = parser("hwb(0 0% 0% / 50%)", 1, {})
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r >= 126 and r <= 128)
end

T["alpha"]["alpha clamped to 1"] = function()
  local len1, hex1 = parser("hwb(0 0% 0% / 1.5)", 1, {})
  local len2, hex2 = parser("hwb(0 0% 0% / 1)", 1, {})
  eq(hex1, hex2)
end

T["alpha"]["zero alpha is black"] = function()
  local len, hex = parser("hwb(0 0% 0% / 0)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

-- Clamping --------------------------------------------------------------------

T["clamping"] = new_set()

T["clamping"]["negative hue wraps"] = function()
  local len, hex = parser("hwb(-120 0% 0%)", 1, {})
  eq(true, len ~= nil)
  -- -120 degrees wraps to 240 degrees (blue)
  eq("0000ff", hex)
end

T["clamping"]["negative whiteness clamped to 0"] = function()
  local len, hex = parser("hwb(0 -10% 0%)", 1, {})
  eq(true, len ~= nil)
  -- Negative whiteness clamped to 0, same as hwb(0 0% 0%)
  eq("ff0000", hex)
end

T["clamping"]["negative blackness clamped to 0"] = function()
  local len, hex = parser("hwb(0 0% -10%)", 1, {})
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["clamping"]["negative alpha clamped to 0"] = function()
  local len, hex = parser("hwb(0 0% 0% / -0.5)", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

-- Decimals --------------------------------------------------------------------

T["decimals"] = new_set()

T["decimals"]["decimal hue, whiteness, blackness"] = function()
  local len, hex = parser("hwb(120.5 10.5% 20.5%)", 1, {})
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

-- Extra whitespace ------------------------------------------------------------

T["whitespace"] = new_set()

T["whitespace"]["extra internal spaces"] = function()
  local len, hex = parser("hwb(  0   0%   0%  )", 1, {})
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["whitespace"]["extra spaces around alpha slash"] = function()
  local len, hex = parser("hwb(0 0% 0%   /   0.5)", 1, {})
  eq(true, len ~= nil)
end

-- Return length ---------------------------------------------------------------

T["return length"] = new_set()

T["return length"]["returns correct end index"] = function()
  local len, hex = parser("hwb(0 0% 0%)", 1, {})
  eq(12, len) -- length of "hwb(0 0% 0%)"
  eq("ff0000", hex)
end

T["return length"]["mid-line returns length relative to start"] = function()
  local len, hex = parser("x hwb(0 0% 0%) y", 3, {})
  eq(12, len) -- length of "hwb(0 0% 0%)" from the sub(i) perspective
  eq("ff0000", hex)
end

-- Invalid ---------------------------------------------------------------------

T["invalid"] = new_set()

T["invalid"]["missing blackness"] = function()
  local len = parser("hwb(0 50%)", 1, {})
  eq(nil, len)
end

T["invalid"]["comma separated (not valid CSS)"] = function()
  local len = parser("hwb(0, 50%, 50%)", 1, {})
  eq(nil, len)
end

T["invalid"]["empty hwb()"] = function()
  local len = parser("hwb()", 1, {})
  eq(nil, len)
end

T["invalid"]["space before paren"] = function()
  local len = parser("hwb (0 50% 50%)", 1, {})
  eq(nil, len)
end

T["invalid"]["alpha without slash"] = function()
  local len = parser("hwb(0 50% 50% 1)", 1, {})
  eq(nil, len)
end

T["invalid"]["invalid hue unit"] = function()
  local len = parser("hwb(120foo 0% 0%)", 1, {})
  eq(nil, len)
end

-- Offset ----------------------------------------------------------------------

T["offset"] = new_set()

T["offset"]["mid-line match"] = function()
  local len, hex = parser("color: hwb(0 0% 0%);", 8, {})
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

return T
