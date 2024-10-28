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
mk({ "n" }, "<esc>", "<cmd>noh<cr><esc>", "remove search highlights") -- Clear search with <esc>
mk({ "t" }, "<esc><esc>", "<C-\\><C-n>", "terminal: exit terminal mode") -- Exit terminal

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
mk({ "n", "v" }, "<leader>2", uuids.search_files, "search: files")
------------------------------------------------------------------------------------------#enhance--

--#[b]uf--------------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<C-a>s", uuids.buf_save, "buf: save changes")
mk({ "i", "n", "v" }, "<M-s>", uuids.buf_save, "buf: save changes")
mk({ "n", "v" }, "[b", uuids.buf_focus_left, "buf: focus left")
mk({ "n", "v" }, "]b", uuids.buf_focus_right, "buf: focus right")
mk({ "n", "v" }, "{b", uuids.buf_swap_left, "buf: swap left")
mk({ "n", "v" }, "}b", uuids.buf_swap_right, "buf: swap right")
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
--
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

--#[s]earch-----------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<C-a>f", uuids.search_files_buffer, "search: files (buffer)")
mk({ "i", "n", "v" }, "<M-f>", uuids.search_files_buffer, "search: files (buffer)")
mk({ "n", "v" }, "<leader>ss", uuids.search_files, "search: files")
mk({ "n", "v" }, "<leader>sb", uuids.search_files_buffer, "search: files (buffer)")
mk({ "n", "v" }, "<leader>sc", uuids.search_files_cwd, "search: files (cwd)")
mk({ "n", "v" }, "<leader>sd", uuids.search_files_directory, "search: files (directory)")
mk({ "n", "v" }, "<leader>sw", uuids.search_files_workspace, "search: files (workspace)")
-----------------------------------------------------------------------------------------#[s]earch--

--#[s]elect-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>st", uuids.select_theme, "select: theme")
-----------------------------------------------------------------------------------------#[s]elect--

--#[t]erminal---------------------------------------------------------------------------------------
mk({ "i", "n", "t", "v" }, "<C-a>t", uuids.term_cwd, "terminal: toggle (cwd)")
mk({ "i", "n", "t", "v" }, "<M-t>", uuids.term_cwd, "terminal: toggle (cwd)")
mk({ "n", "t" }, "<leader>tT", uuids.term_workspace, "terminal: toggle (workspace)")
mk({ "n", "t" }, "<leader>tt", uuids.term_cwd, "terminal: toggle (cwd)")
---------------------------------------------------------------------------------------#[t]erminal--
