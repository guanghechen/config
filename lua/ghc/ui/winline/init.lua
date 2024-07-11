---@class ghc.ui.winline
local M = {}

---@param winnr                         integer
local function should_show_winline(winnr)
  if fml.api.win.is_floating(winnr) then
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local buf = fml.api.state.bufs[bufnr] ---@type fml.api.state.IBufItem|nil
  if buf == nil or buf.filename == fml.constant.BUF_UNTITLED then
    return false
  end

  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == "nofile " or buftype == "nowrite" then
    return false
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if fml.api.state.BUF_IGNORED_FILETYPES[filetype] then
    return false
  end

  return true
end

local winline_map = {} ---@type table<string, fml.types.ui.INvimbar>

---@return string
function M.render(winnr)
  if not should_show_winline(winnr) then
    return ""
  end

  local winline = winline_map[winnr] ---@type fml.types.ui.INvimbar
  if winline == nil then
    winline = fml.ui.Nvimbar.new({
      name = "winline_" .. winnr,
      component_sep = "",
      component_sep_hlname = "f_wl_bg",
      preset_context = { winnr = winnr },
    })
    winline_map[winnr] = winline
    winline
      :add("left", require("ghc.ui.winline.component.dirpath"))
      :add("left", require("ghc.ui.winline.component.filename"))
  end
  return winline:render()
end

---@return nil
function M.update(winnr)
  local result = M.render(winnr) ---@type string
  if #result > 0 then
    vim.wo[winnr].winbar = result
  end
end

return M
