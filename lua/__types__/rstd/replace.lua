---@meta

---@module 'rstd.replace'
---@class rstd.replace
local M = {}

---@class rstd.replace.IReplaceFileParams
---@field public filepath               string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@class rstd.replace.IReplaceFileByMatchesParams : rstd.replace.IReplaceFileParams
---@field public match_offsets          integer[]

---@class rstd.replace.IReplaceFileByMatchesAdvanceParams : rstd.replace.IReplaceFileByMatchesParams
---@field public remain_offsets         integer[]

---@class rstd.replace.IReplaceFileResult
---@field public locations              std.t.IMatchLocation[]

---@class rstd.replace.IReplaceFilePreviewParams
---@field public filepath               string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public keep_search_pieces     boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@class rstd.replace.IReplaceFilePreviewByMatchesAdvanceParams : rstd.replace.IReplaceFilePreviewParams
---@field public match_offsets          integer[]

---@class rstd.replace.IReplaceTextPreviewParams
---@field public text                   string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public keep_search_pieces     boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@class rstd.replace.IReplaceTextPreviewByMatchesParams : rstd.replace.IReplaceTextPreviewParams
---@field public match_offsets          integer[]

---@class rstd.replace.IReplacePreviewResult
---@field public text                   string
---@field public matches                std.t.IMatchPoint[]

---@param params                        rstd.replace.IReplaceFileParams
---@return boolean|nil
---@return string|nil
function M.replace_file(params) end

---@param params                        rstd.replace.IReplaceFileByMatchesParams
---@return boolean|nil
---@return string|nil
function M.replace_file_by_matches(params) end

---@param params                        rstd.replace.IReplaceFileByMatchesAdvanceParams
---@return rstd.replace.IReplaceFileResult|nil
---@return string|nil
function M.replace_file_by_matches_advance(params) end

---@param params                        rstd.replace.IReplaceFilePreviewParams
---@return string|nil
---@return string|nil
function M.replace_file_preview(params) end

---@param params                        rstd.replace.IReplaceFilePreviewParams
---@return rstd.replace.IReplacePreviewResult|nil
---@return string|nil
function M.replace_file_preview_advance(params) end

---@param params                        rstd.replace.IReplaceFilePreviewByMatchesAdvanceParams
---@return rstd.replace.IReplacePreviewResult|nil
---@return string|nil
function M.replace_file_preview_by_matches_advance(params) end

---@param params                        rstd.replace.IReplaceTextPreviewParams
---@return string|nil
---@return string|nil
function M.replace_text_preview(params) end

---@param params                        rstd.replace.IReplaceTextPreviewByMatchesParams
---@return string|nil
---@return string|nil
function M.replace_text_preview_by_matches(params) end

---@param params                        rstd.replace.IReplaceTextPreviewParams
---@return rstd.replace.IReplacePreviewResult|nil
---@return string|nil
function M.replace_text_preview_advance(params) end

---@param params                        rstd.replace.IReplaceTextPreviewByMatchesParams
---@return rstd.replace.IReplacePreviewResult|nil
---@return string|nil
function M.replace_text_preview_by_matches_advance(params) end

return M
