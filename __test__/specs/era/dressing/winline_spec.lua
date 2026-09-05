--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/winline_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local module_name = "era.dressing.winline"
local t = harness.new(module_name)

t:test("diffview winbar renders hunk navigation on the right", function()
  local winnr = vim.api.nvim_get_current_win()
  local bufnr_previous = vim.api.nvim_win_get_buf(winnr)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local on_dirty = nil ---@type fun(winnr: integer)|nil

  vim.api.nvim_buf_set_name(bufnr, "diffview:///repo/index/file.lua")
  vim.api.nvim_win_set_buf(winnr, bufnr)

  t:patch_global("stl", {
    c = {
      Subscriber = {
        new = function(spec)
          return spec
        end,
      },
    },
    env = {
      HOME_NVIM_CONFIG = "/nvim",
    },
    filetype = {
      has_external_winline = function()
        return false
      end,
    },
    nvim = {
      fn = {
        txt = function(text)
          return text
        end,
      },
      win = {
        is_valid = function(target_winnr)
          return target_winnr == winnr
        end,
      },
    },
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

  vim.api.nvim_win_set_buf(winnr, bufnr_previous)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("external winline delegates dirty renders to its owned nvimbar", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr_previous = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local on_dirty = nil ---@type fun(winnr: integer)|nil
  local renders = 0

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "diffview-commits-test", { buf = bufnr })
  vim.api.nvim_win_set_buf(winnr, bufnr)

  t:patch_global("stl", {
    c = {
      Subscriber = {
        new = function(spec)
          return spec
        end,
      },
    },
    filetype = {
      has_external_winline = function(filetype)
        return filetype == "diffview-commits-test"
      end,
    },
    nvim = {
      fn = {
        txt = function(text)
          return text
        end,
      },
      win = {
        is_valid = function(target_winnr)
          return target_winnr == winnr
        end,
      },
    },
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

  vim.api.nvim_win_set_buf(winnr, bufnr_previous)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("dressing subscribes once and routes dirty updates to valid current and previous windows", function()
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local previous_winnr = vim.api.nvim_open_win(bufnr, false, { split = "right" })
  t:defer(function()
    if vim.api.nvim_win_is_valid(previous_winnr) then
      vim.api.nvim_win_close(previous_winnr, true)
    end
  end)

  local subscribers = {}
  local rendered_winnrs = {}
  t:patch_global("stl", {
    c = { Subscriber = {
      new = function(props)
        return props
      end,
    } },
    filetype = {
      has_external_winline = function()
        return true
      end,
    },
    nvim = {
      fn = {
        txt = function(text)
          return text
        end,
      },
      win = { is_valid = vim.api.nvim_win_is_valid },
    },
  })
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
  t.assert_nil(era.m.__mods.winline, "old registration removed")
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
  t.assert_true(vim.deep_equal({ winnr, previous_winnr }, rendered_winnrs), "both dirty windows render once")
  rendered_winnrs = {}
  notify(winnr, winnr)
  t.assert_true(vim.deep_equal({ winnr }, rendered_winnrs), "identical windows render once")

  vim.api.nvim_win_close(previous_winnr, true)
  rendered_winnrs = {}
  notify(winnr, previous_winnr)
  notify(previous_winnr, winnr)
  notify(nil, nil)
  t.assert_true(vim.deep_equal({ winnr, winnr }, rendered_winnrs), "closed and missing windows are ignored")
end)

t:run()
