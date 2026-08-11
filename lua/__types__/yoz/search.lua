---@meta

---@module 'yoz.search'
---@class yoz.search
local M = {}

---@class yoz.search.ISearchInFilesOptions
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

---@class yoz.search.ITextMatch
---@field public lx                     integer
---@field public ly                     integer
---@field public cx                     integer
---@field public cy                     integer
---@field public ox                     integer
---@field public oy                     integer
---@field public s                      string
---@field public sx                     integer
---@field public sy                     integer

---@class yoz.search.IFileMatch
---@field public p                      string
---@field public matches                yoz.search.ITextMatch[]

---@class yoz.search.ISearchFileResult
---@field public elapsed_time           integer
---@field public items                  yoz.search.IFileMatch[]

---@class yoz.search.ISearchFailedResult
---@field public elapsed_time           integer
---@field public error                  string

---@alias yoz.search.SearchInFilesJobStatus "running"|"completed"|"cancelled"|"failed"

---@class yoz.search.SearchInFilesJob
local SearchInFilesJob = {}

---@return yoz.search.SearchInFilesJobStatus
---@return yoz.search.ISearchFileResult|nil
---@return yoz.search.ISearchFailedResult|nil
function SearchInFilesJob:poll() end

function SearchInFilesJob:cancel() end

function SearchInFilesJob:dispose() end

---@class yoz.search.ISearchTextResult
---@field public elapsed_time           integer
---@field public matches                yoz.search.ITextMatch[]
---@field public lines                  yoz.search.ISearchInLinesLineMatch[]

---@param options                       yoz.search.ISearchInFilesOptions
---@return yoz.search.ISearchFileResult|nil
---@return yoz.search.ISearchFailedResult|nil
function M.search_in_files(options) end

---@param options                       yoz.search.ISearchInFilesOptions
---@return yoz.search.SearchInFilesJob
function M.start_search_in_files(options) end

---@alias yoz.search.ISearchInLinesLiteralMatchPoint yoz.search.ISearchInLinesMatchPoint

---@alias yoz.search.ISearchInLinesLiteralLineMatch yoz.search.ISearchInLinesLineMatch

---@class yoz.search.ISearchInLinesLiteralOptions
---@field public pattern                string
---@field public lines                  string[]
---@field public flag_fuzzy             boolean
---@field public flag_case_sensitive    boolean

---@param options                       yoz.search.ISearchInLinesLiteralOptions
---@return yoz.search.ISearchTextResult|nil
---@return string|nil
function M.search_in_lines_literal(options) end

---@alias yoz.search.ISearchInLinesRegexMatchPoint yoz.search.ISearchInLinesMatchPoint

---@alias yoz.search.ISearchInLinesRegexLineMatch yoz.search.ISearchInLinesLineMatch

---@class yoz.search.ISearchInLinesRegexOptions
---@field public pattern                string
---@field public lines                  string[]
---@field public flag_case_sensitive    boolean

---@param options                       yoz.search.ISearchInLinesRegexOptions
---@return yoz.search.ISearchTextResult|nil
---@return string|nil
function M.search_in_lines_regex(options) end

---@class yoz.search.ISearchInLinesMatchPoint
---@field public l                      integer
---@field public r                      integer

---@class yoz.search.ISearchInLinesLineMatch
---@field public lnum                   integer
---@field public score                  integer
---@field public matches                yoz.search.ISearchInLinesMatchPoint[]

---@class yoz.search.ISearchInLinesOptions
---@field public pattern                string
---@field public lines                  string[]
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@param options                       yoz.search.ISearchInLinesOptions
---@return yoz.search.ISearchTextResult|nil
---@return string|nil
function M.search_in_lines(options) end

---@class yoz.search.ISearchInTextOptions
---@field public pattern                string
---@field public text                   string
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@param options                       yoz.search.ISearchInTextOptions
---@return yoz.search.ISearchTextResult|nil
---@return string|nil
function M.search_in_text(options) end

return M
