local __module_name__ = "era.m.explorer.widget" ---@type string

local Action = require("era.m.explorer.action")
local Tree = require("era.m.explorer.tree")
local View = require("era.m.explorer.view")
local ResourceFileManager = require("era.m.explorer.resource.file")

local EXPLORER_WIN_HIGHLIGHT = table.concat({
  "EndOfBuffer:m_ex_eob",
  "Normal:m_ex_bg",
  "SignColumn:m_ex_bg",
  "VertSplit:m_ex_border",
  "WinBar:m_ex_winbar",
  "WinBarNC:m_ex_winbar",
  "WinSeparator:m_ex_border",
}, ",")

---@class era.m.explorer.widget.IFlagItem
---@field public desc                   string
---@field public callback               fun(): nil
---@field public snapshot               fun(): string, string

---@class era.m.explorer.widget.IProps
---@field public name                   string
---@field public root                   ?string
---@field public o_flag_foldempty       stl.c.Observable
---@field public o_flag_hidden          stl.c.Observable
---@field public o_width                stl.c.Observable
---@field public flags                  ?era.m.explorer.widget.IFlagItem[]
---@field public on_disposed            ?fun(): nil

---@class era.m.explorer.Widget : dot.t.IWidget
---@field public name                   string
---@field public fullname               string
---@field protected _action             era.m.explorer.Action
---@field protected _autocmd_ids        integer[]
---@field protected _bufnr              integer|nil
---@field protected _disposed           boolean
---@field protected _flags              era.m.explorer.widget.IFlagItem[]
---@field protected _is_focused         boolean
---@field protected _keymaps            stl.t.IKeymap[]
---@field protected _nvimbar            era.m.nvimbar.Nvimbar
---@field protected _on_disposed        fun(): nil|nil
---@field protected _o_width            stl.c.Observable
---@field protected _prev_cursor_lnum   integer|nil
---@field protected _render_result      era.m.explorer.view.IRenderResult|nil
---@field protected _resource_manager   era.m.explorer.resource.FileManager
---@field protected _subscriptions      stl.c.IUnsubscribable[]
---@field protected _tree               era.m.explorer.Tree
---@field protected _view               era.m.explorer.View
---@field protected _winnr              integer|nil
local M = {}
M.__index = M

---@param props                         era.m.explorer.widget.IProps
---@return era.m.explorer.Widget
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string

  local o_flag_foldempty = props.o_flag_foldempty ---@type stl.c.Observable
  local o_flag_hidden = props.o_flag_hidden ---@type stl.c.Observable
  local show_hidden = o_flag_hidden:snapshot() ---@type boolean

  local self = setmetatable({}, M)

  local resource_manager = ResourceFileManager.new({
    name = name,
    show_hidden = show_hidden,
    on_change = function()
      if self._disposed then ---@diagnostic disable-line: invisible
        return
      end
      self._tree:mark_all_dirty() ---@diagnostic disable-line: invisible
      if self:isvisible() then
        self:__refresh__() ---@diagnostic disable-line: invisible
      end
    end,
  }) ---@type era.m.explorer.resource.FileManager

  ---@type era.m.explorer.Tree
  local tree = Tree.new({
    name = name,
    protocol = "file://",
    initial_root = props.root,
    resource_manager = resource_manager,
    o_flag_foldempty = o_flag_foldempty,
    o_flag_hidden = o_flag_hidden,
  })

  local view = View.new(name) ---@type era.m.explorer.View

  self.name = name
  self.fullname = fullname
  self._autocmd_ids = {}
  self._bufnr = nil
  self._disposed = false
  self._flags = props.flags or {}
  self._is_focused = false
  self._keymaps = {}
  self._on_disposed = props.on_disposed
  self._o_width = props.o_width
  self._prev_cursor_lnum = nil
  self._render_result = nil
  self._resource_manager = resource_manager
  self._subscriptions = {}
  self._tree = tree
  self._view = view
  self._winnr = nil

  ---@type era.m.explorer.action.IContext
  local action_ctx = {
    widget = self,
    tree = tree,
    resource_manager = resource_manager,
    fullname = fullname,
    get_cursor_uri = function()
      return self:get_cursor_uri()
    end,
    get_parent_uri = function(uri)
      return self:__get_parent_uri__(uri) ---@diagnostic disable-line: invisible
    end,
    get_visual_nodes = function()
      return self:__get_visual_nodes__() ---@diagnostic disable-line: invisible
    end,
    refresh = function(skip_refresh)
      self:__refresh__(skip_refresh) ---@diagnostic disable-line: invisible
    end,
    render = function()
      self:__render__() ---@diagnostic disable-line: invisible
    end,
    sync_cursor_to_uri = function(uri)
      self:__sync_cursor_to_uri__(uri) ---@diagnostic disable-line: invisible
    end,
  }
  self._action = Action.new(action_ctx)
  self._nvimbar = self:__create_nvimbar__()

  self:__setup_subscriptions__()
  return self
