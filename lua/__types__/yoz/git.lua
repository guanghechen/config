---@meta

---@alias yoz.git.Stage "staged"|"unstaged"|"mixed"

---@class yoz.git.IStatusOptions
---@field public base                   ?string
---@field public include_numstat        ?boolean
---@field public include_untracked      ?boolean

---@class yoz.git.IStatusQuery : yoz.git.IStatusOptions
---@field public cwd                    string

---@class yoz.git.StatusInfo
---@field public codes                  integer
---@field public display                string
---@field public stage                  ?yoz.git.Stage
---@field public staged_display         string
---@field public summary                ?string

---@class yoz.git.StatusEntry
---@field public categories             table<string, boolean>
---@field public codes                  table<string, boolean>
---@field public display                string
---@field public path                   string
---@field public relative               string
---@field public stage                  ?yoz.git.Stage
---@field public staged                 table<string, boolean>
---@field public staged_bits            integer
---@field public staged_display         string
---@field public staged_new_object_name ?string
---@field public staged_old_object_name ?string
---@field public staged_prev_relative   ?string
---@field public summary                ?string
---@field public unstaged               table<string, boolean>
---@field public unstaged_bits          integer
---@field public unstaged_display       string
---@field unstaged_new_object_name      ?string
---@field unstaged_old_object_name      ?string
---@field public unstaged_prev_relative ?string

---@class yoz.git.Numstat
---@field public insertions             integer
---@field public deletions              integer

---@class yoz.git.StatusData
---@field public status_map             table<string, yoz.git.StatusEntry>
---@field public status_groups          table<string, table<string, boolean>>
---@field public numstats               ?{ staged: table<string, yoz.git.Numstat>, unstaged: table<string, yoz.git.Numstat> }

---@class yoz.git.StatusSnapshot
local Snapshot = {}

---@param other                         yoz.git.StatusSnapshot
---@return boolean
function Snapshot:equals(other) end

---@param path                          string
---@param directory                     ?boolean
---@return yoz.git.StatusInfo|nil
function Snapshot:lookup(path, directory) end

---@return table<string, yoz.git.StatusEntry>
function Snapshot:entries() end

---@return yoz.git.StatusData
function Snapshot:export() end

---@return table<string, string>
function Snapshot:display() end

---@return string[]                     staged files
---@return string[]                     unstaged files, including untracked
function Snapshot:changed_files() end

---@return integer                      process count
---@return number                       native elapsed milliseconds
function Snapshot:stats() end

---@class yoz.git.StatusJob
local Job = {}

---@return "running"|"completed"|"cancelled"|"failed"
---@return yoz.git.StatusSnapshot|nil
---@return string|nil
function Job:poll() end

---@return nil
function Job:cancel() end

---@return nil
function Job:dispose() end

---@class yoz.git.IgnoreReport
---@field public changed                string[]
---@field public warning                ?{ code: integer|nil, stderr: string }
---@field public processes              integer
---@field public lstat_calls            integer

---@class yoz.git.IgnoreJob
local IgnoreJob = {}

---@return "running"|"completed"|"cancelled"|"failed"
---@return yoz.git.IgnoreReport|nil
---@return string|nil
function IgnoreJob:poll() end

---@return nil
function IgnoreJob:cancel() end

---@return nil
function IgnoreJob:dispose() end

---@class yoz.git.IgnoreCache
local IgnoreCache = {}

---@param path                          string
---@return boolean
function IgnoreCache:lookup(path) end

---@return nil
function IgnoreCache:clear() end

---@param paths                         string[]
---@return yoz.git.IgnoreJob
function IgnoreCache:start(paths) end

---@class yoz.git.IBlameQuery
---@field public cwd                    string
---@field public path                   string
---@field public contents               string

---@class yoz.git.BlameCommit
---@field public sha                    string
---@field public abbrev_sha             string
---@field public author                 string
---@field public author_mail            string
---@field public author_time            integer
---@field public author_tz              string
---@field public committer              string
---@field public committer_mail         string
---@field public committer_time         integer
---@field public committer_tz           string
---@field public summary                string
---@field public uncommitted            boolean

---@class yoz.git.BlameInfo : yoz.git.BlameCommit
---@field public filename               string
---@field public final_lnum             integer
---@field public num_lines              integer
---@field public orig_lnum              integer
---@field public previous               ?string
---@field public previous_filename      ?string

---@class yoz.git.BlameSnapshot
local BlameSnapshot = {}

---@param lnum                          integer
---@return yoz.git.BlameCommit|nil
function BlameSnapshot:commit_at(lnum) end

---@return yoz.git.BlameCommit[]
function BlameSnapshot:commits() end

