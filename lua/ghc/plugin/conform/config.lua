local config = function(_, opts)
  require("conform").setup(opts)
  vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
end

return config
