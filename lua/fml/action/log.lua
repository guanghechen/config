local M = {}

---@param content                          string
---@return string|nil
local function extract_json_content(content)
  local trimmed = content:match("^%s*(.-)%s*$")
  if not trimmed or #trimmed == 0 then
    return nil
  end

  local start_pos = trimmed:find("{")
  if not start_pos then
    return nil
  end

  local json_content = trimmed:sub(start_pos)
  if not json_content or #json_content == 0 then
    return nil
  end

  return json_content
end

---@param content                          string
---@return nil
local function show_json_preview(content)
  local json = extract_json_content(content)
  if not json then
    vim.notify("No JSON content found in the selection", vim.log.levels.WARN)
    return
  end

  if not json then
    vim.notify("Failed to format JSON content", vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(json, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = "json"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].readonly = false

  -- Trigger LSP and TreeSitter attachment
  vim.schedule(function()
    vim.api.nvim_exec_autocmds("FileType", { buffer = bufnr })
    vim.api.nvim_exec_autocmds("BufRead", { buffer = bufnr })
  end)

  local editor_width = vim.o.columns
  local editor_height = vim.o.lines
  local width = math.floor(editor_width * 0.9)
  local height = math.floor(editor_height * 0.9)
  local row = math.floor((editor_height - height) / 2) - 1
  local col = math.floor((editor_width - width) / 2)

  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    style = "minimal",
    title = "JSON Preview",
    title_pos = "center",
    noautocmd = true,
  })

  vim.wo[winnr].wrap = true
  vim.wo[winnr].number = true
  vim.wo[winnr].relativenumber = true
  vim.wo[winnr].signcolumn = "yes"
  vim.wo[winnr].spell = false
  vim.wo[winnr].cursorline = true

  local keymaps = {
    {
      "n",
      "q",
      function()
        vim.api.nvim_win_close(winnr, true)
      end,
      { desc = "Close JSON preview" },
    },
    {
      "n",
      "<Esc>",
      function()
        vim.api.nvim_win_close(winnr, true)
      end,
      { desc = "Close JSON preview" },
    },
  }

  for _, keymap in ipairs(keymaps) do
    vim.keymap.set(keymap[1], keymap[2], keymap[3], vim.tbl_extend("force", keymap[4] or {}, { buffer = bufnr }))
  end

  -- Format the JSON content using conform.nvim
  require("conform").format({
    bufnr = bufnr,
    write = false,
    async = true,
  })
end

---@return nil
function M.preview_json_normal()
  local line = vim.api.nvim_get_current_line()
  show_json_preview(line)
end

---@return nil
function M.preview_json_visual()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local s_lnum, s_col, e_lnum, e_col = eve.buf.retrieve_visual_range()

  local lines ---@type string[]
  if s_lnum == e_lnum then
    lines = vim.api.nvim_buf_get_text(bufnr, s_lnum - 1, s_col - 1, e_lnum - 1, e_col, {})
  else
    lines = vim.api.nvim_buf_get_lines(bufnr, s_lnum - 1, e_lnum, false)
    if #lines > 0 then
      lines[1] = lines[1]:sub(s_col)
    end
    if #lines > 0 then
      lines[#lines] = lines[#lines]:sub(1, e_col)
    end
  end

  local content = table.concat(lines, "\n")
  show_json_preview(content)
end

return M
