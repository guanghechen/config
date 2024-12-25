local path = require("eve.lib.path")
local command = require("eve.lib.command")

--[buf] close---------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.buf.close.uuid,
    action = function()
      require("fml.action.buf.close").close()
    end,
  })
  .implement({
    uuid = command.definitions.buf.close_to_leftest.uuid,
    action = function()
      require("fml.action.buf.close").close_to_leftest()
    end,
  })
  .implement({
    uuid = command.definitions.buf.close_to_rightest.uuid,
    action = function()
      require("fml.action.buf.close").close_to_rightest()
    end,
  })
  .implement({
    uuid = command.definitions.buf.close_others.uuid,
    action = function()
      require("fml.action.buf.close").close_others()
    end,
  })

--[buf] focus---------------------------------------------------------------------------------------
for i = 1, 10, 1 do
  command.implement({
    uuid = command.definitions.buf["focus_" .. tostring(i)].uuid,
    action = function()
      require("fml.action.buf.focus").focus(i)
    end,
  })
end

command
  .implement({
    uuid = command.definitions.buf.open.uuid,
    action = function(args)
      local bufnr = tonumber(args) ---@type integer|nil
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        require("fml.action.buf.focus").open(bufnr)
      end
    end,
  })
  .implement({
    uuid = command.definitions.buf.focus.uuid,
    action = function(args)
      local bufid = tonumber(args) ---@type integer|nil
      if bufid ~= nil then
        require("fml.action.buf.focus").focus(bufid)
      end
    end,
  })
  .implement({
    uuid = command.definitions.buf.focus_left.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.buf.focus").focus_left(ok and step or nil)
    end,
  })
  .implement({
    uuid = command.definitions.buf.focus_right.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.buf.focus").focus_right(ok and step or nil)
    end,
  })

--[buf] new-----------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.buf.new.uuid,
  action = function()
    require("fml.action.buf.new").new()
  end,
})

--[buf] pin-----------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.buf.pin.uuid,
  action = function()
    require("fml.action.buf.pin").toggle_pin()
  end,
})

--[buf] save----------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.buf.save.uuid,
  action = function()
    require("fml.action.buf.save").save()
  end,
})

--[buf] swap----------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.buf.swap_left.uuid,
    action = function()
      require("fml.action.buf.swap").swap_left()
    end,
  })
  .implement({
    uuid = command.definitions.buf.swap_right.uuid,
    action = function()
      require("fml.action.buf.swap").swap_right()
    end,
  })

--[code] run----------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.code.run.uuid,
  action = function()
    local filepath = path.current_filepath() ---@type string
    require("fml.action.code.run").run(filepath)
  end,
})

--[copy] filepath-----------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.copy.filepath.uuid,
    action = function(arg)
      local filepath = path.current_filepath() ---@type string
      require("fml.action.copy").copy_filepath(filepath, arg)
    end,
  })
  .implement({
    uuid = command.definitions.copy.filepath_absolute.uuid,
    action = function()
      local filepath = path.current_filepath() ---@type string
      require("fml.action.copy").copy_filepath_absolute(filepath)
    end,
  })
  .implement({
    uuid = command.definitions.copy.filepath_relative.uuid,
    action = function()
      local filepath = path.current_filepath() ---@type string
      require("fml.action.copy").copy_filepath_relative(filepath)
    end,
  })

--[copy] text---------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.copy.char_under_cursor.uuid,
  action = function()
    require("fml.action.copy").copy_char_under_cursor()
  end,
})

--[debug] ------------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.debug.inspect.uuid,
    action = function()
      require("fml.action.debug").inspect()
    end,
  })
  .implement({
    uuid = command.definitions.debug.inspect_pos.uuid,
    action = function()
      require("fml.action.debug").inspect_pos()
    end,
  })
  .implement({
    uuid = command.definitions.debug.inspect_state.uuid,
    action = function()
      require("fml.action.debug").inspect_state()
    end,
  })
  .implement({
    uuid = command.definitions.debug.inspect_tree.uuid,
    action = function()
      require("fml.action.debug").inspect_tree()
    end,
  })

