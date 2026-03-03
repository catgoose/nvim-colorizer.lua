-- Generate nvim-colorizer.lua screenshots using Charmbracelet VHS
--
-- Usage:
--   nvim --headless -l scripts/screenshots/generate.lua                  # Generate all screenshots
--   nvim --headless -l scripts/screenshots/generate.lua hex_rgb          # Generate a single screenshot
--   nvim --headless -l scripts/screenshots/generate.lua --hex            # Generate hex group only
--   nvim --headless -l scripts/screenshots/generate.lua --list           # List available configs
--   nvim --headless -l scripts/screenshots/generate.lua -j4              # Run 4 screenshots in parallel
--   nvim --headless -l scripts/screenshots/generate.lua --install-deps   # Install VHS, ttyd, and Nerd Font (for CI)
--
-- Requirements:
--   - VHS: https://github.com/charmbracelet/vhs
--   - Neovim

local uv = vim.uv

-- ── Paths ────────────────────────────────────────────────────────

local script_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local root_dir = vim.fn.fnamemodify(script_dir .. "/../..", ":p"):gsub("/$", "")
local output_dir = script_dir .. "/output"
local init_lua = script_dir .. "/init.lua"

-- ── Load configs ─────────────────────────────────────────────────

local configs_mod = dofile(script_dir .. "/configs.lua")

-- ── Settings ─────────────────────────────────────────────────────

local settings = {
  width = 1200,
  height = 600,
  font_size = 14,
  font_family = "JetBrainsMono Nerd Font",
  padding = 20,
  theme = "Catppuccin Mocha",
}

-- ── Helpers ──────────────────────────────────────────────────────

local function printf(fmt, ...)
  io.write(string.format(fmt, ...) .. "\n")
  io.flush()
end

local function file_exists(path)
  return uv.fs_stat(path) ~= nil
end

local function file_size_human(path)
  local stat = uv.fs_stat(path)
  if not stat then
    return "?"
  end
  local bytes = stat.size
  if bytes >= 1048576 then
    return string.format("%.1fM", bytes / 1048576)
  elseif bytes >= 1024 then
    return string.format("%.0fK", bytes / 1024)
  else
    return string.format("%dB", bytes)
  end
end

-- ── Tmpfile helper ───────────────────────────────────────────────

local function write_tmpfile(content)
  local path = os.tmpname() .. ".tape"
  local f = io.open(path, "w")
  f:write(content)
  f:close()
  return path
end

-- ── VHS helpers ──────────────────────────────────────────────────

--- Shared VHS preamble (shell, font, dimensions, theme).
---@return string
local function vhs_preamble()
  return string.format(
    [[Require nvim

Set Shell "bash"
Set FontSize %d
Set FontFamily "%s"
Set Width %d
Set Height %d
Set Padding %d
Set Theme "%s"]],
    settings.font_size,
    settings.font_family,
    settings.width,
    settings.height,
    settings.padding,
    settings.theme
  )
end

-- ── VHS tape generation ──────────────────────────────────────────

local function generate_tape(config_name)
  local cfg = configs_mod.configs[config_name]
  if not cfg then
    printf("Error: unknown config '%s'", config_name)
    return nil
  end

  local nvim_cmd = string.format("COLORIZER_CONFIG=%s nvim -u %s -i NONE %s", config_name, init_lua, cfg.fixture)

  -- Optional vsplit block for fixtures that exceed ~30 visible lines
  local split_block = ""
  if cfg.split then
    split_block = [[

Type ":vsplit"
Enter
Sleep 500ms
Type ":wincmd l"
Enter
Sleep 200ms
Type "/Should NOT"
Enter
Sleep 200ms
Type "zt"
Sleep 200ms
Type ":nohlsearch"
Enter
Sleep 500ms]]
  end

  local tape = string.format(
    [[%s

Type "%s"
Enter
Sleep 3s%s

Screenshot "%s/%s.png"

Type ":qa!"
Enter
Sleep 500ms]],
    vhs_preamble(),
    nvim_cmd,
    split_block,
    output_dir,
    config_name
  )

  return write_tmpfile(tape)
