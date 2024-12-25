local ft = require("eve.lib.filetype")
local augroup = require("eve.lib.nvim").augroup

-- Active indent guide and indent text objects. When you're browsing
-- code, this highlights the current level of indentation, and animates
-- the highlighting.
return {
  name = "mini.indentscope",
  event = { "VeryLazy" },
  opts = {
    symbol = "╎",
    options = {
      try_as_border = true,
    },
  },
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      group = augroup("disable_miniindentscope"),
      pattern = ft.get_no_ibl_filetypes(),
      callback = function()
        vim.b.miniindentscope_disable = true
      end,
    })
  end,
}
