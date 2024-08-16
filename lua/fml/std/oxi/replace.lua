local path = require("fml.std.path")
local reporter = require("fml.std.reporter")

---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@class fml.std.oxi.replace.replace_entire_file.IResult
---@field public success                boolean
---@field public error                  ?string

---@class fml.std.oxi.replace.replace_file_preview.IResult
---@field public lines                  string[]

---@class fml.std.oxi.replace.replace_file_preview_with_matches.IResult
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                fml.std.oxi.search.IMatchPoint[]

---@class fml.std.oxi.replace.replace_text_preview.IResult
---@field public lines                  string[]

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
  local result = M.json.parse(json_str)
  ---@cast result string

  if result ~= nil and type(result) == "string" then
    local lines = {} ---@type string[]
    local text = result ---@type string
    for line in text:gmatch("([^\n]+)") do
      table.insert(lines, line)
    end
    ---@type fml.std.oxi.replace.replace_file_preview.IResult
    return { lines = lines }
  end
  ---@type fml.std.oxi.replace.replace_file_preview.IResult
  return { lines = {} }
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
  local result = M.json.parse(json_str)
  ---@cast result fml.std.oxi.replace.replace_file_preview_with_matches.IResult

  if result ~= nil and result.lines ~= nil then
    local lwidths = {} ---@type integer[]
    for _, line in ipairs(result.lines) do
      local lwidth = string.len(line) + 1 ---@type integer
      table.insert(lwidths, lwidth)
    end
    result.lwidths = lwidths
  end

  return result
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
  local result = M.json.parse(json_str)
  ---@cast result string

  if result ~= nil and type(result) == "string" then
    local lines = {} ---@type string[]
    local text = result ---@type string
    for line in text:gmatch("([^\n]+)") do
      table.insert(lines, line)
    end
    ---@type fml.std.oxi.replace.replace_text_preview.IResult
    return { lines = lines }
  end
  ---@type fml.std.oxi.replace.replace_text_preview.IResult
  return { lines = {} }
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
  local result = M.json.parse(json_str)
  ---@cast result fml.std.oxi.replace.replace_text_preview_with_matches.IResult

  if result ~= nil and result.lines ~= nil then
    local lwidths = {} ---@type integer[]
    for _, line in ipairs(result.lines) do
      local lwidth = string.len(line) + 1 ---@type integer
      table.insert(lwidths, lwidth)
    end
    result.lwidths = lwidths
  end

  return result
end
