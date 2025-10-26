---@diagnostic disable: invisible

local DEFAULT_WIDTH = 0.6
local DEFAULT_HEIGHT = 0.6
local MAX_WIDTH = 0.9
local MAX_HEIGHT = 0.9
local MIN_WIDTH = 60
local MIN_HEIGHT = 12
local WIN_TITLE = " Notepad "
local NOTEPAD_WIN_HIGHLIGHT = table.concat({
  "FloatBorder:FloatBorder",
  "FloatTitle:f_np_title",
}, ",") ---@type string

local TEXT_CHANGED_EVENTS = { "TextChanged", "TextChangedI", "TextChangedP" } ---@type string[]
local K = eve.command.definitions ---@type eve.builtin.command.definitions

local DEFAULT_ITEM_NAME = eve.setting.BUF_UNTITLED ---@type string
local BUFFER_VAR_NAME = "eve_notepad_uuid" ---@type string

---@type std.t.IKeymap[]
local NOTEPAD_KEYMAPS = {
  {
    modes = { "i", "n", "v" },
    key = "<C-s>",
    desc = K.notepad.save.desc,
    callback = function()
      vim.cmd(K.notepad.save.uuid)
    end,
  },
  {
    modes = { "i", "n", "v" },
    key = "<C-a>s",
    aliases = { "<D-s>", "<M-s>" },
    desc = K.notepad.save.desc,
    callback = function()
      vim.cmd(K.notepad.save.uuid)
    end,
  },
  {
    modes = { "n" },
    key = "q",
    desc = K.notepad.close.desc,
    callback = function()
      vim.cmd(K.notepad.close.uuid)
    end,
  },
  {
    modes = { "i", "n", "v" },
    key = "<C-n>",
    desc = K.notepad.create.desc,
    callback = function()
      vim.cmd(K.notepad.create.uuid)
    end,
  },
  {
    modes = { "n" },
    key = "<leader><cr>",
    desc = K.ai.submit_buffer.desc,
    callback = function()
      vim.cmd(K.ai.submit_buffer.uuid)
    end,
  },
  {
    modes = { "v" },
    key = "<leader><cr>",
    desc = K.ai.submit_selection.desc,
    callback = function()
      vim.cmd(K.ai.submit_selection.uuid)
    end,
  },
  {
    modes = { "i", "n", "v" },
    key = "<C-/>",
    desc = K.notepad.rename.desc,
    callback = function()
      vim.cmd(K.notepad.rename.uuid)
    end,
  },
  {
    modes = { "i", "n", "v" },
    key = "<C-d>",
    desc = K.notepad.destroy.desc,
    callback = function()
      vim.cmd(K.notepad.destroy.uuid)
    end,
  },
  {
    modes = { "n" },
    key = "<leader>dd",
    desc = K.notepad.destroy.desc,
    callback = function()
      vim.cmd(K.notepad.destroy.uuid)
    end,
  },
  {
    modes = { "i", "n", "v" },
    key = "<C-,>",
    aliases = { "<C-[>" },
    desc = K.notepad.focus_left.desc,
    callback = function()
      vim.cmd(K.notepad.focus_left.uuid)
    end,
  },
  {
    modes = { "i", "n", "v" },
    key = "<C-.>",
    aliases = { "<C-]>" },
    desc = K.notepad.focus_right.desc,
    callback = function()
      vim.cmd(K.notepad.focus_right.uuid)
    end,
  },
  {
    modes = { "i", "n", "v" },
    key = "<C-S-,>",
    aliases = { "<C-S-[>" },
    desc = K.notepad.swap_left.desc,
    callback = function()
      vim.cmd(K.notepad.swap_left.uuid)
    end,
  },
  {
    modes = { "i", "n", "v" },
    key = "<C-S-.>",
    aliases = { "<C-S-]>" },
    desc = K.notepad.swap_right.desc,
    callback = function()
      vim.cmd(K.notepad.swap_right.uuid)
    end,
  },
  {
    modes = { "i", "n", "v" },
    key = "<esc>",
    desc = "notepad: feedback esc to notepad (fix the conflict caused by the csi u)",
    expr = true,
    replace_keycodes = true,
    callback = function()
      return "<esc>"
    end,
  },
}
for index = 1, 9, 1 do
  local definition = K.notepad["focus_" .. tostring(index)] ---@type eve.builtin.command.IDefinition
  NOTEPAD_KEYMAPS[#NOTEPAD_KEYMAPS + 1] = {
    modes = { "i", "n", "v" },
    key = string.format("<C-%d>", index),
    desc = definition.desc,
    callback = function()
      vim.cmd(definition.uuid)
    end,
  }
