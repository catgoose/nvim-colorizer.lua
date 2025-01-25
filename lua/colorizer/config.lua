--- Provides configuration options and utilities for setting up colorizer.
-- @module colorizer.config
local M = {}

local utils = require("colorizer.utils")

--- Defaults for colorizer options
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
  css = false,
  css_fn = false,
  tailwind = false,
  tailwind_opts = {
    update_names = false,
  },
  sass = { enable = false, parsers = { css = true } },
  mode = "background",
  virtualtext = "■",
  virtualtext_inline = false,
  virtualtext_mode = "foreground",
  always_update = false,
  hooks = {
    disable_line_highlight = false,
  },
}

--[[-- Default user options for colorizer.
This table defines individual options and alias options, allowing configuration of
colorizer's behavior for different color formats (e.g., `#RGB`, `#RRGGBB`, `#AARRGGBB`, etc.).

Individual Options: Options like `names`, `RGB`, `RRGGBB`, `RRGGBBAA`, `hsl_fn`, `rgb_fn`,
`AARRGGBB`, `tailwind`, and `sass` can be enabled or disabled independently.

Alias Options: `css` and `css_fn` enable multiple options at once.
  - `css_fn = true` enables `hsl_fn` and `rgb_fn`.
  - `css = true` enables `names`, `RGB`, `RRGGBB`, `RRGGBBAA`, `hsl_fn`, and `rgb_fn`.

Option Priority: Individual options have higher priority than aliases.
If both `css` and `css_fn` are true, `css_fn` has more priority over `css`.
]]
-- @table user_default_options
-- @field names boolean: Enables named colors (e.g., "Blue").
-- @field names_opts table: Names options for customizing casing, digit stripping, etc
-- @field names_custom table|function|false: Custom color name to RGB value mappings
-- should return a table of color names to RGB value pairs
-- @field RGB boolean: Enables `#RGB` hex codes.
-- @field RGBA boolean: Enables `#RGBA` hex codes.
-- @field RRGGBB boolean: Enables `#RRGGBB` hex codes.
-- @field RRGGBBAA boolean: Enables `#RRGGBBAA` hex codes.
-- @field AARRGGBB boolean: Enables `0xAARRGGBB` hex codes.
-- @field rgb_fn boolean: Enables CSS `rgb()` and `rgba()` functions.
-- @field hsl_fn boolean: Enables CSS `hsl()` and `hsla()` functions.
-- @field css boolean: Enables all CSS features (`rgb_fn`, `hsl_fn`, `names`, `RGB`, `RRGGBB`).
-- @field css_fn boolean: Enables all CSS functions (`rgb_fn`, `hsl_fn`).
-- @field tailwind boolean|string: Enables Tailwind CSS colors (e.g., `"normal"`, `"lsp"`, `"both"`).
-- @field tailwind_opts table: Tailwind options for updating names cache, etc
-- @field sass table: Sass color configuration (`enable` flag and `parsers`).
-- @field mode 'background'|'foreground'|'virtualtext': Display mode
-- @field virtualtext string: Character used for virtual text display.
-- @field virtualtext_inline boolean|'before'|'after': Shows virtual text inline with color.
-- @field virtualtext_mode 'background'|'foreground': Mode for virtual text display.
-- @field always_update boolean: Always update color values, even if buffer is not focused.
-- @field hooks table: Table of hook functions
-- @field hooks.disable_line_highlight function: Returns boolean which controls if line should be parsed for highlights

