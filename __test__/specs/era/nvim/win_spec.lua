local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()
local enums = require("stl.e")

bootstrap.with_runtime(t, {
  dot = {},
  stl = {
    e = enums,
    env = { IS_TMUX = false },
    reporter = { error = function() end },
  },
})

t:test("Workspace left navigation delegates to Diffview only when handled", function()
  local directions = {} ---@type string[]
  t:patch_table(package.loaded, "era.m.diffview.fn", {
    navigate_window = function(direction)
      directions[#directions + 1] = direction
      return true
    end,
  })

  local win = assert(loadfile("lua/era/nvim/win.lua"))()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.t[tabnr].tabtype = enums.TabTypeEnum.DIFFVIEW_WORKSPACE
  win.focus_left()
  win.focus_right()
  t.assert_eq("h", table.concat(directions, ","), "Diffview delegation")

  vim.t[tabnr].tabtype = enums.TabTypeEnum.NORMAL
  win.focus_left()
  t.assert_eq("h", table.concat(directions, ","), "normal navigation bypass")
end)

---A window like the Explorer's or a terminal's: a buffer of its own, options of its own.
---@param bufopts                       table<string, any>
---@param winopts                       table<string, any>
---@return integer, integer
local function panel(bufopts, winopts)
  vim.cmd("silent only")
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_set_current_buf(bufnr)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  for name, value in pairs(bufopts) do
    vim.api.nvim_set_option_value(name, value, { buf = bufnr })
  end
  for name, value in pairs(winopts) do
    vim.api.nvim_set_option_value(name, value, { win = winnr, scope = "local" })
  end
  t:defer(function()
    vim.cmd("silent only")
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return winnr, bufnr
end

---@return table
local function split_module()
  bootstrap.with_global(t, "stl", {
    nvim = {
      win = {
        is_float = function(winnr)
          return vim.api.nvim_win_get_config(winnr).relative ~= ""
        end,
      },
    },
  })
  bootstrap.with_global(t, "dot", {
    win = {
      is_sourcefile = function()
        return false
      end,
      fork = function() end,
    },
  })
  return assert(loadfile("lua/era/nvim/win.lua"))()
end

t:test("splitting a window whose buffer is wiped once hidden keeps that window", function()
  local win = split_module()
  local winnr, bufnr = panel({ bufhidden = "wipe" }, { winbar = "EXPLORER", winhighlight = "Normal:Comment" })

  win.split("l")

  local target = vim.api.nvim_get_current_win() ---@type integer
  t.assert_true(target ~= winnr, "focus moves to the new window")
  t.assert_eq(bufnr, vim.api.nvim_win_get_buf(winnr), "the window keeps its buffer")
  t.assert_true(vim.api.nvim_win_get_buf(target) ~= bufnr, "the new window shows a scratch buffer")
  t.assert_eq(
    "",
    vim.api.nvim_get_option_value("winbar", { win = target }),
    "no winbar of the window it was split from"
  )
  t.assert_eq("", vim.api.nvim_get_option_value("winhighlight", { win = target }), "no highlights of that window")
  t.assert_true(vim.api.nvim_get_option_value("number", { win = target }), "line numbers")
end)

t:test("splitting a winfixbuf window keeps that window and its buffer", function()
  local win = split_module()
  local winnr, bufnr = panel({}, { winfixbuf = true })

  win.split("j")

  local target = vim.api.nvim_get_current_win() ---@type integer
  t.assert_true(target ~= winnr, "focus moves to the new window")
  t.assert_eq(bufnr, vim.api.nvim_win_get_buf(winnr), "the window keeps its buffer")
  t.assert_true(vim.api.nvim_get_option_value("winfixbuf", { win = winnr }), "the window keeps winfixbuf")
  t.assert_false(vim.api.nvim_get_option_value("winfixbuf", { win = target }), "the new window takes any buffer")
end)

t:test("a split from a panel opens on the side its direction names", function()
  local win = split_module()
  for direction, expect in pairs({ h = "left", l = "right", k = "above", j = "below" }) do
    local winnr = panel({}, {})
    win.split(direction)
    local target = vim.api.nvim_get_current_win() ---@type integer
    local from, to = vim.fn.win_screenpos(winnr), vim.fn.win_screenpos(target)
    local side = to[2] < from[2] and "left" or to[2] > from[2] and "right" or to[1] < from[1] and "above" or "below"
    t.assert_eq(expect, side, "split " .. direction)
  end
end)

t:run()
