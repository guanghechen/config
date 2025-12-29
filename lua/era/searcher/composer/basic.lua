---@diagnostic disable: invisible
local __module_name__ = "era.searcher.composer.basic" ---@type string

---@alias era.searcher.composer.basic.PaneEnum
---| "finder"
---| "replacer"
---| "preview"
---| "result"

---@alias era.searcher.composer.basic.IOnCancel
---| fun(): nil

---@alias era.searcher.composer.basic.IOnClosed
---| fun(self: era.searcher.BasicComposer): nil

---@alias era.searcher.composer.basic.IOnDisposed
---| fun(): nil

---@alias era.searcher.composer.basic.IOnFocused
---| fun(self: era.searcher.BasicComposer): nil

---@alias era.searcher.composer.basic.IOnHidden
---| fun(self: era.searcher.BasicComposer): nil

---@alias era.searcher.composer.basic.IOnRefresh
---| fun(self: era.searcher.BasicComposer, force: boolean): nil

---@alias era.searcher.composer.basic.IOnResultRendered
---| fun(self: era.searcher.BasicComposer, bufnr: integer): nil

---@alias era.searcher.composer.basic.IOnPreviewRendered
---| fun(self: era.searcher.BasicComposer, bufnr: integer): nil

----------------------------------------------------------------------------------------------------

---@class era.searcher.composer.basic.borders
---@field public finder                 string[]
---@field public finder_with_preview    string[]
---@field public finder_without_result  string[]
---@field public finder_with_replacer   string[]
---@field public finder_with_replacer_and_preview string[]
---@field public replacer               string[]
---@field public replacer_with_preview  string[]
---@field public replacer_stacked       string[]
---@field public result                 string[]
---@field public result_with_preview    string[]
---@field public result_stacked         string[]
---@field public preview                string[]
---@field public preview_stacked        string[]
local __borders__ = {
  -- stylua: ignore start
  finder                = { "╭", "─", "╮", "│", "┤", "─", "├", "│" },
  finder_with_preview   = { "╭", "─", "┬", "│", "┤", "─", "├", "│" },
  finder_without_result = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
  finder_with_replacer  = { "╭", "─", "╮", "│", "┤", "─", "├", "│" },
  finder_with_replacer_and_preview = { "╭", "─", "┬", "│", "┤", "─", "├", "│" },
  replacer              = { "├", "─", "┤", "│", "┤", "─", "├", "│" },
  replacer_with_preview = { "├", "─", "┤", "│", "┴", "─", "╰", "│" },
  replacer_stacked      = { "├", "─", "┤", "│", "┤", "─", "├", "│" },
  result                = { "├", "─", "┤", "│", "╯", "─", "╰", "│" },
  result_with_preview   = { "├", "─", "┤", "│", "┴", "─", "╰", "│" },
  result_stacked        = { "├", "─", "┤", "│", "┤", "─", "├", "│" },
  preview               = { "┬", "─", "╮", "│", "╯", "─", "┴", "│" },
  preview_stacked       = { "├", "─", "┤", "│", "╯", "─", "╰", "│" },
  -- stylua: ignore end
}

---@class era.searcher.composer.basic.highlights
---@field public finder                 string
---@field public replacer               string
---@field public result                 string
---@field public preview                string
local __highlights__ = {
  finder = table.concat({
    "FloatBorder:FloatBorder",
    "FloatTitle:f_pk_finder_title",
    "Normal:f_pk_finder_normal",
  }, ","),
  replacer = table.concat({
    "FloatBorder:FloatBorder",
    "FloatTitle:f_pk_finder_title",
    "Normal:f_pk_finder_normal",
  }, ","),
  result = table.concat({
    "Cursor:f_pk_result_current",
    "CursorColumn:f_pk_result_current",
    "CursorLine:f_pk_result_current",
    "CursorLineNr:f_pk_result_current",
    "FloatBorder:FloatBorder",
    "Normal:f_pk_result_normal",
  }, ","),
  preview = table.concat({
    "Cursor:f_pk_preview_current",
    "CursorColumn:f_pk_preview_current",
    "CursorLine:f_pk_preview_current",
    "CursorLineNr:f_pk_preview_current",
    "FloatBorder:FloatBorder",
    "FloatTitle:f_pk_preview_title",
    "Normal:f_pk_preview_normal",
  }, ","),
}

----------------------------------------------------------------------------------------------------

---@class era.searcher.composer.IBasicProps
---@field public uuid                   ?string
---@field public name                   string
---@field public permanent              boolean
---
---@field public flags                  ?era.searcher.result.IFlagItemRaw[]
---@field public flags_start_index      ?0|1
---@field public height                 ?number
---@field public width                  ?number
---
---@field public keymaps_common         ?stl.t.IKeymap[]
---@field public keymaps_finder         ?stl.t.IKeymap[]
---@field public keymaps_replacer       ?stl.t.IKeymap[]
---@field public keymaps_preview        ?stl.t.IKeymap[]
---@field public keymaps_result         ?stl.t.IKeymap[]
---
---@field public search_pattern         stl.c.Observable
---@field public search_pattern_history ?stl.c.History
---@field public finder_title           string
---
---@field public replace_pattern        ?stl.c.Observable
---@field public replace_pattern_history ?stl.c.History
---@field public replacer_title         ?string
---@field public flag_replace           ?stl.c.Observable
---
---@field public result_number          boolean
---@field public result_isselected      ?era.searcher.result.IIsSelected
---
---@field public render_preview         ?era.searcher.preview.IDraw
---@field public render_result          era.searcher.result.IDraw
---
---@field public on_cancel              ?era.searcher.composer.basic.IOnCancel
---@field public on_closed              ?era.searcher.composer.basic.IOnClosed
---@field public on_disposed            ?era.searcher.composer.basic.IOnDisposed
---@field public on_focused             ?era.searcher.composer.basic.IOnFocused
---@field public on_hidden              ?era.searcher.composer.basic.IOnHidden
---@field public on_refresh             ?era.searcher.composer.basic.IOnRefresh
---@field public on_preview_rendered    ?era.searcher.composer.basic.IOnPreviewRendered
---@field public on_result_rendered     ?era.searcher.composer.basic.IOnResultRendered

---@class era.searcher.BasicComposer : dot.t.IWidget
---@field public uuid                   string
---@field public fullname               string
---@field public permanent              boolean
---
---@field public finder                 era.searcher.Finder
---@field public replacer               era.searcher.Finder|nil
---@field public result                 era.searcher.Result
---@field public preview                era.searcher.Preview|nil
---
---@field protected _result_number      boolean
---
---@field protected _disposed           boolean
---@field protected _pane_focused       era.searcher.composer.basic.PaneEnum
---@field protected _pane_last_focused  era.searcher.composer.basic.PaneEnum
---@field protected _recommended_height number
---@field protected _recommended_width  number
---
---@field protected _flag_replace       stl.c.Observable|nil
---@field protected _flag_replace_unsub stl.c.IUnsubscribable|nil
---
---@field protected _search_pattern_history ?stl.c.History
---@field protected _replace_pattern_history ?stl.c.History
---
---@field protected _on_cancel          era.searcher.composer.basic.IOnCancel
---@field protected _on_closed          era.searcher.composer.basic.IOnClosed
---@field protected _on_disposed        era.searcher.composer.basic.IOnDisposed
---@field protected _on_focused         era.searcher.composer.basic.IOnFocused
---@field protected _on_hidden          era.searcher.composer.basic.IOnHidden
---@field protected _on_refresh         era.searcher.composer.basic.IOnRefresh
local M = {}
M.__index = M

