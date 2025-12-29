local command = dot.command ---@type dot.command
local K = dot.command.definitions ---@type dot.command.definitions

--[ai] ---------------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.ai.edit.uuid,
    action = function()
      require("fml.action.ai").edit()
    end,
  })
  .implement({
    uuid = K.ai.attach_agent.uuid,
    action = function()
      require("fml.action.ai").attach_agent()
    end,
  })
  .implement({
    uuid = K.ai.detach_agent.uuid,
    action = function()
      require("fml.action.ai").detach_agent()
    end,
  })
  .implement({
    uuid = K.ai.submit_buffer.uuid,
    action = function()
      require("fml.action.ai").submit_buffer()
    end,
  })
  .implement({
    uuid = K.ai.submit_selection.uuid,
    action = function()
      require("fml.action.ai").submit_selection()
    end,
  })
  .implement({
    uuid = K.ai.send_buffer.uuid,
    action = function()
      require("fml.action.ai").send_buffer()
    end,
  })
  .implement({
    uuid = K.ai.send_selection.uuid,
    action = function()
      require("fml.action.ai").send_selection()
    end,
  })
  .implement({
    uuid = K.ai.send_this.uuid,
    action = function()
      require("fml.action.ai").send_this()
    end,
  })
  .implement({
    uuid = K.ai.send_file.uuid,
    action = function()
      require("fml.action.ai").send_file()
    end,
  })
  .implement({
    uuid = K.ai.select_prompt.uuid,
    action = function()
      require("fml.action.ai").select_prompt()
    end,
  })

--[buf] close---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.buf.close.uuid,
    action = function()
      require("fml.action.buf").close()
    end,
  })
  .implement({
    uuid = K.buf.close_to_leftest.uuid,
    action = function()
      require("fml.action.buf").close_to_leftest()
    end,
  })
  .implement({
    uuid = K.buf.close_to_rightest.uuid,
    action = function()
      require("fml.action.buf").close_to_rightest()
    end,
  })
  .implement({
    uuid = K.buf.close_others.uuid,
    action = function()
      require("fml.action.buf").close_others()
    end,
  })

--[buf] focus---------------------------------------------------------------------------------------
for index = 1, 49, 1 do
  local bufid = index < 10 and ("0" .. tostring(index)) or tostring(index)
  command.implement({
    uuid = K.buf["focus_" .. bufid].uuid,
    action = function()
      require("fml.action.buf").focus(index)
    end,
  })
end
for index = 1, 9, 1 do
  command.implement({
    uuid = K.buf["focus_left_" .. tostring(index)].uuid,
    action = function()
      require("fml.action.buf").focus_left(index)
    end,
  })
  command.implement({
    uuid = K.buf["focus_right_" .. tostring(index)].uuid,
    action = function()
      require("fml.action.buf").focus_right(index)
    end,
  })
end

command
  .implement({
    uuid = K.buf.open.uuid,
    action = function(args)
      local bufnr = tonumber(args) ---@type integer|nil
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        require("fml.action.buf").open(bufnr)
      end
    end,
  })
  .implement({
    uuid = K.buf.focus.uuid,
    action = function(args)
      local bufid = tonumber(args) ---@type integer|nil
      if bufid ~= nil then
        require("fml.action.buf").focus(bufid)
      end
    end,
  })
  .implement({
    uuid = K.buf.focus_left.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.buf").focus_left(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.buf.focus_right.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.buf").focus_right(ok and step or nil)
    end,
  })

--[buf] new-----------------------------------------------------------------------------------------
command.implement({
  uuid = K.buf.new.uuid,
  action = function()
    require("fml.action.buf").new()
  end,
})

--[buf] pin-----------------------------------------------------------------------------------------
command.implement({
  uuid = K.buf.pin.uuid,
  action = function()
    require("fml.action.buf").toggle_pin()
  end,
})

--[buf] save----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.buf.save.uuid,
    action = function(args)
      require("fml.action.buf").save(args)
    end,
  })
  .implement({
    uuid = K.buf.save_no_format.uuid,
    action = function()
      require("fml.action.buf").save("noformat")
    end,
  })

--[buf] swap----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.buf.swap_left.uuid,
    action = function()
      require("fml.action.buf").swap_left()
    end,
  })
  .implement({
    uuid = K.buf.swap_right.uuid,
    action = function()
      require("fml.action.buf").swap_right()
    end,
  })

