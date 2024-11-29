local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

---@param bufnrs                        integer[]
---@return nil
local function close(bufnrs)
  if #bufnrs < 1 then
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = eve.context.state.tabs[tabnr] ---@type eve.t.context.state.tab.IItem
  if tab ~= nil then
    for _, bufnr in ipairs(bufnrs) do
      tab.bufnr_set[bufnr] = nil
    end

    local k = 0 ---@type integer
    local N = #tab.bufnrs ---@type integer
    for i = 1, N, 1 do
      local bufnr = tab.bufnrs[i]
      if tab.bufnr_set[bufnr] then
        k = k + 1
        tab.bufnrs[k] = bufnr
      end
    end
    for i = k + 1, N, 1 do
      tab.bufnrs[i] = nil
    end
  end

  fml.api.buf.remove_unrefereced_bufs(bufnrs) ---@type integer
end

eve.commander
  .register({
    uuid = uuids.buf_close,
    desc = "buf: close current",
    action = function()
      local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local win = eve.context.state.wins[winnr_cur] ---@type eve.t.context.state.win.IItem|nil

      ---! Set the buf to the last buf in the history before closing the current buf to avoid unexpected behaviors.
      if win ~= nil then
        local last_filepath = win.filepath_history:backward() ---@type string|nil
        local bufnr_last = fml.api.buf.locate_by_filepath(last_filepath) ---@type integer|nil
        if bufnr_last ~= nil and vim.api.nvim_buf_is_valid(bufnr_last) then
          vim.api.nvim_win_set_buf(winnr_cur, bufnr_last)
        end
      end

      close({ bufnr_cur })
    end,
  })
  .register({
    uuid = uuids.buf_close_to_leftest,
    desc = "buf: close to leftest",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local tab = fml.api.tab.get(tabnr) ---@type eve.t.context.state.tab.IItem|nil
      if tab == nil then
        return
      end

      local bufnrs_to_remove = {} ---@type integer[]
      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local visible_bufnrs = eve.tab.list_visible_bufnrs(tabnr) ---@type table<integer, boolean>
      for id = 1, #tab.bufnrs, 1 do
        local bufnr = tab.bufnrs[id] ---@type integer
        if bufnr == bufnr_cur then
          break
        end
        if not visible_bufnrs[bufnr] then
          table.insert(bufnrs_to_remove, bufnr)
        end
      end

      close(bufnrs_to_remove)
    end,
  })
  .register({
    uuid = uuids.buf_close_to_rightest,
    desc = "buf: close to rightest",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local tab = fml.api.tab.get(tabnr) ---@type eve.t.context.state.tab.IItem|nil
      if tab == nil then
        return
      end

      local bufnrs_to_remove = {} ---@type integer[]
      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local visible_bufnrs = eve.tab.list_visible_bufnrs(tabnr) ---@type table<integer, boolean>

      local start_id = 1 ---@type integer
      while start_id <= #tab.bufnrs do
        local bufnr = tab.bufnrs[start_id] ---@type integer
        if bufnr == bufnr_cur then
          break
        end
        start_id = start_id + 1
      end

      for id = start_id + 1, #tab.bufnrs, 1 do
        local bufnr = tab.bufnrs[id] ---@type integer
        if not visible_bufnrs[bufnr] then
          table.insert(bufnrs_to_remove, bufnr)
        end
      end

      close(bufnrs_to_remove)
    end,
  })
  .register({
    uuid = uuids.buf_close_others,
    desc = "buf: close others",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local tab = fml.api.tab.get(tabnr) ---@type eve.t.context.state.tab.IItem|nil
      if tab == nil then
        return
      end

      local bufnrs_to_remove = {} ---@type integer[]
      local visible_bufnrs = eve.tab.list_visible_bufnrs(tabnr) ---@type table<integer, boolean>
      for _, bufnr in ipairs(tab.bufnrs) do
        if not visible_bufnrs[bufnr] then
          local buf = eve.context.state.bufs[bufnr] ---@type eve.t.context.state.buf.IItem|nil
          if buf == nil or not buf.pinned then
            table.insert(bufnrs_to_remove, bufnr)
          end
        end
      end
      close(bufnrs_to_remove)
    end,
  })
