---@mod colorizer.config Configuration
---@brief [[
---Provides configuration options and utilities for setting up colorizer.
---
---Colorizer supports two configuration formats:
---
---1. **New structured format** (recommended): Uses the `options` key with
---   logically grouped settings under `parsers`, `display`, and `hooks`.
---
---2. **Legacy flat format**: Uses the `user_default_options` key with flat
---   keys like `RGB`, `RRGGBB`, `rgb_fn`, `mode`, etc. This format is
---   automatically translated to the new format and will continue to work.
---
---NEW FORMAT EXAMPLE ~
---
--->lua
---  require("colorizer").setup({
---    options = {
---      parsers = {
---        css = true,  -- preset: enables names, hex, rgb, hsl, oklch
---        tailwind = { enable = true, mode = "normal" },
---      },
---      display = {
---        mode = "virtualtext",
---        virtualtext = { position = "after" },
---      },
---    },
---  })
---<
---
---LEGACY FORMAT EXAMPLE ~
---
--->lua
---  require("colorizer").setup({
---    user_default_options = {
---      css = true,
---      tailwind = "normal",
---      mode = "virtualtext",
---      virtualtext_inline = "after",
---    },
---  })
---<
---
---PRESETS ~
---
---  `parsers.css = true` enables: names, hex (all), rgb, hsl, oklch
---  `parsers.css_fn = true` enables: rgb, hsl, oklch
---
---  Individual settings always override presets:
--->lua
---  parsers = { css = true, rgb = { enable = false } }
---  -- rgb is disabled despite css preset
---<
---
---CUSTOM PARSERS ~
---
---  Register custom parsers via `parsers.custom`:
--->lua
---  parsers = {
---    custom = {
---      {
---        name = "my_parser",
---        prefixes = { "Color." },
---        parse = function(ctx)
---          -- return length, rgb_hex or nil
---        end,
---      },
---    },
---  }
---<
---
---@brief ]]
local M = {}

local utils = require("colorizer.utils")

--- Legacy defaults for colorizer options (old flat format)
local plugin_user_default_options = {
  names = true,
  names_opts = {
    lowercase = true,
    camelcase = true,
    uppercase = false,
    strip_digits = false,
  },
  names_custom = false,
  RGB = true,
  RGBA = true,
  RRGGBB = true,
  RRGGBBAA = false,
  AARRGGBB = false,
  rgb_fn = false,
  hsl_fn = false,
  oklch_fn = false,
  css = false,
  css_fn = false,
  tailwind = false,
  tailwind_opts = {
    update_names = false,
  },
  sass = { enable = false, parsers = { css = true } },
  xterm = false,
  mode = "background",
  virtualtext = "■",
  virtualtext_inline = false,
  virtualtext_mode = "foreground",
  always_update = false,
  hooks = {
    disable_line_highlight = false,
  },
}

--- Default options in the new structured format.
---
--- The `options` table is organized into logical groups:
--- - `parsers`: Which color formats to detect
--- - `display`: How to render detected colors
--- - `hooks`: Functions to customize behavior
--- - `always_update`: Whether to update unfocused buffers
---
---@class colorizer.NewOptions
---@field parsers colorizer.ParsersOptions Parser configuration
---@field display colorizer.DisplayOptions Display configuration
---@field hooks colorizer.Hooks Hook functions
---@field always_update boolean Update color values even if buffer is not focused

---@class colorizer.ParsersOptions
---@field css boolean Preset: enables names, hex (all), rgb, hsl, oklch. Individual settings override.
---@field css_fn boolean Preset: enables rgb, hsl, oklch. Individual settings override.
---@field names colorizer.ParsersNames Named color options
---@field hex colorizer.ParsersHex Hex color options
---@field rgb colorizer.ParsersSimple rgb()/rgba() function parser
---@field hsl colorizer.ParsersSimple hsl()/hsla() function parser
---@field oklch colorizer.ParsersSimple oklch() function parser
---@field tailwind colorizer.ParsersTailwind Tailwind CSS color options
---@field sass colorizer.ParsersSass Sass variable color options
---@field xterm colorizer.ParsersSimple xterm 256-color code parser
---@field custom colorizer.CustomParserDef[] List of custom parser definitions

---@class colorizer.ParsersNames
---@field enable boolean Enable named colors (e.g. "Blue", "red")
---@field lowercase boolean Match lowercase names (e.g. "blue")
---@field camelcase boolean Match camelCase names (e.g. "LightBlue")
---@field uppercase boolean Match UPPERCASE names (e.g. "BLUE")
---@field strip_digits boolean Ignore names with digits (e.g. skip "blue3")
---@field custom table|function|false Custom name-to-RGB mappings. Table of `{name = "#rrggbb"}` or function returning one.

