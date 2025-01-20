--[[-- Requires Neovim >= 0.7.0 and `set termguicolors`

Highlights terminal CSI ANSI color codes.
@module colorizer
@usage Establish the autocmd to highlight all filetypes.

      `lua require("colorizer").setup()`

Highlight using all css highlight modes in every filetype

      `lua require("colorizer").setup(user_default_options = { css = true })`

==============================================================================
USE WITH COMMANDS                                          *colorizer-commands*

  *:ColorizerAttachToBuffer*

      Attach to the current buffer and start continuously highlighting
      matched color names and codes.

      If the buffer was already attached(i.e. being highlighted), the
      settings will be reloaded. This is useful for reloading settings for
      just one buffer.

  *:ColorizerDetachFromBuffer*

      Stop highlighting the current buffer (detach).

  *:ColorizerReloadAllBuffers*

      Reload all buffers that are being highlighted currently.
      Calls ColorizerAttachToBuffer on every buffer.

  *:ColorizerToggle*
      Toggle highlighting of the current buffer.

USE WITH LUA

ATTACH
  Accepts buffer number (0 or nil for current) and an option
  table of user_default_options from `setup`.  Option table can be nil
  which defaults to setup options.

      Attach to current buffer with local options:
          require("colorizer").attach_to_buffer(0, {
            mode = "background",
            css = false,
          })

      Attach to current buffer with setup options:
          require("colorizer").attach_to_buffer()

          Accepts an optional buffer number (0 or nil for current).  Defaults to
          current buffer.

DETACH

      Detach to buffer with id 22:
          require("colorizer").attach_to_buffer(22)

      Detach from current buffer:
          require("colorizer").detach_from_buffer(0)
          require("colorizer").detach_from_buffer()

      Detach from buffer with id 22:
          require("colorizer").detach_from_buffer(22)
]]
-- @see colorizer.setup
-- @see colorizer.attach_to_buffer
-- @see colorizer.detach_from_buffer
local M = {}

local buffer = require("colorizer.buffer")
local config = require("colorizer.config")
local const = require("colorizer.constants")
local utils = require("colorizer.utils")

--- State and configuration dynamic holding information table tracking
local colorizer_state = {
  -- augroup: augroup id
  augroup = vim.api.nvim_create_augroup(const.autocmd.setup, { clear = true }),
  -- buffer_current: store the current buffer number to prevent rehighlighting the current buffer
  buffer_current = 0,
  -- buffer_lines: store the current window position to be used later to incremently highlight
  buffer_lines = {},
  -- buffer_local: store buffer local options
  -- __init: whether the buffer has been initialized
  -- __autocmds: list of autocmds attached to buffer
  -- __detach: detach settings table to use when cleaning up buffer state in `colorizer.detach_from_buffer`
  -- __startline: start line of the current window
  -- __endline: end line of the current window
  -- __event: event that triggered the autocmd
  -- __augroup_id: augroup id
  buffer_local = {},
  -- buffer_options: store buffer options
  buffer_options = {},
  -- buffer_reload: store buffer reload state
  buffer_reload = {},
}

--- Highlight the buffer region.
---@function highlight_buffer
---@see colorizer.buffer.highlight
M.highlight_buffer = buffer.highlight

--- Get the row range of the current window
---@param bufnr number: Buffer number
local function row_range(bufnr)
  colorizer_state.buffer_lines[bufnr] = colorizer_state.buffer_lines[bufnr] or {}
  local new_min, new_max = utils.visible_line_range(bufnr)
  local old_min = colorizer_state.buffer_lines[bufnr]["min"]
  local old_max = colorizer_state.buffer_lines[bufnr]["max"]
  local min, max
  if old_min and old_max then
    if (old_max == new_max) or (old_min == new_min) then
      -- TextChanged autocmd
      min, max = new_min, new_max
    elseif old_max < new_max then
      -- Scroll Down
      min = old_max
      max = new_max
    elseif old_max > new_max then
      -- Scroll Up
      min = new_min
      max = new_min + (old_max - new_max)
    end
    -- Handle large jumps
    if max - min > new_max - new_min then
      min = new_min
      max = new_max
    end
  else
    -- First time initialization
    min, max = new_min, new_max
  end
  -- Ensure ranges are clamped to new_min and new_max
  min = math.max(new_min, min or new_min)
  max = math.min(new_max, max or new_max)
  -- Store current window position for future use to incrementally highlight
  colorizer_state.buffer_lines[bufnr]["min"] = new_min
  colorizer_state.buffer_lines[bufnr]["max"] = new_max
  return min, max
end

