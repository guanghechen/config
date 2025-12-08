local wezterm = require("wezterm")
local act = wezterm.action

---@class keymap.win
local M = {}

---@param config table
function M.setup(config)
  local keys = {}

  -- CSI u format keybindings for special keys (ghostty-style)
  table.insert(keys, { key = "Tab", mods = "", action = act.SendString("\x1b[9;1u") })
  -- table.insert(keys, { key = "Enter", mods = "", action = act.SendString("\x1b[13;1u") })
  table.insert(keys, { key = "Escape", mods = "", action = act.SendString("\x1b[27;1u") })
  table.insert(keys, { key = "Tab", mods = "SHIFT", action = act.SendString("\x1b[9;2u") })
  table.insert(keys, { key = "Enter", mods = "SHIFT", action = act.SendString("\x1b[13;2u") })
  table.insert(keys, { key = "Escape", mods = "SHIFT", action = act.SendString("\x1b[27;2u") })

  -- ctrl+keys to CSI u format
  local ctrl_keys = {
    { key = ",", code = 44 },
    { key = ".", code = 46 },
    { key = "/", code = 47 },
    { key = "0", code = 48 },
    { key = "1", code = 49 },
    { key = "2", code = 50 },
    { key = "3", code = 51 },
    { key = "4", code = 52 },
    { key = "5", code = 53 },
    { key = "6", code = 54 },
    { key = "7", code = 55 },
    { key = "8", code = 56 },
    { key = "9", code = 57 },
    { key = "[", code = 91 },
    { key = "]", code = 93 },
    { key = "`", code = 96 },
    { key = "i", code = 105 },
    { key = "m", code = 109 },
    { key = "o", code = 111 },
  }

  for _, entry in ipairs(ctrl_keys) do
    table.insert(keys, {
      key = entry.key,
      mods = "CTRL",
      action = act.SendString(string.format("\x1b[%d;5u", entry.code)),
    })
  end

  -- ctrl+shift+keys to CSI u format
  local ctrl_shift_keys = {
    { key = "<", code = 44 },
    { key = ">", code = 46 },
    { key = "?", code = 47 },
    { key = "{", code = 91 },
    { key = "}", code = 93 },
  }

  for _, entry in ipairs(ctrl_shift_keys) do
    table.insert(keys, {
      key = entry.key,
      mods = "CTRL|SHIFT",
      action = act.SendString(string.format("\x1b[%d;6u", entry.code)),
    })
  end

  -- ctrl+shift+letter to CSI u format
  local letters = {
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z",
  }

  for _, key in ipairs(letters) do
    local ascii_code = string.byte(key:upper())
    table.insert(keys, {
      key = key:upper(),
      mods = "CTRL|SHIFT",
      action = act.SendString(string.format("\x1b[%d;6u", ascii_code)),
    })
  end

  -- Alt+Keys -> Ctrl+A prefix (tmux style)

  -- Function keys (Alt+Fn -> Ctrl+A Fn)
  local fn_sequences = {
    { key = "F1", seq = "\x01\x1bOP" },
    { key = "F2", seq = "\x01\x1bOQ" },
    { key = "F3", seq = "\x01\x1bOR" },
    { key = "F4", seq = "\x01\x1bOS" },
    { key = "F5", seq = "\x01\x1b[15~" },
    { key = "F6", seq = "\x01\x1b[17~" },
    { key = "F7", seq = "\x01\x1b[18~" },
    { key = "F8", seq = "\x01\x1b[19~" },
    { key = "F9", seq = "\x01\x1b[20~" },
    { key = "F10", seq = "\x01\x1b[21~" },
    { key = "F11", seq = "\x01\x1b[23~" },
    { key = "F12", seq = "\x01\x1b[24~" },
  }

  for _, entry in ipairs(fn_sequences) do
    table.insert(keys, {
      key = entry.key,
      mods = "ALT",
      action = act.SendString(entry.seq),
    })
  end

  -- Shift+Function keys
  local shift_fn_sequences = {
    { key = "F1", seq = "\x01\x1b[1;2P" },
    { key = "F2", seq = "\x01\x1b[1;2Q" },
    { key = "F3", seq = "\x01\x1b[1;2R" },
    { key = "F4", seq = "\x01\x1b[1;2S" },
    { key = "F5", seq = "\x01\x1b[15;2~" },
    { key = "F6", seq = "\x01\x1b[17;2~" },
    { key = "F7", seq = "\x01\x1b[18;2~" },
    { key = "F8", seq = "\x01\x1b[19;2~" },
    { key = "F9", seq = "\x01\x1b[20;2~" },
    { key = "F10", seq = "\x01\x1b[21;2~" },
    { key = "F11", seq = "\x01\x1b[23;2~" },
    { key = "F12", seq = "\x01\x1b[24;2~" },
  }

  for _, entry in ipairs(shift_fn_sequences) do
    table.insert(keys, {
      key = entry.key,
      mods = "ALT|SHIFT",
      action = act.SendString(entry.seq),
    })
  end

  -- Arrow keys (Alt+Arrow -> Ctrl+A Arrow)
  local arrow_sequences = {
    { key = "UpArrow", seq = "\x01\x1b[A" },
    { key = "RightArrow", seq = "\x01\x1b[C" },
    { key = "DownArrow", seq = "\x01\x1b[B" },
    { key = "LeftArrow", seq = "\x01\x1b[D" },
  }

  for _, entry in ipairs(arrow_sequences) do
    table.insert(keys, {
      key = entry.key,
      mods = "ALT",
      action = act.SendString(entry.seq),
    })
  end

  -- Shift+Arrow keys
  local shift_arrow_sequences = {
    { key = "UpArrow", seq = "\x01\x1b[1;2A" },
    { key = "RightArrow", seq = "\x01\x1b[1;2C" },
    { key = "DownArrow", seq = "\x01\x1b[1;2B" },
    { key = "LeftArrow", seq = "\x01\x1b[1;2D" },
  }

  for _, entry in ipairs(shift_arrow_sequences) do
    table.insert(keys, {
      key = entry.key,
      mods = "ALT|SHIFT",
      action = act.SendString(entry.seq),
    })
  end

  -- Digit keys (Alt+N -> Ctrl+A N)
  local digits = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }

  for _, key in ipairs(digits) do
    table.insert(keys, {
      key = key,
      mods = "ALT",
      action = act.SendString("\x01" .. key),
    })
  end

  -- Letter keys (Alt+Letter -> Ctrl+A letter)
  for _, key in ipairs(letters) do
    table.insert(keys, {
      key = key,
      mods = "ALT",
      action = act.SendString("\x01" .. key),
    })
  end

  -- Upper letter keys (Alt+Shift+Letter -> Ctrl+A LETTER)
  for _, key in ipairs(letters) do
    table.insert(keys, {
      key = key:upper(),
      mods = "ALT|SHIFT",
      action = act.SendString("\x01" .. key:upper()),
    })
  end

  -- Ctrl+letter keys (Alt+Ctrl+Letter -> Ctrl+A Ctrl+Letter)
  local ctrl_letter_codes = {
    a = 0x01,
    b = 0x02,
    c = 0x03,
    d = 0x04,
    e = 0x05,
    f = 0x06,
    g = 0x07,
    i = 0x09,
    m = 0x0d,
    n = 0x0e,
    o = 0x0f,
    p = 0x10,
    q = 0x11,
    r = 0x12,
    s = 0x13,
    t = 0x14,
    u = 0x15,
    v = 0x16,
    w = 0x17,
    x = 0x18,
    y = 0x19,
    z = 0x1a,
  }

  for key, code in pairs(ctrl_letter_codes) do
    table.insert(keys, {
      key = key,
      mods = "ALT|CTRL",
      action = act.SendString("\x01" .. string.char(code)),
    })
  end

  -- Special characters (Alt+Punct -> Ctrl+A punct)
  local special_chars = {
    { key = ",", mods = "ALT", seq = "\x01\x2c" },
    { key = ".", mods = "ALT", seq = "\x01\x2e" },
    { key = "<", mods = "ALT|SHIFT", seq = "\x01\x3c" },
    { key = ">", mods = "ALT|SHIFT", seq = "\x01\x3e" },
    { key = "[", mods = "ALT", seq = "\x01\x5b" },
    { key = "]", mods = "ALT", seq = "\x01\x5d" },
    { key = "{", mods = "ALT|SHIFT", seq = "\x01\x7b" },
    { key = "}", mods = "ALT|SHIFT", seq = "\x01\x7d" },
    { key = "Enter", mods = "ALT", seq = "\x1b\x0d" },
    { key = ";", mods = "ALT", seq = "\x01\x3b" },
    { key = ":", mods = "ALT|SHIFT", seq = "\x01\x3a" },
    { key = "'", mods = "ALT", seq = "\x01\x27" },
    { key = "`", mods = "ALT", seq = "\x01\x60" },
  }

  for _, entry in ipairs(special_chars) do
    table.insert(keys, {
      key = entry.key,
      mods = entry.mods,
      action = act.SendString(entry.seq),
    })
  end

  -- Terminal actions (placed last to override SendString bindings)

  -- Clipboard
  table.insert(keys, { key = "v", mods = "ALT", action = act.PasteFrom("Clipboard") })
  table.insert(keys, { key = "Insert", mods = "CTRL", action = act.CopyTo("Clipboard") })
  table.insert(keys, { key = "Insert", mods = "SHIFT", action = act.PasteFrom("Clipboard") })

  -- Tab management
  table.insert(keys, { key = "n", mods = "ALT|CTRL", action = act.SpawnTab("CurrentPaneDomain") })
  table.insert(keys, { key = ",", mods = "ALT|CTRL", action = act.ActivateTabRelative(-1) })
  table.insert(keys, { key = ".", mods = "ALT|CTRL", action = act.ActivateTabRelative(1) })
  table.insert(keys, { key = "<", mods = "ALT|CTRL|SHIFT", action = act.MoveTabRelative(-1) })
  table.insert(keys, { key = ">", mods = "ALT|CTRL|SHIFT", action = act.MoveTabRelative(1) })
  table.insert(keys, { key = "1", mods = "ALT|CTRL", action = act.ActivateTab(0) })
  table.insert(keys, { key = "2", mods = "ALT|CTRL", action = act.ActivateTab(1) })
  table.insert(keys, { key = "3", mods = "ALT|CTRL", action = act.ActivateTab(2) })
  table.insert(keys, { key = "4", mods = "ALT|CTRL", action = act.ActivateTab(3) })
  table.insert(keys, { key = "5", mods = "ALT|CTRL", action = act.ActivateTab(4) })
  table.insert(keys, { key = "6", mods = "ALT|CTRL", action = act.ActivateTab(5) })
  table.insert(keys, { key = "7", mods = "ALT|CTRL", action = act.ActivateTab(6) })
  table.insert(keys, { key = "8", mods = "ALT|CTRL", action = act.ActivateTab(7) })
  table.insert(keys, { key = "9", mods = "ALT|CTRL", action = act.ActivateTab(8) })

  -- Split/Pane management
  table.insert(keys, {
    key = "J",
    mods = "ALT|CTRL|SHIFT",
    action = act.SplitPane({ direction = "Down", command = { cwd = wezterm.home_dir } }),
  })
  table.insert(keys, {
    key = "L",
    mods = "ALT|CTRL|SHIFT",
    action = act.SplitPane({ direction = "Right", command = { cwd = wezterm.home_dir } }),
  })
  table.insert(keys, { key = "h", mods = "ALT|CTRL", action = act.ActivatePaneDirection("Left") })
  table.insert(keys, { key = "j", mods = "ALT|CTRL", action = act.ActivatePaneDirection("Down") })
  table.insert(keys, { key = "k", mods = "ALT|CTRL", action = act.ActivatePaneDirection("Up") })
  table.insert(keys, { key = "l", mods = "ALT|CTRL", action = act.ActivatePaneDirection("Right") })
  table.insert(keys, { key = "LeftArrow", mods = "ALT|CTRL", action = act.AdjustPaneSize({ "Left", 1 }) })
  table.insert(keys, { key = "DownArrow", mods = "ALT|CTRL", action = act.AdjustPaneSize({ "Down", 1 }) })
  table.insert(keys, { key = "UpArrow", mods = "ALT|CTRL", action = act.AdjustPaneSize({ "Up", 1 }) })
  table.insert(keys, { key = "RightArrow", mods = "ALT|CTRL", action = act.AdjustPaneSize({ "Right", 1 }) })
  table.insert(keys, { key = "LeftArrow", mods = "ALT|CTRL|SHIFT", action = act.RotatePanes("CounterClockwise") })
  table.insert(keys, { key = "RightArrow", mods = "ALT|CTRL|SHIFT", action = act.RotatePanes("Clockwise") })
  table.insert(keys, { key = "w", mods = "ALT|CTRL", action = act.CloseCurrentPane({ confirm = false }) })
  table.insert(keys, { key = "z", mods = "ALT|CTRL", action = act.TogglePaneZoomState })

  -- Font size controls
  table.insert(keys, { key = "0", mods = "ALT|CTRL", action = act.ResetFontSize })
  table.insert(keys, { key = "=", mods = "ALT|CTRL", action = act.IncreaseFontSize })
  table.insert(keys, { key = "-", mods = "ALT|CTRL", action = act.DecreaseFontSize })

  -- Configuration
  table.insert(keys, { key = "F5", mods = "ALT|CTRL", action = act.ReloadConfiguration })
  table.insert(keys, { key = "F11", mods = "", action = act.ToggleFullScreen })
  table.insert(keys, { key = "F12", mods = "ALT|CTRL", action = act.ToggleFullScreen })

  -- Launch Menu (Profiles)
  table.insert(keys, { key = "p", mods = "ALT|CTRL", action = act.ShowLauncher })

  -- Tab title
  table.insert(keys, {
    key = "F2",
    mods = "ALT|CTRL",
    action = act.PromptInputLine({
      description = "Enter new name for tab",
      action = wezterm.action_callback(function(window, _, line)
        if line then
          window:active_tab():set_title(line)
        end
      end),
    }),
  })

  config.keys = keys
end

return M
