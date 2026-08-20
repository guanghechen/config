---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/git/hunk.lua

local harness = require("__test__.harness")
local diff = require("era.m.git.diff")
local hunk = require("era.m.git.hunk")

local t = harness.new("era.m.git.hunk")

t:test("signs: a following deletion does not rewrite a change sign", function()
  local hunks = diff.run_diff({ "a", "b", "c", "" }, { "A", "b", "" })
  local signs = hunk.calc_signs_all(hunks)

  t.assert_eq(2, #hunks, "authoritative hunks")
  t.assert_eq("change", signs[1].type, "change sign")
  t.assert_eq(1, signs[1].lnum, "change line")
  t.assert_eq("delete", signs[2].type, "delete sign")
  t.assert_eq(2, signs[2].lnum, "delete anchor")
end)

t:test("signs: excess removed lines remain a changedelete", function()
  local hunks = diff.run_diff({ "a", "b", "c", "" }, { "A", "" })
  local signs = hunk.calc_signs_all(hunks)

  t.assert_eq(1, #hunks, "one unequal hunk")
  t.assert_eq("changedelete", signs[1].type, "combined sign")
end)

t:test("textobject: returns linewise unstaged hunk regions", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local modified = { "one", "TWO", "THREE", "four", "six" }
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, modified)
  hunk.set(bufnr, diff.run_diff({ "one", "two", "three", "four", "five", "six" }, modified))

  local regions ---@type table[]
  vim.api.nvim_buf_call(bufnr, function()
    regions = hunk.ai_textobject()
  end)
  hunk.remove(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })

  t.assert_eq(2, #regions, "regions")
  t.assert_eq(2, regions[1].from.line, "first start")
  t.assert_eq(3, regions[1].to.line, "first end")
  t.assert_eq(5, regions[1].to.col, "last byte column")
  t.assert_eq("V", regions[1].vis_mode, "linewise")
  t.assert_eq(4, regions[2].from.line, "second start")
end)

t:test("textobject: anchors a pure deletion to a selectable line", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "next" })
  hunk.set(bufnr, diff.run_diff({ "gone", "next" }, { "next" }))

  local regions ---@type table[]
  vim.api.nvim_buf_call(bufnr, function()
    regions = hunk.ai_textobject()
  end)
  hunk.remove(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })

  t.assert_eq(1, regions[1].from.line, "top deletion anchor")
  t.assert_eq(1, regions[1].to.line, "single anchor line")
  t.assert_eq("V", regions[1].vis_mode, "linewise")
end)

t:test("navigation publishes transient winline state", function()
  local winnr = vim.api.nvim_get_current_win()
  local bufnr_previous = vim.api.nvim_win_get_buf(winnr)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local dirty_calls = {} ---@type { winnr: integer, force: boolean }[]

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "one", "two", "three", "four" })
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_win_set_cursor(winnr, { 1, 0 })

  t:patch_global("era", {
    m = {
      git = {
        buffer = {
          is_attached = function()
            return true
          end,
          get_unstaged_hunks = function()
            return {
              { added = { start = 2 }, vend = 2 },
              { added = { start = 4 }, vend = 4 },
            }
          end,
        },
      },
    },
  })
  t:patch_global("dot", {
    state = {
      status = {
        dirty_winline_nr = {
          next = function(_, dirty_winnr, opts)
            dirty_calls[#dirty_calls + 1] = { winnr = dirty_winnr, force = opts ~= nil and opts.force == true }
          end,
        },
      },
    },
  })

  hunk.nav("next")

  local index, total = hunk.get_nav_indicator(winnr)
  t.assert_eq(1, index, "current hunk")
  t.assert_eq(2, total, "total hunks")
  t.assert_eq(2, vim.api.nvim_win_get_cursor(winnr)[1], "target line")
  t.assert_eq(winnr, dirty_calls[#dirty_calls].winnr, "dirty window")
  t.assert_true(dirty_calls[#dirty_calls].force, "force redraw for repeated window")

  hunk.clear_nav()
  t.assert_nil(hunk.get_nav_indicator(winnr), "cleared indicator")

  vim.api.nvim_win_set_buf(winnr, bufnr_previous)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("git winline component renders hunk navigation position", function()
  t:patch_global("stl", {
    nvim = {
      fn = {
        txt = function(text)
          return text
        end,
      },
    },
  })
  t:patch_global("era", {
    m = {
      git = {
        hunk = {
          get_nav_indicator = function(winnr)
            t.assert_eq(42, winnr, "component window")
            return 2, 10
          end,
        },
      },
    },
  })

  local git_component = assert(loadfile("lua/era/m/nvimbar/component/git.lua"))()
  local component = git_component.hunk_nav("f_wl")

  local context = { winnr = 42 } ---@type era.m.nvimbar.INvimbarContext
  t.assert_true(component.condition(context, 20), "visible with navigation state")
  local text, _, full = component.render(context, 20)
  t.assert_eq("[2/10]", text, "rendered position")
  t.assert_true(full, "atomic result")
end)

t:run()
