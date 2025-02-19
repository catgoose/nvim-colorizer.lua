--[[-- Provides utility functions for color handling and file operations.
This module contains helper functions for checking byte categories, merging tables,
parsing colors, managing file watchers, and handling buffer lines.
]]
-- @module colorizer.utils
local M = {}

local bit, ffi = require("bit"), require("ffi")
local band, bor, rshift, lshift = bit.band, bit.bor, bit.rshift, bit.lshift

-- -- TODO use rgb as the return value from the matcher functions
-- -- instead of the rgb_hex. Can be the highlight key as well
-- -- when you shift it left 8 bits. Use the lower 8 bits for
-- -- indicating which highlight mode to use.
-- ffi.cdef [[
-- typedef struct { uint8_t r, g, b; } colorizer_rgb;
-- ]]
-- local rgb_t = ffi.typeof 'colorizer_rgb'

-- Create a lookup table where the bottom 4 bits are used to indicate the
-- category and the top 4 bits are the hex value of the ASCII byte.
local byte_category = ffi.new("uint8_t[256]")

local category_hex = lshift(1, 2)
local category_alphanum = bor(lshift(1, 1) --[[alpha]], lshift(1, 0) --[[digit]])
local additional_color_chars = ""

do
  local b = string.byte
  local byte_values =
    { ["0"] = b("0"), ["9"] = b("9"), ["a"] = b("a"), ["f"] = b("f"), ["z"] = b("z") }
  for i = 0, 255 do
    local v = 0
    local lowercase = bor(i, 0x20)
    -- Digit is bit 1
    if i >= byte_values["0"] and i <= byte_values["9"] then
      v = bor(v, lshift(1, 0))
      v = bor(v, lshift(1, 2))
      v = bor(v, lshift(i - byte_values["0"], 4))
    elseif lowercase >= byte_values["a"] and lowercase <= byte_values["z"] then
      -- Alpha is bit 2
      v = bor(v, lshift(1, 1))
      if lowercase <= byte_values["f"] then
        v = bor(v, lshift(1, 2))
        v = bor(v, lshift(lowercase - byte_values["a"] + 10, 4))
      end
    end
    byte_category[i] = v
  end
end

--- Returns HEX format from RGB values
---@param r number: Red value
---@param g number: Green value
---@param b number: Blue value
function M.rgb_to_hex(r, g, b)
  local rgb_hex = string.format("%02x%02x%02x", r, g, b)
  return rgb_hex
end

--- Checks if a byte represents an alphanumeric character.
---@param byte number The byte to check.
---@return boolean: `true` if the byte is alphanumeric, otherwise `false`.
function M.byte_is_alphanumeric(byte)
  return band(byte_category[byte], category_alphanum) ~= 0
end

--- Checks if a byte represents a hexadecimal character.
---@param byte number The byte to check.
---@return boolean: `true` if the byte is hexadecimal, otherwise `false`.
function M.byte_is_hex(byte)
  return band(byte_category[byte], category_hex) ~= 0
end

--- Extract non-alphanumeric characters to add as a valid index in the Trie
---@param tbl table: The table to extract non-alphanumeric characters from.
---@return string: The extracted non-alphanumeric characters.
function M.get_non_alphanum_keys(tbl)
  local non_alphanum_chars = {}
  for key, _ in pairs(tbl) do
    for char in key:gmatch("[^%w]") do
      non_alphanum_chars[char] = true
    end
  end
  local result = ""
  for char in pairs(non_alphanum_chars) do
    result = result .. char
  end
  return result
end

--- Adds additional characters to the list of valid color characters.
---@param chars string: The additional characters to add.
---@return boolean: `true` if the characters were added, otherwise `false`.
function M.add_additional_color_chars(chars)
  for i = 1, #chars do
    local char = chars:sub(i, i)
    local char_byte = string.byte(char)
    -- It's possible to define `custom_names` with spaces.  Ignore space: it's by empty space that separate things may exist 🧘
    if
      char_byte ~= 32
      and char_byte ~= ("'"):byte()
      and char_byte ~= ('"'):byte()
      and byte_category[char_byte] == 0
    then
      additional_color_chars = additional_color_chars .. char
      byte_category[char_byte] = 1
    end
  end
  return true
