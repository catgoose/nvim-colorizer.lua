-- Screenshot configuration definitions
-- Each config maps to colorizer setup options and a fixture file.
--
-- Design: each config enables only ONE parser option, so the screenshot
-- shows exactly which strings that option highlights (and which it doesn't).
-- Fixture files use appropriate file types for syntax highlighting.

local M = {}

local script_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local root_dir = vim.fn.fnamemodify(script_dir .. "/../..", ":p"):gsub("/$", "")
local fixtures_dir = script_dir .. "/fixtures"

-- Shorthand: build a config entry from parser opts + fixture name
local function cfg(fixture, parsers, meta)
  meta = meta or {}
  local opts = { parsers = parsers }
  if meta.display then
    opts.display = meta.display
  end
  if meta.hooks then
    opts.hooks = meta.hooks
  end
  return {
    setup_opts = { options = opts },
    fixture = fixtures_dir .. "/" .. fixture,
    label = meta.label,
    description = meta.description,
    split = meta.split,
  }
end

--- All screenshot configurations.
M.configs = {
  -- ── Default showcase ─────────────────────────────────────────────
  default = cfg("default.css", { css = true }, {
    label = "default",
    description = "css = true (names + hex + rgb + hsl + oklch)",
  }),

  -- ── Presets ─────────────────────────────────────────────────────
  preset_css = cfg("preset_css.css", { css = true }, {
    label = "preset_css",
    description = "css = true preset (names + hex + rgb + hsl + oklch)",
    split = true,
  }),
  preset_css_fn = cfg("preset_css_fn.scss", { css_fn = true }, {
    label = "preset_css_fn",
    description = "css_fn = true preset (rgb + hsl + oklch only)",
  }),

  -- ── Hex group ────────────────────────────────────────────────────
  hex_rgb = cfg("hex_rgb.css", { hex = { rgb = true } }, {
    label = "hex_rgb",
    description = "#RGB (3-digit)",
  }),
  hex_rgba = cfg("hex_rgba.css", { hex = { rgba = true } }, {
    label = "hex_rgba",
    description = "#RGBA (4-digit)",
  }),
  hex_rrggbb = cfg("hex_rrggbb.css", { hex = { rrggbb = true } }, {
    label = "hex_rrggbb",
    description = "#RRGGBB (6-digit)",
  }),
  hex_rrggbbaa = cfg("hex_rrggbbaa.css", { hex = { rrggbbaa = true } }, {
    label = "hex_rrggbbaa",
    description = "#RRGGBBAA (8-digit)",
  }),
  hex_hash_aarrggbb = cfg("hex_hash_aarrggbb.css", { hex = { hash_aarrggbb = true } }, {
    label = "hex_hash_aarrggbb",
    description = "#AARRGGBB (QML 8-digit)",
  }),
  hex_0x_aarrggbb = cfg("hex_0x_aarrggbb.css", { hex = { aarrggbb = true } }, {
    label = "hex_0x_aarrggbb",
    description = "0xAARRGGBB (prefix hex)",
  }),
  hex_no_hash = cfg("hex_no_hash.lua", { hex = { no_hash = true } }, {
    label = "hex_no_hash",
    description = "RRGGBB without # prefix",
  }),
  hex_default = cfg("hex_default.css", { hex = { default = true } }, {
    label = "hex_default",
    description = "hex.default (all common formats)",
  }),
  hex_all = cfg("hex_all.css", {
    hex = { default = true, hash_aarrggbb = true, no_hash = true },
  }, {
    label = "hex_all",
    description = "All hex formats combined",
  }),

  -- ── CSS function group ───────────────────────────────────────────
  css_rgb = cfg("css_rgb.scss", { rgb = { enable = true } }, {
    label = "css_rgb",
    description = "rgb() / rgba() functions",
  }),
  css_hsl = cfg("css_hsl.scss", { hsl = { enable = true } }, {
    label = "css_hsl",
    description = "hsl() / hsla() functions",
  }),
  css_oklch = cfg("css_oklch.scss", { oklch = { enable = true } }, {
    label = "css_oklch",
    description = "oklch() function",
  }),
  css_hsluv = cfg("css_hsluv.scss", { hsluv = { enable = true } }, {
    label = "css_hsluv",
    description = "hsluv() / hsluvu() functions",
  }),
  css_all = cfg("css_all.scss", {
    rgb = { enable = true },
    hsl = { enable = true },
    oklch = { enable = true },
    hsluv = { enable = true },
  }, {
    label = "css_all",
    description = "All CSS color functions combined",
    split = true,
  }),

  -- ── Names group ──────────────────────────────────────────────────
  names_lowercase = cfg("names_lowercase.css", {
    names = { enable = true, lowercase = true, camelcase = false, uppercase = false },
  }, {
    label = "names_lowercase",
    description = "lowercase named colors only",
  }),
  names_camelcase = cfg("names_camelcase.css", {
    names = { enable = true, lowercase = false, camelcase = true, uppercase = false },
  }, {
    label = "names_camelcase",
    description = "CamelCase named colors only",
  }),
  names_uppercase = cfg("names_uppercase.css", {
    names = { enable = true, lowercase = false, camelcase = false, uppercase = true },
  }, {
    label = "names_uppercase",
    description = "UPPERCASE named colors only",
  }),
  names_tailwind = cfg("names_tailwind.html", { tailwind = { enable = true } }, {
    label = "names_tailwind",
    description = "Tailwind CSS color names",
  }),
  names_strip_digits = cfg("names_strip_digits.css", {
    names = { enable = true, lowercase = true, strip_digits = true },
  }, {
    label = "names_strip_digits",
    description = "strip_digits rejects names ending in digits",
  }),
  names_all = cfg("names_all.css", {
    names = { enable = true, lowercase = true, camelcase = true, uppercase = true },
    tailwind = { enable = true },
  }, {
    label = "names_all",
    description = "All name styles combined",
  }),

  names_custom = cfg("names_custom.css", {
    names = {
      enable = true,
      lowercase = false,
      camelcase = false,
      uppercase = false,
      extra_word_chars = "",
      custom = {
        ["brand-primary"] = "#E63946",
        ["brand-secondary"] = "#457B9D",
        ["ui-success"] = "#2A9D8F",
        ["ui-warning"] = "#E9C46A",
        ["ui-danger"] = "#F4A261",
      },
    },
  }, {
    label = "names_custom",
    description = "User-defined custom color names",
  }),

  names_extra_word_chars = cfg("names_extra_word_chars.css", {
    names = {
      enable = true,
      lowercase = false,
      camelcase = false,
      uppercase = false,
      extra_word_chars = "-",
      custom = {
        ["brand-primary"] = "#E63946",
        ["brand-secondary"] = "#457B9D",
        ["ui-success"] = "#2A9D8F",
        ["ui-warning"] = "#E9C46A",
      },
    },
  }, {
    label = "names_extra_word_chars",
    description = "extra_word_chars = \"-\" (hyphens in names)",
  }),

  -- ── Special group ────────────────────────────────────────────────
  special_xterm = cfg("xterm.sh", { xterm = { enable = true } }, {
    label = "special_xterm",
    description = "Xterm 256-color (#xN)",
  }),
  special_xcolor = cfg("xcolor.tex", { xcolor = { enable = true } }, {
    label = "special_xcolor",
    description = "XColor blending (name!percent)",
  }),
  special_css_var_rgb = cfg("css_var_rgb.css", { css_var_rgb = { enable = true } }, {
    label = "special_css_var_rgb",
    description = "CSS variable RGB (--var: r,g,b;)",
  }),
  special_sass = cfg("sass.scss", { sass = { enable = true, parsers = { css = true } } }, {
    label = "special_sass",
    description = "Sass $variable color resolution",
  }),
  special_sass_pattern = cfg("sass_pattern.scss", {
    sass = { enable = true, parsers = { css = true }, variable_pattern = "^%$([%a]+)" },
  }, {
    label = "special_sass_pattern",
    description = "variable_pattern restricts to alpha-only names",
  }),
  special_hooks_line_filter = cfg("hooks_line_filter.css", { css = true }, {
    label = "special_hooks_line_filter",
    description = "should_highlight_line skips comment lines",
    hooks = {
      should_highlight_line = function(line)
        return not line:match("^/%*")
      end,
    },
  }),

  -- ── Demo ────────────────────────────────────────────────────────
  demo = cfg("demo.css", {
    css = true,
    hsluv = { enable = true },
    tailwind = { enable = true },
    hex = { no_hash = true },
    xterm = { enable = true },
    xcolor = { enable = true },
    sass = { enable = true, parsers = { css = true } },
  }, {
    label = "demo",
    description = "Full demo showcase",
  }),

  -- ── Display modes ──────────────────────────────────────────────
  display_background = cfg("display.css", { css = true }, {
    label = "display_background",
    description = "mode = background (default)",
    display = { mode = "background" },
  }),
  display_foreground = cfg("display.css", { css = true }, {
    label = "display_foreground",
    description = "mode = foreground (colored text)",
    display = { mode = "foreground" },
  }),
  display_virtualtext_eol = cfg("display.css", { css = true }, {
    label = "display_virtualtext_eol",
    description = "virtualtext at end of line",
    display = { mode = "virtualtext", virtualtext = { position = "eol" } },
  }),
  display_virtualtext_inline = cfg("display.css", { css = true }, {
    label = "display_virtualtext_inline",
    description = "virtualtext inline after color",
    display = { mode = "virtualtext", virtualtext = { position = "after" } },
  }),
  display_virtualtext_before = cfg("display.css", { css = true }, {
    label = "display_virtualtext_before",
    description = "virtualtext before color",
    display = { mode = "virtualtext", virtualtext = { position = "before" } },
  }),
  display_virtualtext_hl_bg = cfg("display.css", { css = true }, {
    label = "display_virtualtext_hl_bg",
    description = "virtualtext eol with hl_mode = background",
    display = { mode = "virtualtext", virtualtext = { position = "eol", hl_mode = "background" } },
  }),
  display_vt_before_hl_bg = cfg("display.css", { css = true }, {
    label = "display_vt_before_hl_bg",
    description = "virtualtext before with hl_mode = background",
    display = { mode = "virtualtext", virtualtext = { position = "before", hl_mode = "background" } },
  }),
  display_vt_after_hl_bg = cfg("display.css", { css = true }, {
    label = "display_vt_after_hl_bg",
    description = "virtualtext after with hl_mode = background",
    display = { mode = "virtualtext", virtualtext = { position = "after", hl_mode = "background" } },
  }),
  display_vt_char_circle = cfg("display.css", { css = true }, {
    label = "display_vt_char_circle",
    description = "virtualtext with char = ●",
    display = { mode = "virtualtext", virtualtext = { char = "●", position = "eol" } },
  }),
  display_vt_char_block = cfg("display.css", { css = true }, {
    label = "display_vt_char_block",
    description = "virtualtext with char = █",
    display = { mode = "virtualtext", virtualtext = { char = "█", position = "eol" } },
  }),
  display_bg_contrast = cfg("display_contrast.css", { css = true }, {
    label = "display_bg_contrast",
    description = "background mode with custom contrast colors",
    display = { mode = "background", background = { bright_fg = "#1a1a2e", dark_fg = "#e0e0ff" } },
  }),
}

--- Ordered categories for --list, iteration, and --<flag> filtering.
M.categories = {
  {
    flag = "default",
    display = "Default",
    img_width = 600,
    names = { "default" },
  },
  {
    flag = "preset",
    display = "Presets",
    names = { "preset_css", "preset_css_fn" },
  },
  {
    flag = "hex",
    display = "Hex",
    names = {
      "hex_rgb",
      "hex_rgba",
      "hex_rrggbb",
      "hex_rrggbbaa",
      "hex_hash_aarrggbb",
      "hex_0x_aarrggbb",
      "hex_no_hash",
      "hex_default",
      "hex_all",
    },
  },
  {
    flag = "css",
    display = "CSS Functions",
    names = { "css_rgb", "css_hsl", "css_oklch", "css_hsluv", "css_all" },
  },
  {
    flag = "names",
    display = "Named Colors",
    names = { "names_lowercase", "names_camelcase", "names_uppercase", "names_tailwind", "names_strip_digits", "names_custom", "names_extra_word_chars", "names_all" },
  },
  {
    flag = "special",
    display = "Special Parsers",
    names = { "special_xterm", "special_xcolor", "special_css_var_rgb", "special_sass", "special_sass_pattern", "special_hooks_line_filter" },
  },
  {
    flag = "display",
    display = "Display Modes",
    names = {
      "display_background",
      "display_foreground",
      "display_virtualtext_eol",
      "display_virtualtext_inline",
      "display_virtualtext_before",
      "display_virtualtext_hl_bg",
      "display_vt_before_hl_bg",
      "display_vt_after_hl_bg",
      "display_vt_char_circle",
      "display_vt_char_block",
      "display_bg_contrast",
    },
  },
}

--- Initialize nvim for a screenshot.
--- Called from init.lua with the config name from COLORIZER_CONFIG env var.
---@param config_name string
function M.screenshot_init(config_name)
  local c = M.configs[config_name]
  if not c then
    io.write("Unknown config: " .. config_name .. "\n")
    os.exit(1)
  end

  -- Add colorizer to rtp
  vim.opt.rtp:prepend(root_dir)

  -- Clone kanagawa colorscheme if not present
  local deps_dir = root_dir .. "/deps"
  local kanagawa_dir = deps_dir .. "/kanagawa.nvim"
  if not vim.uv.fs_stat(kanagawa_dir) then
    vim.fn.mkdir(deps_dir, "p")
    vim.fn.system({ "git", "clone", "--depth", "1", "https://github.com/rebelot/kanagawa.nvim", kanagawa_dir })
  end
  vim.opt.rtp:prepend(kanagawa_dir)

  -- Minimal UI settings
  vim.o.swapfile = false
  vim.o.hidden = true
  vim.o.termguicolors = true
  vim.o.cmdheight = 0
  vim.o.laststatus = 0
  vim.o.number = true
  vim.o.signcolumn = "no"
  vim.o.foldenable = false
  vim.o.fillchars = "eob: "

  vim.cmd.colorscheme("kanagawa-wave")

  -- Setup colorizer
  require("colorizer").setup(c.setup_opts)

  -- Open the fixture file and trigger filetype detection
  -- (filetype detect is needed because vim.cmd.edit during init
  -- does not automatically trigger filetype detection)
  vim.cmd.edit(c.fixture)
  vim.cmd("filetype detect")
end

return M
