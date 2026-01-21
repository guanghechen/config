---@diagnostic disable: invisible

local S = era.m.notepad

local DEFAULT_WIDTH = 0.6
local DEFAULT_HEIGHT = 0.6
local MAX_WIDTH = 0.9
local MAX_HEIGHT = 0.9
local MIN_WIDTH = 60
local MIN_HEIGHT = 12
local WIN_TITLE = " Notepad "
local NOTEPAD_WIN_HIGHLIGHT =
  "CursorLine:f_np_cursorline,CursorLineNr:f_np_cursorline,FloatBorder:FloatBorder,FloatTitle:f_np_title,LineNr:f_np_normal,Normal:f_np_normal,SignColumn:f_np_normal"
local TEXT_CHANGED_EVENTS = { "TextChanged", "TextChangedI", "TextChangedP" }
local DEFAULT_ITEM_NAME = dot.var.BUF_UNTITLED
local BUFFER_VAR_NAME = "eve_notepad_uuid"

local K = dot.command.definitions

---@type stl.t.IKeymap[]
local NOTEPAD_KEYMAPS = {
  {
    modes = { "i", "n", "x" },
    key = "<C-s>",
    desc = K.notepad.save.desc,
    callback = function()
      K.notepad.save:execute()
    end,
  },
  {
    modes = { "i", "n", "x" },
    key = "<C-a>s",
    aliases = { "<D-s>", "<M-s>" },
    desc = K.notepad.save.desc,
    callback = function()
      K.notepad.save:execute()
    end,
  },
  {
    modes = { "n" },
    key = "q",
    desc = K.notepad.close.desc,
    callback = function()
      K.notepad.close:execute()
    end,
  },
  {
    modes = { "i", "n", "x" },
    key = "<C-n>",
    desc = K.notepad.rename.desc,
    callback = function()
      K.notepad.rename:execute()
    end,
  },
  {
    modes = { "n" },
    key = "<leader><cr>",
    desc = K.ai.submit_buffer.desc,
    callback = function()
      K.ai.submit_buffer:execute()
    end,
  },
  {
    modes = { "x" },
    key = "<leader><cr>",
    desc = K.ai.submit_selection.desc,
    callback = function()
      K.ai.submit_selection:execute()
    end,
  },
  {
    modes = { "i", "n", "x" },
    key = "<C-/>",
    desc = K.notepad.create.desc,
    callback = function()
      K.notepad.create:execute()
    end,
  },
  {
    modes = { "i", "n", "x" },
    key = "<C-d>",
    desc = K.notepad.destroy.desc,
    callback = function()
      K.notepad.destroy:execute()
    end,
  },
  {
    modes = { "n" },
    key = "<leader>dd",
    desc = K.notepad.destroy.desc,
    callback = function()
      K.notepad.destroy:execute()
    end,
  },
  {
    modes = { "i", "n", "x" },
    key = "<C-,>",
    desc = K.notepad.source_prev.desc,
    callback = function()
      K.notepad.source_prev:execute()
    end,
  },
  {
    modes = { "i", "n", "x" },
    key = "<C-.>",
    desc = K.notepad.source_next.desc,
    callback = function()
      K.notepad.source_next:execute()
    end,
  },
  {
    modes = { "i", "n", "x" },
    key = "<C-[>",
    desc = K.notepad.focus_left.desc,
    callback = function()
      K.notepad.focus_left:execute()
    end,
  },
  {
    modes = { "i", "n", "x" },
    key = "<C-]>",
    desc = K.notepad.focus_right.desc,
    callback = function()
      K.notepad.focus_right:execute()
    end,
  },
  {
    modes = { "n", "x" },
    key = "<leader>[",
    desc = K.notepad.focus_left.desc,
    callback = function()
      K.notepad.focus_left:execute()
    end,
  },
  {
    modes = { "n", "x" },
    key = "<leader>]",
    desc = K.notepad.focus_right.desc,
    callback = function()
      K.notepad.focus_right:execute()
    end,
  },
  {
    modes = { "i", "n", "x" },
    key = "<C-S-,>",
    aliases = { "<C-S-[>" },
    desc = K.notepad.swap_left.desc,
    callback = function()
      K.notepad.swap_left:execute()
    end,
  },
  {
    modes = { "i", "n", "x" },
    key = "<C-S-.>",
    aliases = { "<C-S-]>" },
    desc = K.notepad.swap_right.desc,
    callback = function()
      K.notepad.swap_right:execute()
    end,
  },
  {
    modes = { "n", "x" },
    key = "<leader>0",
    desc = K.notepad.change_engine.desc,
    callback = function()
      K.notepad.change_engine:execute()
    end,
  },
  {
    modes = { "n", "x" },
    key = "<leader>1",
    desc = K.notepad.source_select.desc,
    callback = function()
      K.notepad.source_select:execute()
    end,
  },
  {
    modes = { "n", "x" },
    key = "<leader>2",
    desc = K.notepad.note_select.desc,
    callback = function()
      K.notepad.note_select:execute()
    end,
  },
  {
    modes = { "i", "n", "x" },
    key = "<M-i>",
    desc = K.notepad.go_backward.desc,
    callback = function()
      K.notepad.go_backward:execute()
    end,
  },
  {
    modes = { "i", "n", "x" },
    key = "<M-o>",
    desc = K.notepad.go_forward.desc,
    callback = function()
      K.notepad.go_forward:execute()
    end,
  },
  {
    modes = { "i", "n", "x" },
    key = "<esc>",
    desc = "notepad: feedback esc to notepad (fix the conflict caused by the csi u)",
    expr = true,
    replace_keycodes = true,
    callback = function()
      return "<esc>"
    end,
  },
}

