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

---@class rstd.search.ITextMatch
---@field public lx                     integer
---@field public ly                     integer
---@field public cx                     integer
---@field public cy                     integer
---@field public ox                     integer
---@field public oy                     integer
---@field public s                      string
---@field public sx                     integer
---@field public sy                     integer

---@class rstd.search.IFileMatch
---@field public p                      string
---@field public matches                rstd.search.ITextMatch[]

---@class rstd.search.ISearchFileResult
---@field public elapsed_time           integer
---@field public items                  rstd.search.IFileMatch[]

---@class rstd.search.ISearchFailedResult
---@field public elapsed_time           integer
---@field public error                  string

---@class rstd.search.ISearchTextResult
---@field public elapsed_time           integer
---@field public matches                rstd.search.ITextMatch[]
---@field public lines                  rstd.search.ISearchInLinesLineMatch[]

---@param options                       rstd.search.ISearchInFilesOptions
---@return rstd.search.ISearchFileResult|nil
---@return rstd.search.ISearchFailedResult|nil
function M.search_in_files(options) end

---@alias rstd.search.ISearchInLinesLiteralMatchPoint rstd.search.ISearchInLinesMatchPoint

---@alias rstd.search.ISearchInLinesLiteralLineMatch rstd.search.ISearchInLinesLineMatch

---@class rstd.search.ISearchInLinesLiteralOptions
---@field public pattern                string
---@field public lines                  string[]
---@field public flag_fuzzy             boolean
---@field public flag_case_sensitive    boolean

---@param options                       rstd.search.ISearchInLinesLiteralOptions
---@return rstd.search.ISearchTextResult|nil
---@return string|nil
function M.search_in_lines_literal(options) end

---@alias rstd.search.ISearchInLinesRegexMatchPoint rstd.search.ISearchInLinesMatchPoint

---@alias rstd.search.ISearchInLinesRegexLineMatch rstd.search.ISearchInLinesLineMatch

---@class rstd.search.ISearchInLinesRegexOptions
---@field public pattern                string
---@field public lines                  string[]
---@field public flag_case_sensitive    boolean

---@param options                       rstd.search.ISearchInLinesRegexOptions
---@return rstd.search.ISearchTextResult|nil
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
---@return rstd.search.ISearchTextResult|nil
---@return string|nil
function M.search_in_lines(options) end

---@class rstd.search.ISearchInTextOptions
---@field public pattern                string
---@field public text                   string
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@param options                       rstd.search.ISearchInTextOptions
---@return rstd.search.ISearchTextResult|nil
---@return string|nil
function M.search_in_text(options) end

return M
