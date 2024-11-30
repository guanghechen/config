local path = require("eve.lib.path")

---@param context                       fml.t.ux.nvimbar.IContext
---@return string
local function get_filepath(context)
  local cwd = context.cwd ---@type string
  local filepath = context.filepath ---@type string
  local relative_to_cwd = path.relative(cwd, filepath, false) ---@type string
  if string.sub(relative_to_cwd, 1, 1) == "." and path.is_absolute(filepath) then
    local workspace = path.workspace() ---@type string
    if cwd ~= workspace then
      local relative_to_workspace = path.relative(workspace, filepath, false)
      if string.sub(relative_to_workspace, 1, 1) == "." then
        relative_to_cwd = path.normalize(filepath)
      end
    end
  end
  return context.fileicon .. " " .. relative_to_cwd
end

---@type fml.t.ux.nvimbar.IRawComponent
local M = {
  name = "filepath",
  condition = function(context)
    return #context.filepath > 0 and context.filepath ~= "."
  end,
  render = function(context)
    local text = get_filepath(context) ---@type string
    local hl_text = eve.nvim.txt(text, "f_sl_text")
    local width = vim.api.nvim_strwidth(text)
    return hl_text, width
  end,
}

return M
