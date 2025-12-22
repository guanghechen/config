local txt = ark.nvim.txt

---@class dot.module.nvimbar.component.git
local M = {}

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.branch(position)
  local hln_sep = position .. "_git_branch_sep" ---@type string
  local hln_text = position .. "_git_branch_text" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "git:branch",
    atomic = true,
    tight = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.git_branch ~= prev_context.git_branch
    end,
    render = function(context)
      if context.git_branch == nil then
        local text = " " .. dot.icon.symbols.sep_right ---@type string
        local hl_text = txt(" ", hln_text) .. txt(dot.icon.symbols.sep_right, hln_sep) ---@type string
        return text, hl_text, true
      end

      local text = " " .. dot.icon.git.Branch .. " " .. context.git_branch .. dot.icon.symbols.sep_right ---@type string
      local hl_text = txt(" " .. dot.icon.git.Branch .. " " .. context.git_branch, hln_text) .. txt(dot.icon.symbols.sep_right, hln_sep) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

return M
