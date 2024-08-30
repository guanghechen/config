local path = require("fml.std.path")

---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@class fml.std.oxi.replace.replace_file_by_matches.IRawParams
---@field public filepath               string
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public match_offsets          integer[]

---@class fml.std.oxi.replace.replace_file_preview_by_matches.IRawParams
---@field public filepath               string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public match_offsets          integer[]

---@class fml.std.oxi.replace_file_preview_advance_by_matches.IRawParams
---@field public filepath               string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public match_offsets          integer[]

---@class fml.std.oxi.replace_text_preview_by_matches.IRawParams
---@field public text                   string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public match_offsets          integer[]

---@class fml.std.oxi.replace_text_preview_advance_by_matches.IRawParams
---@field public text                   string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public match_offsets          integer[]

---@class fml.std.oxi.replace.replace_file.IRawResult
---@field public success                boolean
---@field public error                  ?string

---@class fml.std.oxi.replace.replace_file_preview.IRawResult
---@field public text                   string

---@class fml.std.oxi.replace.replace_file_preview_by_matches.IRawResult
---@field public text                   string

---@class fml.std.oxi.replace.replace_file_preview_advance.IRawResult
---@field public text                   string
---@field public matches                fml.types.IMatchPoint[]

---@class fml.std.oxi.replace.replace_file_preview_advance_by_matches.IRawResult
---@field public text                   string
---@field public matches                fml.types.IMatchPoint[]

---@class fml.std.oxi.replace.replace_text_preview.IRawResult
---@field public text                   string

---@class fml.std.oxi.replace.replace_text_preview_by_matches.IRawResult
---@field public text                   string

---@class fml.std.oxi.replace.replace_text_preview_advance.IRawResult
---@field public text                   string
---@field public matches                fml.types.IMatchPoint[]

---@class fml.std.oxi.replace.replace_text_preview_advance_by_matches.IRawResult
---@field public text                   string
---@field public matches                fml.types.IMatchPoint[]

---@class fml.std.oxi.replace.replace_file.IResult
---@field public success                boolean
---@field public error                  ?string

---@class fml.std.oxi.replace.replace_file_by_matches.IResult
---@field public offset_deltas          integer[]

---@class fml.std.oxi.replace.replace_file_preview.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]

---@class fml.std.oxi.replace.replace_file_preview_by_matches.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]

---@class fml.std.oxi.replace.replace_file_preview_advance.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                fml.types.IMatchPoint[]

---@class fml.std.oxi.replace.replace_file_preview_advance_by_matches.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                fml.types.IMatchPoint[]

---@class fml.std.oxi.replace.replace_text_preview.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]

---@class fml.std.oxi.replace.replace_text_preview_by_matches.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]

---@class fml.std.oxi.replace.replace_text_preview_advance.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                fml.types.IMatchPoint[]

---@class fml.std.oxi.replace.replace_text_preview_advance_by_matches.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                fml.types.IMatchPoint[]

---@class fml.std.oxi.replace.replace_file.IParams
---@field public cwd                    string
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public replace_pattern        string

---@class fml.std.oxi.replace.replace_file_by_matches.IParams
---@field public cwd                    string
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public match_offsets          integer[]

---@class fml.std.oxi.replace.replace_file_preview.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public filepath               string

---@class fml.std.oxi.replace.replace_file_preview_by_matches.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public filepath               string
---@field public match_offsets          integer[]

---@class fml.std.oxi.replace.replace_file_preview_advance.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public filepath               string

---@class fml.std.oxi.replace.replace_file_preview_advance_by_matches.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public filepath               string
---@field public match_offsets          integer[]

---@class fml.std.oxi.replace.replace_text_preview.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string

---@class fml.std.oxi.replace.replace_text_preview_by_matches.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string
---@field public match_offsets          integer[]

---@class fml.std.oxi.replace.replace_text_preview_advance.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string

---@class fml.std.oxi.replace.replace_text_preview_advance_by_matches.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string
---@field public match_offsets          integer[]

---@param params                        fml.std.oxi.replace.replace_file.IParams
---@return boolean
function M.replace_file(params)
  local search_pattern = params.search_pattern ---@type string
  local filepath = path.resolve(params.cwd, params.filepath) ---@type string
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  local ok, data = M.resolve_fun_result(
    "fml.std.oxi.replace_file",
    M.nvim_tools.replace_file(filepath, search_pattern, params.replace_pattern, params.flag_regex)
  )
  return ok and data
