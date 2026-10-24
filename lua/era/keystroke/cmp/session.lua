---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.session" ---@type string

local Context = require("era.keystroke.cmp.context")
local Policy = require("era.keystroke.cmp.policy")
local Edit = require("era.keystroke.cmp.edit")
local Item = require("era.keystroke.cmp.item")
local Rank = require("era.keystroke.cmp.rank")
local Brackets = require("era.keystroke.cmp.brackets")
local Repeat = require("era.keystroke.cmp.repeat")
local Menu = require("era.keystroke.cmp.menu")
local Documentation = require("era.keystroke.cmp.documentation")
local Signature = require("era.keystroke.cmp.signature")
local Snippet = require("era.keystroke.cmp.snippet")

---@class era.keystroke.cmp.ISessionProps
---@field public sources                table<string, era.keystroke.cmp.ISource>
---@field public sources_for            fun(context: era.keystroke.cmp.IContext, manual: boolean, previous?: era.keystroke.cmp.IContext): string[] Names belong to sources; each item retains its source name.
---@field public frecency               ?yoz.completion.History

---@class era.keystroke.cmp.IPreparedItems
---@field public items                  era.keystroke.cmp.IItem[]
---@field public groups                 era.keystroke.cmp.IRankGroup[]

---@class era.keystroke.cmp.ISourceSlot
---@field public context                era.keystroke.cmp.IContext
---@field public response               ?era.keystroke.cmp.IResponse
---@field public prepared               ?era.keystroke.cmp.IPreparedItems
---@field public groups                 ?era.keystroke.cmp.IRankGroup[]
---@field public cancel                 ?fun(keep_transport?: boolean): nil

---@class era.keystroke.cmp.Session
---@field public context                ?era.keystroke.cmp.IContext
---@field public items                  era.keystroke.cmp.IItem[]
---@field public selected               ?integer
---@field public menu                   era.keystroke.cmp.Menu
---@field public documentation          era.keystroke.cmp.Documentation
---@field public signature              era.keystroke.cmp.Signature
---@field public internal               boolean
---@field private _props                era.keystroke.cmp.ISessionProps
---@field private _slots                table<string, era.keystroke.cmp.ISourceSlot>
---@field private _source_order         string[]
---@field private _epoch                integer
---@field private _doc_epoch            integer
---@field private _doc_cancel           ?fun(): nil
---@field private _doc_timer            ?uv.uv_timer_t
---@field private _observed             ?era.keystroke.cmp.IContext
---@field private _preview              ?era.keystroke.cmp.IContext
---@field private _explicit             boolean
---@field private _accept_cancel        ?fun(): nil
---@field private _semantic_cancel      ?fun(): nil
---@field private _render_epoch         ?integer
---@field private _menu_epoch           ?integer
---@field private _restore_render       boolean
local M = {}
M.__index = M

---@param props                         era.keystroke.cmp.ISessionProps
---@return era.keystroke.cmp.Session
function M.new(props)
  return setmetatable({
    _props = props,
    _slots = {},
    _source_order = {},
    _epoch = 0,
    _doc_epoch = 0,
    _explicit = false,
    _restore_render = false,
    items = {},
    internal = false,
    menu = Menu.new(),
    documentation = Documentation.new(),
    signature = Signature.new(),
  }, M)
end

---@return era.keystroke.cmp.IItem|nil
function M:current_item()
  return self.selected and self.items[self.selected] or nil
end

---@param item                          era.keystroke.cmp.IItem
---@param context                       era.keystroke.cmp.IContext
---@param raw                           ?lsp.CompletionItem
---@return nil
function M:prepare_snippet(item, context, raw)
  raw = raw or item.resolved or item.raw
  if raw.insertTextFormat ~= vim.lsp.protocol.InsertTextFormat.Snippet then
    return
  end
  local body = Item.insert_text(raw)
  local expansion = item.expansion
  if
    body ~= nil
    and (expansion == nil or expansion.body ~= body or not Context.same_input(expansion.context, context))
  then
    -- Variables are evaluated on selection/acceptance, never while gathering snippet candidates.
    item.expansion = { body = body, text = Snippet.expand_variables(body, context), context = context }
  end
end

---@return boolean
function M:is_visible()
  return self.menu:is_visible()
end

---@return nil
function M:reposition()
  local current = Context.capture()
  if current == nil or self.internal then
    return
  end
  local context = self.context
  if context ~= nil and context.winnr == current.winnr and self:is_visible() and not self._restore_render then
    -- Reselecting without insertion asks native completion to update its position.
    self.menu:select(self.selected, false)
  end
  self.signature:reposition(current)
