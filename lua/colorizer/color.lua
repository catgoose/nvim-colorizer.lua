--- Provides color conversion and utility functions for RGB and HSL values.
-- @module colorizer.color
local M = {}

--- Converts an HSL color value to RGB.
-- Accepts hue, saturation, and lightness values, each within the range [0, 1],
-- and converts them to an RGB color representation with values scaled to [0, 255].
---@param h number: Hue, in the range [0, 1].
---@param s number: Saturation, in the range [0, 1].
---@param l number: Lightness, in the range [0, 1].
---@return number|nil,number|nil,number|nil: Returns red, green, and blue values
--         scaled to [0, 255], or nil if any input value is out of range.
---@return number|nil,number|nil,number|nil
function M.hsl_to_rgb(h, s, l)
  if h > 1 or s > 1 or l > 1 then
    return
  end
  if s == 0 then
    local r = l * 255
    return r, r, r
  end
  local q
  if l < 0.5 then
    q = l * (1 + s)
  else
    q = l + s - l * s
  end
  local p = 2 * l - q
  return 255 * M.hue_to_rgb(p, q, h + 1 / 3),
    255 * M.hue_to_rgb(p, q, h),
    255 * M.hue_to_rgb(p, q, h - 1 / 3)
end

--- Converts an HSL component to RGB, used within `hsl_to_rgb`.
-- Source: https://gist.github.com/mjackson/5311256
-- This function computes one component of the RGB value by adjusting
-- the color based on intermediate values `p`, `q`, and `t`.
---@param p number: A helper variable representing part of the lightness scale.
---@param q number: Another helper variable based on saturation and lightness.
---@param t number: Adjusted hue component to be converted to RGB.
---@return number: The RGB component value, in the range [0, 1].
function M.hue_to_rgb(p, q, t)
  if t < 0 then
    t = t + 1
  end
  if t > 1 then
    t = t - 1
  end
  if t < 1 / 6 then
    return p + (q - p) * 6 * t
  end
  if t < 1 / 2 then
    return q
  end
  if t < 2 / 3 then
    return p + (q - p) * (2 / 3 - t) * 6
  end
  return p
end

--- Determines whether a color is bright, helping decide text color.
-- ref: https://stackoverflow.com/a/1855903/837964
-- https://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color
-- Calculates the perceived luminance of the RGB color. Returns `true` if
-- the color is bright enough to warrant black text and `false` otherwise.
-- Formula based on the human eye’s sensitivity to different colors.
---@param r number: Red component, in the range [0, 255].
---@param g number: Green component, in the range [0, 255].
---@param b number: Blue component, in the range [0, 255].
---@return boolean: `true` if the color is bright, `false` if it's dark.
function M.is_bright(r, g, b)
  -- counting the perceptive luminance - human eye favors green color
  local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  if luminance > 0.5 then
    return true -- bright colors, black font
  else
    return false -- dark colors, white font
  end
end

return M
