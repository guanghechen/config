local sep = " "

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "dirpath",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local winnr = context.winnr ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local buf = fml.api.state.bufs[bufnr] ---@type fml.api.state.IBufItem|nil
    if buf == nil or buf.filename == nil then
      return "", 0
    end

    local first = true ---@type boolean
    local text = "" ---@type string
    local N = #buf.real_paths - 1 ---@type integer
    for i = 1, N, 1 do
      local piece = buf.real_paths[i] ---@type string
      if first then
        first = false
        text = piece .. sep
      else
        text = text .. " " .. piece .. sep
      end
    end

    local text_hln = "f_wl_dirpath_text" ---@type string
    local hl_text = fml.nvimbar.txt(text, text_hln) ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
