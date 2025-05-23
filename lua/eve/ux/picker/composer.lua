---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker.composer" ---@type string

---@alias eve.ux.picker.composer.PaneEnum
---| "finder"
---| "preview"
---| "result"

---@alias eve.ux.picker.composer.IOnCancel
---| fun(): nil

---@alias eve.ux.picker.composer.IOnClosed
---| fun(self: eve.ux.PickerComposer): nil

---@alias eve.ux.picker.composer.IOnDisposed
---| fun(): nil

---@alias eve.ux.picker.composer.IOnFocused
---| fun(self: eve.ux.PickerComposer): nil

---@alias eve.ux.picker.composer.IOnHidden
---| fun(self: eve.ux.PickerComposer): nil

---@alias eve.ux.picker.composer.IOnRefresh
---| fun(self: eve.ux.PickerComposer, force: boolean): nil

---@alias eve.ux.picker.composer.IOnResultRendered
---| fun(self: eve.ux.PickerComposer, bufnr: integer): nil

---@alias eve.ux.picker.composer.IOnPreviewRendered
---| fun(self: eve.ux.PickerComposer, bufnr: integer): nil

----------------------------------------------------------------------------------------------------

---@class eve.ux.picker.composer.borders
---@field public finder                 string[]
---@field public finder_with_preview    string[]
---@field public finder_without_result  string[]
---@field public result                 string[]
---@field public result_with_preview    string[]
---@field public preview                string[]
local __borders__ = {
  -- stylua: ignore start
  finder                = { "╭", "─", "╮", "│", "┤", "─", "├", "│" },
  finder_with_preview   = { "╭", "─", "┬", "│", "┤", "─", "├", "│" },
  finder_without_result = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
  result                = { "├", "─", "┤", "│", "╯", "─", "╰", "│" },
  result_with_preview   = { "├", "─", "┤", "│", "┴", "─", "╰", "│" },
  preview               = { "┬", "─", "╮", "│", "╯", "─", "┴", "│" },
  -- stylua: ignore end
}

