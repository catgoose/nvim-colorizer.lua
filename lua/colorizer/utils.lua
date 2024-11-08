--@module colorizer.utils
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
local BYTE_CATEGORY = ffi.new("uint8_t[256]")
local CATEGORY_DIGIT = lshift(1, 0)
local CATEGORY_ALPHA = lshift(1, 1)
local CATEGORY_HEX = lshift(1, 2)
local CATEGORY_ALPHANUM = bor(CATEGORY_ALPHA, CATEGORY_DIGIT)

do
  -- do not run the loop multiple times
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
    BYTE_CATEGORY[i] = v
  end
end

---Obvious.
---@param byte number
---@return boolean
function M.byte_is_alphanumeric(byte)
  local category = BYTE_CATEGORY[byte]
  return band(category, CATEGORY_ALPHANUM) ~= 0
end

---Obvious.
---@param byte number
---@return boolean
function M.byte_is_hex(byte)
  return band(BYTE_CATEGORY[byte], CATEGORY_HEX) ~= 0
end

---Valid colorchars are alphanumeric and - ( tailwind colors )
---@param byte number
---@return boolean
function M.byte_is_valid_colorchar(byte)
  return M.byte_is_alphanumeric(byte) or byte == ("-"):byte()
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

---Merge two tables.
--
-- todo: Remove this and use `vim.tbl_deep_extend`
---@return table
function M.merge(...)
  local res = {}
  for i = 1, select("#", ...) do
    local o = select(i, ...)
    if type(o) ~= "table" then
      return {}
    end
    for k, v in pairs(o) do
      res[k] = v
    end
  end
  return res
end

--- Obvious.
---@param byte number
---@return number
function M.parse_hex(byte)
  return rshift(BYTE_CATEGORY[byte], 4)
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

--- Get the row range of the current window
---@param state colorizerState: Colorizer state
---@param bufnr number: Buffer number
function M.getrow(state, bufnr)
  state.buffer_lines[bufnr] = state.buffer_lines[bufnr] or {}
  local a = vim.api.nvim_buf_call(bufnr, function()
    return {
      vim.fn.line("w0"),
      vim.fn.line("w$"),
    }
  end)
  local min, max
  local new_min, new_max = a[1] - 1, a[2]
  local old_min, old_max = state.buffer_lines[bufnr]["min"], state.buffer_lines[bufnr]["max"]
  if old_min and old_max then
    -- Triggered for TextChanged autocmds
    -- TODO: Find a way to just apply highlight to changed text lines
    if (old_max == new_max) or (old_min == new_min) then
      min, max = new_min, new_max
    -- Triggered for WinScrolled autocmd - Scroll Down
    elseif old_max < new_max then
      min = old_max
      max = new_max
    -- Triggered for WinScrolled autocmd - Scroll Up
    elseif old_max > new_max then
      min = new_min
      max = new_min + (old_max - new_max)
    end
    -- just in case a long jump was made
    if max - min > new_max - new_min then
      min = new_min
      max = new_max
    end
  end
  min = min or new_min
  max = max or new_max
  -- store current window position to be used later to incremently highlight
  state.buffer_lines[bufnr]["max"] = new_max
  state.buffer_lines[bufnr]["min"] = new_min
  return min, max
end

--- Get validate buffer number
---@return number: Returns bufnr if valid buf and not 0, else current buffer
function M.bufme(bufnr)
  return bufnr and bufnr ~= 0 and vim.api.nvim_buf_is_valid(bufnr) and bufnr
    or vim.api.nvim_get_current_buf()
end

return M
