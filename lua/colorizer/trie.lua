---Trie implementation in luajit.
-- This module provides a Trie data structure implemented in LuaJIT with efficient memory handling.
-- It supports operations such as inserting, searching, finding the longest prefix, and converting the Trie into a table format.
-- The implementation uses LuaJIT's Foreign Function Interface (FFI) for optimized memory allocation.

-- Copyright © 2019 Ashkan Kiani
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--@module trie

local ffi = require("ffi")

ffi.cdef([[
struct Trie {
	bool is_leaf;
	struct Trie* character[62];
};
void *malloc(size_t size);
void free(void *ptr);
]])

local Trie_t = ffi.typeof("struct Trie")
local Trie_ptr_t = ffi.typeof("$ *", Trie_t)
local Trie_size = ffi.sizeof(Trie_t)

local function trie_create()
  local ptr = ffi.C.malloc(Trie_size)
  ffi.fill(ptr, Trie_size)
  return ffi.cast(Trie_ptr_t, ptr)
end

local function trie_destroy(trie)
  if trie == nil then
    return
  end
  for i = 0, 61 do
    local child = trie.character[i]
    if child ~= nil then
      trie_destroy(child)
    end
  end
  ffi.C.free(trie)
end

local total_char = 255
local index_lookup = ffi.new("uint8_t[?]", total_char)
local char_lookup = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
do
  local b = string.byte
  local extra_char = {
    [b("-")] = true,
    [b("_")] = true,
  }
  local byte = {
    ["0"] = b("0"),
    ["9"] = b("9"),
    ["a"] = b("a"),
    ["A"] = b("A"),
    ["z"] = b("z"),
    ["Z"] = b("Z"),
  }
  for i = 0, total_char do
    if i >= byte["0"] and i <= byte["9"] then
      index_lookup[i] = i - byte["0"]
    elseif i >= byte["A"] and i <= byte["Z"] then
      index_lookup[i] = i - byte["A"] + 10
    elseif i >= byte["a"] and i <= byte["z"] then
      index_lookup[i] = i - byte["a"] + 10 + 26
    elseif extra_char[i] then
    else
      index_lookup[i] = total_char
    end
  end
end

local function trie_insert(trie, value)
  if trie == nil then
    return false
  end
  local node = trie
  for i = 1, #value do
    local index = index_lookup[value:byte(i)]
    if index == total_char then
      return false
    end
    if node.character[index] == nil then
      node.character[index] = trie_create()
    end
    node = node.character[index]
  end
  node.is_leaf = true
  return node, trie
end

local function trie_search(trie, value, start)
  if trie == nil then
    return false
  end
  local node = trie
  for i = (start or 1), #value do
    local index = index_lookup[value:byte(i)]
    if index == total_char then
      return
    end
    local child = node.character[index]
    if child == nil then
      return false
    end
    node = child
  end
  return node.is_leaf
end

local function trie_longest_prefix(trie, value, start, exact)
  if trie == nil then
    return false
  end
  start = start or 1
  local node = trie
  local last_i = nil
  for i = start, #value do
    local index = index_lookup[value:byte(i)]
    if index == total_char then
      break
    end
    local child = node.character[index]
    if child == nil then
      break
    end
    if child.is_leaf then
      last_i = i
    end
    node = child
  end
  if last_i then
    -- Avoid a copy if the whole string is a match.
    if start == 1 and last_i == #value then
      return value
    end

    if not exact then
      return value:sub(start, last_i)
    end
  end
end

local function trie_extend(trie, t)
  assert(type(t) == "table")
  for _, v in ipairs(t) do
    trie_insert(trie, v)
  end
end

--- Printing utilities

local function index_to_char(index)
  if index < 0 or index > 61 then
    return
  end
  return char_lookup:sub(index + 1, index + 1)
end

local function trie_as_table(trie)
  if trie == nil then
    return
  end
  local children = {}
  for i = 0, 61 do
    local child = trie.character[i]
    if child ~= nil then
      local child_table = trie_as_table(child)
      child_table.c = index_to_char(i)
      table.insert(children, child_table)
    end
  end
  return {
    is_leaf = trie.is_leaf,
    children = children,
  }
end

local function print_trie_table(s)
  local mark
  if not s then
    return { "nil" }
  end
  if s.c then
    if s.is_leaf then
      mark = s.c .. "*"
    else
      mark = s.c .. "─"
    end
  else
    mark = "├─"
  end
  if #s.children == 0 then
    return { mark }
  end
  local lines = {}
  for _, child in ipairs(s.children) do
    local child_lines = print_trie_table(child)
    for _, child_line in ipairs(child_lines) do
      table.insert(lines, child_line)
    end
  end
  local child_count = 0
  for i, line in ipairs(lines) do
    local line_parts = {}
    if line:match("^%w") then
      child_count = child_count + 1
      if i == 1 then
        line_parts = { mark }
      elseif i == #lines or child_count == #s.children then
        line_parts = { "└─" }
      else
        line_parts = { "├─" }
      end
    else
      if i == 1 then
        line_parts = { mark }
      elseif #s.children > 1 and child_count ~= #s.children then
        line_parts = { "│ " }
      else
        line_parts = { "  " }
      end
    end
    table.insert(line_parts, line)
    lines[i] = table.concat(line_parts)
  end
  return lines
end

local function trie_to_string(trie)
  if trie == nil then
    return "nil"
  end
  local as_table = trie_as_table(trie)
  return table.concat(print_trie_table(as_table), "\n")
end

local Trie_mt = {
  __new = function(_, init)
    local trie = trie_create()
    if type(init) == "table" then
      trie_extend(trie, init)
    end
    return trie
  end,
  __index = {
    insert = trie_insert,
    search = trie_search,
    longest_prefix = trie_longest_prefix,
    extend = trie_extend,
    destroy = trie_destroy,
  },
  __tostring = trie_to_string,
  __gc = trie_destroy,
}

return ffi.metatype("struct Trie", Trie_mt)
