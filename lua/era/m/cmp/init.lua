---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp" ---@type string

local cmdline = require("era.m.cmp.cmdline")
local insert = require("era.m.cmp.insert")
local keymap = require("era.m.cmp.keymap")
local signature = require("era.m.cmp.signature")

---@class era.m.cmp
local M = {}
local dressed = false

function M.show()
  if cmdline.in_cmdwin() then
    cmdline.refresh()
  else
    insert.show()
  end
end

function M.hide()
  if cmdline.in_cmdwin() then
    cmdline.cancel()
  else
    insert.hide()
  end
end

function M.backspace()
  if not cmdline.in_cmdwin() then
    insert.backspace()
  end
end

---@param bufnr?                       integer
---@return boolean
function M.visible(bufnr)
  return cmdline.visible() or insert.visible(bufnr or vim.api.nvim_get_current_buf())
end

function M.dressing()
  if dressed then
    return
  end
  dressed = true

  keymap.set_actions({
    accept = function(bufnr, index)
      return cmdline.in_cmdwin() and cmdline.accept(index) or insert.accept(bufnr, index)
    end,
    backspace = function()
      M.backspace()
    end,
    cancel = function(bufnr)
      return cmdline.in_cmdwin() and cmdline.cancel() or insert.cancel(bufnr)
    end,
    move = function(bufnr, direction)
      return cmdline.in_cmdwin() and cmdline.move(direction) or insert.move(bufnr, direction)
    end,
    signature = signature.toggle,
    show = M.show,
    visible = M.visible,
  })
  keymap.set_cmdline_actions({
    accept = cmdline.accept,
    cancel = cmdline.cancel,
    move = cmdline.move,
    show = cmdline.show,
  })
  keymap.bind_cmdline()
  insert.dressing(signature.show)
  cmdline.dressing()
  signature.dressing()
end

return M
