---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.minimap.view" ---@type string

local util = require("era.m.minimap.util")

local M = {}

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local WINBLEND = 50
local ZINDEX = 40

local EXCLUDED_FILETYPES = {
  "dashboard",
  "explorer",
  "help",
  "mason",
  "notify",
  "qf",
  "term",
}

----------------------------------------------------------------------------------------------------
-- State
----------------------------------------------------------------------------------------------------

local nsnr = vim.api.nvim_create_namespace("era.m.minimap")

---@type boolean
local global_enabled = false

---@type table<integer, integer>
local bar_winnrs = {}

---@type table<integer, { row: integer, height: integer }>
local render_cache = {}

---@type table<integer, true>
local attached_winnrs = {}

----------------------------------------------------------------------------------------------------
-- Handlers
----------------------------------------------------------------------------------------------------

---@class era.m.minimap.view.IHandlerSpec
---@field public name                 string
---@field public config               era.m.minimap.IHandlerConfig

---@type era.m.minimap.view.IHandlerSpec[]
local HANDLER_SPECS = {
  { name = "cursor", config = { enable = true, overlap = true, priority = 100 } },
  { name = "diagnostic", config = { enable = true, overlap = true, priority = 50 } },
  { name = "git", config = { enable = true, overlap = false, priority = 20 } },
  { name = "marks", config = { enable = true, overlap = true, priority = 60 } },
  { name = "quickfix", config = { enable = true, overlap = true, priority = 60 } },
  { name = "search", config = { enable = true, overlap = true, priority = 10 } },
}

local handlers = {} ---@type era.m.minimap.IHandler[]
for _, spec in ipairs(HANDLER_SPECS) do
  if spec.config.enable then
    local handler = require("era.m.minimap.handler." .. spec.name)
    handler.ns = vim.api.nvim_create_namespace("era.m.minimap.handler." .. spec.name)
    handler.config = spec.config
    handlers[#handlers + 1] = handler
  end
end

---@param winnr                       integer
local function attach_handlers(winnr)
  if attached_winnrs[winnr] then
    return
  end
  attached_winnrs[winnr] = true

  for _, handler in ipairs(handlers) do
    handler.attach(winnr)
  end
end

---@param winnr                       integer
local function detach_handlers(winnr)
  if not attached_winnrs[winnr] then
    return
  end
  attached_winnrs[winnr] = nil

  for _, handler in ipairs(handlers) do
    handler.detach(winnr)
  end
end

----------------------------------------------------------------------------------------------------
-- Bar window
----------------------------------------------------------------------------------------------------

---@param winnr                       integer
---@param opt                         string
---@param value                       string|boolean|integer
local function set_winopt(winnr, opt, value)
  vim.api.nvim_set_option_value(opt, value, { win = winnr, scope = "local" })
end

---@param cfg                         vim.api.keyset.win_config
---@return integer
local create_bar = util.noautocmd(function(cfg)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].undolevels = -1

  cfg.noautocmd = true
  local winnr = vim.api.nvim_open_win(bufnr, false, cfg)

  set_winopt(winnr, "winhighlight", "Normal:Normal")
  set_winopt(winnr, "winblend", WINBLEND)
  set_winopt(winnr, "foldcolumn", "0")
  set_winopt(winnr, "wrap", false)

  return winnr
end)

---@param winnr                       integer
---@return integer bar_winnr
---@return boolean is_new
local function get_or_create_bar(winnr)
  local cfg = {
    win = winnr,
    relative = "win",
    style = "minimal",
    border = "none",
    focusable = false,
    zindex = ZINDEX,
    width = 1,
    row = 0,
    height = util.get_winheight(winnr),
    col = vim.api.nvim_win_get_width(winnr) - 1,
  } ---@type vim.api.keyset.win_config

  local bar_winnr = bar_winnrs[winnr]
  if bar_winnr then
    local info = vim.fn.getwininfo(bar_winnr)[1]
    if info then
      cfg.col = cfg.col - info.textoff
      cfg.width = cfg.width + info.textoff
    end
  end

  local is_new = false
  if bar_winnr and vim.api.nvim_win_is_valid(bar_winnr) then
    vim.api.nvim_win_set_config(bar_winnr, cfg)
  else
    bar_winnr = create_bar(cfg)
    bar_winnrs[winnr] = bar_winnr
    is_new = true
  end

  local topline, botline = util.visible_line_range(winnr)
  local toprow = util.row_to_barpos(winnr, topline - 1)
  local height = util.height_to_virtual(winnr, topline - 1, botline - 1)

  vim.w[bar_winnr].col = cfg.col
  vim.w[bar_winnr].width = cfg.width
  vim.w[bar_winnr].height = height
  vim.w[bar_winnr].row = toprow

  return bar_winnr, is_new
