local State = require("era.m.plugin.state")

---@class era.m.plugin.Widget
---@field public padding                integer
---@field public wrap                   integer
---@field protected _view               era.m.plugin.View
---@field protected _lines              era.m.plugin.ITextSegment[][]
---@field protected _required_by        table<string, string[]>
---@field protected _line_to_plugin     table<integer, string>
local M = {}
M.__index = M

---@param view                          era.m.plugin.View
---@return era.m.plugin.Widget
function M.new(view)
  local self = setmetatable({}, M)
  self._view = view
  self._lines = {}
  self._required_by = {}
  self._line_to_plugin = {}
  self.padding = 2
  self.wrap = view.win_opts.width
  return self
end

---@return nil
function M:update()
  local cursor_plugin = self:__cursor_plugin__() ---@type string|nil
  self._lines = {}
  self._line_to_plugin = {}
  self:__build_required_by__()
  self:__header__()
  self:__home__()

  self:__trim__()

  vim.api.nvim_set_option_value("modifiable", true, { buf = self._view.bufnr })
  self:__render__(self._view.bufnr)
  vim.api.nvim_set_option_value("modifiable", false, { buf = self._view.bufnr })
  self:__restore_cursor__(cursor_plugin)
end

----------------------------------------------------------------------------------------------------

---@return string|nil
function M:__cursor_plugin__()
  local winnr = self._view.winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end
  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  return self._line_to_plugin[cursor[1]]
end

---@param plugin_name                   string|nil
---@return nil
function M:__restore_cursor__(plugin_name)
  if plugin_name == nil then
    return
  end
  local winnr = self._view.winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return
  end
  for line = 1, #self._lines do
    if self._line_to_plugin[line] == plugin_name then
      vim.api.nvim_win_set_cursor(winnr, { line, 0 })
      return
    end
  end
end

----------------------------------------------------------------------------------------------------

---@return nil
function M:__build_required_by__()
  self._required_by = {}
  local Loader = require("era.m.plugin.loader")
  local plugins = Loader.get_all() ---@type table<string, era.m.plugin.IPluginState>

  for _, state in pairs(plugins) do
    local spec = state.spec ---@type era.m.plugin.IPluginSpec
    if spec.dependencies then
      for _, dep_name in ipairs(spec.dependencies) do
        if not self._required_by[dep_name] then
          self._required_by[dep_name] = {}
        end
        table.insert(self._required_by[dep_name], spec.name)
      end
    end
  end

  for _, list in pairs(self._required_by) do
    table.sort(list)
  end
end

