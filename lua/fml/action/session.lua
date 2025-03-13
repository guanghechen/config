local __module_name__ = "fml.action.session" ---@type string

local session = require("eve.module.session")
local state = require("eve.state")

---@class fml.action.session
local M = {}

---@return nil
function M.restore()
  if eve.std.path.is_repo_git() then
    local storage = state.get_storage() ---@type eve.state.storage

    local nvim_session_filepath = nil ---@type string|nil
    if storage.nvim_session and vim.fn.filereadable(storage.nvim_session) ~= 0 then
      nvim_session_filepath = storage.nvim_session
    elseif storage.nvim_session_autosaved and vim.fn.filereadable(storage.nvim_session_autosaved) ~= 0 then
      nvim_session_filepath = storage.nvim_session_autosaved
    end

    if nvim_session_filepath then
      session.load_session(nvim_session_filepath)
      state.load({
        editor = storage.editor,
        session = storage.session,
        workspace = storage.workspace,
      }, true)
      state.refresh()
    end
  end
end

---@return nil
function M.restore_autosaved()
  if eve.std.path.is_repo_git() then
    local storage = state.get_storage() ---@type eve.state.storage

    local nvim_session_filepath = nil ---@type string|nil
    if storage.nvim_session_autosaved and vim.fn.filereadable(storage.nvim_session_autosaved) ~= 0 then
      nvim_session_filepath = storage.nvim_session_autosaved
    end

    if nvim_session_filepath then
      session.load_session(nvim_session_filepath)
      state.load({
        editor = storage.editor,
        session = storage.session,
        workspace = storage.workspace,
      }, true)
      state.refresh()
    end
  end
end

---@return nil
function M.save()
  if eve.std.path.is_repo_git() then
    local storage = state.get_storage() ---@type eve.state.storage
    state.save({
      session = storage.session,
      workspace = storage.workspace,
    })
    session.save_session(storage.nvim_session)

    eve.std.reporter.info({
      from = __module_name__,
      message = "Session saved successfully!",
    })
  end
end

return M
