local __module_name__ = "dot.module.explorer.widget" ---@type string

local Tree = require("dot.module.explorer.tree")
local View = require("dot.module.explorer.view")
local ResourceFileManager = require("dot.module.explorer.resource.file")

local EXPLORER_WIN_HIGHLIGHT = table.concat({
  "EndOfBuffer:f_explorer_eob",
  "Normal:f_explorer_bg",
  "SignColumn:f_explorer_bg",
  "VertSplit:f_explorer_border",
  "WinBar:f_explorer_winbar",
  "WinBarNC:f_explorer_winbar",
  "WinSeparator:f_explorer_border",
}, ",")

local ns_cursorline = vim.api.nvim_create_namespace("explorer_cursorline") ---@type integer

---@class dot.module.explorer.widget.IFlagItem
---@field public desc                   string
---@field public callback               fun(): nil
---@field public snapshot               fun(): string, string

---@class dot.module.explorer.widget.IProps
---@field public name                   string
---@field public root                   ?string
---@field public width                  ?integer
---@field public o_flag_foldempty       ?ark.c.Observable
---@field public o_flag_hidden          ?ark.c.Observable
---@field public o_width                ?ark.c.Observable
---@field public flags                  ?dot.module.explorer.widget.IFlagItem[]

---@class dot.module.explorer.Widget : dot.t.IWidget
---@field public name                   string
---@field public fullname               string
---@field protected _disposed           boolean
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _autocmd_ids        integer[]
---@field protected _tree               dot.module.explorer.Tree
---@field protected _view               dot.module.explorer.View
---@field protected _resource_manager   dot.module.explorer.resource.FileManager
---@field protected _render_result      dot.module.explorer.view.IRenderResult|nil
---@field protected _nvimbar            dot.module.nvimbar.Nvimbar
---@field protected _subscriptions      ark.c.IUnsubscribable[]
---@field protected _width              integer
---@field protected _o_width            ark.c.Observable|nil
---@field protected _flags              dot.module.explorer.widget.IFlagItem[]
---@field protected _is_focused         boolean
---@field protected _keymaps            ark.t.IKeymap[]
---@field protected _prev_cursor_lnum   integer|nil
local M = {}
M.__index = M

---@param props                         dot.module.explorer.widget.IProps
---@return dot.module.explorer.Widget
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string

  local o_flag_foldempty = props.o_flag_foldempty ---@type ark.c.Observable|nil
  local o_flag_hidden = props.o_flag_hidden ---@type ark.c.Observable|nil
  local show_hidden = o_flag_hidden ~= nil and o_flag_hidden:snapshot() or false ---@type boolean

  local resource_manager = ResourceFileManager.new({ name = name, show_hidden = show_hidden }) ---@type dot.module.explorer.resource.FileManager

  ---@type dot.module.explorer.Tree
  local tree = Tree.new({
    name = name,
    protocol = "file://",
    initial_root = props.root,
    resource_manager = resource_manager,
    o_flag_foldempty = o_flag_foldempty,
    o_flag_hidden = o_flag_hidden,
  })

  local view = View.new(name) ---@type dot.module.explorer.View

  local self = setmetatable({}, M)
  self.name = name
  self.fullname = fullname
  self._disposed = false
  self._bufnr = nil
  self._winnr = nil
  self._autocmd_ids = {}
  self._tree = tree
  self._view = view
  self._resource_manager = resource_manager
  self._render_result = nil
  self._subscriptions = {}
  self._width = props.width or 40
  self._o_width = props.o_width
  self._flags = props.flags or {}
  self._is_focused = false
  self._keymaps = {}
  self._prev_cursor_lnum = nil
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
  self._render_result = nil
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
  local render_result = self._render_result ---@type dot.module.explorer.view.IRenderResult|nil
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

---@return dot.module.explorer.view.IRenderResult|nil
function M:get_render_result()
  return self._render_result
end

---@return dot.module.explorer.State
function M:get_state()
  return self._tree.state
end