end

---@return nil
function M:on_complete_changed()
  if self.internal or not self.menu.active or self._menu_epoch ~= self._epoch then
    return
  end
  local info = vim.fn.complete_info({ "selected", "completed" })
  local current = assert(Context.capture())
  local previous = self.selected
  if self._restore_render and info.selected == -1 then
    self._restore_render = false
    self._preview = nil
    self._observed = current
    local epoch = self._epoch
    vim.schedule(function()
      if self._epoch == epoch then
        self:render(true)
      end
    end)
    return
  end
  if
    info.selected == (self.selected and self.selected - 1 or -1)
    and self._observed ~= nil
    and Context.same_input(self._observed, current)
    and self._observed.changedtick == current.changedtick
  then
    vim.schedule(function()
      if self.context ~= nil and self:is_visible() and self.selected ~= nil then
        self.documentation:reposition(self.selected - 1)
      end
    end)
    return
  end
  if info.selected == -1 then
    self.selected = nil
    self._preview = nil
    if self.context ~= nil and Context.same_input(self.context, current) then
      self._observed = current
    end
  elseif self.menu:owns(info.completed.user_data) then
    self.selected = info.completed.user_data.index
    self._preview = self.context ~= nil and not Context.same_input(self.context, current) and current or nil
    self._observed = current
  else
    return
  end
  if self.selected ~= previous or self._preview ~= nil then
    self._explicit = true
  end
  -- CompleteChanged holds textlock; documentation can open or update buffers after it is released.
  vim.schedule(function()
    if self:is_visible() then
      self:show_documentation()
    end
  end)
end

---@param reason                        string
---@param completed                     table
---@param backspace                     ?boolean
---@return nil
function M:on_complete_done(reason, completed, backspace)
  if self.internal or not self.menu.active then
    return
  end
  local accepted = reason == "accept" and self.menu:owns(completed.user_data) and self._menu_epoch == self._epoch
  local continuing = reason == "discard" and (backspace == true or self._menu_epoch ~= self._epoch)
  self.menu:hide()
  self._preview = nil
  if not accepted then
    -- Native completion ends before Backspace edits the prefix; let the next text event take over its requests.
    self:hide(false, continuing)
    return
  end
  local item = self.items[completed.user_data.index]
  local context = assert(self.context)
  local current = Context.capture()
  local start_col = self.menu.start_col
  if
    current == nil
    or current.bufnr ~= context.bufnr
    or current.winnr ~= context.winnr
    or current.row ~= context.row
    or current.filetype ~= context.filetype
    or current.buffer_version ~= context.buffer_version
    or current.col ~= start_col + #completed.word
    or current.line ~= context.line:sub(1, start_col) .. completed.word .. context.line:sub(context.col + 1)
  then
    self:hide()
    return
  end
  local native_line, native_col = current.line, current.col
  local epoch = self._epoch
  local restored = self:_restore_input(context, current)
  if self._epoch ~= epoch then
    return
  end
  if restored == nil then
    self:hide()
    return
  end
  -- Finish native completion bookkeeping before starting another completion or recording dot repeat.
  vim.schedule(function()
    if self._epoch == epoch and Edit.is_current(restored) then
      self:_accept(item, restored, native_line, native_col)
    end
  end)
end

---@private
---@param context                       era.keystroke.cmp.IContext
---@param current                       era.keystroke.cmp.IContext
---@return era.keystroke.cmp.IContext|nil
function M:_restore_input(context, current)
  local epoch = self._epoch
  self.menu:hide()
  -- CompleteDone callbacks may replace the owner without changing the buffer.
  if self._epoch ~= epoch or not Edit.is_current(current) then
    return nil
  end
  self:write(function()
    if not Context.same_input(context, current) then
      vim.api.nvim_buf_set_text(context.bufnr, context.row, self.menu.start_col, context.row, current.col, {
        context.line:sub(self.menu.start_col + 1, context.col),
      })
      vim.api.nvim_win_set_cursor(context.winnr, { context.row + 1, context.col })
    end
    vim.api.nvim_set_option_value("modified", context.modified, { buf = context.bufnr })
  end)
  return Context.capture()
end

---@param bufnr                         integer
---@return boolean
function M:owns_buffer(bufnr)
  local context = self.context or self._observed
  return (context and context.bufnr or vim.api.nvim_get_current_buf()) == bufnr
