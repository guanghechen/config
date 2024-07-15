---@return string
local function get_filestatus()
  local bufnr_status_line = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
  local buffer_status_line = vim.b[bufnr_status_line]
  if buffer_status_line and buffer_status_line.gitsigns_head and not buffer_status_line.gitsigns_git_status then
    local texts = {} ---@type string[]
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
    return table.concat(texts, " ")
  end
  return ""
end

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "filestatus",
  render = function()
    local text_filestatus = get_filestatus() ---@type string
    local hl_text = fml.nvimbar.txt(text_filestatus, "f_sl_text")
    local width = vim.fn.strwidth(text_filestatus)
    return hl_text, width
  end,
}

return M