for index = 1, 9 do
  local definition = K.notepad["focus_" .. tostring(index)]
  NOTEPAD_KEYMAPS[#NOTEPAD_KEYMAPS + 1] = {
    modes = { "i", "n", "x" },
    key = string.format("<C-%d>", index),
    desc = definition.desc,
    callback = function()
      definition:execute()
    end,
  }
end

for index = 1, 9 do
  local definition_left = K.notepad["focus_left_" .. tostring(index)]
  NOTEPAD_KEYMAPS[#NOTEPAD_KEYMAPS + 1] = {
    modes = { "n", "x" },
    key = string.format("[%d", index),
    desc = definition_left.desc,
    callback = function()
      definition_left:execute()
    end,
  }

  local definition_right = K.notepad["focus_right_" .. tostring(index)]
  NOTEPAD_KEYMAPS[#NOTEPAD_KEYMAPS + 1] = {
    modes = { "n", "x" },
    key = string.format("]%d", index),
    desc = definition_right.desc,
    callback = function()
      definition_right:execute()
    end,
  }
end

---@class era.m.notepad.view.IProps
---@field public name                   ?string
---@field public title                  ?string
---@field public bufname                ?string
---@field public width                  ?number
---@field public height                 ?number
---@field public max_width              ?number
---@field public max_height             ?number
---@field public min_width              ?number
---@field public min_height             ?number
---@field public filetype               ?string
---@field public win_opts               ?table<string, any>
---@field public source                 ?era.m.notepad.state.INotepadSource

---@class era.m.notepad.View : dot.t.IWidget
---@field public name                   string|nil
---@field protected title               string
---@field protected bufname             string
---@field protected width               number
---@field protected height              number
---@field protected max_width           number
---@field protected max_height          number
---@field protected min_width           number
---@field protected min_height          number
---@field protected filetype            string
---@field protected win_opts            table<string, any>
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _suspend_sync       boolean
---@field protected _buf_autocmds       integer[]
---@field protected _nvimbar            era.m.nvimbar.Nvimbar|nil
---@field protected _subscription_active stl.c.IUnsubscribable|nil
---@field protected _subscription_winbar stl.c.IUnsubscribable|nil
---@field protected _subscription_source stl.c.IUnsubscribable|nil
local M = {}
M.__index = M

