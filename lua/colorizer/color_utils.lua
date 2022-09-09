---Helper functions to parse different colour formats
--@module colorizer.color_utils
local Trie = require "colorizer.trie"

local utils = require "colorizer.utils"
local byte_is_alphanumeric = utils.byte_is_alphanumeric
local byte_is_hex = utils.byte_is_hex
local parse_hex = utils.parse_hex
local percent_or_hex = utils.percent_or_hex
local get_last_modified = utils.get_last_modified
local watch_file = utils.watch_file

local uv = vim.loop

local bit = require "bit"
local floor, min, max = math.floor, math.min, math.max
local band, rshift, lshift, tohex = bit.band, bit.rshift, bit.lshift, bit.tohex

local api = vim.api

---Determine whether to use black or white text.
--
-- ref: https://stackoverflow.com/a/1855903/837964
-- https://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color
---@param r number: Red
---@param g number: Green
---@param b number: Blue
local function color_is_bright(r, g, b)
  -- counting the perceptive luminance - human eye favors green color
  local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  if luminance > 0.5 then
    return true -- bright colors, black font
  else
    return false -- dark colors, white font
  end
end

---Convert hsl colour values to rgb.
-- Source: https://gist.github.com/mjackson/5311256
---@param p number
---@param q number
---@param t number
---@return number
local function hue_to_rgb(p, q, t)
  if t < 0 then
    t = t + 1
  end
  if t > 1 then
    t = t - 1
  end
  if t < 1 / 6 then
    return p + (q - p) * 6 * t
  end
  if t < 1 / 2 then
    return q
  end
  if t < 2 / 3 then
    return p + (q - p) * (2 / 3 - t) * 6
  end
  return p
end

