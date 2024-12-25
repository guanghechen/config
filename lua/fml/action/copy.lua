local __module_name__ = "fml.action.copy" ---@type string

local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")
local Observable = require("eve.lib.collection.observable")
local command = require("eve.lib.command")
local select = require("fml.fn.select")

---@param candidate                     eve.lib.command.definitions.copy.Scope
---@param filepath                      string
---@return nil
local function copy_current_filepath(candidate, filepath)
  if candidate == "absolute" then
    local content = filepath ---@type string

    vim.fn.setreg("+", content)
    reporter.info({
      from = __module_name__,
      message = "Copied current buffer filepath (absolute) to system clipboard!",
    })
  elseif candidate == "relative" then
    local cwd = path.cwd() ---@type string
    local content = path.relative(cwd, filepath, true) ---@type string

    vim.fn.setreg("+", content)
    reporter.info({
      from = __module_name__,
      message = "Copied current buffer filepath (relative) to system clipboard!",
    })
  else
    reporter.error({
      from = __module_name__,
      message = "Failed to copy current filepath, unknown candidate!",
      details = { candidate = candidate },
    })
  end
end

---@class fml.action.copy
local M = {}

---@param context                       eve.lib.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.copy_char_under_cursor(context)
  local col = vim.fn.col(".")
  local char = vim.fn.getline("."):sub(col, col)
  vim.fn.setreg("+", char)
end

---@param context                       eve.lib.command.IContext
---@param arg                           unknown|nil
---@return nil
function M.copy_filepath(context, arg)
  local bufnr = context.bufnr ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local scopes = command.definitions.copy.filepath.candidates
  local scope = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.tbl_contains(scopes, scope) then
    copy_current_filepath(scope, filepath)
  else
    select({
      title = "Copy current filepath",
      flag_fuzzy = true,
      flag_regex = false,
      input = Observable.from_value(scope),
      dimension = {
        row = 5,
        width = 50,
      },
      get_present = function()
        return "relative"
      end,
      fetch_items = function()
        local items = {} ---@type fml.ux.select.IItem[]
        for _, candidate in ipairs(scopes) do
          table.insert(items, { uuid = candidate, text = candidate })
        end
        return items
      end,
      on_confirm = function(item)
        local candidate = item.uuid ---@type string
        copy_current_filepath(candidate, filepath)
      end,
    })
  end
end

---@param context                       eve.lib.command.IContext
---@return nil
function M.copy_filepath_absolute(context)
  local bufnr = context.bufnr ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  copy_current_filepath("absolute", filepath)
end

---@param context                       eve.lib.command.IContext
---@return nil
function M.copy_filepath_relative(context)
  local bufnr = context.bufnr ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  copy_current_filepath("relative", filepath)
end

return M
