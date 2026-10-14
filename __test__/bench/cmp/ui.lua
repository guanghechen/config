---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp.ui" ---@type string

local Data = require("__test__.bench.cmp.data")
local Rpc = require("__test__.support.rpc")
local M = {}

---@param rpc                           table
---@param sequence                      integer
---@param start                         number
---@return table
local function await_menu(rpc, sequence, start)
  local result = { menus = {} }
  local seen = 0
  assert(
    vim.wait(10000, function()
      while seen < #rpc.notifications do
        seen = seen + 1
        local event = rpc.notifications[seen]
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
    "menu/UI timeout: " .. vim.inspect(rpc:lua("return require('__test__.bench.cmp.editor').snapshot()"))
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
  for scenario_index, scenario in ipairs(scenarios) do
    local engines = scenario_index % 2 == 1 and { "era", "blink" } or { "blink", "era" }
    for _, engine in ipairs(engines) do
      io.stdout:write("  " .. scenario.name .. " / " .. engine .. "\n")
      io.stdout:flush()
      local rpc = Rpc.new(options.root)
      local ok, err = xpcall(function()
        rpc:request("nvim_ui_attach", { 120, 40, { ext_linegrid = true, ext_multigrid = true, rgb = true } })
        local setup = rpc:lua(
          [[
          local options = ...
          vim.opt.runtimepath:prepend(options.root)
          package.path = options.root .. '/?.lua;' .. options.root .. '/?/init.lua;' .. package.path
          return require('__test__.bench.cmp.editor').setup(options)
        ]],
          vim.tbl_extend("force", options, scenario, { engine = engine })
        )
        local samples, cold = {}, nil
        for sample = 1, options.samples + 5 do
          rpc:request("nvim_input", { "<Esc>" })
          assert(Rpc.wait(1000, function()
            return rpc:request("nvim_get_mode", {}).mode == "n"
          end, 1))
          rpc:lua("require('__test__.bench.cmp.editor').reset()")
          local steps = {}
          for step, query in ipairs({ "g", "ge", "get", "getC", "getCo" }) do
            sequence = sequence + 1
            rpc.notifications = {}
            local start = vim.uv.hrtime()
            rpc:lua(
              "require('__test__.bench.cmp.editor').input(...)",
              sequence,
              step == 1 and "ig" or query:sub(-1),
              query
            )
            local measured = await_menu(rpc, sequence, start)
            local state = rpc:lua("return require('__test__.bench.cmp.editor').snapshot()")
            assert(state.errmsg == "", state.errmsg)
            measured.cost = state.active.cost
            measured.calls = state.active.calls
            measured.requests = state.active.requests
            measured.renders = state.active.renders
            measured.query = query
            measured.rss_kib = state.rss_kib
            measured.lua_kib = state.lua_kib
            steps[#steps + 1] = measured
            -- Allow the delayed second source to finish before measuring the next keystroke.
            if scenario.delays ~= nil then
              rpc:lua("vim.wait(...)", 40)
              local settled = rpc:lua("return require('__test__.bench.cmp.editor').snapshot()")
              measured.settled_cost = settled.active.cost
              measured.settled_calls = settled.active.calls
              measured.settled_renders = settled.active.renders
              for _, event in ipairs(rpc.notifications) do
                if event.method == "cmp_bench_menu" and event.args[1].sequence == sequence then
                  measured.last_menu_ms = event.args[1].elapsed_ms
                end
              end
            else
              vim.wait(20)
            end
          end
          sequence = sequence + 1
          rpc.notifications = {}
          local start = vim.uv.hrtime()
          rpc:lua("require('__test__.bench.cmp.editor').input(...)", sequence, "<Tab>", "getCo")
          assert(
            Rpc.wait(2000, function()
              return rpc:lua("return vim.api.nvim_get_current_line()") ~= "getCo"
            end, 1),
            "selection preview timeout"
          )
          local select_ms
          assert(
            vim.wait(2000, function()
              for _, event in ipairs(rpc.notifications) do
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
          rpc.notifications = {}
          start = vim.uv.hrtime()
          rpc:lua("require('__test__.bench.cmp.editor').input(...)", sequence, "<CR>", "getCo")
          local accept_ms
          assert(
            vim.wait(2000, function()
              for _, event in ipairs(rpc.notifications) do
                if event.method == "cmp_bench_accept" and event.args[1] == sequence then
                  accept_ms = event.args[2]
                end
              end
              return accept_ms ~= nil
            end, 1),
            "accept timeout: " .. vim.inspect(rpc:lua("return require('__test__.bench.cmp.editor').snapshot()"))
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
          engine = engine,
          setup = setup,
          summary = summary,
          samples = samples,
          cold = cold,
        }
        vim.fn.writefile({ vim.json.encode(result) }, options.output .. "/ui.partial.json")
      end, debug.traceback)
      rpc:close()
      assert(ok, err)
    end
  end
  vim.fn.delete(options.output .. "/ui.partial.json")
  return result
end

return M
