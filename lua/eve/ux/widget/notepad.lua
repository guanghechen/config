---@diagnostic disable: invisible

local __module_name__ = "eve.ux.widget.notepad" ---@type string

local DEFAULT_WIDTH = 0.6
local DEFAULT_HEIGHT = 0.6
local MAX_WIDTH = 0.9
local MAX_HEIGHT = 0.9
local MIN_WIDTH = 60
local MIN_HEIGHT = 12
local WIN_TITLE = " Notepad "

local TEXT_CHANGED_EVENTS = { "TextChanged", "TextChangedI", "TextChangedP" } ---@type string[]

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
---@field private _active_uuid          string|nil
---@field private _suspend_sync         boolean
---@field private _buf_autocmds         integer[]
---@field private _nvimbar              eve.ux.nvimbar.Nvimbar|nil
---@field private _subscription_active  std.collection.IUnsubscribable|nil
---@field private _subscription_winbar  std.collection.IUnsubscribable|nil
local Notepad = {}
Notepad.__index = Notepad

---@param props                         eve.ux.widget.notepad.IProps|nil
---@return eve.ux.widget.Notepad
function Notepad.new(props)
  props = props or {}
  eve.notepad.load()

  local self = setmetatable({}, Notepad)
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
  self.win_opts = vim.tbl_extend("force", {}, props.win_opts or {})

  self._bufnr = nil
  self._winnr = nil
  local _, uuid = eve.notepad.current()
  self._active_uuid = uuid
  self._suspend_sync = false
  self._buf_autocmds = {}
  local widget = self ---@type eve.ux.widget.Notepad
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
  self._nvimbar:place("left", eve.ux.nvimbar.component.notepad.items("f_wl"), 100)

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

  self._subscription_active = eve.notepad.o_active_uuid:subscribe(
    std.Subscriber.new({
      on_next = function(next_uuid)
        widget:_on_active_uuid(next_uuid)
      end,
    }),
    false
  )

  return self
end

---@private
---@return nil
function Notepad:_dispose_subscriptions()
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
function Notepad:_clear_buf_autocmds()
  for _, id in ipairs(self._buf_autocmds) do
    pcall(vim.api.nvim_del_autocmd, id)
  end
  self._buf_autocmds = {}
end

---@private
---@param bufnr                          integer
---@param uuid                           string|nil
---@return nil
function Notepad:_sync_content_from_buf(bufnr, uuid)
  uuid = uuid or self._active_uuid
  if uuid == nil then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local content = table.concat(lines, "\n") ---@type string
  eve.notepad.set_content(uuid, content)
end

---@private
---@param bufnr                          integer
---@return nil
function Notepad:_render_active_item(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local uuid = self._active_uuid ---@type string|nil
  local item = uuid ~= nil and eve.notepad.get(uuid) or nil ---@type eve.builtin.notepad.INotepadItem|nil
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
function Notepad:_on_text_changed()
  if self._suspend_sync then
    return
  end

  local bufnr = self:get_bufnr()
  if bufnr ~= nil then
    self:_sync_content_from_buf(bufnr, self._active_uuid)
  end
end

---@private
---@param bufnr                          integer
---@return nil
function Notepad:_attach_autocmds(bufnr)
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
function Notepad:_on_active_uuid(uuid)
  uuid = uuid ~= nil and #uuid > 0 and uuid or nil
  if self._active_uuid == uuid then
    return
  end

  local bufnr = self:get_bufnr()
  if bufnr ~= nil and self._active_uuid ~= nil then
    self:_sync_content_from_buf(bufnr, self._active_uuid)
  end

  self._active_uuid = uuid
  if bufnr ~= nil then
    self:_render_active_item(bufnr)
  end

  if self._nvimbar ~= nil then
    self._nvimbar:render()
  end
end

---@private
---@return integer|nil
function Notepad:get_bufnr()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end
end

---@private
---@return integer
function Notepad:ensure_buf()
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

  ---@type std.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i", "n", "v" },
      key = "<C-s>",
      desc = "notepad: save",
      callback = function()
        self:save()
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>s",
      aliases = { "<D-s>", "<M-s>" },
      desc = "notepad: save",
      callback = function()
        self:save()
      end,
    },
    {
      modes = { "n" },
      key = "q",
      desc = "notepad: quit",
      callback = function()
        self:hide()
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-n>",
      desc = "notepad: create item",
      callback = function()
        vim.cmd(eve.command.definitions.notepad.create.uuid)
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-r>",
      desc = "notepad: rename item",
      callback = function()
        vim.cmd(eve.command.definitions.notepad.rename.uuid)
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-d>",
      desc = "notepad: destroy item",
      callback = function()
        vim.cmd(eve.command.definitions.notepad.destroy.uuid)
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-,>",
      desc = eve.command.definitions.notepad.focus_left.desc,
      callback = function()
        vim.cmd(eve.command.definitions.notepad.focus_left.uuid)
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-.>",
      desc = eve.command.definitions.notepad.focus_right.desc,
      callback = function()
        vim.cmd(eve.command.definitions.notepad.focus_right.uuid)
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-S-,>",
      desc = eve.command.definitions.notepad.swap_left.desc,
      callback = function()
        vim.cmd(eve.command.definitions.notepad.swap_left.uuid)
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-S-.>",
      desc = eve.command.definitions.notepad.swap_right.desc,
      callback = function()
        vim.cmd(eve.command.definitions.notepad.swap_right.uuid)
      end,
    },
  }

  for index = 1, 9, 1 do
    local key = string.format("<C-%d>", index) ---@type string
    local definition = eve.command.definitions.notepad["focus_" .. tostring(index)] ---@type eve.builtin.command.IDefinition
    keymaps[#keymaps + 1] = {
      modes = { "i", "n", "v" },
      key = key,
      desc = definition.desc,
      callback = function()
        vim.cmd(definition.uuid)
      end,
    }
  end

  eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
  return bufnr
