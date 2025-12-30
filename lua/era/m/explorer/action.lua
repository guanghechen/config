---@class era.m.explorer.Action
---@field protected _ctx                era.m.explorer.action.IContext
local M = {}
M.__index = M

---@param ctx                           era.m.explorer.action.IContext
---@return era.m.explorer.Action
function M.new(ctx)
  local self = setmetatable({}, M)
  self._ctx = ctx
  return self
end

---@return nil
function M:add_locations_to_ai()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local selected_nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]

  local locations = {} ---@type dot.t.ILocation[]
  if #selected_nodes > 0 then
    for _, node in ipairs(selected_nodes) do
      local filepath = yoz.uri.to_filepath(node.uri) or "" ---@type string
      locations[#locations + 1] = { filepath = filepath }
    end
  else
    local uri = ctx.get_cursor_uri() ---@type string|nil
    if uri == nil then
      return
    end
    local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
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
    local filepath = yoz.uri.to_filepath(node.uri) or "" ---@type string
    locations[#locations + 1] = { filepath = filepath }
  end

  era.fn.add_locations_to_ai(locations)
end

---@return nil
function M:collapse_all()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local root_uri = ctx.tree.o_root_uri:snapshot() ---@type string
  ctx.tree:toggle_expanded(root_uri, true, "collapse")
  ctx.tree:toggle_expanded(root_uri, false, "expand")
  ctx.refresh()
end

---@return nil
function M:collapse_or_parent()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local root_uri = ctx.tree.o_root_uri:snapshot() ---@type string
  if uri:sub(-1) == "/" then
    local node = ctx.tree:locate(uri) ---@type era.m.explorer.Node|nil
    if node ~= nil and node.expanded then
      ctx.tree:toggle_expanded(uri, false, "collapse")
      ctx.refresh()
      return
    end
  end

  local parent_uri = ctx.get_parent_uri(uri) ---@type string
  if parent_uri ~= root_uri then
    ctx.tree.o_cursor_uri:next(parent_uri)
    ctx.sync_cursor_to_uri(parent_uri)
  end
end

---@return nil
function M:copy_node()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local selected_nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]
  if #selected_nodes > 0 then
    local current_mode = ctx.tree.select_mode ---@type era.m.explorer.SelectModeEnum
    local is_selected = ctx.tree:is_selected(uri) ---@type boolean

    if current_mode == "copy" and is_selected then
      ctx.tree:toggle_selected(uri, "unselect")
    else
      ctx.tree:toggle_selected(uri, "select")
    end

    ctx.tree.select_mode = "copy"
    ctx.refresh()
    return
  end

  local filepath = yoz.uri.to_filepath(uri) or "" ---@type string

  vim.ui.input({ prompt = "Copy to: ", default = filepath }, function(input)
    if input == nil or input == "" or input == filepath then
      return
    end

    local target_uri = yoz.uri.from_filepath(input) ---@type string
    local ok = ctx.resource_manager:copy(uri, target_uri) ---@type boolean
    if ok then
      ctx.tree:refresh(true)
      vim.schedule(function()
        ctx.refresh(true)
        ctx.sync_cursor_to_uri(target_uri)
      end)
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
      local filepath = yoz.uri.to_filepath(node.uri) or "" ---@type string
      filepaths[#filepaths + 1] = filepath
    end
  else
    local uri = ctx.get_cursor_uri() ---@type string|nil
    if uri == nil then
      return
    end
    local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
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
function M:copy_visual()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local nodes = ctx.get_visual_nodes() ---@type era.m.explorer.Node[]
  if #nodes == 0 then
    return
  end

  local current_mode = ctx.tree.select_mode ---@type era.m.explorer.SelectModeEnum
  if current_mode ~= "copy" then
    for _, node in ipairs(nodes) do
      ctx.tree:toggle_selected(node.uri, "select")
    end
    ctx.tree.select_mode = "copy"
  else
    local has_unselected = false ---@type boolean
    for _, node in ipairs(nodes) do
      if not node.selected then
        has_unselected = true
        break
      end
    end

    if has_unselected then
      for _, node in ipairs(nodes) do
        ctx.tree:toggle_selected(node.uri, "select")
      end
    else
      for _, node in ipairs(nodes) do
        ctx.tree:toggle_selected(node.uri, "unselect")
      end
    end
  end
  ctx.refresh()
end

---@return nil
function M:create_directory()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local cursor_uri = ctx.get_cursor_uri() ---@type string|nil
  if cursor_uri == nil then
    return
  end

  local parent_uri = cursor_uri:sub(-1) == "/" and cursor_uri or ctx.get_parent_uri(cursor_uri) ---@type string
  local root_uri = ctx.tree.o_root_uri:snapshot() ---@type string
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
    local resource = ctx.resource_manager:create(new_uri) ---@type era.m.explorer.resource.INode|nil
    if resource ~= nil then
      local new_parent_uri = ctx.get_parent_uri(new_uri) ---@type string
      ctx.tree:toggle_expanded(new_parent_uri, false, "expand")
      local parts = vim.split(dirname:sub(1, -2), "/", { plain = true }) ---@type string[]
      local intermediate_uri = root_uri ---@type string
      for _, part in ipairs(parts) do
        intermediate_uri = intermediate_uri .. part .. "/"
        ctx.tree:toggle_expanded(intermediate_uri, false, "expand")
      end
      ctx.tree:refresh(true)
      vim.schedule(function()
        ctx.render()
        ctx.sync_cursor_to_uri(new_uri)
      end)
    end
  end)
end

---@return nil
function M:create_file()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local cursor_uri = ctx.get_cursor_uri() ---@type string|nil
  if cursor_uri == nil then
    return
  end

  local parent_uri = cursor_uri:sub(-1) == "/" and cursor_uri or ctx.get_parent_uri(cursor_uri) ---@type string
  local root_uri = ctx.tree.o_root_uri:snapshot() ---@type string
  local relative_path = parent_uri:sub(#root_uri + 1) ---@type string

  vim.ui.input({ prompt = "Create file: ", default = relative_path }, function(input)
    if input == nil or #vim.trim(input) == 0 then
      return
    end

    local filename = vim.trim(input) ---@type string
    local new_uri = root_uri .. filename ---@type string
    local resource = ctx.resource_manager:create(new_uri) ---@type era.m.explorer.resource.INode|nil
    if resource ~= nil then
      local new_parent_uri = ctx.get_parent_uri(new_uri) ---@type string
      ctx.tree:toggle_expanded(new_parent_uri, false, "expand")
      local parts = vim.split(filename, "/", { plain = true }) ---@type string[]
      if #parts > 1 then
        local intermediate_uri = root_uri ---@type string
        for i = 1, #parts - 1 do
          intermediate_uri = intermediate_uri .. parts[i] .. "/"
          ctx.tree:toggle_expanded(intermediate_uri, false, "expand")
        end
      end
      ctx.tree:refresh(true)
      vim.schedule(function()
        ctx.render()
        ctx.sync_cursor_to_uri(new_uri)
      end)
    end
  end)
end

---@return nil
function M:cut()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local selected_nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]
  if #selected_nodes > 0 then
    local current_mode = ctx.tree.select_mode ---@type era.m.explorer.SelectModeEnum
    local is_selected = ctx.tree:is_selected(uri) ---@type boolean

    if current_mode == "cut" and is_selected then
      ctx.tree:toggle_selected(uri, "unselect")
    else
      ctx.tree:toggle_selected(uri, "select")
    end

    ctx.tree.select_mode = "cut"
    ctx.refresh()
    return
  end

  local filepath = yoz.uri.to_filepath(uri) or "" ---@type string

  vim.ui.input({ prompt = "Move to: ", default = filepath }, function(input)
    if input == nil or input == "" or input == filepath then
      return
    end

    local target_uri = yoz.uri.from_filepath(input) ---@type string
    local ok = ctx.resource_manager:move(uri, target_uri) ---@type boolean
    if ok then
      ctx.tree:remove(uri)
      ctx.tree:refresh(true)
      vim.schedule(function()
        ctx.refresh(true)
        ctx.sync_cursor_to_uri(target_uri)
      end)
    end
  end)
end

---@return nil
function M:cut_visual()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local nodes = ctx.get_visual_nodes() ---@type era.m.explorer.Node[]
  if #nodes == 0 then
    return
  end

  local current_mode = ctx.tree.select_mode ---@type era.m.explorer.SelectModeEnum
  if current_mode ~= "cut" then
    for _, node in ipairs(nodes) do
      ctx.tree:toggle_selected(node.uri, "select")
    end
    ctx.tree.select_mode = "cut"
  else
    local has_unselected = false ---@type boolean
    for _, node in ipairs(nodes) do
      if not node.selected then
        has_unselected = true
        break
      end
    end

    if has_unselected then
      for _, node in ipairs(nodes) do
        ctx.tree:toggle_selected(node.uri, "select")
      end
    else
      for _, node in ipairs(nodes) do
        ctx.tree:toggle_selected(node.uri, "unselect")
      end
    end
  end
  ctx.refresh()
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

      local deleted_count = 0 ---@type integer
      for _, node in ipairs(selected_nodes) do
        local ok = ctx.tree:remove(node.uri) ---@type boolean
        if ok then
          deleted_count = deleted_count + 1
        end
      end

      if deleted_count > 0 then
        ctx.tree:clear_selection()
        vim.schedule(function()
          ctx.refresh()
        end)

        stl.reporter.info({
          from = ctx.fullname,
          subject = "delete",
          message = string.format("Deleted %d item(s)", deleted_count),
        })
      end
    end)
    return
  end

  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local is_directory = uri:sub(-1) == "/" ---@type boolean
  local name ---@type string
  if is_directory then
    local parts = vim.split(uri:sub(1, -2), "/") ---@type string[]
    name = parts[#parts] or uri
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

    local ok = ctx.tree:remove(uri) ---@type boolean
    if ok then
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

    local deleted_count = 0 ---@type integer
    for _, node in ipairs(nodes) do
      local ok = ctx.tree:remove(node.uri) ---@type boolean
      if ok then
        deleted_count = deleted_count + 1
      end
    end

    if deleted_count > 0 then
      vim.schedule(function()
        ctx.refresh()
      end)

      stl.reporter.info({
        from = ctx.fullname,
        subject = "delete",
        message = string.format("Deleted %d item(s)", deleted_count),
      })
    end
  end)
end

---@return nil
function M:delete_selected()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local selected_nodes = ctx.tree:get_selected_nodes_toplevel() ---@type era.m.explorer.Node[]
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
    local filepath = yoz.uri.to_filepath(node.uri) or "" ---@type string
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

      local deleted_count = 0 ---@type integer
      for _, node in ipairs(selected_nodes) do
        local ok = ctx.tree:remove(node.uri) ---@type boolean
        if ok then
          deleted_count = deleted_count + 1
        end
      end

      if deleted_count > 0 then
        ctx.tree:clear_selection()
        vim.schedule(function()
          ctx.refresh()
        end)

        stl.reporter.info({
          from = fullname,
          subject = "delete",
          message = string.format("Deleted %d item(s)", deleted_count),
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
  local root_uri = yoz.uri.from_filepath(cwd .. "/") ---@type string
  ctx.widget:set_root(root_uri)
end

---@return nil
function M:go_home()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local workspace = dot.path.workspace() ---@type string
  local root_uri = yoz.uri.from_filepath(workspace .. "/") ---@type string
  ctx.widget:set_root(root_uri)
end

---@return nil
function M:go_parent()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local root_uri = ctx.tree.o_root_uri:snapshot() ---@type string
  local parent_uri = ctx.get_parent_uri(root_uri) ---@type string

  if parent_uri ~= root_uri then
    ctx.widget:set_root(parent_uri)
  end
end

---@return nil
function M:go_prev()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local prev_root_uri = ctx.tree.prev_root_uri ---@type string|nil
  if prev_root_uri == nil then
    return
  end
  ctx.widget:set_root(prev_root_uri)
end

---@return nil
function M:jump_last_child()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  if uri:sub(-1) ~= "/" then
    return
  end

  local node = ctx.tree:locate(uri) ---@type era.m.explorer.Node|nil
  if node == nil or not node.expanded or #node.children == 0 then
    return
  end

  local last_child = node.children[#node.children] ---@type era.m.explorer.Node
  local target_uri = last_child.uri ---@type string
  ctx.tree.o_cursor_uri:next(target_uri)
  ctx.sync_cursor_to_uri(target_uri)
end

---@return nil
function M:jump_parent()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local parent_uri = ctx.get_parent_uri(uri) ---@type string
  local root_uri = ctx.tree.o_root_uri:snapshot() ---@type string

  if parent_uri ~= uri and vim.startswith(parent_uri, root_uri) then
    ctx.tree.o_cursor_uri:next(parent_uri)
    ctx.sync_cursor_to_uri(parent_uri)
  end
end

---@return nil
function M:mark()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  ctx.tree:toggle_selected(uri, nil)
  ctx.tree.select_mode = "select"
  ctx.refresh()
end

---@return nil
function M:mark_visual()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local nodes = ctx.get_visual_nodes() ---@type era.m.explorer.Node[]
  if #nodes == 0 then
    return
  end

  local has_unselected = false ---@type boolean
  for _, node in ipairs(nodes) do
    if not node.selected then
      has_unselected = true
      break
    end
  end

  if has_unselected then
    for _, node in ipairs(nodes) do
      ctx.tree:toggle_selected(node.uri, "select")
    end
  else
    for _, node in ipairs(nodes) do
      ctx.tree:toggle_selected(node.uri, "unselect")
    end
  end
  ctx.refresh()
end

---@return nil
function M:open()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  if uri:sub(-1) == "/" then
    ctx.tree:toggle_expanded(uri, false, nil)
    ctx.refresh()
  else
    local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
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
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
  era.fn.find_explorer(filepath)
end

---@return nil
function M:open_file_finder()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local dirpath ---@type string
  if uri:sub(-1) == "/" then
    dirpath = yoz.uri.to_filepath(uri) or ""
  else
    dirpath = dot.path.dirname(yoz.uri.to_filepath(uri) or "")
  end

  era.fn.find_files(dirpath, true)
end

---@return nil
function M:open_searcher()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
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
    local filepath = yoz.uri.to_filepath(node.uri) or "" ---@type string
    dot.win.open_filepath(winnr_sourcefile, filepath)
  end

  ctx.tree:clear_selection()
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
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil or uri:sub(-1) == "/" then
    return
  end

  local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
  vim.cmd("split " .. vim.fn.fnameescape(filepath))
end

---@return nil
function M:open_system_explorer()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
  vim.ui.open(filepath)
end

---@return nil
function M:open_tab()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil or uri:sub(-1) == "/" then
    return
  end

  local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
  vim.cmd("tabnew " .. vim.fn.fnameescape(filepath))
end

---@return nil
function M:open_vsplit()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil or uri:sub(-1) == "/" then
    return
  end

  local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
  vim.cmd("vsplit " .. vim.fn.fnameescape(filepath))
end

---@param winnr                         integer|nil
---@return nil
function M:pick_win_open(winnr)
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil or uri:sub(-1) == "/" then
    return
  end

  local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
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
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil or uri:sub(-1) == "/" then
    return
  end

  local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
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
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil or uri:sub(-1) == "/" then
    return
  end

  local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
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
  local selected_nodes = ctx.tree:get_selected_nodes() ---@type era.m.explorer.Node[]

  if #selected_nodes > 1 then
    stl.reporter.warn({
      from = ctx.fullname,
      subject = "rename",
      message = "Cannot rename multiple files at once. Please select only one file.",
    })
    return
  end

  local uri ---@type string|nil
  if #selected_nodes == 1 then
    uri = selected_nodes[1].uri
  else
    uri = ctx.get_cursor_uri()
  end

  if uri == nil then
    return
  end

  local root_uri = ctx.tree.o_root_uri:snapshot() ---@type string
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

    local ok = ctx.resource_manager:move(uri, new_uri) ---@type boolean
    if ok then
      if #selected_nodes == 1 then
        ctx.tree:clear_selection()
      end
      ctx.tree:refresh(true)
      vim.schedule(function()
        ctx.refresh(true)
      end)
      stl.reporter.info({
        from = ctx.fullname,
        subject = "rename",
        message = string.format("Renamed to: %s", new_relative_path),
      })
    end
  end)
end

---@return nil
function M:select_toggle()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  ctx.tree:toggle_selected(uri, nil)
  ctx.tree.select_mode = "select"
  ctx.refresh()
end

---@param root                          era.m.explorer.Node
---@return nil
function M:send_to_quickfix(root)
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local selected_nodes = require("era.m.explorer.node").collect_selected(root) ---@type era.m.explorer.Node[]

  if #selected_nodes == 0 then
    local uri = ctx.get_cursor_uri() ---@type string|nil
    if uri == nil then
      return
    end
    local filepath = yoz.uri.to_filepath(uri) or "" ---@type string
    vim.fn.setqflist({}, "r", {
      title = "Explorer",
      items = { { filename = filepath, lnum = 1, col = 1 } },
    })
  else
    local items = {} ---@type table[]
    for _, node in ipairs(selected_nodes) do
      local filepath = yoz.uri.to_filepath(node.uri) or "" ---@type string
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
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  if uri:sub(-1) ~= "/" then
    uri = ctx.get_parent_uri(uri)
  end

  ctx.widget:set_root(uri)
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
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local filepath = yoz.uri.to_filepath(uri) or "" ---@type string

  local fileinfo = era.view.Fileinfo.new({ filepath = filepath })
  fileinfo:open()
end

---@param target_mode                   era.m.explorer.SelectModeEnum
---@return nil
function M:toggle_select_mode(target_mode)
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  local current_mode = ctx.tree.select_mode ---@type era.m.explorer.SelectModeEnum
  local is_selected = ctx.tree:is_selected(uri) ---@type boolean

  if is_selected then
    if current_mode == target_mode then
      ctx.tree:toggle_selected(uri, "unselect")
    else
      ctx.tree.select_mode = target_mode
    end
  else
    ctx.tree:toggle_selected(uri, "select")
    ctx.tree.select_mode = target_mode
  end

  ctx.refresh()
end

---@param target_mode                   era.m.explorer.SelectModeEnum
---@return nil
function M:toggle_select_mode_visual(target_mode)
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local nodes = ctx.get_visual_nodes() ---@type era.m.explorer.Node[]
  if #nodes == 0 then
    return
  end

  local current_mode = ctx.tree.select_mode ---@type era.m.explorer.SelectModeEnum
  local all_selected = true ---@type boolean

  for _, node in ipairs(nodes) do
    if not node.selected then
      all_selected = false
      break
    end
  end

  if all_selected then
    if current_mode == target_mode then
      for _, node in ipairs(nodes) do
        ctx.tree:toggle_selected(node.uri, "unselect")
      end
    else
      ctx.tree.select_mode = target_mode
    end
  else
    for _, node in ipairs(nodes) do
      ctx.tree:toggle_selected(node.uri, "select")
    end
    ctx.tree.select_mode = target_mode
  end

  ctx.refresh()
end

---@return nil
function M:toggle_recursive()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local uri = ctx.get_cursor_uri() ---@type string|nil
  if uri == nil then
    return
  end

  if uri:sub(-1) ~= "/" then
    return
  end

  ctx.tree:toggle_expanded(uri, true, nil)
  ctx.refresh()
end

---@class era.m.explorer.action.IPreviewItem
---@field public from                   string
---@field public to                     string
---@field public relative_part          string

---@alias era.m.explorer.action.TransferModeEnum
---| "move"
---| "copy"

---@return nil
function M:move_selected()
  self:__transfer_selected__("move", nil)
end

---@return nil
function M:copy_selected()
  self:__transfer_selected__("copy", nil)
end

---@return nil
function M:paste()
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local select_mode = ctx.tree.select_mode ---@type era.m.explorer.SelectModeEnum

  if select_mode == "select" then
    stl.reporter.warn({
      from = ctx.fullname,
      subject = "paste",
      message = "No cut/copy operation pending",
    })
    return
  end

  local cursor_uri = ctx.get_cursor_uri() ---@type string|nil
  if cursor_uri == nil then
    return
  end

  local target_dir_uri = cursor_uri:sub(-1) == "/" and cursor_uri or ctx.get_parent_uri(cursor_uri) ---@type string
  local target_dir = yoz.uri.to_filepath(target_dir_uri) or "" ---@type string

  local mode = select_mode == "cut" and "move" or "copy" ---@type era.m.explorer.action.TransferModeEnum
  self:__transfer_selected__(mode, target_dir)
end

----------------------------------------------------------------------------------------------------

---@protected
---@param mode                          era.m.explorer.action.TransferModeEnum
---@param initial_target                string|nil
---@return nil
function M:__transfer_selected__(mode, initial_target)
  local ctx = self._ctx ---@type era.m.explorer.action.IContext
  local selected_nodes = ctx.tree:get_selected_nodes_toplevel() ---@type era.m.explorer.Node[]
  if #selected_nodes == 0 then
    stl.reporter.warn({
      from = ctx.fullname,
      subject = mode .. " selected",
      message = "No files selected",
    })
    return
  end

  local common_ancestor = ctx.tree:get_common_ancestor_path(selected_nodes) ---@type string|nil
  if common_ancestor == nil then
    return
  end

  local is_move = mode == "move" ---@type boolean
  local icon = is_move and stl.icon.symbols.selection_cut or stl.icon.symbols.selection_copy ---@type string
  local arrow = is_move and " -> " or " +> " ---@type string
  local verb_past = is_move and "Moved" or "Copied" ---@type string
  local verb_inf = is_move and "move" or "copy" ---@type string

  local cwd = dot.path.cwd() ---@type string
  local default_target = initial_target and dot.path.relative(cwd, initial_target) or dot.path.relative(cwd, common_ancestor) ---@type string
  local ns = vim.api.nvim_create_namespace("explorer_" .. mode .. "_preview") ---@type integer

  ---@return integer
  local function calc_content_width()
    local max_width = 0 ---@type integer
    for _, node in ipairs(selected_nodes) do
      local filepath = yoz.uri.to_filepath(node.uri) or "" ---@type string
      local from_relative = dot.path.relative(cwd, filepath) ---@type string
      local line_width = vim.fn.strdisplaywidth(from_relative) * 2 + 4 ---@type integer
      max_width = math.max(max_width, line_width)
    end
    return max_width + 4
  end

  ---@param target_dir                  string
  ---@return era.m.explorer.action.IPreviewItem[]
  ---@return integer                     max_from_display_width
  local function build_preview_items(target_dir)
    local items = {} ---@type era.m.explorer.action.IPreviewItem[]
    local max_from_display_width = 0 ---@type integer

    for _, node in ipairs(selected_nodes) do
      local filepath = yoz.uri.to_filepath(node.uri) or "" ---@type string
      local relative_part = dot.path.relative(common_ancestor, filepath) ---@type string
      local from_relative = dot.path.relative(cwd, filepath) ---@type string
      local target_path = dot.path.join(target_dir, relative_part) ---@type string
      local to_relative = dot.path.relative(cwd, target_path) ---@type string
      items[#items + 1] = { from = from_relative, to = to_relative, relative_part = relative_part }
      max_from_display_width = math.max(max_from_display_width, vim.fn.strdisplaywidth(from_relative))
    end

    return items, max_from_display_width
  end

  local fullname = ctx.fullname ---@type string

  ---@type era.view.Act
  local act = era.view.Act.new({
    name = "explorer_" .. mode,
    title = string.format("%s %s %d item(s)", icon, verb_past:gsub("ed$", ""), #selected_nodes),
    initial_input = default_target,
    preview_lines = #selected_nodes,
    get_width = calc_content_width,
    render_preview = function(bufnr, input)
      local target_dir = vim.trim(input) ---@type string
      if target_dir == "" then
        target_dir = default_target
      end
      if not yoz.path.is_absolute(target_dir) then
        target_dir = dot.path.resolve(cwd, target_dir)
      end
      target_dir = dot.path.normalize(target_dir)

      local items, max_from_display_width = build_preview_items(target_dir)

      local lines = {} ---@type string[]
      for _, item in ipairs(items) do
        local padding = string.rep(" ", max_from_display_width - vim.fn.strdisplaywidth(item.from)) ---@type string
        lines[#lines + 1] = string.format("%s%s%s%s", item.from, padding, arrow, item.to)
      end

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

      for lnum, item in ipairs(items) do
        local padding = string.rep(" ", max_from_display_width - vim.fn.strdisplaywidth(item.from)) ---@type string
        local from_hl_start = #item.from - #item.relative_part ---@type integer
        local from_hl_end = #item.from ---@type integer
        local to_hl_start = #item.from + #padding + #arrow + #item.to - #item.relative_part ---@type integer
        local to_hl_end = #item.from + #padding + #arrow + #item.to ---@type integer
        vim.hl.range(bufnr, ns, "m_pk_matches", { lnum - 1, from_hl_start }, { lnum - 1, from_hl_end })
        vim.hl.range(bufnr, ns, "m_pk_matches", { lnum - 1, to_hl_start }, { lnum - 1, to_hl_end })
      end
    end,
    on_confirm = function(input)
      if input == "" then
        return
      end

      local target_dir = input ---@type string
      if not yoz.path.is_absolute(target_dir) then
        target_dir = dot.path.resolve(cwd, target_dir)
      end
      target_dir = dot.path.normalize(target_dir)
      if target_dir:sub(-1) ~= "/" then
        target_dir = target_dir .. "/"
      end

      local success_count = 0 ---@type integer
      local failed_count = 0 ---@type integer

      for _, node in ipairs(selected_nodes) do
        local filepath = yoz.uri.to_filepath(node.uri) or "" ---@type string

        local relative_path = dot.path.relative(common_ancestor, filepath) ---@type string
        local target_path = dot.path.join(target_dir, relative_path) ---@type string
        local is_directory = node.nodetype == "D" ---@type boolean
        local target_uri = yoz.uri.from_filepath(target_path) ---@type string
        if is_directory and target_uri:sub(-1) ~= "/" then
          target_uri = target_uri .. "/"
        end

        local ok ---@type boolean
        if is_move then
          ok = ctx.resource_manager:move(node.uri, target_uri)
          if ok then
            ctx.tree:remove(node.uri)
          end
        else
          ok = ctx.resource_manager:copy(node.uri, target_uri)
        end

        if ok then
          success_count = success_count + 1
        else
          failed_count = failed_count + 1
        end
      end

      if success_count > 0 then
        ctx.tree:clear_selection()
        ctx.tree:refresh(true)
        vim.schedule(function()
          ctx.refresh(true)
        end)

        if failed_count > 0 then
          stl.reporter.warn({
            from = fullname,
            subject = verb_inf,
            message = string.format("%s %d item(s), %d failed", verb_past, success_count, failed_count),
          })
        else
          stl.reporter.info({
            from = fullname,
            subject = verb_inf,
            message = string.format("%s %d item(s)", verb_past, success_count),
          })
        end
      elseif failed_count > 0 then
        stl.reporter.error({
          from = fullname,
          subject = verb_inf,
          message = string.format("Failed to %s %d item(s)", verb_inf, failed_count),
        })
      end
    end,
  })
  act:open()
end

return M
