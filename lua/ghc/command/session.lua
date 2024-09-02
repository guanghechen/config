-- https://github.com/folke/persistence.nvim/blob/4982499c1636eac254b72923ab826ee7827b3084/lua/persistence/init.lua#L1

---@param bufnr                         integer
---@return boolean
local function does_buf_savable(bufnr)
  return vim.bo[bufnr].buftype ~= "" and vim.api.nvim_buf_get_name(bufnr) ~= ""
end

---@param pathtype                      "session"|"state"|"session_autosaved"|"state_autosaved"
---@return string
local function get_filepath(pathtype)
  if pathtype == "session" then
    local filepath = eve.path.locate_session_filepath({ filename = "session.vim" })
    vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":p:h"), "p")
    return filepath
  end

  if pathtype == "state" then
    local filepath = eve.path.locate_session_filepath({ filename = "state.json" })
    vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":p:h"), "p")
    return filepath
  end

  if pathtype == "session_autosaved" then
    local filepath = eve.path.locate_session_filepath({ filename = "session.autosave.vim" })
    vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":p:h"), "p")
    return filepath
  end

  if pathtype == "state_autosaved" then
    local filepath = eve.path.locate_session_filepath({ filename = "state.autosave.json" })
    vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":p:h"), "p")
    return filepath
  end

  eve.reporter.error({
    from = "ghc.command.session",
    subject = "get_filepath",
    message = "Unexpected pathtype.",
    details = { pathtype = pathtype }
  })
  return eve.path.locate_session_filepath({ filename = "session.tmp.txt" })
end


---@class ghc.command.session
local M = {}

---@return nil
function M.clear_current()
  local filenames = { "session.vim", "state.vim", "session.autosave.nvim", "state.autosave.json" }
  eve.path.remove_session_filepaths({ filenames = filenames })
end

---@return nil
function M.clear_all()
  local filenames = { "session.vim", "state.vim", "session.autosave.nvim", "state.autosave.json" }
  eve.path.remove_session_filepaths_all({ filenames = filenames })
end

---@return nil
function M.quit_all()
  vim.cmd("qa")
end

---@return nil
function M.autosave()
  if eve.array.some(vim.api.nvim_list_bufs(), does_buf_savable) then
    return
  end

  local session_filepath = get_filepath("session_autosaved")
  local state_fliepath = get_filepath("state_autosaved")
  fml.api.state.save(state_fliepath)

  local tmp = vim.o.sessionoptions
  vim.o.sessionoptions = eve.constants.SESSION_AUTOSAVE_OPTION
  vim.cmd("mks! " .. vim.fn.fnameescape(session_filepath))
  vim.o.sessionoptions = tmp
end

function M.save()
  local session_filepath = get_filepath("session")
  local state_fliepath = get_filepath("state")
  fml.api.state.save(state_fliepath)

  local tmp = vim.o.sessionoptions
  vim.o.sessionoptions = eve.constants.SESSION_SAVE_OPTION
  vim.cmd("mks! " .. vim.fn.fnameescape(session_filepath))
  vim.o.sessionoptions = tmp

  eve.reporter.info({
    from = "ghc.command.sesession",
    subject = "save",
    message = "Session saved successfully!",
  })
end

function M.load()
  local session_filepath = get_filepath("session")
  local state_fliepath = get_filepath("state")

  if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
    vim.cmd("silent! source " .. vim.fn.fnameescape(session_filepath))

    if state_fliepath and vim.fn.filereadable(state_fliepath) ~= 0 then
      fml.api.state.load(state_fliepath)
    end
  else
    M.load_autosaved()
  end
end

function M.load_autosaved()
  local session_filepath = get_filepath("session_autosaved")
  local state_fliepath = get_filepath("state_autosaved")
  if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
    vim.cmd("silent! source " .. vim.fn.fnameescape(session_filepath))

    if state_fliepath and vim.fn.filereadable(state_fliepath) ~= 0 then
      fml.api.state.load(state_fliepath)
    end
  else
    eve.reporter.warn({
      from = "ghc.command.session",
      subject = "load_autosaved",
      message = "Cannot find session filepath" .. session_filepath,
    })
  end
end

return M