end

---@param bufnr                         integer
---@param row                           integer
---@param col                           integer
---@param old_rows                      integer
---@param old_cols                      integer
---@param new_rows                      integer
---@param new_cols                      integer
---@return nil
function M:on_bytes(bufnr, row, col, old_rows, old_cols, new_rows, new_cols)
  if self.internal then
    return
  end
  -- CompleteDone may clear the logical context before the edit that dismissed native completion.
  local context = self.context or self._observed
  local within_input = context ~= nil
    and context.bufnr == bufnr
    and row == context.row
    and old_rows == 0
    and new_rows == 0
  local menu = self.menu
  if within_input and menu.active then
    within_input = col >= menu.start_col and col + old_cols <= menu.end_col
    if within_input then
      menu.end_col = menu.end_col + new_cols - old_cols
    end
  end
  if not within_input then
    Context.invalidate(bufnr)
    if self:owns_buffer(bufnr) then
      self:cancel_requests()
    end
  end
  if not within_input and menu.active then
    self:on_buffer_invalidated(bufnr)
  elseif self:owns_buffer(bufnr) and not menu.active then
    -- Native preview edits stay inside its prefix; typing also has input/text events.
    self:before_input()
  end
end

---@param bufnr                         integer
---@return nil
function M:on_buffer_invalidated(bufnr)
  if not self:owns_buffer(bufnr) then
    return
  end
  if self.menu.active then
    -- Override any queued insertion without replacing externally edited text.
    self.menu:select(self.selected, false)
  end
  self:before_input()
  self:cancel_requests()
  self.signature:cancel()
  local epoch = self._epoch
  -- Buffer callbacks may run under textlock; newer input owns any later presentation.
  vim.schedule(function()
    if self._epoch == epoch then
      self:hide()
      self.signature:hide()
    end
  end)
end

---@param callback                      fun(): nil
---@return nil
function M:write(callback)
  local was_internal = self.internal
  self.internal = true
  local ok, err = xpcall(callback, debug.traceback)
  self.internal = was_internal
  self._observed = Context.capture()
  if not ok then
    error(err, 0)
  end
end

---@param keep_transport                ?boolean Cancel publication while retaining transports for the next input.
---@param slots                         ?table<string, era.keystroke.cmp.ISourceSlot>
---@return nil
function M:cancel_requests(keep_transport, slots)
  for _, slot in pairs(slots or self._slots) do
    local cancel = slot.cancel
    if not keep_transport then
      slot.cancel = nil
    end
    if cancel ~= nil then
      cancel(keep_transport)
    end
  end
end

---@return nil
function M:cancel_documentation()
  self._doc_epoch = self._doc_epoch + 1
  if self._doc_timer ~= nil then
    self._doc_timer:stop()
    self._doc_timer:close()
    self._doc_timer = nil
  end
  local cancel = self._doc_cancel
  self._doc_cancel = nil
  if cancel ~= nil then
    cancel()
  end
end

---@return nil
function M:before_input()
  if self.internal then
    return
  end
  self:_invalidate()
end

---@private
---@return nil
function M:_invalidate()
  self._epoch = self._epoch + 1
  -- After native dismissal, retain the input scope until the coalesced text event observes all queued edits.
  if self.context ~= nil then
    self._observed = nil
  end
  -- Continuing to type commits an explicitly inserted preview as normal input.
  self._preview = nil
  self._restore_render = false
  -- Invalidate publication now; the next update or hide takes ownership of completion transports.
  self:cancel_requests(true)
  self:cancel_documentation()
  if self._accept_cancel ~= nil then
    self._accept_cancel()
    self._accept_cancel = nil
  end
  if self._semantic_cancel ~= nil then
    self._semantic_cancel()
    self._semantic_cancel = nil
  end
end

---@param cancel_preview                ?boolean
---@param keep_sources                  ?boolean Native discard precedes the next input event.
---@return boolean
function M:hide(cancel_preview, keep_sources)
  local active = self:is_visible() or self._preview ~= nil
  if cancel_preview and self._preview ~= nil and Edit.is_current(self._preview) then
    local epoch = self._epoch
    self:_restore_input(assert(self.context), self._preview)
    if self._epoch ~= epoch then
      return active
    end
  end
  self._preview = nil
  -- Explicit cancellation also owns the synchronous callbacks of an internal redraw.
  self:_invalidate()
  if not keep_sources then
    self:cancel_requests()
    self._slots = {}
  end
  self.context = nil
  self._source_order = {}
  self.items = {}
  self.selected = nil
  self._explicit = false
  self.menu:hide()
  self.documentation:hide()
  self._observed = Context.capture()
  return active
