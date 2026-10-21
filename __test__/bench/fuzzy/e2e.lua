---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.fuzzy.e2e" ---@type string

-- Level L3: real keystrokes into a full-config picker, observed from the parent's UI.
-- Usage: nvim -l __test__/bench/fuzzy/e2e.lua CHECKOUT CORPUS_DIR CORPUS WORKSPACE SCENARIO MODE PACE_MS SEQUENCES LIBRARY [FUZZY]
-- SCENARIO is files (find_files over WORKSPACE, a materialized corpus tree) or list (a ListComposer over
-- the corpus lines). The picker header shows "current / total"; a keystroke is visible at the first UI
-- flush after it whose header shows the total its query published. When that total was already on
-- screen before the keystroke the screen does not change, so the publish time stands in and the
-- keystroke is marked unchanged.

local harness = vim.fs.dirname(
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
)
package.path = harness .. "/?.lua;" .. package.path
require("__test__.bench.fuzzy.cpu").prefer_performance_cores()

---@param path                        string
---@return string
local function absolute(path)
  return assert(vim.uv.fs_realpath(path), "missing path: " .. path)
end
local checkout, directory, corpus = absolute(assert(arg[1])), absolute(assert(arg[2])), assert(arg[3])
local workspace, scenario, mode = absolute(assert(arg[4])), assert(arg[5]), assert(arg[6])
local pace = assert(tonumber(arg[7]))
local sequence_count = assert(tonumber(arg[8]))
local library = arg[9] ~= nil and arg[9] ~= "" and arg[9] or checkout .. "/lua/yoz.so"
local fuzzy = arg[10] ~= "false"
assert(scenario == "files" or scenario == "list", "scenario must be files or list")
assert(mode == "tree" or mode == "list", "mode must be tree or list")

local manifest = vim.json.decode(table.concat(vim.fn.readfile(directory .. "/manifest.json"), "\n"))
local entry = assert(manifest.corpora[corpus], "unknown corpus")
local texts = vim.fn.readfile(directory .. "/" .. corpus .. ".txt")
local sequences = vim.json.decode(table.concat(vim.fn.readfile(directory .. "/queries/" .. corpus .. ".json"), "\n"))

