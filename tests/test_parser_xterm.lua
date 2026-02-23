local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local parser = require("colorizer.parser.xterm").parser

local T = new_set()

-- #xNN decimal codes ----------------------------------------------------------

T["#xNN"] = new_set()

T["#xNN"]["#x0 is black"] = function()
  local len, hex = parser("#x0", 1)
  eq(3, len)
  eq("000000", hex)
end

T["#xNN"]["#x1 is maroon"] = function()
  local len, hex = parser("#x1", 1)
  eq(3, len)
  eq("800000", hex)
end

T["#xNN"]["#x9 is red"] = function()
  local len, hex = parser("#x9", 1)
  eq(3, len)
  eq("ff0000", hex)
end

T["#xNN"]["#x15 is white"] = function()
  local len, hex = parser("#x15", 1)
  eq(4, len)
  eq("ffffff", hex)
end

T["#xNN"]["#x255 is last grayscale"] = function()
  local len, hex = parser("#x255", 1)
  eq(5, len)
  eq("eeeeee", hex)
end

T["#xNN"]["#x42 is green variant"] = function()
  local len, hex = parser("#x42", 1)
  eq(4, len)
  eq("00d787", hex)
end

T["#xNN"]["#x232 is dark grayscale"] = function()
  local len, hex = parser("#x232", 1)
  eq(5, len)
  eq("080808", hex)
end

T["#xNN"]["#x000 with leading zeros"] = function()
  local len, hex = parser("#x000", 1)
  eq(5, len)
  eq("000000", hex)
end

-- ANSI escape sequences (literal \e format) -----------------------------------

T["ANSI escape literal"] = new_set()

T["ANSI escape literal"]["\\e[38;5;0m is black"] = function()
  local len, hex = parser("\\e[38;5;0m", 1)
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["ANSI escape literal"]["\\e[38;5;15m is white"] = function()
  local len, hex = parser("\\e[38;5;15m", 1)
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

T["ANSI escape literal"]["\\e[38;5;42m"] = function()
  local len, hex = parser("\\e[38;5;42m", 1)
  eq(true, len ~= nil)
  eq("00d787", hex)
end

-- ANSI 16-color ---------------------------------------------------------------

T["ANSI 16-color"] = new_set()

T["ANSI 16-color"]["\\e[30;0m is black (fg 30, brightness 0)"] = function()
  local len, hex = parser("\\e[30;0m", 1)
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["ANSI 16-color"]["\\e[31;1m is bright red"] = function()
  local len, hex = parser("\\e[31;1m", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["ANSI 16-color"]["\\e[37;1m is bright white"] = function()
  local len, hex = parser("\\e[37;1m", 1)
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

T["ANSI 16-color"]["\\e[1;37m reversed order"] = function()
  local len, hex = parser("\\e[1;37m", 1)
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

-- Edge cases ------------------------------------------------------------------

T["edge cases"] = new_set()

T["edge cases"]["no match returns nil"] = function()
  local len = parser("not a color", 1)
  eq(nil, len)
end

T["edge cases"]["#x256 is out of range"] = function()
  local len = parser("#x256", 1)
  eq(nil, len)
end

T["edge cases"]["#x followed by alpha boundary"] = function()
  -- #x42 followed by alpha chars should not match
  local len = parser("#x42abc", 1)
  eq(nil, len)
end

return T
