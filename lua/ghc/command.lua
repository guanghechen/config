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
    uuid = K.explorer.focus.uuid,
    action = function()
      dot.widget.explorer.focus()
    end,
  })
  .implement({
    uuid = K.explorer.focus_cwd.uuid,
    action = function()
      dot.widget.explorer.focus_cwd()
    end,
  })
  .implement({
    uuid = K.explorer.focus_workspace.uuid,
    action = function()
      dot.widget.explorer.focus_workspace()
    end,
  })
  .implement({
    uuid = K.explorer.hide.uuid,
    action = function()
      dot.widget.explorer.hide()
    end,
  })
  .implement({
    uuid = K.explorer.refresh.uuid,
    action = function()
      dot.widget.explorer.refresh()
    end,
  })
  .implement({
    uuid = K.explorer.reveal.uuid,
    action = function()
      dot.widget.explorer.reveal()
    end,
  })
  .implement({
    uuid = K.explorer.toggle.uuid,
    tabtype = dot.tab.Types.NORMAL,
    action = function()
      dot.widget.explorer.toggle()
    end,
  })
  .implement({
    uuid = K.explorer.toggle.uuid,
    tabtype = dot.tab.Types.DIFFVIEW,
    action = function()
      require("ghc.action.diffview").toggle()
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
  tabtype = dot.tab.Types.DIFFVIEW,
  action = function()
    require("ghc.action.diffview").refresh()
  end,
})
