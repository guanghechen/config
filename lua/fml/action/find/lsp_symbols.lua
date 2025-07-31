---@diagnostic disable: invisible
local name = "fml.action.find.lsp_symbols" ---@type string
local title = "LSP Symbols" ---@type string

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

local o_finder_input = eve.context.select.lsp_symbols.input ---@type std.collection.IObservable
local o_flag_fuzzy = eve.context.select.lsp_symbols.flag_fuzzy ---@type std.collection.IObservable
local o_flag_regex = eve.context.select.lsp_symbols.flag_regex ---@type std.collection.IObservable
local o_flag_sensitive = eve.context.select.lsp_symbols.flag_case_sensitive ---@type std.collection.IObservable
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

  if not vim.b[bufnr].support_documentSymbol then
    callback()
    return
  end

  local tick_refresh = _tick_refresh ---@type integer

  local function process_symbols(symbols, parent_uuid, prefix)
    for _, symbol in ipairs(symbols) do
      local kindname = vim.lsp.protocol.SymbolKind[symbol.kind] or "Unknown"
      if WANT_SYMBOLS[kindname] and symbol.range then
        local lnum = symbol.range.start.line + 1 ---@type integer
        local col = symbol.range.start.character ---@type integer
        local uuid = string.format("%s%s@%d:%d", prefix, symbol.name, lnum, col)

        ---@class fml.action.find.lsp_symbols.ISymbolData
        local data = {
          name = symbol.name,
          kind = kindname,
          lnum = lnum,
          col = col,
          end_lnum = symbol.range["end"].line + 1,
          end_col = symbol.range["end"].character,
          icon = eve.icon.kind[kindname] or "󰅩",
          icon_hln = "f_lsp_symbol_icon_" .. kindname,
        }
        tree:insert(parent_uuid, uuid, data)

        if symbol.children then
          process_symbols(symbol.children, uuid, uuid .. "/")
        end
      end
    end
  end

  vim.lsp.buf_request(bufnr, "textDocument/documentSymbol", {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
  }, function(err, symbols)
    if tick_refresh ~= _tick_refresh then
      return
    end

    if not err and symbols then
      process_symbols(symbols, tree.root, "/")
    end
    callback()
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
