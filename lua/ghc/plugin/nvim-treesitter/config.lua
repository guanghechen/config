local config = function(_, opts)
  dofile(vim.g.base46_cache .. "syntax")
  dofile(vim.g.base46_cache .. "treesitter")
  require("nvim-treesitter.configs").setup(opts)
end

return config