end

---@param immediate                     ?boolean
---@return nil
function M:show_documentation(immediate)
  self:cancel_documentation()
  local delay = self.documentation.winnr ~= nil and 50 or 200
  self.documentation:hide()
  local item = self:current_item()
  local context = self.context
  if item == nil or context == nil or not self:is_visible() then
    return
  end
  local epoch = self._doc_epoch

  ---@param raw                         lsp.CompletionItem
  ---@return nil
  local function publish(raw)
    if self._doc_epoch ~= epoch or self.context == nil or self:current_item() ~= item then
      return
    end
    item.resolved = raw
    self:prepare_snippet(item, self.context, raw)
    self.documentation:show(self.context, raw, assert(self.selected) - 1, item.expansion and item.expansion.text)
  end

  ---@return nil
  local function resolve()
    if self._doc_epoch ~= epoch then
      return
    end
    if self._doc_timer ~= nil then
      self._doc_timer:stop()
      self._doc_timer:close()
      self._doc_timer = nil
    end
    local source = self._props.sources[item.source]
    if item.resolved ~= nil then
      publish(item.resolved)
    elseif source.resolve ~= nil then
      self._doc_cancel = source.resolve(item, publish)
    else
      publish(item.raw)
    end
  end

  if immediate then
    resolve()
  else
    self._doc_timer = assert(vim.uv.new_timer())
    self._doc_timer:start(delay, 0, vim.schedule_wrap(resolve))
  end
end

---@param preview                       ?boolean
---@return nil
function M:render(preview)
  if self._preview ~= nil then
    self._restore_render = true
    self.menu:select(nil, true)
    return
  end
  local previous = self:current_item()
  local context = self.context
  if context == nil then
    return
  end
  local epoch = self._epoch
  local groups = {}
  for _, name in ipairs(self._source_order) do
    local slot = self._slots[name]
    if slot ~= nil and slot.groups ~= nil then
      vim.list_extend(groups, slot.groups)
    end
  end
  self.items = Rank.filter(context, groups, self._props.frecency)
  self.selected = nil
  if self._explicit and previous ~= nil then
    for index, item in ipairs(self.items) do
      -- Only the original LSP Item identifies the selection across partial client responses.
      if item == previous or (previous.source ~= "lsp" and item.id == previous.id) then
        self.selected = index
        break
      end
    end
  elseif #self.items > 0 then
    self.selected = 1
  end
  self:write(function()
    self.menu:show(context, self.items, self.selected)
  end)
  if self._epoch ~= epoch then
    return
  end
  self._menu_epoch = epoch
  local selected = self:current_item()
  if preview and selected ~= nil then
    self:prepare_snippet(selected, context)
    self:write(function()
      self.menu:select(self.selected, true)
    end)
  end
  if selected ~= previous then
    self:show_documentation()
  end
end

---@return nil
function M:schedule_render()
  local epoch = self._epoch
  if self._render_epoch == epoch then
    return
  end
  self._render_epoch = epoch
  vim.schedule(function()
    if self._render_epoch ~= epoch then
      return
    end
    self._render_epoch = nil
    if self._epoch == epoch then
      self:render()
    end
  end)
end