---@param labels                        string[]
---@return string[]
function BlameSnapshot:annotations(labels) end

---@return yoz.git.BlameInfo[]
function BlameSnapshot:entries() end

---@return integer                      line count
---@return integer                      commit count
---@return number                       native elapsed milliseconds
function BlameSnapshot:stats() end

---@class yoz.git.BlameJob
local BlameJob = {}

---@return "running"|"completed"|"cancelled"|"failed"
---@return yoz.git.BlameSnapshot|nil
---@return string|nil
function BlameJob:poll() end

---@return nil
function BlameJob:cancel() end

---@return nil
function BlameJob:dispose() end

---@class yoz.git.TextDocument
---@field public eol                    string
---@field public lines                  string[]
---@field public text                   string

---@alias yoz.git.HunkType "add"|"change"|"delete"

---@class yoz.git.HunkNode
---@field public count                  integer
---@field public lines                  string[]
---@field public no_nl_at_eof           ?boolean
---@field public start                  integer

---@class yoz.git.Hunk
---@field public added                  yoz.git.HunkNode
---@field public head                   string
---@field public removed                yoz.git.HunkNode
---@field public type                   yoz.git.HunkType
---@field public vend                   integer

---@class yoz.git.WordChange
---@field public old_start              integer
---@field public old_end                integer
---@field public new_start              integer
---@field public new_end                integer

---@class yoz.git.word_diff
local WordDiff = {}

---The first 500 bytes, separated by LF, for the unchanged Neovim histogram diff.
---@param old_text                      string
---@param new_text                      string
---@return string
---@return string
function WordDiff.inputs(old_text, new_text) end

---Nil raw data selects the failed-diff fallback; an empty array means no changes.
---@param old_text                      string
---@param new_text                      string
---@param raw                           ?integer[][]
---@return yoz.git.WordChange[]
function WordDiff.finish(old_text, new_text, raw) end

---@class yoz.git.staging
local Staging = {}

---@alias yoz.git.Selection "stage"|"stage_partial"|"unstage"|"reset"

---@param encoding                      ?string
---@return string
function Staging.normalize_encoding(encoding) end

---Encoding must be normalized. Nil without error means a legacy codec; errors must not fall back.
---@param bytes                         string
---@param encoding                      string
---@return string|nil                   text
---@return boolean                      bomb
---@return string|nil                   error
function Staging.decode_unicode(bytes, encoding) end

---Encoding must be normalized. Nil without error means a legacy codec; errors must not fall back.
---@param text                          string
---@param encoding                      string
---@param bomb                          boolean
---@return string|nil                   bytes
---@return string|nil                   error
function Staging.encode_unicode(text, encoding, bomb) end

---Hunks always describe original -> modified, including unstage. Nil means no touched change.
---@param original                      yoz.git.TextDocument
---@param modified                      yoz.git.TextDocument
---@param hunks                         yoz.git.Hunk[]
---@param top                           integer
---@param bot                           integer
---@param mode                          yoz.git.Selection
---@return string|nil
function Staging.apply_selection(original, modified, hunks, top, bot, mode) end

---@param text                          string
---@param default_eol                   ?string
---@return yoz.git.TextDocument
function Staging.from_text(text, default_eol) end

---@param original                      yoz.git.TextDocument
---@param modified                      yoz.git.TextDocument
---@param hunks                         yoz.git.Hunk[]
---@return string
function Staging.apply_line_changes(original, modified, hunks) end

---@param hunk                          yoz.git.Hunk
---@return integer
---@return integer
function Staging.modified_range(hunk) end

---@param hunk                          yoz.git.Hunk
---@param top                           integer
---@param bot                           integer
---@return boolean
function Staging.touches(hunk, top, bot) end

---@param hunk                          yoz.git.Hunk
---@param top                           integer
---@param bot                           integer
---@return yoz.git.Hunk|nil
function Staging.intersect(hunk, top, bot) end

---@param hunk                          yoz.git.Hunk
---@return yoz.git.Hunk
function Staging.invert(hunk) end

---@param a                             yoz.git.Hunk
---@param b                             yoz.git.Hunk
---@return boolean
function Staging.less(a, b) end

---@class yoz.git
---@field public codes                  table<string, integer>
---@field public staging                yoz.git.staging
---@field public word_diff              yoz.git.word_diff
local M = {}

---@param options                       yoz.git.IStatusQuery
---@return yoz.git.StatusJob
function M.start_status(options) end

---@return yoz.git.StatusSnapshot
function M.empty_status() end

---@param cwd                           string
---@return yoz.git.IgnoreCache
function M.ignore_cache(cwd) end

---@param options                       yoz.git.IBlameQuery
---@return yoz.git.BlameJob
function M.start_blame(options) end

return M
