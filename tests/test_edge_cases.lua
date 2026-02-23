local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local matcher = require("colorizer.matcher")
local config = require("colorizer.config")
local names = require("colorizer.parser.names")
local buffer = require("colorizer.buffer")

local T = new_set({
  hooks = {
    pre_case = function()
      matcher.reset_cache()
      names.reset_cache()
      buffer.reset_cache()
      config.get_setup_options(nil)
    end,
  },
})

local function make_opts(overrides)
  overrides = overrides or { css = true, AARRGGBB = true, xterm = true }
  return config.apply_alias_options(overrides)
end

-- xterm boundary: underscore treated as word character ----------------------------

T["xterm boundary"] = new_set()

T["xterm boundary"]["#x255 followed by underscore does NOT match"] = function()
  local xterm_parser = require("colorizer.parser.xterm").parser
  local len = xterm_parser("#x255_foo", 1)
  eq(nil, len)
end

T["xterm boundary"]["#x255 followed by space DOES match"] = function()
  local xterm_parser = require("colorizer.parser.xterm").parser
  local len, hex = xterm_parser("#x255 foo", 1)
  eq(5, len)
  eq("eeeeee", hex)
end

T["xterm boundary"]["#x255 followed by dot DOES match"] = function()
  local xterm_parser = require("colorizer.parser.xterm").parser
  local len, hex = xterm_parser("#x255.foo", 1)
  eq(5, len)
  eq("eeeeee", hex)
end

T["xterm boundary"]["#x255 followed by hyphen DOES match"] = function()
  local xterm_parser = require("colorizer.parser.xterm").parser
  local len, hex = xterm_parser("#x255-foo", 1)
  eq(5, len)
  eq("eeeeee", hex)
end

T["xterm boundary"]["#x42 at end of line DOES match"] = function()
  local xterm_parser = require("colorizer.parser.xterm").parser
  local len, hex = xterm_parser("#x42", 1)
  eq(4, len)
  eq("00d787", hex)
end

T["xterm boundary"]["#x42 followed by letter does NOT match"] = function()
  local xterm_parser = require("colorizer.parser.xterm").parser
  local len = xterm_parser("#x42abc", 1)
  eq(nil, len)
end

T["xterm boundary"]["#x42 followed by digit does NOT match"] = function()
  local xterm_parser = require("colorizer.parser.xterm").parser
  local len = xterm_parser("#x429", 1)
  eq(nil, len)
end

-- HSL percentage optional --------------------------------------------------------

T["hsl percentage optional"] = new_set()

T["hsl percentage optional"]["hsl with percent on both s and l"] = function()
  local parser = require("colorizer.parser.hsl").parser
  local len, hex = parser("hsl(0, 100%, 50%)", 1, { prefix = "hsl" })
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["hsl percentage optional"]["hsl without percent on s and l"] = function()
  local parser = require("colorizer.parser.hsl").parser
  local len, hex = parser("hsl(0, 100, 50)", 1, { prefix = "hsl" })
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["hsl percentage optional"]["hsl with percent on s only"] = function()
  local parser = require("colorizer.parser.hsl").parser
  local len, hex = parser("hsl(0, 100%, 50)", 1, { prefix = "hsl" })
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["hsl percentage optional"]["hsl with percent on l only"] = function()
  local parser = require("colorizer.parser.hsl").parser
  -- Space-separated with percent on l but not s
  local len, hex = parser("hsl(120 50 50%)", 1, { prefix = "hsl" })
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["hsl percentage optional"]["hsla without percent on s and l"] = function()
  local parser = require("colorizer.parser.hsl").parser
  local len, hex = parser("hsla(240, 100, 50, 1)", 1, { prefix = "hsla" })
  eq(true, len ~= nil)
  eq("0000ff", hex)
end

-- Matcher cache with custom names ------------------------------------------------

T["matcher cache custom names"] = new_set()