---@param context                       era.keystroke.cmp.IContext
---@param manual                        ?boolean
---@return nil
function M:update(context, manual)
  if self.internal then
    return
  end
  if
    not manual
    and context.trigger ~= "accept"
    and self._observed ~= nil
    and Context.same_input(self._observed, context)
    and self._observed.changedtick == context.changedtick
  then
    return
  end
  self._preview = nil
  if manual and context.trigger ~= "manual" then
    context = vim.tbl_extend("force", {}, context, { trigger = "manual" })
  end
  if not Context.enabled(context) then
    self:hide()
    self.signature:hide()
    return
  end
  self.signature:update(context)
  local names = self._props.sources_for(context, manual == true, self.context)
  if #names == 0 then
    self:hide()
    return
  end
  local old_context = self.context
  local old_slots = self._slots
  self._epoch = self._epoch + 1
  self._restore_render = false
  self:cancel_documentation()
  self._slots = {}
  self._source_order = names
  self.context = context
  self._observed = context
  if old_context == nil or not Context.same_input(old_context, context) then
    self._explicit = false
    self.selected = nil
  end
  local epoch = self._epoch
  local requested = {} ---@type table<string, boolean>
  for _, name in ipairs(names) do
    requested[name] = true
  end
  local request_source ---@type fun(name: string): nil
  -- Responses that arrive before this update renders are shown by that render.
  local updating = true ---@type boolean

  ---@return nil
  local function render_later()
    if not updating then
      self:schedule_render()
    end
  end

  ---@return nil
  local function update_buffer()
    if not requested.buffer then
      return
    end
    local eligible = true
    for _, parent in ipairs(Policy.buffer_parents) do
      if requested[parent] then
        local slot = self._slots[parent]
        local response = slot and slot.response
        if response == nil or response.pending or response.items[1] ~= nil then
          eligible = false
          break
        end
      end
    end
    local slot = self._slots.buffer
    if eligible and slot == nil then
      request_source("buffer")
      render_later()
    elseif not eligible and slot ~= nil then
      self._slots.buffer = nil
      if slot.cancel ~= nil then
        slot.cancel()
        slot.cancel = nil
      end
      render_later()
    end
  end

  ---@param name                        string
  ---@return nil
  request_source = function(name)
    local source = self._props.sources[name]
    local old = old_slots[name]
    if
      not manual
      and name ~= "lsp"
      and old ~= nil
      and old.response ~= nil
      and not old.response.incomplete
      and Context.extends(old.context, context)
    then
      self._slots[name] = old
    else
      ---@type era.keystroke.cmp.ISourceSlot
      local slot = {
        context = context,
        -- A superseded response callback must not discard the last prepared candidate set.
        -- This cache alone does not authorize displaying or accepting its items.
        prepared = old ~= nil and Context.compatible(old.context, context) and old.prepared or nil,
        -- Filter the previous compatible snapshot while incomplete/async providers refresh it.
        groups = old ~= nil and Context.compatible(old.context, context) and old.groups or nil,
      }
      self._slots[name] = slot
      ---@param submit                  fun(): nil
      ---@return nil
      local function dispatch(submit)
        if self._epoch ~= epoch or self._slots[name] ~= slot then
          return
        end
        local current = Context.capture()
        local preview = not Context.same_input(context, current)
        if preview then
          if self._preview == nil or not Edit.is_current(self._preview) then
            return
          end
          current = self:_restore_input(context, assert(current))
          if self._epoch ~= epoch or self._slots[name] ~= slot then
            return
          end
          self._preview = nil
          self._restore_render = false
        end
        if self._epoch ~= epoch or self._slots[name] ~= slot or not Context.same_input(context, current) then
          return
        end
        -- Client:request flushes didChange. Its document must match the snapshot used to interpret response ranges.
        submit()
        if preview and self._epoch == epoch and self._slots[name] == slot then
          self:render(true)
        end
      end
      ---@param response                era.keystroke.cmp.IResponse
      ---@return nil
      local function receive(response)
        if self._epoch ~= epoch or self._slots[name] ~= slot or self.context == nil then
          return
        end
        if not Context.same_input(self._observed or context, Context.capture()) then
          return
        end
        local previous = slot.prepared
        local groups ---@type era.keystroke.cmp.IRankGroup[]|nil
        if previous ~= nil and #previous.items == #response.items then
          local reusable = true
          if previous.items ~= response.items then
            for index, item in ipairs(response.items) do
              if item ~= previous.items[index] then
                reusable = false
                break
              end
            end
          end
          if reusable then
            groups = previous.groups
          end
        end
        groups = groups or Rank.prepare(response.items)
        local changed = slot.groups ~= groups
        slot.response = response
        slot.prepared = { items = response.items, groups = groups }
        slot.groups = groups
        if vim.list_contains(Policy.buffer_parents, name) then
          update_buffer()
        end
        if changed then
          render_later()
        end
      end
      -- Buffer, path and dictionary sources answer within complete(); only later answers wait a tick.
      local synchronous = true ---@type boolean
      slot.cancel = source.complete(context, function(response)
        if synchronous then
          receive(response)
        else
          vim.schedule(function()
            receive(response)
          end)
        end
      end, dispatch)
      synchronous = false
    end
  end
  for _, name in ipairs(names) do
    if name ~= "buffer" then
      request_source(name)
    end
  end
  update_buffer()
  -- LSP subscribers transfer compatible transports before the superseded handles are cancelled.
  self:cancel_requests(false, old_slots)
  updating = false
  self:render()
end

