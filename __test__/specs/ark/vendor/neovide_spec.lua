---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ark.vendor.neovide" ---@type string

local harness = require("__test__.support.harness")
local t = harness.new("ark.vendor.neovide")

---@param neovide                       boolean
---@param scrolling                     ?boolean
---@return integer
local function start_runtime(neovide, scrolling)
  local channel = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-u", "NONE", "-i", "NONE", "-n" }, {
    rpc = true,
  })
  t.assert_true(channel > 0, "isolated Neovim started")
  t:defer(function()
    if vim.fn.jobwait({ channel }, 0)[1] == -1 then
      vim.fn.jobstop(channel)
      vim.fn.jobwait({ channel }, 1000)
    end
  end)

  vim.rpcrequest(
    channel,
    "nvim_exec_lua",
    [[
      local root, neovide, scrolling = ...
      vim.opt.runtimepath:prepend(root)
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
    { assert(vim.uv.cwd()), neovide, scrolling ~= false }
  )
  return channel
end

---@param channel                       integer
---@param code                          string
---@return any
local function eval(channel, code)
  return vim.rpcrequest(channel, "nvim_exec_lua", code, {})
end

t:test("Neovide retains the shared font setting and disables cursor effects", function()
  local channel = start_runtime(true)

  t.assert_true(eval(channel, "return neovide_test_initial.font_was_set"), "common font option remains explicit")
  t.assert_eq("Maple Mono NF CN", eval(channel, "return vim.o.guifont"), "Neovide inherits the common font")
  t.assert_eq(0, eval(channel, "return vim.g.neovide_cursor_animation_length"), "cursor moves immediately")
  t.assert_eq("", eval(channel, "return vim.g.neovide_cursor_vfx_mode"), "cursor particle effects are disabled")
end)

t:test("terminal Neovim retains its common font option and owns no Neovide settings", function()
  local channel = start_runtime(false)

  t.assert_true(eval(channel, "return neovide_test_initial.font_was_set"), "common font option remains explicit")
  t.assert_eq("Maple Mono NF CN", eval(channel, "return vim.o.guifont"), "common font is unchanged")
  t.assert_true(eval(channel, "return vim.g.neovide_scroll_animation_length == nil"), "no native scroll settings")
  t.assert_true(eval(channel, "return vim.g.neovide_theme == nil"), "no GUI theme settings")
end)

t:test("terminal palette is initialized synchronously and follows theme changes", function()
  local channel = start_runtime(true)
  local initial_bg = eval(channel, "return dot.context.theme.get_scheme('gruvbox-dark').palette.unified.bg0")
  local light_bg = eval(channel, "return dot.context.theme.get_scheme('gruvbox-light').palette.unified.bg0")
  t.assert_true(initial_bg ~= light_bg, "theme transition changes the expected palette")
  t.assert_eq(initial_bg, eval(channel, "return neovide_test_initial.terminal_bg"), "palette exists before TermOpen")
  t.assert_eq("bg_color", eval(channel, "return vim.g.neovide_theme"), "GUI theme follows the rendered background")

  eval(channel, "dot.context.theme.theme:next('gruvbox-light')")
  t.wait_until(function()
    return eval(channel, "return vim.g.terminal_color_0") == light_bg
  end, 1000, "new terminals did not receive the light theme palette")

  eval(channel, "dot.context.theme.theme:next('gruvbox-dark')")
  t.wait_until(function()
    return eval(channel, "return vim.g.terminal_color_0") == initial_bg
  end, 1000, "new terminals did not receive the restored dark theme palette")
end)

t:test("native scrolling respects the workspace toggle at startup and after changes", function()
  local channel = start_runtime(true, false)
  t.assert_eq(0, eval(channel, "return neovide_test_initial.scroll_duration"), "disabled state applies during startup")

  eval(channel, "dot.context.flight.dressing_scroll:next(true)")
  t.wait_until(function()
    return eval(channel, "return vim.g.neovide_scroll_animation_length") == 0.3
  end, 1000, "workspace toggle did not enable native scrolling")

  eval(channel, "dot.context.flight.dressing_scroll:next(false)")
  t.wait_until(function()
    return eval(channel, "return vim.g.neovide_scroll_animation_length") == 0
  end, 1000, "workspace toggle did not disable native scrolling")
end)

t:run()
