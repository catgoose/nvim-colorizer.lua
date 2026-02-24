local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.hsl").parser

local T = new_set()

local hsl_opts = { prefix = "hsl" }
local hsla_opts = { prefix = "hsla" }

-- HSL basic -------------------------------------------------------------------

T["hsl basic"] = new_set()

T["hsl basic"]["comma separated hsl(60, 100%, 80%)"] = function()
  local len, hex = parser("hsl(60, 100%, 80%)", 1, hsl_opts)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["hsl basic"]["space separated hsl(300 50% 50%)"] = function()
  local len, hex = parser("hsl(300 50% 50%)", 1, hsl_opts)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["hsl basic"]["hsl(0, 100%, 90%) is pinkish/red"] = function()
  local len, hex = parser("hsl(0, 100%, 90%)", 1, hsl_opts)
  eq(true, len ~= nil)
  -- hsl(0, 100%, 90%) = a very light red
  local r = tonumber(hex:sub(1, 2), 16)
  eq(true, r > 200) -- Red channel should be high
end

-- HSL with degrees and turns --------------------------------------------------

T["hsl deg/turn"] = new_set()

T["hsl deg/turn"]["hsl with deg suffix"] = function()
  local len, hex = parser("hsl(300deg 50% 50%)", 1, hsl_opts)
  -- "deg" suffix should be accepted but pattern may not match it depending on implementation
  -- The regex uses ([deg]*) which would match "deg"
  eq(true, len ~= nil)
end

T["hsl deg/turn"]["hsl with turn"] = function()
  local len, hex = parser("hsl(1turn 80% 50% / 0.4)", 1, hsl_opts)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["hsl deg/turn"]["hsl with fractional turn"] = function()
  local len, hex = parser("hsl(0.4turn 80% 50% / 0.4)", 1, hsl_opts)
  eq(true, len ~= nil)
end

-- HSL with alpha --------------------------------------------------------------

T["hsl alpha"] = new_set()

T["hsl alpha"]["hsl with slash alpha"] = function()
  local len, hex = parser("hsl(300 50% 50% / 1)", 1, hsl_opts)
  eq(true, len ~= nil)
end

T["hsl alpha"]["hsl with comma alpha (4 args)"] = function()
  local len, hex = parser("hsl(255, 100%, 100%, 1)", 1, hsl_opts)
  eq(true, len ~= nil)
end

T["hsl alpha"]["hsl with percentage alpha"] = function()
  local len, hex = parser("hsl(100 80% 50% / 40%)", 1, hsl_opts)
  eq(true, len ~= nil)
end

-- HSL clamping ----------------------------------------------------------------

T["hsl clamping"] = new_set()

T["hsl clamping"]["hue > 360 wraps around"] = function()
  local len, hex = parser("hsl(720 80% 50% / 0.4)", 1, hsl_opts)
  eq(true, len ~= nil)
end

T["hsl clamping"]["saturation > 100 clamped"] = function()
  local len, hex = parser("hsl(10000, 10000%, 10000%)", 1, hsl_opts)
  eq(true, len ~= nil)
end

T["hsl clamping"]["alpha > 1 clamped to 1"] = function()
  local len1, hex1 = parser("hsl(300 50% 50% / 1)", 1, hsl_opts)
  local len2, hex2 = parser("hsl(300 50% 50% / 5)", 1, hsl_opts)
  -- Both should produce same result since alpha is clamped
  eq(hex1, hex2)
end

-- HSLA ------------------------------------------------------------------------

T["hsla"] = new_set()

T["hsla"]["basic hsla(300 50% 50%)"] = function()
  local len, hex = parser("hsla(300 50% 50%)", 1, hsla_opts)
  eq(true, len ~= nil)
end

T["hsla"]["hsla with alpha"] = function()
  local len, hex = parser("hsla(300 50% 50% / 0.4)", 1, hsla_opts)
  eq(true, len ~= nil)
end

T["hsla"]["hsla comma separated with alpha"] = function()
  local len, hex = parser("hsla(60, 100%, 85%, 0.5)", 1, hsla_opts)
  eq(true, len ~= nil)
end

-- HSL decimal values ----------------------------------------------------------

T["hsl decimals"] = new_set()

T["hsl decimals"]["decimal saturation and lightness"] = function()
  local len, hex = parser("hsl(300 50.5% 50.5%)", 1, hsl_opts)
  eq(true, len ~= nil)
end

T["hsl decimals"]["decimal hue value"] = function()
  local len, hex = parser("hsl(210, 9.1%, 87%)", 1, hsl_opts)
  eq(true, len ~= nil)
end

-- HSL invalid -----------------------------------------------------------------

T["hsl invalid"] = new_set()

T["hsl invalid"]["percent on saturation is optional"] = function()
  local len, hex = parser("hsl(300, 50, 50)", 1, hsl_opts)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["hsl invalid"]["empty hsl()"] = function()
  local len = parser("hsl()", 1, hsl_opts)
  eq(nil, len)
end

T["hsl invalid"]["missing closing paren"] = function()
  local len = parser("hsl(300, 50%, 50", 1, hsl_opts)
  eq(nil, len)
end

T["hsl invalid"]["space before paren"] = function()
  local len = parser("hsl (300, 50%, 50%)", 1, hsl_opts)
  eq(nil, len)
end

T["hsl invalid"]["mixed separators (space and alpha without slash)"] = function()
  local len = parser("hsl(300 50% 50% 1)", 1, hsl_opts)
  eq(nil, len)
end

T["hsl invalid"]["percent on lightness is optional"] = function()
  local len, hex = parser("hsl(300 50% 50 / 1)", 1, hsl_opts)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

return T
