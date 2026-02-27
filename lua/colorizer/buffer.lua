---@mod colorizer.buffer Buffer
---@brief [[
---Provides highlighting functions for buffer.
---@brief ]]
local M = {}

local color = require("colorizer.color")
local config = require("colorizer.config")
local const = require("colorizer.constants")
local matcher = require("colorizer.matcher")
local names = require("colorizer.parser.names")
local sass = require("colorizer.parser.sass")
local tailwind = require("colorizer.tailwind")
local utils = require("colorizer.utils")

local hl_state
--- Clean the highlight cache
function M.reset_cache()
  hl_state = {
    name_prefix = const.plugin.name,
    cache = {},
    updated_colors = {},
  }
end
do
  M.reset_cache()
end

--- Make a deterministic name for a highlight given these attributes
local function make_highlight_name(rgb, mode)
  return table.concat({ hl_state.name_prefix, const.highlight_mode_names[mode], rgb }, "_")
end

--- Create a highlight with the given rgb_hex and mode
---@param rgb_hex string RGB hex code
---@param mode 'background'|'foreground' Mode of the highlight
---@param bg_opts table|nil Background display options { bright_fg, dark_fg }
local function create_highlight(rgb_hex, mode, bg_opts)
  mode = mode or "background"
  rgb_hex = rgb_hex:lower()
  local bright_fg = bg_opts and bg_opts.bright_fg or "#000000"
  local dark_fg = bg_opts and bg_opts.dark_fg or "#ffffff"
  local cache_key = table.concat({ const.highlight_mode_names[mode], rgb_hex, bright_fg, dark_fg }, "_")
  local highlight_name = hl_state.cache[cache_key]

  -- Look up in our cache.
  if highlight_name then
    return highlight_name
  end

  -- Create the highlight
  highlight_name = make_highlight_name(rgb_hex, mode)
  if mode == "foreground" then
    vim.api.nvim_set_hl(0, highlight_name, { fg = "#" .. rgb_hex })
  else
    local rr, gg, bb = rgb_hex:sub(1, 2), rgb_hex:sub(3, 4), rgb_hex:sub(5, 6)
    local r, g, b = tonumber(rr, 16), tonumber(gg, 16), tonumber(bb, 16)
    local fg_color = color.is_bright(r, g, b) and bright_fg or dark_fg
    vim.api.nvim_set_hl(0, highlight_name, { fg = fg_color, bg = "#" .. rgb_hex })
  end
  hl_state.cache[cache_key] = highlight_name
  return highlight_name
end

local function slice_line(bufnr, line, start_col, end_col)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)
  if #lines == 0 then
    return
  end
  return string.sub(lines[1], start_col + 1, end_col)
end

--- Normalize opts to new format if needed.
--- Ensures the result is fully merged with defaults so all expected
--- sub-tables (parsers.names, parsers.hex, etc.) are present.
---@param opts table Options (new format or legacy)
---@return table New-format options
local function normalize_opts(opts)
  if opts.__resolved then
    return opts
  end
  return config.resolve_options(opts)
end

--- Create highlight and set highlights
---@param bufnr number Buffer number (0 for current)
---@param ns_id number Namespace id for which to create highlights
---@param line_start number Line_start should be 0-indexed
---@param line_end number Last line to highlight
---@param data table Table output of `parse_lines`
---@param opts table Options (new format or legacy `user_default_options`)
---@param hl_opts table|nil Highlight options:
--- - tailwind_lsp boolean: Clear tailwind_names namespace when applying Tailwind LSP highlighting
function M.add_highlight(bufnr, ns_id, line_start, line_end, data, opts, hl_opts)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  opts = normalize_opts(opts)
  hl_opts = hl_opts or {}
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, line_start, line_end)

  local d = opts.display
  local prio = d.priority or {}
  local priority = hl_opts.tailwind_lsp and (prio.lsp or vim.hl.priorities.user) or (prio.default or vim.hl.priorities.diagnostics)
  local bg_opts = d.background
  local tw = opts.parsers.tailwind or {}

  if d.mode == "background" or d.mode == "foreground" then
    local tw_both = tw.enable and tw.lsp and hl_opts.tailwind_lsp
    for linenr, hls in pairs(data) do
      for _, hl in ipairs(hls) do
        if tw_both and tw.update_names then
          local txt = slice_line(bufnr, linenr, hl.range[1], hl.range[2])
          if txt and not hl_state.updated_colors[txt] then
            hl_state.updated_colors[txt] = true
            names.update_color(txt, hl.rgb_hex, "tailwind_names")
          end
        end
        local hlname = create_highlight(hl.rgb_hex, d.mode, bg_opts)
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, linenr, hl.range[1], {
          end_col = hl.range[2],
          hl_group = hlname,
          priority = priority,
        })
      end
    end
  elseif d.mode == "virtualtext" then
    local vt = d.virtualtext
    -- Reuse a single opts table across iterations to reduce allocations
    local extmark_opts = {
      virt_text = nil,
      hl_mode = "combine",
      priority = 0,
      virt_text_pos = nil,
      end_col = nil,
    }
    -- Reuse a single inner table for virt_text entries
    local virt_text_entry = { "", "" }
    local virt_text_list = { virt_text_entry }
    for linenr, hls in pairs(data) do
      for _, hl in ipairs(hls) do
        if tw.enable and tw.lsp and hl_opts.tailwind_lsp then
          vim.api.nvim_buf_clear_namespace(bufnr, ns_id, linenr, linenr + 1)
          if tw.update_names then
            local txt = slice_line(bufnr, linenr, hl.range[1], hl.range[2])
            if txt and not hl_state.updated_colors[txt] then
              hl_state.updated_colors[txt] = true
              names.update_color(txt, hl.rgb_hex, "tailwind_names")
            end
          end
        end
        local hlname = create_highlight(hl.rgb_hex, vt.hl_mode, bg_opts)
        local start_col = hl.range[2]
        virt_text_entry[2] = hlname
        if vt.position == "before" or vt.position == "after" then
          extmark_opts.virt_text_pos = "inline"
          local vt_char = vt.char or const.defaults.virtualtext
          virt_text_entry[1] = string.format(
            "%s%s%s",
            vt.position == "before" and vt_char or " ",
            vt.position == "before" and " " or "",
            vt.position == "after" and vt_char or ""
          )
          if vt.position == "before" then
            start_col = hl.range[1]
          end
        else
          extmark_opts.virt_text_pos = nil
          virt_text_entry[1] = vt.char or const.defaults.virtualtext
        end
        extmark_opts.virt_text = virt_text_list
        extmark_opts.end_col = start_col
        pcall(function()
          vim.api.nvim_buf_set_extmark(bufnr, ns_id, linenr, start_col, extmark_opts)
        end)
      end
    end
  end