--- Rehighlight the buffer if colorizer is active
---@param bufnr number: Buffer number (0 for current)
---@param ud_opts table: `user_default_options`
---@param buf_local_opts table|nil: Buffer local options
---@param hl_opts table|nil: Highlighting options
--- - use_local_lines: boolean: Use `buf_local_opts` __startline and __endline for lines
---@return table: Detach settings table to use when cleaning up buffer state in `colorizer.detach_from_buffer`
--- - ns_id number: Table of namespace ids to clear
--- - functions function: Table of detach functions to call
function M.rehighlight(bufnr, ud_opts, buf_local_opts, hl_opts)
  hl_opts = hl_opts or {}
  bufnr = utils.bufme(bufnr)

  local line_start, line_end
  if hl_opts.use_local_lines and buf_local_opts then
    line_start, line_end = buf_local_opts.__startline or 0, buf_local_opts.__endline or -1
  else
    line_start, line_end = row_range(bufnr)
  end

  local detach = M.highlight_buffer(
    bufnr,
    const.namespace.default,
    line_start,
    line_end,
    ud_opts,
    buf_local_opts or {}
  )
  table.insert(detach.functions, function()
    colorizer_state.buffer_lines[bufnr] = nil
  end)

  return detach
end

---Get attached bufnr
---@param bufnr number|nil: buffer number (0 for current)
---@return number: Returns attached bufnr. Returns -1 if buffer is not attached to colorizer.
---@see colorizer.buffer.highlight
function M.get_attached_bufnr(bufnr)
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

---Check if buffer is attached to colorizer
---@param bufnr number|nil: buffer number (0 for current)
---@return boolean: Returns `true` if buffer is attached to colorizer.
function M.is_buffer_attached(bufnr)
  return M.get_attached_bufnr(bufnr) > -1
end

--- Return buffer options if buffer is attached to colorizer.
---@param bufnr number: Buffer number (0 for current)
---@return table|nil
local function get_attached_buffer_options(bufnr)
  local attached_bufnr = M.get_attached_bufnr(bufnr)
  if attached_bufnr > -1 then
    return colorizer_state.buffer_options[attached_bufnr]
  end
end

--- Reload all of the currently active highlighted buffers.
function M.reload_all_buffers()
  for bufnr, _ in pairs(colorizer_state.buffer_options) do
    bufnr = utils.bufme(bufnr)
    M.attach_to_buffer(bufnr, get_attached_buffer_options(bufnr), "buftype")
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

          vim.schedule(function()
            -- mimic bo_type_setup() function within colorizer.setup
            local bo_type = "filetype"
            local ud_opts = config.get_bo_options(bo_type, vim.bo.buftype, vim.bo.filetype)
            M.attach_to_buffer(evt.buf, ud_opts, bo_type)
            vim.notify(
              "Colorizer reloaded with updated options from " .. evt.match,
              vim.log.levels.INFO
            )
          end)
        end
      end)
    end,
  })
end

