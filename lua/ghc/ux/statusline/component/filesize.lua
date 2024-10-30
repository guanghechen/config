---@param context                       t.fml.ux.nvimbar.IContext
---@return string
local function get_filesize(context)
  local filepath = context.filepath ---@type string
  local file = io.open(filepath, "r")

  if not file then
    return ""
  end

  local size = file:seek("end")
  file:close()

  local units = { "B", "KB", "MB", "GB", "TB" }
  local i = 1
  while size > 1024 and i < #units do
    size = size / 1024
    i = i + 1
  end

  local remain = (size * 100) % 100
  if remain == 0 then
    return string.format("%g%s", size, units[i])
  elseif remain % 10 == 0 then
    return string.format("%.1f%s", size, units[i])
  else
    return string.format("%.2f%s", size, units[i])
  end
end

---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "filesize",
  render = function(context)
    local text = get_filesize(context) ---@type string
    local hl_text = eve.nvimbar.txt(text, "f_sl_text")
    local width = vim.api.nvim_strwidth(text)
    return hl_text, width
  end,
}

return M
