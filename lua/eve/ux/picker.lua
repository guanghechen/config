local __module_name__ = "eve.ux.picker" ---@type string

---@class eve.ux.picker.highlights
local highlights = {
  finder = table.concat({
    "FloatBorder:FloatBorder",
    "FloatTitle:f_picker_finder_title",
    "Normal:f_picker_finder_normal",
  }, ","),
  result = table.concat({
    "Cursor:f_picker_result_current",
    "CursorColumn:f_picker_result_current",
    "CursorLine:f_picker_result_current",
    "CursorLineNr:f_picker_result_current",
    "FloatBorder:FloatBorder",
    "Normal:f_picker_result_normal",
  }, ","),
  preview = table.concat({
    "Cursor:f_picker_preview_current",
    "CursorColumn:f_picker_preview_current",
    "CursorLine:f_picker_preview_current",
    "CursorLineNr:f_picker_preview_current",
    "FloatBorder:FloatBorder",
    "FloatTitle:f_picker_preview_title",
    "Normal:f_picker_preview_normal",
  }, ","),
}

---@class eve.ux.picker.borders
local borders = {
  -- stylua: ignore start
  finder                = { "╭", "─", "╮", "│", "┤", "─", "├", "│" },
  finder_with_preview   = { "╭", "─", "┬", "│", "┤", "─", "├", "│" },
  finder_without_result = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
  result                = { "├", "─", "┤", "│", "╯", "─", "╰", "│" },
  result_with_preview   = { "├", "─", "┤", "│", "┴", "─", "╰", "│" },
  preview               = { "┬", "─", "╮", "│", "╯", "─", "┴", "│" },
  -- stylua: ignore end
}

---@alias eve.ux.picker.PaneEnum
---| "finder"
---| "preview"
---| "result"

---@alias eve.ux.picker.IResultRender
---| fun(self: eve.ux.Picker, input: string): integer, integer?

---@alias eve.ux.picker.IPreviewRender
---| fun(self: eve.ux.Picker, input: string): string

---@class eve.ux.picker.IWinOptions
---@field public number                 ?boolean
---@field public wrap                   ?boolean

---@class eve.ux.picker.IWinPosition
---@field public width                  integer
---@field public height                 integer
---@field public row                    integer
---@field public col                    integer

---@class eve.ux.IPickerProps
---@field public name                   string
---@field public nsnr                   ?integer
---
---@field public finder_input           ?string
---@field public finder_multiline       ?boolean
---@field public finder_title           string
---@field public finder_win_opts        ?eve.ux.picker.IWinOptions
---
---@field public result_render          eve.ux.picker.IResultRender
---@field public result_win_opts        ?eve.ux.picker.IWinOptions
---
---@field public preview_render         ?eve.ux.picker.IResultRender
---@field public preview_win_opts       ?eve.ux.picker.IWinOptions

---@class eve.ux.Picker
---@field public name                   string
---@field public nsnr                   integer
---
---@field protected _disposed           boolean
---@field protected _visible            boolean
---@field protected _pane_focused       eve.ux.picker.PaneEnum
---
---@field protected _scheduler_finder   eve.std.collection.Scheduler
---@field protected _scheduler_preview  eve.std.collection.Scheduler|nil
---@field protected _scheduler_result   eve.std.collection.Scheduler
---
---@field protected _finder_bufnr       integer|nil
---@field protected _finder_winnr       integer|nil
---@field protected _finder_title       string
---@field protected _finder_winopts     eve.ux.picker.IWinOptions
---@field protected _finder_input       eve.std.collection.Observable
---@field protected _finder_line_count  eve.std.collection.Observable
---@field protected _finder_multiline   boolean
---
---@field protected _result_bufnr       integer|nil
---@field protected _result_winnr       integer|nil
---@field protected _result_winopts     eve.ux.picker.IWinOptions
---@field protected _result_lnum        eve.std.collection.Observable
---@field protected _result_total       eve.std.collection.Observable
---@field protected _result_render      eve.ux.picker.IResultRender
---
---@field protected _preview_bufnr      integer|nil
---@field protected _preview_winnr      integer|nil
---@field protected _preview_title      string|nil
---@field protected _preview_winopts    eve.ux.picker.IWinOptions
---@field protected _preview_render     eve.ux.picker.IPreviewRender|nil
local M = {}
M.__index = M