--[clipboard] paste---------------------------------------------------------------------------------
command
  .implement({
    uuid = K.clipboard.paste_image.uuid,
    action = function()
      era.fn.paste_image()
    end,
  })
  .implement({
    uuid = K.clipboard.paste_image_as_base64.uuid,
    action = function()
      local base64 = era.fn.paste_image_as_base64()
      if base64 then
        vim.api.nvim_put({ base64 }, "c", true, true)
      end
    end,
  })

--[code] run----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.code.run.uuid,
    action = function()
      era.fn.run_code(false)
    end,
  })
  .implement({
    uuid = K.code.run_force.uuid,
    action = function()
      era.fn.run_code(true)
    end,
  })
  .implement({
    uuid = K.code.run_as_neovim_command.uuid,
    action = function()
      era.fn.run_code_as_neovim_command()
    end,
  })
  .implement({
    uuid = K.code.format.uuid,
    action = function()
      local bufnr = vim.api.nvim_get_current_buf()
      require("conform").format({
        bufnr = bufnr,
        write = false,
        async = true,
      })
    end,
  })
  .implement({
    uuid = K.code.insert_splitline.uuid,
    action = function()
      era.fn.insert_splitline()
    end,
  })
  .implement({
    uuid = K.code.trim_trailspace.uuid,
    action = function()
      era.trailspace.trim()
      era.trailspace.trim_last_lines()
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
  .implement({
    uuid = K.diagnostic.outline.uuid,
    action = function()
      era.fn.find_diagnostics()
    end,
  })
  .implement({
    uuid = K.diagnostic.to_md.uuid,
    action = function()
      require("fml.action.diagnostic").to_md()
    end,
  })

--[explorer] ---------------------------------------------------------------------------------------
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
    tabtype = stl.nvim.tab.Types.NORMAL,
    action = function()
      dot.widget.explorer.toggle()
    end,
  })

--[find] -------------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.find.bufs.uuid,
    action = function()
      era.fn.find_buffers()
    end,
  })
  .implement({
    uuid = K.find.bufs_file.uuid,
    action = function()
      era.fn.find_buffers("F")
    end,
  })
  .implement({
    uuid = K.find.bufs_term.uuid,
    action = function()
      era.fn.find_buffers("T")
    end,
  })
  .implement({
    uuid = K.find.diagnostics.uuid,
    action = function()
      era.fn.find_diagnostics()
    end,
  })
  .implement({
    uuid = K.find.diagnostics_in_workspace.uuid,
    action = function()
      era.fn.find_diagnostics()
    end,
  })
  .implement({
    uuid = K.find.explorer.uuid,
    action = function(args)
      era.fn.find_explorer(args)
    end,
  })
  .implement({
    uuid = K.find.files.uuid,
    action = function(args)
      era.fn.find_files(args)
    end,
  })
  .implement({
    uuid = K.find.files_in_cwd.uuid,
    action = function()
      era.fn.find_files("cwd")
    end,
  })
  .implement({
    uuid = K.find.files_in_directory.uuid,
    action = function()
      era.fn.find_files("directory")
    end,
  })
  .implement({
    uuid = K.find.files_in_workspace.uuid,
    action = function()
      era.fn.find_files("workspace")
    end,
  })
  .implement({
    uuid = K.find.git_not_committed.uuid,
    action = function()
      era.fn.find_git()
    end,
  })
  .implement({
    uuid = K.find.highlights.uuid,
    action = function()
      era.fn.find_highlights()
    end,
  })
  .implement({
    uuid = K.find.notifications.uuid,
    action = function()
      era.fn.find_notifications()
    end,
  })
  .implement({
    uuid = K.find.pinned_files.uuid,
    action = function()
      era.fn.find_pinned_files()
    end,
  })
  .implement({
    uuid = K.find.lsp_symbols.uuid,
    action = function()
      era.fn.find_lsp_symbols()
    end,
  })
  .implement({
    uuid = K.find.vim_options.uuid,
    action = function()
      era.fn.find_vim_options()
    end,
  })
  .implement({
    uuid = K.find.keymaps.uuid,
    action = function()
      era.fn.find_keymaps()
    end,
  })

