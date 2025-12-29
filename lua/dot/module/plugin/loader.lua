local __module_name__ = "dot.module.plugin.loader" ---@type string

---@class dot.module.plugin.loader
---@field public plugins                table<string, dot.module.plugin.IPluginState>
---@field protected _module_to_plugin   table<string, string>
---@field protected _initialized        boolean
local M = {}

M.plugins = {}
M._module_to_plugin = {}
M._initialized = false

---@param name                          string
---@return dot.module.plugin.IPluginState|nil
function M.get(name)
  return M.plugins[name]
end

---@return table<string, dot.module.plugin.IPluginState>
function M.get_all()
  return M.plugins
end

---@param name                          string
---@return boolean
function M.is_loaded(name)
  local state = M.plugins[name] ---@type dot.module.plugin.IPluginState|nil
  return state ~= nil and state.loaded
end

---@param name                          string
---@return nil
function M.load(name)
  local state = M.plugins[name] ---@type dot.module.plugin.IPluginState|nil
  if state then
    M.__load_plugin__(state)
  end
end

---@param specs                         dot.module.plugin.IPluginSpec[]
---@return nil
function M.setup(specs)
  if M._initialized then
    stl.reporter.warn({
      from = __module_name__,
      subject = "setup",
      message = "Plugin loader already initialized",
    })
    return
  end
  M._initialized = true

  M.__register_plugins__(specs)
  M.__install_package_loader__()
  M.__load_plugins__(specs)
  M.__schedule_very_lazy__()
end

----------------------------------------------------------------------------------------------------

---@param specs                         dot.module.plugin.IPluginSpec[]
---@return nil
function M.__register_plugins__(specs)
  for _, spec in ipairs(specs) do
    ---@type dot.module.plugin.IPluginState
    local state = {
      spec = spec,
      loaded = false,
      path = M.__resolve_plugin_path__(spec),
    }
    M.plugins[spec.name] = state

    local main_module = M.__resolve_main_module__(spec) ---@type string
    M._module_to_plugin[main_module] = spec.name
  end
end

---@return nil
function M.__install_package_loader__()
  table.insert(package.loaders, 2, function(modname)
    local plugin_name = M._module_to_plugin[modname] ---@type string|nil
    if not plugin_name then
      local prefix = modname:match("^([^%.]+)") ---@type string|nil
      if prefix then
        plugin_name = M._module_to_plugin[prefix]
      end
    end

    if plugin_name then
      local state = M.plugins[plugin_name] ---@type dot.module.plugin.IPluginState|nil
      if state and not state.loaded then
        M.__load_plugin__(state)
      end

      local mod = package.loaded[modname]
      if mod ~= nil then
        return function()
          return mod
        end
      end
    end

    return nil
  end)
end

---@param specs                         dot.module.plugin.IPluginSpec[]
---@return nil
function M.__load_plugins__(specs)
  local dep_names = {} ---@type table<string, boolean>
  for _, spec in ipairs(specs) do
    if spec.dependencies then
      for _, dep in ipairs(spec.dependencies) do
        dep_names[dep] = true
      end
    end
  end

  for _, spec in ipairs(specs) do
    local has_lazy_triggers = (spec.event or spec.cmd or spec.ft or spec.keys) ~= nil ---@type boolean
    local is_dependency = dep_names[spec.name] or false ---@type boolean
    local is_lazy = spec.lazy ~= false and (spec.lazy or has_lazy_triggers or is_dependency) ---@type boolean

    if is_lazy then
      M.__setup_lazy_loading__(spec)
    else
      local state = M.plugins[spec.name] ---@type dot.module.plugin.IPluginState|nil
      if state then
        M.__load_plugin__(state)
      end
    end
  end
end

---@param state                         dot.module.plugin.IPluginState
---@return nil
function M.__load_plugin__(state)
  if state.loaded then
    return
  end

  local spec = state.spec ---@type dot.module.plugin.IPluginSpec

  if spec.cond and not spec.cond() then
    return
  end

  if spec.enabled == false then
    return
  end

  local start_time = vim.uv.hrtime() ---@type integer

  if spec.dependencies then
    for _, dep_name in ipairs(spec.dependencies) do
      local dep_state = M.plugins[dep_name] ---@type dot.module.plugin.IPluginState|nil
      if dep_state then
        M.__load_plugin__(dep_state)
      end
    end
  end

  state.loaded = true

  if state.path and yoz.path.is_exist(state.path) then
    vim.opt.rtp:prepend(state.path)

    local plugin_dir = dot.path.join(state.path, "plugin") ---@type string
    if yoz.path.is_exist(plugin_dir) then
      for _, file in ipairs(vim.fn.glob(plugin_dir .. "/*.lua", false, true)) do
        vim.cmd.source(file)
      end
      for _, file in ipairs(vim.fn.glob(plugin_dir .. "/*.vim", false, true)) do
        vim.cmd.source(file)
      end
    end

    local after_dir = dot.path.join(state.path, "after") ---@type string
    if yoz.path.is_exist(after_dir) then
      vim.opt.rtp:append(after_dir)
    end
  end

  local opts = {} ---@type table
  if spec.opts then
    opts = type(spec.opts) == "function" and spec.opts() or spec.opts --[[@as table]]
  end

  if spec.config then
    spec.config(spec, opts)
  elseif spec.main then
    local ok, mod = pcall(require, spec.main)
    if ok and mod and type(mod.setup) == "function" then
      mod.setup(opts)
    end
  end

  state.load_time = (vim.uv.hrtime() - start_time) / 1e6

  vim.schedule(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "PluginLoad", modeline = false, data = spec.name })
  end)
