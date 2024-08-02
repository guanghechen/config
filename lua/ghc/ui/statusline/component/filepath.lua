---@param context                       fml.types.ui.nvimbar.IContext
---@return string
local function get_filepath(context)
  local cwd = context.cwd ---@type string
  local filepath = context.filepath ---@type string
  local relative_to_cwd = fml.path.relative(cwd, filepath) ---@type string
  if string.sub(relative_to_cwd, 1, 1) == "." and fml.path.is_absolute(filepath) then
    local workspace = fml.path.workspace() ---@type string
    if cwd ~= workspace then
      local relative_to_workspace = fml.path.relative(workspace, filepath)
      if string.sub(relative_to_workspace, 1, 1) == "." then
        relative_to_cwd = fml.path.normalize(filepath)
      end
    end
  end
  return context.fileicon .. " " .. relative_to_cwd
end

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "filepath",
  condition = function(context)
    return #context.filepath > 0 and context.filepath ~= "."
  end,
  render = function(context)
    local text = get_filepath(context) ---@type string
    local hl_text = fml.nvimbar.txt(text, "f_sl_text")
    local width = vim.fn.strwidth(text)
    return hl_text, width
  end,
}

return M
