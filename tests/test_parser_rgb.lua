local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.rgb").parser

local T = new_set()

local rgb_opts = { prefix = "rgb" }
local rgba_opts = { prefix = "rgba" }

-- RGB basic -------------------------------------------------------------------

T["rgb basic"] = new_set()

T["rgb basic"]["comma separated rgb(255, 200, 80)"] = function()
  local len, hex = parser("rgb(255, 200, 80)", 1, rgb_opts)
  eq(true, len ~= nil)
  eq("ffc850", hex)
end

T["rgb basic"]["space separated rgb(255 122 127 / 80%)"] = function()
  local len, hex = parser("rgb(255 122 127 / 80%)", 1, rgb_opts)
  eq(true, len ~= nil)
end

T["rgb basic"]["rgb(0,0,0) is black"] = function()
  local len, hex = parser("rgb(0,0,0)", 1, rgb_opts)
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["rgb basic"]["rgb(255, 255, 255) is white"] = function()
  local len, hex = parser("rgb(255, 255, 255)", 1, rgb_opts)
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

-- RGB with percentages --------------------------------------------------------

T["rgb percentage"] = new_set()

T["rgb percentage"]["rgb(30% 20% 50%)"] = function()
  local len, hex = parser("rgb(30% 20% 50%)", 1, rgb_opts)
  eq(true, len ~= nil)
end

T["rgb percentage"]["rgb(100%, 100%, 100%)"] = function()
  local len, hex = parser("rgb(100%, 100%, 100%)", 1, rgb_opts)
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

T["rgb percentage"]["rgb(80%, 60%, 40%)"] = function()
  local len, hex = parser("rgb(80%, 60%, 40%)", 1, rgb_opts)
  eq(true, len ~= nil)
end

-- RGB with alpha --------------------------------------------------------------

T["rgb alpha"] = new_set()

T["rgb alpha"]["rgb with slash alpha"] = function()
  local len, hex = parser("rgb(255 122 127 / .7)", 1, rgb_opts)
  eq(true, len ~= nil)
end

T["rgb alpha"]["rgb with comma alpha"] = function()
  local len, hex = parser("rgb(255, 255, 100, 0.8)", 1, rgb_opts)
  eq(true, len ~= nil)
end

-- RGB clamping ----------------------------------------------------------------

T["rgb clamping"] = new_set()

T["rgb clamping"]["values > 255 clamped"] = function()
  local len, hex = parser("rgb(255, 255, 255, 255)", 1, rgb_opts)
  eq(true, len ~= nil)
end

T["rgb clamping"]["percentages > 100 clamped"] = function()
  local len, hex = parser("rgb(100000%, 100000%, 100000%)", 1, rgb_opts)
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

-- RGBA ------------------------------------------------------------------------

T["rgba"] = new_set()

T["rgba"]["basic rgba(255, 240, 200, 0.5)"] = function()
  local len, hex = parser("rgba(255, 240, 200, 0.5)", 1, rgba_opts)
  eq(true, len ~= nil)
end

T["rgba"]["rgba full alpha"] = function()
  local len, hex = parser("rgba(255, 255, 255, 1)", 1, rgba_opts)
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

-- Hyprlang format -------------------------------------------------------------

T["hyprlang"] = new_set()

T["hyprlang"]["rgb(ff0000) is red"] = function()
  local len, hex = parser("rgb(ff0000)", 1, rgb_opts)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["hyprlang"]["rgb(ffffff) is white"] = function()
  local len, hex = parser("rgb(ffffff)", 1, rgb_opts)
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

T["hyprlang"]["rgba(ff0000ff) full alpha"] = function()
  local len, hex = parser("rgba(ff0000ff)", 1, rgba_opts)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["hyprlang"]["rgba(ff000000) zero alpha"] = function()
  local len, hex = parser("rgba(ff000000)", 1, rgba_opts)
  eq(true, len ~= nil)
  eq("000000", hex)
end

-- RGB invalid -----------------------------------------------------------------

T["rgb invalid"] = new_set()

T["rgb invalid"]["space before paren"] = function()
  local len = parser("rgb (10,255,100)", 1, rgb_opts)
  eq(nil, len)
end

T["rgb invalid"]["empty rgb()"] = function()
  local len = parser("rgb()", 1, rgb_opts)
  eq(nil, len)
end

T["rgb invalid"]["embedded space in number"] = function()
  local len = parser("rgb(10, 1 00 ,  100)", 1, rgb_opts)
  eq(nil, len)
end

T["rgb invalid"]["mixed percent and decimal"] = function()
  -- All three must be same unit (all % or all decimal)
  local len = parser("rgb(100%, 100, 100%)", 1, rgb_opts)
  eq(nil, len)
end

T["rgb invalid"]["hyprlang invalid length"] = function()
  local len = parser("rgb(12345)", 1, rgb_opts)
  eq(nil, len)
end

T["rgb invalid"]["hyprlang non-hex"] = function()
  local len = parser("rgb(gggggg)", 1, rgb_opts)
  eq(nil, len)
end

return T
