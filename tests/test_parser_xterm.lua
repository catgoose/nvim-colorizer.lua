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

-- ANSI 256-color background ---------------------------------------------------

T["ANSI 256-bg"] = new_set()

T["ANSI 256-bg"]["\\e[48;5;0m is black (background)"] = function()
  local len, hex = parser("\\e[48;5;0m", 1)
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["ANSI 256-bg"]["\\e[48;5;15m is white (background)"] = function()
  local len, hex = parser("\\e[48;5;15m", 1)
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

T["ANSI 256-bg"]["\\e[48;5;42m (background)"] = function()
  local len, hex = parser("\\e[48;5;42m", 1)
  eq(true, len ~= nil)
  eq("00d787", hex)
end

-- ANSI 16-color background ----------------------------------------------------

T["ANSI 16-bg"] = new_set()

T["ANSI 16-bg"]["\\e[40;0m is black (bg 40)"] = function()
  local len, hex = parser("\\e[40;0m", 1)
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["ANSI 16-bg"]["\\e[41;1m is bright red (bg 41)"] = function()
  local len, hex = parser("\\e[41;1m", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["ANSI 16-bg"]["\\e[47;1m is bright white (bg 47)"] = function()
  local len, hex = parser("\\e[47;1m", 1)
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

T["ANSI 16-bg"]["\\e[1;42m reversed order (bg green)"] = function()
  local len, hex = parser("\\e[1;42m", 1)
  eq(true, len ~= nil)
  eq("00ff00", hex)
end

-- True-color ANSI (24-bit) ----------------------------------------------------

T["truecolor"] = new_set()

T["truecolor"]["\\e[38;2;255;0;0m is red (foreground)"] = function()
  local len, hex = parser("\\e[38;2;255;0;0m", 1)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["truecolor"]["\\e[38;2;0;255;0m is green (foreground)"] = function()
  local len, hex = parser("\\e[38;2;0;255;0m", 1)
  eq(true, len ~= nil)
  eq("00ff00", hex)
end

T["truecolor"]["\\e[38;2;0;0;255m is blue (foreground)"] = function()
  local len, hex = parser("\\e[38;2;0;0;255m", 1)
  eq(true, len ~= nil)
  eq("0000ff", hex)
end

T["truecolor"]["\\e[48;2;255;128;0m is orange (background)"] = function()
  local len, hex = parser("\\e[48;2;255;128;0m", 1)
  eq(true, len ~= nil)
  eq("ff8000", hex)
end

T["truecolor"]["\\e[38;2;0;0;0m is black"] = function()
  local len, hex = parser("\\e[38;2;0;0;0m", 1)
  eq(true, len ~= nil)
  eq("000000", hex)
end

T["truecolor"]["\\e[38;2;255;255;255m is white"] = function()
  local len, hex = parser("\\e[38;2;255;255;255m", 1)
  eq(true, len ~= nil)
  eq("ffffff", hex)
end

T["truecolor"]["out of range R=256 returns nil"] = function()
  local len = parser("\\e[38;2;256;0;0m", 1)
  eq(nil, len)
end

T["truecolor"]["negative value returns nil"] = function()
  -- Pattern won't match negative numbers (no minus sign allowed)
  local len = parser("\\e[38;2;-1;0;0m", 1)
  eq(nil, len)
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
