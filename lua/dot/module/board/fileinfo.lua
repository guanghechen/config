local __module_name__ = "dot.module.board.fileinfo" ---@type string

---@class dot.module.board.fileinfo.IProps
---@field public filepath               string

---@class dot.module.board.fileinfo.IState
---@field protected _disposed           boolean
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _ns                 integer
---@field protected _filepath           string

---@class dot.module.board.Fileinfo : dot.module.board.fileinfo.IState
local M = {}
M.__index = M

local PADDING_LEFT = 2 ---@type integer
local PADDING_RIGHT = 2 ---@type integer

---@param props                         dot.module.board.fileinfo.IProps
---@return dot.module.board.Fileinfo
function M.new(props)
  local self = setmetatable({}, M)
  self._disposed = false
  self._bufnr = nil
  self._winnr = nil
  self._ns = vim.api.nvim_create_namespace("board_fileinfo")
  self._filepath = props.filepath
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true
  self:close()
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isvisible()
  return self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr)
end

---@return nil
function M:close()
  local winnr = self._winnr ---@type integer|nil
  local bufnr = self._bufnr ---@type integer|nil

  self._winnr = nil
  self._bufnr = nil

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    pcall(vim.api.nvim_win_close, winnr, true)
  end

  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

---@return nil
function M:open()
  if self._disposed then
    return
  end

  if self:isvisible() then
    return
  end

  self:close()

  local filepath = self._filepath ---@type string
  local stat = vim.uv.fs_stat(filepath) ---@type uv.fs_stat.result|nil
  if stat == nil then
    ark.reporter.warn({
      from = __module_name__,
      subject = "File Info",
      message = "Cannot get file information",
    })
    return
  end

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr = bufnr

  vim.b[bufnr].miniindentscope_disable = true
  vim.b[bufnr].miniai_disable = true
  vim.b[bufnr].minihipatterns_disable = true
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = "board"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true

  local lines, highlights, width = self:__render__(stat) ---@type string[], ark.t.IHighlight[], integer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

  for _, hl in ipairs(highlights) do
    vim.hl.range(bufnr, self._ns, hl.hlname, { hl.lnum, hl.coll }, { hl.lnum, hl.colr })
  end

  local height = #lines ---@type integer
  local row, col = self:__calc_position__(width, height) ---@type integer, integer

  local winblend = dot.context.theme.get_float_winblend() ---@type integer
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "cursor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
    focusable = true,
    title = string.format(" %s File Info ", ark.icon.diagnostic.Information),
    title_pos = "center",
  })
  self._winnr = winnr

  vim.wo[winnr].cursorline = false
  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "no"
  vim.wo[winnr].spell = false
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].winfixbuf = true
  vim.wo[winnr].wrap = false
  vim.wo[winnr].winhighlight = table.concat({
    "FloatBorder:ms_b_bg0",
    "FloatTitle:ms_b_bg0",
    "Normal:m_bf_normal",
  }, ",")

  self:__setup_keymaps__(bufnr)
end

---@return nil
function M:toggle()
  if self:isvisible() then
    self:close()
  else
    self:open()
  end
end

----------------------------------------------------------------------------------------------------

---@protected
---@param width                         integer
---@param height                        integer
---@return integer
---@return integer
function M:__calc_position__(width, height)
  local cursor_pos = vim.fn.screenpos(0, vim.fn.line("."), vim.fn.col("."))
  local cursor_row = cursor_pos.row ---@type integer
  local cursor_col = cursor_pos.col ---@type integer
  local screen_width = vim.o.columns ---@type integer
  local screen_height = vim.o.lines ---@type integer

  local row = 1 ---@type integer
  local col = 2 ---@type integer

  if cursor_row + row + height + 4 > screen_height then
    row = -height - 2
  end

  if cursor_col + col + width + 4 > screen_width then
    col = screen_width - cursor_col - width - 4
  end

  return row, col
end

