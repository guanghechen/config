---@class oxi.replacer
local M = {}

---@class oxi.replacer.replace_file.IParams
---@field public cwd                    string
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public replace_pattern        string

---@class oxi.replacer.replace_file_by_matches.IParams
---@field public cwd                    string
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public match_offsets          integer[]

---@class oxi.replacer.replace_file_by_matches_advance.IParams
---@field public cwd                    string
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public match_offsets          integer[]
---@field public remain_offsets         integer[]

---@class oxi.replacer.replace_file_preview.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public filepath               string

---@class oxi.replacer.replace_file_preview_advance.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public filepath               string

---@class oxi.replacer.replace_file_preview_by_matches_advance.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public filepath               string
---@field public match_offsets          integer[]

---@class oxi.replacer.replace_text_preview.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string

---@class oxi.replacer.replace_text_preview_by_matches.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string
---@field public match_offsets          integer[]

---@class oxi.replacer.replace_text_preview_advance.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string

---@class oxi.replacer.replace_text_preview_by_matches_advance.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string
---@field public match_offsets          integer[]

----------------------------------------------------------------------------------------------------

---@class oxi.replacer.replace_file_preview.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]

---@class oxi.replacer.replace_file_preview_advance.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                std.t.IMatchPoint[]

---@class oxi.replacer.replace_file_preview_by_matches_advance.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                std.t.IMatchPoint[]

---@class oxi.replacer.replace_text_preview.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]

---@class oxi.replacer.replace_text_preview_by_matches.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]

---@class oxi.replacer.replace_text_preview_advance.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                std.t.IMatchPoint[]

---@class oxi.replacer.replace_text_preview_by_matches_advance.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                std.t.IMatchPoint[]

----------------------------------------------------------------------------------------------------

---@class oxi.replacer.replace_file.IPayload
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public replace_pattern        string
---@field public search_pattern         string

---@class oxi.replacer.replace_file_by_matches.IPayload
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public match_offsets          integer[]
---@field public replace_pattern        string
---@field public search_pattern         string

---@class oxi.replacer.replace_file_by_matches_advance.IPayload
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public match_offsets          integer[]
---@field public remain_offsets         integer[]
---@field public replace_pattern        string
---@field public search_pattern         string

---@class oxi.replacer.replace_file_preview.IPayload
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public replace_pattern        string
---@field public search_pattern         string

---@class oxi.replacer.replace_file_preview_advance.IPayload
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public replace_pattern        string
---@field public search_pattern         string

---@class oxi.replacer.replace_file_preview_by_matches_advance.IPayload
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public match_offsets          integer[]
---@field public replace_pattern        string
---@field public search_pattern         string

---@class oxi.replacer.replace_text_preview.IPayload
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public replace_pattern        string
---@field public search_pattern         string
---@field public text                   string

---@class oxi.replacer.replace_text_preview_by_matches.IPayload
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public match_offsets          integer[]
---@field public replace_pattern        string
---@field public search_pattern         string
---@field public text                   string

---@class oxi.replacer.replace_text_preview_advance.IPayload
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public replace_pattern        string
---@field public search_pattern         string
---@field public text                   string

---@class oxi.replacer.replace_text_preview_by_matches_advance.IPayload
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public match_offsets          integer[]
---@field public replace_pattern        string
---@field public search_pattern         string
---@field public text                   string

----------------------------------------------------------------------------------------------------

---@class oxi.replacer.replace_file_preview_advance.IResponseData
---@field public text                   string
---@field public matches                std.t.IMatchPoint[]

---@class oxi.replacer.replace_file_preview_by_matches_advance.IResponseData
---@field public text                   string
---@field public matches                std.t.IMatchPoint[]

---@class oxi.replacer.replace_text_preview_advance.IResponseData
---@field public text                   string
---@field public matches                std.t.IMatchPoint[]

---@class oxi.replacer.replace_text_preview_by_matches_advance.IResponseData
---@field public text                   string
---@field public matches                std.t.IMatchPoint[]

---@class oxi.replacer.replace_file_by_matches_advance.IResponseData
---@field public locations              std.t.IMatchLocation[]

---@param params                        oxi.replacer.replace_file.IParams
---@return boolean
function M.replace_file(params)
  local filepath = std.path.resolve(params.cwd, params.filepath) ---@type string

  ---@type oxi.replacer.replace_file.IPayload
  local payload = {
    filepath = filepath,
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    replace_pattern = params.replace_pattern,
    search_pattern = params.search_pattern,
  }

  local _, data = oxi.fn.safe_call("replace_file", payload)
  return data == true
end