end

---@return nil
function M:close()
  self:hide()
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  for _, sub in ipairs(self._subscriptions) do
    sub:unsubscribe()
  end
  self._subscriptions = {}

  for _, autocmd_id in ipairs(self._autocmd_ids) do
    pcall(vim.api.nvim_del_autocmd, autocmd_id)
  end
  self._autocmd_ids = {}

  self:hide()
  self._tree:dispose()
  self._resource_manager:dispose()
  self._render_result = nil

  if self._on_disposed ~= nil then
    self._on_disposed()
  end
end

---@return integer|nil
function M:focus()
  dot.state.widget.push(self)

  local winnr = self:__create_win_as_needed__() ---@type integer
  vim.api.nvim_set_current_win(winnr)

  self._is_focused = true
  self:__refresh__()
  self:__update_cursorline__()
  return winnr
end

---@return integer|nil
function M:get_bufnr()
  return self._bufnr
end

---@return string|nil
function M:get_cursor_uri()
  local render_result = self._render_result ---@type era.m.explorer.view.IRenderResult|nil
  if render_result == nil then
    return nil
  end

  local winnr = self._winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end

  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local lnum = cursor[1] ---@type integer
  return render_result.lnum_to_uri[lnum]
end

---@return era.m.explorer.view.IRenderResult|nil
function M:get_render_result()
  return self._render_result
end

---@return era.m.explorer.Tree
function M:get_tree()
  return self._tree
end

---@return integer|nil
function M:get_winnr()
  return self._winnr
end

---@return nil
function M:hide()
  local winnr = self._winnr ---@type integer|nil
  self._winnr = nil

  self._resource_manager:pause_watch()

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    local width = vim.api.nvim_win_get_width(winnr) ---@type integer
    if width > 0 then
      self._o_width:next(width)
    end
    vim.api.nvim_win_close(winnr, true)
  end
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isfocused()
  if self._winnr == nil then
    return false
  end
  local winnr_current = vim.api.nvim_get_current_win() ---@type integer
  return winnr_current == self._winnr
end

---@return boolean
function M:isvisible()
  return self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr)
end

---@return nil
function M:refresh()
  self._tree:refresh(true)
  self:__refresh__(true)
  stl.reporter.info({
    from = self.fullname,
    subject = "refresh",
    message = "Explorer refreshed",
  })
end

---@return nil
function M:render_winbar()
  self:__update_winbar__()
end

---@return nil
function M:resize()
  local winnr = self._winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  vim.api.nvim_win_set_width(winnr, self:__get_effective_width__())
end

---@param uri                           string|nil
---@return nil
function M:reveal(uri)
  if uri == nil then
    return
  end

  local root_uri = self._tree.o_root_uri:snapshot() ---@type string
  if not vim.startswith(uri, root_uri) then
    local parent_uri = self:__get_parent_uri__(uri) ---@type string
    self:set_root(parent_uri)
    root_uri = self._tree.o_root_uri:snapshot()
  end

  local target_dir = uri:sub(-1) == "/" and uri or self:__get_parent_uri__(uri) ---@type string
  self._tree:expand_path(target_dir)

  self._tree:refresh(false)
  self:__refresh__()

  self._tree.o_cursor_uri:next(uri)
  self:__sync_cursor_to_uri__(uri)
end

---@param root_uri                      string
---@return boolean
function M:set_root(root_uri)
  local current_root_uri = self._tree.o_root_uri:snapshot() ---@type string
  if root_uri == current_root_uri then
    return true
  end

  local ok = self._tree:attach(root_uri) ---@type boolean
  if ok then
    self._tree.prev_root_uri = current_root_uri
    self._tree.o_root_uri:next(root_uri)
    self:__refresh__()
  end
  return ok
end

---@param width                         integer
---@return nil
function M:set_width(width)
  self._o_width:next(width)
  self:resize()
end

---@return nil
function M:show()
  self:focus()
end

---@return nil
function M:toggle()
  if self:isvisible() then
    self:hide()
  else
    self:focus()
  end
end

----------------------------------------------------------------------------------------------------

---@protected
---@return integer
function M:__create_buf_as_needed__()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end

  bufnr = vim.api.nvim_create_buf(false, true)
  self._bufnr = bufnr

  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = "explorer"
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].swapfile = false

  self:__setup_keymaps__(bufnr)
  return bufnr
end

