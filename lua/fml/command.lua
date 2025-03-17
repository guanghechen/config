local command = eve.command ---@type eve.builtin.command
local K = eve.command.definitions ---@type eve.builtin.command.definitions

--[buf] close---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.buf.close.uuid,
    action = function()
      require("fml.action.buf.close").close()
    end,
  })
  .implement({
    uuid = K.buf.close_to_leftest.uuid,
    action = function()
      require("fml.action.buf.close").close_to_leftest()
    end,
  })
  .implement({
    uuid = K.buf.close_to_rightest.uuid,
    action = function()
      require("fml.action.buf.close").close_to_rightest()
    end,
  })
  .implement({
    uuid = K.buf.close_others.uuid,
    action = function()
      require("fml.action.buf.close").close_others()
    end,
  })

--[buf] focus---------------------------------------------------------------------------------------
for i = 1, 49, 1 do
  local bufid = i < 10 and ("0" .. tostring(i)) or tostring(i)
  command.implement({
    uuid = K.buf["focus_" .. bufid].uuid,
    action = function()
      require("fml.action.buf.focus").focus(i)
    end,
  })
end

command
  .implement({
    uuid = K.buf.open.uuid,
    action = function(args)
      local bufnr = tonumber(args) ---@type integer|nil
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        require("fml.action.buf.focus").open(bufnr)
      end
    end,
  })
  .implement({
    uuid = K.buf.focus.uuid,
    action = function(args)
      local bufid = tonumber(args) ---@type integer|nil
      if bufid ~= nil then
        require("fml.action.buf.focus").focus(bufid)
      end
    end,
  })
  .implement({
    uuid = K.buf.focus_left.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.buf.focus").focus_left(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.buf.focus_right.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.buf.focus").focus_right(ok and step or nil)
    end,
  })

--[buf] new-----------------------------------------------------------------------------------------
command.implement({
  uuid = K.buf.new.uuid,
  action = function()
    require("fml.action.buf.new").new()
  end,
})

--[buf] pin-----------------------------------------------------------------------------------------
command.implement({
  uuid = K.buf.pin.uuid,
  action = function()
    require("fml.action.buf.pin").toggle_pin()
  end,
})

--[buf] save----------------------------------------------------------------------------------------
command.implement({
  uuid = K.buf.save.uuid,
  action = function()
    require("fml.action.buf.save").save()
  end,
})

--[buf] swap----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.buf.swap_left.uuid,
    action = function()
      require("fml.action.buf.swap").swap_left()
    end,
  })
  .implement({
    uuid = K.buf.swap_right.uuid,
    action = function()
      require("fml.action.buf.swap").swap_right()
    end,
  })

--[clipboard] paste---------------------------------------------------------------------------------
command.implement({
  uuid = K.clipboard.paste.uuid,
  action = function()
    require("fml.action.clipboard").paste()
  end,
})

--[code] run----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.code.run.uuid,
    action = function()
      require("fml.action.code.run").run(false)
    end,
  })
  .implement({
    uuid = K.code.run_force.uuid,
    action = function()
      require("fml.action.code.run").run(true)
    end,
  })

--[copy] filepath-----------------------------------------------------------------------------------
command
  .implement({
    uuid = K.copy.filepath.uuid,
    action = function(arg)
      require("fml.action.copy").copy_filepath(arg)
    end,
  })
  .implement({
    uuid = K.copy.filepath_absolute.uuid,
    action = function()
      require("fml.action.copy").copy_filepath_absolute()
    end,
  })
  .implement({
    uuid = K.copy.filepath_relative.uuid,
    action = function()
      require("fml.action.copy").copy_filepath_relative()
    end,
  })

--[copy] text---------------------------------------------------------------------------------------
command.implement({
  uuid = K.copy.char_under_cursor.uuid,
  action = function()
    require("fml.action.copy").copy_char_under_cursor()
  end,
})

