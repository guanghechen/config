---@param winnr                         integer
local function should_show_winline(winnr)
  if fml.api.state.is_floating_win(winnr) then
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

---@class ghc.ui.winline
local M = {}

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
      get_max_width = function()
        return vim.api.nvim_win_get_width(winnr)
      end,
    })
    winline_map[winnr] = winline

    local c = {
      dirpath = "dirpath",
      filename = "filename",
      indicator = "indicator",
      lsp = "lsp",
    }
    for _, name in pairs(c) do
      winline:register(name, require("ghc.ui.winline.component." .. name))
    end

    winline
      ---
      :place(c.indicator, "left")
      :place(c.dirpath, "left")
      :place(c.filename, "left")
      :place(c.lsp, "left")
  end
  return winline:render()
end

---@param winnr                         integer|nil
---@return nil
function M.update(winnr)
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local result = M.render(winnr) ---@type string
  if #result > 0 then
    vim.wo[winnr].winbar = result
  end
end

fml.api.state.winline_dirty_ticker:subscribe(fml.collection.Subscriber.new({
  on_next = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    M.update(winnr)
  end,
}))

return M