local NSNR_DEFAULT = vim.api.nvim_create_namespace("ux_view_picker") ---@type integer

---@param props                         eve.ux.IPickerProps
---@return eve.ux.Picker
function M.new(props)
  local name = props.name ---@type string
  local nsnr = props.nsnr or NSNR_DEFAULT ---@type integer
  local initial_input = props.finder_input or "" ---@type string
  local initial_input_lines = vim.split(initial_input, "\n", { plain = true }) ---@type string[]
  local finder_multiline = not not props.finder_multiline ---@type boolean
  local finder_title = string.format(" %s ", vim.trim(props.finder_title)) ---@type string
  local finder_winopts = vim.tbl_deep_extend("force", { number = false, wrap = false }, props.finder_win_opts) ---@type eve.ux.picker.IWinOptions
  local preview_render = props.preview_render ---@type eve.ux.picker.IPreviewRender|nil
  local preview_winopts = vim.tbl_deep_extend("force", { number = true, wrap = false }, props.preview_win_opts) ---@type eve.ux.picker.IWinOptions
  local result_render = props.result_render ---@type eve.ux.picker.IResultRender
  local result_winopts = vim.tbl_deep_extend("force", { number = false, wrap = false }, props.result_win_opts) ---@type eve.ux.picker.IWinOptions

  local finder_input = eve.std.Observable.from_value(initial_input) ---@type eve.std.collection.Observable
  local finder_count = eve.std.Observable.from_value(#initial_input_lines) ---@type eve.std.collection.Observable
  local finder_prompt_nr = nil ---@type integer|nil
  local result_lnum = eve.std.Observable.from_value(0) ---@type eve.std.collection.Observable
  local result_total = eve.std.Observable.from_value(0) ---@type eve.std.collection.Observable

  local self = setmetatable({}, M)

  local scheduler_finder ---@type eve.std.collection.Scheduler
  local scheduler_preview ---@type eve.std.collection.Scheduler|nil
  local scheduler_result ---@type eve.std.collection.Scheduler

  ---@type eve.std.collection.Scheduler
  scheduler_finder = eve.std.Scheduler.new({
    name = string.format("picker:finder:%s", name),
    mode = "debounce",
    delay = 200,
    timeout = 0,
    silent = eve.std.fn.falsy,
    value = eve.std.Observable.from_value(true),
    task = function()
      local bufnr = self:get_finder_bufnr() ---@type integer|nil
      if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      ---! Set the extmark with the right-aligned virtual text
      if finder_prompt_nr then
        vim.api.nvim_buf_del_extmark(bufnr, nsnr, finder_prompt_nr)
        finder_prompt_nr = nil
      end

      local total = result_total:snapshot() ---@type integer
      local lnum = result_lnum:snapshot() ---@type integer
      finder_prompt_nr = vim.api.nvim_buf_set_extmark(bufnr, nsnr, 0, 0, {
        virt_text = { { "" .. lnum .. " / " .. total, "Comment" } },
        virt_text_pos = "right_align",
      })

      ---! Set prompt extmark
      vim.fn.sign_place( --
        bufnr,
        "",
        eve.var.sign.PICKER_FINDER_PROMPT,
        bufnr,
        { lnum = 1, priority = 10 }
      )
    end,
  })

  if preview_render ~= nil then
    scheduler_preview = eve.std.Scheduler.new({
      name = string.format("picker:preview:%s", name),
      mode = "debounce",
      delay = 256,
      timeout = 0,
      silent = eve.std.fn.falsy,
      value = eve.std.Observable.from_value(true),
      task = function(scheduler)
        local bufnr = self:get_preview_bufnr() ---@type integer|nil
        if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        vim.bo[bufnr].modifiable = true
        vim.bo[bufnr].readonly = false

        local input = finder_input:snapshot() ---@type string
        local ok, preview_title = pcall(preview_render, self, input) ---@type boolean, string|nil
        if not ok then
          eve.reporter.error({
            from = __module_name__,
            subject = scheduler.name,
            message = "Failed to render preview",
            details = {
              bufnr = bufnr,
            },
          })
        else
          if preview_title ~= nil then
            ---@diagnostic disable-next-line: invisible
            self._preview_title = string.format(" %s ", vim.trim(preview_title))
          end
        end

        vim.bo[bufnr].modifiable = false
        vim.bo[bufnr].readonly = true
      end,
    })
  end

  ---@type eve.std.collection.Scheduler
  scheduler_result = eve.std.Scheduler.new({
    name = string.format("picker:result:%s", name),
    mode = "debounce",
    delay = 128,
    timeout = 0,
    silent = eve.std.fn.falsy,
    value = eve.std.Observable.from_value(true),
    task = function(scheduler)
      local bufnr = self:get_result_bufnr() ---@type integer|nil
      if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      vim.bo[bufnr].modifiable = true
      vim.bo[bufnr].readonly = false

      local input = finder_input:snapshot() ---@type string
      local ok, lnum, lnum_present = pcall(result_render, self, input) ---@type boolean, integer, integer|nil
      if not ok then
        eve.reporter.error({
          from = __module_name__,
          subject = scheduler.name,
          message = "Failed to render result",
          details = {
            bufnr = bufnr,
          },
        })
        lnum = 1
      end

      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].readonly = true

      local total = vim.api.nvim_buf_line_count(bufnr) ---@type integer
      result_total:next(total)

      lnum = math.min(total, math.max(total > 0 and 1 or 0, lnum)) ---@type integer
      result_lnum:next(lnum)

      vim.fn.sign_unplace("", { buffer = bufnr, id = bufnr })
      if lnum_present ~= nil then
        vim.fn.sign_place(bufnr, "", eve.var.sign.PICKER_RESULT_PRESENT, bufnr, { lnum = lnum, priority = 10 })
      end

      scheduler_finder:schedule()
      if scheduler_preview ~= nil then
        scheduler_preview:schedule()
      end
    end,
  })

  self.name = name
  self.nsnr = nsnr

  self._disposed = false ---@type boolean
  self._visible = false ---@type boolean
  self._pane_focused = "finder" ---@type eve.ux.picker.PaneEnum

  self._scheduler_finder = scheduler_finder
  self._scheduler_preview = scheduler_preview
  self._scheduler_result = scheduler_result

  self._finder_bufnr = nil
  self._finder_winnr = nil
  self._finder_title = finder_title
  self._finder_winopts = finder_winopts
  self._finder_input = finder_input
  self._finder_line_count = finder_count
  self._finder_multiline = finder_multiline

  self._result_bufnr = nil
  self._result_winnr = nil
  self._result_winopts = result_winopts
  self._result_lnum = result_lnum
  self._result_total = result_total
  self._result_render = result_render

  self._preview_bufnr = nil
  self._preview_winnr = nil
  self._preview_title = nil
  self._preview_winopts = preview_winopts
  self._preview_render = preview_render
  return self
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isvisible()
  return self._visible
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true
  self._visible = false

  self._scheduler_finder:dispose()
  self._scheduler_result:dispose()
  if self._scheduler_preview then
    self._scheduler_preview:dispose()
  end

  self._scheduler_finder = nil
  self._scheduler_result = nil
  self._scheduler_preview = nil

  eve.win.close(self._finder_winnr)
  eve.buf.close(self._finder_bufnr)
  eve.win.close(self._result_winnr)
  eve.buf.close(self._result_bufnr)
  eve.win.close(self._preview_winnr)
  eve.buf.close(self._preview_bufnr)

  self._finder_input:dispose()
  self._finder_line_count:dispose()
  self._result_total:dispose()
  self._result_lnum:dispose()

  self._finder_bufnr = nil
  self._finder_winnr = nil
  self._finder_title = nil
  self._finder_winopts = nil
  self._finder_input = nil
  self._finder_line_count = nil
  self._finder_multiline = nil

  self._result_bufnr = nil
  self._result_winnr = nil
  self._result_winopts = nil
  self._result_lnum = nil
  self._result_total = nil
  self._result_render = nil

  self._preview_bufnr = nil
  self._preview_winnr = nil
  self._preview_title = nil
  self._preview_winopts = nil
  self._preview_render = nil
