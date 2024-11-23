--- Requires Neovim >= 0.7.0 and `set termguicolors`
--
--Highlights terminal CSI ANSI color codes.
-- @module colorizer
-- @author Ashkan Kiani <from-nvim-colorizer.lua@kiani.io>
-- @usage Establish the autocmd to highlight all filetypes.
--
--       `lua require("colorizer").setup()`
--
-- Highlight using all css highlight modes in every filetype
--
--       `lua require("colorizer").setup(user_default_options = { css = true })`
--
--==============================================================================
--USE WITH COMMANDS                                          *colorizer-commands*
--
--   *:ColorizerAttachToBuffer*
--
--       Attach to the current buffer and start continuously highlighting
--       matched color names and codes.
--
--       If the buffer was already attached(i.e. being highlighted), the
--       settings will be reloaded. This is useful for reloading settings for
--       just one buffer.
--
--   *:ColorizerDetachFromBuffer*
--
--       Stop highlighting the current buffer (detach).
--
--   *:ColorizerReloadAllBuffers*
--
--       Reload all buffers that are being highlighted currently.
--       Calls ColorizerAttachToBuffer on every buffer.
--
--   *:ColorizerToggle*
--       Toggle highlighting of the current buffer.
--
--USE WITH LUA
--
--Attach
--       Accepts buffer number (0 or nil for current) and an option
--       table of user_default_options from `setup`.  Option table can be nil
--       which defaults to setup options
--
--       Attach to current buffer with local options <pre>
--           require("colorizer").attach_to_buffer(0, {
--             mode = "background",
--             css = false,
--           })
--</pre>
--
--       Attach to current buffer with setup options <pre>
--           require("colorizer").attach_to_buffer(0, {
--             mode = "background",
--             css = false,
--           })
--</pre>
--
--       Accepts an optional buffer number (0 or nil for current).  Defaults to
--       current buffer.
--
--Detach
--
--       Detach to buffer with id 22 <pre>
--           require("colorizer").attach_to_buffer(22)
--</pre>
--
--       Detach from current buffer <pre>
--           require("colorizer").detach_from_buffer(0)
--           require("colorizer").detach_from_buffer()
--</pre>
--
--       Detach from buffer with id 22 <pre>
--           require("colorizer").detach_from_buffer(22)
--</pre>

-- @see colorizer.setup
-- @see colorizer.attach_to_buffer
-- @see colorizer.detach_from_buffer

local M = {}

local buffer = require("colorizer.buffer")
local config = require("colorizer.config")
local utils = require("colorizer.utils")

--- State and configuration dynamic holding information table tracking
local colorizer_state = {
  augroup = vim.api.nvim_create_augroup("ColorizerSetup", {}),
  buffer_current = 0,
  buffer_lines = {},
  buffer_local = {},
  buffer_options = {},
  buffer_reload = {},
}

--- Highlight the buffer region.
---@function highlight_buffer
---@see colorizer.buffer.highlight
M.highlight_buffer = buffer.highlight

---Default namespace used in `colorizer.buffer.highlight` and `attach_to_buffer`.
---@string: default_namespace
---@see colorizer.buffer.default_namespace
M.default_namespace = buffer.default_namespace

--- Get the row range of the current window
---@param bufnr number: Buffer number
local function getrow(bufnr)
  colorizer_state.buffer_lines[bufnr] = colorizer_state.buffer_lines[bufnr] or {}
  local a = vim.api.nvim_buf_call(bufnr, function()
    return {
      vim.fn.line("w0"),
      vim.fn.line("w$"),
    }
  end)
  local min, max
  local new_min, new_max = a[1] - 1, a[2]
  local old_min, old_max =
    colorizer_state.buffer_lines[bufnr]["min"], colorizer_state.buffer_lines[bufnr]["max"]
  if old_min and old_max then
    -- Triggered for TextChanged autocmds
    -- TODO: Find a way to just apply highlight to changed text lines
    if (old_max == new_max) or (old_min == new_min) then
      min, max = new_min, new_max
    -- Triggered for WinScrolled autocmd - Scroll Down
    elseif old_max < new_max then
      min = old_max
      max = new_max
    -- Triggered for WinScrolled autocmd - Scroll Up
    elseif old_max > new_max then
      min = new_min
      max = new_min + (old_max - new_max)
    end
    -- just in case a long jump was made
    if max - min > new_max - new_min then
      min = new_min
      max = new_max
    end
  end
  min = min or new_min
  max = max or new_max
  -- store current window position to be used later to incremently highlight
  colorizer_state.buffer_lines[bufnr]["max"] = new_max
  colorizer_state.buffer_lines[bufnr]["min"] = new_min
  return min, max
