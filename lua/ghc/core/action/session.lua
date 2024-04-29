-- https://github.com/folke/persistence.nvim/blob/4982499c1636eac254b72923ab826ee7827b3084/lua/persistence/init.lua#L1

local globals = require("ghc.core.setting.globals")
local md5 = require("ghc.core.util.md5")
local path = require("ghc.core.util.path")

---@class ghc.core.action.quit
local M = {}

M.storage_dir = vim.fn.expand(vim.fn.stdpath("state") .. globals.path_sep .. "sessions" .. globals.path_sep)
M.session_file_prefix = "ghc_sf_"

function M.get_session_filepath()
  local workspace_path = path.workspace()
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path)
  local hash = md5.sumhexa(workspace_path)
  local session_filename = M.session_file_prefix .. hash .. "_" .. workspace_name .. ".vim"
  local session_filepath = M.storage_dir .. session_filename
  return session_filepath
end

function M.quit_all()
  vim.cmd("qa")
end

function M.session_save()
  local session_filepath = M.get_session_filepath()
  vim.fn.mkdir(vim.fn.fnamemodify(session_filepath, ":p:h"), "p")

  local tmp = vim.o.sessionoptions
  vim.o.sessionoptions = table.concat({ "buffers", "curdir", "folds", "tabpages", "winsize", "skiprtp" }, ",")
  vim.cmd("mks! " .. vim.fn.fnameescape(session_filepath))
  vim.o.sessionoptions = tmp
end

function M.session_load()
  local session_filepath = M.get_session_filepath()
  if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
    vim.cmd("silent! source " .. vim.fn.fnameescape(session_filepath))
  else
    vim.notify("Cannot find session_filepath at " .. session_filepath)
  end
end

function M.session_clear_all()
  local pfile = io.popen('ls -a "' .. M.storage_dir .. '"')
  if pfile then
    for filename in pfile:lines() do
      if filename and string.sub(filename, 1, #M.session_file_prefix) == M.session_file_prefix then
        local session_filepath = M.storage_dir .. filename
        if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
          os.remove(session_filepath)
          vim.notify("Removed " .. session_filepath)
        end
      end
    end
  end
end

return M