end

---@class eve.ux.widget.notepad.IProps
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
---@field public source                 ?std.t.INotepadSource

---@class eve.ux.widget.Notepad : std.t.ux.IWidget
---@field public name                   string|nil
---@field private title                 string
---@field private bufname               string
---@field private width                 number
---@field private height                number
---@field private max_width             number
---@field private max_height            number
---@field private min_width             number
---@field private min_height            number
---@field private filetype              string
---@field private win_opts              table<string, any>
---@field private _bufnr                integer|nil
---@field private _winnr                integer|nil
---@field private _suspend_sync         boolean
---@field private _buf_autocmds         integer[]
---@field private _nvimbar              eve.ux.nvimbar.Nvimbar|nil
---@field private _subscription_active  std.collection.IUnsubscribable|nil
---@field private _subscription_winbar  std.collection.IUnsubscribable|nil
---@field private _source               std.t.INotepadSource
---@field private _o_active_uuid        std.collection.IObservable
local M = {}
M.__index = M

---@param props                         eve.ux.widget.notepad.IProps|nil
---@return eve.ux.widget.Notepad
function M.new(props)
  props = props or {}

  local source = props.source
  if source == nil then
    source = eve.state.notepad.workspace
  end

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
  self.filetype = props.filetype or "markdown"
  self.win_opts = vim.tbl_extend("force", { winhighlight = NOTEPAD_WIN_HIGHLIGHT }, props.win_opts or {})

  self._bufnr = nil
  self._winnr = nil
  self._suspend_sync = false
  self._buf_autocmds = {}

  self._source = source

  -- Ensure source data is loaded
  local data = self._source:load(false)

  -- Initialize observable with loaded active_uuid
  self._o_active_uuid = std.Observable.from_value(data.active_uuid or "")

  -- Set up subscription
  local widget = self ---@type eve.ux.widget.Notepad
  self._subscription_active = self._o_active_uuid:subscribe(
    std.Subscriber.new({
      on_next = function(next_uuid)
        widget:_on_active_uuid_changed(next_uuid)
      end,
    }),
    false
  )

  self._nvimbar = eve.ux.nvimbar.Nvimbar.new({
    name = string.format("%s.winbar", self.name),
    comp_sep = "",
    comp_sep_hlname = "f_wl_bg",
    comp_sep_hlname_active = "f_wl_bg",
    delay = 128,
    get_max_width = function()
      local winnr = widget._winnr ---@type integer|nil
      if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
        local width = vim.api.nvim_win_get_width(winnr) ---@type integer
        return math.max(0, width - 2)
      end
      return vim.o.columns - 2
    end,
    get_preset_context = function()
      return {
        winnr = widget._winnr,
      }
    end,
    is_active = function()
      local winnr = widget._winnr ---@type integer|nil
      return winnr ~= nil and vim.api.nvim_win_is_valid(winnr)
    end,
    on_fulfilled = function(result)
      local winnr = widget._winnr
      if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
        vim.wo[winnr].winbar = result
      end
    end,
  })
  self._nvimbar
    :place("left", eve.ux.nvimbar.component.notepad.items("f_wl", widget), 95)
    :place("left", eve.ux.nvimbar.component.notepad.add_button("f_wl"), 100)

  self._subscription_winbar = eve.status.dirtier_notepadline:subscribe(
    std.Subscriber.new({
      on_next = function()
        local nvimbar = widget._nvimbar ---@type eve.ux.nvimbar.Nvimbar|nil
        if nvimbar ~= nil then
          nvimbar:render()
        end
      end,
    }),
    true
  )

  return self
end

---@private
---@return nil
function M:_notify_active_changed()
  local data = self._source._data ---@type std.t.INotepadSourceSaveData|nil
  if data ~= nil and data.active_uuid ~= nil then
    self._o_active_uuid:next(data.active_uuid)
  else
    self._o_active_uuid:next("")
  end
end

---@private
---@return std.t.INotepadSourceSaveData
function M:_ensure_data()
  return self._source:load(false)
end

---@return string
function M:get_filepath()
  local workspace = eve.state.notepad.workspace
  if self._source == workspace then
    return std.path.locate_workspace_filepath("notepad.json")
  end
  return ""
end

---@return integer
function M:size()
  local data = self:_ensure_data()
  return #data.orders
