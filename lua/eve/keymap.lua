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
mk({ "n", "t", "v" }, "<leader>`", uuids.resume)
mk({ "n", "v" }, "<leader>2", uuids.search_files)
------------------------------------------------------------------------------------------#enhance--

--#[c]opy-------------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<C-a>C", uuids.copy_current_filepath)
mk({ "i", "n", "v" }, "<M-C>", uuids.copy_current_filepath)
mk({ "i", "n" }, "<C-a>c", uuids.copy_current_filepath_relative)
mk({ "i", "n" }, "<M-c>", uuids.copy_current_filepath_relative)
-----------------------------------------------------------------------------------------#[c]opy----

--#[d]ebug------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>dd", uuids.debug_inspect)
mk({ "n", "v" }, "<leader>dI", uuids.debug_inspect_tree)
mk({ "n", "v" }, "<leader>di", uuids.debug_inspect_pos)
mk({ "n", "v" }, "<leader>ds", uuids.debug_inspect_state)
------------------------------------------------------------------------------------------#[d]ebug--

--#[f]ind-------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader><leader>", uuids.find_files)
mk({ "n", "v" }, "<leader>fb", uuids.find_buffers)
mk({ "n", "v" }, "<leader>fc", uuids.find_files_cwd)
mk({ "n", "v" }, "<leader>fe", uuids.find_explorer)
mk({ "n", "v" }, "<leader>fd", uuids.find_files_directory)
mk({ "n", "v" }, "<leader>ff", uuids.find_files)
mk({ "n", "v" }, "<leader>fg", uuids.find_git_not_committed)
mk({ "n", "v" }, "<leader>fh", uuids.find_highlights)
mk({ "n", "v" }, "<leader>fp", uuids.find_pinned_files)
mk({ "n", "v" }, "<leader>fv", uuids.find_vim_options)
mk({ "n", "v" }, "<leader>fw", uuids.find_files_workspace)
-------------------------------------------------------------------------------------------#[f]ind--

--#[q]uit-------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>qq", "<cmd>qa<cr>", "quit: quit all")
-------------------------------------------------------------------------------------------#[q]uit--

--#[r]efresh----------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<C-a>r", uuids.refresh_all)
mk({ "i", "n", "v" }, "<M-r>", uuids.refresh_all)
---------------------------------------------------------------------------------------#[r]efresh---

--#[r]eplace----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>rr", uuids.replace_files)
mk({ "n", "v" }, "<leader>rb", uuids.replace_files_buffer)
mk({ "n", "v" }, "<leader>rd", uuids.replace_files_directory)
mk({ "n", "v" }, "<leader>rc", uuids.replace_files_cwd)
mk({ "n", "v" }, "<leader>rw", uuids.replace_files_workspace)
---------------------------------------------------------------------------------------#[r]eplace---

--#[s]earch-----------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<C-a>f", uuids.search_files_buffer)
mk({ "i", "n", "v" }, "<M-f>", uuids.search_files_buffer)
mk({ "n", "v" }, "<leader>ss", uuids.search_files)
mk({ "n", "v" }, "<leader>sb", uuids.search_files_buffer)
mk({ "n", "v" }, "<leader>sc", uuids.search_files_cwd)
mk({ "n", "v" }, "<leader>sd", uuids.search_files_directory)
mk({ "n", "v" }, "<leader>sw", uuids.search_files_workspace)
-----------------------------------------------------------------------------------------#[s]earch--

--#[s]elect-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>st", uuids.select_theme)
-----------------------------------------------------------------------------------------#[s]elect--
