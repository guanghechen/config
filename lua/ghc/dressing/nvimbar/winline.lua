local functional = require("eve.lib.functional")
local Subscriber = require("eve.lib.collection.subscriber")
local Nvimbar = require("eve.lib.ux.nvimbar")
local constant = require("eve.builtin.constant")
local status = require("eve.builtin.status")
local state = require("eve.state")
local c = require("ghc.dressing.nvimbar.components")

local devmode = state.state.flight.devmode:snapshot() ---@type boolean
local rendering_winnr = 0 ---@type integer

local winline ---@type eve.lib.ux.INvimbar
winline = Nvimbar.new({
  name = "winline",
  component_sep = "",
  component_sep_hlname = "f_sl_bg",
  component_sep_hlname_active = "f_sl_bg",
  render_delay = 0,
  silent = not devmode,
  get_max_width = function()
    return vim.api.nvim_win_get_width(rendering_winnr)
  end,
  get_preset_context = function()
    return { winnr = rendering_winnr }
  end,
  is_active = function(context)
    local winnr_cur = eve.tab.get_current_winnr() or 0 ---@type integer
    return winnr_cur > 0 and winnr_cur == context.winnr
  end,
  trigger_rerender = functional.noop,
  validate = functional.noop,
})

winline
  ---
  :register(c.win_indicator(), "left")
  :register(c.dirpath(), "left")
  :register(c.filename(), "left")
  :register(c.lsp_symbols(), "left")
  ---
  :register(c.debug_render_count(), "center")

---@param winnr                         integer
---@return boolean
local function should_show_winline(winnr)
  if winnr < 1 or not vim.api.nvim_win_is_valid(winnr) or eve.checks.is_win_floating(winnr) then
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if filepath:sub(1, 9) == "diffview:" then
    return filepath:sub(1, 19) ~= "diffview:///panels/"
  end

  if not eve.checks.is_buf_valid(bufnr) then
    return false
  end

  return true
end

status.winline_dirty_nr:subscribe(
  Subscriber.new({
    on_next = function(winnr)
      if should_show_winline(winnr) then
        if vim.w[winnr][constant.V_WINLINE_UPDATING] then
          vim.w[winnr][constant.V_WINLINE_DIRTY] = true
          return
        end

        vim.w[winnr][constant.V_WINLINE_UPDATING] = true
        vim.w[winnr][constant.V_WINLINE_DIRTY] = false

        pcall(function()
          rendering_winnr = winnr
          local result = winline:render_sync() ---@type string
          vim.wo[winnr].winbar = result
        end)

        vim.defer_fn(function()
          vim.w[winnr][constant.V_WINLINE_UPDATING] = false
        end, 128)
      end
    end,
  }),
  true
)
