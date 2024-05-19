local function goto_prev_reference()
  require("illuminate").goto_prev_reference(false)
end

local function goto_next_reference()
  require("illuminate").goto_next_reference(false)
end

-- Automatically highlights other instances of the word under your cursor.
-- This works with LSP, Treesitter, and regexp matching to find the other instances.
return {
  "RRethy/vim-illuminate",
  event = { "VeryLazy" },
  keys = {
    { "]]", desc = "Next Reference" },
    { "[[", desc = "Prev Reference" },
  },
  opts = {
    delay = 200,
    filetypes_denylist = {
      "lazyterm",
      "neo-tree",
      "noice",
      "notify",
      "quickfix",
      "term",
    },
    large_file_cutoff = 2000,
    large_file_overrides = {
      providers = { "lsp" },
    },
  },
  config = function(_, opts)
    require("illuminate").configure(opts)

    ---@param buffer? number|nil
    ---@return nil
    local function bind_keys(buffer)
      vim.keymap.set("n", "[[", goto_prev_reference, { buffer = buffer, noremap = true, silent = true, desc = "illuminate: Goto prev reference" })
      vim.keymap.set("n", "]]", goto_next_reference, { buffer = buffer, noremap = true, silent = true, desc = "illuminate: Goto next reference" })
    end

    bind_keys()

    -- also set it after loading ftplugins, since a lot overwrite [[ and ]]
    vim.api.nvim_create_autocmd("FileType", {
      callback = function()
        local buffer = vim.api.nvim_get_current_buf()
        bind_keys(buffer)
      end,
    })
  end,
}
