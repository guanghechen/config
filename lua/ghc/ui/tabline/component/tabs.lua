local dirty = true ---@type boolean
local last_folded = false ---@type boolean
local last_tab_cur = 0 ---@type integer
local last_tab_count = 0 ---@type integer

---@type string
local fn_toggle_tabs_folded = fml.G.register_anonymous_fn(function()
  last_folded = not last_folded
  dirty = true
  vim.cmd("redrawtabline")
end) or ""


---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "tabs",
  will_change = function()
    local tab_cur = vim.fn.tabpagenr() ---@type integer
    local tab_count = vim.fn.tabpagenr("$") ---@type integer
    local changed = last_tab_cur ~= tab_cur or last_tab_count ~= tab_count
    last_tab_cur = tab_cur
    last_tab_count = tab_count
    dirty = dirty or (not last_folded and changed)
    return dirty
  end,
  render = function()
    dirty = false

    if last_tab_count <= 1 then
      return "", 0
    end

    if last_folded then
      local text = " 󰅁 "
      local width = vim.fn.strwidth(text)
      local hl_text = fml.nvimbar.btn(text, fn_toggle_tabs_folded, "f_tl_tab_toggle")
      return hl_text, width
    end

    local text = " 󰅂 " ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    local hl_text = fml.nvimbar.btn(text, fn_toggle_tabs_folded, "f_tl_tab_toggle")

    for nr = 1, last_tab_count, 1 do
      local hlname = last_tab_cur == nr and "f_tl_tab_item_cur" or "f_tl_tab_item"
      text = " " .. nr .. " "
      width = width + vim.fn.strwidth(text)
      hl_text = hl_text .. fml.nvimbar.btn(text, "fml.api.tab.focus_" .. nr, hlname)
    end

    return hl_text, width
  end
}

return M
