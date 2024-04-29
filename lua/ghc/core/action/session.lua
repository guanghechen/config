-- https://github.com/folke/persistence.nvim/blob/4982499c1636eac254b72923ab826ee7827b3084/lua/persistence/init.lua#L1

local path = require("ghc.core.util.path")

---@class ghc.core.action.quit
local M = {}

---@param opts {autosave: boolean}
function M.get_session_filepath(opts)
  local group = opts.autosave and "session#autosave" or "session"
  return path.gen_session_related_filepath({ group = group })
end

function M.session_clear_all()
  local groups = { "session", "session#autosave" }
  for _, group in ipairs(groups) do
    path.clear_session_related_filepath({ group = group })
  end
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

return M