end

---@private
---@return integer|nil
function Notepad:get_winnr()
  local winnr = self._winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    return winnr
  end
end

---@private
---@return eve.builtin.box.IDimension
function Notepad:measure_rect()
  ---@type eve.builtin.box.IRestriction
  local restriction = {
    position = "center",
    rows = vim.o.lines,
    cols = vim.o.columns,
    max_width = self.max_width,
    max_height = self.max_height,
    min_width = self.min_width,
    min_height = self.min_height,
  }
  return eve.box.measure(self.width, self.height, restriction)
end

---@private
---@return integer
function Notepad:ensure_win()
  local bufnr = self:ensure_buf()
  local rect = self:measure_rect()
  local winblend = eve.context.theme.get_float_winblend() ---@type integer

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
  if winnr == nil then
    winnr = vim.api.nvim_open_win(bufnr, true, config)
    self._winnr = winnr
    eve.win.set_type(winnr, eve.win.Types.TEXTAREA)
  else
    vim.wo[winnr].winfixbuf = false
    vim.api.nvim_win_set_config(winnr, config)
    vim.api.nvim_win_set_buf(winnr, bufnr)
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
    vim.wo[winnr][key] = value
  end
  vim.wo[winnr].winfixbuf = true

  if self._nvimbar ~= nil then
    self._nvimbar:render()
  end

  return winnr
end

---@return nil
function Notepad:save()
  local bufnr = self:get_bufnr()
  if bufnr == nil then
    return
  end

  self:_sync_content_from_buf(bufnr, self._active_uuid)
  eve.notepad.flush()
  vim.bo[bufnr].modified = false

  local filepath = eve.notepad.get_filepath() ---@type string|nil
  if filepath ~= nil and #filepath > 0 then
    vim.fn.mkdir(std.path.dirname(filepath), "p")
    local cwd = std.path.cwd() ---@type string
    local relative = std.path.relative(cwd, filepath, true) ---@type string
    std.reporter.info({
      from = __module_name__,
      subject = "save",
      message = string.format("Saved notepad to %s", relative),
    })
  end
end

---@return nil
function Notepad:focus()
  eve.widget.push(self)

  local winnr = self:ensure_win()
  if vim.api.nvim_get_current_win() ~= winnr then
    vim.api.nvim_set_current_win(winnr)
  end
end

---@return nil
function Notepad:show()
  self:focus()
end

---@return nil
function Notepad:hide()
  local winnr = self:get_winnr()
  self._winnr = nil
  eve.win.close(winnr)
end

---@return nil
function Notepad:close()
  self:hide()
end

---@return boolean
function Notepad:isvisible()
  return self:get_winnr() ~= nil
end

---@return boolean
function Notepad:isfocused()
  local winnr = self:get_winnr()
  if winnr == nil then
    return false
  end
  return vim.api.nvim_get_current_win() == winnr
end

---@return nil
function Notepad:resize()
  local winnr = self:get_winnr()
  if winnr == nil then
    return
  end

  local rect = self:measure_rect()
  vim.wo[winnr].winfixbuf = false
  vim.api.nvim_win_set_config(winnr, {
    relative = "editor",
    anchor = "NW",
    row = rect.row,
    col = rect.col,
    width = rect.width,
    height = rect.height,
  })
  vim.wo[winnr].winfixbuf = true

  if self._nvimbar ~= nil then
    self._nvimbar:render()
  end
end

---@return nil
function Notepad:toggle()
  if self:isvisible() then
    self:hide()
  else
    self:focus()
  end
end

---@return boolean
function Notepad:isdisposed()
  return false
end

---@return nil
function Notepad:dispose()
  self:_dispose_subscriptions()
  self:_clear_buf_autocmds()
  if self._nvimbar ~= nil then
    self._nvimbar:dispose()
    self._nvimbar = nil
  end
  self._bufnr = nil
  self._winnr = nil
end

return Notepad
