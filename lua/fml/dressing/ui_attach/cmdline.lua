local winnr = nil ---@type integer|nil
local bufnr = nil ---@type integer|nil

---@class fml.dressing.ui_attach.cmdline
local M = {}

---@param task                          fml.dressing.ui_attach.ITask
---@return boolean|nil
function M.show(task)
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].filetype = eve.filetype.CMDLINE
    vim.bo[bufnr].swapfile = false
  end

  local width = math.min(math.floor(vim.o.columns * 0.8), 80) ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg = {
    relative = "editor",
    width = width,
    height = 1,
    row = 3,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = "Cmdline",
    title_pos = "center",
  }
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    wincfg.noautocmd = true
    winnr = vim.api.nvim_open_win(bufnr, true, wincfg)

    vim.wo[winnr].cursorline = false
    vim.wo[winnr].list = false
    vim.wo[winnr].number = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].spell = false
    vim.wo[winnr].wrap = false
    vim.wo[winnr].winhighlight = "Normal:FloatNormal,FloatBorder:FloatActiveBorder,CursorLine:FloatNormal"
  else
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_win_set_config(winnr, wincfg)
  end

  eve.debug.log({ task = task })
end

function M.hide(task)
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
    bufnr = nil
  end

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
    winnr = nil
  end

  eve.debug.log({ task = task })
end

return M
