local M = {}

M.workspace = function()
  return LazyVim.root()
end

M.cwd = function()
  return vim.uv.cwd()
end

M.current = function()
  return vim.fn.expand("%:p:h")
end

return M