---@param props                         era.searcher.composer.IBasicProps
---@return era.searcher.BasicComposer
function M.new(props)
  local uuid = props.uuid or yoz.fn.uuid() ---@type string
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local permanent = not not props.permanent ---@type boolean

  local flags = props.flags ---@type era.searcher.result.IFlagItemRaw[]
  local flags_start_index = props.flags_start_index == 0 and 0 or 1 ---@type 0|1
  local pane_focused = "finder" ---@type era.searcher.composer.basic.PaneEnum
  local pane_last_focused = "finder" ---@type era.searcher.composer.basic.PaneEnum
  local recommended_height = math.max(0.1, props.height or 0.8) ---@type number
  local recommended_width = math.max(0.1, props.width or 0.8) ---@type number

  local keymaps_common = props.keymaps_common or {} ---@type stl.t.IKeymap[]
  local keymaps_finder = props.keymaps_finder or {} ---@type stl.t.IKeymap[]
  local keymaps_replacer = props.keymaps_replacer or {} ---@type stl.t.IKeymap[]
  local keymaps_preview = props.keymaps_preview or {} ---@type stl.t.IKeymap[]
  local keymaps_result = props.keymaps_result or {} ---@type stl.t.IKeymap[]

  local search_pattern = props.search_pattern ---@type stl.c.Observable
  local search_pattern_history = props.search_pattern_history ---@type stl.c.History
  local finder_title = string.format(" %s ", vim.trim(props.finder_title)) ---@type string

  local replace_pattern = props.replace_pattern ---@type stl.c.Observable|nil
  local replace_pattern_history = props.replace_pattern_history ---@type stl.c.History|nil
  local replacer_title = props.replacer_title and string.format(" %s ", vim.trim(props.replacer_title)) or " Replace " ---@type string
  local flag_replace = props.flag_replace ---@type stl.c.Observable|nil

  local result_number = not not props.result_number ---@type boolean
  local result_isselected = props.result_isselected ---@type era.searcher.result.IIsSelected|nil

  local render_preview = props.render_preview ---@type era.searcher.preview.IDraw|nil
  local render_result = props.render_result ---@type era.searcher.result.IDraw

  local on_cancel = props.on_cancel or stl.fn.noop ---@type era.searcher.composer.basic.IOnCancel
  local on_closed = props.on_closed or stl.fn.noop ---@type era.searcher.composer.basic.IOnClosed
  local on_disposed = props.on_disposed or stl.fn.noop ---@type era.searcher.composer.basic.IOnDisposed
  local on_focused = props.on_focused or stl.fn.noop ---@type era.searcher.composer.basic.IOnFocused
  local on_hidden = props.on_hidden or stl.fn.noop ---@type era.searcher.composer.basic.IOnHidden
  local on_refresh = props.on_refresh or stl.fn.noop ---@type era.searcher.composer.basic.IOnRefresh
  local on_preview_rendered = props.on_preview_rendered or stl.fn.noop ---@type era.searcher.composer.basic.IOnPreviewRendered
  local on_result_rendered = props.on_result_rendered or stl.fn.noop ---@type era.searcher.composer.basic.IOnResultRendered

  local self = setmetatable({}, M)
  self.uuid = uuid
  self.fullname = fullname
  self.permanent = permanent
  self._disposed = false
  self._pane_focused = pane_focused
  self._pane_last_focused = pane_last_focused
  self._recommended_height = recommended_height
  self._recommended_width = recommended_width
  self._search_pattern_history = search_pattern_history
  self._replace_pattern_history = replace_pattern_history
  self._flag_replace = flag_replace
  self._on_cancel = on_cancel ---@type era.searcher.composer.basic.IOnCancel
  self._on_closed = on_closed ---@type era.searcher.composer.basic.IOnClosed
  self._on_disposed = on_disposed ---@type era.searcher.composer.basic.IOnDisposed
  self._on_focused = on_focused ---@type era.searcher.composer.basic.IOnFocused
  self._on_hidden = on_hidden ---@type era.searcher.composer.basic.IOnHidden
  self._on_refresh = on_refresh ---@type era.searcher.composer.basic.IOnRefresh

  ---@type era.searcher.Finder
  local finder = era.searcher.Finder.new({
    name = name,
    keymaps = self:__resolve_keymaps_finder__(
      flags,
      flags_start_index,
      vim.list_extend(vim.list_slice(keymaps_common), keymaps_finder)
    ),
    input = search_pattern,
    title = finder_title,
  })

  ---@type era.searcher.Finder|nil
  local replacer = nil
  if replace_pattern ~= nil then
    replacer = era.searcher.Finder.new({
      name = name .. " (replacer)",
      keymaps = self:__resolve_keymaps_replacer__(
        flags,
        flags_start_index,
        vim.list_extend(vim.list_slice(keymaps_common), keymaps_replacer)
      ),
      input = replace_pattern,
      title = replacer_title,
      prompt_sign = stl.icon.symbols.flag_replace,
      prompt_sign_hl = "m_pk_replacer_prompt",
    })
  end

  ---@type era.searcher.Result
  local result = era.searcher.Result.new({
    uuid = uuid,
    name = name,
    draw = function(bufnr)
      if search_pattern_history ~= nil then
        local keyword = search_pattern:snapshot() ---@type string
        if keyword ~= nil and vim.trim(keyword) ~= "" then
          search_pattern_history:push(keyword)
        end
      end
      if replace_pattern_history ~= nil and replace_pattern ~= nil then
        local replacement = replace_pattern:snapshot() ---@type string
        if replacement ~= nil and vim.trim(replacement) ~= "" then
          replace_pattern_history:push(replacement)
        end
      end
      return render_result(bufnr)
    end,
    isselected = result_isselected,
    keymaps = self:__resolve_keymaps_result__(
      flags,
      flags_start_index,
      vim.list_extend(vim.list_slice(keymaps_common), keymaps_result)
    ),
    flags = flags,
    flags_start_index = flags_start_index,
    ---@type era.searcher.result.IOnDrawed
    on_drawed = function(bufnr)
      self:mark_preview_dirty()
      on_result_rendered(self, bufnr)
    end,
  })

  ---@type era.searcher.Preview|nil
  local preview = nil
  if render_preview ~= nil then
    preview = era.searcher.Preview.new({
      uuid = uuid,
      name = name,
      draw = render_preview,
      keymaps = self:__resolve_keymaps_preview__(
        flags,
        flags_start_index,
        vim.list_extend(vim.list_slice(keymaps_common), keymaps_preview)
      ),
      ---@type era.searcher.preview.IOnDrawed
      on_drawed = function(bufnr)
        on_preview_rendered(self, bufnr)
      end,
    })
  end

  self.finder = finder
  self.replacer = replacer
  self.result = result
  self.preview = preview

  self._result_number = result_number ---@type boolean
  self._flag_replace_unsub = nil

  if preview ~= nil then
    stl.fn.observe({ result.lnum_current, result.lnum_total }, function()
      self:mark_preview_dirty()
    end, true)
  end

  -- Set up auto-resize observers for finder and replacer
  stl.fn.observe({ finder.linecount }, function()
    if self:isvisible() then
      self:resize()
    end
  end, true)

  if replacer ~= nil then
    stl.fn.observe({ replacer.linecount }, function()
      if self:isvisible() then
        self:resize()
      end
    end, true)
  end

  -- Observer for flag_replace to toggle replacer window visibility
  local flag_replace_unsub = nil ---@type stl.c.IUnsubscribable|nil
  if flag_replace ~= nil then
    flag_replace_unsub = stl.fn.observe({ flag_replace }, function()
      if self:isvisible() then
        self:__toggle_replacer_visibility__(flag_replace:snapshot())
      end
    end, true)
  end
  self._flag_replace_unsub = flag_replace_unsub

  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  local fullname = self.fullname ---@type string
  local finder = self.finder ---@type era.searcher.Finder
  local replacer = self.replacer ---@type era.searcher.Finder|nil
  local result = self.result ---@type era.searcher.Result
  local preview = self.preview ---@type era.searcher.Preview|nil
  local on_disposed = self._on_disposed ---@type era.searcher.composer.basic.IOnDisposed
  local flag_replace_unsub = self._flag_replace_unsub ---@type stl.c.IUnsubscribable|nil
  vim.schedule(function()
    local ok1, error1 = pcall(finder.dispose, finder)
    local ok2, error2 = pcall(result.dispose, result)
    local ok3, error3 = true, nil
    local ok4, error4 = true, nil
    local ok5, error5 = pcall(on_disposed)
    local ok6, error6 = true, nil

    if replacer ~= nil then
      ok3, error3 = pcall(replacer.dispose, replacer)
    end

    if preview ~= nil then
      ok4, error4 = pcall(preview.dispose, preview)
    end

    if flag_replace_unsub ~= nil then
      ok6, error6 = pcall(flag_replace_unsub.unsubscribe, flag_replace_unsub)
    end

    if not (ok1 and ok2 and ok3 and ok4 and ok5 and ok6) then
      stl.reporter.error({
        from = fullname,
        subject = "dispose",
        message = "Failed to dispose",
        details = {
          error1 = not ok1 and error1 or nil,
          error2 = not ok2 and error2 or nil,
          error3 = not ok3 and error3 or nil,
          error4 = not ok4 and error4 or nil,
          error5 = not ok5 and error5 or nil,
          error6 = not ok6 and error6 or nil,
        },
      })
    end
  end)

  self.finder = nil
  self.replacer = nil
  self.result = nil
  self.preview = nil

  self._pane_focused = nil
  self._pane_last_focused = nil
  self._recommended_height = nil
  self._recommended_width = nil

  self._flag_replace = nil
  self._flag_replace_unsub = nil
  self._search_pattern_history = nil
  self._replace_pattern_history = nil

  self._on_cancel = nil
  self._on_closed = nil
  self._on_disposed = nil
  self._on_focused = nil
  self._on_hidden = nil
  self._on_refresh = nil
