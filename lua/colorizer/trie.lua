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

---@mod colorizer.trie Trie
---@brief [[
---Trie implementation in LuaJIT.
---This module provides an optimized Trie data structure using LuaJIT's Foreign Function Interface (FFI).
---It supports operations like insertion, search, finding the longest prefix, and converting the Trie into a table format.
---
---Dynamic Allocation:
---The implementation uses dynamic memory allocation for efficient storage and manipulation of nodes:
---- Each Trie node dynamically allocates memory for its `children` and `keys` arrays using `ffi.C.malloc` and `ffi.C.realloc`.
---- Arrays are initially allocated with a small capacity and are resized as needed to accommodate more child nodes.
---
---Node Structure:
---Each Trie node contains the following fields:
---- `is_leaf` (boolean): Indicates whether the node represents the end of a string.
---- `capacity` (number): The current maximum number of children the node can hold.
---- `size` (number): The current number of children the node has.
---- `children` (array): A dynamically allocated array of pointers to child nodes.
---- `keys` (array): A dynamically allocated array of ASCII values corresponding to the `children` nodes.
---
---Dynamic Resizing:
---- If a node's `size` exceeds its `capacity` during insertion, the `capacity` is doubled.
---- The `children` and `keys` arrays are reallocated to match the new capacity using `ffi.C.realloc`.
---- Resizing ensures efficient use of memory while avoiding frequent allocations.
---
---Memory Management:
---- Allocation: Done using `ffi.C.malloc` for new nodes and `ffi.C.realloc` for resizing arrays.
---- Deallocation: Performed recursively for all child nodes using `ffi.C.free`.
---- The implementation includes safeguards to handle allocation failures and ensure proper cleanup.
---@brief ]]
local ffi = require("ffi")

-- Trie Node Structure.
ffi.cdef([[
struct Trie {
  bool is_leaf;
  size_t capacity;      // Current capacity of the character array
  size_t size;          // Number of children currently in use
  size_t _resize_count; // Number of resizes performed (tracked on root node)
  struct Trie** children; // Dynamically allocated array of children
  uint8_t* keys;        // Array of corresponding ASCII keys
};
void *malloc(size_t size);
void *realloc(void *ptr, size_t size);
void free(void *ptr);
]])

local Trie_t = ffi.typeof("struct Trie")
local Trie_ptr_t = ffi.typeof("$ *", Trie_t)
local Trie_size = ffi.sizeof(Trie_t)
local Trie_ptr_size = ffi.sizeof("struct Trie*")

local DEFAULT_INITIAL_CAPACITY = 2
local DEFAULT_GROWTH_FACTOR = 2

--- Per-instance configuration stored Lua-side to avoid adding float to FFI struct.
-- Keyed by root cdata identity.  Weak keys so orphaned tries can be GC'd.
local trie_opts = setmetatable({}, { __mode = "k" })

local function trie_create(capacity)
  capacity = capacity or DEFAULT_INITIAL_CAPACITY
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
  node._resize_count = 0
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

local function trie_resize(node, root)
  local current_capacity = tonumber(node.capacity) -- convert to lua number
  local opts = root and trie_opts[root]
  local growth_factor = opts and opts.growth_factor or DEFAULT_GROWTH_FACTOR
  local new_capacity = math.max(current_capacity + 1, math.floor(current_capacity * growth_factor))
  -- Perform both reallocs before committing either pointer to avoid
  -- leaking the old keys buffer if the second realloc fails
  local new_children = ffi.C.realloc(node.children, new_capacity * ffi.sizeof("struct Trie*"))
  local new_keys = ffi.C.realloc(node.keys, new_capacity * ffi.sizeof("uint8_t"))
  if not new_children or not new_keys then
    -- After a successful realloc the old pointer is invalid, so we must
    -- update node.children/keys even on the rollback path.
    if new_children then
      local rolled = ffi.C.realloc(new_children, current_capacity * ffi.sizeof("struct Trie*"))
      -- Use the rolled-back pointer if possible, otherwise keep the enlarged one
      node.children = ffi.cast("struct Trie**", rolled ~= nil and rolled or new_children)
    end
    if new_keys then
      local rolled = ffi.C.realloc(new_keys, current_capacity * ffi.sizeof("uint8_t"))
      node.keys = ffi.cast("uint8_t*", rolled ~= nil and rolled or new_keys)
    end
    error("Failed to reallocate memory during trie resize")
  end
  node.children = ffi.cast("struct Trie**", new_children)
  node.keys = ffi.cast("uint8_t*", new_keys)
  local added = new_capacity - current_capacity
  ffi.fill(node.children + current_capacity, added * ffi.sizeof("struct Trie*"))
  ffi.fill(node.keys + current_capacity, added * ffi.sizeof("uint8_t"))
  node.capacity = new_capacity
  if root then
    root._resize_count = root._resize_count + 1
  end
