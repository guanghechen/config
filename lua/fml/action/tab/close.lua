local __module_name__ = "fml.action.tab" ---@type string

---@class fml.action.tab
local M = {}

---@return nil
function M.close()
  local N = vim.fn.tabpagenr("$") ---@type integer
  if N <= 1 then
    std.reporter.warn({
      from = __module_name__,
      subject = "close",
      message = "This is the last tab, cannot close it.",
    })
    return
  end
  vim.cmd.tabclose()
end

---@return nil
function M.close_to_leftest()
  local tabid = vim.fn.tabpagenr() ---@type integer
  for _ = 1, tabid - 1, 1 do
    vim.cmd("-tabclose")
  end
end

---@return nil
function M.close_to_rightest()
  local N = vim.fn.tabpagenr("$") ---@type integer
  local tabid = vim.fn.tabpagenr() ---@type integer
  for _ = tabid + 1, N, 1 do
    vim.cmd("+tabclose")
  end
end

---@return nil
function M.close_others()
  vim.cmd("tabonly")
end

return M
