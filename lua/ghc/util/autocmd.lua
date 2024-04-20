local function augroup(name)
  return vim.api.nvim_create_augroup("ghc_" .. name, { clear = true })
end

return {
  augroup = augroup,
}
