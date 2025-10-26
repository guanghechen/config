local __module_name__ = "fml.action.notepad" ---@type string

---@type eve.ux.widget.Notepad
local widget = eve.ux.widget.Notepad.new({ name = "notepad.default" })

local dirty_data = true ---@type boolean
local o_search_pattern = std.Observable.from_value("") ---@type std.collection.IObservable
local o_flag_fuzzy = std.Observable.from_value(true) ---@type std.collection.IObservable
local o_flag_regex = std.Observable.from_value(false) ---@type std.collection.IObservable
local o_flag_case_sensitive = std.Observable.from_value(false) ---@type std.collection.IObservable

if widget:current_item() == nil then
  local first_uuid = widget:at(1) ---@type string|nil
  if first_uuid == nil or not widget:focus_uuid(first_uuid) then
    widget:create(nil)
  end
end

---@class fml.action.notepad.ISourceItem : eve.ux.picker.composer.list.IItem
---@field public data                   { name: string, title: string, filepath: string }
---@field public text_lower             string

---@return eve.ux.picker.composer.list.IResetData
local function fetch_source_data()
  dirty_data = false

  local current_source = widget:get_source() ---@type std.t.INotepadSource
  local items = {} ---@type fml.action.notepad.ISourceItem[]

  for _, config in ipairs(eve.state.notepad.source_configs) do
    local source = eve.state.notepad.retrieve_source(config.name)
    items[#items + 1] = {
      uuid = config.name,
      text = config.name,
      text_lower = config.name:lower(),
      highlights = {},
      data = {
        name = source.name,
        title = config.title,
        filepath = source.filepath,
      },
    }
  end

  ---@type eve.ux.picker.composer.list.IResetData
  return {
    items = items,
    uuid_current = current_source.name,
    uuid_present = current_source.name,
  }
end

local source_picker ---@type eve.ux.picker.ListComposer|nil
source_picker = eve.ux.picker.ListComposer.new({
  name = __module_name__ .. ".source_select",
  permanent = true,
  title = "Select Notepad Source",
  height = 12,
  width = 120,

  search_pattern = o_search_pattern,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,

  render_preview = function(composer, bufnr, _)
    local lnum_current = composer.result.lnum_current:snapshot() ---@type integer
    local item = composer:retrieve(lnum_current) ---@type eve.ux.picker.composer.list.IItem|nil
    ---@cast item fml.action.notepad.ISourceItem|nil

    if item == nil then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No source selected" })
      ---@type eve.ux.picker.preview.IDrawResult
      return {
        cursorline = false,
        number = false,
        title = "Preview",
        wrap = false,
      }
    end

    local lines = { item.data.filepath } ---@type string[]

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    ---@type eve.ux.picker.preview.IDrawResult
    return {
      cursorline = false,
      number = false,
      title = "Source Information",
      wrap = true,
    }
  end,

  on_confirm = function(composer, item)
    ---@cast item fml.action.notepad.ISourceItem
    composer:close()
    if item ~= nil then
      widget:attach(item.data.name)
      dirty_data = true
      std.reporter.info({
        from = __module_name__,
        subject = "source_select",
        message = string.format("Switched to '%s' notepad source.", item.data.name),
      })
    end
  end,
  on_disposed = function()
    o_search_pattern:dispose()
    o_flag_fuzzy:dispose()
    o_flag_regex:dispose()
    o_flag_case_sensitive:dispose()
  end,
  on_refresh = function(composer)
    local data = fetch_source_data()
    composer:reset_data(data)
  end,
})

---@param args                          string|nil
---@return integer|nil
local function resolve_step(args)
  if args == nil or #args == 0 then
    return nil
  end
  local ok, value = pcall(tonumber, args)
  if not ok or value == nil then
    return nil
  end
  value = math.floor(value)
  if value < 1 then
    return 1
  end
  return value
end

---@class fml.action.notepad
local M = {}

---@param content                       string
---@return nil
function M.append_content(content)
  if type(content) ~= "string" or #content == 0 then
    return
  end

  widget:append_content(nil, content)
  widget:focus()
end

---@return nil
function M.close()
  widget:close()
end

