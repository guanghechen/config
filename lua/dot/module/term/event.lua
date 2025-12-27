require("dot.module.term.types")

---@class dot.module.term.event
local M = {}

---@param bufnr                         integer|nil
---@return nil
function M.on_buf_deleted(bufnr)
  local _, termmeta = dot.term.state.indexof_by_bufnr(bufnr)
  if termmeta ~= nil then
    M.on_closed(termmeta)
  end
end

---@param termmeta                      dot.module.term.IMeta
---@return nil
function M.on_closed(termmeta)
  if termmeta.jobid ~= nil then
    vim.fn.jobstop(termmeta.jobid)
    termmeta.jobid = nil
  end

  local bufnr = termmeta.bufnr ---@type integer
  termmeta.bufnr = 0

  local next_termmeta = dot.term.state.pick_next_term(termmeta.uuid) ---@type dot.module.term.IMeta|nil
  if next_termmeta ~= nil then
    dot.term.state.o_termuuid:next(next_termmeta.uuid)
  else
    dot.term.state.o_termuuid:next("")
  end

  dot.term.state.remove(termmeta.uuid)

  if not termmeta.permanent then
    dot.term.state.unregister(termmeta.uuid)
  end

  if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    dot.buf.close(bufnr)
  end
  termmeta.on_closed()

  vim.schedule(function()
    vim.cmd("checktime")
  end)
end

---@param termmeta                      dot.module.term.IMeta
---@return nil
function M.on_focused(termmeta)
  termmeta.on_focused()
end

return M
