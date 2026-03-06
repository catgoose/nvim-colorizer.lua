---@mod colorizer.color Color Utilities
---@brief [[
---Provides color conversion and utility functions for RGB and HSL values.
---@brief ]]
local M = {}

--- Converts an HSL color value to RGB.
-- Accepts hue, saturation, and lightness values, each within the range [0, 1],
-- and converts them to an RGB color representation with values scaled to [0, 255].
---@param h number Hue, in the range [0, 1].
---@param s number Saturation, in the range [0, 1].
---@param l number Lightness, in the range [0, 1].
---@return number|nil,number|nil,number|nil Returns red, green, and blue values
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
---@param p number A helper variable representing part of the lightness scale.
---@param q number Another helper variable based on saturation and lightness.
---@param t number Adjusted hue component to be converted to RGB.
---@return number The RGB component value, in the range [0, 1].
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
---@param r number Red component, in the range [0, 255].
---@param g number Green component, in the range [0, 255].
---@param b number Blue component, in the range [0, 255].
---@return boolean `true` if the color is bright, `false` if it's dark.
function M.is_bright(r, g, b)
  -- counting the perceptive luminance - human eye favors green color
  local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  if luminance > 0.5 then
    return true -- bright colors, black font
  else
    return false -- dark colors, white font
  end
end

--- Apply alpha transparency to RGB color channels.
-- Multiplies each channel by the alpha value and floors the result.
---@param r number Red component, in the range [0, 255].
---@param g number Green component, in the range [0, 255].
---@param b number Blue component, in the range [0, 255].
---@param alpha number Alpha value, in the range [0, 1].
---@return number, number, number Alpha-blended red, green, and blue values.
function M.apply_alpha(r, g, b, alpha)
  local floor = math.floor
  return floor(r * alpha), floor(g * alpha), floor(b * alpha)
end

--- Converts an OKLCH color value to RGB.
-- OKLCH is a perceptual color space that provides better uniformity than HSL.
-- Accepts lightness, chroma, and hue values and converts them to RGB.
--
-- References:
--   - OKLCH/OKLab specification: https://bottosson.github.io/posts/oklab/
--   - W3C CSS Color Module Level 4: https://www.w3.org/TR/css-color-4/#ok-lab
--   - Conversion algorithms: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/oklch
--
---@param L number Lightness, in the range [0, 1].
---@param C number Chroma, typically in the range [0, 0.4] but can be higher.
---@param H number Hue, in degrees [0, 360].
---@return number|nil,number|nil,number|nil Returns red, green, and blue values
--         scaled to [0, 255], or nil if any input value is out of range.
function M.oklch_to_rgb(L, C, H)
  if L > 1 or C < 0 then
    return
  end

  local min, max = math.min, math.max

  -- OKLCH to OKLab: convert cylindrical (LCh) to cartesian (Lab) coordinates
  local h_rad = H * (math.pi / 180)
  local a = C * math.cos(h_rad)
  local b_oklab = C * math.sin(h_rad)

  -- OKLab to LMS': apply M2 inverse matrix to get cone response values
  -- LMS represents Long, Medium, Short cone responses in human vision
  local l_ = L + 0.3963377774 * a + 0.2158037573 * b_oklab
  local m_ = L - 0.1055613458 * a - 0.0638541728 * b_oklab
  local s_ = L - 0.0894841775 * a - 1.2914855480 * b_oklab

  -- LMS' to LMS: undo the cube root non-linearity
  local l = l_ * l_ * l_
  local m = m_ * m_ * m_
  local s = s_ * s_ * s_

  -- LMS to Linear RGB: apply M1 inverse matrix
  local r_lin = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
  local g_lin = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
  local b_lin = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

  -- Linear RGB to sRGB: apply gamma correction with standard sRGB transfer function
  local function linear_to_srgb(c)
    if c <= 0.0031308 then
      return 12.92 * c
    else
      return 1.055 * (c ^ (1 / 2.4)) - 0.055
    end
  end

  local r = linear_to_srgb(r_lin)
  local g = linear_to_srgb(g_lin)
  local b = linear_to_srgb(b_lin)

  -- Clamp to 0-1 range and convert to 0-255
  r = max(0, min(1, r)) * 255
  g = max(0, min(1, g)) * 255
  b = max(0, min(1, b)) * 255

  return r, g, b
end

