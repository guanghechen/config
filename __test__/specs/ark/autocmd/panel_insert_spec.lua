local t = require("__test__.support.harness").new()
local UI = require("__test__.support.ui")

t:test("an Explorer or Diffview panel that a click or a window key enters from Insert mode ends it", function()
  local ui = UI.open(t, { width = 80, height = 20, runtime = "ark" })
  ui:lua([[
    editor = vim.api.nvim_get_current_win()
    vim.cmd("leftabove vsplit")
    panel = vim.api.nvim_get_current_win()
    -- Stands for the global window keys such as <C-a>h, which also work in Insert mode.
    vim.keymap.set("i", "<F2>", "<Cmd>wincmd h<CR>")
  ]])
  ---@param wintype                     ?string The `stl.e.WinTypeEnum` name of the panel.
  ---@param keys                        ?string The keys that enter the panel; a click without them.
  ---@return string mode
  local function enter(wintype, keys)
    ui:lua("vim.w[panel].wintype = ... and stl.e.WinTypeEnum[...]; vim.api.nvim_set_current_win(editor)", wintype)
    ui:rpc("nvim_input", "i")
    ui:wait_lua("return vim.api.nvim_get_mode().mode == 'i'", 5000, "Insert mode in the editor")
    if keys then
      ui:rpc("nvim_input", keys)
    else
      ui:rpc("nvim_command", "redraw")
      local window = ui:lua("return vim.fn.getwininfo(panel)[1]")
      ui:rpc("nvim_input_mouse", "left", "press", "", 0, window.winrow, window.wincol + 1)
      ui:rpc("nvim_input_mouse", "left", "release", "", 0, window.winrow, window.wincol + 1)
    end
    ui:wait_lua("return vim.api.nvim_get_current_win() == panel", 5000, "the panel takes the focus")
    local mode = ui:lua("return vim.api.nvim_get_mode().mode")
    ui:rpc("nvim_input", "<Esc>")
    ui:wait_lua("return vim.api.nvim_get_mode().mode == 'n'", 5000, "Normal mode")
    return mode
  end

  t.assert_eq("n", enter("EXPLORER"), "a click into the Explorer")
  t.assert_eq("n", enter("EXPLORER", "<F2>"), "a window key into the Explorer")
  t.assert_eq("n", enter("DIFFVIEW_PANEL", "<F2>"), "a window key into a Diffview panel")
  t.assert_eq("i", enter(nil, "<F2>"), "any other window keeps Insert mode")
end)

t:run()
