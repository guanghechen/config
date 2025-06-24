---@diagnostic disable: invisible
local __module_name__ = "fml.action.find.lsp_symbols" ---@type string

---@class fml.action.find.lsp_symbols.ISymbolData
---@field public name                   string
---@field public kind                   integer
---@field public kind_name              string
---@field public range                  { start: { line: integer, character: integer }, ["end"]: { line: integer, character: integer } }
---@field public selection_range        { start: { line: integer, character: integer }, ["end"]: { line: integer, character: integer } }
---@field public detail                 string|nil
---@field public icon                   string
---@field public icon_hl                string
---@field public line                   integer
---@field public character              integer

local filepath_sourcefile = nil ---@type string|nil
local workspace_mode = false ---@type boolean

-- Symbol filtering configuration by filetype
local symbol_filter_config = {
  default = true, -- Show all symbols by default
  lua = { "Function", "Method", "Class", "Interface", "Module", "Variable", "Constant" },
  javascript = { "Function", "Method", "Class", "Interface", "Variable", "Constant", "Constructor" },
  typescript = { "Function", "Method", "Class", "Interface", "Variable", "Constant", "Constructor", "Property" },
  python = { "Function", "Method", "Class", "Variable", "Module" },
  go = { "Function", "Method", "Struct", "Interface", "Variable", "Constant", "Package" },
  rust = { "Function", "Method", "Struct", "Enum", "Trait", "Module", "Variable", "Constant" },
  c = { "Function", "Variable", "Struct", "Enum", "Union", "Typedef" },
  cpp = { "Function", "Method", "Class", "Struct", "Enum", "Variable", "Namespace" },
  java = { "Function", "Method", "Class", "Interface", "Variable", "Field", "Constructor" },
}

local o_finder_input = eve.context.select.lsp_symbols.input ---@type std.collection.IObservable
local o_flag_fuzzy = eve.context.select.lsp_symbols.flag_fuzzy ---@type std.collection.IObservable
local o_flag_regex = eve.context.select.lsp_symbols.flag_regex ---@type std.collection.IObservable
local o_flag_sensitive = eve.context.select.lsp_symbols.flag_case_sensitive ---@type std.collection.IObservable
local o_flag_viewtype = eve.context.select.lsp_symbols.flag_viewtype ---@type std.collection.IObservable
local o_flag_foldempty = eve.context.select.lsp_symbols.flag_foldempty ---@type std.collection.IObservable

-- Forward declaration
local refresh