end

---@param winnr                       integer
local function close_bar(winnr)
  util.invalidate_virtual_line_count_cache(winnr)

  local bar_winnr = bar_winnrs[winnr]
  if not bar_winnr then
    return
  end

  render_cache[bar_winnr] = nil
  bar_winnrs[winnr] = nil
  detach_handlers(winnr)

  if not vim.api.nvim_win_is_valid(bar_winnr) then
    return
  end
  if util.in_cmdline_win(winnr) then
    return
  end

  util.noautocmd(vim.api.nvim_win_close)(bar_winnr, true)
end

----------------------------------------------------------------------------------------------------
-- Rendering
----------------------------------------------------------------------------------------------------

---@param winnr                       integer
---@param bar_winnr                   integer
---@param force                       boolean|nil
local function render_scrollbar(winnr, bar_winnr, force)
  local bufnr = vim.api.nvim_win_get_buf(bar_winnr)
  local winheight = util.get_winheight(winnr)

  if vim.api.nvim_buf_line_count(bufnr) ~= winheight then
    local lines = {} ---@type string[]
    for i = 1, winheight do
      lines[i] = " "
    end
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    vim.bo[bufnr].modifiable = false
    force = true
  end

  local row = vim.w[bar_winnr].row ---@type integer
  local height = vim.w[bar_winnr].height ---@type integer

  local cached = render_cache[bar_winnr]
  if not force and cached and cached.row == row and cached.height == height then
    return
  end
  render_cache[bar_winnr] = { row = row, height = height }

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)

  for i = 0, winheight - 1 do
    local hl = (i >= row and i < row + height) and "m_mm_bar" or "m_mm_bg"
    pcall(vim.api.nvim_buf_set_extmark, bufnr, nsnr, i, 0, {
      virt_text = { { " ", hl } },
      virt_text_pos = "overlay",
      priority = 1,
    })
  end
end

---@param winnr                       integer
---@param bar_winnr                   integer
local function render(winnr, bar_winnr)
  util.invalidate_virtual_line_count_cache(winnr)
  render_scrollbar(winnr, bar_winnr)
end

----------------------------------------------------------------------------------------------------
-- Predicates
----------------------------------------------------------------------------------------------------

---@param winnr                       integer
---@return boolean
local function is_terminal(winnr)
  return assert(vim.fn.getwininfo(winnr)[1]).terminal ~= 0
end

---@param winnr                       integer
---@return boolean
local function can_attach(winnr)
  local bufnr = vim.api.nvim_win_get_buf(winnr)

  if vim.tbl_contains(EXCLUDED_FILETYPES, vim.bo[bufnr].filetype) then
    return false
  end
  if vim.wo[winnr].winfixbuf then
    return false
  end
  if is_terminal(winnr) then
    return false
  end
  if util.in_cmdline_win(winnr) then
    return false
  end
  if util.get_winheight(winnr) == 0 or vim.api.nvim_win_get_width(winnr) == 0 then
    return false
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line_count == 0 then
    return false
  end

  local topline, botline = util.visible_line_range(winnr)
  if botline - topline + 1 == line_count then
    return false
  end

  return true
end