---@param props                         era.m.notepad.view.IProps|nil
---@return era.m.notepad.View
function M.new(props)
  props = props or {}

  local self = setmetatable({}, M)
  self.name = props.name or "notepad"
  self.title = props.title or WIN_TITLE
  self.bufname = props.bufname or "Notepad"
  self.width = props.width or DEFAULT_WIDTH
  self.height = props.height or DEFAULT_HEIGHT
  self.max_width = props.max_width or MAX_WIDTH
  self.max_height = props.max_height or MAX_HEIGHT
  self.min_width = props.min_width or MIN_WIDTH
  self.min_height = props.min_height or MIN_HEIGHT
  self.filetype = props.filetype or stl.filetype.NOTEPAD
  self.win_opts = vim.tbl_extend("force", { winhighlight = NOTEPAD_WIN_HIGHLIGHT }, props.win_opts or {})
  self._bufnr = nil
  self._winnr = nil
  self._suspend_sync = false
  self._buf_autocmds = {}

  local source_name = dot.context.module.notepad_source:snapshot() ---@type string
  local source = S.state.retrieve_source(source_name) ---@type era.m.notepad.state.INotepadSource

  source:load(false)

  self:__setup_subscriptions__()
  self:__setup_nvimbar__()

  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__setup_subscriptions__()
  self._subscription_active = S.state.o_activated_uuid:subscribe(
    stl.c.Subscriber.new({
      on_next = function(next_uuid)
        self:__on_active_uuid_changed__(next_uuid)
      end,
    }),
    false
  )

  self._subscription_winbar = dot.state.status.dirtier_notepadline:subscribe(
    stl.c.Subscriber.new({
      on_next = function()
        if self._nvimbar ~= nil then
          self._nvimbar:render()
        end
      end,
    }),
    true
  )

  self._subscription_source = dot.context.module.notepad_source:subscribe(
    stl.c.Subscriber.new({
      on_next = function(source_name)
        self:attach(source_name)
      end,
    }),
    false
  )
end

---@protected
---@return nil
function M:__setup_nvimbar__()
  local widget = self
  self._nvimbar = era.m.nvimbar.Nvimbar
    .new({
      name = string.format("%s.winbar", self.name),
      comp_sep = "",
      comp_sep_hlname = "f_wl_bg",
      comp_sep_hlname_active = "f_wl_bg",
      delay = 128,
      get_max_width = function()
        local winnr = widget._winnr
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          return math.max(0, vim.api.nvim_win_get_width(winnr))
        end
        return vim.o.columns - 2
      end,
      get_preset_context = function()
        return { winnr = widget._winnr }
      end,
      is_active = function()
        return widget._winnr ~= nil and vim.api.nvim_win_is_valid(widget._winnr)
      end,
      on_fulfilled = function(result)
        local winnr = widget._winnr
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          vim.api.nvim_set_option_value("winbar", result, { win = winnr, scope = "local" })
        end
      end,
    })
    :place("left", era.m.nvimbar.component.notepad.items("f_wl", widget), 95)
    :place("left", era.m.nvimbar.component.notepad.add_button("f_wl"), 100)
    :place("right", era.m.nvimbar.component.notepad.source("f_wl", widget), 100)
end

---@protected
---@return era.m.notepad.state.INotepadSourceState
function M:__ensure_state__()
  local source = self:get_source()
  return source:load(false)
end

---@protected
---@return nil
function M:__notify_active_changed__()
  local source = self:get_source()
  local uuid = source:get_activated_uuid()
  S.state.focus_note(uuid)
end

---@protected
---@return nil
function M:__mark_dirty__()
  dot.state.status.dirtier_notepadline:mark_dirty()
end

---@protected
---@return nil
function M:__mark_orders_dirty__()
  local source = self:get_source()
  source:mark_orders_dirty()
  self:__mark_dirty__()
end

---@protected
---@return nil
function M:__mark_active_dirty__()
  local source = self:get_source()
  source:mark_active_dirty()
  self:__mark_dirty__()
end

---@return string
function M:get_filepath()
  local source = self:get_source() ---@type era.m.notepad.state.INotepadSource
  return source.filepath or ""
end

---@return era.m.notepad.state.INotepadSource
function M:get_source()
  local source_name = dot.context.module.notepad_source:snapshot() ---@type string
  local source = S.state.retrieve_source(source_name)
  return source
end

