local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.ls_colors").parser
local config = require("colorizer.config")
local matcher = require("colorizer.matcher")
local xterm = require("colorizer.parser.xterm")

local T = new_set({
  hooks = {
    pre_case = function()
      matcher.reset_cache()
    end,
  },
})

-- 256-color foreground -------------------------------------------------------

T["256-color fg"] = new_set()

T["256-color fg"]["=38;5;0 is black"] = function()
  local len, hex = parser("=38;5;0", 1)
  eq(7, len)
  eq("000000", hex)
end

T["256-color fg"]["=38;5;196 is red"] = function()
  local len, hex = parser("=38;5;196", 1)
  eq(9, len)
  eq("ff0000", hex)
end

T["256-color fg"]["=38;5;255 is lightest grayscale"] = function()
  local len, hex = parser("=38;5;255", 1)
  eq(9, len)
  eq("eeeeee", hex)
end

T["256-color fg"]["leading style codes are skipped"] = function()
  local len, hex = parser("=01;38;5;33", 1)
  eq(11, len)
  eq("0087ff", hex)
end

T["256-color fg"]["trailing colon terminator"] = function()
  local len, hex = parser("=38;5;42:di", 1)
  eq(8, len)
  eq("00d787", hex)
end

T["256-color fg"]["trailing semicolon style code consumed"] = function()
  -- The parser walks the full [digit;]+ run, so `=38;5;33;1` is consumed even
  -- though the trailing `;1` is a separate SGR style code, not part of the
  -- color directive itself.
  local len, hex = parser("=38;5;33;1m", 1)
  eq(10, len)
  eq("0087ff", hex)
end

T["256-color fg"]["out-of-range index returns nil"] = function()
  local len = parser("=38;5;256", 1)
  eq(nil, len)
end

-- 256-color background -------------------------------------------------------

T["256-color bg"] = new_set()

T["256-color bg"]["=48;5;15 is white"] = function()
  local len, hex = parser("=48;5;15", 1)
  eq(8, len)
  eq("ffffff", hex)
end

T["256-color bg"]["leading style codes are skipped"] = function()
  local len, hex = parser("=01;48;5;240", 1)
  eq(12, len)
  eq("585858", hex)
end

-- Truecolor foreground -------------------------------------------------------

T["truecolor fg"] = new_set()

T["truecolor fg"]["=38;2;255;0;0 is red"] = function()
  local len, hex = parser("=38;2;255;0;0", 1)
  eq(13, len)
  eq("ff0000", hex)
end

T["truecolor fg"]["=38;2;0;255;0 is green"] = function()
  local len, hex = parser("=38;2;0;255;0", 1)
  eq(13, len)
  eq("00ff00", hex)
end

T["truecolor fg"]["leading style codes are skipped"] = function()
  local len, hex = parser("=01;38;2;10;20;30", 1)
  eq(17, len)
  eq("0a141e", hex)
end

T["truecolor fg"]["trailing colon terminator"] = function()
  local len, hex = parser("=38;2;1;2;3:next", 1)
  eq(11, len)
  eq("010203", hex)
end

T["truecolor fg"]["out-of-range channel returns nil"] = function()
  local len = parser("=38;2;256;0;0", 1)
  eq(nil, len)
end

-- Truecolor background -------------------------------------------------------

T["truecolor bg"] = new_set()

T["truecolor bg"]["=48;2;0;0;255 is blue"] = function()
  local len, hex = parser("=48;2;0;0;255", 1)
  eq(13, len)
  eq("0000ff", hex)
end

-- 8/16-color SGR -------------------------------------------------------------

T["8/16-color"] = new_set()

T["8/16-color"]["=31 is plain red (palette 1)"] = function()
  local len, hex = parser("=31", 1)
  eq(3, len)
  eq(xterm.lookup_256(1), hex)
end

T["8/16-color"]["=34 is plain blue (palette 4)"] = function()
  local len, hex = parser("=34", 1)
  eq(3, len)
  eq(xterm.lookup_256(4), hex)
end

T["8/16-color"]["=01;34 promotes bold blue to bright blue (palette 12)"] = function()
  local len, hex = parser("=01;34", 1)
  eq(6, len)
  eq(xterm.lookup_256(12), hex)
end

T["8/16-color"]["=1;31 also promotes to bright"] = function()
  local len, hex = parser("=1;31", 1)
  eq(5, len)
  eq(xterm.lookup_256(9), hex)
end

