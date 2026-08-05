---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.action" ---@type string

---@class era.m.explorer.Action
---@field protected _ctx                era.m.explorer.action.IContext
---@field protected _pending_transfer   era.m.explorer.IPendingTransfer|nil
local M = {}
M.__index = M

---@param filepath                      string
---@param keep_trailing_slash           boolean|nil
---@return string
local function normalize_filepath(filepath, keep_trailing_slash)
  return stl.os.path.normalize(filepath, keep_trailing_slash)
end

---@param parent_filepath               string
---@param name                          string
---@param is_directory                  boolean
---@return string
local function join_child_filepath(parent_filepath, name, is_directory)
  return normalize_filepath(parent_filepath .. "/" .. name, is_directory)
end

---@param filepath                      string
---@return string
local function to_os_filepath(filepath)
  return stl.os.path.to_os(filepath)
end

---@param source                        era.m.explorer.IPendingTransferSource
---@param filepath                      string
---@return boolean
local function transfer_source_covers(source, filepath)
  local source_filepath = normalize_filepath(source.filepath, false) ---@type string
  local target_filepath = normalize_filepath(filepath, false) ---@type string
  return source_filepath == target_filepath
    or (source.nodetype == "D" and yoz.path.is_descendant(source_filepath, target_filepath))
end

---@param root_filepath                 string
---@param filepath                      string
---@return boolean
local function is_same_or_descendant(root_filepath, filepath)
  local root = normalize_filepath(root_filepath, false) ---@type string
  local target = normalize_filepath(filepath, false) ---@type string
  return yoz.path.is_descendant(root, target)
end

---@param input                         string
---@return string|nil                   name
---@return string|nil                   error
local function validate_entry_name(input)
  local name = vim.trim(input) ---@type string
  if name == "" then
    return nil, nil
  end
  if name == "." or name == ".." then
    return nil, "Invalid name: '.' and '..' are not allowed"
  end
  if name:find("[/\\]") ~= nil then
    return nil, "Invalid name: path separator is not allowed"
  end
  return name, nil
end