---@param params                        oxi.replacer.replace_file_by_matches.IParams
---@return boolean
---@return boolean
function M.replace_file_by_matches(params)
  local filepath = std.path.resolve(params.cwd, params.filepath) ---@type string
  local match_offsets = params.match_offsets ---@type integer[]

  ---@type oxi.replacer.replace_file_by_matches.IPayload
  local payload = {
    filepath = filepath,
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    match_offsets = match_offsets,
    replace_pattern = params.replace_pattern,
    search_pattern = params.search_pattern,
  }

  local ok, data = oxi.fn.safe_call("replace_file_by_matches", payload)
  return ok, data
end

---@param params                        oxi.replacer.replace_file_by_matches_advance.IParams
---@return boolean
---@return std.t.IMatchLocation[]
function M.replace_file_by_matches_advance(params)
  local filepath = std.path.resolve(params.cwd, params.filepath) ---@type string
  local match_offsets = params.match_offsets ---@type integer[]
  local remain_offsets = params.remain_offsets ---@type integer[]

  ---@type oxi.replacer.replace_file_by_matches_advance.IPayload
  local payload = {
    filepath = filepath,
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    match_offsets = match_offsets,
    remain_offsets = remain_offsets,
    replace_pattern = params.replace_pattern,
    search_pattern = params.search_pattern,
  }

  local ok, data = oxi.fn.safe_call("replace_file_by_matches_advance", payload)
  ---@cast data                         oxi.replacer.replace_file_by_matches_advance.IResponseData

  return ok, ok and data.locations or {}
end

---@param params                        oxi.replacer.replace_file_preview.IParams
---@return oxi.replacer.replace_file_preview.IResult
function M.replace_file_preview(params)
  ---@type oxi.replacer.replace_file_preview.IPayload
  local payload = {
    filepath = params.filepath,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
    keep_search_pieces = params.keep_search_pieces,
    search_pattern = params.search_pattern,
    replace_pattern = params.replace_pattern,
  }

  local ok, data = oxi.fn.safe_call("replace_file_preview", payload)
  if ok then
    ---@cast data                       string

    local text = data ---@type string
    local lwidths = oxi.string.calc_linewidths(text) ---@type integer[]
    local lines = oxi.string.parse_lines(text, lwidths) ---@type string[]

    ---@type oxi.replacer.replace_file_preview.IResult
    return { lines = lines, lwidths = lwidths }
  end

  ---@type oxi.replacer.replace_file_preview.IResult
  return { lines = {}, lwidths = {} }
end

---@param params                        oxi.replacer.replace_file_preview_advance.IParams
---@return oxi.replacer.replace_file_preview_advance.IResult
function M.replace_file_preview_advance(params)
  ---@type oxi.replacer.replace_file_preview_advance.IPayload
  local payload = {
    filepath = params.filepath,
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    replace_pattern = params.replace_pattern,
    search_pattern = params.search_pattern,
  }

  local ok, data = oxi.fn.safe_call("replace_file_preview_advance", payload)
  if ok then
    ---@cast data                       oxi.replacer.replace_file_preview_advance.IResponseData

    local text = data.text ---@type string
    local lwidths = oxi.string.calc_linewidths(text) ---@type integer[]
    local lines = oxi.string.parse_lines(text, lwidths) ---@type string[]

    ---@type oxi.replacer.replace_file_preview_advance.IResult
    return { lines = lines, lwidths = lwidths, matches = data.matches }
  end

  ---@type oxi.replacer.replace_file_preview_advance.IResult
  return { lines = {}, lwidths = {}, matches = {} }
end

---@param params                        oxi.replacer.replace_file_preview_by_matches_advance.IParams
---@return oxi.replacer.replace_file_preview_by_matches_advance.IResult
function M.replace_file_preview_by_matches_advance(params)
  ---@type oxi.replacer.replace_file_preview_by_matches_advance.IPayload
  local payload = {
    filepath = params.filepath,
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
    replace_pattern = params.replace_pattern,
    search_pattern = params.search_pattern,
  }

  local ok, data = oxi.fn.safe_call("replace_file_preview_by_matches_advance", payload)
  if ok then
    ---@cast data                       oxi.replacer.replace_file_preview_by_matches_advance.IResponseData

    local text = data.text ---@type string
    local lwidths = oxi.string.calc_linewidths(text) ---@type integer[]
    local lines = oxi.string.parse_lines(text, lwidths) ---@type string[]

    ---@type oxi.replacer.replace_file_preview_by_matches_advance.IResult
    return { lines = lines, lwidths = lwidths, matches = data.matches }
  end

  ---@type oxi.replacer.replace_file_preview_by_matches_advance.IResult
  return { lines = {}, lwidths = {}, matches = {} }
end

