local config = function(_, opts)
  dofile(vim.g.base46_cache .. "git")
  require("gitsigns").setup(opts)
end

return config

