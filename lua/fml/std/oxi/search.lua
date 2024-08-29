---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@class fml.std.oxi.search.IMatchPoint
---@field public l                      integer
---@field public r                      integer

---@class fml.std.oxi.search.IBlockMatch
---@field public lnum                   integer
---@field public text                   string
---@field public lines                  string[]
---@field public lwidths                integer[]
---@field public matches                fml.std.oxi.search.IMatchPoint[]

---@class fml.std.oxi.search.IFileMatch
---@field public matches                fml.std.oxi.search.IBlockMatch[]

---@class fml.std.oxi.search.IResult
---@field public elapsed_time           string
---@field public items                  ?table<string, fml.std.oxi.search.IFileMatch>
---@field public item_orders            ?string[]
---@field public error                  ?string

---@class fml.std.oxi.search.IParams
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

---@param params                        fml.std.oxi.search.IParams
---@return fml.std.oxi.search.IResult|nil
function M.search(params)
  local payload = M.json.stringify(params) ---@type string
  local ok, data = M.run_cmd("fml.std.oxi.search", M.nvim_tools.search, payload)

  if ok and data ~= nil and data.items ~= nil then
    local orders = {}
    for filepath in pairs(data.items) do
      table.insert(orders, filepath)
    end
    table.sort(orders)
    data.item_orders = orders

    for _, item in pairs(data.items) do
      for _, block_match in ipairs(item.matches) do
        local text = block_match.text ---@type string
        local lwidths = M.get_line_widths(text) ---@type integer[]
        local lines = M.parse_lines(text, lwidths) ---@type string[]
        block_match.lines = lines
        block_match.lwidths = lwidths
      end
    end
  end

  return data
end
