local __module_name__ = "fml.action.lint" ---@type string

---@return string|nil
local function word_under_cursor()
  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local cursor_index = col + 1 ---@type integer

  for start_index, segment in line:gmatch("()([%a]+)") do
    local end_index = start_index + #segment - 1 ---@type integer
    if cursor_index >= start_index and cursor_index <= end_index then
      if segment:match("^[A-Za-z][a-z]*$") then
        return segment:lower()
      end
      break
    end
  end

  return nil
end

---@class fml.action.lint
local M = {}

---@return string|nil
function M.word_under_cursor()
  return word_under_cursor()
end

---@param bufnr                          integer
---@param lnum                           integer
---@return boolean
function M.has_cspell_diagnostic(bufnr, lnum)
  for _, diagnostic in ipairs(vim.diagnostic.get(bufnr, { lnum = lnum })) do
    if diagnostic.source == "cspell" then
      return true
    end
  end
  return false
end

---@return nil
function M.spellcheck_register()
  local word = word_under_cursor()
  if word == nil then
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
      message = string.format("Created cspell.json file with word(s): %s.", word),
    })
    return
  end

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

  local key = string.lower(word) ---@type string
  local existing = {} ---@type table<string, boolean>
  for _, item in ipairs(data.words) do
    if type(item) == "string" then
      existing[string.lower(item)] = true
    end
  end

  if existing[key] then
    return
  end

  table.insert(data.words, word)
  table.sort(data.words)
  std.fs.write_json(filepath, data, true)
  std.reporter.info({
    from = __module_name__,
    subject = "spellcheck_register",
    message = string.format("Added word(s) (%s) to cspell.json file.", word),
  })
end

return M
