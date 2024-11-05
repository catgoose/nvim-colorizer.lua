---Helper functions to parse sass color variables
--@module colorizer.sass
local api = vim.api
local uv = vim.loop

local utils = require "colorizer.utils"
local get_last_modified = utils.get_last_modified
local watch_file = utils.watch_file

local sass = {}

local DOLLAR_HASH = ("$"):byte()
local AT_HASH = ("@"):byte()
local COLON_HASH = (";"):byte()

local SASS = {}

local function remove_unused_imports(bufnr, import_name)
  if type(SASS[bufnr].IMPORTS[import_name]) == "table" then
    for file, _ in pairs(SASS[bufnr].IMPORTS[import_name]) do
      remove_unused_imports(bufnr, file)
    end
  end
  SASS[bufnr].DEFINITIONS[import_name] = nil
  SASS[bufnr].DEFINITIONS_LINEWISE[import_name] = nil
  SASS[bufnr].IMPORTS[import_name] = nil
  -- stop the watch handler
  pcall(uv.fs_event_stop, SASS[bufnr].WATCH_IMPORTS[import_name])
  SASS[bufnr].WATCH_IMPORTS[import_name] = nil
end

--- Cleanup sass variables and watch handlers
---@param bufnr number
function sass.cleanup(bufnr)
  remove_unused_imports(bufnr, api.nvim_buf_get_name(bufnr))
  SASS[bufnr] = nil
end

--- Parse the given line for sass color names
-- check for value in SASS[buf].DEFINITIONS_ALL
---@param line string: Line to parse
---@param i number: Index of line from where to start parsing
---@param bufnr number
---@return number|nil, string|nil
function sass.name_parser(line, i, bufnr)
  local variable_name = line:match("^%$([%w_-]+)", i)
  if variable_name then
    local rgb_hex = SASS[bufnr].DEFINITIONS_ALL[variable_name]
    if rgb_hex then
      return #variable_name + 1, rgb_hex
    end
  end
end

-- Helper function for sass_update_variables
local function sass_parse_lines(bufnr, line_start, content, name)
  SASS[bufnr].DEFINITIONS_ALL = SASS[bufnr].DEFINITIONS_ALL or {}
  SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT = SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT or {}
  SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT_ABSOLUTE = SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT_ABSOLUTE or {}

  SASS[bufnr].DEFINITIONS_LINEWISE[name] = SASS[bufnr].DEFINITIONS_LINEWISE[name] or {}
  SASS[bufnr].DEFINITIONS[name] = SASS[bufnr].DEFINITIONS[name] or {}
  SASS[bufnr].IMPORTS[name] = SASS[bufnr].IMPORTS[name] or {}
  SASS[bufnr].WATCH_IMPORTS[name] = SASS[bufnr].WATCH_IMPORTS[name] or {}
  SASS[bufnr].CURRENT_IMPORTS[name] = {}

  local import_find_colon = false
  for i, line in ipairs(content) do
    local linenum = i - 1 + line_start
    -- Invalidate any existing definitions for the lines we are processing.
    if not vim.tbl_isempty(SASS[bufnr].DEFINITIONS_LINEWISE[name][linenum] or {}) then
      for v, _ in pairs(SASS[bufnr].DEFINITIONS_LINEWISE[name][linenum]) do
        SASS[bufnr].DEFINITIONS[name][v] = nil
      end
      SASS[bufnr].DEFINITIONS_LINEWISE[name][linenum] = {}
    else
      SASS[bufnr].DEFINITIONS_LINEWISE[name][linenum] = {}
    end

    local index = 1
    while index < #line do
      -- ignore comments
      if line:sub(index, index + 1) == "//" then
        index = #line
      -- line starting with variables $var
      elseif not import_find_colon and line:byte(index) == DOLLAR_HASH then
        local variable_name, variable_value = line:match("^%$([%w_-]+)%s*:%s*(.+)%s*", index)
        -- Check if we got a variable definition
        if variable_name and variable_value then
          -- Check for a recursive variable definition.
          if variable_value:byte() == DOLLAR_HASH then
            local target_variable_name, len = variable_value:match "^%$([%w_-]+)()"
            if target_variable_name then
              -- Update the value.
              SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT[variable_name] = target_variable_name
              SASS[bufnr].DEFINITIONS_LINEWISE[name][linenum][variable_name] = true
              index = index + len
            end
            index = index + 1
          else
            -- Check for a recursive variable definition.
            -- If it's not recursive, then just update the value.
            if SASS[bufnr].COLOR_PARSER then
              local length, rgb_hex = SASS[bufnr].COLOR_PARSER(variable_value, 1)
              if length and rgb_hex then
                SASS[bufnr].DEFINITIONS[name][variable_name] = rgb_hex
                SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT[variable_name] = rgb_hex
                SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT_ABSOLUTE[variable_name] = rgb_hex
                SASS[bufnr].DEFINITIONS_LINEWISE[name][linenum][variable_name] = true
                -- added 3 because the color parsers returns 3 less
                -- todo: need to fix
                index = index + length + 3
              end
            end
          end
          index = index + #variable_name
        end
      -- color ( ; ) found
      elseif import_find_colon and line:byte(index) == COLON_HASH then
        import_find_colon, index = false, index + 1
      -- imports @import 'somefile'
      elseif line:byte(index) == AT_HASH or import_find_colon then
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
              table.insert(files, folder_path .. file_name .. ".scss")
              table.insert(files, folder_path .. "_" .. file_name .. ".scss")
              table.insert(files, folder_path .. file_name .. ".sass")
              table.insert(files, folder_path .. "_" .. file_name .. ".sass")
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
              if v then
                SASS[bufnr].CURRENT_IMPORTS[name][v or ""] = true

                if not SASS[bufnr].WATCH_IMPORTS[name][v] then
                  SASS[bufnr].IMPORTS[name][v or ""] = last_modified
                  local c, ind = {}, 0
                  for l in io.lines(v) do
                    ind = ind + 1
                    c[ind] = l
                  end
                  sass_parse_lines(bufnr, 0, c, v)
                  c = nil

                  local function watch_callback()
                    local dimen = vim.api.nvim_buf_call(bufnr, function()
                      return { vim.fn.line "w0", vim.fn.line "w$", vim.fn.line "$", vim.api.nvim_win_get_height(0) }
                    end)
                    -- todo: Improve this to only refresh highlight for visible lines
                    -- can't find out how to get visible rows from another window
                    -- probably a neovim bug, it is returning 1 and 1 or 1 and 5
                    if
                      SASS[bufnr].LOCAL_OPTIONS
                      and dimen[1] ~= dimen[2]
                      and ((dimen[3] > dimen[4] and dimen[2] > dimen[4]) or (dimen[2] >= dimen[3]))
                    then
                      SASS[bufnr].LOCAL_OPTIONS.__startline = dimen[1]
                      SASS[bufnr].LOCAL_OPTIONS.__endline = dimen[2]
                    end
                    SASS[bufnr].LOCAL_OPTIONS.__event = ""

                    local lastm = get_last_modified(v)
                    if lastm then
                      SASS[bufnr].IMPORTS[name] = SASS[bufnr].IMPORTS[name] or {}
                      SASS[bufnr].IMPORTS[name][v] = lastm
                      local cc, inde = {}, 0
                      for l in io.lines(v) do
                        inde = inde + 1
                        cc[inde] = l
                      end
                      sass_parse_lines(bufnr, 0, cc, v)
                      cc = nil
                    end

                    require("colorizer.buffer").rehighlight(bufnr, SASS[bufnr].OPTIONS, SASS[bufnr].LOCAL_OPTIONS, true)
                  end
                  SASS[bufnr].WATCH_IMPORTS[name][v] = watch_file(v, watch_callback)
                end
              end
            else
              -- if file does not exists then remove related variables
              SASS[bufnr].IMPORTS[name][v] = nil
              pcall(uv.fs_event_stop, SASS[bufnr].WATCH_IMPORTS[name][v])
              SASS[bufnr].WATCH_IMPORTS[name][v] = nil
            end
          end -- process imported files
        end
      end -- parse lines
      index = index + 1
    end -- while loop end
  end -- for loop end

  -- remove definitions of files which are not imported now
  for file, _ in pairs(SASS[bufnr].IMPORTS[name]) do
    if not SASS[bufnr].CURRENT_IMPORTS[name][file] then
      remove_unused_imports(bufnr, name)
    end
  end
