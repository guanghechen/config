local command = eve.command ---@type eve.builtin.command
local K = eve.command.definitions ---@type eve.builtin.command.definitions

--[ai] sidekick -------------------------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.ai.attach_agent.uuid,
    action = function()
      require("ghc.action.sidekick").attach_agent()
    end,
  })
  .implement({
    uuid = K.ai.detach_agent.uuid,
    action = function()
      require("ghc.action.sidekick").detach_agent()
    end,
  })
  .implement({
    uuid = K.ai.submit_buffer.uuid,
    action = function()
      require("ghc.action.sidekick").submit_buffer()
    end,
  })
  .implement({
    uuid = K.ai.submit_selection.uuid,
    action = function()
      require("ghc.action.sidekick").submit_selection()
    end,
  })
  .implement({
    uuid = K.ai.send_buffer.uuid,
    action = function()
      require("ghc.action.sidekick").send_buffer()
    end,
  })
  .implement({
    uuid = K.ai.send_selection.uuid,
    action = function()
      require("ghc.action.sidekick").send_selection()
    end,
  })
  .implement({
    uuid = K.ai.send_this.uuid,
    action = function()
      require("ghc.action.sidekick").send_this()
    end,
  })
  .implement({
    uuid = K.ai.send_file.uuid,
    action = function()
      require("ghc.action.sidekick").send_file()
    end,
  })
  .implement({
    uuid = K.ai.select_prompt.uuid,
    action = function()
      require("ghc.action.sidekick").select_prompt()
    end,
  })

--[code] -------------------------------------------------------------------------------------------
command.implement({
  uuid = K.code.swap_conditional_branches.uuid,
  action = function()
    require("ghc.action.nvim-treesitter").swap_conditional_branches()
  end,
})

command.implement({
  uuid = K.code.swap_next_parameter.uuid,
  action = function()
    require("ghc.action.nvim-treesitter").swap_next_parameter()
  end,
})

command.implement({
  uuid = K.code.swap_prev_parameter.uuid,
  action = function()
    require("ghc.action.nvim-treesitter").swap_prev_parameter()
  end,
})

--[explorer] -------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.explorer.toggle.uuid,
    tabtype = eve.tab.Types.DIFFVIEW,
    action = function()
      require("ghc.action.diffview").toggle()
    end,
  })
  .implement({
    uuid = K.explorer.fs_cwd.uuid,
    tabtype = eve.tab.Types.NORMAL,
    action = function()
      require("ghc.action.neo-tree").fs_cwd()
    end,
  })
  .implement({
    uuid = K.explorer.fs_workspace.uuid,
    tabtype = eve.tab.Types.NORMAL,
    action = function()
      require("ghc.action.neo-tree").fs_workspace()
    end,
  })
  .implement({
    uuid = K.explorer.fs_reveal.uuid,
    tabtype = eve.tab.Types.NORMAL,
    action = function()
      require("ghc.action.neo-tree").fs_reveal()
    end,
  })
  .implement({
    uuid = K.explorer.git_cwd.uuid,
    action = function()
      require("ghc.action.neo-tree").git_cwd()
    end,
  })
  .implement({
    uuid = K.explorer.git_workspace.uuid,
    action = function()
      require("ghc.action.neo-tree").git_workspace()
    end,
  })
  .implement({
    uuid = K.explorer.last.uuid,
    action = function()
      require("ghc.action.neo-tree").last()
    end,
  })
  .implement({
    uuid = K.explorer.toggle.uuid,
    action = function()
      require("ghc.action.neo-tree").toggle()
    end,
  })

--[git] --------------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.git.diffview.uuid,
    action = function()
      require("ghc.action.diffview").diffview()
    end,
  })
  .implement({
    uuid = K.git.history.uuid,
    action = function()
      require("ghc.action.diffview").history()
    end,
  })
  .implement({
    uuid = K.git.history_file.uuid,
    action = function()
      require("ghc.action.diffview").history_file()
    end,
  })

--[refresh] ----------------------------------------------------------------------------------------
command.implement({
  uuid = K.refresh.all.uuid,
  tabtype = eve.tab.Types.DIFFVIEW,
  action = function()
    require("ghc.action.diffview").refresh()
  end,
})
