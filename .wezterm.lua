local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- =========================================================
-- OS detection (used to branch only where the OS matters)
-- =========================================================
local triple = wezterm.target_triple
local is_windows = triple:find("windows") ~= nil
local is_mac = triple:find("darwin") ~= nil
local is_linux = triple:find("linux") ~= nil

-- On macOS, make the Option key act as a plain modifier so
-- Alt/Option shortcuts fire instead of typing special glyphs.
if is_mac then
  config.send_composed_key_when_left_alt_is_pressed = false
  config.send_composed_key_when_right_alt_is_pressed = false
end

-- =========================================================
-- General appearance
-- =========================================================
config.color_scheme = "Catppuccin Mocha"
config.font = wezterm.font_with_fallback({
  "JetBrains Mono",
  "Cascadia Code",
  "Menlo",       -- macOS fallback
  "Consolas",    -- Windows fallback
  "monospace",   -- Linux fallback
})
config.font_size = 12.5
config.window_background_opacity = 0.96
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 8,
}
config.scrollback_lines = 100000
config.default_cursor_style = "BlinkingBar"

-- A little extra polish on macOS: blur behind the translucent window.
if is_mac then
  config.macos_window_background_blur = 20
end

-- =========================================================
-- Tab bar
-- =========================================================
config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = false
-- Prevent applications from replacing your manually assigned tab title.
config.tab_max_width = 32

-- =========================================================
-- Window behaviour
-- =========================================================
config.window_close_confirmation = "NeverPrompt"
config.adjust_window_size_when_changing_font_size = false

-- =========================================================
-- Default shell (the only real OS difference)
--
--   Windows -> open WSL, since tmux runs inside Linux, not
--             native Windows. tmux must be installed in your
--             WSL distro (e.g. `sudo apt install tmux`).
--   macOS / Linux -> leave default_prog unset so WezTerm uses
--             your login shell (zsh/bash). tmux runs natively;
--             just type `tmux`.
--
-- To auto-start tmux on launch (both OSes), see the commented
-- lines below instead of the plain shell.
-- =========================================================
if is_windows then
  config.default_prog = { "wsl.exe", "~" }
  -- Auto-attach/start tmux on every new WSL shell:
  config.default_prog = { "wsl.exe", "~", "-e", "tmux", "new-session", "-A", "-s", "main" }
end
-- On macOS/Linux we intentionally do NOT set default_prog
-- (WezTerm uses your login shell, where tmux is native).
-- To auto-start tmux there, uncomment:
-- if is_mac or is_linux then
--   config.default_prog = { "tmux", "new-session", "-A", "-s", "main" }
-- end

-- =========================================================
-- Visual profiles
--
-- Colour overrides apply to the complete WezTerm window.
-- Use separate WezTerm windows for Claude, backend, tests,
-- logs and Git if you want all colours visible simultaneously.
-- =========================================================
local profiles = {
  claude = {
    title = "Claude Code",
    background = "#172033",
    foreground = "#E8EEF8",
    cursor = "#89B4FA",
    font_size = 13.5,
  },
  backend = {
    title = "Backend",
    background = "#10291B",
    foreground = "#E2F5E9",
    cursor = "#A6E3A1",
    font_size = 12.5,
  },
  frontend = {
    title = "Frontend",
    background = "#2B2113",
    foreground = "#F8EFD9",
    cursor = "#FAB387",
    font_size = 12.5,
  },
  tests = {
    title = "Tests",
    background = "#241D35",
    foreground = "#F2EAFB",
    cursor = "#CBA6F7",
    font_size = 12.5,
  },
  logs = {
    title = "Logs",
    background = "#111111",
    foreground = "#B8F7B0",
    cursor = "#94E2D5",
    font_size = 11.5,
  },
  git = {
    title = "Git",
    background = "#301819",
    foreground = "#F8E2E2",
    cursor = "#F38BA8",
    font_size = 12.0,
  },
}

