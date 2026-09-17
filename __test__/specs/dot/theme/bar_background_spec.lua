---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.dot.theme.bar_background" ---@type string

local harness = require("__test__.support.harness")
local t = harness.new("dot.theme bar backgrounds")

t:patch_global("yoz", require("yoz"))
t:patch_global("stl", require("stl"))
t:patch_global("dot", require("dot"))

t:test("transparent statusline and tabline preserve badges without filling their backgrounds", function()
  local options = {
    laststatus = 2,
    showtabline = 2,
    statusline = "%#f_sl_nvim_mode_text#M%#f_sl_text#SL%#f_sl_bg#%=",
    tabline = "%#f_tl_nvim_tabtype_text#T%#f_tl_text#TL%#f_tl_bg#%=",
  }
  for name, value in pairs(options) do
    local original = vim.api.nvim_get_option_value(name, { scope = "global" })
    t:defer(function()
      vim.api.nvim_set_option_value(name, original, { scope = "global" })
    end)
    vim.api.nvim_set_option_value(name, value, { scope = "global" })
  end

  local original_winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  local winnr = vim.api.nvim_open_win(bufnr, true, { split = "right" })
  t:defer(function()
    vim.api.nvim_win_close(winnr, true)
  end)

  vim.api.nvim__redraw({ valid = false, flush = true })
  vim.api.nvim__inspect_cell(1, 0, 0)
  for _, theme in ipairs(dot.var.themes) do
    local opaque_backgrounds = {}
    for step, transparency in ipairs({ false, true, false }) do
      dot.context.theme.apply_theme({ theme = theme, transparency = transparency })
      vim.api.nvim__redraw({ valid = false, flush = true })
      local points = { { name = "tabline", row = 0, col = 0, badge = "T" } }
      for index, current_winnr in ipairs({ original_winnr, winnr }) do
        local pos = vim.api.nvim_win_get_position(current_winnr)
        points[#points + 1] = {
          name = index == 1 and "inactive statusline" or "active statusline",
          row = pos[1] + vim.api.nvim_win_get_height(current_winnr),
          col = pos[2],
          badge = "M",
        }
      end
      for _, point in ipairs(points) do
        local context = theme .. "/" .. point.name
        local blank = vim.api.nvim__inspect_cell(1, point.row, point.col + 3)
        local badge = vim.api.nvim__inspect_cell(1, point.row, point.col)
        t.assert_eq(" ", blank[1], context .. ": background cell")
        t.assert_eq(point.badge, badge[1], context .. ": badge cell")
        t.assert_true(badge[2].background ~= nil, context .. ": badge keeps its color")
        if transparency then
          t.assert_nil(blank[2].background, context .. ": terminal-default background")
        elseif step == 1 then
          opaque_backgrounds[point.name] = blank[2].background
        else
          t.assert_eq(opaque_backgrounds[point.name], blank[2].background, context .. ": opaque background restored")
        end
      end
      if transparency then
        for _, group in ipairs({ "StatusLine", "StatusLineNC", "TabLine", "TabLineFill", "TabLineSel" }) do
          t.assert_nil(vim.api.nvim_get_hl(0, { name = group, link = false }).bg, theme .. "/" .. group)
        end
      end
    end
  end
end)

t:run()
