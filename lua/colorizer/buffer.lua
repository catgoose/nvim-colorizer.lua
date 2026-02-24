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
---@param rgb_hex string RGB hex code
---@param mode 'background'|'foreground' Mode of the highlight
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

local PRIORITY_DEFAULT = 100
local PRIORITY_LSP = 200

local function slice_line(bufnr, line, start_col, end_col)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)
  if #lines == 0 then
    return
  end
  return string.sub(lines[1], start_col + 1, end_col)
end

--- Read display/tailwind options from either new or legacy format
---@param opts table Options (new or legacy format)
---@return table display_opts { mode, virtualtext_char, virtualtext_position, virtualtext_hl_mode }
---@return table tailwind_opts { enable, mode, update_names }
local function read_display_opts(opts)
  local display, tw
  if opts.display then
    -- New format
    local d = opts.display
    display = {
      mode = d.mode,
      virtualtext_char = d.virtualtext.char,
      virtualtext_position = d.virtualtext.position,
      virtualtext_hl_mode = d.virtualtext.hl_mode,
    }
    local p = opts.parsers.tailwind
    tw = {
      enable = p.enable,
      mode = p.enable and p.mode or false,
      update_names = p.update_names,
    }
  else
    -- Legacy flat format
    display = {
      mode = opts.mode,
      virtualtext_char = opts.virtualtext,
      virtualtext_position = opts.virtualtext_inline,
      virtualtext_hl_mode = opts.virtualtext_mode,
    }
    tw = {
      enable = opts.tailwind and opts.tailwind ~= false,
      mode = opts.tailwind,
      update_names = opts.tailwind_opts and opts.tailwind_opts.update_names,
    }
  end
  return display, tw
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
  hl_opts = hl_opts or {}
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, line_start, line_end)
  local priority = hl_opts.tailwind_lsp and PRIORITY_LSP or PRIORITY_DEFAULT

  local d, tw = read_display_opts(opts)

  if d.mode == "background" or d.mode == "foreground" then
    local tw_both = tw.mode == "both" and hl_opts.tailwind_lsp
    for linenr, hls in pairs(data) do
      for _, hl in ipairs(hls) do
        if tw_both and tw.update_names then
          local txt = slice_line(bufnr, linenr, hl.range[1], hl.range[2])
          if txt and not hl_state.updated_colors[txt] then
            hl_state.updated_colors[txt] = true
            names.update_color(txt, hl.rgb_hex, "tailwind_names")
          end
        end
        local hlname = create_highlight(hl.rgb_hex, d.mode)
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, linenr, hl.range[1], {
          end_col = hl.range[2],
          hl_group = hlname,
          priority = priority,
        })
      end
    end
  elseif d.mode == "virtualtext" then
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
        if tw.mode == "both" and hl_opts.tailwind_lsp then
          vim.api.nvim_buf_clear_namespace(bufnr, ns_id, linenr, linenr + 1)
          if tw.update_names then
            local txt = slice_line(bufnr, linenr, hl.range[1], hl.range[2])
            if txt and not hl_state.updated_colors[txt] then
              hl_state.updated_colors[txt] = true
              names.update_color(txt, hl.rgb_hex, "tailwind_names")
            end
          end
        end
        local hlname = create_highlight(hl.rgb_hex, d.virtualtext_hl_mode)
        local start_col = hl.range[2]
        virt_text_entry[2] = hlname
        if d.virtualtext_position then
          extmark_opts.virt_text_pos = "inline"
          local vt_char = d.virtualtext_char or const.defaults.virtualtext
          virt_text_entry[1] = string.format(
            "%s%s%s",
            d.virtualtext_position == "before" and vt_char or " ",
            d.virtualtext_position == "before" and " " or "",
            d.virtualtext_position == "after" and vt_char or ""
          )
          if d.virtualtext_position == "before" then
            start_col = hl.range[1]
          end
        else
          extmark_opts.virt_text_pos = nil
          virt_text_entry[1] = d.virtualtext_char or const.defaults.virtualtext
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
  local detach = { ns_id = {}, functions = {} }
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_start, line_end, false)

  -- Read sass config from new or legacy format
  local sass_enable, sass_parsers_cfg
  if opts.parsers then
    sass_enable = opts.parsers.sass and opts.parsers.sass.enable
    sass_parsers_cfg = opts.parsers.sass and opts.parsers.sass.parsers
  else
    sass_enable = opts.sass and opts.sass.enable
    sass_parsers_cfg = opts.sass and opts.sass.parsers
  end

  -- only update sass varibles when text is changed
  if buf_local_opts.__event ~= "WinScrolled" and sass_enable then
    table.insert(detach.functions, sass.cleanup)

    -- Build matcher options for sass color parsing
    local sass_matcher_opts
    if opts.parsers then
      sass_matcher_opts = config.expand_sass_parsers(sass_parsers_cfg)
    else
      sass_matcher_opts = sass_parsers_cfg
    end

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

  -- Read tailwind mode from new or legacy format
  local tw_mode
  if opts.parsers then
    tw_mode = opts.parsers.tailwind.enable and opts.parsers.tailwind.mode or false
  else
    tw_mode = opts.tailwind
  end

  if tw_mode == "lsp" or tw_mode == "both" then
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
