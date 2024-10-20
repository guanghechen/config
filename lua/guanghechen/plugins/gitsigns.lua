---@type t.eve.IKeymap[]
local keymaps = {
  {
    modes = { "n" },
    key = "[h",
    callback = function()
      if vim.wo.diff then
        vim.cmd.normal({ "[c", bang = true })
      else
        require("gitsigns").nav_hunk("prev")
      end
    end,
    desc = "git: goto prev hunk",
  },
  {
    modes = { "n" },
    key = "]h",
    callback = function()
      if vim.wo.diff then
        vim.cmd.normal({ "]c", bang = true })
      else
        require("gitsigns").nav_hunk("next")
      end
    end,
    desc = "git: goto next hunk",
  },
  {
    modes = { "n" },
    key = "<leader>gb",
    callback = function()
      require("gitsigns").blame_line({ full = true })
    end,
    desc = "git: blame line",
  },
  {
    modes = { "n" },
    key = "<leader>gd",
    callback = function()
      require("gitsigns").diffthis("~")
    end,
    desc = "git: diff current file",
  },
  {
    modes = { "n" },
    key = "<leader>gp",
    callback = function()
      require("gitsigns").preview_hunk_inline()
    end,
    desc = "git: preview hunk inline",
  },
  {
    modes = { "n" },
    key = "<leader>gu",
    callback = function()
      require("gitsigns").undo_stage_hunk()
    end,
    desc = "git: undo stage hunk",
  },
}

-- git signs highlights text that has changed since the list
-- git commit, and also lets you interactively stage & unstage
-- hunks in a commit.
return {
  name = "gitsigns.nvim",
  event = { "BufReadPre", "BufWritePost", "VeryLazy" },
  opts = {
    current_line_blame = true,
    current_line_blame_formatter = "    <author>, <author_time:%Y-%m-%d %H:%M:%S> - <summary>",
    linehl = false,
    max_file_length = 3000, -- Disable if file is longer than this (in lines)
    numhl = true,
    signcolumn = true,
    signs_staged_enable = true,
    word_diff = false,
    signs = {
      add = { text = "▎" },
      change = { text = "▎" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "󱕖" },
      untracked = { text = "┆" },
    },
    signs_staged = {
      add = { text = "▎" },
      change = { text = "▎" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "󱕖" },
      untracked = { text = "┆" },
    },
    on_attach = function(bufnr)
      eve.nvim.bindkeys(keymaps, { buffer = bufnr, noremap = true, silent = true })
    end,
  },
}
