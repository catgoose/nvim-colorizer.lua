local count = require("colorizer.utils").count

local parser = {}
local CSS_RGBA_FN_MINIMUM_LENGTH = #"rgba(0,0,0)" - 1
local CSS_RGB_FN_MINIMUM_LENGTH = #"rgb(0,0,0)" - 1
---Parse for rgb() rgba() css function and return rgb hex.
-- For more info: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/rgb
---@param line string: Line to parse
---@param i number: Index of line from where to start parsing
---@param opts table: Values passed from matchers like prefix
---@return number|nil: Index of line where the rgb/rgba function ended
---@return string|nil: rgb hex value
function parser.rgb_function_parser(line, i, opts)
  local min_len = CSS_RGBA_FN_MINIMUM_LENGTH
  local min_commas, min_spaces, min_percent = 2, 2, 3
  local pattern = "^"
    .. opts.prefix
    .. "%(%s*([.%d]+)([%%]?)(%s?)%s*(,?)%s*([.%d]+)([%%]?)(%s?)%s*(,?)%s*([.%d]+)([%%]?)%s*(/?,?)%s*([.%d]*)([%%]?)%s*%)()"

  if opts.prefix == "rgb" then
    min_len = CSS_RGB_FN_MINIMUM_LENGTH
  end

  if #line < i + min_len then
    return
  end

  local r, unit1, ssep1, csep1, g, unit2, ssep2, csep2, b, unit3, sep3, a, unit_a, match_end =
    line:sub(i):match(pattern)
  if not match_end then
    return
  end

  if a == "" then
    a = nil
  else
    min_commas = min_commas + 1
  end

  local units = ("%s%s%s"):format(unit1, unit2, unit3)
  if units:match "%%" then
    if not ((count(units, "%%")) == min_percent) then
      return
    end
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
    if unit_a == "%" then
      a = a / 100
    end
    -- although alpha doesn't support larger values than 1, css anyways renders it at 1
    if a > 1 then
      a = 1
    end
  end

  r = tonumber(r)
  if not r then
    return
  end
  g = tonumber(g)
  if not g then
    return
  end
  b = tonumber(b)
  if not b then
    return
  end

  if unit1 == "%" then
    r = r / 100 * 255
    g = g / 100 * 255
    b = b / 100 * 255
  else
    -- although r,g,b doesn't support larger values than 255, css anyways renders it at 255
    if r > 255 then
      r = 255
    end
    if g > 255 then
      g = 255
    end
    if b > 255 then
      b = 255
    end
  end

  local rgb_hex = string.format("%02x%02x%02x", r * a, g * a, b * a)
  return match_end - 1, rgb_hex
end

return parser.rgb_function_parser
