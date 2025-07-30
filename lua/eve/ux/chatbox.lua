---@diagnostic disable: invisible
local __module_name__ = "eve.ux.chatbox" ---@type string

---@type string
local WIN_HIGHLIGHT = table.concat({
  "Cursor:f_ut_current",
  "CursorColumn:f_ut_current",
  "CursorLine:f_ut_current",
  "CursorLineNr:f_ut_current",
  "FloatBorder:FloatActiveBorder",
  "Normal:f_ut_normal",
}, ",")

---@class eve.ux.IChatbox
---@field public close                  fun(self: eve.ux.IChatbox): nil
---@field public get_bufnr              fun(): integer|nil
---@field public get_winnr              fun(): integer|nil
---@field public mark_settled           fun(self: eve.ux.IChatbox): nil
---@field public on_close               fun(): nil
---@field public on_confirm             fun(): nil
---@field public open                   fun(self: eve.ux.IChatbox, params: eve.ux.chatbox.IOpenParams): nil
---@field public set_footer             fun(self: eve.ux.IChatbox, text: string): nil
---@field public start_spinner          fun(self: eve.ux.IChatbox, text: string|nil): nil
---@field public stop_spinner           fun(self: eve.ux.IChatbox): nil

---@class eve.ux.chatbox.IOpenParams
---@field public initial_lines          string[]
---@field public row                    number
---@field public col                    number
---@field public width                  ?number
---@field public height                 ?number
---@field public text_cursor_row        ?integer
---@field public text_cursor_col        ?integer

---@class eve.ux.Chatbox : eve.ux.IChatbox
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected width               number
---@field protected height              number
---@field protected title               string
---@field protected filetype            string|nil
---@field protected keymaps             std.t.IKeymap[]
---@field protected win_opts            table<string, any>
---@field protected _spinner_timer      uv.uv_timer_t|nil
---@field protected _footer_text        string
---@field protected _settled            boolean
local M = {}
M.__index = M

---@class eve.ux.chatbox.IProps
---@field public width                  ?number
---@field public height                 ?number
---@field public title                  ?string
---@field public filetype               ?string
---@field public keymaps                ?std.t.IKeymap[]
---@field public win_opts               ?table<string, any>
---@field public validate               ?fun(lines: string[]): string|nil
---@field public on_close               ?fun(): nil
---@field public on_confirm             fun(lines: string[]): boolean

---@param props                         eve.ux.chatbox.IProps
---@return eve.ux.Chatbox
function M.new(props)
  local self = setmetatable({}, M)

  local width = props.width or 0.5 ---@type number
  local height = props.height or 0.5 ---@type number
  local filetype = props.filetype ---@type string|nil
  local winblend = eve.context.theme.get_float_winblend() ---@type integer

  ---@type table<string, any>
  local win_opts = vim.tbl_extend("force", {
    cursorline = true,
    number = false,
    relativenumber = false,
    signcolumn = "no",
    wrap = false,
    winblend = winblend,
    winhighlight = WIN_HIGHLIGHT,
  }, props.win_opts or {})

  local title = props.title ---@type string|nil
  title = (type(title) == "string" and #title > 0) and (" " .. title .. " ") or "" ---@type string

  local validate = props.validate ---@type (fun(lines: string[]): string|nil)|nil
  local on_close_from_props = props.on_close ---@type (fun(): nil)
  local on_confirm_from_props = props.on_confirm ---@type fun(lines: string[]): boolean

  ---@return nil
  local function on_close()
    self:close()
    if type(on_close_from_props) == "function" then
      on_close_from_props()
    end
  end

  ---@return nil
  local function on_confirm()
    local bufnr = self:get_bufnr() ---@type integer|nil
    if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
      std.reporter.warn({
        from = __module_name__,
        subject = "confirm",
        message = "The buffer is not valid.",
        details = { bufnr = bufnr, self = self },
      })
      return
    end

    -- If chatbox is settled, dispose it instead of resubmitting
    if self._settled then
      self:close()
      return
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
    local err_msg = type(validate) == "function" and validate(lines) or nil ---@type string|nil
    if err_msg ~= nil then
      std.reporter.warn({
        from = __module_name__,
        subject = "confirm",
        message = "Validation failed.",
        details = { lines = lines, err_msg = err_msg },
      })
      return
    end

    if on_confirm_from_props(lines) then
      self:close()
    end
  end

  ---@type std.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i", "n", "v" },
      key = "<C-a>q",
      aliases = { "<D-q>", "<M-q>" },
      desc = "chatbox: quit",
      callback = on_close,
    },
    { modes = { "n" }, key = "q", desc = "chatbox: quit", callback = on_close },
    { modes = { "n" }, key = "<cr>", desc = "chatbox: confirm", callback = on_confirm },
  }
  vim.list_extend(keymaps, props.keymaps or {})

  self._bufnr = nil
  self._winnr = nil
  self.on_close = on_close
  self.on_confirm = on_confirm

  self.width = width
  self.height = height
  self.filetype = filetype
  self.keymaps = keymaps
  self.title = title
  self.win_opts = win_opts
  self._spinner_timer = nil
  self._footer_text = ""
  self._settled = false

  return self
