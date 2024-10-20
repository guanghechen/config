local json = require("eve.std.json")
local path = require("eve.std.path")

---@class eve.oxi
local M = require("eve.oxi.mod")

---@class eve.oxi.search.IBlockMatch
---@field public lnum                   integer
---@field public text                   string
---@field public offset                 integer
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                t.eve.IMatchPoint[]

---@class eve.oxi.search.IFileMatch
---@field public matches                eve.oxi.search.IBlockMatch[]

---@class eve.oxi.search.IResult
---@field public elapsed_time           string
---@field public items                  ?table<string, eve.oxi.search.IFileMatch>
---@field public item_orders            ?string[]
---@field public error                  ?string

---@class eve.oxi.search.IParams
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

---@param params                        eve.oxi.search.IParams
---@return eve.oxi.search.IResult|nil
function M.search(params)
  local payload = json.stringify(params) ---@type string
  local ok, data = M.run_cmd("eve.oxi.search", M.nvim_tools.search, payload)

  if ok and data ~= nil and data.items ~= nil then
    local items = {} ---@type table<string, eve.oxi.search.IFileMatch>
    local orders = {} ---@type string[]

    local cwd = params.cwd ---@type string
    for filepath, item in pairs(data.items) do
      filepath = path.relative(cwd, filepath, true)
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

  return data
end