end

---@param uuid string|nil
---@return integer
function M:indexof(uuid)
  local data = self:_ensure_data()
  if uuid == nil then
    return -1
  end
  for index, target in ipairs(data.orders) do
    if target == uuid then
      return index
    end
  end
  return -1
end

---@param index integer
---@return string|nil
---@return std.t.INotepadItem|nil
function M:at(index)
  local data = self:_ensure_data()
  local uuid = data.orders[index]
  if uuid ~= nil then
    return uuid, data.items[uuid]
  end
  return nil, nil
end

---@return integer
---@return string|nil
function M:current()
  local data = self:_ensure_data()
  return self:indexof(data.active_uuid), data.active_uuid
end

---@return std.t.INotepadItem|nil
function M:current_item()
  local data = self:_ensure_data()
  if data.active_uuid == nil then
    return nil
  end
  return data.items[data.active_uuid]
end

---@param uuid string
---@return std.t.INotepadItem|nil
function M:get(uuid)
  local data = self:_ensure_data()
  return data.items[uuid]
end

---@return fun():std.t.INotepadItem|nil, integer|nil
function M:iterator()
  local data = self:_ensure_data()
  local index = 0 ---@type integer
  local orders = data.orders
  local items_map = data.items
  return function()
    index = index + 1
    if index > #orders then
      return nil, nil
    end
    local uuid = orders[index] ---@type string
    local item = items_map[uuid]
    if item == nil then
      return nil, nil
    end
    return item, index
  end
end

---@param uuid string|nil
---@return boolean
function M:focus_uuid(uuid)
  local data = self:_ensure_data()
  if uuid == nil then
    return false
  end
  if data.items[uuid] == nil then
    return false
  end
  if data.active_uuid == uuid then
    return true
  end

  -- Emit notification (will trigger _on_active_uuid_changed which updates data.active_uuid)
  self._o_active_uuid:next(uuid)

  eve.status.dirtier_notepadline:mark_dirty()
  return true
end

---@param index integer
---@return boolean
function M:focus_index(index)
  local data = self:_ensure_data()
  local uuid = data.orders[index]
  if uuid == nil then
    return false
  end
  return self:focus_uuid(uuid)
end

---@param step integer
---@return boolean
function M:focus_step(step)
  local data = self:_ensure_data()
  local count = #data.orders ---@type integer
  if count == 0 then
    return false
  end
  local index_current = self:indexof(data.active_uuid)
  if index_current < 1 then
    index_current = 1
  end
  local index_next = std.fn.navigate_circular(index_current, step, count) ---@type integer
  return self:focus_index(index_next)
end