---@param source_name                   string
---@return nil
function M:attach(source_name)
  local current_source = self:get_source()
  if current_source.name == source_name then
    return
  end

  local bufnr = self:get_bufnr()
  if bufnr ~= nil then
    self:__sync_content_from_buf__(bufnr, current_source:get_activated_uuid())
  end

  self:flush()

  dot.context.module.notepad_source:next(source_name)

  local new_source = S.state.retrieve_source(source_name)
  local new_uuid = new_source:get_activated_uuid()
  S.state.focus_note(new_uuid)

  if bufnr ~= nil then
    self:__render_active_item__(bufnr)
  end

  local winnr = self:get_winnr()
  if winnr ~= nil then
    local current_config = vim.api.nvim_win_get_config(winnr)
    current_config.title = self:__get_window_title__()
    vim.api.nvim_win_set_config(winnr, current_config)
  end

  self:__mark_dirty__()

  if self._nvimbar ~= nil then
    self._nvimbar:render()
  end
end

---@return integer
function M:size()
  return #self:__ensure_state__().orders
end

---@param uuid                          string|nil
---@return integer
function M:indexof(uuid)
  if uuid == nil then
    return -1
  end
  local state = self:__ensure_state__()
  for index, target in ipairs(state.orders) do
    if target == uuid then
      return index
    end
  end
  return -1
end

---@param index                         integer
---@return string|nil, era.m.notepad.state.INotepadItemState|nil
function M:at(index)
  local state = self:__ensure_state__()
  local uuid = state.orders[index]
  return uuid, uuid and state.items[uuid] or nil
end

---@return integer, string|nil
function M:current()
  local source = self:get_source()
  local active_uuid = source:get_activated_uuid()
  return self:indexof(active_uuid), active_uuid
end

---@return era.m.notepad.state.INotepadItemState|nil
function M:current_item()
  local source = self:get_source()
  local active_uuid = source:get_activated_uuid()
  if active_uuid == nil then
    return nil
  end
  return source:retrieve(active_uuid, false)
end

---@param uuid                          string
---@return era.m.notepad.state.INotepadItemState|nil
function M:get(uuid)
  local source = self:get_source()
  return source:retrieve(uuid, false)
end

---@return fun():era.m.notepad.state.INotepadItemState|nil, integer|nil
function M:iterator()
  local state = self:__ensure_state__()
  local index = 0
  return function()
    index = index + 1
    local uuid = state.orders[index]
    return uuid and state.items[uuid] or nil, uuid and index or nil
  end
end

---@param uuid                          string|nil
---@return boolean
function M:focus_uuid(uuid)
  if uuid == nil then
    return false
  end

  local source = self:get_source()

  -- Check if already focused
  if source:get_activated_uuid() == uuid then
    return true
  end

  -- Save the current buffer content before switching
  local bufnr = self:get_bufnr()
  if bufnr ~= nil then
    local old_uuid = source:get_activated_uuid()
    if old_uuid ~= nil then
      self:__sync_content_from_buf__(bufnr, old_uuid)
    end
  end

  -- Push to history before changing focus
  source:push_history(uuid)

  -- Use state's focus_note to update source and notify observers
  return S.state.focus_note(uuid)
end

---@param index                         integer
---@return boolean
function M:focus_index(index)
  local uuid = self:__ensure_state__().orders[index]
  return uuid ~= nil and self:focus_uuid(uuid) or false
end

---@param step                          integer
---@return boolean
function M:focus_step(step)
  local state = self:__ensure_state__()
  local count = #state.orders
  if count == 0 then
    return false
  end
  local source = self:get_source()
  local active_uuid = source:get_activated_uuid()
  local index_current = math.max(1, self:indexof(active_uuid))
  local index_next = stl.fn.navigate_circular(index_current, step, count)
  return self:focus_index(index_next)
end

