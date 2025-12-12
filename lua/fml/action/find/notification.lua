local __module_name__ = "fml.action.find.notification"

---@class fml.action.find.notification.IItemData
---@field public task                   era.t.INotifierTask

---@class fml.action.find.notification.IItem : ux.picker.composer.list.IItem
---@field public data                   fml.action.find.notification.IItemData

local dirty_data = true ---@type boolean
local o_search_pattern = ark.c.Observable.from_value("") ---@type ark.c.Observable
local o_flag_fuzzy = ark.c.Observable.from_value(true) ---@type ark.c.Observable
local o_flag_regex = ark.c.Observable.from_value(false) ---@type ark.c.Observable
local o_flag_case_sensitive = ark.c.Observable.from_value(false) ---@type ark.c.Observable

---@return ux.picker.composer.list.IResetData
local function fetch_data()
  dirty_data = false

  local items = {} ---@type fml.action.find.notification.IItem[]
  local tasks = era.notifier.history() ---@type era.t.INotifierTask[]

  for index = #tasks, 1, -1 do
    local task = tasks[index] ---@type era.t.INotifierTask
    local text =
      string.format("%s %s %s", os.date("%H:%M:%S", task.timestamp), dot.icon.loglevel[task.level], task.title)

    local suffix = task.level:lower() ---@type string
    ---@type ark.t.IHighlightInline[]
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

  ---@type ux.picker.composer.list.IResetData
  return { items = items }
end

local picker ---@type ux.picker.ListComposer
picker = ux.picker.ListComposer.new({
  name = __module_name__,
  permanent = true,
  title = "Find Notifications",
  height = 0.9,
  width = 0.9,

  search_pattern = o_search_pattern,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,

  render_preview = function(composer, bufnr)
    local lnum_current = composer.result.lnum_current:snapshot() ---@type integer

    if lnum_current < 1 then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No notification selected" })
      ---@type ux.picker.preview.IDrawResult
      return {
        cursorline = false,
        number = true,
        title = "Notification",
        wrap = false,
      }
    end

    local item = composer:retrieve(lnum_current) ---@type ux.picker.composer.list.IItem|nil
    if item == nil then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No notification selected" })
      ---@type ux.picker.preview.IDrawResult
      return {
        cursorline = false,
        number = true,
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

    local nsnr_content = dot.var.nsnr.picker_preview ---@type integer
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

    ---@type ux.picker.preview.IDrawResult
    return {
      cursorline = false,
      number = true,
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

    dirty_data = true

    local task = item.data.task ---@type eve.builtin.notifier.ITask
    ark.reporter.log(task.level, {
      from = __module_name__,
      title = task.title,
      message = task.content,
      group = task.group,
      highlights = task.highlights,
      timeout = task.timeout,
      anonymous = true,
    })
  end,
  on_disposed = function()
    o_search_pattern:dispose()
    o_flag_fuzzy:dispose()
    o_flag_regex:dispose()
    o_flag_case_sensitive:dispose()
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
  if dirty_data then
    local data = fetch_data()
    picker:reset_data(data)
  end
  picker:focus()
end

return M
