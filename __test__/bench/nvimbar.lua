---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.nvimbar" ---@type string

package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;" .. package.path
local t = require("__test__.support.harness").new("nvimbar benchmark")
local bootstrap = require("__test__.support.bootstrap")
local Nvimbar = require("era.m.nvimbar.nvimbar")
local Future = require("stl.c.future")

bootstrap.with_runtime(t, {
  stl = {
    fn = { noop = function() end },
    nvim = { fn = {
      txt = function(text)
        return text
      end,
    } },
    reporter = {
      error = function(details)
        error(vim.inspect(details))
      end,
    },
  },
  dot = {
    path = {
      cwd = function()
        return "/benchmark"
      end,
    },
    theme = { hlgroup = { common = {
      resolve_mode = function()
        return "n", "NORMAL"
      end,
    } } },
  },
  yoz = { path = {
    basename = function(path)
      return path:match("[^/]*$")
    end,
  } },
})

---@param values                        number[]
---@return number
local function median(values)
  table.sort(values)
  return values[math.ceil(#values / 2)]
end

---@param count                         integer
---@param staggered                     boolean
---@return nil
local function measure(count, staggered)
  local revision, fetched, layouts, publications = 0, 0, 0, 0
  local published, expected = "", ""
  local published_at, last_ready_at = 0, 0
  local started_cpu, started_wall = 0, 0
  local round, running, done = -1, false, false
  local next_round ---@type fun(): nil
  local start_results ---@type fun(): nil
  local jobs = {} ---@type table<integer, fun(value: any): nil>
  local samples = { cpu = {}, wall = {}, layouts = {}, publications = {}, lag = {} }
  local winnr = vim.api.nvim_get_current_win()
  local bar = Nvimbar.new({
    name = "benchmark",
    comp_sep = "",
    comp_sep_hlname = "Normal",
    comp_sep_hlname_active = "Normal",
    get_preset_context = function()
      return { winnr = winnr }
    end,
    get_max_width = function()
      layouts = layouts + 1
      return 1024
    end,
    is_active = function()
      return true
    end,
    on_fulfilled = function(text)
      publications = publications + 1
      published = text
      if text == expected then
        published_at = vim.uv.hrtime()
        if revision == 0 then
          vim.schedule(next_round)
        elseif running then
          assert(fetched == count, "publication unexpectedly reacquired component data")
          if round > 0 then
            samples.cpu[#samples.cpu + 1] = (os.clock() - started_cpu) * 1e3
            samples.wall[#samples.wall + 1] = (published_at - started_wall) / 1e6
            samples.layouts[#samples.layouts + 1] = layouts
            samples.publications[#samples.publications + 1] = publications
            samples.lag[#samples.lag + 1] = (published_at - last_ready_at) / 1e6
          end
          running = false
          vim.schedule(next_round)
        end
      end
    end,
  })
  local dispose = t:defer(function()
    bar:dispose()
  end)

  ---@param index integer
  ---@return era.m.nvimbar.ITextSnapshot
  local function data(index)
    local text = string.format("%d.%d ", revision, index)
    return { text = text, hltext = text }
  end

  ---@return string
  local function expected_value()
    local items = {}
    for index = 1, count do
      items[index] = data(index).text
    end
    return table.concat(items) .. "%="
  end

  for index = 1, count do
    bar:place({
      position = "left",
      component = {
        name = "item_" .. index,
        refresh = function(_, token)
          if revision == 0 then
            return data(index)
          end
          fetched = fetched + 1
          local future, resolve = Future.new_with_resolver({ token = token })
          jobs[index] = resolve
          if fetched == count then
            start_results()
          end
          return future
        end,
      },
    })
  end
  ---@return nil
  start_results = function()
    local index = 0
    local timer = assert(vim.uv.new_timer())
    local stop = t:defer(function()
      if not timer:is_closing() then
        timer:stop()
        timer:close()
      end
    end)
    local pending = false
    timer:start(1, staggered and 1 or 0, function()
      if pending then
        return
      end
      pending = true
      vim.schedule(function()
        pending = false
        if index == count then
          return
        end
        repeat
          index = index + 1
          if index == count then
            last_ready_at = vim.uv.hrtime()
          end
          jobs[index](data(index))
        until staggered or index == count
        if index == count then
          stop()
        end
      end)
    end)
  end

  ---@return nil
  next_round = function()
    if round == 7 then
      done = true
      return
    end
    round = round + 1
    revision = round + 1
    expected = expected_value()
    fetched, layouts, publications = 0, 0, 0
    published_at, last_ready_at = 0, 0
    jobs = {}
    collectgarbage("collect")
    started_cpu, started_wall = os.clock(), vim.uv.hrtime()
    running = true
    bar:refresh()
  end

  expected = expected_value()
  bar:refresh()
  -- Rounds advance from publication callbacks; this observer does not poll each result.
  assert(
    vim.wait(10000, function()
      return done
    end, 100),
    "latest data did not reach publication"
  )
  assert(published == expected)
  dispose()
  io.write(
    string.format(
      "%s,%d,%.3f,%.3f,%.0f,%.0f,%.3f\n",
      staggered and "staggered" or "batch",
      count,
      median(samples.cpu),
      median(samples.wall),
      median(samples.layouts),
      median(samples.publications),
      median(samples.lag)
    )
  )
end

io.write(
  "scenario,components,median_cpu_ms,median_wall_ms,median_layouts,median_publications,median_last_result_to_publication_ms\n"
)
t:test("completed snapshots always reach publication", function()
  for _, count in ipairs({ 8, 32, 64 }) do
    measure(count, false)
    measure(count, true)
  end
end)
local result = t:run({ exit = false, quiet = true })
assert(result.failed == 0, table.concat(result.failures, "\n"))
