---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/plugin/widget.lua

local harness = require("__test__.harness")
require("ark.bootstrap").setup()

local State = require("era.m.plugin.state")
local Widget = require("era.m.plugin.widget")
local t = harness.new("era.m.plugin.widget")

---@param widget                        era.m.plugin.Widget
---@return string[]
local function lines_of(widget)
  local lines = {} ---@type string[]
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
    missing = {
      spec = { name = "missing.nvim" },
      loaded = false,
      loading = false,
      startup = false,
      path = "/plugins/missing.nvim",
    },
  } ---@type table<string, era.m.plugin.IPluginState>
  local tasks = {
    ["slow.nvim"] = {
      name = "slow.nvim",
      status = "done",
      message = "Updated",
      from_commit = "aaaaaaa",
      to_commit = "bbbbbbb",
    },
    ["runtime.nvim"] = {
      name = "runtime.nvim",
      status = "done",
      message = "Already up to date",
      from_commit = "ccccccc",
      to_commit = "ccccccc",
    },
    ["missing.nvim"] = {
      name = "missing.nvim",
      status = "running",
      step = "cloning",
      message = "Cloning...",
      output = { "receiving objects" },
      from_commit = nil,
      to_commit = nil,
    },
    ["orphan.nvim"] = {
      name = "orphan.nvim",
      status = "done",
      message = "Removed",
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

  local widget = Widget.new({ win_opts = { width = 132 } } --[[@as era.m.plugin.View]])
  widget:__build_required_by__()
  widget:__header__()
  widget:__home__()
  local lines = lines_of(widget)
  local text = table.concat(lines, "\n")
  local shortcut_line = find_line(lines, stl.icon.ui.CloudDownload)
  local shortcut_text = table.concat({
    stl.icon.ui.CloudDownload .. " I Install",
    stl.icon.ui.ArrowUp .. " U Update",
    stl.icon.ui.Trash .. " X Clean",
  }, "      ")
  local shortcut_padding = math.floor((132 - widget.padding * 2 - vim.fn.strdisplaywidth(shortcut_text)) / 2)

  t.assert_true(State.options.ui.title:find(stl.icon.ui.Plugin, 1, true) ~= nil, "title icon")
  t.assert_true(text:find(shortcut_text, 1, true) ~= nil, "actions")
  t.assert_eq(shortcut_padding, #(lines[shortcut_line]:match("^(%s*)") or ""), "action centering")
  t.assert_eq("", lines[shortcut_line + 1], "action spacing")
  t.assert_eq(shortcut_line + 2, find_line(lines, "Neovim 30.00ms"), "header order")
  t.assert_true(text:find("Neovim 30.00ms    Startup 22.00ms", 1, true) ~= nil, "startup profile")
  t.assert_true(find_line(lines, "slow.nvim") < find_line(lines, "fast.nvim"), "startup order")
  t.assert_true(find_line(lines, "slow.nvim") + 1 == find_line(lines, "Updated"), "updated task nesting")
  t.assert_true(find_line(lines, "missing.nvim") + 1 == find_line(lines, "Cloning..."), "install task nesting")
  t.assert_eq("missing.nvim", widget:get_plugin_at_line(find_line(lines, "receiving objects")), "nested line owner")
  t.assert_true(find_line(lines, "orphan.nvim") + 1 == find_line(lines, "Removed"), "clean task nesting")
  t.assert_true(text:find("Already up to date", 1, true) == nil, "unchanged result hidden")
end)

t:run()
