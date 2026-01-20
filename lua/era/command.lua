local command = dot.command ---@type dot.command
local K = dot.command.definitions ---@type dot.command.definitions

--[acp] --------------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.acp.cancel.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ACP,
    action = function()
      era.m.acp.cancel()
    end,
  })
  .implement({
    uuid = K.acp.clear.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ACP,
    action = function()
      era.m.acp.clear()
    end,
  })
  .implement({
    uuid = K.acp.close.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ACP,
    action = function()
      era.m.acp.close()
    end,
  })
  .implement({
    uuid = K.acp.focus.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.acp.focus()
    end,
  })
  .implement({
    uuid = K.acp.new.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.acp.new_session()
    end,
  })
  .implement({
    uuid = K.acp.open.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      local provider = args ~= "" and args or nil
      era.m.acp.open({ provider = provider })
    end,
  })
  .implement({
    uuid = K.acp.select_provider.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ACP,
    action = function()
      era.m.acp.select_provider()
    end,
  })
  .implement({
    uuid = K.acp.submit.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ACP,
    action = function(args)
      local content = args ~= "" and args or nil
      era.m.acp.submit(content)
    end,
  })
  .implement({
    uuid = K.acp.toggle.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      local provider = args ~= "" and args or nil
      era.m.acp.toggle({ provider = provider })
    end,
  })

--[ai] ---------------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.ai.attach_agent.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.ai.action.show_attach_picker()
    end,
  })
  .implement({
    uuid = K.ai.detach_agent.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.ai.action.show_detach_picker()
    end,
  })
  .implement({
    uuid = K.ai.edit.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.ai.action.edit()
    end,
  })
  .implement({
    uuid = K.ai.select_prompt.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.ai.action.show_prompt_picker()
    end,
  })
  .implement({
    uuid = K.ai.send_buffer.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.ai.action.send_buffer()
    end,
  })
  .implement({
    uuid = K.ai.send_file.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.ai.action.send_file()
    end,
  })
  .implement({
    uuid = K.ai.send_selection.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.ai.action.send_selection()
    end,
  })
  .implement({
    uuid = K.ai.submit_buffer.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.ai.action.submit_buffer()
    end,
  })
  .implement({
    uuid = K.ai.submit_selection.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.ai.action.submit_selection()
    end,
  })
  .implement({
    uuid = K.ai.submit_to.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.ai.action.submit_to()
    end,
  })

--[buf] close---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.buf.close.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.buf.close()
    end,
  })
  .implement({
    uuid = K.buf.close_to_leftest.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.buf.close_to_leftest()
    end,
  })
  .implement({
    uuid = K.buf.close_to_rightest.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.buf.close_to_rightest()
    end,
  })
  .implement({
    uuid = K.buf.close_others.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.buf.close_others()
    end,
  })

--[buf] focus---------------------------------------------------------------------------------------
for index = 1, 49, 1 do
  local bufid = index < 10 and ("0" .. tostring(index)) or tostring(index)
  command.implement({
    uuid = K.buf["focus_" .. bufid].uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.buf.focus(index)
    end,
  })
end
for index = 1, 9, 1 do
  command.implement({
    uuid = K.buf["focus_left_" .. tostring(index)].uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.buf.focus_left(index)
    end,
  })
  command.implement({
    uuid = K.buf["focus_right_" .. tostring(index)].uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.buf.focus_right(index)
    end,
  })
end

command
  .implement({
    uuid = K.buf.open.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      local bufnr = tonumber(args) ---@type integer|nil
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        era.nvim.buf.open(bufnr)
      end
    end,
  })
  .implement({
    uuid = K.buf.focus.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      local bufid = tonumber(args) ---@type integer|nil
      if bufid ~= nil then
        era.nvim.buf.focus(bufid)
      end
    end,
  })
  .implement({
    uuid = K.buf.focus_left.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      era.nvim.buf.focus_left(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.buf.focus_right.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      era.nvim.buf.focus_right(ok and step or nil)
    end,
  })

--[buf] new-----------------------------------------------------------------------------------------
command.implement({
  uuid = K.buf.new.uuid,
  tabtypes = stl.nvim.tab.TypeSet.ALL,
  action = function()
    era.nvim.buf.new()
  end,
})

--[buf] pin-----------------------------------------------------------------------------------------
command.implement({
  uuid = K.buf.pin.uuid,
  tabtypes = stl.nvim.tab.TypeSet.ALL,
  action = function()
    era.nvim.buf.toggle_pin()
  end,
})

--[buf] save----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.buf.save.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      era.nvim.buf.save(args)
    end,
  })
  .implement({
    uuid = K.buf.save_no_format.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.buf.save("noformat")
    end,
  })

