--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/plugin/widget_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local State = require("era.m.plugin.state")
local Widget = require("era.m.plugin.widget")
local t = harness.new("era.m.plugin.widget")

---@param widget                        era.m.plugin.Widget
---@return string[]
local function lines_of(widget)
  local lines = {} ---@type string[]
  ---@diagnostic disable-next-line: invisible
  for _, segments in ipairs(widget._lines) do
    local line = ""
    for _, segment in ipairs(segments) do
      line = line .. segment.str
    end
    lines[#lines + 1] = line
  end
  return lines
end

---@param lines                         string[]
---@param pattern                       string
---@return integer
local function find_line(lines, pattern)
  for index, line in ipairs(lines) do
    if line:find(pattern, 1, true) then
      return index
    end
  end
  error("line not found: " .. pattern, 2)
end

t:test("home merges startup profile, inventory, and nested tasks", function()
  local plugins = {
    fast = {
      spec = { name = "fast.nvim" },
      loaded = true,
      loading = false,
      startup = true,
      load_time = 2,
      path = "/plugins/fast.nvim",
    },
    slow = {
      spec = { name = "slow.nvim" },
      loaded = true,
      loading = false,
      startup = true,
      load_time = 20,
      path = "/plugins/slow.nvim",
    },
    runtime = {
      spec = { name = "runtime.nvim" },
      loaded = true,
      loading = false,
      startup = false,
      load_time = 5,
      path = "/plugins/runtime.nvim",
    },
    idle = {
      spec = { name = "idle.nvim" },
      loaded = false,
      loading = false,
      startup = false,
      path = "/plugins/idle.nvim",
    },
    dormant = {
      spec = { name = "dormant.nvim" },
      loaded = false,
      loading = false,
      startup = false,
      path = "/plugins/dormant.nvim",
    },
    missing = {
      spec = { name = "missing.nvim" },
      loaded = false,
      loading = false,
      startup = false,
      path = "/plugins/missing.nvim",
    },
  } ---@type table<string, era.m.plugin.IPluginState>
  local tasks = {
    ---@diagnostic disable-next-line: missing-fields
    ["slow.nvim"] = {
      name = "slow.nvim",
      action = "update",
      status = "done",
      message = "Updated",
      from_commit = "aaaaaaa",
      to_commit = "bbbbbbb",
    },
    ---@diagnostic disable-next-line: missing-fields
    ["runtime.nvim"] = {
      name = "runtime.nvim",
      action = "update",
      status = "done",
      message = "Already up to date",
      from_commit = "ccccccc",
      to_commit = "ccccccc",
    },
    ---@diagnostic disable-next-line: missing-fields
    ["missing.nvim"] = {
      name = "missing.nvim",
      action = "install",
      status = "running",
      step = "cloning",
      message = "Cloning...",
      output = { "receiving objects" },
      from_commit = nil,
      to_commit = nil,
    },
    ---@diagnostic disable-next-line: missing-fields
    ["orphan.nvim"] = {
      name = "orphan.nvim",
      action = "clean",
      status = "done",
      message = "Removed",
      from_commit = nil,
      to_commit = nil,
    },
    ---@diagnostic disable-next-line: missing-fields
    ["idle.nvim"] = {
      name = "idle.nvim",
      action = "install",
      status = "queued",
      message = "Queued",
      from_commit = nil,
      to_commit = nil,
    },
  } ---@type table<string, era.m.plugin.ITaskState>

  t:patch_table(package.loaded, "era.m.plugin.loader", {
    get_all = function()
      return plugins
    end,
    get_startup_profile = function()
      return { plugins = { plugins.slow, plugins.fast }, nvim_startup_time = 30, total_time = 22, finalized = true }
    end,
  })
  t:patch_table(package.loaded, "era.m.plugin.action", {
    is_running = function()
      return true
    end,
    get_progress = function()
      return { action = "install", total = 2, queued = 1, running = 1, done = 0, error = 0 }
    end,
    get_tasks = function()
      return tasks
    end,
  })
  t:patch_table(State, "collect_orphan_plugins", function()
    return {}
  end)
  t:patch_table(yoz.path, "is_exist", function(path)
    return path ~= "/plugins/missing.nvim"
  end)

  ---@diagnostic disable-next-line: missing-fields
  local widget = Widget.new({ win_opts = { width = 132 } } --[[@as era.m.plugin.View]])
  widget:__build_required_by__()
  widget:__header__()
  widget:__home__()
  local lines = lines_of(widget)
  local text = table.concat(lines, "\n")
  local shortcut_line = find_line(lines, stl.icon.ui.CloudDownload)
  local shortcut_text = table.concat({
    stl.icon.ui.CloudDownload .. " I Install",
    stl.icon.ui.Lock .. " S Sync",
    stl.icon.ui.ArrowUp .. " U Update",
    stl.icon.ui.Trash .. " X Clean",
  }, "    ")
  local shortcut_padding = math.floor((132 - widget.padding * 2 - vim.fn.strdisplaywidth(shortcut_text)) / 2)

  t.assert_true(State.options.ui.title:find(stl.icon.ui.Plugin, 1, true) ~= nil, "title icon")
  t.assert_true(text:find(shortcut_text, 1, true) ~= nil, "actions")
  t.assert_eq(shortcut_padding, #(lines[shortcut_line]:match("^(%s*)") or ""), "action centering")
  t.assert_eq("", lines[shortcut_line + 1], "action spacing")
  t.assert_eq(shortcut_line + 2, find_line(lines, "Neovim 30.00ms"), "header order")
  t.assert_true(text:find("Neovim 30.00ms    Startup 22.00ms", 1, true) ~= nil, "startup profile")
  t.assert_true(text:find("Installing 0/2    Queued 1", 1, true) ~= nil, "operation progress")
  t.assert_true(find_line(lines, "Installing (1)") < find_line(lines, "missing.nvim"), "installing section")
  t.assert_true(find_line(lines, "Queued (1)") < find_line(lines, "idle.nvim"), "queued section")
  t.assert_true(text:find("Startup (2) 22.00ms", 1, true) ~= nil, "startup section load time")
  t.assert_true(text:find("Runtime Loaded (1) 5.00ms", 1, true) ~= nil, "runtime section load time")
  t.assert_true(text:find("Not Loaded (1)", 1, true) ~= nil, "not loaded section")
  t.assert_true(text:find("Not Loaded (1) 0.00ms", 1, true) == nil, "not loaded section has no load time")

  ---@diagnostic disable-next-line: invisible
  local startup_segments = widget._lines[find_line(lines, "Startup (2)")]
  local summary_time_hl = nil ---@type string|nil
  for _, segment in ipairs(startup_segments) do
    if segment.str == " 22.00ms" then
      summary_time_hl = segment.hl
      break
    end
  end
  t.assert_eq("m_pl_comment", summary_time_hl, "summary time highlight")

  t.assert_true(find_line(lines, "slow.nvim") < find_line(lines, "fast.nvim"), "startup order")
  t.assert_true(find_line(lines, "slow.nvim") + 1 == find_line(lines, "Updated"), "updated task nesting")
  t.assert_eq(find_line(lines, "missing.nvim"), find_line(lines, "Cloning..."), "install task row")
  local idle_line = find_line(lines, "idle.nvim")
  t.assert_true(lines[idle_line]:find("Queued", 1, true) ~= nil, "queued task row")
  t.assert_eq("missing.nvim", widget:get_plugin_at_line(find_line(lines, "receiving objects")), "nested line owner")
  t.assert_true(find_line(lines, "orphan.nvim") + 1 == find_line(lines, "Removed"), "clean task nesting")
  t.assert_true(text:find("╰─", 1, true) ~= nil, "rounded tree connector")
  t.assert_true(text:find("Already up to date", 1, true) == nil, "unchanged result hidden")
end)

t:test("cursor ownership follows a plugin across section moves", function()
  local restored = nil ---@type integer[]|nil
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_win_get_cursor", function()
    return { 3, 0 }
  end)
  t:patch_table(vim.api, "nvim_win_set_cursor", function(_, cursor)
    restored = cursor
  end)

  ---@diagnostic disable-next-line: missing-fields
  local widget = Widget.new({ win_opts = { width = 80 }, winnr = 7 } --[[@as era.m.plugin.View]])
  ---@diagnostic disable-next-line: invisible
  widget._line_to_plugin = { [3] = "target.nvim" }
  t.assert_eq("target.nvim", widget:__cursor_plugin__(), "cursor owner")

  ---@diagnostic disable-next-line: invisible
  widget._lines = { {}, {}, {}, {} }
  ---@diagnostic disable-next-line: invisible
  widget._line_to_plugin = { [2] = "other.nvim", [4] = "target.nvim" }
  widget:__restore_cursor__("target.nvim")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(4, restored[1], "restored line")
end)

t:test("normalized multiline task errors render successfully", function()
  ---@diagnostic disable-next-line: missing-fields
  local widget = Widget.new({ win_opts = { width = 80 } } --[[@as era.m.plugin.View]])
  widget:__render_task__({
    name = "clone-error.nvim",
    action = "sync",
    status = "error",
    message = "Clone failed: Cloning into 'plugin'...",
    output = { "fatal: Remote branch missing not found" },
    from_commit = nil,
    to_commit = nil,
  })
  widget:__trim__()

  local bufnr = vim.api.nvim_create_buf(false, true)
  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  local ok, err = pcall(widget.__render__, widget, bufnr)
  t.assert_true(ok, tostring(err))
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  t.assert_true(table.concat(lines, "\n"):find("Remote branch missing", 1, true) ~= nil, "rendered detail")
end)

t:run()