local COLOR_MAP
local COLOR_TRIE
local COLOR_NAME_MINLEN, COLOR_NAME_MAXLEN
local COLOR_NAME_SETTINGS = { lowercase = true, strip_digits = false }
local TAILWIND_ENABLED = false
--- Grab all the colour values from `vim.api.nvim_get_color_map` and create a lookup table.
-- COLOR_MAP is used to store the colour values
---@param line string: Line to parse
---@param i number: Index of line from where to start parsing
---@param opts table: Currently contains whether tailwind is enabled or not
local function color_name_parser(line, i, opts)
  --- Setup the COLOR_MAP and COLOR_TRIE
  if not COLOR_TRIE or opts.tailwind ~= TAILWIND_ENABLED then
    COLOR_MAP = {}
    COLOR_TRIE = Trie()
    for k, v in pairs(api.nvim_get_color_map()) do
      if not (COLOR_NAME_SETTINGS.strip_digits and k:match "%d+$") then
        COLOR_NAME_MINLEN = COLOR_NAME_MINLEN and min(#k, COLOR_NAME_MINLEN) or #k
        COLOR_NAME_MAXLEN = COLOR_NAME_MAXLEN and max(#k, COLOR_NAME_MAXLEN) or #k
        local rgb_hex = tohex(v, 6)
        COLOR_MAP[k] = rgb_hex
        COLOR_TRIE:insert(k)
        if COLOR_NAME_SETTINGS.lowercase then
          local lowercase = k:lower()
          COLOR_MAP[lowercase] = rgb_hex
          COLOR_TRIE:insert(lowercase)
        end
      end
    end
    if opts and opts.tailwind then
      if opts.tailwind == true or opts.tailwind == "normal" or opts.tailwind == "both" then
        local tailwind = require "colorizer.tailwind_colors"
        -- setup tailwind colors
        for k, v in pairs(tailwind.colors) do
          for _, pre in ipairs(tailwind.prefixes) do
            local name = pre .. "-" .. k
            COLOR_NAME_MINLEN = COLOR_NAME_MINLEN and min(#name, COLOR_NAME_MINLEN) or #name
            COLOR_NAME_MAXLEN = COLOR_NAME_MAXLEN and max(#name, COLOR_NAME_MAXLEN) or #name
            COLOR_MAP[name] = v
            COLOR_TRIE:insert(name)
          end
        end
      end
    end
    TAILWIND_ENABLED = opts.tailwind
  end

  if #line < i + COLOR_NAME_MINLEN - 1 then
    return
  end

  if i > 1 and byte_is_alphanumeric(line:byte(i - 1)) then
    return
  end

  local prefix = COLOR_TRIE:longest_prefix(line, i)
  if prefix then
    -- Check if there is a letter here so as to disallow matching here.
    -- Take the Blue out of Blueberry
    -- Line end or non-letter.
    local next_byte_index = i + #prefix
    if #line >= next_byte_index and byte_is_alphanumeric(line:byte(next_byte_index)) then
      return
    end
    return #prefix, COLOR_MAP[prefix]
  end
end

local SASS = {}
--- Cleanup sass variables
---@param buf number
local function sass_cleanup(buf)
  SASS[buf] = nil
end

local dollar_hash = ("$"):byte()
local at_hash = ("@"):byte()
local colon_hash = (";"):byte()

-- Helper function for sass_update_variables
local function sass_parse_lines(buf, line_start, content, name)
  SASS[buf].DEFINITIONS_ALL = SASS[buf].DEFINITIONS_ALL or {}
  SASS[buf].DEFINITIONS_RECURSIVE_CURRENT = SASS[buf].DEFINITIONS_RECURSIVE_CURRENT or {}
  SASS[buf].DEFINITIONS_RECURSIVE_CURRENT_ABSOLUTE = SASS[buf].DEFINITIONS_RECURSIVE_CURRENT_ABSOLUTE or {}

  SASS[buf].DEFINITIONS_LINEWISE[name] = SASS[buf].DEFINITIONS_LINEWISE[name] or {}
  SASS[buf].DEFINITIONS[name] = SASS[buf].DEFINITIONS[name] or {}
  SASS[buf].IMPORTS[name] = SASS[buf].IMPORTS[name] or {}
  SASS[buf].WATCH_IMPORTS[name] = SASS[buf].WATCH_IMPORTS[name] or {}
  SASS[buf].CURRENT_IMPORTS[name] = {}

  local import_find_colon = false
  for i, line in ipairs(content) do
    local linenum = i - 1 + line_start
    -- Invalidate any existing definitions for the lines we are processing.
    if not vim.tbl_isempty(SASS[buf].DEFINITIONS_LINEWISE[name][linenum] or {}) then
      for v, _ in pairs(SASS[buf].DEFINITIONS_LINEWISE[name][linenum]) do
        SASS[buf].DEFINITIONS[name][v] = nil
      end
      SASS[buf].DEFINITIONS_LINEWISE[name][linenum] = {}
    else
      SASS[buf].DEFINITIONS_LINEWISE[name][linenum] = {}
    end

    local index = 1
    while index < #line do
      -- ignore comments
      if line:match("^//", index) then
        index = #line
      -- line starting with variables $var
      elseif not import_find_colon and line:byte(index) == dollar_hash then
        local variable_name, variable_value = line:match("^%$([%w_-]+)%s*:%s*(.+)%s*", index)
        -- Check if we got a variable definition
        if variable_name and variable_value then
          -- Check for a recursive variable definition.
          if variable_value:byte() == dollar_hash then
            local target_variable_name, len = variable_value:match "^%$([%w_-]+)()"
            if target_variable_name then
              -- Update the value.
              SASS[buf].DEFINITIONS_RECURSIVE_CURRENT[variable_name] = target_variable_name
              SASS[buf].DEFINITIONS_LINEWISE[name][linenum][variable_name] = true
              index = index + len
            end
            index = index + 1
          else
            -- Check for a recursive variable definition.
            -- If it's not recursive, then just update the value.
            if SASS[buf].COLOR_PARSER then
              local length, rgb_hex = SASS[buf].COLOR_PARSER(variable_value, 1)
              if length and rgb_hex then
                SASS[buf].DEFINITIONS[name][variable_name] = rgb_hex
                SASS[buf].DEFINITIONS_RECURSIVE_CURRENT[variable_name] = rgb_hex
                SASS[buf].DEFINITIONS_RECURSIVE_CURRENT_ABSOLUTE[variable_name] = rgb_hex
                SASS[buf].DEFINITIONS_LINEWISE[name][linenum][variable_name] = true
                -- added 3 because the color parsers returns 3 less
                -- todo: need to fix
                index = index + length + 3
              end
            end
          end
          index = index + #variable_name
        end
      -- color ( ; ) found
      elseif import_find_colon and line:byte(index) == colon_hash then
        import_find_colon, index = false, index + 1
      -- imports @import 'somefile'
      elseif line:byte(index) == at_hash or import_find_colon then
        local variable_value, colon, import_kw
        if import_find_colon then
          variable_value, colon = line:match("%s*(.*[^;])%s*([;]?)", index)
        else
          import_kw, variable_value, colon = line:match("@(%a+)%s+(.+[^;])%s*([;]?)", index)
          import_kw = (import_kw == "import" or import_kw == "use")
        end

        if not colon or colon == "" then
          -- now loop until ; is found
          import_find_colon = true
        else
          import_find_colon = false
        end

        -- if import/use key word is found along with file name
        if import_kw and variable_value then
          local files = {}
          -- grab files to be imported
          for s, a in variable_value:gmatch "['\"](.-)()['\"]" do
            local folder_path, file_name = vim.fn.fnamemodify(s, ":h"), vim.fn.fnamemodify(s, ":t")
            if file_name ~= "" then
              -- get the root directory of the file
              local parent_dir = vim.fn.fnamemodify(name, ":h")
              parent_dir = (parent_dir ~= "") and parent_dir .. "/" or ""
              folder_path = vim.fn.fnamemodify(parent_dir .. folder_path, ":p")
              file_name = file_name
              files = {
                folder_path .. file_name .. ".scss",
                folder_path .. "_" .. file_name .. ".scss",
                folder_path .. file_name .. ".sass",
                folder_path .. "_" .. file_name .. ".sass",
              }
            end
            -- why 2 * a ? I don't know
            index = index + 2 * a
          end

          -- process imported files
          for _, v in ipairs(files) do
            -- parse the sass files
            local last_modified = get_last_modified(v)
            if last_modified then
              -- grab the full path
              v = uv.fs_realpath(v)
              SASS[buf].CURRENT_IMPORTS[name][v] = true

              if not SASS[buf].WATCH_IMPORTS[name][v] then
                SASS[buf].IMPORTS[name][v] = last_modified
                local c, ind = {}, 0
                for l in io.lines(v) do
                  ind = ind + 1
                  c[ind] = l
                end
                sass_parse_lines(buf, 0, c, v)
                c = nil

                local function watch_callback()
                  local dimen = vim.api.nvim_buf_call(buf, function()
                    return { vim.fn.line "w0", vim.fn.line "w$", vim.fn.line "$", vim.api.nvim_win_get_height(0) }
                  end)
                  -- todo: Improve this to only refresh highlight for visible lines
                  -- can't find out how to get visible rows from another window
                  -- probably a neovim bug, it is returning 1 and 1 or 1 and 5
                  if
                    dimen[1] ~= dimen[2]
                    and ((dimen[3] > dimen[4] and dimen[2] > dimen[4]) or (dimen[2] >= dimen[3]))
                  then
                    SASS[buf].LOCAL_OPTIONS.__startline = dimen[1]
                    SASS[buf].LOCAL_OPTIONS.__endline = dimen[2]
                  end
                  SASS[buf].LOCAL_OPTIONS.__event = ""

                  local lastm = get_last_modified(v)
                  if lastm then
                    SASS[buf].IMPORTS[name][v] = lastm
                    local cc, inde = {}, 0
                    for l in io.lines(v) do
                      inde = inde + 1
                      cc[inde] = l
                    end
                    sass_parse_lines(buf, 0, cc, v)
                    cc = nil
                  end

                  require("colorizer.buffer_utils").rehighlight_buffer(
                    buf,
                    SASS[buf].OPTIONS,
                    SASS[buf].LOCAL_OPTIONS,
                    true
                  )
                end
                SASS[buf].WATCH_IMPORTS[name][v] = watch_file(v, watch_callback)
              end
            else
              -- if file does not exists then remove related variables
              SASS[buf].IMPORTS[name][v] = nil
              pcall(uv.fs_event_stop, SASS[buf].WATCH_IMPORTS[name][v])
              SASS[buf].WATCH_IMPORTS[name][v] = nil
            end
          end -- process imported files
        end
      end -- parse lines
      index = index + 1
    end -- while loop end
  end -- for loop end

  local function remove_unused_imports(import_name)
    if type(SASS[buf].IMPORTS[import_name]) == "table" then
      for file, _ in pairs(SASS[buf].IMPORTS[import_name]) do
        remove_unused_imports(file)
      end
    end
    SASS[buf].DEFINITIONS[import_name] = nil
    SASS[buf].DEFINITIONS_LINEWISE[import_name] = nil
    SASS[buf].IMPORTS[import_name] = nil
    -- stop the watch handler
    pcall(uv.fs_event_stop, SASS[buf].WATCH_IMPORTS[import_name])
    SASS[buf].WATCH_IMPORTS[import_name] = nil
  end

  -- remove definitions of files which are not imported now
  for file, _ in pairs(SASS[buf].IMPORTS[name]) do
    if not SASS[buf].CURRENT_IMPORTS[name][file] then
      remove_unused_imports(name)
    end
  end
end -- sass_parse_lines end

--- Parse the given lines for sass variabled and add to SASS[buf].DEFINITIONS_ALL.
-- which is then used in |sass_name_parser|
-- If lines are not given, then fetch the lines with line_start and line_end
---@param buf number
---@param line_start number
---@param line_end number
---@param lines table|nil
---@param color_parser function|boolean
---@param options table: Buffer options
---@param options_local table|nil: Buffer local variables
local function sass_update_variables(buf, line_start, line_end, lines, color_parser, options, options_local)
  lines = lines or vim.api.nvim_buf_get_lines(buf, line_start, line_end, false)

  if not SASS[buf] then
    SASS[buf] = {
      DEFINITIONS_ALL = {},
      DEFINITIONS = {},
      IMPORTS = {},
      WATCH_IMPORTS = {},
      CURRENT_IMPORTS = {},
      DEFINITIONS_LINEWISE = {},
      OPTIONS = options,
      LOCAL_OPTIONS = options_local,
    }
  end

  SASS[buf].COLOR_PARSER = color_parser
  SASS[buf].DEFINITIONS_ALL = {}
  SASS[buf].DEFINITIONS_RECURSIVE_CURRENT = {}
  SASS[buf].DEFINITIONS_RECURSIVE_CURRENT_ABSOLUTE = {}

  sass_parse_lines(buf, line_start, lines, api.nvim_buf_get_name(buf))

  -- add non-recursive def to DEFINITIONS_ALL
  for _, color_table in pairs(SASS[buf].DEFINITIONS) do
    for color_name, color in pairs(color_table) do
      SASS[buf].DEFINITIONS_ALL[color_name] = color
    end
  end

  -- normally this is just a wasted step as all the values here are
  -- already present in SASS[buf].DEFINITIONS
  -- but when undoing a pasted text, it acts as a backup
  for name, color in pairs(SASS[buf].DEFINITIONS_RECURSIVE_CURRENT_ABSOLUTE) do
    SASS[buf].DEFINITIONS_ALL[name] = color
  end

  -- try to find the absolute color value for the given name
  -- use tail call recursion
  -- https://www.lua.org/pil/6.3.html
  local function find_absolute_value(name, color_name)
    return SASS[buf].DEFINITIONS_ALL[color_name]
      or (
        SASS[buf].DEFINITIONS_RECURSIVE_CURRENT[color_name]
        and find_absolute_value(name, SASS[buf].DEFINITIONS_RECURSIVE_CURRENT[color_name])
      )
  end

  local function set_color_value(name, color_name)
    local value = find_absolute_value(name, color_name)
    if value then
      SASS[buf].DEFINITIONS_ALL[name] = value
    end
    SASS[buf].DEFINITIONS_RECURSIVE_CURRENT[name] = nil
  end

  for name, color_name in pairs(SASS[buf].DEFINITIONS_RECURSIVE_CURRENT) do
    set_color_value(name, color_name)
  end

  SASS[buf].DEFINITIONS_RECURSIVE_CURRENT = nil
  SASS[buf].DEFINITIONS_RECURSIVE_CURRENT_ABSOLUTE = nil
end

--- Parse the given line for sass color names
-- check for value in SASS[buf].DEFINITIONS_ALL
---@param line string: Line to parse
---@param i number: Index of line from where to start parsing
---@param buf number
---@return number|nil, string|nil
local function sass_name_parser(line, i, buf)
  local variable_name = line:sub(i):match "^%$([%w_-]+)"
  if variable_name then
    local rgb_hex = SASS[buf].DEFINITIONS_ALL[variable_name]
    if rgb_hex then
      return #variable_name + 1, rgb_hex
    end
  end
end

--- Converts an HSL color value to RGB.
---@param h number: Hue
---@param s number: Saturation
---@param l number: Lightness
---@return number|nil,number|nil,number|nil
local function hsl_to_rgb(h, s, l)
  if h > 1 or s > 1 or l > 1 then
    return
  end
  if s == 0 then
    local r = l * 255
    return r, r, r
  end
  local q
  if l < 0.5 then
    q = l * (1 + s)
  else
    q = l + s - l * s
  end
  local p = 2 * l - q
  return 255 * hue_to_rgb(p, q, h + 1 / 3), 255 * hue_to_rgb(p, q, h), 255 * hue_to_rgb(p, q, h - 1 / 3)
end

local CSS_RGB_FN_MINIMUM_LENGTH = #"rgb(0,0,0)" - 1
---Parse for rgb() css function and return rgb hex.
---@param line string: Line to parse
---@param i number: Index of line from where to start parsing
---@return number|nil: Index of line where the rgb function ended
---@return string|nil: rgb hex value
local function rgb_function_parser(line, i)
  if #line < i + CSS_RGB_FN_MINIMUM_LENGTH then
    return
  end
  local r, g, b, match_end = line:sub(i):match "^rgb%(%s*(%d+%%?)%s*,%s*(%d+%%?)%s*,%s*(%d+%%?)%s*%)()"
  if not match_end then
    r, g, b, match_end = line:sub(i):match "^rgb%(%s*(%d+%%?)%s+(%d+%%?)%s+(%d+%%?)%s*%)()"
    if not match_end then
      return
    end
  end
  r = percent_or_hex(r)
  if not r then
    return
  end
  g = percent_or_hex(g)
  if not g then
    return
  end
  b = percent_or_hex(b)
  if not b then
    return
  end
  local rgb_hex = string.format("%02x%02x%02x", r, g, b)
  return match_end - 1, rgb_hex
end

local CSS_RGBA_FN_MINIMUM_LENGTH = #"rgba(0,0,0,0)" - 1
---Parse for rgba() css function and return rgb hex.
-- Todo consider removing the regexes here
-- Todo this might not be the best approach to alpha channel.
-- Things like pumblend might be useful here.
---@param line string: Line to parse
---@param i number: Index of line from where to start parsing
---@return number|nil: Index of line where the rgba function ended
---@return string|nil: rgb hex value
local function rgba_function_parser(line, i)
  if #line < i + CSS_RGBA_FN_MINIMUM_LENGTH then
    return
  end
  local r, g, b, a, match_end =
    line:sub(i):match "^rgba%(%s*(%d+%%?)%s*,%s*(%d+%%?)%s*,%s*(%d+%%?)%s*,%s*([.%d]+)%s*%)()"
  if not match_end then
    r, g, b, a, match_end = line:sub(i):match "^rgba%(%s*(%d+%%?)%s+(%d+%%?)%s+(%d+%%?)%s+([.%d]+)%s*%)()"
    if not match_end then
      return
    end
  end
  a = tonumber(a)
  if not a or a > 1 then
    return
  end
  r = percent_or_hex(r)
  if not r then
    return
  end
  g = percent_or_hex(g)
  if not g then
    return
  end
  b = percent_or_hex(b)
  if not b then
    return
  end
  local rgb_hex = string.format("%02x%02x%02x", r * a, g * a, b * a)
  return match_end - 1, rgb_hex
end

local CSS_HSL_FN_MINIMUM_LENGTH = #"hsl(0,0%,0%)" - 1
---Parse for hsl() css function and return rgb hex.
---@param line string: Line to parse
---@param i number: Index of line from where to start parsing
---@return number|nil: Index of line where the hsl function ended
---@return string|nil: rgb hex value
local function hsl_function_parser(line, i)
  if #line < i + CSS_HSL_FN_MINIMUM_LENGTH then
    return
  end
  local h, s, l, match_end = line:sub(i):match "^hsl%(%s*(%d+)%s*,%s*(%d+)%%%s*,%s*(%d+)%%%s*%)()"
  if not match_end then
    h, s, l, match_end = line:sub(i):match "^hsl%(%s*(%d+)%s+(%d+)%%%s+(%d+)%%%s*%)()"
    if not match_end then
      return
    end
  end
  h = tonumber(h)
  if h > 360 then
    return
  end
  s = tonumber(s)
  if s > 100 then
    return
  end
  l = tonumber(l)
  if l > 100 then
    return
  end
  local r, g, b = hsl_to_rgb(h / 360, s / 100, l / 100)
  if r == nil or g == nil or b == nil then
    return
  end
  local rgb_hex = string.format("%02x%02x%02x", r, g, b)
  return match_end - 1, rgb_hex
end

local CSS_HSLA_FN_MINIMUM_LENGTH = #"hsla(0,0%,0%,0)" - 1
---Parse for hsl() css function and return rgb hex.
---@param line string: Line to parse
---@param i number: Index of line from where to start parsing
---@return number|nil: Index of line where the hsla function ended
---@return string|nil: rgb hex value
local function hsla_function_parser(line, i)
  if #line < i + CSS_HSLA_FN_MINIMUM_LENGTH then
    return
  end
  local h, s, l, a, match_end = line:sub(i):match "^hsla%(%s*(%d+)%s*,%s*(%d+)%%%s*,%s*(%d+)%%%s*,%s*([.%d]+)%s*%)()"
  if not match_end then
    h, s, l, a, match_end = line:sub(i):match "^hsla%(%s*(%d+)%s+(%d+)%%%s+(%d+)%%%s+([.%d]+)%s*%)()"
    if not match_end then
      return
    end
  end
  a = tonumber(a)
  if not a or a > 1 then
    return
  end
  h = tonumber(h)
  if h > 360 then
    return
  end
  s = tonumber(s)
  if s > 100 then
    return
  end
  l = tonumber(l)
  if l > 100 then
    return
  end
  local r, g, b = hsl_to_rgb(h / 360, s / 100, l / 100)
  if r == nil or g == nil or b == nil then
    return
  end
  local rgb_hex = string.format("%02x%02x%02x", r * a, g * a, b * a)
  return match_end - 1, rgb_hex
end

local ARGB_MINIMUM_LENGTH = #"0xAARRGGBB" - 1
---parse for 0xaarrggbb and return rgb hex.
-- a format used in android apps
---@param line string: line to parse
---@param i number: index of line from where to start parsing
---@return number|nil: index of line where the hex value ended
---@return string|nil: rgb hex value
local function argb_hex_parser(line, i)
  if #line < i + ARGB_MINIMUM_LENGTH then
    return
  end

  local j = i + 2

  local n = j + 8
  local alpha
  local v = 0
  while j <= min(n, #line) do
    local b = line:byte(j)
    if not byte_is_hex(b) then
      break
    end
    if j - i <= 3 then
      alpha = parse_hex(b) + lshift(alpha or 0, 4)
    else
      v = parse_hex(b) + lshift(v, 4)
    end
    j = j + 1
  end
  if #line >= j and byte_is_alphanumeric(line:byte(j)) then
    return
  end
  local length = j - i
  if length ~= 10 then
    return
  end
  alpha = tonumber(alpha) / 255
  local r = floor(band(rshift(v, 16), 0xFF) * alpha)
  local g = floor(band(rshift(v, 8), 0xFF) * alpha)
  local b = floor(band(v, 0xFF) * alpha)
  local rgb_hex = string.format("%02x%02x%02x", r, g, b)
  return length, rgb_hex
end

---parse for #rrggbbaa and return rgb hex.
-- a format used in android apps
---@param line string: line to parse
---@param i number: index of line from where to start parsing
---@param opts table: Containing minlen, maxlen, valid_lengths
---@return number|nil: index of line where the hex value ended
---@return string|nil: rgb hex value
local function rgba_hex_parser(line, i, opts)
  local minlen, maxlen, valid_lengths = opts.minlen, opts.maxlen, opts.valid_lengths
  local j = i + 1
  if #line < j + minlen - 1 then
    return
  end

  if i > 1 and byte_is_alphanumeric(line:byte(i - 1)) then
    return
  end

  local n = j + maxlen
  local alpha
  local v = 0

  while j <= min(n, #line) do
    local b = line:byte(j)
    if not byte_is_hex(b) then
      break
    end
    if j - i >= 7 then
      alpha = parse_hex(b) + lshift(alpha or 0, 4)
    else
      v = parse_hex(b) + lshift(v, 4)
    end
    j = j + 1
  end

  if #line >= j and byte_is_alphanumeric(line:byte(j)) then
    return
  end

  local length = j - i
  if length ~= 4 and length ~= 7 and length ~= 9 then
    return
  end

  if alpha then
    alpha = tonumber(alpha) / 255
    local r = floor(band(rshift(v, 16), 0xFF) * alpha)
    local g = floor(band(rshift(v, 8), 0xFF) * alpha)
    local b = floor(band(v, 0xFF) * alpha)
    local rgb_hex = string.format("%02x%02x%02x", r, g, b)
    return 9, rgb_hex
  end
  return (valid_lengths[length - 1] and length), line:sub(i + 1, i + length - 1)
end

--- @export
return {
  color_is_bright = color_is_bright,
  color_name_parser = color_name_parser,
  rgba_hex_parser = rgba_hex_parser,
  argb_hex_parser = argb_hex_parser,
  rgb_function_parser = rgb_function_parser,
  rgba_function_parser = rgba_function_parser,
  hsl_function_parser = hsl_function_parser,
  hsla_function_parser = hsla_function_parser,
  sass_name_parser = sass_name_parser,
  sass_cleanup = sass_cleanup,
  sass_update_variables = sass_update_variables,
}
