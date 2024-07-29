local Subscriber = require("fml.collection.subscriber")
local Ticker = require("fml.collection.ticker")
local navigate = require("fml.std.navigate")
local std_array = require("fml.std.array")
local oxi = require("fml.std.oxi")
local util = require("fml.std.util")
local defaults = require("fml.ui.select.defaults")

---@class fml.ui.select.State : fml.types.ui.select.IState
---@field protected _cmp                fml.types.ui.select.ILineMatchCmp
---@field protected _match              fml.types.ui.select.IMatch
---@field protected _current_item_lnum  integer
---@field protected _current_item_idx   integer
---@field protected _dirty              boolean
---@field protected _frecency           fml.types.collection.IFrecency|nil
---@field protected _filtering          boolean
---@field protected _full_matches       fml.types.ui.select.ILineMatch[]
---@field protected _last_input         string|nil
---@field protected _last_input_lower   string|nil
---@field protected _matches            fml.types.ui.select.ILineMatch[]
---@field protected _visible            boolean
local M = {}
M.__index = M

---@class fml.ui.select.state.IProps
---@field public title                  string
---@field public items                  fml.types.ui.select.IItem[]
---@field public input                  fml.types.collection.IObservable
---@field public input_history          ?fml.types.collection.IHistory
---@field public frecency               ?fml.types.collection.IFrecency
---@field public cmp                    ?fml.types.ui.select.ILineMatchCmp
---@field public match                  ?fml.types.ui.select.IMatch

---@param props                         fml.ui.select.state.IProps
---@return fml.ui.select.State
function M.new(props)
  local self = setmetatable({}, M)

  local uuid = oxi.uuid() ---@type string
  local title = props.title ---@type string
  local items = props.items ---@type fml.types.ui.select.IItem[]
  local input = props.input ---@type fml.types.collection.IObservable
  local input_history = props.input_history ---@type fml.types.collection.IHistory|nil
  local frecency = props.frecency ---@type fml.types.collection.IFrecency|nil
  local cmp = props.cmp or defaults.line_match_cmp ---@type fml.types.ui.select.ILineMatchCmp
  local match = props.match or defaults.match ---@type fml.types.ui.select.IMatch

  local max_width = 0 ---@type integer
  local full_matches = {} ---@type fml.types.ui.select.ILineMatch[]
  for idx, item in ipairs(items) do
    local text = item.lower ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    local m = { idx = idx, score = frecency and frecency:score(item.uuid) or 0, pieces = {} } ---@type fml.types.ui.select.ILineMatch
    max_width = max_width < width and width or max_width ---@type integer
    table.insert(full_matches, m)
  end
  table.sort(full_matches, cmp)

  self.uuid = uuid
  self.title = title
  self.input = input
  self.items = items
  self.max_width = max_width
  self.ticker = Ticker.new({ start = 0 })

  self._cmp = cmp
  self._match = match
  self._current_item_lnum = #full_matches > 0 and 1 or 0
  self._current_item_idx = 0
  self._dirty = true
  self._filtering = false
  self._frecency = frecency
  self._full_matches = full_matches
  self.input_history = input_history
  self._last_input = nil
  self._last_input_lower = nil
  self._matches = full_matches
  self._visible = false

  input:subscribe(Subscriber.new({
    on_next = function()
      ---@diagnostic disable-next-line: invisible
      self._dirty = true
      self:filter()
    end,
  }))
  return self
end

