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

local M = {}

local buffer = require("colorizer.buffer")
local config = require("colorizer.config")
local utils = require("colorizer.utils")

--- State and configuration dynamic holding information table tracking
---@class colorizerState
local colorizer_state = {
  --- Table storing options for each buffer, keyed by buffer number
  --- @type table<number, table>
  buffer_options = {},
  --- Table storing local buffer-specific configurations and resources for each buffer, keyed by buffer number
  --- @type table<number, table>
  buffer_local = {},
  --- Current buffer ID being processed for colorizer updates
  --- @type number
  buffer_current = 0,
  --- Autocommand group ID used for setting up and managing Colorizer's autocommands
  --- @type number
  augroup = vim.api.nvim_create_augroup("ColorizerSetup", {}),
  --- Buffer lines cache
  buffer_lines = {},
}

-- get the amount lines to highlight
---@function highlight_buffer
---@see colorizer.buffer.highlight
M.highlight_buffer = buffer.highlight

---Default namespace used in `colorizer.buffer.highlight` and `attach_to_buffer`.
---@string: default_namespace
---@see colorizer.buffer.default_namespace
M.default_namespace = buffer.default_namespace

--- Rehighlight the buffer if colorizer is active
---@param bufnr number: buffer number (0 for current)
---@param options table: Buffer options
---@param options_local table|nil: Buffer local variables
---@param use_local_lines boolean|nil Whether to use lines num range from options_local
---@return nil|boolean|number,table
function M.rehighlight(bufnr, options, options_local, use_local_lines)
  bufnr = utils.bufme(bufnr)
  local ns_id = M.default_namespace

  local min, max
  if use_local_lines and options_local then
    min, max = options_local.__startline or 0, options_local.__endline or -1
  else
    min, max = utils.getrow(colorizer_state, bufnr)
  end

  local bool, returns = M.highlight_buffer(bufnr, ns_id, min, max, options, options_local or {})
  table.insert(returns.detach.functions, function()
    colorizer_state.buffer_lines[bufnr] = nil
  end)

  return bool, returns
end

---Colorizer state
---@param bufnr number|nil: A value of 0 implies the current buffer.
---@return number|nil: if attached to the buffer, false otherwise.
---@see colorizer.buffer.highlight
function M.is_buffer_attached(bufnr)
  if bufnr == 0 or not bufnr then
    bufnr = utils.bufme(bufnr)
  else
    if not vim.api.nvim_buf_is_valid(bufnr) then
      colorizer_state.buffer_local[bufnr], colorizer_state.buffer_options[bufnr] = nil, nil
      return
    end
  end
  local au = vim.api.nvim_get_autocmds({
    group = colorizer_state.augroup,
    event = { "WinScrolled", "TextChanged", "TextChangedI", "TextChangedP" },
    buffer = bufnr,
  })
  if not colorizer_state.buffer_options[bufnr] or vim.tbl_isempty(au) then
    return
  end
  return bufnr
end

--- Return the currently active buffer options.
---@param bufnr number|nil: buffer number (0 for current)
---@return table|nil
function M.get_buffer_options(bufnr)
  bufnr = utils.bufme(bufnr)
  local _bufnr = M.is_buffer_attached(bufnr)
  if _bufnr then
    return colorizer_state.buffer_options[_bufnr]
  end
end

--- Parse buffer Configuration and convert aliases to normal values
---@param options table: options table
---@return table
local function parse_buffer_options(options)
  local includes = {
    ["css"] = { "names", "RGB", "RRGGBB", "RRGGBBAA", "hsl_fn", "rgb_fn" },
    ["css_fn"] = { "hsl_fn", "rgb_fn" },
  }
  local default_opts = config.user_default_options

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

  options = utils.merge(default_opts, options)
  return options
end

--- Reload all of the currently active highlighted buffers.
function M.reload_all_buffers()
  for bufnr, _ in pairs(colorizer_state.buffer_options) do
    bufnr = utils.bufme(bufnr)
    M.attach_to_buffer(bufnr, M.get_buffer_options(bufnr), "buftype")
  end
end

