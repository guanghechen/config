vim.api.nvim_create_autocmd("VimLeavePre", {
  group = eve.nvim.augroup("state_on_VimLeavePre"),
  once = true,
  callback = function()
    eve.state.dispose()
  end,
})

vim.api.nvim_create_autocmd({ "VimEnter", "SessionLoadPost" }, {
  group = eve.nvim.augroup("state_on_VimEnter"),
  callback = function()
    vim.schedule(function()
      local cwd = eve.path.cwd() ---@type string
      local existed_filepaths = {} ---@type table<string, boolean>
      local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
      for _, bufnr in ipairs(bufnrs) do
        local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
        local filepath = eve.path.resolve(cwd, filename) ---@type string
        existed_filepaths[filepath] = true
      end

      for _, bufnr in ipairs(bufnrs) do
        local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
        local filepath = eve.path.resolve(cwd, filename) ---@type string
        if eve.path.is_exist_dirpath(filepath) then
          local new_filepath = eve.buf.pick_filepath(filepath, existed_filepaths) ---@type string|nil
          if new_filepath ~= nil then
            existed_filepaths[new_filepath] = true
            if eve.buf.is_valid(bufnr) then
              local filetype = vim.bo[bufnr].filetype ---@type string
              vim.bo[bufnr].filetype = #filetype > 0 and filetype or "text" ---@type string
              vim.bo[bufnr].swapfile = false
              vim.api.nvim_buf_set_name(bufnr, new_filepath)
            end
          end
        end
      end

      eve.tab.refresh()
      eve.status.dirtier_statusline:mark_dirty()
      eve.status.dirtier_tabline:mark_dirty()
    end)
  end,
})