---@return nil
function M.create()
  local source_name = eve.context.option.notepad_source:snapshot() ---@type string
  local _, config = eve.state.notepad.retrieve_source(source_name)

  local prefix = config.default_item_name() ---@type string
  local name_default = string.format("%s %d", prefix, math.max(1, widget:size() + 1)) ---@type string
  vim.ui.input({
    prompt = "Enter new notepad name:",
    default = name_default,
  }, function(input)
    if input == nil then
      return
    end

    local name = vim.trim(input) ---@type string
    local item = widget:create(#name > 0 and name or nil) ---@type std.t.INotepadItem
    widget:focus()

    local ok = widget:flush()
    if ok then
      std.reporter.info({
        from = __module_name__,
        subject = "create",
        message = string.format("Created notepad '%s'.", item.name),
      })
    else
      std.reporter.warn({
        from = __module_name__,
        subject = "create",
        message = string.format("Created notepad '%s', but failed to save.", item.name),
      })
    end
  end)
end

---@return nil
function M.destroy()
  local item = widget:current_item() ---@type std.t.INotepadItem|nil
  if item == nil then
    std.reporter.warn({
      from = __module_name__,
      subject = "destroy",
      message = "No notepad item available to destroy.",
    })
    return
  end

  local prompt = string.format("Delete the notepad (%s)? (y/N): ", item.name) ---@type string
  vim.ui.input({
    inputtype = "confirmation",
    prompt = prompt,
    relative = "editor",
    row = 3,
    col = math.floor((vim.o.columns - #prompt) / 2),
  }, function(answer)
    if answer == nil then
      return
    end

    answer = vim.trim(answer:lower())
    if answer:sub(1, 1) ~= "y" then
      return
    end

    if widget:size() <= 1 then
      widget:create(nil)
    end

    local item_name = item.name ---@type string
    if widget:remove(item.uuid) then
      local ok = widget:flush()
      if ok then
        std.reporter.info({
          from = __module_name__,
          subject = "destroy",
          message = string.format("Removed notepad '%s'.", item_name),
        })
      else
        std.reporter.warn({
          from = __module_name__,
          subject = "destroy",
          message = string.format("Removed notepad '%s', but failed to save.", item_name),
        })
      end
    end
  end)
end

---@param index                         integer
---@return boolean
function M.focus_index(index)
  local ok = widget:focus_index(index) ---@type boolean
  if ok then
    widget:focus()
  end
  return ok
end

---@param step                          string|nil
---@return nil
function M.focus_left(step)
  local resolved = resolve_step(step) ---@type integer|nil
  local done = widget:focus_step(-math.max(1, resolved or vim.v.count1 or 1)) ---@type boolean
  if done and widget:isvisible() then
    widget:focus()
  end
end

---@param step                          string|nil
---@return nil
function M.focus_right(step)
  local resolved = resolve_step(step) ---@type integer|nil
  local done = widget:focus_step(math.max(1, resolved or vim.v.count1 or 1)) ---@type boolean
  if done and widget:isvisible() then
    widget:focus()
  end
end

---@return nil
function M.rename()
  local item = widget:current_item() ---@type std.t.INotepadItem|nil
  if item == nil then
    std.reporter.warn({
      from = __module_name__,
      subject = "rename",
      message = "No notepad item available to rename.",
    })
    return
  end

  local input_opts = {
    prompt = "Rename notepad item:",
    default = item.name,
  } ---@type fml.dressing.input.IOptions

  if widget:isvisible() then
    local winnr = widget:get_winnr() ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local available_width = nil ---@type integer|nil
      local ok_width, width_value = pcall(vim.api.nvim_win_get_width, winnr)
      if ok_width and type(width_value) == "number" then
        available_width = width_value
      else
        local ok_cfg, cfg = pcall(vim.api.nvim_win_get_config, winnr)
        if ok_cfg and type(cfg) == "table" and type(cfg.width) == "number" then
          available_width = cfg.width
        end
      end

      if type(available_width) == "number" and available_width > 0 then
        local max_width = math.max(1, available_width - 2) ---@type integer
        local width = math.min(60, math.max(20, max_width)) ---@type integer
        width = math.min(width, max_width)
        local col = math.max(0, math.floor((available_width - width) / 2)) ---@type integer

        input_opts.relative = "win"
        input_opts.win = winnr
        input_opts.width = width
        input_opts.row = 1
        input_opts.col = col
      else
        input_opts.relative = "win"
        input_opts.win = winnr
        input_opts.row = 1
        input_opts.col = 0
      end
    end
  end

  vim.ui.input(input_opts, function(input)
    if input == nil then
      return
    end

    local name = vim.trim(input) ---@type string
    if widget:rename(item.uuid, name) then
      std.reporter.info({
        from = __module_name__,
        subject = "rename",
        message = string.format("Renamed notepad to '%s'.", name),
      })
    end
  end)
end

---@return nil
function M.save()
  local ok = widget:save()

  if ok then
    std.reporter.info({
      from = __module_name__,
      subject = "save",
      message = "Notepad saved successfully.",
    })
  else
    std.reporter.error({
      from = __module_name__,
      subject = "save",
      message = "Failed to save notepad.",
    })
  end
end

---@return nil
function M.show()
  widget:show()
end

---@param step                          string|nil
---@return nil
function M.swap_left(step)
  local resolved = resolve_step(step) ---@type integer|nil
  widget:swap_left(resolved)
end

---@param step                          string|nil
---@return nil
function M.swap_right(step)
  local resolved = resolve_step(step) ---@type integer|nil
  widget:swap_right(resolved)
end

---@return nil
function M.toggle()
  widget:toggle()
end

---@return nil
function M.source_select()
  if dirty_data then
    local data = fetch_source_data()
    source_picker:reset_data(data)
  end
  source_picker:focus()
end

return M