---@protected
---@param mode                          integer
---@return string
function M:__format_permissions__(mode)
  local perms = ""
  local flags = mode % 512
  for i = 8, 0, -1 do
    local has = math.floor(flags / (2 ^ i)) % 2 == 1
    if has then
      local idx = 8 - i
      if idx % 3 == 0 then
        perms = perms .. "r"
      elseif idx % 3 == 1 then
        perms = perms .. "w"
      else
        perms = perms .. "x"
      end
    else
      perms = perms .. "-"
    end
  end
  return perms
end

---@protected
---@param stat                          uv.fs_stat.result
---@return string[]
---@return ark.t.IHighlight[]
---@return integer
function M:__render__(stat)
  local strwidth = vim.api.nvim_strwidth ---@type fun(str: string): integer
  local filepath = self._filepath ---@type string

  ---@class dot.module.board.fileinfo.IInfoLine
  ---@field public label                  string
  ---@field public value                  string

  local infos = {} ---@type dot.module.board.fileinfo.IInfoLine[]
  local workspace = dot.path.workspace() ---@type string
  local relative_path = filepath ---@type string
  if filepath:sub(1, #workspace) == workspace then
    relative_path = filepath:sub(#workspace + 2)
  end

  infos[#infos + 1] = { label = "Path", value = relative_path }
  infos[#infos + 1] = { label = "Type", value = stat.type }
  infos[#infos + 1] = { label = "Size", value = yoz.fs.get_filesize(filepath) or "unknown" }
  infos[#infos + 1] = { label = "Modified", value = os.date("%Y-%m-%d %H:%M:%S", stat.mtime.sec) --[[@as string]] }
  infos[#infos + 1] = { label = "Accessed", value = os.date("%Y-%m-%d %H:%M:%S", stat.atime.sec) --[[@as string]] }
  if stat.birthtime and stat.birthtime.sec > 0 then
    infos[#infos + 1] = { label = "Created", value = os.date("%Y-%m-%d %H:%M:%S", stat.birthtime.sec) --[[@as string]] }
  end
  infos[#infos + 1] = { label = "Mode", value = string.format("%s (%o)", self:__format_permissions__(stat.mode), stat.mode % 512) }

  local label_width = 0 ---@type integer
  for _, info in ipairs(infos) do
    label_width = math.max(label_width, #info.label)
  end

  local lines = {} ---@type string[]
  local highlights = {} ---@type ark.t.IHighlight[]

  lines[#lines + 1] = ""

  for _, info in ipairs(infos) do
    local label_padding = string.rep(" ", label_width - #info.label) ---@type string
    local line = string.format("%s%s%s : %s", string.rep(" ", PADDING_LEFT), label_padding, info.label, info.value)
    local lnum = #lines ---@type integer

    local label_start = PADDING_LEFT + label_width - #info.label ---@type integer
    local value_start = PADDING_LEFT + label_width + 3 ---@type integer

    highlights[#highlights + 1] = {
      lnum = lnum,
      coll = label_start,
      colr = label_start + #info.label,
      hlname = "m_bf_label",
    }

    highlights[#highlights + 1] = {
      lnum = lnum,
      coll = value_start,
      colr = value_start + #info.value,
      hlname = "m_bf_value",
    }

    lines[#lines + 1] = line
  end

  lines[#lines + 1] = ""

  local width = 0 ---@type integer
  for _, line in ipairs(lines) do
    width = math.max(width, strwidth(line))
  end
  width = width + PADDING_RIGHT

  return lines, highlights, width
end

---@protected
---@param bufnr                         integer
---@return nil
function M:__setup_keymaps__(bufnr)
  ---@type ark.t.IKeymap[]
  local keymaps = {
    { modes = { "n" }, key = "q", callback = function() self:close() end, desc = "fileinfo: close" },
    { modes = { "n" }, key = "<Esc>", callback = function() self:close() end, desc = "fileinfo: close" },
  }
  ark.vim.fn.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
end

return M
