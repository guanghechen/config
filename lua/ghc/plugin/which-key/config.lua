local function config(_, opts)
  dofile(vim.g.base46_cache .. "whichkey")
  require("which-key").setup(opts)
  require("which-key").register(opts.defaults)
end

return config
