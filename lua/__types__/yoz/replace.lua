---@meta

---@module 'yoz.replace'
---@class yoz.replace
local M = {}

---@class yoz.replace.IReplaceFileParams
---@field public filepath               string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@class yoz.replace.IReplaceFileByMatchesParams : yoz.replace.IReplaceFileParams
---@field public match_offsets          integer[]

---@class yoz.replace.IReplaceFileByMatchesAdvanceParams : yoz.replace.IReplaceFileByMatchesParams
---@field public remain_offsets         integer[]

---@class yoz.replace.IReplaceFileResult
---@field public locations              std.t.IMatchLocation[]

---@class yoz.replace.IReplaceFilePreviewParams
---@field public filepath               string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public keep_search_pieces     boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@class yoz.replace.IReplaceFilePreviewByMatchesAdvanceParams : yoz.replace.IReplaceFilePreviewParams
---@field public match_offsets          integer[]

---@class yoz.replace.IReplaceTextPreviewParams
---@field public text                   string
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public keep_search_pieces     boolean
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@class yoz.replace.IReplaceTextPreviewByMatchesParams : yoz.replace.IReplaceTextPreviewParams
---@field public match_offsets          integer[]

---@class yoz.replace.IReplacePreviewResult
---@field public text                   string
---@field public matches                std.t.IMatchPoint[]

---@param params                        yoz.replace.IReplaceFileParams
---@return boolean|nil
---@return string|nil
function M.replace_file(params) end

---@param params                        yoz.replace.IReplaceFileByMatchesParams
---@return boolean|nil
---@return string|nil
function M.replace_file_by_matches(params) end

---@param params                        yoz.replace.IReplaceFileByMatchesAdvanceParams
---@return yoz.replace.IReplaceFileResult|nil
---@return string|nil
function M.replace_file_by_matches_advance(params) end

---@param params                        yoz.replace.IReplaceFilePreviewParams
---@return string|nil
---@return string|nil
function M.replace_file_preview(params) end

---@param params                        yoz.replace.IReplaceFilePreviewParams
---@return yoz.replace.IReplacePreviewResult|nil
---@return string|nil
function M.replace_file_preview_advance(params) end

---@param params                        yoz.replace.IReplaceFilePreviewByMatchesAdvanceParams
---@return yoz.replace.IReplacePreviewResult|nil
---@return string|nil
function M.replace_file_preview_by_matches_advance(params) end

---@param params                        yoz.replace.IReplaceTextPreviewParams
---@return string|nil
---@return string|nil
function M.replace_text_preview(params) end

---@param params                        yoz.replace.IReplaceTextPreviewByMatchesParams
---@return string|nil
---@return string|nil
function M.replace_text_preview_by_matches(params) end

---@param params                        yoz.replace.IReplaceTextPreviewParams
---@return yoz.replace.IReplacePreviewResult|nil
---@return string|nil
function M.replace_text_preview_advance(params) end

---@param params                        yoz.replace.IReplaceTextPreviewByMatchesParams
---@return yoz.replace.IReplacePreviewResult|nil
---@return string|nil
function M.replace_text_preview_by_matches_advance(params) end

return M