---@return dot.module.explorer.Tree
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

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    local width = vim.api.nvim_win_get_width(winnr) ---@type integer
    if width > 0 then
      self._width = width
      if self._o_width ~= nil then
        self._o_width:next(width)
      end
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
  ark.reporter.info({
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

  local root_uri = self._tree.state.o_root_uri:snapshot() ---@type string
  if not vim.startswith(uri, root_uri) then
    local parent_uri = self:__get_parent_uri__(uri) ---@type string
    self:set_root(parent_uri)
    root_uri = self._tree.state.o_root_uri:snapshot()
  end

  local target_dir = uri:sub(-1) == "/" and uri or self:__get_parent_uri__(uri) ---@type string
  self._tree:expand_path(target_dir)

  self._tree:refresh(false)
  self:__refresh__()

  self._tree.state.o_cursor_uri:next(uri)
  self:__sync_cursor_to_uri__(uri)
end

---@param root_uri                      string
---@return boolean
function M:set_root(root_uri)
  local current_root_uri = self._tree.state.o_root_uri:snapshot() ---@type string
  if root_uri == current_root_uri then
    return true
  end

  local ok = self._tree:attach(root_uri) ---@type boolean
  if ok then
    self._tree.state.prev_root_uri = current_root_uri
    self._tree.state.o_root_uri:next(root_uri)
    self:__refresh__()
  end
  return ok
end

---@param width                         integer
---@return nil
function M:set_width(width)
  self._width = width
  if self._o_width ~= nil then
    self._o_width:next(width)
  end
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
---@return nil
function M:__action_add_locations_to_ai__()
  local selected_nodes = self._tree:get_selected_nodes() ---@type dot.module.explorer.Node[]

  local locations = {} ---@type dot.t.ILocation[]
  if #selected_nodes > 0 then
    for _, node in ipairs(selected_nodes) do
      local filepath = node.uri:sub(8) ---@type string
      if filepath:sub(-1) == "/" then
        filepath = filepath:sub(1, -2)
      end
      locations[#locations + 1] = { filepath = filepath }
    end
  else
    local uri = self:get_cursor_uri() ---@type string|nil
    if uri == nil then
      return
    end
    local filepath = uri:sub(8) ---@type string
    if filepath:sub(-1) == "/" then
      filepath = filepath:sub(1, -2)
    end
    locations[#locations + 1] = { filepath = filepath }
  end

  dot.fn.add_locations_to_ai(locations)
end

---@protected
---@return nil
function M:__action_add_locations_to_ai_visual__()
  local nodes = self:__get_visual_nodes__() ---@type dot.module.explorer.Node[]
  if #nodes == 0 then
    return
  end

  local locations = {} ---@type dot.t.ILocation[]
  for _, node in ipairs(nodes) do
    local filepath = node.uri:sub(8) ---@type string
    if filepath:sub(-1) == "/" then
      filepath = filepath:sub(1, -2)
    end
    locations[#locations + 1] = { filepath = filepath }
  end

  dot.fn.add_locations_to_ai(locations)
end

---@protected
---@return nil
function M:__action_collapse_all__()
  local root_uri = self._tree.state.o_root_uri:snapshot() ---@type string
  self._tree:toggle_expanded(root_uri, true, "collapse")
  self._tree:toggle_expanded(root_uri, false, "expand")
  self:__refresh__()
end

---@protected
---@return nil
function M:__action_collapse_or_parent__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  if uri:sub(-1) == "/" then
    local node = self._tree:locate(uri) ---@type dot.module.explorer.Node|nil
    if node ~= nil and node:is_expanded() then
      self._tree:toggle_expanded(uri, false, "collapse")
      self:__refresh__()
      return
    end
  end

  local parent_uri = self:__get_parent_uri__(uri) ---@type string
  local root_uri = self._tree.state.o_root_uri:snapshot() ---@type string
  if parent_uri ~= root_uri then
    self._tree.state.o_cursor_uri:next(parent_uri)
    self:__sync_cursor_to_uri__(parent_uri)
  end
end

---@protected
---@return nil
function M:__action_copy_node__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local selected_nodes = self._tree:get_selected_nodes() ---@type dot.module.explorer.Node[]
  if #selected_nodes > 0 then
    local current_mode = self._tree.select_mode ---@type dot.module.explorer.SelectModeEnum
    local is_selected = self._tree:is_selected(uri) ---@type boolean

    if current_mode == "copy" and is_selected then
      self._tree:toggle_selected(uri, "unselect")
    else
      self._tree:toggle_selected(uri, "select")
    end

    self._tree.select_mode = "copy"
    self:__refresh__()
    return
  end

  local filepath = uri:sub(8) ---@type string
  if filepath:sub(-1) == "/" then
    filepath = filepath:sub(1, -2)
  end

  vim.ui.input({ prompt = "Copy to: ", default = filepath }, function(input)
    if input == nil or input == "" or input == filepath then
      return
    end

    local target_uri = "file://" .. input ---@type string
    local ok = self._resource_manager:copy(uri, target_uri) ---@type boolean
    if ok then
      self._tree:refresh(true)
      vim.schedule(function()
        self:__refresh__(true)
        self:__sync_cursor_to_uri__(target_uri)
      end)
    end
  end)
end

---@protected
---@return nil
function M:__action_copy_path__()
  local selected_nodes = self._tree:get_selected_nodes() ---@type dot.module.explorer.Node[]

  local filepaths = {} ---@type string[]
  if #selected_nodes > 0 then
    for _, node in ipairs(selected_nodes) do
      local filepath = node.uri:sub(8) ---@type string
      if filepath:sub(-1) == "/" then
        filepath = filepath:sub(1, -2)
      end
      filepaths[#filepaths + 1] = filepath
    end
  else
    local uri = self:get_cursor_uri() ---@type string|nil
    if uri == nil then
      return
    end
    local filepath = uri:sub(8) ---@type string
    if filepath:sub(-1) == "/" then
      filepath = filepath:sub(1, -2)
    end
    filepaths[#filepaths + 1] = filepath
  end

  dot.fn.select_copy_filepaths({
    filepaths = filepaths,
    winopts = {
      relative = "cursor",
      row = 1,
      col = 4,
    },
  })
end

---@protected
---@return nil
function M:__action_copy_visual__()
  local nodes = self:__get_visual_nodes__() ---@type dot.module.explorer.Node[]
  if #nodes == 0 then
    return
  end

  local current_mode = self._tree.select_mode ---@type dot.module.explorer.SelectModeEnum
  if current_mode ~= "copy" then
    for _, node in ipairs(nodes) do
      self._tree:toggle_selected(node.uri, "select")
    end
    self._tree.select_mode = "copy"
  else
    local has_unselected = false ---@type boolean
    for _, node in ipairs(nodes) do
      if not node:is_selected() then
        has_unselected = true
        break
      end
    end

    if has_unselected then
      for _, node in ipairs(nodes) do
        self._tree:toggle_selected(node.uri, "select")
      end
    else
      self._tree.state:advance_tick_selected()
      local tick = self._tree.state:next_tick_selected_even() ---@type integer
      for _, node in ipairs(nodes) do
        node:set_selected(tick)
      end
    end
  end
  self:__refresh__()
end

---@protected
---@return nil
function M:__action_create_directory__()
  local cursor_uri = self:get_cursor_uri() ---@type string|nil
  if cursor_uri == nil then
    return
  end

  local parent_uri = cursor_uri:sub(-1) == "/" and cursor_uri or self:__get_parent_uri__(cursor_uri) ---@type string
  local root_uri = self._tree.state.o_root_uri:snapshot() ---@type string
  local relative_path = parent_uri:sub(#root_uri + 1) ---@type string

  vim.ui.input({ prompt = "Create directory: ", default = relative_path }, function(input)
    if input == nil or #vim.trim(input) == 0 then
      return
    end

    local dirname = vim.trim(input) ---@type string
    if dirname:sub(-1) ~= "/" then
      dirname = dirname .. "/"
    end

    local new_uri = root_uri .. dirname ---@type string
    local resource = self._resource_manager:create(new_uri) ---@type dot.module.explorer.resource.INode|nil
    if resource ~= nil then
      local new_parent_uri = self:__get_parent_uri__(new_uri) ---@type string
      self._tree:toggle_expanded(new_parent_uri, false, "expand")
      local parts = vim.split(dirname:sub(1, -2), "/", { plain = true }) ---@type string[]
      local intermediate_uri = root_uri ---@type string
      for _, part in ipairs(parts) do
        intermediate_uri = intermediate_uri .. part .. "/"
        self._tree:toggle_expanded(intermediate_uri, false, "expand")
      end
      self._tree:refresh(true)
      vim.schedule(function()
        self:__render__()
        self:__sync_cursor_to_uri__(new_uri)
      end)
    end
  end)
end

---@protected
---@return nil
function M:__action_create_file__()
  local cursor_uri = self:get_cursor_uri() ---@type string|nil
  if cursor_uri == nil then
    return
  end

  local parent_uri = cursor_uri:sub(-1) == "/" and cursor_uri or self:__get_parent_uri__(cursor_uri) ---@type string
  local root_uri = self._tree.state.o_root_uri:snapshot() ---@type string
  local relative_path = parent_uri:sub(#root_uri + 1) ---@type string

  vim.ui.input({ prompt = "Create file: ", default = relative_path }, function(input)
    if input == nil or #vim.trim(input) == 0 then
      return
    end

    local filename = vim.trim(input) ---@type string
    local new_uri = root_uri .. filename ---@type string
    local resource = self._resource_manager:create(new_uri) ---@type dot.module.explorer.resource.INode|nil
    if resource ~= nil then
      local new_parent_uri = self:__get_parent_uri__(new_uri) ---@type string
      self._tree:toggle_expanded(new_parent_uri, false, "expand")
      local parts = vim.split(filename, "/", { plain = true }) ---@type string[]
      if #parts > 1 then
        local intermediate_uri = root_uri ---@type string
        for i = 1, #parts - 1 do
          intermediate_uri = intermediate_uri .. parts[i] .. "/"
          self._tree:toggle_expanded(intermediate_uri, false, "expand")
        end
      end
      self._tree:refresh(true)
      vim.schedule(function()
        self:__render__()
        self:__sync_cursor_to_uri__(new_uri)
      end)
    end
  end)
end

---@protected
---@return nil
function M:__action_cut__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local selected_nodes = self._tree:get_selected_nodes() ---@type dot.module.explorer.Node[]
  if #selected_nodes > 0 then
    local current_mode = self._tree.select_mode ---@type dot.module.explorer.SelectModeEnum
    local is_selected = self._tree:is_selected(uri) ---@type boolean

    if current_mode == "cut" and is_selected then
      self._tree:toggle_selected(uri, "unselect")
    else
      self._tree:toggle_selected(uri, "select")
    end

    self._tree.select_mode = "cut"
    self:__refresh__()
    return
  end

  local filepath = uri:sub(8) ---@type string
  if filepath:sub(-1) == "/" then
    filepath = filepath:sub(1, -2)
  end

  vim.ui.input({ prompt = "Move to: ", default = filepath }, function(input)
    if input == nil or input == "" or input == filepath then
      return
    end

    local target_uri = "file://" .. input ---@type string
    local ok = self._resource_manager:move(uri, target_uri) ---@type boolean
    if ok then
      self._tree:remove(uri)
      self._tree:refresh(true)
      vim.schedule(function()
        self:__refresh__(true)
        self:__sync_cursor_to_uri__(target_uri)
      end)
    end
  end)
end

---@protected
---@return nil
function M:__action_cut_visual__()
  local nodes = self:__get_visual_nodes__() ---@type dot.module.explorer.Node[]
  if #nodes == 0 then
    return
  end

  local current_mode = self._tree.select_mode ---@type dot.module.explorer.SelectModeEnum
  if current_mode ~= "cut" then
    for _, node in ipairs(nodes) do
      self._tree:toggle_selected(node.uri, "select")
    end
    self._tree.select_mode = "cut"
  else
    local has_unselected = false ---@type boolean
    for _, node in ipairs(nodes) do
      if not node:is_selected() then
        has_unselected = true
        break
      end
    end

    if has_unselected then
      for _, node in ipairs(nodes) do
        self._tree:toggle_selected(node.uri, "select")
      end
    else
      self._tree.state:advance_tick_selected()
      local tick = self._tree.state:next_tick_selected_even() ---@type integer
      for _, node in ipairs(nodes) do
        node:set_selected(tick)
      end
    end
  end
  self:__refresh__()
end

---@protected
---@return nil
function M:__action_delete__()
  local selected_nodes = self._tree:get_selected_nodes() ---@type dot.module.explorer.Node[]

  if #selected_nodes > 0 then
    local names = {} ---@type string[]
    for _, node in ipairs(selected_nodes) do
      names[#names + 1] = node.nodename
    end

    local prompt ---@type string
    if #selected_nodes == 1 then
      prompt = string.format("Delete '%s'?", names[1])
    else
      prompt = string.format("Delete %d items? (%s)", #selected_nodes, table.concat(names, ", "))
    end

    vim.ui.input({ prompt = prompt, inputtype = "confirmation" }, function(input)
      if input == nil then
        return
      end

      local answer = vim.trim(input):lower() ---@type string
      if answer ~= "y" and answer ~= "yes" then
        return
      end

      local deleted_count = 0 ---@type integer
      for _, node in ipairs(selected_nodes) do
        local ok = self._tree:remove(node.uri) ---@type boolean
        if ok then
          deleted_count = deleted_count + 1
        end
      end

      if deleted_count > 0 then
        self._tree:clear_selection()
        vim.schedule(function()
          self:__refresh__()
        end)

        ark.reporter.info({
          from = self.fullname,
          subject = "delete",
          message = string.format("Deleted %d item(s)", deleted_count),
        })
      end
    end)
    return
  end

  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local is_directory = uri:sub(-1) == "/" ---@type boolean
  local name ---@type string
  if is_directory then
    local parts = vim.split(uri:sub(1, -2), "/") ---@type string[]
    name = parts[#parts]
  else
    name = vim.fn.fnamemodify(uri, ":t")
  end

  local prompt = string.format("Delete '%s'?", name) ---@type string
  vim.ui.input({ prompt = prompt, inputtype = "confirmation" }, function(input)
    if input == nil then
      return
    end

    local answer = vim.trim(input):lower() ---@type string
    if answer ~= "y" and answer ~= "yes" then
      return
    end

    local ok = self._tree:remove(uri) ---@type boolean
    if ok then
      vim.schedule(function()
        self:__refresh__()
      end)
    end
  end)
end

---@protected
---@return nil
function M:__action_delete_visual__()
  local nodes = self:__get_visual_nodes__() ---@type dot.module.explorer.Node[]
  if #nodes == 0 then
    return
  end

  local names = {} ---@type string[]
  for _, node in ipairs(nodes) do
    names[#names + 1] = node.nodename
  end

  local prompt ---@type string
  if #nodes == 1 then
    prompt = string.format("Delete '%s'?", names[1])
  else
    prompt = string.format("Delete %d items? (%s)", #nodes, table.concat(names, ", "))
  end

  vim.ui.input({ prompt = prompt, inputtype = "confirmation" }, function(input)
    if input == nil then
      return
    end

    local answer = vim.trim(input):lower() ---@type string
    if answer ~= "y" and answer ~= "yes" then
      return
    end

    local deleted_count = 0 ---@type integer
    for _, node in ipairs(nodes) do
      local ok = self._tree:remove(node.uri) ---@type boolean
      if ok then
        deleted_count = deleted_count + 1
      end
    end

    if deleted_count > 0 then
      vim.schedule(function()
        self:__refresh__()
      end)

      ark.reporter.info({
        from = self.fullname,
        subject = "delete",
        message = string.format("Deleted %d item(s)", deleted_count),
      })
    end
  end)
end

---@protected
---@return nil
function M:__action_go_home__()
  local workspace = dot.path.workspace() ---@type string
  local root_uri = "file://" .. workspace .. "/" ---@type string
  self:set_root(root_uri)
end

---@protected
---@return nil
function M:__action_go_parent__()
  local root_uri = self._tree.state.o_root_uri:snapshot() ---@type string
  local parent_uri = self:__get_parent_uri__(root_uri) ---@type string

  if parent_uri ~= root_uri then
    self:set_root(parent_uri)
  end
end

---@protected
---@return nil
function M:__action_go_prev__()
  local prev_root_uri = self._tree.state.prev_root_uri ---@type string|nil
  if prev_root_uri == nil then
    return
  end
  self:set_root(prev_root_uri)
end

---@protected
---@return nil
function M:__action_go_cwd__()
  local cwd = dot.path.cwd() ---@type string
  local root_uri = "file://" .. cwd .. "/" ---@type string
  self:set_root(root_uri)
end

---@protected
---@return nil
function M:__action_jump_last_child__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  if uri:sub(-1) ~= "/" then
    return
  end

  local node = self._tree:locate(uri) ---@type dot.module.explorer.Node|nil
  if node == nil or not node:is_expanded() or #node.children == 0 then
    return
  end

  local last_child = node.children[#node.children] ---@type dot.module.explorer.Node
  local target_uri = last_child.uri ---@type string
  self._tree.state.o_cursor_uri:next(target_uri)
  self:__sync_cursor_to_uri__(target_uri)
end

---@protected
---@return nil
function M:__action_jump_parent__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local parent_uri = self:__get_parent_uri__(uri) ---@type string
  local root_uri = self._tree.state.o_root_uri:snapshot() ---@type string

  if parent_uri ~= uri and vim.startswith(parent_uri, root_uri) then
    self._tree.state.o_cursor_uri:next(parent_uri)
    self:__sync_cursor_to_uri__(parent_uri)
  end
end

---@protected
---@return nil
function M:__action_mark__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  self._tree:toggle_selected(uri, nil)
  self._tree.select_mode = "select"
  self:__refresh__()
end

---@protected
---@return nil
function M:__action_mark_visual__()
  local nodes = self:__get_visual_nodes__() ---@type dot.module.explorer.Node[]
  if #nodes == 0 then
    return
  end

  local has_unselected = false ---@type boolean
  for _, node in ipairs(nodes) do
    if not node:is_selected() then
      has_unselected = true
      break
    end
  end

  if has_unselected then
    for _, node in ipairs(nodes) do
      self._tree:toggle_selected(node.uri, "select")
    end
  else
    self._tree.state:advance_tick_selected()
    local tick = self._tree.state:next_tick_selected_even() ---@type integer
    for _, node in ipairs(nodes) do
      node:set_selected(tick)
    end
  end
  self:__refresh__()
end

---@protected
---@return nil
function M:__action_open_selected__()
  local selected_nodes = self._tree:get_selected_nodes() ---@type dot.module.explorer.Node[]
  if #selected_nodes == 0 then
    ark.reporter.warn({
      from = self.fullname,
      subject = "open selected",
      message = "No files selected",
    })
    return
  end

  local file_nodes = {} ---@type dot.module.explorer.Node[]
  for _, node in ipairs(selected_nodes) do
    if node.nodetype == "F" then
      file_nodes[#file_nodes + 1] = node
    end
  end

  if #file_nodes == 0 then
    ark.reporter.warn({
      from = self.fullname,
      subject = "open selected",
      message = "No files in selection (only directories)",
    })
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
    vim.api.nvim_set_current_win(winnr_sourcefile)
  end

  for _, node in ipairs(file_nodes) do
    local filepath = node.uri:sub(8) ---@type string
    dot.win.open_filepath(winnr_sourcefile, filepath)
  end

  self._tree:clear_selection()
  vim.schedule(function()
    self:__render__()
  end)

  ark.reporter.info({
    from = self.fullname,
    subject = "open selected",
    message = string.format("Opened %d file(s)", #file_nodes),
  })
end

---@protected
---@return nil
function M:__action_delete_selected__()
  local selected_nodes = self._tree:get_selected_nodes_toplevel() ---@type dot.module.explorer.Node[]
  if #selected_nodes == 0 then
    ark.reporter.warn({
      from = self.fullname,
      subject = "delete selected",
      message = "No files selected",
    })
    return
  end

  local cwd = dot.path.cwd() ---@type string

  ---@type string[]
  local preview_lines = {}
  for _, node in ipairs(selected_nodes) do
    local filepath = node.uri:sub(8) ---@type string
    if filepath:sub(-1) == "/" then
      filepath = filepath:sub(1, -2)
    end
    local relative_path = dot.path.relative(cwd, filepath) ---@type string
    preview_lines[#preview_lines + 1] = relative_path
  end

  local fullname = self.fullname ---@type string

  ---@type dot.module.board.Act
  local act = dot.board.Act.new({
    name = "explorer_delete",
    title = string.format("%s Delete %d item(s)", ark.icon.diagnostic.Warning, #selected_nodes),
    initial_input = "y",
    preview_lines = #preview_lines,
    render_preview = function(bufnr, _)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, preview_lines)
    end,
    on_confirm = function(input)
      local answer = vim.trim(input):lower() ---@type string
      if answer ~= "y" and answer ~= "yes" then
        return
      end

      local deleted_count = 0 ---@type integer
      for _, node in ipairs(selected_nodes) do
        local ok = self._tree:remove(node.uri) ---@type boolean
        if ok then
          deleted_count = deleted_count + 1
        end
      end

      if deleted_count > 0 then
        self._tree:clear_selection()
        vim.schedule(function()
          self:__refresh__()
        end)

        ark.reporter.info({
          from = fullname,
          subject = "delete",
          message = string.format("Deleted %d item(s)", deleted_count),
        })
      end
    end,
  })
  act:open()
end

---@protected
---@return nil
function M:__action_move_selected__()
  local selected_nodes = self._tree:get_selected_nodes_toplevel() ---@type dot.module.explorer.Node[]
  if #selected_nodes == 0 then
    ark.reporter.warn({
      from = self.fullname,
      subject = "move selected",
      message = "No files selected",
    })
    return
  end

  local common_ancestor = self._tree:get_common_ancestor_path(selected_nodes) ---@type string|nil
  if common_ancestor == nil then
    return
  end

  local cwd = dot.path.cwd() ---@type string
  local default_target = dot.path.relative(cwd, common_ancestor) ---@type string
  local ns = vim.api.nvim_create_namespace("explorer_move_preview") ---@type integer

  ---@class dot.module.explorer.widget.IPreviewItem
  ---@field public from                    string
  ---@field public to                      string
  ---@field public relative_part           string

  ---@return integer
  local function calc_content_width()
    local max_width = 0 ---@type integer
    for _, node in ipairs(selected_nodes) do
      local filepath = node.uri:sub(8) ---@type string
      if filepath:sub(-1) == "/" then
        filepath = filepath:sub(1, -2)
      end
      local from_relative = dot.path.relative(cwd, filepath) ---@type string
      local line_width = vim.fn.strdisplaywidth(from_relative) * 2 + 4 ---@type integer
      max_width = math.max(max_width, line_width)
    end
    return max_width + 4
  end

  ---@param target_dir string
  ---@return dot.module.explorer.widget.IPreviewItem[]
  ---@return integer
  local function build_preview_items(target_dir)
    local items = {} ---@type dot.module.explorer.widget.IPreviewItem[]
    local max_from_len = 0 ---@type integer

    for _, node in ipairs(selected_nodes) do
      local filepath = node.uri:sub(8) ---@type string
      if filepath:sub(-1) == "/" then
        filepath = filepath:sub(1, -2)
      end
      local relative_part = dot.path.relative(common_ancestor, filepath) ---@type string
      local from_relative = dot.path.relative(cwd, filepath) ---@type string
      local target_path = target_dir .. (target_dir:sub(-1) == "/" and "" or "/") .. relative_part ---@type string
      local to_relative = dot.path.relative(cwd, target_path) ---@type string
      items[#items + 1] = { from = from_relative, to = to_relative, relative_part = relative_part }
      max_from_len = math.max(max_from_len, vim.fn.strdisplaywidth(from_relative))
    end

    return items, max_from_len
  end

  local fullname = self.fullname ---@type string

  ---@type dot.module.board.Act
  local act = dot.board.Act.new({
    name = "explorer_move",
    title = string.format("%s Move %d item(s)", ark.icon.symbols.selection_cut, #selected_nodes),
    initial_input = default_target,
    preview_lines = #selected_nodes,
    get_width = calc_content_width,
    render_preview = function(bufnr, input)
      local target_dir = vim.trim(input) ---@type string
      if target_dir == "" then
        target_dir = default_target
      end
      if not vim.startswith(target_dir, "/") then
        target_dir = cwd .. "/" .. target_dir
      end
      target_dir = dot.path.normalize(target_dir)

      local items, max_from_len = build_preview_items(target_dir)

      local lines = {} ---@type string[]
      for _, item in ipairs(items) do
        local padding = string.rep(" ", max_from_len - vim.fn.strdisplaywidth(item.from)) ---@type string
        lines[#lines + 1] = string.format("%s%s -> %s", item.from, padding, item.to)
      end

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

      for lnum, item in ipairs(items) do
        local padding = string.rep(" ", max_from_len - vim.fn.strdisplaywidth(item.from)) ---@type string
        local from_hl_start = #item.from - #item.relative_part ---@type integer
        local from_hl_end = #item.from ---@type integer
        local to_hl_start = #item.from + #padding + 4 + #item.to - #item.relative_part ---@type integer
        local to_hl_end = #item.from + #padding + 4 + #item.to ---@type integer
        vim.hl.range(bufnr, ns, "f_pk_matches", { lnum - 1, from_hl_start }, { lnum - 1, from_hl_end })
        vim.hl.range(bufnr, ns, "f_pk_matches", { lnum - 1, to_hl_start }, { lnum - 1, to_hl_end })
      end
    end,
    on_confirm = function(input)
      if input == "" then
        return
      end

      local target_dir = input ---@type string
      if not vim.startswith(target_dir, "/") then
        target_dir = cwd .. "/" .. target_dir
      end
      target_dir = dot.path.normalize(target_dir)
      if target_dir:sub(-1) ~= "/" then
        target_dir = target_dir .. "/"
      end

      local moved_count = 0 ---@type integer
      local failed_count = 0 ---@type integer

      for _, node in ipairs(selected_nodes) do
        local filepath = node.uri:sub(8) ---@type string
        if filepath:sub(-1) == "/" then
          filepath = filepath:sub(1, -2)
        end

        local relative_path = dot.path.relative(common_ancestor, filepath) ---@type string
        local target_path = target_dir .. relative_path ---@type string
        local target_uri = "file://" .. target_path ---@type string

        local ok = self._resource_manager:move(node.uri, target_uri) ---@type boolean
        if ok then
          self._tree:remove(node.uri)
          moved_count = moved_count + 1
        else
          failed_count = failed_count + 1
        end
      end

      if moved_count > 0 then
        self._tree:clear_selection()
        self._tree:refresh(true)
        vim.schedule(function()
          self:__refresh__(true)
        end)

        if failed_count > 0 then
          ark.reporter.warn({
            from = fullname,
            subject = "move",
            message = string.format("Moved %d item(s), %d failed", moved_count, failed_count),
          })
        else
          ark.reporter.info({
            from = fullname,
            subject = "move",
            message = string.format("Moved %d item(s)", moved_count),
          })
        end
      elseif failed_count > 0 then
        ark.reporter.error({
          from = fullname,
          subject = "move",
          message = string.format("Failed to move %d item(s)", failed_count),
        })
      end
    end,
  })
  act:open()
end

---@protected
---@return nil
function M:__action_copy_selected__()
  local selected_nodes = self._tree:get_selected_nodes_toplevel() ---@type dot.module.explorer.Node[]
  if #selected_nodes == 0 then
    ark.reporter.warn({
      from = self.fullname,
      subject = "copy selected",
      message = "No files selected",
    })
    return
  end

  local common_ancestor = self._tree:get_common_ancestor_path(selected_nodes) ---@type string|nil
  if common_ancestor == nil then
    return
  end

  local cwd = dot.path.cwd() ---@type string
  local default_target = dot.path.relative(cwd, common_ancestor) ---@type string
  local ns = vim.api.nvim_create_namespace("explorer_copy_preview") ---@type integer

  ---@return integer
  local function calc_content_width()
    local max_width = 0 ---@type integer
    for _, node in ipairs(selected_nodes) do
      local filepath = node.uri:sub(8) ---@type string
      if filepath:sub(-1) == "/" then
        filepath = filepath:sub(1, -2)
      end
      local from_relative = dot.path.relative(cwd, filepath) ---@type string
      local line_width = vim.fn.strdisplaywidth(from_relative) * 2 + 4 ---@type integer
      max_width = math.max(max_width, line_width)
    end
    return max_width + 4
  end

  ---@param target_dir string
  ---@return dot.module.explorer.widget.IPreviewItem[]
  ---@return integer
  local function build_preview_items(target_dir)
    local items = {} ---@type dot.module.explorer.widget.IPreviewItem[]
    local max_from_len = 0 ---@type integer

    for _, node in ipairs(selected_nodes) do
      local filepath = node.uri:sub(8) ---@type string
      if filepath:sub(-1) == "/" then
        filepath = filepath:sub(1, -2)
      end
      local relative_part = dot.path.relative(common_ancestor, filepath) ---@type string
      local from_relative = dot.path.relative(cwd, filepath) ---@type string
      local target_path = target_dir .. (target_dir:sub(-1) == "/" and "" or "/") .. relative_part ---@type string
      local to_relative = dot.path.relative(cwd, target_path) ---@type string
      items[#items + 1] = { from = from_relative, to = to_relative, relative_part = relative_part }
      max_from_len = math.max(max_from_len, vim.fn.strdisplaywidth(from_relative))
    end

    return items, max_from_len
  end

  local fullname = self.fullname ---@type string

  ---@type dot.module.board.Act
  local act = dot.board.Act.new({
    name = "explorer_copy",
    title = string.format("%s Copy %d item(s)", ark.icon.symbols.selection_copy, #selected_nodes),
    initial_input = default_target,
    preview_lines = #selected_nodes,
    get_width = calc_content_width,
    render_preview = function(bufnr, input)
      local target_dir = vim.trim(input) ---@type string
      if target_dir == "" then
        target_dir = default_target
      end
      if not vim.startswith(target_dir, "/") then
        target_dir = cwd .. "/" .. target_dir
      end
      target_dir = dot.path.normalize(target_dir)

      local items, max_from_len = build_preview_items(target_dir)

      local lines = {} ---@type string[]
      for _, item in ipairs(items) do
        local padding = string.rep(" ", max_from_len - vim.fn.strdisplaywidth(item.from)) ---@type string
        lines[#lines + 1] = string.format("%s%s +> %s", item.from, padding, item.to)
      end

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

      for lnum, item in ipairs(items) do
        local padding = string.rep(" ", max_from_len - vim.fn.strdisplaywidth(item.from)) ---@type string
        local from_hl_start = #item.from - #item.relative_part ---@type integer
        local from_hl_end = #item.from ---@type integer
        local to_hl_start = #item.from + #padding + 4 + #item.to - #item.relative_part ---@type integer
        local to_hl_end = #item.from + #padding + 4 + #item.to ---@type integer
        vim.hl.range(bufnr, ns, "f_pk_matches", { lnum - 1, from_hl_start }, { lnum - 1, from_hl_end })
        vim.hl.range(bufnr, ns, "f_pk_matches", { lnum - 1, to_hl_start }, { lnum - 1, to_hl_end })
      end
    end,
    on_confirm = function(input)
      if input == "" then
        return
      end

      local target_dir = input ---@type string
      if not vim.startswith(target_dir, "/") then
        target_dir = cwd .. "/" .. target_dir
      end
      target_dir = dot.path.normalize(target_dir)
      if target_dir:sub(-1) ~= "/" then
        target_dir = target_dir .. "/"
      end

      local copied_count = 0 ---@type integer
      local failed_count = 0 ---@type integer

      for _, node in ipairs(selected_nodes) do
        local filepath = node.uri:sub(8) ---@type string
        if filepath:sub(-1) == "/" then
          filepath = filepath:sub(1, -2)
        end

        local relative_path = dot.path.relative(common_ancestor, filepath) ---@type string
        local target_path = target_dir .. relative_path ---@type string
        local target_uri = "file://" .. target_path ---@type string

        local ok = self._resource_manager:copy(node.uri, target_uri) ---@type boolean
        if ok then
          copied_count = copied_count + 1
        else
          failed_count = failed_count + 1
        end
      end

      if copied_count > 0 then
        self._tree:clear_selection()
        self._tree:refresh(true)
        vim.schedule(function()
          self:__refresh__(true)
        end)

        if failed_count > 0 then
          ark.reporter.warn({
            from = fullname,
            subject = "copy",
            message = string.format("Copied %d item(s), %d failed", copied_count, failed_count),
          })
        else
          ark.reporter.info({
            from = fullname,
            subject = "copy",
            message = string.format("Copied %d item(s)", copied_count),
          })
        end
      elseif failed_count > 0 then
        ark.reporter.error({
          from = fullname,
          subject = "copy",
          message = string.format("Failed to copy %d item(s)", failed_count),
        })
      end
    end,
  })
  act:open()
end

---@protected
---@return nil
function M:__action_open_file_explorer__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local filepath = uri:sub(8) ---@type string
  if filepath:sub(-1) == "/" then
    filepath = filepath:sub(1, -2)
  end
  dot.fn.find_explorer(filepath)
end

---@protected
---@return nil
function M:__action_open_file_finder__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local dirpath ---@type string
  if uri:sub(-1) == "/" then
    dirpath = uri:sub(8, -2)
  else
    dirpath = dot.path.dirname(uri:sub(8))
  end

  dot.fn.find_files(dirpath, true)
end

---@protected
---@return nil
function M:__action_open_searcher__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local filepath = uri:sub(8) ---@type string
  if filepath:sub(-1) == "/" then
    filepath = filepath:sub(1, -2)
  end
  dot.fn.search_in_files(filepath)
end

---@protected
---@return nil
function M:__action_open_system_explorer__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local filepath = uri:sub(8) ---@type string
  if filepath:sub(-1) == "/" then
    filepath = filepath:sub(1, -2)
  end

  vim.ui.open(filepath)
end

---@protected
---@return nil
function M:__action_open__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  if uri:sub(-1) == "/" then
    self._tree:toggle_expanded(uri, false, nil)
    self:__refresh__()
  else
    local filepath = uri:sub(8) ---@type string
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
    if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
      vim.api.nvim_set_current_win(winnr_sourcefile)
    end
    dot.win.open_filepath(winnr_sourcefile, filepath)
  end
end

---@protected
---@return nil
function M:__action_open_split__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil or uri:sub(-1) == "/" then
    return
  end

  local filepath = uri:sub(8) ---@type string
  vim.cmd("split " .. vim.fn.fnameescape(filepath))
end

---@protected
---@return nil
function M:__action_open_tab__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil or uri:sub(-1) == "/" then
    return
  end

  local filepath = uri:sub(8) ---@type string
  vim.cmd("tabnew " .. vim.fn.fnameescape(filepath))
end

---@protected
---@return nil
function M:__action_open_vsplit__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil or uri:sub(-1) == "/" then
    return
  end

  local filepath = uri:sub(8) ---@type string
  vim.cmd("vsplit " .. vim.fn.fnameescape(filepath))
end

---@protected
---@return nil
function M:__action_paste__()
  local select_mode = self._tree.select_mode ---@type dot.module.explorer.SelectModeEnum

  if select_mode == "select" then
    ark.reporter.warn({
      from = self.fullname,
      subject = "paste",
      message = "No cut/copy operation pending",
    })
    return
  end

  local selected_nodes = self._tree:get_selected_nodes_toplevel() ---@type dot.module.explorer.Node[]
  if #selected_nodes > 1 then
    if select_mode == "cut" then
      self:__action_move_selected__()
    else
      self:__action_copy_selected__()
    end
    return
  end

  local cursor_uri = self:get_cursor_uri() ---@type string|nil
  if cursor_uri == nil then
    return
  end

  local target_uri = cursor_uri:sub(-1) == "/" and cursor_uri or self:__get_parent_uri__(cursor_uri) ---@type string

  local ok ---@type boolean

  if select_mode == "cut" then
    ok = self._tree:apply_cut_paste(target_uri)
  else
    ok = self._tree:apply_copy_paste(target_uri)
  end

  if ok then
    self._tree.select_mode = "select"
    self._tree:refresh(true)
    self:__refresh__(true)

    ark.reporter.info({
      from = self.fullname,
      subject = "paste",
      message = select_mode == "cut" and "Moved successfully" or "Copied successfully",
    })
  end
end

---@protected
---@return nil
function M:__action_pick_win_open__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil or uri:sub(-1) == "/" then
    return
  end

  local filepath = uri:sub(8) ---@type string
  local winnr = dot.win.pick_sourcefile(self._winnr) ---@type integer|nil
  if winnr == nil then
    return
  end

  dot.win.open_filepath(winnr, filepath)
  vim.api.nvim_set_current_win(winnr)
end

---@protected
---@return nil
function M:__action_pick_win_split__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil or uri:sub(-1) == "/" then
    return
  end

  local filepath = uri:sub(8) ---@type string
  local winnr = dot.win.pick_sourcefile(self._winnr) ---@type integer|nil
  if winnr == nil then
    return
  end

  vim.api.nvim_set_current_win(winnr)
  vim.cmd("split " .. vim.fn.fnameescape(filepath))
end

---@protected
---@return nil
function M:__action_pick_win_vsplit__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil or uri:sub(-1) == "/" then
    return
  end

  local filepath = uri:sub(8) ---@type string
  local winnr = dot.win.pick_sourcefile(self._winnr) ---@type integer|nil
  if winnr == nil then
    return
  end

  vim.api.nvim_set_current_win(winnr)
  vim.cmd("vsplit " .. vim.fn.fnameescape(filepath))
end

---@protected
---@return nil
function M:__action_rename__()
  local selected_nodes = self._tree:get_selected_nodes() ---@type dot.module.explorer.Node[]

  if #selected_nodes > 1 then
    ark.reporter.warn({
      from = self.fullname,
      subject = "rename",
      message = "Cannot rename multiple files at once. Please select only one file.",
    })
    return
  end

  local uri ---@type string|nil
  if #selected_nodes == 1 then
    uri = selected_nodes[1].uri
  else
    uri = self:get_cursor_uri()
  end

  if uri == nil then
    return
  end

  local root_uri = self._tree.state.o_root_uri:snapshot() ---@type string
  local is_directory = uri:sub(-1) == "/" ---@type boolean
  local relative_path = uri:sub(#root_uri + 1) ---@type string
  if is_directory and relative_path:sub(-1) == "/" then
    relative_path = relative_path:sub(1, -2)
  end

  vim.ui.input({ prompt = "Rename to: ", default = relative_path }, function(input)
    if input == nil or #vim.trim(input) == 0 then
      return
    end

    local new_relative_path = vim.trim(input) ---@type string
    if new_relative_path == relative_path then
      return
    end

    local new_uri = root_uri .. new_relative_path .. (is_directory and "/" or "") ---@type string

    local old_filepath = uri:sub(8) ---@type string
    local new_filepath = new_uri:sub(8) ---@type string
    if old_filepath:sub(-1) == "/" then
      old_filepath = old_filepath:sub(1, -2)
    end
    if new_filepath:sub(-1) == "/" then
      new_filepath = new_filepath:sub(1, -2)
    end

    dot.lsp.on_rename(old_filepath, new_filepath, function()
      local ok = self._resource_manager:move(uri, new_uri) ---@type boolean
      if ok then
        dot.lsp.rename_buf(old_filepath, new_filepath)
        if #selected_nodes == 1 then
          self._tree:clear_selection()
        end
        self._tree:refresh(true)
        vim.schedule(function()
          self:__refresh__(true)
        end)
        ark.reporter.info({
          from = self.fullname,
          subject = "rename",
          message = string.format("Renamed to: %s", new_relative_path),
        })
      end
    end)
  end)
end

---@protected
---@return nil
function M:__action_select_toggle__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  self._tree:toggle_selected(uri, nil)
  self._tree.select_mode = "select"
  self:__refresh__()
end

---@protected
---@return nil
function M:__action_send_to_quickfix__()
  local root = self._tree:get_root_node() ---@type dot.module.explorer.Node
  local selected_nodes = require("dot.module.explorer.node").collect_selected(root) ---@type dot.module.explorer.Node[]

  if #selected_nodes == 0 then
    local uri = self:get_cursor_uri() ---@type string|nil
    if uri == nil then
      return
    end
    local filepath = uri:sub(8) ---@type string
    if filepath:sub(-1) == "/" then
      filepath = filepath:sub(1, -2)
    end
    vim.fn.setqflist({}, "r", {
      title = "Explorer",
      items = { { filename = filepath, lnum = 1, col = 1 } },
    })
  else
    local items = {} ---@type table[]
    for _, node in ipairs(selected_nodes) do
      local filepath = node.uri:sub(8) ---@type string
      if filepath:sub(-1) == "/" then
        filepath = filepath:sub(1, -2)
      end
      items[#items + 1] = { filename = filepath, lnum = 1, col = 1 }
    end
    vim.fn.setqflist({}, "r", {
      title = "Explorer Selection",
      items = items,
    })
  end

  vim.cmd("copen")

  ark.reporter.info({
    from = self.fullname,
    subject = "quickfix",
    message = "Sent to quickfix list",
  })
end

---@protected
---@return nil
function M:__action_show_file_info__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local filepath = uri:sub(8) ---@type string
  if filepath:sub(-1) == "/" then
    filepath = filepath:sub(1, -2)
  end

  local fileinfo = dot.board.Fileinfo.new({ filepath = filepath })
  fileinfo:open()
end

---@protected
---@return nil
function M:__action_set_root__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  if uri:sub(-1) ~= "/" then
    uri = self:__get_parent_uri__(uri)
  end

  self:set_root(uri)
end

---@protected
---@return nil
function M:__action_show_keysheet__()
  local keysheet = dot.board.Keysheet.new({
    title = "Explorer Help",
    keymaps = self._keymaps,
  })
  keysheet:open()
end

---@protected
---@return nil
function M:__action_toggle_recursive__()
  local uri = self:get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  if uri:sub(-1) ~= "/" then
    return
  end

  self._tree:toggle_expanded(uri, true, nil)
  self:__refresh__()
end

---@protected
---@param direction                     "prev"|"next"
---@return nil
function M:__action_goto_diagnostic__(direction)
  self:__goto_matching_file__(direction, function(filepath)
    local bufnr = vim.fn.bufnr(filepath) ---@type integer
    if bufnr < 0 then
      return false
    end
    local diagnostics = vim.diagnostic.get(bufnr) ---@type vim.Diagnostic[]
    return #diagnostics > 0
  end)
end

---@protected
---@param direction                     "prev"|"next"
---@return nil
function M:__action_goto_diagnostic_error__(direction)
  self:__goto_matching_file__(direction, function(filepath)
    local bufnr = vim.fn.bufnr(filepath) ---@type integer
    if bufnr < 0 then
      return false
    end
    local diagnostics = vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR }) ---@type vim.Diagnostic[]
    return #diagnostics > 0
  end)
end

---@protected
---@param direction                     "prev"|"next"
---@return nil
function M:__action_goto_diagnostic_warning__(direction)
  self:__goto_matching_file__(direction, function(filepath)
    local bufnr = vim.fn.bufnr(filepath) ---@type integer
    if bufnr < 0 then
      return false
    end
    local diagnostics = vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.WARN }) ---@type vim.Diagnostic[]
    return #diagnostics > 0
  end)
end

---@protected
---@param direction                     "prev"|"next"
---@return nil
function M:__action_goto_git_changed__(direction)
  local aggregated = dot.git.state.aggregated() ---@type dot.module.git.status.IAggregatedCache
  local staged_files = aggregated.staged_files ---@type string[]
  local unstaged_files = aggregated.unstaged_files ---@type string[]

  if #staged_files == 0 and #unstaged_files == 0 then
    ark.reporter.info({
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
    ark.reporter.info({
      from = self.fullname,
      subject = "goto git changed",
      message = "No git changed files in current view",
    })
  end
end

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
---@return dot.module.nvimbar.Nvimbar
function M:__create_nvimbar__()
  local c = require("dot.module.nvimbar").component
  local Nvimbar = require("dot.module.nvimbar").Nvimbar
  local position = "f_wl" ---@type dot.module.nvimbar.PositionEnum

  local flags = self:__get_flags__() ---@type dot.module.explorer.widget.IFlagItem[]
  ---@type dot.module.nvimbar.component.explorer.IFlagItem[]
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

  ---@type dot.module.nvimbar.Nvimbar
  local nvimbar = Nvimbar.new({
    name = string.format("%s#winbar", self.fullname),
    comp_sep = "",
    comp_sep_hlname = "f_explorer_winbar",
    comp_sep_hlname_active = "f_explorer_winbar",
    delay = 128,
    silent = ark.fn.falsy,
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
  }):place("left", c.explorer.winbar(self._tree.state.o_root_uri, position, nvimbar_flags, get_width), 100)

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

  winnr = vim.api.nvim_open_win(bufnr, true, {
    split = "left",
    width = self:__get_effective_width__(),
  })
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

  dot.win.set_type(winnr, dot.win.Types.EXPLORER)

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
        self._tree.state.o_cursor_uri:next(uri)
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
  return math.min(self._width, columns)
end

---@protected
---@return dot.module.explorer.widget.IFlagItem[]
function M:__get_flags__()
  local state = self._tree.state ---@type dot.module.explorer.State

  ---@type dot.module.explorer.widget.IFlagItem[]
  local flags = {}

  for _, flag in ipairs(self._flags) do
    flags[#flags + 1] = flag
  end

  flags[#flags + 1] = {
    desc = "explorer: toggle hidden files",
    callback = function()
      state.o_flag_hidden:next(not state.o_flag_hidden:snapshot())
    end,
    snapshot = function()
      local show_hidden = state.o_flag_hidden:snapshot() ---@type boolean
      return ark.icon.symbols.flag_hidden, show_hidden and "picker_flag_blue" or "picker_flag_grey"
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
---@return dot.module.explorer.Node[]
function M:__get_visual_nodes__()
  local render_result = self._render_result ---@type dot.module.explorer.view.IRenderResult|nil
  if render_result == nil then
    return {}
  end

  local start_lnum, end_lnum = dot.buf.retrieve_visual_lnum_range() ---@type integer, integer

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)

  local nodes = {} ---@type dot.module.explorer.Node[]
  for lnum = start_lnum, end_lnum do
    local uri = render_result.lnum_to_uri[lnum] ---@type string|nil
    if uri ~= nil then
      local node = self._tree:locate(uri) ---@type dot.module.explorer.Node|nil
      if node ~= nil then
        nodes[#nodes + 1] = node
      end
    end
  end

  return nodes
end

---@protected
---@param skip_refresh                  ?boolean
---@return nil
function M:__refresh__(skip_refresh)
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local root_uri = self._tree.state.o_root_uri:snapshot() ---@type string
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

  local root_node = self._tree:get_root_node() ---@type dot.module.explorer.Node

  local render_result = self._view:render(bufnr, self._tree, root_node, {
    resource_manager = self._resource_manager,
    foldempty = self._tree.state.o_flag_foldempty:snapshot(),
    only_selected = dot.context.explorer.flag_selected:snapshot(),
    show_git_status = true,
    show_icons = true,
    select_mode = self._tree.select_mode,
  })
  self._render_result = render_result

  local cursor_uri = self._tree.state.o_cursor_uri:snapshot() ---@type string
  self:__sync_cursor_to_uri__(cursor_uri)
  self:__update_winbar__()
  self:__update_cursorline__()
end

---@protected
---@param bufnr                         integer
---@return nil
function M:__setup_keymaps__(bufnr)
  local widget_keymaps = dot.state.widget.get_keymaps(self) ---@type ark.t.IKeymap[]

  ---@type ark.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "<2-LeftMouse>",
      callback = function()
        self:__action_open__()
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
        self:__action_send_to_quickfix__()
      end,
      desc = "explorer: send selection to quickfix",
    },
    {
      modes = { "n" },
      key = "<C-t>",
      callback = function()
        self:__action_open_tab__()
      end,
      desc = "explorer: open in tab",
    },
    {
      modes = { "n" },
      key = "<C-v>",
      callback = function()
        self:__action_open_vsplit__()
      end,
      desc = "explorer: open in vsplit",
    },
    {
      modes = { "n" },
      key = "<C-x>",
      callback = function()
        self:__action_open_split__()
      end,
      desc = "explorer: open in split",
    },
    -- Special keys
    {
      modes = { "n" },
      key = "<BS>",
      callback = function()
        self:__action_go_parent__()
      end,
      desc = "explorer: go to parent directory",
    },
    {
      modes = { "n" },
      key = "<CR>",
      callback = function()
        self:__action_open__()
      end,
      desc = "explorer: open/toggle",
    },
    {
      modes = { "n" },
      key = "<Tab>",
      callback = function()
        self:__action_select_toggle__()
      end,
      desc = "explorer: toggle selection",
    },
    -- Symbols
    {
      modes = { "n" },
      key = ".",
      callback = function()
        self:__action_set_root__()
      end,
      desc = "explorer: set as root",
    },
    {
      modes = { "n" },
      key = "?",
      callback = function()
        self:__action_show_keysheet__()
      end,
      desc = "explorer: show keymap help",
    },
    {
      modes = { "n" },
      key = "[d",
      callback = function()
        self:__action_goto_diagnostic__("prev")
      end,
      desc = "explorer: go to prev diagnostic file",
    },
    {
      modes = { "n" },
      key = "[e",
      callback = function()
        self:__action_goto_diagnostic_error__("prev")
      end,
      desc = "explorer: go to prev diagnostic error file",
    },
    {
      modes = { "n" },
      key = "[h",
      callback = function()
        self:__action_goto_git_changed__("prev")
      end,
      desc = "explorer: go to prev git changed file",
    },
    {
      modes = { "n" },
      key = "[i",
      callback = function()
        self:__action_jump_parent__()
      end,
      desc = "explorer: jump to parent line",
    },
    {
      modes = { "n" },
      key = "[w",
      callback = function()
        self:__action_goto_diagnostic_warning__("prev")
      end,
      desc = "explorer: go to prev diagnostic warning file",
    },
    {
      modes = { "n" },
      key = "]d",
      callback = function()
        self:__action_goto_diagnostic__("next")
      end,
      desc = "explorer: go to next diagnostic file",
    },
    {
      modes = { "n" },
      key = "]e",
      callback = function()
        self:__action_goto_diagnostic_error__("next")
      end,
      desc = "explorer: go to next diagnostic error file",
    },
    {
      modes = { "n" },
      key = "]h",
      callback = function()
        self:__action_goto_git_changed__("next")
      end,
      desc = "explorer: go to next git changed file",
    },
    {
      modes = { "n" },
      key = "]i",
      callback = function()
        self:__action_jump_last_child__()
      end,
      desc = "explorer: jump to last child",
    },
    {
      modes = { "n" },
      key = "]w",
      callback = function()
        self:__action_goto_diagnostic_warning__("next")
      end,
      desc = "explorer: go to next diagnostic warning file",
    },
    -- Uppercase letters
    {
      modes = { "n" },
      key = "A",
      callback = function()
        self:__action_create_directory__()
      end,
      desc = "explorer: create directory",
    },
    {
      modes = { "n" },
      key = "H",
      callback = function()
        self._tree.state.o_flag_hidden:next(not self._tree.state.o_flag_hidden:snapshot())
      end,
      desc = "explorer: toggle hidden files",
    },
    {
      modes = { "n" },
      key = "J",
      callback = function()
        self:__action_pick_win_split__()
      end,
      desc = "explorer: pick window and split",
    },
    {
      modes = { "n" },
      key = "L",
      callback = function()
        self:__action_pick_win_vsplit__()
      end,
      desc = "explorer: pick window and vsplit",
    },
    {
      modes = { "n" },
      key = "O",
      callback = function()
        self:__action_open_system_explorer__()
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
        self:__action_collapse_all__()
      end,
      desc = "explorer: collapse all",
    },
    -- Lowercase letters
    {
      modes = { "n" },
      key = "a",
      callback = function()
        self:__action_create_file__()
      end,
      desc = "explorer: create file",
    },
    {
      modes = { "n" },
      key = "c",
      callback = function()
        self:__action_copy_node__()
      end,
      desc = "explorer: copy node",
    },
    {
      modes = { "n" },
      key = "d",
      callback = function()
        self:__action_delete__()
      end,
      desc = "explorer: delete",
    },
    {
      modes = { "n" },
      key = "gb",
      callback = function()
        self:__action_go_prev__()
      end,
      desc = "explorer: go to previous root",
    },
    {
      modes = { "n" },
      key = "gc",
      callback = function()
        self:__action_go_cwd__()
      end,
      desc = "explorer: go to cwd",
    },
    {
      modes = { "n" },
      key = "gw",
      callback = function()
        self:__action_go_home__()
      end,
      desc = "explorer: go to workspace root",
    },
    {
      modes = { "n" },
      key = "h",
      callback = function()
        self:__action_collapse_or_parent__()
      end,
      desc = "explorer: collapse/go parent",
    },
    {
      modes = { "n" },
      key = "l",
      callback = function()
        self:__action_open__()
      end,
      desc = "explorer: open/toggle",
    },
    {
      modes = { "n" },
      key = "mc",
      callback = function()
        self:__action_copy_selected__()
      end,
      desc = "explorer: copy selected to directory",
    },
    {
      modes = { "n" },
      key = "md",
      callback = function()
        self:__action_delete_selected__()
      end,
      desc = "explorer: delete selected",
    },
    {
      modes = { "n" },
      key = "mo",
      callback = function()
        self:__action_open_selected__()
      end,
      desc = "explorer: open selected files",
    },
    {
      modes = { "n" },
      key = "mx",
      callback = function()
        self:__action_move_selected__()
      end,
      desc = "explorer: move selected to directory",
    },
    {
      modes = { "n" },
      key = "o",
      callback = function()
        self:__action_open__()
      end,
      desc = "explorer: open/toggle",
    },
    {
      modes = { "n" },
      key = "oa",
      callback = function()
        self:__action_add_locations_to_ai__()
      end,
      desc = "explorer: add locations to ai",
    },
    {
      modes = { "n" },
      key = "oc",
      callback = function()
        self:__action_copy_path__()
      end,
      desc = "explorer: copy path",
    },
    {
      modes = { "n" },
      key = "oe",
      callback = function()
        self:__action_open_file_explorer__()
      end,
      desc = "explorer: open file explorer",
    },
    {
      modes = { "n" },
      key = "of",
      callback = function()
        self:__action_open_file_finder__()
      end,
      desc = "explorer: open file finder",
    },
    {
      modes = { "n" },
      key = "oi",
      callback = function()
        self:__action_show_file_info__()
      end,
      desc = "explorer: show file info",
    },
    {
      modes = { "n" },
      key = "oo",
      callback = function()
        self:__action_open_system_explorer__()
      end,
      desc = "explorer: open in system explorer",
    },
    {
      modes = { "n" },
      key = "os",
      callback = function()
        self:__action_open_searcher__()
      end,
      desc = "explorer: open searcher",
    },
    {
      modes = { "n" },
      key = "p",
      callback = function()
        self:__action_paste__()
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
        self:__action_rename__()
      end,
      desc = "explorer: rename",
    },
    {
      modes = { "n" },
      key = "w",
      callback = function()
        self:__action_pick_win_open__()
      end,
      desc = "explorer: pick window and open",
    },
    {
      modes = { "n" },
      key = "x",
      callback = function()
        self:__action_cut__()
      end,
      desc = "explorer: cut",
    },
    {
      modes = { "n" },
      key = "z",
      callback = function()
        self:__action_toggle_recursive__()
      end,
      desc = "explorer: toggle expand/collapse recursively",
    },
    -- Visual mode
    {
      modes = { "x" },
      key = "c",
      callback = function()
        self:__action_copy_visual__()
      end,
      desc = "explorer: copy (visual)",
    },
    {
      modes = { "x" },
      key = "d",
      callback = function()
        self:__action_delete_visual__()
      end,
      desc = "explorer: delete (visual)",
    },
    {
      modes = { "x" },
      key = "m",
      callback = function()
        self:__action_mark_visual__()
      end,
      desc = "explorer: mark (visual)",
    },
    {
      modes = { "x" },
      key = "oa",
      callback = function()
        self:__action_add_locations_to_ai_visual__()
      end,
      desc = "explorer: add locations to ai (visual)",
    },
    {
      modes = { "x" },
      key = "x",
      callback = function()
        self:__action_cut_visual__()
      end,
      desc = "explorer: cut (visual)",
    },
  }

  local flags = self:__get_flags__() ---@type dot.module.explorer.widget.IFlagItem[]
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
  ark.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
end

---@protected
---@return nil
function M:__setup_subscriptions__()
  local state = self._tree.state ---@type dot.module.explorer.State

  local sub_root_uri = state.o_root_uri:subscribe(
    ark.c.Subscriber.new({
      on_next = function()
        self:__update_winbar__()
        dot.state.status.dirtier_tabline:mark_dirty()
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_root_uri

  local sub_show_hidden = state.o_flag_hidden:subscribe(
    ark.c.Subscriber.new({
      on_next = function(show_hidden)
        self._resource_manager:set_show_hidden(show_hidden)
        self._tree:refresh(true)
        self:__render__()
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_show_hidden

  local sub_foldempty = state.o_flag_foldempty:subscribe(
    ark.c.Subscriber.new({
      on_next = function()
        self:__refresh__()
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_foldempty

  if self._o_width ~= nil then
    local sub_width = self._o_width:subscribe(
      ark.c.Subscriber.new({
        on_next = function(width)
          self._width = width
          self:resize()
        end,
      }),
      false
    )
    self._subscriptions[#self._subscriptions + 1] = sub_width
  end

  local sub_flag_selected = dot.context.explorer.flag_selected:subscribe(
    ark.c.Subscriber.new({
      on_next = function()
        self:__refresh__()
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_flag_selected

  local sub_flag_viewtype = dot.context.explorer.flag_viewtype:subscribe(
    ark.c.Subscriber.new({
      on_next = function()
        self:__refresh__()
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_flag_viewtype

  local sub_git_staged = dot.git.state.o_staged_files:subscribe(
    ark.c.Subscriber.new({
      on_next = function()
        if self:isvisible() then
          self:__render__()
        end
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_git_staged

  local sub_git_unstaged = dot.git.state.o_unstaged_files:subscribe(
    ark.c.Subscriber.new({
      on_next = function()
        if self:isvisible() then
          self:__render__()
        end
      end,
    }),
    false
  )
  self._subscriptions[#self._subscriptions + 1] = sub_git_unstaged
end

---@protected
---@param uri                           string
---@return nil
function M:__sync_cursor_to_uri__(uri)
  local render_result = self._render_result ---@type dot.module.explorer.view.IRenderResult|nil
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
---@param direction                     "prev"|"next"
---@param matcher                       fun(filepath: string): boolean
---@return boolean                      found
function M:__goto_matching_file__(direction, matcher)
  local render_result = self._render_result ---@type dot.module.explorer.view.IRenderResult|nil
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

  local file_uris = {} ---@type {lnum: integer, uri: string, filepath: string}[]
  for lnum = 1, total_lines do
    local uri = render_result.lnum_to_uri[lnum] ---@type string|nil
    if uri ~= nil and uri:sub(-1) ~= "/" then
      local filepath = uri:sub(8) ---@type string
      file_uris[#file_uris + 1] = { lnum = lnum, uri = uri, filepath = filepath }
    end
  end

  if #file_uris == 0 then
    return false
  end

  local matching_lnums = {} ---@type integer[]
  for _, item in ipairs(file_uris) do
    if matcher(item.filepath) then
      matching_lnums[#matching_lnums + 1] = item.lnum
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
      self._tree.state.o_cursor_uri:next(target_uri)
      pcall(vim.api.nvim_win_set_cursor, winnr, { target_lnum, 0 })
      return true
    end
  end

  return false
end

---@protected
---@param direction                     "prev"|"next"
---@param matcher                       fun(filepath: string, is_dir: boolean): boolean
---@return boolean                      found
function M:__goto_matching_file_or_dir__(direction, matcher)
  local render_result = self._render_result ---@type dot.module.explorer.view.IRenderResult|nil
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

  local items = {} ---@type {lnum: integer, uri: string, filepath: string, is_dir: boolean}[]
  for lnum = 1, total_lines do
    local uri = render_result.lnum_to_uri[lnum] ---@type string|nil
    if uri ~= nil then
      local is_dir = uri:sub(-1) == "/" ---@type boolean
      local filepath = uri:sub(8) ---@type string
      if is_dir and #filepath > 1 then
        filepath = filepath:sub(1, -2)
      end
      items[#items + 1] = { lnum = lnum, uri = uri, filepath = filepath, is_dir = is_dir }
    end
  end

  if #items == 0 then
    return false
  end

  local matching_lnums = {} ---@type integer[]
  for _, item in ipairs(items) do
    if matcher(item.filepath, item.is_dir) then
      matching_lnums[#matching_lnums + 1] = item.lnum
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
      self._tree.state.o_cursor_uri:next(target_uri)
      pcall(vim.api.nvim_win_set_cursor, winnr, { target_lnum, 0 })
      return true
    end
  end

  return false
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

  local render_result = self._render_result ---@type dot.module.explorer.view.IRenderResult|nil
  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local lnum = cursor[1] ---@type integer
  local prev_lnum = self._prev_cursor_lnum ---@type integer|nil

  vim.api.nvim_buf_clear_namespace(bufnr, ns_cursorline, 0, -1)

  local hlgroup = self._is_focused and "f_explorer_cursorline" or "f_explorer_cursorline_blur" ---@type string
  vim.api.nvim_buf_set_extmark(bufnr, ns_cursorline, lnum - 1, 0, {
    line_hl_group = hlgroup,
    priority = 100,
  })

  if render_result ~= nil then
    if prev_lnum ~= nil and prev_lnum ~= lnum then
      self._view:update_virt_text(bufnr, render_result, prev_lnum, nil)
    end
    local cursorline_hlgroup = self._is_focused and "f_explorer_cursorline" or "f_explorer_cursorline_blur" ---@type string
    self._view:update_virt_text(bufnr, render_result, lnum, cursorline_hlgroup)
  end

  self._prev_cursor_lnum = lnum
end

---@protected
---@return nil
function M:__update_winbar__()
  if vim.o.showtabline ~= 0 then
    return
  end
  self._nvimbar:render(true)
end

return M