--[buf] swap----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.buf.swap_left.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.buf.swap_left()
    end,
  })
  .implement({
    uuid = K.buf.swap_right.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.buf.swap_right()
    end,
  })

--[clipboard] paste---------------------------------------------------------------------------------
command
  .implement({
    uuid = K.clipboard.paste_image.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.paste_image()
    end,
  })
  .implement({
    uuid = K.clipboard.paste_image_as_base64.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
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
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.run_code(false)
    end,
  })
  .implement({
    uuid = K.code.run_force.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.run_code(true)
    end,
  })
  .implement({
    uuid = K.code.run_as_neovim_command.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.run_code_as_neovim_command()
    end,
  })
  .implement({
    uuid = K.code.format.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
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
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.splitline.insert()
    end,
  })
  .implement({
    uuid = K.code.trim_trailspace.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.trailspace.trim()
      era.m.trailspace.trim_last_lines()
    end,
  })

--[copy] filepath-----------------------------------------------------------------------------------
command
  .implement({
    uuid = K.copy.filepath.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(arg)
      era.m.copy.copy_filepath(arg)
    end,
  })
  .implement({
    uuid = K.copy.filepath_absolute.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.copy.copy_filepath_absolute()
    end,
  })
  .implement({
    uuid = K.copy.filepath_relative.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.copy.copy_filepath_relative()
    end,
  })

--[copy] text---------------------------------------------------------------------------------------
command.implement({
  uuid = K.copy.char_under_cursor.uuid,
  tabtypes = stl.nvim.tab.TypeSet.ALL,
  action = function()
    era.m.copy.copy_char_under_cursor()
  end,
})

--[diagnostic] -------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.diagnostic.goto_next.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.diagnostic.goto_next()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_next_error.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.diagnostic.goto_next_error()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_next_warn.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.diagnostic.goto_next_warn()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_next_hint.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.diagnostic.goto_next_hint()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_next_quickfix.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.diagnostic.goto_next_quickfix()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_prev.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.diagnostic.goto_prev()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_prev_error.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.diagnostic.goto_prev_error()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_prev_warn.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.diagnostic.goto_prev_warn()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_prev_hint.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.diagnostic.goto_prev_hint()
    end,
  })
  .implement({
    uuid = K.diagnostic.goto_prev_quickfix.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.diagnostic.goto_prev_quickfix()
    end,
  })
  .implement({
    uuid = K.diagnostic.line.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.diagnostic.line()
    end,
  })
  .implement({
    uuid = K.diagnostic.outline.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_diagnostics()
    end,
  })
  .implement({
    uuid = K.diagnostic.to_md.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.diagnostic.to_md()
    end,
  })

--[diffview] ---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.diffview.close.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.diffview.fn.close()
    end,
  })
  .implement({
    uuid = K.diffview.open_commits.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.diffview.fn.open_commits()
    end,
  })
  .implement({
    uuid = K.diffview.open_file_history.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      local bufnr = vim.api.nvim_get_current_buf() ---@type integer
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      era.m.diffview.fn.open_file_history({ filepath = filepath })
    end,
  })
  .implement({
    uuid = K.diffview.open_workspace.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.diffview.fn.open_workspace()
    end,
  })
  .implement({
    uuid = K.diffview.refresh.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.diffview.fn.refresh()
    end,
  })
  .implement({
    uuid = K.diffview.toggle_commits.uuid,
    tabtypes = stl.nvim.tab.TypeSet.DIFFVIEW,
    action = function()
      era.m.diffview.fn.toggle_commits()
    end,
  })
  .implement({
    uuid = K.diffview.toggle_files.uuid,
    tabtypes = stl.nvim.tab.TypeSet.DIFFVIEW,
    action = function()
      era.m.diffview.fn.toggle_files()
    end,
  })

