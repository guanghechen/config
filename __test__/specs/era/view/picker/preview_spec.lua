local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local bootstrap = require("__test__.support.bootstrap")
local picker = require("__test__.support.picker")
local treeview = require("__test__.support.treeview")

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

-- Each draw returns `result`, which also stands for the last draw `__update_winopts__` reads. With `failure`, a draw
-- then fails and must report from that scope.
for _, case in ipairs({
  {
    name = "shared preview applies picker number and diagnostic policies",
    preview = "shared preview contract",
    diagnostic_scope = "contract.preview",
    relative_number = true,
    result = { cursorline = false, number = false, title = "", wrap = false },
    initial = { number = true, relativenumber = true },
    updated = { number = false, relativenumber = false },
    failure = "shared preview contract -> contract.preview",
  },
  {
    name = "shared preview keeps searcher relative numbers disabled",
    preview = "shared searcher preview contract",
    diagnostic_scope = "era.m.searcher.preview",
    relative_number = false,
    result = { cursorline = true, number = true, title = "", wrap = false },
    initial = { number = true, relativenumber = false },
    updated = { number = true, relativenumber = false },
  },
}) do
  t:test(case.name, function()
    local fail_draw = false ---@type boolean
    local reports = case.failure and bootstrap.with_reporter(t)

    local preview = new_preview({
      name = case.preview,
      diagnostic_scope = case.diagnostic_scope,
      relative_number = case.relative_number,
      draw = function()
        if fail_draw then
          error("draw failure")
        end
        return vim.deepcopy(case.result)
      end,
    })

    local winnr = preview:create_win({ border = "", winhighlight = "" }, { row = 0, col = 0, width = 20, height = 2 })
    local number = vim.api.nvim_get_option_value("number", { win = winnr })
    t.assert_eq(case.initial.number, number, "initial absolute number")
    local relativenumber = vim.api.nvim_get_option_value("relativenumber", { win = winnr })
    t.assert_eq(case.initial.relativenumber, relativenumber, "initial relative number")

    preview._last_result = vim.deepcopy(case.result)
    preview:__update_winopts__()
    number = vim.api.nvim_get_option_value("number", { win = winnr })
    t.assert_eq(case.updated.number, number, "updated absolute number")
    relativenumber = vim.api.nvim_get_option_value("relativenumber", { win = winnr })
    t.assert_eq(case.updated.relativenumber, relativenumber, "updated relative number")

    if reports then
      fail_draw = true
      ---@diagnostic disable-next-line: missing-parameter
      preview._scheduler_content._task()
      local reported = reports.error[#reports.error]
      t.assert_eq(case.failure, reported and reported.from, "diagnostic scope")
      ---@diagnostic disable-next-line: assign-type-mismatch
      local bufnr = preview:get_bufnr() ---@type integer
      t.assert_false(vim.api.nvim_get_option_value("modifiable", { buf = bufnr }), "draw failure restores modifiable")
      t.assert_true(vim.api.nvim_get_option_value("readonly", { buf = bufnr }), "draw failure restores readonly")
    end
  end)
end

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

t:test("Preview switches between a native subtree and a file without closing its window", function()
  local tree = picker.file_tree(t)
  treeview.publish(tree)
  local target = { owner = tree, key = "dir", foldempty = true, title = "directory" }
  local draws = 0
  local preview = new_preview({
    name = "native preview",
    diagnostic_scope = "native preview",
    relative_number = false,
    tree = function()
      return target
    end,
    draw = function(bufnr, force)
      t.assert_true(force, "a new file buffer must force its first draw")
      draws = draws + 1
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "source content" })
      return { title = "file", cursorline = true, has_range = true, number = true, wrap = false }
    end,
  })
  local winhighlight = "Normal:NormalFloat,CursorLine:m_pk_preview_current,TreeviewMatch:IncSearch"
  local winnr = preview:create_win(
    { border = "none", winhighlight = winhighlight },
    { row = 0, col = 0, width = 40, height = 6 }
  )
  preview:mark_content_dirty()
  t.wait_until(function()
    return preview._tree_view and preview._tree_view:frame() ~= nil
  end, 5000)
  t.assert_eq(0, draws)
  t.assert_true(vim.api.nvim_buf_get_lines(preview:get_bufnr(), 0, 1, true)[1]:find("file.lua", 1, true) ~= nil)
  t.assert_eq(winhighlight, vim.api.nvim_get_option_value("winhighlight", { win = winnr }), "directory preview styles")
  target = nil
  preview:mark_content_dirty()
  t.wait_until(function()
    return draws == 1
  end, 5000)
  t.assert_true(vim.api.nvim_win_is_valid(winnr))
  t.assert_eq("source content", vim.api.nvim_buf_get_lines(preview:get_bufnr(), 0, 1, true)[1])
  t.assert_eq(
    "Normal:NormalFloat,CursorLine:m_pk_preview_range_current,TreeviewMatch:IncSearch",
    vim.api.nvim_get_option_value("winhighlight", { win = winnr }),
    "range preview uses its own cursorline style"
  )
  target = { owner = tree, key = "dir", foldempty = true, title = "directory" }
  preview:mark_content_dirty()
  t.wait_until(function()
    return preview._tree_view and preview._tree_view:frame() ~= nil
  end, 5000)
  t.assert_eq(winnr, preview:get_winnr())
  t.assert_eq(1, draws)
  t.assert_eq(winhighlight, vim.api.nvim_get_option_value("winhighlight", { win = winnr }), "restored directory styles")
end)

t:run()
