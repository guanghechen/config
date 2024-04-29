local function config(_, opts)
  require("notify").setup(opts)
  vim.notify = require("notify")
end

return config
