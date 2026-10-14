-- nvim -l __test__/bench/cmp_native.lua [output-dir] [baseline-dir|-] [samples] [ranking|load|all] [case-filter]
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp_native" ---@type string

local root = assert(vim.uv.cwd())
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local output = arg[1] or vim.fn.tempname() .. "-cmp-native"
local baseline = arg[2] ~= "-" and arg[2] or nil
local samples = tonumber(arg[3]) or 15
local phase = arg[4] or "all"
assert(samples >= 5 and samples % 1 == 0, "samples must be an integer >= 5")
assert(vim.tbl_contains({ "ranking", "load", "all" }, phase), "unknown benchmark phase")
vim.fn.mkdir(output, "p")

local Metadata = require("__test__.bench.cmp.metadata")
local source_root = baseline or root
local rust_paths = vim.fn.glob(source_root .. "/rust/yoz/src/completion/**/*.rs", false, true)
rust_paths[#rust_paths + 1] = source_root .. "/rust/yoz/src/completion.rs"
local metadata = vim.tbl_extend("force", Metadata.collect(root, baseline, "__test__/bench/cmp_native.lua"), {
  completion_rust_sha256 = Metadata.digest(source_root, rust_paths),
  runtime_sha256 = Metadata.file_hash(root .. "/__test__/fixtures/era/keystroke/cmp/runtime.lua"),
  native_sha256 = Metadata.file_hash(source_root .. "/bin/nix.yoz.so"),
  samples = samples,
  phase = phase,
  case_filter = arg[5],
  frecency = "production MD5; ranking off/empty/64 entries; load enabled with 64 entries",
  load_history = { state = "populated", entries = 64 },
  gc = "full GC outside samples; automatic GC enabled inside timed regions",
  engine = "era",
})
vim.fn.writefile({ vim.json.encode(metadata) }, output .. "/metadata.json")
for _, name in ipairs({ "ranking", "load" }) do
  if phase == "all" or phase == name then
    io.stdout:write("Running " .. name .. " benchmark\n")
    io.stdout:flush()
    local result = require("__test__.bench.cmp." .. name).run({
      root = root,
      output = output,
      baseline = baseline,
      samples = samples,
      engine = "era",
      frecency = true,
      frecency_entries = 64,
      case_filter = arg[5],
    })
    vim.fn.writefile({ vim.json.encode(result) }, output .. "/" .. name .. ".json")
  end
end
print("Results: " .. output)
