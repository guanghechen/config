local ft = require("eve.constant.filetype")

local filetypes = { ft.AVANTE } --@type string[]

return {
  "render-markdown.nvim",
  ft = vim.list_slice(filetypes),
  opts = {
    file_types = vim.list_slice(filetypes),
  },
}