--[diagnostic] -------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.diagnostic.goto_next.uuid,
    action = function()
      require("fml.action.diagnostic").goto_next()
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_next_error.uuid,
    action = function()
      require("fml.action.diagnostic").goto_next_error()
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_next_warn.uuid,
    action = function()
      require("fml.action.diagnostic").goto_next_warn()
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_next_hint.uuid,
    action = function()
      require("fml.action.diagnostic").goto_next_hint()
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_next_quickfix.uuid,
    action = function()
      require("fml.action.diagnostic").goto_next_quickfix()
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_prev.uuid,
    action = function()
      require("fml.action.diagnostic").goto_prev()
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_prev_error.uuid,
    action = function()
      require("fml.action.diagnostic").goto_prev_error()
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_prev_warn.uuid,
    action = function()
      require("fml.action.diagnostic").goto_prev_warn()
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_prev_hint.uuid,
    action = function()
      require("fml.action.diagnostic").goto_prev_hint()
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_prev_quickfix.uuid,
    action = function()
      require("fml.action.diagnostic").goto_prev_quickfix()
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.line.uuid,
    action = function()
      require("fml.action.diagnostic").line()
    end,
  })

--[find] buffers------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.find.buffers.uuid,
    action = function()
      require("fml.action.find.buffers").find_buffers()
    end,
  })
  .implement({
    uuid = command.definitions.find.explorer.uuid,
    action = function()
      require("fml.action.find.explorer").find_explorer()
    end,
  })
  .implement({
    uuid = command.definitions.find.files.uuid,
    action = function()
      require("fml.action.find.files").find_files()
    end,
  })
  .implement({
    uuid = command.definitions.find.files_cwd.uuid,
    action = function()
      require("fml.action.find.files").find_files_cwd()
    end,
  })
  .implement({
    uuid = command.definitions.find.files_directory.uuid,
    action = function()
      require("fml.action.find.files").find_files_directory()
    end,
  })
  .implement({
    uuid = command.definitions.find.files_workspace.uuid,
    action = function()
      require("fml.action.find.files").find_files_workspace()
    end,
  })
  .implement({
    uuid = command.definitions.find.git_not_committed.uuid,
    action = function()
      require("fml.action.find.git").find_git_not_committed()
    end,
  })
  .implement({
    uuid = command.definitions.find.highlights.uuid,
    action = function()
      require("fml.action.find.highlights").find_highlights()
    end,
  })
  .implement({
    uuid = command.definitions.find.pinned_files.uuid,
    action = function()
      require("fml.action.find.pinned_files").find_pinned_files()
    end,
  })
  .implement({
    uuid = command.definitions.find.vim_options.uuid,
    action = function()
      require("fml.action.find.vim_options").find_vim_options()
    end,
  })

--[git] browse--------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.git.browse.uuid,
  action = function()
    require("fml.action.git.browse").browse()
  end,
})

--[lsp] reference-----------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.lsp.goto_definitions.uuid,
    action = function()
      require("fml.action.lsp.reference").goto_definitions()
    end,
  })
  .implement({
    uuid = command.definitions.lsp.goto_implementations.uuid,
    action = function()
      require("fml.action.lsp.reference").goto_implementations()
    end,
  })
  .implement({
    uuid = command.definitions.lsp.goto_references.uuid,
    action = function()
      require("fml.action.lsp.reference").goto_references()
    end,
  })
  .implement({
    uuid = command.definitions.lsp.goto_type_definitions.uuid,
    action = function()
      require("fml.action.lsp.reference").goto_type_definitions()
    end,
  })

--[refresh] ----------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.refresh.all.uuid,
  action = function()
    require("fml.action.refresh").refresh_all()
  end,
})

--[replace] files-----------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.replace.files.uuid,
    action = function()
      require("fml.action.search.files").replace_files()
    end,
  })
  .implement({
    uuid = command.definitions.replace.files_in_buffer.uuid,
    action = function()
      require("fml.action.search.files").replace_files_in_buffer()
    end,
  })
  .implement({
    uuid = command.definitions.replace.files_in_cwd.uuid,
    action = function()
      require("fml.action.search.files").replace_files_in_cwd()
    end,
  })
  .implement({
    uuid = command.definitions.replace.files_in_directory.uuid,
    action = function()
      require("fml.action.search.files").replace_files_in_directory()
    end,
  })
  .implement({
    uuid = command.definitions.replace.files_in_workspace.uuid,
    action = function()
      require("fml.action.search.files").replace_files_in_workspace()
    end,
  })

