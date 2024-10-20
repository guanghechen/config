---@return string
local function get_filestatus()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = fml.api.tab.get(tabnr) ---@type t.eve.context.state.tab.IItem|nil
  local winnr = tab ~= nil and tab.winnr_cur:snapshot() or 0 ---@type integer
  local bufnr_status_line = vim.api.nvim_win_get_buf(winnr)
  local buffer_status_line = vim.b[bufnr_status_line]
  if buffer_status_line and buffer_status_line.gitsigns_head and not buffer_status_line.gitsigns_git_status then
    local texts = {} ---@type string[]
    local git_status = buffer_status_line.gitsigns_status_dict
    if git_status.added and git_status.added > 0 then
      table.insert(texts, eve.icons.git.Add .. " " .. git_status.added)
    end
    if git_status.changed and git_status.changed > 0 then
      table.insert(texts, eve.icons.git.Mod_alt .. " " .. git_status.changed)
    end
    if git_status.removed and git_status.removed > 0 then
      table.insert(texts, eve.icons.git.Remove .. " " .. git_status.removed)
    end
    return table.concat(texts, " ")
  end
  return ""
end

---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "filestatus",
  tight = true,
  render = function()
    local status = get_filestatus() ---@type string
    if #status < 1 then
      return "", 0
    end

    local text_filestatus = " " .. status ---@type string
    local hl_text = eve.nvimbar.txt(text_filestatus, "f_sl_text") ---@type string
    local width = vim.api.nvim_strwidth(text_filestatus)
    return hl_text, width
  end,
}

return M
