return {
  name = "diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  opts = function()
    local actions = require("diffview.actions")

    return {
      default_args = { -- Default args prepended to the arg-list for the listed commands
        DiffviewOpen = {
          "--imply-local",
        },
        DiffviewFileHistory = {
          "--right-only",
        },
      },
      diff_binaries = false,
      enhanced_diff_hl = false, -- Set up hihglights in the hooks instead
      file_history_panel = {
        log_options = {
          git = {
            single_file = {
              diff_merges = "first-parent",
              follow = true,
            },
            multi_file = {
              diff_merges = "first-parent",
            },
          },
        },
        win_config = {
          position = "left",
          height = vim.o.lines,
        },
      },
      file_panel = {
        listing_style = "tree",            -- One of 'list' or 'tree'
        tree_options = {                   -- Only applies when listing_style is 'tree'
          flatten_dirs = true,             -- Flatten dirs that only contain one single dir
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
      ---https://github.com/sindrets/dotfiles/blob/40e20f7f68cf55f175d94a92b31a64d66ed3c059/.config/nvim/lua/user/plugins/diffview.lua#L71
      ---https://github.com/sindrets/diffview.nvim/pull/258#issuecomment-1408689220
      hooks = {
        diff_buf_read = function()
          vim.opt_local.wrap = false
          vim.opt_local.list = false
          vim.opt_local.foldlevel = 99
          vim.opt_local.foldmethod = "manual"
          vim.opt_local.colorcolumn = ""
        end,
        ---@diagnostic disable-next-line: unused-local
        diff_buf_win_enter = function(bufnr, winid, ctx)
          -- Highlight 'DiffChange' as 'DiffDelete' on the left, and 'DiffAdd' on the right.
          if ctx.layout_name:match("^diff2") then
            if ctx.symbol == "a" then
              vim.opt_local.winhl = table.concat({
                "DiffAdd:f_diff_add_left",
                "DiffDelete:f_diff_del_left",
                "DiffChange:f_diff_mod_left",
                "DiffText:f_diff_word_left",
              }, ",")
            elseif ctx.symbol == "b" then
              vim.opt_local.winhl = table.concat({
                "DiffAdd:f_diff_add_right",
                "DiffDelete:f_diff_del_right",
                "DiffChange:f_diff_mod_right",
                "DiffText:f_diff_word_right",
              }, ",")
            end
          end
        end,
      },
      icons = { -- Only applies when use_icons is true.
        folder_closed = eve.icons.ui.Folder,
        folder_open = eve.icons.ui.FolderOpen,
      },
      signs = {
        fold_closed = eve.icons.ui.ArrowClosed,
        fold_open = eve.icons.ui.ArrowOpen,
        done = eve.icons.ui.Accepted,
      },
      keymaps = {
        disable_defaults = true, -- Disable the default keymaps
        view = {
          -- The `view` bindings are active in the diff buffers, only when the current tabpage is a Diffview.
          { "n", "<tab>",   actions.select_next_entry, { desc = "Open the diff for the next file" } },
          { "n", "<S-tab>", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
          { "n", "gf",      actions.goto_file_edit,    { desc = "Open the file in the previous tabpage" } },
          { "n", "g<C-x>",  actions.cycle_layout,      { desc = "Cycle through available layouts." } },
          { "n", "[x",      actions.prev_conflict,     { desc = "In the merge-tool: jump to the previous conflict" } },
          { "n", "]x",      actions.next_conflict,     { desc = "In the merge-tool: jump to the next conflict" } },
          {
            "n",
            "<leader>gco",
            actions.conflict_choose("ours"),
            { desc = "Choose the OURS version of a conflict" },
          },
          {
            "n",
            "<leader>gct",
            actions.conflict_choose("theirs"),
            { desc = "Choose the THEIRS version of a conflict" },
          },
          {
            "n",
            "<leader>gcb",
            actions.conflict_choose("base"),
            { desc = "Choose the BASE version of a conflict" },
          },
          {
            "n",
            "<leader>gca",
            actions.conflict_choose("all"),
            { desc = "Choose all the versions of a conflict" },
          },
          { "n", "dx", actions.conflict_choose("none"), { desc = "Delete the conflict region" } },
          {
            "n",
            "<leader>gcO",
            actions.conflict_choose_all("ours"),
            { desc = "Choose the OURS version of a conflict for the whole file" },
          },
          {
            "n",
            "<leader>gcT",
            actions.conflict_choose_all("theirs"),
            { desc = "Choose the THEIRS version of a conflict for the whole file" },
          },
          {
            "n",
            "<leader>gcB",
            actions.conflict_choose_all("base"),
            { desc = "Choose the BASE version of a conflict for the whole file" },
          },
          {
            "n",
            "<leader>gcA",
            actions.conflict_choose_all("all"),
            { desc = "Choose all the versions of a conflict for the whole file" },
          },
          {
            "n",
            "gcD",
            actions.conflict_choose_all("none"),
            { desc = "Delete the conflict region for the whole file" },
          },
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
            { "n",                                                            "x" },
            "2do",
            actions.diffget("ours"),
            { desc = "Obtain the diff hunk from the OURS version of the file" },
          },
          {
            { "n",                                                              "x" },
            "3do",
            actions.diffget("theirs"),
            { desc = "Obtain the diff hunk from the THEIRS version of the file" },
          },
          { "n", "g?", actions.help({ "view", "diff3" }), { desc = "Open the help panel" } },
        },
        diff4 = {
          -- Mappings in 4-way diff layouts
          {
            { "n",                                                            "x" },
            "1do",
            actions.diffget("base"),
            { desc = "Obtain the diff hunk from the BASE version of the file" },
          },
          {
            { "n",                                                            "x" },
            "2do",
            actions.diffget("ours"),
            { desc = "Obtain the diff hunk from the OURS version of the file" },
          },
          {
            { "n",                                                              "x" },
            "3do",
            actions.diffget("theirs"),
            { desc = "Obtain the diff hunk from the THEIRS version of the file" },
          },
          { "n", "g?", actions.help({ "view", "diff4" }), { desc = "Open the help panel" } },
        },
        file_panel = {
          { "n", "k",             actions.prev_entry,          { desc = "Bring the cursor to the previous file entry" } },
          { "n", "j",             actions.next_entry,          { desc = "Bring the cursor to the next file entry" } },
          { "n", "<up>",          actions.prev_entry,          { desc = "Bring the cursor to the previous file entry" } },
          { "n", "<down>",        actions.next_entry,          { desc = "Bring the cursor to the next file entry" } },
          { "n", "<cr>",          actions.select_entry,        { desc = "Open the diff for the selected entry" } },
          { "n", "<LeftRelease>", actions.select_entry,        { desc = "Open the diff for the selected entry" } },
          { "n", "S",             actions.toggle_stage_entry,  { desc = "Stage / unstage the selected entry" } },
          { "n", "X",             actions.restore_entry,       { desc = "Restore entry to the state on the left side" } },
          { "n", "L",             actions.open_commit_log,     { desc = "Open the commit log panel" } },
          { "n", "zo",            actions.open_fold,           { desc = "Expand fold" } },
          { "n", "zc",            actions.close_fold,          { desc = "Collapse fold" } },
          { "n", "zO",            actions.open_all_folds,      { desc = "Expand all folds" } },
          { "n", "zC",            actions.close_all_folds,     { desc = "Collapse all folds" } },
          { "n", "<C-b>",         actions.scroll_view(-0.25),  { desc = "Scroll the view up" } },
          { "n", "<C-f>",         actions.scroll_view(0.25),   { desc = "Scroll the view down" } },
          { "n", "<tab>",         actions.select_next_entry,   { desc = "Open the diff for the next file" } },
          { "n", "<S-tab>",       actions.select_prev_entry,   { desc = "Open the diff for the previous file" } },
          { "n", "gf",            actions.goto_file_edit,      { desc = "Open the file in the previous tabpage" } },
          { "n", "i",             actions.listing_style,       { desc = "Toggle between 'list' and 'tree' views" } },
          { "n", "f",             actions.toggle_flatten_dirs, { desc = "Flatten empty subdirectories in tree listing style" } },
          { "n", "R",             actions.refresh_files,       { desc = "Update stats and entries in the file list" } },
          { "n", "<leader>ee",    actions.focus_files,         { desc = "Bring focus to the file panel" } },
          { "n", "<leader>er",    actions.focus_files,         { desc = "Bring focus to the file panel" } },
          { "n", "<leader>et",    actions.toggle_files,        { desc = "Toggle the file panel" } },
          { "n", "g<C-x>",        actions.cycle_layout,        { desc = "Cycle available layouts" } },
          { "n", "[x",            actions.prev_conflict,       { desc = "Go to the previous conflict" } },
          { "n", "]x",            actions.next_conflict,       { desc = "Go to the next conflict" } },
          { "n", "g?",            actions.help("file_panel"),  { desc = "Open the help panel" } },
          {
            "n",
            "<leader>gcO",
            actions.conflict_choose_all("ours"),
            { desc = "Choose the OURS version of a conflict for the whole file" },
          },
          {
            "n",
            "<leader>gcT",
            actions.conflict_choose_all("theirs"),
            { desc = "Choose the THEIRS version of a conflict for the whole file" },
          },
          {
            "n",
            "<leader>gcB",
            actions.conflict_choose_all("base"),
            { desc = "Choose the BASE version of a conflict for the whole file" },
          },
          {
            "n",
            "<leader>gcA",
            actions.conflict_choose_all("all"),
            { desc = "Choose all the versions of a conflict for the whole file" },
          },
          {
            "n",
            "<leader>gcD",
            actions.conflict_choose_all("none"),
            { desc = "Delete the conflict region for the whole file" },
          },
        },
        file_history_panel = {
          { "n", "y",             actions.copy_hash,                  { desc = "Copy the commit hash of the entry under the cursor" } },
          { "n", "L",             actions.open_commit_log,            { desc = "Show commit details" } },
          { "n", "X",             actions.restore_entry,              { desc = "Restore file to the state from the selected entry" } },
          { "n", "zo",            actions.open_fold,                  { desc = "Expand fold" } },
          { "n", "zc",            actions.close_fold,                 { desc = "Collapse fold" } },
          { "n", "zO",            actions.open_all_folds,             { desc = "Expand all folds" } },
          { "n", "zC",            actions.close_all_folds,            { desc = "Collapse all folds" } },
          { "n", "k",             actions.prev_entry,                 { desc = "Bring the cursor to the previous file entry" } },
          { "n", "j",             actions.next_entry,                 { desc = "Bring the cursor to the next file entry" } },
          { "n", "<up>",          actions.prev_entry,                 { desc = "Bring the cursor to the previous file entry" } },
          { "n", "<down>",        actions.next_entry,                 { desc = "Bring the cursor to the next file entry" } },
          { "n", "<cr>",          actions.select_entry,               { desc = "Open the diff for the selected entry" } },
          { "n", "<C-a><cr>",     actions.open_in_diffview,           { desc = "Open the entry under the cursor in a diffview" } },
          { "n", "<tab>",         actions.select_next_entry,          { desc = "Open the diff for the next file" } },
          { "n", "<S-tab>",       actions.select_prev_entry,          { desc = "Open the diff for the previous file" } },
          { "n", "<LeftRelease>", actions.select_entry,               { desc = "Open the diff for the selected entry" } },
          { "n", "<C-b>",         actions.scroll_view(-0.25),         { desc = "Scroll the view up" } },
          { "n", "<C-f>",         actions.scroll_view(0.25),          { desc = "Scroll the view down" } },
          { "n", "gf",            actions.goto_file_edit,             { desc = "Open the file in the previous tabpage" } },
          { "n", "g?",            actions.help("file_history_panel"), { desc = "Open the help panel" } },
          { "n", "g!",            actions.options,                    { desc = "Open the option panel" } },
        },
        option_panel = {
          { "n", "<tab>", actions.select_entry,         { desc = "Change the current option" } },
          { "n", "q",     actions.close,                { desc = "Close the panel" } },
          { "n", "g?",    actions.help("option_panel"), { desc = "Open the help panel" } },
        },
        help_panel = {
          { "n", "q",     actions.close, { desc = "Close help menu" } },
          { "n", "<esc>", actions.close, { desc = "Close help menu" } },
        },
      },
    }
  end,
}
