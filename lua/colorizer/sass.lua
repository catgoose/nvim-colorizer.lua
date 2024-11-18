--- Manages Sass variable parsing and color detection for buffers.
-- This module handles the parsing of Sass color variables, managing import statements,
-- and watching files for updates to Sass variable definitions.
-- It supports recursive Sass imports, resolving color values for each variable, and caching color definitions.
-- @module colorizer.sass

local M = {}

local utils = require("colorizer.utils")

local state = {}

local function remove_unused_imports(bufnr, import_name)
  if type(state[bufnr].imports[import_name]) == "table" then
    for file, _ in pairs(state[bufnr].imports[import_name]) do
      remove_unused_imports(bufnr, file)
    end
  end
  state[bufnr].definitions[import_name] = nil
  state[bufnr].definitions_linewise[import_name] = nil
  state[bufnr].imports[import_name] = nil
  -- stop the watch handler
  pcall(vim.loop.fs_event_stop, state[bufnr].watch_imports[import_name])
  state[bufnr].watch_imports[import_name] = nil
end

--- Cleanup sass variables and watch handlers
---@param bufnr number
function M.cleanup(bufnr)
  remove_unused_imports(bufnr, vim.api.nvim_buf_get_name(bufnr))
  state[bufnr] = nil
end

--- Parse the given line for sass color names
-- check for value in state[buf].definitions_all
---@param line string: Line to parse
---@param i number: Index of line from where to start parsing
---@param bufnr number: Buffer number
---@return number|nil, string|nil
function M.name_parser(line, i, bufnr)
  local variable_name = line:match("^%$([%w_-]+)", i)
  if variable_name then
    local rgb_hex = state[bufnr].definitions_all[variable_name]
    if rgb_hex then
      return #variable_name + 1, rgb_hex
    end
  end
end

-- Helper function for sass_update_variables
local function sass_parse_lines(bufnr, line_start, content, name)
  state[bufnr].definitions_all = state[bufnr].definitions_all or {}
  state[bufnr].definitions_recursive_current = state[bufnr].definitions_recursive_current or {}
  state[bufnr].definitions_recursive_current_absolute = state[bufnr].definitions_recursive_current_absolute
    or {}

  state[bufnr].definitions_linewise[name] = state[bufnr].definitions_linewise[name] or {}
  state[bufnr].definitions[name] = state[bufnr].definitions[name] or {}
  state[bufnr].imports[name] = state[bufnr].imports[name] or {}
  state[bufnr].watch_imports[name] = state[bufnr].watch_imports[name] or {}
  state[bufnr].current_imports[name] = {}

  local import_find_colon = false
  for i, line in ipairs(content) do
    local linenum = i - 1 + line_start
    -- Invalidate any existing definitions for the lines we are processing.
    if not vim.tbl_isempty(state[bufnr].definitions_linewise[name][linenum] or {}) then
      for v, _ in pairs(state[bufnr].definitions_linewise[name][linenum]) do
        state[bufnr].definitions[name][v] = nil
      end
      state[bufnr].definitions_linewise[name][linenum] = {}
    else
      state[bufnr].definitions_linewise[name][linenum] = {}
    end

    local index = 1
    while index < #line do
      -- ignore comments
      if line:sub(index, index + 1) == "//" then
        index = #line
      -- line starting with variables $var
      elseif not import_find_colon and line:byte(index) == ("$"):byte() then
        local variable_name, variable_value = line:match("^%$([%w_-]+)%s*:%s*(.+)%s*", index)
        -- Check if we got a variable definition
        if variable_name and variable_value then
          -- Check for a recursive variable definition.
          if variable_value:byte() == ("$"):byte() then
            local target_variable_name, len = variable_value:match("^%$([%w_-]+)()")
            if target_variable_name then
              -- Update the value.
              state[bufnr].definitions_recursive_current[variable_name] = target_variable_name
              state[bufnr].definitions_linewise[name][linenum][variable_name] = true
              index = index + len
            end
            index = index + 1
          else
            -- Check for a recursive variable definition.
            -- If it's not recursive, then just update the value.
            if state[bufnr].color_parser then
              local length, rgb_hex = state[bufnr].COLOR_PARSER(variable_value, 1)
              if length and rgb_hex then
                state[bufnr].definitions[name][variable_name] = rgb_hex
                state[bufnr].definitions_recursive_current[variable_name] = rgb_hex
                state[bufnr].definitions_recursive_current_absolute[variable_name] = rgb_hex
                state[bufnr].definitions_linewise[name][linenum][variable_name] = true
                -- added 3 because the color parsers returns 3 less
                -- todo: need to fix
                index = index + length + 3
              end
            end
          end
          index = index + #variable_name
        end
      -- color ( ; ) found
      elseif import_find_colon and line:byte(index) == (";"):byte() then
        import_find_colon, index = false, index + 1
      -- imports @import 'somefile'
      elseif line:byte(index) == ("@"):byte() or import_find_colon then
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
          for s, a in variable_value:gmatch("['\"](.-)()['\"]") do
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
            local last_modified = utils.get_last_modified(v)
            if last_modified then
              -- grab the full path
              v = vim.loop.fs_realpath(v)
              if v then
                state[bufnr].current_imports[name][v or ""] = true

                if not state[bufnr].watch_imports[name][v] then
                  state[bufnr].imports[name][v or ""] = last_modified
                  local c, ind = {}, 0
                  for l in io.lines(v) do
                    ind = ind + 1
                    c[ind] = l
                  end
                  sass_parse_lines(bufnr, 0, c, v)
                  c = nil

                  local function watch_callback()
                    local dimen = vim.api.nvim_buf_call(bufnr, function()
                      return {
                        vim.fn.line("w0"),
                        vim.fn.line("w$"),
                        vim.fn.line("$"),
                        vim.api.nvim_win_get_height(0),
                      }
                    end)
                    -- todo: Improve this to only refresh highlight for visible lines
                    -- can't find out how to get visible rows from another window
                    -- probably a neovim bug, it is returning 1 and 1 or 1 and 5
                    if
                      state[bufnr].local_options
                      and dimen[1] ~= dimen[2]
                      and ((dimen[3] > dimen[4] and dimen[2] > dimen[4]) or (dimen[2] >= dimen[3]))
                    then
                      state[bufnr].local_options.__startline = dimen[1]
                      state[bufnr].local_options.__endline = dimen[2]
                    end
                    state[bufnr].local_options.__event = ""

                    local lastm = utils.get_last_modified(v)
                    if lastm then
                      state[bufnr].imports[name] = state[bufnr].imports[name] or {}
                      state[bufnr].imports[name][v] = lastm
                      local cc, inde = {}, 0
                      for l in io.lines(v) do
                        inde = inde + 1
                        cc[inde] = l
                      end
                      sass_parse_lines(bufnr, 0, cc, v)
                      cc = nil
                    end

                    require("colorizer.buffer").rehighlight(
                      bufnr,
                      state[bufnr].options,
                      state[bufnr].local_options,
                      true
                    )
                  end
                  state[bufnr].watch_imports[name][v] = utils.watch_file(v, watch_callback)
                end
              end
            else
              -- if file does not exists then remove related variables
              state[bufnr].imports[name][v] = nil
              pcall(vim.loop.fs_event_stop, state[bufnr].watch_imports[name][v])
              state[bufnr].watch_imports[name][v] = nil
            end
          end -- process imported files
        end
      end -- parse lines
      index = index + 1
    end -- while loop end
  end -- for loop end

  -- remove definitions of files which are not imported now
  for file, _ in pairs(state[bufnr].imports[name]) do
    if not state[bufnr].current_imports[name][file] then
      remove_unused_imports(bufnr, name)
    end
  end