--[diagnostic] -------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.diagnostic.goto_next.uuid,
    action = function()
      require("fml.action.diagnostic").goto_next()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_next_error.uuid,
    action = function()
      require("fml.action.diagnostic").goto_next_error()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_next_warn.uuid,
    action = function()
      require("fml.action.diagnostic").goto_next_warn()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_next_hint.uuid,
    action = function()
      require("fml.action.diagnostic").goto_next_hint()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_next_quickfix.uuid,
    action = function()
      require("fml.action.diagnostic").goto_next_quickfix()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_prev.uuid,
    action = function()
      require("fml.action.diagnostic").goto_prev()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_prev_error.uuid,
    action = function()
      require("fml.action.diagnostic").goto_prev_error()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_prev_warn.uuid,
    action = function()
      require("fml.action.diagnostic").goto_prev_warn()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_prev_hint.uuid,
    action = function()
      require("fml.action.diagnostic").goto_prev_hint()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_prev_quickfix.uuid,
    action = function()
      require("fml.action.diagnostic").goto_prev_quickfix()
    end,
  })
  .implement({
    uuid = K.diagnostic.line.uuid,
    action = function()
      require("fml.action.diagnostic").line()
    end,
  })

--[find] buffers------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.find.bufs.uuid,
    action = function()
      require("fml.action.find.buffers").find_bufs()
    end,
  })
  .implement({
    uuid = K.find.bufs_file.uuid,
    action = function()
      require("fml.action.find.buffers").find_bufs_file()
    end,
  })
  .implement({
    uuid = K.find.bufs_term.uuid,
    action = function()
      require("fml.action.find.buffers").find_bufs_term()
    end,
  })
  .implement({
    uuid = K.find.explorer.uuid,
    action = function(args)
      require("fml.action.find.explorer").find_explorer(args)
    end,
  })
  .implement({
    uuid = K.find.files.uuid,
    action = function()
      require("fml.action.find.files").find_files()
    end,
  })
  .implement({
    uuid = K.find.files_cwd.uuid,
    action = function()
      require("fml.action.find.files").find_files_cwd()
    end,
  })
  .implement({
    uuid = K.find.files_directory.uuid,
    action = function(args)
      require("fml.action.find.files").find_files_directory(args)
    end,
  })
  .implement({
    uuid = K.find.files_workspace.uuid,
    action = function()
      require("fml.action.find.files").find_files_workspace()
    end,
  })
  .implement({
    uuid = K.find.git_not_committed.uuid,
    action = function()
      require("fml.action.find.git").find_git_not_committed()
    end,
  })
  .implement({
    uuid = K.find.highlights.uuid,
    action = function()
      require("fml.action.find.highlights").find_highlights()
    end,
  })
  .implement({
    uuid = K.find.pinned_files.uuid,
    action = function()
      require("fml.action.find.pinned_files").find_pinned_files()
    end,
  })
  .implement({
    uuid = K.find.vim_options.uuid,
    action = function()
      require("fml.action.find.vim_options").find_vim_options()
    end,
  })

--[git] browse--------------------------------------------------------------------------------------
command.implement({
  uuid = K.git.browse.uuid,
  action = function()
    require("fml.action.git.browse").browse()
  end,
})

--[inspect] ------------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.inspect.inspect_buf.uuid,
    action = function()
      require("fml.action.inspect").inspect_buf()
    end,
  })
  .implement({
    uuid = K.inspect.inspect_pos.uuid,
    action = function()
      require("fml.action.inspect").inspect_pos()
    end,
  })
  .implement({
    uuid = K.inspect.inspect_state.uuid,
    action = function()
      require("fml.action.inspect").inspect_state()
    end,
  })
  .implement({
    uuid = K.inspect.inspect_state_full.uuid,
    action = function()
      require("fml.action.inspect").inspect_state_full()
    end,
  })
  .implement({
    uuid = K.inspect.inspect_tab.uuid,
    action = function()
      require("fml.action.inspect").inspect_tab()
    end,
  })
  .implement({
    uuid = K.inspect.inspect_tree.uuid,
    action = function()
      require("fml.action.inspect").inspect_tree()
    end,
  })
  .implement({
    uuid = K.inspect.inspect_window.uuid,
    action = function()
      require("fml.action.inspect").inspect_window()
    end,
  })

