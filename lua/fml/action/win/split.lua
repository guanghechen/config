---@param direction                     'h'|'j'|'k'|'l'
---@return integer
local function split(direction)
  if direction == "h" then
    vim.o.splitright = false
    vim.cmd("vsplit")
    vim.o.splitright = true
  elseif direction == "j" then
    vim.o.splitbelow = true
    vim.cmd("split")
  elseif direction == "k" then
    vim.o.splitbelow = false
    vim.cmd("split")
    vim.o.splitbelow = true
  elseif direction == "l" then
    vim.o.splitright = true
    vim.cmd("vsplit")
  end
  return vim.api.nvim_get_current_win()
end

---@class fml.action.win
local M = {}

---@param direction                     'h'|'j'|'k'|'l'
---@return nil
function M.split(direction)
  local winnr_original = vim.api.nvim_get_current_win() ---@type integer
  if eve.win.is_float(winnr_original) then
    return
  end

  if eve.win.is_sourcefile(winnr_original) then
    local winnr_target = split(direction) ---@type integer
    eve.win.fork(winnr_original, winnr_target)
    return
  end

  local bufnr_original = vim.api.nvim_win_get_buf(winnr_original) ---@type integer
  local bufnr_scratch = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.bo[bufnr_scratch].buflisted = false
  vim.bo[bufnr_scratch].buftype = "nofile"
  vim.bo[bufnr_scratch].filetype = "text"
  vim.bo[bufnr_scratch].swapfile = false

  if vim.wo[winnr_original].winfixbuf then
    vim.wo[winnr_original].winfixbuf = false
    vim.api.nvim_win_set_buf(winnr_original, bufnr_scratch)
    vim.wo[winnr_original].winfixbuf = true
  else
    vim.api.nvim_win_set_buf(winnr_original, bufnr_scratch)
  end

  local winnr_target = split(direction) ---@type integer
  vim.api.nvim_win_set_buf(winnr_original, bufnr_original)
  vim.api.nvim_win_set_buf(winnr_target, bufnr_scratch)

  vim.wo[winnr_target].cursorline = true
  vim.wo[winnr_target].number = true
  vim.wo[winnr_target].relativenumber = true
  vim.wo[winnr_target].signcolumn = "yes"
  vim.wo[winnr_target].spell = false
  vim.wo[winnr_target].winfixbuf = false
  vim.wo[winnr_target].wrap = false

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr_scratch) then
      vim.bo[bufnr_scratch].bufhidden = "wipe"
    end
  end)
end

---@return nil
function M.split_above()
  M.split("k")
end

---@return nil
function M.split_right()
  M.split("l")
end

---@return nil
function M.split_below()
  M.split("j")
end

---@return nil
function M.split_left()
  M.split("h")
end

return M
