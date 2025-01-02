local command = require("eve.command")

--[buf] close---------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.buf.close.uuid,
    action = function(context)
      require("fml.action.buf.close").close(context)
    end,
  })
  .implement({
    uuid = command.definitions.buf.close_to_leftest.uuid,
    action = function(context)
      require("fml.action.buf.close").close_to_leftest(context)
    end,
  })
  .implement({
    uuid = command.definitions.buf.close_to_rightest.uuid,
    action = function(context)
      require("fml.action.buf.close").close_to_rightest(context)
    end,
  })
  .implement({
    uuid = command.definitions.buf.close_others.uuid,
    action = function(context)
      require("fml.action.buf.close").close_others(context)
    end,
  })

--[buf] focus---------------------------------------------------------------------------------------
for i = 1, 10, 1 do
  command.implement({
    uuid = command.definitions.buf["focus_" .. tostring(i)].uuid,
    action = function(context)
      require("fml.action.buf.focus").focus(context, i)
    end,
  })
end

command
  .implement({
    uuid = command.definitions.buf.open.uuid,
    action = function(context, args)
      local bufnr = tonumber(args) ---@type integer|nil
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        require("fml.action.buf.focus").open(context, bufnr)
      end
    end,
  })
  .implement({
    uuid = command.definitions.buf.focus.uuid,
    action = function(context, args)
      local bufid = tonumber(args) ---@type integer|nil
      if bufid ~= nil then
        require("fml.action.buf.focus").focus(context, bufid)
      end
    end,
  })
  .implement({
    uuid = command.definitions.buf.focus_left.uuid,
    action = function(context, args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.buf.focus").focus_left(context, ok and step or nil)
    end,
  })
  .implement({
    uuid = command.definitions.buf.focus_right.uuid,
    action = function(context, args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.buf.focus").focus_right(context, ok and step or nil)
    end,
  })

--[buf] new-----------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.buf.new.uuid,
  action = function(context)
    require("fml.action.buf.new").new(context)
  end,
})

--[buf] pin-----------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.buf.pin.uuid,
  action = function(context)
    require("fml.action.buf.pin").toggle_pin(context)
  end,
})

--[buf] save----------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.buf.save.uuid,
  action = function(context)
    require("fml.action.buf.save").save(context)
  end,
})

--[buf] swap----------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.buf.swap_left.uuid,
    action = function(context)
      require("fml.action.buf.swap").swap_left(context)
    end,
  })
  .implement({
    uuid = command.definitions.buf.swap_right.uuid,
    action = function(context)
      require("fml.action.buf.swap").swap_right(context)
    end,
  })

--[code] run----------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.code.run.uuid,
  action = function(context)
    require("fml.action.code.run").run(context)
  end,
})

--[copy] filepath-----------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.copy.filepath.uuid,
    action = function(context, arg)
      require("fml.action.copy").copy_filepath(context, arg)
    end,
  })
  .implement({
    uuid = command.definitions.copy.filepath_absolute.uuid,
    action = function(context)
      require("fml.action.copy").copy_filepath_absolute(context)
    end,
  })
  .implement({
    uuid = command.definitions.copy.filepath_relative.uuid,
    action = function(context)
      require("fml.action.copy").copy_filepath_relative(context)
    end,
  })

--[copy] text---------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.copy.char_under_cursor.uuid,
  action = function(context)
    require("fml.action.copy").copy_char_under_cursor(context)
  end,
})

--[debug] ------------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.debug.inspect.uuid,
    action = function(context)
      require("fml.action.debug").inspect(context)
    end,
  })
  .implement({
    uuid = command.definitions.debug.inspect_pos.uuid,
    action = function(context)
      require("fml.action.debug").inspect_pos(context)
    end,
  })
  .implement({
    uuid = command.definitions.debug.inspect_state.uuid,
    action = function(context)
      require("fml.action.debug").inspect_state(context)
    end,
  })
  .implement({
    uuid = command.definitions.debug.inspect_tree.uuid,
    action = function(context)
      require("fml.action.debug").inspect_tree(context)
    end,
  })

