local __module_name__ = "dot.module.explorer.state" ---@type string

---@class dot.module.explorer.state.IProps
---@field public name                   string
---@field public initial_root           ?string
---@field public o_flag_foldempty       ?ark.c.Observable
---@field public o_flag_hidden          ?ark.c.Observable

---@class dot.module.explorer.State
---@field public name                   string
---@field public fullname               string
---@field public o_root_uri             ark.c.Observable
---@field public o_cursor_uri           ark.c.Observable
---@field public o_flag_foldempty       ark.c.Observable
---@field public o_flag_hidden          ark.c.Observable
---@field public prev_root_uri          string|nil
---@field public tick_expanded          integer
---@field public tick_loaded            integer
---@field public tick_selected          integer
local M = {}
M.__index = M

---@param props                         dot.module.explorer.state.IProps
---@return dot.module.explorer.State
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string
  local initial_root = props.initial_root ---@type string|nil

  local default_root = initial_root or dot.path.cwd_uri() ---@type string

  local self = setmetatable({}, M)
  self.name = name
  self.fullname = fullname
  self.o_root_uri = ark.c.Observable.from_value(default_root)
  self.o_cursor_uri = ark.c.Observable.from_value(default_root)
  self.o_flag_foldempty = props.o_flag_foldempty or ark.c.Observable.from_value(true)
  self.o_flag_hidden = props.o_flag_hidden or ark.c.Observable.from_value(false)
  self.prev_root_uri = nil
  self.tick_expanded = 1
  self.tick_loaded = 1
  self.tick_selected = 0
  return self
end

---@return integer
function M:next_tick_expanded_odd()
  local tick = self.tick_expanded ---@type integer
  if tick % 2 == 0 then
    tick = tick + 1
    self.tick_expanded = tick
  end
  return tick
end

---@return integer
function M:next_tick_expanded_even()
  local tick = self.tick_expanded ---@type integer
  if tick % 2 == 1 then
    tick = tick + 1
    self.tick_expanded = tick
  end
  return tick
end

---@return integer
function M:advance_tick_expanded()
  self.tick_expanded = self.tick_expanded + 1
  return self.tick_expanded
end

---@return integer
function M:advance_tick_loaded()
  self.tick_loaded = self.tick_loaded + 1
  return self.tick_loaded
end

---@return integer
function M:next_tick_selected_odd()
  local tick = self.tick_selected ---@type integer
  if tick % 2 == 0 then
    tick = tick + 1
    self.tick_selected = tick
  end
  return tick
end

---@return integer
function M:next_tick_selected_even()
  local tick = self.tick_selected ---@type integer
  if tick % 2 == 1 then
    tick = tick + 1
    self.tick_selected = tick
  end
  return tick
end

---@return integer
function M:advance_tick_selected()
  self.tick_selected = self.tick_selected + 1
  return self.tick_selected
end

return M