end

---@return nil
function M:close()
  if self._disposed then
    return
  end

  if not self.permanent then
    self:dispose()
    return
  end

  self:__hide__()
  vim.schedule(function()
    local ok, error = pcall(self._on_closed, self)
    if not ok then
      stl.reporter.error({
        from = self.fullname,
        subject = "close",
        message = "Failed to call on_closed",
        details = { error = error },
      })
    end
  end)
end

---@param pane                          era.searcher.composer.basic.PaneEnum|nil
---@return nil
function M:focus(pane)
  self:__health__()
  dot.state.widget.push(self)

  local has_new_created = self:__create_wins__()
  local pane_focused = has_new_created and "finder" or self._pane_focused ---@type era.searcher.composer.basic.PaneEnum
  self:__focus_pane__(pane or pane_focused)

  vim.schedule(function()
    local ok, error = pcall(self._on_focused, self)
    if not ok then
      stl.reporter.error({
        from = self.fullname,
        subject = "focus",
        message = "Failed to call on_focused",
        details = { error = error },
      })
    end
  end)
end

---@return nil
function M:hide()
  if self._disposed then
    return
  end

  self:__hide__()
  vim.schedule(function()
    local ok, error = pcall(self._on_hidden, self)
    if not ok then
      stl.reporter.error({
        from = self.fullname,
        subject = "hide",
        message = "Failed to call on_hidden",
        details = { error = error },
      })
    end
  end)
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isfocused()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  return self.finder:get_winnr() == winnr
    or (self.replacer ~= nil and self.replacer:get_winnr() == winnr)
    or self.result:get_winnr() == winnr
    or (self.preview ~= nil and self.preview:get_winnr() == winnr)
end

---@return boolean
function M:isvisible()
  if self._disposed then
    return false
  end
  return self.finder:isvisible()
    or (self.replacer ~= nil and self.replacer:isvisible())
    or self.result:isvisible()
    or (self.preview ~= nil and self.preview:isvisible())
end

---@return integer
function M:get_result_lnum()
  self:__health__()
  return self.result.lnum_current:snapshot()
end

---@return dot.t.IWinDimension
---@return dot.t.IWinDimension|nil
---@return dot.t.IWinDimension
---@return dot.t.IWinDimension|nil
function M:get_layout()
  self:__health__()
  return self:__layout__()
end

---@return era.searcher.BasicComposer
function M:mark_result_dirty()
  self:__health__()
  self.result:mark_content_dirty()
  if self.preview ~= nil then
    self.preview:mark_content_dirty()
  end
  return self
end

---@return era.searcher.BasicComposer
function M:mark_result_flags_dirty()
  self:__health__()
  self.result:mark_nvimbar_dirty()
  return self
end

function M:mark_preview_dirty()
  self:__health__()
  if self.preview ~= nil then
    self.preview:mark_content_dirty()
  end
  return self
end

