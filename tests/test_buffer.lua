local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local buffer = require("colorizer.buffer")
local config = require("colorizer.config")
local names = require("colorizer.parser.names")

local T = new_set({
  hooks = {
    pre_case = function()
      names.reset_cache()
      buffer.reset_cache()
      config.get_setup_options(nil)
    end,
  },
})

-- Helper: create a scratch buffer with given lines
local function make_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

-- Helper: standard opts enabling most parsers
local function all_opts()
  return config.apply_alias_options({
    css = true,
    AARRGGBB = true,
    xterm = true,
    tailwind = false,
    names_opts = {
      lowercase = true,
      camelcase = false,
      uppercase = false,
      strip_digits = false,
    },
  })
end

-- parse_lines -----------------------------------------------------------------

T["parse_lines"] = new_set()

T["parse_lines"]["finds #RRGGBB in buffer"] = function()
  local buf = make_buf({ "#FF0000 some text #00FF00" })
  local opts = all_opts()
  local data = buffer.parse_lines(buf, { "#FF0000 some text #00FF00" }, 0, opts)
  eq(true, data ~= nil)
  eq(true, data[0] ~= nil)
  eq(2, #data[0])
  eq("ff0000", data[0][1].rgb_hex:lower())
  eq("00ff00", data[0][2].rgb_hex:lower())
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["parse_lines"]["finds rgb() function"] = function()
  local buf = make_buf({ "rgb(255, 0, 0)" })
  local opts = all_opts()
  local data = buffer.parse_lines(buf, { "rgb(255, 0, 0)" }, 0, opts)
  eq(true, data ~= nil)
  eq(true, data[0] ~= nil)
  eq(1, #data[0])
  eq("ff0000", data[0][1].rgb_hex)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["parse_lines"]["finds hsl() function"] = function()
  local buf = make_buf({ "hsl(0, 100%, 50%)" })
  local opts = all_opts()
  local data = buffer.parse_lines(buf, { "hsl(0, 100%, 50%)" }, 0, opts)
  eq(true, data ~= nil)
  eq(true, data[0] ~= nil)
  eq(1, #data[0])
  -- hsl(0, 100%, 50%) = pure red
  eq("ff0000", data[0][1].rgb_hex)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["parse_lines"]["finds named colors"] = function()
  local buf = make_buf({ "red blue" })
  local opts = all_opts()
  local data = buffer.parse_lines(buf, { "red blue" }, 0, opts)
  eq(true, data ~= nil)
  eq(true, data[0] ~= nil)
  eq(2, #data[0])
  eq("ff0000", data[0][1].rgb_hex)
  eq("0000ff", data[0][2].rgb_hex)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["parse_lines"]["mixed formats on single line"] = function()
  local buf = make_buf({ "#F00 rgb(0,255,0) blue" })
  local opts = all_opts()
  local data = buffer.parse_lines(buf, { "#F00 rgb(0,255,0) blue" }, 0, opts)
  eq(true, data ~= nil)
  eq(true, data[0] ~= nil)
  eq(3, #data[0])
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["parse_lines"]["multiple lines"] = function()
  local lines = { "#FF0000", "#00FF00", "#0000FF" }
  local buf = make_buf(lines)
  local opts = all_opts()
  local data = buffer.parse_lines(buf, lines, 0, opts)
  eq(true, data ~= nil)
  eq(true, data[0] ~= nil)
  eq(true, data[1] ~= nil)
  eq(true, data[2] ~= nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["parse_lines"]["empty line produces no data"] = function()
  local buf = make_buf({ "" })
  local opts = all_opts()
  local data = buffer.parse_lines(buf, { "" }, 0, opts)
  eq(true, data ~= nil)
  -- Empty line should have no entries
  eq(nil, data[0])
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["parse_lines"]["0xRRGGBB format"] = function()
  local buf = make_buf({ "0xFF00FF" })
  local opts = all_opts()
  local data = buffer.parse_lines(buf, { "0xFF00FF" }, 0, opts)
  eq(true, data ~= nil)
  eq(true, data[0] ~= nil)
  eq("ff00ff", data[0][1].rgb_hex)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["parse_lines"]["range is correct (0-indexed columns)"] = function()
  local buf = make_buf({ "  #FF0000  " })
  local opts = all_opts()
  local data = buffer.parse_lines(buf, { "  #FF0000  " }, 0, opts)
  eq(true, data ~= nil)
  eq(true, data[0] ~= nil)
  -- range is {start_col, end_col} 0-indexed
  eq(2, data[0][1].range[1]) -- starts at column 2 (0-indexed)
  eq(9, data[0][1].range[2]) -- ends at column 9
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["parse_lines"]["no colors found returns empty data"] = function()
  local buf = make_buf({ "no colors here at all" })
  local opts = all_opts()
  local data = buffer.parse_lines(buf, { "no colors here at all" }, 0, opts)
  eq(true, data ~= nil)
  eq(nil, data[0]) -- no entries for line 0
  vim.api.nvim_buf_delete(buf, { force = true })
end

return T
