---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@class fml.std.oxi.replace.IPreviewBlockItem
---@field public text                   string
---@field public lines                  fml.std.oxi.search.ILineMatch[]

---@class fml.std.oxi.replace.ITextPreviewParams
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean
---@field public keep_search_pieces     boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public text                   string

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

