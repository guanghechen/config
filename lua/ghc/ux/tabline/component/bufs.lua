---@type string
local fn_active_buf = eve.G.register_anonymous_fn(function(bufnr)
  if type(bufnr) == "number" and vim.api.nvim_buf_is_valid(bufnr) then
    eve.buf.go(bufnr)
  end
end) or ""

---@type string
local fn_focus_left_buf = eve.G.register_anonymous_fn(function()
  eve.commander.execute(eve.commander.uuids.buf_focus_left)
end) or ""

---@type string
local fn_focus_right_buf = eve.G.register_anonymous_fn(function()
  eve.commander.execute(eve.commander.uuids.buf_focus_right)
end) or ""

---@param bufnr                         integer
---@param is_current                    boolean
---@param is_first                      boolean
---@return string
---@return integer
local function render_buf(bufnr, is_current, is_first)
  local meta = eve.buf.resolve(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
  if meta == nil then
    return "", 0
  end

  local is_mod = vim.api.nvim_get_option_value("mod", { buf = bufnr }) ---@type boolean
  local is_pinned = meta.pinned ---@type boolean

  local text_indicator_or_sep = is_current and "▎" or (is_first and " " or "▏") ---@type string
  local text_icon = meta.fileicon .. " " ---@type string
  local text_title = meta.filename ---@type string
  local text_mod = is_pinned and (is_mod and "  " or "  ") or (is_mod and "  " or "  ") ---@type string

  local hl_indicator_or_sep = is_current and "f_tl_buf_indicator" or "f_tl_buf_sep" ---@type string
  local hl_title = is_current and "f_tl_buf_title_cur" or "f_tl_buf_title" ---@type string
  local hl_mod = is_current and "f_tl_buf_mod_cur" or "f_tl_buf_mod" ---@type string
  local hl_icon = meta.fileicon_hl .. (is_current and "_tl_buf_cur" or "_tl_buf") ---@type string

  local hl_text_indicator = eve.nvim.txt(text_indicator_or_sep, hl_indicator_or_sep)
  local hl_text_icon = eve.nvim.txt(text_icon, hl_icon)
  local hl_text_title = eve.nvim.txt(text_title, hl_title)
  local hl_text_mod = is_mod and eve.nvim.txt(text_mod, hl_mod) or text_mod

  local width = vim.api.nvim_strwidth(text_indicator_or_sep)
    + vim.api.nvim_strwidth(text_icon)
    + vim.api.nvim_strwidth(text_title)
    + vim.api.nvim_strwidth(text_mod)
  local hl_text = hl_text_indicator .. hl_text_icon .. hl_text_title .. hl_text_mod ---@type string
  return eve.nvim.btn(hl_text, fn_active_buf, bufnr), width
end

---@type fml.t.ux.nvimbar.IRawComponent
local M = {
  name = "bufs",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local meta = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
    if meta == nil then
      return "", 0
    end

    local tab_bufnrs = meta.bufnrs ---@type integer[]
    local N = #tab_bufnrs ---@type integer
    if N < 1 then
      return "", 0
    end

    local bufnr_cur = eve.locations.get_current_bufnr() ---@type integer|nil
    local bufid_src = eve.util.find_index(tab_bufnrs, bufnr_cur) ---@type integer|nil
    local bufid_cur = tab_bufnrs[bufid_src or 1]

    local text, width = render_buf(tab_bufnrs[bufid_cur], bufid_src ~= nil, bufid_cur == 1)
    if remain_width < width then
      return "", 0
    end

    local left_remain_count = bufid_cur - 1 ---@type integer
    local right_remain_count = N - bufid_cur ---@type integer
    local left_omitter_width = bufid_cur == 1 and 0 or 7 ---@type integer
    local right_omitter_width = bufid_cur == N and 0 or 7 ---@type integer

    ---! Render left bufs as many as possible.
    do
      local available_width = remain_width - left_omitter_width - right_omitter_width ---@type integer
      for i = bufid_cur - 1, 1, -1 do
        local t, w = render_buf(tab_bufnrs[i], false, i == 1)
        local width_next = width + w ---@type integer

        if i == 1 then
          if available_width + left_omitter_width >= width_next then
            text = t .. text
            width = width_next
            left_remain_count = 0
            left_omitter_width = 0
          end
          break
        end

        if available_width < width_next then
          break
        end

        text = t .. text
        width = width_next
        left_remain_count = left_remain_count - 1
      end
    end

    ---! Render right bufs as many as possible.
    do
      local available_width = remain_width - left_omitter_width - right_omitter_width ---@type integer
      for i = bufid_cur + 1, N, 1 do
        local t, w = render_buf(tab_bufnrs[i], false, false)
        local width_next = width + w ---@type integer

        if i == N then
          if available_width + right_omitter_width >= width_next then
            text = text .. t
            width = width_next
            right_remain_count = 0
            right_omitter_width = 0
          end
          break
        end

        if available_width < width_next then
          break
        end

        text = text .. t
        width = width_next
        right_remain_count = right_remain_count - 1
      end
    end

    ---! Render left omitter.
    if left_omitter_width > 0 then
      local count = math.min(99, left_remain_count) ---@type integer
      local omitter_text = " " .. eve.icons.ui.Left .. "  " .. tostring(count) .. " " ---@type string
      local omitter_text_hl = eve.nvim.txt(omitter_text, "f_tl_buf_ommitter") ---@type string
      text = eve.nvim.btn(omitter_text_hl, fn_focus_left_buf) .. text
      width = width + vim.api.nvim_strwidth(omitter_text)
    end

    ---! Render right omitter.
    if right_omitter_width > 0 then
      local count = math.min(99, right_remain_count) ---@type integer
      local omitter_text = "▏" .. tostring(count) .. " " .. eve.icons.ui.Right .. "  " ---@type string
      local omitter_text_hl = eve.nvim.txt("▏", "f_tl_buf_ommitter_sep")
        .. eve.nvim.txt(tostring(count) .. " " .. eve.icons.ui.Right .. "  ", "f_tl_buf_ommitter") ---@type string
      text = text .. eve.nvim.btn(omitter_text_hl, fn_focus_right_buf)
      width = width + vim.api.nvim_strwidth(omitter_text)
    end

    return text, width
  end,
}

return M
