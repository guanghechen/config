---@class fml.action.find.notification.IItemData
---@field public task                   eve.builtin.notifier.ITask

---@class fml.action.find.notification.IItem : eve.ux.select.IItem
---@field public data                   fml.action.find.notification.IItemData

---@type eve.ux.select.IProvider
local provider = {
  fetch_data = function()
    local items = {} ---@type eve.ux.select.IItem[]
    local tasks = eve.notifier.history() ---@type eve.builtin.notifier.ITask[]
    for index = #tasks, 1, -1 do
      local task = tasks[index] ---@type eve.builtin.notifier.ITask
      local text =
        string.format("%s %s %s", os.date("%H:%M:%S", task.timestamp), eve.icon.loglevel[task.level], task.title)
      local item = { uuid = tostring(index), text = text, data = task } ---@type eve.ux.select.IItem
      items[#items + 1] = item
    end
    local result = { items = items } ---@type eve.ux.select.IData
    return result
  end,
  fetch_preview_data = function(item)
    local task = item.data ---@type eve.builtin.notifier.ITask
    local lines = vim.list_extend({
      string.format("## %s", task.title),
      "",
      string.format("- **uuid**:      %s", task.uuid),
      string.format("- **group**:     %s", task.group or "NIL"),
      string.format("- **level**:     %s", task.level),
      string.format("- **timestamp**: %s (%d)", os.date("%H:%M:%S", task.timestamp), task.timestamp),
      string.format("- **timeout**:   %d", task.timeout),
      "",
      "## Content",
      "",
    }, task.lines) ---@type string[]

    if task.highlights then
      lines[#lines + 1] = "" ---@type string
      lines[#lines + 1] = "## Highlight" ---@type string
      lines[#lines + 1] = "" ---@type string
      lines[#lines + 1] = "--------------------------------" ---@type string

      for _, hl in ipairs(task.highlights) do
        local text = string.format("%3d %5d %5d   %s", hl.lnum, hl.coll, hl.colr, hl.hlname) ---@type string
        lines[#lines + 1] = text ---@type string
      end
    end

    ---@type eve.ux.ISearchPreviewData
    local result = {
      lines = lines,
      filetype = "markdown",
      highlights = {},
      title = "message",
    }
    return result
  end,
  render_item = function(item, match)
    local suffix = item.data.level:lower() ---@type string
    ---@type eve.t.IHighlightInline[]
    local highlights = {
      { coll = 0, colr = 8, hlname = "f_un_icon_" .. suffix },
      { coll = 9, colr = 12, hlname = "f_un_icon_" .. suffix },
      { coll = 13, colr = -1, hlname = "f_un_title_" .. suffix },
    }

    for _, piece in ipairs(match.matches) do
      ---@type eve.t.IHighlightInline[]
      local highlight = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
      table.insert(highlights, highlight)
    end
    return item.text, highlights
  end,
}

local select = nil ---@type eve.ux.ISelect|nil

select = eve.ux.Select.new({
  dimension = {
    height = 0.8,
    max_height = 1,
    max_width = 1,
    width = 0.35,
    width_preview = 0.5,
  },
  dirty_on_invisible = false,
  multiple = true,
  preview_enabled = true,
  extend_preset_keymaps = true,
  permanent = true,
  provider = provider,
  title = "Find notifications",
  on_close = function()
    if select ~= nil then
      select:mark_data_dirty()
    end
  end,
  on_confirm = function(widget, items)
    widget:close()
    for _, item in ipairs(items) do
      local task = item.data ---@type eve.builtin.notifier.ITask
      eve.notifier.notify({
        group = task.group,
        level = task.level,
        title = task.title,
        content = task.content,
        highlights = task.highlights,
        timeout = task.timeout,
        anonymous = true,
        silent = false,
      })
    end
  end,
})

---@class fml.action.find
local M = {}

---@return nil
function M.find_notifications()
  select:focus()
end

return M
