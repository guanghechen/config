local __module_name__ = "fml.action.copy" ---@type string

---@param candidate                     eve.builtin.command.definitions.copy.Scope
---@param filepath                      string
---@return nil
local function copy_current_filepath(candidate, filepath)
  if candidate == "absolute" then
    local content = filepath ---@type string

    vim.fn.setreg("+", content)
    eve.reporter.info({
      from = __module_name__,
      message = "Copied current buffer filepath (absolute) to system clipboard!",
    })
  elseif candidate == "relative" then
    local cwd = eve.path.cwd() ---@type string
    local content = eve.path.relative(cwd, filepath, true) ---@type string

    vim.fn.setreg("+", content)
    eve.reporter.info({
      from = __module_name__,
      message = "Copied current buffer filepath (relative) to system clipboard!",
    })
  elseif candidate == "filename" then
    local content = eve.path.basename(filepath) ---@type string

    vim.fn.setreg("+", content)
    eve.reporter.info({
      from = __module_name__,
      message = "Copied current buffer filename to system clipboard!",
    })
  else
    eve.reporter.error({
      from = __module_name__,
      message = "Failed to copy current filepath, unknown candidate!",
      details = { candidate = candidate },
    })
  end
end

---@class fml.action.copy
local M = {}

---@return nil
function M.copy_char_under_cursor()
  local col = vim.fn.col(".")
  local char = vim.fn.getline("."):sub(col, col)
  vim.fn.setreg("+", char)
end

---@param arg                           unknown|nil
---@return nil
function M.copy_filepath(arg)
  local bufnr_sourcefile = eve.state.editor.get_bufnr_sourcefile() ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  local scopes = eve.command.definitions.copy.filepath.candidates
  local scope = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.list_contains(scopes, scope) then
    copy_current_filepath(scope, filepath)
  else
    eve.ux.fn.select({
      title = "Copy current filepath",
      flag_fuzzy = true,
      flag_regex = false,
      input = eve.std.Observable.from_value(scope),
      dimension = {
        row = 5,
        width = 50,
      },
      multiple = false,
      get_cursor = function()
        return "relative"
      end,
      fetch_items = function()
        local items = {} ---@type eve.ux.select.IItem[]
        for _, candidate in ipairs(scopes) do
          table.insert(items, { uuid = candidate, text = candidate })
        end
        return items
      end,
      on_confirm = function(widget, items)
        if #items == 1 then
          widget:hide()
          local item = items[1] ---@type eve.ux.select.IItem
          local candidate = item.uuid ---@type string
          copy_current_filepath(candidate, filepath)
        end
      end,
    })
  end
end

---@return nil
function M.copy_filepath_absolute()
  local bufnr_sourcefile = eve.state.editor.get_bufnr_sourcefile() ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  copy_current_filepath("absolute", filepath)
end

---@return nil
function M.copy_filepath_relative()
  local bufnr_sourcefile = eve.state.editor.get_bufnr_sourcefile() ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  copy_current_filepath("relative", filepath)
end

---@return nil
function M.copy_filepath_filename()
  local bufnr_sourcefile = eve.state.editor.get_bufnr_sourcefile() ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  copy_current_filepath("filename", filepath)
end

return M
