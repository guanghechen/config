---@type t.eve.IKeymap[]
local keymaps = {
  {
    modes = { "n" },
    key = "[C",
    desc = "git: goto first hunk",
    callback = function()
      require("gitsigns").nav_hunk("first")
    end,
  },
  {
    modes = { "n" },
    key = "]C",
    desc = "git: goto last hunk",
    callback = function()
      require("gitsigns").nav_hunk("last")
    end,
  },
  {
    modes = { "n" },
    key = "[c",
    desc = "git: goto prev hunk",
    callback = function()
      if vim.wo.diff then
        vim.cmd.normal({ "[c", bang = true })
      else
        require("gitsigns").nav_hunk("prev")
      end
    end,
  },
  {
    modes = { "n" },
    key = "]c",
    desc = "git: goto next hunk",
    callback = function()
      if vim.wo.diff then
        vim.cmd.normal({ "]c", bang = true })
      else
        require("gitsigns").nav_hunk("next")
      end
    end,
  },
  {
    modes = { "n" },
    key = "<leader>gb",
    desc = "git: blame line",
    callback = function()
      require("gitsigns").blame_line({ full = true })
    end,
  },
  {
    modes = { "n" },
    key = "<leader>ghd",
    desc = "git: diff current file",
    callback = function()
      require("gitsigns").diffthis("~")
    end,
  },
  {
    modes = { "n", "v" },
    key = "<leader>ghp",
    desc = "git: preview hunk inline",
    callback = function()
      require("gitsigns").preview_hunk()
    end,
  },
  {
    modes = { "n", "v" },
    key = "<leader>ghr",
    desc = "git: reset hunk",
    callback = function()
      require("gitsigns").reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end,
  },
  {
    modes = { "n", "v" },
    key = "<leader>ghs",
    desc = "git: stage hunk",
    callback = function()
      require("gitsigns").stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end,
  },
  {
    modes = { "n", "v" },
    key = "<leader>ghu",
    desc = "git: undo stage hunk",
    callback = function()
      require("gitsigns").undo_stage_hunk()
    end,
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

      vim.keymap.set({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", {
        buffer = bufnr,
        noremap = true,
        silent = true,
        desc = "git: select hunk",
      })
    end,
  },
}
