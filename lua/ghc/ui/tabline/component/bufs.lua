local last_bufnr_cur = 1 ---@type integer

---@type string
local fn_active_buf = fml.G.register_anonymous_fn(function(bufnr)
  if type(bufnr) == "number" and vim.api.nvim_buf_is_valid(bufnr) then
    fml.api.buf.go(bufnr)
  end
end) or ""

---@param bufnr                         integer
---@param is_curbuf                     boolean
---@return string
---@return integer
local function render_buf(bufnr, is_curbuf)
  if fml.api.state.bufs[bufnr] == nil then
    fml.api.state.refresh_buf(bufnr)
  end

  local buf = fml.api.state.bufs[bufnr] ---@type fml.api.state.IBufItem|nil
  if buf == nil then
    return "", 0
  end

  local is_pinned = buf.pinned ---@type boolean
  local is_mod = vim.api.nvim_get_option_value("mod", { buf = bufnr }) ---@type boolean
  local icon, fileicon_hl = fml.fn.calc_fileicon(buf.filename)

  local left_pad = is_curbuf and "▎" or " " ---@type string
  local text_icon = icon .. " " ---@type string
  local text_title = buf.filename ---@type string
  local text_mod = is_pinned and (is_mod and "  " or "  ") or (is_mod and "  " or "  ") ---@type string

  local left_pad_hl = is_curbuf and "f_tl_buf_left_pad_cur" or "f_tl_buf_left_pad"
  local buf_hl = is_curbuf and "f_tl_buf_item_cur" or "f_tl_buf_item" ---@type string
  local icon_hl = fml.highlight.blend_color(fileicon_hl, buf_hl)
  local title_hl = is_curbuf and "f_tl_buf_title_cur" or "f_tl_buf_title" ---@type string
  local mod_hl = is_curbuf and "f_tl_buf_mod_cur" or "f_tl_buf_mod" ---@type string

  local hl_text_left_pad = fml.nvimbar.txt(left_pad, left_pad_hl)
  local hl_text_icon = fml.nvimbar.txt(text_icon, icon_hl)
  local hl_text_title = fml.nvimbar.txt(text_title, title_hl)
  local hl_text_mod = is_mod and fml.nvimbar.txt(text_mod, mod_hl) or text_mod

  local hl_text = fml.nvimbar.txt(hl_text_left_pad .. hl_text_icon .. hl_text_title .. hl_text_mod, buf_hl)
  local width = vim.fn.strwidth(left_pad .. text_icon .. text_title .. text_mod) ---@type integer
  return fml.nvimbar.btn(hl_text, fn_active_buf, bufnr), width
end

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "bufs",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local tab = fml.api.state.get_current_tab() ---@type fml.api.state.ITabItem|nil
    if tab == nil or #tab.bufnrs < 1 then
      return "", 0
    end

    local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
    local bufid_cur = fml.array.first(tab.bufnrs, bufnr_cur)
    if bufid_cur ~= nil then
      last_bufnr_cur = bufnr_cur
    else
      local bufid_last = fml.array.first(tab.bufnrs, last_bufnr_cur)
      bufid_cur = bufid_last or 1
    end

    local text, width = render_buf(tab.bufnrs[bufid_cur], true)
    remain_width = remain_width - width

    if remain_width < 0 then
      return "", 0
    end

    for i = bufid_cur - 1, 1, -1 do
      local t, w = render_buf(tab.bufnrs[i], false)
      remain_width = remain_width - w
      if remain_width >= 0 then
        text = t .. text
      end
    end
    for i = bufid_cur + 1, #tab.bufnrs, 1 do
      local t, w = render_buf(tab.bufnrs[i], false)
      remain_width = remain_width - w
      if remain_width >= 0 then
        text = text .. t
      end
    end
    return text, width
  end,
}

return M
