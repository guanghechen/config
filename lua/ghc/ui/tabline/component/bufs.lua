---@type string
local fn_active_buf = fc.G.register_anonymous_fn(function(bufnr)
  if type(bufnr) == "number" and vim.api.nvim_buf_is_valid(bufnr) then
    fml.api.buf.go(bufnr)
  end
end) or ""

---@param bufnr                         integer
---@param is_current                    boolean
---@param is_first                      boolean
---@return string
---@return integer
local function render_buf(bufnr, is_current, is_first)
  local buf = fml.api.state.bufs[bufnr] ---@type fml.types.api.state.IBufItem|nil
  if buf == nil then
    return "", 0
  end

  local is_mod = vim.api.nvim_get_option_value("mod", { buf = bufnr }) ---@type boolean
  local is_pinned = buf.pinned ---@type boolean

  local text_left_pad = is_current and "▎" or (is_first and " " or "▏") ---@type string
  local text_icon = buf.fileicon .. " " ---@type string
  local text_title = buf.filename ---@type string
  local text_mod = is_pinned and (is_mod and "  " or "  ") or (is_mod and "  " or "  ") ---@type string

  local hl_left_pad = is_current and "f_tl_buf_left_pad_cur" or "f_tl_buf_left_pad" ---@type string
  local hl_buf = is_current and "f_tl_buf_item_cur" or "f_tl_buf_item" ---@type string
  local hl_title = is_current and "f_tl_buf_title_cur" or "f_tl_buf_title" ---@type string
  local hl_mod = is_current and "f_tl_buf_mod_cur" or "f_tl_buf_mod" ---@type string
  local hl_icon = buf.fileicon_hl .. (is_current and "_tl_buf_cur" or "_tl_buf") ---@type string

  local hl_text_left_pad = fc.nvimbar.txt(text_left_pad, hl_left_pad)
  local hl_text_icon = fc.nvimbar.txt(text_icon, hl_icon)
  local hl_text_title = fc.nvimbar.txt(text_title, hl_title)
  local hl_text_mod = is_mod and fc.nvimbar.txt(text_mod, hl_mod) or text_mod

  local hl_text = "%#" .. hl_buf .. "#" .. hl_text_left_pad .. hl_text_icon .. hl_text_title .. hl_text_mod ---@type string
  local width = vim.fn.strwidth(text_left_pad .. text_icon .. text_title .. text_mod) ---@type integer
  return fc.nvimbar.btn(hl_text, fn_active_buf, bufnr), width
end

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "bufs",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local tab = fml.api.state.get_tab(tabnr) ---@type fml.types.api.state.ITabItem|nil
    if tab == nil or #tab.bufnrs < 1 then
      return "", 0
    end

    local winnr_cur = fml.api.state.get_current_tab_winnr() ---@type integer
    local bufnr_cur = vim.api.nvim_win_get_buf(winnr_cur) ---@type integer
    local bufid_src = fc.array.first(tab.bufnrs, bufnr_cur) ---@type integer|nil
    local bufid_cur = bufid_src or 1
    bufnr_cur = tab.bufnrs[bufid_cur]

    local text, width = render_buf(tab.bufnrs[bufid_cur], bufid_src ~= nil, bufid_cur == 1)
    remain_width = remain_width - width
    if remain_width < 0 then
      return "", 0
    end

    for i = bufid_cur - 1, 1, -1 do
      local t, w = render_buf(tab.bufnrs[i], false, i == 1)
      remain_width = remain_width - w
      if remain_width >= 0 then
        text = t .. text
      end
    end
    for i = bufid_cur + 1, #tab.bufnrs, 1 do
      local t, w = render_buf(tab.bufnrs[i], false, false)
      remain_width = remain_width - w
      if remain_width >= 0 then
        text = text .. t
      end
    end
    return text, width
  end,
}

return M
