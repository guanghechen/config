local __module_name__ = "fml.action.lint" ---@type string

---@class fml.action.lint.IWordContext
---@field public text                   string
---@field public normalized             string
---@field public start_col              integer
---@field public end_col                integer

---@param bufnr                         integer
---@param lnum                          integer
---@param col                           integer
---@return fml.action.lint.IWordContext|nil
local function resolve_word_context(bufnr, lnum, col)
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
  if type(line) ~= "string" then
    return nil
  end

  local cursor_index = col + 1 ---@type integer
  for start_index, segment in line:gmatch("()([%a]+)") do
    local end_index = start_index + #segment - 1 ---@type integer
    if cursor_index >= start_index and cursor_index <= end_index then
      if segment:match("^[A-Za-z][a-z]*$") then
        return {
          text = segment,
          normalized = segment:lower(),
          start_col = start_index - 1,
          end_col = end_index,
        }
      end
      break
    end
  end

  return nil
end

---@param source                        string
---@param suggestion                    string
---@return string
local function adapt_casing(source, suggestion)
  if type(suggestion) ~= "string" or #suggestion == 0 then
    return ""
  end

  if source:match("^[A-Z]+$") then
    return suggestion:upper()
  end

  if source:match("^[A-Z][a-z]*$") then
    local head = suggestion:sub(1, 1)
    local tail = suggestion:sub(2)
    return head:upper() .. tail:lower()
  end

  return suggestion
end

---@return string|nil
local function word_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local context = resolve_word_context(vim.api.nvim_get_current_buf(), cursor[1] - 1, cursor[2])
  if context ~= nil then
    return context.normalized
  end
  return nil
end

---@class fml.action.lint
local M = {}

---@return string|nil
function M.word_under_cursor()
  return word_under_cursor()
end

---@param bufnr                         integer
---@param lnum                          integer
---@param col                           integer
---@return fml.action.lint.IWordContext|nil
function M.word_context(bufnr, lnum, col)
  return resolve_word_context(bufnr, lnum, col)
end

---@param bufnr                         integer
---@param lnum                          integer
---@return boolean
function M.has_cspell_diagnostic(bufnr, lnum)
  for _, diagnostic in ipairs(vim.diagnostic.get(bufnr, { lnum = lnum })) do
    if diagnostic.source == "cspell" then
      return true
    end
  end
  return false
end

---@param bufnr                         integer
---@param lnum                          integer
---@param context                       fml.action.lint.IWordContext|nil
---@return vim.Diagnostic|nil
function M.find_cspell_diagnostic(bufnr, lnum, context)
  if context == nil then
    return nil
  end

  for _, diagnostic in ipairs(vim.diagnostic.get(bufnr, { lnum = lnum })) do
    if diagnostic.source == "cspell" then
      if type(diagnostic.message) == "string" then
        local message_word = diagnostic.message:match("%(([^)]+)%)") ---@type string|nil
        if message_word ~= nil and message_word:lower() == context.normalized then
          return diagnostic
        end
      end

      local col = diagnostic.col ---@type integer|nil
      if col ~= nil then
        local end_col = diagnostic.end_col ---@type integer|nil
        if end_col ~= nil then
          if context.start_col >= col and context.start_col < end_col then
            return diagnostic
          end
        elseif context.start_col == col then
          return diagnostic
        end
      end
    end
  end

  return nil
end

---@param diagnostic                    vim.Diagnostic|nil
---@return string[]
function M.cspell_suggestions_from_diagnostic(diagnostic)
  if diagnostic == nil or type(diagnostic.message) ~= "string" then
    return {}
  end

  local chunk = diagnostic.message:match("Suggestions:%s*%[([^%]]+)%]") ---@type string|nil
  if chunk == nil then
    return {}
  end

  return stl.string.parse_comma_list(chunk)
end

---@param context                       fml.action.lint.IWordContext|nil
---@param suggestion                    string
---@return string
function M.preview_cspell_suggestion(context, suggestion)
  if context == nil then
    return ""
  end
  return adapt_casing(context.text, suggestion)
end

---@param bufnr                         integer
---@param lnum                          integer
---@param col                           integer
---@param suggestion                    string
---@return nil
function M.apply_cspell_suggestion(bufnr, lnum, col, suggestion)
  if type(suggestion) ~= "string" or #suggestion == 0 then
    return
  end

  local context = resolve_word_context(bufnr, lnum, col)
  if context == nil then
    return
  end

  local replacement = adapt_casing(context.text, suggestion)
  if replacement == "" or replacement == context.text then
    return
  end

  vim.api.nvim_buf_set_text(bufnr, lnum, context.start_col, lnum, context.end_col, { replacement })
  vim.schedule(function()
    dot.state.status.lint_schedule_nr:next(bufnr)
  end)
  stl.reporter.info({
    from = __module_name__,
    subject = "cspell_replace",
    message = string.format('Replaced "%s" with "%s".', context.text, replacement),
  })
end

---@return nil
function M.spellcheck_register()
  local word = word_under_cursor()
  if word == nil then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  vim.schedule(function()
    dot.state.status.lint_schedule_nr:next(bufnr)
  end)

  local filepath_buf = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filepath = yoz.path.locate_nearest(filepath_buf, { ".cspell.json" })
    or dot.path.join(dot.path.workspace(), ".cspell.json")

  if not yoz.path.is_exist(filepath) then
    local data = {
      version = "0.2",
      language = "en",
      words = { word },
    }
    stl.fs.write_json(filepath, data, true)
    stl.reporter.info({
      from = __module_name__,
      subject = "spellcheck_register",
      message = string.format("Created cspell.json file with word(s): %s.", word),
    })
    return
  end

  local data = stl.fs.read_json({ filepath = filepath, silent_on_bad_json = false, silent_on_bad_path = false })
  if type(data) ~= "table" or type(data.words) ~= "table" then
    stl.reporter.error({
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
  stl.fs.write_json(filepath, data, true)
  stl.reporter.info({
    from = __module_name__,
    subject = "spellcheck_register",
    message = string.format("Added word(s) (%s) to cspell.json file.", word),
  })
end

return M
