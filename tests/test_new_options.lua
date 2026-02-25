local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local config = require("colorizer.config")
local matcher = require("colorizer.matcher")
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

-- is_legacy_options -----------------------------------------------------------

T["is_legacy_options"] = new_set()

T["is_legacy_options"]["detects flat keys as legacy"] = function()
  eq(true, config.is_legacy_options({ RGB = true }))
  eq(true, config.is_legacy_options({ names = true }))
  eq(true, config.is_legacy_options({ rgb_fn = true }))
  eq(true, config.is_legacy_options({ mode = "background" }))
  eq(true, config.is_legacy_options({ tailwind = "normal" }))
end

T["is_legacy_options"]["returns false for new format"] = function()
  eq(false, config.is_legacy_options({ parsers = { css = true } }))
  eq(false, config.is_legacy_options({}))
  eq(false, config.is_legacy_options(nil))
end

-- translate_options -----------------------------------------------------------

T["translate_options"] = new_set()

T["translate_options"]["translates names"] = function()
  local new = config.translate_options({ names = true })
  eq(true, new.parsers.names.enable)
end

T["translate_options"]["translates hex keys"] = function()
  local new = config.translate_options({ RGB = true, RRGGBB = true, RRGGBBAA = false })
  eq(true, new.parsers.hex.enable)
  eq(true, new.parsers.hex.rgb)
  eq(true, new.parsers.hex.rrggbb)
  eq(false, new.parsers.hex.rrggbbaa)
end

T["translate_options"]["translates css functions"] = function()
  local new = config.translate_options({ rgb_fn = true, hsl_fn = true, oklch_fn = false })
  eq(true, new.parsers.rgb.enable)
  eq(true, new.parsers.hsl.enable)
  eq(false, new.parsers.oklch.enable)
end

T["translate_options"]["translates tailwind boolean"] = function()
  local new = config.translate_options({ tailwind = true })
  eq(true, new.parsers.tailwind.enable)
  eq("normal", new.parsers.tailwind.mode)
end

T["translate_options"]["translates tailwind string"] = function()
  local new = config.translate_options({ tailwind = "lsp" })
  eq(true, new.parsers.tailwind.enable)
  eq("lsp", new.parsers.tailwind.mode)
end

T["translate_options"]["translates tailwind false"] = function()
  local new = config.translate_options({ tailwind = false })
  eq(false, new.parsers.tailwind.enable)
end

T["translate_options"]["translates display options"] = function()
  local new = config.translate_options({
    mode = "foreground",
    virtualtext = "X",
    virtualtext_inline = true,
    virtualtext_mode = "background",
  })
  eq("foreground", new.display.mode)
  eq("X", new.display.virtualtext.char)
  eq("after", new.display.virtualtext.position)
  eq("background", new.display.virtualtext.hl_mode)
end

T["translate_options"]["translates virtualtext_inline before"] = function()
  local new = config.translate_options({ virtualtext_inline = "before" })
  eq("before", new.display.virtualtext.position)
end

T["translate_options"]["translates sass"] = function()
  local new = config.translate_options({ sass = { enable = true, parsers = { css = true } } })
  eq(true, new.parsers.sass.enable)
  eq(true, new.parsers.sass.parsers.css)
end

T["translate_options"]["translates xterm"] = function()
  local new = config.translate_options({ xterm = true })
  eq(true, new.parsers.xterm.enable)
end

-- translate_filetypes ---------------------------------------------------------

T["translate_filetypes"] = new_set()

