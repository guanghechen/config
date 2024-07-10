local path = require("fml.std.path")
local reporter = require("fml.std.reporter")

---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@class fml.std.oxi.replace.IPreviewBlockItem
---@field public text                   string
---@field public lines                  fml.std.oxi.search.ILineMatch[]

---@class fml.std.oxi.replace.IReplaceEntireFileResult
---@field public success                boolean
---@field public error                  ?string

---@class fml.std.oxi.replace.ITextPreviewParams
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string

---@class fml.std.oxi.replace.IReplaceEntireFileParams
---@field public cwd                    string
---@field public filepath               string
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean
---@field public search_pattern         string
---@field public replace_pattern        string

---@param params                        fml.std.oxi.replace.ITextPreviewParams
---@return fml.std.oxi.replace.IPreviewBlockItem
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
  ---@cast result fml.std.oxi.replace.IPreviewBlockItem
  return result
end

---@param params                        fml.std.oxi.replace.IReplaceEntireFileParams
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
  ---@cast result fml.std.oxi.replace.IReplaceEntireFileResult

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