---@param tree std.collection.Tree
---@param callback fun()|nil
---@param picker eve.ux.picker.TreeComposer|nil
---@return nil
local function fetch_symbols(tree, callback, picker)
  local bufnr = filepath_sourcefile and eve.buf.loadfile(filepath_sourcefile) or nil ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    if callback then callback() end
    return
  end

  -- For unloaded buffers, load the buffer and refresh on LspAttach
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    local autocmd_id = vim.api.nvim_create_autocmd("LspAttach", {
      buffer = bufnr,
      callback = vim.schedule_wrap(function()
        if picker and picker._tree and picker._tree.root then
          local root_node = picker._tree:retrieve(picker._tree.root)
          if root_node and #root_node.children > 0 then
            return true -- Remove autocmd
          end
        end
        if picker then
          refresh(picker)
          vim.defer_fn(function()
            if picker._tree and picker._tree.root then
              local root_node = picker._tree:retrieve(picker._tree.root)
              if not root_node or #root_node.children == 0 then
                refresh(picker)
              end
            end
          end, 1000)
        end
      end),
    })

    pcall(vim.fn.bufload, bufnr)

    -- Clean up autocmd after 10 seconds
    vim.defer_fn(function()
      vim.api.nvim_del_autocmd(autocmd_id)
    end, 10000)

    -- Wait a bit for buffer to load
    vim.defer_fn(function()
      if callback then callback() end
    end, 2000)
    return
  end

  -- Check if winline is disabled for this buffer
  if vim.b[bufnr][eve.var.Names.WINLINE_DISABLED] then
    if callback then callback() end
    return
  end

  -- Check if LSP method is supported based on workspace mode
  local method = workspace_mode and "workspace/symbol" or "textDocument/documentSymbol"
  if not eve.lsp.has_support_method(bufnr, method) then
    if callback then callback() end
    return
  end

  -- Check if blink.cmp is visible (same as locate_symbols)
  local ok, cmp = pcall(require, "blink.cmp")
  if ok and cmp.is_visible() then
    if callback then callback() end
    return
  end

  -- LSP request handler following locate_symbols pattern
  local function handler(err, symbols)
    if err then
      if type(err) == "table" then
        if err.message == "Content modified." then
          return
        end

        if err.message == "trying to get AST for non-added document" then
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.b[bufnr][eve.var.Names.WINLINE_DISABLED] = true
          end
          return
        end
      end

      if eve.status.suppress_warning:snapshot() then
        if callback then
          callback()
        end
        return
      end

      std.reporter.error({
        from = __module_name__,
        subject = "fetch_symbols",
        message = "Failed to request document symbols",
        details = { err = err, result = symbols, bufnr = bufnr },
      })
      if callback then
        callback()
      end
      return
    end

    if not symbols then
      if callback then
        callback()
      end
      return
    end

    -- Get filetype for filtering
    local filetype = vim.bo[bufnr].filetype
    local filter = symbol_filter_config[filetype] or symbol_filter_config.default

    -- Helper function to check if symbol kind should be included
    local function want_symbol(kind_name)
      if type(filter) == "boolean" then
        return filter
      end
      return vim.tbl_contains(filter, kind_name or "Unknown")
    end

    -- Collect all items first for sorting and last marking
    local items = {}

    -- Process LSP documentSymbol response recursively
    ---@param symbol_list any[]
    ---@param parent_uuid string
    ---@param path_prefix string
    local function process_symbols_recursive(symbol_list, parent_uuid, path_prefix)
      if not symbol_list then
        return
      end

      for i, symbol in ipairs(symbol_list) do
        local name = symbol.name or "Unknown"
        local kind = symbol.kind or 1
        local kind_name = vim.lsp.protocol.SymbolKind[kind] or "Unknown"

        -- Skip symbols that don't match the filter
        if not want_symbol(kind_name) then
          goto continue
        end

        -- Get position information - handle both documentSymbol and SymbolInformation
        local range = symbol.range or (symbol.location and symbol.location.range)
        if not range then
          goto continue
        end

        local line = range.start.line + 1
        local character = range.start.character

        -- Generate hierarchical UUID that reflects the symbol path
        local symbol_uuid = path_prefix .. tostring(i) .. ":" .. name .. "@" .. tostring(line) .. ":" .. tostring(character)

        -- Create symbol data compatible with existing renderers
        local symbol_data = {
          name = name,
          kind = kind,
          kind_name = kind_name,
          range = {
            start = { line = line, character = character },
            ["end"] = { line = range["end"].line + 1, character = range["end"].character },
          },
          selection_range = symbol.selectionRange and {
            start = { line = symbol.selectionRange.start.line + 1, character = symbol.selectionRange.start.character },
            ["end"] = { line = symbol.selectionRange["end"].line + 1, character = symbol.selectionRange["end"].character },
          } or {
            start = { line = line, character = character },
            ["end"] = { line = range["end"].line + 1, character = range["end"].character },
          },
          detail = symbol.detail,
          icon = eve.icon.kind[kind_name] or "󰅩",
          icon_hl = "f_lsp_symbol_icon_" .. kind_name,
          line = line,
          character = character,
          parent = parent_uuid,
        }

        -- Store item for processing
        local item = {
          uuid = symbol_uuid,
          parent = parent_uuid,
          data = symbol_data,
        }
        items[#items + 1] = item

        -- Process children recursively if they exist (IMPORTANT: do this immediately)
        if symbol.children and #symbol.children > 0 then
          process_symbols_recursive(symbol.children, symbol_uuid, symbol_uuid .. "/")
        end

        ::continue::
      end
    end

    -- Start processing from root level
    process_symbols_recursive(symbols, tree.root, "")

    -- Sort items by position
    table.sort(items, function(a, b)
      local a_line = a.data.line or 0
      local b_line = b.data.line or 0
      if a_line == b_line then
        return (a.data.character or 0) < (b.data.character or 0)
      end
      return a_line < b_line
    end)

    -- Fix last child marking - group by parent
    local parent_groups = {}
    for _, item in ipairs(items) do
      local parent_uuid = item.parent
      if not parent_groups[parent_uuid] then
        parent_groups[parent_uuid] = {}
      end
      parent_groups[parent_uuid][#parent_groups[parent_uuid] + 1] = item
    end

    -- Mark last items for each parent
    for _, children in pairs(parent_groups) do
      if #children > 0 then
        local last_item = children[#children]
        last_item.data.last = true
      end
    end

    -- Add all items to tree (children are already processed recursively)
    for _, item in ipairs(items) do
      tree:insert(item.uuid, item.parent, item.data)
    end

    -- Call the callback to trigger UI update
    if callback then
      callback()
    end
  end

  -- Make LSP request for symbols following locate_symbols pattern
  local request_method = workspace_mode and "workspace/symbol" or "textDocument/documentSymbol"
  local request_params

  if workspace_mode then
    -- For workspace symbols, use query parameter (could be from finder input)
    request_params = { query = o_finder_input:snapshot() or "" }
  else
    -- For document symbols, use text document params
    request_params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  end

  vim.lsp.buf_request(bufnr, request_method, request_params, handler)
end

---@param picker                        eve.ux.picker.TreeComposer
refresh = function(picker)
  local tree = picker._tree ---@type std.collection.Tree
  local treeview = picker._treeview ---@type eve.ux.picker.TreeView

  tree:clear()
  treeview:clear()

  fetch_symbols(tree, function()
    -- This callback is called after LSP symbols are processed
    tree:unsafe_traverse(tree.root, function(ctx)
      local nodemap = ctx.nodemap ---@type table<string, std.collection.tree.INode>
      for uuid, node in pairs(nodemap) do
        local has_children = #node.children > 0
        if has_children then
          local nodestate = {
            nodetype = "container",
            collapsed = false,
            tick_invisible = 0,
            tick_matched = 0,
            tick_selected = 0,
            tick_selected_maximum = 0,
            text = node.data.name,
            text_lower = node.data.name:lower(),
          }
          treeview:insert(uuid, nodestate)
        else
          -- Leaf node (symbol without children)
          local nodestate = {
            nodetype = "leaf",
            collapsed = false,
            tick_invisible = 0,
            tick_matched = 0,
            tick_selected = 0,
            text = node.data.name,
            text_lower = node.data.name:lower(),
          }
          treeview:insert(uuid, nodestate)
        end
      end
    end)

    picker:attach(tree.root)
    picker:mark_result_dirty()
  end, picker)
end

---@type eve.ux.picker.view.tree.IListviewLeafNodeRenderer
local function render_listview_leaf(_, node)
  local symbol_data = node.data ---@type fml.action.find.lsp_symbols.ISymbolData
  local icon = symbol_data.icon or "●"
  local name = symbol_data.name or "Unknown"

  local text = string.format("%s %s", icon, name)
  local icon_end = #icon + 1

  local highlights = {
    { coll = 0, colr = icon_end, hlname = symbol_data.icon_hl or "DiagnosticInfo" },
    { coll = icon_end, colr = #text, hlname = "f_lsp_symbol_text" },
  }

  return { text = text, highlights = highlights }
end

---@type eve.ux.picker.view.tree.IListviewLeafLocationRenderer
local function render_listview_location(_, node)
  local symbol_data = node.data ---@type fml.action.find.lsp_symbols.ISymbolData
  if symbol_data and symbol_data.line then
    return {
      text = string.format(":%d", symbol_data.line),
      highlights = { { coll = 0, colr = 10, hlname = "LineNr" } },
    }
  end
  return { text = "", highlights = {} }
end

---@type eve.ux.picker.view.tree.ITreeviewContainerNodeRenderer
local function render_treeview_container(_, node)
  local symbol_data = node.data ---@type fml.action.find.lsp_symbols.ISymbolData
  local icon = symbol_data.icon or "●"
  local name = symbol_data.name or "Unknown"

  local text = string.format("%s %s", icon, name)
  local icon_end = #icon + 1

  local highlights = {
    { coll = 0, colr = icon_end, hlname = symbol_data.icon_hl or "DiagnosticInfo" },
    { coll = icon_end, colr = #text, hlname = "f_lsp_symbol_text" },
  }

  return { text = text, highlights = highlights }
end

---@type eve.ux.picker.view.tree.ITreeviewLeafNodeRenderer
local function render_treeview_leaf(_, node)
  local symbol_data = node.data ---@type fml.action.find.lsp_symbols.ISymbolData
  local icon = symbol_data.icon or "●"
  local name = symbol_data.name or "Unknown"

  local text = string.format("%s %s", icon, name)
  local icon_end = #icon + 1

  local highlights = {
    { coll = 0, colr = icon_end, hlname = symbol_data.icon_hl or "DiagnosticInfo" },
    { coll = icon_end, colr = #text, hlname = "f_lsp_symbol_text" },
  }

  return { text = text, highlights = highlights }
end

---@type eve.ux.picker.view.tree.ITreeviewLeafLocationRenderer
local function render_treeview_location(_, node)
  local symbol_data = node.data ---@type fml.action.find.lsp_symbols.ISymbolData
  if symbol_data and symbol_data.line then
    return {
      text = string.format(":%d", symbol_data.line),
      highlights = { { coll = 0, colr = 10, hlname = "LineNr" } },
    }
  end
  return { text = "", highlights = {} }
end

local picker ---@type eve.ux.picker.TreeComposer
picker = eve.ux.picker.TreeComposer.new({
  name = __module_name__,
  permanent = true,
  title = "LSP Symbols",
  height = 30,
  width = 100,
  node_sorter = function(a, b)
    local a_line = a.data.line or 0
    local b_line = b.data.line or 0
    if a_line == b_line then
      return (a.data.character or 0) < (b.data.character or 0)
    end
    return a_line < b_line
  end,

  finder_input = o_finder_input,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_sensitive = o_flag_sensitive,
  flag_viewtype = o_flag_viewtype,
  flag_foldempty = o_flag_foldempty,
  flag_selected = std.Observable.from_value(false),

  -- Required renderer functions
  render_listview_leaf = render_listview_leaf,
  render_listview_location = render_listview_location,
  render_treeview_container = render_treeview_container,
  render_treeview_leaf = render_treeview_leaf,
  render_treeview_location = render_treeview_location,

  on_confirm = function(self, selected_uuids)
    if selected_uuids and #selected_uuids > 0 then
      self:close()

      -- Get symbol data from the first selected node
      local symbol_uuid = selected_uuids[1]
      local node = picker._tree:retrieve(symbol_uuid)
      if node and node.data then
        local symbol_data = node.data ---@type fml.action.find.lsp_symbols.ISymbolData

        -- Use selection_range if available for more precise positioning
        local target_line, target_col
        if symbol_data.selection_range then
          target_line = symbol_data.selection_range.start.line
          target_col = symbol_data.selection_range.start.character
        else
          target_line = symbol_data.line or 1
          target_col = symbol_data.character or 0
        end

        -- Ensure we have a valid source file
        if not filepath_sourcefile or filepath_sourcefile == "" then
          std.reporter.warn({
            from = __module_name__,
            subject = "on_confirm",
            message = "No source file available for navigation",
          })
          return
        end

        -- Get or load the buffer for the source file
        local target_bufnr = eve.buf.loadfile(filepath_sourcefile)
        if not target_bufnr or not vim.api.nvim_buf_is_valid(target_bufnr) then
          std.reporter.error({
            from = __module_name__,
            subject = "on_confirm",
            message = "Failed to load source file buffer",
            details = { filepath = filepath_sourcefile },
          })
          return
        end

        -- Find a window displaying the target buffer, or use current window
        local target_winid = nil
        for _, winid in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_buf(winid) == target_bufnr then
            target_winid = winid
            break
          end
        end

        -- If no window is displaying the buffer, use the current window
        if not target_winid then
          target_winid = vim.api.nvim_get_current_win()
          -- Switch to the target buffer in current window
          vim.api.nvim_win_set_buf(target_winid, target_bufnr)
        end

        -- Validate line number against buffer content
        local line_count = vim.api.nvim_buf_line_count(target_bufnr)
        if target_line > line_count then
          target_line = line_count
        end
        if target_line < 1 then
          target_line = 1
        end

        -- Validate column position against line content
        local line_content = vim.api.nvim_buf_get_lines(target_bufnr, target_line - 1, target_line, false)[1] or ""
        local line_length = #line_content
        if target_col > line_length then
          target_col = line_length
        end
        if target_col < 0 then
          target_col = 0
        end

        -- Focus the target window and set cursor position
        vim.api.nvim_set_current_win(target_winid)
        vim.api.nvim_win_set_cursor(target_winid, { target_line, target_col })

        -- Center the line and open folds if necessary
        vim.cmd("normal! zv") -- Open folds
        vim.cmd("normal! zz") -- Center the line

        -- Flash the cursor location for better visibility
        vim.defer_fn(function()
          if vim.api.nvim_win_is_valid(target_winid) and vim.api.nvim_get_current_win() == target_winid then
            vim.cmd("normal! zv") -- Ensure folds are still open
          end
        end, 50)
      end
    end
  end,

  on_refresh = function(self)
    refresh(self)
  end,
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
    refresh(picker)
  end
end

return M