end

---@return nil
function M:close()
  self:__health__()

  self._visible = false
  eve.win.close(self._finder_winnr)
  eve.win.close(self._preview_winnr)
  eve.win.close(self._result_winnr)

  self._finder_winnr = nil
  self._preview_winnr = nil
  self._result_winnr = nil
end

---@return nil
function M:focus()
  self:__health__()

  self._visible = true
  self:__create_wins__()
  self:__focus_pane__()
end

---@return nil
function M:resize()
  self:__health__()

  if not self._visible then
    return
  end

  local finder_winnr, result_winnr, preview_winnr = self:__create_wins__() ---@type integer, integer, integer|nil
  local finder_position, result_position, preview_position = self:__resize__() ---@type eve.ux.picker.IWinPosition, eve.ux.picker.IWinPosition, eve.ux.picker.IWinPosition|nil

  local finder_wincfg = vim.api.nvim_win_get_config(finder_winnr) ---@type vim.api.keyset.win_config
  finder_wincfg.row = finder_position.row
  finder_wincfg.col = finder_position.col
  finder_wincfg.width = finder_position.width
  finder_wincfg.height = finder_position.height

  local result_wincfg = vim.api.nvim_win_get_config(result_winnr) ---@type vim.api.keyset.win_config
  result_wincfg.row = result_position.row
  result_wincfg.col = result_position.col
  result_wincfg.width = result_position.width
  result_wincfg.height = result_position.height

  if preview_winnr ~= nil and preview_position ~= nil then
    local preview_wincfg = vim.api.nvim_win_get_config(preview_winnr) ---@type vim.api.keyset.win_config
    preview_wincfg.row = preview_position.row
    preview_wincfg.col = preview_position.col
    preview_wincfg.width = preview_position.width
    preview_wincfg.height = preview_position.height
  end
