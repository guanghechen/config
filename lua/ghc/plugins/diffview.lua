---@see https://github.com/sindrets/diffview.nvim/tree/4516612fe98ff56ae0415a259ff6361a89419b0a

return {
  name = "diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  opts = function()
    local actions = require("diffview.actions")

    return {
      default_args = {
        DiffviewOpen = {
          "--imply-local",
        },
        DiffviewFileHistory = {
          "--right-only",
        },
      },
      diff_binaries = false,
      enhanced_diff_hl = false,
      view = {
        default = {
          layout = "diff2_horizontal",
          disable_diagnostics = false,
          winbar_info = false,
        },
        merge_tool = {
          layout = "diff3_horizontal",
          disable_diagnostics = true,
          winbar_info = true,
        },
        file_history = {
          layout = "diff2_horizontal",
          disable_diagnostics = false,
          winbar_info = false,
        },
      },
      file_history_panel = {
        log_options = {
          git = {
            single_file = {
              diff_merges = "combined",
              follow = true,
            },
            multi_file = {
              diff_merges = "first-parent",
            },
          },
        },
        win_config = {
          position = "top",
          height = 20,
          win_opts = {},
        },
      },
      commit_log_panel = {
        win_config = {
          win_opts = {},
        },
      },
      file_panel = {
        listing_style = "tree", -- One of 'list' or 'tree'
        tree_options = { -- Only applies when listing_style is 'tree'
          flatten_dirs = true, -- Flatten dirs that only contain one single dir
          folder_statuses = "only_folded", -- One of 'never', 'only_folded' or 'always'.
        },
        win_config = function()
          local editor_width = vim.o.columns
          return {
            position = "left",
            width = editor_width >= 247 and 45 or 35,
          }
        end,
      },
      hooks = {
        diff_buf_win_enter = function(_, _, ctx)
          if eve.context.flight.gitdiff_expand_all:snapshot() then
            vim.opt_local.foldlevel = 99
          end

          vim.opt_local.list = true
          vim.opt_local.wrap = false

          if ctx.layout_name:match("^diff[234]") then
            local is_left = ctx.symbol == "a" or ctx.symbol == "d"
            local side = is_left and "Left" or "Right"
            vim.opt_local.winhl = table.concat({
              "DiffAdd:DiffAdd" .. side,
              "DiffDelete:DiffDel" .. side,
              "DiffChange:DiffMod" .. side,
              "DiffText:DiffWord" .. side,
            }, ",")
          end
        end,
        view_opened = function()
          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          vim.schedule(function()
            eve.tab.resolve(tabnr, true)
          end)
        end,
      },
      icons = { -- Only applies when use_icons is true.
        folder_closed = eve.icon.filetype.Folder,
        folder_open = eve.icon.filetype.FolderOpen,
      },
      signs = {
        fold_closed = eve.icon.ui.ArrowClosed,
        fold_open = eve.icon.ui.ArrowOpen,
        done = eve.icon.ui.Accepted,
      },
      keymaps = {
        disable_defaults = true, -- Disable the default keymaps
        view = {
          { "n", "<tab>", actions.select_next_entry, { desc = "Open the diff for the next file" } },
          { "n", "<S-tab>", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
          { "n", "[F", actions.select_first_entry, { desc = "Open the diff for the first file" } },
          { "n", "]F", actions.select_last_entry, { desc = "Open the diff for the last file" } },
          { "n", "gf", actions.goto_file_edit, { desc = "Open the file in the previous tabpage" } },
          { "n", "<C-w><C-f>", actions.goto_file_split, { desc = "Open the file in a new split" } },
          { "n", "<C-w>gf", actions.goto_file_tab, { desc = "Open the file in a new tabpage" } },
          { "n", "g<C-x>", actions.cycle_layout, { desc = "Cycle through available layouts" } },
          { "n", "[x", actions.prev_conflict, { desc = "In the merge-tool: jump to the previous conflict" } },
          { "n", "]x", actions.next_conflict, { desc = "In the merge-tool: jump to the next conflict" } },
          { "n", "gS", actions.toggle_stage_entry, { desc = "Stage / unstage the selected hunk" } },
          { "n", "<leader>co", actions.conflict_choose("ours"), { desc = "Choose the OURS version of a conflict" } },
          { "n", "<leader>ct", actions.conflict_choose("theirs"), { desc = "Choose the THEIRS version of a conflict" } },
          { "n", "<leader>cb", actions.conflict_choose("base"), { desc = "Choose the BASE version of a conflict" } },
          { "n", "<leader>ca", actions.conflict_choose("all"), { desc = "Choose all the versions of a conflict" } },
          { "n", "dx", actions.conflict_choose("none"), { desc = "Delete the conflict region" } },
          { "n", "<leader>cO", actions.conflict_choose_all("ours"), { desc = "Choose OURS for the whole file" } },
          { "n", "<leader>cT", actions.conflict_choose_all("theirs"), { desc = "Choose THEIRS for the whole file" } },
          { "n", "<leader>cB", actions.conflict_choose_all("base"), { desc = "Choose BASE for the whole file" } },
          { "n", "<leader>cA", actions.conflict_choose_all("all"), { desc = "Choose all versions for the whole file" } },
          { "n", "dX", actions.conflict_choose_all("none"), { desc = "Delete conflict region for the whole file" } },
          { "n", "g?", actions.help("view"), { desc = "Open the help panel" } },
          unpack(actions.compat.fold_cmds),
        },
        diff1 = {
          -- Mappings in single window diff layouts
          { "n", "g?", actions.help({ "view", "diff1" }), { desc = "Open the help panel" } },
        },
        diff2 = {
          -- Mappings in 2-way diff layouts
          { "n", "g?", actions.help({ "view", "diff2" }), { desc = "Open the help panel" } },
        },
        diff3 = {
          -- Mappings in 3-way diff layouts
          {
            { "n", "x" },
            "2do",
            actions.diffget("ours"),
            { desc = "Obtain the diff hunk from the OURS version of the file" },
          },
          {
            { "n", "x" },
            "3do",
            actions.diffget("theirs"),
            { desc = "Obtain the diff hunk from the THEIRS version of the file" },
          },
          { "n", "g?", actions.help({ "view", "diff3" }), { desc = "Open the help panel" } },
        },
        diff4 = {
          -- Mappings in 4-way diff layouts
          {
            { "n", "x" },
            "1do",
            actions.diffget("base"),
            { desc = "Obtain the diff hunk from the BASE version of the file" },
          },
          {
            { "n", "x" },
            "2do",
            actions.diffget("ours"),
            { desc = "Obtain the diff hunk from the OURS version of the file" },
          },
          {
            { "n", "x" },
            "3do",
            actions.diffget("theirs"),
            { desc = "Obtain the diff hunk from the THEIRS version of the file" },
          },
          { "n", "g?", actions.help({ "view", "diff4" }), { desc = "Open the help panel" } },
        },
        file_panel = {
          { "n", "j", actions.next_entry, { desc = "Bring the cursor to the next file entry" } },
          { "n", "k", actions.prev_entry, { desc = "Bring the cursor to the previous file entry" } },
          { "n", "<down>", actions.next_entry, { desc = "Bring the cursor to the next file entry" } },
          { "n", "<up>", actions.prev_entry, { desc = "Bring the cursor to the previous file entry" } },
          { "n", "<cr>", actions.select_entry, { desc = "Open the diff for the selected entry" } },
          { "n", "o", actions.select_entry, { desc = "Open the diff for the selected entry" } },
          { "n", "l", actions.select_entry, { desc = "Open the diff for the selected entry" } },
          { "n", "<2-LeftMouse>", actions.select_entry, { desc = "diffview_ignore" } },
          { "n", "-", actions.toggle_stage_entry, { desc = "Stage / unstage the selected entry" } },
          { "n", "s", actions.toggle_stage_entry, { desc = "Stage / unstage the selected entry" } },
          { "n", "S", actions.stage_all, { desc = "Stage all entries" } },
          { "n", "U", actions.unstage_all, { desc = "Unstage all entries" } },
          { "n", "X", actions.restore_entry, { desc = "Restore entry to the state on the left side" } },
          { "n", "L", actions.open_commit_log, { desc = "Open the commit log panel" } },
          { "n", "zo", actions.open_fold, { desc = "Expand fold" } },
          { "n", "h", actions.close_fold, { desc = "Collapse fold" } },
          { "n", "zc", actions.close_fold, { desc = "Collapse fold" } },
          { "n", "za", actions.toggle_fold, { desc = "Toggle fold" } },
          { "n", "zR", actions.open_all_folds, { desc = "Expand all folds" } },
          { "n", "zM", actions.close_all_folds, { desc = "Collapse all folds" } },
          { "n", "<C-b>", actions.scroll_view(-0.25), { desc = "Scroll the view up" } },
          { "n", "<C-f>", actions.scroll_view(0.25), { desc = "Scroll the view down" } },
          { "n", "<tab>", actions.select_next_entry, { desc = "Open the diff for the next file" } },
          { "n", "<S-tab>", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
          { "n", "[F", actions.select_first_entry, { desc = "Open the diff for the first file" } },
          { "n", "]F", actions.select_last_entry, { desc = "Open the diff for the last file" } },
          { "n", "gf", actions.goto_file_edit, { desc = "Open the file in the previous tabpage" } },
          { "n", "<C-w><C-f>", actions.goto_file_split, { desc = "Open the file in a new split" } },
          { "n", "<C-w>gf", actions.goto_file_tab, { desc = "Open the file in a new tabpage" } },
          { "n", "i", actions.listing_style, { desc = "Toggle between 'list' and 'tree' views" } },
          { "n", "f", actions.toggle_flatten_dirs, { desc = "Flatten empty subdirectories" } },
          { "n", "R", actions.refresh_files, { desc = "Update stats and entries in the file list" } },
          { "n", "g<C-x>", actions.cycle_layout, { desc = "Cycle available layouts" } },
          { "n", "[x", actions.prev_conflict, { desc = "Go to the previous conflict" } },
          { "n", "]x", actions.next_conflict, { desc = "Go to the next conflict" } },
          { "n", "g?", actions.help("file_panel"), { desc = "Open the help panel" } },
          { "n", "<leader>cO", actions.conflict_choose_all("ours"), { desc = "Choose OURS for the whole file" } },
          { "n", "<leader>cT", actions.conflict_choose_all("theirs"), { desc = "Choose THEIRS for the whole file" } },
          { "n", "<leader>cB", actions.conflict_choose_all("base"), { desc = "Choose BASE for the whole file" } },
          { "n", "<leader>cA", actions.conflict_choose_all("all"), { desc = "Choose all versions for the whole file" } },
          { "n", "dX", actions.conflict_choose_all("none"), { desc = "Delete conflict region for the whole file" } },
        },
        file_history_panel = {
          { "n", "y", actions.copy_hash, { desc = "Copy the commit hash of the entry under the cursor" } },
          { "n", "L", actions.open_commit_log, { desc = "Show commit details" } },
          { "n", "X", actions.restore_entry, { desc = "Restore file to the state from the selected entry" } },
          { "n", "zo", actions.open_fold, { desc = "Expand fold" } },
          { "n", "h", actions.close_fold, { desc = "Collapse fold" } },
          { "n", "zc", actions.close_fold, { desc = "Collapse fold" } },
          { "n", "za", actions.toggle_fold, { desc = "Toggle fold" } },
          { "n", "zR", actions.open_all_folds, { desc = "Expand all folds" } },
          { "n", "zM", actions.close_all_folds, { desc = "Collapse all folds" } },
          { "n", "j", actions.next_entry, { desc = "Bring the cursor to the next file entry" } },
          { "n", "k", actions.prev_entry, { desc = "Bring the cursor to the previous file entry" } },
          { "n", "<down>", actions.next_entry, { desc = "Bring the cursor to the next file entry" } },
          { "n", "<up>", actions.prev_entry, { desc = "Bring the cursor to the previous file entry" } },
          { "n", "<cr>", actions.select_entry, { desc = "Open the diff for the selected entry" } },
          { "n", "o", actions.select_entry, { desc = "Open the diff for the selected entry" } },
          { "n", "l", actions.select_entry, { desc = "Open the diff for the selected entry" } },
          { "n", "<2-LeftMouse>", actions.select_entry, { desc = "diffview_ignore" } },
          { "n", "<C-A-d>", actions.open_in_diffview, { desc = "Open the entry under the cursor in a diffview" } },
          { "n", "<tab>", actions.select_next_entry, { desc = "Open the diff for the next file" } },
          { "n", "<S-tab>", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
          { "n", "[F", actions.select_first_entry, { desc = "Open the diff for the first file" } },
          { "n", "]F", actions.select_last_entry, { desc = "Open the diff for the last file" } },
          { "n", "<C-b>", actions.scroll_view(-0.25), { desc = "Scroll the view up" } },
          { "n", "<C-f>", actions.scroll_view(0.25), { desc = "Scroll the view down" } },
          { "n", "gf", actions.goto_file_edit, { desc = "Open the file in the previous tabpage" } },
          { "n", "<C-w><C-f>", actions.goto_file_split, { desc = "Open the file in a new split" } },
          { "n", "<C-w>gf", actions.goto_file_tab, { desc = "Open the file in a new tabpage" } },
          { "n", "g<C-x>", actions.cycle_layout, { desc = "Cycle available layouts" } },
          { "n", "g?", actions.help("file_history_panel"), { desc = "Open the help panel" } },
          { "n", "g!", actions.options, { desc = "Open the option panel" } },
        },
        option_panel = {
          { "n", "<tab>", actions.select_entry, { desc = "Change the current option" } },
          { "n", "q", actions.close, { desc = "Close the panel" } },
          { "n", "g?", actions.help("option_panel"), { desc = "Open the help panel" } },
        },
        help_panel = {
          { "n", "q", actions.close, { desc = "Close help menu" } },
          { "n", "<esc>", actions.close, { desc = "Close help menu" } },
        },
      },
    }
  end,
  config = function(_, opts)
    require("fml.dressing.plugin").mock_web_devicons()

    require("diffview").setup(opts)
  end,
}
