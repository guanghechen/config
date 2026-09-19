---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.dressing.indentline.screen" ---@type string

local root = vim.uv.cwd()
vim.opt.runtimepath = { root, vim.env.VIMRUNTIME, vim.api.nvim__get_lib_dir() }
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new("era.dressing.indentline.screen.fixture")
t:patch_global("stl", require("stl"))
require("ark.bootstrap").setup_patches()
local enabled = stl.c.Observable.from_value(true)
bootstrap.with_runtime(t, { dot = { context = { flight = { dressing_indent = enabled } } } })

vim.o.swapfile = false
vim.o.number = false
vim.o.relativenumber = false
vim.o.signcolumn = "no"
vim.o.foldcolumn = "0"
vim.o.laststatus = 0
vim.o.showtabline = 0
vim.o.showmode = false
vim.o.ruler = false
vim.o.cmdheight = 1
vim.o.shortmess = "atI"
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "root", "        child", "tail" })
vim.bo.filetype = "lua"
vim.bo.shiftwidth = 2
local hidden_bufnr = vim.api.nvim_create_buf(false, false)
vim.api.nvim_set_option_value("filetype", "lua", { buf = hidden_bufnr })
require("era.dressing.indentline").dressing()

local frames = 0
vim.api.nvim_set_decoration_provider(vim.api.nvim_create_namespace(__module_name__), {
  on_start = function()
    frames = frames + 1
  end,
})

---@return string
local function screenline()
  local chars = {}
  for col = 1, 13 do
    chars[#chars + 1] = vim.fn.screenstring(2, col)
  end
  return table.concat(chars)
end

local guides_two = "│ │ │ │ child"
local guides_four = "│   │   child"
local plain = "        child"
local steps = {
  { name = "initial guides", expected = guides_two },
  {
    name = "hidden option burst",
    expected = guides_two,
    frames = 1,
    action = function()
      for index = 1, 40 do
        vim.api.nvim_set_option_value("shiftwidth", index % 2 == 0 and 4 or 2, { buf = hidden_bufnr })
        vim.api.nvim_set_option_value("tabstop", index % 2 == 0 and 8 or 4, { buf = hidden_bufnr })
      end
    end,
  },
  {
    name = "enter command line",
    expected = guides_two,
    mode = "c",
    action = function()
      vim.api.nvim_input(":")
    end,
  },
  {
    name = "disable while command line is idle",
    expected = plain,
    mode = "c",
    frames = 1,
    action = function()
      enabled:next(false)
    end,
  },
  {
    name = "enable while command line is idle",
    expected = guides_two,
    mode = "c",
    frames = 1,
    action = function()
      enabled:next(true)
    end,
  },
  {
    name = "option burst while command line is idle",
    expected = guides_four,
    mode = "c",
    frames = 1,
    action = function()
      vim.bo.shiftwidth = 4
      vim.bo.tabstop = 4
    end,
  },
}
local samples = {}
local index = 0
local current

---@param timed_out                     boolean
---@return nil
local function finish(timed_out)
  vim.fn.writefile({
    vim.json.encode({ samples = samples, current = current, timed_out = timed_out }),
  }, assert(vim.env.INDENTLINE_TEST_RESULT))
  vim.cmd("qa!")
end

---@return nil
local function advance()
  index = index + 1
  local step = steps[index]
  if not step then
    finish(false)
    return
  end
  frames = 0
  if step.action then
    step.action()
  end
  local sync_frames = frames
  local deadline = vim.uv.hrtime() + 1000e6
  ---@return nil
  local function check()
    current = {
      name = step.name,
      screen = screenline(),
      mode = vim.api.nvim_get_mode().mode,
      frames = frames,
      sync_frames = sync_frames,
    }
    if
      current.screen == step.expected
      and current.mode == (step.mode or "n")
      and (step.frames == nil or current.frames == step.frames)
    then
      samples[#samples + 1] = current
      vim.defer_fn(advance, 10)
    elseif vim.uv.hrtime() >= deadline then
      finish(true)
    else
      -- Read the existing screen without requesting redraw or sending input.
      vim.defer_fn(check, 10)
    end
  end
  vim.defer_fn(check, 10)
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.defer_fn(advance, 50)
  end,
})
