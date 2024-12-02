---@return string
local function foldexpr()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer

  -- don't use treesitter folds for terminal
  if vim.bo[bufnr].buftype == "terminal" then
    return "0"
  end

  if vim.bo[bufnr].filetype == "" then
    return "0"
  end

  if vim.b[bufnr].ts_folds == nil then
    vim.b[bufnr].ts_folds = pcall(vim.treesitter.get_parser, bufnr)
  end

  return vim.b[bufnr].ts_folds and vim.treesitter.foldexpr() or "0"
end

return foldexpr
