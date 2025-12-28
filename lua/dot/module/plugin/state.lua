---@class dot.module.plugin.state
---@field public options                dot.module.plugin.IConfig
---@field public specs                  dot.module.plugin.IPluginSpec[]
---@field public lock                   table<string, dot.module.plugin.ILockEntry>
---@field public ns                     integer
---@field protected _lock_loaded        boolean
local M = {
  options = {
    lockfile = dot.path.normalize(vim.fn.stdpath("config") .. "/lazy-lock.json"),
    root = dot.path.normalize(ark.env.HOME_NVIM_DATA .. "/lazy"),
    ui = {
      size = { width = 119, height = 0.8 },
      border = "rounded",
      title = " Plugin ",
      icons = {
      cmd = " ",
      dep = " ",
      event = " ",
      ft = " ",
      keys = "󰌌 ",
      lazy = "󰂠 ",
      loaded = " ",
      not_loaded = " ",
      source = "󰘓 ",
      },
    },
  },
  specs = {},
  lock = {},
  ns = vim.api.nvim_create_namespace("dot_plugin"),
  _lock_loaded = false,
}

---@param specs                         dot.module.plugin.IPluginSpec[]
---@return nil
function M.setup(specs)
  M.specs = specs
end

----------------------------------------------------------------------------------------------------

---@return nil
function M.load_lock()
  if M._lock_loaded then
    return
  end
  M._lock_loaded = true
  M.lock = {}

  local f = io.open(M.options.lockfile, "r")
  if f then
    local data = f:read("*a") ---@type string
    local ok, lock = pcall(vim.json.decode, data)
    if ok and type(lock) == "table" then
      M.lock = lock
    end
    f:close()
  end
end

---@param plugins                       table<string, dot.module.plugin.ILockEntry>
---@return nil
function M.update_lock(plugins)
  vim.fn.mkdir(vim.fn.fnamemodify(M.options.lockfile, ":p:h"), "p")

  local f = assert(io.open(M.options.lockfile, "wb"))
  f:write("{\n")

  local names = vim.tbl_keys(plugins) ---@type string[]
  table.sort(names)

  for n, name in ipairs(names) do
    local info = plugins[name] ---@type dot.module.plugin.ILockEntry
    f:write(([[  %q: { "branch": %q, "commit": %q }]]):format(name, info.branch, info.commit))
    if n ~= #names then
      f:write(",\n")
    end
  end

  f:write("\n}\n")
  f:close()

  M.lock = plugins
  M._lock_loaded = true
end

---@param name                          string
---@return dot.module.plugin.ILockEntry|nil
function M.get_lock(name)
  M.load_lock()
  return M.lock[name]
end

---@return nil
function M.reload_lock()
  M._lock_loaded = false
  M.load_lock()
end

---@return string[]
function M.collect_orphan_plugins()
  local known_plugins = {} ---@type table<string, boolean>
  for _, spec in ipairs(M.specs) do
    known_plugins[spec.name] = true
  end

  local orphans = {} ---@type string[]
  local handle = vim.uv.fs_scandir(M.options.root)
  if handle then
    while true do
      local name, type = vim.uv.fs_scandir_next(handle) ---@type string|nil, string|nil
      if not name then
        break
      end
      if type == "directory" and not known_plugins[name] then
        orphans[#orphans + 1] = name
      end
    end
  end
  table.sort(orphans)

  return orphans
end

---@return nil
function M.remove_orphan_lock_entries()
  M.load_lock()

  local known_plugins = {} ---@type table<string, boolean>
  for _, spec in ipairs(M.specs) do
    known_plugins[spec.name] = true
  end

  local new_lock = {} ---@type table<string, dot.module.plugin.ILockEntry>
  for name, entry in pairs(M.lock) do
    if known_plugins[name] then
      new_lock[name] = entry
    end
  end

  M.update_lock(new_lock)
end

return M