-- Round-robin over sequence kinds keeps every kind represented in a short run.
local selected = {}
do
  local by_kind, kinds = {}, {}
  for _, sequence in ipairs(sequences) do
    if not by_kind[sequence.kind] then
      by_kind[sequence.kind] = {}
      kinds[#kinds + 1] = sequence.kind
    end
    table.insert(by_kind[sequence.kind], sequence)
  end
  local round = 1
  while #selected < sequence_count do
    local added = false
    for _, kind in ipairs(kinds) do
      local sequence = by_kind[kind][round]
      if sequence and #selected < sequence_count then
        selected[#selected + 1] = sequence
        added = true
      end
    end
    if not added then
      break
    end
    round = round + 1
  end
end

local state = vim.fn.tempname()
vim.fn.mkdir(state, "p")
local ui = require("__test__.support.ui").new({
  timeout_ms = 120000,
  init = checkout .. "/init.lua",
  args = {
    "--cmd",
    string.format(
      "lua vim.g.fuzzy_bench_root=%q; vim.g.fuzzy_bench_harness=%q; vim.g.fuzzy_bench_workspace=%q; vim.g.fuzzy_bench_state=%q; vim.g.fuzzy_bench_library=%q",
      checkout,
      harness,
      workspace,
      state,
      library
    ),
    "--cmd",
    "lua dofile(" .. string.format("%q", harness .. "/__test__/bench/fuzzy/init.lua") .. ")",
  },
})

local events = {}
ui.on_notification = function(method, args)
  if method == "fuzzy_stage" then
    events[#events + 1] = args[1]
  end
end

---@param grid                          table
---@return string[]
local function screen_lines(grid)
  local lines = {}
  for _, screen in pairs(grid.grids) do
    for _, row in ipairs(screen.rows) do
      local cells = {}
      for index, cell in ipairs(row) do
        cells[index] = cell[1]
      end
      lines[#lines + 1] = table.concat(cells)
    end
  end
  return lines
end

-- Totals shown in "current / total" headers, logged whenever the set changes.
local counts = {} ---@type { t: integer, totals: table<integer, true> }[]
local signature = ""
local grid = require("__test__.support.ui_grid").new(ui, function(screen)
  local totals, keys = {}, {}
  for _, line in ipairs(screen_lines(screen)) do
    for total in line:gmatch("%d+ / (%d+)") do
      totals[tonumber(total)] = true
    end
  end
  for total in pairs(totals) do
    keys[#keys + 1] = total
  end
  table.sort(keys)
  local current = table.concat(keys, ",")
  if current ~= signature then
    signature = current
    counts[#counts + 1] = { t = vim.uv.hrtime(), totals = totals }
  end
end)

---@param total                         integer
---@param after                         integer
---@return integer|nil
local function first_shown(total, after)
  for _, item in ipairs(counts) do
    if item.t >= after and item.totals[total] then
      return item.t
    end
  end
end

---@param stage                         string
---@param input                         ?string
---@param after                         ?integer
---@return table|nil
local function find(stage, input, after)
  for _, event in ipairs(events) do
    if event.stage == stage and (input == nil or event.input == input) and (after == nil or event.t >= after) then
      return event
    end
  end
end

-- When the result of the query typed at `after` is on screen. A changed total must appear in the
-- header; an unchanged total leaves the screen as it was, so publishing completes the keystroke.
---@param query                         string
---@param after                         integer
---@return integer|nil visible
---@return boolean unchanged
---@return integer|nil rows
local function visible_at(query, after)
  local published = find("published", query, after)
  if not published then
    return nil, false, nil
  end
  local total = find("total", query, after)
  if not total then
    return published.t, true, nil
  end
  return first_shown(total.rows, total.t), false, total.rows
end

---@param name                          string
---@param ...                           any
---@return any
local function call(name, ...)
  return ui:rpc("nvim_exec_lua", "return require('__test__.bench.fuzzy.probes')." .. name .. "(...)", { ... })
end

---@param timeout                       integer
---@param predicate                     fun(): boolean
---@param message                       string
---@return nil
local function wait(timeout, predicate, message)
  if not vim.wait(timeout, predicate, 2) then
    error(message .. ": " .. vim.inspect(call("status")) .. "\n" .. table.concat(screen_lines(grid), "\n"))
  end
end

---@param milliseconds                  integer
---@return nil
local function sleep(milliseconds)
  vim.wait(milliseconds, function()
    return false
  end, 1)
end

-- A deterministic subset of items carries recency, so frecency-aware ranking has real input.
---@return integer
local function seed_frecency()
  local seed = 0x5eed
  local function random()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
  end
  local ages = { 600, 2400, 43200, 172800, 432000, 1000000, 2000000 }
  local paths, stamps = {}, {}
  for _ = 1, math.min(2000, math.max(20, math.floor(#texts * 0.02))) do
    paths[#paths + 1] = workspace .. "/" .. texts[math.floor(random() * #texts) + 1]
    local accesses = {}
    for at = 1, 1 + math.floor(random() * 10) do
      accesses[at] = ages[math.floor(random() * #ages) + 1]
    end
    stamps[#stamps + 1] = accesses
  end
  return call("seed_frecency", paths, stamps)
end

local ok, result = xpcall(function()
  ui:rpc("nvim_ui_attach", 120, 40, { rgb = true, ext_linegrid = true })
  wait(60000, function()
    return ui:rpc("nvim_exec_lua", "return _G.era ~= nil and vim.v.vim_did_enter == 1", {})
  end, "startup")
  call("install")
  local calibration_ms = ui:rpc("nvim_exec_lua", "return require('__test__.bench.fuzzy.cpu').calibrate()", {})
  local seeded = scenario == "files" and seed_frecency() or 0
  local opened = vim.uv.hrtime()
  call("open", scenario, { mode = mode, fuzzy = fuzzy, labels = directory .. "/" .. corpus .. ".txt" })
  -- Large corpora prepare in slices and publish growing totals; the picker is open once its total
  -- settles and that total has reached the screen.
  local open ---@type table|nil
  local settled_rows ---@type integer|nil
  wait(120000, function()
    local rows = call("status").rows
    if not rows or rows == 0 or not first_shown(rows, opened) then
      settled_rows = nil
      return false
    end
    if rows ~= settled_rows then
      settled_rows = rows
      sleep(300)
      return false
    end
    local published = 0
    for _, event in ipairs(events) do
      if event.stage == "published" and event.t >= opened then
        published = event.t
      end
    end
    local shown = assert(first_shown(rows, opened))
    open = { published_ms = (published - opened) / 1e6, visible_ms = (shown - opened) / 1e6, rows = rows }
    return true
  end, "open")

  local keystrokes, records = {}, {}
  for _, sequence in ipairs(selected) do
    call("arm")
    wait(10000, function()
      local status = call("status")
      return status.input == "" and status.finder_focused and status.mode:sub(1, 1) == "i"
    end, "arm")
    sleep(250)
    events = {}
    local usage = ui:rpc("nvim_exec_lua", "return require('__test__.bench.metrics').usage()", {})
    local typed, previous = {}, ""
    for _, query in ipairs(sequence.steps) do
      local key = query:sub(#previous + 1)
      previous = query
      typed[#typed + 1] = { query = query, t = vim.uv.hrtime() }
      ui:rpc("nvim_input", (key:gsub("<", "<lt>")))
      sleep(pace)
    end
    local final = typed[#typed]
    local settled = vim.wait(15000, function()
      return visible_at(final.query, final.t) ~= nil
    end, 2)
    sleep(50)
    local after = ui:rpc("nvim_exec_lua", "return require('__test__.bench.metrics').usage()", {})
    local status = call("status")
    for index, key in ipairs(typed) do
      local input = find("input", key.query, key.t)
      local match_start = find("match_start", key.query, key.t)
      local match_end = match_start and find("match_end", key.query, match_start.t)
      local display_start = match_end and find("display_start", nil, match_end.t)
      local display_end = display_start and find("display_end", nil, display_start.t)
      local published = find("published", key.query, key.t)
      local shown, unchanged, total = visible_at(key.query, key.t)
      keystrokes[#keystrokes + 1] = {
        sequence = sequence.id,
        kind = sequence.kind,
        step = index,
        length = vim.fn.strchars(key.query),
        query = key.query,
        last = index == #typed,
        coalesced = match_start == nil,
        -- Matched, but a later keystroke replaced the result before it reached the screen.
        superseded = match_start ~= nil and shown == nil and index < #typed,
        unchanged = unchanged,
        rows = total,
        input_ms = input and (input.t - key.t) / 1e6 or nil,
        key_to_match_ms = match_start and (match_start.t - key.t) / 1e6 or nil,
        match_ms = match_end and (match_end.t - match_start.t) / 1e6 or nil,
        display_ms = display_end and (display_end.t - display_start.t) / 1e6 or nil,
        fire_to_published_ms = published and match_start and (published.t - match_start.t) / 1e6 or nil,
        fire_to_visible_ms = shown and match_start and (shown - match_start.t) / 1e6 or nil,
        key_to_visible_ms = shown and (shown - key.t) / 1e6 or nil,
      }
    end
    records[#records + 1] = {
      id = sequence.id,
      kind = sequence.kind,
      query = final.query,
      settled = settled,
      final_input = status.input,
      final_mode = status.mode,
      cpu_ms = (after.cpu_us - usage.cpu_us) / 1000,
      main_ms = after.main_us and usage.main_us and (after.main_us - usage.main_us) / 1000 or nil,
      wall_ms = (vim.uv.hrtime() - typed[1].t) / 1e6,
    }
  end
  return {
    schema = "fuzzy-l3/1",
    level = "e2e",
    scenario = scenario,
    mode = mode,
    pace_ms = pace,
    fuzzy = fuzzy,
    corpus = corpus,
    corpus_sha256 = entry.sha256,
    items = entry.count,
    checkout = checkout,
    library = library,
    seeded_frecency = seeded,
    calibration_ms = calibration_ms,
    open = open,
    sequences = records,
    keystrokes = keystrokes,
    memory = call("finish"),
  }
end, debug.traceback)
ui:close()
vim.fn.delete(state, "rf")
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
