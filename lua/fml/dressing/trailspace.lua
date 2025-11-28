local PATTERN = [[\s\+$]]
local HLGROUP = "f_ux_trailspace"
local match_ids = {} ---@type table<integer, integer>

---@return nil
local function highlight()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  if match_ids[winnr] then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype ~= "" and buftype ~= "nowrite" then
    return
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if not eve.filetype.is_sourcefile(filetype) then
    return
  end

  if vim.fn.mode() ~= "n" then
    return
  end

  match_ids[winnr] = vim.fn.matchadd(HLGROUP, PATTERN)
end

---@return nil
local function unhighlight()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  if match_ids[winnr] then
    pcall(vim.fn.matchdelete, match_ids[winnr])
    match_ids[winnr] = nil
  end
end

---@return nil
local function trim()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local curpos = vim.api.nvim_win_get_cursor(winnr)
  vim.cmd([[keeppatterns %s/\s\+$//e]])
  vim.api.nvim_win_set_cursor(0, curpos)
end

---@return nil
local function trim_last_lines()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local n_lines = vim.api.nvim_buf_line_count(bufnr) ---@type integer
  local last_nonblank = vim.fn.prevnonblank(n_lines) ---@type integer
  if last_nonblank < n_lines then
    vim.api.nvim_buf_set_lines(bufnr, last_nonblank, n_lines, true, {})
  end
end

local group = eve.nvim.augroup("fml.dressing.trailspace")
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "InsertLeave" }, {
  group = group,
  callback = highlight,
})
vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave", "InsertEnter" }, {
  group = group,
  callback = unhighlight,
})

vim.defer_fn(highlight, 0)

return {
  trim = trim,
  trim_last_lines = trim_last_lines,
}