---@class colorizer.ParsersHex
---@field enable boolean Master switch for all hex formats
---@field rgb boolean #RGB (3-digit)
---@field rgba boolean #RGBA (4-digit)
---@field rrggbb boolean #RRGGBB (6-digit)
---@field rrggbbaa boolean #RRGGBBAA (8-digit)
---@field aarrggbb boolean 0xAARRGGBB

---@class colorizer.ParsersSimple
---@field enable boolean Enable this parser

---@class colorizer.ParsersTailwind
---@field enable boolean Enable Tailwind CSS colors
---@field mode 'normal'|'lsp'|'both' "normal" parses names, "lsp" uses LSP, "both" combines
---@field update_names boolean Update tailwind_names color mapping from LSP results

---@class colorizer.ParsersSass
---@field enable boolean Enable Sass color variable parsing
---@field parsers table Parsers for sass color values (e.g. `{ css = true }`)
---@field variable_pattern string Lua pattern for matching sass variable names (default "^%$([%w_-]+)")

---@class colorizer.DisplayOptions
---@field mode 'background'|'foreground'|'virtualtext' How to display detected colors
---@field background colorizer.DisplayBackground Background mode settings
---@field virtualtext colorizer.DisplayVirtualtext Virtual text display settings
---@field priority colorizer.DisplayPriority Extmark priority settings

---@class colorizer.DisplayBackground
---@field bright_fg string Foreground color for bright backgrounds (default "#000000")
---@field dark_fg string Foreground color for dark backgrounds (default "#ffffff")

---@class colorizer.DisplayVirtualtext
---@field char string Character used for virtual text (default "■")
---@field position false|'before'|'after' Inline virtualtext position. `false` for end-of-line.
---@field hl_mode 'background'|'foreground' Highlight mode for virtual text

---@class colorizer.DisplayPriority
---@field default number Extmark priority for normal highlights (default 200)
---@field lsp number Extmark priority for LSP/Tailwind highlights (default 300)
-- Build default parsers from registry + hardcoded entries
local registry = require("colorizer.parser.registry")
-- Ensure all parsers are loaded so their specs are registered
require("colorizer.parser")

local function build_default_parsers()
  local parsers = registry.config_defaults()

  -- Hardcoded entries not derived from registry
  parsers.css = false
  parsers.css_fn = false
  parsers.hex = {
    enable = false,
    rgb = true,
    rgba = true,
    rrggbb = true,
    rrggbbaa = false,
    aarrggbb = false,
  }
  parsers.tailwind = {
    enable = false,
    mode = "normal",
    update_names = false,
  }
  parsers.custom = {}

  return parsers
end

local default_options = {
  parsers = build_default_parsers(),

  display = {
    mode = "background",
    background = {
      bright_fg = "#000000",
      dark_fg = "#ffffff",
    },
    virtualtext = {
      char = "■",
      position = false,
      hl_mode = "foreground",
    },
    priority = {
      default = 200,
      lsp = 300,
    },
  },

  hooks = {
    disable_line_highlight = false,
  },

  always_update = false,
}

--- Expose default_options for external use
M.default_options = default_options

