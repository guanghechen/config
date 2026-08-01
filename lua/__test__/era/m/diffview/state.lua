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

t:run()
