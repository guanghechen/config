local PATTERN = [[\s\+$]]
local HLGROUP = "f_ux_trailspace"
local match_ids = {} ---@type table<integer, integer>

---@return nil
local function highlight()
  local enabled = era.context.flight.dressing_trailspace:snapshot()
  if not enabled then
    return
  end

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
  if not dot.filetype.is_sourcefile(filetype) then
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
local function unhighlight_all()
  for winnr, match_id in pairs(match_ids) do
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_call(winnr, function()
        pcall(vim.fn.matchdelete, match_id)
      end)
    end
  end
  match_ids = {}
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

local group = ark.nvim.augroup("fml.dressing.trailspace")
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "InsertLeave" }, {
  group = group,
  callback = highlight,
})
vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave", "InsertEnter" }, {
  group = group,
  callback = unhighlight,
})

ark.fn.observe({ era.context.flight.dressing_trailspace }, function()
  local enabled = era.context.flight.dressing_trailspace:snapshot()
  if enabled then
    highlight()
  else
    unhighlight_all()
  end
end, true)

return {
  trim = trim,
  trim_last_lines = trim_last_lines,
}