end

--- Checks if a byte is valid as a color character (alphanumeric, dynamically added chars, or hardcoded characters).
---@param byte number: The byte to check.
---@return boolean: `true` if the byte is valid, otherwise `false`.
function M.byte_is_valid_color_char(byte)
  if M.byte_is_alphanumeric(byte) then
    return true
  end
  -- Check additional characters for the provided key
  for i = 1, #additional_color_chars do
    if byte == additional_color_chars:byte(i) then
      return true
    end
  end
  return false
end

---Count the number of character in a string
---@param str string
---@param pattern string
---@return number
function M.count(str, pattern)
  return select(2, string.gsub(str, pattern, ""))
end

--- Get last modified time of a file
---@param path string: file path
---@return number|nil: modified time
function M.get_last_modified(path)
  local fd = vim.loop.fs_open(path, "r", 438)
  if not fd then
    return
  end

  local stat = vim.loop.fs_fstat(fd)
  vim.loop.fs_close(fd)
  if stat then
    return stat.mtime.nsec
  else
    return
  end
end

--- Parses a hexadecimal byte.
---@param byte number The byte to parse.
---@return number: The parsed hexadecimal value of the byte.
function M.parse_hex(byte)
  return rshift(byte_category[byte], 4)
end

--- Watch a file for changes and execute callback
---@param path string: File path
---@param callback function: Callback to execute
---@param ... table: params for callback
---@return uv_fs_event_t|nil
function M.watch_file(path, callback, ...)
  if not path or type(callback) ~= "function" then
    return
  end

  local fullpath = vim.loop.fs_realpath(path)
  if not fullpath then
    return
  end

  local start
  local args = { ... }

  local handle = vim.loop.new_fs_event()
  if not handle then
    return
  end
  local function on_change(err, filename, _)
    -- Do work...
    callback(filename, unpack(args))
    -- Debounce: stop/start.
    handle:stop()
    if not err or not M.get_last_modified(filename) then
      start()
    end
  end

  function start()
    vim.loop.fs_event_start(
      handle,
      fullpath,
      {},
      vim.schedule_wrap(function(...)
        on_change(...)
      end)
    )
  end

  start()
  return handle
end

--- Validates and returns a buffer number.
-- If the provided buffer number is invalid, defaults to the current buffer.
---@param bufnr number|nil: The buffer number to validate.
---@return number: The validated buffer number.
function M.bufme(bufnr)
  return bufnr and bufnr ~= 0 and vim.api.nvim_buf_is_valid(bufnr) and bufnr
    or vim.api.nvim_get_current_buf()
end

--- Returns range of visible lines
---@param bufnr number: Buffer number
---@return number, number: Start (0-index) and end (exclusive) range of lines in viewport
function M.visible_line_range(bufnr)
  bufnr = M.bufme(bufnr)
  local range = vim.api.nvim_buf_call(bufnr, function()
    return {
      vim.fn.line("w0"),
      vim.fn.line("w$"),
    }
  end)
  return range[1] - 1, range[2]
end

function M.log_message(message)
  if vim.version().minor >= 11 then
    vim.api.nvim_echo({ { message, "ErrorMsg" } }, true, {})
  else
    vim.api.nvim_err_writeln(message)
  end
end

--- Returns sha256 hash of lua table
---@param tbl table: Table to be hashed
function M.hash_table(tbl)
  -- local json_string = vim.json.encode(tbl, { escape_slash = true })
  local json_string = vim.json.encode(tbl)
  local hash = vim.fn.sha256(json_string)
  return hash
end

return M