---@return integer[]
local function get_target_windows()
  local ret = {} ---@type integer[]
  local tabnr = vim.api.nvim_get_current_tabpage()

  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    if util.is_ordinary_window(winnr) and vim.api.nvim_win_get_tabpage(winnr) == tabnr then
      ret[#ret + 1] = winnr
    end
  end

  return ret
end

----------------------------------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------------------------------

---@return boolean
function M.enabled()
  return global_enabled
end

---@param winnr                       integer
---@return boolean
function M.is_attached(winnr)
  local bar_winnr = bar_winnrs[winnr]
  return bar_winnr ~= nil and vim.api.nvim_win_is_valid(bar_winnr)
end

---@param winnr                       integer
---@return era.m.minimap.IViewProps|nil
function M.get_props(winnr)
  local bar_winnr = bar_winnrs[winnr]
  if not bar_winnr then
    return nil
  end

  return {
    col = vim.w[bar_winnr].col,
    height = vim.w[bar_winnr].height,
    row = vim.w[bar_winnr].row,
    width = vim.w[bar_winnr].width,
  }
end

---@param winnr                       integer
---@return integer|nil
function M.get_bar_winnr(winnr)
  local bar_winnr = bar_winnrs[winnr]
  if bar_winnr and vim.api.nvim_win_is_valid(bar_winnr) then
    return bar_winnr
  end
  return nil
end

---@param winnr                       integer
---@param handler_ns                  integer
---@param config                      era.m.minimap.IHandlerConfig
---@param marks                       era.m.minimap.IMark[]
function M.render_handler(winnr, handler_ns, config, marks)
  local bar_winnr = bar_winnrs[winnr]
  if not bar_winnr or not vim.api.nvim_win_is_valid(bar_winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(bar_winnr)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local max_pos = vim.api.nvim_buf_line_count(bufnr) - 1
  local uses_signs = config.overlap == false

  local old_textoff = 0
  if uses_signs then
    local info = vim.fn.getwininfo(bar_winnr)[1]
    if info then
      old_textoff = info.textoff
    end
  end

  vim.api.nvim_buf_clear_namespace(bufnr, handler_ns, 0, -1)

  for _, m in ipairs(marks) do
    if m.pos <= max_pos then
      local opts = {
        id = not m.unique and m.pos + 1 or nil,
        priority = config.priority,
      } ---@type vim.api.keyset.set_extmark

      if not uses_signs then
        opts.virt_text = { { m.symbol, m.highlight } }
        opts.virt_text_pos = "overlay"
        opts.hl_mode = "combine"
      else
        opts.sign_text = " " .. m.symbol
        opts.sign_hl_group = m.highlight
      end

      pcall(vim.api.nvim_buf_set_extmark, bufnr, handler_ns, m.pos, 0, opts)
    end
  end

  if uses_signs then
    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(bar_winnr) or not vim.api.nvim_win_is_valid(winnr) then
        return
      end
      local info = vim.fn.getwininfo(bar_winnr)[1]
      if info and info.textoff ~= old_textoff then
        pcall(get_or_create_bar, winnr)
      end
    end)
  end
end

function M.refresh()
  local active_bars = {} ---@type table<integer, true>

  if global_enabled then
    for _, winnr in ipairs(get_target_windows()) do
      if can_attach(winnr) then
        local ok, bar_winnr, is_new = pcall(get_or_create_bar, winnr)
        if ok then
          ---@cast bar_winnr integer
          render(winnr, bar_winnr)
          active_bars[bar_winnr] = true
          if is_new then
            attach_handlers(winnr)
          end
        else
          stl.reporter.error({
            from = __module_name__,
            subject = "refresh",
            message = "Unable to get bar",
            details = { error = tostring(bar_winnr) },
          })
        end
      end
    end
  end

  for winnr, bar_winnr in pairs(bar_winnrs) do
    if not active_bars[bar_winnr] then
      close_bar(winnr)
    end
  end
end

---@param winnr                       integer
function M.attach(winnr)
  if not can_attach(winnr) then
    return
  end

  local ok, bar_winnr, is_new = pcall(get_or_create_bar, winnr)
  if ok then
    ---@cast bar_winnr integer
    render(winnr, bar_winnr)
    if is_new then
      attach_handlers(winnr)
    end
  else
    stl.reporter.error({
      from = __module_name__,
      subject = "attach",
      message = "Unable to create bar",
      details = { error = tostring(bar_winnr) },
    })
  end
end

---@param winnr                       integer
function M.detach(winnr)
  close_bar(winnr)
end

function M.detach_all()
  local winnrs = vim.tbl_keys(bar_winnrs)
  for _, winnr in ipairs(winnrs) do
    close_bar(winnr)
  end
end

function M.attach_global()
  global_enabled = true
  M.refresh()
end

function M.detach_global()
  global_enabled = false
  M.detach_all()
end

return M
