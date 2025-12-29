local __module_name__ = "dot.module.board.act" ---@type string

---@alias dot.module.board.act.IRenderPreview
---| fun(bufnr: integer, input: string): nil

---@alias dot.module.board.act.IOnConfirm
---| fun(input: string): nil

---@alias dot.module.board.act.IOnCancel
---| fun(): nil

---@alias dot.module.board.act.IOnInputChange
---| fun(input: string): nil

---@alias dot.module.board.act.IGetWidth
---| fun(): integer

---@class dot.module.board.act.IProps
---@field public name                   string
---@field public title                  string
---@field public initial_input          ?string
---@field public preview_lines          ?integer
---@field public render_preview         dot.module.board.act.IRenderPreview
---@field public on_input_change        ?dot.module.board.act.IOnInputChange
---@field public on_confirm             dot.module.board.act.IOnConfirm
---@field public on_cancel              ?dot.module.board.act.IOnCancel
---@field public keymaps                ?stl.t.IKeymap[]
---@field public width                  ?number
---@field public get_width              ?dot.module.board.act.IGetWidth

---@class dot.module.board.act.IState
---@field protected _disposed           boolean
---@field protected _input_bufnr        integer|nil
---@field protected _input_winnr        integer|nil
---@field protected _preview_bufnr      integer|nil
---@field protected _preview_winnr      integer|nil
---@field protected _ns                 integer
---@field protected _input              stl.c.Observable
---@field protected _preview_debounced  ark.timer.IDisposableCallable

---@class dot.module.board.Act : dot.module.board.act.IState
---@field public fullname               string
---@field public title                  string
---@field public render_preview         dot.module.board.act.IRenderPreview
---@field public on_input_change        dot.module.board.act.IOnInputChange
---@field public on_confirm             dot.module.board.act.IOnConfirm
---@field public on_cancel              dot.module.board.act.IOnCancel
---@field protected _keymaps            stl.t.IKeymap[]
---@field protected _preview_lines      integer
---@field protected _recommended_width  number
---@field protected _get_width          dot.module.board.act.IGetWidth|nil
local M = {}
M.__index = M

local MAX_WIDTH = 120 ---@type integer

---@class dot.module.board.act.borders
---@field public input                  string[]
---@field public preview                string[]
local __borders__ = {
  -- stylua: ignore start
  input   = { "╭", "─", "╮", "│", "┤", "─", "├", "│" },
  preview = { "├", "─", "┤", "│", "╯", "─", "╰", "│" },
  -- stylua: ignore end
}

---@class dot.module.board.act.highlights
---@field public input                  string
---@field public preview                string
local __highlights__ = {
  input = table.concat({
    "FloatBorder:FloatActiveBorder",
    "FloatTitle:f_pk_finder_title",
    "Normal:f_pk_finder_normal",
  }, ","),
  preview = table.concat({
    "FloatBorder:FloatBorder",
    "Normal:f_pk_result_normal",
  }, ","),
}

