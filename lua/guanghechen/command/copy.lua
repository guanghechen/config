local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

eve.commander
  .register({
    uuid = uuids.copy_current_filepath,
    desc = "copy: current filepath",
    action = function()
      local filepath = eve.path.current_filepath() ---@type string
      local content = filepath ---@type string
      vim.fn.setreg("+", content)
      eve.reporter.info({
        from = "guanghechen.command.copy",
        message = "Copied current buffer filepath to system clipboard!",
      })
    end,
  })
  .register({
    uuid = uuids.copy_current_filepath_relative,
    desc = "copy: current filepath (relative)",
    action = function()
      local cwd = eve.path.cwd() ---@type string
      local filepath = eve.path.current_filepath() ---@type string
      local content = eve.path.relative(cwd, filepath, true) ---@type string

      vim.fn.setreg("+", content)
      eve.reporter.info({
        from = "guanghechen.command.copy",
        message = "Copied current buffer filepath (relative) to system clipboard!",
      })
    end,
  })
