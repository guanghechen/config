--- Run with: nvim -l __test__/run.lua __test__/specs/era/view/picker/preview_spec.lua
---@diagnostic disable: invisible

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.view.picker.preview")

t:test("feature Preview modules alias the shared surface", function()
  t.assert_true(era.m.picker.Preview == era.view.PickerPreview, "picker Preview alias identity")
  t.assert_true(era.m.searcher.Preview == era.view.PickerPreview, "searcher Preview alias identity")
end)

t:test("shared preview applies picker number and diagnostic policies", function()
  local fail_draw = false ---@type boolean
  local reported_from = nil ---@type string|nil
  t:patch_table(stl.reporter, "error", function(report)
    reported_from = report.from
  end)

  local preview = era.view.PickerPreview.new({
    name = "shared preview contract",
    diagnostic_scope = "contract.preview",
    relative_number = true,
    draw = function()
      if fail_draw then
        error("draw failure")
      end
      return {
        cursorline = false,
        number = false,
        title = "",
        wrap = false,
      }
    end,
    keymaps = {},
  })

  local ok, err = pcall(function()
    local winnr = preview:create_win({ border = "", winhighlight = "" }, { row = 0, col = 0, width = 20, height = 2 })
    t.assert_true(vim.api.nvim_get_option_value("number", { win = winnr }), "initial absolute number")
    t.assert_true(vim.api.nvim_get_option_value("relativenumber", { win = winnr }), "initial relative number")

    preview._last_result = {
      cursorline = false,
      number = false,
      title = "",
      wrap = false,
    }
    preview:__update_winopts__()
    t.assert_false(vim.api.nvim_get_option_value("number", { win = winnr }), "updated absolute number")
    t.assert_false(vim.api.nvim_get_option_value("relativenumber", { win = winnr }), "updated relative number")

    fail_draw = true
    ---@diagnostic disable-next-line: missing-parameter
    preview._scheduler_content._task()
    t.assert_eq("shared preview contract -> contract.preview", reported_from, "diagnostic scope")
    ---@diagnostic disable-next-line: assign-type-mismatch
    local bufnr = preview:get_bufnr() ---@type integer
    t.assert_false(vim.api.nvim_get_option_value("modifiable", { buf = bufnr }), "draw failure restores modifiable")
    t.assert_true(vim.api.nvim_get_option_value("readonly", { buf = bufnr }), "draw failure restores readonly")
  end)

  preview:dispose()
  vim.wait(20)
  if not ok then
    error(err, 0)
  end
end)

t:test("shared preview keeps searcher relative numbers disabled", function()
  local preview = era.view.PickerPreview.new({
    name = "shared searcher preview contract",
    diagnostic_scope = "era.m.searcher.preview",
    relative_number = false,
    draw = function()
      return {
        cursorline = true,
        number = true,
        title = "",
        wrap = false,
      }
    end,
    keymaps = {},
  })

  local ok, err = pcall(function()
    local winnr = preview:create_win({ border = "", winhighlight = "" }, { row = 0, col = 0, width = 20, height = 2 })
    t.assert_true(vim.api.nvim_get_option_value("number", { win = winnr }), "initial absolute number")
    t.assert_false(vim.api.nvim_get_option_value("relativenumber", { win = winnr }), "initial relative number")

    preview._last_result = {
      cursorline = true,
      number = true,
      title = "",
      wrap = false,
    }
    preview:__update_winopts__()
    t.assert_true(vim.api.nvim_get_option_value("number", { win = winnr }), "updated absolute number")
    t.assert_false(vim.api.nvim_get_option_value("relativenumber", { win = winnr }), "updated relative number")
  end)

  preview:dispose()
  vim.wait(20)
  if not ok then
    error(err, 0)
  end
end)

t:test("shared preview ignores a queued draw after dispose", function()
  local draw_count = 0 ---@type integer
  local preview = era.view.PickerPreview.new({
    name = "shared disposed preview contract",
    diagnostic_scope = "contract.preview",
    relative_number = false,
    draw = function()
      draw_count = draw_count + 1
      return {
        cursorline = false,
        number = false,
        title = "",
        wrap = false,
      }
    end,
    keymaps = {},
  })

  preview:create_buf()
  preview._scheduler_content:schedule({ immediate = true })
  preview:dispose()
  vim.wait(20)

  t.assert_eq(0, draw_count, "queued draw count after dispose")
end)

t:run()
