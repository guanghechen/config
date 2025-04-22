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
      local level = task.level ---@type eve.builtin.notifier.LevelEnum
      local text = string.format("%s %s %s", eve.icon.loglevel[level], eve.string.pad_end(level, 5, " "), task.title)
      local item = { uuid = task.uuid, text = text, data = task } ---@type eve.ux.select.IItem
      items[#items + 1] = item
    end
    local result = { items = items } ---@type eve.ux.select.IData
    return result
  end,
  fetch_preview_data = function(item)
    local task = item.data ---@type eve.builtin.notifier.ITask
    ---@type eve.ux.ISearchPreviewData
    local result = {
      lines = task.lines,
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
      { coll = 0, colr = 2, hlname = "f_un_icon_" .. suffix },
      { coll = 2, colr = 7, hlname = "f_un_level_" .. suffix },
      { coll = 8, colr = -1, hlname = "f_un_title" },
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
    widget:hide()
    for _, item in ipairs(items) do
      local data = item.data ---@type fml.action.find.notification.IItemData
      local task = data.task ---@type eve.builtin.notifier.ITask
      eve.notifier.notify(task.level, task.group, task.title, task.content, task.timeout, true, false)
    end
  end,
})

---@class fml.action.find
local M = {}

---@return nil
function M.find_notifications()
  select:show()
end

return M
