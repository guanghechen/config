local sep = "  "

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "dirpath",
  render = function(context)
    local winnr = context.winnr ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local buf = fml.api.state.bufs[bufnr] ---@type fml.types.api.state.IBufItem|nil
    if buf == nil then
      return "", 0
    end

    local text = "" ---@type string
    local N = #buf.real_paths - 1 ---@type integer
    for i = 1, N, 1 do
      local piece = buf.real_paths[i] ---@type string
      text = text .. piece .. sep
    end

    local hl_text = fml.nvimbar.txt(text, "f_wl_dirpath_text") ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
