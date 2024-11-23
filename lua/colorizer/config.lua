--- Provides configuration options and utilities for setting up colorizer.
-- @module colorizer.config
local M = {}

local utils = require("colorizer.utils")

--- Defaults for colorizer options
local function user_defaults()
  return vim.deepcopy({
    names = true,
    RGB = true,
    RRGGBB = true,
    RRGGBBAA = false,
    AARRGGBB = false,
    rgb_fn = false,
    hsl_fn = false,
    css = false,
    css_fn = false,
    mode = "background",
    tailwind = false,
    sass = { enable = false, parsers = { css = true } },
    virtualtext = "■",
    virtualtext_inline = false,
    virtualtext_mode = "foreground",
    always_update = false,
  })
end

--- Default user options for colorizer.
-- This table defines individual options and alias options, allowing configuration of
-- colorizer's behavior for different color formats (e.g., `#RGB`, `#RRGGBB`, `#AARRGGBB`, etc.).
--
-- **Individual Options**: Options like `names`, `RGB`, `RRGGBB`, `RRGGBBAA`, `hsl_fn`, `rgb_fn`,
-- `AARRGGBB`, `tailwind`, and `sass` can be enabled or disabled independently.
--
-- **Alias Options**: `css` and `css_fn` enable multiple options at once.
--   - `css_fn = true` enables `hsl_fn` and `rgb_fn`.
--   - `css = true` enables `names`, `RGB`, `RRGGBB`, `RRGGBBAA`, `hsl_fn`, and `rgb_fn`.
--
-- **Option Priority**: Individual options have higher priority than aliases.
-- If both `css` and `css_fn` are true, `css_fn` has more priority over `css`.
-- @table user_default_options
-- @field RGB boolean: Enables `#RGB` hex codes.
-- @field RRGGBB boolean: Enables `#RRGGBB` hex codes.
-- @field names boolean: Enables named colors (e.g., "Blue").
-- @field RRGGBBAA boolean: Enables `#RRGGBBAA` hex codes.
-- @field AARRGGBB boolean: Enables `0xAARRGGBB` hex codes.
-- @field rgb_fn boolean: Enables CSS `rgb()` and `rgba()` functions.
-- @field hsl_fn boolean: Enables CSS `hsl()` and `hsla()` functions.
-- @field css boolean: Enables all CSS features (`rgb_fn`, `hsl_fn`, `names`, `RGB`, `RRGGBB`).
-- @field css_fn boolean: Enables all CSS functions (`rgb_fn`, `hsl_fn`).
-- @field mode 'background'|'foreground'|'virtualtext': Display mode
-- @field tailwind boolean|string: Enables Tailwind CSS colors (e.g., `"normal"`, `"lsp"`, `"both"`).
-- @field sass table: Sass color configuration (`enable` flag and `parsers`).
-- @field virtualtext string: Character used for virtual text display.
-- @field virtualtext_inline boolean: Shows virtual text inline with color.
-- @field virtualtext_mode 'background'|'foreground': Mode for virtual text display.
-- @field always_update boolean: Always update color values, even if buffer is not focused.

-- Configured user options
---@table user_default_options
--@field RGB boolean
--@field RRGGBB boolean
--@field names boolean
--@field RRGGBBAA boolean
--@field AARRGGBB boolean
--@field rgb_fn boolean
--@field hsl_fn boolean
--@field css boolean
--@field css_fn boolean
--@field mode 'background'|'foreground'|'virtualtext'
--@field tailwind boolean|string
--@field sass table
--@field virtualtext string
--@field virtualtext_inline boolean
--@field virtualtext_mode 'background'|'foreground'
--@field always_update boolean
M.user_default_options = nil

--- Options for colorizer that were passed in to setup function
---@table setup_options
--@field exclusions table
--@field all table
--@field default_options table
--@field user_commands boolean
--@field filetypes table
--@field buftypes table
M.setup_options = nil

--- Plugin default options cache from vim.deepcopy
---@table default_options
local plugin_default_options = user_defaults()

-- State for managing buffer and filetype-specific options
local options_state

--- Validates user options and sets defaults if necessary.
local function validate_opts(settings)
  if
    not vim.tbl_contains(
      { "background", "foreground", "virtualtext" },
      settings.default_options.mode
    )
  then
    settings.default_options.mode = plugin_default_options.mode
  end
  if
    not vim.tbl_contains({ "background", "foreground" }, settings.default_options.virtualtext_mode)
  then
    settings.default_options.virtualtext_mode = plugin_default_options.virtualtext_mode
  end
  if
    not vim.tbl_contains(
      { true, false, "normal", "lsp", "both" },
      settings.default_options.tailwind
    )
  then
    settings.default_options.tailwind = plugin_default_options.tailwind
  end
  return settings
end

