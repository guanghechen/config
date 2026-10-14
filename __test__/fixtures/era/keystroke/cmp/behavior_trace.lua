---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.keystroke.cmp.behavior_trace" ---@type string

local Rpc = require("__test__.support.rpc")
local M = {}

---@param options                       table
---@param case                          table
---@return table[]
function M.run(options, case)
  local rpc = Rpc.new(options.root)
  local step_index = 0
  local states = {}
  local ok, err = xpcall(function()
    rpc:request("nvim_ui_attach", { 120, 40, { ext_linegrid = true, ext_multigrid = true, rgb = true } })
    rpc:lua(
      [[
      local options = ...
      vim.opt.runtimepath:prepend(options.root)
      package.path = options.root .. '/?.lua;' .. options.root .. '/?/init.lua;' .. package.path
      require('__test__.fixtures.era.keystroke.cmp.behavior').setup(options)
    ]],
      vim.tbl_extend("force", case.options or {}, options)
    )
    vim.wait(50)
    for index, step in ipairs(case.steps) do
      step_index = index
      local keys = type(step) == "string" and step or step.keys
      if keys ~= nil then
        rpc:request("nvim_input", { keys })
      elseif step.action == "cancel" then
        rpc:lua("require('__test__.fixtures.era.keystroke.cmp.behavior').cmp.cancel()")
      end
      vim.wait(type(step) == "table" and step.wait_ms or 100)
      local state = rpc:lua("return require('__test__.fixtures.era.keystroke.cmp.behavior').snapshot()")
      assert(state.errmsg == "", state.errmsg)
      assert(#state.notices == 0, vim.inspect(state.notices))
      states[#states + 1] = state
    end
  end, debug.traceback)
  if not ok then
    local mode_ok, mode = pcall(rpc.request, rpc, "nvim_get_mode", {})
    vim.fn.writefile(
      vim.split(
        vim.inspect({
          case = case.name,
          engine = options.engine,
          step = step_index,
          error = err,
          mode = mode_ok and mode or nil,
          stderr = rpc.stderr,
          events = vim.list_slice(rpc.notifications, math.max(1, #rpc.notifications - 80)),
        }),
        "\n",
        { plain = true }
      ),
      options.output .. "/failure.txt"
    )
  end
  rpc:close()
  assert(ok, err)
  return states
end

return M
