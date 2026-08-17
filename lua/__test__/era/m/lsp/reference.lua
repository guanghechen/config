---@diagnostic disable: undefined-global, invisible
--- Run with: nvim -l lua/__test__/era/m/lsp/reference.lua

local harness = require("__test__.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.m.lsp.reference")

---@param filepath                      string
---@param line                          integer
---@param col                           integer
---@param col_end                       integer
---@return lsp.Location
local function location(filepath, line, col, col_end)
  return {
    uri = vim.uri_from_fname(filepath),
    range = {
      start = { line = line, character = col },
      ["end"] = { line = line, character = col_end },
    },
  }
end

t:test("references: deduplicates overlapping clients and renders unique locations", function()
  local filepath_source = "/workspace/source.css"
  local filepath_target = "/workspace/target.css"
  local bufnr_source = vim.api.nvim_create_buf(false, true)
  local winnr_source = vim.api.nvim_get_current_win()
  local bufnr_previous = vim.api.nvim_win_get_buf(winnr_source)
  vim.api.nvim_buf_set_name(bufnr_source, filepath_source)
  vim.api.nvim_win_set_buf(winnr_source, bufnr_source)

  local picker = nil ---@type era.m.picker.FiletreeComposer|nil
  local original_new = era.m.picker.FiletreeComposer.new
  t:patch_table(era.m.picker.FiletreeComposer, "new", function(props)
    props.permanent = false
    picker = original_new(props)
    picker._scheduler_match.schedule = function() end
    picker.finder.set_title = function() end
    picker.focus = function() end
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
  t:patch_table(dot.win, "open_filepath", function()
    error("multiple unique references must use the picker")
  end)
  t:patch_table(vim.lsp, "get_clients", function()
    return { { id = 1 }, { id = 2 } }
  end)
  t:patch_table(vim.lsp.util, "make_position_params", function()
    return {
      textDocument = { uri = vim.uri_from_fname(filepath_source) },
      position = { line = 0, character = 0 },
    }
  end)
  t:patch_table(vim.lsp, "buf_request_all", function(_, method, _, callback)
    t.assert_eq("textDocument/references", method, "LSP method")
    callback({
      [1] = {
        result = {
          location(filepath_target, 9, 2, 5),
          location(filepath_target, 19, 4, 7),
        },
      },
      [2] = {
        result = {
          location(filepath_target, 9, 2, 5),
          location(filepath_target, 9, 8, 11),
        },
      },
    })
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
  Reference.goto_references()

  local resolved_picker = assert(picker) ---@type era.m.picker.FiletreeComposer
  local fileuuid = stl.c.Filetree.uuid(filepath_target) ---@type string
  local filestate = resolved_picker._treeview.statemap[fileuuid] ---@type era.m.picker.view.filetree.IFileNodeState
  local locations = assert(filestate.locations) ---@type era.m.picker.view.filetree.ILocationNodeState[]
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

  local bufnr_result = vim.api.nvim_create_buf(false, true)
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

  resolved_picker:dispose()
  if vim.api.nvim_buf_is_valid(bufnr_result) then
    vim.api.nvim_buf_delete(bufnr_result, { force = true })
  end
  if vim.api.nvim_buf_is_valid(bufnr_previous) then
    vim.api.nvim_win_set_buf(winnr_source, bufnr_previous)
  end
  if vim.api.nvim_buf_is_valid(bufnr_source) then
    vim.api.nvim_buf_delete(bufnr_source, { force = true })
  end
end)

t:run()
