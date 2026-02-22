-- Run: nvim --clean --headless --cmd 'set rtp+=<repo_root>' -u benchmark-growth.lua -c quit
-- Or: nvim --clean --headless --cmd 'set rtp+=/home/jtye/git/nvim-colorizer.lua' -c 'luafile benchmark-growth.lua' -c quit

-- Bootstrap: try local first, fall back to minimal setup
local ok = pcall(require, "colorizer.trie")
if not ok then
  -- Try adding parent repo to rtp
  local repo_root = vim.fn.fnamemodify("../../", ":p")
  vim.opt.rtp:append(repo_root)
end

local Trie = require("colorizer.trie")
local ffi = require("ffi")

-- High-resolution timer
pcall(function()
  ffi.cdef([[
    typedef struct bench_timeval { long tv_sec; long tv_usec; } bench_timeval;
    int gettimeofday(struct bench_timeval* tv, void* tz);
  ]])
end)

local function get_time_us()
  local tv = ffi.new("struct bench_timeval")
  ffi.C.gettimeofday(tv, nil)
  return tonumber(tv.tv_sec) * 1e6 + tonumber(tv.tv_usec)
end

-- Generate random strings
local function rand_strings(count, range)
  local strings = {}
  local pools = {
    { 97, 122 }, { 65, 90 }, { 48, 57 },
    { 33, 47 }, { 58, 64 }, { 91, 96 }, { 123, 126 },
  }
  for _ = 1, count do
    local length = math.random(range[1], range[2])
    local str = {}
    for _ = 1, length do
      local pool = pools[math.random(1, #pools)]
      table.insert(str, string.char(math.random(pool[1], pool[2])))
    end
    table.insert(strings, table.concat(str))
  end
  return strings
end

-- Build the real-world color names dataset
local function build_color_words()
  local words = {}
  for word in pairs(vim.api.nvim_get_color_map()) do
    table.insert(words, word:lower())
    table.insert(words, word)
    table.insert(words, word:upper())
  end
  local tw_ok, data = pcall(require, "colorizer.data.tailwind_colors")
  if tw_ok then
    for name in pairs(data.colors) do
      for _, prefix in ipairs(data.prefixes) do
        table.insert(words, prefix .. "-" .. name)
      end
    end
  end
  return words
end

-- Run a single benchmark trial
-- Returns: insert_us, lookup_us, prefix_us, resize_count, memory_bytes, node_count
local function bench_trial(words, opts)
  local trie = Trie({}, opts)

  local t0 = get_time_us()
  for _, w in ipairs(words) do
    trie:insert(w)
  end
  local t1 = get_time_us()

  for _, w in ipairs(words) do
    trie:search(w)
  end
  local t2 = get_time_us()

  for _, w in ipairs(words) do
    trie:longest_prefix(w)
  end
  local t3 = get_time_us()

  local rc = trie:resize_count()
  local mem, nodes = trie:memory_usage()

  trie:destroy()

  return t1 - t0, t2 - t1, t3 - t1, rc, mem, nodes
end

-- Run multiple trials and return median
local function bench(words, opts, trials)
  trials = trials or 5
  local results = {}
  for _ = 1, trials do
    local insert_us, lookup_us, prefix_us, rc, mem, nodes = bench_trial(words, opts)
    table.insert(results, {
      insert = insert_us,
      lookup = lookup_us,
      prefix = prefix_us,
      resizes = rc,
      memory = mem,
      nodes = nodes,
    })
  end
  -- Sort by insert time and take median
  table.sort(results, function(a, b)
    return a.insert < b.insert
  end)
  return results[math.ceil(#results / 2)]
end

-- Format bytes to human readable
local function fmt_mem(bytes)
  if bytes < 1024 then
    return string.format("%dB", bytes)
  elseif bytes < 1024 * 1024 then
    return string.format("%.1fKB", bytes / 1024)
  else
    return string.format("%.1fMB", bytes / (1024 * 1024))
  end
end

-- ============================================================
-- Main benchmark
-- ============================================================
local growth_factors = { 1.25, 1.5, 1.618, 2.0, 3.0, 4.0 }
local init_capacities = { 2, 4, 8, 16 }

local datasets = {
  { name = "color_names", words = build_color_words() },
  { name = "random_10k", words = rand_strings(10000, { 3, 15 }) },
}

local file = io.open("benchmark-growth.txt", "w")
if not file then
  error("Failed to open output file")
end

for _, ds in ipairs(datasets) do
  file:write(string.format("=== %s (%d words) ===\n", ds.name, #ds.words))
  file:write(string.format(
    "%-8s  %-8s  %10s  %10s  %10s  %8s  %10s  %8s\n",
    "growth", "init_cap", "insert_ms", "lookup_ms", "prefix_ms", "resizes", "memory", "nodes"
  ))
  file:write(string.rep("-", 88) .. "\n")

  local results_for_ds = {}

  for _, gf in ipairs(growth_factors) do
    for _, ic in ipairs(init_capacities) do
      local r = bench(ds.words, { initial_capacity = ic, growth_factor = gf }, 5)
      local line = string.format(
        "%-8.3f  %-8d  %10.2f  %10.2f  %10.2f  %8d  %10s  %8d",
        gf, ic,
        r.insert / 1000, r.lookup / 1000, r.prefix / 1000,
        r.resizes, fmt_mem(r.memory), r.nodes
      )
      file:write(line .. "\n")
      table.insert(results_for_ds, {
        gf = gf, ic = ic,
        insert = r.insert, lookup = r.lookup, prefix = r.prefix,
        resizes = r.resizes, memory = r.memory, nodes = r.nodes,
      })
    end
  end

  -- Find best by composite score: normalize insert + lookup + prefix + memory
  -- Find min/max for normalization
  local min_t, max_t = math.huge, 0
  local min_m, max_m = math.huge, 0
  for _, r in ipairs(results_for_ds) do
    local total_time = r.insert + r.lookup + r.prefix
    min_t = math.min(min_t, total_time)
    max_t = math.max(max_t, total_time)
    min_m = math.min(min_m, r.memory)
    max_m = math.max(max_m, r.memory)
  end

  file:write("\n--- Normalized scores (lower is better, 70% time + 30% memory) ---\n")
  file:write(string.format("%-8s  %-8s  %10s\n", "growth", "init_cap", "score"))
  file:write(string.rep("-", 30) .. "\n")

  local time_range = max_t - min_t
  local mem_range = max_m - min_m
  for _, r in ipairs(results_for_ds) do
    local total_time = r.insert + r.lookup + r.prefix
    local time_norm = time_range > 0 and (total_time - min_t) / time_range or 0
    local mem_norm = mem_range > 0 and (r.memory - min_m) / mem_range or 0
    r.score = 0.7 * time_norm + 0.3 * mem_norm
  end
  table.sort(results_for_ds, function(a, b)
    return a.score < b.score
  end)
  for i, r in ipairs(results_for_ds) do
    file:write(string.format("%-8.3f  %-8d  %10.4f%s\n", r.gf, r.ic, r.score, i == 1 and "  <-- best" or ""))
  end

  file:write("\n")
end

file:close()

-- Also print to stdout
local f = io.open("benchmark-growth.txt", "r")
if f then
  print(f:read("*a"))
  f:close()
end