T["8/16-color"]["=90 is bright black (palette 8)"] = function()
  local len, hex = parser("=90", 1)
  eq(3, len)
  eq(xterm.lookup_256(8), hex)
end

T["8/16-color"]["=97 is bright white (palette 15)"] = function()
  local len, hex = parser("=97", 1)
  eq(3, len)
  eq(xterm.lookup_256(15), hex)
end

T["8/16-color"]["=44 is plain blue background (palette 4)"] = function()
  local len, hex = parser("=44", 1)
  eq(3, len)
  eq(xterm.lookup_256(4), hex)
end

T["8/16-color"]["=104 is bright blue background (palette 12)"] = function()
  local len, hex = parser("=104", 1)
  eq(4, len)
  eq(xterm.lookup_256(12), hex)
end

T["8/16-color"]["fg wins when both fg and bg are present"] = function()
  local len, hex = parser("=31;44", 1)
  eq(6, len)
  eq(xterm.lookup_256(1), hex)
end

T["8/16-color"]["bg is used when only bg is present"] = function()
  local len, hex = parser("=44", 1)
  eq(3, len)
  eq(xterm.lookup_256(4), hex)
end

T["8/16-color"]["bold without color returns nil"] = function()
  eq(nil, parser("=1", 1))
  eq(nil, parser("=01", 1))
end

T["8/16-color"]["reset alone returns nil"] = function()
  eq(nil, parser("=0", 1))
end

-- Edge cases -----------------------------------------------------------------

T["edge cases"] = new_set()

T["edge cases"]["no leading = returns nil"] = function()
  eq(nil, parser("38;5;196", 1))
end

T["edge cases"]["non-color SGR like =01 returns nil"] = function()
  eq(nil, parser("=01;1m", 1))
end

T["edge cases"]["empty after = returns nil"] = function()
  eq(nil, parser("=", 1))
end

T["edge cases"]["unrelated text returns nil"] = function()
  eq(nil, parser("=hello world", 1))
end

-- xterm palette helpers ------------------------------------------------------

T["xterm palette"] = new_set()

T["xterm palette"]["lookup_256 returns hex for valid index"] = function()
  eq("000000", xterm.lookup_256(0))
  eq("ff0000", xterm.lookup_256(9))
  eq("ffffff", xterm.lookup_256(15))
  eq("eeeeee", xterm.lookup_256(255))
end

T["xterm palette"]["lookup_256 returns nil for out-of-range"] = function()
  eq(nil, xterm.lookup_256(-1))
  eq(nil, xterm.lookup_256(256))
end

T["xterm palette"]["lookup_256 returns nil for non-number"] = function()
  eq(nil, xterm.lookup_256("9"))
  eq(nil, xterm.lookup_256(nil))
end

T["xterm palette"]["get_palette returns 256 entries"] = function()
  local p = xterm.get_palette()
  eq(256, #p)
  eq("000000", p[1])
  eq("ffffff", p[16])
  eq("eeeeee", p[256])
end

T["xterm palette"]["get_palette returns independent copy"] = function()
  local p1 = xterm.get_palette()
  p1[1] = "deadbe"
  local p2 = xterm.get_palette()
  eq("000000", p2[1])
end

-- Dispatch fallthrough -------------------------------------------------------

T["dispatch"] = new_set()

T["dispatch"]["custom = parser sees non-LS_COLORS = text when ls_colors enabled"] = function()
  local opts = config.resolve_options({
    parsers = {
      ls_colors = { enable = true },
      custom = {
        {
          name = "equals_hello",
          prefixes = { "=" },
          parse = function(ctx)
            if ctx.line:sub(ctx.col, ctx.col + 5) == "=hello" then
              return 6, "abcdef"
            end
          end,
        },
      },
    },
  })
  local parse_fn = matcher.make(opts)
  eq("function", type(parse_fn))
  local len, hex = parse_fn("=hello world", 1, 0, 0)
  eq(6, len)
  eq("abcdef", hex)
end

T["dispatch"]["ls_colors still matches when both enabled"] = function()
  local opts = config.resolve_options({
    parsers = {
      ls_colors = { enable = true },
      custom = {
        {
          name = "equals_hello",
          prefixes = { "=" },
          parse = function(ctx)
            if ctx.line:sub(ctx.col, ctx.col + 5) == "=hello" then
              return 6, "abcdef"
            end
          end,
        },
      },
    },
  })
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("=38;5;196 here", 1, 0, 0)
  eq(9, len)
  eq("ff0000", hex)
end

return T
