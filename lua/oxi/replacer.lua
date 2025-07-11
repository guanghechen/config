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

---@class oxi.replacer.replace_file_advance_by_matches.IParams
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

---@class oxi.replacer.replace_file_preview_advance_by_matches.IParams
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

---@class oxi.replacer.replace_text_preview_advance_by_matches.IParams
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

---@class oxi.replacer.replace_file_preview_advance_by_matches.IResult
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

---@class oxi.replacer.replace_text_preview_advance_by_matches.IResult
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

---@class oxi.replacer.replace_file_advance_by_matches.IPayload
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

---@class oxi.replacer.replace_file_preview_advance_by_matches.IPayload
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

---@class oxi.replacer.replace_text_preview_advance_by_matches.IPayload
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

---@class oxi.replacer.replace_file_preview_advance_by_matches.IResponseData
---@field public text                   string
---@field public matches                std.t.IMatchPoint[]

---@class oxi.replacer.replace_text_preview_advance.IResponseData
---@field public text                   string
---@field public matches                std.t.IMatchPoint[]

---@class oxi.replacer.replace_text_preview_advance_by_matches.IResponseData
---@field public text                   string
---@field public matches                std.t.IMatchPoint[]

---@class oxi.replacer.replace_file_advance_by_matches.IResponseData
---@field public locations              std.t.IMatchLocation[]

---@param params                        oxi.replacer.replace_file.IParams
---@return boolean
function M.replace_file(params)
  local search_pattern = params.search_pattern ---@type string
  local filepath = std.path.resolve(params.cwd, params.filepath) ---@type string
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type oxi.replacer.replace_file.IPayload
  local payload = {
    filepath = filepath,
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    replace_pattern = params.replace_pattern,
    search_pattern = search_pattern,
  }

  local _, data = oxi.fn.safe_call("replace_file", payload)
  return data == true
end

---@param params                        oxi.replacer.replace_file_by_matches.IParams
---@return boolean
---@return boolean
function M.replace_file_by_matches(params)
  local search_pattern = params.search_pattern ---@type string
  local filepath = std.path.resolve(params.cwd, params.filepath) ---@type string
  local match_offsets = params.match_offsets ---@type integer[]
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type oxi.replacer.replace_file_by_matches.IPayload
  local payload = {
    filepath = filepath,
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    match_offsets = match_offsets,
    replace_pattern = params.replace_pattern,
    search_pattern = search_pattern,
  }

  local ok, data = oxi.fn.safe_call("replace_file_by_matches", payload)
  return ok, data
end

---@param params                        oxi.replacer.replace_file_advance_by_matches.IParams
---@return boolean
---@return std.t.IMatchLocation[]
function M.replace_file_advance_by_matches(params)
  local search_pattern = params.search_pattern ---@type string
  local filepath = std.path.resolve(params.cwd, params.filepath) ---@type string
  local match_offsets = params.match_offsets ---@type integer[]
  local remain_offsets = params.remain_offsets ---@type integer[]
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type oxi.replacer.replace_file_advance_by_matches.IPayload
  local payload = {
    filepath = filepath,
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    match_offsets = match_offsets,
    remain_offsets = remain_offsets,
    replace_pattern = params.replace_pattern,
    search_pattern = search_pattern,
  }

  local ok, data = oxi.fn.safe_call("replace_file_advance_by_matches", payload)
  ---@cast data                         oxi.replacer.replace_file_advance_by_matches.IResponseData

  return ok, ok and data.locations or {}
end

---@param params                        oxi.replacer.replace_file_preview.IParams
---@return oxi.replacer.replace_file_preview.IResult
function M.replace_file_preview(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type oxi.replacer.replace_file_preview.IPayload
  local payload = {
    filepath = params.filepath,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
    keep_search_pieces = params.keep_search_pieces,
    search_pattern = search_pattern,
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
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type oxi.replacer.replace_file_preview_advance.IPayload
  local payload = {
    filepath = params.filepath,
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    replace_pattern = params.replace_pattern,
    search_pattern = search_pattern,
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

---@param params                        oxi.replacer.replace_file_preview_advance_by_matches.IParams
---@return oxi.replacer.replace_file_preview_advance_by_matches.IResult
function M.replace_file_preview_advance_by_matches(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type oxi.replacer.replace_file_preview_advance_by_matches.IPayload
  local payload = {
    filepath = params.filepath,
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
    replace_pattern = params.replace_pattern,
    search_pattern = search_pattern,
  }

  local ok, data = oxi.fn.safe_call("replace_file_preview_advance_by_matches", payload)
  if ok then
    ---@cast data                       oxi.replacer.replace_file_preview_advance_by_matches.IResponseData

    local text = data.text ---@type string
    local lwidths = oxi.string.calc_linewidths(text) ---@type integer[]
    local lines = oxi.string.parse_lines(text, lwidths) ---@type string[]

    ---@type oxi.replacer.replace_file_preview_advance_by_matches.IResult
    return { lines = lines, lwidths = lwidths, matches = data.matches }
  end

  ---@type oxi.replacer.replace_file_preview_advance_by_matches.IResult
  return { lines = {}, lwidths = {}, matches = {} }
end

---@param params                        oxi.replacer.replace_text_preview.IParams
---@return oxi.replacer.replace_text_preview.IResult
function M.replace_text_preview(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type oxi.replacer.replace_text_preview.IPayload
  local payload = {
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    replace_pattern = params.replace_pattern,
    search_pattern = search_pattern,
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
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type oxi.replacer.replace_text_preview_by_matches.IPayload
  local payload = {
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
    replace_pattern = params.replace_pattern,
    search_pattern = search_pattern,
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
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type oxi.replacer.replace_text_preview_advance.IPayload
  local payload = {
    flag_case_sensitive = params.flag_case_sensitive,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    replace_pattern = params.replace_pattern,
    search_pattern = search_pattern,
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

---@param params                        oxi.replacer.replace_text_preview_advance_by_matches.IParams
---@return oxi.replacer.replace_text_preview_advance_by_matches.IResult
function M.replace_text_preview_advance_by_matches(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type oxi.replacer.replace_text_preview_advance_by_matches.IPayload
  local payload = {
    text = params.text,
    search_pattern = search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
  }

  local ok, data = oxi.fn.safe_call("replace_text_preview_advance_by_matches", payload)
  if ok then
    ---@cast data                       oxi.replacer.replace_text_preview_advance_by_matches.IResponseData

    local text = data.text ---@type string
    local lwidths = oxi.string.calc_linewidths(text) ---@type integer[]
    local lines = oxi.string.parse_lines(text, lwidths) ---@type string[]

    ---@type oxi.replacer.replace_text_preview_advance_by_matches.IResult
    return { lines = lines, lwidths = lwidths, matches = data.matches }
  end

  ---@type oxi.replacer.replace_text_preview_advance_by_matches.IResult
  return { lines = {}, lwidths = {}, matches = {} }
end

return M
