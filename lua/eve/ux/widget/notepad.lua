---@diagnostic disable: invisible

local DEFAULT_WIDTH = 0.6
local DEFAULT_HEIGHT = 0.6
local MAX_WIDTH = 0.9
local MAX_HEIGHT = 0.9
local MIN_WIDTH = 60
local MIN_HEIGHT = 12
local WIN_TITLE = " Notepad "
local NOTEPAD_WIN_HIGHLIGHT = "FloatBorder:FloatBorder,FloatTitle:f_np_title"
local TEXT_CHANGED_EVENTS = { "TextChanged", "TextChangedI", "TextChangedP" }
local DEFAULT_ITEM_NAME = eve.setting.BUF_UNTITLED
local BUFFER_VAR_NAME = "eve_notepad_uuid"

local K = eve.command.definitions

---@param modes string[]
---@param key string
---@param cmd string
---@param desc string
---@param opts table|nil
---@return std.t.IKeymap
local function create_keymap(modes, key, cmd, desc, opts)
  opts = opts or {}
  return vim.tbl_extend("force", {
    modes = modes,
    key = key,
    desc = desc,
    callback = function()
      vim.cmd(cmd)
    end,
  }, opts)
end

local NOTEPAD_KEYMAPS = {
  create_keymap({ "i", "n", "v" }, "<C-s>", K.notepad.save.uuid, K.notepad.save.desc),
  create_keymap({ "i", "n", "v" }, "<C-a>s", K.notepad.save.uuid, K.notepad.save.desc, { aliases = { "<D-s>", "<M-s>" } }),
  create_keymap({ "n" }, "q", K.notepad.close.uuid, K.notepad.close.desc),
  create_keymap({ "i", "n", "v" }, "<C-n>", K.notepad.create.uuid, K.notepad.create.desc),
  create_keymap({ "n" }, "<leader><cr>", K.ai.submit_buffer.uuid, K.ai.submit_buffer.desc),
  create_keymap({ "v" }, "<leader><cr>", K.ai.submit_selection.uuid, K.ai.submit_selection.desc),
  create_keymap({ "i", "n", "v" }, "<C-/>", K.notepad.rename.uuid, K.notepad.rename.desc),
  create_keymap({ "i", "n", "v" }, "<C-d>", K.notepad.destroy.uuid, K.notepad.destroy.desc),
  create_keymap({ "n" }, "<leader>dd", K.notepad.destroy.uuid, K.notepad.destroy.desc),
  create_keymap({ "i", "n", "v" }, "<C-,>", K.notepad.focus_left.uuid, K.notepad.focus_left.desc, { aliases = { "<C-[>" } }),
  create_keymap({ "i", "n", "v" }, "<C-.>", K.notepad.focus_right.uuid, K.notepad.focus_right.desc, { aliases = { "<C-]>" } }),
  create_keymap({ "i", "n", "v" }, "<C-S-,>", K.notepad.swap_left.uuid, K.notepad.swap_left.desc, { aliases = { "<C-S-[>" } }),
  create_keymap({ "i", "n", "v" }, "<C-S-.>", K.notepad.swap_right.uuid, K.notepad.swap_right.desc, { aliases = { "<C-S-]>" } }),
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

for index = 1, 9 do
  local definition = K.notepad["focus_" .. tostring(index)]
  NOTEPAD_KEYMAPS[#NOTEPAD_KEYMAPS + 1] = create_keymap({ "i", "n", "v" }, string.format("<C-%d>", index), definition.uuid, definition.desc)
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
  self._source = props.source or eve.state.notepad.workspace

  local data = self._source:load(false)
  self._o_active_uuid = std.Observable.from_value(data.active_uuid or "")

  self:_setup_subscriptions()
  self:_setup_nvimbar()

  return self
end

---@private
---@return nil
function M:_setup_subscriptions()
  self._subscription_active = self._o_active_uuid:subscribe(std.Subscriber.new({
    on_next = function(next_uuid)
      self:_on_active_uuid_changed(next_uuid)
    end,
  }), false)

  self._subscription_winbar = eve.status.dirtier_notepadline:subscribe(std.Subscriber.new({
    on_next = function()
      if self._nvimbar ~= nil then
        self._nvimbar:render()
      end
    end,
  }), true)
end

---@private
---@return nil
function M:_setup_nvimbar()
  local widget = self
  self._nvimbar = eve.ux.nvimbar.Nvimbar.new({
    name = string.format("%s.winbar", self.name),
    comp_sep = "",
    comp_sep_hlname = "f_wl_bg",
    comp_sep_hlname_active = "f_wl_bg",
    delay = 128,
    get_max_width = function()
      local winnr = widget._winnr
      if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
        return math.max(0, vim.api.nvim_win_get_width(winnr) - 2)
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
        vim.wo[winnr].winbar = result
      end
    end,
  })
    :place("left", eve.ux.nvimbar.component.notepad.items("f_wl", widget), 95)
    :place("left", eve.ux.nvimbar.component.notepad.add_button("f_wl"), 100)
end

---@private
---@return std.t.INotepadSourceSaveData
function M:_ensure_data()
  return self._source:load(false)
end

---@private
---@return nil
function M:_notify_active_changed()
  local data = self._source._data
  self._o_active_uuid:next(data ~= nil and data.active_uuid or "")
end

---@private
---@return nil
function M:_mark_dirty()
  eve.status.dirtier_notepadline:mark_dirty()
end

---@return string
function M:get_filepath()
  if self._source == eve.state.notepad.workspace then
    return std.path.locate_workspace_filepath("notepad.json")
  end
  return ""
end

---@return integer
function M:size()
  return #self:_ensure_data().orders
end

---@param uuid string|nil
---@return integer
function M:indexof(uuid)
  if uuid == nil then
    return -1
  end
  local data = self:_ensure_data()
  for index, target in ipairs(data.orders) do
    if target == uuid then
      return index
    end
  end
  return -1
end

---@param index integer
---@return string|nil, std.t.INotepadItem|nil
function M:at(index)
  local data = self:_ensure_data()
  local uuid = data.orders[index]
  return uuid, uuid and data.items[uuid] or nil
end

---@return integer, string|nil
function M:current()
  local data = self:_ensure_data()
  return self:indexof(data.active_uuid), data.active_uuid
end

---@return std.t.INotepadItem|nil
function M:current_item()
  local data = self:_ensure_data()
  return data.active_uuid and data.items[data.active_uuid] or nil
end

---@param uuid string
---@return std.t.INotepadItem|nil
function M:get(uuid)
  return self:_ensure_data().items[uuid]
end

---@return fun():std.t.INotepadItem|nil, integer|nil
function M:iterator()
  local data = self:_ensure_data()
  local index = 0
  return function()
    index = index + 1
    local uuid = data.orders[index]
    return uuid and data.items[uuid] or nil, uuid and index or nil
  end
end

---@param uuid string|nil
---@return boolean
function M:focus_uuid(uuid)
  if uuid == nil then
    return false
  end
  local data = self:_ensure_data()
  if data.items[uuid] == nil or data.active_uuid == uuid then
    return data.active_uuid == uuid
  end

  self._o_active_uuid:next(uuid)
  self:_mark_dirty()
  return true
end

---@param index integer
---@return boolean
function M:focus_index(index)
  local uuid = self:_ensure_data().orders[index]
  return uuid ~= nil and self:focus_uuid(uuid) or false
end

---@param step integer
---@return boolean
function M:focus_step(step)
  local data = self:_ensure_data()
  local count = #data.orders
  if count == 0 then
    return false
  end
  local index_current = math.max(1, self:indexof(data.active_uuid))
  local index_next = std.fn.navigate_circular(index_current, step, count)
  return self:focus_index(index_next)
end

---@param name string|nil
---@return std.t.INotepadItem
function M:create(name)
  local trimmed = type(name) == "string" and vim.trim(name) or nil
  local item = self._source:create(#(trimmed or "") > 0 and trimmed or nil, nil)
  self:_mark_dirty()
  self:focus_uuid(item.uuid)
  return item
end

---@param name string
---@return std.t.INotepadItem|nil
function M:find_first_by_name(name)
  if type(name) ~= "string" then
    return nil
  end
  local target = vim.trim(name):lower()
  if #target == 0 then
    return nil
  end

  local data = self:_ensure_data()
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
  trimmed = #trimmed > 0 and trimmed or DEFAULT_ITEM_NAME

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

  self:_mark_dirty()
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

  if not self._source:remove(uuid) then
    return false
  end

  if data.active_uuid == uuid then
    data.active_uuid = data.orders[1]
    if data.active_uuid ~= nil then
      self:_notify_active_changed()
    end
  end

  self:_mark_dirty()
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

  if self._source:update(uuid, { name = name, content = item.content }) then
    self:_mark_dirty()
    return true
  end
  return false
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
  if item == nil or item.content == (content or "") then
    return false
  end

  return self._source:update(uuid, { name = item.name, content = content or "" })
end

---@param uuid_or_item string|std.t.INotepadItem|nil
---@param text string
---@return boolean
function M:append_content(uuid_or_item, text)
  if type(text) ~= "string" or #text == 0 then
    return false
  end

  local uuid = type(uuid_or_item) == "table" and uuid_or_item.uuid or uuid_or_item
  local data = self:_ensure_data()
  uuid = uuid or data.active_uuid

  local item = uuid and data.items[uuid] or nil
  if item == nil then
    return false
  end

  local new_content = (type(item.content) == "string" and item.content or "") .. text
  local ok = self:set_content(uuid, new_content)

  if ok and uuid == data.active_uuid then
    local bufnr = self:get_bufnr()
    if bufnr ~= nil then
      self:_render_active_item(bufnr)
    end
  end

  return ok
end

---@private
---@param step integer
---@return boolean
function M:_swap_step(step)
  local data = self:_ensure_data()
  local count = #data.orders
  if count <= 1 then
    return false
  end

  local index_current = self:indexof(data.active_uuid)
  if index_current < 1 then
    return false
  end

  local actual_step = math.max(1, step or vim.v.count1 or 1)
  local index_next = std.fn.navigate_circular(index_current, actual_step, count)
  if index_next == index_current then
    return false
  end

  data.orders[index_current], data.orders[index_next] = data.orders[index_next], data.orders[index_current]
  self:_mark_dirty()
  return true
end

---@param step integer|nil
---@return boolean
function M:swap_left(step)
  return self:_swap_step(-(step or 1))
end

---@param step integer|nil
---@return boolean
function M:swap_right(step)
  return self:_swap_step(step or 1)
end

---@return boolean
function M:flush()
  return self._source:flush()
end

---@private
---@return nil
function M:_dispose_subscriptions()
  if self._subscription_active ~= nil then
    self._subscription_active:unsubscribe()
    self._subscription_active = nil
  end
  if self._subscription_winbar ~= nil then
    self._subscription_winbar:unsubscribe()
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
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  uuid = uuid or self:_ensure_data().active_uuid
  if uuid ~= nil then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    self:set_content(uuid, table.concat(lines, "\n"))
  end
end

---@private
---@param bufnr                          integer
---@return nil
function M:_render_active_item(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local data = self:_ensure_data()
  local uuid = data.active_uuid
  vim.b[bufnr][BUFFER_VAR_NAME] = uuid

  local item = uuid and self:get(uuid) or nil
  local lines = (item ~= nil and #item.content > 0) and vim.split(item.content, "\n", { plain = true }) or { "" }

  self._suspend_sync = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modified = false
  self._suspend_sync = false
end

---@private
---@return nil
function M:_on_text_changed()
  if self._suspend_sync then
    return
  end
  local bufnr = self:get_bufnr()
  if bufnr ~= nil then
    self:_sync_content_from_buf(bufnr, self:_ensure_data().active_uuid)
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
  local bufnr = self._bufnr
  return bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) and bufnr or nil
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
  local winnr = self._winnr
  return winnr ~= nil and vim.api.nvim_win_is_valid(winnr) and winnr or nil
end

---@private
---@return eve.builtin.box.IDimension
function M:measure_rect()
  local columns = vim.o.columns
  local desired_width = math.min(132, math.floor(columns * 0.9 + 0.5))
  local desired_height = math.floor(vim.o.lines * 0.8 + 0.5)
  local min_width = math.min(self.min_width, columns)
  local min_height = math.min(self.min_height, vim.o.lines)
  desired_width = math.min(math.max(min_width, desired_width), columns)
  desired_height = math.min(math.max(min_height, desired_height), vim.o.lines - 2)

  return eve.box.measure(desired_width, desired_height, {
    position = "center",
    rows = vim.o.lines,
    cols = columns,
    max_width = desired_width,
    max_height = desired_height,
    min_width = min_width,
    min_height = min_height,
  })
end

---@private
---@param winhighlight string|nil
---@return string
function M:_normalize_winhighlight(winhighlight)
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

---@private
---@return integer
function M:ensure_win()
  local bufnr = self:ensure_buf()
  local rect = self:measure_rect()
  local winblend = eve.context.theme.get_float_winblend()

  self.win_opts.winhighlight = self:_normalize_winhighlight(self.win_opts.winhighlight)

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

  local winnr = self:get_winnr()
  local is_new_win = winnr == nil

  if winnr == nil then
    winnr = vim.api.nvim_open_win(bufnr, true, config)
    self._winnr = winnr
    eve.win.set_type(winnr, eve.win.Types.TEXTAREA)
  else
    vim.wo[winnr].winfixbuf = false
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
  if bufnr ~= nil then
    self:_sync_content_from_buf(bufnr, self:_ensure_data().active_uuid)
  end
  return bufnr
end

---@return boolean
function M:save()
  local bufnr = self:sync_active_content()

  local filepath = self:get_filepath()
  if #filepath > 0 then
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
  return winnr ~= nil and vim.api.nvim_get_current_win() == winnr
end

---@return nil
function M:resize()
  local winnr = self:get_winnr()
  if winnr == nil then
    return
  end

  local rect = self:measure_rect()
  vim.wo[winnr].winfixbuf = false

  local resize = eve.state.maximized.resolve_resize_config(winnr, {
    relative = "editor",
    anchor = "NW",
    row = rect.row,
    col = rect.col,
    width = rect.width,
    height = rect.height,
  }, nil)

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
