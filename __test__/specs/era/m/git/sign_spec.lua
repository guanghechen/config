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

t:test("an update keeps one mark per line after an edit joins two", function()
  local bufnr = create_buffer()
  sign.update(bufnr, { { lnum = 1, type = "change" }, { lnum = 2, type = "add" } }, nil)
  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, {})
  t.assert_eq(2, #marks(bufnr), "both marks on the first line")

  sign.update(bufnr, { { lnum = 1, type = "change" } }, nil)
  local current = marks(bufnr)
  t.assert_eq(1, #current, "single mark")
  t.assert_eq(0, current[1][2], "first line")
  t.assert_eq("m_git_sign_change", current[1][4].sign_hl_group, "change sign")
end)

t:test("an unchanged update writes nothing and unknown marks are dropped", function()
  local bufnr = create_buffer()
  local signs = { { lnum = 1, type = "change" }, { lnum = 3, type = "add" } } ---@type era.m.git.Sign[]
  sign.update(bufnr, signs, nil)
  vim.api.nvim_buf_set_extmark(bufnr, sign.get_namespace(), 1, 0, { sign_text = "?", sign_hl_group = "Error" })

  local writes = 0 ---@type integer
  for _, name in ipairs({ "nvim_buf_set_extmark", "nvim_buf_del_extmark", "nvim_buf_clear_namespace" }) do
    local original = vim.api[name]
    t:patch_table(vim.api, name, function(...)
      writes = writes + 1
      return original(...)
    end)
  end
  sign.update(bufnr, signs, nil)
  t.assert_eq(1, writes, "only the unknown mark is removed")
  t.assert_eq(2, #marks(bufnr), "known marks kept")

  writes = 0
  sign.update(bufnr, signs, nil)
  t.assert_eq(0, writes, "nothing to write")
end)

t:run()
