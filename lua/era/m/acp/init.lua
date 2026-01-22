---@class era.m.acp.__mods
local __mods = {
  acp_client = "era.m.acp.acp_client",
  config = "era.m.acp.config",
  confirm = "era.m.acp.confirm",
  conversation = "era.m.acp.conversation",
  conversation_store = "era.m.acp.conversation_store",
  diff = "era.m.acp.diff",
  input = "era.m.acp.input",
  output = "era.m.acp.output",
  provider = "era.m.acp.provider",
  render = "era.m.acp.render",
  session_bridge = "era.m.acp.session_bridge",
  session = "era.m.acp.session",
  sidebar = "era.m.acp.sidebar",
  tabline = "era.m.acp.tabline",
  widget = "era.m.acp.widget",
}

---@class era.m.acp
---@field public __mods                 era.m.acp.__mods
---@field public acp_client             era.m.acp.acp_client.ACPClient
---@field public config                 era.m.acp.config
---@field public confirm                era.m.acp.confirm
---@field public conversation           era.m.acp.conversation
---@field public conversation_store     era.m.acp.conversation_store
---@field public diff                   era.m.acp.Diff
---@field public input                  era.m.acp.Input
---@field public output                 era.m.acp.Output
---@field public provider               era.m.acp.provider
---@field public render                 era.m.acp.render
---@field public session_bridge         era.m.acp.session_bridge
---@field public session                era.m.acp.Session
---@field public sidebar                era.m.acp.Sidebar
---@field public tabline                era.m.acp.tabline
---@field public widget                 era.m.acp.Widget
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@type era.m.acp.Widget|nil
local _widget = nil

---@param tabnr                        integer
---@return era.m.acp.Widget|nil
local function get_tab_widget(tabnr)
  local tab = vim.t[tabnr]
  if tab == nil then
    return nil
  end
  local widget = tab.acp_widget ---@type era.m.acp.Widget|nil
  if type(widget) ~= "table" or type(widget.isdisposed) ~= "function" then
    tab.acp_widget = nil
    return nil
  end
  if not widget:isdisposed() then
    return widget
  end
  tab.acp_widget = nil
  return nil
end

---@return era.m.acp.Widget|nil
local function find_any_widget()
  local tabnrs = vim.api.nvim_list_tabpages()
  for _, tabnr in ipairs(tabnrs) do
    local widget = get_tab_widget(tabnr)
    if widget then
      return widget
    end
  end
  return nil
end

---@return era.m.acp.Widget|nil
function M.get_widget()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local tab_widget = get_tab_widget(tabnr)
  if tab_widget ~= nil then
    _widget = tab_widget
    return tab_widget
  end

  if _widget ~= nil then
    if type(_widget) ~= "table" or type(_widget.isdisposed) ~= "function" then
      _widget = nil
    elseif not _widget:isdisposed() then
      return _widget
    else
      _widget = nil
    end
  end

  local any_widget = find_any_widget()
  if any_widget then
    _widget = any_widget
    return any_widget
  end

  return nil
end

---@param opts                          ?{ provider?: era.m.acp.ProviderName }
---@return era.m.acp.Widget
function M.open(opts)
  opts = opts or {}
  local widget = M.get_widget()
  if widget ~= nil then
    widget:focus()
    return widget
  end

  M.tabline.register()

  local session = nil ---@type era.m.acp.Session|nil
  if opts.provider == nil then
    local conversation = M.conversation_store.load_latest()
    if conversation then
      session = M.conversation.to_session(conversation)
    end
  end

  if session == nil then
    local provider_name = opts.provider or M.config.default_provider ---@type era.m.acp.ProviderName
    session = M.session.new({
      cwd = dot.path.cwd(),
      provider = provider_name,
    })
  end

  local new_widget = M.widget.new({ session = session })
  _widget = new_widget
  new_widget:focus()
  return new_widget
end

---@return nil
function M.close()
  local widget = M.get_widget()
  if widget ~= nil then
    widget:close()
    if _widget == widget then
      _widget = find_any_widget()
    end
  end
end

---@param opts                          ?{ provider?: era.m.acp.ProviderName }
---@return era.m.acp.Widget|nil
function M.toggle(opts)
  local widget = M.get_widget()
  if widget ~= nil then
    if widget:isvisible() then
      widget:hide()
      return nil
    else
      widget:focus()
      return widget
    end
  end
  return M.open(opts)
end

---@return nil
function M.focus()
  local widget = M.get_widget()
  if widget ~= nil then
    widget:focus()
  end
end

---@return nil
function M.cancel()
  local widget = M.get_widget()
  if widget ~= nil then
    widget.session:cancel()
  end
end

---@return nil
function M.clear()
  local widget = M.get_widget()
  if widget ~= nil then
    widget.session:clear()
    widget.output:clear()
  end
end

---@return nil
function M.rename_title()
  local widget = M.get_widget()
  if widget == nil then
    return
  end

  local session = widget.session
  local current = session.title or "untitled"

  vim.ui.input({
    prompt = "ACP Title",
    default = current,
  }, function(input)
    if input == nil then
      return
    end

    local next_title = vim.trim(input)
    if next_title == "" then
      next_title = "untitled"
    end

    M.session_bridge.rename_title(session, next_title)
    dot.state.status.dirtier_tabline:mark_dirty()
  end)
end

---@param opts                          ?{ provider?: era.m.acp.ProviderName, keep?: boolean }
---@return nil
function M.new_session(opts)
  opts = opts or {}
  local widget = M.get_widget()
  if widget ~= nil and not widget:isdisposed() then
    if not opts.keep then
      widget:close()
    end
  end

  local provider_name = opts.provider or M.config.default_provider ---@type era.m.acp.ProviderName
  local session = M.session.new({
    cwd = dot.path.cwd(),
    provider = provider_name,
  })

  local new_widget = M.widget.new({ session = session })
  _widget = new_widget
  new_widget:focus()
end

---@param content                       ?string
---@return nil
function M.submit(content)
  local widget = M.get_widget()
  if widget == nil then
    widget = M.open()
  end
  if widget and content ~= nil and content ~= "" then
    widget.input:submit(content)
  end
end

---@return nil
function M.select_provider()
  local providers = M.config.providers ---@type era.m.acp.ProviderName[]
  local items = {} ---@type { label: string, value: era.m.acp.ProviderName }[]

  for _, name in ipairs(providers) do
    local cfg = M.config.provider_configs[name]
    if cfg then
      items[#items + 1] = {
        label = cfg.label,
        value = name,
      }
    end
  end

  vim.ui.select(items, {
    prompt = "Select ACP Provider",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice then
      local widget = M.get_widget()
      local has_messages = widget ~= nil and #widget.session.messages > 0
      if widget ~= nil and widget.session.provider == choice.value then
        return
      end
      M.new_session({ provider = choice.value, keep = has_messages })
    end
  end)
end

return M