--[explorer] ---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.explorer.focus.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.widget.explorer.focus()
    end,
  })
  .implement({
    uuid = K.explorer.focus_cwd.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.widget.explorer.focus_cwd()
    end,
  })
  .implement({
    uuid = K.explorer.focus_workspace.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.widget.explorer.focus_workspace()
    end,
  })
  .implement({
    uuid = K.explorer.hide.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.widget.explorer.hide()
    end,
  })
  .implement({
    uuid = K.explorer.refresh.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.widget.explorer.refresh()
    end,
  })
  .implement({
    uuid = K.explorer.reveal.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.widget.explorer.reveal()
    end,
  })
  .implement({
    uuid = K.explorer.toggle.uuid,
    tabtypes = stl.nvim.tab.TypeSet.NORMAL,
    action = function()
      era.widget.explorer.toggle()
    end,
  })
  .implement({
    uuid = K.explorer.toggle.uuid,
    tabtypes = stl.nvim.tab.TypeSet.DIFFVIEW_WORKSPACE,
    action = function()
      era.m.diffview.fn.toggle_files()
    end,
  })
  .implement({
    uuid = K.explorer.toggle.uuid,
    tabtypes = stl.nvim.tab.TypeSet.DIFFVIEW_COMMITS,
    action = function()
      era.m.diffview.fn.toggle_commits()
    end,
  })

--[find] -------------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.find.bufs.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_buffers()
    end,
  })
  .implement({
    uuid = K.find.bufs_file.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_buffers("F")
    end,
  })
  .implement({
    uuid = K.find.bufs_term.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_buffers("T")
    end,
  })
  .implement({
    uuid = K.find.diagnostics.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_diagnostics()
    end,
  })
  .implement({
    uuid = K.find.diagnostics_in_workspace.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_diagnostics()
    end,
  })
  .implement({
    uuid = K.find.explorer.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      era.fn.find_explorer(args)
    end,
  })
  .implement({
    uuid = K.find.files.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      era.fn.find_files(args)
    end,
  })
  .implement({
    uuid = K.find.files_in_cwd.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_files("cwd")
    end,
  })
  .implement({
    uuid = K.find.files_in_directory.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_files("directory")
    end,
  })
  .implement({
    uuid = K.find.files_in_workspace.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_files("workspace")
    end,
  })
  .implement({
    uuid = K.find.git_not_committed.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_git()
    end,
  })
  .implement({
    uuid = K.find.highlights.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_highlights()
    end,
  })
  .implement({
    uuid = K.find.notifications.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_notifications()
    end,
  })
  .implement({
    uuid = K.find.pinned_files.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_pinned_files()
    end,
  })
  .implement({
    uuid = K.find.lsp_symbols.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_lsp_symbols()
    end,
  })
  .implement({
    uuid = K.find.vim_options.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_vim_options()
    end,
  })
  .implement({
    uuid = K.find.keymaps.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.find_keymaps()
    end,
  })

--[git] browse--------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.git.browse.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      stl.git.browse.open({
        cwd = dot.path.cwd(),
      })
    end,
  })
  .implement({
    uuid = K.git.browse_permalink.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      stl.git.browse.open({
        cwd = dot.path.cwd(),
        what = "permalink",
      })
    end,
  })
  .implement({
    uuid = K.git.browse_repo.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      stl.git.browse.open({
        cwd = dot.path.cwd(),
        what = "repo",
      })
    end,
  })

