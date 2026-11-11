local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

local created = nil ---@type era.m.term.ICreateParams|nil
local focused = false ---@type boolean
local toggled = nil ---@type era.m.term.IToggleAndFocusParams|nil

bootstrap.with_runtime(t, {
  dot = {
    path = {
      cwd = function()
        return "/repo"
      end,
      dirname = function(filepath)
        return filepath .. "/parent"
      end,
      locate_cache_filepath = function()
        return "/cache/yazi chooser.txt"
      end,
    },
  },
  era = {
    m = {
      term = {
        state = {
          create = function(params)
            created = params
            return params
          end,
        },
        widget = {
          focus = function()
            focused = true
          end,
          toggle_and_focus = function(_, params)
            toggled = params
          end,
        },
      },
    },
  },
  yoz = {
    fn = {
      uuid = function()
        return "terminal-uuid"
      end,
    },
  },
})

local action = require("era.m.term.action")

local function reset()
  created = nil
  focused = false
  toggled = nil
end

-- Each action launches its program directly, as argv entries: the shell is created and focused, the others toggle.
for _, case in ipairs({
  {
    name = "create: launches the shell directly",
    action = "create",
    creates = true,
    argv = { { vim.o.shell, "shell executable" } },
  },
  {
    name = "lazygit_cwd: launches lazygit directly",
    action = "lazygit_cwd",
    cwd = "/repo",
    argv = { { "lazygit", "executable" } },
  },
  {
    name = "lazygit_file_history: preserves the filepath as one argument",
    action = "lazygit_file_history",
    filepath = "/repo/file with spaces.lua",
    argv = {
      { "lazygit", "executable" },
      { "-f", "file-history flag" },
      { "/repo/file with spaces.lua", "filepath" },
    },
  },
  {
    name = "yazi_cwd: preserves paths as argv entries",
    action = "yazi_cwd",
    argv = {
      { "yazi", "executable" },
      { "/repo/parent", "directory argument" },
      { "--chooser-file=/cache/yazi chooser.txt", "chooser argument" },
    },
  },
}) do
  t:test(case.name, function()
    reset()
    if case.filepath ~= nil then
      t:patch_table(vim.api, "nvim_get_current_buf", function()
        return 7
      end)
      t:patch_table(vim.api, "nvim_buf_get_name", function()
        return case.filepath
      end)
    end

    action[case.action]()

    local params ---@type era.m.term.ICreateParams|era.m.term.IToggleAndFocusParams
    if case.creates then
      t.assert_true(focused, "widget should focus")
      t.assert_true(created ~= nil, "terminal should be created")
      params = assert(created)
    else
      t.assert_true(toggled ~= nil, "terminal should toggle")
      params = assert(toggled)
    end
    if case.cwd ~= nil then
      t.assert_eq(case.cwd, params.cwd, "cwd")
    end
    t.assert_eq("table", type(params.cmd), "command type")
    local cmd = assert(params.cmd)
    for index, argument in ipairs(case.argv) do
      t.assert_eq(argument[1], cmd[index], argument[2])
    end
    t.assert_eq(#case.argv, #cmd, "argument count")
  end)
end

t:run()
