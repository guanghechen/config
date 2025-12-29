local __module_name__ = "ftplugin.bigfile"

local bufnr = vim.api.nvim_get_current_buf() ---@type integer
local winnr = vim.api.nvim_get_current_win() ---@type integer
local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string

vim.b[bufnr].completion = false
vim.b[bufnr].minihipatterns_disable = true
vim.b[bufnr].miniindentscope_disable = true

vim.bo[bufnr].swapfile = false
vim.bo[bufnr].undolevels = 100

vim.wo[winnr].foldmethod = "manual"
vim.wo[winnr].spell = false

pcall(vim.treesitter.stop, bufnr)

vim.schedule(function()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local filetype = vim.filetype.match({ buf = bufnr }) or "" ---@type string
  vim.bo[bufnr].syntax = filetype
end)

stl.reporter.warn({
  from = __module_name__,
  subject = "bigfile",
  message = ("Big file detected `%s`.\nSome Neovim features have been **disabled**."):format(filepath),
})
