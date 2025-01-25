--- Provides highlighting functions for buffer
--@module colorizer.buffer
local M = {}

local color = require("colorizer.color")
local const = require("colorizer.constants")
local matcher = require("colorizer.matcher")
local names = require("colorizer.parser.names")
local sass = require("colorizer.sass")
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

  --  TODO: 2025-01-02 - Is this required?
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

local function slice_line(bufnr, line, start_col, end_col)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)
  if #lines == 0 then
    return
  end
  return string.sub(lines[1], start_col + 1, end_col)
end

--- Add low priority highlights.  Trims highlight ranges to avoid collisions.
---@param bufnr number: Buffer number
---@param extmarks table: List of low priority extmarks to reapply
---@param priority_ns_id number: Namespace id for priority highlights
---@param linenr number: Line number
local function add_low_priority_highlights(bufnr, extmarks, priority_ns_id, linenr)
  local priority_marks = vim.api.nvim_buf_get_extmarks(
    bufnr,
    priority_ns_id,
    { linenr, 0 },
    { linenr + 1, 0 },
    { details = true }
  )
  for _, default_mark in ipairs(extmarks) do
    local default_start = default_mark[3] -- Start column
    local default_end = default_mark[4].end_col
    local hl_group = default_mark[4].hl_group
    local non_overlapping_ranges = { { default_start, default_end } }
    for _, lsp_mark in ipairs(priority_marks) do
      local lsp_start = lsp_mark[3]
      local lsp_end = lsp_mark[4].end_col
      -- Adjust ranges to avoid collisions
      local new_ranges = {}
      for _, range in ipairs(non_overlapping_ranges) do
        local start, end_ = range[1], range[2]
        if lsp_start <= end_ and lsp_end >= start then
          -- Collision detected, split range
          if start < lsp_start then
            table.insert(new_ranges, { start, lsp_start })
          end
          if lsp_end < end_ then
            table.insert(new_ranges, { lsp_end, end_ })
          end
        else
          -- No collision, keep range
          table.insert(new_ranges, { start, end_ })
        end
      end
      non_overlapping_ranges = new_ranges
    end
    for _, range in ipairs(non_overlapping_ranges) do
      vim.api.nvim_buf_add_highlight(
        bufnr,
        default_mark[4].ns_id, -- Original namespace
        hl_group,
        linenr,
        range[1],
        range[2]
      )
    end
  end
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
  if ud_opts.mode == "background" or ud_opts.mode == "foreground" then
    local tw_both = ud_opts.tailwind == "both" and hl_opts.tailwind_lsp
    for linenr, hls in pairs(data) do
      local marks
      if tw_both then
        marks = vim.api.nvim_buf_get_extmarks(
          bufnr,
          const.namespace.default,
          { linenr, 0 },
          { linenr + 1, 0 },
          { details = true }
        )
        -- clear default namespace to apply LSP highlights, then rehighlight non-overlapping default highlights
        -- Fixes: https://github.com/catgoose/nvim-colorizer.lua/issues/61
        vim.api.nvim_buf_clear_namespace(bufnr, const.namespace.default, linenr, linenr + 1)
      end
      for _, hl in ipairs(hls) do
        if tw_both and ud_opts.tailwind_opts.update_names then
          local txt = slice_line(bufnr, linenr, hl.range[1], hl.range[2])
          if txt and not hl_state.updated_colors[txt] then
            hl_state.updated_colors[txt] = true
            names.update_color(txt, hl.rgb_hex, "tailwind_names")
          end
        end
        local hlname = create_highlight(hl.rgb_hex, ud_opts.mode)
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, hlname, linenr, hl.range[1], hl.range[2])
      end
      if tw_both then
        add_low_priority_highlights(bufnr, marks, ns_id, linenr)
      end
    end
  elseif ud_opts.mode == "virtualtext" then
    for linenr, hls in pairs(data) do
      for _, hl in ipairs(hls) do
        if ud_opts.tailwind == "both" and hl_opts.tailwind_lsp then
          vim.api.nvim_buf_clear_namespace(bufnr, ns_id, linenr, linenr + 1)
          if ud_opts.tailwind_opts.update_names then
            local txt = slice_line(bufnr, linenr, hl.range[1], hl.range[2])
            if txt and not hl_state.updated_colors[txt] then
              hl_state.updated_colors[txt] = true
              names.update_color(txt, hl.rgb_hex, "tailwind_names")
            end
          end
        end
        local hlname = create_highlight(hl.rgb_hex, ud_opts.virtualtext_mode)
        local start_col = hl.range[2]
        local opts = {
          virt_text = { { ud_opts.virtualtext or const.defaults.virtualtext, hlname } },
          hl_mode = "combine",
          priority = 0,
        }
        if ud_opts.virtualtext_inline then
          opts.virt_text_pos = "inline"
          opts.virt_text = {
            {
              string.format(
                "%s%s%s",
                ud_opts.virtualtext_inline == "before"
                    and (ud_opts.virtualtext or const.defaults.virtualtext)
                  or " ",
                ud_opts.virtualtext_inline == "before" and " " or "",
                ud_opts.virtualtext_inline == "after"
                    and (ud_opts.virtualtext or const.defaults.virtualtext)
                  or ""
              ),
              hlname,
            },
          }
          if ud_opts.virtualtext_inline == "before" then
            start_col = hl.range[1]
          end
        end
        opts.end_col = start_col
        pcall(function()
          vim.api.nvim_buf_set_extmark(bufnr, ns_id, linenr, start_col, opts)
        end)
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
---@return table: Detach settings table to use when cleaning up buffer state in `colorizer.detach_from_buffer`
--- - ns_id number: Table of namespace ids to clear
--- - functions function: Table of detach functions to call
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
      matcher.make(ud_opts.sass.parsers),
      ud_opts,
      buf_local_opts
    )
  end

  -- Parse lines from matcher
  local data = M.parse_lines(bufnr, lines, line_start, ud_opts) or {}
  M.add_highlight(bufnr, ns_id, line_start, line_end, data, ud_opts)
  if ud_opts.tailwind == "lsp" or ud_opts.tailwind == "both" then
    tailwind.lsp_highlight(
      bufnr,
      ud_opts,
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
---@param bufnr number: Buffer number (0 for current)
---@param lines table: Table of lines to parse
---@param line_start number: Buffer line number to start highlighting
---@param ud_opts table: `user_default_options`
---@return table|nil
function M.parse_lines(bufnr, lines, line_start, ud_opts)
  local loop_parse_fn = matcher.make(ud_opts)
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
