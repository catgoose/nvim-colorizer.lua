---Provides highlighting functions for buffer
--@module colorizer.buffer

local M = {}

local color = require("colorizer.color")
local sass = require("colorizer.sass")
local tailwind = require("colorizer.tailwind")
local utils = require("colorizer.utils")
local make_matcher = require("colorizer.matcher").make
local const = require("colorizer.constants")

local hl_state = {
  name_prefix = const.plugin.name,
  cache = {},
}

--- Clean the highlight cache
function M.clear_hl_cache()
  hl_state.cache = {}
end

--- Make a deterministic name for a highlight given these attributes
local function make_highlight_name(rgb, mode)
  return table.concat({ hl_state.name_prefix, const.highlight_mode_names[mode], rgb }, "_")
end

--- Create a highlight with the given rgb_hex and mode
---@param rgb_hex string: RGB hex code
---@param mode 'background'|'foreground': Mode of the highlight
local function create_highlight(rgb_hex, mode)
  mode = mode or "background"
  --  TODO: 2024-12-20 - validate rgb format
  rgb_hex = rgb_hex:lower()
  local cache_key = table.concat({ const.highlight_mode_names[mode], rgb_hex }, "_")
  local highlight_name = hl_state.cache[cache_key]

  -- Look up in our cache.
  if highlight_name then
    return highlight_name
  end

  -- convert from #fff to #ffffff
  if #rgb_hex == 3 then
    rgb_hex = table.concat({
      rgb_hex:sub(1, 1):rep(2),
      rgb_hex:sub(2, 2):rep(2),
      rgb_hex:sub(3, 3):rep(2),
    })
  end

  -- Create the highlight
  highlight_name = make_highlight_name(rgb_hex, mode)
  if mode == "foreground" then
    vim.api.nvim_set_hl(0, highlight_name, { fg = "#" .. rgb_hex })
  else
    local rr, gg, bb = rgb_hex:sub(1, 2), rgb_hex:sub(3, 4), rgb_hex:sub(5, 6)
    local r, g, b = tonumber(rr, 16), tonumber(gg, 16), tonumber(bb, 16)
    local fg_color = color.is_bright(r, g, b) and "Black" or "White"
    vim.api.nvim_set_hl(0, highlight_name, { fg = fg_color, bg = "#" .. rgb_hex })
  end
  hl_state.cache[cache_key] = highlight_name
  return highlight_name
end

--- Create highlight and set highlights
---@param bufnr number: Buffer number (0 for current)
---@param ns_id number: Namespace id for which to create highlights
---@param line_start number: Line_start should be 0-indexed
---@param line_end number: Last line to highlight
---@param data table: Table output of `parse_lines`
---@param ud_opts table: `user_default_options`
---@param hl_opts table|nil: Highlight options:
--- - tailwind_lsp boolean: Clear tailwind_names namespace when applying Tailwind LSP highlighting
function M.add_highlight(bufnr, ns_id, line_start, line_end, data, ud_opts, hl_opts)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  hl_opts = hl_opts or {}
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, line_start, line_end)
  if vim.tbl_contains({ "background", "foreground" }, ud_opts.mode) then
    for linenr, hls in pairs(data) do
      for _, hl in ipairs(hls) do
        if ud_opts.tailwind == "both" and hl_opts.tailwind_lsp then
          vim.api.nvim_buf_clear_namespace(
            bufnr,
            const.namespace.tailwind_names,
            linenr,
            linenr + 1
          )
        end
        local hlname = create_highlight(hl.rgb_hex, ud_opts.mode)
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, hlname, linenr, hl.range[1], hl.range[2])
      end
    end
  elseif ud_opts.mode == "virtualtext" then
    for linenr, hls in pairs(data) do
      for _, hl in ipairs(hls) do
        if ud_opts.tailwind == "both" and hl_opts.tailwind_lsp then
          vim.api.nvim_buf_clear_namespace(
            bufnr,
            const.namespace.tailwind_names,
            linenr,
            linenr + 1
          )
        end
        local hlname = create_highlight(hl.rgb_hex, ud_opts.virtualtext_mode)
        local start_col = hl.range[2]
        local opts = {
          virt_text = { { ud_opts.virtualtext or const.defaults.virtualtext, hlname } },
          hl_mode = "combine",
          priority = 0,
        }
        if ud_opts.virtualtext_inline then
          start_col = hl.range[1]
          opts.virt_text_pos = "inline"
          opts.virt_text =
            { { (ud_opts.virtualtext or const.defaults.virtualtext) .. " ", hlname } }
        end
        opts.end_col = start_col
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, linenr, start_col, opts)
      end
    end
  end
