---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.startup" ---@type string

local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local harness = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))
package.path = harness .. "/?.lua;" .. package.path
local repo, directory, implementation = assert(arg[1]), assert(arg[2]), assert(arg[3])
local entries = assert(tonumber(arg[4]))
local suffix = vim.uv.os_uname().sysname == "Windows_NT" and "dll" or "so"
local library = vim.env[implementation == "legacy" and "NVIM_EXPLORER_BENCH_BASELINE_NATIVE" or "NVIM_EXPLORER_BENCH_NATIVE"]
  or repo .. "/lua/yoz." .. suffix
local started = vim.uv.hrtime()
local ui = require("__test__.support.ui").new({
  timeout_ms = 65000,
  init = repo .. "/init.lua",
  args = {
    "--cmd",
    string.format(
      "lua vim.g.explorer_test_root=%q; vim.g.explorer_test_directory=%q; vim.g.explorer_test_library=%q; vim.g.explorer_test_capture=true",
      repo,
      directory,
      library
    ),
    "--cmd",
    "lua dofile(" .. string.format("%q", harness .. "/__test__/fixtures/era/m/explorer/full_config_init.lua") .. ")",
  },
})
local active, visible
local observations, failure = {}, nil
ui.on_notification = function(method, args)
  if method == "explorer_bench_startup" then
    observations[args[1]] = args[2]
  elseif method == "explorer_bench_error" then
    failure = args[1]
  end
end
local grid = require("__test__.support.ui_grid").new(ui, function(screen)
  if active and not visible and screen:find("file-00001.txt") then
    visible = vim.uv.hrtime()
  end
end)

local ok, result = xpcall(function()
  ui:rpc("nvim_ui_attach", 110, 40, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    "startup_bench = assert(loadfile(...))(); startup_bench.configuration()",
    { here .. "/startup_runtime.lua" }
  )
  local sequence = ui._sequence
  assert(
    vim.wait(30000, function()
      assert(not failure, failure)
      return observations.startup ~= nil
    end, 10),
    "configuration startup did not finish"
  )
  local initialized = observations.startup.at
  local startup_rpcs = ui._sequence - sequence
  active = true
  local opened = vim.uv.hrtime()
  ui:rpc("nvim_exec_lua", "startup_bench.open(...)", { directory, entries, implementation == "native" })
  sequence = ui._sequence
  assert(
    vim.wait(30000, function()
      assert(not failure, failure)
      return observations.first_explorer ~= nil and visible
    end, 10),
    "first Explorer did not become ready"
  )
  local ready = math.max(observations.first_explorer.at, visible)
  local explorer_rpcs = ui._sequence - sequence
  local metadata = ui:rpc(
    "nvim_exec_lua",
    [[
    local metrics_path = ...
    assert(#explorer_bench_startup_errors == 0, vim.inspect(explorer_bench_startup_errors))
    assert(vim.v.errmsg == "", vim.v.errmsg)
    assert(not dot.context.behavior.auto_im:snapshot())
    local plugins = {}
    local state = require("era.m.plugin.state")
    for name, plugin in pairs(require("era.m.plugin.loader").get_all()) do
      local lock = state.get_lock(name)
      plugins[#plugins + 1] = { name = name, path = plugin.path, loaded = plugin.loaded,
        locked_commit = lock and lock.commit }
    end
    table.sort(plugins, function(left, right) return left.name < right.name end)
    collectgarbage("collect")
    return { plugins = plugins, plugin_lockfile = state.options.lockfile,
      memory = assert(loadfile(metrics_path))().memory(), runtimepath = vim.opt.runtimepath:get() }
  ]],
    { here .. "/metrics.lua" }
  )
  ui:rpc("nvim_exec_lua", "startup_bench.dispose()", {})
  return {
    schema_version = 2,
    scope = "startup",
    mode = "tree",
    implementation = implementation,
    operations = {
      {
        kind = "startup",
        ready_ms = (initialized - started) / 1000000,
        visible_ms = (visible - started) / 1000000,
        readiness_checks = observations.startup.checks,
        observer_rpcs = startup_rpcs,
      },
      {
        kind = "first_explorer",
        ready_ms = (ready - opened) / 1000000,
        visible_ms = (visible - opened) / 1000000,
        readiness_checks = observations.first_explorer.checks,
        observer_rpcs = explorer_rpcs,
      },
    },
    open_memory = metadata.memory,
    plugins = metadata.plugins,
    plugin_lockfile = metadata.plugin_lockfile,
    runtimepath = metadata.runtimepath,
    checks = { full_configuration = true, real_default_entry = true, errors = 0 },
  }
end, debug.traceback)
ui:close()
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