---@param name string|nil
---@return std.t.INotepadItem
function M:create(name)
  local trimmed = type(name) == "string" and vim.trim(name) or nil
  local item = self._source:create(#(trimmed or "") > 0 and trimmed or nil, nil)

  eve.status.dirtier_notepadline:mark_dirty()
  self:focus_uuid(item.uuid)
  return item
end

---@param name string
---@return std.t.INotepadItem|nil
function M:find_first_by_name(name)
  local data = self:_ensure_data()
  if type(name) ~= "string" then
    return nil
  end

  local target = vim.trim(name)
  if #target == 0 then
    return nil
  end
  target = target:lower()

  for _, uuid in ipairs(data.orders) do
    local item = data.items[uuid]
    if item ~= nil and type(item.name) == "string" and item.name:lower() == target then
      return item
    end
  end

  return nil
end

---@param name string
---@return std.t.INotepadItem
function M:ensure_named_item(name)
  local trimmed = vim.trim(type(name) == "string" and name or "")
  if #trimmed == 0 then
    trimmed = DEFAULT_ITEM_NAME
  end

  local existing = self:find_first_by_name(trimmed)
  if existing ~= nil then
    return existing
  end

  local item = self._source:create(trimmed, nil)
  local data = self:_ensure_data()

  if data.active_uuid == nil then
    data.active_uuid = item.uuid
    self:_notify_active_changed()
  end

  eve.status.dirtier_notepadline:mark_dirty()
  return item
end

---@param uuid string|nil
---@return boolean
function M:remove(uuid)
  local data = self:_ensure_data()
  uuid = uuid or data.active_uuid
  if uuid == nil or data.items[uuid] == nil then
    return false
  end

  local ok = self._source:remove(uuid)
  if not ok then
    return false
  end

  local active_changed = false ---@type boolean
  if data.active_uuid == uuid then
    data.active_uuid = data.orders[1]
    if data.active_uuid ~= nil then
      active_changed = true
    end
  end

  eve.status.dirtier_notepadline:mark_dirty()

  if active_changed then
    self:_notify_active_changed()
  end

  return true
end

---@param uuid string|nil
---@param name string
---@return boolean
function M:rename(uuid, name)
  local data = self:_ensure_data()
  uuid = uuid or data.active_uuid
  if uuid == nil then
    return false
  end
  local item = data.items[uuid]
  if item == nil then
    return false
  end

  name = vim.trim(name or "")
  if #name == 0 or name == item.name then
    return false
  end

  local ok = self._source:update(uuid, { name = name, content = item.content })
  if ok then
    eve.status.dirtier_notepadline:mark_dirty()
  end

  return ok
end

---@param uuid string|nil
---@param content string
---@return boolean
function M:set_content(uuid, content)
  local data = self:_ensure_data()
  uuid = uuid or data.active_uuid
  if uuid == nil then
    return false
  end
  local item = data.items[uuid]
  if item == nil then
    return false
  end

  content = content or ""
  if item.content == content then
    return false
  end

  return self._source:update(uuid, { name = item.name, content = content })
end

---@param uuid_or_item string|std.t.INotepadItem|nil
---@param text string
---@return boolean
function M:append_content(uuid_or_item, text)
  if type(text) ~= "string" or #text == 0 then
    return false
  end

  local uuid ---@type string|nil
  local item ---@type std.t.INotepadItem|nil

  if type(uuid_or_item) == "table" then
    item = uuid_or_item
    uuid = uuid_or_item.uuid
  elseif type(uuid_or_item) == "string" then
    uuid = uuid_or_item
  end

  local data = self:_ensure_data()
  uuid = uuid or data.active_uuid
  if uuid == nil then
    return false
  end

  item = item or data.items[uuid]
  if item == nil then
    return false
  end

  local existing = type(item.content) == "string" and item.content or "" ---@type string
  local new_content = existing .. text ---@type string
  local ok = self:set_content(uuid, new_content) ---@type boolean

  -- Update buffer if it's the active item and buffer exists
  if ok and uuid == data.active_uuid then
    local bufnr = self:get_bufnr()
    if bufnr ~= nil then
      self:_render_active_item(bufnr)
    end
  end

  return ok
end

---@param step integer|nil
---@return boolean
function M:swap_left(step)
  local data = self:_ensure_data()
  local count = #data.orders ---@type integer
  if count <= 1 then
    return false
  end

  local index_current = self:indexof(data.active_uuid)
  if index_current < 1 then
    return false
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local index_next = std.fn.navigate_circular(index_current, -step, count) ---@type integer
  if index_next == index_current then
    return false
  end

  data.orders[index_current], data.orders[index_next] = data.orders[index_next], data.orders[index_current]

  eve.status.dirtier_notepadline:mark_dirty()
  return true
end

---@param step integer|nil
---@return boolean
function M:swap_right(step)
  local data = self:_ensure_data()
  local count = #data.orders ---@type integer
  if count <= 1 then
    return false
  end

  local index_current = self:indexof(data.active_uuid)
  if index_current < 1 then
    return false
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local index_next = std.fn.navigate_circular(index_current, step, count) ---@type integer
  if index_next == index_current then
    return false
  end

  data.orders[index_current], data.orders[index_next] = data.orders[index_next], data.orders[index_current]

  eve.status.dirtier_notepadline:mark_dirty()
  return true
end

---@return boolean
function M:flush()
  return self._source:flush()
end

---@private
---@return nil
function M:_dispose_subscriptions()
  local sub_active = self._subscription_active ---@type std.collection.IUnsubscribable|nil
  if sub_active ~= nil then
    sub_active:unsubscribe()
    self._subscription_active = nil
  end

  local sub_winbar = self._subscription_winbar ---@type std.collection.IUnsubscribable|nil
  if sub_winbar ~= nil then
    sub_winbar:unsubscribe()
    self._subscription_winbar = nil
  end
end

---@private
---@return nil
function M:_clear_buf_autocmds()
  for _, id in ipairs(self._buf_autocmds) do
    pcall(vim.api.nvim_del_autocmd, id)
  end
  self._buf_autocmds = {}
end

---@private
---@param bufnr                          integer
---@param uuid                           string|nil
---@return nil
function M:_sync_content_from_buf(bufnr, uuid)
  local data = self:_ensure_data()
  uuid = uuid or data.active_uuid
  if uuid == nil then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local content = table.concat(lines, "\n") ---@type string
  self:set_content(uuid, content)
end

---@private
---@param bufnr                          integer
---@return nil
function M:_render_active_item(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local data = self:_ensure_data()
  local uuid = data.active_uuid ---@type string|nil
  if uuid ~= nil then
    vim.b[bufnr][BUFFER_VAR_NAME] = uuid
  else
    vim.b[bufnr][BUFFER_VAR_NAME] = nil
  end
  local item = uuid ~= nil and self:get(uuid) or nil ---@type std.t.INotepadItem|nil
  local lines ---@type string[]

  if item ~= nil and #item.content > 0 then
    lines = vim.split(item.content, "\n", { plain = true })
  else
    lines = { "" }
  end

  self._suspend_sync = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  self._suspend_sync = false
  vim.bo[bufnr].modified = false
end

---@private
---@return nil
function M:_on_text_changed()
  if self._suspend_sync then
    return
  end

  local bufnr = self:get_bufnr()
  if bufnr ~= nil then
    local data = self:_ensure_data()
    self:_sync_content_from_buf(bufnr, data.active_uuid)
  end
end

---@private
---@param bufnr                          integer
---@return nil
function M:_attach_autocmds(bufnr)
  self:_clear_buf_autocmds()

  for _, event in ipairs(TEXT_CHANGED_EVENTS) do
    local id = vim.api.nvim_create_autocmd(event, {
      buffer = bufnr,
      callback = function()
        self:_on_text_changed()
      end,
    })
    table.insert(self._buf_autocmds, id)
  end

  local wipe_id = vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    callback = function()
      if self._bufnr == bufnr then
        self._bufnr = nil
        self:_clear_buf_autocmds()
      end
    end,
  })
  table.insert(self._buf_autocmds, wipe_id)
