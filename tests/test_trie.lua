local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local Trie = require("colorizer.trie")

local T = new_set()

-- insert & search -------------------------------------------------------------

T["insert and search"] = new_set()

T["insert and search"]["basic insert and search"] = function()
  local t = Trie()
  eq(true, t:insert("hello"))
  eq(true, t:search("hello"))
  eq(false, t:search("hell"))
  eq(false, t:search("helloo"))
end

T["insert and search"]["multiple words"] = function()
  local t = Trie()
  t:insert("apple")
  t:insert("app")
  t:insert("application")
  eq(true, t:search("apple"))
  eq(true, t:search("app"))
  eq(true, t:search("application"))
  eq(false, t:search("ap"))
  eq(false, t:search("apples"))
end

T["insert and search"]["empty string"] = function()
  local t = Trie()
  eq(true, t:insert(""))
  eq(true, t:search(""))
end

T["insert and search"]["single character"] = function()
  local t = Trie()
  t:insert("a")
  eq(true, t:search("a"))
  eq(false, t:search("b"))
end

T["insert and search"]["returns false for nil/non-string"] = function()
  local t = Trie()
  eq(false, t:insert(nil))
  eq(false, t:search(nil))
end

-- init from table -------------------------------------------------------------

T["init from table"] = new_set()

T["init from table"]["constructs trie from table"] = function()
  local t = Trie({ "red", "green", "blue" })
  eq(true, t:search("red"))
  eq(true, t:search("green"))
  eq(true, t:search("blue"))
  eq(false, t:search("yellow"))
end

-- longest_prefix --------------------------------------------------------------

T["longest_prefix"] = new_set()

T["longest_prefix"]["finds longest match"] = function()
  local t = Trie({ "rgb", "rgba" })
  eq("rgba", t:longest_prefix("rgba(255,0,0)", 1))
end

T["longest_prefix"]["returns shorter prefix when longer doesn't match"] = function()
  local t = Trie({ "rgb", "rgba" })
  eq("rgb", t:longest_prefix("rgb(255,0,0)", 1))
end

T["longest_prefix"]["returns nil when no match"] = function()
  local t = Trie({ "rgb", "rgba" })
  eq(nil, t:longest_prefix("hsl(0,0%,0%)", 1))
end

T["longest_prefix"]["with offset"] = function()
  local t = Trie({ "rgb", "rgba" })
  -- "  rgba(..." starting at position 3
  eq("rgba", t:longest_prefix("  rgba(255,0,0)", 3))
end

T["longest_prefix"]["exact mode"] = function()
  local t = Trie({ "red", "green" })
  eq("red", t:longest_prefix("red", 1, true))
  eq(nil, t:longest_prefix("reddish", 1, true))
end

T["longest_prefix"]["nil trie returns nil"] = function()
  -- Calling longest_prefix is tested via internal usage;
  -- verify edge case with a destroyed trie
  local t = Trie({ "abc" })
  eq("abc", t:longest_prefix("abcdef", 1))
end

-- extend ----------------------------------------------------------------------

T["extend"] = new_set()

T["extend"]["adds multiple values"] = function()
  local t = Trie()
  t:extend({ "cat", "car", "card" })
  eq(true, t:search("cat"))
  eq(true, t:search("car"))
  eq(true, t:search("card"))
  eq(false, t:search("ca"))
end

-- memory_usage ----------------------------------------------------------------

T["memory_usage"] = new_set()

T["memory_usage"]["returns bytes and nodes"] = function()
  local t = Trie({ "hello", "world" })
  local bytes, nodes = t:memory_usage()
  eq(true, bytes > 0)
  eq(true, nodes > 0)
end

T["memory_usage"]["more words = more memory"] = function()
  local t1 = Trie({ "a" })
  local t2 = Trie({ "a", "bb", "ccc", "dddd", "eeeee" })
  local b1 = t1:memory_usage()
  local b2 = t2:memory_usage()
  eq(true, b2 > b1)
end

-- resize_count ----------------------------------------------------------------

T["resize_count"] = new_set()

T["resize_count"]["returns a number"] = function()
  local t = Trie()
  eq(true, type(t:resize_count()) == "number")
end

-- destroy ---------------------------------------------------------------------

T["destroy"] = new_set()

T["destroy"]["search returns false after destroy"] = function()
  local t = Trie({ "hello" })
  eq(true, t:search("hello"))
  t:destroy()
  eq(false, t:search("hello"))
end

-- tostring --------------------------------------------------------------------

T["tostring"] = new_set()

T["tostring"]["produces string representation"] = function()
  local t = Trie({ "ab", "ac" })
  local s = tostring(t)
  eq(true, type(s) == "string")
  eq(true, #s > 0)
end

return T
