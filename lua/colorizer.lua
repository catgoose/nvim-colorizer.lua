--- Requires Neovim >= 0.6.0 and `set termguicolors`
--
--Highlights terminal CSI ANSI color codes.
-- @module colorizer
-- @author Ashkan Kiani <from-nvim-colorizer.lua@kiani.io>
-- @usage Establish the autocmd to highlight all filetypes.
--
--       `lua require 'colorizer'.setup()`
--
-- Highlight using all css highlight modes in every filetype
--
--       `lua require 'colorizer'.setup(user_default_options = { css = true; })`
--
--==============================================================================
--USE WITH COMMANDS                                          *colorizer-commands*
--
--   *:ColorizerAttachToBuffer*
--
--       Attach to the current buffer and start highlighting with the settings as
--       specified in setup (or the defaults).
--
--       If the buffer was already attached(i.e. being highlighted), the
--       settings will be reloaded with the ones from setup.
--       This is useful for reloading settings for just one buffer.
--
--   *:ColorizerDetachFromBuffer*
--
--       Stop highlighting the current buffer (detach).
--
--   *:ColorizerReloadAllBuffers*
--
--       Reload all buffers that are being highlighted currently.
--       Shortcut for ColorizerAttachToBuffer on every buffer.
--
--   *:ColorizerToggle*
--       Toggle highlighting of the current buffer.
--
--USE WITH LUA
--
--       All options that can be passed to user_default_options in `setup`
--       can be passed here. Can be empty too.
--       `0` is the buffer number here
--
--       Attach to current buffer <pre>
--           require("colorizer").attach_to_buffer(0, {
--             mode = "background",
--             css = false,
--           })
--</pre>
--       Detach from buffer <pre>
--           require("colorizer").detach_from_buffer(0, {
--             mode = "background",
--             css = false,
--           })
--</pre>
-- @see colorizer.setup
-- @see colorizer.attach_to_buffer
-- @see colorizer.detach_from_buffer

local buffer_utils = require "colorizer.buffer_utils"

---Default namespace used in `colorizer.buffer_utils.highlight_buffer` and `attach_to_buffer`.
-- @see colorizer.buffer_utils.highlight_buffer
-- @see attach_to_buffer
local DEFAULT_NAMESPACE = buffer_utils.DEFAULT_NAMESPACE

local HIGHLIGHT_MODE_NAMES = buffer_utils.HIGHLIGHT_MODE_NAMES
local rehighlight_buffer = buffer_utils.rehighlight_buffer

---Highlight the buffer region
---@function highlight_buffer
-- @see colorizer.buffer_utils.highlight_buffer
local highlight_buffer = buffer_utils.highlight_buffer

local utils = require "colorizer.utils"
local merge = utils.merge

local api = vim.api
local augroup = api.nvim_create_augroup
local autocmd = api.nvim_create_autocmd
local buf_get_option = api.nvim_buf_get_option
local clear_namespace = api.nvim_buf_clear_namespace
local current_buf = api.nvim_get_current_buf

-- USER FACING FUNCTIONALITY --
local AUGROUP_ID
local AUGROUP_NAME = "ColorizerSetup"
-- buffer specific options given in setup
local BUFFER_OPTIONS = {}
-- store boolean for buffer if it is initialzed
local BUFFER_INIT = {}
-- store buffer local autocmd(s) id
local BUFFER_AUTOCMDS = {}

local USER_DEFAULT_OPTIONS = {
  RGB = true, -- #RGB hex codes
  RRGGBB = true, -- #RRGGBB hex codes
  names = true, -- "Name" codes like Blue or blue
  RRGGBBAA = false, -- #RRGGBBAA hex codes
  AARRGGBB = false, -- 0xAARRGGBB hex codes
  rgb_fn = false, -- CSS rgb() and rgba() functions
  hsl_fn = false, -- CSS hsl() and hsla() functions
  css = false, -- Enable all CSS features: rgb_fn, hsl_fn, names, RGB, RRGGBB
  css_fn = false, -- Enable all CSS *functions*: rgb_fn, hsl_fn
  -- Available modes: foreground, background, virtualtext
  mode = "background", -- Set the display mode.
  virtualtext = "■",
}

local OPTIONS = { buf = {}, file = {} }
local SETUP_SETTINGS = {
  exclusions = { buf = {}, file = {} },
  all = { file = false, buf = false },
  default_options = USER_DEFAULT_OPTIONS,
}

--- Make new buffer Configuration
---@param buf number: buffer number
---@param typ string|nil: "buf" or "file" - The type of buffer option
---@return table
local function new_buffer_options(buf, typ)
  local value
  if typ == "buf" then
    value = buf_get_option(buf, "buftype")
  else
    value = buf_get_option(buf, "filetype")
  end
  return OPTIONS.file[value] or SETUP_SETTINGS.default_options
