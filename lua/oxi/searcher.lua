---@class oxi.searcher.IBlockMatch
---@field public lnum                   integer
---@field public text                   string
---@field public offset                 integer
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                std.t.IMatchPoint[]

---@class oxi.searcher.IFileMatch
---@field public matches                oxi.searcher.IBlockMatch[]

---@class oxi.searcher.ISearchInFilesParams
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

---@class oxi.searcher.ISearchInFilesResult
---@field public elapsed_time           string
---@field public items                  ?table<string, oxi.searcher.IFileMatch>
---@field public item_orders            ?string[]
---@field public error                  ?string

---@class oxi.searcher
local M = {}

---@param params                        oxi.searcher.ISearchInFilesParams
---@return oxi.searcher.ISearchInFilesResult|nil
---@return string|nil
function M.search_in_files(params)
  local data, cmd = oxi.fn.safe_execute("search_in_files", params)
  if data ~= nil and data.items ~= nil then
    ---@cast data                       oxi.searcher.ISearchInFilesResult
    ---
    local items = {} ---@type table<string, oxi.searcher.IFileMatch>
    local orders = {} ---@type string[]

    local cwd = params.cwd ---@type string
    for filepath, item in pairs(data.items) do
      filepath = std.path.relative(cwd, filepath, true)
      table.insert(orders, filepath)
      items[filepath] = item

      for _, block_match in ipairs(item.matches) do
        local text = block_match.text ---@type string
        local lwidths = oxi.string.calc_linewidths(text) ---@type integer[]
        local lines = oxi.string.parse_lines(text, lwidths) ---@type string[]
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

---@class oxi.searcher.ISearchInLinesParams
---@field public pattern                string
---@field public lines                  string[]
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@param params                        oxi.searcher.ISearchInLinesParams
---@return oxi.string.ILineMatch[]|nil
function M.search_in_lines(params)
  local result = oxi.fn.safe_run("search_in_lines", {
    pattern = params.pattern,
    lines = params.lines,
    flag_fuzzy = params.flag_fuzzy,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
  })
  return result
end

---@class oxi.searcher.ISearchInTextParams
---@field public pattern                string
---@field public text                   string
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@param params                        oxi.searcher.ISearchInTextParams
---@return oxi.string.ILineMatch[]|nil
function M.search_in_text(params)
  local result = oxi.fn.safe_run("search_in_text", {
    pattern = params.pattern,
    text = params.text,
    flag_fuzzy = params.flag_fuzzy,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
  })
  return result
end

---@class oxi.searcher.ISearchInBufferParams
---@field public bufnr                  integer
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean
---@field public flag_replace           boolean
---@field public search_pattern         string

---@class oxi.searcher.ISearchInBufferResult
---@field public bufnr                  integer
---@field public error                  string|nil
---@field public matches                std.t.IMatchPoint[]

---@param params                        oxi.searcher.ISearchInBufferParams
---@return oxi.searcher.ISearchInBufferResult
function M.search_in_buffer(params)
  local nvim_tools = require("nvim_tools")
  local result = nvim_tools.search_in_buffer({
    bufnr = params.bufnr,
    search_pattern = params.search_pattern,
    flag_fuzzy = params.flag_fuzzy,
    flag_regex = params.flag_regex,
    flag_case_sensitive = params.flag_case_sensitive,
  })
  return result
end

return M
