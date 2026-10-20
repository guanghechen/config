---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp.metadata" ---@type string

local M = {}

---@param path                          string
---@return string
local function read(path)
  local file = assert(io.open(path, "rb"))
  local contents = file:read("*a")
  file:close()
  return contents
end

---@param path                          string
---@return string
function M.file_hash(path)
  return vim.fn.sha256(read(path))
end

---@param directory                     string
---@param paths                         string[]
---@return string
function M.digest(directory, paths)
  table.sort(paths)
  local sources = {}
  for _, path in ipairs(paths) do
    sources[#sources + 1] = path:sub(#directory + 1) .. "\0" .. read(path)
  end
  return vim.fn.sha256(table.concat(sources, "\0"))
end

---The native library a checkout installs for this platform.
---@param root                          string
---@return string
function M.native_library(root)
  return root .. "/lua/yoz." .. (vim.fn.has("win32") == 1 and "dll" or "so")
end

---@param root                          string
---@param baseline                      ?string
---@param entry                         string Repository-relative CLI path.
---@return table
function M.collect(root, baseline, entry)
  local source_root = baseline or root
  local paths = vim.fn.glob(root .. "/__test__/bench/cmp/*.lua", false, true)
  paths[#paths + 1] = root .. "/" .. entry
  paths[#paths + 1] = root .. "/__test__/support/cmp/runtime.lua"
  paths[#paths + 1] = root .. "/__test__/support/ui.lua"
  return {
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    repository_revision = vim.trim(vim.system({ "git", "rev-parse", "HEAD" }):wait().stdout),
    baseline = baseline,
    completion_lua_sha256 = M.digest(
      source_root,
      vim.fn.glob(source_root .. "/lua/era/keystroke/cmp/**/*.lua", false, true)
    ),
    benchmark_lua_sha256 = M.digest(root, paths),
    neovim = vim.version(),
    luajit = jit.version,
    system = vim.uv.os_uname(),
    cpu = vim.uv.cpu_info()[1].model,
    parallelism = vim.uv.available_parallelism(),
    warmup = 5,
  }
end

return M
