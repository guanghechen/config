---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker.composer.list" ---@type string

---@alias eve.ux.picker.composer.list.IOnCancel
---| fun(self: eve.ux.picker.ListComposer): nil

---@alias eve.ux.picker.composer.list.IOnClosed
---| fun(self: eve.ux.picker.ListComposer): nil

---@alias eve.ux.picker.composer.list.IOnConfirm
---| fun(self: eve.ux.picker.ListComposer, item: eve.ux.picker.composer.list.IItem|nil): nil

---@alias eve.ux.picker.composer.list.IOnDisposed
---| fun(): nil

---@alias eve.ux.picker.composer.list.IOnFocused
---| fun(self: eve.ux.picker.ListComposer): nil

---@alias eve.ux.picker.composer.list.IOnHidden
---| fun(self: eve.ux.picker.ListComposer): nil

---@alias eve.ux.picker.composer.list.IOnRefresh
---| fun(self: eve.ux.picker.ListComposer, force: boolean): nil

---@alias eve.ux.picker.composer.list.IPreviewRender
---| fun(self: eve.ux.picker.ListComposer, bufnr: integer): eve.ux.picker.preview.IDrawResult

---@alias eve.ux.picker.composer.list.IResultRender
---| fun(self: eve.ux.picker.ListComposer, bufnr: integer, itemmap: table<string, eve.ux.picker.composer.list.IItem>, matches: std.t.IScoredMatch[]): eve.ux.picker.composer.list.IResultRenderData

---@class eve.ux.picker.composer.list.IItem
---@field public uuid                   string
---@field public text                   string
---@field public text_lower             string
---@field public highlights             std.t.IHighlightInline[]

---@class eve.ux.picker.composer.list.IResetData
---@field public items                  eve.ux.picker.composer.list.IItem[]
---@field public uuid_present           string|nil
---@field public uuid_current           string|nil

---@class eve.ux.picker.composer.list.IResultRenderData
---@field public uuids                  string[]

----------------------------------------------------------------------------------------------------

---@class eve.ux.picker.IListComposerProps
---@field public uuid                   ?string
---@field public name                   string
---@field public permanent              boolean
---@field public preview                ?boolean
---@field public title                  string
---@field public height                 ?number
---@field public width                  ?number
---
---@field public keymaps_common         ?std.t.IKeymap[]
---@field public keymaps_finder         ?std.t.IKeymap[]
---@field public keymaps_preview        ?std.t.IKeymap[]
---@field public keymaps_result         ?std.t.IKeymap[]
---
---@field public flag_fuzzy             std.collection.IObservable
---@field public flag_regex             std.collection.IObservable
---@field public flag_sensitive         std.collection.IObservable
---@field public flags_append           eve.ux.picker.result.IFlagItemRaw[]|nil
---@field public flags_prepend          eve.ux.picker.result.IFlagItemRaw[]|nil
---@field public flags_start_index      ?0|1
---
---@field public finder_input           std.collection.IObservable
---@field public finder_input_history   ?std.collection.IHistory
---
---@field public result_render          ?eve.ux.picker.composer.list.IResultRender
---@field public preview_render         ?eve.ux.picker.composer.list.IPreviewRender
---
---@field public on_cancel              ?eve.ux.picker.composer.list.IOnCancel
---@field public on_closed              ?eve.ux.picker.composer.list.IOnClosed
---@field public on_confirm             ?eve.ux.picker.composer.list.IOnConfirm
---@field public on_disposed            ?eve.ux.picker.composer.list.IOnDisposed
---@field public on_focused             ?eve.ux.picker.composer.list.IOnFocused
---@field public on_hidden              ?eve.ux.picker.composer.list.IOnHidden
---@field public on_refresh             ?eve.ux.picker.composer.list.IOnRefresh