--[lsp] reference-----------------------------------------------------------------------------------
command
  .implement({
    uuid = K.lsp.goto_definitions.uuid,
    action = function()
      require("fml.action.lsp.reference").goto_definitions()
    end,
  })
  .implement({
    uuid = K.lsp.goto_implementations.uuid,
    action = function()
      require("fml.action.lsp.reference").goto_implementations()
    end,
  })
  .implement({
    uuid = K.lsp.goto_references.uuid,
    action = function()
      require("fml.action.lsp.reference").goto_references()
    end,
  })
  .implement({
    uuid = K.lsp.goto_type_definitions.uuid,
    action = function()
      require("fml.action.lsp.reference").goto_type_definitions()
    end,
  })
  .implement({
    uuid = K.lsp.select_python_venv.uuid,
    action = function()
      require("fml.action.lsp.python_venv").activate_venv()
    end,
  })

--[refresh] ----------------------------------------------------------------------------------------
command.implement({
  uuid = K.refresh.all.uuid,
  action = function()
    require("fml.action.refresh").refresh_all()
  end,
})

--[replace] files-----------------------------------------------------------------------------------
command
  .implement({
    uuid = K.replace.files.uuid,
    action = function()
      require("fml.action.search.files").replace_files()
    end,
  })
  .implement({
    uuid = K.replace.files_in_buffer.uuid,
    action = function()
      require("fml.action.search.files").replace_files_in_buffer()
    end,
  })
  .implement({
    uuid = K.replace.files_in_cwd.uuid,
    action = function()
      require("fml.action.search.files").replace_files_in_cwd()
    end,
  })
  .implement({
    uuid = K.replace.files_in_directory.uuid,
    action = function()
      require("fml.action.search.files").replace_files_in_directory()
    end,
  })
  .implement({
    uuid = K.replace.files_in_workspace.uuid,
    action = function()
      require("fml.action.search.files").replace_files_in_workspace()
    end,
  })

--[search] files------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.search.files.uuid,
    action = function()
      require("fml.action.search.files").search_files()
    end,
  })
  .implement({
    uuid = K.search.files_in_buffer.uuid,
    action = function()
      require("fml.action.search.files").search_files_in_buffer()
    end,
  })
  .implement({
    uuid = K.search.files_in_cwd.uuid,
    action = function()
      require("fml.action.search.files").search_files_in_cwd()
    end,
  })
  .implement({
    uuid = K.search.files_in_directory.uuid,
    action = function()
      require("fml.action.search.files").search_files_in_directory()
    end,
  })
  .implement({
    uuid = K.search.files_in_workspace.uuid,
    action = function()
      require("fml.action.search.files").search_files_in_workspace()
    end,
  })

--[session] ----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.session.restore.uuid,
    action = function()
      require("fml.action.session").restore()
    end,
  })
  .implement({
    uuid = K.session.restore_autosaved.uuid,
    action = function()
      require("fml.action.session").restore_autosaved()
    end,
  })
  .implement({
    uuid = K.session.save.uuid,
    action = function()
      require("fml.action.session").save()
    end,
  })

--[tab] close---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.tab.close.uuid,
    action = function()
      require("fml.action.tab.close").close()
    end,
  })
  .implement({
    uuid = K.tab.close_to_leftest.uuid,
    action = function()
      require("fml.action.tab.close").close_to_leftest()
    end,
  })
  .implement({
    uuid = K.tab.close_to_rightest.uuid,
    action = function()
      require("fml.action.tab.close").close_to_rightest()
    end,
  })
  .implement({
    uuid = K.tab.close_others.uuid,
    action = function()
      require("fml.action.tab.close").close_others()
    end,
  })

