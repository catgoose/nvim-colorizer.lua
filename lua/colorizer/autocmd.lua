local M = {}

function M.get_autocmds(augroup, bufnr)
  return vim.api.nvim_get_autocmds({
    group = augroup,
    event = { "WinScrolled", "TextChanged", "TextChangedI", "TextChangedP" },
    buffer = bufnr,
  })
end

function M.do_workit(colorizer_state, bo_type, conf_bo_type, list, setup_hook)
  local aucmd = { buftype = "BufWinEnter", filetype = "FileType" }
  vim.api.nvim_create_autocmd({ aucmd[bo_type] }, {
    group = colorizer_state.augroup,
    pattern = bo_type == "filetype" and (conf_bo_type and "*" or list) or nil,
    callback = function()
      setup_hook(bo_type)
    end,
  })
end

function M.rollout(options, bufnr, state, rh_cb)
  local autocmds = {}
  local text_changed_au = { "TextChanged", "TextChangedI", "TextChangedP" }
  -- only enable InsertLeave in sass, rest don't require it
  if options.sass and options.sass.enable then
    table.insert(text_changed_au, "InsertLeave")
  end
  autocmds[#autocmds + 1] = vim.api.nvim_create_autocmd(text_changed_au, {
    group = state.augroup,
    buffer = bufnr,
    callback = function(args)
      state.buffer_current = bufnr
      -- only reload if it was not disabled using detach_from_buffer
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
      -- only reload if it was not disabled using detach_from_buffer
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
