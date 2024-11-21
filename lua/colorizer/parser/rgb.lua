--- This module provides a parser for identifying and converting `rgb()` and `rgba()` CSS functions to RGB hexadecimal format.
-- It supports decimal and percentage values for RGB channels, as well as an optional alpha (transparency) component.
-- The function can interpret a variety of CSS syntax variations, making it useful for syntax highlighting or color parsing.
-- @module colorizer.parser.rgb

local M = {}

local count = require("colorizer.utils").count

--- Parses `rgb()` and `rgba()` CSS functions and converts them to RGB hexadecimal format.
-- This function matches `rgb()` or `rgba()` functions in a line of text, extracting RGB and optional alpha values.
-- It supports decimal and percentage formats, alpha transparency, and comma or space-separated CSS syntax.
-- @param line string The line of text to parse for the color function
-- @param i number The starting index within the line where parsing should begin
-- @param opts table Parsing options, including:
--   - `prefix` (string): "rgb" or "rgba" to specify the CSS function type
-- @return number|nil The end index of the parsed `rgb/rgba` function within the line, or `nil` if parsing failed
-- @return string|nil The RGB hexadecimal color (e.g., "ff0000" for red), or `nil` if parsing failed
function M.rgb_function_parser(line, i, opts)
  local min_len = #"rgba(0,0,0)" - 1
  local min_commas, min_spaces, min_percent = 2, 2, 3
  local pattern = "^"
    .. opts.prefix
    .. "%(%s*([.%d]+)([%%]?)(%s?)%s*(,?)%s*([.%d]+)([%%]?)(%s?)%s*(,?)%s*([.%d]+)([%%]?)%s*(/?,?)%s*([.%d]*)([%%]?)%s*%)()"

  if opts.prefix == "rgb" then
    min_len = #"rgb(0,0,0)" - 1
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
  if units:match("%%") then
    if not ((count(units, "%%")) == min_percent) then
      return
    end
  end

  local c_seps = ("%s%s%s"):format(csep1, csep2, sep3)
  local s_seps = ("%s%s"):format(ssep1, ssep2)
  -- Comma separator syntax
  if c_seps:match(",") then
    if not (count(c_seps, ",") == min_commas) then
      return
    end
    -- Space separator syntax with decimal or percentage alpha
  elseif count(s_seps, "%s") >= min_spaces then
    if a then
      if not (c_seps == "/") then
        return
      end
    end
  else
    return
  end

  -- Alpha value handling
  if not a then
    a = 1
  else
    a = tonumber(a)
    -- Convert percentage alpha to decimal if applicable
    if unit_a == "%" then
      a = a / 100
    end
    if a > 1 then
      a = 1
    end
  end

  -- Convert RGB values to numeric form
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

  -- clamp values to 0-255
  if unit1 == "%" then
    r = r > 100 and 255 or r / 100 * 255
    g = g > 100 and 255 or g / 100 * 255
    b = b > 100 and 255 or b / 100 * 255
  else
    r = r > 255 and 255 or r
    b = b > 255 and 255 or b
    g = g > 255 and 255 or g
  end

  -- Convert to hex, applying alpha to each channel
  local rgb_hex = string.format("%02x%02x%02x", r * a, g * a, b * a)
  return match_end - 1, rgb_hex
end

return M.rgb_function_parser
