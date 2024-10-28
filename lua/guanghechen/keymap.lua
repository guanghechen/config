---@param mode                          string | string[]
---@param key                           string
---@param action                        any
---@param desc                          string
---@param silent                        ?boolean
---@param nowait                        ?boolean
local function mk(mode, key, action, desc, silent, nowait)
  vim.keymap.set(mode, key, action, { noremap = true, silent = silent, nowait = nowait, desc = desc })
end

--#enhance------------------------------------------------------------------------------------------
---! better indenting
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

---! better up/down
vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "down" })
vim.keymap.set({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "down" })
vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "up" })
vim.keymap.set({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "up" })

---! https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
vim.keymap.set("n", "n", "'Nn'[v:searchforward].'zv'", { expr = true, desc = "next Search Result" })
vim.keymap.set("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "next Search Result" })
vim.keymap.set("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "next Search Result" })
vim.keymap.set("n", "N", "'nN'[v:searchforward].'zv'", { expr = true, desc = "prev Search Result" })
vim.keymap.set("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "prev Search Result" })
vim.keymap.set("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "prev Search Result" })

---! quick shortcut
mk({ "i", "n", "v" }, "<C-a>T", ghc.action.theme.toggle_mode, "theme: toggle mode")
mk({ "i", "n", "v" }, "<M-T>", ghc.action.theme.toggle_mode, "theme: toggle mode")

---! better save
mk({ "i", "n", "v" }, "<C-a>s", ghc.action.buf.save, "system: save changes")
mk({ "i", "n", "v" }, "<M-s>", ghc.action.buf.save, "system: save changes")

--- quick access widgets (diagnostic, explorer, terminal)
mk({ "n", "v" }, "<leader>1", ghc.action.explorer.toggle_explorer_file_cwd, "explorer: files (cwd)")
mk({ "n", "v" }, "<leader>3", ghc.action.explorer.toggle_explorer_git_cwd, "explorer: git (cwd)")
---------------------------------------------------------------------------------------#enhance-----

--#navigation---------------------------------------------------------------------------------------
----- buffer -----
mk({ "n", "v" }, "<leader>[", ghc.action.buf.focus_left, "buf: focus left", true, true)
mk({ "n", "v" }, "<leader>]", ghc.action.buf.focus_right, "buf: focus right", true, true)
mk({ "n", "v" }, "<leader>{", ghc.action.buf.swap_left, "buf: swap left", true, true)
mk({ "n", "v" }, "<leader>}", ghc.action.buf.swap_right, "buf: swap right", true, true)
mk({ "n", "v" }, "[b", ghc.action.buf.focus_left, "buf: focus left", true, true)
mk({ "n", "v" }, "]b", ghc.action.buf.focus_right, "buf: focus right", true, true)

----- tab -----
mk({ "n", "v" }, "<leader>,", ghc.action.tab.focus_left, "tab: focus left", true, true)
mk({ "n", "v" }, "<leader>.", ghc.action.tab.focus_right, "tab: focus right", true, true)
mk({ "n", "v" }, "[t", ghc.action.tab.focus_left, "tab: focus left", true, true)
mk({ "n", "v" }, "]t", ghc.action.tab.focus_right, "tab: focus right", true, true)

----- window -----
mk({ "i", "n", "t", "v" }, "<C-a>h", ghc.action.win.focus_left, "win: focus left", true, true)
mk({ "i", "n", "t", "v" }, "<C-a>j", ghc.action.win.focus_bottom, "win: focus bottom", true, true)
mk({ "i", "n", "t", "v" }, "<C-a>k", ghc.action.win.focus_top, "win: focus top", true, true)
mk({ "i", "n", "t", "v" }, "<C-a>l", ghc.action.win.focus_right, "win: focus right", true, true)
mk({ "i", "n", "t", "v" }, "<M-h>", ghc.action.win.focus_left, "win: focus left", true, true)
mk({ "i", "n", "t", "v" }, "<M-j>", ghc.action.win.focus_bottom, "win: focus bottom", true, true)
mk({ "i", "n", "t", "v" }, "<M-k>", ghc.action.win.focus_top, "win: focus top", true, true)
mk({ "i", "n", "t", "v" }, "<M-l>", ghc.action.win.focus_right, "win: focus right", true, true)
mk({ "i", "n", "v" }, "<C-a><Left>", ghc.action.win.resize_vertical_minus, "win: resize -(v:count) vertically.", true)
mk(
  { "i", "n", "v" },
  "<C-a><Down>",
  ghc.action.win.resize_horizontal_minus,
  "win: resize -(v:count) horizontally.",
  true
)
mk({ "i", "n", "v" }, "<C-a><Up>", ghc.action.win.resize_horizontal_plus, "win: resize +(v:count) horizontally.", true)
mk({ "i", "n", "v" }, "<C-a><Right>", ghc.action.win.resize_vertical_plus, "win: resize +(v:count) vertically.", true)
mk({ "i", "n", "v" }, "<M-Left>", ghc.action.win.resize_vertical_minus, "win: resize -(v:count) vertically.", true)
mk({ "i", "n", "v" }, "<M-Down>", ghc.action.win.resize_horizontal_minus, "win: resize -(v:count) horizontally.", true)
mk({ "i", "n", "v" }, "<M-Up>", ghc.action.win.resize_horizontal_plus, "win: resize +(v:count) horizontally.", true)
mk({ "i", "n", "v" }, "<M-Right>", ghc.action.win.resize_vertical_plus, "win: resize +(v:count) vertically.", true)
mk({ "i", "n", "v" }, "<C-a>i", ghc.action.win.backward, "win: back", true, true)
mk({ "i", "n", "v" }, "<C-a>o", ghc.action.win.forward, "win: forward", true, true)
mk({ "i", "n", "v" }, "<M-i>", ghc.action.win.backward, "win: back", true, true)
mk({ "i", "n", "v" }, "<M-o>", ghc.action.win.forward, "win: forward", true, true)
---------------------------------------------------------------------------------------#navigation--

--[#]buffer-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>b1", ghc.action.buf.focus_1, "buf: focus buffer 1", true, true)
mk({ "n", "v" }, "<leader>b2", ghc.action.buf.focus_2, "buf: focus buffer 2", true, true)
mk({ "n", "v" }, "<leader>b3", ghc.action.buf.focus_3, "buf: focus buffer 3", true, true)
mk({ "n", "v" }, "<leader>b4", ghc.action.buf.focus_4, "buf: focus buffer 4", true, true)
mk({ "n", "v" }, "<leader>b5", ghc.action.buf.focus_5, "buf: focus buffer 5", true, true)
mk({ "n", "v" }, "<leader>b6", ghc.action.buf.focus_6, "buf: focus buffer 6", true, true)
mk({ "n", "v" }, "<leader>b7", ghc.action.buf.focus_7, "buf: focus buffer 7", true, true)
mk({ "n", "v" }, "<leader>b8", ghc.action.buf.focus_8, "buf: focus buffer 8", true, true)
mk({ "n", "v" }, "<leader>b9", ghc.action.buf.focus_9, "buf: focus buffer 9", true, true)
mk({ "n", "v" }, "<leader>b0", ghc.action.buf.focus_10, "buf: focus buffer 10", true, true)
mk({ "n", "v" }, "<leader>b[", ghc.action.buf.focus_left, "buf: focus left", true, true)
mk({ "n", "v" }, "<leader>b]", ghc.action.buf.focus_right, "buf: focus right", true, true)
mk({ "n", "v" }, "<leader>bd", ghc.action.buf.close_current, "buf: close current", true)
mk({ "n", "v" }, "<leader>bh", ghc.action.buf.close_to_leftest, "buf: close to the leftest", true)
mk({ "n", "v" }, "<leader>bl", ghc.action.buf.close_to_rightest, "buf: close to the rightest", true)
mk({ "n", "v" }, "<leader>bn", ghc.action.buf.create, "buf: new", true)
mk({ "n", "v" }, "<leader>bo", ghc.action.buf.close_others, "buf: close others", true)
mk({ "n", "v" }, "<leader>bp", ghc.action.buf.toggle_pin_cur, "buf: toggle pin", true)
-----------------------------------------------------------------------------------------#[b]uffer--

--#[x] diagnostic-----------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>xd", ghc.action.diagnostic.toggle_diagnositics_cur, "diagnostic: open diagnostics (document)")
mk({ "n", "v" }, "<leader>xD", ghc.action.diagnostic.toggle_diagnostics, "diagnostic: open diagnostics (workspace)")
mk({ "n", "v" }, "<leader>xL", ghc.action.diagnostic.toggle_loclist, "diagnostic: open location list (Trouble)")
mk({ "n", "v" }, "<leader>xl", ghc.action.diagnostic.open_line_diagnostics, "diagnostic: open diagnostics(line)")
mk({ "n", "v" }, "<leader>xq", ghc.action.diagnostic.toggle_quickfix, "diagnostic: open quickfix list (Trouble)")
mk({ "n", "v" }, "[d", ghc.action.diagnostic.goto_prev_diagnostic, "diagnostic: goto prev diagnostic", true)
mk({ "n", "v" }, "]d", ghc.action.diagnostic.goto_next_diagnostic, "diagnostic: goto next Diagnostic", true)
mk({ "n", "v" }, "[e", ghc.action.diagnostic.goto_prev_error, "diagnostic: goto prev error", true)
mk({ "n", "v" }, "]e", ghc.action.diagnostic.goto_next_error, "diagnostic: goto next error", true)
mk({ "n", "v" }, "[q", ghc.action.diagnostic.toggle_previous_quickfix_item, "diagnostic: goto previous quickfix", true)
mk({ "n", "v" }, "]q", ghc.action.diagnostic.toggle_next_quickfix_item, "diagnostic: goto next quickfix", true)
mk({ "n", "v" }, "[w", ghc.action.diagnostic.goto_prev_warn, "diagnostic: goto prev warning", true)
mk({ "n", "v" }, "]w", ghc.action.diagnostic.goto_next_warn, "diagnostic: goto next warning", true)
-----------------------------------------------------------------------------------#[x] diagnostic--

--#[e]xplorer---------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>eB", ghc.action.explorer.toggle_explorer_buffer_workspace, "explorer: buffers (workspace)")
mk({ "n", "v" }, "<leader>eb", ghc.action.explorer.toggle_explorer_buffer_cwd, "explorer: buffers (cwd)")
mk({ "n", "v" }, "<leader>ee", ghc.action.explorer.toggle_explorer_last, "explorer: last")
mk({ "n", "v" }, "<leader>eF", ghc.action.explorer.toggle_explorer_file_workspace, "explorer: files (workspace)")
mk({ "n", "v" }, "<leader>ef", ghc.action.explorer.toggle_explorer_file_cwd, "explorer: files (cwd)")
mk({ "n", "v" }, "<leader>eG", ghc.action.explorer.toggle_explorer_git_workspace, "explorer: git (workspace)")
mk({ "n", "v" }, "<leader>eg", ghc.action.explorer.toggle_explorer_git_cwd, "explorer: git (cwd)")
mk({ "n", "v" }, "<leader>er", ghc.action.explorer.reveal_file_explorer, "explorer: reveal file")
mk({ "n", "v" }, "<leader>et", ghc.action.explorer.toggle_explorers, "explorer: toggle")
---------------------------------------------------------------------------------------#[e]xplorer--

--#[f]ile-------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>fn", ghc.action.buf.create, "file: new", true)
-------------------------------------------------------------------------------------------#[f]ile--

--#[s]croll-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>sj", ghc.action.scroll.down_half_window, "scroll: down half of window")
mk({ "n", "v" }, "<leader>sk", ghc.action.scroll.up_half_window, "scroll: up half of window")
-----------------------------------------------------------------------------------------#[s]croll--

--#[t]ab--------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>t1", ghc.action.tab.focus_1, "tab: focus tab 1", true, true)
mk({ "n", "v" }, "<leader>t2", ghc.action.tab.focus_2, "tab: focus tab 2", true, true)
mk({ "n", "v" }, "<leader>t3", ghc.action.tab.focus_3, "tab: focus tab 3", true, true)
mk({ "n", "v" }, "<leader>t4", ghc.action.tab.focus_4, "tab: focus tab 4", true, true)
mk({ "n", "v" }, "<leader>t5", ghc.action.tab.focus_5, "tab: focus tab 5", true, true)
mk({ "n", "v" }, "<leader>t6", ghc.action.tab.focus_6, "tab: focus tab 6", true, true)
mk({ "n", "v" }, "<leader>t7", ghc.action.tab.focus_7, "tab: focus tab 7", true, true)
mk({ "n", "v" }, "<leader>t8", ghc.action.tab.focus_8, "tab: focus tab 8", true, true)
mk({ "n", "v" }, "<leader>t9", ghc.action.tab.focus_9, "tab: focus tab 9", true, true)
mk({ "n", "v" }, "<leader>t0", ghc.action.tab.focus_10, "tab: focus tab 10", true, true)
mk({ "n", "v" }, "<leader>t[", ghc.action.tab.focus_left, "tab: focus the left tab", true)
mk({ "n", "v" }, "<leader>t]", ghc.action.tab.focus_right, "tab: focus the right tab", true)
mk({ "n", "v" }, "<leader>tN", ghc.action.tab.create, "tab: new tab", true)
mk({ "n", "v" }, "<leader>tn", ghc.action.tab.create_with_buf, "tab: new tab with current buf", true)
mk({ "n", "v" }, "<leader>td", ghc.action.tab.close_current, "tab: close", true)
mk({ "n", "v" }, "<leader>th", ghc.action.tab.close_to_leftest, "tab: close tabs to the leftest", true)
mk({ "n", "v" }, "<leader>tl", ghc.action.tab.close_to_rightest, "tab: close tabs to the rightest", true)
mk({ "n", "v" }, "<leader>to", ghc.action.tab.close_others, "tab: close other tabs", true)
--------------------------------------------------------------------------------------------#[t]ab--

--#[t]oggle-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>tul", ghc.action.theme.toggle_relativenumber, "toggle: relative line number")
mk({ "n", "v" }, "<leader>tuT", ghc.action.theme.toggle_transparency, "toggle: transparency")
mk({ "n", "v" }, "<leader>tuw", ghc.action.theme.toggle_wrap_tmp, "toggle: wrap (temporary)")
-----------------------------------------------------------------------------------------#[t]oggle--

--#[u]i---------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>un", ghc.action.notification.dismiss_all, "notification: dismiss all")
---------------------------------------------------------------------------------------------#[u]i--

--#[w]indow-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>wh", ghc.action.find_win_history.focus, "win: history", true)
mk({ "n", "v" }, "<leader>wp", ghc.action.win.project_with_picker, "win: project (with picker)", true)
mk({ "n", "v" }, "<leader>ws", ghc.action.win.swap_with_picker, "win: swap (with picker)", true)
mk({ "n", "v" }, "<leader>ww", ghc.action.win.focus_with_picker, "win: focus (with picker)", true)
mk({ "n", "v" }, "<leader>wj", ghc.action.win.split_horizontal, "win: split horizontally", true)
mk({ "n", "v" }, "<leader>wl", ghc.action.win.split_vertical, "win: split vertically", true)
mk({ "n", "v" }, "<leader>wd", ghc.action.win.close_current, "win: close current window", true)
mk({ "n", "v" }, "<leader>wo", ghc.action.win.close_others, "win: close others", true)
-----------------------------------------------------------------------------------------#[w]indow--
