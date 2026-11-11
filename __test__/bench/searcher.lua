-- Usage, from the repository root: nvim -l __test__/bench/searcher.lua [iterations=20]
-- Measures how a Searcher FiletreeComposer publishes a completed native search for "needle" in a 5,000-line file:
-- 500 matches, the same 500 as a replace preview, and 5,000 matches. A publication splits into poll (the poll call that
-- returns the completed result), normalize (normalize_search_result), apply (__apply_search_result__ and drawing the
-- composer's own 80x10 result window) and render (drawing the result into a scratch buffer); total is their sum. Each
-- sample publishes through a fresh composer after a full GC; rounds alternate the scenarios after 3 warm-up rounds.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.searcher" ---@type string

local root =
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local iterations = tonumber(arg[1]) or 20
assert(iterations >= 1 and iterations % 1 == 0, "iterations must be a positive integer")
require("ark.bootstrap").setup()
local picker = require("__test__.support.picker")
local treeview = require("__test__.support.treeview")
local Record = require("__test__.bench.lib.record")
local Stats = require("__test__.bench.lib.stats")
local t = require("__test__.support.harness").new()

local WARMUP = 3
local LINES = 5000
local SCENARIOS = {
  { name = "normal_500", replace = false, max_matches = 500 },
  { name = "replace_500", replace = true, max_matches = 500 },
  { name = "normal_5000", replace = false, max_matches = 5000 },
}
local PHASES = { "poll", "normalize", "apply", "render", "total" }

local fixture_dir = t:tempdir()
local fixture_lines = {} ---@type string[]
for index = 1, LINES do
  fixture_lines[index] = string.format("needle line %04d", index)
end
vim.fn.writefile(fixture_lines, vim.fs.joinpath(fixture_dir, "matches.txt"))

---Publishes a native search for "needle" over the fixture through a fresh composer, and returns the milliseconds of
---each phase.
---@param scenario                      { name: string, replace: boolean, max_matches: integer }
---@return table<string, number>
local function publish(scenario)
  local controls = {
    search_pattern = picker.observable(""),
    replace_pattern = picker.observable(""),
    flag_replace = picker.observable(false),
    max_matches = picker.observable(scenario.max_matches),
  }
  local composer = picker.searcher(t, {
    name = "searcher-bench-" .. scenario.name,
    permanent = false,
    preview = false,
    title = "searcher benchmark",
    flag_replace = controls.flag_replace,
    max_matches = controls.max_matches,
    replace_pattern = controls.replace_pattern,
    rootpath = fixture_dir,
    search_pattern = controls.search_pattern,
  })
  picker.show_result(composer, 80, 10)
  treeview.await(composer._treeview:ready())
  controls.search_pattern:next("needle", { silent = true })
  controls.replace_pattern:next("replacement", { silent = true })
  controls.flag_replace:next(scenario.replace, { silent = true })

  -- Dead owners and frames of earlier samples are collected first; allocations during this publication are timed.
  collectgarbage("collect")
  local request, snapshot_err = composer:__snapshot_search_request__()
  assert(request ~= nil, snapshot_err)
  local search_job = yoz.search.start_search_in_files(request.options)
  t:defer(function()
    search_job:dispose()
  end)

  local status, result, err, poll_ms
  assert(
    vim.wait(10000, function()
      local started = vim.uv.hrtime()
      status, result, err = search_job:poll()
      poll_ms = (vim.uv.hrtime() - started) / 1e6
      return status ~= "running"
    end, 1),
    "fixture search did not finish"
  )
  assert(status == "completed", err and err.error or status)

  local context = request.context
  local started = vim.uv.hrtime()
  ---@diagnostic disable-next-line: param-type-mismatch
  local normalized = composer._treeview:normalize_search_result(context.params, result)
  local normalize_ms = (vim.uv.hrtime() - started) / 1e6

  started = vim.uv.hrtime()
  composer:__apply_search_result__(context, normalized)
  treeview.await(composer.result.draw())
  local apply_ms = (vim.uv.hrtime() - started) / 1e6

  local bufnr = t:buffer()
  started = vim.uv.hrtime()
  treeview.await(composer.result.draw(bufnr))
  local render_ms = (vim.uv.hrtime() - started) / 1e6
  t.assert_true(composer._treeview:linecount() >= scenario.max_matches, "native frame must contain every match")
  return {
    poll = poll_ms,
    normalize = normalize_ms,
    apply = apply_ms,
    render = render_ms,
    total = poll_ms + normalize_ms + apply_ms + render_ms,
  }
end

local samples = {} ---@type table<string, table<string, number[]>>
for _, scenario in ipairs(SCENARIOS) do
  samples[scenario.name] = {}
  for _, phase in ipairs(PHASES) do
    samples[scenario.name][phase] = {}
  end
end
for round = 1, WARMUP + iterations do
  for _, scenario in ipairs(SCENARIOS) do
    -- A case of its own disposes the sample's composer, search and buffer before the next sample.
    t:test(string.format("%s, round %d: the publication contains every match", scenario.name, round), function()
      local sample = publish(scenario)
      if round > WARMUP then
        for phase, ms in pairs(sample) do
          table.insert(samples[scenario.name][phase], ms)
        end
      end
    end)
  end
end

local run = t:run({ exit = false, quiet = true })
assert(run.failed == 0, table.concat(run.failures, "\n"))
local results = {} ---@type table<string, table<string, __test__.bench.lib.stats.ISummary|nil>>
for _, scenario in ipairs(SCENARIOS) do
  results[scenario.name] = {}
  for _, phase in ipairs(PHASES) do
    results[scenario.name][phase .. "_ms"] = Stats.summary(samples[scenario.name][phase])
  end
end
io.write(vim.json.encode(results), "\n")
local conditions = {
  iterations = iterations,
  warmup = WARMUP,
  fixture_lines = LINES,
  scenarios = SCENARIOS,
  result_window = { 80, 10 },
  gc = "full GC before each publication; natural GC inside it",
}
io.write("results: ", Record.write("searcher", { conditions = conditions, results = results }), "\n")
