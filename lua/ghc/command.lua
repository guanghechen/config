local command = require("eve.command")

--[ai] copilot -------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.ai.avante_ask.uuid,
    action = function()
      require("ghc.action.avante").ask()
    end,
  })
  .implement({
    uuid = command.definitions.ai.avante_edit.uuid,
    action = function()
      require("ghc.action.avante").edit()
    end,
  })
  .implement({
    uuid = command.definitions.ai.avante_refresh.uuid,
    action = function()
      require("ghc.action.avante").refresh()
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_prompt.uuid,
    action = function()
      require("ghc.action.copilot-chat").prompt()
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_quick.uuid,
    action = function()
      require("ghc.action.copilot-chat").quick()
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_reset.uuid,
    action = function()
      require("ghc.action.copilot-chat").reset()
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_stop.uuid,
    action = function()
      require("ghc.action.copilot-chat").stop()
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_toggle.uuid,
    action = function()
      require("ghc.action.copilot-chat").toggle()
    end,
  })

--[code] -------------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.code.swap_conditional_branches.uuid,
  action = function()
    require("ghc.action.nvim-treesitter").swap_conditional_branches()
  end,
})

--[diagnostic] -------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.diagnostic.outline.uuid,
  action = function()
    require("aerial").toggle()
  end,
})

--[explorer] -------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.explorer.fs_cwd.uuid,
    tabtype = eve.var.TabTypes.DIFFVIEW,
    action = function()
      require("ghc.action.diffview").fs_cwd()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.fs_cwd.uuid,
    tabtype = eve.var.TabTypes.NORMAL,
    action = function()
      require("ghc.action.neo-tree").fs_cwd()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.fs_workspace.uuid,
    tabtype = eve.var.TabTypes.NORMAL,
    action = function()
      require("ghc.action.neo-tree").fs_workspace()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.fs_reveal.uuid,
    tabtype = eve.var.TabTypes.NORMAL,
    action = function()
      require("ghc.action.neo-tree").fs_reveal()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.git_cwd.uuid,
    action = function()
      require("ghc.action.neo-tree").git_cwd()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.git_workspace.uuid,
    action = function()
      require("ghc.action.neo-tree").git_workspace()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.last.uuid,
    action = function()
      require("ghc.action.neo-tree").last()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.toggle.uuid,
    action = function()
      require("ghc.action.neo-tree").toggle()
    end,
  })

--[git] --------------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.git.diffview.uuid,
    action = function()
      require("ghc.action.diffview").diffview()
    end,
  })
  .implement({
    uuid = command.definitions.git.history.uuid,
    action = function()
      require("ghc.action.diffview").history()
    end,
  })
  .implement({
    uuid = command.definitions.git.history_file.uuid,
    action = function()
      require("ghc.action.diffview").history_file()
    end,
  })

--[ux] notifications -------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.ux.dismiss_notifications.uuid,
  action = function()
    require("notify").dismiss({
      silent = true,
      pending = true,
    })
  end,
})