--[git] hunk----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.git.blame.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.git.blame.inline_toggle()
    end,
  })
  .implement({
    uuid = K.git.blame_buffer.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.git.blame.buffer_toggle()
    end,
  })
  .implement({
    uuid = K.git.hunk_goto_prev.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      if vim.api.nvim_get_option_value("diff", { win = 0 }) then
        vim.cmd.normal({ "[c", bang = true })
      else
        era.m.git.hunk.nav("prev")
      end
    end,
  })
  .implement({
    uuid = K.git.hunk_goto_next.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      if vim.api.nvim_get_option_value("diff", { win = 0 }) then
        vim.cmd.normal({ "]c", bang = true })
      else
        era.m.git.hunk.nav("next")
      end
    end,
  })
  .implement({
    uuid = K.git.hunk_goto_prev_all.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      if vim.api.nvim_get_option_value("diff", { win = 0 }) then
        vim.cmd.normal({ "[c", bang = true })
      else
        era.m.git.hunk.nav_all("prev")
      end
    end,
  })
  .implement({
    uuid = K.git.hunk_goto_next_all.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      if vim.api.nvim_get_option_value("diff", { win = 0 }) then
        vim.cmd.normal({ "]c", bang = true })
      else
        era.m.git.hunk.nav_all("next")
      end
    end,
  })
  .implement({
    uuid = K.git.hunk_preview.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.git.hunk.preview()
    end,
  })
  .implement({
    uuid = K.git.hunk_stage.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.git.hunk.stage()
    end,
  })
  .implement({
    uuid = K.git.hunk_stage_visual.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      local lnum_start, lnum_end = stl.nvim.buf.retrieve_visual_lnum_range()
      era.m.git.hunk.stage({ lnum_start, lnum_end })
    end,
  })
  .implement({
    uuid = K.git.hunk_unstage.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.git.hunk.unstage()
    end,
  })
  .implement({
    uuid = K.git.hunk_unstage_visual.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      local lnum_start, lnum_end = stl.nvim.buf.retrieve_visual_lnum_range()
      era.m.git.hunk.unstage({ lnum_start, lnum_end })
    end,
  })
  .implement({
    uuid = K.git.hunk_reset.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.git.hunk.reset()
    end,
  })
  .implement({
    uuid = K.git.hunk_reset_visual.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      local lnum_start, lnum_end = stl.nvim.buf.retrieve_visual_lnum_range()
      era.m.git.hunk.reset({ lnum_start, lnum_end })
    end,
  })
  .implement({
    uuid = K.git.stage_buffer.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.git.hunk.stage_buffer()
    end,
  })
  .implement({
    uuid = K.git.reset_buffer.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.git.hunk.reset_buffer()
    end,
  })

--[inspect] ------------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.inspect.inspect_buf.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.inspect.inspect_buf()
    end,
  })
  .implement({
    uuid = K.inspect.inspect_pos.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.inspect.inspect_pos()
    end,
  })
  .implement({
    uuid = K.inspect.inspect_state.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.inspect.inspect_state()
    end,
  })
  .implement({
    uuid = K.inspect.inspect_state_full.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.inspect.inspect_state_full()
    end,
  })
  .implement({
    uuid = K.inspect.inspect_tab.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.inspect.inspect_tab()
    end,
  })
  .implement({
    uuid = K.inspect.inspect_tree.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.inspect.inspect_tree()
    end,
  })
  .implement({
    uuid = K.inspect.inspect_window.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.inspect.inspect_window()
    end,
  })

--[lint] ---------------------------------------------------------------------------------------------
command.implement({
  uuid = K.lint.spellcheck_register.uuid,
  tabtypes = stl.nvim.tab.TypeSet.ALL,
  action = function()
    era.m.lint.spellcheck_register()
  end,
})

--[log] ------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.log.preview_json_normal.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.widget.log.preview_json_normal()
    end,
  })
  .implement({
    uuid = K.log.preview_json_visual.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.widget.log.preview_json_visual()
    end,
  })

--[lsp] reference-----------------------------------------------------------------------------------
command
  .implement({
    uuid = K.lsp.goto_definitions.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.reference.goto_definitions()
    end,
  })
  .implement({
    uuid = K.lsp.goto_implementations.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.reference.goto_implementations()
    end,
  })
  .implement({
    uuid = K.lsp.goto_references.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.reference.goto_references()
    end,
  })
  .implement({
    uuid = K.lsp.goto_type_definitions.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.reference.goto_type_definitions()
    end,
  })
  .implement({
    uuid = K.lsp.goto_prev_reference.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      local step = vim.v.count1 ---@type integer
      era.m.illuminate.jump(-step, true)
    end,
  })
  .implement({
    uuid = K.lsp.goto_next_reference.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      local step = vim.v.count1 ---@type integer
      era.m.illuminate.jump(step, true)
    end,
  })
  .implement({
    uuid = K.lsp.restart.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.lsp.fn.restart_server()
    end,
  })
  .implement({
    uuid = K.lsp.select_python_venv.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.python_venv.select_venv()
    end,
  })

--[notepad] ---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.notepad.append_content.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      if type(args) == "string" and #args > 0 then
        era.m.notepad.action.append_content(args)
      end
    end,
  })
  .implement({
    uuid = K.notepad.toggle.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.toggle()
    end,
  })
  .implement({
    uuid = K.notepad.show.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.show()
    end,
  })
  .implement({
    uuid = K.notepad.close.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.close()
    end,
  })
  .implement({
    uuid = K.notepad.save.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.save()
    end,
  })
  .implement({
    uuid = K.notepad.create.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.create()
    end,
  })
  .implement({
    uuid = K.notepad.destroy.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.destroy()
    end,
  })
  .implement({
    uuid = K.notepad.rename.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.rename()
    end,
  })

