--@module colorizer.config
local M = {}

---defaults options.
--In `user_default_options`, there are 2 types of options
--
--1. Individual options - `names`, `RGB`, `RRGGBB`, `RRGGBBAA`, `hsl_fn`, `rgb_fn` , `RRGGBBAA`, `AARRGGBB`, `tailwind`, `sass`
--
--1. Alias options - `css`, `css_fn`
--
--If `css_fn` is true, then `hsl_fn`, `rgb_fn` becomes `true`
--
--If `css` is true, then `names`, `RGB`, `RRGGBB`, `RRGGBBAA`, `hsl_fn`, `rgb_fn` becomes `true`
--
--These options have a priority, Individual options have the highest priority, then alias options
--
--For alias, `css_fn` has more priority over `css`
--
--e.g: Here `RGB`, `RRGGBB`, `RRGGBBAA`, `hsl_fn`, `rgb_fn` is enabled but not `names`
--
--<pre>
--  require 'colorizer'.setup { user_default_options = { names = false, css = true } }
--</pre>
--
--e.g: Here `names`, `RGB`, `RRGGBB`, `RRGGBBAA` is enabled but not `rgb_fn` and `hsl_fn`
--
--<pre>
--  require 'colorizer'.setup { user_default_options = { css_fn = false, css = true } }
--</pre>
--
--<pre>
--  user_commands = {
--   "ColorizerAttachToBuffer",
--   "ColorizerDetachFromBuffer",
--   "ColorizerReloadAllBuffers",
--   "ColorizerToggle",
-- }, -- List of commands to enable, set to false to disable all user commands,
-- true to enable all
--  user_default_options = {
--      RGB = true, -- #RGB hex codes
--      RRGGBB = true, -- #RRGGBB hex codes
--      names = true, -- "Name" codes like Blue or blue
--      RRGGBBAA = false, -- #RRGGBBAA hex codes
--      AARRGGBB = false, -- 0xAARRGGBB hex codes
--      rgb_fn = false, -- CSS rgb() and rgba() functions
--      hsl_fn = false, -- CSS hsl() and hsla() functions
--      css = false, -- Enable all CSS features: rgb_fn, hsl_fn, names, RGB, RRGGBB
--      css_fn = false, -- Enable all CSS *functions*: rgb_fn, hsl_fn
--      -- Available modes for `mode`: foreground, background,  virtualtext
--      mode = "background", -- Set the display mode.
--      -- Available methods are false / true / "normal" / "lsp" / "both"
--      -- True is same as normal
--      tailwind = false, -- Enable tailwind colors
--      -- parsers can contain values used in |user_default_options|
--      sass = { enable = false, parsers = { css }, }, -- Enable sass colors
--      virtualtext = "■",
--      virtualtext_inline = false, -- Show the virtualtext inline with the color
--      -- update color values even if buffer is not focused
--      always_update = false
--  }
--</pre>

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

-- State for managing buffer and filetype-specific options
local options_state = { buftype = {}, filetype = {} }

--- Setup function to initialize module settings based on user-provided options.
---@param opts table: User-provided configuration options.
function M.setup(opts)
  opts = opts or {}
  local defaults = {
    filetypes = { "*" },
    user_default_options = {},
    buftypes = nil,
    user_commands = true,
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

return M