---@param props                         dot.module.board.act.IProps
---@return dot.module.board.Act
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local title = string.format(" %s ", vim.trim(props.title)) ---@type string
  local initial_input = props.initial_input or "" ---@type string

  local render_preview = props.render_preview ---@type dot.module.board.act.IRenderPreview
  local on_input_change = props.on_input_change or stl.fn.noop ---@type dot.module.board.act.IOnInputChange
  local on_confirm = props.on_confirm ---@type dot.module.board.act.IOnConfirm
  local on_cancel = props.on_cancel or stl.fn.noop ---@type dot.module.board.act.IOnCancel

  local keymaps = props.keymaps or {} ---@type stl.t.IKeymap[]
  local preview_lines = props.preview_lines or 5 ---@type integer
  local recommended_width = math.max(0.1, props.width or 0.6) ---@type number
  local get_width = props.get_width ---@type dot.module.board.act.IGetWidth|nil

  local input = stl.c.Observable.from_value(initial_input) ---@type stl.c.Observable

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.title = title
  self.render_preview = render_preview
  self.on_input_change = on_input_change
  self.on_confirm = on_confirm
  self.on_cancel = on_cancel

  self._disposed = false
  self._input_bufnr = nil
  self._input_winnr = nil
  self._preview_bufnr = nil
  self._preview_winnr = nil
  self._ns = vim.api.nvim_create_namespace(string.format("board_act_%s", name))
  self._input = input
  self._keymaps = keymaps
  self._preview_lines = preview_lines
  self._recommended_width = recommended_width
  self._get_width = get_width

  self._preview_debounced = ark.timer.debounce(function()
    local bufnr = self._preview_bufnr ---@type integer|nil
    if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    vim.bo[bufnr].modifiable = true
    vim.bo[bufnr].readonly = false
    local ok, result = pcall(render_preview, bufnr, input:snapshot())
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].readonly = true

    if not ok then
      stl.reporter.error({
        from = fullname,
        subject = "render_preview",
        message = "Failed to render preview",
        details = { bufnr = bufnr, error = result },
      })
    end
  end, 64)

  stl.fn.observe({ input }, function()
    self._preview_debounced()
    local ok, result = pcall(on_input_change, input:snapshot())
    if not ok then
      stl.reporter.error({
        from = fullname,
        subject = "on_input_change",
        message = "Failed to call on_input_change",
        details = { error = result },
      })
    end
  end, true)

  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  local input_bufnr = self._input_bufnr ---@type integer|nil
  local input_winnr = self._input_winnr ---@type integer|nil
  local preview_bufnr = self._preview_bufnr ---@type integer|nil
  local preview_winnr = self._preview_winnr ---@type integer|nil
  local input = self._input ---@type stl.c.Observable
  local preview_debounced = self._preview_debounced ---@type ark.timer.IDisposableCallable

  self._input_bufnr = nil
  self._input_winnr = nil
  self._preview_bufnr = nil
  self._preview_winnr = nil
  self._input = nil
  self._preview_debounced = nil

  local ok1, error1 = pcall(input.dispose, input)
  local ok2, error2 = pcall(preview_debounced.dispose, preview_debounced)
  local ok3, error3 = pcall(ark.vim.win.close, input_winnr)
  local ok4, error4 = pcall(ark.vim.win.close, preview_winnr)
  local ok5, error5 = pcall(ark.vim.buf.close, input_bufnr)
  local ok6, error6 = pcall(ark.vim.buf.close, preview_bufnr)

  if not (ok1 and ok2 and ok3 and ok4 and ok5 and ok6) then
    stl.reporter.error({
      from = self.fullname,
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
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isvisible()
  local input_winnr = self._input_winnr ---@type integer|nil
  local preview_winnr = self._preview_winnr ---@type integer|nil
  return (input_winnr ~= nil and vim.api.nvim_win_is_valid(input_winnr))
    or (preview_winnr ~= nil and vim.api.nvim_win_is_valid(preview_winnr))
end

---@return nil
function M:close()
  if self._disposed then
    return
  end
  self:dispose()
end

---@return nil
function M:open()
  if self._disposed then
    return
  end

  if self:isvisible() then
    self:__focus_input__()
    return
  end

  self:__create_wins__()
  self:__focus_input__()
  vim.cmd("startinsert!")
end

---@return nil
function M:confirm()
  if self._disposed then
    return
  end

  local input_value = self._input:snapshot() ---@type string
  self:dispose()

  local ok, result = pcall(self.on_confirm, input_value)
  if not ok then
    stl.reporter.error({
      from = self.fullname,
      subject = "confirm",
      message = "Failed to call on_confirm",
      details = { error = result },
    })
  end
end

---@return nil
function M:cancel()
  if self._disposed then
    return
  end

  self:dispose()

  local ok, result = pcall(self.on_cancel)
  if not ok then
    stl.reporter.error({
      from = self.fullname,
      subject = "cancel",
      message = "Failed to call on_cancel",
      details = { error = result },
    })
  end
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__create_wins__()
  local input_dimension, preview_dimension = self:__layout__() ---@type dot.t.IWinDimension, dot.t.IWinDimension
  local zindex = dot.win.resolve_zindex() ---@type integer
  local winblend = dot.context.theme.get_float_winblend() ---@type integer

  local input_bufnr = self:__create_input_buf__() ---@type integer
  local input_winnr = vim.api.nvim_open_win(input_bufnr, false, {
    relative = "editor",
    row = input_dimension.row,
    col = input_dimension.col,
    width = input_dimension.width,
    height = input_dimension.height,
    border = __borders__.input,
    style = "minimal",
    focusable = true,
    noautocmd = true,
    title = self.title,
    title_pos = "center",
    zindex = zindex,
  })
  self._input_winnr = input_winnr

  dot.win.set_type(input_winnr, ark.vim.win.Types.BOARD)
  vim.wo[input_winnr].cursorline = false
  vim.wo[input_winnr].number = false
  vim.wo[input_winnr].relativenumber = false
  vim.wo[input_winnr].signcolumn = "yes"
  vim.wo[input_winnr].spell = false
  vim.wo[input_winnr].winblend = winblend
  vim.wo[input_winnr].winfixbuf = true
  vim.wo[input_winnr].winhighlight = __highlights__.input
  vim.wo[input_winnr].wrap = false

  local preview_bufnr = self:__create_preview_buf__() ---@type integer
  local preview_winnr = vim.api.nvim_open_win(preview_bufnr, false, {
    relative = "editor",
    row = preview_dimension.row,
    col = preview_dimension.col,
    width = preview_dimension.width,
    height = preview_dimension.height,
    border = __borders__.preview,
    style = "minimal",
    focusable = false,
    noautocmd = true,
    zindex = zindex,
  })
  self._preview_winnr = preview_winnr

  dot.win.set_type(preview_winnr, ark.vim.win.Types.BOARD)
  vim.wo[preview_winnr].cursorline = false
  vim.wo[preview_winnr].number = false
  vim.wo[preview_winnr].relativenumber = false
  vim.wo[preview_winnr].signcolumn = "no"
  vim.wo[preview_winnr].spell = false
  vim.wo[preview_winnr].winblend = winblend
  vim.wo[preview_winnr].winfixbuf = true
  vim.wo[preview_winnr].winhighlight = __highlights__.preview
  vim.wo[preview_winnr].wrap = false

  self._preview_debounced()
end

---@protected
---@return integer
function M:__create_input_buf__()
  local bufnr = self._input_bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end

  bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._input_bufnr = bufnr

  vim.b[bufnr].miniindentscope_disable = true
  vim.b[bufnr].miniai_disable = true
  vim.b[bufnr].minihipatterns_disable = true
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = stl.filetype.BOARD
  vim.bo[bufnr].swapfile = false

  local initial_input = self._input:snapshot() ---@type string
  local initial_lines = { initial_input } ---@type string[]
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, initial_lines)
  self:__set_prompt__(bufnr)

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = bufnr,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]

      if #lines > 1 then
        local content = table.concat(lines, " ") ---@type string
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { content })
        self._input:next(content)
        self:__set_prompt__(bufnr)
        return
      end

      local content = lines[1] or "" ---@type string
      self._input:next(content)
      self:__set_prompt__(bufnr)
    end,
  })

  self:__setup_keymaps__(bufnr)
  return bufnr
