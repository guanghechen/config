local __module_name__ = "ghc.command.buf.close" ---@type string

local reporter = require("eve.lib.reporter")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

---@param bufnrs                        integer[]
---@return nil
local function close(bufnrs)
  if #bufnrs < 1 then
    return
  end

  eve.tab.on_bufs_close(bufnrs)
  eve.tab.remove_unrefereced_bufs(bufnrs) ---@type integer
end

---@param tabnr                         integer
---@return table<integer, boolean>
local function list_visible_bufnrs(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  local bufnrs = {} ---@type table<integer, boolean>
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    bufnrs[bufnr] = true
  end
  return bufnrs
end

eve.commander
  .register({
    uuid = uuids.buf_close,
    desc = "buf: close current",
    action = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local bufnr = vim.api.nvim_get_current_buf() ---@type integer
      local win_meta = eve.win.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil

      ---! Set the buf to the last buf in the history before closing the current buf to avoid unexpected behaviors.
      if win_meta ~= nil then
        local last_filepath = win_meta.filepath_history:backward() ---@type string|nil
        local bufnr_last = eve.buf.locate_by_filepath(last_filepath) ---@type integer|nil
        if bufnr_last ~= nil and vim.api.nvim_buf_is_valid(bufnr_last) then
          vim.api.nvim_win_set_buf(winnr, bufnr_last)
        end
      end

      close({ bufnr })
    end,
  })
  .register({
    uuid = uuids.buf_close_to_leftest,
    desc = "buf: close to leftest",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local tab_meta = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
      if tab_meta == nil then
        reporter.error({
          from = __module_name__,
          subject = "buf_close_to_leftest",
          message = "Cannot resolve the meta for the current tab.",
          details = { tabnr = tabnr },
        })
        return
      end

      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local bufnrs_to_remove = {} ---@type integer[]
      local bufnrs_visible = list_visible_bufnrs(tabnr) ---@type table<integer, boolean>
      local tab_bufnrs = tab_meta.bufnrs ---@type integer[]

      for index = 1, tab_bufnrs, 1 do
        local bufnr = tab_bufnrs[index] ---@type integer
        if bufnr == bufnr_cur then
          break
        end
        if not bufnrs_visible[bufnr] then
          local buf_meta = eve.buf.get_meta(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
          if buf_meta == nil or not buf_meta.pinned then
            table.insert(bufnrs_to_remove, bufnr)
          end
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
      local tab_meta = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
      if tab_meta == nil then
        reporter.error({
          from = __module_name__,
          subject = "buf_close_to_rightest",
          message = "Cannot resolve the meta for the current tab.",
          details = { tabnr = tabnr },
        })
        return
      end

      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local bufnrs_to_remove = {} ---@type integer[]
      local bufnrs_visible = list_visible_bufnrs(tabnr) ---@type table<integer, boolean>
      local tab_bufnrs = tab_meta.bufnrs ---@type integer[]

      local index = 1 ---@type integer
      while index <= #tab_bufnrs do
        local bufnr = tab_bufnrs[index] ---@type integer
        if bufnr == bufnr_cur then
          break
        end
        index = index + 1
      end

      for id = index + 1, #tab_bufnrs, 1 do
        local bufnr = tab_bufnrs[id] ---@type integer
        if not bufnrs_visible[bufnr] then
          local buf_meta = eve.buf.get_meta(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
          if buf_meta == nil or not buf_meta.pinned then
            table.insert(bufnrs_to_remove, bufnr)
          end
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
      local tab_meta = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
      if tab_meta == nil then
        reporter.error({
          from = __module_name__,
          subject = "buf_close_others",
          message = "Cannot resolve the meta for the current tab.",
          details = { tabnr = tabnr },
        })
        return
      end

      local bufnrs_to_remove = {} ---@type integer[]
      local bufnrs_visible = list_visible_bufnrs(tabnr) ---@type table<integer, boolean>
      local tab_bufnrs = tab_meta.bufnrs ---@type integer[]

      for _, bufnr in ipairs(tab_bufnrs) do
        if not bufnrs_visible[bufnr] then
          local buf_meta = eve.buf.get_meta(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
          if buf_meta == nil or not buf_meta.pinned then
            table.insert(bufnrs_to_remove, bufnr)
          end
        end
      end

      close(bufnrs_to_remove)
    end,
  })