end -- sass_parse_lines end

--- Parse the given lines for sass variabled and add to `SASS[buf].DEFINITIONS_ALL`.
-- which is then used in |sass_name_parser|
-- If lines are not given, then fetch the lines with line_start and line_end
---@param bufnr number: buffer number (0 for current)
---@param line_start number
---@param line_end number
---@param lines table|nil
---@param color_parser function|boolean
---@param options table: Buffer options
---@param options_local table|nil: Buffer local variables
function sass.update_variables(bufnr, line_start, line_end, lines, color_parser, options, options_local)
  lines = lines or vim.api.nvim_buf_get_lines(bufnr, line_start, line_end, false)

  if not SASS[bufnr] then
    SASS[bufnr] = {
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

  SASS[bufnr].COLOR_PARSER = color_parser
  SASS[bufnr].DEFINITIONS_ALL = {}
  SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT = {}
  SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT_ABSOLUTE = {}

  sass_parse_lines(bufnr, line_start, lines, api.nvim_buf_get_name(bufnr))

  -- add non-recursive def to DEFINITIONS_ALL
  for _, color_table in pairs(SASS[bufnr].DEFINITIONS) do
    for color_name, color in pairs(color_table) do
      SASS[bufnr].DEFINITIONS_ALL[color_name] = color
    end
  end

  -- normally this is just a wasted step as all the values here are
  -- already present in SASS[buf].DEFINITIONS
  -- but when undoing a pasted text, it acts as a backup
  for name, color in pairs(SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT_ABSOLUTE) do
    SASS[bufnr].DEFINITIONS_ALL[name] = color
  end

  -- try to find the absolute color value for the given name
  -- use tail call recursion
  -- https://www.lua.org/pil/6.3.html
  local function find_absolute_value(name, color_name)
    return SASS[bufnr].DEFINITIONS_ALL[color_name]
      or (
        SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT[color_name]
        and find_absolute_value(name, SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT[color_name])
      )
  end

  local function set_color_value(name, color_name)
    local value = find_absolute_value(name, color_name)
    if value then
      SASS[bufnr].DEFINITIONS_ALL[name] = value
    end
    SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT[name] = nil
  end

  for name, color_name in pairs(SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT) do
    set_color_value(name, color_name)
  end

  SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT = nil
  SASS[bufnr].DEFINITIONS_RECURSIVE_CURRENT_ABSOLUTE = nil
end

return sass
