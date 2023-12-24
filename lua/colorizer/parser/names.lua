---Helper function to parse argb
local api = vim.api

local bit = require "bit"
local tohex = bit.tohex

local min, max = math.min, math.max

local Trie = require "colorizer.trie"

local utils = require "colorizer.utils"
local byte_is_valid_colorchar = utils.byte_is_valid_colorchar

local parser = {}

local COLOR_MAP
local COLOR_TRIE
local COLOR_NAME_MINLEN, COLOR_NAME_MAXLEN
-- if any settings are changed, remember to call parser.init() to refresh the map
local COLOR_NAME_SETTINGS = { lowercase = false, strip_digits = false }
parser.settings = COLOR_NAME_SETTINGS
---@type boolean|string|table<string,string>|function
local CUSTOM_ENABLED = false

function parser.init(opts)
  if opts == nil then
    opts = CUSTOM_ENABLED
  end
  COLOR_MAP = {}
  COLOR_TRIE = Trie()
  COLOR_NAME_MINLEN, COLOR_NAME_MAXLEN = 1e10, 0

  local function addPair(k, v)
    COLOR_NAME_MINLEN, COLOR_NAME_MAXLEN = min(#k, COLOR_NAME_MINLEN), max(#k, COLOR_NAME_MAXLEN)
    COLOR_MAP[k] = v
    COLOR_TRIE:insert(k)
    if COLOR_NAME_SETTINGS.lowercase then
      local lowercase = k:lower()
      COLOR_MAP[lowercase] = v
      COLOR_TRIE:insert(lowercase)
    end
  end

  if type(opts) == "table" or type(opts) == "function" then
    local hash = string.byte "#"
    for k, v in pairs(type(opts) == "function" and opts() or opts) do
      addPair(k, v:byte(1) == hash and v:sub(2) or v)
    end
  elseif opts == "nvim" then
    for k, v in pairs(api.nvim_get_color_map()) do
      if not (COLOR_NAME_SETTINGS.strip_digits and k:match "%d+$") then
        addPair(k, tohex(v, 6))
      end
    end
  elseif opts:match "^tailwind" or opts == true then
    local tailwind = require "colorizer.tailwind_colors"
    -- setup tailwind colors
    for k, v in pairs(tailwind.colors) do
      for _, pre in ipairs(tailwind.prefixes) do
        addPair(pre .. "-" .. k, v)
      end
    end
  elseif opts then
    vim.notify_once("Warning: registering no colors for colorizer.names = " .. opts, vim.log.levels.WARN)
  end
  CUSTOM_ENABLED = opts
end

--- Grab all the colour values from `vim.api.nvim_get_color_map` and create a lookup table.
-- COLOR_MAP is used to store the colour values
---@param line string: Line to parse
---@param i number: Index of line from where to start parsing
---@param opts string|table<string,string>: nvim or tailwind colors, or a custom color set
function parser.name_parser(line, i, opts)
  --- Setup the COLOR_MAP and COLOR_TRIE
  if not COLOR_TRIE or opts ~= CUSTOM_ENABLED then
    parser.init(opts)
  end

  if #line < i + COLOR_NAME_MINLEN - 1 then
    return
  end

  if i > 1 and byte_is_valid_colorchar(line:byte(i - 1)) then
    return
  end

  local prefix = COLOR_TRIE:longest_prefix(line, i)
  if prefix then
    -- Check if there is a letter here so as to disallow matching here.
    -- Take the Blue out of Blueberry
    -- Line end or non-letter.
    local next_byte_index = i + #prefix
    if #line >= next_byte_index and byte_is_valid_colorchar(line:byte(next_byte_index)) then
      return
    end
    return #prefix, COLOR_MAP[prefix]
  end
end

return parser
