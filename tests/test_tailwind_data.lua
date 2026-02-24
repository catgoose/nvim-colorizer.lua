local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local tailwind = require("colorizer.data.tailwind_colors")

local T = new_set()

-- Data structure validation ---------------------------------------------------

T["data structure"] = new_set()

T["data structure"]["colors table exists and is non-empty"] = function()
  eq("table", type(tailwind.colors))
  local count = 0
  for _ in pairs(tailwind.colors) do
    count = count + 1
  end
  eq(true, count > 0)
end

T["data structure"]["prefixes table exists and is non-empty"] = function()
  eq("table", type(tailwind.prefixes))
  eq(true, #tailwind.prefixes > 0)
end

-- Color values are valid hex strings ------------------------------------------

T["color values"] = new_set()

T["color values"]["all values are valid 3 or 6 char hex strings"] = function()
  for name, hex in pairs(tailwind.colors) do
    local len = #hex
    eq(true, len == 3 or len == 6, string.format("color %q has length %d, expected 3 or 6", name, len))
    eq(true, hex:match("^[0-9a-f]+$") ~= nil, string.format("color %q value %q contains invalid chars", name, hex))
  end
end

-- Prefixes are non-empty strings ----------------------------------------------

T["prefixes"] = new_set()

T["prefixes"]["all prefixes are non-empty strings"] = function()
  for _, prefix in ipairs(tailwind.prefixes) do
    eq("string", type(prefix))
    eq(true, #prefix > 0)
  end
end

-- Spot checks -----------------------------------------------------------------

T["spot checks"] = new_set()

T["spot checks"]["black is 000"] = function()
  eq("000", tailwind.colors["black"])
end

T["spot checks"]["white is fff"] = function()
  eq("fff", tailwind.colors["white"])
end

T["spot checks"]["red-500 is ef4444"] = function()
  eq("ef4444", tailwind.colors["red-500"])
end

T["spot checks"]["blue-500 is 3b82f6"] = function()
  eq("3b82f6", tailwind.colors["blue-500"])
end

T["spot checks"]["slate-50 is f8fafc"] = function()
  eq("f8fafc", tailwind.colors["slate-50"])
end

-- No duplicate color names ----------------------------------------------------

T["no duplicates"] = new_set()

T["no duplicates"]["no duplicate color names"] = function()
  local seen = {}
  for name, _ in pairs(tailwind.colors) do
    eq(nil, seen[name], string.format("duplicate color name: %q", name))
    seen[name] = true
  end
end

return T
