local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

---@type string[]
local focus_candidates = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }

---@param bufid                         integer the index of buffer list
---@return nil
local function focus(bufid)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = fml.api.tab.get(tabnr) ---@type eve.t.context.state.tab.IItem|nil
  if tab == nil or bufid < 1 or bufid > #tab.bufnrs then
    return
  end

  local bufid_next = eve.util.navigate_circular(0, bufid, #tab.bufnrs)
  local bufnr_next = tab.bufnrs[bufid_next]
  fml.api.buf.go(bufnr_next)
end

for i = 1, 10, 1 do
  local idx = tostring(i) ---@type string
  eve.commander.register({
    uuid = uuids["buf_focus_" .. idx],
    desc = "buf: focus " .. idx,
    action = function()
      eve.commander.execute(uuids.buf_focus, idx)
    end,
  })
end

eve.commander
  .register({
    uuid = uuids.buf_focus,
    desc = "buf: focus",
    candidates = focus_candidates,
    nargs = 1,
    action = function(args)
      local bufid = tonumber(args) ---@type integer|nil
      if bufid ~= nil then
        focus(bufid)
      end
    end,
  })
  .register({
    uuid = uuids.buf_focus_left,
    desc = "buf: focus left",
    candidates = focus_candidates,
    nargs = "?",
    action = function(args)
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local tab = fml.api.tab.get(tabnr) ---@type eve.t.context.state.tab.IItem|nil
      if tab == nil then
        return
      end

      local _, step = pcall(tonumber, args)
      step = math.max(1, step or vim.v.count1 or 1)
      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local bufid_cur = eve.array.first(tab.bufnrs, bufnr_cur) ---@type integer|nil

      if bufid_cur ~= nil then
        local bufid_next = eve.util.navigate_circular(bufid_cur, -step, #tab.bufnrs)
        local bufnr_next = tab.bufnrs[bufid_next]
        fml.api.buf.go(bufnr_next)
      end
    end,
  })
  .register({
    uuid = uuids.buf_focus_right,
    desc = "buf: focus right",
    candidates = focus_candidates,
    nargs = "?",
    action = function(args)
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local tab = fml.api.tab.get(tabnr) ---@type eve.t.context.state.tab.IItem|nil
      if tab == nil then
        return
      end

      local _, step = pcall(tonumber, args)
      step = math.max(1, step or vim.v.count1 or 1)
      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local bufid_cur = eve.array.first(tab.bufnrs, bufnr_cur) ---@type integer|nil

      if bufid_cur ~= nil then
        local bufid_next = eve.util.navigate_circular(bufid_cur, step, #tab.bufnrs)
        local bufnr_next = tab.bufnrs[bufid_next]
        fml.api.buf.go(bufnr_next)
      end
    end,
  })
