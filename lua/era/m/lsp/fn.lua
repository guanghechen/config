---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.lsp.fn" ---@type string

---@class era.m.lsp.fn
local M = {}

local JS_PACKAGE_FILENAMES = {
  "package-lock.json",
  "yarn.lock",
  "pnpm-lock.yaml",
  "bun.lockb",
  "bun.lock",
}

----------------------------------------------------------------------------------------------------
-- Symbol
----------------------------------------------------------------------------------------------------

---@param cursor                        era.m.lsp.ISymbolPos
---@param range                         { start: era.m.lsp.ISymbolPos, end: era.m.lsp.ISymbolPos }
---@return boolean
local function is_within_range(cursor, range)
  local start = range.start ---@type era.m.lsp.ISymbolPos
  local finish = range["end"] ---@type era.m.lsp.ISymbolPos
  return (cursor.line > start.line or (cursor.line == start.line and cursor.character >= start.character))
    and (cursor.line < finish.line or (cursor.line == finish.line and cursor.character <= finish.character))
end

---@param cursor                        era.m.lsp.ISymbolPos
---@param symbols                       ?any[]
---@return any[]|nil
function M.find_symbol_path(cursor, symbols)
  if symbols == nil then
    return
  end

  for _, symbol in ipairs(symbols) do
    if symbol.location then
      local range = symbol.location.range
      if is_within_range(cursor, range) then
        return { symbol }
      end
    elseif symbol.range then
      local range = symbol.range
      if is_within_range(cursor, range) then
        local path = { symbol }
        if symbol.children then
          local child_path = M.find_symbol_path(cursor, symbol.children)
          if child_path then
            for _, child_symbol in ipairs(child_path) do
              path[#path + 1] = child_symbol
            end
          end
        end
        return path
      end
    end
  end
  return nil
end

----------------------------------------------------------------------------------------------------
-- Locate
----------------------------------------------------------------------------------------------------

---@param dirpath                       string
---@param config_filenames              string[]
---@return string|nil
function M.find_filepath(dirpath, config_filenames)
  for _, filename in ipairs(config_filenames) do
    local filepath = dirpath .. stl.env.PATH_SEP .. filename ---@type string
    if yoz.path.is_exist(filepath) then
      return filepath
    end
  end
end

---@param filepath                      string
---@param config_filenames              string[]
---@return string|nil
---@return string|nil
function M.locate_lsp_root(filepath, config_filenames)
  if filepath == "" then
    return
  end

  local dirpath = vim.fs.dirname(filepath) ---@type string
  while true do
    local config_filepath = M.find_filepath(dirpath, config_filenames) ---@type string|nil
    if config_filepath ~= nil then
      return dirpath, config_filepath
    end

    local parent = vim.fs.dirname(dirpath) ---@type string
    if parent == dirpath then
      break
    end
    dirpath = parent
  end
end

---@param filepath                      string
---@return string|nil rootdir
---@return "deno"|"node" project_type
function M.locate_js_project_root(filepath)
  if filepath == "" then
    return nil, "node"
  end

  local node_root = M.locate_lsp_root(filepath, JS_PACKAGE_FILENAMES) ---@type string|nil
  local deno_root = M.locate_lsp_root(filepath, { "deno.json", "deno.jsonc" }) ---@type string|nil
  local deno_lock_root = vim.fs.root(filepath, { "deno.lock" }) ---@type string|nil
  local rootdir = nil ---@type string|nil

  if deno_lock_root ~= nil and (node_root == nil or #deno_lock_root > #node_root) then
    rootdir = deno_lock_root
  end
  if
    deno_root ~= nil
    and (node_root == nil or #deno_root >= #node_root)
    and (rootdir == nil or #deno_root >= #rootdir)
  then
    rootdir = deno_root
  end

  if rootdir ~= nil then
    return rootdir, "deno"
  end
  return node_root, "node"
end

---@param bin                           string
---@param silent                        ?boolean
---@return string|nil
function M.locate_mason_bin_path(bin, silent)
  local root = vim.env.MASON or (stl.env.HOME_NVIM_DATA .. stl.env.PATH_SEP .. "mason")
  local resolved_binname = stl.env.IS_WIN and not bin:match("%.cmd$") and (bin .. ".cmd") or bin ---@type string
  local filepath = dot.path.normalize(root .. "/bin/" .. resolved_binname) ---@type string

  if yoz.path.is_exist_file(filepath) then
    return filepath
  end

  if not silent then
    stl.reporter.warn({
      from = __module_name__,
      subject = "locate_mason_bin_path",
      message = string.format(
        "Mason binary not found for **%s**:\\n- You may need to install the package via Mason.",
        resolved_binname,
        filepath
      ),
      details = {
        root = root,
        original_binname = bin,
        resolved_binname = resolved_binname,
        filepath = filepath,
      },
    })
  end

  return nil
end

---@param pkg                           string
---@param pkg_path                      string
---@param silent                        ?boolean
---@return string|nil
function M.locate_mason_pkg_path(pkg, pkg_path, silent)
  local root = vim.env.MASON or (stl.env.HOME_NVIM_DATA .. stl.env.PATH_SEP .. "mason")
  local filepath = root .. "/packages/" .. pkg .. "/" .. pkg_path

  if not vim.uv.fs_stat(filepath) and not stl.env.IS_HEADLESS then
    if not silent then
      stl.reporter.warn({
        from = __module_name__,
        subject = "locate_mason_pkg_path",
        message = string.format(
          "Mason package path not found for **%s**:\n- `%s`\nYou may need to force update the package.",
          pkg,
          pkg_path
        ),
      })
    end
    return nil
  end

  return filepath
end

----------------------------------------------------------------------------------------------------
-- Server
----------------------------------------------------------------------------------------------------

---@return nil
function M.restart_server()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local clients = vim.lsp.get_clients({ bufnr = bufnr }) ---@type vim.lsp.Client[]

  stl.reporter.info({
    from = __module_name__,
    subject = "restart_server",
  })

  for _, client in ipairs(clients) do
    if client.name ~= "copilot" then
      client:stop(true)
    end
  end

  vim.defer_fn(function()
    vim.cmd("edit")
  end, 100)
end

return M