---@param name                          string|nil
---@return era.m.notepad.state.INotepadItemState
function M:create(name)
  local trimmed = type(name) == "string" and vim.trim(name) or nil
  local source = self:get_source()
  local item = source:create(#(trimmed or "") > 0 and trimmed or nil, nil)
  self:__mark_dirty__()
  self:focus_uuid(item.uuid)
  return item
end

---@param name                          string
---@return era.m.notepad.state.INotepadItemState|nil
function M:find_first_by_name(name)
  if type(name) ~= "string" then
    return nil
  end
  local target = vim.trim(name):lower()
  if #target == 0 then
    return nil
  end

  local state = self:__ensure_state__()
  for _, uuid in ipairs(state.orders) do
    local item = state.items[uuid]
    if item ~= nil and type(item.name) == "string" and item.name:lower() == target then
      return item
    end
  end
  return nil
end

---@param name                          string
---@return era.m.notepad.state.INotepadItemState
function M:ensure_named_item(name)
  local trimmed = vim.trim(type(name) == "string" and name or "")
  trimmed = #trimmed > 0 and trimmed or DEFAULT_ITEM_NAME

  local existing = self:find_first_by_name(trimmed)
  if existing ~= nil then
    return existing
  end

  local source = self:get_source()
  local item = source:create(trimmed, nil)

  if source:get_activated_uuid() == nil then
    source:set_activated_uuid(item.uuid)
    self:__notify_active_changed__()
  end

  self:__mark_dirty__()
  return item
end

---@param uuid                          string|nil
---@return boolean
function M:remove(uuid)
  local source = self:get_source()
  local active_uuid = source:get_activated_uuid()
  uuid = uuid or active_uuid
  if uuid == nil then
    return false
  end

  local state = self:__ensure_state__()
  if state.items[uuid] == nil then
    return false
  end

  -- If deleting the currently active note, navigate backward in history first
  if active_uuid == uuid then
    local history_uuid = source:go_backward()
    if history_uuid ~= nil and history_uuid ~= uuid then
      -- Set the previous note from history
      S.state.focus_note(history_uuid)
    end
  end

  if not source:remove(uuid) then
    return false
  end

  -- If we couldn't find a history entry, fall back to first note
  if source:get_activated_uuid() == uuid then
    local fallback_uuid = state.orders[1]
    if fallback_uuid ~= nil then
      S.state.focus_note(fallback_uuid)
    end
  end

  self:__mark_dirty__()
  return true
end

---@return boolean
function M:go_backward()
  local source = self:get_source()
  local uuid = source:go_backward()
  if uuid == nil then
    return false
  end

  -- Save the current buffer content before switching
  local bufnr = self:get_bufnr()
  if bufnr ~= nil then
    local old_uuid = source:get_activated_uuid()
    if old_uuid ~= nil then
      self:__sync_content_from_buf__(bufnr, old_uuid)
    end
  end

  -- Use state's focus_note to update source and notify observers
  -- The notification will trigger _on_active_uuid_changed which renders the buffer
  return S.state.focus_note(uuid)
end

---@return boolean
function M:go_forward()
  local source = self:get_source()
  local uuid = source:go_forward()
  if uuid == nil then
    return false
  end

  -- Save the current buffer content before switching
  local bufnr = self:get_bufnr()
  if bufnr ~= nil then
    local old_uuid = source:get_activated_uuid()
    if old_uuid ~= nil then
      self:__sync_content_from_buf__(bufnr, old_uuid)
    end
  end

  -- Use state's focus_note to update source and notify observers
  -- The notification will trigger _on_active_uuid_changed which renders the buffer
  return S.state.focus_note(uuid)
end

---@param uuid                          string|nil
---@param name                          string
---@return boolean
function M:rename(uuid, name)
  local source = self:get_source()
  uuid = uuid or source:get_activated_uuid()
  if uuid == nil then
    return false
  end

  local state = self:__ensure_state__()
  local item = state.items[uuid]
  if item == nil then
    return false
  end

  name = vim.trim(name or "")
  if #name == 0 or name == item.name then
    return false
  end

  if source:rename(uuid, name) then
    self:__mark_dirty__()
    return true
  end
  return false
end

---@param uuid                          string|nil
---@param content                       string
---@return boolean
function M:set_content(uuid, content)
  local source = self:get_source()
  uuid = uuid or source:get_activated_uuid()
  if uuid == nil then
    return false
  end

  local item = source:retrieve(uuid, false)
  if item == nil then
    return false
  end

  -- Content is now guaranteed to be loaded
  if item.content == (content or "") then
    return false
  end

  return source:update(uuid, {
    name = item.name,
    content = content or "",
  })
end

---@param uuid                          string|nil
---@param text                          string
---@return boolean
function M:append_content(uuid, text)
  if type(text) ~= "string" or #text == 0 then
    return false
  end

  local source = self:get_source()
  uuid = uuid or source:get_activated_uuid()

  local item = uuid and source:retrieve(uuid, false) or nil
  if item == nil then
    return false
  end

  -- Content is now guaranteed to be loaded
  local new_content = (type(item.content) == "string" and item.content or "") .. text
  local ok = self:set_content(uuid, new_content)

  if ok and uuid == source:get_activated_uuid() then
    local bufnr = self:get_bufnr()
    if bufnr ~= nil then
      self:__render_active_item__(bufnr)
    end
  end

  return ok
end

---@protected
---@param step                          integer
---@return boolean
function M:__swap_step__(step)
  local state = self:__ensure_state__()
  local count = #state.orders
  if count <= 1 then
    return false
  end

  local source = self:get_source()
  local index_current = self:indexof(source:get_activated_uuid())
  if index_current < 1 then
    return false
  end

  local index_next = stl.fn.navigate_circular(index_current, step, count)
  if index_next == index_current then
    return false
  end

  state.orders[index_current], state.orders[index_next] = state.orders[index_next], state.orders[index_current]
  self:__mark_orders_dirty__()
  return true
end

---@param step                          integer|nil
---@return boolean
function M:swap_left(step)
  step = step or vim.v.count1 ---@type integer
  return self:__swap_step__(-step)
end

---@param step                          integer|nil
---@return boolean
function M:swap_right(step)
  step = step or vim.v.count1 ---@type integer
  return self:__swap_step__(step)
end

---@return boolean
function M:flush()
  local source = self:get_source()
  return source:flush()
end

---@protected
---@return nil
function M:__dispose_subscriptions__()
  if self._subscription_active ~= nil then
    self._subscription_active:unsubscribe()
    self._subscription_active = nil
  end
  if self._subscription_winbar ~= nil then
    self._subscription_winbar:unsubscribe()
    self._subscription_winbar = nil
  end
  if self._subscription_source ~= nil then
    self._subscription_source:unsubscribe()
    self._subscription_source = nil
  end
end

---@protected
---@return nil
function M:__clear_buf_autocmds__()
  for _, id in ipairs(self._buf_autocmds) do
    pcall(vim.api.nvim_del_autocmd, id)
  end
  self._buf_autocmds = {}
end

---@protected
---@param bufnr                         integer
---@param uuid                          string|nil
---@return nil
function M:__sync_content_from_buf__(bufnr, uuid)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local source = self:get_source()
  uuid = uuid or source:get_activated_uuid()
  if uuid ~= nil then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    self:set_content(uuid, table.concat(lines, "\n"))
  end
end

---@protected
---@param bufnr                         integer
---@return nil
function M:__render_active_item__(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local source = self:get_source()
  local uuid = source:get_activated_uuid()
  vim.b[bufnr][BUFFER_VAR_NAME] = uuid

  local item = uuid and self:get(uuid) or nil
  local lines = (item ~= nil and #item.content > 0) and vim.split(item.content, "\n", { plain = true }) or { "" }

  self._suspend_sync = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  self._suspend_sync = false
end

---@protected
---@return nil
function M:__on_text_changed__()
  if self._suspend_sync then
    return
  end
  local bufnr = self:get_bufnr()
  if bufnr ~= nil then
    local source = self:get_source()
    self:__sync_content_from_buf__(bufnr, source:get_activated_uuid())
  end
end

---@protected
---@param bufnr                         integer
---@return nil
function M:__attach_autocmds__(bufnr)
  self:__clear_buf_autocmds__()

  for _, event in ipairs(TEXT_CHANGED_EVENTS) do
    local id = vim.api.nvim_create_autocmd(event, {
      buffer = bufnr,
      callback = function()
        self:__on_text_changed__()
      end,
    })
    table.insert(self._buf_autocmds, id)
  end

  local wipe_id = vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    callback = function()
      if self._bufnr == bufnr then
        self._bufnr = nil
        self:__clear_buf_autocmds__()
      end
    end,
  })
  table.insert(self._buf_autocmds, wipe_id)
end

---@protected
---@param uuid                          string|nil
---@return nil
function M:__on_active_uuid_changed__(uuid)
  uuid = uuid ~= nil and #uuid > 0 and uuid or nil

  -- The source's activated UUID has already been updated by focus_note()
  -- We just need to render the buffer with the new note's content
  local bufnr = self:get_bufnr()
  if bufnr ~= nil then
    -- Check if the buffer is already showing this UUID to avoid unnecessary renders
    local current_uuid = vim.b[bufnr][BUFFER_VAR_NAME]
    if current_uuid ~= uuid then
      self:__render_active_item__(bufnr)
    end
  end

  if self._nvimbar ~= nil then
    self._nvimbar:render()
  end
end

---@return integer|nil
function M:get_bufnr()
  local bufnr = self._bufnr
  return bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) and bufnr or nil
