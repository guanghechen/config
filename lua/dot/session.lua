---@class dot.session
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
  stl.env.mkdirs(filepath, false)
  local tmp = vim.o.sessionoptions
  vim.o.sessionoptions = ark.var.session.persistent_options
  vim.cmd("mks! " .. vim.fn.fnameescape(filepath))
  vim.o.sessionoptions = tmp
end

return M
