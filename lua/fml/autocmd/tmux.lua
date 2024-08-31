local std_tmux = require("fml.std.tmux")
local global = require("fml.global")

if vim.env.TMUX then
  local function on_resize()
    local is_tmux_pane_zoomed = std_tmux.is_tmux_pane_zoomed() ---@type boolean
    global.observable_zen_mode:next(is_tmux_pane_zoomed)
  end

  on_resize()
  vim.api.nvim_create_autocmd({ "VimResized" }, {
    callback = on_resize,
  })
end