end

---@return integer|nil
function M:get_finder_bufnr()
  self:__health__()

  local bufnr = self._finder_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    self._finder_bufnr = nil
    return nil
  end
  return bufnr
end

---@return integer|nil
function M:get_finder_winnr()
  self:__health__()

  local winnr = self._finder_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    self._finder_winnr = nil
    return nil
  end
  return winnr
end

---@return integer|nil
function M:get_result_bufnr()
  self:__health__()

  local bufnr = self._result_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    self._result_bufnr = nil
    return nil
  end
  return bufnr
end

---@return integer|nil
function M:get_result_winnr()
  self:__health__()

  local winnr = self._result_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    self._result_winnr = nil
    return nil
  end
  return winnr
end

---@return integer|nil
function M:get_preview_bufnr()
  self:__health__()

  local bufnr = self._preview_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    self._preview_bufnr = nil
    return nil
  end
  return bufnr
end

---@return integer|nil
function M:get_preview_winnr()
  self:__health__()

  local winnr = self._preview_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    self._preview_winnr = nil
    return nil
  end
  return winnr
end

---@return nil
function M:mark_result_dirty()
  self:__health__()
  self._scheduler_result:schedule()
end

---@param content                       string
---@return nil
function M:set_finder_content(content)
  self:__health__()

  if content == self._finder_input:snapshot() then
    return
  end

  local bufnr = self._finder_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local lines = self._finder_multiline and { content } or vim.split(content, "\n", { plain = true }) ---@type  string[]
  if #lines < 1 then
    lines = { "" } ---@type string[]
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  self._finder_input:next(content)
  self._finder_line_count:next(#lines)

  self._scheduler_finder:schedule()
end

---@param title                         string
---@return nil
function M:set_finder_title(title)
  self:__health__()
  self._finder_title = string.format(" %s ", vim.trim(title)) ---@type string

  local finder_winnr = self._finder_winnr ---@type integer|nil
  if finder_winnr ~= nil and vim.api.nvim_win_is_valid(finder_winnr) then
    local wincfg = vim.api.nvim_win_get_config(finder_winnr) ---@type vim.api.keyset.win_config
    wincfg.title = self._finder_title
    vim.api.nvim_win_set_config(finder_winnr, wincfg)
  else
    M:__create_wins__()
  end
end

---@param title                         string
---@return nil
function M:set_preview_title(title)
  self:__health__()
  self._preview_title = string.format(" %s ", vim.trim(title)) ---@type string

  local should_preview_show = M:__should_show_preview__() ---@type boolean
  if should_preview_show then
    local preview_winnr = self._preview_winnr ---@type integer|nil
    if preview_winnr ~= nil and vim.api.nvim_win_is_valid(preview_winnr) then
      local wincfg = vim.api.nvim_win_get_config(preview_winnr) ---@type vim.api.keyset.win_config
      wincfg.title = self._preview_title
      vim.api.nvim_win_set_config(preview_winnr, wincfg)
    else
      M:__create_wins__()
    end
  end
end

---@protected
---@return integer
---@return integer
---@return integer|nil
function M:__create_bufs__()
  local finder_bufnr = self._finder_bufnr ---@type integer|nil
  local result_bufnr = self._result_bufnr ---@type integer|nil
  local preview_bufnr = self._preview_bufnr ---@type integer|nil
  local has_preview = self._preview_render ~= nil ---@type boolean

  if finder_bufnr == nil or not vim.api.nvim_buf_is_valid(finder_bufnr) then
    finder_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    self._finder_bufnr = finder_bufnr

    vim.bo[finder_bufnr].buflisted = false
    vim.bo[finder_bufnr].buftype = "nofile"
    vim.bo[finder_bufnr].filetype = eve.filetype.UX_PICKER_FINDER
    vim.bo[finder_bufnr].swapfile = false

    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      buffer = finder_bufnr,
      callback = function()
        local lines = vim.api.nvim_buf_get_lines(finder_bufnr, 0, -1, false) ---@type string[]
        local content = table.concat(lines, "\n") ---@type string
        self._finder_input:next(content)
        self._finder_line_count:next(#lines)
        self._scheduler_finder:schedule()
      end,
    })

    self._scheduler_finder:schedule({ immediate = true })
  end

  if result_bufnr == nil or not vim.api.nvim_buf_is_valid(result_bufnr) then
    result_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    self._result_bufnr = result_bufnr

    vim.bo[result_bufnr].buflisted = false
    vim.bo[result_bufnr].buftype = "nofile"
    vim.bo[result_bufnr].filetype = eve.filetype.UX_PICKER_RESULT
    vim.bo[result_bufnr].swapfile = false
    vim.bo[result_bufnr].modifiable = false
    vim.bo[result_bufnr].readonly = true

    self._scheduler_result:schedule({ immediate = true })
  end

  if has_preview then
    if preview_bufnr == nil or not vim.api.nvim_buf_is_valid(preview_bufnr) then
      preview_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
      self._preview_bufnr = preview_bufnr

      vim.bo[preview_bufnr].buflisted = false
      vim.bo[preview_bufnr].buftype = "nofile"
      vim.bo[preview_bufnr].filetype = eve.filetype.UX_PICKER_PREVIEW
      vim.bo[preview_bufnr].swapfile = false
      vim.bo[preview_bufnr].modifiable = false
      vim.bo[preview_bufnr].readonly = true
    end

    self._scheduler_preview:schedule({ immediate = true })
  else
    self._preview_bufnr = nil
    if preview_bufnr ~= nil and vim.api.nvim_buf_is_valid(preview_bufnr) then
      vim.api.nvim_buf_delete(preview_bufnr, { force = true })
    end
  end

  return finder_bufnr, result_bufnr, preview_bufnr
