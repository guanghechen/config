---@class oxi.replacer
local M = {}

---@class oxi.replacer.show_replace_preview_in_buffer.IParams
---@field public bufnr                  integer
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean
---@field public namespace_id           integer|nil
---@field public highlight_group_search string|nil
---@field public highlight_group_replace string|nil

---@class oxi.replacer.show_replace_preview_in_buffer.IReplacementPoint
---@field public l                      integer
---@field public r                      integer
---@field public text                   string

---@class oxi.replacer.show_replace_preview_in_buffer.IResult
---@field public bufnr                  integer
---@field public error                  string|nil
---@field public preview_applied        boolean
---@field public matches_count          integer
---@field public search_matches         oxi.string.ILineMatch[]
---@field public replacement_lines      string[]
---@field public replacement_matches    oxi.replacer.show_replace_preview_in_buffer.IReplacementPoint[]

---@param params                        oxi.replacer.show_replace_preview_in_buffer.IParams
---@return oxi.replacer.show_replace_preview_in_buffer.IResult|nil
function M.show_replace_preview_in_buffer(params)
  local ok, result = oxi.fn.safe_call("show_replace_preview_in_buffer", {
    bufnr = params.bufnr,
    search_pattern = params.search_pattern,
    replace_pattern = params.replace_pattern,
    flag_fuzzy = params.flag_fuzzy,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
    namespace_id = params.namespace_id,
    highlight_group_search = params.highlight_group_search,
    highlight_group_replace = params.highlight_group_replace,
  })
  if not ok then return nil end
  return result
end

---@class oxi.replacer.replace_current_match_in_buffer.IParams
---@field public bufnr                  integer
---@field public current_match_index    integer
---@field public matches                oxi.string.ILineMatch[]
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@class oxi.replacer.replace_current_match_in_buffer.IResult
---@field public success                boolean

---@param params                        oxi.replacer.replace_current_match_in_buffer.IParams
---@return oxi.replacer.replace_current_match_in_buffer.IResult|nil
function M.replace_current_match_in_buffer(params)
  local ok, result = oxi.fn.safe_call("replace_current_match_in_buffer", {
    bufnr = params.bufnr,
    current_match_index = params.current_match_index,
    matches = params.matches,
    search_pattern = params.search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
  })
  if not ok then return nil end
  return result
end

---@class oxi.replacer.replace_all_matches_in_buffer.IParams
---@field public bufnr                  integer
---@field public matches                oxi.string.ILineMatch[]
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@class oxi.replacer.replace_all_matches_in_buffer.IResult
---@field public success                boolean
---@field public replaced_count         integer

---@param params                        oxi.replacer.replace_all_matches_in_buffer.IParams
---@return oxi.replacer.replace_all_matches_in_buffer.IResult|nil
function M.replace_all_matches_in_buffer(params)
  local ok, result = oxi.fn.safe_call("replace_all_matches_in_buffer", {
    bufnr = params.bufnr,
    matches = params.matches,
    search_pattern = params.search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
  })
  if not ok then return nil end
  return result
end

return M
