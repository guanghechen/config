-- https://github.com/folke/persistence.nvim/blob/4982499c1636eac254b72923ab826ee7827b3084/lua/persistence/init.lua#L1

---@class guanghechen.core.action.session
local M = {}

---@param opts {autosave: boolean}
function M.get_session_filepath(opts)
  local filename = opts.autosave and "session.autosave.vim" or "session.vim"
  return fml.path.locate_session_filepath({ filename = filename })
end

function M.session_clear()
  local filenames = { "session.autosave.vim", "session.vim" }
  fml.path.remove_session_filepaths({ filenames = filenames })
end

function M.session_clear_all()
  local filenames = { "session.autosave.vim", "session.vim" }
  fml.path.remove_session_filepaths_all({ filenames = filenames })
end

function M.quit_all()
  vim.cmd("qa")
end

function M.session_autosave()
  -- save context
  require("guanghechen.core.context.session"):save()

  local bufs = vim.tbl_filter(function(b)
    return vim.bo[b].buftype ~= "" and vim.api.nvim_buf_get_name(b) ~= ""
  end, vim.api.nvim_list_bufs())

  -- no buffers to save
  if #bufs < 1 then
    return
  end

  local session_filepath = M.get_session_filepath({ autosave = true })
  vim.fn.mkdir(vim.fn.fnamemodify(session_filepath, ":p:h"), "p")

  local tmp = vim.o.sessionoptions
  vim.o.sessionoptions = table.concat(
    { "blank", "buffers", "curdir", "folds", "localoptions", "help", "resize", "tabpages", "unix", "winpos", "winsize" },
    ","
  )
  vim.cmd("mks! " .. vim.fn.fnameescape(session_filepath))
  vim.o.sessionoptions = tmp
end

function M.session_save()
  local session_filepath = M.get_session_filepath({ autosave = false })
  vim.fn.mkdir(vim.fn.fnamemodify(session_filepath, ":p:h"), "p")

  local tmp = vim.o.sessionoptions
  vim.o.sessionoptions =
    table.concat({ "blank", "buffers", "curdir", "folds", "help", "resize", "tabpages", "winpos", "winsize" }, ",")
  vim.cmd("mks! " .. vim.fn.fnameescape(session_filepath))
  vim.o.sessionoptions = tmp

  fml.reporter.info({
    from = "session.lua",
    subject = "session_save",
    message = "Session saved successfully!",
  })
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
      fml.reporter.info({
        from = "session.lua",
        subject = "session_load",
        message = "Cannot find session_filepath at " .. session_filepath,
      })
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