--[search] files------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.search.files.uuid,
    action = function()
      require("fml.action.search.files").search_files()
    end,
  })
  .implement({
    uuid = command.definitions.search.files_in_buffer.uuid,
    action = function()
      require("fml.action.search.files").search_files_in_buffer()
    end,
  })
  .implement({
    uuid = command.definitions.search.files_in_cwd.uuid,
    action = function()
      require("fml.action.search.files").search_files_in_cwd()
    end,
  })
  .implement({
    uuid = command.definitions.search.files_in_directory.uuid,
    action = function()
      require("fml.action.search.files").search_files_in_directory()
    end,
  })
  .implement({
    uuid = command.definitions.search.files_in_workspace.uuid,
    action = function()
      require("fml.action.search.files").search_files_in_workspace()
    end,
  })

--[session] ----------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.session.restore.uuid,
    action = function()
      require("fml.action.session").restore()
    end,
  })
  .implement({
    uuid = command.definitions.session.restore_autosaved.uuid,
    action = function()
      require("fml.action.session").restore_autosaved()
    end,
  })
  .implement({
    uuid = command.definitions.session.save.uuid,
    action = function()
      require("fml.action.session").save()
    end,
  })

--[tab] close---------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.tab.close.uuid,
    action = function()
      require("fml.action.tab.close").close()
    end,
  })
  .implement({
    uuid = command.definitions.tab.close_to_leftest.uuid,
    action = function()
      require("fml.action.tab.close").close_to_leftest()
    end,
  })
  .implement({
    uuid = command.definitions.tab.close_to_rightest.uuid,
    action = function()
      require("fml.action.tab.close").close_to_rightest()
    end,
  })
  .implement({
    uuid = command.definitions.tab.close_others.uuid,
    action = function()
      require("fml.action.tab.close").close_others()
    end,
  })

--[tab] focus---------------------------------------------------------------------------------------
for i = 1, 10, 1 do
  command.implement({
    uuid = command.definitions.tab["focus_" .. tostring(i)].uuid,
    action = function()
      require("fml.action.tab.focus").focus(i)
    end,
  })
end

command
  .implement({
    uuid = command.definitions.tab.focus.uuid,
    action = function(args)
      local tabid = tonumber(args) ---@type integer|nil
      if tabid ~= nil then
        require("fml.action.tab.focus").focus(tabid)
      end
    end,
  })
  .implement({
    uuid = command.definitions.tab.focus_left.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.tab.focus").focus_left(ok and step or nil)
    end,
  })
  .implement({
    uuid = command.definitions.tab.focus_right.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.tab.focus").focus_right(ok and step or nil)
    end,
  })

--[tab] new-----------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.tab.new.uuid,
    action = function()
      require("fml.action.tab.new").new()
    end,
  })
  .implement({
    uuid = command.definitions.tab.new_with_buf.uuid,
    action = function()
      local winnr = vim.api.nvim_get_current_win()
      local bufnr = vim.api.nvim_win_get_buf(winnr)
      local cursor = vim.api.nvim_win_get_cursor(winnr)

      require("fml.action.tab.new").new(bufnr)
      vim.api.nvim_win_set_cursor(winnr, cursor)
    end,
  })

--[term] term---------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.term.toggle_cwd.uuid,
    action = function()
      require("fml.action.term.toggle").toggle_cwd()
    end,
  })
  .implement({
    uuid = command.definitions.term.toggle_directory.uuid,
    action = function()
      require("fml.action.term.toggle").toggle_directory()
    end,
  })
  .implement({
    uuid = command.definitions.term.toggle_workspace.uuid,
    action = function()
      require("fml.action.term.toggle").toggle_workspace()
    end,
  })
  .implement({
    uuid = command.definitions.term.lazygit_cwd.uuid,
    action = function()
      require("fml.action.term.lazygit").lazygit_cwd()
    end,
  })
  .implement({
    uuid = command.definitions.term.lazygit_workspace.uuid,
    action = function()
      require("fml.action.term.lazygit").lazygit_workspace()
    end,
  })
  .implement({
    uuid = command.definitions.term.lazygit_file_history.uuid,
    action = function()
      require("fml.action.term.lazygit").lazygit_file_history()
    end,
  })

