-- Screenshot configuration definitions
-- Each config maps to colorizer setup options and a fixture file.
--
-- Design: each group (hex, css, names, special) shares ONE fixture file
-- containing ALL color strings for that group. Each config within the group
-- enables only ONE parser option, so the screenshot shows exactly which
-- strings that option highlights (and which it doesn't).

local M = {}

local script_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local root_dir = vim.fn.fnamemodify(script_dir .. "/../..", ":p"):gsub("/$", "")
local fixtures_dir = script_dir .. "/fixtures"

-- Shorthand: build a config entry from parser opts + fixture name
local function cfg(fixture, parsers, meta)
  meta = meta or {}
  return {
    setup_opts = { options = { parsers = parsers } },
    fixture = fixtures_dir .. "/" .. fixture,
    label = meta.label,
    description = meta.description,
  }
end

--- All screenshot configurations.
M.configs = {
  -- ── Default showcase ─────────────────────────────────────────────
  default = cfg("default.txt", { css = true }, {
    label = "default",
    description = "css = true (names + hex + rgb + hsl + oklch)",
  }),

  -- ── Hex group ────────────────────────────────────────────────────
  -- All share hex.txt; each enables one hex format
  hex_rgb = cfg("hex.txt", { hex = { rgb = true } }, {
    label = "hex_rgb",
    description = "#RGB (3-digit)",
  }),
  hex_rgba = cfg("hex.txt", { hex = { rgba = true } }, {
    label = "hex_rgba",
    description = "#RGBA (4-digit)",
  }),
  hex_rrggbb = cfg("hex.txt", { hex = { rrggbb = true } }, {
    label = "hex_rrggbb",
    description = "#RRGGBB (6-digit)",
  }),
  hex_rrggbbaa = cfg("hex.txt", { hex = { rrggbbaa = true } }, {
    label = "hex_rrggbbaa",
    description = "#RRGGBBAA (8-digit)",
  }),
  hex_hash_aarrggbb = cfg("hex.txt", { hex = { hash_aarrggbb = true } }, {
    label = "hex_hash_aarrggbb",
    description = "#AARRGGBB (QML 8-digit)",
  }),
  hex_0x_aarrggbb = cfg("hex.txt", { hex = { aarrggbb = true } }, {
    label = "hex_0x_aarrggbb",
    description = "0xAARRGGBB (prefix hex)",
  }),
  hex_no_hash = cfg("hex.txt", { hex = { no_hash = true } }, {
    label = "hex_no_hash",
    description = "RRGGBB without # prefix",
  }),

  -- ── CSS function group ───────────────────────────────────────────
  -- All share css.txt; each enables one function parser
  css_rgb = cfg("css.txt", { rgb = { enable = true } }, {
    label = "css_rgb",
    description = "rgb() / rgba() functions",
  }),
  css_hsl = cfg("css.txt", { hsl = { enable = true } }, {
    label = "css_hsl",
    description = "hsl() / hsla() functions",
  }),
  css_oklch = cfg("css.txt", { oklch = { enable = true } }, {
    label = "css_oklch",
    description = "oklch() function",
  }),
  css_hsluv = cfg("css.txt", { hsluv = { enable = true } }, {
    label = "css_hsluv",
    description = "hsluv() / hsluvu() functions",
  }),

  -- ── Names group ──────────────────────────────────────────────────
  -- All share names.txt; each enables one name variant
  names_lowercase = cfg("names.txt", {
    names = { enable = true, lowercase = true, camelcase = false, uppercase = false },
  }, {
    label = "names_lowercase",
    description = "lowercase named colors only",
  }),
  names_camelcase = cfg("names.txt", {
    names = { enable = true, lowercase = false, camelcase = true, uppercase = false },
  }, {
    label = "names_camelcase",
    description = "CamelCase named colors only",
  }),
  names_uppercase = cfg("names.txt", {
    names = { enable = true, lowercase = false, camelcase = false, uppercase = true },
  }, {
    label = "names_uppercase",
    description = "UPPERCASE named colors only",
  }),
  names_tailwind = cfg("names.txt", { tailwind = { enable = true } }, {
    label = "names_tailwind",
    description = "Tailwind CSS color names",
  }),

  -- ── Special group ────────────────────────────────────────────────
  -- All share special.txt; each enables one special parser
  special_xterm = cfg("special.txt", { xterm = { enable = true } }, {
    label = "special_xterm",
    description = "Xterm 256-color (#xN)",
  }),
  special_xcolor = cfg("special.txt", { xcolor = { enable = true } }, {
    label = "special_xcolor",
    description = "XColor blending (name!percent)",
  }),
  special_css_var_rgb = cfg("special.txt", { css_var_rgb = { enable = true } }, {
    label = "special_css_var_rgb",
    description = "CSS variable RGB (--var: r,g,b;)",
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
    },
  },
  {
    flag = "css",
    display = "CSS Functions",
    names = { "css_rgb", "css_hsl", "css_oklch", "css_hsluv" },
  },
  {
    flag = "names",
    display = "Named Colors",
    names = { "names_lowercase", "names_camelcase", "names_uppercase", "names_tailwind" },
  },
  {
    flag = "special",
    display = "Special Parsers",
    names = { "special_xterm", "special_xcolor", "special_css_var_rgb" },
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

  -- Minimal UI settings
  vim.o.termguicolors = true
  vim.o.cmdheight = 0
  vim.o.laststatus = 0
  vim.o.number = true
  vim.o.signcolumn = "no"
  vim.o.foldenable = false
  vim.o.fillchars = "eob: "

  -- Use built-in dark colorscheme
  vim.cmd.colorscheme("habamax")

  -- Setup colorizer
  require("colorizer").setup(c.setup_opts)

  -- Open the fixture file
  vim.cmd.edit(c.fixture)
end

return M
