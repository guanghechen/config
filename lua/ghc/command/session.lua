local __module_name__ = "ghc.command.session" ---@type string

local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")
local state = require("eve.state")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.session_restore,
    desc = "session: restore",
    action = function()
      if path.is_git_repo() then
        local nvim_session_filepath = nil ---@type string|nil
        local storage = state.get_storage() ---@type eve.t.state.storage
        if storage.nvim_session and vim.fn.filereadable(storage.nvim_session) ~= 0 then
          nvim_session_filepath = storage.nvim_session
        elseif storage.nvim_session_autosaved and vim.fn.filereadable(storage.nvim_session_autosaved) ~= 0 then
          nvim_session_filepath = storage.nvim_session_autosaved
        end

        if nvim_session_filepath then
          eve.nvim.load_nvim_session(nvim_session_filepath)
          state.load({
            editor = storage.editor,
            session = storage.session,
            workspace = storage.workspace,
          })
          fml.fn.refresh_state()
        end
      end
    end,
  })
  .register({
    uuid = uuids.session_save,
    desc = "session: save",
    action = function()
      if path.is_git_repo() then
        local storage = state.get_storage() ---@type eve.t.state.storage
        state.save({
          session = storage.session,
          workspace = storage.workspace,
        })
        eve.nvim.save_nvim_session(storage.nvim_session)

        reporter.info({
          from = __module_name__,
          message = "Session saved successfully!",
        })
      end
    end,
  })