end

---@protected
---@return integer
---@return integer
---@return integer|nil
function M:__create_wins__()
  local should_show_preview = M:__should_show_preview__() ---@type boolean
  local finder_winnr = self._finder_winnr ---@type integer|nil
  local result_winnr = self._result_winnr ---@type integer|nil
  local preview_winnr = self._preview_winnr ---@type integer|nil

  if finder_winnr ~= nil and not vim.api.nvim_win_is_valid(finder_winnr) then
    self._finder_winnr = nil
    finder_winnr = nil
  end

  if result_winnr ~= nil and not vim.api.nvim_win_is_valid(result_winnr) then
    self._result_winnr = nil
    result_winnr = nil
  end

  if preview_winnr ~= nil and not vim.api.nvim_win_is_valid(preview_winnr) then
    self._preview_winnr = nil
    preview_winnr = nil
  end

  if preview_winnr ~= nil and not should_show_preview then
    self._preview_winnr = nil
    eve.win.close(preview_winnr)
    preview_winnr = nil
  end

  if finder_winnr ~= nil and result_winnr ~= nil and (preview_winnr ~= nil or not should_show_preview) then
    return finder_winnr, result_winnr, preview_winnr
  end

  local winblend = eve.state.theme.get_float_winblend() ---@type integer
  local finder_bufnr, result_bufnr, preview_bufnr = self:__create_bufs__() ---@type integer, integer, integer|nil
  local finder_position, result_position, preview_position = self:__resize__() ---@type eve.ux.picker.IWinPosition, eve.ux.picker.IWinPosition, eve.ux.picker.IWinPosition|nil

  local finder_wincfg = {
    relative = "editor",
    row = finder_position.row,
    col = finder_position.col,
    width = finder_position.width,
    height = finder_position.height,
    border = borders.finder,
    style = "minimal",
    focusable = true,
    title = self._finder_title,
    title_pos = "center",
  }
  if finder_winnr == nil then
    finder_wincfg.noautocmd = true
    finder_winnr = vim.api.nvim_open_win(finder_bufnr, false, finder_wincfg)
    self._finder_winnr = finder_winnr
    self._pane_focused = "finder"

    local winopts = self._finder_winopts ---@type eve.ux.picker.IWinOptions
    eve.win.set_type(finder_winnr, eve.win.Types.PICKER_FINDER)
    vim.wo[finder_winnr].number = winopts.number
    vim.wo[finder_winnr].relativenumber = false
    vim.wo[finder_winnr].signcolumn = "yes"
    vim.wo[finder_winnr].spell = false
    vim.wo[finder_winnr].winblend = winblend
    vim.wo[finder_winnr].winfixbuf = true
    vim.wo[finder_winnr].winhighlight = highlights.finder
    vim.wo[finder_winnr].wrap = winopts.wrap
  else
    vim.api.nvim_win_set_config(finder_winnr, finder_wincfg)
    vim.api.nvim_win_set_buf(finder_winnr, finder_bufnr)
  end

  local result_wincfg = {
    relative = "editor",
    row = result_position.row,
    col = result_bufnr,
    width = result_position.width,
    height = result_position.height,
    border = should_show_preview and borders.result_with_preview or borders.result,
    style = "minimal",
    focusable = true,
  }
  if result_winnr == nil then
    result_wincfg.noautocmd = true
    result_winnr = vim.api.nvim_open_win(result_bufnr, false, result_wincfg)
    self._result_winnr = result_winnr
    self._pane_focused = "finder"

    local winopts = self._result_winopts ---@type eve.ux.picker.IWinOptions
    eve.win.set_type(result_winnr, eve.win.Types.PICKER_RESULT)
    vim.wo[result_winnr].number = winopts.number
    vim.wo[result_winnr].signcolumn = "yes"
    vim.wo[result_winnr].spell = false
    vim.wo[result_winnr].winblend = winblend
    vim.wo[result_winnr].winfixbuf = true
    vim.wo[result_winnr].winhighlight = highlights.result
    vim.wo[result_winnr].wrap = winopts.wrap
  else
    vim.api.nvim_win_set_config(result_winnr, result_wincfg)

    vim.wo[result_winnr].winfixbuf = false
    vim.api.nvim_win_set_buf(result_winnr, result_bufnr)
    vim.wo[result_winnr].winfixbuf = true
  end

  if should_show_preview then
    ---@cast preview_bufnr              integer
    ---@cast preview_position           eve.ux.picker.IWinPosition

    local preview_wincfg = {
      relative = "editor",
      row = preview_position.row,
      col = preview_position.col,
      width = preview_position.width,
      height = preview_position.height,
      border = borders.preview,
      style = "minimal",
      focusable = true,
      title = self._preview_title,
      title_pos = "center",
    }

    if preview_winnr == nil then
      preview_wincfg.noautocmd = true
      preview_winnr = vim.api.nvim_open_win(preview_bufnr, false, preview_wincfg)
      self._preview_winnr = preview_winnr
      self._pane_focused = "finder"

      local winopts = self._preview_winopts ---@type eve.ux.picker.IWinOptions
      eve.win.set_type(preview_winnr, eve.win.Types.PICKER_PREVIEW)
      vim.wo[preview_winnr].list = true
      vim.wo[preview_winnr].listchars = string.format(
        "eol:%s,lead:%s,nbsp:%s,space:%s,trail:%s",
        eve.icon.listchars.eol,
        eve.icon.listchars.lead,
        eve.icon.listchars.nbsp,
        eve.icon.listchars.space,
        eve.icon.listchars.trail
      )
      vim.wo[preview_winnr].number = winopts.number
      vim.wo[preview_winnr].relativenumber = false
      vim.wo[preview_winnr].spell = false
      vim.wo[preview_winnr].signcolumn = "yes"
      vim.wo[preview_winnr].winblend = winblend
      vim.wo[preview_winnr].winfixbuf = true
      vim.wo[preview_winnr].winhighlight = highlights.preview
      vim.wo[preview_winnr].wrap = winopts.wrap
    else
      vim.api.nvim_win_set_config(preview_winnr, preview_wincfg)

      vim.wo[preview_winnr].winfixbuf = false
      vim.api.nvim_win_set_buf(preview_winnr, preview_bufnr)
      vim.wo[preview_winnr].winfixbuf = true
    end
  end

  return finder_winnr, result_winnr, preview_winnr
