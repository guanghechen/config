local function goto_prev_hunk()
  if vim.wo.diff then
    vim.cmd.normal({ "[c", bang = true })
  else
    require("gitsigns").nav_hunk("prev")
  end
end
local function goto_next_hunk()
  if vim.wo.diff then
    vim.cmd.normal({ "]c", bang = true })
  else
    require("gitsigns").nav_hunk("next")
  end
end

local function blame_line()
  require("gitsigns").blame_line({ full = true })
end

local function diff_current_file()
  require("gitsigns").diffthis("~")
end

local function preview_hunk_inline()
  require("gitsigns").preview_hunk_inline()
end

local function undo_stage_hunk()
  require("gitsigns").undo_stage_hunk()
end

-- git signs highlights text that has changed since the list
-- git commit, and also lets you interactively stage & unstage
-- hunks in a commit.
return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufWritePost", "VeryLazy" },
  opts = {
    current_line_blame = true,
    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
      delay = 1000,
      ignore_whitespace = false,
      virt_text_priority = 100,
    },
    current_line_blame_formatter = "    <author>, <author_time:%Y-%m-%d %H:%M:%S> - <summary>",
    current_line_blame_formatter_opts = {
      relative_time = false,
    },
    signcolumn = true,
    numhl = true,
    linehl = false,
    word_diff = false,
    max_file_length = 3000, -- Disable if file is longer than this (in lines)
    signs = {
      add = { text = "┃" },
      change = { text = "┃" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
      untracked = { text = "┆" },
    },
    on_attach = function(buffer)
      ---@param mode string
      ---@param key string
      ---@param action any
      ---@param desc string
      ---@param silent? boolean
      local function mapkey(mode, key, action, desc, silent)
        vim.keymap.set(mode, key, action, { buffer = buffer, noremap = true, silent = silent ~= nil and silent or false, desc = desc })
      end

      mapkey("n", "[h", goto_prev_hunk, "git: Prev hunk", true)
      mapkey("n", "]h", goto_next_hunk, "git: Next hunk", true)
      mapkey("n", "<leader>gb", blame_line, "git: Preview hunk inline", true)
      mapkey("n", "<leader>gd", diff_current_file, "git: Diff current file", true)
      mapkey("n", "<leader>gp", preview_hunk_inline, "git: Preview hunk inline", true)
    end,
  },
  config = function(_, opts)
    dofile(vim.g.base46_cache .. "git")
    require("gitsigns").setup(opts)
  end,
}