end

--- Check if attached to a buffer.
---@param buf number|nil: A value of 0 implies the current buffer.
---@return number|nil: if attached to the buffer, false otherwise.
---@see highlight_buffer
local function is_buffer_attached(buf)
  if buf == 0 or buf == nil then
    buf = current_buf()
  end
  local au = api.nvim_get_autocmds {
    group = AUGROUP_ID,
    event = { "WinScrolled", "TextChanged", "TextChangedI", "TextChangedP" },
    buffer = buf,
  }
  if not BUFFER_OPTIONS[buf] or vim.tbl_isempty(au) then
    return
  end

  return buf
end

--- Stop highlighting the current buffer.
---@param buf number|nil: buf A value of 0 or nil implies the current buffer.
---@param ns number|nil: ns the namespace id, if not given DEFAULT_NAMESPACE is used
local function detach_from_buffer(buf, ns)
  buf = is_buffer_attached(buf)
  if not buf then
    return
  end

  clear_namespace(buf, ns or DEFAULT_NAMESPACE, 0, -1)
  for _, id in ipairs(BUFFER_AUTOCMDS[buf] or {}) do
    pcall(api.nvim_del_autocmd, id)
  end
  -- because now the buffer is not visible, so delete its information
  BUFFER_OPTIONS[buf] = nil
  BUFFER_AUTOCMDS[buf] = nil
end

---Attach to a buffer and continuously highlight changes.
---@param buf integer: A value of 0 implies the current buffer.
---@param options table: Configuration options as described in `setup`
---@param typ string|nil: "buf" or "file" - The type of buffer option
local function attach_to_buffer(buf, options, typ)
  if buf == 0 or buf == nil then
    buf = current_buf()
  end

  if not options then
    options = new_buffer_options(buf, typ)
  end

  if not HIGHLIGHT_MODE_NAMES[options.mode] then
    if options.mode ~= nil then
      local mode = options.mode
      vim.defer_fn(function()
        -- just notify the user once
        vim.notify_once(string.format("Warning: Invalid mode given to colorizer setup [ %s ]", mode))
      end, 0)
    end
    options.mode = "background"
  end

  BUFFER_OPTIONS[buf] = options
  rehighlight_buffer(buf, options)

  BUFFER_INIT[buf] = true

  if BUFFER_AUTOCMDS[buf] then
    return
  end

  local autocmds = {}
  local au_group_id = AUGROUP_ID

  autocmds[#autocmds + 1] = autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
    group = au_group_id,
    buffer = buf,
    callback = function()
      -- only reload if it was not disabled using detach_from_buffer
      if BUFFER_OPTIONS[buf] then
        rehighlight_buffer(buf, options)
      end
    end,
  })

  autocmds[#autocmds + 1] = autocmd({ "WinScrolled" }, {
    group = au_group_id,
    buffer = buf,
    callback = function()
      -- only reload if it was not disabled using detach_from_buffer
      if BUFFER_OPTIONS[buf] then
        rehighlight_buffer(buf, options)
      end
    end,
  })

  autocmd({ "BufUnload", "BufDelete" }, {
    group = au_group_id,
    buffer = buf,
    callback = function()
      if BUFFER_OPTIONS[buf] then
        detach_from_buffer(buf)
      end
      BUFFER_INIT[buf] = nil
    end,
  })

  BUFFER_AUTOCMDS[buf] = autocmds
end

