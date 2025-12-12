local __module_name__ = "fml.action.term.destroy" ---@type string

---@class fml.action.term.destroy
local M = {}

---@return nil
function M.destroy()
  local termindex = era.term.current() ---@type integer
  local _, termmeta = era.term.at(termindex) ---@type string|nil, era.t.ITermMeta|nil
  if termmeta == nil then
    ark.reporter.warn({
      from = __module_name__,
      subject = "destroy",
      message = "No active terminal found to destroy.",
    })
    return
  end

  vim.ui.input({
    inputtype = "confirmation",
    prompt = string.format("Delete the terminal (%s)? (y/N): ", termmeta.name),
    relative = "editor",
    row = 3,
    col = math.floor((vim.o.columns - 40) / 2),
  }, function(answer)
    if answer == nil then
      return
    end

    answer = vim.trim(answer:lower()) ---@type string
    if answer:sub(1, 1) ~= "y" then
      return
    end

    local next_termmeta = era.term.pick_next_term(termmeta.uuid) ---@type era.t.ITermMeta|nil
    if next_termmeta ~= nil then
      era.term.o_termuuid:next(next_termmeta.uuid)
    end

    vim.defer_fn(function()
      era.term.on_closed(termmeta)
      era.state.status.dirtier_termline:mark_dirty()
    end, 100)
  end)
end

return M
