local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local Nvimbar = require("era.m.nvimbar.nvimbar")
local Future = require("stl.c.future")
local t = harness.new("era.m.nvimbar.nvimbar")

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
        error(details.message or vim.inspect(details))
      end,
    },
  },
  dot = {
    path = {
      cwd = function()
        return "/test"
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

local function window()
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 1, col = 1, width = 30, height = 3 })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  return winnr, bufnr
end

---@param winnr                         integer
---@param publish                       ?fun(result: string): nil
---@param width                         ?fun(): integer
---@param draw_interval                 ?integer
---@return era.m.nvimbar.Nvimbar
local function create(winnr, publish, width, draw_interval)
  local bar = Nvimbar.new({
    name = "test",
    comp_sep = "",
    comp_sep_hlname = "Normal",
    comp_sep_hlname_active = "Normal",
    get_preset_context = function()
      return { winnr = winnr }
    end,
    get_max_width = width or function()
      return 20
    end,
    is_active = function()
      return true
    end,
    on_fulfilled = publish or function() end,
    draw_interval = draw_interval,
  })
  t:defer(function()
    bar:dispose()
  end)
  return bar
end

t:test("snapshot reads the published cache without recomputing layout", function()
  local winnr = window()
  local width, layouts = 20, 0
  local published = ""
  local bar = create(winnr, function(text)
    published = text
  end, function()
    return width
  end)
  bar:place({
    position = "left",
    component = {
      name = "cached",
      refresh = function()
        return "abcdefghij"
      end,
      render = function(data, _, remain_width)
        layouts = layouts + 1
        local text = data:sub(1, remain_width)
        return text, text
      end,
    },
  })
  bar:refresh()
  t.wait_until(function()
    return published:find("abcdefghij", 1, true) ~= nil
  end, 1000)
  local cached, previous_layouts = published, layouts
  width = 5
  t.assert_eq(cached, bar:snapshot())
  t.assert_eq(previous_layouts, layouts, "snapshot does not lay out cached data")
  t.assert_true(bar:render() ~= cached, "render uses the current geometry")
  t.assert_eq(cached, bar:snapshot(), "render does not publish its result")
  bar:refresh()
  t.wait_until(function()
    return published ~= cached
  end, 1000)
  t.assert_eq(published, bar:snapshot())
end)

