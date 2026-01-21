local txt = stl.nvim.fn.txt

---@class era.m.nvimbar.component.cwd
local M = {}

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.cwd(position)
  local hln_text = position .. "_cwd_text" ---@type string
  local hln_sep = position .. "_cwd_sep" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "cwd",
    atomic = true,
    tight = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.cwd ~= prev_context.cwd
    end,
    render = function(context)
      local cwd_name = yoz.path.basename(context.cwd) ---@type string
      local text = stl.icon.filetype.FolderRootOpened .. " " .. cwd_name .. " " ---@type string
      local hl_text = txt(text, hln_text) ---@type string

      text = stl.icon.symbols.sep_left .. text ---@type string
      hl_text = txt(stl.icon.symbols.sep_left, hln_sep) .. hl_text ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

return M
