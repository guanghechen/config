local state = require("fml.api.state")
local std_array = require("fml.std.array")

vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
  callback = function(args)
    local bufnr = args.buf
    state.refresh_buf(bufnr)
    if bufnr == nil or state.bufs[bufnr] == nil then
      return
    end

    local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
    if tab == nil then
      return
    end

    if not std_array.contains(tab.bufnrs, bufnr) then
      table.insert(tab.bufnrs, bufnr)
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local win = tab.wins[winnr]
      if win ~= nil then
        win.buf_history:push(bufnr)
      end
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete" }, {
  callback = function(args)
    local bufnr = args.buf
    if bufnr == nil or not state.validate_buf(bufnr) then
      return
    end

    state.bufs[bufnr] = nil
    for tabnr, tab in pairs(state.tabs) do
      if not state.validate_tab(tabnr) then
        state.tabs[tabnr] = nil
      else
        std_array.filter_inline(tab.bufnrs, function(nr)
          return nr ~= bufnr
        end)
        if #tab.bufnrs < 1 then
          state.tabs[tabnr] = nil
        end
      end
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.opt_local.buflisted = false
  end,
})
