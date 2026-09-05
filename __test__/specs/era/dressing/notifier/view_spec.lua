--- Run with: nvim -l __test__/run.lua era/dressing/notifier/view_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
local module_name = "era.dressing.notifier.view"
local t = harness.new(module_name)

t:test("refresh updates history without readonly warnings and restores buffer protection", function()
  local tasks = { { level = "INFO", title = "Build", timestamp = 0, times = 1, lines = { "first body" } } }
  t:patch_global("stl", {
    e = require("stl.e"),
    filetype = require("stl.filetype"),
    icon = { loglevel = { INFO = "I" } },
    nvim = { fn = require("stl.nvim.fn") },
  })
  t:patch_global("dot", {
    win = {
      resolve_zindex = function()
        return 50
      end,
    },
    context = { theme = {
      get_float_winblend = function()
        return 0
      end,
    } },
  })
  t:patch_global("era", { dressing = { notifier = {
    history = function()
      return tasks
    end,
  } } })
  t:patch_table(package.loaded, module_name, nil)
  local view = require(module_name)
  t:defer(view.close)
  local previous_warning = vim.v.warningmsg
  t:defer(function()
    vim.v.warningmsg = previous_warning
  end)

  view.open()
  local bufnr = vim.api.nvim_get_current_buf()
  local refresh
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    if mapping.lhs == "r" then
      refresh = mapping.callback
    end
  end
  t.assert_eq("function", type(refresh), "refresh mapping")

  tasks = { { level = "INFO", title = "Updated", timestamp = 0, times = 1, lines = { "second body" } } }
  vim.v.warningmsg = ""
  refresh()
  t.assert_eq("", vim.v.warningmsg, "refresh warning")
  t.assert_eq("     second body", vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)[1], "updated content")
  t.assert_true(vim.api.nvim_get_option_value("readonly", { buf = bufnr }), "readonly restored")
  t.assert_false(vim.api.nvim_get_option_value("modifiable", { buf = bufnr }), "buffer protected")

  refresh()
  t.assert_eq("", vim.v.warningmsg, "repeated refresh warning")
end)

t:run()
