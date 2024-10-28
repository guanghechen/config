local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

eve.commander
  .register({
    uuid = uuids.session_restore,
    desc = "session: restore",
    action = function()
      if eve.path.is_git_repo() then
        local nvim_session_filepath = nil ---@type string|nil
        if eve.context.storage.nvim_session and vim.fn.filereadable(eve.context.storage.nvim_session) ~= 0 then
          nvim_session_filepath = eve.context.storage.nvim_session
        elseif
          eve.context.storage.nvim_session_autosaved
          and vim.fn.filereadable(eve.context.storage.nvim_session_autosaved) ~= 0
        then
          nvim_session_filepath = eve.context.storage.nvim_session_autosaved
        end

        if nvim_session_filepath then
          eve.nvim.load_nvim_session(nvim_session_filepath)
        end

        eve.context.load({
          client = eve.context.storage.client,
          session = eve.context.storage.session,
          workspace = eve.context.storage.workspace,
        })
      end
    end,
  })
  .register({
    uuid = uuids.session_save,
    desc = "session: save",
    action = function()
      if eve.path.is_git_repo() then
        eve.context.save({
          session = eve.context.storage.session,
          workspace = eve.context.storage.workspace,
        })
        eve.nvim.save_nvim_session(eve.context.storage.nvim_session)

        eve.reporter.info({
          from = "guanghechen.command.session",
          message = "Session saved successfully!",
        })
      end
    end,
  })
