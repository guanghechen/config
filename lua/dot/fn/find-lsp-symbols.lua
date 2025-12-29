---@diagnostic disable: invisible
local name = "dot.fn.find_lsp_symbols" ---@type string
local title = "LSP Symbols" ---@type string

---@class dot.fn.find_lsp_symbols.ISymbolData
---@field public name                   string
---@field public kind                   string
---@field public icon                   string
---@field public icon_hln               string
---@field public lnum                   integer
---@field public col                    integer
---@field public end_lnum               integer
---@field public end_col                integer
---@field public selection_lnum         integer?
---@field public selection_col          integer?

local filepath_sourcefile = nil ---@type string|nil
local plainfile = era.view.Plainfile.new({ name = name }) ---@type era.view.Plainfile
local _tick_refresh = 0 ---@type integer

-- stylua: ignore
local KIND_FILTER_DEFAULT = {
  Class       = true,
  Constructor = true,
  Enum        = true,
  Function    = true,
  Interface   = true,
  Method      = true,
  Module      = true,
  Namespace   = true,
  Package     = true,
  Struct      = true,
}

-- stylua: ignore
local KIND_FILTER_BY_FT = {
  lua = {
    Class    = true,
    Function = true,
    Method   = true,
    Module   = true,
  },
  python = {
    Class       = true,
    Constructor = true,
    Function    = true,
    Method      = true,
    Module      = true,
  },
  go = {
    Function  = true,
    Interface = true,
    Method    = true,
    Struct    = true,
  },
  rust = {
    Enum      = true,
    Function  = true,
    Interface = true,
    Method    = true,
    Module    = true,
    Struct    = true,
  },
  javascript = {
    Class       = true,
    Constructor = true,
    Function    = true,
    Interface   = true,
    Method      = true,
    Module      = true,
  },
  typescript = {
    Class       = true,
    Constructor = true,
    Enum        = true,
    Function    = true,
    Interface   = true,
    Method      = true,
    Module      = true,
  },
  typescriptreact = {
    Class       = true,
    Constructor = true,
    Enum        = true,
    Function    = true,
    Interface   = true,
    Method      = true,
    Module      = true,
  },
  javascriptreact = {
    Class       = true,
    Constructor = true,
    Function    = true,
    Interface   = true,
    Method      = true,
    Module      = true,
  },
  json = {
    Module = true,
  },
  markdown = {
    Module = true,
  },
}

---@param bufnr                         integer|nil
---@return table<string, boolean>
local function get_kind_filter(bufnr)
  if not bufnr then
    return KIND_FILTER_DEFAULT
  end
  local ft = vim.bo[bufnr].filetype
  return KIND_FILTER_BY_FT[ft] or KIND_FILTER_DEFAULT
end

-- stylua: ignore
local TS_KIND_MAP = {
  constant   = "Constant",
  enum       = "Enum",
  field      = "Field",
  ["function"] = "Function",
  macro      = "Function",
  method     = "Method",
  namespace  = "Namespace",
  import     = "Module",
  type       = "Class",
  var        = "Variable",
}

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@return boolean
local function supports_document_symbols(client, bufnr)
  if not client then
    return false
  end
  if client.supports_method and client:supports_method("textDocument/documentSymbol", bufnr) then
    return true
  end
  local cap = client.server_capabilities and client.server_capabilities.documentSymbolProvider
  return cap ~= nil and cap ~= false
end

