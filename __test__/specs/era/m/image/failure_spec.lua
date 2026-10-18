--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/image/failure_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.image.failure")

bootstrap.with_runtime(t, {
  dot = {
    context = { flight = {} },
    path = {
      join = function(left, right)
        return left .. "/" .. right
      end,
    },
    var = { N_IMAGE_ATTACHED = "image_failure_attached" },
  },
  stl = {
    env = {
      IS_GHOSTTY = false,
      IS_KITTY = false,
      IS_TMUX = false,
      IS_WEZTERM = false,
    },
    table = require("stl.table"),
    timer = require("stl.timer"),
  },
  yoz = {},
})

---@param done                          boolean
---@param error                         string|nil
---@return table
local function conversion(done, error)
  return {
    done = function()
      return done
    end,
    error = function()
      return error
    end,
  }
end

t:test("a failed conversion is never ready, even when its source stays readable", function()
  local Image = assert(loadfile("lua/era/m/image/image.lua"))()
  -- A PNG needs no conversion, so a broken one keeps the readable source as its file.
  local file = vim.fn.tempname() .. ".png" ---@type string
  vim.fn.writefile({ "not a png" }, file)
  t:defer(function()
    vim.fn.delete(file)
  end)

  local failed = setmetatable({ file = file, convert = conversion(true, "identify: improper image header") }, Image)
  t.assert_false(failed:ready(), "failed conversion")
  t.assert_true(failed:failed(), "failed conversion")

  local pending = setmetatable({ file = file, convert = conversion(false, nil) }, Image)
  t.assert_false(pending:ready(), "pending conversion")
  t.assert_false(pending:failed(), "pending conversion")

  local converted = setmetatable({ file = file, convert = conversion(true, nil) }, Image)
  t.assert_true(converted:ready(), "finished conversion")
  t.assert_false(converted:failed(), "finished conversion")
end)

t:test("the failure message is highlighted by treesitter alone", function()
  local Placement = assert(loadfile("lua/era/m/image/placement.lua"))()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  setmetatable({ bufnr = bufnr, opts = {}, img = {} }, Placement):error()
  t.assert_eq("# Image Conversion Failed:", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1])
  t.assert_true(vim.treesitter.highlighter.active[bufnr] ~= nil, "treesitter highlighting")
  t.assert_eq("", vim.api.nvim_get_option_value("syntax", { buf = bufnr }), "no regex syntax on top")
end)

t:run()
