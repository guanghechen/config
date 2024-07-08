local constant = require("fml.constant")
local state = require("fml.api.state")
local std_array = require("fml.std.array")
local std_object = require("fml.std.object")

vim.api.nvim_create_autocmd({ "BufAdd", "BufEnter" }, {
  callback = function(args)
    local bufnr = args.buf
    if type(bufnr) ~= "number" then
      return
    end

    if not state.validate_buf(bufnr) then
      state.bufs[bufnr] = nil
    else
      state.refresh_buf(bufnr)
    end

    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    state.refresh_tab(tabnr)
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete" }, {
  callback = function(args)
    local bufnr = args.buf
    if type(bufnr) ~= "number" or state.bufs[bufnr] == nil then
      return
    end

    state.bufs[bufnr] = nil

    local has_tab_removed = false ---@type boolean
    std_object.filter_inline(state.tabs, function(tab, tabnr)
      if not state.validate_tab(tabnr) then
        has_tab_removed = true
        return false
      end

      tab.bufnr_set[bufnr] = nil
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
