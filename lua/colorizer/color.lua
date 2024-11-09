--@module colorizer.color
local M = {}

--- Converts an HSL color value to RGB.
---@param h number: Hue
---@param s number: Saturation
---@param l number: Lightness
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

---Convert hsl color values to rgb.
-- Source: https://gist.github.com/mjackson/5311256
---@param p number
---@param q number
---@param t number
---@return number
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

---Determine whether to use black or white text.
--
-- ref: https://stackoverflow.com/a/1855903/837964
-- https://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color
---@param r number: Red
---@param g number: Green
---@param b number: Blue
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