---Attach to a buffer and continuously highlight changes.
---@param bufnr number|nil: buffer number (0 for current)
---@param options table|nil: Configuration options as described in `setup`
---@param bo_type 'buftype'|'filetype'|nil: The type of buffer option
function M.attach_to_buffer(bufnr, options, bo_type)
  bufnr = utils.bufme(bufnr)
  bo_type = bo_type or "buftype"
  if not vim.api.nvim_buf_is_valid(bufnr) then
    colorizer_state.buffer_local[bufnr], colorizer_state.buffer_options[bufnr] = nil, nil
    return
  end
  -- set options by grabbing existing or creating new options, then parsing
  options = parse_buffer_options(
    options or M.get_buffer_options(bufnr) or config.new_buffer_options(bufnr, bo_type)
  )

  if not buffer.highlight_mode_names[options.mode] then
    if options.mode ~= nil then
      local mode = options.mode
      vim.defer_fn(function()
        -- just notify the user once
        vim.notify_once(
          string.format("Warning: Invalid mode given to colorizer setup [ %s ]", mode)
        )
      end, 0)
    end
    options.mode = "background"
  end

  colorizer_state.buffer_options[bufnr] = options
  colorizer_state.buffer_local[bufnr] = colorizer_state.buffer_local[bufnr] or {}
  local highlighted, returns = M.rehighlight(bufnr, options)

  if not highlighted then
    return
  end

  colorizer_state.buffer_local[bufnr].__detach = colorizer_state.buffer_local[bufnr].__detach
    or returns.detach
  colorizer_state.buffer_local[bufnr].__init = true

  if colorizer_state.buffer_local[bufnr].__autocmds then
    return
  end

  if colorizer_state.buffer_current == 0 then
    colorizer_state.buffer_current = bufnr
  end

  if options.always_update then
    -- attach using lua api so buffer gets updated even when not the current buffer
    -- completely moving to buf_attach is not possible because it doesn't handle all the text change events
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = function(_, _bufnr)
        -- only reload if the buffer is not the current one
        if not (colorizer_state.buffer_current == _bufnr) then
          -- only reload if it was not disabled using detach_from_buffer
          if colorizer_state.buffer_options[bufnr] then
            M.rehighlight(bufnr, options, colorizer_state.buffer_local[bufnr])
          end
        end
      end,
      on_reload = function(_, _bufnr)
        -- only reload if the buffer is not the current one
        if not (colorizer_state.buffer_current == _bufnr) then
          -- only reload if it was not disabled using detach_from_buffer
          if colorizer_state.buffer_options[bufnr] then
            M.rehighlight(bufnr, options, colorizer_state.buffer_local[bufnr])
          end
        end
      end,
    })
  end

  local autocmds = {}
  local text_changed_au = { "TextChanged", "TextChangedI", "TextChangedP" }
  -- Only enable InsertLeave in sass mode, other modes do not require it
  if options.sass and options.sass.enable then
    table.insert(text_changed_au, "InsertLeave")
  end
  autocmds[#autocmds + 1] = vim.api.nvim_create_autocmd(text_changed_au, {
    group = colorizer_state.augroup,
    buffer = bufnr,
    callback = function(args)
      colorizer_state.buffer_current = bufnr
      -- Only reload if it was not disabled using detach_from_buffer
      if colorizer_state.buffer_options[bufnr] then
        colorizer_state.buffer_local[bufnr].__event = args.event
        if args.event == "TextChanged" or args.event == "InsertLeave" then
          M.rehighlight(bufnr, options, colorizer_state.buffer_local[bufnr])
        else
          local pos = vim.fn.getpos(".")
          colorizer_state.buffer_local[bufnr].__startline = pos[2] - 1
          colorizer_state.buffer_local[bufnr].__endline = pos[2]
          M.rehighlight(bufnr, options, colorizer_state.buffer_local[bufnr], true)
        end
      end
    end,
  })
  autocmds[#autocmds + 1] = vim.api.nvim_create_autocmd({ "WinScrolled" }, {
    group = colorizer_state.augroup,
    buffer = bufnr,
    callback = function(args)
      -- Only reload if it was not disabled using detach_from_buffer
      if colorizer_state.buffer_options[bufnr] then
        colorizer_state.buffer_local[bufnr].__event = args.event
        M.rehighlight(bufnr, options, colorizer_state.buffer_local[bufnr])
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
    group = colorizer_state.augroup,
    buffer = bufnr,
    callback = function()
      if colorizer_state.buffer_options[bufnr] then
        M.detach_from_buffer(bufnr)
      end
      colorizer_state.buffer_local[bufnr].__init = nil
    end,
  })
  colorizer_state.buffer_local[bufnr].__autocmds = autocmds
  colorizer_state.buffer_local[bufnr].__augroup_id = colorizer_state.augroup
end