---Attach to a buffer and continuously highlight changes.
---@param bufnr number|nil: buffer number (0 for current)
---@param ud_opts table|nil: `user_default_options`
---@param bo_type 'buftype'|'filetype'|nil: The type of buffer option
function M.attach_to_buffer(bufnr, ud_opts, bo_type)
  bufnr = utils.bufme(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    colorizer_state.buffer_local[bufnr], colorizer_state.buffer_options[bufnr] = nil, nil
    return
  end

  bo_type = bo_type or "buftype"

  ud_opts = ud_opts
    -- options for filetype
    or config.options.filetypes[vim.bo.filetype]
    -- cached buffer options
    or get_attached_buffer_options(bufnr)
    -- new buffer options
    or config.new_bo_options(bufnr, bo_type)

  -- Applying alias options also validates options, for example converts `tailwind = true` to `tailwind = "normal"`.  This makes later options checks easier
  ud_opts = config.apply_alias_options(ud_opts)

  colorizer_state.buffer_options[bufnr] = ud_opts
  colorizer_state.buffer_local[bufnr] = colorizer_state.buffer_local[bufnr] or {}

  local detach = M.rehighlight(bufnr, ud_opts)

  colorizer_state.buffer_local[bufnr].__detach = colorizer_state.buffer_local[bufnr].__detach
    or detach
  colorizer_state.buffer_local[bufnr].__init = true

  if colorizer_state.buffer_local[bufnr].__autocmds then
    return
  end

  if colorizer_state.buffer_current == 0 then
    colorizer_state.buffer_current = bufnr
  end

  if ud_opts.always_update then
    -- attach using lua api so buffer gets updated even when not the current buffer
    -- completely moving to buf_attach is not possible because it doesn't handle all the text change events
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = function(_, _bufnr)
        -- only reload if the buffer is not the current one
        if not (colorizer_state.buffer_current == _bufnr) then
          -- only reload if it was not disabled using detach_from_buffer
          if colorizer_state.buffer_options[bufnr] then
            M.rehighlight(bufnr, ud_opts, colorizer_state.buffer_local[bufnr])
          end
        end
      end,
      on_reload = function(_, _bufnr)
        -- only reload if the buffer is not the current one
        if not (colorizer_state.buffer_current == _bufnr) then
          -- only reload if it was not disabled using detach_from_buffer
          if colorizer_state.buffer_options[bufnr] then
            M.rehighlight(bufnr, ud_opts, colorizer_state.buffer_local[bufnr])
          end
        end
      end,
    })
  end

  local autocmds = {}
  local text_changed_au = { "TextChanged", "TextChangedI", "TextChangedP" }
  -- Only enable InsertLeave in sass mode, other modes do not require it
  if ud_opts.sass and ud_opts.sass.enable then
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
          M.rehighlight(bufnr, ud_opts, colorizer_state.buffer_local[bufnr])
        else
          local pos = vim.fn.getpos(".")
          colorizer_state.buffer_local[bufnr].__startline = pos[2] - 1
          colorizer_state.buffer_local[bufnr].__endline = pos[2]
          M.rehighlight(
            bufnr,
            ud_opts,
            colorizer_state.buffer_local[bufnr],
            { use_local_lines = true }
          )
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
        M.rehighlight(bufnr, ud_opts, colorizer_state.buffer_local[bufnr])
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
---@return number: returns -1 if buffer is not attached, otherwise returns bufnr
function M.detach_from_buffer(bufnr)
  bufnr = utils.bufme(bufnr)
  bufnr = M.get_attached_bufnr(bufnr)
  if bufnr < 0 then
    return -1
  end
  for _, ns_id in pairs(const.namespace) do
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end
  vim.api.nvim_buf_clear_namespace(bufnr, const.namespace.default, 0, -1)
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
  return bufnr
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

  colorizer_state = {
    augroup = vim.api.nvim_create_augroup("ColorizerSetup", { clear = true }),
    buffer_current = 0,
    buffer_lines = {},
    buffer_local = {},
    buffer_options = {},
    buffer_reload = {},
  }
  require("colorizer.matcher").reset_cache()
  require("colorizer.parser.names").reset_cache()
  require("colorizer.buffer").reset_cache()

  local s = config.get_setup_options(opts)

  -- Setup the buffer with the correct options
  local function bo_type_setup(bo_type)
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

    -- get cached options
    local ud_opts = config.get_bo_options(bo_type, buftype, filetype)
    if not ud_opts and not s.all[bo_type] then
      return
    end

    -- Multiple autocmd events can try to attach to buffer
    -- check if buffer has already been initialized before attaching
    if not colorizer_state.buffer_local[bufnr].__init then
      M.attach_to_buffer(bufnr, ud_opts, bo_type)
    end
  end

  -- Setup highlighting autocmds for filetypes and buftypes
  local bo_type_options = {
    filetype = s.filetypes,
    buftype = s.buftypes,
  }
  for bo_type, bo_type_option in pairs(bo_type_options) do
    local list = {}
    for k, v in pairs(bo_type_option) do
      local value
      local ud_opts = s.user_default_options
      if type(k) == "string" then
        value = k
        if type(v) ~= "table" then
          vim.notify(string.format("colorizer: Invalid option type for %s", value), 4)
        else
          ud_opts = vim.tbl_extend("force", ud_opts, v)
        end
      else
        value = v
      end
      -- Exclude or set buffer options
      if value:sub(1, 1) == "!" then
        s.exclusions[bo_type][value:sub(2)] = true
      else
        config.set_bo_value(bo_type, value, ud_opts)
        if value == "*" then
          s.all[bo_type] = true
        else
          table.insert(list, value)
        end
      end
    end
    vim.api.nvim_create_autocmd({ const.autocmd.bo_type_ac[bo_type] }, {
      group = colorizer_state.augroup,
      pattern = bo_type == "filetype" and (s.all[bo_type] and "*" or list) or nil,
      callback = function()
        if s.lazy_load then
          vim.schedule(function()
            bo_type_setup(bo_type)
          end)
        else
          bo_type_setup(bo_type)
        end
      end,
    })
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
  buffer.reset_cache()
  vim.schedule(M.reload_all_buffers)
end

return M