--[git] browse--------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.git.browse.uuid,
    action = function()
      era.git.browse.open()
    end,
  })
  .implement({
    uuid = K.git.browse_permalink.uuid,
    action = function()
      era.git.browse.open({ what = "permalink" })
    end,
  })
  .implement({
    uuid = K.git.browse_repo.uuid,
    action = function()
      era.git.browse.open({ what = "repo" })
    end,
  })

--[git] hunk----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.git.blame.uuid,
    action = function()
      era.git.blame.inline_toggle()
    end,
  })
  .implement({
    uuid = K.git.blame_buffer.uuid,
    action = function()
      era.git.blame.buffer_toggle()
    end,
  })
  .implement({
    uuid = K.git.hunk_goto_prev.uuid,
    action = function()
      if vim.wo.diff then
        vim.cmd.normal({ "[c", bang = true })
      else
        era.git.hunk.nav("prev")
      end
    end,
  })
  .implement({
    uuid = K.git.hunk_goto_next.uuid,
    action = function()
      if vim.wo.diff then
        vim.cmd.normal({ "]c", bang = true })
      else
        era.git.hunk.nav("next")
      end
    end,
  })
  .implement({
    uuid = K.git.hunk_goto_prev_all.uuid,
    action = function()
      if vim.wo.diff then
        vim.cmd.normal({ "[c", bang = true })
      else
        era.git.hunk.nav_all("prev")
      end
    end,
  })
  .implement({
    uuid = K.git.hunk_goto_next_all.uuid,
    action = function()
      if vim.wo.diff then
        vim.cmd.normal({ "]c", bang = true })
      else
        era.git.hunk.nav_all("next")
      end
    end,
  })
  .implement({
    uuid = K.git.hunk_preview.uuid,
    action = function()
      era.git.hunk.preview()
    end,
  })
  .implement({
    uuid = K.git.hunk_stage.uuid,
    action = function()
      era.git.hunk.stage()
    end,
  })
  .implement({
    uuid = K.git.hunk_stage_visual.uuid,
    action = function()
      local lnum_start, lnum_end = stl.nvim.buf.retrieve_visual_lnum_range()
      era.git.hunk.stage({ lnum_start, lnum_end })
    end,
  })
  .implement({
    uuid = K.git.hunk_unstage.uuid,
    action = function()
      era.git.hunk.unstage()
    end,
  })
  .implement({
    uuid = K.git.hunk_unstage_visual.uuid,
    action = function()
      local lnum_start, lnum_end = stl.nvim.buf.retrieve_visual_lnum_range()
      era.git.hunk.unstage({ lnum_start, lnum_end })
    end,
  })
  .implement({
    uuid = K.git.hunk_reset.uuid,
    action = function()
      era.git.hunk.reset()
    end,
  })
  .implement({
    uuid = K.git.hunk_reset_visual.uuid,
    action = function()
      local lnum_start, lnum_end = stl.nvim.buf.retrieve_visual_lnum_range()
      era.git.hunk.reset({ lnum_start, lnum_end })
    end,
  })
  .implement({
    uuid = K.git.stage_buffer.uuid,
    action = function()
      era.git.hunk.stage_buffer()
    end,
  })
  .implement({
    uuid = K.git.reset_buffer.uuid,
    action = function()
      era.git.hunk.reset_buffer()
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

--[lint] ---------------------------------------------------------------------------------------------
command.implement({
  uuid = K.lint.spellcheck_register.uuid,
  action = function()
    require("fml.action.lint").spellcheck_register()
  end,
})

--[log] ------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.log.preview_json_normal.uuid,
    action = function()
      require("fml.action.log").preview_json_normal()
    end,
  })
  .implement({
    uuid = K.log.preview_json_visual.uuid,
    action = function()
      require("fml.action.log").preview_json_visual()
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
    uuid = K.lsp.goto_prev_reference.uuid,
    action = function()
      local step = vim.v.count1 ---@type integer
      require("era.illuminate").jump(-step, true)
    end,
  })
  .implement({
    uuid = K.lsp.goto_next_reference.uuid,
    action = function()
      local step = vim.v.count1 ---@type integer
      require("era.illuminate").jump(step, true)
    end,
  })
  .implement({
    uuid = K.lsp.restart.uuid,
    action = function()
      require("fml.action.lsp.server").restart()
    end,
  })
  .implement({
    uuid = K.lsp.select_python_venv.uuid,
    action = function()
      require("fml.action.lsp.python_venv").activate_venv()
    end,
  })

