--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/indentline/options_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.dressing.indentline.options")

bootstrap.with_runtime(t, {
  stl = {
    filetype = require("stl.filetype"),
    fn = {
      observe = function()
        return { unsubscribe = function() end }
      end,
    },
    nvim = {
      fn = {
        augroup = function(name)
          return vim.api.nvim_create_augroup(name, { clear = true })
        end,
      },
    },
  },
  dot = {
    context = {
      flight = {
        dressing_indent = {
          snapshot = function()
            return true
          end,
        },
      },
    },
  },
})

local redraws = {} ---@type vim.api.keyset.redraw[]
t:patch_table(vim.api, "nvim__redraw", function(options)
  redraws[#redraws + 1] = options
end)
t:patch_table(package.loaded, "era.dressing.indentline", nil)
t:patch_table(package.loaded, "era.dressing.indentline.render", nil)

local Indentline = require("era.dressing.indentline")
Indentline.dressing()

-- The windows each coalesced refresh redraws; "all" for every window.
---@return string
local function settle()
  vim.wait(20)
  local targets = {} ---@type string[]
  for _, options in ipairs(redraws) do
    targets[#targets + 1] = options.win and tostring(options.win) or "all"
  end
  table.sort(targets)
  redraws = {}
  return table.concat(targets, ",")
end
settle()

---@return integer bufnr
---@return integer winnr
local function open_float()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 1, col = 1, width = 20, height = 2 })
  settle()
  return bufnr, winnr
end

t:test("a floating window setting its options redraws only itself", function()
  local bufnr, winnr = open_float()

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  vim.api.nvim_set_option_value("list", true, { win = winnr })
  t.assert_eq(tostring(winnr), settle(), "one coalesced redraw of the float")
end)

t:test("a buffer option redraws every window on the buffer", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("split")
  local split_winnr = vim.api.nvim_get_current_win() ---@type integer
  t:defer(function()
    vim.api.nvim_win_close(split_winnr, true)
  end)
  settle()

  vim.api.nvim_set_option_value("shiftwidth", 3, { buf = bufnr })
  local expected = { tostring(winnr), tostring(split_winnr) } ---@type string[]
  table.sort(expected)
  t.assert_eq(table.concat(expected, ","), settle(), "windows on the buffer")

  vim.cmd("set tabstop=4")
  t.assert_eq(table.concat(expected, ","), settle(), "a global set still changes only the current buffer")
end)

t:test("only a global-local option set globally redraws every window", function()
  local _, winnr = open_float()
  local listchars = vim.o.listchars ---@type string
  t:defer(function()
    vim.o.listchars = listchars
  end)

  vim.api.nvim_set_option_value("listchars", "tab:>-", { win = winnr, scope = "local" })
  t.assert_eq(tostring(winnr), settle(), "local value")
  vim.cmd("set listchars=tab:>-,trail:-")
  t.assert_eq("all", settle(), "global value")
end)

t:run()
