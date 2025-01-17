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

--[[-- Trie implementation in LuaJIT.
This module provides an optimized Trie data structure using LuaJIT's Foreign Function Interface (FFI).
It supports operations like insertion, search, finding the longest prefix, and converting the Trie into a table format.

Dynamic Allocation:
<pre>
The implementation uses dynamic memory allocation for efficient storage and manipulation of nodes:
- Each Trie node dynamically allocates memory for its `children` and `keys` arrays using `ffi.C.malloc` and `ffi.C.realloc`.
- Arrays are initially allocated with a small capacity and are resized as needed to accommodate more child nodes.</pre>

Node Structure:
Each Trie node contains the following fields:
<pre>
- `is_leaf` (boolean): Indicates whether the node represents the end of a string.
- `capacity` (number): The current maximum number of children the node can hold.
  - Starts at a small initial value (e.g., 8) and doubles as needed.
- `size` (number): The current number of children the node has.
  - Always ≤ `capacity`.
- `children` (array): A dynamically allocated array of pointers to child nodes.
- `keys` (array): A dynamically allocated array of ASCII values corresponding to the `children` nodes.</pre>

Dynamic Resizing:
<pre>
- If a node's `size` exceeds its `capacity` during insertion, the `capacity` is doubled.
- The `children` and `keys` arrays are reallocated to match the new capacity using `ffi.C.realloc`.
- Resizing ensures efficient use of memory while avoiding frequent allocations.</pre>

Memory Management:
<pre>
- Memory is manually managed:
  - Allocation: Done using `ffi.C.malloc` for new nodes and `ffi.C.realloc` for resizing arrays.
  - Deallocation: Performed recursively for all child nodes using `ffi.C.free`.
- The implementation includes safeguards to handle allocation failures and ensure proper cleanup.</pre>
]]
-- @module trie
local ffi = require("ffi")

-- Trie Node Structure.
ffi.cdef([[
struct Trie {
  bool is_leaf;
  size_t capacity; // Current capacity of the character array
  size_t size;     // Number of children currently in use
  struct Trie** children; // Dynamically allocated array of children
  uint8_t* keys;   // Array of corresponding ASCII keys
};
void *malloc(size_t size);
void *realloc(void *ptr, size_t size);
void free(void *ptr);
]])

local Trie_t = ffi.typeof("struct Trie")
local Trie_ptr_t = ffi.typeof("$ *", Trie_t)
local Trie_size = ffi.sizeof(Trie_t)

local initial_capacity = 8

local function trie_create(capacity)
  capacity = capacity or initial_capacity
  local node_ptr = ffi.C.malloc(Trie_size)
  if not node_ptr then
    error("Failed to allocate memory for Trie node")
  end
  if not Trie_size then
    error("Failed to get size of Trie node")
  end
  ffi.fill(node_ptr, Trie_size)
  local node = ffi.cast(Trie_ptr_t, node_ptr)
  node.is_leaf = false
  node.capacity = capacity
  node.size = 0
  node.children = ffi.cast("struct Trie**", ffi.C.malloc(capacity * ffi.sizeof("struct Trie*")))
  if not node.children then
    ffi.C.free(node_ptr)
    error("Failed to allocate memory for children")
  end
  ffi.fill(node.children, capacity * ffi.sizeof("struct Trie*"))
  node.keys = ffi.cast("uint8_t*", ffi.C.malloc(capacity * ffi.sizeof("uint8_t")))
  if not node.keys then
    ffi.C.free(node.children)
    ffi.C.free(node_ptr)
    error("Failed to allocate memory for keys")
  end
  ffi.fill(node.keys, capacity * ffi.sizeof("uint8_t"))
  return node
end

local resize_count = 0
local function trie_resize(node)
  local current_capacity = tonumber(node.capacity) -- convert to lua number
  local new_capacity = current_capacity * 2
  local new_children = ffi.C.realloc(node.children, new_capacity * ffi.sizeof("struct Trie*"))
  if not new_children then
    error("Failed to reallocate memory for children")
  end
  node.children = ffi.cast("struct Trie**", new_children)
  local new_keys = ffi.C.realloc(node.keys, new_capacity * ffi.sizeof("uint8_t"))
  if not new_keys then
    error("Failed to reallocate memory for keys")
  end
  node.keys = ffi.cast("uint8_t*", new_keys)
  for i = current_capacity, new_capacity - 1 do
    node.children[i] = nil
    node.keys[i] = 0
  end
  node.capacity = new_capacity
  resize_count = resize_count + 1
end

local function trie_destroy(node)
  if not node then
    return
  end
  if node.children then
    for i = 0, node.size - 1 do
      trie_destroy(node.children[i])
    end
    ffi.C.free(node.children)
  end
  if node.keys then
    ffi.C.free(node.keys)
  end
  ffi.C.free(node)
end

local function trie_insert(node, value, capacity)
  if not node or type(value) ~= "string" then
    print("Invalid node or value for insertion")
    return false
  end
  local current = node
  for i = 1, #value do
    local char_byte = value:byte(i)
    local found = false
    for j = 0, tonumber(current.size) - 1 do
      if current.keys[j] == char_byte then
        current = current.children[j]
        found = true
        break
      end
    end
    if not found then
      if current.size >= current.capacity then
        trie_resize(current)
      end
      current.keys[current.size] = char_byte
      current.children[current.size] = trie_create(capacity or initial_capacity)
      current.size = current.size + 1
      current = current.children[current.size - 1]
    end
  end
  current.is_leaf = true
  return true
end

local function trie_search(node, value)
  if not node or type(value) ~= "string" then
    return false
  end
  local current = node
  for i = 1, #value do
    local char_byte = value:byte(i)
    local found = false
    for j = 0, tonumber(current.size) - 1 do
      if current.keys[j] == char_byte then
        current = current.children[j]
        found = true
        break
      end
    end
    if not found then
      return false
    end
  end
  return current.is_leaf
end

local function trie_longest_prefix(trie, value, start, exact)
  if trie == nil then
    return nil
  end
  start = start or 1
  local node = trie
  local last_i = nil
  for i = start, #value do
    local char_byte = value:byte(i)
    local found = false
    for j = 0, tonumber(node.size) - 1 do
      if node.keys[j] == char_byte then
        node = node.children[j]
        found = true
        if node.is_leaf then
          last_i = i
        end
        break
      end
    end
    if not found then
      break
    end
  end
  if exact then
    return last_i == #value and value or nil
  else
    return last_i and value:sub(start, last_i) or nil
  end
end

local function trie_extend(trie, t)
  assert(type(t) == "table")
  for _, v in ipairs(t) do
    trie_insert(trie, v)
  end
end

local function trie_as_table(node)
  if node == nil then
    return nil
  end
  local children = {}
  for i = 0, tonumber(node.size) - 1 do
    local child_table = trie_as_table(node.children[i])
    if child_table then
      child_table.c = string.char(node.keys[i])
      table.insert(children, child_table)
    end
  end
  return {
    is_leaf = node.is_leaf,
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

local function trie_resize_count()
  return resize_count
end

local Trie_mt = {
  __new = function(_, init, opts)
    opts = opts or {}
    local capacity = opts.initial_capacity or initial_capacity
    local trie = trie_create(capacity)
    resize_count = 0
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
    resize_count = trie_resize_count,
  },
  __tostring = trie_to_string,
  __gc = trie_destroy,
}

return ffi.metatype("struct Trie", Trie_mt)