--[notepad] ---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.notepad.append_content.uuid,
    action = function(args)
      if type(args) == "string" and #args > 0 then
        require("fml.action.notepad").append_content(args)
      end
    end,
  })
  .implement({
    uuid = K.notepad.toggle.uuid,
    action = function()
      require("fml.action.notepad").toggle()
    end,
  })
  .implement({
    uuid = K.notepad.show.uuid,
    action = function()
      require("fml.action.notepad").show()
    end,
  })
  .implement({
    uuid = K.notepad.close.uuid,
    action = function()
      require("fml.action.notepad").close()
    end,
  })
  .implement({
    uuid = K.notepad.save.uuid,
    action = function()
      require("fml.action.notepad").save()
    end,
  })
  .implement({
    uuid = K.notepad.create.uuid,
    action = function()
      require("fml.action.notepad").create()
    end,
  })
  .implement({
    uuid = K.notepad.destroy.uuid,
    action = function()
      require("fml.action.notepad").destroy()
    end,
  })
  .implement({
    uuid = K.notepad.rename.uuid,
    action = function()
      require("fml.action.notepad").rename()
    end,
  })

for index = 1, 9, 1 do
  local key = "focus_" .. tostring(index)
  command.implement({
    uuid = K.notepad[key].uuid,
    action = function()
      require("fml.action.notepad").focus_index(index)
    end,
  })
end

for index = 1, 9, 1 do
  command.implement({
    uuid = K.notepad["focus_left_" .. tostring(index)].uuid,
    action = function()
      require("fml.action.notepad").focus_left(tostring(index))
    end,
  })
  command.implement({
    uuid = K.notepad["focus_right_" .. tostring(index)].uuid,
    action = function()
      require("fml.action.notepad").focus_right(tostring(index))
    end,
  })
end

command
  .implement({
    uuid = K.notepad.focus_left.uuid,
    action = function(args)
      require("fml.action.notepad").focus_left(args)
    end,
  })
  .implement({
    uuid = K.notepad.focus_right.uuid,
    action = function(args)
      require("fml.action.notepad").focus_right(args)
    end,
  })
  .implement({
    uuid = K.notepad.swap_left.uuid,
    action = function(args)
      require("fml.action.notepad").swap_left(args)
    end,
  })
  .implement({
    uuid = K.notepad.swap_right.uuid,
    action = function(args)
      require("fml.action.notepad").swap_right(args)
    end,
  })
  .implement({
    uuid = K.notepad.source_select.uuid,
    action = function()
      require("fml.action.notepad").source_select()
    end,
  })
  .implement({
    uuid = K.notepad.note_select.uuid,
    action = function()
      require("fml.action.notepad").note_select()
    end,
  })
  .implement({
    uuid = K.notepad.source_prev.uuid,
    action = function()
      require("fml.action.notepad").source_prev()
    end,
  })
  .implement({
    uuid = K.notepad.source_next.uuid,
    action = function()
      require("fml.action.notepad").source_next()
    end,
  })
  .implement({
    uuid = K.notepad.change_engine.uuid,
    action = function()
      require("fml.action.notepad").change_engine()
    end,
  })
  .implement({
    uuid = K.notepad.go_backward.uuid,
    action = function()
      require("fml.action.notepad").go_backward()
    end,
  })
  .implement({
    uuid = K.notepad.go_forward.uuid,
    action = function()
      require("fml.action.notepad").go_forward()
    end,
  })
  .implement({
    uuid = K.notepad.split_h.uuid,
    action = function()
      require("fml.action.notepad").split("h")
    end,
  })
  .implement({
    uuid = K.notepad.split_j.uuid,
    action = function()
      require("fml.action.notepad").split("j")
    end,
  })
  .implement({
    uuid = K.notepad.split_k.uuid,
    action = function()
      require("fml.action.notepad").split("k")
    end,
  })
  .implement({
    uuid = K.notepad.split_l.uuid,
    action = function()
      require("fml.action.notepad").split("l")
    end,
  })

--[refresh] ----------------------------------------------------------------------------------------
command.implement({
  uuid = K.refresh.all.uuid,
  tabtype = stl.nvim.tab.Types.NORMAL,
  action = function()
    require("fml.action.refresh").refresh_all()
  end,
})