--[diagnostic] -------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.diagnostic.goto_next.uuid,
    action = function(context)
      require("fml.action.diagnostic").goto_next(context)
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_next_error.uuid,
    action = function(context)
      require("fml.action.diagnostic").goto_next_error(context)
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_next_warn.uuid,
    action = function(context)
      require("fml.action.diagnostic").goto_next_warn(context)
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_next_hint.uuid,
    action = function(context)
      require("fml.action.diagnostic").goto_next_hint(context)
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_next_quickfix.uuid,
    action = function(context)
      require("fml.action.diagnostic").goto_next_quickfix(context)
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_prev.uuid,
    action = function(context)
      require("fml.action.diagnostic").goto_prev(context)
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_prev_error.uuid,
    action = function(context)
      require("fml.action.diagnostic").goto_prev_error(context)
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_prev_warn.uuid,
    action = function(context)
      require("fml.action.diagnostic").goto_prev_warn(context)
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_prev_hint.uuid,
    action = function(context)
      require("fml.action.diagnostic").goto_prev_hint(context)
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.goto_prev_quickfix.uuid,
    action = function(context)
      require("fml.action.diagnostic").goto_prev_quickfix(context)
    end,
  })
  .implement({
    uuid = command.definitions.diagnostic.line.uuid,
    action = function(context)
      require("fml.action.diagnostic").line(context)
    end,
  })

--[find] buffers------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.find.buffers.uuid,
    action = function(context)
      require("fml.action.find.buffers").find_buffers(context)
    end,
  })
  .implement({
    uuid = command.definitions.find.explorer.uuid,
    action = function(context)
      require("fml.action.find.explorer").find_explorer(context)
    end,
  })
  .implement({
    uuid = command.definitions.find.files.uuid,
    action = function(context)
      require("fml.action.find.files").find_files(context)
    end,
  })
  .implement({
    uuid = command.definitions.find.files_cwd.uuid,
    action = function(context)
      require("fml.action.find.files").find_files_cwd(context)
    end,
  })
  .implement({
    uuid = command.definitions.find.files_directory.uuid,
    action = function(context)
      require("fml.action.find.files").find_files_directory(context)
    end,
  })
  .implement({
    uuid = command.definitions.find.files_workspace.uuid,
    action = function(context)
      require("fml.action.find.files").find_files_workspace(context)
    end,
  })
  .implement({
    uuid = command.definitions.find.git_not_committed.uuid,
    action = function(context)
      require("fml.action.find.git").find_git_not_committed(context)
    end,
  })
  .implement({
    uuid = command.definitions.find.highlights.uuid,
    action = function(context)
      require("fml.action.find.highlights").find_highlights(context)
    end,
  })
  .implement({
    uuid = command.definitions.find.pinned_files.uuid,
    action = function(context)
      require("fml.action.find.pinned_files").find_pinned_files(context)
    end,
  })
  .implement({
    uuid = command.definitions.find.vim_options.uuid,
    action = function(context)
      require("fml.action.find.vim_options").find_vim_options(context)
    end,
  })

--[git] browse--------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.git.browse.uuid,
  action = function(context)
    require("fml.action.git.browse").browse(context)
  end,
})

--[lsp] reference-----------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.lsp.goto_definitions.uuid,
    action = function(context)
      require("fml.action.lsp.reference").goto_definitions(context)
    end,
  })
  .implement({
    uuid = command.definitions.lsp.goto_implementations.uuid,
    action = function(context)
      require("fml.action.lsp.reference").goto_implementations(context)
    end,
  })
  .implement({
    uuid = command.definitions.lsp.goto_references.uuid,
    action = function(context)
      require("fml.action.lsp.reference").goto_references(context)
    end,
  })
  .implement({
    uuid = command.definitions.lsp.goto_type_definitions.uuid,
    action = function(context)
      require("fml.action.lsp.reference").goto_type_definitions(context)
    end,
  })

--[refresh] ----------------------------------------------------------------------------------------
command.implement({
  uuid = command.definitions.refresh.all.uuid,
  action = function(context)
    require("fml.action.refresh").refresh_all(context)
  end,
})

--[replace] files-----------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.replace.files.uuid,
    action = function(context)
      require("fml.action.search.files").replace_files(context)
    end,
  })
  .implement({
    uuid = command.definitions.replace.files_in_buffer.uuid,
    action = function(context)
      require("fml.action.search.files").replace_files_in_buffer(context)
    end,
  })
  .implement({
    uuid = command.definitions.replace.files_in_cwd.uuid,
    action = function(context)
      require("fml.action.search.files").replace_files_in_cwd(context)
    end,
  })
  .implement({
    uuid = command.definitions.replace.files_in_directory.uuid,
    action = function(context)
      require("fml.action.search.files").replace_files_in_directory(context)
    end,
  })
  .implement({
    uuid = command.definitions.replace.files_in_workspace.uuid,
    action = function(context)
      require("fml.action.search.files").replace_files_in_workspace(context)
    end,
  })

