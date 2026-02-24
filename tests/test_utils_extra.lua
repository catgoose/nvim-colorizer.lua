local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local utils = require("colorizer.utils")

local T = new_set()

-- get_non_alphanum_keys -------------------------------------------------------

T["get_non_alphanum_keys"] = new_set()

T["get_non_alphanum_keys"]["extracts special chars from table keys"] = function()
  local result = utils.get_non_alphanum_keys({ ["red-500"] = true, ["blue_200"] = true })
  eq(true, result:find("-") ~= nil)
end

T["get_non_alphanum_keys"]["returns empty string for alphanum-only keys"] = function()
  local result = utils.get_non_alphanum_keys({ red = true, blue = true, green = true })
  eq("", result)
end

T["get_non_alphanum_keys"]["handles empty table"] = function()
  local result = utils.get_non_alphanum_keys({})
  eq("", result)
end

T["get_non_alphanum_keys"]["deduplicates characters"] = function()
  local result = utils.get_non_alphanum_keys({ ["a-b"] = true, ["c-d"] = true })
  -- Should contain only one dash
  local dash_count = select(2, result:gsub("%-", ""))
  eq(1, dash_count)
end

-- byte_is_valid_color_char / add_additional_color_chars -----------------------

T["byte_is_valid_color_char"] = new_set()

T["byte_is_valid_color_char"]["alphanumeric bytes are valid"] = function()
  eq(true, utils.byte_is_valid_color_char(string.byte("a")))
  eq(true, utils.byte_is_valid_color_char(string.byte("Z")))
  eq(true, utils.byte_is_valid_color_char(string.byte("5")))
end

T["byte_is_valid_color_char"]["special chars are initially invalid"] = function()
  -- '@' is not alphanumeric and unlikely to have been added
  eq(false, utils.byte_is_valid_color_char(string.byte("@")))
end

T["byte_is_valid_color_char"]["add_additional_color_chars makes char valid"] = function()
  -- Use a rare char that won't affect other tests
  local char = "~"
  -- Verify it's not already valid
  local was_valid = utils.byte_is_valid_color_char(string.byte(char))
  if not was_valid then
    utils.add_additional_color_chars(char)
    eq(true, utils.byte_is_valid_color_char(string.byte(char)))
  else
    -- If already valid (from another test), just confirm it's valid
    eq(true, utils.byte_is_valid_color_char(string.byte(char)))
  end
end

T["byte_is_valid_color_char"]["add_additional_color_chars returns true"] = function()
  eq(true, utils.add_additional_color_chars(""))
end

-- get_last_modified -----------------------------------------------------------

T["get_last_modified"] = new_set()

T["get_last_modified"]["returns number for existing file"] = function()
  -- The test file itself should exist
  local result = utils.get_last_modified("tests/test_utils_extra.lua")
  eq("number", type(result))
end

T["get_last_modified"]["returns nil for missing file"] = function()
  local result = utils.get_last_modified("/tmp/nonexistent_file_colorizer_test_" .. os.time() .. ".txt")
  eq(nil, result)
end

-- visible_line_range ----------------------------------------------------------

T["visible_line_range"] = new_set()

T["visible_line_range"]["returns valid range for current buffer"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line1", "line2", "line3" })
  vim.api.nvim_set_current_buf(buf)
  local start, stop = utils.visible_line_range(buf)
  eq("number", type(start))
  eq("number", type(stop))
  eq(true, start >= 0)
  eq(true, stop >= start)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- bufme -----------------------------------------------------------------------

T["bufme"] = new_set()

T["bufme"]["nil returns current buffer"] = function()
  local cur = vim.api.nvim_get_current_buf()
  eq(cur, utils.bufme(nil))
end

T["bufme"]["0 returns current buffer"] = function()
  local cur = vim.api.nvim_get_current_buf()
  eq(cur, utils.bufme(0))
end

T["bufme"]["valid bufnr returns itself"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  eq(buf, utils.bufme(buf))
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- hash_table ------------------------------------------------------------------

T["hash_table"] = new_set()

T["hash_table"]["returns a 64-char hex string"] = function()
  local hash = utils.hash_table({ a = 1, b = 2 })
  eq(64, #hash)
  eq(true, hash:match("^[0-9a-f]+$") ~= nil)
end

T["hash_table"]["same table produces same hash"] = function()
  local h1 = utils.hash_table({ x = "hello" })
  local h2 = utils.hash_table({ x = "hello" })
  eq(h1, h2)
end

T["hash_table"]["different tables produce different hashes"] = function()
  local h1 = utils.hash_table({ x = 1 })
  local h2 = utils.hash_table({ x = 2 })
  eq(true, h1 ~= h2)
end

return T
