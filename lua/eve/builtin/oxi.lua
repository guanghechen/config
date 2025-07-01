local __module_name__ = "eve.builtin.oxi" ---@type string

local nvim_tools = require("nvim_tools")

---@class eve.builtin.oxi.ICmdResult
---@field public cmd                    string
---@field public error                  ?string
---@field public data                   ?any

---@class eve.builtin.oxi.IFunResult
---@field public error                  ?string
---@field public data                   ?any

---@class eve.builtin.oxi
local M = {}

---@param subject                       string
---@param result_str                    string
---@return boolean
---@return any|nil
---@return string|nil
function M.resolve_cmd_result(subject, result_str)
  local result = std.json.parse(result_str)
  if result == nil or type(result.error) == "string" then
    std.reporter.error({
      from = __module_name__,
      subject = subject,
      message = "Failed to run command.",
      details = (result or {}).error or result,
    })
    return false
  end

  ---@cast result                       eve.builtin.oxi.ICmdResult
  return true, result.data, result.cmd
end

---@param subject                          string
---@param result_str                    string
---@return boolean
---@return any|nil
function M.resolve_fun_result(subject, result_str)
  local result = std.json.parse(result_str)
  if result == nil or type(result.error) == "string" then
    std.reporter.error({
      from = __module_name__,
      subject = subject,
      message = "Failed to run function",
      details = (result or {}).error or result,
    })
    return false, nil
  end

  ---@cast result                       eve.builtin.oxi.IFunResult
  return true, result.data
end

---@param subject                       string
---@param fn                            fun(...): string
---@param args                          any
---@return boolean
---@return any|nil
function M.run_cmd(subject, fn, args)
  local result_str = fn(args) ---@type string
  return M.resolve_cmd_result(subject, result_str)
end

---@param subject                       string
---@param fn                            fun(...): string
---@param args                          any
---@return boolean
---@return any|nil
function M.run_fun(subject, fn, args)
  local result_str = fn(args) ---@type string
  return M.resolve_fun_result(subject, result_str)
end

--[F]ile--------------------------------------------------------------------------------------------
---@class eve.builtin.oxi.IFileItemWithStatus
---@field public type                   string
---@field public name                   string
---@field public perm                   string
---@field public size                   string
---@field public owner                  string
---@field public group                  string
---@field public date                   string

---@class eve.builtin.oxi.IReaddirResult
---@field public itself                 eve.builtin.oxi.IFileItemWithStatus
---@field public items                  eve.builtin.oxi.IFileItemWithStatus[]

---@param dirpath                       string
---@return eve.builtin.oxi.IReaddirResult|nil
function M.readdir(dirpath)
  local ok, data = M.run_fun("readdir", nvim_tools.readdir, dirpath)
  if ok then
    return data
  end
end

---@param filepath string
---@return string|nil
function M.get_filesize(filepath)
  local stat = vim.uv.fs_stat(filepath)
  if stat == nil or stat.type ~= "file" then
    return nil
  end

  local ok, data = M.run_fun("get_filesize", nvim_tools.get_filesize, filepath)
  if ok then
    return data
  end
end
--------------------------------------------------------------------------------------------[F]ile--

--[F]ind--------------------------------------------------------------------------------------------

---@class eve.builtin.oxi.find.IParams
---@field public workspace              string
---@field public cwd                    string
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public search_paths           string
---@field public exclude_patterns       string

---@class eve.builtin.oxi.find.IResult
---@field public filepaths              string[]

---@param params                        eve.builtin.oxi.find.IParams
---@return string[]
function M.find(params)
  local options_stringified = std.json.stringify(params)
  local result_str = nvim_tools.find(options_stringified)
  local ok, data = M.resolve_cmd_result("find", result_str)
  if ok and data ~= nil then
    ---@cast data                       eve.builtin.oxi.find.IResult
    return data.filepaths
  end
  return {}
end
--------------------------------------------------------------------------------------------[F]ind--

--[R]eplace-----------------------------------------------------------------------------------------
---@class eve.builtin.oxi.replace.replace_file_by_matches.IRawParams
---@field public filepath               string
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public match_offsets          integer[]

---@class eve.builtin.oxi.replace.replace_file_advance_by_matches.IRawParams
---@field public filepath               string
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public match_offsets          integer[]
---@field public remain_offsets         integer[]

---@class eve.builtin.oxi.replace.replace_file_preview_by_matches.IRawParams
---@field public filepath               string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public match_offsets          integer[]

---@class eve.builtin.oxi.replace_file_preview_advance_by_matches.IRawParams
---@field public filepath               string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public match_offsets          integer[]

