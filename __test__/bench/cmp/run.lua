-- Usage, from the repository root: nvim -l __test__/bench/cmp/run.lua [output-dir|''] [baseline-dir|-] [iterations=15] [ranking|load|ui|all] [load-case-filter]
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp.run" ---@type string

local root = assert(vim.uv.cwd())
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
-- By default the run keeps its results beside the other benchmarks; a tempname would vanish with Neovim's
-- private temporary directory when the process exits.
local output = arg[1] ~= "" and arg[1]
  or string.format("%s/__test__/bench/results/cmp/%s-%d", root, os.date("!%Y%m%dT%H%M%SZ"), vim.uv.os_getpid())
local baseline = arg[2] ~= "-" and arg[2] or nil
local iterations = tonumber(arg[3]) or 15
local phase = arg[4] or "all"
assert(iterations >= 5 and iterations % 1 == 0, "iterations must be an integer >= 5")
assert(vim.tbl_contains({ "ranking", "load", "ui", "all" }, phase), "unknown benchmark phase")
vim.fn.mkdir(output, "p")

local Metadata = require("__test__.bench.cmp.metadata")
local source_root = baseline or root
local rust_paths = vim.fn.glob(source_root .. "/rust/yoz/src/completion/**/*.rs", false, true)
rust_paths[#rust_paths + 1] = source_root .. "/rust/yoz/src/completion.rs"
local metadata = vim.tbl_extend("force", Metadata.collect(root, baseline), {
  completion_rust_sha256 = Metadata.digest(source_root, rust_paths),
  runtime_sha256 = Metadata.file_hash(root .. "/__test__/support/cmp/runtime.lua"),
  native_artifact_sha256 = Metadata.file_hash(Metadata.native_library(source_root)),
  iterations = iterations,
  phase = phase,
  case_filter = arg[5],
  frecency = "production MD5; ranking off/empty/64 entries; load enabled with 64 entries; ui per scenario",
  load_history = { state = "populated", entries = 64 },
  gc = "full GC outside iterations; automatic GC enabled inside timed regions",
  engine = "era",
})
vim.fn.writefile({ vim.json.encode(metadata) }, output .. "/metadata.json")
for _, name in ipairs({ "ranking", "load", "ui" }) do
  if phase == "all" or phase == name then
    io.stdout:write("Running " .. name .. " benchmark\n")
    io.stdout:flush()
    local result = require("__test__.bench.cmp." .. name).run({
      root = root,
      output = output,
      baseline = baseline,
      iterations = iterations,
      engine = "era",
      -- Load measures a populated history; UI scenarios enable history individually.
      frecency = name ~= "ui",
      frecency_entries = 64,
      case_filter = arg[5],
    })
    vim.fn.writefile({ vim.json.encode(result) }, output .. "/" .. name .. ".json")
  end
end
print("Results: " .. output)
