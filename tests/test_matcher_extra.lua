local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local matcher = require("colorizer.matcher")
local config = require("colorizer.config")
local names = require("colorizer.parser.names")
local buffer = require("colorizer.buffer")
local sass = require("colorizer.sass")

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

-- xterm #xNN path (tried before rgba_hex for # prefix) -----------------------

T["xterm via matcher"] = new_set()

T["xterm via matcher"]["#x00 through matcher returns black"] = function()
  local parse_fn = matcher.make(make_opts({ RRGGBB = true, xterm = true }))
  -- xterm code 0 is black (#000000)
  local len, hex = parse_fn("#x00", 1)
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["xterm via matcher"]["#x255 through matcher returns grayscale"] = function()
  local parse_fn = matcher.make(make_opts({ RRGGBB = true, xterm = true }))
  -- xterm code 255 is gray #eeeeee (decimal format, not hex)
  local len, hex = parse_fn("#x255", 1)
  eq(true, len ~= nil)
  eq("eeeeee", hex)
end

T["xterm via matcher"]["#x10 returns color (not confused with hex)"] = function()
  local parse_fn = matcher.make(make_opts({ RRGGBB = true, xterm = true }))
  -- xterm #xNN is decimal, so #x10 is palette index 10
  local len, hex = parse_fn("#x10 text", 1)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["xterm via matcher"]["ANSI escape through matcher"] = function()
  local parse_fn = matcher.make(make_opts({ xterm = true }))
  -- \e[38;5;196m = ANSI 256-color red
  local line = "\x1b[38;5;196m"
  local len, hex = parse_fn(line, 1)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

-- sass $ prefix path through matcher ------------------------------------------

T["sass via matcher"] = new_set()

T["sass via matcher"]["$varname resolved through matcher"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "$mycolor: #ff0000;" })
  vim.api.nvim_buf_set_name(buf, "/tmp/test_matcher_sass_" .. buf .. ".scss")

  -- Set up sass state
  local function simple_color_parser(line, i)
    if line:sub(i, i) == "#" and #line >= i + 6 then
      local hex = line:sub(i + 1, i + 6):lower()
      if hex:match("^[0-9a-f]+$") then
        return 7, hex
      end
    end
  end
  sass.update_variables(buf, 0, 1, { "$mycolor: #ff0000;" }, simple_color_parser, {}, {})

  -- Build matcher with sass enabled
  local opts = make_opts({ sass = { enable = true, parsers = { css = true } } })
  local parse_fn = matcher.make(opts)

  local len, hex = parse_fn("$mycolor", 1, buf, 0)
  eq(true, len ~= nil)
  eq("ff0000", hex)

  sass.cleanup(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["sass via matcher"]["$ without sass enabled returns nil"] = function()
  local parse_fn = matcher.make(make_opts({ RRGGBB = true }))
  local len, hex = parse_fn("$mycolor", 1, 1, 0)
  eq(nil, len)
  eq(nil, hex)
end

-- config: sass parser alias expansion -----------------------------------------

T["config sass alias"] = new_set()

T["config sass alias"]["sass.parsers.css expands when top-level css is true"] = function()
  local opts = config.apply_alias_options({
    css = true,
    sass = { enable = true, parsers = { css = true } },
  })
  -- When top-level css=true, sass.parsers.css alias expands using that value
  eq(true, opts.sass.parsers.css)
  -- The sass.parsers table retains its css key
  eq(true, opts.sass.enable)
end

T["config sass alias"]["sass.parsers preserved after apply_alias_options"] = function()
  local opts = config.apply_alias_options({
    sass = { enable = true, parsers = { css = true } },
  })
  eq(true, opts.sass.enable)
  eq(true, opts.sass.parsers.css)
end

-- matcher with names_custom ---------------------------------------------------

T["names_custom via matcher"] = new_set()

T["names_custom via matcher"]["custom color name is found"] = function()
  local opts = make_opts({
    names_custom = { myred = "#ff0000" },
  })
  local parse_fn = matcher.make(opts)
  local len, hex = parse_fn("myred text", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["names_custom via matcher"]["different custom names produce different cache keys"] = function()
  local opts1 = make_opts({ names_custom = { colorA = "#111111" } })
  local opts2 = make_opts({ names_custom = { colorB = "#222222" } })
  local fn1 = matcher.make(opts1)
  matcher.reset_cache()
  names.reset_cache()
  local fn2 = matcher.make(opts2)
  eq(true, fn1 ~= fn2)
end

-- matcher with tailwind "normal" (name-based matching) ------------------------

T["tailwind normal via matcher"] = new_set()

T["tailwind normal via matcher"]["finds tailwind color names"] = function()
  local opts = make_opts({ tailwind = "normal" })
  local parse_fn = matcher.make(opts)
  -- "bg-red-500" should match as a tailwind color
  local len, hex = parse_fn("bg-red-500 text", 1)
  eq(true, len ~= nil)
  eq("ef4444", hex)
end

-- Helper: build new-format options for parsers not in legacy format
local function make_new_opts(parsers)
  return config.resolve_options({ parsers = parsers })
end

-- hex_no_hash via matcher ------------------------------------------------------

T["hex_no_hash via matcher"] = new_set()

T["hex_no_hash via matcher"]["finds RRGGBB without # prefix"] = function()
  local parse_fn = matcher.make(make_new_opts({ hex = { no_hash = true } }))
  local len, hex = parse_fn("FF0000 text", 1)
  eq(6, len)
  eq("ff0000", hex)
end

T["hex_no_hash via matcher"]["not found when hex_no_hash disabled"] = function()
  local parse_fn = matcher.make(make_new_opts({ hex = { rrggbb = true } }))
  local len = parse_fn("FF0000 text", 1)
  eq(nil, len)
end

T["hex_no_hash via matcher"]["does not block named colors starting with hex letter"] = function()
  local parse_fn = matcher.make(make_new_opts({ css = true, hex = { no_hash = true } }))
  -- "coral" starts with 'c' (a hex byte) — must still match as a named color
  local len, hex = parse_fn("coral text", 1)
  eq(true, len ~= nil)
  eq("ff7f50", hex)
end

T["hex_no_hash via matcher"]["does not block DeepSkyBlue starting with D"] = function()
  local parse_fn = matcher.make(make_new_opts({ css = true, hex = { no_hash = true } }))
  local len, hex = parse_fn("DeepSkyBlue text", 1)
  eq(true, len ~= nil)
  eq("00bfff", hex)
end

T["hex_no_hash via matcher"]["does not block blue starting with b"] = function()
  local parse_fn = matcher.make(make_new_opts({ css = true, hex = { no_hash = true } }))
  local len, hex = parse_fn("blue text", 1)
  eq(true, len ~= nil)
  eq("0000ff", hex)
end

-- hsluv via matcher ------------------------------------------------------------

T["hsluv via matcher"] = new_set()

T["hsluv via matcher"]["finds hsluv() function"] = function()
  local parse_fn = matcher.make(make_new_opts({ hsluv = { enable = true } }))
  local len, hex = parse_fn("hsluv(0, 100, 50)", 1)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["hsluv via matcher"]["finds hsluvu() with alpha"] = function()
  local parse_fn = matcher.make(make_new_opts({ hsluv = { enable = true } }))
  local len, hex = parse_fn("hsluvu(0, 100, 50, 0.5)", 1)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["hsluv via matcher"]["not found when hsluv disabled"] = function()
  local parse_fn = matcher.make(make_new_opts({ hex = { rrggbb = true } }))
  local len = parse_fn("hsluv(0, 100, 50)", 1)
  eq(nil, len)
end

-- xcolor via matcher -----------------------------------------------------------

T["xcolor via matcher"] = new_set()

T["xcolor via matcher"]["finds red!50 blended color"] = function()
  local parse_fn = matcher.make(make_new_opts({
    names = { enable = true, lowercase = true },
    xcolor = { enable = true },
  }))
  local len, hex = parse_fn("red!50 text", 1)
  eq(true, len ~= nil)
  -- red!50 blends red (#ff0000) 50% with white (#ffffff) → pinkish
  eq(true, hex ~= nil)
end

T["xcolor via matcher"]["not found when xcolor disabled"] = function()
  local parse_fn = matcher.make(make_new_opts({
    names = { enable = true, lowercase = true },
  }))
  -- Without xcolor, "red!50" should match "red" (3 chars) not "red!50" (6 chars)
  local len = parse_fn("red!50 text", 1)
  -- names matches "red" (3 chars), not the full "red!50"
  eq(3, len)
end

-- css_var_rgb via matcher ------------------------------------------------------

T["css_var_rgb via matcher"] = new_set()

T["css_var_rgb via matcher"]["finds --color: R,G,B"] = function()
  local parse_fn = matcher.make(make_new_opts({ css_var_rgb = { enable = true } }))
  local len, hex = parse_fn("--color: 255,0,0;", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["css_var_rgb via matcher"]["not found when css_var_rgb disabled"] = function()
  local parse_fn = matcher.make(make_new_opts({ hex = { rrggbb = true } }))
  local len = parse_fn("--color: 255,0,0;", 1)
  eq(nil, len)
end

-- hash_aarrggbb via matcher ----------------------------------------------------

T["hash_aarrggbb via matcher"] = new_set()

T["hash_aarrggbb via matcher"]["finds #AARRGGBB format"] = function()
  local parse_fn = matcher.make(make_new_opts({ hex = { hash_aarrggbb = true } }))
  -- #FFFF0000 = fully opaque red in AARRGGBB format
  local len, hex = parse_fn("#FFFF0000 text", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

-- Caching with new flags -------------------------------------------------------

T["caching new flags"] = new_set()

T["caching new flags"]["hex_no_hash toggle produces different cache key"] = function()
  local fn1 = matcher.make(make_new_opts({ hex = { rrggbb = true } }))
  local fn2 = matcher.make(make_new_opts({ hex = { rrggbb = true, no_hash = true } }))
  eq(true, fn1 ~= fn2)
end

T["caching new flags"]["hsluv toggle produces different cache key"] = function()
  local fn1 = matcher.make(make_new_opts({ hex = { rrggbb = true } }))
  local fn2 = matcher.make(make_new_opts({ hex = { rrggbb = true }, hsluv = { enable = true } }))
  eq(true, fn1 ~= fn2)
end

T["caching new flags"]["xcolor toggle produces different cache key"] = function()
  local fn1 = matcher.make(make_new_opts({ names = { enable = true, lowercase = true } }))
  local fn2 = matcher.make(make_new_opts({ names = { enable = true, lowercase = true }, xcolor = { enable = true } }))
  eq(true, fn1 ~= fn2)
end

T["caching new flags"]["css_var_rgb toggle produces different cache key"] = function()
  local fn1 = matcher.make(make_new_opts({ hex = { rrggbb = true } }))
  local fn2 = matcher.make(make_new_opts({ hex = { rrggbb = true }, css_var_rgb = { enable = true } }))
  eq(true, fn1 ~= fn2)
end

return T
