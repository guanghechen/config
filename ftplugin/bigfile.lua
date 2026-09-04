local __module_name__ = "ftplugin.bigfile"

local bufnr = vim.api.nvim_get_current_buf() ---@type integer
local winnr = vim.api.nvim_get_current_win() ---@type integer
local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string

vim.b[bufnr].completion = false

vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
vim.api.nvim_set_option_value("undolevels", 100, { buf = bufnr })

vim.api.nvim_set_option_value("foldmethod", "manual", { win = winnr, scope = "local" })
vim.api.nvim_set_option_value("spell", false, { win = winnr, scope = "local" })

pcall(vim.treesitter.stop, bufnr)

vim.schedule(function()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local filetype = vim.filetype.match({ buf = bufnr }) or "" ---@type string
  vim.api.nvim_set_option_value("syntax", filetype, { buf = bufnr })
end)

stl.reporter.warn({
  from = __module_name__,
  subject = "bigfile",
  message = ("Big file detected `%s`.\nSome Neovim features have been **disabled**."):format(filepath),
})
