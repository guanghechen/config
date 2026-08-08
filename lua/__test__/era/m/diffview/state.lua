---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/state.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.state")

local Observable = {}
Observable.__index = Observable

---@param value                          any
---@return table
function Observable.from_value(value)
  return setmetatable({ value = value, disposed = false }, Observable)
end

---@return any
function Observable:snapshot()
  return self.value
end

---@param value                          any
---@return nil
function Observable:next(value)
  self.value = value
end

---@return nil
function Observable:dispose()
  self.disposed = true
end

---@param path                           string
---@param field                          string
local function verify_invalid_handle_cleanup(path, field)
  local valid = true
  local callback
  local deleted_autocmd

  t:patch_global("stl", { c = { Observable = Observable } })
  t:patch_table(package.loaded, "era.m.diffview.config", { COMMITS_PER_PAGE = 100 })
  t:patch_table(vim.api, "nvim_create_autocmd", function(_, opts)
    callback = opts.callback
    return 77
  end)
  t:patch_table(vim.api, "nvim_del_autocmd", function(autocmd_id)
    deleted_autocmd = autocmd_id
  end)
  t:patch_table(vim.api, "nvim_tabpage_is_valid", function()
    return valid
  end)

  local State = assert(loadfile(path))()
  local state = State.create(101)

  callback({ file = "1" })
  local retained_while_valid = State.get(101) == state

  valid = false
  callback({ file = "1" })

  t.assert_true(retained_while_valid, "state retained for valid handle")
  t.assert_nil(State.get(101), "state removed for invalid handle")
  t.assert_true(state[field].disposed, "state observables disposed")
  t.assert_eq(77, deleted_autocmd, "TabClosed autocmd deletion")
end

t:test("workspace state cleanup follows tabpage handle validity", function()
  verify_invalid_handle_cleanup("lua/era/m/diffview/view/workspace/state.lua", "entries")
end)

t:test("commits state cleanup follows tabpage handle validity", function()
  verify_invalid_handle_cleanup("lua/era/m/diffview/view/commits/state.lua", "commits")
end)

t:test("workspace state disposes its refresh owner after unsubscribing", function()
  local disposed = {} ---@type string[]
  t:patch_global("stl", { c = { Observable = Observable } })
  local State = assert(loadfile("lua/era/m/diffview/view/workspace/state.lua"))()
  local uninitialized = State.State.new(100)
  t.assert_false(pcall(uninitialized.request_refresh, uninitialized), "uninitialized refresh still rejected")
  uninitialized:dispose()

  local state = State.State.new(101)

  state:set_refresh({
    dispose = function()
      disposed[#disposed + 1] = "refresh"
    end,
  })
  state:set_git_subscription({
    unsubscribe = function()
      disposed[#disposed + 1] = "subscription"
    end,
  })
  state:dispose()

  t.assert_eq("subscription", disposed[1], "subscription disposed first")
  t.assert_eq("refresh", disposed[2], "refresh owner disposed second")
  t.assert_true(state:is_disposed(), "state marked disposed")

  local ok_request = pcall(state.request_refresh, state)
  local ok_check = pcall(state.request_refresh_if_stale, state)
  t.assert_true(ok_request, "late local refresh is ignored")
  t.assert_true(ok_check, "late watcher refresh is ignored")
end)

t:run()
