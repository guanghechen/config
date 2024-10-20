local constants = require("eve.std.constants")
local fs = require("eve.std.fs")
local path = require("eve.std.path")
local reporter = require("eve.std.reporter")

---@class ghc.action.buf
local M = require("ghc.action.buf.mod")

---@return nil
function M.create()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_create_buf(true, true) ---@type integer

  vim.bo[bufnr].buflisted = true
  vim.bo[bufnr].buftype = ""
  vim.bo[bufnr].filetype = "text"
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_win_set_buf(winnr, bufnr)
end

---@param filepath                      string
---@return string
function M.reload_or_load(filepath)
  local target_filepath = vim.fn.fnamemodify(filepath, ":p") ---@type string
  local target_bufnr = fml.api.buf.locate_by_filepath(filepath) ---@type integer|nil

  if target_bufnr ~= nil then
    local lines = vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false) ---@type string[]
    return table.concat(lines, "\n")
  end

  return fs.read_file({ filepath = target_filepath, silent = true }) or ""
end

---@param bufnr                         ?integer
---@return nil
function M.save(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf() ---@type integer
  local current_filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if #current_filepath < 1 or current_filepath == constants.BUF_UNTITLED then
    local cwd = path.cwd() ---@type string
    local workspace = path.workspace() ---@type string
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local initial_text = path.is_under(workspace, filepath) and path.relative(cwd, filepath, true) or filepath ---@type string
    local winnr = vim.api.nvim_get_current_win() ---@type integer

    local input ---@type t.fml.ux.IInput
    input = fml.ux.Input.new({
      position = "center",
      title = "Save file",
      min_width = 40,
      on_confirm = function(text)
        local next_filepath = path.resolve(cwd, text) ---@type string
        local filetype = fs.is_file_or_dir(next_filepath)

        ---@return nil
        local on_save = function()
          local escaped_filepath = vim.fn.fnameescape(next_filepath)
          vim.api.nvim_buf_set_name(bufnr, next_filepath)
          vim.api.nvim_win_set_buf(winnr, bufnr)
          vim.cmd("write! " .. escaped_filepath)
          vim.cmd("edit " .. escaped_filepath)
          vim.schedule(function()
            vim.cmd("redrawtabline")
          end)
          input:close()
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
            from = "fml.api.buf.create",
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
  else
    vim.cmd("wa")
  end
end
