local __module_name__ = "ftplugin.bigfile"

local bufnr = vim.api.nvim_get_current_buf()
local filepath = vim.api.nvim_buf_get_name(bufnr)

vim.b[bufnr].completion = false
vim.b[bufnr].minihipatterns_disable = true

vim.schedule(function()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local filetype = vim.filetype.match({ buf = bufnr }) or ""
  vim.bo[bufnr].syntax = filetype
end)

std.reporter.warn({
  from = __module_name__,
  subject = "bigfile",
  message = ("Big file detected `%s`.\nSome Neovim features have been **disabled**."):format(filepath),
})
