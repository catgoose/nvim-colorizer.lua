local M = {}

local buf_get_option = vim.api.nvim_get_option_value

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
local user_default_options = {
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

local USER_COMMANDS = {
  "ColorizerAttachToBuffer",
  "ColorizerDetachFromBuffer",
  "ColorizerReloadAllBuffers",
  "ColorizerToggle",
}
local SETUP_SETTINGS = {
  exclusions = { buftype = {}, filetype = {} },
  all = { buftype = false, filetype = false },
  default_options = user_default_options,
  user_commands = USER_COMMANDS,
}

local OPTIONS = { buftype = {}, filetype = {} }

function M.setup(cfg)
  -- if nothing given the enable for all filetypes
  local _filetypes = cfg.filetypes or cfg[1] or { "*" }
  local _user_default_options = cfg.user_default_options or cfg[2] or {}
  local _buftypes = cfg.buftypes or cfg[3] or nil
  local _user_commands = cfg.user_commands == nil and true or cfg.user_commands

  local _settings = {
    exclusions = { buftype = {}, filetype = {} },
    all = { buftype = false, filetype = false },
    default_options = _user_default_options,
    user_commands = _user_commands,
    filetypes = _filetypes,
    buftypes = _buftypes,
  }

  SETUP_SETTINGS = _settings

  return SETUP_SETTINGS
end

function M.get_user_default_options()
  return user_default_options
end

function M.get_setup_settings()
  return SETUP_SETTINGS
end

function M.new_buffer_options(bufnr, bo_type)
  local value = buf_get_option(bo_type, { buf = bufnr })
  return OPTIONS.filetype[value] or M.get_setup_settings().default_options
end

function M.get_options(bo_type, buftype, filetype)
  local fopts, bopts, options = OPTIONS[bo_type][filetype], OPTIONS[bo_type][buftype], nil
  return fopts, bopts, options
end

function M.set_bo_value(bo_type, value, options)
  OPTIONS[bo_type][value] = options
end

return M