--[toggle] -----------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.toggle.list.uuid,
    action = function(arg)
      require("fml.action.toggle").list(arg)
    end,
  })
  .implement({
    uuid = command.definitions.toggle.flight.uuid,
    action = function(arg)
      require("fml.action.toggle").toggle_flight(arg)
    end,
  })
  .implement({
    uuid = command.definitions.toggle.relativenumber.uuid,
    action = function()
      require("fml.action.toggle").toggle_relativenumber()
    end,
  })
  .implement({
    uuid = command.definitions.toggle.theme.uuid,
    action = function(arg)
      require("fml.action.toggle").toggle_theme(arg)
    end,
  })
  .implement({
    uuid = command.definitions.toggle.theme_variant.uuid,
    action = function()
      require("fml.action.toggle").toggle_theme_variant()
    end,
  })
  .implement({
    uuid = command.definitions.toggle.transparency.uuid,
    action = function()
      require("fml.action.toggle").toggle_transparency()
    end,
  })
  .implement({
    uuid = command.definitions.toggle.wrap.uuid,
    action = function()
      require("fml.action.toggle").toggle_wrap()
    end,
  })

--[ux] widgets -------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.ux.reload_theme.uuid,
    action = function(arg)
      require("fml.action.ux").reload_theme(arg)
    end,
  })
  .implement({
    uuid = command.definitions.ux.resume_last_widget.uuid,
    action = function()
      require("fml.action.ux").resume_last_widget()
    end,
  })

--[win] close---------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.close.uuid,
    action = function()
      require("fml.action.win.close").close()
    end,
  })
  .implement({
    uuid = command.definitions.win.close_others.uuid,
    action = function()
      require("fml.action.win.close").close_others()
    end,
  })

--[win] focus---------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.focus_top.uuid,
    action = function()
      require("fml.action.win.focus").focus_top()
    end,
  })
  .implement({
    uuid = command.definitions.win.focus_right.uuid,
    action = function()
      require("fml.action.win.focus").focus_right()
    end,
  })
  .implement({
    uuid = command.definitions.win.focus_bottom.uuid,
    action = function()
      require("fml.action.win.focus").focus_bottom()
    end,
  })
  .implement({
    uuid = command.definitions.win.focus_left.uuid,
    action = function()
      require("fml.action.win.focus").focus_left()
    end,
  })
  .implement({
    uuid = command.definitions.win.focus_prev.uuid,
    action = function()
      require("fml.action.win.focus").focus_prev()
    end,
  })
  .implement({
    uuid = command.definitions.win.focus_next.uuid,
    action = function()
      require("fml.action.win.focus").focus_next()
    end,
  })

--[win] history-------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.history.uuid,
    action = function()
      require("fml.action.win.history").history()
    end,
  })
  .implement({
    uuid = command.definitions.win.history_backward.uuid,
    action = function()
      require("fml.action.win.history").history_backward()
    end,
  })
  .implement({
    uuid = command.definitions.win.history_forward.uuid,
    action = function()
      require("fml.action.win.history").history_forward()
    end,
  })

--[win] resize--------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.resize_horizontal_minus.uuid,
    action = function()
      require("fml.action.win.resize").resize_horizontal_minus()
    end,
  })
  .implement({
    uuid = command.definitions.win.resize_horizontal_plus.uuid,
    action = function()
      require("fml.action.win.resize").resize_horizontal_plus()
    end,
  })
  .implement({
    uuid = command.definitions.win.resize_vertical_minus.uuid,
    action = function()
      require("fml.action.win.resize").resize_vertical_minus()
    end,
  })
  .implement({
    uuid = command.definitions.win.resize_vertical_plus.uuid,
    action = function()
      require("fml.action.win.resize").resize_vertical_plus()
    end,
  })

--[win] scroll--------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.scroll_down.uuid,
    action = function()
      require("fml.action.win.scroll").scroll_down()
    end,
  })
  .implement({
    uuid = command.definitions.win.scroll_up.uuid,
    action = function()
      require("fml.action.win.scroll").scroll_up()
    end,
  })

--[win] split---------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.split_horizontal.uuid,
    action = function()
      require("fml.action.win.split").split_horizontal()
    end,
  })
  .implement({
    uuid = command.definitions.win.split_vertical.uuid,
    action = function()
      require("fml.action.win.split").split_vertical()
    end,
  })