end

--- Recursively free a node and all its descendants (including the node itself).
-- Used for child nodes that were allocated with malloc.
local function trie_free_recursive(node)
  if not node then
    return
  end
  if node.children ~= nil then
    for i = 0, tonumber(node.size) - 1 do
      trie_free_recursive(node.children[i])
    end
    ffi.C.free(node.children)
    node.children = nil
  end
  if node.keys ~= nil then
    ffi.C.free(node.keys)
    node.keys = nil
  end
  node.size = 0
  ffi.C.free(node)
end

--- Public destroy: free children and keys but not the root node itself.
-- The root is freed by the ffi.gc finalizer when the cdata is collected.
local function trie_destroy(node)
  if not node then
    return
  end
  trie_opts[node] = nil
  if node.children == nil then
    return
  end
  for i = 0, tonumber(node.size) - 1 do
    trie_free_recursive(node.children[i])
  end
  ffi.C.free(node.children)
  node.children = nil
  if node.keys ~= nil then
    ffi.C.free(node.keys)
    node.keys = nil
  end
  node.size = 0
end

--- GC finalizer (registered via ffi.gc): if destroy() was already called,
-- just free the root.  Otherwise do full recursive cleanup.
local function trie_gc(node)
  if node == nil then
    return
  end
  trie_opts[node] = nil
  if node.children == nil and node.keys == nil then
    ffi.C.free(node)
    return
  end
  -- destroy() was never called, do full cleanup
  trie_destroy(node)
  ffi.C.free(node)
end

local function trie_insert(node, value, capacity)
  if not node or type(value) ~= "string" then
    return false
  end
  local opts = trie_opts[node]
  local child_capacity = capacity or (opts and opts.initial_capacity) or DEFAULT_INITIAL_CAPACITY
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
        trie_resize(current, node)
      end
      current.keys[current.size] = char_byte
      current.children[current.size] = trie_create(child_capacity)
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

local function trie_resize_count(node)
  return tonumber(node._resize_count)
end

--- Recursively compute memory usage in bytes and node count.
local function trie_memory_stats(node)
  if not node then
    return 0, 0
  end
  local cap = tonumber(node.capacity)
  -- This node: struct + children array + keys array
  local bytes = Trie_size + cap * Trie_ptr_size + cap
  local nodes = 1
  for i = 0, tonumber(node.size) - 1 do
    local child_bytes, child_nodes = trie_memory_stats(node.children[i])
    bytes = bytes + child_bytes
    nodes = nodes + child_nodes
  end
  return bytes, nodes
end

--- Return total memory usage in bytes and number of nodes.
---@return number bytes, number nodes
local function trie_memory_usage(node)
  return trie_memory_stats(node)
end

local Trie_mt = {
  __new = function(_, init, opts)
    opts = opts or {}
    local capacity = opts.initial_capacity or DEFAULT_INITIAL_CAPACITY
    local trie = trie_create(capacity)
    -- Register GC finalizer via ffi.gc (metatype __gc does not fire in LuaJIT)
    trie = ffi.gc(trie, trie_gc)
    trie_opts[trie] = {
      initial_capacity = capacity,
      growth_factor = opts.growth_factor or DEFAULT_GROWTH_FACTOR,
    }
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
    memory_usage = trie_memory_usage,
  },
  __tostring = trie_to_string,
}

return ffi.metatype("struct Trie", Trie_mt)
