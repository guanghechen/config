local setting = require("eve.constant.setting")

local command = require("eve.command")

--[ai] copilot -------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.ai.avante_ask.uuid,
    action = function(context)
      require("ghc.action.avante").ask(context)
    end,
  })
  .implement({
    uuid = command.definitions.ai.avante_edit.uuid,
    action = function(context)
      require("ghc.action.avante").edit(context)
    end,
  })
  .implement({
    uuid = command.definitions.ai.avante_refresh.uuid,
    action = function(context)
      require("ghc.action.avante").refresh(context)
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_prompt.uuid,
    action = function(context)
      require("ghc.action.copilot-chat").prompt(context)
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_quick.uuid,
    action = function(context)
      require("ghc.action.copilot-chat").quick(context)
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_reset.uuid,
    action = function(context)
      require("ghc.action.copilot-chat").reset(context)
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_stop.uuid,
    action = function(context)
      require("ghc.action.copilot-chat").stop(context)
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_toggle.uuid,
    action = function(context)
      require("ghc.action.copilot-chat").toggle(context)
    end,
  })

--[code] -------------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.code.swap_conditional_branches.uuid,
  action = function(context)
    require("ghc.action.nvim-treesitter").swap_conditional_branches(context)
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
    tabtype = setting.tabtypes.DIFFVIEW,
    action = function(context)
      require("ghc.action.diffview").fs_cwd(context)
    end,
  })
  .implement({
    uuid = command.definitions.explorer.fs_cwd.uuid,
    tabtype = setting.tabtypes.NORMAL,
    action = function(context)
      require("ghc.action.neo-tree").fs_cwd(context)
    end,
  })
  .implement({
    uuid = command.definitions.explorer.fs_workspace.uuid,
    tabtype = setting.tabtypes.NORMAL,
    action = function(context)
      require("ghc.action.neo-tree").fs_workspace(context)
    end,
  })
  .implement({
    uuid = command.definitions.explorer.fs_reveal.uuid,
    tabtype = setting.tabtypes.NORMAL,
    action = function(context)
      require("ghc.action.neo-tree").fs_reveal(context)
    end,
  })
  .implement({
    uuid = command.definitions.explorer.git_cwd.uuid,
    action = function(context)
      require("ghc.action.neo-tree").git_cwd(context)
    end,
  })
  .implement({
    uuid = command.definitions.explorer.git_workspace.uuid,
    action = function(context)
      require("ghc.action.neo-tree").git_workspace(context)
    end,
  })
  .implement({
    uuid = command.definitions.explorer.last.uuid,
    action = function(context)
      require("ghc.action.neo-tree").last(context)
    end,
  })
  .implement({
    uuid = command.definitions.explorer.toggle.uuid,
    action = function(context)
      require("ghc.action.neo-tree").toggle(context)
    end,
  })

--[git] --------------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.git.diffview.uuid,
    action = function(context)
      require("ghc.action.diffview").diffview(context)
    end,
  })
  .implement({
    uuid = command.definitions.git.history.uuid,
    action = function(context)
      require("ghc.action.diffview").history(context)
    end,
  })
  .implement({
    uuid = command.definitions.git.history_file.uuid,
    action = function(context)
      require("ghc.action.diffview").history_file(context)
    end,
  })

--[toggle]------------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.toggle.markdown.uuid,
  action = function()
    vim.cmd("RenderMarkdown toggle")
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