---@protected
---@return era.m.nvimbar.Nvimbar
function M:__create_nvimbar__()
  local c = require("era.m.nvimbar").component
  local Nvimbar = require("era.m.nvimbar").Nvimbar
  local position = "f_wl" ---@type stl.e.NvimbarPositionEnum

  local flags = self:__get_flags__() ---@type era.m.explorer.widget.IFlagItem[]
  ---@type era.m.nvimbar.component.explorer.IFlagItem[]
  local nvimbar_flags = {}
  for _, flag in ipairs(flags) do
    nvimbar_flags[#nvimbar_flags + 1] = {
      desc = flag.desc,
      callback = dot.G.register_anonymous_fn(flag.callback) or "dot.G.noop",
      snapshot = flag.snapshot,
    }
  end

  local get_width = function()
    local winnr = self._winnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      return vim.api.nvim_win_get_width(winnr)
    end
    return 0
  end

  ---@type era.m.nvimbar.Nvimbar
  local nvimbar = Nvimbar.new({
    name = string.format("%s#winbar", self.fullname),
    comp_sep = "",
    comp_sep_hlname = "m_ex_winbar",
    comp_sep_hlname_active = "m_ex_winbar",
    delay = 128,
    silent = stl.fn.falsy,
    get_max_width = get_width,
    get_preset_context = function()
      local winnr = self._winnr ---@type integer|nil
      return { winnr = winnr }
    end,
    is_active = function()
      local winnr = self._winnr ---@type integer|nil
      return winnr == vim.api.nvim_get_current_win()
    end,
    on_fulfilled = function(result)
      local winnr = self._winnr ---@type integer|nil
      if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
        vim.wo[winnr].winbar = result
      end
    end,
  }):place("left", c.explorer.winbar(self._tree.o_root_uri, position, nvimbar_flags, get_width), 100)

  return nvimbar
end

