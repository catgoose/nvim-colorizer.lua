---@diagnostic disable: undefined-field
local Trie = require("colorizer.trie")

local opts = {
  lowercase = true,
  uppercase = true,
  camelcase = true,
  strip_digits = false,
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
    color_trie:insert(name)
    total_inserted = total_inserted + 1
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
  print(string.format("inserted %d color names into trie", total_inserted))
  print(color_trie)
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
}
local trie = Trie(list)

print("*** Testing trie with small list ***")
print(vim.inspect(list))
print(trie)
print("checking longest prefix: ")
print("catdo: ", trie:longest_prefix("catdo"))
print("catastrophic: ", trie:longest_prefix("catastrophic"))

print()
print("*** Testing trie with vim.api.nvim_get_color_map()***")
print_color_trie()
