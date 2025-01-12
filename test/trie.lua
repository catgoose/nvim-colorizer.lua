---@diagnostic disable: undefined-field
local Trie = require("colorizer.trie")
local utils = require("colorizer.utils")

local opts = {
  lowercase = true,
  uppercase = true,
  camelcase = true,
  strip_digits = false,
  tailwind = true,
}

---@diagnostic disable-next-line: unused-function, unused-local
local function print_color_trie()
  local tohex = bit.tohex
  local min, max = math.min, math.max
  ---@diagnostic disable-next-line: unused-local
  local color_map = {}
  local color_trie = Trie()
  local color_name_minlen
  local color_name_maxlen
  local total_inserted = 0
  local function add_color(name, val)
    color_name_minlen = color_name_minlen and min(#name, color_name_minlen) or #name
    color_name_maxlen = color_name_maxlen and max(#name, color_name_maxlen) or #name
    ---@diagnostic disable-next-line: unused-local
    color_map[name] = val
    local inserted = color_trie:insert(name)
    if inserted then
      total_inserted = total_inserted + 1
    end
  end
  for name, value in pairs(vim.api.nvim_get_color_map()) do
    if not (opts.strip_digits and name:match("%d+$")) then
      local rgb_hex = tohex(value, 6)
      if opts.lowercase then
        add_color(name:lower(), rgb_hex)
      end
      if opts.camelcase then
        add_color(name, rgb_hex)
      end
      if opts.uppercase then
        add_color(name:upper(), rgb_hex)
      end
    end
  end
  if opts.tailwind == true then
    local tw_delimeter = "-"
    utils.add_additional_color_chars(tw_delimeter)
    local data = require("colorizer.data.tailwind_colors")
    for name, hex in pairs(data.colors) do
      for _, prefix in ipairs(data.prefixes) do
        add_color(string.format("%s%s%s", prefix, tw_delimeter, name), hex)
      end
    end
  end
  vim.print(
    string.format("inserted %d color names into trie using the configuration: ", total_inserted)
  )
  vim.print(string.format("opts: %s", vim.inspect(opts)))

  -- print(color_trie)
end

local list = {
  "cat",
  "car",
  "celtic",
  "carb",
  "carb0",
  "CART0",
  "CaRT0",
  "Cart0",
  "931",
  "191",
  "121",
  "cardio",
  "call",
  "calcium",
  "calciur",
  "carry",
  "dog",
  "catdog",
  " spaces ",
  " catspace",
  " dog",
  "dogspace ",
}
local trie = Trie(list)
local function long_prefix(txt)
  vim.print(string.format("'%s': '%s'", txt, trie:longest_prefix(txt)))
end

vim.print("*** Testing trie with small list ***")
vim.print(vim.inspect(list))
vim.print(trie)
vim.print("checking longest prefix: ")
long_prefix("cat")
long_prefix("catastrophic")
long_prefix(" spaces ")
long_prefix(" spaces  ")
long_prefix(" catspace")
long_prefix("catspace ")
long_prefix("dogspace ")
long_prefix(" dogspace")

vim.print("*** Testing trie with large list")
print_color_trie()