end

---@protected
---@return nil
function M:__focus_pane__()
  local pane_focused = self._pane_focused ---@type eve.ux.picker.PaneEnum
  local winnr ---@type integer|nil

  if pane_focused == "finder" then
    local finder_winnr = self._finder_winnr ---@type integer|nil
    if finder_winnr ~= nil and vim.api.nvim_win_is_valid(finder_winnr) then
      winnr = finder_winnr
    end
  elseif pane_focused == "preview" then
    local preview_winnr = self._preview_winnr ---@type integer|nil
    if preview_winnr ~= nil and vim.api.nvim_win_is_valid(preview_winnr) then
      winnr = preview_winnr
    end
  elseif pane_focused == "result" then
    local result_winnr = self._result_winnr ---@type integer|nil
    if result_winnr ~= nil and vim.api.nvim_win_is_valid(result_winnr) then
      winnr = result_winnr
    end
  end

  if winnr ~= nil then
    vim.api.nvim_set_current_win(winnr)
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

---@return nil
function M:__result_movedown__() end

---@return eve.ux.picker.IWinPosition
---@return eve.ux.picker.IWinPosition
---@return eve.ux.picker.IWinPosition|nil
function M:__resize__()
  local should_show_preview = M:__should_show_preview__() ---@type boolean
  local max_width = math.max(vim.o.columns * 0.9, vim.o.columns - 20) ---@type integer
  local max_height = math.max(vim.o.lines * 0.9, vim.o.lines - 10) ---@type integer

  local width = math.min(200, max_width) ---@type integer
  local height = math.min(56, max_height) ---@type integer
  local row = math.floor((vim.o.columns - width) / 2) ---@type integer
  local col = math.floor((vim.o.lines - height) / 2) ---@type integer

  local finder_width = should_show_preview and math.floor(width / 2) or width ---@type integer
  local finder_height = 1 ---@type integer

  if self._finder_multiline then
    local line_count = self._finder_line_count:snapshot() ---@type integer
    finder_height = math.max(1, math.min(5, math.floor(height * 0.3), line_count)) ---@type integer
  end

  local preview_width = width - finder_width ---@type integer

  ---@type eve.ux.picker.IWinPosition
  local finder_position = {
    row = row,
    col = col,
    width = finder_width,
    height = finder_height,
  }

  ---@type eve.ux.picker.IWinPosition
  local result_position = {
    row = row + finder_height,
    col = col,
    width = finder_width,
    height = height - finder_height,
  }

  local preview_position = nil ---@type eve.ux.picker.IWinPosition|nil
  if should_show_preview then
    ---@type eve.ux.picker.IWinPosition
    preview_position = {
      row = row,
      col = col + finder_width + 1,
      width = preview_width,
      height = height,
    }
  end

  return finder_position, result_position, preview_position
end

---@return boolean
function M:__should_show_preview__()
  return vim.o.columns > 160 and self._scheduler_preview ~= nil
end

return M
