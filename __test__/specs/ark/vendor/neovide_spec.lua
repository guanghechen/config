local harness = require("__test__.support.harness")
local UI = require("__test__.support.ui")
local t = harness.new()

---@param neovide                       boolean
---@param scrolling                     ?boolean
---@return __test__.support.UI
local function start_runtime(neovide, scrolling)
  local ui = UI.new()
  t:defer(function()
    ui:close()
  end)
  ui:start({})
  ui:lua(
    [[
      local neovide, scrolling = ...
      vim.g.neovide = neovide and true or nil
      require("ark.bootstrap").setup()
      dot.context.flight.dressing_scroll:next(scrolling)
      require("ark.vendor." .. (neovide and "neovide" or "neovim") .. ".option")
      _G.neovide_test_initial = {
        font_was_set = vim.api.nvim_get_option_info2("guifont", {}).was_set,
        terminal_bg = vim.g.terminal_color_0,
        scroll_duration = vim.g.neovide_scroll_animation_length,
      }
    ]],
    neovide,
    scrolling ~= false
  )
  return ui
end

t:test("Neovide retains the shared font setting and disables cursor effects", function()
  local ui = start_runtime(true)

  t.assert_true(ui:lua("return neovide_test_initial.font_was_set"), "common font option remains explicit")
  t.assert_eq("Maple Mono NF CN", ui:lua("return vim.o.guifont"), "Neovide inherits the common font")
  t.assert_eq(0, ui:lua("return vim.g.neovide_cursor_animation_length"), "cursor moves immediately")
  t.assert_eq("", ui:lua("return vim.g.neovide_cursor_vfx_mode"), "cursor particle effects are disabled")
end)

t:test("terminal Neovim retains its common font option and owns no Neovide settings", function()
  local ui = start_runtime(false)

  t.assert_true(ui:lua("return neovide_test_initial.font_was_set"), "common font option remains explicit")
  t.assert_eq("Maple Mono NF CN", ui:lua("return vim.o.guifont"), "common font is unchanged")
  t.assert_true(ui:lua("return vim.g.neovide_scroll_animation_length == nil"), "no native scroll settings")
  t.assert_true(ui:lua("return vim.g.neovide_theme == nil"), "no GUI theme settings")
end)

t:test("terminal palette is initialized synchronously and follows theme changes", function()
  local ui = start_runtime(true)
  local initial_bg = ui:lua("return dot.context.theme.get_scheme('gruvbox-dark').palette.unified.bg0")
  local light_bg = ui:lua("return dot.context.theme.get_scheme('gruvbox-light').palette.unified.bg0")
  t.assert_true(initial_bg ~= light_bg, "theme transition changes the expected palette")
  t.assert_eq(initial_bg, ui:lua("return neovide_test_initial.terminal_bg"), "palette exists before TermOpen")
  t.assert_eq("bg_color", ui:lua("return vim.g.neovide_theme"), "GUI theme follows the rendered background")

  ui:lua("dot.context.theme.theme:next('gruvbox-light')")
  ui:wait_until(function()
    return ui:lua("return vim.g.terminal_color_0") == light_bg
  end, 1000, "new terminals did not receive the light theme palette")

  ui:lua("dot.context.theme.theme:next('gruvbox-dark')")
  ui:wait_until(function()
    return ui:lua("return vim.g.terminal_color_0") == initial_bg
  end, 1000, "new terminals did not receive the restored dark theme palette")
end)

t:test("native scrolling respects the workspace toggle at startup and after changes", function()
  local ui = start_runtime(true, false)
  t.assert_eq(0, ui:lua("return neovide_test_initial.scroll_duration"), "disabled state applies during startup")

  ui:lua("dot.context.flight.dressing_scroll:next(true)")
  ui:wait_until(function()
    return ui:lua("return vim.g.neovide_scroll_animation_length") == 0.3
  end, 1000, "workspace toggle did not enable native scrolling")

  ui:lua("dot.context.flight.dressing_scroll:next(false)")
  ui:wait_until(function()
    return ui:lua("return vim.g.neovide_scroll_animation_length") == 0
  end, 1000, "workspace toggle did not disable native scrolling")
end)

t:run()
