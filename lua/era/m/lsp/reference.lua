---@diagnostic disable: invisible
---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.lsp.reference" ---@type string

---@class era.m.lsp.reference.IItem
---@field public filepath               string
---@field public lnum                   integer
---@field public col                    integer
---@field public col_end                integer

local search_pattern = stl.c.Observable.from_value("")
local flag_foldempty = dot.context.select.lsp_reference.flag_foldempty
local flag_fuzzy = dot.context.select.lsp_reference.flag_fuzzy
local flag_regex = dot.context.select.lsp_reference.flag_regex
local flag_case_sensitive = dot.context.select.lsp_reference.flag_case_sensitive
local flag_selected = dot.context.select.lsp_reference.flag_selected
local flag_viewtype = dot.context.select.lsp_reference.flag_viewtype

local picker = era.m.picker.FiletreeComposer.new({
  name = "lsp:reference",
  permanent = true,
  frecency = dot.context.frecency.files,
  title = "LSP References",
  height = 0.80,
  width = 0.85,

  search_pattern = search_pattern,

  flag_foldempty = flag_foldempty,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_case_sensitive = flag_case_sensitive,
  flag_selected = flag_selected,
  flag_viewtype = flag_viewtype,
  flags_start_index = 1,

  on_close = function()
    search_pattern:next("")
  end,
})

---@param node                          TSNode
---@return TSNode|nil
local function lua_field_name(node)
  local field = node:parent()
  if node:type() ~= "function_definition" or field == nil or field:type() ~= "field" or field:has_error() then
    return nil
  end

  local name = field:field("name")[1]
  local value = field:field("value")[1]
  if name ~= nil and field:child(0):type() == "identifier" and value ~= nil and value:id() == node:id() then
    return name
  end
  return nil
end

-- Loaded buffers hold the text servers count positions in; other files are read from disk.
---@param filepath                      string
---@return string[]
local function read_lines(filepath)
  local bufnr = stl.nvim.buf.locate_bufnr(filepath)
  if bufnr ~= nil and vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end
  return stl.fs.read_file_as_lines({ filepath = filepath, silent = true }) or {}
end

---@param items                         era.m.lsp.reference.IItem[]
---@param definitions                   table<era.m.lsp.reference.IItem, true>
---@return era.m.lsp.reference.IItem[]
local function collapse_lua_field_values(items, definitions)
  local grouped = {} ---@type table<string, era.m.lsp.reference.IItem[]>
  for _, item in ipairs(items) do
    if item.filepath:match("%.lua$") and definitions[item] then
      grouped[item.filepath] = grouped[item.filepath] or {}
      table.insert(grouped[item.filepath], item)
    end
  end

  local redundant = {} ---@type table<era.m.lsp.reference.IItem, true>
  for filepath, candidates in pairs(grouped) do
    if #candidates > 1 then
      local lines = read_lines(filepath)
      local parsed, trees = pcall(function()
        return vim.treesitter.get_string_parser(table.concat(lines, "\n"), "lua"):parse()
      end)
      if parsed and trees ~= nil and trees[1] ~= nil then
        local root = trees[1]:root() ---@type TSNode
        local positions = {} ---@type table<integer, table<integer, true>>
        local nodes = {} ---@type table<era.m.lsp.reference.IItem, TSNode>
        for _, item in ipairs(candidates) do
          if lines[item.lnum] ~= nil then
            local col = item.col ---@type integer
            positions[item.lnum] = positions[item.lnum] or {}
            positions[item.lnum][col] = true
            local node = root:named_descendant_for_range(item.lnum - 1, col, item.lnum - 1, col)
            if node ~= nil then
              local row_start, col_start = node:start()
              if row_start == item.lnum - 1 and col_start == col then
                nodes[item] = node
              end
            end
          end
        end

        for item, node in pairs(nodes) do
          local name = lua_field_name(node)
          if name ~= nil then
            local row, col = name:start()
            if positions[row + 1] ~= nil and positions[row + 1][col] then
              redundant[item] = true
            end
          end
        end
      end
    end
  end
  return vim.tbl_filter(function(item)
    return not redundant[item]
  end, items)
end

