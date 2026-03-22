---@mod colorizer.css_lsp CSS LSP Color Provider
---@brief [[
---Integrates with CSS-capable Language Servers that support textDocument/documentColor
---to resolve CSS custom properties (var()) that reference variables defined in external files.
---Only highlights var() references — other colors are handled by parser-based highlighting.
---@brief ]]
local M = {}

local css_var = require("colorizer.parser.css_var")
local utils = require("colorizer.utils")
local ns_id = require("colorizer.constants").namespace.css_var_lsp

local lsp_cache = {}

--- Cleanup CSS LSP state and autocmds for a buffer
---@param bufnr number|nil buffer number (0 for current)
function M.cleanup(bufnr)
  bufnr = utils.bufme(bufnr)
  local cache = lsp_cache[bufnr]
  if cache and cache.au_id then
    for _, au_id in ipairs(cache.au_id) do
      pcall(vim.api.nvim_del_autocmd, au_id)
    end
  end
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  lsp_cache[bufnr] = nil
end

--- Check if text at a given range is a var() reference and extract the variable name.
--- Reads the text within the LSP range first; if the range is narrower than the full
--- var() expression (some LSPs only report the resolved value span), falls back to
--- reading a small window around it.
---@param bufnr number
---@param range table LSP range { start = { line, character }, ["end"] = { line, character } }
---@return string|nil variable_name
local function extract_var_name(bufnr, range)
  local lines = vim.api.nvim_buf_get_lines(bufnr, range.start.line, range.start.line + 1, false)
  if #lines == 0 then
    return nil
  end
  local line = lines[1]
  local start_char = range.start.character
  local end_char = range["end"].character

  -- First try: text within the LSP range itself
  local text = line:sub(start_char + 1, end_char)
  local var_name = text:match("^var%(%s*%-%-([%w_-]+)")
  if var_name then
    return var_name
  end

  -- Fallback: some LSPs report a narrower range (e.g. just the property name).
  -- Check a small window before the range start for the var( prefix.
  local search_start = math.max(0, start_char - 5)
  text = line:sub(search_start + 1, end_char)
  return text:match("var%(%s*%-%-([%w_-]+)")
end

--- Find a CSS LSP client with colorProvider for this buffer
---@param bufnr number
---@return table|nil client
local function find_css_lsp(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  for _, client in ipairs(clients) do
    if client.server_capabilities and client.server_capabilities.colorProvider then
      return client
    end
  end
  return nil
end

local function highlight(bufnr, opts, add_highlight)
  if not lsp_cache[bufnr] or not lsp_cache[bufnr].client then
    return
  end
  local document_params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  local client = lsp_cache[bufnr].client
  if not client.server_capabilities or not client.server_capabilities.colorProvider then
    return
  end
  client:request(
    "textDocument/documentColor",
    document_params,
    function(err, results, _, _)
      if err ~= nil then
        utils.log_message("css_lsp.highlight: Error: " .. vim.inspect(err))
        return
      end
      if not results then
        return
      end

      local data = {}
      local lsp_definitions = {}

      for _, result in pairs(results) do
        local var_name = extract_var_name(bufnr, result.range)
        if var_name then
          local r, g, b, a =
            result.color.red or 0,
            result.color.green or 0,
            result.color.blue or 0,
            result.color.alpha or 0
          local rgb_hex = string.format("%02x%02x%02x", r * a * 255, g * a * 255, b * a * 255)

          -- Store for css_var state (cross-file resolution)
          lsp_definitions[var_name] = rgb_hex

          -- Only build extmark data for variables NOT already resolved by buffer scanning.
          -- Buffer-scanned vars are already highlighted by the parser in the default namespace.
          if not css_var.has_buffer_definition(bufnr, var_name) then
            local cur_line = result.range.start.line
            local first_col = result.range.start.character
            local end_col = result.range["end"].character
            data[cur_line] = data[cur_line] or {}
            table.insert(data[cur_line], { rgb_hex = rgb_hex, range = { first_col, end_col } })
          end
        end
      end

      -- Feed resolved variables into css_var state for parser-based resolution
      css_var.update_from_lsp(bufnr, lsp_definitions)

      -- Apply direct highlights for var() references the buffer couldn't resolve
      lsp_cache[bufnr].data = data
      vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      if next(data) then
        add_highlight(bufnr, ns_id, 0, -1, data, opts)
      end
    end
  )
end

--- Highlight buffer using CSS LSP documentColor for var() references
---@param bufnr number Buffer number (0 for current)
---@param opts table Options (new format or legacy)
---@param buf_local_opts table Buffer local options
---@param add_highlight function Function to add highlights
---@param on_detach function Function to call when LSP is detached
---@return boolean|nil
function M.lsp_highlight(bufnr, opts, buf_local_opts, add_highlight, on_detach)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  lsp_cache[bufnr] = lsp_cache[bufnr] or {}
  lsp_cache[bufnr].au_id = lsp_cache[bufnr].au_id or {}

  if not lsp_cache[bufnr].client or lsp_cache[bufnr].client:is_stopped() then
    if not lsp_cache[bufnr].au_created then
      vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      lsp_cache[bufnr].au_id[1] = vim.api.nvim_create_autocmd("LspAttach", {
        group = buf_local_opts.__augroup_id,
        buffer = bufnr,
        callback = function(args)
          local clients = vim.lsp.get_clients({ id = args.data.client_id })
          local client = clients[1]
          if client and client.server_capabilities and client.server_capabilities.colorProvider then
            lsp_cache[bufnr].client = client
            vim.defer_fn(function()
              if vim.api.nvim_buf_is_valid(bufnr) and lsp_cache[bufnr] then
                highlight(bufnr, opts, add_highlight)
              end
            end, 200)
          end
        end,
      })
      lsp_cache[bufnr].au_id[2] = vim.api.nvim_create_autocmd("LspDetach", {
        group = buf_local_opts.__augroup_id,
        buffer = bufnr,
        callback = function()
          on_detach(bufnr)
        end,
      })
      lsp_cache[bufnr].au_created = true
    end

    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

    local client = find_css_lsp(bufnr)
    if not client then
      return
    end

    lsp_cache[bufnr].client = client
    highlight(bufnr, opts, add_highlight)

    return true
  end

  if lsp_cache[bufnr].client then
    if buf_local_opts.__event == "WinScrolled" and lsp_cache[bufnr].data then
      vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      if next(lsp_cache[bufnr].data) then
        add_highlight(bufnr, ns_id, 0, -1, lsp_cache[bufnr].data, opts)
      end
    else
      highlight(bufnr, opts, add_highlight)
    end
  end
end

return M
