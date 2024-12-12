local __module_name__ = "ghc.command.buf.focus" ---@type string

local reporter = require("eve.lib.reporter")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids
local focus_candidates = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" } ---@type string[]

---@param bufid                         integer the index of buffer list
---@return nil
local function focus(bufid)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab_meta = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
  if tab_meta == nil then
    reporter.error({
      from = __module_name__,
      subject = "focus",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr, bufid = bufid },
    })
    return
  end

  local bufs = tab_meta.bufs ---@type eve.t.state.state.tab.meta.IBuf[]
  local bufid_next = eve.util.navigate_circular(0, bufid, #bufs) ---@type integer
  eve.buf.go(bufs[bufid_next].bufnr)
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
      local tab_meta = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
      if tab_meta == nil then
        reporter.error({
          from = __module_name__,
          subject = "buf_focus_left",
          message = "Cannot resolve the meta for the current tab.",
          details = { tabnr = tabnr },
        })
        return
      end

      local bufs = tab_meta.bufs ---@type eve.t.state.state.tab.meta.IBuf[]
      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local _, bufid_cur = tab_meta:find_buf(bufnr_cur)

      if bufid_cur ~= nil then
        local _, step = pcall(tonumber, args)
        step = math.max(1, step or vim.v.count1 or 1)
        local bufid_next = eve.util.navigate_circular(bufid_cur, -step, #bufs)
        eve.buf.go(bufs[bufid_next].bufnr)
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
      local tab_meta = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
      if tab_meta == nil then
        reporter.error({
          from = __module_name__,
          subject = "buf_focus_right",
          message = "Cannot resolve the meta for the current tab.",
          details = { tabnr = tabnr },
        })
        return
      end

      local bufs = tab_meta.bufs ---@type eve.t.state.state.tab.meta.IBuf[]
      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local _, bufid_cur = tab_meta:find_buf(bufnr_cur)

      if bufid_cur ~= nil then
        local _, step = pcall(tonumber, args)
        step = math.max(1, step or vim.v.count1 or 1)
        local bufid_next = eve.util.navigate_circular(bufid_cur, step, #bufs)
        eve.buf.go(bufs[bufid_next].bufnr)
      end
    end,
  })
