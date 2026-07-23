---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.clipboard.exec" ---@type string

---@class era.m.clipboard.exec
local M = {}

---@param from                          string
---@param subject                       string
---@param cmd                           string[]
---@param opts                          ?vim.SystemOpts
---@param details                       ?table
---@return vim.SystemCompleted|nil
function M.run(from, subject, cmd, opts, details)
  local ok, result = pcall(function()
    return vim.system(cmd, opts or { text = true }):wait()
  end)
  if ok and result.code == 0 then
    return result
  end

  stl.reporter.error({
    from = from,
    subject = subject,
    message = "Failed to run command.",
    details = vim.tbl_extend("force", details or {}, {
      cmd = cmd,
      exit_code = ok and result.code or nil,
      output = ok and result.stdout or nil,
      error = ok and result.stderr or result,
    }),
  })
  return nil
end

return M
