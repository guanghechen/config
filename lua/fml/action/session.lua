local __module_name__ = "fml.action.session" ---@type string

---@class fml.action.session
local M = {}

---@return nil
function M.restore()
  if eve.path.is_repo_git() then
    local storage = eve.state.get_storage() ---@type eve.state.storage

    local nvim_session_filepath = nil ---@type string|nil
    if storage.nvim_session and vim.fn.filereadable(storage.nvim_session) ~= 0 then
      nvim_session_filepath = storage.nvim_session
    elseif storage.nvim_session_autosaved and vim.fn.filereadable(storage.nvim_session_autosaved) ~= 0 then
      nvim_session_filepath = storage.nvim_session_autosaved
    end

    if nvim_session_filepath then
      eve.session.load_session(nvim_session_filepath)
      eve.state.load({
        editor = storage.editor,
        session = storage.session,
        workspace = storage.workspace,
      }, true)
      vim.schedule(eve.tab.refresh)
    end
  end
end

---@return nil
function M.restore_autosaved()
  if eve.path.is_repo_git() then
    local storage = eve.state.get_storage() ---@type eve.state.storage

    local nvim_session_filepath = nil ---@type string|nil
    if storage.nvim_session_autosaved and vim.fn.filereadable(storage.nvim_session_autosaved) ~= 0 then
      nvim_session_filepath = storage.nvim_session_autosaved
    end

    if nvim_session_filepath then
      eve.session.load_session(nvim_session_filepath)
      eve.state.load({
        editor = storage.editor,
        session = storage.session,
        workspace = storage.workspace,
      }, true)
      vim.schedule(eve.tab.refresh)
    end
  end
end

---@return nil
function M.save()
  if eve.path.is_repo_git() then
    local storage = eve.state.get_storage() ---@type eve.state.storage
    eve.state.save({
      session = storage.session,
      workspace = storage.workspace,
    })
    eve.session.save_session(storage.nvim_session)

    eve.reporter.info({
      from = __module_name__,
      message = "Session saved successfully!",
    })
  end
end

return M
