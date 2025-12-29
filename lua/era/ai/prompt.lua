---@class era.ai.prompt.ICtx
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public cwd                    string
---@field public filepath               string|nil
---@field public filetype               string|nil
---@field public selection_range        ?{ start_lnum: integer, start_col: integer, end_lnum: integer, end_col: integer }

---@class era.ai.prompt
local M = {}

local SEVERITY_NAMES = { "ERROR", "WARN", "INFO", "HINT" }
local SEVERITY_HL = {
  "DiagnosticError",
  "DiagnosticWarn",
  "DiagnosticInfo",
  "DiagnosticHint",
}

----------------------------------------------------------------------------------------------------
--- Text utilities
----------------------------------------------------------------------------------------------------

---@param lines                         era.ai.IText
---@return string
local function text_to_string(lines)
  local result = {} ---@type string[]
  for _, line in ipairs(lines) do
    local parts = {} ---@type string[]
    for _, chunk in ipairs(line) do
      parts[#parts + 1] = chunk[1]
    end
    result[#result + 1] = table.concat(parts)
  end
  return table.concat(result, "\n")
end

---@param lines                         string[]
---@param hlname                        ?string
---@return era.ai.IText
local function plain_lines(lines, hlname)
  local result = {} ---@type era.ai.IText
  for _, line in ipairs(lines) do
    result[#result + 1] = { { line, hlname } }
  end
  return result
end

---@param bufnr                         integer
---@param start_row                     integer 0-indexed
---@param end_row                       integer 0-indexed, exclusive
---@return era.ai.IText
local function get_highlighted_lines(bufnr, start_row, end_row)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)
  local ft = vim.bo[bufnr].filetype
  local lang = ft and vim.treesitter.language.get_lang(ft) or nil

  if not lang then
    return plain_lines(lines)
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or not parser then
    return plain_lines(lines)
  end

  local extmarks = {} ---@type table<integer, table<integer, string>>
  pcall(function()
    parser:parse(true)
    parser:for_each_tree(function(tstree, tree)
      if not tstree then
        return
      end
      local query = vim.treesitter.query.get(tree:lang(), "highlights")
      if not query then
        return
      end
      for capture, node in query:iter_captures(tstree:root(), bufnr, start_row, end_row) do
        local name = query.captures[capture]
        if name ~= "spell" and name ~= "nospell" and name ~= "conceal" then
          local sr, sc, er, ec = node:range()
          for row = sr, er do
            extmarks[row] = extmarks[row] or {}
            local col_start = row == sr and sc or 0
            local col_end = row == er and ec or #(lines[row - start_row + 1] or "")
            for col = col_start, col_end - 1 do
              extmarks[row][col] = "@" .. name .. "." .. lang
            end
          end
        end
      end
    end)
  end)

  local result = {} ---@type era.ai.IText
  for i, line in ipairs(lines) do
    local row = start_row + i - 1
    local row_marks = extmarks[row] or {}
    local text_line = {} ---@type era.ai.ITextLine
    local from = 0
    local hl_group = nil ---@type string|nil

    for col = 0, #line do
      local hl = row_marks[col]
      if hl ~= hl_group or col == #line then
        if col > from then
          text_line[#text_line + 1] = { line:sub(from + 1, col), hl_group }
        end
        from = col
        hl_group = hl
      end
    end
    result[#result + 1] = text_line
  end
  return result
end

----------------------------------------------------------------------------------------------------
--- Context helpers
----------------------------------------------------------------------------------------------------

---@return era.ai.prompt.ICtx
function M.get_ctx()
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  local selection_range = nil ---@type { start_lnum: integer, start_col: integer, end_lnum: integer, end_col: integer }|nil
  local start_lnum, start_col, end_lnum, end_col = stl.nvim.buf.retrieve_visual_range()
  if start_lnum and start_col and end_lnum and end_col then
    if start_lnum ~= end_lnum or start_col ~= end_col then
      selection_range = {
        start_lnum = start_lnum,
        start_col = start_col,
        end_lnum = end_lnum,
        end_col = end_col,
      }
    end
  end

  return {
    winnr = winnr,
    bufnr = bufnr,
    cwd = dot.path.cwd(),
    filepath = filepath ~= "" and filepath or nil,
    filetype = vim.bo[bufnr].filetype,
    selection_range = selection_range,
  }
end

---@param ctx                           era.ai.prompt.ICtx
---@return era.ai.ITextLine|nil, string|nil
local function get_selection_line(ctx)
  local range = ctx.selection_range
  if not range or not ctx.filepath then
    return nil, nil
  end
  local relpath = dot.path.relative(ctx.cwd, ctx.filepath)
  local text =
    string.format("@%s L%d:C%d-L%d:C%d", relpath, range.start_lnum, range.start_col, range.end_lnum, range.end_col)
  ---@type era.ai.ITextLine
  local line = {
    { "@", "m_ai_loc_delim" },
    { relpath, "m_ai_loc_file" },
    { " ", nil },
    { "L", "m_ai_loc_row" },
    { tostring(range.start_lnum), "m_ai_loc_num" },
    { ":", "m_ai_loc_delim" },
    { "C", "m_ai_loc_col" },
    { tostring(range.start_col), "m_ai_loc_num" },
    { "-", "m_ai_loc_delim" },
    { "L", "m_ai_loc_row" },
    { tostring(range.end_lnum), "m_ai_loc_num" },
    { ":", "m_ai_loc_delim" },
    { "C", "m_ai_loc_col" },
    { tostring(range.end_col), "m_ai_loc_num" },
  }
  return line, text
end

---@param ctx                           era.ai.prompt.ICtx
---@return era.ai.ITextLine|nil, string|nil
local function get_file_line(ctx)
  if not ctx.filepath then
    return nil, nil
  end
  local relpath = dot.path.relative(ctx.cwd, ctx.filepath)
  local text = string.format("@%s", relpath)
  ---@type era.ai.ITextLine
  local line = {
    { "@", "m_ai_loc_delim" },
    { relpath, "m_ai_loc_file" },
  }
  return line, text
end

---@param ctx                           era.ai.prompt.ICtx
---@return era.ai.ITextLine|nil, string|nil
local function get_target_line(ctx)
  local line, text = get_selection_line(ctx)
  if line then
    return line, text
  end
  return get_file_line(ctx)
end

---@param ctx                           era.ai.prompt.ICtx
---@return era.ai.IText|nil, string|nil
local function get_selection_content(ctx)
  local range = ctx.selection_range
  if not range then
    return nil, nil
  end
  local lines = get_highlighted_lines(ctx.bufnr, range.start_lnum - 1, range.end_lnum)
  local text = text_to_string(lines)
  return lines, text
end

---@param ctx                           era.ai.prompt.ICtx
---@return era.ai.IText|nil, string|nil
local function get_diagnostics_lines(ctx)
  if not ctx.bufnr or not vim.api.nvim_buf_is_valid(ctx.bufnr) then
    return nil, nil
  end
  local diagnostics = vim.diagnostic.get(ctx.bufnr)
  if #diagnostics == 0 then
    return nil, nil
  end
  local lines = {} ---@type era.ai.IText
  local text_lines = {} ---@type string[]
  for _, d in ipairs(diagnostics) do
    local severity_name = SEVERITY_NAMES[d.severity] or "UNKNOWN"
    local severity_hl = SEVERITY_HL[d.severity] or "Comment"
    local text = string.format("[%s] Line %d: %s", severity_name, d.lnum + 1, d.message)
    text_lines[#text_lines + 1] = text
    lines[#lines + 1] = {
      { "[", "Comment" },
      { severity_name, severity_hl },
      { "] Line ", "Comment" },
      { tostring(d.lnum + 1), "Number" },
      { ": ", "Comment" },
      { d.message, nil },
    }
  end
  return lines, table.concat(text_lines, "\n")
end

---@param ctx                           era.ai.prompt.ICtx
---@return era.ai.IText|nil, string|nil
local function get_diagnostics_all_lines(ctx)
  local lines = {} ---@type era.ai.IText
  local text_lines = {} ---@type string[]
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      if filepath ~= "" then
        local relpath = dot.path.relative(ctx.cwd, filepath)
        for _, d in ipairs(vim.diagnostic.get(bufnr)) do
          local severity_name = SEVERITY_NAMES[d.severity] or "UNKNOWN"
          local severity_hl = SEVERITY_HL[d.severity] or "Comment"
          local text = string.format("%s:%d [%s]: %s", relpath, d.lnum + 1, severity_name, d.message)
          text_lines[#text_lines + 1] = text
          lines[#lines + 1] = {
            { relpath, "m_ai_loc_file" },
            { ":", "m_ai_loc_delim" },
            { tostring(d.lnum + 1), "m_ai_loc_num" },
            { " [", "Comment" },
            { severity_name, severity_hl },
            { "]: ", "Comment" },
            { d.message, nil },
          }
        end
      end
    end
  end
  return #lines > 0 and lines or nil, #text_lines > 0 and table.concat(text_lines, "\n") or nil
end

----------------------------------------------------------------------------------------------------
--- Prompts
----------------------------------------------------------------------------------------------------

---@type era.ai.IPrompt[]
M.list = {
  {
    name = "diagnostics",
    submit = true,
    render = function(ctx)
      local file_line, file_text = get_file_line(ctx)
      local diag_lines, diag_text = get_diagnostics_lines(ctx)
      if not file_line or not diag_lines then
        return nil
      end
      local lines = {} ---@type era.ai.IText
      lines[#lines + 1] = vim.list_extend({ { "Fix the diagnostics in ", "m_ai_prompt_header" } }, file_line)
      table.insert(lines[#lines], { ":", "m_ai_prompt_header" })
      vim.list_extend(lines, diag_lines)
      return { text = "Fix the diagnostics in " .. file_text .. ":\n" .. diag_text, lines = lines }
    end,
  },
  {
    name = "diagnostics_all",
    submit = true,
    render = function(ctx)
      local diag_lines, diag_text = get_diagnostics_all_lines(ctx)
      if not diag_lines then
        return nil
      end
      local lines = {} ---@type era.ai.IText
      lines[#lines + 1] = { { "Fix these diagnostics:", "m_ai_prompt_header" } }
      vim.list_extend(lines, diag_lines)
      return { text = "Fix these diagnostics:\n" .. diag_text, lines = lines }
    end,
  },
  {
    name = "fix",
    submit = true,
    render = function(ctx)
      local target_line, target_text = get_target_line(ctx)
      if not target_line then
        return nil
      end
      local lines = {} ---@type era.ai.IText
      lines[#lines + 1] = vim.list_extend({ { "Fix this code: ", "m_ai_prompt_header" } }, target_line)
      local content_lines = get_selection_content(ctx)
      if content_lines then
        vim.list_extend(lines, content_lines)
      end
      return { text = "Fix this code: " .. target_text, lines = lines }
    end,
  },
  {
    name = "optimize",
    submit = true,
    render = function(ctx)
      local target_line, target_text = get_target_line(ctx)
      if not target_line then
        return nil
      end
      local lines = {} ---@type era.ai.IText
      lines[#lines + 1] = vim.list_extend({ { "Optimize this code: ", "m_ai_prompt_header" } }, target_line)
      local content_lines = get_selection_content(ctx)
      if content_lines then
        vim.list_extend(lines, content_lines)
      end
      return { text = "Optimize this code: " .. target_text, lines = lines }
    end,
  },
  {
    name = "refactor",
    submit = true,
    render = function(ctx)
      local target_line, target_text = get_target_line(ctx)
      if not target_line then
        return nil
      end
      local lines = {} ---@type era.ai.IText
      lines[#lines + 1] = vim.list_extend({ { "Refactor this code: ", "m_ai_prompt_header" } }, target_line)
      local content_lines = get_selection_content(ctx)
      if content_lines then
        vim.list_extend(lines, content_lines)
      end
      return { text = "Refactor this code: " .. target_text, lines = lines }
    end,
  },
  {
    name = "review",
    submit = true,
    render = function(ctx)
      local target_line, target_text = get_target_line(ctx)
      if not target_line then
        return nil
      end
      local lines = {} ---@type era.ai.IText
      lines[#lines + 1] = vim.list_extend({ { "Review this code: ", "m_ai_prompt_header" } }, target_line)
      local content_lines = get_selection_content(ctx)
      if content_lines then
        vim.list_extend(lines, content_lines)
      end
      return { text = "Review this code: " .. target_text, lines = lines }
    end,
  },
}

return M
