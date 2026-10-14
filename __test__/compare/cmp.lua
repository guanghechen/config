-- nvim -l __test__/compare/cmp.lua [output-dir] [blink-dir] [case-filter|all] [baseline-dir]
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.compare.cmp" ---@type string

local root = assert(vim.uv.cwd())
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local Trace = require("__test__.fixtures.era.keystroke.cmp.behavior_trace")
local output = arg[1] or vim.fn.tempname() .. "-cmp-behavior"
local blink = arg[2] or vim.fn.stdpath("data") .. "/lazy/blink.cmp"
local filter = arg[3] ~= "all" and arg[3] or nil
local baseline = arg[4]
assert(vim.uv.fs_stat(blink .. "/lua/blink/cmp/init.lua"), "pass an existing Blink checkout; no downloads are made")
vim.fn.mkdir(output, "p")

---@param paths                         string[]
---@param source_root                   string
---@return string
local function fingerprint(paths, source_root)
  table.sort(paths)
  local sources = {}
  for _, path in ipairs(paths) do
    local file = assert(io.open(path, "rb"))
    sources[#sources + 1] = path:sub(#source_root + 1) .. "\0" .. file:read("*a")
    file:close()
  end
  return vim.fn.sha256(table.concat(sources, "\0"))
end

local results = {
  cases = {},
  timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  baseline_revision = "8a8edb925",
  baseline = baseline,
  blink = blink,
  blink_lua_sha256 = fingerprint(vim.fn.glob(blink .. "/lua/**/*.lua", false, true), blink),
  blink_revision = vim.trim(vim.system({ "git", "-C", blink, "rev-parse", "HEAD" }):wait().stdout),
  blink_dirty = vim.trim(vim.system({ "git", "-C", blink, "status", "--porcelain" }):wait().stdout),
  neovim = vim.version(),
  completion_lua_sha256 = fingerprint(
    vim.fn.glob((baseline or root) .. "/lua/era/keystroke/cmp/**/*.lua", false, true),
    baseline or root
  ),
  oracle_lua_sha256 = fingerprint({ root .. "/__test__/fixtures/era/keystroke/cmp/blink_options.lua" }, root),
  behavior_lua_sha256 = fingerprint({
    root .. "/__test__/compare/cmp.lua",
    root .. "/__test__/fixtures/era/keystroke/cmp/behavior.lua",
    root .. "/__test__/fixtures/era/keystroke/cmp/behavior_cases.lua",
    root .. "/__test__/fixtures/era/keystroke/cmp/behavior_trace.lua",
    root .. "/__test__/fixtures/era/keystroke/cmp/runtime.lua",
    root .. "/__test__/support/rpc.lua",
  }, root),
  compared_fields = "mode, text, cursor, menu, candidates, selection, ghost, documentation, signature, snippet, inline and mapping fallback",
}
local unexpected = 0
for _, case in ipairs(require("__test__.fixtures.era.keystroke.cmp.behavior_cases")) do
  if filter == nil or case.name:find(filter, 1, true) then
    local record = { name = case.name, steps = case.steps, traces = {}, differences = {}, reviewed = {} }
    for _, engine in ipairs({ "blink", "era" }) do
      io.stdout:write(case.name .. " / " .. engine .. "\n")
      io.stdout:flush()
      record.traces[engine] =
        Trace.run({ root = root, engine = engine, blink = blink, output = output, baseline = baseline }, case)
    end
    for index, expected in ipairs(record.traces.blink) do
      local actual = record.traces.era[index]
      for key, value in pairs(expected) do
        if not vim.deep_equal(value, actual[key]) then
          local difference = { step = index, field = key, blink = value, era = actual[key] }
          local reviewed = key == "native_menu" and value == false and actual[key] == true and actual.menu == true
          if reviewed then
            difference.reason = "Era uses the native PUM; Blink renders its completion menu in floating windows."
          end
          for _, accepted in ipairs(case.reviewed_differences or {}) do
            if
              accepted.step == index
              and accepted.field == key
              and vim.deep_equal(accepted.blink, value)
              and vim.deep_equal(accepted.era, actual[key])
            then
              difference.reason = accepted.reason
              reviewed = true
              break
            end
          end
          local target = reviewed and record.reviewed or record.differences
          target[#target + 1] = difference
        end
      end
    end
    results.cases[#results.cases + 1] = record
    unexpected = unexpected + #record.differences
    results.unexpected_differences = unexpected
    vim.fn.writefile({ vim.json.encode(results) }, output .. "/behavior.json")
    io.stdout:write("  differences: " .. #record.differences .. ", reviewed: " .. #record.reviewed .. "\n")
    io.stdout:flush()
  end
end
assert(#results.cases > 0, "no behavior cases matched filter: " .. tostring(filter))
io.stdout:write("Results: " .. output .. "\n")
assert(unexpected == 0, unexpected .. " unexpected behavioral differences")
