--- Vendored from hsluv-lua (MIT). http://www.hsluv.org/
--- Only hsluv_to_rgb is used; H,S,L in 0-360, 0-100, 0-100; returns RGB 0-1.
local M = {}

local function distance_line_from_origin(line)
  return math.abs(line.intercept) / math.sqrt((line.slope ^ 2) + 1)
end

local function length_of_ray_until_intersect(theta, line)
  return line.intercept / (math.sin(theta) - line.slope * math.cos(theta))
end

function M.get_bounds(l)
  local result = {}
  local sub2
  local sub1 = ((l + 16) ^ 3) / 1560896
  if sub1 > M.epsilon then
    sub2 = sub1
  else
    sub2 = l / M.kappa
  end
  for i = 1, 3 do
    local m1, m2, m3 = M.m[i][1], M.m[i][2], M.m[i][3]
    for t = 0, 1 do
      local top1 = (284517 * m1 - 94839 * m3) * sub2
      local top2 = (838422 * m3 + 769860 * m2 + 731718 * m1) * l * sub2 - 769860 * t * l
      local bottom = (632260 * m3 - 126452 * m2) * sub2 + 126452 * t
      table.insert(result, { slope = top1 / bottom, intercept = top2 / bottom })
    end
  end
  return result
end

function M.max_safe_chroma_for_l(l)
  local bounds = M.get_bounds(l)
  local min_val = 1.7976931348623157e+308
  for i = 1, 6 do
    local length = distance_line_from_origin(bounds[i])
    if length >= 0 then
      min_val = math.min(min_val, length)
    end
  end
  return min_val
end

function M.max_safe_chroma_for_lh(l, h)
  local hrad = h / 360 * math.pi * 2
  local bounds = M.get_bounds(l)
  local min_val = 1.7976931348623157e+308
  for i = 1, 6 do
    local length = length_of_ray_until_intersect(hrad, bounds[i])
    if length >= 0 then
      min_val = math.min(min_val, length)
    end
  end
  return min_val
end

function M.dot_product(a, b)
  return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

function M.from_linear(c)
  if c <= 0.0031308 then
    return 12.92 * c
  end
  return 1.055 * (c ^ 0.416666666666666685) - 0.055
end

function M.to_linear(c)
  if c > 0.04045 then
    return ((c + 0.055) / 1.055) ^ 2.4
  end
  return c / 12.92
end

function M.xyz_to_rgb(tuple)
  return {
    M.from_linear(M.dot_product(M.m[1], tuple)),
    M.from_linear(M.dot_product(M.m[2], tuple)),
    M.from_linear(M.dot_product(M.m[3], tuple)),
  }
end

function M.rgb_to_xyz(tuple)
  local rgbl = { M.to_linear(tuple[1]), M.to_linear(tuple[2]), M.to_linear(tuple[3]) }
  return {
    M.dot_product(M.minv[1], rgbl),
    M.dot_product(M.minv[2], rgbl),
    M.dot_product(M.minv[3], rgbl),
  }
end

function M.y_to_l(Y)
  if Y <= M.epsilon then
    return Y / M.refY * M.kappa
  end
  return 116 * ((Y / M.refY) ^ 0.333333333333333315) - 16
end

function M.l_to_y(L)
  if L <= 8 then
    return M.refY * L / M.kappa
  end
  return M.refY * (((L + 16) / 116) ^ 3)
end

function M.xyz_to_luv(tuple)
  local X, Y, Z = tuple[1], tuple[2], tuple[3]
  local divider = X + 15 * Y + 3 * Z
  local varU = divider ~= 0 and 4 * X / divider or 0
  local varV = divider ~= 0 and 9 * Y / divider or 0
  local L = M.y_to_l(Y)
  if L == 0 then
    return { 0, 0, 0 }
  end
  return { L, 13 * L * (varU - M.refU), 13 * L * (varV - M.refV) }
end

function M.luv_to_xyz(tuple)
  local L, U, V = tuple[1], tuple[2], tuple[3]
  if L == 0 then
    return { 0, 0, 0 }
  end
  local varU = U / (13 * L) + M.refU
  local varV = V / (13 * L) + M.refV
  local Y = M.l_to_y(L)
  local X = 0 - (9 * Y * varU) / ((((varU - 4) * varV) - varU * varV))
  return { X, Y, (9 * Y - 15 * varV * Y - varV * X) / (3 * varV) }
end

function M.luv_to_lch(tuple)
  local L, U, V = tuple[1], tuple[2], tuple[3]
  local C = math.sqrt(U * U + V * V)
  local H = C < 1e-8 and 0 or (math.atan2(V, U) * 180 / math.pi)
  if H < 0 then
    H = 360 + H
  end
  return { L, C, H }
end

function M.lch_to_luv(tuple)
  local L, C, H = tuple[1], tuple[2], tuple[3]
  local Hrad = H / 360 * 2 * math.pi
  return { L, math.cos(Hrad) * C, math.sin(Hrad) * C }
end

function M.hsluv_to_lch(tuple)
  local H, S, L = tuple[1], tuple[2], tuple[3]
  if L > 99.9999999 then
    return { 100, 0, H }
  end
  if L < 0.00000001 then
    return { 0, 0, H }
  end
  return { L, M.max_safe_chroma_for_lh(L, H) / 100 * S, H }
end

function M.lch_to_rgb(tuple)
  return M.xyz_to_rgb(M.luv_to_xyz(M.lch_to_luv(tuple)))
end

function M.hsluv_to_rgb(tuple)
  return M.lch_to_rgb(M.hsluv_to_lch(tuple))
end

M.m = {
  { 3.240969941904521, -1.537383177570093, -0.498610760293 },
  { -0.96924363628087, 1.87596750150772, 0.041555057407175 },
  { 0.055630079696993, -0.20397695888897, 1.056971514242878 },
}
M.minv = {
  { 0.41239079926595, 0.35758433938387, 0.18048078840183 },
  { 0.21263900587151, 0.71516867876775, 0.072192315360733 },
  { 0.019330818715591, 0.11919477979462, 0.95053215224966 },
}
M.refY = 1.0
M.refU = 0.19783000664283
M.refV = 0.46831999493879
M.kappa = 903.2962962
M.epsilon = 0.0088564516

return M
