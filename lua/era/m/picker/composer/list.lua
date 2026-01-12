---@diagnostic disable: invisible
---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.picker.composer.list" ---@type string

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

---@alias era.m.picker.composer.list.IRenderResult
---| fun(self: era.m.picker.ListComposer, bufnr: integer, itemmap: table<string, era.m.picker.composer.list.IItem>, matches: dot.t.IScoredMatch[]): era.m.picker.composer.list.IRenderResultData

---@class era.m.picker.composer.list.IItem
---@field public uuid                   string
---@field public text                   string
---@field public text_lower             string
---@field public highlights             stl.t.IHighlightInline[]

---@class era.m.picker.composer.list.IResetData
---@field public items                  era.m.picker.composer.list.IItem[]
---@field public uuid_present           string|nil
---@field public uuid_current           string|nil

---@class era.m.picker.composer.list.IRenderResultData
---@field public uuids                  string[]

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
---@field public render_result          ?era.m.picker.composer.list.IRenderResult
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
---@field protected _lnum2uuid          string[]
---@field protected _uuid2lnum          table<string, integer>
---
---@field protected _autosort           boolean
---@field protected _items              era.m.picker.composer.list.IItem[]
---@field protected _itemmap            table<string, era.m.picker.composer.list.IItem>
---@field protected _matches            dot.t.IScoredMatch[]
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

  ---@type era.m.picker.composer.list.IRenderResult
  local render_result = props.render_result
    or function(_, bufnr, itemmap, matches)
      local lines = {} ---@type string[]
      local uuids = {} ---@type string[]

      for _, match in ipairs(matches) do
        local item = itemmap[match.uuid] ---@type era.m.picker.composer.list.IItem
        lines[#lines + 1] = item.text
        uuids[#uuids + 1] = item.uuid
      end

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local nsnr_content = dot.var.nsnr.picker_result ---@type integer
      local nsnr_matches = dot.var.nsnr.picker_matches ---@type integer

      for lnum, match in ipairs(matches) do
        local row = lnum - 1 ---@type integer
        local item = itemmap[match.uuid] ---@type era.m.picker.composer.list.IItem

        if item and item.highlights then
          for _, hl in ipairs(item.highlights) do
            vim.hl.range(bufnr, nsnr_content, hl.hlname, { row, hl.coll }, { row, hl.colr }, { priority = 10 })
          end
        end

        if match.matches then
          for _, m in ipairs(match.matches) do
            vim.hl.range(bufnr, nsnr_matches, "m_pk_matches", { row, m.l }, { row, m.r }, { priority = 30 })
          end
        end
      end

      ---@type era.m.picker.composer.list.IRenderResultData
      local data = { uuids = uuids }
      return data
    end

  ---@type era.m.picker.composer.list.IRenderPreview|nil
  local render_preview = props.render_preview

  local self = setmetatable({}, M)

  ---@return string|nil
  ---@return integer
  local function retrieve()
    local lnum = self._composer:get_result_lnum() ---@type integer
    local uuid = self._lnum2uuid[lnum] ---@type string|nil
    return uuid, lnum
  end

  local scheduler_match = stl.c.Scheduler.new({
    name = string.format("%s#match", fullname),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = stl.fn.falsy,
    value = stl.c.Observable.from_value(true),
    task = function()
      local input = search_pattern:snapshot() ---@type string
      self:__match__(input)
      self:mark_result_dirty()
    end,
  })

  local actions = {
    on_confirm = function()
      if on_confirm ~= nil then
        local uuid = retrieve() ---@type string|nil
        local item = uuid and self._itemmap[uuid] or nil ---@type era.m.picker.composer.list.IItem|nil
        on_confirm(self, item)
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

    render_result = function(bufnr)
      local data = render_result(self, bufnr, self._itemmap, self._matches)
      local uuids = data.uuids ---@type string[]

      local lnum2uuid = self._lnum2uuid ---@type string[]
      local uuid2lnum = self._uuid2lnum ---@type table<string, integer>

      local N1 = #lnum2uuid ---@type integer
      for lnum = 1, N1, 1 do
        local uuid = lnum2uuid[lnum] ---@type string
        uuid2lnum[uuid] = nil
      end

      local N2 = #uuids ---@type integer
      for lnum = 1, N2, 1 do
        local uuid = uuids[lnum] ---@type string
        lnum2uuid[lnum] = uuid
        uuid2lnum[uuid] = lnum
      end

      if N1 > N2 then
        stl.table.truncate_inline(lnum2uuid, N2)
      end

      local uuid_current = self._uuid_current ---@type string|nil
      local uuid_present = self._uuid_present ---@type string|nil
      local lnum_current = uuid_current and uuid2lnum[uuid_current] or nil ---@type integer|nil
      local lnum_present = uuid_present and uuid2lnum[uuid_present] or nil ---@type integer|nil
      return { lnum_current = lnum_current, lnum_present = lnum_present }
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

  self._lnum2uuid = {}
  self._uuid2lnum = {}

  self._autosort = autosort
  self._items = {}
  self._itemmap = {}
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
      composer:mark_result_flags_dirty()
    end,
    true
  )
  observer_unsubs[#observer_unsubs + 1] = stl.fn.observe(
    { search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive },
    function()
      scheduler_match:schedule()
    end
  )
  observer_unsubs[#observer_unsubs + 1] = stl.fn.observe({ composer.result.lnum_current }, function()
    local lnum = composer.result.lnum_current:snapshot() ---@type integer
    local uuid = self._lnum2uuid[lnum] ---@type string|nil
    if uuid ~= nil then
      self._uuid_current = uuid
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

  vim.schedule(function()
    local ok1, error1 = pcall(scheduler_match.dispose, scheduler_match)
    local ok2, error2 = pcall(composer.dispose, composer)
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

  self._lnum2uuid = nil
  self._uuid2lnum = nil

  self._autosort = nil
  self._items = nil
  self._itemmap = nil
  self._matches = nil
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
  local uuid = self._lnum2uuid[lnum] ---@type string|nil
  local item = uuid and self._itemmap[uuid] or nil ---@type era.m.picker.composer.list.IItem|nil
  return item
end

---@return era.m.picker.ListComposer
function M:mark_result_dirty()
  self:__health__()
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

  local items = data.items ---@type era.m.picker.composer.list.IItem[]
  local lnum_total = #items ---@type integer
  local itemmap = {} ---@type table<string, era.m.picker.composer.list.IItem>
  for _, item in ipairs(items) do
    itemmap[item.uuid] = item
  end

  self._items = items
  self._itemmap = itemmap
  self._composer.result.lnum_total:next(lnum_total)
  self._composer:mark_result_dirty()
  self._scheduler_match:schedule()

  vim.schedule(function()
    self:reset_uuid_current(data.uuid_current)
    self:reset_uuid_present(data.uuid_present)
  end)
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

  if #input == 0 then
    for order, item in ipairs(items) do
      matches[#matches + 1] = { order = order, uuid = item.uuid, score = 0, matches = {} }
    end
  else
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
      for _, entry in ipairs(search_result.lines) do
        local lnum = entry.lnum ---@type integer
        matches[#matches + 1] = {
          order = lnum,
          uuid = items[lnum].uuid,
          score = entry.score,
          matches = entry.matches,
        }
      end
    end
  end

  if self._autosort then
    table.sort(matches, function(a, b)
      return a.score == b.score and a.order < b.order or a.score > b.score
    end)
  end

  self._matches = matches
end

---@protected
---@return nil
function M:__refresh_uuid_current__()
  local uuid = self._uuid_current ---@type string|nil
  if uuid == nil then
    return
  end

  local lnum = self._uuid2lnum[uuid] ---@type integer|nil
  if lnum then
    self._composer.result:set_lnum_current(lnum)
  end
end

---@protected
---@return nil
function M:__refresh_uuid_present__()
  local uuid = self._uuid_present ---@type string|nil
  if uuid == nil then
    return
  end

  local lnum = self._uuid2lnum[uuid] ---@type integer|nil
  if lnum then
    self._composer.result:set_lnum_present(lnum)
  end
end

return M