--[search] files------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.search.in_files.uuid,
    action = function(args)
      era.fn.search_in_files(args)
    end,
  })
  .implement({
    uuid = K.search.in_file.uuid,
    action = function()
      era.fn.search_in_files("file")
    end,
  })
  .implement({
    uuid = K.search.in_buffer.uuid,
    action = function()
      era.fn.search_in_buffer()
    end,
  })
  .implement({
    uuid = K.search.in_cwd.uuid,
    action = function()
      era.fn.search_in_files("cwd")
    end,
  })
  .implement({
    uuid = K.search.in_directory.uuid,
    action = function()
      era.fn.search_in_files("directory")
    end,
  })
  .implement({
    uuid = K.search.in_workspace.uuid,
    action = function()
      era.fn.search_in_files("workspace")
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
      require("fml.action.tab").close()
    end,
  })
  .implement({
    uuid = K.tab.close_to_leftest.uuid,
    action = function()
      require("fml.action.tab").close_to_leftest()
    end,
  })
  .implement({
    uuid = K.tab.close_to_rightest.uuid,
    action = function()
      require("fml.action.tab").close_to_rightest()
    end,
  })
  .implement({
    uuid = K.tab.close_others.uuid,
    action = function()
      require("fml.action.tab").close_others()
    end,
  })

--[tab] focus---------------------------------------------------------------------------------------
for i = 1, 10, 1 do
  command.implement({
    uuid = K.tab["focus_" .. tostring(i)].uuid,
    action = function()
      require("fml.action.tab").focus(i)
    end,
  })
end

command
  .implement({
    uuid = K.tab.focus.uuid,
    action = function(args)
      local tabid = tonumber(args) ---@type integer|nil
      if tabid ~= nil then
        require("fml.action.tab").focus(tabid)
      end
    end,
  })
  .implement({
    uuid = K.tab.focus_left.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.tab").focus_left(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.tab.focus_right.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      require("fml.action.tab").focus_right(ok and step or nil)
    end,
  })

--[tab] new-----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.tab.new.uuid,
    action = function()
      require("fml.action.tab").new()
    end,
  })
  .implement({
    uuid = K.tab.new_with_buf.uuid,
    action = function()
      require("fml.action.tab").new_with_buf()
    end,
  })

--[term] term---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.term.create.uuid,
    action = function()
      era.term.action.create()
    end,
  })
  .implement({
    uuid = K.term.destroy.uuid,
    action = function()
      era.term.action.destroy()
    end,
  })
  .implement({
    uuid = K.term.rename.uuid,
    action = function()
      era.term.action.rename()
    end,
  })
  .implement({
    uuid = K.term.toggle.uuid,
    action = function()
      era.term.action.toggle()
    end,
  })
  .implement({
    uuid = K.term.lazygit_cwd.uuid,
    action = function()
      era.term.action.lazygit_cwd()
    end,
  })
  .implement({
    uuid = K.term.lazygit_file_history.uuid,
    action = function()
      era.term.action.lazygit_file_history()
    end,
  })
  .implement({
    uuid = K.term.yazi_cwd.uuid,
    action = function()
      era.term.action.yazi_cwd()
    end,
  })
  .implement({
    uuid = K.term.yazi_workspace.uuid,
    action = function()
      era.term.action.yazi_workspace()
    end,
  })
  .implement({
    uuid = K.term.yazi_reveal.uuid,
    action = function()
      era.term.action.yazi_reveal()
    end,
  })

--[term] focus-----------------------------------------------------------------------------------------
for index = 1, 9, 1 do
  command.implement({
    uuid = K.term["focus_" .. tostring(index)].uuid,
    action = function()
      if era.term.state.focus(index) then
        era.term.widget:focus()
      end
    end,
  })
end

