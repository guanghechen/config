local command = eve.command ---@type eve.builtin.command
local K = eve.command.definitions ---@type eve.builtin.command.definitions

--[ai] avante --------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.ai.avante_ask.uuid,
    action = function()
      require("ghc.action.avante").ask()
    end,
  })
  .implement({
    uuid = K.ai.avante_edit.uuid,
    action = function()
      require("ghc.action.avante").edit()
    end,
  })
  .implement({
    uuid = K.ai.avante_refresh.uuid,
    action = function()
      require("ghc.action.avante").refresh()
    end,
  })

--[code] -------------------------------------------------------------------------------------------
command.implement({
  uuid = K.code.swap_conditional_branches.uuid,
  action = function()
    require("ghc.action.nvim-treesitter").swap_conditional_branches()
  end,
})

--[explorer] -------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.explorer.fs_cwd.uuid,
    tabtype = eve.tab.Types.DIFFVIEW,
    action = function()
      require("ghc.action.diffview").fs_cwd()
    end,
  })
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

--[profile] ----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.profile.start.uuid,
    action = function()
      require("ghc.action.profile").start()
    end,
  })
  .implement({
    uuid = K.profile.stop.uuid,
    action = function()
      require("ghc.action.profile").stop()
    end,
  })

--[ux] notifications -------------------------------------------------------------------------------
command.implement({
  uuid = K.ux.dismiss_notifications.uuid,
  action = function()
    eve.notifier.dismiss_all()
  end,
})
