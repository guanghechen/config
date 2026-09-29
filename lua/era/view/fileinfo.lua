---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.fileinfo" ---@type string

---@class era.view.fileinfo.IProps
---@field public filepath               string
---@field public kind                   string
---@field public details                ux.filetree.IResourceDetails

---@class era.view.fileinfo.IState
---@field protected _disposed           boolean
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _ns                 integer
---@field protected _filepath           string
---@field protected _kind               string
---@field protected _details            ux.filetree.IResourceDetails

---@class era.view.Fileinfo : era.view.fileinfo.IState
local M = {}
M.__index = M

local PADDING_LEFT = 2 ---@type integer
local PADDING_RIGHT = 2 ---@type integer

---@param props                         era.view.fileinfo.IProps
---@return era.view.Fileinfo
function M.new(props)
  local self = setmetatable({}, M)
  self._disposed = false
  self._bufnr = nil
  self._winnr = nil
  self._ns = vim.api.nvim_create_namespace("board_fileinfo")
  self._filepath = props.filepath
  self._kind = props.kind
  self._details = props.details
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

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr = bufnr

  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "board", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

  local lines, highlights, width = self:__render__() ---@type string[], stl.t.IHighlight[], integer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })

  for _, hl in ipairs(highlights) do
    vim.hl.range(bufnr, self._ns, hl.hlname, { hl.lnum, hl.coll }, { hl.lnum, hl.colr })
  end

  local height = math.min(#lines, math.max(1, vim.o.lines - 4)) ---@type integer
  local row, col = self:__calc_position__(width, height) ---@type integer, integer

  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "cursor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
    focusable = true,
    title = string.format(" %s File Info ", stl.icon.diagnostic.Information),
    title_pos = "center",
  })
  self._winnr = winnr

  vim.api.nvim_set_option_value("cursorline", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("number", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("relativenumber", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("spell", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winblend", 0, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("wrap", true, { win = winnr, scope = "local" })
  vim.api.nvim_win_set_height(
    winnr,
    math.min(vim.api.nvim_win_text_height(winnr, {}).all, math.max(1, vim.o.lines - 4))
  )
  vim.api.nvim_set_option_value(
    "winhighlight",
    table.concat({
      "FloatBorder:ms_b_bg0",
      "FloatTitle:ms_b_bg0",
      "Normal:m_bf_normal",
    }, ","),
    { win = winnr, scope = "local" }
  )

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
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local cursor_pos = vim.fn.screenpos(winnr, vim.fn.line("."), vim.fn.col("."))
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
---@return string[]
---@return stl.t.IHighlight[]
---@return integer
function M:__render__()
  local strwidth = vim.api.nvim_strwidth ---@type fun(str: string): integer
  local filepath = self._filepath ---@type string
  local details = self._details

  ---@class era.view.fileinfo.IInfoLine
  ---@field public label                  string
  ---@field public value                  string

  local infos = {} ---@type era.view.fileinfo.IInfoLine[]
  local workspace = dot.path.workspace() ---@type string
  local relative_path = filepath ---@type string
  local prefix = workspace:sub(-1) == "/" and workspace or workspace .. "/"
  if filepath:sub(1, #prefix) == prefix then
    relative_path = filepath:sub(#prefix + 1)
  end

  local units = { "B", "KiB", "MiB", "GiB", "TiB", "PiB" }
  local size, unit = details.size, 1
  while size >= 1024 and unit < #units do
    size, unit = size / 1024, unit + 1
  end
  local size_label = unit == 1 and string.format("%d B", size)
    or string.format("%.1f %s (%d bytes)", size, units[unit], details.size)
  infos[#infos + 1] = { label = "Path", value = vim.fn.strtrans(relative_path) }
  infos[#infos + 1] = { label = "Type", value = self._kind }
  infos[#infos + 1] = { label = "Size", value = size_label }
  infos[#infos + 1] = {
    label = "Modified",
    value = details.modified or "unavailable",
  }
  infos[#infos + 1] = {
    label = "Accessed",
    value = details.accessed or "unavailable",
  }
  if details.created then
    infos[#infos + 1] = {
      label = "Created",
      value = details.created,
    }
  end
  infos[#infos + 1] = { label = "Mode", value = details.permissions .. " (" .. details.mode .. ")" }

  local label_width = 0 ---@type integer
  for _, info in ipairs(infos) do
    label_width = math.max(label_width, #info.label)
  end

  local lines = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlight[]

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
  width = math.min(width + PADDING_RIGHT, math.max(1, vim.o.columns - 4))

  return lines, highlights, width
end

---@protected
---@param bufnr                         integer
---@return nil
function M:__setup_keymaps__(bufnr)
  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "q",
      callback = function()
        self:close()
      end,
      desc = "fileinfo: close",
    },
    {
      modes = { "n" },
      key = "<Esc>",
      callback = function()
        self:close()
      end,
      desc = "fileinfo: close",
    },
  }
  stl.nvim.fn.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
end

return M