command
  .implement({
    uuid = K.term.focus_left.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      era.term.action.focus_left(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.term.focus_right.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      era.term.action.focus_right(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.term.swap_left.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      era.term.action.swap_left(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.term.swap_right.uuid,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      era.term.action.swap_right(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.term.split_h.uuid,
    action = function()
      era.term.widget:split("h")
    end,
  })
  .implement({
    uuid = K.term.split_j.uuid,
    action = function()
      era.term.widget:split("j")
    end,
  })
  .implement({
    uuid = K.term.split_k.uuid,
    action = function()
      era.term.widget:split("k")
    end,
  })
  .implement({
    uuid = K.term.split_l.uuid,
    action = function()
      era.term.widget:split("l")
    end,
  })

--[toggle] -----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.toggle.dim.uuid,
    action = function()
      require("fml.action.toggle.list").list("dressing_dim_flight")
    end,
  })
  .implement({
    uuid = K.toggle.expandtab.uuid,
    action = function()
      require("fml.action.toggle.list").list("expandtab_ux")
    end,
  })
  .implement({
    uuid = K.toggle.indent.uuid,
    action = function()
      require("fml.action.toggle.list").list("dressing_indent_flight")
    end,
  })
  .implement({
    uuid = K.toggle.list.uuid,
    action = function(arg)
      require("fml.action.toggle.list").list(arg)
    end,
  })
  .implement({
    uuid = K.toggle.markdown.uuid,
    action = function()
      require("fml.action.toggle.list").list("render_markdown_plugin")
    end,
  })
  .implement({
    uuid = K.toggle.markdown_local.uuid,
    action = function()
      require("fml.action.toggle.list").list("markdown_local")
    end,
  })
  .implement({
    uuid = K.toggle.maximize.uuid,
    action = function()
      require("fml.action.toggle.maximize").maximize()
    end,
  })
  .implement({
    uuid = K.toggle.number_local.uuid,
    action = function()
      require("fml.action.toggle.list").list("number_local")
    end,
  })
  .implement({
    uuid = K.toggle.relativenumber.uuid,
    action = function()
      require("fml.action.toggle.list").list("relativenumber_ux")
    end,
  })
  .implement({
    uuid = K.toggle.relativenumber_local.uuid,
    action = function()
      require("fml.action.toggle.list").list("relativenumber_local")
    end,
  })
  .implement({
    uuid = K.toggle.scroll.uuid,
    action = function()
      require("fml.action.toggle.list").list("dressing_scroll_flight")
    end,
  })
  .implement({
    uuid = K.toggle.signcolumn_local.uuid,
    action = function()
      require("fml.action.toggle.list").list("signcolumn_local")
    end,
  })
  .implement({
    uuid = K.toggle.theme.uuid,
    action = function(arg)
      require("fml.action.toggle.theme").theme(arg)
    end,
  })
  .implement({
    uuid = K.toggle.theme_variant.uuid,
    action = function()
      require("fml.action.toggle.list").list("theme_variant_ux")
    end,
  })
  .implement({
    uuid = K.toggle.trailspace.uuid,
    action = function()
      require("fml.action.toggle.list").list("dressing_trailspace_flight")
    end,
  })
  .implement({
    uuid = K.toggle.transparency.uuid,
    action = function()
      require("fml.action.toggle.list").list("transparency_ux")
    end,
  })
  .implement({
    uuid = K.toggle.username.uuid,
    action = function()
      require("fml.action.toggle.list").list("username_ux")
    end,
  })
  .implement({
    uuid = K.toggle.virtcolumn.uuid,
    action = function()
      require("fml.action.toggle.list").list("dressing_virtcolumn_flight")
    end,
  })
  .implement({
    uuid = K.toggle.wrap_local.uuid,
    action = function()
      require("fml.action.toggle.list").list("wrap_local")
    end,
  })

--[plugin] -----------------------------------------------------------------------------------------
command.implement({
  uuid = K.plugin.open.uuid,
  action = function()
    require("era.plugin").show()
  end,
})

--[ux] widgets -------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.ux.color_picker.uuid,
    action = function()
      require("era.colorpicker").ColorPicker.instance():pick()
    end,
  })
  .implement({
    uuid = K.ux.dismiss_notifications.uuid,
    action = function()
      dot.notifier.dismiss_all()
    end,
  })
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
      require("fml.action.win").close()
    end,
  })
  .implement({
    uuid = K.win.close_others.uuid,
    action = function()
      require("fml.action.win").close_others()
    end,
  })

--[win] focus---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.focus_top.uuid,
    action = function()
      require("fml.action.win").focus_top()
    end,
  })
  .implement({
    uuid = K.win.focus_right.uuid,
    action = function()
      require("fml.action.win").focus_right()
    end,
  })
  .implement({
    uuid = K.win.focus_bottom.uuid,
    action = function()
      require("fml.action.win").focus_bottom()
    end,
  })
  .implement({
    uuid = K.win.focus_left.uuid,
    action = function()
      require("fml.action.win").focus_left()
    end,
  })
  .implement({
    uuid = K.win.focus_prev.uuid,
    action = function()
      require("fml.action.win").focus_prev()
    end,
  })
  .implement({
    uuid = K.win.focus_next.uuid,
    action = function()
      require("fml.action.win").focus_next()
    end,
  })