-- Apply a visual profile to the active WezTerm window.
local function apply_profile(profile)
  return wezterm.action_callback(function(window, pane)
    local overrides = window:get_config_overrides() or {}
    overrides.font_size = profile.font_size
    overrides.colors = {
      background = profile.background,
      foreground = profile.foreground,
      cursor_bg = profile.cursor,
      cursor_fg = profile.background,
      cursor_border = profile.cursor,
      selection_bg = profile.cursor,
      selection_fg = profile.background,
    }
    window:set_config_overrides(overrides)
    local tab = window:active_tab()
    if tab then
      tab:set_title(profile.title)
    end
    window:set_right_status(
      wezterm.format({
        { Attribute = { Intensity = "Bold" } },
        { Text = " " .. profile.title .. " " },
      })
    )
  end)
end

-- Restore the standard appearance.
local function reset_profile()
  return wezterm.action_callback(function(window, pane)
    local overrides = window:get_config_overrides() or {}
    overrides.font_size = nil
    overrides.colors = nil
    window:set_config_overrides(overrides)
    window:set_right_status("")
  end)
end

-- =========================================================
-- Rename the current tab
-- Alt+r
-- =========================================================
local rename_tab = act.PromptInputLine({
  description = "Enter a name for this terminal tab:",
  action = wezterm.action_callback(function(window, pane, line)
    if line and line ~= "" then
      window:active_tab():set_title(line)
    end
  end),
})

-- =========================================================
-- Dev workspace  (Alt+Shift+W)
--
-- One keypress opens SIX separate windows, each with its own
-- title and colour scheme:
--   claude · backend · frontend · git · logs · tests
--
-- Colour overrides are per-window in WezTerm, so separate
-- windows are exactly how you get all six colours visible at
-- once. Works the same on macOS and Windows/WSL because each
-- window just opens your normal login shell.
--
-- Set WORKSPACE_DIR to auto-cd every window into a project.
-- Add/edit the `cmd` fields to auto-run something per window.
-- =========================================================
local WORKSPACE_DIR = nil -- e.g. "~/projects/myapp"  (nil = your home)

-- Order + optional startup command for each window.
local dev_windows = {
  { profile = profiles.claude,   cmd = "claude" },
  { profile = profiles.backend,  cmd = nil },
  { profile = profiles.frontend, cmd = nil },
  { profile = profiles.git,      cmd = "git status" },
  { profile = profiles.logs,     cmd = nil },
  { profile = profiles.tests,    cmd = nil },
}

-- How the windows are stacked (works on macOS and Windows).
--   STACK_OFFSET = 0  -> piled exactly on top of each other.
--   STACK_OFFSET = 36 -> cascade, so each title bar peeks out.
-- STACK_SIZE = nil keeps WezTerm's default window size.
local STACK_ORIGIN = { x = 90, y = 90 }
local STACK_OFFSET = 36
local STACK_SIZE = { width = 1120, height = 720 } -- or nil

local function open_dev_workspace()
  return wezterm.action_callback(function()
    local cd = WORKSPACE_DIR and ("cd " .. WORKSPACE_DIR .. " && clear\n") or nil
    for i, w in ipairs(dev_windows) do
      local p = w.profile
      -- Each entry gets its own top-level GUI window.
      local tab, pane, mux_win = wezterm.mux.spawn_window({})
      tab:set_title(p.title)

      local gui = mux_win:gui_window()
      if gui then
        -- Stack this window on top of the previous one.
        if STACK_SIZE then
          gui:set_inner_size(STACK_SIZE.width, STACK_SIZE.height)
        end
        gui:set_position(
          STACK_ORIGIN.x + (i - 1) * STACK_OFFSET,
          STACK_ORIGIN.y + (i - 1) * STACK_OFFSET
        )
        gui:set_config_overrides({
          font_size = p.font_size,
          colors = {
            background = p.background,
            foreground = p.foreground,
            cursor_bg = p.cursor,
            cursor_fg = p.background,
            cursor_border = p.cursor,
            selection_bg = p.cursor,
            selection_fg = p.background,
          },
        })
        gui:set_right_status(wezterm.format({
          { Attribute = { Intensity = "Bold" } },
          { Text = " " .. p.title .. " " },
        }))
      end

      if cd then pane:send_text(cd) end
      if w.cmd then pane:send_text(w.cmd .. "\n") end
    end
  end)