---@return nil
function M:resize()
  self:__health__()

  if not self:isvisible() then
    return
  end

  local has_new_created = self:__create_wins__() ---@type boolean

  local preview_layout = self:__preview_layout__() ---@type "hidden"|"right"|"bottom"
  local should_show_preview = preview_layout ~= "hidden" ---@type boolean
  local should_show_replacer = self:__should_show_replacer__() ---@type boolean
  local replacer_border, result_border, preview_border = self:__get_borders__(preview_layout, should_show_replacer) ---@type string[], string[], string[]

  local finder_dimension, replacer_dimension, result_dimension, preview_dimension = self:__layout__() ---@type dot.t.IWinDimension, dot.t.IWinDimension|nil, dot.t.IWinDimension, dot.t.IWinDimension|nil
  self.finder:resize(finder_dimension)
  if self.replacer ~= nil and replacer_dimension ~= nil then
    self.replacer:resize(replacer_dimension)
  end
  self.result:resize(result_dimension)
  if self.preview ~= nil and preview_dimension ~= nil then
    self.preview:resize(preview_dimension)
  end

  if has_new_created then
    -- Check if the currently focused window still exists, otherwise restore focus
    local current_focused_exists = self:__is_pane_valid__(self._pane_focused) ---@type boolean
    if not current_focused_exists then
      -- Try to restore the last focused pane first, fallback to finder
      local pane_to_focus = "finder" ---@type era.searcher.composer.basic.PaneEnum
      if self:__is_pane_valid__(self._pane_last_focused) then
        pane_to_focus = self._pane_last_focused
      end
      self:__focus_pane__(pane_to_focus)
    end
  end

  -- Update borders when layout changes
  local finder_winnr = self.finder:get_winnr() ---@type integer|nil
  if finder_winnr ~= nil and vim.api.nvim_win_is_valid(finder_winnr) then
    vim.api.nvim_win_set_config(finder_winnr, {
      border = self:__get_finder_border__(should_show_replacer, should_show_preview and preview_layout == "right"),
    })
  end

  if self.replacer ~= nil then
    local replacer_winnr = self.replacer:get_winnr() ---@type integer|nil
    if replacer_winnr ~= nil and vim.api.nvim_win_is_valid(replacer_winnr) then
      vim.api.nvim_win_set_config(replacer_winnr, { border = replacer_border })
    end
  end

  local result_winnr = self.result:get_winnr() ---@type integer|nil
  if result_winnr ~= nil and vim.api.nvim_win_is_valid(result_winnr) then
    vim.api.nvim_win_set_config(result_winnr, { border = result_border })
  end

  if self.preview ~= nil then
    local preview_winnr = self.preview:get_winnr() ---@type integer|nil
    if preview_winnr ~= nil and vim.api.nvim_win_is_valid(preview_winnr) then
      vim.api.nvim_win_set_config(preview_winnr, { border = preview_border })
    end
  end
end

---@param lnum                          integer
---@return era.searcher.BasicComposer
function M:set_result_lnum(lnum)
  self:__health__()
  self.result:set_lnum_current(lnum)
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@return boolean
---@return integer
---@return integer|nil
---@return integer
---@return integer|nil
function M:__create_wins__()
  local finder = self.finder ---@type era.searcher.Finder
  local replacer = self.replacer ---@type era.searcher.Finder|nil
  local result = self.result ---@type era.searcher.Result
  local preview = self.preview ---@type era.searcher.Preview|nil

  local result_number = self._result_number ---@type boolean

  local finder_winnr = finder:get_winnr() ---@type integer|nil
  local replacer_winnr = replacer and replacer:get_winnr() or nil ---@type integer|nil
  local result_winnr = result:get_winnr() ---@type integer|nil
  local preview_winnr = preview and preview:get_winnr() or nil ---@type integer|nil

  if finder_winnr ~= nil and not vim.api.nvim_win_is_valid(finder_winnr) then
    finder_winnr = nil
  end

  if replacer_winnr ~= nil and not vim.api.nvim_win_is_valid(replacer_winnr) then
    replacer_winnr = nil
  end

  if result_winnr ~= nil and not vim.api.nvim_win_is_valid(result_winnr) then
    result_winnr = nil
  end

  if preview_winnr ~= nil and not vim.api.nvim_win_is_valid(preview_winnr) then
    preview_winnr = nil
  end

  local preview_layout = self:__preview_layout__() ---@type "hidden"|"right"|"bottom"
  local should_show_preview = preview_layout ~= "hidden" ---@type boolean
  if preview_winnr ~= nil and not should_show_preview then
    stl.nvim.win.close(preview_winnr)
    preview_winnr = nil
  end

  local should_show_replacer = self:__should_show_replacer__() ---@type boolean
  if replacer_winnr ~= nil and not should_show_replacer then
    stl.nvim.win.close(replacer_winnr)
    replacer_winnr = nil
  end

  if
    finder_winnr ~= nil
    and result_winnr ~= nil
    and (replacer_winnr ~= nil or not should_show_replacer)
    and (preview_winnr ~= nil or not should_show_preview)
  then
    return false, finder_winnr, replacer_winnr, result_winnr, preview_winnr
  end

  local finder_dimension, replacer_dimension, result_dimension, preview_dimension = self:__layout__() ---@type dot.t.IWinDimension, dot.t.IWinDimension|nil, dot.t.IWinDimension, dot.t.IWinDimension|nil
  local replacer_border, result_border, preview_border = self:__get_borders__(preview_layout, should_show_replacer) ---@type string[], string[], string[]
  local zindex = dot.win.resolve_zindex() ---@type integer

  ---@type era.searcher.finder.IWinOpts
  local finder_winopts = {
    border = self:__get_finder_border__(should_show_replacer, should_show_preview and preview_layout == "right"),
    winhighlight = __highlights__.finder,
    zindex = zindex,
  }
  finder_winnr = finder:create_win(finder_winopts, finder_dimension)

  if replacer ~= nil and replacer_dimension ~= nil and should_show_replacer then
    ---@type era.searcher.finder.IWinOpts
    local replacer_winopts = {
      border = replacer_border,
      winhighlight = __highlights__.replacer,
      zindex = zindex,
    }
    replacer_winnr = replacer:create_win(replacer_winopts, replacer_dimension)
  end

  ---@type era.searcher.result.IWinOpts
  local result_winopts = {
    border = result_border,
    number = result_number,
    winhighlight = __highlights__.result,
    zindex = zindex,
  }
  result_winnr = result:create_win(result_winopts, result_dimension)

  if preview ~= nil and preview_dimension ~= nil and should_show_preview then
    ---@type era.searcher.preview.IWinOpts
    local preview_winopts = {
      border = preview_border,
      winhighlight = __highlights__.preview,
      zindex = zindex,
    }
    preview_winnr = preview:create_win(preview_winopts, preview_dimension) ---@type integer|nil
  end

  return true, finder_winnr, replacer_winnr, result_winnr, preview_winnr
end

----------------------------------------------------------------------------------------------------

