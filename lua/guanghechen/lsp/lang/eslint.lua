local on_attach = require("guanghechen.lsp.common").on_attach
local on_init = require("guanghechen.lsp.common").on_init
local capabilities = require("guanghechen.lsp.common").capabilities

---@type string[]
local ESLINT_CONFIG_FILENAMES = {
  ".eslintrc",
  ".eslintrc.json",
  ".eslintrc.js",
  ".eslintrc.mjs",
}

---@param dirpath                       string
---@return boolean
local function check_if_eslint_root(dirpath)
  for _, filename in ipairs(ESLINT_CONFIG_FILENAMES) do
    local filepath = dirpath .. eve.path.SEP .. filename ---@type string
    if eve.fs.is_file_or_dir(filepath) then
      return true
    end
  end
  return false
end

---@param cwd                           string
---@param filepath                      string
---@return string|nil
local function locate_latest_eslint_root(cwd, filepath)
  local pieces = eve.path.split(filepath) ---@type string[]
  local k = #pieces - 1 ---@type integer
  while k >= 1 do
    local dirpath = table.concat(pieces, eve.path.SEP, 1, k) ---@type string
    if dirpath == cwd then
      return nil
    end

    if check_if_eslint_root(dirpath) then
      return dirpath
    end
    k = k - 1
  end
  return nil
end

return {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  root_dir = function(filename)
    local cwd = eve.path.cwd() ---@type string
    if check_if_eslint_root(cwd) then
      return cwd
    end

    local workspace = eve.path.cwd() ---@type string
    if cwd ~= workspace and check_if_eslint_root(workspace) then
      return workspace
    end

    return locate_latest_eslint_root(cwd, filename) or cwd
  end,
  settings = {
    eslint = {
      workingDirectories = { mode = "auto" },
    },
  },
}
