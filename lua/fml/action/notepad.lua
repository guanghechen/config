---@diagnostic disable: invisible

local __module_name__ = "fml.action.notepad" ---@type string

---@type ux.widget.Notepad
local widget = ux.widget.Notepad.new({ name = "notepad.default" })

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

---@class fml.action.notepad.ISourceItem : ux.picker.composer.list.IItem
---@field public data                   { name: string, title: string, filepath: string }
---@field public text_lower             string

---@return ux.picker.composer.list.IResetData
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

  ---@type ux.picker.composer.list.IResetData
  return {
    items = items,
    uuid_current = current_source.name,
    uuid_present = current_source.name,
  }
end

local source_picker ---@type ux.picker.ListComposer|nil
source_picker = ux.picker.ListComposer.new({
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
    local item = composer:retrieve(lnum_current) ---@type ux.picker.composer.list.IItem|nil
    ---@cast item fml.action.notepad.ISourceItem|nil

    if item == nil then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No source selected" })
      ---@type ux.picker.preview.IDrawResult
      return {
        cursorline = false,
        number = false,
        title = "Preview",
        wrap = false,
      }
    end

    local lines = { item.data.filepath } ---@type string[]

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    ---@type ux.picker.preview.IDrawResult
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
      ark.reporter.info({
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
  return value < 1 and 1 or value
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
  local source, config = eve.state.notepad.retrieve_source(source_name)

  local prefix = config.default_item_name() ---@type string
  local name_default = string.format("%s %d", prefix, math.max(1, widget:size() + 1)) ---@type string
  vim.ui.input({
    prompt = "Enter notepad name (create or navigate):",
    default = name_default,
  }, function(input)
    if input == nil then
      return
    end

    local name = vim.trim(input) ---@type string
    local item ---@type std.t.INotepadItemState|nil
    if #name == 0 then
      item = widget:create(nil)
    else
      item = source:retrieve_by_name(name, true)
      if item == nil then
        ark.reporter.error({
          from = __module_name__,
          subject = "create",
          message = string.format("Failed to create or retrieve notepad '%s'.", name),
        })
        return
      end
      widget:focus_uuid(item.uuid)
    end

    if item == nil then
      return
    end

    widget:focus()

    local ok = widget:flush()
    if ok then
      ark.reporter.info({
        from = __module_name__,
        subject = "create",
        message = string.format("Opened notepad '%s'.", item.name),
      })
    else
      ark.reporter.warn({
        from = __module_name__,
        subject = "create",
        message = string.format("Opened notepad '%s', but failed to save.", item.name),
      })
    end
  end)
end

---@return nil
function M.destroy()
  local item = widget:current_item() ---@type std.t.INotepadItemState|nil
  if item == nil then
    ark.reporter.warn({
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
        ark.reporter.info({
          from = __module_name__,
          subject = "destroy",
          message = string.format("Removed notepad '%s'.", item_name),
        })
      else
        ark.reporter.warn({
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
  local item = widget:current_item() ---@type std.t.INotepadItemState|nil
  if item == nil then
    ark.reporter.warn({
      from = __module_name__,
      subject = "rename",
      message = "No notepad item available to rename.",
    })
    return
  end

  ---@type fml.dressing.input.IOptions
  local input_opts = {
    prompt = "Rename notepad item:",
    default = item.name,
  }

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
      ark.reporter.info({
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
    ark.reporter.info({
      from = __module_name__,
      subject = "save",
      message = "Notepad saved successfully.",
    })
  else
    ark.reporter.error({
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

---@return nil
function M.source_prev()
  local current_source = widget:get_source() ---@type std.t.INotepadSource
  local current_index = nil ---@type integer|nil

  for i, config in ipairs(eve.state.notepad.source_configs) do
    if config.name == current_source.name then
      current_index = i
      break
    end
  end

  if current_index == nil then
    return
  end

  local prev_index = current_index - 1
  if prev_index < 1 then
    prev_index = #eve.state.notepad.source_configs
  end

  local prev_config = eve.state.notepad.source_configs[prev_index]
  widget:attach(prev_config.name)
  dirty_data = true
  ark.reporter.info({
    from = __module_name__,
    subject = "source_prev",
    message = string.format("Switched to '%s' notepad source.", prev_config.title),
  })
end

---@return nil
function M.source_next()
  local current_source = widget:get_source() ---@type std.t.INotepadSource
  local current_index = nil ---@type integer|nil

  for i, config in ipairs(eve.state.notepad.source_configs) do
    if config.name == current_source.name then
      current_index = i
      break
    end
  end

  if current_index == nil then
    return
  end

  local next_index = current_index + 1
  if next_index > #eve.state.notepad.source_configs then
    next_index = 1
  end

  local next_config = eve.state.notepad.source_configs[next_index]
  widget:attach(next_config.name)
  dirty_data = true
  ark.reporter.info({
    from = __module_name__,
    subject = "source_next",
    message = string.format("Switched to '%s' notepad source.", next_config.title),
  })
end

---@class fml.action.notepad.INoteItem : ux.picker.composer.list.IItem
---@field public data                   std.t.INotepadItemMeta
---@field public text_lower             string

---@return ux.picker.composer.list.IResetData
local function fetch_notes_data()
  local source = widget:get_source() ---@type std.t.INotepadSource
  local current_item = widget:current_item() ---@type std.t.INotepadItemState|nil
  local items = {} ---@type fml.action.notepad.INoteItem[]

  for _, note_meta in ipairs(source:list()) do
    items[#items + 1] = {
      uuid = note_meta.uuid,
      text = note_meta.name,
      text_lower = note_meta.name:lower(),
      highlights = {},
      data = note_meta,
    }
  end

  ---@type ux.picker.composer.list.IResetData
  return {
    items = items,
    uuid_current = current_item and current_item.uuid or nil,
    uuid_present = current_item and current_item.uuid or nil,
  }
end

local notes_picker ---@type ux.picker.ListComposer|nil
notes_picker = ux.picker.ListComposer.new({
  name = __module_name__ .. ".note_select",
  permanent = true,
  title = "Select Note",
  height = 0.8,
  width = 120,

  search_pattern = o_search_pattern,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,

  render_preview = function(composer, bufnr, _)
    local lnum_current = composer.result.lnum_current:snapshot() ---@type integer
    local item = composer:retrieve(lnum_current) ---@type ux.picker.composer.list.IItem|nil
    ---@cast item fml.action.notepad.INoteItem|nil

    if item == nil then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No note selected" })
      ---@type ux.picker.preview.IDrawResult
      return {
        cursorline = false,
        number = false,
        title = "Preview",
        wrap = false,
      }
    end

    local source = widget:get_source() ---@type std.t.INotepadSource
    local note = source:retrieve(item.data.uuid) ---@type std.t.INotepadItemState|nil

    if note == nil then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Failed to load note content" })
      ---@type ux.picker.preview.IDrawResult
      return {
        cursorline = false,
        number = false,
        title = "Error",
        wrap = false,
      }
    end

    local lines = vim.split(note.content or "", "\n") ---@type string[]
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "markdown"

    ---@type ux.picker.preview.IDrawResult
    return {
      cursorline = false,
      number = true,
      title = string.format(" %s ", note.name),
      wrap = true,
    }
  end,

  on_confirm = function(composer, item)
    ---@cast item fml.action.notepad.INoteItem
    composer:close()
    if item ~= nil then
      widget:focus_uuid(item.data.uuid)
      widget:focus()
    end
  end,
  on_disposed = function()
    o_search_pattern:next("")
  end,
  on_refresh = function(composer)
    local data = fetch_notes_data()
    composer:reset_data(data)
  end,
})

---@class fml.action.notepad.IEngineItem : ux.picker.composer.list.IItem
---@field public data                   { engine: 'json'|'folder', description: string }
---@field public text_lower             string

local engine_picker ---@type ux.picker.ListComposer|nil
engine_picker = ux.picker.ListComposer.new({
  name = __module_name__ .. ".engine_select",
  permanent = true,
  title = "Select Storage Engine",
  height = 8,
  width = 80,

  search_pattern = o_search_pattern,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,

  render_preview = function(composer, bufnr, _)
    local lnum_current = composer.result.lnum_current:snapshot() ---@type integer
    local item = composer:retrieve(lnum_current) ---@type ux.picker.composer.list.IItem|nil
    ---@cast item fml.action.notepad.IEngineItem|nil

    if item == nil then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No engine selected" })
      return {
        cursorline = false,
        number = false,
        title = "Preview",
        wrap = false,
      }
    end

    local lines = { item.data.description }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    return {
      cursorline = false,
      number = false,
      title = "Engine Information",
      wrap = true,
    }
  end,

  on_confirm = function(composer, item)
    ---@cast item fml.action.notepad.IEngineItem
    composer:close()
    if item ~= nil then
      local current_source = widget:get_source()
      local current_config = eve.state.notepad.source_config_map[current_source.name]

      if current_config.engine == item.data.engine then
        ark.reporter.info({
          from = __module_name__,
          subject = "change_engine",
          message = string.format("Already using %s engine", item.data.engine),
        })
        return
      end

      if eve.state.notepad.migrate_source_engine(current_source.name, item.data.engine) then
        widget:attach(current_source.name)
        dirty_data = true
      end
    end
  end,
  on_disposed = function()
    o_search_pattern:next("")
  end,
})

---@return nil
function M.change_engine()
  local current_source = widget:get_source()
  local current_config = eve.state.notepad.source_config_map[current_source.name]

  ---@type fml.action.notepad.IEngineItem[]
  local items = {
    {
      uuid = "json",
      text = "json",
      text_lower = "json",
      highlights = {},
      data = {
        engine = "json",
        description = "JSON file storage - Human-readable, git-friendly, simple",
      },
    },
    {
      uuid = "folder",
      text = "folder",
      text_lower = "folder",
      highlights = {},
      data = {
        engine = "folder",
        description = "Folder storage - One file per note, easy to manage",
      },
    },
  }

  ---@type ux.picker.composer.list.IResetData
  local data = {
    items = items,
    uuid_current = current_config.engine,
    uuid_present = current_config.engine,
  }

  engine_picker:reset_data(data)
  engine_picker:focus()
end

---@return nil
function M.go_backward()
  if not widget:go_backward() then
    ark.reporter.info({
      from = __module_name__,
      subject = "go_backward",
      message = "No previous note in history",
    })
  end
  widget:focus()
end

---@return nil
function M.go_forward()
  if not widget:go_forward() then
    ark.reporter.info({
      from = __module_name__,
      subject = "go_forward",
      message = "No next note in history",
    })
  end
  widget:focus()
end

---@return nil
function M.note_select()
  local data = fetch_notes_data()
  notes_picker:reset_data(data)
  notes_picker:focus()
end

return M
