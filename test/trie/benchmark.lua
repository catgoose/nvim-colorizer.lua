-- Run this file as `nvim --clean -u benchmark.lua`

local opts = {
  use_remote = true,
}
require("minimal").setup(opts)

-- @diagnostic disable: undefined-field
local Trie = require("colorizer.trie")
local bit = require("bit")
local ffi = require("ffi")

--- Generate random strings with specified count and length range.
---@param count number: number of strings to generate
---@param range table: min and max length of strings
---@return table: list of random strings
local function rand_strings(count, range)
  local strings = {}
  local char_pools = {
    { 97, 122 }, -- 'a' to 'z' (lowercase)
    { 65, 90 }, -- 'A' to 'Z' (uppercase)
    { 48, 57 }, -- '0' to '9' (numbers)
    { 33, 47 }, -- Special characters: '!' to '/'
    { 58, 64 }, -- Special characters: ':' to '@'
    { 91, 96 }, -- Special characters: '[' to '`'
    { 123, 126 }, -- Special characters: '{' to '~'
  }

  for _ = 1, count do
    local length = math.random(range[1], range[2])
    local str = {}
    for _ = 1, length do
      local pool = char_pools[math.random(1, #char_pools)]
      table.insert(str, string.char(math.random(pool[1], pool[2])))
    end
    table.insert(strings, table.concat(str))
  end

  return strings
end

ffi.cdef([[
  typedef struct timeval {
    long tv_sec;
    long tv_usec;
  } timeval;
  int gettimeofday(struct timeval* tv, void* tz);
]])

--- Get the current time in milliseconds.
-- @return number time in milliseconds
local function get_time_in_ms()
  local tv = ffi.new("struct timeval")
  ffi.C.gettimeofday(tv, nil)
  ---@diagnostic disable-next-line: undefined-field
  return tv.tv_sec * 1000 + tv.tv_usec / 1000
end

--- Benchmark Trie insertions and lookups.
---@param file file*: file handle for writing results
---@param data table: list of strings to insert and search
---@param description string: description of the dataset
local function benchmark_trie(file, data, description)
  file:write(string.format("*** %s ***\n", description))
  file:write("Initial Capacity\tResize Count\tInsert Time (ms)\tLookup Time (ms)\n")

  local resizing = true
  local shift_bit = 1

  while resizing do
    local initial_capacity = bit.lshift(1, shift_bit - 1)
    local trie = Trie({}, { initial_capacity = initial_capacity })

    -- Measure insertion time
    local insert_start = get_time_in_ms()
    for _, name in ipairs(data) do
      ---@diagnostic disable-next-line: undefined-field
      trie:insert(name, initial_capacity)
    end
    local insert_stop = get_time_in_ms()

    -- Measure lookup time
    local lookup_start = get_time_in_ms()
    for _, name in ipairs(data) do
      ---@diagnostic disable-next-line: undefined-field
      local _ = trie:search(name) -- Perform lookups
    end
    local lookup_stop = get_time_in_ms()

    ---@diagnostic disable-next-line: undefined-field
    local resize_count = trie:resize_count()
    file:write(
      string.format(
        "%d\t%d\t%d\t%d\n",
        initial_capacity,
        resize_count,
        insert_stop - insert_start,
        lookup_stop - lookup_start
      )
    )

    resizing = resize_count > 0
    shift_bit = shift_bit + 1
  end

  file:write("\n")
end

local file = io.open("trie-benchmark.txt", "w")
if not file then
  error("Failed to open file for writing")
end

-- Benchmark with Vim color map and Tailwind data
local words = {}
for word in pairs(vim.api.nvim_get_color_map()) do
  table.insert(words, word:lower())
  table.insert(words, word)
  table.insert(words, word:upper())
end
local tw_delimeter = "-"
local data = require("colorizer.data.tailwind_colors")
for name in pairs(data.colors) do
  for _, prefix in ipairs(data.prefixes) do
    table.insert(words, string.format("%s%s%s", prefix, tw_delimeter, name))
  end
end
benchmark_trie(
  file,
  words,
  string.format(
    "Inserting %d words: uppercase, lowercase, camelcase from vim.api.nvim_get_color_map() and Tailwind colors",
    #words
  )
)

-- Benchmark with random strings
local rs = 1000
local rs_scale = 10
while rs <= 100000 do
  local strings = rand_strings(rs, { 3, 15 })
  benchmark_trie(file, strings, string.format("Inserting %d randomized words", #strings))
  rs = rs * rs_scale
end

file:close()
