---! Go to last loc when opening a buffer
vim.api.nvim_create_autocmd({ "BufReadPost" }, {
  callback = function(event)
    local bufnr = event.buf ---@type integer
    if vim.b[bufnr].eve_last_loc then
      return
    end
    vim.b[bufnr].eve_last_loc = true

    local filetype = vim.bo[bufnr].filetype ---@type string
    if eve.filetype.is_plain_file(filetype) then
      local mark = vim.api.nvim_buf_get_mark(bufnr, '"')
      local lcount = vim.api.nvim_buf_line_count(bufnr)
      if mark[1] > 0 and mark[1] <= lcount then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
      end
    end
  end,
})
