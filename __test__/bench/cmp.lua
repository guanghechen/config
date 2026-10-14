-- nvim -l __test__/bench/cmp.lua [output-dir] [blink-dir] [samples] [matching|sources|ui|memory|load|all] [baseline-dir|-] [off|empty|populated]
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp" ---@type string

local root = assert(vim.uv.cwd())
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local output = arg[1] or vim.fn.tempname() .. "-cmp-bench"
local blink = arg[2] or vim.fn.stdpath("data") .. "/lazy/blink.cmp"
local samples = tonumber(arg[3]) or 31
local phase = arg[4] or "all"
local baseline = arg[5] ~= "-" and arg[5] or nil
local history = arg[6] or "off"
assert(samples >= 5 and samples % 1 == 0, "samples must be an integer >= 5")
assert(vim.uv.fs_stat(blink .. "/lua/blink/cmp/init.lua"), "pass an existing Blink checkout; no downloads are made")
assert(vim.tbl_contains({ "matching", "sources", "ui", "memory", "load", "all" }, phase), "unknown benchmark phase")
assert(vim.tbl_contains({ "off", "empty", "populated" }, history), "unknown history state")
assert(history == "off" or phase == "load", "history selection is only supported for the load phase")
vim.fn.mkdir(output, "p")
vim.opt.runtimepath:append(blink)

local Metadata = require("__test__.bench.cmp.metadata")
local metadata = vim.tbl_extend("force", Metadata.collect(root, baseline, "__test__/bench/cmp.lua"), {
  root = root,
  blink = blink,
  blink_lua_sha256 = Metadata.digest(blink, vim.fn.glob(blink .. "/lua/**/*.lua", false, true)),
  blink_revision = vim.trim(vim.system({ "git", "-C", blink, "rev-parse", "HEAD" }):wait().stdout),
  blink_dirty = vim.trim(vim.system({ "git", "-C", blink, "status", "--porcelain" }):wait().stdout),
  samples = samples,
  phase = phase,
  load_history = { state = history, entries = history == "populated" and 64 or 0 },
  gc = "collect between paired samples; collector remains enabled inside timed regions",
  load_gc = "full GC before each burst and after its measurement; automatic GC remains enabled",
  libraries = {},
})
local cpuinfo = io.open("/proc/cpuinfo", "r")
if cpuinfo ~= nil then
  for line in cpuinfo:lines() do
    if line:match("^flags%s*:") then
      metadata.avx2 = line:match("%f[%w]avx2%f[%W]") ~= nil
      break
    end
  end
  cpuinfo:close()
end
for name, path in pairs({
  era = (baseline or root) .. "/bin/nix.yoz.so",
  blink = blink .. "/target/release/libblink_cmp_fuzzy.so",
}) do
  metadata.libraries[name] = { path = path, sha256 = Metadata.file_hash(path) }
end
vim.fn.writefile({ vim.json.encode(metadata) }, output .. "/metadata.json")

for _, name in ipairs({ "matching", "sources", "ui", "memory", "load" }) do
  if phase == "all" or phase == name then
    io.stdout:write("Running " .. name .. " benchmark\n")
    io.stdout:flush()
    local result = require("__test__.bench.cmp." .. name).run({
      root = root,
      blink = blink,
      output = output,
      samples = samples,
      baseline = baseline,
      frecency = history ~= "off",
      frecency_entries = history == "populated" and 64 or 0,
    })
    vim.fn.writefile({ vim.json.encode(result) }, output .. "/" .. name .. ".json")
  end
end
print("Results: " .. output)
