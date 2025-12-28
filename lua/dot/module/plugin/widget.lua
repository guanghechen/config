local State = require("dot.module.plugin.state")

---@class dot.module.plugin.Widget
---@field public padding                integer
---@field public wrap                   integer
---@field protected _view               dot.module.plugin.View
---@field protected _lines              dot.module.plugin.ITextSegment[][]
local M = {}
M.__index = M

---@param view                          dot.module.plugin.View
---@return dot.module.plugin.Widget
function M.new(view)
  local self = setmetatable({}, M)
  self._view = view
  self._lines = {}
  self.padding = 2
  self.wrap = view.win_opts.width
  return self
end

---@return nil
function M:update()
  self._lines = {}
  self:__title__()

  local mode = self._view.state.mode ---@type dot.module.plugin.ViewModeEnum
  if mode == "profile" then
    self:__profile__()
  elseif mode == "update" then
    self:__update__()
  elseif mode == "clean" then
    self:__clean__()
  else
    self:__home__()
  end

  self:__trim__()

  vim.bo[self._view.bufnr].modifiable = true
  self:__render__(self._view.bufnr)
  vim.bo[self._view.bufnr].modifiable = false
end

----------------------------------------------------------------------------------------------------

---@param str                           string
---@param hl                            string|nil
---@return dot.module.plugin.Widget
function M:__append__(str, hl)
  if #self._lines == 0 then
    self:__nl__()
  end
  table.insert(self._lines[#self._lines], { str = str, hl = hl })
  return self
end

---@return dot.module.plugin.Widget
function M:__nl__()
  table.insert(self._lines, {})
  return self
end

---@param bufnr                         integer
---@return nil
function M:__render__(bufnr)
  local lines = {} ---@type string[]
  for _, line in ipairs(self._lines) do
    local str = (" "):rep(self.padding) ---@type string
    for _, segment in ipairs(line) do
      str = str .. segment.str
    end
    if str:match("^%s*$") then
      str = ""
    end
    table.insert(lines, str)
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(bufnr, State.ns, 0, -1)

  for l, line in ipairs(self._lines) do
    if lines[l] ~= "" then
      local col = self.padding ---@type integer
      for _, segment in ipairs(line) do
        local width = vim.fn.strlen(segment.str) ---@type integer
        if segment.hl then
          vim.api.nvim_buf_set_extmark(bufnr, State.ns, l - 1, col, {
            hl_group = segment.hl,
            end_col = col + width,
          })
        end
        col = col + width
      end
    end
  end
end

---@return nil
function M:__trim__()
  while #self._lines > 0 and #self._lines[#self._lines] == 0 do
    table.remove(self._lines)
  end
end

---@return nil
function M:__title__()
  self:__nl__():__nl__()

  local icons = State.options.ui.icons

  if self._view.state.mode == "home" then
    self:__append__(" Home " .. icons.lazy, "m_pl_h1")
  else
    self:__append__(" Home (H) ", "m_pl_button")
  end

  self:__append__(" ")

  if self._view.state.mode == "profile" then
    self:__append__(" Profile " .. icons.lazy, "m_pl_h1")
  else
    self:__append__(" Profile (P) ", "m_pl_button")
  end

  self:__append__(" ")

  if self._view.state.mode == "update" then
    self:__append__(" Update " .. icons.lazy, "m_pl_h1")
  else
    self:__append__(" Update (U) ", "m_pl_button")
  end

  self:__append__(" ")

  if self._view.state.mode == "clean" then
    self:__append__(" Clean " .. icons.lazy, "m_pl_h1")
  else
    self:__append__(" Clean (X) ", "m_pl_button")
  end

  self:__nl__():__nl__()
end

---@param spec                          dot.module.plugin.IPluginSpec
---@return nil
function M:__append_triggers__(spec)
  local icons = State.options.ui.icons

  if spec.event then
    local events = type(spec.event) == "string" and { spec.event } or spec.event --[[@as string[] ]]
    for _, event in ipairs(events) do
      self:__append__(" " .. icons.event, "m_pl_icon_event")
      self:__append__(event, "m_pl_event")
    end
  end

  if spec.cmd then
    local cmds = type(spec.cmd) == "string" and { spec.cmd } or spec.cmd --[[@as string[] ]]
    for _, cmd in ipairs(cmds) do
      self:__append__(" " .. icons.cmd, "m_pl_icon_cmd")
      self:__append__(cmd, "m_pl_cmd")
    end
  end

  if spec.ft then
    local fts = type(spec.ft) == "string" and { spec.ft } or spec.ft --[[@as string[] ]]
    for _, ft in ipairs(fts) do
      self:__append__(" " .. icons.ft, "m_pl_icon_ft")
      self:__append__(ft, "m_pl_ft")
    end
  end

  if spec.keys then
    for _, key_spec in ipairs(spec.keys) do
      local lhs = key_spec[1] ---@type string
      local modes = key_spec.mode or { "n" }
      if type(modes) == "string" then
        modes = { modes }
      end
      for _, mode in ipairs(modes) do
        self:__append__(" " .. icons.keys, "m_pl_icon_key")
        if mode == "n" then
          self:__append__(lhs, "m_pl_key")
        else
          self:__append__(lhs .. " (" .. mode .. ")", "m_pl_key")
        end
      end
    end
  end

  if spec.dependencies then
    for _, dep in ipairs(spec.dependencies) do
      self:__append__(" " .. icons.dep, "m_pl_icon_dep")
      self:__append__(dep, "m_pl_dep")
    end
  end
end

---@param state                         dot.module.plugin.IPluginState
---@param show_time                     boolean
---@return nil
function M:__render_plugin__(state, show_time)
  local spec = state.spec ---@type dot.module.plugin.IPluginSpec
  local icons = State.options.ui.icons

  if state.loaded then
    self:__append__("  " .. icons.loaded .. " ", "m_pl_loaded")
  else
    self:__append__("  " .. icons.not_loaded .. " ", "m_pl_not_loaded")
  end

  self:__append__(spec.name, "m_pl_bold")

  if show_time and state.load_time then
    self:__append__(" " .. string.format("%.2fms", state.load_time), "m_pl_time")
  end

  self:__append_triggers__(spec)
  self:__nl__()
end

---@return dot.module.plugin.IPluginState[], dot.module.plugin.IPluginState[]
function M:__collect_plugins__()
  local Loader = require("dot.module.plugin.loader")
  local plugins = Loader.get_all() ---@type table<string, dot.module.plugin.IPluginState>

  local loaded = {} ---@type dot.module.plugin.IPluginState[]
  local not_loaded = {} ---@type dot.module.plugin.IPluginState[]

  for _, state in pairs(plugins) do
    if state.loaded then
      loaded[#loaded + 1] = state
    else
      not_loaded[#not_loaded + 1] = state
    end
  end

  return loaded, not_loaded
end

---@return string[]
function M:__collect_to_clean__()
  return State.collect_orphan_plugins()
end

---@return nil
function M:__home__()
  local loaded, not_loaded = self:__collect_plugins__()
  local to_clean = self:__collect_to_clean__()
  local total = #loaded + #not_loaded ---@type integer

  table.sort(loaded, function(a, b)
    return a.spec.name < b.spec.name
  end)
  table.sort(not_loaded, function(a, b)
    return a.spec.name < b.spec.name
  end)

  self:__append__("Total:", "m_pl_h2"):__append__(" " .. total .. " plugins", "m_pl_comment"):__nl__():__nl__()

  if #to_clean > 0 then
    self:__append__("Clean", "m_pl_h2"):__append__(" (" .. #to_clean .. ")", "m_pl_comment"):__nl__()
    local icons = State.options.ui.icons
    for _, name in ipairs(to_clean) do
      self:__append__("  " .. icons.not_loaded .. " ", "m_pl_not_loaded")
      self:__append__(name, "m_pl_bold"):__nl__()
    end
    self:__nl__()
  end

  if #loaded > 0 then
    self:__append__("Loaded", "m_pl_h2"):__append__(" (" .. #loaded .. ")", "m_pl_comment"):__nl__()
    for _, state in ipairs(loaded) do
      self:__render_plugin__(state, true)
    end
    self:__nl__()
  end

  if #not_loaded > 0 then
    self:__append__("Not Loaded", "m_pl_h2"):__append__(" (" .. #not_loaded .. ")", "m_pl_comment"):__nl__()
    for _, state in ipairs(not_loaded) do
      self:__render_plugin__(state, false)
    end
  end

  if total == 0 then
    self:__append__("  No plugins found", "m_pl_comment"):__nl__()
  end
end

---@return nil
function M:__profile__()
  local loaded, _ = self:__collect_plugins__()

  local total_time = 0 ---@type number
  for _, state in ipairs(loaded) do
    total_time = total_time + (state.load_time or 0)
  end

  table.sort(loaded, function(a, b)
    return (a.load_time or 0) > (b.load_time or 0)
  end)

  self:__append__("Total:", "m_pl_h2"):__append__(" " .. string.format("%.2fms", total_time), "m_pl_comment"):__nl__():__nl__()

  if #loaded > 0 then
    self:__append__("Startup Profile", "m_pl_h2"):__nl__()
    for _, state in ipairs(loaded) do
      self:__render_plugin__(state, true)
    end
  else
    self:__append__("  No plugins loaded yet", "m_pl_comment"):__nl__()
  end
end

---@return nil
function M:__update__()
  local Action = require("dot.module.plugin.action")
  local Loader = require("dot.module.plugin.loader")
  local tasks = Action.get_tasks() ---@type table<string, dot.module.plugin.ITaskState>
  local is_running = Action.is_running() ---@type boolean

  if is_running then
    self:__append__("Updating plugins...", "m_pl_h2"):__nl__():__nl__()

    local names = vim.tbl_keys(tasks) ---@type string[]
    table.sort(names)

    for _, name in ipairs(names) do
      local task = tasks[name]
      self:__render_task_progress__(task)
    end
    return
  end

  if vim.tbl_isempty(tasks) then
    self:__append__("Press ", "m_pl_comment")
    self:__append__("U", "m_pl_key")
    self:__append__(" to update all plugins", "m_pl_comment"):__nl__()
    return
  end

  self:__append__("Update Complete", "m_pl_h2"):__nl__():__nl__()

  local names = vim.tbl_keys(tasks) ---@type string[]
  table.sort(names)

  local updated = {} ---@type dot.module.plugin.ITaskState[]
  local unchanged = {} ---@type dot.module.plugin.ITaskState[]
  local errors = {} ---@type dot.module.plugin.ITaskState[]

  for _, name in ipairs(names) do
    local task = tasks[name]
    if task.status == "error" then
      errors[#errors + 1] = task
    elseif task.from_commit and task.to_commit and task.from_commit ~= task.to_commit then
      updated[#updated + 1] = task
    else
      unchanged[#unchanged + 1] = task
    end
  end

  if #errors > 0 then
    self:__append__("Errors", "m_pl_h2"):__append__(" (" .. #errors .. ")", "m_pl_comment"):__nl__()
    for _, task in ipairs(errors) do
      self:__render_task_result__(task, Loader.get(task.name))
    end
    self:__nl__()
  end

  if #updated > 0 then
    self:__append__("Updated", "m_pl_h2"):__append__(" (" .. #updated .. ")", "m_pl_comment"):__nl__()
    for _, task in ipairs(updated) do
      self:__render_task_result__(task, Loader.get(task.name))
    end
    self:__nl__()
  end

  if #unchanged > 0 then
    self:__append__("Unchanged", "m_pl_h2"):__append__(" (" .. #unchanged .. ")", "m_pl_comment"):__nl__()
    for _, task in ipairs(unchanged) do
      self:__render_task_result__(task, Loader.get(task.name))
    end
  end
end

---@return nil
function M:__clean__()
  local Action = require("dot.module.plugin.action")
  local tasks = Action.get_tasks() ---@type table<string, dot.module.plugin.ITaskState>
  local is_running = Action.is_running() ---@type boolean

  if is_running then
    self:__append__("Cleaning plugins...", "m_pl_h2"):__nl__():__nl__()
    return
  end

  local to_clean = State.collect_orphan_plugins() ---@type string[]

  if not vim.tbl_isempty(tasks) then
    self:__append__("Clean Complete", "m_pl_h2"):__nl__():__nl__()
    local names = vim.tbl_keys(tasks) ---@type string[]
    table.sort(names)
    for _, name in ipairs(names) do
      local task = tasks[name]
      self:__render_task_progress__(task)
    end
    return
  end

  if #to_clean == 0 then
    self:__append__("No plugins to clean", "m_pl_comment"):__nl__()
    return
  end

  self:__append__("Plugins to clean:", "m_pl_h2"):__append__(" (" .. #to_clean .. ")", "m_pl_comment"):__nl__():__nl__()
  self:__append__("Press ", "m_pl_comment")
  self:__append__("X", "m_pl_key")
  self:__append__(" to remove these plugins:", "m_pl_comment"):__nl__():__nl__()

  for _, name in ipairs(to_clean) do
    self:__append__("  ", nil)
    self:__append__(name, "m_pl_bold"):__nl__()
  end
end

---@param task                          dot.module.plugin.ITaskState
---@return nil
function M:__render_task_progress__(task)
  local icons = State.options.ui.icons
  local status_icon = "" ---@type string
  local status_hl = "" ---@type string

  if task.status == "running" then
    status_icon = icons.lazy
    status_hl = "m_pl_running"
  elseif task.status == "done" then
    status_icon = icons.loaded
    status_hl = "m_pl_loaded"
  else
    status_icon = ""
    status_hl = "m_pl_error"
  end

  self:__append__("  " .. status_icon .. " ", status_hl)
  self:__append__(task.name, "m_pl_bold")

  if task.message and task.message ~= "" then
    self:__append__(" ", nil)
    self:__append__(task.message, "m_pl_comment")
  end

  self:__nl__()
end

---@param task                          dot.module.plugin.ITaskState
---@param plugin_state                  dot.module.plugin.IPluginState|nil
---@return nil
function M:__render_task_result__(task, plugin_state)
  local icons = State.options.ui.icons
  local status_icon = "" ---@type string
  local status_hl = "" ---@type string

  if task.status == "error" then
    status_icon = ""
    status_hl = "m_pl_error"
  elseif plugin_state and plugin_state.loaded then
    status_icon = icons.loaded
    status_hl = "m_pl_loaded"
  else
    status_icon = icons.not_loaded
    status_hl = "m_pl_not_loaded"
  end

  self:__append__("  " .. status_icon .. " ", status_hl)
  self:__append__(task.name, "m_pl_bold")

  if task.from_commit and task.to_commit and task.from_commit ~= task.to_commit then
    self:__append__(" ", nil)
    self:__append__(task.from_commit, "m_pl_commit_from")
    self:__append__(" → ", "m_pl_comment")
    self:__append__(task.to_commit, "m_pl_commit_to")
  end

  if plugin_state then
    self:__append_triggers__(plugin_state.spec)
  end

  self:__nl__()

  if task.commits and #task.commits > 0 then
    for _, commit in ipairs(task.commits) do
      self:__render_commit__(commit)
    end
  end
end

---@param commit                        dot.module.plugin.ICommitInfo
---@return nil
function M:__render_commit__(commit)
  self:__append__("      ", nil)
  self:__append__(commit.hash .. " ", "m_pl_commit")

  local msg = commit.message ---@type string
  local type_prefix = msg:match("^%S+:") ---@type string|nil
  if type_prefix then
    self:__append__(type_prefix, "m_pl_commit_type")
    self:__append__(msg:sub(#type_prefix + 1), "m_pl_commit_msg")
  else
    self:__append__(msg, "m_pl_commit_msg")
  end

  self:__append__(" " .. commit.time, "m_pl_commit_time")
  self:__nl__()
end

return M
