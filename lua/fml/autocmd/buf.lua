local state = require("fml.api.state")
local std_array = require("fml.std.array")
local std_object = require("fml.std.object")

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
      local win = state.wins[winnr]
      if win ~= nil then
        win.buf_history:push(bufnr)
      end
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete" }, {
  callback = function(args)
    local bufnr = args.buf
    if bufnr == nil or state.bufs[bufnr] == nil or not state.validate_buf(bufnr) then
      return
    end

    state.bufs[bufnr] = nil

    local has_tab_removed = false ---@type boolean
    std_object.filter_inline(state.tabs, function(tab, tabnr)
      if not state.validate_tab(tabnr) then
        has_tab_removed = true
        return false
      end

      std_array.filter_inline(tab.bufnrs, function(nr)
        return nr ~= bufnr
      end)

      if #tab.bufnrs < 1 then
        has_tab_removed = true
        return false
      end

      return true
    end)

    if has_tab_removed then
      state.schedule_refresh_tabs()
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.opt_local.buflisted = false
  end,
})
