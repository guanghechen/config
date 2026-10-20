---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.cmp.runtime" ---@type string

local M = {}

---@param baseline                      ?string
---@return nil
function M.setup(baseline)
  if baseline ~= nil then
    vim.opt.runtimepath:prepend(baseline)
    local library = baseline .. "/lua/yoz." .. (vim.fn.has("win32") == 1 and "dll" or "so")
    package.preload.yoz = assert(package.loadlib(library, "luaopen_yoz"))
  end
  _G.yoz = require("yoz")
  _G.stl = { env = { IS_NIX = vim.fn.has("unix") == 1 } }
  _G.stl = {
    env = stl.env,
    filetype = require("stl.filetype"),
    icon = require("stl.icon"),
    e = require("stl.e"),
    nvim = { fn = require("stl.nvim.fn") },
    dict = { en = {} },
    reporter = {
      error = function(report)
        error(vim.inspect(report))
      end,
      warn = function(report)
        error(vim.inspect(report))
      end,
    },
  }
  _G.dot = {
    path = {
      cwd = function()
        return assert(vim.uv.cwd())
      end,
      join = function(a, b)
        return yoz.path.join(a, b, true, "/")
      end,
      resolve = function(a, b)
        return yoz.path.resolve(a, b, false, "/")
      end,
      dirname = function(path)
        return yoz.path.dirname(path, false, "/")
      end,
      relative = function(a, b)
        return yoz.path.relative(a, b, false, "/")
      end,
    },
    tab = {
      resolve = function()
        local buffers = {}
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          buffers[#buffers + 1] = { bufnr = bufnr }
        end
        return { bufs = buffers }
      end,
    },
    var = {
      zindex = { POPUPMENU = 1200 },
      N_WINLINE_DISABLED = "dot_winline_disabled",
    },
    context = {
      frecency = {
        completions = yoz.completion.new_history(),
      },
    },
  }
  _G.era = { m = { plugin = { load = function() end } } }
end

---@param line                          string
---@param col                           ?integer
---@param row                           ?integer
---@return era.keystroke.cmp.IContext
function M.context(line, col, row)
  col = col or #line
  row = row or 0
  local start_col = require("era.keystroke.cmp.context").start_col(line, col)
  return {
    bufnr = vim.api.nvim_get_current_buf(),
    winnr = vim.api.nvim_get_current_win(),
    row = row,
    col = col,
    line = line,
    start_col = start_col,
    keyword = line:sub(start_col + 1, col),
    filetype = "lua",
    changedtick = vim.api.nvim_buf_get_changedtick(0),
    modified = vim.api.nvim_get_option_value("modified", { buf = vim.api.nvim_get_current_buf() }),
    trigger = "typing",
    buffer_version = 0,
  }
end

return M