for index = 1, 9, 1 do
  local key = "focus_" .. tostring(index)
  command.implement({
    uuid = K.notepad[key].uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.focus_index(index)
    end,
  })
end

for index = 1, 9, 1 do
  command.implement({
    uuid = K.notepad["focus_left_" .. tostring(index)].uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.focus_left(tostring(index))
    end,
  })
  command.implement({
    uuid = K.notepad["focus_right_" .. tostring(index)].uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.focus_right(tostring(index))
    end,
  })
end

command
  .implement({
    uuid = K.notepad.focus_left.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      era.m.notepad.action.focus_left(args)
    end,
  })
  .implement({
    uuid = K.notepad.focus_right.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      era.m.notepad.action.focus_right(args)
    end,
  })
  .implement({
    uuid = K.notepad.swap_left.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      era.m.notepad.action.swap_left(args)
    end,
  })
  .implement({
    uuid = K.notepad.swap_right.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      era.m.notepad.action.swap_right(args)
    end,
  })
  .implement({
    uuid = K.notepad.source_select.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.source_select()
    end,
  })
  .implement({
    uuid = K.notepad.note_select.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.note_select()
    end,
  })
  .implement({
    uuid = K.notepad.source_prev.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.source_prev()
    end,
  })
  .implement({
    uuid = K.notepad.source_next.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.source_next()
    end,
  })
  .implement({
    uuid = K.notepad.change_engine.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.change_engine()
    end,
  })
  .implement({
    uuid = K.notepad.go_backward.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.go_backward()
    end,
  })
  .implement({
    uuid = K.notepad.go_forward.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.go_forward()
    end,
  })
  .implement({
    uuid = K.notepad.split_h.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.split("h")
    end,
  })
  .implement({
    uuid = K.notepad.split_j.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.split("j")
    end,
  })
  .implement({
    uuid = K.notepad.split_k.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.split("k")
    end,
  })
  .implement({
    uuid = K.notepad.split_l.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notepad.action.split("l")
    end,
  })

--[refresh] ----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.refresh.all.uuid,
    tabtypes = stl.nvim.tab.TypeSet.DIFFVIEW,
    action = function()
      era.m.diffview.fn.refresh()
    end,
  })
  .implement({
    uuid = K.refresh.all.uuid,
    tabtypes = stl.nvim.tab.TypeSet.NORMAL,
    action = function()
      era.fn.refresh_all()
    end,
  })

--[search] files------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.search.in_files.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      era.fn.search_in_files(args)
    end,
  })
  .implement({
    uuid = K.search.in_file.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.search_in_files("file")
    end,
  })
  .implement({
    uuid = K.search.in_buffer.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.search_in_buffer()
    end,
  })
  .implement({
    uuid = K.search.in_cwd.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.search_in_files("cwd")
    end,
  })
  .implement({
    uuid = K.search.in_directory.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.search_in_files("directory")
    end,
  })
  .implement({
    uuid = K.search.in_workspace.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.search_in_files("workspace")
    end,
  })

--[session] ----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.session.restore.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      dot.session.restore()
    end,
  })
  .implement({
    uuid = K.session.restore_autosaved.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      dot.session.restore_autosaved()
    end,
  })
  .implement({
    uuid = K.session.save.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      dot.session.save()
    end,
  })

--[tab] close---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.tab.close.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.tab.close()
    end,
  })
  .implement({
    uuid = K.tab.close_to_leftest.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.tab.close_to_leftest()
    end,
  })
  .implement({
    uuid = K.tab.close_to_rightest.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.tab.close_to_rightest()
    end,
  })
  .implement({
    uuid = K.tab.close_others.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.tab.close_others()
    end,
  })

--[tab] focus---------------------------------------------------------------------------------------
for i = 1, 10, 1 do
  command.implement({
    uuid = K.tab["focus_" .. tostring(i)].uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.tab.focus(i)
    end,
  })
end

command
  .implement({
    uuid = K.tab.focus.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      local tabid = tonumber(args) ---@type integer|nil
      if tabid ~= nil then
        era.nvim.tab.focus(tabid)
      end
    end,
  })
  .implement({
    uuid = K.tab.focus_left.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      era.nvim.tab.focus_left(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.tab.focus_right.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      era.nvim.tab.focus_right(ok and step or nil)
    end,
  })

--[tab] new-----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.tab.new.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.tab.new()
    end,
  })
  .implement({
    uuid = K.tab.new_with_buf.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.tab.new_with_buf()
    end,
  })