end

---@param spec                          dot.module.plugin.IPluginSpec
---@return string
function M.__resolve_main_module__(spec)
  if spec.main then
    return spec.main
  end

  local name = spec.name ---@type string
  name = name:gsub("%.nvim$", "")
  name = name:gsub("%.lua$", "")
  name = name:gsub("^nvim%-", "")
  name = name:gsub("%-nvim$", "")
  return name
end

---@param spec                          dot.module.plugin.IPluginSpec
---@return string
function M.__resolve_plugin_path__(spec)
  local State = require("dot.module.plugin.state")
  return dot.path.join(State.options.root, spec.name)
end

---@return nil
function M.__schedule_very_lazy__()
  local function fire()
    vim.schedule(function()
      if vim.v.exiting ~= vim.NIL then
        return
      end
      vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
    end)
  end

  if vim.v.vim_did_enter == 1 then
    fire()
  else
    vim.api.nvim_create_autocmd("UIEnter", {
      once = true,
      callback = fire,
    })
  end
end

---@param spec                          dot.module.plugin.IPluginSpec
---@return nil
function M.__setup_lazy_loading__(spec)
  local state = M.plugins[spec.name] ---@type dot.module.plugin.IPluginState|nil
  if not state then
    return
  end

  M.__setup_lazy_events__(spec, state)
  M.__setup_lazy_cmds__(spec, state)
  M.__setup_lazy_ft__(spec, state)
  M.__setup_lazy_keys__(spec, state)
end

---@param spec                          dot.module.plugin.IPluginSpec
---@param state                         dot.module.plugin.IPluginState
---@return nil
function M.__setup_lazy_events__(spec, state)
  if not spec.event then
    return
  end

  local events = type(spec.event) == "string" and { spec.event } or spec.event --[[@as string[] ]]
  for _, event in ipairs(events) do
    if event == "VeryLazy" then
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          M.__load_plugin__(state)
        end,
      })
    else
      vim.api.nvim_create_autocmd(event, {
        once = true,
        callback = function()
          M.__load_plugin__(state)
        end,
      })
    end
  end
end

---@param spec                          dot.module.plugin.IPluginSpec
---@param state                         dot.module.plugin.IPluginState
---@return nil
function M.__setup_lazy_cmds__(spec, state)
  if not spec.cmd then
    return
  end

  local cmds = type(spec.cmd) == "string" and { spec.cmd } or spec.cmd --[[@as string[] ]]
  for _, cmd in ipairs(cmds) do
    vim.api.nvim_create_user_command(cmd, function(cmd_opts)
      vim.api.nvim_del_user_command(cmd)
      M.__load_plugin__(state)
      vim.cmd(string.format("%s %s", cmd, cmd_opts.args or ""))
    end, {
      nargs = "*",
      complete = function()
        vim.api.nvim_del_user_command(cmd)
        M.__load_plugin__(state)
        return {}
      end,
    })
  end
end

---@param spec                          dot.module.plugin.IPluginSpec
---@param state                         dot.module.plugin.IPluginState
---@return nil
function M.__setup_lazy_ft__(spec, state)
  if not spec.ft then
    return
  end

  local fts = type(spec.ft) == "string" and { spec.ft } or spec.ft --[[@as string[] ]]
  vim.api.nvim_create_autocmd("FileType", {
    pattern = fts,
    once = true,
    callback = function()
      M.__load_plugin__(state)
    end,
  })
end

---@param spec                          dot.module.plugin.IPluginSpec
---@param state                         dot.module.plugin.IPluginState
---@return nil
function M.__setup_lazy_keys__(spec, state)
  if not spec.keys then
    return
  end

  for _, key_spec in ipairs(spec.keys) do
    local lhs = key_spec.lhs ---@type string
    local rhs = key_spec.rhs ---@type string|fun()|nil
    local modes = type(key_spec.mode) == "string" and { key_spec.mode } or key_spec.mode or { "n" } --[[@as string[] ]]

    for _, mode in ipairs(modes) do
      vim.keymap.set(mode, lhs, function()
        for _, m in ipairs(modes) do
          pcall(vim.keymap.del, m, lhs)
        end

        M.__load_plugin__(state)

        if rhs then
          ---@type vim.keymap.set.Opts
          local opts = {
            desc = key_spec.desc,
            noremap = key_spec.noremap,
            remap = key_spec.remap,
            expr = key_spec.expr,
            nowait = key_spec.nowait,
          }
          for _, m in ipairs(modes) do
            vim.keymap.set(m, lhs, rhs, opts)
          end
        end

        local key = mode:sub(-1) == "a" and (lhs .. "<C-]>") or lhs ---@type string
        local feed = vim.api.nvim_replace_termcodes("<Ignore>" .. key, true, true, true) ---@type string
        vim.api.nvim_feedkeys(feed, "i", false)
      end, {
        desc = key_spec.desc or ("Load " .. spec.name),
        nowait = key_spec.nowait,
        expr = true,
      })
    end
  end
end

return M