end

---@private
---@param uuid                           string|nil
---@return nil
function M:_on_active_uuid_changed(uuid)
  local data = self:_ensure_data()
  uuid = uuid ~= nil and #uuid > 0 and uuid or nil
  if data.active_uuid == uuid then
    return
  end

  local bufnr = self:get_bufnr()
  if bufnr ~= nil and data.active_uuid ~= nil then
    self:_sync_content_from_buf(bufnr, data.active_uuid)
  end

  data.active_uuid = uuid
  if bufnr ~= nil then
    self:_render_active_item(bufnr)
  end

  if self._nvimbar ~= nil then
    self._nvimbar:render()
  end
end

---@private
---@return integer|nil
function M:get_bufnr()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end
end

---@private
---@return integer
function M:ensure_buf()
  local bufnr = self:get_bufnr()
  if bufnr ~= nil then
    return bufnr
  end

  bufnr = vim.api.nvim_create_buf(false, true)
  self._bufnr = bufnr

  vim.api.nvim_buf_set_name(bufnr, self.bufname)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = self.filetype
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].swapfile = false
  local render_manager = package.loaded["render-markdown.core.manager"]
  if render_manager ~= nil then
    render_manager.set_buf(bufnr, false)
  end

  self:_attach_autocmds(bufnr)
  self:_render_active_item(bufnr)

  eve.nvim.bindkeys(NOTEPAD_KEYMAPS, { bufnr = bufnr, noremap = true, silent = true })
  return bufnr
end

---@return integer|nil
function M:get_winnr()
  local winnr = self._winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    return winnr
  end
end

---@private
---@return eve.builtin.box.IDimension
function M:measure_rect()
  local columns = vim.o.columns ---@type integer
  local desired_width = math.min(132, math.floor(columns * 0.9 + 0.5)) ---@type integer
  local desired_height = math.floor(vim.o.lines * 0.8 + 0.5) ---@type integer
  local min_width = math.min(self.min_width, columns) ---@type integer
  local min_height = math.min(self.min_height, vim.o.lines) ---@type integer
  desired_width = math.max(min_width, desired_width) ---@type integer
  desired_width = math.min(desired_width, columns) ---@type integer
  desired_height = math.max(min_height, math.min(desired_height, vim.o.lines - 2)) ---@type integer

  ---@type eve.builtin.box.IRestriction
  local restriction = {
    position = "center",
    rows = vim.o.lines,
    cols = columns,
    max_width = desired_width,
    max_height = desired_height,
    min_width = min_width,
    min_height = min_height,
  }
  return eve.box.measure(desired_width, desired_height, restriction)
end

