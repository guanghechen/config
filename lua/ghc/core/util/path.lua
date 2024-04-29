local Path = require("plenary.path")
local globals = require("ghc.core.setting.globals")
local md5 = require("ghc.core.util.md5")

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

M.session_related_files_dir = vim.fn.expand(vim.fn.stdpath("state") .. globals.path_sep .. "sessions" .. globals.path_sep)

---@param opts {group: string}
function M.gen_session_related_filepath(opts)
  local group = opts.group
  local workspace_path = M.workspace()
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path)
  local hash = md5.sumhexa(workspace_path)
  local prefix = "ghc_sf_" .. group .. "_"
  local session_filename = prefix .. hash .. "_" .. workspace_name .. ".vim"
  local session_filepath = M.session_related_files_dir .. session_filename
  return session_filepath
end

---@param opts {group: string}
function M.clear_session_related_filepath(opts)
  local group = opts.group
  local pfile = io.popen('ls -a "' .. M.session_related_files_dir .. '"')
  local filename_prefix = "ghc_sf_" .. group .. "_"
  if pfile then
    for filename in pfile:lines() do
      if filename and string.sub(filename, 1, #filename_prefix) == filename_prefix then
        local session_filepath = M.session_related_files_dir .. filename
        if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
          os.remove(session_filepath)
          vim.notify("Removed " .. session_filepath)
        end
      end
    end
  end
end

return M
