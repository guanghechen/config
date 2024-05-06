local function config(_, opts)
  dofile(vim.g.base46_cache .. "whichkey")

  vim.o.timeout = true
  vim.o.timeoutlen = 300

  require("which-key").setup(opts)
  require("which-key").register(opts.defaults)
end

return config
