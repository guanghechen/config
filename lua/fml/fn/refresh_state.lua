local api_buf = require("fml.api.buf")
local api_tab = require("fml.api.tab")
local api_win = require("fml.api.win")

---@return nil
local function refresh_state()
  api_buf.refresh_all()
  api_tab.refresh_all()
  api_win.refresh_all()
  api_buf.remove_unrefereced_bufs()
end

return eve.fn.schedule("fml.fn.refresh_state", refresh_state, 16)