---@param method                        string
---@param additional_params             table<string, any>
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with { ok: boolean, items: ?era.m.lsp.reference.IItem[] }
---@see https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#referenceContext
local function fetch_data(method, additional_params, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({ ok = false, items = nil })
      return
    end

    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
    if winnr_sourcefile == nil then
      resolve({ ok = false, items = nil })
      return
    end

    local bufnr_sourcefile = vim.api.nvim_win_get_buf(winnr_sourcefile) ---@type integer
    if #vim.lsp.get_clients({ bufnr = bufnr_sourcefile, method = method }) == 0 then
      stl.reporter.error({
        from = __module_name__,
        subject = "fetch_data",
        message = "Not support method.",
        details = { bufnr = bufnr_sourcefile, method = method, context = additional_params },
      })
      resolve({ ok = false, items = nil })
      return
    end

    -- Positions count in each client's encoding, so every client gets its own request.
    ---@param client                    vim.lsp.Client
    ---@return table
    local function params_for(client)
      local position = vim.lsp.util.make_position_params(winnr_sourcefile, client.offset_encoding)
      return vim.tbl_extend("force", position, additional_params)
    end
    local uri_cur = vim.uri_from_bufnr(bufnr_sourcefile) ---@type string
    local line_cur = vim.api.nvim_win_get_cursor(winnr_sourcefile)[1] - 1 ---@type integer
    local is_definition = method == "textDocument/definition"

    vim.lsp.buf_request_all(bufnr_sourcefile, method, params_for, function(results_per_client)
      if token and token:is_cancelled() then
        return
      end

      local errors = {} ---@type string[]
      local items = {} ---@type era.m.lsp.reference.IItem[]
      local seen_locations = {} ---@type table<string, true>
      local definitions = {} ---@type table<era.m.lsp.reference.IItem, true>
      local lines_by_filepath = {} ---@type table<string, string[]>

      -- Items hold byte columns, as the jump and the highlights of the picker read them.
      ---@param filepath                string
      ---@param lnum                    integer
      ---@param character               integer
      ---@param encoding                lsp.PositionEncodingKind
      ---@return integer
      local function byte_col(filepath, lnum, character, encoding)
        if encoding == "utf-8" then
          return character
        end
        local lines = lines_by_filepath[filepath] or read_lines(filepath)
        lines_by_filepath[filepath] = lines
        local line = lines[lnum] ---@type string|nil
        return line ~= nil and vim.str_byteindex(line, encoding, character, false) or character
      end

      for client_id, result_or_error in pairs(results_per_client) do
        local client = vim.lsp.get_client_by_id(client_id)
        local encoding = client ~= nil and client.offset_encoding or "utf-16" ---@type lsp.PositionEncodingKind
        local error, result = result_or_error.err, result_or_error.result
        if error then
          local details = "Failed to executing '" .. method .. "' (" .. client_id .. "): " .. error.message
          table.insert(errors, details)
        else
          if result ~= nil then
            local locations = {} ---@type lsp.Location[]
            -- The targetRange of a link spans the whole declaration, its doc comments and attributes
            -- included; the targetSelectionRange marks the name to land on.
            if vim.islist(result) then
              for _, location in ipairs(result) do
                local uri = location.targetUri or location.uri
                local range = location.targetSelectionRange or location.range
                if uri ~= uri_cur or range.start.line ~= line_cur then
                  locations[#locations + 1] = location
                end
              end
            else
              local location = result
              local uri = location.targetUri or location.uri
              local range = location.targetSelectionRange or location.range
              if uri ~= uri_cur or range.start.line ~= line_cur then
                locations[#locations + 1] = location
              end
            end

            for _, location in ipairs(locations) do
              ---@diagnostic disable-next-line: undefined-field
              local uri = location.targetUri or location.uri
              ---@diagnostic disable-next-line: undefined-field
              local range = location.targetSelectionRange or location.range
              if uri ~= nil and range ~= nil then
                local filepath = dot.path.normalize(vim.uri_to_fname(uri)) ---@type string
                local lnum = range.start.line + 1 ---@type integer
                local col = byte_col(filepath, lnum, range.start.character, encoding) ---@type integer
                local location_key = string.format("%s:%d:%d", filepath, lnum, col) ---@type string
                if not seen_locations[location_key] then
                  seen_locations[location_key] = true
                  local lnum_end = range["end"].line + 1 ---@type integer

                  ---@type era.m.lsp.reference.IItem
                  local item = {
                    filepath = filepath,
                    lnum = lnum,
                    col = col,
                    col_end = lnum == lnum_end and byte_col(filepath, lnum, range["end"].character, encoding) or -1,
                  }
                  items[#items + 1] = item
                  if is_definition then
                    definitions[item] = true
                  end
                end
              end
            end
          end
        end
      end

      if #errors > 0 then
        stl.reporter.error({
          from = __module_name__,
          subject = "fetch_data",
          message = "Encountered errors.",
          details = { bufnr = bufnr_sourcefile, method = method, context = additional_params, errors = errors },
        })
        resolve({ ok = false, items = nil })
        return
      end

      if is_definition and #items > 1 then
        items = collapse_lua_field_values(items, definitions)
      end

      if #items <= 0 then
        resolve({ ok = true, items = {} })
        return
      end

      if #items == 1 then
        local item = items[1] ---@type era.m.lsp.reference.IItem
        dot.win.open_filepath(winnr_sourcefile, item.filepath, item.lnum, item.col)
        resolve({ ok = true, items = { item } })
        return
      end

      resolve({ ok = true, items = items })
    end)
  end)
end

---@param title                         string
---@param method                        string
---@param additional_params             table<string, any>
---@return nil
local function focus(title, method, additional_params)
  fetch_data(method, additional_params):finally(function(resolved, result)
    if not resolved or not result or not result.ok or result.items == nil then
      return
    end

    local items = result.items ---@type era.m.lsp.reference.IItem[]

    if #items <= 0 then
      stl.reporter.info({
        from = __module_name__,
        subject = title,
        message = "No items found.",
        details = { title = title, method = method, additional_params = additional_params },
      })
      return
    end

    if #items == 1 then
      return
    end

    local rootdir = dot.path.cwd() ---@type string
    local filepaths = {} ---@type string[]
    for _, item in ipairs(items) do
      local filepath = string.format("%s:%d:%d:%d", item.filepath, item.lnum, item.col, item.col_end) ---@type string
      filepaths[#filepaths + 1] = filepath

      if string.sub(filepath, 1, #rootdir) ~= rootdir then
        while true do
          local parent = dot.path.dirname(rootdir) ---@type string
          if parent == rootdir then
            break
          end
          rootdir = parent
        end
      end
    end

    picker.finder:set_title(title)
    picker:reset_filepaths(rootdir, filepaths, true)
    picker:mark_result_dirty()
    picker:focus()

    vim.schedule(function()
      local treeview = picker._treeview ---@type era.m.picker.FiletreeView
      treeview:traverse_filenode(nil, function(_, data, nodestate)
        if nodestate ~= nil and nodestate.locations ~= nil then
          local locations = nodestate.locations ---@type era.view.result_tree.IEntry[]
          local lnum_maximum = 1 ---@type integer
          for _, location in ipairs(locations) do
            lnum_maximum = lnum_maximum < location.lnum and location.lnum or lnum_maximum
          end

          local lines = vim.fn.readfile(data.filepath, "", lnum_maximum) ---@type string[]
          for _, location in ipairs(locations) do
            local line = lines[location.lnum] or "" ---@type string
            location.text = line
            location.highlights = { { coll = location.col, colr = location.col_end, hlname = "m_ft_reference" } }
          end
        end
      end)

      treeview:invalidate()
      picker:mark_result_dirty()
    end)
  end)
end

---@class era.m.lsp.reference
local M = {}

---@return nil
function M.goto_definitions()
  focus("LSP Definitions", "textDocument/definition", {})
end

---@return nil
function M.goto_implementations()
  focus("LSP Implementations", "textDocument/implementation", {})
end

---@return nil
function M.goto_references()
  focus("LSP References", "textDocument/references", { context = { includeDeclaration = true } })
end

---@return nil
function M.goto_type_definitions()
  focus("LSP Type Definitions", "textDocument/typeDefinition", {})
end

return M
