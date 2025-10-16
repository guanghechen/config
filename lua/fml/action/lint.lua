local __module_name__ = "fml.action.lint" ---@type string

---@return string[]
local function collect_candidate_words()
  local words = {} ---@type string[]
  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local cursor_index = col + 1 ---@type integer

  for start_index, segment in line:gmatch("()([%a]+)") do
    local end_index = start_index + #segment - 1 ---@type integer
    if cursor_index >= start_index and cursor_index <= end_index then
      if segment:match("^[A-Za-z][a-z]*$") then
        words[1] = segment:lower()
      end
      break
    end
  end

  return words
end

---@class fml.action.lint
local M = {}

---@return nil
function M.spellcheck_register()
  local words = collect_candidate_words()
  if vim.tbl_isempty(words) then
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
      words = vim.list_extend({}, words),
    }
    std.fs.write_json(filepath, data, true)
    std.reporter.info({
      from = __module_name__,
      subject = "spellcheck_register",
      message = string.format("Created cspell.json file with word(s): %s.", table.concat(words, ", ")),
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

    local added = {} ---@type string[]
    local existing = {} ---@type table<string, boolean>
    for _, item in ipairs(data.words) do
      if type(item) == "string" then
        existing[item] = true
      end
    end

    for _, candidate in ipairs(words) do
      if not existing[candidate] then
        table.insert(data.words, candidate)
        existing[candidate] = true
        table.insert(added, candidate)
      end
    end

    if vim.tbl_isempty(added) then
      return
    end

    table.sort(data.words)
    std.fs.write_json(filepath, data, true)
    std.reporter.info({
      from = __module_name__,
      subject = "spellcheck_register",
      message = string.format("Added word(s) (%s) to cspell.json file.", table.concat(added, ", ")),
    })
    return
  end
end

return M
