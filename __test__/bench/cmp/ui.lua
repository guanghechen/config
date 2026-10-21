---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp.ui" ---@type string

local Child = require("__test__.bench.cmp.child")
local Data = require("__test__.bench.cmp.data")
local M = {}

---@param ui                            __test__.support.UI
---@param recorder                      __test__.bench.cmp.IRecorder
---@param sequence                      integer
---@param start                         number
---@return table
local function await_menu(ui, recorder, sequence, start)
  local result = { menus = {} }
  local seen = 0
  assert(
    vim.wait(10000, function()
      while seen < #recorder.events do
        seen = seen + 1
        local event = recorder.events[seen]
        if event.method == "cmp_bench_menu" and event.args[1].sequence == sequence then
          result.menus[#result.menus + 1] = event.args[1]
        elseif event.method == "redraw" and #result.menus > 0 then
          for _, updates in ipairs(event.args) do
            if updates[1] == "flush" then
              result.flush_ms = (event.time - start) / 1e6
            end
          end
        end
      end
      return result.flush_ms ~= nil
    end, 1),
    "menu/UI timeout: " .. vim.inspect(ui:lua("return require('__test__.bench.cmp.editor').snapshot()"))
  )
  result.first_menu_ms = result.menus[1].elapsed_ms
  result.count = result.menus[#result.menus].count
  return result
end

---@param options                       table
---@return table
function M.run(options)
  local result = {
    cases = {},
    note = "attached 120x40 ext_multigrid UI; flush receipt includes IPC, not compositor/monitor latency; hooks contribute small shared instrumentation cost",
  }
  local scenarios = {
    { name = "lsp_1000", count = 1000 },
    { name = "lsp_10000", count = 10000 },
    { name = "lsp_50000", count = 50000 },
    { name = "frecency_10000", count = 10000, frecency = true },
    { name = "defaults_10000", count = 10000, defaults = true },
    { name = "incomplete_20ms", count = 1000, incomplete = true, delays = { 20 } },
    { name = "two_clients_0_30ms", count = 1000, delays = { 0, 30 } },
    { name = "buffer_and_lsp_20ms", count = 1000, buffer = 500, delays = { 20 } },
  }
  local sequence = 0
  for _, scenario in ipairs(scenarios) do
    io.stdout:write("  " .. scenario.name .. "\n")
    io.stdout:flush()
    local ui, recorder = Child.start()
    local ok, err = xpcall(function()
      local setup =
        ui:lua("return require('__test__.bench.cmp.editor').setup(...)", vim.tbl_extend("force", options, scenario))
      local samples, cold = {}, nil
      for sample = 1, options.iterations + 5 do
        ui:rpc("nvim_input", "<Esc>")
        ui:wait_until(function()
          return ui:rpc("nvim_get_mode").mode == "n"
        end, 1000)
        ui:lua("require('__test__.bench.cmp.editor').reset()")
        local steps = {}
        for step, query in ipairs({ "g", "ge", "get", "getC", "getCo" }) do
          sequence = sequence + 1
          recorder.events = {}
          local start = vim.uv.hrtime()
          ui:lua(
            "require('__test__.bench.cmp.editor').input(...)",
            sequence,
            step == 1 and "ig" or query:sub(-1),
            query
          )
          local measured = await_menu(ui, recorder, sequence, start)
          local state = ui:lua("return require('__test__.bench.cmp.editor').snapshot()")
          assert(state.errmsg == "", state.errmsg)
          measured.cost = state.active.cost
          measured.calls = state.active.calls
          measured.requests = state.active.requests
          measured.renders = state.active.renders
          measured.query = query
          measured.process_memory_bytes = state.process_memory_bytes
          measured.lua_heap_bytes = state.lua_heap_bytes
          steps[#steps + 1] = measured
          -- Allow the delayed second source to finish before measuring the next keystroke.
          if scenario.delays ~= nil then
            ui:lua("vim.wait(...)", 40)
            local settled = ui:lua("return require('__test__.bench.cmp.editor').snapshot()")
            measured.settled_cost = settled.active.cost
            measured.settled_calls = settled.active.calls
            measured.settled_renders = settled.active.renders
            for _, event in ipairs(recorder.events) do
              if event.method == "cmp_bench_menu" and event.args[1].sequence == sequence then
                measured.last_menu_ms = event.args[1].elapsed_ms
              end
            end
          else
            vim.wait(20)
          end
        end
        sequence = sequence + 1
        recorder.events = {}
        local start = vim.uv.hrtime()
        ui:lua("require('__test__.bench.cmp.editor').input(...)", sequence, "<Tab>", "getCo")
        ui:wait_until(function()
          return ui:lua("return vim.api.nvim_get_current_line()") ~= "getCo"
        end, 2000, "selection preview")
        local select_ms
        assert(
          vim.wait(2000, function()
            for _, event in ipairs(recorder.events) do
              if event.method == "cmp_bench_select" and event.args[1] == sequence then
                select_ms = event.args[2]
              end
            end
            return select_ms ~= nil
          end, 1),
          "selection notification timeout"
        )
        vim.wait(20)
        sequence = sequence + 1
        recorder.events = {}
        start = vim.uv.hrtime()
        ui:lua("require('__test__.bench.cmp.editor').input(...)", sequence, "<CR>", "getCo")
        local accept_ms
        assert(
          vim.wait(2000, function()
            for _, event in ipairs(recorder.events) do
              if event.method == "cmp_bench_accept" and event.args[1] == sequence then
                accept_ms = event.args[2]
              end
            end
            return accept_ms ~= nil
          end, 1),
          "accept timeout: " .. vim.inspect(ui:lua("return require('__test__.bench.cmp.editor').snapshot()"))
        )
        if sample > 5 then
          samples[#samples + 1] = { steps = steps, select_ms = select_ms, accept_ms = accept_ms }
        end
        if sample == 1 then
          cold = { steps = steps, select_ms = select_ms, accept_ms = accept_ms }
        end
        vim.wait(15)
      end
      local summary = {}
      for step = 1, 5 do
        local menus, frames, settled = {}, {}, {}
        for _, sample in ipairs(samples) do
          menus[#menus + 1] = sample.steps[step].first_menu_ms
          frames[#frames + 1] = sample.steps[step].flush_ms
          settled[#settled + 1] = sample.steps[step].last_menu_ms or sample.steps[step].first_menu_ms
        end
        summary[#summary + 1] = {
          query = samples[1].steps[step].query,
          menu_ms = Data.stats(menus),
          flush_ms = Data.stats(frames),
          settled_menu_ms = Data.stats(settled),
        }
      end
      result.cases[#result.cases + 1] = {
        scenario = scenario.name,
        engine = "era",
        setup = setup,
        summary = summary,
        iterations = samples,
        cold = cold,
      }
      vim.fn.writefile({ vim.json.encode(result) }, options.output .. "/ui.partial.json")
    end, debug.traceback)
    ui:close()
    assert(ok, err)
  end
  vim.fn.delete(options.output .. "/ui.partial.json")
  return result
end

return M
