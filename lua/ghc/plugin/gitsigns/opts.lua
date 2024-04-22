local opts = {
  current_line_blame = true,
  signs = {
    add = { text = "│" },
    change = { text = "│" },
    delete = { text = "󰍵" },
    topdelete = { text = "‾" },
    changedelete = { text = "~" },
    untracked = { text = "│" },
  },
  on_attach = function(buffer)
    local gs = package.loaded.gitsigns

    vim.keymap.set("n", "]h", gs.next_hunk, { buffer = buffer, desc = "Next Hunk" })
    vim.keymap.set("n", "[h", gs.prev_hunk, { buffer = buffer, desc = "Prev Hunk" })
    vim.keymap.set({ "n", "v" }, "<leader>ghs", ":Gitsigns stage_hunk<cr>", { buffer = buffer, desc = "Stage Hunk" })
    vim.keymap.set({ "n", "v" }, "<leader>ghr", ":Gitsigns reset_hunk<cr>", { buffer = buffer, desc = "Reset Hunk" })
    vim.keymap.set("n", "<leader>ghS", gs.stage_buffer, { buffer = buffer, desc = "Stage Buffer" })
    vim.keymap.set("n", "<leader>ghu", gs.undo_stage_hunk, { buffer = buffer, desc = "Undo Stage Hunk" })
    vim.keymap.set("n", "<leader>ghR", gs.reset_buffer, { buffer = buffer, desc = "Reset Buffer" })
    vim.keymap.set("n", "<leader>ghp", gs.preview_hunk_inline, { buffer = buffer, desc = "Preview Hunk Inline" })
    vim.keymap.set("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, { buffer = buffer, desc = "Blame Line" })
    vim.keymap.set("n", "<leader>ghd", gs.diffthis, { buffer = buffer, desc = "Diff This" })
    vim.keymap.set("n", "<leader>ghD", function() gs.diffthis("~") end, { buffer = buffer, desc = "Diff This ~" })
    vim.keymap.set({ "o", "x" }, "<leader>ghi", ":<C-U>Gitsigns select_hunk<cr>", { buffer = buffer, desc = "GitSigns Select Hunk"})
  end,
}

return opts
