---@diagnostic disable: invisible
--- Run with: nvim -l lua/__test__/era/m/result_scheduler.lua

local harness = require("__test__.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.m result scheduler")

local CASES = {
  {
    name = "picker",
    new = era.m.picker.Result.new,
    policy = {
      augroup_prefix = "picker.result",
      diagnostic_scope = "era.m.picker.result",
      winline_hl = "f_wl_picker",
    },
  },
  {
    name = "searcher",
    new = era.m.searcher.Result.new,
    policy = {
      augroup_prefix = "searcher.result",
      diagnostic_scope = "era.m.searcher.result",
      winline_hl = "f_wl_searcher",
    },
  },
}

t:test("picker Result aliases the shared surface", function()
  t.assert_true(era.m.picker.Result == era.view.PickerResult, "picker Result alias identity")
end)

t:test("searcher Result aliases the shared surface", function()
  t.assert_true(era.m.searcher.Result == era.view.PickerResult, "searcher Result alias identity")
end)

t:test("shared result applies status and diagnostic policies", function()
  local fail_draw = false ---@type boolean
  local reported_from = nil ---@type string|nil
  t:patch_table(stl.reporter, "error", function(report)
    reported_from = report.from
  end)

  local result = era.view.PickerResult.new({
    uuid = "shared-result-contract",
    name = "shared result contract",
    diagnostic_scope = "contract.result",
    augroup_prefix = "contract.result",
    winline_hl = "f_wl_searcher",
    status = function()
      return "READY", "picker_result_limit"
    end,
    draw = function(bufnr)
      if fail_draw then
        error("draw failure")
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "item" })
      return { lnum_current = 1 }
    end,
    keymaps = {},
    flags = {},
  })

  local ok, err = pcall(function()
    local winnr = result:create_win(
      { border = "", number = false, winhighlight = "" },
      { row = 0, col = 0, width = 40, height = 4 }
    )
    local winbar = vim.api.nvim_get_option_value("winbar", { win = winnr }) ---@type string
    t.assert_true(winbar:find("READY", 1, true) ~= nil, "shared result status")

    fail_draw = true
    result._scheduler_content._task()
    t.assert_eq("shared result contract -> contract.result", reported_from, "diagnostic scope")
    local bufnr = result:get_bufnr() ---@type integer
    t.assert_false(vim.api.nvim_get_option_value("modifiable", { buf = bufnr }), "draw failure restores modifiable")
    t.assert_true(vim.api.nvim_get_option_value("readonly", { buf = bufnr }), "draw failure restores readonly")

    result:dispose()
    local restore_ok, restore_err = pcall(result.__restore_cursor__, result, winnr)
    t.assert_true(restore_ok, "disposed cursor restore: " .. tostring(restore_err))
  end)

  if not result:isdisposed() then
    result:dispose()
  end
  vim.wait(20)
  if not ok then
    error(err, 0)
  end
end)

---@param case                         { name: string, new: fun(props: table): table, policy: table|nil }
local function verify_schedule_counts(case)
  local desired_lnum_current = 1 ---@type integer
  local desired_lnum_present = 1 ---@type integer
  local props = vim.tbl_extend("force", {
    uuid = "result-scheduler-" .. case.name,
    name = "result scheduler " .. case.name,
    draw = function(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "first", "second" })
      return { lnum_current = desired_lnum_current, lnum_present = desired_lnum_present }
    end,
    keymaps = {},
    flags = {},
  }, case.policy or {})
  local result = case.new(props)

  local ok, err = pcall(function()
    result:create_buf()
    vim.wait(50)
    result._scheduler_lnum_current:cancel()
    result._scheduler_lnum_present:cancel()

    local current_schedule_count = 0 ---@type integer
    local present_schedule_count = 0 ---@type integer
    result._scheduler_lnum_current.schedule = function(self)
      current_schedule_count = current_schedule_count + 1
      return self
    end
    result._scheduler_lnum_present.schedule = function(self)
      present_schedule_count = present_schedule_count + 1
      return self
    end

    result.lnum_current:next(2)
    result.lnum_present:next(2)
    t.wait_until(function()
      return current_schedule_count > 0 and present_schedule_count > 0
    end, 1000, case.name .. " line observers did not run")
    vim.wait(10)
    t.assert_eq(1, current_schedule_count, case.name .. " direct current-line schedule count")
    t.assert_eq(1, present_schedule_count, case.name .. " direct present-line schedule count")

    current_schedule_count = 0
    present_schedule_count = 0
    desired_lnum_current = 1
    desired_lnum_present = 1
    result._scheduler_content._task()
    t.wait_until(function()
      return current_schedule_count > 0 and present_schedule_count > 0
    end, 1000, case.name .. " changed redraw observers did not run")
    vim.wait(10)
    t.assert_eq(1, current_schedule_count, case.name .. " changed redraw current schedule count")
    t.assert_eq(1, present_schedule_count, case.name .. " changed redraw present schedule count")

    current_schedule_count = 0
    present_schedule_count = 0
    result._scheduler_content._task()
    vim.wait(10)
    t.assert_eq(1, current_schedule_count, case.name .. " stable redraw current schedule count")
    t.assert_eq(1, present_schedule_count, case.name .. " stable redraw present schedule count")
  end)

  result:dispose()
  vim.wait(20)
  if not ok then
    error(err, 0)
  end
end

for _, case in ipairs(CASES) do
  t:test(case.name .. " result schedules line signs once per update", function()
    verify_schedule_counts(case)
  end)
end

t:run()