--- Options for colorizer that were passed in to setup function
--@field filetypes
--@field buftypes
--@field user_commands
--@field lazy_load
--@field user_default_options
--@field exclusions
--@field all
M.options = {}
local function init_options()
  M.options = {
    -- setup options
    filetypes = { "*" },
    buftypes = {},
    user_commands = true,
    lazy_load = false,
    user_default_options = plugin_user_default_options,
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

--- Validate user options and set defaults.
local function validate_options(ud_opts)
  -- Set true value to it's "name"
  if ud_opts.tailwind == true then
    ud_opts.tailwind = "normal"
  end
  if ud_opts.virtualtext_inline == true then
    ud_opts.virtualtext_inline = "after"
  end
  -- Set default if value is invalid
  if ud_opts.tailwind ~= "normal" and ud_opts.tailwind ~= "both" and ud_opts.tailwind ~= "lsp" then
    ud_opts.tailwind = plugin_user_default_options.tailwind
  end
  if ud_opts.virtualtext_inline ~= "before" and ud_opts.virtualtext_inline ~= "after" then
    ud_opts.virtualtext_inline = plugin_user_default_options.virtualtext_inline
  end
  if
    ud_opts.mode ~= "background"
    and ud_opts.mode ~= "foreground"
    and ud_opts.mode ~= "virtualtext"
  then
    ud_opts.mode = plugin_user_default_options.mode
  end
  if ud_opts.virtualtext_mode ~= "background" and ud_opts.virtualtext_mode ~= "foreground" then
    ud_opts.virtualtext_mode = plugin_user_default_options.virtualtext_mode
  end
  -- Set names_custom to false if it's an empty table
  if
    ud_opts.names_custom
    and type(ud_opts.names_custom) == "table"
    and not next(ud_opts.names_custom)
  then
    ud_opts.names_custom = false
  end
  -- Extract table if names_custom is a function
  if ud_opts.names_custom then
    if type(ud_opts.names_custom) == "function" then
      local status, names = pcall(ud_opts.names_custom)
      if not (status and type(names) == "table") then
        error(string.format("Error in names_custom function: %s", names or "Invalid return value"))
      end
      ud_opts.names_custom = names
    end
    if type(ud_opts.names_custom) ~= "table" then
      error(string.format("Error in names_custom table: %s", vim.inspect(ud_opts.names_custom)))
    end
    -- Calculate hash to be used as key in names parser color_map
    -- Use a new key (names_custom_hashed) in case `hash` or `names` were defined as custom colors
    -- Make sure this key is checked in matcher and not `names_custom`
    ud_opts.names_custom_hashed = {
      hash = utils.hash_table(ud_opts.names_custom),
      names = ud_opts.names_custom,
    }
    ud_opts.names_custom = false
  end
  if ud_opts.hooks then
    if type(ud_opts.hooks.disable_line_highlight) ~= "function" then
      ud_opts.hooks.disable_line_highlight = false
    end
  end
end

--- Set options for a specific buffer or file type.
---@param bo_type 'buftype'|'filetype': The type of buffer option
---@param val string: The specific value to set.
---@param ud_opts table: `user_default_options`
function M.set_bo_value(bo_type, val, ud_opts)
  validate_options(ud_opts)
  options_cache[bo_type][val] = ud_opts
end

--- Parse and apply alias options to the user options.
---@param ud_opts table: user_default_options
---@return table
function M.apply_alias_options(ud_opts)
  local aliases = {
    --  TODO: 2024-12-24 - Should aliases be configurable?
    ["css"] = { "names", "RGB", "RGBA", "RRGGBB", "RRGGBBAA", "hsl_fn", "rgb_fn" },
    ["css_fn"] = { "hsl_fn", "rgb_fn" },
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
-- @table ud_opts
-- @field filetypes (table|nil): Optional.  A list of file types where colorizer should be enabled. Use `"*"` for all file types.
-- @field user_default_options table: Default options for color handling.
-- <pre>
--   - `names` (boolean): Enables named color codes like `"Blue"`.
--   - `names_opts` (table): Names options for customizing casing, digit stripping, etc
--     - `lowercase` (boolean): Converts color names to lowercase.
--     - `camelcase` (boolean): Converts color names to camelCase.  This is the default naming scheme for colors returned from `vim.api.nvim_get_color_map`
--     - `uppercase` (boolean): Converts color names to uppercase.
--     - `strip_digits` (boolean): Removes digits from color names.
--   - `names_custom` (table|function|false): Custom color name to RGB value mappings
--   - `RGB` (boolean): Enables support for `#RGB` hex codes.
--   - `RGBA` (boolean): Enables support for `#RGBA` hex codes.
--   - `RRGGBB` (boolean): Enables support for `#RRGGBB` hex codes.
--   - `RRGGBBAA` (boolean): Enables support for `#RRGGBBAA` hex codes.
--   - `AARRGGBB` (boolean): Enables support for `0xAARRGGBB` hex codes.
--   - `rgb_fn` (boolean): Enables CSS `rgb()` and `rgba()` functions.
--   - `hsl_fn` (boolean): Enables CSS `hsl()` and `hsla()` functions.
--   - `css` (boolean): Enables all CSS-related features (e.g., `names`, `RGB`, `RRGGBB`, `hsl_fn`, `rgb_fn`).
--   - `css_fn` (boolean): Enables all CSS function-related features (e.g., `rgb_fn`, `hsl_fn`).
--   - `tailwind` (boolean|string): Enables Tailwind CSS colors. Accepts `true`, `"normal"`, `"lsp"`, or `"both"`.
--   - `tailwind_opts` (table): Tailwind options for updating names cache, etc
--      - `update_names` (boolean): Updates Tailwind "normal" names cache from LSP results.  This provides a smoother highlighting experience when tailwind = "both" is used.  Highlighting on non-tailwind lsp buffers (like cmp) becomes more consistent.
--   - `sass` (table): Configures Sass color support.
--      - `enable` (boolean): Enables Sass color parsing.
--      - `parsers` (table): A list of parsers to use, typically includes `"css"`.
--   - `mode` (string): Determines the display mode for highlights. Options are `"background"`, `"foreground"`, and `"virtualtext"`.
--   - `virtualtext` (string): Character used for virtual text display of colors (default is `"■"`).
--  - `virtualtext_inline` (boolean|'before'|'after'): Shows the virtual text inline with the color.  True defaults to 'before'.
--  - `virtualtext_mode` ('background'|'foreground'): Determines the display mode for virtual text.
--  - `always_update` (boolean): If true, updates color values even if the buffer is not focused.</pre>
-- - `hooks` (table): Table of hook functions
--    - `disable_line_highlight` (function): Returns a boolean that controls if the line should be parsed for highlights. Called  with 3 parameters:
--      - `line` (string): The line's contents.
--      - `bufnr` (number): The buffer number.
--      - `line_num` (number): The line number (0-indexed).  Add 1 to get the line number in the buffer.
-- @field buftypes (table|nil): Optional. A list of buffer types where colorizer should be enabled. Defaults to all buffer types if not provided.
-- @field user_commands (boolean|table): If true, enables all user commands for colorizer. If `false`, disables user commands. Alternatively, provide a table of specific commands to enable:
--   - `"ColorizerAttachToBuffer"`
--   - `"ColorizerDetachFromBuffer"`
--   - `"ColorizerReloadAllBuffers"`
--   - `"ColorizerToggle"`
-- @field lazy_load (boolean): If true, lazily schedule buffer highlighting setup function

--- Initializes colorizer with user-provided options.
-- Merges default settings with any user-specified options, setting up `filetypes`,
-- `user_default_options`, and `user_commands`.
---@param opts table|nil: Configuration options for colorizer.
---@return table: Final settings after merging user and default options.
function M.get_setup_options(opts)
  init_config()
  opts = opts or {}
  opts.user_default_options = opts.user_default_options or plugin_user_default_options
  opts.user_default_options = M.apply_alias_options(opts.user_default_options)
  M.options = vim.tbl_deep_extend("force", M.options, opts)
  return M.options
end

--- Retrieve buffer-specific options or user_default_options defined when setup() was called.
---@param bufnr number: The buffer number.
---@param bo_type 'buftype'|'filetype': The type of buffer option
function M.new_bo_options(bufnr, bo_type)
  local value = vim.api.nvim_get_option_value(bo_type, { buf = bufnr })
  return options_cache.filetype[value] or M.options.user_default_options
end

--- Retrieve options based on buffer type and file type.  Prefer filetype.
---@param bo_type 'buftype'|'filetype': The type of buffer option
---@param buftype string: Buffer type.
---@param filetype string: File type.
---@return table
function M.get_bo_options(bo_type, buftype, filetype)
  local fo, bo = options_cache[bo_type][filetype], options_cache[bo_type][buftype]
  return fo or bo
end

return M
