local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.rgba_hex").parser

local T = new_set()

-- Helper to build opts for the rgba_hex parser
local function make_opts(formats)
  formats = formats or { RGB = true, RGBA = true, RRGGBB = true, RRGGBBAA = true }
  local valid_lengths = {
    [3] = formats.RGB or false,
    [4] = formats.RGBA or false,
    [6] = formats.RRGGBB or false,
    [8] = formats.RRGGBBAA or false,
  }
  local minlen, maxlen
  for k, v in pairs(valid_lengths) do
    if v then
      minlen = minlen and math.min(k, minlen) or k
      maxlen = maxlen and math.max(k, maxlen) or k
    end
  end
  return { valid_lengths = valid_lengths, minlen = minlen or 3, maxlen = maxlen or 8 }
end

local default_opts = make_opts()

-- #RGB ------------------------------------------------------------------------

T["#RGB"] = new_set()

T["#RGB"]["parses #F0F"] = function()
  local len, hex = parser("#F0F", 1, default_opts)
  eq(4, len)
  eq("ff00ff", hex)
end

T["#RGB"]["parses #FFF"] = function()
  local len, hex = parser("#FFF", 1, default_opts)
  eq(4, len)
  eq("ffffff", hex)
end

T["#RGB"]["parses #000"] = function()
  local len, hex = parser("#000", 1, default_opts)
  eq(4, len)
  eq("000000", hex)
end

T["#RGB"]["parses lowercase #def"] = function()
  local len, hex = parser("#def", 1, default_opts)
  eq(4, len)
  eq("ddeeff", hex)
end

-- #RRGGBB ---------------------------------------------------------------------

T["#RRGGBB"] = new_set()

T["#RRGGBB"]["parses #FFFF00"] = function()
  local len, hex = parser("#FFFF00", 1, default_opts)
  eq(7, len)
  eq("ffff00", hex:lower())
end

T["#RRGGBB"]["parses #32a14b"] = function()
  local len, hex = parser("#32a14b", 1, default_opts)
  eq(7, len)
  eq("32a14b", hex)
end

-- #RRGGBBAA -------------------------------------------------------------------

T["#RRGGBBAA"] = new_set()

T["#RRGGBBAA"]["full alpha #FFFFFFCC"] = function()
  local len, hex = parser("#FFFFFFCC", 1, default_opts)
  eq(9, len)
  -- CC = 204, alpha = 204/255 ≈ 0.8, 255*0.8 = 204
  eq(true, hex ~= nil)
end

T["#RRGGBBAA"]["zero alpha"] = function()
  local len, hex = parser("#FF000000", 1, default_opts)
  eq(9, len)
  eq("000000", hex)
end

T["#RRGGBBAA"]["full alpha FF"] = function()
  local len, hex = parser("#FF0000FF", 1, default_opts)
  eq(9, len)
  -- alpha = FF/255 = 1.0, floor(255*1) = 255
  eq("ff0000", hex)
end

-- #RGBA -----------------------------------------------------------------------

T["#RGBA"] = new_set()

T["#RGBA"]["parses #F0F5"] = function()
  local opts = make_opts({ RGBA = true })
  local len, hex = parser("#F0F5", 1, opts)
  eq(5, len)
  -- F=15, 15*17=255; alpha=5/15=0.333, r=floor(255*0.333)=84
  eq(true, hex ~= nil)
end

T["#RGBA"]["full alpha F"] = function()
  local opts = make_opts({ RGBA = true })
  local len, hex = parser("#F0FF", 1, opts)
  eq(5, len)
  -- alpha = F/15 = 1.0
  eq("ff00ff", hex)
end

-- Boundary rejection ----------------------------------------------------------

T["boundary rejection"] = new_set()

T["boundary rejection"]["rejects when preceded by alphanumeric"] = function()
  local len = parser("a#FFF", 2, default_opts)
  eq(nil, len)
end

T["boundary rejection"]["rejects when followed by alphanumeric beyond max length"] = function()
  -- #FFFaaa is actually valid #RRGGBB (all hex), so use non-hex trailing alpha
  local len = parser("#FFF0g", 1, default_opts)
  -- #FFF is valid RGB (3 hex digits) then '0g' - '0' is hex so this extends to 4 hex chars
  -- #FFF0 with 'g' after = 4 hex digits = RGBA length; but 'g' is alphanumeric -> rejected
  eq(nil, len)
end

T["boundary rejection"]["rejects invalid lengths"] = function()
  -- #F (1 hex char) - not a valid length
  local len = parser("#F ", 1, default_opts)
  eq(nil, len)
end

T["boundary rejection"]["rejects 5-digit hex without RGBA enabled"] = function()
  local opts = make_opts({ RGB = true, RRGGBB = true })
  local len = parser("#F0FFF", 1, opts)
  eq(nil, len)
end

T["boundary rejection"]["rejects non-hex chars"] = function()
  local len = parser("#GGG", 1, default_opts)
  eq(nil, len)
end

-- Offset parsing --------------------------------------------------------------

T["offset parsing"] = new_set()

T["offset parsing"]["parses at offset in line"] = function()
  local len, hex = parser("color: #FF00FF;", 8, default_opts)
  eq(7, len)
  eq("ff00ff", hex:lower())
end

return T
