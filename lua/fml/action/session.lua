local __module_name__ = "fml.action.session" ---@type string

local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")
local session = require("eve.module.session")
local state = require("eve.state")

---@class fml.action.session
local M = {}

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.restore(context)
  if path.is_git_repo() then
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

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.restore_autosaved(context)
  if path.is_git_repo() then
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

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.save(context)
  if path.is_git_repo() then
    local storage = state.get_storage() ---@type eve.state.storage
    state.save({
      session = storage.session,
      workspace = storage.workspace,
    })
    session.save_session(storage.nvim_session)

    reporter.info({
      from = __module_name__,
      message = "Session saved successfully!",
    })
  end
end

return M