---@class eve.builtin.oxi.replace_text_preview_by_matches.IRawParams
---@field public text                   string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public match_offsets          integer[]

---@class eve.builtin.oxi.replace_text_preview_advance_by_matches.IRawParams
---@field public text                   string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public match_offsets          integer[]

---@class eve.builtin.oxi.replace.replace_file.IRawResult
---@field public success                boolean
---@field public error                  ?string

---@class eve.builtin.oxi.replace.replace_file_preview.IRawResult
---@field public text                   string

---@class eve.builtin.oxi.replace.replace_file_preview_by_matches.IRawResult
---@field public text                   string

---@class eve.builtin.oxi.replace.replace_file_preview_advance.IRawResult
---@field public text                   string
---@field public matches                std.t.IMatchPoint[]

---@class eve.builtin.oxi.replace.replace_file_preview_advance_by_matches.IRawResult
---@field public text                   string
---@field public matches                std.t.IMatchPoint[]

---@class eve.builtin.oxi.replace.replace_text_preview.IRawResult
---@field public text                   string

---@class eve.builtin.oxi.replace.replace_text_preview_by_matches.IRawResult
---@field public text                   string

---@class eve.builtin.oxi.replace.replace_text_preview_advance.IRawResult
---@field public text                   string
---@field public matches                std.t.IMatchPoint[]

---@class eve.builtin.oxi.replace.replace_text_preview_advance_by_matches.IRawResult
---@field public text                   string
---@field public matches                std.t.IMatchPoint[]

---@class eve.builtin.oxi.replace.replace_file.IResult
---@field public success                boolean
---@field public error                  ?string

---@alias eve.builtin.oxi.replace.replace_file_by_matches.IResult
---| boolean

---@class eve.builtin.oxi.replace.replace_file_advance_by_matches.IResult
---@field public locations              std.t.IMatchLocation[]

---@class eve.builtin.oxi.replace.replace_file_preview.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]

---@class eve.builtin.oxi.replace.replace_file_preview_by_matches.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]

---@class eve.builtin.oxi.replace.replace_file_preview_advance.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                std.t.IMatchPoint[]

---@class eve.builtin.oxi.replace.replace_file_preview_advance_by_matches.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                std.t.IMatchPoint[]

---@class eve.builtin.oxi.replace.replace_text_preview.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]

---@class eve.builtin.oxi.replace.replace_text_preview_by_matches.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]

---@class eve.builtin.oxi.replace.replace_text_preview_advance.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                std.t.IMatchPoint[]

---@class eve.builtin.oxi.replace.replace_text_preview_advance_by_matches.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                std.t.IMatchPoint[]

---@class eve.builtin.oxi.replace.replace_file.IParams
---@field public cwd                    string
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public replace_pattern        string

---@class eve.builtin.oxi.replace.replace_file_by_matches.IParams
---@field public cwd                    string
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public match_offsets          integer[]

---@class eve.builtin.oxi.replace.replace_file_advance_by_matches.IParams
---@field public cwd                    string
---@field public filepath               string
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public match_offsets          integer[]
---@field public remain_offsets         integer[]

---@class eve.builtin.oxi.replace.replace_file_preview.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public filepath               string

---@class eve.builtin.oxi.replace.replace_file_preview_by_matches.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public filepath               string
---@field public match_offsets          integer[]

---@class eve.builtin.oxi.replace.replace_file_preview_advance.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public filepath               string

---@class eve.builtin.oxi.replace.replace_file_preview_advance_by_matches.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public filepath               string
---@field public match_offsets          integer[]

---@class eve.builtin.oxi.replace.replace_text_preview.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string

---@class eve.builtin.oxi.replace.replace_text_preview_by_matches.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string
---@field public match_offsets          integer[]

---@class eve.builtin.oxi.replace.replace_text_preview_advance.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string

---@class eve.builtin.oxi.replace.replace_text_preview_advance_by_matches.IParams
---@field public flag_case_sensitive    boolean
---@field public flag_regex             boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string
---@field public match_offsets          integer[]

---@param params                        eve.builtin.oxi.replace.replace_file.IParams
---@return boolean
function M.replace_file(params)
  local search_pattern = params.search_pattern ---@type string
  local filepath = std.path.resolve(params.cwd, params.filepath) ---@type string
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  local ok, data = M.resolve_fun_result(
    "replace_file",
    nvim_tools.replace_file(
      filepath,
      search_pattern,
      params.replace_pattern,
      params.flag_regex,
      params.flag_case_sensitive
    )
  )
  return ok and data
