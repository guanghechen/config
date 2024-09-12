---@param winnr                         integer
local function should_show_winline(winnr)
  if fml.api.state.is_floating_win(winnr) then
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if not eve.locations.is_listed_buf(bufnr) then
    return false
  end

  return true
end

local winline_map = {} ---@type table<string, fml.types.ui.INvimbar>

---@class ghc.ui.winline
local M = {}

---@param winnr                         integer
---@param force                         boolean
---@return string
function M.render(winnr, force)
  if not should_show_winline(winnr) then
    return ""
  end

  local winline = winline_map[winnr] ---@type fml.types.ui.INvimbar
  if winline == nil then
    winline = fml.ui.Nvimbar.new({
      name = "winline_" .. winnr,
      component_sep = "",
      component_sep_hlname = "f_wl_bg",
      preset_context = { winnr = winnr },
      get_max_width = function()
        return vim.api.nvim_win_get_width(winnr)
      end,
      trigger_rerender = function()
        vim.schedule(function()
          M.update(winnr, false)
        end)
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
      winline:register(name, require("ghc.ui.winline.component." .. name))
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
          from = "ghc.ui.winline",
          subject = "update",
          message = "Failed to update winbar.",
          details = { winnr = winnr, result = result, err = err },
        })
      end
    end
  end
end

fml.api.state.winline_dirty_nr:subscribe(
  eve.c.Subscriber.new({
    on_next = function(winnr)
      if winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
        M.update(winnr, true)
      end
    end,
  }),
  true
)

return M
