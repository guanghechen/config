local augroup = require("eve.lib.nvim").augroup
local state = require("eve.state")
local ux = require("fml.dressing.hipairs.ux")

local timer = nil ---@type any|nil
local function close_timer()
  if timer ~= nil and timer:is_active() then
    timer:close()
    timer = nil
  end
end

---Initial rendering pairs.
for _, winnr in ipairs(vim.api.nvim_list_wins()) do
  timer = ux.render(winnr)
end

---Start rendering pairs on events.
vim.api.nvim_create_autocmd({
  "BufWinEnter",
  "WinScrolled",
  "ModeChanged",
  "CursorMoved",
  "CursorMovedI",
}, {
  desc = "[fml.dressing.hipairs] render pairs",
  group = augroup("hipairs_render"),
  callback = function()
    close_timer()

    local enabled = state.flight.dressing_hipairs:snapshot() ---@type boolean
    if not enabled then
      return
    end

    local winnr = vim.api.nvim_get_current_win() ---@type integer
    timer = ux.render(winnr)
  end,
})

---Clean `timer` on `VimLeavePre`
vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
  desc = "[fml.dressing.hipairs] cleanup timer",
  group = augroup("hipairs_clear"),
  callback = function()
    close_timer()
  end,
})
