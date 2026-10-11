---@diagnostic disable: invisible
---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.picker.composer.list" ---@type string

local Source = require("era.view.result_source")
local ResultTree = require("era.view.result_tree")
local LEAF = { nodetype = "leaf" }
local PRESENTATION = {}

---@alias era.m.picker.composer.list.IOnCancel
---| fun(self: era.m.picker.ListComposer): nil

---@alias era.m.picker.composer.list.IOnClosed
---| fun(self: era.m.picker.ListComposer): nil

---@alias era.m.picker.composer.list.IOnConfirm
---| fun(self: era.m.picker.ListComposer, item: era.m.picker.composer.list.IItem|nil): nil

---@alias era.m.picker.composer.list.IOnDisposed
---| fun(): nil

---@alias era.m.picker.composer.list.IOnFocused
---| fun(self: era.m.picker.ListComposer): nil

---@alias era.m.picker.composer.list.IOnHidden
---| fun(self: era.m.picker.ListComposer): nil

---@alias era.m.picker.composer.list.IOnRefresh
---| fun(self: era.m.picker.ListComposer, force: boolean): nil

---@alias era.m.picker.composer.list.IRenderPreview
---| fun(self: era.m.picker.ListComposer, bufnr: integer, force: boolean): era.m.picker.preview.IDrawResult

---@class era.m.picker.composer.list.IPresentation
---@field public label                  ?string
---@field public highlights             ?stl.t.IHighlightInline[]
---@field public overlay                ?table[]
---@field public match_regions          ?integer[][] Source byte start/end and displayed byte start.

---@alias era.m.picker.composer.list.IPresent
---| fun(self: era.m.picker.ListComposer, item: era.m.picker.composer.list.IItem): era.m.picker.composer.list.IPresentation

---@class era.m.picker.composer.list.IItem
---@field public uuid                   string
---@field public text                   string
---@field public text_lower             string
---@field public highlights             ?stl.t.IHighlightInline[]

---@class era.m.picker.composer.list.IResetData
---@field public items                  era.m.picker.composer.list.IItem[]
---@field public uuid_present           string|nil
---@field public uuid_current           string|nil

----------------------------------------------------------------------------------------------------

---@class era.m.picker.IListComposerProps
---@field public uuid                   ?string
---@field public name                   string
---@field public autosort               ?boolean
---@field public permanent              boolean
---@field public title                  string
---@field public height                 ?number
---@field public width                  ?number
---
---@field public keymaps_common         ?stl.t.IKeymap[]
---@field public keymaps_finder         ?stl.t.IKeymap[]
---@field public keymaps_preview        ?stl.t.IKeymap[]
---@field public keymaps_result         ?stl.t.IKeymap[]
---
---@field public flag_fuzzy             stl.c.Observable
---@field public flag_regex             stl.c.Observable
---@field public flag_case_sensitive    stl.c.Observable
---@field public flags_append           era.m.picker.result.IFlagItemRaw[]|nil
---@field public flags_prepend          era.m.picker.result.IFlagItemRaw[]|nil
---@field public flags_start_index      ?0|1
---
---@field public search_pattern         stl.c.Observable
---@field public search_pattern_history ?stl.c.History
---
---@field public render_preview         ?era.m.picker.composer.list.IRenderPreview
---@field public present                ?era.m.picker.composer.list.IPresent
---
---@field public on_cancel              ?era.m.picker.composer.list.IOnCancel
---@field public on_closed              ?era.m.picker.composer.list.IOnClosed
---@field public on_confirm             ?era.m.picker.composer.list.IOnConfirm
---@field public on_disposed            ?era.m.picker.composer.list.IOnDisposed
---@field public on_focused             ?era.m.picker.composer.list.IOnFocused
---@field public on_hidden              ?era.m.picker.composer.list.IOnHidden
---@field public on_refresh             ?era.m.picker.composer.list.IOnRefresh

