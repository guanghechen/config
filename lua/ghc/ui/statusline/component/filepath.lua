---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "filepath",
  condition = function(context)
    return #context.filepath > 0 and context.filepath ~= "."
  end,
  pieces = {
    {
      hlname = function()
        return "f_sl_text"
      end,
      text = function(context)
        local cwd = context.cwd
        local filepath = context.filepath
        local relative_to_cwd = fml.path.relative(cwd, filepath)
        if string.sub(relative_to_cwd, 1, 1) == "." and fml.path.is_absolute(filepath) then
          local workspace = fml.path.workspace()
          if cwd ~= workspace then
            local relative_to_workspace = fml.path.relative(workspace, filepath)
            if string.sub(relative_to_workspace, 1, 1) == "." then
              relative_to_cwd = fml.path.normalize(filepath)
            end
          end
        end
        return context.fileicon .. " " .. relative_to_cwd
      end,
    },
    {
      hlname = function()
        return "f_sl_text"
      end,
      text = function()
        local texts = {} ---@type string[]
        local bufnr_status_line = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
        local buffer_status_line = vim.b[bufnr_status_line]
        if buffer_status_line and buffer_status_line.gitsigns_head and not buffer_status_line.gitsigns_git_status then
          local git_status = buffer_status_line.gitsigns_status_dict
          if git_status.added and git_status.added > 0 then
            table.insert(texts, fml.ui.icons.git.Add .. " " .. git_status.added)
          end
          if git_status.changed and git_status.changed > 0 then
            table.insert(texts, fml.ui.icons.git.Mod_alt .. " " .. git_status.changed)
          end
          if git_status.removed and git_status.removed > 0 then
            table.insert(texts, fml.ui.icons.git.Remove .. " " .. git_status.removed)
          end
        end
        return table.concat(texts, " ")
      end,
    },
  },
}

return M