end -- sass_parse_lines end

--- Parse the given lines for sass variabled and add to `SASS[buf].DEFINITIONS_ALL`.
-- which is then used in |sass_name_parser|
-- If lines are not given, then fetch the lines with line_start and line_end
---@param bufnr number: Buffer number
---@param line_start number
---@param line_end number
---@param lines table|nil
---@param color_parser function|boolean
---@param options table: Buffer options
---@param options_local table|nil: Buffer local variables
function M.update_variables(
  bufnr,
  line_start,
  line_end,
  lines,
  color_parser,
  options,
  options_local
)
  lines = lines or vim.api.nvim_buf_get_lines(bufnr, line_start, line_end, false)

  if not state[bufnr] then
    state[bufnr] = {
      definitions_all = {},
      definitions = {},
      imports = {},
      watch_imports = {},
      current_imports = {},
      definitions_linewise = {},
      options = options,
      local_options = options_local,
    }
  end

  state[bufnr].color_parser = color_parser
  state[bufnr].definitions_all = {}
  state[bufnr].definitions_recursive_current = {}
  state[bufnr].definitions_recursive_current_absolute = {}

  sass_parse_lines(bufnr, line_start, lines, vim.api.nvim_buf_get_name(bufnr))

  -- add non-recursive def to DEFINITIONS_ALL
  for _, color_table in pairs(state[bufnr].definitions) do
    for color_name, color in pairs(color_table) do
      state[bufnr].definitions_all[color_name] = color
    end
  end

  -- normally this is just a wasted step as all the values here are
  -- already present in SASS[buf].DEFINITIONS
  -- but when undoing a pasted text, it acts as a backup
  for name, color in pairs(state[bufnr].definitions_recursive_current_absolute) do
    state[bufnr].definitions_all[name] = color
  end

  -- try to find the absolute color value for the given name
  -- use tail call recursion
  -- https://www.lua.org/pil/6.3.html
  local function find_absolute_value(name, color_name)
    return state[bufnr].definitions_all[color_name]
      or (
        state[bufnr].definitions_recursive_current[color_name]
        and find_absolute_value(name, state[bufnr].definitions_recursive_current[color_name])
      )
  end

  local function set_color_value(name, color_name)
    local value = find_absolute_value(name, color_name)
    if value then
      state[bufnr].definitions_all[name] = value
    end
    state[bufnr].definitions_recursive_current[name] = nil
  end

  for name, color_name in pairs(state[bufnr].definitions_recursive_current) do
    set_color_value(name, color_name)
  end

  state[bufnr].definitions_recursive_current = nil
  state[bufnr].definitions_recursive_current_absolute = nil
end

return M
