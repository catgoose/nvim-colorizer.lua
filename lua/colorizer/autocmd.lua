local M = {}

--- Retrieve autocommands associated with a specific augroup and buffer
---@param augroup number|string The autocommand group name or ID
---@param bufnr number The buffer number to query
---@return table List of autocommands matching the given augroup and buffer
function M.get_autocmds(augroup, bufnr)
  return vim.api.nvim_get_autocmds({
    group = augroup,
    event = { "WinScrolled", "TextChanged", "TextChangedI", "TextChangedP" },
    buffer = bufnr,
  })
end

--- Set up an autocommand for a given buffer or file type
---@param colorizer_state table The colorizer state table containing augroup information
---@param bo_type string The buffer option type (either 'buftype' or 'filetype')
---@param conf_bo_type boolean Indicates if buffer or file type is configured
---@param list table List of patterns to apply for autocommands
---@param setup function A callback function to execute when the autocommand triggers
function M.do_workit(colorizer_state, bo_type, conf_bo_type, list, setup)
  local aucmd = { buftype = "BufWinEnter", filetype = "FileType" }
  vim.api.nvim_create_autocmd({ aucmd[bo_type] }, {
    group = colorizer_state.augroup,
    pattern = bo_type == "filetype" and (conf_bo_type and "*" or list) or nil,
    callback = function()
      setup(bo_type)
    end,
  })
end

--- Roll out autocommands for buffer-specific events such as text changes and scrolling
---@param options table Options configuration for the buffer, including sass settings
---@param bufnr number Buffer number where the autocommands should be applied
---@param state table State table containing information like augroup, buffer options, and buffer local state
---@param rh_cb function Callback function to re-highlight the buffer upon triggering events
---@return table List of created autocommand IDs
function M.rollout(options, bufnr, state, rh_cb)
  local autocmds = {}
  local text_changed_au = { "TextChanged", "TextChangedI", "TextChangedP" }

  -- Only enable InsertLeave in sass mode, other modes do not require it
  if options.sass and options.sass.enable then
    table.insert(text_changed_au, "InsertLeave")
  end

  autocmds[#autocmds + 1] = vim.api.nvim_create_autocmd(text_changed_au, {
    group = state.augroup,
    buffer = bufnr,
    callback = function(args)
      state.buffer_current = bufnr
      -- Only reload if it was not disabled using detach_from_buffer
      if state.buffer_options[bufnr] then
        state.buffer_local[bufnr].__event = args.event
        if args.event == "TextChanged" or args.event == "InsertLeave" then
          rh_cb(bufnr, options, state.buffer_local[bufnr])
        else
          local pos = vim.fn.getpos(".")
          state.buffer_local[bufnr].__startline = pos[2] - 1
          state.buffer_local[bufnr].__endline = pos[2]
          rh_cb(bufnr, options, state.buffer_local[bufnr], true)
        end
      end
    end,
  })

  autocmds[#autocmds + 1] = vim.api.nvim_create_autocmd({ "WinScrolled" }, {
    group = state.augroup,
    buffer = bufnr,
    callback = function(args)
      -- Only reload if it was not disabled using detach_from_buffer
      if state.buffer_options[bufnr] then
        state.buffer_local[bufnr].__event = args.event
        rh_cb(bufnr, options, state.buffer_local[bufnr])
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
    group = state.augroup,
    buffer = bufnr,
    callback = function()
      if state.buffer_options[bufnr] then
        M.detach_from_buffer(bufnr)
      end
      state.buffer_local[bufnr].__init = nil
    end,
  })

  return autocmds
end

return M
