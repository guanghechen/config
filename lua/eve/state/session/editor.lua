---@class eve.state.editor.data
---@field public winnr_command          integer|nil
---@field public winnr_fixed            integer|nil

---@class eve.state.editor.state
---@field public winnr_command          eve.collection.IObservable -- integer|nil>
---@field public winnr_fixed            eve.collection.IObservable -- integer|nil>
---
---@field public focus_win_fixed        fun(): nil
---@field public get_winnr_fixed        fun(): integer|nil
---@field public get_winnr_command      fun(): integer|nil
---@field public set_winnr_fixed        fun(winnr: integer|nil): nil
---@field public set_winnr_command      fun(winnr: integer|nil): nil
---
---@field public on_refresh             fun(): nil
---@field public on_win_enter           fun(winnr: integer): nil

---@class eve.state.editor : eve.state.editor.state
---@field public defaults               fun(): eve.state.editor.data
---@field public dump                   fun(): eve.state.editor.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.state.editor.data
local M = {}

---@return eve.state.editor.data
function M.defaults()
  ---@type eve.state.editor.data
  return {
    winnr_command = 0,
    winnr_fixed = 0,
  }
end

---@param data                        any
---@return eve.state.editor.data
---@diagnostic disable-next-line: unused-local
function M.normalize(data)
  return M.defaults() ---@type eve.state.editor.data
end

---@return eve.state.editor.data
function M.dump()
  ---@type eve.state.editor.data
  return {
    winnr_command = M.winnr_command:snapshot(),
    winnr_fixed = M.winnr_fixed:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  ---@diagnostic disable-next-line: unused-local
  local data = M.normalize(raw_data) ---@type eve.state.editor.data
  M.winnr_command:next(data.winnr_command)
  M.winnr_fixed:next(data.winnr_fixed)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.state.editor.data
M.winnr_command = eve.col.Observable.from_value(_defaults.winnr_command)
M.winnr_fixed = eve.col.Observable.from_value(_defaults.winnr_fixed)

---@return nil
function M.focus_win_fixed()
  local winnr_fixed = M.get_winnr_fixed()
  if winnr_fixed ~= nil then
    vim.api.nvim_set_current_win(winnr_fixed)
  end
end

---@return integer|nil
function M.get_winnr_command()
  local winnr_command = M.winnr_command:snapshot() ---@type integer
  if winnr_command ~= 0 and eve.editor.is_win_valid(winnr_command) then
    return winnr_command
  else
    M.winnr_command:next(0)
    return nil
  end
end

---@return integer|nil
function M.get_winnr_fixed()
  local winnr_fixed = M.winnr_fixed:snapshot() ---@type integer
  if winnr_fixed ~= 0 and eve.editor.is_win_valid(winnr_fixed) then
    return winnr_fixed
  else
    M.winnr_fixed:next(0)
    return nil
  end
end

---@param winnr                         integer|nil
---@return nil
function M.set_winnr_command(winnr)
  if winnr == nil then
    M.winnr_command:next(0)
    return
  end
  if eve.editor.is_win_valid(winnr) then
    M.winnr_command:next(winnr)
  end
end

---@param winnr                         integer|nil
---@return nil
function M.set_winnr_fixed(winnr)
  if winnr == nil then
    M.winnr_fixed:next(0)
    return
  end
  if eve.editor.is_win_valid(winnr) then
    M.winnr_fixed:next(winnr)
  end
end

---@return nil
function M.on_refresh()
  local winnr_fixed = eve.editor.find_winnr_fixed() or 0 ---@type integer
  M.winnr_fixed:next(winnr_fixed or 0)
end

---@param winnr                         integer
---@return nil
function M.on_win_enter(winnr)
  if not eve.editor.is_win_floating(winnr) then
    M.winnr_fixed:next(winnr)
  end
end

return M