---@param params                        oxi.replacer.replace_text_preview.IParams
---@return oxi.replacer.replace_text_preview.IResult
function M.replace_text_preview(params)
  ---@type oxi.replacer.replace_text_preview.IPayload
  local payload = {
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    replace_pattern = params.replace_pattern,
    search_pattern = params.search_pattern,
    text = params.text,
  }

  local ok, data = oxi.fn.safe_call("replace_text_preview", payload)
  if ok then
    ---@cast data                       string

    local text = data ---@type string
    local lwidths = oxi.string.calc_linewidths(text) ---@type integer[]
    local lines = oxi.string.parse_lines(text, lwidths) ---@type string[]

    ---@type oxi.replacer.replace_text_preview.IResult
    return { lines = lines, lwidths = lwidths }
  end

  ---@type oxi.replacer.replace_text_preview.IResult
  return { lines = {}, lwidths = {} }
end

---@param params                        oxi.replacer.replace_text_preview_by_matches.IParams
---@return oxi.replacer.replace_text_preview_by_matches.IResult
function M.replace_text_preview_by_matches(params)
  ---@type oxi.replacer.replace_text_preview_by_matches.IPayload
  local payload = {
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
    replace_pattern = params.replace_pattern,
    search_pattern = params.search_pattern,
    text = params.text,
  }

  local ok, data = oxi.fn.safe_call("replace_text_preview_by_matches", payload)
  if ok then
    ---@cast data                       string

    local text = data ---@type string
    local lwidths = oxi.string.calc_linewidths(text) ---@type integer[]
    local lines = oxi.string.parse_lines(text, lwidths) ---@type string[]

    ---@type oxi.replacer.replace_text_preview_by_matches.IResult
    return { lines = lines, lwidths = lwidths }
  end

  ---@type oxi.replacer.replace_text_preview_by_matches.IResult
  return { lines = {}, lwidths = {} }
end

---@param params                        oxi.replacer.replace_text_preview_advance.IParams
---@return oxi.replacer.replace_text_preview_advance.IResult
function M.replace_text_preview_advance(params)
  ---@type oxi.replacer.replace_text_preview_advance.IPayload
  local payload = {
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    replace_pattern = params.replace_pattern,
    search_pattern = params.search_pattern,
    text = params.text,
  }

  local ok, data = oxi.fn.safe_call("replace_text_preview_advance", payload)
  if ok then
    ---@cast data                       oxi.replacer.replace_text_preview_advance.IResponseData

    local text = data.text ---@type string
    local lwidths = oxi.string.calc_linewidths(text) ---@type integer[]
    local lines = oxi.string.parse_lines(text, lwidths) ---@type string[]

    ---@type oxi.replacer.replace_text_preview_advance.IResult
    return { lines = lines, lwidths = lwidths, matches = data.matches }
  end

  ---@type oxi.replacer.replace_text_preview_advance.IResult
  return { lines = {}, lwidths = {}, matches = {} }
end

---@param params                        oxi.replacer.replace_text_preview_by_matches_advance.IParams
---@return oxi.replacer.replace_text_preview_by_matches_advance.IResult
function M.replace_text_preview_by_matches_advance(params)
  ---@type oxi.replacer.replace_text_preview_by_matches_advance.IPayload
  local payload = {
    text = params.text,
    search_pattern = params.search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
  }

  local ok, data = oxi.fn.safe_call("replace_text_preview_by_matches_advance", payload)
  if ok then
    ---@cast data                       oxi.replacer.replace_text_preview_by_matches_advance.IResponseData

    local text = data.text ---@type string
    local lwidths = oxi.string.calc_linewidths(text) ---@type integer[]
    local lines = oxi.string.parse_lines(text, lwidths) ---@type string[]

    ---@type oxi.replacer.replace_text_preview_by_matches_advance.IResult
    return { lines = lines, lwidths = lwidths, matches = data.matches }
  end

  ---@type oxi.replacer.replace_text_preview_by_matches_advance.IResult
  return { lines = {}, lwidths = {}, matches = {} }
end

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

---@class oxi.replacer.replace_current_match_in_buffer.IParams
---@field public bufnr                  integer
---@field public current_match_index    integer
---@field public matches                oxi.string.ILineMatch[]
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@class oxi.replacer.replace_all_matches_in_buffer.IParams
---@field public bufnr                  integer
---@field public matches                oxi.string.ILineMatch[]
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@class oxi.replacer.show_replace_preview_in_buffer.IReplacementPoint
---@field public l                      integer -- start position
---@field public r                      integer -- end position
---@field public text                   string  -- replacement text content

---@class oxi.replacer.show_replace_preview_in_buffer.IResult
---@field public bufnr                  integer
---@field public error                  string|nil
---@field public preview_applied        boolean
---@field public matches_count          integer
---@field public search_matches         oxi.string.ILineMatch[]
---@field public replacement_lines      string[]
---@field public replacement_matches    oxi.replacer.show_replace_preview_in_buffer.IReplacementPoint[]

---@class oxi.replacer.replace_current_match_in_buffer.IResult
---@field public success                boolean

---@class oxi.replacer.replace_all_matches_in_buffer.IResult
---@field public success                boolean
---@field public replaced_count         integer

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