---Easy to use function if you want the full setup without fine grained control.
--Setup an autocmd which enables colorizing for the filetypes and options specified.
--
--By default highlights all FileTypes.
--
--Example config:~
--<pre>
--  { filetypes = { "css", "html" }, user_default_options = { names = true } }
--</pre>
--Setup with all the default options:~
--<pre>
--    require("colorizer").setup {
--      filetypes = { "*" },
--      user_default_options = {
--        RGB = true, -- #RGB hex codes
--        RRGGBB = true, -- #RRGGBB hex codes
--        names = true, -- "Name" codes like Blue or blue
--        RRGGBBAA = false, -- #RRGGBBAA hex codes
--        AARRGGBB = false, -- 0xAARRGGBB hex codes
--        rgb_fn = false, -- CSS rgb() and rgba() functions
--        hsl_fn = false, -- CSS hsl() and hsla() functions
--        css = false, -- Enable all CSS features: rgb_fn, hsl_fn, names, RGB, RRGGBB
--        css_fn = false, -- Enable all CSS *functions*: rgb_fn, hsl_fn
--        -- Available modes for `mode`: foreground, background,  virtualtext
--        mode = "background", -- Set the display mode.
--        virtualtext = "■",
--      },
--      -- all the sub-options of filetypes apply to buftypes
--      buftypes = {},
--    }
--</pre>
---@param config table: Config containing above parameters.
---@usage `require'colorizer'.setup()`
local function setup(config)
  if not vim.opt.termguicolors then
    vim.schedule(function()
      vim.notify("Colorizer: Error: &termguicolors must be set", "Error")
    end)
    return
  end

  local conf = vim.deepcopy(config) or {}

  -- if nothing given the enable for all filetypes
  local filetypes = conf.filetypes or conf[1] or { "*" }
  local user_default_options = conf.user_default_options or conf[2] or {}
  local buftypes = conf.buftypes or conf[3] or nil

  OPTIONS = { buf = {}, file = {} }
  SETUP_SETTINGS = {
    exclusions = { buf = {}, file = {} },
    all = { file = false, buf = false },
    default_options = merge(USER_DEFAULT_OPTIONS, user_default_options),
  }

  local function COLORIZER_SETUP_HOOK(typ)
    local filetype = vim.bo.filetype
    local buftype = vim.bo.buftype
    local buf = current_buf()
    if SETUP_SETTINGS.exclusions.file[filetype] or SETUP_SETTINGS.exclusions.buf[buftype] then
      -- when a filetype is disabled but buftype is enabled, it can Attach in
      -- some cases, so manually detach
      if BUFFER_OPTIONS[buf] then
        detach_from_buffer(buf)
      end
      BUFFER_INIT[buf] = nil
      return
    end

    local fopts, bopts, options = OPTIONS[typ][filetype], OPTIONS[typ][buftype], nil
    if typ == "file" then
      options = fopts
      -- if buffer and filetype options both are given, then prefer fileoptions
    elseif fopts and bopts then
      options = fopts
    else
      options = bopts
    end

    if not options and not SETUP_SETTINGS.all[typ] then
      return
    end

    options = options or SETUP_SETTINGS.default_options

    -- this should ideally be triggered one time per buffer
    -- but BufWinEnter also triggers for split formation
    -- but we don't want that so add a check using local buffer variable
    if not BUFFER_INIT[buf] then
      attach_to_buffer(buf, options, typ)
    end
  end

  local au_group_id = augroup(AUGROUP_NAME, {})
  AUGROUP_ID = au_group_id

  local aucmd = { buf = "BufWinEnter", file = "FileType" }
  local function parse_opts(typ, tbl)
    if type(tbl) == "table" then
      local list = {}

      for k, v in pairs(tbl) do
        local value
        local options = SETUP_SETTINGS.default_options
        if type(k) == "string" then
          value = k
          if type(v) ~= "table" then
            vim.notify("colorizer: Invalid option type for " .. typ .. "type" .. value, "ErrorMsg")
          else
            options = merge(SETUP_SETTINGS.default_options, v)
          end
        else
          value = v
        end
        -- Exclude
        if value:sub(1, 1) == "!" then
          SETUP_SETTINGS.exclusions[typ][value:sub(2)] = true
        else
          OPTIONS[typ][value] = options
          if value == "*" then
            SETUP_SETTINGS.all[typ] = true
          else
            table.insert(list, value)
          end
        end
      end
      autocmd({ aucmd[typ] }, {
        group = au_group_id,
        pattern = typ == "file" and (SETUP_SETTINGS.all[typ] and "*" or list) or nil,
        callback = function()
          COLORIZER_SETUP_HOOK(typ)
        end,
      })
    elseif tbl then
      vim.notify_once(string.format("colorizer: Invalid type for %stypes %s", typ, vim.inspect(tbl)), "ErrorMsg")
    end
  end

  parse_opts("file", filetypes)
  parse_opts("buf", buftypes)

  autocmd("ColorScheme", {
    group = au_group_id,
    callback = function()
      require("colorizer").clear_highlight_cache()
    end,
  })
end

--- Return the currently active buffer options.
---@param buf number|nil: Buffer number
local function get_buffer_options(buf)
  if buf == 0 or buf == nil then
    buf = current_buf()
  end
  return merge({}, BUFFER_OPTIONS[buf])
end

--- Reload all of the currently active highlighted buffers.
local function reload_all_buffers()
  for buf, _ in pairs(BUFFER_OPTIONS) do
    attach_to_buffer(buf, get_buffer_options(buf))
  end
end

--- Clear the highlight cache and reload all buffers.
local function clear_highlight_cache()
  HIGHLIGHT_CACHE = {}
  vim.schedule(reload_all_buffers)
end

--- @export
return {
  DEFAULT_NAMESPACE = DEFAULT_NAMESPACE,
  setup = setup,
  is_buffer_attached = is_buffer_attached,
  attach_to_buffer = attach_to_buffer,
  detach_from_buffer = detach_from_buffer,
  highlight_buffer = highlight_buffer,
  reload_all_buffers = reload_all_buffers,
  get_buffer_options = get_buffer_options,
  clear_highlight_cache = clear_highlight_cache,
}
