---@class ux.IBoard
---@field protected _permanent          boolean
---@field protected _wincfg             vim.api.keyset.win_config
---@field protected _winnr              integer|nil
---@field protected _bufnr              integer|nil
---
---@field public name                   string
---@field public focused                boolean
---@field public visible                boolean
---@field public isfocused              fun(): boolean
---@field public isvisible              fun(): boolean
---@field public add_lines              fun(self: ux.IBoard, lines: string[]): nil
---@field public add_highlights         fun(self: ux.IBoard, highlights: std.t.IHighlight[]): nil
---@field public clear                  fun(self: ux.IBoard): nil
---@field public close                  fun(self: ux.IBoard): nil
---@field public focus                  fun(self: ux.IBoard): nil
---@field public hide                   fun(self: ux.IBoard): nil
---@field public resize                 fun(self: ux.IBoard): nil

---@class ux.board.IProps
---@field public permanent              boolean
---@field public wincfg                 vim.api.keyset.win_config

---@class ux.Board : ux.IBoard
local M = {}

---@type vim.api.keyset.win_config
local DEFAULT_WIN_CFG = {
  zindex = dot.var.zindex.BOARD,
  relative = "editor",
  style = "minimal",
  border = "rounded",
  title = " board ",
  focusable = true,
}

---@param props                         ux.board.IProps
---@return ux.Board
function M.new(props)
  local permanent = not not props.permanent ---@type boolean
  local wincfg = vim.tbl_extend("force", {}, DEFAULT_WIN_CFG, props.wincfg) ---@type vim.api.keyset.win_config

  local self = setmetatable({}, {
    __index = function(self, key)
      if key == "visible" then
        local winnr = self._winnr ---@type integer|nil
        local visible = winnr ~= nil and vim.api.nvim_win_is_valid(winnr) ---@type boolean
        return visible
      end

      if key == "focused" then
        local winnr = self._winnr ---@type integer|nil
        local focused = winnr == vim.api.nvim_get_current_win() ---@type boolean
        return focused
      end

      return M[key]
    end,
  })

  self._permanent = permanent
  self._wincfg = wincfg
  return self
end

---@return nil
function M:focus() end

return M
