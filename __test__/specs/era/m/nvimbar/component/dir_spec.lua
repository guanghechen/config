local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local clock_fixture = require("__test__.fixtures.era.m.nvimbar.clock")
local nvim_fn = require("stl.nvim.fn")
local yoz = require("yoz")
local t = harness.new("era.m.nvimbar.component.dir")

---@class __test__.nvimbar.dir.IScene
---@field public bar                    era.m.nvimbar.Nvimbar
---@field public clock                  __test__.fixtures.nvimbar.IClock
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public clicked                string[]
---@field public callbacks              table<string, fun(id: integer): nil>

---@return __test__.nvimbar.dir.IScene
local function scene()
  local clicked, callbacks = {}, {}
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_name(bufnr, "/project/old/file.lua")
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 0, col = 0, width = 80, height = 3 })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  bootstrap.with_runtime(t, {
    stl = {
      fn = { noop = function() end },
      env = { PATH_SEP = "/" },
      icon = { fillchars = { foldclose = ">" } },
      nvim = { fn = nvim_fn },
      reporter = {
        error = function(report)
          error(vim.inspect(report))
        end,
      },
    },
    dot = {
      path = {
        cwd = function()
          return "/project"
        end,
        resolve = function(cwd, path)
          return yoz.path.resolve(cwd, path, true, "/")
        end,
      },
      theme = {
        hlgroup = {
          common = {
            resolve_mode = function()
              return "n", "NORMAL"
            end,
          },
        },
      },
      G = {
        register_anonymous_fn = function(callback)
          callbacks.dir_click = callback
          t:patch_global("dir_click", callback)
          return "dir_click"
        end,
      },
      buf = {
        resolve = function(buf)
          return { relpath = yoz.path.relative("/project", vim.api.nvim_buf_get_name(buf), false, "/") }
        end,
      },
      tab = {
        retrieve_winnr_sourcefile = function()
          return winnr
        end,
      },
      command = {
        definitions = {
          find = {
            explorer = {
              execute = function(_, path)
                clicked[#clicked + 1] = path
              end,
            },
          },
        },
      },
    },
    yoz = yoz,
  })
  local clock = clock_fixture.new(t)
  local bar = clock.Nvimbar.new({
    name = "directory test",
    comp_sep = "",
    comp_sep_hlname = "Normal",
    comp_sep_hlname_active = "Normal",
    draw_interval = 200,
    get_preset_context = function()
      return { winnr = winnr }
    end,
    get_max_width = function()
      return 80
    end,
    is_active = function()
      return true
    end,
    on_fulfilled = function(result)
      vim.api.nvim_set_option_value("winbar", result, { win = winnr, scope = "local" })
    end,
  })
  t:defer(function()
    bar:dispose()
  end)
  bar:place({ position = "left", component = assert(loadfile("lua/era/m/nvimbar/component/dir.lua"))().path("f_wl") })
  bar:refresh()
  clock:advance(1)
  clock:advance(2)
  return { bar = bar, clock = clock, winnr = winnr, bufnr = bufnr, clicked = clicked, callbacks = callbacks }
end

---@param winnr                         integer
---@return string
local function option(winnr)
  return vim.api.nvim_get_option_value("winbar", { win = winnr, scope = "local" })
end

---@param current                       __test__.nvimbar.dir.IScene
---@param text                          string
---@return nil
local function click(current, text)
  local id, callback = text:match("%%(%d+)@v:lua%.([%w_]+)@")
  assert(id and callback, text)
  current.callbacks[callback](assert(tonumber(id)))
end

t:test("published buttons retain their path through newer data, direct render and garbage collection", function()
  local current = scene()
  local previous = option(current.winnr)
  vim.api.nvim_buf_set_name(current.bufnr, "/project/new/file.lua")
  current.bar:refresh()
  current.clock:advance(3)
  t.assert_true(current.bar:render():find("new", 1, true) ~= nil)
  collectgarbage("collect")
  t.assert_eq(previous, option(current.winnr))
  click(current, previous)
  t.assert_eq("/project/old", current.clicked[1])

  current.clock:advance(202)
  local latest = option(current.winnr)
  click(current, latest)
  t.assert_eq("/project/new", current.clicked[2])
  collectgarbage("collect")
  click(current, previous)
  t.assert_eq(2, #current.clicked, "expired targets are not retained by the callback registry")
  current.bar:dispose()
  collectgarbage("collect")
  click(current, latest)
  t.assert_eq(2, #current.clicked, "disposal releases current and displayed targets")
end)

t:test("unchanged directories reuse button identities across data snapshots", function()
  local current = scene()
  local previous = option(current.winnr)
  for time = 3, 20 do
    current.bar:refresh()
    current.clock:advance(time)
  end
  collectgarbage("collect")
  t.assert_eq(previous, current.bar:render())
  click(current, previous)
  t.assert_eq("/project/old", current.clicked[1])
  current.clock:advance(202)
  t.assert_eq(previous, option(current.winnr))
end)

t:test("forks sharing a raw definition keep independent button targets", function()
  local current = scene()
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_name(bufnr, "/project/peer/file.lua")
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 5, col = 0, width = 80, height = 3 })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  local fork = current.bar:fork(winnr)
  fork:refresh()
  current.clock:advance(3)
  current.clock:advance(4)
  collectgarbage("collect")
  click(current, option(current.winnr))
  click(current, option(winnr))
  t.assert_true(vim.deep_equal({ "/project/old", "/project/peer" }, current.clicked))
  fork:dispose()
  collectgarbage("collect")
  click(current, option(current.winnr))
  t.assert_eq("/project/old", current.clicked[3])
end)

t:run()