end

--- Highlight the buffer region.
-- Highlight starting from `line_start` (0-indexed) for each line described by `lines` in the
-- buffer id `bufnr` and attach it to the namespace id `ns_id`.
---@param bufnr number Buffer number, 0 for current
---@param ns_id number Namespace id, default is "colorizer" created with vim.api.nvim_create_namespace
---@param line_start number line_start should be 0-indexed
---@param line_end number Last line to highlight
---@param opts table Options (new format or legacy `user_default_options`)
---@param buf_local_opts table Buffer local options
---@return table Detach settings table to use when cleaning up buffer state in `colorizer.detach_from_buffer`
--- - ns_id number: Table of namespace ids to clear
--- - functions function: Table of detach functions to call
function M.highlight(bufnr, ns_id, line_start, line_end, opts, buf_local_opts)
  ns_id = ns_id or const.namespace.default
  bufnr = utils.bufme(bufnr)
  opts = normalize_opts(opts)
  local detach = { ns_id = {}, functions = {} }
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_start, line_end, false)

  local tw = opts.parsers.tailwind or {}
  local sass_cfg = opts.parsers.sass

  -- only update sass varibles when text is changed
  if buf_local_opts.__event ~= "WinScrolled" and sass_cfg and sass_cfg.enable then
    table.insert(detach.functions, sass.cleanup)

    local sass_matcher_opts = config.expand_sass_parsers(sass_cfg.parsers)
    sass.update_variables(
      bufnr,
      0,
      -1,
      nil,
      matcher.make(sass_matcher_opts),
      opts,
      buf_local_opts
    )
  end

  -- Parse lines from matcher
  local data = M.parse_lines(bufnr, lines, line_start, opts) or {}
  M.add_highlight(bufnr, ns_id, line_start, line_end, data, opts)

  if tw.lsp then
    tailwind.lsp_highlight(
      bufnr,
      opts,
      buf_local_opts,
      M.add_highlight,
      tailwind.cleanup,
      line_start,
      line_end
    )
  end

  return detach
end

--- Parse the given lines for colors and return a table containing
-- rgb_hex and range per line
---@param bufnr number Buffer number (0 for current)
---@param lines table Table of lines to parse
---@param line_start number Buffer line number to start highlighting
---@param opts table Options (new format or legacy `user_default_options`)
---@return table|nil
function M.parse_lines(bufnr, lines, line_start, opts)
  opts = normalize_opts(opts)
  local loop_parse_fn = matcher.make(opts)
  if not loop_parse_fn then
    return
  end

  local data = {}
  for line_nr, line in ipairs(lines) do
    line_nr = line_nr - 1 + line_start
    local i = 1
    while i < #line do
      local length, rgb_hex = loop_parse_fn(line, i, bufnr, line_nr)
      if length and not rgb_hex then
        utils.log_message(
          string.format(
            "Colorizer: Error parsing line %d, index %d. Please report this issue.",
            line_nr,
            i
          )
        )
      end
      if length and rgb_hex then
        local line_data = data[line_nr]
        if not line_data then
          line_data = {}
          data[line_nr] = line_data
        end
        line_data[#line_data + 1] = { rgb_hex = rgb_hex, range = { i - 1, i + length - 1 } }
        i = i + length
      else
        i = i + 1
      end
    end
  end

  return data
end

return M