---@class era.m.picker.ListComposer
---@field public uuid                   string
---@field public fullname               string
---@field public title                  string
---
---@field public finder                 era.m.picker.Finder
---@field public result                 era.m.picker.Result
---@field public preview                era.m.picker.Preview|nil
---
---@field public flag_fuzzy             stl.c.Observable
---@field public flag_regex             stl.c.Observable
---@field public flag_case_sensitive    stl.c.Observable
---
---@field protected _disposed           boolean
---@field protected _composer           era.m.picker.BasicComposer
---@field protected _scheduler_match    stl.c.Scheduler
---
---@field protected _treeview           era.view.ResultTree
---@field protected _payload_version    integer
---@field protected _preparing          ?integer
---
---@field protected _autosort           boolean
---@field protected _items              era.m.picker.composer.list.IItem[]
---@field protected _matches            dot.t.IScoredMatch[]
---@field protected _matched_input      string
---@field protected _uuid_current       string|nil
---@field protected _uuid_present       string|nil
---
---@field protected _on_confirm         era.m.picker.composer.list.IOnConfirm|nil
---@field protected _on_disposed        era.m.picker.composer.list.IOnDisposed
---@field protected _observer_unsubs    stl.c.IUnsubscribable[]|nil
local M = {}
M.__index = M
---@param props                         era.m.picker.IListComposerProps
---@return era.m.picker.ListComposer
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local picker_uuid = props.uuid or yoz.fn.uuid() ---@type string
  local autosort = props.autosort ~= false ---@type boolean
  local permanent = props.permanent ---@type boolean
  local title = props.title ---@type string
  local height = props.height ---@type number|nil
  local width = props.width ---@type number|nil

  local search_pattern = props.search_pattern ---@type stl.c.Observable
  local search_pattern_history = props.search_pattern_history ---@type stl.c.History|nil

  local keymaps_common = props.keymaps_common ---@type stl.t.IKeymap[]|nil
  local keymaps_finder = props.keymaps_finder ---@type stl.t.IKeymap[]|nil
  local keymaps_preview = props.keymaps_preview ---@type stl.t.IKeymap[]|nil
  local keymaps_result = props.keymaps_result ---@type stl.t.IKeymap[]|nil

  local flag_fuzzy = props.flag_fuzzy ---@type stl.c.Observable
  local flag_regex = props.flag_regex ---@type stl.c.Observable
  local flag_case_sensitive = props.flag_case_sensitive ---@type stl.c.Observable
  local flags_append = props.flags_append ---@type era.m.picker.result.IFlagItemRaw[]|nil
  local flags_prepend = props.flags_prepend ---@type era.m.picker.result.IFlagItemRaw[]|nil
  local flags_start_index = props.flags_start_index ---@type 0|1|nil

  local on_cancel = props.on_cancel or stl.fn.noop ---@type era.m.picker.composer.list.IOnCancel
  local on_closed = props.on_closed or stl.fn.noop ---@type era.m.picker.composer.list.IOnClosed
  local on_confirm = props.on_confirm ---@type era.m.picker.composer.list.IOnConfirm|nil
  local on_disposed = props.on_disposed or stl.fn.noop ---@type era.m.picker.composer.list.IOnDisposed
  local on_focused = props.on_focused or stl.fn.noop ---@type era.m.picker.composer.list.IOnFocused
  local on_hidden = props.on_hidden or stl.fn.noop ---@type era.m.picker.composer.list.IOnHidden
  local on_refresh = props.on_refresh or stl.fn.noop ---@type era.m.picker.composer.list.IOnRefresh

  local present = props.present
  local render_preview = props.render_preview
  local self = setmetatable({ _disposed = false, _payload_version = 0, _matches = {} }, M)
  local treeview
  treeview = ResultTree.new({
    name = fullname,
    tree = Source.new("list"),
    present = function(key, data)
      if key == "list" then
        return { label = "", fields = { payload_version = data.payload_version } }
      end
      local item = treeview.source.payloads[key]
      local display = item and present and present(self, item) or PRESENTATION
      local highlights = display.highlights or item and item.highlights
      local fields
      if highlights and #highlights > 0 or display.overlay or display.match_regions then
        fields = { highlights = highlights, overlay = display.overlay, match_regions = display.match_regions }
      end
      return {
        label = display.label or item and item.text or data,
        fields = fields,
      }
    end,
  })
  self._treeview = treeview

  local scheduler_match = stl.c.Scheduler.new({
    name = string.format("%s#match", fullname),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = stl.fn.falsy,
    value = stl.c.Observable.from_value(true),
    task = function()
      if self._preparing then
        return
      end
      local input = search_pattern:snapshot() ---@type string
      self:__match__(input)
      self._composer:mark_result_dirty()
    end,
  })

  local actions = {
    on_confirm = function()
      if on_confirm ~= nil then
        on_confirm(self, self:retrieve(self._composer:get_result_lnum()))
      end
    end,
  }

  local flags = {} ---@type era.m.picker.result.IFlagItemRaw[]
  do
    local function add_flags(target, source, prefix)
      if source then
        for _, flag in ipairs(source) do
          target[#target + 1] = {
            desc = string.format("%s: %s", prefix, flag.desc),
            callback = flag.callback,
            snapshot = flag.snapshot,
          }
        end
      end
    end

    add_flags(flags, flags_prepend, name)
    flags[#flags + 1] = {
      desc = string.format("%s: fuzzy", name),
      callback = function()
        flag_fuzzy:next(not flag_fuzzy:snapshot())
      end,
      snapshot = function()
        return stl.icon.symbols.flag_fuzzy, flag_fuzzy:snapshot() and "picker_flag_blue" or "picker_flag_grey"
      end,
    }
    flags[#flags + 1] = {
      desc = string.format("%s: sensitive", name),
      callback = function()
        flag_case_sensitive:next(not flag_case_sensitive:snapshot())
      end,
      snapshot = function()
        return stl.icon.symbols.flag_case_sensitive,
          flag_case_sensitive:snapshot() and "picker_flag_blue" or "picker_flag_grey"
      end,
    }
    flags[#flags + 1] = {
      desc = string.format("%s: regex", name),
      callback = function()
        flag_regex:next(not flag_regex:snapshot())
      end,
      snapshot = function()
        return stl.icon.symbols.flag_regex, flag_regex:snapshot() and "picker_flag_blue" or "picker_flag_grey"
      end,
    }
    add_flags(flags, flags_append, name)
  end

  ---@type stl.t.IKeymap[]
  local preset_ks_common = {
    {
      modes = { "i", "n", "x" },
      key = "<enter>",
      desc = "list: confirm",
      callback = actions.on_confirm,
    },
    {
      modes = { "i", "n", "x" },
      key = "<2-LeftMouse>",
      desc = "list: confirm",
      callback = function()
        local result_winnr = self._composer.result:get_winnr() ---@type integer|nil
        if result_winnr ~= nil and vim.api.nvim_win_is_valid(result_winnr) then
          local cursor = vim.fn.getmousepos()
          if cursor.winid == result_winnr then
            actions.on_confirm()
          end
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<Tab>",
      desc = "list: noop",
      callback = stl.fn.noop,
    },
  }

  ---@type stl.t.IKeymap[]
  local preset_ks_finder = {}

  ---@type stl.t.IKeymap[]
  local preset_ks_result = {}

  ---@type stl.t.IKeymap[]
  local preset_ks_preview = {}

  local composer = era.m.picker.BasicComposer.new({
    uuid = picker_uuid,
    name = fullname,
    permanent = permanent,

    flags = flags,
    flags_start_index = flags_start_index,
    height = height,
    width = width,

    keymaps_common = keymaps_common and vim.list_extend(preset_ks_common, keymaps_common) or preset_ks_common,
    keymaps_finder = keymaps_finder and vim.list_extend(preset_ks_finder, keymaps_finder) or preset_ks_finder,
    keymaps_result = keymaps_result and vim.list_extend(preset_ks_result, keymaps_result) or preset_ks_result,
    keymaps_preview = keymaps_preview and vim.list_extend(preset_ks_preview, keymaps_preview) or preset_ks_preview,

    search_pattern = search_pattern,
    search_pattern_history = search_pattern_history,
    finder_title = title,

    result_number = false,

    result_tree = treeview,
    render_result = function()
      if self._preparing then
        return
      end
      local all_rows = self._matched_input == ""
      local orders
      if not all_rows then
        orders = {}
        for _, match in ipairs(self._matches) do
          orders[#orders + 1] = "item:" .. match.uuid
        end
      end
      return treeview:publish({ mode = "list", rootuuid = "list", orders = orders, all_rows = all_rows })
    end,
    on_result_rendered = function()
      self:__refresh_uuid_present__()
    end,

    ---@type era.m.picker.preview.IDraw|nil
    render_preview = render_preview and function(bufnr, force)
      return render_preview(self, bufnr, force)
    end or nil,

    on_cancel = function()
      on_cancel(self)
    end,
    on_closed = function()
      on_closed(self)
    end,
    on_disposed = function()
      self:dispose()
    end,
    on_focused = function()
      on_focused(self)
    end,
    on_hidden = function()
      on_hidden(self)
    end,
    on_refresh = function(composer, force)
      on_refresh(self, force)
      composer:mark_preview_dirty()
      composer:mark_result_flags_dirty()
      composer:mark_result_dirty()
    end,
  })

  self.uuid = picker_uuid
  self.fullname = fullname
  self.title = title

  self.finder = composer.finder
  self.result = composer.result
  self.preview = composer.preview

  self.flag_fuzzy = flag_fuzzy
  self.flag_regex = flag_regex
  self.flag_case_sensitive = flag_case_sensitive

  self._disposed = false
  self._composer = composer
  self._scheduler_match = scheduler_match
  self._search_pattern = search_pattern

  self._autosort = autosort
  self._items = {}
  self._matches = {}
  self._uuid_current = nil
  self._uuid_present = nil

  self._on_confirm = on_confirm
  self._on_disposed = on_disposed
  self._observer_unsubs = nil

  local observer_unsubs = {} ---@type stl.c.IUnsubscribable[]

  observer_unsubs[#observer_unsubs + 1] = stl.fn.observe(
    { search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive },
    function()
      if not self._disposed and not composer:isdisposed() then
        composer:mark_result_flags_dirty()
      end
    end,
    true
  )
  observer_unsubs[#observer_unsubs + 1] = stl.fn.observe(
    { search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive },
    function()
      if not self._disposed and not composer:isdisposed() then
        scheduler_match:schedule()
      end
    end
  )
  observer_unsubs[#observer_unsubs + 1] = stl.fn.observe({ composer.result.lnum_current }, function()
    if self._disposed or composer:isdisposed() then
      return
    end
    local lnum = composer.result.lnum_current:snapshot() ---@type integer
    local item = self:retrieve(lnum)
    if item then
      self._uuid_current = item.uuid
    end
  end)
  self._observer_unsubs = observer_unsubs

  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  local fullname = self.fullname ---@type string
  local on_disposed = self._on_disposed ---@type era.m.picker.composer.list.IOnDisposed
  local composer = self._composer
  local scheduler_match = self._scheduler_match
  local observer_unsubs = self._observer_unsubs ---@type stl.c.IUnsubscribable[]|nil
  self._observer_unsubs = nil

  local ok_unsubs = true ---@type boolean
  local error_unsubs = {} ---@type table[]
  if observer_unsubs ~= nil then
    for index, unsub in ipairs(observer_unsubs) do
      local ok, err = pcall(unsub.unsubscribe, unsub)
      if not ok then
        ok_unsubs = false
        error_unsubs[#error_unsubs + 1] = { index = index, error = err }
      end
    end
  end

  local ok1, error1 = pcall(scheduler_match.dispose, scheduler_match)
  local ok2, error2 = pcall(composer.dispose, composer)
  self._treeview:dispose()
  vim.schedule(function()
    local ok3, error3 = pcall(on_disposed)

    if not (ok1 and ok2 and ok3) then
      stl.reporter.error({
        from = fullname,
        subject = "dispose",
        message = "Failed to dispose",
        details = {
          error1 = not ok1 and error1 or nil,
          error2 = not ok2 and error2 or nil,
          error3 = not ok3 and error3 or nil,
          error_observers = not ok_unsubs and error_unsubs or nil,
        },
      })
    end
  end)

  self.finder = nil
  self.result = nil
  self.preview = nil

  self.flag_fuzzy = nil
  self.flag_regex = nil
  self.flag_case_sensitive = nil

  self._composer = nil
  self._scheduler_match = nil
  self._search_pattern = nil

  self._treeview = nil

  self._autosort = nil
  self._items = nil
  self._matches = nil
  self._matched_input = nil
  self._uuid_current = nil
  self._uuid_present = nil

  self._on_confirm = nil
  self._on_disposed = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isfocused()
  return self._composer:isfocused()
end

---@return boolean
function M:isvisible()
  return self._composer:isvisible()
end

---@return nil
function M:close()
  self._composer:close()
end

---@return nil
function M:focus()
  self._composer:focus()
end

---@return nil
function M:hide()
  self._composer:hide()
end

---@return nil
function M:resize()
  self._composer:resize()
end

---@param lnum                          integer
---@return era.m.picker.composer.list.IItem|nil
function M:retrieve(lnum)
  self:__health__()
  local key = self._treeview:retrieve_uuid(lnum)
  return key and self._treeview:payload(key)
end

---@return era.m.picker.ListComposer
function M:mark_result_dirty()
  self:__health__()
  self._treeview:invalidate()
  self._composer:mark_result_dirty()
  return self
end

---@return era.m.picker.ListComposer
function M:mark_result_flags_dirty()
  self:__health__()
  self._composer:mark_result_flags_dirty()
  return self
end

---@param uuid                          string|nil
---@return era.m.picker.ListComposer
function M:reset_uuid_current(uuid)
  self:__health__()
  self._uuid_current = uuid ---@type string|nil
  self:__refresh_uuid_current__()
  return self
end

---@param uuid                          string|nil
---@return era.m.picker.ListComposer
function M:reset_uuid_present(uuid)
  self:__health__()
  self._uuid_present = uuid ---@type string|nil
  self:__refresh_uuid_present__()
  return self
end

---@param data                          era.m.picker.composer.list.IResetData
---@return era.m.picker.ListComposer
function M:reset_data(data)
  self:__health__()

  local items = vim.list_slice(data.items)
  self._payload_version = self._payload_version + 1
  local version = self._payload_version
  self._preparing = version
  self._uuid_present = data.uuid_present
  self._uuid_current = data.uuid_current or self._uuid_current
  local source = Source.new("list", { payload_version = version })
  local entries = { list = { nodetype = "container" } }
  local index = 1
  ---@return nil
  local function prepare()
    if self._disposed or self._preparing ~= version then
      return
    end
    local ok, done = pcall(function()
      local deadline = vim.uv.hrtime() + 2000000
      while index <= #items do
        local item = items[index]
        assert(type(item.uuid) == "string", "list item identities must be strings")
        local key = "item:" .. item.uuid
        source:insert("list", key, item.text)
        source.payloads[key], entries[key] = item, LEAF
        index = index + 1
        if vim.uv.hrtime() >= deadline then
          return false
        end
      end
      return true
    end)
    if not ok then
      self._preparing = nil
      stl.reporter.error({ from = __module_name__, subject = "list preparation", message = tostring(done) })
    elseif not done then
      vim.schedule(prepare)
    else
      self._preparing = nil
      self._items = items
      self._treeview.source, self._treeview.entries = source, entries
      self._treeview:invalidate()
      self:__match__(self._search_pattern:snapshot())
      if self._uuid_current then
        self._treeview:focus_key("item:" .. self._uuid_current)
      end
      self._composer:mark_result_dirty()
    end
  end
  prepare()

  return self
end

----------------------------------------------------------------------------------------------------
---@protected
---@return nil
function M:__health__()
  if self._disposed then
    error(string.format("[%s#%s] already been disposed.", __module_name__, self.fullname))
  end
end

---@protected
---@param input                         string
---@return nil
function M:__match__(input)
  local items = self._items
  local matches = {}

  if #input > 0 then
    local case_sensitive = self.flag_case_sensitive:snapshot()
    local use_fuzzy = self.flag_fuzzy:snapshot()
    local use_regex = self.flag_regex:snapshot()

    local lines = {}
    local search_pattern = case_sensitive and input or input:lower()

    for _, item in ipairs(items) do
      lines[#lines + 1] = case_sensitive and item.text or item.text_lower
    end

    ---@type yoz.search.ISearchInLinesOptions
    local search_params = {
      pattern = search_pattern,
      lines = lines,
      flag_fuzzy = use_fuzzy,
      flag_regex = use_regex,
      flag_case_sensitive = case_sensitive,
    }
    local search_result, search_err = yoz.search.search_in_lines(search_params) ---@type yoz.search.ISearchTextResult|nil, string|nil
    if search_err then
      stl.reporter.error({
        from = __module_name__,
        subject = "search_in_lines failed",
        details = {
          error = search_err,
          params = search_params,
        },
      })
      search_result = nil
    end
    if search_result and search_result.lines then
      local by_line = {}
      for _, entry in ipairs(search_result.lines) do
        local lnum = entry.lnum ---@type integer
        local match = by_line[lnum]
        if match then
          match.score = math.max(match.score, entry.score)
          vim.list_extend(match.matches, entry.matches)
        else
          match = { order = lnum, uuid = items[lnum].uuid, score = entry.score, matches = entry.matches }
          by_line[lnum] = match
          matches[#matches + 1] = match
        end
      end
    end
  end

  if self._autosort and #input > 0 then
    table.sort(matches, function(a, b)
      return a.score == b.score and a.order < b.order or a.score > b.score
    end)
  end

  self._matches = matches
  self._matched_input = input
  local native_matches = {}
  for _, match in ipairs(matches) do
    if #match.matches > 0 then
      native_matches["item:" .. match.uuid] = match
    end
  end
  self._treeview._matches = native_matches
  if self._treeview.view then
    self._treeview.view:refresh_decorations()
  end
end

---@protected
---@return nil
function M:__refresh_uuid_current__()
  local uuid = self._uuid_current ---@type string|nil
  if uuid == nil then
    return
  end

  self._treeview:focus_key("item:" .. uuid)
end

---@protected
---@return nil
function M:__refresh_uuid_present__()
  local uuid = self._uuid_present ---@type string|nil
  if uuid == nil then
    self._composer.result:set_lnum_present(-1)
    return
  end

  local lnum = self._treeview:retrieve_lnum("item:" .. uuid)
  self._composer.result:set_lnum_present(lnum or -1)
end

return M
