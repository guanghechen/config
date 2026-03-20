---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.fn.run_code_as_neovim_command" ---@type string

---@return nil
local function run_code_as_neovim_command()
  local selected = stl.nvim.buf.retrieve_selected_text() ---@type string
  if selected == "" then
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
    selected = table.concat(lines, "\n")
  end

  if selected:match("^%s*$") then
    return
  end

  local ok, err = pcall(function()
    vim.api.nvim_command(selected)
  end)

  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "run_code_as_neovim_command",
      message = err,
    })
  end
end

return run_code_as_neovim_command
