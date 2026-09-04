---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/dressing/indentline/setup.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.dressing.indentline.setup")
local module_name = "era.dressing.indentline" ---@type string
local observable = {
  value = true,
  snapshot = function(self)
    return self.value
  end,
}
local observer = nil ---@type fun()|nil
local provider = nil ---@type table|nil
local observe_calls = 0 ---@type integer
local augroup_calls = 0 ---@type integer
local autocmd_calls = 0 ---@type integer
local redraw_calls = 0 ---@type integer
local option_patterns = nil ---@type string[]|nil

bootstrap.with_runtime(t, {
  stl = {
    filetype = require("stl.filetype"),
    fn = {
      observe = function(observables, callback, ignore_initial)
        observe_calls = observe_calls + 1
        observer = callback
        t.assert_eq(observable, observables[1], "observed flight")
        t.assert_true(ignore_initial, "initial notification ignored")
        return { unsubscribe = function() end }
      end,
    },
    nvim = {
      fn = {
        augroup = function(name)
          augroup_calls = augroup_calls + 1
          t.assert_eq(module_name, name, "augroup name")
          return 1
        end,
      },
    },
  },
  dot = {
    context = {
      flight = {
        dressing_indent = observable,
      },
    },
  },
})

t:patch_table(vim.api, "nvim_set_decoration_provider", function(_, value)
  provider = value
end)
t:patch_table(vim.api, "nvim_create_autocmd", function(event, options)
  autocmd_calls = autocmd_calls + 1
  if event == "OptionSet" then
    option_patterns = options.pattern
  end
  return autocmd_calls
end)
t:patch_table(vim.api, "nvim__redraw", function()
  redraw_calls = redraw_calls + 1
end)
t:patch_table(package.loaded, module_name, nil)
t:patch_table(package.loaded, "era.dressing.indentline.render", nil)

local Indentline = require(module_name)

t:test("dressing initializes provider and lifecycle once", function()
  Indentline.dressing()
  Indentline.dressing()

  t.assert_eq(1, observe_calls, "observer registrations")
  t.assert_eq(1, augroup_calls, "augroup registrations")
  t.assert_eq(2, autocmd_calls, "autocmd registrations")
  t.assert_true(provider ~= nil, "decoration provider")
  t.assert_eq(1, redraw_calls, "initial redraw")
  for _, option in ipairs({
    "breakindent",
    "buftype",
    "filetype",
    "list",
    "listchars",
    "shiftwidth",
    "tabstop",
    "vartabstop",
  }) do
    t.assert_true(option_patterns ~= nil and vim.list_contains(option_patterns, option), "observed option: " .. option)
  end
end)

t:test("provider renders ephemeral guides and respects eligibility", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "  one", "    two" })
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  vim.api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })
  local extmarks = {} ---@type table[]
  local option_refs = {} ---@type table[]

  local ok, err = pcall(function()
    t:patch_table(vim.api, "nvim_buf_set_extmark", function(_, _, row, col, options)
      option_refs[#option_refs + 1] = options
      extmarks[#extmarks + 1] = { row = row, col = col, options = vim.deepcopy(options) }
      return #extmarks
    end)

    t.assert_false(provider and provider.on_win(nil, winnr, bufnr, 0, 2), "rebuilt window skips range callback")
    t.assert_eq(2, #extmarks, "guide count")
    t.assert_eq(0, extmarks[1].row, "first row")
    t.assert_true(extmarks[1].options.ephemeral, "ephemeral extmark")
    t.assert_eq("overlay", extmarks[1].options.virt_text_pos, "overlay position")
    t.assert_true(rawequal(option_refs[1], option_refs[2]), "extmark options reused")

    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    t.assert_false(provider and provider.on_win(nil, winnr, bufnr, 0, 2), "blocked buftype")
    vim.api.nvim_set_option_value("buftype", "", { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", "bigfile", { buf = bufnr })
    t.assert_false(provider and provider.on_win(nil, winnr, bufnr, 0, 2), "blocked bigfile")
  end)

  if vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end)

t:test("flight changes invalidate rendering and redraw", function()
  observable.value = false
  ---@diagnostic disable-next-line: need-check-nil
  observer()
  t.assert_false(Indentline.is_enabled(vim.api.nvim_get_current_buf()), "flight disabled")
  t.assert_eq(2, redraw_calls, "flight redraw")
end)

t:run()