end

---@return integer
function M:ensure_buf()
  local bufnr = self:get_bufnr()
  if bufnr ~= nil then
    return bufnr
  end

  bufnr = vim.api.nvim_create_buf(false, true)
  self._bufnr = bufnr

  vim.api.nvim_buf_set_name(bufnr, self.bufname)
  vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", self.filetype, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })

  self:__attach_autocmds__(bufnr)
  self:__render_active_item__(bufnr)
  stl.nvim.fn.bindkeys(NOTEPAD_KEYMAPS, { bufnr = bufnr, noremap = true, silent = true })

  return bufnr
end

---@return integer|nil
function M:get_winnr()
  local winnr = self._winnr
  return winnr ~= nil and vim.api.nvim_win_is_valid(winnr) and winnr or nil
end

---@return stl.box.IDimension
function M:measure_rect()
  local columns = vim.o.columns
  local desired_width = math.min(132, math.floor(columns * 0.9 + 0.5))
  local desired_height = math.floor(vim.o.lines * 0.8 + 0.5)
  local min_width = math.min(self.min_width, columns)
  local min_height = math.min(self.min_height, vim.o.lines)
  desired_width = math.min(math.max(min_width, desired_width), columns)
  desired_height = math.min(math.max(min_height, desired_height), vim.o.lines - 2)

  return stl.box.measure(desired_width, desired_height, {
    position = "center",
    rows = vim.o.lines,
    cols = columns,
    max_width = desired_width,
    max_height = desired_height,
    min_width = min_width,
    min_height = min_height,
  })
