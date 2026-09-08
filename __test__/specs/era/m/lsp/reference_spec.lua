--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/lsp/reference_spec.lua
---@diagnostic disable: undefined-global, invisible

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.m.lsp.reference")

---@param filepath                      string
---@param lines                         string[]
---@return integer
local function create_buffer(filepath, lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_buf_set_name(bufnr, filepath)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

---@param filepath                      string
---@param line                          integer
---@param col                           integer
---@param col_end                       integer
---@param line_end                      ?integer
---@return lsp.Location
local function location(filepath, line, col, col_end, line_end)
  return {
    uri = vim.uri_from_fname(filepath),
    range = {
      start = { line = line, character = col },
      ["end"] = { line = line_end or line, character = col_end },
    },
  }
end

---@param method                        string
---@param results                       table<integer, table>
---@return era.m.picker.FiletreeComposer
---@return { filepath: string, lnum: integer, col: integer }[]
---@return boolean
local function navigate(method, results)
  local filepath_source = "/workspace/source.lua"
  local winnr_source = vim.api.nvim_get_current_win()
  local bufnr_previous = vim.api.nvim_win_get_buf(winnr_source)
  local bufnr_source = create_buffer(filepath_source, { "callback()" })
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr_previous) then
      vim.api.nvim_win_set_buf(winnr_source, bufnr_previous)
    end
  end)
  vim.api.nvim_win_set_buf(winnr_source, bufnr_source)

  local picker = nil ---@type era.m.picker.FiletreeComposer|nil
  local jumps = {}
  local focused = false
  local original_new = era.m.picker.FiletreeComposer.new
  t:patch_table(era.m.picker.FiletreeComposer, "new", function(props)
    props.permanent = false
    picker = original_new(props)
    t:defer(function()
      picker:dispose()
    end)
    picker._scheduler_match.schedule = function() end
    picker.finder.set_title = function() end
    picker.focus = function()
      focused = true
    end
    picker.mark_result_dirty = function(self)
      return self
    end
    return picker
  end)

  t:patch_table(dot.tab, "retrieve_winnr_sourcefile", function()
    return winnr_source
  end)
  t:patch_table(dot.path, "cwd", function()
    return "/workspace"
  end)
  t:patch_table(dot.win, "open_filepath", function(winnr, filepath, lnum, col)
    t.assert_eq(winnr_source, winnr, "jump window")
    jumps[#jumps + 1] = { filepath = filepath, lnum = lnum, col = col }
  end)
  local clients = { { id = 1, offset_encoding = "utf-8" }, { id = 2, offset_encoding = "utf-8" } }
  t:patch_table(vim.lsp, "get_clients", function()
    return clients
  end)
  t:patch_table(vim.lsp, "get_client_by_id", function(client_id)
    return clients[client_id]
  end)
  t:patch_table(vim.lsp.util, "make_position_params", function()
    return {
      textDocument = { uri = vim.uri_from_fname(filepath_source) },
      position = { line = 0, character = 0 },
    }
  end)
  t:patch_table(vim.lsp, "buf_request_all", function(_, requested_method, _, callback)
    t.assert_eq(method, requested_method, "LSP method")
    callback(results)
  end)
  t:patch_table(vim.fn, "readfile", function()
    local lines = {} ---@type string[]
    for index = 1, 20, 1 do
      lines[index] = string.format("line %d", index)
    end
    return lines
  end)
  t:patch_table(vim, "schedule", function(callback)
    callback()
  end)
  t:patch_table(package.loaded, "era.m.lsp.reference", nil)

  local Reference = require("era.m.lsp.reference")
  if method == "textDocument/references" then
    Reference.goto_references()
  else
    Reference.goto_definitions()
  end
  return assert(picker), jumps, focused
end

---@param picker                        era.m.picker.FiletreeComposer
---@param filepath                      string
---@return era.m.picker.view.filetree.ILocationNodeState[]
local function picker_locations(picker, filepath)
  local fileuuid = stl.c.Filetree.uuid(filepath)
  ---@diagnostic disable-next-line: assign-type-mismatch
  local filestate = picker._treeview.statemap[fileuuid] ---@type era.m.picker.view.filetree.IFileNodeState
  return assert(filestate.locations)
end

t:test("references: deduplicates overlapping clients and renders unique locations", function()
  local filepath_target = "/workspace/target.css"
  local resolved_picker, jumps, focused = navigate("textDocument/references", {
    [1] = { result = { location(filepath_target, 9, 2, 5), location(filepath_target, 19, 4, 7) } },
    [2] = { result = { location(filepath_target, 9, 2, 5), location(filepath_target, 9, 8, 11) } },
  })
  t.assert_eq(0, #jumps, "multiple references must not jump")
  t.assert_true(focused, "picker opened")
  local locations = picker_locations(resolved_picker, filepath_target)
  t.assert_eq(3, #locations, "unique location count")

  local ids = {} ---@type table<string, true>
  local cols = {} ---@type table<integer, true>
  for _, item in ipairs(locations) do
    t.assert_nil(ids[item.locationuuid], "duplicate location ID")
    ids[item.locationuuid] = true
    cols[assert(item.col)] = true
  end
  t.assert_true(cols[2], "first overlapping column")
  t.assert_true(cols[4], "second line column")
  t.assert_true(cols[8], "distinct same-line column")

  local bufnr_result = create_buffer("", { "" })
  local render_result = resolved_picker._treeview:render_treeview({
    bufnr = bufnr_result,
    rootuuid = resolved_picker._uuid_root,
    foldempty = false,
    only_expanded = true,
    only_matched = false,
    only_selected = false,
    only_visible = true,
  })
  local layout = assert(render_result.layout) ---@type stl.view.TreeLayout
  local rendered_ids = {} ---@type table<string, true>
  for lnum = 1, layout:len(), 1 do
    local id = assert(layout:id(lnum)) ---@type string
    t.assert_nil(rendered_ids[id], "duplicate rendered ID")
    rendered_ids[id] = true
  end
  for locationuuid in pairs(ids) do
    t.assert_true(rendered_ids[locationuuid], "rendered location ID")
  end
end)

for _, reversed in ipairs({ false, true }) do
  t:test("definitions: collapses the reported field/function pair, reversed=" .. tostring(reversed), function()
    local filepath = "/workspace/target.lua"
    create_buffer(filepath, {
      "local conds = {",
      "  not_vscode_or_yozvim = function()",
      "    return not vim.g.vscode and not vim.g.yozvim",
      "  end,",
      "}",
    })
    local targets = {}
    for _, target in ipairs({ location(filepath, 1, 2, 22), location(filepath, 1, 25, 5, 3) }) do
      targets[#targets + 1] =
        { targetUri = target.uri, targetRange = target.range, targetSelectionRange = target.range }
    end
    if reversed then
      targets[1], targets[2] = targets[2], targets[1]
    end
    local _, jumps, focused = navigate("textDocument/definition", {
      [1] = { result = targets },
      [2] = { result = { targets[2] } },
    })
    t.assert_false(focused, "picker remains closed")
    t.assert_eq(1, #jumps, "single jump")
    t.assert_eq(filepath, jumps[1].filepath, "target filepath")
    t.assert_eq(2, jumps[1].lnum, "target line")
    t.assert_eq(2, jumps[1].col, "field name column")
  end)
end

t:test("definitions: distinct fields on the same line still open the picker", function()
  local filepath = "/workspace/target.lua"
  create_buffer(filepath, { "local conds = { first = function() end, second = function() end }" })
  local targets = {
    location(filepath, 0, 16, 21),
    location(filepath, 0, 24, 38),
    location(filepath, 0, 40, 46),
    location(filepath, 0, 49, 63),
  }
  local picker, jumps, focused = navigate("textDocument/definition", { [1] = { result = targets } })
  t.assert_eq(0, #jumps, "no automatic jump")
  t.assert_true(focused, "picker opened")
  local locations = picker_locations(picker, filepath)
  t.assert_eq(2, #locations, "two distinct fields")
  local cols = { locations[1].col, locations[2].col }
  table.sort(cols)
  t.assert_eq(16, cols[1], "first field")
  t.assert_eq(40, cols[2], "second field")
end)

t:test("definitions: distinct files still open the picker", function()
  local filepaths = { "/workspace/first.lua", "/workspace/second.lua" }
  local results = {}
  for index, filepath in ipairs(filepaths) do
    create_buffer(filepath, { "local conds = { callback = function() end }" })
    results[index] = { result = { location(filepath, 0, 16, 24), location(filepath, 0, 27, 41) } }
  end
  local picker, jumps, focused = navigate("textDocument/definition", results)
  t.assert_eq(0, #jumps, "no automatic jump")
  t.assert_true(focused, "picker opened")
  for _, filepath in ipairs(filepaths) do
    t.assert_eq(1, #picker_locations(picker, filepath), "one field per file")
  end
end)

for _, sample in ipairs({
  { source = "local callback = function() end", tokens = { "callback", "function() end" } },
  {
    source = "local first, second = function() end, function() end",
    tokens = { "first", "second", "function() end", "function() end" },
  },
  { source = "local conds = { [key] = function() end }", tokens = { "key", "function() end" } },
  {
    source = "local conds = { [function() end] = function() end }",
    tokens = { "function() end", "function() end" },
  },
  { source = "local conds = { callback = function(", tokens = { "callback", "function(" } },
}) do
  t:test("definitions: does not collapse " .. sample.source, function()
    local filepath = "/workspace/target.lua"
    create_buffer(filepath, { sample.source })
    local targets = {}
    local from = 1
    for _, token in ipairs(sample.tokens) do
      local first, last = sample.source:find(token, from, true)
      targets[#targets + 1] = location(filepath, 0, assert(first) - 1, assert(last))
      from = last + 1
    end
    local picker, jumps, focused = navigate("textDocument/definition", { [1] = { result = targets } })
    t.assert_eq(0, #jumps, "no automatic jump")
    t.assert_true(focused, "picker opened")
    t.assert_eq(#targets, #picker_locations(picker, filepath), "all targets preserved")
  end)
end

t:test("definitions: preserves candidates when the Lua parser is unavailable", function()
  local filepath = "/workspace/target.lua"
  create_buffer(filepath, { "local conds = { callback = function() end }" })
  t:patch_table(vim.treesitter, "get_string_parser", function()
    error("Lua parser unavailable")
  end)
  local picker, jumps, focused = navigate("textDocument/definition", {
    [1] = { result = { location(filepath, 0, 16, 24), location(filepath, 0, 27, 41) } },
  })
  t.assert_eq(0, #jumps, "no automatic jump")
  t.assert_true(focused, "picker opened")
  t.assert_eq(2, #picker_locations(picker, filepath), "all candidates preserved")
end)

t:test("definitions: preserves the existing current-line filter", function()
  local filepath = "/workspace/target.ts"
  local _, jumps, focused = navigate("textDocument/definition", {
    [1] = { result = { location("/workspace/source.lua", 0, 0, 8), location(filepath, 9, 2, 5) } },
  })
  t.assert_false(focused, "current-line target remains excluded")
  t.assert_eq(1, #jumps, "single external target")
  t.assert_eq(filepath, jumps[1].filepath, "external filepath")
end)

t:run()