--- Default user options for colorizer.
---
--- This table defines individual options and alias options, allowing configuration of
--- colorizer's behavior for different color formats (e.g., `#RGB`, `#RRGGBB`, `#AARRGGBB`, etc.).
---
--- Individual Options: Options like `names`, `RGB`, `RRGGBB`, `RRGGBBAA`, `hsl_fn`, `rgb_fn`,
--- `oklch_fn`, `AARRGGBB`, `tailwind`, and `sass` can be enabled or disabled independently.
---
--- Alias Options: `css` and `css_fn` enable multiple options at once.
---   - `css_fn = true` enables `hsl_fn`, `rgb_fn`, and `oklch_fn`.
---   - `css = true` enables `names`, `RGB`, `RRGGBB`, `RRGGBBAA`, `hsl_fn`, `rgb_fn`, and `oklch_fn`.
---
--- Option Priority: Individual options have higher priority than aliases.
--- If both `css` and `css_fn` are true, `css_fn` has more priority over `css`.
---@class colorizer.UserDefaultOptions
---@field names boolean Enables named colors (e.g., "Blue").
---@field names_opts colorizer.NamesOpts Names options for customizing casing, digit stripping, etc
---@field names_custom table|function|false Custom color name to RGB value mappings. Should return a table of color names to RGB value pairs.
---@field RGB boolean Enables `#RGB` hex codes.
---@field RGBA boolean Enables `#RGBA` hex codes.
---@field RRGGBB boolean Enables `#RRGGBB` hex codes.
---@field RRGGBBAA boolean Enables `#RRGGBBAA` hex codes.
---@field AARRGGBB boolean Enables `0xAARRGGBB` hex codes.
---@field rgb_fn boolean Enables CSS `rgb()` and `rgba()` functions.
---@field hsl_fn boolean Enables CSS `hsl()` and `hsla()` functions.
---@field oklch_fn boolean Enables CSS `oklch()` function.
---@field css boolean Enables all CSS features (`rgb_fn`, `hsl_fn`, `oklch_fn`, `names`, `RGB`, `RRGGBB`).
---@field css_fn boolean Enables all CSS functions (`rgb_fn`, `hsl_fn`, `oklch_fn`).
---@field tailwind boolean|string Enables Tailwind CSS colors (e.g., `"normal"`, `"lsp"`, `"both"`).
---@field tailwind_opts colorizer.TailwindOpts Tailwind options for updating names cache, etc
---@field sass colorizer.SassOpts Sass color configuration (`enable` flag and `parsers`).
---@field mode 'background'|'foreground'|'virtualtext' Display mode
---@field virtualtext string Character used for virtual text display.
---@field virtualtext_inline boolean|'before'|'after' Shows virtual text inline with color.
---@field virtualtext_mode 'background'|'foreground' Mode for virtual text display.
---@field always_update boolean Always update color values, even if buffer is not focused.
---@field hooks colorizer.Hooks Table of hook functions
---@field xterm boolean Enables xterm 256-color codes (#xNN, \e[38;5;NNNm)

---@class colorizer.NamesOpts
---@field lowercase boolean Converts color names to lowercase.
---@field camelcase boolean Converts color names to camelCase.
---@field uppercase boolean Converts color names to uppercase.
---@field strip_digits boolean Removes digits from color names.

---@class colorizer.TailwindOpts
---@field update_names boolean Updates Tailwind "normal" names cache from LSP results.

---@class colorizer.SassOpts
---@field enable boolean Enables Sass color parsing.
---@field parsers table A list of parsers to use, typically includes "css".

---@class colorizer.Hooks
---@field disable_line_highlight function|false Returns boolean which controls if line should be parsed for highlights.

---@class colorizer.CustomParserDef
---@field name string unique identifier
---@field prefixes? string[] trie prefixes, e.g. {"color("}
---@field prefix_bytes? number[] raw byte triggers, e.g. {0x23} for '#'
---@field parse fun(ctx: colorizer.ParserContext): (number?, string?)
---@field setup? fun(ctx: colorizer.ParserContext) called once per buffer attach
---@field teardown? fun(ctx: colorizer.ParserContext) called on buffer detach
---@field state_factory? fun(): table returns initial per-buffer state

---@class colorizer.ParserContext
---@field line string current line text
---@field col number 1-indexed column position
---@field bufnr number
---@field line_nr number 0-indexed line number
---@field opts table full resolved options for this buffer
---@field parser_opts table this parser's config subtable
---@field state table per-buffer persistent state

--- Options for colorizer that were passed in to setup function.
--- After setup(), `M.options.options` holds the canonical new-format config.
--- `M.options.user_default_options` holds a backward-compatible flat view.
---@class colorizer.Options
---@field filetypes table File types to highlight
---@field buftypes table Buffer types to highlight
---@field user_commands boolean|table User commands to enable
---@field lazy_load boolean Lazily schedule buffer highlighting
---@field user_default_options colorizer.UserDefaultOptions Legacy flat options (backward compat)
---@field options colorizer.NewOptions Canonical structured options
---@field exclusions table Excluded filetypes/buftypes
---@field all table Whether all filetypes/buftypes are enabled
M.options = {}
local function init_options()
  M.options = {
    -- setup options
    filetypes = { "*" },
    buftypes = {},
    user_commands = true,
    lazy_load = false,
    user_default_options = plugin_user_default_options,
    options = vim.deepcopy(default_options),
    -- shortcuts for filetype, buftype inclusion, exclusion settings
    exclusions = { buftype = {}, filetype = {} },
    all = { buftype = false, filetype = false },
  }
end

local options_cache
--- Reset the cache for buffer options.
-- Called from colorizer.setup
local function init_cache()
  options_cache = { buftype = {}, filetype = {} }
end

local function init_config()
  init_options()
  init_cache()
end
do
  init_config()
end

-- Keys that indicate legacy (old flat) format
local legacy_keys = {
  "RGB", "RGBA", "RRGGBB", "RRGGBBAA", "AARRGGBB",
  "rgb_fn", "hsl_fn", "oklch_fn",
  "names", "names_opts", "names_custom",
  "css", "css_fn",
  "tailwind", "tailwind_opts",
  "sass", "xterm",
  "mode", "virtualtext", "virtualtext_inline", "virtualtext_mode",
  "always_update",
}

--- Detect if options are in legacy (old flat) format.
---@param opts table Options to check
---@return boolean true if options appear to be in legacy format
function M.is_legacy_options(opts)
  if not opts then
    return false
  end
  for _, key in ipairs(legacy_keys) do
    if opts[key] ~= nil then
      return true
    end
  end
  return false
end

--- Translate legacy flat options to new structured format.
-- Returns a partial new-format table containing only the values present in old_opts.
---@param old_opts table Legacy flat options
---@return table Partial new-format options
function M.translate_options(old_opts)
  local new = { parsers = {} }

  -- parsers.names
  if old_opts.names ~= nil or old_opts.names_opts or old_opts.names_custom ~= nil or old_opts.names_custom_hashed then
    new.parsers.names = {}
    if old_opts.names ~= nil then
      new.parsers.names.enable = old_opts.names
    end
    if old_opts.names_opts then
      for k, v in pairs(old_opts.names_opts) do
        new.parsers.names[k] = v
      end
    end
    if old_opts.names_custom ~= nil then
      new.parsers.names.custom = old_opts.names_custom
    end
    -- Preserve pre-computed hash from validate_options()
    if old_opts.names_custom_hashed then
      new.parsers.names.custom_hashed = old_opts.names_custom_hashed
    end
  end

  -- parsers.hex
  local hex_keys = { RGB = "rgb", RGBA = "rgba", RRGGBB = "rrggbb", RRGGBBAA = "rrggbbaa", AARRGGBB = "aarrggbb" }
  local has_hex = false
  for old_key, new_key in pairs(hex_keys) do
    if old_opts[old_key] ~= nil then
      new.parsers.hex = new.parsers.hex or {}
      new.parsers.hex[new_key] = old_opts[old_key]
      if old_opts[old_key] then
        has_hex = true
      end
    end
  end
  if has_hex then
    new.parsers.hex = new.parsers.hex or {}
    if new.parsers.hex.enable == nil then
      new.parsers.hex.enable = true
    end
  end

  -- parsers.rgb/hsl/oklch
  if old_opts.rgb_fn ~= nil then
    new.parsers.rgb = { enable = old_opts.rgb_fn }
  end
  if old_opts.hsl_fn ~= nil then
    new.parsers.hsl = { enable = old_opts.hsl_fn }
  end
  if old_opts.oklch_fn ~= nil then
    new.parsers.oklch = { enable = old_opts.oklch_fn }
  end

  -- Presets
  if old_opts.css ~= nil then
    new.parsers.css = old_opts.css
  end
  if old_opts.css_fn ~= nil then
    new.parsers.css_fn = old_opts.css_fn
  end

  -- Tailwind
  if old_opts.tailwind ~= nil then
    new.parsers.tailwind = {}
    if old_opts.tailwind == false then
      new.parsers.tailwind.enable = false
    elseif old_opts.tailwind == true then
      new.parsers.tailwind.enable = true
      new.parsers.tailwind.mode = "normal"
    elseif type(old_opts.tailwind) == "string" then
      new.parsers.tailwind.enable = true
      new.parsers.tailwind.mode = old_opts.tailwind
    end
  end
  if old_opts.tailwind_opts then
    new.parsers.tailwind = new.parsers.tailwind or {}
    if old_opts.tailwind_opts.update_names ~= nil then
      new.parsers.tailwind.update_names = old_opts.tailwind_opts.update_names
    end
  end

  -- Sass
  if old_opts.sass then
    new.parsers.sass = {}
    if old_opts.sass.enable ~= nil then
      new.parsers.sass.enable = old_opts.sass.enable
    end
    if old_opts.sass.parsers ~= nil then
      new.parsers.sass.parsers = old_opts.sass.parsers
    end
  end

  -- Xterm
  if old_opts.xterm ~= nil then
    new.parsers.xterm = { enable = old_opts.xterm }
  end

  -- Display
  if old_opts.mode ~= nil or old_opts.virtualtext ~= nil
      or old_opts.virtualtext_inline ~= nil or old_opts.virtualtext_mode ~= nil then
    new.display = {}
    if old_opts.mode ~= nil then
      new.display.mode = old_opts.mode
    end
    if old_opts.virtualtext ~= nil or old_opts.virtualtext_inline ~= nil or old_opts.virtualtext_mode ~= nil then
      new.display.virtualtext = {}
      if old_opts.virtualtext ~= nil then
        new.display.virtualtext.char = old_opts.virtualtext
      end
      if old_opts.virtualtext_inline ~= nil then
        if old_opts.virtualtext_inline == true then
          new.display.virtualtext.position = "after"
        elseif old_opts.virtualtext_inline == "before" then
          new.display.virtualtext.position = "before"
        elseif old_opts.virtualtext_inline == "after" then
          new.display.virtualtext.position = "after"
        else
          new.display.virtualtext.position = false
        end
      end
      if old_opts.virtualtext_mode ~= nil then
        new.display.virtualtext.hl_mode = old_opts.virtualtext_mode
      end
    end
  end

  -- Hooks
  if old_opts.hooks then
    new.hooks = {}
    for k, v in pairs(old_opts.hooks) do
      new.hooks[k] = v
    end
  end

  -- Always update
  if old_opts.always_update ~= nil then
    new.always_update = old_opts.always_update
  end

  return new
end

--- Translate old polymorphic filetypes/buftypes format to new structured format.
---@param old_ft table Old format filetypes/buftypes
---@return table New format { enable, exclude, overrides }
function M.translate_filetypes(old_ft)
  if not old_ft then
    return { enable = {}, exclude = {}, overrides = {} }
  end

  -- Already new format
  if old_ft.enable or old_ft.exclude or old_ft.overrides then
    -- Fill in missing keys
    old_ft.enable = old_ft.enable or {}
    old_ft.exclude = old_ft.exclude or {}
    old_ft.overrides = old_ft.overrides or {}
    return old_ft
  end

  -- Check if it's a plain list (all numeric keys, all strings)
  local is_plain_list = true
  for k, v in pairs(old_ft) do
    if type(k) ~= "number" then
      is_plain_list = false
      break
    end
    if type(v) ~= "string" then
      is_plain_list = false
      break
    end
  end

  -- Plain list without "!" entries: shorthand for { enable = {...} }
  if is_plain_list then
    local has_exclusions = false
    for _, v in ipairs(old_ft) do
      if v:sub(1, 1) == "!" then
        has_exclusions = true
        break
      end
    end
    if not has_exclusions then
      return { enable = old_ft, exclude = {}, overrides = {} }
    end
  end

  -- Mixed format: strings go to enable/exclude, tables go to overrides
  local new = { enable = {}, exclude = {}, overrides = {} }
  for k, v in pairs(old_ft) do
    if type(k) == "number" then
      if type(v) == "string" then
        if v:sub(1, 1) == "!" then
          table.insert(new.exclude, v:sub(2))
        else
          table.insert(new.enable, v)
        end
      end
    elseif type(k) == "string" then
      if type(v) == "table" then
        new.overrides[k] = M.translate_options(v)
      end
    end
  end

  return new
end

--- Apply preset expansions to user-provided parsers config.
-- Expands css/css_fn presets into individual parser enables, but only
-- for parsers that the user hasn't explicitly configured.
-- Operates on the user's raw options BEFORE merging with defaults.
---@param user_parsers table|nil The user's raw parsers config
function M.apply_presets(user_parsers)
  if not user_parsers then
    return
  end

  -- Helper: set enable=true for a parser key if user hasn't explicitly configured it
  local function preset_enable(key)
    local v = user_parsers[key]
    if not v then
      user_parsers[key] = { enable = true }
    elseif type(v) == "table" and v.enable == nil then
      v.enable = true
    elseif type(v) ~= "table" then
      -- Boolean shorthand (e.g. from legacy sass parsers): convert to table
      user_parsers[key] = { enable = v and true or false }
    end
  end

  -- css preset: enables names, hex (all), rgb, hsl, oklch
  if user_parsers.css then
    preset_enable("names")
    preset_enable("hex")
    preset_enable("rgb")
    preset_enable("hsl")
    preset_enable("oklch")
  end

  -- css_fn preset: enables rgb, hsl, oklch
  if user_parsers.css_fn then
    preset_enable("rgb")
    preset_enable("hsl")
    preset_enable("oklch")
  end

  -- Remove preset keys after expansion
  user_parsers.css = nil
  user_parsers.css_fn = nil
end

--- Validate new-format options. Validates enums, processes names.custom, checks hook types.
---@param opts table New-format options (fully merged with defaults)
function M.validate_new_options(opts)
  -- Validate display.mode enum
  local valid_modes = { background = true, foreground = true, virtualtext = true }
  if not valid_modes[opts.display.mode] then
    opts.display.mode = default_options.display.mode
  end

  -- Validate tailwind.mode enum
  local valid_tw_modes = { normal = true, lsp = true, both = true }
  if opts.parsers.tailwind.enable and not valid_tw_modes[opts.parsers.tailwind.mode] then
    opts.parsers.tailwind.mode = default_options.parsers.tailwind.mode
  end

  -- Validate virtualtext.position
  local valid_vt_pos = { ["before"] = true, ["after"] = true, [false] = true }
  if not valid_vt_pos[opts.display.virtualtext.position] then
    opts.display.virtualtext.position = default_options.display.virtualtext.position
  end

  -- Validate virtualtext.hl_mode
  local valid_vt_mode = { background = true, foreground = true }
  if not valid_vt_mode[opts.display.virtualtext.hl_mode] then
    opts.display.virtualtext.hl_mode = default_options.display.virtualtext.hl_mode
  end

  -- Process names.custom (function -> table, compute hash)
  local custom = opts.parsers.names.custom
  if custom and type(custom) == "table" and not next(custom) then
    opts.parsers.names.custom = false
    custom = false
  end
  if custom then
    if type(custom) == "function" then
      local status, names = pcall(custom)
      if not (status and type(names) == "table") then
        error(string.format("Error in parsers.names.custom function: %s", names or "Invalid return value"))
      end
      custom = names
    end
    if type(custom) ~= "table" then
      error(string.format("Error in parsers.names.custom: %s", vim.inspect(custom)))
    end
    opts.parsers.names.custom_hashed = {
      hash = utils.hash_table(custom),
      names = custom,
    }
    opts.parsers.names.custom = false
  end

  -- Validate hooks
  if opts.hooks then
    if type(opts.hooks.disable_line_highlight) ~= "function" then
      opts.hooks.disable_line_highlight = false
    end
  end

  -- Validate custom parsers
  if opts.parsers.custom then
    for i, parser_def in ipairs(opts.parsers.custom) do
      if type(parser_def) ~= "table" or not parser_def.name or type(parser_def.parse) ~= "function" then
        error(string.format("Invalid custom parser at index %d: must have 'name' and 'parse' function", i))
      end
    end
  end
end

--- Convert new-format options back to legacy flat format.
-- Used for backward compatibility with code that hasn't been updated yet.
---@param opts table New-format options
---@return table Legacy flat options
function M.as_flat(opts)
  local flat = {}
  local p = opts.parsers
  local d = opts.display

  -- Names
  flat.names = p.names.enable
  flat.names_opts = {
    lowercase = p.names.lowercase,
    camelcase = p.names.camelcase,
    uppercase = p.names.uppercase,
    strip_digits = p.names.strip_digits,
  }
  flat.names_custom = p.names.custom
  flat.names_custom_hashed = p.names.custom_hashed or false

  -- Hex: AND enable with individual flags
  flat.RGB = p.hex.enable and p.hex.rgb or false
  flat.RGBA = p.hex.enable and p.hex.rgba or false
  flat.RRGGBB = p.hex.enable and p.hex.rrggbb or false
  flat.RRGGBBAA = p.hex.enable and p.hex.rrggbbaa or false
  flat.AARRGGBB = p.hex.enable and p.hex.aarrggbb or false

  -- CSS functions
  flat.rgb_fn = p.rgb.enable
  flat.hsl_fn = p.hsl.enable
  flat.oklch_fn = p.oklch.enable

  -- Presets (already expanded)
  flat.css = false
  flat.css_fn = false

  -- Tailwind
  if p.tailwind.enable then
    flat.tailwind = p.tailwind.mode
  else
    flat.tailwind = false
  end
  flat.tailwind_opts = {
    update_names = p.tailwind.update_names,
  }

  -- Sass
  flat.sass = {
    enable = p.sass.enable,
    parsers = p.sass.parsers,
  }

  -- Xterm
  flat.xterm = p.xterm.enable

  -- Display
  flat.mode = d.mode
  flat.virtualtext = d.virtualtext.char
  if d.virtualtext.position then
    flat.virtualtext_inline = d.virtualtext.position
  else
    flat.virtualtext_inline = false
  end
  flat.virtualtext_mode = d.virtualtext.hl_mode

  -- Hooks
  flat.hooks = opts.hooks and vim.deepcopy(opts.hooks) or { disable_line_highlight = false }

  -- Always update
  flat.always_update = opts.always_update

  return flat
end

--- Resolve options from any format to canonical new format.
-- Accepts new-format options, legacy flat options, or nil (returns defaults).
-- Applies presets and validation.
---@param opts table|nil Options in any format
---@param user_opts table|nil The raw user-provided options (before merge), for preset priority
---@return table Canonical new-format options
function M.resolve_options(opts, user_opts)
  if not opts then
    return vim.deepcopy(default_options)
  end

  -- Already new format (has parsers key)
  if opts.parsers then
    local user_parsers = user_opts and user_opts.parsers or opts.parsers
    M.apply_presets(user_parsers)
    local merged = vim.tbl_deep_extend("force", vim.deepcopy(default_options), opts)
    M.validate_new_options(merged)
    return merged
  end

  -- Legacy flat format: translate, apply presets, merge, validate
  if M.is_legacy_options(opts) then
    local translated = M.translate_options(opts)
    M.apply_presets(translated.parsers)
    local merged = vim.tbl_deep_extend("force", vim.deepcopy(default_options), translated)
    M.validate_new_options(merged)
    return merged
  end

  return vim.deepcopy(default_options)
end

--- Build a new-format options table for sass color parsing.
-- Expands sass.parsers presets into a full options table suitable for matcher.make().
---@param sass_parsers table Sass parsers config (e.g. { css = true })
---@return table New-format options for the sass color parser
function M.expand_sass_parsers(sass_parsers)
  if not sass_parsers then
    return vim.deepcopy(default_options)
  end
  -- sass_parsers is like { css = true } - treat as preset-style config
  local user_parsers = vim.deepcopy(sass_parsers)
  M.apply_presets(user_parsers)

  -- Build a full parsers table from the expanded config
  local parsers = vim.deepcopy(default_options.parsers)
  for k, v in pairs(user_parsers) do
    if type(v) == "boolean" and parsers[k] then
      if type(parsers[k]) == "table" then
        parsers[k].enable = v
      end
    elseif type(v) == "table" and parsers[k] then
      parsers[k] = vim.tbl_deep_extend("force", parsers[k], v)
    end
  end

  local opts = vim.deepcopy(default_options)
  opts.parsers = parsers
  return opts
end

--- Validate user options and set defaults (legacy format).
---@param opts table Legacy flat options to validate in-place
local function validate_options(opts)
  -- Set true value to it's "name"
  if opts.tailwind == true then
    opts.tailwind = "normal"
  end
  if opts.virtualtext_inline == true then
    opts.virtualtext_inline = "after"
  end
  -- Set default if value is invalid
  if opts.tailwind ~= "normal" and opts.tailwind ~= "both" and opts.tailwind ~= "lsp" then
    opts.tailwind = plugin_user_default_options.tailwind
  end
  if opts.virtualtext_inline ~= "before" and opts.virtualtext_inline ~= "after" then
    opts.virtualtext_inline = plugin_user_default_options.virtualtext_inline
  end
  if
    opts.mode ~= "background"
    and opts.mode ~= "foreground"
    and opts.mode ~= "virtualtext"
  then
    opts.mode = plugin_user_default_options.mode
  end
  if opts.virtualtext_mode ~= "background" and opts.virtualtext_mode ~= "foreground" then
    opts.virtualtext_mode = plugin_user_default_options.virtualtext_mode
  end
  -- Set names_custom to false if it's an empty table
  if
    opts.names_custom
    and type(opts.names_custom) == "table"
    and not next(opts.names_custom)
  then
    opts.names_custom = false
  end
  -- Extract table if names_custom is a function
  if opts.names_custom then
    if type(opts.names_custom) == "function" then
      local status, names = pcall(opts.names_custom)
      if not (status and type(names) == "table") then
        error(string.format("Error in names_custom function: %s", names or "Invalid return value"))
      end
      opts.names_custom = names
    end
    if type(opts.names_custom) ~= "table" then
      error(string.format("Error in names_custom table: %s", vim.inspect(opts.names_custom)))
    end
    -- Calculate hash to be used as key in names parser color_map
    -- Use a new key (names_custom_hashed) in case `hash` or `names` were defined as custom colors
    -- Make sure this key is checked in matcher and not `names_custom`
    opts.names_custom_hashed = {
      hash = utils.hash_table(opts.names_custom),
      names = opts.names_custom,
    }
    opts.names_custom = false
  end
  if opts.hooks then
    if type(opts.hooks.disable_line_highlight) ~= "function" then
      opts.hooks.disable_line_highlight = false
    end
  end
end

--- Set options for a specific buffer or file type.
---@param bo_type 'buftype'|'filetype' The type of buffer option
---@param val string The specific value to set.
---@param opts table New-format options
function M.set_bo_value(bo_type, val, opts)
  options_cache[bo_type][val] = opts
end

--- Parse and apply alias options to the user options (legacy format).
---@param ud_opts table user_default_options
---@return table
function M.apply_alias_options(ud_opts)
  local aliases = {
    --  TODO: 2024-12-24 - Should aliases be configurable?
    ["css"] = { "names", "RGB", "RGBA", "RRGGBB", "RRGGBBAA", "hsl_fn", "rgb_fn", "oklch_fn" },
    ["css_fn"] = { "hsl_fn", "rgb_fn", "oklch_fn" },
  }
  local function handle_alias(name, opts)
    if not aliases[name] then
      return
    end
    for _, option in ipairs(aliases[name]) do
      if opts[option] == nil then
        opts[option] = ud_opts[name]
      end
    end
  end

  for alias, _ in pairs(aliases) do
    handle_alias(alias, ud_opts)
  end
  if ud_opts.sass and ud_opts.sass.enable then
    for child, _ in pairs(ud_opts.sass.parsers) do
      handle_alias(child, ud_opts.sass.parsers)
    end
  end

  ud_opts = vim.tbl_deep_extend("force", M.options.user_default_options, ud_opts)
  validate_options(ud_opts)
  return ud_opts
end

--- Configuration options for the `setup` function.
--- Use `options` (new format) or `user_default_options` (legacy format), not both.
---@class colorizer.SetupOptions
---@field filetypes table|nil File types to highlight. Use `"*"` for all. Supports `"!name"` exclusions and `name = {opts}` overrides.
---@field buftypes table|nil Buffer types to highlight. Same format as filetypes.
---@field options colorizer.NewOptions|nil Structured options (recommended). See |colorizer.NewOptions|.
---@field user_default_options colorizer.UserDefaultOptions|nil Legacy flat options. Deprecated in favor of `options`.
---@field user_commands boolean|table Enable all or specific user commands.
---@field lazy_load boolean Lazily schedule buffer highlighting setup function.

--- Initializes colorizer with user-provided options.
-- Merges default settings with any user-specified options, setting up `filetypes`,
-- `user_default_options`, and `user_commands`.
-- Accepts both new `options` key and legacy `user_default_options` key.
---@param opts table|nil Configuration options for colorizer.
---@return table Final settings after merging user and default options.
function M.get_setup_options(opts)
  init_config()
  opts = opts or {}

  if opts.options then
    -- New format path
    local user_options = vim.deepcopy(opts.options)
    M.apply_presets(user_options.parsers)
    local merged = vim.tbl_deep_extend("force", vim.deepcopy(default_options), user_options)
    M.validate_new_options(merged)
    M.options.options = merged
    -- Compute backward-compat flat view
    M.options.user_default_options = M.as_flat(merged)
  else
    -- Legacy format path (or no options)
    local raw_ud = opts.user_default_options or vim.deepcopy(plugin_user_default_options)
    -- Translate to new format
    local translated = M.translate_options(raw_ud)
    M.apply_presets(translated.parsers)
    local merged = vim.tbl_deep_extend("force", vim.deepcopy(default_options), translated)
    M.validate_new_options(merged)
    M.options.options = merged
    -- Also keep legacy flat format (apply aliases + validate)
    opts.user_default_options = M.apply_alias_options(raw_ud)
    M.options.user_default_options = opts.user_default_options
  end

  -- Handle filetypes/buftypes: translate to new format if needed
  if opts.filetypes then
    M.options.filetypes = opts.filetypes
  end
  if opts.buftypes then
    M.options.buftypes = opts.buftypes
  end
  if opts.user_commands ~= nil then
    M.options.user_commands = opts.user_commands
  end
  if opts.lazy_load ~= nil then
    M.options.lazy_load = opts.lazy_load
  end

  return M.options
end

--- Retrieve buffer-specific options or default options for a buffer.
---@param bufnr number The buffer number.
---@param bo_type 'buftype'|'filetype' The type of buffer option
---@return table New-format options
function M.new_bo_options(bufnr, bo_type)
  local value = vim.api.nvim_get_option_value(bo_type, { buf = bufnr })
  return options_cache[bo_type][value] or M.options.options
end

--- Retrieve options based on buffer type and file type. Prefer filetype.
---@param bo_type 'buftype'|'filetype' The type of buffer option
---@param buftype string Buffer type.
---@param filetype string File type.
---@return table|nil
function M.get_bo_options(bo_type, buftype, filetype)
  local fo, bo = options_cache[bo_type][filetype], options_cache[bo_type][buftype]
  return fo or bo
end

return M