---@return fml.types.ui.select.ILineMatch[]
function M:filter()
  if self._filtering or not self._visible or not self._dirty then
    return self._matches
  end

  self._filtering = true
  vim.defer_fn(function()
    local input = self.input:snapshot() ---@type string
    local input_lower = input:lower() ---@type string
    local items = self.items ---@type fml.types.ui.select.IItem[]

    self._dirty = false
    util.run_async(
      "fml.ui.select.state:filter",
      ---@return fml.types.ui.select.ILineMatch[]
      function()
        if #input < 1 then
          return self._full_matches
        end

        local last_input_lower = self._last_input_lower ---@type string|nil

        ---@type fml.types.ui.select.ILineMatch[]
        local result = (
          last_input_lower ~= nil
          and #input_lower > #last_input_lower
          and input_lower:sub(1, #last_input_lower) == last_input_lower
        )
            and self._match(input_lower, items, self._matches)
          or self._match(input_lower, items, self._full_matches)
        return result
      end,
      function(ok, matches)
        if ok and matches then
          if self._frecency ~= nil then
            local frecency = self._frecency ---@type fml.types.collection.IFrecency
            for _, match in ipairs(matches) do
              local item = items[match.idx] ---@type fml.types.ui.select.IItem
              match.score = match.score + frecency:score(item.uuid)
            end
          end
          table.sort(matches, self._cmp)

          ---@type integer|nil
          local lnum = std_array.first(matches, function(match)
            return match.idx == self._current_item_idx
          end)

          self._current_item_lnum = lnum or (#matches > 0 and 1 or 0)
          self._current_item_idx = lnum ~= nil and matches[lnum].idx or 0
          self._last_input = input
          self._last_input_lower = input_lower
          self._matches = matches
        end

        self._filtering = false
        self.ticker:tick()

        if self._dirty then
          self:filter()
        end
      end
    )
  end, 50)

  return self._matches
end

---@return fml.types.ui.select.IItem|nil
---@return integer|nil
function M:get_current()
  local lnum = self._current_item_lnum ---@type integer
  if lnum > 0 then
    local match = self._matches[lnum] ---@type fml.types.ui.select.ILineMatch|nil
    if match ~= nil then
      local idx = match.idx ---@type integer
      return self.items[idx], idx
    end
  end
end

---@return integer
function M:get_lnum()
  return self._current_item_lnum
end

---@return boolean
function M:is_visible()
  return self._visible
end

---@param lnum                          integer
---@return integer
function M:locate(lnum)
  local matches = self._matches ---@type fml.types.ui.select.ILineMatch[]
  lnum = math.max(0, math.min(#matches, lnum)) ---@type integer
  self._current_item_lnum = lnum
  self._current_item_idx = lnum > 0 and matches[lnum].idx or self._current_item_idx
  return lnum
end

---@return integer
function M:movedown()
  local step = vim.v.count1 or 1 ---@type integer
  local matches = self._matches ---@type fml.types.ui.select.ILineMatch[]
  local lnum = navigate.circular(self._current_item_lnum, step, #matches) ---@type integer
  self._current_item_lnum = lnum
  self._current_item_idx = lnum > 0 and matches[lnum].idx or self._current_item_idx
  return lnum
end

---@return integer
function M:moveup()
  local step = vim.v.count1 or 1 ---@type integer
  local matches = self._matches ---@type fml.types.ui.select.ILineMatch[]
  local lnum = navigate.circular(self._current_item_lnum, -step, #matches) ---@type integer
  self._current_item_lnum = lnum
  self._current_item_idx = lnum > 0 and matches[lnum].idx or self._current_item_idx
  return lnum
end

---@param item                          fml.types.ui.select.IItem
---@return nil
function M:on_confirmed(item)
  local last_input = self._last_input
  if last_input ~= nil then
    if self._frecency ~= nil then
      self._frecency:access(item.uuid)
    end
    if self.input_history ~= nil then
      self.input_history:push(last_input)
    end
  end
end

---@param visible                       ?boolean
---@return nil
function M:toggle_visible(visible)
  if visible ~= nil then
    self._visible = visible
  else
    local next_visible = not self._visible ---@type boolean
    self._visible = next_visible
  end
  self:filter()
end

---@param items                         fml.types.ui.select.IItem[]
---@return nil
function M:update_items(items)
  local max_width = 0 ---@type integer
  local full_matches = {} ---@type fml.types.ui.select.ILineMatch[]
  if self._frecency ~= nil then
    local frecency = self._frecency ---@type fml.types.collection.IFrecency
    for idx, item in ipairs(items) do
      local text = item.display:lower() ---@type string
      local width = vim.fn.strwidth(text) ---@type integer
      local match = { idx = idx, score = frecency:score(item.uuid), pieces = {} } ---@type fml.types.ui.select.ILineMatch
      max_width = max_width < width and width or max_width
      table.insert(full_matches, match)
    end
  else
    for idx, item in ipairs(items) do
      local text = item.display:lower() ---@type string
      local width = vim.fn.strwidth(text) ---@type integer
      local match = { idx = idx, score = 0, pieces = {} } ---@type fml.types.ui.select.ILineMatch
      max_width = max_width < width and width or max_width
      table.insert(full_matches, match)
    end
  end
  table.sort(full_matches, self._cmp)

  ---@type integer|nil
  local lnum = std_array.first(full_matches, function(match)
    return match.idx == self._current_item_idx
  end)

  self.items = items
  self.max_width = max_width
  self._current_item_lnum = lnum or (#full_matches > 0 and 1 or 0)
  self._current_item_idx = lnum ~= nil and full_matches[lnum].idx or 0
  self._dirty = true
  self._full_matches = full_matches
  self._matches = full_matches
  self.ticker:tick()
end

return M