end

---@param params                        eve.builtin.oxi.replace.replace_file_by_matches.IParams
---@return boolean
---@return boolean
function M.replace_file_by_matches(params)
  local search_pattern = params.search_pattern ---@type string
  local filepath = std.path.resolve(params.cwd, params.filepath) ---@type string
  local match_offsets = params.match_offsets ---@type integer[]
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type eve.builtin.oxi.replace.replace_file_by_matches.IRawParams
  local resolved_params = {
    filepath = filepath,
    search_pattern = search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
    match_offsets = match_offsets,
  }
  local payload = std.json.stringify(resolved_params)
  local ok, data = M.run_fun("replace_file_by_matches", nvim_tools.replace_file_by_matches, payload)
  ---@cast data                         eve.builtin.oxi.replace.replace_file_by_matches.IResult

  return ok, data
end

---@param params                        eve.builtin.oxi.replace.replace_file_advance_by_matches.IParams
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

  ---@type eve.builtin.oxi.replace.replace_file_advance_by_matches.IRawParams
  local resolved_params = {
    filepath = filepath,
    search_pattern = search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
    match_offsets = match_offsets,
    remain_offsets = remain_offsets,
  }
  local payload = std.json.stringify(resolved_params)
  local ok, data = M.run_fun("replace_file_advance_by_matches", nvim_tools.replace_file_advance_by_matches, payload)
  ---@cast data                         eve.builtin.oxi.replace.replace_file_advance_by_matches.IResult

  return ok, ok and data.locations or {}
end

