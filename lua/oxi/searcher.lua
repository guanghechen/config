local __module_name__ = "oxi.searcher" ---@type string

---@class oxi.searcher
local M = {}

---@class oxi.searcher.ISearchInLinesParams
---@field public pattern                string
---@field public lines                  string[]
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@param params                        oxi.searcher.ISearchInLinesParams
---@return oxi.string.ILineMatch[]|nil
function M.search_in_lines(params)
  local ok, result, err = pcall(rstd.search.search_in_lines, {
    pattern = params.pattern,
    lines = params.lines,
    flag_fuzzy = params.flag_fuzzy,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
  })

  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = "search_in_lines failed",
      details = {
        error = result,
        params = params,
      },
    })
    return nil
  end

  if err then
    std.reporter.error({
      from = __module_name__,
      subject = "search_in_lines failed",
      details = {
        error = err,
        params = params,
      },
    })
    return nil
  end

  return result
end

---@class oxi.searcher.ISearchInTextParams
---@field public pattern                string
---@field public text                   string
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@param params                        oxi.searcher.ISearchInTextParams
---@return oxi.string.ILineMatch[]|nil
function M.search_in_text(params)
  local ok, result, err = pcall(rstd.search.search_in_text, {
    pattern = params.pattern,
    text = params.text,
    flag_fuzzy = params.flag_fuzzy,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
  })

  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = "search_in_text failed",
      details = {
        error = result,
        params = params,
      },
    })
    return nil
  end

  if err then
    std.reporter.error({
      from = __module_name__,
      subject = "search_in_text failed",
      details = {
        error = err,
        params = params,
      },
    })
    return nil
  end

  return result
end

---@class oxi.searcher.ISearchInBufferParams
---@field public bufnr                  integer
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean
---@field public flag_replace           boolean
---@field public search_pattern         string

---@param params                        oxi.searcher.ISearchInBufferParams
---@return oxi.string.ILineMatch[]|nil
function M.search_in_buffer(params)
  local ok, result = oxi.fn.safe_call("search_in_buffer", {
    bufnr = params.bufnr,
    search_pattern = params.search_pattern,
    flag_fuzzy = params.flag_fuzzy,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
  })
  if not ok then return nil end
  return result
end

return M
