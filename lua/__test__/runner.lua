---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.runner" ---@type string

local M = {}

local ROOT = "lua/__test__" ---@type string

local EXCLUDED = {
  ["bootstrap.lua"] = true,
  ["harness.lua"] = true,
  ["run.lua"] = true,
  ["runner.lua"] = true,
} ---@type table<string, boolean>

---@param path                          string
---@return string
local function normalize(path)
  return (path:gsub("\\", "/"))
end

---@param root                          string
---@param filepath                      string
---@return boolean
local function is_excluded(root, filepath)
  local prefix = normalize(root):gsub("/+$", "") .. "/" ---@type string
  if filepath:sub(1, #prefix) ~= prefix then
    return false
  end

  local relative = filepath:sub(#prefix + 1) ---@type string
  return EXCLUDED[relative] == true
end

---@param dirpath                       string
---@param root                          string
---@param result                        string[]
---@return nil
local function collect_lua_files(root, dirpath, result)
  local ok, iter = pcall(vim.fs.dir, dirpath)
  if not ok or iter == nil then
    io.stderr:write("WARN test runner cannot read root: " .. dirpath .. "\n")
    return
  end

  for name, type in iter do
    local filepath = normalize(dirpath .. "/" .. name) ---@type string
    if type == "directory" then
      collect_lua_files(root, filepath, result)
    elseif type == "file" and filepath:sub(-4) == ".lua" and not is_excluded(root, filepath) then
      result[#result + 1] = filepath
    end
  end
end

---@param root                          ?string
---@param filter                        ?string
---@return string[]
function M.discover(root, filter)
  root = root or ROOT
  local suites = {} ---@type string[]
  collect_lua_files(root, root, suites)
  table.sort(suites)

  if filter == nil or filter == "" then
    return suites
  end

  local filtered = {} ---@type string[]
  for _, suite in ipairs(suites) do
    if suite:find(filter, 1, true) then
      filtered[#filtered + 1] = suite
    end
  end
  return filtered
end

---@param suites                        string[]
---@return integer
local function run_suites(suites)
  local nvim = vim.v.progpath ~= "" and vim.v.progpath or "nvim" ---@type string
  local failed = 0 ---@type integer

  for _, suite in ipairs(suites) do
    io.write("== " .. suite .. "\n")
    io.flush()
    -- Capture stdout and stderr together so nested `nvim -l` reports stay ordered.
    local command = string.format("%s -l %s 2>&1", vim.fn.shellescape(nvim), vim.fn.shellescape(suite))
    local output = vim.fn.system({ "sh", "-c", command }) ---@type string
    local code = vim.v.shell_error ---@type integer
    if output ~= "" then
      io.write(output)
      if output:sub(-1) ~= "\n" then
        io.write("\n")
      end
    end
    if code ~= 0 then
      failed = failed + 1
    end
  end

  print(string.format("\n%d suite(s), %d failed", #suites, failed))
  return failed
end

---@param opts                          ?{ root?: string, filter?: string }
---@return integer
function M.run_all(opts)
  opts = opts or {}
  local suites = M.discover(opts.root, opts.filter) ---@type string[]
  return run_suites(suites)
end

---@return nil
function M.main()
  local filter = arg and arg[1] or nil ---@type string|nil
  local failed = M.run_all({ filter = filter }) ---@type integer
  os.exit(failed > 0 and 1 or 0)
end

return M
