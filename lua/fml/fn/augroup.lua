local function augroup(name)
  return vim.api.nvim_create_augroup("fml_" .. name, { clear = true })
end

return augroup
