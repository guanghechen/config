---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.fuzzy.ffi" ---@type string

-- Level L2: one typed query at a time through the Lua/native boundary, without the picker UI.
-- Usage: nvim -l __test__/bench/fuzzy/ffi.lua CHECKOUT CORPUS_DIR CORPUS [ITERATIONS] [LIBRARY] [SEQUENCE_STRIDE]
-- Prints one JSON line per pipeline. The old pipeline repeats the list composer's per-keystroke work
-- (lua/era/m/picker/composer/list.lua: __match__ and render_result) stage by stage.

local harness = vim.fs.dirname(
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
)
package.path = harness .. "/?.lua;" .. package.path
local cpu = require("__test__.bench.fuzzy.cpu")
local Stats = require("__test__.bench.stats")
local qos = cpu.prefer_performance_cores()
local calibration_ms = cpu.calibrate()

local checkout, directory, corpus = assert(arg[1]), assert(arg[2]), assert(arg[3])
local iterations = tonumber(arg[4]) or 5
local library = arg[5] ~= nil and arg[5] ~= "" and arg[5] or checkout .. "/lua/yoz.so"
local stride = tonumber(arg[6]) or 1
yoz = assert(package.loadlib(library, "luaopen_yoz"))()

local texts = vim.fn.readfile(directory .. "/" .. corpus .. ".txt")
local queries = {}
for _, line in ipairs(vim.fn.readfile(directory .. "/queries/" .. corpus .. ".tsv")) do
  local sequence, kind, _, step, text = line:match("^(%d+)\t([^\t]*)\t([^\t]*)\t(%d+)\t(.*)$")
  if sequence and (tonumber(sequence) - 1) % stride == 0 then
    queries[#queries + 1] = { sequence = tonumber(sequence), kind = kind, step = tonumber(step), text = text }
  end
end

-- Items exactly as the list composer prepares them before any keystroke.
local items = {}
for index, text in ipairs(texts) do
  items[index] = { uuid = tostring(index), text = text, text_lower = text:lower() }
end
local manifest = vim.json.decode(table.concat(vim.fn.readfile(directory .. "/manifest.json"), "\n"))

---@param ticket                        any
---@return table
local function settle(ticket)
  while true do
    local done, outcome = ticket:poll()
    if done then
      assert(outcome.kind == "Applied", vim.inspect(outcome))
      return outcome
    end
    vim.uv.sleep(1)
  end
end

-- The native Treeview data a result tree publishes: a root with one leaf per item, keyed as in the list
-- composer. Both pipelines resolve the matches to node ids against it, as ResultTree:_display does.
local setup = {}
local started = vim.uv.hrtime()
local data = yoz.ux.treeview.new_data()
local upload = data:begin_import(nil, data:source():revision())
upload:append({ keys = { "list" }, parent_keys = { false }, labels = { "list" }, can_expand = { true } })
for first = 1, #items, 512 do
  local columns = { keys = {}, parent_keys = {}, labels = {} }
  for index = first, math.min(first + 511, #items) do
    columns.keys[#columns.keys + 1] = "item:" .. items[index].uuid
    columns.parent_keys[#columns.parent_keys + 1] = "list"
    columns.labels[#columns.labels + 1] = items[index].text
  end
  local reply = upload:append(columns)
  assert(reply.kind == "NoChange", vim.inspect(reply))
end
settle(upload:commit())
local source = data:source()
setup.treeview_ms = (vim.uv.hrtime() - started) / 1e6

---@class __test__.bench.fuzzy.IStage
---@field name                          string
---@field run                           fun(state: table): nil

---@type table<string, __test__.bench.fuzzy.IStage[]>
local pipelines = {}

pipelines.old_list = {
  {
    name = "lines",
    run = function(state)
      local lines = {}
      for _, item in ipairs(items) do
        lines[#lines + 1] = item.text_lower
      end
      state.lines = lines
    end,
  },
  {
    name = "search",
    run = function(state)
      state.result = yoz.search.search_in_lines({
        pattern = state.query:lower(),
        lines = state.lines,
        flag_fuzzy = true,
        flag_regex = false,
        flag_case_sensitive = false,
      })
    end,
  },
  {
    name = "post",
    run = function(state)
      local matches, by_line = {}, {}
      for _, entry in ipairs(state.result and state.result.lines or {}) do
        local match = by_line[entry.lnum]
        if match then
          match.score = math.max(match.score, entry.score)
          vim.list_extend(match.matches, entry.matches)
        else
          match = { order = entry.lnum, uuid = items[entry.lnum].uuid, score = entry.score, matches = entry.matches }
          by_line[entry.lnum] = match
          matches[#matches + 1] = match
        end
      end
      table.sort(matches, function(a, b)
        return a.score == b.score and a.order < b.order or a.score > b.score
      end)
      local native_matches = {}
      for _, match in ipairs(matches) do
        if #match.matches > 0 then
          native_matches["item:" .. match.uuid] = match
        end
      end
      state.matches = matches
      state.native_matches = native_matches
    end,
  },
  {
    name = "orders",
    run = function(state)
      local orders = {}
      for _, match in ipairs(state.matches) do
        orders[#orders + 1] = "item:" .. match.uuid
      end
      state.orders = orders
      state.matched = #orders
    end,
  },
  {
    name = "ids",
    run = function(state)
      local filter = {}
      for _, key in ipairs(state.orders) do
        local id = source:id(key)
        if id then
          filter[#filter + 1] = id
        end
      end
      state.filter = filter
    end,
  },
}

if yoz.fuzzy then
  -- The native corpus, built once as the list composer's preparation would.
  started = vim.uv.hrtime()
  local corpus_items = yoz.fuzzy.new_corpus({ scheme = manifest.corpora[corpus].scheme })
  for first = 1, #items, 2048 do
    local chunk, keys = {}, {}
    for index = first, math.min(first + 2047, #items) do
      chunk[#chunk + 1], keys[#keys + 1] = items[index].text, "item:" .. items[index].uuid
    end
    corpus_items:append(chunk, keys)
  end
  setup.corpus_ms = (vim.uv.hrtime() - started) / 1e6
  started = vim.uv.hrtime()
  corpus_items:query({ pattern = "" }):ids(source)
  setup.bind_ms = (vim.uv.hrtime() - started) / 1e6

  pipelines.fuzzy_list = {
    {
      name = "query",
      run = function(state)
        state.result = corpus_items:query({ pattern = state.query, fuzzy = true, case = "smart", rank = true })
        state.matched = state.result:count()
      end,
    },
    {
      name = "ids",
      run = function(state)
        state.filter = state.result:ids(source)
      end,
    },
    {
      -- Ranges for the rows a viewport shows, as decorate_row reads them.
      name = "highlight",
      run = function(state)
        for _, key in ipairs(state.result:keys(1, 50)) do
          state.result:highlight(key)
        end
      end,
    },
  }
end

local names = vim.tbl_keys(pipelines)
table.sort(names)

---@param name                          string
---@param query                         string
---@return table
local function run(name, query)
  local state = { query = query }
  local timings = {}
  collectgarbage("collect")
  collectgarbage("stop")
  local heap = collectgarbage("count")
  local started = vim.uv.hrtime()
  for _, stage in ipairs(pipelines[name]) do
    local before = vim.uv.hrtime()
    stage.run(state)
    timings[stage.name] = vim.uv.hrtime() - before
  end
  local total = vim.uv.hrtime() - started
  local allocated_bytes = (collectgarbage("count") - heap) * 1024
  collectgarbage("restart")
  return { timings = timings, total = total, allocated_bytes = allocated_bytes, matched = state.matched or 0 }
end

-- The first query of a fresh process, before any warm-up.
local cold = {}
for _, name in ipairs(names) do
  local result = run(name, queries[1].text)
  cold[name] = { total_ms = result.total / 1e6, query = queries[1].text }
end
for _, name in ipairs(names) do
  for _, query in ipairs(queries) do
    run(name, query.text)
  end
end

local records = {}
for _, name in ipairs(names) do
  records[name] = {}
  for index = 1, #queries do
    records[name][index] = { total = {}, allocated = {}, stages = {} }
  end
end
for iteration = 1, iterations do
  for offset = 0, #names - 1 do
    local name = names[(offset + iteration - 1) % #names + 1]
    for index, query in ipairs(queries) do
      local result = run(name, query.text)
      local record = records[name][index]
      record.total[#record.total + 1] = result.total
      record.allocated[#record.allocated + 1] = result.allocated_bytes
      for stage, value in pairs(result.timings) do
        record.stages[stage] = record.stages[stage] or {}
        table.insert(record.stages[stage], value)
      end
      record.matched = result.matched
    end
  end
end

for _, name in ipairs(names) do
  local rows = {}
  local stage_names = {}
  for _, stage in ipairs(pipelines[name]) do
    stage_names[#stage_names + 1] = stage.name
  end
  for index, query in ipairs(queries) do
    local record = records[name][index]
    local stages = {}
    for _, stage in ipairs(stage_names) do
      stages[#stages + 1] = Stats.median(record.stages[stage]) / 1e6
    end
    rows[index] = {
      query.sequence,
      query.step,
      vim.fn.strchars(query.text),
      query.kind,
      Stats.median(record.total) / 1e6,
      record.matched,
      Stats.median(record.allocated),
      stages,
    }
  end
  io.stdout:write(
    vim.json.encode({
      schema = "fuzzy-l2/2",
      level = "ffi",
      corpus = corpus,
      corpus_sha256 = manifest.corpora[corpus].sha256,
      items = #items,
      pipeline = name,
      iterations = iterations,
      sequence_stride = stride,
      library = library,
      qos = qos,
      calibration_ms = calibration_ms,
      stages = stage_names,
      cold = cold[name],
      setup = setup,
      columns = { "sequence", "step", "length", "kind", "total_ms", "matched", "allocated_bytes", "stage_ms" },
      queries = rows,
    }),
    "\n"
  )
end