--[term] term---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.term.create.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.term.action.create()
    end,
  })
  .implement({
    uuid = K.term.destroy.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.term.action.destroy()
    end,
  })
  .implement({
    uuid = K.term.rename.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.term.action.rename()
    end,
  })
  .implement({
    uuid = K.term.toggle.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.term.action.toggle()
    end,
  })
  .implement({
    uuid = K.term.lazygit_cwd.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.term.action.lazygit_cwd()
    end,
  })
  .implement({
    uuid = K.term.lazygit_file_history.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.term.action.lazygit_file_history()
    end,
  })
  .implement({
    uuid = K.term.yazi_cwd.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.term.action.yazi_cwd()
    end,
  })
  .implement({
    uuid = K.term.yazi_workspace.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.term.action.yazi_workspace()
    end,
  })
  .implement({
    uuid = K.term.yazi_reveal.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.term.action.yazi_reveal()
    end,
  })

--[term] focus-----------------------------------------------------------------------------------------
for index = 1, 9, 1 do
  command.implement({
    uuid = K.term["focus_" .. tostring(index)].uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      if era.m.term.state.focus(index) then
        era.m.term.widget:focus()
      end
    end,
  })
end

command
  .implement({
    uuid = K.term.focus_left.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      era.m.term.action.focus_left(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.term.focus_right.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      era.m.term.action.focus_right(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.term.swap_left.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      era.m.term.action.swap_left(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.term.swap_right.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(args)
      local ok, step = pcall(tonumber, args)
      era.m.term.action.swap_right(ok and step or nil)
    end,
  })
  .implement({
    uuid = K.term.split_h.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.term.widget:split("h")
    end,
  })
  .implement({
    uuid = K.term.split_j.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.term.widget:split("j")
    end,
  })
  .implement({
    uuid = K.term.split_k.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.term.widget:split("k")
    end,
  })
  .implement({
    uuid = K.term.split_l.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.term.widget:split("l")
    end,
  })

--[toggle] -----------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.toggle.dim.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("dressing_dim_flight")
    end,
  })
  .implement({
    uuid = K.toggle.expandtab.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("expandtab_ux")
    end,
  })
  .implement({
    uuid = K.toggle.indent.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("dressing_indent_flight")
    end,
  })
  .implement({
    uuid = K.toggle.list.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(arg)
      era.m.toggle.list.list(arg)
    end,
  })
  .implement({
    uuid = K.toggle.markdown.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("render_markdown_plugin")
    end,
  })
  .implement({
    uuid = K.toggle.markdown_local.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("markdown_local")
    end,
  })
  .implement({
    uuid = K.toggle.maximize.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.maximize.toggle()
    end,
  })
  .implement({
    uuid = K.toggle.minimap.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.minimap.toggle()
    end,
  })
  .implement({
    uuid = K.toggle.minimap_local.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
      if winnr ~= nil then
        era.m.minimap.toggle_local(winnr)
      end
    end,
  })
  .implement({
    uuid = K.toggle.number_local.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("number_local")
    end,
  })
  .implement({
    uuid = K.toggle.relativenumber.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("relativenumber_ux")
    end,
  })
  .implement({
    uuid = K.toggle.relativenumber_local.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("relativenumber_local")
    end,
  })
  .implement({
    uuid = K.toggle.scroll.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("dressing_scroll_flight")
    end,
  })
  .implement({
    uuid = K.toggle.signcolumn_local.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("signcolumn_local")
    end,
  })
  .implement({
    uuid = K.toggle.theme.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(arg)
      era.m.toggle.theme.theme(arg)
    end,
  })
  .implement({
    uuid = K.toggle.theme_variant.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("theme_variant_ux")
    end,
  })
  .implement({
    uuid = K.toggle.trailspace.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("dressing_trailspace_flight")
    end,
  })
  .implement({
    uuid = K.toggle.transparency.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("transparency_ux")
    end,
  })
  .implement({
    uuid = K.toggle.username.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("username_ux")
    end,
  })
  .implement({
    uuid = K.toggle.virtcolumn.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("dressing_virtcolumn_flight")
    end,
  })
  .implement({
    uuid = K.toggle.wrap_local.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.toggle.list.list("wrap_local")
    end,
  })

--[plugin] -----------------------------------------------------------------------------------------
command.implement({
  uuid = K.plugin.open.uuid,
  tabtypes = stl.nvim.tab.TypeSet.ALL,
  action = function()
    era.m.plugin.show()
  end,
})

--[ux] widgets -------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.ux.color_picker.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.colorpicker.ColorPicker.instance():pick()
    end,
  })
  .implement({
    uuid = K.ux.copy_notifications.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notifier.copy_history()
    end,
  })
  .implement({
    uuid = K.ux.dismiss_notifications.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.m.notifier.dismiss_all()
    end,
  })
  .implement({
    uuid = K.ux.reload_theme.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function(arg)
      local force = type(arg) == "string" and arg:lower() == "force" ---@type boolean
      dot.context.theme.reload_theme(force, true)
    end,
  })
  .implement({
    uuid = K.ux.resume_last_widget.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.fn.resume_last_widget()
    end,
  })