end

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
    min, max = getrow(bufnr)
  end

  local bool, returns = M.highlight_buffer(bufnr, ns_id, min, max, options, options_local or {})
  table.insert(returns.detach.functions, function()
    colorizer_state.buffer_lines[bufnr] = nil
  end)

  return bool, returns
end

---Check if attached to a buffer
---@param bufnr number|nil: buffer number (0 for current)
---@return number: returns bufnr if attached, otherwise -1
---@see colorizer.buffer.highlight
function M.is_buffer_attached(bufnr)
  if bufnr == 0 or not bufnr then
    bufnr = utils.bufme(bufnr)
  else
    if not vim.api.nvim_buf_is_valid(bufnr) then
      colorizer_state.buffer_local[bufnr], colorizer_state.buffer_options[bufnr] = nil, nil
      return -1
    end
  end
  local au = vim.api.nvim_get_autocmds({
    group = colorizer_state.augroup,
    event = { "WinScrolled", "TextChanged", "TextChangedI", "TextChangedP" },
    buffer = bufnr,
  })
  if not colorizer_state.buffer_options[bufnr] or vim.tbl_isempty(au) then
    return -1
  end
  return bufnr
end

--- Return the currently active buffer options.
---@param bufnr number: Buffer number (0 for current)
---@return table|nil
local function get_buffer_options(bufnr)
  local attached_bufnr = M.is_buffer_attached(bufnr)
  if attached_bufnr > -1 then
    return colorizer_state.buffer_options[attached_bufnr]
  end
end

--- Reload all of the currently active highlighted buffers.
function M.reload_all_buffers()
  for bufnr, _ in pairs(colorizer_state.buffer_options) do
    bufnr = utils.bufme(bufnr)
    M.attach_to_buffer(bufnr, get_buffer_options(bufnr), "buftype")
  end
end

--- Reload file on save; used for dev, to edit expect.txt and apply highlights from returned setup table
---@param pattern string: pattern to match file name
function M.reload_on_save(pattern)
  local bufnr = utils.bufme()
  if colorizer_state.buffer_reload[bufnr] then
    return
  else
    colorizer_state.buffer_reload[bufnr] = true
  end
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("ColorizerReload", {}),
    pattern = pattern,
    callback = function(evt)
      vim.schedule(function()
        local success, opts = pcall(dofile, evt.match)
        if not success or type(opts) ~= "table" then
          vim.notify("Failed to load options from " .. evt.match, vim.log.levels.ERROR)
          return
        end
        if opts then
          local buffer_reload = vim.deepcopy(colorizer_state.buffer_reload)
          M.setup(opts)
          -- restore buffer reload state after setup
          colorizer_state.buffer_reload = buffer_reload
          M.attach_to_buffer()
          vim.notify(
            "Colorizer reloaded with updated options from " .. evt.match,
            vim.log.levels.INFO
          )
        end
      end)
    end,
  })
end

