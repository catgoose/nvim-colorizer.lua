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
local function cfg(fixture, parsers)
  return {
    setup_opts = { options = { parsers = parsers } },
    fixture = fixtures_dir .. "/" .. fixture,
  }
end

--- All screenshot configurations.
M.configs = {
  -- ── Default showcase ─────────────────────────────────────────────
  default = cfg("default.txt", { css = true }),

  -- ── Hex group ────────────────────────────────────────────────────
  -- All share hex.txt; each enables one hex format
  hex_rgb = cfg("hex.txt", { hex = { rgb = true } }),
  hex_rgba = cfg("hex.txt", { hex = { rgba = true } }),
  hex_rrggbb = cfg("hex.txt", { hex = { rrggbb = true } }),
  hex_rrggbbaa = cfg("hex.txt", { hex = { rrggbbaa = true } }),
  hex_hash_aarrggbb = cfg("hex.txt", { hex = { hash_aarrggbb = true } }),
  hex_0x_aarrggbb = cfg("hex.txt", { hex = { aarrggbb = true } }),
  hex_no_hash = cfg("hex.txt", { hex = { no_hash = true } }),

  -- ── CSS function group ───────────────────────────────────────────
  -- All share css.txt; each enables one function parser
  css_rgb = cfg("css.txt", { rgb = { enable = true } }),
  css_hsl = cfg("css.txt", { hsl = { enable = true } }),
  css_oklch = cfg("css.txt", { oklch = { enable = true } }),
  css_hsluv = cfg("css.txt", { hsluv = { enable = true } }),

  -- ── Names group ──────────────────────────────────────────────────
  -- All share names.txt; each enables one name variant
  names_lowercase = cfg("names.txt", {
    names = { enable = true, lowercase = true, camelcase = false, uppercase = false },
  }),
  names_camelcase = cfg("names.txt", {
    names = { enable = true, lowercase = false, camelcase = true, uppercase = false },
  }),
  names_uppercase = cfg("names.txt", {
    names = { enable = true, lowercase = false, camelcase = false, uppercase = true },
  }),
  names_tailwind = cfg("names.txt", { tailwind = { enable = true } }),

  -- ── Special group ────────────────────────────────────────────────
  -- All share special.txt; each enables one special parser
  special_xterm = cfg("special.txt", { xterm = { enable = true } }),
  special_xcolor = cfg("special.txt", { xcolor = { enable = true } }),
  special_css_var_rgb = cfg("special.txt", { css_var_rgb = { enable = true } }),
}

--- Ordered categories for --list, iteration, and --<flag> filtering.
M.categories = {
  {
    flag = "default",
    display = "Default",
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
