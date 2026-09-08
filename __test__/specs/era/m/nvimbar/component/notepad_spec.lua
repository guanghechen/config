local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local Nvimbar = require("era.m.nvimbar.nvimbar")
local t = harness.new("era.m.nvimbar.component.notepad")

t:test("source selection handlers survive closed forks without accumulating registrations", function()
  local selections = 0
  t:patch_global("stl", require("stl"))
  bootstrap.with_runtime(t, {
    dot = {
      G = require("dot.G"),
      path = {
        cwd = function()
          return "/test"
        end,
      },
      theme = {
        hlgroup = {
          common = {
            resolve_mode = function()
              return "n", "NORMAL"
            end,
          },
        },
      },
      command = {
        definitions = {
          notepad = {
            source_select = {
              execute = function()
                selections = selections + 1
              end,
            },
          },
        },
      },
    },
    era = {
      m = {
        notepad = {
          state = {
            retrieve_source = function()
              return nil, { engine = "json" }
            end,
          },
        },
      },
    },
    yoz = {
      path = {
        basename = function(path)
          return path:match("[^/]*$")
        end,
      },
    },
  })

  local handlers = {} ---@type string[]
  local register = dot.G.register_anonymous_fn
  t:patch_table(dot.G, "register_anonymous_fn", function(fn, name)
    local handler, unregister = register(fn, name)
    t:defer(unregister)
    handlers[#handlers + 1] = handler:sub(#"dot.G." + 1)
    return handler, unregister
  end)

  ---@return integer
  local function count_handlers()
    local count = 0
    for _, handler in ipairs(handlers) do
      if type(dot.G[handler]) == "function" then
        count = count + 1
      end
    end
    return count
  end

  local provider = require("era.m.nvimbar.component.notepad")
  local notepad = {
    get_source = function()
      return { name = "notes" }
    end,
  }
  ---@cast notepad era.m.notepad.View
  local winnr, bufnr = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  local bar = Nvimbar.new({
    name = "notepad",
    comp_sep = "",
    comp_sep_hlname = "Normal",
    comp_sep_hlname_active = "Normal",
    get_preset_context = function()
      return { winnr = winnr }
    end,
    get_max_width = function()
      return 80
    end,
    is_active = stl.fn.truthy,
  })
  t:defer(function()
    bar:dispose()
  end)
  bar:place({
    position = "left",
    component = function()
      return provider.source("f_wl", notepad)
    end,
  })
  bar:refresh()
  t.wait_until(function()
    return bar:snapshot():find("notes@json", 1, true) ~= nil
  end, 1000, "source label is published")
  local source_handler = assert(bar:snapshot():match("dot%.G%.(_%d+)"))
  local initial_count = count_handlers()

  for _ = 1, 25 do
    local target_winnr = vim.api.nvim_open_win(bufnr, false, {
      relative = "editor",
      row = 1,
      col = 1,
      width = 40,
      height = 3,
    })
    t:defer(function()
      if vim.api.nvim_win_is_valid(target_winnr) then
        vim.api.nvim_win_close(target_winnr, true)
      end
    end)
    local fork = bar:fork(target_winnr)
    fork:refresh()
    t.wait_until(function()
      return vim.api.nvim_get_option_value("winbar", { win = target_winnr }):find("notes@json", 1, true) ~= nil
    end, 1000, "fork publishes the source label")
    vim.api.nvim_win_close(target_winnr, true)
    t.assert_true(fork:isdisposed())
  end

  t.assert_eq(initial_count, count_handlers(), "closed forks do not retain global handlers")
  dot.G[source_handler]()
  t.assert_eq(1, selections, "closing a fork preserves the source selection action")
  bar:dispose()
  t.assert_eq(initial_count, count_handlers(), "parent disposal does not leave per-instance registrations")
end)

t:run()
