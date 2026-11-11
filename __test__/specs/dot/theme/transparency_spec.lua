local harness = require("__test__.support.harness")
local t = harness.new()

t:patch_global("yoz", require("yoz"))
t:patch_global("stl", require("stl"))
t:patch_global("dot", require("dot"))
local theme = dot.context.theme

---Applies every registered theme with each of `transparencies` in turn, and calls `check` after each application.
---@param transparencies                boolean[]
---@param check                         fun(name: string, transparency: boolean, step: integer, scheme: any): nil
---@return nil
local function sweep(transparencies, check)
  for _, name in ipairs(dot.var.themes) do
    for step, transparency in ipairs(transparencies) do
      check(name, transparency, step, theme.apply_theme({ theme = name, transparency = transparency }))
    end
  end
end

t:test("registered themes apply through the highlight pipeline", function()
  sweep({ false, true }, function(name, _, _, scheme)
    t.assert_true(type(scheme) == "table", "failed to apply " .. name)
    local deprecated = vim.api.nvim_get_hl(0, { name = "CmpLabelDeprecated", link = false })
    t.assert_true(deprecated.strikethrough, "deprecated decoration for " .. name)
    t.assert_true(deprecated.fg == nil and deprecated.bg == nil, "native match and selection colors for " .. name)
  end)

  local applied ---@type dot.context.theme.ILoadThemeParams|nil
  t:patch_table(theme, "apply_theme", function(params)
    applied = params
  end)
  theme.reload_theme()
  t.assert_eq(theme.theme:snapshot(), applied and applied.theme, "reload theme")
  t.assert_eq(theme.transparency:snapshot(), applied and applied.transparency, "reload transparency")
end)

t:test("transparent floats preserve terminal-default backgrounds across themes", function()
  local groups = {
    "Normal",
    "NormalNC",
    "NormalFloat",
    "FloatNormal",
    "FloatBorder",
    "FloatTitle",
    "FloatActiveBorder",
    "FloatActiveTitle",
    "m_ex_bg",
    "m_ex_border",
    "m_pk_finder_normal",
    "m_pk_finder_prompt",
    "m_pk_result_normal",
    "m_pk_preview_normal",
    "m_bf_normal",
    "m_bk_normal",
    "m_ch_normal",
    "m_cp_normal",
    "m_in_normal",
    "m_nf_normal",
    "m_ghp_normal",
    "m_pl_normal",
    "m_term_bg",
    "m_wk_normal",
    "f_np_normal",
    "f_ut_normal",
    "f_up_normal",
    "f_up_border",
    "f_un_border_trace",
    "f_un_border_debug",
    "f_un_border_info",
    "f_un_border_warn",
    "f_un_border_error",
    "f_un_normal_info",
    "f_maximize_float_normal",
    "f_maximize_float_border",
    "MasonNormal",
    "CmpDoc",
    "CmpDocBorder",
    "CmpDocSeparator",
    "CmpSignatureHelp",
    "CmpSignatureHelpBorder",
  }

  sweep({ false, true }, function(name, transparency)
    for _, group in ipairs(groups) do
      local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
      t.assert_eq(transparency, hl.bg == nil, name .. "/" .. group)
    end
  end)
end)

t:test("transparent themes leave NormalNC empty so window switches keep cell attributes", function()
  sweep({ true, false }, function(name, transparency)
    if transparency then
      t.assert_true(vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = "NormalNC" })), name .. " transparent")
    else
      t.assert_true(vim.api.nvim_get_hl(0, { name = "NormalNC" }).bg ~= nil, name .. " opaque")
    end
  end)
end)

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
  local winnr = t:window(t:buffer(), { split = "right" }, true)

  vim.api.nvim__redraw({ valid = false, flush = true })
  vim.api.nvim__inspect_cell(1, 0, 0)
  -- The opaque background of each point, as the first opaque application of the current theme left it.
  local opaque_backgrounds = {}
  sweep({ false, true, false }, function(name, transparency, step)
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
      local context = name .. "/" .. point.name
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
        t.assert_nil(vim.api.nvim_get_hl(0, { name = group, link = false }).bg, name .. "/" .. group)
      end
    end
  end)
end)

t:test("fold badge stays opaque with transparent window backgrounds across themes", function()
  t:patch_global("__test_foldtext", require("era.dressing.foldtext").foldtext)

  local lines = { "size = 16" }
  for _ = 1, 20 do
    lines[#lines + 1] = "folded line"
  end
  local bufnr = t:buffer(lines)

  local winnrs = {}
  for _, split in ipairs({ "right", "below" }) do
    local winnr = t:window(bufnr, { split = split }, true)
    winnrs[#winnrs + 1] = winnr
    for name, value in pairs({
      number = false,
      relativenumber = false,
      signcolumn = "no",
      foldcolumn = "0",
      cursorline = false,
      wrap = false,
      foldmethod = "manual",
      foldtext = "v:lua.__test_foldtext()",
      winhighlight = "Normal:m_dv_normal",
    }) do
      vim.api.nvim_set_option_value(name, value, { win = winnr })
    end
    vim.cmd("1,$fold")
  end
  vim.api.nvim_set_current_win(winnrs[1])

  -- The first inspection enables hlstate; redraw afterward to refresh attribute IDs.
  vim.api.nvim__redraw({ valid = false, flush = true })
  vim.api.nvim__inspect_cell(1, 0, 0)

  ---@param winnr                       integer
  ---@param col                         integer
  ---@return table
  local function cell(winnr, col)
    local pos = vim.api.nvim_win_get_position(winnr)
    return vim.api.nvim__inspect_cell(1, pos[1], pos[2] + col)
  end

  local cap_col = vim.api.nvim_strwidth(lines[1]) + 2
  local text_col = cap_col + vim.api.nvim_strwidth(stl.icon.symbols.sep_left)
  local end_col = text_col + vim.api.nvim_strwidth("↙ 20 lines")
  sweep({ false, true }, function(name, transparency)
    vim.api.nvim__redraw({ valid = false, flush = true })

    for index, winnr in ipairs(winnrs) do
      local context = string.format("%s transparency=%s window=%d", name, transparency, index)
      local middle = cell(winnr, text_col)
      t.assert_eq("↙", middle[1], context .. ": fold badge is rendered")
      t.assert_eq(0, middle[2].blend or 0, context .. ": badge background remains opaque")
      t.assert_eq(cell(winnr, cap_col)[2].foreground, middle[2].background, context .. ": left cap matches")
      t.assert_eq(cell(winnr, end_col)[2].foreground, middle[2].background, context .. ": right cap matches")
    end

    local gap = cell(winnrs[2], cap_col - 1)
    t.assert_eq(0, gap[2].blend or 0, "ordinary window backgrounds do not use float blending")
  end)
end)

t:run()