---@protected
---@return integer
function M:__create_win_as_needed__()
  local winnr = self._winnr ---@type integer|nil
  local bufnr = self:__create_buf_as_needed__() ---@type integer

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    return winnr
  end

  local width = self:__get_effective_width__() ---@type integer
  vim.cmd(("silent noswapfile vertical topleft sbuffer %d | vertical resize %d"):format(bufnr, width))
  winnr = vim.api.nvim_get_current_win() ---@type integer
  self._winnr = winnr

  vim.wo[winnr].cursorline = false
  vim.wo[winnr].foldcolumn = "0"
  vim.wo[winnr].foldlevel = 99
  vim.wo[winnr].list = false
  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "no"
  vim.wo[winnr].spell = false
  vim.wo[winnr].winfixwidth = true
  vim.wo[winnr].wrap = false
  vim.wo[winnr].winhighlight = EXPLORER_WIN_HIGHLIGHT

  dot.win.set_type(winnr, stl.nvim.win.Types.EXPLORER)

  self:__update_winbar__()

  local autocmd_id_buf_enter = vim.api.nvim_create_autocmd("BufEnter", {
    buffer = bufnr,
    callback = function()
      self._is_focused = true
      self:__update_cursorline__()
    end,
  })
  self._autocmd_ids[#self._autocmd_ids + 1] = autocmd_id_buf_enter

  local autocmd_id_buf_leave = vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    callback = function()
      self._is_focused = false
      self:__update_cursorline__()
    end,
  })
  self._autocmd_ids[#self._autocmd_ids + 1] = autocmd_id_buf_leave

  local autocmd_id_cursor_moved = vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = bufnr,
    callback = function()
      local uri = self:get_cursor_uri() ---@type string|nil
      if uri ~= nil then
        self._tree.o_cursor_uri:next(uri)
      end
      self:__update_cursorline__()
    end,
  })
  self._autocmd_ids[#self._autocmd_ids + 1] = autocmd_id_cursor_moved

  return winnr
end

---@protected
---@return integer
function M:__get_effective_width__()
  local columns = vim.o.columns ---@type integer
  local width = self._o_width:snapshot() ---@type integer
  return math.min(width, columns)
end

---@protected
---@return era.m.explorer.widget.IFlagItem[]
function M:__get_flags__()
  local tree = self._tree ---@type era.m.explorer.Tree

  ---@type era.m.explorer.widget.IFlagItem[]
  local flags = {}

  for _, flag in ipairs(self._flags) do
    flags[#flags + 1] = flag
  end

  flags[#flags + 1] = {
    desc = "explorer: toggle hidden files",
    callback = function()
      tree.o_flag_hidden:next(not tree.o_flag_hidden:snapshot())
    end,
    snapshot = function()
      local show_hidden = tree.o_flag_hidden:snapshot() ---@type boolean
      return stl.icon.symbols.flag_hidden, show_hidden and "picker_flag_blue" or "picker_flag_grey"
    end,
  }

  return flags
end

---@protected
---@param uri                           string
---@return string
function M:__get_parent_uri__(uri)
  if uri:sub(-1) == "/" then
    uri = uri:sub(1, -2)
  end

  local parent = uri:match("(.*/)[^/]+$") ---@type string|nil
  if parent == nil then
    return uri
  end

  return parent
end

---@protected
---@return era.m.explorer.Node[]
function M:__get_visual_nodes__()
  local render_result = self._render_result ---@type era.m.explorer.view.IRenderResult|nil
  if render_result == nil then
    return {}
  end

  local start_lnum, end_lnum = stl.nvim.buf.retrieve_visual_lnum_range() ---@type integer, integer

  local mode = vim.fn.mode() ---@type string
  if mode == "v" or mode == "V" or mode == "\22" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  end

  local nodes = {} ---@type era.m.explorer.Node[]
  for lnum = start_lnum, end_lnum do
    local uri = render_result.lnum_to_uri[lnum] ---@type string|nil
    if uri ~= nil then
      local node = self._tree:locate(uri) ---@type era.m.explorer.Node|nil
      if node ~= nil then
        nodes[#nodes + 1] = node
      end
    end
  end

  return nodes
end

---@protected
---@param direction                     "prev"|"next"
---@return nil
function M:__goto_git_changed__(direction)
  local aggregated = era.m.git.state.aggregated() ---@type era.m.git.status.IAggregatedCache
  local staged_files = aggregated.staged_files ---@type string[]
  local unstaged_files = aggregated.unstaged_files ---@type string[]

  if #staged_files == 0 and #unstaged_files == 0 then
    stl.reporter.info({
      from = self.fullname,
      subject = "goto git changed",
      message = "No git changes detected",
    })
    return
  end

  local changed_set = {} ---@type table<string, boolean>
  for _, filepath in ipairs(staged_files) do
    changed_set[filepath] = true
  end
  for _, filepath in ipairs(unstaged_files) do
    changed_set[filepath] = true
  end

  local found = self:__goto_matching_file_or_dir__(direction, function(filepath, is_dir)
    local normalized = dot.path.normalize(filepath) ---@type string
    if is_dir then
      for changed_path, _ in pairs(changed_set) do
        if vim.startswith(changed_path, normalized .. "/") then
          return true
        end
      end
      return false
    end
    return changed_set[normalized] == true
  end)

  if not found then
    stl.reporter.info({
      from = self.fullname,
      subject = "goto git changed",
      message = "No git changed files in current view",
    })
  end
end

---@protected
---@param direction                     "prev"|"next"
---@param matcher                       fun(filepath: string): boolean
---@return boolean                      found
function M:__goto_matching_file__(direction, matcher)
  return self:__goto_matching_item__(direction, false, function(filepath, _)
    return matcher(filepath)
  end)
end

---@protected
---@param direction                     "prev"|"next"
---@param matcher                       fun(filepath: string, is_dir: boolean): boolean
---@return boolean                      found
function M:__goto_matching_file_or_dir__(direction, matcher)
  return self:__goto_matching_item__(direction, true, matcher)
end

---@protected
---@param direction                     "prev"|"next"
---@param include_dirs                  boolean
---@param matcher                       fun(filepath: string, is_dir: boolean): boolean
---@return boolean                      found
function M:__goto_matching_item__(direction, include_dirs, matcher)
  local render_result = self._render_result ---@type era.m.explorer.view.IRenderResult|nil
  if render_result == nil then
    return false
  end

  local winnr = self._winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local current_lnum = cursor[1] ---@type integer
  local total_lines = #render_result.lines ---@type integer

  local matching_lnums = {} ---@type integer[]
  for lnum = 1, total_lines do
    local uri = render_result.lnum_to_uri[lnum] ---@type string|nil
    if uri ~= nil then
      local is_dir = uri:sub(-1) == "/" ---@type boolean
      if include_dirs or not is_dir then
        local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
        if is_dir and #filepath > 1 then
          filepath = filepath:sub(1, -2)
        end
        if matcher(filepath, is_dir) then
          matching_lnums[#matching_lnums + 1] = lnum
        end
      end
    end
  end

  if #matching_lnums == 0 then
    return false
  end

  local target_lnum ---@type integer|nil
  if direction == "next" then
    for _, lnum in ipairs(matching_lnums) do
      if lnum > current_lnum then
        target_lnum = lnum
        break
      end
    end
    if target_lnum == nil then
      target_lnum = matching_lnums[1]
    end
  else
    for i = #matching_lnums, 1, -1 do
      if matching_lnums[i] < current_lnum then
        target_lnum = matching_lnums[i]
        break
      end
    end
    if target_lnum == nil then
      target_lnum = matching_lnums[#matching_lnums]
    end
  end

  if target_lnum ~= nil then
    local target_uri = render_result.lnum_to_uri[target_lnum] ---@type string|nil
    if target_uri ~= nil then
      self._tree.o_cursor_uri:next(target_uri)
      pcall(vim.api.nvim_win_set_cursor, winnr, { target_lnum, 0 })
      return true
    end
  end

  return false
end

---@protected
---@param skip_refresh                  ?boolean
---@return nil
function M:__refresh__(skip_refresh)
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local root_uri = self._tree.o_root_uri:snapshot() ---@type string
  local current_root_uri = self._tree:get_root_uri() ---@type string
  if root_uri ~= current_root_uri then
    local ok = self._tree:attach(root_uri) ---@type boolean
    if not ok then
      return
    end
  end

  if not skip_refresh then
    self._tree:refresh(false)
  end
  self:__render__()
end

---@protected
---@return nil
function M:__render__()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local root_node = self._tree:get_root_node() ---@type era.m.explorer.Node

  local render_result = self._view:render(bufnr, self._tree, root_node, {
    resource_manager = self._resource_manager,
    foldempty = self._tree.o_flag_foldempty:snapshot(),
    only_selected = dot.context.explorer.flag_selected:snapshot(),
    show_git_status = true,
    show_icons = true,
    select_mode = self._tree.select_mode,
  })
  self._render_result = render_result

  local cursor_uri = self._tree.o_cursor_uri:snapshot() ---@type string
  self:__sync_cursor_to_uri__(cursor_uri)
  self:__update_winbar__()
  self:__update_cursorline__()
  self:__sync_watches__(root_node)
end

---@protected
---@param root_node                     era.m.explorer.Node
---@return nil
function M:__sync_watches__(root_node)
  local expanded_dirs = {} ---@type string[]

  ---@param node                        era.m.explorer.Node
  local function walk(node)
    if node.nodetype == "D" and node.expanded then
      local filepath = yoz.uri.to_filepath(node.uri) ---@type string|nil
      if filepath then
        expanded_dirs[#expanded_dirs + 1] = filepath
      end
      for _, child in ipairs(node.children) do
        walk(child)
      end
    end
  end

  walk(root_node)
  self._resource_manager:sync_watches(expanded_dirs)
end

---@protected
---@param bufnr                         integer
---@return nil
function M:__setup_keymaps__(bufnr)
  local action = self._action ---@type era.m.explorer.Action
  local widget_keymaps = dot.state.widget.get_keymaps(self) ---@type stl.t.IKeymap[]

  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "<2-LeftMouse>",
      callback = function()
        action:open()
      end,
      desc = "explorer: open/toggle (double-click)",
    },
    {
      modes = { "n" },
      key = "<C-a>r",
      aliases = { "<D-r>", "<M-r>" },
      callback = function()
        self:refresh()
      end,
      desc = "explorer: redraw",
    },
    -- <C-*>
    {
      modes = { "n" },
      key = "<C-q>",
      callback = function()
        action:send_to_quickfix(self._tree:get_root_node())
      end,
      desc = "explorer: send selection to quickfix",
    },
    {
      modes = { "n" },
      key = "<C-t>",
      callback = function()
        action:open_tab()
      end,
      desc = "explorer: open in tab",
    },
    {
      modes = { "n" },
      key = "<C-v>",
      callback = function()
        action:open_vsplit()
      end,
      desc = "explorer: open in vsplit",
    },
    {
      modes = { "n" },
      key = "<C-x>",
      callback = function()
        action:open_split()
      end,
      desc = "explorer: open in split",
    },
    -- Special keys
    {
      modes = { "n" },
      key = "<BS>",
      callback = function()
        action:go_parent()
      end,
      desc = "explorer: go to parent directory",
    },
    {
      modes = { "n" },
      key = "<CR>",
      callback = function()
        action:open()
      end,
      desc = "explorer: open/toggle",
    },
    {
      modes = { "n" },
      key = "<Tab>",
      callback = function()
        action:select_toggle()
      end,
      desc = "explorer: toggle selection",
    },
    -- Symbols
    {
      modes = { "n" },
      key = ".",
      callback = function()
        action:set_root()
      end,
      desc = "explorer: set as root",
    },
    {
      modes = { "n" },
      key = "?",
      callback = function()
        action:show_keysheet(self._keymaps)
      end,
      desc = "explorer: show keymap help",
    },
    {
      modes = { "n" },
      key = "[d",
      callback = function()
        self:__goto_matching_file__("prev", function(filepath)
          return era.m.lsp.diagnostic.has_diagnostics(filepath, nil)
        end)
      end,
      desc = "explorer: go to prev diagnostic file",
    },
    {
      modes = { "n" },
      key = "[e",
      callback = function()
        self:__goto_matching_file__("prev", function(filepath)
          return era.m.lsp.diagnostic.has_diagnostics(filepath, vim.diagnostic.severity.ERROR)
        end)
      end,
      desc = "explorer: go to prev diagnostic error file",
    },
    {
      modes = { "n" },
      key = "[h",
      callback = function()
        self:__goto_git_changed__("prev")
      end,
      desc = "explorer: go to prev git changed file",
    },
    {
      modes = { "n" },
      key = "[i",
      callback = function()
        action:jump_parent()
      end,
      desc = "explorer: jump to parent line",
    },
    {
      modes = { "n" },
      key = "[w",
      callback = function()
        self:__goto_matching_file__("prev", function(filepath)
          return era.m.lsp.diagnostic.has_diagnostics(filepath, vim.diagnostic.severity.WARN)
        end)
      end,
      desc = "explorer: go to prev diagnostic warning file",
    },
    {
      modes = { "n" },
      key = "]d",
      callback = function()
        self:__goto_matching_file__("next", function(filepath)
          return era.m.lsp.diagnostic.has_diagnostics(filepath, nil)
        end)
      end,
      desc = "explorer: go to next diagnostic file",
    },
    {
      modes = { "n" },
      key = "]e",
      callback = function()
        self:__goto_matching_file__("next", function(filepath)
          return era.m.lsp.diagnostic.has_diagnostics(filepath, vim.diagnostic.severity.ERROR)
        end)
      end,
      desc = "explorer: go to next diagnostic error file",
    },
    {
      modes = { "n" },
      key = "]h",
      callback = function()
        self:__goto_git_changed__("next")
      end,
      desc = "explorer: go to next git changed file",
    },
    {
      modes = { "n" },
      key = "]i",
      callback = function()
        action:jump_last_child()
      end,
      desc = "explorer: jump to last child",
    },
    {
      modes = { "n" },
      key = "]w",
      callback = function()
        self:__goto_matching_file__("next", function(filepath)
          return era.m.lsp.diagnostic.has_diagnostics(filepath, vim.diagnostic.severity.WARN)
        end)
      end,
      desc = "explorer: go to next diagnostic warning file",
    },
    -- Uppercase letters
    {
      modes = { "n", "i" },
      key = "I",
      callback = function() end,
      desc = "explorer: nop (block insert mode)",
    },
    {
      modes = { "n" },
      key = "A",
      callback = function()
        action:create_directory()
      end,
      desc = "explorer: create directory",
    },
    {
      modes = { "n" },
      key = "H",
      callback = function()
        self._tree.o_flag_hidden:next(not self._tree.o_flag_hidden:snapshot())
      end,
      desc = "explorer: toggle hidden files",
    },
    {
      modes = { "n" },
      key = "J",
      callback = function()
        action:pick_win_split()
      end,
      desc = "explorer: pick window and split",
    },
    {
      modes = { "n" },
      key = "L",
      callback = function()
        action:pick_win_vsplit()
      end,
      desc = "explorer: pick window and vsplit",
    },
    {
      modes = { "n" },
      key = "O",
      callback = function()
        action:open_system_explorer()
      end,
      desc = "explorer: open in system explorer",
    },
    {
      modes = { "n" },
      key = "R",
      callback = function()
        self:refresh()
      end,
      desc = "explorer: refresh",
    },
    {
      modes = { "n" },
      key = "W",
      callback = function()
        action:collapse_all()
      end,
      desc = "explorer: collapse all",
    },
    -- Lowercase letters
    {
      modes = { "n" },
      key = "a",
      callback = function()
        action:create_file()
      end,
      desc = "explorer: create file",
    },
    {
      modes = { "n" },
      key = "c",
      callback = function()
        action:copy_node()
      end,
      desc = "explorer: copy node",
    },
    {
      modes = { "n" },
      key = "d",
      callback = function()
        action:delete()
      end,
      desc = "explorer: delete",
    },
    {
      modes = { "n" },
      key = "gb",
      callback = function()
        action:go_prev()
      end,
      desc = "explorer: go to previous root",
    },
    {
      modes = { "n" },
      key = "gc",
      callback = function()
        action:go_cwd()
      end,
      desc = "explorer: go to cwd",
    },
    {
      modes = { "n" },
      key = "gw",
      callback = function()
        action:go_home()
      end,
      desc = "explorer: go to workspace root",
    },
    {
      modes = { "n" },
      key = "h",
      callback = function()
        action:collapse_or_parent()
      end,
      desc = "explorer: collapse/go parent",
    },
    {
      modes = { "n", "i" },
      key = "i",
      callback = function() end,
      desc = "explorer: nop (block insert mode)",
    },
    {
      modes = { "n" },
      key = "l",
      callback = function()
        action:open()
      end,
      desc = "explorer: open/toggle",
    },
    {
      modes = { "n" },
      key = "mc",
      callback = function()
        action:toggle_select_mode("copy")
      end,
      desc = "explorer: toggle copy selection",
    },
    {
      modes = { "n" },
      key = "md",
      callback = function()
        action:delete_selected()
      end,
      desc = "explorer: delete selected",
    },
    {
      modes = { "n" },
      key = "mo",
      callback = function()
        action:open_selected()
      end,
      desc = "explorer: open selected files",
    },
    {
      modes = { "n" },
      key = "mp",
      callback = function()
        action:paste()
      end,
      desc = "explorer: paste",
    },
    {
      modes = { "n" },
      key = "ms",
      callback = function()
        action:toggle_select_mode("select")
      end,
      desc = "explorer: toggle select mode",
    },
    {
      modes = { "n" },
      key = "mx",
      callback = function()
        action:toggle_select_mode("cut")
      end,
      desc = "explorer: toggle cut selection",
    },
    {
      modes = { "n" },
      key = "o",
      callback = function()
        action:open()
      end,
      desc = "explorer: open/toggle",
    },
    {
      modes = { "n" },
      key = "oa",
      callback = function()
        action:add_locations_to_ai()
      end,
      desc = "explorer: add locations to ai",
    },
    {
      modes = { "n" },
      key = "oc",
      callback = function()
        action:copy_path()
      end,
      desc = "explorer: copy path",
    },
    {
      modes = { "n" },
      key = "oe",
      callback = function()
        action:open_file_explorer()
      end,
      desc = "explorer: open file explorer",
    },
    {
      modes = { "n" },
      key = "of",
      callback = function()
        action:open_file_finder()
      end,
      desc = "explorer: open file finder",
    },
    {
      modes = { "n" },
      key = "oi",
      callback = function()
        action:show_file_info()
      end,
      desc = "explorer: show file info",
    },
    {
      modes = { "n" },
      key = "oo",
      callback = function()
        action:open_system_explorer()
      end,
      desc = "explorer: open in system explorer",
    },
    {
      modes = { "n" },
      key = "os",
      callback = function()
        action:open_searcher()
      end,
      desc = "explorer: open searcher",
    },
    {
      modes = { "n" },
      key = "p",
      callback = function()
        action:paste()
      end,
      desc = "explorer: paste",
    },
    {
      modes = { "n" },
      key = "q",
      callback = function()
        self:hide()
      end,
      desc = "explorer: close",
    },
    {
      modes = { "n" },
      key = "r",
      callback = function()
        action:rename()
      end,
      desc = "explorer: rename",
    },
    {
      modes = { "n" },
      key = "w",
      callback = function()
        action:pick_win_open()
      end,
      desc = "explorer: pick window and open",
    },
    {
      modes = { "n" },
      key = "x",
      callback = function()
        action:cut()
      end,
      desc = "explorer: cut",
    },
    {
      modes = { "n" },
      key = "y",
      callback = function()
        action:toggle_select_mode("copy")
      end,
      desc = "explorer: yank (copy)",
    },
    {
      modes = { "n" },
      key = "z",
      callback = function()
        action:toggle_recursive()
      end,
      desc = "explorer: toggle expand/collapse recursively",
    },
    -- Visual mode
    {
      modes = { "x" },
      key = "<Tab>",
      callback = function()
        action:toggle_select_mode_visual("select")
      end,
      desc = "explorer: toggle select (visual)",
    },
    {
      modes = { "x" },
      key = "c",
      callback = function()
        action:toggle_select_mode_visual("copy")
      end,
      desc = "explorer: toggle copy (visual)",
    },
    {
      modes = { "x" },
      key = "d",
      callback = function()
        action:delete_visual()
      end,
      desc = "explorer: delete (visual)",
    },
    {
      modes = { "x" },
      key = "mc",
      callback = function()
        action:toggle_select_mode_visual("copy")
      end,
      desc = "explorer: toggle copy (visual)",
    },
    {
      modes = { "x" },
      key = "ms",
      callback = function()
        action:toggle_select_mode_visual("select")
      end,
      desc = "explorer: toggle select (visual)",
    },
    {
      modes = { "x" },
      key = "mx",
      callback = function()
        action:toggle_select_mode_visual("cut")
      end,
      desc = "explorer: toggle cut (visual)",
    },
    {
      modes = { "x" },
      key = "my",
      callback = function()
        action:toggle_select_mode_visual("copy")
      end,
      desc = "explorer: toggle copy (visual)",
    },
    {
      modes = { "x" },
      key = "oa",
      callback = function()
        action:add_locations_to_ai_visual()
      end,
      desc = "explorer: add locations to ai (visual)",
    },
    {
      modes = { "x" },
      key = "x",
      callback = function()
        action:toggle_select_mode_visual("cut")
      end,
      desc = "explorer: toggle cut (visual)",
    },
    {
      modes = { "x" },
      key = "y",
      callback = function()
        action:toggle_select_mode_visual("copy")
      end,
      desc = "explorer: toggle copy (visual)",
    },
  }

  local flags = self:__get_flags__() ---@type era.m.explorer.widget.IFlagItem[]
  for i, flag in ipairs(flags) do
    keymaps[#keymaps + 1] = {
      modes = { "n" },
      key = string.format("t%d", i),
      callback = flag.callback,
      desc = flag.desc,
    }
  end

  for _, km in ipairs(widget_keymaps) do
    keymaps[#keymaps + 1] = km
  end

  self._keymaps = keymaps
  stl.nvim.fn.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
end

---@protected
---@return nil
function M:__setup_subscriptions__()
  local tree = self._tree ---@type era.m.explorer.Tree

  local sub_root_uri = tree.o_root_uri:subscribe(
    stl.c.Subscriber.new({
      on_next = function()
        self:__update_winbar__()
        dot.state.status.dirtier_tabline:mark_dirty()
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_root_uri

  local sub_show_hidden = tree.o_flag_hidden:subscribe(
    stl.c.Subscriber.new({
      on_next = function(show_hidden)
        self._resource_manager:set_show_hidden(show_hidden)
        self._tree:refresh(true)
        self:__render__()
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_show_hidden

  local sub_foldempty = tree.o_flag_foldempty:subscribe(
    stl.c.Subscriber.new({
      on_next = function()
        self:__refresh__()
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_foldempty

  local sub_width = self._o_width:subscribe(
    stl.c.Subscriber.new({
      on_next = function()
        self:resize()
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_width

  local sub_flag_selected = dot.context.explorer.flag_selected:subscribe(
    stl.c.Subscriber.new({
      on_next = function()
        self:__refresh__()
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_flag_selected

  local sub_flag_viewtype = dot.context.explorer.flag_viewtype:subscribe(
    stl.c.Subscriber.new({
      on_next = function()
        self:__refresh__()
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_flag_viewtype

  local sub_git_staged = era.m.git.state.o_staged_files:subscribe(
    stl.c.Subscriber.new({
      on_next = function()
        if self:isvisible() then
          self:__render__()
        end
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_git_staged

  local sub_git_unstaged = era.m.git.state.o_unstaged_files:subscribe(
    stl.c.Subscriber.new({
      on_next = function()
        if self:isvisible() then
          self:__render__()
        end
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_git_unstaged

  local sub_diagnostic = era.m.lsp.diagnostic.subscribe_all(
    stl.c.Subscriber.new({
      on_next = function()
        if self:isvisible() then
          self:__render__()
        end
      end,
    })
  )
  self._subscriptions[#self._subscriptions + 1] = sub_diagnostic
end

---@protected
---@param uri                           string
---@return nil
function M:__sync_cursor_to_uri__(uri)
  local render_result = self._render_result ---@type era.m.explorer.view.IRenderResult|nil
  if render_result == nil then
    return
  end

  local winnr = self._winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local lnum = render_result.uri_to_lnum[uri] ---@type integer|nil
  if lnum ~= nil then
    pcall(vim.api.nvim_win_set_cursor, winnr, { lnum, 0 })
  end
end

---@protected
---@return nil
function M:__update_cursorline__()
  local bufnr = self._bufnr ---@type integer|nil
  local winnr = self._winnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local render_result = self._render_result ---@type era.m.explorer.view.IRenderResult|nil
  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local lnum = cursor[1] ---@type integer
  local prev_lnum = self._prev_cursor_lnum ---@type integer|nil

  vim.api.nvim_buf_clear_namespace(bufnr, dot.var.nsnr.explorer_cursorline, 0, -1)

  local hlgroup = self._is_focused and "m_ex_cursorline" or "m_ex_cursorline_blur" ---@type string
  vim.api.nvim_buf_set_extmark(bufnr, dot.var.nsnr.explorer_cursorline, lnum - 1, 0, {
    line_hl_group = hlgroup,
    priority = 100,
  })

  if render_result ~= nil then
    if prev_lnum ~= nil and prev_lnum ~= lnum then
      self._view:update_virt_text(bufnr, render_result, prev_lnum, nil)
    end
    local cursorline_hlgroup = self._is_focused and "m_ex_cursorline" or "m_ex_cursorline_blur" ---@type string
    self._view:update_virt_text(bufnr, render_result, lnum, cursorline_hlgroup)
  end

  self._prev_cursor_lnum = lnum
end

---@protected
---@return nil
function M:__update_winbar__()
  local winnr = self._winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  if vim.o.showtabline ~= 0 then
    -- When tabline is shown, hide winbar (info displayed in tabline instead)
    vim.wo[winnr].winbar = nil
    return
  end

  self._nvimbar:render(true)
end

return M
