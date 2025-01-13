-- Run this file as `nvim --clean -u test.lua`

local opts = {
  use_remote = true,
}
require("minimal").setup(opts)

local Trie = require("colorizer.trie")

local file = io.open("trie-test.txt", "w")
if not file then
  error("Failed to open file for appending")
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
file:write("*** Testing trie with small list ***\n")
file:write(string.format("list: \n%s\n", vim.inspect(list)))
file:write(string.format("trie: \n%s\n", trie))
file:write("checking longest prefix:\n")

local function long_prefix(txt)
  ---@diagnostic disable-next-line: undefined-field
  file:write(string.format("'%s': '%s'\n", txt, trie:longest_prefix(txt) or nil))
end
long_prefix("ffffff")
long_prefix("")
long_prefix("cat")
long_prefix("catastrophic")
long_prefix(" spaces ")
long_prefix(" spaces  ")
long_prefix(" catspace")
long_prefix("catspace ")
long_prefix("dogspace ")
long_prefix(" dogspace")

file:write("\n")

file:close()
