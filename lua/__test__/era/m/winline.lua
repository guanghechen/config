---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/winline.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.winline")

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

  local winline = assert(loadfile("lua/era/m/winline.lua"))()
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

  local winline = assert(loadfile("lua/era/m/winline.lua"))()
  winline.dressing()
  assert(on_dirty)(winnr)
  t.assert_eq(1, renders, "external nvimbar render")

  vim.api.nvim_win_set_buf(winnr, bufnr_previous)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
