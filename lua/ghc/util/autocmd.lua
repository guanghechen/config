---@class ghc.util.autocmd
local M = {}

M.augroup = function(name)
  return vim.api.nvim_create_augroup("ghc_" .. name, { clear = true })
end

return M