--- Stop highlighting the current buffer.
---@param bufnr number|nil: buffer number (0 for current)
---@param ns_id number|nil: namespace id.  default is "colorizer", created with vim.api.nvim_create_namespace
function M.detach_from_buffer(bufnr, ns_id)
  bufnr = utils.bufme(bufnr)
  bufnr = M.is_buffer_attached(bufnr)
  if not bufnr then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id or buffer.default_namespace, 0, -1)
  if colorizer_state.buffer_local[bufnr] then
    for _, namespace in pairs(colorizer_state.buffer_local[bufnr].__detach.ns_id) do
      vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    end
    for _, f in pairs(colorizer_state.buffer_local[bufnr].__detach.functions) do
      if type(f) == "function" then
        f(bufnr)
      end
    end
    for _, id in ipairs(colorizer_state.buffer_local[bufnr].__autocmds or {}) do
      pcall(vim.api.nvim_del_autocmd, id)
    end
    colorizer_state.buffer_local[bufnr].__autocmds = nil
    colorizer_state.buffer_local[bufnr].__detach = nil
  end
  -- because now the buffer is not visible, so delete its information
  colorizer_state.buffer_options[bufnr] = nil
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
--      user_commands,
--      filetypes = { "*" },
--      user_default_options,
--      -- all the sub-options of filetypes apply to buftypes
--      buftypes = {},
--    }
--</pre>
--For all user_default_options, see |user_default_options|
---@param opts table: Config containing above parameters.
---@usage `require'colorizer'.setup()`
function M.setup(opts)
  if not vim.opt.termguicolors then
    vim.schedule(function()
      vim.notify("Colorizer: Error: &termguicolors must be set", 4)
    end)
    return
  end

  local conf = config.setup(opts)

  local function setup(bo_type)
    local filetype = vim.bo.filetype
    local buftype = vim.bo.buftype
    local bufnr = vim.api.nvim_get_current_buf()
    colorizer_state.buffer_local[bufnr] = colorizer_state.buffer_local[bufnr] or {}

    if conf.exclusions.filetype[filetype] or conf.exclusions.buftype[buftype] then
      -- when a filetype is disabled but buftype is enabled, it can Attach in
      -- some cases, so manually detach
      if colorizer_state.buffer_options[bufnr] then
        M.detach_from_buffer(bufnr)
      end
      colorizer_state.buffer_local[bufnr].__init = nil
      return
    end

    local fopts, bopts = config.get_options(bo_type, buftype, filetype)
    -- if buffer and filetype options both are given, then prefer fileoptions
    local options = bo_type == "filetype" and fopts or (fopts and fopts or bopts)

    if not options and not conf.all[bo_type] then
      return
    end

    options = options or conf.default_options

    -- this should ideally be triggered one time per buffer
    -- but BufWinEnter also triggers for split formation
    -- but we don't want that so add a check using local buffer variable
    if not colorizer_state.buffer_local[bufnr].__init then
      M.attach_to_buffer(bufnr, options, bo_type)
    end
  end

  local aucmd = { buftype = "BufWinEnter", filetype = "FileType" }
  local function parse_opts(bo_type, tbl)
    if type(tbl) == "table" then
      local list = {}
      for k, v in pairs(tbl) do
        local value
        local options = conf.default_options
        if type(k) == "string" then
          value = k
          if type(v) ~= "table" then
            vim.notify(string.format("colorizer: Invalid option type for %s", value), 4)
          else
            options = utils.merge(conf.default_options, v)
          end
        else
          value = v
        end
        -- Exclude
        if value:sub(1, 1) == "!" then
          conf.exclusions[bo_type][value:sub(2)] = true
        else
          config.set_bo_value(bo_type, value, options)
          if value == "*" then
            conf.all[bo_type] = true
          else
            table.insert(list, value)
          end
        end
      end
      vim.api.nvim_create_autocmd({ aucmd[bo_type] }, {
        group = colorizer_state.augroup,
        pattern = bo_type == "filetype" and (conf.all[bo_type] and "*" or list) or nil,
        callback = function()
          setup(bo_type)
        end,
      })
    elseif tbl then
      vim.notify_once(
        string.format("colorizer: Invalid type for %ss %s", bo_type, vim.inspect(tbl)),
        4
      )
    end
  end

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = colorizer_state.augroup,
    callback = function()
      require("colorizer").clear_highlight_cache()
    end,
  })

  parse_opts("filetype", conf.filetypes)
  parse_opts("buftype", conf.buftypes)

  require("colorizer.usercmds").make(conf.user_commands)
end

--- Clear the highlight cache and reload all buffers.
function M.clear_highlight_cache()
  utils.clear_hl_cache()
  vim.schedule(buffer.reload_all_buffers)
end

return M
