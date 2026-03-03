-- ── Should highlight ─────────────────────────

local colors = {
  red = "FF0000",
  green = "00FF00",
  blue = "0000FF",
  yellow = "FFFF00",
  cyan = "00FFFF",
  magenta = "FF00FF",
  white = "FFFFFF",
  custom = "32a14b",
  warm = "abcdef",
}

local alpha = {
  red_half = "FF000080",
  green_solid = "00FF00FF",
  blue_faded = "0000FF40",
}

-- ── Should NOT highlight ────────────────────

local invalid = {
  short = "ABCDE",
  non_hex = "GGGGGG",
  too_short = "F00",
}
