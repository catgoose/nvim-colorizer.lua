local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local matcher = require("colorizer.matcher")
local config = require("colorizer.config")
local names = require("colorizer.parser.names")
local buffer = require("colorizer.buffer")

local T = new_set({
  hooks = {
    pre_case = function()
      matcher.reset_cache()
      names.reset_cache()
      buffer.reset_cache()
      config.get_setup_options(nil)
    end,
  },
})

-- Helper: build opts via config.apply_alias_options
local function make_opts(overrides)
  overrides = overrides or { css = true, AARRGGBB = true, xterm = true }
  return config.apply_alias_options(overrides)
end

-- make() basics ---------------------------------------------------------------

T["make()"] = new_set()

T["make()"]["returns a function when parsers are enabled"] = function()
  local parse_fn = matcher.make(make_opts({ RRGGBB = true }))
  eq("function", type(parse_fn))
end

T["make()"]["returns false when nothing is enabled"] = function()
  -- Pass opts directly to bypass apply_alias_options merging with defaults
  local result = matcher.make({
    names = false,
    RGB = false,
    RGBA = false,
    RRGGBB = false,
    RRGGBBAA = false,
    AARRGGBB = false,
    rgb_fn = false,
    hsl_fn = false,
    oklch_fn = false,
    tailwind = false,
    xterm = false,
    oklch_fn = false,
  })
  eq(false, result)
end

T["make()"]["returns false for nil opts"] = function()
  local result = matcher.make(nil)
  eq(false, result)
end

-- Returned parse function finds color formats ---------------------------------

T["parse_fn"] = new_set()

T["parse_fn"]["finds #RRGGBB"] = function()
  local parse_fn = matcher.make(make_opts({ RRGGBB = true }))
  local len, hex = parse_fn("#FF0000 text", 1)
  eq(7, len)
  eq("ff0000", hex:lower())
end

T["parse_fn"]["finds #RGB"] = function()
  local parse_fn = matcher.make(make_opts({ RGB = true }))
  local len, hex = parse_fn("#F00 text", 1)
  eq(4, len)
  eq("ff0000", hex)
end