---@param filename                      string
---@param is_directory                  boolean
---@return string
local function suggest_copy_name(filename, is_directory)
  if is_directory then
    return filename .. "-copy"
  end

  local ext = yoz.path.extname(filename) ---@type string
  if ext ~= "" and #filename > #ext then
    return filename:sub(1, #filename - #ext) .. "-copy" .. ext
  end
  return filename .. "-copy"
end

---@param ctx                           era.m.explorer.action.IContext
---@return era.m.explorer.Action
function M.new(ctx)
  local self = setmetatable({}, M)
  self._ctx = ctx
  self._pending_transfer = nil
  return self
end

---@return nil
function M:add_locations_to_ai()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local selected_nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]

  local locations = {} ---@type dot.t.ILocation[]
  if #selected_nodes > 0 then
    for _, node in ipairs(selected_nodes) do
      local filepath = to_os_filepath(node.filepath) ---@type string
      locations[#locations + 1] = { filepath = filepath }
    end
  else
    local filepath = ctx.get_cursor_filepath() ---@type string|nil
    if filepath == nil then
      return
    end
    local filepath = to_os_filepath(filepath) ---@type string
    locations[#locations + 1] = { filepath = filepath }
  end

  era.fn.add_locations_to_ai(locations)
end

---@return nil
function M:add_locations_to_ai_visual()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local nodes = ctx.get_visual_nodes() ---@type era.m.explorer.Node[]
  if #nodes == 0 then
    return
  end

  local locations = {} ---@type dot.t.ILocation[]
  for _, node in ipairs(nodes) do
    local filepath = to_os_filepath(node.filepath) ---@type string
    locations[#locations + 1] = { filepath = filepath }
  end

  era.fn.add_locations_to_ai(locations)
end

---@return nil
function M:collapse_all()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local root_filepath = ctx.tree.o_root_filepath:snapshot() ---@type string
  ctx.tree:toggle_expanded(root_filepath, true, "collapse")
  ctx.tree:toggle_expanded(root_filepath, false, "expand")
  ctx.refresh()
end

---@return nil
function M:collapse_or_parent()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  local root_filepath = ctx.tree.o_root_filepath:snapshot() ---@type string
  if filepath:sub(-1) == "/" then
    local node = ctx.tree:locate(filepath) ---@type era.m.explorer.Node|nil
    if node ~= nil and node.expanded then
      ctx.tree:toggle_expanded(filepath, false, "collapse")
      ctx.refresh()
      return
    end
  end

  local parent_filepath = ctx.get_parent_filepath(filepath) ---@type string
  if parent_filepath ~= root_filepath then
    ctx.tree:toggle_expanded(parent_filepath, false, "collapse")
    ctx.tree.o_cursor_filepath:next(parent_filepath)
    ctx.sync_cursor_to_filepath(parent_filepath)
    ctx.refresh()
  end
end

---@return nil
function M:copy()
  if self:__cancel_focused_transfer__("copy") then
    return
  end

  local selected_nodes = self._ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]
  local pending_transfer = self._pending_transfer ---@type era.m.explorer.IPendingTransfer|nil
  if #selected_nodes > 0 or (pending_transfer ~= nil and pending_transfer.mode == "move") then
    self:stage_transfer("copy")
    return
  end

  self:copy_as()
end

---@return nil
function M:cut()
  if self:__cancel_focused_transfer__("move") then
    return
  end

  self:stage_transfer("move")
end

---@return nil
function M:copy_as()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  local node = ctx.tree:locate(filepath) ---@type era.m.explorer.Node|nil
  if node == nil then
    return
  end

  local is_directory = node.nodetype == "D" ---@type boolean
  local parent_filepath = ctx.get_parent_filepath(filepath) ---@type string
  local suggested_name = suggest_copy_name(node.nodename, is_directory) ---@type string
  local cwd = dot.path.cwd() ---@type string
  local suggested_target = join_child_filepath(parent_filepath, suggested_name, is_directory) ---@type string
  local suggested_input = dot.path.relative(cwd, suggested_target, "/") ---@type string
  if is_directory and suggested_input:sub(-1) ~= "/" then
    suggested_input = suggested_input .. "/"
  end

  vim.ui.input({ prompt = "Copy as: ", default = suggested_input }, function(input)
    if input == nil then
      return
    end

    local specified_filepath = vim.trim(input) ---@type string
    if specified_filepath == "" then
      return
    end

    local target_filepath = normalize_filepath(dot.path.resolve(cwd, specified_filepath), is_directory) ---@type string
    if is_directory and target_filepath:sub(-1) ~= "/" then
      target_filepath = target_filepath .. "/"
    end

    if is_directory and is_same_or_descendant(filepath, target_filepath) then
      stl.reporter.error({
        from = ctx.fullname,
        subject = "copy as",
        message = string.format("Cannot copy a directory into itself: %s", target_filepath),
      })
      return
    end

    local ok = ctx.resource_manager:copy(filepath, target_filepath) ---@type boolean
    if ok then
      ctx.tree:refresh(true)
      vim.schedule(function()
        ctx.refresh(true)
        ctx.sync_cursor_to_filepath(target_filepath)
      end)
      stl.reporter.info({
        from = ctx.fullname,
        subject = "copy as",
        message = string.format("Copied to: %s", target_filepath),
      })
    end
  end)
end

---@return nil
function M:copy_path()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local selected_nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]

  local filepaths = {} ---@type string[]
  if #selected_nodes > 0 then
    for _, node in ipairs(selected_nodes) do
      local filepath = normalize_filepath(node.filepath) ---@type string
      filepaths[#filepaths + 1] = filepath
    end
  else
    local filepath = ctx.get_cursor_filepath() ---@type string|nil
    if filepath == nil then
      return
    end
    local filepath = normalize_filepath(filepath) ---@type string
    filepaths[#filepaths + 1] = filepath
  end

  era.fn.select_copy_filepaths({
    filepaths = filepaths,
    winopts = {
      relative = "cursor",
      row = 1,
      col = 4,
    },
  })
end

---@return nil
function M:create_directory()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local cursor_filepath = ctx.get_cursor_filepath() ---@type string|nil
  if cursor_filepath == nil then
    return
  end

  local parent_filepath = cursor_filepath:sub(-1) == "/" and cursor_filepath or ctx.get_parent_filepath(cursor_filepath) ---@type string
  local root_filepath = ctx.tree.o_root_filepath:snapshot() ---@type string
  local relative_path = parent_filepath:sub(#root_filepath + 1) ---@type string

  vim.ui.input({ prompt = "Create directory: ", default = relative_path }, function(input)
    if input == nil or #vim.trim(input) == 0 then
      return
    end

    local dirname = normalize_filepath(vim.trim(input), false) ---@type string
    if dirname:sub(-1) ~= "/" then
      dirname = dirname .. "/"
    end

    local new_filepath = normalize_filepath(root_filepath .. dirname, true) ---@type string
    local resource = ctx.resource_manager:create(new_filepath) ---@type era.m.explorer.resource.INode|nil
    if resource ~= nil then
      local new_parent_filepath = ctx.get_parent_filepath(new_filepath) ---@type string
      ctx.tree:toggle_expanded(new_parent_filepath, false, "expand")
      local parts = vim.split(dirname:sub(1, -2), "/", { plain = true }) ---@type string[]
      local intermediate_filepath = root_filepath ---@type string
      for _, part in ipairs(parts) do
        intermediate_filepath = intermediate_filepath .. part .. "/"
        ctx.tree:toggle_expanded(intermediate_filepath, false, "expand")
      end
      ctx.tree:refresh(true)
      vim.schedule(function()
        ctx.render()
        ctx.sync_cursor_to_filepath(new_filepath)
      end)
    end
  end)
end

---@return nil
function M:create_file()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local cursor_filepath = ctx.get_cursor_filepath() ---@type string|nil
  if cursor_filepath == nil then
    return
  end

  local parent_filepath = cursor_filepath:sub(-1) == "/" and cursor_filepath or ctx.get_parent_filepath(cursor_filepath) ---@type string
  local root_filepath = ctx.tree.o_root_filepath:snapshot() ---@type string
  local relative_path = parent_filepath:sub(#root_filepath + 1) ---@type string
  if relative_path ~= "" and relative_path:sub(-1) ~= "/" then
    relative_path = relative_path .. "/"
  end

  vim.ui.input({ prompt = "Create file: ", default = relative_path }, function(input)
    if input == nil or #vim.trim(input) == 0 then
      return
    end

    local filename = normalize_filepath(vim.trim(input)) ---@type string
    local is_directory = filename:sub(-1) == "/" ---@type boolean
    local new_filepath = normalize_filepath(root_filepath .. filename, is_directory) ---@type string
    local resource = ctx.resource_manager:create(new_filepath) ---@type era.m.explorer.resource.INode|nil
    if resource ~= nil then
      local new_parent_filepath = ctx.get_parent_filepath(new_filepath) ---@type string
      ctx.tree:toggle_expanded(new_parent_filepath, false, "expand")
      local parts = vim.split(filename, "/", { plain = true }) ---@type string[]
      if #parts > 1 then
        local intermediate_filepath = root_filepath ---@type string
        for i = 1, #parts - 1 do
          intermediate_filepath = intermediate_filepath .. parts[i] .. "/"
          ctx.tree:toggle_expanded(intermediate_filepath, false, "expand")
        end
      end
      ctx.tree:refresh(true)
      vim.schedule(function()
        ctx.render()
        ctx.sync_cursor_to_filepath(new_filepath)

        if resource.nodetype == "F" then
          local filepath = to_os_filepath(resource.filepath) ---@type string
          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
          if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
            vim.api.nvim_set_current_win(winnr_sourcefile)
          end
          dot.win.open_filepath(winnr_sourcefile, filepath)
        end
      end)
    end
  end)
end

---@return era.m.explorer.IPendingTransfer|nil
function M:get_pending_transfer()
  return self._pending_transfer
end

---@return nil
function M:cancel_transfer()
  if self._pending_transfer == nil then
    return
  end

  self._pending_transfer = nil
  self._ctx.refresh()
end

---@param mode                          era.m.explorer.TransferModeEnum
---@return nil
function M:stage_transfer(mode)
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  local focused_node = filepath ~= nil and ctx.tree:locate(filepath) or nil ---@type era.m.explorer.Node|nil
  if #nodes > 0 and focused_node ~= nil and not ctx.tree:is_selected(focused_node.filepath) then
    ctx.tree:toggle_selected(focused_node.filepath, "select")
    nodes = ctx.tree:get_selected_nodes()
  elseif #nodes == 0 and focused_node ~= nil then
    nodes = { focused_node }
  end
  if #nodes == 0 then
    return
  end

  self:__stage_transfer__(mode, nodes)
end

---@param mode                          era.m.explorer.TransferModeEnum
---@return nil
function M:stage_transfer_visual(mode)
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local visual_nodes = ctx.get_visual_nodes() ---@type era.m.explorer.Node[]
  if #visual_nodes == 0 then
    return
  end

  local nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]
  for _, node in ipairs(visual_nodes) do
    nodes[#nodes + 1] = node
  end
  self:__stage_transfer__(mode, nodes)
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
end

---@protected
---@param mode                          era.m.explorer.TransferModeEnum
---@param nodes                         era.m.explorer.Node[]
---@return nil
function M:__stage_transfer__(mode, nodes)
  local sources = {} ---@type era.m.explorer.IPendingTransferSource[]
  for _, node in ipairs(nodes) do
    self:__append_transfer_source__(sources, self:__create_transfer_source__(node))
  end

  self:__set_pending_transfer__(mode, sources)
  self._ctx.refresh()
end

---@protected
---@param node                          era.m.explorer.Node
---@return era.m.explorer.IPendingTransferSource
function M:__create_transfer_source__(node)
  local is_directory = node.nodetype == "D" ---@type boolean
  local filepath = normalize_filepath(node.filepath, is_directory) ---@type string
  if is_directory and filepath:sub(-1) ~= "/" then
    filepath = filepath .. "/"
  end
  return {
    filepath = filepath,
    nodename = node.nodename,
    nodetype = node.nodetype,
  }
end

---@protected
---@param sources                       era.m.explorer.IPendingTransferSource[]
---@param candidate                     era.m.explorer.IPendingTransferSource
---@return nil
function M:__append_transfer_source__(sources, candidate)
  for i = #sources, 1, -1 do
    local source = sources[i] ---@type era.m.explorer.IPendingTransferSource
    if transfer_source_covers(source, candidate.filepath) then
      return
    end
    if transfer_source_covers(candidate, source.filepath) then
      table.remove(sources, i)
    end
  end
  sources[#sources + 1] = candidate
end

---@protected
---@param mode                          era.m.explorer.TransferModeEnum
---@return boolean
function M:__cancel_focused_transfer__(mode)
  local pending_transfer = self._pending_transfer ---@type era.m.explorer.IPendingTransfer|nil
  if pending_transfer == nil or pending_transfer.mode ~= mode then
    return false
  end

  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return false
  end

  local is_pending = false ---@type boolean
  for _, source in ipairs(pending_transfer.sources) do
    if transfer_source_covers(source, filepath) then
      is_pending = true
      break
    end
  end
  if not is_pending then
    return false
  end

  if ctx.tree:is_selected(filepath) then
    local selected_nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]
    ctx.tree:toggle_selected(filepath, "unselect")
    self:__sync_pending_transfer__(selected_nodes)
  end

  pending_transfer = self._pending_transfer
  local sources = {} ---@type era.m.explorer.IPendingTransferSource[]
  if pending_transfer ~= nil then
    for _, source in ipairs(pending_transfer.sources) do
      if not transfer_source_covers(source, filepath) then
        self:__append_transfer_source__(sources, source)
      end
    end
  end
  self:__set_pending_transfer__(mode, sources)
  ctx.refresh()
  return true
end

---@protected
---@param mode                          era.m.explorer.TransferModeEnum|nil
---@param sources                       era.m.explorer.IPendingTransferSource[]
---@return nil
function M:__set_pending_transfer__(mode, sources)
  if mode == nil or #sources == 0 then
    self._pending_transfer = nil
    return
  end

  local source_filepaths = {} ---@type table<string, boolean>
  for _, source in ipairs(sources) do
    source_filepaths[source.filepath] = true
  end

  self._pending_transfer = {
    mode = mode,
    sources = sources,
    source_filepaths = source_filepaths,
  }
end

---@protected
---@param previous_selected_nodes       era.m.explorer.Node[]
---@return nil
function M:__sync_pending_transfer__(previous_selected_nodes)
  local pending_transfer = self._pending_transfer ---@type era.m.explorer.IPendingTransfer|nil
  if pending_transfer == nil then
    return
  end

  local selected_nodes = self._ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]
  local selected_filepaths = {} ---@type table<string, boolean>
  for _, node in ipairs(selected_nodes) do
    selected_filepaths[self:__create_transfer_source__(node).filepath] = true
  end

  local removed_filepaths = {} ---@type string[]
  for _, node in ipairs(previous_selected_nodes) do
    local filepath = self:__create_transfer_source__(node).filepath ---@type string
    if not selected_filepaths[filepath] then
      removed_filepaths[#removed_filepaths + 1] = filepath
    end
  end

  local sources = {} ---@type era.m.explorer.IPendingTransferSource[]
  for _, source in ipairs(pending_transfer.sources) do
    local covers_removed_selection = false ---@type boolean
    for _, filepath in ipairs(removed_filepaths) do
      if transfer_source_covers(source, filepath) then
        covers_removed_selection = true
        break
      end
    end
    if not covers_removed_selection then
      self:__append_transfer_source__(sources, source)
    end
  end
  for _, node in ipairs(selected_nodes) do
    self:__append_transfer_source__(sources, self:__create_transfer_source__(node))
  end
  self:__set_pending_transfer__(pending_transfer.mode, sources)
end

---@protected
---@param nodes                         era.m.explorer.Node[]
---@return nil
function M:__remove_pending_sources_covered_by__(nodes)
  local pending_transfer = self._pending_transfer ---@type era.m.explorer.IPendingTransfer|nil
  if pending_transfer == nil or #nodes == 0 then
    return
  end

  local removed_roots = {} ---@type era.m.explorer.IPendingTransferSource[]
  for _, node in ipairs(nodes) do
    removed_roots[#removed_roots + 1] = self:__create_transfer_source__(node)
  end

  local sources = {} ---@type era.m.explorer.IPendingTransferSource[]
  for _, source in ipairs(pending_transfer.sources) do
    local removed = false ---@type boolean
    for _, root in ipairs(removed_roots) do
      if transfer_source_covers(root, source.filepath) then
        removed = true
        break
      end
    end
    if not removed then
      self:__append_transfer_source__(sources, source)
    end
  end
  self:__set_pending_transfer__(pending_transfer.mode, sources)
end

---@protected
---@return nil
function M:__select_pending_sources__()
  local pending_transfer = self._pending_transfer ---@type era.m.explorer.IPendingTransfer|nil
  if pending_transfer == nil then
    return
  end

  local tree = self._ctx.tree ---@type era.m.explorer.Tree
  for _, source in ipairs(pending_transfer.sources) do
    tree:toggle_selected(source.filepath, "select")
  end
end

---@protected
---@param filepath                      string
---@return nil
function M:__toggle_selection__(filepath)
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local selected_nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]
  if #selected_nodes == 0 and self._pending_transfer ~= nil then
    self:__select_pending_sources__()
    ctx.tree:toggle_selected(filepath, "select")
  else
    ctx.tree:toggle_selected(filepath, nil)
  end
  self:__sync_pending_transfer__(selected_nodes)
  ctx.refresh()
end

---@protected
---@return nil
function M:__clear_selection__()
  local selected_nodes = self._ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]
  self._ctx.tree:clear_selection()
  self:__sync_pending_transfer__(selected_nodes)
end

---@return nil
function M:delete()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local selected_nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]

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

      local deleted_nodes = {} ---@type era.m.explorer.Node[]
      for _, node in ipairs(selected_nodes) do
        local ok = ctx.tree:remove(node.filepath) ---@type boolean
        if ok then
          deleted_nodes[#deleted_nodes + 1] = node
        end
      end

      if #deleted_nodes > 0 then
        self:__remove_pending_sources_covered_by__(deleted_nodes)
        self:__clear_selection__()
        vim.schedule(function()
          ctx.refresh()
        end)

        stl.reporter.info({
          from = ctx.fullname,
          subject = "delete",
          message = string.format("Deleted %d item(s)", #deleted_nodes),
        })
      end
    end)
    return
  end

  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  local node = ctx.tree:locate(filepath) ---@type era.m.explorer.Node|nil
  if node == nil then
    return
  end

  local is_directory = filepath:sub(-1) == "/" ---@type boolean
  local name ---@type string
  if is_directory then
    local parts = vim.split(filepath:sub(1, -2), "/") ---@type string[]
    name = parts[#parts] or filepath
  else
    name = vim.fn.fnamemodify(filepath, ":t")
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

    local ok = ctx.tree:remove(filepath) ---@type boolean
    if ok then
      self:__remove_pending_sources_covered_by__({ node })
      vim.schedule(function()
        ctx.refresh()
      end)
    end
  end)
end

---@return nil
function M:delete_visual()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local nodes = ctx.get_visual_nodes() ---@type era.m.explorer.Node[]
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

    local deleted_nodes = {} ---@type era.m.explorer.Node[]
    for _, node in ipairs(nodes) do
      local ok = ctx.tree:remove(node.filepath) ---@type boolean
      if ok then
        deleted_nodes[#deleted_nodes + 1] = node
      end
    end

    if #deleted_nodes > 0 then
      self:__remove_pending_sources_covered_by__(deleted_nodes)
      vim.schedule(function()
        ctx.refresh()
      end)

      stl.reporter.info({
        from = ctx.fullname,
        subject = "delete",
        message = string.format("Deleted %d item(s)", #deleted_nodes),
      })
    end
  end)
end

---@return nil
function M:delete_selected()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local selected_nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]
  if #selected_nodes == 0 then
    stl.reporter.warn({
      from = ctx.fullname,
      subject = "delete selected",
      message = "No files selected",
    })
    return
  end

  local cwd = dot.path.cwd() ---@type string

  ---@type string[]
  local preview_lines = {}
  for _, node in ipairs(selected_nodes) do
    local filepath = normalize_filepath(node.filepath) ---@type string
    local relative_path = dot.path.relative(cwd, filepath) ---@type string
    preview_lines[#preview_lines + 1] = relative_path
  end

  local fullname = ctx.fullname ---@type string

  ---@type era.view.Act
  local act = era.view.Act.new({
    name = "explorer_delete",
    title = string.format("%s Delete %d item(s)", stl.icon.diagnostic.Warning, #selected_nodes),
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

      local deleted_nodes = {} ---@type era.m.explorer.Node[]
      for _, node in ipairs(selected_nodes) do
        local ok = ctx.tree:remove(node.filepath) ---@type boolean
        if ok then
          deleted_nodes[#deleted_nodes + 1] = node
        end
      end

      if #deleted_nodes > 0 then
        self:__remove_pending_sources_covered_by__(deleted_nodes)
        self:__clear_selection__()
        vim.schedule(function()
          ctx.refresh()
        end)

        stl.reporter.info({
          from = fullname,
          subject = "delete",
          message = string.format("Deleted %d item(s)", #deleted_nodes),
        })
      end
    end,
  })
  act:open()
end

---@return nil
function M:go_cwd()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local cwd = dot.path.cwd() ---@type string
  local root_filepath = normalize_filepath(cwd .. "/") ---@type string
  ctx.widget:set_root(root_filepath)
end

---@return nil
function M:go_home()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local workspace = dot.path.workspace() ---@type string
  local root_filepath = normalize_filepath(workspace .. "/") ---@type string
  ctx.widget:set_root(root_filepath)
end

---@return nil
function M:go_parent()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local root_filepath = ctx.tree.o_root_filepath:snapshot() ---@type string
  local parent_filepath = ctx.get_parent_filepath(root_filepath) ---@type string

  if parent_filepath ~= root_filepath then
    ctx.widget:set_root(parent_filepath)
  end
end

---@return nil
function M:go_prev()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local prev_root_filepath = ctx.tree.prev_root_filepath ---@type string|nil
  if prev_root_filepath == nil then
    return
  end
  ctx.widget:set_root(prev_root_filepath)
end

---@return nil
function M:jump_last_child()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  if filepath:sub(-1) ~= "/" then
    return
  end

  local node = ctx.tree:locate(filepath) ---@type era.m.explorer.Node|nil
  if node == nil or not node.expanded or #node.children == 0 then
    return
  end

  local last_child = node.children[#node.children] ---@type era.m.explorer.Node
  local target_filepath = last_child.filepath ---@type string
  ctx.tree.o_cursor_filepath:next(target_filepath)
  ctx.sync_cursor_to_filepath(target_filepath)
end

---@return nil
function M:jump_parent()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  local parent_filepath = ctx.get_parent_filepath(filepath) ---@type string
  local root_filepath = ctx.tree.o_root_filepath:snapshot() ---@type string

  if parent_filepath ~= filepath and vim.startswith(parent_filepath, root_filepath) then
    ctx.tree.o_cursor_filepath:next(parent_filepath)
    ctx.sync_cursor_to_filepath(parent_filepath)
  end
end

---@return nil
function M:mark_visual()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local nodes = ctx.get_visual_nodes() ---@type era.m.explorer.Node[]
  if #nodes == 0 then
    return
  end

  local selected_nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]
  local force_selected = "unselect" ---@type era.m.explorer.ForceSelectedEnum
  if #selected_nodes == 0 and self._pending_transfer ~= nil then
    self:__select_pending_sources__()
    force_selected = "select"
  else
    for _, node in ipairs(nodes) do
      if not ctx.tree:is_selected(node.filepath) then
        force_selected = "select"
        break
      end
    end
  end

  for _, node in ipairs(nodes) do
    ctx.tree:toggle_selected(node.filepath, force_selected)
  end
  self:__sync_pending_transfer__(selected_nodes)
  ctx.refresh()
end

---@return nil
function M:open()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  if filepath:sub(-1) == "/" then
    ctx.tree:toggle_expanded(filepath, false, nil)
    ctx.refresh()
  else
    local filepath = to_os_filepath(filepath) ---@type string
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
    if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
      vim.api.nvim_set_current_win(winnr_sourcefile)
    end
    dot.win.open_filepath(winnr_sourcefile, filepath)
  end
end

---@return nil
function M:open_file_explorer()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  local filepath = to_os_filepath(filepath) ---@type string
  era.fn.find_explorer(filepath)
end

---@return nil
function M:open_file_finder()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  local dirpath ---@type string
  if filepath:sub(-1) == "/" then
    dirpath = to_os_filepath(filepath)
  else
    dirpath = dot.path.dirname(to_os_filepath(filepath))
  end

  era.fn.find_files(dirpath, true)
end

---@return nil
function M:open_searcher()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  local filepath = to_os_filepath(filepath) ---@type string
  era.fn.search_in_files(filepath)
end

---@return nil
function M:open_selected()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local selected_nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]
  if #selected_nodes == 0 then
    stl.reporter.warn({
      from = ctx.fullname,
      subject = "open selected",
      message = "No files selected",
    })
    return
  end

  local file_nodes = {} ---@type era.m.explorer.Node[]
  for _, node in ipairs(selected_nodes) do
    if node.nodetype == "F" then
      file_nodes[#file_nodes + 1] = node
    end
  end

  if #file_nodes == 0 then
    stl.reporter.warn({
      from = ctx.fullname,
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
    local filepath = to_os_filepath(node.filepath) ---@type string
    dot.win.open_filepath(winnr_sourcefile, filepath)
  end

  self:__clear_selection__()
  vim.schedule(function()
    ctx.render()
  end)

  stl.reporter.info({
    from = ctx.fullname,
    subject = "open selected",
    message = string.format("Opened %d file(s)", #file_nodes),
  })
end

---@return nil
function M:open_split()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil or filepath:sub(-1) == "/" then
    return
  end

  local filepath = to_os_filepath(filepath) ---@type string
  vim.cmd("split " .. vim.fn.fnameescape(filepath))
end

---@return nil
function M:open_system_explorer()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  local filepath = to_os_filepath(filepath) ---@type string
  vim.ui.open(filepath)
end

---@return nil
function M:open_tab()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil or filepath:sub(-1) == "/" then
    return
  end

  local filepath = to_os_filepath(filepath) ---@type string
  vim.cmd("tabnew " .. vim.fn.fnameescape(filepath))

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.t[tabnr].tabtype = stl.e.TabTypeEnum.NORMAL
end

---@return nil
function M:open_vsplit()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil or filepath:sub(-1) == "/" then
    return
  end

  local filepath = to_os_filepath(filepath) ---@type string
  vim.cmd("vsplit " .. vim.fn.fnameescape(filepath))
end

---@param winnr                         integer|nil
---@return nil
function M:pick_win_open(winnr)
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil or filepath:sub(-1) == "/" then
    return
  end

  local filepath = to_os_filepath(filepath) ---@type string
  local picked_winnr = dot.win.pick_sourcefile(winnr) ---@type integer|nil
  if picked_winnr == nil then
    return
  end

  dot.win.open_filepath(picked_winnr, filepath)
  vim.api.nvim_set_current_win(picked_winnr)
end

---@param winnr                         integer|nil
---@return nil
function M:pick_win_split(winnr)
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil or filepath:sub(-1) == "/" then
    return
  end

  local filepath = to_os_filepath(filepath) ---@type string
  local picked_winnr = dot.win.pick_sourcefile(winnr) ---@type integer|nil
  if picked_winnr == nil then
    return
  end

  vim.api.nvim_set_current_win(picked_winnr)
  vim.cmd("split " .. vim.fn.fnameescape(filepath))
end

---@param winnr                         integer|nil
---@return nil
function M:pick_win_vsplit(winnr)
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil or filepath:sub(-1) == "/" then
    return
  end

  local filepath = to_os_filepath(filepath) ---@type string
  local picked_winnr = dot.win.pick_sourcefile(winnr) ---@type integer|nil
  if picked_winnr == nil then
    return
  end

  vim.api.nvim_set_current_win(picked_winnr)
  vim.cmd("vsplit " .. vim.fn.fnameescape(filepath))
end

---@return nil
function M:rename()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  local node = ctx.tree:locate(filepath) ---@type era.m.explorer.Node|nil
  if node == nil then
    return
  end

  local is_directory = node.nodetype == "D" ---@type boolean
  local parent_filepath = ctx.get_parent_filepath(filepath) ---@type string

  vim.ui.input({ prompt = "Rename to: ", default = node.nodename }, function(input)
    if input == nil then
      return
    end

    local name, err = validate_entry_name(input)
    if name == nil then
      if err ~= nil then
        stl.reporter.error({
          from = ctx.fullname,
          subject = "rename",
          message = err,
        })
      end
      return
    end
    if name == node.nodename then
      return
    end

    local new_filepath = join_child_filepath(parent_filepath, name, is_directory) ---@type string
    if is_directory and new_filepath:sub(-1) ~= "/" then
      new_filepath = new_filepath .. "/"
    end

    local ok = ctx.resource_manager:move(filepath, new_filepath) ---@type boolean
    if ok then
      self:__remove_pending_sources_covered_by__({ node })
      ctx.tree:refresh(true)
      vim.schedule(function()
        ctx.refresh(true)
        ctx.sync_cursor_to_filepath(new_filepath)
      end)
      stl.reporter.info({
        from = ctx.fullname,
        subject = "rename",
        message = string.format("Renamed to: %s", new_filepath),
      })
    end
  end)
end

---@return nil
function M:select_toggle()
  local filepath = self._ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  self:__toggle_selection__(filepath)
end

---@return nil
function M:send_to_quickfix()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local selected_nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]

  if #selected_nodes == 0 then
    local filepath = ctx.get_cursor_filepath() ---@type string|nil
    if filepath == nil then
      return
    end
    local filepath = to_os_filepath(filepath) ---@type string
    vim.fn.setqflist({}, "r", {
      title = "Explorer",
      items = { { filename = filepath, lnum = 1, col = 1 } },
    })
  else
    local items = {} ---@type table[]
    for _, node in ipairs(selected_nodes) do
      local filepath = to_os_filepath(node.filepath) ---@type string
      items[#items + 1] = { filename = filepath, lnum = 1, col = 1 }
    end
    vim.fn.setqflist({}, "r", {
      title = "Explorer Selection",
      items = items,
    })
  end

  vim.cmd("copen")

  stl.reporter.info({
    from = ctx.fullname,
    subject = "quickfix",
    message = "Sent to quickfix list",
  })
end

---@return nil
function M:set_root()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  if filepath:sub(-1) ~= "/" then
    filepath = ctx.get_parent_filepath(filepath)
  end

  ctx.widget:set_root(filepath)
end

---@param keymaps                       stl.t.IKeymap[]
---@return nil
function M:show_keysheet(keymaps)
  local keysheet = era.view.Keysheet.new({
    title = "Explorer Help",
    keymaps = keymaps,
  })
  keysheet:open()
end

---@return nil
function M:show_file_info()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  local filepath = to_os_filepath(filepath) ---@type string

  local fileinfo = era.view.Fileinfo.new({ filepath = filepath })
  fileinfo:open()
end

---@return nil
function M:toggle_recursive()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local filepath = ctx.get_cursor_filepath() ---@type string|nil
  if filepath == nil then
    return
  end

  if filepath:sub(-1) ~= "/" then
    return
  end

  ctx.tree:toggle_expanded(filepath, true, nil)
  ctx.refresh()
end

---@class era.m.explorer.action.ITransferPlan
---@field public source                 era.m.explorer.IPendingTransferSource
---@field public target_filepath        string

---@return nil
function M:paste()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local pending_transfer = self:get_pending_transfer() ---@type era.m.explorer.IPendingTransfer|nil
  if pending_transfer == nil then
    stl.reporter.warn({
      from = ctx.fullname,
      subject = "paste",
      message = "No cut/copy operation pending",
    })
    return
  end

  local cursor_filepath = ctx.get_cursor_filepath() ---@type string|nil
  if cursor_filepath == nil then
    return
  end

  local target_dir_filepath = cursor_filepath:sub(-1) == "/" and cursor_filepath
    or ctx.get_parent_filepath(cursor_filepath) ---@type string
  local target_dir = normalize_filepath(target_dir_filepath, true) ---@type string
  if target_dir:sub(-1) ~= "/" then
    target_dir = target_dir .. "/"
  end

  local plans, errors = self:__build_transfer_plans__(pending_transfer, target_dir)
  if plans == nil then
    stl.reporter.error({
      from = ctx.fullname,
      subject = "paste",
      message = string.format("Cannot paste %d item(s)", #pending_transfer.sources),
      details = { errors = errors },
    })
    return
  end

  self:__execute_transfer__(pending_transfer, plans, target_dir)
end

---@protected
---@param pending_transfer              era.m.explorer.IPendingTransfer
---@param target_dir                    string
---@return era.m.explorer.action.ITransferPlan[]|nil
---@return string[]
function M:__build_transfer_plans__(pending_transfer, target_dir)
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local target_resource = ctx.resource_manager:locate(target_dir) ---@type era.m.explorer.resource.INode|nil
  if target_resource == nil or target_resource.nodetype ~= "D" then
    return nil, { string.format("Target is not an existing directory: %s", target_dir) }
  end

  local errors = {} ---@type string[]
  local plans = {} ---@type era.m.explorer.action.ITransferPlan[]
  local target_filepaths = {} ---@type table<string, boolean>

  ---@param source                      era.m.explorer.IPendingTransferSource
  ---@return era.m.explorer.action.ITransferPlan|nil
  ---@return string|nil
  local function build_plan(source)
    local current_source = ctx.resource_manager:locate(source.filepath) ---@type era.m.explorer.resource.INode|nil
    if current_source == nil then
      return nil, string.format("Source no longer exists: %s", source.filepath)
    end

    local is_directory = current_source.nodetype == "D" ---@type boolean
    local target_filepath = normalize_filepath(target_dir .. current_source.nodename, is_directory) ---@type string
    if is_directory and target_filepath:sub(-1) ~= "/" then
      target_filepath = target_filepath .. "/"
    end

    local source_comparable = normalize_filepath(current_source.filepath, false) ---@type string
    local target_comparable = normalize_filepath(target_filepath, false) ---@type string
    if source_comparable == target_comparable then
      return nil, string.format("Source is already in target directory: %s", current_source.filepath)
    end

    if is_directory and is_same_or_descendant(source_comparable, target_dir) then
      return nil, string.format("Cannot paste a directory into itself: %s", current_source.filepath)
    end

    if target_filepaths[target_comparable] then
      return nil, string.format("Multiple sources resolve to: %s", target_filepath)
    end
    target_filepaths[target_comparable] = true

    if ctx.resource_manager:locate(target_filepath) ~= nil then
      return nil, string.format("Target already exists: %s", target_filepath)
    end

    local plan = {
      source = {
        filepath = current_source.filepath,
        nodename = current_source.nodename,
        nodetype = current_source.nodetype,
      },
      target_filepath = target_filepath,
    } ---@type era.m.explorer.action.ITransferPlan
    return plan, nil
  end

  for _, source in ipairs(pending_transfer.sources) do
    local plan, err = build_plan(source)
    if plan ~= nil then
      plans[#plans + 1] = plan
    elseif err ~= nil then
      errors[#errors + 1] = err
    end
  end

  if #errors > 0 then
    return nil, errors
  end
  return plans, errors
end

---@protected
---@param pending_transfer              era.m.explorer.IPendingTransfer
---@param plans                         era.m.explorer.action.ITransferPlan[]
---@param target_dir                    string
---@return nil
function M:__execute_transfer__(pending_transfer, plans, target_dir)
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local is_move = pending_transfer.mode == "move" ---@type boolean
  local verb = is_move and "move" or "copy" ---@type string
  local verb_past = is_move and "Moved" or "Copied" ---@type string
  local failed_sources = {} ---@type era.m.explorer.IPendingTransferSource[]
  local failures = {} ---@type string[]
  local success_count = 0 ---@type integer

  for _, plan in ipairs(plans) do
    local ok ---@type boolean
    if is_move then
      ok = ctx.resource_manager:move(plan.source.filepath, plan.target_filepath)
    else
      ok = ctx.resource_manager:copy(plan.source.filepath, plan.target_filepath)
    end
    if ok then
      success_count = success_count + 1
    else
      failed_sources[#failed_sources + 1] = plan.source
      failures[#failures + 1] = string.format("%s -> %s", plan.source.filepath, plan.target_filepath)
    end
  end

  if success_count > 0 then
    ctx.tree:clear_selection()
    self:__set_pending_transfer__(#failed_sources > 0 and pending_transfer.mode or nil, failed_sources)
    ctx.tree:refresh(true)
    vim.schedule(function()
      ctx.refresh(true)
    end)
  end

  if #failed_sources == 0 then
    stl.reporter.info({
      from = ctx.fullname,
      subject = verb,
      message = string.format("%s %d item(s) to: %s", verb_past, success_count, target_dir),
    })
  elseif success_count > 0 then
    stl.reporter.warn({
      from = ctx.fullname,
      subject = verb,
      message = string.format("%s %d item(s), %d failed", verb_past, success_count, #failed_sources),
      details = { failures = failures },
    })
  else
    stl.reporter.error({
      from = ctx.fullname,
      subject = verb,
      message = string.format("Failed to %s %d item(s)", verb, #failed_sources),
      details = { failures = failures },
    })
  end
end

return M
