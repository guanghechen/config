local __module_name__ = "dot.session" ---@type string

---@class dot.session
local M = {}

---@param filepath                      string
---@return nil
function M.load_session(filepath)
  if vim.fn.filereadable(filepath) ~= 0 then
    vim.cmd("silent! source " .. vim.fn.fnameescape(filepath))
  end
end

---@param filepath                      string
---@return nil
function M.save_session(filepath)
  stl.env.mkdirs(filepath, false)
  local tmp = vim.o.sessionoptions
  vim.o.sessionoptions = dot.var.session.persistent_options
  vim.cmd("mks! " .. vim.fn.fnameescape(filepath))
  vim.o.sessionoptions = tmp
end

---@return nil
function M.restore()
  if dot.path.is_git_repo() then
    local storage = dot.context.get_storage() ---@type dot.context.storage

    local nvim_session_filepath = nil ---@type string|nil
    if storage.nvim_session and vim.fn.filereadable(storage.nvim_session) ~= 0 then
      nvim_session_filepath = storage.nvim_session
    elseif storage.nvim_session_autosaved and vim.fn.filereadable(storage.nvim_session_autosaved) ~= 0 then
      nvim_session_filepath = storage.nvim_session_autosaved
    end

    if nvim_session_filepath then
      M.load_session(nvim_session_filepath)
      dot.context.load({
        editor = storage.editor,
        session = storage.session,
        workspace = storage.workspace,
      }, true)
      vim.schedule(dot.tab.refresh)
    end
  end
end

---@return nil
function M.restore_autosaved()
  if dot.path.is_git_repo() then
    local storage = dot.context.get_storage() ---@type dot.context.storage

    local nvim_session_filepath = nil ---@type string|nil
    if storage.nvim_session_autosaved and vim.fn.filereadable(storage.nvim_session_autosaved) ~= 0 then
      nvim_session_filepath = storage.nvim_session_autosaved
    end

    if nvim_session_filepath then
      M.load_session(nvim_session_filepath)
      dot.context.load({
        editor = storage.editor,
        session = storage.session,
        workspace = storage.workspace,
      }, true)
      vim.schedule(dot.tab.refresh)
    end
  end
end

---@return nil
function M.save()
  if dot.path.is_git_repo() then
    local storage = dot.context.get_storage() ---@type dot.context.storage
    dot.context.save({
      session = storage.session,
      workspace = storage.workspace,
    })
    M.save_session(storage.nvim_session)

    stl.reporter.info({
      from = __module_name__,
      message = "Session saved successfully!",
    })
  end
end

return M
