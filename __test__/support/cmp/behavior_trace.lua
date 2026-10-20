---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.cmp.behavior_trace" ---@type string

local UI = require("__test__.support.ui")
local M = {}

---@param options                       table
---@param case                          table
---@return table[]
function M.run(options, case)
  local ui = UI.new()
  local redraws = {} ---@type table[]
  ui.on_redraw = function(events)
    redraws[#redraws + 1] = events
  end
  local step_index = 0
  local states = {}
  local ok, err = xpcall(function()
    ui:start({ width = 120, height = 40, ui = { ext_multigrid = true } })
    ui:lua(
      [[
      local options = ...
      require('__test__.support.cmp.behavior').setup(options)
    ]],
      vim.tbl_extend("force", case.options or {}, options)
    )
    vim.wait(50)
    for index, step in ipairs(case.steps) do
      step_index = index
      local keys = type(step) == "string" and step or step.keys
      if keys ~= nil then
        ui:rpc("nvim_input", keys)
      elseif step.action == "cancel" then
        ui:lua("require('__test__.support.cmp.behavior').cmp.cancel()")
      end
      vim.wait(type(step) == "table" and step.wait_ms or 100)
      local state = ui:lua("return require('__test__.support.cmp.behavior').snapshot()")
      assert(state.errmsg == "", state.errmsg)
      assert(#state.notices == 0, vim.inspect(state.notices))
      states[#states + 1] = state
    end
  end, debug.traceback)
  if not ok then
    local mode_ok, mode = pcall(ui.rpc, ui, "nvim_get_mode")
    vim.fn.writefile(
      vim.split(
        vim.inspect({
          case = case.name,
          step = step_index,
          error = err,
          mode = mode_ok and mode or nil,
          stderr = ui.stderr,
          redraws = vim.list_slice(redraws, math.max(1, #redraws - 80)),
        }),
        "\n",
        { plain = true }
      ),
      options.output .. "/failure.txt"
    )
  end
  ui:close()
  assert(ok, err)
  return states
end

---Registers a case per behavior case; each asserts the fields its `expect` lists for every step.
---@param t                             __test__.support.Harness
---@param cases                         table[]
---@return nil
function M.check(t, cases)
  local output = t:tempdir()
  for _, case in ipairs(cases) do
    t:test(case.name, function()
      local states = M.run({ root = assert(vim.uv.cwd()), output = output }, case)
      for step, fields in pairs(case.expect) do
        for key, value in pairs(fields) do
          t.assert_same(value, states[step][key], string.format("step %d %s", step, key))
        end
      end
    end)
  end
end

return M
