local config = function()
  dofile(vim.g.base46_cache .. "lsp")
  require "nvchad.lsp"
end

return config
