local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local module_name = "era.dressing.winline"
local t = harness.new()

-- Declares the `stl` the winline reads: subscribers are their props and text carries no highlight.
---@param has_external_winline          fun(filetype: string): boolean
---@param win                           table The `stl.nvim.win` functions.
---@param extra                         ?table Further `stl` fields.
---@return nil
local function patch_stl(has_external_winline, win, extra)
  t:patch_global(
    "stl",
    vim.tbl_extend("error", {
      c = { Subscriber = {
        new = function(props)
          return props
        end,
      } },
      filetype = { has_external_winline = has_external_winline },
      nvim = {
        fn = {
          txt = function(text)
            return text
          end,
        },
        win = win,
      },
    }, extra or {})
  )
end

t:test("diffview winbar renders hunk navigation on the right", function()
  local winnr = vim.api.nvim_get_current_win()
  t:buffer(nil, { name = "diffview:///repo/index/file.lua", current = true })
  local on_dirty = nil ---@type fun(winnr: integer)|nil

  patch_stl(function()
    return false
  end, {
    is_valid = function(target_winnr)
      return target_winnr == winnr
    end,
  }, { env = { HOME_NVIM_CONFIG = "/nvim" } })
  t:patch_global("dot", {
    state = {
      status = {
        dirty_winline_nr = {
          subscribe = function(_, subscriber)
            on_dirty = subscriber.on_next
          end,
        },
      },
    },
  })
  t:patch_global("era", {
    m = {
      nvimbar = {
        component = {
          git = {
            render_hunk_nav = function(target_winnr)
              t.assert_eq(winnr, target_winnr, "indicator window")
              return "G 2/3", "G 2/3"
            end,
          },
        },
      },
    },
  })

  local winline = assert(loadfile("lua/era/dressing/winline.lua"))()
  winline.dressing()
  assert(on_dirty)(winnr)

  local rendered = vim.api.nvim_get_option_value("winbar", { win = winnr }) ---@type string
  t.assert_eq("diffview:///repo/index/file.lua%=G 2/3", rendered, "diffview winbar")
end)

t:test("external winline delegates dirty renders to its owned nvimbar", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  t:buffer(nil, { filetype = "diffview-commits-test", current = true })
  local on_dirty = nil ---@type fun(winnr: integer)|nil
  local renders = 0

  patch_stl(function(filetype)
    return filetype == "diffview-commits-test"
  end, {
    is_valid = function(target_winnr)
      return target_winnr == winnr
    end,
  })
  t:patch_global("dot", {
    state = {
      status = {
        dirty_winline_nr = {
          subscribe = function(_, subscriber)
            on_dirty = subscriber.on_next
          end,
        },
      },
    },
    win = {
      render_winline = function()
        renders = renders + 1
      end,
      resolve = function()
        return {
          winline = {
            nvimbar = {
              isdisposed = function()
                return false
              end,
              render = function()
                error("external render should delegate through dot.win")
              end,
            },
          },
        }
      end,
    },
  })

  local winline = assert(loadfile("lua/era/dressing/winline.lua"))()
  winline.dressing()
  assert(on_dirty)(winnr)
  t.assert_eq(1, renders, "external nvimbar render")
end)