end

---@param params                        fml.std.oxi.replace.replace_file_by_matches.IParams
---@return boolean
---@return integer[]
function M.replace_file_by_matches(params)
  local search_pattern = params.search_pattern ---@type string
  local filepath = path.resolve(params.cwd, params.filepath) ---@type string
  local match_offsets = params.match_offsets ---@type integer[]
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type fml.std.oxi.replace.replace_file_by_matches.IRawParams
  local resolved_params = {
    filepath = filepath,
    search_pattern = search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    match_offsets = match_offsets,
  }
  local payload = M.json.stringify(resolved_params)
  local ok, data = M.run_fun("fml.std.oxi.replace_file_by_matches", M.nvim_tools.replace_file_by_matches, payload)
  ---@cast data fml.std.oxi.replace.replace_file_by_matches.IResult

  return ok, ok and data.offset_deltas or {}
end

---@param params                        fml.std.oxi.replace.replace_file_preview.IParams
---@return fml.std.oxi.replace.replace_file_preview.IResult
function M.replace_file_preview(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  local ok, data = M.resolve_fun_result(
    "fml.std.oxi.replace_file_preview",
    M.nvim_tools.replace_file_preview(
      params.filepath,
      search_pattern,
      params.replace_pattern,
      params.keep_search_pieces,
      params.flag_regex
    )
  )

  if ok then
    ---@cast data string

    local text = data ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type fml.std.oxi.replace.replace_file_preview.IResult
    local result = { lines = lines, lwidths = lwidths }
    return result
  end

  ---@type fml.std.oxi.replace.replace_file_preview.IResult
  local result = { lines = {}, lwidths = {} }
  return result
end

---@param params                        fml.std.oxi.replace.replace_file_preview_by_matches.IParams
---@return fml.std.oxi.replace.replace_file_preview_by_matches.IResult
function M.replace_file_preview_by_matches(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type fml.std.oxi.replace.replace_file_preview_by_matches.IRawParams
  local payload_params = {
    filepath = params.filepath,
    search_pattern = search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
  }
  local payload = M.json.stringify(payload_params)
  local ok, data = M.run_fun( ---
    "fml.std.oxi.replace_file_preview_by_matches",
    M.nvim_tools.replace_file_preview_by_matches,
    payload
  )

  if ok then
    ---@cast data string

    local text = data ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type fml.std.oxi.replace.replace_file_preview_by_matches.IResult
    local result = { lines = lines, lwidths = lwidths }
    return result
  end

  ---@type fml.std.oxi.replace.replace_file_preview_by_matches.IResult
  local result = { lines = {}, lwidths = {} }
  return result
end

---@param params                        fml.std.oxi.replace.replace_file_preview_advance.IParams
---@return fml.std.oxi.replace.replace_file_preview_advance.IResult
function M.replace_file_preview_advance(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  local ok, data = M.resolve_fun_result(
    "fml.std.oxi.replace_file_preview_advance",
    M.nvim_tools.replace_file_preview_advance(
      params.filepath,
      search_pattern,
      params.replace_pattern,
      params.keep_search_pieces,
      params.flag_regex
    )
  )

  if ok then
    ---@cast data fml.std.oxi.replace.replace_file_preview_advance.IRawResult

    local text = data.text ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type fml.std.oxi.replace.replace_file_preview_advance.IResult
    local result = { lines = lines, lwidths = lwidths, matches = data.matches }
    return result
  end

  ---@type fml.std.oxi.replace.replace_file_preview_advance.IResult
  local result = { lines = {}, lwidths = {}, matches = {} }
  return result
end

---@param params                        fml.std.oxi.replace.replace_file_preview_advance_by_matches.IParams
---@return fml.std.oxi.replace.replace_file_preview_advance_by_matches.IResult
function M.replace_file_preview_advance_by_matches(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type fml.std.oxi.replace.replace_file_preview_by_matches.IRawParams
  local payload_params = {
    filepath = params.filepath,
    search_pattern = search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
  }
  local payload = M.json.stringify(payload_params)
  local ok, data = M.run_fun(
    "fml.std.oxi.replace_file_preview_advance_by_matches",
    M.nvim_tools.replace_file_preview_advance_by_matches,
    payload
  )

  if ok then
    ---@cast data fml.std.oxi.replace.replace_file_preview_advance_by_matches.IRawResult

    local text = data.text ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type fml.std.oxi.replace.replace_file_preview_advance_by_matches.IResult
    local result = { lines = lines, lwidths = lwidths, matches = data.matches }
    return result
  end

  ---@type fml.std.oxi.replace.replace_file_preview_advance_by_matches.IResult
  local result = { lines = {}, lwidths = {}, matches = {} }
  return result
end

---@param params                        fml.std.oxi.replace.replace_text_preview.IParams
---@return fml.std.oxi.replace.replace_text_preview.IResult
function M.replace_text_preview(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  local ok, data = M.resolve_fun_result(
    "fml.std.oxi.replace_text_preview",
    M.nvim_tools.replace_text_preview(
      params.text,
      search_pattern,
      params.replace_pattern,
      params.keep_search_pieces,
      params.flag_regex
    )
  )

  if ok then
    ---@cast data string

    local text = data ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type fml.std.oxi.replace.replace_text_preview.IResult
    local result = { lines = lines, lwidths = lwidths }
    return result
  end

  ---@type fml.std.oxi.replace.replace_text_preview.IResult
  local result = { lines = {}, lwidths = {} }
  return result
end

---@param params                        fml.std.oxi.replace.replace_text_preview_by_matches.IParams
---@return fml.std.oxi.replace.replace_text_preview_by_matches.IResult
function M.replace_text_preview_by_matches(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type fml.std.oxi.replace_text_preview_by_matches.IRawParams
  local payload_params = {
    text = params.text,
    search_pattern = search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
  }
  local payload = M.json.stringify(payload_params)
  local ok, data = M.run_fun( ---
    "fml.std.oxi.replace_text_preview_by_matches",
    M.nvim_tools.replace_text_preview_by_matches,
    payload
  )

  if ok then
    ---@cast data string

    local text = data ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type fml.std.oxi.replace.replace_text_preview_by_matches.IResult
    local result = { lines = lines, lwidths = lwidths }
    return result
  end

  ---@type fml.std.oxi.replace.replace_text_preview_by_matches.IResult
  local result = { lines = {}, lwidths = {} }
  return result
end

---@param params                        fml.std.oxi.replace.replace_text_preview_advance.IParams
---@return fml.std.oxi.replace.replace_text_preview_advance.IResult
function M.replace_text_preview_advance(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  local ok, data = M.resolve_fun_result(
    "fml.std.oxi.replace_text_preview_advance",
    M.nvim_tools.replace_text_preview_advance(
      params.text,
      search_pattern,
      params.replace_pattern,
      params.keep_search_pieces,
      params.flag_regex
    )
  )

  if ok then
    ---@cast data fml.std.oxi.replace.replace_text_preview_advance.IRawResult

    local text = data.text ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type fml.std.oxi.replace.replace_text_preview_advance.IResult
    local result = {
      lines = lines,
      lwidths = lwidths,
      matches = data.matches,
    }
    return result
  end

  ---@type fml.std.oxi.replace.replace_text_preview_advance.IResult
  local result = { lines = {}, lwidths = {}, matches = {} }
  return result
end

---@param params                        fml.std.oxi.replace.replace_text_preview_advance_by_matches.IParams
---@return fml.std.oxi.replace.replace_text_preview_advance_by_matches.IResult
function M.replace_text_preview_advance_by_matches(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type fml.std.oxi.replace_text_preview_advance_by_matches.IRawParams
  local payload_params = {
    text = params.text,
    search_pattern = search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
  }
  local payload = M.json.stringify(payload_params)
  local ok, data = M.run_fun( ---
    "fml.std.oxi.replace_text_preview_advance_by_matches",
    M.nvim_tools.replace_text_preview_advance_by_matches,
    payload
  )

  if ok then
    ---@cast data fml.std.oxi.replace.replace_text_preview_advance_by_matches.IRawResult

    local text = data.text ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type fml.std.oxi.replace.replace_text_preview_advance_by_matches.IResult
    local result = {
      lines = lines,
      lwidths = lwidths,
      matches = data.matches,
    }
    return result
  end

  ---@type fml.std.oxi.replace.replace_text_preview_advance_by_matches.IResult
  local result = { lines = {}, lwidths = {}, matches = {} }
  return result
end
