---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.textobject" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local M = {}

---@param t                             __test__.support.Harness
---@return era.keystroke.textobject
---@return string[]
function M.setup(t)
  local messages = {} ---@type string[]
  bootstrap.with_runtime(t, {
    stl = {
      filetype = require("stl.filetype"),
      nvim = { fn = require("stl.nvim.fn") },
      reporter = {
        warn = function(event)
          messages[#messages + 1] = event.message
        end,
      },
    },
    era = {
      m = {},
      keystroke = require("era.keystroke"),
      dressing = { whichkey = { add = function() end } },
    },
  })
  era.m.git = { hunk = require("era.m.git.hunk") }
  local textobject = era.keystroke.textobject
  textobject.setup()
  return textobject, messages
end

---@param keys                          string
---@return nil
function M.feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end

---Shows `lines` in the current window without undo history; the case ends by leaving any pending mode and restoring
---'selection'.
---@param t                             __test__.support.Harness
---@param lines                         string[]
---@param filetype                      ?string
---@return integer
function M.buffer(t, lines, filetype)
  local selection = vim.o.selection ---@type string
  local bufnr = t:buffer(lines, { filetype = filetype or "lua", current = true }) ---@type integer
  t:defer(function()
    M.feed("<Esc>")
    vim.o.selection = selection
  end)
  vim.api.nvim_set_option_value("undolevels", -1, { buf = bufnr })
  vim.api.nvim_set_option_value("undolevels", 1000, { buf = bufnr })
  return bufnr
end

---@param range                         era.keystroke.textobject.Range
---@return string
function M.text(range)
  local line_count = vim.api.nvim_buf_line_count(0) ---@type integer
  if range[3] == line_count and range[4] == 0 then
    local last_line = vim.api.nvim_buf_get_lines(0, line_count - 1, line_count, true)[1] ---@type string
    return table.concat(vim.api.nvim_buf_get_text(0, range[1], range[2], line_count - 1, #last_line, {}), "\n") .. "\n"
  end
  return table.concat(vim.api.nvim_buf_get_text(0, range[1], range[2], range[3], range[4], {}), "\n")
end

return M
