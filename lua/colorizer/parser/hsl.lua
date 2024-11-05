local count = require("colorizer.utils").count
local floor = math.floor

local hsl_to_rgb = require("colorizer.color").hsl_to_rgb

local parser = {}

local CSS_HSLA_FN_MINIMUM_LENGTH = #"hsla(0,0%,0%)" - 1
local CSS_HSL_FN_MINIMUM_LENGTH = #"hsl(0,0%,0%)" - 1
---Parse for hsl() hsla() css function and return rgb hex.
-- For more info: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/hsl
---@param line string: Line to parse
---@param i number: Index of line from where to start parsing
---@param opts table: Values passed from matchers like prefix
---@return number|nil: Index of line where the hsla/hsl function ended
---@return string|nil: rgb hex value
function parser.hsl_function_parser(line, i, opts)
  local min_len = CSS_HSLA_FN_MINIMUM_LENGTH
  local min_commas, min_spaces = 2, 2
  local pattern = "^"
    .. opts.prefix
    .. "%(%s*([.%d]+)([deg]*)([turn]*)(%s?)%s*(,?)%s*(%d+)%%(%s?)%s*(,?)%s*(%d+)%%%s*(/?,?)%s*([.%d]*)([%%]?)%s*%)()"

  if opts.prefix == "hsl" then
    min_len = CSS_HSL_FN_MINIMUM_LENGTH
  end

  if #line < i + min_len then
    return
  end

  local h, deg, turn, ssep1, csep1, s, ssep2, csep2, l, sep3, a, percent_sign, match_end = line:sub(i):match(pattern)
  if not match_end then
    return
  end
  if a == "" then
    a = nil
  else
    min_commas = min_commas + 1
  end

  -- the text after hue should be either deg or empty
  if not ((deg == "") or (deg == "deg") or (turn == "turn")) then
    return
  end

  local c_seps = ("%s%s%s"):format(csep1, csep2, sep3)
  local s_seps = ("%s%s"):format(ssep1, ssep2)
  -- comma separator syntax
  if c_seps:match "," then
    if not (count(c_seps, ",") == min_commas) then
      return
    end
    -- space separator syntax with decimal or percentage alpha
  elseif count(s_seps, "%s") >= min_spaces then
    if a then
      if not (c_seps == "/") then
        return
      end
    end
  else
    return
  end

  if not a then
    a = 1
  else
    a = tonumber(a)
    -- if percentage, then convert to decimal
    if percent_sign == "%" then
      a = a / 100
    end
    -- although alpha doesn't support larger values than 1, css anyways renders it at 1
    if a > 1 then
      a = 1
    end
  end

  h = tonumber(h) or 1
  -- single turn is 360
  if turn == "turn" then
    h = 360 * h
  end

  -- if hue angle if greater than 360, then calculate the hue within 360
  if h > 360 then
    local turns = h / 360
    h = 360 * (turns - floor(turns))
  end

  -- if saturation or luminance percentage is  greater than 100 then reset it to 100
  s = tonumber(s)
  if s > 100 then
    s = 100
  end
  l = tonumber(l)
  if l > 100 then
    l = 100
  end

  local r, g, b = hsl_to_rgb(h / 360, s / 100, l / 100)
  if not r or not g or not b then
    return
  end
  local rgb_hex = string.format("%02x%02x%02x", r * a, g * a, b * a)
  return match_end - 1, rgb_hex
end

return parser.hsl_function_parser
