local __module_name__ = "fml.action.find.notification" ---@type string

---@class fml.action.find.notification.IItemData
---@field public task                   eve.builtin.notifier.ITask

---@class fml.action.find.notification.IItem : eve.ux.picker.composer.list.IItem
---@field public data                   fml.action.find.notification.IItemData

local initialized = false ---@type boolean
local finder_input = std.Observable.from_value("") ---@type std.collection.IObservable
local flag_fuzzy = std.Observable.from_value(true) ---@type std.collection.IObservable
local flag_regex = std.Observable.from_value(false) ---@type std.collection.IObservable
local flag_sensitive = std.Observable.from_value(false) ---@type std.collection.IObservable

---@return eve.ux.picker.composer.list.IResetData
local function fetch_data()
  local items = {} ---@type fml.action.find.notification.IItem[]
  local tasks = eve.notifier.history() ---@type eve.builtin.notifier.ITask[]

  for index = #tasks, 1, -1 do
    local task = tasks[index] ---@type eve.builtin.notifier.ITask
    local text =
      string.format("%s %s %s", os.date("%H:%M:%S", task.timestamp), eve.icon.loglevel[task.level], task.title)

    local suffix = task.level:lower() ---@type string
    ---@type std.t.IHighlightInline[]
    local highlights = {
      { coll = 0, colr = 8, hlname = "f_un_icon_" .. suffix },
      { coll = 9, colr = 12, hlname = "f_un_icon_" .. suffix },
      { coll = 13, colr = -1, hlname = "f_un_title_" .. suffix },
    }

    ---@type fml.action.find.notification.IItem
    local item = {
      uuid = tostring(index),
      text = text,
      text_lower = text:lower(),
      highlights = highlights,
      data = { task = task },
    }
    items[#items + 1] = item
  end

  ---@type eve.ux.picker.composer.list.IResetData
  return { items = items }
end

local picker ---@type eve.ux.picker.ListComposer
picker = eve.ux.picker.ListComposer.new({
  name = __module_name__,
  permanent = true,
  title = "Find notifications",
  height = 25,
  width = 120,

  finder_input = finder_input,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_sensitive = flag_sensitive,

  preview_render = function(composer, bufnr)
    local lnum_current = composer.result.lnum_current:snapshot() ---@type integer

    if lnum_current < 1 then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No notification selected" })
      ---@type eve.ux.picker.preview.IDrawResult
      return {
        cursorline = false,
        number = false,
        title = "Notification",
        wrap = false,
      }
    end

    local item = composer:retrieve(lnum_current) ---@type eve.ux.picker.composer.list.IItem|nil
    if item == nil then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No notification selected" })
      ---@type eve.ux.picker.preview.IDrawResult
      return {
        cursorline = false,
        number = false,
        title = "Notification",
        wrap = false,
      }
    end

    ---@cast item fml.action.find.notification.IItem

    local task = item.data.task ---@type eve.builtin.notifier.ITask

    ---@type string[]
    local header_lines = {
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
    }

    local content_start_line = #header_lines ---@type integer
    local lines = vim.list_extend(header_lines, task.lines) ---@type string[]

    if task.highlights then
      lines[#lines + 1] = ""
      lines[#lines + 1] = "## Highlight"
      lines[#lines + 1] = ""
      lines[#lines + 1] = "--------------------------------"

      for _, hl in ipairs(task.highlights) do
        local text = string.format("%3d %5d %5d   %s", hl.lnum, hl.coll, hl.colr, hl.hlname)
        lines[#lines + 1] = text
      end
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local nsnr_content = eve.var.nsnr.picker_preview ---@type integer
    if task.highlights then
      for _, hl in ipairs(task.highlights) do
        local preview_row = content_start_line + hl.lnum - 1 ---@type integer
        if preview_row < #lines then
          vim.hl.range(
            bufnr,
            nsnr_content,
            hl.hlname,
            { preview_row, hl.coll },
            { preview_row, hl.colr },
            { priority = 10 }
          )
        end
      end
    end

    if vim.treesitter ~= nil and vim.treesitter.language ~= nil then
      local lang = vim.treesitter.language.get_lang("markdown") or "markdown" ---@type string
      local has_ts_parser = pcall(vim.treesitter.language.add, lang)
      if has_ts_parser then
        vim.treesitter.start(bufnr, lang)
      end
    end

    ---@type eve.ux.picker.preview.IDrawResult
    return {
      cursorline = false,
      number = false,
      title = task.title,
      wrap = false,
    }
  end,

  on_confirm = function(composer, item)
    if item == nil then
      return
    end

    ---@cast item fml.action.find.notification.IItem
    composer:close()

    local task = item.data.task ---@type eve.builtin.notifier.ITask
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
  end,

  on_refresh = function(composer)
    local data = fetch_data()
    composer:reset_data(data)
  end,
})

---@class fml.action.find
local M = {}

---@return nil
function M.find_notifications()
  if not initialized then
    initialized = true
    local data = fetch_data()
    picker:reset_data(data)
  end
  picker:focus()
end

return M
