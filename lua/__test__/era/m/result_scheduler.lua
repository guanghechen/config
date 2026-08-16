---@diagnostic disable: invisible
--- Run with: nvim -l lua/__test__/era/m/result_scheduler.lua

local harness = require("__test__.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.m result scheduler")

local CASES = {
  {
    name = "picker",
    new = era.m.picker.Result.new,
  },
  {
    name = "searcher",
    new = era.m.searcher.Result.new,
  },
}

---@param case                         { name: string, new: fun(props: table): table }
local function verify_schedule_counts(case)
  local result = case.new({
    uuid = "result-scheduler-" .. case.name,
    name = "result scheduler " .. case.name,
    draw = function(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "item" })
      return { lnum_current = 1, lnum_present = 1 }
    end,
    keymaps = {},
    flags = {},
  })

  local ok, err = pcall(function()
    result:create_buf()
    -- Flush the initial Observable notifications installed by Result.new before replacing the scheduler method.
    vim.wait(20)

    local schedule_count = 0 ---@type integer
    result._scheduler_lnum_current.schedule = function(self)
      schedule_count = schedule_count + 1
      return self
    end

    result.lnum_current:next(1)
    t.wait_until(function()
      return schedule_count > 0
    end, 1000, case.name .. " current-line observer did not run")
    vim.wait(10)
    t.assert_eq(1, schedule_count, case.name .. " direct current-line schedule count")

    schedule_count = 0
    result._scheduler_content._task()
    t.assert_eq(1, schedule_count, case.name .. " stable redraw schedule count")
  end)

  result:dispose()
  vim.wait(20)
  if not ok then
    error(err, 0)
  end
end

for _, case in ipairs(CASES) do
  t:test(case.name .. " result avoids duplicate cursor observers", function()
    verify_schedule_counts(case)
  end)
end

t:run()
