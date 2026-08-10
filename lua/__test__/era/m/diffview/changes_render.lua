---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/changes_render.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.changes_render")
local ns = vim.api.nvim_create_namespace("era.m.diffview.changes_render.test")

bootstrap.with_global(t, "stl", {
  e = {
    TabTypeEnum = {
      DIFFVIEW_COMMITS = "diffview_commits",
      DIFFVIEW_WORKSPACE = "diffview_workspace",
    },
  },
  fileicon = {
    get_file_icon = function()
      return "F", "file_icon"
    end,
  },
  icon = {
    filetype = {
      Folder = "D",
      FolderOpen = "O",
    },
  },
})
t:patch_table(package.loaded, "era.m.diffview.config", {
  NS = ns,
  ICONS = { SEPARATOR = "-" },
  FILETREE_WIDTH = 40,
  WINOPTS_PANEL = {},
})
t:patch_table(package.loaded, "era.m.diffview.util", {
  get_status_hlgroup = function(status)
    return status == "?" and "status_untracked" or "status_" .. status
  end,
})

local changes = assert(loadfile("lua/era/m/diffview/pane/changes.lua"))()

---@param overlay                      era.m.diffview.IOverlay
---@return string
local function overlay_text(overlay)
  local parts = {} ---@type string[]
  for _, segment in ipairs(overlay.virt_text) do
    parts[#parts + 1] = segment[1]
  end
  return table.concat(parts)
end

---@param result                       era.m.diffview.IRenderResult
---@return table<string, era.m.diffview.IOverlay>
local function overlays_by_filepath(result)
  local overlays = {} ---@type table<string, era.m.diffview.IOverlay>
  for index, item in ipairs(result.line_map) do
    if item.entry ~= nil then
      for _, overlay in ipairs(result.overlays or {}) do
        if overlay.lnum == index - 1 then
          overlays[item.entry.filepath] = overlay
          break
        end
      end
    end
  end
  return overlays
end

local entries = {
  { filepath = "src/foo.lua", stage_type = "staged", status = "M", insertions = 12, deletions = 3 },
  { filepath = "src/new.lua", stage_type = "staged", status = "A", insertions = 8, deletions = 0 },
  { filepath = "src/deleted.lua", stage_type = "unstaged", status = "D", insertions = 0, deletions = 6 },
  { filepath = "src/untracked.lua", stage_type = "unstaged", status = "?" },
}

---@param viewtype                     stl.m.diffview.PanelViewTypeEnum
---@param stage_type                  stl.m.diffview.StageTypeEnum
---@return era.m.diffview.IRenderResult
local function render(viewtype, stage_type)
  return changes.render(entries, {
    stage_type = stage_type,
    viewtype = viewtype,
    foldempty = true,
    collapsed_dirs = {},
    metadata_widths = changes.measure_metadata(entries),
    panel_width = 40,
  })
end

---@param viewtype                     stl.m.diffview.PanelViewTypeEnum
local function assert_aligned_columns(viewtype)
  local overlays = {} ---@type table<string, era.m.diffview.IOverlay>
  for _, stage_type in ipairs({ "staged", "unstaged" }) do
    for filepath, overlay in pairs(overlays_by_filepath(render(viewtype, stage_type))) do
      overlays[filepath] = overlay
    end
  end
  t.assert_eq(" +12 -3 M", overlay_text(overlays["src/foo.lua"]), "full metadata row")
  t.assert_eq("  +8    A", overlay_text(overlays["src/new.lua"]), "missing deletion keeps its column")
  t.assert_eq("     -6 D", overlay_text(overlays["src/deleted.lua"]), "missing insertion keeps its column")
  t.assert_eq("        ?", overlay_text(overlays["src/untracked.lua"]), "missing stats keep both columns")
end

t:test("render: list keeps pane-wide INS / DEL / S columns", function()
  assert_aligned_columns("list")
end)

t:test("render: tree uses the same metadata columns", function()
  assert_aligned_columns("tree")
end)

t:test("render: narrow pane keeps status when full metadata cannot fit", function()
  local overlays = {} ---@type table<string, era.m.diffview.IOverlay>
  for _, stage_type in ipairs({ "staged", "unstaged" }) do
    local result = changes.render(entries, {
      stage_type = stage_type,
      viewtype = "list",
      foldempty = true,
      collapsed_dirs = {},
      metadata_widths = changes.measure_metadata(entries),
      panel_width = 5,
    })
    for filepath, overlay in pairs(overlays_by_filepath(result)) do
      overlays[filepath] = overlay
    end
  end

  t.assert_eq(" M", overlay_text(overlays["src/foo.lua"]), "status fallback")
  t.assert_eq(" ?", overlay_text(overlays["src/untracked.lua"]), "untracked fallback")
end)

t:test("render: escapes control characters without changing semantic paths", function()
  for _, viewtype in ipairs({ "list", "tree" }) do
    local entry = { filepath = "src/multi\nline\tname.lua", stage_type = "staged", status = "A" }
    local result = changes.render({ entry }, {
      stage_type = "staged",
      viewtype = viewtype,
      foldempty = true,
      collapsed_dirs = {},
      panel_width = 40,
    })

    for _, line in ipairs(result.lines) do
      t.assert_false(line:find("\n", 1, true) ~= nil, viewtype .. " line remains single-line")
    end
    local file_lnum = nil ---@type integer|nil
    for index, item in ipairs(result.line_map) do
      if item.entry == entry then
        file_lnum = index
        break
      end
    end
    t.assert_true(file_lnum ~= nil, viewtype .. " file line")
    t.assert_true(result.lines[file_lnum]:find("multi^@line^Iname.lua", 1, true) ~= nil, viewtype .. " display path")
    t.assert_eq(entry.filepath, result.line_map[file_lnum].entry.filepath, viewtype .. " semantic path")

    local bufnr = vim.api.nvim_create_buf(false, true)
    changes.apply_to_buffer(bufnr, result)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end)

t:test("render: filename and status use per-status highlights", function()
  local result = render("list", "staged")
  local overlays = overlays_by_filepath(result)

  t.assert_eq("status_M", overlays["src/foo.lua"].virt_text[#overlays["src/foo.lua"].virt_text][2], "status")

  local item_lnum = nil ---@type integer|nil
  for index, item in ipairs(result.line_map) do
    if item.entry and item.entry.filepath == "src/foo.lua" then
      item_lnum = index - 1
      break
    end
  end
  local filename_hl = nil ---@type string|nil
  for _, highlight in ipairs(result.highlights) do
    if highlight.lnum == item_lnum and highlight.hlname == "status_M" then
      filename_hl = highlight.hlname
      break
    end
  end
  t.assert_eq("status_M", filename_hl, "filename")
end)

t:test("apply: installs right-aligned virtual text", function()
  local result = render("list", "staged")
  local bufnr = vim.api.nvim_create_buf(false, true)
  changes.apply_to_buffer(bufnr, result)

  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
  local right_aligned = 0 ---@type integer
  for _, extmark in ipairs(extmarks) do
    local details = extmark[4]
    if details and details.virt_text_pos == "right_align" then
      right_aligned = right_aligned + 1
    end
  end

  t.assert_eq(2, right_aligned, "one right-aligned overlay per staged file")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("window options keep the Changes column width fixed", function()
  local winnr = vim.api.nvim_get_current_win()
  local winfixwidth = vim.api.nvim_get_option_value("winfixwidth", { win = winnr })
  changes.apply_winopts(winnr)

  t.assert_true(vim.api.nvim_get_option_value("winfixwidth", { win = winnr }), "fixed width")
  vim.api.nvim_set_option_value("winfixwidth", winfixwidth, { win = winnr, scope = "local" })
end)

t:test("render: each pane contains only its own header and entries", function()
  local staged = render("list", "staged")
  local unstaged = render("list", "unstaged")

  t.assert_eq("Staged (2)", staged.lines[1], "staged header")
  t.assert_eq("Unstaged (2)", unstaged.lines[1], "unstaged header")
  t.assert_eq(3, #staged.lines, "staged lines")
  t.assert_eq(3, #unstaged.lines, "unstaged lines")
  for _, item in ipairs(staged.line_map) do
    t.assert_eq("staged", item.stage_type, "staged line ownership")
  end
  for _, item in ipairs(unstaged.line_map) do
    t.assert_eq("unstaged", item.stage_type, "unstaged line ownership")
  end
end)

t:test("status highlight mapping distinguishes conflicts and untracked files", function()
  bootstrap.with_global(t, "era", { m = { diffview = { config = { STATUS_ICONS = {} } } } })
  local util = assert(loadfile("lua/era/m/diffview/util.lua"))()

  t.assert_eq("m_dv_ft_status_unmerged", util.get_status_hlgroup("U"), "conflict")
  t.assert_eq("m_dv_ft_status_untracked", util.get_status_hlgroup("?"), "untracked")
end)

t:run()
