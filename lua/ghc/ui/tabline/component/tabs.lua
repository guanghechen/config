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


--- @type fml.types.ui.nvimbar.IRawComponent
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
      return ""
    end

    if last_folded then
      return fml.nvimbar.btn(" 󰅁 ", fn_toggle_tabs_folded, "f_tl_tab_toggle")
    end

    ---@type string[]
    local btns = { fml.nvimbar.btn(" 󰅂 ", fn_toggle_tabs_folded, "f_tl_tab_toggle") }

    for nr = 1, last_tab_count, 1 do
      local hlname = last_tab_cur == nr and "f_tl_tab_item_cur" or "f_tl_tab_item"
      table.insert(btns, fml.nvimbar.btn(" " .. nr .. " ", "fml.api.tab.goto_tab" .. nr, hlname))
    end
    -- table.insert(btns, fml.nvimbar.btn("  ", "fml.api.tab.new_tab", "f_tl_tab_add"))
    return table.concat(btns, '')
  end
}

return M
