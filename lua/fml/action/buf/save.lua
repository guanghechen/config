local __module_name__ = "fml.action.buf" ---@type string

local fs = require("eve.lib.fs")
local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")
local state = require("eve.state")
local Input = require("fml.ux.input")

---@class fml.action.buf
local M = {}

---@return nil
function M.save()
  local cwd = path.cwd() ---@type string
  local workspace = path.workspace() ---@type string

  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local new_file_bufnrs = {} ---@type integer[]

  local modified_count = 0 ---@type integer
  local new_file_count = 0 ---@type integer
  local ready_count = 0 ---@type integer

  for _, bufnr in ipairs(bufnrs) do
    local is_mod = vim.api.nvim_get_option_value("mod", { buf = bufnr }) ---@type boolean
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

  for _, bufnr in ipairs(new_file_bufnrs) do
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local initial_text = path.is_under(workspace, filepath) and path.relative(cwd, filepath, true) or filepath ---@type string

    local input ---@type fml.ux.IInput
    input = Input.new({
      position = "center",
      title = "Save file",
      min_width = 40,
      on_confirm = function(text)
        local next_filepath = path.resolve(cwd, text) ---@type string
        local filetype = fs.is_file_or_dir(next_filepath)

        ---@return nil
        local on_save = function()
          vim.api.nvim_buf_set_name(bufnr, next_filepath)
          state.buf.refresh(bufnr)

          input:close()

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
      end,
    })
    input:open({
      initial_value = initial_text,
      row = 3,
      text_cursor_col = string.len(initial_text),
    })
  end

  if modified_count > 0 then
    check()
  end
end

return M
