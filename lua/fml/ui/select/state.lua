local History = require("fml.collection.history")
local Subscriber = require("fml.collection.subscriber")
local Ticker = require("fml.collection.ticker")
local navigate_circular = require("fml.fn.navigate_circular")
local run_async = require("fml.fn.run_async")
local std_array = require("fml.std.array")

---@class fml.ui.select.State : fml.types.ui.select.IState
---@field protected _current_item_lnum  integer
---@field protected _current_item_idx   integer
---@field protected _dirty              boolean
---@field protected _filtering          boolean
---@field protected _full_matches       fml.types.ui.select.ILineMatch[]
---@field protected _matches            fml.types.ui.select.ILineMatch[]
---@field protected _visible            boolean
local M = {}
M.__index = M

---@class fml.ui.select.state.IProps
---@field public uuid                   string
---@field public title                  string
---@field public items                  fml.types.ui.select.IItem[]
---@field public input                  fml.types.collection.IObservable

---@param props                         fml.ui.select.state.IProps
---@return fml.ui.select.State
function M.new(props)
  local self = setmetatable({}, M)

  local uuid = props.uuid ---@type string
  local title = props.title ---@type string
  local items = props.items ---@type fml.types.ui.select.IItem[]
  local input = props.input ---@type fml.types.collection.IObservable
  local input_history = History.new({ name = uuid, capacity = 100 }) ---@type fml.types.collection.IHistory

  local max_width = 0 ---@type integer
  local items_lowercase = {} ---@type string[]
  local full_matches = {} ---@type fml.types.ui.select.ILineMatch[]
  for idx, item in ipairs(items) do
    local text = item.display:lower() ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    local match = { idx = idx, score = 0, pieces = {} } ---@type fml.types.ui.select.ILineMatch
    max_width = max_width < width and width or max_width
    table.insert(items_lowercase, text)
    table.insert(full_matches, match)
  end

  self.uuid = uuid
  self.title = title
  self.input = input
  self.input_history = input_history
  self.items = items
  self.items_lowercase = items_lowercase
  self.max_width = max_width
  self.ticker = Ticker.new({ start = 0 })

  self._current_item_lnum = #full_matches > 0 and 1 or 0
  self._current_item_idx = 0
  self._dirty = true
  self._filtering = false
  self._full_matches = full_matches
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
    local items_lowercase = self.items_lowercase ---@type string[]

    self._dirty = false
    run_async(function()
      local ok, matches = pcall(
        ---@return fml.types.ui.select.ILineMatch[]
        function()
          local N1 = #input ---@type integer
          if N1 < 1 then
            return self._full_matches
          end

          local last_input = self.input_history:present() ---@type string|nil
          local last_input_lower = last_input ~= nil and last_input:lower() or nil ---@type string|nil
          local matches = {} ---@type fml.types.ui.select.ILineMatch[]
          local input_lower = input:lower() ---@type string

          ---@type fml.types.ui.select.ILineMatch[]
          local old_matches = (last_input_lower ~= nil and input_lower:sub(1, #last_input_lower) == input_lower)
              and self._matches
            or self._full_matches

          for _, m in ipairs(old_matches) do
            local idx = m.idx ---@type integer
            local text = items_lowercase[idx] ---@type string

            local l = 1 ---@type integer
            local r = N1 ---@type integer
            local score = 0 ---@type integer
            local pieces = {} ---@type fml.types.ui.select.ILineMatchPiece[]
            local N2 = #text ---@type integer
            while r <= N2 do
              if string.sub(text, l, r) == input_lower then
                table.insert(pieces, { l = l, r = r })
                score = score + 10
                l = r + 1
                r = r + N1
              else
                l = l + 1
                r = r + 1
              end
            end
            if #pieces > 0 then
              local match = { idx = idx, score = score, pieces = pieces } ---@type fml.types.ui.select.ILineMatch
              table.insert(matches, match)
            end
          end

          table.sort(matches, function(a, b)
            if a.score == b.score then
              return a.idx < b.idx
            end
            return a.score > b.score
          end)
          return matches
        end
      )

      if ok and matches then
        ---@type integer|nil
        local current_item_lnum = std_array.first(matches, function(match)
          return match.idx == self._current_item_idx
        end)
        self._matches = matches
        self._current_item_lnum = current_item_lnum or (#matches > 0 and 1 or 0)
      end

      self._filtering = false
      self.input_history:push(input)
      self.ticker:tick()

      if self._dirty then
        self:filter()
      end
    end)
  end, 50)

  return self._matches
end

---@return fml.types.ui.select.IItem|nil
---@return integer|nil
function M:get_current()
  local idx = self._current_item_idx ---@type integer
  if idx > 0 then
    local item = self._full_matches[idx] ---@type fml.types.ui.select.ILineMatch|nil
    if item ~= nil then
      return self.items[item.idx], idx
    end
  end
  if #self.items > 0 then
    return self.items[1], 1
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
  local lnum = navigate_circular(self._current_item_lnum, step, #matches) ---@type integer
  self._current_item_lnum = lnum
  self._current_item_idx = lnum > 0 and matches[lnum].idx or self._current_item_idx
  return lnum
end

---@return integer
function M:moveup()
  local step = vim.v.count1 or 1 ---@type integer
  local matches = self._matches ---@type fml.types.ui.select.ILineMatch[]
  local lnum = navigate_circular(self._current_item_lnum, -step, #matches) ---@type integer
  self._current_item_lnum = lnum
  self._current_item_idx = lnum > 0 and matches[lnum].idx or self._current_item_idx
  return lnum
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
  local items_lowercase = {} ---@type string[]
  local full_matches = {} ---@type fml.types.ui.select.ILineMatch[]
  for idx, item in ipairs(items) do
    local text = item.display:lower() ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    local match = { idx = idx, score = 0, pieces = {} } ---@type fml.types.ui.select.ILineMatch
    max_width = max_width < width and width or max_width
    table.insert(items_lowercase, text)
    table.insert(full_matches, match)
  end

  ---@type integer
  local current_item_lnum = std_array.first(full_matches, function(match)
    return match.idx == self._current_item_idx
  end) or (#full_matches > 0 and 1 or 0)

  self.items = items
  self.items_lowercase = items_lowercase
  self.max_width = max_width
  self._current_item_lnum = current_item_lnum
  self._dirty = true
  self._full_matches = full_matches
  self._matches = full_matches
  self.ticker:tick()
end

return M
