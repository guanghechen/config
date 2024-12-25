local constant = require("eve.lib.constant")
local command = require("eve.lib.command")

--[ai] copilot -------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.ai.copilot_chat_prompt.uuid,
    action = function()
      require("guanghechen.action.copilot-chat").prompt()
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_quick.uuid,
    action = function()
      require("guanghechen.action.copilot-chat").quick()
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_reset.uuid,
    action = function()
      require("guanghechen.action.copilot-chat").reset()
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_stop.uuid,
    action = function()
      require("guanghechen.action.copilot-chat").stop()
    end,
  })
  .implement({
    uuid = command.definitions.ai.copilot_chat_toggle.uuid,
    action = function()
      require("guanghechen.action.copilot-chat").toggle()
    end,
  })

--[code] -------------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.code.swap_conditional_branches.uuid,
  action = function()
    require("guanghechen.action.nvim-treesitter").swap_conditional_branches()
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
    tabtype = constant.TT_DIFFVIEW,
    action = function()
      require("guanghechen.action.diffview").fs_cwd()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.fs_cwd.uuid,
    tabtype = constant.TT_NORMAL,
    action = function()
      require("guanghechen.action.neo-tree").fs_cwd()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.fs_workspace.uuid,
    tabtype = constant.TT_NORMAL,
    action = function()
      require("guanghechen.action.neo-tree").fs_workspace()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.fs_reveal.uuid,
    tabtype = constant.TT_NORMAL,
    action = function()
      require("guanghechen.action.neo-tree").fs_reveal()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.git_cwd.uuid,
    action = function()
      require("guanghechen.action.neo-tree").git_cwd()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.git_workspace.uuid,
    action = function()
      require("guanghechen.action.neo-tree").git_workspace()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.last.uuid,
    action = function()
      require("guanghechen.action.neo-tree").last()
    end,
  })
  .implement({
    uuid = command.definitions.explorer.toggle.uuid,
    action = function()
      require("guanghechen.action.neo-tree").toggle()
    end,
  })

--[git] --------------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.git.diffview.uuid,
    action = function()
      require("guanghechen.action.diffview").diffview()
    end,
  })
  .implement({
    uuid = command.definitions.git.history.uuid,
    action = function()
      require("guanghechen.action.diffview").history()
    end,
  })
  .implement({
    uuid = command.definitions.git.history_file.uuid,
    action = function()
      require("guanghechen.action.diffview").history_file()
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

--[win] picker -------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.focus.uuid,
    action = function()
      require("guanghechen.action.nvim-window-picker").focus()
    end,
  })
  .implement({
    uuid = command.definitions.win.project.uuid,
    action = function()
      require("guanghechen.action.nvim-window-picker").project()
    end,
  })
  .implement({
    uuid = command.definitions.win.swap.uuid,
    action = function()
      require("guanghechen.action.nvim-window-picker").swap()
    end,
  })
