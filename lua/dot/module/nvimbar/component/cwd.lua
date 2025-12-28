local txt = ark.vim.fn.txt

---@class dot.module.nvimbar.component.cwd
local M = {}

---@param position                      ark.e.NvimbarPositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.cwd(position)
  local hln_text = position .. "_cwd_text" ---@type string
  local hln_sep = position .. "_cwd_sep" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "cwd",
    atomic = true,
    tight = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.cwd ~= prev_context.cwd
    end,
    render = function(context)
      local cwd_name = yoz.path.basename(context.cwd) ---@type string
      local text = ark.icon.filetype.FolderRootOpened .. " " .. cwd_name .. " " ---@type string
      local hl_text = txt(text, hln_text) ---@type string

      text = ark.icon.symbols.sep_left .. text ---@type string
      hl_text = txt(ark.icon.symbols.sep_left, hln_sep) .. hl_text ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

return M