--[view] -------------------------------------------------------------------------------------------
command.implement({
  uuid = K.view.notifications.uuid,
  tabtypes = stl.nvim.tab.TypeSet.ALL,
  action = function()
    era.view.notifications.open()
  end,
})

--[win] close---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.close.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.close()
    end,
  })
  .implement({
    uuid = K.win.close_others.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.close_others()
    end,
  })

--[win] focus---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.focus_top.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.focus_top()
    end,
  })
  .implement({
    uuid = K.win.focus_right.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.focus_right()
    end,
  })
  .implement({
    uuid = K.win.focus_bottom.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.focus_bottom()
    end,
  })
  .implement({
    uuid = K.win.focus_left.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.focus_left()
    end,
  })
  .implement({
    uuid = K.win.focus_prev.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.focus_prev()
    end,
  })
  .implement({
    uuid = K.win.focus_next.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.focus_next()
    end,
  })

--[win] history-------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.history.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.widget.win_history.history()
    end,
  })
  .implement({
    uuid = K.win.history_backward.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.widget.win_history.history_backward()
    end,
  })
  .implement({
    uuid = K.win.history_forward.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.widget.win_history.history_forward()
    end,
  })

--[win] mark----------------------------------------------------------------------------------------
command.implement({
  uuid = K.win.mark_sourcefile.uuid,
  tabtypes = stl.nvim.tab.TypeSet.ALL,
  action = function()
    era.nvim.win.mark_sourcefile()
  end,
})

--[win] picker--------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.focus.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.picker_focus()
    end,
  })
  .implement({
    uuid = K.win.project.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.picker_project()
    end,
  })
  .implement({
    uuid = K.win.swap.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.picker_swap()
    end,
  })

--[win] resize--------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.resize_horizontal_minus.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.resize_horizontal_minus()
    end,
  })
  .implement({
    uuid = K.win.resize_horizontal_plus.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.resize_horizontal_plus()
    end,
  })
  .implement({
    uuid = K.win.resize_vertical_minus.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.resize_vertical_minus()
    end,
  })
  .implement({
    uuid = K.win.resize_vertical_plus.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.resize_vertical_plus()
    end,
  })

--[win] split---------------------------------------------------------------------------------------
command
  .implement({
    uuid = K.win.split_above.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.split_above()
    end,
  })
  .implement({
    uuid = K.win.split_right.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.split_right()
    end,
  })
  .implement({
    uuid = K.win.split_below.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.split_below()
    end,
  })
  .implement({
    uuid = K.win.split_left.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      era.nvim.win.split_left()
    end,
  })

----------------------------------------------------------------------------------------------------
--                                            plugin                                              --
----------------------------------------------------------------------------------------------------

--[code] plugin: nvim-treesitter -------------------------------------------------------------------
command
  .implement({
    uuid = K.code.swap_conditional_branches.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      require("era.plugin.nvim-treesitter").swap_conditional_branches()
    end,
  })
  .implement({
    uuid = K.code.swap_next_parameter.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      require("era.plugin.nvim-treesitter").swap_next_parameter()
    end,
  })
  .implement({
    uuid = K.code.swap_prev_parameter.uuid,
    tabtypes = stl.nvim.tab.TypeSet.ALL,
    action = function()
      require("era.plugin.nvim-treesitter").swap_prev_parameter()
    end,
  })
