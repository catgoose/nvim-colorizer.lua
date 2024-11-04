--- Requires Neovim >= 0.7.0 and `set termguicolors`
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

local buffer_utils = require "colorizer.buffer"
local clear_hl_cache = buffer_utils.clear_hl_cache
local rehighlight_buffer = buffer_utils.rehighlight

local utils = require "colorizer.utils"
local merge = utils.merge

local api = vim.api
local augroup = api.nvim_create_augroup
local autocmd = api.nvim_create_autocmd
local buf_get_option = api.nvim_get_option_value
local clear_namespace = api.nvim_buf_clear_namespace
local current_buf = api.nvim_get_current_buf

local colorizer = {}

---Default namespace used in `colorizer.buffer.highlight` and `attach_to_buffer`.
-- @see colorizer.buffer.highlight
-- @see attach_to_buffer
colorizer.DEFAULT_NAMESPACE = buffer_utils.default_namespace

---Highlight the buffer region
---@function highlight_buffer
-- @see colorizer.buffer.highlight
colorizer.highlight_buffer = buffer_utils.highlight

-- USER FACING FUNCTIONALITY --
local AUGROUP_ID
local AUGROUP_NAME = "ColorizerSetup"
-- buffer specific options given in setup
local BUFFER_OPTIONS = {}
-- buffer local options created after setup
local BUFFER_LOCAL = {}
-- the current buffer id, used in buf_attach calls
local CURRENT_BUF = 0

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
local USER_DEFAULT_OPTIONS = {
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

local OPTIONS = { buftype = {}, filetype = {} }
local SETUP_SETTINGS = {
  exclusions = { buftype = {}, filetype = {} },
  all = { buftype = false, filetype = false },
  default_options = USER_DEFAULT_OPTIONS,
}

--- Make new buffer Configuration
---@param bufnr number: buffer number (0 for current)
---@param bo_type 'buftype'|'filetype': The type of buffer option
---@return table
local function new_buffer_options(bufnr, bo_type)
  local value = buf_get_option(bo_type, { buf = bufnr })
  return OPTIONS.filetype[value] or SETUP_SETTINGS.default_options
end

--- Parse buffer Configuration and convert aliases to normal values
---@param options table: options table
---@return table
local function parse_buffer_options(options)
  local includes = {
    ["css"] = { "names", "RGB", "RRGGBB", "RRGGBBAA", "hsl_fn", "rgb_fn" },
    ["css_fn"] = { "hsl_fn", "rgb_fn" },
  }
  local default_opts = USER_DEFAULT_OPTIONS

  local function handle_alias(name, opts, d_opts)
    if not includes[name] then
      return
    end
    if opts == true or opts[name] == true then
      for _, child in ipairs(includes[name]) do
        d_opts[child] = true
      end
    elseif opts[name] == false then
      for _, child in ipairs(includes[name]) do
        d_opts[child] = false
      end
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

  options = merge(default_opts, options)
  return options
end

--- Check if attached to a buffer.
---@param bufnr number|nil: A value of 0 implies the current buffer.
---@return number|nil: if attached to the buffer, false otherwise.
---@see colorizer.buffer.highlight
function colorizer.is_buffer_attached(bufnr)
  if bufnr == 0 or not bufnr then
    bufnr = current_buf()
  else
    if not api.nvim_buf_is_valid(bufnr) then
      BUFFER_LOCAL[bufnr], BUFFER_OPTIONS[bufnr] = nil, nil
      return
    end
  end

  local au = api.nvim_get_autocmds {
    group = AUGROUP_ID,
    event = { "WinScrolled", "TextChanged", "TextChangedI", "TextChangedP" },
    buffer = bufnr,
  }
  if not BUFFER_OPTIONS[bufnr] or vim.tbl_isempty(au) then
    return
  end

  return bufnr
end

--- Stop highlighting the current buffer.
---@param bufnr number|nil: buffer number (0 for current)
---@param ns_id number|nil: namespace id.  default is "colorizer", created with vim.api.nvim_create_namespace
function colorizer.detach_from_buffer(bufnr, ns_id)
  bufnr = colorizer.is_buffer_attached(bufnr)
  if not bufnr then
    return
  end

  clear_namespace(bufnr, ns_id or colorizer.DEFAULT_NAMESPACE, 0, -1)
  if BUFFER_LOCAL[bufnr] then
    for _, namespace in pairs(BUFFER_LOCAL[bufnr].__detach.ns_id) do
      clear_namespace(bufnr, namespace, 0, -1)
    end

    for _, f in pairs(BUFFER_LOCAL[bufnr].__detach.functions) do
      if type(f) == "function" then
        f(bufnr)
      end
    end

    for _, id in ipairs(BUFFER_LOCAL[bufnr].__autocmds or {}) do
      pcall(api.nvim_del_autocmd, id)
    end

    BUFFER_LOCAL[bufnr].__autocmds = nil
    BUFFER_LOCAL[bufnr].__detach = nil
  end
  -- because now the buffer is not visible, so delete its information
  BUFFER_OPTIONS[bufnr] = nil
end

---Attach to a buffer and continuously highlight changes.
---@param bufnr number|nil: buffer number (0 for current)
---@param options table|nil: Configuration options as described in `setup`
---@param bo_type 'buftype'|'filetype'|nil: The type of buffer option
function colorizer.attach_to_buffer(bufnr, options, bo_type)
  bufnr = bufnr and bufnr ~= 0 and api.nvim_buf_is_valid(bufnr) and bufnr or current_buf()
  bo_type = bo_type or "buftype"
  if not api.nvim_buf_is_valid(bufnr) then
    BUFFER_LOCAL[bufnr], BUFFER_OPTIONS[bufnr] = nil, nil
    return
  end

  -- set options by grabbing existing or creating new options, then parsing
  options = parse_buffer_options(options or colorizer.get_buffer_options(bufnr) or new_buffer_options(bufnr, bo_type))

  if not buffer_utils.highlight_mode_names[options.mode] then
    if options.mode ~= nil then
      local mode = options.mode
      vim.defer_fn(function()
        -- just notify the user once
        vim.notify_once(string.format("Warning: Invalid mode given to colorizer setup [ %s ]", mode))
      end, 0)
    end
    options.mode = "background"
  end

  BUFFER_OPTIONS[bufnr] = options

  BUFFER_LOCAL[bufnr] = BUFFER_LOCAL[bufnr] or {}
  local highlighted, returns = rehighlight_buffer(bufnr, options)

  if not highlighted then
    return
  end

  BUFFER_LOCAL[bufnr].__detach = BUFFER_LOCAL[bufnr].__detach or returns.detach

  BUFFER_LOCAL[bufnr].__init = true

  if BUFFER_LOCAL[bufnr].__autocmds then
    return
  end

  local autocmds = {}
  local au_group_id = AUGROUP_ID

  local text_changed_au = { "TextChanged", "TextChangedI", "TextChangedP" }
  -- only enable InsertLeave in sass, rest don't require it
  if options.sass and options.sass.enable then
    table.insert(text_changed_au, "InsertLeave")
  end

  if CURRENT_BUF == 0 then
    CURRENT_BUF = bufnr
  end

  if options.always_update then
    -- attach using lua api so buffer gets updated even when not the current buffer
    -- completely moving to buf_attach is not possible because it doesn't handle all the text change events
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = function(_, buffer)
        -- only reload if the buffer is not the current one
        if not (CURRENT_BUF == buffer) then
          -- only reload if it was not disabled using detach_from_buffer
          if BUFFER_OPTIONS[bufnr] then
            rehighlight_buffer(bufnr, options, BUFFER_LOCAL[bufnr])
          end
        end
      end,
      on_reload = function(_, buffer)
        -- only reload if the buffer is not the current one
        if not (CURRENT_BUF == buffer) then
          -- only reload if it was not disabled using detach_from_buffer
          if BUFFER_OPTIONS[bufnr] then
            rehighlight_buffer(bufnr, options, BUFFER_LOCAL[bufnr])
          end
        end
      end,
    })
  end

  autocmds[#autocmds + 1] = autocmd(text_changed_au, {
    group = au_group_id,
    buffer = bufnr,
    callback = function(args)
      CURRENT_BUF = bufnr
      -- only reload if it was not disabled using detach_from_buffer
      if BUFFER_OPTIONS[bufnr] then
        BUFFER_LOCAL[bufnr].__event = args.event
        if args.event == "TextChanged" or args.event == "InsertLeave" then
          rehighlight_buffer(bufnr, options, BUFFER_LOCAL[bufnr])
        else
          local pos = vim.fn.getpos "."
          BUFFER_LOCAL[bufnr].__startline = pos[2] - 1
          BUFFER_LOCAL[bufnr].__endline = pos[2]
          rehighlight_buffer(bufnr, options, BUFFER_LOCAL[bufnr], true)
        end
      end
    end,
  })

  autocmds[#autocmds + 1] = autocmd({ "WinScrolled" }, {
    group = au_group_id,
    buffer = bufnr,
    callback = function(args)
      -- only reload if it was not disabled using detach_from_buffer
      if BUFFER_OPTIONS[bufnr] then
        BUFFER_LOCAL[bufnr].__event = args.event
        rehighlight_buffer(bufnr, options, BUFFER_LOCAL[bufnr])
      end
    end,
  })

  autocmd({ "BufUnload", "BufDelete" }, {
    group = au_group_id,
    buffer = bufnr,
    callback = function()
      if BUFFER_OPTIONS[bufnr] then
        colorizer.detach_from_buffer(bufnr)
      end
      BUFFER_LOCAL[bufnr].__init = nil
    end,
  })

  BUFFER_LOCAL[bufnr].__autocmds = autocmds
  BUFFER_LOCAL[bufnr].__augroup_id = au_group_id
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
--      user_default_options,
--      -- all the sub-options of filetypes apply to buftypes
--      buftypes = {},
--    }
--</pre>
--For all user_default_options, see |user_default_options|
---@param config table: Config containing above parameters.
---@usage `require'colorizer'.setup()`
function colorizer.setup(config)
  if not vim.opt.termguicolors then
    vim.schedule(function()
      vim.notify("Colorizer: Error: &termguicolors must be set", 4)
    end)
    return
  end

  local conf = vim.deepcopy(config) or {}

  -- if nothing given the enable for all filetypes
  local filetypes = conf.filetypes or conf[1] or { "*" }
  local user_default_options = conf.user_default_options or conf[2] or {}
  local buftypes = conf.buftypes or conf[3] or nil

  OPTIONS = { buftype = {}, filetype = {} }
  SETUP_SETTINGS = {
    exclusions = { buftype = {}, filetype = {} },
    all = { buftype = false, filetype = false },
    default_options = user_default_options,
  }
  BUFFER_OPTIONS, BUFFER_LOCAL = {}, {}

  local function COLORIZER_SETUP_HOOK(bo_type)
    local filetype = vim.bo.filetype
    local buftype = vim.bo.buftype
    local bufnr = current_buf()
    BUFFER_LOCAL[bufnr] = BUFFER_LOCAL[bufnr] or {}

    if SETUP_SETTINGS.exclusions.filetype[filetype] or SETUP_SETTINGS.exclusions.buftype[buftype] then
      -- when a filetype is disabled but buftype is enabled, it can Attach in
      -- some cases, so manually detach
      if BUFFER_OPTIONS[bufnr] then
        colorizer.detach_from_buffer(bufnr)
      end
      BUFFER_LOCAL[bufnr].__init = nil
      return
    end

    local fopts, bopts, options = OPTIONS[bo_type][filetype], OPTIONS[bo_type][buftype], nil
    if bo_type == "filetype" then
      options = fopts
      -- if buffer and filetype options both are given, then prefer fileoptions
    elseif fopts and bopts then
      options = fopts
    else
      options = bopts
    end

    if not options and not SETUP_SETTINGS.all[bo_type] then
      return
    end

    options = options or SETUP_SETTINGS.default_options

    -- this should ideally be triggered one time per buffer
    -- but BufWinEnter also triggers for split formation
    -- but we don't want that so add a check using local buffer variable
    if not BUFFER_LOCAL[bufnr].__init then
      colorizer.attach_to_buffer(bufnr, options, bo_type)
    end
  end

  AUGROUP_ID = augroup(AUGROUP_NAME, {})

  local aucmd = { buftype = "BufWinEnter", filetype = "FileType" }
  local function parse_opts(bo_type, tbl)
    if type(tbl) == "table" then
      local list = {}

      for k, v in pairs(tbl) do
        local value
        local options = SETUP_SETTINGS.default_options
        if type(k) == "string" then
          value = k
          if type(v) ~= "table" then
            vim.notify(string.format("colorizer: Invalid option type for %s", value), 4)
          else
            options = merge(SETUP_SETTINGS.default_options, v)
          end
        else
          value = v
        end
        -- Exclude
        if value:sub(1, 1) == "!" then
          SETUP_SETTINGS.exclusions[bo_type][value:sub(2)] = true
        else
          OPTIONS[bo_type][value] = options
          if value == "*" then
            SETUP_SETTINGS.all[bo_type] = true
          else
            table.insert(list, value)
          end
        end
      end
      autocmd({ aucmd[bo_type] }, {
        group = AUGROUP_ID,
        pattern = bo_type == "filetype" and (SETUP_SETTINGS.all[bo_type] and "*" or list) or nil,
        callback = function()
          COLORIZER_SETUP_HOOK(bo_type)
        end,
      })
    elseif tbl then
      vim.notify_once(string.format("colorizer: Invalid type for %ss %s", bo_type, vim.inspect(tbl)), 4)
    end
  end

  parse_opts("filetype", filetypes)
  parse_opts("buftype", buftypes)

  autocmd("ColorScheme", {
    group = AUGROUP_ID,
    callback = function()
      require("colorizer").clear_highlight_cache()
    end,
  })
end

--- Return the currently active buffer options.
---@param bufnr number|nil: buffer number (0 for current)
---@return table|nil
function colorizer.get_buffer_options(bufnr)
  local buffer = colorizer.is_buffer_attached(bufnr)
  if buffer then
    return BUFFER_OPTIONS[buffer]
  end
end

--- Reload all of the currently active highlighted buffers.
function colorizer.reload_all_buffers()
  for bufnr, _ in pairs(BUFFER_OPTIONS) do
    colorizer.attach_to_buffer(bufnr, colorizer.get_buffer_options(bufnr), "buftype")
  end
end

--- Clear the highlight cache and reload all buffers.
function colorizer.clear_highlight_cache()
  clear_hl_cache()
  vim.schedule(colorizer.reload_all_buffers)
end

return colorizer
