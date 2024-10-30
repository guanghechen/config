local skip_check = assert(vim.uv.new_check())
local skip_foldexpr = {} ---@type table<number,boolean>

---@return string
local function foldexpr()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer

  -- still in the same tick and no parser
  if skip_foldexpr[bufnr] then
    return "0"
  end

  -- don't use treesitter folds for terminal
  if vim.bo[bufnr].buftype == "terminal" then
    return "0"
  end

  -- as long as we don't have a filetype, don't bother
  -- checking if treesitter is available (it won't)
  if vim.bo[bufnr].filetype == "" then
    return "0"
  end

  local ok = pcall(vim.treesitter.get_parser, bufnr)

  if ok then
    return vim.treesitter.foldexpr()
  end

  -- no parser available, so mark it as skip
  -- in the next tick, all skip marks will be reset
  skip_foldexpr[bufnr] = true
  skip_check:start(function()
    skip_foldexpr = {}
    skip_check:stop()
  end)

  return "0"
end

return foldexpr
