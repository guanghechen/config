---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.acp.provider" ---@type string

local S = era.m.acp

---@class era.m.acp.provider.__mods
local __mods = {
  claude = "era.m.acp.provider.claude",
  codex = "era.m.acp.provider.codex",
  gemini = "era.m.acp.provider.gemini",
  opencode = "era.m.acp.provider.opencode",
}

---@class era.m.acp.provider
---@field public __mods                 era.m.acp.provider.__mods
---@field public claude                 era.m.acp.provider.Claude
---@field public codex                  era.m.acp.provider.Codex
---@field public gemini                 era.m.acp.provider.Gemini
---@field public opencode               era.m.acp.provider.OpenCode
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

---@type table<era.m.acp.ProviderName, era.m.acp.IProvider>
local _providers = {}

---@param name                          era.m.acp.ProviderName
---@return era.m.acp.IProvider|nil
function M.get(name)
  if _providers[name] then
    return _providers[name]
  end

  local config = S.config.provider_configs[name]
  if not config then
    stl.reporter.error({
      group = "acp",
      from = __module_name__,
      subject = "get",
      message = "Unknown provider: " .. name,
    })
    return nil
  end

  local provider_module = __mods[name]
  if not provider_module then
    stl.reporter.error({
      group = "acp",
      from = __module_name__,
      subject = "get",
      message = "Provider module not found: " .. name,
    })
    return nil
  end

  local ok, provider_class = pcall(require, provider_module)
  if not ok then
    stl.reporter.error({
      group = "acp",
      from = __module_name__,
      subject = "get",
      message = "Failed to load provider: " .. name,
      details = { error = provider_class },
    })
    return nil
  end

  local provider = provider_class.new(config)
  _providers[name] = provider
  return provider
end

---@param provider_name                 era.m.acp.ProviderName
---@param opts                          era.m.acp.IRequestOpts
---@return fun(): nil                   cancel
function M.send(provider_name, opts)
  local provider = M.get(provider_name)
  if not provider then
    vim.schedule(function()
      opts.on_error("Provider not available: " .. provider_name)
    end)
    return stl.fn.noop
  end

  return provider:send(opts)
end

return M