T["translate_filetypes"]["handles plain list"] = function()
  local new = config.translate_filetypes({ "*" })
  eq("*", new.enable[1])
  eq(0, #new.exclude)
end

T["translate_filetypes"]["handles exclusions"] = function()
  local new = config.translate_filetypes({ "*", "!markdown" })
  eq("*", new.enable[1])
  eq("markdown", new.exclude[1])
end

T["translate_filetypes"]["handles overrides"] = function()
  local new = config.translate_filetypes({ "*", html = { mode = "foreground" } })
  eq("*", new.enable[1])
  eq("foreground", new.overrides.html.display.mode)
end

T["translate_filetypes"]["passes through new format"] = function()
  local input = { enable = { "*" }, exclude = { "md" }, overrides = {} }
  local new = config.translate_filetypes(input)
  eq("*", new.enable[1])
  eq("md", new.exclude[1])
end

-- apply_presets ---------------------------------------------------------------

T["apply_presets"] = new_set()

T["apply_presets"]["css enables names, hex, rgb, hsl, oklch"] = function()
  local p = { css = true }
  config.apply_presets(p)
  eq(true, p.names.enable)
  eq(true, p.hex.enable)
  eq(true, p.rgb.enable)
  eq(true, p.hsl.enable)
  eq(true, p.oklch.enable)
  eq(nil, p.css)
end

T["apply_presets"]["css_fn enables rgb, hsl, oklch"] = function()
  local p = { css_fn = true }
  config.apply_presets(p)
  eq(true, p.rgb.enable)
  eq(true, p.hsl.enable)
  eq(true, p.oklch.enable)
  eq(nil, p.names)
  eq(nil, p.css_fn)
end

T["apply_presets"]["individual settings override presets"] = function()
  local p = { css = true, rgb = { enable = false } }
  config.apply_presets(p)
  eq(false, p.rgb.enable)
  eq(true, p.hsl.enable)
  eq(true, p.names.enable)
end

T["apply_presets"]["does nothing for nil"] = function()
  config.apply_presets(nil)
end

-- validate_new_options --------------------------------------------------------

T["validate_new_options"] = new_set()

T["validate_new_options"]["resets invalid display.mode"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.display.mode = "invalid"
  config.validate_new_options(opts)
  eq("background", opts.display.mode)
end

T["validate_new_options"]["resets invalid tailwind.mode"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.tailwind.enable = true
  opts.parsers.tailwind.mode = "invalid"
  config.validate_new_options(opts)
  eq("normal", opts.parsers.tailwind.mode)
end

T["validate_new_options"]["resets invalid virtualtext.position"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.display.virtualtext.position = "center"
  config.validate_new_options(opts)
  eq(false, opts.display.virtualtext.position)
end

T["validate_new_options"]["processes names.custom table"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.names.custom = { myred = "#ff0000" }
  config.validate_new_options(opts)
  eq(false, opts.parsers.names.custom)
  eq(true, opts.parsers.names.custom_hashed ~= nil)
  eq("table", type(opts.parsers.names.custom_hashed))
  eq("#ff0000", opts.parsers.names.custom_hashed.names.myred)
end

T["validate_new_options"]["processes names.custom function"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.names.custom = function()
    return { myblue = "#0000ff" }
  end
  config.validate_new_options(opts)
  eq(false, opts.parsers.names.custom)
  eq("#0000ff", opts.parsers.names.custom_hashed.names.myblue)
end

T["validate_new_options"]["empty names.custom becomes false"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.names.custom = {}
  config.validate_new_options(opts)
  eq(false, opts.parsers.names.custom)
end

T["validate_new_options"]["non-function hook becomes false"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.hooks.disable_line_highlight = "not a function"
  config.validate_new_options(opts)
  eq(false, opts.hooks.disable_line_highlight)
end

-- as_flat ---------------------------------------------------------------------

T["as_flat"] = new_set()

T["as_flat"]["converts new format to flat format"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.names.enable = true
  opts.parsers.hex.enable = true
  opts.parsers.hex.rgb = true
  opts.parsers.hex.rrggbb = true
  opts.parsers.rgb.enable = true
  opts.display.mode = "foreground"
  local flat = config.as_flat(opts)
  eq(true, flat.names)
  eq(true, flat.RGB)
  eq(true, flat.RRGGBB)
  eq(true, flat.rgb_fn)
  eq("foreground", flat.mode)
end

T["as_flat"]["hex master switch disables individual flags"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = false
  opts.parsers.hex.rgb = true
  opts.parsers.hex.rrggbb = true
  local flat = config.as_flat(opts)
  eq(false, flat.RGB)
  eq(false, flat.RRGGBB)
end

T["as_flat"]["tailwind enabled becomes mode string"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.tailwind.enable = true
  opts.parsers.tailwind.mode = "both"
  local flat = config.as_flat(opts)
  eq("both", flat.tailwind)
end

T["as_flat"]["tailwind disabled becomes false"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.tailwind.enable = false
  local flat = config.as_flat(opts)
  eq(false, flat.tailwind)
end

T["as_flat"]["virtualtext position converts correctly"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.display.virtualtext.position = "before"
  local flat = config.as_flat(opts)
  eq("before", flat.virtualtext_inline)
end

T["as_flat"]["virtualtext position false converts correctly"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.display.virtualtext.position = false
  local flat = config.as_flat(opts)
  eq(false, flat.virtualtext_inline)
end

-- resolve_options -------------------------------------------------------------

T["resolve_options"] = new_set()

T["resolve_options"]["handles nil"] = function()
  local result = config.resolve_options(nil)
  eq("table", type(result))
  eq("table", type(result.parsers))
  eq("table", type(result.display))
end

T["resolve_options"]["handles new format"] = function()
  local result = config.resolve_options({ parsers = { css = true } })
  eq(true, result.parsers.names.enable)
  eq(true, result.parsers.hex.enable)
  eq(true, result.parsers.rgb.enable)
end

T["resolve_options"]["handles legacy format"] = function()
  local result = config.resolve_options({ RGB = true, RRGGBB = true, names = true })
  eq(true, result.parsers.names.enable)
  eq(true, result.parsers.hex.enable)
  eq(true, result.parsers.hex.rgb)
  eq(true, result.parsers.hex.rrggbb)
end

-- get_setup_options with new format -------------------------------------------

T["get_setup_options new format"] = new_set()

T["get_setup_options new format"]["accepts options key"] = function()
  local s = config.get_setup_options({
    options = { parsers = { css = true } },
  })
  eq(true, s.options.parsers.names.enable)
  eq(true, s.options.parsers.hex.enable)
  eq(true, s.options.parsers.rgb.enable)
  eq(true, s.options.parsers.hsl.enable)
  eq(true, s.options.parsers.oklch.enable)
  -- Legacy view should also be populated
  eq(true, s.user_default_options.names)
  eq(true, s.user_default_options.RGB)
end

T["get_setup_options new format"]["preserves individual overrides in presets"] = function()
  local s = config.get_setup_options({
    options = { parsers = { css = true, rgb = { enable = false } } },
  })
  eq(false, s.options.parsers.rgb.enable)
  eq(true, s.options.parsers.hsl.enable)
end

-- matcher.make with new format ------------------------------------------------

T["matcher new format"] = new_set()

T["matcher new format"]["make() works with new format options"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.parsers.hex.rrggbb = true
  local parse_fn = matcher.make(opts)
  eq("function", type(parse_fn))
end

T["matcher new format"]["finds #RRGGBB"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.parsers.hex.rrggbb = true
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("#FF0000 text", 1)
  eq(7, len)
  eq("ff0000", hex:lower())
end

T["matcher new format"]["finds rgb() function"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.rgb.enable = true
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("rgb(255, 0, 0)", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["matcher new format"]["finds hsl() function"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hsl.enable = true
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("hsl(0, 100%, 50%)", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["matcher new format"]["finds oklch() function"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.oklch.enable = true
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("oklch(0.6 0.2 30)", 1)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["matcher new format"]["finds named colors"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.names.enable = true
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("red text", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["matcher new format"]["returns false when nothing enabled"] = function()
  local opts = vim.deepcopy(config.default_options)
  local result = matcher.make(opts)
  eq(false, result)
end

T["matcher new format"]["css preset enables all via resolve_options"] = function()
  local opts = config.resolve_options({ parsers = { css = true } })
  local parse_fn = matcher.make(opts)
  eq("function", type(parse_fn))
  -- Should find named colors
  local len, hex = parse_fn("red text", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
  -- Should find #RRGGBB
  local len2, hex2 = parse_fn("#00FF00 text", 1)
  eq(7, len2)
  eq("00ff00", hex2:lower())
end

-- Custom parser ---------------------------------------------------------------

T["custom parser"] = new_set()

T["custom parser"]["basic custom parser works"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.custom = {
    {
      name = "test_color",
      prefixes = { "Color." },
      parse = function(ctx)
        local m = ctx.line:match("^Color%.RED", ctx.col)
        if m then
          return #"Color.RED", "ff0000"
        end
      end,
    },
  }
  local parse_fn = matcher.make(opts)
  eq("function", type(parse_fn))
  local len, hex = parse_fn("Color.RED here", 1)
  eq(#"Color.RED", len)
  eq("ff0000", hex)
end

T["custom parser"]["byte-triggered custom parser works"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.custom = {
    {
      name = "exclaim_color",
      prefix_bytes = { string.byte("!") },
      parse = function(ctx)
        local m = ctx.line:match("^!red", ctx.col)
        if m then
          return 4, "ff0000"
        end
      end,
    },
  }
  local parse_fn = matcher.make(opts)
  eq("function", type(parse_fn))
  local len, hex = parse_fn("!red here", 1)
  eq(4, len)
  eq("ff0000", hex)
end

T["custom parser"]["custom parser without triggers is last resort"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.custom = {
    {
      name = "fallback_parser",
      parse = function(ctx)
        local m = ctx.line:match("^MYCOLOR", ctx.col)
        if m then
          return #"MYCOLOR", "00ff00"
        end
      end,
    },
  }
  local parse_fn = matcher.make(opts)
  eq("function", type(parse_fn))
  local len, hex = parse_fn("MYCOLOR here", 1)
  eq(#"MYCOLOR", len)
  eq("00ff00", hex)
end

T["custom parser"]["custom parser does not match wrong input"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.custom = {
    {
      name = "test_only_red",
      prefixes = { "Color." },
      parse = function(ctx)
        local m = ctx.line:match("^Color%.RED", ctx.col)
        if m then
          return #"Color.RED", "ff0000"
        end
      end,
    },
  }
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("Color.BLUE here", 1)
  eq(nil, len)
  eq(nil, hex)
end

T["custom parser"]["multiple custom parsers"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.custom = {
    {
      name = "parser_a",
      prefixes = { "A:" },
      parse = function(ctx)
        if ctx.line:match("^A:red", ctx.col) then
          return 5, "ff0000"
        end
      end,
    },
    {
      name = "parser_b",
      prefixes = { "B:" },
      parse = function(ctx)
        if ctx.line:match("^B:green", ctx.col) then
          return 7, "00ff00"
        end
      end,
    },
  }
  local parse_fn = matcher.make(opts)
  local len1, hex1 = parse_fn("A:red here", 1)
  eq(5, len1)
  eq("ff0000", hex1)
  local len2, hex2 = parse_fn("B:green here", 1)
  eq(7, len2)
  eq("00ff00", hex2)
end

T["custom parser"]["custom parser with both prefixes and prefix_bytes"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.custom = {
    {
      name = "dual_trigger",
      prefixes = { "CLR(" },
      prefix_bytes = { string.byte("@") },
      parse = function(ctx)
        if ctx.line:match("^CLR%(red%)", ctx.col) then
          return #"CLR(red)", "ff0000"
        end
        if ctx.line:match("^@blue", ctx.col) then
          return 5, "0000ff"
        end
      end,
    },
  }
  local parse_fn = matcher.make(opts)
  local len1, hex1 = parse_fn("CLR(red) text", 1)
  eq(#"CLR(red)", len1)
  eq("ff0000", hex1)
  local len2, hex2 = parse_fn("@blue text", 1)
  eq(5, len2)
  eq("0000ff", hex2)
end

T["custom parser"]["custom parser alongside standard parsers"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.parsers.hex.rrggbb = true
  opts.parsers.custom = {
    {
      name = "my_parser",
      prefixes = { "Color." },
      parse = function(ctx)
        if ctx.line:match("^Color%.RED", ctx.col) then
          return #"Color.RED", "ff0000"
        end
      end,
    },
  }
  local parse_fn = matcher.make(opts)
  -- Standard hex should work
  local len1, hex1 = parse_fn("#00FF00 text", 1)
  eq(7, len1)
  eq("00ff00", hex1:lower())
  -- Custom parser should work too
  local len2, hex2 = parse_fn("Color.RED text", 1)
  eq(#"Color.RED", len2)
  eq("ff0000", hex2)
end

T["custom parser"]["context fields are correct"] = function()
  local captured_ctx
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.custom = {
    {
      name = "ctx_test",
      prefixes = { "TEST(" },
      parse = function(ctx)
        captured_ctx = ctx
        if ctx.line:match("^TEST%(ok%)", ctx.col) then
          return 7, "abcdef"
        end
      end,
    },
  }
  local parse_fn = matcher.make(opts)
  parse_fn("TEST(ok) end", 1, 42, 5)
  eq("TEST(ok) end", captured_ctx.line)
  eq(1, captured_ctx.col)
  eq(42, captured_ctx.bufnr)
  eq(5, captured_ctx.line_nr)
  eq("table", type(captured_ctx.state))
end

-- Custom parser state management -------------------------------------------

T["custom parser state"] = new_set()

T["custom parser state"]["init_buffer_parser_state creates state"] = function()
  local factory_called = 0
  local custom = {
    {
      name = "stateful",
      state_factory = function()
        factory_called = factory_called + 1
        return { count = 0 }
      end,
      parse = function() end,
    },
  }
  matcher.init_buffer_parser_state(1, custom)
  eq(1, factory_called)
  local state = matcher.get_buffer_parser_state(1, "stateful")
  eq(0, state.count)
end

T["custom parser state"]["init_buffer_parser_state is idempotent"] = function()
  local factory_called = 0
  local custom = {
    {
      name = "stateful2",
      state_factory = function()
        factory_called = factory_called + 1
        return { count = 0 }
      end,
      parse = function() end,
    },
  }
  matcher.init_buffer_parser_state(2, custom)
  eq(1, factory_called)
  -- Call again: should not re-create state
  matcher.init_buffer_parser_state(2, custom)
  eq(1, factory_called)
end

T["custom parser state"]["state persists across parse calls"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.custom = {
    {
      name = "counter",
      state_factory = function()
        return { count = 0 }
      end,
      prefixes = { "CNT" },
      parse = function(ctx)
        ctx.state.count = ctx.state.count + 1
        if ctx.line:match("^CNT", ctx.col) then
          return 3, "ff0000"
        end
      end,
    },
  }
  matcher.init_buffer_parser_state(10, opts.parsers.custom)
  local parse_fn = matcher.make(opts)
  parse_fn("CNT here", 1, 10, 0)
  parse_fn("CNT again", 1, 10, 1)
  local state = matcher.get_buffer_parser_state(10, "counter")
  eq(2, state.count)
end

T["custom parser state"]["cleanup removes all buffer state"] = function()
  local custom = {
    {
      name = "tmp",
      state_factory = function()
        return { data = true }
      end,
      parse = function() end,
    },
  }
  matcher.init_buffer_parser_state(20, custom)
  eq(true, matcher.get_buffer_parser_state(20, "tmp").data)
  matcher.cleanup_buffer_parser_state(20)
  eq(nil, matcher.get_buffer_parser_state(20, "tmp"))
end

T["custom parser state"]["get_buffer_parser_state returns nil for unknown"] = function()
  eq(nil, matcher.get_buffer_parser_state(999, "nonexistent"))
end

T["custom parser state"]["init with nil custom_parsers is safe"] = function()
  matcher.init_buffer_parser_state(30, nil)
  matcher.init_buffer_parser_state(31, {})
end

T["custom parser state"]["cleanup with no state is safe"] = function()
  matcher.cleanup_buffer_parser_state(999)
end

T["custom parser state"]["multiple parsers with separate state"] = function()
  local custom = {
    {
      name = "parser_x",
      state_factory = function()
        return { id = "x" }
      end,
      parse = function() end,
    },
    {
      name = "parser_y",
      state_factory = function()
        return { id = "y" }
      end,
      parse = function() end,
    },
  }
  matcher.init_buffer_parser_state(40, custom)
  eq("x", matcher.get_buffer_parser_state(40, "parser_x").id)
  eq("y", matcher.get_buffer_parser_state(40, "parser_y").id)
end

T["custom parser state"]["different buffers have isolated state"] = function()
  local custom = {
    {
      name = "iso",
      state_factory = function()
        return { val = 0 }
      end,
      parse = function() end,
    },
  }
  matcher.init_buffer_parser_state(50, custom)
  matcher.init_buffer_parser_state(51, custom)
  matcher.get_buffer_parser_state(50, "iso").val = 100
  matcher.get_buffer_parser_state(51, "iso").val = 200
  eq(100, matcher.get_buffer_parser_state(50, "iso").val)
  eq(200, matcher.get_buffer_parser_state(51, "iso").val)
end

-- is_legacy_options additional tests ----------------------------------------

T["is_legacy_options"]["detects all legacy keys"] = function()
  eq(true, config.is_legacy_options({ RGBA = true }))
  eq(true, config.is_legacy_options({ RRGGBB = true }))
  eq(true, config.is_legacy_options({ RRGGBBAA = true }))
  eq(true, config.is_legacy_options({ AARRGGBB = true }))
  eq(true, config.is_legacy_options({ hsl_fn = true }))
  eq(true, config.is_legacy_options({ oklch_fn = true }))
  eq(true, config.is_legacy_options({ virtualtext = "X" }))
  eq(true, config.is_legacy_options({ virtualtext_inline = true }))
  eq(true, config.is_legacy_options({ virtualtext_mode = "foreground" }))
  eq(true, config.is_legacy_options({ always_update = true }))
  eq(true, config.is_legacy_options({ xterm = true }))
end

T["is_legacy_options"]["false with explicit false legacy values"] = function()
  -- Even false values should detect as legacy (they're explicitly set)
  eq(true, config.is_legacy_options({ RGB = false }))
  eq(true, config.is_legacy_options({ names = false }))
end

-- translate_options additional tests ----------------------------------------

T["translate_options"]["translates names_opts"] = function()
  local new = config.translate_options({
    names = true,
    names_opts = { lowercase = false, uppercase = true, strip_digits = true },
  })
  eq(true, new.parsers.names.enable)
  eq(false, new.parsers.names.lowercase)
  eq(true, new.parsers.names.uppercase)
  eq(true, new.parsers.names.strip_digits)
end

T["translate_options"]["translates names_custom"] = function()
  local new = config.translate_options({ names_custom = { myred = "#ff0000" } })
  eq("#ff0000", new.parsers.names.custom.myred)
end

T["translate_options"]["translates tailwind both"] = function()
  local new = config.translate_options({ tailwind = "both" })
  eq(true, new.parsers.tailwind.enable)
  eq("both", new.parsers.tailwind.mode)
end

T["translate_options"]["translates tailwind_opts.update_names"] = function()
  local new = config.translate_options({
    tailwind = "both",
    tailwind_opts = { update_names = true },
  })
  eq(true, new.parsers.tailwind.update_names)
end

T["translate_options"]["translates all hex keys to false"] = function()
  local new = config.translate_options({
    RGB = false, RGBA = false, RRGGBB = false, RRGGBBAA = false, AARRGGBB = false,
  })
  -- hex.enable should not be set since no hex key is true
  eq(nil, new.parsers.hex.enable)
  eq(false, new.parsers.hex.rgb)
  eq(false, new.parsers.hex.rrggbb)
end

T["translate_options"]["translates virtualtext_inline after string"] = function()
  local new = config.translate_options({ virtualtext_inline = "after" })
  eq("after", new.display.virtualtext.position)
end

T["translate_options"]["translates virtualtext_inline false"] = function()
  local new = config.translate_options({ virtualtext_inline = false })
  eq(false, new.display.virtualtext.position)
end

T["translate_options"]["translates hooks"] = function()
  local fn = function() return true end
  local new = config.translate_options({ hooks = { disable_line_highlight = fn } })
  eq(fn, new.hooks.disable_line_highlight)
end

T["translate_options"]["translates always_update"] = function()
  local new = config.translate_options({ always_update = true })
  eq(true, new.always_update)
end

T["translate_options"]["translates css preset"] = function()
  local new = config.translate_options({ css = true })
  eq(true, new.parsers.css)
end

T["translate_options"]["translates css_fn preset"] = function()
  local new = config.translate_options({ css_fn = true })
  eq(true, new.parsers.css_fn)
end

-- translate_filetypes additional tests --------------------------------------

T["translate_filetypes"]["handles nil"] = function()
  local new = config.translate_filetypes(nil)
  eq(0, #new.enable)
  eq(0, #new.exclude)
  eq("table", type(new.overrides))
end

T["translate_filetypes"]["handles multiple exclusions"] = function()
  local new = config.translate_filetypes({ "*", "!markdown", "!json", "!yaml" })
  eq("*", new.enable[1])
  eq(3, #new.exclude)
end

T["translate_filetypes"]["handles multiple overrides"] = function()
  local new = config.translate_filetypes({
    "*",
    html = { mode = "foreground" },
    css = { RGB = true },
  })
  eq("*", new.enable[1])
  eq("foreground", new.overrides.html.display.mode)
  eq(true, new.overrides.css.parsers.hex.rgb)
end

T["translate_filetypes"]["override translates legacy options"] = function()
  local new = config.translate_filetypes({
    html = { rgb_fn = true, hsl_fn = true },
  })
  eq(true, new.overrides.html.parsers.rgb.enable)
  eq(true, new.overrides.html.parsers.hsl.enable)
end

T["translate_filetypes"]["new format fills missing keys"] = function()
  local new = config.translate_filetypes({ enable = { "*" } })
  eq("*", new.enable[1])
  eq(0, #new.exclude)
  eq("table", type(new.overrides))
end

-- apply_presets additional tests --------------------------------------------

T["apply_presets"]["both css and css_fn together"] = function()
  local p = { css = true, css_fn = true }
  config.apply_presets(p)
  eq(true, p.names.enable)
  eq(true, p.hex.enable)
  eq(true, p.rgb.enable)
  eq(true, p.hsl.enable)
  eq(true, p.oklch.enable)
  eq(nil, p.css)
  eq(nil, p.css_fn)
end

T["apply_presets"]["is idempotent"] = function()
  local p = { css = true }
  config.apply_presets(p)
  -- Preset keys removed, calling again should be safe
  config.apply_presets(p)
  eq(true, p.names.enable)
  eq(true, p.hex.enable)
end

T["apply_presets"]["css_fn does not enable names or hex"] = function()
  local p = { css_fn = true }
  config.apply_presets(p)
  eq(nil, p.names)
  eq(nil, p.hex)
  eq(true, p.rgb.enable)
  eq(true, p.hsl.enable)
  eq(true, p.oklch.enable)
end

T["apply_presets"]["does not affect custom parsers"] = function()
  local custom = { { name = "test", parse = function() end } }
  local p = { css = true, custom = custom }
  config.apply_presets(p)
  eq(custom, p.custom)
end

T["apply_presets"]["does not overwrite existing enable value"] = function()
  -- User explicitly set names.enable = false, css preset should not override
  local p = { css = true, names = { enable = false } }
  config.apply_presets(p)
  eq(false, p.names.enable)
end

T["apply_presets"]["sets enable when table exists without enable key"] = function()
  -- User set hex = { rrggbbaa = true } without enable key
  local p = { css = true, hex = { rrggbbaa = true } }
  config.apply_presets(p)
  eq(true, p.hex.enable)
  eq(true, p.hex.rrggbbaa)
end

-- validate_new_options additional tests -------------------------------------

T["validate_new_options"]["resets invalid virtualtext.hl_mode"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.display.virtualtext.hl_mode = "invalid"
  config.validate_new_options(opts)
  eq("foreground", opts.display.virtualtext.hl_mode)
end

T["validate_new_options"]["valid display.mode is preserved"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.display.mode = "virtualtext"
  config.validate_new_options(opts)
  eq("virtualtext", opts.display.mode)
end

T["validate_new_options"]["valid tailwind.mode lsp is preserved"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.tailwind.enable = true
  opts.parsers.tailwind.mode = "lsp"
  config.validate_new_options(opts)
  eq("lsp", opts.parsers.tailwind.mode)
end

T["validate_new_options"]["valid tailwind.mode both is preserved"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.tailwind.enable = true
  opts.parsers.tailwind.mode = "both"
  config.validate_new_options(opts)
  eq("both", opts.parsers.tailwind.mode)
end

T["validate_new_options"]["skips tailwind.mode validation when disabled"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.tailwind.enable = false
  opts.parsers.tailwind.mode = "whatever"
  config.validate_new_options(opts)
  -- Should not reset since tailwind is disabled
  eq("whatever", opts.parsers.tailwind.mode)
end

T["validate_new_options"]["valid virtualtext.position values preserved"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.display.virtualtext.position = "before"
  config.validate_new_options(opts)
  eq("before", opts.display.virtualtext.position)

  opts.display.virtualtext.position = "after"
  config.validate_new_options(opts)
  eq("after", opts.display.virtualtext.position)
end

T["validate_new_options"]["function hook is preserved"] = function()
  local opts = vim.deepcopy(config.default_options)
  local fn = function() return false end
  opts.hooks.disable_line_highlight = fn
  config.validate_new_options(opts)
  eq(fn, opts.hooks.disable_line_highlight)
end

T["validate_new_options"]["names.custom_hashed has hash field"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.names.custom = { a = "#111111", b = "#222222" }
  config.validate_new_options(opts)
  eq("string", type(opts.parsers.names.custom_hashed.hash))
  eq(true, #opts.parsers.names.custom_hashed.hash > 0)
end

T["validate_new_options"]["rejects invalid custom parser"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.custom = {
    { name = "bad_parser" }, -- missing parse function
  }
  local ok, err = pcall(config.validate_new_options, opts)
  eq(false, ok)
  eq(true, err:find("Invalid custom parser") ~= nil)
end

T["validate_new_options"]["rejects custom parser without name"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.custom = {
    { parse = function() end }, -- missing name
  }
  local ok, err = pcall(config.validate_new_options, opts)
  eq(false, ok)
  eq(true, err:find("Invalid custom parser") ~= nil)
end

T["validate_new_options"]["accepts valid custom parser"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.custom = {
    { name = "good", parse = function() end },
  }
  config.validate_new_options(opts)
  -- Should not error
  eq("good", opts.parsers.custom[1].name)
end

T["validate_new_options"]["always_update is preserved"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.always_update = true
  config.validate_new_options(opts)
  eq(true, opts.always_update)
end

-- as_flat additional tests --------------------------------------------------

T["as_flat"]["converts all hex flags correctly"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.parsers.hex.rgb = true
  opts.parsers.hex.rgba = false
  opts.parsers.hex.rrggbb = true
  opts.parsers.hex.rrggbbaa = true
  opts.parsers.hex.aarrggbb = true
  local flat = config.as_flat(opts)
  eq(true, flat.RGB)
  eq(false, flat.RGBA)
  eq(true, flat.RRGGBB)
  eq(true, flat.RRGGBBAA)
  eq(true, flat.AARRGGBB)
end

T["as_flat"]["converts names_opts correctly"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.names.enable = true
  opts.parsers.names.lowercase = false
  opts.parsers.names.uppercase = true
  opts.parsers.names.strip_digits = true
  local flat = config.as_flat(opts)
  eq(true, flat.names)
  eq(false, flat.names_opts.lowercase)
  eq(true, flat.names_opts.uppercase)
  eq(true, flat.names_opts.strip_digits)
end

T["as_flat"]["converts css functions correctly"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.rgb.enable = true
  opts.parsers.hsl.enable = true
  opts.parsers.oklch.enable = false
  local flat = config.as_flat(opts)
  eq(true, flat.rgb_fn)
  eq(true, flat.hsl_fn)
  eq(false, flat.oklch_fn)
end

T["as_flat"]["presets are always false in flat output"] = function()
  local opts = vim.deepcopy(config.default_options)
  local flat = config.as_flat(opts)
  eq(false, flat.css)
  eq(false, flat.css_fn)
end

T["as_flat"]["converts sass correctly"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.sass.enable = true
  opts.parsers.sass.parsers = { css = true }
  local flat = config.as_flat(opts)
  eq(true, flat.sass.enable)
  eq(true, flat.sass.parsers.css)
end

T["as_flat"]["converts xterm correctly"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.xterm.enable = true
  local flat = config.as_flat(opts)
  eq(true, flat.xterm)
end

T["as_flat"]["converts virtualtext char correctly"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.display.virtualtext.char = "X"
  local flat = config.as_flat(opts)
  eq("X", flat.virtualtext)
end

T["as_flat"]["converts virtualtext_mode correctly"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.display.virtualtext.hl_mode = "background"
  local flat = config.as_flat(opts)
  eq("background", flat.virtualtext_mode)
end

T["as_flat"]["converts always_update correctly"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.always_update = true
  local flat = config.as_flat(opts)
  eq(true, flat.always_update)
end

T["as_flat"]["converts hooks correctly"] = function()
  local opts = vim.deepcopy(config.default_options)
  local fn = function() return true end
  opts.hooks = { disable_line_highlight = fn }
  local flat = config.as_flat(opts)
  eq(fn, flat.hooks.disable_line_highlight)
end

T["as_flat"]["converts tailwind_opts correctly"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.tailwind.update_names = true
  local flat = config.as_flat(opts)
  eq(true, flat.tailwind_opts.update_names)
end

T["as_flat"]["converts names_custom_hashed when present"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.names.custom_hashed = { hash = "abc", names = { r = "#f00" } }
  local flat = config.as_flat(opts)
  eq("abc", flat.names_custom_hashed.hash)
end

-- resolve_options additional tests ------------------------------------------

T["resolve_options"]["returns defaults for empty table"] = function()
  local result = config.resolve_options({})
  eq("table", type(result.parsers))
  eq(false, result.parsers.names.enable)
  eq(false, result.parsers.hex.enable)
end

T["resolve_options"]["css preset with override via new format"] = function()
  local result = config.resolve_options({ parsers = { css = true, rgb = { enable = false } } })
  eq(true, result.parsers.names.enable)
  eq(true, result.parsers.hex.enable)
  eq(false, result.parsers.rgb.enable)
  eq(true, result.parsers.hsl.enable)
  eq(true, result.parsers.oklch.enable)
end

T["resolve_options"]["legacy css enables all parsers"] = function()
  local result = config.resolve_options({ css = true })
  eq(true, result.parsers.names.enable)
  eq(true, result.parsers.hex.enable)
  eq(true, result.parsers.rgb.enable)
  eq(true, result.parsers.hsl.enable)
  eq(true, result.parsers.oklch.enable)
end

T["resolve_options"]["validates after merge"] = function()
  local result = config.resolve_options({ parsers = { names = { enable = true } } })
  eq(true, result.parsers.names.enable)
  -- Other defaults should be preserved
  eq(false, result.parsers.hex.enable)
  eq("background", result.display.mode)
end

T["resolve_options"]["preserves display settings"] = function()
  local result = config.resolve_options({
    parsers = { names = { enable = true } },
    display = { mode = "foreground" },
  })
  eq("foreground", result.display.mode)
end

-- expand_sass_parsers -------------------------------------------------------

T["expand_sass_parsers"] = new_set()

T["expand_sass_parsers"]["expands css preset"] = function()
  local result = config.expand_sass_parsers({ css = true })
  eq(true, result.parsers.names.enable)
  eq(true, result.parsers.hex.enable)
  eq(true, result.parsers.rgb.enable)
end

T["expand_sass_parsers"]["returns defaults for nil"] = function()
  local result = config.expand_sass_parsers(nil)
  eq(false, result.parsers.names.enable)
  eq(false, result.parsers.hex.enable)
end

T["expand_sass_parsers"]["expands css_fn preset"] = function()
  local result = config.expand_sass_parsers({ css_fn = true })
  eq(true, result.parsers.rgb.enable)
  eq(true, result.parsers.hsl.enable)
  eq(true, result.parsers.oklch.enable)
  eq(false, result.parsers.names.enable)
end

-- get_setup_options additional tests ----------------------------------------

T["get_setup_options new format"]["handles nil input"] = function()
  local s = config.get_setup_options(nil)
  eq("table", type(s.options))
  eq("table", type(s.options.parsers))
end

T["get_setup_options new format"]["preserves filetypes"] = function()
  local s = config.get_setup_options({
    filetypes = { "lua", "html" },
    options = { parsers = { names = { enable = true } } },
  })
  eq("lua", s.filetypes[1])
  eq("html", s.filetypes[2])
end

T["get_setup_options new format"]["preserves user_commands"] = function()
  local s = config.get_setup_options({
    user_commands = false,
    options = { parsers = { names = { enable = true } } },
  })
  eq(false, s.user_commands)
end

T["get_setup_options new format"]["preserves lazy_load"] = function()
  local s = config.get_setup_options({
    lazy_load = true,
    options = { parsers = { names = { enable = true } } },
  })
  eq(true, s.lazy_load)
end

T["get_setup_options new format"]["called twice resets state"] = function()
  config.get_setup_options({
    options = { parsers = { css = true } },
  })
  local s = config.get_setup_options({
    options = { parsers = { names = { enable = true } } },
  })
  -- Second call should not carry over css preset from first call
  eq(true, s.options.parsers.names.enable)
  eq(false, s.options.parsers.hex.enable)
end

T["get_setup_options new format"]["display options propagate"] = function()
  local s = config.get_setup_options({
    options = {
      parsers = { names = { enable = true } },
      display = {
        mode = "virtualtext",
        virtualtext = { char = "X", position = "before", hl_mode = "background" },
      },
    },
  })
  eq("virtualtext", s.options.display.mode)
  eq("X", s.options.display.virtualtext.char)
  eq("before", s.options.display.virtualtext.position)
  eq("background", s.options.display.virtualtext.hl_mode)
end

-- get_setup_options legacy format -------------------------------------------

T["get_setup_options legacy"] = new_set()

T["get_setup_options legacy"]["accepts user_default_options"] = function()
  local s = config.get_setup_options({
    user_default_options = { names = true, RGB = true, RRGGBB = true },
  })
  -- New format should be populated
  eq(true, s.options.parsers.names.enable)
  eq(true, s.options.parsers.hex.enable)
  -- Legacy view should also work
  eq(true, s.user_default_options.names)
  eq(true, s.user_default_options.RGB)
end

T["get_setup_options legacy"]["legacy css preset resolves"] = function()
  local s = config.get_setup_options({
    user_default_options = { css = true },
  })
  eq(true, s.options.parsers.names.enable)
  eq(true, s.options.parsers.hex.enable)
  eq(true, s.options.parsers.rgb.enable)
end

-- matcher cache tests -------------------------------------------------------

T["matcher cache"] = new_set()

T["matcher cache"]["same options return same function"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.parsers.hex.rrggbb = true
  local fn1 = matcher.make(opts)
  local fn2 = matcher.make(opts)
  eq(fn1, fn2)
end

T["matcher cache"]["different options return different functions"] = function()
  local opts1 = vim.deepcopy(config.default_options)
  opts1.parsers.hex.enable = true
  opts1.parsers.hex.rrggbb = true
  local opts2 = vim.deepcopy(config.default_options)
  opts2.parsers.names.enable = true
  local fn1 = matcher.make(opts1)
  local fn2 = matcher.make(opts2)
  eq(true, fn1 ~= fn2)
end

T["matcher cache"]["reset_cache invalidates"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.parsers.hex.rrggbb = true
  local fn1 = matcher.make(opts)
  matcher.reset_cache()
  local fn2 = matcher.make(opts)
  eq(true, fn1 ~= fn2)
end

T["matcher cache"]["custom parser names in cache key"] = function()
  local opts1 = vim.deepcopy(config.default_options)
  opts1.parsers.custom = {
    { name = "alpha", parse = function() end },
  }
  local opts2 = vim.deepcopy(config.default_options)
  opts2.parsers.custom = {
    { name = "beta", parse = function() end },
  }
  local fn1 = matcher.make(opts1)
  local fn2 = matcher.make(opts2)
  eq(true, fn1 ~= fn2)
end

T["matcher cache"]["custom parser name order does not affect cache"] = function()
  local parse_a = function() end
  local parse_b = function() end
  local opts1 = vim.deepcopy(config.default_options)
  opts1.parsers.custom = {
    { name = "alpha", parse = parse_a },
    { name = "beta", parse = parse_b },
  }
  local opts2 = vim.deepcopy(config.default_options)
  opts2.parsers.custom = {
    { name = "beta", parse = parse_b },
    { name = "alpha", parse = parse_a },
  }
  local fn1 = matcher.make(opts1)
  local fn2 = matcher.make(opts2)
  -- Names are sorted in cache key so order shouldn't matter
  eq(fn1, fn2)
end

-- matcher with hooks --------------------------------------------------------

T["matcher hooks"] = new_set()

T["matcher hooks"]["disable_line_highlight skips line"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.parsers.hex.rrggbb = true
  opts.hooks = {
    disable_line_highlight = function(line)
      return line:sub(1, 2) == "--"
    end,
  }
  local parse_fn = matcher.make(opts)
  -- Normal line should parse
  local len1, hex1 = parse_fn("#ff0000 text", 1, 0, 0)
  eq(7, len1)
  eq("ff0000", hex1)
  -- Comment line should be skipped
  local len2, hex2 = parse_fn("-- #ff0000 text", 1, 0, 0)
  eq(nil, len2)
  eq(nil, hex2)
end

T["matcher hooks"]["hook receives bufnr and line_nr"] = function()
  local captured_bufnr, captured_line_nr
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.parsers.hex.rrggbb = true
  opts.hooks = {
    disable_line_highlight = function(_, bufnr, line_nr)
      captured_bufnr = bufnr
      captured_line_nr = line_nr
      return false
    end,
  }
  local parse_fn = matcher.make(opts)
  parse_fn("#ff0000", 1, 42, 7)
  eq(42, captured_bufnr)
  eq(7, captured_line_nr)
end

-- matcher hex format combinations -------------------------------------------

T["matcher hex formats"] = new_set()

T["matcher hex formats"]["finds #RGB when enabled"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.parsers.hex.rgb = true
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("#F00 text", 1)
  eq(4, len)
  -- Parser expands 3-digit to 6-digit hex
  eq("ff0000", hex:lower())
end

T["matcher hex formats"]["finds #RGBA when enabled"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.parsers.hex.rgba = true
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("#F00F text", 1)
  eq(true, len ~= nil)
end

T["matcher hex formats"]["finds #RRGGBBAA when enabled"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.parsers.hex.rrggbbaa = true
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("#FF0000FF text", 1)
  eq(true, len ~= nil)
end

T["matcher hex formats"]["finds 0xAARRGGBB when enabled"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.parsers.hex.aarrggbb = true
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("0xFFFF0000 text", 1)
  eq(true, len ~= nil)
end

T["matcher hex formats"]["does not find disabled formats"] = function()
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.parsers.hex.rgb = false
  opts.parsers.hex.rgba = false
  opts.parsers.hex.rrggbb = true
  opts.parsers.hex.rrggbbaa = false
  local parse_fn = matcher.make(opts)
  -- #RGB should not match
  local len1 = parse_fn("#F00 text", 1)
  eq(nil, len1)
end

-- matcher make with nil opts ------------------------------------------------

T["matcher new format"]["make() with nil returns false"] = function()
  eq(false, matcher.make(nil))
end

-- buffer.parse_lines tests --------------------------------------------------

T["parse_lines"] = new_set()

T["parse_lines"]["parses single color on line"] = function()
  local opts = config.resolve_options({ parsers = { hex = { enable = true, rrggbb = true } } })
  local data = buffer.parse_lines(0, { "#ff0000" }, 0, opts)
  eq(true, data ~= nil)
  eq(true, data[0] ~= nil)
  eq("ff0000", data[0][1].rgb_hex)
  eq(0, data[0][1].range[1])
  eq(7, data[0][1].range[2])
end

T["parse_lines"]["parses multiple colors on line"] = function()
  local opts = config.resolve_options({ parsers = { hex = { enable = true, rrggbb = true } } })
  local data = buffer.parse_lines(0, { "#ff0000 #00ff00" }, 0, opts)
  eq(2, #data[0])
  eq("ff0000", data[0][1].rgb_hex)
  eq("00ff00", data[0][2].rgb_hex)
end

T["parse_lines"]["parses multiple lines"] = function()
  local opts = config.resolve_options({ parsers = { hex = { enable = true, rrggbb = true } } })
  local data = buffer.parse_lines(0, { "#ff0000", "#00ff00" }, 0, opts)
  eq("ff0000", data[0][1].rgb_hex)
  eq("00ff00", data[1][1].rgb_hex)
end

T["parse_lines"]["returns nil when no parsers enabled"] = function()
  local opts = vim.deepcopy(config.default_options)
  local data = buffer.parse_lines(0, { "#ff0000" }, 0, opts)
  eq(nil, data)
end

T["parse_lines"]["skips lines with no colors"] = function()
  local opts = config.resolve_options({ parsers = { hex = { enable = true, rrggbb = true } } })
  local data = buffer.parse_lines(0, { "no colors here" }, 0, opts)
  eq(true, data ~= nil)
  eq(nil, data[0])
end

T["parse_lines"]["respects line_start offset"] = function()
  local opts = config.resolve_options({ parsers = { hex = { enable = true, rrggbb = true } } })
  local data = buffer.parse_lines(0, { "#ff0000" }, 5, opts)
  eq(nil, data[0])
  eq("ff0000", data[5][1].rgb_hex)
end

T["parse_lines"]["parses color at middle of line"] = function()
  local opts = config.resolve_options({ parsers = { hex = { enable = true, rrggbb = true } } })
  local data = buffer.parse_lines(0, { "text #ff0000 end" }, 0, opts)
  eq("ff0000", data[0][1].rgb_hex)
  eq(5, data[0][1].range[1])
  eq(12, data[0][1].range[2])
end

T["parse_lines"]["empty line produces no data"] = function()
  local opts = config.resolve_options({ parsers = { hex = { enable = true, rrggbb = true } } })
  local data = buffer.parse_lines(0, { "" }, 0, opts)
  eq(nil, data[0])
end

T["parse_lines"]["mixed color formats"] = function()
  local opts = config.resolve_options({ parsers = { css = true } })
  local data = buffer.parse_lines(0, { "#ff0000 rgb(0, 255, 0)" }, 0, opts)
  eq(true, #data[0] >= 2)
  eq("ff0000", data[0][1].rgb_hex)
  eq("00ff00", data[0][2].rgb_hex)
end

-- Roundtrip: new -> flat -> resolve -----------------------------------------

T["roundtrip"] = new_set()

T["roundtrip"]["new -> flat -> resolve preserves enabled parsers"] = function()
  local original = vim.deepcopy(config.default_options)
  original.parsers.names.enable = true
  original.parsers.hex.enable = true
  original.parsers.hex.rrggbb = true
  original.parsers.rgb.enable = true
  original.display.mode = "foreground"

  local flat = config.as_flat(original)
  local restored = config.resolve_options(flat)

  eq(true, restored.parsers.names.enable)
  eq(true, restored.parsers.hex.enable)
  eq(true, restored.parsers.hex.rrggbb)
  eq(true, restored.parsers.rgb.enable)
  eq("foreground", restored.display.mode)
end

T["roundtrip"]["new -> flat -> resolve preserves display settings"] = function()
  local original = vim.deepcopy(config.default_options)
  original.parsers.names.enable = true
  original.display.mode = "virtualtext"
  original.display.virtualtext.char = "X"
  original.display.virtualtext.position = "before"
  original.display.virtualtext.hl_mode = "background"

  local flat = config.as_flat(original)
  local restored = config.resolve_options(flat)

  eq("virtualtext", restored.display.mode)
  eq("X", restored.display.virtualtext.char)
  eq("before", restored.display.virtualtext.position)
  eq("background", restored.display.virtualtext.hl_mode)
end

T["roundtrip"]["new -> flat -> resolve preserves tailwind"] = function()
  local original = vim.deepcopy(config.default_options)
  original.parsers.tailwind.enable = true
  original.parsers.tailwind.mode = "both"
  original.parsers.tailwind.update_names = true

  local flat = config.as_flat(original)
  local restored = config.resolve_options(flat)

  eq(true, restored.parsers.tailwind.enable)
  eq("both", restored.parsers.tailwind.mode)
  eq(true, restored.parsers.tailwind.update_names)
end

-- display.background options --------------------------------------------------

T["display.background"] = new_set()

T["display.background"]["default bright_fg is #000000"] = function()
  eq("#000000", config.default_options.display.background.bright_fg)
end

T["display.background"]["default dark_fg is #ffffff"] = function()
  eq("#ffffff", config.default_options.display.background.dark_fg)
end

T["display.background"]["custom bright_fg is preserved through resolve"] = function()
  local opts = config.resolve_options({
    parsers = { hex = { enable = true } },
    display = { background = { bright_fg = "DarkGray" } },
  })
  eq("DarkGray", opts.display.background.bright_fg)
  eq("#ffffff", opts.display.background.dark_fg)
end

T["display.background"]["custom dark_fg is preserved through resolve"] = function()
  local opts = config.resolve_options({
    parsers = { hex = { enable = true } },
    display = { background = { dark_fg = "LightYellow" } },
  })
  eq("#000000", opts.display.background.bright_fg)
  eq("LightYellow", opts.display.background.dark_fg)
end

T["display.background"]["bright color uses bright_fg"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "#FFFFFF" })
  local ns = vim.api.nvim_create_namespace("test_bright_fg")
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.display.background.bright_fg = "DarkGreen"
  local data = buffer.parse_lines(buf, { "#FFFFFF" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(true, #marks > 0)
  -- Verify the highlight group exists and was applied
  local hl = vim.api.nvim_get_hl(0, { name = marks[1][4].hl_group })
  eq("DarkGreen", hl.fg and vim.api.nvim_get_color_by_name("DarkGreen") == hl.fg and "DarkGreen" or nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- display.priority options ----------------------------------------------------

T["display.priority"] = new_set()

T["display.priority"]["default values"] = function()
  eq(200, config.default_options.display.priority.default)
  eq(300, config.default_options.display.priority.lsp)
end

T["display.priority"]["custom default priority is used"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "#FF0000" })
  local ns = vim.api.nvim_create_namespace("test_custom_priority")
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.display.priority.default = 50
  local data = buffer.parse_lines(buf, { "#FF0000" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(50, marks[1][4].priority)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["display.priority"]["custom lsp priority is used"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "#FF0000" })
  local ns = vim.api.nvim_create_namespace("test_custom_lsp_priority")
  local opts = vim.deepcopy(config.default_options)
  opts.parsers.hex.enable = true
  opts.display.priority.lsp = 300
  local data = buffer.parse_lines(buf, { "#FF0000" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts, { tailwind_lsp = true })
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(300, marks[1][4].priority)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["display.priority"]["preserved through resolve"] = function()
  local opts = config.resolve_options({
    parsers = { hex = { enable = true } },
    display = { priority = { default = 42, lsp = 99 } },
  })
  eq(42, opts.display.priority.default)
  eq(99, opts.display.priority.lsp)
end

-- parsers.sass.variable_pattern -----------------------------------------------

T["parsers.sass.variable_pattern"] = new_set()

T["parsers.sass.variable_pattern"]["default pattern exists"] = function()
  eq("^%$([%w_-]+)", config.default_options.parsers.sass.variable_pattern)
end

T["parsers.sass.variable_pattern"]["custom pattern preserved through resolve"] = function()
  local opts = config.resolve_options({
    parsers = { sass = { enable = true, variable_pattern = "^@([%w_]+)" } },
  })
  eq("^@([%w_]+)", opts.parsers.sass.variable_pattern)
end

return T