---@protected
---@param pane                          era.searcher.composer.basic.PaneEnum|nil
---@return boolean
function M:__is_pane_valid__(pane)
  if pane == nil then
    return false
  end

  if pane == "finder" then
    local winnr = self.finder:get_winnr() ---@type integer|nil
    return winnr ~= nil and vim.api.nvim_win_is_valid(winnr)
  elseif pane == "replacer" then
    if self.replacer == nil then
      return false
    end
    local winnr = self.replacer:get_winnr() ---@type integer|nil
    return winnr ~= nil and vim.api.nvim_win_is_valid(winnr)
  elseif pane == "result" then
    local winnr = self.result:get_winnr() ---@type integer|nil
    return winnr ~= nil and vim.api.nvim_win_is_valid(winnr)
  elseif pane == "preview" then
    if self.preview == nil then
      return false
    end
    local winnr = self.preview:get_winnr() ---@type integer|nil
    return winnr ~= nil and vim.api.nvim_win_is_valid(winnr)
  end

  return false
end

---@protected
---@param pane_focused                  era.searcher.composer.basic.PaneEnum
---@return nil
function M:__focus_pane__(pane_focused)
  if pane_focused == "finder" then
    self.finder:focus()
  elseif pane_focused == "replacer" then
    if self.replacer ~= nil then
      self.replacer:focus()
    end
  elseif pane_focused == "result" then
    self.result:focus()
  elseif pane_focused == "preview" then
    if self.preview ~= nil then
      self.preview:focus()
    end
  else
    pane_focused = self._pane_focused
  end

  if pane_focused ~= self._pane_focused then
    self._pane_last_focused = self._pane_focused
    self._pane_focused = pane_focused
  end
end

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s] already been disposed.", self.fullname) ---@type string
    error(message)
  end
end

---@protected
---@return nil
function M:__hide__()
  local finder = self.finder ---@type era.searcher.Finder
  local replacer = self.replacer ---@type era.searcher.Finder|nil
  local result = self.result ---@type era.searcher.Result
  local preview = self.preview ---@type era.searcher.Preview|nil

  finder:hide()
  if replacer ~= nil then
    replacer:hide()
  end
  result:hide()
  if preview ~= nil then
    preview:hide()
  end
end

---@return dot.t.IWinDimension
---@return dot.t.IWinDimension|nil
---@return dot.t.IWinDimension
---@return dot.t.IWinDimension|nil
function M:__layout__()
  local preview_layout = self:__preview_layout__() ---@type "hidden"|"right"|"bottom"
  local should_show_preview = preview_layout ~= "hidden" ---@type boolean
  local preview_on_right = preview_layout == "right" ---@type boolean
  local preview_on_bottom = preview_layout == "bottom" ---@type boolean
  local should_show_replacer = self:__should_show_replacer__() ---@type boolean
  local max_height = math.max(math.floor(vim.o.lines * 0.9), vim.o.lines - 10) ---@type integer
  local max_width = math.max(math.floor(vim.o.columns * 0.9), vim.o.columns - 20) ---@type integer

  local min_height = math.min(math.floor(vim.o.lines * 0.6), 56) ---@type integer
  local min_width = preview_on_right and math.min(math.floor(vim.o.columns * 0.6), 160)
    or math.min(math.floor(vim.o.columns * 0.4), 80)

  local recommended_height = self._recommended_height <= 1 and math.floor(vim.o.lines * self._recommended_height)
    or math.floor(self._recommended_height) ---@type integer
  local recommended_width = self._recommended_width <= 1 and math.floor(vim.o.columns * self._recommended_width)
    or math.floor(self._recommended_width) ---@type integer

  local height = math.min(max_height, math.max(min_height, recommended_height)) ---@type integer
  local width = math.min(max_width, math.max(min_width, recommended_width)) ---@type integer

  local row = math.floor((vim.o.lines - height - 3) / 2) ---@type integer
  local col = math.floor((vim.o.columns - width - 2) / 2) ---@type integer

  local finder_width = preview_on_right and math.floor(width / 2) or width ---@type integer
  local preview_width = preview_on_right and (width - finder_width) or width ---@type integer
  local finder_height = 1 ---@type integer

  local min_top_height = should_show_replacer and 5 or 3 ---@type integer
  local preview_height = should_show_preview and preview_on_bottom and math.max(1, math.floor(height * 0.5)) or height ---@type integer
  if should_show_preview and preview_on_bottom then
    local max_preview_height = math.max(1, height - min_top_height) ---@type integer
    preview_height = math.max(1, math.min(preview_height, max_preview_height))
  end

  local layout_height = should_show_preview and preview_on_bottom and (height - preview_height) or height ---@type integer
  if should_show_preview and preview_on_bottom then
    if layout_height < min_top_height then
      layout_height = math.max(min_top_height, height - 1)
      preview_height = math.max(1, height - layout_height)
    end
  end

  local finder = self.finder ---@type era.searcher.Finder
  local linecount = finder.linecount:snapshot() ---@type integer
  finder_height = math.max(1, math.min(5, math.floor(layout_height * 0.3), linecount)) ---@type integer

  local replacer_height = 0 ---@type integer
  if should_show_replacer and self.replacer ~= nil then
    local replacer_linecount = self.replacer.linecount:snapshot() ---@type integer
    replacer_height = math.max(1, math.min(5, math.floor(layout_height * 0.2), replacer_linecount)) ---@type integer
  end
  local total_input_height = finder_height + replacer_height ---@type integer

  ---@type dot.t.IWinDimension
  local finder_dimension = {
    row = row,
    col = col,
    height = finder_height,
    width = finder_width,
  }

  ---@type dot.t.IWinDimension|nil
  local replacer_dimension = should_show_replacer
      and {
        row = row + finder_height + 1,
        col = col,
        height = replacer_height,
        width = finder_width,
      }
    or nil

  ---@type dot.t.IWinDimension
  local result_dimension = {
    row = row + total_input_height + (should_show_replacer and 2 or 1),
    col = col,
    height = math.max(1, layout_height - total_input_height - (should_show_replacer and 2 or 1)),
    width = finder_width,
  }

  local preview_dimension = nil ---@type dot.t.IWinDimension|nil
  if should_show_preview then
    if preview_on_bottom then
      local gap_result_preview = 1 ---@type integer
      preview_dimension = {
        row = row + layout_height + gap_result_preview,
        col = col,
        height = preview_height,
        width = preview_width,
      }
    else
      preview_dimension = {
        row = row,
        col = col + finder_width + 1,
        height = height,
        width = preview_width,
      }
    end
  end
  return finder_dimension, replacer_dimension, result_dimension, preview_dimension
end

