local __module_name__ = "fml.action.notepad" ---@type string

local Notepad = eve.ux.widget.Notepad ---@type table

local DEFAULT_KEY = "default" ---@type string
local instances = {} ---@type table<string, eve.ux.widget.Notepad>

---@param key                            ?string
---@param props                          ?eve.ux.widget.notepad.IProps
---@return eve.ux.widget.Notepad
local function ensure_instance(key, props)
  eve.notepad.load()

  if eve.notepad.current_item() == nil then
    local first_uuid = eve.notepad.at(1) ---@type string|nil
    if first_uuid == nil or not eve.notepad.focus_uuid(first_uuid) then
      eve.notepad.create(nil)
    end
  end

  key = key or DEFAULT_KEY

  local widget = instances[key] ---@type eve.ux.widget.Notepad|nil
  if widget ~= nil then
    return widget
  end

  local merged_props = vim.tbl_extend("force", {
    name = string.format("notepad.%s", key),
  }, props or {}) ---@type eve.ux.widget.notepad.IProps

  widget = Notepad.new(merged_props)
  instances[key] = widget
  return widget
end

---@return eve.ux.widget.Notepad|nil
local function find_visible_widget()
  for _, widget in pairs(instances) do
    if widget ~= nil and not widget:isdisposed() and widget:isvisible() then
      return widget
    end
  end
end

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

  local note = eve.notepad.ensure_named_item("chatbox") ---@type eve.builtin.notepad.INotepadItem
  eve.notepad.append_content(note.uuid, content)
  eve.notepad.focus_uuid(note.uuid)

  local widget = M.ensure()
  if widget ~= nil then
    widget:focus()
  end
end

---@param key                            ?string
---@return nil
function M.close(key)
  key = key or DEFAULT_KEY
  local widget = instances[key]
  if widget ~= nil then
    widget:close()
  end
end

---@return nil
function M.create()
  eve.notepad.load()

  local name_default = string.format("Note %d", math.max(1, eve.notepad.size() + 1)) ---@type string
  vim.ui.input({
    prompt = "Enter new notepad name:",
    default = name_default,
  }, function(input)
    if input == nil then
      return
    end

    local name = vim.trim(input) ---@type string
    local item = eve.notepad.create(#name > 0 and name or nil) ---@type eve.builtin.notepad.INotepadItem

    ensure_instance(nil):focus()

    std.reporter.info({
      from = __module_name__,
      subject = "create",
      message = string.format("Created notepad '%s'.", item.name),
    })
  end)
end

---@return nil
function M.destroy()
  eve.notepad.load()

  local item = eve.notepad.current_item() ---@type eve.builtin.notepad.INotepadItem|nil
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

    if eve.notepad.size() <= 1 then
      eve.notepad.create(nil)
    end

    if eve.notepad.remove(item.uuid) then
      std.reporter.info({
        from = __module_name__,
        subject = "destroy",
        message = string.format("Removed notepad '%s'.", item.name),
      })
    end
  end)
end

---@param key                            ?string
---@param props                          ?eve.ux.widget.notepad.IProps
---@return eve.ux.widget.Notepad
function M.ensure(key, props)
  return ensure_instance(key, props)
end

---@param index                         integer
---@return boolean
function M.focus_index(index)
  eve.notepad.load()
  local ok = eve.notepad.focus_index(index) ---@type boolean
  if ok then
    local widget = instances[DEFAULT_KEY]
    if widget ~= nil then
      widget:focus()
    end
  end
  return ok
end

---@param step                          string|nil
---@return nil
function M.focus_left(step)
  eve.notepad.load()

  local resolved = resolve_step(step) ---@type integer|nil
  local done = eve.notepad.focus_step(-math.max(1, resolved or vim.v.count1 or 1)) ---@type boolean
  if done then
    local widget = instances[DEFAULT_KEY]
    if widget ~= nil and widget:isvisible() then
      widget:focus()
    end
  end
end

---@param step                          string|nil
---@return nil
function M.focus_right(step)
  eve.notepad.load()

  local resolved = resolve_step(step) ---@type integer|nil
  local done = eve.notepad.focus_step(math.max(1, resolved or vim.v.count1 or 1)) ---@type boolean
  if done then
    local widget = instances[DEFAULT_KEY]
    if widget ~= nil and widget:isvisible() then
      widget:focus()
    end
  end
end

---@return nil
function M.rename()
  eve.notepad.load()

  local item = eve.notepad.current_item() ---@type eve.builtin.notepad.INotepadItem|nil
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

  local widget = find_visible_widget() ---@type eve.ux.widget.Notepad|nil
  if widget ~= nil then
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
    if eve.notepad.rename(item.uuid, name) then
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
  eve.notepad.load()

  local synced_bufnrs = {} ---@type integer[]
  for _, widget in pairs(instances) do
    if widget ~= nil and not widget:isdisposed() then
      local bufnr = widget:sync_active_content()
      if bufnr ~= nil then
        synced_bufnrs[#synced_bufnrs + 1] = bufnr
      end
    end
  end

  Notepad.flush_to_disk()

  for _, bufnr in ipairs(synced_bufnrs) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.bo[bufnr].modified = false
    end
  end
end

---@param key                            ?string
---@param props                          ?eve.ux.widget.notepad.IProps
---@return nil
function M.show(key, props)
  ensure_instance(key, props):show()
end

---@param step                          string|nil
---@return nil
function M.swap_left(step)
  eve.notepad.load()
  local resolved = resolve_step(step) ---@type integer|nil
  eve.notepad.swap_left(resolved)
end

---@param step                          string|nil
---@return nil
function M.swap_right(step)
  eve.notepad.load()
  local resolved = resolve_step(step) ---@type integer|nil
  eve.notepad.swap_right(resolved)
end

---@param key                            ?string
---@param props                          ?eve.ux.widget.notepad.IProps
---@return nil
function M.toggle(key, props)
  ensure_instance(key, props):toggle()
end

return M
