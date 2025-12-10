local command = dot.command ---@type dot.command
local K = dot.command.definitions ---@type dot.command.definitions

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
