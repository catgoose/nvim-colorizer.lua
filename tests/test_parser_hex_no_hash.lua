local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.hex_no_hash").parser

local T = new_set()

local default_opts = { rrggbb = true, rrggbbaa = true }
local rrggbb_only = { rrggbb = true, rrggbbaa = false }
local rrggbbaa_only = { rrggbb = false, rrggbbaa = true }

-- RRGGBB (6-digit) -----------------------------------------------------------

T["RRGGBB"] = new_set()

T["RRGGBB"]["parses FF0000 as red"] = function()
  local len, hex = parser("FF0000", 1, default_opts)
  eq(6, len)
  eq("ff0000", hex)
end

T["RRGGBB"]["parses 00FF00 as green"] = function()
  local len, hex = parser("00FF00", 1, default_opts)
  eq(6, len)
  eq("00ff00", hex)
end

T["RRGGBB"]["parses 0000FF as blue"] = function()
  local len, hex = parser("0000FF", 1, default_opts)
  eq(6, len)
  eq("0000ff", hex)
end

T["RRGGBB"]["parses lowercase abcdef"] = function()
  local len, hex = parser("abcdef", 1, default_opts)
  eq(6, len)
  eq("abcdef", hex)
end

T["RRGGBB"]["parses 000000 as black"] = function()
  local len, hex = parser("000000", 1, default_opts)
  eq(6, len)
  eq("000000", hex)
end

T["RRGGBB"]["parses ffffff as white"] = function()
  local len, hex = parser("ffffff", 1, default_opts)
  eq(6, len)
  eq("ffffff", hex)
end

-- RRGGBBAA (8-digit) ----------------------------------------------------------

T["RRGGBBAA"] = new_set()

T["RRGGBBAA"]["full alpha FF"] = function()
  local len, hex = parser("FF0000FF", 1, default_opts)
  eq(8, len)
  eq("ff0000", hex)
end

T["RRGGBBAA"]["zero alpha"] = function()
  local len, hex = parser("FF000000", 1, default_opts)
  eq(8, len)
  eq("000000", hex)
end

T["RRGGBBAA"]["half alpha"] = function()
  local len, hex = parser("FF000080", 1, default_opts)
  eq(8, len)
  eq(true, hex ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, math.abs(r - 128) <= 1)
end

-- Options filtering -----------------------------------------------------------

T["options"] = new_set()

T["options"]["rejects 6-digit when rrggbb disabled"] = function()
  local len = parser("FF0000", 1, rrggbbaa_only)
  eq(nil, len)
end

T["options"]["rejects 8-digit when rrggbbaa disabled"] = function()
  local len = parser("FF0000FF", 1, rrggbb_only)
  eq(nil, len)
end

T["options"]["allows 6-digit when rrggbb enabled"] = function()
  local len, hex = parser("FF0000", 1, rrggbb_only)
  eq(6, len)
  eq("ff0000", hex)
end

-- Boundary rejection ----------------------------------------------------------

T["boundary rejection"] = new_set()

T["boundary rejection"]["rejects when preceded by alphanumeric"] = function()
  local len = parser("xABCDEF", 2, default_opts)
  eq(nil, len)
end

T["boundary rejection"]["rejects when followed by alphanumeric"] = function()
  local len = parser("ABCDEFg", 1, default_opts)
  eq(nil, len)
end

T["boundary rejection"]["accepts when preceded by space"] = function()
  local len, hex = parser(" ABCDEF", 2, default_opts)
  eq(6, len)
  eq("abcdef", hex)
end

T["boundary rejection"]["accepts when followed by space"] = function()
  local len, hex = parser("ABCDEF ", 1, default_opts)
  eq(6, len)
  eq("abcdef", hex)
end

T["boundary rejection"]["accepts when followed by semicolon"] = function()
  local len, hex = parser("ABCDEF;", 1, default_opts)
  eq(6, len)
  eq("abcdef", hex)
end

T["boundary rejection"]["accepts at start of line"] = function()
  local len, hex = parser("FF0000", 1, default_opts)
  eq(6, len)
  eq("ff0000", hex)
end

-- Invalid inputs --------------------------------------------------------------

T["invalid"] = new_set()

T["invalid"]["rejects 5-digit hex"] = function()
  local len = parser("ABCDE ", 1, default_opts)
  eq(nil, len)
end

T["invalid"]["rejects 7-digit hex"] = function()
  local len = parser("ABCDEFa ", 1, default_opts)
  eq(nil, len)
end

T["invalid"]["rejects non-hex chars"] = function()
  local len = parser("GHIJKL", 1, default_opts)
  eq(nil, len)
end

T["invalid"]["rejects line too short"] = function()
  local len = parser("ABC", 1, default_opts)
  eq(nil, len)
end

-- Offset parsing --------------------------------------------------------------

T["offset parsing"] = new_set()

T["offset parsing"]["parses at offset"] = function()
  local len, hex = parser("color: FF00FF;", 8, default_opts)
  eq(6, len)
  eq("ff00ff", hex)
end

T["offset parsing"]["rejects at offset when preceded by alpha"] = function()
  local len = parser("colorFF00FF", 6, default_opts)
  eq(nil, len)
end

return T
