local commander = require("eve.std.commander")
local uuids = commander.uuids ---@type eve.std.commander.uuids

---@param modes                         string[]
---@param key                           string
---@param uuid                          string
---@param desc                          ?string
local function mk(modes, key, uuid, desc)
  local action = uuid ---@type string|fun():nil

  if commander.should_be_command(uuid) then
    if desc == nil then
      local command = commander.resolve(uuid, true) ---@type t.eve.ICommand|nil
      desc = command ~= nil and command.desc or nil ---@type string|nil
    end

    ---@return nil
    action = function()
      commander.execute(uuid)
    end
  end

  vim.keymap.set(modes, key, action, {
    noremap = true,
    silent = true,
    nowait = true,
    desc = desc,
  })
end

--#enhance------------------------------------------------------------------------------------------
mk({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", "remove search highlights") -- Clear search with <esc>
-- mk({ "t" }, "<esc><esc>", "<C-\\><C-n>", "terminal: enter normal mode") -- Exit terminal

---! Add undo break-points
mk({ "i" }, "<space>", "<space><c-g>u")
mk({ "i" }, "<cr>", "<cr><c-g>u")
mk({ "i" }, ",", ",<c-g>u")
mk({ "i" }, ".", ".<c-g>u")
mk({ "i" }, ";", ";<c-g>u")

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

----- better copy/paste list -----
mk({ "v" }, "<C-a>c", '"+y', "system: copy to clipboard")
mk({ "v" }, "<M-c>", '"+y', "system: copy to clipboard")
mk({ "v" }, "<C-a>x", '"+x', "system: cut to clipboard")
mk({ "v" }, "<M-x>", '"+x', "system: cut to clipboard")
mk({ "i", "n", "v" }, "<C-a>a", "<esc>gg0vG$", "system: select all")
mk({ "i", "n", "v" }, "<M-a>", "<esc>gg0vG$", "system: select all")
mk({ "i", "n", "v" }, "<C-a>v", '<esc>"+p', "system: paste from clipboard")
mk({ "i", "n", "v" }, "<M-v>", '<esc>"+p', "system: paste from clipboard")

----- jump list -----
mk({ "i", "n", "v" }, "<C-i>", "<C-o>", "jump back")
mk({ "i", "n", "v" }, "<C-o>", "<C-i>", "jump forward")

--- quick access widgets (diagnostic, explorer, terminal) -----
mk({ "n", "t", "v" }, "<leader>`", uuids.resume, "resume: widgets")
mk({ "n", "v" }, "<leader>1", uuids.explorer_filesystem_cwd, "explorer: filesystem (cwd)")
mk({ "n", "v" }, "<leader>2", uuids.search_files, "search: files")
mk({ "n", "v" }, "<leader>3", uuids.explorer_git_cwd, "explorer: git (cwd)")
------------------------------------------------------------------------------------------#enhance--

--#[a]i---------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>aa", uuids.copilot_chat_toggle, "copilot chat: toggle")
mk({ "n", "v" }, "<leader>ap", uuids.copilot_chat_prompt, "copilot chat: prompt actions")
mk({ "n", "v" }, "<leader>aq", uuids.copilot_chat_quick, "copilot chat: quick chat")
mk({ "n", "v" }, "<leader>as", uuids.copilot_chat_stop, "copilot chat: stop output")
mk({ "n", "v" }, "<leader>ax", uuids.copilot_chat_reset, "copilot chat: reset")
---------------------------------------------------------------------------------------------#[a]i--

--#[b]uf--------------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<C-a>s", uuids.buf_save, "buf: save changes")
mk({ "i", "n", "v" }, "<M-s>", uuids.buf_save, "buf: save changes")
mk({ "n", "v" }, "<leader>[", uuids.buf_focus_left, "buf: focus left")
mk({ "n", "v" }, "<leader>]", uuids.buf_focus_right, "buf: focus right")
mk({ "n", "v" }, "<leader>{", uuids.buf_swap_left, "buf: swap left")
mk({ "n", "v" }, "<leader>}", uuids.buf_swap_right, "buf: swap right")
mk({ "n", "v" }, "<leader>b[", uuids.buf_focus_left, "buf: focus left")
mk({ "n", "v" }, "<leader>b]", uuids.buf_focus_right, "buf: focus right")
mk({ "n", "v" }, "<leader>b{", uuids.buf_swap_left, "buf: swap left")
mk({ "n", "v" }, "<leader>b}", uuids.buf_swap_right, "buf: swap right")
mk({ "n", "v" }, "<leader>b1", uuids.buf_focus_1, "buf: focus 1")
mk({ "n", "v" }, "<leader>b2", uuids.buf_focus_2, "buf: focus 2")
mk({ "n", "v" }, "<leader>b3", uuids.buf_focus_3, "buf: focus 3")
mk({ "n", "v" }, "<leader>b4", uuids.buf_focus_4, "buf: focus 4")
mk({ "n", "v" }, "<leader>b5", uuids.buf_focus_5, "buf: focus 5")
mk({ "n", "v" }, "<leader>b6", uuids.buf_focus_6, "buf: focus 6")
mk({ "n", "v" }, "<leader>b7", uuids.buf_focus_7, "buf: focus 7")
mk({ "n", "v" }, "<leader>b8", uuids.buf_focus_8, "buf: focus 8")
mk({ "n", "v" }, "<leader>b9", uuids.buf_focus_9, "buf: focus 9")
mk({ "n", "v" }, "<leader>b0", uuids.buf_focus_10, "buf: focus 10")
mk({ "n", "v" }, "<leader>bd", uuids.buf_close, "buf: close current")
mk({ "n", "v" }, "<leader>bh", uuids.buf_close_to_leftest, "buf: close to the leftest")
mk({ "n", "v" }, "<leader>bl", uuids.buf_close_to_rightest, "buf: close to the rightest")
mk({ "n", "v" }, "<leader>bn", uuids.buf_new, "buf: new")
mk({ "n", "v" }, "<leader>bo", uuids.buf_close_others, "buf: close others")
mk({ "n", "v" }, "<leader>bp", uuids.buf_pin, "buf: toggle pin")
--------------------------------------------------------------------------------------------#[b]uf--

--#[c]ode-------------------------------------------------------------------------------------------
mk({ "n" }, "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "code: add comment below")
mk({ "n" }, "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "code: add comment above")
-------------------------------------------------------------------------------------------#[c]ode--

--#[c]opy-------------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<C-a>C", uuids.copy_current_filepath, "copy: current filepath")
mk({ "i", "n", "v" }, "<M-C>", uuids.copy_current_filepath, "copy: current filepath")
mk({ "i", "n" }, "<C-a>c", uuids.copy_current_filepath_relative, "copy: current filepath (relative)")
mk({ "i", "n" }, "<M-c>", uuids.copy_current_filepath_relative, "copy: current filepath (relative)")
-----------------------------------------------------------------------------------------#[c]opy----

--#[d]ebug------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>dd", uuids.debug_inspect, "debug: inspect")
mk({ "n", "v" }, "<leader>dI", uuids.debug_inspect_tree, "debug: inspect tree")
mk({ "n", "v" }, "<leader>di", uuids.debug_inspect_pos, "debug: inspect pos")
mk({ "n", "v" }, "<leader>ds", uuids.debug_inspect_state, "debug: inspect state")
------------------------------------------------------------------------------------------#[d]ebug--

--#[e]xplorer---------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>ee", uuids.explorer_last, "explorer: last")
mk({ "n", "v" }, "<leader>eF", uuids.explorer_filesystem_workspace, "explorer: filesystem (workspace)")
mk({ "n", "v" }, "<leader>ef", uuids.explorer_filesystem_cwd, "explorer: filesystem (cwd)")
mk({ "n", "v" }, "<leader>eG", uuids.explorer_git_workspace, "explorer: git (workspace)")
mk({ "n", "v" }, "<leader>eg", uuids.explorer_git_cwd, "explorer: git (cwd)")
mk({ "n", "v" }, "<leader>er", uuids.explorer_reveal, "explorer: reveal")
mk({ "n", "v" }, "<leader>et", uuids.explorer_toggle, "explorer: toggle")
---------------------------------------------------------------------------------------#[e]xplorer--

--#[f]ind-------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader><leader>", uuids.find_files, "find: files")
mk({ "n", "v" }, "<leader>fb", uuids.find_buffers, "find: buffers")
mk({ "n", "v" }, "<leader>fc", uuids.find_files_cwd, "find: files (cwd)")
mk({ "n", "v" }, "<leader>fe", uuids.find_explorer, "find: explorer")
mk({ "n", "v" }, "<leader>fd", uuids.find_files_directory, "find: files (directory)")
mk({ "n", "v" }, "<leader>ff", uuids.find_files, "find: files")
mk({ "n", "v" }, "<leader>fg", uuids.find_git_not_committed, "find: files (git not committed)")
mk({ "n", "v" }, "<leader>fh", uuids.find_highlights, "find: highlights")
mk({ "n", "v" }, "<leader>fp", uuids.find_pinned_files, "find: files (pinned)")
mk({ "n", "v" }, "<leader>fv", uuids.find_vim_options, "find: vim options")
mk({ "n", "v" }, "<leader>fw", uuids.find_files_workspace, "find: files (workspace)")
-------------------------------------------------------------------------------------------#[f]ind--

--#[g]it--------------------------------------------------------------------------------------------
mk({ "i", "n", "t", "v" }, "<C-a>g", uuids.lazygit_cwd, "git: toggle lazygit (cwd)")
mk({ "i", "n", "t", "v" }, "<M-g>", uuids.lazygit_cwd, "git: toggle lazygit (cwd)")
mk({ "n", "v" }, "<leader>gf", uuids.git_file_history, "git: open file history")
mk({ "n", "v" }, "<leader>gg", uuids.git_diffview, "git: open diffview")
--------------------------------------------------------------------------------------------#[g]it--

--#[q]uit-------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>qq", "<cmd>qa<cr>", "quit: quit all")
mk({ "n", "v" }, "<leader>ql", uuids.session_restore, "session: restore")
mk({ "n", "v" }, "<leader>qs", uuids.session_save, "session: save")
-------------------------------------------------------------------------------------------#[q]uit--

--#[r]efresh----------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<C-a>r", uuids.refresh_all, "refresh: all")
mk({ "i", "n", "v" }, "<M-r>", uuids.refresh_all, "refresh: all")
---------------------------------------------------------------------------------------#[r]efresh---

--#[r]eplace----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>rr", uuids.replace_files, "replace: files")
mk({ "n", "v" }, "<leader>rb", uuids.replace_files_buffer, "replace: files (buffer)")
mk({ "n", "v" }, "<leader>rd", uuids.replace_files_directory, "replace: files (directory)")
mk({ "n", "v" }, "<leader>rc", uuids.replace_files_cwd, "replace: files (cwd)")
mk({ "n", "v" }, "<leader>rw", uuids.replace_files_workspace, "replace: files (workspace)")
---------------------------------------------------------------------------------------#[r]eplace---

--#[r]run-------------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<F5>", uuids.run, "run: run codes")
-------------------------------------------------------------------------------------------#[r]run--

--#[s]croll-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>sj", uuids.scroll_down_half_window, "scroll: down (half window)")
mk({ "n", "v" }, "<leader>sk", uuids.scroll_up_half_window, "scroll: up (half window)")
-----------------------------------------------------------------------------------------#[s]croll--

--#[s]earch-----------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<C-a>f", uuids.search_files_buffer, "search: files (buffer)")
mk({ "i", "n", "v" }, "<M-f>", uuids.search_files_buffer, "search: files (buffer)")
mk({ "n", "v" }, "<leader>ss", uuids.search_files, "search: files")
mk({ "n", "v" }, "<leader>sb", uuids.search_files_buffer, "search: files (buffer)")
mk({ "n", "v" }, "<leader>sc", uuids.search_files_cwd, "search: files (cwd)")
mk({ "n", "v" }, "<leader>sd", uuids.search_files_directory, "search: files (directory)")
mk({ "n", "v" }, "<leader>sw", uuids.search_files_workspace, "search: files (workspace)")
-----------------------------------------------------------------------------------------#[s]earch--

--#[t]ab--------------------------------------------------------------------------------------------
mk({ "n", "v" }, "[t", uuids.tab_focus_left, "tab: focus left")
mk({ "n", "v" }, "]t", uuids.tab_focus_right, "tab: focus right")
mk({ "n", "v" }, "<leader>,", uuids.tab_focus_left, "tab: focus left")
mk({ "n", "v" }, "<leader>.", uuids.tab_focus_right, "tab: focus right")
mk({ "n", "v" }, "<leader>t[", uuids.tab_focus_left, "tab: focus left")
mk({ "n", "v" }, "<leader>t]", uuids.tab_focus_right, "tab: focus right")
mk({ "n", "v" }, "<leader>t1", uuids.tab_focus_1, "tab: focus 1")
mk({ "n", "v" }, "<leader>t2", uuids.tab_focus_2, "tab: focus 2")
mk({ "n", "v" }, "<leader>t3", uuids.tab_focus_3, "tab: focus 3")
mk({ "n", "v" }, "<leader>t4", uuids.tab_focus_4, "tab: focus 4")
mk({ "n", "v" }, "<leader>t5", uuids.tab_focus_5, "tab: focus 5")
mk({ "n", "v" }, "<leader>t6", uuids.tab_focus_6, "tab: focus 6")
mk({ "n", "v" }, "<leader>t7", uuids.tab_focus_7, "tab: focus 7")
mk({ "n", "v" }, "<leader>t8", uuids.tab_focus_8, "tab: focus 8")
mk({ "n", "v" }, "<leader>t9", uuids.tab_focus_9, "tab: focus 9")
mk({ "n", "v" }, "<leader>t0", uuids.tab_focus_10, "tab: focus 10")
mk({ "n", "v" }, "<leader>td", uuids.tab_close, "tab: close current")
mk({ "n", "v" }, "<leader>th", uuids.tab_close_to_leftest, "tab: close to the leftest")
mk({ "n", "v" }, "<leader>tl", uuids.tab_close_to_rightest, "tab: close to the rightest")
mk({ "n", "v" }, "<leader>to", uuids.tab_close_others, "tab: close other tabs")
mk({ "n", "v" }, "<leader>tN", uuids.tab_new, "tab: new")
mk({ "n", "v" }, "<leader>tn", uuids.tab_new_with_buf, "tab: new (with current buf)")
--------------------------------------------------------------------------------------------#[t]ab--

--#[t]erminal---------------------------------------------------------------------------------------
mk({ "i", "n", "t", "v" }, "<C-a>t", uuids.term_cwd, "terminal: toggle (cwd)")
mk({ "i", "n", "t", "v" }, "<M-t>", uuids.term_cwd, "terminal: toggle (cwd)")
mk({ "n", "t" }, "<leader>tT", uuids.term_workspace, "terminal: toggle (workspace)")
mk({ "n", "t" }, "<leader>tt", uuids.term_cwd, "terminal: toggle (cwd)")
---------------------------------------------------------------------------------------#[t]erminal--

--#[t]oggle-----------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<C-a>T", uuids.toggle_theme_variant, "theme: toggle variant")
mk({ "i", "n", "v" }, "<M-T>", uuids.toggle_theme_variant, "theme: toggle variant")
mk({ "n", "v" }, "<leader>tt", uuids.toggle, "toggle")
mk({ "n", "v" }, "<leader>tuf", uuids.toggle_flight, "toggle: flight")
mk({ "n", "v" }, "<leader>tul", uuids.toggle_relativenumber, "toggle: relativenumber")
mk({ "n", "v" }, "<leader>tuT", uuids.toggle_theme_transparency, "toggle: theme transparency")
mk({ "n", "v" }, "<leader>tut", uuids.toggle_theme, "toggle: theme")
mk({ "n", "v" }, "<leader>tuw", uuids.toggle_wrap, "toggle: wrap (temporary)")
-----------------------------------------------------------------------------------------#[t]oggle--

--#[u]x---------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>un", uuids.notification_dismiss_all, "notification: dismiss all")
---------------------------------------------------------------------------------------------#[u]x--

--#[w]in--------------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<C-a><Left>", uuids.win_resize_vertical_minus, "win: resize vertical (minus)")
mk({ "i", "n", "v" }, "<C-a><Down>", uuids.win_resize_horizontal_minus, "win: resize horizontal (minus)")
mk({ "i", "n", "v" }, "<C-a><Up>", uuids.win_resize_horizontal_plus, "win: resize horizontal (plus)")
mk({ "i", "n", "v" }, "<C-a><Right>", uuids.win_resize_vertical_plus, "win: resize vertical (plus)")
mk({ "i", "n", "v" }, "<M-Left>", uuids.win_resize_vertical_minus, "win: resize vertical (minus)")
mk({ "i", "n", "v" }, "<M-Down>", uuids.win_resize_horizontal_minus, "win: resize horizontal (minus)")
mk({ "i", "n", "v" }, "<M-Up>", uuids.win_resize_horizontal_plus, "win: resize horizontal (plus)")
mk({ "i", "n", "v" }, "<M-Right>", uuids.win_resize_vertical_plus, "win: resize vertical (plus)")
mk({ "i", "n", "v" }, "<C-a>i", uuids.win_history_backward, "win: history backward")
mk({ "i", "n", "v" }, "<C-a>o", uuids.win_history_forward, "win: history forward")
mk({ "i", "n", "v" }, "<M-i>", uuids.win_history_backward, "win: history backward")
mk({ "i", "n", "v" }, "<M-o>", uuids.win_history_forward, "win: history forward")
mk({ "i", "n", "t", "v" }, "<C-a>h", uuids.win_focus_left, "win: focus left")
mk({ "i", "n", "t", "v" }, "<C-a>j", uuids.win_focus_bottom, "win: focus bottom")
mk({ "i", "n", "t", "v" }, "<C-a>k", uuids.win_focus_top, "win: focus top")
mk({ "i", "n", "t", "v" }, "<C-a>l", uuids.win_focus_right, "win: focus right")
mk({ "i", "n", "t", "v" }, "<M-h>", uuids.win_focus_left, "win: focus left")
mk({ "i", "n", "t", "v" }, "<M-j>", uuids.win_focus_bottom, "win: focus bottom")
mk({ "i", "n", "t", "v" }, "<M-k>", uuids.win_focus_top, "win: focus top")
mk({ "i", "n", "t", "v" }, "<M-l>", uuids.win_focus_right, "win: focus right")
mk({ "n", "v" }, "<leader>wd", uuids.win_close, "win: close current")
mk({ "n", "v" }, "<leader>wh", uuids.win_history, "win: history")
mk({ "n", "v" }, "<leader>wj", uuids.win_split_horizontal, "win: split horizontal")
mk({ "n", "v" }, "<leader>wl", uuids.win_split_vertical, "win: split vertical")
mk({ "n", "v" }, "<leader>wo", uuids.win_close_others, "win: close others")
mk({ "n", "v" }, "<leader>wp", uuids.win_project, "win: project (with picker)")
mk({ "n", "v" }, "<leader>ws", uuids.win_swap, "win: swap (with picker)")
mk({ "n", "v" }, "<leader>ww", uuids.win_focus, "win: focus (with picker)")
--------------------------------------------------------------------------------------------#[w]in--

--#[x] diagnostic-----------------------------------------------------------------------------------
mk({ "n", "v" }, "[d", uuids.goto_prev_diagnostic, "diagnostic: goto prev")
mk({ "n", "v" }, "]d", uuids.goto_next_diagnostic, "diagnostic: goto next")
mk({ "n", "v" }, "[e", uuids.goto_prev_error, "diagnostic: goto prev error")
mk({ "n", "v" }, "]e", uuids.goto_next_error, "diagnostic: goto next error")
mk({ "n", "v" }, "[q", uuids.goto_prev_quickfix_item, "diagnostic: goto prev quickfix item")
mk({ "n", "v" }, "]q", uuids.goto_next_quickfix_item, "diagnostic: goto next quickfix item")
mk({ "n", "v" }, "[w", uuids.goto_prev_warn, "diagnostic: goto prev warning")
mk({ "n", "v" }, "]w", uuids.goto_next_warn, "diagnostic: goto next warning")
mk({ "n", "v" }, "<leader>xD", "<cmd>Trouble diagnostics toggle<cr>", "diagnostic: open diagnostics (workspace)")
mk(
  { "n", "v" },
  "<leader>xd",
  "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
  "diagnostic: open diagnostics (document)"
)
mk({ "n", "v" }, "<leader>xL", "<cmd>Trouble loclist toggle<cr>", "diagnostic: open location list (Trouble)")
mk({ "n", "v" }, "<leader>xl", uuids.open_line_diagnostic, "diagnostic: open float window")
mk({ "n", "v" }, "<leader>xo", uuids.outline_toggle, "code: toggle outline")
mk({ "n", "v" }, "<leader>xq", "<cmd>Trouble qflist toggle<cr>", "diagnostic: open quickfix list (Trouble)")
-----------------------------------------------------------------------------------#[x] diagnostic--
