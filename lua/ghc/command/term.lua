local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.term_cwd,
    desc = "term: toggle or create (cwd)",
    action = function()
      fml.api.term.toggle_or_create({
        name = "workspace",
        cwd = eve.path.cwd(),
        permanent = true,
        send_selection_to_run = true,
      })
    end,
  })
  .register({
    uuid = uuids.term_directory,
    desc = "term: toggle or create (directory)",
    action = function()
      fml.api.term.toggle_or_create({
        name = "workspace",
        cwd = eve.path.current_directory(),
        permanent = true,
        send_selection_to_run = true,
      })
    end,
  })
  .register({
    uuid = uuids.term_workspace,
    desc = "term: toggle or create (workspace)",
    action = function()
      fml.api.term.toggle_or_create({
        name = "workspace",
        cwd = eve.path.workspace()(),
        permanent = true,
        send_selection_to_run = true,
      })
    end,
  })