end

-- ── VHS execution ────────────────────────────────────────────────

--- Run VHS synchronously on a single tape file.
---@return boolean success
local function run_vhs(tape_file)
  vim.fn.system({ "vhs", tape_file })
  return vim.v.shell_error == 0
end

--- Run multiple VHS jobs in parallel using libuv.
---@param jobs table[] list of { config = string, tape = string }
---@param max_concurrent number
---@return table<number, boolean> results indexed by job position
local function run_parallel(jobs, max_concurrent)
  local idx, active = 0, 0
  local results = {}
  local done_count = 0
  local total = #jobs

  local function next_job()
    while active < max_concurrent and idx < total do
      idx = idx + 1
      active = active + 1
      local i = idx
      printf("  Generating: %s", jobs[i].config)
      local handle, pid
      handle, pid = uv.spawn("vhs", {
        args = { jobs[i].tape },
        stdio = { nil, nil, nil },
      }, function(code, _signal)
        handle:close()
        results[i] = code == 0
        active = active - 1
        done_count = done_count + 1

        -- Report result
        local name = jobs[i].config
        if code == 0 and file_exists(output_dir .. "/" .. name .. ".png") then
          printf("    OK: %s.png (%s)", name, file_size_human(output_dir .. "/" .. name .. ".png"))
        else
          printf("    FAILED: %s", name)
        end

        -- Clean up tape
        os.remove(jobs[i].tape)

        next_job()
      end)

      if not handle then
        printf("    FAILED to spawn VHS for %s: %s", jobs[i].config, tostring(pid))
        results[i] = false
        active = active - 1
        done_count = done_count + 1
        os.remove(jobs[i].tape)
      end
    end
  end

  next_job()
  -- Run the event loop until all jobs complete
  while done_count < total do
    uv.run("once")
  end

  return results
end

-- ── CI dependency installer ──────────────────────────────────────

local function install_deps()
  printf("Installing CI dependencies...")

  if os.execute("command -v vhs >/dev/null 2>&1") ~= 0 then
    printf("  Installing VHS and ttyd...")
    os.execute("sudo mkdir -p /etc/apt/keyrings")
    os.execute("curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg")
    os.execute(
      'echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list'
    )
    os.execute("sudo apt-get update")
    os.execute("sudo apt-get install -y vhs ttyd")
  end

  if os.execute('fc-list | grep -qi "JetBrainsMono Nerd Font"') ~= 0 then
    printf("  Installing JetBrainsMono Nerd Font...")
    os.execute("mkdir -p ~/.local/share/fonts")
    os.execute(
      "curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz | tar -xJf - -C ~/.local/share/fonts"
    )
    os.execute("fc-cache -fv")
  end

  printf("  Dependencies installed.")
end

-- ── Dependency checks ────────────────────────────────────────────

local function check_deps()
  if vim.fn.executable("vhs") ~= 1 then
    printf("Error: VHS is not installed.")
    printf("")
    printf("Install VHS:")
    printf("  go install github.com/charmbracelet/vhs@latest")
    printf("  brew install vhs")
    printf("  nix-env -iA nixpkgs.vhs")
    printf("")
    printf("See: https://github.com/charmbracelet/vhs")
    os.exit(1)
  end

  if vim.fn.executable("nvim") ~= 1 then
    printf("Error: Neovim is not installed.")
    os.exit(1)
  end
end

-- ── List configs ─────────────────────────────────────────────────

local function list_configs()
  printf("Available screenshot configs:")
  printf("")

  for _, cat in ipairs(configs_mod.categories) do
    printf("%s:", cat.display)
    for _, name in ipairs(cat.names) do
      local cfg = configs_mod.configs[name]
      local fixture = cfg and vim.fn.fnamemodify(cfg.fixture, ":t") or "?"
      printf("  %-12s  (%s)", name, fixture)
    end
    printf("")
  end
