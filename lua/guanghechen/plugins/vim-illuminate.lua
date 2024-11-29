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
  event = { "VeryLazy" },
  keys = {
    { "]]", desc = "Next Reference" },
    { "[[", desc = "Prev Reference" },
  },
  opts = {
    delay = 200,
    filetypes_denylist = eve.filetype.get_no_illuminate_filetypes(),
    large_file_cutoff = 2000,
    large_file_overrides = {
      providers = { "lsp" },
    },
  },
  config = function(_, opts)
    require("illuminate").configure(opts)

    ---@param bufnr                     ?integer|nil
    ---@return nil
    local function bindkeys(bufnr)
      eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true, nowait = true })
    end

    bindkeys()

    -- also set it after loading ftplugins, since a lot overwrite [[ and ]]
    vim.api.nvim_create_autocmd("FileType", {
      callback = function()
        local bufnr = vim.api.nvim_get_current_buf() ---@type integer|nil
        bindkeys(bufnr)
      end,
    })
  end,
}