--- Configuration options for the `setup` function.
-- @table opts
-- @field filetypes table A list of file types where colorizer should be enabled. Use `"*"` for all file types.
-- @field user_default_options table Default options for color handling.
--   - `RGB` (boolean): Enables support for `#RGB` hex codes.
--   - `RRGGBB` (boolean): Enables support for `#RRGGBB` hex codes.
--   - `names` (boolean): Enables named color codes like `"Blue"`.
--   - `RRGGBBAA` (boolean): Enables support for `#RRGGBBAA` hex codes.
--   - `AARRGGBB` (boolean): Enables support for `0xAARRGGBB` hex codes.
--   - `rgb_fn` (boolean): Enables CSS `rgb()` and `rgba()` functions.
--   - `hsl_fn` (boolean): Enables CSS `hsl()` and `hsla()` functions.
--   - `css` (boolean): Enables all CSS-related features (e.g., `names`, `RGB`, `RRGGBB`, `hsl_fn`, `rgb_fn`).
--   - `css_fn` (boolean): Enables all CSS function-related features (e.g., `rgb_fn`, `hsl_fn`).
--   - `mode` (string): Determines the display mode for highlights. Options are `"background"`, `"foreground"`, and `"virtualtext"`.
--   - `tailwind` (boolean|string): Enables Tailwind CSS colors. Accepts `true`, `"normal"`, `"lsp"`, or `"both"`.
--   - `sass` (table): Configures Sass color support.
--      - `enable` (boolean): Enables Sass color parsing.
--      - `parsers` (table): A list of parsers to use, typically includes `"css"`.
--   - `virtualtext` (string): Character used for virtual text display of colors (default is `"■"`).
--   - `virtualtext_inline` (boolean): If true, shows the virtual text inline with the color.
-- - `virtualtext_mode` ('background'|'foreground'): Determines the display mode for virtual text.
--   - `always_update` (boolean): If true, updates color values even if the buffer is not focused.
-- @field buftypes table|nil Optional. A list of buffer types where colorizer should be enabled. Defaults to all buffer types if not provided.
-- @field user_commands boolean|table If true, enables all user commands for colorizer. If `false`, disables user commands. Alternatively, provide a table of specific commands to enable:
--   - `"ColorizerAttachToBuffer"`
--   - `"ColorizerDetachFromBuffer"`
--   - `"ColorizerReloadAllBuffers"`
--   - `"ColorizerToggle"`

--- Initializes colorizer with user-provided options.
-- Merges default settings with any user-specified options, setting up `filetypes`,
-- `user_default_options`, and `user_commands`.
-- @param opts opts User-provided configuration options.
-- @return table Final settings after merging user and default options.
function M.get_settings(opts)
  options_state = { buftype = {}, filetype = {} }
  opts = opts or {}
  local default_opts = {
    filetypes = { "*" },
    buftypes = nil,
    user_commands = true,
    user_default_options = plugin_default_options,
  }
  --  TODO: 2024-11-21 - verify that vim.tbl_deep_extend is doing what it should
  opts = vim.tbl_deep_extend("force", default_opts, opts)
  local settings = {
    exclusions = { buftype = {}, filetype = {} },
    all = { buftype = false, filetype = false },
    default_options = vim.tbl_deep_extend(
      "force",
      plugin_default_options,
      opts.user_default_options
    ),
    user_commands = opts.user_commands,
    filetypes = opts.filetypes,
    buftypes = opts.buftypes,
  }
  validate_opts(settings)
  M.setup_options = settings
  M.user_default_options = settings.default_options
  return settings
end

--- Retrieve default options or buffer-specific options.
---@param bufnr number: The buffer number.
---@param bo_type 'buftype'|'filetype': The type of buffer option
function M.new_buffer_options(bufnr, bo_type)
  local value = vim.api.nvim_get_option_value(bo_type, { buf = bufnr })
  return options_state.filetype[value] or M.user_default_options
end

--- Retrieve options based on buffer type and file type.  Prefer filetype.
---@param bo_type 'buftype'|'filetype': The type of buffer option
---@param buftype string: Buffer type.
---@param filetype string: File type.
---@return table
function M.get_options(bo_type, buftype, filetype)
  return options_state[bo_type][filetype] or options_state[bo_type][buftype]
end

--- Set options for a specific buffer or file type.
---@param bo_type 'buftype'|'filetype': The type of buffer option
---@param value string: The specific value to set.
---@param options table: Options to associate with the value.
function M.set_bo_value(bo_type, value, options)
  options_state[bo_type][value] = options
end

--- Parse buffer Configuration and convert aliases to normal values
---@param options table: options table
---@return table
function M.parse_buffer_options(options)
  local default = vim.deepcopy(M.user_default_options)
  local includes = {
    ["css"] = { "names", "RGB", "RRGGBB", "RRGGBBAA", "hsl_fn", "rgb_fn" },
    ["css_fn"] = { "hsl_fn", "rgb_fn" },
  }

  local function handle_alias(name, opts, d_opts)
    if not includes[name] then
      return
    end
    for _, child in ipairs(includes[name]) do
      d_opts[child] = opts[name] or false
    end
  end

  -- https://github.com/NvChad/nvim-colorizer.lua/issues/48
  handle_alias("css", options, default)
  handle_alias("css_fn", options, default)

  if options.sass then
    if type(options.sass.parsers) == "table" then
      for child, _ in pairs(options.sass.parsers) do
        handle_alias(child, options.sass.parsers, default.sass.parsers)
      end
    else
      options.sass.parsers = {}
      for child, _ in pairs(default.sass.parsers) do
        handle_alias(child, true, options.sass.parsers)
      end
    end
  end

  options = utils.merge(default, options)
  return options
end
return M
