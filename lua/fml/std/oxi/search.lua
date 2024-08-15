---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@class fml.std.oxi.search.IMatchPoint
---@field public l                      integer
---@field public r                      integer

---@class fml.std.oxi.search.IBlockMatch
---@field public lnum                   integer
---@field public text                   string
---@field public lines                  string[]
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
---@return fml.std.oxi.search.IResult
function M.search(params)
  local options_stringified = M.json.stringify(params)
  local result_str = M.nvim_tools.search(options_stringified)
  local result = M.json.parse(result_str)
  ---@cast result fml.std.oxi.search.IResult

  if result.items ~= nil then
    local orders = {}
    for filepath in pairs(result.items) do
      table.insert(orders, filepath)
    end
    table.sort(orders)
    result.item_orders = orders

    for _, item in pairs(result.items) do
      for _, block_match in ipairs(item.matches) do
        local text = block_match.text ---@type string
        local lines = {} ---@type string[]
        for line in text:gmatch("([^\n]+)") do
          table.insert(lines, line)
        end
        block_match.lines = lines
      end
    end
  end

  return result
end