T["parse_fn"]["finds rgb() function"] = function()
  local parse_fn = matcher.make(make_opts({ rgb_fn = true }))
  local len, hex = parse_fn("rgb(255, 0, 0)", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["parse_fn"]["finds hsl() function"] = function()
  local parse_fn = matcher.make(make_opts({ hsl_fn = true }))
  local len, hex = parse_fn("hsl(0, 100%, 50%)", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["parse_fn"]["finds oklch() function"] = function()
  local parse_fn = matcher.make(make_opts({ oklch_fn = true }))
  local len, hex = parse_fn("oklch(0.6 0.2 30)", 1)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["parse_fn"]["finds named colors"] = function()
  local parse_fn = matcher.make(make_opts({ names = true }))
  local len, hex = parse_fn("red text", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["parse_fn"]["finds 0xRRGGBB"] = function()
  local parse_fn = matcher.make(make_opts({ AARRGGBB = true }))
  local len, hex = parse_fn("0xFF00FF text", 1)
  eq(true, len ~= nil)
  eq("ff00ff", hex)
end

T["parse_fn"]["returns nil for non-color text"] = function()
  local parse_fn = matcher.make(make_opts({ RRGGBB = true }))
  local len, hex = parse_fn("hello world", 1)
  eq(nil, len)
  eq(nil, hex)
end

T["parse_fn"]["finds color at offset position"] = function()
  local parse_fn = matcher.make(make_opts({ RRGGBB = true }))
  -- The # is at position 6
  local len, hex = parse_fn("text #00FF00 end", 6)
  eq(7, len)
  eq("00ff00", hex:lower())
end

-- Bitmask caching -------------------------------------------------------------

T["caching"] = new_set()

T["caching"]["same opts return same function reference"] = function()
  local opts = make_opts({ RRGGBB = true })
  local fn1 = matcher.make(opts)
  local fn2 = matcher.make(opts)
  eq(true, fn1 == fn2)
end

T["caching"]["different opts return different functions"] = function()
  local fn1 = matcher.make(make_opts({ RRGGBB = true, rgb_fn = false, hsl_fn = false, oklch_fn = false }))
  local fn2 = matcher.make(make_opts({ RRGGBB = true, rgb_fn = true }))
  eq(true, fn1 ~= fn2)
end

T["caching"]["reset_cache invalidates cached functions"] = function()
  local opts = make_opts({ RRGGBB = true })
  local fn1 = matcher.make(opts)
  matcher.reset_cache()
  names.reset_cache()
  local fn2 = matcher.make(opts)
  -- After reset, a new function is compiled
  eq(true, fn1 ~= fn2)
end

-- Trie prefix ordering --------------------------------------------------------

T["trie ordering"] = new_set()

T["trie ordering"]["rgba matched correctly (not confused with rgb)"] = function()
  local parse_fn = matcher.make(make_opts({ rgb_fn = true }))
  local len, hex = parse_fn("rgba(255, 0, 0, 1)", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["trie ordering"]["hsla matched correctly (not confused with hsl)"] = function()
  local parse_fn = matcher.make(make_opts({ hsl_fn = true }))
  local len, hex = parse_fn("hsla(0, 100%, 50%, 1)", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

-- Hooks -----------------------------------------------------------------------

T["hooks"] = new_set()

T["hooks"]["should_highlight_line returning false suppresses parsing"] = function()
  local opts = make_opts({ RRGGBB = true })
  opts.hooks = {
    should_highlight_line = function()
      return false
    end,
  }
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("#FF0000", 1, 1, 1)
  eq(nil, len)
  eq(nil, hex)
end

T["hooks"]["should_highlight_line returning true allows parsing"] = function()
  local opts = make_opts({ RRGGBB = true })
  opts.hooks = {
    should_highlight_line = function()
      return true
    end,
  }
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("#FF0000", 1, 1, 1)
  eq(7, len)
  eq("ff0000", hex:lower())
end

T["hooks"]["should_highlight_color returning false suppresses color"] = function()
  local opts = make_opts({ RRGGBB = true })
  opts.hooks = {
    should_highlight_color = function(rgb_hex)
      -- Skip white (hex is uppercase from parser)
      return rgb_hex:lower() ~= "ffffff"
    end,
  }
  local parse_fn = matcher.make(opts)
  -- White should be suppressed
  local len, hex = parse_fn("#FFFFFF", 1, 1, 1)
  eq(nil, len)
  eq(nil, hex)
  -- Red should still work
  len, hex = parse_fn("#FF0000", 1, 1, 1)
  eq(7, len)
  eq("ff0000", hex:lower())
end

T["hooks"]["should_highlight_color receives parser_name and context"] = function()
  local captured_name, captured_ctx
  local opts = make_opts({ RRGGBB = true })
  opts.hooks = {
    should_highlight_color = function(rgb_hex, parser_name, ctx)
      captured_name = parser_name
      captured_ctx = ctx
      return true
    end,
  }
  local parse_fn = matcher.make(opts)
  parse_fn("#FF0000 text", 1, 42, 10)
  eq("rgba_hex", captured_name)
  eq(42, captured_ctx.bufnr)
  eq(10, captured_ctx.line_nr)
  eq(1, captured_ctx.col)
  eq("#FF0000 text", captured_ctx.line)
end

T["hooks"]["transform_color remaps rgb_hex"] = function()
  local opts = make_opts({ RRGGBB = true })
  opts.hooks = {
    transform_color = function()
      -- Force everything to green
      return "00ff00"
    end,
  }
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("#FF0000", 1, 1, 1)
  eq(7, len)
  eq("00ff00", hex)
end

T["hooks"]["transform_color receives rgb_hex and context"] = function()
  local captured_hex, captured_ctx
  local opts = make_opts({ RRGGBB = true })
  opts.hooks = {
    transform_color = function(rgb_hex, ctx)
      captured_hex = rgb_hex
      captured_ctx = ctx
      return rgb_hex
    end,
  }
  local parse_fn = matcher.make(opts)
  parse_fn("#FF0000 text", 1, 42, 10)
  eq("ff0000", captured_hex:lower())
  eq(42, captured_ctx.bufnr)
  eq(10, captured_ctx.line_nr)
end

T["hooks"]["transform_color nil return keeps original hex"] = function()
  local opts = make_opts({ RRGGBB = true })
  opts.hooks = {
    transform_color = function()
      return nil
    end,
  }
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("#FF0000", 1, 1, 1)
  eq(7, len)
  eq("ff0000", hex:lower())
end

T["hooks"]["should_highlight_color runs before transform_color"] = function()
  local transform_called = false
  local opts = make_opts({ RRGGBB = true })
  opts.hooks = {
    should_highlight_color = function()
      return false
    end,
    transform_color = function(rgb_hex)
      transform_called = true
      return rgb_hex
    end,
  }
  local parse_fn = matcher.make(opts)
  parse_fn("#FF0000", 1, 1, 1)
  eq(false, transform_called)
end

T["hooks"]["combined: filter + transform"] = function()
  local opts = make_opts({ RRGGBB = true })
  opts.hooks = {
    should_highlight_color = function(rgb_hex)
      return rgb_hex:lower() ~= "ffffff"
    end,
    transform_color = function()
      return "00ff00"
    end,
  }
  local parse_fn = matcher.make(opts)
  -- White is filtered out
  local len, hex = parse_fn("#FFFFFF", 1, 1, 1)
  eq(nil, len)
  -- Red passes filter, then gets transformed to green
  len, hex = parse_fn("#FF0000", 1, 1, 1)
  eq(7, len)
  eq("00ff00", hex)
end

return T