---@param params                        eve.builtin.oxi.replace.replace_file_preview.IParams
---@return eve.builtin.oxi.replace.replace_file_preview.IResult
function M.replace_file_preview(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  local ok, data = M.resolve_fun_result(
    "replace_file_preview",
    nvim_tools.replace_file_preview(
      params.filepath,
      search_pattern,
      params.replace_pattern,
      params.keep_search_pieces,
      params.flag_regex,
      params.flag_case_sensitive
    )
  )

  if ok then
    ---@cast data                       string

    local text = data ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type eve.builtin.oxi.replace.replace_file_preview.IResult
    local result = { lines = lines, lwidths = lwidths }
    return result
  end

  ---@type eve.builtin.oxi.replace.replace_file_preview.IResult
  local result = { lines = {}, lwidths = {} }
  return result
end

---@param params                        eve.builtin.oxi.replace.replace_file_preview_by_matches.IParams
---@return eve.builtin.oxi.replace.replace_file_preview_by_matches.IResult
function M.replace_file_preview_by_matches(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type eve.builtin.oxi.replace.replace_file_preview_by_matches.IRawParams
  local payload_params = {
    filepath = params.filepath,
    search_pattern = search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
  }
  local payload = std.json.stringify(payload_params)
  local ok, data = M.run_fun( ---
    "replace_file_preview_by_matches",
    nvim_tools.replace_file_preview_by_matches,
    payload
  )

  if ok then
    ---@cast data                       string

    local text = data ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type eve.builtin.oxi.replace.replace_file_preview_by_matches.IResult
    local result = { lines = lines, lwidths = lwidths }
    return result
  end

  ---@type eve.builtin.oxi.replace.replace_file_preview_by_matches.IResult
  local result = { lines = {}, lwidths = {} }
  return result
end

---@param params                        eve.builtin.oxi.replace.replace_file_preview_advance.IParams
---@return eve.builtin.oxi.replace.replace_file_preview_advance.IResult
function M.replace_file_preview_advance(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  local ok, data = M.resolve_fun_result(
    "replace_file_preview_advance",
    nvim_tools.replace_file_preview_advance(
      params.filepath,
      search_pattern,
      params.replace_pattern,
      params.keep_search_pieces,
      params.flag_regex,
      params.flag_case_sensitive
    )
  )

  if ok then
    ---@cast data                       eve.builtin.oxi.replace.replace_file_preview_advance.IRawResult

    local text = data.text ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type eve.builtin.oxi.replace.replace_file_preview_advance.IResult
    local result = { lines = lines, lwidths = lwidths, matches = data.matches }
    return result
  end

  ---@type eve.builtin.oxi.replace.replace_file_preview_advance.IResult
  local result = { lines = {}, lwidths = {}, matches = {} }
  return result
end

---@param params                        eve.builtin.oxi.replace.replace_file_preview_advance_by_matches.IParams
---@return eve.builtin.oxi.replace.replace_file_preview_advance_by_matches.IResult
function M.replace_file_preview_advance_by_matches(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type eve.builtin.oxi.replace.replace_file_preview_by_matches.IRawParams
  local payload_params = {
    filepath = params.filepath,
    search_pattern = search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
  }
  local payload = std.json.stringify(payload_params)
  local ok, data =
    M.run_fun("replace_file_preview_advance_by_matches", nvim_tools.replace_file_preview_advance_by_matches, payload)

  if ok then
    ---@cast data                       eve.builtin.oxi.replace.replace_file_preview_advance_by_matches.IRawResult

    local text = data.text ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type eve.builtin.oxi.replace.replace_file_preview_advance_by_matches.IResult
    local result = { lines = lines, lwidths = lwidths, matches = data.matches }
    return result
  end

  ---@type eve.builtin.oxi.replace.replace_file_preview_advance_by_matches.IResult
  local result = { lines = {}, lwidths = {}, matches = {} }
  return result
end

---@param params                        eve.builtin.oxi.replace.replace_text_preview.IParams
---@return eve.builtin.oxi.replace.replace_text_preview.IResult
function M.replace_text_preview(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  local ok, data = M.resolve_fun_result(
    "replace_text_preview",
    nvim_tools.replace_text_preview(
      params.text,
      search_pattern,
      params.replace_pattern,
      params.keep_search_pieces,
      params.flag_regex,
      params.flag_case_sensitive
    )
  )

  if ok then
    ---@cast data                       string

    local text = data ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type eve.builtin.oxi.replace.replace_text_preview.IResult
    local result = { lines = lines, lwidths = lwidths }
    return result
  end

  ---@type eve.builtin.oxi.replace.replace_text_preview.IResult
  local result = { lines = {}, lwidths = {} }
  return result
end

---@param params                        eve.builtin.oxi.replace.replace_text_preview_by_matches.IParams
---@return eve.builtin.oxi.replace.replace_text_preview_by_matches.IResult
function M.replace_text_preview_by_matches(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type eve.builtin.oxi.replace_text_preview_by_matches.IRawParams
  local payload_params = {
    text = params.text,
    search_pattern = search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
  }
  local payload = std.json.stringify(payload_params)
  local ok, data = M.run_fun( ---
    "replace_text_preview_by_matches",
    nvim_tools.replace_text_preview_by_matches,
    payload
  )

  if ok then
    ---@cast data                       string

    local text = data ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type eve.builtin.oxi.replace.replace_text_preview_by_matches.IResult
    local result = { lines = lines, lwidths = lwidths }
    return result
  end

  ---@type eve.builtin.oxi.replace.replace_text_preview_by_matches.IResult
  local result = { lines = {}, lwidths = {} }
  return result
end

---@param params                        eve.builtin.oxi.replace.replace_text_preview_advance.IParams
---@return eve.builtin.oxi.replace.replace_text_preview_advance.IResult
function M.replace_text_preview_advance(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  local ok, data = M.resolve_fun_result(
    "replace_text_preview_advance",
    nvim_tools.replace_text_preview_advance(
      params.text,
      search_pattern,
      params.replace_pattern,
      params.keep_search_pieces,
      params.flag_regex,
      params.flag_case_sensitive
    )
  )

  if ok then
    ---@cast data                       eve.builtin.oxi.replace.replace_text_preview_advance.IRawResult

    local text = data.text ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type eve.builtin.oxi.replace.replace_text_preview_advance.IResult
    local result = {
      lines = lines,
      lwidths = lwidths,
      matches = data.matches,
    }
    return result
  end

  ---@type eve.builtin.oxi.replace.replace_text_preview_advance.IResult
  local result = { lines = {}, lwidths = {}, matches = {} }
  return result
end

---@param params                        eve.builtin.oxi.replace.replace_text_preview_advance_by_matches.IParams
---@return eve.builtin.oxi.replace.replace_text_preview_advance_by_matches.IResult
function M.replace_text_preview_advance_by_matches(params)
  local search_pattern = params.search_pattern
  if params.flag_regex and not params.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type eve.builtin.oxi.replace_text_preview_advance_by_matches.IRawParams
  local payload_params = {
    text = params.text,
    search_pattern = search_pattern,
    replace_pattern = params.replace_pattern,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
    keep_search_pieces = params.keep_search_pieces,
    match_offsets = params.match_offsets,
  }
  local payload = std.json.stringify(payload_params)
  local ok, data = M.run_fun( ---
    "replace_text_preview_advance_by_matches",
    nvim_tools.replace_text_preview_advance_by_matches,
    payload
  )

  if ok then
    ---@cast data                       eve.builtin.oxi.replace.replace_text_preview_advance_by_matches.IRawResult

    local text = data.text ---@type string
    local lwidths = M.get_line_widths(text) ---@type integer[]
    local lines = M.parse_lines(text, lwidths) ---@type string[]

    ---@type eve.builtin.oxi.replace.replace_text_preview_advance_by_matches.IResult
    local result = {
      lines = lines,
      lwidths = lwidths,
      matches = data.matches,
    }
    return result
  end

  ---@type eve.builtin.oxi.replace.replace_text_preview_advance_by_matches.IResult
  local result = { lines = {}, lwidths = {}, matches = {} }
  return result
end
-----------------------------------------------------------------------------------------[R]eplace--

------------------------------------------------------------------------------------------[S]earch--
---@class eve.builtin.oxi.search.IBlockMatch
---@field public lnum                   integer
---@field public text                   string
---@field public offset                 integer
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                std.t.IMatchPoint[]

---@class eve.builtin.oxi.search.IFileMatch
---@field public matches                eve.builtin.oxi.search.IBlockMatch[]

---@class eve.builtin.oxi.search.IResult
---@field public elapsed_time           string
---@field public items                  ?table<string, eve.builtin.oxi.search.IFileMatch>
---@field public item_orders            ?string[]
---@field public error                  ?string

---@class eve.builtin.oxi.search.IParams
---@field public cwd                    string
---@field public flag_regex             boolean
---@field public flag_gitignore         boolean
---@field public flag_case_sensitive    boolean
---@field public max_filesize           string|nil
---@field public max_matches            integer|nil
---@field public search_pattern         string
---@field public search_paths           string
---@field public include_patterns       string
---@field public exclude_patterns       string
---@field public specified_filepath     ?string

---@param params                        eve.builtin.oxi.search.IParams
---@return eve.builtin.oxi.search.IResult|nil
---@return string|nil
function M.search(params)
  local payload = std.json.stringify(params) ---@type string
  local ok, data, cmd = M.run_cmd("search", nvim_tools.search, payload)

  if ok and data ~= nil and data.items ~= nil then
    local items = {} ---@type table<string, eve.builtin.oxi.search.IFileMatch>
    local orders = {} ---@type string[]

    local cwd = params.cwd ---@type string
    for filepath, item in pairs(data.items) do
      filepath = std.path.relative(cwd, filepath, true)
      table.insert(orders, filepath)
      items[filepath] = item

      for _, block_match in ipairs(item.matches) do
        local text = block_match.text ---@type string
        local lwidths = M.get_line_widths(text) ---@type integer[]
        local lines = M.parse_lines(text, lwidths) ---@type string[]
        block_match.lines = lines
        block_match.lwidths = lwidths
      end
    end
    table.sort(orders)

    data.items = items
    data.item_orders = orders
  end

  return data, cmd
end
--[S]earch------------------------------------------------------------------------------------------

--[S]tring------------------------------------------------------------------------------------------
---@class eve.builtin.oxi.string.ILineMatch
---@field public lnum                   integer
---@field public score                  integer
---@field public matches                std.t.IMatchPoint[]

---@param text                          string
---@return integer
function M.count_lines(text)
  return nvim_tools.count_lines(text)
end

---@param pattern                       string
---@param lines                         string[]
---@param flag_fuzzy                    boolean
---@param flag_regex                    boolean
---@return eve.builtin.oxi.string.ILineMatch[]|nil
function M.find_match_points_line_by_line(pattern, lines, flag_fuzzy, flag_regex)
  local text = table.concat(lines, "\n") ---@type string

  local ok, data = M.resolve_fun_result(
    "find_match_points_line_by_line",
    nvim_tools.find_match_points_line_by_line(pattern, text, flag_fuzzy, flag_regex)
  )

  if ok then
    ---@cast data                       eve.builtin.oxi.string.ILineMatch[]
    return data
  end
  return nil
end

---@param text                          string
---@return integer[]
function M.get_line_widths(text)
  local str = nvim_tools.get_line_widths(text)
  local raw_result = std.json.parse(str)
  ---@cast raw_result                   integer[]

  local result = raw_result ---@type integer[]
  return result
end

---@param text                          string
---@param lwidths                       ?integer[]
---@return string[]
function M.parse_lines(text, lwidths)
  lwidths = lwidths or M.get_line_widths(text) ---@type integer[]
  local offset = 0
  local lines = {} ---@type string[]
  for _, lwidth in ipairs(lwidths) do
    local line = string.sub(text, offset + 1, offset + lwidth)
    table.insert(lines, line)
    offset = offset + lwidth + 1
  end
  return lines
end

return M
