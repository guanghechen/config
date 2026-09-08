local root = vim.uv.cwd()
vim.opt.runtimepath = { root, vim.env.VIMRUNTIME, vim.api.nvim__get_lib_dir() }
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local harness = require("__test__.support.harness")
local runtime = require("__test__.fixtures.era.dressing.statusline.runtime")
local Future = require("stl.c.future")
local t = harness.new("era.dressing.statusline.cmdline")
local errors = runtime.setup(t, {
  nvim = {
    mode = function(position)
      local component = require("era.m.nvimbar.component.nvim").mode(position)
      local refresh = component.refresh
      component.notify = { strategy = "debounce", interval = 30 }
      component.refresh = function(context, token)
        local future, resolve = Future.new_with_resolver({ token = token })
        vim.defer_fn(function()
          if not token:is_cancelled() then
            resolve(refresh(context, token))
          end
        end, 40)
        return future
      end
      return component
    end,
  },
})
t:patch_table(stl, "icon", { app = { Vim = "VIM" }, symbols = { sep_right = "" } })

vim.o.laststatus = 3
vim.o.cmdheight = 1
vim.o.showmode = false
vim.o.ruler = false
vim.o.swapfile = false
require("era.dressing.statusline").dressing()

---@return string
local function screenline()
  local chars = {}
  for col = 1, vim.o.columns do
    chars[#chars + 1] = vim.fn.screenstring(vim.o.lines - 1, col)
  end
  return table.concat(chars)
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local expected = { "NORMAL", "COMMAND", "NORMAL" }
    local modes = { "n", "c", "n" }
    local samples = {}
    local deadline = vim.uv.hrtime() / 1e6 + 3000
    ---@return nil
    local function poll()
      local current = { mode = vim.api.nvim_get_mode().mode, option = vim.o.statusline, screen = screenline() }
      local index = #samples + 1
      if
        current.mode == modes[index]
        and current.option:find(expected[index], 1, true)
        and current.screen:find(expected[index], 1, true)
      then
        samples[index] = current
        if index < #expected then
          vim.api.nvim_input(index == 1 and ":" or "<Esc>")
        end
      end
      local timed_out = vim.uv.hrtime() / 1e6 >= deadline
      if #samples == #expected or timed_out then
        vim.fn.writefile({
          vim.json.encode({ samples = samples, current = current, errors = errors, timed_out = timed_out }),
        }, assert(vim.env.NVIMBAR_TEST_RESULT))
        vim.cmd("qa!")
        return
      end
      vim.defer_fn(poll, 10)
    end
    vim.schedule(poll)
  end,
})