---@param str                           string
---@param hl                            string|nil
---@return era.m.plugin.Widget
function M:__append__(str, hl)
  if #self._lines == 0 then
    self:__nl__()
  end
  table.insert(self._lines[#self._lines], { str = str, hl = hl })
  return self
end

---@return era.m.plugin.Widget
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
function M:__header__()
  self:__nl__():__nl__()

  local gap = "    "
  local install_icon = stl.icon.ui.CloudDownload
  local sync_icon = stl.icon.ui.Lock
  local update_icon = stl.icon.ui.ArrowUp
  local clean_icon = stl.icon.ui.Trash
  local shortcuts = table.concat({
    install_icon .. " I Install",
    sync_icon .. " S Sync",
    update_icon .. " U Update",
    clean_icon .. " X Clean",
  }, gap)
  local available_width = self._view.win_opts.width - self.padding * 2 ---@type integer
  local shortcut_padding = math.max(0, math.floor((available_width - vim.fn.strdisplaywidth(shortcuts)) / 2))

  self:__append__(string.rep(" ", shortcut_padding))
  self:__append__(install_icon .. " ", "m_pl_loaded")
  self:__append__("I", "m_pl_key"):__append__(" Install" .. gap, "m_pl_comment")
  self:__append__(sync_icon .. " ", "m_pl_event")
  self:__append__("S", "m_pl_key"):__append__(" Sync" .. gap, "m_pl_comment")
  self:__append__(update_icon .. " ", "m_pl_time")
  self:__append__("U", "m_pl_key"):__append__(" Update" .. gap, "m_pl_comment")
  self:__append__(clean_icon .. " ", "m_pl_error")
  self:__append__("X", "m_pl_key"):__append__(" Clean", "m_pl_comment")
  self:__nl__():__nl__()

  local Loader = require("era.m.plugin.loader")
  local profile = Loader.get_startup_profile() ---@type era.m.plugin.IStartupProfile
  local nvim_startup_time = profile.nvim_startup_time ---@type number|nil

  self
    :__append__("Neovim", "m_pl_bold")
    :__append__(nvim_startup_time and (" " .. string.format("%.2fms", nvim_startup_time)) or " pending", "m_pl_comment")
    :__append__("    Startup", "m_pl_bold")
    :__append__(" " .. string.format("%.2fms", profile.total_time), "m_pl_comment")

  local Action = require("era.m.plugin.action")
  if Action.is_running() then
    local progress = Action.get_progress() ---@type era.m.plugin.IOperationProgress
    local labels = {
      install = "Installing",
      sync = "Syncing",
      update = "Updating",
      clean = "Cleaning",
      build = "Building",
    } ---@type table<era.m.plugin.ActionEnum, string>
    local completed = progress.done + progress.error ---@type integer
    self:__append__("    " .. (labels[progress.action] or "Running"), "m_pl_bold")
    self:__append__(string.format(" %d/%d", completed, progress.total), "m_pl_comment")
    if progress.queued > 0 then
      self:__append__("    Queued " .. progress.queued, "m_pl_comment")
    end
    if progress.error > 0 then
      self:__append__("    Failed " .. progress.error, "m_pl_error")
    end
  end

  self:__nl__():__nl__()
end

---@param spec                          era.m.plugin.IPluginSpec
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
      local lhs = key_spec.lhs ---@type string
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

  local required_by = self._required_by[spec.name] ---@type string[]|nil
  if required_by then
    for _, requirer in ipairs(required_by) do
      self:__append__(" " .. icons.source, "m_pl_icon_source")
      self:__append__(requirer, "m_pl_source")
    end
  end
end

---@class era.m.plugin.IPluginGroups
---@field public startup                era.m.plugin.IPluginState[]
---@field public runtime                era.m.plugin.IPluginState[]
---@field public not_loaded             era.m.plugin.IPluginState[]
---@field public missing                era.m.plugin.IPluginState[]
---@field public by_name                table<string, era.m.plugin.IPluginState>

---@param task                          era.m.plugin.ITaskState|nil
---@return boolean
function M:__task_is_visible__(task)
  if task == nil then
    return false
  end
  return task.status ~= "done" or task.from_commit == nil or task.from_commit ~= task.to_commit
end

---@param task                          era.m.plugin.ITaskState
---@return nil
function M:__render_task__(task)
  local icons = State.options.ui.icons
  local status_icon = "" ---@type string
  local status_hl = "" ---@type string

  if task.status == "queued" then
    status_icon = icons.not_loaded
    status_hl = "m_pl_not_loaded"
  elseif task.status == "running" then
    status_icon = icons.lazy
    status_hl = "m_pl_running"
  elseif task.status == "error" then
    status_icon = icons.not_loaded
    status_hl = "m_pl_error"
  else
    status_icon = icons.loaded
    status_hl = "m_pl_loaded"
  end

  self:__append__("    ╰─ ", "m_pl_comment")
  self:__append__(status_icon .. " ", status_hl)

  if task.step then
    self:__append__("[", "m_pl_comment")
    self:__append__(task.step, "m_pl_step")
    self:__append__("] ", "m_pl_comment")
  end

  if task.from_commit and task.to_commit and task.from_commit ~= task.to_commit then
    self:__append__(task.from_commit, "m_pl_commit_from")
    self:__append__(" → ", "m_pl_comment")
    self:__append__(task.to_commit .. " ", "m_pl_commit_to")
  end

  if task.message and task.message ~= "" then
    self:__append__(task.message, task.status == "error" and "m_pl_error" or "m_pl_comment")
  end

  self._line_to_plugin[#self._lines] = task.name
  self:__nl__()

  if task.commits and #task.commits > 0 then
    for index, commit in ipairs(task.commits) do
      self:__render_commit__(commit, task.name, index == #task.commits)
    end
  end

  if task.status ~= "done" and task.output and #task.output > 0 then
    for index, line in ipairs(task.output) do
      local prefix = index == #task.output and "       ╰─ " or "       ├─ "
      self:__append__(prefix .. line, "m_pl_output")
      self._line_to_plugin[#self._lines] = task.name
      self:__nl__()
    end
  end
end

---@param state                         era.m.plugin.IPluginState
---@param task                          era.m.plugin.ITaskState|nil
---@return nil
function M:__render_plugin__(state, task)
  local spec = state.spec ---@type era.m.plugin.IPluginSpec
  local icons = State.options.ui.icons

  if state.loaded then
    self:__append__("  " .. icons.loaded .. " ", "m_pl_loaded")
  else
    self:__append__("  " .. icons.not_loaded .. " ", "m_pl_not_loaded")
  end

  self:__append__(spec.name, "m_pl_bold")
  if state.loaded and state.load_time then
    self:__append__(" " .. string.format("%.2fms", state.load_time), "m_pl_time")
  end
  self:__append_triggers__(spec)

  self._line_to_plugin[#self._lines] = spec.name
  self:__nl__()

  if task ~= nil and self:__task_is_visible__(task) then
    self:__render_task__(task)
  end
end

---@param name                          string
---@param task                          era.m.plugin.ITaskState|nil
---@return nil
function M:__render_orphan__(name, task)
  local icons = State.options.ui.icons
  self:__append__("  " .. icons.not_loaded .. " ", "m_pl_not_loaded")
  self:__append__(name, "m_pl_bold")
  self._line_to_plugin[#self._lines] = name
  self:__nl__()

  if task ~= nil and self:__task_is_visible__(task) then
    self:__render_task__(task)
  end
end

---@param task                          era.m.plugin.ITaskState
---@return nil
function M:__render_operation_task__(task)
  local icons = State.options.ui.icons
  local icon = task.status == "queued" and icons.not_loaded or icons.lazy
  local icon_hl = task.status == "queued" and "m_pl_not_loaded" or "m_pl_running"

  self:__append__("  " .. icon .. " ", icon_hl)
  self:__append__(task.name, "m_pl_bold")
  if task.step then
    self:__append__(" [", "m_pl_comment")
    self:__append__(task.step, "m_pl_step")
    self:__append__("]", "m_pl_comment")
  end
  if task.message and task.message ~= "" then
    self:__append__(" " .. task.message, "m_pl_comment")
  end
  self._line_to_plugin[#self._lines] = task.name
  self:__nl__()

  if task.output and #task.output > 0 then
    for index, line in ipairs(task.output) do
      local prefix = index == #task.output and "    ╰─ " or "    ├─ "
      self:__append__(prefix .. line, "m_pl_output")
      self._line_to_plugin[#self._lines] = task.name
      self:__nl__()
    end
  end
end

---@param title                         string
---@param tasks                         era.m.plugin.ITaskState[]
---@return nil
function M:__render_task_section__(title, tasks)
  if #tasks == 0 then
    return
  end
  table.sort(tasks, function(a, b)
    return a.name < b.name
  end)
  self:__append__(title, "m_pl_h2"):__append__(" (" .. #tasks .. ")", "m_pl_comment"):__nl__()
  for _, task in ipairs(tasks) do
    self:__render_operation_task__(task)
  end
  self:__nl__()
end

---@param tasks                         table<string, era.m.plugin.ITaskState>
---@return table<string, boolean>
function M:__render_operation_sections__(tasks)
  local queued = {} ---@type era.m.plugin.ITaskState[]
  local running = {} ---@type era.m.plugin.ITaskState[]
  local active = {} ---@type table<string, boolean>
  local action = nil ---@type era.m.plugin.ActionEnum|nil

  for name, task in pairs(tasks) do
    if task.status == "queued" then
      queued[#queued + 1] = task
      active[name] = true
      action = action or task.action
    elseif task.status == "running" then
      running[#running + 1] = task
      active[name] = true
      action = action or task.action
    end
  end

  local titles = {
    install = "Installing",
    sync = "Syncing",
    update = "Updating",
    clean = "Cleaning",
    build = "Building",
  } ---@type table<era.m.plugin.ActionEnum, string>
  self:__render_task_section__(titles[action] or "Running", running)
  self:__render_task_section__("Queued", queued)
  return active
end

---@return era.m.plugin.IPluginGroups
function M:__collect_plugins__()
  local Loader = require("era.m.plugin.loader")
  local plugins = Loader.get_all() ---@type table<string, era.m.plugin.IPluginState>
  local groups = {
    startup = {},
    runtime = {},
    not_loaded = {},
    missing = {},
    by_name = plugins,
  } ---@type era.m.plugin.IPluginGroups

  for _, state in pairs(plugins) do
    if state.loaded and state.startup then
      groups.startup[#groups.startup + 1] = state
    elseif state.loaded then
      groups.runtime[#groups.runtime + 1] = state
    else
      local path = state.path or dot.path.join(State.options.root, state.spec.name) ---@type string
      local target = yoz.path.is_exist(path) and groups.not_loaded or groups.missing
      target[#target + 1] = state
    end
  end

  local function sort_by_name(states)
    table.sort(states, function(a, b)
      return a.spec.name < b.spec.name
    end)
  end

  local function sort_by_time(states)
    table.sort(states, function(a, b)
      local left = a.load_time or 0 ---@type number
      local right = b.load_time or 0 ---@type number
      return left == right and a.spec.name < b.spec.name or left > right
    end)
  end

  sort_by_time(groups.startup)
  sort_by_time(groups.runtime)
  sort_by_name(groups.not_loaded)
  sort_by_name(groups.missing)
  return groups
end

---@param title                         string
---@param states                        era.m.plugin.IPluginState[]
---@param tasks                         table<string, era.m.plugin.ITaskState>
---@param excluded                      table<string, boolean>
---@return nil
function M:__render_plugin_section__(title, states, tasks, excluded)
  local visible = {} ---@type era.m.plugin.IPluginState[]
  for _, state in ipairs(states) do
    if not excluded[state.spec.name] then
      visible[#visible + 1] = state
    end
  end
  if #visible == 0 then
    return
  end

  self:__append__(title, "m_pl_h2"):__append__(" (" .. #visible .. ")", "m_pl_comment"):__nl__()
  for _, state in ipairs(visible) do
    self:__render_plugin__(state, tasks[state.spec.name])
  end
  self:__nl__()
end

---@return nil
function M:__home__()
  local Action = require("era.m.plugin.action")
  local groups = self:__collect_plugins__()
  local tasks = Action.get_tasks() ---@type table<string, era.m.plugin.ITaskState>
  local total = #groups.startup + #groups.runtime + #groups.not_loaded + #groups.missing ---@type integer

  self:__append__("Total:", "m_pl_h2"):__append__(" " .. total .. " plugins", "m_pl_comment"):__nl__():__nl__()

  local active = self:__render_operation_sections__(tasks) ---@type table<string, boolean>

  self:__render_plugin_section__("Missing", groups.missing, tasks, active)

  local orphan_set = {} ---@type table<string, boolean>
  for _, name in ipairs(State.collect_orphan_plugins()) do
    orphan_set[name] = true
  end
  for name, task in pairs(tasks) do
    if groups.by_name[name] == nil and self:__task_is_visible__(task) then
      orphan_set[name] = true
    end
  end

  local orphans = vim.tbl_keys(orphan_set) ---@type string[]
  table.sort(orphans)
  local visible_orphans = {} ---@type string[]
  for _, name in ipairs(orphans) do
    if not active[name] then
      visible_orphans[#visible_orphans + 1] = name
    end
  end
  if #visible_orphans > 0 then
    self:__append__("Orphans", "m_pl_h2"):__append__(" (" .. #visible_orphans .. ")", "m_pl_comment"):__nl__()
    for _, name in ipairs(visible_orphans) do
      self:__render_orphan__(name, tasks[name])
    end
    self:__nl__()
  end

  self:__render_plugin_section__("Startup", groups.startup, tasks, active)
  self:__render_plugin_section__("Runtime Loaded", groups.runtime, tasks, active)
  self:__render_plugin_section__("Not Loaded", groups.not_loaded, tasks, active)

  if total == 0 then
    self:__append__("  No plugins found", "m_pl_comment"):__nl__()
  end
end

---@param commit                        era.m.plugin.ICommitInfo
---@param plugin_name                   string
---@param is_last                       boolean
---@return nil
function M:__render_commit__(commit, plugin_name, is_last)
  self:__append__("       " .. (is_last and "╰─ " or "├─ "), "m_pl_comment")
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
  self._line_to_plugin[#self._lines] = plugin_name
  self:__nl__()
end

---@param line                          integer
---@return string|nil
function M:get_plugin_at_line(line)
  return self._line_to_plugin[line]
end

return M