end

---@protected
---@return integer
function M:__create_preview_buf__()
  local bufnr = self._preview_bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end

  bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._preview_bufnr = bufnr

  vim.b[bufnr].miniindentscope_disable = true
  vim.b[bufnr].miniai_disable = true
  vim.b[bufnr].minihipatterns_disable = true
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = stl.filetype.BOARD
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

  return bufnr
end

---@protected
---@return nil
function M:__focus_input__()
  local winnr = self._input_winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_current_win(winnr)
  end
end

---@protected
---@return dot.t.IWinDimension
---@return dot.t.IWinDimension
function M:__layout__()
  local max_preview_lines = 10 ---@type integer
  local max_width = math.min(MAX_WIDTH, vim.o.columns - 4) ---@type integer
  local min_width = math.min(math.floor(vim.o.columns * 0.4), 60) ---@type integer

  local width ---@type integer
  if self._get_width ~= nil then
    local content_width = self._get_width() ---@type integer
    width = math.min(max_width, math.max(min_width, content_width))
  else
    local recommended_width = self._recommended_width <= 1 and math.floor(vim.o.columns * self._recommended_width)
      or math.floor(self._recommended_width) ---@type integer
    width = math.min(max_width, math.max(min_width, recommended_width))
  end

  local input_height = 1 ---@type integer
  local preview_height = math.min(self._preview_lines, max_preview_lines) ---@type integer

  local total_height = input_height + 2 + preview_height + 2 ---@type integer
  local max_total_height = vim.o.lines - 4 ---@type integer
  if total_height > max_total_height then
    preview_height = max_total_height - input_height - 4
    total_height = max_total_height
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(0) ---@type integer[]
  local cursor_row = cursor_pos[1] ---@type integer
  local cursor_col = cursor_pos[2] ---@type integer
  local screen_pos = vim.fn.screenpos(0, cursor_row, cursor_col + 1) ---@type table
  local win_row = screen_pos.row ---@type integer
  local win_col = screen_pos.col ---@type integer

  local row = win_row + 1 ---@type integer
  if row + total_height > vim.o.lines - 2 then
    row = win_row - total_height - 1
  end
  row = math.max(1, math.min(row, vim.o.lines - total_height - 2))

  local col = win_col + 2 ---@type integer
  if col + width + 2 > vim.o.columns then
    col = win_col - width - 4
  end
  col = math.max(0, math.min(col, vim.o.columns - width - 2))

  ---@type dot.t.IWinDimension
  local input_dimension = {
    row = row,
    col = col,
    height = input_height,
    width = width,
  }

  ---@type dot.t.IWinDimension
  local preview_dimension = {
    row = row + input_height + 1,
    col = col,
    height = preview_height,
    width = width,
  }

  return input_dimension, preview_dimension
end

---@protected
---@param bufnr                         integer
---@return nil
function M:__set_prompt__(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    local group = ark.var.sign.GROUP_PICKER_FINDER_PROMPT ---@type string
    local sign = ark.var.sign.PICKER_FINDER_PROMPT ---@type string
    pcall(vim.fn.sign_place, 1, group, sign, bufnr, { lnum = 1, priority = 10 })
  end
end

---@protected
---@param bufnr                         integer
---@return nil
function M:__setup_keymaps__(bufnr)
  ---@type stl.t.IKeymap[]
  local builtin_keymaps = {
    {
      modes = { "i", "n" },
      key = "<CR>",
      callback = function()
        self:confirm()
      end,
      desc = "act: confirm",
    },
    {
      modes = { "n" },
      key = "q",
      callback = function()
        self:cancel()
      end,
      desc = "act: cancel",
    },
  }

  local keymaps = vim.list_extend(builtin_keymaps, self._keymaps) ---@type stl.t.IKeymap[]
  ark.vim.fn.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
end

return M
