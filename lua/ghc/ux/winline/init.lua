local Subscriber = require("eve.collection.subscriber")

local winline_map = {} ---@type table<string, fml.t.ux.INvimbar>

---@class ghc.ux.winline
local M = {}

---@param winnr                         integer
---@return boolean
function M.should_show_winline(winnr)
  if eve.win.is_floating(winnr) then
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if filepath:sub(1, 9) == "diffview:" then
    return filepath:sub(1, 19) ~= "diffview:///panels/"
  end

  if not eve.buf.is_listed(bufnr) then
    return false
  end

  return true
end

---@param winnr                         integer
---@param force                         boolean
---@return string
function M.render(winnr, force)
  if not M.should_show_winline(winnr) then
    return ""
  end

  local winline = winline_map[winnr] ---@type fml.t.ux.INvimbar
  if winline == nil then
    local devmode = eve.context.state.flight.devmode:snapshot() ---@type boolean
    winline = fml.ux.Nvimbar.new({
      name = "winline_" .. winnr,
      component_sep = "",
      component_sep_hlname = "f_wl_bg",
      component_sep_hlname_active = "f_wla_bg",
      preset_context = { winnr = winnr },
      render_delay = 32,
      silent = not devmode,
      get_max_width = function()
        return vim.api.nvim_win_get_width(winnr)
      end,
      is_active = function(context)
        local winnr_cur = fml.api.tab.get_current_winnr() ---@type integer
        return winnr_cur == context.winnr
      end,
      trigger_rerender = function()
        vim.schedule(function()
          M.update(winnr, false)
        end)
      end,
      validate = function()
        if winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
          return nil
        else
          return "The window is not valid, winnr=" .. winnr .. "."
        end
      end,
    })
    winline_map[winnr] = winline

    local c = {
      dirpath = "dirpath",
      filename = "filename",
      indicator = "indicator",
      lsp = "lsp",
    }
    for _, name in pairs(c) do
      winline:register(name, require("ghc.ux.winline.component." .. name))
    end

    winline
      ---
      :place(c.indicator, "left")
      :place(c.dirpath, "left")
      :place(c.filename, "left")
      :place(c.lsp, "left")
  end
  return winline:render(force)
end

---@param winnr                         integer
---@param force                         boolean
---@return nil
function M.update(winnr, force)
  if vim.api.nvim_win_is_valid(winnr) then
    local result = M.render(winnr, force) ---@type string
    if #result > 0 then
      local ok, err = pcall(function()
        vim.wo[winnr].winbar = result
      end)
      if not ok then
        eve.reporter.error({
          from = "ghc.ux.winline",
          subject = "update",
          message = "Failed to update winbar.",
          details = { winnr = winnr, result = result, err = err },
        })
      end
    end
  end
end

eve.context.state.status.winline_dirty_nr:subscribe(
  Subscriber.new({
    on_next = function(winnr)
      if winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
        M.update(winnr, true)
      end
    end,
  }),
  true
)

return M