---@class eve.ux.picker.composer.highlights
---@field public finder                 string
---@field public result                 string
---@field public preview                string
local __highlights__ = {
  finder = table.concat({
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

---@class eve.ux.IPickerComposerProps
---@field public uuid                   ?string
---@field public name                   string
---@field public permanent              boolean
---
---@field public flags                  ?eve.ux.picker.result.IFlagItemRaw[]
---@field public flags_start_index      ?0|1
---@field public height                 ?number
---@field public width                  ?number
---
---@field public finder_input           std.collection.IObservable
---@field public finder_input_history   ?std.collection.IHistory
---@field public finder_keymaps         ?std.t.IKeymap[]
---@field public finder_multiline       ?boolean
---@field public finder_title           string
---
---@field public result_keymaps         ?std.t.IKeymap[]
---@field public result_render          eve.ux.picker.result.IDraw
---
---@field public preview_keymaps        ?std.t.IKeymap[]
---@field public preview_render         ?eve.ux.picker.preview.IDraw
---
---@field public on_cancel              ?eve.ux.picker.composer.IOnCancel
---@field public on_closed              ?eve.ux.picker.composer.IOnClosed
---@field public on_disposed            ?eve.ux.picker.composer.IOnDisposed
---@field public on_focused             ?eve.ux.picker.composer.IOnFocused
---@field public on_hidden              ?eve.ux.picker.composer.IOnHidden
---@field public on_refresh             ?eve.ux.picker.composer.IOnRefresh
---@field public on_preview_rendered    ?eve.ux.picker.composer.IOnPreviewRendered
---@field public on_result_rendered     ?eve.ux.picker.composer.IOnResultRendered

---@class eve.ux.PickerComposer : std.t.ux.IWidget
---@field public uuid                   string
---@field public name                   string
---@field public permanent              boolean
---
---@field public finder                 eve.ux.PickerFinder
---@field public result                 eve.ux.PickerResult
---@field public preview                eve.ux.PickerPreview|nil
---
---@field protected _disposed           boolean
---@field protected _pane_focused       eve.ux.picker.composer.PaneEnum
---@field protected _pane_last_focused  eve.ux.picker.composer.PaneEnum
---@field protected _recommended_height number
---@field protected _recommended_width  number
---
---@field protected _finder_input_history ?std.collection.IHistory
---
---@field protected _on_cancel          eve.ux.picker.composer.IOnCancel
---@field protected _on_closed          eve.ux.picker.composer.IOnClosed
---@field protected _on_disposed        eve.ux.picker.composer.IOnDisposed
---@field protected _on_focused         eve.ux.picker.composer.IOnFocused
---@field protected _on_hidden          eve.ux.picker.composer.IOnHidden
---@field protected _on_refresh         eve.ux.picker.composer.IOnRefresh
local M = {}
M.__index = M

---@param props                         eve.ux.IPickerComposerProps
---@return eve.ux.PickerComposer
function M.new(props)
  local uuid = props.uuid or std.fn.uuid() ---@type string
  local name = props.name ---@type string
  local permanent = not not props.permanent ---@type boolean

  local flags = props.flags ---@type eve.ux.picker.result.IFlagItemRaw[]
  local flags_start_index = props.flags_start_index == 0 and 0 or 1 ---@type 0|1
  local pane_focused = "finder" ---@type eve.ux.picker.composer.PaneEnum
  local pane_last_focused = "finder" ---@type eve.ux.picker.composer.PaneEnum
  local recommended_height = math.max(0.1, props.height or 0.8) ---@type number
  local recommended_width = math.max(0.1, props.width or 0.8) ---@type number

  local finder_input = props.finder_input ---@type std.collection.IObservable
  local finder_input_history = props.finder_input_history ---@type std.collection.IHistory
  local finder_keymaps = props.finder_keymaps or {} ---@type std.t.IKeymap[]
  local finder_multiline = not not props.finder_multiline ---@type boolean
  local finder_title = string.format(" %s ", vim.trim(props.finder_title)) ---@type string

  local result_keymaps = props.result_keymaps or {} ---@type std.t.IKeymap[]
  local result_render = props.result_render ---@type eve.ux.picker.result.IDraw

  local preview_keymaps = props.preview_keymaps or {} ---@type std.t.IKeymap[]
  local preview_render = props.preview_render ---@type eve.ux.picker.preview.IDraw|nil

  local on_cancel = props.on_cancel or std.fn.noop ---@type eve.ux.picker.composer.IOnCancel
  local on_closed = props.on_closed or std.fn.noop ---@type eve.ux.picker.composer.IOnClosed
  local on_disposed = props.on_disposed or std.fn.noop ---@type eve.ux.picker.composer.IOnDisposed
  local on_focused = props.on_focused or std.fn.noop ---@type eve.ux.picker.composer.IOnFocused
  local on_hidden = props.on_hidden or std.fn.noop ---@type eve.ux.picker.composer.IOnHidden
  local on_refresh = props.on_refresh or std.fn.noop ---@type eve.ux.picker.composer.IOnRefresh
  local on_preview_rendered = props.on_preview_rendered or std.fn.noop ---@type eve.ux.picker.composer.IOnPreviewRendered
  local on_result_rendered = props.on_result_rendered or std.fn.noop ---@type eve.ux.picker.composer.IOnResultRendered

  local has_finder_input_history = finder_input_history ~= nil ---@type boolean

  local self = setmetatable({}, M)

  ---@type eve.ux.PickerFinder
  local finder = eve.ux.PickerFinder.new({
    name = name,
    keymaps = self:__resolve_finder__keymaps__(
      flags,
      flags_start_index,
      finder_multiline,
      has_finder_input_history,
      finder_keymaps
    ),
    input = finder_input,
    multiline = finder_multiline,
    title = finder_title,
  })

  ---@type eve.ux.PickerResult
  local result = eve.ux.PickerResult.new({
    uuid = uuid,
    name = name,
    draw = function(bufnr)
      if finder_input_history ~= nil then
        local keyword = finder_input:snapshot() ---@type string
        if keyword ~= nil and vim.trim(keyword) ~= "" then
          finder_input_history:push(keyword)
        end
      end
      return result_render(bufnr)
    end,
    keymaps = self:__resolve_result__keymaps__(flags, flags_start_index, result_keymaps),
    flags = flags,
    flags_start_index = flags_start_index,
    ---@type eve.ux.picker.result.IOnDrawed
    on_drawed = function(bufnr)
      self:mark_preview_dirty()
      on_result_rendered(self, bufnr)
    end,
  })

  ---@type eve.ux.PickerPreview|nil
  local preview = nil
  if preview_render ~= nil then
    preview = eve.ux.PickerPreview.new({
      uuid = uuid,
      name = name,
      draw = preview_render,
      keymaps = self:__resolve_preview__keymaps__(flags, flags_start_index, preview_keymaps),
      ---@type eve.ux.picker.preview.IOnDrawed
      on_drawed = function(bufnr)
        on_preview_rendered(self, bufnr)
      end,
    })
  end

  self.uuid = uuid
  self.name = name
  self.permanent = permanent

  self.finder = finder
  self.result = result
  self.preview = preview

  self._disposed = false
  self._pane_focused = pane_focused
  self._pane_last_focused = pane_last_focused
  self._recommended_height = recommended_height
  self._recommended_width = recommended_width

  self._finder_input_history = finder_input_history

  self._on_cancel = on_cancel ---@type eve.ux.picker.composer.IOnCancel
  self._on_closed = on_closed ---@type eve.ux.picker.composer.IOnClosed
  self._on_disposed = on_disposed ---@type eve.ux.picker.composer.IOnDisposed
  self._on_focused = on_focused ---@type eve.ux.picker.composer.IOnFocused
  self._on_hidden = on_hidden ---@type eve.ux.picker.composer.IOnHidden
  self._on_refresh = on_refresh ---@type eve.ux.picker.composer.IOnRefresh

  if preview ~= nil then
    std.fn.observe({ result.lnum_current, result.lnum_total }, function()
      self:mark_preview_dirty()
    end, true)
  end
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  local name = self.name ---@type string
  local finder = self.finder ---@type eve.ux.PickerFinder
  local result = self.result ---@type eve.ux.PickerResult
  local preview = self.preview ---@type eve.ux.PickerPreview|nil
  local on_disposed = self._on_disposed ---@type eve.ux.picker.composer.IOnDisposed
  vim.schedule(function()
    local ok1, error1 = pcall(finder.dispose, finder)
    local ok2, error2 = pcall(result.dispose, result)
    local ok3, error3 = true, nil
    local ok4, error4 = pcall(on_disposed)

    if preview ~= nil then
      ok3, error3 = pcall(preview.dispose, preview)
    end

    if not (ok1 and ok2 and ok3 and ok4) then
      std.reporter.error({
        from = string.format("%s | %s", name, __module_name__),
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

  self.finder = nil
  self.result = nil
  self.preview = nil

  self._pane_focused = nil
  self._pane_last_focused = nil
  self._recommended_height = nil
  self._recommended_width = nil

  self._finder_input_history = nil

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
      std.reporter.error({
        from = string.format("%s | %s", self.name, __module_name__),
        subject = "close",
        message = "Failed to call on_closed",
        details = { error = error },
      })
    end
  end)
end

---@param pane                         eve.ux.picker.composer.PaneEnum|nil
---@return nil
function M:focus(pane)
  self:__health__()
  eve.widget.push(self)

  local has_new_created = self:__create_wins__()
  local pane_focused = has_new_created and "finder" or self._pane_focused ---@type eve.ux.picker.composer.PaneEnum
  self:__focus_pane__(pane or pane_focused)

  vim.schedule(function()
    local ok, error = pcall(self._on_focused, self)
    if not ok then
      std.reporter.error({
        from = string.format("%s | %s", self.name, __module_name__),
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
      std.reporter.error({
        from = string.format("%s | %s", self.name, __module_name__),
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
    or self.result:get_winnr() == winnr
    or (self.preview ~= nil and self.preview:get_winnr() == winnr)
end

---@return boolean
function M:isvisible()
  if self._disposed then
    return false
  end
  return self.finder:isvisible() or self.result:isvisible() or (self.preview ~= nil and self.preview:isvisible())
end

---@return integer
function M:get_result_lnum()
  self:__health__()
  return self.result.lnum_current:snapshot()
end

---@return eve.ux.PickerComposer
function M:mark_result_dirty()
  self:__health__()
  self.result:mark_content_dirty()
  if self.preview ~= nil then
    self.preview:mark_content_dirty()
  end
  return self
end

---@return eve.ux.PickerComposer
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
  if has_new_created then
    self:__focus_pane__("finder")
    return
  end

  local finder_dimension, result_dimension, preview_dimension = self:__layout__() ---@type std.t.IWinDimension, std.t.IWinDimension, std.t.IWinDimension|nil
  self.finder:resize(finder_dimension)
  self.result:resize(result_dimension)
  if self.preview ~= nil and preview_dimension ~= nil then
    self.preview:resize(preview_dimension)
  end
end

---@param lnum                          integer
---@return eve.ux.PickerComposer
function M:set_result_lnum(lnum)
  self:__health__()
  self.result:set_lnum_current(lnum)
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@return boolean
---@return integer
---@return integer
---@return integer|nil
function M:__create_wins__()
  local finder = self.finder ---@type eve.ux.PickerFinder
  local result = self.result ---@type eve.ux.PickerResult
  local preview = self.preview ---@type eve.ux.PickerPreview|nil

  local finder_winnr = finder:get_winnr() ---@type integer|nil
  local result_winnr = result:get_winnr() ---@type integer|nil
  local preview_winnr = preview and preview:get_winnr() or nil ---@type integer|nil

  if finder_winnr ~= nil and not vim.api.nvim_win_is_valid(finder_winnr) then
    finder_winnr = nil
  end

  if result_winnr ~= nil and not vim.api.nvim_win_is_valid(result_winnr) then
    result_winnr = nil
  end

  if preview_winnr ~= nil and not vim.api.nvim_win_is_valid(preview_winnr) then
    preview_winnr = nil
  end

  local should_show_preview = self:__should_show_preview__() ---@type boolean
  if preview_winnr ~= nil and not should_show_preview then
    eve.win.close(preview_winnr)
    preview_winnr = nil
  end

  if finder_winnr ~= nil and result_winnr ~= nil and (preview_winnr ~= nil or not should_show_preview) then
    return false, finder_winnr, result_winnr, preview_winnr
  end

  local finder_dimension, result_dimension, preview_dimension = self:__layout__() ---@type std.t.IWinDimension, std.t.IWinDimension, std.t.IWinDimension|nil

  ---@type eve.ux.picker.finder.IWinOpts
  local finder_winopts = {
    border = should_show_preview and __borders__.finder_with_preview or __borders__.finder,
    winhighlight = __highlights__.finder,
  }
  finder_winnr = finder:create_win(finder_winopts, finder_dimension)

  ---@type eve.ux.picker.result.IWinOpts
  local result_winopts = {
    border = should_show_preview and __borders__.result_with_preview or __borders__.result,
    winhighlight = __highlights__.result,
  }
  result_winnr = result:create_win(result_winopts, result_dimension)

  if preview ~= nil and preview_dimension ~= nil and should_show_preview then
    ---@type eve.ux.picker.preview.IWinOpts
    local preview_winopts = {
      border = __borders__.preview,
      winhighlight = __highlights__.preview,
    }
    preview_winnr = preview:create_win(preview_winopts, preview_dimension) ---@type integer|nil
  end

  return true, finder_winnr, result_winnr, preview_winnr
end

---@protected
---@param pane_focused                  eve.ux.picker.composer.PaneEnum
---@return nil
function M:__focus_pane__(pane_focused)
  if pane_focused == "finder" then
    self.finder:focus()
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
    local message = string.format("[%s#%s] already been disposed.", __module_name__, self.name) ---@type string
    error(message)
  end
end

---@protected
---@return nil
function M:__hide__()
  local finder = self.finder ---@type eve.ux.PickerFinder
  local result = self.result ---@type eve.ux.PickerResult
  local preview = self.preview ---@type eve.ux.PickerPreview|nil

  finder:hide()
  result:hide()
  if preview ~= nil then
    preview:hide()
  end
end

---@return std.t.IWinDimension
---@return std.t.IWinDimension
---@return std.t.IWinDimension|nil
function M:__layout__()
  local should_show_preview = self:__should_show_preview__() ---@type boolean
  local max_height = math.max(math.floor(vim.o.lines * 0.9), vim.o.lines - 10) ---@type integer
  local max_width = math.max(math.floor(vim.o.columns * 0.9), vim.o.columns - 20) ---@type integer

  local min_height = math.min(math.floor(vim.o.lines * 0.6), 56) ---@type integer
  local min_width = should_show_preview and math.min(math.floor(vim.o.columns * 0.6), 160)
    or math.min(math.floor(vim.o.columns * 0.4), 80)

  local recommended_height = self._recommended_height <= 1 and math.floor(vim.o.lines * self._recommended_height)
    or math.floor(self._recommended_height) ---@type integer
  local recommended_width = self._recommended_width <= 1 and math.floor(vim.o.columns * self._recommended_width)
    or math.floor(self._recommended_width) ---@type integer

  local height = math.min(max_height, math.max(min_height, recommended_height)) ---@type integer
  local width = math.min(max_width, math.max(min_width, recommended_width)) ---@type integer

  local row = math.floor((vim.o.lines - height - 3) / 2) ---@type integer
  local col = math.floor((vim.o.columns - width - 2) / 2) ---@type integer

  local finder_width = should_show_preview and math.floor(width / 2) or width ---@type integer
  local finder_height = 1 ---@type integer
  local preview_width = width - finder_width ---@type integer

  local finder = self.finder ---@type eve.ux.PickerFinder
  if finder.multiline then
    local linecount = finder.linecount:snapshot() ---@type integer
    finder_height = math.max(1, math.min(5, math.floor(height * 0.3), linecount)) ---@type integer
  end

  ---@type std.t.IWinDimension
  local finder_dimension = {
    row = row,
    col = col,
    height = finder_height,
    width = finder_width,
  }

  ---@type std.t.IWinDimension
  local result_dimension = {
    row = row + finder_height + 1,
    col = col,
    height = height - finder_height - 1,
    width = finder_width,
  }

  local preview_dimension = nil ---@type std.t.IWinDimension|nil
  if should_show_preview then
    ---@type std.t.IWinDimension
    preview_dimension = {
      row = row,
      col = col + finder_width + 1,
      height = height,
      width = preview_width,
    }
  end
  return finder_dimension, result_dimension, preview_dimension
end

---@param flags                         eve.ux.picker.result.IFlagItemRaw[]
---@param flags_start_index             0|1
---@return std.t.IKeymap[]
function M:__resolve_builtin_common_keymaps__(flags, flags_start_index)
  ---@type std.t.IKeymap[]
  local builtin_keymaps = {
    {
      modes = { "n", "v" },
      key = "q",
      desc = "picker: close",
      callback = function()
        self:close()
        local ok, error = pcall(self._on_cancel)
        if not ok then
          std.reporter.error({
            from = string.format("%s | %s", self.name, __module_name__),
            subject = "close",
            message = "Failed to call on_cancel",
            details = { error = error },
          })
        end
      end,
    },

    {
      disabled = self._on_refresh == std.fn.noop,
      modes = { "i", "n", "v" },
      key = "<C-a>r",
      aliases = { "<D-r>", "<M-r>" },
      desc = "picker: refresh",
      callback = function()
        local refresh_ok, refresh_error = pcall(self._on_refresh, self, true)
        if not refresh_ok then
          std.reporter.error({
            from = string.format("%s | %s", self.name, __module_name__),
            subject = "refresh",
            message = "Failed to run on_refresh",
            details = { error = refresh_error },
          })
        end
      end,
    },
  }

  local index = flags_start_index ---@type integer
  for _, item in ipairs(flags) do
    ---@type std.t.IKeymap
    local keymap = {
      modes = { "n" },
      key = string.format("<leader>%d", index),
      desc = item.desc,
      callback = item.callback,
    }
    builtin_keymaps[#builtin_keymaps + 1] = keymap
    index = index + 1
  end
  return builtin_keymaps
end

---@param finder_multiline              boolean
---@param has_input_history             boolean
---@return std.t.IKeymap[]
function M:__resolve_builtin_finder_keymaps__(finder_multiline, has_input_history)
  ---@type std.t.IKeymap[]
  local builtin_keymaps = {
    {
      disabled = finder_multiline,
      modes = { "n", "v" },
      key = "o",
      aliases = { "O", "<enter>" },
      desc = "picker#finder: noop",
      callback = std.fn.noop,
    },
    {
      disabled = finder_multiline,
      modes = { "i" },
      key = "<enter>",
      desc = "picker#finder: noop",
      callback = std.fn.noop,
    },
    {
      disabled = finder_multiline,
      modes = { "n", "v" },
      key = "j",
      desc = "picker#finder: focus next item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(step)
      end,
    },
    {
      disabled = finder_multiline,
      modes = { "i", "n", "v" },
      key = "<Down>",
      desc = "picker#finder: focus next item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(step)
      end,
    },
    {
      disabled = finder_multiline,
      modes = { "n", "v" },
      key = "gg",
      desc = "picker#finder: focus first item",
      callback = function()
        self:__result_move_to__(1)
      end,
    },
    {
      disabled = finder_multiline,
      modes = { "n", "v" },
      key = "G",
      desc = "picker#finder: focus last item",
      callback = function()
        local total = self.result.lnum_total:snapshot() ---@type integer
        self:__result_move_to__(total)
      end,
    },
    {
      disabled = finder_multiline,
      modes = { "n", "v" },
      key = "k",
      desc = "picker#finder: focus prev item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(-step)
      end,
    },
    {
      disabled = finder_multiline,
      modes = { "i", "n", "v" },
      key = "<Up>",
      desc = "picker#finder: focus prev item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(-step)
      end,
    },
    {
      disabled = not has_input_history,
      modes = { "i", "n", "v" },
      key = "<C-i>",
      desc = "picker#finder: history backward",
      callback = function()
        local last_input = self._finder_input_history:backward() ---@type string|nil
        if last_input ~= nil then
          self.finder:set_content(last_input)
        end
      end,
    },
    {
      disabled = not has_input_history,
      modes = { "i", "n", "v" },
      key = "<C-o>",
      desc = "picker#finder: history forward",
      callback = function()
        local next_input = self._finder_input_history:forward() ---@type string|nil
        if next_input ~= nil then
          self.finder:set_content(next_input)
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "picker#finder: focus down",
      callback = function()
        self:__focus_pane__("result")
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      desc = "picker#finder: focus left",
      callback = function()
        if std.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          std.tmux.change_pane("h")
          return
        end

        if self.preview ~= nil then
          local winnr = self.preview:get_winnr() ---@type integer|nil
          if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
            self:__focus_pane__("preview")
            return
          end
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      desc = "picker#finder: focus right",
      callback = function()
        if self.preview ~= nil then
          local winnr = self.preview:get_winnr() ---@type integer|nil
          if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
            self:__focus_pane__("preview")
            return
          end
        end
        if std.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          std.tmux.change_pane("l")
          return
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "picker#finder: focus up",
      callback = function()
        if std.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          std.tmux.change_pane("k")
          return
        end

        self:__focus_pane__("result")
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-j>",
      desc = "picker#finder: focus next item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(step)
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-k>",
      desc = "picker#finder: focus prev item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(-step)
      end,
    },
  }
  return builtin_keymaps
end

---@return std.t.IKeymap[]
function M:__resolve_builtin_result_keymaps__()
  ---@type std.t.IKeymap[]
  local builtin_keymaps = {
    {
      modes = { "n", "v" },
      key = "d",
      aliases = { "dd", "X", "x" },
      desc = "picker#result: noop",
      callback = std.fn.noop,
    },
    {
      modes = { "n", "v" },
      key = "A",
      desc = "picker#result: back to edit (A)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("A", "n", false)
        end
      end,
    },
    {
      modes = { "n", "v" },
      key = "a",
      desc = "picker#result: back to edit (a)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("a", "n", false)
        end
      end,
    },
    {
      modes = { "n", "v" },
      key = "I",
      desc = "picker#result: back to edit (I)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("I", "n", false)
        end
      end,
    },
    {
      modes = { "n", "v" },
      key = "i",
      desc = "picker#result: back to edit (i)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("i", "n", false)
        end
      end,
    },
    {
      modes = { "n", "v" },
      key = "O",
      desc = "picker#result: back to edit (O)",
      callback = function()
        self:__focus_pane__("finder")

        if self.finder.multiline then
          local winnr = vim.api.nvim_get_current_win() ---@type integer
          if winnr == self.finder:get_winnr() then
            vim.api.nvim_feedkeys("O", "n", false)
          end
        end
      end,
    },
    {
      modes = { "n", "v" },
      key = "o",
      desc = "picker#result: back to edit (o)",
      callback = function()
        self:__focus_pane__("finder")

        if self.finder.multiline then
          local winnr = vim.api.nvim_get_current_win() ---@type integer
          if winnr == self.finder:get_winnr() then
            vim.api.nvim_feedkeys("o", "n", false)
          end
        end
      end,
    },
    {
      disabled = true,
      modes = { "i", "n", "v" },
      key = "<LeftMouse>",
      desc = "picker#result: focus",
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
      modes = { "i", "n", "v" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "picker#result: focus down",
      callback = function()
        if std.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          std.tmux.change_pane("j")
          return
        end

        self:__focus_pane__("finder")
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      desc = "picker#result: focus left",
      callback = function()
        if std.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          std.tmux.change_pane("h")
          return
        end

        if self.preview ~= nil then
          local winnr = self.preview:get_winnr() ---@type integer|nil
          if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
            self:__focus_pane__("preview")
            return
          end
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      desc = "picker#result: focus right",
      callback = function()
        if self.preview ~= nil then
          local winnr = self.preview:get_winnr() ---@type integer|nil
          if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
            self:__focus_pane__("preview")
            return
          end
        end

        if std.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          std.tmux.change_pane("l")
          return
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "picker#result: focus up",
      callback = function()
        self:__focus_pane__("finder")
      end,
    },
    {
      modes = { "n", "v" },
      key = "j",
      desc = "picker#result: focus next item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(step)
      end,
    },
    {
      modes = { "n", "v" },
      key = "k",
      desc = "picker#result: focus prev item",
      callback = function()
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(-step)
      end,
    },
  }
  return builtin_keymaps
end

---@return std.t.IKeymap[]
function M:__resolve_builtin_preview_keymaps__()
  ---@type std.t.IKeymap[]
  local builtin_keymaps = {
    {
      modes = { "n", "v" },
      key = "d",
      aliases = { "dd", "X", "x" },
      desc = "picker#preview: noop",
      callback = std.fn.noop,
    },
    {
      modes = { "n", "v" },
      key = "A",
      desc = "picker#preview: back to edit (A)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("A", "n", false)
        end
      end,
    },
    {
      modes = { "n", "v" },
      key = "a",
      desc = "picker#preview: back to edit (a)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("a", "n", false)
        end
      end,
    },
    {
      modes = { "n", "v" },
      key = "I",
      desc = "picker#preview: back to edit (I)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("I", "n", false)
        end
      end,
    },
    {
      modes = { "n", "v" },
      key = "i",
      desc = "picker#preview: back to edit (i)",
      callback = function()
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self.finder:get_winnr() then
          vim.api.nvim_feedkeys("i", "n", false)
        end
      end,
    },
    {
      modes = { "n", "v" },
      key = "O",
      desc = "picker#preview: back to edit (O)",
      callback = function()
        self:__focus_pane__("finder")

        if self.finder.multiline then
          local winnr = vim.api.nvim_get_current_win() ---@type integer
          if winnr == self.finder:get_winnr() then
            vim.api.nvim_feedkeys("O", "n", false)
          end
        end
      end,
    },
    {
      modes = { "n", "v" },
      key = "o",
      desc = "picker#preview: back to edit (o)",
      callback = function()
        self:__focus_pane__("finder")

        if self.finder.multiline then
          local winnr = vim.api.nvim_get_current_win() ---@type integer
          if winnr == self.finder:get_winnr() then
            vim.api.nvim_feedkeys("o", "n", false)
          end
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "picker#preview: focus down",
      callback = function()
        if std.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          std.tmux.change_pane("j")
          return
        end
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      desc = "picker#result: focus left",
      callback = function()
        local pane_focused = self._pane_last_focused == "result" and "result" or "finder" ---@type eve.ux.picker.composer.PaneEnum
        self:__focus_pane__(pane_focused)
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      desc = "picker#result: focus right",
      callback = function()
        if std.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          std.tmux.change_pane("l")
          return
        end

        local pane_focused = self._pane_last_focused == "result" and "result" or "finder" ---@type eve.ux.picker.composer.PaneEnum
        self:__focus_pane__(pane_focused)
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "picker#preview: focus up",
      callback = function()
        if std.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          std.tmux.change_pane("k")
          return
        end
      end,
    },
  }
  return builtin_keymaps
end

---@param flags                         eve.ux.picker.result.IFlagItemRaw[]
---@param flags_start_index             0|1
---@param finder_multiline              boolean
---@param has_input_history             boolean
---@param keymaps                       std.t.IKeymap[]
---@return std.t.IKeymap[]
function M:__resolve_finder__keymaps__(flags, flags_start_index, finder_multiline, has_input_history, keymaps)
  local builtin_common_keymaps = self:__resolve_builtin_common_keymaps__(flags, flags_start_index) ---@type std.t.IKeymap[]
  local builtin_finder_keymaps = self:__resolve_builtin_finder_keymaps__(finder_multiline, has_input_history) ---@type std.t.IKeymap[]
  local resolved_keymaps = vim.list_extend(builtin_common_keymaps, builtin_finder_keymaps) ---@type std.t.IKeymap[]
  vim.list_extend(resolved_keymaps, keymaps)
  return resolved_keymaps
end

---@param flags                         eve.ux.picker.result.IFlagItemRaw[]
---@param flags_start_index             0|1
---@param keymaps                       std.t.IKeymap[]
---@return std.t.IKeymap[]
function M:__resolve_result__keymaps__(flags, flags_start_index, keymaps)
  local builtin_common_keymaps = self:__resolve_builtin_common_keymaps__(flags, flags_start_index) ---@type std.t.IKeymap[]
  local builtin_result_keymaps = self:__resolve_builtin_result_keymaps__() ---@type std.t.IKeymap[]
  local resolved_keymaps = vim.list_extend(builtin_common_keymaps, builtin_result_keymaps) ---@type std.t.IKeymap[]
  vim.list_extend(resolved_keymaps, keymaps)
  return resolved_keymaps
end

---@param flags                         eve.ux.picker.result.IFlagItemRaw[]
---@param flags_start_index             0|1
---@param keymaps                       std.t.IKeymap[]
---@return std.t.IKeymap[]
function M:__resolve_preview__keymaps__(flags, flags_start_index, keymaps)
  local builtin_common_keymaps = self:__resolve_builtin_common_keymaps__(flags, flags_start_index) ---@type std.t.IKeymap[]
  local builtin_preview_keymaps = self:__resolve_builtin_preview_keymaps__() ---@type std.t.IKeymap[]
  local resolved_keymaps = vim.list_extend(builtin_common_keymaps, builtin_preview_keymaps) ---@type std.t.IKeymap[]
  vim.list_extend(resolved_keymaps, keymaps)
  return resolved_keymaps
end

---@param step                         integer
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
  return self.preview ~= nil and vim.o.columns > 160
end

return M
