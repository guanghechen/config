-- Usage, from the repository root:
-- nvim -l __test__/bench/treeview/decorations.lua [scenario=all] [processes=5] [iterations=300] [baseline-root] [gc=natural|stopped]
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.treeview.decorations" ---@type string

local root = vim.fs.dirname(
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
)
vim.api.nvim_set_current_dir(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local only = arg[1] or "all"
local processes = tonumber(arg[2]) or 5
local iterations = tonumber(arg[3]) or 300
local baseline = arg[4] and arg[4] ~= "" and assert(vim.uv.fs_realpath(arg[4]), "missing baseline root") or root
local gc = arg[5] or "natural"
local warmups = 30
local native = root .. "/lua/yoz.so"
assert(processes >= 1 and iterations >= 1, "invalid benchmark dimensions")
assert(gc == "natural" or gc == "stopped", "gc is natural or stopped")
local UI = require("__test__.support.ui")
local Git = require("__test__.support.git")
local Record = require("__test__.bench.lib.record")
local Stats = require("__test__.bench.lib.stats")

-- Runs before any module loads so that providers registered at load time are timed, and both variants share the
-- native library of this checkout.
local PRELUDE = [=[
  local code_root, native = ...
  vim.opt.runtimepath:prepend(code_root)
  yoz = assert(package.loadlib(native, "luaopen_yoz"))()
  package.loaded.yoz = yoz
  bench = { provider_ns = 0, errors = {} }
  local timed = { ["ux.treeview"] = true, ["ux.filetree.annotations"] = true, ["era.explorer"] = true }
  local register = vim.api.nvim_set_decoration_provider
  vim.api.nvim_set_decoration_provider = function(namespace, callbacks)
    local name
    for key, id in pairs(vim.api.nvim_get_namespaces()) do
      if id == namespace then
        name = key
      end
    end
    if timed[name] then
      for _, event in ipairs({ "on_start", "on_buf", "on_win", "on_line", "on_range", "on_end" }) do
        local callback = callbacks[event]
        if callback then
          callbacks[event] = function(...)
            local started = vim.uv.hrtime()
            local result = callback(...)
            bench.provider_ns = bench.provider_ns + vim.uv.hrtime() - started
            return result
          end
        end
      end
    end
    return register(namespace, callbacks)
  end
  function bench.await(future)
    assert(vim.wait(30000, function() return future:is_done() end, 1), "future timed out")
    assert(not future:is_failed(), future:get_error())
    return future:get_result()
  end
  -- A stopped collector shows the decoration work itself; a natural one also shows where collection lands.
  function bench.measure(iterations, warmups, stopped)
    local redraw, provider = {}, {}
    if stopped then
      collectgarbage("collect")
      collectgarbage("stop")
    end
    for index = 1, warmups + iterations do
      bench.provider_ns = 0
      local started = vim.uv.hrtime()
      vim.api.nvim__redraw({ win = bench.winnr, valid = false, flush = true })
      local elapsed = vim.uv.hrtime() - started
      if index > warmups then
        redraw[#redraw + 1] = elapsed / 1e6
        provider[#provider + 1] = bench.provider_ns / 1e6
      end
    end
    collectgarbage("restart")
    return { redraw = redraw, provider = provider }
  end
  function bench.census()
    local counts = { marks = 0, right_align = 0, overlay = 0, highlight = 0, truncated = 0 }
    local truncated = bench.view._glyphs.truncated
    local set_extmark = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(bufnr, namespace, row, col, options)
      if bufnr == bench.bufnr and options.ephemeral then
        counts.marks = counts.marks + 1
        if options.virt_text_pos == "right_align" then
          counts.right_align = counts.right_align + 1
          if truncated and options.virt_text[1][1] == truncated then
            counts.truncated = counts.truncated + 1
          end
        elseif options.virt_text_pos == "overlay" then
          counts.overlay = counts.overlay + 1
        else
          counts.highlight = counts.highlight + 1
        end
      end
      return set_extmark(bufnr, namespace, row, col, options)
    end
    local ok, failure = pcall(vim.api.nvim__redraw, { win = bench.winnr, valid = false, flush = true })
    vim.api.nvim_buf_set_extmark = set_extmark
    assert(ok, failure)
    local info = vim.fn.getwininfo(bench.winnr)[1]
    counts.rows = math.min(info.height, bench.view:frame():header().row_count - info.topline + 1)
    counts.width = info.width - info.textoff
    return counts
  end
  -- Ready means published with decorations prepared; settled additionally waits out late annotations.
  function bench.settled(ms)
    if not bench.ready() then
      return false
    end
    local view = bench.view
    local key = view:frame():id() .. ":" .. tostring(view._filetree_annotation_key)
    vim.wait(ms, function() return false end, 10)
    return bench.ready() and key == view:frame():id() .. ":" .. tostring(view._filetree_annotation_key)
  end
]=]

---@class __test__.bench.treeview.decorations.IState
---@field name                          string
---@field apply                         ?string Child code switching to this state.
---@field ready                         ?string Child code returning true once the state is published.

---@class __test__.bench.treeview.decorations.IScenario
---@field name                          string
---@field ui                            integer[]
---@field data                          string
---@field setup                         string Child code defining bench.ready() and, once ready, bench.view/winnr/bufnr.
---@field args                          fun(): any[]
---@field states                        ?__test__.bench.treeview.decorations.IState[]

-- Real file names and contents of this checkout, committed and then edited, so status and numstat come from Git.
---@return string
local function git_files_repo()
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  local archive = Git.run(root, { "archive", "--format=tar", "HEAD", "lua/era/m" })
  local extracted = vim.system({ "tar", "-x", "-C", directory }, { stdin = archive }):wait(30000)
  assert(extracted.code == 0, extracted.stderr)
  Git.run(directory, { "init", "-q" })
  Git.run(directory, { "add", "." })
  Git.run(directory, { "commit", "-qm", "fixture" })
  for index, path in
    ipairs(vim.fs.find(function(name)
      return name:match("%.lua$") ~= nil
    end, { path = directory .. "/lua", type = "file", limit = math.huge }))
  do
    local lines = vim.fn.readfile(path)
    lines[#lines + 1] = string.format("-- benchmark edit %d", index)
    vim.fn.writefile(lines, path)
  end
  return directory
end

---@type __test__.bench.treeview.decorations.IScenario[]
local scenarios = {
  {
    name = "explorer",
    ui = { 120, 50 },
    data = "this checkout, lua/, lua/era/ and lua/era/fn/ expanded, Git status and three diagnostics, width 30",
    args = function()
      return { root, 30 }
    end,
    setup = [=[
      local path, width = ...
      stl, dot, era = require("stl"), require("dot"), require("era")
      dot.path.workspace = function() return path end
      dot.path.is_git_repo = function() return true end
      stl.reporter.warn = function(value) bench.errors[#bench.errors + 1] = value.message end
      stl.reporter.error = stl.reporter.warn
      stl.reporter.info = function() end
      local Observable = require("stl.c.observable")
      local widget = require("era.m.explorer.widget").new({
        name = "decorations-bench", root = path, o_width = Observable.from_value(width),
      })
      widget:focus()
      assert(vim.wait(30000, function()
        local ok, _, current = pcall(widget.context, widget)
        return ok and current ~= nil and current:frame() ~= nil
      end, 1), "the Explorer did not publish")
      local session, view = widget:context()
      for _, relative in ipairs({ "lua", "lua/era", "lua/era/fn" }) do
        local resource = bench.await(session.data:resolve(path .. "/" .. relative))
        bench.await(session.state:set_expanded({ resource:node() }, true, false))
      end
      for index, relative in ipairs({ "lua/era/fn/find-lsp-symbols.lua", "lua/era/fn/search-in-files.lua",
        "lua/era/fn/run-code-as-neovim-command.lua" }) do
        bench.await(session.data:set_diagnostics(1, index, 1, path .. "/" .. relative, { index, index - 1, 0, 1 }))
      end
      bench.session = session
      bench.selected = bench.await(session.data:resolve(path .. "/lua/era/fn/find-lsp-symbols.lua")):node()
      bench.view, bench.winnr, bench.bufnr = view, view.winnr, view.bufnr
      function bench.ready()
        local frame = view:frame()
        return frame ~= nil and frame:header().row_count >= 70 and not view:status().preparing
          and view._latest == nil and view._filetree_annotations ~= nil
      end
    ]=],
    states = {
      { name = "no selection" },
      {
        name = "selection",
        apply = [=[ bench.selecting = bench.session.state:select_node({ bench.selected }, false) ]=],
        ready = [=[ return bench.selecting:is_done() and not bench.view:frame():header().summary.is_empty ]=],
      },
    },
  },
  {
    name = "results",
    ui = { 100, 40 },
    data = "ResultFiles tree of this checkout's git ls-files, full window",
    args = function()
      return { root }
    end,
    setup = [=[
      local path = ...
      require("ark.bootstrap").setup()
      stl.reporter.error = function(value) bench.errors[#bench.errors + 1] = value.message end
      local paths = vim.fn.systemlist({ "git", "--no-optional-locks", "-C", path, "ls-files" })
      local Source = require("era.view.result_paths")
      local owner = require("era.view.result_files").new({ name = "decorations-bench", tree = Source.new() })
      owner:reset_filepaths(path, paths, false)
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, bufnr)
      owner:mount(vim.api.nvim_get_current_win(), bufnr, function() end)
      owner:publish({ mode = "tree", rootuuid = Source.key(path), foldempty = true })
      function bench.ready()
        local view = owner.view
        if not (owner:is_current() and view and view:frame() and not view:status().preparing) then
          return false
        end
        bench.view, bench.winnr, bench.bufnr = view, view.winnr, view.bufnr
        return true
      end
    ]=],
  },
  {
    name = "git_files",
    ui = { 140, 42 },
    data = "Git Files Unstaged pane on a repository of this checkout's lua/era/m with every Lua file edited",
    args = function()
      return { git_files_repo() }
    end,
    setup = [=[
      local repo = ...
      require("ark.bootstrap").setup()
      stl.reporter.error = function(value) bench.errors[#bench.errors + 1] = value.message end
      stl.reporter.warn = stl.reporter.error
      dot.path.workspace = function() return repo end
      dot.path.is_git_repo = function() return true end
      era.m.git.state.refresh_index = function() return stl.c.Future.resolve() end
      local widget = require("era.m.git_files").new()
      widget:toggle()
      function bench.ready()
        local pane = widget.panes.unstaged
        local view = pane.tree.view
        if widget._request ~= nil or not view or not view:frame() or view:status().preparing then
          return false
        end
        bench.view, bench.winnr, bench.bufnr = view, pane.result:get_winnr(), view.bufnr
        return true
      end
    ]=],
  },
  {
    name = "synthetic",
    ui = { 80, 50 },
    data = "50,001-node eight-way tree, labels of 11-100 bytes, right text on every row",
    args = function()
      return { 50000 }
    end,
    setup = [=[
      local count = ...
      stl = { c = { Future = require("stl.c.future") }, nvim = { fn = require("stl.nvim.fn") },
        reporter = { error = function(options) bench.errors[#bench.errors + 1] = options.message end } }
      local treeview = require("ux.treeview")
      data = treeview.new_data({ limits = { memory_bytes = 1024 * 1024 * 1024, nodes = count + 1,
        batch_nodes = count + 1, batch_bytes = 128 * 1024 * 1024 } })
      local upload = data:begin_import()
      local records = { { key = "root", label = "root", can_expand = true } }
      for index = 1, count do
        records[#records + 1] = {
          key = "n" .. index, parent = index == 1 and "root" or "n" .. math.floor((index - 2) / 8 + 1),
          label = string.format("node-%06d", index) .. string.rep("x", index * 37 % 90),
          right_text = tostring(index % 1000), can_expand = index * 8 - 6 <= count,
        }
        if #records == 512 then
          assert(upload:append(records).kind == "NoChange")
          records = {}
        end
      end
      if #records > 0 then
        assert(upload:append(records).kind == "NoChange")
      end
      bench.await(upload:commit())
      state = bench.await(data:create_state({ kind = "children_of", node = data:source():id("root") }))
      bench.await(state:set_expanded({ data:source():id("root") }, true, true))
      local view = treeview.attach(state, { keymaps = false })
      bench.view, bench.winnr, bench.bufnr = view, view.winnr, view.bufnr
      function bench.ready()
        return view:frame() ~= nil and not view:status().preparing and view._latest == nil
      end
    ]=],
    states = {
      { name = "no selection" },
      {
        name = "selection",
        apply = [=[ bench.selecting = state:select_node({ data:source():id("n2") }, false) ]=],
        ready = [=[ return bench.selecting:is_done() and not bench.view:frame():header().summary.is_empty ]=],
      },
    },
  },
}

---@param summaries                     table
---@param field                         string
---@return string
local function cell(summaries, field)
  local value = summaries[field]
  return value and string.format("%.3f / %s", value.median, value.p95 and string.format("%.3f", value.p95) or "-")
    or "-"
end

local results, conditions =
  {}, {
    processes = processes,
    iterations = iterations,
    warmups = warmups,
    gc = gc,
    baseline = baseline,
    current = root,
    scenarios = {},
  }
for _, scenario in ipairs(scenarios) do
  if only == "all" or only == scenario.name then
    local args = scenario.args()
    local states = scenario.states or { { name = "default" } }
    local collected = {}
    for _, state in ipairs(states) do
      collected[state.name] = {}
      for _, variant in ipairs({ "baseline", "current" }) do
        collected[state.name][variant] = { redraw = {}, provider = {}, process_medians = {}, census = nil }
      end
    end
    for round = 1, processes do
      for _, variant in ipairs(round % 2 == 1 and { "baseline", "current" } or { "current", "baseline" }) do
        local ui = UI.new({ timeout_ms = 120000 })
        local ok, failure = xpcall(function()
          ui:rpc("nvim_ui_attach", scenario.ui[1], scenario.ui[2], { rgb = true, ext_linegrid = true })
          ui:rpc("nvim_exec_lua", PRELUDE, { variant == "baseline" and baseline or root, native })
          ui:rpc("nvim_exec_lua", scenario.setup, args)
          for _, state in ipairs(states) do
            if state.apply then
              ui:rpc("nvim_exec_lua", state.apply, {})
            end
            ui:wait_until(function()
              return ui:rpc("nvim_exec_lua", state.ready or "return true", {})
                and ui:rpc("nvim_exec_lua", "return bench.settled(...)", { 200 })
            end, 120000, scenario.name .. " / " .. state.name .. " did not settle")
            local samples =
              ui:rpc("nvim_exec_lua", "return bench.measure(...)", { iterations, warmups, gc == "stopped" })
            local census = ui:rpc("nvim_exec_lua", "return bench.census()", {})
            local errors = ui:rpc("nvim_exec_lua", "return bench.errors", {})
            assert(#errors == 0, vim.inspect(errors))
            local target = collected[state.name][variant]
            vim.list_extend(target.redraw, samples.redraw)
            vim.list_extend(target.provider, samples.provider)
            target.process_medians[#target.process_medians + 1] = Stats.summary(samples.redraw).median
            target.census = target.census or census
          end
        end, debug.traceback)
        ui:close()
        if not ok then
          error(failure)
        end
      end
    end
    if scenario.name == "git_files" then
      vim.fn.delete(args[1], "rf")
    end
    conditions.scenarios[scenario.name] = { ui = scenario.ui, data = scenario.data }
    results[scenario.name] = {}
    io.stdout:write(
      string.format("\n%s (%s, %dx%d UI)\n", scenario.name, scenario.data, scenario.ui[1], scenario.ui[2])
    )
    io.stdout:write("state         variant   rows  trunc  marks  right  redraw med/p95 ms   provider med/p95 ms\n")
    for _, state in ipairs(states) do
      results[scenario.name][state.name] = {}
      for _, variant in ipairs({ "baseline", "current" }) do
        local target = collected[state.name][variant]
        local summary = {
          redraw_ms = Stats.summary(target.redraw),
          provider_ms = Stats.summary(target.provider),
          process_redraw_medians_ms = target.process_medians,
          census = target.census,
        }
        results[scenario.name][state.name][variant] = summary
        io.stdout:write(
          string.format(
            "%-13s %-9s %4d %6d %6d %6d  %-20s %s\n",
            state.name,
            variant,
            target.census.rows,
            target.census.truncated,
            target.census.marks,
            target.census.right_align,
            cell(summary, "redraw_ms"),
            cell(summary, "provider_ms")
          )
        )
      end
    end
  end
end
io.stdout:write(
  "\nresults: ",
  Record.write("treeview_decorations", { conditions = conditions, results = results }),
  "\n"
)
