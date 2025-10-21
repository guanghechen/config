---@diagnostic disable: invisible
local name = "fml.action.find.lsp_symbols" ---@type string
local title = "LSP Symbols" ---@type string

local Methods = vim.lsp.protocol.Methods

---@class fml.action.find.lsp_symbols.ISymbolData
---@field public name                   string
---@field public kind                   string
---@field public icon                   string
---@field public icon_hln               string
---@field public lnum                   integer
---@field public col                    integer
---@field public end_lnum               integer
---@field public end_col                integer

local filepath_sourcefile = nil ---@type string|nil
local plainfile = eve.ux.view.Plainfile.new({ name = name }) ---@type eve.ux.view.Plainfile
local _tick_refresh = 0 ---@type integer

local WANT_SYMBOLS = {
  ["Class"] = true,
  ["Constructor"] = true,
  ["Enum"] = true,
  ["File"] = true,
  ["Function"] = true,
  ["Interface"] = true,
  ["Method"] = true,
  ["Module"] = true,
  ["Namespace"] = true,
  ["Package"] = true,
  ["Struct"] = true,
}

local TREESITTER_KIND_MAP = {
  constant = "Constant",
  enum = "Enum",
  field = "Field",
  ["function"] = "Function",
  macro = "Function",
  method = "Method",
  namespace = "Namespace",
  import = "Module",
  type = "Class",
  var = "Variable",
}

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@return boolean
local function client_supports_document_symbols(client, bufnr)
  if not client then
    return false
  end

  if client.supports_method and client:supports_method(Methods.textDocument_documentSymbol, bufnr) then
    return true
  end

  local capability = client.server_capabilities and client.server_capabilities.documentSymbolProvider or nil
  if capability == nil then
    return false
  end

  if type(capability) == "table" then
    return capability ~= false
  end

  return capability and capability ~= false
end