t:test("invalid positions report an error without adding a component", function()
  local winnr = window()
  local reports = {}
  t:patch_table(stl.reporter, "error", function(report)
    reports[#reports + 1] = report
  end)
  local bar = create(winnr)
  local result = bar:place({
    position = "invalid",
    component = { name = "invalid placement", refresh = function() end },
  })
  t.assert_eq(bar, result)
  t.assert_eq(0, #bar._components)
  t.assert_eq(1, #reports)
  t.assert_eq("place", reports[1].subject)
  t.assert_eq("invalid", reports[1].details.position)
end)

t:test("disposed public calls fail while pending callbacks drain safely", function()
  local winnr = window()
  local constructions, publications = 0, 0
  local bar = create(winnr, function()
    publications = publications + 1
  end)
  local placement = {
    position = "left",
    component = function()
      constructions = constructions + 1
      return { name = "queued", refresh = function() end }
    end,
  }
  bar:place(placement)
  local runtime = bar._components[1].runtime
  local errmsg = vim.v.errmsg
  t:defer(function()
    vim.v.errmsg = errmsg
  end)
  bar:refresh()
  bar:dispose()
  for _, call in ipairs({
    { "render" },
    { "snapshot" },
    { "cancel_refresh" },
    { "refresh" },
    { "place", placement },
    { "fork", winnr },
  }) do
    local ok, err = pcall(bar[call[1]], bar, call[2])
    t.assert_false(ok, call[1] .. " rejects a disposed bar")
    t.assert_true(tostring(err):find("already been disposed", 1, true) ~= nil, tostring(err))
  end
  bar:dispose()
  t.wait_until(function()
    return not runtime._queued and not bar._publish_scheduled
  end, 1000)
  t.assert_eq(0, constructions)
  t.assert_eq(0, publications)
  t.assert_eq(errmsg, vim.v.errmsg, "pending publication does not raise an editor error")
end)

t:test("placement objects preserve default priority without mutating the declaration", function()
  local winnr = window()
  local refreshes = 0
  local bar = create(winnr, nil, function()
    return 3
  end)
  local function source(text)
    return {
      name = text,
      refresh = function()
        refreshes = refreshes + 1
        return { text = text, hltext = text }
      end,
    }
  end
  local placement = { position = "left", component = source("DEF") }
  bar:place({ position = "left", priority = 0, component = source("LOW") })
  t.assert_true(bar:place(placement) == bar, "placement supports chaining")
  t.assert_nil(placement.priority, "default priority does not modify the caller's object")
  bar:refresh()
  t.wait_until(function()
    return refreshes == 2
  end, 1000)
  t.assert_true(bar:render():find("DEF", 1, true) ~= nil, "default priority is above zero")
  t.assert_false(bar:render():find("LOW", 1, true) ~= nil, "zero priority remains explicit")
end)

t:test("partial snapshots publish before a slow peer finishes", function()
  local winnr = window()
  local published, refreshes = {}, 0
  local resolve_slow
  local bar = create(winnr, function(text)
    published[#published + 1] = text
  end)
  bar:place({
    position = "left",
    component = function()
      return {
        name = "fast",
        refresh = function()
          refreshes = refreshes + 1
          return { text = "FAST", hltext = "FAST" }
        end,
      }
    end,
  })
  bar:place({
    position = "right",
    component = {
      name = "slow",
      refresh = function(_, token)
        local future
        future, resolve_slow = Future.new_with_resolver({ token = token })
        return future
      end,
    },
  })
  bar:refresh()
  t.assert_eq(0, refreshes, "refresh never runs inline")
  t.wait_until(function()
    return bar:render():find("FAST", 1, true) and resolve_slow ~= nil
  end, 1000)
  t.assert_false(bar:render():find("SLOW", 1, true) ~= nil)
  t.assert_true(#published > 0)
  resolve_slow({ text = "SLOW", hltext = "SLOW" })
  t.wait_until(function()
    return bar:render():find("SLOW", 1, true) ~= nil
  end, 1000)
  for _ = 1, 10 do
    bar:render()
  end
  t.assert_eq(1, refreshes, "composition does not request refreshes")
end)

t:test("unchanged completions do not republish while explicit refresh restores the target", function()
  local winnr = window()
  local applied, publications, slow_started = "", 0, false
  local future, resolve = Future.new_with_resolver()
  local bar = create(winnr, function(text)
    applied = text
    publications = publications + 1
  end)
  bar:place({
    position = "left",
    component = {
      name = "visible",
      will_change = function()
        return false
      end,
      refresh = function()
        return { text = "VISIBLE", hltext = "VISIBLE" }
      end,
    },
  })
  bar:place({
    position = "right",
    component = {
      name = "empty",
      refresh = function()
        slow_started = true
        return future
      end,
    },
  })
  bar:refresh()
  t.wait_until(function()
    return slow_started and applied:find("VISIBLE", 1, true) ~= nil
  end, 1000)
  local previous = publications
  resolve(nil)
  t.wait_until(function()
    return not bar._publish_scheduled
  end, 1000)
  t.assert_eq(previous, publications, "unchanged result")
  applied = "another bar owns the target"
  bar:refresh()
  t.wait_until(function()
    return applied:find("VISIBLE", 1, true) ~= nil
  end, 1000)
end)

t:test("late high-priority data reallocates width from cached low-priority data", function()
  local winnr = window()
  local resolve_high, refreshes = nil, 0
  local bar = create(winnr)
  bar:place({
    position = "left",
    priority = 1,
    component = {
      name = "low",
      refresh = function()
        refreshes = refreshes + 1
        return "abcdefghij"
      end,
      render = function(data, _, width)
        local text = data:sub(1, math.max(width, 0))
        return text, text
      end,
    },
  })
  bar:place({
    position = "right",
    priority = 100,
    component = {
      name = "high",
      refresh = function(_, token)
        local future
        future, resolve_high = Future.new_with_resolver({ token = token })
        return future
      end,
    },
  })
  bar:refresh()
  t.wait_until(function()
    return bar:render():find("abcdefghij", 1, true) ~= nil
  end, 1000)
  resolve_high({ text = "123456789012345", hltext = "123456789012345" })
  t.wait_until(function()
    return bar:render():find("123456789012345", 1, true) ~= nil
  end, 1000)
  t.assert_eq("abcde%=123456789012345", bar:render())
  t.assert_eq(1, refreshes, "width changes use the existing data snapshot")
end)

t:test("a buffer switch cannot publish the previous buffer's pending result", function()
  local winnr, first_bufnr = window()
  local second_bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(second_bufnr) then
      vim.api.nvim_buf_delete(second_bufnr, { force = true })
    end
  end)
  local jobs = {}
  local published = {}
  local bar = create(winnr, function(text)
    published[#published + 1] = text
  end)
  bar:place({
    position = "left",
    component = {
      name = "scope",
      refresh = function(context, token)
        local future, resolve = Future.new_with_resolver({ token = token })
        jobs[#jobs + 1] = { bufnr = context.bufnr, resolve = resolve }
        return future
      end,
    },
  })
  bar:refresh()
  t.wait_until(function()
    return #jobs == 1
  end, 1000)
  vim.api.nvim_win_set_buf(winnr, second_bufnr)
  bar:refresh()
  jobs[1].resolve({ text = "OLD", hltext = "OLD" })
  t.wait_until(function()
    return #jobs == 2
  end, 1000)
  t.assert_eq(first_bufnr, jobs[1].bufnr)
  t.assert_eq(second_bufnr, jobs[2].bufnr)
  jobs[2].resolve({ text = "NEW", hltext = "NEW" })
  t.wait_until(function()
    return bar:render():find("NEW", 1, true) ~= nil
  end, 1000)
  for _, text in ipairs(published) do
    t.assert_false(text:find("OLD", 1, true) ~= nil)
  end
end)

t:test("a startup rename replaces queued contexts without waiting for another dirty event", function()
  local winnr, bufnr = window()
  local bar = create(winnr)
  local refreshed = 0
  bar:place({
    position = "left",
    component = {
      name = "startup rename",
      refresh = function(context)
        refreshed = refreshed + 1
        return { text = context.filename, hltext = context.filename }
      end,
    },
  })
  bar:refresh()
  vim.api.nvim_buf_set_name(bufnr, "nvimbar-renamed.txt")
  t.wait_until(function()
    return bar:render():find("nvimbar-renamed.txt", 1, true) ~= nil
  end, 1000, "renamed buffer gets a fresh request")
  t.assert_eq(1, refreshed, "the stale queued context never reaches the provider")
end)

t:test("window forks keep independent targets and close with their windows", function()
  local source_winnr = window()
  local target_winnr, target_bufnr = window()
  local bar = create(source_winnr)
  bar:place({
    position = "left",
    component = function()
      return {
        name = "window",
        refresh = function(context)
          local text = tostring(context.bufnr)
          return { text = text, hltext = text }
        end,
      }
    end,
  })
  local fork = bar:fork(target_winnr)
  bar:refresh()
  t.wait_until(function()
    return vim.api.nvim_get_option_value("winbar", { win = target_winnr }):find(tostring(target_bufnr), 1, true) ~= nil
  end, 1000)
  t.assert_eq(fork, bar:fork(target_winnr), "reuses the owned window instance")
  vim.api.nvim_win_close(target_winnr, true)
  t.assert_true(fork:isdisposed())
  t.assert_nil(fork._components, "window close releases component runtimes")
  t.assert_false(bar:isdisposed())
end)

t:test("disposing the owner cancels its window forks", function()
  local source_winnr = window()
  local target_winnr = window()
  local bar = create(source_winnr)
  local fork = bar:fork(target_winnr)
  bar:dispose()
  t.assert_true(fork:isdisposed())
  t.assert_false(pcall(fork.render, fork), "disposed forks reject public calls")
end)

t:test("bar cancellation preserves refreshes requested by component cleanup", function()
  local winnr = window()
  local bar = create(winnr)
  local refreshed = { 0, 0 }
  local revision = "old"
  for index = 1, 2 do
    bar:place({
      position = "left",
      component = {
        name = "reentrant " .. index,
        refresh = function(_, token)
          refreshed[index] = refreshed[index] + 1
          if revision == "old" then
            if index == 1 then
              token:on_cancel(function()
                revision = "new"
                bar:refresh(true)
              end)
            end
            return Future.new(function() end)
          end
          return { text = "new" .. index, hltext = "new" .. index }
        end,
      },
    })
  end
  bar:refresh()
  t.wait_until(function()
    return refreshed[1] == 1 and refreshed[2] == 1
  end, 1000)
  bar:cancel_refresh()
  t.wait_until(function()
    return bar:snapshot():find("new1new2", 1, true) ~= nil
  end, 1000)
  t.assert_true(vim.deep_equal({ 2, 2 }, refreshed))
end)

t:test("the debug counter advances when a late peer causes another layout", function()
  t:patch_table(dot, "context", { flight = { devmode = {
    snapshot = function()
      return true
    end,
  } } })
  t:patch_table(stl, "icon", { symbols = { sep_left = "", sep_right = "" } })
  t:patch_table(stl, "string", {
    pad_start = function(text, width, pad)
      return string.rep(pad, math.max(0, width - #text)) .. text
    end,
  })
  local winnr = window()
  local bar = create(winnr, nil, function()
    return 100
  end, 0)
  local resolve
  bar:place({
    position = "center",
    component = assert(loadfile("lua/era/m/nvimbar/component/devmode.lua"))().render_count("f_wl"),
  })
  bar:place({
    position = "left",
    component = {
      name = "late peer",
      refresh = function()
        local future
        future, resolve = Future.new_with_resolver()
        return future
      end,
    },
  })
  bar:refresh()
  t.wait_until(function()
    return resolve ~= nil and bar:snapshot():find("00001", 1, true) ~= nil
  end, 1000)
  resolve({ text = "peer", hltext = "peer" })
  t.wait_until(function()
    return bar:snapshot():find("peer", 1, true) ~= nil
  end, 1000)
  t.assert_true(bar:snapshot():find("00002", 1, true) ~= nil)
end)

t:test("widget forks stop publishing after their window changes buffer", function()
  local source_winnr = window()
  local target_winnr = window()
  local other_bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(other_bufnr, { force = true })
  end)
  local bar = create(source_winnr)
  bar:place({
    position = "left",
    component = {
      name = "widget",
      refresh = function()
        return { text = "WIDGET", hltext = "WIDGET" }
      end,
    },
  })
  local fork = bar:fork(target_winnr)
  bar:refresh()
  t.wait_until(function()
    return vim.api.nvim_get_option_value("winbar", { win = target_winnr }):find("WIDGET", 1, true) ~= nil
  end, 1000)
  vim.api.nvim_win_set_buf(target_winnr, other_bufnr)
  vim.api.nvim_set_option_value("winbar", "other owner", { win = target_winnr, scope = "local" })
  bar:refresh()
  t.wait_until(function()
    return bar._components[1].runtime.status == "ready"
  end, 1000)
  t.assert_eq("", fork:render(), "fork rejects the foreign buffer")
  t.assert_eq("other owner", vim.api.nvim_get_option_value("winbar", { win = target_winnr }))
end)

t:test("center content remains visible when no padding fits", function()
  local winnr = window()
  local bar = create(winnr)
  bar:place({
    position = "center",
    component = {
      name = "full width",
      refresh = function()
        return { text = "12345678901234567890", hltext = "12345678901234567890" }
      end,
    },
  })
  bar:refresh()
  t.wait_until(function()
    return bar:render() == "12345678901234567890"
  end, 1000)
end)

t:test("component separators are included in the priority width budget", function()
  local winnr = window()
  local bar = Nvimbar.new({
    name = "separators",
    comp_sep = " ",
    comp_sep_hlname = "Normal",
    comp_sep_hlname_active = "Normal",
    get_preset_context = function()
      return { winnr = winnr }
    end,
    get_max_width = function()
      return 8
    end,
    is_active = function()
      return false
    end,
  })
  t:defer(function()
    bar:dispose()
  end)
  bar:place({
    position = "center",
    priority = 100,
    component = {
      name = "center",
      refresh = function()
        return { text = "C", hltext = "C" }
      end,
    },
  })
  bar:place({
    position = "left",
    priority = 90,
    component = {
      name = "first",
      refresh = function()
        return { text = "LL", hltext = "LL" }
      end,
    },
  })
  bar:place({
    position = "left",
    priority = 80,
    component = {
      name = "last",
      refresh = function()
        return { text = "z", hltext = "z" }
      end,
    },
  })
  bar:refresh()
  t.wait_until(function()
    for _, placed in ipairs(bar._components) do
      if placed.runtime.status ~= "ready" then
        return false
      end
    end
    return true
  end, 1000)
  local text = bar:render()
  t.assert_true(text:find("C", 1, true) ~= nil)
  t.assert_true(text:find("LL", 1, true) ~= nil)
  t.assert_false(text:find("z", 1, true) ~= nil)
  t.assert_true(vim.api.nvim_strwidth((text:gsub("%%=", ""))) <= 8)
end)

t:test("cold factories publish ready content before starting their next peer", function()
  local winnr = window()
  local published = ""
  local bar = create(winnr, function(text)
    published = text
  end)
  bar:place({
    position = "left",
    component = function()
      return {
        name = "first",
        refresh = function()
          return { text = "first", hltext = "first" }
        end,
      }
    end,
  })
  local prior_publication
  bar:place({
    position = "left",
    component = function()
      prior_publication = published
      return {
        name = "second",
        refresh = function()
          return { text = "second", hltext = "second" }
        end,
      }
    end,
  })
  bar:refresh()
  t.wait_until(function()
    return published:find("second", 1, true) ~= nil
  end, 1000)
  t.assert_true(prior_publication:find("first", 1, true) ~= nil, "cold work must not delay ready content")
end)

t:test("warm refreshes batch publication without rebuilding full owner contexts", function()
  local winnr = window()
  local mode_reads, layouts, publications = 0, 0, 0
  local text = "a"
  t:patch_table(dot.theme.hlgroup.common, "resolve_mode", function()
    mode_reads = mode_reads + 1
    return "n", "NORMAL"
  end)
  local bar = create(winnr, function()
    publications = publications + 1
  end, function()
    layouts = layouts + 1
    return 100
  end, 0)
  for index = 1, 5 do
    bar:place({
      position = "left",
      component = {
        name = "item_" .. index,
        refresh = function()
          return { text = text, hltext = text }
        end,
      },
    })
  end
  bar:refresh()
  t.wait_until(function()
    return bar:snapshot():find("aaaaa", 1, true) ~= nil
  end, 1000)

  -- Keep work inside one budget without depending on the host's execution speed.
  t:patch_table(vim.uv, "hrtime", function()
    return 0
  end)
  mode_reads, layouts, publications = 0, 0, 0
  text = "b"
  bar:refresh()
  t.wait_until(function()
    return bar:snapshot():find("bbbbb", 1, true) ~= nil
  end, 1000)
  t.assert_eq(2, layouts, "explicit publication and one completed batch")
  t.assert_eq(2, publications)
  t.assert_eq(layouts + 1, mode_reads, "only the request and layouts need a full context")
end)

t:run()
