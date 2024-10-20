---@param context                       t.fml.ux.nvimbar.IContext
---@return string
local function get_filepath(context)
  local cwd = context.cwd ---@type string
  local filepath = context.filepath ---@type string
  local relative_to_cwd = eve.path.relative(cwd, filepath, false) ---@type string
  if string.sub(relative_to_cwd, 1, 1) == "." and eve.path.is_absolute(filepath) then
    local workspace = eve.path.workspace() ---@type string
    if cwd ~= workspace then
      local relative_to_workspace = eve.path.relative(workspace, filepath, false)
      if string.sub(relative_to_workspace, 1, 1) == "." then
        relative_to_cwd = eve.path.normalize(filepath)
      end
    end
  end
  return context.fileicon .. " " .. relative_to_cwd
end

---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "filepath",
  condition = function(context)
    return #context.filepath > 0 and context.filepath ~= "."
  end,
  render = function(context)
    local text = get_filepath(context) ---@type string
    local hl_text = eve.nvimbar.txt(text, "f_sl_text")
    local width = vim.api.nvim_strwidth(text)
    return hl_text, width
  end,
}

return M