end

-- =========================================================
-- Keyboard shortcuts
--
-- The same ALT-based shortcuts work on Windows and macOS.
-- On macOS, ALT is the Option key. If Option-based accented
-- typing ever clashes, change `mods = "ALT"` to `mods = "SUPER"`
-- (Command) on the bindings you care about.
-- =========================================================
config.keys = {
  -- -------------------------------------------------------
  -- Copy / paste with Ctrl+C and Ctrl+V
  -- -------------------------------------------------------
  -- Ctrl+C: copy when text is selected, otherwise send the
  -- normal interrupt (SIGINT) so you can still stop programs.
  {
    key = "c",
    mods = "CTRL",
    action = wezterm.action_callback(function(window, pane)
      local sel = window:get_selection_text_for_pane(pane)
      if sel and sel ~= "" then
        window:perform_action(act.CopyTo("ClipboardAndPrimarySelection"), pane)
        window:perform_action(act.ClearSelection, pane)
      else
        window:perform_action(act.SendKey({ key = "c", mods = "CTRL" }), pane)
      end
    end),
  },
  -- Ctrl+V: paste from the clipboard.
  {
    key = "v",
    mods = "CTRL",
    action = act.PasteFrom("Clipboard"),
  },
  -- -------------------------------------------------------
  -- Window and tab management
  -- -------------------------------------------------------
  -- Launch the full dev workspace: 6 coloured windows (see above).
  {
    key = "w",
    mods = "ALT|SHIFT",
    action = open_dev_workspace(),
  },
  -- New WezTerm window. No shell hardcoded: it inherits the
  -- OS default shell, so it can never break the way pwsh did.
  {
    key = "n",
    mods = "ALT",
    action = act.SpawnCommandInNewWindow({
      cwd = wezterm.home_dir,
    }),
  },
  -- New tab.
  {
    key = "t",
    mods = "ALT",
    action = act.SpawnTab("CurrentPaneDomain"),
  },
  -- Rename current tab.
  {
    key = "r",
    mods = "ALT",
    action = rename_tab,
  },
  -- Close current tab.
  {
    key = "w",
    mods = "ALT",
    action = act.CloseCurrentTab({
      confirm = true,
    }),
  },
  -- Previous and next tab.
  {
    key = "LeftArrow",
    mods = "CTRL|ALT",
    action = act.ActivateTabRelative(-1),
  },
  {
    key = "RightArrow",
    mods = "CTRL|ALT",
    action = act.ActivateTabRelative(1),
  },
  -- Jump directly to tabs 1-5.
  {
    key = "1",
    mods = "ALT",
    action = act.ActivateTab(0),
  },
  {
    key = "2",
    mods = "ALT",
    action = act.ActivateTab(1),
  },
  {
    key = "3",
    mods = "ALT",
    action = act.ActivateTab(2),
  },
  {
    key = "4",
    mods = "ALT",
    action = act.ActivateTab(3),
  },
  {
    key = "5",
    mods = "ALT",
    action = act.ActivateTab(4),
  },
  -- -------------------------------------------------------
  -- Pane management
  -- -------------------------------------------------------
  -- Split into left and right panes.
  {
    key = "h",
    mods = "ALT",
    action = act.SplitHorizontal({
      domain = "CurrentPaneDomain",
    }),
  },
  -- Split into top and bottom panes.
  {
    key = "v",
    mods = "ALT",
    action = act.SplitVertical({
      domain = "CurrentPaneDomain",
    }),
  },
  -- Close active pane.
  {
    key = "x",
    mods = "ALT",
    action = act.CloseCurrentPane({
      confirm = true,
    }),
  },
  -- Zoom or restore active pane.
  {
    key = "z",
    mods = "ALT",
    action = act.TogglePaneZoomState,
  },
  -- Move between panes.
  {
    key = "LeftArrow",
    mods = "ALT",
    action = act.ActivatePaneDirection("Left"),
  },
  {
    key = "RightArrow",
    mods = "ALT",
    action = act.ActivatePaneDirection("Right"),
  },
  {
    key = "UpArrow",
    mods = "ALT",
    action = act.ActivatePaneDirection("Up"),
  },
  {
    key = "DownArrow",
    mods = "ALT",
    action = act.ActivatePaneDirection("Down"),
  },
  -- Resize panes.
  {
    key = "LeftArrow",
    mods = "ALT|SHIFT",
    action = act.AdjustPaneSize({ "Left", 5 }),
  },
  {
    key = "RightArrow",
    mods = "ALT|SHIFT",
    action = act.AdjustPaneSize({ "Right", 5 }),
  },
  {
    key = "UpArrow",
    mods = "ALT|SHIFT",
    action = act.AdjustPaneSize({ "Up", 2 }),
  },
  {
    key = "DownArrow",
    mods = "ALT|SHIFT",
    action = act.AdjustPaneSize({ "Down", 2 }),
  },
  -- -------------------------------------------------------
  -- Apply visual profiles  (Alt+Shift + 1..6 ; reset = Alt+Shift+0)
  --
  -- Holding Shift + a number produces a SYMBOL at the OS level
  -- (1->!, 2->@, 3->#, 4->$, 5->%, 6->^, 0->)). So each profile
  -- is bound BOTH ways: the digit (mods ALT|SHIFT) in case the OS
  -- keeps it, AND the shifted symbol (mods ALT). One always matches.
  -- -------------------------------------------------------
  -- Alt+Shift+1: Claude Code
  { key = "1", mods = "ALT|SHIFT", action = apply_profile(profiles.claude) },
  { key = "!", mods = "ALT",       action = apply_profile(profiles.claude) },
  -- Alt+Shift+2: Backend
  { key = "2", mods = "ALT|SHIFT", action = apply_profile(profiles.backend) },
  { key = "@", mods = "ALT",       action = apply_profile(profiles.backend) },
  -- Alt+Shift+3: Tests
  { key = "3", mods = "ALT|SHIFT", action = apply_profile(profiles.tests) },
  { key = "#", mods = "ALT",       action = apply_profile(profiles.tests) },
  -- Alt+Shift+4: Logs
  { key = "4", mods = "ALT|SHIFT", action = apply_profile(profiles.logs) },
  { key = "$", mods = "ALT",       action = apply_profile(profiles.logs) },
  -- Alt+Shift+5: Git
  { key = "5", mods = "ALT|SHIFT", action = apply_profile(profiles.git) },
  { key = "%", mods = "ALT",       action = apply_profile(profiles.git) },
  -- Alt+Shift+6: Frontend
  { key = "6", mods = "ALT|SHIFT", action = apply_profile(profiles.frontend) },
  { key = "^", mods = "ALT",       action = apply_profile(profiles.frontend) },
  -- Reset visual profile.  (Alt+Shift+0)
  { key = "0", mods = "ALT|SHIFT", action = reset_profile() },
  { key = ")", mods = "ALT",       action = reset_profile() },
  -- -------------------------------------------------------
  -- Search, copy and display
  -- -------------------------------------------------------
  -- Search terminal history.
  {
    key = "f",
    mods = "CTRL|SHIFT",
    action = act.Search({
      CaseInSensitiveString = "",
    }),
  },
  -- Enter copy mode.
  {
    key = "x",
    mods = "CTRL|SHIFT",
    action = act.ActivateCopyMode,
  },
  -- Command palette.
  {
    key = "p",
    mods = "CTRL|SHIFT",
    action = act.ActivateCommandPalette,
  },
  -- Full screen.
  {
    key = "Enter",
    mods = "ALT",
    action = act.ToggleFullScreen,
  },
  -- Font controls.
  {
    key = "+",
    mods = "CTRL",
    action = act.IncreaseFontSize,
  },
  {
    key = "-",
    mods = "CTRL",
    action = act.DecreaseFontSize,
  },
  {
    key = "0",
    mods = "CTRL",
    action = act.ResetFontSize,
  },
  -- Reload this configuration.
  {
    key = "r",
    mods = "CTRL|SHIFT",
    action = act.ReloadConfiguration,
  },
}

-- Make URLs generated by Claude, Codex and local servers clickable.
config.hyperlink_rules = wezterm.default_hyperlink_rules()

return config