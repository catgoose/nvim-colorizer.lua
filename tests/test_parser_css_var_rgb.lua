local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.css_var_rgb").parser

local T = new_set()

-- Basic parsing ---------------------------------------------------------------

T["basic"] = new_set()

T["basic"]["parses --ctp-flamingo: 240,198,198;"] = function()
  local len, hex = parser("--ctp-flamingo: 240,198,198;", 1, {})
  eq(true, len ~= nil)
  eq("f0c6c6", hex)
end

T["basic"]["parses --color: 255,0,0;"] = function()
  local len, hex = parser("--color: 255,0,0;", 1, {})
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["basic"]["parses --my-var: 0,255,0;"] = function()
  local len, hex = parser("--my-var: 0,255,0;", 1, {})
  eq(true, len ~= nil)
  eq("00ff00", hex)
end

T["basic"]["parses --blue: 0,0,255;"] = function()
  local len, hex = parser("--blue: 0,0,255;", 1, {})
  eq(true, len ~= nil)
  eq("0000ff", hex)
end

T["basic"]["parses black --black: 0,0,0;"] = function()
  local len, hex = parser("--black: 0,0,0;", 1, {})
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["basic"]["parses white --white: 255,255,255;"] = function()
  local len, hex = parser("--white: 255,255,255;", 1, {})
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

-- Spacing variations ----------------------------------------------------------

T["spacing"] = new_set()

T["spacing"]["spaces around commas"] = function()
  local len, hex = parser("--color: 255, 128, 64;", 1, {})
  eq(true, len ~= nil)
  eq("ff8040", hex)
end

T["spacing"]["no spaces around commas"] = function()
  local len, hex = parser("--color: 255,128,64;", 1, {})
  eq(true, len ~= nil)
  eq("ff8040", hex)
end

T["spacing"]["extra spaces around colon"] = function()
  local len, hex = parser("--color  :  255,128,64;", 1, {})
  eq(true, len ~= nil)
  eq("ff8040", hex)
end

T["spacing"]["trailing space instead of semicolon"] = function()
  local len, hex = parser("--color: 255,128,64 ", 1, {})
  eq(true, len ~= nil)
  eq("ff8040", hex)
end

-- Variable name variations ----------------------------------------------------

T["var names"] = new_set()

T["var names"]["hyphenated name"] = function()
  local len, hex = parser("--my-custom-color: 100,200,50;", 1, {})
  eq(true, len ~= nil)
  eq("64c832", hex)
end

T["var names"]["underscore name"] = function()
  local len, hex = parser("--my_color: 100,200,50;", 1, {})
  eq(true, len ~= nil)
  eq("64c832", hex)
end

T["var names"]["single char name"] = function()
  local len, hex = parser("--x: 100,200,50;", 1, {})
  eq(true, len ~= nil)
end

-- Clamping --------------------------------------------------------------------

T["clamping"] = new_set()

T["clamping"]["values > 255 clamped"] = function()
  local len, hex = parser("--color: 300,300,300;", 1, {})
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

-- Invalid inputs --------------------------------------------------------------

T["invalid"] = new_set()

T["invalid"]["missing semicolon or space at end still fails if line too short"] = function()
  -- Needs at least 10 chars from start
  local len = parser("--c: 1,2", 1, {})
  eq(nil, len)
end

T["invalid"]["single dash prefix"] = function()
  local len = parser("-color: 255,0,0;", 1, {})
  eq(nil, len)
end

T["invalid"]["no dash prefix"] = function()
  local len = parser("color: 255,0,0;", 1, {})
  eq(nil, len)
end

T["invalid"]["not enough values"] = function()
  local len = parser("--color: 255,0;", 1, {})
  eq(nil, len)
end

T["invalid"]["line too short"] = function()
  local len = parser("--c: 1,2", 1, {})
  eq(nil, len)
end

-- Offset parsing --------------------------------------------------------------

T["offset"] = new_set()

T["offset"]["parses at offset"] = function()
  local len, hex = parser("  --color: 255,0,0;", 3, {})
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

return T
