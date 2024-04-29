-- https://github.com/folke/persistence.nvim/blob/4982499c1636eac254b72923ab826ee7827b3084/lua/persistence/init.lua#L1

local globals = require("ghc.core.setting.globals")
local md5 = require("ghc.core.util.md5")
local path = require("ghc.core.util.path")

---@class ghc.core.action.quit
local M = {}

M.storage_dir = vim.fn.expand(vim.fn.stdpath("state") .. globals.path_sep .. "sessions" .. globals.path_sep)
M.session_file_prefix = "ghc_sf_"

---@param opts {autosave: boolean}
function M.get_session_filepath(opts)
  local autosave = opts.autosave
  local workspace_path = path.workspace()
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path)
  local hash = md5.sumhexa(workspace_path)
  local prefix = autosave and M.session_file_prefix .. "autosave_" or M.session_file_prefix
  local session_filename = prefix .. hash .. "_" .. workspace_name .. ".vim"
  local session_filepath = M.storage_dir .. session_filename
  return session_filepath
end

function M.quit_all()
  vim.cmd("qa")
end

function M.session_autosave()
  -- remove buffers whose files are located outside of workspace
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local workspace = path.workspace()
    local bufpath = vim.api.nvim_buf_get_name(buf) .. "/"
    if not bufpath:match("^" .. vim.pesc(workspace)) then
      vim.api.nvim_buf_delete(buf, {})
    end
  end

  local bufs = vim.tbl_filter(function(b)
    if vim.bo[b].buftype ~= "" then
      return false
    end
    if vim.bo[b].filetype == "gitcommit" then
      return false
    end
    if vim.bo[b].filetype == "gitrebase" then
      return false
    end
    return vim.api.nvim_buf_get_name(b) ~= ""
  end, vim.api.nvim_list_bufs())

  -- no buffers to save
  if #bufs == 0 then
    return
  end

  local session_filepath = M.get_session_filepath({ autosave = true })
  vim.fn.mkdir(vim.fn.fnamemodify(session_filepath, ":p:h"), "p")

  local tmp = vim.o.sessionoptions
  vim.o.sessionoptions = table.concat({ "buffers", "curdir", "folds", "tabpages", "winsize", "skiprtp" }, ",")
  vim.cmd("mks! " .. vim.fn.fnameescape(session_filepath))
  vim.o.sessionoptions = tmp
end

function M.session_save()
  local session_filepath = M.get_session_filepath({ autosave = false })
  vim.fn.mkdir(vim.fn.fnamemodify(session_filepath, ":p:h"), "p")

  local tmp = vim.o.sessionoptions
  vim.o.sessionoptions = table.concat({ "buffers", "curdir", "folds", "tabpages", "winsize", "skiprtp" }, ",")
  vim.cmd("mks! " .. vim.fn.fnameescape(session_filepath))
  vim.o.sessionoptions = tmp
end

function M.session_load()
  local session_filepath = M.get_session_filepath({ autosave = false })
  if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
    vim.cmd("silent! source " .. vim.fn.fnameescape(session_filepath))
  else
    -- try to load autosaved session
    local session_filepath_autosaved = M.get_session_filepath({ autosave = true })
    if session_filepath_autosaved and vim.fn.filereadable(session_filepath_autosaved) ~= 0 then
      vim.cmd("silent! source " .. vim.fn.fnameescape(session_filepath_autosaved))
    else
      vim.notify("Cannot find session_filepath at " .. session_filepath)
    end
  end
end

function M.session_load_autosaved()
  local session_filepath = M.get_session_filepath({ autosave = true })
  if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
    vim.cmd("silent! source " .. vim.fn.fnameescape(session_filepath))
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
