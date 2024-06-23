---@class fml.core.oxi
local M = require("fml.core.oxi.mod")

---@class fml.core.oxi.search.IMatchPoint
---@field public l                      integer
---@field public r                      integer

---@class fml.core.oxi.search.ILineMatchPiece
---@field public i                      integer
---@field public l                      integer
---@field public r                      integer

---@class fml.core.oxi.search.ILineMatch
---@field public l                      integer
---@field public r                      integer
---@field public p                      fml.core.oxi.search.ILineMatchPiece[]

---@class fml.core.oxi.search.IBlockMatch
---@field public text                   string
---@field public lnum                   integer
---@field public matches                fml.core.oxi.search.IMatchPoint[]
---@field public lines                  fml.core.oxi.search.ILineMatch[]

---@class fml.core.oxi.search.IFileMatch
---@field public matches                fml.core.oxi.search.IBlockMatch[]

---@class fml.core.oxi.search.IResult
---@field public elapsed_time           string
---@field public items                  ?table<string, fml.core.oxi.search.IFileMatch>
---@field public error                  ? string

---@class fml.core.oxi.search.IParams
---@field public cwd                    string
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean
---@field public search_pattern         string
---@field public search_paths           string
---@field public include_patterns       string
---@field public exclude_patterns       string

---@param params                        fml.core.oxi.search.IParams
---@return fml.core.oxi.search.IResult
function M.search(params)
  local options_stringified = M.json.stringify(params)
  local result_str = M.nvim_tools.search(options_stringified)
  local result = M.json.parse(result_str)
  ---@cast result fml.core.oxi.search.IResult
  return result
end