end

---@protected
---@param winhighlight                  string|nil
---@return string
function M:__normalize_winhighlight__(winhighlight)
  if type(winhighlight) ~= "string" or #winhighlight == 0 then
    return NOTEPAD_WIN_HIGHLIGHT
  end
  if not winhighlight:match("FloatBorder:") then
    winhighlight = winhighlight .. ",FloatBorder:FloatBorder"
  end
  if not winhighlight:match("FloatTitle:") then
    winhighlight = winhighlight .. ",FloatTitle:f_np_title"
  end
  return winhighlight
end

---@protected
---@return string
function M:__get_window_title__()
  local source_name = dot.context.module.notepad_source:snapshot() ---@type string
  local _, config = S.state.retrieve_source(source_name)
  return string.format(" %s ", config.title)
end

---@return integer
function M:ensure_win()
  local bufnr = self:ensure_buf()
  local rect = self:measure_rect()
  local winblend = dot.context.theme.get_float_winblend()

  self.win_opts.winhighlight = self:__normalize_winhighlight__(self.win_opts.winhighlight)

  local config = {
    zindex = dot.win.resolve_zindex(),
    relative = "editor",
    anchor = "NW",
    row = rect.row,
    col = rect.col,
    width = rect.width,
    height = rect.height,
    focusable = true,
    title = self:__get_window_title__(),
    title_pos = "center",
    border = "rounded",
    style = "minimal",
  }

  local winnr = self:get_winnr()
  local is_new_win = winnr == nil

  if winnr == nil then
    winnr = vim.api.nvim_open_win(bufnr, true, config)
    self._winnr = winnr
    vim.w[winnr].wintype = stl.e.WinTypeEnum.TEXTAREA
  else
    vim.api.nvim_set_option_value("winfixbuf", false, { win = winnr, scope = "local" })
    local resize = dot.state.maximized.resolve_resize_config(winnr, config, { winblend = winblend })
    vim.api.nvim_win_set_config(winnr, resize.cfg)
    vim.api.nvim_win_set_buf(winnr, bufnr)
    winblend = resize.winblend or winblend
  end

  vim.api.nvim_set_option_value("cursorline", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("list", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("number", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("relativenumber", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("signcolumn", "yes", { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("spell", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("wrap", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winblend", winblend, { win = winnr, scope = "local" })

  for key, value in pairs(self.win_opts) do
    if key ~= "winhighlight" or is_new_win then
      vim.api.nvim_set_option_value(key, value, { win = winnr, scope = "local" })
    end
  end
  vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })

  if self._nvimbar ~= nil then
    self._nvimbar:render()
  end

  return winnr
end

---@return integer|nil
function M:sync_active_content()
  local bufnr = self:get_bufnr()
  if bufnr ~= nil then
    local source = self:get_source()
    self:__sync_content_from_buf__(bufnr, source:get_activated_uuid())
  end
  return bufnr
end

---@return boolean
function M:save()
  local bufnr = self:sync_active_content()

  local filepath = self:get_filepath()
  if #filepath > 0 then
    stl.env.mkdirs(filepath, false)
  end

  local ok = self:flush()

  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  end

  return ok
end

---@return nil
function M:focus()
  dot.state.widget.push(self)
  local winnr = self:ensure_win()
  if vim.api.nvim_get_current_win() ~= winnr then
    vim.api.nvim_set_current_win(winnr)
  end
end

---@return nil
function M:show()
  self:focus()
end

---@return nil
function M:hide()
  local winnr = self:get_winnr()
  self._winnr = nil
  stl.nvim.win.close(winnr)
end

---@return nil
function M:close()
  self:hide()
end

---@return boolean
function M:isvisible()
  return self:get_winnr() ~= nil
end

---@return boolean
function M:isfocused()
  local winnr = self:get_winnr()
  return winnr ~= nil and vim.api.nvim_get_current_win() == winnr
end

---@return nil
function M:resize()
  local winnr = self:get_winnr()
  if winnr == nil then
    return
  end

  local rect = self:measure_rect()
  vim.api.nvim_set_option_value("winfixbuf", false, { win = winnr, scope = "local" })

  local resize = dot.state.maximized.resolve_resize_config(winnr, {
    relative = "editor",
    anchor = "NW",
    row = rect.row,
    col = rect.col,
    width = rect.width,
    height = rect.height,
  }, nil)

  vim.api.nvim_win_set_config(winnr, resize.cfg)
  if resize.winblend ~= nil then
    vim.api.nvim_set_option_value("winblend", resize.winblend, { win = winnr, scope = "local" })
  end
  vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })

  if self._nvimbar ~= nil then
    self._nvimbar:render()
  end
end

---@return nil
function M:toggle()
  if self:isvisible() then
    self:hide()
  else
    self:focus()
  end
end

---@return boolean
function M:isdisposed()
  return false
end

---@return nil
function M:dispose()
  self:__dispose_subscriptions__()
  self:__clear_buf_autocmds__()
  if self._nvimbar ~= nil then
    self._nvimbar:dispose()
    self._nvimbar = nil
  end
  self._bufnr = nil
  self._winnr = nil
end

---@param winnr                          integer
---@return nil
function M:render_winbar_to(winnr)
  if self._nvimbar == nil then
    return
  end
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local prev_winnr = self._winnr
  self._winnr = winnr
  local result = self._nvimbar:render(true)
  self._winnr = prev_winnr

  vim.api.nvim_set_option_value("winbar", result, { win = winnr, scope = "local" })
end

M.BUFFER_VAR = BUFFER_VAR_NAME
M.o_active_uuid = function()
  return S.state.o_activated_uuid
end

return M
