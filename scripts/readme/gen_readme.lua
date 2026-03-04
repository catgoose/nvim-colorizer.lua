#!/usr/bin/env lua
-- Generate SCREENSHOT_TESTS.md from template + configs.lua data.
-- Usage:
--   lua scripts/readme/gen_readme.lua           -- write SCREENSHOT_TESTS.md
--   lua scripts/readme/gen_readme.lua --check   -- exit 1 if stale

local IMG_BASE = "https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/"
local ISSUE_BASE = "https://github.com/catgoose/nvim-colorizer.lua/issues/new"

-- ── CLI args ───────────────────────────────────────────────────────

local check_mode = false

for _, a in ipairs(arg) do
  if a == "--check" then
    check_mode = true
  end
end

-- ── Stub vim global ────────────────────────────────────────────────

if not vim then
  -- Minimal stub so dofile on configs.lua doesn't crash.
  -- We only read static data tables, never call runtime functions.
  local noop = function() end
  vim = {
    fn = setmetatable({}, {
      __index = function()
        return function() return "" end
      end,
    }),
    o = setmetatable({}, {
      __index = function() return 0 end,
      __newindex = noop,
    }),
    opt = setmetatable({}, {
      __index = function()
        return { prepend = noop, append = noop }
      end,
    }),
    cmd = setmetatable({}, {
      __index = function() return noop end,
      __call = noop,
    }),
  }
end

-- ── Load configs.lua ───────────────────────────────────────────────

local configs_mod = dofile("scripts/screenshots/configs.lua")

-- ── Lua value serializer ───────────────────────────────────────────

local function serialize_lua(v, indent)
  indent = indent or 0
  local t = type(v)
  if t == "string" then
    return string.format("%q", v)
  elseif t == "number" or t == "boolean" then
    return tostring(v)
  elseif t ~= "table" then
    return tostring(v)
  end
  local pad = string.rep("  ", indent + 1)
  local pad_close = string.rep("  ", indent)
  local keys = {}
  for k in pairs(v) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do
    local ks = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k
      or ("[" .. serialize_lua(k, 0) .. "]")
    parts[#parts + 1] = ks .. " = " .. serialize_lua(v[k], 0)
  end
  local inline = "{ " .. table.concat(parts, ", ") .. " }"
  if #inline <= 60 then
    return inline
  end
  local lines = { "{" }
  for _, k in ipairs(keys) do
    local ks = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k
      or ("[" .. serialize_lua(k, 0) .. "]")
    lines[#lines + 1] = pad .. ks .. " = " .. serialize_lua(v[k], indent + 1) .. ","
  end
  lines[#lines + 1] = pad_close .. "}"
  return table.concat(lines, "\n")
end

-- ── Config serializer ──────────────────────────────────────────────

local function config_to_lua(name)
  local raw = configs_mod.configs[name]
  if not raw then
    return "-- (unknown config)"
  end
  local parsers = raw.setup_opts and raw.setup_opts.options and raw.setup_opts.options.parsers
  if not parsers then
    return "-- (default settings)"
  end
  return "parsers = " .. serialize_lua(parsers, 0)
end

-- ── URL helpers ────────────────────────────────────────────────────

local function url_encode(s)
  return (s:gsub("[^%w%-_.~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

local function issue_url(config_name, index)
  local title = string.format("Screenshot issue: [%d] %s", index, config_name)
  local body = string.format(
    "**Screenshot index:** %d\n**Config key:** `%s`\n\n**Describe the issue:**\n",
    index, config_name
  )
  return string.format("%s?title=%s&body=%s", ISSUE_BASE, url_encode(title), url_encode(body))
end

-- ── HTML helpers ───────────────────────────────────────────────────

local detail_index = 0

local function img_cell_detailed(config_name, width)
  width = width or 400
  detail_index = detail_index + 1
  local raw = configs_mod.configs[config_name]
  local label = (raw and raw.label) or config_name
  local description = (raw and raw.description) or ""
  local config_lua = config_to_lua(config_name)
  local report_url = issue_url(config_name, detail_index)
  return string.format(
    '<td align="center">\n'
      .. '<strong><a href="%s">[%d]</a> %s</strong><br>\n'
      .. "<em>%s</em><br>\n"
      .. '<img src="%s%s.png" width="%d"><br>\n'
      .. "<details><summary>Config</summary>\n"
      .. '<pre><code class="language-lua">\n'
      .. "%s\n"
      .. "</code></pre>\n"
      .. "</details>\n"
      .. "</td>",
    report_url,
    detail_index,
    label,
    description,
    IMG_BASE,
    config_name,
    width,
    config_lua
  )
end

local function gallery_table(cat)
  local names = cat.names
  local cols = #names < 3 and #names or 3
  local width = cat.img_width or 400
  local lines = { "<table>" }
  for i = 1, #names, cols do
    lines[#lines + 1] = "<tr>"
    for j = 0, cols - 1 do
      local name = names[i + j]
      if name then
        lines[#lines + 1] = img_cell_detailed(name, width)
      else
        lines[#lines + 1] = "<td></td>"
      end
    end
    lines[#lines + 1] = "</tr>"
  end
  lines[#lines + 1] = "</table>"
  return table.concat(lines, "\n")
end

-- ── Generator registry ─────────────────────────────────────────────

local generators = {}

for _, cat in ipairs(configs_mod.categories) do
  generators[cat.flag .. "_gallery"] = function()
    return gallery_table(cat)
  end
end

-- ── File I/O ───────────────────────────────────────────────────────

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    error("Cannot open: " .. path)
  end
  local content = f:read("*a")
  f:close()
  return content
end

local function write_file(path, content)
  local f = io.open(path, "w")
  if not f then
    error("Cannot write: " .. path)
  end
  f:write(content)
  f:close()
end

-- ── Marker replacement ─────────────────────────────────────────────

local function replace_markers(template)
  local lines = {}
  local in_marker = nil
  for line in template:gmatch("([^\n]*)\n?") do
    local start_name = line:match("^<!%-%- gen:([%w_]+):start %-%->$")
    local end_name = line:match("^<!%-%- gen:([%w_]+):end %-%->$")
    if start_name then
      in_marker = start_name
      lines[#lines + 1] = line
      local gen = generators[in_marker]
      if not gen then
        error("Unknown generator: " .. in_marker)
      end
      lines[#lines + 1] = gen()
    elseif end_name and in_marker == end_name then
      lines[#lines + 1] = line
      in_marker = nil
    elseif not in_marker then
      lines[#lines + 1] = line
    end
  end
  -- gmatch produces an extra empty string at the end; remove trailing empty line
  -- only if the original didn't end with one
  if not template:match("\n$") and lines[#lines] == "" then
    table.remove(lines)
  end
  return table.concat(lines, "\n")
end

-- ── Main ───────────────────────────────────────────────────────────

local template = read_file("scripts/readme/SCREENSHOT_TESTS.template.md")
local result = replace_markers(template)

if check_mode then
  local ok, current = pcall(read_file, "SCREENSHOT_TESTS.md")
  if ok and current == result then
    print("SCREENSHOT_TESTS.md is up-to-date.")
  else
    io.stderr:write("SCREENSHOT_TESTS.md is out-of-date. Run 'make readme' to regenerate.\n")
    if ok then
      local tmp = os.tmpname()
      write_file(tmp, result)
      os.execute(string.format("diff -u SCREENSHOT_TESTS.md %s || true", tmp))
      os.remove(tmp)
    end
    os.exit(1)
  end
else
  write_file("SCREENSHOT_TESTS.md", result)
  print("Generated SCREENSHOT_TESTS.md")
end