t:test("dressing subscribes once and routes dirty updates to valid current and previous windows", function()
  local winnr = vim.api.nvim_get_current_win()
  local previous_winnr = t:window(t:buffer(), { split = "right" })

  local subscribers = {}
  local rendered_winnrs = {}
  patch_stl(function()
    return true
  end, { is_valid = vim.api.nvim_win_is_valid })
  t:patch_global("dot", {
    state = {
      status = {
        dirty_winline_nr = {
          subscribe = function(_, subscriber, ignore_initial)
            t.assert_true(ignore_initial, "initial notification ignored")
            subscribers[#subscribers + 1] = subscriber
          end,
        },
      },
    },
    win = {
      render_winline = function(target_winnr)
        rendered_winnrs[#rendered_winnrs + 1] = target_winnr
      end,
    },
  })
  t:patch_global("era", require("era"))
  t:patch_table(package.loaded, module_name, nil)
  t.assert_eq(module_name, era.dressing.__mods.winline, "module registration")
  local winline = era.dressing.winline

  local function notify(winnr, winnr_prev)
    for _, subscriber in ipairs(subscribers) do
      subscriber.on_next(winnr, winnr_prev)
    end
  end

  winline.dressing()
  winline.dressing()
  t.assert_eq(1, #subscribers, "dirty subscriptions")
  t.assert_eq(0, #rendered_winnrs, "setup keeps rendering lazy")

  notify(winnr, previous_winnr)
  t.assert_same({ winnr, previous_winnr }, rendered_winnrs, "both dirty windows render once")
  rendered_winnrs = {}
  notify(winnr, winnr)
  t.assert_same({ winnr }, rendered_winnrs, "identical windows render once")

  vim.api.nvim_win_close(previous_winnr, true)
  rendered_winnrs = {}
  notify(winnr, previous_winnr)
  notify(previous_winnr, winnr)
  notify(nil, nil)
  t.assert_same({ winnr, winnr }, rendered_winnrs, "closed and missing windows are ignored")
end)

t:test("source windows show the confirmed path at once and apply delivered symbols", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  t:buffer(nil, { name = "/tmp/winline-spec-source.lua", listed = true, current = true })

  local on_dirty = nil ---@type fun(winnr: integer)|nil
  local calls = {} ---@type string[]
  local confirmed = nil ---@type dot.t.ILspSymbol[]|nil
  local deliver = nil ---@type fun(winnr: integer, symbols: dot.t.ILspSymbol[])|nil
  local metas = {} ---@type table<integer, dot.win.IMeta>
  local bar = { disposed = false, refreshes = 0 }
  function bar:place()
    return self
  end
  function bar:isdisposed()
    return self.disposed
  end
  function bar:refresh()
    self.refreshes = self.refreshes + 1
  end

  local scheduled = bootstrap.with_schedule(t).callbacks
  patch_stl(function()
    return false
  end, {
    is_valid = vim.api.nvim_win_is_valid,
    is_float = function()
      return false
    end,
  })
  t:patch_global("dot", {
    state = {
      status = {
        dirty_winline_nr = {
          subscribe = function(_, subscriber)
            on_dirty = subscriber.on_next
          end,
          next = function()
            error("symbol delivery must not mark the winline dirty")
          end,
        },
      },
    },
    win = {
      is_sourcefile = function()
        return true
      end,
      resolve = function(target_winnr)
        metas[target_winnr] = metas[target_winnr] or {}
        return metas[target_winnr]
      end,
      render_winline = function()
        calls[#calls + 1] = "render"
      end,
    },
  })
  local component = setmetatable({
    lazy = function(fn)
      return fn
    end,
  }, {
    __index = function()
      return {}
    end,
  })
  t:patch_global("era", {
    m = {
      nvimbar = {
        Nvimbar = {
          new = function()
            return bar
          end,
        },
        component = component,
      },
      lsp = {
        symbols = {
          path = function(target_winnr)
            t.assert_eq(winnr, target_winnr, "path window")
            calls[#calls + 1] = "path"
            return confirmed
          end,
          request = function(target_winnr, on_result)
            t.assert_eq(winnr, target_winnr, "request window")
            calls[#calls + 1] = "request"
            deliver = on_result
          end,
        },
      },
    },
  })

  local winline = assert(loadfile("lua/era/dressing/winline.lua"))()
  winline.dressing()
  assert(on_dirty)(winnr)
  t.assert_eq("path,request,render", table.concat(calls, ","), "confirmed path before the request")
  local meta = metas[winnr]
  t.assert_eq(0, #meta.winline.lsp_symbols, "no confirmed path yet")

  local first = { { kind = "Function", name = "outer", row = 1, col = 1 } } ---@type dot.t.ILspSymbol[]
  assert(deliver)(winnr, first)
  t.assert_eq(first, meta.winline.lsp_symbols, "delivered symbols")
  t.assert_eq(1, #scheduled, "scheduled refresh")
  table.remove(scheduled, 1)()
  t.assert_eq(1, bar.refreshes, "refreshed")
  deliver(winnr, { { kind = "Function", name = "outer", row = 1, col = 1 } })
  t.assert_eq(0, #scheduled, "unchanged path keeps the bar")

  confirmed = { { kind = "Function", name = "confirmed", row = 1, col = 1 } }
  on_dirty(winnr)
  t.assert_eq(confirmed, meta.winline.lsp_symbols, "confirmed path at once")
  confirmed = nil
  on_dirty(winnr)
  t.assert_eq("confirmed", meta.winline.lsp_symbols[1].name, "unknown path keeps the shown one")

  bar.disposed = true
  deliver(winnr, first)
  t.assert_eq("confirmed", meta.winline.lsp_symbols[1].name, "disposed bar ignores deliveries")
end)

t:run()
