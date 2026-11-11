local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local bootstrap = require("__test__.support.bootstrap")

---A preview without keymaps, disposed when the case ends.
---@param props                         table
---@return era.view.PickerPreview
local function new_preview(props)
  local preview = era.view.PickerPreview.new(vim.tbl_extend("error", { keymaps = {} }, props))
  t:defer(function()
    preview:dispose()
  end)
  return preview
end

t:test("feature Preview modules alias the shared surface", function()
  t.assert_true(era.m.picker.Preview == era.view.PickerPreview, "picker Preview alias identity")
  t.assert_true(era.m.searcher.Preview == era.view.PickerPreview, "searcher Preview alias identity")
end)

t:test("shared preview applies picker number and diagnostic policies", function()
  local fail_draw = false ---@type boolean
  local reports = bootstrap.with_reporter(t)

  local preview = new_preview({
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
  })

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
  local reported = reports.error[#reports.error]
  t.assert_eq("shared preview contract -> contract.preview", reported and reported.from, "diagnostic scope")
  ---@diagnostic disable-next-line: assign-type-mismatch
  local bufnr = preview:get_bufnr() ---@type integer
  t.assert_false(vim.api.nvim_get_option_value("modifiable", { buf = bufnr }), "draw failure restores modifiable")
  t.assert_true(vim.api.nvim_get_option_value("readonly", { buf = bufnr }), "draw failure restores readonly")
end)

t:test("shared preview keeps searcher relative numbers disabled", function()
  local preview = new_preview({
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
  })

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

t:test("shared preview ignores a queued draw after dispose", function()
  local draw_count = 0 ---@type integer
  local preview = new_preview({
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
  })

  preview:create_buf()
  preview._scheduler_content:schedule({ immediate = true })
  preview:dispose()
  -- A draw queued before dispose would run within this window.
  vim.wait(20)

  t.assert_eq(0, draw_count, "queued draw count after dispose")
end)

t:test("preview cursorline follows range presence through redraws and reopening", function()
  local has_range
  local preview = new_preview({
    name = "preview range style",
    diagnostic_scope = "contract.preview",
    relative_number = false,
    draw = function()
      return { title = "preview", cursorline = true, has_range = has_range, number = false, wrap = false }
    end,
  })
  local normal = "CursorLine:m_pk_preview_current,TreeviewMatch:m_pk_matches"
  local range = "CursorLine:m_pk_preview_range_current,TreeviewMatch:m_pk_matches"
  local winopts = { border = "", winhighlight = normal }
  local dimension = { row = 0, col = 0, width = 20, height = 2 }
  local winnr = preview:create_win(winopts, dimension)
  t.assert_eq(normal, vim.api.nvim_get_option_value("winhighlight", { win = winnr }))

  has_range = true
  preview._scheduler_content._task()
  t.assert_eq(range, vim.api.nvim_get_option_value("winhighlight", { win = winnr }))
  preview:hide()
  winnr = preview:create_win(winopts, dimension)
  t.assert_eq(range, vim.api.nvim_get_option_value("winhighlight", { win = winnr }), "reopening retains range style")

  has_range = nil
  preview._scheduler_content._task()
  t.assert_eq(
    normal,
    vim.api.nvim_get_option_value("winhighlight", { win = winnr }),
    "ordinary previews restore the theme style"
  )
end)

t:run()
