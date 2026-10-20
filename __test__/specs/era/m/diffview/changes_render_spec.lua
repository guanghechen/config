require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local treeview = require("__test__.support.treeview")
local changes = require("era.m.diffview.pane.changes")
local panels = require("era.m.diffview.pane.tree")

local entries = {
  { filepath = "src/foo.lua", stage_type = "staged", status = "M", insertions = 12, deletions = 3 },
  { filepath = "src/new.lua", stage_type = "staged", status = "A", insertions = 8, deletions = 0 },
  { filepath = "src/deleted.lua", stage_type = "unstaged", status = "D", insertions = 0, deletions = 6 },
  { filepath = "src/untracked.lua", stage_type = "unstaged", status = "?" },
}

---@param mode                          string
---@param stage                         string
---@param input                         ?table[]
---@param width                         ?integer
---@return era.view.ResultTree, integer
local function render(mode, stage, input, width)
  local bufnr = changes.create_buffer(stage)
  local owner = panels.new()
  t:defer(function()
    owner:dispose()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local plan = changes.render(input or entries, {
    stage_type = stage,
    viewtype = mode,
    foldempty = true,
    metadata_widths = changes.measure_metadata(input or entries),
    panel_width = width or 40,
  })
  treeview.await(changes.apply_to_buffer(bufnr, plan, owner))
  return owner, bufnr
end

---@param owner                         era.view.ResultTree
---@param path                          string
---@return string
local function metadata(owner, path)
  local frame = owner:frame()
  local id = frame:source():id(panels.key(nil, path, false))
  local chunks = frame:node(id).fields.overlay
  local text = {}
  for _, chunk in ipairs(chunks) do
    text[#text + 1] = chunk[1]
  end
  return table.concat(text)
end

for _, mode in ipairs({ "tree", "list" }) do
  t:test(mode .. " uses the same INS / DEL / S columns across sibling panes", function()
    local staged = render(mode, "staged")
    local unstaged = render(mode, "unstaged")
    t.assert_eq(" +12 -3 M", metadata(staged, "src/foo.lua"))
    t.assert_eq("  +8    A", metadata(staged, "src/new.lua"))
    t.assert_eq("     -6 D", metadata(unstaged, "src/deleted.lua"))
    t.assert_eq("        ?", metadata(unstaged, "src/untracked.lua"))
  end)
end

t:test("native rows map each Changes pane to its own stage", function()
  for _, stage in ipairs({ "staged", "unstaged" }) do
    local owner, bufnr = render("tree", stage)
    t.assert_eq(stage, changes.get_stage_type(bufnr))
    local files = 0
    for row = 1, owner:linecount() do
      local item = changes.get_item_at_line(bufnr, row)
      t.assert_eq(stage, item.stage_type)
      if item.type == "file" then
        files = files + 1
      end
    end
    t.assert_eq(2, files)
  end
end)

t:test("native navigation and collapse preserve file identity", function()
  local owner, bufnr = render("tree", "staged")
  local row = owner:retrieve_lnum(panels.key(nil, "src/foo.lua", false))
  local parent = changes.resolve_parent_lnum(changes.get_navigation(bufnr), row)
  t.assert_eq("src", changes.get_item_at_line(bufnr, parent).uuid)
  owner:collapse(owner:retrieve_uuid(parent), "collapse", false)
  treeview.publish(owner, { rootuuid = panels.root })
  t.assert_eq(1, owner:linecount())
  t.assert_nil(owner:retrieve_lnum(panels.key(nil, "src/foo.lua", false)))
  owner:collapse(owner:retrieve_uuid(1), "expand", false)
  treeview.publish(owner, { rootuuid = panels.root })
  t.assert_eq(
    "src/foo.lua",
    changes.get_entry_at_line(bufnr, owner:retrieve_lnum(panels.key(nil, "src/foo.lua", false))).filepath
  )
end)

t:test("narrow panes retain status when metadata columns do not fit", function()
  local owner = render("tree", "staged", nil, 2)
  t.assert_eq(" M", metadata(owner, "src/foo.lua"))
end)

t:test("Tree List Tree preserves directory identity, marks and collapsed state", function()
  local owner, bufnr = render("tree", "staged")
  local directory = panels.key(nil, "src", true)
  local file = panels.key(nil, "src/foo.lua", false)
  local source = owner:frame():source()
  local directory_id, file_id = source:id(directory), source:id(file)
  local revision = source:revision()
  owner:set_expansion(directory, false, false)
  owner:set_selected(directory, true)
  treeview.await(owner:ready())
  for _, mode in ipairs({ "list", "tree", "list", "tree" }) do
    treeview.await(changes.apply_to_buffer(
      bufnr,
      changes.render(entries, {
        stage_type = "staged",
        viewtype = mode,
        foldempty = true,
      }),
      owner
    ))
    local frame = owner:frame()
    t.assert_eq(revision, frame:source():revision(), "display changes must not import different records")
    t.assert_eq(directory_id, frame:source():id(directory))
    t.assert_eq(file_id, frame:source():id(file))
    t.assert_eq(directory_id, frame:source():node(file_id).parent)
    t.assert_false(frame:flags(directory_id).expanded)
    t.assert_true(frame:flags(directory_id).marked)
    t.assert_eq(mode == "list" and 2 or 1, frame:header().row_count)
    if mode == "list" then
      t.assert_eq("src/foo.lua", frame:rows(1, 1).labels[1])
    end
  end
end)

t:test("display escapes control and byte names while actions keep exact Git paths", function()
  local paths = { "dir/tab\tname.lua", "line\nbreak.lua", "raw" .. string.char(255) .. ".lua", "back\\slash.lua" }
  local input = {}
  for _, path in ipairs(paths) do
    input[#input + 1] = { filepath = path, stage_type = "staged", status = "M" }
  end
  local owner, bufnr = render("list", "staged", input)
  local frame = owner:frame()
  t.assert_eq(#paths, frame:header().row_count)
  for row = 1, #paths do
    local item = changes.get_item_at_line(bufnr, row)
    t.assert_true(vim.list_contains(paths, item.entry.filepath))
    local label = frame:rows(row, row).labels[1]
    t.assert_false(label:find("[\r\n\t]") ~= nil)
  end
end)

t:test("empty panes expose zero native rows", function()
  local owner, bufnr = render("tree", "staged", {})
  t.assert_eq(0, owner:linecount())
  t.assert_nil(changes.find_adjacent_entry(bufnr, nil, 1))
end)

t:test("an attached Changes pane publishes through the owned native surface", function()
  local bufnr = changes.create_buffer("staged")
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 0, col = 0, width = 50, height = 10 })
  local owner = panels.new()
  t:defer(function()
    owner:dispose()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  treeview.await(
    changes.apply_to_buffer(
      bufnr,
      changes.render(entries, { stage_type = "staged", viewtype = "tree", foldempty = true }),
      owner
    )
  )
  t.assert_eq(owner:linecount(), vim.api.nvim_buf_line_count(bufnr))
  t.assert_false(vim.api.nvim_get_option_value("modifiable", { buf = bufnr }))
  t.assert_true(changes.get_entry_at_line(bufnr, owner:retrieve_lnum(panels.key(nil, "src/foo.lua", false))) ~= nil)
  t.assert_eq(0, #vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, {}), "decorations remain ephemeral")
end)

t:run()