--[search] files------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.search.files.uuid,
    action = function(context)
      require("fml.action.search.files").search_files(context)
    end,
  })
  .implement({
    uuid = command.definitions.search.files_in_buffer.uuid,
    action = function(context)
      require("fml.action.search.files").search_files_in_buffer(context)
    end,
  })
  .implement({
    uuid = command.definitions.search.files_in_cwd.uuid,
    action = function(context)
      require("fml.action.search.files").search_files_in_cwd(context)
    end,
  })
  .implement({
    uuid = command.definitions.search.files_in_directory.uuid,
    action = function(context)
      require("fml.action.search.files").search_files_in_directory(context)
    end,
  })
  .implement({
    uuid = command.definitions.search.files_in_workspace.uuid,
    action = function(context)
      require("fml.action.search.files").search_files_in_workspace(context)
    end,
  })

--[session] ----------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.session.restore.uuid,
    action = function(context)
      require("fml.action.session").restore(context)
    end,
  })
  .implement({
    uuid = command.definitions.session.restore_autosaved.uuid,
    action = function(context)
      require("fml.action.session").restore_autosaved(context)
    end,
  })
  .implement({
    uuid = command.definitions.session.save.uuid,
    action = function(context)
      require("fml.action.session").save(context)
    end,
  })

--[tab] close---------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.tab.close.uuid,
    action = function(context)
      require("fml.action.tab.close").close(context)
    end,
  })
  .implement({
    uuid = command.definitions.tab.close_to_leftest.uuid,
    action = function(context)
      require("fml.action.tab.close").close_to_leftest(context)
    end,
  })
  .implement({
    uuid = command.definitions.tab.close_to_rightest.uuid,
    action = function(context)
      require("fml.action.tab.close").close_to_rightest(context)
    end,
  })
  .implement({
    uuid = command.definitions.tab.close_others.uuid,
    action = function(context)
      require("fml.action.tab.close").close_others(context)
    end,
  })

--[tab] focus---------------------------------------------------------------------------------------
for i = 1, 10, 1 do
  command.implement({
    uuid = command.definitions.tab["focus_" .. tostring(i)].uuid,
    action = function(context)
      require("fml.action.tab.focus").focus(context, i)
    end,
  })
end

command
  .implement({
    uuid = command.definitions.tab.focus.uuid,
    action = function(context, args)
      local tabid = tonumber(args) ---@type integer|nil
      if tabid ~= nil then
        require("fml.action.tab.focus").focus(context, tabid)
      end
    end,
  })
  .implement({
    uuid = command.definitions.tab.focus_left.uuid,
    action = function(context, args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.tab.focus").focus_left(context, ok and step or nil)
    end,
  })
  .implement({
    uuid = command.definitions.tab.focus_right.uuid,
    action = function(context, args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.tab.focus").focus_right(context, ok and step or nil)
    end,
  })

--[tab] new-----------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.tab.new.uuid,
    action = function(context)
      require("fml.action.tab.new").new(context)
    end,
  })
  .implement({
    uuid = command.definitions.tab.new_with_buf.uuid,
    action = function(context)
      require("fml.action.tab.new").new_with_buf(context)
    end,
  })

--[term] term---------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.term.toggle_cwd.uuid,
    action = function(context)
      require("fml.action.term.toggle").toggle_cwd(context)
    end,
  })
  .implement({
    uuid = command.definitions.term.toggle_directory.uuid,
    action = function(context)
      require("fml.action.term.toggle").toggle_directory(context)
    end,
  })
  .implement({
    uuid = command.definitions.term.toggle_workspace.uuid,
    action = function(context)
      require("fml.action.term.toggle").toggle_workspace(context)
    end,
  })
  .implement({
    uuid = command.definitions.term.lazygit_cwd.uuid,
    action = function(context)
      require("fml.action.term.lazygit").lazygit_cwd(context)
    end,
  })
  .implement({
    uuid = command.definitions.term.lazygit_workspace.uuid,
    action = function(context)
      require("fml.action.term.lazygit").lazygit_workspace(context)
    end,
  })
  .implement({
    uuid = command.definitions.term.lazygit_file_history.uuid,
    action = function(context)
      require("fml.action.term.lazygit").lazygit_file_history(context)
    end,
  })

