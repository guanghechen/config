---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.treeview_diffview" ---@type string
local root =
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
vim.api.nvim_set_current_dir(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local count = tonumber(arg[1]) or 10000
local iterations = tonumber(arg[2]) or 10
assert(count > 0 and iterations > 0, "expected positive file and sample counts")
local ui = require("__test__.support.ui").new({ timeout_ms = 60000 })

---@param expected                      integer
---@param started                       integer
---@return number
local function flushed(expected, started)
  local published
  assert(
    vim.wait(60000, function()
      local status = ui:rpc(
        "nvim_exec_lua",
        "return {rows=bench.owner:linecount(), published=bench.published, errors=bench.errors}",
        {}
      )
      assert(#status.errors == 0, vim.inspect(status.errors))
      published = status.published
      return status.rows == expected
        and published
        and published >= started
        and ui.last_flush
        and ui.last_flush >= published
    end, 1),
    "Diffview frame did not flush"
  )
  return (ui.last_flush - started) / 1e6
end

local ok, result = xpcall(function()
  ui:rpc("nvim_ui_attach", 100, 40, { rgb = true, ext_linegrid = true })
  local started = ui:rpc(
    "nvim_exec_lua",
    [[
    local root, count = ...
    vim.opt.runtimepath:prepend(root)
    package.cpath = root .. "/lua/?.so;" .. package.cpath
    require("ark.bootstrap").setup()
    bench = { errors = {}, imports = 0, plans = 0, icons = 0, directory_icons = 0 }
    stl.reporter.error = function(value) bench.errors[#bench.errors + 1] = value.message end
    dot.context.diffview.flag_panel_viewtype:next("tree", { silent=true })
    dot.context.diffview.flag_foldempty:next(false, { silent=true })
    local files = {}
    for index = 1, count do
      files[index] = {filepath=string.format("dir%04d/file%06d.lua", math.floor((index-1)/100), index), status="M"}
    end
    local commit = { hash="bench", abbrev_hash="bench", author="A", date=0, message="benchmark", files=files }
    local pane = require("era.m.diffview.pane.commits")
    local view = require("era.m.diffview.view.commits.view")
    local state = require("era.m.diffview.view.commits.state").State.new(vim.api.nvim_get_current_tabpage(), false)
    state:set_commits({commit})
    state:set_current_commit(commit)
    local bufnr = pane.create_buffer()
    vim.api.nvim_win_set_buf(0, bufnr)
    bench.owner = state:get_tree("commits")
    bench.ctx = {
      state=state,
      layout={ tabnr=state.tabnr, layout_type=2, commits_bufnr=bufnr, commits_winnr=vim.api.nvim_get_current_win() },
      render_winline=function() bench.published=vim.uv.hrtime() end,
    }
    local import, render, icon = bench.owner._import, pane.render, stl.fileicon.get_file_icon
    local directory_icon = stl.fileicon.get_directory_icon
    bench.owner._import = function(self, ...) bench.imports=bench.imports+1; return import(self, ...) end
    pane.render = function(...) bench.plans=bench.plans+1; return render(...) end
    stl.fileicon.get_file_icon = function(...) bench.icons=bench.icons+1; return icon(...) end
    stl.fileicon.get_directory_icon = function(...) bench.directory_icons=bench.directory_icons+1; return directory_icon(...) end
    local started = vim.uv.hrtime()
    view.render_commits(bench.ctx)
    return started
  ]],
    { root, count }
  )
  local initial = flushed(1, started)
  local expanded_rows = count + math.ceil(count / 100) + 1
  local materialization_started = ui:rpc(
    "nvim_exec_lua",
    [[
    local started = vim.uv.hrtime()
    require("era.m.diffview.view.commits.action").sbs_expand(bench.ctx)
    return started
  ]],
    {}
  )
  local materialization = flushed(expanded_rows, materialization_started)
  local collapsed = ui:rpc(
    "nvim_exec_lua",
    [[
    local started = vim.uv.hrtime()
    require("era.m.diffview.view.commits.action").sbs_collapse(bench.ctx)
    return started
  ]],
    {}
  )
  flushed(1, collapsed)
  ui:rpc("nvim_exec_lua", "bench.imports, bench.plans, bench.icons, bench.directory_icons = 0, 0, 0, 0", {})
  local samples = { expand = {}, collapse = {} }
  for _ = 1, iterations do
    for _, kind in ipairs({ "expand", "collapse" }) do
      local begin = ui:rpc(
        "nvim_exec_lua",
        [[
        local kind = ...
        local started = vim.uv.hrtime()
        require("era.m.diffview.view.commits.action")["sbs_" .. kind](bench.ctx)
        return started
      ]],
        { kind }
      )
      local elapsed = flushed(kind == "expand" and expanded_rows or 1, begin)
      samples[kind][#samples[kind] + 1] = elapsed
    end
  end
  local counters = ui:rpc(
    "nvim_exec_lua",
    "return {imports=bench.imports, plans=bench.plans, icons=bench.icons, directory_icons=bench.directory_icons}",
    {}
  )
  assert(counters.imports == 0 and counters.plans == 0, vim.inspect(counters))
  local metrics = {
    files = count,
    rows_expanded = expanded_rows,
    samples_per_action = iterations,
    initial_flush_ms = initial,
    first_expand_flush_ms = materialization,
    expansion_imports = counters.imports,
    expansion_plans = counters.plans,
    expansion_icon_lookups = counters.icons,
    expansion_directory_icon_lookups = counters.directory_icons,
  }
  for kind, timings in pairs(samples) do
    table.sort(timings)
    metrics[kind .. "_flush_p50_ms"] = timings[math.ceil(#timings * 0.5)]
    metrics[kind .. "_flush_p95_ms"] = timings[math.ceil(#timings * 0.95)]
  end
  return metrics
end, debug.traceback)
ui:close()
if not ok then
  error(result)
end
io.stdout:write(vim.json.encode(result), "\n")