---@param flags                         era.searcher.result.IFlagItemRaw[]
---@param flags_start_index             0|1
---@return stl.t.IKeymap[]
function M:__resolve_builtin_keymaps_common__(flags, flags_start_index)
  ---@type stl.t.IKeymap[]
  local builtin_keymaps = {
    {
      modes = { "n", "x" },
      key = "q",
      desc = "searcher: close",
      callback = function()
        self:close()

        if not self._disposed then
          local ok, error = pcall(self._on_cancel)
          if not ok then
            stl.reporter.error({
              from = self.fullname,
              subject = "close",
              message = "Failed to call on_cancel",
              details = { error = error },
            })
          end
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>r",
      aliases = { "<D-r>", "<M-r>" },
      desc = "searcher: refresh",
      callback = function()
        local refresh_ok, refresh_error = pcall(self._on_refresh, self, true)
        if not refresh_ok then
          stl.reporter.error({
            from = self.fullname,
            subject = "refresh",
            message = "Failed to run on_refresh",
            details = { error = refresh_error },
          })
        end
      end,
    },
  }

  local N = #builtin_keymaps ---@type integer

  local index = flags_start_index ---@type integer
  local index_maximum = index + #flags - 1 ---@type integer
  local index_width = #(tostring(index_maximum)) ---@type integer
  local index_format = string.format("t%%0%dd", index_width) ---@type string

  if self._flag_replace ~= nil then
    N = N + 1 ---@type integer
    builtin_keymaps[N] = {
      modes = { "n", "x" },
      key = "tr",
      desc = "searcher: toggle replace mode",
      callback = function()
        local flag = self._flag_replace ---@type stl.c.Observable|nil
        if flag ~= nil then
          flag:next(not flag:snapshot())
        end
      end,
    }
  end

  for _, item in ipairs(flags) do
    if index <= 9 then
      ---@type stl.t.IKeymap
      local keymap = {
        modes = { "i", "n", "x" },
        key = string.format("<C-%d>", index),
        desc = item.desc,
        callback = item.callback,
      }
      N = N + 1 ---@type integer
      builtin_keymaps[N] = keymap
    end

    ---@type stl.t.IKeymap
    local keymap = {
      modes = { "n", "x" },
      key = string.format(index_format, index),
      desc = item.desc,
      callback = item.callback,
    }
    index = index + 1

    N = N + 1 ---@type integer
    builtin_keymaps[N] = keymap
  end

  for _, item in ipairs(dot.state.widget.get_keymaps(self)) do
    N = N + 1 ---@type integer
    builtin_keymaps[N] = item
  end

  return builtin_keymaps
end

---@return stl.t.IKeymap[]
function M:__resolve_builtin_keymaps_finder__()
  ---@type stl.t.IKeymap[]
  local builtin_keymaps = {
    {
      modes = { "i", "n", "x" },
      key = "<Down>",
      desc = "searcher#finder: focus next item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(step)
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<Up>",
      desc = "searcher#finder: focus prev item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(-step)
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-i>",
      desc = "searcher#finder: history backward",
      callback = function()
        if self._search_pattern_history == nil then
          return
        end
        local last_input = self._search_pattern_history:backward() ---@type string|nil
        if last_input ~= nil then
          self.finder:set_content(last_input)
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-o>",
      desc = "searcher#finder: history forward",
      callback = function()
        if self._search_pattern_history == nil then
          return
        end
        local next_input = self._search_pattern_history:forward() ---@type string|nil
        if next_input ~= nil then
          self.finder:set_content(next_input)
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "searcher#finder: focus down",
      callback = function()
        if self:__should_show_replacer__() then
          self:__focus_pane__("replacer")
        else
          self:__focus_pane__("result")
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      desc = "searcher#finder: focus left",
      callback = function()
        if stl.env.IS_TMUX and not dot.state.status.tmux_zen_mode:snapshot() then
          stl.tmux.change_pane("h")
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      desc = "searcher#finder: focus right",
      callback = function()
        local preview_layout = self:__preview_layout__() ---@type "hidden"|"right"|"bottom"
        if preview_layout == "right" and self.preview ~= nil then
          local winnr = self.preview:get_winnr() ---@type integer|nil
          if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
            self:__focus_pane__("preview")
            return
          end
        elseif preview_layout == "bottom" then
          self:__focus_pane__(self:__should_show_replacer__() and "replacer" or "result")
          return
        end
        if stl.env.IS_TMUX and not dot.state.status.tmux_zen_mode:snapshot() then
          stl.tmux.change_pane("l")
          return
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "searcher#finder: focus up",
      callback = function()
        if stl.env.IS_TMUX and not dot.state.status.tmux_zen_mode:snapshot() then
          stl.tmux.change_pane("k")
          return
        end

        self:__focus_pane__("result")
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-j>",
      desc = "searcher#finder: focus next item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(step)
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-k>",
      desc = "searcher#finder: focus prev item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(-step)
      end,
    },
    {
      modes = { "n", "x" },
      key = "j",
      desc = "searcher#finder: focus next item",
      callback = function()
        local linecount = self.finder.linecount:snapshot() ---@type integer
        if linecount > 1 then
          vim.cmd("normal! j")
        else
          local step = vim.v.count1 or 1 ---@type integer
          self:__result_move_down__(step)
        end
      end,
    },
    {
      modes = { "n", "x" },
      key = "k",
      desc = "searcher#finder: focus prev item",
      callback = function()
        local linecount = self.finder.linecount:snapshot() ---@type integer
        if linecount > 1 then
          vim.cmd("normal! k")
        else
          local step = vim.v.count1 or 1 ---@type integer
          self:__result_move_down__(-step)
        end
      end,
    },
    {
      modes = { "n", "x" },
      key = "gg",
      desc = "searcher#finder: focus first item",
      callback = function()
        local linecount = self.finder.linecount:snapshot() ---@type integer
        if linecount > 1 then
          vim.cmd("normal! gg")
        else
          self:__result_move_to__(1)
        end
      end,
    },
    {
      modes = { "n", "x" },
      key = "G",
      desc = "searcher#finder: focus last item",
      callback = function()
        local linecount = self.finder.linecount:snapshot() ---@type integer
        if linecount > 1 then
          vim.cmd("normal! G")
        else
          local total = self.result.lnum_total:snapshot() ---@type integer
          self:__result_move_to__(total)
        end
      end,
    },
    {
      modes = { "n", "x" },
      key = "dd",
      desc = "searcher#finder: clear content",
      callback = function()
        local linecount = self.finder.linecount:snapshot() ---@type integer
        if linecount > 1 then
          vim.cmd("normal! dd")
        else
          self.finder:set_content("")
        end
      end,
    },
  }
  return builtin_keymaps
end

