---@param context                       fml.types.ui.nvimbar.IContext
---@return string
local function get_filepath(context)
  local cwd = context.cwd
  local filepath = context.filepath
  local relative_to_cwd = fml.path.relative(cwd, filepath)
  if string.sub(relative_to_cwd, 1, 1) == "." and fml.path.is_absolute(filepath) then
    local workspace = fml.path.workspace()
    if cwd ~= workspace then
      local relative_to_workspace = fml.path.relative(workspace, filepath)
      if string.sub(relative_to_workspace, 1, 1) == "." then
        relative_to_cwd = fml.path.normalize(filepath)
      end
    end
  end
  return context.fileicon .. " " .. relative_to_cwd
end

---@return string
local function get_filestatus()
  local texts = {} ---@type string[]
  local bufnr_status_line = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
  local buffer_status_line = vim.b[bufnr_status_line]
  if buffer_status_line and buffer_status_line.gitsigns_head and not buffer_status_line.gitsigns_git_status then
    local git_status = buffer_status_line.gitsigns_status_dict
    if git_status.added and git_status.added > 0 then
      table.insert(texts, fml.ui.icons.git.Add .. " " .. git_status.added)
    end
    if git_status.changed and git_status.changed > 0 then
      table.insert(texts, fml.ui.icons.git.Mod_alt .. " " .. git_status.changed)
    end
    if git_status.removed and git_status.removed > 0 then
      table.insert(texts, fml.ui.icons.git.Remove .. " " .. git_status.removed)
    end
  end
  return table.concat(texts, " ")
end

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "filepath",
  condition = function(context)
    return #context.filepath > 0 and context.filepath ~= "."
  end,
  render = function(context)
    local text_filepath = get_filepath(context) ---@type string
    local text_filestatus = get_filestatus() ---@type string
    local hl_text = fml.nvimbar.txt(text_filepath, "f_sl_text") .. " " .. fml.nvimbar.txt(text_filestatus, "f_sl_text")
    local width = vim.fn.strwidth(text_filepath) + vim.fn.strwidth(text_filestatus)
    return hl_text, width
  end,
}

return M
