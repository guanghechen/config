local __module_name__ = "fml.action.lint" ---@type string

---@return string|nil
local function get_strict_word_under_cursor()
  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()

  local start_col = col
  local end_col = col

  while start_col > 0 and string.sub(line, start_col, start_col):match("[%w]") do
    start_col = start_col - 1
  end
  if not string.sub(line, start_col, start_col):match("[%w]") then
    start_col = start_col + 1
  end

  while end_col <= #line and string.sub(line, end_col + 1, end_col + 1):match("[%w]") do
    end_col = end_col + 1
  end

  local word = string.sub(line, start_col, end_col)
  return word:match("^[a-zA-Z0-9]+$") and word:lower() or nil
end

---@class fml.action.lint
local M = {}

---@return nil
function M.spellcheck_register()
  local word = get_strict_word_under_cursor() ---@type string|nil
  if word == nil or #word < 1 then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  vim.schedule(function()
    eve.status.lint_schedule_nr:next(bufnr)
  end)

  local filepath_buf = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filepath = std.path.locate_nearest_filepath(filepath_buf, { ".cspell.json" })
    or std.path.join(std.path.workspace(), ".cspell.json")

  if not std.path.is_exist(filepath) then
    local data = {
      version = "0.2",
      language = "en",
      words = { word },
    }
    std.fs.write_json(filepath, data, true)
    std.reporter.info({
      from = __module_name__,
      subject = "spellcheck_register",
      message = "Created cspell.json file.",
    })
    return
  else
    local data = std.fs.read_json({ filepath = filepath, silent_on_bad_json = false, silent_on_bad_path = false })
    if type(data) ~= "table" or type(data.words) ~= "table" then
      std.reporter.error({
        from = __module_name__,
        subject = "spellcheck_register",
        message = "Bad cspell.json format, missing the `words` field.",
        details = { filepath = filepath, data = data },
      })
      return
    end

    if vim.list_contains(data.words, word) then
      return
    end

    table.insert(data.words, word)
    table.sort(data.words)
    std.fs.write_json(filepath, data, true)
    std.reporter.info({
      from = __module_name__,
      subject = "spellcheck_register",
      message = string.format("Added word (%s) to cspell.json file.", word),
    })
    return
  end
end

return M
