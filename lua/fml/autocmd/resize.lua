local search = require("fml.ui.search")

vim.api.nvim_create_autocmd({ "VimResized" }, {
  callback = function()
    search.resize()
  end,
})