end

--- Highlight the buffer region.
-- Highlight starting from `line_start` (0-indexed) for each line described by `lines` in the
-- buffer id `bufnr` and attach it to the namespace id `ns_id`.
---@param bufnr number: Buffer number, 0 for current
---@param ns_id number: Namespace id, default is "colorizer" created with vim.api.nvim_create_namespace
---@param line_start number: line_start should be 0-indexed
---@param line_end number: Last line to highlight
---@param ud_opts table: `user_default_options`
---@param buf_local_opts table: Buffer local options
---@return table: Detach settings table { ns_id = {}, functions = {} }
function M.highlight(bufnr, ns_id, line_start, line_end, ud_opts, buf_local_opts)
  ns_id = ns_id or const.namespace.default
  bufnr = utils.bufme(bufnr)
  local detach = { ns_id = {}, functions = {} }
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_start, line_end, false)

  -- only update sass varibles when text is changed
  if buf_local_opts.__event ~= "WinScrolled" and ud_opts.sass and ud_opts.sass.enable then
    table.insert(detach.functions, sass.cleanup)
    sass.update_variables(
      bufnr,
      0,
      -1,
      nil,
      make_matcher(ud_opts.sass.parsers),
      ud_opts,
      buf_local_opts
    )
  end

  local data = M.parse_lines(bufnr, lines, line_start, ud_opts) or {}
  M.add_highlight(bufnr, ns_id, line_start, line_end, data, ud_opts)

  --  TODO: 2024-12-31 - Simplifiy checking tailwind opts
  if ud_opts.tailwind == "lsp" or ud_opts.tailwind == "both" then
    tailwind.setup_lsp_colors(bufnr, ud_opts, buf_local_opts, M.add_highlight, tailwind.cleanup)
    table.insert(detach.functions, tailwind.cleanup)
  end
  if ud_opts.tailwind == true or ud_opts.tailwind == "normal" or ud_opts.tailwind == "both" then
    local tw_data = M.parse_lines(bufnr, lines, line_start, ud_opts, { tailwind = true }) or {}
    M.add_highlight(bufnr, const.namespace.tailwind_names, line_start, line_end, tw_data, ud_opts)
  end

  return detach
end

--- Parse the given lines for colors and return a table containing
-- rgb_hex and range per line
---@param bufnr number: Buffer number (0 for current)
---@param lines table: Table of lines to parse
---@param line_start number: Buffer line number to start highlighting
---@param ud_opts table: `user_default_options`
---@param parse_opts table|nil: Parsing options
--- - tailwind boolean|nil: use tailwind_names parser
---@return table|nil
function M.parse_lines(bufnr, lines, line_start, ud_opts, parse_opts)
  parse_opts = parse_opts or {}
  local loop_parse_fn
  local use_tailwind = parse_opts.tailwind == true and ud_opts.tailwind ~= "lsp"
  if use_tailwind then
    loop_parse_fn = function(line, i, _bufnr)
      return require("colorizer.parser.tailwind_names").parser(line, i)
    end
  else
    loop_parse_fn = make_matcher(ud_opts)
  end
  if not loop_parse_fn then
    return
  end

  local data = {}
  for line_nr, line in ipairs(lines) do
    line_nr = line_nr - 1 + line_start
    local i = 1
    while i < #line do
      local length, rgb_hex = loop_parse_fn(line, i, bufnr)
      if length and rgb_hex then
        data[line_nr] = data[line_nr] or {}
        table.insert(data[line_nr] or {}, { rgb_hex = rgb_hex, range = { i - 1, i + length - 1 } })
        i = i + length
      else
        i = i + 1
      end
    end
  end

  return data
end

return M
