local state = require("eve.state")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

---@type string[]
local focus_candidates = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }

---@param tabnr                         integer the stable unique number of the tabpage
---@return nil
local function go(tabnr)
  local tabnr_from = vim.api.nvim_get_current_tabpage() ---@type integer
  if tabnr_from ~= tabnr then
    vim.api.nvim_set_current_tabpage(tabnr)
    state.tab.tab_history:push(tabnr)
  end
end

---@param tabid                         integer the index of tab list
---@return nil
local function focus(tabid)
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = eve.util.navigate_limit(0, tabid, tab_count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  go(tabnr_next)
end

for i = 1, 10, 1 do
  local idx = tostring(i) ---@type string
  eve.commander.register({
    uuid = uuids["tab_focus_" .. idx],
    desc = "tab: focus " .. idx,
    action = function()
      eve.commander.execute(uuids.tab_focus, idx)
    end,
  })
end

eve.commander
  .register({
    uuid = uuids.tab_focus,
    desc = "tab: focus",
    candidates = focus_candidates,
    nargs = 1,
    action = function(args)
      local tabid = tonumber(args) ---@type integer|nil
      if tabid ~= nil then
        focus(tabid)
      end
    end,
  })
  .register({
    uuid = uuids.tab_focus_left,
    desc = "tab: focus left",
    candidates = focus_candidates,
    nargs = "?",
    action = function(args)
      local _, step = pcall(tonumber, args)
      step = math.max(1, step or vim.v.count1 or 1)
      local tabid_cur = vim.fn.tabpagenr() ---@type integer
      local tab_count = vim.fn.tabpagenr("$") ---@type integer
      local tabid_next = eve.util.navigate_circular(tabid_cur, -step, tab_count)
      local tabpages = vim.api.nvim_list_tabpages()
      local tabnr_next = tabpages[tabid_next]
      go(tabnr_next)
    end,
  })
  .register({
    uuid = uuids.tab_focus_right,
    desc = "tab: focus right",
    candidates = focus_candidates,
    nargs = "?",
    action = function(args)
      local _, step = pcall(tonumber, args)
      step = math.max(1, step or vim.v.count1 or 1)
      local tabid_cur = vim.fn.tabpagenr() ---@type integer
      local tab_count = vim.fn.tabpagenr("$") ---@type integer
      local tabid_next = eve.util.navigate_circular(tabid_cur, step, tab_count)
      local tabpages = vim.api.nvim_list_tabpages()
      local tabnr_next = tabpages[tabid_next]
      go(tabnr_next)
    end,
  })
