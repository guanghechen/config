-- Usage, from the repository root:
-- nvim -l __test__/bench/pairs/run.lua [variants=none,era] [corpora=all] [iterations=30] [blink-root] [phases]
-- Measures a pairs implementation on real code of this checkout: full parse, edits with their change tracking,
-- forced window redraws, cursor-moved matchparen work, and typed `(` / `<BS>` from input to the next UI flush.
-- The `stress` phase, outside the default phases, times pathological inputs instead. See README.md for the method.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.pairs.run" ---@type string

local root = vim.fs.dirname(
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
)
vim.api.nvim_set_current_dir(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local UI = require("__test__.support.ui")
local Record = require("__test__.bench.lib.record")
local Stats = require("__test__.bench.lib.stats")

local CORPUS_PHASES = { "parse", "edit", "redraw", "matchparen", "keys" } ---@type string[]
local variants = vim.split(arg[1] and arg[1] ~= "" and arg[1] or "none,era", ",", { plain = true })
local only = arg[2] and arg[2] ~= "" and arg[2] or "all"
local iterations = tonumber(arg[3]) or 30
local blink_root = arg[4] and arg[4] ~= "" and arg[4] or vim.fn.stdpath("data") .. "/lazy/blink.pairs"
local phases = arg[5] and arg[5] ~= "" and arg[5] or table.concat(CORPUS_PHASES, ",")
---@param phase                         string
---@return boolean
local function runs_phase(phase)
  return vim.tbl_contains(vim.split(phases, ",", { plain = true }), phase)
end
---@param name                          string A corpus or stress name.
---@return boolean
local function selected(name)
  return only == "all" or vim.tbl_contains(vim.split(only, ",", { plain = true }), name)
end
local parser_dir = vim.fn.stdpath("data") .. "/treesitter"
local UI_SIZE = { 120, 50 }
assert(iterations >= 1, "iterations must be positive")

---Tracked files that exist in the worktree, by path.
---@param patterns                      string[]
---@param exclude                       ?string
---@return string[]
local function git_files(patterns, exclude)
  local command = vim.list_extend({ "git", "--no-optional-locks", "-C", root, "ls-files", "--" }, patterns)
  local result = vim.system(command, { text = true }):wait()
  assert(result.code == 0, result.stderr)
  local paths = {} ---@type string[]
  for path in result.stdout:gmatch("[^\n]+") do
    if not (exclude and path:find(exclude, 1, true)) and vim.uv.fs_stat(root .. "/" .. path) then
      paths[#paths + 1] = root .. "/" .. path
    end
  end
  table.sort(paths)
  return paths
end

-- The configuration gives a file over `vim.g.bigfile_size` (3 MiB) the "bigfile" filetype, which disables pairs.
local MAX_BYTES = 3000000

---The lines of `paths` in order, repeated until `target` lines when given, and never over `MAX_BYTES`.
---@param paths                         string[]
---@param target                        ?integer
---@return string[]
local function lines_of(paths, target)
  assert(#paths > 0, "empty corpus source")
  local lines, bytes = {}, 0 ---@type string[], integer
  repeat
    for _, path in ipairs(paths) do
      for _, line in ipairs(vim.fn.readfile(path)) do
        bytes = bytes + #line + 1
        if bytes > MAX_BYTES then
          return lines
        end
        lines[#lines + 1] = line
        if target and #lines >= target then
          return lines
        end
      end
    end
  until not target
  return lines
end

---@class __test__.bench.pairs.ICorpus
---@field name                          string
---@field ext                           string
---@field files                         ?string[] Tracked files or pathspecs; friendly-snippets' JSON files when absent.
---@field exclude                       ?string
---@field target                        ?number Lines, repeating the files; one pass when absent.

-- stylua: ignore
---@type __test__.bench.pairs.ICorpus[]
local corpora = {
  { name = "lua-2k",         ext = "lua",  files = { "lua/era/m/searcher/composer/filetree.lua" } },
  { name = "lua-20k",        ext = "lua",  files = { "lua/*.lua" }, exclude = "lua/stl/dict/", target = 20000 },
  { name = "lua-max",        ext = "lua",  files = { "lua/*.lua" }, exclude = "lua/stl/dict/", target = math.huge },
  { name = "rust-2k",        ext = "rs",   files = { "rust/yoz/src/ux/filetree/jobs.rs" } },
  { name = "rust-20k",       ext = "rs",   files = { "rust/*.rs" }, exclude = "/dict/", target = 20000 },
  { name = "rust-max",       ext = "rs",   files = { "rust/*.rs" }, exclude = "/dict/", target = math.huge },
  { name = "javascript-20k", ext = "js",   files = { "*.mjs", "*.js" }, target = 20000 },
  { name = "json-20k",       ext = "json", target = 20000 },
  { name = "markdown-20k",   ext = "md",   files = { "*.md" }, target = 20000 },
}

---@param name                          string
---@return string[]
local function corpus_lines(name)
  local corpus = assert(
    vim.iter(corpora):find(function(corpus)
      return corpus.name == name
    end),
    "no corpus " .. name
  )
  if corpus.files then
    return lines_of(git_files(corpus.files, corpus.exclude), corpus.target)
  end
  local snippets = vim.fs.find(function(file)
    return file:match("%.json$") ~= nil
  end, { path = vim.fn.stdpath("data") .. "/lazy/friendly-snippets/snippets", type = "file", limit = math.huge })
  table.sort(snippets)
  return lines_of(snippets, corpus.target)
end

local OPENERS = { [40] = 41, [91] = 93, [123] = 125 } ---@type table<integer, integer>
local CLOSERS = { [41] = 40, [93] = 91, [125] = 123 } ---@type table<integer, integer>

---@class __test__.bench.pairs.IPositions
---@field edit                          integer[] A non-blank column of a line near the middle.
---@field line                          ?integer[] A line near the middle ending with an opening bracket.
---@field keys                          table<string, integer[]> End of a line inside brackets.
---@field matchparen                    table<string, integer[]>

---Positions for the scenarios, from a bracket count that ignores strings and comments: approximate, but the same for
---every variant.
---@param lines                         string[]
---@return __test__.bench.pairs.IPositions
local function positions(lines)
  local count = #lines
  local depth_at = {} ---@type integer[] Depth at the start of each line.
  local openers = {} ---@type integer[][] Row (1-based), column, byte and, once matched, the closer's row.
  local near = {} ---@type table<integer, integer> Column of a line's first `(` when its `)` is on the same line.
  local stack = {} ---@type integer[][]
  for row, line in ipairs(lines) do
    depth_at[row] = #stack
    local first = line:find("(", 1, true)
    for col = 1, #line do
      local byte = line:byte(col)
      if OPENERS[byte] then
        local opener = { row, col - 1, byte }
        stack[#stack + 1] = opener
        openers[#openers + 1] = opener
      elseif CLOSERS[byte] then
        local top = stack[#stack]
        if top and top[3] == CLOSERS[byte] then
          stack[#stack] = nil
          top[4] = row
          if first and top[1] == row and top[2] == first - 1 then
            near[row] = top[2]
          end
        end
      end
    end
  end
  depth_at[count + 1] = #stack

  local middle = math.floor(count / 2)
  ---@param predicate                   fun(row: integer): any
  ---@return integer|nil
  local function near_middle(predicate)
    for offset = 0, count do
      for _, row in ipairs({ middle + offset, middle - offset }) do
        if row >= 1 and row <= count and predicate(row) then
          return row
        end
      end
    end
  end
  ---@param line                        string
  ---@return integer|nil
  local function plain_column(line)
    for col = 1, #line do
      local byte = line:byte(col)
      if byte ~= 32 and byte ~= 9 and not OPENERS[byte] and not CLOSERS[byte] then
        return col - 1
      end
    end
  end
  ---Column of an identifier that starts the line, so the cursor is on no token at all.
  ---@param line                        string
  ---@return integer|nil
  local function word_column(line)
    local col = line:find("%S")
    return col and line:sub(col, col):match("[%a_]") and col - 1 or nil
  end
  ---@param line                        string
  ---@return boolean
  local function bracketless(line)
    return not line:find("[%(%)%[%]{}]")
  end

  local result = { keys = {}, matchparen = {} }
  local edit = assert(near_middle(function(row)
    return plain_column(lines[row]) ~= nil
  end))
  result.edit = { edit - 1, assert(plain_column(lines[edit])) }
  local line = near_middle(function(row)
    local last = lines[row]:match("([%(%[{])%s*$")
    return last ~= nil
  end)
  result.line = line and { line - 1, 0 } or nil

  local body = near_middle(function(row)
    return depth_at[row] >= 1 and depth_at[row + 1] == depth_at[row] and bracketless(lines[row]) and #lines[row] > 0
  end)
  result.keys.body = body and { body - 1, #lines[body] } or nil

  local on_near = near_middle(function(row)
    return near[row] ~= nil
  end)
  if on_near then
    result.matchparen.on_near = { on_near - 1, near[on_near] }
  end
  local far, span = nil, 0 ---@type integer[]|nil, integer
  for _, opener in ipairs(openers) do
    local closer = opener[4]
    if closer and opener[1] >= count / 3 and opener[1] <= count * 2 / 3 and closer - opener[1] > span then
      far, span = opener, closer - opener[1]
    end
  end
  if far then
    result.matchparen.on_far = { far[1] - 1, far[2] }
  end
  local deepest, depth = nil, 0 ---@type integer|nil, integer
  for row = math.max(1, middle - 2000), math.min(count, middle + 2000) do
    if depth_at[row] > depth and word_column(lines[row]) then
      deepest, depth = row, depth_at[row]
    end
  end
  if deepest then
    result.matchparen.inside_deep = { deepest - 1, assert(word_column(lines[deepest])) }
  end
  local outside = near_middle(function(row)
    return depth_at[row] == 0 and depth_at[row + 1] == 0 and bracketless(lines[row]) and word_column(lines[row])
  end)
  if outside then
    result.matchparen.top_level = { outside - 1, assert(word_column(lines[outside])) }
  end
  return result
end

---@param values                        number[]|nil
---@return table|nil
local function summary(values)
  return values and Stats.summary(values) or nil
end

---Sends `key` as typed input and returns the milliseconds until the child's next UI flush.
---@param ui                            __test__.support.UI
---@param key                           string
---@return number
local function type_key(ui, key)
  local started = vim.uv.hrtime()
  ui:notify("nvim_input", key)
  ui:wait_until(function()
    return ui.last_flush and ui.last_flush > started
  end, 30000, "no flush after " .. key, 1)
  local elapsed = (ui.last_flush - started) / 1e6
  ui:rpc("nvim_eval", "0")
  return elapsed
end

---Runs `measure` against a fresh UI child that has the ark runtime and `variant` set up as its global `bench`.
---@param variant                       string
---@param measure                       fun(ui: __test__.support.UI): table
---@return table
local function with_child(variant, measure)
  local ui = UI.new({ timeout_ms = 600000 })
  local ok, result = pcall(function()
    ui:start({ width = UI_SIZE[1], height = UI_SIZE[2], runtime = "ark" })
    ui:lua(
      [[
      local variant, blink_root, parser_dir = ...
      bench = require("__test__.bench.pairs.child")
      bench.setup(variant, blink_root, parser_dir)
    ]],
      variant,
      blink_root,
      parser_dir
    )
    return measure(ui)
  end)
  local stderr = ui.stderr
  ui:close()
  assert(ok, tostring(result) .. stderr)
  return result
end

---@param ui                            __test__.support.UI
---@param path                          string
---@param where                         __test__.bench.pairs.IPositions
---@return table
local function measure_corpus(ui, path, where)
  local out = { filetype = ui:lua("return bench.open(...)", path, where.edit[1]) }
  if runs_phase("parse") then
    out.parse = summary(ui:lua("return bench.parse(...)", math.max(5, math.floor(iterations / 3))))
  end
  for _, kind in ipairs(runs_phase("edit") and { "char", "pair", "open", "line" } or {}) do
    local at = kind == "line" and where.line or where.edit
    if at then
      local timed = ui:lua("return bench.edit(...)", kind, at[1], at[2], iterations)
      out["edit_" .. kind] = summary(timed.edit)
      out["revert_" .. kind] = summary(timed.revert)
    end
  end
  for _, mode in ipairs(runs_phase("redraw") and { "static", "edit", "scroll" } or {}) do
    local timed = ui:lua("return bench.redraw(...)", mode, where.edit[1], where.edit[2], iterations * 3)
    out["redraw_" .. mode] = summary(timed.redraw)
    out["provider_" .. mode] = summary(timed.provider)
  end
  for name, at in pairs(runs_phase("matchparen") and where.matchparen or {}) do
    out["matchparen_" .. name] = summary(ui:lua("return bench.matchparen(...)", at[1], at[2], iterations * 3))
  end
  for name, at in pairs(runs_phase("keys") and where.keys or {}) do
    ui:lua("bench.insert_at(...)", at[1], at[2])
    ui:wait_lua("return vim.api.nvim_get_mode().mode == 'i'", 5000, "Insert mode")
    local original = ui:lua("return vim.api.nvim_get_current_line()")
    local opens, backs = {}, {} ---@type number[], number[]
    for index = 1, 5 + iterations do
      local open = type_key(ui, "(")
      local back = type_key(ui, "<BS>")
      if index > 5 then
        opens[#opens + 1], backs[#backs + 1] = open, back
      end
    end
    assert(ui:lua("return vim.api.nvim_get_current_line()") == original, "typed keys changed the line")
    ui:rpc("nvim_input", "<Esc>")
    ui:wait_lua("return vim.api.nvim_get_mode().mode == 'n'", 5000, "Normal mode")
    out["key_open_" .. name] = summary(opens)
    out["key_backspace_" .. name] = summary(backs)
  end
  return out
end

---@param ui                            __test__.support.UI
---@param path                          string
---@param row                           integer
---@return table
local function open_timed(ui, path, row)
  local opened = ui:lua("return { bench.open(...) }", path, row)
  return { filetype = opened[1], open = summary({ opened[2] }) }
end

---Adds the times of an edit and of the redraw after it to `out`, after one edit to warm up.
---@param ui                            __test__.support.UI
---@param kind                          "char"|"pair"|"open"
---@param row                           integer
---@param col                           integer
---@param out                           table
---@return nil
local function edit_redraw(ui, kind, row, col, out)
  local edits, redraws = {}, {} ---@type number[], number[]
  for index = 0, iterations do
    local timed = ui:lua("return bench.edit_redraw(...)", kind, row, col)
    if index > 0 then
      edits[#edits + 1], redraws[#redraws + 1] = timed.edit, timed.redraw
    end
  end
  out["edit_" .. kind], out["redraw_" .. kind] = summary(edits), summary(redraws)
end

local LONG_LINE_UNIT = 'f(a[1],{b:(c)},"s(");' ---@type string
-- Ex commands over lines 1-5000; `norm` goes through the Insert mode maps, `norm!` does not.
---@type table<string, string>
local COMMANDS = {
  norm_bang = "silent 1,5000norm! A()",
  norm = "silent 1,5000norm A()",
  substitute = "silent 1,5000s/(/[/ge",
}

---@class __test__.bench.pairs.IStress
---@field name                          string
---@field ext                           ?string
---@field source                        string
---@field lines                         ?fun(): string[] The file to open, if any.
---@field measure                       fun(ui: __test__.support.UI, path: string|nil, lines: string[]|nil): table

---@param corpus                        string
---@return __test__.bench.pairs.IStress
local function commands(corpus)
  return {
    name = "commands-" .. corpus,
    ext = "lua",
    source = corpus,
    lines = function()
      return corpus_lines(corpus)
    end,
    measure = function(ui, path)
      local out = open_timed(ui, assert(path), 0)
      for name, command in pairs(COMMANDS) do
        local ran, redraws = {}, {} ---@type number[], number[]
        for _ = 1, iterations do
          local timed = ui:lua("return bench.command(...)", command)
          ran[#ran + 1], redraws[#redraws + 1] = timed.command, timed.redraw
        end
        out["command_" .. name], out["redraw_" .. name] = summary(ran), summary(redraws)
      end
      return out
    end,
  }
end

-- Pathological inputs of the `stress` phase, timed `iterations` times each.
---@type __test__.bench.pairs.IStress[]
local stresses = {
  {
    name = "long-line",
    ext = "js",
    source = "one line of " .. LONG_LINE_UNIT .. " repeated to 1,000,000 bytes",
    lines = function()
      return { string.rep(LONG_LINE_UNIT, math.floor(1000000 / #LONG_LINE_UNIT)) }
    end,
    measure = function(ui, path)
      local out = open_timed(ui, assert(path), 0)
      out.redraw_static = summary(ui:lua("return bench.redraw(...)", "static", 0, 0, iterations).redraw)
      edit_redraw(ui, "char", 0, 0, out)
      edit_redraw(ui, "open", 0, 0, out)
      ui:lua("vim.wo.wrap = false")
      out.redraw_static_nowrap = summary(ui:lua("return bench.redraw(...)", "static", 0, 0, iterations).redraw)
      return out
    end,
  },
  {
    name = "deep-nesting",
    ext = "lua",
    source = "20,000 lines of `(` then 20,000 of `)`, indented by the line number modulo 40",
    lines = function()
      local lines = {} ---@type string[]
      for row = 1, 20000 do
        lines[row] = string.rep(" ", row % 40) .. "("
      end
      for row = 20000, 1, -1 do
        lines[#lines + 1] = string.rep(" ", row % 40) .. ")"
      end
      return lines
    end,
    measure = function(ui, path)
      local out = open_timed(ui, assert(path), 9999)
      edit_redraw(ui, "open", 9999, 0, out)
      return out
    end,
  },
  {
    name = "stray-opening",
    ext = "lua",
    source = "lua-max under a first line `local broken = (`",
    lines = function()
      local lines = corpus_lines("lua-max")
      table.insert(lines, 1, "local broken = (")
      return lines
    end,
    measure = function(ui, path, lines)
      local middle = math.floor(#assert(lines) / 2)
      local out = open_timed(ui, assert(path), middle)
      edit_redraw(ui, "pair", middle, 0, out)
      return out
    end,
  },
  commands("lua-20k"),
  commands("lua-max"),
  {
    name = "buffers",
    source = "every tracked lua/**/*.lua loaded as a buffer",
    measure = function(ui)
      local loaded = ui:lua("return bench.load(...)", git_files({ "lua/*.lua" }))
      return { load = summary({ loaded.load }), rss = summary({ loaded.rss }) }
    end,
  },
}

local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
local runs = {} ---@type table[]
---Measures every variant on `lines`, written to a file of `ext` when given, each variant in a fresh child.
---@param run                           table The run record: name, plus what describes its input.
---@param lines                         string[]|nil
---@param ext                           string|nil
---@param measure                       fun(ui: __test__.support.UI, path: string|nil): table
---@return nil
local function run_case(run, lines, ext, measure)
  local path = lines and string.format("%s/%s.%s", directory, run.corpus, ext) ---@type string|nil
  if path then
    assert(vim.fn.writefile(lines, path) == 0, "cannot write " .. path)
  end
  run.lines, run.variants = lines and #lines, {}
  for _, variant in ipairs(variants) do
    print(string.format("%s / %s", run.corpus, variant))
    run.variants[variant] = with_child(variant, function(ui)
      return measure(ui, path)
    end)
  end
  runs[#runs + 1] = run
end
for _, corpus in ipairs(vim.iter(CORPUS_PHASES):any(runs_phase) and corpora or {}) do
  if selected(corpus.name) then
    local ok, lines = pcall(corpus_lines, corpus.name)
    if not ok then
      print(string.format("skip %s: %s", corpus.name, lines))
    else
      local where = positions(lines)
      run_case({ corpus = corpus.name, positions = where }, lines, corpus.ext, function(ui, path)
        return measure_corpus(ui, assert(path), where)
      end)
    end
  end
end
for _, stress in ipairs(runs_phase("stress") and stresses or {}) do
  if selected(stress.name) then
    local lines = stress.lines and stress.lines() ---@type string[]|nil
    run_case({ corpus = stress.name, source = stress.source }, lines, stress.ext, function(ui, path)
      return stress.measure(ui, path, lines)
    end)
  end
end
vim.fn.delete(directory, "rf")

local blink_commit = vim.system({ "git", "-C", blink_root, "rev-parse", "--short", "HEAD" }, { text = true }):wait()
local path = Record.write("pairs", {
  conditions = {
    variants = variants,
    phases = phases,
    iterations = iterations,
    ui = UI_SIZE,
    blink = { root = blink_root, commit = vim.trim(blink_commit.stdout or "") },
    treesitter_parsers = vim.uv.fs_stat(parser_dir) and parser_dir or vim.NIL,
    note = "one UI child per corpus and variant, ark bootstrap without plugins, syntax and treesitter highlighting off",
  },
  results = runs,
})

---@param value                         table|nil
---@return string
local function cell(value)
  if not value then
    return "—"
  end
  return value.p95 and string.format("%.3f / %.3f", value.median, value.p95) or string.format("%.3f", value.median)
end

for _, run in ipairs(runs) do
  local size = run.lines and string.format("%d lines", run.lines) or run.source ---@type string
  print(string.format("\n%s (%s), median / p95 ms, rss in bytes", run.corpus, size))
  local metrics = {} ---@type string[]
  for _, result in pairs(run.variants) do
    for key in pairs(result) do
      if key ~= "filetype" and not vim.tbl_contains(metrics, key) then
        metrics[#metrics + 1] = key
      end
    end
  end
  table.sort(metrics)
  for _, metric in ipairs(metrics) do
    local cells = {} ---@type string[]
    for _, variant in ipairs(variants) do
      cells[#cells + 1] = string.format("%-22s", cell(run.variants[variant][metric]))
    end
    print(string.format("  %-26s %s", metric, table.concat(cells, " ")))
  end
end
print("\n" .. path)