end

-- ── Build ordered config name lists ──────────────────────────────

local function all_config_names()
  local names = {}
  for _, cat in ipairs(configs_mod.categories) do
    for _, n in ipairs(cat.names) do
      table.insert(names, n)
    end
  end
  return names
end

-- ── Main ─────────────────────────────────────────────────────────

local function main()
  local configs_to_run = {}
  local parallel_jobs = 1

  -- Parse arguments
  local args = vim.v.argv
  local script_args = {}
  local found_script = false
  for _, a in ipairs(args) do
    if found_script then
      table.insert(script_args, a)
    elseif a:match("generate%.lua$") then
      found_script = true
    end
  end

  -- Build flag→category lookup from configs_mod.categories
  local category_flags = {}
  for _, cat in ipairs(configs_mod.categories) do
    category_flags["--" .. cat.flag] = cat
  end

  local i = 1
  while i <= #script_args do
    local a = script_args[i]
    if a == "--help" or a == "-h" then
      printf("Usage: nvim --headless -l scripts/screenshots/generate.lua [options] [config...]")
      printf("")
      printf("Options:")
      printf("  --list           List available configs")
      printf("  --install-deps   Install VHS, ttyd, and Nerd Font (for CI)")
      printf("  -j<N>            Run N screenshots in parallel")
      for _, cat in ipairs(configs_mod.categories) do
        printf("  --%-13s  Generate %s group only", cat.flag, cat.display)
      end
      printf("  --help           Show this help")
      os.exit(0)
    elseif a == "--list" then
      list_configs()
      os.exit(0)
    elseif a == "--install-deps" then
      install_deps()
      os.exit(0)
    elseif category_flags[a] then
      local cat = category_flags[a]
      for _, n in ipairs(cat.names) do
        table.insert(configs_to_run, n)
      end
    elseif a:match("^%-j%d+$") then
      parallel_jobs = tonumber(a:sub(3))
    else
      -- Single config name
      table.insert(configs_to_run, a)
    end
    i = i + 1
  end

  -- Default: all configs
  if #configs_to_run == 0 then
    configs_to_run = all_config_names()
  end

  check_deps()
  vim.fn.mkdir(output_dir, "p")

  printf("Generating %d screenshot(s) (jobs: %d)...", #configs_to_run, parallel_jobs)
  printf("Output: %s/", output_dir)
  printf("")

  local succeeded, failed = 0, 0

  if parallel_jobs > 1 then
    -- Build all tape files, then run in parallel
    local jobs = {}
    for j, config_name in ipairs(configs_to_run) do
      printf("  [%d] %s", j, config_name)
      local tape_file = generate_tape(config_name)
      if tape_file then
        table.insert(jobs, { config = config_name, tape = tape_file })
      else
        failed = failed + 1
      end
    end

    local results = run_parallel(jobs, parallel_jobs)

    for j = 1, #jobs do
      if results[j] then
        succeeded = succeeded + 1
      else
        failed = failed + 1
      end
    end
  else
    -- Sequential execution
    for j, config_name in ipairs(configs_to_run) do
      printf("  [%d] Generating: %s", j, config_name)
      local tape_file = generate_tape(config_name)
      if not tape_file then
        printf("    FAILED: unknown config")
        failed = failed + 1
      else
        local ok = run_vhs(tape_file)
        os.remove(tape_file)

        local png_path = output_dir .. "/" .. config_name .. ".png"
        if ok and file_exists(png_path) then
          printf("    OK: %s.png (%s)", config_name, file_size_human(png_path))
          succeeded = succeeded + 1
        else
          printf("    FAILED: %s.png not created", config_name)
          failed = failed + 1
        end
      end
    end
  end

  printf("")
  printf("Done: %d succeeded, %d failed", succeeded, failed)
  printf("Screenshots: %s/", output_dir)

  os.exit(failed > 0 and 1 or 0)
end

main()