---Attach to a buffer and continuously highlight changes.
---@param bufnr number|nil: buffer number (0 for current)
---@param options table|nil: Configuration options as described in `setup`
---@param bo_type 'buftype'|'filetype'|nil: The type of buffer option
function M.attach_to_buffer(bufnr, options, bo_type)
  bufnr = utils.bufme(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    colorizer_state.buffer_local[bufnr], colorizer_state.buffer_options[bufnr] = nil, nil
    return
  end
  --  TODO: 2024-11-22 - When attaching using user command does this respect buffer settings?
  options = options or config.setup_options.filetypes[vim.bo.filetype] or {}
  --  TODO: 2024-11-22 - Why default to "buftype"?
  bo_type = vim.tbl_contains({ "buftype", "filetype" }, bo_type) and bo_type or "buftype"

  -- check if options is empty table
  options = next(options) and options
    -- cached buffer options
    or get_buffer_options(bufnr)
    -- new buffer options
    or config.new_buffer_options(bufnr, bo_type)
  options = config.parse_buffer_options(options)

  if not buffer.highlight_mode_names[options.mode] then
    local default = "background"
    if options.mode ~= nil then
      local mode = options.mode
      vim.defer_fn(function()
        vim.notify_once(
          string.format(
            "Warning: Invalid mode given to colorizer setup [ %s ], setting to '%s'",
            mode,
            default
          )
        )
      end, 0)
    end
    options.mode = default
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
function M.detach_from_buffer(bufnr)
  bufnr = utils.bufme(bufnr)
  bufnr = M.is_buffer_attached(bufnr)
  if bufnr < 0 then
    return -1
  end
  vim.api.nvim_buf_clear_namespace(bufnr, buffer.default_namespace, 0, -1)
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
---Setup colorizer with user options
---@param opts table|nil: User provided options
---@usage `require("colorizer").setup()`
---@see colorizer.config
function M.setup(opts)
  if not vim.opt.termguicolors then
    vim.schedule(function()
      vim.notify("Colorizer: Error: &termguicolors must be set", 4)
    end)
    return
  end

  local s = config.get_settings(opts)
  colorizer_state = {
    augroup = vim.api.nvim_create_augroup("ColorizerSetup", { clear = true }),
    buffer_current = 0,
    buffer_lines = {},
    buffer_local = {},
    buffer_options = {},
    buffer_reload = {},
  }

  -- Setup the buffer with the correct options
  local function setup(bo_type)
    local filetype = vim.bo.filetype
    local buftype = vim.bo.buftype
    local bufnr = utils.bufme()
    colorizer_state.buffer_local[bufnr] = colorizer_state.buffer_local[bufnr] or {}
    if s.exclusions.filetype[filetype] or s.exclusions.buftype[buftype] then
      -- when a filetype is disabled but buftype is enabled, it can Attach in
      -- some cases, so manually detach
      if colorizer_state.buffer_options[bufnr] then
        M.detach_from_buffer(bufnr)
      end
      colorizer_state.buffer_local[bufnr].__init = nil
      return
    end
    local options = config.get_options(bo_type, buftype, filetype)
    if not options and not s.all[bo_type] then
      return
    end
    options = options or s.default_options
    -- this should ideally be triggered one time per buffer
    -- but BufWinEnter also triggers for split formation
    -- but we don't want that so add a check using local buffer variable
    if not colorizer_state.buffer_local[bufnr].__init then
      M.attach_to_buffer(bufnr, options, bo_type)
    end
  end

  -- Setup highlighting autocmds for filetypes and buftypes
  local events = { buftype = "BufWinEnter", filetype = "FileType" }
  local opt_types = {
    filetype = s.filetypes,
    buftype = s.buftypes,
  }
  for bo_type, opt_type in pairs(opt_types) do
    if type(opt_type) ~= "table" then
      vim.notify_once(
        string.format("colorizer: Invalid type for %ss %s", bo_type, vim.inspect(opt_type)),
        4
      )
    else
      local list = {}
      for k, v in pairs(opt_type) do
        local value
        local options = s.default_options
        if type(k) == "string" then
          value = k
          if type(v) ~= "table" then
            vim.notify(string.format("colorizer: Invalid option type for %s", value), 4)
          else
            options = utils.merge(s.default_options, v)
          end
        else
          value = v
        end
        -- Exclude or set buffer options
        if value:sub(1, 1) == "!" then
          s.exclusions[bo_type][value:sub(2)] = true
        else
          config.set_bo_value(bo_type, value, options)
          if value == "*" then
            s.all[bo_type] = true
          else
            table.insert(list, value)
          end
        end
      end
      vim.api.nvim_create_autocmd({ events[bo_type] }, {
        group = colorizer_state.augroup,
        pattern = bo_type == "filetype" and (s.all[bo_type] and "*" or list) or nil,
        callback = function()
          setup(bo_type)
        end,
      })
    end
  end

  -- Clear highlight cache on colorscheme change
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = colorizer_state.augroup,
    callback = M.clear_highlight_cache,
  })

  --  TODO: 2024-11-23 - Delete user commands first
  require("colorizer.usercmds").make(s.user_commands)
end

--- Clears the highlight cache and reloads all buffers.
function M.clear_highlight_cache()
  buffer.clear_hl_cache()
  vim.schedule(M.reload_all_buffers)
end

return M