---@class eve.ux.picker.ListComposer
---@field public uuid                   string
---@field public fullname               string
---@field public title                  string
---
---@field public finder                 eve.ux.picker.Finder
---@field public result                 eve.ux.picker.Result
---@field public preview                eve.ux.picker.Preview|nil
---
---@field public flag_fuzzy             std.collection.IObservable
---@field public flag_regex             std.collection.IObservable
---@field public flag_sensitive         std.collection.IObservable
---
---@field protected _disposed           boolean
---@field protected _composer           eve.ux.picker.BasicComposer
---@field protected _retriever          eve.ux.picker.ListRetriever
---@field protected _scheduler_match    std.collection.Scheduler
---
---@field protected _items              eve.ux.picker.composer.list.IItem[]
---@field protected _itemmap            table<string, eve.ux.picker.composer.list.IItem>
---@field protected _matches            std.t.IScoredMatch[]
---@field protected _uuid_current       string|nil
---@field protected _uuid_present       string|nil
---
---@field protected _on_confirm         eve.ux.picker.composer.list.IOnConfirm|nil
---@field protected _on_disposed        eve.ux.picker.composer.list.IOnDisposed
local M = {}
M.__index = M

---@param props                         eve.ux.picker.IListComposerProps
---@return eve.ux.picker.ListComposer
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local picker_uuid = props.uuid or std.fn.uuid() ---@type string
  local permanent = props.permanent ---@type boolean
  local title = props.title ---@type string
  local height = props.height ---@type number|nil
  local width = props.width ---@type number|nil

  local finder_input = props.finder_input ---@type std.collection.IObservable
  local finder_input_history = props.finder_input_history ---@type std.collection.IHistory|nil

  local keymaps_common = props.keymaps_common ---@type std.t.IKeymap[]|nil
  local keymaps_finder = props.keymaps_finder ---@type std.t.IKeymap[]|nil
  local keymaps_preview = props.keymaps_preview ---@type std.t.IKeymap[]|nil
  local keymaps_result = props.keymaps_result ---@type std.t.IKeymap[]|nil

  local flag_fuzzy = props.flag_fuzzy ---@type std.collection.IObservable
  local flag_regex = props.flag_regex ---@type std.collection.IObservable
  local flag_sensitive = props.flag_sensitive ---@type std.collection.IObservable
  local flags_append = props.flags_append ---@type eve.ux.picker.result.IFlagItemRaw[]|nil
  local flags_prepend = props.flags_prepend ---@type eve.ux.picker.result.IFlagItemRaw[]|nil
  local flags_start_index = props.flags_start_index ---@type 0|1|nil

  local on_cancel = props.on_cancel or std.fn.noop ---@type eve.ux.picker.composer.list.IOnCancel
  local on_closed = props.on_closed or std.fn.noop ---@type eve.ux.picker.composer.list.IOnClosed
  local on_confirm = props.on_confirm ---@type eve.ux.picker.composer.list.IOnConfirm|nil
  local on_disposed = props.on_disposed or std.fn.noop ---@type eve.ux.picker.composer.list.IOnDisposed
  local on_focused = props.on_focused or std.fn.noop ---@type eve.ux.picker.composer.list.IOnFocused
  local on_hidden = props.on_hidden or std.fn.noop ---@type eve.ux.picker.composer.list.IOnHidden
  local on_refresh = props.on_refresh or std.fn.noop ---@type eve.ux.picker.composer.list.IOnRefresh

  ---@type eve.ux.picker.composer.list.IResultRender
  local result_render = props.result_render
    or function(_, bufnr, itemmap, matches)
      local lines = {} ---@type string[]
      local uuids = {} ---@type string[]

      for _, match in ipairs(matches) do
        local item = itemmap[match.uuid] ---@type eve.ux.picker.composer.list.IItem
        lines[#lines + 1] = item.text
        uuids[#uuids + 1] = item.uuid
      end

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local nsnr_content = eve.var.nsnr.picker_result ---@type integer
      local nsnr_matches = eve.var.nsnr.picker_matches ---@type integer

      for lnum, match in ipairs(matches) do
        local row = lnum - 1 ---@type integer
        local item = itemmap[match.uuid] ---@type eve.ux.picker.composer.list.IItem

        if item and item.highlights then
          for _, hl in ipairs(item.highlights) do
            vim.hl.range(bufnr, nsnr_content, hl.hlname, { row, hl.coll }, { row, hl.colr }, { priority = 10 })
          end
        end

        if match.matches then
          for _, m in ipairs(match.matches) do
            vim.hl.range(bufnr, nsnr_matches, "f_pk_matches", { row, m.l }, { row, m.r }, { priority = 30 })
          end
        end
      end

      ---@type eve.ux.picker.composer.list.IResultRenderData
      local data = { uuids = uuids }
      return data
    end

  ---@type eve.ux.picker.composer.list.IPreviewRender|nil
  local preview_render = props.preview_render

  local self = setmetatable({}, M)

  ---@type eve.ux.picker.ListRetriever
  local retriever = eve.ux.picker.ListRetriever.new({
    name = fullname,
  })

  ---@return string|nil
  ---@return integer
  local function retrieve()
    local lnum = self._composer:get_result_lnum() ---@type integer
    local uuid = self._retriever:retrieve_uuid(lnum) ---@type string|nil
    return uuid, lnum
  end

  local scheduler_match = std.Scheduler.new({
    name = string.format("%s#match", fullname),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = std.fn.falsy,
    value = std.Observable.from_value(true),
    task = function()
      local input = finder_input:snapshot() ---@type string
      self:__match__(input)
      self:mark_result_dirty()
    end,
  })

  local actions = {
    on_confirm = function()
      if on_confirm ~= nil then
        local uuid = retrieve() ---@type string|nil
        local item = uuid and self._itemmap[uuid] or nil ---@type eve.ux.picker.composer.list.IItem|nil
        on_confirm(self, item)
      end
    end,
  }

  local flags = {} ---@type eve.ux.picker.result.IFlagItemRaw[]
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
        return eve.icon.symbols.flag_fuzzy, flag_fuzzy:snapshot() and "picker_flag_blue" or "picker_flag_grey"
      end,
    }
    flags[#flags + 1] = {
      desc = string.format("%s: sensitive", name),
      callback = function()
        flag_sensitive:next(not flag_sensitive:snapshot())
      end,
      snapshot = function()
        return eve.icon.symbols.flag_case_sensitive,
          flag_sensitive:snapshot() and "picker_flag_blue" or "picker_flag_grey"
      end,
    }
    flags[#flags + 1] = {
      desc = string.format("%s: regex", name),
      callback = function()
        flag_regex:next(not flag_regex:snapshot())
      end,
      snapshot = function()
        return eve.icon.symbols.flag_regex, flag_regex:snapshot() and "picker_flag_blue" or "picker_flag_grey"
      end,
    }
    add_flags(flags, flags_append, name)
  end

  ---@type std.t.IKeymap[]
  local preset_ks_common = {
    {
      modes = { "i", "n", "v" },
      key = "<enter>",
      desc = "list: confirm",
      callback = actions.on_confirm,
    },
    {
      modes = { "i", "n", "v" },
      key = "<Tab>",
      desc = "list: noop",
      callback = std.fn.noop,
    },
  }

  ---@type std.t.IKeymap[]
  local preset_ks_finder = {}

  ---@type std.t.IKeymap[]
  local preset_ks_result = {}

  ---@type std.t.IKeymap[]
  local preset_ks_preview = {}

  local composer = eve.ux.picker.BasicComposer.new({
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

    finder_input = finder_input,
    finder_input_history = finder_input_history,
    finder_multiline = false,
    finder_title = title,

    result_number = false,

    result_render = function(bufnr)
      local data = result_render(self, bufnr, self._itemmap, self._matches)
      local uuids = data.uuids ---@type string[]
      retriever:attach(bufnr, uuids)

      local uuid_current = self._uuid_current ---@type string|nil
      local uuid_present = self._uuid_present ---@type string|nil
      local lnum_current = uuid_current and retriever:retrieve_lnum(uuid_current) or nil ---@type integer|nil
      local lnum_present = uuid_present and retriever:retrieve_lnum(uuid_present) or nil ---@type integer|nil
      return { lnum_current = lnum_current, lnum_present = lnum_present }
    end,
    preview_render = preview_render and function(bufnr)
      return preview_render(self, bufnr)
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
  self.flag_sensitive = flag_sensitive

  self._disposed = false
  self._composer = composer
  self._retriever = retriever
  self._scheduler_match = scheduler_match

  self._items = {}
  self._itemmap = {}
  self._matches = {}
  self._uuid_current = nil
  self._uuid_present = nil

  self._on_confirm = on_confirm
  self._on_disposed = on_disposed

  std.fn.observe({ finder_input, flag_fuzzy, flag_regex, flag_sensitive }, function()
    composer:mark_result_flags_dirty()
  end, true)
  std.fn.observe({ finder_input, flag_fuzzy, flag_regex, flag_sensitive }, function()
    scheduler_match:schedule()
  end)
  std.fn.observe({ composer.result.lnum_current }, function()
    local lnum = composer.result.lnum_current:snapshot() ---@type integer
    local uuid = retriever:retrieve_uuid(lnum) ---@type string|nil
    if uuid ~= nil then
      self._uuid_current = uuid
    end
  end)

  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  local fullname = self.fullname ---@type string
  local on_disposed = self._on_disposed ---@type eve.ux.picker.composer.list.IOnDisposed
  local composer = self._composer
  local retriever = self._retriever ---@type eve.ux.picker.ListRetriever
  local scheduler_match = self._scheduler_match

  vim.schedule(function()
    local ok1, error1 = pcall(scheduler_match.dispose, scheduler_match)
    local ok2, error2 = pcall(composer.dispose, composer)
    local ok3, error3 = pcall(retriever.dispose, retriever)
    local ok4, error4 = pcall(on_disposed)

    if not (ok1 and ok2 and ok3 and ok4) then
      std.reporter.error({
        from = fullname,
        subject = "dispose",
        message = "Failed to dispose",
        details = {
          error1 = not ok1 and error1 or nil,
          error2 = not ok2 and error2 or nil,
          error3 = not ok3 and error3 or nil,
          error4 = not ok4 and error4 or nil,
        },
      })
    end
  end)

  self._retriever:dispose()

  self.finder = nil
  self.result = nil
  self.preview = nil

  self.flag_fuzzy = nil
  self.flag_regex = nil
  self.flag_sensitive = nil

  self._composer = nil
  self._retriever = nil
  self._scheduler_match = nil
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

---@return eve.ux.picker.ListComposer
function M:mark_result_dirty()
  self:__health__()
  self._composer:mark_result_dirty()
  return self
end

---@return eve.ux.picker.ListComposer
function M:mark_result_flags_dirty()
  self:__health__()
  self._composer:mark_result_flags_dirty()
  return self
end

---@param uuid                          string|nil
---@return eve.ux.picker.ListComposer
function M:reset_uuid_current(uuid)
  self:__health__()
  self._uuid_current = uuid ---@type string|nil
  self:__refresh_uuid_current__()
  return self
end

---@param uuid                          string|nil
---@return eve.ux.picker.ListComposer
function M:reset_uuid_present(uuid)
  self:__health__()
  self._uuid_present = uuid ---@type string|nil
  self:__refresh_uuid_present__()
  return self
end

---@param data                          eve.ux.picker.composer.list.IResetData
---@return eve.ux.picker.ListComposer
function M:reset_data(data)
  self:__health__()

  local items = data.items ---@type eve.ux.picker.composer.list.IItem[]
  local lnum_total = #items ---@type integer
  local itemmap = {} ---@type table<string, eve.ux.picker.composer.list.IItem>
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
    local case_sensitive = self.flag_sensitive:snapshot()
    local use_fuzzy = self.flag_fuzzy:snapshot()
    local use_regex = self.flag_regex:snapshot()

    local lines = {}
    local search_input = case_sensitive and input or input:lower()

    for _, item in ipairs(items) do
      lines[#lines + 1] = case_sensitive and item.text or item.text_lower
    end

    local oxi_matches = eve.oxi.find_match_points_line_by_line(search_input, lines, use_fuzzy, use_regex)
    if oxi_matches then
      for _, oxi_match in ipairs(oxi_matches) do
        matches[#matches + 1] = {
          order = oxi_match.lnum,
          uuid = items[oxi_match.lnum].uuid,
          score = oxi_match.score,
          matches = oxi_match.matches,
        }
      end
    end
  end

  table.sort(matches, function(a, b)
    return a.score == b.score and a.order < b.order or a.score > b.score
  end)

  self._matches = matches
end

---@protected
---@return nil
function M:__refresh_uuid_current__()
  local uuid = self._uuid_current ---@type string|nil
  if uuid == nil then
    return
  end

  local lnum = self._retriever:retrieve_lnum(uuid) ---@type integer|nil
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

  local lnum = self._retriever:retrieve_lnum(uuid) ---@type integer|nil
  if lnum then
    self._composer.result:set_lnum_present(lnum)
  end
end

return M