--[toggle] -----------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.toggle.list.uuid,
    action = function(context, arg)
      require("fml.action.toggle").list(context, arg)
    end,
  })
  .implement({
    uuid = command.definitions.toggle.flight.uuid,
    action = function(context, arg)
      require("fml.action.toggle").toggle_flight(context, arg)
    end,
  })
  .implement({
    uuid = command.definitions.toggle.relativenumber.uuid,
    action = function(context)
      require("fml.action.toggle").toggle_relativenumber(context)
    end,
  })
  .implement({
    uuid = command.definitions.toggle.theme.uuid,
    action = function(context, arg)
      require("fml.action.toggle").toggle_theme(context, arg)
    end,
  })
  .implement({
    uuid = command.definitions.toggle.theme_variant.uuid,
    action = function(context)
      require("fml.action.toggle").toggle_theme_variant(context)
    end,
  })
  .implement({
    uuid = command.definitions.toggle.transparency.uuid,
    action = function(context)
      require("fml.action.toggle").toggle_transparency(context)
    end,
  })

--[ux] widgets -------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.ux.reload_theme.uuid,
    action = function(context, arg)
      require("fml.action.ux").reload_theme(context, arg)
    end,
  })
  .implement({
    uuid = command.definitions.ux.resume_last_widget.uuid,
    action = function(context)
      require("fml.action.ux").resume_last_widget(context)
    end,
  })

--[win] close---------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.close.uuid,
    action = function(context)
      require("fml.action.win.close").close(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.close_others.uuid,
    action = function(context)
      require("fml.action.win.close").close_others(context)
    end,
  })

--[win] focus---------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.focus_top.uuid,
    action = function(context)
      require("fml.action.win.focus").focus_top(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.focus_right.uuid,
    action = function(context)
      require("fml.action.win.focus").focus_right(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.focus_bottom.uuid,
    action = function(context)
      require("fml.action.win.focus").focus_bottom(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.focus_left.uuid,
    action = function(context)
      require("fml.action.win.focus").focus_left(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.focus_prev.uuid,
    action = function(context)
      require("fml.action.win.focus").focus_prev(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.focus_next.uuid,
    action = function(context)
      require("fml.action.win.focus").focus_next(context)
    end,
  })

--[win] history-------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.history.uuid,
    action = function(context)
      require("fml.action.win.history").history(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.history_backward.uuid,
    action = function(context)
      require("fml.action.win.history").history_backward(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.history_forward.uuid,
    action = function(context)
      require("fml.action.win.history").history_forward(context)
    end,
  })

--[win] picker--------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.focus.uuid,
    action = function(context)
      require("fml.action.win.picker").focus(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.project.uuid,
    action = function(context)
      require("fml.action.win.picker").project(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.swap.uuid,
    action = function(context)
      require("fml.action.win.picker").swap(context)
    end,
  })

--[win] resize--------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.resize_horizontal_minus.uuid,
    action = function(context)
      require("fml.action.win.resize").resize_horizontal_minus(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.resize_horizontal_plus.uuid,
    action = function(context)
      require("fml.action.win.resize").resize_horizontal_plus(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.resize_vertical_minus.uuid,
    action = function(context)
      require("fml.action.win.resize").resize_vertical_minus(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.resize_vertical_plus.uuid,
    action = function(context)
      require("fml.action.win.resize").resize_vertical_plus(context)
    end,
  })

--[win] scroll--------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.scroll_down.uuid,
    action = function(context)
      require("fml.action.win.scroll").scroll_down(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.scroll_up.uuid,
    action = function(context)
      require("fml.action.win.scroll").scroll_up(context)
    end,
  })

--[win] split---------------------------------------------------------------------------------------
command
  .implement({
    uuid = command.definitions.win.split_horizontal.uuid,
    action = function(context)
      require("fml.action.win.split").split_horizontal(context)
    end,
  })
  .implement({
    uuid = command.definitions.win.split_vertical.uuid,
    action = function(context)
      require("fml.action.win.split").split_vertical(context)
    end,
  })
