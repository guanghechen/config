---@class era.m.acp.__mods
local __mods = {
  acp_client = "era.m.acp.acp_client",
  config = "era.m.acp.config",
  confirm = "era.m.acp.confirm",
  diff = "era.m.acp.diff",
  input = "era.m.acp.input",
  output = "era.m.acp.output",
  provider = "era.m.acp.provider",
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
---@field public diff                   era.m.acp.Diff
---@field public input                  era.m.acp.Input
---@field public output                 era.m.acp.Output
---@field public provider               era.m.acp.provider
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

---@return era.m.acp.Widget|nil
function M.get_widget()
  if _widget == nil or _widget:isdisposed() then
    return nil
  end
  return _widget
end

---@param opts                          ?{ provider?: era.m.acp.ProviderName }
---@return era.m.acp.Widget
function M.open(opts)
  opts = opts or {}
  if _widget ~= nil and not _widget:isdisposed() then
    _widget:focus()
    return _widget
  end

  M.tabline.register()

  local provider_name = opts.provider or M.config.default_provider ---@type era.m.acp.ProviderName
  local session = M.session.new({
    cwd = dot.path.cwd(),
    provider = provider_name,
  })

  _widget = M.widget.new({ session = session })
  _widget:focus()
  return _widget
end

---@return nil
function M.close()
  if _widget ~= nil and not _widget:isdisposed() then
    _widget:close()
    _widget = nil
  end
end

---@param opts                          ?{ provider?: era.m.acp.ProviderName }
---@return era.m.acp.Widget|nil
function M.toggle(opts)
  if _widget ~= nil and not _widget:isdisposed() then
    if _widget:isvisible() then
      _widget:hide()
      return nil
    else
      _widget:focus()
      return _widget
    end
  end
  return M.open(opts)
end

---@return nil
function M.focus()
  if _widget ~= nil and not _widget:isdisposed() then
    _widget:focus()
  end
end

---@return nil
function M.cancel()
  if _widget ~= nil and not _widget:isdisposed() then
    _widget.session:cancel()
  end
end

---@return nil
function M.clear()
  if _widget ~= nil and not _widget:isdisposed() then
    _widget.session:clear()
    _widget.output:clear()
  end
end

---@param opts                          ?{ provider?: era.m.acp.ProviderName }
---@return nil
function M.new_session(opts)
  opts = opts or {}
  if _widget ~= nil and not _widget:isdisposed() then
    _widget:close()
  end

  local provider_name = opts.provider or M.config.default_provider ---@type era.m.acp.ProviderName
  local session = M.session.new({
    cwd = dot.path.cwd(),
    provider = provider_name,
  })

  _widget = M.widget.new({ session = session })
  _widget:focus()
end

---@param content                       ?string
---@return nil
function M.submit(content)
  if _widget == nil or _widget:isdisposed() then
    M.open()
  end
  if _widget and content ~= nil and content ~= "" then
    _widget.input:submit(content)
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
      M.new_session({ provider = choice.value })
    end
  end)
end

return M