---@return stl.t.IKeymap[]
function M:__resolve_builtin_keymaps_result__()
  ---@type stl.t.IKeymap[]
  local builtin_keymaps = {
    {
      modes = { "n", "x" },
      key = "d",
      aliases = { "dd", "X", "x" },
      desc = "searcher#result: noop",
      callback = stl.fn.noop,
    },
    {
      modes = { "n", "x" },
      key = "A",
      desc = "searcher#result: back to edit (A)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("A", "n", false)
        end
      end,
    },
    {
      modes = { "n", "x" },
      key = "a",
      desc = "searcher#result: back to edit (a)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("a", "n", false)
        end
      end,
    },
    {
      modes = { "n", "x" },
      key = "I",
      desc = "searcher#result: back to edit (I)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("I", "n", false)
        end
      end,
    },
    {
      modes = { "n", "x" },
      key = "i",
      desc = "searcher#result: back to edit (i)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("i", "n", false)
        end
      end,
    },
    {
      modes = { "n", "x" },
      key = "O",
      desc = "searcher#result: back to edit (O)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("O", "n", false)
        end
      end,
    },
    {
      modes = { "n", "x" },
      key = "o",
      desc = "searcher#result: back to edit (o)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("o", "n", false)
        end
      end,
    },
    {
      disabled = true,
      modes = { "i", "n", "x" },
      key = "<LeftMouse>",
      desc = "searcher#result: focus",
      callback = function()
        local cursor = vim.fn.getmousepos()
        if cursor.winid == self.result:get_winnr() then
          local lnum = cursor.line ---@type integer
          if lnum > 0 then
            self:__result_move_to__(lnum)
            return
          end
        end

        ---! fallback
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true), "n", false)
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "searcher#result: focus down",
      callback = function()
        local preview_layout = self:__preview_layout__() ---@type "hidden"|"right"|"bottom"
        if preview_layout == "bottom" and self.preview ~= nil then
          local winnr = self.preview:get_winnr() ---@type integer|nil
          if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
            self:__focus_pane__("preview")
            return
          end
        end

        if stl.env.IS_TMUX and not dot.state.status.tmux_zen_mode:snapshot() then
          stl.tmux.change_pane("j")
          return
        end

        if not self:__should_show_replacer__() then
          self:__focus_pane__("finder")
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      desc = "searcher#result: focus left",
      callback = function()
        if stl.env.IS_TMUX and not dot.state.status.tmux_zen_mode:snapshot() then
          stl.tmux.change_pane("h")
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      desc = "searcher#result: focus right",
      callback = function()
        local preview_layout = self:__preview_layout__() ---@type "hidden"|"right"|"bottom"
        if preview_layout == "right" and self.preview ~= nil then
          local winnr = self.preview:get_winnr() ---@type integer|nil
          if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
            self:__focus_pane__("preview")
            return
          end
        end

        if stl.env.IS_TMUX and not dot.state.status.tmux_zen_mode:snapshot() then
          stl.tmux.change_pane("l")
          return
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "searcher#result: focus up",
      callback = function()
        if self:__should_show_replacer__() then
          self:__focus_pane__("replacer")
        else
          self:__focus_pane__("finder")
        end
      end,
    },
    {
      modes = { "n", "x" },
      key = "j",
      desc = "searcher#result: focus next item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(step)
      end,
    },
    {
      modes = { "n", "x" },
      key = "k",
      desc = "searcher#result: focus prev item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(-step)
      end,
    },
  }
  return builtin_keymaps
end

---@return stl.t.IKeymap[]
function M:__resolve_builtin_keymaps_replacer__()
  ---@type stl.t.IKeymap[]
  local builtin_keymaps = {
    {
      modes = { "i", "n", "x" },
      key = "<Down>",
      desc = "searcher#replacer: focus next item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(step)
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<Up>",
      desc = "searcher#replacer: focus prev item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(-step)
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-i>",
      desc = "searcher#replacer: history backward",
      callback = function()
        if self._replace_pattern_history == nil then
          return
        end
        local last_input = self._replace_pattern_history:backward() ---@type string|nil
        if last_input ~= nil and self.replacer ~= nil then
          self.replacer:set_content(last_input)
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-o>",
      desc = "searcher#replacer: history forward",
      callback = function()
        if self._replace_pattern_history == nil then
          return
        end
        local next_input = self._replace_pattern_history:forward() ---@type string|nil
        if next_input ~= nil and self.replacer ~= nil then
          self.replacer:set_content(next_input)
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "searcher#replacer: focus down",
      callback = function()
        self:__focus_pane__("result")
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "searcher#replacer: focus up",
      callback = function()
        self:__focus_pane__("finder")
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      desc = "searcher#replacer: focus left",
      callback = function()
        if stl.env.IS_TMUX and not dot.state.status.tmux_zen_mode:snapshot() then
          stl.tmux.change_pane("h")
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      desc = "searcher#replacer: focus right",
      callback = function()
        local preview_layout = self:__preview_layout__() ---@type "hidden"|"right"|"bottom"
        if preview_layout == "right" and self.preview ~= nil then
          local winnr = self.preview:get_winnr() ---@type integer|nil
          if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
            self:__focus_pane__("preview")
            return
          end
        elseif preview_layout == "bottom" then
          self:__focus_pane__("result")
          return
        end
        if stl.env.IS_TMUX and not dot.state.status.tmux_zen_mode:snapshot() then
          stl.tmux.change_pane("l")
          return
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-j>",
      desc = "searcher#replacer: focus next item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(step)
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-k>",
      desc = "searcher#replacer: focus prev item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(-step)
      end,
    },
  }
  return builtin_keymaps
end

---@return stl.t.IKeymap[]
function M:__resolve_builtin_keymaps_preview__()
  ---@type stl.t.IKeymap[]
  local builtin_keymaps = {
    {
      modes = { "n", "x" },
      key = "d",
      aliases = { "dd", "X", "x" },
      desc = "searcher#preview: noop",
      callback = stl.fn.noop,
    },
    {
      modes = { "n", "x" },
      key = "A",
      desc = "searcher#preview: back to edit (A)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("A", "n", false)
        end
      end,
    },
    {
      modes = { "n", "x" },
      key = "a",
      desc = "searcher#preview: back to edit (a)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("a", "n", false)
        end
      end,
    },
    {
      modes = { "n", "x" },
      key = "I",
      desc = "searcher#preview: back to edit (I)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("I", "n", false)
        end
      end,
    },
    {
      modes = { "n", "x" },
      key = "i",
      desc = "searcher#preview: back to edit (i)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("i", "n", false)
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "searcher#preview: focus down",
      callback = function()
        if stl.env.IS_TMUX and not dot.state.status.tmux_zen_mode:snapshot() then
          stl.tmux.change_pane("j")
          return
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      desc = "searcher#preview: focus left",
      callback = function()
        local preview_layout = self:__preview_layout__() ---@type "hidden"|"right"|"bottom"
        if preview_layout == "right" then
          local pane_focused = self._pane_last_focused == "result" and "result" or "finder" ---@type era.searcher.composer.basic.PaneEnum
          self:__focus_pane__(pane_focused)
          return
        end
        if stl.env.IS_TMUX and not dot.state.status.tmux_zen_mode:snapshot() then
          stl.tmux.change_pane("h")
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      desc = "searcher#result: focus right",
      callback = function()
        if stl.env.IS_TMUX and not dot.state.status.tmux_zen_mode:snapshot() then
          stl.tmux.change_pane("l")
          return
        end

        local pane_focused = self._pane_last_focused == "result" and "result" or "finder" ---@type era.searcher.composer.basic.PaneEnum
        self:__focus_pane__(pane_focused)
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "searcher#preview: focus up",
      callback = function()
        local preview_layout = self:__preview_layout__() ---@type "hidden"|"right"|"bottom"
        if preview_layout == "bottom" then
          self:__focus_pane__("result")
          return
        end

        if stl.env.IS_TMUX and not dot.state.status.tmux_zen_mode:snapshot() then
          stl.tmux.change_pane("k")
          return
        end
      end,
    },
  }
  return builtin_keymaps
