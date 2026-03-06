#!/bin/bash
# ── Should highlight ─────────────────────────

# Foreground 256-color (0-15)
echo -e "\e[38;5;0m black"    # #x0
echo -e "\e[38;5;9m red"      # #x9
echo -e "\e[38;5;15m white"   # #x15

# Color cube + grayscale
FG_GREEN="\e[38;5;42m"        # #x42
FG_RED="\e[38;5;196m"         # #x196
GRAY="\e[38;5;240m"           # #x240

# Background 256-color
BG_BLACK="\e[48;5;0m"         # black bg
BG_RED="\e[48;5;196m"         # red bg
BG_WHITE="\e[48;5;15m"        # white bg

# 16-color foreground (30-37)
echo -e "\e[31;1m bright red"
echo -e "\e[32;0m dark green"

# 16-color background (40-47)
echo -e "\e[41;1m bright red bg"
echo -e "\e[42;0m dark green bg"
echo -e "\e[1;47m bright white bg"

# True-color 24-bit foreground
echo -e "\e[38;2;255;0;0m red"
echo -e "\e[38;2;0;255;0m green"
echo -e "\e[38;2;0;0;255m blue"
echo -e "\e[38;2;255;128;0m orange"

# True-color 24-bit background
echo -e "\e[48;2;255;0;0m red bg"
echo -e "\e[48;2;100;200;50m green bg"

# ── Should NOT highlight ────────────────────

BAD1="#x256"
BAD2="#x42abc"
BAD3="\e[38;2;256;0;0m"