---@param bufnr                         integer
---@param callback                      fun(responses:{ client:vim.lsp.Client, result:lsp.DocumentSymbol[]|lsp.SymbolInformation[] }[]): nil
local function request_document_symbols(bufnr, callback)
  local clients = vim.lsp.get_clients({ bufnr = bufnr }) ---@type vim.lsp.Client[]
  local supported = vim.tbl_filter(function(c)
    return supports_document_symbols(c, bufnr)
  end, clients)

  if #supported == 0 then
    vim.b[bufnr].support_documentSymbol = 0
    callback({})
    return
  end

  vim.b[bufnr].support_documentSymbol = 1

  local pending = #supported ---@type integer
  local responses = {} ---@type { client:vim.lsp.Client, result:lsp.DocumentSymbol[]|lsp.SymbolInformation[] }[]
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }

  for _, client in ipairs(supported) do
    local ok, request_id = client:request("textDocument/documentSymbol", params, function(err, result)
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
  return ok and col or position.character
end

---@param symbol_name                   string
---@return string
local function clean_symbol_name(symbol_name)
  return (string.gsub(symbol_name, "\n.*", ""))
end

---@param bufnr                         integer
---@param lnum                          integer
---@param col                           integer
---@return integer
local function fix_col_position(bufnr, lnum, col)
  local lines = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)
  if #lines == 0 then
    return col
  end
  local line_len = #lines[1]
  if col > line_len then
    return line_len
  end
  return col
end

