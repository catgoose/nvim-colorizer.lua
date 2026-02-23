local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local utils = require("colorizer.utils")

local T = new_set()

-- byte_is_hex -----------------------------------------------------------------

T["byte_is_hex"] = new_set()

T["byte_is_hex"]["digits 0-9 are hex"] = function()
  for i = 0, 9 do
    eq(true, utils.byte_is_hex(string.byte(tostring(i))))
  end
end

T["byte_is_hex"]["lowercase a-f are hex"] = function()
  for _, c in ipairs({ "a", "b", "c", "d", "e", "f" }) do
    eq(true, utils.byte_is_hex(string.byte(c)))
  end
end

T["byte_is_hex"]["uppercase A-F are hex"] = function()
  for _, c in ipairs({ "A", "B", "C", "D", "E", "F" }) do
    eq(true, utils.byte_is_hex(string.byte(c)))
  end
end

T["byte_is_hex"]["g is not hex"] = function()
  eq(false, utils.byte_is_hex(string.byte("g")))
end

T["byte_is_hex"]["space is not hex"] = function()
  eq(false, utils.byte_is_hex(string.byte(" ")))
end

-- byte_is_alphanumeric --------------------------------------------------------

T["byte_is_alphanumeric"] = new_set()

T["byte_is_alphanumeric"]["digits are alphanumeric"] = function()
  eq(true, utils.byte_is_alphanumeric(string.byte("0")))
  eq(true, utils.byte_is_alphanumeric(string.byte("9")))
end

T["byte_is_alphanumeric"]["letters are alphanumeric"] = function()
  eq(true, utils.byte_is_alphanumeric(string.byte("a")))
  eq(true, utils.byte_is_alphanumeric(string.byte("Z")))
end

T["byte_is_alphanumeric"]["space is not alphanumeric"] = function()
  eq(false, utils.byte_is_alphanumeric(string.byte(" ")))
end

T["byte_is_alphanumeric"]["special chars are not alphanumeric"] = function()
  eq(false, utils.byte_is_alphanumeric(string.byte("#")))
  eq(false, utils.byte_is_alphanumeric(string.byte("(")))
end

-- parse_hex -------------------------------------------------------------------

T["parse_hex"] = new_set()

T["parse_hex"]["digit characters"] = function()
  eq(0, utils.parse_hex(string.byte("0")))
  eq(9, utils.parse_hex(string.byte("9")))
end

T["parse_hex"]["lowercase hex letters"] = function()
  eq(10, utils.parse_hex(string.byte("a")))
  eq(15, utils.parse_hex(string.byte("f")))
end

T["parse_hex"]["uppercase hex letters"] = function()
  eq(10, utils.parse_hex(string.byte("A")))
  eq(15, utils.parse_hex(string.byte("F")))
end

-- rgb_to_hex ------------------------------------------------------------------

T["rgb_to_hex"] = new_set()

T["rgb_to_hex"]["black"] = function()
  eq("000000", utils.rgb_to_hex(0, 0, 0))
end

T["rgb_to_hex"]["white"] = function()
  eq("ffffff", utils.rgb_to_hex(255, 255, 255))
end

T["rgb_to_hex"]["red"] = function()
  eq("ff0000", utils.rgb_to_hex(255, 0, 0))
end

T["rgb_to_hex"]["arbitrary color"] = function()
  eq("1b29fb", utils.rgb_to_hex(27, 41, 251))
end

-- count -----------------------------------------------------------------------

T["count"] = new_set()

T["count"]["counts pattern matches"] = function()
  eq(3, utils.count("a,b,c,d", ","))
  eq(0, utils.count("abcd", ","))
  eq(2, utils.count("hello world hello", "hello"))
end

-- bufme -----------------------------------------------------------------------

T["bufme"] = new_set()

T["bufme"]["nil returns current buffer"] = function()
  local cur = vim.api.nvim_get_current_buf()
  eq(cur, utils.bufme(nil))
end

T["bufme"]["0 returns current buffer"] = function()
  local cur = vim.api.nvim_get_current_buf()
  eq(cur, utils.bufme(0))
end

T["bufme"]["valid bufnr returns itself"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  eq(buf, utils.bufme(buf))
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- hash_table ------------------------------------------------------------------

T["hash_table"] = new_set()

T["hash_table"]["returns consistent hash"] = function()
  local tbl = { a = 1, b = "two" }
  local h1 = utils.hash_table(tbl)
  local h2 = utils.hash_table(tbl)
  eq(h1, h2)
  eq(64, #h1) -- SHA256 is 64 hex chars
end

T["hash_table"]["different tables produce different hashes"] = function()
  local h1 = utils.hash_table({ a = 1 })
  local h2 = utils.hash_table({ a = 2 })
  eq(true, h1 ~= h2)
end

return T