---@param bufnr                         integer
---@param callback                      fun(responses:{ client:vim.lsp.Client, result:lsp.Symbol[] }[]): nil
---@return nil
local function request_document_symbols(bufnr, callback)
  local clients = vim.lsp.get_clients({ bufnr = bufnr }) ---@type vim.lsp.Client[]
  local supported = {} ---@type vim.lsp.Client[]

  for _, client in ipairs(clients) do
    if client_supports_document_symbols(client, bufnr) then
      supported[#supported + 1] = client
    end
  end

  if vim.tbl_isempty(supported) then
    vim.b[bufnr].support_documentSymbol = 0
    callback({})
    return
  end

  vim.b[bufnr].support_documentSymbol = 1

  local pending = #supported ---@type integer
  local responses = {} ---@type { client:vim.lsp.Client, result:lsp.Symbol[] }[]
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
  }

  for _, client in ipairs(supported) do
    local ok, request_id = client:request(Methods.textDocument_documentSymbol, params, function(err, result)
      if not err and result then
        responses[#responses + 1] = { client = client, result = result }
      end

      pending = pending - 1
      if pending == 0 then
        callback(responses)
      end
    end, bufnr)

    if not ok or not request_id then
      pending = pending - 1
      if pending == 0 then
        callback(responses)
      end
    end
  end
end

---@param bufnr                         integer
---@param position                      lsp.Position
---@param encoding                      string?
---@return integer
local function lsp_position_to_col(bufnr, position, encoding)
  local ok, col = pcall(vim.lsp.util._get_line_byte_from_position, bufnr, position, encoding)
  if ok then
    return col
  end
  return position.character
end

---@param nodes                         table[]
---@return nil
local function sort_matches(nodes)
  table.sort(nodes, function(a, b)
    if a.pos[1] ~= b.pos[1] then
      return a.pos[1] < b.pos[1]
    end
    if a.pos[2] ~= b.pos[2] then
      return a.pos[2] < b.pos[2]
    end
    if a.end_pos[1] ~= b.end_pos[1] then
      return a.end_pos[1] < b.end_pos[1]
    end
    return a.end_pos[2] < b.end_pos[2]
  end)
end

---@param bufnr                         integer
---@return table[]
local function collect_treesitter_scopes(bufnr)
  local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not (ok_parser and parser) then
    return {}
  end

  parser:parse(true)

  local ok_query, query = pcall(vim.treesitter.query.get, parser:lang(), "locals")
  if not (ok_query and query) then
    return {}
  end

  local definitions = {} ---@type table[]
  local scopes = {} ---@type table<string, table>

  for _, tree in ipairs(parser:trees()) do
    for capture_id, node, metadata in query:iter_captures(tree:root(), bufnr) do
      local capture_name = query.captures[capture_id] ---@type string
      local range = { node:range() }
      local match = {
        id = node:id(),
        node = node,
        name = capture_name,
        meta = metadata,
        text = vim.treesitter.get_node_text(node, bufnr),
        pos = { range[1] + 1, range[2] },
        end_pos = { range[3] + 1, range[4] },
      }

      local kind = capture_name:match("^local%.definition%.(.*)$")
      if kind then
        match.kind = kind
        match.scope = metadata["definition.method.scope"] or "local"
        definitions[#definitions + 1] = match
      elseif capture_name == "local.scope" then
        match.kind = "scope"
        scopes[match.id] = match
      end
    end
  end

  ---@param node                        TSNode
  local function find_scope(node)
    local current = node:parent()
    while current do
      local scope = scopes[current:id()]
      if scope then
        return scope
      end
      current = current:parent()
    end
  end

  for _, def in ipairs(definitions) do
    local scope = find_scope(def.node)
    if scope then
      scope.children = scope.children or {}
      scope.children[#scope.children + 1] = def
    end
  end

  local roots = {} ---@type table[]
  for _, scope in pairs(scopes) do
    local parent_scope = find_scope(scope.node)
    if parent_scope then
      parent_scope.children = parent_scope.children or {}
      parent_scope.children[#parent_scope.children + 1] = scope
    else
      roots[#roots + 1] = scope
    end
  end

  sort_matches(roots)
  return roots
end

local o_finder_input = eve.context.select.lsp_symbols.input ---@type std.collection.IObservable
local o_flag_fuzzy = eve.context.select.lsp_symbols.flag_fuzzy ---@type std.collection.IObservable
local o_flag_regex = eve.context.select.lsp_symbols.flag_regex ---@type std.collection.IObservable
local o_flag_case_sensitive = eve.context.select.lsp_symbols.flag_case_sensitive ---@type std.collection.IObservable
local o_flag_viewtype = eve.context.select.lsp_symbols.flag_viewtype ---@type std.collection.IObservable
local o_flag_foldempty = eve.context.select.lsp_symbols.flag_foldempty ---@type std.collection.IObservable
local picker ---@type eve.ux.picker.TreeComposer

---@param tree                          std.collection.Tree
---@param callback                      fun(): nil
---@return nil
local function fetch_symbols(tree, callback)
  local bufnr = filepath_sourcefile and eve.buf.loadfile(filepath_sourcefile) or nil
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    callback()
    return
  end

  if not vim.api.nvim_buf_is_loaded(bufnr) then
    pcall(vim.fn.bufload, bufnr)
    vim.defer_fn(callback, 100)
    return
  end

  local tick_refresh = _tick_refresh ---@type integer

  local inserted = 0 ---@type integer
  local seen = {} ---@type table<string, boolean>
  local seq = 0 ---@type integer

  local function make_uuid(parent_uuid)
    seq = seq + 1
    return string.format("%s:%d", parent_uuid, seq)
  end

  ---@param parent_uuid                 string
  ---@param data                        fml.action.find.lsp_symbols.ISymbolData
  ---@return string|nil
  local function insert_node(parent_uuid, data)
    local name = data.name or "Unknown"
    local key = table.concat({
      data.kind or "Unknown",
      name,
      tostring(data.lnum or -1),
      tostring(data.col or -1),
      tostring(data.end_lnum or -1),
      tostring(data.end_col or -1),
    }, ":")

    if seen[key] then
      return nil
    end

    local uuid = make_uuid(parent_uuid)
    tree:insert(parent_uuid, uuid, data)
    seen[key] = true
    return uuid
  end

  ---@param symbol                      table
  ---@return lsp.Range?, lsp.Range?
  local function resolve_ranges(symbol)
    local selection = symbol.selectionRange
    local whole = symbol.range

    if symbol.location then
      local location = symbol.location
      selection = selection or location.targetSelectionRange or location.range
      whole = whole or location.targetRange or location.range or location.targetSelectionRange
    end

    selection = selection or whole
    whole = whole or selection

    return selection, whole
  end

  ---@param symbol                      table
  ---@param parent_uuid                 string
  ---@param client                      vim.lsp.Client
  local function handle_document_symbol(symbol, parent_uuid, client)
    local selection_range, whole_range = resolve_ranges(symbol)
    local start_pos = selection_range and selection_range.start or nil
    local end_pos = whole_range and whole_range["end"] or nil
    local kindname = vim.lsp.protocol.SymbolKind[symbol.kind] or "Unknown"

    local parent_for_children = parent_uuid

    if start_pos and end_pos then
      local lnum = start_pos.line + 1
      local col = lsp_position_to_col(bufnr, start_pos, client and client.offset_encoding or nil)
      local end_lnum = end_pos.line + 1
      local end_col = lsp_position_to_col(bufnr, end_pos, client and client.offset_encoding or nil)

      if WANT_SYMBOLS[kindname] then
        ---@class fml.action.find.lsp_symbols.ISymbolData
        local data = {
          name = symbol.name or "Unknown",
          kind = kindname,
          lnum = lnum,
          col = col,
          end_lnum = end_lnum,
          end_col = end_col,
          icon = eve.icon.kind[kindname] or "󰅩",
          icon_hln = "f_lsp_symbol_icon_" .. kindname,
        }
        local uuid = insert_node(parent_uuid, data)
        if uuid then
          inserted = inserted + 1
          parent_for_children = uuid
        end
      end
    end

    if symbol.children then
      for _, child in ipairs(symbol.children) do
        handle_document_symbol(child, parent_for_children, client)
      end
    end
  end

  ---@param symbol                      table
  ---@param parent_uuid                 string
  ---@param client                      vim.lsp.Client
  local function handle_symbol_information(symbol, parent_uuid, client)
    local selection_range, whole_range = resolve_ranges(symbol)
    local range = selection_range or whole_range
    if not range or not range.start or not range["end"] then
      return
    end

    local kindname = vim.lsp.protocol.SymbolKind[symbol.kind] or "Unknown"
    if not WANT_SYMBOLS[kindname] then
      return
    end

    local lnum = range.start.line + 1
    local col = lsp_position_to_col(bufnr, range.start, client and client.offset_encoding or nil)
    local end_lnum = range["end"].line + 1
    local end_col = lsp_position_to_col(bufnr, range["end"], client and client.offset_encoding or nil)
    local name = symbol.name or "Unknown"
    if symbol.containerName and symbol.containerName ~= "" then
      name = string.format("%s.%s", symbol.containerName, name)
    end

    ---@class fml.action.find.lsp_symbols.ISymbolData
    local data = {
      name = name,
      kind = kindname,
      lnum = lnum,
      col = col,
      end_lnum = end_lnum,
      end_col = end_col,
      icon = eve.icon.kind[kindname] or "󰅩",
      icon_hln = "f_lsp_symbol_icon_" .. kindname,
    }

    local uuid = insert_node(parent_uuid, data)
    if uuid then
      inserted = inserted + 1
    end
  end

  ---@param responses                   { client:vim.lsp.Client, result:lsp.Symbol[] }[]
  local function populate_from_lsp(responses)
    for _, response in ipairs(responses) do
      local result = response.result
      if result ~= nil and result ~= vim.NIL then
        local list = vim.tbl_islist(result) and result or { result }
        for _, symbol in ipairs(list) do
          if type(symbol) == "table" and symbol.kind then
            if symbol.children or symbol.selectionRange or symbol.range then
              handle_document_symbol(symbol, tree.root, response.client)
            elseif symbol.location then
              handle_symbol_information(symbol, tree.root, response.client)
            else
              handle_document_symbol(symbol, tree.root, response.client)
            end
          end
        end
      end
    end
  end

  local function populate_from_treesitter()
    local scopes = collect_treesitter_scopes(bufnr)

    local function visit(match, parent_uuid)
      local children = match.children or {}
      local parent_for_children = parent_uuid
      local kind = match.kind and TREESITTER_KIND_MAP[match.kind] or nil

      if kind and WANT_SYMBOLS[kind] and match.pos and match.end_pos then
        ---@class fml.action.find.lsp_symbols.ISymbolData
        local data = {
          name = match.text or "Unknown",
          kind = kind,
          lnum = match.pos[1],
          col = match.pos[2],
          end_lnum = match.end_pos[1],
          end_col = match.end_pos[2],
          icon = eve.icon.kind[kind] or "󰅩",
          icon_hln = "f_lsp_symbol_icon_" .. kind,
        }

        local uuid = insert_node(parent_uuid, data)
        if uuid then
          inserted = inserted + 1
          parent_for_children = uuid
        end
      end

      if #children > 0 then
        sort_matches(children)
        for _, child in ipairs(children) do
          visit(child, parent_for_children)
        end
      end
    end

    for _, scope in ipairs(scopes) do
      visit(scope, tree.root)
    end
  end

  local function finalize()
    if tick_refresh ~= _tick_refresh then
      return
    end
    callback()
  end

  request_document_symbols(bufnr, function(responses)
    if tick_refresh ~= _tick_refresh then
      return
    end

    populate_from_lsp(responses)
    if inserted > 0 then
      finalize()
      return
    end

    populate_from_treesitter()
    finalize()
  end)
end

---@return nil
local function refresh()
  local tree = picker._tree ---@type std.collection.Tree
  local treeview = picker._treeview ---@type eve.ux.picker.TreeView

  _tick_refresh = _tick_refresh + 1 ---@type integer
  local tick_refresh = _tick_refresh ---@type integer

  tree:clear()
  treeview:clear()

  fetch_symbols(tree, function()
    if _tick_refresh == tick_refresh then
      tree:quick_traverse(tree.root, function(_, node)
        -- Insert into treeview with appropriate nodestate
        local has_children = node.children and #node.children > 0
        local nodestate = {
          nodetype = has_children and "container" or "leaf",
          collapsed = false,
          tick_invisible = 0,
          tick_matched = 0,
          tick_selected = 0,
          tick_selected_maximum = 0,
          cache_treeview = nil,
        }
        treeview:insert(node.uuid, nodestate)
      end)

      picker:attach(tree.root)
      picker:mark_result_dirty()
    end
  end)
end

local function render_symbol(_, node)
  local data = node.data ---@type fml.action.find.lsp_symbols.ISymbolData
  local icon = data.icon or "●"
  local symbolname = data.name or "Unknown"
  local text = string.format("%s %s", icon, symbolname)
  local icon_end = #icon + 1

  return {
    text = text,
    highlights = {
      { coll = 0, colr = icon_end, hlname = data.icon_hln or "DiagnosticInfo" },
      { coll = icon_end, colr = #text, hlname = "f_lsp_symbol_text" },
    },
  }
end

---@type eve.ux.picker.view.tree.ITreeviewContainerNodeRenderer
local function render_treeview_container(_, node, _, _, folded_depth)
  if folded_depth == 0 then
    return render_symbol(_, node)
  end

  local N = folded_depth + 1 ---@type integer
  local items = {} ---@type fml.action.find.lsp_symbols.ISymbolData[]
  items[N] = node.data ---@type fml.action.find.lsp_symbols.ISymbolData

  local o = node ---@type std.collection.tree.INode
  for i = folded_depth, 1, -1 do
    local v = picker._tree:retrieve(o.parent)
    ---@cast v                          std.collection.tree.INode

    o = v
    items[i] = o.data ---@type fml.action.find.lsp_symbols.ISymbolData
  end

  local text = "" ---@type string
  local highlights = {} ---@type table[]
  local offset = 0 ---@type integer

  local sep = "  " ---@type string
  for i = 1, N, 1 do
    local item = items[i] ---@type fml.action.find.lsp_symbols.ISymbolData

    if i > 1 then
      text = text .. sep
      highlights[#highlights + 1] = {
        coll = offset,
        colr = offset + #sep,
        hlname = "f_lsp_symbol_sep",
      }
      offset = offset + #sep
    end

    local icon = item.icon or "●"
    local symbol_name = item.name or "Unknown"
    local part_text = string.format("%s %s", icon, symbol_name)

    text = text .. part_text
    highlights[#highlights + 1] = {
      coll = offset,
      colr = offset + #icon,
      hlname = item.icon_hln or "DiagnosticInfo",
    }
    highlights[#highlights + 1] = {
      coll = offset + #icon + 1,
      colr = offset + #part_text,
      hlname = "f_lsp_symbol_text",
    }

    offset = offset + #part_text
  end

  return {
    text = text,
    highlights = highlights,
  }
end

local function render_location(_, node)
  local symbol_data = node.data ---@type fml.action.find.lsp_symbols.ISymbolData
  if symbol_data and symbol_data.lnum then
    return {
      text = string.format(":%d", symbol_data.lnum),
      highlights = { { coll = 0, colr = 10, hlname = "LineNr" } },
    }
  end
  return { text = "", highlights = {} }
end

local function render_preview(bufnr, force)
  if not filepath_sourcefile then
    if force then
      local lines = { "No source file available for preview" }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end
    return {
      cursorline = true,
      number = true,
      title = "No Source File",
      wrap = false,
      whitespaces = nil,
      lnum = 1,
    }
  end

  local nodeuuid = picker:__retrieve_nodeuuid__() ---@type string|nil
  if not nodeuuid then
    if force then
      local lines = { "No symbol selected" }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end
    return {
      cursorline = true,
      number = true,
      title = "No Symbol Selected",
      wrap = false,
      whitespaces = nil,
      lnum = 1,
    }
  end

  local node = picker._tree:retrieve(nodeuuid) ---@type std.collection.tree.INode|nil
  if node == nil or node.data == nil then
    if force then
      local lines = { "Invalid symbol data" }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end
    return {
      cursorline = true,
      number = true,
      title = "Invalid Symbol",
      wrap = false,
      whitespaces = nil,
      lnum = 1,
    }
  end

  plainfile:render(bufnr, filepath_sourcefile, force)

  local nsnr = eve.var.nsnr.picker_preview_visual ---@type integer
  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)

  local data = node.data ---@type fml.action.find.lsp_symbols.ISymbolData
  if data.end_lnum and data.end_col and data.lnum and data.col then
    vim.hl.range(bufnr, nsnr, "Visual", { data.lnum - 1, data.col }, { data.end_lnum - 1, data.end_col })
  end

  return {
    cursorline = true,
    number = true,
    title = vim.fn.fnamemodify(filepath_sourcefile, ":t") .. ":" .. data.lnum,
    wrap = false,
    whitespaces = true,
    lnum = data.lnum,
    col = data.col,
  }
end

picker = eve.ux.picker.TreeComposer.new({
  name = name,
  permanent = true,
  title = title,
  height = 0.9,
  width = 0.9,
  node_sorter = function(a, b)
    local ad = a.data or {} ---@type fml.action.find.lsp_symbols.ISymbolData
    local bd = b.data or {} ---@type fml.action.find.lsp_symbols.ISymbolData

    local a_line = ad.lnum or 0
    local b_line = bd.lnum or 0
    if a_line == b_line then
      local a_col = ad.col or 0
      local b_col = bd.col or 0
      if a_col == b_col then
        local a_name = ad.name or ""
        local b_name = bd.name or ""
        if a_name == b_name then
          return (ad.kind or "") < (bd.kind or "")
        end
        return a_name < b_name
      end
      return a_col < b_col
    end
    return a_line < b_line
  end,

  finder_input = o_finder_input,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,
  flag_viewtype = o_flag_viewtype,
  flag_foldempty = o_flag_foldempty,
  flag_selected = std.Observable.from_value(false),

  -- Required renderer functions
  render_listview_leaf = render_symbol,
  render_listview_location = render_location,
  render_treeview_container = render_treeview_container,
  render_treeview_leaf = render_symbol,
  render_treeview_location = render_location,

  render_preview = render_preview,

  on_confirm = function(self, selected_uuids)
    if not selected_uuids or #selected_uuids == 0 then
      return
    end

    self:close()

    local node = picker._tree:retrieve(selected_uuids[1])
    if not (node and node.data and filepath_sourcefile) then
      return
    end

    local symbol_data = node.data ---@type fml.action.find.lsp_symbols.ISymbolData
    local target_bufnr = eve.buf.loadfile(filepath_sourcefile)
    if not target_bufnr then
      return
    end

    -- Find existing window or use current one
    local target_winid = vim.api.nvim_get_current_win()
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(winid) == target_bufnr then
        target_winid = winid
        break
      end
    end

    -- Navigate to symbol location
    vim.api.nvim_win_set_buf(target_winid, target_bufnr)
    vim.api.nvim_set_current_win(target_winid)
    vim.api.nvim_win_set_cursor(target_winid, { symbol_data.lnum, symbol_data.col })
    vim.cmd("normal! zv zz")
  end,

  on_refresh = refresh,
})

---@class fml.action.find
local M = {}

---@return nil
function M.find_lsp_symbols()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr = eve.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  local filepath = nil ---@type string|nil

  if bufnr ~= nil then
    local buftype = vim.bo[bufnr].buftype ---@type string
    if buftype == "" or buftype == "nowrite" then
      filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      if filepath == "" then
        filepath = nil
      end
    end
  end

  local dirty = filepath ~= filepath_sourcefile ---@type boolean
  filepath_sourcefile = filepath

  picker:focus()

  if dirty then
    refresh()
  end
end

return M
