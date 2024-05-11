local Path = require("plenary.path")
local globals = require("ghc.core.setting.globals")
local md5 = require("guanghechen.util.md5")

---@class ghc.core.util.path
local M = {}

function M.findGitRepoFromPath(p)
  local current_dir = Path:new(p)
  while current_dir ~= nil do
    local gitDir = current_dir:joinpath(".git")
    if gitDir:exists() and gitDir:is_dir() then
      return current_dir:absolute()
    end

    local parent_dir = current_dir:parent()
    if current_dir:absolute() == parent_dir:absolute() then
      return nil
    end
    current_dir = parent_dir
  end
  return nil
end

function M.relative(from, to)
  return Path:new(to):make_relative(from)
end

function M.is_absolute(p)
  return Path:new(p):is_absolute()
end

function M.workspace()
  local cwd = vim.uv.cwd()
  return M.findGitRepoFromPath(cwd) or cwd
end

function M.cwd()
  return vim.uv.cwd()
end

function M.current()
  return vim.fn.expand("%:p:h")
end

---@param scope "W"|"C"|"D"
function M.scope(scope)
  if scope == "W" then
    return M.workspace()
  elseif scope == "C" then
    return M.cwd()
  elseif scope == "D" then
    return M.current()
  else
    return M.cwd()
  end
end

M.session_related_files_dir = vim.fn.expand(vim.fn.stdpath("state") .. globals.path_sep .. "sessions" .. globals.path_sep)

---@param opts {filename: string}
function M.gen_session_related_filepath(opts)
  local filename = opts.filename
  local workspace_path = M.workspace()
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path)
  local hash = md5.sumhexa(workspace_path)
  local session_filename = "ghc_" .. hash .. "_" .. workspace_name .. globals.path_sep .. filename
  local session_filepath = M.session_related_files_dir .. session_filename
  return session_filepath
end

---@param opts {filename: string}
function M.clear_session_related_filepath(opts)
  local filename = opts.filename
  local pfile = io.popen('ls -a "' .. M.session_related_files_dir .. '"')
  local dirname_prefix = "ghc_"
  if pfile then
    for dirname in pfile:lines() do
      if dirname and string.sub(dirname, 1, #dirname_prefix) == dirname_prefix then
        local session_filepath = M.session_related_files_dir .. dirname .. globals.path_sep .. filename
        if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
          os.remove(session_filepath)
          vim.notify("Removed " .. session_filepath)
        end
      end
    end
  end
end

return M