---@param nodes                         table[]
local function sort_by_position(nodes)
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
local function get_treesitter_locals(bufnr)
  local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok_parser or not parser then
    return {}
  end

  parser:parse(true)

  local ok_query, query = pcall(vim.treesitter.query.get, parser:lang(), "locals")
  if not ok_query or not query then
    return {}
  end

  local defs = {} ---@type table[]
  local scopes = {} ---@type table<string, table>

  for _, tree in ipairs(parser:trees()) do
    for id, node, meta in query:iter_captures(tree:root(), bufnr) do
      local capture = query.captures[id] ---@type string
      local range = { node:range() }
      local match = {
        id = node:id(),
        node = node,
        text = vim.treesitter.get_node_text(node, bufnr),
        pos = { range[1] + 1, range[2] },
        end_pos = { range[3] + 1, range[4] },
      }

      local kind = capture:match("^local%.definition%.(.*)$")
      if kind then
        match.kind = kind
        match.scope = meta["definition.method.scope"] or "local"
        defs[#defs + 1] = match
      elseif capture == "local.scope" then
        match.kind = "scope"
        scopes[match.id] = match
      end
    end
  end

  ---@param node                        TSNode
  local function find_scope(node)
    local n = node:parent()
    while n do
      if scopes[n:id()] then
        return scopes[n:id()]
      end
      n = n:parent()
    end
  end

  for _, def in ipairs(defs) do
    local scope = find_scope(def.node)
    if scope then
      scope.children = scope.children or {}
      scope.children[#scope.children + 1] = def
    end
  end

  local roots = {} ---@type table[]
  for _, scope in pairs(scopes) do
    local parent = find_scope(scope.node)
    if parent then
      parent.children = parent.children or {}
      parent.children[#parent.children + 1] = scope
    else
      roots[#roots + 1] = scope
    end
  end

  sort_by_position(roots)
  return roots
end

local o_search_pattern = dot.context.select.lsp_symbols.search_pattern ---@type stl.c.Observable
local o_flag_fuzzy = dot.context.select.lsp_symbols.flag_fuzzy ---@type stl.c.Observable
local o_flag_regex = dot.context.select.lsp_symbols.flag_regex ---@type stl.c.Observable
local o_flag_case_sensitive = dot.context.select.lsp_symbols.flag_case_sensitive ---@type stl.c.Observable
local o_flag_viewtype = dot.context.select.lsp_symbols.flag_viewtype ---@type stl.c.Observable
local o_flag_foldempty = dot.context.select.lsp_symbols.flag_foldempty ---@type stl.c.Observable
local picker ---@type era.picker.TreeComposer

---@param kindname                      string
---@return string, string
local function get_icon(kindname)
  local icon = stl.icon.kind[kindname] or "󰅩"
  local icon_hln = "f_lsp_symbol_icon_" .. kindname
  return icon, icon_hln
end

---@param tree                          stl.c.Tree
---@param callback                      fun(): nil
local function fetch_symbols(tree, callback)
  local bufnr = filepath_sourcefile and dot.buf.loadfile(filepath_sourcefile) or nil
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
  local kind_filter = get_kind_filter(bufnr) ---@type table<string, boolean>

  local function make_uuid(parent_uuid)
    seq = seq + 1
    return string.format("%s:%d", parent_uuid, seq)
  end

  ---@param parent_uuid                 string
  ---@param data                        dot.fn.find_lsp_symbols.ISymbolData
  ---@return string|nil
  local function insert_node(parent_uuid, data)
    -- Check for duplicate symbols at same position (handles C++ macros, etc.)
    local pos_key = string.format("%d:%d", data.lnum, data.col)
    local full_key = string.format("%s:%s:%s", data.kind, data.name, pos_key)
    if seen[full_key] or seen[pos_key .. ":" .. data.kind] then
      return nil
    end
    local uuid = make_uuid(parent_uuid)
    tree:insert(parent_uuid, uuid, data)
    seen[full_key] = true
    seen[pos_key .. ":" .. data.kind] = true
    return uuid
  end

  ---@param symbol                      table
  ---@return lsp.Range?, lsp.Range?
  local function resolve_ranges(symbol)
    local sel = symbol.selectionRange
    local whole = symbol.range
    if symbol.location then
      local loc = symbol.location
      sel = sel or loc.targetSelectionRange or loc.range
      whole = whole or loc.targetRange or loc.range or loc.targetSelectionRange
    end
    return sel or whole, whole or sel
  end

  ---@param symbol                      table
  ---@param parent_uuid                 string
  ---@param encoding                    string?
  local function handle_document_symbol(symbol, parent_uuid, encoding)
    local sel_range, whole_range = resolve_ranges(symbol)
    local sel_start = sel_range and sel_range.start
    local whole_start = whole_range and whole_range.start
    local end_pos = whole_range and whole_range["end"]
    local kindname = vim.lsp.protocol.SymbolKind[symbol.kind] or "Unknown"
    local parent_for_children = parent_uuid

    if whole_start and end_pos and kind_filter[kindname] then
      local icon, icon_hln = get_icon(kindname)
      local lnum = whole_start.line + 1
      local col = lsp_position_to_col(bufnr, whole_start, encoding)
      col = fix_col_position(bufnr, lnum, col)

      local sel_lnum = sel_start and (sel_start.line + 1) or nil
      local sel_col = sel_start and lsp_position_to_col(bufnr, sel_start, encoding) or nil
      if sel_lnum and sel_col then
        sel_col = fix_col_position(bufnr, sel_lnum, sel_col)
      end

      ---@type dot.fn.find_lsp_symbols.ISymbolData
      local data = {
        name = clean_symbol_name(symbol.name or "Unknown"),
        kind = kindname,
        lnum = lnum,
        col = col,
        end_lnum = end_pos.line + 1,
        end_col = lsp_position_to_col(bufnr, end_pos, encoding),
        icon = icon,
        icon_hln = icon_hln,
        selection_lnum = sel_lnum,
        selection_col = sel_col,
      }
      local uuid = insert_node(parent_uuid, data)
      if uuid then
        inserted = inserted + 1
        parent_for_children = uuid
      end
    end

    for _, child in ipairs(symbol.children or {}) do
      handle_document_symbol(child, parent_for_children, encoding)
    end
  end

  ---@param symbol                      table
  ---@param parent_uuid                 string
  ---@param encoding                    string?
  local function handle_symbol_information(symbol, parent_uuid, encoding)
    local sel_range, whole_range = resolve_ranges(symbol)
    local range = whole_range or sel_range
    if not range or not range.start or not range["end"] then
      return
    end

    local kindname = vim.lsp.protocol.SymbolKind[symbol.kind] or "Unknown"
    if not kind_filter[kindname] then
      return
    end

    local symbol_name = clean_symbol_name(symbol.name or "Unknown")
    if symbol.containerName and symbol.containerName ~= "" then
      symbol_name = symbol.containerName .. "." .. symbol_name
    end

    local icon, icon_hln = get_icon(kindname)
    local lnum = range.start.line + 1
    local col = lsp_position_to_col(bufnr, range.start, encoding)
    col = fix_col_position(bufnr, lnum, col)

    local sel_lnum = sel_range and (sel_range.start.line + 1) or nil
    local sel_col = sel_range and lsp_position_to_col(bufnr, sel_range.start, encoding) or nil
    if sel_lnum and sel_col then
      sel_col = fix_col_position(bufnr, sel_lnum, sel_col)
    end

    ---@type dot.fn.find_lsp_symbols.ISymbolData
    local data = {
      name = symbol_name,
      kind = kindname,
      lnum = lnum,
      col = col,
      end_lnum = range["end"].line + 1,
      end_col = lsp_position_to_col(bufnr, range["end"], encoding),
      icon = icon,
      icon_hln = icon_hln,
      selection_lnum = sel_lnum,
      selection_col = sel_col,
    }

    if insert_node(parent_uuid, data) then
      inserted = inserted + 1
    end
  end

  ---@param responses                   { client:vim.lsp.Client, result:lsp.DocumentSymbol[]|lsp.SymbolInformation[] }[]
  local function populate_from_lsp(responses)
    for _, resp in ipairs(responses) do
      local result = resp.result
      if result ~= nil and result ~= vim.NIL then
        local list = vim.islist(result) and result or { result }
        local encoding = resp.client and resp.client.offset_encoding
        for _, symbol in ipairs(list) do
          if type(symbol) == "table" and symbol.kind then
            if symbol.location then
              handle_symbol_information(symbol, tree.root, encoding)
            else
              handle_document_symbol(symbol, tree.root, encoding)
            end
          end
        end
      end
    end
  end

  local function populate_from_treesitter()
    local scopes = get_treesitter_locals(bufnr)

    local function visit(match, parent_uuid)
      local parent_for_children = parent_uuid
      local kind = match.kind and TS_KIND_MAP[match.kind]

      if kind and kind_filter[kind] and match.pos and match.end_pos then
        local icon, icon_hln = get_icon(kind)
        ---@type dot.fn.find_lsp_symbols.ISymbolData
        local data = {
          name = match.text or "Unknown",
          kind = kind,
          lnum = match.pos[1],
          col = match.pos[2],
          end_lnum = match.end_pos[1],
          end_col = match.end_pos[2],
          icon = icon,
          icon_hln = icon_hln,
        }
        local uuid = insert_node(parent_uuid, data)
        if uuid then
          inserted = inserted + 1
          parent_for_children = uuid
        end
      end

      local children = match.children or {}
      if #children > 0 then
        sort_by_position(children)
        for _, child in ipairs(children) do
          visit(child, parent_for_children)
        end
      end
    end

    for _, scope in ipairs(scopes) do
      visit(scope, tree.root)
    end
  end

  request_document_symbols(bufnr, function(responses)
    if tick_refresh ~= _tick_refresh then
      return
    end
    populate_from_lsp(responses)
    if inserted == 0 then
      populate_from_treesitter()
    end
    callback()
  end)
end

---@return nil
local function refresh()
  local tree = picker._tree ---@type stl.c.Tree
  local treeview = picker._treeview ---@type era.picker.TreeView

  _tick_refresh = _tick_refresh + 1
  local tick_refresh = _tick_refresh

  tree:clear()
  treeview:clear()

  fetch_symbols(tree, function()
    if _tick_refresh ~= tick_refresh then
      return
    end
    tree:quick_traverse(tree.root, function(_, node)
      local data = node.data ---@type dot.fn.find_lsp_symbols.ISymbolData|nil
      local text = data and data.name or ""
      local has_children = #node.children > 0
      treeview:insert(node.uuid, {
        nodetype = has_children and "container" or "leaf",
        collapsed = false,
        tick_invisible = 0,
        tick_matched = 0,
        tick_selected = 0,
        tick_selected_maximum = 0,
        cache_treeview = nil,
        text = text,
        text_lower = text:lower(),
      })
    end)
    picker:attach(tree.root)
    picker:mark_result_dirty()
  end)
end

---@param _                             any
---@param node                          stl.c.ITreeNode
local function render_symbol(_, node)
  local data = node.data ---@type dot.fn.find_lsp_symbols.ISymbolData
  local icon = data.icon or "●"
  local text = icon .. " " .. (data.name or "Unknown")
  return {
    text = text,
    highlights = {
      { coll = 0, colr = #icon + 1, hlname = data.icon_hln or "DiagnosticInfo" },
      { coll = #icon + 1, colr = #text, hlname = "f_lsp_symbol_text" },
    },
  }
end

---@type era.picker.view.tree.ITreeviewContainerNodeRenderer
local function render_treeview_container(_, node, _, _, folded_depth)
  if folded_depth == 0 then
    return render_symbol(_, node)
  end

  local limit = folded_depth + 1
  local items = {} ---@type dot.fn.find_lsp_symbols.ISymbolData[]
  local curr = node ---@type stl.c.ITreeNode|nil
  while curr ~= nil and #items < limit do
    table.insert(items, 1, curr.data)
    local parentuuid = curr.parent
    if parentuuid == nil then
      break
    end
    curr = picker._tree:retrieve(parentuuid)
  end
  local item_count = #items

  local text = "" ---@type string
  local highlights = {} ---@type table[]
  local offset = 0 ---@type integer

  local sep = "  " ---@type string
  for i = 1, item_count, 1 do
    local item = items[i] ---@type dot.fn.find_lsp_symbols.ISymbolData

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
  local symbol_data = node.data ---@type dot.fn.find_lsp_symbols.ISymbolData
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

  local node = picker._tree:retrieve(nodeuuid) ---@type stl.c.ITreeNode|nil
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

  local nsnr = dot.var.nsnr.picker_preview_visual ---@type integer
  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)

  local data = node.data ---@type dot.fn.find_lsp_symbols.ISymbolData
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

---@param nodeuuid                      string
---@return nil
local function goto_symbol(nodeuuid)
  local node = picker._tree:retrieve(nodeuuid)
  if not (node and node.data and filepath_sourcefile) then
    return
  end

  picker:close()

  local symbol_data = node.data ---@type dot.fn.find_lsp_symbols.ISymbolData
  local target_bufnr = dot.buf.loadfile(filepath_sourcefile)
  if not target_bufnr then
    return
  end

  local target_winid = vim.api.nvim_get_current_win()
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winid) == target_bufnr then
      target_winid = winid
      break
    end
  end

  local lnum = symbol_data.selection_lnum or symbol_data.lnum
  local col = symbol_data.selection_col or symbol_data.col

  vim.api.nvim_win_set_buf(target_winid, target_bufnr)
  vim.api.nvim_set_current_win(target_winid)
  vim.api.nvim_win_set_cursor(target_winid, { lnum, col })
  vim.cmd("normal! zv zz")
end

picker = era.picker.TreeComposer.new({
  name = name,
  permanent = true,
  title = title,
  height = 0.9,
  width = 0.9,
  node_sorter = function(a, b)
    local ad = a.data or {} ---@type dot.fn.find_lsp_symbols.ISymbolData
    local bd = b.data or {} ---@type dot.fn.find_lsp_symbols.ISymbolData

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

  search_pattern = o_search_pattern,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,
  flag_viewtype = o_flag_viewtype,
  flag_foldempty = o_flag_foldempty,
  flag_selected = stl.c.Observable.from_value(false),

  render_listview_leaf = render_symbol,
  render_listview_location = render_location,
  render_treeview_container = render_treeview_container,
  render_treeview_leaf = render_symbol,
  render_treeview_location = render_location,

  render_preview = render_preview,

  on_confirm = function(_, selected_uuids)
    if not selected_uuids or #selected_uuids == 0 then
      return
    end
    goto_symbol(selected_uuids[1])
  end,

  on_enter = function(_, nodeuuid)
    goto_symbol(nodeuuid)
    return true
  end,

  on_refresh = refresh,
})

---@return nil
local function find_lsp_symbols()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr = dot.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
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

return find_lsp_symbols
