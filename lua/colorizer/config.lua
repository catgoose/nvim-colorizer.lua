--- Provides configuration options and utilities for setting up colorizer.
-- @module colorizer.config
local M = {}

local utils = require("colorizer.utils")

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
-- @field mode string: Display mode (e.g., "background", "foreground", "virtualtext").
-- @field tailwind boolean|string: Enables Tailwind CSS colors (e.g., `"normal"`, `"lsp"`, `"both"`).
-- @field sass table: Sass color configuration (`enable` flag and `parsers`).
-- @field virtualtext string: Character used for virtual text display.
-- @field virtualtext_inline boolean: Shows virtual text inline with color.
-- @field always_update boolean: Always update color values, even if buffer is not focused.

-- Default options for the user
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
--@field mode string
--@field tailwind boolean|string
--@field sass table
--@field virtualtext string
--@field virtualtext_inline? boolean
--@field always_update boolean
M.user_default_options = {
  RGB = true,
  RRGGBB = true,
  names = true,
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
  always_update = false,
}

--  TODO: 2024-11-10 - check if setup() works

-- State for managing buffer and filetype-specific options
local options_state = { buftype = {}, filetype = {} }

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
  opts = opts or {}
  local defaults = {
    filetypes = { "*" },
    buftypes = nil,
    user_commands = true,
    user_default_options = M.user_default_options,
  }
  opts = vim.tbl_deep_extend("force", defaults, opts)
  local settings = {
    exclusions = { buftype = {}, filetype = {} },
    all = { buftype = false, filetype = false },
    default_options = vim.tbl_deep_extend(
      "force",
      M.user_default_options,
      opts.user_default_options
    ),
    user_commands = opts.user_commands,
    filetypes = opts.filetypes,
    buftypes = opts.buftypes,
  }
  return settings
end

--- Retrieve default options or buffer-specific options.
---@param bufnr number: The buffer number.
---@param option_type string: The option type to retrieve.
function M.new_buffer_options(bufnr, option_type)
  local value = vim.api.nvim_get_option_value(option_type, { buf = bufnr })
  return options_state.filetype[value] or M.user_default_options
end

--- Retrieve options based on buffer type and file type.
---@param bo_type 'filetype' | 'buftype': Type of buffer option
---@param buftype string: Buffer type.
---@param filetype string: File type.
function M.get_options(bo_type, buftype, filetype)
  return options_state[bo_type][filetype], options_state[bo_type][buftype]
end

--- Set options for a specific buffer or file type.
---@param bo_type 'filetype' | 'buftype': Type of buffer option
---@param value string: The specific value to set.
---@param options table: Options to associate with the value.
function M.set_bo_value(bo_type, value, options)
  options_state[bo_type][value] = options
end

--- Parse buffer Configuration and convert aliases to normal values
---@param options table: options table
---@return table
function M.parse_buffer_options(options)
  local includes = {
    ["css"] = { "names", "RGB", "RRGGBB", "RRGGBBAA", "hsl_fn", "rgb_fn" },
    ["css_fn"] = { "hsl_fn", "rgb_fn" },
  }
  local default_opts = M.user_default_options

  local function handle_alias(name, opts, d_opts)
    if not includes[name] then
      return
    end
    for _, child in ipairs(includes[name]) do
      d_opts[child] = opts[name] or false
    end
  end

  -- https://github.com/NvChad/nvim-colorizer.lua/issues/48
  handle_alias("css", options, default_opts)
  handle_alias("css_fn", options, default_opts)

  if options.sass then
    if type(options.sass.parsers) == "table" then
      for child, _ in pairs(options.sass.parsers) do
        handle_alias(child, options.sass.parsers, default_opts.sass.parsers)
      end
    else
      options.sass.parsers = {}
      for child, _ in pairs(default_opts.sass.parsers) do
        handle_alias(child, true, options.sass.parsers)
      end
    end
  end

  options = utils.merge(default_opts, options)
  return options
end
return M