--[tab] focus---------------------------------------------------------------------------------------
for i = 1, 10, 1 do
  command.implement({
    uuid = K.tab["focus_" .. tostring(i)].uuid,
    action = function()
      require("fml.action.tab.focus").focus(i)
    end,
  })
end

command
  .implement({
    uuid = K.tab.focus.uuid,
    action = function(args)
      local tabid = tonumber(args) ---@type integer|nil
      if tabid ~= nil then
        require("fml.action.tab.focus").focus(tabid)
      end
    end,
  })
  .implement({
    uuid = K.tab.focus_left.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.tab.focus").focus_left(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.tab.focus_right.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.tab.focus").focus_right(ok and step or nil)
    end,
  })

--[tab] new-----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.tab.new.uuid,
    action = function()
      require("fml.action.tab.new").new()
    end,
  })
  .implement({
    uuid = K.tab.new_with_buf.uuid,
    action = function()
      require("fml.action.tab.new").new_with_buf()
    end,
  })

--[term] term---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.term.toggle_cwd.uuid,
    action = function()
      require("fml.action.term.toggle").toggle_cwd()
    end,
  })
  .implement({
    uuid = K.term.toggle_directory.uuid,
    action = function()
      require("fml.action.term.toggle").toggle_directory()
    end,
  })
  .implement({
    uuid = K.term.toggle_workspace.uuid,
    action = function()
      require("fml.action.term.toggle").toggle_workspace()
    end,
  })
  .implement({
    uuid = K.term.lazygit_cwd.uuid,
    action = function()
      require("fml.action.term.lazygit").lazygit_cwd()
    end,
  })
  .implement({
    uuid = K.term.lazygit_workspace.uuid,
    action = function()
      require("fml.action.term.lazygit").lazygit_workspace()
    end,
  })
  .implement({
    uuid = K.term.lazygit_file_history.uuid,
    action = function()
      require("fml.action.term.lazygit").lazygit_file_history()
    end,
  })
  .implement({
    uuid = K.term.yazi_cwd.uuid,
    action = function()
      require("fml.action.term.yazi").yazi_cwd()
    end,
  })
  .implement({
    uuid = K.term.yazi_workspace.uuid,
    action = function()
      require("fml.action.term.yazi").yazi_workspace()
    end,
  })
  .implement({
    uuid = K.term.yazi_reveal.uuid,
    action = function()
      require("fml.action.term.yazi").yazi_reveal()
    end,
  })

--[toggle] -----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.toggle.list.uuid,
    action = function(arg)
      require("fml.action.toggle").list(arg)
    end,
  })
  .implement({
    uuid = K.toggle.ai_provider.uuid,
    action = function(arg)
      require("fml.action.toggle").toggle_ai_provider(arg)
    end,
  })
  .implement({
    uuid = K.toggle.markdown.uuid,
    action = function()
      require("fml.action.toggle").list("markdown_local")
    end,
  })
  .implement({
    uuid = K.toggle.maximize.uuid,
    action = function()
      require("fml.action.toggle").toggle_maximize()
    end,
  })
  .implement({
    uuid = K.toggle.relativenumber.uuid,
    action = function()
      require("fml.action.toggle").list("ux_relativenumber")
    end,
  })
  .implement({
    uuid = K.toggle.theme.uuid,
    action = function(arg)
      require("fml.action.toggle").toggle_theme(arg)
    end,
  })
  .implement({
    uuid = K.toggle.theme_variant.uuid,
    action = function()
      require("fml.action.toggle").list("theme_variant")
    end,
  })
  .implement({
    uuid = K.toggle.transparency.uuid,
    action = function()
      require("fml.action.toggle").list("ux_transparency")
    end,
  })
  .implement({
    uuid = K.toggle.username.uuid,
    action = function()
      require("fml.action.toggle").list("ux_username")
    end,
  })

