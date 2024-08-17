local path = require("fml.std.path")
local reporter = require("fml.std.reporter")

---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@class fml.std.oxi.replace.replace_entire_file.IRawResult
---@field public success                boolean
---@field public error                  ?string

---@class fml.std.oxi.replace.replace_file_preview.IRawResult
---@field public text                   string

---@class fml.std.oxi.replace.replace_file_preview_with_matches.IRawResult
---@field public text                   string
---@field public matches                fml.std.oxi.search.IMatchPoint[]

---@class fml.std.oxi.replace.replace_text_preview.IRawResult
---@field public text                   string

---@class fml.std.oxi.replace.replace_text_preview_with_matches.IRawResult
---@field public text                   string
---@field public matches                fml.std.oxi.search.IMatchPoint[]

---@class fml.std.oxi.replace.replace_entire_file.IResult
---@field public success                boolean
---@field public error                  ?string

---@class fml.std.oxi.replace.replace_file_preview.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]

---@class fml.std.oxi.replace.replace_file_preview_with_matches.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                fml.std.oxi.search.IMatchPoint[]

---@class fml.std.oxi.replace.replace_text_preview.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]

---@class fml.std.oxi.replace.replace_text_preview_with_matches.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                fml.std.oxi.search.IMatchPoint[]

---@class fml.std.oxi.replace.replace_entire_file.IParams
---@field public cwd                    string
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public replace_pattern        string

---@class fml.std.oxi.replace.replace_file_preview.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public filepath               string

---@class fml.std.oxi.replace.replace_file_preview_with_matches.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public filepath               string

---@class fml.std.oxi.replace.replace_text_preview.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string

---@class fml.std.oxi.replace.replace_text_preview_with_matches.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string

---@param params                        fml.std.oxi.replace.replace_entire_file.IParams
---@return boolean
function M.replace_entire_file(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  local filepath = path.resolve(params.cwd, params.filepath) ---@type string

  ---@type string
  local json_str = M.nvim_tools.replace_entire_file( ---
    filepath,
    search_pattern,
    params.replace_pattern,
    params.flag_regex
  )
  local result = M.json.parse(json_str)
  ---@cast result fml.std.oxi.replace.replace_entire_file.IResult

  if result.error and result.error ~= vim.NIL then
    reporter.error({
      from = "fml.std.oxi",
      subject = "replace_entire_file",
      message = "Failed to replace entire file.",
      details = { result = result, params = params, search_pattern = search_pattern },
    })
  end
  return result.success
end

---@param params                        fml.std.oxi.replace.replace_file_preview.IParams
---@return fml.std.oxi.replace.replace_file_preview.IResult
function M.replace_file_preview(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type string
  local json_str = M.nvim_tools.replace_file_preview(
    params.filepath,
    search_pattern,
    params.replace_pattern,
    params.keep_search_pieces,
    params.flag_regex
  )
  local raw_result = M.json.parse(json_str)
  ---@cast raw_result string

  if raw_result ~= nil and type(raw_result) == "string" then
    local text = raw_result ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type fml.std.oxi.replace.replace_file_preview.IResult
    local result = { lines = lines, lwidths = lwidths }
    return result
  else
    ---@type fml.std.oxi.replace.replace_file_preview.IResult
    local result = { lines = {}, lwidths = {} }
    return result
  end
end

---@param params                        fml.std.oxi.replace.replace_file_preview_with_matches.IParams
---@return fml.std.oxi.replace.replace_file_preview_with_matches.IResult
function M.replace_file_preview_with_matches(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type string
  local json_str = M.nvim_tools.replace_file_preview_with_matches(
    params.filepath,
    search_pattern,
    params.replace_pattern,
    params.keep_search_pieces,
    params.flag_regex
  )
  local raw_result = M.json.parse(json_str)
  ---@cast raw_result fml.std.oxi.replace.replace_file_preview_with_matches.IRawResult

  if raw_result ~= nil and type(raw_result.text) == "string" then
    local text = raw_result.text ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type fml.std.oxi.replace.replace_file_preview_with_matches.IResult
    local result = {
      lines = lines,
      lwidths = lwidths,
      matches = raw_result.matches,
    }
    return result
  else
    ---@type fml.std.oxi.replace.replace_file_preview_with_matches.IResult
    local result = {
      lines = {},
      lwidths = {},
      matches = raw_result.matches,
    }
    return result
  end
end

---@param params                        fml.std.oxi.replace.replace_text_preview.IParams
---@return fml.std.oxi.replace.replace_text_preview.IResult
function M.replace_text_preview(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type string
  local json_str = M.nvim_tools.replace_text_preview(
    params.text,
    search_pattern,
    params.replace_pattern,
    params.keep_search_pieces,
    params.flag_regex
  )
  local raw_result = M.json.parse(json_str)
  ---@cast raw_result string

  if raw_result ~= nil and type(raw_result) == "string" then
    local text = raw_result ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type fml.std.oxi.replace.replace_text_preview.IResult
    local result = { lines = lines, lwidths = lwidths }
    return result
  else
    ---@type fml.std.oxi.replace.replace_text_preview.IResult
    local result = { lines = {}, lwidths = {} }
    return result
  end
end

---@param params                        fml.std.oxi.replace.replace_text_preview_with_matches.IParams
---@return fml.std.oxi.replace.replace_text_preview_with_matches.IResult
function M.replace_text_preview_with_matches(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type string
  local json_str = M.nvim_tools.replace_text_preview_with_matches(
    params.text,
    search_pattern,
    params.replace_pattern,
    params.keep_search_pieces,
    params.flag_regex
  )
  local raw_result = M.json.parse(json_str)
  ---@cast raw_result fml.std.oxi.replace.replace_text_preview_with_matches.IRawResult

  if raw_result ~= nil and type(raw_result.text) == "string" then
    local text = raw_result.text ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type fml.std.oxi.replace.replace_text_preview_with_matches.IResult
    local result = {
      lines = lines,
      lwidths = lwidths,
      matches = raw_result.matches,
    }
    return result
  else
    ---@type fml.std.oxi.replace.replace_text_preview_with_matches.IResult
    local result = {
      lines = {},
      lwidths = {},
      matches = raw_result.matches,
    }
    return result
  end
end
