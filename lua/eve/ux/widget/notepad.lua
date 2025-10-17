local __module_name__ = "eve.ux.widget.notepad" ---@type string

local DEFAULT_WIDTH = 0.6
local DEFAULT_HEIGHT = 0.6
local MAX_WIDTH = 0.9
local MAX_HEIGHT = 0.9
local MIN_WIDTH = 60
local MIN_HEIGHT = 12
local WIN_TITLE = " Notepad "

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
---@field private _last_filepath        string|nil
local Notepad = {}
Notepad.__index = Notepad

---@param props                         eve.ux.widget.notepad.IProps|nil
---@return eve.ux.widget.Notepad
function Notepad.new(props)
  props = props or {}

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
  self.filetype = props.filetype or "text"
  self.win_opts = vim.tbl_extend("force", {}, props.win_opts or {})
  self._bufnr = nil
  self._winnr = nil
  self._last_filepath = nil
  return self
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

  ---@type std.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i", "n", "v" },
      key = "<C-s>",
      desc = "notepad: save without lint",
      callback = function()
        self:choose_filename(false)
      end,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>s",
      aliases = { "<D-s>", "<M-s>" },
      desc = "notepad: save with lint",
      callback = function()
        self:choose_filename(true)
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
  }
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

  return winnr
end

---@param bufnr                          integer
---@param filepath                       string
---@param with_lint                      boolean
---@return nil
function Notepad:save_to_filepath(bufnr, filepath, with_lint)
  vim.fn.mkdir(std.path.dirname(filepath), "p")

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local ok, reason = pcall(vim.fn.writefile, lines, filepath) ---@type boolean, string
  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = "save",
      message = "Failed to write notepad content to disk.",
      details = { filepath = filepath, reason = reason },
    })
    return
  end

  self._last_filepath = filepath
  vim.api.nvim_buf_set_name(bufnr, filepath)
  vim.bo[bufnr].modified = false

  if with_lint then
    local target_bufnr = bufnr ---@type integer
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(target_bufnr) then
        return
      end

      local ok_lint, lint = pcall(require, "lint")
      if not ok_lint or lint == nil then
        std.reporter.warn({
          from = __module_name__,
          subject = "save",
          message = "Lint plugin is not available.",
          details = { filepath = filepath },
        })
        return
      end

      vim.api.nvim_buf_call(target_bufnr, function()
        lint.try_lint()
      end)
    end)
  end

  local cwd = std.path.cwd() ---@type string
  local relative = std.path.relative(cwd, filepath, true) ---@type string
  std.reporter.info({
    from = __module_name__,
    subject = "save",
    message = string.format("Saved notepad to %s", relative),
  })
end

---@param with_lint                      boolean
---@return nil
function Notepad:choose_filename(with_lint)
  local bufnr = self:get_bufnr() ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = self:ensure_buf()
  end

  local cwd = std.path.cwd() ---@type string
  local workspace = std.path.workspace() ---@type string
  local default_filepath = self._last_filepath ---@type string|nil
  if default_filepath == nil or #default_filepath == 0 then
    local bufname = vim.api.nvim_buf_get_name(bufnr) ---@type string
    if bufname ~= nil and #bufname > 0 and std.path.is_absolute(bufname) then
      default_filepath = bufname
    else
      default_filepath = ""
    end
  end

  if #default_filepath > 0 and #workspace > 0 and std.path.is_under(workspace, default_filepath) then
    default_filepath = std.path.relative(cwd, default_filepath, true)
  end

  vim.ui.input({
    relative = "editor",
    prompt = "Save notepad as",
    default = default_filepath,
  }, function(text)
    if text == nil then
      return
    end

    text = vim.trim(text)
    if #text == 0 then
      return
    end

    local filepath = std.path.resolve(cwd, text) ---@type string
    if std.path.is_exist_dirpath(filepath) then
      std.reporter.error({
        from = __module_name__,
        subject = "save",
        message = "Cannot save notepad to a directory path.",
        details = { text = text, filepath = filepath },
      })
      return
    end

    local function finalize()
      self:save_to_filepath(bufnr, filepath, with_lint)
    end

    if std.path.is_exist_filepath(filepath) then
      vim.ui.select({ "Yes", "No" }, {
        name = __module_name__,
        prompt = "The file already exists, overwrite it?",
      }, function(choice)
        if choice == "Yes" then
          finalize()
        end
      end)
      return
    end

    finalize()
  end)
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
function Notepad:dispose() end

return Notepad
