---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/dot/context/init.lua

local harness = require("__test__.harness")

local t = harness.new("dot.context")

local modules = {
  ["dot.context.editor.behavior"] = { auto_im = {}, bufs_relative = {} },
  ["dot.context.editor.theme"] = { theme = {}, transparency = {}, username = {} },
  ["dot.context.workspace.bookmark"] = { pinned = {} },
  ["dot.context.workspace.flight"] = {
    autoformat = {},
    autoload = {},
    autosave = {},
    devmode = {},
    dressing_clipboard = {},
    dressing_illuminate = {},
    dressing_input = {},
    dressing_select = {},
    dressing_winsep = {},
    gitdiff_expand_all = {},
  },
  ["dot.context.workspace.lsp"] = {
    code_lens = {},
    diagnostics_virt_lines = {},
    inlay_hints = {},
    python_venv_path = {},
  },
  ["dot.context.workspace.option"] = { expandtab = {}, relativenumber = {} },
  ["dot.context.workspace.plugin"] = { render_markdown = {}, treesitter_context = {} },
}

t:test("watch_changes watches only an existing editor state file", function()
  local readable = 0
  local watch_count = 0

  for name, value in pairs(modules) do
    t:patch_table(package.loaded, name, value)
  end
  t:patch_global("stl", {
    c = {
      Disposable = {
        new = function(props)
          return props
        end,
      },
      Observable = {
        from_value = function(value)
          return { value = value }
        end,
      },
      Scheduler = {
        new = function()
          return { schedule = function() end }
        end,
      },
      Subscriber = {
        new = function(props)
          return props
        end,
      },
      Ticker = {
        new = function()
          return {
            subscribe = function() end,
            tick = function() end,
          }
        end,
      },
    },
    fn = {
      falsy = function()
        return false
      end,
      observe = function() end,
    },
    fs = {
      read_json = function()
        return {}
      end,
      watch_file = function()
        watch_count = watch_count + 1
        return function() end
      end,
    },
    reporter = { error = function() end },
  })
  t:patch_global("dot", {
    state = {
      status = {
        add_disposable = function() end,
        dirtier_statusline = { mark_dirty = function() end },
        dirtier_tabline = { mark_dirty = function() end },
      },
    },
  })
  t:patch_table(vim.fn, "filereadable", function()
    return readable
  end)

  local Context = assert(loadfile("lua/dot/context/init.lua"))()
  dot.context = Context
  Context.set_storage({ editor = "editor.json" })

  Context.watch_changes()
  local watches_when_missing = watch_count

  readable = 1
  Context.watch_changes()
  local watches_when_readable = watch_count

  t.assert_eq(0, watches_when_missing, "watch count for missing file")
  t.assert_eq(1, watches_when_readable, "watch count for readable file")
end)

t:run()