---@param direction                     integer
---@return boolean
function M:select(direction)
  if not self:is_visible() or #self.items == 0 then
    return false
  end
  if self._menu_epoch ~= self._epoch then
    self.context = Context.capture()
    self._menu_epoch = self._epoch
  end
  local context = self.context
  if context == nil then
    return false
  end
  local index = self.selected and self.selected + direction or (direction > 0 and 1 or #self.items)
  self.selected = index >= 1 and index <= #self.items and index or nil
  self._explicit = true
  local item = self:current_item()
  if item ~= nil then
    self:prepare_snippet(item, context)
  end
  self.menu:select(self.selected, true)
  return true
end

---@return boolean
function M:show()
  local context = Context.capture("manual")
  if context == nil or not Context.enabled(context) then
    return false
  end
  self:update(context, true)
  return true
end

---@param index                         ?integer
---@return boolean
function M:accept(index)
  index = index or self.selected or 1
  local item = self.items[index]
  if item == nil or not self:is_visible() then
    return false
  end
  local current = Context.capture()
  local context = self._preview ~= nil and Edit.is_current(self._preview) and self.context or current
  if context == nil or not Context.compatible(item.context, context, item.start_col) then
    self:hide()
    return false
  end
  assert(current)
  local epoch = self._epoch
  local restored = self:_restore_input(context, current)
  if self._epoch ~= epoch then
    return false
  end
  if restored == nil then
    self:hide()
    return false
  end
  return self:_accept(item, restored, current.line, current.col)
end

---@private
---@param item                          era.keystroke.cmp.IItem
---@param context                       era.keystroke.cmp.IContext
---@param native_line                   string
---@param native_col                    integer
---@return boolean
function M:_accept(item, context, native_line, native_col)
  self:hide()
  local epoch = self._epoch
  local done = false
  local cancel_resolve
  local timer = assert(vim.uv.new_timer())

  ---@return nil
  local function cancel()
    if done then
      return
    end
    done = true
    timer:stop()
    timer:close()
    if cancel_resolve ~= nil then
      cancel_resolve()
    end
  end
  self._accept_cancel = cancel

  ---@param raw                         lsp.CompletionItem
  ---@return nil
  local function apply(raw)
    if done then
      return
    end
    cancel()
    self._accept_cancel = nil
    if epoch ~= self._epoch or not Edit.is_current(context) then
      return
    end
    self:prepare_snippet(item, context, raw)
    local plan = Edit.plan(item, context, raw)
    if plan == nil then
      stl.reporter.warn({
        from = __module_name__,
        subject = "accept",
        message = "Completion edit is no longer applicable",
      })
      return
    end
    Brackets.prepare(context, raw, plan)
    local applied = false
    self:write(function()
      Repeat.record(context, plan, native_line, native_col)
      applied = Edit.apply(context, plan)
      if applied and not plan.snippet then
        Repeat.move(plan.cursor_offset)
      end
    end)
    if not applied then
      return
    end
    if self._props.frecency ~= nil then
      self._props.frecency:access(context.filetype .. "\0" .. item.frecency_key)
    end
    local client = item.client_id and vim.lsp.get_client_by_id(item.client_id) or nil
    local command = Item.optional(raw.command)
    if client ~= nil and command ~= nil then
      client:exec_cmd(command, { bufnr = context.bufnr })
    end
    vim.schedule(function()
      local current = Context.capture("accept")
      if epoch ~= self._epoch or current == nil or current.bufnr ~= context.bufnr then
        return
      end
      if plan.semantic_brackets and item.client_id ~= nil then
        self._semantic_cancel = Brackets.watch(current, item.client_id, function(opening, closing)
          self:write(function()
            Edit.insert_brackets(current, opening, closing)
          end)
          local updated = Context.capture()
          self._observed = updated
          if updated ~= nil then
            self.signature:update(updated)
          end
        end)
      end
      self.signature:update(current)
      if #self._props.sources_for(current, false) > 0 then
        self:update(current)
      end
    end)
  end

  timer:start(
    100,
    0,
    vim.schedule_wrap(function()
      apply(item.resolved or item.raw)
    end)
  )
  local source = self._props.sources[item.source]
  if item.resolved ~= nil or source.resolve == nil then
    apply(item.resolved or item.raw)
  else
    cancel_resolve = source.resolve(item, apply)
    if done and cancel_resolve ~= nil then
      cancel_resolve()
    end
  end
  return true
end

---@return nil
function M:destroy()
  self:hide()
  self.signature:destroy()
end

return M
