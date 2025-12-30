local S = era.m.term

---@class era.m.term.event
local M = {}

---@param bufnr                         integer|nil
---@return nil
function M.on_buf_deleted(bufnr)
  local _, termmeta = S.state.indexof_by_bufnr(bufnr)
  if termmeta ~= nil then
    M.on_closed(termmeta)
  end
end

---@param termmeta                      era.m.term.IMeta
---@return nil
function M.on_closed(termmeta)
  if termmeta.jobid ~= nil then
    vim.fn.jobstop(termmeta.jobid)
    termmeta.jobid = nil
  end

  local bufnr = termmeta.bufnr ---@type integer
  termmeta.bufnr = 0

  local next_termmeta = S.state.pick_next_term(termmeta.uuid) ---@type era.m.term.IMeta|nil
  if next_termmeta ~= nil then
    S.state.o_termuuid:next(next_termmeta.uuid)
  else
    S.state.o_termuuid:next("")
  end

  S.state.remove(termmeta.uuid)

  if not termmeta.permanent then
    S.state.unregister(termmeta.uuid)
  end

  if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    stl.nvim.buf.close(bufnr)
  end
  termmeta.on_closed()

  vim.schedule(function()
    vim.cmd("checktime")
  end)
end

---@param termmeta                      era.m.term.IMeta
---@return nil
function M.on_focused(termmeta)
  termmeta.on_focused()
end

return M
