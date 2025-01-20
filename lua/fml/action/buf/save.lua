local __module_name__ = "fml.action.buf" ---@type string

local fs = require("eve.builtin.fs")
local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")
local editor = require("eve.module.editor")
local state = require("eve.state")

---@class fml.action.buf
local M = {}

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.save(context)
  local cwd = path.cwd() ---@type string
  local workspace = path.workspace() ---@type string

  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local new_file_bufnrs = {} ---@type integer[]

  local modified_count = 0 ---@type integer
  local new_file_count = 0 ---@type integer
  local ready_count = 0 ---@type integer

  for _, bufnr in ipairs(bufnrs) do
    local is_mod = vim.bo[bufnr].mod ---@type boolean
    if is_mod then
      modified_count = modified_count + 1

      local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local filepath = path.resolve(cwd, filename) ---@type string
      if fs.is_file_or_dir(filepath) == nil then
        new_file_count = new_file_count + 1
        table.insert(new_file_bufnrs, bufnr)
      end
    end
  end

  ---@return nil
  local function check()
    if ready_count == new_file_count then
      vim.cmd("wa")
      state.status.dirtier_statusline:mark_dirty()
      state.status.dirtier_tabline:mark_dirty()
    end
  end

  local winnr = editor.get_projectable_winnr() ---@type integer
  for _, bufnr in ipairs(new_file_bufnrs) do
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local initial_text = path.is_under(workspace, filepath) and path.relative(cwd, filepath, true) or filepath ---@type string
    vim.api.nvim_win_set_buf(winnr, bufnr)

    vim.ui.input({
      relative = "editor",
      row = 3,
      col = math.floor((vim.o.columns - 60) / 2),
      width = 60,
      prompt = "Save file as",
      default = initial_text,
    }, function(text)
      if text == nil then
        return
      end

      local next_filepath = path.resolve(cwd, text) ---@type string
      local filetype = fs.is_file_or_dir(next_filepath)

      ---@return nil
      local on_save = function()
        vim.api.nvim_buf_set_name(bufnr, next_filepath)
        state.buf.refresh(bufnr)

        ready_count = ready_count + 1
        check()
      end

      if filetype == "file" then
        vim.ui.select(
          { "Yes", "No" },
          { prompt = "The file is already existed, do you want to override it?" },
          function(choice)
            if choice == "Yes" then
              on_save()
            end
          end
        )
        return false
      end

      if filetype == "directory" then
        reporter.error({
          from = __module_name__,
          subject = "save",
          message = "Cannot save a file into a directory.",
          details = {
            bufnr = bufnr,
            text = text,
            cwd = cwd,
            workspace = workspace,
            next_filepath = next_filepath,
          },
        })

        ready_count = ready_count + 1
        check()
        return false
      end

      vim.schedule(on_save)
      return true
    end)
  end

  if modified_count > 0 then
    check()
  end
end

return M
