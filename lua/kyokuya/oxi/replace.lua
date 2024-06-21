local nvim_tools = require("nvim_tools")
local util_json = require("guanghechen.util.json")

---@class kyokuya.oxi.replace.ISearchMatchPoint
---@field public l                    integer
---@field public r                    integer

---@class kyokuya.oxi.replace.ISearchLineMatchPiece
---@field public i                    integer
---@field public l                    integer
---@field public r                    integer

---@class kyokuya.oxi.replace.ISearchLineMatch
---@field public l                    integer
---@field public r                    integer
---@field public p                    kyokuya.oxi.replace.ISearchLineMatchPiece[]

---@class kyokuya.oxi.replace.ISearchBlockMatch
---@field public text                 string
---@field public lnum                 integer
---@field public matches              kyokuya.oxi.replace.ISearchMatchPoint[]
---@field public lines                kyokuya.oxi.replace.ISearchLineMatch[]

---@class kyokuya.oxi.replace.ISearchFileMatch
---@field public matches              kyokuya.oxi.replace.ISearchBlockMatch[]

---@class kyokuya.oxi.replace.ISearchResult
---@field public elapsed_time         string
---@field public items                ?table<string, kyokuya.oxi.replace.ISearchFileMatch>
---@field public error                ? string

---@class kyokuya.oxi.replace.IReplacePreviewBlockItem
---@field public text                 string
---@field public lines                kyokuya.oxi.replace.ISearchLineMatch[]

---@class kyokuya.oxi.replace.IReplaceTextPreviewOptions
---@field public flag_regex           boolean
---@field public flag_case_sensitive  boolean
---@field public keep_search_pieces   boolean
---@field public search_pattern       string
---@field public replace_pattern      string
---@field public text                 string

---@class kyokuya.oxi.replace.ISearchOptions
---@field public cwd                  string
---@field public flag_regex           boolean
---@field public flag_case_sensitive  boolean
---@field public search_pattern       string
---@field public search_paths         string
---@field public include_patterns     string
---@field public exclude_patterns     string

---@class kyokuya.oxi
local M = require("kyokuya.oxi.mod")

---@param opts kyokuya.oxi.replace.IReplaceTextPreviewOptions
---@return kyokuya.oxi.replace.IReplacePreviewBlockItem
function M.replace_text_preview(opts)
  local search_pattern = opts.search_pattern
  if opts.flag_regex and not opts.flag_case_sensitive then
    search_pattern = "(?i)" .. search_pattern:lower()
  end

  ---@type string
  local json_str = nvim_tools.replace_text_preview(
    opts.text,
    search_pattern,
    opts.replace_pattern,
    opts.keep_search_pieces,
    opts.flag_regex
  )
  local json = util_json.parse(json_str)
  ---@cast json kyokuya.oxi.replace.IReplacePreviewBlockItem
  return json
end

---@param opts kyokuya.oxi.replace.ISearchOptions
---@return kyokuya.oxi.replace.ISearchResult
function M.search(opts)
  local options_stringified = util_json.stringify(opts)
  local result_str = nvim_tools.search(options_stringified)
  local json = util_json.parse(result_str)
  ---@cast json kyokuya.oxi.replace.ISearchResult
  return json
end

return M
