---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/dot/win_winline.lua

local harness = require("__test__.harness")

local t = harness.new("dot.win_winline")
local enums = assert(loadfile("lua/stl/e.lua"))()

local function new_history()
  return {
    clear = function() end,
    fork = function()
      return new_history()
    end,
  }
end

local function new_nvimbar()
  return {
    disposed = false,
    renders = 0,
    dispose = function(self)
      self.disposed = true
    end,
    isdisposed = function(self)
      return self.disposed
    end,
    render = function(self)
      self.renders = self.renders + 1
    end,
  }
end

t:patch_global("stl", {
  c = { History = { new = new_history } },
  e = enums,
  nvim = { win = {
    is_float = function()
      return false
    end,
  } },
  reporter = { error = function() end },
})
t:patch_global("dot", {
  var = { WIN_BUF_HISTORY_CAPACITY = 10 },
})

t:test("window metadata forks render and release a target-owned nvimbar", function()
  local source_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("vsplit")
  local target_winnr = vim.api.nvim_get_current_win() ---@type integer
  local Win = assert(loadfile("lua/dot/win.lua"))()
  local source_meta = assert(Win.resolve(source_winnr, true))
  local source_nvimbar = new_nvimbar()
  local target_nvimbar = new_nvimbar()
  source_meta.winline = {
    bufnr = vim.api.nvim_win_get_buf(source_winnr),
    nvimbar = source_nvimbar,
    fork = function(winnr)
      local target_meta = assert(Win.resolve(winnr, true))
      target_meta.winline = {
        bufnr = vim.api.nvim_win_get_buf(winnr),
        nvimbar = target_nvimbar,
      }
      return target_nvimbar
    end,
  }

  Win.fork(source_winnr, target_winnr)
  t.assert_true(source_meta.winline.forks[target_winnr] == target_nvimbar, "source owns live fork")
  t.assert_eq(source_winnr, assert(Win.resolve(target_winnr, false)).winline.fork_source_winnr, "target owner")
  t.assert_eq(1, target_nvimbar.renders, "fork renders immediately")

  Win.render_winline(source_winnr)
  t.assert_eq(1, source_nvimbar.renders, "source render")
  t.assert_eq(2, target_nvimbar.renders, "source render reaches fork")

  Win.on_close(target_winnr)
  t.assert_nil(source_meta.winline.forks[target_winnr], "closed target detached")
  t.assert_true(target_nvimbar.disposed, "target nvimbar disposed")

  Win.on_close(source_winnr)
  vim.api.nvim_win_close(target_winnr, true)
end)

t:test("closing the source detaches but does not dispose a live target owner", function()
  local source_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("vsplit")
  local target_winnr = vim.api.nvim_get_current_win() ---@type integer
  local Win = assert(loadfile("lua/dot/win.lua"))()
  local source_meta = assert(Win.resolve(source_winnr, true))
  local source_nvimbar = new_nvimbar()
  local target_nvimbar = new_nvimbar()
  source_meta.winline = {
    bufnr = vim.api.nvim_win_get_buf(source_winnr),
    nvimbar = source_nvimbar,
    fork = function(winnr)
      local target_meta = assert(Win.resolve(winnr, true))
      target_meta.winline = {
        bufnr = vim.api.nvim_win_get_buf(winnr),
        nvimbar = target_nvimbar,
      }
      return target_nvimbar
    end,
  }

  Win.fork(source_winnr, target_winnr)
  Win.on_close(source_winnr)

  local target_winline = assert(assert(Win.resolve(target_winnr, false)).winline)
  t.assert_nil(target_winline.fork_source_winnr, "target no longer points to closed source")
  t.assert_false(target_nvimbar.disposed, "target-owned nvimbar remains live")
  Win.render_winline(target_winnr)
  t.assert_eq(2, target_nvimbar.renders, "detached target still renders")

  Win.on_close(target_winnr)
  t.assert_true(target_nvimbar.disposed, "target close disposes its nvimbar")
  vim.api.nvim_win_close(target_winnr, true)
end)

t:run()