end

---@return nil
function M:close()
  self:stop_spinner()

  if self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr) then
    vim.api.nvim_win_close(self._winnr, true)
  end

  if self._bufnr ~= nil and vim.api.nvim_buf_is_valid(self._bufnr) then
    vim.api.nvim_buf_delete(self._bufnr, { force = true })
  end

  self._bufnr = nil
  self._winnr = nil
end

---@return integer|nil
function M:get_bufnr()
  return self._bufnr
end

---@return integer|nil
function M:get_winnr()
  return self._winnr
end

---@return nil
function M:mark_settled()
  self._settled = true
end

---@param params                        eve.ux.chatbox.IOpenParams
---@return nil
function M:open(params)
  if self._bufnr == nil or not vim.api.nvim_buf_is_valid(self._bufnr) then
    local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    self._bufnr = bufnr

    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].filetype = self.filetype
    vim.bo[bufnr].swapfile = false
    vim.b[bufnr][eve.var.Names.BUF_DISABLE_LINT] = true
    eve.nvim.bindkeys(self.keymaps, { bufnr = bufnr, noremap = true, silent = true })

    vim.schedule(function()
      vim.cmd("stopinsert")
    end)
  end

  local lines = params.initial_lines ---@type string[]
  local text_cursor_row = params.text_cursor_row or #lines ---@type integer
  local text_cursor_col = params.text_cursor_col or string.len(lines[#lines]) ---@type integer
  vim.api.nvim_buf_set_lines(self._bufnr, 0, -1, false, lines)

  if self._winnr == nil or not vim.api.nvim_win_is_valid(self._winnr) then
    ---@type integer
    local winnr = vim.api.nvim_open_win(self._bufnr, true, {
      relative = "editor",
      anchor = "NW",
      row = params.row,
      col = params.col,
      width = params.width or self.width,
      height = params.height or self.height,
      focusable = true,
      title = self.title,
      title_pos = "center",
      border = "rounded",
      style = "minimal",
    })
    self._winnr = winnr

    eve.win.set_type(winnr, eve.win.Types.CHATBOX)
    vim.api.nvim_win_set_cursor(winnr, { text_cursor_row, text_cursor_col })
  end

  for key, value in pairs(self.win_opts) do
    vim.wo[self._winnr][key] = value
  end
end

---@param text                          string
---@return nil
function M:set_footer(text)
  self._footer_text = text
  if self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr) then
    if text ~= "" then
      vim.api.nvim_win_set_config(self._winnr, { footer = text, footer_pos = "right" })
    else
      vim.api.nvim_win_set_config(self._winnr, { footer = nil })
    end
  end
end

---@param text                          ?string
---@return nil
function M:start_spinner(text)
  self:stop_spinner()

  local spinner_text = text or ""
  self._spinner_timer = vim.uv.new_timer()

  if self._spinner_timer then
    self._spinner_timer:start(0, 80, function()
      vim.schedule(function()
        if self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr) then
          local footer = std.fn.spinner()
          if spinner_text ~= "" then
            footer = footer .. " " .. spinner_text
          end
          vim.api.nvim_win_set_config(self._winnr, { footer = footer, footer_pos = "right" })
        end
      end)
    end)
  end
end

---@return nil
function M:stop_spinner()
  if self._spinner_timer then
    self._spinner_timer:stop()
    self._spinner_timer:close()
    self._spinner_timer = nil
  end

  self:set_footer(self._footer_text)
end

return M
