local __module_name__ = "fml.action.buf.save" ---@type string

---@class fml.action.buf
local M = {}

---@param args                          string|nil
---@return nil
function M.save(args)
  local noformat = args == "noformat" ---@type boolean
  local cwd = dot.path.cwd() ---@type string
  local workspace = dot.path.workspace() ---@type string

  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local bufnrs_modified = {} ---@type integer[]
  local bufnrs_new_file = {} ---@type integer[]

  for _, bufnr in ipairs(bufnrs) do
    if vim.bo[bufnr].modified and vim.bo[bufnr].buftype == "" then
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      if #filepath > 0 and yoz.path.is_absolute(filepath) then
        table.insert(bufnrs_modified, bufnr)

        if not yoz.path.is_exist(filepath) then
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
  local winnr_sourcefile = era.tab.retrieve_winnr_sourcefile(tabnr) or era.win.pick_sourcefile() ---@type integer|nil
  if winnr_sourcefile == nil then
    ark.reporter.error({
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
            if noformat then
              vim.cmd("noautocmd write")
            else
              vim.cmd("write")
            end
          end)
        end
      end

      local winnrs = vim.api.nvim_list_wins() ---@type integer[]
      for _, winnr in ipairs(winnrs) do
        era.state.status.dirty_winline_nr:next(winnr)
      end
      era.state.status.dirtier_statusline:mark_dirty()
      era.state.status.dirtier_tabline:mark_dirty()
    end
  end

  for _, bufnr in ipairs(bufnrs_new_file) do
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local initial_text = yoz.path.is_descendant(workspace, filepath) and dot.path.relative(cwd, filepath, "/")
      or filepath ---@type string
    vim.api.nvim_win_set_buf(winnr_sourcefile, bufnr)

    vim.ui.input({
      relative = "editor",
      prompt = "Save file as",
      default = initial_text,
    }, function(text)
      if text == nil then
        return
      end

      local next_filepath = dot.path.resolve(cwd, text) ---@type string

      ---@return nil
      local on_save = function()
        vim.api.nvim_buf_set_name(bufnr, next_filepath)

        count_ready = count_ready + 1
        check()
      end

      if yoz.path.is_exist_file(next_filepath) then
        vim.ui.select({ "Yes", "No" }, {
          name = __module_name__,
          prompt = "The file is already existed, do you want to override it?",
        }, function(choice)
          if choice == "Yes" then
            on_save()
          end
        end)
        return false
      end

      if yoz.path.is_exist_directory(next_filepath) then
        ark.reporter.error({
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
