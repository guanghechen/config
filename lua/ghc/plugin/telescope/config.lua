local function config(_, opts)
  dofile(vim.g.base46_cache .. "telescope")
  require("telescope").setup(opts)
end

return config
