local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local names = require("colorizer.parser.names")
local parser = require("colorizer.parser.xcolor").parser

local T = new_set({
  hooks = {
    pre_case = function()
      names.reset_cache()
    end,
  },
})

-- Helper: build opts that xcolor expects (needs opts.parsers.names)
local function make_opts(overrides)
  overrides = overrides or {}
  return {
    parsers = {
      names = overrides.names_opts or { lowercase = true, camelcase = true, uppercase = false, strip_digits = false },
      tailwind = overrides.tailwind or nil,
    },
  }
end

local default_opts = make_opts()

-- Basic parsing ---------------------------------------------------------------

T["basic"] = new_set()

T["basic"]["red!100 is pure red"] = function()
  local len, hex = parser("red!100", 1, default_opts)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["basic"]["red!0 is white"] = function()
  local len, hex = parser("red!0", 1, default_opts)
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

T["basic"]["red!50 is midpoint between red and white"] = function()
  local len, hex = parser("red!50", 1, default_opts)
  eq(true, len ~= nil)
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  -- r should be ~255*0.5 + 255*0.5 = 255, g should be ~128
  eq(true, r > 200)
  eq(true, math.abs(g - 128) <= 1)
end

T["basic"]["blue!50 blends blue with white"] = function()
  local len, hex = parser("blue!50", 1, default_opts)
  eq(true, len ~= nil)
  -- CSS blue is #0000FF; 50% blend with white (#FFFFFF):
  -- r = floor(0*0.5 + 255*0.5 + 0.5) = 128, g = 128, b = 255
  local r = tonumber(hex:sub(1, 2), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  eq(true, math.abs(r - 128) <= 1)
  eq(255, b)
end

T["basic"]["green!100 is pure green"] = function()
  local len, hex = parser("green!100", 1, default_opts)
  eq(true, len ~= nil)
  -- CSS "green" is #008000
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  eq(0, r)
  eq(128, g)
end

-- Boundary rejection ----------------------------------------------------------

T["boundary"] = new_set()

T["boundary"]["rejects when followed by alphanumeric"] = function()
  local len = parser("red!50x", 1, default_opts)
  eq(nil, len)
end

T["boundary"]["accepts when followed by space"] = function()
  local len, hex = parser("red!50 ", 1, default_opts)
  eq(true, len ~= nil)
end

T["boundary"]["accepts when followed by semicolon"] = function()
  local len, hex = parser("red!50;", 1, default_opts)
  eq(true, len ~= nil)
end

T["boundary"]["accepts at end of line"] = function()
  local len, hex = parser("red!50", 1, default_opts)
  eq(true, len ~= nil)
end

-- Invalid inputs --------------------------------------------------------------

T["invalid"] = new_set()

T["invalid"]["rejects unknown color name"] = function()
  local len = parser("foobar!50", 1, default_opts)
  eq(nil, len)
end

T["invalid"]["rejects percentage > 100"] = function()
  local len = parser("red!101", 1, default_opts)
  eq(nil, len)
end

T["invalid"]["rejects missing percentage"] = function()
  local len = parser("red!", 1, default_opts)
  eq(nil, len)
end

T["invalid"]["rejects missing color name"] = function()
  local len = parser("!50", 1, default_opts)
  eq(nil, len)
end

T["invalid"]["rejects line too short"] = function()
  local len = parser("r!5", 1, default_opts)
  eq(nil, len)
end

T["invalid"]["rejects nil opts"] = function()
  local len = parser("red!50", 1, nil)
  eq(nil, len)
end

T["invalid"]["rejects opts without parsers"] = function()
  local len = parser("red!50", 1, {})
  eq(nil, len)
end

-- Offset parsing --------------------------------------------------------------

T["offset"] = new_set()

T["offset"]["parses at offset"] = function()
  local len, hex = parser("color: red!50;", 8, default_opts)
  eq(true, len ~= nil)
end

return T
