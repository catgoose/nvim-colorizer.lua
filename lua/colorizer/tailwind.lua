--- Handles Tailwind CSS color highlighting within buffers.
-- This module integrates with the Tailwind CSS Language Server Protocol (LSP) to retrieve and apply
-- color highlights for Tailwind classes in a buffer. It manages LSP attachment, autocmds for color updates,
-- and maintains state for efficient Tailwind highlighting.
-- @module colorizer.tailwind

local M = {}

-- use a different namespace for tailwind as will be cleared if kept in Default namespace
local namespace = vim.api.nvim_create_namespace("colorizer_tailwind")

local state = {}

--- Cleanup tailwind variables and autocmd
---@param bufnr number: buffer number (0 for current)
function M.cleanup(bufnr)
  if state[bufnr] and state[bufnr].au_id and state[bufnr].au_id[1] then
    pcall(vim.api.nvim_del_autocmd, state[bufnr].au_id[1])
    pcall(vim.api.nvim_del_autocmd, state[bufnr].au_id[2])
  end
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  state[bufnr] = nil
end

local function highlight_tailwind(bufnr, ns, options, add_highlight)
  -- it can take some time to actually fetch the results
  -- on top of that, tailwindcss is quite slow in neovim
  vim.defer_fn(function()
    if not state[bufnr] or not state[bufnr].client or not state[bufnr].client.request then
      return
    end

    local opts = { textDocument = vim.lsp.util.make_text_document_params() }
    state[bufnr].client.request("textDocument/documentColor", opts, function(err, results, _, _)
      if err == nil and results ~= nil then
        local data, line_start, line_end = {}, nil, nil
        for _, color in pairs(results) do
          local cur_line = color.range.start.line
          if line_start then
            if cur_line < line_start then
              line_start = cur_line
            end
          else
            line_start = cur_line
          end

          local end_line = color.range["end"].line
          if line_end then
            if end_line > line_end then
              line_end = end_line
            end
          else
            line_end = end_line
          end

          local r, g, b, a =
            color.color.red or 0,
            color.color.green or 0,
            color.color.blue or 0,
            color.color.alpha or 0
          local rgb_hex = string.format("%02x%02x%02x", r * a * 255, g * a * 255, b * a * 255)
          local first_col = color.range.start.character
          local end_col = color.range["end"].character

          data[cur_line] = data[cur_line] or {}
          table.insert(data[cur_line], { rgb_hex = rgb_hex, range = { first_col, end_col } })
        end
        add_highlight(bufnr, ns, line_start or 0, line_end and (line_end + 2) or -1, data, options)
      end
    end)
  end, 10)
end

--- highlight buffer using values returned by tailwindcss
-- To see these table information, see |colorizer.buffer|
---@param bufnr number: Buffer number (0 for current)
---@param options table
---@param options_local table
---@param add_highlight function
function M.setup_lsp_colors(bufnr, options, options_local, add_highlight)
  state[bufnr] = state[bufnr] or {}
  state[bufnr].au_id = state[bufnr].au_id or {}

  if not state[bufnr].client or state[bufnr].client.is_stopped() then
    if vim.version().minor >= 8 then
      -- create the autocmds so tailwind colors only activate when tailwindcss lsp is active
      if not state[bufnr].AU_CREATED then
        vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
        state[bufnr].au_id[1] = vim.api.nvim_create_autocmd("LspAttach", {
          group = options_local.__augroup_id,
          buffer = bufnr,
          callback = function(args)
            local ok, client = pcall(vim.lsp.get_client_by_id, args.data.client_id)
            if ok and client then
              if
                client.name == "tailwindcss"
                and client.supports_method("textDocument/documentColor")
              then
                -- wait 100 ms for the first request
                state[bufnr].client = client
                vim.defer_fn(function()
                  highlight_tailwind(bufnr, namespace, options, add_highlight)
                end, 100)
              end
            end
          end,
        })
        -- make sure the autocmds are deleted after lsp server is closed
        state[bufnr].au_id[2] = vim.api.nvim_create_autocmd("LspDetach", {
          group = options_local.__augroup_id,
          buffer = bufnr,
          callback = function()
            M.cleanup(bufnr)
          end,
        })
        state[bufnr].AU_CREATED = true
      end
    end
    -- this will be triggered when no lsp is attached
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

    state[bufnr].client = nil

    local ok, tailwind_client = pcall(function()
      return vim.lsp.get_clients({ bufnr = bufnr, name = "tailwindcss" })
    end)
    if not ok then
      return
    end

    ok = false
    for _, cl in pairs(tailwind_client) do
      if cl["name"] == "tailwindcss" then
        tailwind_client = cl
        ok = true
        break
      end
    end

    if
      not ok
      and (
        vim.tbl_isempty(tailwind_client or {})
        or not tailwind_client
        or not tailwind_client.supports_method
        or not tailwind_client.supports_method("textDocument/documentColor")
      )
    then
      return true
    end

    state[bufnr].client = tailwind_client

    -- wait 500 ms for the first request
    vim.defer_fn(function()
      highlight_tailwind(bufnr, namespace, options, add_highlight)
    end, 1000)

    return true
  end

  -- only try to do tailwindcss highlight if lsp is attached
  if state[bufnr].client then
    highlight_tailwind(bufnr, namespace, options, add_highlight)
  end
end

return M
