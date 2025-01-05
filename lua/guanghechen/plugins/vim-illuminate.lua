local fn = require("eve.builtin.fn")
local ft = require("eve.constant.filetype")

---@type eve.t.IKeymap[]
local keymaps = {
  {
    modes = { "n" },
    key = "[[",
    callback = function()
      require("illuminate").goto_prev_reference(false)
    end,
    desc = "illuminate: Goto prev reference",
  },
  {
    modes = { "n" },
    key = "]]",
    callback = function()
      require("illuminate").goto_next_reference(false)
    end,
    desc = "illuminate: Goto next reference",
  },
}

-- Automatically highlights other instances of the word under your cursor.
-- This works with LSP, Treesitter, and regexp matching to find the other instances.
return {
  name = "vim-illuminate",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  keys = {
    { "]]", desc = "Next Reference" },
    { "[[", desc = "Prev Reference" },
  },
  opts = {
    delay = 200,
    filetypes_denylist = ft.get_no_illuminate_filetypes(),
    large_file_cutoff = 2000,
    large_file_overrides = {
      providers = { "lsp" },
    },
  },
  config = function(_, opts)
    require("illuminate").configure(opts)
    fn.bindkeys(keymaps, { noremap = true, silent = true, nowait = true })

    -- also set it after loading ftplugins, since a lot overwrite [[ and ]]
    vim.api.nvim_create_autocmd("FileType", {
      group = fn.augroup("reset_illuminate_keymaps"),
      callback = function()
        local bufnr = vim.api.nvim_get_current_buf() ---@type integer|nil
        fn.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true, nowait = true })
      end,
    })
  end,
}
