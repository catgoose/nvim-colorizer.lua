---Provides highlighting functions for buffer
--@module colorizer.buffer

local M = {}

local color = require("colorizer.color")
local plugin_name = "colorizer"
local sass = require("colorizer.sass")
local tailwind = require("colorizer.tailwind")
local utils = require("colorizer.utils")
local make_matcher = require("colorizer.matcher").make

local hl_state = {
  name_prefix = plugin_name,
  cache = {},
  hs_id = plugin_name,
}

--- Highlight mode which will be use to render the color
M.highlight_mode_names = {
  background = "mb",
  foreground = "mf",
  virtualtext = "mv",
}

--- Default namespace used in `highlight` and `colorizer.attach_to_buffer`.
---@see highlight
---@see colorizer.attach_to_buffer
M.default_namespace = vim.api.nvim_create_namespace(hl_state.hs_id)

--- Clean the highlight cache
function M.clear_hl_cache()
  hl_state.cache = {}
end

--- Make a deterministic name for a highlight given these attributes
local function make_highlight_name(rgb, mode)
  return table.concat({ hl_state.name_prefix, M.highlight_mode_names[mode], rgb }, "_")
end

--- Create a highlight with the given rgb_hex and mode
---@param rgb_hex string: RGB hex code
---@param mode 'background'|'foreground': Mode of the highlight
local function create_highlight(rgb_hex, mode)
  mode = mode or "background"
  -- TODO validate rgb format?
  rgb_hex = rgb_hex:lower()
  local cache_key = table.concat({ M.highlight_mode_names[mode], rgb_hex }, "_")
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
---@param bufnr number: buffer number (0 for current)
---@param ns_id number: namespace id.  default is "colorizer", created with vim.api.nvim_create_namespace
---@param line_start number: line_start should be 0-indexed
---@param line_end number: Last line to highlight
---@param data table: table output of `parse_lines`
---@param options table: Passed in setup, mainly for `user_default_options`
function M.add_highlight(bufnr, ns_id, line_start, line_end, data, options)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, line_start, line_end)

  if vim.tbl_contains({ "background", "foreground" }, options.mode) then
    for linenr, hls in pairs(data) do
      for _, hl in ipairs(hls) do
        local hlname = create_highlight(hl.rgb_hex, options.mode)
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, hlname, linenr, hl.range[1], hl.range[2])
      end
    end
  elseif options.mode == "virtualtext" then
    for linenr, hls in pairs(data) do
      for _, hl in ipairs(hls) do
        local hlname = create_highlight(hl.rgb_hex, options.virtualtext_mode)

        local start_col = hl.range[2]
        local opts = {
          virt_text = { { options.virtualtext or "■", hlname } },
          hl_mode = "combine",
          priority = 0,
        }

        if options.virtualtext_inline then
          start_col = hl.range[1]
          opts.virt_text_pos = "inline"
          opts.virt_text = { { (options.virtualtext or "■") .. " ", hlname } }
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
---@param options table: Configuration options as described in `setup`
---@param options_local table: Buffer local variables
---@return nil|boolean|number,table
function M.highlight(bufnr, ns_id, line_start, line_end, options, options_local)
  local returns = { detach = { ns_id = {}, functions = {} } }
  if bufnr == 0 or bufnr == nil then
    bufnr = utils.bufme()
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, line_start, line_end, false)

  ns_id = ns_id or M.default_namespace

  -- only update sass varibles when text is changed
  if options_local.__event ~= "WinScrolled" and options.sass and options.sass.enable then
    table.insert(returns.detach.functions, sass.cleanup)
    sass.update_variables(
      bufnr,
      0,
      -1,
      nil,
      make_matcher(options.sass.parsers),
      options,
      options_local
    )
  end

  local data = M.parse_lines(bufnr, lines, line_start, options) or {}
  M.add_highlight(bufnr, ns_id, line_start, line_end, data, options)

  if options.tailwind == "lsp" or options.tailwind == "both" then
    tailwind.setup_lsp_colors(bufnr, options, options_local, M.add_highlight)
    table.insert(returns.detach.functions, tailwind.cleanup)
  end

  return true, returns
end

--- Parse the given lines for colors and return a table containing
-- rgb_hex and range per line
---@param bufnr number: Buffer number (0 for current)
---@param lines table: Table of lines to parse
---@param line_start number: This is the buffer line number, from where to start highlighting
---@param options table: Passed in `colorizer.setup`, Only uses `user_default_options`
---@return table|nil
function M.parse_lines(bufnr, lines, line_start, options)
  local loop_parse_fn = make_matcher(options)
  if not loop_parse_fn then
    return
  end

  local data = {}
  for current_linenum, line in ipairs(lines) do
    current_linenum = current_linenum - 1 + line_start
    data[current_linenum] = data[current_linenum] or {}

    -- Upvalues are options and current_linenum
    local i = 1
    while i < #line do
      local length, rgb_hex = loop_parse_fn(line, i, bufnr)
      if length and rgb_hex then
        table.insert(
          data[current_linenum],
          { rgb_hex = rgb_hex, range = { i - 1, i + length - 1 } }
        )
        i = i + length
      else
        i = i + 1
      end
    end
  end

  return data
end

return M