end

---@param flags                         era.searcher.result.IFlagItemRaw[]
---@param flags_start_index             0|1
---@param keymaps                       stl.t.IKeymap[]
---@return stl.t.IKeymap[]
function M:__resolve_keymaps_finder__(flags, flags_start_index, keymaps)
  local builtin_keymaps_common = self:__resolve_builtin_keymaps_common__(flags, flags_start_index) ---@type stl.t.IKeymap[]
  local builtin_keymaps_finder = self:__resolve_builtin_keymaps_finder__() ---@type stl.t.IKeymap[]
  local resolved_keymaps = vim.list_extend(builtin_keymaps_common, builtin_keymaps_finder) ---@type stl.t.IKeymap[]
  vim.list_extend(resolved_keymaps, keymaps)
  return resolved_keymaps
end

---@param flags                         era.searcher.result.IFlagItemRaw[]
---@param flags_start_index             0|1
---@param keymaps                       stl.t.IKeymap[]
---@return stl.t.IKeymap[]
function M:__resolve_keymaps_replacer__(flags, flags_start_index, keymaps)
  local builtin_keymaps_common = self:__resolve_builtin_keymaps_common__(flags, flags_start_index) ---@type stl.t.IKeymap[]
  local builtin_keymaps_replacer = self:__resolve_builtin_keymaps_replacer__() ---@type stl.t.IKeymap[]
  local resolved_keymaps = vim.list_extend(builtin_keymaps_common, builtin_keymaps_replacer) ---@type stl.t.IKeymap[]
  vim.list_extend(resolved_keymaps, keymaps)
  return resolved_keymaps
end

---@param flags                         era.searcher.result.IFlagItemRaw[]
---@param flags_start_index             0|1
---@param keymaps                       stl.t.IKeymap[]
---@return stl.t.IKeymap[]
function M:__resolve_keymaps_result__(flags, flags_start_index, keymaps)
  local builtin_keymaps_common = self:__resolve_builtin_keymaps_common__(flags, flags_start_index) ---@type stl.t.IKeymap[]
  local builtin_keymaps_result = self:__resolve_builtin_keymaps_result__() ---@type stl.t.IKeymap[]
  local resolved_keymaps = vim.list_extend(builtin_keymaps_common, builtin_keymaps_result) ---@type stl.t.IKeymap[]
  vim.list_extend(resolved_keymaps, keymaps)
  return resolved_keymaps
end

---@param flags                         era.searcher.result.IFlagItemRaw[]
---@param flags_start_index             0|1
---@param keymaps                       stl.t.IKeymap[]
---@return stl.t.IKeymap[]
function M:__resolve_keymaps_preview__(flags, flags_start_index, keymaps)
  local builtin_keymaps_common = self:__resolve_builtin_keymaps_common__(flags, flags_start_index) ---@type stl.t.IKeymap[]
  local builtin_keymaps_preview = self:__resolve_builtin_keymaps_preview__() ---@type stl.t.IKeymap[]
  local resolved_keymaps = vim.list_extend(builtin_keymaps_common, builtin_keymaps_preview) ---@type stl.t.IKeymap[]
  vim.list_extend(resolved_keymaps, keymaps)
  return resolved_keymaps
end

---@param step                          integer
---@return nil
function M:__result_move_down__(step)
  self.result:movedown(step)
end

---@param next_lnum                     integer
---@return nil
function M:__result_move_to__(next_lnum)
  self.result:moveto(next_lnum)
end

---@return boolean
function M:__should_show_preview__()
  return self:__preview_layout__() ~= "hidden"
end

---@protected
---@return "hidden"|"right"|"bottom"
function M:__preview_layout__()
  if self.preview == nil then
    return "hidden"
  end

  if vim.o.columns > 140 then
    return "right"
  end

  local lines = vim.o.lines ---@type integer
  local max_height = math.max(math.floor(lines * 0.9), lines - 10) ---@type integer
  local min_height = math.min(math.floor(lines * 0.6), 56) ---@type integer
  local recommended_height = self._recommended_height <= 1 and math.floor(lines * self._recommended_height)
    or math.floor(self._recommended_height) ---@type integer
  local height = math.min(max_height, math.max(min_height, recommended_height)) ---@type integer

  if height < 32 then
    return "hidden"
  end

  return "bottom"
end

---@return boolean
function M:__should_show_replacer__()
  return self.replacer ~= nil and self._flag_replace ~= nil and self._flag_replace:snapshot()
end

---@protected
---@param flag_replace                  boolean
---@return nil
function M:__toggle_replacer_visibility__(flag_replace)
  if self.replacer == nil then
    return
  end

  local replacer_winnr = self.replacer:get_winnr() ---@type integer|nil

  if flag_replace then
    if replacer_winnr == nil or not vim.api.nvim_win_is_valid(replacer_winnr) then
      self:resize()
    end
  else
    if replacer_winnr ~= nil and vim.api.nvim_win_is_valid(replacer_winnr) then
      local current_winnr = vim.api.nvim_get_current_win() ---@type integer
      if current_winnr == replacer_winnr then
        self._pane_focused = "finder"
        self.finder:focus()
      end

      stl.nvim.win.close(replacer_winnr)
      self:resize()
    end
  end
end

---@param should_show_replacer          boolean
---@param should_show_preview           boolean
---@return string[]
function M:__get_finder_border__(should_show_replacer, should_show_preview)
  if should_show_replacer and should_show_preview then
    return __borders__.finder_with_replacer_and_preview
  elseif should_show_replacer then
    return __borders__.finder_with_replacer
  elseif should_show_preview then
    return __borders__.finder_with_preview
  else
    return __borders__.finder
  end
end

---@protected
---@param preview_layout                "hidden"|"right"|"bottom"
---@param should_show_replacer          boolean
---@return string[]
---@return string[]
---@return string[]
---@diagnostic disable-next-line: unused-local
function M:__get_borders__(preview_layout, should_show_replacer)
  local should_show_preview = preview_layout ~= "hidden" ---@type boolean
  local replacer_border = should_show_preview
      and (preview_layout == "right" and __borders__.replacer_with_preview or __borders__.replacer_stacked)
    or __borders__.replacer
  local result_border = should_show_preview
      and (preview_layout == "right" and __borders__.result_with_preview or __borders__.result_stacked)
    or __borders__.result
  local preview_border = preview_layout == "bottom" and __borders__.preview_stacked or __borders__.preview
  return replacer_border, result_border, preview_border
end

return M
