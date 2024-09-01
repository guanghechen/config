local dirty = true ---@type boolean
local folded = false ---@type boolean
local last_tab_cur = 0 ---@type integer
local last_tab_count = 0 ---@type integer

---@type string
local fn_active_tab = fc.G.register_anonymous_fn(function(tabnr)
  if type(tabnr) == "number" and vim.api.nvim_tabpage_is_valid(tabnr) then
    fml.api.tab.go(tabnr)
  end
end) or ""

---@type string
local fn_toggle_tabs_folded = fc.G.register_anonymous_fn(function()
  folded = not folded
  dirty = true
  vim.cmd("redrawtabline")
end) or ""

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "tabs",
  will_change = function()
    local tab_cur = vim.fn.tabpagenr() ---@type integer
    local tab_count = vim.fn.tabpagenr("$") ---@type integer
    local changed = last_tab_cur ~= tab_cur or last_tab_count ~= tab_count ---@type boolean
    last_tab_cur = tab_cur
    last_tab_count = tab_count
    dirty = dirty or changed
    return dirty
  end,
  render = function()
    dirty = false

    if last_tab_count <= 1 then
      return "", 0
    end

    if folded then
      local text = " 󰅁 "
      local width = vim.fn.strwidth(text)
      local hl_text = fc.nvimbar.txt(text, "f_tl_tab_toggle")
      hl_text = fc.nvimbar.btn(hl_text, fn_toggle_tabs_folded)
      return hl_text, width
    end

    local text = " 󰅂 " ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    local hl_text = fc.nvimbar.txt(text, "f_tl_tab_toggle")
    hl_text = fc.nvimbar.btn(hl_text, fn_toggle_tabs_folded)

    local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
    for tabid = 1, last_tab_count, 1 do
      local hlname = last_tab_cur == tabid and "f_tl_tab_item_cur" or "f_tl_tab_item"
      text = " " .. tabid .. " "
      width = width + vim.fn.strwidth(text)
      local hl_text_inner = fc.nvimbar.txt(text, hlname)
      hl_text = hl_text .. fc.nvimbar.btn(hl_text_inner, fn_active_tab, tabnrs[tabid])
    end
    return hl_text, width
  end,
}

return M
