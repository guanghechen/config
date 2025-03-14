---@class eve.module.session
local M = {}

---@param filepath                      string
---@return nil
function M.load_session(filepath)
  if vim.fn.filereadable(filepath) ~= 0 then
    vim.cmd("silent! source " .. vim.fn.fnameescape(filepath))
  end
end

---@param filepath                      string
---@return nil
function M.save_session(filepath)
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":p:h"), "p")
  local tmp = vim.o.sessionoptions
  vim.o.sessionoptions = eve.setting.sessions.persistent_options
  vim.cmd("mks! " .. vim.fn.fnameescape(filepath))
  vim.o.sessionoptions = tmp
end

return M