--[win] history-------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.history.uuid,
    action = function()
      require("fml.action.win_history").history()
    end,
  })
  .implement({
    uuid = K.win.history_backward.uuid,
    action = function()
      require("fml.action.win_history").history_backward()
    end,
  })
  .implement({
    uuid = K.win.history_forward.uuid,
    action = function()
      require("fml.action.win_history").history_forward()
    end,
  })

--[win] mark----------------------------------------------------------------------------------------
command.implement({
  uuid = K.win.mark_sourcefile.uuid,
  action = function()
    require("fml.action.win").mark_sourcefile()
  end,
})

--[win] picker--------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.focus.uuid,
    action = function()
      require("fml.action.win").picker_focus()
    end,
  })
  .implement({
    uuid = K.win.project.uuid,
    action = function()
      require("fml.action.win").picker_project()
    end,
  })
  .implement({
    uuid = K.win.swap.uuid,
    action = function()
      require("fml.action.win").picker_swap()
    end,
  })

--[win] resize--------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.resize_horizontal_minus.uuid,
    action = function()
      require("fml.action.win").resize_horizontal_minus()
    end,
  })
  .implement({
    uuid = K.win.resize_horizontal_plus.uuid,
    action = function()
      require("fml.action.win").resize_horizontal_plus()
    end,
  })
  .implement({
    uuid = K.win.resize_vertical_minus.uuid,
    action = function()
      require("fml.action.win").resize_vertical_minus()
    end,
  })
  .implement({
    uuid = K.win.resize_vertical_plus.uuid,
    action = function()
      require("fml.action.win").resize_vertical_plus()
    end,
  })

--[win] split---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.split_above.uuid,
    action = function()
      require("fml.action.win").split_above()
    end,
  })
  .implement({
    uuid = K.win.split_right.uuid,
    action = function()
      require("fml.action.win").split_right()
    end,
  })
  .implement({
    uuid = K.win.split_below.uuid,
    action = function()
      require("fml.action.win").split_below()
    end,
  })
  .implement({
    uuid = K.win.split_left.uuid,
    action = function()
      require("fml.action.win").split_left()
    end,
  })

----------------------------------------------------------------------------------------------------
--                                            plugin                                              --
----------------------------------------------------------------------------------------------------

--[code] plugin: nvim-treesitter -------------------------------------------------------------------
command
  .implement({
    uuid = K.code.swap_conditional_branches.uuid,
    action = function()
      require("fml.action.plugin.nvim-treesitter").swap_conditional_branches()
    end,
  })
  .implement({
    uuid = K.code.swap_next_parameter.uuid,
    action = function()
      require("fml.action.plugin.nvim-treesitter").swap_next_parameter()
    end,
  })
  .implement({
    uuid = K.code.swap_prev_parameter.uuid,
    action = function()
      require("fml.action.plugin.nvim-treesitter").swap_prev_parameter()
    end,
  })

--[explorer] plugin: diffview ----------------------------------------------------------------------
command.implement({
  uuid = K.explorer.toggle.uuid,
  tabtype = stl.nvim.tab.Types.DIFFVIEW,
  action = function()
    require("fml.action.plugin.diffview").toggle()
  end,
})

--[git] plugin: diffview ---------------------------------------------------------------------------
command
  .implement({
    uuid = K.git.diffview.uuid,
    action = function()
      require("fml.action.plugin.diffview").diffview()
    end,
  })
  .implement({
    uuid = K.git.history.uuid,
    action = function()
      require("fml.action.plugin.diffview").history()
    end,
  })
  .implement({
    uuid = K.git.history_file.uuid,
    action = function()
      require("fml.action.plugin.diffview").history_file()
    end,
  })

--[refresh] plugin: diffview -----------------------------------------------------------------------
command.implement({
  uuid = K.refresh.all.uuid,
  tabtype = stl.nvim.tab.Types.DIFFVIEW,
  action = function()
    require("fml.action.plugin.diffview").refresh()
  end,
})
