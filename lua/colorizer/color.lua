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

--- Converts linear sRGB to gamma-corrected sRGB.
-- Shared by multiple color space converters.
---@param c number Linear sRGB channel value
---@return number Gamma-corrected sRGB value in [0, 1]
function M.linear_to_srgb(c)
  if c <= 0.0031308 then
    return 12.92 * c
  else
    return 1.055 * (c ^ (1 / 2.4)) - 0.055
  end
end

--- Converts sRGB gamma to linear sRGB.
---@param c number Gamma-corrected sRGB channel value in [0, 1]
---@return number Linear sRGB value
function M.srgb_to_linear(c)
  if c <= 0.04045 then
    return c / 12.92
  else
    return ((c + 0.055) / 1.055) ^ 2.4
  end
end

--- Converts a CSS color() function value to sRGB.
-- Supports: srgb, srgb-linear, display-p3, a98-rgb, prophoto-rgb, rec2020.
--
-- References:
--   - W3C CSS Color Module Level 4: https://www.w3.org/TR/css-color-4/#color-function
--   - Color space matrices: https://www.w3.org/TR/css-color-4/#color-conversion
--
---@param space string Color space name (e.g. "srgb", "display-p3")
---@param r number Red/first channel, in [0, 1]
---@param g number Green/second channel, in [0, 1]
---@param b number Blue/third channel, in [0, 1]
---@return number|nil,number|nil,number|nil Returns red, green, blue in [0, 255], or nil
function M.css_color_to_rgb(space, r, g, b)
  local min, max = math.min, math.max

  if space == "srgb" then
    -- Already in sRGB gamut, just scale to 0-255
    r = max(0, min(1, r)) * 255
    g = max(0, min(1, g)) * 255
    b = max(0, min(1, b)) * 255
    return r, g, b
  end

  if space == "srgb-linear" then
    -- Linear sRGB, apply gamma correction
    r = max(0, min(1, M.linear_to_srgb(r))) * 255
    g = max(0, min(1, M.linear_to_srgb(g))) * 255
    b = max(0, min(1, M.linear_to_srgb(b))) * 255
    return r, g, b
  end

  if space == "display-p3" then
    -- Display P3: linearize P3 gamma -> XYZ D65 -> linear sRGB -> sRGB gamma
    -- P3 uses the same transfer function as sRGB
    local rl = M.srgb_to_linear(max(0, min(1, r)))
    local gl = M.srgb_to_linear(max(0, min(1, g)))
    local bl = M.srgb_to_linear(max(0, min(1, b)))

    -- P3 to XYZ (D65)
    local x = 0.4865709486 * rl + 0.2656676932 * gl + 0.1982172852 * bl
    local y = 0.2289745641 * rl + 0.6917385218 * gl + 0.0792869141 * bl
    local z = 0.0000000000 * rl + 0.0451133819 * gl + 1.0439443689 * bl

    -- XYZ to linear sRGB
    local sr = 3.2404541621 * x - 1.5371385940 * y - 0.4985314096 * z
    local sg = -0.9692660305 * x + 1.8760108454 * y + 0.0415560175 * z
    local sb = 0.0556434310 * x - 0.2040259135 * y + 1.0572251882 * z

    r = max(0, min(1, M.linear_to_srgb(sr))) * 255
    g = max(0, min(1, M.linear_to_srgb(sg))) * 255
    b = max(0, min(1, M.linear_to_srgb(sb))) * 255
    return r, g, b
  end

  if space == "a98-rgb" then
    -- Adobe RGB 1998: linearize -> XYZ D65 -> linear sRGB -> sRGB gamma
    -- A98 uses gamma = 563/256 ≈ 2.19921875
    local gamma = 563 / 256
    local rl = max(0, min(1, r)) ^ gamma
    local gl = max(0, min(1, g)) ^ gamma
    local bl = max(0, min(1, b)) ^ gamma

    -- A98-RGB to XYZ (D65)
    local x = 0.5766690429 * rl + 0.1855582379 * gl + 0.1882286462 * bl
    local y = 0.2973449753 * rl + 0.6273635663 * gl + 0.0752914585 * bl
    local z = 0.0270313614 * rl + 0.0706888525 * gl + 0.9913375368 * bl

    -- XYZ to linear sRGB
    local sr = 3.2404541621 * x - 1.5371385940 * y - 0.4985314096 * z
    local sg = -0.9692660305 * x + 1.8760108454 * y + 0.0415560175 * z
    local sb = 0.0556434310 * x - 0.2040259135 * y + 1.0572251882 * z

    r = max(0, min(1, M.linear_to_srgb(sr))) * 255
    g = max(0, min(1, M.linear_to_srgb(sg))) * 255
    b = max(0, min(1, M.linear_to_srgb(sb))) * 255
    return r, g, b
  end

  if space == "prophoto-rgb" then
    -- ProPhoto RGB: linearize -> XYZ D50 -> XYZ D65 -> linear sRGB -> sRGB gamma
    -- ProPhoto uses gamma = 1.8
    local function prophoto_to_linear(c)
      local abs_c = math.abs(c)
      if abs_c <= 16 / 512 then
        return c / 16
      else
        local sign = c < 0 and -1 or 1
        return sign * (abs_c ^ 1.8)
      end
    end

    local rl = prophoto_to_linear(max(0, min(1, r)))
    local gl = prophoto_to_linear(max(0, min(1, g)))
    local bl = prophoto_to_linear(max(0, min(1, b)))

    -- ProPhoto to XYZ (D50)
    local x50 = 0.7977604896 * rl + 0.1351917082 * gl + 0.0313493495 * bl
    local y50 = 0.2880711282 * rl + 0.7118432178 * gl + 0.0000856540 * bl
    local z50 = 0.0000000000 * rl + 0.0000000000 * gl + 0.8251046026 * bl

    -- D50 to D65 (Bradford)
    local x = 0.9555766 * x50 + -0.0230393 * y50 + 0.0631636 * z50
    local y = -0.0282895 * x50 + 1.0099416 * y50 + 0.0210077 * z50
    local z = 0.0122982 * x50 + -0.0204830 * y50 + 1.3299098 * z50

    -- XYZ to linear sRGB
    local sr = 3.2404541621 * x - 1.5371385940 * y - 0.4985314096 * z
    local sg = -0.9692660305 * x + 1.8760108454 * y + 0.0415560175 * z
    local sb = 0.0556434310 * x - 0.2040259135 * y + 1.0572251882 * z

    r = max(0, min(1, M.linear_to_srgb(sr))) * 255
    g = max(0, min(1, M.linear_to_srgb(sg))) * 255
    b = max(0, min(1, M.linear_to_srgb(sb))) * 255
    return r, g, b
  end

  if space == "rec2020" then
    -- Rec. 2020: linearize -> XYZ D65 -> linear sRGB -> sRGB gamma
    local alpha_r = 1.09929682680944
    local beta_r = 0.018053968510807
    local function rec2020_to_linear(c)
      local abs_c = math.abs(c)
      if abs_c < beta_r * 4.5 then
        return c / 4.5
      else
        local sign = c < 0 and -1 or 1
        return sign * (((abs_c + alpha_r - 1) / alpha_r) ^ (1 / 0.45))
      end
    end

    local rl = rec2020_to_linear(max(0, min(1, r)))
    local gl = rec2020_to_linear(max(0, min(1, g)))
    local bl = rec2020_to_linear(max(0, min(1, b)))

    -- Rec2020 to XYZ (D65)
    local x = 0.6369580483 * rl + 0.1446169036 * gl + 0.1688809752 * bl
    local y = 0.2627002120 * rl + 0.6779980715 * gl + 0.0593017165 * bl
    local z = 0.0000000000 * rl + 0.0280726930 * gl + 1.0609850577 * bl

    -- XYZ to linear sRGB
    local sr = 3.2404541621 * x - 1.5371385940 * y - 0.4985314096 * z
    local sg = -0.9692660305 * x + 1.8760108454 * y + 0.0415560175 * z
    local sb = 0.0556434310 * x - 0.2040259135 * y + 1.0572251882 * z

    r = max(0, min(1, M.linear_to_srgb(sr))) * 255
    g = max(0, min(1, M.linear_to_srgb(sg))) * 255
    b = max(0, min(1, M.linear_to_srgb(sb))) * 255
    return r, g, b
  end

  -- Unknown color space
  return nil
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
