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

    if state.validate_buf(bufnr) then
      state.refresh_buf(bufnr)
    else
      state.bufs[bufnr] = nil
    end

    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    state.refresh_tab(tabnr)

    ---! The current bufnr of the window still be the old one.
    local tab = state.tabs[tabnr]
    if tab ~= nil then
      if not tab.bufnr_set[bufnr] then
        tab.bufnr_set[bufnr] = true
        table.insert(tab.bufnrs, bufnr)
      end
    end

    if args.event == "BufAdd" then
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local win = state.wins[winnr]
      if win ~= nil then
        fml.debug.log("1", { 
          winnr = winnr,
          bufnr = bufnr,
          buf_history = win.buf_history._stack:collect(),
          valid = state.validate_buf(bufnr),
          bufnrs = state.tabs[win.tabnr] and state.tabs[win.tabnr].bufnrs or "nil",
        })
        win.buf_history:push(bufnr)
        fml.debug.log("2", { winnr = winnr, bufnr = bufnr, buf_history = win.buf_history._stack:collect() })
      end
    end
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
