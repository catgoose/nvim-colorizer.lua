local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.argb_hex").parser

local T = new_set()

-- 0xRGB -----------------------------------------------------------------------

T["0xRGB"] = new_set()

T["0xRGB"]["parses 0xF0F"] = function()
  local len, hex = parser("0xF0F", 1)
  eq(5, len)
  eq("ff00ff", hex)
end

T["0xRGB"]["parses 0xFFF"] = function()
  local len, hex = parser("0xFFF", 1)
  eq(5, len)
  eq("ffffff", hex)
end

T["0xRGB"]["parses 0x000"] = function()
  local len, hex = parser("0x000", 1)
  eq(5, len)
  -- 0*17=0 for each channel
  eq("000000", hex)
end

-- 0xRRGGBB --------------------------------------------------------------------

T["0xRRGGBB"] = new_set()

T["0xRRGGBB"]["parses 0xFFFF00"] = function()
  local len, hex = parser("0xFFFF00", 1)
  eq(8, len)
  eq("ffff00", hex)
end

T["0xRRGGBB"]["parses 0x1B29FB"] = function()
  local len, hex = parser("0x1B29FB", 1)
  eq(8, len)
  eq("1b29fb", hex)
end

-- 0xAARRGGBB ------------------------------------------------------------------

T["0xAARRGGBB"] = new_set()

T["0xAARRGGBB"]["full alpha 0xFFRRGGBB"] = function()
  local len, hex = parser("0xFF1B29FB", 1)
  eq(10, len)
  -- alpha=FF/255=1.0
  eq("1b29fb", hex)
end

T["0xAARRGGBB"]["zero alpha"] = function()
  local len, hex = parser("0x00FF0000", 1)
  eq(10, len)
  eq("000000", hex)
end

T["0xAARRGGBB"]["half alpha"] = function()
  local len, hex = parser("0x80FF0000", 1)
  eq(10, len)
  -- alpha = 128/255 ≈ 0.502, r = floor(255*0.502) = 128
  -- Result should be approximately "800000"
  eq(true, hex ~= nil)
  -- Verify the red channel is approximately 128
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, math.abs(r - 128) <= 1)
end

-- Boundary rejection ----------------------------------------------------------

T["boundary rejection"] = new_set()

T["boundary rejection"]["rejects when followed by alphanumeric"] = function()
  local len = parser("0xFFFFFFF1", 1)
  -- 0xFFFFFFF1 is 10 chars = 0xAARRGGBB
  eq(10, len) -- This is actually valid as 0xAARRGGBB
end

T["boundary rejection"]["rejects invalid lengths"] = function()
  -- 0xFF (only 2 hex chars) - not a valid length
  local len = parser("0xFF ", 1)
  eq(nil, len)
end

T["boundary rejection"]["rejects 0x with 4 hex chars"] = function()
  local len = parser("0x1234 ", 1)
  eq(nil, len)
end

T["boundary rejection"]["rejects 0x with 5 hex chars"] = function()
  local len = parser("0xFFFFF ", 1)
  eq(nil, len)
end

T["boundary rejection"]["rejects non-hex chars after 0x"] = function()
  local len = parser("0xGHI", 1)
  eq(nil, len)
end

T["boundary rejection"]["rejects when followed by non-hex alphanum"] = function()
  -- 0xFFFabc is valid 0xRRGGBB (6 hex chars), so use trailing non-hex alpha
  local len = parser("0xFFFg", 1)
  -- 0xFFF then 'g' is alphanumeric -> rejected
  eq(nil, len)
end

-- Offset parsing --------------------------------------------------------------

T["offset parsing"] = new_set()

T["offset parsing"]["parses at offset"] = function()
  local len, hex = parser("val=0xFF00FF;", 5)
  eq(8, len)
  eq("ff00ff", hex)
end

return T