T["matcher cache custom names"]["same custom names hit cache"] = function()
  local opts = make_opts({ names_custom = { brand = "#112233" } })
  local fn1 = matcher.make(opts)
  local fn2 = matcher.make(opts)
  eq(true, fn1 == fn2) -- same reference from cache
end

T["matcher cache custom names"]["different custom names get different functions"] = function()
  local opts1 = make_opts({ names_custom = { colorA = "#111111" } })
  local opts2 = make_opts({ names_custom = { colorB = "#222222" } })
  local fn1 = matcher.make(opts1)
  local fn2 = matcher.make(opts2)
  eq(true, fn1 ~= fn2) -- different functions, not sharing cache
end

T["matcher cache custom names"]["custom name A resolves correctly after B is cached"] = function()
  local opts1 = make_opts({ names_custom = { colorA = "#111111" } })
  local opts2 = make_opts({ names_custom = { colorB = "#222222" } })
  local fn1 = matcher.make(opts1)
  local fn2 = matcher.make(opts2)
  -- fn1 should still resolve colorA correctly
  local len1, hex1 = fn1("colorA text", 1)
  eq(true, len1 ~= nil)
  eq("111111", hex1)
  -- fn2 should resolve colorB
  local len2, hex2 = fn2("colorB text", 1)
  eq(true, len2 ~= nil)
  eq("222222", hex2)
  -- fn2 should NOT resolve colorA
  local len3 = fn2("colorA text", 1)
  eq(nil, len3)
end

-- Trie with custom opts ----------------------------------------------------------

T["trie custom opts"] = new_set()

T["trie custom opts"]["custom initial_capacity works"] = function()
  local Trie = require("colorizer.trie")
  local t = Trie(nil, { initial_capacity = 8 })
  t:insert("hello")
  t:insert("world")
  eq(true, t:search("hello"))
  eq(true, t:search("world"))
end

T["trie custom opts"]["custom growth_factor works"] = function()
  local Trie = require("colorizer.trie")
  local t = Trie(nil, { initial_capacity = 2, growth_factor = 4 })
  -- Insert enough to trigger resize
  t:insert("a")
  t:insert("b")
  t:insert("c")
  t:insert("d")
  eq(true, t:search("a"))
  eq(true, t:search("b"))
  eq(true, t:search("c"))
  eq(true, t:search("d"))
  eq(true, t:resize_count() > 0)
end

T["trie custom opts"]["init with table and custom opts"] = function()
  local Trie = require("colorizer.trie")
  local t = Trie({ "rgb", "rgba", "hsl", "hsla", "oklch" }, { initial_capacity = 4 })
  eq(true, t:search("rgb"))
  eq(true, t:search("rgba"))
  eq(true, t:search("hsl"))
  eq(true, t:search("hsla"))
  eq(true, t:search("oklch"))
end

T["trie custom opts"]["destroy cleans up opts"] = function()
  local Trie = require("colorizer.trie")
  local t = Trie({ "test" }, { initial_capacity = 4, growth_factor = 3 })
  eq(true, t:search("test"))
  t:destroy()
  eq(false, t:search("test"))
end

-- Trie stress: many single-char inserts triggering resizes -----------------------

T["trie resize stress"] = new_set()

T["trie resize stress"]["insert all ASCII letters triggers resizes"] = function()
  local Trie = require("colorizer.trie")
  local t = Trie(nil, { initial_capacity = 2 })
  -- Insert 26 single characters as children of root -> many resizes
  for c = string.byte("a"), string.byte("z") do
    t:insert(string.char(c))
  end
  for c = string.byte("a"), string.byte("z") do
    eq(true, t:search(string.char(c)))
  end
  eq(true, t:resize_count() > 0)
end

T["trie resize stress"]["memory grows with insertions"] = function()
  local Trie = require("colorizer.trie")
  local t = Trie(nil, { initial_capacity = 2 })
  local b1 = t:memory_usage()
  for i = 1, 100 do
    t:insert("word" .. i)
  end
  local b2 = t:memory_usage()
  eq(true, b2 > b1)
end

return T