---@private
---@return integer
function M:ensure_win()
  local bufnr = self:ensure_buf()
  local rect = self:measure_rect()
  local winblend = eve.context.theme.get_float_winblend() ---@type integer

  local winhighlight = self.win_opts.winhighlight ---@type string|nil
  if type(winhighlight) ~= "string" or #winhighlight == 0 then
    winhighlight = NOTEPAD_WIN_HIGHLIGHT
  else
    if not winhighlight:match("FloatBorder:") then
      winhighlight = table.concat({ winhighlight, "FloatBorder:FloatBorder" }, ",")
    end
    if not winhighlight:match("FloatTitle:") then
      winhighlight = table.concat({ winhighlight, "FloatTitle:f_np_title" }, ",")
    end
  end
  self.win_opts.winhighlight = winhighlight

  ---@type vim.api.keyset.win_config
  local config = {
    relative = "editor",
    anchor = "NW",
    row = rect.row,
    col = rect.col,
    width = rect.width,
    height = rect.height,
    focusable = true,
    title = self.title,
    title_pos = "center",
    border = "rounded",
    style = "minimal",
  }

  local winnr = self:get_winnr() ---@type integer|nil
  local is_new_win = winnr == nil ---@type boolean
  if winnr == nil then
    winnr = vim.api.nvim_open_win(bufnr, true, config)
    self._winnr = winnr
    eve.win.set_type(winnr, eve.win.Types.TEXTAREA)
    is_new_win = true
  else
    vim.wo[winnr].winfixbuf = false
    ---@type eve.state.maximized.ResolveResizeResult
    local resize = eve.state.maximized.resolve_resize_config(winnr, config, { winblend = winblend })
    vim.api.nvim_win_set_config(winnr, resize.cfg)
    vim.api.nvim_win_set_buf(winnr, bufnr)
    winblend = resize.winblend or winblend
  end

  vim.wo[winnr].cursorline = true
  vim.wo[winnr].list = true
  vim.wo[winnr].number = true
  vim.wo[winnr].relativenumber = true
  vim.wo[winnr].signcolumn = "yes"
  vim.wo[winnr].spell = true
  vim.wo[winnr].wrap = true
  vim.wo[winnr].winblend = winblend
  for key, value in pairs(self.win_opts) do
    if key ~= "winhighlight" or is_new_win then
      vim.wo[winnr][key] = value
    end
  end
  vim.wo[winnr].winfixbuf = true

  if self._nvimbar ~= nil then
    self._nvimbar:render()
  end

  return winnr
end

---@return integer|nil
function M:sync_active_content()
  local bufnr = self:get_bufnr()
  if bufnr == nil then
    return nil
  end
  local data = self:_ensure_data()
  self:_sync_content_from_buf(bufnr, data.active_uuid)
  return bufnr
end

---@return boolean
function M:save()
  local bufnr = self:sync_active_content()

  local filepath = self:get_filepath() ---@type string|nil
  if filepath ~= nil and #filepath > 0 then
    vim.fn.mkdir(std.path.dirname(filepath), "p")
  end

  local ok = self:flush()

  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.bo[bufnr].modified = false
  end

  return ok
end

---@return nil
function M:focus()
  eve.widget.push(self)

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
  eve.win.close(winnr)
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
  if winnr == nil then
    return false
  end
  return vim.api.nvim_get_current_win() == winnr
end

---@return nil
function M:resize()
  local winnr = self:get_winnr()
  if winnr == nil then
    return
  end

  local rect = self:measure_rect()
  vim.wo[winnr].winfixbuf = false
  local config = {
    relative = "editor",
    anchor = "NW",
    row = rect.row,
    col = rect.col,
    width = rect.width,
    height = rect.height,
  }
  local resize = eve.state.maximized.resolve_resize_config(winnr, config, nil) ---@type eve.state.maximized.ResolveResizeResult
  vim.api.nvim_win_set_config(winnr, resize.cfg)
  if resize.winblend ~= nil then
    vim.wo[winnr].winblend = resize.winblend
  end
  vim.wo[winnr].winfixbuf = true

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
  self:_dispose_subscriptions()
  self:_clear_buf_autocmds()
  if self._nvimbar ~= nil then
    self._nvimbar:dispose()
    self._nvimbar = nil
  end
  self._bufnr = nil
  self._winnr = nil
end

M.BUFFER_VAR = BUFFER_VAR_NAME
M.o_active_uuid = function(self)
  return self._o_active_uuid
end

return M
