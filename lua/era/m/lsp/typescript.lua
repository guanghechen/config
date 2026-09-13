---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.lsp.typescript" ---@type string

local Fn = require("era.m.lsp.fn")

---@class era.m.lsp.typescript.IProject
---@field public server                 "tsc"|"vtsls"|"denols"
---@field public root_dir               string|nil
---@field public binpath                string|nil
---@field public tsdk                   string|nil

---@class era.m.lsp.typescript
local M = {}

local cached_filepath = nil ---@type string|nil
local cached_stat = nil ---@type uv.fs_stat.result|nil
local cached_major = nil ---@type integer|nil

---@class era.m.lsp.typescript.ISelection
---@field public filename               string
---@field public first_server           "tsc"|"vtsls"
---@field public project                era.m.lsp.typescript.IProject

local selections = {} ---@type table<integer, era.m.lsp.typescript.ISelection>

---@param filepath                      string
---@return integer|nil
local function read_major_version(filepath)
  local stat = vim.uv.fs_stat(filepath)
  if stat == nil or stat.type ~= "file" then
    cached_filepath, cached_stat, cached_major = nil, nil, nil
    return nil
  end

  -- One entry covers consecutive server-selection/startup calls without retaining old projects.
  if
    filepath == cached_filepath
    and cached_stat ~= nil
    and stat.dev == cached_stat.dev
    and stat.ino == cached_stat.ino
    and stat.size == cached_stat.size
    and stat.mtime.sec == cached_stat.mtime.sec
    and stat.mtime.nsec == cached_stat.mtime.nsec
    and stat.ctime.sec == cached_stat.ctime.sec
    and stat.ctime.nsec == cached_stat.ctime.nsec
  then
    return cached_major
  end

  -- Failed reads must remain retryable even when the file metadata does not change.
  cached_filepath, cached_stat, cached_major = nil, nil, nil
  local package_json = stl.fs.read_json({
    filepath = filepath,
    silent_on_bad_json = true,
    silent_on_bad_path = true,
  })
  if type(package_json) == "table" and package_json.name == "typescript" and type(package_json.version) == "string" then
    local version = vim.version.parse(package_json.version)
    if version ~= nil then
      cached_filepath, cached_stat, cached_major = filepath, stat, version.major
    end
  end
  return cached_major
end

---@param rootdir                       string
---@return string|nil
function M.get_tsc_binpath(rootdir)
  local binpath = rootdir .. "/node_modules/.bin/" .. (stl.env.IS_WIN and "tsc.cmd" or "tsc")
  return vim.fn.executable(binpath) == 1 and binpath or nil
end

---@param rootdir                       string
---@return era.m.lsp.typescript.IProject
function M.get_installation(rootdir)
  local project = { server = "vtsls", root_dir = rootdir } ---@type era.m.lsp.typescript.IProject
  local package_dir = rootdir .. "/node_modules/typescript"
  local major = read_major_version(package_dir .. "/package.json")
  if major == nil then
    return project
  end
  if major >= 7 then
    local binpath = M.get_tsc_binpath(rootdir)
    if binpath ~= nil then
      project.server = "tsc"
      project.binpath = binpath
    end
  else
    local tsdk = package_dir .. "/lib"
    local stat = vim.uv.fs_stat(tsdk .. "/tsserver.js")
    if stat ~= nil and stat.type == "file" then
      project.tsdk = tsdk
    end
  end
  return project
end

---@param dirname                       string
---@return era.m.lsp.typescript.IProject
function M.resolve(dirname)
  local rootdir, project_type = Fn.locate_js_project_root(dirname .. "/package.json")
  if project_type == "deno" then
    return { server = "denols", root_dir = rootdir }
  end

  local git_root = vim.fs.root(dirname, { ".git" }) ---@type string|nil
  if git_root ~= nil and (rootdir == nil or #git_root > #rootdir) then
    rootdir = git_root
  end
  local dirpath = dirname ---@type string
  while true do
    local package_dir = dirpath .. "/node_modules/typescript" ---@type string
    if vim.uv.fs_lstat(package_dir) ~= nil then
      -- The nearest installation owns this package, even if it is old or incomplete.
      return M.get_installation(dirpath)
    end

    if dirpath == rootdir then
      break
    end
    local parent = vim.fs.dirname(dirpath) ---@type string
    if parent == dirpath then
      break
    end
    dirpath = parent
  end

  return { server = "vtsls", root_dir = rootdir }
end

---@param bufnr                         integer
---@param server                        "tsc"|"vtsls"
---@return era.m.lsp.typescript.IProject
function M.select_for_buffer(bufnr, server)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local selection = selections[bufnr]
  if selection ~= nil and selection.filename == filename and selection.first_server ~= server then
    selections[bufnr] = nil
    return selection.project
  end

  local project = filename == "" and { server = "vtsls" } or M.resolve(vim.fs.dirname(filename))
  -- Keep the latest choice for clients whose scheduled startup/initialization is still pending.
  vim.b[bufnr].typescript_lsp_server = project.server
  selection = { filename = filename, first_server = server, project = project }
  selections[bufnr] = selection
  -- Neovim checks both root callbacks synchronously. Expire even when only one config is enabled.
  vim.schedule(function()
    if selections[bufnr] == selection then
      selections[bufnr] = nil
    end
  end)

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, _uninitialized = true })) do
    if (client.name == "tsc" or client.name == "vtsls") and client.name ~= project.server then
      vim.lsp.buf_detach_client(bufnr, client.id)
    end
  end
  return project
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@return nil
function M.on_attach(client, bufnr)
  -- Wait for Neovim to finish on_attach and its scheduled capability initialization before detaching.
  vim.schedule(function()
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) or not vim.lsp.buf_is_attached(bufnr, client.id) then
        return
      end
      local server = vim.b[bufnr].typescript_lsp_server
      if server ~= nil and server ~= client.name then
        vim.lsp.buf_detach_client(bufnr, client.id)
      end
    end)
  end)
end

return M
