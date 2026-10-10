---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.treeview.decorations" ---@type string

local t = require("__test__.support.harness").new("ux.treeview.decorations")
local bootstrap = require("__test__.support.bootstrap")
local suffix = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
bootstrap.with_yoz(t, assert(package.loadlib("rust/target/debug/libyoz." .. suffix, "luaopen_yoz"))())
bootstrap.with_stl(t, {
  c = { Future = require("stl.c.future") },
  nvim = { fn = require("stl.nvim.fn") },
  reporter = {
    error = function(value)
      error(value.message)
    end,
  },
})
local treeview = require("ux.treeview")
local decorations = require("ux.treeview.decorations")

---@param future                        stl.c.Future
---@return any
local function await(future)
  t.wait_until(function()
    return future:is_done()
  end, 5000)
  t.assert_false(future:is_failed(), future:get_error())
  local result = future:get_result()
  t.assert_false(result.kind == "Rejected", vim.inspect(result))
  return result
end

---@param count                         integer
---@param label_bytes                   ?integer
---@return ux.treeview.State
local function fixture(count, label_bytes)
  local data = treeview.new_data({ limits = { batch_bytes = 4 * 1024 * 1024 } })
  local records = { { key = "root", label = "root", can_expand = true } }
  for index = 1, count do
    records[#records + 1] = {
      key = "n" .. index,
      parent = index == 1 and "root" or "n" .. math.floor((index - 2) / 4 + 1),
      label = string.format("node-%03d", index) .. string.rep("x", label_bytes or 0),
      can_expand = index * 4 - 2 <= count,
    }
  end
  await(data:import(records))
  local state = await(data:create_state({ kind = "children_of", node = data:source():id("root") }))
  local reply = await(state:set_expanded({ data:source():id("root") }, true, true))
  t.wait_until(function()
    return state._native:applicable(state:snapshot(), reply.revisions.commit)
  end, 5000)
  return state
end

---@param frame                         yoz.ux.treeview.Frame
---@return yoz.ux.treeview.Frame, integer[][]
local function observed(frame)
  local reads = {}
  local proxy = {
    id = function()
      return frame:id()
    end,
    header = function()
      return frame:header()
    end,
    rows = function(_, first, last)
      reads[#reads + 1] = { first, last }
      return frame:rows(first, last)
    end,
  }
  ---@cast proxy yoz.ux.treeview.Frame
  return proxy, reads
end

---@param frame                         yoz.ux.treeview.Frame
---@param cache                         table
---@return nil
local function exact_rows(frame, cache)
  local expected = frame:rows(cache.first + 1, cache.last)
  for name, column in pairs(expected) do
    if name == "folded_ids" then
      for index, ids in ipairs(column) do
        local actual = cache.rows.folded_ids[index]
        t.assert_eq(ids:len(), actual:len())
        for at = 1, ids:len() do
          t.assert_eq(ids:get(at), actual:get(at))
        end
      end
    else
      t.assert_true(vim.deep_equal(column, cache.rows[name]), "exact viewport column " .. name)
    end
  end
end

t:test("small scrolls reuse native rows while consumers retain the exact viewport", function()
  local frame = fixture(300):snapshot()
  local proxy, reads = observed(frame)
  local original = decorations.prepare(proxy, 0, 48)
  local cache = original
  for first = 1, 8 do
    cache = decorations.prepare(proxy, first, first + 48, cache)
    t.assert_eq(first, cache.first)
    t.assert_eq(first + 48, cache.last)
    t.assert_eq(48, #cache.rows.ids)
    exact_rows(frame, cache)
  end
  t.assert_eq(2, #reads, "one bounded lookahead serves consecutive viewport shifts")
  cache = decorations.prepare(proxy, 0, 48, cache)
  t.assert_eq(2, #reads, "reversing within the cached margin does not export rows again")
  exact_rows(frame, cache)
  exact_rows(frame, original)
  t.assert_eq(0, original.first, "the earlier publication remains immutable")

  cache = decorations.prepare(proxy, 200, 248, cache)
  t.assert_true(vim.deep_equal({ 201, 248 }, reads[#reads]), "cold jumps read only the requested rows")
  exact_rows(frame, cache)
end)

t:test("row batches cannot survive a frame change without the same_rows publication proof", function()
  local state = fixture(100)
  local frame = state:snapshot()
  local cache = decorations.prepare(frame, 0, 32)
  cache = decorations.prepare(frame, 1, 33, cache)
  local reply = await(state:select_node({ frame:node_at(10) }, false))
  t.wait_until(function()
    return state._native:applicable(state:snapshot(), reply.revisions.commit)
  end, 5000)
  local current = state:snapshot()
  t.assert_eq(frame:header().layout_revision, current:header().layout_revision)
  local proxy, reads = observed(current)
  local updated = decorations.prepare(proxy, 2, 34, cache)
  t.assert_eq(1, #reads)
  t.assert_true(updated.rows.marked[8], "selection metadata comes from the new frame")
  t.assert_false(cache.rows.marked[9], "the retained batch stays unchanged")
  exact_rows(current, updated)
end)

t:test("lookahead stays within row limits and falls back when the payload budget is exceeded", function()
  local frame = fixture(600):snapshot()
  local proxy, reads = observed(frame)
  local cache = decorations.prepare(proxy, 0, 505)
  cache = decorations.prepare(proxy, 1, 506, cache)
  for _, range in ipairs(reads) do
    t.assert_true(range[2] - range[1] + 1 <= 512, "overscan preserves the native row limit")
  end
  exact_rows(frame, cache)

  frame = fixture(80, 24000):snapshot()
  proxy, reads = observed(frame)
  cache = decorations.prepare(proxy, 16, 48)
  cache = decorations.prepare(proxy, 17, 49, cache)
  t.assert_eq(3, #reads, "an oversized prefetch retries the exact viewport")
  t.assert_true(vim.deep_equal({ 18, 49 }, reads[3]))
  t.assert_eq(17, cache.batch.first)
  t.assert_eq(49, cache.batch.last)
  exact_rows(frame, cache)
  cache = decorations.prepare(proxy, 18, 50, cache)
  t.assert_eq(4, #reads, "nearby scrolls do not repeat a rejected overscan query")
  exact_rows(frame, cache)
  t.assert_false(pcall(decorations.prepare, proxy, 0, 48, cache), "an oversized actual viewport still fails")
end)

t:run()
