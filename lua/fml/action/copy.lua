local __module_name__ = "fml.action.copy" ---@type string

---@param candidate                     dot.command.definitions.copy.Scope
---@param filepath                      string
---@return nil
local function copy_current_filepath(candidate, filepath)
  if candidate == "absolute" then
    local content = filepath ---@type string

    ark.vim.fn.copy(content)
    ark.reporter.info({
      from = __module_name__,
      message = "Copied current buffer filepath (absolute) to system clipboard!",
    })
  elseif candidate == "relative" then
    local cwd = dot.path.cwd() ---@type string
    local content = dot.path.relative(cwd, filepath, "/") ---@type string

    ark.vim.fn.copy(content)
    ark.reporter.info({
      from = __module_name__,
      message = "Copied current buffer filepath (relative) to system clipboard!",
    })
  elseif candidate == "filename" then
    local content = yoz.path.basename(filepath) ---@type string

    ark.vim.fn.copy(content)
    ark.reporter.info({
      from = __module_name__,
      message = "Copied current buffer filename to system clipboard!",
    })
  else
    ark.reporter.error({
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
  ark.vim.fn.copy(char)
end

---@param arg                           unknown|nil
---@return nil
function M.copy_filepath(arg)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = dot.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  local scopes = dot.command.definitions.copy.filepath.candidates ---@type string[]|nil
  local scope = type(arg) == "string" and arg:lower() or "" ---@type string
  if scopes and vim.list_contains(scopes, scope) then
    copy_current_filepath(scope, filepath)
  elseif scopes then
    vim.ui.select(scopes, {
      name = __module_name__,
      prompt = "Copy Filepath",
      uuid_current = "relative",
      dimension = {
        row = 3,
        width = 20,
      },
    }, function(choice)
      if choice then
        copy_current_filepath(choice, filepath)
      end
    end)
  end
end

---@return nil
function M.copy_filepath_absolute()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = dot.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  copy_current_filepath("absolute", filepath)
end

---@return nil
function M.copy_filepath_relative()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = dot.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  copy_current_filepath("relative", filepath)
end

---@return nil
function M.copy_filepath_filename()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = dot.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  copy_current_filepath("filename", filepath)
end

return M
