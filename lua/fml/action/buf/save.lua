local __module_name__ = "fml.action.buf.save" ---@type string

---@class fml.action.buf
local M = {}

---@return nil
function M.save()
  local cwd = std.path.cwd() ---@type string
  local workspace = std.path.workspace() ---@type string

  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local bufnrs_modified = {} ---@type integer[]
  local bufnrs_new_file = {} ---@type integer[]

  for _, bufnr in ipairs(bufnrs) do
    if vim.bo[bufnr].modified and vim.bo[bufnr].buftype == "" then
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      if #filepath > 0 and std.path.is_absolute(filepath) then
        table.insert(bufnrs_modified, bufnr)

        if not eve.fs.is_exists(filepath) then
          table.insert(bufnrs_new_file, bufnr)
        end
      end
    end
  end

  local count_modified = #bufnrs_modified ---@type integer
  local count_new_file = #bufnrs_new_file ---@type integer
  local count_ready = 0 ---@type integer

  if count_modified < 1 then
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) or eve.win.pick_sourcefile() ---@type integer|nil
  if winnr_sourcefile == nil then
    std.reporter.error({
      from = __module_name__,
      subject = "save",
      message = "Cannot find a valid sourcefile winnr",
    })
    return
  end

  ---@return nil
  local function check()
    if count_ready == count_new_file then
      for _, bufnr in ipairs(bufnrs_modified) do
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd.write()
          end)
        end
      end

      local winnrs = vim.api.nvim_list_wins() ---@type integer[]
      for _, winnr in ipairs(winnrs) do
        eve.status.dirty_winline_nr:next(winnr)
      end
      eve.status.dirtier_statusline:mark_dirty()
      eve.status.dirtier_tabline:mark_dirty()
    end
  end

  for _, bufnr in ipairs(bufnrs_new_file) do
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local initial_text = std.path.is_under(workspace, filepath) and std.path.relative(cwd, filepath, true) or filepath ---@type string
    vim.api.nvim_win_set_buf(winnr_sourcefile, bufnr)

    vim.ui.input({
      relative = "editor",
      prompt = "Save file as",
      default = initial_text,
    }, function(text)
      if text == nil then
        return
      end

      local next_filepath = std.path.resolve(cwd, text) ---@type string

      ---@return nil
      local on_save = function()
        vim.api.nvim_buf_set_name(bufnr, next_filepath)

        count_ready = count_ready + 1
        check()
      end

      if std.path.is_exist_filepath(next_filepath) then
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

      if std.path.is_exist_dirpath(next_filepath) then
        std.reporter.error({
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

        count_ready = count_ready + 1
        check()
        return false
      end

      vim.schedule(on_save)
      return true
    end)
  end

  check()
end

return M