--- Converts an HWB color value to RGB.
-- HWB (Hue, Whiteness, Blackness) is a CSS Color Level 4 color model.
-- When whiteness + blackness >= 1, the result is a shade of gray.
--
-- References:
--   - W3C CSS Color Module Level 4: https://www.w3.org/TR/css-color-4/#the-hwb-notation
--
---@param h number Hue, in degrees [0, 360].
---@param w number Whiteness, in the range [0, 1].
---@param b number Blackness, in the range [0, 1].
---@return number|nil,number|nil,number|nil Returns red, green, and blue values
--         scaled to [0, 255], or nil if any input value is out of range.
function M.hwb_to_rgb(h, w, b)
  if w < 0 or b < 0 then
    return
  end

  -- When whiteness + blackness >= 1, normalize and return gray
  local sum = w + b
  if sum >= 1 then
    local gray = math.floor((w / sum) * 255)
    return gray, gray, gray
  end

  -- Get the base RGB from the hue (equivalent to hsl with S=100%, L=50%)
  local r, g, bl = M.hsl_to_rgb(h / 360, 1, 0.5)
  if not r or not g or not bl then
    return
  end

  -- Apply whiteness and blackness
  local scale = 1 - w - b
  r = r / 255 * scale + w
  g = g / 255 * scale + w
  bl = bl / 255 * scale + w

  return r * 255, g * 255, bl * 255
end

--- Converts a CIE Lab color value to RGB.
-- CIE Lab is a perceptually uniform color space.
--
-- References:
--   - W3C CSS Color Module Level 4: https://www.w3.org/TR/css-color-4/#lab-colors
--   - Conversion: Lab -> D50 XYZ -> D65 XYZ -> linear sRGB -> sRGB
--
---@param L number Lightness, in the range [0, 100].
---@param a number Green-red axis, typically [-125, 125].
---@param b_lab number Blue-yellow axis, typically [-125, 125].
---@return number|nil,number|nil,number|nil Returns red, green, and blue values
--         scaled to [0, 255], or nil if conversion fails.
function M.lab_to_rgb(L, a, b_lab)
  local min, max = math.min, math.max

  -- Lab to D50 XYZ
  local fy = (L + 16) / 116
  local fx = a / 500 + fy
  local fz = fy - b_lab / 200

  local delta = 6 / 29
  local delta_sq = delta * delta
  local delta_cb = delta_sq * delta

  local x = (fx > delta) and (fx * fx * fx) or (3 * delta_sq * (fx - 4 / 29))
  local y = (fy > delta) and (fy * fy * fy) or (3 * delta_sq * (fy - 4 / 29))
  local z = (fz > delta) and (fz * fz * fz) or (3 * delta_sq * (fz - 4 / 29))

  -- Scale by D50 white point
  x = x * 0.3457 / 0.3585
  -- y = y * 1.0 (D50 Yn = 1.0)
  z = z * (1.0 - 0.3457 - 0.3585) / 0.3585

  -- D50 XYZ to D65 XYZ (Bradford chromatic adaptation)
  local xd65 = 0.9555766 * x + -0.0230393 * y + 0.0631636 * z
  local yd65 = -0.0282895 * x + 1.0099416 * y + 0.0210077 * z
  local zd65 = 0.0122982 * x + -0.0204830 * y + 1.3299098 * z

  -- D65 XYZ to linear sRGB
  local r_lin = 3.2404541621 * xd65 - 1.5371385940 * yd65 - 0.4985314096 * zd65
  local g_lin = -0.9692660305 * xd65 + 1.8760108454 * yd65 + 0.0415560175 * zd65
  local b_lin = 0.0556434310 * xd65 - 0.2040259135 * yd65 + 1.0572251882 * zd65

  -- Linear sRGB to sRGB gamma
  local function linear_to_srgb(c)
    if c <= 0.0031308 then
      return 12.92 * c
    else
      return 1.055 * (c ^ (1 / 2.4)) - 0.055
    end
  end

  local r = max(0, min(1, linear_to_srgb(r_lin))) * 255
  local g = max(0, min(1, linear_to_srgb(g_lin))) * 255
  local b = max(0, min(1, linear_to_srgb(b_lin))) * 255

  return r, g, b
end

--- Converts a CIE LCH color value to RGB.
-- CIE LCH is the cylindrical form of CIE Lab.
--
-- References:
--   - W3C CSS Color Module Level 4: https://www.w3.org/TR/css-color-4/#lab-colors
--
---@param L number Lightness, in the range [0, 100].
---@param C number Chroma, typically [0, 150].
---@param H number Hue, in degrees [0, 360].
---@return number|nil,number|nil,number|nil Returns red, green, and blue values
--         scaled to [0, 255], or nil if conversion fails.
function M.lch_to_rgb(L, C, H)
  -- Convert cylindrical LCH to cartesian Lab
  local h_rad = H * (math.pi / 180)
  local a = C * math.cos(h_rad)
  local b = C * math.sin(h_rad)
  return M.lab_to_rgb(L, a, b)
end

return M
