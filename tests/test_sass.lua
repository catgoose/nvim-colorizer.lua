local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local sass = require("colorizer.sass")

local T = new_set()

-- Helper: create a named scratch buffer for sass
local function make_sass_buf(lines, name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(buf, name or ("/tmp/test_sass_" .. buf .. ".scss"))
  return buf
end

-- Helper: simple color parser that recognizes #RRGGBB
local function simple_color_parser(line, i)
  if line:sub(i, i) == "#" and #line >= i + 6 then
    local hex = line:sub(i + 1, i + 6):lower()
    if hex:match("^[0-9a-f]+$") then
      return 7, hex
    end
  end
end

-- parser() --------------------------------------------------------------------

T["parser()"] = new_set()

T["parser()"]["matches $varname when definition exists"] = function()
  local buf = make_sass_buf({ "$primary: #ff0000;" })
  local lines = { "$primary: #ff0000;" }
  sass.update_variables(buf, 0, 1, lines, simple_color_parser, {}, {})
  local len, hex = sass.parser("$primary", 1, buf)
  eq(true, len ~= nil)
  eq("ff0000", hex)
  sass.cleanup(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["parser()"]["returns nil for undefined variable"] = function()
  local buf = make_sass_buf({ "$primary: #ff0000;" })
  local lines = { "$primary: #ff0000;" }
  sass.update_variables(buf, 0, 1, lines, simple_color_parser, {}, {})
  local len, hex = sass.parser("$unknown", 1, buf)
  eq(nil, len)
  eq(nil, hex)
  sass.cleanup(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- update_variables() ----------------------------------------------------------

T["update_variables()"] = new_set()

T["update_variables()"]["parses $color: #ff0000; line"] = function()
  local buf = make_sass_buf({ "$color: #ff0000;" })
  local lines = { "$color: #ff0000;" }
  sass.update_variables(buf, 0, 1, lines, simple_color_parser, {}, {})
  local len, hex = sass.parser("$color", 1, buf)
  eq(true, len ~= nil)
  eq("ff0000", hex)
  sass.cleanup(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["update_variables()"]["resolves recursive $a: $b chains"] = function()
  local buf = make_sass_buf({ "$base: #00ff00;", "$alias: $base;" })
  local lines = { "$base: #00ff00;", "$alias: $base;" }
  sass.update_variables(buf, 0, 2, lines, simple_color_parser, {}, {})
  -- $base should be directly defined
  local len1, hex1 = sass.parser("$base", 1, buf)
  eq(true, len1 ~= nil)
  eq("00ff00", hex1)
  -- $alias should resolve through $base
  local len2, hex2 = sass.parser("$alias", 1, buf)
  eq(true, len2 ~= nil)
  eq("00ff00", hex2)
  sass.cleanup(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["update_variables()"]["comments are skipped"] = function()
  local buf = make_sass_buf({ "// $commented: #ff0000;", "$real: #0000ff;" })
  local lines = { "// $commented: #ff0000;", "$real: #0000ff;" }
  sass.update_variables(buf, 0, 2, lines, simple_color_parser, {}, {})
  -- commented variable should not be defined
  local len1, hex1 = sass.parser("$commented", 1, buf)
  eq(nil, len1)
  eq(nil, hex1)
  -- real variable should be defined
  local len2, hex2 = sass.parser("$real", 1, buf)
  eq(true, len2 ~= nil)
  eq("0000ff", hex2)
  sass.cleanup(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["update_variables()"]["multiple variables on separate lines"] = function()
  local buf = make_sass_buf({ "$red: #ff0000;", "$green: #00ff00;", "$blue: #0000ff;" })
  local lines = { "$red: #ff0000;", "$green: #00ff00;", "$blue: #0000ff;" }
  sass.update_variables(buf, 0, 3, lines, simple_color_parser, {}, {})
  local _, hex_r = sass.parser("$red", 1, buf)
  local _, hex_g = sass.parser("$green", 1, buf)
  local _, hex_b = sass.parser("$blue", 1, buf)
  eq("ff0000", hex_r)
  eq("00ff00", hex_g)
  eq("0000ff", hex_b)
  sass.cleanup(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- cleanup() -------------------------------------------------------------------

T["cleanup()"] = new_set()

T["cleanup()"]["after cleanup parser returns nil"] = function()
  local buf = make_sass_buf({ "$color: #ff0000;" })
  local lines = { "$color: #ff0000;" }
  sass.update_variables(buf, 0, 1, lines, simple_color_parser, {}, {})
  sass.cleanup(buf)
  -- After cleanup, state is gone so parser should error or return nil
  -- We need to handle the case that state[bufnr] is nil
  local ok, result = pcall(sass.parser, "$color", 1, buf)
  -- Either it errors because state is nil, or returns nil
  eq(true, not ok or result == nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

return T
