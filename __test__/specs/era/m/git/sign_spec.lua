--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/git/sign_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.git.sign")

bootstrap.with_runtime(t, {
  era = {
    m = {
      git = {
        buffer = {
          get_cache = function()
            return nil
          end,
        },
        hunk = {
          calc_signs_all = function(signs)
            return signs
          end,
        },
      },
    },
  },
})

local sign = require("era.m.git.sign")

---@return integer
local function create_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "one", "two", "three" })
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return bufnr
end

---@param bufnr                      integer
---@return table[]
local function marks(bufnr)
  return vim.api.nvim_buf_get_extmarks(bufnr, sign.get_namespace(), 0, -1, { details = true })
end

t:test("incremental update distinguishes sign types that share a highlight", function()
  local bufnr = create_buffer()
  sign.update(bufnr, { { lnum = 1, type = "change" } }, nil)
  sign.update(bufnr, { { lnum = 1, type = "changedelete" } }, nil)

  local current = marks(bufnr)
  t.assert_eq(1, #current, "single sign")
  t.assert_eq("~", current[1][4].sign_text:gsub("%s+$", ""), "updated sign glyph")
end)

t:test("incremental removal uses the extmark id after line movement", function()
  local bufnr = create_buffer()
  sign.update(bufnr, { { lnum = 2, type = "change" } }, nil)
  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "inserted" })

  local moved = marks(bufnr)
  t.assert_eq(3, moved[1][2] + 1, "extmark follows edited text")

  sign.update(bufnr, {}, nil)
  t.assert_eq(0, #marks(bufnr), "moved extmark removed")
end)

t:run()
