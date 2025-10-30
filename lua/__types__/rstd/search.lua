---@meta

---@module 'rstd.search'
---@class rstd.search
local M = {}

---@class rstd.search.ISearchInFilesOptions
---@field public cwd                    string|nil
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public max_filesize           string|nil
---@field public max_matches            integer|nil
---@field public search_pattern         string
---@field public search_paths           string
---@field public include_patterns       string
---@field public exclude_patterns       string
---@field public specified_filepath     string|nil

---@class rstd.search.ISearchMatchPoint
---@field public l                      integer
---@field public r                      integer

---@class rstd.search.ISearchBlockMatch
---@field public lnum                   integer
---@field public text                   string
---@field public offset                 integer
---@field public matches                rstd.search.ISearchMatchPoint[]

---@class rstd.search.ISearchFileMatch
---@field public matches                rstd.search.ISearchBlockMatch[]

---@class rstd.search.ISearchInFilesSucceedResult
---@field public elapsed_time           string
---@field public items                  table<string, rstd.search.ISearchFileMatch>
---@field public item_orders            string[]|nil

---@class rstd.search.ISearchInFilesFailedResult
---@field public elapsed_time           string
---@field public error                  string

---@param options                       rstd.search.ISearchInFilesOptions
---@return rstd.search.ISearchInFilesSucceedResult|nil
---@return rstd.search.ISearchInFilesFailedResult|nil
function M.search_in_files(options) end

---@class rstd.search.ISearchInLinesLiteralMatchPoint
---@field public l                      integer
---@field public r                      integer

---@class rstd.search.ISearchInLinesLiteralLineMatch
---@field public lnum                   integer
---@field public score                  integer
---@field public matches                rstd.search.ISearchInLinesLiteralMatchPoint[]

---@class rstd.search.ISearchInLinesLiteralOptions
---@field public pattern                string
---@field public lines                  string[]
---@field public flag_fuzzy             boolean
---@field public flag_case_sensitive    boolean

---@param options                       rstd.search.ISearchInLinesLiteralOptions
---@return rstd.search.ISearchInLinesLiteralLineMatch[]
function M.search_in_lines_literal(options) end

---@class rstd.search.ISearchInLinesRegexMatchPoint
---@field public l                      integer
---@field public r                      integer

---@class rstd.search.ISearchInLinesRegexLineMatch
---@field public lnum                   integer
---@field public score                  integer
---@field public matches                rstd.search.ISearchInLinesRegexMatchPoint[]

---@class rstd.search.ISearchInLinesRegexOptions
---@field public pattern                string
---@field public lines                  string[]
---@field public flag_case_sensitive    boolean

---@param options                       rstd.search.ISearchInLinesRegexOptions
---@return rstd.search.ISearchInLinesRegexLineMatch[]|nil
---@return string|nil
function M.search_in_lines_regex(options) end

---@class rstd.search.ISearchInLinesMatchPoint
---@field public l                      integer
---@field public r                      integer

---@class rstd.search.ISearchInLinesLineMatch
---@field public lnum                   integer
---@field public score                  integer
---@field public matches                rstd.search.ISearchInLinesMatchPoint[]

---@class rstd.search.ISearchInLinesOptions
---@field public pattern                string
---@field public lines                  string[]
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@param options                       rstd.search.ISearchInLinesOptions
---@return rstd.search.ISearchInLinesLineMatch[]|nil
---@return string|nil
function M.search_in_lines(options) end

return M