--[ux] widgets -------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.ux.reload_theme.uuid,
    action = function(arg)
      require("fml.action.ux").reload_theme(arg)
    end,
  })
  .implement({
    uuid = K.ux.resume_last_widget.uuid,
    action = function()
      require("fml.action.ux").resume_last_widget()
    end,
  })

--[win] close---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.close.uuid,
    action = function()
      require("fml.action.win.close").close()
    end,
  })
  .implement({
    uuid = K.win.close_others.uuid,
    action = function()
      require("fml.action.win.close").close_others()
    end,
  })

--[win] focus---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.focus_top.uuid,
    action = function()
      require("fml.action.win.focus").focus_top()
    end,
  })
  .implement({
    uuid = K.win.focus_right.uuid,
    action = function()
      require("fml.action.win.focus").focus_right()
    end,
  })
  .implement({
    uuid = K.win.focus_bottom.uuid,
    action = function()
      require("fml.action.win.focus").focus_bottom()
    end,
  })
  .implement({
    uuid = K.win.focus_left.uuid,
    action = function()
      require("fml.action.win.focus").focus_left()
    end,
  })
  .implement({
    uuid = K.win.focus_prev.uuid,
    action = function()
      require("fml.action.win.focus").focus_prev()
    end,
  })
  .implement({
    uuid = K.win.focus_next.uuid,
    action = function()
      require("fml.action.win.focus").focus_next()
    end,
  })

--[win] history-------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.history.uuid,
    action = function()
      require("fml.action.win.history").history()
    end,
  })
  .implement({
    uuid = K.win.history_backward.uuid,
    action = function()
      require("fml.action.win.history").history_backward()
    end,
  })
  .implement({
    uuid = K.win.history_forward.uuid,
    action = function()
      require("fml.action.win.history").history_forward()
    end,
  })

--[win] picker--------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.focus.uuid,
    action = function()
      require("fml.action.win.picker").focus()
    end,
  })
  .implement({
    uuid = K.win.project.uuid,
    action = function()
      require("fml.action.win.picker").project()
    end,
  })
  .implement({
    uuid = K.win.swap.uuid,
    action = function()
      require("fml.action.win.picker").swap()
    end,
  })

--[win] resize--------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.resize_horizontal_minus.uuid,
    action = function()
      require("fml.action.win.resize").resize_horizontal_minus()
    end,
  })
  .implement({
    uuid = K.win.resize_horizontal_plus.uuid,
    action = function()
      require("fml.action.win.resize").resize_horizontal_plus()
    end,
  })
  .implement({
    uuid = K.win.resize_vertical_minus.uuid,
    action = function()
      require("fml.action.win.resize").resize_vertical_minus()
    end,
  })
  .implement({
    uuid = K.win.resize_vertical_plus.uuid,
    action = function()
      require("fml.action.win.resize").resize_vertical_plus()
    end,
  })

--[win] scroll--------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.scroll_down.uuid,
    action = function()
      require("fml.action.win.scroll").scroll_down()
    end,
  })
  .implement({
    uuid = K.win.scroll_up.uuid,
    action = function()
      require("fml.action.win.scroll").scroll_up()
    end,
  })

--[win] split---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.split_above.uuid,
    action = function()
      require("fml.action.win.split").split_above()
    end,
  })
  .implement({
    uuid = K.win.split_right.uuid,
    action = function()
      require("fml.action.win.split").split_right()
    end,
  })
  .implement({
    uuid = K.win.split_below.uuid,
    action = function()
      require("fml.action.win.split").split_below()
    end,
  })
  .implement({
    uuid = K.win.split_left.uuid,
    action = function()
      require("fml.action.win.split").split_left()
    end,
  })
