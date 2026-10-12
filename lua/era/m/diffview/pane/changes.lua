---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.pane.changes" ---@type string

local tree = require("era.m.diffview.pane.tree")
local files = require("era.m.diffview.pane.filetree")
local config = require("era.m.diffview.config")
local util = require("era.m.diffview.util")
local M = {}
M.apply_to_buffer = tree.apply
M.get_item_at_line = tree.item
M.get_navigation = tree.navigation
M.resolve_parent_lnum = tree.parent
M.resolve_last_child_or_sibling_lnum = tree.last_child
M.get_entry_at_line = files.get_entry_at_line
M.find_adjacent_entry = files.find_adjacent_entry
M.toggle_collapse = files.toggle_collapse
M.is_directory = files.is_directory
M.goto_parent_node = files.goto_parent_node
M.goto_last_child_or_sibling = files.goto_last_child_or_sibling

---@class era.m.diffview.pane.changes.IOverlayEntry
---@field public lnum                   integer
---@field public entry                  era.m.diffview.IFileEntry

---@param value                         integer|nil
---@param prefix                        string
---@return string
local function format_stat(value, prefix)
  if value == nil or value <= 0 then
    return ""
  end
  return prefix .. tostring(value)
end

---@param text                          string
---@param width                         integer
---@return string
local function pad_left(text, width)
  return string.rep(" ", math.max(0, width - #text)) .. text
end

---Keep Git paths semantic in action payloads while making buffer text single-line and printable.
---@param path                          string
---@return string
local function format_display_path(path)
  return vim.fn.strtrans(path)
end

---@class era.m.diffview.pane.changes.IMetadataWidths
---@field public insertion              integer
---@field public deletion               integer

---Measure fixed INS / DEL columns shared by the sibling Changes panes.
---@param entries                       era.m.diffview.IFileEntry[]
---@return era.m.diffview.pane.changes.IMetadataWidths
function M.measure_metadata(entries)
  local widths = { insertion = 0, deletion = 0 } ---@type era.m.diffview.pane.changes.IMetadataWidths
  for _, entry in ipairs(entries) do
    widths.insertion = math.max(widths.insertion, #format_stat(entry.insertions, "+"))
    widths.deletion = math.max(widths.deletion, #format_stat(entry.deletions, "-"))
  end
  return widths
end

---Build right-aligned metadata using Changes-wide fixed INS / DEL / S columns.
---@param items                         era.m.diffview.pane.changes.IOverlayEntry[]
---@param panel_width                   integer
---@param widths                        era.m.diffview.pane.changes.IMetadataWidths
---@return era.m.diffview.IOverlay[]
local function build_overlays(items, panel_width, widths)
  local insertion_width = widths.insertion
  local deletion_width = widths.deletion
  local overlays = {} ---@type era.m.diffview.IOverlay[]
  for _, item in ipairs(items) do
    local entry = item.entry
    local insertion = format_stat(entry.insertions, "+") ---@type string
    local deletion = format_stat(entry.deletions, "-") ---@type string
    local status = entry.status ~= "" and entry.status or "?" ---@type string
    local virt_text = { { " ", "m_dv_ft_filename" } } ---@type [string, string][]

    if insertion_width > 0 then
      virt_text[#virt_text + 1] = {
        pad_left(insertion, insertion_width),
        insertion ~= "" and "m_dv_ft_insertions" or "m_dv_ft_filename",
      }
    end
    if insertion_width > 0 and deletion_width > 0 then
      virt_text[#virt_text + 1] = { " ", "m_dv_ft_filename" }
    end
    if deletion_width > 0 then
      virt_text[#virt_text + 1] = {
        pad_left(deletion, deletion_width),
        deletion ~= "" and "m_dv_ft_deletions" or "m_dv_ft_filename",
      }
    end
    if insertion_width > 0 or deletion_width > 0 then
      virt_text[#virt_text + 1] = { " ", "m_dv_ft_filename" }
    end
    virt_text[#virt_text + 1] = { status, util.get_status_hlgroup(status) }

    local metadata_width = 0 ---@type integer
    for _, segment in ipairs(virt_text) do
      metadata_width = metadata_width + #segment[1]
    end
    if metadata_width > panel_width then
      virt_text = {
        { panel_width > 1 and " " or "", "m_dv_ft_filename" },
        { status, util.get_status_hlgroup(status) },
      }
    end

    overlays[#overlays + 1] = {
      lnum = item.lnum,
      virt_text = virt_text,
    }
  end

  return overlays
end

---Create a changes panel buffer.
---@param stage_type                    stl.m.diffview.StageTypeEnum
---@return integer                      bufnr
function M.create_buffer(stage_type)
  local bufnr = vim.api.nvim_create_buf(false, true)

  for opt, val in pairs(config.BUFOPTS_PANEL) do
    vim.api.nvim_set_option_value(opt, val, { buf = bufnr })
  end
  vim.api.nvim_set_option_value("filetype", config.FT.CHANGES, { buf = bufnr })
  vim.b[bufnr].diffview_changes_stage_type = stage_type

  return bufnr
end

---Get the stage rendered by a Changes buffer.
---@param bufnr                         integer
---@return stl.m.diffview.StageTypeEnum|nil
function M.get_stage_type(bufnr)
  return vim.b[bufnr].diffview_changes_stage_type
end

----------------------------------------------------------------------------------------------------
-- Window options
----------------------------------------------------------------------------------------------------

---Generate winhighlight string for changes panel
---@return string
local function gen_winhl()
  local parts = {
    "CursorLine:m_dv_cursorline",
    "EndOfBuffer:m_dv_eob",
    "FoldColumn:m_dv_normal",
    "Normal:m_dv_normal",
    "SignColumn:m_dv_normal",
    "WinSeparator:m_dv_winsep",
  }
  return table.concat(parts, ",")
end

---Apply panel window options
---@param winnr                         integer
function M.apply_winopts(winnr)
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  for opt, val in pairs(config.WINOPTS_PANEL) do
    vim.api.nvim_set_option_value(opt, val, { win = winnr, scope = "local" })
  end
  vim.api.nvim_set_option_value("winfixwidth", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winhighlight", gen_winhl(), { win = winnr, scope = "local" })
end

----------------------------------------------------------------------------------------------------
-- Custom renderers for changes filetree
----------------------------------------------------------------------------------------------------

---@param entries                       era.m.diffview.IFileEntry[]
---@return era.m.diffview.IFileEntry[]
function M.get_entries_in_render_order(entries)
  local staged, unstaged = {}, {}
  for _, entry in ipairs(entries) do
    local target = entry.stage_type == "staged" and staged or unstaged
    target[#target + 1] = entry
  end
  return vim.list_extend(tree.sorted_entries(staged), tree.sorted_entries(unstaged))
end

---@param entries                       era.m.diffview.IFileEntry[]
---@param opts                          table
---@return table
function M.render(entries, opts)
  local plan = tree.plan(opts)
  local section = {}
  for _, entry in ipairs(entries) do
    if entry.stage_type == opts.stage_type then
      section[#section + 1] = entry
    end
  end
  tree.files(plan, section)
  local widths = opts.metadata_widths or M.measure_metadata(entries)
  for _, record in pairs(plan.source.records) do
    local item = record.data.item
    if item and item.type == "file" then
      local overlay =
        build_overlays({ { lnum = 0, entry = item.entry } }, opts.panel_width or config.FILETREE_WIDTH, widths)[1]
      record.data.presentation.right_text = nil
      record.data.presentation.fields.overlay = overlay.virt_text
    end
  end
  return plan
end

---@param bufnr                         integer
---@param entry                         era.m.diffview.IFileEntry
---@return integer|nil
function M.find_entry_line(bufnr, entry)
  if M.get_stage_type(bufnr) == entry.stage_type then
    return files.find_entry_line(bufnr, entry.filepath)
  end
end

---@param bufnr                         integer
---@param entry                         era.m.diffview.IFileEntry
---@return integer|nil
function M.find_entry_anchor(bufnr, entry)
  if M.get_stage_type(bufnr) == entry.stage_type then
    return files.find_entry_anchor(bufnr, entry.filepath)
  end
end

return M
