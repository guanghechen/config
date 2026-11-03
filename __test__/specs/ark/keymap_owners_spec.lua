local harness = require("__test__.support.harness")

local t = harness.new()

local ROOT = assert(vim.uv.cwd()) ---@type string
local FIXTURE = ROOT .. "/__test__/fixtures/ark/keymap_owners.lua" ---@type string

-- Keys that more than one source maps while the full configuration starts, with the sources in order: the last one is
-- in effect, and "nvim" is Neovim's default mapping. A failure asks for a decision rather than a refreshed list: keep
-- the override and record it here, or resolve the conflict.
local OVERRIDES = {
  -- Neovim defaults the configuration replaces.
  ["i <C-S>"] = "nvim -> ark/vendor/neovim/keymap.lua",
  ["n [d"] = "nvim -> ark/vendor/neovim/keymap.lua",
  ["n ]d"] = "nvim -> ark/vendor/neovim/keymap.lua",
  ["n [q"] = "nvim -> ark/vendor/neovim/keymap.lua",
  ["n ]q"] = "nvim -> ark/vendor/neovim/keymap.lua",
  ["n [a"] = "nvim -> era/keystroke/textobject/keymap.lua",
  ["n ]a"] = "nvim -> era/keystroke/textobject/keymap.lua",
  ["n [A"] = "nvim -> era/keystroke/textobject/keymap.lua",
  ["n ]A"] = "nvim -> era/keystroke/textobject/keymap.lua",
  ["n [b"] = "nvim -> era/keystroke/textobject/keymap.lua",
  ["n ]b"] = "nvim -> era/keystroke/textobject/keymap.lua",
  -- ui_attach replaces the <Esc> of ark/keymap.lua in Normal and Insert mode; Visual mode keeps the latter.
  ["n <Esc>"] = "ark/keymap.lua -> era/dressing/ui_attach/init.lua",
  ["i <Esc>"] = "ark/keymap.lua -> era/dressing/ui_attach/init.lua",
  -- blink.pairs replaces the undo break-points that ark/keymap.lua maps on Enter and Space, and
  -- era/plugin/blink-pairs.lua puts them back in front of its maps.
  ["i <CR>"] = "ark/keymap.lua -> plugin:blink.pairs -> era/plugin/blink-pairs.lua",
  ["i <Space>"] = "ark/keymap.lua -> plugin:blink.pairs -> era/plugin/blink-pairs.lua",
} ---@type table<string, string>

-- Buffer-local maps of an edited file that hide a global map, as global source -> buffer source. Completion takes
-- these keys and falls back to the global map when its menu does not use them.
local SHADOWS = {
  ["i <CR>"] = "era/plugin/blink-pairs.lua -> era/keystroke/cmp/keymap.lua",
  ["i <C-B>"] = "plugin:blink.pairs -> era/keystroke/cmp/keymap.lua",
  ["i <Tab>"] = "nvim -> era/keystroke/cmp/keymap.lua",
  ["i <S-Tab>"] = "nvim -> era/keystroke/cmp/keymap.lua",
  ["s <Tab>"] = "nvim -> era/keystroke/cmp/keymap.lua",
  ["s <S-Tab>"] = "nvim -> era/keystroke/cmp/keymap.lua",
} ---@type table<string, string>

-- Mapped keys that start a longer mapping without nowait, with their source. Which-key then waits for the next key for
-- as long as it takes: right for an operator or a text object, which needs one, but a key meant to act on its own is
-- stuck until another key arrives, so it needs nowait instead.
local PREFIXES = {
  ["n gc"] = "nvim",
  ["x a"] = "era/keystroke/textobject/keymap.lua",
  ["x i"] = "era/keystroke/textobject/keymap.lua",
} ---@type table<string, string>

---@class __test__.specs.ark.keymap_owners.IReport
---@field public overrides              ?table<string, string>
---@field public shadows                ?table<string, string>
---@field public prefixes               ?table<string, string>
---@field public missing                ?string[]
---@field public error                  ?string

local report = nil ---@type __test__.specs.ark.keymap_owners.IReport|nil

---Starts the full configuration once, with this checkout as its config directory and state in a temporary one.
---@return __test__.specs.ark.keymap_owners.IReport
local function start()
  if report ~= nil then
    return report
  end
  local dir = t:tempdir()
  assert(vim.uv.fs_symlink(ROOT, vim.fs.joinpath(dir, vim.env.NVIM_APPNAME or "nvim"), { junction = true }))
  local out = vim.fs.joinpath(dir, "owners.json")
  local process = vim.system({
    vim.v.progpath,
    "--headless",
    "-i",
    "NONE",
    "-n",
    "--cmd",
    string.format("lua keymap_owners = dofile(%q) keymap_owners.install()", FIXTURE),
    FIXTURE,
    "-c",
    string.format("lua keymap_owners.run(%q)", out),
  }, {
    cwd = ROOT,
    text = true,
    env = { XDG_CONFIG_HOME = dir, XDG_STATE_HOME = dir .. "/state", XDG_CACHE_HOME = dir .. "/cache" },
  })
  t:defer(function()
    if not process:is_closing() then
      process:kill(15)
      process:wait(1000)
    end
  end)
  local result = process:wait(20000)
  t.assert_eq(0, result.code, "configuration exit status: " .. (result.stderr or ""))
  report = vim.json.decode(table.concat(vim.fn.readfile(out), "\n"))
  return report
end

---@param what                          string
---@param expected                      table<string, string>
---@param actual                        table<string, string>
---@return nil
local function assert_recorded(what, expected, actual)
  local keys = vim.tbl_keys(vim.tbl_extend("force", {}, expected, actual)) ---@type string[]
  table.sort(keys)
  local lines = {} ---@type string[]
  for _, key in ipairs(keys) do
    if expected[key] ~= actual[key] then
      lines[#lines + 1] = string.format("  %s: recorded %s, now %s", key, expected[key] or "-", actual[key] or "-")
    end
  end
  if #lines > 0 then
    error(what .. " changed:\n" .. table.concat(lines, "\n"), 0)
  end
end

---@param name                          "overrides"|"shadows"|"prefixes"
---@return table<string, string>
local function started(name)
  local data = start()
  if data.missing ~= nil then
    t.skip("plugins are not installed: " .. table.concat(data.missing, ", "))
  end
  assert(data.error == nil, data.error)
  return data[name] or {}
end

t:test("starting the full configuration overrides only the recorded keys", function()
  assert_recorded("keymap overrides", OVERRIDES, started("overrides"))
end)

t:test("an edited file hides only the recorded global keys with buffer-local maps", function()
  assert_recorded("buffer-local maps over global ones", SHADOWS, started("shadows"))
end)

t:test("only the recorded mapped keys wait for a longer mapping", function()
  assert_recorded("mapped keys waiting for a longer mapping", PREFIXES, started("prefixes"))
end)

t:run()
