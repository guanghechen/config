vim.api.nvim_create_autocmd("BufDelete", {
  group = eve.nvim.augroup("bootstrap_on_BufDelete"),
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    vim.schedule(function()
      eve.tab.on_buf_delete(tabnr)
      eve.status.dirtier_tabline:mark_dirty()
    end)
  end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = eve.nvim.augroup("bootstrap_on_BufWinEnter"),
  callback = function(arg)
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    local bufnr = arg.buf ---@type integer

    vim.schedule(function()
      eve.win.on_buf_enter(winnr, bufnr)
      eve.tab.on_buf_enter(tabnr, bufnr)
      eve.status.dirty_winline_nr:next(winnr)
      eve.status.dirtier_statusline:mark_dirty()
      eve.status.dirtier_tabline:mark_dirty()
    end)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = eve.nvim.augroup("bootstrap_on_FileType"),
  callback = function(event)
    local bufnr = event.buf ---@type integer|nil
    if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local filetype = vim.bo[bufnr].filetype ---@type string
    if eve.filetype.is_not_sourcefile(filetype) then
      vim.b[bufnr].miniindentscope_disable = true
      vim.b[bufnr].minipairs_disable = true
    end
  end,
})

vim.api.nvim_create_autocmd("WinEnter", {
  group = eve.nvim.augroup("bootstrap_on_WinEnter"),
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    eve.tab.on_win_enter(tabnr, winnr)
  end,
})

vim.api.nvim_create_autocmd("WinNew", {
  group = eve.nvim.augroup("bootstrap_on_WinNew"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer

    if eve.win.is_fixed(winnr) then
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local filetype = vim.bo[bufnr].filetype ---@type string

      if filetype == "Avante" or filetype == "AvanteInput" or filetype == "AvanteSelectedFiles" then
        local winnr_k = vim.fn.winnr("k") ---@type integer
        if winnr_k ~= nil and winnr_k ~= winnr then
          local bufnr_k = vim.api.nvim_win_get_buf(winnr_k) ---@type integer
          local filetype_k = vim.bo[bufnr_k].filetype ---@type string
          if filetype_k == "Avante" or filetype_k == "AvanteInput" or filetype_k == "AvanteSelectedFiles" then
            eve.win.set_type(winnr, eve.win.Types.AVANTE)
            return
          end
        end

        local winnr_j = vim.fn.winnr("j") ---@type integer
        if winnr_j ~= nil and winnr_j ~= winnr then
          local bufnr_j = vim.api.nvim_win_get_buf(winnr_j) ---@type integer
          local filetype_j = vim.bo[bufnr_j].filetype ---@type string
          if filetype_j == "Avante" or filetype_j == "AvanteInput" or filetype_j == "AvanteSelectedFiles" then
            eve.win.set_type(winnr, eve.win.Types.AVANTE)
            return
          end
        end
      end
    end

    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(winnr) then
        return
      end

      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local filetype = vim.bo[bufnr].filetype ---@type string

      if filetype == "neo-tree" then
        eve.win.set_type(winnr, eve.win.Types.NEOTREE)
        return
      end

      if filetype == "Avante" or filetype == "AvanteInput" or filetype == "AvanteSelectedFiles" then
        eve.win.set_type(winnr, eve.win.Types.AVANTE)
        return
      end
    end)
  end,
})

----------------------------------------------------------------------------------------------------

if 1 == 0 then
  vim.api.nvim_create_autocmd({ "WinNew", "WinEnter" }, {
    group = eve.nvim.augroup("debug_on_WinNew_WinEnter"),
    callback = function(arg)
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local bufname = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local buftype = vim.bo[bufnr].buftype ---@type string
      local filetype = vim.bo[bufnr].filetype ---@type string

      vim.schedule(function()
        if not vim.api.nvim_win_is_valid(winnr) then
          return
        end

        local bufnr2 = vim.api.nvim_win_get_buf(winnr) ---@type integer
        local bufname2 = vim.api.nvim_buf_get_name(bufnr2) ---@type string
        local buftype2 = vim.bo[bufnr2].buftype ---@type string
        local filetype2 = vim.bo[bufnr2].filetype ---@type string
        eve.debug.log_silent({
          arg = arg,
          winnr = winnr,
          b1 = {
            bufnr = bufnr,
            bufname = bufname,
            buftype = buftype,
            filetype = filetype,
          },
          b2 = {
            bufnr = bufnr2,
            bufname = bufname2,
            buftype = buftype2,
            filetype = filetype2,
          },
        })
      end)
    end,
  })
end
