local txt = std.nvim.txt

---@class ux.nvimbar.component.git
local M = {}

---@param position                      ux.nvimbar.PositionEnum
---@return ux.nvimbar.IRawComponent
function M.branch(position)
  local hln_text = position .. "_git_branch_text" ---@type string

  ---@type ux.nvimbar.IRawComponent
  local component = {
    name = "git:branch",
    atomic = true,
    condition = function(context)
      return context.git_branch ~= nil
    end,
    render = function(context)
      local text = dot.icon.git.Branch .. " " .. context.git_branch ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

return M
